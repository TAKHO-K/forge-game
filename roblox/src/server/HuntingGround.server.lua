-- 사냥터 = 3×3 tier 구역 맵(16-6, 9-4/9-5의 단일 사냥터를 대체). 리스폰(중앙 안전지대) +
-- 강화소 + 커뮤니티(빈 자리) + tier1~6 여섯 구역, 전부 WorldConfig.zones가 정한 위치에
-- 배치한다 - 좌표를 여기서 다시 계산하지 않는다(단일 출처).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local MonsterPrefixData = require(ReplicatedStorage.Shared.data.MonsterPrefixData)
local MonsterSpawner = require(script.Parent.MonsterSpawner)
local TeleportPad = require(script.Parent.TeleportPad)
local ZoneTerrain = require(script.Parent.ZoneTerrain)

local FLOOR_THICKNESS = 2
local FLOOR_Y = 0 -- 모든 구역 바닥 중심 Y(9-4 원본 huntingGround.center.Y=0과 동일 기준).

-- 구역 역할별 바닥색. tier는 그 tier 대표 몬스터 색(MonsterData)을 옅게 섞어 "이 구역이
-- 어떤 몬스터 구역인지" 색으로도 읽히게 한다(지시 - "지형/색/기둥 정도로 충분하다").
local ROLE_FLOOR_COLOR = {
	spawn = Color3.fromRGB(210, 225, 220), -- 안전지대 - 밝고 중성적인 색.
	enhance = Color3.fromRGB(150, 140, 120),
	community = Color3.fromRGB(140, 150, 170),
}

local function blend(a, b, ratio)
	return Color3.new(
		a.R + (b.R - a.R) * ratio,
		a.G + (b.G - a.G) * ratio,
		a.B + (b.B - a.B) * ratio
	)
end

local NEUTRAL_GROUND = Color3.fromRGB(90, 140, 70) -- 9-4 원본 바닥색(Grass) - tier색과 섞는 바탕.

local function floorColorFor(zone)
	if zone.role == "tier" then
		local tierKey = MonsterData.tierOrder[zone.tierIndex]
		return blend(NEUTRAL_GROUND, MonsterData[tierKey].bodyColor, 0.45)
	end
	return ROLE_FLOOR_COLOR[zone.role] or NEUTRAL_GROUND
end

-- 22-4: 맵 밑판. 플레이스 기본 Baseplate(윗면 y=0)가 사실상 복도(구역 사이 32stud)의 바닥
-- 노릇을 하고 있었다 - Baseplate를 지우면서(removeDefaultBaseplate) 복도가 심연이 되므로 밑판을
-- 지면 폴더에 깐다. 22-5: 맵 크기는 WorldConfig.superGrid.mapSizeStuds(단일 출처) + 바깥 테두리
-- (복도 폭의 절반)이고, 구역 9개 자리는 비운다(ZoneTerrain.buildMapBase - 구역 바닥과 겹치지 않아
-- 웅덩이 밑에 밑판이 비치지 않는다). 윗면은 구역 바닥(1.0)보다 0.1 낮게(0.9) - 복도와 구역이 맞닿는
-- 선에서 두 면이 같은 높이로 겹치는 일이 없게 한 22-4 결정을 그대로 둔다. 이 밑판 밖(맵 밖)은 진짜
-- 심연 → 리스폰 복귀(TerrainServer).
local MAP_BASE_TOP_Y = FLOOR_Y + FLOOR_THICKNESS / 2 - 0.1
local MAP_BASE_BORDER_STUDS = WorldConfig.superGrid.corridorWidthStuds / 2

-- 22-5 지시: 구역 담장 대신 "맵 밖으로만 못 나가게". 맵 가장자리(±mapSize/2) 바로 바깥에 보이지
-- 않는 장벽 4장을 세운다 - 점프(7.2)·대시(수평)로 못 넘는 높이. 보이는 쪽은 ZoneTerrain의 바위 능선.
local function createMapBarrier()
	local halfMap = WorldConfig.superGrid.mapSizeStuds / 2
	local cfg = WorldConfig.mapBoundary
	local thickness = WorldConfig.walls.thicknessStuds
	local length = halfMap * 2 + cfg.barrierOffsetStuds * 2 + thickness * 2
	local y = FLOOR_Y + FLOOR_THICKNESS / 2 + cfg.barrierHeightStuds / 2 - 2 -- 바닥 아래 2까지 내려 틈 없음
	for _, side in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
		local wall = Instance.new("Part")
		wall.Name = "MapBarrier"
		wall.Anchored = true
		wall.CanCollide = true
		wall.Transparency = 1
		wall.CastShadow = false
		local offset = halfMap + cfg.barrierOffsetStuds + thickness / 2
		if side[1] ~= 0 then
			wall.Size = Vector3.new(thickness, cfg.barrierHeightStuds, length)
			wall.Position = Vector3.new(side[1] * offset, y, 0)
		else
			wall.Size = Vector3.new(length, cfg.barrierHeightStuds, thickness)
			wall.Position = Vector3.new(0, y, side[2] * offset)
		end
		wall.Parent = Workspace
	end
end

-- 구역 바닥 + 지형(22-5). 바닥색은 여기서 정하고(tier 몬스터 색 혼합), 지형 요소는 ZoneTerrainData.
local function buildZoneTerrain(zone)
	local color = floorColorFor(zone)
	return ZoneTerrain.build(zone, {
		floorSurface = { material = "Grass", color = { math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5) } },
		floorTopY = FLOOR_Y + FLOOR_THICKNESS / 2,
		floorThickness = FLOOR_THICKNESS,
	})
end

local function removeDefaultSpawns(ourSpawnName)
	for _, obj in ipairs(Workspace:GetChildren()) do
		if obj:IsA("SpawnLocation") and obj.Name ~= ourSpawnName then
			obj:Destroy()
		end
	end
end

-- 22-4: 플레이스 기본 Baseplate(2048×16, 윗면 y=0)를 지운다. 20.49 실측에서 잔존이 확인됐고,
-- 남겨 두면 구역 바닥 사이 틈·심연이 전부 "1stud 아래 바닥"이 되어 심연 복귀(TerrainServer)와
-- 몬스터의 "지면 없음" 판정이 절대 발동하지 않는다. removeDefaultSpawns와 같은 성격의 정리.
local function removeDefaultBaseplate()
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate:Destroy()
	end
end

-- 리스폰 구역(5번 칸) - 완전 안전지대, 몬스터 없음. 예전엔 몬스터 격자에서 멀리 떨어뜨려야
-- 했지만(9-5, SPAWN_SAFE_DISTANCE), 이제 이 구역 자체에 몬스터가 아예 없어 그 계산이
-- 통째로 필요 없어졌다(16-6) - 그냥 구역 중심에 스폰한다.
local function createPlayerSpawn(zone)
	local spawnPart = Instance.new("SpawnLocation")
	spawnPart.Name = "HuntingGroundSpawn"
	spawnPart.Size = Vector3.new(6, 1, 6)
	spawnPart.Anchored = true
	spawnPart.Neutral = true
	spawnPart.Transparency = 0.5
	spawnPart.Position = Vector3.new(zone.center.X, FLOOR_Y + FLOOR_THICKNESS / 2 + 0.5, zone.center.Z)
	spawnPart.Parent = Workspace
	return spawnPart
end

-- 커뮤니티 구역(8번 칸) - 지시: "지금은 건물 외형과 빈 공간만 만들어라. 기능은 넣지 마라."
local function createCommunityPlaceholder(zone)
	local building = Instance.new("Part")
	building.Name = "CommunityCenter"
	building.Size = Vector3.new(40, 20, 40)
	building.Anchored = true
	building.Material = Enum.Material.Concrete
	building.Color = Color3.fromRGB(180, 180, 190)
	building.Position = Vector3.new(zone.center.X, FLOOR_Y + FLOOR_THICKNESS / 2 + 10, zone.center.Z)
	building.Parent = Workspace

	local label = Instance.new("BillboardGui")
	label.Size = UDim2.new(6, 0, 1.2, 0)
	label.StudsOffset = Vector3.new(0, 12, 0)
	label.AlwaysOnTop = true
	label.Adornee = building
	label.Parent = building

	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.new(1, 0, 1, 0)
	text.Text = "커뮤니티 센터 (준비 중)"
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextScaled = true
	text.Parent = label
end

local function spawnTierMonsters(zone)
	local tierKey = MonsterData.tierOrder[zone.tierIndex]
	local data = MonsterData[tierKey]
	for _, offset in ipairs(WorldConfig.zoneMonsterGrid.offsets) do
		-- Y는 바닥 윗면 기준 관례값 - 실제 스폰 Y는 MonsterSpawner.spawn이 그 자리 지면으로
		-- 스냅한다(22-4, 슬롯 위에 언덕이 있으면 언덕 위에 선다).
		local position = Vector3.new(
			zone.center.X + offset.X,
			FLOOR_Y + FLOOR_THICKNESS / 2 + 1.5,
			zone.center.Z + offset.Z
		)
		MonsterSpawner.spawn(data, position, zone.key)
	end
end

-- ═══ 실행 ═══

-- 22-5: 유도 상수를 부팅 때 로그로 찍는다 - WorldConfig 주석에 숫자를 박지 않는 대신(20.49에서
-- "슈퍼그리드 160" 주석이 실제 224였다) 실제 값이 매 실행마다 눈에 보이게 한다.
do
	local zoneSize = WorldConfig.zoneSize
	local grid = WorldConfig.superGrid
	local tier6 = WorldConfig.zones.tier6
	local diagonalStuds = Vector2.new(tier6.center.X - tier6.halfSize, tier6.center.Z + tier6.halfSize).Magnitude
	local tier1 = WorldConfig.zones.tier1
	local entranceMargin = tier1.entrance.X - (tier1.center.X + zoneSize.halfSizeStuds) -- 입구 ~ 구역 경계(스폰 쪽 면)
	print(("[forge-game] 맵 상수 - 구역 %d(반 %d) / 복도 %d / 슈퍼그리드 %d / 맵 %d / 입구 마진 %d / 안전 띠(여백-리쉬) %.1f / 리스폰→tier6 모서리 %.0fstud(%.1f초)"):format(
		zoneSize.sizeStuds, zoneSize.halfSizeStuds, grid.corridorWidthStuds, grid.spacingStuds, grid.mapSizeStuds,
		entranceMargin, WorldConfig.zoneEdge.safeBandStuds, diagonalStuds, diagonalStuds / WorldConfig.playerWalkSpeedStuds))
end

-- 24-5(PRD 20.51 [4] 예정분 시도 → 보류): `Workspace.StreamingTargetRadius`/`StreamingMinRadius`는
-- 실측 결과 스크립트로 못 읽지도 못 쓰지도 않는다 - 실행 시 "StreamingTargetRadius is not a
-- valid member of Workspace" 에러(공식 문서: 이 두 속성은 스크립트 불가, Studio 속성창
-- 전용). Rojo 트리에 Workspace가 없어(default.project.json) 이 값을 커밋으로 못 남긴다 -
-- 권장값(WorldConfig.superGrid.streamingTargetRadiusStuds = 600)만 데이터로 남기고 실제
-- 적용은 사용자가 Studio 속성창에서 직접 한다(퍼블리시 전 체크리스트 5번).
print(("[forge-game] 스트리밍 반경 권장값 %d(Studio 속성창에서 수동 설정 필요 - 코드로 불가)"):format(
	WorldConfig.superGrid.streamingTargetRadiusStuds))

local mapBaseParts = ZoneTerrain.buildMapBase({
	topY = MAP_BASE_TOP_Y,
	thickness = FLOOR_THICKNESS,
	borderStuds = MAP_BASE_BORDER_STUDS,
	surface = "dirtPath",
})
local terrainParts = 0
for _, key in ipairs(WorldConfig.zoneOrder) do
	local zone = WorldConfig.zones[key]
	local counts = buildZoneTerrain(zone)
	terrainParts += counts.parts
	if counts.featureCount > 0 then
		print(("[forge-game] 지형 %s - 요소 %d개 → 파트 %d(바닥 %d·지면 %d·장식 %d), 배치 거부 %d"):format(
			key, counts.featureCount, counts.parts, counts.floorParts, counts.groundParts - counts.floorParts, counts.decorParts, #counts.violations))
	end
end
local ridgeParts = ZoneTerrain.buildPerimeterRidge(FLOOR_Y + FLOOR_THICKNESS / 2)
createMapBarrier()
print(("[forge-game] 맵 밑판 %d조각, 가장자리 능선 %d, 구역 지형 파트 합계 %d"):format(mapBaseParts, ridgeParts, terrainParts))

removeDefaultSpawns("HuntingGroundSpawn")
removeDefaultBaseplate()
createPlayerSpawn(WorldConfig.zones.spawn)
createCommunityPlaceholder(WorldConfig.zones.community)

local totalMonsters = 0
for _, key in ipairs(WorldConfig.tierZoneOrder) do
	spawnTierMonsters(WorldConfig.zones[key])
	totalMonsters += WorldConfig.zoneMonsterGrid.count
end

-- 포탈: 리스폰 구역 안에 tier 6개로 가는 패드, 각 tier 구역 입구에 중앙 복귀 패드
-- (지시 - "걸어서도 갈 수 있어야 한다. 포탈은 반복 이동의 편의지 유일한 경로가 아니다" -
-- 그래서 순간이동 전용 벽 대신 밟으면 이동하는 패드로만 만든다. 걸어서 가는 길은 이미
-- 열려 있다(구역 사이에 벽이 없다)).
local spawnCenter = WorldConfig.zones.spawn.center
for _, key in ipairs(WorldConfig.tierZoneOrder) do
	local zone = WorldConfig.zones[key]
	local tierName = MonsterData[key].displayName
	local padLabel = ("tier %d\n%s"):format(zone.tierIndex, tierName)

	-- 리스폰 쪽 패드 - 그 구역 방향을 향해 중심에서 50stud(구역 절반64보다 안쪽,
	-- 다른 패드와 안 겹치도록 원점에서 충분히 뗀 거리).
	local directionUnit = zone.center.Unit
	local outboundPosition = Vector3.new(
		spawnCenter.X + directionUnit.X * 50,
		FLOOR_Y + FLOOR_THICKNESS / 2 + 0.6,
		spawnCenter.Z + directionUnit.Z * 50
	)
	-- 도착 지점은 입구(복귀 패드 자리)에서 구역 쪽으로 10stud 더 들어간 곳 - 복귀 패드
	-- 바로 위에 겹쳐 내리지 않게 한다(시각적 구분, 기능은 쿨다운 공유로 이미 안전하다).
	local destinationInZone = Vector3.new(
		zone.entrance.X + directionUnit.X * 10,
		FLOOR_Y + FLOOR_THICKNESS / 2 + 3,
		zone.entrance.Z + directionUnit.Z * 10
	)
	-- 표지판은 다가오는 플레이어를 마주봐야 한다(지시 - "판자 표면에 직접 그린다"는 곧
	-- 각도가 카메라 시점에 고정된다는 뜻 - 방향까지 맞아야 정면으로 보인다). 출발 패드는
	-- 스폰(원점) 쪽에서 걸어오므로 그 방향(-directionUnit)을 향하고, 복귀 패드는 구역
	-- 안쪽에서 걸어나오므로 구역 방향(directionUnit)을 향한다.
	TeleportPad.create(outboundPosition, padLabel, MonsterData[key].bodyColor, destinationInZone, -directionUnit)

	-- 구역 쪽 복귀 패드 - 구역 입구 지점에 둔다.
	local returnPosition = Vector3.new(zone.entrance.X, FLOOR_Y + FLOOR_THICKNESS / 2 + 0.6, zone.entrance.Z)
	local spawnDestination = Vector3.new(spawnCenter.X, FLOOR_Y + FLOOR_THICKNESS / 2 + 3, spawnCenter.Z)
	TeleportPad.create(returnPosition, "중앙 복귀", Color3.fromRGB(220, 220, 230), spawnDestination, directionUnit)
end

print(("[forge-game] 사냥터 생성 완료 - 9개 구역, tier 몬스터 %d마리 스폰됨"):format(totalMonsters))

-- 공정성 항등식 실측 로그(16-6 지시 - "6개 tier 전부 수치로 확인하고 결과를 보여줘라").
for _, check in ipairs(MonsterData.fairnessCheck) do
	print(("[forge-game] tier%d 공정성 검증 - r=%.4f, 시간당보상=%.4f"):format(
		check.tier, check.r, check.rewardPerTime))
end
-- 접두사 변종 공평성(22-2 [1]) - 보상배율/HP배율이 접두사 무관하게 1인지 실행 시점에 확인.
for _, check in ipairs(MonsterPrefixData.fairnessCheck) do
	print(("[forge-game] 접두사 %s(%s) 공평성 검증 - HP×%.2f, 보상×%.2f, 시간당보상=%.4f"):format(
		check.displayName, check.id, check.hpMultiplier, check.rewardMultiplier, check.rewardPerTime))
end
