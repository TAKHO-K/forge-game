-- QUEUE-ALL1 P4 §3 주간 도전(docs/design/v2/05 §3): 별도 모드 - 매주 보스 1종 + 변형 규칙(표 = 여기) · 기본 보스 기록 · 시즌 리더보드 · 첫 클리어 드랍과 분리(토벌과 같은 입장 규칙 - isRaid).
--   주 = Quest.weekOf(월요일 UTC) · cycle[(주 − 1) % #cycle + 1] · 모두 같은 스테이지(stage - 처치 시간 순위의 공정성).
--   변형(mods) = { path = { "skills" | "environment", 스킬 id?, 필드 }, mul = 배수, max? = 상한(정수 필드는 반올림) } - 인스턴스 사본에만(BossData 원본 불변 · shared/WeeklyChallenge.apply).
--   검사: 변형 뒤에도 회피 부등식(BossSkillMath.dodgeChecks)을 지켜야 한다 - /gg weekly check · 검증(WeeklyChallenge.check).
--   보상: 그 주 첫 처치 = participation · 지난주 순위(로그인 때 한 번) = rankRewards(1위 칭호 · 10위까지 반짝 조각). 순위 = OrderedDataStore(처치 초 × 100 · 오름차순).
return {
	stage = 40,
	storeName = "WeeklyChallenge_v1",
	studioSuffix = "_studio",
	cycle = {
		{ bossId = "crystal_queen", label = "분신 2배", mods = { { path = { "skills", "mirrorDash", "directions" }, mul = 2, max = 6 } } },
		{ bossId = "storm_lord", label = "번개 2배", mods = { { path = { "skills", "strike", "count" }, mul = 2, max = 4 } } },
		{ bossId = "section_guardian", label = "바닥 붕괴 빨라짐", mods = { { path = { "environment", "cooldownSeconds" }, mul = 0.7 } } },
		{ bossId = "crystal_queen", label = "파편 유도 강화", mods = { { path = { "skills", "shards", "turnRateDeg" }, mul = 1.5 } } },
	},
	participation = { sparkleShard = 20 },
	rankRewards = { { upTo = 1, reward = { sparkleShard = 100 }, title = "weeklyChampion" }, { upTo = 10, reward = { sparkleShard = 50 } } },
	topShown = 5,
	text = { button = "주간 도전", start = "도전", rank = "이번 주 순위(처치 시간)", none = "아직 기록 없음", done = "주간 도전 완료! %.1f초", reward = "지난주 주간 도전 %d위 보상" },
}
