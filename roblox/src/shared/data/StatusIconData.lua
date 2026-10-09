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
		-- BOSS-NIGHT-3 자리(reserved - 지금 아무도 켜지 않음)
		{ id = "slow", nameKey = "status.slow", source = "StatusSlowUntil", order = 6, reserved = true }, -- 둔화(이동 속도 감소)
		{ id = "crystalMark", nameKey = "status.crystalMark", source = "StatusCrystalMarkUntil", order = 7, reserved = true, kind = "debuff" }, -- 수정 표식(취약 - 받는 피해 증가)
	},
}
