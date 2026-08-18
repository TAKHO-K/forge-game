// 드랍 판정 - 장비 등급/부위 (PRD 7.1, 7.2), 경험치 토큰 (PRD 7.1-1)

// 착용 장비 기준 등급 - 3부위 중 최하위, 미착용 부위는 normal 취급 (PRD 7.4 자동판매와 같은 철학)
function getEquipmentBaselineGradeIndex(equipment) {
  let minIndex = ITEM_GRADE_ORDER.length - 1;
  for (const part of ITEM_PARTS) {
    const item = equipment[part];
    const grade = item ? item.grade : "normal";
    minIndex = Math.min(minIndex, ITEM_GRADE_ORDER.indexOf(grade));
  }
  return minIndex;
}

// 기준 등급 + EQUIPMENT_GRADE_BOOST.capSteps 등급에만 weight를 더하고 행 전체를 재정규화 (합은 항상 1 유지)
function getBoostedDropTable(tier, equipment) {
  const table = DROP_GRADE_TABLE[tier - 1];
  const baselineIndex = getEquipmentBaselineGradeIndex(equipment);
  const targetGrade = ITEM_GRADE_ORDER[baselineIndex + EQUIPMENT_GRADE_BOOST.capSteps];
  if (!targetGrade || targetGrade === "ancient" || targetGrade === "primordial" || table[targetGrade] === undefined) {
    return table;
  }
  const boosted = Object.assign({}, table);
  boosted[targetGrade] += EQUIPMENT_GRADE_BOOST.weight;
  const sum = Object.values(boosted).reduce((a, b) => a + b, 0);
  for (const grade in boosted) boosted[grade] /= sum;
  return boosted;
}

function rollItemGrade(tier, equipment) {
  const table = getBoostedDropTable(tier, equipment);
  const roll = Math.random();
  let acc = 0;
  for (const grade of ITEM_GRADE_ORDER) {
    if (!table[grade]) continue;
    acc += table[grade];
    if (roll < acc) return grade;
  }
  return null;
}

function rollItemPart() {
  return ITEM_PARTS[Math.floor(Math.random() * ITEM_PARTS.length)];
}

// 슬롯 2회 판정 (7.1 다중 드랍) - 슬롯2 확률은 슬롯1의 dropSlot2Multiplier배
function rollDroppedItems(tier, dropChance, slot2Multiplier, equipment) {
  const drops = [];
  if (Math.random() < dropChance) {
    const grade = rollItemGrade(tier, equipment);
    if (grade) drops.push({ grade, part: rollItemPart() });
  }
  if (Math.random() < dropChance * slot2Multiplier) {
    const grade = rollItemGrade(tier, equipment);
    if (grade) drops.push({ grade, part: rollItemPart() });
  }
  return drops;
}

function rollExpTokenSize() {
  const roll = Math.random();
  let acc = 0;
  for (const size of Object.keys(EXP_TOKEN_TIERS)) {
    acc += EXP_TOKEN_TIERS[size].chance;
    if (roll < acc) return size;
  }
  return "small";
}

function rollExpTokenCount(tier) {
  const [min, max] = BALANCE.expTokenCountByTier[tier - 1];
  return min + Math.floor(Math.random() * (max - min + 1));
}
