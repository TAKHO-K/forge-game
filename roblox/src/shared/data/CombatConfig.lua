-- 평타 상수. 밸런스 수식(피해감소율 α, 등급 배율, 스킬 계수)은 아직 넣지 않는다 - 평타
-- 하나만 만든다. 웹 값(data/balance.js) 기준, 9-1에서 정한 1 stud = 10px로 환산.

return {
	-- 웹 meleeRange=100px(대검 기준, data/classes.js) / 10px per stud = 10stud.
	-- 캐릭터 너비(약 4stud)의 2.5배 정도라 로블록스 근접 사거리로 어색하지 않다.
	attackRangeStuds = 10,

	-- 웹 attackInterval 그대로(시간값이라 stud 환산 대상이 아니다).
	attackCooldownSeconds = 0.28,

	-- 공격력은 10-2부터 여기 없다 - WeaponData.weapons.starter_sword.baseAttack(=10, 옮긴
	-- 값 그대로)을 기준으로 무기 기본값×강화 배율×등급 배율×클래스 배율로 계산한다
	-- (PlayerCombat.getAttack). 죽은 필드로 남겨두지 않는다.
	--
	-- classAttackMultiplier(10-2가 만든 자리, 항상 1.0)도 10-3부터 여기 없다 - 실제 클래스별
	-- 값(ClassData.lua)이 생겨서 자리만 있던 필드가 죽은 필드가 됐다. 이제 클래스 배율은
	-- PlayerCombat이 ClassData에서 직접 읽는다.

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
	--
	-- 13-3에서 0.072 -> 0.2029104로 재보정(PRD 20.24). 13-2가 장비 방어력 보너스의 기준을
	-- dropStage에서 itemLevel로 바꾸면서, 보너스 자체가 정확히 c=2.44×1.155=2.8182배가
	-- 됐다(등급·레벨 무관 - CharacterLevel 레벨25 정점 2.44에 InfiniteStageConfig.growthRate
	-- 1.155가 곱해진 것). 피해감소율 = D/(D+αA)에서 D가 c배 되면 α도 c배 올려야
	-- (cD)/(cD+cαA) = D/(D+αA)로 분자분모의 c가 약분되어 감소율이 그대로 보존된다 -
	-- 20.11-4가 α를 역산했던 "완전무장" 앵커(장비 보너스가 CombatConfig.playerDefense=5를
	-- 압도하는 상태)를 그대로 유지하는 선택이다(20.24, 사용자 승인).
	--
	-- 반올림하지 않는다 - 아래 값은 0.072 * 2.44 * 1.155의 정확한 곱이다.
	--
	-- 알아둘 것: 이 c배 보존은 "장비 보너스"에만 정확히 성립한다. CombatConfig.playerDefense
	-- (레벨 무관 고정값 5)는 이번 스케일링의 영향을 받지 않고 그대로 더해지므로, 미착용·
	-- 저레벨(장비 보너스가 5에 비해 작은) 구간은 이 상쇄가 근사적으로만 성립하고 완전히
	-- 정확하지는 않다(20.24 - 미결 항목으로 기록). "완전무장"에 가까울수록(장비 보너스가
	-- 5를 압도할수록) 근사가 정확해진다 - 이번 재보정은 그 완전무장 앵커를 우선한 결정이다.
	damageReductionAlpha = 0.072 * 2.44 * 1.155, -- = 0.2029104

	-- 웹 BALANCE.playerDefense=5 그대로. 클래스 배율은 10-3부터 PlayerCombat.getDefense가
	-- 이 값에 곱한다 - 여긴 배율 적용 전 기본값만 남는다.
	playerDefense = 5,

	-- 웹 BALANCE.playerMaxHp=10 그대로.
	playerMaxHp = 10,

	-- 피격 상한(playerDamageCapRatio)은 9-5에서 폐지했다(PRD-forge-game-roblox.md 20.11-4
	-- "재확인 — 피격 상한 폐지" 참고) - 스펙이 모자란 구역에서 즉사하는 걸 "여기 오면
	-- 안 된다"는 신호로 쓰기로 방향을 바꿨다. 상한이 있으면 그 신호가 뭉개진다. 파티
	-- 모드가 생기면 그쪽에서만 별도로 상한을 되살려야 한다(같은 문서, 파티 관련 항목) -
	-- 지금은 파티가 없으니 여기 죽은 필드로 남겨두지 않는다.
}
