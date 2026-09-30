-- D1 태초 · 고대 연출(클라). 모양 = docs/art/ref/15_effects.png ⑦(태초 4컷) · 수치 = shared/data/PrimordialData.
--   ③ 배너: 서버 PrimordialBanner(전 서버 태초 - 세계 번호) → 상단 가운데 배너(Toast TC - 대기열이 있어 하나씩) + 채팅 시스템 줄.
--   ① 본인 연출: 서버 PrimordialFx → 태초 = 흰 섬광 + 필드에서만 0.6초 슬로우(화면 연출 - 시야가 조이고 색이 빠졌다 돌아온다 · 게임 시간은 안 멈춘다) + 효과음 자리 ·
--      고대 = 고대 색 빛기둥(본인 화면만) + 옅은 섬광. 흰 빛기둥(전원 30초)은 서버 파트(PrimordialRegistry.spawnBeacon).
--   ⑤ 흰 오라: Attribute PrimordialEquipped인 사람 발밑에 흰 고리 + 빛 - 내 캐릭터에서 auraMaxDistance 안일 때만(외곽선 Highlight를 안 쓴다 - 외곽선 풀 상한과 무관).
--   D1-2 딜 부위 고유 연출(PrimordialData.unique): 태초 장갑 = 강공격이 맞으면 대상에 흰 번개(서버 PrimordialGlovesBolt) (태초 신발 흰 발자국은 D1-3에서 삭제 - 2단 대시(MV1)로 대체).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local PrimordialData = require(ReplicatedStorage.Shared.data.PrimordialData)
local TranscendentData = require(ReplicatedStorage.Shared.data.TranscendentData) -- C5-7
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local PrimordialStamp = require(ReplicatedStorage.Shared.PrimordialStamp)
local Toast = require(script.Parent.ui.kit.Toast)

local player = Players.LocalPlayer
local ACCENT_HEX = PrimordialData.accentColor:ToHex()

-- ── ③ 배너 + 채팅 ──
-- QUEUE-10h Q7-10: 태초 = 같은 서버 알림 칸("[이 서버]" · 무지개 없음) / 초월 = 전 서버 배너("[전 서버]" · 흑금 글자 · 무지개). 두 표시가 섞이지 않게 머리말 · 색 · 무지개가 다르다.
local function isTranscendent(entry)
	return entry.grade == TranscendentData.gradeId
end

local function bannerParts(entry)
	local global = isTranscendent(entry)
	local gradeWord = global and "초월" or "태초"
	local parts = {
		{ text = global and "[전 서버] " or "[이 서버] ", colorName = "textSecondary", bold = true },
		{ text = entry.no and ("%s 세계 %d번째 %s %s "):format(global and TranscendentData.announce.glyph or "★", entry.no, gradeWord, global and TranscendentData.announce.glyph or "★")
			or ("★ %s ★ "):format(gradeWord), color = global and TranscendentData.announce.color or PrimordialData.auraColor, bold = true },
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
	local gradeWord = isTranscendent(entry) and "초월" or "태초"
	return ('%s ★ %s - <font color="#%s">%s</font>%s'):format(isTranscendent(entry) and "[전 서버]" or "[이 서버]", entry.no and ("세계 %d번째 %s"):format(entry.no, gradeWord) or gradeWord, ACCENT_HEX, tostring(entry.name or PrimordialData.fallbackName),
		sourceText and (" · " .. sourceText) or "")
end

ReplicatedStorage:WaitForChild("PrimordialBanner").OnClientEvent:Connect(function(entry)
	if type(entry) ~= "table" then
		return
	end
	Toast.push("TC", { richParts = bannerParts(entry), seconds = isTranscendent(entry) and PrimordialData.bannerSeconds or math.max(3, PrimordialData.bannerSeconds - 2), fadeSeconds = 0.4, rainbow = isTranscendent(entry) }) -- Q7-10
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
	grade.Brightness = game:GetService("Players").LocalPlayer:GetAttribute("ReduceFlashes") and 0 or 0.08 -- Q14: 섬광 줄이기 = 화면 밝아짐 없음(채도만)
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

-- A2-N4 §3-3(A2-N3 결정 ⑧): 초월 결정(extras/transcend_crystal) - 드랍 자리에서 떠오르며 돌다 사라진다(겉모습만 · 캐시 없으면 없음)
local function transcendCrystal(position)
	local ArtMeshKit = require(ReplicatedStorage.Shared.ArtMeshKit)
	local src = ArtMeshKit.get("extras/transcend_crystal")
	local T = TranscendentData.crystalFx
	if not (src and T) then
		return
	end
	local model = src:Clone()
	model.Name = "TranscendCrystalFx"
	local parts = {}
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Size *= T.scale
			p.CFrame = CFrame.new(p.Position * T.scale) * p.CFrame.Rotation
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
			table.insert(parts, { part = p, rel = p.CFrame, base = p.Transparency })
		end
	end
	model.Parent = workspace
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t >= T.seconds or not model.Parent then
			conn:Disconnect()
			model:Destroy()
			return
		end
		local k = t / T.seconds
		local rise = T.riseStuds * math.sin(math.min(k * 2, 1) * math.pi / 2)
		local frame = CFrame.new(position + Vector3.new(0, rise, 0)) * CFrame.Angles(0, t * math.rad(T.spinDegPerSecond), 0)
		local fade = k > 0.75 and (k - 0.75) / 0.25 or 0
		for _, e in ipairs(parts) do
			e.part.CFrame = frame * e.rel
			e.part.Transparency = e.base + (1 - e.base) * fade
		end
	end)
end

ReplicatedStorage:WaitForChild("PrimordialFx").OnClientEvent:Connect(function(info)
	if type(info) ~= "table" then
		return
	end
	if info.grade == "transcendent" then -- C5-7: 흑금 섬광 + 긴 슬로우(필드에서만)
		flash(TranscendentData.announce.color, 0, PrimordialData.flashSeconds * 1.5)
		if typeof(info.position) == "Vector3" then
			transcendCrystal(info.position) -- A2-N4 §3-3(A2-N3 결정 ⑧): 초월 결정 메시(ArtStyleV1 뒤)
		end
		if not info.inBoss then
			slowMotion(TranscendentData.announce.slowSeconds)
		end
		playSound()
	elseif info.grade == "primordial" then
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
		local transcendent = (other:GetAttribute("TranscendentParts") or 0) > 0 -- C5-7 흑금 오라(초월 착용 - 태초 흰 오라보다 우선)
		local wants = root and eye and (other:GetAttribute("PrimordialEquipped") == true or transcendent) and (root.Position - eye).Magnitude <= PrimordialData.auraMaxDistance
		if wants then
			local aura = auras[other] or makeAura()
			auras[other] = aura
			local pulse = 0.5 + 0.1 * math.sin(spin * 3)
			if transcendent and other:GetAttribute("FrenzyActive") == true then
				pulse = TranscendentData.frenzy.auraTransparency + 0.05 * math.sin(spin * 6) -- C5-7b 광폭 발동 중 오라가 짙다(빠르게 맥동)
			end
			local color = transcendent and TranscendentData.announce.color or PrimordialData.auraColor
			aura.ring.Color, aura.light.Color = color, color
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

-- ── C5-7b 환영(초월 장갑): Attribute PhantomGloves인 사람 등 뒤에 흑금 무기 + 팔(임시 파트 조합 - 판정 없음) · 서버 TranscendentEvent "phantom"이 오면 대상으로 찌르고 돌아온다 ──
local PHANTOM = TranscendentData.phantom
local phantoms = {} -- [Player] = { folder, arm, blade, edge, lunge = { at, target, heavy } }

local function fxPart(parent, size, color, material)
	local part = Instance.new("Part")
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
	part.Size, part.Color, part.Material = size, color, material
	part.Transparency = PHANTOM.bodyTransparency
	part.Parent = parent
	return part
end

local function makePhantom()
	local folder = Instance.new("Folder")
	folder.Name = "TranscendentPhantom"
	local p = {
		folder = folder,
		arm = fxPart(folder, Vector3.new(0.7, 0.7, 2.2), TranscendentData.announce.darkColor, Enum.Material.SmoothPlastic),
		blade = fxPart(folder, Vector3.new(0.25, 0.5, 3.4), TranscendentData.announce.darkColor, Enum.Material.SmoothPlastic),
		edge = fxPart(folder, Vector3.new(0.08, 0.12, 3.4), TranscendentData.announce.color, Enum.Material.Neon),
	}
	folder.Parent = Workspace
	return p
end

local function removePhantom(target)
	local p = phantoms[target]
	if p then
		p.folder:Destroy()
		phantoms[target] = nil
	end
end

-- 팔(어깨 = home) → 무기가 앞(aim 방향)으로 뻗는다.
local function placePhantom(p, home, aim, scale)
	local look = aim - home
	if look.Magnitude < 1e-3 then
		return
	end
	local frame = CFrame.lookAt(home, aim)
	p.arm.CFrame = frame * CFrame.new(0, 0, -1.1)
	p.blade.CFrame = frame * CFrame.new(0, 0, -2.2 - 1.7 * scale)
	p.edge.CFrame = p.blade.CFrame * CFrame.new(0, 0.3, 0)
end

RunService.RenderStepped:Connect(function()
	local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local eye = myRoot and myRoot.Position or (Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame.Position)
	local now = os.clock()
	for _, other in ipairs(Players:GetPlayers()) do
		local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if root and eye and other:GetAttribute("PhantomGloves") == true and (root.Position - eye).Magnitude <= PrimordialData.auraMaxDistance then
			local p = phantoms[other] or makePhantom()
			phantoms[other] = p
			local home = (root.CFrame * CFrame.new(0, PHANTOM.upStuds + 0.15 * math.sin(now * 2), PHANTOM.backStuds)).Position -- 등 뒤에 떠 있다(천천히 오르내림)
			local aim = home + root.CFrame.LookVector * 4 + Vector3.new(0, 0.6, 0)
			local lunge = p.lunge
			if lunge then
				local t = now - lunge.at
				local total = PHANTOM.lungeSeconds + PHANTOM.returnSeconds
				if t >= total then
					p.lunge = nil
				else
					local k = t < PHANTOM.lungeSeconds and t / PHANTOM.lungeSeconds or 1 - (t - PHANTOM.lungeSeconds) / PHANTOM.returnSeconds
					local strikeHome = home:Lerp(lunge.target - (lunge.target - home).Unit * 3.5, k) -- 대상 앞 3.5 stud까지 찌른다
					placePhantom(p, strikeHome, lunge.target, lunge.heavy and 1.35 or 1)
					continue
				end
			end
			placePhantom(p, home, aim, 1)
		else
			removePhantom(other)
		end
	end
	for target in pairs(phantoms) do
		if target.Parent == nil then
			removePhantom(target)
		end
	end
end)

ReplicatedStorage:WaitForChild("TranscendentEvent").OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" or payload.kind ~= "phantom" or typeof(payload.position) ~= "Vector3" then
		return
	end
	local p = phantoms[payload.owner]
	if p then
		p.lunge = { at = os.clock(), target = payload.position, heavy = payload.heavy == true } -- 강공격 = 무기가 1.35배 길게 뻗는다(본인 화면은 AttackResult 강공격 불꽃도 같이)
	end
end)
