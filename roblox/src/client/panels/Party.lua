-- 파티창(S12b E) - 독립 window. 예전에는 장비창(InventoryUI)의 "파티" 탭이었다(24-1 · 24-2) - 같은 내용(내 파티 · 서버 플레이어 · 다른 서버 친구 · 코드 · 만들기 · 탈퇴)을 그대로 옮겼고 동작 변경은 없다.
-- 열기: HUD [파티] 버튼(TR.partyToggle - 칩 스택 왼쪽) + P 키(PanelRegistry - 채팅 입력 중이면 UIManager가 gameProcessed로 무시한다). 모바일은 버튼.
-- S12b가 바꾼 것: ① 이름 줄 = "★n Lv.35 표시이름"(D - 레벨은 이름 줄로 옮겨 가 meta에서 뺐다) ② 이름을 누르면 이름 클릭 메뉴(A - 자기 · 서버 플레이어 · 파티원, 더미 · 다른 서버 친구는 제외)
-- ③ 글씨 4단(G - 20 · 16 · 14 · 12, 모바일 × 1.15는 Theme.textSize) · 모바일 버튼 44 이상 ④ 본문 고정 캔버스 + 창 안 스크롤(화면보다 작은 창에서 잘리지 않게 - COMMON.md §2).
-- 판정은 전부 서버(PartyServer.server.lua) - 여기 버튼은 요청만 보낸다. Party.init()이 창과 HUD 버튼을 짓고 서버 스냅샷(PartyStateChanged)을 듣는다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local PartyConfig = require(ReplicatedStorage.Shared.data.PartyConfig)
local PlayerLabelFormat = require(ReplicatedStorage.Shared.PlayerLabelFormat)
local Text = require(ReplicatedStorage.Shared.Text)
local UIManager = require(script.Parent.Parent.UIManager)
local FriendInvite = require(script.Parent.Parent.FriendInvite)
local HelpTooltip = require(script.Parent.Parent.HelpTooltip)
local PlayerMenu = require(script.Parent.PlayerMenu)
local ScreenMap = require(script.Parent.Parent.ui.ScreenMap)
local PartyAway = require(script.Parent.Parent.hud.PartyAway)
local Panel = require(script.Parent.Parent.ui.kit.Panel)
local Toast = require(script.Parent.Parent.ui.kit.Toast)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local Tabs = require(script.Parent.Parent.ui.kit.Tabs)
local PartyBoard = require(script.Parent.PartyBoard) -- QUEUE-ALL9C 1-4: 모집 게시판 = 파티창 [파티 찾기] 탭 안(옛 독립 창)

local Party = {}

Party.id = "party"

local UIColors = Theme.colors
local player = Players.LocalPlayer
local partyRequest = ReplicatedStorage:WaitForChild("PartyRequest")
local partyStateChanged = ReplicatedStorage:WaitForChild("PartyStateChanged")
local partyFriendsFetch = ReplicatedStorage:WaitForChild("PartyFriendsFetch") -- 24-2: 다른 서버의 온라인 친구

local COLUMN_WIDTH = 330
local ROW_GAP = 6
local BODY_WIDTH = 14 + COLUMN_WIDTH + 30 + COLUMN_WIDTH + 14

local windowOpen = false
local partyState = nil -- 서버 스냅샷(PartyStateChanged) - nil이면 파티 없음.
local friendsElsewhere = {} -- 다른 서버의 온라인 친구(서버 응답 캐시)
local refs -- build가 채운다

local function classNameOf(classId)
	return classId and ClassData.classes[classId] and Text.get("class.name." .. classId) or "-"
end

local function isMeLeader()
	return partyState ~= nil and partyState.leaderUserId == player.UserId
end

-- QUEUE-ALL2 P2 B-4 ②: 첫 보스(스테이지 5) 처치 뒤 1회 안내(이번 접속 · 계정당 한 번 넘어가는 순간) - 누르면 파티 창
player:GetAttributeChangedSignal("BestBossCleared"):Connect(function()
	local best = player:GetAttribute("BestBossCleared") or 0
	if best >= 5 and not Party.invitePromptShown and (Party.lastBest or 0) < 5 and Party.lastBest ~= nil then
		Party.invitePromptShown = true
		Toast.push("TC", { text = Text.get("party.invitePrompt"), colorName = "gold" })
	end
	Party.lastBest = best
end)
task.defer(function()
	Party.lastBest = player:GetAttribute("BestBossCleared") or 0
end)

local function build()
	local ROW_HEIGHT = Theme.isMobile and 52 or 38
	local BUTTON_HEIGHT = Theme.isMobile and 44 or 24
	local PILL_HEIGHT = Theme.isMobile and 44 or 28
	local nameSize, metaSize = Theme.textSize("body"), Theme.textSize("caption")
	local nameHeight, metaHeight = nameSize + 2, metaSize + 2
	-- QUEUE-ALL9C 2-6: 폰 = 코드 · 합류 · 만들기 줄을 내 파티 목록 위로(작은 폰 389에서 멤버 4줄 아래에 있던 코드 입력이 스크롤 밖으로 숨던 것)
	local CODE_FIRST = Theme.isMobile
	local membersHeight = PartyConfig.maxMembers * (ROW_HEIGHT + ROW_GAP)
	local MY_EXTRA_Y = CODE_FIRST and 40 or (40 + membersHeight + 8)
	local codeHeight, hintHeight = Theme.textSize("body") + 4, Theme.textSize("caption") + 4
	local joinY = MY_EXTRA_Y + codeHeight + hintHeight + 6
	local createY = joinY + PILL_HEIGHT + 8
	local friendY = createY + PILL_HEIGHT + 8
	local MEMBERS_TOP = CODE_FIRST and (createY + PILL_HEIGHT + 8) or 40
	local BODY_HEIGHT = CODE_FIRST and (MEMBERS_TOP + membersHeight + 8) or (friendY + PILL_HEIGHT + 8 + PILL_HEIGHT + 8)

	local panel = Panel.create({
		id = Party.id,
		kind = "window",
		title = Text.get("ui.party.title"),
		size = Vector2.new(720, 480),
		onOpen = function()
			windowOpen = true
			if refs then
				refs.refreshFriends()
				refs.update()
			end
		end,
		onClose = function()
			windowOpen = false
		end,
	})

	-- QUEUE-ALL9C 1-4(H + L1): 파티 기능 한 곳 = HUD [파티] 버튼 · P → 이 창의 탭(내 파티 · 파티 찾기). 친구 초대 = 제목줄 오른쪽(그대로).
	local tabTop = Theme.tabHeight + 10
	local boardPage = Instance.new("Frame")
	boardPage.Name = "BoardPage"
	boardPage.BackgroundTransparency = 1
	boardPage.Position = UDim2.fromOffset(0, tabTop)
	boardPage.Size = UDim2.new(1, 0, 1, -tabTop)
	boardPage.Visible = false
	boardPage.Parent = panel.content

	-- 고정 캔버스 + 창 안 스크롤: 화면이 작아 창이 캔버스보다 작아지면 위아래(좁으면 좌우)로 민다.
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Body"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(0, tabTop)
	scroll.Size = UDim2.new(1, 0, 1, -tabTop)
	scroll.ScrollingDirection = Enum.ScrollingDirection.XY
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = UIColors.rim
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.None
	scroll.CanvasSize = UDim2.new(0, BODY_WIDTH, 0, BODY_HEIGHT)
	scroll.Parent = panel.content

	local partyBody = Instance.new("Frame")
	partyBody.Name = "PartyBody"
	partyBody.Size = UDim2.new(0, BODY_WIDTH, 0, BODY_HEIGHT)
	partyBody.BackgroundTransparency = 1
	partyBody.Parent = scroll

	-- 좌: 내 파티 / 우: 서버 플레이어 - 두 열의 틀은 같다(제목 + 세로 목록).
	local function makeColumn(x, titleText)
		local column = Instance.new("Frame")
		column.Position = UDim2.new(0, x, 0, 0)
		column.Size = UDim2.new(0, COLUMN_WIDTH, 1, 0)
		column.BackgroundTransparency = 1
		column.Parent = partyBody

		local title = Theme.label(column, titleText, "caption", "textTertiary")
		title.Font = Theme.font
		title.Position = UDim2.new(0, 0, 0, 12)
		title.Size = UDim2.new(1, -30, 0, metaSize + 4)

		-- 24-2: 서버 플레이어(최대 16) + 다른 서버 친구 목록이 한 열에 들어가야 해서 스크롤 프레임으로.
		local listFrame = Instance.new("ScrollingFrame")
		listFrame.Position = UDim2.new(0, 0, 0, 40)
		listFrame.Size = UDim2.new(1, 0, 1, -40)
		listFrame.BackgroundTransparency = 1
		listFrame.BorderSizePixel = 0
		listFrame.ScrollBarThickness = 4
		listFrame.ScrollBarImageColor3 = UIColors.rim
		listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
		listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
		listFrame.Parent = column

		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Vertical
		layout.Padding = UDim.new(0, ROW_GAP)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = listFrame

		return column, title, listFrame
	end

	local myColumn, myTitle, myList = makeColumn(14, Text.get("ui.party.myParty"))
	if CODE_FIRST then -- 폰: 멤버 목록은 코드 줄 아래
		myList.Position = UDim2.new(0, 0, 0, MEMBERS_TOP)
		myList.Size = UDim2.new(1, 0, 1, -MEMBERS_TOP)
	end
	local serverColumn, serverTitle, serverList = makeColumn(14 + COLUMN_WIDTH + 30, Text.get("ui.party.serverPlayers"))
	local _ = serverColumn

	-- 25-3 · S09의 파티 도움말("?"). 숫자(기여 10% · 경험치 보너스 · 투표 10초)는 데이터에서 읽어 끼운다. 패널은 280 × 176 고정.
	do
		local gatePercent = math.floor(CombatConfig.contributionRewardThreshold * 100 + 0.5)
		local bonusParts = {}
		for memberCount = 2, PartyConfig.maxMembers do
			table.insert(bonusParts, Text.get("ui.party.help.bonusPart", { count = ("%d"):format(memberCount), percent = ("%d"):format(math.floor(PartyConfig.expBonusByMemberCount[memberCount] * 100 + 0.5)) }))
		end
		local helpButton = HelpTooltip.attach(myColumn, UDim2.new(0, 62, 0, 19), { short = Text.get("party.help.short", { percent = gatePercent }), detail = table.concat({ -- G1-1: 2단
			Text.get("ui.party.help.gateHead", { percent = ("%d"):format(gatePercent) }),
			Text.get("ui.party.help.gateBody", { percent = ("%d"):format(gatePercent) }),
			Text.get("ui.party.help.expHead"),
			Text.get("ui.party.help.expBody", { bonuses = table.concat(bonusParts, " · ") }),
			Text.get("ui.party.help.dropHead"),
			Text.get("ui.party.help.dropBody"),
			Text.get("ui.party.help.stageHead"),
			Text.get("ui.party.help.stageBody", { seconds = ("%d"):format(PartyConfig.stageVoteTimeoutSeconds) }),
		}, "\n") }, nil, { panelSize = Vector2.new(280, 176) })
		-- QUEUE-ALL9C 블록 1 폰 캡처: "?"가 고정 x 62라 "내 파티 (0/4)"(폰 글씨 ×1.15)와 겹쳤다 → 제목 글자 끝 + 12에 붙인다
		local function placeHelp()
			local x = myTitle.AbsolutePosition.X - myColumn.AbsolutePosition.X + myTitle.TextBounds.X + 12
			helpButton.Position = UDim2.new(0, math.max(62, math.floor(x)), 0, 19)
		end
		myTitle:GetPropertyChangedSignal("TextBounds"):Connect(placeHelp)
		myColumn:GetPropertyChangedSignal("AbsolutePosition"):Connect(placeHelp)
		task.defer(placeHelp)
	end

	-- 열 사이 세로 구분선.
	local divider = Instance.new("Frame")
	divider.Position = UDim2.new(0, 14 + COLUMN_WIDTH + 14, 0, 12)
	divider.Size = UDim2.new(0, 1, 1, -24)
	divider.BackgroundColor3 = UIColors.rim
	divider.BackgroundTransparency = UIColors.rimTransparency
	divider.BorderSizePixel = 0
	divider.Parent = partyBody

	-- 행 하나: [이름(누르면 메뉴)] [직업 · 스테이지]            [버튼]
	local function makeRow(parent, order)
		local row = Instance.new("Frame")
		row.LayoutOrder = order
		row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
		row.BackgroundColor3 = UIColors.slot
		row.BackgroundTransparency = UIColors.slotTransparency
		row.Parent = parent
		Theme.corner(row, 8)
		Theme.stroke(row)

		local top = math.floor((ROW_HEIGHT - nameHeight - metaHeight) / 2)
		local name = Instance.new("TextButton")
		name.AutoButtonColor = false
		name.BackgroundTransparency = 1
		name.Position = UDim2.new(0, 10, 0, top)
		name.Size = UDim2.new(1, -96, 0, nameHeight)
		name.Font = Theme.font
		name.TextSize = nameSize
		name.RichText = true
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.TextColor3 = UIColors.textPrimary
		name.Text = ""
		name.Parent = row

		local meta = Theme.label(row, "", "caption", "textSecondary")
		meta.Position = UDim2.new(0, 10, 0, top + nameHeight)
		meta.Size = UDim2.new(1, -96, 0, metaHeight)

		local button = Instance.new("TextButton")
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.new(1, -8, 0.5, 0)
		button.Size = UDim2.new(0, 72, 0, BUTTON_HEIGHT)
		button.Font = Theme.font
		button.TextSize = Theme.textSize("caption")
		button.TextColor3 = Color3.new(0, 0, 0)
		button.BackgroundColor3 = UIColors.gold
		button.BackgroundTransparency = 0.1
		button.Parent = row
		Theme.corner(button, 12)

		return { frame = row, name = name, meta = meta, button = button, connection = nil, nameConnection = nil }
	end

	local myRows, serverRows, friendRows = {}, {}, {}

	local function makePillButton(parent, text, x, y, width, accent)
		local button = Instance.new("TextButton")
		button.Position = UDim2.new(0, x, 0, y)
		button.Size = UDim2.new(0, width, 0, PILL_HEIGHT)
		button.Font = Theme.font
		button.TextSize = Theme.textSize("caption")
		button.Text = text
		button.TextColor3 = accent and Color3.new(0, 0, 0) or UIColors.textPrimary
		button.BackgroundColor3 = accent and UIColors.gold or UIColors.panel
		button.BackgroundTransparency = accent and 0.1 or UIColors.panelTransparency
		button.Parent = parent
		Theme.corner(button, 14)
		Theme.stroke(button)
		return button
	end

	-- ═══ 24-2 크로스서버: 파티 코드 · 코드로 합류 · 파티 만들기(내 파티 열, 멤버 4행 아래) ═══
	local codeLabel = Theme.label(myColumn, "", "body", "gold")
	codeLabel.Font = Theme.font
	codeLabel.Position = UDim2.new(0, 0, 0, MY_EXTRA_Y)
	codeLabel.Size = UDim2.new(1, 0, 0, codeHeight)
	codeLabel.Visible = false

	local codeHint = Theme.label(myColumn, Text.get("ui.party.codeHint"), "caption", "textTertiary")
	codeHint.Position = UDim2.new(0, 0, 0, MY_EXTRA_Y + codeHeight)
	codeHint.Size = UDim2.new(1, 0, 0, hintHeight)
	codeHint.Visible = false

	-- 코드 입력 상자 - 장비 패널 슬롯 틀(slot 색 + rim 링)을 그대로 쓴다.
	local joinBox = Instance.new("TextBox")
	joinBox.Position = UDim2.new(0, 0, 0, joinY)
	joinBox.Size = UDim2.new(0, 160, 0, PILL_HEIGHT)
	joinBox.Font = Theme.font
	joinBox.TextSize = Theme.textSize("body")
	joinBox.PlaceholderText = Text.get("ui.party.codePlaceholder")
	joinBox.PlaceholderColor3 = UIColors.textTertiary
	joinBox.Text = ""
	joinBox.TextColor3 = UIColors.textPrimary
	joinBox.ClearTextOnFocus = false
	joinBox.BackgroundColor3 = UIColors.slot
	joinBox.BackgroundTransparency = UIColors.slotTransparency
	joinBox.Parent = myColumn
	Theme.corner(joinBox, 8)
	Theme.stroke(joinBox)

	local joinButton = makePillButton(myColumn, Text.get("ui.party.joinCode"), 168, joinY, 96, true)
	joinButton.Activated:Connect(function()
		local code = joinBox.Text:gsub("%s", ""):upper()
		if #code > 0 then
			partyRequest:FireServer("joincode", code)
			joinBox.Text = ""
		end
	end)

	local createButton = makePillButton(myColumn, Text.get("ui.party.create"), 0, createY, 160, false)
	createButton.Activated:Connect(function()
		partyRequest:FireServer("create")
	end)

	local cancelJoinButton = makePillButton(myColumn, Text.get("ui.party.cancelJoin"), 168, createY, 110, false)
	cancelJoinButton.Activated:Connect(function()
		partyRequest:FireServer("cancel_join")
	end)

	-- S12: [친구 부르기] - 로블록스 기본 초대 창. 견습 1단계에서는 TutorialHud의 같은 버튼이 강조되고, 여기는 상시다(장비창 파티 탭에서 이 창으로 옮겨 왔다 - 역할이 겹치지 않는다). 초대를 못 보내는 환경이면 숨긴다.
	-- QUEUE-ALL2 P2 B-4 ②: 친구 초대 = 창 맨 위(제목줄 오른쪽 - 금색 · 초대 보상 안내 · 05 문서 SocialReward와 같은 초대) · 옛 본문 자리는 비운다(중복 삭제)
	local inviteFriendButton = makePillButton(panel.frame, Text.get("party.inviteTop"), 0, 0, 200, true)
	inviteFriendButton.Name = "InviteFriendButton"
	inviteFriendButton.AnchorPoint = Vector2.new(1, 0)
	inviteFriendButton.Position = UDim2.new(1, -(Panel.closeSize + 12), 0, 8)
	inviteFriendButton.ZIndex = 20
	inviteFriendButton.Visible = false
	FriendInvite.onAvailability(function(canShow)
		inviteFriendButton.Visible = canShow
	end)
	inviteFriendButton.Activated:Connect(function()
		FriendInvite.prompt()
	end)

	-- A2-N4 §4-4 모집 게시판 → QUEUE-ALL9C 1-4: [파티 찾기] 탭(옛 [모집 게시판] 버튼 · 독립 창 삭제)
	PartyBoard.mount(boardPage)
	local tabs = Tabs.build({ parent = panel.content, tabs = { { id = "party", text = Text.get("party.tab.party") }, { id = "board", text = Text.get("party.tab.board") } },
		selected = "party", width = 420, position = UDim2.fromOffset(12, 4), onSelect = function(id)
			scroll.Visible = id == "party"
			boardPage.Visible = id == "board"
			if id == "board" then
				PartyBoard.refresh()
			end
		end })
	Party.tabs = tabs

	local function ensureRows(rowsTable, parent, count)
		for i = #rowsTable + 1, count do
			rowsTable[i] = makeRow(parent, i)
		end
		for i, row in ipairs(rowsTable) do
			row.frame.Visible = i <= count
			if row.connection then
				row.connection:Disconnect()
				row.connection = nil
			end
			if row.nameConnection then
				row.nameConnection:Disconnect()
				row.nameConnection = nil
			end
		end
	end

	-- 탈퇴 버튼 - 내 파티 열 맨 아래(위험 동작이라 hp색).
	local leaveButton = Instance.new("TextButton")
	leaveButton.AnchorPoint = Vector2.new(0, 1)
	leaveButton.Position = UDim2.new(0, 0, 1, -8)
	leaveButton.Size = UDim2.new(0, 110, 0, PILL_HEIGHT)
	leaveButton.Font = Theme.font
	leaveButton.TextSize = Theme.textSize("caption")
	leaveButton.Text = Text.get("ui.party.leave")
	leaveButton.TextColor3 = UIColors.textPrimary
	leaveButton.BackgroundColor3 = UIColors.hpDark
	leaveButton.BackgroundTransparency = 0.1
	leaveButton.Visible = false
	leaveButton.Parent = myColumn
	Theme.corner(leaveButton, 14)
	local leaveStroke = Theme.stroke(leaveButton)
	leaveStroke.Color = UIColors.hp
	leaveButton.Activated:Connect(function()
		partyRequest:FireServer("leave")
	end)

	local emptyLabel = Theme.label(myColumn, Text.get("ui.party.empty"), "caption", "textTertiary")
	emptyLabel.Position = UDim2.new(0, 0, 0, CODE_FIRST and (MEMBERS_TOP + 4) or 44) -- 폰 = 코드 줄 아래(멤버 자리)
	emptyLabel.Size = UDim2.new(1, 0, 0, metaSize * 3 + 6)
	emptyLabel.TextWrapped = true
	emptyLabel.TextYAlignment = Enum.TextYAlignment.Top
	emptyLabel.TextTruncate = Enum.TextTruncate.None

	-- 다른 서버 친구 구분 라벨(서버 플레이어 행들 아래 끼운다).
	local friendsHeader = Theme.label(serverList, "", "caption", "textTertiary")
	friendsHeader.Font = Theme.font
	friendsHeader.Size = UDim2.new(1, 0, 0, metaSize + 6)
	friendsHeader.Visible = false

	local function openMenu(userId, displayName, level, rebirth)
		return function()
			PlayerMenu.open({ userId = userId, displayName = displayName, level = level, rebirth = rebirth })
		end
	end

	local function setInviteButton(row, enabled, onClick)
		row.button.AutoButtonColor = enabled
		row.button.BackgroundColor3 = enabled and UIColors.gold or UIColors.panel
		row.button.TextColor3 = enabled and Color3.new(0, 0, 0) or UIColors.textTertiary
		if enabled then
			row.connection = row.button.Activated:Connect(onClick)
		end
	end

	local function update()
		if not windowOpen then
			return
		end
		-- ── 내 파티 ──
		local members = partyState and partyState.members or {}
		local pending = partyState and partyState.pending or {} -- 24-2: 다른 서버에서 이동 중인 좌석
		myTitle.Text = Text.get((partyState and partyState.bossActive) and "ui.party.myTitleBoss" or "ui.party.myTitle", { count = ("%d"):format(#members + #pending), max = ("%d"):format(PartyConfig.maxMembers) })
		emptyLabel.Visible = #members == 0
		leaveButton.Visible = #members > 0
		codeLabel.Visible = #members > 0
		codeHint.Visible = #members > 0
		codeLabel.Text = partyState and partyState.code and Text.get("ui.party.code", { code = partyState.code }) or Text.get("ui.party.codePending")
		createButton.Visible = #members == 0
		cancelJoinButton.Visible = #members == 0
		ensureRows(myRows, myList, #members + #pending)
		for i, member in ipairs(members) do
			local row = myRows[i]
			local target = (not member.isDummy) and Players:GetPlayerByUserId(member.userId) or nil
			local last = member.last -- S19b: 연결 끊김 유예 중인 멤버는 Player가 없다 - 끊기기 직전 값
			local awayText = PartyAway.text(member, false)
			local classId = member.isDummy and member.dummy.classId or (target and target:GetAttribute("ClassId")) or (last and last.classId)
			local level = member.isDummy and member.dummy.level or (target and target:GetAttribute("CharacterLevel")) or (last and last.level)
			local rebirth = (target and target:GetAttribute("RebirthCount")) or (last and last.rebirth)
			local stage = member.isDummy and member.dummy.stage or (target and target:GetAttribute("InfiniteStage")) or (last and last.stage)
			local displayName = (target and target.DisplayName) or (last and last.displayName) or member.name
			-- 파티장 표시는 금색 이름(옛 "★ " 표시는 환생 ★n과 헷갈려 뺐다).
			row.name.Text = PlayerLabelFormat.richText(member.isDummy and Text.get("ui.party.dummyName", { name = displayName }) or displayName, level, rebirth, nameSize)
			row.name.TextColor3 = awayText and UIColors.textSecondary or (member.isLeader and UIColors.gold or UIColors.textPrimary)
			local meta = Text.get("ui.party.memberMeta", { class = classNameOf(classId), stage = tostring(stage or "-") })
			row.meta.Text = awayText and ("%s · %s"):format(awayText, meta) or meta
			if target then
				row.nameConnection = row.name.Activated:Connect(openMenu(member.userId, displayName, level, rebirth))
			end
			local canKick = isMeLeader() and member.userId ~= player.UserId
			row.button.Visible = canKick
			row.button.Text = Text.get("ui.party.kick")
			row.button.AutoButtonColor = true
			row.button.BackgroundColor3 = UIColors.gold
			row.button.TextColor3 = Color3.new(0, 0, 0)
			if canKick then
				row.connection = row.button.Activated:Connect(function()
					partyRequest:FireServer("kick", member.userId)
				end)
			end
		end
		for i, seat in ipairs(pending) do
			local row = myRows[#members + i]
			row.name.Text = seat.name
			row.name.TextColor3 = UIColors.textSecondary
			row.meta.Text = Text.get("ui.party.movingIn")
			row.button.Visible = isMeLeader()
			row.button.Text = Text.get("ui.party.cancel")
			if isMeLeader() then
				row.connection = row.button.Activated:Connect(function()
					partyRequest:FireServer("kick", seat.userId)
				end)
			end
		end

		-- ── 서버 플레이어(나 제외) ──
		local others = {}
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player then
				table.insert(others, other)
			end
		end
		table.sort(others, function(a, b)
			return a.Name < b.Name
		end)
		serverTitle.Text = Text.get("ui.party.serverTitle", { players = ("%d"):format(#others), friends = ("%d"):format(#friendsElsewhere) })
		ensureRows(serverRows, serverList, #others)
		local inMyParty = {}
		for _, member in ipairs(members) do
			inMyParty[member.userId] = true
		end
		for _, seat in ipairs(pending) do
			inMyParty[seat.userId] = true
		end
		local canInvite = (partyState == nil) or (isMeLeader() and #members + #pending < PartyConfig.maxMembers)
		for i, other in ipairs(others) do
			local row = serverRows[i]
			local level, rebirth = other:GetAttribute("CharacterLevel"), other:GetAttribute("RebirthCount")
			row.name.Text = PlayerLabelFormat.richText(other.DisplayName, level, rebirth, nameSize)
			row.name.TextColor3 = UIColors.textPrimary
			row.meta.Text = Text.get("ui.party.memberMeta", { class = classNameOf(other:GetAttribute("ClassId")), stage = tostring(other:GetAttribute("InfiniteStage") or "-") })
			row.nameConnection = row.name.Activated:Connect(openMenu(other.UserId, other.DisplayName, level, rebirth))
			local alreadyIn = inMyParty[other.UserId]
			row.button.Visible = true
			row.button.Text = Text.get(alreadyIn and "ui.party.member" or "ui.party.invite")
			setInviteButton(row, canInvite and not alreadyIn, function()
				partyRequest:FireServer("invite", other.UserId)
			end)
		end

		-- ── 24-2: 다른 서버의 온라인 친구(서버 플레이어 아래, 같은 행 틀) ──
		friendsHeader.Visible = true
		friendsHeader.LayoutOrder = #others + 1
		friendsHeader.Text = Text.get(#friendsElsewhere > 0 and "ui.party.friendsHeader" or "ui.party.friendsNone")
		ensureRows(friendRows, serverList, #friendsElsewhere)
		for i, friend in ipairs(friendsElsewhere) do
			local row = friendRows[i]
			row.frame.LayoutOrder = #others + 1 + i
			row.name.Text = friend.displayName and friend.displayName ~= friend.name and ("%s (@%s)"):format(friend.displayName, friend.name) or friend.name
			row.name.TextColor3 = UIColors.textPrimary
			row.meta.Text = Text.get("ui.party.friendMeta")
			local alreadyIn = inMyParty[friend.userId]
			row.button.Visible = true
			row.button.Text = Text.get(alreadyIn and "ui.party.member" or "ui.party.invite")
			setInviteButton(row, canInvite and not alreadyIn, function()
				partyRequest:FireServer("invite_remote", friend.userId)
			end)
		end
	end

	-- 친구 목록은 창을 열 때 한 번 서버에 묻는다(RemoteFunction, 서버가 스로틀). 응답이 오면 다시 그린다.
	local fetchingFriends = false
	local function refreshFriends()
		if fetchingFriends then
			return
		end
		fetchingFriends = true
		task.spawn(function()
			local ok, list = pcall(function()
				return partyFriendsFetch:InvokeServer()
			end)
			fetchingFriends = false
			if ok and type(list) == "table" then
				friendsElsewhere = list
				update()
			end
		end)
	end

	refs = { panel = panel, update = update, refreshFriends = refreshFriends, myRows = myRows, serverRows = serverRows, myTitle = myTitle, scroll = scroll }
end

-- 칩 스택(TopChipsRow - 골드 · 레벨 · 스테이지 ...)의 왼쪽에 붙인다: 위 끝을 스택과 맞추고 오른쪽 끝 = 스택 왼쪽 끝 - 8. 칩은 자릿수에 따라 폭이 변하므로 스택 크기가 바뀔 때마다 다시 붙인다.
-- 스택이 아직 없거나 못 찾으면 ScreenMap 슬롯의 기본 자리(폭 77일 때)에 둔다.
local CHIP_STACK_GAP = 8
local function followChipStack(button, gui)
	task.spawn(function()
		local stack
		for _ = 1, 40 do
			stack = player.PlayerGui:FindFirstChild("TopChipsRow", true)
			if stack then
				break
			end
			task.wait(0.25)
		end
		if not stack then
			return
		end
		local function reposition()
			local topLeft = stack.AbsolutePosition -- 둘 다 상단 인셋이 있는 ScreenGui라 AbsolutePosition(ScreenGui 안 좌표)을 그대로 Position에 쓴다
			button.AnchorPoint = Vector2.new(1, 0)
			button.Position = UDim2.new(0, topLeft.X - CHIP_STACK_GAP, 0, topLeft.Y)
		end
		reposition()
		stack:GetPropertyChangedSignal("AbsoluteSize"):Connect(reposition)
		stack:GetPropertyChangedSignal("AbsolutePosition"):Connect(reposition)
		local _ = gui
	end)
end

-- HUD [파티] 버튼(항상 보임) - 칩 스택 왼쪽 TR.partyToggle 자리. 누르면 파티창을 토글한다.
local function buildToggleButton()
	local gui = Instance.new("ScreenGui")
	gui.Name = "PartyToggleGui"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local button = Instance.new("TextButton")
	button.Name = "PartyToggleButton"
	button.Visible = false -- QUEUE-ALL2 P2 중복 삭제: 왼쪽 메뉴 더보기 [파티] · P 키가 연다(자리 계산은 그대로 - 다른 버튼이 기준으로 읽던 자리)
	ScreenMap.place(button, "TR", "partyToggle")
	button.Size = UDim2.new(0, 72, 0, Theme.isMobile and Theme.touchMin or 36)
	button.Text = Text.get("ui.party.title")
	button.Font = Theme.font
	button.TextSize = Theme.textSize("body")
	button.TextColor3 = UIColors.textPrimary
	button.BackgroundColor3 = UIColors.panel
	button.BackgroundTransparency = UIColors.panelTransparency
	button.Parent = gui
	Theme.corner(button, 8)
	Theme.stroke(button)
	-- QUEUE-ALL1 01 A-4: 아트 켬 = 아이콘 타일(파티 · 단축키 칩 P) - 아트 속성이 늦게 와도 켜지는 순간 입힌다
	local IconTile = require(script.Parent.Parent.ui.IconTile)
	local function tile()
		if not button:FindFirstChild("IconTile") then
			IconTile.apply(button, "party", "P", { size = 40 })
		end
	end
	tile()
	workspace:GetAttributeChangedSignal("ArtStyleV1"):Connect(tile)
	button.Activated:Connect(function()
		UIManager.toggle(Party.id)
	end)
	followChipStack(button, gui)
	return button
end

function Party.init()
	build()
	buildToggleButton()
	partyStateChanged.OnClientEvent:Connect(function(state)
		partyState = PartyAway.stamp(state)
		refs.update()
	end)
	-- S19b: 연결 끊김 카운트다운 - 창이 열려 있고 끊긴 멤버가 있을 때만 1초마다 다시 그린다.
	task.spawn(function()
		while true do
			task.wait(1)
			if windowOpen and partyState then
				for _, member in ipairs(partyState.members) do
					if member.awayEndsAt then
						refs.update()
						break
					end
				end
			end
		end
	end)
	Players.PlayerAdded:Connect(refs.update)
	Players.PlayerRemoving:Connect(function()
		task.defer(refs.update)
	end)
end

-- QUEUE-ALL9C 1-4: 파티창을 그 탭으로 연다(party | board)
function Party.openTab(tabId)
	if not UIManager.isOpen(Party.id) then
		UIManager.open(Party.id)
	end
	if Party.tabs then
		Party.tabs.select(tabId or "party", false)
	end
end

-- 검사용: 지금 그려진 파티창 줄들(내 파티 · 서버 플레이어)의 이름 글(태그 없는 글)과 스크롤 캔버스.
function Party.debugState()
	local function texts(rows)
		local out = {}
		for _, row in ipairs(rows) do
			if row.frame.Visible then
				table.insert(out, (row.name.Text:gsub("<[^>]+>", "")))
			end
		end
		return out
	end
	return { myRows = texts(refs.myRows), serverRows = texts(refs.serverRows), myTitle = refs.myTitle.Text, canvas = refs.scroll.CanvasSize, open = windowOpen }
end

return Party
