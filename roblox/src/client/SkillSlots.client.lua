-- 스킬 슬롯 자리(16-1 [2]). Q·E·대시 세 칸 - 대시는 조사 결과(16-1 [0]) 이 프로젝트에
-- 실제로 존재하지 않는 기능이다(MonsterAI.server.lua:169, BossData.lua:48에 "아직 없다"는
-- 코드 주석만 있다) - 그래서 여기서도 자리와 쿨타임 표현 방식만 만들고 이동·무적 로직은
-- 절대 만들지 않는다. Q·E도 아직 스킬 자체가 없다 - 세 슬롯 다 지금은 "곧 채워질 자리"
-- 상태(키 글자만 있는 빈 칸)로 그린다.
--
-- SLOTS를 데이터 목록으로 두고 그 목록만큼 슬롯을 그린다 - 4번째 슬롯이 필요해지면(지시
-- "나중에 4개까지 늘어날 수 있는 구조로") 이 목록에 한 줄만 추가하면 된다(이 프로젝트의
-- "데이터 추가로만 확장한다" 원칙을 UI에도 그대로 적용).
--
-- 쿨타임 표현은 "어두워짐 + 남은 초" 쪽을 골랐다(지시가 준 두 선택지 중 - 원형 채움은
-- 로블록스 기본 UI로 구현하려면 이미지 마스크나 회전 트릭이 필요해 이번처럼 기능 없는
-- 자리 단계에서 들이기엔 과하다). setCooldown은 미래에 실제 스킬이 생겼을 때 연결할
-- 진입점만 만들어 둔 것 - 지금은 아무도 호출하지 않는다(호출하는 스킬 시스템 자체가
-- 아직 없다).
--
-- 체력바(PlayerHealthBar.client.lua) 바로 위, 같은 중앙 하단 축에 쌓는다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)

local SLOT_SIZE = 56
local SLOT_GAP = 10

-- PlayerHealthBar.client.lua의 BOTTOM_OFFSET(36) + 체력바 높이(34) + 여백(14).
local BOTTOM_OFFSET = 84

local SLOTS = {
	{ id = "q", label = "Q" },
	{ id = "e", label = "E" },
	{ id = "dash", label = "대시" },
}

local player = Players.LocalPlayer

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SkillSlotsGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local row = Instance.new("Frame")
row.Name = "SkillSlotRow"
row.AnchorPoint = Vector2.new(0.5, 1)
row.Position = UDim2.new(0.5, 0, 1, -BOTTOM_OFFSET)
row.Size = UDim2.new(0, #SLOTS * SLOT_SIZE + (#SLOTS - 1) * SLOT_GAP, 0, SLOT_SIZE)
row.BackgroundTransparency = 1
row.Parent = screenGui

local rowLayout = Instance.new("UIListLayout")
rowLayout.FillDirection = Enum.FillDirection.Horizontal
rowLayout.Padding = UDim.new(0, SLOT_GAP)
rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
rowLayout.Parent = row

local cooldownOverlays = {}
local cooldownLabels = {}

for order, slotInfo in ipairs(SLOTS) do
	local slot = Instance.new("Frame")
	slot.Name = "Slot_" .. slotInfo.id
	slot.LayoutOrder = order
	slot.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
	slot.BackgroundColor3 = UIColors.panel
	slot.BackgroundTransparency = UIColors.panelTransparency
	slot.Parent = row

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = slot

	local stroke = Instance.new("UIStroke")
	stroke.Color = UIColors.border
	stroke.Thickness = 1.5
	stroke.Parent = slot

	local keyLabel = Instance.new("TextLabel")
	keyLabel.Name = "KeyLabel"
	keyLabel.BackgroundTransparency = 1
	keyLabel.Size = UDim2.new(1, 0, 1, 0)
	keyLabel.Font = Enum.Font.GothamBold
	keyLabel.TextSize = slotInfo.id == "dash" and 15 or 22
	keyLabel.TextColor3 = UIColors.textSecondary
	keyLabel.Text = slotInfo.label
	keyLabel.ZIndex = 2
	keyLabel.Parent = slot

	-- 쿨타임 중 어두워지는 덮개. 기본은 완전히 투명(=쿨타임 없음, "비어 있어도 어색하지
	-- 않아야 한다"). 아래에서 위로 걷히도록 AnchorPoint를 아래에 둔다.
	local overlay = Instance.new("Frame")
	overlay.Name = "CooldownOverlay"
	overlay.AnchorPoint = Vector2.new(0, 1)
	overlay.Position = UDim2.new(0, 0, 1, 0)
	overlay.Size = UDim2.new(1, 0, 0, 0)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.35
	overlay.BorderSizePixel = 0
	overlay.ZIndex = 3
	overlay.Parent = slot

	local overlayCorner = Instance.new("UICorner")
	overlayCorner.CornerRadius = UDim.new(0, 8)
	overlayCorner.Parent = overlay

	local cooldownLabel = Instance.new("TextLabel")
	cooldownLabel.Name = "CooldownLabel"
	cooldownLabel.BackgroundTransparency = 1
	cooldownLabel.Size = UDim2.new(1, 0, 1, 0)
	cooldownLabel.Font = Enum.Font.GothamBold
	cooldownLabel.TextSize = 20
	cooldownLabel.TextColor3 = UIColors.textPrimary
	cooldownLabel.Text = ""
	cooldownLabel.ZIndex = 4
	cooldownLabel.Parent = slot

	cooldownOverlays[slotInfo.id] = overlay
	cooldownLabels[slotInfo.id] = cooldownLabel
end

-- 진입점만 미리 만들어 둔다 - 지금은 어떤 스킬 시스템도 이 함수를 부르지 않는다(대시·Q·E
-- 전부 미구현). remainingSeconds<=0이면 완전히 걷힌 "사용 가능" 상태로 되돌린다.
local function setCooldown(slotId, remainingSeconds, totalSeconds)
	local overlay = cooldownOverlays[slotId]
	local label = cooldownLabels[slotId]
	if not overlay or not label then
		return
	end

	if remainingSeconds <= 0 or totalSeconds <= 0 then
		overlay.Size = UDim2.new(1, 0, 0, 0)
		label.Text = ""
		return
	end

	local ratio = math.clamp(remainingSeconds / totalSeconds, 0, 1)
	overlay.Size = UDim2.new(1, 0, ratio, 0)
	label.Text = ("%.0f"):format(math.ceil(remainingSeconds))
end
