-- 오늘의 목표 칸(QUEUE-ALL2 P2 B-4 ③ · QUEUE-ALL3 Q3 "메인 지금 단계를 1순위"). 왼쪽 메뉴 아래 작은 칸 - 1 ~ 3줄(메인 지금 단계 · 수련 가능 · 안 끝난 일간 1개) + 진행도.
--   줄을 누르면 그 목표의 길 안내(QuestGuide - 메인 guide · 수련 = 수련 창 · 일간 = 퀘스트 창). 보스전 중 · 최근 4초 안에 맞았으면(전투) 접힌다(제목 한 줄만).
--   폰 = 한 줄(메인만) · 메뉴 격자 오른쪽. 값 = QuestUpdate(서버 표)만 - 계산 안 함.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Text = require(ReplicatedStorage.Shared.Text)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local UIManager = require(script.Parent.Parent.UIManager)

local player = Players.LocalPlayer
local updateRemote = ReplicatedStorage:WaitForChild("QuestUpdate")

local WIDTH_PC, WIDTH_PHONE = 250, 220
local LINE_H = 34
local COMBAT_SECONDS = 4

local gui = Instance.new("ScreenGui")
gui.Name = "TodayGoalGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 4
gui.Parent = player:WaitForChild("PlayerGui")

local box = Instance.new("Frame")
box.Name = "TodayGoal"
box.BackgroundColor3 = Theme.color("panel")
box.BackgroundTransparency = 0.25
box.Parent = gui
Theme.corner(box, 10)
Theme.stroke(box)
local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 2)
layout.Parent = box
local pad = Instance.new("UIPadding")
pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8), UDim.new(0, 4), UDim.new(0, 4)
pad.Parent = box
local title = Theme.label(box, Text.get("today.title"), "caption", "gold")
title.Name = "Title"
title.LayoutOrder = 0
title.Size = UDim2.new(1, 0, 0, 18)

local view
local lines = {}
local lastHp, hitAt = nil, -math.huge

local function line(i, text, n, target, onPress)
	local b = lines[i]
	if not b then
		b = Instance.new("TextButton")
		b.Name = "Goal" .. i
		b.LayoutOrder = i
		b.BackgroundTransparency = 1
		b.AutoButtonColor = false
		b.Text = ""
		b.Size = UDim2.new(1, 0, 0, LINE_H)
		b.Parent = box
		local l = Theme.label(b, "", "body", "textPrimary")
		l.Name = "Label"
		l.Size = UDim2.new(1, -50, 1, 0)
		l.TextTruncate = Enum.TextTruncate.AtEnd
		local c = Theme.label(b, "", "caption", "success")
		c.Name = "Count"
		c.AnchorPoint = Vector2.new(1, 0)
		c.Position = UDim2.fromScale(1, 0)
		c.Size = UDim2.new(0, 50, 1, 0)
		c.TextXAlignment = Enum.TextXAlignment.Right
		b.Activated:Connect(function()
			if b:GetAttribute("Busy") then
				return
			end
			local fn = lines[i] and lines[i].press
			if fn then
				fn()
			end
		end)
		lines[i] = b
	end
	b.Visible = true
	b.Label.Text = text
	b.Count.Text = target and ("%d/%d"):format(n or 0, target) or ""
	b.press = onPress
end

local function collapsed()
	return player:GetAttribute("BossEncounterId") ~= nil or os.clock() - hitAt < COMBAT_SECONDS
end

local function place()
	local menu = player.PlayerGui:FindFirstChild("MenuBarGui") and player.PlayerGui.MenuBarGui:FindFirstChild("MenuBar")
	local width = Theme.isMobile and WIDTH_PHONE or WIDTH_PC
	if menu and menu.AbsoluteSize.Y > 0 then
		local offset = gui.AbsolutePosition
		local below = menu.AbsolutePosition.Y - offset.Y + menu.AbsoluteSize.Y + 10
		local need = 26 + 3 * (LINE_H + 2)
		if Theme.isMobile or below + need > gui.AbsoluteSize.Y - 40 then -- 폰 · 메뉴 아래 자리가 모자라면 = 메뉴 오른쪽 위
			box.Position = UDim2.fromOffset(menu.AbsolutePosition.X - offset.X + menu.AbsoluteSize.X + 10, menu.AbsolutePosition.Y - offset.Y)
		else
			box.Position = UDim2.fromOffset(menu.AbsolutePosition.X - offset.X, below)
		end
	end
	local shown = 0
	for _, b in ipairs(lines) do
		if b.Visible then
			shown += 1
		end
	end
	box.Size = UDim2.fromOffset(width, 26 + shown * (LINE_H + 2))
end

local function refresh()
	for _, b in ipairs(lines) do
		b.Visible = false
	end
	local hide = collapsed() or player:GetAttribute("ClassId") == nil or player:GetAttribute("ClassId") == ""
	box.Visible = view ~= nil and player:GetAttribute("BossEncounterId") == nil
	if not view or hide then
		place()
		return
	end
	local i = 0
	if view.main then
		i += 1
		local m = view.main
		line(i, m.name, m.n, m.target, function()
			if m.done then
				require(script.Parent.Parent.panels.Quests).open("main")
			elseif m.guide then
				require(script.Parent.Parent.QuestGuide).go(m.guide, false)
			else
				require(script.Parent.Parent.panels.Quests).open("main")
			end
		end)
	end
	local maxLines = Theme.isMobile and 1 or 3
	if i < maxLines and player:GetAttribute("TrainingReady") == true then
		i += 1
		line(i, Text.get("today.training"), nil, nil, function()
			UIManager.openLazy("training")
		end)
	end
	for _, q in ipairs(view.daily or {}) do
		if i >= maxLines then
			break
		end
		if q.n < q.target then
			i += 1
			line(i, q.name, q.n, q.target, function()
				require(script.Parent.Parent.panels.Quests).open("daily")
			end)
			break
		end
	end
	place()
end

updateRemote.OnClientEvent:Connect(function(v)
	view = v
	refresh()
end)
for _, name in ipairs({ "TrainingReady", "BossEncounterId", "ClassId" }) do
	player:GetAttributeChangedSignal(name):Connect(refresh)
end
-- 전투(맞음) 감지 = 체력이 줄면 COMBAT_SECONDS 동안 접힘
local wasCollapsed = false
RunService.Heartbeat:Connect(function()
	local hp = player:GetAttribute("Hp")
	if lastHp and hp and hp < lastHp - 0.01 then
		hitAt = os.clock()
	end
	lastHp = hp
	local now = collapsed()
	if now ~= wasCollapsed then
		wasCollapsed = now
		refresh()
	end
end)
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
task.spawn(function()
	local menuGui = player.PlayerGui:WaitForChild("MenuBarGui", 30)
	local menu = menuGui and menuGui:WaitForChild("MenuBar", 10)
	if menu then
		menu:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
		menu:GetPropertyChangedSignal("AbsolutePosition"):Connect(place)
	end
	place()
end)
if RunService:IsStudio() then
	player:GetAttributeChangedSignal("ForceTouchLayout"):Connect(function()
		task.defer(refresh)
	end)
end
