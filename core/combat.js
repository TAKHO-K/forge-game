// 데미지 계산
// forceCrit: 확정 치명타(쌍검 Q 등) - critChance가 이미 100%면 확정치명타가 무의미해지므로
// 대신 치명타 피해율을 guaranteedCritOverflowBonus만큼 올려준다(PRD 4.3 "확정 치명타의 초과분 처리")
function calcDamage(attack, defense, critChance, critMultiplier, forceCrit = false) {
  const baseDamage = Math.max(Math.round(attack * BALANCE.damageFloorRatio), Math.round(attack - defense));
  let isCrit, finalMultiplier = critMultiplier;
  if (forceCrit) {
    isCrit = true;
    if (critChance >= 1) finalMultiplier = critMultiplier + BALANCE.guaranteedCritOverflowBonus;
  } else {
    isCrit = Math.random() < critChance;
  }
  const damage = isCrit ? Math.round(baseDamage * finalMultiplier) : baseDamage;
  return { damage, isCrit };
}

// 몬스터 -> 플레이어 데미지 (5.2) - 한 번에 최대체력 × capRatio 이상 깎이지 않음
// 체력이 10칸 정수 단위라 최종값도 정수여야 한다. 반올림만 하면 공격력이 방어력보다
// 근소하게 높을 때 0으로 내림돼 사실상 무적이 되므로, 원본 데미지가 0보다 크면 최소 1칸은 깎이게 한다
function calcPlayerDamage(monsterAttack, playerDefense, maxHp, capRatio) {
  const rawDamage = Math.max(0, Math.min(maxHp * capRatio, monsterAttack - playerDefense));
  return rawDamage > 0 ? Math.max(1, Math.round(rawDamage)) : 0;
}
