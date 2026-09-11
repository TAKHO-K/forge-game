-- 무한 모드 스테이지 이동 UI(11-1 [3]). 기능 확인 수준 - 폴리시는 UI 세션에서 한다.
-- 현재 단계·최고 기록 표시 + 위/아래 버튼 하나씩. 서버 Attribute(InfiniteStage/
-- InfiniteStageBest)만 읽는다 - 이동 자체는 항상 서버 응답(StageMoveResult)을 거친다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)

local stageMoveRequest = ReplicatedStorage:WaitForChild("StageMoveRequest")
local stageMoveResult = ReplicatedStorage:WaitForChild("StageMoveResult")

local player = Players.LocalPlayer

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StageUIGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- 다른 HUD가 이미 차지한 자리(체력바=상단중앙, 골드=상단우측, 공격=우하단, 직업변경=
-- 좌하단, 강화=하단중앙)와 안 겹치는 좌상단에 둔다.
local panel = Instance.new("Frame")
panel.Name = "StagePanel"
panel.AnchorPoint = Vector2.new(0, 0)
panel.Position = UDim2.new(0, 16, 0, 16)
panel.Size = UDim2.new(0, 170, 0, 70)
panel.BackgroundColor3 = UIColors.panel
panel.BackgroundTransparency = UIColors.panelTransparency
panel.BorderSizePixel = 0
panel.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 6)
panelCorner.Parent = panel

local stageLabel = Instance.new("TextLabel")
stageLabel.Name = "StageLabel"
stageLabel.BackgroundTransparency = 1
stageLabel.Position = UDim2.new(0, 8, 0, 4)
stageLabel.Size = UDim2.new(1, -16, 0, 24)
stageLabel.Font = Enum.Font.GothamBold
stageLabel.TextSize = 16
stageLabel.TextColor3 = UIColors.textPrimary
stageLabel.TextXAlignment = Enum.TextXAlignment.Left
stageLabel.Text = "스테이지 -"
stageLabel.Parent = panel

local bestLabel = Instance.new("TextLabel")
bestLabel.Name = "BestLabel"
bestLabel.BackgroundTransparency = 1
bestLabel.Position = UDim2.new(0, 8, 0, 26)
bestLabel.Size = UDim2.new(1, -16, 0, 18)
bestLabel.Font = Enum.Font.Gotham
bestLabel.TextSize = 13
bestLabel.TextColor3 = UIColors.textSecondary
bestLabel.TextXAlignment = Enum.TextXAlignment.Left
bestLabel.Text = "최고 기록 -"
bestLabel.Parent = panel

local function makeMoveButton(text, xOffset)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, 74, 0, 26)
	button.Position = UDim2.new(0, xOffset, 0, 46)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 14
	button.TextColor3 = UIColors.textPrimary
	button.BackgroundColor3 = UIColors.border
	button.Text = text
	button.Parent = panel
	return button
end

local downButton = makeMoveButton("▼ 아래", 8)
local upButton = makeMoveButton("▲ 위", 88)

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
	stageLabel.Text = ("스테이지 %d"):format(player:GetAttribute("InfiniteStage") or 1)
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
