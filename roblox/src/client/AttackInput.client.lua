-- 공격 입력(버튼 하나, 모바일 탭 가능) + 서버 결과 수신. 사거리·대상·데미지 판정은
-- 전부 서버가 한다 - 여기는 클릭 신호를 보내고 서버가 알려준 결과를 그리기만 한다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local WeaponVisual = require(script.Parent.WeaponVisual)
local HitEffects = require(script.Parent.HitEffects)

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

-- 스윙 모션은 서버 확인 없이 여기서 바로 재생한다(지시 사항 - "모션은 클라이언트에서
-- 재생한다. 판정은 여전히 서버다. 둘을 섞지 마라"). 다만 버튼을 쿨다운보다 빨리 연타하면
-- (서버는 조용히 무시하는데) 모션만 계속 재생되면 실제 공격 속도보다 빨라 보여 오히려
-- 거짓 피드백이 된다 - 그래서 여기서도 같은 쿨다운을 직접 계산해 재생 여부를 건너뛴다
-- (서버 쿨다운과 별개의 클라이언트 판정 - 공격 자체를 막는 게 아니라 "모션을 또
-- 보여줄지"만 결정한다. attackRequest는 클라이언트 쿨다운과 무관하게 항상 보낸다 -
-- 헛스윙 판정은 여전히 서버 몫이다).
local lastSwingTick = 0

-- Activated는 마우스 클릭·터치 탭·게임패드를 전부 같은 이벤트로 받는다(모바일 대응).
attackButton.Activated:Connect(function()
	attackRequest:FireServer()

	local classId = player:GetAttribute("ClassId")
	if not classId or classId == "" then
		return
	end
	local cooldown = PlayerCombat.getAttackCooldown(classId)
	local now = os.clock()
	if now - lastSwingTick >= cooldown then
		lastSwingTick = now
		WeaponVisual.playSwing(cooldown)
	end
end)

-- 몬스터별로 동시에 떠 있는 데미지 숫자 개수(9-5 개정, 9-3에서 미루기만 했던
-- 스택 오프셋). 약한 테이블 키라 몬스터가 사라지면(사망·리스폰) 항목도 같이
-- 수거된다 - 죽은 몬스터 참조를 붙들고 있을 이유가 없다.
local activeStacks = setmetatable({}, { __mode = "k" })

-- 치명타 크기 배율(PRD-forge-game.md 4.4 "크기 1.5배 + 굵게 + 튀어오르는 모션").
-- 색은 그대로 두고(같은 흰색 계열) 크기·폰트·모션만 바꿔 구분한다.
local CRIT_SIZE_SCALE = 1.5

local function showDamageNumber(monsterModel, damage, isCrit)
	local head = monsterModel and monsterModel:FindFirstChild("Head")
	if not head then
		return
	end

	-- 짧은 시간에 여러 대를 때리면 숫자가 겹쳐 안 보인다 - 이미 떠 있는 개수만큼
	-- 위로 밀어서 계단식으로 쌓는다.
	local stackIndex = activeStacks[monsterModel] or 0
	activeStacks[monsterModel] = stackIndex + 1

	local scale = isCrit and CRIT_SIZE_SCALE or 1
	local finalSize = UDim2.new(3 * scale, 0, 1 * scale, 0)

	local gui = Instance.new("BillboardGui")
	gui.Name = "DamageNumberGui"
	gui.Size = finalSize
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
	label.Font = isCrit and Enum.Font.GothamBlack or Enum.Font.GothamMedium
	label.Parent = gui

	if isCrit then
		-- 튀어오르는 모션: 작게 시작해서 목표 크기로 튕기듯 커진다.
		gui.Size = UDim2.new(finalSize.X.Scale * 0.6, 0, finalSize.Y.Scale * 0.6, 0)
		TweenService:Create(
			gui,
			TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Size = finalSize }
		):Play()
	end

	task.delay(CombatConfig.damageNumberLifetimeSeconds, function()
		gui:Destroy()
		activeStacks[monsterModel] = math.max((activeStacks[monsterModel] or 1) - 1, 0)
	end)
end

-- died가 추가된 이유는 AttackServer.server.lua의 attackResult:FireClient 주석 참고.
-- 죽었으면 피격 반응 대신 사망 연출을 재생한다(둘 다 재생하면 사망 직전 프레임에
-- Body/Head 색을 흰색으로 바꿨다가 곧바로 사망 연출이 그 색을 지워버려 부자연스럽다).
attackResult.OnClientEvent:Connect(function(monsterModel, damage, isCrit, died)
	showDamageNumber(monsterModel, damage, isCrit)
	if not monsterModel then
		return
	end
	if died then
		HitEffects.playDeath(monsterModel)
	else
		HitEffects.playHit(monsterModel, isCrit)
	end
end)
