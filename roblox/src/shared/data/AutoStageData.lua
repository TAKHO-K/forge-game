-- C5-4 자동 스테이지 이동(docs/design/growth-curve-v2.md §7): 전투력 ÷ 권장(CombatFormula.recommendedPower)이 triggerRatio 이상이면 "비율 ≥ 설정값인 가장 높은 일반 스테이지"로 숫자만 이동.
--   보스 관문은 수동(관문 앞에서 멈추고 도전 알림) · 파티 = 리더만 · 최고 기록(infiniteBest) · 리더보드 영향 0(이동 상한 = 지금 최고) · C1 공유 규칙과 충돌 없음(StageServer의 일반 이동과 같은 경로).
--   서버(AutoStage.server.lua)가 checkSeconds마다 본다. 설정 = 클라 설정 창 → RemoteEvent AutoStageSetting → 서버 보관(Player Attribute AutoStage - 이번 접속 동안 · 저장은 P4-4).
return {
	triggerRatio = 1.3, -- 이 비율 이상일 때만 움직인다(넉넉함의 문턱 - 평탄 상한 1.3과 같다)
	presets = { -- 설정값(이동 목표 비율) · 순서 = 설정 창 버튼 순환 순서
		{ id = "easy", name = "편함", ratio = 1.2 },
		{ id = "normal", name = "보통", ratio = 1.0 },
		{ id = "challenge", name = "도전", ratio = 0.85 },
		{ id = "off", name = "끄기", ratio = nil },
	},
	default = "normal",
	checkSeconds = 5,
	bossGateNoticeSeconds = 120, -- 같은 관문 도전 알림 반복 간격
}
