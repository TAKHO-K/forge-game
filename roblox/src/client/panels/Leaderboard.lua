-- 리더보드 순위 창(P3b A · L2) - window. 서버 캐시(Leaderboard.lua - LeaderboardRequest)만 읽는다(저장소 직접 요청 0).
--   입구: HUD [순위] 버튼(TR.leaderboardToggle - 칩 스택 왼쪽 [파티] 버튼 바로 아래). 메뉴바 4번째 칸은 폰 높이에서 BL 터치 예약 구역과 겹쳐(P2.5b 확인) 쓰지 않는다.
--   탭(왼쪽 세로 레일 - 폰 높이 302에서 가로 탭 + 목록 + 내 순위 줄을 세로로 쌓으면 목록이 2.5줄뿐이라 옆으로 뺐다):
--     전체(개인 - 클리어한 보스 스테이지 최고) · 직업별(보스 스테이지 + 시간, 직업 칩 4개) · 파티(구성별 최고) · 시즌(시즌 번호 · 기간 · 규칙).
--   목록 = 상위 100(서버 topN). "내 순위"는 목록 위 고정 줄(칩 오른쪽) - 캐시 안이면 board 응답에 같이 오고, 밖이면 "me" 요청 1회(서버 간격 10초 · 창이 60초 캐시).
--   줄을 누르면 장비 보기(리더보드 카드 - 무기 · 보석만 공개, 방어구 칸 "?") - 장비 보기를 닫으면 이 창으로 돌아온다. 파티 줄은 누르면 멤버 이름이 펼쳐지고, 멤버를 누르면 그 사람 카드.
-- 표시 글(스테이지 · 시간)은 서버가 LeaderboardRules.decode로 푼 값을 그대로 쓴다(화면용 복사 계산 없음).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local UIManager = require(script.Parent.Parent.UIManager)
local Panel = require(script.Parent.Parent.ui.kit.Panel)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local Toast = require(script.Parent.Parent.ui.kit.Toast)
local ScreenMap = require(script.Parent.Parent.ui.ScreenMap)
local Inspect = require(script.Parent.Inspect)

local Leaderboard = {}

Leaderboard.id = "leaderboard"
local RAIL_WIDTH = 96
local GAP = 6
local PAD = 8
local CHIP_WIDTH = 64
local ME_CACHE_SECONDS = 60
local ME_RETRY_SECONDS = 10.5 -- 서버 "me" 간격(LeaderboardConfig.requestIntervalSeconds.me = 10) 바로 뒤

local player = Players.LocalPlayer
local request = ReplicatedStorage:WaitForChild("LeaderboardRequest")

local TABS = {
	{ id = "all", text = "전체" },
	{ id = "class", text = "직업별" },
	{ id = "party", text = "파티" },
	{ id = "season", text = "시즌" },
}

local refs
local state = {
	tab = "all",
	classId = nil, -- 직업별 탭의 직업(처음 = 내 직업)
	boards = {}, -- [boardId] = board 응답(마지막)
	me = {}, -- [boardId] = { result, at }
	expandedParty = nil, -- 펼친 파티 줄의 key
	token = 0,
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
		return "내 순위: 불러오는 중…"
	end
	if result.rank then
		local timeText = result.seconds and (" · " .. Leaderboard.formatSeconds(result.seconds)) or ""
		return ("내 순위 %d위 · 스테이지 %d%s"):format(result.rank, result.stage or 0, timeText)
	end
	if result.outOfTop and result.stage then
		return ("내 순위: %d위 밖 · 스테이지 %d"):format(result.topN or 100, result.stage)
	end
	if result.outOfTop and isParty then
		return ("내 파티: %d위 안 기록 없음"):format(result.topN or 100)
	end
	return "내 순위: 기록 없음"
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

local function build()
	local panel = Panel.create({
		id = Leaderboard.id,
		kind = "window",
		title = "순위",
		size = Vector2.new(660, 440),
		help = "보스 스테이지를 깬 기록만 순위에 오릅니다. 자기 최고 다음 보스를 깨고 본인이 피해 10% 이상을 넣어야 합니다. 순위표는 약 90초마다 갱신됩니다.",
		onOpen = function()
			Leaderboard.refresh()
		end,
		onClose = function()
			state.token += 1
		end,
	})
	local content = panel.content
	local r = { panel = panel, tabButtons = {}, chips = {}, rows = {}, memberButtons = {} }

	-- 왼쪽 레일(탭)
	for index, tab in ipairs(TABS) do
		local button, stroke = makeButton(content, "Tab_" .. tab.id, tab.text)
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
	for index, classId in ipairs(ClassData.order) do
		local class = ClassData.classes[classId]
		local chip, stroke = makeButton(header, "Chip_" .. classId, class.displayName)
		chip.Position = UDim2.new(0, (index - 1) * (CHIP_WIDTH + 4), 0, 0)
		chip.Size = UDim2.new(0, CHIP_WIDTH, 1, 0)
		r.chips[classId] = { button = chip, stroke = stroke }
		chip.Activated:Connect(function()
			Leaderboard.selectClass(classId)
		end)
	end
	local meLabel = Theme.label(header, "", "body", "textPrimary")
	meLabel.Name = "MyRank"
	meLabel.TextTruncate = Enum.TextTruncate.AtEnd
	meLabel.Size = UDim2.new(1, 0, 1, 0)
	r.meLabel = meLabel

	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.new(0, 0, 0, rowHeight() + GAP)
	list.Size = UDim2.new(1, 0, 1, -(rowHeight() + GAP))
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
	row = { button = button, stroke = stroke, rank = rank, name = name, stage = stage, time = time, entry = nil }
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
	local chipsWidth = showChips and (#ClassData.order * (CHIP_WIDTH + 4) + 8) or 0
	refs.meLabel.Position = UDim2.new(0, chipsWidth + 4, 0, 0)
	refs.meLabel.Size = UDim2.new(1, -(chipsWidth + 4), 1, 0)
	refs.meLabel.Visible = state.tab ~= "season"
end

local function seasonText(season)
	if not season then
		return "시즌 정보를 불러오는 중…"
	end
	local lines = { ("시즌 %d · 기간 %d일"):format(season.id, season.lengthDays) }
	if season.endsAt then
		local left = math.max(0, season.endsAt - os.time())
		table.insert(lines, ("남은 기간: %d일 %d시간"):format(math.floor(left / 86400), math.floor((left % 86400) / 3600)))
	else
		table.insert(lines, "시작일: 아직 정해지지 않았습니다")
	end
	table.insert(lines, "")
	table.insert(lines, "· 순위는 시즌마다 새로 시작합니다(전체 · 직업별 · 파티 모두).")
	table.insert(lines, "· 직업별 · 파티 순위: 스테이지가 높을수록, 같으면 클리어 시간이 짧을수록 위.")
	table.insert(lines, "· 파티 기록: 그 처치로 파티원 전원의 개인 최고가 오를 때만 남습니다.")
	table.insert(lines, "· 순위표는 약 90초마다 갱신됩니다.")
	return table.concat(lines, "\n")
end

-- 지금 탭의 목록 · 내 순위 줄을 다시 그린다.
local function render()
	paintTabs()
	local boardId = currentBoardId()
	local rowH = rowHeight()
	local y = 0
	local used, usedMembers = 0, 0
	if state.tab == "season" then
		refs.emptyLabel.Visible = true
		refs.emptyLabel.Text = seasonText(state.season)
		refs.emptyLabel.Size = UDim2.new(1, -8, 0, (Theme.textSize("body") + 6) * 8)
		y = (Theme.textSize("body") + 6) * 8 + 8
	else
		local board = state.boards[boardId]
		local entries = board and board.entries or {}
		local isParty = boardId == "party"
		refs.emptyLabel.Size = UDim2.new(1, -8, 0, Theme.textSize("body") * 3)
		refs.emptyLabel.Visible = #entries == 0
		refs.emptyLabel.Text = board and "아직 기록이 없습니다" or "불러오는 중…"
		if #entries == 0 then
			y = Theme.textSize("body") * 3 + 8
		end
		for index, entry in ipairs(entries) do
			local row = rowAt(index)
			used = index
			row.entry = entry
			row.button.Visible = true
			row.button.Position = UDim2.new(0, 0, 0, y)
			row.rank.Text = tostring(entry.rank)
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
			row.name.Text = nameText
			row.name.TextColor3 = isMine and UIColors.ember or UIColors.textPrimary
			row.stroke.Color = isMine and UIColors.ember or UIColors.rim
			row.stroke.Transparency = isMine and 0 or UIColors.rimTransparency
			row.stage.Text = ("스테이지 %d"):format(entry.stage or 0)
			row.time.Text = Leaderboard.formatSeconds(entry.seconds)
			y += rowH + 4
			if isParty and state.expandedParty == entry.key then
				for _, id in ipairs(entry.members or {}) do
					usedMembers += 1
					local item = memberButtonAt(usedMembers)
					item.userId = id
					item.button.Text = ("%s - 장비 보기"):format(nameOf(board.names, id))
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
				state.me[boardId] = { result = { ok = true }, at = os.clock() - ME_CACHE_SECONDS + 5 } -- 5초 뒤 다시
				return
			end
			task.wait(ME_RETRY_SECONDS)
			if token ~= state.token or currentBoardId() ~= boardId then
				return
			end
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
			Toast.push("TC", { text = reason == "rate_limited" and "잠시 뒤 다시 눌러 주세요" or "장비 정보를 불러오지 못했습니다", colorName = "textPrimary" })
			return
		end
		if type(result.card) ~= "table" or type(result.card.weapon) ~= "table" then
			Toast.push("TC", { text = "이 기록에는 장비 정보가 없습니다", colorName = "textPrimary" })
			return
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

-- ═══ HUD 버튼 ═══

-- [순위] 버튼: 칩 스택(TopChipsRow) 왼쪽 [파티] 버튼(PartyToggleButton) 바로 아래. 파티 버튼이 칩 스택을 따라 움직이므로 그 버튼의 자리를 따라간다.
local function buildToggleButton()
	local gui = Instance.new("ScreenGui")
	gui.Name = "LeaderboardToggleGui"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local button = Instance.new("TextButton")
	button.Name = "LeaderboardToggleButton"
	ScreenMap.place(button, "TR", "leaderboardToggle")
	button.Size = UDim2.new(0, 72, 0, Theme.isMobile and Theme.touchMin or 36)
	button.Text = "순위"
	button.Font = Theme.font
	button.TextSize = Theme.textSize("body")
	button.TextColor3 = UIColors.textPrimary
	button.BackgroundColor3 = UIColors.panel
	button.BackgroundTransparency = UIColors.panelTransparency
	button.Parent = gui
	Theme.corner(button, 8)
	Theme.stroke(button)
	button.Activated:Connect(function()
		UIManager.toggle(Leaderboard.id)
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
	build()
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
