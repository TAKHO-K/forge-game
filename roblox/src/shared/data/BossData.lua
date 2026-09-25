-- 무한 모드 보스 데이터(15-1 → 23-5 6종 → 29-2 보스별 독립 스킬표). PRD-forge-game-roblox.md 20.75.
--
-- 29-2 재편: 보스마다 자기 스킬표(skills)·기본 공격·체격·이동 속도·전역 쿨을 갖는다. 23-6의 "주력 빈도
-- ×2 / 나머지 ×0.75" 관계식과 변형 플래그(VARIANTS)·십자 회전은 없앴다(20.73 [1-2] 폐기 결정) - 같은
-- 5패턴의 간격만 바꾸는 방식은 "같은 보스의 다른 리듬"에 그쳤다. 이제 보스의 차이는 스킬마다의
-- 쿨·우선순위·발동 조건·모양 파라미터로 적는다(구동은 shared/BossScheduler.lua).
--
-- 어느 스테이지에 어느 종이 나오는가는 스테이지 번호만의 함수다(29-5, BossRules.bossIdForStage - 아래 placement 표).
-- 23-5의 플레이어별 순환은 폐기했다(같은 스테이지에서 유저마다 다른 보스를 만났다). pools는 6종 목록(선언 순) 하나다.
-- 견습 보스는 tutorialBossId 고정.
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
--   densityScalable      true면 스테이지 밀도(mechanics.stageDensity)가 count · scatterStuds를 늘린다(S14 - 조건은 BossSkillMath.densityEligible)
--   sim                  BossSim 전용 가정(회피 비용 등) - 게임 판정에는 안 쓰인다
--   onComplete           P3d D1: 스킬이 **정상으로 끝난** 순간 도는 결과 조각(중단 · 리셋이면 안 돈다) - { type = "regrowObstacles", count }(지형지물 재생성)
-- 전조 뒤 마지막 판정까지의 시간(시전)과 후딜은 손으로 적지 않는다 - 모양 파라미터(waveCount·volleys·
-- dashCount·recoverSeconds…)에서 BossSkillMath.boundSeconds가 계산한다(값이 두 군데 있으면 어긋난다).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)
local BalanceAnchorConfig = require(ReplicatedStorage.Shared.data.BalanceAnchorConfig)
-- P3a C: 킷 자리는 원형 아레나의 반경에서 계산한다(아레나를 키우면 킷도 같은 뜻의 자리로 따라간다).
local ARENA_RADIUS = require(ReplicatedStorage.Shared.data.BossArenaMapData).geometry.radiusStuds

local STAGE_INTERVAL = 5 -- 아래 stageInterval(보스 간격) - 밀도 임계값의 반올림 단위로도 쓴다

-- ═══ 6종 공통 뼈대 상수 ═══
-- 게이트의 받는 피해 배율 g는 여기 없다 - BossRules.gateDamageTakenMultiplier가 PartyConfig.maxMembers·
-- partyHpExponent에서 유도한다(N_max^(p−1) = 0.487).
local MECHANICS = {
	-- 29-1 A-1: 기믹 실패 1회 = 최대체력 × 이 값(방어 무관). 허용 구간 [50%, 57.1%). %최대체력 스킬은
	-- 종류를 막론하고 한 번의 발동에서 한 사람에게 이 값을 넘겨 주지 못한다(29-2 D - 돌진도 여기에 든다).
	gimmickFailMaxHpFraction = 0.55,
	partialFailDivisor = 3,

	-- 29-1 A-2: 잡힘. 자동 해제 9초 = 구출 인시 6 ÷ (1 − 1/3) = 90초 앵커의 10%. 0 = 잡힌 동안 면역.
	-- releaseGraceSeconds(29-3): 풀려난 뒤에도 이만큼은 면역이다. 잡힌 동안 시작된 예고는 피할 수 없었다 - 판정 뒤 후딜
	-- + 전역 쿨 + 다음 전조가 9.2 ~ 10.25초라(전갈 3 + 5 + 독침 1.2 / 서리 1 + 7 + 강타 2.25) 자동 해제(9초) 뒤 0.2 ~ 1.25초
	-- 만에 다음 스킬이 떨어진다. 2초 = 가장 오래 걸리는 일반 스킬의 회피 필요 시간(빙결 강타 최대 배율 1.57초) + 여유.
	-- 기믹은 쿨이 18초 이상이라 이 창에 다시 오지 않는다.
	trap = {
		autoReleaseSeconds = 9,
		rescueSeconds = 1.5,
		damageTakenMultiplier = 0,
		releaseGraceSeconds = 2,
	},

	-- 29-3 구출 동작의 수치(20.73 [2-8] A-4). 둘 다 "혼자 하면 trap.rescueSeconds 안팎, 둘이 하면 절반"이 되게 잡는다.
	-- 29-5(PRD 20.80 [B]): 구출 입력을 **F 홀드 하나로 통일**했다 - 잡힌 친구에게 ProximityPrompt가 붙는다(PC F · 모바일
	-- 화면 버튼 · 게임패드가 로블록스 기본 UI로 자동으로 붙는다). 보스별 차이는 "어디서·어떤 조건으로 누르는가"
	-- (종류별 reachStuds와 아래 주석)로 남는다. 홀드 시간 = trap.rescueSeconds(1.5초 - 새 상수가 아니다):
	--   · 위: 인시 절약 1/3(자동 해제 9초의 도출식, 20.73 A-2)이 T ≤ 1.5를 요구한다. 그리고 잡힌 판정 뒤 다음 스킬의 예고가
	--     뜨기까지 가장 짧은 보스(폭풍: 후딜 0 + 전역 쿨 5초) 안에 인지 0.5 + 걸어가기(30stud 1.9초) + 홀드가 끝나야 한다 → T ≤ 2.6.
	--   · 아래: 너무 짧으면 구출이 공짜다 - 기존 구출 동작(1.0 ~ 1.5초)보다 싸지 않게 1.5.
	--   · 둘이 같이 누르면 구출자마다 더해져 0.75초(29-3 · 29-4의 "둘이면 절반" 그대로).
	--   · **예고가 있는 피격(스킬·기믹·반사)을 받으면 그 구출자의 진행은 0으로 돌아간다.** 보스 평타는 끊지 않는다 -
	--     홀드 중에는 서 있어야 하므로 평타는 피할 방법이 없는 피격이다(막을 수 없는 벌은 벌이 아니다). 스킬은 전조를
	--     보고 손을 떼면 피할 수 있다(인지 0.5초).
	rescue = {
		-- completeToleranceSeconds: 홀드 시작·완료 신호가 서버에 닿기까지의 지연 몫. 클라의 홀드가 끝났다는 신호가
		-- 왔을 때 서버가 센 시간이 이만큼 모자라도 완료로 친다. reachSlackStuds: 클라의 프롬프트 거리와 서버 거리의 오차 몫.
		hold = { keyCode = "F", gamepadKeyCode = "ButtonX", completeToleranceSeconds = 0.35, reachSlackStuds = 2 },
		-- 때려서 깬다(빙결): 얼음에 유효 타격 requiredHits회. 구출자 1인당 hitIntervalSeconds에 한 번만 센다(보물상자와
		-- 같은 규칙 - 평타 2.5~5.7타/초의 직업 차이를 지운다). 혼자 0 · 0.5 · 1.0초 = 1.0초, 둘이면 0.5초.
		-- 근접·원거리·스킬 전부 센다(활·힐러 둘뿐인 파티도 서로를 구할 수 있어야 한다).
		-- 29-5: F 홀드는 얼음 곁(reachStuds - 얼음 덩어리의 반폭 2 + 팔 길이)에서. 얼음을 때리는 길도 그대로 남긴다 -
		-- 원거리 직업이 멀리서 구할 수 있는 유일한 구출이고, 때릴 수 있어 보이는 얼음을 때렸는데 아무 일도 없으면 안 된다.
		hitCount = { requiredHits = 3, hitIntervalSeconds = 0.5, reachStuds = 6 },
		-- 끌어낸다(속박): 29-5부터 "붙어서 걷는다"가 아니라 F 홀드다. 홀드가 차는 만큼 묻힌 친구가 **구출자 쪽으로** 끌려
		-- 나온다. reachStuds 6 = 무덤 반경 4 + 팔 길이 2 - 흰 원(무덤) 바로 밖에 서서 당기면 친구가 무덤 반경만큼 움직여 원의
		-- 테두리(= 구출자의 standoffStuds 앞)에서 풀린다. 더 가까이서 당기면 구출자 앞 standoffStuds까지만 끌려온다(몸이 겹치지
		-- 않게) - 풀리는 시각은 같다. 꼬리 박힘 3초(딜타임)를 구출에 쓸지 딜에 쓸지 고르는 것이 이 구출의 값이다.
		push = { graveRadiusStuds = 4, reachStuds = 6, standoffStuds = 2 },
		-- 곁에서 끌어올린다(침수, 29-4): reachStuds 안에서 F 홀드(29-5 - 전에는 곁에 머물기만 하면 찼다). 가장 너그러운
		-- 구출이다 - 거리가 넉넉하고, 방전 뒤 7.5초 동안 새 판정이 없다.
		proximity = { reachStuds = 6 },
		-- 진짜를 찾아 때린다(결정화, 29-5): 이 보스만의 길은 "누구든 진짜 여왕을 때리면 결정화된 전원이 풀린다"이고, 공통 입력
		-- (곁 reachStuds에서 F 홀드)도 그대로 통한다 - 다른 보스에서 배운 F가 여기서만 안 되면 안 된다. 분열이 끝난 뒤(제한 시간을
		-- 넘겼거나 진짜를 찾기 전)에 남은 친구는 F로 꺼낸다.
		gimmick = { reachStuds = 6 },
		-- 닿아서 푼다(감전, 29-4): 29-5부터 닿는 순간 즉시가 아니라 **몸이 닿는 거리(reachStuds 3)에서 F 홀드**다. rescuerMaxHpFraction = 구출자가 "나눠 받는" 최대체력
		-- 비율 - 28-2·29-1의 18.3%(= 55% ÷ 3)를 **0으로 내렸다**(PRD 20.79): 보스전 중 기본 자동회복이 없어(29-3) 구출자가 낸
		-- 체력은 전투 끝까지 돌아오지 않는다. 기믹 실패 55% + 강타류 42.9% = 97.9%의 여유 2.1%가 "한 번은 버틴다"의 전부인데
		-- 18.3%를 내면 구출자는 다음 실수 한 번에 죽는다 - 친구를 구한 사람이 벌받는 구조다. 값이 0보다 크면 구출자는 그만큼
		-- 받고, 체력이 그 이하면 풀리지 않는다(구출로 죽는 일은 없다) - 경로는 남겨 두고 값만 0이다.
		touch = { reachStuds = 3, rescuerMaxHpFraction = 0 },
		-- BR1 대공 잡기: 잡힌 사람은 보스 곁 공중(발 +7)에 들려 있다 - 땅에서 보스 곁(수평 16 안)이면 F 홀드. 프롬프트 거리는 3D라 높이만큼 넉넉하게.
		grab = { reachStuds = 16 },
	},

	-- BR1 대공 잡기(docs/design/boss-br1.md §2 - 6종 공통 규칙, 모션만 보스별). 스킬 primitive = "grab".
	--   airSeconds(N) 1.2: 판정 순간 연속 체공이 이 이상인 사람 전원. 1단 + 공중 점프 1(1.04초)은 안전, 공중 2회(1.54) · 공중 + 대시(1.46)는 걸린다.
	--   warnAirSeconds 0.6: 이만큼 떠 있으면 머리 위 작은 손바닥이 차기 시작한다(발동 조건 memberAirborneFor와 같은 값 - 땅에서만 싸우면 안 온다).
	--   holdSeconds 3.0 뒤 던짐(throw - 기존 넉백 상한 규칙 · 맵 밖이면 기존 복귀) + 현재 체력 × currentHpFraction(방어 무시 · 받는 피해 감소 · 쉴드 적용 - 설계 §2 결정).
	--   holdLiftStuds = 잡힌 사람의 발 높이(아레나 바닥 기준) - 땅의 동료가 손을 때릴 수 있는 높이(판정 높이차 ≤ 8). holdOffsetStuds = 보스에서 그 사람 쪽 수평 거리.
	--   해제: 동료가 손(구출 대상)을 rescueHits회(구출자 1인당 hitIntervalSeconds에 한 번) 또는 곁(rescue.grab.reachStuds)에서 F 홀드 → 풀림 + 보스 기절 stunSeconds.
	--   발버둥(본인): 점프 누를 때마다 남은 시간 − secondsPerPress(초당 maxPressesPerSecond회까지 인정), 잡힌 뒤 minHoldSeconds 전에는 안 풀린다.
	airGrab = {
		warnAirSeconds = 0.6,
		airSeconds = 1.2,
		holdSeconds = 3.0,
		holdLiftStuds = 7,
		holdOffsetStuds = 6,
		throw = { heightStuds = 7.5, distanceStuds = 30 },
		currentHpFraction = 0.5,
		stunSeconds = 3.5,
		struggle = { secondsPerPress = 0.25, maxPressesPerSecond = 6, minHoldSeconds = 0.8 },
		rescueHits = { requiredHits = 3, hitIntervalSeconds = 0.5 },
		maxAirSeconds = 1.961, -- 한 체공 최대(공중 점프 2 + 대시 - movement-metrics v2 · JumpMath.maxAirSeconds) - 회피 검사 "보고 착지"의 기준
	},

	-- BR1 핵심 기믹 실패(설계 §3): 55% → 85% · 쉴드 무시. 기믹 판정 실패(resolveGimmick)에만 쓴다 - 다른 %최대체력 피해(돌진 · 구덩이 · 반사 · 분신)는
	-- 옛 발동당 상한(gimmickFailMaxHpFraction 55%)에 그대로 묶인다. 85%는 "실패 + 강한 공격 한 번 = 죽음"이면서 단독으로는 죽지 않는 값(즉사는 K 단계).
	gimmickFail = { maxHpFraction = 0.85, ignoresShield = true },

	-- BR1 환경 변화 공통(설계 §4): 환경 발동 하나에서 한 사람이 받는 도트 합 상한(기존 발동당 상한과 같은 55%) · 겹침(§4-3 - 환경이 도는 동안
	-- "피할 수 없음" 쌍의 패턴은 나올 차례에 deferChance로 미루고(deferSeconds 뒤 다시 후보) 같은 발동 안에서 두 번 나오지 않는다).
	-- overlap.check = 자동 분류기(shared/BossOverlap) - trials번 무작위 배치 · 탈출 지점을 directions 방위 × stepStuds 간격(최대 maxStuds)으로 찾는다 ·
	-- 분위 percentile의 필요 시간으로 가른다(여유 ×1.25 통과 = 피할 수 있음 · ×1.0만 통과 = 어려움 · 둘 다 실패 = 피할 수 없음 - 공중으로만 피하면 어려움).
	environment = {
		maxHpFractionPerActivation = 0.55,
		overlap = {
			deferChance = 0.7, deferSeconds = 1.0,
			check = { trials = 24, directions = 36, stepStuds = 1, maxStuds = 60, percentile = 0.95, seed = 7, standoffStuds = 8, airRiseSeconds = 0.45 },
		},
	},

	-- 29-3 반사(전갈 여왕 갑각 태세): 타격 수가 아니라 시간 창으로 센다 - windowSeconds에 한 번. 평타 빈도가 직업마다
	-- 2.5~5.7타/초라 타격당으로 세면 쌍검만 두 배로 벌받는다(20.73 [2-5]). 1회 = gimmickFailMaxHpFraction ÷ partialFailDivisor.
	reflect = { windowSeconds = 0.75 },

	-- 29-5 탱커 대비 훅(PRD 20.80 [F]) - 탱커 직업은 아직 없다. 보스 코드를 나중에 다시 뜯지 않게 **자리만** 만들어 둔다:
	--   ① 스킬의 reflectable 필드(아래 스킬표 - 없으면 false. BossSkillMath.isReflectable) - 직선·회오리·갑각의 반사만 true다.
	--      바닥에 깔리는 원·퍼지는 고리·전역 기믹은 "날아오는 것"이 아니라 되돌릴 대상이 없다.
	--   ② 도발 인터럽트: BossPatterns.onTaunt → BossScheduler.noteTaunt(지금은 기록만 하고 아무것도 바꾸지 않는다)
	--   ③ 넉백·띄우기의 무게 계수: BossMechanics.weightFactorOf(player) → 높이·거리·체공·면역 시간을 나눈다(지금은 전원 defaultWeightFactor)
	--   ④ 반사 누적 버퍼: BossMechanics.reflectBufferOf/addToReflectBuffer/clearReflectBuffer(아무도 채우지 않는다)
	tank = { defaultWeightFactor = 1.0 },

	-- 29-3 보스전 중에는 기본 자동회복(CombatConfig.regenPercentPerSecond)이 돌지 않는다 - 재생 옵션이 얹는 몫과 흡혈은
	-- 그대로다(플레이어가 골라서 낀 빌드다). 견습 보스전은 예외(배우는 자리). PlayerRegen.server.lua가 읽는다.
	bossFight = { baseRegenEnabled = false },

	-- 28-2 [1-5] 힌트 단계: 전멸 1회 = 말풍선 ×bubbleScale + 안전지대 흰 화살표, 2회 이상 = 기믹 예고 ×telegraphMultiplier.
	hint = {
		maxLevel = 2,
		bubbleScale = 1.5,
		telegraphMultiplier = 1.5,
	},

	-- S14(PRD 20.81 [C-3]) 스테이지 25 이후의 난이도는 범위가 아니라 **낙하 원의 개수**가 맡는다(범위 배율은 25에서 1.152로 멈춘다 -
	-- 보장되지 않는 속도를 전제로 넓히면 "피할 수 없는 패턴"이 된다). extra(S) = min(maxExtra, floor((S - startStage) ÷ stepStages)) -
	-- (P2.5c 전 번호) 스테이지 50부터 +1 · 75부터 +2 · 100부터 +3 - 지금은 355 · 535 · 715(아래 줄). densityScalable = true인 스킬의 count가 extra만큼 늘고 scatterStuds가
	-- sqrt((count + extra) ÷ count)배로 넓어진다(면적당 밀도 보존). 대상 조건: circleTarget · 동시 산개(sequential 아님) · scatterStuds > 0 ·
	-- 기믹 아님 · gate 없음(BossSkillMath.densityEligible). 검사기 BossSim.checkDensity가 합격 기준이다 - 실패하면 maxExtra = 0으로 끈다.
	-- check(검사기 파라미터): 대상의 자리에서 어느 원에도 안 덮인 가장 가까운 점까지를 directions개 방위 × stepStuds 간격으로 찾고, 그 거리 d로
	-- 필요 시간 t = perceptionSeconds + d ÷ 이동 속도 × marginFactor(회피 부등식 dodge와 같은 식)를 잰다. 합격 = t의 percentile 분위가 telegraphSeconds 이하 ·
	-- 최댓값이 telegraphSeconds + maxOverSeconds 이하.
	-- P2.5c 결정 10: 옛 25 · 25칸(k 1.155)을 같은 힘의 지금 스테이지로(힘 비율 - InfiniteStage.fromLegacyStage/Span, 보스 간격의 배수로 반올림) = 175 · 180칸
	-- → +1 = 355 · +2 = 535 · +3 = 715(옛 50 · 75 · 100과 같은 힘).
	stageDensity = { startStage = InfiniteStage.fromLegacyStage(25, STAGE_INTERVAL), stepStages = InfiniteStage.fromLegacySpan(25, STAGE_INTERVAL), maxExtra = 3, check = { directions = 72, stepStuds = 0.5, percentile = 0.99, maxOverSeconds = 0.25 } },

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
		-- BR1 첫 도전 난이도 모형(shared/BossDifficultySim - 설계 §5). 전부 **가정**이다(사람 플레이 기록이 생기면 그 값으로 바꾼다 - 보고서에 같이 싣는다).
		--   hitChance: 판정 한 번에 맞을 확률(첫 도전 - 패턴을 처음 본다). 무게(피해 몫: < 20% 작음 · < 35% 중간 · 그 위 큼) · 종류별.
		--   slack: 회피 여유(전조 − 필요 시간)가 tightSeconds 밑이면 ×tightMultiplier, looseSeconds 위면 ×looseMultiplier.
		--   airDodgeShare: 바닥 판정을 공중으로 피하는 몫(M1-0 이동 - 피한 뒤 airSecondsMin ~ Max 떠 있다 → 대공 잡기의 발동 조건 · 대상).
		--   grabCatchChance: 떠 있는 채 잡기 전조를 본 사람이 N초 전에 못 내려올 확률(첫 도전).
		--   envTicks: 환경 발동 하나에서 맞는 도트 횟수(균등 min ~ max, 확률 hitChance.env로 한 번 이상).
		--   basicExposure: 보스 평타 사거리(14) 안에 있는 몫(스킬 사이 시간 중) - 원거리(기준 직업 활) · 근접.
		--   gimmickTrapDpsZero: 기믹 실패로 잡히면 그동안 딜 0(trap.autoReleaseSeconds).
		difficulty = {
			runs = 300,
			-- 처음 보는 판정의 확률 - 같은 스킬을 두 번째 볼 때부터 × learnedMultiplier(한 판 안에서 배운다).
			hitChance = { small = 0.25, medium = 0.3, large = 0.35, jump = 0.25, airWave = 0.4, antiAir = 0.35, gimmickFirst = 0.45, gimmickLater = 0.25, env = 0.5 },
			learnedMultiplier = 0.4,
			-- 게이트가 기믹이 아닌 스킬의 판정인 경우(폭풍 군주 낙뢰 - 피뢰침 둘을 동시에 채운다): 회차마다 풀 확률(처음 · 두 번째부터).
			gateSolveChance = { first = 0.3, later = 0.6 },
			slack = { tightSeconds = 0.15, tightMultiplier = 1.4, looseSeconds = 1.0, looseMultiplier = 0.7 },
			airDodgeShare = 0.4, airSecondsMin = 0.6, airSecondsMax = 1.9,
			grabCatchChance = 0.35,
			envTicks = { min = 1, max = 4 },
			basicExposure = { ranged = 0.12, melee = 0.45 },
			evadeSeconds = { sector = 1.0, projectile = 0.8, grab = 0.5, vortex = 2.5, chain = 0.8, ambush = 1.2 },
			envDpsMultiplier = 0.8, -- 환경이 도는 동안 딜이 줄어드는 몫(피하고 버티느라)
		},
	},
}

local P = MECHANICS.priority

-- ═══ BR1 공통 스킬(docs/design/boss-br1.md §1-1 · §2) - 6종이 같은 뼈대를 쓰고 이름 · 모션(motion = 클라 인형 스타일 키)만 다르다 ═══
-- 강화 평타: 피할 수 있는 작은 일격(무게 작음 - 전조 1.1초 · ×1.4 = 20%). 앞 100° · 반경 14 부채꼴(sector). 보스 앞 8에 선 사람이 옆으로
-- 8 × sin 50° + 1 = 7.1 → 0.5 + 7.1 ÷ 16 × 1.25 = 1.05초 ≤ 1.1. 뒤로 물러나도 되고 공중 점프 1회(발 13.3 > 8)로도 피한다.
local function enhancedBasic(label, motion)
	return {
		primitive = "sector", bubble = "swipe", motion = motion,
		cooldownSeconds = 7, priority = P.normal,
		conditions = { { type = "targetWithin", studs = 14 } },
		telegraphSeconds = 1.1, angleDeg = 100, radiusStuds = 14, facing = "target",
		dodge = { distanceStuds = 7.1 },
		damage = { kind = "attack", multiplier = 1.4 }, damageLabel = label,
	}
end

-- 대공 잡기(§2): 누군가 연속 체공 ≥ warnAirSeconds일 때만 쓴다(땅에서만 싸우면 안 온다 - 공중 남용에 대한 대답). 전조 2.5초(큰 모션 - 손 · 꼬리 ·
-- 집게를 하늘로) = 보고 내려올 시간(한 체공 최대 1.96초 + 인지 0.5). 판정 = 그 순간 연속 체공 ≥ airGrab.airSeconds인 사람 전원(BossAirGrab).
local function airGrab(label, motion)
	return {
		primitive = "grab", bubble = "grab", motion = motion,
		cooldownSeconds = 16, firstAvailableSeconds = 20, priority = P.normal,
		conditions = { { type = "memberAirborneFor", seconds = MECHANICS.airGrab.warnAirSeconds } },
		telegraphSeconds = 2.5,
		trap = { kind = "grabbed", rescueType = "grab" },
		damage = { kind = "currentHp", fraction = MECHANICS.airGrab.currentHpFraction }, damageLabel = label,
		sim = { evadeSeconds = 0.5 },
	}
end

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
			-- BR1(무게 원칙 §1): 피해 ×3(42.9% - 큼)에 전조 1.5(중간)는 어긋났다 → 2.0초(두 주먹을 머리 위로 크게).
			telegraphSeconds = 2.0, radiusStuds = 14,
			damage = { kind = "attack", multiplier = 3 }, damageLabel = "강공격",
		},
		-- 진동파. 보스가 hopHeightStuds만큼 떠올랐다 찍는 동작이 예고이고 찍는 순간 파동이 waveSpeedStuds로
		-- 퍼진다. 24 > 걷기 16이라 뛰어서는 못 피한다(점프가 유일한 답). 판정은 "파동 두께가 플레이어를
		-- 지나는 동안 한 순간이라도 공중이었는가" - 점프 입력 창 = 체공 0.54 + 통과 4/24 = 0.71초.
		-- waveCount 3 = 줄넘기: repeatIntervalSeconds 1.5 ≥ 체공 0.54 + 반응·입력 0.35 + 통과 0.17 + 여유 0.44.
		-- P3c A1 리듬 "느림 · 느림 · 빠름": 박자 간격 1.6 → 1.25(마지막 박자가 당겨진다). 속도는 같다 - 같은 자리에 닿는 시각 차 = 간격
		-- (1.6 · 1.25 ≥ 다시 뛰기 1.175 = 인지 0.5 + 체공 0.54 × 여유 1.25). 파동 수 · 속도가 같아 회피 비용은 그대로, 구속 시간은 0.15초 짧다.
		shockwave = {
			primitive = "ring", bubble = "shockwave",
			cooldownSeconds = 11, priority = P.normal,
			telegraphSeconds = 1.2, waveCount = 3, repeatIntervalSeconds = 1.5,
			-- BR1(공중 전제 §2 "땅 · 공중 겹침"): 2박째 = 공중 파동(발 높이 지면 + 4 ~ 14만 친다) - 1 · 3박은 뛰고 2박은 **서 있어야** 한다. 계속 떠 있기로는 못 버틴다.
			rhythm = { label = "느림 · 느림(공중) · 빠름", { speedStuds = 24 }, { gapSeconds = 1.6, speedStuds = 24, air = { minStuds = 4, maxStuds = 14 } }, { gapSeconds = 1.25, speedStuds = 24 } },
			waveSpeedStuds = 24, waveThicknessStuds = 4, hopHeightStuds = 4,
			-- 공중 판정 여유 - 지면 거리가 서 있을 때(HipHeight + 루트 반높이)보다 이만큼 더 크면 공중(21-3 실측).
			airborneClearanceStuds = 0.5,
			damage = { kind = "attack", multiplier = 2 }, damageLabel = "진동파",
			onComplete = { { type = "regrowObstacles", count = 1 } }, -- P3d D1 지형 재생성(찍은 뒤 전역 쿨 안에 1개 - BossArenaMapData.regrow)
		},
		-- 낙석. 표적 장판 count개(첫 장판은 대상 현재 위치, 나머지는 scatterStuds 안 랜덤). 좌표 고정형이라
		-- "계속 움직이는 사람은 안 맞는다". 회피 = 반경 6 + 1 = 7stud.
		meteor = {
			primitive = "circleTarget", bubble = "meteor",
			cooldownSeconds = 13, priority = P.normal,
			telegraphSeconds = 1.5, count = 3, radiusStuds = 6, scatterStuds = 10, densityScalable = true,
			damage = { kind = "attack", multiplier = 2 }, damageLabel = "낙석",
		},
		-- 정신집중 → 돌진. 느낌표가 뜨는 순간 대상 좌표를 고정하고(추적 안 함 - 회피가 실력이 되는 핵심)
		-- telegraphSeconds 뒤 그 좌표를 지나 벽까지 speedStuds로 직진한다. 방어 무관(직업 무관하게 회피를 강제).
		-- 경로 반폭 4 + 캐릭터 반폭 1 = 5stud 옆걸음. 벽(arenaMarginStuds 안쪽)에서 멈추고 recoverSeconds 동안
		-- 헤롱거린다 - 돌진을 피한 사람에게만 주어지는 딜타임이다.
		charge = {
			primitive = "charge", bubble = "charge",
			cooldownSeconds = 15, priority = P.normal,
			-- BR1(사용자 - 돌진은 전조를 크게): 1.5 → 2.2초(발 긁기가 길어진다). 피해 55%는 그대로.
			telegraphSeconds = 2.2, speedStuds = 60, pathHalfWidthStuds = 4, dashCount = 1,
			recoverSeconds = 4.0, dazeSinkStuds = 1.2, dazeTiltDeg = 25,
			arenaMarginStuds = 4, -- 보스 몸통 반폭(1.2×3=3.6)보다 조금 크게
			damage = { kind = "maxHp", fraction = 0.55 }, damageLabel = "돌진",
		},
		-- 십자 화염. 보스 중심 4방향(첫 볼리는 대상 방향, 90도 간격) 벽까지. 두 번째 볼리는 rotateDeg 돌려서 -
		-- 첫 볼리를 피해 대각선에 섰으면 다시 옆으로 걸어야 한다. 회피 = 옆으로 3 + 1 = 4stud.
		cross = {
			primitive = "line", bubble = "cross", reflectable = true, -- 29-5 탱커 훅: 탱커의 반사가 되돌릴 수 있는 스킬(지금은 아무도 안 읽는다 - PRD 20.80 [F])
			cooldownSeconds = 17, priority = P.normal,
			telegraphSeconds = 1.5, directions = 4, stepDeg = 90, volleys = 2, rotateDeg = 45, halfWidthStuds = 3,
			damage = { kind = "attack", multiplier = 2 }, damageLabel = "십자 화염",
		},
		swipe = enhancedBasic("방패 후려치기", "fist"), -- BR1 강화 평타
		grab = airGrab("움켜쥐기", "hand"), -- BR1 대공 잡기
		-- BR1 새 ① 쌍권 연타: 좌 · 우 주먹을 번갈아 내려찍는다 - 점점 크게(작게 → 크게, 무게 원칙). 매 칸은 그 순간 대상의 자리(계속 걸어라).
		--   칸 = 반경 5 · 5 · 6 · 10, 전조 1.1 · 1.1 · 1.2 · 1.55, 배율 ×0.8 · ×0.8 · ×1.0(작음) · ×2.2(31% - 중간). 최대 범위 배율(×1.152)에서
		--   마지막 칸 11.5 + 1 = 1.48초 ≤ 1.55(하네스 - 1.4는 0.08초 모자랐다). 공중으로 피해도 다음 칸이 착지 자리로 온다.
		fists = {
			primitive = "circleTarget", bubble = "meteor", motion = "fist",
			cooldownSeconds = 12, priority = P.normal, starvationSeconds = 45,
			telegraphSeconds = 1.1, count = 4, sequential = true, radiusStuds = 5, scatterStuds = 0,
			shots = {
				{ radiusStuds = 5, multiplier = 0.8, telegraphSeconds = 1.1 },
				{ radiusStuds = 5, multiplier = 0.8, telegraphSeconds = 1.1 },
				{ radiusStuds = 6, multiplier = 1.0, telegraphSeconds = 1.2 },
				{ radiusStuds = 10, multiplier = 2.2, telegraphSeconds = 1.55 },
			},
			damage = { kind = "attack", multiplier = 0.8 }, damageLabel = "쌍권 연타",
		},
		-- BR1 새 ② 추적 광구(대공): 두 손을 모아 빛을 뭉쳐 느린 구체 2개를 띄운다 - 공중에 뜬 사람 우선(없으면 어그로 대상). 속도 12 < 걷기 16 -
		-- 땅에서 걸으면 따돌리고, 공중에서는 느리다(내려와서 달린다). 회전 90°/초 · 반경 3(3D) · 수명 7초.
		orbs = {
			primitive = "projectile", bubble = "meteor", motion = "fist", projectileStyle = "orb",
			cooldownSeconds = 14, priority = P.normal, starvationSeconds = 45,
			telegraphSeconds = 1.2, count = 2, launchIntervalSeconds = 0.2, spreadDeg = 25,
			speedStuds = 12, turnRateDeg = 90, radiusStuds = 3, lifetimeSeconds = 7, heightMode = "air", launchHeightStuds = 9,
			targetRule = "airbornePreferred",
			damage = { kind = "attack", multiplier = 1.6 }, damageLabel = "추적 광구",
		},
		-- BR1 새 ③ 대지 가르기: 한 손을 땅에 꽂고 옆으로 긋는다 - 보스 → 대상 선의 왼쪽 또는 오른쪽 반원(반경 40)이 갈라진다(무작위).
		--   큼 = 전조 2.4초(최대 범위 배율 1.152에서 반경 46: 최악 = 가르는 선까지와 원 밖까지가 같은 자리 23 + 1 → 2.38초) · ×2.8(40%).
		--   공중 점프로도 피한다 - 충전을 쓰게 만들고(→ 대공 잡기) 착지 자리를 좁힌다.
		earthSplit = {
			primitive = "sector", bubble = "heavy", motion = "handDrag",
			cooldownSeconds = 16, priority = P.normal, starvationSeconds = 45,
			telegraphSeconds = 2.4, angleDeg = 180, radiusStuds = 40, facing = "randomSide",
			damage = { kind = "attack", multiplier = 2.8 }, damageLabel = "대지 가르기",
		},
	}
end

-- ═══ 6종 공통 스탯 ═══
local BASE_STATS = {
	-- 잡몹(MonsterData.tier1) 대비 배율. 실제 수치는 그 스테이지의 잡몹 값에 곱해서 매번 계산한다
	-- (BossRules.buildInstanceData) - 여기 절대값을 박지 않는다.
	-- BR1(사용자): 보스 HP = 그 스테이지 첫 도전 대표 전력의 60초분. 대표 전력 = 권장 스테이지에서 잡몹을 killTargetSeconds(2.5초)에 잡는 앵커(BalanceAnchorConfig) -
	-- 잡몹 HP × (60 ÷ 2.5) = × 24(옛 20 = 50초분). 숫자를 박지 않고 두 원본 값에서 유도한다(MECHANICS.sim.referenceKillSeconds).
	hpMultiplier = MECHANICS.sim.referenceKillSeconds / BalanceAnchorConfig.killTargetSeconds,
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
MECHANICS.rescue.hitCount.blockColor = frostHead -- 구출 대상(얼음 덩어리)의 색 - 얼음 기둥과 같은 기존 색
local stormBody, stormHead = tierColor("tier3")
local scorpionBody, scorpionHead = tierColor("tier4")
local crystalBody, crystalHead = tierColor("tier6")

-- 전갈 여왕의 아레나 kit(29-3) - 파트 10개(상한 40). offset은 아레나 중심·바닥 윗면 기준.
-- P3a C(원형 아레나): 돌진은 벽에서 arenaMarginStuds(5) 안쪽 = 중심에서 반경 − 5에서 멈춘다 - 웅덩이(반경 5) 중심을 반경 − 9에 둬 그 자리를 덮는다(옛 87 = 91 − 4와 같은 뜻).
-- 폐허 기둥(장식 · 충돌 없음)은 벽 안쪽 고리(반경 − 10)에 웅덩이 · 입장 방위(+Z)를 피해 선다(옛 정사각형 가장자리 자리의 원형판).
local function scorpionKitParts(ruinColor, sandColor)
	local parts = {}
	for _, x in ipairs({ -(ARENA_RADIUS - 9), ARENA_RADIUS - 9 }) do
		table.insert(parts, {
			name = "Quicksand", shape = "cylinder", size = Vector3.new(0.2, 10, 10), rotationDeg = Vector3.new(0, 0, 90),
			offset = Vector3.new(x, 0.1, 0), color = sandColor, material = Enum.Material.Sand, collide = false,
			tag = "quicksand", radiusStuds = 5,
		})
	end
	for index, angleDeg in ipairs({ 30, 60, 120, 150, 210, 240, 300, 330 }) do
		local height = 6 + (index % 3) * 3
		local angle = math.rad(angleDeg)
		table.insert(parts, {
			name = "RuinPillar", size = Vector3.new(4, height, 4),
			offset = Vector3.new(math.cos(angle) * (ARENA_RADIUS - 10), height / 2, math.sin(angle) * (ARENA_RADIUS - 10)),
			color = ruinColor, material = Enum.Material.Sandstone, collide = false,
		})
	end
	return parts
end

-- 심해 군주의 아레나 kit(29-4) - 옛 정사각형(반폭 96)은 돌단 4곳(±48, ±48) - 어느 자리에서도 가장 가까운 단 윗면까지 56.6stud.
-- P3a C(원형 반경 120): 4곳으로는 그 거리를 못 지킨다(단 4곳이면 최대 약 73) → 반경 65의 방위 0 · 45 · … · 315 여덟 곳 = 8곳 × 2파트 = 16파트(상한 40).
-- P3c B4(반경 140): 한 고리로는 어떤 개수 · 반경이어도 원 안 최악이 63.6stud(12곳 · 반경 70)로 회피 57을 넘는다 - 가운데를 비워야 해서 중심 둘레가 멀어진다.
-- → 안쪽 고리(반경 40 · 방위 45 · 165 · 285) 3곳 + 바깥 고리(반경 105 · 방위 22.5 + 45k) 8곳 = 11곳 × 2파트 = 22파트(상한 40). 원 안 최악 49.8stud(하네스 격자 1stud ·
-- 29-4(가)가 다시 잰다). 안쪽 단의 가장자리는 중심에서 40 − 10√2 = 25.9 - 보스 스폰(중심)은 비어 있다. 입장 자리(+Z 90)는 바깥 단 67.5° · 112.5° 사이(각 단에서 약 40stud).
-- 결정 필요 4(P3a에서 승인된 "발판 8"과 개수가 다르다 - 반경 120을 유지하면 8곳 그대로).
-- 두 단 계단: 아랫단(20 × 20, 윗면 1) → 윗단(16 × 16, 윗면 2). 한 단이 1stud라 경사로 없이 걸어 오른다(지면 폴더 -
-- 드랍은 윗면에 놓이고 보스도 밟고 지나간다). 범람의 안전지대는 tag가 붙은 **윗단**뿐이다 - 아랫단은 물에 잠긴다.
-- 넷이 한 단에 넉넉히 선다(윗면 16 × 16, 몸통 폭 2).
local function abyssalKitParts(baseColor, topColor)
	local parts = {}
	local spots = {}
	for _, ring in ipairs({ { count = 3, radius = 40, offsetDeg = 45 }, { count = 8, radius = 105, offsetDeg = 22.5 } }) do
		for k = 0, ring.count - 1 do
			local angle = math.rad(ring.offsetDeg + 360 * k / ring.count)
			table.insert(spots, { math.cos(angle) * ring.radius, math.sin(angle) * ring.radius })
		end
	end
	for _, spot in ipairs(spots) do
		table.insert(parts, {
			name = "FloodPlatform", size = Vector3.new(20, 1, 20), offset = Vector3.new(spot[1], 0.5, spot[2]),
			color = baseColor, ground = true,
		})
		table.insert(parts, {
			name = "FloodPlatform", size = Vector3.new(16, 1, 16), offset = Vector3.new(spot[1], 1.5, spot[2]),
			color = topColor, ground = true, tag = "platform",
		})
	end
	return parts
end

-- 폭풍 군주의 아레나 kit(29-4) - 피뢰침 2개 × 2파트 = 4파트. 중심에서 X ±8(간격 16): 낙뢰의 원(반경 6, 충전 판정은 + 1)
-- 하나가 두 피뢰침을 한꺼번에 덮지 못하고(16 > 2 × 7.9 - 최대 범위 배율에서도), 솔로가 첫 낙뢰를 A 곁에서 받고 둘째 낙뢰의
-- 예고(1.5초) 안에 B의 충전 거리(7) 안으로 걸어 들어갈 수 있는(16 − 7 = 9stud → 1.20초) 간격이다. 28-2의 24stud는 인지
-- 0.5초·여유 ×1.25를 넣으면 1.83초가 필요해 성립하지 않았다(PRD 20.79). 기둥만 충돌한다(1 × 1 - 회피 동선을 안 막는다).
local function stormKitParts(baseColor, rodColor)
	local parts = {}
	for _, x in ipairs({ -8, 8 }) do
		table.insert(parts, {
			name = "LightningRodBase", size = Vector3.new(3, 0.6, 3), offset = Vector3.new(x, 0.3, 0), color = baseColor, collide = false,
		})
		table.insert(parts, {
			name = "LightningRod", size = Vector3.new(1, 12, 1), offset = Vector3.new(x, 6, 0), color = rodColor, material = Enum.Material.Metal,
			tag = "rod", radiusStuds = 6, -- radiusStuds = 과충전 방전 때 이 피뢰침 곁의 안전 반경
		})
	end
	return parts
end

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
		basicAttack = { cooldownSeconds = 1.0, damageMultiplier = 0.5, rangeStuds = 14 }, -- BR1: 피할 수 없는 평타는 절반(초당 7.1% - 6종 같음)
		scheduler = scheduler(6),
		skillOrder = { "heavy", "shockwave", "meteor", "charge", "cross", "swipe", "grab", "fists", "orbs", "earthSplit" },
		skills = guardianSkills(),
		-- BR1 환경 변화 "지반 붕괴"(체력 50%부터 · 설계 §1-2): 두 주먹으로 땅을 연타 → 멤버 발밑마다 + 1개 무작위의 원(반경 22)에 금이 가고(3초)
		-- 무너져 12초 동안 용암(0.5초마다 5% - 발 기준 같은 층). 구멍 밖으로 23 = 2.3초 ≤ 3.0. 견습 보스전에는 없다(BossEnvironment).
		environment = {
			id = "groundCollapse", style = "lava", motion = "fist", damageLabel = "지반 붕괴",
			hpBelow = 0.5, firstDelaySeconds = 3, cooldownSeconds = 35, telegraphSeconds = 3.0, durationSeconds = 12,
			zones = { shape = "circle", radiusStuds = 22, perMember = true, extra = 1 },
			tick = { seconds = 0.5, fraction = 0.05 },
		},
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
		basicAttack = { cooldownSeconds = 1.5, damageMultiplier = 0.75, rangeStuds = 14 }, -- BR1: 피할 수 없는 평타는 절반(초당 7.1% - 6종 같음)
		scheduler = scheduler(7),
		skillOrder = { "slam", "icefall", "spike", "roar", "swipe", "grab" },
		-- 29-3 동적 지형(논리 상태는 서버 BossArenaProps, 그리기·충돌은 클라 BossArenaPropsView). 얼음 기둥: 반경 3 ·
		-- 높이 10 · 최대 6개(넘으면 가장 오래된 것부터 사라진다). 그림자 폭 6stud에 네 명이 한 줄로 선다 - 기둥 하나가
		-- 파티 전원을 가린다(그림자는 벽까지 이어진다).
		props = {
			pillar = { radiusStuds = 3, heightStuds = 10, maxCount = 6, color = frostHead },
		},
		skills = {
			-- 빙결 강타(23-6의 "긴 예비동작" 흡수). 기본형 강공격과 같은 동사(밖으로 걷기)지만 더 크고 더 느리다 -
			-- 반경 18을 2.25초에. 범위에 걸친 얼음 기둥을 부순다(29-3) - 보스를 기둥 옆에서 싸우면 엄폐물을 잃는다.
			slam = {
				primitive = "circleBoss", bubble = "heavy", role = "signature",
				cooldownSeconds = 9, priority = P.signature,
				telegraphSeconds = 2.25, radiusStuds = 18,
				damage = { kind = "attack", multiplier = 3 }, damageLabel = "빙결 강타",
				onImpact = { { type = "destroyProps", prop = "pillar" } },
				onComplete = { { type = "regrowObstacles", count = 1 } }, -- P3d D1 지형 재생성(찍은 뒤 전역 쿨 안에 1개 - BossArenaMapData.regrow)
			},
			-- 낙빙. 원이 입장 인원 + 2개(솔로 3): 멤버 각자의 발밑에 하나씩 + 대상 주변에 2개. 낙하점마다 얼음 기둥이
			-- 남는다(29-3) - "어디서 피했는가" = "엄폐물이 어디 생기는가". 각자의 발밑에 떨어지므로 4인 전원이 자기
			-- 기둥을 하나씩 얻는다.
			icefall = {
				primitive = "circleTarget", bubble = "meteor",
				cooldownSeconds = 12, firstAvailableSeconds = 4, priority = P.normal, starvationSeconds = 45,
				telegraphSeconds = 1.5, count = 2, countPerMember = 1, perMember = true, radiusStuds = 5, scatterStuds = 12, densityScalable = true,
				damage = { kind = "attack", multiplier = 2 }, damageLabel = "낙빙",
				onImpact = { { type = "spawnProp", prop = "pillar" } },
			},
			-- 얼음 가시. 보스 → 대상 직선 하나. 체력이 70% 아래로 내려가야 쓰기 시작한다(HP 구간 조건). 기둥에 닿으면
			-- 거기서 끊기고 그 기둥이 부서진다(29-3) - 포효보다 싸게 "기둥이 막아 준다"를 보여 주는 스킬이다.
			spike = {
				primitive = "line", bubble = "cross", reflectable = true, -- 29-5 탱커 훅: 탱커의 반사가 되돌릴 수 있는 스킬(지금은 아무도 안 읽는다 - PRD 20.80 [F])
				cooldownSeconds = 14, priority = P.normal, starvationSeconds = 45,
				conditions = { { type = "hpBelow", value = 0.7 } },
				telegraphSeconds = 1.5, directions = 1, stepDeg = 0, volleys = 1, rotateDeg = 0, halfWidthStuds = 3,
				blockedByProp = "pillar",
				damage = { kind = "attack", multiplier = 2 }, damageLabel = "얼음 가시",
			},
			-- 눈보라 포효(기믹, 29-3). 전역 - 얼음 기둥 뒤에서만 피한다(판정은 shared/BossPropMath.isShielded). 가려 준
			-- 기둥은 부서진다.
			--   · 순서 보장: 첫 포효 16초. 낙빙이 7.0초(전역 쿨 7)에 나와 8.5초에 기둥을 남기고, 전역 쿨 7초 뒤인
			--     15.5초부터 포효가 나올 수 있다 - 자리 비우기(끝 + 전역 쿨 ≤ 첫 발동 시각)가 낙빙을 막지 않는 가장 이른
			--     정수 시각이 16이다. 10초로 두면 낙빙(8.5 + 7 = 15.5 > 10)이 자리 비우기에 막혀 **기둥 0개로 첫 포효**가 온다.
			--   · 그래도 안전지대가 없으면(강타가 기둥을 다 부쉈거나 누군가 멀리 있으면) 포효 대신 낙빙이 먼저 온다
			--     (precondition, BossScheduler 규칙 ⑦). 걸을 수 있는 거리 = (전조 3.0 − 인지 0.5) ÷ 여유 1.25 × 속도 16 =
			--     32stud. 기둥 뒤 자리까지의 직선 27 + 기둥을 돌아 들어가는 몫 4(반경 3의 반 바퀴 − 지름) = 회피 거리 31
			--     (dodge.distanceStuds, 2.92초 ≤ 3.0) - 남는 1stud가 여유다.
			roar = {
				primitive = "gimmick", bubble = "roar", role = "gimmick", kind = "behindProp",
				-- 쿨 21(29-5 튜닝 - 전 20): 몬테카를로 200회에서 초회 ÷ 파훼 후가 x2.71로 허용 구간(1.8 ~ 2.7)을 넘었다 → x2.60. 세 박자
				-- (낙빙 → 포효 → 강타)와 첫 포효 16초·기둥 3개는 그대로다(실제 BossPatterns 300초 로그).
				cooldownSeconds = 21, firstAvailableSeconds = 16, reserveFirstUse = true, priority = P.gimmick,
				precondition = { type = "membersNearSafeSpot", prop = "pillar", studs = 27, marginStuds = 2, otherwise = "icefall" },
				telegraphSeconds = 3.0, recoverSeconds = 1.0,
				dodge = { distanceStuds = 31 },
				safeProp = "pillar", -- 클라가 이 지형의 그림자만 비우고 바닥 전체를 빨강으로 깐다 · 힌트 화살표의 자리
				onResolve = { { type = "destroyProps", prop = "pillar", which = "shielding" } },
				damage = { kind = "maxHp", fraction = MECHANICS.gimmickFailMaxHpFraction }, damageLabel = "눈보라 포효",
				sim = { evadeSeconds = 2.0 },
			},
			swipe = enhancedBasic("서리 주먹", "fist"), -- BR1 강화 평타
			grab = airGrab("서리 손아귀", "hand"), -- BR1 대공 잡기
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
		basicAttack = { cooldownSeconds = 1.0, damageMultiplier = 0.5, rangeStuds = 14 }, -- BR1: 피할 수 없는 평타는 절반(초당 7.1% - 6종 같음)
		scheduler = scheduler(6),
		skillOrder = { "sweep", "tide", "spout", "flood", "swipe", "grab" },
		arenaKit = { parts = abyssalKitParts(abyssalBody, abyssalHead) }, -- 29-4 수몰 사원의 돌단(P3c: 11곳)
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
			-- P3c A1 리듬 "두 겹 시간차 · 빠름 → 보통 → 느림": 파동 속도 30 · 24 · 18(전부 걷기 16보다 빨라 점프가 유일한 답), 겹 간격 = 두께 ÷ 그 파동 속도
			-- (두 겹이 붙어 온다 - 겹 통과 0.27 · 0.33 · 0.44초 ≤ 체공 0.54). 빠른 파동이 앞서므로 뒤 파동과의 차는 멀수록 벌어진다 - 보스 곁(8)이 최악 1.43 · 1.44초 ≥ 1.175.
			tide = {
				primitive = "ring", bubble = "shockwave", role = "signature",
				cooldownSeconds = 13, priority = P.signature,
				telegraphSeconds = 1.2, waveCount = 3, repeatIntervalSeconds = 1.5,
				rhythm = {
					label = "두 겹 시간차 · 빠름 → 보통 → 느림",
					{ speedStuds = 30, layers = 2, layerGapSeconds = 4 / 30 },
					{ gapSeconds = 1.5, speedStuds = 24, layers = 2, layerGapSeconds = 4 / 24 },
					{ gapSeconds = 1.5, speedStuds = 18, layers = 2, layerGapSeconds = 4 / 18 },
				},
				waveSpeedStuds = 24, waveThicknessStuds = 4, hopHeightStuds = 4, airborneClearanceStuds = 0.5,
				layers = 2, layerGapSeconds = 4 / 24,
				damage = { kind = "attack", multiplier = 1 }, damageLabel = "해일",
				onComplete = { { type = "regrowObstacles", count = 1 } }, -- P3d D1 지형 재생성(찍은 뒤 전역 쿨 안에 1개 - BossArenaMapData.regrow)
			},
			-- 물기둥. 기본형 낙석(동시 3개 산개)과 달리 **연발** - 하나가 터지면 그 순간의 대상 위치에 다음 것이
			-- 예고된다. 한 번 피하고 서 있으면 다음 것을 맞는다(계속 걸어라).
			spout = {
				primitive = "circleTarget", bubble = "meteor",
				cooldownSeconds = 15, priority = P.normal, starvationSeconds = 45,
				telegraphSeconds = 1.5, count = 3, sequential = true, repeatTelegraphSeconds = 1.2, radiusStuds = 6, scatterStuds = 0,
				damage = { kind = "attack", multiplier = 2 }, damageLabel = "물기둥",
			},
			-- 범람(기믹, 29-4 - 타이밍). 예고 시작 6초 뒤 방전 - 그 순간 "아직 가라앉지 않은 단(윗단) 위"여야 한다.
			--   · 단은 **그 사람이** 밟은 뒤 sinkSeconds(5초)면 **그 사람에게만** 가라앉는다 - 친구가 먼저 밟았다고 내 단이
			--     가라앉지 않는다(서버는 멤버별로 밟은 시각만 갖고, 가라앉는 그림과 발밑 충돌은 각자의 클라가 자기 시계로 한다).
			--     → 예고 뒤 1초(= 전조 − sinkSeconds) 안에 밟으면 방전 전에 발판을 잃는다. 미리 올라가 있던 사람은 예고와 함께
			--     밟은 것으로 친다. 그 1초 동안은 단 윗면도 빨강이다("아직 올라가지 마라") - 빨강이 걷히면 올라간다.
			--   · 시계는 범람이 도는 동안에만 돈다 - 범람이 시작될 때마다 네 단이 전원에게 새것이고, 끝나면 전부 돌아온다.
			--     그래서 "첫 방전 전에 밟을 단이 없다"는 상태가 구조적으로 없다(단은 정적 kit이라 스킬 순서와도 무관하다).
			--   · 물속 이동 −20%는 넣지 않았다(PRD 20.79) - 가장 먼 자리(56.6stud)에서 0.8배면 6.03초 > 전조 6.0으로 못 닿는다.
			--     회피 거리 57 = 가장 먼 자리에서 윗단 가장자리까지 56.6(BossGimmickVerify가 격자로 잰다).
			--   · 힌트 2단계(예고 × 1.5 = 9초)에서는 sinkSeconds도 같은 3초만큼 늘어난다 - "너무 이른" 창은 늘 1초다.
			flood = {
				primitive = "gimmick", bubble = "flood", role = "gimmick", kind = "onZone",
				cooldownSeconds = 20, firstAvailableSeconds = 10, reserveFirstUse = true, priority = P.gimmick,
				telegraphSeconds = 6.0, recoverSeconds = 1.5,
				safeZone = { tag = "platform", sinkSeconds = 5.0, shakeSeconds = 1.0, waterRiseStuds = 1.5 },
				dodge = { distanceStuds = 57 },
				damage = { kind = "maxHp", fraction = MECHANICS.gimmickFailMaxHpFraction }, damageLabel = "방전",
				-- 방전을 쏟아낸 직후 3초는 기회 창이다(파랑 말풍선). 노브: 단이 사분면 한가운데로 옮겨 가며(어디서든 닿게) 오가는
				-- 길이 길어졌다 - 회피 비용 3.0 → 3.5초(단 20stud 곁에서 싸우는 사람: 가기 1.25 + 오기 1.25 + 여유 1). 창이 없으면
				-- 몬테카를로 +8.7%로 ±10%의 가장자리다.
				breakWindow = { seconds = 3, damageTakenMultiplier = 1.3 },
				sim = { evadeSeconds = 3.5 },
			},
			swipe = enhancedBasic("지느러미 베기", "fin"), -- BR1 강화 평타
			grab = airGrab("꼬리 감기", "tail"), -- BR1 대공 잡기
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
		basicAttack = { cooldownSeconds = 1.0, damageMultiplier = 0.5, rangeStuds = 14 }, -- BR1: 피할 수 없는 평타는 절반(초당 7.1% - 6종 같음)
		scheduler = scheduler(6),
		skillOrder = { "burst", "drop", "beam", "split", "swipe", "grab" },
		skills = {
			-- 파편 폭발. 두 번 터진다: 안쪽 원(반경 10) → 바깥 도넛(10 ~ 22). 밖으로 나갔다가 다시 안으로 - 기본형
			-- 강공격의 "한 번 나가면 끝"과 다르다. 펄스당 ×2(둘 다 맞아도 57%).
			burst = {
				primitive = "circleBoss", bubble = "heavy",
				cooldownSeconds = 9, priority = P.normal, starvationSeconds = 45,
				telegraphSeconds = 1.5, radiusStuds = 22,
				pulses = { { innerRadiusStuds = 0, radiusStuds = 10 }, { innerRadiusStuds = 10, radiusStuds = 22 } },
				damage = { kind = "attack", multiplier = 2 }, damageLabel = "파편 폭발",
				onComplete = { { type = "regrowObstacles", count = 1 } }, -- P3d D1 지형 재생성(찍은 뒤 전역 쿨 안에 1개 - BossArenaMapData.regrow)
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
				primitive = "line", bubble = "cross", reflectable = true, -- 29-5 탱커 훅: 탱커의 반사가 되돌릴 수 있는 스킬(지금은 아무도 안 읽는다 - PRD 20.80 [F])
				cooldownSeconds = 14, priority = P.normal, starvationSeconds = 45,
				telegraphSeconds = 1.5, directions = 1, stepDeg = 0, volleys = 2, rotateDeg = 0, reaim = true, halfWidthStuds = 3,
				damage = { kind = "attack", multiplier = 2 }, damageLabel = "반사 광선",
			},
			-- 프리즘 분열(기믹, 29-5 - 대상 선택). 여왕이 넷으로 갈라진다: 분열 중심(지금 자리)의 네 방위 radiusStuds에 진짜 1 + 분신 3.
			-- 넷 다 발밑에 빨강 원(circleRadiusStuds)이 깔리고 **진짜의 원에서만 흰 원이 자란다**(제한 시간의 카운트다운 - 낙석의
			-- "안쪽에서 자라는 흰 원"과 같은 문법). 분신은 겉모습이 진짜와 완전히 같다 - 구분은 색이 아니라 움직임이다(색약에서도 같다).
			--   · 제한 8초 안에 진짜를 때리면: 분신 소멸 · 결정화된 친구 전원 해제 · 기절 4초(받는 피해 ×1.3, 파랑 말풍선).
			--   · 분신을 때리면: 그 분신이 깨지고 **때린 사람에게** 55% ÷ 3 = 18.3% + 결정화. 8초를 넘기면 파편 폭풍 55%(잡힘 없음 -
			--     failTraps). 둘 다 발동당 1인 상한을 같이 쓴다 - 한 번의 분열에서 받는 합은 55%를 넘지 않는다(BossPatterns.beginSplit).
			--   · 말풍선이 없다(bubble = "none"): 말풍선은 "보스"의 머리 위에만 뜬다 - 띄우면 그것이 진짜를 가리킨다.
			--   · 도달 가능성(29-3·29-4의 교훈 - 검사기는 "걸을 시간"만 묻는다): 발동 조건 memberWithin 40 → 그 사람이 가장 먼
			--     자리의 진짜까지 40 + 20 = 60stud → 0.5 + 60 ÷ 16 × 1.25 = 5.19초 ≤ 8초. 닿을 수 있는 사람이 없으면 쏘지 않는다.
			--   · 힌트 1단계 = 진짜의 자리 위에 흰 ▼, 2단계 = 제한 시간 8 → 12초.
			split = {
				primitive = "gimmick", bubble = "none", role = "gimmick", kind = "hitReal",
				cooldownSeconds = 20, firstAvailableSeconds = 10, reserveFirstUse = true, priority = P.gimmick,
				conditions = { { type = "memberWithin", studs = 40 } },
				telegraphSeconds = 8.0, recoverSeconds = 4.0,
				split = { count = 4, radiusStuds = 20, circleRadiusStuds = 6, decoyLabel = "분신 반격" },
				failTraps = false,
				recoverPose = true, dazeSinkStuds = 1.2, dazeTiltDeg = 25,
				breakWindow = { seconds = 4, damageTakenMultiplier = 1.3 },
				dodge = { distanceStuds = 60 }, -- memberWithin 40 + 분열 반경 20
				damage = { kind = "maxHp", fraction = MECHANICS.gimmickFailMaxHpFraction }, damageLabel = "파편 폭풍",
				sim = { evadeSeconds = 2.5, resolveSeconds = 3.5 },
			},
			swipe = enhancedBasic("수정 채찍", "fist"), -- BR1 강화 평타
			grab = airGrab("수정 손", "hand"), -- BR1 대공 잡기
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
		basicAttack = { cooldownSeconds = 0.75, damageMultiplier = 0.375, rangeStuds = 14 }, -- BR1: 피할 수 없는 평타는 절반(초당 7.1% - 6종 같음)
		scheduler = scheduler(5),
		skillOrder = { "claw", "sting", "stab", "shell", "swipe", "grab" },
		-- 29-3 모래 유적(정적 지형 - 보스전이 시작될 때 짓고 끝나면 치운다, BossArenaKit). 유사 웅덩이 2곳(지름 10)은
		-- 동·서 벽 앞이다 - 돌진은 늘 벽까지 달리므로 "웅덩이 앞에 서서 돌진을 받으면" 마지막 돌진이 웅덩이에서 끝난다
		-- (연속 찌르기의 recoverInZone). 무너진 기둥 8개는 네 벽 앞의 장식이다(충돌 없음 - 회피 동선을 막지 않는다).
		-- 색은 기존 tier4 색 그대로. 모래 무덤(속박된 자리)은 동적이라 여기가 아니다 - 클라 BossTrapView가 그린다.
		arenaKit = { parts = scorpionKitParts(scorpionBody, scorpionHead) },
		-- 29-3 모래 구덩이(개미지옥 - 동적 지형: 서버는 자리만, 그리기와 끌어당김은 클라 BossArenaPropsView). 잠행 찌르기가
		-- 시작될 때 생기고 마지막 돌진이 끝나면(헤롱 = 딜타임 전에) 사라진다 - 스킬은 한 번에 하나이므로 갑각 태세·속박과
		-- 겹치지 않는다(속박된 사람 곁에 구덩이가 있는 일이 없다. 잡힌 사람은 어차피 면역이고 클라도 끌어당기지 않는다).
		--   · 비탈(반경 8): armSeconds(1.5초 - 돌진의 첫 예고와 같다) 뒤부터 중심으로 pullStudsPerSecond 6으로 끌려간다.
		--     걷기 16 − 6 = 10stud/s로 빠져나온다("좀 힘들다") - 끌림은 걷기의 절반을 넘지 않는다(못 나오는 구덩이는 없다).
		--   · 바닥(중심부 반경 2.5): coreTickSeconds마다 최대체력의 55% ÷ 6 = 9.17%. 그 발동의 1인 상한 55%를 돌진과 같이 쓴다.
		--   · 멤버에게서 반경 + 6stud 안에는 생기지 않는다(`spawnPropsAround.clearStuds`) - 들어가는 것은 걸어 들어간 것이다.
		props = {
			pit = {
				radiusStuds = 8, coreRadiusStuds = 2.5, heightStuds = 0, maxCount = 3, armSeconds = 1.5,
				pullStudsPerSecond = 6, coreTickSeconds = 0.75,
				coreFraction = MECHANICS.gimmickFailMaxHpFraction / 6, damageLabel = "모래 구덩이", color = scorpionHead,
				-- P3d E2(사용자 요청): 구조물 위에도 생기고, 걸친 구조물은 틱(coreTickSeconds)마다 달그락거리다 ticks번째에 무너진다(위 사람은 떨어지기만 - 피해 없음).
				breaksObstacles = { ticks = 3 },
			},
		},
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
				telegraphSeconds = 1.2, count = 3, radiusStuds = 5, scatterStuds = 10, densityScalable = true,
				damage = { kind = "attack", multiplier = 2 }, damageLabel = "독침 낙하",
			},
			-- 잠행 찌르기(23-6 "돌진 2연속" 흡수 → 29-3 잠행). 첫 돌진을 피한 자리로 둘째가 다시 겨눈다 - 한 번 피하고 멈추면
			-- 맞는다. 회당 27.5% = 둘 다 맞아도 55%. 갑각 태세 직후에는 쓰지 않는다(55 + 55 = 110%를 인접시키지 않는다).
			-- 29-3 잠행: 첫 예고의 앞 0.5초에 땅속으로 파고들고, 돌진하는 동안에는 꼬리만 지표를 가르며, 마지막 돌진 뒤 0.4초에
			-- 솟아올라 헤롱한다. 경로·속도·판정은 돌진 그대로다 - 겉모습만 바뀐다(BossPatterns HANDLERS.charge). 시작과 함께 모래
			-- 구덩이 3개가 대상 주변 14 ~ 26stud에 생긴다 - 둘째 돌진을 피할 때 "어디로 비킬 것인가"가 남는다.
			stab = {
				primitive = "charge", bubble = "charge", role = "signature",
				cooldownSeconds = 14, priority = P.signature,
				conditions = { { type = "notAfter", skills = { "shell" } } },
				-- BR1: 첫 돌진 전조 1.5 → 2.2초(repeatTelegraphSeconds = 둘째 돌진은 옛 1.5 - 첫 돌진을 피한 자리에서 다시 겨눈다)
				telegraphSeconds = 2.2, repeatTelegraphSeconds = 1.5, speedStuds = 60, pathHalfWidthStuds = 4, dashCount = 2,
				recoverSeconds = 4.0, dazeSinkStuds = 1.2, dazeTiltDeg = 25,
				-- 29-3: 마지막 돌진이 유사 웅덩이 안에서 끝나면 헤롱 6초(알면 이득인 유인 - 몰라도 손해는 없다, 20.73 [2-5]).
				recoverInZone = { tag = "quicksand", seconds = 6.0 },
				-- depthStuds 2.0: 보스 루트는 바닥 + 1.5라 몸통 윗면이 바닥 위 2.76, 꼬리 끝이 3.8이다(sizeScale 2.8) → 2.0 내려가면
				-- 몸통은 0.76만 남은 순간 가려지고 꼬리가 1.8stud 솟은 채 달린다. 더 내리면 꼬리까지 바닥 밑으로 들어간다.
				burrow = { depthStuds = 2.0, enterSeconds = 0.5, exitSeconds = 0.4, visibleParts = { "TailSpike" } },
				onStart = { { type = "spawnPropsAround", prop = "pit", count = 3, minStuds = 14, maxStuds = 26, clearStuds = 6 } },
				onEnd = { { type = "destroyProps", prop = "pit", which = "all" } },
				arenaMarginStuds = 5, -- 몸통 반폭 1.2 × 2.8 × 1.3 = 4.4보다 조금 크게
				damage = { kind = "maxHp", fraction = MECHANICS.gimmickFailMaxHpFraction / 2 }, damageLabel = "잠행 찌르기",
				onComplete = { { type = "regrowObstacles", count = 1 } }, -- P3d D1 지형 재생성(찍은 뒤 전역 쿨 안에 1개 - BossArenaMapData.regrow)
			},
			-- 갑각 태세(기믹, 29-3). 예고 1초(몸을 낮춘다) → 태세 3초(빨강 고리 - 받는 피해 0, 때린 사람에게 반사) → 꼬리
			-- 내려찍기(태세 마지막 1.5초가 예고) → 꼬리 박힘 3초(고리가 사라진다 - 때려도 되는 순간, 헤롱 자세).
			--   · 회피는 이동이 아니라 "손을 뗀다"(dodge.noticeSeconds 1.0 ≥ 인지 0.5). 판정(noHit) = 태세 동안 반사를
			--     한 번도 안 받았는가. 실패의 대가는 반사로 이미 치렀으므로 판정 실패에는 추가 피해·잡힘이 없다(failPenalty).
			--   · 반사 1회 = 55% ÷ 3 = 18.3%, 0.75초 창당 1회, 합계는 발동당 상한 55%에서 잘린다(28-2의 20% × 3 = 60%는
			--     "기믹 1회로 죽지 않는다"의 상한을 넘겨 29-1에서 내렸다). 상세는 BossMechanics.beginReflect.
			--   · 꼬리 내려찍기(finisher): 보스 앞 8stud의 원 r8, ×2(방어 적용) + 속박(모래 무덤). 예고 1.5초 - 28-2의 1.0초는
			--     원 한가운데의 근접 자리(9stud)에서 1.20초가 필요해 회피 부등식을 못 넘는다.
			shell = {
				primitive = "gimmick", bubble = "shell", role = "gimmick", kind = "noHit",
				reflectable = true, -- 29-5 탱커 훅: 갑각의 반사는 탱커의 반사로 되돌릴 수 있다("반사 대 반사" - PRD 20.80 [F]). 지금은 아무도 안 읽는다
				cooldownSeconds = 18, firstAvailableSeconds = 10, reserveFirstUse = true, priority = P.gimmick,
				conditions = { { type = "notAfter", skills = { "stab" } } },
				telegraphSeconds = 4.0, recoverSeconds = 3.0,
				stance = { afterSeconds = 1.0, damageTakenMultiplier = 0, ringRadiusStuds = 5, sinkStuds = 1.0 },
				failPenalty = false,
				finisher = {
					telegraphSeconds = 1.5, radiusStuds = 8, offsetStuds = 8, trapOnHit = true,
					damage = { kind = "attack", multiplier = 2 }, damageLabel = "꼬리 내려찍기",
				},
				recoverPose = true, dazeSinkStuds = 1.2, dazeTiltDeg = 25,
				breakWindow = { seconds = 3, damageTakenMultiplier = 1.5 },
				dodge = { distanceStuds = 0, noticeSeconds = 1.0 }, -- 예고 1초 안에 공격을 멈추면 된다
				damage = { kind = "maxHp", fraction = MECHANICS.gimmickFailMaxHpFraction }, damageLabel = "갑각 반사",
				sim = { evadeSeconds = 4.0 },
			},
			swipe = enhancedBasic("집게 찰싹", "claw"), -- BR1 강화 평타
			grab = airGrab("집게 낚아채기", "claw"), -- BR1 대공 잡기
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
		basicAttack = { cooldownSeconds = 0.75, damageMultiplier = 0.375, rangeStuds = 14 }, -- BR1: 피할 수 없는 평타는 절반(초당 7.1% - 6종 같음)
		scheduler = scheduler(5),
		skillOrder = { "discharge", "whirl", "strike", "overcharge", "swipe", "grab" },
		arenaKit = { parts = stormKitParts(stormBody, stormHead) }, -- 29-4 폭풍 첨탑의 피뢰침 2개
		skills = {
			-- 방전 고리. 파동 하나 - 기본형 강공격 자리의 스킬이지만 걸어서가 아니라 **뛰어서** 피한다.
			-- P3c A1 리듬 "천둥 · 메아리": 빠른 파동(36) 뒤 1.3초에 느린 메아리(20). 빠른 쪽이 앞서 차는 멀수록 벌어진다 - 보스 곁(8) 최악 1.48초 ≥ 1.175.
			-- 파동이 둘이 되며 한 파동의 피해를 ×3 → ×1.5로 나눴다(둘 다 맞으면 옛 한 방과 같다 - 결정 필요 2: 회피 비용이 파동 하나만큼 늘어 처치 시간 모형이 바뀐다).
			discharge = {
				primitive = "ring", bubble = "shockwave",
				cooldownSeconds = 9, priority = P.normal, starvationSeconds = 40,
				telegraphSeconds = 1.2, waveCount = 1, repeatIntervalSeconds = 1.5,
				rhythm = { label = "천둥 · 메아리", { speedStuds = 36 }, { gapSeconds = 1.3, speedStuds = 20 } },
				waveSpeedStuds = 24, waveThicknessStuds = 4, hopHeightStuds = 4, airborneClearanceStuds = 0.5,
				damage = { kind = "attack", multiplier = 1.5 }, damageLabel = "방전 고리",
				onComplete = { { type = "regrowObstacles", count = 1 } }, -- P3d D1 지형 재생성(찍은 뒤 전역 쿨 안에 1개 - BossArenaMapData.regrow)
			},
			-- 회오리(29-4 - 28-2의 "연쇄 번개" 직선 자리를 대신한다, PRD 20.77 [1] · 20.79). 대상 위치의 원 하나 - 맞으면 그 자리에서
			-- 공중으로 떠올라 원을 그리며 돌다가 내려온다. 낙뢰의 넉백과 **같은 결과 조각**(onHit = launch)이고 파라미터만 늘었다:
			--   heightStuds 6 · distanceStuds 0(날아가지 않는다 - 제자리) · holdSeconds 1.5(떠서 도는 시간) · spinRadiusStuds 3.
			--   뜨는 것은 그 사람의 클라가 자기 캐릭터로 한다(BossStormView). 뜬 동안 카메라는 회오리 중심에 묶인다.
			--   immuneSeconds 2.5 = 뜨기 0.3 + 돌기 1.5 + 내려오기 ≈ 0.25 + 일어나기 - 조작을 잃은 동안은 맞지 않는다(보스 평타는
			--   피할 수 없는 확정 피격이 된다 - 20.77 [1]의 조건 ③). 회오리 자체의 피해(×2)는 그 전에 이미 들어갔다.
			--   보스는 뜬 대상을 놓치지 않는다 - MonsterAI가 발밑 지면으로 층을 판단한다(GroundProbe.sameGroundLayer).
			whirl = {
				primitive = "circleTarget", bubble = "whirl", reflectable = true, -- 29-5 탱커 훅: 탱커의 반사가 되돌릴 수 있는 스킬 - 되돌리면 보스가 뜬다(지금은 아무도 안 읽는다 - PRD 20.80 [F])
				cooldownSeconds = 13, priority = P.normal, starvationSeconds = 40,
				telegraphSeconds = 1.5, count = 1, radiusStuds = 8, scatterStuds = 0,
				damage = { kind = "attack", multiplier = 2 }, damageLabel = "회오리",
				impactStyle = "whirl",
				onHit = { { type = "launch", heightStuds = 6, distanceStuds = 0, holdSeconds = 1.5, spinRadiusStuds = 3, immuneSeconds = 2.5 } },
			},
			-- 낙뢰. 대상 위치에 2연발(둘째는 그 순간의 위치). 29-4: **피뢰침 충전 수단이자 뇌운 장막(게이트)의 판정**이다.
			--   · 낙뢰의 원 안(+ chargeZone.reachStuds)에 피뢰침이 있으면 그 피뢰침이 seconds(12초) 동안 충전된다. 두 피뢰침이 동시에
			--     충전 상태가 되는 순간 장막이 걷힌다(gate.breakWindow) + 두 피뢰침은 방전된다. 낙뢰가 끝났는데 못 채웠으면 장막이
			--     선다/남는다. 장막은 첫 낙뢰 예고와 함께 선다(29-1 게이트 규칙 그대로 - 판정 스킬이 기믹이 아니라 낙뢰일 뿐이다).
			--   · 솔로: 첫 낙뢰를 A 곁에서 받고(원은 예고 순간의 자리에 고정된다) 둘째 예고 1.5초 안에 B 곁으로 9stud(route).
			--     맞아도 충전은 된다 - 충전은 "낙뢰가 어디에 떨어졌는가"이지 "피했는가"가 아니다.
			--   · 파티(perMember): 낙뢰가 **멤버 각자의 자리**에 떨어진다(두 발 다). 둘이 피뢰침을 하나씩 맡으면 첫 발에 끝나고,
			--     한 명뿐이면 솔로처럼 뛰면 된다 - 인원이 늘수록 쉬워진다. 12초 충전은 한 회차(3초)만 덮으므로 회차마다 다시 선다.
			strike = {
				primitive = "circleTarget", bubble = "meteor", role = "signature",
				cooldownSeconds = 12, firstAvailableSeconds = 8, reserveFirstUse = true, priority = P.signature,
				telegraphSeconds = 1.5, count = 2, sequential = true, repeatTelegraphSeconds = 1.5, radiusStuds = 6, scatterStuds = 0,
				perMember = true,
				damage = { kind = "attack", multiplier = 2 }, damageLabel = "낙뢰",
				onImpact = { { type = "chargeZone", tag = "rod", seconds = 12, reachStuds = 1 } },
				route = { distanceStuds = 9 }, -- 회피 부등식의 "피뢰침 사이": 간격 16 − 충전 거리 7(BossGimmick4Verify가 kit에서 다시 잰다)
				-- 29-3: 하늘에서 꽂히는 번개로 그리고(impactStyle), 맞은 사람은 팝콘처럼 판정 중심 반대쪽으로 튕겨 난다 - 높이 5
				-- (판정의 높이차 상한 8·아레나 벽 12보다 낮다 - 보스가 대상을 놓치지 않고 맵 밖으로도 못 나간다), 거리 8, 체공 ≈ 0.45초.
				-- 둘째 낙뢰는 첫 낙뢰가 떨어진 순간의 자리에 예고되므로, 튕겨 난 사람은 이미 그 원(r6) 밖이다.
				impactStyle = "lightning",
				-- P3c A4: 여러 명이 한 판정에 함께 맞으면 넉백이 높아진다 - 함께 맞은 사람 1명마다 + extraHeightPerCoHit, 상한 maxHeightStuds(1명 5 · 2명 6 · 3명 7 · 4명 7.5).
				-- 상한 7.5 = 맵 이탈 방지 상한(BossArenaMapData.containment.maxLaunchHeightStuds)과 같다 - 판정 높이차 상한 8보다 낮다.
				onHit = { { type = "launch", heightStuds = 5, distanceStuds = 8, extraHeightPerCoHit = 1, maxHeightStuds = 7.5 } },
				-- P3c A4 번개 추적: 첫 낙뢰에 맞아 튕겨 난 사람에게는 둘째 낙뢰의 원이 그 사람을 trackSeconds(0.55 = 넉백 체공 0.45 + 착지 0.1) 동안 따라가다가
				-- 멈추고, lockTelegraphSeconds(1.2) 뒤에 떨어진다 - 멈춘 뒤 1.2초 ≥ 인지 0.5 + (반경 6 × 최대 범위 배율 1.152 + 몸통 1) ÷ 16 × 1.25 = 1.12초
				-- (회피 부등식 "추적 뒤 고정" - 1.1은 배율 1에서만 성립했다, 하네스 29-4(가)). 안 맞은 사람의 원은 옛 규칙(첫 낙뢰가 떨어진 순간의 자리 · 피뢰침 유인 경로)
				-- 그대로다 - 그 회차 전체는 추적 + 고정 1.75초에 같이 떨어진다.
				trackAfterHit = { trackSeconds = 0.55, lockTelegraphSeconds = 1.2 },
				gate = { zoneTag = "rod", breakWindow = { seconds = 10, damageTakenMultiplier = 1.15 } }, -- 28-2의 ×1.3은 새 쿨 분포에서 −11.6%로 범위 밖(×1.15 = −6.5%)
				sim = { evadeSeconds = 2.5 },
			},
			-- 과충전 방전(기믹, 29-4). 장막이 30초 이어지면 전역 55% + 감전 - **피뢰침 곁(반경 6)만 안전하다**(충전 여부와 무관).
			--   · 28-2는 "충전된 피뢰침 곁"이었다. 그러면 피뢰침을 한 번도 못 채운 사람(= 과충전을 보게 되는 바로 그 사람)에게는
			--     안전지대가 아예 없다 - 서리 거인의 "기둥 0개 포효"와 같은 파훼 불가 패턴이다. 피뢰침은 정적 kit이라 늘 있다.
			--   · 장막(기믹)과의 연결: 과충전의 전조는 바닥 전체가 빨강이고 **두 피뢰침 둘레만 비어 있다** - 기믹을 못 푼 사람에게
			--     "답은 피뢰침이다"를 그림으로 알려 주는 스킬이다. 살아남은 사람은 피뢰침 곁에 서 있고, 다음 낙뢰가 거기 떨어진다.
			--   · 발동 조건: 장막 30초 + 살아 있는(안 잡힌) 전원이 피뢰침에서 nearStuds(30) 안 - 예고 3초에 닿을 수 없는 사람이
			--     있으면 쏘지 않는다(피할 수 없는 과충전은 없다). 멀리 떨어져 싸우면 과충전은 안 오지만 장막도 영영 못 걷는다.
			--   · 게이트를 바꾸지 않는다(judgesGate = false) - 장막을 걷는 것은 낙뢰뿐이다.
			overcharge = {
				primitive = "gimmick", bubble = "overcharge", role = "gimmick", kind = "nearZone",
				cooldownSeconds = 30, priority = P.gimmick,
				conditions = { { type = "gateArmedFor", seconds = 30 }, { type = "membersNearZone", tag = "rod", studs = 30 } },
				telegraphSeconds = 3.0, recoverSeconds = 0,
				safeCircles = { tag = "rod" }, judgesGate = false,
				dodge = { distanceStuds = 25 }, -- 30 − 안전 반경 6 + 몸통 1
				damage = { kind = "maxHp", fraction = MECHANICS.gimmickFailMaxHpFraction }, damageLabel = "과충전 방전",
				sim = { evadeSeconds = 2.0 },
			},
			swipe = enhancedBasic("지팡이 휘두르기", "staff"), -- BR1 강화 평타
			grab = airGrab("바람 손", "wind"), -- BR1 대공 잡기
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
	-- arenaKit(29-2 훅): 보스별 정적 지형지물 목록. 전갈 여왕·심해 군주·폭풍 군주가 갖는다 - BossArenaKit.lua. tag가 붙은 파트는 스킬이 읽는 논리 구역(shared/BossPropMath.kitZones).
	bosses[species.id] = boss
	table.insert(rotationBossIds, species.id)
end

return {
	stageInterval = STAGE_INTERVAL,
	-- G1-4(D0 결정 5 · 사용자 확정): 보스를 잡아도 보스맵에 남는다 - [다음 스테이지] · [다시 도전](파티 = 재투표 · 보스 재생성) · [마을]을 고른다.
	-- lingerSeconds 동안 아무것도 안 고르면 다음 스테이지로 자동 이동(잠수 대비 - 슬롯 12개 · 서버 16명이라 무제한 잔류는 안 된다).
	lingerSeconds = 90,
	-- P2.5a: 보스 한 간격(stageInterval)의 "힘 비율" - 파티 HP 지수 p · 파훼 게이트 배율 g(BossRules)가 이 값에서 나온다. 옛 식은 k^stageInterval(k = 몬스터 성장)이라
	-- k를 1.155 → 1.02로 바꾸면 2.056 → 1.104가 되어 4인 파티 이득(처치 시간 0.49 → 0.90배)과 파훼 게이트(받는 피해 ×0.487 → ×0.906 - "파훼 안 하면 1.8 ~ 2.7배
	-- 느림"이 1.1 ~ 1.6배로)가 무너졌다(P25a 1회차 Play - S14(가) · 29-1(가) X). 보스 · 파티 균형(29-x · S14 튜닝)은 스테이지 단위가 아니라 힘 비율로 정해진 것이라
	-- 옛 값을 그대로 둔다: 1.155^5 = 2.0560. 스테이지 환산이 필요한 곳(파티 입장 밴드)은 지금 k로 그대로 바꾼다(BossRules.partyEntryBand).
	intervalPowerRatio = 1.155 ^ 5,

	pools = {
		{ minStage = 1, bossIds = rotationBossIds },
	},

	-- 28-2 [1-3]: 견습 보스는 기본형 고정(견습의 패턴 부분집합은 5패턴 보스에만 뜻이 있다). 무한 모드의 첫 보스
	-- 스테이지도 이 보스다(placement.laps[1][1]).
	tutorialBossId = "section_guardian",

	-- 29-5 보스 배치(PRD 20.80 [A]): 보스의 정체는 **스테이지 번호만의 함수**이고 모든 유저에게 같다. n번째 보스
	-- 스테이지(= 스테이지 ÷ stageInterval)는 laps의 칸을 순서대로 읽는다 - 한 줄이 한 바퀴(6마리), 마지막 줄 다음은
	-- 첫 줄로 돌아간다(36마리 = 180스테이지 주기). 유저 상태·저장 데이터·난수를 읽지 않는다.
	--   · 1줄 = 선언 순서: 첫 보스는 기본형(전조 어휘를 배운다), 그다음 다섯에서 나머지 5종을 한 번씩 전부 만난다.
	--   · 2줄부터는 바퀴마다 순서가 다르다. 표는 6 × 6 행 완전 라틴 방진이다 - 각 보스가 바퀴의 각 자리에 한 번씩
	--     서고, "A 다음에 B"라는 이웃 쌍 30가지가 36마리 안에서 정확히 한 번씩 나온다(같은 흐름이 되풀이되지 않는다).
	--   · 같은 보스가 다시 나오기까지 최소 4마리(바퀴 경계·주기 경계 포함) - 연속 등장이 없다.
	-- 표를 고치면 BossRules.validatePlacement(자동 검증 · "/gg boss table")가 규칙 위반을 잡는다.
	placement = {
		laps = {
			{ "section_guardian", "frost_giant", "abyssal_lord", "crystal_queen", "scorpion_queen", "storm_lord" },
			{ "frost_giant", "crystal_queen", "section_guardian", "storm_lord", "abyssal_lord", "scorpion_queen" },
			{ "crystal_queen", "storm_lord", "frost_giant", "scorpion_queen", "section_guardian", "abyssal_lord" },
			{ "storm_lord", "scorpion_queen", "crystal_queen", "abyssal_lord", "frost_giant", "section_guardian" },
			{ "scorpion_queen", "abyssal_lord", "storm_lord", "section_guardian", "crystal_queen", "frost_giant" },
			{ "abyssal_lord", "section_guardian", "scorpion_queen", "frost_giant", "storm_lord", "crystal_queen" },
		},
		minRepeatGap = 4, -- 같은 보스 사이의 최소 간격(보스 스테이지 수) - validatePlacement가 검사한다
	},

	bosses = bosses,
	mechanics = MECHANICS,
}
