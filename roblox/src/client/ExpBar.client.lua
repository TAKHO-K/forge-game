-- 경험치바(16-1 [3] 신설 → 16-2에서 목업 재정렬). 마인크래프트·메이플식 - 화면 맨 아래
-- 가로 전체, 퍼센트를 함께 표시한다. 13-2가 만든 레벨 곡선(CharacterLevel.getProgress)을
-- 그대로 읽는다 - 진행률 공식을 새로 만들지 않는다.
--
-- 16-2: `Claude outputs/hud-mockup.html`의 .xpbar 크기·색으로 다시 맞춘다 - 높이 26 → 15,
-- 10칸 분절(.xpseg) 추가, 채움색을 팔레트의 "gold"(accent, 재화/강조 겸용)에서 "xp" 전용
-- 색으로 분리(UIColors 16-2 개정 참고 - 이제 재화·경험치·강조가 서로 다른 색이다).
--
-- 레벨업 순간의 토스트(LevelUpHud.client.lua)는 그대로 두고, 여기서는 그 순간 바가 실제로
-- 차오르는 것만 덧붙인다.
--
-- 가로 전체를 덮으므로 옆 여백이 없다 - 좌우 코너에 걸리는 로블록스 기본 모바일 조이스틱/
-- 점프 버튼과는 세로로 겹칠 수 있지만, 이 바는 터치 대상이 아니라(입력을 받지 않는다)
-- 얇은 시각 요소일 뿐이라 조작을 막지 않는다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local CharacterLevel = require(ReplicatedStorage.Shared.CharacterLevel)

local BAR_HEIGHT = 15
local SEGMENT_COUNT = 10

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
track.BackgroundColor3 = Color3.fromRGB(6, 8, 11) -- 목업 --xpbar 배경(패널보다 더 짙은 전용색)
track.BackgroundTransparency = 0.12
track.BorderSizePixel = 0
track.Parent = screenGui

local topBorder = Instance.new("Frame")
topBorder.Name = "TopBorder"
topBorder.AnchorPoint = Vector2.new(0.5, 1)
topBorder.Position = UDim2.new(0.5, 0, 0, 0)
topBorder.Size = UDim2.new(1, 0, 0, 1)
topBorder.BackgroundColor3 = UIColors.rim
topBorder.BackgroundTransparency = UIColors.rimTransparency
topBorder.BorderSizePixel = 0
topBorder.Parent = track

local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.BackgroundColor3 = UIColors.xp
fill.BorderSizePixel = 0
fill.Size = UDim2.new(0, 0, 1, 0)
fill.ZIndex = 1
fill.Parent = track

-- 목업 linear-gradient(180deg,#FFE07A,--xp) - 위는 밝고 아래는 xp 원색.
local fillGradient = Instance.new("UIGradient")
fillGradient.Color = ColorSequence.new(Color3.fromRGB(255, 224, 122), UIColors.xp)
fillGradient.Rotation = 90
fillGradient.Parent = fill

-- 10칸 분절선(목업 .xpseg) - 진행률 자체는 fill의 폭이 이미 매끄럽게 보여주고, 이 선은
-- "몇 칸 중 몇 칸째"라는 눈금 정보만 얹는다(체력바 눈금과 같은 역할, 다른 자리).
local segmentHolder = Instance.new("Frame")
segmentHolder.Name = "Segments"
segmentHolder.BackgroundTransparency = 1
segmentHolder.Size = UDim2.new(1, 0, 1, 0)
segmentHolder.ZIndex = 2
segmentHolder.Parent = track

for i = 1, SEGMENT_COUNT - 1 do
	local divider = Instance.new("Frame")
	divider.BorderSizePixel = 0
	divider.BackgroundColor3 = Color3.new(0, 0, 0)
	divider.BackgroundTransparency = 0.5
	divider.Size = UDim2.new(0, 1, 1, 0)
	divider.Position = UDim2.new(i / SEGMENT_COUNT, 0, 0, 0)
	divider.Parent = segmentHolder
end

local percentLabel = Instance.new("TextLabel")
percentLabel.Name = "PercentLabel"
percentLabel.BackgroundTransparency = 1
percentLabel.Size = UDim2.new(1, 0, 1, 0)
percentLabel.Font = Enum.Font.GothamBold
percentLabel.TextSize = 10
percentLabel.TextColor3 = UIColors.textPrimary
percentLabel.Text = "0%"
percentLabel.ZIndex = 3
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
