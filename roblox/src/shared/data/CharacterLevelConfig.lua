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

	-- 26+ 구간 경험치 곡선. EXP(L) = base×(ratio^(L-1)-1)/divisor의 계수 그대로 -
	-- "1~25를 재현하는 공식"이 아니라 "26부터 자연스럽게 이어 붙이는" 목적이라 1~25 실측표와
	-- 정확히 안 맞아도 된다.
	--
	-- 17-1에서 ratio·divisor를 1.216/0.216 -> 1.155/0.155로 바꿨다(PRD 20.10의 원래 값은
	-- 무기 공격력 성장률 g=1.15에 맞춘 것이었는데, 몬스터 HP/공격력 성장률
	-- InfiniteStageConfig.growthRate(k=1.155)와 어긋나 있었다 - 레벨이 스테이지를 못
	-- 따라가는 구조적 문제였다. 17-1 [0]에서 실측: 레벨1->100 누적으로 어긋남이 163배까지
	-- 벌어짐. k로 맞추면 레벨당 필요 처치 수가 레벨과 무관하게 일정해진다 - 아래
	-- monsterExpCoefficient 참고). expFormulaBase(50)는 그대로 둔다 - base와
	-- monsterExpCoefficient는 서로 반비례하는 자유도라(둘 다 바꿔도 "레벨당 처치 수"는
	-- 안 바뀐다) 굳이 같이 바꿀 이유가 없다.
	expFormulaBase = 50,
	expFormulaRatio = 1.155,
	expFormulaDivisor = 0.155,

	-- 몬스터 처치 경험치 계수(17-1). MonsterData.lua가 각 tier의 expReward를
	-- `hp × monsterExpCoefficient`로 계산하는 데 쓴다 - "몬스터 경험치는 그 몬스터의 최대
	-- HP에 비례한다"는 설계(17-1 [0])의 유일한 튜닝 노브. 0.025는 "레벨당 정확히 25마리"가
	-- 되도록 역산한 값이다(레벨26~150 전 구간에서 실측 확인 - expFormulaRatio가 k와
	-- 같아졌기 때문에 이 마리 수가 레벨과 무관하게 일정하다).
	monsterExpCoefficient = 0.025,
}
