// 직업 정의 (PRD 4장) - v1 딜러 3종 + 힐러. 스킬(Q/E)은 다음 단계에서 추가, 힐러 딜링모드(E)만 예외로 이번에 포함
// healPower/aggro/control은 v3(파티) 전용 장비 특화 스탯 자리 - v1에서는 항상 0
// attackType: "melee"(전방 부채꼴, meleeRange/meleeArc 사용) | "ranged"(투사체, core/render.js drawProjectiles)
// meleeRange(px)·meleeArc(도)는 PRD에 수치가 없어 임시값 - 이 파일만 고치면 밸런스 조정 끝
// alternateSides: true면 근접 공격마다 판정 중심이 좌우로 번갈아 치우침 (쌍검), alternateOffsetDegrees가 치우치는 각도
// rangeBonusScale: 강화 사거리 마일스톤(6.1-1, data/enhance.js ENHANCE_VISUAL_MILESTONES)의 배분 배율.
//   PRD가 "활은 +30%(근접은 폭이 작다)"라고만 정해서, 명시된 활만 1.5배, 근접은 그 절반인 0.5배로
//   설정했다(설계 승인) - 힐러는 원거리지만 PRD가 별도 언급을 안 해서 기본값 1.0을 그대로 씀.
const CLASSES = {
  greatsword: {
    id: "greatsword", name: "대검",
    atk: 1.6, atkSpeed: 0.6, def: 1.3,
    critRate: 0.10, critDmg: 1.8,
    attackType: "melee", meleeRange: 100, meleeArc: 70, rangeBonusScale: 0.5,
    healPower: 0, aggro: 0, control: 0
  },
  dualblade: {
    id: "dualblade", name: "쌍검",
    atk: 0.75, atkSpeed: 1.35, def: 1.0,
    critRate: 0.25, critDmg: 1.6,
    attackType: "melee", meleeRange: 70, meleeArc: 110, rangeBonusScale: 0.5,
    alternateSides: true, alternateOffsetDegrees: 25,
    healPower: 0, aggro: 0, control: 0
  },
  bow: {
    id: "bow", name: "활",
    atk: 2.0, atkSpeed: 0.65, def: 0.6,
    critRate: 0.15, critDmg: 2.6,
    attackType: "ranged", rangeBonusScale: 1.5,
    healPower: 0, aggro: 0, control: 0
  },
  // 딜링모드(E): 최대체력 dealModeHpCost칸 소모, dealModeDuration초간 지속 - 지금은 온/오프 전환만, 공격력 배율은 없음
  // 회복량 계수 시스템이 붙는 다음 단계에서 딜링모드 중 효과(회복량 계수 기반 딜 환산)를 추가할 예정
  healer: {
    id: "healer", name: "힐러",
    atk: 0.6, atkSpeed: 1.25, def: 1.0,
    critRate: 0.12, critDmg: 1.8,
    attackType: "ranged",
    dealModeDuration: 15, dealModeHpCost: 1,
    healPower: 0, aggro: 0, control: 0
  }
};
const CLASS_ORDER = ["greatsword", "dualblade", "bow", "healer"];
