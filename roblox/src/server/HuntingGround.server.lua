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

-- 몬스터 스폰 슬롯: 사냥터 중심 기준 원형 균등 배치. 그리드보다 마리 수가 안 맞아도
-- 빈 자리가 안 생기고, 전부 중심에서 같은 거리라 자동 타겟(가장 가까운 대상) 결과가
-- 플레이어 위치에 따라 고르게 갈린다.
local function monsterSpawnPositions(floor)
	local floorTopY = floor.Position.Y + floor.Size.Y / 2
	local positions = {}
	for i = 0, WorldConfig.spawns.count - 1 do
		local angle = (2 * math.pi / WorldConfig.spawns.count) * i
		positions[i + 1] = Vector3.new(
			floor.Position.X + WorldConfig.spawns.radius * math.cos(angle),
			floorTopY + 1.5,
			floor.Position.Z + WorldConfig.spawns.radius * math.sin(angle)
		)
	end
	return positions
end

local floor = createFloor()
createPlayerSpawn(floor)

for _, position in ipairs(monsterSpawnPositions(floor)) do
	MonsterSpawner.spawn(MonsterData.tier1, position)
end

print(("[forge-game] 사냥터 생성 완료 - 몬스터 %d마리 스폰됨"):format(WorldConfig.spawns.count))
