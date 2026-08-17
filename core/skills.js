// 스킬 효과 계산 (data/skills.js의 effects 조각을 해석하는 순수 함수들)
// 쿨다운·활성 버프 같은 상태는 main.js가 들고 있고, 여기는 계산만 한다 - 다른 core/ 파일과 동일한 방식.

// heal 조각의 회복량 - healPower는 v1에서 항상 0이라 "1 + 계수"로 둬야
// baseAmount가 그대로 나온다(0을 곱하면 회복량이 0이 되어버림).
// weaponExp 공격력 배율(1 + 계수*레벨)과 같은 관례 - v3에서 healPower가
// 실제값을 가지면 이 식 그대로 자연히 커진다.
function computeHealAmount(effect, healPower, critRate) {
  const base = Math.round(effect.baseAmount * (1 + (effect.scaleWithHealPower ? healPower : 0)));
  const isCrit = !!effect.critDoubles && Math.random() < critRate;
  return { amount: isCrit ? base * 2 : base, isCrit };
}

// buff 조각의 크기 계산 - formula가 있으면 시전 시점 스탯에서 1회 산출해 지속시간 내내
// 고정값으로 쓴다(매 프레임 재계산 안 함). 없으면 effect.value를 그대로 쓴다.
function computeBuffMagnitude(effect, critChance) {
  if (!effect.formula) return effect.value;
  const f = effect.formula;
  const scaleStat = f.scaleFrom === "critChance" ? critChance : 0;
  return Math.min(f.cap, f.base + scaleStat * f.coefficient);
}

// 점 (px,py)에서 선분 (ax,ay)-(bx,by)까지의 최단 거리 - hitOnDash 조각이
// "돌진 경로상의 적"을 판정하는 데 쓴다
function pointSegmentDistance(px, py, ax, ay, bx, by) {
  const abx = bx - ax, aby = by - ay;
  const abLenSq = abx * abx + aby * aby;
  let t = abLenSq > 0 ? ((px - ax) * abx + (py - ay) * aby) / abLenSq : 0;
  t = Math.max(0, Math.min(1, t));
  const cx = ax + abx * t, cy = ay + aby * t;
  return Math.hypot(px - cx, py - cy);
}
