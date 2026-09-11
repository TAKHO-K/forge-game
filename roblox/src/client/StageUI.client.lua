-- 무한 모드 스테이지 이동 UI(11-1 [3] 신설 → 16-2에서 목업 재정렬). 서버 Attribute
-- (InfiniteStage/InfiniteStageBest)만 읽는다 - 이동 자체는 항상 서버 응답
-- (StageMoveResult)을 거친다.
--
-- 16-2: `Claude outputs/hud-mockup.html`은 골드·레벨·스테이지를 상단 중앙에 한 줄로 붙은
-- 칩 세 개로 그린다(16-1까지는 좌상단/상단중앙/우상단으로 흩어져 있었다). 그 한 줄
-- (TopChipsRow)을 이 스크립트가 만든다 - GoldHud.client.lua/LevelHud.client.lua가
-- WaitForChild로 찾아 자기 칩을 끼워 넣는다(AttackInput이 SkillSlots의 Row를 찾는 것과
-- 같은 패턴, 순서 계약: 골드=1, 레벨=2, 스테이지=3).
--
-- 목업의 스테이지 칩은 숫자만 보여주고 위/아래 이동 버튼이 없다(디자인 시안이라 순수
-- 정보 표시만 다뤘을 것) - 이 프로젝트는 그 버튼이 실제 이동 기능이라 뺄 수 없다. 칩
-- 자체는 목업과 똑같이 만들고, "최고 기록"과 이동 버튼은 칩 아래에 작게 이어 붙였다
-- (세로로 쌓은 한 묶음 - HudChip은 칩 틀만 만들고 이 묶음 구성은 이 파일이 맡는다).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local HudChip = require(script.Parent.HudChip)

local stageMoveRequest = ReplicatedStorage:WaitForChild("StageMoveRequest")
local stageMoveResult = ReplicatedStorage:WaitForChild("StageMoveResult")

local player = Players.LocalPlayer

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TopChipsGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local row = Instance.new("Frame")
row.Name = "TopChipsRow"
row.AnchorPoint = Vector2.new(0.5, 0)
row.Position = UDim2.new(0.5, 0, 0, 14)
row.AutomaticSize = Enum.AutomaticSize.XY
row.Size = UDim2.new(0, 0, 0, 0)
row.BackgroundTransparency = 1
row.Parent = screenGui

local rowLayout = Instance.new("UIListLayout")
rowLayout.FillDirection = Enum.FillDirection.Horizontal
rowLayout.VerticalAlignment = Enum.VerticalAlignment.Top
rowLayout.Padding = UDim.new(0, 10)
rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
rowLayout.Parent = row

-- 스테이지 묶음(칩 + 최고기록 + 이동버튼) - 골드·레벨 칩과 달리 세로로 더 늘어난다.
local wrapper = Instance.new("Frame")
wrapper.Name = "StageWrapper"
wrapper.LayoutOrder = 3
wrapper.AutomaticSize = Enum.AutomaticSize.XY
wrapper.Size = UDim2.new(0, 0, 0, 0)
wrapper.BackgroundTransparency = 1
wrapper.Parent = row

local wrapperLayout = Instance.new("UIListLayout")
wrapperLayout.FillDirection = Enum.FillDirection.Vertical
wrapperLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
wrapperLayout.Padding = UDim.new(0, 4)
wrapperLayout.SortOrder = Enum.SortOrder.LayoutOrder
wrapperLayout.Parent = wrapper

local chip = HudChip.new(wrapper, 1)

local stageSub = Instance.new("TextLabel")
stageSub.Name = "StageSub"
stageSub.BackgroundTransparency = 1
stageSub.AutomaticSize = Enum.AutomaticSize.X
stageSub.Size = UDim2.new(0, 0, 1, 0)
stageSub.LayoutOrder = 1
stageSub.Font = Enum.Font.GothamBold
stageSub.TextSize = 11.5
stageSub.TextColor3 = UIColors.textTertiary
stageSub.Text = "STAGE"
stageSub.Parent = chip

local stageLabel = Instance.new("TextLabel")
stageLabel.Name = "StageLabel"
stageLabel.BackgroundTransparency = 1
stageLabel.AutomaticSize = Enum.AutomaticSize.X
stageLabel.Size = UDim2.new(0, 0, 1, 0)
stageLabel.LayoutOrder = 2
stageLabel.Font = Enum.Font.GothamBold
stageLabel.TextSize = 15
stageLabel.TextColor3 = UIColors.textPrimary
stageLabel.Text = "-"
stageLabel.Parent = chip

local bestLabel = Instance.new("TextLabel")
bestLabel.Name = "BestLabel"
bestLabel.LayoutOrder = 2
bestLabel.BackgroundTransparency = 1
bestLabel.AutomaticSize = Enum.AutomaticSize.X
bestLabel.Size = UDim2.new(0, 0, 0, 14)
bestLabel.Font = Enum.Font.Gotham
bestLabel.TextSize = 10.5
bestLabel.TextColor3 = UIColors.textTertiary
bestLabel.Text = "최고 기록 -"
bestLabel.Parent = wrapper

local buttonsRow = Instance.new("Frame")
buttonsRow.Name = "MoveButtons"
buttonsRow.LayoutOrder = 3
buttonsRow.AutomaticSize = Enum.AutomaticSize.XY
buttonsRow.Size = UDim2.new(0, 0, 0, 0)
buttonsRow.BackgroundTransparency = 1
buttonsRow.Parent = wrapper

local buttonsRowLayout = Instance.new("UIListLayout")
buttonsRowLayout.FillDirection = Enum.FillDirection.Horizontal
buttonsRowLayout.Padding = UDim.new(0, 6)
buttonsRowLayout.SortOrder = Enum.SortOrder.LayoutOrder
buttonsRowLayout.Parent = buttonsRow

local function makeMoveButton(text, order)
	local button = Instance.new("TextButton")
	button.LayoutOrder = order
	button.AutomaticSize = Enum.AutomaticSize.X
	button.Size = UDim2.new(0, 0, 0, 22)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 12
	button.TextColor3 = UIColors.textSecondary
	button.BackgroundColor3 = UIColors.panel
	button.BackgroundTransparency = UIColors.panelTransparency
	button.Text = text
	button.Parent = buttonsRow

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Color = UIColors.rim
	stroke.Transparency = UIColors.rimTransparency
	stroke.Thickness = 1
	stroke.Parent = button

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = button

	return button
end

local downButton = makeMoveButton("▼", 1)
local upButton = makeMoveButton("▲", 2)

local function currentStage()
	return player:GetAttribute("InfiniteStage") or 1
end

downButton.Activated:Connect(function()
	stageMoveRequest:FireServer(currentStage() - 1)
end)

upButton.Activated:Connect(function()
	stageMoveRequest:FireServer(currentStage() + 1)
end)

local function updateLabels()
	stageLabel.Text = tostring(player:GetAttribute("InfiniteStage") or 1)
	bestLabel.Text = ("최고 기록 %d"):format(player:GetAttribute("InfiniteStageBest") or 1)
end

player:GetAttributeChangedSignal("InfiniteStage"):Connect(updateLabels)
player:GetAttributeChangedSignal("InfiniteStageBest"):Connect(updateLabels)
updateLabels()

-- 서버가 거절하면(최고+2 이상 등) Attribute가 안 바뀌므로 라벨은 그대로다 - 거절 자체를
-- 화면에 알리는 연출은 폴리시 단계로 미룬다(지시 [3] "기능 확인 수준"). 15-1에서 이유가
-- 두 가지로 늘었다 - 콘솔 메시지만이라도 구분해 둔다(reason 없는 옛 서버 응답도
-- 방어적으로 처리).
stageMoveResult.OnClientEvent:Connect(function(payload)
	if payload.result ~= "rejected" then
		return
	end
	if payload.reason == "boss_locked" then
		warn(("[forge-game] 스테이지 이동 거절됨 - 스테이지 %d 보스를 아직 못 깼다"):format(payload.requiredBossStage))
	else
		warn("[forge-game] 스테이지 이동 거절됨 - 요청 범위를 벗어났다")
	end
end)
