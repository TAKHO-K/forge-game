// 강화 계수표 · 확률표 (PRD 6장)

const ENHANCE_MAX_LEVEL = 25;

// 상급 강화 계수 (6.2-1) - 성공률 배율, 상한
const ENHANCE_HIGH_SUCCESS_MULTIPLIER = 1.5;
const ENHANCE_HIGH_SUCCESS_CAP = 0.90;
const ENHANCE_HIGH_COST_MULTIPLIER = 5;

// 강화 비용표 (6.2-2, 테스트용) - index는 시도 전 현재 강화 단계, 값은 일반 강화 골드 비용
const ENHANCE_GOLD_COST = [
  10, 20, 30, 40, 50,                      // +0~+4 -> +1~+5
  100, 150, 200, 250, 300,                 // +5~+9 -> +6~+10
  400, 500, 700, 850, 1000,                // +10~+14 -> +11~+15
  1500, 2000, 2600, 3300, 4100,            // +15~+19 -> +16~+20
  5000, 6500, 8500, 11000, 14000           // +20~+24 -> +21~+25
];

// 강화 단계별 데미지 계수 (6.1) - index는 강화 단계, 값은 기본 대비 누적 증가분
const ENHANCE_DAMAGE_COEFFICIENT = [
  0,                                       // +0
  0.10, 0.20, 0.30, 0.40, 0.50,            // +1~+5
  0.70, 0.90, 1.10, 1.30, 1.50,            // +6~+10
  1.90, 2.30, 2.70, 3.10, 3.50,            // +11~+15
  4.30, 5.10, 5.90, 6.70, 7.50,            // +16~+20
  9.10, 10.70, 12.30, 13.90, 15.50         // +21~+25
];

// 확률 강화권 3종 (재료 몬스터 드랍) - 실제 강화 시도에 적용, 상급 강화·서로 간 중복 불가
// 소/중은 상급 강화와 같은 배율+상한 방식, 대는 성공률을 50%로 고정
const ENHANCE_TICKET_BOOST = {
  small:  { multiplier: 1.5, cap: ENHANCE_HIGH_SUCCESS_CAP },
  medium: { multiplier: 2.0, cap: ENHANCE_HIGH_SUCCESS_CAP },
  large:  { fixedSuccess: 0.5 }
};

// 강화 확률표 (6.2) - index는 시도 전 현재 강화 단계. 실패는 형상유지/-1강/-2강/리셋 4종
const ENHANCE_PROBABILITY = [
  { success: 0.92, maintain: 0.08, down1: 0,    down2: 0,    reset: 0 },    // +0 -> +1
  { success: 0.92, maintain: 0.08, down1: 0,    down2: 0,    reset: 0 },    // +1 -> +2
  { success: 0.92, maintain: 0.08, down1: 0,    down2: 0,    reset: 0 },    // +2 -> +3
  { success: 0.92, maintain: 0.08, down1: 0,    down2: 0,    reset: 0 },    // +3 -> +4
  { success: 0.92, maintain: 0.08, down1: 0,    down2: 0,    reset: 0 },    // +4 -> +5
  { success: 0.78, maintain: 0.12, down1: 0.10, down2: 0,    reset: 0 },    // +5 -> +6
  { success: 0.78, maintain: 0.12, down1: 0.10, down2: 0,    reset: 0 },    // +6 -> +7
  { success: 0.78, maintain: 0.12, down1: 0.10, down2: 0,    reset: 0 },    // +7 -> +8
  { success: 0.62, maintain: 0.13, down1: 0.25, down2: 0,    reset: 0 },    // +8 -> +9
  { success: 0.62, maintain: 0.13, down1: 0.25, down2: 0,    reset: 0 },    // +9 -> +10
  { success: 0.62, maintain: 0.13, down1: 0.25, down2: 0,    reset: 0 },    // +10 -> +11
  { success: 0.48, maintain: 0.12, down1: 0.30, down2: 0.10, reset: 0 },    // +11 -> +12
  { success: 0.48, maintain: 0.12, down1: 0.30, down2: 0.10, reset: 0 },    // +12 -> +13
  { success: 0.48, maintain: 0.12, down1: 0.30, down2: 0.10, reset: 0 },    // +13 -> +14
  { success: 0.38, maintain: 0.12, down1: 0.32, down2: 0.17, reset: 0.01 }, // +14 -> +15
  { success: 0.38, maintain: 0.12, down1: 0.32, down2: 0.17, reset: 0.01 }, // +15 -> +16
  { success: 0.38, maintain: 0.12, down1: 0.32, down2: 0.17, reset: 0.01 }, // +16 -> +17
  { success: 0.28, maintain: 0.10, down1: 0.35, down2: 0.26, reset: 0.01 }, // +17 -> +18
  { success: 0.28, maintain: 0.10, down1: 0.35, down2: 0.26, reset: 0.01 }, // +18 -> +19
  { success: 0.28, maintain: 0.10, down1: 0.35, down2: 0.26, reset: 0.01 }, // +19 -> +20
  { success: 0.18, maintain: 0.08, down1: 0.38, down2: 0.34, reset: 0.02 }, // +20 -> +21
  { success: 0.18, maintain: 0.08, down1: 0.38, down2: 0.34, reset: 0.02 }, // +21 -> +22
  { success: 0.18, maintain: 0.08, down1: 0.38, down2: 0.34, reset: 0.02 }, // +22 -> +23
  { success: 0.12, maintain: 0.05, down1: 0.38, down2: 0.42, reset: 0.03 }, // +23 -> +24
  { success: 0.12, maintain: 0.05, down1: 0.38, down2: 0.42, reset: 0.03 }  // +24 -> +25
];
