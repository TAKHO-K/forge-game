// 성공률을 배율만큼 올리고 나머지 결과는 비율 유지하며 축소 (6.2-1, 확률 강화권 소/중 공용)
function calcBoostedProbability(prob, multiplier, cap) {
  const successBoosted = Math.min(cap, prob.success * multiplier);
  const scale = (1 - successBoosted) / (1 - prob.success);
  return {
    success: successBoosted,
    maintain: prob.maintain * scale,
    down1: prob.down1 * scale,
    down2: prob.down2 * scale,
    reset: prob.reset * scale
  };
}

// 성공률을 고정값으로 맞추고 나머지 결과는 비율 유지하며 축소 (확률 강화권 대)
function calcFixedSuccessProbability(prob, fixedSuccess) {
  const scale = (1 - fixedSuccess) / (1 - prob.success);
  return {
    success: fixedSuccess,
    maintain: prob.maintain * scale,
    down1: prob.down1 * scale,
    down2: prob.down2 * scale,
    reset: prob.reset * scale
  };
}

// boostType: "none" | "high" | "small" | "medium" | "large" - 확률권 3종은 상급 강화·서로 간 중복 불가라 한 번에 하나만 적용
// 보정 결과가 기본 확률보다 낮으면 기본 확률을 그대로 쓴다 - 상한(90%)이나 고정값(대 확률권 50%)이
// 저단계 기본 성공률(92%)보다 낮아, 그대로 두면 "보정"이 성공률을 깎는 페널티가 된다
function resolveProbability(level, boostType) {
  const prob = ENHANCE_PROBABILITY[level];
  if (boostType === "high") return keepBetter(prob, calcBoostedProbability(prob, ENHANCE_HIGH_SUCCESS_MULTIPLIER, ENHANCE_HIGH_SUCCESS_CAP));
  const ticketBoost = ENHANCE_TICKET_BOOST[boostType];
  if (!ticketBoost) return prob;
  return keepBetter(prob, ticketBoost.fixedSuccess !== undefined
    ? calcFixedSuccessProbability(prob, ticketBoost.fixedSuccess)
    : calcBoostedProbability(prob, ticketBoost.multiplier, ticketBoost.cap));
}

function keepBetter(prob, boosted) {
  return boosted.success >= prob.success ? boosted : prob;
}

// 강화 판정
function tryEnhance(level, boostType) {
  if (level >= ENHANCE_MAX_LEVEL) {
    return { result: "max", level };
  }

  const prob = resolveProbability(level, boostType);
  const roll = Math.random();
  let acc = 0;

  acc += prob.success;
  if (roll < acc) return { result: "success", level: level + 1 };

  acc += prob.maintain;
  if (roll < acc) return { result: "maintain", level };

  acc += prob.down1;
  if (roll < acc) return { result: "down1", level: Math.max(1, level - 1) };

  acc += prob.down2;
  if (roll < acc) return { result: "down2", level: Math.max(1, level - 2) };

  return { result: "reset", level: 1 };
}

function getEnhanceDamageMultiplier(level) {
  return 1 + ENHANCE_DAMAGE_COEFFICIENT[level];
}

// 강화 비용 (6.2-2) - 최대 강화 단계에서는 시도 불가
function getEnhanceCost(level, isHigh) {
  if (level >= ENHANCE_MAX_LEVEL) return Infinity;
  const base = ENHANCE_GOLD_COST[level];
  return isHigh ? base * ENHANCE_HIGH_COST_MULTIPLIER : base;
}
