-- 강화 계수표·확률표. 웹 v1(data/enhance.js)에서 확정된 수치를 그대로 옮긴다 - 새로 만들지
-- (28-1 S03: 확률표의 실패 내용 · 골드표 · 천장은 PRD 20.72 [1]의 새 규칙으로 교체했다 - 아래 각 항목 주석 참고. 성공률 · 계수표 · 최대 단계는 그대로.)
-- 않는다(10-2 지시). 인덱스는 로블록스(Lua) 1부터 시작하므로 "강화 단계 N에서의 값"은
-- 이 테이블의 [N+1]번째 항목이다(N=0이 +0강, 즉 미강화 상태).
--
-- 이번 이식에서 뺀 것 - 웹엔 있지만 지금은 안 가져온다(10-2 "하지 말 것" 지시):
--   - 상급 강화(6.2-1, 골드 5배로 성공률 매수), 강화권 4종(6.3).
--   - 강화 부가 효과(6.1-1, 사거리·명중 배가 등). 정확히는 웹에서 +10 스킬 해금만
--     미구현이고 사거리·명중 배가는 실제 구현돼 있었지만(PRD-forge-game.md 6.1-1),
--     이번 작업 지시가 명확히 "만들지 마라"였으므로 전부 뺐다.
--   - 강화석 등 재료 비용(PRD 6.2-2 표). 실제 웹 코드(data/enhance.js ENHANCE_GOLD_COST)를
--     확인해보니 골드만 쓰고 재료 비용은 구현된 적이 없다(PRD 표는 미구현 원안) - 그래서
--     여기도 골드만 쓴다. 새로 만든 게 아니라 실제 구현을 그대로 따라간 것이다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)
local BossData = require(ReplicatedStorage.Shared.data.BossData)

local config = {
	-- P2.5a R4(사용자 확정): 최대 +30(상수 하나 - 서버 판정 · 강화 패널 제목 "최대 +30" · 시뮬이 이 값을 읽는다). 옛 +25.
	maxLevel = 30,

	-- 30-0 S08: 이 단계 이상으로 **성공**했을 때(새 단계 기준) 같은 서버 전원에게 채팅 시스템 메시지 1줄(EnhanceService · 클라 EnhanceAnnounceClient).
	announceFromLevel = 20,

	-- 28-1(S03, PRD 20.72 [1-2]) 하락 · 초기화 규칙. 시도하는 순간의 단계로 읽는다 - 결과는 5종(success / maintain / down1 / down2 /
	-- reset)이고 파괴(소멸)는 없다. 성공률은 옛 표 그대로(92 / 78 / 62 / 48 / 38 / 28 / 18 / 12%)이고 바뀐 것은 실패의 내용뿐이다:
	-- 0 ~ 18강은 하락이 없다(옛 실패 확률 전체가 maintain), 19 ~ 21강은 하락(바닥 downFloorLevel), 22 ~ 24강은 하락 + 초기화(resetToLevel).
	-- 한 행의 합은 항상 1 - Enhance 모듈이 로드될 때 25행 전부를 검사한다(어긋나면 서버 시작 시 에러).
	probability = {
		{ success = 0.92, maintain = 0.08, down1 = 0, down2 = 0, reset = 0 }, -- +0
		{ success = 0.92, maintain = 0.08, down1 = 0, down2 = 0, reset = 0 }, -- +1
		{ success = 0.92, maintain = 0.08, down1 = 0, down2 = 0, reset = 0 }, -- +2
		{ success = 0.92, maintain = 0.08, down1 = 0, down2 = 0, reset = 0 }, -- +3
		{ success = 0.92, maintain = 0.08, down1 = 0, down2 = 0, reset = 0 }, -- +4
		{ success = 0.78, maintain = 0.22, down1 = 0, down2 = 0, reset = 0 }, -- +5
		{ success = 0.78, maintain = 0.22, down1 = 0, down2 = 0, reset = 0 }, -- +6
		{ success = 0.78, maintain = 0.22, down1 = 0, down2 = 0, reset = 0 }, -- +7
		{ success = 0.62, maintain = 0.38, down1 = 0, down2 = 0, reset = 0 }, -- +8
		{ success = 0.62, maintain = 0.38, down1 = 0, down2 = 0, reset = 0 }, -- +9
		{ success = 0.62, maintain = 0.38, down1 = 0, down2 = 0, reset = 0 }, -- +10
		{ success = 0.48, maintain = 0.52, down1 = 0, down2 = 0, reset = 0 }, -- +11
		{ success = 0.48, maintain = 0.52, down1 = 0, down2 = 0, reset = 0 }, -- +12
		{ success = 0.48, maintain = 0.52, down1 = 0, down2 = 0, reset = 0 }, -- +13
		{ success = 0.38, maintain = 0.62, down1 = 0, down2 = 0, reset = 0 }, -- +14
		{ success = 0.38, maintain = 0.62, down1 = 0, down2 = 0, reset = 0 }, -- +15
		{ success = 0.38, maintain = 0.62, down1 = 0, down2 = 0, reset = 0 }, -- +16
		{ success = 0.28, maintain = 0.72, down1 = 0, down2 = 0, reset = 0 }, -- +17
		{ success = 0.28, maintain = 0.72, down1 = 0, down2 = 0, reset = 0 }, -- +18
		{ success = 0.28, maintain = 0.58, down1 = 0.14, down2 = 0, reset = 0 }, -- +19
		{ success = 0.18, maintain = 0.775, down1 = 0, down2 = 0.045, reset = 0 }, -- +20
		{ success = 0.18, maintain = 0.775, down1 = 0, down2 = 0.045, reset = 0 }, -- +21
		{ success = 0.18, maintain = 0.72, down1 = 0.06, down2 = 0.03, reset = 0.01 }, -- +22
		{ success = 0.12, maintain = 0.81, down1 = 0.04, down2 = 0.02, reset = 0.01 }, -- +23
		{ success = 0.12, maintain = 0.81, down1 = 0.04, down2 = 0.02, reset = 0.01 }, -- +24
		-- P2.5a C5: 25 ~ 29강(→ +26 ~ +30). 실패 결과는 23 · 24강 규칙 그대로(하락 1 · 2단계 + 초기화 - 4 : 2 : 1%), 성공률 12 · 12 · 10 · 10 · 8%.
		-- (10 · 10 · 8 · 8 · 6%는 초기화 · 하락 재등반 때문에 29강 기대 시도가 192회 · 0 → 30 기대 골드가 상위 1% 6개월 수입의 4배를 넘었다 - P25a-log.)
		{ success = 0.12, maintain = 0.81, down1 = 0.04, down2 = 0.02, reset = 0.01 }, -- +25
		{ success = 0.12, maintain = 0.81, down1 = 0.04, down2 = 0.02, reset = 0.01 }, -- +26
		{ success = 0.10, maintain = 0.83, down1 = 0.04, down2 = 0.02, reset = 0.01 }, -- +27
		{ success = 0.10, maintain = 0.83, down1 = 0.04, down2 = 0.02, reset = 0.01 }, -- +28
		{ success = 0.08, maintain = 0.85, down1 = 0.04, down2 = 0.02, reset = 0.01 }, -- +29
	},

	-- 하락은 어디서 시작해도 이 단계에서 멈춘다(19 → 18 · 20 → 18 · 21 → 19 · 22 → 21/20). 18강 이하는 하락이 없는 구간이라 더 내려갈 곳이 없다.
	downFloorLevel = 18,
	-- 초기화(reset)가 보내는 단계 - 옛 규칙의 "1강"이 아니다.
	resetToLevel = 12,

	-- 천장("불씨", PRD 20.72 [1-6] 3번). 모든 실패(유지 · 하락 · 초기화)가 게이지를 채운다: 실패 1회당
	-- += round(시도한 단계의 성공률 × gainPerSuccessRate)(천분율 정수, weapon.enhanceGauge에 저장). 게이지 ≥ max면 다음 시도는 성공 100%,
	-- 성공하면 0으로. 하락 · 초기화로 단계가 바뀌어도 게이지는 유지된다. 성공률 p에서 ceil(2 / p)번 실패하면 확정이다("기대 시도 수의 2배").
	gauge = { max = 1000, gainPerSuccessRate = 500},

	-- 방지권 2종(28-1 S05, PRD 20.72 [1-3]) - 골드로만 산다. 결과를 원래 확률표로 굴린 뒤 **실제로 막았을 때만** 1장이 소모된다(하락 방지권: down1 · down2를
	-- maintain으로, 초기화 방지권: reset을 maintain으로). usableFromLevel = 시도하는 단계가 이 값 이상일 때만 쓸 수 있다. priceKillEquivalent = 상점가 =
	-- "계정 최고 스테이지의 잡몹(tier1) 1마리당 골드 × 이 값"(Enhance.getProtectionPrice).
	protection = {
		drop = { displayName = "하락 방지권", usableFromLevel = 19, priceKillEquivalent = 300 },
		reset = { displayName = "초기화 방지권", usableFromLevel = 22, priceKillEquivalent = 900 },
		-- 보스 계정 첫 클리어 지급(계정 단위 1회): 보스 스테이지 S가 S >= firstStage이고 (S - firstStage) % stepStages == 0이면 하락 1장, 그중
		-- S >= resetFromStage이면 초기화도 1장(Enhance.getBossGrant).
		-- P2.5c 결정 10: 옛 50 · 25칸 · 100(k 1.155)을 같은 힘의 지금 스테이지로(힘 비율 - InfiniteStage.fromLegacyStage/Span, 보스 간격 5의 배수로 반올림)
		-- = 360 · 180칸 · 720 → 360 · 540 = 하락 / 720 · 900 · 1080 ... = 하락 + 초기화. 설계 최대 25,300까지 하락 139장(옛 번호 그대로면 약 1,000장).
		bossGrant = {
			firstStage = InfiniteStage.fromLegacyStage(50, BossData.stageInterval),
			stepStages = InfiniteStage.fromLegacySpan(25, BossData.stageInterval),
			resetFromStage = InfiniteStage.fromLegacyStage(100, BossData.stageInterval),
		},
	},

	-- 28-1 [1-6]: Robux로 살 수 있는 투입물의 id(gold · 재료 id · dropTicket · resetTicket). 지금은 비어 있다 - EnhancePolicy.canAttempt가 이 표에 든
	-- 것이 이번 시도에 쓰이고 PolicyService가 "제한됨"이면 시도를 거부한다. 지금은 이 분기를 절대 안 탄다.
	paidInputIds = {},

	-- P2.5a R5(사용자 확정): 강화 1회 성공마다 ① 최종 데미지 +finalDamagePerLevel(3.5% - 합연산 버킷, Enhance.getFinalDamageBonus → PlayerCombat) ②
	-- 공격력 ×(1 + attackGrowthPerLevel)(곱연산, Enhance.getDamageMultiplier). +maxLevel 누적 합계 = (1 + 30 × 0.035) × (1 + a)^30 = totalMultiplierAtMax(20)이
	-- 되도록 a를 여기서 푼다: a = (20 ÷ 2.05)^(1/30) − 1 = 0.07891(약 +7.9%/강). 옛 계수표(웹 6.1 - +20 ×8.5 · +25 ×16.5)는 없앴다.
	finalDamagePerLevel = 0.035,
	totalMultiplierAtMax = 20,

	-- 강화 시도 1회 골드 비용(28-1 S03, PRD 20.72 [1-5](가) - 골드만, 19강 이상의 강화석은 S04). index는 "시도 전 현재 강화 단계+1".
	-- 하락이 없어지면 같은 성공률로도 기대 비용이 크게 줄어서(18 → 19: 390회 → 3.4회), 곡선을 안 흔들려고 "단계별 기대 골드"를 보존하도록
	-- 시도 1회의 골드를 올렸다: 새 비용 = 유효숫자 3자리 반올림(옛 구조의 L → L+1 기대 골드 ÷ 천장 포함 기대 시도 수). 0 → 19강의 누적 기대
	-- 골드는 옛 498,841 / 새 498,822이고 기대 시도 수는 679회 → 34.6회다. 19강 이상은 같은 식을 연장한 값이다.
	goldCost = {
		10, 20, 30, 40, 50,   -- +0~+4 -> +1~+5
		106, 164, 221, 323, 433,   -- +5~+9 -> +6~+10
		578, 958, 1610, 2410, 4250,   -- +10~+14 -> +11~+15
		-- P2.5c 결정 4(사용자 확정 - "일반 프로필 +20 이상 강화 1회 시도 = 사냥 약 20 ~ 30분"): +17 이상을 다시 설계했다. 일반 프로필 골드 수입은 스테이지와 무관하게
		-- 1회 비용 단위(× 1.001^(s−1))로 분당 약 930(스테이지 501 ~ 1000 평균 - P25c-before)이라 +20→21 = 20,000(약 21분) · 그 뒤 ×1.035/단계(+29→30 = 27,300 · 약 29분).
		-- +17 ~ +19는 +16(14,900)과 +20 사이를 잇는다(단조 증가 - 옛 33,700 · 89,300 · 235,000은 +20보다 비싸진다). 옛 +20→21 = 766,000(약 820분).
		-- +0 ~ +16 · 방지권 · 변환권 · 계승 · 재련 골드는 그대로다(다른 골드 소비처를 안 흔든다). 구간별 분 = docs/econ/P25c-after.md "P2.5c ④".
		8140, 14900, 16000, 17000, 18500,   -- +15~+19 -> +16~+20
		20000, 20700, 21400, 22200, 23000,   -- +20~+24 -> +21~+25
		23800, 24600, 25500, 26400, 27300,   -- +25~+29 -> +26~+30
	},

	-- P3c C1(사용자 확정 - "천장 구간 +20 이상 강화 1회 = 사냥 30 ~ 60분"): 천장 감속(CharacterLevelConfig.weaponGrowthSegments)이 처치를 늦추면 같은 비용이 더 오래 걸린다.
	-- 청크 단위 실측(그 순간의 비용 ÷ 그 순간의 골드/분 - 경제 하네스 P3c, 보고서 ⑥): 일반 프로필 +20 1회 = 스테이지 ~2,000 약 21분 → 6,000 이후 약 50분(+29 약 68분 - 60 초과).
	-- (P2.5c 보고서의 191 ~ 566분은 넓은 구간의 평균 골드/분을 구간 끝 비용으로 나눈 값이라 골드 성장 1.001^구간 폭만큼 부풀었다 - 로그 결정.)
	-- 보정 = +fromEnhanceLevel 이상 시도의 골드에 배수: 캐릭터 레벨 축 rampFromLevel(2,500 - 천장 감속이 처치를 막기 시작하는 곳)에서 1, fullAtLevel(4,500 - 감속이 거의 다 걸린 곳)부터 factor(하네스: 4,000 ~ 6,000에서 이미 +29 66분 - 램프를 4,000 → 6,000에 두면 그 구간 상위 10%가 69.5분).
	-- 스테이지 = 레벨 + levelStageOffset(앵커 장비 척도). factor 0.75 → 천장 일반 +20 약 37분 · +25 약 45분 · +29 약 51분(30 ~ 60 안). 천장 전 구간 · +19 이하 · 다른 골드 소비처는 그대로.
	ceilingDiscount = { fromEnhanceLevel = 20, rampFromLevel = 2500, fullAtLevel = 4500, factor = 0.75 },
}

-- R5 공격력 곱연산 증가율(위 finalDamagePerLevel · totalMultiplierAtMax 주석) - 데이터 두 값에서 푼다(숫자를 따로 박지 않는다).
config.attackGrowthPerLevel = (config.totalMultiplierAtMax / (1 + config.maxLevel * config.finalDamagePerLevel)) ^ (1 / config.maxLevel) - 1

return config
