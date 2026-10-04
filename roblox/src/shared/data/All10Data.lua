-- QUEUE-ALL10 블록 1-2: ALL10-P2 초월 계승 숫자 한 곳(설계 원본 docs/design/transcend-inherit-plan.md · 숫자 = docs/design/all10-p1-proposal.md 추천안 · 돌파 2.4배).
--   스위치 enabled(기능 스위치 All10Economy) = false면 게임은 지금과 완전히 같다(계승 · 초월 강화 · 고급 · 방어 수련 · 초월 보석 · 몹 곡선 전부 꺼짐 - 하네스 all10_test가 증명).
--   개발 중 켬 · 출시 기본값 = 사용자 결정. Studio에서만 ReplicatedStorage Attribute "All10Economy"(true/false)가 이 값을 덮는다(shared/All10.enabled).
--   비용 단위 = GoldCost 단위(tier1 잡몹 골드 × 마리 수 × GoldCost.scale(계정 최고 스테이지)) - 제안서의 "마리분"(EconSim 처치당 골드)은 일반(중앙값) 프로필 기준
--   처치당 골드 ÷ tier1 골드 = 1.76(8,000 ~ 25,000 일정 - QUEUE-ALL10 1-2 측정)이라 제안 값 × killUnitScale로 옮긴다. 최고 스테이지 기준이라 내려가서 싸게 사는 구멍 없음.
--   상한 확장 대비(D8): 초월 강화 +21 ~ · 고급 수련 101 ~ 은 maxLevel만 올리면 같은 식이 이어진다(표가 아니라 식).
return {
	enabled = true, -- 기능 스위치(All10Economy) - 개발 중 켬
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
	transcendEnhance = {
		maxLevel = 20, -- D8: 늘리면 +21 ~ 이 같은 식
		perLevel = 0.05, -- 단계당 공격 +5%(무기 강화 줄 합연산 · 칸마다 1/10)
		levelKills = 360000, -- 한 단계 비용(마리분) - 공격 1%당 비용 일정(효율 일정 · R13) · 3-1 실제 EconSim 맞춤: 28만 → 36만(상위 1% +20 ≈ 24,755 - 25,300 근처)
		slots = 10, -- 결정 4: 10칸 분할(칸마다 효과 1/10 · 낸 만큼 저장)
	},

	-- 2-3 고급 수련 51 ~ 100(D5 · R9 · R10): 초월 무기 보유 시에만 해금(★사용자 규칙 - 스테이지만으로 열지 않는다) · 같은 수련 창 · 51부터 이름 "고급 수련"
	advancedTraining = {
		fromLevel = 51, maxLevel = 100, -- D8: 101 ~ = maxLevel만
		perLevel = 0.01, -- 단계당 공격 +1%(영구 공격 버킷 합연산)
		baseKills = 1840, growth = 1.03, -- 비용 = baseKills × growth^(단계 − 51)(제안서 마리분)
		early = { untilLevel = 60, factor = 0.4 }, -- 결정 4 보완: 51 ~ 60 비용 × 0.4(계승 직후 골드가 바로 쓰이게)
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
		breakLength = 1500, breakRatio = 2.4, -- 돌파 계수(그 사람에게만) = 기준 빌드 배수(All10.referenceBuild) × 계승 스테이지부터 1,500 동안 1/2.4 - 진행 속도 ∝ 상대 힘이라 기준 빌드인 사람은 2.4배 · 뒤 정상(QUEUE-ALL10 3-1)
		followKappa = 0, -- 계승한 사람의 몹 HP 성장률 추가(계승 지점부터 · 스테이지당 ln1.02의 몫) - 3-1 실제 EconSim 맞춤 값
		refEndStage = 25300, -- 기준 빌드: 초월 강화를 계승 스테이지 → 이 스테이지 사이 일정하게 +0 → +20으로 본다(D8 초월 +20 ≈ 25,300)
		curveStart = 16000, curveKappa = 0.005, -- 전역: 16,000부터 몹 HP 성장률 +0.5% · 3-1 실제 EconSim 맞춤: 0.12 → 0.005(진행 속도 ∝ 상대 힘이라 0.12는 지수적으로 멈춤 · 상위 1% 25,300 = 2,296h)
		attackKappa = 0.00163, -- 전역: 16,000부터 몹 공격 성장률 +0.163%(25,300에서 ×1.35 = 방어 수련 30단계 ×0.74가 상쇄 - 생존 축)
	},
}
