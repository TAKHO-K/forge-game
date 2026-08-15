// 데미지 계산
function calcDamage(attack, defense, critChance, critMultiplier) {
  const baseDamage = Math.max(1, Math.round(attack - defense));
  const isCrit = Math.random() < critChance;
  const damage = isCrit ? Math.round(baseDamage * critMultiplier) : baseDamage;
  return { damage, isCrit };
}

// 몬스터 -> 플레이어 데미지 (5.2) - 한 번에 최대체력 × capRatio 이상 깎이지 않음
function calcPlayerDamage(monsterAttack, playerDefense, maxHp, capRatio) {
  return Math.max(0, Math.min(maxHp * capRatio, monsterAttack - playerDefense));
}
