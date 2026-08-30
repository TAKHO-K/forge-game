-- 사냥터 좌표계·환산 기준. 밸런스 수식(감소율·등급 배율 등)은 여기 없다 - 그건 전투가 생길 때 넣는다.

-- 격자 간격 s = 목표 이동 시간 t × 플레이어 이동 속도 v.
-- v=16은 StarterPlayer.CharacterWalkSpeed 기본값(이번 세션에 Studio에서 직접 조회해 확인,
-- 이 프로젝트 어디서도 커스텀 설정하지 않음).
-- t=4초로 잡은 이유: 몬스터가 정지해 있던 이전 원형 배치(반지름30, 8마리)는 인접 몬스터
-- 사이 이동 시간이 약 1.4초였는데, 추격이 붙으면 몬스터도 플레이어 쪽으로 다가오기 때문에
-- 실제 체감 시간은 이보다 더 짧아진다 - 정지 기준으로 여유를 크게 잡아야 실전에서
-- 너무 촘촘해지지 않는다. t=4초 → s=64stud는 사용자가 다른 로블록스 게임 기준으로
-- "감이 맞다"고 판단한 원래 원 지름(60stud)과 거의 일치해 검증됐다.
local PLAYER_WALK_SPEED_STUDS = 16
local TARGET_APPROACH_SECONDS = 4
local GRID_SPACING_STUDS = TARGET_APPROACH_SECONDS * PLAYER_WALK_SPEED_STUDS

-- 3x3=9마리. count를 8에 고정하지 않고 격자 한 변 마리 수에서 유도한다.
local GRID_SIDE_COUNT = 3

-- 격자 바깥 여백 = s/2. 격자 가장자리 몬스터의 리쉬(38.4stud, 아래 aggro 참고)가
-- 바닥 밖으로 새지 않을 만큼 여유를 두면서, 간격 자체와 비례해 마리 수가 바뀌어도
-- 자동으로 맞는 값이 되도록 s에서 유도했다.
local EDGE_MARGIN_STUDS = GRID_SPACING_STUDS / 2

-- 격자가 차지하는 한 변 길이의 절반. 예: 3마리면 간격 2칸(=2s)의 절반 = s만큼
-- 중심에서 바깥쪽 줄까지 떨어진다.
local HALF_SPAN_STUDS = GRID_SPACING_STUDS * (GRID_SIDE_COUNT - 1) / 2
local FLOOR_HALF_SIZE_STUDS = HALF_SPAN_STUDS + EDGE_MARGIN_STUDS
local FLOOR_SIZE_STUDS = FLOOR_HALF_SIZE_STUDS * 2

-- 플레이어 스폰은 바닥 가장자리에 붙이되, 스폰 파트(6stud 정사각형, 반폭 3)가
-- 바닥 밖으로 안 나가도록 반폭만큼 안쪽으로 뺀다.
local SPAWN_PART_HALF_SIZE_STUDS = 3
local PLAYER_SPAWN_Z = -(FLOOR_HALF_SIZE_STUDS - SPAWN_PART_HALF_SIZE_STUDS)

return {
	-- 1 stud = 웹 10px. 기준: 로블록스 기본 캐릭터(R15) 너비 약 4stud(반지름 2stud) vs
	-- 웹 playerRadius=20px(지름 40px) -> 40px/4stud = 10px/stud.
	-- 사거리·투사체 속도 등 나머지 픽셀 값은 지금 환산하지 않는다. 이 비율만 기록해 둔다.
	pxPerStud = 10,

	huntingGround = {
		center = Vector3.new(0, 0, 0),
		size = Vector3.new(FLOOR_SIZE_STUDS, 2, FLOOR_SIZE_STUDS),
	},

	-- 사냥터 중심 기준 XZ 오프셋. Y는 스크립트가 바닥 위 높이로 계산한다.
	-- 가장 가까운 앞줄 몬스터(집 위치 기준 s만큼 떨어짐)까지 거리는
	-- FLOOR_HALF_SIZE_STUDS - HALF_SPAN_STUDS = EDGE_MARGIN_STUDS(32stud)로,
	-- 어그로 범위(25.6stud)보다 넉넉히 밖이라 스폰 직후 바로 어그로가 붙지 않는다.
	--
	-- [미결, 9-4] 여유가 3.4stud(0.2초)뿐이라 사실상 부활 직후 어그로가 붙는다. 방금 고친
	-- "죽은 뒤 리쉬가 안 풀리는" 버그와 같은 계열이지만 반대쪽 - 이건 "부활 직후"를 안 본다.
	-- 지금은 몬스터가 약해 죽기 전에 도망칠 시간이 있어 안 터지지만, 더 강한 몬스터가
	-- 이 사냥터에 들어오면 "부활 -> 즉시 어그로 -> 즉사 -> 부활" 루프가 생긴다. 강화 맵과
	-- 사냥 맵을 물리적으로 분리하기로 이미 정했으니 그때 근본 해결되지만, 그 전에 강한
	-- 몬스터가 먼저 들어오면 터진다.
	playerSpawnOffset = Vector3.new(0, 0, PLAYER_SPAWN_Z),

	-- 몬스터 배치: 사냥터 중심 기준 격자 균등 배치. 원형 배치는 중심에 있으면 모든 몬스터가
	-- 등거리라 이동 방향에 우열이 없고, 가운데만 붐비고 가장자리가 비어 맵을 절반도 못 쓰는
	-- 문제가 있었다. 격자는 간격(s)과 맵 크기가 위 관계식으로 묶여 있어 마리 수를 늘리거나
	-- 이동 속도 상품이 생겨도 배치가 자동으로 따라온다.
	spawns = {
		gridSpacingStuds = GRID_SPACING_STUDS,
		gridSideCount = GRID_SIDE_COUNT,
		count = GRID_SIDE_COUNT * GRID_SIDE_COUNT,
		respawnDelaySeconds = 5,
	},

	-- 어그로 범위 r < s/2 조건을 지키면, 플레이어가 한 마리의 범위에 들어가는 순간
	-- 이웃 격자점(거리 s)의 몬스터는 아직 범위 밖이라 여러 마리가 동시에 달려드는 상황이
	-- 구조적으로 불가능하다. r = 0.4s로 잡아 이론 상한(0.5s) 대비 20% 안전 여유를 뒀다 -
	-- 나중에 광역 스킬이 생겨도 "동시 어그로 금지" 같은 조건문을 따로 안 둬도 된다.
	-- 리쉬 범위(집에서 이 거리 이상 벌어지면 추격을 포기하고 돌아간다)는 어그로 범위의
	-- 1.5배로, 플레이어가 살짝 끌어내는 것은 허용하되 옆 칸 몬스터의 집 자리(거리 s)까지
	-- 침범하지 않게 잡았다.
	aggro = {
		rangeStuds = GRID_SPACING_STUDS * 0.4,
		leashRangeStuds = GRID_SPACING_STUDS * 0.4 * 1.5,
	},
}
