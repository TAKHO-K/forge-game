-- QUEUE-ALL10 블록 1-2: ALL10-P2 초월 계승 숫자 한 곳(설계 원본 docs/design/transcend-inherit-plan.md · 숫자 = docs/design/all10-p1-proposal.md 추천안 · 돌파 2.4배).
--   스위치 enabled(기능 스위치 All10Economy) = false면 게임은 지금과 완전히 같다(계승 · 초월 강화 · 고급 · 방어 수련 · 초월 보석 · 몹 곡선 전부 꺼짐 - 하네스 all10_test가 증명).
--   개발 중 켬 · 출시 기본값 = 사용자 결정. Studio에서만 ReplicatedStorage Attribute "All10Economy"(true/false)가 이 값을 덮는다(shared/All10.enabled).
--   비용 단위 = GoldCost 단위(tier1 잡몹 골드 × 마리 수 × GoldCost.scale(계정 최고 스테이지)) - 제안서의 "마리분"(EconSim 처치당 골드)은 일반(중앙값) 프로필 기준
--   처치당 골드 ÷ tier1 골드 = 1.76(8,000 ~ 25,000 일정 - QUEUE-ALL10 1-2 측정)이라 제안 값 × killUnitScale로 옮긴다. 최고 스테이지 기준이라 내려가서 싸게 사는 구멍 없음.
--   상한 확장 대비(D8): 초월 강화 +21 ~ · 고급 수련 101 ~ 은 maxLevel만 올리면 같은 식이 이어진다(표가 아니라 식).
return {
	enabled = true, -- 기능 스위치(All10Economy) - 출시 기본값 켬(QUEUE-ALL9E1-ADD 결정 2 · 10-04)
	killUnitScale = 1.76, -- 제안서 마리분(EconSim) → GoldCost 단위(tier1 잡몹)

	-- 2-1 계승(D1 · D2): 태초(grade 6) 무기 +30 · 같은 직업 → 초월 무기(grade 7) +0
	--   QUEUE-ALL9E1 0-2(P3-2 · 사용자 10-04): 조건 = 그 직업의 **현재 무기 +29 이상**(등급 무관 - 환생 0회 기본 무기 포함). 결과는 어디서 왔든 같은 초월 +0
	--   (강화 줄 = resultLevel 몫 · 등급 줄 = 태초 × weaponMultiplier). +30에서 계승 = "+30 증표"(치장 소품 markItemId) · 그 직업 환생 0회 = 히든 칭호.
	inherit = {
		fromGrade = 6, toGrade = 7, requiredLevel = 29, -- fromGrade = 초월 등급 줄의 기준(태초) - 계승 조건에는 쓰지 않는다(P3-2)
		resultLevel = 30, -- 계승 뒤 무기 강화 단계(+30 몫 그대로 - 초월 +0 = 태초 +30 × 1.25)
		markLevel = 30, markItemId = "enhance30Mark", -- 계승 순간 +30이면 증표(치장 칸 weaponMark · 판매 · 토큰 · 선물 X)
		unrebornTitleId = "unrebornTranscendent", -- 계승 순간 그 직업 환생 0회 = 칭호 "환생 없는 초월자"(히든 - 도감에서 얻기 전엔 ???)
		weaponMultiplier = 1.25, -- 초월 +0 공격 = 태초 +30 공격 × 1.25(제안서 5절)
		titleId = "transcendHeir", -- 칭호 "초월 계승자"
		rewardGems = 1, -- 계승 보상 초월 보석 1개(D16 보존 규칙)
		confirmTtlSeconds = 60, -- 2단계 확인 토큰 유효 시간
	},

	-- 2-2 초월 강화 0 ~ 20(D7 + 결정 4): 확정 성공 · 골드만 · 하락/초기화 없음 · 한 단계 = 10칸 분할 납입
	--   QUEUE-ALL9E1 0-4(P3-4 · 사용자 10-04 · D7 변경): +1 ~ +5 = 확정 · 10칸 분할 그대로 / +6 이상 = 확률(3단계 묶음 · 실패 = 골드만 · 하락 · 초기화 없음) +
	--   불씨 천장(ceiling번째 시도 확정 · 성공하면 0) · 단계당 공격 ×(1 + gain)(곱 - 한 단계 성공 = 같은 스테이지 처치 시간 1 − 1/(1 + gain) 감소) ·
	--   시도 비용 = 그 단계 기대 비용(levelKills · 실패 포함) ÷ 기대 시도 수(천장 반영). +21 ~ +25 = 계정 최고 스테이지 extendStage 이상에서만(결정 4).
	transcendEnhance = {
		maxLevel = 25, baseMaxLevel = 20, extendStage = 24000, -- 상한 = 최고 스테이지 < extendStage면 baseMaxLevel(All10.transcendCap)
		perLevel = 0.05, -- +1 ~ +5 단계당 공격 +5%(무기 강화 줄 합연산 · 칸마다 1/10)
		sureUntil = 5, -- 여기까지 확정(칸 납입)
		levelKills = 430000, -- 한 단계 비용(마리분 · 확률 단계는 실패 포함 기대값) · 3-1: 28만 → 36만 · QUEUE-ALL9E1 0-6(곱 ×1.22 · 기준 빌드 = 중앙값 궤적): 36만 = 상위 1% 2,023h(미달) → 43만 = 2,174h
		slots = 10, -- 결정 4: 10칸 분할(칸마다 효과 1/10 · 낸 만큼 저장) - +1 ~ +5만
		sureCostFactor = 1, -- P3 결정 2-2(10-04): +1 ~ +5 칸 가격 배수(확률 단계 무관) - 캐주얼 계승 직후 보유 시간 맞춤
		gain = 0.22, -- +6 이상 단계당 공격 ×1.22(같은 스테이지 처치 시간 −18% - 목표 15 ~ 25%)
		bands = { -- 성공해서 닿는 단계 기준(+6 ~ +8 = 5 → 6 · 6 → 7 · 7 → 8 시도) · chance = 성공률 · ceiling = 이 번째 시도는 확정(불씨 게이지)
			{ fromLevel = 6, toLevel = 8, chance = 0.40, ceiling = 8 },
			{ fromLevel = 9, toLevel = 11, chance = 0.30, ceiling = 10 },
			{ fromLevel = 12, toLevel = 14, chance = 0.25, ceiling = 12 },
			{ fromLevel = 15, toLevel = 17, chance = 0.15, ceiling = 20 },
			{ fromLevel = 18, toLevel = 20, chance = 0.10, ceiling = 30 },
			{ fromLevel = 21, toLevel = 25, chance = 0.10, ceiling = 30 }, -- extendStage 이상
		},
	},

	-- QUEUE-ALL9E1 0-5(P3-5): 초월 강화 최초 달성 - levels 각 단계 "전 서버 최초 1명" = 전 서버 배너 + 명예의 전당 "초월 강화" 줄 + 칭호(titleIds).
	--   판정 = DataStore UpdateAsync 선점(키 = launchEpoch .. ":" .. 단계 · 먼저 쓴 사람만) · Studio = 시험 키(PrimordialData.testKeyPrefix) · 개발 계정 제외(server/OpsConfig.leaderboardExcludedUserIds).
	--   launchEpoch = 출시 때 바꾼다(그 전 기록 = 시험 기록과 분리). 그 밖 localFromLevel 이상 성공 = 같은 서버 알림.
	transcendFirsts = {
		levels = { 10, 15, 20 },
		titleIds = { [10] = "firstTranscend10", [15] = "firstTranscend15", [20] = "firstTranscend20" },
		storeName = "TranscendFirsts_v1", launchEpoch = "prelaunch1", topic = "TranscendFirst",
		localFromLevel = 15,
	},

	-- QUEUE-ALL9E1-ADD 결정 7(D): 계승 뒤 골드 쓰는 순서(안내 · 시뮬 정책 - 기능 잠금 아님): ① 초월 +1 ~ sureTo → ② 고급 수련 ~ advancedTo → ③ 방어 수련 ~ guardTo(1구간)
	--   → ④ 초월 +6 ~ / 고급 수련 61 ~ 번갈아(남는 방어 수련은 그 사이 가장 싼 것). 화면 안내(client 계승 뒤 "다음 쓸 곳") · EconSim 캐주얼 · 일반(profile.all10Order)이 같은 표.
	spendOrder = { sureTo = 5, advancedTo = 60, guardTo = 10 },

	-- 2-3 고급 수련 51 ~ 100(D5 · R9 · R10): 초월 무기 보유 시에만 해금(★사용자 규칙 - 스테이지만으로 열지 않는다) · 같은 수련 창 · 51부터 이름 "고급 수련"
	advancedTraining = {
		fromLevel = 51, maxLevel = 100, -- D8: 101 ~ = maxLevel만
		perLevel = 0.01, -- 단계당 공격 +1%(영구 공격 버킷 합연산)
		baseKills = 1840, growth = 1.03, -- 비용 = baseKills × growth^(단계 − 51)(제안서 마리분)
		early = { untilLevel = 60, factor = 1 }, -- 결정 4 보완: 51 ~ 60 비용 × 0.4(계승 직후 골드가 바로 쓰이게) → PROG-2B-1 1(PROG-2A D3 폐지): × 1(50 → 51 계단이 보이게 - 옛 = T 14 → 9분으로 싸짐)
		lateStep = { fromLevel = 76, factor = 2 }, -- PROG-2B-1 1(PROG-2A A안): 76 ~ 100 비용 × 2(75에서 계단 - 25 · 50 · 75에서 눈에 띄게 비싸짐)
		capStart = 10000, capStep = 100, -- 단계 상한 = 50 + (계정 최고 스테이지 − capStart) ÷ capStep(15,000에 100) · 초월 무기 없으면 50
	},

	-- 방어 수련(D6 · 고급 수련 안 항목): 받는 피해 × (1 − perLevel)^단계 - 서버 피해 식 한 곳(PlayerCombat) + UI 같은 함수(shared/All10)
	defenseTraining = {
		unlockStage = 12000, maxLevel = 30,
		perLevel = 0.01,
		baseKills = 6000, growth = 1.05,
	},

	-- 2-4 초월 보석(D9 · D16): 계승 뒤에만 · 태초 보석 × gradeStep · 계정 귀속 · 기본 잠금 · 판매/분해 불가 · 추출 100% 무료
	transcendGem = {
		gradeStep = 1.35, -- OptionData.gradeStep와 같은 값(8번째 등급)
		dropMinStage = 15000, dropChance = 0.002, -- 15,000 이상 보스 처치당 0.2%
	},

	-- 2-5 수련 1 ~ 50 · 직업 특성 진화 확대(D4 · 제안서 1-6 예): 계정 최고 스테이지 5,000 · 7,500 · 10,000에서 직업 고유 능력 상한 +10씩(초반 곡선 불변)
	evolution = {
		stages = { 5000, 7500, 10000 }, capBonusPerStep = 10,
	},

	-- 2-6 몹 곡선(D3 · D11): MonsterStats 한 곳
	monsterCurve = {
		breakLength = 1500, breakRatio = 2.2, -- P3 결정 2-1(10-04): 2.4 → 2.2(같은 규칙 · 돌파만 끈 기준 대비 중앙값 2.35 · 상위 1% 2.91 · P90 2.59 · 상위 1% 25,300 = 2,160h) · 돌파 계수(그 사람에게만) = 기준 빌드 배수(All10.referenceBuild) × 계승 스테이지부터 1,500 동안 1/breakRatio - 진행 속도 ∝ 상대 힘이라 기준 빌드인 사람은 breakRatio배 · 뒤 정상(QUEUE-ALL10 3-1)
		followKappa = 0, -- 계승한 사람의 몹 HP 성장률 추가(계승 지점부터 · 스테이지당 ln1.02의 몫) - 3-1 실제 EconSim 맞춤 값
		refEndStage = 25300, -- 기준 빌드: 초월 강화를 계승 스테이지 → 이 스테이지 사이 일정하게 +0 → +20으로 본다(D8 초월 +20 ≈ 25,300) - refTranscend가 있으면 그것을 쓴다
		-- QUEUE-ALL9E1 0-6: 기준 빌드의 초월 강화 단계 = 중앙값(일반 프로필) 실제 궤적(계정 최고 스테이지 → 단계 · 사이는 직선). +6부터 곱(×1.22)이라 "일정하게"
		--   가정은 20,000에서 몹을 중앙값의 4.6배로 만들었다(일반 25,300 = 4,765h). 실제 EconSim 고정점 맞춤(궤적 → 표 → 다시 돌림).
		refInheritStage = 8570, -- 위 궤적의 계승 스테이지(일반 프로필) - 이보다 늦게 계승한 사람은 차이만큼 궤적을 미룬다(All10.referenceBuild)
		refTranscend = { -- QUEUE-ALL9E1 0-6 최종(levelKills 43만 · 결정 7 순서 반영 · 고정점 2회): 일반 프로필 초월 강화 단계 도달 스테이지
			{ 12230, 0 }, { 13230, 1 }, { 16270, 2 }, { 19020, 3 }, { 20380, 4 }, { 21320, 5 }, { 21800, 6 }, { 23270, 7 }, { 24010, 8 }, { 24275, 9 }, { 24500, 10 },
			{ 24655, 11 }, { 24700, 12 }, { 24750, 13 }, { 24880, 14 }, { 24965, 15 }, { 25305, 16 }, { 25405, 17 }, { 25870, 18 }, { 26015, 19 }, { 26325, 20 },
		},

		curveStart = 16000, curveKappa = 0.005, -- 전역: 16,000부터 몹 HP 성장률 +0.5% · 3-1 실제 EconSim 맞춤: 0.12 → 0.005(진행 속도 ∝ 상대 힘이라 0.12는 지수적으로 멈춤 · 상위 1% 25,300 = 2,296h)
		attackKappa = 0.00163, -- 전역: 16,000부터 몹 공격 성장률 +0.163%(25,300에서 ×1.35 = 방어 수련 30단계 ×0.74가 상쇄 - 생존 축)
	},
}
