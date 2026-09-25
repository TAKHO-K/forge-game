-- BR1 대공 잡기의 그림 · 입력(docs/design/boss-br1.md §2) - 서버(BossAirGrab)가 보낸 사실만 그린다. 판정 없음.
--   grabTelegraph  아레나 전역 신호: 보스 머리 위 큰 손바닥(✋) + 보스 손 · 꼬리 · 집게 · 바람 손(motion)이 하늘로 솟는다(인형 방식 - 풀 파트)
--   grabMark       연속 체공이 warnAirSeconds를 넘은 사람 머리 위 작은 손바닥 - level(0.25 ~ 1)만큼 찬다(가득 = 잡힌다). 내 것이면 "착지!"
--   grabbed        손이 잡힌 사람의 자리로 내려와 쥔다(구출 대상 = 서버가 세운 "손" 덩어리 - 그건 서버 모델이다)
--   grabRelease · grabEnd · grabMiss  손을 치운다
--   발버둥: 내가 "grabbed"로 잡혀 있는 동안 점프 입력(PC 스페이스 · 폰 점프 버튼 - JumpRequest)을 서버에 보낸다(BossGrabStruggle - 서버가 초당 횟수를 자른다).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local Text = require(ReplicatedStorage.Shared.Text)
local BossFx = require(script.Parent.BossFx)

local BossGrabView = {}

local player = Players.LocalPlayer
local DANGER = UIColors.danger
local WHITE = Color3.new(1, 1, 1)
local struggleEvent = ReplicatedStorage:WaitForChild("BossGrabStruggle")

local live = {}
local marks = {} -- [userId] = { gui, fill }
local hands = {} -- 솟은 손 파트 목록
local followHands = {} -- [손 파트] = 잡힌 사람 userId(BR1-2 - 그 사람 루트를 따라간다)

local function newPart(size, color, transparency, shape)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	part.Size = size
	part.Transparency = transparency or 0
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

local function playerByUserId(userId)
	for _, p in ipairs(Players:GetPlayers()) do
		if p.UserId == userId then
			return p
		end
	end
	return nil
end

local function palmGui(parent, size, text)
	local gui = Instance.new("BillboardGui")
	gui.Name = "BossGrabMark"
	gui.Size = UDim2.new(0, size, 0, size)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 400
	gui.StudsOffset = Vector3.new(0, 4.2, 0)
	gui.Adornee = parent
	gui.Parent = parent
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = UIColors.panel
	back.BackgroundTransparency = 0.3
	back.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = back
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.AnchorPoint = Vector2.new(0.5, 1)
	fill.Position = UDim2.fromScale(0.5, 1)
	fill.Size = UDim2.fromScale(1, 0)
	fill.BackgroundColor3 = DANGER
	fill.BackgroundTransparency = 0.15
	fill.Parent = back
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.fromScale(1, 1)
	icon.BackgroundTransparency = 1
	icon.Font = Enum.Font.GothamBlack
	icon.TextScaled = true
	icon.Text = text
	icon.TextColor3 = WHITE
	icon.Parent = back
	live[gui] = true
	return gui, fill
end

-- ─────────────────────────── 전조 ───────────────────────────
local bigPalm = nil

function BossGrabView.telegraph(data)
	-- 보스 손(motion별 모양)이 전조 동안 하늘로 솟는다 - 큰 모션(무게 큼).
	local color = data.color or DANGER
	local shape, size, transparency = nil, Vector3.new(3.2, 1.2, 3.8), 0
	if data.motion == "tail" then
		size = Vector3.new(1.6, 1.6, 6)
	elseif data.motion == "claw" then
		size = Vector3.new(3.6, 1.2, 2.4)
	elseif data.motion == "wind" then
		shape, size, transparency, color = Enum.PartType.Cylinder, Vector3.new(6, 3.5, 3.5), 0.55, WHITE
	end
	local hand = newPart(size, color, transparency, shape)
	hand.Material = data.motion == "wind" and Enum.Material.Neon or Enum.Material.SmoothPlastic
	local base = data.center + Vector3.new(0, 4, 0)
	hand.CFrame = CFrame.new(base)
	TweenService:Create(hand, TweenInfo.new(data.seconds * 0.8, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		CFrame = CFrame.new(base + Vector3.new(0, 13, 0)) * CFrame.Angles(math.rad(-20), 0, 0),
	}):Play()
	table.insert(hands, hand)
	-- 아레나 전역 신호(BR1-2): 보스 위 "점프하지 마" 표지 - 뛰는 사람 실루엣 + 빨간 금지 원 + 시전 막대(모두에게 보인다).
	local anchor = newPart(Vector3.one * 0.2, WHITE, 1)
	anchor.CFrame = CFrame.new(base + Vector3.new(0, 18, 0))
	bigPalm = BossGrabView.noJumpSign(anchor, 130, data.seconds)
	task.delay(data.seconds + 0.1, function()
		destroy(bigPalm)
		destroy(anchor)
		bigPalm = nil
	end)
	for i = 1, 8 do
		local a = i / 8 * 2 * math.pi
		BossFx.streak(base + Vector3.new(math.cos(a) * 3, 0, math.sin(a) * 3), Vector3.new(0, 1, 0), 6, 0.3, WHITE, 0.5, 20)
	end
end

-- "점프하지 마" 표지(BillboardGui): 흰 원판 위 뛰는 사람(머리 · 몸 · 올린 팔 · 굽힌 다리 - 프레임 조각) + 빨간 원 + 사선. 아래 막대 = 남은 시전 시간.
function BossGrabView.noJumpSign(adornee, size, seconds)
	local gui = Instance.new("BillboardGui")
	gui.Name = "BossNoJumpSign"
	gui.Size = UDim2.new(0, size, 0, size + 16)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 500
	gui.Adornee = adornee
	gui.Parent = adornee
	live[gui] = true
	local disc = Instance.new("Frame")
	disc.Size = UDim2.new(0, size, 0, size)
	disc.BackgroundColor3 = WHITE
	disc.Parent = gui
	Instance.new("UICorner", disc).CornerRadius = UDim.new(1, 0)
	local function bar(x, y, w, h, rot, round)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(x, y)
		f.Size = UDim2.fromScale(w, h)
		f.Rotation = rot or 0
		f.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
		f.BorderSizePixel = 0
		f.Parent = disc
		if round then
			Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
		end
		return f
	end
	bar(0.5, 0.26, 0.16, 0.16, 0, true) -- 머리
	bar(0.5, 0.47, 0.08, 0.26, 10) -- 몸
	bar(0.38, 0.34, 0.06, 0.22, -40) -- 올린 팔
	bar(0.62, 0.34, 0.06, 0.22, 40)
	bar(0.42, 0.66, 0.07, 0.2, 35) -- 굽힌 다리(뛰는 자세)
	bar(0.58, 0.68, 0.07, 0.2, -20)
	bar(0.5, 0.86, 0.46, 0.04, 0) -- 땅
	local ring = Instance.new("Frame")
	ring.Size = UDim2.fromScale(1, 1)
	ring.BackgroundTransparency = 1
	ring.Parent = disc
	Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)
	local stroke = Instance.new("UIStroke")
	stroke.Color = DANGER
	stroke.Thickness = math.max(size * 0.07, 4)
	stroke.Parent = ring
	local slash = Instance.new("Frame")
	slash.AnchorPoint = Vector2.new(0.5, 0.5)
	slash.Position = UDim2.fromScale(0.5, 0.5)
	slash.Size = UDim2.new(1, -4, 0, math.max(size * 0.07, 4))
	slash.Rotation = 45
	slash.BackgroundColor3 = DANGER
	slash.BorderSizePixel = 0
	slash.Parent = disc
	local timeBack = Instance.new("Frame")
	timeBack.Position = UDim2.new(0, 0, 0, size + 6)
	timeBack.Size = UDim2.new(1, 0, 0, 8)
	timeBack.BackgroundColor3 = UIColors.panel
	timeBack.Parent = gui
	local timeFill = Instance.new("Frame")
	timeFill.Size = UDim2.fromScale(1, 1)
	timeFill.BackgroundColor3 = DANGER
	timeFill.BorderSizePixel = 0
	timeFill.Parent = timeBack
	TweenService:Create(timeFill, TweenInfo.new(seconds or 5, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 1) }):Play()
	-- 두근거림(눈에 띄게)
	TweenService:Create(disc, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Size = UDim2.new(0, size * 0.9, 0, size * 0.9) }):Play()
	return gui
end

function BossGrabView.mark(data)
	local entry = data.userId and marks[data.userId]
	if (data.level or 0) <= 0 then
		if entry then
			destroy(entry.gui)
			marks[data.userId] = nil
		end
		return
	end
	local target = data.userId and playerByUserId(data.userId)
	local head = target and target.Character and target.Character:FindFirstChild("Head")
	if not head then
		return
	end
	if not entry then
		local mine = target == player
		local gui, fill = palmGui(head, mine and 72 or 44, mine and Text.get("boss.grab.warn") or "✋")
		entry = { gui = gui, fill = fill }
		marks[data.userId] = entry
	end
	TweenService:Create(entry.fill, TweenInfo.new(0.12), { Size = UDim2.fromScale(1, data.level) }):Play()
end

local function clearMarks()
	for userId, entry in pairs(marks) do
		destroy(entry.gui)
		marks[userId] = nil
	end
end

function BossGrabView.grabbed(data)
	clearMarks()
	-- 솟았던 손이 잡힌 자리로 내려와 쥔다(첫 사람 자리 - 여럿이면 손을 더 만든다).
	for index, point in ipairs(data.points or {}) do
		local hand = hands[index]
		if not hand then
			hand = newPart(Vector3.new(3.2, 1.2, 3.8), data.color or DANGER, 0)
			hand.CFrame = CFrame.new(point + Vector3.new(0, 10, 0))
			table.insert(hands, hand)
		end
		TweenService:Create(hand, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(point + Vector3.new(0, 2.2, 0)) }):Play()
		BossFx.ring(point, 1, 6, WHITE, 0.3)
	end
	BossFx.shake(data.points and data.points[1] or Vector3.zero, 0.6)
end

-- 사슬(사용자 보완 A): 얼린 사람마다 캐릭터를 감싸는 얼음 덩어리(반투명 Ice - 누가 걸렸는지 한눈에). 루트가 서버에 고정돼 있어 자리를 따라갈 필요가 없다.
local ice = {} -- [userId] = Part

function BossGrabView.freeze(data)
	clearMarks()
	for index, userId in ipairs(data.userIds or {}) do
		local at = data.positions and data.positions[index]
		if at then
			local block = newPart(Vector3.new(4.2, 6, 4.2), Color3.fromRGB(190, 225, 255), 0.35)
			block.Material = Enum.Material.Ice
			block.CFrame = CFrame.new(at + Vector3.new(0, -0.5, 0))
			ice[userId] = block
			BossFx.ring(at, 1, 5, WHITE, 0.3)
		end
	end
end

-- 한 명씩 잡는다: 보스 곁에서 손이 그 사람(얼음)까지 뻗었다가(liftSeconds의 앞 절반) 들어 올려 보스 곁 들고 있는 자리로(뒤 절반). 그 사람의 얼음은 깨진다.
function BossGrabView.pick(data)
	local block = data.userId and ice[data.userId]
	if block then
		ice[data.userId] = nil
		for i = 1, 6 do
			BossFx.chunk(block.Position, Vector3.new(math.random(-10, 10), 12, math.random(-10, 10)), 0.8, Color3.fromRGB(190, 225, 255), 0.5)
		end
		destroy(block)
	end
	-- BR1-2: 사람마다 손 하나 - 들린 사람의 루트를 매 프레임 따라간다(서버가 보스 둘레로 옮긴다 - 아래 RenderStepped).
	local hand = newPart(Vector3.new(3.2, 1.2, 3.8), data.color or DANGER, 0)
	hand.CFrame = CFrame.new(data.from + Vector3.new(0, 2.2, 0))
	table.insert(hands, hand)
	followHands[hand] = data.userId
	BossFx.ring(data.from, 1, 6, WHITE, 0.3)
	BossFx.shake(data.from, 0.4)
end

-- BR1-2 던짐: 보스별 던지는 모션(motion) - 보스 곁에서 큰 호를 그리며 휘두른다(인형 방식 - 풀 파트 트윈) + 충격 고리 · 흔들림.
function BossGrabView.throw(data)
	local center = data.bossPosition or Vector3.zero
	local color = data.color or DANGER
	local size, material, transparency = Vector3.new(4, 1.4, 7), Enum.Material.SmoothPlastic, 0
	if data.motion == "tail" then
		size = Vector3.new(1.8, 1.8, 14)
	elseif data.motion == "claw" then
		size = Vector3.new(5, 1.4, 4)
	elseif data.motion == "wind" then
		size, material, transparency, color = Vector3.new(3, 10, 10), Enum.Material.Neon, 0.5, WHITE
	end
	local arm = newPart(size, color, transparency)
	arm.Material = material
	local start = math.random() * 2 * math.pi
	local radius = size.Z / 2 + 3
	local steps = 10
	for i = 0, steps do
		task.delay(0.04 * i, function()
			if arm.Parent then
				local a = start + i / steps * math.pi * 1.3
				local at = center + Vector3.new(math.cos(a) * radius, 8 - i * 0.4, math.sin(a) * radius)
				arm.CFrame = CFrame.lookAt(at, center + Vector3.new(0, 8, 0)) * CFrame.Angles(0, math.pi, 0)
			end
		end)
	end
	task.delay(0.5, function()
		destroy(arm)
	end)
	BossFx.ring(center, 2, 18, WHITE, 0.4)
	for i = 1, 10 do
		local a = i / 10 * 2 * math.pi
		BossFx.streak(center + Vector3.new(0, 8, 0), Vector3.new(math.cos(a), 0.3, math.sin(a)), 14, 0.35, WHITE, 0.4, 30)
	end
	BossFx.shake(center, 0.8)
end

-- BR1-2 공중 가둠: 갇힌 사람을 감싸는 거품(유리 공) · 회오리(흰 원통 둘) - 그 사람의 루트를 따라간다(서버가 공중에 고정). 풀리면(BossTrapKind가 바뀌면) 터진다.
local bubbles = {} -- [userId] = { parts, style }
function BossGrabView.bubble(data)
	local userId = data.userId
	if not userId or bubbles[userId] then
		return
	end
	local parts = {}
	if data.style == "tornado" then
		for i = 1, 2 do
			local ring = newPart(Vector3.new(1, 6 + i * 2, 6 + i * 2), WHITE, 0.55, Enum.PartType.Cylinder)
			ring.Material = Enum.Material.Neon
			table.insert(parts, ring)
		end
	else
		local ball = newPart(Vector3.one * 7.5, Color3.fromRGB(150, 220, 255), 0.6, Enum.PartType.Ball)
		ball.Material = Enum.Material.Glass
		table.insert(parts, ball)
	end
	bubbles[userId] = { parts = parts, style = data.style }
	BossFx.ring(data.position, 1, 6, WHITE, 0.3)
end

local function popBubble(userId)
	local entry = bubbles[userId]
	if not entry then
		return
	end
	bubbles[userId] = nil
	for _, part in ipairs(entry.parts) do
		if part.Parent then
			BossFx.puff(part.Position, 3, WHITE, 0.3, Vector3.new(0, 4, 0))
		end
		destroy(part)
	end
end

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for userId, entry in pairs(bubbles) do
		local target = playerByUserId(userId)
		local root = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
		if not root or target:GetAttribute("BossTrapKind") ~= "bubbled" then
			popBubble(userId)
		else
			for index, part in ipairs(entry.parts) do
				if entry.style == "tornado" then
					part.CFrame = CFrame.new(root.Position + Vector3.new(0, (index - 1.5) * 2, 0)) * CFrame.Angles(0, t * 8 * index, math.rad(90))
				else
					part.CFrame = CFrame.new(root.Position + Vector3.new(0, math.sin(t * 3) * 0.3, 0))
				end
			end
		end
	end
end)

function BossGrabView.unfreeze(userId)
	local block = userId and ice[userId]
	if block then
		ice[userId] = nil
		destroy(block)
	end
end

function BossGrabView.clear()
	clearMarks()
	for userId, block in pairs(ice) do
		ice[userId] = nil
		destroy(block)
	end
	for _, hand in ipairs(hands) do
		destroy(hand)
	end
	hands = {}
	followHands = {}
	if bigPalm then
		destroy(bigPalm)
		bigPalm = nil
	end
end

function BossGrabView.reset()
	BossGrabView.clear()
	for part in pairs(live) do
		part:Destroy()
	end
	live = {}
end

-- ─────────────────────────── 발버둥(내가 잡혔을 때) ───────────────────────────
UserInputService.JumpRequest:Connect(function()
	local kind = player:GetAttribute("BossTrapKind")
	if kind == "grabbed" or kind == "bubbled" then -- BR1-2: 공중 가둠도 점프 연타로 탈출
		struggleEvent:FireServer()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			BossFx.puff(root.Position + Vector3.new(0, -1, 0), 1.5, WHITE, 0.3, Vector3.new(0, 6, 0))
		end
	end
end)

-- 손이 잡힌 사람을 따라 흔들린다(발버둥 느낌 - 그림만).
RunService.RenderStepped:Connect(function()
	if #hands == 0 then
		return
	end
	local t = os.clock()
	for index, hand in ipairs(hands) do
		if hand.Parent then
			local userId = followHands[hand]
			local target = userId and playerByUserId(userId)
			local root = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
			if root then
				hand.CFrame = CFrame.new(root.Position + Vector3.new(0, -1.2, 0)) * CFrame.Angles(0, math.sin(t * 9 + index) * 0.2, 0)
			else
				hand.CFrame *= CFrame.Angles(0, math.sin(t * 9 + index) * 0.01, 0)
			end
		end
	end
end)

return BossGrabView
