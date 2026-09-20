-- 견습 모드(튜토리얼, 23-1) 안내 토스트 + 진행 칩 + 보스 도전 버튼. PRD-forge-game-roblox.md
-- 20.47[1] "안내 UI" 지시 그대로: 단계 시작 시 1회·3초 노출 후 자동 소멸, 화면 중앙을 덮지
-- 않고 조작을 막지 않는다 - ZoneBoundaryWarning.client.lua와 같은 토스트 틀(트윈 페이드,
-- SaveNoticeHud.client.lua 계열 패턴)을 그대로 재사용한다. 진행 칩은 StageUI.client.lua가
-- 만든 TopChipsRow에 끼워 넣는다(GoldHud/LevelHud와 같은 WaitForChild 패턴) - 그 파일 자체는
-- 건드리지 않는다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local FriendInvite = require(script.Parent.FriendInvite)
local HudChip = require(script.Parent.HudChip)
local Theme = require(script.Parent.ui.kit.Theme)

local tutorialStepNotice = ReplicatedStorage:WaitForChild("TutorialStepNotice")
local tutorialChallengeBossRequest = ReplicatedStorage:WaitForChild("TutorialChallengeBossRequest")

local player = Players.LocalPlayer

-- ═══ 토스트(안내 텍스트, 3초) ═══
local toastGui = Instance.new("ScreenGui")
toastGui.Name = "TutorialToastGui"
toastGui.ResetOnSpawn = false
toastGui.Parent = player:WaitForChild("PlayerGui")

local DISPLAY_SECONDS = 3

local toast = Instance.new("Frame")
toast.Name = "TutorialToast"
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, 160) -- ZoneBoundaryWarning(y=100)보다 아래 - 화면 중앙(캐릭터)을 안 덮고 서로 안 겹친다.
toast.AutomaticSize = Enum.AutomaticSize.Y
toast.Size = UDim2.new(0, 480, 0, 0)
toast.BackgroundColor3 = UIColors.panel
toast.BackgroundTransparency = 1
toast.BorderSizePixel = 0
toast.Parent = toastGui

local toastCorner = Instance.new("UICorner")
toastCorner.CornerRadius = UDim.new(0, 10)
toastCorner.Parent = toast

local toastStroke = Instance.new("UIStroke")
toastStroke.Color = UIColors.rim
toastStroke.Transparency = 1
toastStroke.Parent = toast

local toastPadding = Instance.new("UIPadding")
toastPadding.PaddingTop = UDim.new(0, 10)
toastPadding.PaddingBottom = UDim.new(0, 10)
toastPadding.PaddingLeft = UDim.new(0, 16)
toastPadding.PaddingRight = UDim.new(0, 16)
toastPadding.Parent = toast

local toastTitle = Instance.new("TextLabel")
toastTitle.Name = "Title"
toastTitle.BackgroundTransparency = 1
toastTitle.AutomaticSize = Enum.AutomaticSize.Y
toastTitle.Size = UDim2.new(1, 0, 0, 0)
toastTitle.Font = Enum.Font.GothamBold
toastTitle.TextSize = 14
toastTitle.TextColor3 = UIColors.xp
toastTitle.TextXAlignment = Enum.TextXAlignment.Left
toastTitle.TextTransparency = 1
toastTitle.Text = ""
toastTitle.Parent = toast

local toastBody = Instance.new("TextLabel")
toastBody.Name = "Body"
toastBody.LayoutOrder = 2
toastBody.BackgroundTransparency = 1
toastBody.AutomaticSize = Enum.AutomaticSize.Y
toastBody.Size = UDim2.new(1, 0, 0, 0)
toastBody.Font = Enum.Font.Gotham
toastBody.TextSize = 13
toastBody.TextColor3 = UIColors.textPrimary
toastBody.TextWrapped = true
toastBody.TextXAlignment = Enum.TextXAlignment.Left
toastBody.TextTransparency = 1
toastBody.Text = ""
toastBody.Parent = toast

local toastLayout = Instance.new("UIListLayout")
toastLayout.FillDirection = Enum.FillDirection.Vertical
toastLayout.Padding = UDim.new(0, 4)
toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
toastLayout.Parent = toast

local hideThread = nil

local function showToast(title, body)
	if hideThread then
		task.cancel(hideThread)
		hideThread = nil
	end
	toastTitle.Text = title
	toastBody.Text = body
	local tweenIn = TweenInfo.new(0.2)
	TweenService:Create(toast, tweenIn, { BackgroundTransparency = 0.15 }):Play()
	TweenService:Create(toastStroke, tweenIn, { Transparency = UIColors.rimTransparency }):Play()
	TweenService:Create(toastTitle, tweenIn, { TextTransparency = 0 }):Play()
	TweenService:Create(toastBody, tweenIn, { TextTransparency = 0 }):Play()

	hideThread = task.delay(DISPLAY_SECONDS, function()
		hideThread = nil
		local tweenOut = TweenInfo.new(0.5)
		TweenService:Create(toast, tweenOut, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(toastStroke, tweenOut, { Transparency = 1 }):Play()
		TweenService:Create(toastTitle, tweenOut, { TextTransparency = 1 }):Play()
		TweenService:Create(toastBody, tweenOut, { TextTransparency = 1 }):Play()
	end)
end

tutorialStepNotice.OnClientEvent:Connect(function(payload)
	if payload.completed then
		showToast("견습 졸업", payload.text)
		return
	end
	local title = ("견습 %d/%d단계 - %s 구역"):format(payload.step, payload.stepCount, payload.zoneName)
	-- 1단계만 안내 뒤에 친구 부르기 한 줄이 붙는다(S12 - 문구는 TutorialData.steps[1].friendHintText).
	showToast(title, payload.friendHint and (payload.text .. "\n" .. payload.friendHint) or payload.text)
end)

-- ═══ 진행 칩 + 보스 도전 버튼(TopChipsRow에 끼워 넣는다) ═══
local topRow = player:WaitForChild("PlayerGui"):WaitForChild("TopChipsGui"):WaitForChild("TopChipsRow")

local wrapper = Instance.new("Frame")
wrapper.Name = "TutorialWrapper"
wrapper.LayoutOrder = 5 -- 골드1·레벨2·스테이지3·설정4 다음, 맨 아래.
wrapper.AutomaticSize = Enum.AutomaticSize.XY
wrapper.Size = UDim2.new(0, 0, 0, 0)
wrapper.BackgroundTransparency = 1
wrapper.Visible = false
wrapper.Parent = topRow

local wrapperLayout = Instance.new("UIListLayout")
wrapperLayout.FillDirection = Enum.FillDirection.Vertical
wrapperLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
wrapperLayout.Padding = UDim.new(0, 4)
wrapperLayout.SortOrder = Enum.SortOrder.LayoutOrder
wrapperLayout.Parent = wrapper

local chip = HudChip.new(wrapper, 1)

local chipLabel = Instance.new("TextLabel")
chipLabel.Name = "TutorialLabel"
chipLabel.BackgroundTransparency = 1
chipLabel.AutomaticSize = Enum.AutomaticSize.X
chipLabel.Size = UDim2.new(0, 0, 1, 0)
chipLabel.Font = Enum.Font.GothamBold
chipLabel.TextSize = 13
chipLabel.TextColor3 = UIColors.textPrimary
chipLabel.Text = "견습"
chipLabel.Parent = chip

local challengeButton = Instance.new("TextButton")
challengeButton.Name = "ChallengeButton"
challengeButton.LayoutOrder = 2
challengeButton.AutomaticSize = Enum.AutomaticSize.X
challengeButton.Size = UDim2.new(0, 0, 0, 24)
challengeButton.Font = Enum.Font.GothamBold
challengeButton.TextSize = 12
challengeButton.Text = "보스 도전"
challengeButton.BackgroundColor3 = UIColors.ember
challengeButton.TextColor3 = UIColors.textPrimary
challengeButton.AutoButtonColor = true
challengeButton.Visible = false
challengeButton.Parent = wrapper

local challengeCorner = Instance.new("UICorner")
challengeCorner.CornerRadius = UDim.new(1, 0)
challengeCorner.Parent = challengeButton

local challengePadding = Instance.new("UIPadding")
challengePadding.PaddingLeft = UDim.new(0, 12)
challengePadding.PaddingRight = UDim.new(0, 12)
challengePadding.Parent = challengeButton

challengeButton.Activated:Connect(function()
	tutorialChallengeBossRequest:FireServer()
end)

-- [친구 부르기](S12) - 견습 1단계에서만 보인다(ember 테두리로 강조). 2단계부터는 숨기고 파티창(S12b - 옛 장비창 파티 탭)의 같은 버튼이 남는다. 초대를 못 보내는 환경이면 아예 안 보인다.
local inviteButton = Instance.new("TextButton")
inviteButton.Name = "InviteFriendButton"
inviteButton.LayoutOrder = 3
inviteButton.AutomaticSize = Enum.AutomaticSize.X
inviteButton.Size = UDim2.new(0, 0, 0, Theme.isMobile and 44 or 26)
inviteButton.Font = Enum.Font.GothamBold
inviteButton.TextSize = 12
inviteButton.Text = "친구 부르기"
inviteButton.BackgroundColor3 = UIColors.panel
inviteButton.BackgroundTransparency = UIColors.panelTransparency
inviteButton.TextColor3 = UIColors.textPrimary
inviteButton.AutoButtonColor = true
inviteButton.Visible = false
inviteButton.Parent = wrapper

local inviteCorner = Instance.new("UICorner")
inviteCorner.CornerRadius = UDim.new(1, 0)
inviteCorner.Parent = inviteButton

local invitePadding = Instance.new("UIPadding")
invitePadding.PaddingLeft = UDim.new(0, 12)
invitePadding.PaddingRight = UDim.new(0, 12)
invitePadding.Parent = inviteButton

local inviteStroke = Instance.new("UIStroke")
inviteStroke.Color = UIColors.ember
inviteStroke.Thickness = 2
inviteStroke.Parent = inviteButton

inviteButton.Activated:Connect(function()
	FriendInvite.prompt()
end)

local function updateHud()
	local completed = player:GetAttribute("TutorialCompleted")
	local step = player:GetAttribute("TutorialStep") or 0
	if completed or step <= 0 then
		wrapper.Visible = false
		return
	end
	wrapper.Visible = true

	local target = player:GetAttribute("TutorialKillTarget") or 0
	local count = player:GetAttribute("TutorialKillCount") or 0
	local canChallenge = player:GetAttribute("TutorialCanChallenge")
	chipLabel.Text = ("견습 %d/7 · %d/%d마리"):format(step, math.min(count, target), target)
	challengeButton.Visible = canChallenge == true
	inviteButton.Visible = step == 1 and FriendInvite.isAvailable()
end
FriendInvite.onAvailability(function()
	task.defer(function()
		updateHud()
	end)
end)

for _, attr in ipairs({ "TutorialCompleted", "TutorialStep", "TutorialKillTarget", "TutorialKillCount", "TutorialCanChallenge" }) do
	player:GetAttributeChangedSignal(attr):Connect(updateHud)
end
updateHud()
