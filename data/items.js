// 장비 · 소모품 · 특수 드랍 (PRD 7장)

// 장비 등급 7단계 (7.0) - color는 바닥 드랍 표시에 사용, multiplier는 장비 스탯 계산에 쓸 예정(미구현)
// 고대·태초는 enhanceable:false - 장비 강화 시스템은 아직 미구현(7.5)
const ITEM_GRADES = {
  normal:     { name: "Common",    color: "#e6e6e6", multiplier: 1.0,  enhanceable: true },
  rare:       { name: "Rare",      color: "#4da6ff", multiplier: 1.4,  enhanceable: true },
  epic:       { name: "Epic",      color: "#a64dff", multiplier: 2.0,  enhanceable: true },
  legendary:  { name: "Legendary", color: "#ff9933", multiplier: 3.0,  enhanceable: true },
  relic:      { name: "Relic",     color: "#ffd700", multiplier: 4.5,  enhanceable: true },
  ancient:    { name: "Ancient",   color: "#e0393e", multiplier: 8.0,  enhanceable: false },
  primordial: { name: "Primordial", color: "rainbow", multiplier: 15.0, enhanceable: false } // color:"rainbow" -> 렌더에서 hue 순환 처리
};
const ITEM_GRADE_ORDER = ["normal", "rare", "epic", "legendary", "relic", "ancient", "primordial"];

// 장비 부위 (7.3) - 드랍 시점엔 등급만 노출, 부위는 주운 뒤 확인 (7.1)
const ITEM_PARTS = ["armor", "gloves", "shoes"];
const ITEM_PART_NAMES = { armor: "갑옷", gloves: "장갑", shoes: "신발" };

// 부위별 기본 효과 (7.3) - 실제 값은 base × 등급 성능배율(ITEM_GRADES.multiplier)
// armor: 방어력 +base, gloves/shoes: 공격력·이동속도 +base(비율)
const ITEM_PART_BASE_STAT = {
  armor:  { statType: "defenseFlat",   base: 2 },
  gloves: { statType: "attackPercent", base: 0.05 },
  shoes:  { statType: "speedPercent",  base: 0.05 }
};

// 몬스터 등급(tier)별 드랍 등급 확률표 (7.2) - index는 tier-1, 각 행의 합은 1
const DROP_GRADE_TABLE = [
  { normal: 0.90, rare: 0.10 },
  { normal: 0.70, rare: 0.27, epic: 0.03 },
  { normal: 0.45, rare: 0.40, epic: 0.14, legendary: 0.01 },
  { normal: 0.20, rare: 0.40, epic: 0.30, legendary: 0.09, relic: 0.01 },
  { normal: 0.05, rare: 0.25, epic: 0.40, legendary: 0.25, relic: 0.045, ancient: 0.005 },
  { rare: 0.10, epic: 0.30, legendary: 0.40, relic: 0.18, ancient: 0.019, primordial: 0.001 }
];

// 경험치 토큰 크기 (7.1-1) - value는 몬스터 weaponExp 기준 배율
// 색은 장비 등급 색(ITEM_GRADES)과 겹치지 않는 하늘색~청록 계열로 통일 - 소/중/대는 색이 아니라 radius(대는 소의 2배)로 구분
const EXP_TOKEN_TIERS = {
  small:  { multiplier: 1, chance: 0.70, color: "#7dd3fc", radius: 4 },
  medium: { multiplier: 3, chance: 0.25, color: "#2dd4bf", radius: 6 },
  large:  { multiplier: 8, chance: 0.05, color: "#5eead4", radius: 8 }
};

// 강화권 (9.6/8.0-5) - 확정권은 보스 클리어 지급, 확률권은 재료 몬스터가 바닥에 드랍(주우면 획득)
// 확정권=자홍(즉시 +1, 실패 없음) / 확률권=초록(강화 시도 성공 확률 보정, ENHANCE_TICKET_BOOST 참고)
const ENHANCE_TICKET_TYPES = {
  guaranteed:  { name: "확정 강화권", color: "#ff44aa" },
  probability: { name: "확률 강화권", color: "#33cc66" }
};

// 확률 강화권 크기 - materialTicketSizeChances(balance.js)로 드랍 시 랜덤 결정
const ENHANCE_TICKET_SIZES = {
  small:  { label: "소", radius: 6 },
  medium: { label: "중", radius: 8 },
  large:  { label: "대", radius: 10 }
};
