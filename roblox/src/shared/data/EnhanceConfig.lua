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

return {
	maxLevel = 25,

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
		-- S >= resetFromStage이면 초기화도 1장 -> 50 · 75 = 하락 / 100 · 125 · 150 ... = 하락 + 초기화(Enhance.getBossGrant).
		bossGrant = { firstStage = 50, stepStages = 25, resetFromStage = 100 },
	},

	-- 28-1 [1-6]: Robux로 살 수 있는 투입물의 id(gold · 재료 id · dropTicket · resetTicket). 지금은 비어 있다 - EnhancePolicy.canAttempt가 이 표에 든
	-- 것이 이번 시도에 쓰이고 PolicyService가 "제한됨"이면 시도를 거부한다. 지금은 이 분기를 절대 안 탄다.
	paidInputIds = {},

	-- 강화 단계별 데미지 계수(누적, 6.1). 최종 배율 = 1 + damageCoefficient[level+1].
	damageCoefficient = {
		0,                                -- +0
		0.10, 0.20, 0.30, 0.40, 0.50,      -- +1~+5
		0.70, 0.90, 1.10, 1.30, 1.50,      -- +6~+10
		1.90, 2.30, 2.70, 3.10, 3.50,      -- +11~+15
		4.30, 5.10, 5.90, 6.70, 7.50,      -- +16~+20
		9.10, 10.70, 12.30, 13.90, 15.50,  -- +21~+25
	},

	-- 강화 시도 1회 골드 비용(28-1 S03, PRD 20.72 [1-5](가) - 골드만, 19강 이상의 강화석은 S04). index는 "시도 전 현재 강화 단계+1".
	-- 하락이 없어지면 같은 성공률로도 기대 비용이 크게 줄어서(18 → 19: 390회 → 3.4회), 곡선을 안 흔들려고 "단계별 기대 골드"를 보존하도록
	-- 시도 1회의 골드를 올렸다: 새 비용 = 유효숫자 3자리 반올림(옛 구조의 L → L+1 기대 골드 ÷ 천장 포함 기대 시도 수). 0 → 19강의 누적 기대
	-- 골드는 옛 498,841 / 새 498,822이고 기대 시도 수는 679회 → 34.6회다. 19강 이상은 같은 식을 연장한 값이다.
	goldCost = {
		10, 20, 30, 40, 50,   -- +0~+4 -> +1~+5
		106, 164, 221, 323, 433,   -- +5~+9 -> +6~+10
		578, 958, 1610, 2410, 4250,   -- +10~+14 -> +11~+15
		8140, 14900, 33700, 89300, 235000,   -- +15~+19 -> +16~+20
		766000, 3480000, 15900000, 84200000, 624000000,   -- +20~+24 -> +21~+25
	},
}
