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
	-- 17-1에서 0.2029104 -> 0.023846으로 재보정. 13-3(20.24)의 "완전무장 앵커"는 캐릭터
	-- 레벨25 부근에서 역산한 값이라, 레벨100(itemLevel100, 스테이지100)까지 그대로 끌고
	-- 가면 생존 타수가 사실상 0으로 붕괴한다는 게 17-1 [0] 실측으로 드러났다(maxHp가
	-- CombatConfig.playerMaxHp=10에 고정된 채 몬스터공격력만 무한히 자랐던 게 근본
	-- 원인 - 아래 maxHpBonusBase 도입으로 그 축을 새로 열었다). 새 앵커: 캐릭터레벨100 +
	-- 갑옷/장갑/신발 전부 itemLevel100(일반등급), bow 클래스, 목표 생존 타수 7대.
	-- maxHpBonusBase(300)를 반영한 뒤 이 앵커를 만족하도록 역산한 값이 아래 상수다 -
	-- HP_BASE(300)와 defenseFlat이 몬스터공격력과 같은 k=1.155로 자라므로(CharacterLevel.
	-- getItemLevelMultiplier), 이 α는 레벨50~200+ 전 구간에서 7대로 안정된다(단일
	-- 레벨에서만 맞는 값이 아니다 - 17-1 [0] 보고서 참고). 반올림값이라 정확한 유도식은
	-- 없다 - 목표식 hits=maxHp×(D+αA)/(αA²)=7을 α에 대해 풀어 역산했다.
	damageReductionAlpha = 0.023846,

	-- 최대체력 성장(17-1, PRD-forge-game-roblox.md 20.11-4 "maxHp 성장 경로"가 이미
	-- 정해 둔 값을 그대로 가져온다 - 이번 세션 전까지 로블록스에 구현이 안 돼 있었다).
	-- 갑옷에서만 나온다(defenseFlat과 나란히, 등급은 안 본다) - Loot.getMaxHpBonus 참고.
	--   maxHpBonus(itemLevel) = maxHpBonusBase × CharacterLevel.getItemLevelMultiplier(itemLevel)
	-- defenseFlat과 완전히 같은 함수(같은 k=1.155)를 재사용한다 - 그래야 몬스터공격력
	-- 대비 "받는 피해/최대체력" 비율이 스테이지 무관 상수로 수렴한다(PRD 20.11-4 검증
	-- 그대로, 17-1 [0]에서 레벨50~200+로 재확인).
	maxHpBonusBase = 300,

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

	-- 3타 강타(16-7). 웹 값(data/balance.js BALANCE.combo*) 그대로 옮긴다 - 새로 정하지
	-- 않는다는 지시. 모든 직업 공통, 넉백 없음(웹 구현에 없다).
	comboHitEvery = 3, -- N번째 공격마다 강타
	comboHitMultiplier = 1.8,
	comboResetWindowSeconds = 2, -- 이 시간 동안 공격 없으면 콤보 카운터 초기화

	-- 자동 체력회복(17-1, 19-1에서 조건 확장). 마지막 전투 행위(피격 또는 공격 시도) 후
	-- 이 시간이 지나면 회복이 시작되고, 피격되거나 공격을 시도하면 즉시 중단·리셋된다
	-- (PlayerState.setLastCombatActionAt) - "쉬고 있을 때"의 보상이지 싸우는 중엔 아니다.
	-- 회복 속도를 고정 수치가 아니라 "최대체력의 %/초"로 정의한 이유 - 최대체력이 레벨에
	-- 따라 지수적으로 커지므로(maxHpBonusBase), 고정 수치는 후반에 무의미해진다(초당 1처럼
	-- 고정하면 레벨100에서 사실상 0%/초와 같다).
	regenDelaySeconds = 5,
	regenPercentPerSecond = 0.04, -- 25초면 만피
}
