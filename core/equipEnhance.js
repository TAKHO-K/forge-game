// 장비 강화 (PRD 7.5) - 무기 강화(core/enhance.js)와는 완전히 별개 시스템.
// 결과는 성공/파괴 2종뿐(무기 강화의 강등·리셋 없음) - 파괴 시 장비가 완전히 사라진다는 점이
// 무기 강화의 "되돌릴 수 있는 강등"과 대비되는 설계 의도.

// 목표 레벨(강화 시도로 도달하려는 레벨 = 현재 레벨+1) 기준으로 구간을 찾는다
function getEquipEnhanceProbability(level) {
  const targetLevel = level + 1;
  let matched = ITEM_ENHANCE_PROBABILITY[0];
  for (const row of ITEM_ENHANCE_PROBABILITY) {
    if (row.minLevel <= targetLevel) matched = row;
  }
  return matched;
}

// 강화 골드 비용 = 무기 강화와 같은 레벨당 비용표(ENHANCE_GOLD_COST) x 등급별 판매가 배율(sellMultiplier).
// 등급 배율을 곱하는 이유: 곱하지 않으면 유물(판매가 800G) +1 비용이 10G(판매가의 1.25%)인데 커먼(판매가 50G)은
// 10G(20%)라 등급이 높을수록 강화가 오히려 공짜에 가까워지는 역방향 곡선이 된다. sellMultiplier를 곱하면
// "비용 = 판매가의 일정 비율"이 모든 등급에서 동일하게 유지된다 - 판매가 공식이 이미 같은 배율을 쓰므로 같은 축.
function getEquipEnhanceCost(level, grade) {
  const idx = Math.min(level, ENHANCE_GOLD_COST.length - 1);
  return ENHANCE_GOLD_COST[idx] * ITEM_GRADES[grade].sellMultiplier;
}

// 강화 가능 여부 - 고대·태초는 강화 불가(버튼 비활성, PRD 7.5), 캐릭터 레벨을 넘는 단계로는 시도 자체가 불가(PRD 7.0-1).
// v1은 별도의 캐릭터 레벨 시스템이 없어 weaponExpLevel을 그대로 쓴다(main.js getCharacterLevel) - 설계 승인 사항.
function canEquipEnhance(item, characterLevel) {
  if (!ITEM_GRADES[item.grade].enhanceable) return false;
  const level = item.enhanceLevel || 0;
  return level + 1 <= characterLevel;
}

// 확인창을 띄울지 - 판매의 shouldConfirmSell과 같은 "조건부 확인" 패턴(요청사항 2).
// 파괴 확률이 첫 구간(10%)을 넘는 순간부터(레벨 3 이상, 즉 +4 시도부터) 확인창을 띄운다.
// 파괴 확률 임계값으로 고른 이유: 강화 단계별 위험도는 등급과 무관하게 이 표 하나로 정해지므로,
// 등급 임계값보다 "그 시도가 실제로 얼마나 위험한가"를 직접 반영한다. +1~+3(10%)은 반복 강화의 기본 리듬이라
// 매번 확인창을 띄우면(+9까지 18클릭) 강화를 못 할 지경이 되므로 그대로 진행하고, 30%부터는 확인을 받는다.
function shouldConfirmEquipEnhance(item) {
  const prob = getEquipEnhanceProbability(item.enhanceLevel || 0);
  return prob.destroy > 0.10;
}

// 강화 판정. preventDestroy: 파괴방지권 연동 지점 - 지금은 호출부(main.js)가 항상 false로 넘긴다(파괴방지권 미구현).
// 나중에 파괴방지권이 들어오면 호출부에서 보유 개수/체크 상태를 여기로 전달하는 것만으로
// "모든 파괴를 유지로 바꾼다"가 한 곳(아래 분기)에서 적용된다.
function tryEquipEnhance(level, preventDestroy) {
  const prob = getEquipEnhanceProbability(level);
  const success = Math.random() < prob.success;
  if (success) return { result: "success", level: level + 1 };
  if (preventDestroy) return { result: "maintain", level };
  return { result: "destroy", level };
}
