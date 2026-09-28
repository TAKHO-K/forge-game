-- 서버 권위 공격 판정. 클라이언트는 "공격하겠다"는 의사 + 조준점(aimPoint, 16-7)만
-- 보낸다 - 사거리 검증·대상 선정·쿨다운 관리·데미지 계산은 전부 여기서만 한다. aimPoint는
-- "어느 방향으로 대상을 고를지"에만 쓰이는 힌트일 뿐(아래 AimPicker.pick), 사거리·데미지·
-- 최종 대상 확정은 클라이언트 값을 그대로 믿지 않고 항상 서버가 다시 계산한다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local AttackMotionData = require(ReplicatedStorage.Shared.data.AttackMotionData)
local ProjectileConfig = require(ReplicatedStorage.Shared.data.ProjectileConfig)
local PrimordialData = require(ReplicatedStorage.Shared.data.PrimordialData)
local SkillData = require(ReplicatedStorage.Shared.data.SkillData) -- C3-2 강궁(heavyShot - 관통)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local AimPicker = require(ReplicatedStorage.Shared.AimPicker)
local ZoneBounds = require(ReplicatedStorage.Shared.ZoneBounds)
local MonsterState = require(script.Parent.MonsterState)
local MonsterSpawner = require(script.Parent.MonsterSpawner)
local PlayerProfile = require(script.Parent.PlayerProfile)
local PlayerState = require(script.Parent.PlayerState)
local CombatResolution = require(script.Parent.CombatResolution)
local BuffState = require(script.Parent.BuffState)
local StuckArrowState = require(script.Parent.StuckArrowState)
local TutorialState = require(script.Parent.TutorialState)
local BossHandlersBR1 = require(script.Parent.BossHandlersBR1) -- BR1-2 투사체 반사
local AirState = require(script.Parent.AirState) -- MV1 공중 공격 예산 · 강공격 스택 초기화
local TranscendentService = require(script.Parent.TranscendentService) -- C5-7
local UltimateService = require(script.Parent.UltimateService) -- K1 궁극기(충전 · 대검 변신 배율 · 충격파)
local MoveRules = require(ReplicatedStorage.Shared.MoveRules)
local MotionTiming = require(ReplicatedStorage.Shared.MotionTiming) -- W1: 원거리 발사 시각 = 모션 타격 프레임(클라와 같은 함수)
local TerrainConfig = require(ReplicatedStorage.Shared.data.TerrainConfig)
local TrailData = require(ReplicatedStorage.Shared.data.TrailData)
local RangedLagAssist = require(script.Parent.RangedLagAssist) -- C4 파트 0: 원거리 보정 반경 = 기본 + 몹 속도 × 편도 지연
local DamageFeed = require(script.Parent.DamageFeed) -- W2-3 서버 확정 피해 방송(프로토타입 - 플래그 꺼짐)
require(script.Parent.TrailSkinService) -- W2 궤적 스킨(Player Attribute TrailSkin - 접속 때 기본값)
local RunService = game:GetService("RunService")

local attackRequest = Instance.new("RemoteEvent")
attackRequest.Name = "AttackRequest"
attackRequest.Parent = ReplicatedStorage

-- damage/isCrit/isDead/isComboHit는 기존 그대로. missed(20-2b, 신규)가 true면 나머지
-- 필드는 의미 없다(전부 0/false로 채워 보낸다) - 원거리 투사체가 도달 시점에 빗나간
-- 경우에만 true다. 근접(대검·쌍검)은 즉시 판정이라 missed가 아예 안 나온다(항상 false).
local attackResult = Instance.new("RemoteEvent")
attackResult.Name = "AttackResult"
attackResult.Parent = ReplicatedStorage

-- 원거리(활·힐러) 발사 즉시 신호 - 클라가 이 시점에 투사체 시각 재생을 시작한다(20-2b [2]).
-- 실제 피해 판정은 attackResult로 따로, 화살/구슬이 도달하는 시점에 온다 - 이 이벤트는
-- "쐈다"만 알린다.
local attackLaunched = Instance.new("RemoteEvent")
attackLaunched.Name = "AttackLaunched"
attackLaunched.Parent = ReplicatedStorage

-- W1 공격 모션 중계(남의 화면 - 무기 · 포즈는 각 클라가 그린다: client/WeaponVisual). 받아들인 공격만 (공격자, 콤보 수, 3타 강공격, 공중)으로 가까운 다른 사람에게.
local attackMotion = Instance.new("RemoteEvent")
attackMotion.Name = "AttackMotion"
attackMotion.Parent = ReplicatedStorage
local MOTION_SEND_STUDS = 220 -- client/WeaponVisual DRAW_RANGE_STUDS와 같게

-- W2 남의 화살 · 구슬(궤적 꼬리 - 스킨이 남에게도 보인다): 받아들여진 원거리 발사만 (공격자, 대상, 발사 지연, 비행 시간, 콤보 순번, 3타 강공격)으로 가까운 다른 사람에게.
local attackShotRelay = Instance.new("RemoteEvent")
attackShotRelay.Name = "AttackShotRelay"
attackShotRelay.Parent = ReplicatedStorage

-- W2-2 판정 표시(/gg hitbox on|off - Player Attribute DebugHitbox): 실제 판정 범위 · 서버가 계산한 투사체 경로 · 적중 지점을 그 사람에게만(client/HitboxDebugView).
local hitboxDebug = Instance.new("RemoteEvent")
hitboxDebug.Name = "HitboxDebug"
hitboxDebug.Parent = ReplicatedStorage
local function debugHitbox(player, info)
	if player:GetAttribute("DebugHitbox") then
		pcall(hitboxDebug.FireClient, hitboxDebug, player, info) -- 표시 실패가 판정 흐름을 끊지 않게(리뷰)
	end
end
-- W2-2 검증(Studio): 서버 판정 순간(os.clock - Studio Play는 서버 · 클라가 한 프로세스)을 Player Attribute로 남긴다 - 클라 궤적 시각과 비교.
local IS_STUDIO = RunService:IsStudio()
local function markJudged(player, seq)
	if IS_STUDIO then
		player:SetAttribute("W2JudgedAt", os.clock())
		player:SetAttribute("W2JudgedSeq", seq or 0)
	end
end

-- 처치 순간 골드 팝업(10-1)용. 골드 자체는 PlayerProfile.addGold가 Attribute로 이미
-- 동기화한다 - 이 이벤트는 "방금 얼마 벌었다"는 일회성 연출 신호만 보낸다.
local goldGained = Instance.new("RemoteEvent")
goldGained.Name = "GoldGained"
goldGained.Parent = ReplicatedStorage

-- 레벨업 알림(13-2)용. characterExp 자체는 PlayerProfile.addCharacterExp가 Attribute로 이미
-- 동기화한다 - 이 이벤트는 레벨이 실제로 오른 순간에만 쏘는 일회성 연출 신호다(매 처치마다
-- 쏘지 않는다 - goldGained와 다르게 레벨업은 드물다).
local levelUp = Instance.new("RemoteEvent")
levelUp.Name = "LevelUp"
levelUp.Parent = ReplicatedStorage

-- 골드/레벨업 팝업은 SkillServer.server.lua와 공유한다(20-2a) - CombatResolution이
-- 죽음 처리 중 이 두 이벤트를 쏜다.
CombatResolution.init(goldGained, levelUp)

local lastAttackTick = {} -- [Player] = os.clock() 시각

-- 3타 강타(16-7, 웹 main.js comboCount/comboResetWindow와 동일 값 CombatConfig 참고).
-- 헛스윙도 콤보에 들어간다 - 웹 performAttack()이 대상 유무와 무관하게 매 공격 입력마다
-- comboCount를 올리는 것과 같다.
local comboCounts = {} -- [Player] = number
local lastComboAttackTick = {} -- [Player] = os.clock() 시각

local comboSession = {} -- [Player] = 마지막으로 콤보를 센 체공 세션 번호(MV1: 뜨는 순간 스택 초기화 - 세션 번호가 바뀌면 0부터)

-- MV1 공중 3타 강공격 반짝임(표시 신호 - 판정 없음): 때린 사람 곁 sendStuds 안의 사람에게.
local airHeavyFx = Instance.new("RemoteEvent")
airHeavyFx.Name = "AirHeavyFx"
airHeavyFx.Parent = ReplicatedStorage
local AIR_FX_SEND_STUDS = 120

local comboUpdate = Instance.new("RemoteEvent")
comboUpdate.Name = "ComboUpdate"
comboUpdate.Parent = ReplicatedStorage

-- D1-2 태초 장갑 고유 연출: 강공격(3타)이 실제로 맞으면 대상 위치에 흰 번개(대상에서 boltSendStuds 안의 사람에게만 - 리뷰 5: 공속 상한 쌍검은 초당 약 5회라 전원 방송은 대역폭 낭비). 판정 · 피해와 무관한 표시 신호.
local primordialGlovesBolt = Instance.new("RemoteEvent")
primordialGlovesBolt.Name = "PrimordialGlovesBolt"
primordialGlovesBolt.Parent = ReplicatedStorage
local function glovesBolt(player, target, isComboHit, dealt)
	if not isComboHit or not dealt or dealt <= 0 or not target.PrimaryPart then
		return
	end
	local gloves = PlayerProfile.getEquipped(player, "gloves")
	if gloves and gloves.grade == "primordial" then
		local position = target.PrimaryPart.Position
		for _, other in ipairs(Players:GetPlayers()) do
			local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
			if root and (root.Position - position).Magnitude <= PrimordialData.unique.glovesBolt.sendStuds then
				primordialGlovesBolt:FireClient(other, position, player)
			end
		end
	end
end

-- 구역 밖 공격 차단 안내(19-4 [4]-나). 조용히 씹으면 버그로 오해한다는 지시 - 스팸
-- 방지로 플레이어당 3초에 한 번만 띄운다(입구에 서서 연타해도 토스트가 겹쳐 뜨지 않게).
local zoneBlockedNotice = Instance.new("RemoteEvent")
zoneBlockedNotice.Name = "ZoneBlockedNotice"
zoneBlockedNotice.Parent = ReplicatedStorage

local ZONE_BLOCKED_NOTICE_THROTTLE_SECONDS = 3
local lastZoneBlockedNoticeAt = {} -- [Player] = os.clock() 시각

local function notifyZoneBlocked(player)
	local now = os.clock()
	local last = lastZoneBlockedNoticeAt[player]
	if last and now - last < ZONE_BLOCKED_NOTICE_THROTTLE_SECONDS then
		return
	end
	lastZoneBlockedNoticeAt[player] = now
	zoneBlockedNotice:FireClient(player, "구역 안으로 들어가야 공격할 수 있습니다")
end

-- C3-2 강궁 넉백(짧게 - SkillData.bow.Q.heavyShot.knockbackStuds): 잡몹만 · 쏜 방향으로 수평 밀기 · 앞이 막혔거나 그 자리 발밑 지면이 없으면 안 민다(MonsterAI는 다음 프레임 지금 자리에서 이어 간다).
local function knockMonster(model, fromPosition, studs)
	local root = model.PrimaryPart
	local data = MonsterState.getData(model)
	if not root or not data or data.isBoss or MonsterState.isChest(model) or MonsterState.isRescueTarget(model) or (studs or 0) <= 0 then
		return
	end
	local flat = Vector3.new(root.Position.X - fromPosition.X, 0, root.Position.Z - fromPosition.Z)
	if flat.Magnitude < 1e-3 then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local excluded = MonsterState.getAllModels() -- 리뷰 6: 다른 몹 · 플레이어는 벽 · 땅이 아니다
	for _, other in ipairs(Players:GetPlayers()) do
		if other.Character then
			table.insert(excluded, other.Character)
		end
	end
	params.FilterDescendantsInstances = excluded
	local dir = flat.Unit
	local offset = dir * studs
	local reach = studs + (data.radiusPx or 12) / 10 + 0.5 -- 몸 반경(px ÷ 10 = stud) 여유
	for _, h in ipairs({ -1.5, 0, 1.5 }) do -- 발 · 몸 · 머리 높이(루트보다 낮은 턱도)
		if Workspace:Raycast(root.Position + Vector3.new(0, h, 0), dir * reach, params) then
			return -- 벽
		end
	end
	local destination = root.Position + offset
	local ground = Workspace:Raycast(destination + Vector3.new(0, 4, 0), Vector3.new(0, -12, 0), params)
	if not ground then
		return -- 낭떠러지
	end
	model:PivotTo(model:GetPivot() + offset)
end

local lastAttackDebug = {} -- [Player] = { status, isAir, isComboHit, combo } - 검증 훅(MV1(나))이 읽는다
local function handleAttack(player, aimPoint, clientAir, clientSeq)
	if require(script.Parent.SoulService).rejectAction(player, "공격") then -- Q8: 영혼 = 공격 불가(서버 거부)
		return
	end
	-- 프로필 로드가 아직 안 끝난 접속 직후, 혹은 클래스를 아직 안 고른 상태에서 공격이
	-- 들어올 수 있다 - 공격력·쿨다운 둘 다 클래스가 있어야 계산할 수 있으니 헛스윙으로
	-- 처리한다(10-3 [3] - 클래스 배율이 실제로 평타에 반영되는 첫 지점).
	local weapon = PlayerProfile.getWeapon(player)
	local classId = PlayerProfile.getClassId(player)
	if not weapon or not classId then
		return
	end

	-- 21-1 [1]-C: 채널링(대검 회전베기 3초·쌍검 난무 1초) 중엔 평타를 받지 않는다 - PRD
	-- 4.3의 "채널링 3초는 평타 시간에서 뺀다"가 명세다. 쿨다운·콤보 카운터도 건드리지
	-- 않는다(요청 자체가 없었던 것과 같다) - 채널링이 끝나면 직전 평타 쿨다운 기준으로
	-- 바로 이어진다(BalanceSim.simulateCombat의 nextAttackTime과 같은 규칙).
	if PlayerState.isChanneling(player) then
		return
	end
	-- 29-1(PRD 20.73 [2-8] A-2): 잡힌 동안엔 평타 요청 자체를 받지 않는다(채널링과 같은 처리).
	if PlayerState.isTrapped(player) then
		return
	end

	-- W2: 요청 번호(클라가 붙인다) - 결과 · 발사 알림에 그대로 돌려줘 클라가 "어느 요청의 결과인가"를 맞춘다(판정에는 안 쓴다)
	local seq = (type(clientSeq) == "number" and clientSeq == clientSeq and math.abs(clientSeq) < 2 ^ 31) and math.floor(clientSeq) or nil
	local now = os.clock()
	local last = lastAttackTick[player]
	-- 신발 공속 보너스(16-6) - 미착용이면 PlayerProfile.getSpeedPercentBonus가 0을 돌려줘
	-- 기존과 똑같이 계산된다. 활 속사(20-2b [1][3]) - 버프가 없으면 BuffState.getValue가
	-- 기본값 1을 돌려줘 역시 기존과 똑같이 계산된다.
	local buffSpeedMultiplier = BuffState.getValue(player, "quickShot", 1)
	-- C3-2 공격 템포: 실제 간격 · 한 타 피해 배율 · 묶음 타 수(PlayerCombat.getAttackTempo - 초당 피해 = 옛 쿨다운식). 연타해도 누르고 있기보다 빨라지지 않는다:
	--   이른 요청은 흔들림 여유(serverGraceSeconds)까지만 받고, 받은 요청의 시각은 max(지금, 지난 시각 + 간격)으로 적는다(평균 빈도 ≤ 1 ÷ 간격).
	-- C5-7b 광폭: 전투 중 공속 +10%(FrenzyAttackBonus - 신발 % 합에 더한다 → 상한 ×2.5 · 최소 간격 · 넘는 몫 피해 환산 규칙 그대로 · 클라 예측과 같은 합).
	local speedBonus = PlayerProfile.getSpeedPercentBonus(player) + (player:GetAttribute("FrenzyAttackBonus") or 0)
	local interval, swingScale, swingHits = PlayerCombat.getAttackTempo(classId, speedBonus, buffSpeedMultiplier)
	swingScale *= PlayerCombat.getFrenzyOverflowDamageScale(PlayerProfile.getSpeedPercentBonus(player), player:GetAttribute("FrenzyAttackBonus")) -- 상한에 막힌 광폭 몫 = 피해
	if last and now - last < interval - CombatConfig.attackTempo.serverGraceSeconds then
		return -- 쿨다운이 안 지났다 - 조용히 무시
	end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	-- MV1 공중 공격: 클라가 공중이라고 보냈거나(clientAir) 서버가 AirState.airSanitySeconds 넘게 공중으로 본 요청 = 공중 공격.
	-- 예산(MoveRules.airAttackBudget - 해금된 공중 점프 + 이번 체공의 공중 대시)을 넘거나 해금 전이면 거부(쿨다운 · 콤보를 건드리지 않는다 - 요청이 없던 것과 같다).
	local session = AirState.session(player)
	local isAir = session ~= nil and (clientAir == true or (now - session.since >= AirState.airSanitySeconds and not AirState.nearGround(player, rootPart)))
	local tier = MoveRules.tierOf(player)
	if isAir then
		if session.airAttacks >= MoveRules.airAttackBudget(tier, session.airDashes) then
			lastAttackDebug[player] = { status = "air_budget", isAir = true }
			return
		end
		session.airAttacks += 1
		AirState.markTakeoff(player)
		-- 파트 0(MV1 결정 9): 원거리 공중 정지(프레야식 - 클라 AirHover)도 스스로 떠 있는 시간 - 서버가 정지 끝 시각을 적어 대공 잡기 체공이 그대로 센다
		local air = AttackMotionData[classId] and AttackMotionData[classId].air
		if air and air.hoverSeconds and clientAir == true then -- 리뷰: 클라가 지상으로 보낸 요청(서버만 공중 - 막 착지)은 클라가 안 멈춘다
			session.hoverUntil = math.max(session.hoverUntil or 0, now) + air.hoverSeconds
		end
	end

	lastAttackTick[player] = last and math.max(now, last + interval) or now -- 헛스윙이어도 쿨다운은 소모한다(C3-2: 여유로 일찍 받은 요청도 간격 자리로)
	-- 19-1: 공격 시도(헛스윙 포함)도 "전투 중"이다 - 자동회복이 싸우는 동안엔 켜지지
	-- 않아야 한다(PlayerRegen.server.lua 주석 참고).
	PlayerState.setLastCombatActionAt(player, now)
	TranscendentService.syncFrenzy(player) -- C5-7b 광폭: 공격 순간 전투 중

	-- 3타 강타 콤보 카운터 - 헛스윙도 포함해 이 시점에서 갱신한다(웹과 동일 지점).
	local lastCombo = lastComboAttackTick[player]
	local sessionNo = AirState.sessionCount(player)
	if not lastCombo or now - lastCombo > CombatConfig.comboResetWindowSeconds or comboSession[player] ~= sessionNo then
		comboCounts[player] = 0 -- MV1: 공중에 뜨는 순간(세션 번호가 바뀌면) 스택 초기화 - 공중에서 다시 쌓고 착지 뒤 지상도 0부터
	end
	comboSession[player] = sessionNo
	comboCounts[player] += 1
	lastComboAttackTick[player] = now
	local isComboHit = comboCounts[player] % CombatConfig.comboHitEvery == 0
	if isAir and isComboHit then
		if tier.airHeavy then
			for _, other in ipairs(Players:GetPlayers()) do -- MV1 공중 3타 = 강공격 + 무기 반짝임(표시)
				local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
				if root and (root.Position - rootPart.Position).Magnitude <= AIR_FX_SEND_STUDS then
					airHeavyFx:FireClient(other, player)
				end
			end
		else
			isComboHit = false -- 공중 3타 강공격은 환생 3회부터(해금 전 공중 3타 = 일반 타격)
		end
	end
	lastAttackDebug[player] = { status = "swing", isAir = isAir, isComboHit = isComboHit, combo = comboCounts[player] }
	comboUpdate:FireClient(player, comboCounts[player], isComboHit)
	-- W1 남의 화면 공격 모션 · C3 0-3(C2 결정 8): 고른 대상도 실어 보낸다 → 남의 화면도 옆 · 뒤 대상으로 돌아서 휘두르기 · 활 · 지팡이 가까운 대상 휘두르기(연출만 - 대상 선정 뒤에 부른다)
	local function relayMotion(motionTarget)
		for _, other in ipairs(Players:GetPlayers()) do
			local root = other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
			if root and (root.Position - rootPart.Position).Magnitude <= MOTION_SEND_STUDS then
				attackMotion:FireClient(other, player, comboCounts[player], isComboHit, isAir, motionTarget)
			end
		end
	end

	-- aimPoint는 클릭·탭한 지점(AttackInput.client.lua) - 서버 검증: Vector3가 아니면
	-- 무시한다(지시 - "클라가 보낸 방향을 그대로 믿으면 안 된다"). 방향이 없거나 이상한
	-- 값이면 AimPicker가 사거리 안 최근접으로 대체하므로 안전하게 실패한다. 사거리·데미지는
	-- 이 값과 무관하게 아래에서 항상 서버가 다시 계산한다.
	local safeAimPoint = typeof(aimPoint) == "Vector3" and aimPoint or nil
	-- 활 백스텝샷 사거리 버프(20-4 [2]) - 충전이 남아 있는 동안(BuffState.getField가 만료·
	-- 소진된 버프는 자동으로 기본값 1을 돌려준다) 대상 판정 사거리를 넓힌다. 실제 상한은
	-- PlayerCombat.getBuffedAttackRange가 어그로 범위 아래로 자른다(주석 참고).
	local rangeMultiplier = BuffState.getField(player, "backstepShotBuff", "rangeMultiplier", 1)
	-- 강화 단계(+15 · +20)의 사거리 보너스(30-0 S08)도 같은 함수가 곱한다 - 클라 조준(AimTarget)은 WeaponLevel Attribute로 같은 값을 넘긴다.
	local attackRange = PlayerCombat.getBuffedAttackRange(classId, rangeMultiplier, weapon.level)
	-- MV1: 공중 공격은 아래 대상까지(CombatConfig.airAttack - 근접 · 원거리 높이차 상한)
	local projectileKind = ProjectileConfig.kindByClass[classId]
	local target, pathTargets, pathEnd, heavyShot = nil, nil, nil, nil
	local shotOrigin = rootPart.Position + Vector3.new(0, CombatConfig.rangedAim.muzzleUpStuds, 0)
	if projectileKind then
		-- C3-4 원거리 = 클릭 지점으로 발사: 서버 원점(루트 + 가슴 높이) → 조준점 직선 위 첫 몹(강궁 = 관통 수만큼 더) · 없으면 조준점 둘레 작은 반경만 보정 · 아무도 없어도 발사.
		--   방향 검증: 조준점이 NaN이거나 원점에서 너무 먼 값이면 무시(바라보는 방향으로) - 원점 · 사거리 · 판정은 서버 값만 쓴다.
		if safeAimPoint and (safeAimPoint ~= safeAimPoint or (safeAimPoint - rootPart.Position).Magnitude > 2000) then
			safeAimPoint = nil
		end
		local skill = BuffState.get(player, "quickShot") ~= nil and SkillData[classId] and SkillData[classId].Q
		heavyShot = skill and skill.heavyShot or nil
		pathTargets, pathEnd = AimPicker.pickPath(shotOrigin, safeAimPoint, attackRange, MonsterState.getAllModels(), rootPart.CFrame.LookVector, 1 + (heavyShot and heavyShot.pierce or 0), RangedLagAssist.extraFor(player))
		target = pathTargets[1]
		relayMotion(target)
		if player:GetAttribute("DebugHitbox") then -- W2-2 판정 표시: 화살 경로(원점 → 끝 · 몸 반경) · 고른 대상
			debugHitbox(player, { kind = "path", origin = shotOrigin, pathEnd = pathEnd, radius = CombatConfig.rangedAim.bodyRadiusStuds,
				target = target and target.PrimaryPart and target.PrimaryPart.Position or nil, seq = seq })
		end
	else
		local layer = isAir and CombatConfig.airAttack.meleeLayerStuds or nil
		target = AimPicker.pick(rootPart.Position, safeAimPoint, attackRange, MonsterState.getAllModels(), layer)
		relayMotion(target)
		if player:GetAttribute("DebugHitbox") then -- W2-2 판정 표시: 사거리 원(AimPicker = 원 안 1명) · 높이 허용 · 고른 대상
			debugHitbox(player, { kind = "range", origin = rootPart.Position, range = attackRange, layer = layer or TerrainConfig.heightToleranceStuds,
				target = target and target.PrimaryPart and target.PrimaryPart.Position or nil, seq = seq })
		end
		if not target then
			markJudged(player, seq)
			return -- 사거리 안에 몬스터가 없다 - 헛스윙
		end
	end

	-- 구역 밖 공격 차단(19-4 [4]-나) - 담장(HuntingGround.server.lua)이 1차 방어, 이건
	-- 뚫렸을 때의 2차 방어이자 "입구에 서서 안쪽을 쏘는" 행위 자체를 막는 장치다. 클라이언트
	-- 좌표가 아니라 서버가 들고 있는 rootPart.Position으로 판정한다.
	if target and not ZoneBounds.isInside(rootPart.Position, MonsterState.getZoneKey(target)) then
		notifyZoneBlocked(player)
		return
	end

	-- 공격력 = 무기 기본값 × 강화 배율 × 등급 배율 × 클래스 배율 × 캐릭터 레벨계수(10-2 [1],
	-- 10-3 [3], 13-2에서 레벨계수가 들어갔다) × (1+장갑 공격력%, 16-6) × 3타 강타 배율(16-7,
	-- 웹 main.js "attack = getPlayerAttack() * (isComboHit ? comboHitMultiplier : 1)"과 같은
	-- 순서 - 치명타 판정보다 먼저 곱한다). 배율이 곱해지는 지점은 PlayerCombat 하나뿐이다.
	-- 치명타(10-4)는 이 base를 calcDamage에 넘겨서 판정한다 - 판정도 서버 여기 한 곳뿐이다.
	-- 치명타 롤 자체는 여기서(발사 시점) 미리 정한다 - 원거리 투사체 색(화살/구슬)이 발사
	-- 즉시 정해져야 클라가 "맞을지 미리 안다"는 위화감 없이 보인다(Projectiles.lua 원본
	-- 주석과 같은 이유). 실제로 맞는지(도달 시점 재검증)는 아래에서 따로 판단한다.
	local characterLevel = PlayerProfile.getCharacterLevel(player)
	local atk = PlayerCombat.getAttack(weapon, classId, characterLevel, PlayerProfile.getAttackPercentBonus(player), PlayerProfile.getOptionBonus(player, "finalDamage"), PlayerProfile.getMilestoneMultiplier(player), PlayerProfile.getDealItemLevels(player)) -- C5-1 딜 부위 itemLevel 지수 -- P2.5a R5: 최종 데미지 버킷 · P2.5b D: 마일스톤 영구 배율
	local base = atk * swingScale -- C3-2 한 타 피해 배율(느린 간격 · 넘는 공속 · 강궁 = 한 방이 커진다 - 초당 피해 불변)
	if isComboHit then
		base *= CombatConfig.comboHitMultiplier
	end

	-- 딜링모드(힐러 E, 20-6 [6], PRD 4.3 "평타 배율을 딜로 환산") - 버프가 없으면
	-- BuffState.getField가 기본값 1을 돌려줘 다른 3직업은 기존과 완전히 동일하게 계산된다.
	local dealingFactor = BuffState.getField(player, "dealingMode", "attackMultiplier", 1) -- C5-7b: 환영 추가타도 같은 값을 쓴다
		-- P2.5a D(결정 8): 딜링모드의 투자 기울기(강화 · 위력% 투자가 클수록 배율이 딜러보다 가파르게 큰다 - PlayerCombat.getInvestmentScale).
		* PlayerCombat.getInvestmentScale(weapon.level, PlayerProfile.getAttackPercentBonus(player), BuffState.getField(player, "dealingMode", "investmentScaling", nil))
	base *= dealingFactor

	-- 활 백스텝샷(20-2b [1][4], PRD-forge-game.md 4.3) - "다음 평타 5발에 마법피해 추가 +
	-- 그 5발 치명타 확률 +30%p". 버프가 없으면 두 값 다 0이라 기존과 똑같이 계산된다.
	-- 이 평타 하나에 실제로 적용된 순간에만 충전을 소모한다(맞았는지와 무관 - 쐈다는
	-- 사실 자체가 소모 조건이다, 근접도 같은 지점이라 대검/쌍검에 이 버프가 걸릴 일이
	-- 생기면 자동으로 똑같이 동작한다).
	local bonusDamageCoefficient = BuffState.getField(player, "backstepShotBuff", "damageCoefficient", 0)
	local buffCritRateBonus = BuffState.getField(player, "backstepShotBuff", "critRateBonus", 0)
	if bonusDamageCoefficient > 0 or buffCritRateBonus > 0 then
		base += bonusDamageCoefficient * atk / swingHits -- C3-2: 발당 고정(한 타 배율 밖 - 5발 총량 불변)
		BuffState.consumeCharge(player, "backstepShotBuff")
	end

	-- 쌍검 Q 확정 치명타(20-6, PRD 4.3 "5초간 기본공격 확정 치명타") - 평타 경로도 스킬
	-- 경로(SkillServer.server.lua)와 같은 PlayerCombat.resolveGuaranteedCrit을 공유한다.
	-- 26-2(PRD 20.67 [14] 4단계 "치명"): 장비·보석 치명 옵션 합(optionCritRate/optionCritDmg)을
	-- 버프 치확과 더해서 넘긴다 - 버프 소비 판정(위)은 옵션과 무관하게 버프 값만 본다(옵션이
	-- 있다고 백스텝샷 충전을 대신 태우면 안 된다).
	local optionCritRate, optionCritDmg = PlayerProfile.getCritBonus(player)
	local critRateBonus = buffCritRateBonus + optionCritRate
	local shadowMark = BuffState.get(player, "shadowMark") -- K2 쌍검 암영 표식: 표식 대상에게 치명 +20%p(넘는 몫 = 기존 오버치명)
	if shadowMark and target and shadowMark.target == target then
		critRateBonus += shadowMark.critRateBonus
	end
	local isGuaranteedCritActive = BuffState.get(player, "guaranteedCrit") ~= nil
	local forceCrit, guaranteedCritDmgBonus = PlayerCombat.resolveGuaranteedCrit(classId, isGuaranteedCritActive, critRateBonus)
	local critDmgBonus = guaranteedCritDmgBonus + optionCritDmg

	local damage, isCrit = PlayerCombat.calcDamage(base, classId, critRateBonus, forceCrit, critDmgBonus)
	-- 힐러 버프(24-3, PRD 20.64) - SkillServer.strikeTarget과 같은 지점(calcDamage 직후,
	-- "최종 피해") - 이 아래로는 배율 계산이 없다. 버프 없으면 getField 기본값 1로 무동작.
	damage *= BuffState.getField(player, "healerBuff", "multiplier", 1)
	damage *= UltimateService.damageMultiplier(player) -- K1 대검 파괴의 화신
	damage *= BuffState.getField(player, "warcryBuff", "multiplier", 1) -- K2 대검 전장의 포효(파티 공격력 +10%)
	-- 23-1: 견습 중이면 무한 stage 대신 그 단계의 잡몹 stage를 쓴다(TutorialState.getMonsterStage).
	local attackerStage = TutorialState.getMonsterStage(player)

	-- 20-5 [1] 시각 구분용 - 백스텝샷이 이 평타에 실제로 적용됐는가("스킬이다"가 한눈에
	-- 읽혀야 한다는 지시, Projectiles.lua/AttackInput.client.lua가 이 값으로 화살을
	-- 굵고 밝게 그리고 적중 히트스톱을 준다).
	local isBuffedShot = bonusDamageCoefficient > 0 or buffCritRateBonus > 0
	-- 20-5 [2] 꽂히는 화살 - 이 평타를 "쏜 시점"에 속사가 켜져 있었는가(지시 원문 "속사
	-- 버프가 켜져 있는 동안 발사한 평타"). 도달까지 걸리는 시간 동안 버프가 꺼져도 이미
	-- 쏜 화살의 성격은 바뀌지 않는다 - 백스텝샷 충전 소모와 같은 "쏘는 시점 스냅샷" 원칙.
	-- requestedAt(실기 검증 중 발견) - 이 시점과 attach() 호출 시점(도달 후) 사이에
	-- 플레이어가 퇴장·직업변경하면 StuckArrowState.clearForPlayer가 이미 지나간 이
	-- 요청을 걸러낸다(StuckArrowState.lua clearedAt 주석 참고).
	local wasQuickShotActive = BuffState.get(player, "quickShot") ~= nil
	local requestedAt = os.clock()

	local healerBuff = BuffState.getField(player, "healerBuff", "multiplier", 1) * UltimateService.damageMultiplier(player) * BuffState.getField(player, "warcryBuff", "multiplier", 1) -- K1 · K2: 묶음 둘째 타 · 관통 뒤 대상도 같은 최종 배율
	-- C5-7b 환영(초월 장갑): 기본 공격이 대상에 들어간 뒤 요청 1회당 한 번 굴린다(서버) → 같은 대상에 추가타 1회 = 기본 공격 피해 1회분(한 타 배율 · 딜링모드 · 치명 · 힐러 버프 · 3타 배율 제외).
	--   환영 추가타 heavyEvery번째 = 강공격(3타 배율 · 강공격 연출). 보스 포함(applyDamage가 파훼 게이트 · 보호막을 그대로 적용). 흡혈 · 태초 번개 · 비상 초기화는 안 건다(플레이어 본인의 타격만).
	local phantomRolled = false
	local function phantomStrike(phantomTarget)
		if phantomRolled or not phantomTarget.Parent or not MonsterState.getData(phantomTarget) then
			return
		end
		phantomRolled = true
		local isHeavy = TranscendentService.rollPhantom(player)
		if isHeavy == nil then
			return
		end
		local phantomBase = atk * swingScale * dealingFactor * (isHeavy and CombatConfig.comboHitMultiplier or 1)
		local phantomDamage, phantomCrit = PlayerCombat.calcDamage(phantomBase, classId, critRateBonus, forceCrit, critDmgBonus)
		phantomDamage *= healerBuff
		local position = phantomTarget.PrimaryPart and phantomTarget.PrimaryPart.Position
		local isDead, dealt = MonsterState.applyDamage(phantomTarget, phantomDamage, attackerStage, player)
		MonsterSpawner.updateHpLabel(phantomTarget)
		attackResult:FireClient(player, phantomTarget, dealt, phantomCrit, isDead, isHeavy, false, false, nil, position)
		DamageFeed.emit(phantomTarget, position, dealt, DamageFeed.kindOf(isHeavy), player, phantomCrit)
		CombatResolution.resolveHit(player, phantomTarget, isDead)
		if position then
			TranscendentService.firePhantomFx(player, position, isHeavy)
		end
		if lastAttackDebug[player] then
			lastAttackDebug[player].phantom = { heavy = isHeavy, dealt = dealt }
		end
	end
	if not projectileKind then
		-- 근접(대검·쌍검) - 즉시 판정(기존 동작 그대로, 20-2a까지와 완전히 같다).
		-- C3-2: 쌍검 = 한 번의 입력 = 두 칼 묶음(swingHits타 - 같은 대상 · 타마다 치명 굴림 · 콤보는 한 번 셌다).
		-- 29-1: applyDamage의 둘째 반환값 = 실제로 들어간 피해(보스 파훼 게이트 ×g 반영). 숫자·흡혈이 이 값을 쓴다.
		for hitIndex = 1, swingHits do
			local hitDamage, hitCrit = damage, isCrit
			if hitIndex > 1 then
				hitDamage, hitCrit = PlayerCombat.calcDamage(base, classId, critRateBonus, forceCrit, critDmgBonus)
				hitDamage *= healerBuff
			end
			local hitPosition = target.PrimaryPart and target.PrimaryPart.Position -- W2: 서버 적중 지점(피해 숫자 · 이펙트 자리)
			local isDead, dealt = MonsterState.applyDamage(target, hitDamage, attackerStage, player)
			markJudged(player, seq)
			MonsterSpawner.updateHpLabel(target)
			-- 흡혈(26-2, PRD 20.67 [6-1]) - 실제로 데미지가 몬스터에게 들어간 직후에만 회복한다
			-- (여기·아래 원거리 도달 판정 두 곳 - "damage 확정"을 "실제로 맞았다"로 해석했다,
			-- 원거리가 빗나가는 경우까지 회복시키면 안 되므로).
			PlayerProfile.applyLifesteal(player, dealt)
			glovesBolt(player, target, isComboHit, dealt)
			UltimateService.onDealt(player, classId, atk > 0 and dealt / atk or 0, dealt, hitCrit, hitPosition and (hitPosition - rootPart.Position).Magnitude or 0, target) -- K1 충전
			if hitIndex == 1 then
				UltimateService.onBasicHit(player, classId, rootPart, target) -- K1 대검 변신 충격파
			end
			if isComboHit and dealt > 0 then -- C5-7b 비상: 공중 강공격 적중 → 공중 행동 초기화
				TranscendentService.onHeavyHit(player, isAir)
			end
			attackResult:FireClient(player, target, dealt, hitCrit, isDead, isComboHit, false, isBuffedShot, seq, hitPosition)
			DamageFeed.emit(target, hitPosition, dealt, DamageFeed.kindOf(isComboHit), player, hitCrit)
			CombatResolution.resolveHit(player, target, isDead)
			if isDead or not MonsterState.getData(target) then
				break
			end
			if hitIndex == swingHits and dealt > 0 then
				phantomStrike(target) -- C5-7b 환영(묶음 타가 다 들어간 뒤 한 번)
			end
		end
		return
	end

	-- 원거리(활·힐러, 20-2b [2]) - "클라가 맞았다고 보고하는 구조로 만들지 마라"는 지시대로 서버가 도달 시점을 직접 계산해 그때 판정한다.
	-- C3-4: 경로(원점 → 조준점) 위 대상들(pathTargets - 강궁 관통이면 여러 명) · 아무도 없으면 경로 끝으로 헛발사(투사체는 그린다 - "허공 클릭에도 반드시 발사").
	-- 벽 차단(20-2b [2]): 담장 · 지형이 경로를 막으면 그 앞 대상만 맞고 화살은 벽에서 멈춘다(플레이어 자신 · 다른 플레이어 · 살아있는 몬스터는 막지 않는다 - W2 결정 5).
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	local excluded = { character }
	for _, other in ipairs(Players:GetPlayers()) do
		if other.Character and other.Character ~= character then
			table.insert(excluded, other.Character)
		end
	end
	for _, model in ipairs(MonsterState.getAllModels()) do
		table.insert(excluded, model)
	end
	raycastParams.FilterDescendantsInstances = excluded
	local wallHit = Workspace:Raycast(shotOrigin, pathEnd - shotOrigin, raycastParams)
	if wallHit then
		pathEnd = wallHit.Position -- 헛발사 화살이 멈추는 자리(대상 판정은 아래 대상마다)
	end

	-- W1: 발사 시각 = 모션 타격 프레임(MotionTiming - 클라 WeaponVisual과 같은 함수) · W2: 발사 지연 · 비행 시간을 같이 보내 클라가 서버 도달 시각에 닿게 그린다.
	local motionSpeed = PlayerCombat.getMotionSpeed(classId, speedBonus, buffSpeedMultiplier)
	local releaseDelay = MotionTiming.serverSeconds(classId, MotionTiming.comboIndex(comboCounts[player]), motionSpeed, isComboHit, isAir)
	local speed = ProjectileConfig.speedStudsPerSec[projectileKind]
	local comboIndex = MotionTiming.comboIndex(comboCounts[player])
	local heavyFlag = heavyShot ~= nil -- C3-2 강궁: 큰 화살 · 넉백 연출(클라)

	-- 대상마다 시야 검사(리뷰 1 · 2): 원점 → 그 몹 몸 중심 레이가 담장 · 지형에 먼저 막히면 제외(땅을 클릭해도 몹 발밑 땅이 몹을 가리지 않는다 · 얇은 벽 너머 보정 대상은 막힌다).
	--   관통 뒤 대상도 공격자 구역 규칙을 따른다.
	local hitsToApply = {}
	for _, pathTarget in ipairs(pathTargets) do
		local root = pathTarget.PrimaryPart
		local position = root and root.Position
		local distance = position and (position - shotOrigin).Magnitude or 0
		if position and distance > 0 and ZoneBounds.isInside(rootPart.Position, MonsterState.getZoneKey(pathTarget)) then
			local blocked = Workspace:Raycast(shotOrigin, position - shotOrigin, raycastParams)
			if not blocked or blocked.Distance >= distance - 1 then
				table.insert(hitsToApply, { target = pathTarget, launchPosition = position, distance = distance })
			end
		end
	end
	local first = hitsToApply[1]
	-- 클라 투사체 = 첫 대상(없으면 경로 끝 - 강궁 관통은 뒤 대상의 결과 이벤트로 보인다)
	local launchTarget = first and first.target or nil
	local launchAnchor = first and first.launchPosition or pathEnd
	local travelTime = (first and first.distance or (pathEnd - shotOrigin).Magnitude) / speed
	attackLaunched:FireClient(player, launchTarget, isCrit, isBuffedShot, seq, releaseDelay, travelTime, launchAnchor, heavyFlag)
	for _, other in ipairs(Players:GetPlayers()) do -- W2 남의 화면 투사체(궤적 꼬리) - 받는 쪽이 그리는 거리(TrailData.othersDrawStuds) 안만
		local root = other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - rootPart.Position).Magnitude <= TrailData.othersDrawStuds then
			attackShotRelay:FireClient(other, player, launchTarget, releaseDelay, travelTime, comboIndex, isComboHit, launchAnchor, heavyFlag)
		end
	end
	if not first then
		markJudged(player, seq)
		lastAttackDebug[player].shot = { hit = false, pathEnd = pathEnd }
		return -- 허공 · 벽 = 헛발사(피해 없음)
	end
	lastAttackDebug[player].shot = { hit = true, target = first.target, count = #hitsToApply, pathEnd = pathEnd }
	local originAtLaunch = rootPart.Position

	for hitIndex, hit in ipairs(hitsToApply) do
		local hitTarget, launchPosition = hit.target, hit.launchPosition
		task.delay(releaseDelay + hit.distance / speed, function()
			-- 도달 시점 재검증. 몬스터가 이미 없어졌으면(다른 공격자가 먼저 죽였거나 despawn)
			-- MonsterState.getData가 nil을 돌려준다 - 조용히 빗나간다.
			local currentRoot = hitTarget.Parent and hitTarget.PrimaryPart
			if not currentRoot or not MonsterState.getData(hitTarget) then
				attackResult:FireClient(player, hitTarget, 0, false, false, isComboHit, true, isBuffedShot, seq, nil)
				markJudged(player, seq)
				return
			end
			if player:GetAttribute("DebugHitbox") then -- W2-2: 서버가 계산한 경로(발사 자리 → 발사 순간 대상 자리) · 도달 순간 대상 자리 · 허용 폭
				debugHitbox(player, { kind = "projectile", origin = originAtLaunch, launch = launchPosition, arrive = currentRoot.Position, tolerance = ProjectileConfig.hitToleranceStuds,
					hit = (currentRoot.Position - launchPosition).Magnitude <= ProjectileConfig.hitToleranceStuds, seq = seq })
			end

			-- 비행 중 이동한 거리가 허용 폭(ProjectileConfig.hitToleranceStuds)을 넘으면
			-- 빗나간다 - "몬스터가 움직이므로 빗나갈 수 있다"는 지시를 그대로 구현한다.
			if (currentRoot.Position - launchPosition).Magnitude > ProjectileConfig.hitToleranceStuds then
				attackResult:FireClient(player, hitTarget, 0, false, false, isComboHit, true, isBuffedShot, seq, nil)
				markJudged(player, seq)
				return
			end

			-- BR1-2 투사체 반사: 보스가 반사 중이면 피해 0 + 쏜 사람 쪽으로 되돌린다(BossHandlersBR1.tryReflect - 근접 분기는 위에서 이미 끝났다)
			if MonsterState.getData(hitTarget).isBoss and BossHandlersBR1.tryReflect(hitTarget, player) then
				attackResult:FireClient(player, hitTarget, 0, false, false, isComboHit, true, isBuffedShot, seq, nil)
				markJudged(player, seq)
				return
			end
			-- 29-3: 이 투사체를 "쏜" 시각을 같이 넘긴다 - 보스의 반사 태세는 태세가 선 뒤에 쏜 것만 반사한다(이미 날아가던
			-- 화살·구슬은 0 피해로 끝날 뿐이다, BossMechanics.beginReflect).
			local hitDamage, hitCrit = damage, isCrit
			if hitIndex > 1 then -- 관통 뒤 대상 = 타마다 치명 굴림
				hitDamage, hitCrit = PlayerCombat.calcDamage(base, classId, critRateBonus, forceCrit, critDmgBonus)
				hitDamage *= healerBuff
			end
			local hitPosition = currentRoot.Position -- W2: 서버 적중 지점(도달 순간 대상 자리)
			local isDead, dealt = MonsterState.applyDamage(hitTarget, hitDamage, attackerStage, player, { committedAt = requestedAt }) -- 29-1: 위 근접 분기와 같다
			markJudged(player, seq)
			MonsterSpawner.updateHpLabel(hitTarget)
			PlayerProfile.applyLifesteal(player, dealt) -- 26-2, 위 근접 분기와 같은 지점(실제 명중 후)
			glovesBolt(player, hitTarget, isComboHit, dealt)
			local shooterRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			UltimateService.onDealt(player, classId, atk > 0 and dealt / atk or 0, dealt, hitCrit, shooterRoot and (hitPosition - shooterRoot.Position).Magnitude or 0, hitTarget) -- K1 충전(원거리 도달 - 먼 적중 가중)
			attackResult:FireClient(player, hitTarget, dealt, hitCrit, isDead, isComboHit, false, isBuffedShot, seq, hitPosition, heavyFlag)
			DamageFeed.emit(hitTarget, hitPosition, dealt, DamageFeed.kindOf(isComboHit), player, hitCrit)
			CombatResolution.resolveHit(player, hitTarget, isDead)
			if isComboHit and dealt > 0 then -- C5-7b 비상(원거리 도달 - 근접 분기와 같은 조건)
				TranscendentService.onHeavyHit(player, isAir)
			end
			if hitIndex == 1 and not isDead and dealt > 0 then
				phantomStrike(hitTarget) -- C5-7b 환영(첫 대상 · 도달 순간 즉시 - 근접 규칙)
			end
			if heavyShot and not isDead and dealt > 0 and hitTarget.Parent then
				knockMonster(hitTarget, originAtLaunch, heavyShot.knockbackStuds) -- C3-2 강궁 짧은 넉백
			end

			-- 꽂히는 화살(20-5 [2]) - 활 전용(ProjectileConfig.kindByClass가 "arrow"인
			-- 클래스만 - 힐러 "orb"는 대상이 아니다), 강궁(옛 속사)이 켜진 채로 쏜 평타가 실제로
			-- 명중했을 때만 남는다. 이 평타 자체가 처치를 냈으면(isDead) 붙이지 않는다 -
			-- CombatResolution.resolveHit이 바로 위에서 despawn까지 끝낸 대상이라, 화살을
			-- 붙여도 의미 있는 폭발 없이 시체와 함께 사라질 뿐이다.
			-- 보물상자(22-2 [3])에는 화살이 안 꽂힌다 - 피해량이 무관한 대상에 지연 폭발을 남기면
			-- "1초 간격" 규칙만 우회하는 셈이 된다. C3-2: 화살 피해 = 공격력 × 한 타 배율(한 발이 커진 만큼 - BalanceSim과 같다).
			if not isDead and dealt > 0 and wasQuickShotActive and projectileKind == "arrow" and not MonsterState.isChest(hitTarget) and not MonsterState.isRescueTarget(hitTarget) then -- C1 리뷰 5: 막힌 타격(피해 0)엔 안 꽂힌다
				local hitDirection = Vector3.new(currentRoot.Position.X - rootPart.Position.X, 0, currentRoot.Position.Z - rootPart.Position.Z)
				hitDirection = hitDirection.Magnitude > 1e-3 and hitDirection.Unit or Vector3.new(0, 0, 1)
				StuckArrowState.attach(hitTarget, player, atk * swingScale, classId, attackerStage, hitDirection, requestedAt)
			end
		end)
	end
end

attackRequest.OnServerEvent:Connect(handleAttack)
if game:GetService("RunService"):IsStudio() then -- 검증 훅(MV1(나)): 실제 요청과 같은 판정 → 마지막 판정 기록
	local hook = Instance.new("BindableFunction")
	hook.Name = "AttackHook"
	hook.OnInvoke = function(player, aimPoint, clientAir)
		lastAttackDebug[player] = { status = "ignored" }
		handleAttack(player, aimPoint, clientAir)
		return lastAttackDebug[player]
	end
	hook.Parent = game:GetService("ServerStorage")
end

Players.PlayerRemoving:Connect(function(player)
	lastAttackTick[player] = nil
	lastAttackDebug[player] = nil
	comboCounts[player] = nil
	lastComboAttackTick[player] = nil
	comboSession[player] = nil
	lastZoneBlockedNoticeAt[player] = nil
	-- 아직 살아있는 몬스터의 기여 기록에 이 플레이어가 남아있으면(퇴장 시점에 전투 중이었던
	-- 경우) 몬스터가 죽을 때까지 계속 남는다 - 떠나는 쪽이 자기 흔적을 지운다(MonsterAI.
	-- server.lua의 releaseChasersOf와 같은 원칙, 19-4 지시 - 이전 nil 비교 사고 반복 금지).
	MonsterState.clearPlayerContributions(player)
	-- 꽂히는 화살(20-5 [2]) - 퇴장 시점에 아직 안 터진 화살이 남아있으면 대상 몬스터가
	-- 살아있는 한 계속 남는다(BuffState.clearAll과 같은 이유로 명시 정리가 필요하다).
	StuckArrowState.clearForPlayer(player)
end)
