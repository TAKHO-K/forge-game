-- 공격 입력(버튼 하나, 모바일 탭 가능) + 서버 결과 수신. 사거리·대상·데미지 판정은
-- 전부 서버가 한다 - 여기는 클릭 신호를 보내고 서버가 알려준 결과를 그리기만 한다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)

local attackRequest = ReplicatedStorage:WaitForChild("AttackRequest")
local attackResult = ReplicatedStorage:WaitForChild("AttackResult")

local player = Players.LocalPlayer

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AttackGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local attackButton = Instance.new("TextButton")
attackButton.Name = "AttackButton"
attackButton.AnchorPoint = Vector2.new(1, 1)
attackButton.Position = UDim2.new(1, -20, 1, -20)
attackButton.Size = UDim2.new(0, 120, 0, 120)
attackButton.Text = "공격"
attackButton.TextScaled = true
attackButton.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
attackButton.Parent = screenGui

-- Activated는 마우스 클릭·터치 탭·게임패드를 전부 같은 이벤트로 받는다(모바일 대응).
attackButton.Activated:Connect(function()
	attackRequest:FireServer()
end)

local function showDamageNumber(monsterModel, damage)
	local head = monsterModel and monsterModel:FindFirstChild("Head")
	if not head then
		return
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "DamageNumberGui"
	gui.Size = UDim2.new(3, 0, 1, 0)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = head
	gui.Parent = head

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Text = NumberFormat.format(damage)
	label.TextColor3 = Color3.fromRGB(255, 220, 60)
	label.TextScaled = true
	label.Parent = gui

	task.delay(CombatConfig.damageNumberLifetimeSeconds, function()
		gui:Destroy()
	end)
end

attackResult.OnClientEvent:Connect(showDamageNumber)
