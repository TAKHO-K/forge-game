-- 파티 HUD(24-1, PRD 20.47 [5](다) 4번 "파티원 HP 바"). 두 가지만 그린다:
--   [1] 파티원 목록(이름·직업·레벨·스테이지·HP 바) - 화면 왼쪽 세로 중앙. 로블록스 기본 채팅창이
--       좌상단을 차지하므로(끌 수 없다) 그 아래·세로 중앙에 두고, 모바일 대시 버튼(좌하단,
--       SkillSlots.client.lua)과도 겹치지 않는 높이다. 채팅창을 가리지 않는다는 지시.
--   [2] 초대 토스트(수락/거절 버튼) + 짧은 알림 토스트 - 상단 중앙 토스트 줄(SaveNotice 64 /
--       ZoneBoundary 100 / ZoneBlocked 108 / TreasureChest 150 / Tutorial 160)의 맨 아래 y=210.
-- 새 창을 만들지 않는다 - 초대·탈퇴·추방 조작은 파티창(panels/Party.lua - S12b에서 장비창 "파티" 탭이 독립 창이 됐다)에 있다.
-- 색·틀은 전부 UIColors + HudChip 계열(패널 + 링 + 알약 모서리)을 그대로 쓴다.
--
-- 실제 파티원의 HP·레벨·직업·스테이지는 서버가 Player Attribute(Hp/MaxHp/CharacterLevel/
-- ClassId/InfiniteStage - 전 클라에 복제된다)로 이미 내보내고 있어 그대로 읽는다. 더미 멤버
-- (DevTools)만 스냅샷(PartyStateChanged)에 실려 온 값을 쓴다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local PlayerLabelFormat = require(ReplicatedStorage.Shared.PlayerLabelFormat)
local ScreenMap = require(script.Parent.ui.ScreenMap)

local partyStateChanged = ReplicatedStorage:WaitForChild("PartyStateChanged")
local partyInviteNotice = ReplicatedStorage:WaitForChild("PartyInviteNotice")
local partyNotice = ReplicatedStorage:WaitForChild("PartyNotice")
local friendJoinedNotice = ReplicatedStorage:WaitForChild("FriendJoinedNotice")
local partyRequest = ReplicatedStorage:WaitForChild("PartyRequest")
local partyVoteNotice = ReplicatedStorage:WaitForChild("PartyVoteNotice")

local player = Players.LocalPlayer

local ROW_WIDTH, ROW_HEIGHT = 196, 44
local TOAST_Y = 210
local NOTICE_SECONDS = 3

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PartyHudGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- ═══ [1] 파티원 목록 ═══
local list = Instance.new("Frame")
list.Name = "PartyList"
ScreenMap.place(list, "ML", "partyList") -- S16: 메뉴바 오른쪽 옆(x = 14 + 48 + 8)
list.AutomaticSize = Enum.AutomaticSize.XY
list.Size = UDim2.new(0, 0, 0, 0)
list.BackgroundTransparency = 1
list.Visible = false
list.Parent = screenGui

local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection = Enum.FillDirection.Vertical
listLayout.Padding = UDim.new(0, 6)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list

-- 30-0 S09(PRD 20.73 [6]): 목록 맨 위의 "경험치 +20%" 칩 - 도움말을 안 열어도 파티의 이득이 보인다. 값은 서버가 PartyState에서 내려주는 Attribute PartyExpBonus
-- (0 / 0.10 / 0.15 / 0.20 - 같은 서버의 실제 Player 인원 기준)를 그대로 읽는다. 0이면(솔로 · 더미만 있는 파티) 숨긴다. 목록 자체가 파티가 없으면 숨어 있다.
local expChip = Instance.new("Frame")
expChip.Name = "PartyExpChip"
expChip.LayoutOrder = 0
expChip.Size = UDim2.new(0, 108, 0, 22)
expChip.BackgroundColor3 = UIColors.panel
expChip.BackgroundTransparency = UIColors.panelTransparency
expChip.Visible = false
expChip.Parent = list

local expChipCorner = Instance.new("UICorner")
expChipCorner.CornerRadius = UDim.new(1, 0)
expChipCorner.Parent = expChip

local expChipStroke = Instance.new("UIStroke")
expChipStroke.Color = UIColors.success
expChipStroke.Transparency = 0.4
expChipStroke.Thickness = 1
expChipStroke.Parent = expChip

local expChipText = Instance.new("TextLabel")
expChipText.BackgroundTransparency = 1
expChipText.Size = UDim2.new(1, 0, 1, 0)
expChipText.Font = Enum.Font.GothamBold
expChipText.TextSize = 12
expChipText.TextColor3 = UIColors.success
expChipText.Text = ""
expChipText.Parent = expChip

local function refreshExpChip()
	local bonus = player:GetAttribute("PartyExpBonus") or 0
	expChip.Visible = bonus > 0
	if bonus > 0 then
		expChipText.Text = ("경험치 +%d%%"):format(math.floor(bonus * 100 + 0.5))
	end
end
player:GetAttributeChangedSignal("PartyExpBonus"):Connect(refreshExpChip)
refreshExpChip()

local rows = {} -- index -> { frame, name, meta, fill, userId, isDummy, dummy }

local function makeRow(order)
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.Size = UDim2.new(0, ROW_WIDTH, 0, ROW_HEIGHT)
	frame.BackgroundColor3 = UIColors.panel
	frame.BackgroundTransparency = UIColors.panelTransparency
	frame.Parent = list

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = UIColors.rim
	stroke.Transparency = UIColors.rimTransparency
	stroke.Thickness = 1
	stroke.Parent = frame

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.new(0, 10, 0, 5)
	name.Size = UDim2.new(1, -20, 0, 15)
	name.Font = Enum.Font.GothamBold
	name.TextSize = 12.5
	name.RichText = true -- S12b D: "★n Lv.35 표시이름"
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextColor3 = UIColors.textPrimary
	name.Text = ""
	name.Parent = frame

	local meta = Instance.new("TextLabel")
	meta.BackgroundTransparency = 1
	meta.Position = UDim2.new(0, 10, 0, 20)
	meta.Size = UDim2.new(1, -20, 0, 12)
	meta.Font = Enum.Font.Gotham
	meta.TextSize = 10.5
	meta.TextXAlignment = Enum.TextXAlignment.Left
	meta.TextColor3 = UIColors.textSecondary
	meta.Text = ""
	meta.Parent = frame

	local track = Instance.new("Frame")
	track.Position = UDim2.new(0, 10, 1, -9)
	track.Size = UDim2.new(1, -20, 0, 5)
	track.BackgroundColor3 = UIColors.hpDark
	track.BorderSizePixel = 0
	track.Parent = frame
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = UIColors.hp
	fill.BorderSizePixel = 0
	fill.Parent = track
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	-- S13b: 쉴드 총량 - 체력 막대 위쪽 절반에 겹쳐 그리는 흰 띠(새 HUD 요소 없음). 폭 = 쉴드 ÷ 최대체력(최대 100%).
	local shieldFill = Instance.new("Frame")
	shieldFill.Name = "ShieldFill"
	shieldFill.Size = UDim2.new(0, 0, 0, 3)
	shieldFill.BackgroundColor3 = Color3.new(1, 1, 1)
	shieldFill.BorderSizePixel = 0
	shieldFill.Visible = false
	shieldFill.ZIndex = 2
	shieldFill.Parent = track

	return { frame = frame, name = name, meta = meta, fill = fill, shieldFill = shieldFill, stroke = stroke }
end

local currentState = nil

local function classNameOf(classId)
	local class = classId and ClassData.classes[classId]
	return class and class.displayName or "-"
end

local function refreshRows()
	for i, row in ipairs(rows) do
		local member = currentState and currentState.members[i]
		if not member then
			row.frame.Visible = false
		else
			row.frame.Visible = true
			local hp, maxHp, level, stage, classId, buffActive, rebirth, shield
			local displayName = member.name -- 서버 기록은 username - 살아 있는 Player면 DisplayName으로 바꾼다(S12b D)
			if member.isDummy then
				hp, maxHp = member.dummy.hp or 1, member.dummy.maxHp or 1
				level, stage, classId = member.dummy.level, member.dummy.stage, member.dummy.classId
			else
				local target = Players:GetPlayerByUserId(member.userId)
				if target then
					hp, maxHp = target:GetAttribute("Hp"), target:GetAttribute("MaxHp")
					shield = target:GetAttribute("Shield") -- S13b: 서버 PlayerShield가 올리는 쉴드 총량
					level, stage, classId = target:GetAttribute("CharacterLevel"), target:GetAttribute("InfiniteStage"), target:GetAttribute("ClassId")
					-- 24-3(PRD 20.64) 힐러 버프 - "파티원 목록에서 누가 버프를 받고 있는지
					-- 구분되게" 하라는 지시. BuffState.lua가 올려주는 Attribute를 그대로
					-- 읽는다(dealingMode를 PlayerHealthBar.client.lua가 읽는 것과 같은 패턴).
					buffActive = target:GetAttribute("HealerBuffActive")
					rebirth = target:GetAttribute("RebirthCount")
					displayName = target.DisplayName
				end
			end
			-- S12b D: 이름 줄 = "★n Lv.35 표시이름"(파티장은 이름이 금색 - 옛 "★ " 표시는 환생 ★n과 헷갈려 뺐다). 레벨은 이름 줄로 옮겨 갔다.
			row.name.Text = PlayerLabelFormat.richText(displayName .. (member.isDummy and " (더미)" or "") .. (buffActive and " ✚" or ""), level, rebirth, 12.5)
			row.name.TextColor3 = member.isLeader and UIColors.gold or UIColors.textPrimary
			row.meta.Text = ("%s · 스테이지 %s"):format(classNameOf(classId), tostring(stage or "-"))
			local ratio = (hp and maxHp and maxHp > 0) and math.clamp(hp / maxHp, 0, 1) or 0
			row.fill.Size = UDim2.new(ratio, 0, 1, 0)
			local shieldRatio = (shield and maxHp and maxHp > 0) and math.clamp(shield / maxHp, 0, 1) or 0
			row.shieldFill.Visible = shieldRatio > 0
			row.shieldFill.Size = UDim2.new(shieldRatio, 0, 0, 3)
			-- 24-3: 링 색으로 버프 여부를 구분한다(새 파티클·새 색 없이 기존 rim/success 재사용).
			row.stroke.Color = buffActive and UIColors.success or UIColors.rim
			row.stroke.Transparency = buffActive and 0.2 or UIColors.rimTransparency
		end
	end
end

local function applyState(state)
	currentState = state
	local count = state and #state.members or 0
	for i = #rows + 1, count do
		rows[i] = makeRow(i)
	end
	list.Visible = count > 0
	refreshRows()
end

partyStateChanged.OnClientEvent:Connect(applyState)

-- HP는 Attribute 변화 신호를 멤버마다 따로 걸기보다 0.2초마다 한 번 다시 읽는다 - 최대 4명이라
-- 비용이 없고, 멤버가 바뀔 때 연결을 붙였다 뗐다 할 필요가 없다.
local accumulated = 0
RunService.Heartbeat:Connect(function(dt)
	if not currentState then
		return
	end
	accumulated += dt
	if accumulated >= 0.2 then
		accumulated = 0
		refreshRows()
	end
end)

-- ═══ [2] 토스트(초대 수락/거절 + 알림) ═══
local toast = Instance.new("Frame")
toast.Name = "PartyToast"
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, TOAST_Y)
toast.Size = UDim2.new(0, 420, 0, 40)
toast.BackgroundColor3 = UIColors.panel
toast.BackgroundTransparency = UIColors.panelTransparency
toast.Visible = false
toast.Parent = screenGui

local toastCorner = Instance.new("UICorner")
toastCorner.CornerRadius = UDim.new(0, 10)
toastCorner.Parent = toast

local toastStroke = Instance.new("UIStroke")
toastStroke.Color = UIColors.rim
toastStroke.Transparency = UIColors.rimTransparency
toastStroke.Parent = toast

local toastText = Instance.new("TextLabel")
toastText.BackgroundTransparency = 1
toastText.Position = UDim2.new(0, 12, 0, 0)
toastText.Size = UDim2.new(1, -24, 1, 0)
toastText.Font = Enum.Font.GothamBold
toastText.TextSize = 13
toastText.TextWrapped = true
toastText.TextXAlignment = Enum.TextXAlignment.Left
toastText.TextColor3 = UIColors.textPrimary
toastText.Text = ""
toastText.Parent = toast

local function makeToastButton(text, order, accent)
	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -10 - (order - 1) * 66, 0.5, 0)
	button.Size = UDim2.new(0, 60, 0, 26)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 12
	button.Text = text
	button.TextColor3 = accent and Color3.new(0, 0, 0) or UIColors.textSecondary
	button.BackgroundColor3 = accent and UIColors.gold or UIColors.panel
	button.BackgroundTransparency = accent and 0.1 or UIColors.panelTransparency
	button.Visible = false
	button.Parent = toast
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = UIColors.rim
	stroke.Transparency = UIColors.rimTransparency
	stroke.Parent = button
	return button
end

local declineButton = makeToastButton("거절", 1, false)
local acceptButton = makeToastButton("수락", 2, true)
-- S12: 친구가 같은 서버에 들어왔다는 토스트의 [파티 초대] - 기존 초대 요청("invite")을 그대로 쏜다.
local friendButton = makeToastButton("파티 초대", 1, true)
friendButton.Size = UDim2.new(0, 76, 0, 26)

local toastToken = 0
local inviteOpen = false
local friendUserId = nil

local function hideToast()
	toast.Visible = false
	acceptButton.Visible = false
	declineButton.Visible = false
	friendButton.Visible = false
	friendUserId = nil
	inviteOpen = false
end

-- withButtons = 초대 수락/거절 버튼 · friendId = 친구 토스트의 [파티 초대] 대상 userId(둘은 같이 안 쓴다).
local function showToast(text, withButtons, seconds, friendId)
	toastToken += 1
	local token = toastToken
	toastText.Text = text
	toastText.Size = UDim2.new(1, withButtons and -150 or (friendId and -100 or -24), 1, 0)
	toast.Visible = true
	acceptButton.Visible = withButtons
	declineButton.Visible = withButtons
	friendUserId = friendId
	friendButton.Visible = friendId ~= nil
	inviteOpen = withButtons
	task.delay(seconds, function()
		if toastToken == token then
			hideToast()
		end
	end)
end

partyInviteNotice.OnClientEvent:Connect(function(data)
	-- 24-2: 다른 서버에서 온 초대(remote)는 수락하면 그 서버로 이동한다는 점을 문구로 알린다 - 버튼은 같다.
	local text = data.remote and ("%s님이 파티에 초대했습니다 (다른 서버 - 수락 시 이동)"):format(data.inviterName)
		or ("%s님이 파티에 초대했습니다"):format(data.inviterName)
	showToast(text, true, data.seconds or 15)
end)

partyNotice.OnClientEvent:Connect(function(text)
	if inviteOpen then
		return -- 초대 팝업이 떠 있는 동안은 덮어쓰지 않는다(수락/거절 버튼이 사라지면 안 된다).
	end
	showToast(text, false, NOTICE_SECONDS)
end)

friendJoinedNotice.OnClientEvent:Connect(function(data)
	if inviteOpen then
		return
	end
	showToast(("친구 %s님이 들어왔습니다"):format(data.name), false, data.seconds or NOTICE_SECONDS, data.userId)
end)

friendButton.Activated:Connect(function()
	if friendUserId then
		partyRequest:FireServer("invite", friendUserId)
	end
	hideToast()
end)

acceptButton.Activated:Connect(function()
	partyRequest:FireServer("accept")
	hideToast()
end)

declineButton.Activated:Connect(function()
	partyRequest:FireServer("decline")
	hideToast()
end)

-- ═══ [3] 스테이지 이동 투표 패널(25-3, PRD 20.47 [6](라) "입장 수락 팝업"을 투표로 대체) ═══
-- 화면 오른쪽 세로 중앙 - 파티 목록(왼쪽)의 반대편이라 화면 중앙·채팅창(좌상단)과 안 겹친다.
local votePanel = Instance.new("Frame")
votePanel.Name = "PartyVotePanel"
votePanel.AnchorPoint = Vector2.new(1, 0.5)
votePanel.Position = UDim2.new(1, -14, 0.5, 0)
votePanel.Size = UDim2.new(0, 210, 0, 84)
votePanel.BackgroundColor3 = UIColors.panel
votePanel.BackgroundTransparency = UIColors.panelTransparency
votePanel.Visible = false
votePanel.Parent = screenGui

local voteCorner = Instance.new("UICorner")
voteCorner.CornerRadius = UDim.new(0, 10)
voteCorner.Parent = votePanel

local voteStroke = Instance.new("UIStroke")
voteStroke.Color = UIColors.rim
voteStroke.Transparency = UIColors.rimTransparency
voteStroke.Parent = votePanel

local voteText = Instance.new("TextLabel")
voteText.BackgroundTransparency = 1
voteText.Position = UDim2.new(0, 12, 0, 8)
voteText.Size = UDim2.new(1, -24, 0, 40)
voteText.Font = Enum.Font.GothamBold
voteText.TextSize = 12.5
voteText.TextWrapped = true
voteText.TextXAlignment = Enum.TextXAlignment.Left
voteText.TextYAlignment = Enum.TextYAlignment.Top
voteText.TextColor3 = UIColors.textPrimary
voteText.Text = ""
voteText.Parent = votePanel

local function makeVoteButton(text, leftSide, accent)
	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(leftSide and 0 or 1, 1)
	button.Position = UDim2.new(leftSide and 0 or 1, leftSide and 12 or -12, 1, -8)
	button.Size = UDim2.new(0, 84, 0, 26)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 12
	button.Text = text
	button.TextColor3 = accent and Color3.new(0, 0, 0) or UIColors.textSecondary
	button.BackgroundColor3 = accent and UIColors.gold or UIColors.panel
	button.BackgroundTransparency = accent and 0.1 or UIColors.panelTransparency
	button.Visible = false
	button.Parent = votePanel
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = UIColors.rim
	stroke.Transparency = UIColors.rimTransparency
	stroke.Parent = button
	return button
end

local voteRejectButton = makeVoteButton("거절", true, false)
local voteAgreeButton = makeVoteButton("동의", false, true)

local voteToken = 0

local function hideVote()
	votePanel.Visible = false
	voteAgreeButton.Visible = false
	voteRejectButton.Visible = false
end

partyVoteNotice.OnClientEvent:Connect(function(data)
	voteToken += 1
	local token = voteToken
	local autoHideSeconds = 2
	if data.result == "start" then
		votePanel.Visible = true
		if data.isLeader then
			voteText.Text = ("스테이지 %d 보스 진입 투표 중... 파티원 1명 동의 시 성립"):format(data.stage)
		else
			voteText.Text = ("%s님이 스테이지 %d 보스로 이동하려 합니다"):format(data.leaderName, data.stage)
			voteAgreeButton.Visible = true
			voteRejectButton.Visible = true
		end
		autoHideSeconds = data.seconds or 10
	elseif data.result == "passed" then
		voteText.Text = "투표 통과 - 이동합니다"
		voteAgreeButton.Visible = false
		voteRejectButton.Visible = false
		autoHideSeconds = 1.5
	elseif data.result == "failed" then
		voteText.Text = "투표가 성립하지 않았습니다"
		voteAgreeButton.Visible = false
		voteRejectButton.Visible = false
	end
	task.delay(autoHideSeconds, function()
		if voteToken == token then
			hideVote()
		end
	end)
end)

voteAgreeButton.Activated:Connect(function()
	partyRequest:FireServer("vote_agree")
	voteAgreeButton.Visible = false
	voteRejectButton.Visible = false
end)

voteRejectButton.Activated:Connect(function()
	partyRequest:FireServer("vote_reject")
	voteAgreeButton.Visible = false
	voteRejectButton.Visible = false
end)
