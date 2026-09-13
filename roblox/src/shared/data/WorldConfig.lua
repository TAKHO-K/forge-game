-- 맵 좌표계(16-6 - 9-4/9-5가 만든 단일 192×192 사냥터를 3×3 tier 구역 맵으로 재설계).
-- 몬스터 격자 간격(64stud)·어그로/리쉬 관계식(0.4s/1.5x)은 15-x가 이미 검증해 둔 값이라
-- 그대로 유지한다(지시 - "격자 간격을 좁히지 마라") - 이번에 바뀌는 건 "그 격자가 어디
-- 있는가"(구역별로 분산)뿐이다.

local PLAYER_WALK_SPEED_STUDS = 16

-- ═══ 구역 하나(tier 구역) 안의 몬스터 격자 - 9-4/15-x 그대로 ═══
local GRID_SPACING_STUDS = 64 -- t=4초 x v=16stud/s, WorldConfig 원본 산식 그대로.
-- 19-4: "동시에 3~4명이 서로 몬스터를 뺏는 느낌 없이 사냥할 수 있는 밀도" + "8마리 정도"
-- 지시를 3×3=9마리 정사각형 격자로 만족시킨다(2×2=4에서 SIDE_COUNT만 3으로 올린다 -
-- GRID_SPACING_STUDS는 그대로라 "좁히지 마라" 조건을 지킨다). 정확히 8을 만들려면
-- 직사각형 격자(예: 4×2)가 필요한데, 그러면 구역이 정사각형이 아니게 되어 아래 담장·
-- 슈퍼그리드 배치 수식이 전부 "가로/세로 다른 반너비"를 새로 다뤄야 한다 - 늘어난
-- 복잡도 대비 1마리 차이는 그 값어치를 못한다고 판단해 정사각형을 유지했다. 19-4 [2]로
-- 킬 크레딧이 "기여 비율 임계값 이상 전원 지급"으로 바뀌면서 "뺏는 느낌"이 구조적으로
-- 사라졌으므로(같이 때리면 서로 이득), 정확한 밀도 숫자보다 "충분한 수"가 더 중요하다.
local ZONE_MONSTER_SIDE_COUNT = 3
local ZONE_MONSTER_HALF_SPAN = GRID_SPACING_STUDS * (ZONE_MONSTER_SIDE_COUNT - 1) / 2
local ZONE_EDGE_MARGIN_STUDS = GRID_SPACING_STUDS / 2
local ZONE_HALF_SIZE_STUDS = ZONE_MONSTER_HALF_SPAN + ZONE_EDGE_MARGIN_STUDS -- 96(19-4, 이전 64)
local ZONE_SIZE_STUDS = ZONE_HALF_SIZE_STUDS * 2 -- 192(19-4, 이전 128) - SIDE_COUNT 3으로 자동 반영.

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
	-- 정확히 중점이다. entrance - half = center*0.5 - half가 항상 16(=GRID_SPACING/4)로
	-- 양수라(SUPER_GRID_SPACING=ZONE_SIZE+CORRIDOR_WIDTH, CORRIDOR_WIDTH=EDGE_MARGIN 관계
	-- 덕분에 ZONE_HALF_SIZE_STUDS 값이 바뀌어도 이 마진은 항상 유지된다 - 19-4에서
	-- SIDE_COUNT를 2->3으로 올려 64->96이 됐을 때도 재검산으로 확인) 변 칸이든 대각 칸이든
	-- 이 중점은 항상 두 구역 경계 바깥이다. 리스폰(구역 자체가 없음)엔 입구가 없다.
	local entrance = center * 0.5

	-- 담장 입구(19-4 [4]) - 4면 중 스폰 쪽을 향한 한 면에만 문을 낸다. 변 칸(col 또는 row
	-- 하나만 0이 아님)은 그 축이 곧 답이다. 대각 칸(툴 다 0이 아님, tier3~6)은 스폰까지
	-- 거리가 X축·Z축 벽 어느 쪽이든 기하학적으로 완전히 같아(45도 대칭) 어느 쪽으로 내도
	-- 틀리지 않는다 - X축으로 통일한다(임의 선택, 일관성이 유일한 기준).
	local gate = nil
	if entry.col ~= 0 then
		gate = { axis = "x", sign = entry.col > 0 and -1 or 1 }
	elseif entry.row ~= 0 then
		gate = { axis = "z", sign = entry.row > 0 and -1 or 1 }
	end

	zones[entry.key] = {
		key = entry.key,
		role = entry.role,
		tierIndex = entry.tierIndex,
		center = center,
		halfSize = ZONE_HALF_SIZE_STUDS,
		entrance = entrance,
		gate = gate, -- role~="tier"면 담장을 안 세우니 안 쓰지만, spawn(col=row=0)만 nil이다.
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
		offsets = ZONE_MONSTER_OFFSETS, -- 구역 중심 기준 상대 오프셋(XZ, Y=0) 9개(19-4, 이전 4개).
		count = #ZONE_MONSTER_OFFSETS,
		-- 19-4 [5] "재검토" 결과 - 5초 유지. 마릿수(4->9, +125%)가 이미 "동시 사냥꾼 3~4명"
		-- 가정과 같은 비율로 공급을 늘렸으므로(빈 슬롯/초 = count/respawnDelay, 4/5=0.8 ->
		-- 9/5=1.8, +125%로 정확히 같은 비율) 마릿수 증가 자체가 수요 증가를 상쇄한다 - 시간
		-- 값을 따로 더 줄일 근거가 없다(근거 없이 숫자만 바꾸지 않는다).
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

	-- 안전지대 물리 담장(19-4 [4]-가). tier 구역에만 세운다(몬스터가 있는 곳만 봉쇄가
	-- 필요하다 - enhance/community는 원래도 몬스터가 없다). 높이 12stud는 로블록스 기본
	-- 점프 정점(약 7~8stud)보다 확실히 높게 잡아 대시·점프로도 못 넘게 하면서(지시 "대시로도
	-- 못 넘게"), 3인칭 카메라(PRD 20.14 - 이 지도는 탑다운이 아니다)를 가리지 않는 선(기존
	-- 장식용 BoundaryPillar가 이미 10stud라 비슷한 높이감)에서 잡았다. 문 너비 12stud는
	-- 플레이어 하나가 편하게 지나갈 폭(캐릭터 폭 약 4stud의 3배) + 몬스터가 추격 중 좁은
	-- 문틀에 낌 없이 빠져나갈 여유다.
	walls = {
		heightStuds = 12,
		thicknessStuds = 2,
		doorwayWidthStuds = 12,
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
