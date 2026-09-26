-- 경제 시뮬(P0 E1 · server/EconSim.lua)의 입력표. **게임 밸런스 수치가 아니다** - 게임은 이 파일을 읽지 않는다(EconSim만 읽는다).
-- 여기 있는 값은 전부 [가정](플레이어 모형 · what-if 입력)이다. 게임 공식 · 상수는 EconSim이 실제 모듈을 require해서 쓰고, 이 파일에 옮겨 적지 않는다
-- (게임이 바뀌면 시뮬도 따라가야 한다). 개발자 · Studio 전용: DevToolsConfig.econSim이 켜져 있고 RunService:IsStudio()일 때만 EconSim이 돈다.
--
-- 명령: /gg econ [프로필|all] [what-if 이름] → 결과는 Studio 로그(출력 창)에 [ECONMD] · [ECONCSV:<표>] 줄로 찍히고,
-- docs/econ/_extract.py가 그 줄을 docs/econ/E1-<what-if>.md + CSV로 옮긴다. 채팅에는 요약만.

return {
	-- 시뮬 전체 공통
	partyExpRequiresPresence = true, -- P2 G: 게임 규칙(파티 경험치 보너스 = 조건 충족 파티원만)
	seed = 20260923, -- 강화 시도 · 몬테카를로 난수 시드(같은 입력 → 같은 결과)
	yieldSeconds = 0.25, -- 계산이 이만큼(초) 이어지면 레벨업 사이에서 task.wait() 한 번(한 번에 계산하되 스크립트 시간 초과를 피한다 - 매 프레임 계산이 아니다)
	-- P3c C5(사용자 확정 "첫 가방 점검 전 장비 착용 반영"): 첫 가방 점검 시각(분) - 견습 1단계(슬라임 25마리 ≈ 2분)가 가방을 열어 착용하라고 가르친다.
	firstGearCheckMinutes = 2,
	stallLevelHours = 200, -- 레벨업 한 번에 이 플레이 시간(시간)을 넘기면 "진행 정지"로 보고 끝낸다([없음] 사유)
	maxPlayHours = 20000, -- 누적 플레이 시간 상한(시간)
	enhanceMonteCarloTrials = 2000, -- 강화 단계별 기대 비용 표(E4)의 시행 수
	-- D1: 보스 첫 클리어 장비를 모형에 넣는가(누적 기대 도착 - server/EconSim fightBosses). D1 전 모형은 이 장비를 안 셌다(보스 드랍이 상위 등급의
	-- 주 공급원이 된 D1부터 켠다 - what-if modelBossDrops = false로 옛 모형과 비교).
	modelBossDrops = true,
	-- D1-2(사용자 지시 "보스 장비 포함 = 현실"): 보스 장비 itemLevel = 보스 스테이지 + 게임 편차표(ArmorData.bossItemLevelDelta +0 · +7 · +15 = 3:2:1)를 비율대로 돈다("cycle").
	-- D1 모형은 편차 +0("zero" - 보수적). 첫 클리어 장비 기대 개수 = bossFirstClearDrops(게임 = 1).
	bossItemLevelDeltaModel = "cycle",
	bossFirstClearDrops = 1,
	-- D1-2: 반짝이(처치당 RareMonsterConfig.sparkleChance) 확정 장비 · 골드를 모형에 넣는다(누적 기대 도착 - 보스와 같은 방식). D1 전 모형은 반짝이를 안 셌다.
	modelSparkleDrops = true,

	-- E3 도달 시간 곡선의 이정표(마지막 = InfiniteStageConfig.designMaxStage를 EconSim이 붙인다 - P2.5a)
	milestones = { 10, 20, 50, 100, 500, 1000, 2000, 5000, 10000, 15000, 17000, 20000 }, -- P2.5c: 20 · 17,000 추가(사용자 보고 표)

	-- E4 구간(최고 스테이지 기준, "cap" = designMaxStage) - P2.5a 지시의 구간 1 ~ 100 / 100 ~ 500 / 500 ~ 1000 / 1000 ~ 설계 최대(P2.5a는 옛 한 단 천장 20,000 앞 · 뒤로 나눴다).
	-- P2.5c: 점진 감속 천장(weaponGrowthSegments)의 모양대로 1,001 ~ 2,000(사다리) · 2,001 ~ 10,000(감속) · 10,001 ~ 17,000(평탄) · 17,001 ~ 설계 최대로 나눴다.
	segments = { { 1, 100 }, { 101, 500 }, { 501, 1000 }, { 1001, 2000 }, { 2001, 10000 }, { 10001, 17000 }, { 17001, "cap" } },

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
	--   partyExpBonus      사냥 중 파티 경험치 보너스를 받는가(P2 전 규칙: 파티 소속만 되면 거리 무관 - S21-0 D3)
	--   partyHuntsTogether (P2 G) 사냥도 파티원과 같은 구역 · 반경 안에서 같이 하는가 - 새 규칙(partyExpRequiresPresence)에서는 이게 참이어야 보너스가 붙는다
	--   enhanceTarget      무기 강화 목표 단계
	--   useProtection      19강 이상에서 방지권을 사서 쓰는가
	--   rebirth            환생 가능해지면 바로 하는가
	--   gearCheckMinutes   가방 점검 간격(분) - 이 간격마다 그동안 주운 장비 · 분해 보석 중 가장 좋은 것으로 바꾼다(점수가 조금이라도 좋으면)
	--   gemReroll          고대 · 태초 보석을 원하는 축이 나올 때까지 변환권으로 다시 굴리는가
	--   gemRoll            원하는 축을 맞췄을 때의 옵션 롤 값(0.875 ~ 1.125)
	profiles = {
		casual = {
			displayName = "캐주얼", hoursPerDay = 1, classId = "bow", huntTierMax = 3,
			targetKillSeconds = 4.0, minSurviveHits = 5, dpsEfficiency = 0.7, moveOverheadSeconds = 1.5,
			bossDpsEfficiency = 0.6, bossKillLimitSeconds = 120, bossAttemptsPerClear = 2.0, bossOverheadSeconds = 30,
			partySize = 1, partyExpBonus = false,
			enhanceTarget = 18, useProtection = false, rebirth = true, -- P2.5a: 최대 +25 → +30에 맞춰 목표 ×30/25(15 → 18 · 20 → 24 · 25 → 30)
			gearCheckMinutes = 60, gemReroll = false, gemRoll = 1.0,
			tutorial = true, -- P3d G-d(사용자 결정): 견습 7단계를 무한 모드 앞에 돈다(EconSim.tutorialPhase) - 캐주얼 스테이지 20 도달 시간에 견습이 들어간다
		},
		normal = {
			displayName = "일반", hoursPerDay = 3, classId = "bow", huntTierMax = 5,
			targetKillSeconds = 3.0, minSurviveHits = 4, dpsEfficiency = 0.85, moveOverheadSeconds = 1.0,
			bossDpsEfficiency = 0.75, bossKillLimitSeconds = 90, bossAttemptsPerClear = 1.5, bossOverheadSeconds = 20,
			partySize = 1, partyExpBonus = false,
			enhanceTarget = 24, useProtection = false, rebirth = true,
			gearCheckMinutes = 20, gemReroll = true, gemRoll = 1.0,
		},
		top = {
			displayName = "상위 1%", hoursPerDay = 12, classId = "bow", huntTierMax = 6,
			targetKillSeconds = 2.5, minSurviveHits = 3, dpsEfficiency = 0.95, moveOverheadSeconds = 0.6,
			bossDpsEfficiency = 0.9, bossKillLimitSeconds = 60, bossAttemptsPerClear = 1.1, bossOverheadSeconds = 10,
			partySize = 4, partyExpBonus = true, partyHuntsTogether = false,
			enhanceTarget = 30, useProtection = true, rebirth = true,
			gearCheckMinutes = 5, gemReroll = true, gemRoll = 1.1,
		},
	},
	profileOrder = { "casual", "normal", "top" },

	-- E5 태초 선택지(P2: 게임 드랍표 그대로 - DropTable.effectiveRate · 레벨 감쇠 포함). 비교: 같은 플레이어가
	--   (A) 드래곤(highTier)을 자기 스테이지보다 Δ 낮은 스테이지에서 잡기 vs (B) tier t(lowTiers)를 자기 스테이지에서 잡기. 보석 레벨 = 잡은 스테이지(몬스터 레벨, 결정 6B E4).
	-- P2.5a: 스테이지 단위를 새 k(1.02)로 옮겼다 - 옛 Δ 1 · 2 · 3 · 4 · 5 · 10 · 30(k = 1.155)과 같은 HP 배율인 Δ 7 · 15 · 22 · 29 · 36 · 73 · 218, 지배 판정 범위 Δ ≤ 36(옛 5 = ×2.06).
	-- 플레이어 레벨 10 · 1000 · 10000(옛 10 · 150 · 1000 - 새 설계 최대 약 21,000에 맞춰 넓혔다).
	primordial = {
		playerLevels = { 10, 1000, 10000 },
		deltas = { 7, 15, 22, 29, 36, 73, 218 },
		dominanceMaxDelta = 36, -- 지배 전략 판정 범위(E2 "Δ ≤ 5에서 지배 전략 없음"의 새 단위)
		highTier = 6,
		lowTiers = { 1, 2, 3, 4, 5 },
	},

	-- E6 치유사(P2 F). 장비 단계 = 딜러와 치유사가 똑같이 낀 딜 옵션 보석(치유모드에도 옵션 100% - 게임 AttackServer와 같다). 앵커 = 레벨 100 · 무기 등급 0 · +0강(S21-0 D2와 같은 조건).
	--   gems: { 옵션 id, 등급, itemLevel, roll } 목록(보석 칸 순서)
	healer = {
		fightRatioScenario = { hitsPerSecond = 0.25, hitRatio = 0.1026, bossHpUnitsSeconds = 600 }, -- S13b PartyShieldSim 기준 시나리오 그대로
		shareFloor = 0.10, -- 보상 문턱(CombatConfig.contributionRewardThreshold를 EconSim이 읽어 대조한다 - 이 값은 표의 기준선일 뿐)
		shareTarget = 0.12,
		-- P2.5a: 장비 단계에 강화 단계(weaponLevel)를 넣었다 - 결정 8 "투자(유효 옵션 · 보석 · 강화)"의 평균 = +20 · 최상위 = +30(최대). 옛 E6는 전 단계 +0.
		gearTiers = {
			{ id = "none", displayName = "없음", weaponLevel = 0, gems = {} },
			{ id = "average", displayName = "평균", weaponLevel = 20, gems = {
				{ "attackPercent", "primordial", 100, 1.0 },
				{ "crit", "epic", 100, 1.0 },
				{ "speedPercent", "legendary", 100, 1.0 },
			} },
			{ id = "top", displayName = "상위", weaponLevel = 30, gems = {
				{ "attackPercent", "primordial", 125, 1.125 },
				{ "crit", "epic", 125, 1.125 },
				{ "attackPercent", "legendary", 125, 1.125 },
				{ "crit", "relic", 125, 1.125 },
				{ "speedPercent", "ancient", 125, 1.125 },
			} },
		},
		dealingTarget = 0.875, -- F3 딜링모드 원딜 = 검사 × 이 값(P2.5a: 평균 투자 기준 - 결정 8. P2는 장비 없음 기준)
		dealingTargetRange = { 0.85, 0.9 }, -- 딜링모드 목표 범위(결정 8A)
		shareDealerClass = "dualblade", -- F2 판정 구성 = 이 딜러 3 + 치유사 1
		healModeFightRatio = 1.0, -- [가정] 보스전 치유모드 치유사의 전투 시간 비율(치유모드는 소모가 없다 - 딜러 가동률과 같게 1로 본다)
		dealerClasses = { "bow", "dualblade", "greatsword" },
		-- F4 파티 구성(4인). 딜러 직업은 compositionDealerClasses마다 따로 잰다.
		compositions = { { dealers = 4, healers = 0 }, { dealers = 3, healers = 1 }, { dealers = 2, healers = 2 }, { dealers = 1, healers = 3 }, { dealers = 0, healers = 4 } },
		compositionDealerClasses = { "dualblade", "greatsword" },
	},

	-- P2.5a 지표 절(EconSimReport.writeP25): 구매력 기준 강화 단계(+20→+21) · 레벨업 간격 목표(첫 12시간 평균 ≤ 5분 · 이후 ≤ 15분) · 정체 기준(10분) · 표 스테이지
	p25 = {
		powerReferenceLevel = 20,
		earlyHours = 12, earlyIntervalMinutes = 5, lateIntervalMinutes = 15, stallMinutes = 10,
		powerStages = { 10, 50, 100, 500, 1000, 2000, 5000, 10000, 20000 },
		gemStages = { 125, 500, 1000, 2000, 5000, 10000, 20000 },
	},

	-- P2.5b 지표 절(EconSimReport.writeP25b): 마일스톤 누적을 볼 스테이지(마지막에 설계 최대를 붙인다) · 계승 · 재련 · 변환권 비용을 볼 스테이지 · 골드 수입 기준 프로필.
	p25b = {
		milestoneStages = { 500, 1000, 5000, 10000, 20000 },
		costStages = { 100, 1000, 5000, 20000 },
		incomeProfile = "normal",
	},

	-- P2.5c 지표 절(EconSimReport.writeP25c): 천장 경사 표의 누적 시간(시간) · 구매력 표의 강화 단계(+n→+n+1 1회 = 사냥 몇 분).
	p25c = {
		ceilingHours = { 12, 50, 100, 180, 360, 720, 1080, 1500, 2190, 3000 },
		powerLevels = { 20, 25, 29 },
	},

	-- E7 what-if 덮어쓰기. 이름 = /gg econ의 둘째 인자. 빈 표 = 기준선. 모든 칸은 선택:
	--   growthRate          InfiniteStageConfig.growthRate(몬스터 · 보상 · 아이템 계수 성장 k)
	--   weaponGrowthRate    CharacterLevelConfig.weaponMultGrowthRate(g)
	--   dealingMultiplier   SkillData.healer.E.attackMultiplier에 곱하는 배율
	--   enhanceCostScale    EnhanceConfig.goldCost 전체에 곱하는 배율
	--   (P2) rebirthRequiredLevels  CharacterLevelConfig.rebirth.requiredLevels · optionLevelLogSlope  OptionData.levelLogSlope · enhanceGoldAnchor  GoldCostConfig.anchorStage.enhance
	--   (P2) primordialDragonOverTier  DropTableData.primordial.dragonOverTier · primordialDecayPerLevel  levelDecay.perLevel · healerAtk  ClassData.healer.atk · dealingAttackMultiplier  SkillData.healer.E.attackMultiplier(절대값)
	--   (P2.5c) milestoneStat  MilestoneData.stat(마일스톤 버킷이 붙는 곳 "attack" · "survival" · "none" = 끔 - 곡선 영향 비교). (P2.5b의 milestoneStages · milestoneSurvival은 없앴다 - 곱연산 마일스톤이 없어졌다.)
	--   (P2.5a: p2before · compare는 없앴다 - k · 강화식 · 경험치 척도가 바뀌어 "P2 전 값만 되돌리기"가 옛 게임을 재현하지 못한다. 전후 비교 = docs/econ/P25a-before.md(옛 코드) 대조)
	whatIfs = {
		baseline = {},
		g10195 = { weaponGrowthRate = 1.0195 }, -- P2.5a: 주 구간 g를 k 아래로(천장이 앞당겨지는 민감도)
		dealing087 = { dealingMultiplier = 0.87 },
		enhanceHalf = { enhanceCostScale = 0.5 },
		noMilestone = { milestoneStat = "none" }, -- P2.5c B2: 마일스톤 버킷을 끈 곡선(영향 비교)
		milestoneAttack = { milestoneStat = "attack" }, -- P2.5c B2: 버킷 = 공격력(E1 비교)
		milestoneSurvival = { milestoneStat = "survival" }, -- P2.5c B2: 버킷 = 최대 체력(E1 비교)
	},
}
