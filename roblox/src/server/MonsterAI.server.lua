-- 몬스터 추격·리쉬·반격. 이동은 직선(PathfindingService 안 씀 - 사냥터에 장애물이 없다).
-- 어그로/리쉬 판정은 WorldConfig.aggro에서 유도한 값을 그대로 쓴다(관계식 근거는 그쪽 참고).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local MonsterState = require(script.Parent.MonsterState)
local PlayerState = require(script.Parent.PlayerState)

-- 클라이언트 체력바(PlayerHealthBar.client.lua)는 Humanoid.Health가 아니라 이 Attribute를
-- 읽는다 - PlayerState가 유일한 HP 소스이므로 HP가 바뀌는 모든 지점에서 이걸 같이 불러야 한다.
local function syncHud(player)
	player:SetAttribute("Hp", PlayerState.getHp(player))
	player:SetAttribute("MaxHp", PlayerState.getMaxHp(player))
end

Players.PlayerAdded:Connect(function(player)
	PlayerState.init(player)
	syncHud(player)
	player.CharacterAdded:Connect(function()
		PlayerState.reset(player) -- 죽었다 살아나든 처음 입장이든 항상 풀피로 시작
		syncHud(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerState.clear(player)
end)

-- 범위 안에서 가장 가까운 플레이어의 캐릭터 루트파트. 없으면 nil.
local function findNearestPlayerRootInRange(position, maxRange)
	local nearestRoot, nearestPlayer, nearestDistance = nil, nil, math.huge

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			local distance = (rootPart.Position - position).Magnitude
			if distance <= maxRange and distance < nearestDistance then
				nearestRoot, nearestPlayer, nearestDistance = rootPart, player, distance
			end
		end
	end

	return nearestPlayer, nearestRoot
end

-- 목표 지점을 향해 이번 프레임만큼 XZ 평면으로 이동시킨다. Y는 몬스터 자기 높이를 유지한다
-- (플레이어 캐릭터 루트 높이를 그대로 쫓아가면 3D 시점에서도 위아래로 떠서 어색하다).
local function stepToward(model, currentPosition, targetPosition, speedStuds, dt)
	local delta = Vector3.new(targetPosition.X - currentPosition.X, 0, targetPosition.Z - currentPosition.Z)
	local distance = delta.Magnitude
	if distance < 0.01 then
		return
	end

	local step = math.min(speedStuds * dt, distance)
	local newPosition = currentPosition + delta.Unit * step
	model:PivotTo(CFrame.new(newPosition))
end

-- 몬스터 평타 1회가 실제로 얼마나 깎는지(감소율 적용 후). 체력바 눈금(9-5)과 실제
-- 피격 데미지가 같은 계산을 써야 눈금이 "몇 대"를 정확히 의미한다.
local function computeHitDamage(data)
	local reduction = CombatConfig.playerDefense / (CombatConfig.playerDefense + CombatConfig.damageReductionAlpha * data.attack)
	return data.attack * (1 - reduction)
end

-- 사거리 안이고 자기 쿨다운이 지났으면 플레이어를 때린다. 데미지는 PRD 확정 비율 모델
-- (뺄셈이 아니라 감소율 나눗셈)을 쓴다 - 웹에서 뺄셈으로 만들었던 무적 버그 구조를 피한다.
-- 9-5에서 피격 상한을 없앴다 - 상한은 즉사가 주는 "스펙이 모자란다"는 신호를 뭉갰다
-- (PRD-forge-game-roblox.md 20.11-4 참고).
local function tryAttack(model, data, monsterPosition, targetPlayer, targetRoot)
	if PlayerState.getHp(targetPlayer) <= 0 then
		return -- 죽어서 리스폰 대기 중인 시체는 때리지 않는다(사망 로그 중복 방지)
	end

	local distance = (targetRoot.Position - monsterPosition).Magnitude
	if distance > data.attackRangeStuds then
		return
	end

	local now = os.clock()
	local last = MonsterState.getLastAttackTick(model)
	if last and now - last < data.attackCooldownSeconds then
		return
	end
	MonsterState.setLastAttackTick(model, now)

	local damage = computeHitDamage(data)
	local newHp = math.max(PlayerState.getHp(targetPlayer) - damage, 0)
	PlayerState.setHp(targetPlayer, newHp)
	syncHud(targetPlayer)

	print(("[forge-game] 플레이어 피격: %s - %.2f 데미지 (남은 HP %.2f/%d)"):format(
		targetPlayer.Name, damage, newHp, PlayerState.getMaxHp(targetPlayer)))

	if newHp <= 0 then
		print(("[forge-game] 플레이어 사망: %s"):format(targetPlayer.Name))
		local character = targetPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			-- 실제 HP는 PlayerState가 관리한다. Humanoid.Health=0은 로블록스 리스폰
			-- 처리(사냥터에 이미 있는 SpawnLocation으로 자동 복귀)를 트리거하는 신호일 뿐이다.
			humanoid.Health = 0
		end
	end
end

RunService.Heartbeat:Connect(function(dt)
	for _, model in ipairs(MonsterState.getAllModels()) do
		local rootPart = model.PrimaryPart
		if rootPart then
			local position = rootPart.Position
			local home = MonsterState.getSpawnPosition(model)
			local data = MonsterState.getData(model)
			local state = MonsterState.getAiState(model)

			if state == "idle" then
				local player, playerRoot = findNearestPlayerRootInRange(position, WorldConfig.aggro.rangeStuds)
				if player then
					MonsterState.setAiState(model, "chasing")
					MonsterState.setAiTarget(model, player)
					state = "chasing"
					-- 체력바 눈금(9-5)은 "지금 상대하는 몬스터의 평타"다 - 전투 중 계속 바뀌면
					-- 혼란스러우니 어그로가 붙는 이 순간에만 값을 정하고, 전투가 끝날 때까지
					-- (아래 else 분기의 clear까지) 고정한다.
					player:SetAttribute("TickDamage", computeHitDamage(data))
				end
			end

			if state == "chasing" then
				local target = MonsterState.getAiTarget(model)
				local targetCharacter = target and target.Character
				local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
				local distanceFromHome = (position - home).Magnitude
				local targetIsDead = target and PlayerState.getHp(target) <= 0

				-- 추격을 그만두는 조건은 하나가 아니다 - 거리로 풀리는 것(리쉬)과 대상이
				-- 사라져서 풀리는 것(퇴장·사망)은 별개라 각각 따로 체크해야 한다. 아래
				-- targetIsDead를 빼고 거리만 봤다가 리스폰 직후 재사망 루프가 생겼었다(9-4).
				if not targetRoot or targetIsDead or distanceFromHome > WorldConfig.aggro.leashRangeStuds then
					-- 대상을 놓쳤거나(퇴장) 죽었거나(리스폰된 새 캐릭터를 이어서 쫓아가면 안 된다 -
					-- 스폰 지점이 리쉬 범위 안이면 즉시 재사망 루프가 생긴다) 집에서 너무
					-- 멀어졌다 - 포기하고 돌아간다.
					MonsterState.setAiState(model, "returning")
					MonsterState.setAiTarget(model, nil)
					if target then
						target:SetAttribute("TickDamage", 0) -- 전투 종료 - 눈금 기준을 지운다
					end
				else
					stepToward(model, position, targetRoot.Position, data.moveSpeedStuds, dt)
					tryAttack(model, data, position, target, targetRoot)
				end
			elseif state == "returning" then
				if (position - home).Magnitude <= 0.5 then
					model:PivotTo(CFrame.new(home))
					MonsterState.setAiState(model, "idle")
				else
					stepToward(model, position, home, data.moveSpeedStuds, dt)
				end
			end
		end
	end
end)
