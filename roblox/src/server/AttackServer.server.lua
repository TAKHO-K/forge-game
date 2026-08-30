-- 서버 권위 공격 판정. 클라이언트는 "공격하겠다"는 의사만 보낸다(RemoteEvent 인자 없음) -
-- 사거리 검증·대상 선정·쿨다운 관리·데미지 계산은 전부 여기서만 한다. 클라이언트가 보낸
-- 좌표·대상·데미지 값을 받는 코드는 없다(애초에 그런 인자를 받지 않는다).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local MonsterState = require(script.Parent.MonsterState)

local attackRequest = Instance.new("RemoteEvent")
attackRequest.Name = "AttackRequest"
attackRequest.Parent = ReplicatedStorage

local attackResult = Instance.new("RemoteEvent")
attackResult.Name = "AttackResult"
attackResult.Parent = ReplicatedStorage

local lastAttackTick = {} -- [Player] = os.clock() 시각

-- 자동 타겟: 사거리 안에서 가장 가까운 몬스터 하나. 어느 몬스터를 때릴지는
-- 클라이언트가 정하지 않는다 - 여기서만 정한다.
local function findNearestMonsterInRange(originPosition)
	local nearestModel, nearestDistance = nil, math.huge

	for _, model in ipairs(MonsterState.getAllModels()) do
		local rootPart = model.PrimaryPart
		if rootPart then
			local distance = (rootPart.Position - originPosition).Magnitude
			if distance <= CombatConfig.attackRangeStuds and distance < nearestDistance then
				nearestModel, nearestDistance = model, distance
			end
		end
	end

	return nearestModel
end

attackRequest.OnServerEvent:Connect(function(player)
	local now = os.clock()
	local last = lastAttackTick[player]
	if last and now - last < CombatConfig.attackCooldownSeconds then
		return -- 쿨다운이 안 지났다 - 조용히 무시
	end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	lastAttackTick[player] = now -- 헛스윙이어도 쿨다운은 소모한다

	local target = findNearestMonsterInRange(rootPart.Position)
	if not target then
		return -- 사거리 안에 몬스터가 없다 - 헛스윙
	end

	local damage = CombatConfig.playerAttackPower
	MonsterState.setHp(target, MonsterState.getHp(target) - damage)

	attackResult:FireClient(player, target, damage)
end)

Players.PlayerRemoving:Connect(function(player)
	lastAttackTick[player] = nil
end)
