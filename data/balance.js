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
  bossTimerDuration: 600,
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
  bossRetryFarmDuration: 180,
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

// 무기 레벨별 누적 필요 경험치 (PRD 4.2) - index는 레벨-1, 값은 그 레벨 도달까지 누적 경험치
// 1/5/10/15/20/25레벨 기준값(0/500/2000/5500/12000/25000)에 맞춰 보간, 세부 밸런스는 추후 조정
const WEAPON_LEVEL_EXP = [
  0, 50, 150, 300, 500,                    // Lv1~5
  600, 800, 1100, 1500, 2000,              // Lv6~10
  2250, 2700, 3400, 4350, 5500,            // Lv11~15
  5950, 6800, 8100, 9850, 12000,           // Lv16~20
  12850, 14600, 17200, 20650, 25000        // Lv21~25
];
