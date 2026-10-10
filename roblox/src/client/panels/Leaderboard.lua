-- 리더보드 순위 창(P3b A · L2) - window. 서버 캐시(Leaderboard.lua - LeaderboardRequest)만 읽는다(저장소 직접 요청 0).
--   입구: HUD [순위] 버튼(TR.leaderboardToggle - 칩 스택 왼쪽 [파티] 버튼 바로 아래). 메뉴바 4번째 칸은 폰 높이에서 BL 터치 예약 구역과 겹쳐(P2.5b 확인) 쓰지 않는다.
--   탭(왼쪽 세로 레일 - 폰 높이 302에서 가로 탭 + 목록 + 내 순위 줄을 세로로 쌓으면 목록이 2.5줄뿐이라 옆으로 뺐다):
--     전체(개인 - 클리어한 보스 스테이지 최고) · 직업별(보스 스테이지 + 시간, 직업 칩 4개) · 파티(구성별 최고) · 시즌(시즌 번호 · 기간 · 규칙).
--   목록 = 상위 100(서버 topN). "내 순위"는 목록 위 고정 줄(칩 오른쪽) - 캐시 안이면 board 응답에 같이 오고, 밖이면 "me" 요청 1회(서버 간격 10초 · 창이 60초 캐시).
--   줄을 누르면 장비 보기(리더보드 카드 - 무기 · 보석만 공개, 방어구 칸 "?") - 장비 보기를 닫으면 이 창으로 돌아온다. 파티 줄은 누르면 멤버 이름이 펼쳐지고, 멤버를 누르면 그 사람 카드.
-- 표시 글(스테이지 · 시간)은 서버가 LeaderboardRules.decode로 푼 값을 그대로 쓴다(화면용 복사 계산 없음).

local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local Text = require(ReplicatedStorage.Shared.Text)
local UIManager = require(script.Parent.Parent.UIManager)
local Button = require(script.Parent.Parent.ui.kit.Button) -- UI-1 7c 빈 상태 [구역 선택 열기]
local Panel = require(script.Parent.Parent.ui.kit.Panel)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local Toast = require(script.Parent.Parent.ui.kit.Toast)
local ScreenMap = require(script.Parent.Parent.ui.ScreenMap)
local Inspect = require(script.Parent.Inspect)

local REST = require(game:GetService("ReplicatedStorage").Shared.data.UiV2Flags).rest -- UI-1 7c 순위(H §6 · v1.1 §3)
local Leaderboard = {}

Leaderboard.id = "leaderboard"
local RAIL_WIDTH = 96
local GAP = 6
local PAD = 8
local CHIP_WIDTH = 64 -- 칩 최소 폭(글이 길면 글 폭 + CHIP_TEXT_PAD - QUEUE-STUDIO S-5: 영어 "Swordsman"이 64를 넘쳤다)
local CHIP_TEXT_PAD = 12
local ME_CACHE_SECONDS = 60
local ME_RETRY_SECONDS = 10.5 -- 서버 "me" 간격(LeaderboardConfig.requestIntervalSeconds.me = 10) 바로 뒤

local player = Players.LocalPlayer
local request = ReplicatedStorage:WaitForChild("LeaderboardRequest")

local TABS = {
	{ id = "all", textKey = "ui.rank.tab.all" },
	{ id = "class", textKey = "ui.rank.tab.class" },
	{ id = "party", textKey = "ui.rank.tab.party" },
	{ id = "season", textKey = "ui.rank.tab.season" },
}

local refs
local state = {
	tab = "all",
	classId = nil, -- 직업별 탭의 직업(처음 = 내 직업)
	boards = {}, -- [boardId] = board 응답(마지막)
	me = {}, -- [boardId] = { result, at }
	expandedParty = nil, -- 펼친 파티 줄의 key
	token = 0,
	hall = nil, -- P3c E2: 지난 시즌 개인 순위(명예의 전당 응답 - 시즌 탭)
}

local function rowHeight()
	return Theme.isMobile and Theme.touchMin or 36
end

-- 초 → "3:12.4"(1시간 이상 "1:02:03").
function Leaderboard.formatSeconds(seconds)
	if not seconds then
		return ""
	end
	local total = math.max(0, seconds)
	local hours = math.floor(total / 3600)
	local minutes = math.floor((total % 3600) / 60)
	local rest = total % 60
	if hours > 0 then
		return ("%d:%02d:%02d"):format(hours, minutes, math.floor(rest))
	end
	return ("%d:%04.1f"):format(minutes, rest)
end

local function currentBoardId()
	if state.tab == "all" then
		return "personal"
	elseif state.tab == "class" then
		return "class:" .. state.classId
	elseif state.tab == "party" then
		return "party"
	end
	return nil
end

local function nameOf(names, userId)
	if userId == player.UserId then
		return player.DisplayName
	end
	return (names and names[tostring(userId)]) or ("#" .. tostring(userId))
end

-- 서버 요청(RemoteFunction) - 실패 · 거절이면 nil, 이유.
local function invoke(action, boardId, key)
	local ok, result = pcall(function()
		return request:InvokeServer(action, boardId, key)
	end)
	if ok and type(result) == "table" and result.ok then
		return result
	end
	return nil, ok and type(result) == "table" and result.reason or "error"
end

local function meText(result, isParty)
	if not result then
		return Text.get("ui.rank.me.loading")
	end
	if result.rank then
		local args = { rank = ("%d"):format(result.rank), stage = ("%d"):format(result.stage or 0) }
		if result.seconds then
			args.time = Leaderboard.formatSeconds(result.seconds)
			return Text.get("ui.rank.me.rankTime", args)
		end
		return Text.get("ui.rank.me.rank", args)
	end
	if result.outOfTop and result.stage then
		if result.topPercent then -- QUEUE-ALL9C 1-5(J2): 100위 밖 = 상위 약 n%(서버 인원 구간)
			return Text.get("ui.rank.me.topPercent", { percent = ("%d"):format(result.topPercent), stage = ("%d"):format(result.stage) })
		end
		return Text.get("ui.rank.me.outOfTop", { top = ("%d"):format(result.topN or 100), stage = ("%d"):format(result.stage) })
	end
	if result.retry then
		return Text.get("ui.rank.me.retry")
	end
	if result.outOfTop and isParty then
		return Text.get("ui.rank.me.partyNone", { top = ("%d"):format(result.topN or 100) })
	end
	return Text.get("ui.rank.me.none")
end

-- ═══ 짓기 ═══

local function makeButton(parent, name, text)
	local button = Instance.new("TextButton")
	button.Name = name
	button.AutoButtonColor = false
	button.Font = Theme.font
	button.TextSize = Theme.textSize("body")
	button.TextColor3 = UIColors.textSecondary
	button.Text = text
	button.BackgroundColor3 = UIColors.slot
	button.BackgroundTransparency = UIColors.slotTransparency
	button.Parent = parent
	Theme.corner(button, Theme.corner.chip)
	local stroke = Theme.stroke(button)
	return button, stroke
end

-- ══ QUEUE-ALL9C 1-5 J1 메달 · J3 시상대(위 3명 · 헤드샷 = GetUserThumbnailAsync, 실패 = 기본 실루엣) - 같은 순위표 응답(허브 명예의 전당 지점도 이 창) ══
local PODIUM_H = 172
local headshots = {} -- [userId] = 이미지 주소 | false(실패)
local function silhouette(parent)
	local s = Instance.new("Frame")
	s.Name = "Silhouette"
	s.BackgroundTransparency = 1
	s.Size = UDim2.fromScale(1, 1)
	s.Parent = parent
	local head = Instance.new("Frame")
	head.BackgroundColor3 = Color3.fromRGB(110, 116, 128)
	head.AnchorPoint = Vector2.new(0.5, 0)
	head.Position = UDim2.fromScale(0.5, 0.16)
	head.Size = UDim2.fromScale(0.42, 0.42)
	head.Parent = s
	Theme.corner(head, 999)
	local body = Instance.new("Frame")
	body.BackgroundColor3 = Color3.fromRGB(110, 116, 128)
	body.AnchorPoint = Vector2.new(0.5, 1)
	body.Position = UDim2.fromScale(0.5, 1)
	body.Size = UDim2.fromScale(0.78, 0.36)
	body.Parent = s
	Theme.corner(body, 999)
	return s
end
function Leaderboard.paintMedal(row, rank)
	local color = UIColors.rankMedal[rank]
	row.medal.Visible = color ~= nil
	row.rank.Visible = color == nil
	if color then
		row.medal.BackgroundColor3 = color
		row.medal.Text = tostring(rank)
	end
end
function Leaderboard.buildPodium(list)
	local root = Instance.new("Frame")
	root.Name = "Podium"
	root.BackgroundTransparency = 1
	root.Size = UDim2.new(1, -8, 0, PODIUM_H)
	root.Visible = false
	root.Parent = list
	local cards = {}
	local layout = { { rank = 2, x = 0.17, h = 0.86 }, { rank = 1, x = 0.5, h = 1 }, { rank = 3, x = 0.83, h = 0.78 } } -- 2 · 1 · 3위(가운데가 가장 높다)
	for _, spot in ipairs(layout) do
		local card = Instance.new("TextButton")
		card.Name = "Podium" .. spot.rank
		card.Text = ""
		card.AutoButtonColor = false
		card.AnchorPoint = Vector2.new(0.5, 1)
		card.Position = UDim2.new(spot.x, 0, 1, 0)
		card.Size = UDim2.new(0.3, 0, spot.h, 0)
		card.BackgroundColor3 = UIColors.slot
		card.BackgroundTransparency = UIColors.slotTransparency
		card.Parent = root
		Theme.corner(card, 10)
		local stroke = Theme.stroke(card)
		stroke.Color = UIColors.rankMedal[spot.rank]
		stroke.Transparency = 0
		stroke.Thickness = 2
		local face = Instance.new("ImageLabel")
		face.Name = "Headshot"
		face.AnchorPoint = Vector2.new(0.5, 0)
		face.Position = UDim2.new(0.5, 0, 0, 8)
		face.Size = UDim2.fromOffset(64, 64)
		face.BackgroundColor3 = Color3.fromRGB(46, 52, 64)
		face.Parent = card
		Theme.corner(face, 999)
		local sil = silhouette(face)
		local medal = Instance.new("TextLabel")
		medal.Name = "Medal"
		medal.AnchorPoint = Vector2.new(0.5, 0.5)
		medal.Position = UDim2.new(0.5, 26, 0, 66)
		medal.Size = UDim2.fromOffset(26, 26)
		medal.BackgroundColor3 = UIColors.rankMedal[spot.rank]
		medal.Text = tostring(spot.rank)
		medal.Font = Enum.Font.GothamBlack
		medal.TextScaled = true
		medal.TextColor3 = Color3.fromRGB(40, 30, 10)
		medal.Parent = card
		Theme.corner(medal, 999)
		local name = Theme.label(card, "", "body", "textPrimary")
		name.Name = "PlayerName"
		name.AnchorPoint = Vector2.new(0.5, 0)
		name.Position = UDim2.new(0.5, 0, 0, 80)
		name.Size = UDim2.new(1, -12, 0, 22)
		name.TextXAlignment = Enum.TextXAlignment.Center
		name.TextTruncate = Enum.TextTruncate.AtEnd
		local stage = Theme.label(card, "", "caption", "textSecondary")
		stage.Name = "Stage"
		stage.AnchorPoint = Vector2.new(0.5, 0)
		stage.Position = UDim2.new(0.5, 0, 0, 102)
		stage.Size = UDim2.new(1, -12, 0, 18)
		stage.TextXAlignment = Enum.TextXAlignment.Center
		local item = { card = card, face = face, silhouette = sil, name = name, stage = stage, entry = nil }
		card.Activated:Connect(function()
			if item.entry then
				Leaderboard.onRowPressed(item.entry)
			end
		end)
		cards[spot.rank] = item
	end
	return { root = root, cards = cards }
end
local function setHeadshot(item, userId)
	local url = userId and headshots[userId]
	item.face.Image = url or ""
	item.silhouette.Visible = not url
	if not userId or userId <= 0 or headshots[userId] ~= nil then
		return
	end
	headshots[userId] = false -- 한 사람 한 번만 묻는다(실패 = 실루엣 그대로)
	task.spawn(function()
		local ok, image = pcall(function()
			return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok and type(image) == "string" and image ~= "" then
			headshots[userId] = image
			if item.userId == userId then
				item.face.Image = image
				item.silhouette.Visible = false
			end
		end
	end)
end
-- 시상대 그리기 - 반환 = 목록에서 차지한 높이(없으면 0)
function Leaderboard.renderPodium(entries, names)
	local podium = refs and refs.podium
	if not podium then
		return 0
	end
	local show = #entries > 0
	podium.root.Visible = show
	for rank, item in pairs(podium.cards) do
		local entry = entries[rank]
		item.card.Visible = entry ~= nil
		item.entry = entry
		item.userId = entry and entry.userId
		if entry then
			item.name.Text = nameOf(names, entry.userId)
			item.stage.Text = Text.get("ui.rank.stage", { stage = ("%d"):format(entry.stage or 0) })
			setHeadshot(item, entry.userId)
		end
	end
	return show and (PODIUM_H + 8) or 0
end

local function build()
	Theme.recompute()
	local panel = Panel.create({
		id = Leaderboard.id,
		kind = "window",
		title = Text.get("ui.rank.title"),
		size = Vector2.new(780, 560), -- QUEUE-ALL9C 1-5(J3): 창 크게(옛 660 × 440) - 위 시상대 + 100줄 + 아래 내 줄
		help = { -- G1-1: "자기 최고 다음 보스" 모호 정리 + 2단
			short = Text.get("leaderboard.help.short"),
			detail = Text.get("leaderboard.help.detail"),
		},
		onOpen = function()
			Leaderboard.refresh()
		end,
		onClose = function()
			state.token += 1
		end,
	})
	local content = panel.content
	local r = { panel = panel, tabButtons = {}, chips = {}, rows = {}, memberButtons = {}, mobile = Theme.isMobile }

	-- 왼쪽 레일(탭)
	for index, tab in ipairs(TABS) do
		local button, stroke = makeButton(content, "Tab_" .. tab.id, Text.get(tab.textKey))
		button.Position = UDim2.new(0, PAD, 0, PAD + (index - 1) * (rowHeight() + GAP))
		button.Size = UDim2.new(0, RAIL_WIDTH, 0, rowHeight())
		r.tabButtons[tab.id] = { button = button, stroke = stroke }
		button.Activated:Connect(function()
			Leaderboard.selectTab(tab.id)
		end)
	end

	local paneX = PAD + RAIL_WIDTH + PAD
	local pane = Instance.new("Frame")
	pane.Name = "Pane"
	pane.BackgroundTransparency = 1
	pane.Position = UDim2.new(0, paneX, 0, PAD)
	pane.Size = UDim2.new(1, -(paneX + PAD), 1, -PAD * 2)
	pane.Parent = content
	r.pane = pane

	-- 머리 줄: 직업 칩(직업별 탭) + 내 순위(고정)
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, rowHeight())
	header.Parent = pane
	local chipX = 0
	for _, classId in ipairs(ClassData.order) do
		local chip, stroke = makeButton(header, "Chip_" .. classId, Text.get("class.name." .. classId))
		local width = math.max(CHIP_WIDTH, math.ceil(TextService:GetTextSize(chip.Text, chip.TextSize, chip.Font, Vector2.new(1000, 100)).X) + CHIP_TEXT_PAD)
		chip.Position = UDim2.new(0, chipX, 0, 0)
		chip.Size = UDim2.new(0, width, 1, 0)
		chipX += width + 4
		r.chips[classId] = { button = chip, stroke = stroke }
		r.chipsWidth = chipX
		chip.Activated:Connect(function()
			Leaderboard.selectClass(classId)
		end)
	end
	-- QUEUE-ALL9C 1-5(J2): 내 줄 = 목록 아래 항상 고정(옛 머리 줄 오른쪽 글)
	local myBar = Instance.new("Frame")
	myBar.Name = "MyRow"
	myBar.AnchorPoint = Vector2.new(0, 1)
	myBar.Position = UDim2.new(0, 0, 1, 0)
	myBar.Size = UDim2.new(1, -8, 0, rowHeight())
	myBar.BackgroundColor3 = UIColors.slot
	myBar.BackgroundTransparency = UIColors.slotTransparency
	myBar.Parent = pane
	Theme.corner(myBar, Theme.corner.chip)
	local myStroke = Theme.stroke(myBar)
	myStroke.Color = UIColors.ember
	myStroke.Transparency = 0
	local meLabel = Theme.label(myBar, "", "body", "textPrimary")
	meLabel.Name = "MyRank"
	meLabel.TextTruncate = Enum.TextTruncate.AtEnd
	meLabel.Position = UDim2.new(0, 10, 0, 0)
	meLabel.Size = UDim2.new(1, -20, 1, 0)
	r.meLabel = meLabel
	r.myBar = myBar

	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.new(0, 0, 0, rowHeight() + GAP)
	list.Size = UDim2.new(1, 0, 1, -(rowHeight() + GAP) * 2)
	list.ScrollBarThickness = 4
	list.ScrollBarImageColor3 = UIColors.rim
	list.AutomaticCanvasSize = Enum.AutomaticSize.None
	list.Parent = pane
	r.list = list

	local emptyLabel = Theme.label(list, "", "body", "textSecondary")
	emptyLabel.Name = "Empty"
	emptyLabel.Position = UDim2.new(0, 4, 0, 8)
	emptyLabel.Size = UDim2.new(1, -8, 0, Theme.textSize("body") * 6)
	emptyLabel.TextWrapped = true
	emptyLabel.TextYAlignment = Enum.TextYAlignment.Top
	emptyLabel.Visible = false
	r.emptyLabel = emptyLabel

	r.podium = Leaderboard.buildPodium(list)
	refs = r
end

-- 목록 줄 하나(재사용 - 탭을 바꿔도 인스턴스를 새로 만들지 않는다). 열: 순위 · 이름 · 스테이지 · 시간.
local function rowAt(index)
	local row = refs.rows[index]
	if row then
		return row
	end
	local button = Instance.new("TextButton")
	button.Name = "Row" .. index
	button.AutoButtonColor = false
	button.Text = ""
	button.BackgroundColor3 = UIColors.slot
	button.BackgroundTransparency = UIColors.slotTransparency
	button.Size = UDim2.new(1, -8, 0, rowHeight())
	button.Parent = refs.list
	Theme.corner(button, Theme.corner.chip)
	local stroke = Theme.stroke(button)
	local rank = Theme.label(button, "", "body", "textSecondary")
	rank.Name = "Rank"
	rank.Position = UDim2.new(0, 8, 0, 0)
	rank.Size = UDim2.new(0, 40, 1, 0)
	local name = Theme.label(button, "", "body", "textPrimary")
	name.Name = "PlayerName"
	name.Position = UDim2.new(0, 52, 0, 0)
	name.Size = UDim2.new(1, -(52 + 96 + 84 + 8), 1, 0)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local stage = Theme.label(button, "", "body", "textPrimary")
	stage.Name = "Stage"
	stage.AnchorPoint = Vector2.new(1, 0)
	stage.Position = UDim2.new(1, -(84 + 8), 0, 0)
	stage.Size = UDim2.new(0, 96, 1, 0)
	stage.TextXAlignment = Enum.TextXAlignment.Right
	local time = Theme.label(button, "", "body", "textSecondary")
	time.Name = "Time"
	time.AnchorPoint = Vector2.new(1, 0)
	time.Position = UDim2.new(1, -8, 0, 0)
	time.Size = UDim2.new(0, 80, 1, 0)
	time.TextXAlignment = Enum.TextXAlignment.Right
	local medal = Instance.new("TextLabel") -- QUEUE-ALL9C 1-5(J1): 1 · 2 · 3위 = 금 · 은 · 동 동그라미(순위 글 대신)
	medal.Name = "Medal"
	medal.AnchorPoint = Vector2.new(0.5, 0.5)
	medal.Position = UDim2.new(0, 26, 0.5, 0)
	medal.Size = UDim2.fromOffset(rowHeight() - 10, rowHeight() - 10)
	medal.Font = Enum.Font.GothamBlack
	medal.TextScaled = true
	medal.TextColor3 = Color3.fromRGB(40, 30, 10)
	medal.Visible = false
	medal.Parent = button
	Theme.corner(medal, 999)
	row = { button = button, stroke = stroke, rank = rank, name = name, stage = stage, time = time, entry = nil, medal = medal }
	button.Activated:Connect(function()
		if row.entry then
			Leaderboard.onRowPressed(row.entry)
		end
	end)
	refs.rows[index] = row
	return row
end

-- 파티 줄 아래 펼쳐지는 멤버 버튼(최대 4 - 재사용).
local function memberButtonAt(index)
	local item = refs.memberButtons[index]
	if item then
		return item
	end
	local button = makeButton(refs.list, "Member" .. index, "")
	button.TextXAlignment = Enum.TextXAlignment.Left
	button.TextColor3 = UIColors.textPrimary
	button.Size = UDim2.new(1, -48, 0, rowHeight())
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.Parent = button
	item = { button = button, userId = nil }
	button.Activated:Connect(function()
		if item.userId then
			Leaderboard.openCard("personal", "u" .. tostring(item.userId))
		end
	end)
	refs.memberButtons[index] = item
	return item
end

-- ═══ 그리기 ═══

local function paintTabs()
	for id, handle in pairs(refs.tabButtons) do
		local selected = id == state.tab
		handle.button.TextColor3 = selected and UIColors.textPrimary or UIColors.textSecondary
		handle.stroke.Color = selected and UIColors.ember or UIColors.rim
		handle.stroke.Transparency = selected and 0 or UIColors.rimTransparency
	end
	local showChips = state.tab == "class"
	for classId, handle in pairs(refs.chips) do
		handle.button.Visible = showChips
		local selected = classId == state.classId
		handle.button.TextColor3 = selected and (UIColors.classAccent[classId] or UIColors.textPrimary) or UIColors.textSecondary
		handle.stroke.Color = selected and UIColors.ember or UIColors.rim
		handle.stroke.Transparency = selected and 0 or UIColors.rimTransparency
	end
	refs.myBar.Visible = state.tab ~= "season" -- QUEUE-ALL9C 1-5: 내 줄 = 아래 고정(머리 줄 칩 옆 자리 계산 없음)
	refs.meLabel.Visible = state.tab ~= "season"
end

local function seasonText(season)
	if not season then
		return Text.get("ui.rank.season.loading")
	end
	local lines = { Text.get("ui.rank.season.head", { season = ("%d"):format(season.id), days = ("%d"):format(season.lengthDays) }) }
	if season.endsAt then
		local left = math.max(0, season.endsAt - os.time())
		table.insert(lines, Text.get("ui.rank.season.left", { days = ("%d"):format(math.floor(left / 86400)), hours = ("%d"):format(math.floor((left % 86400) / 3600)) }))
	else
		table.insert(lines, Text.get("ui.rank.season.noStart"))
	end
	table.insert(lines, "")
	table.insert(lines, Text.get("ui.rank.season.rule1"))
	table.insert(lines, Text.get("ui.rank.season.rule2"))
	table.insert(lines, Text.get("ui.rank.season.rule3"))
	table.insert(lines, Text.get("ui.rank.season.rule4"))
	table.insert(lines, Text.get("ui.rank.season.rule5"))
	-- P3c C7: 영구 개인 최고(시즌과 무관 - 프로필의 보스 클리어 최고).
	table.insert(lines, Text.get("ui.rank.season.myBest", { stage = ("%d"):format(player:GetAttribute("BestBossCleared") or 0) }))
	return table.concat(lines, "\n")
end

-- P3c E2: 시즌 탭 아래의 지난 시즌 순위표 제목(명예의 전당 - C7과 같은 데이터).
local function hallTitle(hall)
	if not hall then
		return Text.get("ui.rank.hall.loading")
	elseif (hall.season or 0) < 1 then
		return Text.get("ui.rank.hall.first")
	elseif not hall.exists or #(hall.entries or {}) == 0 then
		return Text.get("ui.rank.hall.empty", { season = ("%d"):format(hall.season) })
	end
	return Text.get("ui.rank.hall.title", { season = ("%d"):format(hall.season), count = ("%d"):format(#hall.entries) })
end

-- 지금 탭의 목록 · 내 순위 줄을 다시 그린다.
local function render()
	paintTabs()
	local boardId = currentBoardId()
	local rowH = rowHeight()
	local y = 0
	local used, usedMembers = 0, 0
	if state.tab == "season" then
		Leaderboard.renderPodium({}, nil)
		refs.emptyLabel.Visible = true
		refs.emptyLabel.Text = seasonText(state.season) .. "\n\n" .. hallTitle(state.hall)
		refs.emptyLabel.Size = UDim2.new(1, -8, 0, (Theme.textSize("body") + 6) * 12)
		y = (Theme.textSize("body") + 6) * 12 + 8
		-- P3c E2: 지난 시즌 개인 순위 줄(누르면 열리는 카드는 없다 - 카드는 지금 시즌 저장소라 지난 시즌 사람의 카드가 아닐 수 있다).
		local hall = state.hall
		for index, entry in ipairs(hall and hall.entries or {}) do
			local row = rowAt(index)
			used = index
			row.entry = nil
			row.button.Visible = true
			row.button.Position = UDim2.new(0, 0, 0, y)
			row.rank.Text = tostring(entry.rank)
			Leaderboard.paintMedal(row, entry.rank)
			local isMine = entry.userId == player.UserId
			row.name.Text = nameOf(hall.names, entry.userId)
			row.name.TextColor3 = isMine and UIColors.ember or UIColors.textPrimary
			row.stroke.Color = isMine and UIColors.ember or UIColors.rim
			row.stroke.Transparency = isMine and 0 or UIColors.rimTransparency
			row.stage.Text = Text.get("ui.rank.stage", { stage = ("%d"):format(entry.stage or 0) })
			row.time.Text = ""
			y += rowH + 4
		end
	else
		local board = state.boards[boardId]
		local entries = board and board.entries or {}
		local isParty = boardId == "party"
		refs.emptyLabel.Size = UDim2.new(1, -8, 0, Theme.textSize("body") * 3)
		refs.emptyLabel.Visible = #entries == 0
		refs.emptyLabel.Text = Text.get(board and "ui.rank.empty" or "ui.rank.loading")
		if REST then -- UI-1 7c(H §6): 빈 상태 = "스테이지를 깨면 여기에 이름이 올라가요" + [구역 선택 열기](보조)
			if board and #entries == 0 then
				refs.emptyLabel.Text = Text.get("ui.rank.empty") .. "\n" .. Text.get("ui1.rank.emptySub")
			end
			local open = refs.list:FindFirstChild("OpenStageSelect")
			if not open then
				local b = Button.build({ parent = refs.list, kind = "secondary", name = "OpenStageSelect", text = Text.get("ui1.rank.openStage"), width = 200, height = 44,
					position = UDim2.new(0, 4, 0, Theme.textSize("body") * 3 + 12), onActivated = function()
						UIManager.close(Leaderboard.id)
						UIManager.openLazy("stageSelect")
					end })
				open = b.root
				open.Name = "OpenStageSelect"
			end
			open.Visible = board ~= nil and #entries == 0
		end
		if #entries == 0 and REST and board then
			y = Theme.textSize("body") * 3 + 64
		end
		if #entries == 0 then
			y = Theme.textSize("body") * 3 + 8
		end
		y += Leaderboard.renderPodium(not isParty and entries or {}, board and board.names) -- QUEUE-ALL9C 1-5(J3): 위 시상대(개인 · 직업별)
		for index, entry in ipairs(entries) do
			local row = rowAt(index)
			used = index
			row.entry = entry
			row.button.Visible = true
			row.button.Position = UDim2.new(0, 0, 0, y)
			row.rank.Text = tostring(entry.rank)
			Leaderboard.paintMedal(row, entry.rank)
			local isMine = entry.userId == player.UserId or (entry.members and table.find(entry.members, player.UserId) ~= nil)
			local nameText
			if isParty then
				local names = {}
				for _, id in ipairs(entry.members or {}) do
					table.insert(names, nameOf(board.names, id))
				end
				nameText = table.concat(names, " · ")
			else
				nameText = nameOf(board.names, entry.userId)
			end
			local classId = REST and boardId:match("^class:(.+)$") -- UI-1 7c(H v1.1 §3): 직업 = 직업 이름(무기 이름 X) · 줄 데이터에 직업이 있는 직업별 탭만
			row.name.Text = classId and (nameText .. " · " .. Text.get("class.name." .. classId)) or nameText
			row.name.TextColor3 = isMine and UIColors.ember or UIColors.textPrimary
			row.stroke.Color = isMine and UIColors.ember or (UIColors.rankMedal[entry.rank] or UIColors.rim)
			row.stroke.Transparency = (isMine or UIColors.rankMedal[entry.rank]) and 0 or UIColors.rimTransparency
			row.stage.Text = Text.get("ui.rank.stage", { stage = ("%d"):format(entry.stage or 0) })
			row.time.Text = Leaderboard.formatSeconds(entry.seconds)
			y += rowH + 4
			if isParty and state.expandedParty == entry.key then
				for _, id in ipairs(entry.members or {}) do
					usedMembers += 1
					local item = memberButtonAt(usedMembers)
					item.userId = id
					item.button.Text = Text.get("ui.rank.memberGear", { name = nameOf(board.names, id) })
					item.button.Position = UDim2.new(0, 40, 0, y)
					item.button.Visible = true
					y += rowH + 4
				end
			end
		end
		local mine = state.me[boardId]
		refs.meLabel.Text = meText((board and board.mine and { rank = board.mine.rank, stage = board.mine.stage, seconds = board.mine.seconds }) or (mine and mine.result), isParty)
	end
	for index = used + 1, #refs.rows do
		refs.rows[index].button.Visible = false
		refs.rows[index].entry = nil
	end
	for index = usedMembers + 1, #refs.memberButtons do
		refs.memberButtons[index].button.Visible = false
		refs.memberButtons[index].userId = nil
	end
	refs.list.CanvasSize = UDim2.new(0, 0, 0, y + 4)
end

-- ═══ 요청 ═══

local function fetchMe(boardId, token)
	local cached = state.me[boardId]
	if cached and os.clock() - cached.at < ME_CACHE_SECONDS then
		return
	end
	task.spawn(function()
		for _ = 1, 2 do
			local result, reason = invoke("me", boardId)
			if token ~= state.token then
				return
			end
			if result then
				state.me[boardId] = { result = result, at = os.clock() }
				if currentBoardId() == boardId then
					render()
				end
				return
			end
			if reason ~= "rate_limited" then
				break
			end
			task.wait(ME_RETRY_SECONDS)
			if token ~= state.token or currentBoardId() ~= boardId then
				return
			end
		end
		-- 두 번 다 실패(간격 · 오류): "잠시 뒤" 표시 + 5초 뒤 캐시가 풀려 다음 갱신(탭 · 열기)이 다시 묻는다(리뷰 5).
		state.me[boardId] = { result = { ok = true, retry = true }, at = os.clock() - ME_CACHE_SECONDS + 5 }
		if currentBoardId() == boardId then
			render()
		end
	end)
end

-- 지금 탭의 순위표를 받는다(열 때 · 탭 · 직업을 바꿀 때). 서버 간격(1초)에 걸리면 1.1초 뒤 한 번 더.
function Leaderboard.refresh()
	if not refs then
		return
	end
	state.token += 1
	local token = state.token
	state.classId = state.classId or (ClassData.classes[player:GetAttribute("ClassId") or ""] and player:GetAttribute("ClassId")) or ClassData.order[1]
	render()
	local boardId = currentBoardId() or "personal" -- 시즌 탭은 시즌 정보만(개인 순위표 응답에 실려 온다)
	if state.tab == "season" then
		-- P3c E2: 지난 시즌 개인 순위(명예의 전당). 서버는 캐시만 돌려준다(저장소 요청은 서버가 30분에 한 번).
		task.spawn(function()
			local result = invoke("hall", "personal")
			if token == state.token and result then
				state.hall = result
				render()
			end
		end)
	end
	task.spawn(function()
		for _ = 1, 2 do
			local result, reason = invoke("board", boardId)
			if token ~= state.token then
				return
			end
			if result then
				state.boards[boardId] = result
				state.season = result.season
				render()
				if not result.mine and boardId == currentBoardId() then
					fetchMe(boardId, token)
				end
				return
			end
			if reason ~= "rate_limited" then
				return
			end
			task.wait(1.1)
			if token ~= state.token then
				return
			end
		end
	end)
end

function Leaderboard.selectTab(tabId)
	if state.tab == tabId then
		return
	end
	state.tab = tabId
	state.expandedParty = nil
	refs.list.CanvasPosition = Vector2.zero
	Leaderboard.refresh()
end

function Leaderboard.selectClass(classId)
	if state.classId == classId then
		return
	end
	state.classId = classId
	refs.list.CanvasPosition = Vector2.zero
	Leaderboard.refresh()
end

-- 카드 요청 → 장비 보기(무기만). 장비 보기를 닫으면 이 창으로 돌아온다.
function Leaderboard.openCard(boardId, key)
	task.spawn(function()
		local result, reason = invoke("card", boardId, key)
		if not result then
			Toast.push("TC", { text = Text.get(reason == "rate_limited" and "ui.rank.card.rateLimited" or "ui.rank.card.failed"), colorName = "textPrimary" })
			return
		end
		if type(result.card) ~= "table" or type(result.card.weapon) ~= "table" then
			Toast.push("TC", { text = Text.get("ui.rank.card.noGear"), colorName = "textPrimary" })
			return
		end
		if not UIManager.isOpen(Leaderboard.id) then
			return -- 응답이 오기 전에 순위 창을 닫았다(리뷰 4b)
		end
		Inspect.openCard(result.card, Leaderboard.id)
	end)
end

function Leaderboard.onRowPressed(entry)
	local boardId = currentBoardId()
	if boardId == "party" then
		state.expandedParty = state.expandedParty ~= entry.key and entry.key or nil
		render()
		return
	end
	Leaderboard.openCard(boardId, entry.key)
end

-- 모바일 판정(Studio ForceTouchLayout 포함)이 지은 뒤 바뀌었으면 다시 짓는다(보석 공방과 같은 방식 - 줄 높이 · 탭 높이가 판정에서 나온다).
local function ensureBuilt()
	Theme.recompute()
	if refs and refs.mobile ~= Theme.isMobile then
		UIManager.unregister(Leaderboard.id)
		refs.panel.screenGui:Destroy()
		refs = nil
	end
	if not refs then
		build()
	end
end

function Leaderboard.open()
	ensureBuilt()
	return UIManager.open(Leaderboard.id)
end

function Leaderboard.toggle()
	ensureBuilt()
	local ok, text = UIManager.switchTo(Leaderboard.id)
	if not ok and text then
		Toast.push("TC", { text = text, colorName = "textPrimary" })
	end
end

-- ═══ HUD 버튼 ═══

-- [순위] 버튼: 칩 스택(TopChipsRow) 왼쪽 [파티] 버튼(PartyToggleButton) 바로 아래. 파티 버튼이 칩 스택을 따라 움직이므로 그 버튼의 자리를 따라간다.
local function buildToggleButton()
	local gui = Instance.new("ScreenGui")
	gui.Name = "LeaderboardToggleGui"
	gui.ResetOnSpawn = false
	-- 순위 창이 열려 있는 동안만 창 딤 위(150 - 메뉴바와 같은 대역)로 올린다: 열린 채 이 버튼을 다시 누르면 닫혀야 한다(실제 클릭으로 확인한 결함 - 0이면 딤이 클릭을 먹었다).
	-- 다른 창이 열려 있을 때는 0(파티 버튼과 같은 HUD 층) - 늘 150이면 폰 가방 창(800 × 302) 위를 덮었다(스크린샷 Play).
	gui.DisplayOrder = 0
	UIManager.changed:Connect(function()
		gui.DisplayOrder = UIManager.isOpen(Leaderboard.id) and 150 or 0
	end)
	gui.Parent = player:WaitForChild("PlayerGui")

	local button = Instance.new("TextButton")
	button.Name = "LeaderboardToggleButton"
	ScreenMap.place(button, "TR", "leaderboardToggle")
	button.Size = UDim2.new(0, 72, 0, Theme.isMobile and Theme.touchMin or 36)
	button.Text = Text.get("ui.rank.title")
	button.Font = Theme.font
	button.TextSize = Theme.textSize("body")
	button.TextColor3 = UIColors.textPrimary
	button.BackgroundColor3 = UIColors.panel
	button.BackgroundTransparency = UIColors.panelTransparency
	button.Parent = gui
	Theme.corner(button, 8)
	Theme.stroke(button)
	button.Activated:Connect(Leaderboard.toggle)
	button.Visible = false -- QUEUE-ALL2 P2 중복 삭제: 왼쪽 메뉴 더보기 [순위] · L 키가 연다
	-- QUEUE-ALL1 R1: 단축키 L(PanelRegistry.actionKeys - 채팅 입력 중 = gameProcessed로 무시)
	local lKey = require(script.Parent.Parent.ui.PanelRegistry).actionKey("leaderboard")
	game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == lKey then
			Leaderboard.toggle()
		end
	end)
	-- QUEUE-ALL1 01 A-4: 아트 켬 = 아이콘 타일(순위 - 단축키 없음)
	local IconTile = require(script.Parent.Parent.ui.IconTile)
	local function tile()
		if not button:FindFirstChild("IconTile") then
			IconTile.apply(button, "rank", "L", { size = 40 }) -- QUEUE-ALL1 R1 단축키 L
		end
	end
	tile()
	workspace:GetAttributeChangedSignal("ArtStyleV1"):Connect(tile)
	player:GetAttributeChangedSignal("ForceTouchLayout"):Connect(function()
		task.defer(function() -- MenuBar가 Theme.recompute를 한 뒤
			button.Size = UDim2.new(0, 72, 0, Theme.isMobile and Theme.touchMin or 36)
		end)
	end)

	task.spawn(function()
		local partyButton = player.PlayerGui:WaitForChild("PartyToggleGui", 20)
		partyButton = partyButton and partyButton:WaitForChild("PartyToggleButton", 10)
		if not partyButton then
			return
		end
		local function reposition()
			local pos, size = partyButton.AbsolutePosition, partyButton.AbsoluteSize -- 둘 다 상단 인셋이 있는 ScreenGui라 같은 좌표계
			button.AnchorPoint = Vector2.new(1, 0)
			button.Position = UDim2.new(0, pos.X + size.X, 0, pos.Y + size.Y + 8)
		end
		reposition()
		partyButton:GetPropertyChangedSignal("AbsolutePosition"):Connect(reposition)
		partyButton:GetPropertyChangedSignal("AbsoluteSize"):Connect(reposition)
	end)
	return button
end

function Leaderboard.init()
	ensureBuilt()
	buildToggleButton()
end

-- 검사용: 지금 상태(탭 · 직업 · 보이는 줄 글 · 내 순위 글 · 캔버스).
function Leaderboard.debugState()
	local rows = {}
	for _, row in ipairs(refs.rows) do
		if row.button.Visible then
			table.insert(rows, ("%s|%s|%s|%s"):format(row.rank.Text, row.name.Text, row.stage.Text, row.time.Text))
		end
	end
	local members = {}
	for _, item in ipairs(refs.memberButtons) do
		if item.button.Visible then
			table.insert(members, item.button.Text)
		end
	end
	return { tab = state.tab, classId = state.classId, rows = rows, members = members, me = refs.meLabel.Text, meVisible = refs.meLabel.Visible, empty = refs.emptyLabel.Visible and refs.emptyLabel.Text or nil, canvas = refs.list.CanvasSize.Y.Offset }
end

-- 검사용: n번째 보이는 줄을 누른 것과 같은 일.
function Leaderboard.debugPressRow(index)
	local row = refs.rows[index]
	if row and row.entry then
		Leaderboard.onRowPressed(row.entry)
		return true
	end
	return false
end

return Leaderboard
