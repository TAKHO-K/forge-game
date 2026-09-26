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
	-- BR1-2 도움 단계(사용자 - 시간 제한은 없고, 오래 걸리면 쉬워진다 · 시계 = 전투 기준(파티 공통) · 두 코스 모두 · 솔로도 같다):
	--   1단계 stage1Seconds: 코스 발판 boostEvery칸마다 윗면에 높이 점프 발판(밟으면 발 + boostHeightStuds - 다음 발판까지 1단 점프 없이 오른다)
	--   2단계 stage2Seconds: 코스 시작 곁 바닥에 발사 발판(밟으면 수정 발판 윗면 + 3으로 포물선 - 정점은 수정 발판 + launchApexAboveStuds)
	--   값 근거 = 코스별 깨끗한 완주 추정(BR1-2 보고서 · 하네스 - 발판마다 도움닫기 1.2초 + 그 조합의 최대 체공): 가장 긴 코스 약 20초 · 두 코스 + 사이 이동 약 50초 →
	--   1단계 45초(솔로가 첫 코스를 한 번쯤 떨어져도 두 번째 코스 전에 도움) · 2단계 90초(1단계로도 두 배 넘게 걸리면 바로 간다).
	help = { stage1Seconds = 45, stage2Seconds = 90, boostEvery = 2, boostHeightStuds = 20, boostPadStuds = 2.4, launchPadStuds = 5, launchApexAboveStuds = 8, launchOffsetStuds = 8 },
	-- 도움 발판 발사 식(클라 BossEnvironmentView가 띄우고 서버 BossJumpCourse.padLaunchSpec가 같은 식으로 허가 정점을 잰다 - M1-2c): 발판 중심 위 루트 0 ~ probeRootStuds면 밟음 ·
	-- 발사 발판 정점 = max(LaunchApexY(없으면 목표 + defaultApexAboveTargetStuds), 루트 + apexMinAboveRootStuds, 목표 + targetClearStuds) · 높이 점프 발판 기본 높이 defaultBoostHeightStuds.
	padLaunch = { probeRootStuds = 5, apexMinAboveRootStuds = 2, defaultApexAboveTargetStuds = 8, targetClearStuds = 1, defaultBoostHeightStuds = 18 },
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
