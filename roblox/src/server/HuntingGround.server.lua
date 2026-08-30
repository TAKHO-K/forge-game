-- 사냥터 구역 + 몬스터 1종 스폰. 공격/이동/AI/UI는 다음 세션이다.
-- 몬스터는 서버가 스폰한다 - 클라이언트는 관여하지 않는다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local MonsterState = require(script.Parent.MonsterState)

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

-- 기본 파트 조합으로 "구분되는 덩어리" 하나를 만든다. Humanoid는 애니메이션·이름표 전용이고
-- 실제 HP는 MonsterState가 관리한다(Humanoid.MaxHealth=100은 쓰이지 않는 더미값).
local function spawnMonster(data, position)
	local model = Instance.new("Model")
	model.Name = data.displayName

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.CanCollide = false
	root.Anchored = true
	root.Position = position
	root.Parent = model

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(2.4, 3, 1.2)
	body.Anchored = true
	body.Color = Color3.fromRGB(150, 90, 200)
	body.Position = position
	body.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.6, 1.6, 1.6)
	head.Anchored = true
	head.Color = Color3.fromRGB(180, 120, 220)
	head.Position = position + Vector3.new(0, 2.3, 0)
	head.Parent = model

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.NameDisplayDistance = 0
	humanoid.Parent = model

	-- 이름·HP 표시 자리만 잡아둔다. HP 값 표시는 9-3에서 채운다.
	local nameplateGui = Instance.new("BillboardGui")
	nameplateGui.Name = "NameplateGui"
	nameplateGui.Size = UDim2.new(4, 0, 1.2, 0)
	nameplateGui.StudsOffset = Vector3.new(0, 1.4, 0)
	nameplateGui.AlwaysOnTop = true
	nameplateGui.Adornee = head
	nameplateGui.Parent = head

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = data.displayName
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextScaled = true
	nameLabel.Parent = nameplateGui

	local hpLabel = Instance.new("TextLabel")
	hpLabel.Name = "HpLabel"
	hpLabel.Size = UDim2.new(1, 0, 0.5, 0)
	hpLabel.Position = UDim2.new(0, 0, 0.5, 0)
	hpLabel.BackgroundTransparency = 1
	hpLabel.Text = "" -- 9-3에서 MonsterState.getHp()로 채운다
	hpLabel.TextColor3 = Color3.new(1, 1, 1)
	hpLabel.TextScaled = true
	hpLabel.Parent = nameplateGui

	model.PrimaryPart = root
	model.Parent = Workspace

	MonsterState.init(model, data.hp)

	return model
end

local floor = createFloor()
createPlayerSpawn(floor)
local monster = spawnMonster(MonsterData.tier1, positionOnFloor(floor, WorldConfig.monsterSpawnOffset, 1.5))

print(("[forge-game] 사냥터 생성 완료 - 몬스터 스폰됨 (name=%s, hp=%d)"):format(
	MonsterData.tier1.displayName,
	MonsterState.getHp(monster)
))
