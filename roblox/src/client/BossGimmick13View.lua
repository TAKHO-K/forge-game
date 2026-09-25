-- BR1-3 전멸기 두 개의 그림 · 소리 · 화면 표시 - 서버(BossSandSearch · BossOrgel)가 보낸 사실만. 판정 없음.
--   진짜 전갈 찾기: 파고드는 먼지 → 진짜 둔덕 뒤 발자국(꼬리 끝 빛은 서버 파트) · 화면 "빛나는 꼬리를 찾아라! 14" → 가짜 폭발 · 튀어나옴 / 전부 폭발
--   수정 오르골: 왕관 → 종이 하나씩 크게 흔들리며 반짝 + 음 → 화면 "0/5 · 남은 초" → 맞음(짧게 반짝) · 틀림(삐빅 · 빨강 · 처음부터) → 성공(왕관 깨짐) /
--               실패 = 수정 조각상(사람마다 다른 포즈 + 표정) → 찰칵(화면 번쩍) → 톡 → 와장창
-- 소리: 사운드 에셋이 없어 기본 내장 음(rbxasset)을 음높이만 바꿔 쓴다 - 에셋 목록은 BR1-3 보고서(종 5음 · 삐빅 · 찰칵 · 와장창).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local BossFx = require(script.Parent.BossFx)

local BossGimmick13View = {}

local player = Players.LocalPlayer
local WHITE = Color3.new(1, 1, 1)
local DUST = Color3.fromRGB(235, 228, 214)
local RED = Color3.fromRGB(230, 40, 40)
local TEMP_SOUND = { ping = "rbxasset://sounds/electronicpingshort.wav", click = "rbxasset://sounds/clickfast.wav" }

local live = {}
local hud = nil -- ScreenGui { label }
local sand = nil -- { realIndex, every, life, lastAt, connection }
local orgel = nil -- { palette, bells, length, progress, endsAt, crown, statues }

local function newPart(size, color, transparency, shape, material)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = material or Enum.Material.Neon
	part.Color = color
	part.Size = size
	part.Transparency = transparency or 0.4
	if shape then
		part.Shape = shape
	end
	part.Parent = Workspace
	live[part] = true
	return part
end

local function destroy(part)
	if part and live[part] then
		live[part] = nil
		part:Destroy()
	end
end

local function fadeOut(part, seconds)
	if not live[part] then
		return
	end
	TweenService:Create(part, TweenInfo.new(seconds), { Transparency = 1 }):Play()
	task.delay(seconds, function()
		destroy(part)
	end)
end

local function play(kind, pitch, volume)
	local sound = Instance.new("Sound")
	sound.SoundId = TEMP_SOUND[kind]
	sound.PlaybackSpeed = pitch or 1
	sound.Volume = volume or 0.6
	SoundService:PlayLocalSound(sound)
	task.delay(2, function()
		sound:Destroy()
	end)
end

-- 화면 위 가운데 한 줄(폰에서도 읽히게 크게 - TextScaled · 화면 너비 비율).
local function setHud(text, color)
	if not hud then
		local gui = Instance.new("ScreenGui")
		gui.Name = "BossGimmickHud"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 20
		local label = Instance.new("TextLabel")
		label.AnchorPoint = Vector2.new(0.5, 0)
		label.Position = UDim2.new(0.5, 0, 0.12, 0)
		label.Size = UDim2.new(0.6, 0, 0.07, 0)
		label.BackgroundTransparency = 0.35
		label.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
		label.TextScaled = true
		label.Font = Enum.Font.GothamBlack
		label.TextStrokeTransparency = 0.3
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.25, 0)
		corner.Parent = label
		label.Parent = gui
		gui.Parent = player:WaitForChild("PlayerGui")
		hud = { gui = gui, label = label }
	end
	hud.label.Text = text
	hud.label.TextColor3 = color or WHITE
end

local function clearHud()
	if hud then
		hud.gui:Destroy()
		hud = nil
	end
end

local function taggedWith(attribute, value)
	for _, model in ipairs(CollectionService:GetTagged("RescueTarget")) do
		if model:GetAttribute(attribute) == value and model.Parent then
			return model
		end
	end
	return nil
end

local function playerByUserId(userId)
	for _, p in ipairs(Players:GetPlayers()) do
		if p.UserId == userId then
			return p
		end
	end
	return nil
end

-- ─────────────────────────── 진짜 전갈 찾기 ───────────────────────────
local function clearSand()
	if sand then
		if sand.connection then
			sand.connection:Disconnect()
		end
		sand = nil
	end
end

function BossGimmick13View.sandDig(data)
	for i = 1, 14 do
		local a = i / 14 * 2 * math.pi
		task.delay(data.seconds * i / 14, function()
			BossFx.puff(data.center + Vector3.new(math.cos(a) * 4, 1, math.sin(a) * 4), 3.5, DUST, 0.8, Vector3.new(0, 5, 0))
		end)
	end
	BossFx.shake(data.center, 0.6)
end

function BossGimmick13View.sandStart(data)
	clearSand()
	sand = { realIndex = data.realIndex, lastAt = 0, endsAt = os.clock() + data.seconds, floorY = data.floorY }
	sand.connection = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		setHud(("빛나는 꼬리를 찾아 때려라! %d"):format(math.max(0, math.ceil(sand.endsAt - now))), Color3.fromRGB(255, 214, 90))
		if now - sand.lastAt < data.footprintEvery then
			return
		end
		sand.lastAt = now
		local mound = taggedWith("SandMound", sand.realIndex)
		local body = mound and mound:FindFirstChild("Body")
		if body then
			-- 발자국: 둔덕 뒤에 작은 어두운 자국 두 개(좌우) - footprintSeconds 동안 옅어진다
			local look = body.CFrame.LookVector
			local side = Vector3.new(-look.Z, 0, look.X)
			for _, s in ipairs({ 1, -1 }) do
				local at = Vector3.new(body.Position.X, sand.floorY, body.Position.Z) - look * (body.Size.Z / 2 + 0.8) + side * 0.9 * s
				local print_ = newPart(Vector3.new(0.12, 1.1, 1.1), Color3.fromRGB(90, 70, 45), 0.15, Enum.PartType.Cylinder, Enum.Material.SmoothPlastic)
				print_.CFrame = CFrame.new(at + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
				fadeOut(print_, data.footprintSeconds)
			end
		end
	end)
end

function BossGimmick13View.sandBlast(data)
	if data.position then
		for i = 1, 10 do
			local a = i / 10 * 2 * math.pi
			BossFx.puff(data.position + Vector3.new(math.cos(a) * 2, 1.5, math.sin(a) * 2), 3, DUST, 0.6, Vector3.new(math.cos(a) * 6, 6, math.sin(a) * 6))
		end
		BossFx.shake(data.position, 0.4)
	end
end

function BossGimmick13View.sandEnd(data)
	clearSand()
	clearHud()
	if data.interrupted then
		return
	end
	if data.success and data.position then
		for i = 1, 16 do
			local a = i / 16 * 2 * math.pi
			BossFx.chunk(data.position, Vector3.new(math.cos(a) * 18, 24, math.sin(a) * 18), 1.1, DUST, 0.8)
		end
		BossFx.shake(data.position, 1)
	else
		for _, position in ipairs(data.positions or {}) do
			BossFx.ring(position + Vector3.new(0, 0.5, 0), 2, 16, RED, 0.5)
			for i = 1, 8 do
				local a = i / 8 * 2 * math.pi
				BossFx.chunk(position, Vector3.new(math.cos(a) * 16, 20, math.sin(a) * 16), 1.2, DUST, 0.8)
			end
			BossFx.shake(position, 1)
		end
	end
end

-- ─────────────────────────── 수정 오르골 ───────────────────────────
local function flashBell(index, color, big)
	local bell = taggedWith("OrgelBell", index)
	local body = bell and bell:FindFirstChild("Body")
	if not body then
		return
	end
	local glow = newPart(body.Size * (big and 1.8 or 1.3), color, 0.2, Enum.PartType.Ball)
	glow.CFrame = body.CFrame
	TweenService:Create(glow, TweenInfo.new(big and 0.6 or 0.3), { Transparency = 1, Size = body.Size * (big and 2.4 or 1.6) }):Play()
	task.delay(big and 0.6 or 0.3, function()
		destroy(glow)
	end)
	if big then
		-- 크게 흔들림(종 모델을 이 화면에서만 좌우로 - 서버 자리는 그대로)
		local base = bell:GetPivot()
		for k = 1, 6 do
			task.delay(k * 0.06, function()
				if bell.Parent then
					bell:PivotTo(base * CFrame.Angles(0, 0, math.rad((k % 2 == 0 and 1 or -1) * 14 * (1 - k / 7))))
				end
			end)
		end
		task.delay(0.45, function()
			if bell.Parent then
				bell:PivotTo(base)
			end
		end)
	end
end

function BossGimmick13View.orgelStart(data)
	orgel = { palette = data.palette, length = data.length, progress = 0 }
	-- 왕관을 들어 올린다: 보스 머리 위 노란 뾰족 고리가 솟는다
	local crown = {}
	for i = 1, 5 do
		local a = i / 5 * 2 * math.pi
		local spike = newPart(Vector3.new(0.6, 1.6, 0.6), Color3.fromRGB(255, 220, 90), 0, nil, Enum.Material.Neon)
		spike.CFrame = CFrame.new(data.center + Vector3.new(math.cos(a) * 1.4, 9, math.sin(a) * 1.4))
		TweenService:Create(spike, TweenInfo.new(data.seconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = spike.CFrame + Vector3.new(0, 5, 0) }):Play()
		table.insert(crown, spike)
	end
	orgel.crown = crown
	setHud("♪ 순서를 기억하라!", Color3.fromRGB(180, 230, 255))
end

function BossGimmick13View.orgelRing(data)
	if not orgel then
		return
	end
	local spec = orgel.palette[data.bell]
	flashBell(data.bell, spec and spec.color or WHITE, true)
	play("ping", spec and spec.note or 1, 0.8)
end

function BossGimmick13View.orgelInput(data)
	if not orgel then
		return
	end
	orgel.endsAt = os.clock() + data.seconds
	orgel.connection = RunService.RenderStepped:Connect(function()
		if orgel and orgel.endsAt then
			setHud(("♪ 같은 순서로 두드려라  %d/%d · %d"):format(orgel.progress, orgel.length, math.max(0, math.ceil(orgel.endsAt - os.clock()))), orgel.wrongUntil and os.clock() < orgel.wrongUntil and RED or WHITE)
		end
	end)
end

function BossGimmick13View.orgelHit(data)
	if not orgel then
		return
	end
	orgel.progress = data.progress
	local spec = orgel.palette[data.bell]
	if data.ok then
		flashBell(data.bell, spec and spec.color or WHITE, false)
		play("ping", spec and spec.note or 1, 0.5)
	else
		orgel.wrongUntil = os.clock() + 0.8
		flashBell(data.bell, RED, false)
		play("ping", 0.45, 0.8) -- 삐
		task.delay(0.12, function()
			play("ping", 0.45, 0.8) -- 빅
		end)
		local bell = taggedWith("OrgelBell", data.bell)
		if bell and bell.PrimaryPart then
			for i = 1, 5 do
				BossFx.streak(bell.PrimaryPart.Position + Vector3.new(0, 2, 0), Vector3.new(math.random() - 0.5, 1, math.random() - 0.5).Unit, 3, 0.3, Color3.fromRGB(120, 200, 255), 0.25, 0)
			end
		end
	end
end

-- 조각상 포즈(인형 방식 - 이 화면의 그림만): 수정 덩어리 기울기 + 머리 위 표정. 1 만세 · 2 엉덩방아 · 3 놀람 · 4 발끝
local POSES = {
	{ face = "🙌", tilt = CFrame.Angles(0, 0, 0), lift = 0.6 },
	{ face = "😵", tilt = CFrame.Angles(math.rad(-28), 0, 0), lift = -1.2 },
	{ face = "😲", tilt = CFrame.Angles(0, 0, math.rad(14)), lift = 0 },
	{ face = "🩰", tilt = CFrame.Angles(math.rad(10), 0, math.rad(-10)), lift = 1.2 },
}

function BossGimmick13View.orgelStatue(data)
	if not orgel then
		orgel = { palette = {}, length = 0, progress = 0 }
	end
	if orgel.connection then
		orgel.connection:Disconnect()
		orgel.connection = nil
	end
	setHud("…여왕의 수정 장식품이 되었다!", Color3.fromRGB(180, 230, 255))
	local statues = {}
	orgel.statues = statues
	for i, userId in ipairs(data.userIds) do
		local pose = POSES[data.poses[i]] or POSES[1]
		local at = data.positions[i]
		local block = newPart(Vector3.new(4, 6.5, 4), Color3.fromRGB(170, 225, 255), 0.45, nil, Enum.Material.Glass)
		block.CFrame = CFrame.new(at + Vector3.new(0, pose.lift, 0)) * pose.tilt
		local face = Instance.new("BillboardGui")
		face.Size = UDim2.new(0, 70, 0, 70)
		face.StudsOffset = Vector3.new(0, 4.5, 0)
		face.LightInfluence = 0
		face.Adornee = block
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = pose.face
		label.TextScaled = true
		label.Parent = face
		face.Parent = block
		table.insert(statues, block)
		-- 내 캐릭터는 이 화면에서 포즈 기울기를 같이 준다(잡힌 동안 고정 - 풀리면 서버 자리로)
		local target = playerByUserId(userId)
		if target == player and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
			local root = target.Character.HumanoidRootPart
			root.CFrame = root.CFrame * pose.tilt
		end
	end
	task.delay(data.flashAt, function()
		-- 찰칵: 화면 번쩍
		local gui = Instance.new("ScreenGui")
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 30
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = WHITE
		frame.BackgroundTransparency = 0
		frame.Parent = gui
		gui.Parent = player:WaitForChild("PlayerGui")
		play("click", 1, 1)
		TweenService:Create(frame, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		task.delay(0.55, function()
			gui:Destroy()
		end)
	end)
	task.delay(data.tapAt, function()
		for _, block in ipairs(statues) do
			if live[block] then
				BossFx.ring(block.Position + Vector3.new(0, 2, 0), 0.5, 3, WHITE, 0.3) -- 톡
			end
		end
	end)
	task.delay(data.shatterAt, function()
		for _, block in ipairs(statues) do
			if live[block] then
				for k = 1, 10 do
					BossFx.chunk(block.Position, Vector3.new(math.random(-16, 16), math.random(10, 26), math.random(-16, 16)), 0.9, Color3.fromRGB(170, 225, 255), 0.9)
				end
				destroy(block)
			end
		end
		play("ping", 2.2, 1) -- 와장창(임시)
		BossFx.shake(data.positions[1] or Vector3.zero, 1)
	end)
end

function BossGimmick13View.orgelEnd(data)
	if orgel then
		if orgel.connection then
			orgel.connection:Disconnect()
		end
		for _, spike in ipairs(orgel.crown or {}) do
			if data.success and live[spike] then
				BossFx.chunk(spike.Position, Vector3.new(math.random(-10, 10), 14, math.random(-10, 10)), 0.6, Color3.fromRGB(255, 220, 90), 0.7) -- 왕관이 깨진다
			end
			destroy(spike)
		end
		if data.interrupted then
			for _, block in ipairs(orgel.statues or {}) do
				destroy(block)
			end
		end
	end
	if data.success then
		setHud("왕관이 깨졌다!", Color3.fromRGB(120, 200, 255))
		task.delay(1.5, clearHud)
	else
		task.delay(data.interrupted and 0 or 1.2, clearHud)
	end
	orgel = nil
end

function BossGimmick13View.reset()
	clearSand()
	clearHud()
	if orgel and orgel.connection then
		orgel.connection:Disconnect()
	end
	orgel = nil
	for part in pairs(live) do
		part:Destroy()
	end
	live = {}
end

return BossGimmick13View
