// 어그로 대상 추상화 (PRD 19.2/19.3 재사용 대비) - 몬스터가 "누구를 쫓을지"를
// player 하드코딩 대신 이 함수로 물어보게 한다. 상태(activeTaunt)는 main.js가 들고
// 있고 여기는 순수 함수만 둔다 - core/의 다른 파일들과 같은 방식.

// 도발원 생성 - v1은 최대 1개, 새 도발이 이전 것을 덮어쓴다.
// v3에서 파티원 여러 명이 동시에 도발하면 목록+우선순위로 바꿔야 하는 지점.
function createTaunt(x, y, radius, duration) {
  return { x, y, radius, timer: duration };
}

// 매 프레임 호출 - 만료되면 null
function tickTaunt(taunt, dt) {
  if (!taunt) return null;
  const timer = taunt.timer - dt;
  return timer > 0 ? { x: taunt.x, y: taunt.y, radius: taunt.radius, timer } : null;
}

// 몬스터가 쫓을 좌표 - 도발원이 있으면 그쪽, 없으면 플레이어.
// v1은 사냥터 몬스터에만 연결한다 - 보스 루프는 의도적으로 이 함수를 호출하지 않는다.
// 근거: 쌍검 Q(쿨14초/지속5초)를 보스에도 먹이면 보스전 시간의 35%를 무피해로
// 만들어 v1 보스 밸런스가 쌍검에게만 무너지고, 1차 개발의 "재미 검증" 기준이
// 오염된다. PRD 19.3의 "보스 도발 면역"과 방향이 같다 - 지금은 "호출하지 않음"
// 으로 면역을 표현하고, 19.3을 실제로 구현할 때 보스 루프에도 이 함수를 연결하며
// 면역 타이머 체크를 여기 추가하는 게 자연스러운 확장점이다.
function resolveAggroTarget(playerX, playerY, playerRadius, taunt) {
  if (taunt) return { x: taunt.x, y: taunt.y, radius: taunt.radius, isPlayer: false };
  return { x: playerX, y: playerY, radius: playerRadius, isPlayer: true };
}
