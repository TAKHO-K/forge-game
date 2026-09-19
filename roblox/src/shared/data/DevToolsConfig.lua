-- 밸런스 테스트 도구(DevTools.server.lua) 접근 제어(19-3a). 값 자체엔 밸런스 수치가
-- 없지만("코드 밖에 둔다"는 원칙이 이 파일에도 적용된다 - 허용 UserId를 서버 스크립트
-- 안에 하드코딩하면 나중에 바꿀 때마다 로직 파일을 열어야 한다), 이 파일 하나가 곧 "누가
-- 치트를 쓸 수 있는가"를 결정하므로 안전장치 자체의 일부다.
--
-- DevTools는 RunService:IsStudio()가 true일 때만 동작한다(1차 방어, 라이브 서버에선
-- 이 파일 내용과 무관하게 항상 꺼져 있다). allowedUserIds는 2차 방어 - Team Create로
-- 여러 명이 같은 Studio 세션에 들어와도 지정한 계정만 명령을 쓰게 좁힌다. 빈 배열이면
-- "Studio 안의 아무나"를 허용한다(1차 방어만으로 이미 충분히 안전하다는 뜻).

return {
	allowedUserIds = {},

	-- 서버 시작 때 도는 자동 검증 블록의 실행 스위치(DevTools.server.lua의 verifyEnabled). 블록마다 id("26-2" · "29-3(나)" · "S05(가)" ...)가 있다.
	-- 옛 세션의 블록이 Play마다 전부 돌면 한 번에 4분 가까이 걸린다(S05 실측 3분 55초) - 그래서 기본은 "지금 세션의 블록만"이다.
	--   regression = false(기본): current에 적은 id의 블록만 돈다.
	--   regression = true: 과거 세션의 블록 전부 + current. **세션의 마지막 Play 1회에서만 켜고, 그 Play가 끝나면 다시 false로 되돌린다**(COMMON.md §3 · §5).
	-- 새 세션을 시작할 때 current를 그 세션의 블록 id로 갈아 끼운다(전 세션의 id는 지운다 - regression이 켜질 때 어차피 다 돈다).
	verify = {
		regression = false,
		current = {}, -- S06은 서버 검증 블록이 없다(클라 UI 세션 - 검증은 클라 콘솔 [S06][UI] · 마지막 Play가 회귀 전체)
	},
}
