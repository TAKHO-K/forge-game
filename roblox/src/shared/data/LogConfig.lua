-- SEC-FIX-1 9(AUDIT1 #12): 로그 단계 스위치. 단계 = DEBUG < INFO < WARN < OFF(그 단계 이상만 찍는다).
--   라이브 서버 = WARN(옛 print 약 260줄 = INFO - 피격 · 드랍 · 강화 · 구매 id · 파티 합류 코드 같은 내부 값과 클라가 일으킬 수 있는 줄이 콘솔에 쌓였다) · warn은 그대로 나간다.
--   Studio = DEBUG(지금처럼 다 찍는다 - 자동 검증 · 로그 폴링이 print 줄을 읽는다). 라이브에서 잠깐 자세히 보려면 liveLevel만 바꿔 배포.
return {
	liveLevel = "WARN",
	studioLevel = "DEBUG",
}
