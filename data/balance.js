// 자주 만지는 수치 모음
const BALANCE = {
  // 탭이 백그라운드로 갔다 오면 dt = (now - lastTime)/1000 이 수십 초로 튈 수 있어 캡을 둔다.
  // 0.1(최저 10fps 상당)은 실제 프레임 드랍은 자연스럽게 수용하면서 순간이동·타이머 급감 같은
  // 비정상 점프는 막는, 게임 루프에서 흔히 쓰는 값
  maxFrameDt: 0.1,
  playerRadius: 20,
  playerSpeed: 200,
  projectileSpeed: 600,
  projectileRadius: 6,
  projectileRange: 400,
  attackInterval: 0.28,
  playerAttack: 10,
  damageFloorRatio: 0.1,
  guaranteedCritOverflowBonus: 0.4, // 확정 치명타가 이미 100% 치확과 겹칠 때 대신 붙는 치명타 피해율 (PRD 4.3)
  meleeSwingVisualDuration: 0.15, // 대검·쌍검 부채꼴 스윙 이펙트 표시 시간
  meleeRangeIndicatorAlpha: 0.12, // 공격 안 할 때도 항상 보이는 옅은 판정 범위 표시
  comboHitEvery: 3, // N번째 공격마다 강타
  comboHitMultiplier: 1.8,
  comboResetWindow: 2, // 이 시간(초) 동안 공격 없으면 콤보 카운터 초기화
  comboSwingScale: 1.35, // 강타 시 근접 스윙 이펙트 확대 배율 (판정 범위 자체는 그대로)
  damageNumberLifetime: 0.8,
  damageNumberRiseSpeed: 40,
  enhanceResultDisplayTime: 1.5,
  playerMaxHp: 10,
  hpBarMaxPerRow: 10, // 체력바 한 줄 최대 칸 수 - 넘으면 마인크래프트처럼 윗줄로 쌓임 (최대 체력 증가 시스템 대비)
  playerDefense: 5,
  playerDamageCapRatio: 0.3,
  playerIframeDuration: 0.8,
  playerRegenNoHitThreshold: 12,
  playerRegenInterval: 3,
  playerRegenAmount: 1,
  monsterApproachSpeed: 80,
  dashDistance: 160, // 캐릭터 4칸 분량 (반지름 20 기준 지름 40 x 4)
  dashDuration: 0.3,
  dashCooldown: 8,
  dashDamageReduction: 0.5,
  mapWidth: 2400,
  mapHeight: 1600,
  wallThickness: 20,
  huntSpawnX: 1200, // 사냥터 시작·리스폰 좌표 (맵 기준) - 화면 크기와 무관해야 창을 줄여도 대장간 안에서 리스폰되지 않음
  huntSpawnY: 600,
  aggroRange: 250,
  leashRange: 400,
  returnSpeed: 120,
  respawnTime: 3,
  zoneYMargin: 120,
  forgeHeight: 320,
  forgeAutoMaxLevel: 10,
  bossTimerDuration: 1800,
  gameSpeedOptions: [1, 2, 3], // 배속 - 파밍량은 그대로 두고 실제 걸리는 시간만 압축 (loop()에서 dt에 곱함)
  forgeNoticeDuration: 3,
  bossCountdown: 5,
  bossMapWidth: 1200,
  bossMapHeight: 900,
  bossZoneEntryMinDistance: 400,
  bossStartFreezeDuration: 2,
  bossEnrageHpRatio: 0.1,
  bossEnrageAttackMultiplier: 2,
  bossGradeThresholds: { S: 0.3, A: 0.5, B: 0.75, C: 1.0 },
  bossGradeMultipliers: { S: 2.0, A: 1.5, B: 1.2, C: 1.0 },
  bossMaxRetries: 2,
  bossRetryFarmDuration: 180, // 30분 본 타이머와 별개로 유지 - 재도전 전 짧은 재정비 구간이라 3배로 늘리면 실패할수록 파밍 시간이 불어나는 부작용이 생김
  bossResultLostDisplayTime: 3,
  weaponExpAttackBonusPerLevel: 0.06,
  rareSparkleChance: 0.005,
  rareMaterialChance: 0.015,
  rareGoldMultiplier: 0.5,
  sparkleGradeChances: { relic: 0.9, ancient: 0.09, primordial: 0.01 },
  materialTicketSizeChances: { small: 0.6, medium: 0.3, large: 0.1 }, // 재료 몬스터 확률 강화권 크기 분포
  bossGuaranteedTicketChance: 0.5, // 보스 클리어 시 확정 강화권 +1 지급 확률
  enhanceTicketGroundLifetime: 30,
  ticketPickupMessageDuration: 2,
  dropSlot2Multiplier: 0.3,
  itemGroundLifetime: 60,
  itemDropOffset: 14,
  itemPickupRadius: 20,
  inventoryBagSize: 20,
  expTokenLifetime: 30,
  expTokenAbsorbRadius: 80,
  expTokenHomingSpeed: 300,
  expTokenScatterRadius: 40,
  expTokenCountByTier: [[1, 1], [1, 2], [1, 2], [1, 3], [2, 3], [2, 3]],
  itemBaseSellValue: 50,
  inventoryMessageDisplayTime: 2
};

// 큰 숫자 축약 표기 (core/format.js에서 사용) - 로블록스류 모바일 게임처럼 1000배마다 알파벳 한 글자.
// minValue: 이 값 미만은 축약 없이 천단위 콤마로 표시한다. 1,000~9,999 구간은 골드·판매가처럼
//   플레이어가 자주 마주치는 범위라 정확한 숫자가 더 유용해서, 1000이 아니라 10000부터 축약을 시작한다.
// step: 알파벳 한 글자가 올라갈 때마다 곱해지는 배수(1000 -> A=x1,000 / B=x1,000,000 ...).
// decimals: 소수 자릿수. 1자리면 "1.2A"처럼 대략적인 크기만 보여주면서도 화면 폭을 아낀다 -
//   내림(버림) 처리라 "1.99A"가 "2A"로 반올림돼 다음 단위에 도달한 것처럼 보이는 일이 없다.
// letters: 알파벳이 Z(26번째)를 넘어가면 스프레드시트 열 이름처럼 AA, AB ...로 이어간다(core/format.js).
const NUMBER_ABBREVIATION = {
  minValue: 10000,
  step: 1000,
  decimals: 1,
  letters: "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
};

// 무기 레벨별 누적 필요 경험치 (PRD 4.2) - index는 레벨-1, 값은 그 레벨 도달까지 누적 경험치
// 1/5/10/15/20/25레벨 기준값(0/500/2000/5500/12000/25000)에 맞춰 보간, 세부 밸런스는 추후 조정
const WEAPON_LEVEL_EXP = [
  0, 50, 150, 300, 500,                    // Lv1~5
  600, 800, 1100, 1500, 2000,              // Lv6~10
  2250, 2700, 3400, 4350, 5500,            // Lv11~15
  5950, 6800, 8100, 9850, 12000,           // Lv16~20
  12850, 14600, 17200, 20650, 25000        // Lv21~25
];
