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
-- 22-5(PRD 20.49 [3]): 외곽 슬롯~담장 여백을 격자 절반(32)에서 격자 하나(64)로. 여백이 리쉬
-- (38.4)를 넘어야 담장 안쪽에 몬스터가 절대 못 오는 "장식 띠"(여백 - 리쉬 = 25.6)가 생긴다 -
-- 급경사·오두막·바위 같은 키 큰 지형은 전부 이 띠에만 둔다(ZoneTerrain이 배치 시점에 강제).
-- 이 조건을 만족하는 첫 격자 배수가 64. 슬롯 격자·어그로·리쉬는 그대로다(핵심부 밀도 불변).
local ZONE_EDGE_MARGIN_STUDS = GRID_SPACING_STUDS
local ZONE_HALF_SIZE_STUDS = ZONE_MONSTER_HALF_SPAN + ZONE_EDGE_MARGIN_STUDS
local ZONE_SIZE_STUDS = ZONE_HALF_SIZE_STUDS * 2

-- 어그로/리쉬 - 9-4 관계식 그대로(r=0.4s, 리쉬=1.5x). 구역이 넓어졌다고 늘리지 않는다 -
-- 대신 "구역 경계 자체가 리쉬의 진짜 상한"이라는 새 규칙을 MonsterAI.server.lua가
-- 거리 조건과 별도로 검사한다(아래 zones[].halfSize 참고, 지시 그대로).
local AGGRO_RANGE_STUDS = GRID_SPACING_STUDS * 0.4 -- 25.6
local LEASH_RANGE_STUDS = AGGRO_RANGE_STUDS * 1.5 -- 38.4

-- ═══ 3×3 슈퍼그리드(구역들의 배치) ═══
-- 복도 폭은 격자 절반(32stud)이다. 22-5 전까지는 ZONE_EDGE_MARGIN_STUDS(당시 32)를 재사용했지만
-- 여백이 64로 오르면서 복도까지 넓어지면 안 되므로(걷는 시간만 늘어난다) 격자에서 직접 유도한다.
-- 입구 마진(entrance - half = SUPER/2 - HALF = CORRIDOR/2 = 16)은 이 식에서 그대로 나온다.
local CORRIDOR_WIDTH_STUDS = GRID_SPACING_STUDS / 2
local SUPER_GRID_SPACING_STUDS = ZONE_SIZE_STUDS + CORRIDOR_WIDTH_STUDS
-- M1: 옛 맵 한 변(3×3) · 스트리밍 권장값(24-5 - 600, Studio 수동)은 WorldMapData(세계 반지름 · streaming)로 옮겼다. 스트리밍 속성은 이제 default.project.json(Workspace)으로 git에 있다.

-- ═══ 유도값 한눈에(22-5) - 숫자를 주석에 박아 두면 값이 바뀔 때 주석이 남는다(20.49 실측에서
-- "슈퍼그리드 160" 주석이 실제 224였다). 그래서 이 파일의 주석은 식만 적고, 실제 숫자는
-- HuntingGround.server.lua가 부팅 로그에 찍는다(derived 테이블). 식은 다음과 같다:
--   구역 = 2 × (격자 + 여백)          / 슈퍼그리드 = 구역 + 복도     / 맵 = 3 × 슈퍼그리드 - 복도
--   담장 안쪽 안전 띠 = 여백 - 리쉬    / 입구 마진 = 복도 / 2          / 변 칸 문까지 = 슈퍼그리드/2 - 여백 + 격자

-- M1(맵 확장 그레이박스): 옛 3×3 배치표(16-6)를 큰 세계(반지름 약 3,000 · 원점 = 허브 "큰 나무 마을")로 바꿨다. 구역 자리 · 크기의 단일 출처 =
-- data/WorldMapData(+ shared/WorldMapLayout 식). 여기서는 옛 계약(zones[key] · zoneOrder · tierZoneOrder · enhance · rebirthAltar · gemMerchant)을 그 값으로 채운다.
--   spawn = 허브(원 - 잎 덮개 반경) · tierN = 꽃잎 구역(원 - 구역 원 · entrance = 입구 캠프) · enhance / community = 허브 시설 자리(구역 아님 - zoneOrder에 없다).
local WorldMapData = require(script.Parent.WorldMapData)
local function hubPoint(angleDeg, r)
	local a = math.rad(angleDeg)
	return Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
end

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
do
	local hub = WorldMapData.hub
	-- arrival = 허브로 돌아오는 자리(리스폰 · 보스전 뒤 · 심연 복귀 · 귀환) - 중심(0, 0, 0)은 나무 줄기 안이다.
	zones[hub.key] = { key = hub.key, role = "spawn", displayName = hub.displayName, center = Vector3.new(0, 0, 0), radius = hub.safeRadius, halfSize = hub.safeRadius,
		arrival = hubPoint(hub.spawn.angleDeg, hub.spawn.r) }
	table.insert(zoneOrder, hub.key)
	local forge, community = hub.facilities.forge, hub.facilities.community
	zones.enhance = { key = "enhance", role = "enhance", displayName = forge.displayName, center = hubPoint(forge.angleDeg, forge.r) }
	zones.community = { key = "community", role = "community", displayName = community.displayName, center = hubPoint(community.angleDeg, community.r) }
	local L = WorldMapData.layout
	for _, z in ipairs(WorldMapData.zones) do
		local a = math.rad(z.angleDeg)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local side = Vector3.new(-math.sin(a), 0, math.cos(a))
		zones[z.key] = {
			key = z.key,
			role = "tier",
			tierIndex = z.tierIndex,
			displayName = z.theme,
			center = dir * L.regionCenterR,
			radius = L.regionRadius, -- 원(ArenaShape) - 몬스터 리쉬 상한 · 구역 소속 · 결계가 같은 원
			halfSize = L.regionRadius,
			entrance = dir * L.camp.r + side * L.camp.lat, -- 입구 캠프(심연 복귀 · 포탈 도착)
			bossId = z.bossId,
		}
		table.insert(zoneOrder, z.key)
	end
end

-- 보스 전용 격리 아레나(20-2b) - "맵 중앙에 보스가 스폰된다"는 버그 수정. 원인은
-- StageServer.server.lua의 접속 시 복원이 "플레이어 20stud 앞"을 캐릭터가 막 스폰된
-- 직후 위치(=사실상 리스폰 구역) 기준으로 계산했고, 보스에게 zoneKey가 없어 구역 경계
-- 리쉬 자체가 안 걸렸던 것(38.4stud 리쉬 거리만 봤다)이 겹친 결과다. 위 3×3 슈퍼그리드
-- (±MAP_SIZE/2)와 절대 겹치지 않는 먼 곳에 서버 정원만큼(12명, PRD-forge-game-roblox.md
-- 20.38 [6]) 슬롯을 미리 만들어 둔다 - BossEncounter.lua가 인원마다 하나씩 배정하고
-- 퇴장하면 반납해 다음 사람이 재사용한다. zones[key]엔 등록하되 zoneOrder에는 일부러
-- 안 넣는다(아래 for문 뒤 주석 참고) - HuntingGround.server.lua가 zoneOrder를 순회하며
-- 세우는 사냥터 바닥·지형이 아레나 위치까지 따라와 겹치는 걸 막는다. 벽(문 없는 완전
-- 밀폐)은 BossEncounter.lua가 직접 세운다.
local BOSS_ARENA_SLOT_COUNT = 12
-- P3a C: 아레나가 원이 됐다(BossArenaMapData.geometry - 반경 120 · 옛 정사각형 반폭 96). zones[key].radius가 있으면 원이다(shared/ArenaShape).
-- halfSize는 원을 감싸는 정사각형 반폭(= 반경)으로 남긴다 - 반폭을 "크기"로만 읽는 옛 코드가 원의 크기를 읽는다.
local BossArenaMapData = require(script.Parent.BossArenaMapData)
local BOSS_ARENA_RADIUS_STUDS = BossArenaMapData.geometry.radiusStuds
local BOSS_ARENA_HALF_SIZE_STUDS = BOSS_ARENA_RADIUS_STUDS
local BOSS_ARENA_BASE_Z_STUDS = -3500 -- M1: 세계 끝(반경 2960 벽 + 능선 44) 밖 - 옛 -3000은 새 세계 끝과 겹친다
-- 슬롯끼리 안 겹치는 간격 = 벽 · 테라스까지의 지름 + 여유.
local BOSS_ARENA_SPACING_STUDS = (BOSS_ARENA_RADIUS_STUDS + BossArenaMapData.geometry.wallThicknessStuds + BossArenaMapData.geometry.rimWidthStuds) * 2
	+ BossArenaMapData.geometry.slotSpacingExtraStuds

-- zoneOrder에는 일부러 안 넣는다 - HuntingGround.server.lua가 zoneOrder를 순회하며 바닥·
-- 경계 장식을 자동으로 세우는데(각 구역에 맞는 스폰/문 배치 전제), 그 로직을 그대로 타면
-- 아레나 위치에 엉뚱한 사냥터 장식이 겹쳐 생긴다. 보스 아레나는 zones[key]로 직접 조회만
-- 하는 별도 계통이라(BossEncounter.lua), zoneOrder 순회 대상일 필요가 없다.
for i = 1, BOSS_ARENA_SLOT_COUNT do
	local key = "bossArena" .. i
	zones[key] = {
		key = key,
		role = "bossArena",
		center = Vector3.new(0, 0, BOSS_ARENA_BASE_Z_STUDS - (i - 1) * BOSS_ARENA_SPACING_STUDS),
		halfSize = BOSS_ARENA_HALF_SIZE_STUDS, -- 걸어 들어오는 문이 없다 - BossEncounter.lua가 텔레포트로만 입장시킨다.
		radius = BOSS_ARENA_RADIUS_STUDS, -- P3a C: 원형 아레나(ArenaShape)
	}
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
	playerWalkSpeedStuds = PLAYER_WALK_SPEED_STUDS, -- 걷는 시간 계산(부팅 로그)용.

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

	-- 보스 아레나 슬롯 정보(20-2b) - BossEncounter.lua가 이 개수만큼 순환 배정한다.
	-- 실제 아레나 zone 자체는 zones["bossArena1"]..["bossArenaN"]에 이미 들어 있다.
	bossArena = {
		slotCount = BOSS_ARENA_SLOT_COUNT,
		halfSizeStuds = BOSS_ARENA_HALF_SIZE_STUDS,
		radiusStuds = BOSS_ARENA_RADIUS_STUDS,
	},

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
		mapSizeStuds = WorldMapData.worldRadiusStuds * 2, -- M1: 세계 지름(옛 = 3×3 맵 한 변 MAP_SIZE_STUDS)
		streamingTargetRadiusStuds = WorldMapData.streaming.targetRadius, -- M1: default.project.json Workspace 속성으로 git에 들어갔다(24-5 권장값 600 대체)
	},

	-- 22-5: 지형 배치 규칙이 읽는 유도값. 담장 안쪽 안전 띠 = 여백 - 리쉬(> 0이어야 띠가 존재).
	zoneEdge = {
		marginStuds = ZONE_EDGE_MARGIN_STUDS,
		safeBandStuds = ZONE_EDGE_MARGIN_STUDS - LEASH_RANGE_STUDS,
	},

	-- 담장 치수. 19-4 [4]-가가 tier 구역 담장에 쓰던 값인데 22-5에서 구역 담장을 없앴고, 지금은
	-- 보스 아레나 벽(BossEncounter.lua)과 맵 가장자리 장벽 두께(HuntingGround MapBarrier)만 읽는다.
	-- 높이 12는 로블록스 기본 점프 정점(약 7~8stud)보다 확실히 높아 대시·점프로 못 넘는 값.
	walls = {
		heightStuds = 12,
		thicknessStuds = 2,
	},

	-- 맵 가장자리 장벽(22-5 지시 - "완전 맵 밖으로는 못 나가게 장치"). 맵 한 변(superGrid.mapSizeStuds)
	-- 바깥 barrierOffset 자리에 보이지 않는 벽. 높이는 담장 높이의 세 배 - 점프(7.2)·대시(수평 16)
	-- 어느 조합으로도 못 넘고, 보이지 않으니 카메라를 가리지도 않는다. 보이는 능선은 ZoneTerrainData.perimeter.
	mapBoundary = {
		barrierHeightStuds = 36,
		barrierOffsetStuds = 4,
	},

	-- 강화대(10-2) - 이제 2번 칸(강화소)에 있다. stationOffset은 huntingGround.center(원점)
	-- 기준 오프셋이라는 기존 계약을 그대로 유지한다 - 값만 강화소 구역 중심으로 바꾸면
	-- EnhanceServer.server.lua/EnhanceStation.server.lua/EnhanceUI.client.lua 세 파일은
	-- 전혀 손대지 않아도 된다(전부 huntingGround.center + stationOffset을 그대로 계산).
	enhance = {
		stationOffset = zones.enhance.center,
		interactionRangeStuds = 12,
	},

	-- 환생 제단(S12b F) - 커뮤니티 구역(8번 칸)의 환생 전용 상호작용 물체(모델은 임시 - F5에서 교체). 위치 = 커뮤니티 구역 중심 + offsetFromCommunity(커뮤니티 센터 블록의
	-- 리스폰 쪽 면 앞). 서버는 요청 시점에 플레이어가 이 자리 interactionRangeStuds 안에 있는지 직접 잰다(클라의 ProximityPrompt 거리만 믿지 않는다).
	-- promptDistanceStuds는 서버 반경보다 작다 - 프롬프트가 뜬 자리에서 누른 요청은 항상 서버 반경 안이다.
	rebirthAltar = {
		offsetFromCommunity = Vector3.new(0, 0, 0), -- M1: 커뮤니티 센터 앞 자리 그대로(건물은 그 바깥쪽 - WorldMapLayout.buildHub)
		interactionRangeStuds = 12,
		promptDistanceStuds = 10,
		objectText = "환생의 제단",
		actionText = "환생",
	},

	-- 보석상인(S20e) - 커뮤니티 구역(8번 칸)의 환생 제단 옆에 놓는 NPC 자리(모델은 임시 - F5에서 교체). 보석 변환 · 리롤(옵션 리롤 · 변환권 구매)은 여기서만 된다 -
	-- GemMerchantAccess가 요청 시점에 플레이어가 이 자리 interactionRangeStuds 안인지 서버가 직접 잰다(클라의 ProximityPrompt 거리 · 창 상태를 믿지 않는다).
	-- offsetFromCommunity = 제단(0, 0, -26)의 옆(같은 면 앞, 동쪽 16stud). promptDistanceStuds는 서버 반경보다 작다 - 프롬프트가 뜬 자리에서 누른 요청은 항상 서버 반경 안이다.
	-- guideSeconds = [위치 안내] 마커가 떠 있는 시간(클라 표시 - 서버 호출 없음).
	gemMerchant = {
		offsetFromCommunity = hubPoint(WorldMapData.hub.facilities.market.angleDeg, WorldMapData.hub.facilities.market.r) - zones.community.center, -- M1: 시장 앞 자리(옛 이름 유지 - 커뮤니티 기준 오프셋)
		interactionRangeStuds = 12,
		promptDistanceStuds = 10,
		objectText = "보석상인",
		actionText = "보석 공방",
		guideSeconds = 10,
	},

	-- 땅에 떨어진 아이템(14-1) - 구역 재설계와 무관, 값 변경 없음.
	items = {
		pickupRangeStuds = 2,
		groundLifetimeSeconds = 60,
		pickupDelaySeconds = 0.6,
	},
}
