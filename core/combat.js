// 데미지 계산
function calcDamage(attack, defense) {
  return Math.max(1, attack - defense);
}
