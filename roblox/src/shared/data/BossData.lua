-- 무한 모드 보스 데이터(15-1 → 23-5 6종 → 29-2 보스별 독립 스킬표). PRD-forge-game-roblox.md 20.75.
--
-- 29-2 재편: 보스마다 자기 스킬표(skills)·기본 공격·체격·이동 속도·전역 쿨을 갖는다. 23-6의 "주력 빈도
-- ×2 / 나머지 ×0.75" 관계식과 변형 플래그(VARIANTS)·십자 회전은 없앴다(20.73 [1-2] 폐기 결정) - 같은
-- 5패턴의 간격만 바꾸는 방식은 "같은 보스의 다른 리듬"에 그쳤다. 이제 보스의 차이는 스킬마다의
-- 쿨·우선순위·발동 조건·모양 파라미터로 적는다(구동은 shared/BossScheduler.lua).
--
-- 어느 스테이지에 어느 종이 나오는가는 BossRules.nextRotationBossId가 플레이어별 순환 상태로 정한다
-- (23-5, PRD 20.50 [5]) - pools는 그 순환이 읽는 6종 목록 하나다. 견습 보스는 tutorialBossId 고정.
--
-- stageInterval=5: 이 프로젝트엔 "몇 스테이지마다 보스"를 정한 기존 값이 없었다. (1) 로블록스 타워/
-- 시뮬레이터 장르의 "10층마다 보스"보다 촘촘해야 초기 빌드에서 첫 보스를 금방 만나 검증할 수 있고,
-- (2) 5단계 간격이면 stage 5(첫 보스)의 잡몹 공격력이 8×1.155^4≈14.2로 아직 맨몸 캐릭터가 버틸 수 있는
-- 크기다(10단계 간격이면 이미 29.2로 잡몹 평타에 즉사해 보스 자체를 검증할 수 없다 - 15-1 세션 계산).
--
-- hpMultiplier=20은 PRD 20.9가 확정해 둔 "일반 몬스터 체력 = 보스 체력 ÷ 20"을 뒤집어 쓴 것이다.
-- 기본 공격의 위협은 잡몹과 같게 두고(attackMultiplier=1) "보스가 위험한 이유"를 예고 있는 스킬에 몬다.
--
-- ═══ 스킬 필드(29-2, PRD 20.75 A-2) ═══
--   primitive            처리 종류 - BossPatterns.lua의 핸들러 표가 이 이름으로 찾는다(보스 이름이 들어간
--                        함수는 없다): circleBoss(보스 중심 원·도넛·연속 펄스) / ring(퍼지는 띠, 점프 회피) /
--                        circleTarget(대상 위치 원 - 동시 산개 또는 연발) / charge(돌진) / line(직선 -
--                        십자·부채·단발) / gimmick(전역 기믹: 예고 → 파훼 판정, 29-1 뼈대)
--   cooldownSeconds      내부 쿨 - 이 스킬이 끝난 시각부터 다시 쓸 수 있을 때까지
--   priority             준비된 스킬이 여럿일 때 큰 쪽이 나간다. 같으면 가장 오래 기다린 것부터(21-3 규칙)
--   firstAvailableSeconds 전투 시작(어그로) 후 처음 쓸 수 있는 시각. 없으면 cooldownSeconds(21-3 관례 그대로)
--   reserveFirstUse      true면 첫 발동 시각이 보장된다 - 그 시각을 넘겨 끝날 다른 스킬은 시작하지 않는다(29-1 자리 비우기)
--   starvationSeconds    마지막 사용(또는 전투 시작) 후 이만큼 안 나왔으면 우선순위에 scheduler.starvationPriorityBonus를 더한다
--   conditions           발동 조건 조각의 목록(전부 참이어야 한다). 없으면 항상 참. 종류는 BossScheduler.lua 주석
--   telegraphSeconds     전조 - 스킬 시작부터 첫 판정까지. 회피 부등식(BossSim.checkDodge)이 검사하는 값이다
--   damage               { kind = "attack", multiplier } = 감소식을 거친 평타 피해 × 배율(방어 적용) /
--                        { kind = "maxHp", fraction } = 최대체력 비율(방어 무시, 발동당 1인 합계 ≤ mechanics.gimmickFailMaxHpFraction)
--   role                 "signature"(그 보스를 기억하게 만드는 하나) / "gimmick"(파훼 대상)
--   enabled = false      설계만 있고 아직 실제 전투에 안 나오는 스킬(보스별 구현 세션이 켠다). BossSim은 design 옵션으로 포함한다
--   bubble               말풍선 픽토그램 키(클라 BossPatternVisuals의 BUBBLES)
--   sim                  BossSim 전용 가정(회피 비용 등) - 게임 판정에는 안 쓰인다
-- 전조 뒤 마지막 판정까지의 시간(시전)과 후딜은 손으로 적지 않는다 - 모양 파라미터(waveCount·volleys·
-- dashCount·recoverSeconds…)에서 BossSkillMath.boundSeconds가 계산한다(값이 두 군데 있으면 어긋난다).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)

-- ═══ 6종 공통 뼈대 상수 ═══
-- 게이트의 받는 피해 배율 g는 여기 없다 - BossRules.gateDamageTakenMultiplier가 PartyConfig.maxMembers·
-- partyHpExponent에서 유도한다(N_max^(p−1) = 0.487).
local MECHANICS = {
	-- 29-1 A-1: 기믹 실패 1회 = 최대체력 × 이 값(방어 무관). 허용 구간 [50%, 57.1%). %최대체력 스킬은
	-- 종류를 막론하고 한 번의 발동에서 한 사람에게 이 값을 넘겨 주지 못한다(29-2 D - 돌진도 여기에 든다).
	gimmickFailMaxHpFraction = 0.55,
	partialFailDivisor = 3,

	-- 29-1 A-2: 잡힘. 자동 해제 9초 = 구출 인시 6 ÷ (1 − 1/3) = 90초 앵커의 10%. 0 = 잡힌 동안 면역.
	trap = {
		autoReleaseSeconds = 9,
		rescueSeconds = 1.5,
		damageTakenMultiplier = 0,
	},

	-- 28-2 [1-5] 힌트 단계: 전멸 1회 = 말풍선 ×bubbleScale + 안전지대 흰 화살표, 2회 이상 = 기믹 예고 ×telegraphMultiplier.
	hint = {
		maxLevel = 2,
		bubbleScale = 1.5,
		telegraphMultiplier = 1.5,
	},

	-- 29-2 A: 우선순위 눈금(값 자체보다 순서가 뜻이다)과 굶주림 가산. 가산이 어떤 기본 우선순위보다도
	-- 커서 굶은 스킬은 다음 선택에서 반드시 나간다(자리 비우기만 예외).
	priority = { normal = 0, signature = 50, gimmick = 100 },
	starvationPriorityBonus = 1000,

	-- 29-2 B: 회피 부등식  telegraphSeconds ≥ perceptionSeconds + (회피 거리 ÷ 이동 속도) × marginFactor
	--   perceptionSeconds 0.5 = 시각 반응 0.25 + 터치 입력 지연 0.10 + 서버→클라 전조 표시 지연 0.15(20.44의 세 항 그대로)
	--   이동 속도 = WorldConfig.playerWalkSpeedStuds(신속 옵션 0, 대시 없음 - 대시는 쿨이 있는 보너스다)
	--   marginFactor 1.25 = 1 ÷ cos 36.9° - 회피 방향을 37°쯤 틀리게 잡아도(모바일 조이스틱 8방향 오차 22.5° +
	--     첫 발의 방향 전환) 성립한다. 1.0은 최단 직선을 즉시 걸어야만 피하는 값이라 실수 여지가 없다.
	--   characterHalfWidthStuds 1 = 판정은 루트 좌표지만 "몸이 다 나왔다"고 느끼는 여유.
	--   jumpAirSeconds 0.54 = 점프 체공(21-3 실측). 점프 회피는 거리가 아니라 "다시 뛸 수 있는가"로 검사한다.
	--   rangedStandoffStuds 20 = 원거리 직업이 서는 자리(활 사거리 기준) - 부채꼴·도넛처럼 선 자리에 따라 회피 거리가 달라지는 모양의 기준점.
	dodge = {
		perceptionSeconds = 0.5,
		marginFactor = 1.25,
		characterHalfWidthStuds = 1,
		jumpAirSeconds = 0.54,
		rangedStandoffStuds = 20,
	},

	-- BossSim(처치 시간 모형) 전용 가정 - 20.44·20.73 [3]의 회피 비용표. 게임 판정에는 안 쓰인다.
	sim = {
		tickSeconds = 0.05,
		referenceKillSeconds = 60, -- 보스 HP = 기준 플레이어 순딜 60초분
		-- 스킬 한 번을 피하느라 딜이 0인 시간(초). 스킬의 sim.evadeSeconds가 있으면 그쪽이 우선.
		evadeSeconds = { circleBoss = 1.5, ringPerWave = 1.0, circleTarget = 1.0, circleTargetLarge = 1.25, circleTargetRepeat = 0.75, linePerVolley = 0.75, chargePerDash = 1.5 },
		largeCircleRadiusStuds = 8, -- 이보다 큰 대상 원은 circleTargetLarge
		chargeTravelSeconds = 1.5, -- 아레나 중앙 → 벽 92stud ÷ 60stud/s(결정 모형). 몬테카를로는 아래 범위에서 뽑는다
		-- 몬테카를로(29-2 F-8): 회피 비용 ±jitter 균등, 돌진 이동 시간 범위, 위치 조건(거리·밀집)의 참 확률.
		monteCarlo = { runs = 200, evadeJitter = 0.25, chargeTravelMinSeconds = 0.5, chargeTravelMaxSeconds = 3.0, positionalConditionChance = 0.5 },
	},
}

local P = MECHANICS.priority

-- ═══ 기본형 스킬(21-3, PRD 20.44 [3](나) → 20.46) - 구간 수호자가 그대로 쓴다 ═══
-- 회피 전제는 "걷기 16stud/s + 점프(높이 7.2, 체공 0.54초)"뿐이다 - 대시(21-2)는 보너스지 필수가 아니다.
-- 값은 29-2에서 한 글자도 안 바꿨다 - 단 하나, 돌진의 최대체력 비율만 0.8 → 0.55다(PRD 20.75 D: 돌진 80% +
-- ×2 패턴 하나 = 108.6%로 "실수 두 번에 풀피 즉사"였다. %최대체력 피해는 전부 같은 상한 아래 둔다).
local function guardianSkills()
	return {
		-- 예고 후 강한 일격(15-1). 보스 중심 원 - 판정이 "보스 좌표에서 radiusStuds 안"이라 위험 범위도 보스 중심이다(25-4).
		-- 평타의 3배 = 7타 앵커에서 최대체력의 42.9%. 예고 1.5초 동안 걸어서 벗어난다.
		heavy = {
			primitive = "circleBoss", bubble = "heavy",
			cooldownSeconds = 6, priority = P.normal,
			telegraphSeconds = 1.5, radiusStuds = 14,
			damage = { kind = "attack", multiplier = 3 }, damageLabel = "강공격",
		},
		-- 진동파. 보스가 hopHeightStuds만큼 떠올랐다 찍는 동작이 예고이고 찍는 순간 파동이 waveSpeedStuds로
		-- 퍼진다. 24 > 걷기 16이라 뛰어서는 못 피한다(점프가 유일한 답). 판정은 "파동 두께가 플레이어를
		-- 지나는 동안 한 순간이라도 공중이었는가" - 점프 입력 창 = 체공 0.54 + 통과 4/24 = 0.71초.
		-- waveCount 3 = 줄넘기: repeatIntervalSeconds 1.5 ≥ 체공 0.54 + 반응·입력 0.35 + 통과 0.17 + 여유 0.44.
		shockwave = {
			primitive = "ring", bubble = "shockwave",
			cooldownSeconds = 11, priority = P.normal,
			telegraphSeconds = 1.2, waveCount = 3, repeatIntervalSeconds = 1.5,
			waveSpeedStuds = 24, waveThicknessStuds = 4, hopHeightStuds = 4,
			-- 공중 판정 여유 - 지면 거리가 서 있을 때(HipHeight + 루트 반높이)보다 이만큼 더 크면 공중(21-3 실측).
			airborneClearanceStuds = 0.5,
			damage = { kind = "attack", multiplier = 2 }, damageLabel = "진동파",
		},
		-- 낙석. 표적 장판 count개(첫 장판은 대상 현재 위치, 나머지는 scatterStuds 안 랜덤). 좌표 고정형이라
		-- "계속 움직이는 사람은 안 맞는다". 회피 = 반경 6 + 1 = 7stud.
		meteor = {
			primitive = "circleTarget", bubble = "meteor",
			cooldownSeconds = 13, priority = P.normal,
			telegraphSeconds = 1.5, count = 3, radiusStuds = 6, scatterStuds = 10,
			damage = { kind = "attack", multiplier = 2 }, damageLabel = "낙석",
		},
		-- 정신집중 → 돌진. 느낌표가 뜨는 순간 대상 좌표를 고정하고(추적 안 함 - 회피가 실력이 되는 핵심)
		-- telegraphSeconds 뒤 그 좌표를 지나 벽까지 speedStuds로 직진한다. 방어 무관(직업 무관하게 회피를 강제).
		-- 경로 반폭 4 + 캐릭터 반폭 1 = 5stud 옆걸음. 벽(arenaMarginStuds 안쪽)에서 멈추고 recoverSeconds 동안
		-- 헤롱거린다 - 돌진을 피한 사람에게만 주어지는 딜타임이다.
		charge = {
			primitive = "charge", bubble = "charge",
			cooldownSeconds = 15, priority = P.normal,
			telegraphSeconds = 1.5, speedStuds = 60, pathHalfWidthStuds = 4, dashCount = 1,
			recoverSeconds = 4.0, dazeSinkStuds = 1.2, dazeTiltDeg = 25,
			arenaMarginStuds = 4, -- 보스 몸통 반폭(1.2×3=3.6)보다 조금 크게
			damage = { kind = "maxHp", fraction = 0.55 }, damageLabel = "돌진",
		},
		-- 십자 화염. 보스 중심 4방향(첫 볼리는 대상 방향, 90도 간격) 벽까지. 두 번째 볼리는 rotateDeg 돌려서 -
		-- 첫 볼리를 피해 대각선에 섰으면 다시 옆으로 걸어야 한다. 회피 = 옆으로 3 + 1 = 4stud.
		cross = {
			primitive = "line", bubble = "cross",
			cooldownSeconds = 17, priority = P.normal,
			telegraphSeconds = 1.5, directions = 4, stepDeg = 90, volleys = 2, rotateDeg = 45, halfWidthStuds = 3,
			damage = { kind = "attack", multiplier = 2 }, damageLabel = "십자 화염",
		},
	}
end

-- ═══ 6종 공통 스탯 ═══
local BASE_STATS = {
	-- 잡몹(MonsterData.tier1) 대비 배율. 실제 수치는 그 스테이지의 잡몹 값에 곱해서 매번 계산한다
	-- (BossRules.buildInstanceData) - 여기 절대값을 박지 않는다.
	hpMultiplier = 20,
	attackMultiplier = 1,
	goldMultiplier = 20,
	expMultiplier = 20,
	telegraphColor = Color3.fromRGB(200, 30, 30),
}

-- 전역 쿨·격노·입장 유예(21-3). 패턴은 한 번에 하나만 돌고, 어떤 스킬이 끝난 뒤 globalCooldownSeconds가
-- 지나야 다음 스킬이 시작된다 - 이게 없으면 쿨이 겹칠 때 회피 불가 구간이 생긴다. 평소 6초: 스킬 사이에
-- 평타 추격 구간이 확실히 있다. 격노(HP ≤ enragedHpFraction) 2.5초 = 착지 0.54 + 반응 0.5 + 옆걸음 0.4 +
-- 여유 1.0 - "진동파 회피 직후 돌진을 착지 경직으로 못 피한다"는 일이 없는 하한. 보스마다 평소 값만 다르다.
local function scheduler(globalCooldownSeconds)
	return {
		globalCooldownSeconds = globalCooldownSeconds,
		enragedHpFraction = 0.2,
		enragedGlobalCooldownSeconds = 2.5,
		entryGraceSeconds = 2, -- 입장·재도전 유예(20.44 [3](다)) - 텔레포트 직후 예고 없이 맞지 않게
		starvationPriorityBonus = MECHANICS.starvationPriorityBonus,
	}
end

local function tierColor(tierKey)
	local tier = MonsterData[tierKey]
	return tier.bodyColor, tier.headColor
end

local abyssalBody, abyssalHead = tierColor("tier1")
local frostBody, frostHead = tierColor("tier2")
local stormBody, stormHead = tierColor("tier3")
local scorpionBody, scorpionHead = tierColor("tier4")
local crystalBody, crystalHead = tierColor("tier6")

-- ═══ 6종(29-2, PRD 20.75 C) ═══
-- 개성 필드: basicAttack(주기·피해 배율·사거리 - 주기 × 배율 보존: 느린 보스는 한 방이 크고 빠른 보스는
-- 잦다, 초당 기대 피해는 6종이 같다) / sizeScale·bodyAspect·attachments(체격·실루엣) / moveSpeedStuds(추격
-- 속도 - 전부 플레이어 걷기 16보다 느리다: 걸어서 벗어날 수 있어야 한다) / scheduler(전역 쿨 - 느린 보스 7 ·
-- 보통 6 · 빠른 보스 5) / skills의 쿨 분포 / role="signature".
-- chaseStopDistanceStuds(21-3): 몸통 충돌이 꺼진 보스가 플레이어와 겹치지 않게 서는 거리 = 몸통 반폭 + 캐릭터 1 + 여유.
-- skillOrder는 같은 우선순위·같은 대기 시간일 때의 결정 순서(순회 순서 보장 - ArmorData.gradeOrder와 같은 이유).
local SPECIES = {
	{
		id = "section_guardian", displayName = "구간 수호자",
		bodyColor = Color3.fromRGB(60, 20, 70), headColor = Color3.fromRGB(90, 30, 100),
		-- 기본형(기준선) - 21-3부터 검증돼 온 그 보스다. 다른 5종이 쓰는 전조 어휘의 사전이고 견습 보스다.
		sizeScale = 3, bodyAspect = Vector3.new(1.0, 1.0, 1.0),
		attachments = {
			{ anchor = "body", offset = Vector3.new(1.2, 0.9, 0), size = Vector3.new(0.5, 0.5, 0.9), kind = "block", color = "head", name = "LeftPauldron" },
			{ anchor = "body", offset = Vector3.new(-1.2, 0.9, 0), size = Vector3.new(0.5, 0.5, 0.9), kind = "block", color = "head", name = "RightPauldron" },
		},
		moveSpeedStuds = 8, chaseStopDistanceStuds = 8,
		basicAttack = { cooldownSeconds = 1.0, damageMultiplier = 1, rangeStuds = 14 },
		scheduler = scheduler(6),
		skillOrder = { "heavy", "shockwave", "meteor", "charge", "cross" },
		skills = guardianSkills(),
	},
	{
		id = "frost_giant", displayName = "서리 거인", bodyColor = frostBody, headColor = frostHead,
		-- 느린 거인: 크고(3.3) 느리고(6) 한 방이 무겁다(평타 1.5초에 ×1.5). 전역 쿨도 7초로 길다.
		sizeScale = 3.3, bodyAspect = Vector3.new(0.85, 1.35, 0.85),
		attachments = {
			{ anchor = "head", offset = Vector3.new(0.5, 0.6, 0), size = Vector3.new(0.3, 1.4, 0.3), rotationDeg = Vector3.new(0, 0, -25), kind = "wedge", color = "head", name = "LeftHorn" },
			{ anchor = "head", offset = Vector3.new(-0.5, 0.6, 0), size = Vector3.new(0.3, 1.4, 0.3), rotationDeg = Vector3.new(0, 180, 25), kind = "wedge", color = "head", name = "RightHorn" },
		},
		moveSpeedStuds = 6, chaseStopDistanceStuds = 8,
		basicAttack = { cooldownSeconds = 1.5, damageMultiplier = 1.5, rangeStuds = 14 },
		scheduler = scheduler(7),
		skillOrder = { "slam", "icefall", "spike", "roar" },
		skills = {
			-- 빙결 강타(23-6의 "긴 예비동작" 흡수). 기본형 강공격과 같은 동사(밖으로 걷기)지만 더 크고 더 느리다 -
			-- 반경 18을 2.25초에. 29-3에서 범위 안의 얼음 기둥을 부순다.
			slam = {
				primitive = "circleBoss", bubble = "heavy", role = "signature",
				cooldownSeconds = 9, priority = P.signature,
				telegraphSeconds = 2.25, radiusStuds = 18,
				damage = { kind = "attack", multiplier = 3 }, damageLabel = "빙결 강타",
			},
			-- 낙빙. 원이 입장 인원 + 2개(솔로 3) - 29-3에서 낙하점마다 얼음 기둥이 남는다("어디서 피했는가" = "엄폐물이 어디 생기는가").
			icefall = {
				primitive = "circleTarget", bubble = "meteor",
				cooldownSeconds = 12, firstAvailableSeconds = 4, priority = P.normal, starvationSeconds = 45,
				telegraphSeconds = 1.5, count = 2, countPerMember = 1, radiusStuds = 5, scatterStuds = 12,
				damage = { kind = "attack", multiplier = 2 }, damageLabel = "낙빙",
			},
			-- 얼음 가시. 보스 → 대상 직선 하나. 체력이 70% 아래로 내려가야 쓰기 시작한다(HP 구간 조건).
			spike = {
				primitive = "line", bubble = "cross",
				cooldownSeconds = 14, priority = P.normal, starvationSeconds = 45,
				conditions = { { type = "hpBelow", value = 0.7 } },
				telegraphSeconds = 1.5, directions = 1, stepDeg = 0, volleys = 1, rotateDeg = 0, halfWidthStuds = 3,
				damage = { kind = "attack", multiplier = 2 }, damageLabel = "얼음 가시",
			},
			-- 눈보라 포효(기믹, 29-3에서 켠다). 전역 - 얼음 기둥 뒤에서만 피한다. 기둥까지 최대 30stud(선행 조건).
			roar = {
				primitive = "gimmick", bubble = "gimmick", role = "gimmick", enabled = false, kind = "behindProp",
				cooldownSeconds = 20, firstAvailableSeconds = 10, reserveFirstUse = true, priority = P.gimmick,
				telegraphSeconds = 3.0, recoverSeconds = 1.0,
				dodge = { distanceStuds = 30 },
				damage = { kind = "maxHp", fraction = MECHANICS.gimmickFailMaxHpFraction }, damageLabel = "눈보라 포효",
				sim = { evadeSeconds = 2.0 },
			},
		},
	},
	{
		id = "abyssal_lord", displayName = "심해 군주", bodyColor = abyssalBody, headColor = abyssalHead,
		sizeScale = 3, bodyAspect = Vector3.new(1.05, 0.95, 1.15),
		attachments = {
			{ anchor = "body", offset = Vector3.new(1.3, 0.9, 0), size = Vector3.new(0.9, 0.5, 0.9), rotationDeg = Vector3.new(0, 0, -30), kind = "wedge", color = "head", name = "LeftFin" },
			{ anchor = "body", offset = Vector3.new(-1.3, 0.9, 0), size = Vector3.new(0.9, 0.5, 0.9), rotationDeg = Vector3.new(0, 180, 30), kind = "wedge", color = "head", name = "RightFin" },
			{ anchor = "body", offset = Vector3.new(0, 0.7, -1.0), size = Vector3.new(0.6, 0.6, 1.0), rotationDeg = Vector3.new(0, 180, 0), kind = "wedge", color = "body", name = "TailFin" },
		},
		moveSpeedStuds = 8, chaseStopDistanceStuds = 8,
		basicAttack = { cooldownSeconds = 1.0, damageMultiplier = 1, rangeStuds = 14 },
		scheduler = scheduler(6),
		skillOrder = { "sweep", "tide", "spout", "flood" },
		skills = {
			-- 꼬리 휩쓸기. 도넛(안쪽 9 ~ 바깥 24) - 기본형 강공격과 반대로 **몸 쪽이 안전하다**. 누군가 바깥 반경
			-- 안에 있을 때만 쓴다(거리 조건).
			sweep = {
				primitive = "circleBoss", bubble = "heavy",
				cooldownSeconds = 8, priority = P.normal, starvationSeconds = 45,
				conditions = { { type = "targetWithin", studs = 24 } },
				telegraphSeconds = 1.5, innerRadiusStuds = 9, radiusStuds = 24,
				damage = { kind = "attack", multiplier = 3 }, damageLabel = "꼬리 휩쓸기",
			},
			-- 해일 줄넘기(23-6 "진동파 두 겹" 흡수). 한 번 찍을 때 파동이 두 겹 - 겹당 피해 절반, 겹 간격 = 두께 ÷ 속도라
			-- 점프 한 번에 둘 다 넘는다. 29-4에서 단 위에서도 뛰어야 한다.
			tide = {
				primitive = "ring", bubble = "shockwave", role = "signature",
				cooldownSeconds = 13, priority = P.signature,
				telegraphSeconds = 1.2, waveCount = 3, repeatIntervalSeconds = 1.5,
				waveSpeedStuds = 24, waveThicknessStuds = 4, hopHeightStuds = 4, airborneClearanceStuds = 0.5,
				layers = 2, layerGapSeconds = 4 / 24,
				damage = { kind = "attack", multiplier = 1 }, damageLabel = "해일",
			},
			-- 물기둥. 기본형 낙석(동시 3개 산개)과 달리 **연발** - 하나가 터지면 그 순간의 대상 위치에 다음 것이
			-- 예고된다. 한 번 피하고 서 있으면 다음 것을 맞는다(계속 걸어라).
			spout = {
				primitive = "circleTarget", bubble = "meteor",
				cooldownSeconds = 15, priority = P.normal, starvationSeconds = 45,
				telegraphSeconds = 1.5, count = 3, sequential = true, repeatTelegraphSeconds = 1.2, radiusStuds = 6, scatterStuds = 0,
				damage = { kind = "attack", multiplier = 2 }, damageLabel = "물기둥",
			},
			-- 범람(기믹, 29-4). 예고 시작 6초 뒤 방전 - 그때 가라앉지 않은 단 위여야 한다. 단까지 최대 51stud, 물속 −20%.
			flood = {
				primitive = "gimmick", bubble = "gimmick", role = "gimmick", enabled = false, kind = "onProp",
				cooldownSeconds = 20, firstAvailableSeconds = 10, reserveFirstUse = true, priority = P.gimmick,
				telegraphSeconds = 6.0, recoverSeconds = 1.5,
				dodge = { distanceStuds = 51, speedMultiplier = 0.8 },
				damage = { kind = "maxHp", fraction = MECHANICS.gimmickFailMaxHpFraction }, damageLabel = "방전",
				sim = { evadeSeconds = 3.0 },
			},
		},
	},
	{
		id = "crystal_queen", displayName = "수정 여왕", bodyColor = crystalBody, headColor = crystalHead,
		sizeScale = 3, bodyAspect = Vector3.new(1.0, 1.15, 1.0),
		attachments = {
			{ anchor = "body", offset = Vector3.new(0.9, 1.0, 0.2), size = Vector3.new(0.4, 1.3, 0.4), rotationDeg = Vector3.new(0, 0, -20), kind = "wedge", color = "head", name = "LeftShard" },
			{ anchor = "body", offset = Vector3.new(-0.9, 1.0, 0.2), size = Vector3.new(0.4, 1.3, 0.4), rotationDeg = Vector3.new(0, 180, 20), kind = "wedge", color = "head", name = "RightShard" },
			{ anchor = "body", offset = Vector3.new(0, 1.1, -0.7), size = Vector3.new(0.4, 1.6, 0.4), kind = "wedge", color = "head", name = "BackShard" },
		},
		moveSpeedStuds = 7, chaseStopDistanceStuds = 8,
		basicAttack = { cooldownSeconds = 1.0, damageMultiplier = 1, rangeStuds = 14 },
		scheduler = scheduler(6),
		skillOrder = { "burst", "drop", "beam", "split" },
		skills = {
			-- 파편 폭발. 두 번 터진다: 안쪽 원(반경 10) → 바깥 도넛(10 ~ 22). 밖으로 나갔다가 다시 안으로 - 기본형
			-- 강공격의 "한 번 나가면 끝"과 다르다. 펄스당 ×2(둘 다 맞아도 57%).
			burst = {
				primitive = "circleBoss", bubble = "heavy",
				cooldownSeconds = 9, priority = P.normal, starvationSeconds = 45,
				telegraphSeconds = 1.5, radiusStuds = 22,
				pulses = { { innerRadiusStuds = 0, radiusStuds = 10 }, { innerRadiusStuds = 10, radiusStuds = 22 } },
				damage = { kind = "attack", multiplier = 2 }, damageLabel = "파편 폭발",
			},
			-- 수정 낙하(23-6 "낙석 1개" 흡수). 하나지만 크다 - 기본형 낙석의 옆걸음으로는 못 나온다(11stud). 23-6의 반경
			-- 6√3 = 10.39는 스테이지 범위 배율 최대(×1.152)에서 회피 부등식을 0.01초 넘겨 10으로 내렸다(PRD 20.75 B).
			drop = {
				primitive = "circleTarget", bubble = "meteor", role = "signature",
				cooldownSeconds = 11, priority = P.signature,
				telegraphSeconds = 1.5, count = 1, radiusStuds = 10, scatterStuds = 0,
				damage = { kind = "attack", multiplier = 2 }, damageLabel = "수정 낙하",
			},
			-- 반사 광선. 직선 하나를 두 번 - 둘째는 그 순간의 대상 위치로 다시 겨눈다(29-5에서 벽 수정에 꺾인다).
			beam = {
				primitive = "line", bubble = "cross",
				cooldownSeconds = 14, priority = P.normal, starvationSeconds = 45,
				telegraphSeconds = 1.5, directions = 1, stepDeg = 0, volleys = 2, rotateDeg = 0, reaim = true, halfWidthStuds = 3,
				damage = { kind = "attack", multiplier = 2 }, damageLabel = "반사 광선",
			},
			-- 프리즘 분열(기믹, 29-5). 제한 8초 안에 진짜를 찾아 때린다 - 진짜까지 20stud.
			split = {
				primitive = "gimmick", bubble = "gimmick", role = "gimmick", enabled = false, kind = "hitReal",
				cooldownSeconds = 20, firstAvailableSeconds = 10, reserveFirstUse = true, priority = P.gimmick,
				telegraphSeconds = 8.0, recoverSeconds = 4.0,
				breakWindow = { seconds = 4, damageTakenMultiplier = 1.3 },
				dodge = { distanceStuds = 20 },
				damage = { kind = "maxHp", fraction = MECHANICS.gimmickFailMaxHpFraction }, damageLabel = "파편 폭풍",
				sim = { evadeSeconds = 2.5, resolveSeconds = 3.5 },
			},
		},
	},
	{
		id = "scorpion_queen", displayName = "전갈 여왕", bodyColor = scorpionBody, headColor = scorpionHead,
		-- 빠른 보스: 낮고 넓고(2.8) 빠르다(10 - 잡몹과 같다). 평타가 잦고(0.75초) 가볍다(×0.75). 전역 쿨 5초.
		sizeScale = 2.8, bodyAspect = Vector3.new(1.3, 0.65, 1.2),
		attachments = {
			{ anchor = "body", offset = Vector3.new(1.1, 0, -0.9), size = Vector3.new(0.9, 0.4, 0.9), rotationDeg = Vector3.new(0, -30, 0), kind = "wedge", color = "head", name = "LeftClaw" },
			{ anchor = "body", offset = Vector3.new(-1.1, 0, -0.9), size = Vector3.new(0.9, 0.4, 0.9), rotationDeg = Vector3.new(0, 210, 0), kind = "wedge", color = "head", name = "RightClaw" },
			{ anchor = "body", offset = Vector3.new(0, 0.8, 1.0), size = Vector3.new(0.35, 1.2, 0.35), rotationDeg = Vector3.new(-30, 0, 0), kind = "wedge", color = "body", name = "TailSpike" },
		},
		moveSpeedStuds = 10, chaseStopDistanceStuds = 8,
		basicAttack = { cooldownSeconds = 0.75, damageMultiplier = 0.75, rangeStuds = 14 },
		scheduler = scheduler(5),
		skillOrder = { "claw", "sting", "stab", "shell" },
		skills = {
			-- 집게 강타. 대상 쪽으로 펼친 부채꼴(직선 3개, ±35°) - 기본형 강공격은 "밖으로", 이건 "옆·뒤로".
			-- 가까이 붙은 사람에게만 쓴다(멀리서는 부채가 너무 넓어져 못 피한다 - 회피 부등식이 12stud까지만 성립).
			claw = {
				primitive = "line", bubble = "heavy",
				cooldownSeconds = 8, priority = P.normal, starvationSeconds = 40,
				conditions = { { type = "targetWithin", studs = 12 } },
				telegraphSeconds = 1.5, directions = 3, stepDeg = 35, centered = true, volleys = 1, rotateDeg = 0, halfWidthStuds = 3,
				damage = { kind = "attack", multiplier = 3 }, damageLabel = "집게 강타",
			},
			-- 독침 낙하. 기본형 낙석보다 작고(반경 5) 빠르다(1.2초) - 빠른 보스의 템포.
			sting = {
				primitive = "circleTarget", bubble = "meteor",
				cooldownSeconds = 12, priority = P.normal, starvationSeconds = 40,
				telegraphSeconds = 1.2, count = 3, radiusStuds = 5, scatterStuds = 10,
				damage = { kind = "attack", multiplier = 2 }, damageLabel = "독침 낙하",
			},
			-- 연속 찌르기(23-6 "돌진 2연속" 흡수). 첫 돌진을 피한 자리로 둘째가 다시 겨눈다 - 한 번 피하고 멈추면
			-- 맞는다. 회당 27.5% = 둘 다 맞아도 55%. 갑각 태세 직후에는 쓰지 않는다(55 + 55 = 110%를 인접시키지 않는다).
			stab = {
				primitive = "charge", bubble = "charge", role = "signature",
				cooldownSeconds = 14, priority = P.signature,
				conditions = { { type = "notAfter", skills = { "shell" } } },
				telegraphSeconds = 1.5, speedStuds = 60, pathHalfWidthStuds = 4, dashCount = 2,
				recoverSeconds = 4.0, dazeSinkStuds = 1.2, dazeTiltDeg = 25,
				arenaMarginStuds = 5, -- 몸통 반폭 1.2 × 2.8 × 1.3 = 4.4보다 조금 크게
				damage = { kind = "maxHp", fraction = MECHANICS.gimmickFailMaxHpFraction / 2 }, damageLabel = "연속 찌르기",
			},
			-- 갑각 태세(기믹, 29-3). 예고 1초 + 태세 3초 동안 때리면 반사 - 판정은 태세 끝. 회피는 이동이 아니라 "손을 뗀다".
			shell = {
				primitive = "gimmick", bubble = "gimmick", role = "gimmick", enabled = false, kind = "noHit",
				cooldownSeconds = 18, firstAvailableSeconds = 10, reserveFirstUse = true, priority = P.gimmick,
				conditions = { { type = "notAfter", skills = { "stab" } } },
				telegraphSeconds = 4.0, recoverSeconds = 3.0,
				breakWindow = { seconds = 3, damageTakenMultiplier = 1.5 },
				dodge = { distanceStuds = 0, noticeSeconds = 1.0 }, -- 예고 1초 안에 공격을 멈추면 된다
				damage = { kind = "maxHp", fraction = MECHANICS.gimmickFailMaxHpFraction }, damageLabel = "갑각 반사",
				sim = { evadeSeconds = 4.0 },
			},
		},
	},
	{
		id = "storm_lord", displayName = "폭풍 군주", bodyColor = stormBody, headColor = stormHead,
		-- 가장 바쁜 보스: 전역 쿨 5초에 쿨이 짧은 스킬들. 평타도 잦고 가볍다.
		sizeScale = 3, bodyAspect = Vector3.new(0.9, 1.2, 0.9),
		attachments = {
			{ anchor = "body", offset = Vector3.new(1.2, 1.3, 0), size = Vector3.new(0.3, 1.8, 0.3), rotationDeg = Vector3.new(0, 0, -15), kind = "wedge", color = "head", name = "LeftBlade" },
			{ anchor = "body", offset = Vector3.new(-1.2, 1.3, 0), size = Vector3.new(0.3, 1.8, 0.3), rotationDeg = Vector3.new(0, 180, 15), kind = "wedge", color = "head", name = "RightBlade" },
		},
		moveSpeedStuds = 9, chaseStopDistanceStuds = 8,
		basicAttack = { cooldownSeconds = 0.75, damageMultiplier = 0.75, rangeStuds = 14 },
		scheduler = scheduler(5),
		skillOrder = { "discharge", "chain", "strike", "overcharge" },
		skills = {
			-- 방전 고리. 파동 하나 - 기본형 강공격 자리의 스킬이지만 걸어서가 아니라 **뛰어서** 피한다.
			discharge = {
				primitive = "ring", bubble = "shockwave",
				cooldownSeconds = 9, priority = P.normal, starvationSeconds = 40,
				telegraphSeconds = 1.2, waveCount = 1, repeatIntervalSeconds = 1.5,
				waveSpeedStuds = 24, waveThicknessStuds = 4, hopHeightStuds = 4, airborneClearanceStuds = 0.5,
				damage = { kind = "attack", multiplier = 3 }, damageLabel = "방전 고리",
			},
			-- 연쇄 번개. 보스 → 대상 직선 하나(29-4에서 8stud 안의 다른 멤버로 이어진다 - "뭉쳐 있지 마라").
			chain = {
				primitive = "line", bubble = "cross",
				cooldownSeconds = 13, priority = P.normal, starvationSeconds = 40,
				telegraphSeconds = 1.5, directions = 1, stepDeg = 0, volleys = 1, rotateDeg = 0, halfWidthStuds = 3,
				damage = { kind = "attack", multiplier = 2 }, damageLabel = "연쇄 번개",
			},
			-- 낙뢰. 대상 위치에 2연발(둘째는 그 순간의 위치). 29-4에서 피뢰침 충전 수단이 되고 뇌운 장막(게이트)의
			-- 판정이 이 스킬에 붙는다 - designGate는 그때까지 BossSim만 읽는다.
			strike = {
				primitive = "circleTarget", bubble = "meteor", role = "signature",
				cooldownSeconds = 12, firstAvailableSeconds = 8, reserveFirstUse = true, priority = P.signature,
				telegraphSeconds = 1.5, count = 2, sequential = true, repeatTelegraphSeconds = 1.5, radiusStuds = 6, scatterStuds = 0,
				damage = { kind = "attack", multiplier = 2 }, damageLabel = "낙뢰",
				designGate = { breakWindow = { seconds = 10, damageTakenMultiplier = 1.15 } }, -- 28-2의 ×1.3은 새 쿨 분포에서 −11.6%로 범위 밖(×1.15 = −6.5%)
				sim = { evadeSeconds = 2.5 },
			},
			-- 과충전 방전(기믹, 29-4). 장막이 30초 이어지면 전역 - 충전된 피뢰침 곁만 안전. 피뢰침까지 최대 30stud.
			overcharge = {
				primitive = "gimmick", bubble = "gimmick", role = "gimmick", enabled = false, kind = "nearProp",
				cooldownSeconds = 30, priority = P.gimmick,
				conditions = { { type = "gateArmedFor", seconds = 30 } },
				telegraphSeconds = 3.0, recoverSeconds = 0,
				dodge = { distanceStuds = 30 },
				damage = { kind = "maxHp", fraction = MECHANICS.gimmickFailMaxHpFraction }, damageLabel = "과충전 방전",
				sim = { evadeSeconds = 2.0, judgesGate = false },
			},
		},
	},
}

-- 보스별 잡힘·구출 종류(PRD 20.73 [2-8] A-4 표). 구간 수호자는 없다.
local SPECIES_MECHANICS = {
	frost_giant = { trapKind = "frozen", rescueType = "hitCount" },
	abyssal_lord = { trapKind = "submerged", rescueType = "proximity" },
	crystal_queen = { trapKind = "crystallized", rescueType = "gimmick" },
	scorpion_queen = { trapKind = "buried", rescueType = "push" },
	storm_lord = { trapKind = "shocked", rescueType = "touch" },
}

local bosses = {}
local rotationBossIds = {}
for _, species in ipairs(SPECIES) do
	local boss = {}
	for key, value in pairs(BASE_STATS) do
		boss[key] = value
	end
	for key, value in pairs(species) do
		boss[key] = value
	end
	boss.mechanics = SPECIES_MECHANICS[species.id]
	-- arenaKit(29-2 훅): 보스별 정적 지형지물 목록. 아직 어느 보스에도 없다(보스별 세션이 채운다) - BossArenaKit.lua.
	bosses[species.id] = boss
	table.insert(rotationBossIds, species.id)
end

return {
	stageInterval = 5,

	pools = {
		{ minStage = 1, bossIds = rotationBossIds },
	},

	-- 28-2 [1-3]: 견습 보스는 기본형 고정(견습의 패턴 부분집합은 5패턴 보스에만 뜻이 있다). 무한 모드 순환도
	-- 맨 처음 한 번은 이 보스를 첫 자리에 둔다(BossRules.nextRotationBossId).
	tutorialBossId = "section_guardian",

	bosses = bosses,
	mechanics = MECHANICS,
}
