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
local UIManager = require(script.Parent.Parent.UIManager)
local FriendInvite = require(script.Parent.Parent.FriendInvite)
local HelpTooltip = require(script.Parent.Parent.HelpTooltip)
local PlayerMenu = require(script.Parent.PlayerMenu)
local ScreenMap = require(script.Parent.Parent.ui.ScreenMap)
local PartyAway = require(script.Parent.Parent.hud.PartyAway)
local Panel = require(script.Parent.Parent.ui.kit.Panel)
local Theme = require(script.Parent.Parent.ui.kit.Theme)

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
	local class = classId and ClassData.classes[classId]
	return class and class.displayName or "-"
end

local function isMeLeader()
	return partyState ~= nil and partyState.leaderUserId == player.UserId
end

local function build()
	local ROW_HEIGHT = Theme.isMobile and 52 or 38
	local BUTTON_HEIGHT = Theme.isMobile and 44 or 24
	local PILL_HEIGHT = Theme.isMobile and 44 or 28
	local nameSize, metaSize = Theme.textSize("body"), Theme.textSize("caption")
	local nameHeight, metaHeight = nameSize + 2, metaSize + 2
	local MY_EXTRA_Y = 40 + PartyConfig.maxMembers * (ROW_HEIGHT + ROW_GAP) + 8
	local codeHeight, hintHeight = Theme.textSize("body") + 4, Theme.textSize("caption") + 4
	local joinY = MY_EXTRA_Y + codeHeight + hintHeight + 6
	local createY = joinY + PILL_HEIGHT + 8
	local friendY = createY + PILL_HEIGHT + 8
	local BODY_HEIGHT = friendY + PILL_HEIGHT + 8 + PILL_HEIGHT + 8

	local panel = Panel.create({
		id = Party.id,
		kind = "window",
		title = "파티",
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

	-- 고정 캔버스 + 창 안 스크롤: 화면이 작아 창이 캔버스보다 작아지면 위아래(좁으면 좌우)로 민다.
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Body"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.new(1, 0, 1, 0)
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

	local myColumn, myTitle, myList = makeColumn(14, "내 파티")
	local serverColumn, serverTitle, serverList = makeColumn(14 + COLUMN_WIDTH + 30, "서버 플레이어")
	local _ = serverColumn

	-- 25-3 · S09의 파티 도움말("?"). 숫자(기여 10% · 경험치 보너스 · 투표 10초)는 데이터에서 읽어 끼운다. 패널은 280 × 176 고정.
	do
		local gatePercent = math.floor(CombatConfig.contributionRewardThreshold * 100 + 0.5)
		local bonusParts = {}
		for memberCount = 2, PartyConfig.maxMembers do
			table.insert(bonusParts, ("%d인 +%d%%"):format(memberCount, math.floor(PartyConfig.expBonusByMemberCount[memberCount] * 100 + 0.5)))
		end
		HelpTooltip.attach(myColumn, UDim2.new(0, 62, 0, 19), table.concat({
			("■ 기여 %d%%"):format(gatePercent),
			("몬스터에게 준 피해가 %d%%에 못 미치면 파티여도 골드·경험치·아이템·강화석을 받지 못합니다. 보스는 파티원 전원이 %d%%를 넘겨야 스테이지 클리어로 기록됩니다."):format(gatePercent, gatePercent),
			"■ 파티 경험치",
			table.concat(bonusParts, " · ") .. ". 장비의 경험치 옵션과 곱해집니다.",
			"■ 드랍 알림",
			"유물 등급 이상이 나오면 파티 전원에게 표시됩니다. 태초는 서버 전체에 알려집니다.",
			"■ 보스 스테이지 이동",
			("파티장이 신청하고 파티원 1명이 동의하면 전원이 이동합니다. %d초 안에 동의가 없으면 취소됩니다."):format(PartyConfig.stageVoteTimeoutSeconds),
		}, "\n"), nil, { panelSize = Vector2.new(280, 176) })
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

	local codeHint = Theme.label(myColumn, "다른 서버의 친구에게 이 코드를 알려 주면 코드로 합류할 수 있습니다", "caption", "textTertiary")
	codeHint.Position = UDim2.new(0, 0, 0, MY_EXTRA_Y + codeHeight)
	codeHint.Size = UDim2.new(1, 0, 0, hintHeight)
	codeHint.Visible = false

	-- 코드 입력 상자 - 장비 패널 슬롯 틀(slot 색 + rim 링)을 그대로 쓴다.
	local joinBox = Instance.new("TextBox")
	joinBox.Position = UDim2.new(0, 0, 0, joinY)
	joinBox.Size = UDim2.new(0, 160, 0, PILL_HEIGHT)
	joinBox.Font = Theme.font
	joinBox.TextSize = Theme.textSize("body")
	joinBox.PlaceholderText = "파티 코드 입력"
	joinBox.PlaceholderColor3 = UIColors.textTertiary
	joinBox.Text = ""
	joinBox.TextColor3 = UIColors.textPrimary
	joinBox.ClearTextOnFocus = false
	joinBox.BackgroundColor3 = UIColors.slot
	joinBox.BackgroundTransparency = UIColors.slotTransparency
	joinBox.Parent = myColumn
	Theme.corner(joinBox, 8)
	Theme.stroke(joinBox)

	local joinButton = makePillButton(myColumn, "코드로 합류", 168, joinY, 96, true)
	joinButton.Activated:Connect(function()
		local code = joinBox.Text:gsub("%s", ""):upper()
		if #code > 0 then
			partyRequest:FireServer("joincode", code)
			joinBox.Text = ""
		end
	end)

	local createButton = makePillButton(myColumn, "파티 만들기 (코드 받기)", 0, createY, 160, false)
	createButton.Activated:Connect(function()
		partyRequest:FireServer("create")
	end)

	local cancelJoinButton = makePillButton(myColumn, "합류 대기 취소", 168, createY, 110, false)
	cancelJoinButton.Activated:Connect(function()
		partyRequest:FireServer("cancel_join")
	end)

	-- S12: [친구 부르기] - 로블록스 기본 초대 창. 견습 1단계에서는 TutorialHud의 같은 버튼이 강조되고, 여기는 상시다(장비창 파티 탭에서 이 창으로 옮겨 왔다 - 역할이 겹치지 않는다). 초대를 못 보내는 환경이면 숨긴다.
	local inviteFriendButton = makePillButton(myColumn, "친구 부르기", 0, friendY, 160, true)
	inviteFriendButton.Name = "InviteFriendButton"
	inviteFriendButton.Visible = false
	FriendInvite.onAvailability(function(canShow)
		inviteFriendButton.Visible = canShow
	end)
	inviteFriendButton.Activated:Connect(function()
		FriendInvite.prompt()
	end)

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
	leaveButton.Text = "파티 탈퇴"
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

	local emptyLabel = Theme.label(myColumn, "파티가 없습니다. 오른쪽 목록에서 초대하면 리더가 됩니다.\n다른 서버 친구는 코드를 받아 아래에 입력하거나, 친구 목록의 초대 버튼으로 부릅니다.", "caption", "textTertiary")
	emptyLabel.Position = UDim2.new(0, 0, 0, 44)
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
		myTitle.Text = ("내 파티 (%d/%d)%s"):format(#members + #pending, PartyConfig.maxMembers, (partyState and partyState.bossActive) and " · 보스전 중" or "")
		emptyLabel.Visible = #members == 0
		leaveButton.Visible = #members > 0
		codeLabel.Visible = #members > 0
		codeHint.Visible = #members > 0
		codeLabel.Text = partyState and partyState.code and ("파티 코드  " .. partyState.code) or "파티 코드 발급 중…"
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
			row.name.Text = PlayerLabelFormat.richText(displayName .. (member.isDummy and " (더미)" or ""), level, rebirth, nameSize)
			row.name.TextColor3 = awayText and UIColors.textSecondary or (member.isLeader and UIColors.gold or UIColors.textPrimary)
			local meta = ("%s · 스테이지 %s"):format(classNameOf(classId), tostring(stage or "-"))
			row.meta.Text = awayText and ("%s · %s"):format(awayText, meta) or meta
			if target then
				row.nameConnection = row.name.Activated:Connect(openMenu(member.userId, displayName, level, rebirth))
			end
			local canKick = isMeLeader() and member.userId ~= player.UserId
			row.button.Visible = canKick
			row.button.Text = "추방"
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
			row.meta.Text = "다른 서버에서 이동 중…"
			row.button.Visible = isMeLeader()
			row.button.Text = "취소"
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
		serverTitle.Text = ("서버 플레이어 (%d) · 다른 서버 친구 (%d)"):format(#others, #friendsElsewhere)
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
			row.meta.Text = ("%s · 스테이지 %s"):format(classNameOf(other:GetAttribute("ClassId")), tostring(other:GetAttribute("InfiniteStage") or "-"))
			row.nameConnection = row.name.Activated:Connect(openMenu(other.UserId, other.DisplayName, level, rebirth))
			local alreadyIn = inMyParty[other.UserId]
			row.button.Visible = true
			row.button.Text = alreadyIn and "파티원" or "초대"
			setInviteButton(row, canInvite and not alreadyIn, function()
				partyRequest:FireServer("invite", other.UserId)
			end)
		end

		-- ── 24-2: 다른 서버의 온라인 친구(서버 플레이어 아래, 같은 행 틀) ──
		friendsHeader.Visible = true
		friendsHeader.LayoutOrder = #others + 1
		friendsHeader.Text = #friendsElsewhere > 0 and "다른 서버에 있는 친구 (초대 → 상대가 수락하면 이 서버로 이동)" or "다른 서버에 있는 온라인 친구 없음"
		ensureRows(friendRows, serverList, #friendsElsewhere)
		for i, friend in ipairs(friendsElsewhere) do
			local row = friendRows[i]
			row.frame.LayoutOrder = #others + 1 + i
			row.name.Text = friend.displayName and friend.displayName ~= friend.name and ("%s (@%s)"):format(friend.displayName, friend.name) or friend.name
			row.name.TextColor3 = UIColors.textPrimary
			row.meta.Text = "다른 서버 · 온라인"
			local alreadyIn = inMyParty[friend.userId]
			row.button.Visible = true
			row.button.Text = alreadyIn and "파티원" or "초대"
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
	ScreenMap.place(button, "TR", "partyToggle")
	button.Size = UDim2.new(0, 72, 0, Theme.isMobile and Theme.touchMin or 36)
	button.Text = "파티"
	button.Font = Theme.font
	button.TextSize = Theme.textSize("body")
	button.TextColor3 = UIColors.textPrimary
	button.BackgroundColor3 = UIColors.panel
	button.BackgroundTransparency = UIColors.panelTransparency
	button.Parent = gui
	Theme.corner(button, 8)
	Theme.stroke(button)
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
