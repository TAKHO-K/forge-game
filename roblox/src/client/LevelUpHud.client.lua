-- 레벨업 알림(13-2). SaveNoticeHud와 같은 "화면 중앙에 잠깐 띄우는 단순 토스트" 패턴을
-- 재사용하되, 레벨업은 긍정적 이벤트라 색을 다르게 쓰고(저장 실패=빨강, 레벨업=금색) 더
-- 크게 띄운다 - 드문 이벤트라 눈에 띄어야 한다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)

local levelUp = ReplicatedStorage:WaitForChild("LevelUp")

local DISPLAY_SECONDS = 2

local player = Players.LocalPlayer

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LevelUpHudGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.Name = "LevelUpLabel"
label.AnchorPoint = Vector2.new(0.5, 0.5)
label.Position = UDim2.new(0.5, 0, 0.3, 0)
label.Size = UDim2.new(0, 320, 0, 56)
label.BackgroundColor3 = Color3.fromRGB(40, 32, 8)
label.BackgroundTransparency = 1
label.TextTransparency = 1
label.BorderSizePixel = 0
label.Font = Enum.Font.GothamBold
label.TextSize = 28
label.TextColor3 = UIColors.xp -- 16-2: accent 토큰이 gold/xp/ember로 갈라지면서 레벨업은 xp로.
label.Text = ""
label.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = label

levelUp.OnClientEvent:Connect(function(newLevel)
	label.Text = ("레벨업! Lv.%d"):format(newLevel)
	label.Position = UDim2.new(0.5, 0, 0.3, 0)
	TweenService:Create(label, TweenInfo.new(0.2), { BackgroundTransparency = 0.1, TextTransparency = 0 }):Play()
	TweenService:Create(label, TweenInfo.new(DISPLAY_SECONDS), { Position = UDim2.new(0.5, 0, 0.24, 0) }):Play()

	task.delay(DISPLAY_SECONDS, function()
		if label.Text == ("레벨업! Lv.%d"):format(newLevel) then
			TweenService:Create(label, TweenInfo.new(0.5), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
		end
	end)
end)
