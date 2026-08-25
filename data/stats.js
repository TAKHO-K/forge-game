// 장비 스탯 레지스트리 (랜덤 옵션 시스템 설계 승인) - 새 스탯을 추가할 때 이 파일에 항목 하나만
// 더하면 core/equipment.js의 getEquipmentBonuses가 자동으로 합산한다. 기존 공식(공격력·치명타·
// 쿨다운 등)에 얹는 스탯은 그 공식을 읽는 지점 한 줄만 더 고치면 끝 - 완전히 새로운 메커니즘
// (예: 라이프스틸처럼 지금 아무 데도 안 읽는 수치)은 소비하는 지점을 새로 만들어야 한다.
//
// appliesAs: "additive"(합산값을 그대로 더함) | "percentPlusOne"(합산값을 1+x 배율로 씀 -
//   기존 attackMultiplier/speedMultiplier와 동일한 구조)
// unit: 툴팁 표시 단위 - "flat"(그대로) | "percent"(x100 후 %) | "seconds"(초)
// optionBase: 랜덤 옵션 값 계수 - optionValue = optionBase × 등급배율 × 아이템레벨계수 × rollFactor
// rollable: false면 랜덤 옵션 풀에서 제외한다. 지금은 aggro/control - 소비하는 코드가 전혀 없어서
//   드랍해도 아무 효과가 없는 "함정 아이템"이 되므로 뺐다. v3 파티 시스템이 생기면 true로 바꾸면 됨.
const STAT_REGISTRY = {
  defenseFlat:   { label: "방어력",        appliesAs: "additive",       unit: "flat",    category: "defense",  optionBase: 0.2 },
  attackPercent: { label: "공격력",        appliesAs: "percentPlusOne", unit: "percent", category: "offense",  optionBase: 0.0145 },
  speedPercent:  { label: "이동·공격속도", appliesAs: "percentPlusOne", unit: "percent", category: "mobility", optionBase: 0.0145 },
  critRate:      { label: "치명타율",      appliesAs: "additive", unit: "percent", category: "crit",    optionBase: 0.00543 },
  critDmg:       { label: "치명타피해",    appliesAs: "additive", unit: "percent", category: "crit",    optionBase: 0.0145 },
  healPower:     { label: "회복량",        appliesAs: "additive", unit: "percent", category: "sustain", optionBase: 0.01087 },
  cooldownReduction:     { label: "스킬 쿨다운 감소", appliesAs: "additive", unit: "percent", category: "cooldown", optionBase: 0.00906 },
  dashCooldownReduction: { label: "대시 쿨다운 감소", appliesAs: "additive", unit: "seconds", category: "cooldown", optionBase: 0.0725 },
  iframeBonus:   { label: "피격 무적시간", appliesAs: "additive", unit: "seconds", category: "defense", optionBase: 0.0181 },
  aggro:   { label: "위협수치", appliesAs: "additive", unit: "flat", category: "party", optionBase: 0, rollable: false },
  control: { label: "제어력",   appliesAs: "additive", unit: "flat", category: "party", optionBase: 0, rollable: false }
};
const STAT_ID_ORDER = Object.keys(STAT_REGISTRY);

// 랜덤 옵션 값 롤 편차 - 같은 등급·스탯이라도 [0.7, 1.3] 범위에서 갈린다(평균 1.0, 좋은 롤/나쁜 롤 둘 다 존재)
const OPTION_ROLL_FACTOR_RANGE = [0.7, 1.3];
