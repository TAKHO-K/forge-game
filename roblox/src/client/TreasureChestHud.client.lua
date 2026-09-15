-- 보물상자 알림 토스트(22-2 [3]). ZoneBlockedHud.client.lua와 같은 단순 토스트 패턴이지만
-- 별도 RemoteEvent·스크립트로 둔다(그쪽 주석과 같은 이유 - 다른 사건을 한 이벤트에 묶지
-- 않는다). 서버(MonsterSpawner/CombatResolution)가 등장·소멸·파괴 세 순간에 전체에 쏜다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)

local treasureChestNotice = ReplicatedStorage:WaitForChild("TreasureChestNotice")

local DISPLAY_SECONDS = 5 -- 구역 이름을 읽고 출발을 결정할 시간(ZoneBlocked 2초보다 길게)

local player = Players.LocalPlayer

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TreasureChestGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.Name = "TreasureChestLabel"
label.AnchorPoint = Vector2.new(0.5, 0)
label.Position = UDim2.new(0.5, 0, 0, 150) -- ZoneBlockedHud(y=108, 높이36) 아래 - 동시에 떠도 안 겹친다
label.Size = UDim2.new(0, 440, 0, 36)
label.BackgroundColor3 = UIColors.gold
label.BackgroundTransparency = 1
label.TextTransparency = 1
label.BorderSizePixel = 0
label.Font = Enum.Font.GothamBold
label.TextSize = 15
label.TextWrapped = true
label.TextColor3 = Color3.fromRGB(20, 16, 8)
label.Text = ""
label.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent = label

treasureChestNotice.OnClientEvent:Connect(function(message)
	label.Text = message
	TweenService:Create(label, TweenInfo.new(0.15), { BackgroundTransparency = 0.1, TextTransparency = 0 }):Play()

	task.delay(DISPLAY_SECONDS, function()
		if label.Text == message then
			TweenService:Create(label, TweenInfo.new(0.3), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
		end
	end)
end)
