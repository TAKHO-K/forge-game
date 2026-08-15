// 상급 강화 확률 계산 (6.2-1) - 성공률을 올리고 나머지 결과는 비율 유지하며 축소
function calcHighProbability(prob) {
  const successHigh = Math.min(ENHANCE_HIGH_SUCCESS_CAP, prob.success * ENHANCE_HIGH_SUCCESS_MULTIPLIER);
  const scale = (1 - successHigh) / (1 - prob.success);
  return {
    success: successHigh,
    maintain: prob.maintain * scale,
    down1: prob.down1 * scale,
    down2: prob.down2 * scale,
    reset: prob.reset * scale
  };
}

// 강화 판정
function tryEnhance(level, isHigh) {
  if (level >= ENHANCE_MAX_LEVEL) {
    return { result: "max", level };
  }

  const prob = isHigh ? calcHighProbability(ENHANCE_PROBABILITY[level]) : ENHANCE_PROBABILITY[level];
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
