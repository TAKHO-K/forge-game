-- A2-N2 2-2 도파민 연출(클라 · ArtStyleV1 스위치 뒤 · 판정 · 문구 무관 - 기존 알림 · 토스트 · 소리는 그대로 위에 얹는다). 값 = shared/data/ArtV1FxData · 표 = art-direction §5-2.
--   ① 땅 드랍 8단계: D1 번개(DropLightning - 사용자 결정) 뒤에 부드러운 빛 띠(Beam) + 오르는 반짝이 + 등장 링 · 번쩍. 희귀 · 초월은 번개가 없어 빛 띠가 기둥(초월 = 검은 심 + 금 테).
--   ② 레벨업(LevelUp) ③ 펫 부화(PetSync hatchCount 증가 - 결과 펫 등급) ④ 환생(RebirthResult success) - 전부 내 캐릭터 발밑.
--   태초 · 초월 알림(같은 서버 배너 · 전 서버 배너 · 본인 큰 연출)은 기존 PrimordialFx · PrimordialRegistry 그대로 - 여기는 땅 드랍 빛만.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local FxData = require(ReplicatedStorage.Shared.data.ArtV1FxData)
local GradeColor = require(ReplicatedStorage.Shared.GradeColor)
local Fx = require(script.Parent.ArtV1Fx)
local GradeFrame = require(script.Parent.GradeFrame)
local DropLookV2 = require(script.Parent.DropLookV2)

local D = FxData.drop
local player = Players.LocalPlayer

-- ─────────────── ① 땅 드랍 ───────────────
local drops = {} -- [model] = { folder, ground, emitter, release(), releaseBeams = {} }

local function beam(folder, ground, height, width, color, transparency)
	local ok, release = Fx.holdBeam()
	if not ok then
		return nil
	end
	local host = Instance.new("Part")
	host.Name = "GlowHost"
	host.Anchored, host.CanCollide, host.CanQuery, host.CanTouch, host.CastShadow = true, false, false, false, false
	host.Transparency = 1
	host.Size = Vector3.one * 0.1
	host.CFrame = CFrame.new(ground)
	host.Parent = folder
	local a0 = Instance.new("Attachment")
	a0.Parent = host
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, height, 0)
	a1.Parent = host
	local b = Instance.new("Beam")
	b.Attachment0, b.Attachment1 = a0, a1
	b.FaceCamera = true
	b.Segments = 1
	local h, sat, v = color:ToHSV()
	b.LightEmission = v < 0.3 and 0 or ((sat < 0.15 and v > 0.9) and 1 or D.glowEmission) -- 검은 심(초월) = 비발광 띠 · 흰 심 = 가산 · 색 띠 = 반쯤(블룸 번짐 방지)
	b.Color = ColorSequence.new(color)
	b.Width0, b.Width1 = width, width * 0.55
	b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, transparency), NumberSequenceKeypoint.new(0.6, math.min(1, transparency + 0.25)), NumberSequenceKeypoint.new(1, 1) })
	b.Parent = host
	return release
end

-- 2-5 드랍 이름표 = 등급 프레임 칩(어두운 바탕 + 등급 테두리 · 글자 = 등급 색 - 서버 이름표 TextLabel을 이 화면에서만 꾸민다)
local INK = Color3.fromRGB(30, 27, 46)
local function styleNameplate(model, on)
	local gui = model:FindFirstChild("NameplateGui", true)
	local label = gui and gui:FindFirstChildOfClass("TextLabel")
	if not label then
		return
	end
	if on then
		if label:FindFirstChild("ArtV1Chip") then
			return
		end
		label:SetAttribute("ArtV1OrigColor", label.TextColor3)
		local marker = Instance.new("UICorner")
		marker.Name = "ArtV1Chip"
		marker.CornerRadius = UDim.new(0.3, 0)
		marker.Parent = label
		local pad = Instance.new("UIPadding")
		pad.Name = "ArtV1Pad"
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0.06, 0), UDim.new(0.06, 0)
		pad.PaddingTop, pad.PaddingBottom = UDim.new(0.12, 0), UDim.new(0.12, 0)
		pad.Parent = label
		label.BackgroundColor3 = INK
		label.BackgroundTransparency = 0.2
		local stroke = Instance.new("UIStroke")
		stroke.Name = "ArtV1Stroke"
		stroke.Parent = label
		local grade = model:GetAttribute("DropGrade")
		GradeFrame.apply(nil, stroke, nil, grade)
		GradeFrame.applyText(label, grade)
	else
		for _, n in ipairs({ "ArtV1Chip", "ArtV1Pad", "ArtV1Stroke", "GradeSheen" }) do
			local c = label:FindFirstChild(n)
			if c then
				c:Destroy()
			end
		end
		label.BackgroundTransparency = 1
		local orig = label:GetAttribute("ArtV1OrigColor")
		if orig then
			label.TextColor3 = orig
		end
	end
end

local function colorOf(grade)
	return grade == "transcendent" and D.transcendentColor or GradeColor.border(grade) -- QUEUE-ALL9C 2-2
end

local function build(model)
	if drops[model] or not Fx.isOn() then
		return
	end
	local grade = model:GetAttribute("DropGrade")
	local ground = model:GetAttribute("BoltGround")
	local spec = grade and D[grade]
	if not spec or typeof(ground) ~= "Vector3" then
		return
	end
	local color = colorOf(grade)
	local glowColor = spec.glow and spec.glow.color or color -- 빛 띠 · 등장 링만 따로 칠할 수 있다(전설 진한 주황)
	local folder = Instance.new("Folder")
	folder.Name = "ArtV1DropGlow"
	folder.Parent = model -- 줍기 · 만료 때 같이 사라진다
	local st = { folder = folder, ground = ground, releases = {} }
	local g = spec.glow
	-- QUEUE-ALL1 P2 드랍 v2: 실루엣 · 빛기둥 가닥 · 바닥 번짐 · 이름표(태초 · 초월은 옛 빛 띠 그대로)
	local V2 = FxData.dropV2
	if V2 and V2.enabled then
		for _, r in ipairs(DropLookV2.build(model, folder, grade, ground, glowColor)) do
			table.insert(st.releases, r)
		end
		st.v2 = true
		if not V2.skipStrands[grade] then
			g = nil
		end
	end
	if g then
		if g.core then -- 두 줄: 넓고 옅은 테(등급 색) + 좁고 진한 심(흰 · 검정)
			table.insert(st.releases, beam(folder, ground, g.height, g.width * 1.6, g.rim, math.min(1, g.transparency + 0.15)))
			table.insert(st.releases, beam(folder, ground, g.height * 0.92, g.width * 0.7, g.core, g.transparency * 0.6))
		else
			table.insert(st.releases, beam(folder, ground, g.height, g.width, glowColor, g.transparency))
		end
	end
	if spec.motes > 0 then
		local n, release = Fx.hold(spec.motes)
		table.insert(st.releases, release)
		if n > 0 then
			local host = Instance.new("Part")
			host.Name = "MoteHost"
			host.Anchored, host.CanCollide, host.CanQuery, host.CanTouch, host.CastShadow = true, false, false, false, false
			host.Transparency = 1
			host.Size = Vector3.new(1.2, 0.1, 1.2)
			host.CFrame = CFrame.new(ground + Vector3.new(0, 0.3, 0))
			host.Parent = folder
			local e = Instance.new("ParticleEmitter")
			e.Rate = n / D.moteLifetime
			e.Lifetime = NumberRange.new(D.moteLifetime * 0.8, D.moteLifetime)
			e.Speed = NumberRange.new(D.moteSpeed * 0.7, D.moteSpeed)
			e.SpreadAngle = Vector2.new(8, 8)
			e.EmissionDirection = Enum.NormalId.Top
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, D.moteSize), NumberSequenceKeypoint.new(1, 0) })
			e.Color = ColorSequence.new(spec.moteColor or color:Lerp(Color3.new(1, 1, 1), 0.35))
			e.LightEmission = 1
			e.Parent = host
			st.emitter = e
		end
	end
	drops[model] = st
	styleNameplate(model, true)
	-- 드랍 광원(서버 PointLight - 등급 밝기)이 평면 조명 + 블룸에서 바닥을 하얗게 날렸다(Play 2) → 이 화면에서만 × dropLightScale
	for _, light in ipairs(model:GetDescendants()) do
		if light:IsA("PointLight") and light:GetAttribute("ArtV1Brightness") == nil then
			light:SetAttribute("ArtV1Brightness", light.Brightness)
			light:SetAttribute("ArtV1Range", light.Range)
			light.Brightness *= D.dropLightScale
			light.Range = math.min(light.Range, D.dropLightMaxRange)
		end
	end
	-- 등장(가까이 있을 때만 - 스트리밍으로 다시 들어온 먼 드랍은 조용히)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root and (root.Position - ground).Magnitude < 150 then
		if spec.ring then
			Fx.ring(ground + Vector3.new(0, 0.12, 0), spec.ring, D.ringSeconds, spec.ringColor or glowColor, 0.14, 0.1)
		end
		if spec.flash then
			Fx.flash(ground + Vector3.new(0, 1.6, 0), spec.flash, D.flashSeconds)
		end
	end
	model.Destroying:Connect(function()
		for _, r in ipairs(st.releases) do
			r()
		end
		drops[model] = nil
	end)
end

local function unbuild(model)
	local st = drops[model]
	if st then
		for _, r in ipairs(st.releases) do
			r()
		end
		st.folder:Destroy()
		drops[model] = nil
		DropLookV2.unbuild(model)
		styleNameplate(model, false)
		for _, light in ipairs(model:GetDescendants()) do
			local b = light:IsA("PointLight") and light:GetAttribute("ArtV1Brightness")
			if b then
				light.Brightness = b
				light.Range = light:GetAttribute("ArtV1Range") or light.Range
				light:SetAttribute("ArtV1Brightness", nil)
			end
		end
	end
end

local function watch(inst)
	if inst:IsA("Model") and inst.Name == "ItemDrop" then
		build(inst)
		inst:GetAttributeChangedSignal("BoltGround"):Connect(function()
			build(inst)
		end)
	end
end
Workspace.ChildAdded:Connect(watch)
for _, child in ipairs(Workspace:GetChildren()) do
	watch(child)
end

-- 스위치: 끄면 전부 걷고, 켜면 지금 있는 드랍에 다시 입힌다
Workspace:GetAttributeChangedSignal("ArtStyleV1"):Connect(function()
	for _, child in ipairs(Workspace:GetChildren()) do
		if child:IsA("Model") and child.Name == "ItemDrop" then
			if Fx.isOn() then
				build(child)
			else
				unbuild(child)
			end
		end
	end
end)

-- 먼 드랍은 반짝이를 끈다(빛 띠는 유지 - 멀리서 등급 읽기)
RunService.Heartbeat:Connect(function()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	for model, st in pairs(drops) do
		if not model.Parent then
			unbuild(model)
		elseif st.emitter then
			st.emitter.Enabled = (st.ground - eye).Magnitude <= FxData.budget.dropParticleDistance
		end
	end
end)

-- ─────────────── ② 레벨업 ───────────────
local function levelUp()
	local feet = Fx.isOn() and Fx.feetOf(player.Character)
	if not feet then
		return
	end
	local L = FxData.levelUp
	Fx.flash(feet + Vector3.new(0, 2.5, 0), 3, 0.12, L.flashColor)
	Fx.ring(feet, L.ringSize, L.seconds * 0.6, L.ringColor, 0.14, 0.05)
	task.delay(0.12, function()
		Fx.ring(feet, L.ringSize * 0.6, L.seconds * 0.5, L.flashColor, 0.1, 0.2)
	end)
	Fx.burst(feet + Vector3.new(0, 0.5, 0), L.particles, { color = L.particleColor, size = L.size, speed = L.speed, spread = L.spread, gravity = L.gravity, lifetime = { 0.6, L.seconds } })
end

-- ─────────────── ③ 펫 부화 ───────────────
local function hatch(grade)
	local feet = Fx.isOn() and Fx.feetOf(player.Character)
	if not feet then
		return
	end
	local H = FxData.hatch
	local s = H[grade] or H.common
	local egg = feet + Vector3.new(0, 1.5, 0)
	Fx.flash(egg, s.flash or 2, 0.14, Color3.new(1, 1, 1))
	Fx.ring(feet, s.ring, H.seconds * 0.6, s.color, 0.14, 0.1)
	Fx.burst(egg, s.particles, { color = s.color, size = H.size, speed = H.speed, spread = H.spread, gravity = H.gravity, lifetime = { 0.5, H.seconds } })
	if s.pillar then
		Fx.pillar(feet, { height = s.pillar.height, width = s.pillar.width, color = s.color, seconds = H.seconds })
	end
end

-- ─────────────── ④ 환생 ───────────────
local function rebirth()
	local feet = Fx.isOn() and Fx.feetOf(player.Character)
	if not feet then
		return
	end
	local R = FxData.rebirth
	Fx.flash(feet + Vector3.new(0, 2.5, 0), 5, 0.18, R.light)
	Fx.pillar(feet, { height = R.pillar.height, width = R.pillar.width, topWidth = R.pillar.topWidth, color = R.color, seconds = R.seconds })
	Fx.ring(feet, R.rings[1], R.seconds * 0.4, R.innerRing, 0.2, 0.05)
	task.delay(0.2, function()
		Fx.ring(feet, R.rings[2], R.seconds * 0.5, R.color, 0.3, 0.1)
	end)
	Fx.burst(feet + Vector3.new(0, 0.5, 0), R.particles, { color = R.light, size = R.size, speed = R.speed, spread = R.spread, gravity = R.gravity, lifetime = { 0.8, 1.2 } })
	Fx.screenFlash(R.screenFlash.brightness, R.screenFlash.seconds)
end

task.spawn(function()
	ReplicatedStorage:WaitForChild("LevelUp").OnClientEvent:Connect(levelUp)
end)
task.spawn(function()
	ReplicatedStorage:WaitForChild("RebirthResult").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and payload.success then
			rebirth()
		end
	end)
end)
task.spawn(function()
	local seen = nil
	ReplicatedStorage:WaitForChild("PetSync").OnClientEvent:Connect(function(view)
		if type(view) ~= "table" or type(view.hatchCount) ~= "number" then
			return
		end
		if seen and view.hatchCount > seen then
			local pets = view.pets
			local newest = type(pets) == "table" and pets[#pets]
			hatch(newest and newest.grade or "common")
		end
		seen = view.hatchCount
	end)
end)

-- 개발 확인용(Studio 전용 · 판정 없음): ReplicatedStorage Attribute ArtV1FxTest = "levelUp" | "rebirth" | "hatch:<등급>"
if RunService:IsStudio() then
	ReplicatedStorage:GetAttributeChangedSignal("ArtV1FxTest"):Connect(function()
		local v = tostring(ReplicatedStorage:GetAttribute("ArtV1FxTest"))
		if v == "levelUp" then
			levelUp()
		elseif v == "rebirth" then
			rebirth()
		elseif v:sub(1, 6) == "hatch:" then
			hatch(v:sub(7))
		end
	end)
end
