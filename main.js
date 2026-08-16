// 게임 초기화 및 메인 루프 진입점
const canvas = document.getElementById("game");
const ctx = canvas.getContext("2d");

const player = {
  x: canvas.width / 2, y: canvas.height / 2, radius: BALANCE.playerRadius, speed: BALANCE.playerSpeed, angle: 0,
  hp: BALANCE.playerMaxHp, maxHp: BALANCE.playerMaxHp, defense: BALANCE.playerDefense,
  iframeTimer: 0, noHitTimer: 0, regenTimer: 0,
  dashTimer: 0, dashCooldownTimer: 0, dashDirX: 1, dashDirY: 0
};

let gameTime = 0;
let lastMoveDirX = 1;
let lastMoveDirY = 0;

function clamp(v, min, max) {
  return Math.min(max, Math.max(min, v));
}

const camera = { x: 0, y: 0 };

// 대장간(안전지대)은 맵 위쪽 forgeHeight 만큼. 그 아래는 전부 사냥터
const FORGE_BOTTOM = BALANCE.wallThickness + BALANCE.forgeHeight;
let wasInForge = false;
let bossTimeRemaining = BALANCE.bossTimerDuration;
let forgeNoticeShown = false;
let forgeNoticeTimer = 0;
const FORGE_NOTICE_TEXT = "싱글 모드에서는 대장간 진입 시 타이머가 멈춥니다";

// 보스존은 사냥터와 완전히 분리된 전용 맵 (PRD 8.0-6) - 좌표는 보스맵 기준
const BOSS_ZONE_X = BALANCE.bossMapWidth / 2;
const BOSS_ZONE_Y = BALANCE.bossMapHeight / 2;
let currentMap = "hunt"; // "hunt" | "boss"
let bossFreezeTimer = 0; // 보스존 진입 후 보스가 정지해 있는 준비 시간
let bossCountdownActive = false;
let bossCountdownTimer = 0;
let bossZoneTriggered = false;

let currentBossStageIndex = 0;
let boss = null;
let bossFightTimeRemaining = 0;
let bossFightFailed = false;
let bossFightResultHandled = false; // 이번 보스전의 승패 결과를 이미 처리했는지 (자동 사라짐 후 재판정 방지)
let bossRetryCount = 0;
let bossResultState = "none"; // "none" | "won" | "lost"
let bossResultInfo = null;
let bossResultAutoHideTimer = 0;
let guaranteedTickets = []; // 확정 강화권 - 각 원소는 상승폭 N (9.6)

function spawnBoss(stageIndex) {
  const data = BOSSES[stageIndex];
  return {
    name: data.name,
    x: BOSS_ZONE_X, y: BOSS_ZONE_Y,
    radius: data.radius,
    color: data.color,
    defense: data.defense,
    baseAttack: data.attack,
    attack: data.attack,
    maxHp: data.hp,
    hp: data.hp,
    alive: true,
    enraged: false
  };
}

function tryDash() {
  if (player.dashCooldownTimer > 0) return;
  let dirX = lastMoveDirX;
  let dirY = lastMoveDirY;
  if (dirX === 0 && dirY === 0) {
    dirX = Math.cos(player.angle);
    dirY = Math.sin(player.angle);
  }
  const len = Math.hypot(dirX, dirY);
  player.dashDirX = dirX / len;
  player.dashDirY = dirY / len;
  player.dashTimer = BALANCE.dashDuration;
  player.dashCooldownTimer = BALANCE.dashCooldown;
}

const keys = {};
window.addEventListener("keydown", (e) => {
  keys[e.key.toLowerCase()] = true;
  if (e.code === "Space") {
    e.preventDefault();
    tryDash();
  }
});
window.addEventListener("keyup", (e) => { keys[e.key.toLowerCase()] = false; });

const mouse = { x: player.x, y: player.y };
canvas.addEventListener("mousemove", (e) => {
  const rect = canvas.getBoundingClientRect();
  mouse.x = e.clientX - rect.left;
  mouse.y = e.clientY - rect.top;
});

const projectiles = [];
function fireProjectile() {
  projectiles.push({
    x: player.x,
    y: player.y,
    angle: player.angle,
    radius: BALANCE.projectileRadius,
    traveled: 0
  });
}

let autoMode = false;
let attackTimer = 0;

// 희귀 몬스터 판정 (PRD 8.0-5) - 스폰 시점마다 판정, 반짝이 0.5% > 재료 3.5% > 일반
function rollRareType() {
  const r = Math.random();
  if (r < BALANCE.rareSparkleChance) return "sparkle";
  if (r < BALANCE.rareSparkleChance + BALANCE.rareMaterialChance) return "material";
  return null;
}

function spawnMonster(x, y, type) {
  const data = MONSTERS[type];
  const rareType = rollRareType();
  return {
    x, y, spawnX: x, spawnY: y, type,
    tier: data.tier,
    radius: data.radius,
    color: data.color,
    defense: data.defense,
    attack: data.attack,
    maxHp: data.hp,
    hp: data.hp,
    goldDrop: rareType ? Math.round(data.goldDrop * BALANCE.rareGoldMultiplier) : data.goldDrop,
    weaponExp: data.weaponExp,
    aggroRange: data.aggroRange,
    rareType,
    alive: true,
    respawnTimer: 0,
    state: "idle"
  };
}

const RESPAWN_TIME = BALANCE.respawnTime;

// 등급(tier)별 구역으로 맵을 나눠 배치 - 왼쪽(1등급)에서 오른쪽(6등급)으로 갈수록 강해짐
const ZONE_COUNT = BALANCE.zoneCount;
const ZONE_Y_MARGIN = BALANCE.zoneYMargin;
const zoneLeft = BALANCE.wallThickness;
const zoneRight = BALANCE.mapWidth - BALANCE.wallThickness;
const zoneTop = FORGE_BOTTOM + ZONE_Y_MARGIN;
const zoneBottom = BALANCE.mapHeight - BALANCE.wallThickness - ZONE_Y_MARGIN;
const zoneWidth = (zoneRight - zoneLeft) / ZONE_COUNT;

const monstersByTier = {};
for (const type of MONSTER_ORDER) {
  const tier = MONSTERS[type].tier;
  if (!monstersByTier[tier]) monstersByTier[tier] = [];
  monstersByTier[tier].push(type);
}

const monsters = [];
for (let tier = 1; tier <= ZONE_COUNT; tier++) {
  const types = monstersByTier[tier] || [];
  const zoneCenterX = zoneLeft + zoneWidth * (tier - 1) + zoneWidth / 2;
  const ySpacing = (zoneBottom - zoneTop) / (types.length + 1);
  types.forEach((type, i) => {
    const y = zoneTop + ySpacing * (i + 1);
    monsters.push(spawnMonster(zoneCenterX, y, type));
  });
}

const damageNumbers = [];
function spawnDamageNumber(x, y, value, isCrit) {
  damageNumbers.push({ x, y, value, isCrit, age: 0 });
}

let weaponLevel = 0;
let enhanceResultText = "";
let enhanceResultTimer = 0;
let gold = 0;

// 무기 경험치 (PRD 4.2) - 강화(weaponLevel)와 별개 축
let weaponExp = 0;
let weaponExpLevel = getWeaponLevelFromExp(weaponExp);

const ENHANCE_RESULT_LABEL = {
  success: (level) => `성공 +${level}`,
  maintain: () => "형상유지",
  down1: () => "-1강",
  down2: () => "-2강",
  reset: () => "1강으로 리셋",
  max: () => "최대 강화 단계"
};

const uiPanel = document.getElementById("ui");
const autoEnhanceMsg = document.getElementById("autoEnhanceMsg");
const enhanceBtn = document.getElementById("enhanceBtn");
const enhanceHighBtn = document.getElementById("enhanceHighBtn");
const useTicketBtn = document.getElementById("useTicketBtn");
const bossResultButtons = document.getElementById("bossResultButtons");
const bossNextStageBtn = document.getElementById("bossNextStageBtn");
const bossExitBtn = document.getElementById("bossExitBtn");

function attemptEnhance(isHigh) {
  const cost = getEnhanceCost(weaponLevel, isHigh);
  if (gold < cost) return;
  gold -= cost;
  const result = tryEnhance(weaponLevel, isHigh);
  weaponLevel = result.level;
  enhanceResultText = ENHANCE_RESULT_LABEL[result.result](weaponLevel);
  enhanceResultTimer = BALANCE.enhanceResultDisplayTime;
}

enhanceBtn.addEventListener("click", () => attemptEnhance(false));
enhanceHighBtn.addEventListener("click", () => attemptEnhance(true));

// 확정 강화권 사용 (PRD 9.6) - 실패 판정 없이 N단계 상승, 최대 강화 단계 초과 불가
function useGuaranteedTicket() {
  if (guaranteedTickets.length === 0) return;
  const n = guaranteedTickets.shift();
  weaponLevel = Math.min(ENHANCE_MAX_LEVEL, weaponLevel + n);
  enhanceResultText = `확정 +${n} 사용`;
  enhanceResultTimer = BALANCE.enhanceResultDisplayTime;
}
useTicketBtn.addEventListener("click", useGuaranteedTicket);

function startNextBossRun(stageIndex) {
  currentBossStageIndex = stageIndex;
  boss = null;
  bossResultState = "none";
  bossResultInfo = null;
  bossFightFailed = false;
  bossFightResultHandled = false;
  bossZoneTriggered = false;
  bossCountdownActive = false;
  bossRetryCount = 0;
  bossTimeRemaining = BALANCE.bossTimerDuration;
  player.x = canvas.width / 2;
  player.y = canvas.height / 2;
}

bossNextStageBtn.addEventListener("click", () => {
  const nextIndex = currentBossStageIndex + 1;
  if (nextIndex >= BOSSES.length) return;
  startNextBossRun(nextIndex);
});

bossExitBtn.addEventListener("click", () => {
  bossResultState = "none";
  bossResultInfo = null;
});

// 대장간 진입 시 재료(골드)가 되는 만큼 +10까지 자동 강화 (PRD 8.0-1-b)
function autoEnhanceInForge() {
  while (weaponLevel < BALANCE.forgeAutoMaxLevel) {
    const cost = getEnhanceCost(weaponLevel, false);
    if (gold < cost) break;
    gold -= cost;
    const result = tryEnhance(weaponLevel, false);
    weaponLevel = result.level;
    enhanceResultText = ENHANCE_RESULT_LABEL[result.result](weaponLevel);
    enhanceResultTimer = BALANCE.enhanceResultDisplayTime;
  }
}

function updateEnhanceButtons() {
  const autoPhase = weaponLevel < BALANCE.forgeAutoMaxLevel;
  autoEnhanceMsg.style.display = autoPhase ? "block" : "none";
  enhanceBtn.style.display = autoPhase ? "none" : "inline-block";
  enhanceHighBtn.style.display = autoPhase ? "none" : "inline-block";
  if (autoPhase) return;

  if (weaponLevel >= ENHANCE_MAX_LEVEL) {
    enhanceBtn.textContent = "일반 강화 (최대)";
    enhanceHighBtn.textContent = "상급 강화 (최대)";
    enhanceBtn.disabled = true;
    enhanceHighBtn.disabled = true;
    return;
  }
  const normalCost = getEnhanceCost(weaponLevel, false);
  const highCost = getEnhanceCost(weaponLevel, true);
  enhanceBtn.textContent = `일반 강화 (${normalCost}G)`;
  enhanceHighBtn.textContent = `상급 강화 (${highCost}G)`;
  enhanceBtn.disabled = gold < normalCost;
  enhanceHighBtn.disabled = gold < highCost;
}

canvas.addEventListener("contextmenu", (e) => e.preventDefault());

canvas.addEventListener("mousedown", (e) => {
  if (e.button === 2) {
    tryDash();
    return;
  }
  if (e.button !== 0) return;
  if (autoMode) return;
  fireProjectile();
});

canvas.addEventListener("dblclick", (e) => {
  if (e.button !== 0) return;
  autoMode = !autoMode;
  attackTimer = 0;
});

let lastTime = performance.now();

function update(dt) {
  gameTime += dt;

  let dx = 0, dy = 0;
  if (keys["w"]) dy -= 1;
  if (keys["s"]) dy += 1;
  if (keys["a"]) dx -= 1;
  if (keys["d"]) dx += 1;

  if (dx !== 0 || dy !== 0) {
    lastMoveDirX = dx;
    lastMoveDirY = dy;
  }

  if (player.dashTimer > 0) {
    const step = (BALANCE.dashDistance / BALANCE.dashDuration) * dt;
    player.x += player.dashDirX * step;
    player.y += player.dashDirY * step;
    player.dashTimer -= dt;
    if (player.dashTimer < 0) player.dashTimer = 0;
  } else if (dx !== 0 || dy !== 0) {
    const len = Math.hypot(dx, dy);
    player.x += (dx / len) * player.speed * dt;
    player.y += (dy / len) * player.speed * dt;
  }

  const mapW = currentMap === "boss" ? BALANCE.bossMapWidth : BALANCE.mapWidth;
  const mapH = currentMap === "boss" ? BALANCE.bossMapHeight : BALANCE.mapHeight;

  player.x = clamp(player.x, BALANCE.wallThickness + player.radius, mapW - BALANCE.wallThickness - player.radius);
  player.y = clamp(player.y, BALANCE.wallThickness + player.radius, mapH - BALANCE.wallThickness - player.radius);

  if (player.dashCooldownTimer > 0) {
    player.dashCooldownTimer -= dt;
    if (player.dashCooldownTimer < 0) player.dashCooldownTimer = 0;
  }

  camera.x = clamp(player.x - canvas.width / 2, 0, mapW - canvas.width);
  camera.y = clamp(player.y - canvas.height / 2, 0, mapH - canvas.height);

  const worldMouseX = mouse.x + camera.x;
  const worldMouseY = mouse.y + camera.y;
  player.angle = Math.atan2(worldMouseY - player.y, worldMouseX - player.x);

  if (autoMode) {
    attackTimer += dt;
    while (attackTimer >= BALANCE.attackInterval) {
      attackTimer -= BALANCE.attackInterval;
      fireProjectile();
    }
  }

  for (const monster of monsters) {
    if (!monster.alive) {
      monster.respawnTimer -= dt;
      if (monster.respawnTimer <= 0) {
        monster.x = monster.spawnX;
        monster.y = monster.spawnY;
        monster.hp = monster.maxHp;
        monster.alive = true;
        monster.state = "idle";
        monster.rareType = rollRareType();
        const baseGold = MONSTERS[monster.type].goldDrop;
        monster.goldDrop = monster.rareType ? Math.round(baseGold * BALANCE.rareGoldMultiplier) : baseGold;
      }
      continue;
    }

    if (monster.attack <= 0) continue;
    if (currentMap !== "hunt") continue; // 보스존에서는 사냥터 몬스터 비활성 (PRD 8.0-6)

    const distToPlayer = Math.hypot(player.x - monster.x, player.y - monster.y);
    const distToSpawn = Math.hypot(monster.spawnX - monster.x, monster.spawnY - monster.y);
    const aggroRange = monster.aggroRange !== undefined ? monster.aggroRange : BALANCE.aggroRange;

    if (monster.state === "idle" && distToPlayer <= aggroRange) {
      monster.state = "chase";
    } else if (monster.state === "chase" && distToSpawn > BALANCE.leashRange) {
      monster.state = "return";
    }

    if (monster.state === "chase") {
      const contactRange = player.radius + monster.radius;
      if (distToPlayer > contactRange) {
        const chaseAngle = Math.atan2(player.y - monster.y, player.x - monster.x);
        const step = BALANCE.monsterApproachSpeed * dt;
        monster.x += Math.cos(chaseAngle) * step;
        monster.y += Math.sin(chaseAngle) * step;
        monster.x = clamp(monster.x, BALANCE.wallThickness + monster.radius, BALANCE.mapWidth - BALANCE.wallThickness - monster.radius);
        monster.y = clamp(monster.y, FORGE_BOTTOM + monster.radius, BALANCE.mapHeight - BALANCE.wallThickness - monster.radius);
      } else if (player.iframeTimer <= 0) {
        let damage = calcPlayerDamage(monster.attack, player.defense, player.maxHp, BALANCE.playerDamageCapRatio);
        if (player.dashTimer > 0) {
          damage = Math.round(damage * (1 - BALANCE.dashDamageReduction));
        }
        player.hp -= damage;
        player.iframeTimer = BALANCE.playerIframeDuration;
        player.noHitTimer = 0;
        player.regenTimer = 0;

        if (player.hp <= 0) {
          player.hp = player.maxHp;
          player.x = canvas.width / 2;
          player.y = canvas.height / 2;
          player.iframeTimer = BALANCE.playerIframeDuration;
          player.dashTimer = 0;
        }
      }
    } else if (monster.state === "return") {
      const step = BALANCE.returnSpeed * dt;
      if (distToSpawn <= step) {
        monster.x = monster.spawnX;
        monster.y = monster.spawnY;
        monster.hp = monster.maxHp;
        monster.state = "idle";
      } else {
        const returnAngle = Math.atan2(monster.spawnY - monster.y, monster.spawnX - monster.x);
        monster.x += Math.cos(returnAngle) * step;
        monster.y += Math.sin(returnAngle) * step;
      }
    }
  }

  for (let i = 0; i < monsters.length; i++) {
    const a = monsters[i];
    if (!a.alive) continue;
    for (let j = i + 1; j < monsters.length; j++) {
      const b = monsters[j];
      if (!b.alive) continue;
      const dx = b.x - a.x;
      const dy = b.y - a.y;
      const dist = Math.hypot(dx, dy);
      const minDist = a.radius + b.radius;
      if (dist === 0) {
        a.x -= 0.5;
        b.x += 0.5;
      } else if (dist < minDist) {
        const overlap = (minDist - dist) / 2;
        const nx = dx / dist;
        const ny = dy / dist;
        a.x -= nx * overlap;
        a.y -= ny * overlap;
        b.x += nx * overlap;
        b.y += ny * overlap;
      }
    }
  }
  for (const m of monsters) {
    if (!m.alive) continue;
    m.x = clamp(m.x, BALANCE.wallThickness + m.radius, BALANCE.mapWidth - BALANCE.wallThickness - m.radius);
    m.y = clamp(m.y, FORGE_BOTTOM + m.radius, BALANCE.mapHeight - BALANCE.wallThickness - m.radius);
  }

  // 구역 판정 (PRD 8.0-1) - 대장간 진입 시 강화 UI 자동 오픈 + 자동 강화, 보스 타이머는 사냥터에서만 흐름
  const inForge = currentMap === "hunt" && player.y <= FORGE_BOTTOM;
  uiPanel.classList.toggle("hidden", !inForge);
  if (inForge && !wasInForge) {
    autoEnhanceInForge();
    if (!forgeNoticeShown) {
      forgeNoticeShown = true;
      forgeNoticeTimer = BALANCE.forgeNoticeDuration;
    }
  }
  wasInForge = inForge;

  if (currentMap === "hunt" && !inForge) {
    bossTimeRemaining = Math.max(0, bossTimeRemaining - dt);
  }

  if (currentMap === "hunt" && bossTimeRemaining <= 0 && !bossCountdownActive && !bossZoneTriggered) {
    bossCountdownActive = true;
    bossCountdownTimer = BALANCE.bossCountdown;
  }
  if (bossCountdownActive) {
    bossCountdownTimer -= dt;
    if (bossCountdownTimer <= 0) {
      bossCountdownActive = false;
      bossZoneTriggered = true;
      currentMap = "boss"; // 사냥터와 분리된 전용 보스맵으로 진입 (PRD 8.0-6)
      boss = spawnBoss(currentBossStageIndex);
      player.x = BOSS_ZONE_X;
      player.y = clamp(
        BOSS_ZONE_Y - BALANCE.bossZoneEntryMinDistance,
        BALANCE.wallThickness + player.radius,
        BALANCE.bossMapHeight - BALANCE.wallThickness - player.radius
      );
      bossFreezeTimer = BALANCE.bossStartFreezeDuration;
      bossFightTimeRemaining = BOSSES[currentBossStageIndex].timeLimit;
      bossFightFailed = false;
      bossFightResultHandled = false;
    }
  }

  if (boss && boss.alive && !bossFightFailed) {
    if (bossFreezeTimer > 0) {
      // 보스존 진입 후 준비 시간 - 보스는 정지 (PRD 8.0-6)
      bossFreezeTimer -= dt;
      if (bossFreezeTimer < 0) bossFreezeTimer = 0;
    } else {
      const distToPlayer = Math.hypot(player.x - boss.x, player.y - boss.y);
      const contactRange = player.radius + boss.radius;
      if (distToPlayer > contactRange) {
        const chaseAngle = Math.atan2(player.y - boss.y, player.x - boss.x);
        const step = BALANCE.monsterApproachSpeed * dt;
        boss.x += Math.cos(chaseAngle) * step;
        boss.y += Math.sin(chaseAngle) * step;
        boss.x = clamp(boss.x, BALANCE.wallThickness + boss.radius, BALANCE.bossMapWidth - BALANCE.wallThickness - boss.radius);
        boss.y = clamp(boss.y, BALANCE.wallThickness + boss.radius, BALANCE.bossMapHeight - BALANCE.wallThickness - boss.radius);
      } else if (player.iframeTimer <= 0) {
        let damage = calcPlayerDamage(boss.attack, player.defense, player.maxHp, BALANCE.playerDamageCapRatio);
        if (player.dashTimer > 0) {
          damage = Math.round(damage * (1 - BALANCE.dashDamageReduction));
        }
        player.hp -= damage;
        player.iframeTimer = BALANCE.playerIframeDuration;
        player.noHitTimer = 0;
        player.regenTimer = 0;

        if (player.hp <= 0) {
          player.hp = player.maxHp;
          player.x = boss.x;
          player.y = clamp(
            boss.y - BALANCE.bossZoneEntryMinDistance,
            BALANCE.wallThickness + player.radius,
            BALANCE.bossMapHeight - BALANCE.wallThickness - player.radius
          );
          player.iframeTimer = BALANCE.playerIframeDuration;
          player.dashTimer = 0;
        }
      }

      if (!boss.enraged && boss.hp <= boss.maxHp * BALANCE.bossEnrageHpRatio) {
        boss.enraged = true;
        boss.attack = boss.baseAttack * BALANCE.bossEnrageAttackMultiplier;
      }

      bossFightTimeRemaining -= dt;
      if (bossFightTimeRemaining <= 0) {
        bossFightTimeRemaining = 0;
        bossFightFailed = true;
      }
    }
  }

  if (forgeNoticeTimer > 0) {
    forgeNoticeTimer -= dt;
    if (forgeNoticeTimer < 0) forgeNoticeTimer = 0;
  }

  player.noHitTimer += dt;
  if (player.iframeTimer > 0) {
    player.iframeTimer -= dt;
    if (player.iframeTimer < 0) player.iframeTimer = 0;
  }
  if (player.noHitTimer >= BALANCE.playerRegenNoHitThreshold && player.hp < player.maxHp) {
    player.regenTimer += dt;
    while (player.regenTimer >= BALANCE.playerRegenInterval && player.hp < player.maxHp) {
      player.regenTimer -= BALANCE.playerRegenInterval;
      player.hp = Math.min(player.maxHp, player.hp + BALANCE.playerRegenAmount);
    }
  }

  for (let i = projectiles.length - 1; i >= 0; i--) {
    const p = projectiles[i];
    const step = BALANCE.projectileSpeed * dt;
    p.x += Math.cos(p.angle) * step;
    p.y += Math.sin(p.angle) * step;
    p.traveled += step;

    if (
      p.x - p.radius <= BALANCE.wallThickness ||
      p.x + p.radius >= mapW - BALANCE.wallThickness ||
      p.y - p.radius <= BALANCE.wallThickness ||
      p.y + p.radius >= mapH - BALANCE.wallThickness
    ) {
      projectiles.splice(i, 1);
      continue;
    }

    const hitMonster = currentMap === "hunt" && monsters.find((m) =>
      m.alive && Math.hypot(p.x - m.x, p.y - m.y) <= p.radius + m.radius
    );
    const hitBoss = !hitMonster && boss && boss.alive && !bossFightFailed &&
      Math.hypot(p.x - boss.x, p.y - boss.y) <= p.radius + boss.radius;

    if (hitMonster) {
      const attack = BALANCE.playerAttack * getEnhanceDamageMultiplier(weaponLevel) * getWeaponExpAttackMultiplier(weaponExpLevel);
      const { damage, isCrit } = calcDamage(attack, hitMonster.defense, BALANCE.critChance, BALANCE.critMultiplier);
      hitMonster.hp -= damage;
      spawnDamageNumber(hitMonster.x, hitMonster.y - hitMonster.radius, damage, isCrit);
      projectiles.splice(i, 1);
      if (hitMonster.hp <= 0) {
        hitMonster.alive = false;
        hitMonster.respawnTimer = RESPAWN_TIME;
        gold += hitMonster.goldDrop;
        weaponExp += hitMonster.weaponExp;
        weaponExpLevel = getWeaponLevelFromExp(weaponExp);

        if (hitMonster.rareType === "sparkle") {
          const roll = Math.random();
          const chances = BALANCE.sparkleGradeChances;
          const grade = roll < chances.primordial ? "태초"
            : roll < chances.primordial + chances.relic ? "유물"
            : "전설";
          console.log(`[반짝이 몬스터 처치] ${grade} 등급 확정 드랍 (장비 시스템 도입 전 - 로그로만 표시)`);
        } else if (hitMonster.rareType === "material") {
          guaranteedTickets.push(BALANCE.materialTicketByTier[hitMonster.tier - 1]);
        }
      }
      continue;
    }

    if (hitBoss) {
      const attack = BALANCE.playerAttack * getEnhanceDamageMultiplier(weaponLevel) * getWeaponExpAttackMultiplier(weaponExpLevel);
      const { damage, isCrit } = calcDamage(attack, boss.defense, BALANCE.critChance, BALANCE.critMultiplier);
      boss.hp -= damage;
      spawnDamageNumber(boss.x, boss.y - boss.radius, damage, isCrit);
      projectiles.splice(i, 1);
      if (boss.hp <= 0) {
        boss.hp = 0;
        boss.alive = false;
      }
      continue;
    }

    if (p.traveled >= BALANCE.projectileRange) {
      projectiles.splice(i, 1);
    }
  }

  for (let i = damageNumbers.length - 1; i >= 0; i--) {
    const dn = damageNumbers[i];
    dn.age += dt;
    dn.y -= BALANCE.damageNumberRiseSpeed * dt;
    if (dn.age >= BALANCE.damageNumberLifetime) {
      damageNumbers.splice(i, 1);
    }
  }

  if (enhanceResultTimer > 0) {
    enhanceResultTimer -= dt;
    if (enhanceResultTimer < 0) enhanceResultTimer = 0;
  }

  // 보스 클리어 판정 (PRD 9.5, 9.6) - 클리어 시간 기준 등급 산정 + 확정 강화권 지급
  if (boss && !boss.alive && !bossFightResultHandled) {
    bossFightResultHandled = true;
    const data = BOSSES[currentBossStageIndex];
    const clearTime = data.timeLimit - Math.max(0, bossFightTimeRemaining);
    const ratio = clearTime / data.timeLimit;
    let grade;
    if (ratio <= BALANCE.bossGradeThresholds.S) grade = "S";
    else if (ratio <= BALANCE.bossGradeThresholds.A) grade = "A";
    else if (ratio <= BALANCE.bossGradeThresholds.B) grade = "B";
    else grade = "C";

    const multiplier = BALANCE.bossGradeMultipliers[grade];
    const goldGained = Math.round(data.clearGoldReward * multiplier);
    gold += goldGained;
    for (let i = 0; i < data.clearTicketCount; i++) guaranteedTickets.push(data.clearTicketValue);

    bossResultState = "won";
    bossResultInfo = { type: "won", grade, goldGained, ticketValue: data.clearTicketValue, ticketCount: data.clearTicketCount };

    // 사냥터로 복귀 (PRD 8.0-6)
    currentMap = "hunt";
    boss = null;
    player.x = canvas.width / 2;
    player.y = canvas.height / 2;
  }

  // 보스 실패 판정 (PRD 9.4) - 재도전 2회까지 3분 추가 파밍 후 자동 재시작
  if (bossFightFailed && !bossFightResultHandled) {
    bossFightResultHandled = true;
    bossRetryCount++;
    const retriesExhausted = bossRetryCount > BALANCE.bossMaxRetries;
    if (!retriesExhausted) {
      bossZoneTriggered = false;
      bossTimeRemaining = BALANCE.bossRetryFarmDuration;
    }
    bossResultState = "lost";
    bossResultInfo = { type: "lost", retriesUsed: bossRetryCount, maxRetries: BALANCE.bossMaxRetries, retriesExhausted };
    bossResultAutoHideTimer = BALANCE.bossResultLostDisplayTime;

    // 사냥터로 복귀 (PRD 8.0-6)
    currentMap = "hunt";
    boss = null;
    player.x = canvas.width / 2;
    player.y = canvas.height / 2;
  }

  if (bossResultState === "lost" && bossResultAutoHideTimer > 0) {
    bossResultAutoHideTimer -= dt;
    if (bossResultAutoHideTimer <= 0) {
      bossResultState = "none";
      bossResultInfo = null;
    }
  }

  bossResultButtons.classList.toggle("hidden", bossResultState !== "won");
  if (bossResultState === "won") {
    bossNextStageBtn.style.display = (currentBossStageIndex + 1 < BOSSES.length) ? "inline-block" : "none";
  }
  useTicketBtn.style.display = guaranteedTickets.length > 0 ? "inline-block" : "none";
  if (guaranteedTickets.length > 0) {
    useTicketBtn.textContent = `확정 강화권 사용 (+${guaranteedTickets[0]}, ${guaranteedTickets.length}개)`;
  }

  updateEnhanceButtons();
}

function render() {
  ctx.clearRect(0, 0, canvas.width, canvas.height);

  const mapW = currentMap === "boss" ? BALANCE.bossMapWidth : BALANCE.mapWidth;
  const mapH = currentMap === "boss" ? BALANCE.bossMapHeight : BALANCE.mapHeight;
  const forgeHeightHere = currentMap === "boss" ? 0 : BALANCE.forgeHeight;

  ctx.save();
  ctx.translate(-camera.x, -camera.y);

  drawMapFloor(ctx, mapW, mapH, BALANCE.wallThickness, forgeHeightHere);
  drawMapWalls(ctx, mapW, mapH, BALANCE.wallThickness);
  if (currentMap === "hunt") {
    for (const monster of monsters) drawMonster(ctx, monster, gameTime);
  }
  drawBoss(ctx, boss);

  const playerAlpha = player.iframeTimer > 0
    ? (Math.floor(gameTime * 10) % 2 === 0 ? 0.4 : 1)
    : 1;
  drawPlayer(ctx, player, playerAlpha);

  drawProjectiles(ctx, projectiles);
  drawDamageNumbers(ctx, damageNumbers);

  ctx.restore();

  if (boss && boss.enraged) drawEnrageVignette(ctx);

  drawAutoIndicator(ctx, autoMode);
  if (currentMap === "hunt") drawOffscreenIndicators(ctx, camera, monsters);
  if (currentMap === "hunt") drawBossTimer(ctx, bossTimeRemaining, player.y <= FORGE_BOTTOM);
  if (forgeNoticeTimer > 0) drawForgeNotice(ctx, FORGE_NOTICE_TEXT);
  if (bossCountdownActive) drawBossCountdown(ctx, Math.ceil(bossCountdownTimer));
  if (boss) {
    drawBossHealthBar(ctx, boss);
    drawBossFightTimer(ctx, bossFightTimeRemaining, bossFightFailed);
  }
  if (bossResultState !== "none") drawBossResult(ctx, bossResultInfo);
  const totalAttack = Math.round(BALANCE.playerAttack * getEnhanceDamageMultiplier(weaponLevel) * getWeaponExpAttackMultiplier(weaponExpLevel));
  drawEnhanceInfo(ctx, weaponLevel, enhanceResultText, enhanceResultTimer, gold, totalAttack);
  drawWeaponExpBar(ctx, weaponExpLevel, getWeaponExpProgress(weaponExp, weaponExpLevel));
  drawPlayerHealthBar(ctx, player.hp, player.maxHp, gameTime);
  drawDashCooldown(ctx, player.dashCooldownTimer, BALANCE.dashCooldown);
}

function loop(now) {
  const dt = (now - lastTime) / 1000;
  lastTime = now;
  update(dt);
  render();
  requestAnimationFrame(loop);
}

requestAnimationFrame(loop);
