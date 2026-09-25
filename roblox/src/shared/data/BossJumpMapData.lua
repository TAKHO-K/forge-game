-- BR1-2 수정 여왕 환경 변화의 점프맵(docs/design/boss-br1-2.md §6-4 · 사용자 보강 C). 코스는 여러 개를 미리 만들어 두고(서버 시작 때 ServerStorage에 짓는다 - BossJumpCourse)
-- 환경 변화 때 수정 자리마다 무작위 1개를 꺼내 쓴다. 끝나면 치운다.
--   난이도 = 로블록스 어려운 점프맵 평균(movement-metrics v2 §3 "어려움" - 공중 점프 · 대시 조합). 단계 = { gap(앞 발판 끝 → 이 발판 끝 수평 간격), rise(높이 차 - 오름 +),
--   width(발판 한 변), turnDeg(앞 방향에서 꺾는 각), checkpoint(떨어지면 여기로), crystal(수정이 서는 마지막 발판) }.
--   검사(BR1-2(가) · 하네스): 단계마다 간격 ≤ 최대 간격(그 높이 차 · 가장 약한 기술 조합 - JumpMath.maxAirSeconds) × safety · 대시 단계 사이 ≥ dashSpacingSteps(쿨 8초) ·
--   어려운 단계(공중 점프 2회 또는 대시) ≥ minHardSteps · 발판 폭 ≥ minWidth · 아레나 안(중심에서 반경 − wallMarginStuds 안 · 보스 자리 centerClearStuds 밖).
return {
	safety = 0.8, -- 표 값의 80%(발판 끝을 겨누지 않게 - movement-metrics §3)
	walkSpeedStuds = 16, -- 최저 이속 기준(신발 없음)
	dashSpacingSteps = 3, -- 대시 쿨 8초 ÷ 발판 한 칸 약 2.5 ~ 3초
	minHardSteps = 4,
	minWidth = 2.5,
	platformThicknessStuds = 1,
	siteRadiusStuds = 40, -- 코스 시작 발판 자리(아레나 중심에서) - 두 수정 자리는 서로 반대 방위
	wallMarginStuds = 14,
	centerClearStuds = 18,
	crystal = { hits = 3, hitIntervalSeconds = 0.3 }, -- 수정 하나 = 유효 타격 3번(구조물 · 상자와 같은 1인 간격)
	-- 코스 4종(자리마다 무작위 1개 - 두 자리는 서로 다른 것)
	courses = {
		{
			name = "나선 계단",
			steps = {
				{ gap = 5, rise = 3, width = 4, turnDeg = 0 },
				{ gap = 11, rise = 5, width = 3, turnDeg = 70 },
				{ gap = 16, rise = 3, width = 3, turnDeg = 70, checkpoint = true },
				{ gap = 24, rise = 2, width = 3, turnDeg = -80 },
				{ gap = 10, rise = 7, width = 3, turnDeg = 60 },
				{ gap = 17, rise = 3, width = 3, turnDeg = 60, checkpoint = true },
				{ gap = 12, rise = 5, width = 2.5, turnDeg = -90 },
				{ gap = 25, rise = 0, width = 3, turnDeg = 70 },
				{ gap = 9, rise = 3, width = 4, turnDeg = 40, crystal = true },
			},
		},
		{
			name = "지그재그 탑",
			steps = {
				{ gap = 6, rise = 2, width = 4, turnDeg = 0 },
				{ gap = 14, rise = 4, width = 3, turnDeg = 90 },
				{ gap = 14, rise = 4, width = 3, turnDeg = -90, checkpoint = true },
				{ gap = 18, rise = 3, width = 2.5, turnDeg = 90 },
				{ gap = 13, rise = 6, width = 3, turnDeg = -90 },
				{ gap = 26, rise = 1, width = 3, turnDeg = 90, checkpoint = true },
				{ gap = 11, rise = 6, width = 2.5, turnDeg = -90 },
				{ gap = 15, rise = 4, width = 3, turnDeg = 90 },
				{ gap = 8, rise = 2, width = 4, turnDeg = -45, crystal = true },
			},
		},
		{
			name = "끊긴 다리",
			steps = {
				{ gap = 5, rise = 2, width = 4, turnDeg = 0 },
				{ gap = 16, rise = 2, width = 3, turnDeg = 20 },
				{ gap = 22, rise = 3, width = 3, turnDeg = 20, checkpoint = true },
				{ gap = 12, rise = 6, width = 2.5, turnDeg = 110 },
				{ gap = 17, rise = 4, width = 3, turnDeg = 20 },
				{ gap = 10, rise = 7, width = 3, turnDeg = 20, checkpoint = true },
				{ gap = 27, rise = 0, width = 3, turnDeg = 110 },
				{ gap = 14, rise = 4, width = 2.5, turnDeg = 20 },
				{ gap = 9, rise = 2, width = 4, turnDeg = 30, crystal = true },
			},
		},
		{
			name = "떠 있는 섬",
			steps = {
				{ gap = 6, rise = 3, width = 4, turnDeg = 0 },
				{ gap = 13, rise = 5, width = 3, turnDeg = -60 },
				{ gap = 19, rise = 2, width = 3, turnDeg = -60 },
				{ gap = 10, rise = 7, width = 2.5, turnDeg = 100, checkpoint = true },
				{ gap = 23, rise = 2, width = 3, turnDeg = -60 },
				{ gap = 15, rise = 4, width = 3, turnDeg = -60 },
				{ gap = 11, rise = 6, width = 2.5, turnDeg = 100, checkpoint = true },
				{ gap = 17, rise = 3, width = 3, turnDeg = -60 },
				{ gap = 8, rise = 2, width = 4, turnDeg = -40, crystal = true },
			},
		},
	},
}
