// 몬스터 종류별 데이터 (PRD 8.1) - 6등급 x 유형(물몸형/탱커형/재료형) 조합, 총 15종
// 유형 성향: 물몸형(체력·방어 낮음, 골드 적음, aggroRange 180) / 탱커형(체력·방어 높음, 골드 많음, aggroRange 320) / 재료형(방어 중간, 골드 적음, aggroRange 250)
// weaponExp: 경험치 토큰(PRD 7.1-1) 기본값의 기준. 임시로 goldDrop의 절반 수준, 추후 재조정
// dropChance: 장비 드랍 판정(PRD 7.1) 슬롯1 확률. 전 몬스터 공통 임시값, 추후 재조정
const MONSTERS = {
  // 1등급
  larva_soft: { tier: 1, hp: 40,  defense: 0,   attack: 3,  radius: 12, color: "#a8e6a3", goldDrop: 4,  weaponExp: 2,   aggroRange: 180, dropChance: 0.25 }, // 말랑꼬물이 (물몸형)
  larva_tank: { tier: 1, hp: 90,  defense: 4,   attack: 4,  radius: 16, color: "#6f9e4c", goldDrop: 8,  weaponExp: 4,   aggroRange: 320, dropChance: 0.25 }, // 딱딱꼬물이 (탱커형)

  // 2등급
  slime_soft: { tier: 2, hp: 150, defense: 3,   attack: 7,  radius: 16, color: "#66cc99", goldDrop: 12, weaponExp: 6,   aggroRange: 180, dropChance: 0.25 }, // 물렁슬라임 (물몸형)
  slime_tank: { tier: 2, hp: 340, defense: 10,  attack: 9,  radius: 21, color: "#3f8e5c", goldDrop: 24, weaponExp: 12,  aggroRange: 320, dropChance: 0.25 }, // 찐득슬라임 (탱커형)

  // 3등급
  goblin_soft: { tier: 3, hp: 550,  defense: 12, attack: 13, radius: 19, color: "#7fbf5f", goldDrop: 28, weaponExp: 14, aggroRange: 180, dropChance: 0.25 }, // 여린고블린 (물몸형)
  goblin_tank: { tier: 3, hp: 1400, defense: 35, attack: 17, radius: 26, color: "#4a7a2e", goldDrop: 65, weaponExp: 30, aggroRange: 320, dropChance: 0.25 }, // 굳센고블린 (탱커형)
  goblin_mat:  { tier: 3, hp: 800,  defense: 20, attack: 11, radius: 22, color: "#b8935c", goldDrop: 20, weaponExp: 10, aggroRange: 250, dropChance: 0.25 }, // 채집고블린 (재료형)

  // 4등급
  orc_soft: { tier: 4, hp: 2000, defense: 40,  attack: 22, radius: 23, color: "#e0a25c", goldDrop: 70,  weaponExp: 35, aggroRange: 180, dropChance: 0.25 }, // 날쌘오크 (물몸형)
  orc_tank: { tier: 4, hp: 5200, defense: 105, attack: 28, radius: 30, color: "#a85f26", goldDrop: 160, weaponExp: 80, aggroRange: 320, dropChance: 0.25 }, // 육중오크 (탱커형)
  orc_mat:  { tier: 4, hp: 3000, defense: 60,  attack: 19, radius: 26, color: "#c98f3d", goldDrop: 55,  weaponExp: 28, aggroRange: 250, dropChance: 0.25 }, // 채굴오크 (재료형)

  // 5등급
  troll_soft: { tier: 5, hp: 8000,  defense: 100, attack: 36, radius: 27, color: "#a97fc9", goldDrop: 170, weaponExp: 85,  aggroRange: 180, dropChance: 0.25 }, // 민첩트롤 (물몸형)
  troll_tank: { tier: 5, hp: 21000, defense: 270, attack: 46, radius: 35, color: "#6a3f8e", goldDrop: 400, weaponExp: 200, aggroRange: 320, dropChance: 0.25 }, // 거대트롤 (탱커형)
  troll_mat:  { tier: 5, hp: 12000, defense: 150, attack: 32, radius: 30, color: "#7fae7f", goldDrop: 130, weaponExp: 65,  aggroRange: 250, dropChance: 0.25 }, // 약초트롤 (재료형)

  // 6등급
  dragon_tank: { tier: 6, hp: 80000, defense: 550, attack: 70, radius: 40, color: "#e0505c", goldDrop: 900, weaponExp: 450, aggroRange: 320, dropChance: 0.25 }, // 폭군드래곤 (탱커형)
  dragon_mat:  { tier: 6, hp: 50000, defense: 400, attack: 55, radius: 36, color: "#4fa3c9", goldDrop: 500, weaponExp: 250, aggroRange: 250, dropChance: 0.25 }  // 비늘드래곤 (재료형)
};

// 보스 데이터 (PRD 9.1, 9.5, 9.6) - 단계 순서 배열, index 0부터 1단계
// clearGoldReward: 기본보상(9.5, 등급배율 곱하기 전). 확정 강화권은 클리어마다 BALANCE.bossGuaranteedTicketChance 확률로 +1 지급(9.6)
const BOSSES = [
  { name: "고블린왕", hp: 4000, defense: 8, attack: 20, timeLimit: 60, radius: 45, color: "#c9a227", // hp/defense 테스트용 임시값 - 나중에 재조정
    clearGoldReward: 3000 },
  { name: "오크로드", hp: 80000, defense: 80, attack: 30, timeLimit: 75, radius: 50, color: "#8b3a1a",
    clearGoldReward: 8000 }
];

// 배치 순서 (등급 낮은 순 - 맵 왼쪽부터 배치될 순서와 맞춤)
const MONSTER_ORDER = [
  "larva_soft", "larva_tank",
  "slime_soft", "slime_tank",
  "goblin_soft", "goblin_tank", "goblin_mat",
  "orc_soft", "orc_tank", "orc_mat",
  "troll_soft", "troll_tank", "troll_mat",
  "dragon_tank", "dragon_mat"
];
