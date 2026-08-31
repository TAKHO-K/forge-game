-- 강화 계수표·확률표. 웹 v1(data/enhance.js)에서 확정된 수치를 그대로 옮긴다 - 새로 만들지
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

	-- 실패는 4종(형상유지/-1강/-2강/리셋) + 성공, 합계는 항상 1.0. 파괴(소멸)는 웹에도
	-- 없었다 - 항목 자체가 없다.
	probability = {
		{ success = 0.92, maintain = 0.08, down1 = 0,    down2 = 0,    reset = 0 },    -- +0
		{ success = 0.92, maintain = 0.08, down1 = 0,    down2 = 0,    reset = 0 },    -- +1
		{ success = 0.92, maintain = 0.08, down1 = 0,    down2 = 0,    reset = 0 },    -- +2
		{ success = 0.92, maintain = 0.08, down1 = 0,    down2 = 0,    reset = 0 },    -- +3
		{ success = 0.92, maintain = 0.08, down1 = 0,    down2 = 0,    reset = 0 },    -- +4
		{ success = 0.78, maintain = 0.12, down1 = 0.10, down2 = 0,    reset = 0 },    -- +5
		{ success = 0.78, maintain = 0.12, down1 = 0.10, down2 = 0,    reset = 0 },    -- +6
		{ success = 0.78, maintain = 0.12, down1 = 0.10, down2 = 0,    reset = 0 },    -- +7
		{ success = 0.62, maintain = 0.13, down1 = 0.25, down2 = 0,    reset = 0 },    -- +8
		{ success = 0.62, maintain = 0.13, down1 = 0.25, down2 = 0,    reset = 0 },    -- +9
		{ success = 0.62, maintain = 0.13, down1 = 0.25, down2 = 0,    reset = 0 },    -- +10
		{ success = 0.48, maintain = 0.12, down1 = 0.30, down2 = 0.10, reset = 0 },    -- +11
		{ success = 0.48, maintain = 0.12, down1 = 0.30, down2 = 0.10, reset = 0 },    -- +12
		{ success = 0.48, maintain = 0.12, down1 = 0.30, down2 = 0.10, reset = 0 },    -- +13
		{ success = 0.38, maintain = 0.12, down1 = 0.32, down2 = 0.17, reset = 0.01 }, -- +14
		{ success = 0.38, maintain = 0.12, down1 = 0.32, down2 = 0.17, reset = 0.01 }, -- +15
		{ success = 0.38, maintain = 0.12, down1 = 0.32, down2 = 0.17, reset = 0.01 }, -- +16
		{ success = 0.28, maintain = 0.10, down1 = 0.35, down2 = 0.26, reset = 0.01 }, -- +17
		{ success = 0.28, maintain = 0.10, down1 = 0.35, down2 = 0.26, reset = 0.01 }, -- +18
		{ success = 0.28, maintain = 0.10, down1 = 0.35, down2 = 0.26, reset = 0.01 }, -- +19
		{ success = 0.18, maintain = 0.08, down1 = 0.38, down2 = 0.34, reset = 0.02 }, -- +20
		{ success = 0.18, maintain = 0.08, down1 = 0.38, down2 = 0.34, reset = 0.02 }, -- +21
		{ success = 0.18, maintain = 0.08, down1 = 0.38, down2 = 0.34, reset = 0.02 }, -- +22
		{ success = 0.12, maintain = 0.05, down1 = 0.38, down2 = 0.42, reset = 0.03 }, -- +23
		{ success = 0.12, maintain = 0.05, down1 = 0.38, down2 = 0.42, reset = 0.03 }, -- +24
	},

	-- 강화 단계별 데미지 계수(누적, 6.1). 최종 배율 = 1 + damageCoefficient[level+1].
	damageCoefficient = {
		0,                                -- +0
		0.10, 0.20, 0.30, 0.40, 0.50,      -- +1~+5
		0.70, 0.90, 1.10, 1.30, 1.50,      -- +6~+10
		1.90, 2.30, 2.70, 3.10, 3.50,      -- +11~+15
		4.30, 5.10, 5.90, 6.70, 7.50,      -- +16~+20
		9.10, 10.70, 12.30, 13.90, 15.50,  -- +21~+25
	},

	-- 강화 시도 1회 골드 비용(6.2-2, 골드만). index는 "시도 전 현재 강화 단계+1".
	goldCost = {
		10, 20, 30, 40, 50,               -- +0~+4 -> +1~+5
		100, 150, 200, 250, 300,          -- +5~+9 -> +6~+10
		400, 500, 700, 850, 1000,         -- +10~+14 -> +11~+15
		1500, 2000, 2600, 3300, 4100,     -- +15~+19 -> +16~+20
		5000, 6500, 8500, 11000, 14000,   -- +20~+24 -> +21~+25
	},
}
