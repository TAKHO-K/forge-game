-- 몬스터 인스턴스 생성·사망·리스폰. 이름표 HP 표시 갱신도 여기서 한다.
-- HP<=0인지 판단은 AttackServer가 하고(데미지를 적용한 직후라 그 값을 이미 들고 있다),
-- 그 다음 처리(로그·MonsterState 정리·인스턴스 제거·리스폰 예약)는 여기 despawn()이 맡는다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local MonsterState = require(script.Parent.MonsterState)

local MonsterSpawner = {}

-- 기본 파트 조합으로 "구분되는 덩어리" 하나를 만든다. Humanoid는 애니메이션·이름표 전용이고
-- 실제 HP는 MonsterState가 관리한다(Humanoid.MaxHealth=100은 쓰이지 않는 더미값).
local function buildModel(data, position)
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
	hpLabel.TextColor3 = Color3.new(1, 1, 1)
	hpLabel.TextScaled = true
	hpLabel.Parent = nameplateGui

	model.PrimaryPart = root
	return model
end

-- 확정된 K/M/B/T 표기(NumberFormat)로 "현재HP/최대HP"를 갱신한다.
function MonsterSpawner.updateHpLabel(model)
	local head = model:FindFirstChild("Head")
	local nameplateGui = head and head:FindFirstChild("NameplateGui")
	local hpLabel = nameplateGui and nameplateGui:FindFirstChild("HpLabel")
	if not hpLabel then
		return
	end

	local hp = math.max(MonsterState.getHp(model) or 0, 0)
	local maxHp = MonsterState.getMaxHp(model) or 0
	hpLabel.Text = NumberFormat.format(hp) .. "/" .. NumberFormat.format(maxHp)
end

function MonsterSpawner.spawn(data, position)
	local model = buildModel(data, position)
	model.Parent = Workspace
	MonsterState.init(model, data, position)
	MonsterSpawner.updateHpLabel(model)
	return model
end

-- 사망 처리. 정해진 스폰 자리에 그대로 리스폰한다 - 무작위 위치로 보내면 균등 배치가
-- 흐트러지고 자리끼리 겹칠 수 있어서, 자리를 고정하는 편이 더 낫다고 판단했다.
function MonsterSpawner.despawn(model)
	local data = MonsterState.getData(model)
	local spawnPosition = MonsterState.getSpawnPosition(model)

	print(("[forge-game] 몬스터 사망: %s"):format(model.Name))
	MonsterState.clear(model) -- 죽는 즉시 타겟 후보에서 제외(findNearestMonsterInRange가 더 이상 고르지 않는다)

	-- 마지막 데미지 숫자가 화면에서 사라질 시간만큼은 시체를 남겨둔다.
	task.delay(CombatConfig.damageNumberLifetimeSeconds, function()
		model:Destroy()
	end)

	task.delay(WorldConfig.spawns.respawnDelaySeconds, function()
		MonsterSpawner.spawn(data, spawnPosition)
	end)
end

return MonsterSpawner
