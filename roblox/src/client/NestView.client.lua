-- M1-3 둥지 · 알(클라 - 내 기준 겉모습): 서버 NestSync(둥지마다 다음 주울 시각 · 내가 주울 알 등급)를 받아 둥지 앵커(NestSpot)에 알을 그린다.
--   알 색 = 구역 보스 관문 색(EggData - 이미 있는 색) · 등급 겉모습 = 보통(무늬 없음) · 좋은(무늬 띠) · 희귀(무늬 + 빛). 쿨다운 중 · 오늘 아닌 순환 둥지 = 빈 둥지 + 내 프롬프트 끔.
--   프롬프트 문구(TextData) · 줍기 알림(TC) · 비밀 둥지 첫 발견 연출(알이 떠올라 빛나며 사라짐 + 알림) · 환경 힌트(반딧불 - 기존 기본 입자 방식) · 알 가방 상태 = NestState(알 정보창이 읽는다).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local EggData = require(ReplicatedStorage.Shared.data.EggData)
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local Text = require(ReplicatedStorage.Shared.Text)
local Toast = require(script.Parent.ui.kit.Toast)
local NestState = require(script.Parent.NestState)

local anchors = {} -- [id] = part
local eggs = {} -- [id] = { model, grade }
local FIREFLY = Color3.fromRGB(255, 230, 120)

-- 구역 알 색 = 그 구역 보스의 관문 색
local ZONE_COLOR = {}
for _, z in ipairs(WorldMapData.zones) do
	local boss = BossData.bosses[z.bossId]
	local c = boss and boss.gate and boss.gate.color or { 230, 230, 230 }
	ZONE_COLOR[z.key] = Color3.fromRGB(c[1], c[2], c[3])
end
function NestState.zoneColor(zoneKey)
	return ZONE_COLOR[zoneKey] or Color3.new(1, 1, 1)
end

-- 알 모형(로컬 파트): 타원 몸 + 무늬 띠 + 빛
function NestState.buildEgg(parent, cframe, zoneKey, grade, scale)
	local L = EggData.look
	local look = L[grade] or L.normal
	scale = scale or 1
	local color = NestState.zoneColor(zoneKey)
	local model = Instance.new("Model")
	model.Name = "Egg"
	local body = Instance.new("Part")
	body.Name = "EggBody"
	body.Shape = Enum.PartType.Ball
	body.Size = L.size * scale
	body.CFrame = cframe
	body.Color = color
	body.Material = grade == "rare" and Enum.Material.Glass or Enum.Material.SmoothPlastic
	body.Anchored, body.CanCollide, body.CanQuery, body.CanTouch, body.CastShadow = true, false, false, false, false
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = body
	body.Parent = model
	local dark = Color3.new(color.R * L.patternDarken, color.G * L.patternDarken, color.B * L.patternDarken)
	for k = 1, look.pattern do
		local y = (k - (look.pattern + 1) / 2) * L.size.Y * scale * 0.24
		local band = Instance.new("Part")
		band.Name = "EggBand"
		band.Shape = Enum.PartType.Cylinder
		local w = L.size.X * scale * math.sqrt(math.max(0.2, 1 - (2 * y / (L.size.Y * scale)) ^ 2)) + 0.08
		band.Size = Vector3.new(0.22 * scale, w, w)
		band.CFrame = cframe * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90))
		band.Color = grade == "rare" and color or dark
		band.Material = grade == "rare" and Enum.Material.Neon or Enum.Material.SmoothPlastic
		band.Anchored, band.CanCollide, band.CanQuery, band.CanTouch, band.CastShadow = true, false, false, false, false
		band.Parent = model
	end
	if look.glow then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Brightness = look.glow.brightness
		light.Range = look.glow.range
		light.Parent = body
	end
	model.PrimaryPart = body
	model.Parent = parent
	return model
end

local function clearEgg(id)
	if eggs[id] then
		eggs[id].model:Destroy()
		eggs[id] = nil
	end
end

local function refresh(id)
	local part = anchors[id]
	if not part or not part.Parent then
		clearEgg(id)
		return
	end
	local info = NestState.nests[id]
	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	local ready = info ~= nil and part:GetAttribute("NestActive") ~= false and NestState.serverUnix() >= (info.next or 0)
	if prompt then
		prompt.ActionText = Text.get("nest.action")
		prompt.ObjectText = Text.get("nest.object")
		prompt.Enabled = ready -- 내 쿨다운 · 순환(서버도 막는다)
	end
	if ready then
		if not eggs[id] or eggs[id].grade ~= info.grade then
			clearEgg(id)
			local zoneKey = part:GetAttribute("NestZone")
			if zoneKey == "hub" then
				local spec = NestState.spec(id)
				zoneKey = spec and spec.eggZone or "tier1"
			end
			local cf = CFrame.new(part.Position - Vector3.new(0, 0.2, 0)) * CFrame.Angles(0.15, 0, 0.1)
			eggs[id] = { model = NestState.buildEgg(Workspace.CurrentCamera, cf, zoneKey, info.grade), grade = info.grade }
		end
	else
		clearEgg(id)
	end
end

local function refreshAll()
	for id in pairs(anchors) do
		refresh(id)
	end
end

-- 환경 힌트(반딧불): 둥지 입구 근처 앵커(NestHint = fireflies)에 기본 입자 몇 개(빛나는 작은 점 - VineLiftView와 같은 방식)
local function addHint(part)
	if part:GetAttribute("NestHint") ~= "fireflies" or part:FindFirstChild("NestFireflies") then
		return
	end
	local e = Instance.new("ParticleEmitter")
	e.Name = "NestFireflies"
	e.Shape = Enum.ParticleEmitterShape.Sphere
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Rate = 1.2
	e.Lifetime = NumberRange.new(3, 4.5)
	e.Speed = NumberRange.new(0.6, 1.4)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new(0.3)
	e.Color = ColorSequence.new(FIREFLY)
	e.LightEmission = 1
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.2), NumberSequenceKeypoint.new(0.7, 0.35), NumberSequenceKeypoint.new(1, 1) })
	e.Parent = part
end

local function track(part)
	if not part:IsA("BasePart") then
		return
	end
	local id = part:GetAttribute("NestId")
	if id then
		anchors[id] = part
		part:GetAttributeChangedSignal("NestActive"):Connect(function()
			refresh(id)
		end)
		task.defer(refresh, id)
	elseif part:GetAttribute("NestHint") then
		addHint(part)
	end
end

local ground = Workspace:WaitForChild("Ground", 60)
if ground then
	for _, d in ipairs(ground:GetDescendants()) do
		track(d)
	end
	ground.DescendantAdded:Connect(function(d)
		task.defer(track, d)
	end)
	ground.DescendantRemoving:Connect(function(d)
		local id = d:IsA("BasePart") and d:GetAttribute("NestId")
		if id and anchors[id] == d then
			anchors[id] = nil
			clearEgg(id)
		end
	end)
end

ReplicatedStorage:WaitForChild("NestSync").OnClientEvent:Connect(function(payload)
	NestState.apply(payload)
	refreshAll()
end)

-- 줍기 결과: 알림 + (비밀 둥지 첫 발견이면) 알이 떠올라 빛나며 사라지는 짧은 연출
ReplicatedStorage:WaitForChild("NestPicked").OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then
		return
	end
	if data.full then
		Toast.push("TC", { text = Text.get("nest.full", { cap = data.cap }), grade = "important", seconds = 3 })
		return
	end
	local egg = data.egg
	local zoneName = EggData.zones[egg.zone] and EggData.zones[egg.zone].name or egg.zone
	Toast.push("TC", {
		text = Text.get("nest.gotEgg", { grade = EggData.gradeNames[egg.grade], egg = zoneName, a = EggData.species[egg.species[1]] or egg.species[1], b = EggData.species[egg.species[2]] or egg.species[2] }),
		grade = "important", seconds = 4,
	})
	local part = anchors[data.id]
	local shown = eggs[data.id]
	if part and shown then
		local model = shown.model
		eggs[data.id] = nil
		local body = model.PrimaryPart
		local rise = data.discovered and 9 or 4
		local t = TweenService:Create(body, TweenInfo.new(data.discovered and 1.4 or 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = body.CFrame * CFrame.new(0, rise, 0) * CFrame.Angles(0, math.pi * 2, 0), Transparency = 1 })
		for _, band in ipairs(model:GetChildren()) do
			if band:IsA("BasePart") and band ~= body then
				band:Destroy()
			end
		end
		if data.discovered then
			local light = Instance.new("PointLight")
			light.Color = NestState.zoneColor(egg.zone)
			light.Brightness = 4
			light.Range = 16
			light.Parent = body
		end
		t:Play()
		t.Completed:Connect(function()
			model:Destroy()
		end)
	end
	if data.discovered then
		task.delay(0.8, function()
			Toast.push("TC", { text = Text.get("nest.discovered", { count = data.dexCount }), grade = "important", seconds = 3 })
			if data.title then
				for _, t in ipairs(require(ReplicatedStorage.Shared.data.NestData).dex.titles) do
					if t.id == data.title then
						Toast.push("TC", { text = Text.get("nest.title", { name = t.name }), grade = "important", seconds = 3 })
					end
				end
			end
		end)
	end
end)

-- 쿨다운이 끝나면 알이 다시 보이게(1초마다 - 둥지 수 64)
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc >= 1 then
		acc = 0
		for id, part in pairs(anchors) do
			local info = NestState.nests[id]
			local ready = info ~= nil and part:GetAttribute("NestActive") ~= false and NestState.serverUnix() >= (info.next or 0)
			if ready ~= (eggs[id] ~= nil) then
				refresh(id)
			end
		end
	end
end)
