-- 강화 UI(10-2). 기능 확인 수준 - 폴리시(꾸미기)는 UI 세션에서 한꺼번에 한다. 강화대
-- 근처에서만 보인다(거리 기준, WorldConfig.enhance.interactionRangeStuds와 서버가 같은
-- 값을 쓴다). 서버 Attribute(WeaponLevel/Gold)만 읽는다 - 확률·비용 표시는 Enhance
-- 조회 함수로 계산하되, 실제 판정은 절대 여기서 하지 않는다(서버 전용, EnhanceServer.server.lua).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Enhance = require(ReplicatedStorage.Shared.Enhance)

local enhanceRequest = ReplicatedStorage:WaitForChild("EnhanceRequest")
local enhanceResult = ReplicatedStorage:WaitForChild("EnhanceResult")

local RESULT_LABEL = {
	success = "성공! +%d",
	maintain = "실패 - 형상유지 (+%d)",
	down1 = "실패 - 1강 하락 (+%d)",
	down2 = "실패 - 2강 하락 (+%d)",
	reset = "실패 - 초기화 (+%d)",
	max = "이미 최대 강화 단계입니다",
	insufficient_gold = "골드가 부족합니다",
}

local player = Players.LocalPlayer
local stationPosition = WorldConfig.huntingGround.center + WorldConfig.enhance.stationOffset

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "EnhanceGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "EnhancePanel"
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.new(0.5, 0, 1, -120)
panel.Size = UDim2.new(0, 320, 0, 170)
panel.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
panel.BackgroundTransparency = 0.1
panel.Visible = false
panel.Parent = screenGui

local infoLabel = Instance.new("TextLabel")
infoLabel.BackgroundTransparency = 1
infoLabel.Size = UDim2.new(1, -16, 0, 90)
infoLabel.Position = UDim2.new(0, 8, 0, 8)
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.TextYAlignment = Enum.TextYAlignment.Top
infoLabel.TextWrapped = true
infoLabel.Font = Enum.Font.Gotham
infoLabel.TextSize = 16
infoLabel.TextColor3 = Color3.new(1, 1, 1)
infoLabel.Text = ""
infoLabel.Parent = panel

local enhanceButton = Instance.new("TextButton")
enhanceButton.Size = UDim2.new(0, 140, 0, 40)
enhanceButton.Position = UDim2.new(0.5, -70, 1, -48)
enhanceButton.Text = "강화"
enhanceButton.Font = Enum.Font.GothamBold
enhanceButton.TextSize = 18
enhanceButton.BackgroundColor3 = Color3.fromRGB(200, 160, 40)
enhanceButton.Parent = panel

local resultLabel = Instance.new("TextLabel")
resultLabel.BackgroundTransparency = 1
resultLabel.Size = UDim2.new(1, -16, 0, 20)
resultLabel.Position = UDim2.new(0, 8, 1, -74)
resultLabel.Font = Enum.Font.GothamBold
resultLabel.TextSize = 14
resultLabel.TextColor3 = Color3.fromRGB(255, 220, 90)
resultLabel.Text = ""
resultLabel.Parent = panel

local function updateInfo()
	local level = player:GetAttribute("WeaponLevel") or 0
	local gold = player:GetAttribute("Gold") or 0
	local cost = Enhance.getCost(level)

	if not cost then
		infoLabel.Text = ("현재 +%d (최대 강화 단계)"):format(level)
		enhanceButton.Text = "최대"
		enhanceButton.AutoButtonColor = false
		return
	end

	local prob = Enhance.getProbability(level)
	enhanceButton.Text = "강화"
	enhanceButton.AutoButtonColor = true
	infoLabel.Text = ("현재 +%d\n다음 +%d 성공 확률 %.0f%%\n소모 골드 %s (보유 %s)"):format(
		level, level + 1, prob.success * 100, NumberFormat.format(cost), NumberFormat.format(gold))
end

enhanceButton.Activated:Connect(function()
	enhanceRequest:FireServer()
end)

enhanceResult.OnClientEvent:Connect(function(data)
	local level = data.level or (player:GetAttribute("WeaponLevel") or 0)
	local template = RESULT_LABEL[data.result] or data.result
	if template:find("%%d") then
		resultLabel.Text = template:format(level)
	else
		resultLabel.Text = template
	end
	updateInfo()
end)

player:GetAttributeChangedSignal("WeaponLevel"):Connect(updateInfo)
player:GetAttributeChangedSignal("Gold"):Connect(updateInfo)

RunService.Heartbeat:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		panel.Visible = false
		return
	end

	local distance = (root.Position - stationPosition).Magnitude
	local wasVisible = panel.Visible
	panel.Visible = distance <= WorldConfig.enhance.interactionRangeStuds
	if panel.Visible and not wasVisible then
		updateInfo()
	end
end)
