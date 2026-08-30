-- 사냥터 구역 + 몬스터 여러 마리 스폰. 이동/AI/공격은 아직 없다(9-4).
-- 몬스터는 서버가 스폰한다 - 클라이언트는 관여하지 않는다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local MonsterSpawner = require(script.Parent.MonsterSpawner)

local function createFloor()
	local floor = Instance.new("Part")
	floor.Name = "HuntingGroundFloor"
	floor.Size = WorldConfig.huntingGround.size
	floor.Position = WorldConfig.huntingGround.center
	floor.Anchored = true
	floor.Material = Enum.Material.Grass
	floor.Color = Color3.fromRGB(90, 140, 70)
	floor.Parent = Workspace
	return floor
end

-- 사냥터 중심 기준 XZ 오프셋 + 바닥 위 높이를 world 좌표로 계산한다.
local function positionOnFloor(floor, xzOffset, partHalfHeight)
	local floorTopY = floor.Position.Y + floor.Size.Y / 2
	return Vector3.new(
		floor.Position.X + xzOffset.X,
		floorTopY + partHalfHeight,
		floor.Position.Z + xzOffset.Z
	)
end

-- Studio 베이스플레이트 템플릿이 기본으로 깔아 두는 SpawnLocation(보통 원점 근처)을
-- 지운다. 로블록스는 SpawnLocation이 여러 개면 그중 하나를 무작위로 골라 리스폰시키므로,
-- 이 기본 스폰이 남아 있으면 우리가 계산한 안전 거리(WorldConfig.playerSpawnOffset,
-- 9-5)와 무관하게 몬스터 바로 옆에서 (재)스폰될 수 있다 - 실제로 이번 세션에 "즉사 후
-- 몬스터 옆에서 다시 즉사"가 재현된 원인이 이거였다.
local function removeDefaultSpawns(ourSpawnName)
	for _, obj in ipairs(Workspace:GetChildren()) do
		if obj:IsA("SpawnLocation") and obj.Name ~= ourSpawnName then
			obj:Destroy()
		end
	end
end

local function createPlayerSpawn(floor)
	local spawnPart = Instance.new("SpawnLocation")
	spawnPart.Name = "HuntingGroundSpawn"
	spawnPart.Size = Vector3.new(6, 1, 6)
	spawnPart.Anchored = true
	spawnPart.Neutral = true
	spawnPart.Transparency = 0.5
	spawnPart.Position = positionOnFloor(floor, WorldConfig.playerSpawnOffset, spawnPart.Size.Y / 2)
	spawnPart.Parent = Workspace
	return spawnPart
end

-- 몬스터 스폰 슬롯: 사냥터 중심 기준 격자 균등 배치(간격·맵 크기 유도는 WorldConfig 참고).
local function monsterSpawnPositions(floor)
	local floorTopY = floor.Position.Y + floor.Size.Y / 2
	local sideCount = WorldConfig.spawns.gridSideCount
	local spacing = WorldConfig.spawns.gridSpacingStuds
	local halfSpan = spacing * (sideCount - 1) / 2

	local positions = {}
	for row = 0, sideCount - 1 do
		for col = 0, sideCount - 1 do
			table.insert(positions, Vector3.new(
				floor.Position.X - halfSpan + col * spacing,
				floorTopY + 1.5,
				floor.Position.Z - halfSpan + row * spacing
			))
		end
	end
	return positions
end

local floor = createFloor()
removeDefaultSpawns("HuntingGroundSpawn")
createPlayerSpawn(floor)

for _, position in ipairs(monsterSpawnPositions(floor)) do
	MonsterSpawner.spawn(MonsterData.tier1, position)
end

print(("[forge-game] 사냥터 생성 완료 - 몬스터 %d마리 스폰됨"):format(WorldConfig.spawns.count))
