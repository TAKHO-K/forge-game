-- M1-2 몬스터 스폰 범위(사용자: 넓은 범위 + 지나가면 생성 · 떠나면 정리). 구역마다 넓은 원 안에 흩어 둔 스폰 지점(shared/WorldMapLayout.huntPoints) -
-- 지점 activateRadius 안에 누가 들어오면 그 둘레 슬롯(group.count)에 몬스터를 세우고, keepRadius 안에 아무도 없이 idleSeconds가 지나면 치운다.
-- 정리 규칙(버그 방지 - 사용자): ① 반경 안에 아무도 없고 ② 시간이 지났고 ③ 그 지점 몬스터가 전투 중이 아닐 때만(어그로 대상 · combatHoldSeconds 안 피격이면 보류).
--   처치 판정 중인 몬스터(tryClaimDeath를 이미 누가 가져감 - 보상 처리 중)는 건드리지 않는다 → 보상 · 드랍 누락 0. 정리할 몬스터는 정리가 먼저 tryClaimDeath를 가져가
--   그 뒤 들어온 타격은 처치로 이어지지 않는다(경합 가드 공유). 파티원이 흩어져 있어도 지점마다 "누구든 가까이"라 각자 주변이 유지된다.
-- 개인 스테이지 수치(HP · 보상)는 그대로 - 여기서는 "있느냐 없느냐"만. 수치 = WorldMapData.spawnSites · 나오는 몬스터 = 구역 hunt.monsters(가중치).
-- 핵심 틱(SpawnSites.tick)은 훅을 받는다 - 실제 서버와 검증 시뮬(1,000 사이클)이 같은 코드를 돈다.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local MonsterSpawner = require(script.Parent.MonsterSpawner)
local MonsterState = require(script.Parent.MonsterState)

local SpawnSites = {}

local CFG = WorldMapData.spawnSites
local points = {} -- { zoneKey, index, position, monsters, slots = { { position, model } }, active, lastNearAt }
local slotByKey = {} -- ["x:z"] = { point, slot }
local rng = Random.new()

local function key(position)
	return ("%d:%d"):format(math.floor(position.X + 0.5), math.floor(position.Z + 0.5))
end

local function flatDistance(a, b)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- 순수(검증용): 지점 하나의 다음 상태. near = activateRadius 안 사람 수 · kept = keepRadius 안 사람 수 · engaged = 그 지점 몬스터가 전투 중인가.
-- 반환: active, lastNearAt(정리를 전투 때문에 미루면 active 그대로)
function SpawnSites.nextState(active, lastNearAt, near, kept, now, engaged)
	if near > 0 then
		return true, now
	end
	if active and kept > 0 then
		return true, now
	end
	if active and now - lastNearAt >= CFG.idleSeconds and not engaged then
		return false, lastNearAt
	end
	return active, lastNearAt
end

-- 가중치로 몬스터 데이터 하나(구역 hunt.monsters - M2에서 종이 늘면 목록만)
function SpawnSites.pickMonster(list, roll)
	local total = 0
	for _, m in ipairs(list) do
		total += m.weight
	end
	local x = (roll or rng:NextNumber()) * total
	for _, m in ipairs(list) do
		x -= m.weight
		if x <= 0 then
			return MonsterData[MonsterData.tierOrder[m.tier]]
		end
	end
	return MonsterData[MonsterData.tierOrder[list[#list].tier]]
end

-- 지점 목록 만들기(구역 순서 · 지점 순서 - 고정 시드라 매번 같다)
function SpawnSites.buildPoints()
	local list = {}
	for _, zone in ipairs(WorldMapData.zones) do
		for _, hp in ipairs(WorldMapLayout.huntPoints(zone)) do
			local point = { zoneKey = zone.key, index = hp.index, position = hp.position, monsters = zone.hunt.monsters, slots = {}, active = false, lastNearAt = -math.huge }
			for _, s in ipairs(hp.slots) do
				table.insert(point.slots, { position = Vector3.new(s.X, s.Y + 1.5, s.Z) }) -- M1-3: 슬롯 높이 = 지형 윗면(WorldMapLayout.huntPoints)
			end
			table.insert(list, point)
		end
	end
	return list
end

-- 핵심 틱: foci(사람 위치들) · now → 켜고 끄기. hooks = { spawn(point, slot) → model | nil, alive(model), engaged(model, now), claim(model) → bool, remove(model) }.
-- 반환: { spawned, cleared, held(전투라 미룸), dying(처치 판정 중이라 남김) }
function SpawnSites.tick(list, foci, now, hooks)
	local report = { spawned = 0, cleared = 0, held = 0, dying = 0, turnedOn = {}, turnedOff = {} }
	for _, point in ipairs(list) do
		local near, kept = 0, 0
		for _, p in ipairs(foci) do
			local d = flatDistance(p, point.position)
			if d <= CFG.activateRadius then
				near += 1
			end
			if d <= CFG.keepRadius then
				kept += 1
			end
		end
		local engaged = false
		if point.active and near == 0 and kept == 0 then
			for _, slot in ipairs(point.slots) do
				if slot.model and hooks.alive(slot.model) and hooks.engaged(slot.model, now) then
					engaged = true
					break
				end
			end
		end
		local wasActive = point.active
		if engaged and now - point.lastNearAt >= CFG.idleSeconds then
			report.held += 1 -- 비었고 시간도 지났지만 전투 중이라 미룬다
		end
		local active, lastNearAt = SpawnSites.nextState(point.active, point.lastNearAt, near, kept, now, engaged)
		point.lastNearAt = lastNearAt
		if active and not wasActive then
			point.active = true
			for _, slot in ipairs(point.slots) do
				if not (slot.model and hooks.alive(slot.model)) then
					slot.model = hooks.spawn(point, slot)
					report.spawned += slot.model and 1 or 0
				end
			end
			table.insert(report.turnedOn, point)
		elseif wasActive and not active then
			point.active = false
			for _, slot in ipairs(point.slots) do
				local model = slot.model
				slot.model = nil
				if model and hooks.alive(model) then
					if hooks.claim(model) then
						hooks.remove(model)
						report.cleared += 1
					else
						report.dying += 1 -- 처치 판정 중(보상 처리 중) - 그쪽이 치운다 · 지점이 꺼져 있어 되살리지 않는다
					end
				end
			end
			table.insert(report.turnedOff, point)
		end
	end
	return report
end

-- 실제 서버 훅
local liveHooks = {
	spawn = function(point, slot)
		local model = MonsterSpawner.spawn(SpawnSites.pickMonster(point.monsters), slot.position, point.zoneKey)
		if model then
			slotByKey[key(MonsterState.getSpawnPosition(model) or slot.position)] = { point = point, slot = slot }
		end
		return model
	end,
	alive = function(model)
		return model.Parent ~= nil and MonsterState.getData(model) ~= nil
	end,
	engaged = function(model, now)
		if MonsterState.getAiTarget(model) ~= nil or MonsterState.getAiState(model) == "chasing" then
			return true
		end
		local hitAt = MonsterState.getLastDamagedAt(model)
		return hitAt ~= nil and now - hitAt < CFG.combatHoldSeconds
	end,
	claim = function(model)
		return MonsterState.tryClaimDeath(model)
	end,
	remove = function(model)
		MonsterState.clear(model)
		model:Destroy()
	end,
}

local function foci()
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			table.insert(list, root.Position)
		end
	end
	for _, extra in ipairs(SpawnSites.debugFoci) do
		table.insert(list, extra)
	end
	for _, extra in ipairs(ReplicatedStorage:GetAttribute("DebugSpawnFoci") and string.split(ReplicatedStorage:GetAttribute("DebugSpawnFoci"), ";") or {}) do
		local x, z = extra:match("^(%-?[%d%.]+),(%-?[%d%.]+)$") -- 검증 · 성능(Studio): "x,z;x,z" 가짜 초점(execute_luau 모듈 사본 대신 Attribute)
		if x then
			table.insert(list, Vector3.new(tonumber(x), 0, tonumber(z)))
		end
	end
	return list
end

function SpawnSites.start()
	points = SpawnSites.buildPoints()
	-- 죽은 잡몹의 리스폰: 이 지점 슬롯이면 지점이 켜져 있을 때만 그 슬롯에 되살린다.
	MonsterSpawner.respawnHook = function(_, spawnPosition, zoneKey)
		local entry = slotByKey[key(spawnPosition)]
		if not entry or entry.point.zoneKey ~= zoneKey then
			return false
		end
		if entry.point.active and not (entry.slot.model and liveHooks.alive(entry.slot.model)) then
			entry.slot.model = liveHooks.spawn(entry.point, entry.slot)
		end
		return true
	end
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < CFG.checkSeconds then
			return
		end
		elapsed = 0
		local report = SpawnSites.tick(points, foci(), os.clock(), liveHooks)
		for _, p in ipairs(report.turnedOn) do
			print(("[forge-game] 스폰 지점 켜짐: %s-%d(%d마리)"):format(p.zoneKey, p.index, #p.slots))
		end
		for _, p in ipairs(report.turnedOff) do
			print(("[forge-game] 스폰 지점 정리: %s-%d"):format(p.zoneKey, p.index))
		end
		local activePoints, alive = SpawnSites.stats()
		ReplicatedStorage:SetAttribute("SpawnSitesActive", activePoints) -- 검증 · 성능 표(서버 상태를 Attribute로)
		ReplicatedStorage:SetAttribute("SpawnSitesAlive", alive)
	end)
	print(("[forge-game] 스폰 지점 %d곳 대기(구역당 %d · 활성 반경 %d · 유지 %d · 정리 %d초 · 전투 보류 %d초)"):format(#points, CFG.pointsPerRange, CFG.activateRadius, CFG.keepRadius, CFG.idleSeconds, CFG.combatHoldSeconds))
end

-- 검증 · 성능 측정용 가짜 초점(서버 가짜 플레이어 자리 - PerfProbe)
SpawnSites.debugFoci = {}

-- 지금 켜진 지점 수 · 살아 있는 지점 몬스터 수 · 전체 지점 수
function SpawnSites.stats()
	local activePoints, alive = 0, 0
	for _, point in ipairs(points) do
		if point.active then
			activePoints += 1
		end
		for _, slot in ipairs(point.slots) do
			if slot.model and slot.model.Parent then
				alive += 1
			end
		end
	end
	return activePoints, alive, #points
end

-- 누수 점검(검증): 꺼진 지점에 남은 몬스터 · 슬롯 밖 구역 잡몹(주인 없는 몬스터) 수
function SpawnSites.audit()
	local owned, leaks, orphans = {}, 0, 0
	for _, point in ipairs(points) do
		for _, slot in ipairs(point.slots) do
			if slot.model and slot.model.Parent then
				owned[slot.model] = true
				if not point.active then
					leaks += 1
				end
			end
		end
	end
	for _, model in ipairs(MonsterState.getAllModels()) do
		local data = MonsterState.getData(model)
		if data and not data.isBoss and not data.isChest and not MonsterState.isRescueTarget(model) and MonsterState.getZoneKey(model) and not owned[model] then
			orphans += 1
		end
	end
	return leaks, orphans
end

function SpawnSites.points()
	return points
end

return SpawnSites
