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

	-- 데미지 숫자가 떠 있는 시간. 죽은 몬스터의 마지막 데미지 숫자가 사라질 시간을
	-- 벌어줘야 해서 사망 처리(MonsterSpawner.despawn)의 시체 유지 시간도 이 값을 같이 쓴다.
	-- 웹의 BALANCE.damageNumberLifetime=0.8과 값이 다른데(0.6), 이번 세션 범위가 아니라
	-- 맞추지 않았다 - 나중에 재검토 필요.
	damageNumberLifetimeSeconds = 0.6,

	-- 몬스터가 플레이어를 때릴 때 받는 데미지 계산(PRD-forge-game-roblox.md 20.11-4
	-- "새 공식 - 비율 감소"). 뺄셈(공격력-방어력) 대신 비율식을 쓴다 - 웹에서 두 값이
	-- 같은 속도로 커지면 뺄셈이 0 아니면 전부로 붕괴하는 무적 버그를 냈던 구조라서다.
	--   피해감소율 = 방어력 / (방어력 + damageReductionAlpha × 몬스터공격력)
	--   받는 데미지 = 몬스터공격력 × (1 − 피해감소율)
	damageReductionAlpha = 0.072, -- PRD 확정 상수. 스테이지·등급 무관 고정값.

	-- 웹 BALANCE.playerDefense=5 그대로(클래스 배율 없음 - CombatConfig.playerAttackPower와
	-- 같은 이유로 아직 클래스가 없다).
	playerDefense = 5,

	-- 웹 BALANCE.playerMaxHp=10 그대로.
	playerMaxHp = 10,

	-- 웹 BALANCE.playerDamageCapRatio=0.3 그대로. 받는 데미지가 최대체력의 이 비율을
	-- 넘지 못하게 잘라 한 방에 훅 깎이는 걸 막는다.
	playerDamageCapRatio = 0.3,
}
