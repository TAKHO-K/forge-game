// 장비 스탯 계산 · 판매가 (PRD 7.3) - base × 등급 성능배율

function getItemStatValue(item) {
  return ITEM_PART_BASE_STAT[item.part].base * ITEM_GRADES[item.grade].multiplier;
}

// 판매가 = 기본가 × 등급배율 × (1 + 강화단계×0.3) - enhanceLevel은 장비 강화(7.5, 미구현) 도입 전까지 항상 0
function getItemSellValue(item) {
  const enhanceLevel = item.enhanceLevel || 0;
  return Math.round(BALANCE.itemBaseSellValue * ITEM_GRADES[item.grade].sellMultiplier * (1 + enhanceLevel * 0.3));
}

// 착용 장비 3부위 합산 보너스 - defenseBonus는 가산, attack/speed는 배율(1 = 보너스 없음)
function getEquipmentBonuses(equipment) {
  let defenseBonus = 0;
  let attackMultiplier = 1;
  let speedMultiplier = 1;
  for (const part of ITEM_PARTS) {
    const item = equipment[part];
    if (!item) continue;
    const value = getItemStatValue(item);
    if (part === "armor") defenseBonus += value;
    else if (part === "gloves") attackMultiplier += value;
    else if (part === "shoes") speedMultiplier += value;
  }
  return { defenseBonus, attackMultiplier, speedMultiplier };
}
