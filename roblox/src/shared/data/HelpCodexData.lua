-- 도움말(백과사전) 항목 목록 - 창 UI는 P4. 문구는 TextData(번역 가능 문자열 규칙 - 키 = 한 문장 전체)에만 둔다.
-- 항목: id · titleKey · bodyKey · category(창의 분류 탭 - P4에서 확정).
return {
	entries = {
		{ id = "stealLock", titleKey = "codex.stealLock.title", bodyKey = "codex.stealLock.body", category = "combat", bodyArgs = { percent = "contributionRewardThreshold" } }, -- bodyArgs = CombatConfig 키(× 100) -- C1 마무리: 잠긴 몹(스틸 규칙)
	},
}
