-- 경험치바(16-1 [3]). 마인크래프트·메이플식 - 화면 맨 아래 가로 전체, 퍼센트를 함께
-- 표시한다. 13-2가 만든 레벨 곡선(CharacterLevel.getProgress)을 그대로 읽는다 - 진행률
-- 공식을 새로 만들지 않는다. 13-2 이후 지금까지 characterExp/characterLevel Attribute를
-- 읽는 client 코드가 전혀 없었다(레벨업 토스트만 있고 상시 진행률 표시가 없었다, 16-1 [0]
-- 조사 결과) - 이 파일이 그 첫 소비자다.
--
-- 레벨업 순간의 토스트(LevelUpHud.client.lua)는 그대로 두고, 여기서는 그 순간 바가 실제로
-- 차오르는 것만 덧붙인다(지시 - "바가 차오르는 것도 보여라").
--
-- 가로 전체를 덮으므로 옆 여백이 없다 - 좌우 코너에 걸리는 로블록스 기본 모바일 조이스틱/
-- 점프 버튼과는 세로로 겹칠 수 있지만, 이 바는 터치 대상이 아니라(입력을 받지 않는다)
-- 얇은 시각 요소일 뿐이라 조작을 막지 않는다(16-1 [0] 지시의 "겹치지 않는지 검증" 대상은
-- 조작 가능 요소 기준 - Studio 플레이테스트로 실제 확인한다).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local CharacterLevel = require(ReplicatedStorage.Shared.CharacterLevel)

local BAR_HEIGHT = 26

local player = Players.LocalPlayer

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ExpBarGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local track = Instance.new("Frame")
track.Name = "ExpTrack"
track.AnchorPoint = Vector2.new(0.5, 1)
track.Position = UDim2.new(0.5, 0, 1, 0)
track.Size = UDim2.new(1, 0, 0, BAR_HEIGHT)
track.BackgroundColor3 = UIColors.panel
track.BackgroundTransparency = UIColors.panelTransparency
track.BorderSizePixel = 0
track.Parent = screenGui

local topBorder = Instance.new("Frame")
topBorder.Name = "TopBorder"
topBorder.AnchorPoint = Vector2.new(0.5, 1)
topBorder.Position = UDim2.new(0.5, 0, 0, 0)
topBorder.Size = UDim2.new(1, 0, 0, 1)
topBorder.BackgroundColor3 = UIColors.border
topBorder.BorderSizePixel = 0
topBorder.Parent = track

local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.BackgroundColor3 = UIColors.accent
fill.BorderSizePixel = 0
fill.Size = UDim2.new(0, 0, 1, 0)
fill.Parent = track

local percentLabel = Instance.new("TextLabel")
percentLabel.Name = "PercentLabel"
percentLabel.BackgroundTransparency = 1
percentLabel.Size = UDim2.new(1, 0, 1, 0)
percentLabel.Font = Enum.Font.GothamBold
percentLabel.TextSize = 14
percentLabel.TextColor3 = UIColors.textPrimary
percentLabel.Text = "0%"
percentLabel.ZIndex = 2
percentLabel.Parent = track

local percentLabelStroke = Instance.new("UIStroke")
percentLabelStroke.Thickness = 1.5
percentLabelStroke.Color = Color3.new(0, 0, 0)
percentLabelStroke.Parent = percentLabel

local function update()
	local level = player:GetAttribute("CharacterLevel") or 1
	local exp = player:GetAttribute("CharacterExp") or 0
	local progress = CharacterLevel.getProgress(exp, level)
	local ratio = math.clamp(progress.ratio, 0, 1)

	fill.Size = UDim2.new(ratio, 0, 1, 0)
	percentLabel.Text = ("%d%%"):format(math.floor(ratio * 100))
end

player:GetAttributeChangedSignal("CharacterExp"):Connect(update)
player:GetAttributeChangedSignal("CharacterLevel"):Connect(update)
update()
