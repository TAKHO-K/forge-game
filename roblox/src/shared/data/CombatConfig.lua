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
	-- P2.5a(k 1.155 → 1.02): 0.023846 → 0.470951. 옛 앵커(레벨 100 · itemLevel 100 · 스테이지 100 · 궁수 · 일반 3부위)의 두 비율(최대체력 ÷ 몬스터공격력
	-- = 2.8804, 방어력 ÷ (α × 몬스터공격력) = 1.4302 - 생존 7.0타)을 새 k의 고스테이지(상수 +10 HP · +5 방어의 몫이 사라지는 곳 - 옛 k에서는 레벨 100에서 이미
	-- 그랬다)에서 그대로 두도록 아래 maxHpBonusBase와 함께 다시 풀었다(로컬 하네스 - docs/phase/P25a-log.md). 결과 생존: 스테이지 1,000 이상 7.0타 ·
	-- 100 7.8타 · 1 ~ 25 8.6 ~ 10.7타. 아이템 계수(25 뒤 k^(L−25))와 몬스터 공격(k^(S−1))의 접합 배율 k^−24가 k에 따라 달라서(1.155 → 0.0316, 1.02 → 0.622)
	-- 옛 값을 그대로 두면 앵커에서 생존이 약 2,700타(사실상 무적)가 된다.
	damageReductionAlpha = 0.470951,

	-- 최대체력 성장(17-1, PRD-forge-game-roblox.md 20.11-4 "maxHp 성장 경로"가 이미
	-- 정해 둔 값을 그대로 가져온다 - 이번 세션 전까지 로블록스에 구현이 안 돼 있었다).
	-- 갑옷에서만 나온다(defenseFlat과 나란히, 등급은 안 본다) - Loot.getMaxHpBonus 참고.
	--   maxHpBonus(itemLevel) = maxHpBonusBase × CharacterLevel.getItemLevelMultiplier(itemLevel)
	-- defenseFlat과 완전히 같은 함수(같은 k=1.155)를 재사용한다 - 그래야 몬스터공격력
	-- 대비 "받는 피해/최대체력" 비율이 스테이지 무관 상수로 수렴한다(PRD 20.11-4 검증
	-- 그대로, 17-1 [0]에서 레벨50~200+로 재확인).
	-- P2.5a: 300 → 15.19(위 damageReductionAlpha 주석 - 새 k의 고스테이지에서 최대체력 ÷ 몬스터공격력 2.8804를 유지하는 값).
	maxHpBonusBase = 15.19,

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
	-- 받는 피해 배율의 최종 하한(G1-0 · P3d-F 결정 1): 출처별 감소(대시 · 회전베기 · 궁극기 · 성벽 · 포효 …)는 곱으로 합치되 이 값 밑으로는 안 내려간다.
	-- 완전 무적(0배)은 배율이 아니라 PlayerState.setInvulnerableUntil 플래그라 이 하한과 무관하다.
	incomingDamageMultiplierFloor = 0.25,

	comboHitEvery = 3, -- N번째 공격마다 강타
	comboHitMultiplier = 1.8,
	comboResetWindowSeconds = 2, -- 이 시간 동안 공격 없으면 콤보 카운터 초기화
	-- 3타 표시 = 무기 발광(M1-0 후속 - 사용자: 발밑 고리는 버튼 · 화면과 겹쳐 난잡). 단계 = 이번 사이클에 친 수(2 = 다음 타가 강타).
	-- colorKey는 UIColors 키 - 강화 이펙트(ember · gold · danger · 흰색)와 겹치지 않는 보라. 내 무기 = mine, 남(Player Attribute ComboStage) = others(준비 단계만 · 약하게).
	-- flashBrightness = 준비 순간 한 번 번쩍(flashSeconds 동안 ready로 내려온다).
	comboGlow = {
		colorKey = "comboGlow",
		mine = { hit = { brightness = 0.6, range = 4 }, ready = { brightness = 4, range = 10 } }, -- hit = 1타 뒤(은은) · ready = 2타 뒤(다음 타 강타)
		others = { ready = { brightness = 1.2, range = 5 } },
		flashBrightness = 10,
		flashSeconds = 0.25,
	},

	-- 자동 체력회복(17-1, 19-1에서 조건 확장). 마지막 전투 행위(피격 또는 공격 시도) 후
	-- 이 시간이 지나면 회복이 시작되고, 피격되거나 공격을 시도하면 즉시 중단·리셋된다
	-- (PlayerState.setLastCombatActionAt) - "쉬고 있을 때"의 보상이지 싸우는 중엔 아니다.
	-- 회복 속도를 고정 수치가 아니라 "최대체력의 %/초"로 정의한 이유 - 최대체력이 레벨에
	-- 따라 지수적으로 커지므로(maxHpBonusBase), 고정 수치는 후반에 무의미해진다(초당 1처럼
	-- 고정하면 레벨100에서 사실상 0%/초와 같다).
	regenDelaySeconds = 5,
	regenPercentPerSecond = 0.04, -- 25초면 만피

	-- 흡혈(lifesteal) 초당 회복 상한(26-2, PRD 20.67 [6-1]) - "%만으로는 안전해질 수 없다"의
	-- 결론: 흡혈률 %에 상한을 두는 대신 회복량 자체에 초당 상한을 둔다. 값은
	-- regenPercentPerSecond와 같게 골랐다("전투 중에도 쉴 때의 자동회복 속도까지는 흡혈로
	-- 벌 수 있다") - 그러나 별도 필드다(20.67 [15] 임의 결정 16 "회복 속도를 바꿀 때 흡혈
	-- 상한이 따라 움직이면 [6-1] 증명이 소리 없이 깨진다"). PlayerState.tryLifesteal(토큰
	-- 버킷, 용량·충전 모두 이 값×maxHp/초)이 유일하게 읽는다.
	lifestealMaxHpFractionPerSecond = 0.04,

	-- 조작감(19-2) - 공격 방향 회전. 클릭 방향과 15도 이내면 회전 없이 즉시 공격하고
	-- (몬스터가 계속 움직이므로 임계값이 없으면 미세 회전 딜레이가 매번 붙어 답답해진다),
	-- 그보다 크면 720도/초로 최단 방향(시계/반시계 중 가까운 쪽)으로 돌고 회전이 끝나야
	-- 공격이 나간다. AttackInput.client.lua가 이 값만 쓴다 - 코드에 흩뿌리지 않는다.
	turnSpeedDegPerSecond = 720,
	turnSnapThresholdDeg = 15,

	-- 기여 비율 보상 임계값(19-4, C안 - PRD 20.13이 미결로 남긴 "공유 몬스터 드랍 정책"을
	-- 여기서 확정한다). 사냥터 잡몹은 공유 HP(비율)라 여러 플레이어가 동시에 때릴 수 있다 -
	-- 몬스터가 죽었을 때 이 비율 이상 기여한 플레이어 "전원"이 각자 온전한 보상(골드·경험치·
	-- 드랍)을 받는다(나눠 갖지 않는다, MonsterState.lua의 contributions 참고). 막타 1인
	-- 방식(2b)이 만드는 킬스틸 유인을 없애는 게 목적이므로, 시작값은 "가볍게 거들어도
	-- 자격이 생기는" 낮은 문턱인 10%로 잡는다 - 상수로 빼둔다(실측 후 조정 대상).
	contributionRewardThreshold = 0.10,

	-- C1 기준 스테이지(shared/MobShare): 잡몹의 참여자 = 최근 participationWindowSeconds초 안에 타격 · 어그로(쫓기는 중) · 치유/보호(참여자를 도움)로 닿은 사람.
	-- 기준 스테이지 = 참여자 중 가장 높은 스테이지 - 모든 피해를 그 HP로 환산한다. stageChangeCooldownSeconds = 서버가 받는 스테이지 변경 요청 간격(연타 제한).
	participationWindowSeconds = 8,
	-- 치유 · 보호 · 버프 참여는 치유사가 그 몹에서 이 거리 안일 때만(파티 버프는 거리 무관하게 걸린다 - C1 리뷰 1). 파티 경험치 공유 반경(PartyConfig 150)보다 좁은 "같은 싸움" 거리.
	supportRadiusStuds = 60,
	-- C1 후속(사용자 결정): 몹의 현재 참여자 중 가장 낮은 스테이지보다 이 값 넘게 높은 사람은 막힌다(피해 0 · 참여 안 됨 · 머리 위 "다른 사람 몹").
	-- 이하면 기존 공유 규칙(스틸 가능 · 기준 상승 재정규화 · 기여 10%). 레벨이 아니라 스테이지 차. 낮은 참여자가 8초 무참여면 풀린다.
	stealStageGap = 10,
	ownedMobLabelSeconds = 1, -- 막힘 알림 뒤 이 시간 안의 피해 0 숫자를 "다른 사람 몹"으로 바꿔 그린다(클라 DamageNumbers)
	stageChangeCooldownSeconds = 1,

	-- 점프 중 기본공격 입력 버퍼(19-2). 점프 중엔 공격이 나가지 않고 회전만 한다 - 착지
	-- 순간 이 시간 안에 눌린 입력만 버퍼되어 발동한다(격투게임 입력 버퍼와 같은 개념).
	-- 점프 시작할 때 누른 입력이 한참 뒤 착지에 나가면 유령 공격처럼 느껴지므로, 착지
	-- 직전 짧은 창만 유효하게 둔다.
	jumpAttackBufferSeconds = 0.3,

	-- 활 백스텝샷(20-2b [1][4])처럼 "다음 N회 평타 사거리 배율" 버프가 걸릴 때 실제로
	-- 적용할 상한(20-4 [2]). 배율을 그대로 곱하면 WorldConfig.aggro.rangeStuds(25.6)를
	-- 넘어 "몬스터가 어그로하기 전에 때리는" 무한 안전 사냥 구간이 생긴다(19-2가 사거리보다
	-- 어그로 범위를 더 크게 잡아 막았던 것과 정확히 같은 문제) - 어그로 범위에서 이
	-- 여유값만큼 뺀 선을 절대 넘지 않는다(PlayerCombat.getBuffedAttackRange). 정확히
	-- 어그로 범위와 같으면 판정 순서에 따라 경계값이 애매해질 수 있어 여유를 둔다.
	rangeBuffAggroMarginStuds = 1,

	-- 확정 치명타 버프(20-6, 쌍검 Q 그림자분신, PRD 4.3)의 초과분 처리 - "치명타 확률이
	-- 이미 100%에 도달한 경우, 확정 치명타 효과는 치명타 피해율 +40%로 전환된다"(기존
	-- critDmg 배율에 이 값을 더한다, 곱하지 않는다). 지금은 크리 확률을 올려주는 장비가
	-- 없어 이 분기가 실제로 발동할 일은 없지만(쌍검 기본 30%뿐), 나중에 장비 치확 옵션이
	-- 생겼을 때를 위해 PRD 규칙을 그대로 넣어 둔다.
	guaranteedCritOverflowBonus = 0.4,

	-- P2.5c 결정 2(사용자 확정): 신규 보호 - 옛 k(1.155)의 초반 "무적"(스테이지 1 갑옷 1,370타) 역할을 되살린다. 받는 사람의 **최고** 무한 스테이지 s(지금 스테이지는 내릴 수 있어 악용된다 - P2.5c 리뷰 1)가
	-- untilStage 이하면 받는 피해 × atStage1^(1 − (s − 1) ÷ untilStage) - 스테이지 1 ×0.1 · 10 ×0.28 · 15 ×0.50 · 20 ×0.89 · 21부터 1(기하 감소 - 계단 없음,
	-- 선형보다 중간 스테이지 보호가 두텁다). 계산 = PlayerCombat.getNewbieDamageMultiplier(서버 피해 공통 지점 PlayerDamage.applyFinalDamage · 시뮬 생존 타수가 같은 함수).
	-- 스테이지 번호 자체가 뜻이다(첫 구간 - 힘 비율 아님). 값 = 캐주얼 프로필 스테이지 10 ≤ 30분을 맞춘 값(하네스 격자 - docs/phase/P25c-log.md).
	-- BR1-2(사용자 - 보스 6종을 한 번씩 만나는 1 ~ 30은 받는 피해를 크게 줄이고 25 ~ 30에서 부드럽게 푼다): 1 ~ plateauStage = atStage1 × (atPlateau ÷ atStage1)^((s − 1) ÷ (plateauStage − 1))
	-- (1 ×0.10 · 10 ×0.15 · 20 ×0.24 · 24 ×0.30) → plateauStage ~ untilStage + 1 = smoothstep으로 atPlateau → 1(25 ×0.34 · 27 ×0.60 · 30 ×0.96) → 31부터 ×1. 기준 = 최고 스테이지(그대로).
	newbieProtection = { untilStage = 30, atStage1 = 0.1, plateauStage = 24, atPlateau = 0.3 },
}
