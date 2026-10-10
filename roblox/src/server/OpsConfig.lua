-- S1 2-8 운영 명령 허용 계정(서버 전용 - 클라에 복제 안 됨). 라이브 · Studio 공통. 추가 = 이 목록에 UserId를 넣고 배포.
return {
	userIds = { 11595243049 }, -- HoddyForge(개발 계정)
	-- SEC-FIX-1 4b: 기록 제외 계정(라이브의 개발 · 운영 계정 - 옛 = shared/data/LeaderboardConfig.excludedUserIds · 클라에 운영 계정이 보였다). 쓰는 곳 = Leaderboard.eligibility · TranscendFirsts · P3dVerify.
	-- P3d G-g(사용자 결정 "라이브 제외 = 개발 계정") · 제외는 라이브(writeMode "live")에서만 건다.
	leaderboardExcludedUserIds = { 11595243049 },
}
