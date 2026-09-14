-- 밸런스 앵커 곡선 정의(21-1 [2], PRD-forge-game-roblox.md 20.44 [2]). 앵커는 한 점(레벨100/
-- 스테이지100/등급0)이 아니라 곡선이다:
--   "캐릭터 레벨 L, 장비 itemLevel L(gearGrade 등급 3부위), 무기 등급 g, 강화 +0,
--    그 조건의 권장 스테이지 rec(L, g)에서 생존 surviveTargetHits타 / tier1 처치 killTargetSeconds초"
-- 이 곡선이 앞으로 모든 밸런스(스킬 계수·보스 HP·어려움 상한)의 기준이다. 숫자를 여기 박지
-- 않고 BalanceSim.solveKillOffset가 이 두 목표에서 rec의 오프셋을 매번 역산한다 - 원본 상수
-- (α·tier1 HP·k·g·계수)가 바뀌면 "/gg curve" 한 줄로 곡선이 다시 나온다(20.42 "파생 표는
-- 원본 상수를 바꿀 때 같이 다시 돌려야 한다").
return {
	surviveTargetHits = 7, -- CombatConfig.damageReductionAlpha 앵커(17-1)와 같은 값.
	killTargetSeconds = 2.5, -- 21-1 지시 - 로테이션(Q+E) 기준 tier1 1마리 처치 시간.

	-- 처치 시간 목표를 어느 직업으로 재는가 - α 앵커가 bow였으므로 같은 직업으로 통일한다.
	referenceClassId = "bow",
	-- 오프셋 역산에 쓰는 레벨 - 레벨26+ 지수 구간 한가운데. 레벨1~25(실측 손튜닝 표 구간)에서
	-- 풀면 구간 경계 때문에 값이 달라진다(20.42 규칙 - "정의역 전체에서 같은 형태인가").
	referenceLevel = 100,

	gearGrade = "normal",
	weaponLevel = 0,

	-- "/gg curve"가 훑는 격자.
	curveLevels = { 25, 50, 75, 100, 125 },
	curveGrades = { 0, 2, 4, 6 },
}
