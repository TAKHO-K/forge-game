-- FINAL-1b 결정 6: 상태 아이콘 줄(디자인 카드 7 - 아직 그리지 않음) CC 정의표. 지속 피해형 상태이상(화상 · 독 · 출혈 · 침묵)은 만들지 않는다(설계 결정).
--   cc = 지금 있는 행동 제약(색 빨강) - source = 그 상태를 알리는 Attribute(캐릭터 · 플레이어) · reserved = BOSS-NIGHT-3에서 들어올 항목의 자리(아직 서버 · 클라 없음 - 이름 · 색 · 순서만)
--   buff · debuff 줄은 BuffState(BuffUpdate)를 그대로 쓴다(이 표 밖). order = 줄에 놓는 순서(같은 색 안에서).
return {
	colors = { cc = "red", debuff = "yellow", buff = "blue" },
	cc = {
		{ id = "stun", nameKey = "status.stun", source = "BossStunned", order = 1 }, -- 기절 0.7초 · 뒤 면역 2초
		{ id = "trap", nameKey = "status.trap", source = "BossTrapKind", order = 2 }, -- 잡힘 6종(빙결 · 침수 · 결정화 · 매몰 · 감전 · 잡힘)
		{ id = "grab", nameKey = "status.grab", source = "BossGrabGauge", order = 3 }, -- 대공 잡기 들림
		{ id = "airLock", nameKey = "status.airLock", source = "AirLocked", order = 4 }, -- 띄우기 · 공중 가둠(거품 · 회오리)
		{ id = "knockdown", nameKey = "status.knockdown", source = "FallKnockdown", order = 5 }, -- 낙하 쓰러짐
		-- BOSS-NIGHT-3 2단계(서버 = server/PlayerCC · DashWindow · Attribute = 서버 시계 끝 시각 workspace:GetServerTimeNow) · icon = handoff 00_design-system/v8 assets 이름
		{ id = "stagger", nameKey = "status.stagger", source = "StatusStaggerUntil", order = 6, icon = "status-stagger" }, -- 경직 0.2초(이동 입력만 · 대시 됨) · 뒤 면역 0.8
		{ id = "knockback", nameKey = "status.knockback", source = "StatusKnockbackUntil", order = 7, icon = "status-knockback" }, -- 넉백(높이 < 5) · 뒤 면역 0.5
		{ id = "airborne", nameKey = "status.airborne", source = "StatusAirborneUntil", order = 8, icon = "status-airborne" }, -- 띄움(높이 ≥ 5) · 0.3초 뒤 공중 대시로 회복 · 뒤 면역 1.0
		{ id = "slow", nameKey = "status.slow", source = "StatusSlowUntil", order = 9, kind = "debuff", icon = "status-slow" }, -- 둔화(걷기 × 0.7 · 3초 · 대시 그대로)
		{ id = "crystalMark", nameKey = "status.crystalMark", source = "StatusCrystalMarkUntil", order = 10, kind = "debuff", icon = "status-crystal-mark" }, -- 수정 표식(그 보스 피해 × 2 · 3초)
		{ id = "dashGuard", nameKey = "status.dashGuard", source = "StatusDashGuardUntil", order = 11, kind = "buff", icon = "status-dash-guard" }, -- 대시 보호 창(받는 피해 × 0.5 · 무적 아님)
	},
}
