-- 캐릭터 레벨 표시(16-1 [0]/목표 레이아웃의 "상단: 골드 / 경험치 레벨 / 현재 스테이지").
-- 골드(우상단)·스테이지(좌상단)는 이미 있었지만 레벨 상시 표시는 없었다(13-2 이후
-- LevelUpHud는 레벨업 "순간"에만 뜨는 토스트일 뿐 - 16-1 [0] 조사 결과). 상단 중앙의
-- 빈 자리에 작은 배지 하나만 놓는다. 진행률(%) 자체는 ExpBar.client.lua가 화면 맨 아래에서
-- 보여준다 - 여기는 숫자만 다룬다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)

local player = Players.LocalPlayer

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LevelHudGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- 다른 상단 HUD(좌상단=스테이지, 우상단=골드)와 안 겹치는 상단 중앙에 둔다.
local badge = Instance.new("Frame")
badge.Name = "LevelBadge"
badge.AnchorPoint = Vector2.new(0.5, 0)
badge.Position = UDim2.new(0.5, 0, 0, 16)
badge.Size = UDim2.new(0, 84, 0, 32)
badge.BackgroundColor3 = UIColors.panel
badge.BackgroundTransparency = UIColors.panelTransparency
badge.BorderSizePixel = 0
badge.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent = badge

local label = Instance.new("TextLabel")
label.Name = "LevelLabel"
label.BackgroundTransparency = 1
label.Size = UDim2.new(1, 0, 1, 0)
label.Font = Enum.Font.GothamBold
label.TextSize = 16
label.TextColor3 = UIColors.textPrimary
label.Text = "Lv.1"
label.Parent = badge

local function update()
	label.Text = ("Lv.%d"):format(player:GetAttribute("CharacterLevel") or 1)
end

player:GetAttributeChangedSignal("CharacterLevel"):Connect(update)
update()
