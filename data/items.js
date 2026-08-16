// 장비 · 소모품 · 특수 드랍 (PRD 7장)

// 장비 등급 7단계 (7.0) - color는 바닥 드랍 표시에 사용, multiplier는 장비 스탯 계산에 쓸 예정(미구현)
// 유물·태초는 enhanceable:false - 장비 강화 시스템은 아직 미구현(7.5)
const ITEM_GRADES = {
  normal:     { name: "Common",    color: "#e6e6e6", multiplier: 1.0,  enhanceable: true },
  rare:       { name: "Rare",      color: "#4da6ff", multiplier: 1.4,  enhanceable: true },
  epic:       { name: "Epic",      color: "#a64dff", multiplier: 2.0,  enhanceable: true },
  unique:     { name: "Unique",    color: "#ff9933", multiplier: 3.0,  enhanceable: true },
  legend:     { name: "Legendary", color: "#ffd700", multiplier: 4.5,  enhanceable: true },
  relic:      { name: "Relic",     color: "#e0393e", multiplier: 8.0,  enhanceable: false },
  primordial: { name: "Primordial", color: "rainbow", multiplier: 15.0, enhanceable: false } // color:"rainbow" -> 렌더에서 hue 순환 처리
};
const ITEM_GRADE_ORDER = ["normal", "rare", "epic", "unique", "legend", "relic", "primordial"];

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
  { normal: 0.45, rare: 0.40, epic: 0.14, unique: 0.01 },
  { normal: 0.20, rare: 0.40, epic: 0.30, unique: 0.09, legend: 0.01 },
  { normal: 0.05, rare: 0.25, epic: 0.40, unique: 0.25, legend: 0.045, relic: 0.005 },
  { rare: 0.10, epic: 0.30, unique: 0.40, legend: 0.18, relic: 0.019, primordial: 0.001 }
];

// 경험치 토큰 크기 (7.1-1) - value는 몬스터 weaponExp 기준 배율
const EXP_TOKEN_TIERS = {
  small:  { multiplier: 1, chance: 0.70, color: "#4da6ff", radius: 4 },
  medium: { multiplier: 3, chance: 0.25, color: "#4dd97e", radius: 6 },
  large:  { multiplier: 8, chance: 0.05, color: "#ffd700", radius: 9 }
};
