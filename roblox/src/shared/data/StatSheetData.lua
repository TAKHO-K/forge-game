-- QUEUE-ALL9C 1-2(C1): 캐릭터 창 상세 스탯 목록. 화면(client/panels/Character)은 이 표를 위에서부터 그리기만 한다 - 줄 추가 = 여기 한 줄 + 서버 계산 하나(PlayerProfile.getStatSheet의 BUILDERS).
--   id = 줄(글자 키 "stat.<id>") · format = 합계 표기(big = 큰 수 · pct = +n% · rate = n%(0 ~ 1 값) · mult = ×n).
--   출처(sources) = 분해에 나오는 순서 · 글자 키 "stat.src.<id>". 출처 값 kind = mult(×n 곱) · add(+n% 더함) · flat(+n 절대값).
--   ALL10에서 방어 · 초월 강화 · 고급 수련 · 초월 보석이 늘면 rows · sources에 줄을 더한다(화면 코드 수정 없음).
return {
	rows = {
		{ id = "attack", format = "big" },
		{ id = "attackSpeed", format = "mult" }, -- 실제 적용 배율(상한 CombatConfig.attackSpeedMaxMultiplier) · 출처 = 상한 전 더하기 몫
		{ id = "critRate", format = "rate" },
		{ id = "critDmg", format = "rate" },
		{ id = "maxHp", format = "big" },
		{ id = "defense", format = "big" },
		{ id = "moveSpeed", format = "mult" },
		{ id = "expGain", format = "mult" },
	},
	sources = { "base", "gear", "enhance", "training", "codex", "gem", "buff" },
}
