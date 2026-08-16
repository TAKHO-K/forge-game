// 무기 경험치 시스템 (PRD 4.2) - 강화(core/enhance.js)와 별개로 굴러가는 확정 성장 축
function getWeaponLevelFromExp(exp) {
  let level = 1;
  for (let i = 0; i < WEAPON_LEVEL_EXP.length; i++) {
    if (exp >= WEAPON_LEVEL_EXP[i]) level = i + 1;
    else break;
  }
  return level;
}

function getWeaponExpAttackMultiplier(level) {
  return 1 + BALANCE.weaponExpAttackBonusPerLevel * (level - 1);
}

function getWeaponExpProgress(exp, level) {
  const maxLevel = WEAPON_LEVEL_EXP.length;
  const currentThreshold = WEAPON_LEVEL_EXP[level - 1];
  if (level >= maxLevel) {
    return { current: exp - currentThreshold, needed: 0, ratio: 1 };
  }
  const nextThreshold = WEAPON_LEVEL_EXP[level];
  const needed = nextThreshold - currentThreshold;
  const current = exp - currentThreshold;
  return { current, needed, ratio: needed > 0 ? current / needed : 1 };
}
