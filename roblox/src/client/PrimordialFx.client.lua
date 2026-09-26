-- D1 태초 · 고대 연출(클라). 모양 = docs/art/ref/15_effects.png ⑦(태초 4컷) · 수치 = shared/data/PrimordialData.
--   ③ 배너: 서버 PrimordialBanner(전 서버 태초 - 세계 번호) → 상단 가운데 배너(Toast TC - 대기열이 있어 하나씩) + 채팅 시스템 줄.
--   ① 본인 연출: 서버 PrimordialFx → 태초 = 흰 섬광 + 필드에서만 0.6초 슬로우(화면 연출 - 시야가 조이고 색이 빠졌다 돌아온다 · 게임 시간은 안 멈춘다) + 효과음 자리 ·
--      고대 = 고대 색 빛기둥(본인 화면만) + 옅은 섬광. 흰 빛기둥(전원 30초)은 서버 파트(PrimordialRegistry.spawnBeacon).
--   ⑤ 흰 오라: Attribute PrimordialEquipped인 사람 발밑에 흰 고리 + 빛 - 내 캐릭터에서 auraMaxDistance 안일 때만(외곽선 Highlight를 안 쓴다 - 외곽선 풀 상한과 무관).
--   D1-2 딜 부위 고유 연출(PrimordialData.unique): 태초 장갑 = 강공격이 맞으면 대상에 흰 번개(서버 PrimordialGlovesBolt) · 태초 신발 = 걸을 때 흰 발자국(Attribute PrimordialParts에 shoes).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local PrimordialData = require(ReplicatedStorage.Shared.data.PrimordialData)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local PrimordialStamp = require(ReplicatedStorage.Shared.PrimordialStamp)
local Toast = require(script.Parent.ui.kit.Toast)

local player = Players.LocalPlayer
local ACCENT_HEX = PrimordialData.accentColor:ToHex()

-- ── ③ 배너 + 채팅 ──
local function bannerParts(entry)
	local parts = {
		{ text = entry.no and ("★ 세계 %d번째 태초 ★ "):format(entry.no) or "★ 태초 ★ ", color = PrimordialData.auraColor, bold = true },
		{ text = tostring(entry.name or PrimordialData.fallbackName), color = PrimordialData.accentColor, bold = true },
	}
	local sourceText = PrimordialStamp.sourceText(entry.source)
	if sourceText then
		table.insert(parts, { text = " · " .. sourceText, colorName = "textPrimary" })
	end
	return parts
end

local function chatLine(entry)
	local sourceText = PrimordialStamp.sourceText(entry.source)
	return ('★ %s - <font color="#%s">%s</font>%s'):format(entry.no and ("세계 %d번째 태초"):format(entry.no) or "태초", ACCENT_HEX, tostring(entry.name or PrimordialData.fallbackName),
		sourceText and (" · " .. sourceText) or "")
end

ReplicatedStorage:WaitForChild("PrimordialBanner").OnClientEvent:Connect(function(entry)
	if type(entry) ~= "table" then
		return
	end
	Toast.push("TC", { richParts = bannerParts(entry), seconds = PrimordialData.bannerSeconds, fadeSeconds = 0.4, rainbow = true })
	local channels = TextChatService:FindFirstChild("TextChannels")
	local general = channels and channels:FindFirstChild("RBXGeneral")
	if general then
		general:DisplaySystemMessage(chatLine(entry))
	end
end)

-- ── ① 본인 연출 ──
local fxGui = Instance.new("ScreenGui")
fxGui.Name = "PrimordialFxGui"
fxGui.IgnoreGuiInset = true
fxGui.ResetOnSpawn = false
fxGui.DisplayOrder = 240 -- 창 위 · 확인창 아래
fxGui.Parent = player:WaitForChild("PlayerGui")

local function flash(color, peakTransparency, seconds)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = peakTransparency
	frame.BorderSizePixel = 0
	frame.Parent = fxGui
	local tween = TweenService:Create(frame, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
	tween:Play()
	tween.Completed:Connect(function()
		frame:Destroy()
	end)
end

-- 슬로우(필드만): 0.6초 동안 시야가 조였다가 풀리고 색이 빠졌다 돌아온다.
local restFov -- 리뷰 10: 연출이 겹쳐도 처음 시야각으로 돌아오게(진행 중 트윈 값을 기준으로 삼지 않는다)
local function slowMotion(seconds)
	local camera = Workspace.CurrentCamera
	restFov = restFov or camera.FieldOfView
	local baseFov = restFov
	task.delay(seconds + 0.1, function()
		restFov = nil
	end)
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "PrimordialSlow"
	grade.Saturation = -0.7
	grade.Brightness = 0.08
	grade.Parent = Lighting
	camera.FieldOfView = baseFov * 0.86
	TweenService:Create(camera, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { FieldOfView = baseFov }):Play()
	local back = TweenService:Create(grade, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { Saturation = 0, Brightness = 0 })
	back:Play()
	back.Completed:Connect(function()
		grade:Destroy()
	end)
end

local function playSound()
	if not PrimordialData.soundId then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = PrimordialData.soundId
	sound.Volume = 0.8
	sound.Parent = fxGui
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

local function localPillar(position, color, height, width, seconds)
	local pillar = Instance.new("Part")
	pillar.Name = "AncientPillar"
	pillar.Anchored, pillar.CanCollide, pillar.CanQuery, pillar.CanTouch, pillar.CastShadow = true, false, false, false, false
	pillar.Material = Enum.Material.Neon
	pillar.Color = color
	pillar.Transparency = 0.3
	pillar.Size = Vector3.new(width, height, width)
	pillar.CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0))
	pillar.Parent = Workspace
	task.delay(seconds, function()
		local fade = TweenService:Create(pillar, TweenInfo.new(1), { Transparency = 1 })
		fade:Play()
		fade.Completed:Connect(function()
			pillar:Destroy()
		end)
	end)
end

ReplicatedStorage:WaitForChild("PrimordialFx").OnClientEvent:Connect(function(info)
	if type(info) ~= "table" then
		return
	end
	if info.grade == "primordial" then
		flash(PrimordialData.auraColor, 0, PrimordialData.flashSeconds)
		if not info.inBoss then
			slowMotion(PrimordialData.slowSeconds)
		end
		playSound()
	elseif info.grade == "ancient" and typeof(info.position) == "Vector3" then
		local color = ItemVisualData.gradeVisuals.ancient.color
		flash(color, 0.55, 0.35)
		localPillar(info.position, color, PrimordialData.pillarHeights.ancient * 2, PrimordialData.ancientPillarWidth, PrimordialData.ancientPillarSeconds)
	end
end)

-- ── ⑤ 흰 오라 ──
local auras = {} -- [Player] = { ring, light }

local function removeAura(target)
	local aura = auras[target]
	if aura then
		aura.ring:Destroy()
		auras[target] = nil
	end
end

local function makeAura()
	local ring = Instance.new("Part")
	ring.Name = "PrimordialAura"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch, ring.CastShadow = true, false, false, false, false
	ring.Material = Enum.Material.Neon
	ring.Color = PrimordialData.auraColor
	ring.Transparency = 0.55
	ring.Size = Vector3.new(0.12, 5.5, 5.5)
	local light = Instance.new("PointLight")
	light.Color = PrimordialData.auraColor
	light.Brightness = 1.2
	light.Range = 10
	light.Parent = ring
	ring.Parent = Workspace
	return { ring = ring, light = light }
end

local spin = 0
RunService.RenderStepped:Connect(function(dt)
	spin += dt
	local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart") -- 거리 기준 = 내 캐릭터(없으면 카메라)
	local eye = myRoot and myRoot.Position or (Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame.Position)
	for _, other in ipairs(Players:GetPlayers()) do
		local character = other.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local wants = root and eye and other:GetAttribute("PrimordialEquipped") == true and (root.Position - eye).Magnitude <= PrimordialData.auraMaxDistance
		if wants then
			local aura = auras[other] or makeAura()
			auras[other] = aura
			local pulse = 0.5 + 0.1 * math.sin(spin * 3)
			aura.ring.Transparency = pulse
			aura.ring.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.8, 0)) * CFrame.Angles(0, spin, math.rad(90))
		else
			removeAura(other)
		end
	end
	for target in pairs(auras) do
		if target.Parent == nil then
			removeAura(target)
		end
	end
end)

-- ── D1-2 태초 장갑: 강공격 흰 번개(위에서 대상으로 내리꽂히는 지그재그 + 가지 - 파트 · 투명도 · 파티클 없음) ──
local UNIQUE = PrimordialData.unique
local rng = Random.new()

local function boltPart(parent, a, b, width)
	local part = Instance.new("Part")
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
	part.Material = Enum.Material.Neon
	part.Color = PrimordialData.auraColor
	local length = (b - a).Magnitude
	part.Size = Vector3.new(width, width, math.max(length, 0.05))
	part.CFrame = CFrame.lookAt((a + b) / 2, b)
	part.Parent = parent
	return part
end

local function glovesBolt(position)
	local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not myRoot or (myRoot.Position - position).Magnitude > PrimordialData.auraMaxDistance * 2 then
		return
	end
	local spec = UNIQUE.glovesBolt
	local folder = Instance.new("Folder")
	folder.Name = "PrimordialGlovesBolt"
	local top = position + Vector3.new(rng:NextNumber(-1, 1), spec.heightStuds, rng:NextNumber(-1, 1))
	local count = math.max(3, math.floor(spec.heightStuds / spec.segmentStuds))
	local prev = top
	local points = { top }
	for i = 1, count do
		local t = i / count
		local jitter = spec.jitter * (1 - t * 0.5)
		local point = i == count and position or top:Lerp(position, t) + Vector3.new(rng:NextNumber(-jitter, jitter), 0, rng:NextNumber(-jitter, jitter))
		boltPart(folder, prev, point, spec.width * (i == count and 1.6 or 1))
		table.insert(points, point)
		prev = point
	end
	for _ = 1, spec.branches do -- 짧은 가지
		local from = points[rng:NextInteger(2, math.max(2, count - 1))]
		boltPart(folder, from, from + Vector3.new(rng:NextNumber(-2, 2), -rng:NextNumber(1, 2.5), rng:NextNumber(-2, 2)), spec.width * 0.6)
	end
	folder.Parent = Workspace
	local parts = folder:GetChildren()
	local info = TweenInfo.new(spec.seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, part in ipairs(parts) do
		TweenService:Create(part, info, { Transparency = 1 }):Play()
	end
	task.delay(spec.seconds + 0.05, function()
		folder:Destroy()
	end)
end
ReplicatedStorage:WaitForChild("PrimordialGlovesBolt").OnClientEvent:Connect(glovesBolt)

-- ── D1-2 태초 신발: 흰 발자국(걸은 거리 everyStuds마다 좌우 번갈아 · lifeSeconds 동안 흐려짐 · 사람마다 최대 maxAlive개 · 오라와 같은 거리 안에서만) ──
local FOOT = UNIQUE.footprint
local walkers = {} -- [Player] = { last = Vector3, left = bool, alive = { { part, bornAt } } }

local function hasPrimordialShoes(other)
	local parts = other:GetAttribute("PrimordialParts")
	return type(parts) == "string" and parts:find("shoes", 1, true) ~= nil
end

local function clearWalker(other)
	local walker = walkers[other]
	if walker then
		for _, foot in ipairs(walker.alive) do
			foot.part:Destroy()
		end
		walkers[other] = nil
	end
end

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	for _, other in ipairs(Players:GetPlayers()) do
		local character = other.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and myRoot and hasPrimordialShoes(other) and (root.Position - myRoot.Position).Magnitude <= PrimordialData.auraMaxDistance then
			local walker = walkers[other] or { last = root.Position, left = true, alive = {} }
			walkers[other] = walker
			local flat = Vector3.new(root.Position.X - walker.last.X, 0, root.Position.Z - walker.last.Z)
			if humanoid.FloorMaterial ~= Enum.Material.Air and flat.Magnitude >= FOOT.everyStuds then
				local forward = flat.Unit
				local side = forward:Cross(Vector3.yAxis) * (walker.left and FOOT.sideOffset or -FOOT.sideOffset)
				local foot = Instance.new("Part")
				foot.Name = "PrimordialFootprint"
				foot.Anchored, foot.CanCollide, foot.CanQuery, foot.CanTouch, foot.CastShadow = true, false, false, false, false
				foot.Material = Enum.Material.SmoothPlastic -- 네온은 오라 빛에 하얗게 날아가 안 보였다(D1-2 스크린샷) - 색이 그대로 보이게
				foot.Color = FOOT.color
				foot.Size = FOOT.size
				foot.Transparency = 0.2
				local ground = root.Position - Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2 - 0.02, 0)
				foot.CFrame = CFrame.lookAt(ground + side, ground + side + forward)
				foot.Parent = Workspace
				table.insert(walker.alive, { part = foot, bornAt = now })
				if #walker.alive > FOOT.maxAlive then
					table.remove(walker.alive, 1).part:Destroy()
				end
				walker.left = not walker.left
				walker.last = root.Position
			elseif flat.Magnitude >= FOOT.everyStuds then
				walker.last = root.Position -- 공중: 발자국 없이 기준만 옮긴다
			end
		elseif walkers[other] and #walkers[other].alive == 0 then
			walkers[other] = nil
		end
	end
	for other, walker in pairs(walkers) do
		for i = #walker.alive, 1, -1 do
			local foot = walker.alive[i]
			local age = now - foot.bornAt
			if age >= FOOT.lifeSeconds then
				foot.part:Destroy()
				table.remove(walker.alive, i)
			else
				foot.part.Transparency = 0.2 + 0.8 * (age / FOOT.lifeSeconds)
			end
		end
		if other.Parent == nil then
			clearWalker(other)
		end
	end
end)

