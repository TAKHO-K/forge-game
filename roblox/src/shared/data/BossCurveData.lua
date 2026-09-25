-- BR1-2 스테이지별 보스 난이도 곡선(docs/design/boss-br1-2.md §1) - 표 하나. 모든 보스 패턴이 이 표를 읽는다(보스 이름이 들어간 분기 없음 -
-- BossRules.buildInstanceDataFrom이 스킬표 사본에 BossSkillMath.applyCurve로 곱한다).
--   단계(사용자): ① 초반 = 투사체 · 장판 수 적게 → ② 투사체 크기 · 장판 범위 증가 → ③ 투사체 개수 증가 → ④ 최대 = 인당 한 패턴에 투사체 8개.
--   행 = { fromStage, tier, projectileCountScale, projectileRadiusScale, zoneRangeScale, zoneExtra, chainExtra }
--     projectileCountScale  인당 투사체 = BR1 기본 개수(스킬의 count) × 이 값(반올림 · 최소 1 · 상한 perPersonMax). math.huge = 상한 그대로.
--     projectileRadiusScale 투사체 반경 ×
--     zoneRangeScale        장판(원 · 도넛 · 부채꼴 · 직선 반폭 · 돌진 경로 · 흩어짐) 범위 × - 옛 이속 보정(BossRules.skillRangeScale)에 곱한다.
--                           넓어져 회피 부등식이 깨지는 스킬은 전조를 모자란 만큼 늘린다(BossSkillMath.fitTelegraphs - 큰 범위 = 긴 전조).
--     zoneExtra             동시 낙하 원 개수 ±(옛 stageDensity를 대신한다 - 대상 조건 BossSkillMath.densityEligible · 최소 1개)
--     chainExtra            연쇄 칸 수 ±(수정 가시 등 circleTarget.chain · 최소 3칸)
--   경계 근거(EconSim 도달 시간 - P3c 보고서 E3 · BR1-2 보고서 ①): ① ≤ 100 = 첫 환생 전후(캐주얼 약 3시간) · ② 101 ~ 500 = 캐주얼 3 ~ 26시간 ·
--   ③ 501 ~ 5000 = 캐주얼 26 ~ 390시간(1000칸마다 한 칸 더) · ④ 5001 ~ = 캐주얼 390시간 · 일반 200시간 뒤.
return {
	perPersonMax = 8, -- 인당 한 패턴 투사체 상한(사용자 - ④ 최대)
	-- 아레나(보스 하나)당 동시에 살아 있는 투사체 상한 - 넘치면 새로 쏘지 않는다(성능 - BR1-2 보고서 성능 표). 4인 × 8 = 32 + 이전 패턴의 잔여.
	arenaProjectileCap = 48,
	rows = {
		{ fromStage = 1, tier = 1, projectileCountScale = 0.5, projectileRadiusScale = 1.0, zoneRangeScale = 1.0, zoneExtra = -1, chainExtra = -2 },
		{ fromStage = 101, tier = 2, projectileCountScale = 1, projectileRadiusScale = 1.15, zoneRangeScale = 1.05, zoneExtra = 0, chainExtra = 0 },
		{ fromStage = 301, tier = 2, projectileCountScale = 1, projectileRadiusScale = 1.3, zoneRangeScale = 1.1, zoneExtra = 0, chainExtra = 0 },
		{ fromStage = 501, tier = 3, projectileCountScale = 1.5, projectileRadiusScale = 1.3, zoneRangeScale = 1.1, zoneExtra = 1, chainExtra = 1 },
		{ fromStage = 1001, tier = 3, projectileCountScale = 2, projectileRadiusScale = 1.3, zoneRangeScale = 1.1, zoneExtra = 1, chainExtra = 2 },
		{ fromStage = 2001, tier = 3, projectileCountScale = 3, projectileRadiusScale = 1.3, zoneRangeScale = 1.1, zoneExtra = 2, chainExtra = 3 },
		{ fromStage = 5001, tier = 4, projectileCountScale = math.huge, projectileRadiusScale = 1.4, zoneRangeScale = 1.15, zoneExtra = 3, chainExtra = 4 },
	},
	-- 표 검사(BR1-2(가)) 표본 스테이지(사용자 지정)
	sampleStages = { 5, 30, 100, 500, 2000, 10000, 25300 },
}
