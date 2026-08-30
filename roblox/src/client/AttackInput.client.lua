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

-- 모바일 기준(9-5 개정): 고정 120px는 화면이 작은 폰에서 과하게 크고 태블릿에서는
-- 작아 보인다 - 화면 비율(Scale) 기준으로 잡고, 로블록스가 권장하는 최소 터치 타깃
-- (약 88px, 손가락 오조작 방지)과 최대 크기를 UISizeConstraint로 못박는다. 엄지가
-- 자연스럽게 닿는 우하단 코너 위치는 그대로 유지한다.
local attackButton = Instance.new("TextButton")
attackButton.Name = "AttackButton"
attackButton.AnchorPoint = Vector2.new(1, 1)
attackButton.Position = UDim2.new(1, -24, 1, -24)
attackButton.Size = UDim2.new(0.14, 0, 0.14, 0)
attackButton.Text = "공격"
attackButton.TextScaled = true
attackButton.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
attackButton.Parent = screenGui

local attackButtonAspectRatio = Instance.new("UIAspectRatioConstraint")
attackButtonAspectRatio.AspectRatio = 1
attackButtonAspectRatio.Parent = attackButton

local attackButtonSizeConstraint = Instance.new("UISizeConstraint")
attackButtonSizeConstraint.MinSize = Vector2.new(88, 88)
attackButtonSizeConstraint.MaxSize = Vector2.new(150, 150)
attackButtonSizeConstraint.Parent = attackButton

local attackButtonCorner = Instance.new("UICorner")
attackButtonCorner.CornerRadius = UDim.new(1, 0)
attackButtonCorner.Parent = attackButton

-- Activated는 마우스 클릭·터치 탭·게임패드를 전부 같은 이벤트로 받는다(모바일 대응).
attackButton.Activated:Connect(function()
	attackRequest:FireServer()
end)

-- 몬스터별로 동시에 떠 있는 데미지 숫자 개수(9-5 개정, 9-3에서 미루기만 했던
-- 스택 오프셋). 약한 테이블 키라 몬스터가 사라지면(사망·리스폰) 항목도 같이
-- 수거된다 - 죽은 몬스터 참조를 붙들고 있을 이유가 없다.
local activeStacks = setmetatable({}, { __mode = "k" })

local function showDamageNumber(monsterModel, damage)
	local head = monsterModel and monsterModel:FindFirstChild("Head")
	if not head then
		return
	end

	-- 짧은 시간에 여러 대를 때리면 숫자가 겹쳐 안 보인다 - 이미 떠 있는 개수만큼
	-- 위로 밀어서 계단식으로 쌓는다.
	local stackIndex = activeStacks[monsterModel] or 0
	activeStacks[monsterModel] = stackIndex + 1

	local gui = Instance.new("BillboardGui")
	gui.Name = "DamageNumberGui"
	gui.Size = UDim2.new(3, 0, 1, 0)
	gui.StudsOffset = Vector3.new(0, 2.6 + stackIndex * 0.9, 0)
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
		activeStacks[monsterModel] = math.max((activeStacks[monsterModel] or 1) - 1, 0)
	end)
end

attackResult.OnClientEvent:Connect(showDamageNumber)
