// 던전 정의 (PRD 8.0, 8.0-2) - 순서대로 위→아래 단계 상승. 각 던전은 몬스터 등급 범위와 배경 색조를 가짐
// background.top/bottom은 사냥터 영역(대장간 아래)에 쓰는 세로 그라데이션 색상 (PRD 8.0 배경 테마)
const STAGES = [
  { id: "underground_depths", name: "지하 깊은 곳", tiers: [1, 2, 3], background: { top: "#241224", bottom: "#0d0710" } },
  { id: "underground_cave",   name: "지하 동굴",     tiers: [2, 3, 4], background: { top: "#3a4c4c", bottom: "#1f2b2c" } },
  { id: "ruins",               name: "지상 폐허",     tiers: [3, 4, 5], background: { top: "#4a3a22", bottom: "#2e2414" } },
  { id: "giant_tree",          name: "거대 나무",     tiers: [4, 5, 6], background: { top: "#254a2e", bottom: "#2e2414" } }
];
