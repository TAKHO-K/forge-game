-- 스킬 슬롯(16-1 [2] 신설 → 16-2에서 목업 재정렬). `Claude outputs/hud-mockup.html`의
-- `.skills` 행을 그대로 옮긴다 - Q · 공격(자리만, 실제 버튼은 AttackInput.client.lua가
-- 만든다) · E · 대시 순서로 한 줄에 놓고, 공격 버튼이 다른 슬롯보다 커서 아래로 살짝 더
-- 튀어나온다. 이 스크립트가 그 한 줄(CentralRow)의 UIListLayout을 소유한다 -
-- AttackInput.client.lua는 이 Row를 WaitForChild로 찾아 자기 버튼을
-- LayoutOrder=ATTACK_LAYOUT_ORDER로 끼워 넣는다(두 스크립트가 같은 이름의 컨테이너를
-- 계약처럼 공유한다 - 아래 상수가 그 계약이다).
--
-- 대시는 조사 결과(16-1 [0]) 이 프로젝트에 실제로 존재하지 않는 기능이고, Q·E도 마찬가지로
-- 스킬 자체가 아직 없다 - 그래서 세 슬롯 다 아이콘을 옅게(dim) 그려 "곧 채워질 자리"임을
-- 똑같이 보여준다(목업의 cooling/ready 데모는 디자인 설명용일 뿐이다). 쿨다운 표현(스톱워치
-- 눈금 링 + 중앙 숫자, HudIcons.buildCooldownRing 참고)은 자리와 갱신 함수만 만들어 두고
-- 지금은 아무도 호출하지 않는다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local HudIcons = require(script.Parent.HudIcons)

local SLOT_SIZE = 54
local SLOT_GAP = 11
local ROW_HEIGHT = 92 -- 공격 버튼(AttackInput.client.lua) 지름과 같다 - 행 안에서 가장 큰 항목.
local ICON_SIZE = 26

-- AttackInput.client.lua와 공유하는 계약값. 이름·순서를 바꾸면 두 파일을 같이 고쳐야 한다.
local CENTRAL_ROW_GUI_NAME = "SkillSlotsGui"
local CENTRAL_ROW_NAME = "CentralRow"
local ATTACK_LAYOUT_ORDER = 2

-- 경험치바(ExpBar.client.lua, 높이15) 위에 16px 여백을 두고 행을 앉힌다.
local ROW_BOTTOM_OFFSET = 15 + 16

local SLOTS = {
	{ id = "q", key = "Q", icon = "spin", layoutOrder = 1 },
	{ id = "e", key = "E", icon = "burst", layoutOrder = 3 },
	{ id = "dash", key = "DASH", icon = "dash", layoutOrder = 4 },
}

local player = Players.LocalPlayer

local screenGui = Instance.new("ScreenGui")
screenGui.Name = CENTRAL_ROW_GUI_NAME
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local row = Instance.new("Frame")
row.Name = CENTRAL_ROW_NAME
row.AnchorPoint = Vector2.new(0.5, 1)
row.Position = UDim2.new(0.5, 0, 1, -ROW_BOTTOM_OFFSET)
row.AutomaticSize = Enum.AutomaticSize.X
row.Size = UDim2.new(0, 0, 0, ROW_HEIGHT)
row.BackgroundTransparency = 1
row.Parent = screenGui

local rowLayout = Instance.new("UIListLayout")
rowLayout.FillDirection = Enum.FillDirection.Horizontal
rowLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
rowLayout.Padding = UDim.new(0, SLOT_GAP)
rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
rowLayout.Parent = row

local cooldownRingUpdaters = {}
local cooldownLabels = {}

for _, slotInfo in ipairs(SLOTS) do
	local slot = Instance.new("Frame")
	slot.Name = "Slot_" .. slotInfo.id
	slot.LayoutOrder = slotInfo.layoutOrder
	slot.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
	slot.BackgroundColor3 = UIColors.panel
	slot.BackgroundTransparency = UIColors.panelTransparency
	slot.ClipsDescendants = false
	slot.Parent = row

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = slot

	local stroke = Instance.new("UIStroke")
	stroke.Color = UIColors.rim
	stroke.Transparency = UIColors.rimTransparency
	stroke.Thickness = 1.5
	stroke.Parent = slot

	local iconHolder = Instance.new("Frame")
	iconHolder.BackgroundTransparency = 1
	iconHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	iconHolder.Position = UDim2.new(0.5, 0, 0.5, 0)
	iconHolder.Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE)
	iconHolder.Parent = slot
	HudIcons[slotInfo.icon](iconHolder, ICON_SIZE, true)

	-- 키 라벨 알약 - 슬롯 바깥 아래로 살짝 겹쳐 나온다(목업 .slot .key의 bottom:-3px).
	local keyPill = Instance.new("TextLabel")
	keyPill.Name = "KeyPill"
	keyPill.AnchorPoint = Vector2.new(0.5, 0)
	keyPill.Position = UDim2.new(0.5, 0, 1, 3)
	keyPill.AutomaticSize = Enum.AutomaticSize.X
	keyPill.Size = UDim2.new(0, 0, 0, 15)
	keyPill.BackgroundColor3 = UIColors.panel
	keyPill.BackgroundTransparency = 0
	keyPill.Font = Enum.Font.GothamBold
	keyPill.TextSize = 10
	keyPill.TextColor3 = UIColors.textTertiary
	keyPill.Text = slotInfo.key
	keyPill.ZIndex = 2
	keyPill.Parent = slot

	local keyPillPadding = Instance.new("UIPadding")
	keyPillPadding.PaddingLeft = UDim.new(0, 5)
	keyPillPadding.PaddingRight = UDim.new(0, 5)
	keyPillPadding.Parent = keyPill

	local keyPillCorner = Instance.new("UICorner")
	keyPillCorner.CornerRadius = UDim.new(0, 4)
	keyPillCorner.Parent = keyPill

	local keyPillStroke = Instance.new("UIStroke")
	keyPillStroke.Color = UIColors.rim
	keyPillStroke.Transparency = UIColors.rimTransparency
	keyPillStroke.Thickness = 1
	keyPillStroke.Parent = keyPill

	-- 쿨다운 링(스톱워치 눈금, HudIcons 모듈 설명 참고) - 기본은 숨김(update(0)).
	cooldownRingUpdaters[slotInfo.id] = HudIcons.buildCooldownRing(slot, SLOT_SIZE)

	local cooldownLabel = Instance.new("TextLabel")
	cooldownLabel.Name = "CooldownLabel"
	cooldownLabel.BackgroundTransparency = 1
	cooldownLabel.Size = UDim2.new(1, 0, 1, 0)
	cooldownLabel.Font = Enum.Font.GothamBold
	cooldownLabel.TextSize = 18
	cooldownLabel.TextColor3 = UIColors.textPrimary
	cooldownLabel.Text = ""
	cooldownLabel.ZIndex = 3
	cooldownLabel.Parent = slot

	local cooldownLabelStroke = Instance.new("UIStroke")
	cooldownLabelStroke.Thickness = 1.5
	cooldownLabelStroke.Color = Color3.new(0, 0, 0)
	cooldownLabelStroke.Parent = cooldownLabel

	cooldownLabels[slotInfo.id] = cooldownLabel
end

-- 진입점만 미리 만들어 둔다 - 지금은 어떤 스킬 시스템도 이 함수를 부르지 않는다(대시·Q·E
-- 전부 미구현). remainingSeconds<=0이면 완전히 걷힌 "사용 가능" 상태로 되돌린다.
local function setCooldown(slotId, remainingSeconds, totalSeconds)
	local updateRing = cooldownRingUpdaters[slotId]
	local label = cooldownLabels[slotId]
	if not updateRing or not label then
		return
	end

	if remainingSeconds <= 0 or totalSeconds <= 0 then
		updateRing(0)
		label.Text = ""
		return
	end

	updateRing(remainingSeconds / totalSeconds)
	label.Text = ("%.0f"):format(math.ceil(remainingSeconds))
end
