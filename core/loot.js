// 드랍 판정 - 장비 등급/부위 (PRD 7.1, 7.2), 경험치 토큰 (PRD 7.1-1)

function rollItemGrade(tier) {
  const table = DROP_GRADE_TABLE[tier - 1];
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
function rollDroppedItems(tier, dropChance, slot2Multiplier) {
  const drops = [];
  if (Math.random() < dropChance) {
    const grade = rollItemGrade(tier);
    if (grade) drops.push({ grade, part: rollItemPart() });
  }
  if (Math.random() < dropChance * slot2Multiplier) {
    const grade = rollItemGrade(tier);
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
