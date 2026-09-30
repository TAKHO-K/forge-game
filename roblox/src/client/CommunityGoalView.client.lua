-- QUEUE-ALL1 P3 §4 전 서버 합동 목표(클라): HUD 작은 진행 알약(위 가운데 · 누르면 칸 · 받기 창) + 허브 게이지(명예의 전당 위 빌보드) + 칸 달성 배너(CommunityGoalBanner).
--   값 = Workspace 속성 CommunityGoalTotal · Target(서버 CommunityGoalService) · 내 기여 · 받은 칸 = Player 속성. 수치 · 문구 = shared/data/CommunityGoalData.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local D = require(ReplicatedStorage.Shared.data.CommunityGoalData)
local Rules = require(ReplicatedStorage.Shared.CommunityGoalRules)
local Theme = require(script.Parent.ui.kit.Theme)
local Toast = require(script.Parent.ui.kit.Toast)

local player = Players.LocalPlayer
local GOLD = Color3.fromRGB(255, 214, 90)
local INK = Color3.fromRGB(30, 27, 46)

local gui = Instance.new("ScreenGui")
gui.Name = "CommunityGoalHud"
gui.ResetOnSpawn = false
gui.DisplayOrder = 19
gui.Parent = player:WaitForChild("PlayerGui")

-- HUD 알약: 막대 + 글씨(누르면 창)
local pill = Instance.new("TextButton")
pill.Name = "CommunityGoalPill"
pill.AnchorPoint = Vector2.new(0.5, 0)
pill.Position = UDim2.new(0.5, 0, 0, 36)
pill.Size = UDim2.fromOffset(210, 24)
pill.BackgroundColor3 = INK
pill.BackgroundTransparency = 0.25
pill.AutoButtonColor = true
pill.Text = ""
pill.Parent = gui
pill.Visible = false -- QUEUE-ALL3 Q3 중복 삭제: 합동 목표 = 퀘스트 창(J) [전 서버 협동] 탭 · 허브 게이지 · 달성 배너는 그대로
Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)
local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.BackgroundColor3 = GOLD
fill.BackgroundTransparency = 0.35
fill.BorderSizePixel = 0
fill.Size = UDim2.fromScale(0, 1)
fill.Parent = pill
Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
for i, t in ipairs(D.tiers) do -- 칸 눈금
	local tick = Instance.new("Frame")
	tick.Name = "Tick" .. i
	tick.BackgroundColor3 = Color3.new(1, 1, 1)
	tick.BorderSizePixel = 0
	tick.Size = UDim2.fromOffset(2, 24)
	tick.Position = UDim2.new(math.min(t.fraction, 0.995), 0, 0, 0)
	tick.Parent = pill
end
local pillText = Instance.new("TextLabel")
pillText.BackgroundTransparency = 1
pillText.Size = UDim2.fromScale(1, 1)
pillText.Font = Theme.font
pillText.TextSize = 13
pillText.TextColor3 = Color3.new(1, 1, 1)
pillText.TextStrokeTransparency = 0.5
pillText.ZIndex = 3
pillText.Parent = pill

-- 칸 · 받기 창
local panel = Instance.new("Frame")
panel.Name = "CommunityGoalPanel"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 66)
panel.Size = UDim2.fromOffset(340, 64 + #D.tiers * 40)
panel.BackgroundColor3 = INK
panel.BackgroundTransparency = 0.08
panel.Visible = false
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(12, 6)
title.Size = UDim2.new(1, -24, 0, 24)
title.Font = Theme.font
title.TextSize = 16
title.TextColor3 = GOLD
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = D.text.panelTitle
title.Parent = panel
local metric = Instance.new("TextLabel")
metric.BackgroundTransparency = 1
metric.Position = UDim2.fromOffset(12, 30)
metric.Size = UDim2.new(1, -24, 0, 20)
metric.Font = Theme.fontBody
metric.TextSize = 12
metric.TextColor3 = Color3.fromRGB(200, 200, 214)
metric.TextXAlignment = Enum.TextXAlignment.Left
metric.Text = D.text.metric
metric.Parent = panel
local rows = {}
for i, t in ipairs(D.tiers) do
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(12, 56 + (i - 1) * 40)
	label.Size = UDim2.new(1, -120, 0, 32)
	label.Font = Theme.fontBody
	label.TextSize = 14
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = ("%d%% · %s"):format(math.floor(t.fraction * 100 + 0.5), t.label)
	label.Parent = panel
	local btn = Instance.new("TextButton")
	btn.Name = "Claim" .. i
	btn.Position = UDim2.new(1, -100, 0, 58 + (i - 1) * 40)
	btn.Size = UDim2.fromOffset(88, 28)
	btn.BackgroundColor3 = Color3.fromRGB(70, 60, 110)
	btn.Font = Theme.font
	btn.TextSize = 13
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Parent = panel
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
	btn.Activated:Connect(function()
		local ok, result = pcall(function()
			return ReplicatedStorage:WaitForChild("CommunityGoalClaim"):InvokeServer(i)
		end)
		if ok and type(result) == "table" then
			Toast.push("TC", { richParts = { { text = (result.ok and "받음: " or "") .. tostring(result.message), color = result.ok and GOLD or Color3.fromRGB(230, 230, 240), bold = true } }, seconds = 3, fadeSeconds = 0.3 })
		end
	end)
	rows[i] = btn
end
pill.Activated:Connect(function()
	panel.Visible = not panel.Visible
end)

-- 허브 게이지(명예의 전당 위 빌보드 - 허브에 가면 보인다)
local board = nil
local function ensureBoard()
	if board and board.Parent then
		return board
	end
	local hof = Workspace:FindFirstChild("HallOfFame")
	local adornee = hof and (hof.PrimaryPart or hof:FindFirstChildWhichIsA("BasePart", true))
	if not adornee then
		return nil
	end
	board = Instance.new("BillboardGui")
	board.Name = "CommunityGoalBoard"
	board.Size = UDim2.fromOffset(260, 56)
	board.StudsOffsetWorldSpace = Vector3.new(0, 16, 0)
	board.MaxDistance = 160
	board.Adornee = adornee
	board.Parent = gui
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = INK
	bg.BackgroundTransparency = 0.2
	bg.Parent = board
	Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 10)
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Position = UDim2.new(0, 10, 1, -20)
	bar.Size = UDim2.new(1, -20, 0, 10)
	bar.BackgroundColor3 = Color3.fromRGB(60, 56, 80)
	bar.Parent = bg
	local barFill = Instance.new("Frame")
	barFill.Name = "Fill"
	barFill.BackgroundColor3 = GOLD
	barFill.Size = UDim2.fromScale(0, 1)
	barFill.Parent = bar
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.BackgroundTransparency = 1
	text.Position = UDim2.fromOffset(10, 4)
	text.Size = UDim2.new(1, -20, 0, 26)
	text.Font = Theme.font
	text.TextSize = 16
	text.TextColor3 = Color3.new(1, 1, 1)
	text.Parent = bg
	return board
end

local function refresh()
	local total = Workspace:GetAttribute("CommunityGoalTotal") or 0
	local target = Workspace:GetAttribute("CommunityGoalTarget")
	local frac = (type(target) == "number" and target > 0) and math.clamp(total / target, 0, 1) or 0
	fill.Size = UDim2.fromScale(frac, 1)
	pillText.Text = (type(target) == "number" and target > 0) and D.text.hud:format(math.floor(frac * 100)) or D.text.measuring
	local reached = Rules.tiersReached(total, target)
	local claimed = {}
	for k in tostring(player:GetAttribute("CommunityGoalClaimed") or ""):gmatch("[^,]+") do
		claimed[tonumber(k) or 0] = true
	end
	for i, btn in ipairs(rows) do
		btn.Text = claimed[i] and D.text.claimed or (i <= reached and D.text.claim or D.text.locked)
		btn.AutoButtonColor = i <= reached and not claimed[i]
		btn.BackgroundTransparency = (i <= reached and not claimed[i]) and 0 or 0.5
	end
	local b = ensureBoard()
	if b then
		local bg = b:FindFirstChildOfClass("Frame")
		bg.Bar.Fill.Size = UDim2.fromScale(frac, 1)
		bg.Text.Text = ("%s · %s"):format(D.text.panelTitle, (type(target) == "number" and target > 0) and ("%d / %d"):format(total, target) or "목표 계산 중")
	end
end
for _, a in ipairs({ "CommunityGoalTotal", "CommunityGoalTarget" }) do
	Workspace:GetAttributeChangedSignal(a):Connect(refresh)
end
player:GetAttributeChangedSignal("CommunityGoalClaimed"):Connect(refresh)
Workspace.ChildAdded:Connect(function(c)
	if c.Name == "HallOfFame" then
		task.defer(refresh)
	end
end)
refresh()

ReplicatedStorage:WaitForChild("CommunityGoalBanner").OnClientEvent:Connect(function(info)
	if type(info) == "table" then
		Toast.push("TC", { richParts = { { text = D.text.tierBanner:format(info.percent or 0, tostring(info.label or "")), color = GOLD, bold = true } }, seconds = 6, fadeSeconds = 0.4, rainbow = info.tier == #D.tiers })
	end
end)
