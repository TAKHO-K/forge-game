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
	-- UI-1 1단계(00 v8 §4 · 39 + 옛 1): 아이콘 id → 범주(cc 빨강 · debuff 노랑 · buff 파랑 · 색 = UiPartsData.statusColors) · 그림(ui/ds/status-<id>) · 이름 · 효과 한 줄 키(TextData_ui1).
	--   src = 데이터 연결: attr(Attribute 이름) · on("player" | "character" | "boss") · mode("truthy" = 있으면 · "untilServer" = 서버 시각 끝 · "untilOs" = os.time 끝) · buff(BuffUpdate id)
	--   src 없음 = 연결할 데이터 없음 → 안 보임(CC-UI-1 §1 · MISSING 8). strong = 강한 버프(빛) · unused = 파일만(옛 이름).
	icons = {
		stun = { cat = "cc", src = { { attr = "BossStunned", on = "player", mode = "truthy", seconds = 0.7 }, { attr = "BossStunUntil", on = "boss", mode = "untilServer" } } },
		["trap-freeze"] = { cat = "cc", trapKinds = { "frozen", "airFrozen", "snowball" } },
		["trap-submerge"] = { cat = "cc", trapKinds = { "submerged" } },
		["trap-crystal"] = { cat = "cc", trapKinds = { "crystallized", "crystal" } },
		["trap-bury"] = { cat = "cc", trapKinds = { "buried" } },
		["trap-shock"] = { cat = "cc", trapKinds = { "shocked" } },
		["trap-grab"] = { cat = "cc", trapKinds = { "grabbed" }, trapFallback = true }, -- 표에 없는 잡힘 종류 = 잡힘
		["grab-lift"] = { cat = "cc", src = { { attr = "BossGrabGauge", on = "player", mode = "truthy" } } },
		airborne = { cat = "cc", src = { { attr = "StatusAirborneUntil", on = "player", mode = "untilServer" } } },
		["cage-bubble"] = { cat = "cc", trapKinds = { "bubbled" } },
		["cage-tornado"] = { cat = "cc", trapKinds = { "tornado" } },
		knockdown = { cat = "cc", src = { { attr = "FallKnockdown", on = "character", mode = "truthy", seconds = 1.6 } } },
		stagger = { cat = "cc", src = { { attr = "StatusStaggerUntil", on = "player", mode = "untilServer" } } },
		knockback = { cat = "cc", src = { { attr = "StatusKnockbackUntil", on = "player", mode = "untilServer" } } },
		petrify = { cat = "cc", trapKinds = { "statue" } },
		slow = { cat = "debuff", src = { { attr = "StatusSlowUntil", on = "player", mode = "untilServer" } } },
		["crystal-mark"] = { cat = "debuff", src = { { attr = "StatusCrystalMarkUntil", on = "player", mode = "untilServer" } } },
		["dmg-taken-up"] = { cat = "debuff" },
		["regen-off"] = { cat = "debuff", src = { { attr = "BossEncounterId", on = "player", mode = "truthy" } } }, -- 보스전 = 자동회복 꺼짐
		["shared-damage"] = { cat = "debuff" },
		["power-shot"] = { cat = "buff", src = { { buff = "quickShot" } } },
		["backstep-charge"] = { cat = "buff", src = { { buff = "backstepShotBuff" } } },
		["shadow-clone"] = { cat = "buff", src = { { buff = "guaranteedCrit" } } },
		["dealing-mode"] = { cat = "buff", src = { { buff = "dealingMode" } } },
		heal = { cat = "buff", src = { { buff = "healerBuff" } } },
		shield = { cat = "buff", src = { { attr = "Shield", on = "player", mode = "positive" }, { attr = "BossShielded", on = "boss", mode = "truthy" } } },
		["war-cry"] = { cat = "buff", src = { { buff = "warcryBuff" } } },
		["shadow-mark"] = { cat = "buff", src = { { buff = "shadowMark" } } },
		destroyer = { cat = "buff", src = { { attr = "UltTransform", on = "player", mode = "truthy" } } },
		sanctuary = { cat = "buff" },
		whirlwind = { cat = "buff" },
		["dash-guard"] = { cat = "buff", src = { { attr = "StatusDashGuardUntil", on = "player", mode = "untilServer" } } },
		invuln = { cat = "buff" },
		["first-boss-help"] = { cat = "buff" },
		berserk = { cat = "buff" },
		comeback = { cat = "buff", strong = true, src = { { attr = "ComebackUntil", on = "player", mode = "untilOs" } } },
		["boss-trap"] = { cat = "debuff" },
		["boss-transform-guard"] = { cat = "buff", src = { { attr = "BossTransformGuard", on = "boss", mode = "truthy", seconds = 3.5 } } },
		["boss-enrage"] = { cat = "buff", src = { { attr = "BossEnraged", on = "boss", mode = "truthy" } } }, -- UI-1 0단계 ⑧ 서버 Attribute 하나
		["dash-invuln"] = { cat = "buff", unused = true }, -- 옛 이름(대시 무적) - v2에서 dash-guard로 · 파일만
	},
}
