-- QUEUE-10h Q8 K3 영혼 상태(보스전 - 아레나 · 토벌만. 일반 스테이지 = 옛 즉시 리스폰 그대로). 서버 = server/SoulService.lua · 클라 모습 = client/SoulView.client.lua.
--   보스전에서 죽으면 리스폰된 캐릭터가 영혼: 반투명 · 이동 · 관전만 · 공격 · 피격 · 줍기 불가 · 기믹 대상 밖(BossEncounter.isAlive · BossPatterns.victims가 영혼을 뺀다).
--   부활: 생명의 성역이 끝날 때(성역 안에서 성역 동안 죽은 영혼) · 구원의 기도(반경 안 영혼) · 보스전 끝(전원 복귀). 부활 체력 = reviveHpFraction × 최대 체력.
--   전멸 = 살아 있는 멤버 0(전원 영혼) → 옛 실패 흐름(BossEncounter.resetFor - 보스 체력 복구 · 힌트 단계)을 그대로 타고 영혼은 전부 풀린다.
--   튕김(연결 끊김): 파티 보스전이 이어지면 reconnectGraceSeconds 안에 다시 들어온 사람은 영혼으로 관전 복귀 · 기여(보상 자격)는 옛 Player 몫을 넘겨받는다.
return {
	enabled = true,
	reviveHpFraction = 0.3,
	reconnectGraceSeconds = 120,
	transparency = 0.6, -- 클라 모습(반투명)
	rejectLogSeconds = 1, -- 영혼 공격 거부 로그 사람당 초당 1줄
}
