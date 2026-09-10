-- 몬스터 추격·리쉬·반격. 이동은 직선(PathfindingService 안 씀 - 사냥터에 장애물이 없다).
-- 어그로/리쉬 판정은 WorldConfig.aggro에서 유도한 값을 그대로 쓴다(관계식 근거는 그쪽 참고).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local Loot = require(ReplicatedStorage.Shared.Loot)
local MonsterState = require(script.Parent.MonsterState)
local MonsterSpawner = require(script.Parent.MonsterSpawner)
local PlayerState = require(script.Parent.PlayerState)
local PlayerProfile = require(script.Parent.PlayerProfile)

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

-- 추격 상태를 빠져나오는 출구는 셋이다(20.24-1이 드러낸 세 번째 - 9-4가 거리·사망 둘을
-- 각각 따로 체크해야 한다고 못박았는데 퇴장이 빠져 있었다): 거리 초과(리쉬) / 대상 사망 /
-- 대상 퇴장. 이 함수가 세 번째(퇴장)를 처리한다 - "떠나는 쪽이 자기 흔적을 지운다"는
-- 원칙으로, PlayerState.clear보다 먼저 이 플레이어를 쫓던 몬스터를 전부 "returning"으로
-- 되돌려 다음 Heartbeat 틱에 이 플레이어를 가리키는 aiTarget이 하나도 안 남게 한다(1차
-- 방어 - 아래 chasing 분기의 nil 가드는 2차 방어선일 뿐, 이게 먼저다). 다음에 네 번째
-- 출구가 생기면 이 목록에 추가할 것.
local function releaseChasersOf(player)
	for _, model in ipairs(MonsterState.getAllModels()) do
		if MonsterState.getAiTarget(model) == player then
			MonsterState.setAiState(model, "returning")
			MonsterState.setAiTarget(model, nil)
		end
	end
end

Players.PlayerRemoving:Connect(function(player)
	releaseChasersOf(player)
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
-- 방어력은 클래스 배율이 걸린다(10-3 [3] - 대검 1.3배로 더 튼튼하고 활 0.6배로 더 약하다).
-- 클래스를 아직 안 고른 순간(접속 직후 선택 UI가 뜨기 전)은 배율 없는 기본값으로 방어한다.
-- attack은 호출부가 MonsterState.getAttack(model)로 넘긴다 - 무한 모드 스테이지 배율(11-1)이
-- 이미 적용된 값이라 여기선 그대로 쓰기만 한다. 장비 방어력(12-1 [4])은 착용한 갑옷이
-- 있으면 Loot.getArmorDefense가 계산하고, 없으면 0 - PlayerCombat.getDefense가
-- "(기본값 + 장비 보너스) 전체에 클래스 배율을 곱한다"는 9-4/10-3 원칙을 그대로 지킨다.
local function computeHitDamage(attack, targetPlayer)
	local classId = PlayerProfile.getClassId(targetPlayer)
	local armorBonus = Loot.getArmorDefense(PlayerProfile.getEquippedArmor(targetPlayer))
	local defense = classId and PlayerCombat.getDefense(classId, armorBonus) or CombatConfig.playerDefense
	local reduction = defense / (defense + CombatConfig.damageReductionAlpha * attack)
	return attack * (1 - reduction)
end

-- 데미지 적용 + 사망 처리 - tryAttack(잡몹·보스 평타)과 tryBossAttack(보스 예고 일격,
-- 15-1)이 공유하는 유일한 지점이다. "때릴지 말지"(사거리·쿨다운)는 호출부마다 다르지만,
-- "맞은 뒤에 뭘 하는가"는 공격 종류와 무관하게 항상 같다.
local function applyHitToPlayer(targetPlayer, rawAttack)
	local damage = computeHitDamage(rawAttack, targetPlayer)
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

	applyHitToPlayer(targetPlayer, MonsterState.getAttack(model))
end

-- 추격을 놓치는 순간(대상 사망·퇴장·리쉬) 보스가 telegraph 도중이었으면 원상복구한다 -
-- 안 하면 다음에 다시 어그로를 잡았을 때 이미 지난 예고 시각이 그대로 남아 재회 즉시
-- "공짜 강타"가 나가거나, 색이 경고색으로 멈춘 채 남는다.
local function resetBossPhaseIfNeeded(model, data)
	if not data.isBoss or MonsterState.getBossPhase(model) ~= "telegraph" then
		return
	end
	MonsterState.setBossPhase(model, "normal")
	MonsterState.setBossNextHeavyAt(model, os.clock() + data.heavyAttackIntervalSeconds)
	local body = model:FindFirstChild("Body")
	if body then
		body.Color = data.bodyColor
	end
end

-- 보스 전용 - 예고 후 강한 일격(15-1, 지시 [3]에서 고른 유일한 긴장 장치). 평상시엔
-- tryAttack과 완전히 같은 평타를 쓰다가, heavyAttackIntervalSeconds마다 한 번 "telegraph"
-- 단계로 들어간다: telegraphWarmupSeconds 동안 제자리에 멈춰 색이 바뀌고(경고), 그 시간이
-- 끝나는 순간 그 자리에 있던 플레이어만 heavyAttack(평타의 3배, 즉사급)을 맞는다 -
-- 로블록스에 아직 웹의 대시·무적시간이 없으므로, 걸어서 attackRangeStuds 밖으로
-- 벗어나는 것만으로 피할 수 있게 telegraphWarmupSeconds를 충분히 준다(플레이어 걷기
-- 속도 16stud/s 기준 사거리 14stud를 벗어나기엔 1.5초로 넉넉하다).
local function tryBossAttack(model, data, monsterPosition, targetPlayer, targetRoot, dt)
	local phase = MonsterState.getBossPhase(model)

	if phase == "telegraph" then
		local endsAt = MonsterState.getBossPhaseEndsAt(model)
		if os.clock() < endsAt then
			return -- 멈춰서 경고하는 중 - 움직이지도, 평타를 넣지도 않는다
		end

		-- 예고가 끝나는 이 순간의 거리만 본다 - 그 사이 벗어났으면 완전히 무효(빗나감).
		if PlayerState.getHp(targetPlayer) > 0 then
			local distance = (targetRoot.Position - monsterPosition).Magnitude
			if distance <= data.attackRangeStuds then
				applyHitToPlayer(targetPlayer, data.heavyAttack)
			end
		end

		MonsterState.setBossPhase(model, "normal")
		local body = model:FindFirstChild("Body")
		if body then
			body.Color = data.bodyColor
		end
		MonsterState.setBossNextHeavyAt(model, os.clock() + data.heavyAttackIntervalSeconds)
		MonsterState.setLastAttackTick(model, os.clock()) -- 예고 직후 바로 평타가 또 나가지 않게
		return
	end

	-- phase == "normal": 예고를 시작할 시점이 됐으면 멈춰 서서 경고색으로 바뀐다.
	if os.clock() >= MonsterState.getBossNextHeavyAt(model) then
		MonsterState.setBossPhase(model, "telegraph")
		MonsterState.setBossPhaseEndsAt(model, os.clock() + data.telegraphWarmupSeconds)
		local body = model:FindFirstChild("Body")
		if body then
			body.Color = data.telegraphColor
		end
		return
	end

	stepToward(model, monsterPosition, targetRoot.Position, data.moveSpeedStuds, dt)
	tryAttack(model, data, monsterPosition, targetPlayer, targetRoot)
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

					-- 무한 모드 스테이지 배율(11-1) - 어그로가 붙는 이 순간에 상대 플레이어의
					-- 현재 스테이지로 이 몬스터 인스턴스를 다시 스케일한다(이미 피해를 입은
					-- 몬스터는 MonsterState.setStage가 조용히 건너뛴다 - 그쪽 주석 참고).
					MonsterState.setStage(model, PlayerProfile.getInfiniteStage(player) or 1)
					MonsterSpawner.updateHpLabel(model)
					-- 체력바 눈금(9-5)은 "지금 상대하는 몬스터의 평타"다 - 전투 중 계속 바뀌면
					-- 혼란스러우니 어그로가 붙는 이 순간에만 값을 정하고, 전투가 끝날 때까지
					-- (아래 else 분기의 clear까지) 고정한다.
					player:SetAttribute("TickDamage", computeHitDamage(MonsterState.getAttack(model), player))
				end
			end

			if state == "chasing" then
				local target = MonsterState.getAiTarget(model)
				local targetCharacter = target and target.Character
				local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
				local distanceFromHome = (position - home).Magnitude
				-- 2차 방어선(1차는 위 releaseChasersOf) - target이 있는데도 PlayerState 항목이
				-- 이미 지워져 nil을 돌려주는 경우를 죽은 것과 동일하게 취급한다. 1차 방어가
				-- 정상 작동하면 이 경로는 절대 안 타지만, 앞으로 PlayerState.clear가 호출되는
				-- 다른 경로가 생겨도(1차 방어를 안 거치는 경로) 여기서 막아 크래시를 방지한다.
				local targetHp = target and PlayerState.getHp(target)
				local targetIsDead = target ~= nil and (targetHp == nil or targetHp <= 0)

				-- 추격을 그만두는 조건은 하나가 아니다 - 거리 초과(리쉬) / 대상 사망 / 대상
				-- 퇴장, 이 셋은 서로 별개라 각각 따로 체크해야 한다(퇴장은 releaseChasersOf가
				-- 1차로 처리하지만, targetIsDead의 nil 가드가 그 경로를 놓쳐도 여기서 다시
				-- 잡는다). 아래 targetIsDead를 빼고 거리만 봤다가 리스폰 직후 재사망 루프가
				-- 생겼었다(9-4).
				if not targetRoot or targetIsDead or distanceFromHome > WorldConfig.aggro.leashRangeStuds then
					-- 대상을 놓쳤거나(퇴장) 죽었거나(리스폰된 새 캐릭터를 이어서 쫓아가면 안 된다 -
					-- 스폰 지점이 리쉬 범위 안이면 즉시 재사망 루프가 생긴다) 집에서 너무
					-- 멀어졌다 - 포기하고 돌아간다.
					MonsterState.setAiState(model, "returning")
					MonsterState.setAiTarget(model, nil)
					resetBossPhaseIfNeeded(model, data)
					if target then
						target:SetAttribute("TickDamage", 0) -- 전투 종료 - 눈금 기준을 지운다
					end
				elseif data.isBoss then
					tryBossAttack(model, data, position, target, targetRoot, dt)
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
