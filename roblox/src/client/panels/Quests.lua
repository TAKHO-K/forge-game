-- 퀘스트 창(QUEUE-10h Q7 · QUEUE-ALL3 Q3 개편 - 10 문서 3절). 단축키 J · 왼쪽 메뉴 퀘스트 칸(PanelRegistry "quests").
--   맨 위 토글 탭 5 = [메인](초반 여정 - 지금 단계 큰 카드: 할 일 · 진행 게이지 · 보상 그림 · [길 안내] · [받기]) · [일일](첫 접속 · 일간 3 · 완료 상자 · 확률 공개) · [주간] ·
--   [전 서버 협동](옛 합동 목표 알약 - 큰 게이지 · 60 · 85 · 100% 칸 보상 그림 · 내 기여 · 남은 시간) · [주간 도전](옛 버튼 - 이번 주 변형 · 순위 · 내 기록 · [도전]).
--   값 = QuestUpdate(서버 QuestService.view)만 그린다 - 판정 · 지급 = 서버. 줄마다 차오르는 게이지(0.35초) + 보상 그림 + 큰 [받기](폰 60 · 초록).
--   수련 줄은 수련 창(U)으로 옮겼다(Q2).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Text = require(ReplicatedStorage.Shared.Text)
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local CommunityGoalData = require(ReplicatedStorage.Shared.data.CommunityGoalData)
local WeeklyChallengeData = require(ReplicatedStorage.Shared.data.WeeklyChallengeData)
local Panel = require(script.Parent.Parent.ui.kit.Panel)
local Button = require(script.Parent.Parent.ui.kit.Button)
local Tabs = require(script.Parent.Parent.ui.kit.Tabs)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local Toast = require(script.Parent.Parent.ui.kit.Toast)
local RewardIcons = require(script.Parent.Parent.ui.RewardIcons)
local UIManager = require(script.Parent.Parent.UIManager)

local QuestsPanel = {}
QuestsPanel.id = "quests"

local player = Players.LocalPlayer
local PANEL_SIZE = Vector2.new(640, 460)
local PAD = 12
local ROW_H = 64
local CLAIM_H = 48 -- PC · 폰 = 60(10 문서 "폰 60px 이상")
local GREEN = Color3.fromRGB(76, 196, 110)
local TABS = { "main", "daily", "weekly", "community", "challenge" }

local requestRemote = ReplicatedStorage:WaitForChild("QuestRequest")
local updateRemote = ReplicatedStorage:WaitForChild("QuestUpdate")

local built, view
local selectedTab = "main"
local order = 0

local function claimHeight()
	return Theme.isMobile and 60 or CLAIM_H
end

local function build()
	local panel = Panel.create({ id = QuestsPanel.id, kind = "window", title = Text.get("quests.titleV2"), size = PANEL_SIZE,
		onOpen = function()
			task.defer(function()
				QuestsPanel.render()
				requestRemote:FireServer("view")
			end)
		end })
	local tabList = {}
	for _, id in ipairs(TABS) do
		table.insert(tabList, { id = id, text = Text.get("quests.tab." .. id) })
	end
	local tabs = Tabs.build({ parent = panel.content, tabs = tabList, selected = selectedTab, width = PANEL_SIZE.X - PAD * 2, position = UDim2.fromOffset(PAD, 4), onSelect = function(id)
		selectedTab = id
		QuestsPanel.render()
	end })
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Body"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(0, Theme.tabHeight + 10)
	scroll.Size = UDim2.new(1, 0, 1, -(Theme.tabHeight + 10))
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = Theme.color("rim")
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = panel.content
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom = UDim.new(0, PAD), UDim.new(0, PAD + 4), UDim.new(0, 4), UDim.new(0, PAD)
	pad.Parent = scroll
	built = { panel = panel, scroll = scroll, tabs = tabs }
end

local function nextOrder()
	order += 1
	return order
end

local function label(parent, text, sizeName, colorName)
	local l = Theme.label(parent, text, sizeName or "body", colorName or "textPrimary")
	l.TextWrapped = true
	return l
end

-- 차오르는 게이지(0 → ratio · 0.35초)
local function gauge(parent, ratio, position, size, color)
	local track = Instance.new("Frame")
	track.Name = "Gauge"
	track.BackgroundColor3 = Theme.color("slot")
	track.Position, track.Size = position, size
	track.Parent = parent
	Theme.corner(track, 6)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = color or GREEN
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = track
	Theme.corner(fill, 6)
	TweenService:Create(fill, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1) }):Play()
	return track
end

-- 큰 초록 [받기]
local function claimButton(parent, enabled, claimed, onPress, name)
	local b = Button.build({ parent = parent, kind = "claim", width = 128, height = claimHeight(),
		text = claimed and Text.get("quests.claimed") or Text.get("quests.claim"), position = UDim2.new(1, -8, 0.5, 0), anchorPoint = Vector2.new(1, 0.5), onActivated = onPress })
	b.root.Name = name or "ClaimButton"
	b.root.Font = Enum.Font.GothamBlack
	b.setEnabled(enabled)
	return b
end

-- 줄 하나: 이름 + 진행 게이지(n/목표) + 보상 그림 + [받기]
local function questRow(name, n, target, reward, claimed, onClaim, rowName)
	local f = Instance.new("Frame")
	f.Name = rowName or ("Row" .. order)
	f.LayoutOrder = nextOrder()
	f.BackgroundColor3 = Theme.color("slot")
	f.BackgroundTransparency = 0.35
	f.Size = UDim2.new(1, 0, 0, math.max(ROW_H, claimHeight() + 12))
	f.Parent = built.scroll
	Theme.corner(f, 10)
	local title = label(f, name, "body")
	title.Position, title.Size = UDim2.fromOffset(10, 4), UDim2.new(1, -300, 0, 24)
	gauge(f, target > 0 and n / target or 0, UDim2.fromOffset(10, 34), UDim2.new(1, -310, 0, 12))
	local count = label(f, ("%d/%d"):format(n, target), "caption", "textSecondary")
	count.Position, count.Size = UDim2.new(1, -296, 0, 28), UDim2.fromOffset(60, 22)
	RewardIcons.row(f, reward, 26, { frameSize = UDim2.fromOffset(130, 30), position = UDim2.new(1, -236, 0.5, -15) })
	claimButton(f, n >= target and not claimed, claimed, onClaim)
	return f
end

local function send(action, a, b)
	requestRemote:FireServer(action, a, b)
end

local function clear()
	for _, child in ipairs(built.scroll:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	order = 0
end

-- [메인] 지금 단계 큰 카드
local function renderMain()
	local m = view.main
	if not m then
		label(built.scroll, Text.get("quests.mainDone"), "header", "xp").LayoutOrder = nextOrder()
		return
	end
	local card = Instance.new("Frame")
	card.Name = "MainCard"
	card.LayoutOrder = nextOrder()
	card.BackgroundColor3 = Theme.color("slot")
	card.BackgroundTransparency = 0.2
	card.Size = UDim2.new(1, 0, 0, 212)
	card.Parent = built.scroll
	Theme.corner(card, 12)
	local step = label(card, Text.get("quests.journeyStep", { index = tostring(m.index), total = tostring(m.total) }), "caption", "textSecondary")
	step.Position, step.Size = UDim2.fromOffset(14, 8), UDim2.new(1, -28, 0, 18)
	local name = label(card, m.name, "title", "textPrimary")
	name.Name = "StepName"
	name.Position, name.Size = UDim2.fromOffset(14, 28), UDim2.new(1, -28, 0, 30)
	gauge(card, (m.target or 1) > 0 and (m.n or 0) / (m.target or 1) or 0, UDim2.fromOffset(14, 68), UDim2.new(1, -110, 0, 18))
	local count = label(card, ("%d / %d"):format(m.n or 0, m.target or 1), "header", "textPrimary")
	count.Position, count.Size = UDim2.new(1, -90, 0, 64), UDim2.fromOffset(80, 26)
	local rewardTitle = label(card, Text.get("quests.rewardLabel"), "caption", "textSecondary")
	rewardTitle.Position, rewardTitle.Size = UDim2.fromOffset(14, 98), UDim2.fromOffset(120, 18)
	RewardIcons.row(card, m.reward, 34, { frameSize = UDim2.new(1, -28, 0, 36), position = UDim2.fromOffset(14, 116) })
	local guideButton = Button.build({ parent = card, kind = "secondary", width = 150, height = claimHeight(), text = Text.get("quests.guide"),
		position = UDim2.new(0, 14, 1, -10), anchorPoint = Vector2.new(0, 1), onActivated = function()
			if require(script.Parent.Parent.QuestGuide).go(m.guide, false) then
				UIManager.close(QuestsPanel.id)
			end
		end })
	guideButton.root.Name = "GuideButton"
	guideButton.root.Visible = m.guide ~= nil
	local autoButton = Button.build({ parent = card, kind = "secondary", width = 150, height = claimHeight(), text = Text.get("map.autoWalk"),
		position = UDim2.new(0, 172, 1, -10), anchorPoint = Vector2.new(0, 1), onActivated = function()
			if require(script.Parent.Parent.QuestGuide).go(m.guide, true) then
				UIManager.close(QuestsPanel.id)
			end
		end })
	autoButton.root.Name = "AutoWalkButton"
	autoButton.root.Visible = m.guide ~= nil
	local claim = claimButton(card, m.done, false, function()
		send("claim", "main")
	end, "MainClaim")
	claim.root.AnchorPoint = Vector2.new(1, 1)
	claim.root.Position = UDim2.new(1, -14, 1, -10)
	if view.guide then -- 첫 5분 이정표(보상 없음 - 한 줄)
		label(built.scroll, Text.get("guide.now", { index = tostring(view.guide.index), total = tostring(view.guide.total), text = Text.get(view.guide.text) }), "body", "xp").LayoutOrder = nextOrder()
	end
end

local function renderDaily()
	local login = questRow(Text.get("quests.login"), view.loginReady and 1 or 0, 1, nil, not view.loginReady, function()
		send("claim", "login")
	end, "LoginRow")
	local _ = login
	for _, q in ipairs(view.daily or {}) do
		questRow(q.name, q.n, q.target, q.reward, q.claimed, function()
			send("claim", "daily", q.id)
		end, "Daily_" .. q.id)
	end
	local doneCount = 0
	for _, q in ipairs(view.daily or {}) do
		doneCount += (q.n >= q.target) and 1 or 0
	end
	questRow(Text.get("quests.chest"), doneCount, math.max(1, #(view.daily or {})), nil, view.chestClaimed, function()
		send("claim", "chest")
	end, "ChestRow")
	local prob = Button.build({ parent = built.scroll, kind = "secondary", width = 200, text = Text.get("prob.open"), onActivated = function()
		require(script.Parent.Probability).open()
	end })
	prob.root.LayoutOrder = nextOrder()
	prob.root.Name = "ProbabilityButton"
end

local function renderWeekly()
	for _, q in ipairs(view.weekly or {}) do
		questRow(q.name, q.n, q.target, q.reward, q.claimed, function()
			send("claim", "weekly", q.id)
		end, "Weekly_" .. q.id)
	end
end

-- [전 서버 협동] 옛 합동 목표 알약 창
local function renderCommunity()
	local total = Workspace:GetAttribute("CommunityGoalTotal") or 0
	local target = Workspace:GetAttribute("CommunityGoalTarget")
	local card = Instance.new("Frame")
	card.Name = "CommunityCard"
	card.LayoutOrder = nextOrder()
	card.BackgroundTransparency = 1
	card.Size = UDim2.new(1, 0, 0, 120)
	card.Parent = built.scroll
	local head = label(card, target and Text.get("quests.communityHead", { pct = tostring(math.floor(total / target * 100)) }) or CommunityGoalData.text.measuring, "header")
	head.Size = UDim2.new(1, 0, 0, 26)
	gauge(card, target and total / target or 0, UDim2.fromOffset(0, 34), UDim2.new(1, 0, 0, 24), Color3.fromRGB(255, 214, 90))
	for i, t in ipairs(CommunityGoalData.tiers) do
		local tick = Instance.new("Frame")
		tick.Name = "Tick" .. i
		tick.BackgroundColor3 = Color3.new(1, 1, 1)
		tick.Position = UDim2.new(math.min(t.fraction, 0.995), 0, 0, 30)
		tick.Size = UDim2.fromOffset(3, 32)
		tick.Parent = card
		RewardIcons.row(card, t.reward, 26, { frameSize = UDim2.fromOffset(90, 28), position = UDim2.new(math.min(t.fraction, 0.9), -60, 0, 66) })
	end
	local week = Workspace:GetAttribute("CommunityGoalWeek")
	local left = week and ((week + 1) * 7 - 3) * 86400 - os.time() or nil -- 다음 월요일 0시(UTC)까지
	local mine = label(card, Text.get("quests.communityMine", { n = tostring(player:GetAttribute("CommunityGoalContributed") or 0),
		left = left and Text.get("ui.quest.daysHours", { days = ("%d"):format(left // 86400), hours = ("%d"):format((left % 86400) // 3600) }) or "-" }), "body", "textSecondary")
	mine.Position, mine.Size = UDim2.fromOffset(0, 96), UDim2.new(1, 0, 0, 22)
	local claimed = "," .. tostring(player:GetAttribute("CommunityGoalClaimed") or "") .. ","
	for i, t in ipairs(CommunityGoalData.tiers) do
		local reached = target and total >= target * t.fraction
		local got = claimed:find("," .. i .. ",", 1, true) ~= nil
		questRow(Text.get("quests.communityTier", { pct = tostring(math.floor(t.fraction * 100 + 0.5)) }), reached and 1 or 0, 1, t.reward, got, function()
			local ok, result = pcall(function()
				return ReplicatedStorage:WaitForChild("CommunityGoalClaim"):InvokeServer(i)
			end)
			if ok and type(result) == "table" then
				Toast.push("TC", { text = tostring(result.message), colorName = result.ok and "gold" or "textPrimary" })
			end
			QuestsPanel.render()
		end, "CommunityTier" .. i)
	end
end

-- [주간 도전] 옛 버튼 창
local function renderChallenge()
	local bossId = Workspace:GetAttribute("WeeklyChallengeBoss")
	local b = bossId and BossData.bosses[bossId]
	local head = label(built.scroll, Text.get("quests.challengeHead", { boss = b and b.displayName or "?", variant = tostring(Workspace:GetAttribute("WeeklyChallengeLabel") or ""),
		stage = tostring(WeeklyChallengeData.stage) }), "header", "gold")
	head.LayoutOrder = nextOrder()
	head.Size = UDim2.new(1, 0, 0, 48)
	local go = Button.build({ parent = built.scroll, kind = "primary", width = 200, height = claimHeight(), text = WeeklyChallengeData.text.start, onActivated = function()
		ReplicatedStorage:WaitForChild("WeeklyChallengeStart"):FireServer()
		UIManager.close(QuestsPanel.id)
	end })
	go.root.Name = "ChallengeStart"
	go.root.LayoutOrder = nextOrder()
	local rankTitle = label(built.scroll, WeeklyChallengeData.text.rank, "body", "textSecondary")
	rankTitle.LayoutOrder = nextOrder()
	rankTitle.Size = UDim2.new(1, 0, 0, 22)
	local rows = {}
	for i = 1, WeeklyChallengeData.topShown do
		local l = label(built.scroll, i == 1 and WeeklyChallengeData.text.none or "", "body")
		l.LayoutOrder = nextOrder()
		l.Size = UDim2.new(1, 0, 0, 22)
		rows[i] = l
	end
	local mine = label(built.scroll, "", "body", "gold")
	mine.LayoutOrder = nextOrder()
	mine.Size = UDim2.new(1, 0, 0, 22)
	task.spawn(function()
		local ok, r = pcall(function()
			return ReplicatedStorage:WaitForChild("WeeklyChallengeTop"):InvokeServer()
		end)
		for i, l in ipairs(rows) do
			local row = ok and type(r) == "table" and r.rows and r.rows[i]
			if l.Parent then
				l.Text = row and Text.get("quests.challengeRow", { rank = tostring(row.rank), name = row.name, seconds = ("%.1f"):format(row.seconds) }) or (i == 1 and WeeklyChallengeData.text.none or "")
			end
		end
		if mine.Parent then
			mine.Text = (ok and type(r) == "table" and r.myBest) and Text.get("quests.challengeMine", { seconds = ("%.1f"):format(r.myBest) }) or ""
		end
	end)
end

local RENDER = { main = renderMain, daily = renderDaily, weekly = renderWeekly, community = renderCommunity, challenge = renderChallenge }

function QuestsPanel.render()
	if not built or not UIManager.isOpen(QuestsPanel.id) then
		return
	end
	clear()
	if not view then
		label(built.scroll, "…", "body").LayoutOrder = nextOrder()
		return
	end
	RENDER[selectedTab]()
end

function QuestsPanel.open(tabId)
	if not built then
		build()
	end
	if tabId and RENDER[tabId] then
		selectedTab = tabId
		built.tabs.select(tabId, true)
	end
	if not UIManager.isOpen(QuestsPanel.id) and not UIManager.open(QuestsPanel.id) then
		return false
	end
	QuestsPanel.render()
	send("view")
	return true
end

function QuestsPanel.view()
	return view
end

QuestsPanel.changed = Instance.new("BindableEvent")

function QuestsPanel.init()
	if not built then
		build()
	end
	updateRemote.OnClientEvent:Connect(function(v)
		view = v
		QuestsPanel.changed:Fire(v)
		QuestsPanel.render()
	end)
	for _, a in ipairs({ "CommunityGoalTotal", "CommunityGoalTarget" }) do
		Workspace:GetAttributeChangedSignal(a):Connect(function()
			if selectedTab == "community" then
				QuestsPanel.render()
			end
		end)
	end
end

-- 점검 · 스크린샷용: 합성 표로 연다
function QuestsPanel.debugOpen(fakeView, tabId)
	view = fakeView
	return QuestsPanel.open(tabId)
end

return QuestsPanel
