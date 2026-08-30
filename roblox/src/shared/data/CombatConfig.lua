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
	-- 웹 BALANCE.damageNumberLifetime과 통일(9-5 개정) - 로블록스만 0.6으로 다르게 둘
	-- 이유가 없었고, 웹은 이미 실플레이로 검증된 값이라 그쪽에 맞췄다.
	damageNumberLifetimeSeconds = 0.8,

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

	-- 피격 상한(playerDamageCapRatio)은 9-5에서 폐지했다(PRD-forge-game-roblox.md 20.11-4
	-- "재확인 — 피격 상한 폐지" 참고) - 스펙이 모자란 구역에서 즉사하는 걸 "여기 오면
	-- 안 된다"는 신호로 쓰기로 방향을 바꿨다. 상한이 있으면 그 신호가 뭉개진다. 파티
	-- 모드가 생기면 그쪽에서만 별도로 상한을 되살려야 한다(같은 문서, 파티 관련 항목) -
	-- 지금은 파티가 없으니 여기 죽은 필드로 남겨두지 않는다.
}
