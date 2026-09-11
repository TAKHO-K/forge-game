-- 캐릭터 레벨 표시(16-1 신설 → 16-2에서 목업 재정렬). 상단 중앙 칩 행(TopChipsRow,
-- StageUI.client.lua가 만든다)의 두 번째 칩(LayoutOrder=2, 골드=1·스테이지=3과 나란히).
-- 진행률(%) 자체는 ExpBar.client.lua가 화면 맨 아래에서 보여준다 - 여기는 숫자만 다룬다.
--
-- 16-2: 목업의 .chip.lv는 테두리에 경험치 색(xp) 그라디언트를 줘서 다른 칩과 구분한다
-- (CSS는 두 배경을 겹치는 트릭을 쓰지만, Roblox는 UIStroke에 UIGradient를 그대로 물릴 수
-- 있어 오히려 더 간단하다 - "로블록스에 HTML엔 없는 게 있다"는 지시가 말한 경우).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local HudChip = require(script.Parent.HudChip)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local topChipsRow = playerGui:WaitForChild("TopChipsGui"):WaitForChild("TopChipsRow")
local chip = HudChip.new(topChipsRow, 2)
chip.Name = "LevelChip"

-- 경험치색 그라디언트 테두리 - 위는 진하고 아래로 갈수록 옅어진다(목업의 세로 그라디언트
-- 방향과 동일). Rim 테두리 위에 덧그리는 게 아니라 대체한다(같은 자리에 두 UIStroke를
-- 두면 두꺼워지기만 하고 색은 나중 것만 보인다).
local rimStroke = chip:FindFirstChild("Rim")
if rimStroke then
	rimStroke.Color = UIColors.xp
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0.88),
	})
	gradient.Rotation = 90
	gradient.Parent = rimStroke
end

local prefixLabel = Instance.new("TextLabel")
prefixLabel.Name = "Prefix"
prefixLabel.LayoutOrder = 1
prefixLabel.BackgroundTransparency = 1
prefixLabel.AutomaticSize = Enum.AutomaticSize.X
prefixLabel.Size = UDim2.new(0, 0, 1, 0)
prefixLabel.Font = Enum.Font.GothamBold
prefixLabel.TextSize = 13
prefixLabel.TextColor3 = UIColors.textPrimary
prefixLabel.Text = "Lv."
prefixLabel.Parent = chip

local levelLabel = Instance.new("TextLabel")
levelLabel.Name = "LevelLabel"
levelLabel.LayoutOrder = 2
levelLabel.BackgroundTransparency = 1
levelLabel.AutomaticSize = Enum.AutomaticSize.X
levelLabel.Size = UDim2.new(0, 0, 1, 0)
levelLabel.Font = Enum.Font.GothamBold
levelLabel.TextSize = 13
levelLabel.TextColor3 = UIColors.xp
levelLabel.Text = "1"
levelLabel.Parent = chip

local function update()
	levelLabel.Text = tostring(player:GetAttribute("CharacterLevel") or 1)
end

player:GetAttributeChangedSignal("CharacterLevel"):Connect(update)
update()
