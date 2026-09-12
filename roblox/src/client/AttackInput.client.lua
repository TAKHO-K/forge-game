-- 공격 입력(클릭/탭 조준 공격, 16-7 → 18-2에서 버튼 제거) + 서버 결과 수신. 사거리·대상·
-- 데미지 판정은 전부 서버가 한다 - 여기는 조준점을 실어 클릭 신호를 보내고 서버가 알려준
-- 결과를 그리기만 한다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local WeaponVisual = require(script.Parent.WeaponVisual)
local HitEffects = require(script.Parent.HitEffects)
local Projectiles = require(script.Parent.Projectiles)
local AimTarget = require(script.Parent.AimTarget)
local UIManager = require(script.Parent.UIManager)

-- 원거리 클래스(활·힐러)는 판정 결과를 곧바로 보여주지 않는다 - 투사체가 도착하는
-- 순간까지 미룬다(아래 attackResult 핸들러 참고). 근접 두 클래스는 즉시 표시.
local RANGED_PROJECTILE_KIND = { bow = "arrow", healer = "orb" }

local attackRequest = ReplicatedStorage:WaitForChild("AttackRequest")
local attackResult = ReplicatedStorage:WaitForChild("AttackResult")
local comboUpdate = ReplicatedStorage:WaitForChild("ComboUpdate")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

-- 3타 강타 콤보 표시(16-7) - 18-2까지는 공격 버튼 위에 붙어 있었다. 버튼이 없어진 뒤로는
-- 체력바 바로 위로 옮긴다 - PlayerHealthBar.client.lua가 만들어 두는 전용 앵커(ComboPipsAnchor)
-- 를 WaitForChild로 찾는다(SkillSlots·AttackInput이 옛 CentralRow를 공유하던 것과 같은
-- 계약 패턴). 서버 ComboUpdate가 보내는 comboCount(계속 증가하는 누적값)를 comboHitEvery로
-- 감싸 "이번 3타 사이클의 몇 번째"로 바꿔서 켠다.
local comboPipsAnchor = playerGui:WaitForChild("PlayerHealthBarGui"):WaitForChild("ComboPipsAnchor")

local COMBO_PIP_COUNT = CombatConfig.comboHitEvery
local COMBO_PIP_SIZE = 10
local COMBO_PIP_GAP = 6
local COMBO_PIP_OFF_COLOR = Color3.fromRGB(255, 255, 255)
local COMBO_PIP_OFF_TRANSPARENCY = 0.75
local COMBO_PIP_ON_COLOR = UIColors.ember
local COMBO_PIP_HEAVY_COLOR = Color3.fromRGB(255, 230, 90)

local comboPipsHolder = Instance.new("Frame")
comboPipsHolder.Name = "ComboPips"
comboPipsHolder.Size = UDim2.new(0, COMBO_PIP_COUNT * (COMBO_PIP_SIZE + COMBO_PIP_GAP), 0, COMBO_PIP_SIZE)
comboPipsHolder.BackgroundTransparency = 1
comboPipsHolder.Parent = comboPipsAnchor

local comboPipLayout = Instance.new("UIListLayout")
comboPipLayout.FillDirection = Enum.FillDirection.Horizontal
comboPipLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
comboPipLayout.VerticalAlignment = Enum.VerticalAlignment.Center
comboPipLayout.Padding = UDim.new(0, COMBO_PIP_GAP)
comboPipLayout.Parent = comboPipsHolder

local comboPips = {}
for i = 1, COMBO_PIP_COUNT do
	local pip = Instance.new("Frame")
	pip.Name = "Pip" .. i
	pip.Size = UDim2.new(0, COMBO_PIP_SIZE, 0, COMBO_PIP_SIZE)
	pip.BackgroundColor3 = COMBO_PIP_OFF_COLOR
	pip.BackgroundTransparency = COMBO_PIP_OFF_TRANSPARENCY
	pip.BorderSizePixel = 0
	pip.Parent = comboPipsHolder

	local pipCorner = Instance.new("UICorner")
	pipCorner.CornerRadius = UDim.new(1, 0)
	pipCorner.Parent = pip

	comboPips[i] = pip
end

comboUpdate.OnClientEvent:Connect(function(comboCount, isHeavyHit)
	local posInCycle = ((comboCount - 1) % COMBO_PIP_COUNT) + 1
	for i, pip in ipairs(comboPips) do
		if i <= posInCycle then
			pip.BackgroundColor3 = isHeavyHit and COMBO_PIP_HEAVY_COLOR or COMBO_PIP_ON_COLOR
			pip.BackgroundTransparency = 0
		else
			pip.BackgroundColor3 = COMBO_PIP_OFF_COLOR
			pip.BackgroundTransparency = COMBO_PIP_OFF_TRANSPARENCY
		end
	end
end)

-- 스윙 모션은 서버 확인 없이 여기서 바로 재생한다(지시 사항 - "모션은 클라이언트에서
-- 재생한다. 판정은 여전히 서버다. 둘을 섞지 마라"). 다만 버튼을 쿨다운보다 빨리 연타하면
-- (서버는 조용히 무시하는데) 모션만 계속 재생되면 실제 공격 속도보다 빨라 보여 오히려
-- 거짓 피드백이 된다 - 그래서 여기서도 같은 쿨다운을 직접 계산해 재생 여부를 건너뛴다
-- (서버 쿨다운과 별개의 클라이언트 판정 - 공격 자체를 막는 게 아니라 "모션을 또
-- 보여줄지"만 결정한다. attackRequest는 클라이언트 쿨다운과 무관하게 항상 보낸다 -
-- 헛스윙 판정은 여전히 서버 몫이다).
local lastSwingTick = 0

-- 3타 강타 예측(16-7) - 실제 콤보 카운트·강타 여부는 서버(AttackServer, ComboUpdate)가
-- 확정한다. 다만 스윙 모션(속도 0.7배·스케일 1.3배)은 서버 왕복을 기다리면 늦으므로,
-- 여기서 서버와 똑같은 규칙(comboHitEvery/comboResetWindowSeconds, 스윙을 실제로 재생하는
-- 시점 = 서버 쿨다운 통과 시점과 사실상 같다)으로 미리 짐작해 모션만 먼저 튼다. 예측이
-- 어긋나도(네트워크 지연 등) 피해를 주는 건 아니다 - 히트스톱·카메라 흔들림·콤보 점
-- 표시 같은 실제 피드백은 전부 attackResult/ComboUpdate가 보내는 서버 확정값만 쓴다.
local predictedComboCount = 0
local lastPredictedComboTick = 0

local function predictIsHeavyHit()
	local now = os.clock()
	if now - lastPredictedComboTick > CombatConfig.comboResetWindowSeconds then
		predictedComboCount = 0
	end
	predictedComboCount += 1
	lastPredictedComboTick = now
	return predictedComboCount % CombatConfig.comboHitEvery == 0
end

-- 클릭·탭이 이 함수 하나로 모인다(지시 - "지금 누구를 때리려는가를 게임과 유저가 같은
-- 답으로 알게 한다 ... 따로 짜지 마라"). 18-2부터 공격 버튼이 없어져 aimPoint는 항상
-- 클릭·탭 지점으로 넘어온다 - 그 지점으로 캐릭터를 돌리고 AimTarget 하이라이트도 즉시 갱신한다.
local function fireAttack(aimPoint)
	-- 18-1 [3]: gameProcessedEvent만 믿지 않는다 - modal 창이 열려 있으면 여기서 한 번 더
	-- 막는다(딤 배경이 클릭을 못 먹는 경우가 생겨도 이중 방어가 된다).
	if UIManager.isInputBlocked() then
		return
	end
	AimTarget.refresh(aimPoint)
	attackRequest:FireServer(aimPoint)

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if aimPoint and rootPart then
		local flat = Vector3.new(aimPoint.X - rootPart.Position.X, 0, aimPoint.Z - rootPart.Position.Z)
		if flat.Magnitude > 0.5 then
			rootPart.CFrame = CFrame.new(rootPart.Position, rootPart.Position + flat)
		end
	end

	local classId = player:GetAttribute("ClassId")
	if not classId or classId == "" then
		return
	end
	-- 신발 공속 보너스(16-6) - 서버가 PlayerProfile.refreshMovementSpeed에서 동기화해 둔
	-- Attribute를 그대로 읽는다(클라이언트가 장비 목록을 따로 계산하지 않는다).
	local cooldown = PlayerCombat.getAttackCooldown(classId, player:GetAttribute("SpeedPercentBonus"))
	local now = os.clock()
	if now - lastSwingTick >= cooldown then
		lastSwingTick = now
		WeaponVisual.playSwing(predictIsHeavyHit())
	end
end

-- 클릭·탭한 곳으로 기본공격(16-7 [3], 18-2부터 유일한 공격 수단). gameProcessedEvent가
-- true면 이미 어떤 GuiObject가 이 입력을 먹었다는 뜻(인벤토리·이동 조이스틱 등) - 그때는
-- 공격을 쏘지 않는다.
-- PC는 기본 카메라가 좌클릭 드래그를 쓰지 않아(마우스 이동만으로 회전) 클릭 자체를 그냥
-- 공격으로 써도 된다. 모바일은 UserInputService.TouchTap이 "드래그가 아닌 순수 탭"만
-- 걸러서 보내주므로(카메라 회전 드래그는 별도 TouchPan으로 소비된다) 따로 탭/드래그
-- 구분 로직을 만들 필요가 없다.
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local worldPoint = AimTarget.getWorldPointFromScreen(Vector2.new(input.Position.X, input.Position.Y))
		if worldPoint then
			fireAttack(worldPoint)
		end
	end
end)

UserInputService.TouchTap:Connect(function(touchPositions, gameProcessedEvent)
	if gameProcessedEvent then
		return
	end
	local screenPos = touchPositions[1]
	if not screenPos then
		return
	end
	local worldPoint = AimTarget.getWorldPointFromScreen(screenPos)
	if worldPoint then
		fireAttack(worldPoint)
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

-- 3타 강타 적중 피드백(16-7) - "타격감이 이번 작업의 진짜 목표"라는 지시. 히트스톱
-- 0.05~0.12초 범위에서 실기로 맞춰본 값(0.08초 - 근접·원거리 전 클래스에서 "묵직하다"는
-- 느낌과 "다음 입력이 막힌 것 같다"는 불편함 사이의 중간). 카메라 흔들림은 0.15초 안에
-- 완전히 잦아든다(지시 - "과하면 멀미가 난다. 감쇠 속도가 중요하다").
local HEAVY_HITSTOP_SECONDS = 0.08
local CAMERA_SHAKE_SECONDS = 0.15
local CAMERA_SHAKE_STUDS = 0.35

local cameraShakeUntil = 0
RunService:BindToRenderStep("ComboCameraShake", Enum.RenderPriority.Camera.Value + 1, function()
	local remaining = cameraShakeUntil - os.clock()
	if remaining <= 0 then
		return
	end
	local decay = remaining / CAMERA_SHAKE_SECONDS
	local offset = Vector3.new(
		(math.random() * 2 - 1) * CAMERA_SHAKE_STUDS * decay,
		(math.random() * 2 - 1) * CAMERA_SHAKE_STUDS * decay,
		0
	)
	camera.CFrame *= CFrame.new(offset)
end)

-- died가 추가된 이유는 AttackServer.server.lua의 attackResult:FireClient 주석 참고.
-- 죽었으면 피격 반응 대신 사망 연출을 재생한다(둘 다 재생하면 사망 직전 프레임에
-- Body/Head 색을 흰색으로 바꿨다가 곧바로 사망 연출이 그 색을 지워버려 부자연스럽다).
-- isComboHit(16-7)이면 죽었든 아니든 히트스톱·카메라 흔들림은 그대로 재생한다 - 강타가
-- 처치를 낸 순간도 "강타였다"는 느낌은 여전히 필요하다.
local function showResult(monsterModel, damage, isCrit, died, isComboHit)
	showDamageNumber(monsterModel, damage, isCrit)

	if isComboHit then
		WeaponVisual.applyHitstop(HEAVY_HITSTOP_SECONDS)
		cameraShakeUntil = os.clock() + CAMERA_SHAKE_SECONDS
	end

	if not monsterModel then
		return
	end
	if died then
		HitEffects.playDeath(monsterModel)
	else
		HitEffects.playHit(monsterModel, isCrit, isComboHit and HEAVY_HITSTOP_SECONDS or nil)
	end
end

-- 활·힐러는 서버 판정 결과(이미 확정된 데미지·치명타·사망 여부)를 곧바로 보여주지
-- 않는다 - 활시위가 아직 안 당겨졌거나 화살이 아직 날아가는 중인데 데미지 숫자가
-- 먼저 뜨면 판정 시점과 화살 도달 시점이 어긋나 보인다(지시 사항). 서버는 이미
-- 즉시 판정했으므로(9-2 서버 권위), 여기서 하는 일은 "이미 정해진 결과를 언제
-- 보여줄지"를 투사체가 실제로 도착하는 순간으로 늦추는 것뿐 - 새로 판정하지 않는다.
attackResult.OnClientEvent:Connect(function(monsterModel, damage, isCrit, died, isComboHit)
	local classId = player:GetAttribute("ClassId")
	local projectileKind = RANGED_PROJECTILE_KIND[classId]

	if not projectileKind then
		showResult(monsterModel, damage, isCrit, died, isComboHit)
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
			showResult(monsterModel, damage, isCrit, died, isComboHit)
			return
		end
		Projectiles.fire(projectileKind, muzzle, targetHead.Position, isCrit, function()
			showResult(monsterModel, damage, isCrit, died, isComboHit)
		end)
	end)
end)
