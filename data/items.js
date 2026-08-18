// 장비 · 소모품 · 특수 드랍 (PRD 7장)

// 장비 등급 7단계 (7.0) - color는 바닥 드랍 표시에 사용, multiplier는 장비 스탯 계산에 쓸 예정(미구현)
// 고대·태초는 enhanceable:false - 장비 강화 시스템은 아직 미구현(7.5)
// nameKo: 판매 UI(툴팁·일괄판매)에서만 사용 - 기존 표시용 name(영문)은 그대로 둠
// sellMultiplier: 판매가 전용 등급배율(7.6) - 스탯 계산용 multiplier와는 별개 수치
const ITEM_GRADES = {
  normal:     { name: "Common",    nameKo: "일반", color: "#e6e6e6", multiplier: 1.0,  sellMultiplier: 1,  enhanceable: true },
  rare:       { name: "Rare",      nameKo: "희귀", color: "#4da6ff", multiplier: 1.4,  sellMultiplier: 2,  enhanceable: true },
  epic:       { name: "Epic",      nameKo: "영웅", color: "#a64dff", multiplier: 2.0,  sellMultiplier: 4,  enhanceable: true },
  legendary:  { name: "Legendary", nameKo: "전설", color: "#ff9933", multiplier: 3.0,  sellMultiplier: 8,  enhanceable: true },
  relic:      { name: "Relic",     nameKo: "유물", color: "#ffd700", multiplier: 4.5,  sellMultiplier: 16, enhanceable: true },
  ancient:    { name: "Ancient",   nameKo: "고대", color: "#e0393e", multiplier: 8.0,  sellMultiplier: 35, enhanceable: false },
  primordial: { name: "Primordial", nameKo: "태초", color: "rainbow", multiplier: 15.0, sellMultiplier: 80, enhanceable: false } // color:"rainbow" -> 렌더에서 hue 순환 처리
};
const ITEM_GRADE_ORDER = ["normal", "rare", "epic", "legendary", "relic", "ancient", "primordial"];

// 일괄 판매 대상 등급 (7.4 근처) - 고대·태초는 항상 제외
const BULK_SELLABLE_GRADES = ITEM_GRADE_ORDER.filter((g) => g !== "ancient" && g !== "primordial");

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

// 착용 장비 기준 드랍 등급 보정 (core/loot.js getBoostedDropTable에서 사용)
// capSteps: 기준 등급(착용 3부위 중 최하위, 미착용은 normal) + capSteps 등급에만 확률을 더한다(대상보다 낮은 등급에서만 차감).
//   1로 고정 - 시뮬레이션 결과 capSteps=2는 등급을 한 단계 건너뛴다(예: tier4에서 올영웅 착용 시
//   legendary가 아니라 relic이 바로 뛰고 legendary는 보정 전보다도 낮아짐 - 성장 곡선이 끊겨 보임).
//   capSteps=1은 legendary만 완만하게 올라가 "다음 등급이 조금 더 잘 나온다"는 체감에 맞음.
// weight: 0.15 - 대상 등급에 더하는 최대 절대량. tier4 legendary(9%) 기준 weight만 적용되면 24%까지 갈 수 있지만
//   maxMultiplier가 더 낮게 걸려 실제로는 그쪽이 상한이 된다(아래 참고).
// maxMultiplier: 2.4 - 대상 등급의 보정 후 확률은 "원래 확률 x maxMultiplier"를 넘지 못한다. weight와 maxMultiplier 중
//   더 낮은 쪽이 실제 상한이 된다. tier4 legendary(9%)는 2.4배=21.6%가 weight(24%)보다 낮아 이 상한이 적용되어
//   기존 목표치(~21.5%)를 그대로 유지하고, tier4 relic(1%)은 2.4배=2.4%로 묶여 flat weight를 그대로 더했을 때
//   나오는 16%(14배 폭증)를 막는다. 즉 2.4는 "legendary 성장폭은 유지하면서 relic 같은 희귀 등급의 폭증만 억제"하는
//   지점으로 시뮬레이션에서 확인해 선택했다(2.0은 legendary가 18%로 줄어 성장폭이 약해지고, 3.0은 relic이 3%로
//   여전히 3배 뛰어 희소성이 흔들리기 시작함).
// target이 ancient·primordial이거나 해당 tier 표에 아예 없는 등급이면 보정을 걸지 않는다(getBoostedDropTable) -
//   고대·태초는 항상 대상보다 높은 등급이라 차감 대상에도 들지 않아 원래 확률이 그대로 보존된다(모든 tier x 기준등급
//   조합에서 시뮬레이션으로 확인).
const EQUIPMENT_GRADE_BOOST = { capSteps: 1, weight: 0.15, maxMultiplier: 2.4 };

// 장비 강화 확률표 (PRD 7.5, core/equipEnhance.js getEquipEnhanceProbability에서 사용) - 성공/파괴 2종뿐(무기 강화의
// 강등·리셋 없음). minLevel은 이 구간이 적용되는 목표 레벨(강화 시도로 도달하려는 레벨, 예: +1은 0강->1강 시도)의
// 하한. "+10 이상"이 무한히 이어지므로 고정 배열 대신 구간 오름차순 목록으로 표현한다.
const ITEM_ENHANCE_PROBABILITY = [
  { minLevel: 1, success: 0.90, destroy: 0.10 },
  { minLevel: 4, success: 0.70, destroy: 0.30 },
  { minLevel: 7, success: 0.45, destroy: 0.55 },
  { minLevel: 10, success: 0.25, destroy: 0.75 }
];

// 강화 1단계당 스탯·판매가 증가율 - core/equipment.js의 getItemStatValue(전투력)와 getItemSellValue(판매가)가
// 이 값을 공유해서 쓴다. 같은 계수를 쓰는 이유: 가격과 실전력이 같은 배율로 올라야 "비싼데 안 세다" 같은
// 괴리가 안 생긴다. 값 자체(0.3)는 기존 판매가 공식이 이미 쓰던 계수를 그대로 승계.
const ITEM_ENHANCE_STAT_BONUS_PER_LEVEL = 0.3;

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
