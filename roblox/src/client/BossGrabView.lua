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
	-- 아레나 전역 신호: 보스 위 큰 손바닥(모두에게 보인다).
	local anchor = newPart(Vector3.one * 0.2, WHITE, 1)
	anchor.CFrame = CFrame.new(base + Vector3.new(0, 18, 0))
	bigPalm = palmGui(anchor, 110, "✋")
	local fill = bigPalm:FindFirstChild("Fill", true)
	if fill then
		TweenService:Create(fill, TweenInfo.new(data.seconds, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) }):Play()
	end
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
	local hand = hands[1]
	if not hand then
		hand = newPart(Vector3.new(3.2, 1.2, 3.8), data.color or DANGER, 0)
		hand.CFrame = CFrame.new(data.bossPosition + Vector3.new(0, 14, 0))
		table.insert(hands, hand)
	end
	local half = math.max(data.liftSeconds / 2, 0.05)
	TweenService:Create(hand, TweenInfo.new(half, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(data.from + Vector3.new(0, 2.2, 0)) }):Play()
	task.delay(half, function()
		if hand.Parent then
			TweenService:Create(hand, TweenInfo.new(half, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = CFrame.new(data.point + Vector3.new(0, 2.2, 0)) }):Play()
		end
	end)
	BossFx.shake(data.from, 0.4)
end

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
	if player:GetAttribute("BossTrapKind") == "grabbed" then
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
			hand.CFrame *= CFrame.Angles(0, math.sin(t * 9 + index) * 0.01, 0)
		end
	end
end)

return BossGrabView
