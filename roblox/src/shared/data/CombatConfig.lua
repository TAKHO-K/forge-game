-- 평타 상수. 밸런스 수식(피해감소율 α, 등급 배율, 스킬 계수)은 아직 넣지 않는다 - 평타
-- 하나만 만든다. 웹 값(data/balance.js) 기준, 9-1에서 정한 1 stud = 10px로 환산.

return {
	-- 웹 meleeRange=100px(대검 기준, data/classes.js) / 10px per stud = 10stud.
	-- 캐릭터 너비(약 4stud)의 2.5배 정도라 로블록스 근접 사거리로 어색하지 않다.
	attackRangeStuds = 10,

	-- 웹 attackInterval 그대로(시간값이라 stud 환산 대상이 아니다).
	attackCooldownSeconds = 0.28,

	-- 웹 playerAttack 그대로(고정 데미지값이라 stud 환산 대상이 아니다. 등급·스킬
	-- 배율 미적용 - 그건 전투가 더 갖춰졌을 때 넣는다).
	playerAttackPower = 10,
}
