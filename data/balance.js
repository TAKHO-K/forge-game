// 자주 만지는 수치 모음
const BALANCE = {
  projectileSpeed: 600,
  projectileRadius: 6,
  projectileRange: 400,
  attackInterval: 0.2,
  playerAttack: 10,
  critChance: 0.3,
  critMultiplier: 1.8,
  damageNumberLifetime: 0.8,
  damageNumberRiseSpeed: 40,
  enhanceResultDisplayTime: 1.5,
  playerMaxHp: 10,
  playerDefense: 5,
  playerDamageCapRatio: 0.3,
  playerIframeDuration: 0.8,
  playerRegenNoHitThreshold: 12,
  playerRegenInterval: 3,
  monsterApproachSpeed: 80,
  dashDistance: 160, // 캐릭터 4칸 분량 (반지름 20 기준 지름 40 x 4)
  dashDuration: 0.3,
  dashCooldown: 8,
  dashDamageReduction: 0.5,
  mapWidth: 2400,
  mapHeight: 1600,
  wallThickness: 20,
  aggroRange: 250,
  leashRange: 400,
  returnSpeed: 120,
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
  rareMaterialChance: 0.035,
  rareGoldMultiplier: 0.5,
  sparkleGradeChances: { legend: 0.9, relic: 0.09, primordial: 0.01 },
  materialTicketByTier: [1, 1, 2, 2, 3, 3]
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
