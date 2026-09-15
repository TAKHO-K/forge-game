-- 몬스터 추격·리쉬·반격. 이동은 XZ 직선(PathfindingService 안 씀 - 48마리가 경로를 재계산하면
-- 서버 프레임 예산의 10~20%를 상시 먹는다, PRD 20.49 [2]) + 지면 Raycast로 Y만 보정(22-4 -
-- 언덕·계단은 오르고, 경사 한계(TerrainConfig.maxSlopeDegrees)를 넘는 절벽·심연 앞에서는
-- 옆으로 비켜 가거나 멈춘다). 상수는 전부 TerrainConfig(단일 출처).
-- 어그로/리쉬 판정은 WorldConfig.aggro에서 유도한 값을 그대로 쓴다(관계식 근거는 그쪽 참고) -
-- 거리는 XZ 수평, 높이차는 Reach.sameLayer 상한으로 따로 자른다(20-4 사슬 보존, Reach.lua 주석).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local TerrainConfig = require(ReplicatedStorage.Shared.data.TerrainConfig)
local ZoneBounds = require(ReplicatedStorage.Shared.ZoneBounds)
local Reach = require(ReplicatedStorage.Shared.Reach)
local GroundProbe = require(script.Parent.GroundProbe)
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
			-- 22-4: 수평 거리 + 높이차 상한(Reach). 절벽 위 플레이어는 어그로 대상이 아니다.
			local distance = Reach.horizontalDistance(rootPart.Position, position)
			if distance <= maxRange and distance < nearestDistance
				and Reach.sameLayer(rootPart.Position, position) then
				nearestRoot, nearestPlayer, nearestDistance = rootPart, player, distance
			end
		end
	end

	return nearestPlayer, nearestRoot
end

-- ═══ 지면 추적(22-4) ═══
-- 이동 방향 probeAhead(2stud) 앞의 지면 Y를 GroundProbe로 묻고, 그 결과를 probeInterval(0.1초)
-- 동안 캐시한다 - 이동 중인 몬스터만 쏘므로(idle 0회) 최악(54마리 전부 추격)에도 초당 540회다.
-- 캐시는 방향이 크게 바뀌면(dot < 0.95) 즉시 무효 - 추격 대상이 옆으로 빠졌을 때 옛 방향의
-- 지면을 믿고 걷지 않는다. 키를 model로 하는 weak 테이블이라 몬스터가 사라지면 같이 지워진다.
local groundCache = setmetatable({}, { __mode = "k" })
local blockedSince = setmetatable({}, { __mode = "k" }) -- returning 중 막힌 시각(순간이동 복귀 판단)

-- dir 방향 2stud 앞의 지면 Y. 계단 한 단(maxStepHeight)보다 큰 단차(오르내림 양방향)거나
-- 지면이 없으면(심연·절벽) nil = 그쪽으로는 못 간다.
local function groundAhead(footY, position, dir)
	local ahead = position + dir * TerrainConfig.probeAheadStuds
	local groundY = GroundProbe.groundY(ahead.X, ahead.Z, footY)
	if groundY == nil or math.abs(groundY - footY) > TerrainConfig.maxStepHeightStuds then
		return nil
	end
	return groundY
end

-- 이번 틱에 실제로 갈 방향과 그 앞 지면 Y. 정면이 막히면 좌우 수직 방향 중 목표에 더
-- 가까워지는 쪽으로 비켜 간다(옆으로 미끄러짐). 둘 다 막히면 blocked - 제자리.
local function resolveGround(model, position, dir, targetPosition, now)
	local cached = groundCache[model]
	if cached and now - cached.at < TerrainConfig.probeIntervalSeconds and cached.dir:Dot(dir) > 0.95 then
		return cached
	end

	local footY = position.Y - TerrainConfig.monsterFootOffsetStuds
	-- 지금 발밑 지면(Y 목표) + 앞 지면(막힘·경사 판정)을 따로 잰다 - 앞 지면으로 Y를 맞추면
	-- 내려갈 때 비탈에 1stud쯤 박히고 오를 때 뜬다(22-4 실측: 30° 경사로에서 -0.9). 여기 Y는
	-- 발밑 지면을 못 찾으면(막 절벽 끝에 걸친 순간) 현재 발 높이를 유지한다.
	local groundHereY = GroundProbe.groundY(position.X, position.Z, footY) or footY
	local moveDir, groundY = dir, groundAhead(footY, position, dir)
	if groundY == nil then
		local left = Vector3.new(-dir.Z, 0, dir.X)
		local candidates = { left, -left }
		local bestDistance = math.huge
		moveDir = nil
		for _, sideDir in ipairs(candidates) do
			local sideGround = groundAhead(footY, position, sideDir)
			if sideGround then
				local after = position + sideDir * TerrainConfig.probeAheadStuds
				local distanceAfter = Reach.horizontalDistance(after, targetPosition)
				if distanceAfter < bestDistance then
					bestDistance = distanceAfter
					moveDir, groundY = sideDir, sideGround
				end
			end
		end
	end

	local result = { at = now, dir = dir, moveDir = moveDir, groundY = groundHereY, blocked = moveDir == nil }
	groundCache[model] = result
	return result
end

-- 목표 지점을 향해 이번 프레임만큼 XZ 평면으로 이동시키고, Y는 발밑 지면 위(발 오프셋)로
-- 맞춘다. Y 변화 속도는 speed×tan(경사한계)(45°면 수평 속도와 같다)로 제한해 계단 한 단도
-- 순간이동이 아니라 짧은 오름으로 보이게 한다. 평지에서는 발밑 지면 Y == 지금 발 Y라 dy=0 -
-- 떨림이 없다(22-4 검증 9).
-- 반환: "목표 쪽으로 전진했는가"(true/false). 정면이 막혀 옆으로 비켜 간 틱은 false다 -
-- 호출부의 "막힘 시간" 계산에 옆걸음도 포함시키기 위해서다(22-4 실측: 도랑 가장자리에서
-- 옆걸음만 8초 넘게 반복 - 전진이 아니면 진행이 아니다). 실제로 위치가 바뀌었는지와는 다르다.
local function stepToward(model, currentPosition, targetPosition, speedStuds, dt)
	local delta = Vector3.new(targetPosition.X - currentPosition.X, 0, targetPosition.Z - currentPosition.Z)
	local distance = delta.Magnitude
	if distance < 0.01 then
		return true
	end

	local ground = resolveGround(model, currentPosition, delta.Unit, targetPosition, os.clock())
	if ground.blocked then
		return false
	end

	local step = math.min(speedStuds * dt, distance)
	local horizontal = currentPosition + ground.moveDir * step
	local targetY = ground.groundY + TerrainConfig.monsterFootOffsetStuds
	local maxDy = speedStuds * TerrainConfig.maxSlopeTangent * dt
	local dy = math.clamp(targetY - currentPosition.Y, -maxDy, maxDy)
	model:PivotTo(CFrame.new(horizontal.X, currentPosition.Y + dy, horizontal.Z))
	return ground.moveDir == ground.dir
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

	-- 22-4: 수평 사거리 + 높이차 상한 - 절벽 위아래로는 못 때린다(Reach.lua).
	if not Reach.within(targetRoot.Position, monsterPosition, data.attackRangeStuds) then
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
	if Reach.horizontalDistance(targetRoot.Position, monsterPosition) > data.chaseStopDistanceStuds then
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

			-- 보물상자(22-2 [3])는 몬스터가 아니다 - 어그로·추격·반격 전부 없다. 조준·피격
			-- 경로만 공유하려고 MonsterState에 등록돼 있을 뿐이다.
			if data.isChest then
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
				-- 22-4: 리쉬는 XZ 수평 거리 - 언덕을 오르내려도 38.4가 그대로다(3D면 경사에서 줄어든다).
				local distanceFromHome = Reach.horizontalDistance(position, home)
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
				-- 22-4: 네 번째 출구 - 대상이 높이차 상한(8) 너머로 올라갔거나 내려갔다(절벽 위아래).
				-- 못 때리는 대상을 절벽 밑에서 영원히 노려보는 대신 집으로 돌아간다.
				if not targetRoot or targetIsDead
					or (not data.isBoss and distanceFromHome > WorldConfig.aggro.leashRangeStuds)
					or isOutsideZoneBounds(position, zoneKey)
					or (targetRoot and not Reach.sameLayer(position, targetRoot.Position)) then
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
					-- 이동속도는 접두사 변종 배율이 곱해진 인스턴스 값(22-2 [1], MonsterState.getMoveSpeed).
					local moved = stepToward(model, position, decoyPosition or targetRoot.Position, MonsterState.getMoveSpeed(model), dt)
					if not decoyPosition then
						tryAttack(model, data, position, target, targetRoot)
					end
					-- 22-4: 절벽·심연 앞에서 전진하지 못한 채(제자리든 옆걸음이든) 일정 시간이 지나면 추격을
					-- 포기한다 - 리쉬 거리 안이라 다른 출구가 하나도 안 열리는 상태로 절벽 끝에서 영원히
					-- 서성이는 것을 막는다(22-4 실측: 고원 끝·도랑 가장자리에서 ±Z 왕복). 복귀 순간이동과
					-- 같은 3초 - 바위 하나(폭 ≤ 8)를 비켜 가는 데는 1초가 안 걸리므로 정상 우회는 안 끊는다.
					if moved then
						blockedSince[model] = nil
					else
						blockedSince[model] = blockedSince[model] or os.clock()
						if os.clock() - blockedSince[model] >= TerrainConfig.returningStuckTeleportSeconds then
							MonsterState.setAiState(model, "returning")
							MonsterState.setAiTarget(model, nil)
							target:SetAttribute("TickDamage", 0)
							blockedSince[model] = nil
						end
					end
					-- 분신 쪽으로 도는 동안(decoyPosition ~= nil)은 다가가 제자리에 머물 뿐
					-- 아무에게도 피해를 주지 않는다(PRD 4.3 "적을 도발해 어그로 유지" - 분신은
					-- 피격판정이 없다, 웹 main.js의 "target.isPlayer일 때만 데미지" 분기와 같다).
				end
			elseif state == "returning" then
				if Reach.horizontalDistance(position, home) <= 0.5 then
					model:PivotTo(CFrame.new(home))
					MonsterState.setAiState(model, "idle")
					blockedSince[model] = nil
				elseif stepToward(model, position, home, MonsterState.getMoveSpeed(model), dt) then
					blockedSince[model] = nil
				else
					-- 22-4: 복귀 직선이 절벽·심연에 막혔다 - 나갈 때 비켜 간 경로가 돌아올 때는 없다.
					-- 잠깐은 옆으로 비켜 보게 두고(resolveGround), 그래도 전진 못 한 채 시간이 지나면 집으로
					-- 순간이동한다(TerrainConfig.returningStuckTeleportSeconds).
					local now = os.clock()
					blockedSince[model] = blockedSince[model] or now
					if now - blockedSince[model] >= TerrainConfig.returningStuckTeleportSeconds then
						model:PivotTo(CFrame.new(home))
						MonsterState.setAiState(model, "idle")
						blockedSince[model] = nil
					end
				end
			end
		end
	end
end)
