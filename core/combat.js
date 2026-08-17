// 데미지 계산
function calcDamage(attack, defense, critChance, critMultiplier) {
  const baseDamage = Math.max(Math.round(attack * BALANCE.damageFloorRatio), Math.round(attack - defense));
  const isCrit = Math.random() < critChance;
  const damage = isCrit ? Math.round(baseDamage * critMultiplier) : baseDamage;
  return { damage, isCrit };
}

// 몬스터 -> 플레이어 데미지 (5.2) - 한 번에 최대체력 × capRatio 이상 깎이지 않음
// 체력이 10칸 정수 단위라 최종값도 정수여야 한다. 반올림만 하면 공격력이 방어력보다
// 근소하게 높을 때 0으로 내림돼 사실상 무적이 되므로, 원본 데미지가 0보다 크면 최소 1칸은 깎이게 한다
function calcPlayerDamage(monsterAttack, playerDefense, maxHp, capRatio) {
  const rawDamage = Math.max(0, Math.min(maxHp * capRatio, monsterAttack - playerDefense));
  return rawDamage > 0 ? Math.max(1, Math.round(rawDamage)) : 0;
}
