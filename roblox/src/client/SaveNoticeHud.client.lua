-- 저장 실패·중단 안내(10-1). 조용히 넘기지 않는다 - 서버가 저장을 포기했을 때
-- (재시도 소진, 다른 서버에 밀림, 불러오기 실패) 플레이어가 알 수 있어야 한다.
-- 화면 중앙 상단에 잠깐 띄우는 단순 토스트. 자주 뜰 이벤트가 아니라 UI를 더 만들지 않는다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local saveNotice = ReplicatedStorage:WaitForChild("SaveNotice")

local DISPLAY_SECONDS = 6

local player = Players.LocalPlayer

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SaveNoticeGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.Name = "SaveNoticeLabel"
label.AnchorPoint = Vector2.new(0.5, 0)
label.Position = UDim2.new(0.5, 0, 0, 64)
label.Size = UDim2.new(0, 480, 0, 40)
label.BackgroundColor3 = Color3.fromRGB(120, 20, 20)
label.BackgroundTransparency = 1
label.TextTransparency = 1
label.BorderSizePixel = 0
label.Font = Enum.Font.GothamBold
label.TextSize = 16
label.TextWrapped = true
label.TextColor3 = Color3.new(1, 1, 1)
label.Text = ""
label.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent = label

saveNotice.OnClientEvent:Connect(function(message)
	label.Text = message
	TweenService:Create(label, TweenInfo.new(0.2), { BackgroundTransparency = 0.15, TextTransparency = 0 }):Play()

	task.delay(DISPLAY_SECONDS, function()
		if label.Text == message then
			TweenService:Create(label, TweenInfo.new(0.5), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
		end
	end)
end)
