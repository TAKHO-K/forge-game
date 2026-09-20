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
-- 맵 전체 한 변(가장 바깥 구역의 바깥 담장까지) = 구역 3개 + 복도 2개. 맵 밑판(HuntingGround
-- MapBase)·심연 판정이 이 값을 읽는다 - 여기 말고는 어디에도 맵 크기를 다시 적지 않는다.
local MAP_SIZE_STUDS = SUPER_GRID_SPACING_STUDS * 3 - CORRIDOR_WIDTH_STUDS

-- 24-5(PRD 20.51 [4]가 예정한 값): 맵 832가 기본 StreamingEnabled 반경 안이라 지금까지
-- 스트리밍이 아무것도 걸러내지 않았다(20.51 [4]). 16인 클라 스트리밍 파트가 상한
-- 1,500에 걸리면서(20.63 [3], 1,501) 처음으로 줄여야 하는 시점이 됐다 - "구역 1개 +
-- 이웃"(슈퍼그리드 간격의 2배, 288×2=576) 정도로 잡으면 지금 서 있는 구역과 옆 구역까지는
-- 보이고 그 너머(같은 대각선의 세 번째 구역)는 걸러진다. 성능/안전장치 값이라 새 밸런스
-- 상수가 아니다. 24-5 실측: `Workspace.StreamingTargetRadius`는 스크립트로 못 쓴다(공식
-- 문서 - Studio 속성창 전용, "not a valid member" 실행 에러로 확인) - 이 값은 적용될
-- 목표치를 기록만 하고, 실제 적용은 사용자가 Studio에서 수동으로 한다
-- (HuntingGround.server.lua 부팅 로그가 이 값을 안내한다).
local STREAMING_TARGET_RADIUS_STUDS = 600

-- ═══ 유도값 한눈에(22-5) - 숫자를 주석에 박아 두면 값이 바뀔 때 주석이 남는다(20.49 실측에서
-- "슈퍼그리드 160" 주석이 실제 224였다). 그래서 이 파일의 주석은 식만 적고, 실제 숫자는
-- HuntingGround.server.lua가 부팅 로그에 찍는다(derived 테이블). 식은 다음과 같다:
--   구역 = 2 × (격자 + 여백)          / 슈퍼그리드 = 구역 + 복도     / 맵 = 3 × 슈퍼그리드 - 복도
--   담장 안쪽 안전 띠 = 여백 - 리쉬    / 입구 마진 = 복도 / 2          / 변 칸 문까지 = 슈퍼그리드/2 - 여백 + 격자

-- 사용자가 확정한 배치표 그대로(16-6):
--   1 tier5 | 2 강화소 | 3 tier6
--   4 tier1 | 5 리스폰 | 6 tier2
--   7 tier3 | 8 커뮤니티 | 9 tier4
-- col/row는 리스폰(원점) 기준 격자 좌표 - world 좌표는 아래서 col/row × SUPER_GRID_SPACING로 뽑는다.
local ZONE_LAYOUT = {
	{ key = "tier5", role = "tier", tierIndex = 5, col = -1, row = -1 },
	{ key = "enhance", role = "enhance", col = 0, row = -1, displayName = "강화소" },
	{ key = "tier6", role = "tier", tierIndex = 6, col = 1, row = -1 },
	{ key = "tier1", role = "tier", tierIndex = 1, col = -1, row = 0 },
	{ key = "spawn", role = "spawn", col = 0, row = 0, displayName = "리스폰 마을" },
	{ key = "tier2", role = "tier", tierIndex = 2, col = 1, row = 0 },
	{ key = "tier3", role = "tier", tierIndex = 3, col = -1, row = 1 },
	{ key = "community", role = "community", col = 0, row = 1, displayName = "커뮤니티 광장" },
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
	-- 정확히 중점이다. entrance - half = SUPER/2 - HALF = CORRIDOR/2로 항상 양수라
	-- (SUPER_GRID_SPACING = ZONE_SIZE + CORRIDOR_WIDTH 관계 덕분에 ZONE_HALF_SIZE_STUDS 값이
	-- 바뀌어도 이 마진은 유지된다 - 19-4의 64->96, 22-5의 96->128 둘 다 재검산으로 확인) 변 칸이든
	-- 대각 칸이든 이 중점은 항상 두 구역 경계 바깥이다. 리스폰(구역 자체가 없음)엔 입구가 없다.
	local entrance = center * 0.5

	-- 22-5 지시로 구역 담장(19-4 [4]-가)과 문(gate)을 없앴다 - "담장을 둘러두면 답답하다". 구역은
	-- 바닥색과 진입 토스트(ZoneBoundaryWarning.client.lua)로만 구분하고, 몬스터 봉쇄는 원래부터
	-- 담장이 아니라 리쉬 + ZoneBounds(구역 경계 = 리쉬 상한, MonsterAI)가 하던 일이라 바뀌지 않는다.
	-- 걸어가는 최단 경로는 이제 리스폰에서 구역 모서리까지의 직선이다(부팅 로그 참고).
	zones[entry.key] = {
		key = entry.key,
		role = entry.role,
		tierIndex = entry.tierIndex,
		displayName = entry.displayName, -- tier 구역은 nil - 몬스터 이름(MonsterData)으로 부른다.
		center = center,
		halfSize = ZONE_HALF_SIZE_STUDS,
		entrance = entrance,
	}
	table.insert(zoneOrder, entry.key)
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
-- 22-5: tier 구역이 256으로 넓어졌지만 아레나는 21-3이 패턴(돌진 거리·파동 반경·경계 92)을
-- 검증한 크기(격자 + 격자/2 = 96)에 묶어 둔다 - 보스맵 6종(20.50 [6])을 지을 때 그 세션이
-- 아레나 크기를 다시 정한다. ZONE_HALF_SIZE를 따라가게 두면 검증 없이 패턴 기하가 바뀐다.
local BOSS_ARENA_HALF_SIZE_STUDS = ZONE_MONSTER_HALF_SPAN + GRID_SPACING_STUDS / 2
local BOSS_ARENA_BASE_Z_STUDS = -3000 -- 슈퍼그리드 가장자리(-MAP_SIZE/2)에서 충분히 먼 값.
local BOSS_ARENA_SPACING_STUDS = BOSS_ARENA_HALF_SIZE_STUDS * 2 + 100 -- 슬롯끼리 안 겹치는 여유.

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
		mapSizeStuds = MAP_SIZE_STUDS, -- 22-5: 맵 전체 한 변(맵 밑판·심연 경계의 단일 출처).
		streamingTargetRadiusStuds = STREAMING_TARGET_RADIUS_STUDS, -- 24-5: 위 주석 참고.
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
		offsetFromCommunity = Vector3.new(0, 0, -26),
		interactionRangeStuds = 12,
		promptDistanceStuds = 10,
		objectText = "환생의 제단",
		actionText = "환생",
	},

	-- 땅에 떨어진 아이템(14-1) - 구역 재설계와 무관, 값 변경 없음.
	items = {
		pickupRangeStuds = 2,
		groundLifetimeSeconds = 60,
		pickupDelaySeconds = 0.6,
	},
}
