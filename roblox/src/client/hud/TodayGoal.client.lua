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
local presses = {} -- 줄 번호 → 누르면 할 일(인스턴스에 필드를 못 붙인다)
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
			local fn = presses[i]
			if fn then
				fn()
			end
		end)
		lines[i] = b
	end
	b.Visible = true
	b.Label.Text = text
	b.Count.Text = target and ("%d/%d"):format(n or 0, target) or ""
	presses[i] = onPress
end

local function collapsed()
	return player:GetAttribute("BossEncounterId") ~= nil or os.clock() - hitAt < COMBAT_SECONDS
end

local HudData = require(game:GetService("ReplicatedStorage").Shared.data.HudData)
local HudLayout = require(game:GetService("ReplicatedStorage").Shared.data.UiLayoutData).hud
local function place()
	local menu = player.PlayerGui:FindFirstChild("MenuBarGui") and player.PlayerGui.MenuBarGui:FindFirstChild("MenuBar")
	local width = Theme.isMobile and WIDTH_PHONE or WIDTH_PC
	if HudData.menuV5 then -- QUEUE-UI2 UI2-4 HUD v5: 메인 퀘스트 = 오른쪽 위(재화 · 스테이지 아래 - UiLayoutData.hud.quest · 화면 오른쪽 끝 기준)
		local q = Theme.isMobile and HudLayout.phone.quest or HudLayout.pc.quest
		local base = Theme.isMobile and { 800, 360 } or { 1920, 1080 }
		local s = math.min(gui.AbsoluteSize.X / base[1], gui.AbsoluteSize.Y / base[2])
		local boxScale = box:FindFirstChild("HudV5Scale") or Instance.new("UIScale") -- 칸도 기준 해상도 배율(칩 스택과 같음)
		boxScale.Name = "HudV5Scale"
		boxScale.Scale = math.max(s, require(game:GetService("ReplicatedStorage").Shared.data.UiTokens).textMinRootScale) -- 글자 읽힘 하한(UI2-2와 같은 값)
		if require(game:GetService("ReplicatedStorage").Shared.data.UiV2Flags).hud then -- UI-1 0단계: HUD 배율 하나(m)
			local view = workspace.CurrentCamera.ViewportSize
			boxScale.Scale = require(game:GetService("ReplicatedStorage").Shared.HudPlace).scale(view.X, view.Y, Theme.isMobile)
		end
		boxScale.Parent = box
		menu = nil
		box.AnchorPoint = Vector2.new(1, 0)
		local top = math.floor(q[2] * s)
		local chips = player.PlayerGui:FindFirstChild("TopChipsGui") and player.PlayerGui.TopChipsGui:FindFirstChild("TopChipsRow")
		if chips and chips.AbsoluteSize.Y > 0 then -- 지금 칩 스택(재화 · 레벨 · 스테이지)이 v5 두 줄보다 길다 → 그 바로 아래
			top = math.max(top, chips.AbsolutePosition.Y + chips.AbsoluteSize.Y + 8 - gui.AbsolutePosition.Y)
		end
		box.Position = UDim2.new(1, -math.floor((base[1] - q[1] - q[3]) * s), 0, top)
	end
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
	-- QUEUE-ALL8 E4: 위 가운데 알림 줄(세부 지역 배너 등 - Toast TC)이 이 칸과 겹치는 동안만 그 아래로 살짝 내린다(폰 = 칸이 메뉴 오른쪽 위라 배너와 겹쳤다)
	local tc = player.PlayerGui:FindFirstChild("ToastGuiTC")
	if tc then
		local offset = gui.AbsolutePosition
		local bx, by = offset.X + box.Position.X.Offset, offset.Y + box.Position.Y.Offset
		local bw, bh = box.Size.X.Offset, box.Size.Y.Offset
		local push = 0
		for _, row in ipairs(tc:GetDescendants()) do
			if row.Name == "ToastRow" and row:IsA("GuiObject") and row.Visible then
				local p, s = row.AbsolutePosition, row.AbsoluteSize
				if s.X > 0 and p.X < bx + bw and bx < p.X + s.X and p.Y < by + bh + push and by + push < p.Y + s.Y then
					push = math.max(push, p.Y + s.Y + 6 - by)
				end
			end
		end
		if push > 0 then
			box.Position = UDim2.fromOffset(box.Position.X.Offset, box.Position.Y.Offset + push)
		end
	end
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
local placeAt = 0
RunService.Heartbeat:Connect(function()
	if os.clock() - placeAt > 0.2 then -- E4: 알림 줄이 뜨고 지는 것을 따라간다(5 Hz)
		placeAt = os.clock()
		place()
	end
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
task.spawn(function() -- QUEUE-UI2 UI2-4 HUD v5: 칩 스택 크기가 바뀌면 다시
	local chipsGui = player.PlayerGui:WaitForChild("TopChipsGui", 30)
	local chips = chipsGui and chipsGui:WaitForChild("TopChipsRow", 10)
	if chips and HudData.menuV5 then
		chips:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
		chips:GetPropertyChangedSignal("AbsolutePosition"):Connect(place)
		place()
	end
end)
task.spawn(function()
	local menuGui = not HudData.menuV5 and player.PlayerGui:WaitForChild("MenuBarGui", 30)
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
