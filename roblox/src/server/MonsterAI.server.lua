-- 몬스터 추격·리쉬·반격. 이동은 직선(PathfindingService 안 씀 - 사냥터에 장애물이 없다).
-- 어그로/리쉬 판정은 WorldConfig.aggro에서 유도한 값을 그대로 쓴다(관계식 근거는 그쪽 참고).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local ZoneBounds = require(ReplicatedStorage.Shared.ZoneBounds)
local MonsterState = require(script.Parent.MonsterState)
local PlayerState = require(script.Parent.PlayerState)
local PlayerProfile = require(script.Parent.PlayerProfile)
local SummonState = require(script.Parent.SummonState)
-- 21-3: 피격 계산·적용(computeHitDamage/applyHitToPlayer/syncHud)은 PlayerDamage.lua로
-- 옮겼다 - 보스 패턴(BossPatterns.lua)이 같은 경로로 피해를 넣어야 해서다. 동작은 그대로다.
local PlayerDamage = require(script.Parent.PlayerDamage)
local BossPatterns = require(script.Parent.BossPatterns)

local syncHud = PlayerDamage.syncHud

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

-- 구역 소속 판정(16-6) - "구역 경계가 리쉬의 상한이다. 거리로만 계산하지 말고 구역
-- 소속으로 판정해라"(지시 그대로). ZoneBounds.lua로 뽑아냈다(19-4) - AttackServer.
-- server.lua의 "구역 밖에서는 공격이 안 들어간다" 판정이 같은 식을 재사용해야 해서다.
local function isOutsideZoneBounds(position, zoneKey)
	return not ZoneBounds.isInside(position, zoneKey)
end

-- 지금 플레이어가 서 있는 tier 구역들의 집합(16-6 성능 절전 - 지시 "플레이어가 없는
-- 구역은... AI를 정지시켜라"). Heartbeat 한 틱에 한 번만 계산해서 그 틱의 모든 몬스터가
-- 재사용한다(몬스터마다 다시 계산하면 의미가 없다). idle 상태 스캔만 건너뛴다 - 이미
-- chasing/returning 중인 몬스터는 그 구역이 방금 비었어도 하던 행동을 끝까지 마친다
-- (갑자기 얼어붙는 것보다 자연스럽고, 어차피 리쉬·구역 이탈 조건으로 곧 스스로 끝난다).
local function computeOccupiedZones()
	local occupied = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			local position = rootPart.Position
			for _, zoneKey in ipairs(WorldConfig.tierZoneOrder) do
				if not occupied[zoneKey] then
					local zone = WorldConfig.zones[zoneKey]
					if math.abs(position.X - zone.center.X) <= zone.halfSize
						and math.abs(position.Z - zone.center.Z) <= zone.halfSize then
						occupied[zoneKey] = true
					end
				end
			end
		end
	end
	return occupied
end

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

-- attack은 호출부가 MonsterState.getAttackFor(model, targetPlayer의 stage)로 넘긴다(19-4,
-- C안 - 잡몹은 공유 자원이라 "몬스터가 가진 stage"가 없다. 맞는 그 순간 상대 플레이어의
-- stage로 매번 새로 계산한다, MonsterState.lua 주석 참고). 감소식 자체는 PlayerDamage.lua.
local computeHitDamage = PlayerDamage.computeHitDamage
local applyHitToPlayer = PlayerDamage.applyHit

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

	local targetStage = PlayerProfile.getInfiniteStage(targetPlayer) or 1
	applyHitToPlayer(targetPlayer, MonsterState.getAttackFor(model, targetStage))
end

-- 보스 전용(15-1 → 21-3에서 BossPatterns.lua로 일반화). 패턴(강공격·진동파·낙석·돌진·
-- 십자 화염)이 진행 중이면 BossPatterns.step이 true를 돌려주고 보스는 그 자리에 구속된다 -
-- 평상시(false)엔 잡몹과 완전히 같은 추격·평타다. 어떤 패턴이 언제 시작되는지(간격·겹침
-- 방지)는 전부 BossPatterns의 스케줄러가 정한다.
local function tryBossAttack(model, data, monsterPosition, targetPlayer, targetRoot, dt)
	if BossPatterns.step(model, data, monsterPosition, targetPlayer, targetRoot, dt) then
		return
	end
	-- 정지 거리(BossData.chaseStopDistanceStuds) 밖에서만 다가간다 - 몸통 충돌이 없는 보스가
	-- 플레이어와 겹치지 않게(21-3).
	if (targetRoot.Position - monsterPosition).Magnitude > data.chaseStopDistanceStuds then
		stepToward(model, monsterPosition, targetRoot.Position, data.moveSpeedStuds, dt)
	end
	tryAttack(model, data, monsterPosition, targetPlayer, targetRoot)
end

RunService.Heartbeat:Connect(function(dt)
	local occupiedZones = computeOccupiedZones()

	for _, model in ipairs(MonsterState.getAllModels()) do
		local rootPart = model.PrimaryPart
		if rootPart then
			local position = rootPart.Position
			local home = MonsterState.getSpawnPosition(model)
			local data = MonsterState.getData(model)
			local state = MonsterState.getAiState(model)
			local zoneKey = MonsterState.getZoneKey(model)

			-- zoneKey가 있는데(구역 소속 잡몹) 그 구역이 비어 있으면 idle 스캔 자체를
			-- 건너뛴다 - 위 computeOccupiedZones 주석 참고. 보스는 예외다(20-2b) -
			-- computeOccupiedZones가 tierZoneOrder만 보므로 보스 아레나는 항상
			-- occupiedZones에 없어(never populated) 이 조건에 안 걸리면 보스가 영원히
			-- idle에 갇힌다 - 아레나엔 몬스터가 하나뿐이라 이 최적화 자체가 필요 없다.
			if state == "idle" and not data.isBoss and zoneKey and not occupiedZones[zoneKey] then
				continue
			end

			if state == "idle" then
				local player, playerRoot = findNearestPlayerRootInRange(position, WorldConfig.aggro.rangeStuds)
				if player then
					MonsterState.setAiState(model, "chasing")
					MonsterState.setAiTarget(model, player)
					state = "chasing"

					-- 체력바 눈금(9-5)은 "지금 상대하는 몬스터의 평타"다 - 전투 중 계속 바뀌면
					-- 혼란스러우니 어그로가 붙는 이 순간에만 값을 정하고, 전투가 끝날 때까지
					-- (아래 else 분기의 clear까지) 고정한다.
					local aggroStage = PlayerProfile.getInfiniteStage(player) or 1
					player:SetAttribute("TickDamage", computeHitDamage(MonsterState.getAttackFor(model, aggroStage), player))
					if data.isBoss then
						BossPatterns.onAggro(model, data) -- 패턴 시계는 전투가 붙는 순간부터(21-3)
					end
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
				-- 21-3: 보스는 거리 리쉬(38.4)를 보지 않는다 - 돌진(패턴 3)이 아레나 벽(중심에서
				-- 92stud)까지 달리므로 거리 리쉬가 매 돌진마다 "집으로 복귀"를 일으킨다. 아레나는
				-- 4면이 막힌 개인 공간이라 구역 경계(zoneKey) 조건만으로 충분하다.
				if not targetRoot or targetIsDead
					or (not data.isBoss and distanceFromHome > WorldConfig.aggro.leashRangeStuds)
					or isOutsideZoneBounds(position, zoneKey) then
					-- 대상을 놓쳤거나(퇴장) 죽었거나(리스폰된 새 캐릭터를 이어서 쫓아가면 안 된다 -
					-- 스폰 지점이 리쉬 범위 안이면 즉시 재사망 루프가 생긴다) 집에서 너무
					-- 멀어졌거나(리쉬), 구역 경계를 벗어났다(16-6 - 구역 경계가 리쉬의 진짜
					-- 상한이다. 넓은 구역 가장자리 몬스터는 리쉬 거리(38.4)보다 먼저 경계에
					-- 닿을 수 있다) - 포기하고 돌아간다.
					MonsterState.setAiState(model, "returning")
					MonsterState.setAiTarget(model, nil)
					if data.isBoss then
						BossPatterns.interrupt(model, data)
					end
					if target then
						target:SetAttribute("TickDamage", 0) -- 전투 종료 - 눈금 기준을 지운다
					end
				elseif data.isBoss then
					tryBossAttack(model, data, position, target, targetRoot, dt)
				else
					-- 쌍검 Q 그림자분신(20-6 [2]) - "이미 쫓기는 중인" 몹의 방향만 분신 쪽으로
					-- 돌린다(도발이지 신규 어그로 획득이 아니다 - idle→chasing 진입은 위에서
					-- 항상 실제 플레이어 거리만 본다, 웹 core/aggro.js의 같은 원칙을 재사용).
					-- aiTarget 자체는 절대 바꾸지 않는다 - 분신이 소멸하면 다음 틱에 이 조회가
					-- 그냥 nil을 돌려줘 실제 플레이어로 자연히 돌아온다(분신을 직접 참조하는
					-- 상태가 MonsterState 어디에도 남지 않으므로, 지시 [1]이 우려한 "소환체
					-- 소멸 시 nil 참조" 사고 자체가 구조적으로 생기지 않는다).
					local decoyPosition = SummonState.getPosition(target, "dualbladeDecoy")
					stepToward(model, position, decoyPosition or targetRoot.Position, data.moveSpeedStuds, dt)
					if not decoyPosition then
						tryAttack(model, data, position, target, targetRoot)
					end
					-- 분신 쪽으로 도는 동안(decoyPosition ~= nil)은 다가가 제자리에 머물 뿐
					-- 아무에게도 피해를 주지 않는다(PRD 4.3 "적을 도발해 어그로 유지" - 분신은
					-- 피격판정이 없다, 웹 main.js의 "target.isPlayer일 때만 데미지" 분기와 같다).
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
