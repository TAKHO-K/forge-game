-- 맵 좌표계(16-6 - 9-4/9-5가 만든 단일 192×192 사냥터를 3×3 tier 구역 맵으로 재설계).
-- 몬스터 격자 간격(64stud)·어그로/리쉬 관계식(0.4s/1.5x)은 15-x가 이미 검증해 둔 값이라
-- 그대로 유지한다(지시 - "격자 간격을 좁히지 마라") - 이번에 바뀌는 건 "그 격자가 어디
-- 있는가"(구역별로 분산)뿐이다.

local PLAYER_WALK_SPEED_STUDS = 16

-- ═══ 구역 하나(tier 구역) 안의 몬스터 격자 - 9-4/15-x 그대로 ═══
local GRID_SPACING_STUDS = 64 -- t=4초 x v=16stud/s, WorldConfig 원본 산식 그대로.
-- 2x2=4마리로 줄인다(지시 "구역당 4~6마리") - 6개 tier 전부 같은 마릿수로 단순화했다.
-- tier마다 다른 수를 주는 건 이번 범위 밖(외형은 크기·색만 다르게 하라는 지시와 같은 결의 절제).
local ZONE_MONSTER_SIDE_COUNT = 2
local ZONE_MONSTER_HALF_SPAN = GRID_SPACING_STUDS * (ZONE_MONSTER_SIDE_COUNT - 1) / 2
local ZONE_EDGE_MARGIN_STUDS = GRID_SPACING_STUDS / 2
local ZONE_HALF_SIZE_STUDS = ZONE_MONSTER_HALF_SPAN + ZONE_EDGE_MARGIN_STUDS -- 64
local ZONE_SIZE_STUDS = ZONE_HALF_SIZE_STUDS * 2 -- 128 - 지시가 제시한 목표치와 정확히 일치.

-- 어그로/리쉬 - 9-4 관계식 그대로(r=0.4s, 리쉬=1.5x). 구역이 넓어졌다고 늘리지 않는다 -
-- 대신 "구역 경계 자체가 리쉬의 진짜 상한"이라는 새 규칙을 MonsterAI.server.lua가
-- 거리 조건과 별도로 검사한다(아래 zones[].halfSize 참고, 지시 그대로).
local AGGRO_RANGE_STUDS = GRID_SPACING_STUDS * 0.4 -- 25.6
local LEASH_RANGE_STUDS = AGGRO_RANGE_STUDS * 1.5 -- 38.4

-- ═══ 3×3 슈퍼그리드(구역들의 배치) ═══
-- 복도 폭은 구역 안 여백과 같은 관례값(32stud)을 재사용한다 - 새 숫자를 만들지 않는다.
local CORRIDOR_WIDTH_STUDS = ZONE_EDGE_MARGIN_STUDS -- 32
local SUPER_GRID_SPACING_STUDS = ZONE_SIZE_STUDS + CORRIDOR_WIDTH_STUDS -- 160

-- 사용자가 확정한 배치표 그대로(16-6):
--   1 tier5 | 2 강화소 | 3 tier6
--   4 tier1 | 5 리스폰 | 6 tier2
--   7 tier3 | 8 커뮤니티 | 9 tier4
-- col/row는 리스폰(원점) 기준 격자 좌표 - world 좌표는 아래서 col/row × SUPER_GRID_SPACING로 뽑는다.
local ZONE_LAYOUT = {
	{ key = "tier5", role = "tier", tierIndex = 5, col = -1, row = -1 },
	{ key = "enhance", role = "enhance", col = 0, row = -1 },
	{ key = "tier6", role = "tier", tierIndex = 6, col = 1, row = -1 },
	{ key = "tier1", role = "tier", tierIndex = 1, col = -1, row = 0 },
	{ key = "spawn", role = "spawn", col = 0, row = 0 },
	{ key = "tier2", role = "tier", tierIndex = 2, col = 1, row = 0 },
	{ key = "tier3", role = "tier", tierIndex = 3, col = -1, row = 1 },
	{ key = "community", role = "community", col = 0, row = 1 },
	{ key = "tier4", role = "tier", tierIndex = 4, col = 1, row = 1 },
}

-- 구역별 몬스터 스폰 슬롯(사냥터 중심 기준이 아니라 그 "구역" 중심 기준) - 기존
-- HuntingGround.server.lua의 monsterSpawnPositions와 같은 산식을, 구역 중심을 인자로 받게
-- 일반화했다.
local function monsterSpawnOffsets()
	local halfSpan = ZONE_MONSTER_HALF_SPAN
	local offsets = {}
	for row = 0, ZONE_MONSTER_SIDE_COUNT - 1 do
		for col = 0, ZONE_MONSTER_SIDE_COUNT - 1 do
			table.insert(offsets, Vector3.new(
				-halfSpan + col * GRID_SPACING_STUDS,
				0,
				-halfSpan + row * GRID_SPACING_STUDS
			))
		end
	end
	return offsets
end

local ZONE_MONSTER_OFFSETS = monsterSpawnOffsets()

local zones = {}
local zoneOrder = {}
for _, entry in ipairs(ZONE_LAYOUT) do
	local center = Vector3.new(entry.col * SUPER_GRID_SPACING_STUDS, 0, entry.row * SUPER_GRID_SPACING_STUDS)
	-- 입구/포탈 도착점/중앙 복귀 패드 위치 - 리스폰(원점)과 구역 중심을 잇는 선분의
	-- 정확히 중점이다. 변 칸(160 이동)이든 대각 칸(160√2 이동)이든 이 중점은 항상 두
	-- 구역 경계 바깥이다(변: 80 vs 각 구역 반너비64, 대각: 각 축 80 vs 96 시작 경계 -
	-- 16-6 세션에서 직접 검산). 리스폰(구역 자체가 없음)엔 입구가 없다.
	local entrance = center * 0.5

	zones[entry.key] = {
		key = entry.key,
		role = entry.role,
		tierIndex = entry.tierIndex,
		center = center,
		halfSize = ZONE_HALF_SIZE_STUDS,
		entrance = entrance,
	}
	table.insert(zoneOrder, entry.key)
end

local tierZoneOrder = {}
for _, key in ipairs(zoneOrder) do
	if zones[key].role == "tier" then
		table.insert(tierZoneOrder, key)
	end
end
table.sort(tierZoneOrder, function(a, b)
	return zones[a].tierIndex < zones[b].tierIndex
end)

return {
	-- 1 stud = 웹 10px(9-1 확정, 변경 없음).
	pxPerStud = 10,

	-- 무한 모드 보스존(15-1/20.31)이 참조하는 값이다 - 이번 지형 재설계와 무관한 별개
	-- 시스템(플레이어별 개인 인스턴스)이라 건드리지 않는다. 실제로 렌더되는 바닥은 더 이상
	-- 없다(9개 구역 바닥으로 대체) - 이 숫자는 오직 BossEncounter.lua의 좌표 계산용
	-- 앵커로만 남는다(리스폰 구역과 같은 원점을 쓰도록 유지 - 기존과 동일한 절대좌표).
	huntingGround = {
		center = Vector3.new(0, 0, 0),
		size = Vector3.new(192, 2, 192),
	},

	zones = zones,
	zoneOrder = zoneOrder,
	tierZoneOrder = tierZoneOrder,

	-- 구역 하나의 물리적 크기 + 안의 몬스터 격자.
	zoneSize = {
		sizeStuds = ZONE_SIZE_STUDS,
		halfSizeStuds = ZONE_HALF_SIZE_STUDS,
	},
	zoneMonsterGrid = {
		spacingStuds = GRID_SPACING_STUDS,
		sideCount = ZONE_MONSTER_SIDE_COUNT,
		offsets = ZONE_MONSTER_OFFSETS, -- 구역 중심 기준 상대 오프셋(XZ, Y=0) 4개.
		count = #ZONE_MONSTER_OFFSETS,
		respawnDelaySeconds = 5,
	},

	-- 어그로/리쉬 - 거리 조건(9-4 그대로) + 구역 소속 조건(16-6 신규, MonsterAI가 둘 다 검사).
	aggro = {
		rangeStuds = AGGRO_RANGE_STUDS,
		leashRangeStuds = LEASH_RANGE_STUDS,
	},

	superGrid = {
		spacingStuds = SUPER_GRID_SPACING_STUDS,
		corridorWidthStuds = CORRIDOR_WIDTH_STUDS,
	},

	-- 강화대(10-2) - 이제 2번 칸(강화소)에 있다. stationOffset은 huntingGround.center(원점)
	-- 기준 오프셋이라는 기존 계약을 그대로 유지한다 - 값만 강화소 구역 중심으로 바꾸면
	-- EnhanceServer.server.lua/EnhanceStation.server.lua/EnhanceUI.client.lua 세 파일은
	-- 전혀 손대지 않아도 된다(전부 huntingGround.center + stationOffset을 그대로 계산).
	enhance = {
		stationOffset = zones.enhance.center,
		interactionRangeStuds = 12,
	},

	-- 땅에 떨어진 아이템(14-1) - 구역 재설계와 무관, 값 변경 없음.
	items = {
		pickupRangeStuds = 2,
		groundLifetimeSeconds = 60,
		pickupDelaySeconds = 0.6,
	},
}
