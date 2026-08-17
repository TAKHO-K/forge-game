// 게임 초기화 및 메인 루프 진입점
const canvas = document.getElementById("game");
const ctx = canvas.getContext("2d");

function resizeCanvas() {
  canvas.width = window.innerWidth;
  canvas.height = window.innerHeight;
}
resizeCanvas();
window.addEventListener("resize", resizeCanvas);

const player = {
  x: BALANCE.huntSpawnX, y: BALANCE.huntSpawnY, radius: BALANCE.playerRadius, speed: BALANCE.playerSpeed, angle: 0,
  hp: BALANCE.playerMaxHp, maxHp: BALANCE.playerMaxHp, defense: BALANCE.playerDefense,
  iframeTimer: 0, noHitTimer: 0, regenTimer: 0,
  dashTimer: 0, dashCooldownTimer: 0, dashDirX: 1, dashDirY: 0
};

let gameTime = 0;
let lastMoveDirX = 1;
let lastMoveDirY = 0;

// 직업 선택 (PRD 4장) - 게임 시작 시 classSelect 화면에서 1택, 선택 전까지 update/render 전체 정지
let selectedClass = null;
let dealModeTimer = 0; // 힐러 딜링모드(E) 남은 시간 - 온/오프 상태만 (공격력 배율 없음)
let qCooldownTimer = 0; // Q 스킬(PRD 4.3) 쿨다운 - 저장하지 않음(전투 중 순간 상태, dashCooldownTimer와 동일 취급)
let meleeSwingTimer = 0; // 대검·쌍검 스윙 이펙트 표시 타이머
let meleeSwingAngle = 0;
let meleeSwingSide = 0; // 0=중앙, 1=오른쪽, -1=왼쪽 (쌍검 좌우 번갈아 공격 렌더용)
let meleeSwingIsCombo = false; // 방금 스윙이 3타 강타였는지 - 렌더에서 이펙트 확대

// 3타 강타 (모든 직업 공통) - comboResetWindow 안에 새 공격이 없으면 카운터 초기화
let comboCount = 0;
let comboResetTimer = 0;

const classSelectPanel = document.getElementById("classSelect");
const classSelectButtons = document.getElementById("classSelectButtons");
CLASS_ORDER.forEach((id) => {
  const cls = CLASSES[id];
  const btn = document.createElement("button");
  btn.className = "classBtn";
  btn.innerHTML = `<strong>${cls.name}</strong><span>공격 ${cls.atk}x · 속도 ${cls.atkSpeed}x · 방어 ${cls.def}x</span>`;
  btn.addEventListener("click", () => {
    selectedClass = cls;
    classSelectPanel.classList.add("hidden");
  });
  classSelectButtons.appendChild(btn);
});

function clamp(v, min, max) {
  return Math.min(max, Math.max(min, v));
}

const camera = { x: 0, y: 0 };

// 대장간(안전지대)은 맵 위쪽 forgeHeight 만큼. 그 아래는 전부 사냥터
const FORGE_BOTTOM = BALANCE.wallThickness + BALANCE.forgeHeight;
let wasInForge = false;
let inForge = false;
let bossTimeRemaining = BALANCE.bossTimerDuration;
let forgeNoticeShown = false;
let forgeNoticeTimer = 0;
const FORGE_NOTICE_TEXT = "싱글 모드에서는 대장간 진입 시 타이머가 멈춥니다";

// 장비창이 게임을 멈추지 않으므로(멀티 대비), 대장간 진입 시마다 정리 타이밍을 안내
let invenNoticeTimer = 0;
const INVENTORY_NOTICE_TEXT = "I 키로 장비를 정리하세요";

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
let guaranteedTickets = []; // 확정 강화권 - 각 원소는 상승폭 N, 보스 클리어로만 획득 (9.6)
const probabilityTicketCounts = { small: 0, medium: 0, large: 0 }; // 확률 강화권 보유 개수 - 재료 몬스터 드랍
let ticketBoostSelection = null; // 강화 시도에 적용할 확률 강화권 크기 - "small"|"medium"|"large"|null, 상급 강화·서로 간 중복 불가
let ticketNoticeText = "";
let ticketNoticeTimer = 0;

// 바닥 아이템을 주웠는데 가방이 꽉 찬 경우 - 사냥 중(장비창 닫힘)에도 보이도록 토스트로 안내 (ticketNoticeTimer와 같은 구조)
let bagFullNoticeTimer = 0;
const BAG_FULL_NOTICE_TEXT = "가방이 가득 찼습니다";

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
  if (invenOpen) return;
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

// 힐러 딜링모드(E) - 최대체력 dealModeHpCost칸 소모, 체력 2칸 이상일 때만 (재)발동 가능 (PRD 4.1-1)
function tryActivateDealMode() {
  if (!selectedClass || selectedClass.id !== "healer" || invenOpen) return;
  if (player.hp < 2) return;
  player.hp -= selectedClass.dealModeHpCost;
  dealModeTimer = selectedClass.dealModeDuration;
}

// Q 스킬 캐스팅 (PRD 4.3) - 클래스별 전용 함수 없이 data/skills.js의 effects 조각을
// 타입별로 해석한다. 새 조각 타입을 붙일 때는 이 switch에 case만 추가하면 된다.
function tryCastSkill() {
  if (!selectedClass || invenOpen) return;
  const skill = SKILLS[selectedClass.id] && SKILLS[selectedClass.id].Q;
  if (!skill || qCooldownTimer > 0) return;
  for (const effect of skill.effects) {
    switch (effect.type) {
      case "heal": {
        const { amount } = computeHealAmount(effect, selectedClass.healPower, selectedClass.critRate);
        player.hp = Math.min(player.maxHp, player.hp + amount);
        break;
      }
    }
  }
  qCooldownTimer = skill.cooldown;
}

const keys = {};
window.addEventListener("keydown", (e) => {
  keys[e.key.toLowerCase()] = true;
  if (e.code === "Space") {
    e.preventDefault();
    tryDash();
  }
  if (e.key.toLowerCase() === "i") {
    invenOpen = !invenOpen;
    if (!invenOpen) {
      pendingEquip = null;
      pendingSell = null;
      bulkSellConfirm = null;
      bulkSellDropdownOpen = false;
      inventoryHoverSlot = null;
    }
  }
  if (e.key.toLowerCase() === "e") {
    tryActivateDealMode();
  }
  if (e.key.toLowerCase() === "q") {
    tryCastSkill();
  }
  if (e.key === "Escape") {
    if (invenOpen) {
      invenOpen = false;
      pendingEquip = null;
      pendingSell = null;
      bulkSellConfirm = null;
      bulkSellDropdownOpen = false;
      inventoryHoverSlot = null;
    } else {
      setSettingsOpen(!settingsOpen);
    }
  }
});
window.addEventListener("keyup", (e) => { keys[e.key.toLowerCase()] = false; });

const mouse = { x: player.x, y: player.y };
canvas.addEventListener("mousemove", (e) => {
  const rect = canvas.getBoundingClientRect();
  mouse.x = e.clientX - rect.left;
  mouse.y = e.clientY - rect.top;
  if (dragState && !dragState.dragging) {
    const dist = Math.hypot(mouse.x - dragState.startX, mouse.y - dragState.startY);
    if (dist > DRAG_START_THRESHOLD) dragState.dragging = true;
  }
});

const projectiles = [];
function fireProjectile(isComboHit) {
  projectiles.push({
    x: player.x,
    y: player.y,
    angle: player.angle,
    radius: BALANCE.projectileRadius,
    traveled: 0,
    isComboHit
  });
}

// 최종 공격력 - 강화/무기경험치/장비/직업배율을 한 곳에 모음, level 생략 시 현재 강화 단계 기준 (강화 버튼의 "다음 단계" 미리보기용으로 level 지정 가능)
function getPlayerAttack(level) {
  const lvl = level === undefined ? weaponLevel : level;
  return BALANCE.playerAttack * selectedClass.atk *
    getEnhanceDamageMultiplier(lvl) * getWeaponExpAttackMultiplier(weaponExpLevel) * equipBonuses.attackMultiplier;
}

// 몬스터·보스 피격 처리 - 투사체 명중과 근접 스윙 명중이 공유. isComboHit이면 comboHitMultiplier 적용 (3타 강타)
function applyDamageToMonster(monster, isComboHit) {
  const attack = getPlayerAttack() * (isComboHit ? BALANCE.comboHitMultiplier : 1);
  const { damage, isCrit } = calcDamage(attack, monster.defense, selectedClass.critRate, selectedClass.critDmg);
  monster.hp -= damage;
  spawnDamageNumber(monster.x, monster.y - monster.radius, damage, isCrit, isComboHit);
  if (monster.hp <= 0) {
    monster.alive = false;
    monster.respawnTimer = RESPAWN_TIME;
    gold += monster.goldDrop;
    spawnGroundItems(monster.x, monster.y, monster.tier, monster.dropChance);
    spawnExpTokens(monster.x, monster.y, monster.tier, monster.weaponExp);

    if (monster.rareType === "sparkle") {
      const roll = Math.random();
      const chances = BALANCE.sparkleGradeChances;
      const grade = roll < chances.primordial ? "primordial"
        : roll < chances.primordial + chances.ancient ? "ancient"
        : "relic";
      groundItems.push({ x: monster.x, y: monster.y, grade, part: rollItemPart(), age: 0 });
    } else if (monster.rareType === "material") {
      spawnGroundTicket(monster.x, monster.y);
    }
  }
}

function applyDamageToBoss(isComboHit) {
  const attack = getPlayerAttack() * (isComboHit ? BALANCE.comboHitMultiplier : 1);
  const { damage, isCrit } = calcDamage(attack, boss.defense, selectedClass.critRate, selectedClass.critDmg);
  boss.hp -= damage;
  spawnDamageNumber(boss.x, boss.y - boss.radius, damage, isCrit, isComboHit);
  if (boss.hp <= 0) {
    boss.hp = 0;
    boss.alive = false;
  }
}

// 두 각도 차이를 -PI~PI로 정규화 (근접 부채꼴 판정용)
function angleDiff(a, b) {
  return Math.atan2(Math.sin(a - b), Math.cos(a - b));
}

let meleeAlternateSign = 1; // 쌍검 좌우 번갈아 공격 - 다음 스윙이 오른쪽(+1)인지 왼쪽(-1)인지

// 대검·쌍검 근접 공격 (PRD 4.1) - 투사체 없이 전방 부채꼴 범위 내 대상을 즉시 판정
// alternateSides 직업(쌍검)은 판정 중심을 좌우로 번갈아 치우쳐 공격 - meleeSwingSide로 렌더에 전달(0=중앙, 1=오른쪽, -1=왼쪽)
function performMeleeAttack(isComboHit) {
  let swingAngle = player.angle;
  let swingSide = 0;
  if (selectedClass.alternateSides) {
    swingSide = meleeAlternateSign;
    swingAngle += meleeAlternateSign * (selectedClass.alternateOffsetDegrees * Math.PI / 180);
    meleeAlternateSign *= -1;
  }

  meleeSwingTimer = BALANCE.meleeSwingVisualDuration;
  meleeSwingAngle = swingAngle;
  meleeSwingSide = swingSide;
  meleeSwingIsCombo = !!isComboHit;

  const range = selectedClass.meleeRange;
  const halfArc = (selectedClass.meleeArc * Math.PI / 180) / 2;

  if (currentMap === "hunt") {
    for (const monster of monsters) {
      if (!monster.alive) continue;
      const dist = Math.hypot(monster.x - player.x, monster.y - player.y);
      if (dist > range + monster.radius) continue;
      if (Math.abs(angleDiff(Math.atan2(monster.y - player.y, monster.x - player.x), swingAngle)) > halfArc) continue;
      applyDamageToMonster(monster, isComboHit);
    }
  }

  if (boss && boss.alive && !bossFightFailed) {
    const dist = Math.hypot(boss.x - player.x, boss.y - player.y);
    if (dist <= range + boss.radius &&
      Math.abs(angleDiff(Math.atan2(boss.y - player.y, boss.x - player.x), swingAngle)) <= halfArc) {
      applyDamageToBoss(isComboHit);
    }
  }
}

// 3타 강타 (모든 직업 공통) - comboResetWindow 안에 이어친 공격 수를 세어 comboHitEvery번째마다 강타 (PRD 4.4 근처 요구사항)
function performAttack() {
  comboCount++;
  comboResetTimer = BALANCE.comboResetWindow;
  const isComboHit = comboCount % BALANCE.comboHitEvery === 0;

  if (selectedClass.attackType === "melee") {
    performMeleeAttack(isComboHit);
  } else {
    fireProjectile(isComboHit);
  }
}

let autoMode = false;
let attackTimer = 0;

// 희귀 몬스터 판정 (PRD 8.0-5) - 스폰 시점마다 판정, 반짝이 0.5% > 재료 1.5% > 일반
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
    dropChance: data.dropChance,
    rareType,
    alive: true,
    respawnTimer: 0,
    state: "idle"
  };
}

const RESPAWN_TIME = BALANCE.respawnTime;

// 던전(PRD 8.0-2) 안에서 등급(tier)별 구역으로 나눠 배치 - 왼쪽(낮은 등급)에서 오른쪽(높은 등급)으로 갈수록 강해짐
const ZONE_Y_MARGIN = BALANCE.zoneYMargin;
const zoneLeft = BALANCE.wallThickness;
const zoneRight = BALANCE.mapWidth - BALANCE.wallThickness;
const zoneTop = FORGE_BOTTOM + ZONE_Y_MARGIN;
const zoneBottom = BALANCE.mapHeight - BALANCE.wallThickness - ZONE_Y_MARGIN;

const monstersByTier = {};
for (const type of MONSTER_ORDER) {
  const tier = MONSTERS[type].tier;
  if (!monstersByTier[tier]) monstersByTier[tier] = [];
  monstersByTier[tier].push(type);
}

function shuffleArray(arr) {
  const a = arr.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

// 던전 전환 시 몬스터 전부 새로 스폰 - 등급당 여러 종이면 순서를 섞어 랜덤 배치
const monsters = [];
function buildMonstersForStage(stageIndex) {
  monsters.length = 0;
  const tiers = STAGES[stageIndex].tiers;
  const zoneWidth = (zoneRight - zoneLeft) / tiers.length;
  tiers.forEach((tier, zoneIdx) => {
    const types = shuffleArray(monstersByTier[tier] || []);
    const zoneCenterX = zoneLeft + zoneWidth * zoneIdx + zoneWidth / 2;
    const ySpacing = (zoneBottom - zoneTop) / (types.length + 1);
    types.forEach((type, i) => {
      const y = zoneTop + ySpacing * (i + 1);
      monsters.push(spawnMonster(zoneCenterX, y, type));
    });
  });
}

let currentStageIndex = 0;
buildMonstersForStage(currentStageIndex);

const damageNumbers = [];
function spawnDamageNumber(x, y, value, isCrit, isComboHit) {
  damageNumbers.push({ x, y, value, isCrit, isComboHit: !!isComboHit, age: 0 });
}

// 바닥 장비 드랍 (PRD 7.1) - 등급/부위는 rollDroppedItems가 판정, 등급만 바닥에 노출
const groundItems = [];
function spawnGroundItems(x, y, tier, dropChance) {
  const drops = rollDroppedItems(tier, dropChance, BALANCE.dropSlot2Multiplier);
  drops.forEach((drop, i) => {
    const angle = Math.random() * Math.PI * 2;
    const offset = i === 0 ? 0 : BALANCE.itemDropOffset;
    groundItems.push({
      x: x + Math.cos(angle) * offset,
      y: y + Math.sin(angle) * offset,
      grade: drop.grade,
      part: drop.part,
      age: 0
    });
  });
}

// 경험치 토큰 (PRD 7.1-1) - 흡수 반경 안에서 플레이어 쪽으로 끌려가다 닿으면 획득
const expTokens = [];
function spawnExpTokens(x, y, tier, baseValue) {
  const count = rollExpTokenCount(tier);
  for (let i = 0; i < count; i++) {
    const size = rollExpTokenSize();
    const angle = Math.random() * Math.PI * 2;
    const offset = Math.random() * BALANCE.expTokenScatterRadius;
    expTokens.push({
      x: x + Math.cos(angle) * offset,
      y: y + Math.sin(angle) * offset,
      size,
      value: Math.round(baseValue * EXP_TOKEN_TIERS[size].multiplier),
      age: 0
    });
  }
}

// 재료 몬스터 확률 강화권 (8.0-5) - 바닥에 드랍, 주우면 획득. 30초 후 소멸. 크기는 드랍 시 랜덤 결정
const groundTickets = [];
function spawnGroundTicket(x, y) {
  const chances = BALANCE.materialTicketSizeChances;
  const roll = Math.random();
  const size = roll < chances.small ? "small"
    : roll < chances.small + chances.medium ? "medium"
    : "large";
  groundTickets.push({ x, y, size, age: 0 });
}

let weaponLevel = 0;
let enhanceResultText = "";
let enhanceResultTimer = 0;
let gold = 0;

// 무기 경험치 (PRD 4.2) - 강화(weaponLevel)와 별개 축
let weaponExp = 0;
let weaponExpLevel = getWeaponLevelFromExp(weaponExp);

// 장비창 (PRD 7.3) - 착용 슬롯 3개 + 가방 20칸(빈 칸은 null 고정 슬롯)
let invenOpen = false;
const equipment = { armor: null, gloves: null, shoes: null };
const bag = new Array(BALANCE.inventoryBagSize).fill(null);
let equipBonuses = { defenseBonus: 0, attackMultiplier: 1, speedMultiplier: 1 };

// 가방 등급 필터 - 기본 전부 체크, 장비창을 닫아도 유지
const gradeFilter = {};
for (const grade of ITEM_GRADE_ORDER) gradeFilter[grade] = true;

// 하위 등급 착용 확인창 대기 상태 - { bagIndex } 또는 null
let pendingEquip = null;
// 상위 등급 판매 확인창 대기 상태 - { bagIndex, message } 또는 null
let pendingSell = null;
// 일괄 판매 (요청사항 4) - 대상 등급 상한, 드롭다운 열림 여부, 확인창 대기 상태
let bulkSellGrade = "normal";
let bulkSellDropdownOpen = false;
let bulkSellConfirm = null; // { indices, message } 또는 null
let invenMessage = "";
let invenMessageTimer = 0;

// 장비창 호버 대상 - { type, part, index } 또는 null. 슬롯 직접 호버 우선, 아니면 직전 슬롯의
// 툴팁(판매 버튼 포함) 위일 때만 유지 - render()에서 매 프레임 갱신되므로 클릭 시점에도 항상 최신
let inventoryHoverSlot = null;

// 강화 패널(#ui)과 장비창은 둘 다 화면 중앙 기준이라 대장간에서 같이 열리면 겹친다.
// 둘 다 열려 있을 때만 각자 절반씩 반대 방향으로 밀어 좌(강화)·우(장비창)로 나눈다.
const PANEL_SPLIT_GAP = 24;
const INVENTORY_PANEL_WIDTH = getInventoryLayout(ctx).panelW;
let enhancePanelWidth = 0; // 대장간에서 패널이 처음 보일 때 실측 후 캐시 (CSS width가 유일한 출처)

function isPanelSplit() {
  return invenOpen && inForge;
}

function getInventoryOffsetX() {
  return isPanelSplit() ? (enhancePanelWidth + PANEL_SPLIT_GAP) / 2 : 0;
}

// 강화 패널은 CSS transform으로 중앙 정렬돼 있으므로 같은 transform에 좌측 이동을 얹는다
function updatePanelSplit() {
  if (!enhancePanelWidth && inForge) enhancePanelWidth = uiPanel.offsetWidth;
  const shift = isPanelSplit() ? (INVENTORY_PANEL_WIDTH + PANEL_SPLIT_GAP) / 2 : 0;
  uiPanel.style.transform = `translate(calc(-50% - ${shift}px), -50%)`;
}

// 장비창 레이아웃 단일 진입점 - 클릭 판정과 그리기가 같은 오프셋을 쓰게 한다
function invenLayout() {
  return getInventoryLayout(ctx, getInventoryOffsetX());
}

function updateInventoryHoverSlot() {
  const layout = invenLayout();
  const direct = findHoveredInventorySlot(layout, mouse.x, mouse.y);
  if (direct) {
    const item = direct.type === "equip" ? equipment[direct.part] : bag[direct.index];
    const visible = direct.type === "equip" ? !!item : !!(item && gradeFilter[item.grade]);
    inventoryHoverSlot = visible ? direct : null;
    return;
  }
  const resolved = resolveHoveredTooltip(ctx, layout, equipment, bag, inventoryHoverSlot);
  if (resolved && pointInRect(mouse.x, mouse.y, resolved.tooltip)) return; // 판매 버튼 쪽으로 이동 중 - 유지
  inventoryHoverSlot = null;
}

// 가방 아이템 드래그 앤 드롭 - 같은 부위 슬롯에 놓아야 착용, 그 외엔 원위치 복귀 (상태 미변경으로 자연히 복귀됨)
let dragState = null; // { bagIndex, startX, startY, dragging }
const DRAG_START_THRESHOLD = 6;

function equipFromBag(bagIndex) {
  const item = bag[bagIndex];
  if (!item) return;
  const previous = equipment[item.part];
  equipment[item.part] = item;
  bag[bagIndex] = previous;
}

// 클릭/더블클릭/드래그드롭이 공통으로 쓰는 착용 판정 - 하위 등급이면 확인창 대기
function tryEquipFromBag(bagIndex) {
  const item = bag[bagIndex];
  if (!item || !gradeFilter[item.grade]) return;
  const current = equipment[item.part];
  if (current && ITEM_GRADE_ORDER.indexOf(item.grade) < ITEM_GRADE_ORDER.indexOf(current.grade)) {
    pendingEquip = { bagIndex };
    return;
  }
  equipFromBag(bagIndex);
}

function handlePendingEquipClick(mx, my) {
  const layout = getConfirmDialogLayout(ctx, getInventoryOffsetX());
  if (pointInRect(mx, my, layout.confirmBtn)) {
    equipFromBag(pendingEquip.bagIndex);
    pendingEquip = null;
  } else if (pointInRect(mx, my, layout.cancelBtn)) {
    pendingEquip = null;
  }
}

// 상위 등급(또는 고대·태초) 판매 확인 필요 여부 (요청사항 3)
function shouldConfirmSell(item) {
  if (item.grade === "ancient" || item.grade === "primordial") return true;
  const equipped = equipment[item.part];
  if (!equipped) return false;
  return ITEM_GRADE_ORDER.indexOf(item.grade) > ITEM_GRADE_ORDER.indexOf(equipped.grade);
}

function sellBagItem(bagIndex) {
  const item = bag[bagIndex];
  if (!item) return;
  gold += getItemSellValue(item);
  bag[bagIndex] = null;
}

// 우클릭·판매 버튼 공용 판매 진입점 - 상위 등급이면 확인창 대기
function trySellFromBag(bagIndex) {
  const item = bag[bagIndex];
  if (!item || !gradeFilter[item.grade]) return;
  if (shouldConfirmSell(item)) {
    pendingSell = { bagIndex, message: "착용 중인 장비보다 높은 등급입니다. 정말 판매할까요?" };
    return;
  }
  sellBagItem(bagIndex);
}

function handlePendingSellClick(mx, my) {
  const layout = getConfirmDialogLayout(ctx, getInventoryOffsetX());
  if (pointInRect(mx, my, layout.confirmBtn)) {
    sellBagItem(pendingSell.bagIndex);
    pendingSell = null;
  } else if (pointInRect(mx, my, layout.cancelBtn)) {
    pendingSell = null;
  }
}

// 일괄 판매 대상 - 가방에 있고(착용 중인 장비는 별도 배열이라 자연히 제외), 고대·태초가 아니며, 선택 등급 이하
function getBulkSellCandidates(maxGrade) {
  const maxIndex = ITEM_GRADE_ORDER.indexOf(maxGrade);
  const indices = [];
  bag.forEach((item, index) => {
    if (!item) return;
    if (item.grade === "ancient" || item.grade === "primordial") return;
    if (ITEM_GRADE_ORDER.indexOf(item.grade) <= maxIndex) indices.push(index);
  });
  return indices;
}

function buildBulkSellGradeLabel(maxGrade) {
  const maxIndex = ITEM_GRADE_ORDER.indexOf(maxGrade);
  return ITEM_GRADE_ORDER.slice(0, maxIndex + 1).map((g) => ITEM_GRADES[g].nameKo).join("·");
}

function tryBulkSell() {
  const indices = getBulkSellCandidates(bulkSellGrade);
  if (indices.length === 0) {
    invenMessage = "판매할 장비가 없습니다";
    invenMessageTimer = BALANCE.inventoryMessageDisplayTime;
    return;
  }
  const total = indices.reduce((sum, i) => sum + getItemSellValue(bag[i]), 0);
  const gradeLabel = buildBulkSellGradeLabel(bulkSellGrade);
  bulkSellConfirm = {
    indices,
    message: `${gradeLabel} 장비 ${indices.length}개를 판매합니다. 총 ${total.toLocaleString()}골드. 진행할까요?`
  };
}

function handleBulkSellConfirmClick(mx, my) {
  const layout = getConfirmDialogLayout(ctx, getInventoryOffsetX());
  if (pointInRect(mx, my, layout.confirmBtn)) {
    for (const index of bulkSellConfirm.indices) sellBagItem(index);
    bulkSellConfirm = null;
  } else if (pointInRect(mx, my, layout.cancelBtn)) {
    bulkSellConfirm = null;
  }
}

function handleInventoryClick(button, mx, my) {
  if (pendingEquip) {
    handlePendingEquipClick(mx, my);
    return;
  }
  if (pendingSell) {
    handlePendingSellClick(mx, my);
    return;
  }
  if (bulkSellConfirm) {
    handleBulkSellConfirmClick(mx, my);
    return;
  }

  const layout = invenLayout();

  // 드롭다운이 열려있으면 이 클릭은 옵션 선택 또는 닫기 전용 - 아래 다른 동작과 안 겹치게 여기서 종료
  if (bulkSellDropdownOpen) {
    if (button === 0) {
      for (const opt of layout.bulkSell.options) {
        if (pointInRect(mx, my, opt)) {
          bulkSellGrade = opt.grade;
          bulkSellDropdownOpen = false;
          return;
        }
      }
    }
    bulkSellDropdownOpen = false;
    return;
  }

  if (button === 0 && pointInRect(mx, my, layout.bulkSell.dropdown)) {
    bulkSellDropdownOpen = true;
    return;
  }
  if (button === 0 && pointInRect(mx, my, layout.bulkSell.button)) {
    tryBulkSell();
    return;
  }

  for (const cb of layout.filterCheckboxes) {
    if (pointInRect(mx, my, cb)) {
      if (button === 0) gradeFilter[cb.grade] = !gradeFilter[cb.grade];
      return;
    }
  }

  if (button === 0) {
    const resolved = resolveHoveredTooltip(ctx, layout, equipment, bag, inventoryHoverSlot);
    if (resolved && pointInRect(mx, my, resolved.tooltip.sellBtn)) {
      if (inventoryHoverSlot.type === "equip") {
        invenMessage = "착용 중인 장비는 판매할 수 없습니다";
        invenMessageTimer = BALANCE.inventoryMessageDisplayTime;
      } else {
        trySellFromBag(inventoryHoverSlot.index);
      }
      return;
    }
  }

  const hovered = findHoveredInventorySlot(layout, mx, my);
  if (!hovered) return;

  if (button === 0) {
    if (hovered.type === "bag") {
      tryEquipFromBag(hovered.index);
    } else if (hovered.type === "equip") {
      const item = equipment[hovered.part];
      if (!item) return;
      const emptyIndex = bag.indexOf(null);
      if (emptyIndex === -1) {
        invenMessage = "가방이 가득 찼습니다";
        invenMessageTimer = BALANCE.inventoryMessageDisplayTime;
        return;
      }
      equipment[hovered.part] = null;
      bag[emptyIndex] = item;
    }
  } else if (button === 2) {
    if (hovered.type === "bag") {
      trySellFromBag(hovered.index);
    } else if (hovered.type === "equip") {
      if (!equipment[hovered.part]) return;
      invenMessage = "착용 중인 장비는 판매할 수 없습니다";
      invenMessageTimer = BALANCE.inventoryMessageDisplayTime;
    }
  }
}

const ENHANCE_RESULT_LABEL = {
  success: (level) => `성공 +${level}`,
  maintain: () => "형상유지",
  down1: () => "-1강",
  down2: () => "-2강",
  reset: () => "1강으로 리셋",
  max: () => "최대 강화 단계"
};

const uiPanel = document.getElementById("ui");
const enhanceTitle = document.getElementById("enhanceTitle");
const activeTicketBadge = document.getElementById("activeTicketBadge");
const autoEnhanceCheck = document.getElementById("autoEnhanceCheck");
const enhanceBtn = document.getElementById("enhanceBtn");
const enhanceSuccessInfo = document.getElementById("enhanceSuccessInfo");
const enhanceProbInfo = document.getElementById("enhanceProbInfo");
const enhanceHighBtn = document.getElementById("enhanceHighBtn");
const enhanceHighSuccessInfo = document.getElementById("enhanceHighSuccessInfo");
const enhanceHighProbInfo = document.getElementById("enhanceHighProbInfo");
const useTicketBtn = document.getElementById("useTicketBtn");
const settingsPanel = document.getElementById("settingsPanel");
const settingsCloseBtn = document.getElementById("settingsCloseBtn");
const saveSummaryEl = document.getElementById("saveSummary");
const deleteSaveBtn = document.getElementById("deleteSaveBtn");

// 자동강화 기본값 끔 (요청사항 4) - 체크 시에만 대장간 진입 때 +10까지 자동 강화
let autoEnhanceEnabled = false;
autoEnhanceCheck.addEventListener("change", () => { autoEnhanceEnabled = autoEnhanceCheck.checked; });

// ESC 우선순위 (요청사항 5) - 장비창 열려있으면 장비창만 닫고, 아니면 설정창 토글
let settingsOpen = false;
function updateSaveSummary() {
  saveSummaryEl.textContent = selectedClass
    ? `직업 ${selectedClass.name} · 강화 +${weaponLevel} · 골드 ${gold.toLocaleString()} · 무기 레벨 ${weaponExpLevel}`
    : "저장된 진행 없음";
}
function setSettingsOpen(open) {
  settingsOpen = open;
  settingsPanel.classList.toggle("hidden", !open);
  if (open) updateSaveSummary();
}
settingsCloseBtn.addEventListener("click", () => setSettingsOpen(false));

// 저장 삭제 - JS confirm()은 claude-in-chrome 등 브라우저 자동화를 블록하므로 두 번 클릭 확인으로 대체
let deleteArmTimeout = null;
deleteSaveBtn.addEventListener("click", () => {
  if (deleteArmTimeout) {
    clearTimeout(deleteArmTimeout);
    deleteArmTimeout = null;
    clearSave();
    // reload 도중에도 pagehide 핸들러가 살아있는 selectedClass를 보고 재저장해버리므로
    // 먼저 비워서 doAutosave의 가드(!selectedClass)에 걸리게 한다
    selectedClass = null;
    location.reload();
    return;
  }
  deleteSaveBtn.textContent = "정말 삭제? 다시 누르면 실행";
  deleteArmTimeout = setTimeout(() => {
    deleteSaveBtn.textContent = "저장 삭제 후 처음부터";
    deleteArmTimeout = null;
  }, 4000);
});
const bossResultButtons = document.getElementById("bossResultButtons");
const bossNextStageBtn = document.getElementById("bossNextStageBtn");
const bossExitBtn = document.getElementById("bossExitBtn");

// 던전 선택 UI (PRD 8.0-2) - STAGES 데이터로부터 버튼 생성, 대장간에서만 클릭 유효
const stageSelectPanel = document.getElementById("stageSelect");
const stageButtons = STAGES.map((stage, i) => {
  const btn = document.createElement("button");
  btn.textContent = stage.name;
  btn.addEventListener("click", () => {
    if (!inForge) return;
    if (i === currentStageIndex) return;
    currentStageIndex = i;
    buildMonstersForStage(currentStageIndex);
  });
  stageSelectPanel.appendChild(btn);
  return btn;
});

function updateStageButtons() {
  stageButtons.forEach((btn, i) => {
    btn.classList.toggle("active", i === currentStageIndex);
    btn.disabled = !inForge;
  });
}

// 확률 강화권 3종 (9.6/8.0-5) - 체크한 크기를 일반 강화에 적용, 상급 강화·서로 간 중복 불가
const ticketCheckboxes = {
  small: document.getElementById("ticketSmallCheck"),
  medium: document.getElementById("ticketMediumCheck"),
  large: document.getElementById("ticketLargeCheck")
};
const ticketLabels = {
  small: document.getElementById("ticketSmallLabel"),
  medium: document.getElementById("ticketMediumLabel"),
  large: document.getElementById("ticketLargeLabel")
};
for (const size of Object.keys(ticketCheckboxes)) {
  ticketCheckboxes[size].addEventListener("change", () => {
    ticketBoostSelection = ticketCheckboxes[size].checked ? size : null;
  });
}

function updateTicketBoostUI() {
  for (const size of Object.keys(ticketCheckboxes)) {
    const count = probabilityTicketCounts[size];
    const checkbox = ticketCheckboxes[size];
    checkbox.checked = ticketBoostSelection === size;
    checkbox.disabled = ticketBoostSelection ? ticketBoostSelection !== size : count <= 0;
    ticketLabels[size].textContent = `${ENHANCE_TICKET_SIZES[size].label} 확률권 (${count}개)`;
  }
  if (ticketBoostSelection) enhanceHighBtn.disabled = true;
}

function attemptEnhance(isHigh) {
  const cost = getEnhanceCost(weaponLevel, isHigh);
  if (gold < cost) return;
  const boostType = isHigh ? "high" : (ticketBoostSelection || "none");
  gold -= cost;
  const result = tryEnhance(weaponLevel, boostType);
  weaponLevel = result.level;
  enhanceResultText = ENHANCE_RESULT_LABEL[result.result](weaponLevel);
  enhanceResultTimer = BALANCE.enhanceResultDisplayTime;
  if (!isHigh && ticketBoostSelection) {
    probabilityTicketCounts[ticketBoostSelection]--;
    if (probabilityTicketCounts[ticketBoostSelection] <= 0) ticketBoostSelection = null;
  }
  doAutosave(); // 강화는 유일한 핵심 행위라 유실·되돌리기 둘 다 허용 못 함 - 주기 대기 없이 즉시저장
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
  doAutosave();
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
  player.x = BALANCE.huntSpawnX;
  player.y = BALANCE.huntSpawnY;
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
  let didEnhance = false;
  while (weaponLevel < BALANCE.forgeAutoMaxLevel) {
    const cost = getEnhanceCost(weaponLevel, false);
    if (gold < cost) break;
    gold -= cost;
    const result = tryEnhance(weaponLevel, "none");
    weaponLevel = result.level;
    enhanceResultText = ENHANCE_RESULT_LABEL[result.result](weaponLevel);
    enhanceResultTimer = BALANCE.enhanceResultDisplayTime;
    didEnhance = true;
  }
  if (didEnhance) doAutosave();
}

// 확률을 % 문자열로 (6.2 확률표는 소수 비율) - 반올림이라 4개 합이 100%가 아닐 수 있음
function formatPercent(p) {
  return Math.round(p * 100);
}

function formatFailureLine(prob) {
  return `실패 시: 유지 ${formatPercent(prob.maintain)}% / -1강 ${formatPercent(prob.down1)}% / -2강 ${formatPercent(prob.down2)}% / 초기화 ${formatPercent(prob.reset)}%`;
}

const TICKET_BOOST_LABEL = { small: "소 확률권", medium: "중 확률권", large: "대 확률권" };

// 확률권 적용 전/후 성공률 표시 (요청사항 3) - boostedProb가 있으면 원래 값은 회색 취소선, 새 값은 초록 굵게
function successLineHTML(baseProb, boostedProb) {
  if (!boostedProb) return `성공 ${formatPercent(baseProb.success)}%`;
  return `성공 <s>${formatPercent(baseProb.success)}%</s> → <span class="boosted">${formatPercent(boostedProb.success)}%</span>`;
}

function updateEnhanceButtons() {
  const currentAttack = Math.round(getPlayerAttack(weaponLevel));

  if (weaponLevel >= ENHANCE_MAX_LEVEL) {
    enhanceTitle.textContent = `현재 +${weaponLevel} · 공격력 ${currentAttack} (최대)`;
    activeTicketBadge.classList.remove("show");
    enhanceBtn.textContent = "일반 강화 (최대)";
    enhanceHighBtn.textContent = "상급 강화 (최대)";
    enhanceBtn.disabled = true;
    enhanceHighBtn.disabled = true;
    enhanceSuccessInfo.textContent = "";
    enhanceHighSuccessInfo.textContent = "";
    enhanceProbInfo.textContent = "";
    enhanceHighProbInfo.textContent = "";
    return;
  }
  const normalCost = getEnhanceCost(weaponLevel, false);
  const highCost = getEnhanceCost(weaponLevel, true);
  const nextAttack = Math.round(getPlayerAttack(weaponLevel + 1));

  // 체크된 확률 강화권이 있으면 일반 강화 확률에 즉시 반영 (ticketBoostSelection은 체크박스 change에서 바로 갱신됨)
  const baseProb = resolveProbability(weaponLevel, "none");
  const normalProb = resolveProbability(weaponLevel, ticketBoostSelection || "none");
  const highProb = resolveProbability(weaponLevel, "high");

  enhanceTitle.textContent = `현재 +${weaponLevel} · 공격력 ${currentAttack}`;
  activeTicketBadge.classList.toggle("show", !!ticketBoostSelection);
  if (ticketBoostSelection) activeTicketBadge.textContent = `${TICKET_BOOST_LABEL[ticketBoostSelection]} 적용 중`;

  enhanceBtn.textContent = `일반 강화 (${normalCost}G) → 공격력 ${nextAttack}`;
  enhanceSuccessInfo.innerHTML = successLineHTML(baseProb, ticketBoostSelection ? normalProb : null);
  enhanceProbInfo.textContent = formatFailureLine(normalProb);
  enhanceBtn.disabled = gold < normalCost;

  enhanceHighBtn.textContent = `상급 강화 (${highCost}G) → 공격력 ${nextAttack}`;
  enhanceHighSuccessInfo.innerHTML = successLineHTML(highProb) +
    (highProb.success === baseProb.success ? ` <span class="noBenefit">이득 없음 - 일반 강화와 성공률 동일</span>` : "");
  enhanceHighProbInfo.textContent = formatFailureLine(highProb);
  enhanceHighBtn.disabled = gold < highCost;
}

canvas.addEventListener("contextmenu", (e) => e.preventDefault());

canvas.addEventListener("mousedown", (e) => {
  if (invenOpen) {
    if (e.button === 0 && !pendingEquip && !pendingSell && !bulkSellConfirm && !bulkSellDropdownOpen) {
      const layout = invenLayout();
      const hovered = findHoveredInventorySlot(layout, mouse.x, mouse.y);
      if (hovered && hovered.type === "bag") {
        const item = bag[hovered.index];
        if (item && gradeFilter[item.grade]) {
          dragState = { bagIndex: hovered.index, startX: mouse.x, startY: mouse.y, dragging: false };
          return;
        }
      }
    }
    handleInventoryClick(e.button, mouse.x, mouse.y);
    return;
  }
  if (e.button === 2) {
    tryDash();
    return;
  }
  if (e.button !== 0) return;
  if (autoMode) return;
  if (!selectedClass) return;
  performAttack();
});

// 드래그 종료 - 이동이 없었으면 클릭으로 처리, 드래그였으면 같은 부위 슬롯에서만 착용
window.addEventListener("mouseup", (e) => {
  if (!dragState) return;
  const { bagIndex, dragging } = dragState;
  dragState = null;
  if (e.button !== 0 || !invenOpen) return;
  const item = bag[bagIndex];
  if (!item) return;

  if (!dragging) {
    tryEquipFromBag(bagIndex);
    return;
  }
  const layout = invenLayout();
  const hovered = findHoveredInventorySlot(layout, mouse.x, mouse.y);
  if (hovered && hovered.type === "equip" && hovered.part === item.part) {
    tryEquipFromBag(bagIndex);
  }
  // 잘못된 슬롯에 드롭 - 가방 상태를 바꾸지 않아 자연히 원위치로 복귀
});

canvas.addEventListener("dblclick", (e) => {
  if (invenOpen) {
    if (e.button !== 0) return;
    const layout = invenLayout();
    const hovered = findHoveredInventorySlot(layout, mouse.x, mouse.y);
    if (hovered && hovered.type === "bag") tryEquipFromBag(hovered.index);
    return;
  }
  if (e.button !== 0) return;
  autoMode = !autoMode;
  attackTimer = 0;
});

// ===== 저장 로드/자동저장 (core/save.js) =====
// 매 프레임 저장 대신: 강화 등 핵심 행위 직후 즉시저장(위 doAutosave 호출 지점들) +
// 10초 주기 자동저장 + 탭 숨김/종료 시 저장. beforeunload는 모바일에서 호출이
// 보장되지 않아 쓰지 않는다 - visibilitychange(hidden)와 pagehide로 대체.
function collectSaveState() {
  return {
    selectedClass, gold, weaponLevel, weaponExp, equipment, bag,
    probabilityTicketCounts, guaranteedTickets, currentStageIndex,
    currentBossStageIndex, bossTimeRemaining, bossRetryCount, autoEnhanceEnabled
  };
}

function doAutosave() {
  if (!selectedClass) return; // 직업 선택 전에는 저장할 게 없음
  saveGame(collectSaveState());
}

setInterval(doAutosave, 10000);
document.addEventListener("visibilitychange", () => {
  if (document.visibilityState === "hidden") doAutosave();
});
window.addEventListener("pagehide", doAutosave);

const saveNoticeEl = document.getElementById("saveNotice");
function showSaveNotice(text) {
  saveNoticeEl.textContent = text;
  saveNoticeEl.classList.remove("hidden");
  setTimeout(() => saveNoticeEl.classList.add("hidden"), 4000);
}

// 저장 로드 - 있으면 이어서 시작(직업 선택 건너뜀), 없으면 새 게임(정상, 안내 없음),
// 깨졌으면 새 게임으로 떨어뜨리고 한 줄 안내
const savedData = loadGame();
if (savedData && !savedData.corrupted) {
  selectedClass = CLASSES[savedData.classId];
  gold = savedData.gold;
  weaponLevel = savedData.weaponLevel;
  weaponExp = savedData.weaponExp;
  weaponExpLevel = getWeaponLevelFromExp(weaponExp);
  equipment.armor = savedData.equipment.armor || null;
  equipment.gloves = savedData.equipment.gloves || null;
  equipment.shoes = savedData.equipment.shoes || null;
  // 가방 길이를 현재 BALANCE.inventoryBagSize에 맞춰 보정 - 초과분은 버리고 모자라면 null로 채움
  for (let i = 0; i < bag.length; i++) {
    bag[i] = savedData.bag[i] !== undefined ? savedData.bag[i] : null;
  }
  probabilityTicketCounts.small = savedData.probabilityTicketCounts.small || 0;
  probabilityTicketCounts.medium = savedData.probabilityTicketCounts.medium || 0;
  probabilityTicketCounts.large = savedData.probabilityTicketCounts.large || 0;
  guaranteedTickets = savedData.guaranteedTickets.slice();
  currentStageIndex = clamp(savedData.currentStageIndex, 0, STAGES.length - 1);
  buildMonstersForStage(currentStageIndex);
  autoEnhanceEnabled = !!savedData.autoEnhanceEnabled;
  autoEnhanceCheck.checked = autoEnhanceEnabled;

  // 보스 상태 - startNextBossRun으로 "이 단계 파밍을 방금 시작한 상태"로 우선 리셋한 뒤
  // (bossZoneTriggered=false 등도 여기서 정합됨), 진행도인 타이머·재도전 횟수만 그 위에 덮어쓴다.
  // 이 순서가 아니면 안 됨 - startNextBossRun이 나중에 실행되면 방금 복원한 값을 지워버린다.
  startNextBossRun(clamp(savedData.currentBossStageIndex, 0, BOSSES.length - 1));
  bossTimeRemaining = Math.max(0, savedData.bossTimeRemaining);
  bossRetryCount = Math.max(0, savedData.bossRetryCount);

  classSelectPanel.classList.add("hidden");
} else if (savedData && savedData.corrupted) {
  showSaveNotice("저장 데이터를 읽을 수 없어 새 게임으로 시작합니다");
}

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

  camera.x = mapW <= canvas.width ? (mapW - canvas.width) / 2 : clamp(player.x - canvas.width / 2, 0, mapW - canvas.width);
  camera.y = mapH <= canvas.height ? (mapH - canvas.height) / 2 : clamp(player.y - canvas.height / 2, 0, mapH - canvas.height);

  const worldMouseX = mouse.x + camera.x;
  const worldMouseY = mouse.y + camera.y;
  player.angle = Math.atan2(worldMouseY - player.y, worldMouseX - player.x);

  if (autoMode) {
    attackTimer += dt;
    const effectiveAttackInterval = BALANCE.attackInterval / (equipBonuses.speedMultiplier * selectedClass.atkSpeed);
    while (attackTimer >= effectiveAttackInterval) {
      attackTimer -= effectiveAttackInterval;
      performAttack();
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
          player.x = BALANCE.huntSpawnX;
          player.y = BALANCE.huntSpawnY;
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
  inForge = currentMap === "hunt" && player.y <= FORGE_BOTTOM;
  uiPanel.classList.toggle("hidden", !inForge);
  updatePanelSplit();
  if (inForge && !wasInForge) {
    if (autoEnhanceEnabled) autoEnhanceInForge();
    if (!forgeNoticeShown) {
      forgeNoticeShown = true;
      forgeNoticeTimer = BALANCE.forgeNoticeDuration;
    }
    invenNoticeTimer = BALANCE.forgeNoticeDuration;
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
  if (invenNoticeTimer > 0) {
    invenNoticeTimer -= dt;
    if (invenNoticeTimer < 0) invenNoticeTimer = 0;
  }
  if (ticketNoticeTimer > 0) {
    ticketNoticeTimer -= dt;
    if (ticketNoticeTimer < 0) ticketNoticeTimer = 0;
  }
  if (bagFullNoticeTimer > 0) {
    bagFullNoticeTimer -= dt;
    if (bagFullNoticeTimer < 0) bagFullNoticeTimer = 0;
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

  if (dealModeTimer > 0) {
    dealModeTimer -= dt;
    if (dealModeTimer < 0) dealModeTimer = 0;
  }
  if (qCooldownTimer > 0) {
    qCooldownTimer -= dt;
    if (qCooldownTimer < 0) qCooldownTimer = 0;
  }
  if (meleeSwingTimer > 0) {
    meleeSwingTimer -= dt;
    if (meleeSwingTimer < 0) meleeSwingTimer = 0;
  }
  if (comboResetTimer > 0) {
    comboResetTimer -= dt;
    if (comboResetTimer <= 0) {
      comboResetTimer = 0;
      comboCount = 0;
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
      applyDamageToMonster(hitMonster, p.isComboHit);
      projectiles.splice(i, 1);
      continue;
    }

    if (hitBoss) {
      applyDamageToBoss(p.isComboHit);
      projectiles.splice(i, 1);
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

  // 바닥 장비 드랍 - 60초 후 소멸, 플레이어가 닿으면 가방에 획득 (PRD 7.1)
  for (let i = groundItems.length - 1; i >= 0; i--) {
    const item = groundItems[i];
    item.age += dt;
    if (item.age >= BALANCE.itemGroundLifetime) {
      groundItems.splice(i, 1);
      continue;
    }
    const distToPlayer = Math.hypot(player.x - item.x, player.y - item.y);
    if (distToPlayer <= player.radius + BALANCE.itemPickupRadius) {
      const emptyIndex = bag.indexOf(null);
      if (emptyIndex !== -1) {
        bag[emptyIndex] = { grade: item.grade, part: item.part };
        groundItems.splice(i, 1);
      } else {
        bagFullNoticeTimer = BALANCE.inventoryMessageDisplayTime;
      }
    }
  }

  // 강화권 바닥 드랍 - 30초 후 소멸, 플레이어가 닿으면 획득 (PRD 9.6/8.0-5)
  for (let i = groundTickets.length - 1; i >= 0; i--) {
    const ticket = groundTickets[i];
    ticket.age += dt;
    if (ticket.age >= BALANCE.enhanceTicketGroundLifetime) {
      groundTickets.splice(i, 1);
      continue;
    }
    const distToPlayer = Math.hypot(player.x - ticket.x, player.y - ticket.y);
    if (distToPlayer <= player.radius + BALANCE.itemPickupRadius) {
      probabilityTicketCounts[ticket.size]++;
      ticketNoticeText = `${ENHANCE_TICKET_TYPES.probability.name}(${ENHANCE_TICKET_SIZES[ticket.size].label}) 획득`;
      ticketNoticeTimer = BALANCE.ticketPickupMessageDuration;
      groundTickets.splice(i, 1);
    }
  }

  // 경험치 토큰 - 흡수 반경 안이면 플레이어 쪽으로 끌려가다 닿으면 획득, 30초 후 소멸 (PRD 7.1-1)
  for (let i = expTokens.length - 1; i >= 0; i--) {
    const token = expTokens[i];
    token.age += dt;
    if (token.age >= BALANCE.expTokenLifetime) {
      expTokens.splice(i, 1);
      continue;
    }
    const distToPlayer = Math.hypot(player.x - token.x, player.y - token.y);
    if (distToPlayer <= player.radius) {
      weaponExp += token.value;
      weaponExpLevel = getWeaponLevelFromExp(weaponExp);
      expTokens.splice(i, 1);
      continue;
    }
    if (distToPlayer <= BALANCE.expTokenAbsorbRadius) {
      const pullAngle = Math.atan2(player.y - token.y, player.x - token.x);
      const step = BALANCE.expTokenHomingSpeed * dt;
      token.x += Math.cos(pullAngle) * step;
      token.y += Math.sin(pullAngle) * step;
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
    const gotTicket = Math.random() < BALANCE.bossGuaranteedTicketChance;
    if (gotTicket) guaranteedTickets.push(1);

    bossResultState = "won";
    bossResultInfo = { type: "won", grade, goldGained, gotTicket };

    // 사냥터로 복귀 (PRD 8.0-6)
    currentMap = "hunt";
    boss = null;
    player.x = BALANCE.huntSpawnX;
    player.y = BALANCE.huntSpawnY;
    doAutosave();
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
    player.x = BALANCE.huntSpawnX;
    player.y = BALANCE.huntSpawnY;
    // bossRetryCount·bossTimeRemaining은 진행도라 즉시저장 - 안 그러면 새로고침으로 재도전 횟수 제한(PRD 9.4)을 무한 우회 가능
    doAutosave();
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
  updateTicketBoostUI();
  updateStageButtons();
}

function render() {
  ctx.clearRect(0, 0, canvas.width, canvas.height);

  const mapW = currentMap === "boss" ? BALANCE.bossMapWidth : BALANCE.mapWidth;
  const mapH = currentMap === "boss" ? BALANCE.bossMapHeight : BALANCE.mapHeight;
  const forgeHeightHere = currentMap === "boss" ? 0 : BALANCE.forgeHeight;
  const stageBackground = currentMap === "hunt" ? STAGES[currentStageIndex].background : null;

  ctx.save();
  ctx.translate(-camera.x, -camera.y);

  drawMapFloor(ctx, mapW, mapH, BALANCE.wallThickness, forgeHeightHere, stageBackground);
  drawMapWalls(ctx, mapW, mapH, BALANCE.wallThickness);
  if (currentMap === "hunt") {
    for (const monster of monsters) drawMonster(ctx, monster, gameTime);
    drawGroundItems(ctx, groundItems, gameTime);
    drawExpTokens(ctx, expTokens);
    drawGroundTickets(ctx, groundTickets);
  }
  drawBoss(ctx, boss);

  const playerAlpha = player.iframeTimer > 0
    ? (Math.floor(gameTime * 10) % 2 === 0 ? 0.4 : 1)
    : 1;
  drawPlayer(ctx, player, playerAlpha);

  drawProjectiles(ctx, projectiles);
  if (selectedClass.attackType === "melee") {
    drawMeleeRangeIndicator(ctx, player, selectedClass.meleeRange, selectedClass.meleeArc, BALANCE.meleeRangeIndicatorAlpha);
  }
  if (meleeSwingTimer > 0) {
    const swingScale = meleeSwingIsCombo ? BALANCE.comboSwingScale : 1;
    drawMeleeSwing(ctx, player, meleeSwingAngle, selectedClass.meleeRange, selectedClass.meleeArc,
      meleeSwingTimer / BALANCE.meleeSwingVisualDuration, meleeSwingSide, swingScale);
  }
  drawDamageNumbers(ctx, damageNumbers);

  ctx.restore();

  if (boss && boss.enraged) drawEnrageVignette(ctx);

  drawAutoIndicator(ctx, autoMode);
  if (currentMap === "hunt") drawOffscreenIndicators(ctx, camera, monsters);
  if (currentMap === "hunt") drawBossTimer(ctx, bossTimeRemaining, player.y <= FORGE_BOTTOM);
  if (forgeNoticeTimer > 0) drawForgeNotice(ctx, FORGE_NOTICE_TEXT, 110);
  if (invenNoticeTimer > 0) drawForgeNotice(ctx, INVENTORY_NOTICE_TEXT, 132);
  if (ticketNoticeTimer > 0) drawForgeNotice(ctx, ticketNoticeText, 154);
  if (bagFullNoticeTimer > 0) drawForgeNotice(ctx, BAG_FULL_NOTICE_TEXT, 176);
  if (bossCountdownActive) drawBossCountdown(ctx, Math.ceil(bossCountdownTimer));
  if (boss) {
    drawBossHealthBar(ctx, boss);
    drawBossFightTimer(ctx, bossFightTimeRemaining, bossFightFailed);
  }
  if (bossResultState !== "none") drawBossResult(ctx, bossResultInfo);
  const totalAttack = Math.round(getPlayerAttack());
  drawEnhanceInfo(ctx, weaponLevel, enhanceResultText, enhanceResultTimer, gold, totalAttack);
  drawWeaponExpBar(ctx, weaponExpLevel, getWeaponExpProgress(weaponExp, weaponExpLevel));
  drawPlayerHealthBar(ctx, player.hp, player.maxHp, gameTime);
  drawDashCooldown(ctx, player.dashCooldownTimer, BALANCE.dashCooldown);
  if (invenOpen) {
    updateInventoryHoverSlot();
    const totalStats = { attack: totalAttack, defense: Math.round(player.defense), speed: Math.round(player.speed) };
    drawInventory(ctx, {
      equipment, bag, gameTime,
      mouseX: mouse.x, mouseY: mouse.y,
      totalStats, gradeFilter, pendingEquip, pendingSell, bulkSellConfirm, bulkSellGrade, bulkSellDropdownOpen,
      inventoryHoverSlot, invenMessage, invenMessageTimer, dragState,
      layoutOffsetX: getInventoryOffsetX()
    });
  }
}

function loop(now) {
  const dt = Math.min((now - lastTime) / 1000, BALANCE.maxFrameDt);
  lastTime = now;

  if (!selectedClass) {
    requestAnimationFrame(loop);
    return;
  }

  equipBonuses = getEquipmentBonuses(equipment);
  player.defense = BALANCE.playerDefense * selectedClass.def + equipBonuses.defenseBonus;
  player.speed = BALANCE.playerSpeed * equipBonuses.speedMultiplier;
  if (invenMessageTimer > 0) invenMessageTimer = Math.max(0, invenMessageTimer - dt);

  update(dt); // 장비창이 열려 있어도 게임은 계속 진행 (멀티 대비)
  render();
  requestAnimationFrame(loop);
}

requestAnimationFrame(loop);
