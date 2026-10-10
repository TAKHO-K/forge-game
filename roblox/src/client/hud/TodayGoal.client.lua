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

-- UI-1 2단계(02 v6 §10 · MISSING 10): 다음 목표 = 카드 1개(PC 380 × 72 · 폰 262 × 44 · 오른쪽 위 v6 자리 · HUD 배율 m) · 제목 + 할 일 + 진행 게이지 + [길 안내](44) ·
--   카드 누름 = 퀘스트 창 · [길 안내] = 바닥 길 안내(QuestGuide) · 보스전 숨김 · 목표 = 메인 지금 단계 → 수련 → 안 끝난 일간 1개(오늘의 목표 3줄 = 퀘스트 창). 스위치 UiV2Flags.hud = false → 옛 3줄 칸.
local cardV6 = nil
local V6ON = require(game:GetService("ReplicatedStorage").Shared.data.UiV2Flags).hud
local function buildCard()
	local RS = game:GetService("ReplicatedStorage")
	local V6 = require(RS.Shared.data.UiLayoutData).hud.v6
	local HudPlace = require(RS.Shared.HudPlace)
	local UiParts = require(script.Parent.Parent.ui.v2.UiParts)
	local UiKit = require(script.Parent.Parent.ui.v2.UiKit)
	local ArtImage = require(script.Parent.Parent.ui.ArtImage)
	local phone = Theme.isMobile
	local spec = phone and V6.phone.nextGoal or V6.pc.nextGoal
	local g = Instance.new("ScreenGui")
	g.Name = "NextGoalGui"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	g.DisplayOrder = 4
	g.Parent = player:WaitForChild("PlayerGui")
	local card = Instance.new("ImageButton")
	card.Name = "NextGoal"
	card.AutoButtonColor = false
	card.BackgroundTransparency = 1
	card.Image = ArtImage.get("ui/ds/hud-panel") or ""
	card.ScaleType = Enum.ScaleType.Slice
	card.SliceCenter = Rect.new(20, 20, 76, 76)
	card.Size = UDim2.fromOffset(spec[3], spec[4])
	card.Parent = g
	local sc = Instance.new("UIScale")
	sc.Parent = card
	local title = UiKit.label(card, Text.get("ui1.nextGoal.title"), "caption", "accent", { name = "Title", font = "korean" })
	local task_ = UiKit.label(card, "", "body", "text.primary", { name = "Task", font = "korean" })
	local count = UiKit.label(card, "", "caption", "text.secondary", { name = "Count", font = "number", align = Enum.TextXAlignment.Right })
	local guide = UiKit.button({ kind = "secondary", text = Text.get("ui1.nextGoal.guide"), parent = card, name = "Guide", textSize = "caption", padX = 6 })
	local gauge
	if phone then
		title.Visible = false
		task_.Position, task_.Size = UDim2.fromOffset(10, 0), UDim2.new(1, -110, 1, 0)
		count.Position, count.Size = UDim2.new(1, -98, 0, 0), UDim2.fromOffset(40, spec[4])
		guide.root.Position, guide.root.Size = UDim2.new(1, -54, 0, 0), UDim2.fromOffset(54, 44)
	else
		title.Position, title.Size = UDim2.fromOffset(14, 6), UDim2.new(1, -130, 0, 20)
		task_.Position, task_.Size = UDim2.fromOffset(14, 24), UDim2.new(1, -170, 0, 26)
		count.Position, count.Size = UDim2.new(1, -160, 0, 24), UDim2.fromOffset(50, 26)
		gauge = UiParts.gauge(card, { w = spec[3] - 140, h = 8, color = require(RS.Shared.data.UiPartsData).gaugeColors.exp, position = UDim2.fromOffset(14, 56) })
		guide.root.Position, guide.root.Size = UDim2.new(1, -104, 0, 14), UDim2.fromOffset(92, 44)
	end
	local current = nil
	card.Activated:Connect(function()
		require(script.Parent.Parent.panels.Quests).open(current and current.tab or "main")
	end)
	guide.Activated:Connect(function()
		if current and current.guide then
			require(script.Parent.Parent.QuestGuide).go(current.guide, false)
		elseif current and current.onPress then
			current.onPress()
		end
	end)
	local function place()
		local view = workspace.CurrentCamera.ViewportSize
		local m = HudPlace.scale(view.X, view.Y, phone)
		local ax, ox, ay, oy = HudPlace.udim(spec, spec.anchor, m, phone)
		-- 지금 칩 묶음(구역 · 재화 · 레벨 · 전투력 · 스테이지 + 최고 기록)이 v6 3줄보다 길다 → v6 자리와 칩 묶음 아래 + 8 중 더 아래(AbsolutePosition = 상단 바 아래 공통 좌표 + 58 = 화면)
		local chips = player.PlayerGui:FindFirstChild("TopChipsGui") and player.PlayerGui.TopChipsGui:FindFirstChild("TopChipsRow")
		if chips and chips.AbsoluteSize.Y > 0 and not phone then
			oy = math.max(oy, chips.AbsolutePosition.Y + chips.AbsoluteSize.Y + game:GetService("GuiService"):GetGuiInset().Y + 8 * m)
		end
		card.Position = UDim2.new(ax, ox, ay, oy)
		sc.Scale = m
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(place)
	place()
	task.spawn(function()
		local chipsGui = player.PlayerGui:WaitForChild("TopChipsGui", 30)
		local chips = chipsGui and chipsGui:WaitForChild("TopChipsRow", 10)
		if chips then
			chips:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
			chips:GetPropertyChangedSignal("AbsolutePosition"):Connect(place)
			place()
		end
	end)
	cardV6 = { gui = g, card = card, task = task_, count = count, gauge = gauge, guide = guide, set = function(c)
		current = c
	end }
	box.Visible = false
	gui.Enabled = false -- 옛 3줄 칸 끔(지우지 않음)
end
local function refreshCard()
	if not cardV6 then
		return
	end
	local c = nil
	if view and view.main then
		local m = view.main
		c = { name = m.name, n = m.n, target = m.target, guide = (not m.done) and m.guide or nil, tab = "main" }
	elseif player:GetAttribute("TrainingReady") == true then
		c = { name = Text.get("today.training"), tab = "main", onPress = function()
			UIManager.openLazy("training")
		end }
	elseif view then
		for _, q in ipairs(view.daily or {}) do
			if q.n < q.target then
				c = { name = q.name, n = q.n, target = q.target, tab = "daily" }
				break
			end
		end
	end
	cardV6.set(c)
	local show = c ~= nil and player:GetAttribute("BossEncounterId") == nil and player:GetAttribute("ClassId") ~= nil and player:GetAttribute("ClassId") ~= ""
	cardV6.gui.Enabled = show and player:GetAttribute("InMainMenu") ~= true
	if c then
		cardV6.task.Text = c.name or ""
		cardV6.count.Text = c.target and ("%d/%d"):format(c.n or 0, c.target) or ""
		if cardV6.gauge then
			cardV6.gauge.set(c.target and math.clamp((c.n or 0) / c.target, 0, 1) or 0)
		end
		cardV6.guide.root.Visible = c.guide ~= nil or c.onPress ~= nil
	end
end
if V6ON then
	buildCard()
	for _, name in ipairs({ "TrainingReady", "BossEncounterId", "ClassId", "InMainMenu" }) do
		player:GetAttributeChangedSignal(name):Connect(refreshCard)
	end
end

updateRemote.OnClientEvent:Connect(function(v)
	view = v
	refresh()
	refreshCard()
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
