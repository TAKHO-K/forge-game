// 장비 · 소모품 · 특수 드랍 (PRD 7장)

// 장비 등급 7단계 (7.0) - color는 바닥 드랍 표시에 사용, multiplier는 장비 스탯 계산에 사용
// nameKo: 판매 UI(툴팁·일괄판매)에서만 사용 - 기존 표시용 name(영문)은 그대로 둠
// sellMultiplier: 판매가 전용 등급배율(7.6) - 스탯 계산용 multiplier와는 별개 수치
const ITEM_GRADES = {
  normal:     { name: "Common",    nameKo: "일반", color: "#e6e6e6", multiplier: 1.0,  sellMultiplier: 1 },
  rare:       { name: "Rare",      nameKo: "희귀", color: "#4da6ff", multiplier: 1.4,  sellMultiplier: 2 },
  epic:       { name: "Epic",      nameKo: "영웅", color: "#a64dff", multiplier: 2.0,  sellMultiplier: 4 },
  legendary:  { name: "Legendary", nameKo: "전설", color: "#ff9933", multiplier: 3.0,  sellMultiplier: 8 },
  relic:      { name: "Relic",     nameKo: "유물", color: "#ffd700", multiplier: 4.5,  sellMultiplier: 16 },
  ancient:    { name: "Ancient",   nameKo: "고대", color: "#e0393e", multiplier: 8.0,  sellMultiplier: 35 },
  primordial: { name: "Primordial", nameKo: "태초", color: "rainbow", multiplier: 15.0, sellMultiplier: 80 } // color:"rainbow" -> 렌더에서 hue 순환 처리
};
const ITEM_GRADE_ORDER = ["normal", "rare", "epic", "legendary", "relic", "ancient", "primordial"];

// 일괄 판매 대상 등급 (7.4 근처) - 고대·태초는 항상 제외
const BULK_SELLABLE_GRADES = ITEM_GRADE_ORDER.filter((g) => g !== "ancient" && g !== "primordial");

// 장비 부위 (7.3) - 드랍 시점엔 등급만 노출, 부위는 주운 뒤 확인 (7.1)
const ITEM_PARTS = ["armor", "gloves", "shoes"];
const ITEM_PART_NAMES = { armor: "갑옷", gloves: "장갑", shoes: "신발" };

// 부위별 기본 효과 (7.3) - 실제 값은 base × 등급 성능배율(ITEM_GRADES.multiplier)
// armor: 방어력 +base, gloves/shoes: 공격력·이동속도 +base(비율)
// gloves/shoes base: 0.05 -> 0.15 (밸런스 조정 승인) - 최종배율이 "1 + base×등급배율×레벨계수" 구조라
// 밑깔림 1이 레벨 1->25 체감 증가폭을 갑옷(flat 가산이라 밑깔림 없음)보다 크게 눌러왔다. base를 올리면
// 이 비율이 갑옷의 순수 증가율(2.44배)에 점근하므로(다만 완전히 도달하진 못함) 체감 격차를 줄인다 -
// 전설 기준 Lv1->25 배율이 1.19배 -> 1.45배로 갑옷(클래스별 1.69~1.96배)에 가까워짐(시뮬레이션 확인).
const ITEM_PART_BASE_STAT = {
  armor:  { statType: "defenseFlat",   base: 2 },
  gloves: { statType: "attackPercent", base: 0.15 },
  shoes:  { statType: "speedPercent",  base: 0.15 }
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
// maxMultiplier: 2.4 -> 3.2 (밸런스 조정 승인) - 대상 등급의 보정 후 확률은 "원래 확률 x maxMultiplier"를
//   넘지 못한다. weight와 maxMultiplier 중 더 낮은 쪽이 실제 상한이 된다. 3부위 유물 착용 시 대상이 ancient가
//   되는데(아래 core/loot.js 참고), ancient처럼 원래 확률이 아주 작은 등급은 weight(0.15)가 항상 원래확률을
//   압도해 사실상 maxMultiplier만이 실질 상한이 된다 - tier5 ancient(0.5%)가 목표치(3부위 유물 시 1.5%↑)에
//   닿으려면 최소 3.0배가 필요해 3.2로 올렸다(결과 1.6%). 이 김에 legendary(tier4 9%->24%)·relic(tier4 1%->3.2%,
//   tier5 4.5%->14.4%)도 같이 오른다 - 예전엔 "3.0은 relic이 3%로 뛰어 희소성이 흔들린다"고 2.4를 골랐지만,
//   그건 그때 relic 구간을 더 키울 이유가 없었기 때문이고 지금은 전설->유물 체감 상승 자체가 목표라 유효하지 않다.
//   장비에 랜덤 옵션이 붙는 다음 단계부터는 같은 등급 안에서도 옵션 조합으로 가치가 갈려 등급 희소성의
//   일부가 옵션 희소성으로 옮겨가므로("원하는 옵션 붙은 유물"은 여전히 희소), 등급 자체의 문턱을 조금 낮추는
//   이번 조정과 방향이 맞는다.
// target이 primordial이거나 해당 tier 표에 아예 없는 등급이면 보정을 걸지 않는다(getBoostedDropTable) -
//   태초는 최종 목표 아이템이라 과하게 풀리지 않도록 항상 대상에서 제외한다(3부위 고대 착용 시에도 보정 없음).
const EQUIPMENT_GRADE_BOOST = { capSteps: 1, weight: 0.15, maxMultiplier: 3.2 };

// 아이템 레벨 계수 (디아블로4식 - 획득 시점 캐릭터 레벨이 아이템에 각인, core/equipment.js
// getItemLevelMultiplier에서 사용) - weaponExpAttackBonusPerLevel(data/balance.js)과 완전히 같은 값을
// 그대로 재사용한다. 둘 다 "사냥만 하면 오르는 축"(getCharacterLevel 참고)에서 갈리는 배율이라
// 레벨25에서 무기 공격력과 아이템 스탯이 똑같이 2.44배로 정점을 찍는 대칭을 만든다.
// 이 계수로 역산한 인접 등급 뒤집힘 레벨차: normal↔rare·rare↔epic(1.4배) 약 8레벨,
// epic↔legendary·legendary↔relic(1.5배) 약 9레벨, relic↔ancient(1.78배) 약 14레벨,
// ancient↔primordial(1.875배) 약 16레벨 - 위 등급일수록 레벨만으로 뒤집기 어렵게 남겨 희소성을 지킨다.
const ITEM_LEVEL_STAT_BONUS_PER_LEVEL = 0.06;

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
