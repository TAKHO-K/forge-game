-- SEC-FIX-1 11(VERIFY-6 M03 · 출시 막음): 라이브 플레이어 DataStore 이름 자리(서버 전용 - 클라 복제 안 됨). 지금 = nil → SaveConfig.dataStoreName 그대로(개발 Studio와 같은 이름).
--   출시 직전에 새 이름(예: "ForgeGamePlayerData_live1")을 넣고 배포한다 - 라이브 서버만 이 이름을 쓰고 Studio(수동 · 검증 Play)는 늘 SaveConfig 이름.
--   주의: 이름을 바꾸면 그 순간 라이브의 모든 저장이 새 저장소에서 시작한다(옛 저장소 값은 그대로 남지만 읽지 않음) - 실제 유저가 생기기 전에 한 번만 바꾼다.
--   다른 저장소(파티 · 리더보드 · 감사 · 선물 등)는 이미 Studio/라이브를 접미사 · 접두사로 나눈다(VERIFY-6 부록 C) - 이 자리는 플레이어 프로필 저장소 하나.
return {
	playerDataStoreName = nil,
}
