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

local function createZoneFloor(zone)
	local floor = Instance.new("Part")
	floor.Name = "ZoneFloor_" .. zone.key
	floor.Size = Vector3.new(WorldConfig.zoneSize.sizeStuds, FLOOR_THICKNESS, WorldConfig.zoneSize.sizeStuds)
	floor.Position = Vector3.new(zone.center.X, FLOOR_Y, zone.center.Z)
	floor.Anchored = true
	floor.Material = Enum.Material.Grass
	floor.Color = floorColorFor(zone)
	floor.Parent = Workspace
	return floor
end

-- 구역 경계 표시(지시 - "유저가 실수로 드래곤 구역에 들어가는 일이 없어야 한다"). 네
-- 모서리에 기둥을 세우고, 네 변에 얇은 경계선(바닥과 다른 색)을 깐다 - 아트 세션으로
-- 미루는 "드래곤 둥지" 같은 꾸밈 없이도 경계 자체는 명확해야 한다는 지시를 도형만으로
-- 만족시킨다.
local function createZoneBoundary(zone)
	local half = zone.halfSize
	local pillarColor = zone.role == "tier"
		and MonsterData[MonsterData.tierOrder[zone.tierIndex]].bodyColor
		or Color3.fromRGB(80, 80, 90)

	for _, corner in ipairs({ Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, 1) }) do
		local pillar = Instance.new("Part")
		pillar.Name = "BoundaryPillar"
		pillar.Size = Vector3.new(3, 10, 3)
		pillar.Anchored = true
		pillar.Material = Enum.Material.Neon
		pillar.Color = pillarColor
		pillar.Position = Vector3.new(
			zone.center.X + corner.X * half,
			FLOOR_Y + FLOOR_THICKNESS / 2 + 5,
			zone.center.Z + corner.Z * half
		)
		pillar.Parent = Workspace
	end

	-- 경계선 4변(바닥보다 살짝 위, 대비되는 밝은 띠) - 지시의 "바닥 색이 바뀌거나"를
	-- 그 구역 바닥색과는 별개로, 정확히 "여기가 끝"을 알리는 선으로 보강한다.
	local stripThickness = 2
	local stripColor = Color3.fromRGB(255, 255, 255)
	local sides = {
		{ size = Vector3.new(WorldConfig.zoneSize.sizeStuds, 0.2, stripThickness), offset = Vector3.new(0, 0, -half) },
		{ size = Vector3.new(WorldConfig.zoneSize.sizeStuds, 0.2, stripThickness), offset = Vector3.new(0, 0, half) },
		{ size = Vector3.new(stripThickness, 0.2, WorldConfig.zoneSize.sizeStuds), offset = Vector3.new(-half, 0, 0) },
		{ size = Vector3.new(stripThickness, 0.2, WorldConfig.zoneSize.sizeStuds), offset = Vector3.new(half, 0, 0) },
	}
	for _, side in ipairs(sides) do
		local strip = Instance.new("Part")
		strip.Name = "BoundaryStrip"
		strip.Size = side.size
		strip.Anchored = true
		strip.CanCollide = false
		strip.Material = Enum.Material.Neon
		strip.Color = stripColor
		strip.Transparency = 0.3
		strip.Position = Vector3.new(
			zone.center.X + side.offset.X,
			FLOOR_Y + FLOOR_THICKNESS / 2 + 0.15,
			zone.center.Z + side.offset.Z
		)
		strip.Parent = Workspace
	end
end

local function removeDefaultSpawns(ourSpawnName)
	for _, obj in ipairs(Workspace:GetChildren()) do
		if obj:IsA("SpawnLocation") and obj.Name ~= ourSpawnName then
			obj:Destroy()
		end
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

-- 안전지대 물리 담장(19-4 [4]-가) - tier 구역에만 세운다. 4면 중 zone.gate가 가리키는
-- 한 면만 문 너비(WorldConfig.walls.doorwayWidthStuds)만큼 벽 두 조각으로 갈라 틈을
-- 낸다 - 나머지 3면은 완전히 막힌 벽 하나씩이다. CanCollide=true라 플레이어·몬스터 둘
-- 다 못 넘는다(대시도 이동 자체를 막으므로 대시로도 못 넘는다). AttackServer.server.lua의
-- ZoneBounds 판정(2차 방어)과 별개로, 이 담장이 "몬스터가 안전지대로 흘러나오는 것" 자체를
-- 물리적으로 막는 1차 방어다.
local WALL_COLOR = Color3.fromRGB(70, 65, 60)

local function createWallPart(centerX, centerZ, sizeX, sizeZ, wallY)
	local wall = Instance.new("Part")
	wall.Name = "ZoneWall"
	wall.Anchored = true
	wall.CanCollide = true
	wall.Material = Enum.Material.Slate
	wall.Color = WALL_COLOR
	wall.Size = Vector3.new(sizeX, WorldConfig.walls.heightStuds, sizeZ)
	wall.Position = Vector3.new(centerX, wallY, centerZ)
	wall.Parent = Workspace
end

local function createZoneWalls(zone)
	if not zone.gate then
		return
	end

	local half = zone.halfSize
	local thickness = WorldConfig.walls.thicknessStuds
	local doorway = WorldConfig.walls.doorwayWidthStuds
	local wallY = FLOOR_Y + FLOOR_THICKNESS / 2 + WorldConfig.walls.heightStuds / 2
	local cx, cz = zone.center.X, zone.center.Z
	-- 문이 있는 변은 완전한 한 조각 대신 이 길이의 벽 두 조각(양 끝) + 가운데 문틀로 나뉜다.
	local segmentLength = half - doorway / 2

	local sides = {
		{ axis = "x", sign = 1 }, { axis = "x", sign = -1 },
		{ axis = "z", sign = 1 }, { axis = "z", sign = -1 },
	}
	for _, side in ipairs(sides) do
		local isGate = zone.gate.axis == side.axis and zone.gate.sign == side.sign
		if side.axis == "x" then
			local wallX = cx + side.sign * half
			if isGate then
				createWallPart(wallX, cz - half + segmentLength / 2, thickness, segmentLength, wallY)
				createWallPart(wallX, cz + half - segmentLength / 2, thickness, segmentLength, wallY)
			else
				createWallPart(wallX, cz, thickness, half * 2, wallY)
			end
		else
			local wallZ = cz + side.sign * half
			if isGate then
				createWallPart(cx - half + segmentLength / 2, wallZ, segmentLength, thickness, wallY)
				createWallPart(cx + half - segmentLength / 2, wallZ, segmentLength, thickness, wallY)
			else
				createWallPart(cx, wallZ, half * 2, thickness, wallY)
			end
		end
	end
end

local function spawnTierMonsters(zone)
	local tierKey = MonsterData.tierOrder[zone.tierIndex]
	local data = MonsterData[tierKey]
	for _, offset in ipairs(WorldConfig.zoneMonsterGrid.offsets) do
		local position = Vector3.new(
			zone.center.X + offset.X,
			FLOOR_Y + FLOOR_THICKNESS / 2 + 1.5,
			zone.center.Z + offset.Z
		)
		MonsterSpawner.spawn(data, position, zone.key)
	end
end

-- ═══ 실행 ═══

for _, key in ipairs(WorldConfig.zoneOrder) do
	local zone = WorldConfig.zones[key]
	createZoneFloor(zone)
	if zone.role ~= "spawn" then
		createZoneBoundary(zone)
	end
end

removeDefaultSpawns("HuntingGroundSpawn")
createPlayerSpawn(WorldConfig.zones.spawn)
createCommunityPlaceholder(WorldConfig.zones.community)

for _, key in ipairs(WorldConfig.tierZoneOrder) do
	createZoneWalls(WorldConfig.zones[key])
end

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
