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
local Projectiles = require(script.Parent.Projectiles)

-- 원거리 클래스(활·힐러)는 판정 결과를 곧바로 보여주지 않는다 - 투사체가 도착하는
-- 순간까지 미룬다(아래 attackResult 핸들러 참고). 근접 두 클래스는 즉시 표시.
local RANGED_PROJECTILE_KIND = { bow = "arrow", healer = "orb" }

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
		WeaponVisual.playSwing()
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
local function showResult(monsterModel, damage, isCrit, died)
	showDamageNumber(monsterModel, damage, isCrit)
	if not monsterModel then
		return
	end
	if died then
		HitEffects.playDeath(monsterModel)
	else
		HitEffects.playHit(monsterModel, isCrit)
	end
end

-- 활·힐러는 서버 판정 결과(이미 확정된 데미지·치명타·사망 여부)를 곧바로 보여주지
-- 않는다 - 활시위가 아직 안 당겨졌거나 화살이 아직 날아가는 중인데 데미지 숫자가
-- 먼저 뜨면 판정 시점과 화살 도달 시점이 어긋나 보인다(지시 사항). 서버는 이미
-- 즉시 판정했으므로(9-2 서버 권위), 여기서 하는 일은 "이미 정해진 결과를 언제
-- 보여줄지"를 투사체가 실제로 도착하는 순간으로 늦추는 것뿐 - 새로 판정하지 않는다.
attackResult.OnClientEvent:Connect(function(monsterModel, damage, isCrit, died)
	local classId = player:GetAttribute("ClassId")
	local projectileKind = RANGED_PROJECTILE_KIND[classId]

	if not projectileKind then
		showResult(monsterModel, damage, isCrit, died)
		return
	end

	-- 스윙이 아직 "발사 시점"(releaseT)에 안 닿았으면 그때까지 기다렸다가 쏜다 - 서버
	-- 응답이 스윙 애니메이션보다 먼저 와도(대개 그렇다) 시위가 안 당겨진 채로 화살이
	-- 나가는 어색함을 막는다.
	local releaseDelay = WeaponVisual.getReleaseDelay()
	task.delay(releaseDelay, function()
		local targetHead = monsterModel and monsterModel:FindFirstChild("Head")
		local muzzle = WeaponVisual.getMuzzleWorldPosition()
		if not targetHead or not muzzle then
			-- 발사 시점에 대상이 이미 사라졌으면(드문 경우) 투사체 없이 즉시 표시로 대체한다.
			showResult(monsterModel, damage, isCrit, died)
			return
		end
		Projectiles.fire(projectileKind, muzzle, targetHead.Position, isCrit, function()
			showResult(monsterModel, damage, isCrit, died)
		end)
	end)
end)
