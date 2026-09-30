-- 공격 입력(클릭/탭 조준 공격, 16-7 → 18-2에서 버튼 제거) + 서버 결과 수신. 사거리·대상·
-- 데미지 판정은 전부 서버가 한다 - 여기는 조준점을 실어 클릭 신호를 보내고 서버가 알려준
-- 결과를 그리기만 한다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local ProjectileConfig = require(ReplicatedStorage.Shared.data.ProjectileConfig)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local WeaponVisual = require(script.Parent.WeaponVisual)
local HitEffects = require(script.Parent.HitEffects)
local Projectiles = require(script.Parent.Projectiles)
local AimTarget = require(script.Parent.AimTarget)
local UIManager = require(script.Parent.UIManager)
local CameraShake = require(script.Parent.CameraShake)
local MovementConfig = require(game:GetService("ReplicatedStorage").Shared.data.MovementConfig) -- A2-N3 보스 타격 FOV 킥 값
local SkillVfx = require(script.Parent.SkillVfx) -- W3c 비장의 한 발 · 어둠 구슬 적중
local VfxData = require(ReplicatedStorage.Shared.data.VfxData)
SkillVfx.watchDealingMode() -- W3c-3 딜링모드 켜는 순간 검보라 소용돌이(모든 플레이어)
local DamageNumbers = require(script.Parent.DamageNumbers)
local MoveRules = require(ReplicatedStorage.Shared.MoveRules)
local AttackMotionData = require(ReplicatedStorage.Shared.data.AttackMotionData)
local AirHover = require(script.Parent.AirHover)
local AttackTrail = require(script.Parent.AttackTrail) -- W2 공격 궤적(무기 발광 대신)
local TrailData = require(ReplicatedStorage.Shared.data.TrailData)
local MotionTiming = require(ReplicatedStorage.Shared.MotionTiming)

-- W2 요청 번호: 서버가 결과 · 발사 알림에 돌려준다 → 원거리는 "그 요청을 보낸 시각 + 서버 발사 지연 + 서버 비행 시간"에 화살이 닿게 그린다.
local requestSeq = 0
-- C3-1: 마지막으로 공격을 낸 시각 - 누를 때 적고, 회전을 거쳐 실제 요청을 보낸 순간 다시 적는다(리뷰 5: 서버가 재는 간격 = 요청 사이 - 회전으로 늦게 나간 요청 다음 타가 서버에서 버려지지 않게)
local lastIntentAt = -math.huge
local pendingShots = {} -- [seq] = { sentAt, index, heavy, close(W2-4 휘두르기 = 투사체 안 그림) }
local lastSwingClose = false
local lastSwingIndex, lastSwingHeavy = 1, false

-- MV1 공중 공격(환생 1회부터 - MovementUnlockData): 한 체공 예산(MoveRules.airAttackBudget = 해금된 공중 점프 + 이번 체공의 공중 대시) 안에서는 공중에서 바로 친다.
-- 예산을 넘거나 해금 전이면 옛 규칙(점프 중 클릭 = 착지 순간 발동하는 버퍼). 판정 · 예산 확정은 서버(AttackServer · AirState) - 여기는 모션 · 요청만.
local airAttacksThisAir = 0

local attackRequest = ReplicatedStorage:WaitForChild("AttackRequest")
local attackResult = ReplicatedStorage:WaitForChild("AttackResult")
-- 20-2b: 발사 즉시 신호 - 원거리 클래스가 투사체 시각을 이 시점부터 재생한다. 실제 피해
-- 판정(맞았는지·얼마나)은 서버가 도달 시점에 계산해 attackResult로 따로 보낸다 - 더 이상
-- 클라이언트가 "이미 정해진 결과"를 늦게 보여주는 게 아니라, 서버 판정 자체가 그 시점에
-- 일어난다(AttackServer.server.lua 참고).
local attackLaunched = ReplicatedStorage:WaitForChild("AttackLaunched")
local comboUpdate = ReplicatedStorage:WaitForChild("ComboUpdate")

local player = Players.LocalPlayer

-- 3타 강타 표시(G1-1 → M1-0 후속): 발밑 고리 → 무기 발광 단계 + 폰 3칸 막대 + 다음 강타 때 조준 외곽선 색(client/ComboGlow). 서버 ComboUpdate를 그대로 넘긴다.
local ComboGlow = require(script.Parent.ComboGlow)
comboUpdate.OnClientEvent:Connect(function(comboCount, isHeavyHit)
	ComboGlow.onCombo(comboCount, isHeavyHit)
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

local function predictIsHeavyHit(isAir)
	local now = os.clock()
	if now - lastPredictedComboTick > CombatConfig.comboResetWindowSeconds then
		predictedComboCount = 0
	end
	predictedComboCount += 1
	lastPredictedComboTick = now
	local heavy = predictedComboCount % CombatConfig.comboHitEvery == 0
	if heavy and isAir and not (MoveRules.tierOf(player)).airHeavy then
		heavy = false -- 공중 3타 강공격은 환생 3회부터(서버와 같은 규칙)
	end
	return heavy
end

local function canAirAttack()
	local character = player.Character
	local budget = MoveRules.airAttackBudget((MoveRules.tierOf(player)), character and character:GetAttribute("AirDashesUsed") or 0)
	return airAttacksThisAir < budget
end

-- 공격 방향 회전(19-2 [1]) - 클릭하면 순간이동하듯 도는 대신, 720도/초로 최단 방향(시계/
-- 반시계 중 가까운 쪽 - CFrame:Lerp의 쿼터니언 보간이 최단 호를 도는 성질을 그대로 써서
-- 180도를 넘게 도는 일이 원천적으로 없다)으로 돌고 회전이 끝나야 공격이 나간다. 몬스터는
-- 계속 움직이므로 각도 임계값(15도) 안이면 회전 없이 즉시 공격한다 - 없으면 몹이 조금
-- 움직일 때마다 미세 회전 딜레이가 붙어 답답해진다(지시 사항).
local TURN_SPEED_RAD_PER_SEC = math.rad(CombatConfig.turnSpeedDegPerSecond)
local TURN_SNAP_THRESHOLD_RAD = math.rad(CombatConfig.turnSnapThresholdDeg)

-- 회전 중 재클릭(다른 방향)은 목표만 갱신한다 - 공격 입력이 큐에 쌓이지 않고 회전이 끝나면
-- 한 번만 때린다(아래 fireAttack). humanoid.AutoRotate를 회전 중엔 꺼 둔다 - 켜 둔 채로
-- 매 프레임 rootPart.CFrame을 덮어쓰면 이동 중일 때 엔진의 자동 이동방향 회전과 매 프레임
-- 서로 되돌리기 경합이 붙는다(이동은 그대로 되어야 하므로 위치는 건드리지 않는다 - 회전
-- 중에도 자유롭게 걸을 수 있다).
local activeRotation = nil -- { targetDir: Vector3(flat, unit), onComplete: function|nil, humanoid: Humanoid }

local function angleBetweenDirs(a, b)
	return math.acos(math.clamp(a:Dot(b), -1, 1))
end

local function flatDir(fromPos, toPos)
	local d = Vector3.new(toPos.X - fromPos.X, 0, toPos.Z - fromPos.Z)
	if d.Magnitude < 0.5 then
		return nil
	end
	return d.Unit
end

local function currentFlatLookDir(rootPart)
	local look = rootPart.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-4 then
		return Vector3.new(0, 0, 1)
	end
	return flat.Unit
end

local function stopRotation()
	if activeRotation and activeRotation.humanoid then
		activeRotation.humanoid.AutoRotate = true
	end
	activeRotation = nil
end

RunService.RenderStepped:Connect(function(dt)
	if not activeRotation then
		return
	end
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		stopRotation()
		return
	end

	local currentDir = currentFlatLookDir(rootPart)
	local targetDir = activeRotation.targetDir
	local remaining = angleBetweenDirs(currentDir, targetDir)
	local maxStep = TURN_SPEED_RAD_PER_SEC * dt

	if remaining <= maxStep then
		rootPart.CFrame = CFrame.new(rootPart.Position, rootPart.Position + targetDir)
		local onComplete = activeRotation.onComplete
		stopRotation()
		if onComplete then
			onComplete()
		end
	else
		local alpha = maxStep / remaining
		local fromCFrame = CFrame.new(rootPart.Position, rootPart.Position + currentDir)
		local toCFrame = CFrame.new(rootPart.Position, rootPart.Position + targetDir)
		rootPart.CFrame = fromCFrame:Lerp(toCFrame, alpha)
	end
end)

-- 점프 중 기본공격 입력 버퍼(19-2 [2]) - 점프 중엔 공격이 나가지 않고 회전만 한다. 착지
-- 순간 CombatConfig.jumpAttackBufferSeconds 안에 눌린 입력만 버퍼되어 발동한다(격투게임
-- 입력 버퍼와 같은 개념 - "눌렀는데 씹혔다"가 아니라 "눌렀는데 늦게 나왔다"로 만드는 게
-- 목적). 여러 번 클릭해도 마지막 클릭 하나만 남는다(매번 덮어쓴다) - 착지 시 한 번만 나간다.
local bufferedJumpAttack = nil -- { aimPoint: Vector3, inputTime: number }

local function isAirborne(humanoid)
	local state = humanoid:GetState()
	return state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping
end

-- 실제 서버 공격 요청 + 스윙 모션 재생(회전 완료 후에만 호출된다). 점프 착지 버퍼(아래)도
-- 같은 함수를 쓴다 - 회전을 거쳤든 착지로 바로 나갔든 공격이 실제로 나가는 지점은 하나뿐이다.
local function performAttack(aimPoint, isAir)
	-- 21-1 [1]-C: 채널링 중(서버가 PlayerState.setChannelingUntil로 올려 둔 Attribute)엔
	-- 요청도 스윙 모션도 내지 않는다 - 서버가 어차피 거부하지만, 모션만 재생되면 "쳤는데
	-- 안 맞는다"는 거짓 피드백이 된다(위 lastSwingTick 주석과 같은 이유). 판정은 서버다.
	if player:GetAttribute("IsChanneling") or player:GetAttribute("BossTrapKind") or player:GetAttribute("BossIntroLock") then -- BR1-4c c-4: 진입 연출 중 입력 잠금
		return -- 29-1: 잡힌 동안에도 같다(서버 BossTrap이 올린 Attribute - 판정은 서버)
	end
	if WeaponVisual.bufferInput(function()
		performAttack(aimPoint, false)
	end) then
		return -- W1: 일어나는 중 = 끝나는 순간 낸다(입력 버퍼)
	end
	requestSeq += 1
	local seq = requestSeq
	attackRequest:FireServer(aimPoint, isAir == true, seq)
	lastIntentAt = math.max(lastIntentAt, os.clock())
	if isAir then
		airAttacksThisAir += 1
		-- MV1 원거리 공중 정지(활 · 지팡이 - AttackMotionData[직업].air.hoverSeconds)
		local motion = AttackMotionData[player:GetAttribute("ClassId") or ""]
		if motion and motion.air and motion.air.hoverSeconds then
			AirHover.hold(motion.air.hoverSeconds)
		end
	end

	local classId = player:GetAttribute("ClassId")
	if not classId or classId == "" then
		return
	end
	-- 신발 공속 보너스(16-6) + 활 속사 버프(20-2b) - 둘 다 서버가 동기화해 둔 Attribute를
	-- 그대로 읽는다(클라이언트가 장비·버프 상태를 따로 계산하지 않는다). 이건 로컬
	-- 예측(스윙 애니메이션을 지금 새로 재생할지)일 뿐 - 실제 쿨다운 판정은 언제나 서버다.
	local cooldown = PlayerCombat.getAttackTempo( -- C3-2: 실제 입력 간격(서버와 같은 함수)
		classId,
		(player:GetAttribute("SpeedPercentBonus") or 0) + (player:GetAttribute("FrenzyAttackBonus") or 0), -- C5-7b 광폭 공속(서버와 같은 합)
		player:GetAttribute("AttackSpeedBuffMultiplier")
	)
	local now = os.clock()
	lastSwingClose = false -- C2 리뷰 3: 이번 요청이 휘두르기를 재생하지 않았으면 투사체를 그린다(지난 휘두르기 값이 남지 않게)
	if now - lastSwingTick >= cooldown then
		lastSwingTick = now
		local heavy = predictIsHeavyHit(isAir)
		lastSwingIndex, lastSwingHeavy = MotionTiming.comboIndex(predictedComboCount), heavy
		lastSwingClose = WeaponVisual.playSwing(heavy, isAir, AimTarget.getCurrentTarget()) -- W2 칼날 리본 = WeaponVisual(동작 구간에만 · 강공격 = 넓게 + 광택) · W2-4 가까운 대상 = 휘두르기
		AttackTrail.debugFire("swing", { at = now, heavy = heavy, index = lastSwingIndex })
	end
	if ProjectileConfig.kindByClass[classId] then
		pendingShots[seq] = { sentAt = now, index = lastSwingIndex, heavy = lastSwingHeavy, close = lastSwingClose, finisher = WeaponVisual.lastSwingFinisher() } -- W3c 비장의 한 발
		if seq - 64 > 0 then
			pendingShots[seq - 64] = nil -- 답이 안 온 요청(헛스윙 · 쿨다운 무시) 정리
		end
	end
end

local function hookJumpLanding(character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.StateChanged:Connect(function(oldState, newState)
		-- MV1: 뜨는 순간 = 강공격 스택 예측 초기화 + 공중 공격 예산 새로(서버 AirState와 같은 규칙 - 요철의 잠깐 Air는 Freefall이 짧아 예측만 흔들린다)
		if (newState == Enum.HumanoidStateType.Jumping or newState == Enum.HumanoidStateType.Freefall)
			and oldState ~= Enum.HumanoidStateType.Jumping and oldState ~= Enum.HumanoidStateType.Freefall then
			predictedComboCount = 0
			airAttacksThisAir = 0
		end
		if newState ~= Enum.HumanoidStateType.Landed then
			return
		end
		local buffered = bufferedJumpAttack
		bufferedJumpAttack = nil
		if not buffered or os.clock() - buffered.inputTime > CombatConfig.jumpAttackBufferSeconds then
			return
		end
		-- 착지 순간 회전이 아직 안 끝났으면 즉시 목표 방향으로 스냅한다 - "착지하는 순간
		-- 버퍼된 공격이 발동한다"는 회전 완료 여부와 무관하다(지시 사항 그대로).
		if activeRotation then
			local rootPart = character:FindFirstChild("HumanoidRootPart")
			if rootPart then
				rootPart.CFrame = CFrame.new(rootPart.Position, rootPart.Position + activeRotation.targetDir)
			end
			stopRotation()
		end
		performAttack(buffered.aimPoint)
	end)
end

player.CharacterAdded:Connect(hookJumpLanding)
if player.Character then
	hookJumpLanding(player.Character)
end

-- 클릭·탭이 이 함수 하나로 모인다(지시 - "지금 누구를 때리려는가를 게임과 유저가 같은
-- 답으로 알게 한다 ... 따로 짜지 마라"). 18-2부터 공격 버튼이 없어져 aimPoint는 항상
-- 클릭·탭 지점으로 넘어온다 - 그 지점으로 캐릭터를 돌리고(즉시가 아니라 위 회전 시스템을
-- 거쳐) AimTarget 하이라이트도 즉시 갱신한다.
local function fireAttack(aimPoint)
	-- 18-1 [3]: gameProcessedEvent만 믿지 않는다 - modal 창이 열려 있으면 여기서 한 번 더
	-- 막는다(딤 배경이 클릭을 못 먹는 경우가 생겨도 이중 방어가 된다).
	if UIManager.isInputBlocked() then
		return
	end
	if player:GetAttribute("IsChanneling") or player:GetAttribute("BossTrapKind") or player:GetAttribute("BossIntroLock") then -- BR1-4c c-4: 진입 연출 중 입력 잠금
		return -- 21-1 [1]-C: 채널링 중엔 회전조차 하지 않는다(돌기만 하고 안 때리면 더 어색하다). 29-1: 잡힘도 같다
	end
	AimTarget.refresh(aimPoint)

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not rootPart or not humanoid or not aimPoint then
		return
	end

	local airborne = isAirborne(humanoid)
	local onComplete = nil
	if airborne and canAirAttack() then
		bufferedJumpAttack = nil -- MV1: 예산 안 = 공중에서 바로(회전을 거쳐)
		onComplete = function()
			performAttack(aimPoint, true)
		end
	elseif airborne then
		bufferedJumpAttack = { aimPoint = aimPoint, inputTime = os.clock() }
	else
		bufferedJumpAttack = nil -- 지상에서 새로 클릭하면 이전 공중 버퍼는 무효
		onComplete = function()
			performAttack(aimPoint)
		end
	end

	local targetDir = flatDir(rootPart.Position, aimPoint)
	if not targetDir then
		if onComplete then
			onComplete()
		end
		return
	end

	-- M1-0 리뷰 1: 시점 고정 중에는 ShiftLock이 매 프레임 루트를 카메라 방위로 되돌려 회전이 끝나지 않는다 - 카메라 방향이 곧 조준이라 돌지 않고 바로 친다
	if player:GetAttribute("ShiftLocked") then
		if onComplete then
			onComplete()
		end
		return
	end

	if activeRotation then
		activeRotation.targetDir = targetDir
		activeRotation.onComplete = onComplete
		activeRotation.humanoid = humanoid
		return
	end

	local currentDir = currentFlatLookDir(rootPart)
	local angle = angleBetweenDirs(currentDir, targetDir)

	if angle <= TURN_SNAP_THRESHOLD_RAD then
		rootPart.CFrame = CFrame.new(rootPart.Position, rootPart.Position + targetDir)
		if onComplete then
			onComplete()
		end
		return
	end

	humanoid.AutoRotate = false
	activeRotation = { targetDir = targetDir, onComplete = onComplete, humanoid = humanoid }
end

-- 클릭·탭한 곳으로 기본공격(16-7 [3], 18-2부터 유일한 공격 수단). gameProcessedEvent가
-- true면 이미 어떤 GuiObject가 이 입력을 먹었다는 뜻(인벤토리·이동 조이스틱 등) - 그때는
-- 공격을 쏘지 않는다.
-- C3-1 꾹 누르기 자동 반복(사용자 확정 - 사람 기준: 누르고 있기 = 연타 = 같은 DPS · 오토클리커 이득 0):
--   좌클릭 · 폰 공격 버튼을 누르고 있으면 공격 간격(PlayerCombat.getAttackTempo)마다 다음 타(3타 콤보 그대로 - 조준은 매번 지금 커서 · 자동 조준).
--   한 번 누름 = 1회. 간격 안에 누르면 버리지 않고 준비되는 순간 1회(누름 버퍼 - 여러 번 눌러도 1회). 서버도 간격(+ 흔들림 여유)으로 막는다.
local heldSource = nil -- "mouse" | "button" (누르고 있는 입력)
local queuedSource = nil -- 간격 안에 누른 1회(준비되면 낸다)

local function currentInterval()
	local classId = player:GetAttribute("ClassId")
	if not classId or classId == "" then
		return CombatConfig.attackTempo.baseIntervalSeconds
	end
	return (PlayerCombat.getAttackTempo(classId, (player:GetAttribute("SpeedPercentBonus") or 0) + (player:GetAttribute("FrenzyAttackBonus") or 0), player:GetAttribute("AttackSpeedBuffMultiplier")))
end

-- C3-4 폰 공격 버튼 조준: 시점 고정(Shift Lock) = 화면 가운데 · 아니면 정면 원뿔(phoneAutoAimDeg) 안 사거리 안 가장 가까운 몹 · 없으면 정면으로 사거리 끝.
local function phoneAimPoint()
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return nil
	end
	local classId = player:GetAttribute("ClassId") or ""
	local range = classId ~= "" and PlayerCombat.getBuffedAttackRange(classId, player:GetAttribute("RangeMultiplier") or 1, player:GetAttribute("WeaponLevel") or 0) or 10
	if player:GetAttribute("ShiftLocked") then
		local viewport = workspace.CurrentCamera.ViewportSize
		return AimTarget.getWorldPointFromScreen(Vector2.new(viewport.X / 2, viewport.Y / 2), ProjectileConfig.kindByClass[classId] and range or nil)
	end
	local look = Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z)
	look = look.Magnitude > 1e-3 and look.Unit or Vector3.new(0, 0, -1)
	local cosLimit = math.cos(math.rad(CombatConfig.rangedAim.phoneAutoAimDeg))
	local best, bestDist = nil, math.huge
	for _, model in ipairs(game:GetService("CollectionService"):GetTagged("Monster")) do
		local root = model.PrimaryPart
		if root and model.Parent then
			local offset = root.Position - rootPart.Position
			local flat = Vector3.new(offset.X, 0, offset.Z)
			local dist = flat.Magnitude
			if dist <= range and dist < bestDist and (dist < 1e-3 or flat.Unit:Dot(look) >= cosLimit) then
				best, bestDist = root, dist
			end
		end
	end
	if best then
		return best.Position
	end
	return rootPart.Position + look * range
end

local function aimPointFor(source)
	if source == "button" then
		return phoneAimPoint()
	end
	local classId = player:GetAttribute("ClassId") or ""
	local ranged = ProjectileConfig.kindByClass[classId] ~= nil
	local range = ranged and PlayerCombat.getBuffedAttackRange(classId, player:GetAttribute("RangeMultiplier") or 1, player:GetAttribute("WeaponLevel") or 0) or nil
	local mouse = UserInputService:GetMouseLocation()
	return AimTarget.getWorldPointFromScreen(Vector2.new(mouse.X, mouse.Y), range) -- C3-4: 원거리 = 허공이면 카메라 방향 사거리 끝(반드시 발사)
end

local function attackNow(source)
	local aimPoint = aimPointFor(source)
	if aimPoint then
		lastIntentAt = os.clock()
		fireAttack(aimPoint)
	end
end

local function press(source)
	if os.clock() - lastIntentAt >= currentInterval() then
		attackNow(source)
	else
		queuedSource = source -- 누름 버퍼(1회)
	end
end

RunService.Heartbeat:Connect(function()
	local source = heldSource or queuedSource
	if source and os.clock() - lastIntentAt >= currentInterval() then
		queuedSource = nil
		attackNow(source)
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		heldSource = "mouse"
		press("mouse")
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 and heldSource == "mouse" then
		heldSource = nil
	end
end)
-- 창이 포커스를 잃으면(알트 탭 등) 뗌 신호가 안 올 수 있다 - 누르고 있기를 푼다
UserInputService.WindowFocusReleased:Connect(function()
	heldSource = nil
	queuedSource = nil
end)

-- C3-1 폰 공격 버튼(SkillSlots가 점프 버튼 옆에 그린다 - 누름 · 뗌 신호)
task.spawn(function()
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("SkillSlotsGui")
	local attackPress = gui:WaitForChild("AttackButtonPress")
	attackPress.Event:Connect(function(down)
		if down then
			heldSource = "button"
			press("button")
		elseif heldSource == "button" then
			heldSource = nil
		end
	end)
end)

UserInputService.TouchTap:Connect(function(touchPositions, gameProcessedEvent)
	if gameProcessedEvent then
		return
	end
	local screenPos = touchPositions[1]
	if not screenPos then
		return
	end
	local classId = player:GetAttribute("ClassId") or ""
	local range = ProjectileConfig.kindByClass[classId] and PlayerCombat.getBuffedAttackRange(classId, player:GetAttribute("RangeMultiplier") or 1, player:GetAttribute("WeaponLevel") or 0) or nil
	local worldPoint = AimTarget.getWorldPointFromScreen(screenPos, range)
	if worldPoint and os.clock() - lastIntentAt >= currentInterval() then -- 화면 탭 = 그 지점으로 1회(간격 안이면 무시 - 누름 버퍼는 버튼 · 클릭만)
		lastIntentAt = os.clock()
		fireAttack(worldPoint)
	end
end)

-- 검증 훅(Studio): 클라 execute_luau → PlayerGui.C3HoldHook:Invoke(action) - "down" · "up"(좌클릭 누름 · 뗌 흉내) · "button_down" · "button_up" · "press"(누름 1회) · "state"
if RunService:IsStudio() then
	local hook = Instance.new("BindableFunction")
	hook.Name = "C3HoldHook"
	hook.OnInvoke = function(action)
		if action == "down" then
			heldSource = "mouse"
			press("mouse")
		elseif action == "up" then
			heldSource = nil
		elseif action == "button_down" then
			heldSource = "button"
			press("button")
		elseif action == "button_up" then
			heldSource = nil
		elseif action == "press" then
			press("mouse")
		end
		return { held = heldSource, queued = queuedSource, interval = currentInterval(), lastIntentAt = lastIntentAt, seq = requestSeq }
	end
	hook.Parent = player:WaitForChild("PlayerGui")
end

-- 3타 강타 적중 피드백(16-7) - "타격감이 이번 작업의 진짜 목표"라는 지시. 히트스톱
-- 0.05~0.12초 범위에서 실기로 맞춰본 값(0.08초 - 근접·원거리 전 클래스에서 "묵직하다"는
-- 느낌과 "다음 입력이 막힌 것 같다"는 불편함 사이의 중간). 카메라 흔들림은 0.15초 안에
-- 완전히 잦아든다(지시 - "과하면 멀미가 난다. 감쇠 속도가 중요하다"). 흔들림 자체의
-- 메커니즘은 20-2a에서 CameraShake.lua로 뽑혀 스킬(SkillInput.client.lua)과 공유한다.
local HEAVY_HITSTOP_SECONDS = 0.08
local CAMERA_SHAKE_SECONDS = 0.15
local CAMERA_SHAKE_STUDS = 0.35

-- 백스텝샷 적용 화살 적중(20-5 [1] - "적중 순간 16-7의 히트스톱을 짧게 적용해라").
-- 3타 강타보다 짧게 잡는다 - 강타와 겹칠 일이 잦은 효과가 아니라 강타의 "묵직함"을
-- 덮어써서는 안 된다(아래 showResult가 강타 쪽을 우선한다 - 두 조건이 겹치면 더 큰
-- 값 하나만 재생하지 더하지 않는다).
local BUFFED_HITSTOP_SECONDS = 0.05
local BUFFED_CAMERA_SHAKE_SECONDS = 0.1
local BUFFED_CAMERA_SHAKE_STUDS = 0.2

-- died가 추가된 이유는 AttackServer.server.lua의 attackResult:FireClient 주석 참고.
-- 죽었으면 피격 반응 대신 사망 연출을 재생한다(둘 다 재생하면 사망 직전 프레임에
-- Body/Head 색을 흰색으로 바꿨다가 곧바로 사망 연출이 그 색을 지워버려 부자연스럽다).
-- isComboHit(16-7)이면 죽었든 아니든 히트스톱·카메라 흔들림은 그대로 재생한다 - 강타가
-- 처치를 낸 순간도 "강타였다"는 느낌은 여전히 필요하다. isBuffedShot(20-5 [1])도 같은
-- 원칙 - 강타와 겹치면 강타 값(더 큰 쪽)만 쓴다.
local finisherShots = {} -- W3c-2 [요청 번호] = { dir } - 비장의 한 발(적중 = 큰 충격 · 긴 히트스톱)
local function showResult(monsterModel, damage, isCrit, died, isComboHit, isBuffedShot, isFinisher)
	DamageNumbers.show(monsterModel, damage, isCrit)

	local holdSeconds = nil
	if isComboHit then
		holdSeconds = HEAVY_HITSTOP_SECONDS
		WeaponVisual.applyHitstop(HEAVY_HITSTOP_SECONDS)
		CameraShake.trigger(CAMERA_SHAKE_SECONDS, CAMERA_SHAKE_STUDS, "heavy") -- 내 3타 강공격만(아주 약하게 · 3초에 1번)
	elseif isFinisher then -- W3c-2: 흔들림은 SkillVfx.bowImpact(적중 충격과 같이)
		holdSeconds = VfxData.bowFinisher.hitstopSeconds
		WeaponVisual.applyHitstop(holdSeconds)
	elseif isBuffedShot then
		holdSeconds = BUFFED_HITSTOP_SECONDS
		WeaponVisual.applyHitstop(BUFFED_HITSTOP_SECONDS)
		-- QUEUE-ALL2 P4 ①: 강화 화살(백스텝샷 충전) 흔들림 없앰 - 강공격 아님(피로 기준)
		local _ = BUFFED_CAMERA_SHAKE_SECONDS + BUFFED_CAMERA_SHAKE_STUDS
	end

	if not monsterModel then
		return
	end
	if died then
		HitEffects.playDeath(monsterModel)
	else
		HitEffects.playHit(monsterModel, isCrit, holdSeconds)
	end
end

-- 20-2b: 원거리(활·힐러) 발사 즉시 신호 - 투사체 시각을 여기서 바로 시작한다. 피해
-- 판정(맞았는지 자체를 포함)은 서버가 도달 시점에 따로 계산해 attackResult로 보낸다 -
-- 이 핸들러는 "쐈다"만 알 뿐 결과를 모른다(그래서 onArrive 콜백이 없다 - 그냥 날아가는
-- 모습만 보여준다). isBuffedShot(20-5 [1]) - 백스텝샷이 적용된 화살이면 Projectiles가
-- 굵고 밝은 변형으로 그린다.
attackLaunched.OnClientEvent:Connect(function(monsterModel, isCrit, isBuffedShot, seq, serverRelease, serverTravel, serverAnchor, isHeavyShot)
	local classId = player:GetAttribute("ClassId")
	local projectileKind = ProjectileConfig.kindByClass[classId]
	if not projectileKind then
		return
	end
	-- W2: 서버 시각표에 맞춘다 - 발사 = 요청 보낸 시각 + 서버 발사 지연 · 도착 = 발사 + 서버 비행 시간.
	--   서버 판정 = (요청이 서버에 닿은 시각) + 같은 두 값 → 화면 도착은 서버 판정보다 올라가는 편도 지연만큼 이르다(결과 · 숫자는 왕복 뒤 - 보고서 W2-3 규칙).
	--   왕복 지연이 발사 지연보다 길면 남은 비행만 그린다(최소 0.03초). 요청 번호를 못 찾으면(유실) 옛 방식(모션 발사 큐 · 거리 ÷ 속도).
	local shot = seq and pendingShots[seq]
	if seq then
		pendingShots[seq] = nil
	end
	local now = os.clock()
	local releaseAt = shot and serverRelease and (shot.sentAt + serverRelease) or (now + WeaponVisual.getReleaseDelay())
	local arriveAt = shot and serverTravel and (releaseAt + serverTravel) or nil
	if shot and shot.close then
		return -- W2-4: 가까운 대상 휘두르기 - 화살 · 구슬 없이 휘두른 무기가 맞힌다(피해 · 판정 시각은 서버 그대로 - 결과 이벤트가 불꽃 · 숫자)
	end
	task.delay(math.max(releaseAt - now, 0), function()
		local targetHead = monsterModel and monsterModel:FindFirstChild("Head")
		local muzzle = WeaponVisual.getMuzzleWorldPosition()
		-- C3-4: 대상 없음(허공 · 벽) = 서버 경로 끝(serverAnchor)으로 날아가 사라진다 - "반드시 발사"
		local toPosition = targetHead and targetHead.Position or serverAnchor
		if not toPosition or not muzzle then
			return -- 발사 시점에 대상이 이미 사라졌다(드문 경우) - 보여줄 화살 자체가 없다.
		end
		local heavy = shot and shot.heavy or false
		local targetRoot = monsterModel and monsterModel.PrimaryPart
		local variant = isHeavyShot and "heavy" or (isBuffedShot and "empowered" or "normal")
		local finisher = isBuffedShot and shot and shot.finisher -- W3c-2 비장의 한 발(E 뒤 첫 발 · 서버 버프가 실제로 붙은 발)
		if finisher then
			variant = "finisher"
			local dir = toPosition - muzzle
			finisherShots[seq] = { dir = dir }
			task.delay(4, function()
				finisherShots[seq] = nil
			end)
			SkillVfx.bowRelease(muzzle, dir, true)
		elseif projectileKind == "orb" and player:GetAttribute("DealingModeActive") then
			variant = "dark" -- W3c-3 딜링모드 어둠 구슬
		end
		Projectiles.fire(projectileKind, muzzle, toPosition, isCrit, variant, function(aim, tracking)
			AttackTrail.debugFire("arrive", { seq = seq, at = os.clock(), aim = aim, tracking = tracking, target = monsterModel, arriveAt = arriveAt })
			if finisher and isHeavyShot then
				SkillVfx.bowStreak(muzzle, aim) -- 관통(강궁 버프 중)이면 경로에 빛줄기
			end
		end, {
			travelSeconds = arriveAt and (arriveAt - os.clock()) or nil,
			style = AttackTrail.tailStyle(player, projectileKind, heavy),
			target = targetHead and monsterModel or nil, anchor = serverAnchor or (targetRoot and targetRoot.Position), tolerance = ProjectileConfig.hitToleranceStuds,
		})
		AttackTrail.debugFire("release", { seq = seq, at = os.clock(), releaseAt = releaseAt, arriveAt = arriveAt, target = monsterModel, muzzle = muzzle })
	end)
end)

-- W2 남의 화살 · 구슬(서버 중계 AttackShotRelay - 궤적 꼬리 스킨이 남에게도 보인다): 받은 순간부터 서버 발사 지연 · 비행 시간 그대로.
ReplicatedStorage:WaitForChild("AttackShotRelay").OnClientEvent:Connect(function(who, monsterModel, serverRelease, serverTravel, comboIndex, isHeavy, serverAnchor, isHeavyShot)
	if typeof(who) ~= "Instance" or who == player then
		return
	end
	local classId = who:GetAttribute("ClassId")
	local kind = ProjectileConfig.kindByClass[classId or ""]
	local hand = who.Character and (who.Character:FindFirstChild("RightHand") or who.Character:FindFirstChild("Right Arm"))
	local mine = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not kind or not hand or not mine or (hand.Position - mine.Position).Magnitude > TrailData.othersDrawStuds then
		return
	end
	task.delay(serverRelease or 0, function()
		local head = monsterModel and monsterModel:FindFirstChild("Head")
		local toPosition = head and head.Position or serverAnchor -- C3-4: 대상 없는 발사도 그린다
		if not toPosition or not hand.Parent then
			return
		end
		local root = monsterModel and monsterModel.PrimaryPart
		local variant = isHeavyShot and "heavy" or ((kind == "orb" and who:GetAttribute("DealingModeActive")) and "dark" or "normal") -- W3c-3 남의 어둠 구슬
		Projectiles.fire(kind, hand.Position, toPosition, false, variant, nil, {
			travelSeconds = serverTravel, style = AttackTrail.tailStyle(who, kind, isHeavy),
			target = head and monsterModel or nil, anchor = serverAnchor or (root and root.Position), tolerance = ProjectileConfig.hitToleranceStuds,
		})
	end)
end)

-- 근접(대검·쌍검)은 즉시 표시, 원거리도 이제 서버가 도달 시점에 맞춰 이 이벤트를
-- 보내주므로 똑같이 즉시 표시한다(더 이상 클라가 따로 늦출 필요가 없다 - 20-2b 이전엔
-- 여기서 투사체 도착을 기다렸지만, 이제 그 기다림 자체를 서버가 이미 하고 왔다).
-- missed(20-2b)면 빗나간 것 - 아무 이펙트도 재생하지 않는다.
attackResult.OnClientEvent:Connect(function(monsterModel, damage, isCrit, died, isComboHit, missed, isBuffedShot, seq, hitPosition)
	AttackTrail.debugFire("result", { seq = seq, at = os.clock(), missed = missed == true, damage = damage, target = monsterModel, hitPosition = hitPosition })
	if missed then
		return
	end
	-- W2 적중 불꽃(서버 적중 지점 · 서버 확정 뒤): 강공격 = 크게 · 투사체 = 작게
	local classId = player:GetAttribute("ClassId")
	if isComboHit then
		AttackTrail.spark(player, hitPosition, TrailData.spark.heavyCount)
	elseif ProjectileConfig.kindByClass[classId or ""] then
		AttackTrail.spark(player, hitPosition, TrailData.spark.projectileCount)
	end
	local fin = seq and finisherShots[seq]
	local at = hitPosition or (monsterModel and monsterModel.PrimaryPart and monsterModel.PrimaryPart.Position)
	if fin and at then
		SkillVfx.bowImpact(at, fin.dir, true) -- W3c-2 큰 충격 · 쏜 방향으로 밀리는 조각(넉백 강조 - 연출만)
	elseif at and ProjectileConfig.kindByClass[classId or ""] == "orb" and player:GetAttribute("DealingModeActive") then
		SkillVfx.darkImpact(at) -- W3c-3 터졌다 → 빨려 듦
	end
	showResult(monsterModel, damage, isCrit, died, isComboHit, isBuffedShot, fin ~= nil)
	if not died and monsterModel and monsterModel:GetAttribute("BossRig") and workspace:GetAttribute("ArtStyleV1") then -- A2-N3 결정 ①: 보스 타격 FOV 킥(설정 "화면 흔들림" 끔 = 없음 · 처치 타격 제외 - 사망 줌이 그 순간 FOV를 기준으로 읽는다)
		local k = MovementConfig.camera.bossHitFovKick
		CameraShake.fovKick(k.degrees, k.seconds)
	end
end)
