-- 몬스터 인스턴스 생성·사망·리스폰. 이름표 HP 표시 갱신도 여기서 한다.
-- HP<=0인지 판단은 AttackServer가 하고(데미지를 적용한 직후라 그 값을 이미 들고 있다),
-- 그 다음 처리(로그·MonsterState 정리·인스턴스 제거·리스폰 예약)는 여기 despawn()이 맡는다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local MonsterState = require(script.Parent.MonsterState)

local MonsterSpawner = {}

local DEFAULT_BODY_COLOR = Color3.fromRGB(150, 90, 200)
local DEFAULT_HEAD_COLOR = Color3.fromRGB(180, 120, 220)

-- 기본 파트 조합으로 "구분되는 덩어리" 하나를 만든다. Humanoid는 애니메이션·이름표 전용이고
-- 실제 HP는 MonsterState가 관리한다(Humanoid.MaxHealth=100은 쓰이지 않는 더미값).
--
-- sizeScale/bodyColor/headColor(15-1, 기본값은 잡몹 그대로) - 보스를 "확실히 크게"
-- 만들라는 지시를 아트 리소스 없이 기본 파트 크기·색만으로 만족시킨다(하지 말 것:
-- 아트·모션 다듬기, 동결 상태).
local function buildModel(data, position)
	local sizeScale = data.sizeScale or 1
	local bodyColor = data.bodyColor or DEFAULT_BODY_COLOR
	local headColor = data.headColor or DEFAULT_HEAD_COLOR

	local model = Instance.new("Model")
	model.Name = data.displayName

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1) * sizeScale
	root.Transparency = 1
	root.CanCollide = false
	root.Anchored = true
	root.Position = position
	root.Parent = model

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(2.4, 3, 1.2) * sizeScale
	body.Anchored = true
	body.Color = bodyColor
	body.Position = position
	body.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.6, 1.6, 1.6) * sizeScale
	head.Anchored = true
	head.Color = headColor
	head.Position = position + Vector3.new(0, 2.3 * sizeScale, 0)
	head.Parent = model

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.NameDisplayDistance = 0
	humanoid.Parent = model

	local nameplateGui = Instance.new("BillboardGui")
	nameplateGui.Name = "NameplateGui"
	nameplateGui.Size = UDim2.new(4 * sizeScale, 0, 1.2 * sizeScale, 0)
	nameplateGui.StudsOffset = Vector3.new(0, 1.4 * sizeScale, 0)
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

-- 등장 연출(15-1, 지시 [2] "그냥 나타나면 보스로 안 읽힌다"). 기본 파트만으로 만든다 -
-- 바닥에서 퍼지는 경고 링 + 보스 본체 페이드인. 잡몹 스폰에는 안 쓴다(부르는 쪽에서
-- data.isBoss일 때만 호출).
local function playBossAppearEffect(model, position)
	local ring = Instance.new("Part")
	ring.Name = "BossAppearRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(200, 30, 30)
	ring.Anchored = true
	ring.CanCollide = false
	ring.Transparency = 0.2
	ring.Size = Vector3.new(0.2, 1, 1)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = Workspace

	TweenService:Create(ring, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {
		Size = Vector3.new(0.2, 40, 40),
		Transparency = 1,
	}):Play()
	task.delay(0.6, function()
		ring:Destroy()
	end)

	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			local targetTransparency = part.Transparency
			part.Transparency = 1
			TweenService:Create(part, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
				Transparency = targetTransparency,
			}):Play()
		end
	end
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
	if data.isBoss then
		playBossAppearEffect(model, position)
	end
	return model
end

-- 사망 처리. 정해진 스폰 자리에 그대로 리스폰한다 - 무작위 위치로 보내면 균등 배치가
-- 흐트러지고 자리끼리 겹칠 수 있어서, 자리를 고정하는 편이 더 낫다고 판단했다.
--
-- 보스(isBoss)는 고정 스폰 격자(WorldConfig.spawns)에 속하지 않는 플레이어 전용 인스턴스라
-- 리스폰시키지 않는다 - 다시 나타나는 시점은 BossEncounter.spawnFor가 "그 스테이지에
-- 다시 들어왔을 때"로 직접 관리한다.
function MonsterSpawner.despawn(model)
	local data = MonsterState.getData(model)
	local spawnPosition = MonsterState.getSpawnPosition(model)

	print(("[forge-game] 몬스터 사망: %s"):format(model.Name))
	MonsterState.clear(model) -- 죽는 즉시 타겟 후보에서 제외(findNearestMonsterInRange가 더 이상 고르지 않는다)

	-- 마지막 데미지 숫자가 화면에서 사라질 시간만큼은 시체를 남겨둔다.
	task.delay(CombatConfig.damageNumberLifetimeSeconds, function()
		model:Destroy()
	end)

	if not data.isBoss then
		task.delay(WorldConfig.spawns.respawnDelaySeconds, function()
			MonsterSpawner.spawn(data, spawnPosition)
		end)
	end
end

return MonsterSpawner
