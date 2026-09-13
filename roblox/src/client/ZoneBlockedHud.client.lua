-- 구역 밖 공격 차단 안내(19-4 [4]-나). SaveNoticeHud.client.lua와 같은 단순 토스트
-- 패턴이지만 일부러 별도 RemoteEvent·스크립트로 둔다 - "저장 실패"와 "구역 밖 공격"은
-- 전혀 다른 사건이라 하나의 이벤트 이름 아래 묶으면 나중에 로그·의도를 헷갈리게 된다
-- (DevTools.server.lua가 SaveCoordinator의 저장 차단 플래그를 따로 만든 것과 같은 이유).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)

local zoneBlockedNotice = ReplicatedStorage:WaitForChild("ZoneBlockedNotice")

local DISPLAY_SECONDS = 2

local player = Players.LocalPlayer

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ZoneBlockedGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.Name = "ZoneBlockedLabel"
label.AnchorPoint = Vector2.new(0.5, 0)
label.Position = UDim2.new(0.5, 0, 0, 108) -- SaveNoticeHud(y=64, 높이40)보다 아래 - 동시에 떠도 안 겹친다
label.Size = UDim2.new(0, 360, 0, 36)
label.BackgroundColor3 = UIColors.ember -- 공격이 막혔다는 신호라 "저장 실패"(danger, 빨강)와 겹치지 않게 공격 강조색을 쓴다
label.BackgroundTransparency = 1
label.TextTransparency = 1
label.BorderSizePixel = 0
label.Font = Enum.Font.GothamBold
label.TextSize = 15
label.TextWrapped = true
label.TextColor3 = UIColors.textPrimary
label.Text = ""
label.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent = label

zoneBlockedNotice.OnClientEvent:Connect(function(message)
	label.Text = message
	TweenService:Create(label, TweenInfo.new(0.15), { BackgroundTransparency = 0.15, TextTransparency = 0 }):Play()

	task.delay(DISPLAY_SECONDS, function()
		if label.Text == message then
			TweenService:Create(label, TweenInfo.new(0.3), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
		end
	end)
end)
