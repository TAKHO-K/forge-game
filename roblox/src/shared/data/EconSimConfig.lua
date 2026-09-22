-- 경제 시뮬(P0 E1 · server/EconSim.lua)의 입력표. **게임 밸런스 수치가 아니다** - 게임은 이 파일을 읽지 않는다(EconSim만 읽는다).
-- 여기 있는 값은 전부 [가정](플레이어 모형 · what-if 입력)이다. 게임 공식 · 상수는 EconSim이 실제 모듈을 require해서 쓰고, 이 파일에 옮겨 적지 않는다
-- (게임이 바뀌면 시뮬도 따라가야 한다). 개발자 · Studio 전용: DevToolsConfig.econSim이 켜져 있고 RunService:IsStudio()일 때만 EconSim이 돈다.
--
-- 명령: /gg econ [프로필|all] [what-if 이름] → 결과는 Studio 로그(출력 창)에 [ECONMD] · [ECONCSV:<표>] 줄로 찍히고,
-- docs/econ/_extract.py가 그 줄을 docs/econ/E1-<what-if>.md + CSV로 옮긴다. 채팅에는 요약만.

return {
	-- 시뮬 전체 공통
	seed = 20260923, -- 강화 시도 · 몬테카를로 난수 시드(같은 입력 → 같은 결과)
	yieldSeconds = 0.25, -- 계산이 이만큼(초) 이어지면 레벨업 사이에서 task.wait() 한 번(한 번에 계산하되 스크립트 시간 초과를 피한다 - 매 프레임 계산이 아니다)
	stallLevelHours = 200, -- 레벨업 한 번에 이 플레이 시간(시간)을 넘기면 "진행 정지"로 보고 끝낸다([없음] 사유)
	maxPlayHours = 20000, -- 누적 플레이 시간 상한(시간)
	enhanceMonteCarloTrials = 2000, -- 강화 단계별 기대 비용 표(E4)의 시행 수

	-- E3 도달 시간 곡선의 이정표(마지막 = InfiniteStageConfig.safeStageCap을 EconSim이 붙인다)
	milestones = { 10, 50, 100, 250, 500, 1000, 2000, 3000, 4000 },

	-- E4 구간(최고 스테이지 기준, 마지막 구간의 끝 = safeStageCap)
	segments = { { 1, 100 }, { 101, 500 }, { 501, 1000 }, { 1001, 3000 }, { 3001, "cap" } },

	-- E2 플레이어 프로필 3종([가정] 전부). 보스는 bossKillLimitSeconds 안에 잡을 수 있을 때만 도전한다.
	--   hoursPerDay        하루 플레이 시간
	--   classId            직업(E3 · E4는 궁수 = BalanceAnchorConfig.referenceClassId와 같은 기준)
	--   huntTierMax        갈 수 있는 가장 높은 사냥 구역 tier - 청크마다 1 ~ 이 값 중 경험치/초가 가장 좋은 구역을 고른다(5% 안이면 높은 tier - 드랍 등급)
	--   targetKillSeconds  사냥 스테이지 고르는 기준 - 로테이션 처치 시간이 이 값 이하인 가장 높은 스테이지
	--   minSurviveHits     그 스테이지 몬스터에게 버틸 타수 하한(BalanceSim.getSurviveHits)
	--   dpsEfficiency      조작 효율 - 실제 DPS = 시뮬 DPS × 이 값(스킬 순서 · 빗맞음 · 이동)
	--   moveOverheadSeconds 처치 1마리마다 붙는 이동 · 탐색 시간
	--   bossDpsEfficiency  보스전 조작 효율(패턴 회피로 딜이 끊기는 몫)
	--   bossKillLimitSeconds 이 시간 안에 잡을 수 있으면 보스에 도전
	--   bossAttemptsPerClear 클리어 1회에 드는 시도 수(실패 포함 - 보스 시간 = 처치 시간 × 이 값 + bossOverheadSeconds)
	--   partySize          보스전 파티 인원(1 = 솔로). 사냥은 솔로로 본다(파티 사냥의 1인당 효율은 [가정] 범위 밖 - S21a §4-4)
	--   partyExpBonus      사냥 중 파티 경험치 보너스를 받는가(파티 소속만 되면 거리 무관 - S21-0 D3)
	--   enhanceTarget      무기 강화 목표 단계
	--   useProtection      19강 이상에서 방지권을 사서 쓰는가
	--   rebirth            환생 가능해지면 바로 하는가
	--   gearCheckMinutes   가방 점검 간격(분) - 이 간격마다 그동안 주운 장비 · 분해 보석 중 가장 좋은 것으로 바꾼다(점수가 조금이라도 좋으면)
	--   gemReroll          고대 · 태초 보석을 원하는 축이 나올 때까지 변환권으로 다시 굴리는가
	--   gemRoll            원하는 축을 맞췄을 때의 옵션 롤 값(0.875 ~ 1.125)
	profiles = {
		casual = {
			displayName = "캐주얼", hoursPerDay = 0.5, classId = "bow", huntTierMax = 3,
			targetKillSeconds = 4.0, minSurviveHits = 5, dpsEfficiency = 0.7, moveOverheadSeconds = 1.5,
			bossDpsEfficiency = 0.6, bossKillLimitSeconds = 120, bossAttemptsPerClear = 2.0, bossOverheadSeconds = 30,
			partySize = 1, partyExpBonus = false,
			enhanceTarget = 15, useProtection = false, rebirth = true,
			gearCheckMinutes = 60, gemReroll = false, gemRoll = 1.0,
		},
		normal = {
			displayName = "일반", hoursPerDay = 1.5, classId = "bow", huntTierMax = 5,
			targetKillSeconds = 3.0, minSurviveHits = 4, dpsEfficiency = 0.85, moveOverheadSeconds = 1.0,
			bossDpsEfficiency = 0.75, bossKillLimitSeconds = 90, bossAttemptsPerClear = 1.5, bossOverheadSeconds = 20,
			partySize = 1, partyExpBonus = false,
			enhanceTarget = 20, useProtection = false, rebirth = true,
			gearCheckMinutes = 20, gemReroll = true, gemRoll = 1.0,
		},
		top = {
			displayName = "상위 1%", hoursPerDay = 6, classId = "bow", huntTierMax = 6,
			targetKillSeconds = 2.5, minSurviveHits = 3, dpsEfficiency = 0.95, moveOverheadSeconds = 0.6,
			bossDpsEfficiency = 0.9, bossKillLimitSeconds = 60, bossAttemptsPerClear = 1.1, bossOverheadSeconds = 10,
			partySize = 4, partyExpBonus = true,
			enhanceTarget = 25, useProtection = true, rebirth = true,
			gearCheckMinutes = 5, gemReroll = true, gemRoll = 1.1,
		},
	},
	profileOrder = { "casual", "normal", "top" },

	-- E5 태초 선택지(what-if 전용 - 게임 코드는 안 바뀐다). 비교: 같은 플레이어가
	--   (A) 고tier(highTier) 몬스터를 자기 사냥 스테이지보다 Δ 낮은 스테이지에서 잡기 vs (B) 저tier(lowTier)를 자기 사냥 스테이지에서 잡기.
	-- 태초 확률: A = primordialByTier[highTier], B = A ÷ 확률 배수. 스위치 ① gemLevelIsMonsterLevel(보석 레벨 = 잡은 몬스터 레벨, 끄면 = 플레이어 사냥 스테이지).
	primordial = {
		playerLevels = { 10, 150, 1000 },
		deltas = { 1, 5, 10, 30, 100 },
		probabilityMultipliers = { 2, 5, 10 },
		highTier = 6,
		lowTier = 1,
		gemLevelIsMonsterLevel = true,
		-- 현재 기본값(S21-0 D5 = MonsterData.dropGradeTableByTier). nil이면 EconSim이 게임 표에서 그대로 읽는다 - what-if만 이 칸을 채운다.
		primordialByTier = nil,
	},

	-- E6 치유사 r과 장비 성장. 장비 단계 = 딜러(와 what-if의 치유사)가 낀 딜 옵션 보석. 앵커 = 레벨 100 · 무기 등급 0 · +0강(S21-0 D2와 같은 조건).
	--   gems: { 옵션 id, 등급, itemLevel, roll } 목록(보석 칸 순서)
	healer = {
		fightRatioScenario = { hitsPerSecond = 0.25, hitRatio = 0.1026, bossHpUnitsSeconds = 600 }, -- S13b PartyShieldSim 기준 시나리오 그대로
		shareFloor = 0.10, -- 보상 문턱(CombatConfig.contributionRewardThreshold를 EconSim이 읽어 대조한다 - 이 값은 표의 기준선일 뿐)
		shareTarget = 0.12,
		gearTiers = {
			{ id = "none", displayName = "없음", gems = {} },
			{ id = "average", displayName = "평균", gems = {
				{ "attackPercent", "primordial", 100, 1.0 },
				{ "crit", "epic", 100, 1.0 },
				{ "speedPercent", "legendary", 100, 1.0 },
			} },
			{ id = "top", displayName = "상위", gems = {
				{ "attackPercent", "primordial", 125, 1.125 },
				{ "crit", "epic", 125, 1.125 },
				{ "attackPercent", "legendary", 125, 1.125 },
				{ "crit", "relic", 125, 1.125 },
				{ "speedPercent", "ancient", 125, 1.125 },
			} },
		},
		applyRates = { 0, 0.5, 0.75, 1.0 }, -- (가) 치유모드에 딜 옵션 적용률 a
		gemCoefficients = { 0, 0.3, 0.6, 0.9, 1.2, 1.5 }, -- (나) 치유모드 전용 보석 계수 m(태초 기준값 - 위력 0.30과 같은 눈금)
		dealingTargetRange = { 0.85, 0.9 }, -- 딜링모드 목표 = 딜러 × 이 범위
		dealerClasses = { "bow", "dualblade", "greatsword" },
	},

	-- E7 what-if 덮어쓰기. 이름 = /gg econ의 둘째 인자. 빈 표 = 기준선. 모든 칸은 선택:
	--   growthRate          InfiniteStageConfig.growthRate(몬스터 · 보상 · 아이템 계수 성장 k)
	--   weaponGrowthRate    CharacterLevelConfig.weaponMultGrowthRate(g)
	--   levelFactorCap      Option.levelFactor 동결 레벨(math.huge = 동결 없음) - 게임 함수의 선형 구간을 그대로 연장한다
	--   primordialByTier    { [tier] = 확률 } - E5 태초 확률표
	--   healerApplyRate     E6 (가)의 a를 한 값으로 고정해 표를 다시 낸다
	--   healerGemCoefficient E6 (나)의 m
	--   dealingMultiplier   SkillData.healer.E.attackMultiplier에 곱하는 배율
	--   enhanceCostScale    EnhanceConfig.goldCost 전체에 곱하는 배율
	whatIfs = {
		baseline = {},
		k1150 = { growthRate = 1.150 },
		g1155 = { weaponGrowthRate = 1.155 },
		unfreeze = { levelFactorCap = math.huge },
		cap500 = { levelFactorCap = 500 },
		primFlat = { primordialByTier = { [1] = 0.0001, [2] = 0.0002, [3] = 0.0003, [4] = 0.0005, [5] = 0.0007, [6] = 0.001 } },
		healA75 = { healerApplyRate = 0.75 },
		healM09 = { healerGemCoefficient = 0.9 },
		dealing087 = { dealingMultiplier = 0.87 },
		enhanceHalf = { enhanceCostScale = 0.5 },
	},
}
