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

// 기준 등급 + EQUIPMENT_GRADE_BOOST.capSteps 등급에만 확률을 더한다.
// 더한 만큼은 "대상보다 낮은 등급"에서만 비례로 빼온다 - 대상과 같거나 높은 등급(유물 위 등급 포함)은 절대 건드리지 않으므로
// 항상 원래 확률 이상으로 유지되고, 고대·태초는 대상이 될 수 없어(아래 가드) 낮은 등급 축에도 대상 축에도 들지 않아 원래값 그대로 남는다.
// 증가폭은 min(weight, 원래 확률 x maxMultiplier)로 상한을 건다 - flat weight만 쓰면 원래 확률이 작을수록(예: 유물 1%) 상대 증가폭이
// 폭발하기 때문(1%+15% = 16배). 두 상한 중 더 낮은 쪽이 적용되므로 legendary처럼 원래 확률이 큰 등급은 weight가,
// relic처럼 원래 확률이 작은 등급은 maxMultiplier가 실질적인 한도가 된다.
function getBoostedDropTable(tier, equipment) {
  const table = DROP_GRADE_TABLE[tier - 1];
  const baselineIndex = getEquipmentBaselineGradeIndex(equipment);
  const targetGrade = ITEM_GRADE_ORDER[baselineIndex + EQUIPMENT_GRADE_BOOST.capSteps];
  // ancient는 보정 대상이 될 수 있다(3부위 유물 착용 시 고대 확률 상승, 밸런스 조정 승인).
  // primordial은 최종 목표 아이템이라 과하게 안 풀리도록 계속 제외한다.
  if (!targetGrade || targetGrade === "primordial" || table[targetGrade] === undefined) {
    return table;
  }
  const targetIndex = ITEM_GRADE_ORDER.indexOf(targetGrade);
  const original = table[targetGrade];
  const desired = Math.min(original + EQUIPMENT_GRADE_BOOST.weight, original * EQUIPMENT_GRADE_BOOST.maxMultiplier);
  const add = desired - original;
  if (add <= 0) return table;

  const belowGrades = ITEM_GRADE_ORDER.slice(0, targetIndex).filter((g) => table[g] !== undefined);
  const belowSum = belowGrades.reduce((sum, g) => sum + table[g], 0);

  const boosted = Object.assign({}, table);
  if (belowSum <= add) {
    // 경계 케이스: 대상보다 낮은 등급을 다 합쳐도 add보다 작다 - 낮은 등급을 전부 0으로 만들고 그만큼만(belowSum) 대상에 더한다.
    // 이렇게 해야 행의 합이 항상 정확히 1로 유지된다(모자란 만큼을 더 끌어올 곳이 없으므로 add 전액이 아닌 belowSum만 이동).
    for (const g of belowGrades) boosted[g] = 0;
    boosted[targetGrade] = original + belowSum;
  } else {
    for (const g of belowGrades) {
      boosted[g] = table[g] - add * (table[g] / belowSum);
    }
    boosted[targetGrade] = original + add;
  }
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
