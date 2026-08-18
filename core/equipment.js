// 장비 스탯 계산 · 판매가 (PRD 7.3) - base × 등급 성능배율

// 스탯 = 기본값 × 등급배율 × (1 + 강화단계 × ITEM_ENHANCE_STAT_BONUS_PER_LEVEL) - 판매가와 같은 축(data/items.js 참고)
function getItemStatValue(item) {
  const enhanceLevel = item.enhanceLevel || 0;
  return ITEM_PART_BASE_STAT[item.part].base * ITEM_GRADES[item.grade].multiplier * (1 + enhanceLevel * ITEM_ENHANCE_STAT_BONUS_PER_LEVEL);
}

// 판매가 = 기본가 × 등급배율 × (1 + 강화단계 × ITEM_ENHANCE_STAT_BONUS_PER_LEVEL) - 스탯 계산과 같은 계수를 공유
function getItemSellValue(item) {
  const enhanceLevel = item.enhanceLevel || 0;
  return Math.round(BALANCE.itemBaseSellValue * ITEM_GRADES[item.grade].sellMultiplier * (1 + enhanceLevel * ITEM_ENHANCE_STAT_BONUS_PER_LEVEL));
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
