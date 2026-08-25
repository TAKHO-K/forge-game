// 장비 스탯 계산 · 판매가 (PRD 7.3) - base × 등급배율 × 아이템 레벨계수

// 아이템 레벨계수 - 획득 시점 캐릭터 레벨이 각인된 item.itemLevel 기준(data/items.js 참고)
function getItemLevelMultiplier(itemLevel) {
  return 1 + ITEM_LEVEL_STAT_BONUS_PER_LEVEL * (itemLevel - 1);
}

// 스탯 = 기본값 × 등급배율 × 레벨계수 - 판매가와 같은 축을 공유(아래)
function getItemStatValue(item) {
  return ITEM_PART_BASE_STAT[item.part].base * ITEM_GRADES[item.grade].multiplier * getItemLevelMultiplier(item.itemLevel);
}

// 판매가 = 기본가 × 등급배율 × 레벨계수 - 스탯 계산과 같은 계수를 공유해 "비싼데 안 세다" 괴리를 막는다
function getItemSellValue(item) {
  return Math.round(BALANCE.itemBaseSellValue * ITEM_GRADES[item.grade].sellMultiplier * getItemLevelMultiplier(item.itemLevel));
}

// 착용 장비 3부위 합산 보너스 - 부위 기본효과 + 랜덤 옵션(item.options)을 스탯 id별로 순회하며
// 합산한다(설계 승인, data/stats.js STAT_REGISTRY 참고). defenseBonus/attackMultiplier/
// speedMultiplier는 기존 소비 코드 호환용 별칭 - 새 스탯은 byId로 읽는다.
function getEquipmentBonuses(equipment) {
  const totals = {};
  for (const id of STAT_ID_ORDER) totals[id] = 0;

  for (const part of ITEM_PARTS) {
    const item = equipment[part];
    if (!item) continue;
    const baseStatId = ITEM_PART_BASE_STAT[part].statType;
    totals[baseStatId] += getItemStatValue(item);
    if (item.options) {
      for (const opt of item.options) totals[opt.statId] += opt.value;
    }
  }

  return {
    byId: totals,
    defenseBonus: totals.defenseFlat,
    attackMultiplier: 1 + totals.attackPercent,
    speedMultiplier: 1 + totals.speedPercent
  };
}
