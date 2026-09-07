-- 캐릭터 레벨(무기 경험치) 곡선. 웹 data/balance.js WEAPON_LEVEL_EXP(1~25)를 그대로 옮기고,
-- 26+ 구간은 PRD-forge-game-roblox.md 20.10이 정의한 공식을 그대로 쓴다(13-2 설계 확정,
-- 사용자 승인 - A안: 레벨이 무기 공격력·아이템 레벨계수 둘 다에 기여한다).

return {
	-- 1~25 누적 필요 경험치. index N = 레벨N 도달 누적치. data/balance.js WEAPON_LEVEL_EXP 그대로.
	weaponLevelExp = {
		0, 50, 150, 300, 500, -- Lv1~5
		600, 800, 1100, 1500, 2000, -- Lv6~10
		2250, 2700, 3400, 4350, 5500, -- Lv11~15
		5950, 6800, 8100, 9850, 12000, -- Lv16~20
		12850, 14600, 17200, 20650, 25000, -- Lv21~25
	},

	-- 레벨당 스탯 보너스 계수(1~25 구간, 선형). data/balance.js weaponExpAttackBonusPerLevel과
	-- data/items.js ITEM_LEVEL_STAT_BONUS_PER_LEVEL이 원래 같은 값(0.06)이었던 것을 그대로
	-- 재사용한다 - 무기 공격력·아이템 스탯이 레벨25에서 나란히 2.44배로 정점을 찍는 대칭
	-- (웹 설계 의도, data/items.js 75-78행 주석)을 그대로 가져온다.
	statBonusPerLevel = 0.06,

	-- 26+ 구간 무기 공격력 배율 성장률(g). PRD 20.10 확정값 - 몬스터 HP 성장률
	-- k=1.155(InfiniteStageConfig.growthRate)보다 살짝 낮게 잡아 스테이지가 오를수록
	-- 아주 조금씩 어려워지도록 설계됐다(20.10 "왜 레벨당 +6%를 무한 구간에 그대로 못 쓰는가").
	weaponMultGrowthRate = 1.15,

	-- 26+ 구간 경험치 곡선(PRD 20.10). EXP(L) = base×(ratio^(L-1)-1)/divisor의 계수 그대로 -
	-- "1~25를 재현하는 공식"이 아니라 "26부터 자연스럽게 이어 붙이는" 목적이라 1~25 실측표와
	-- 정확히 안 맞아도 된다(20.10 본문, Lv25 공식값 25,057 vs 실측 25,000 - 0.2% 오차 허용).
	expFormulaBase = 50,
	expFormulaRatio = 1.216,
	expFormulaDivisor = 0.216,
}
