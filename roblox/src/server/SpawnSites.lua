-- M1-2 몬스터 스폰 범위(사용자: 넓은 범위 + 지나가면 생성 · 떠나면 정리). 구역마다 넓은 원 안에 흩어 둔 스폰 지점(shared/WorldMapLayout.huntPoints) -
-- 지점 activateRadius 안에 누가 들어오면 그 둘레 슬롯에 무리(M1-4 - 구역 groupSizes 표로 3 ~ 5마리)를 세우고, keepRadius 안에 아무도 없이 idleSeconds가 지나면 치운다.
-- M1-4 상한: 서버 전체 지점 몬스터 caps.maxMonsters · 사람당 동시 켜진 무리 caps.maxGroupsPerPlayer(가장 가까운 사람 몫 · 가까운 지점부터) - 넘으면 켜지 않고 기다린다.
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

-- 무리 크기 뽑기(구역 표 · 없으면 default) - roll 0 ~ 1
function SpawnSites.pickSize(zoneKey, roll)
	local tbl = CFG.groupSizes[zoneKey] or CFG.groupSizes.default
	local total = 0
	for _, e in ipairs(tbl) do
		total += e[2]
	end
	local x = (roll or rng:NextNumber()) * total
	for _, e in ipairs(tbl) do
		x -= e[2]
		if x <= 0 then
			return math.min(e[1], CFG.group.maxSize)
		end
	end
	return math.min(tbl[#tbl][1], CFG.group.maxSize)
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

-- 핵심 틱: foci(사람 위치들) · now → 켜고 끄기. hooks = { spawn(point, slot) → model | nil, alive(model), engaged(model, now), claim(model) → bool, remove(model), size(point) → 마릿수(없으면 표에서 뽑기) }.
-- 반환: { spawned, cleared, held(전투라 미룸), dying(처치 판정 중이라 남김), capped(상한이라 안 켬), turnedOn, turnedOff }
-- 순서(M1-4): 가장 가까운 사람까지 거리 순으로 본다 - 상한에 걸리면 먼 지점이 기다린다.
function SpawnSites.tick(list, foci, now, hooks)
	local report = { spawned = 0, cleared = 0, held = 0, dying = 0, capped = 0, turnedOn = {}, turnedOff = {} }
	local caps = CFG.caps
	-- 지점마다 가장 가까운 사람 · 거리
	local order = {}
	local alive = 0
	for _, point in ipairs(list) do
		local best, bestD = nil, math.huge
		for fi, p in ipairs(foci) do
			local d = flatDistance(p, point.position)
			if d < bestD then
				best, bestD = fi, d
			end
		end
		point.nearFocus, point.nearD = best, bestD
		table.insert(order, point)
		for _, slot in ipairs(point.slots) do
			if slot.model and hooks.alive(slot.model) then
				alive += 1
			end
		end
	end
	table.sort(order, function(a, b)
		if a.nearD ~= b.nearD then
			return a.nearD < b.nearD
		end
		if a.zoneKey ~= b.zoneKey then
			return a.zoneKey < b.zoneKey
		end
		return a.index < b.index
	end)
	-- 사람마다 지금 곁(활성 반경 안)에 켜진 무리 수 · 그중 가장 가까운 거리(가장 가까운 사람 몫). 지나온 무리(유지 반경에서 정리를 기다리는 것)는 세지 않는다 -
	-- 그걸 세면 걷는 사람 앞 지점이 영영 안 켜졌다(M1-4 사냥꾼 시뮬).
	local groups, groupMinD = {}, {}
	for _, point in ipairs(order) do
		if point.active and point.nearFocus and point.nearD <= CFG.activateRadius then
			local f = point.nearFocus
			groups[f] = (groups[f] or 0) + 1
			groupMinD[f] = math.min(groupMinD[f] or math.huge, point.nearD)
		end
	end
	for _, point in ipairs(order) do
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
			local size = (hooks.size and hooks.size(point)) or SpawnSites.pickSize(point.zoneKey)
			local f = point.nearFocus
			-- 사람 몫이 찼어도 새 지점이 곁의 무리보다 더 가까우면 켠다(앞으로 걸어가는 사람) - 전체 상한은 늘 지킨다
			local full = f and (groups[f] or 0) >= caps.maxGroupsPerPlayer and point.nearD >= (groupMinD[f] or math.huge)
			if full or alive + size > caps.maxMonsters then
				report.capped += 1 -- 상한: 켜지 않고 기다린다(다음 틱에 다시 본다)
			else
				point.active, point.size = true, size
				if f and point.nearD <= CFG.activateRadius then
					groups[f] = (groups[f] or 0) + 1
					groupMinD[f] = math.min(groupMinD[f] or math.huge, point.nearD)
				end
				for i, slot in ipairs(point.slots) do
					slot.used = i <= size
					if slot.used and not (slot.model and hooks.alive(slot.model)) then
						slot.model = hooks.spawn(point, slot)
						report.spawned += slot.model and 1 or 0
						alive += slot.model and 1 or 0
					end
				end
				table.insert(report.turnedOn, point)
			end
		elseif active and wasActive then
			-- 상한 때 건너뛴 리스폰 자리를 여유가 생기면 채운다(가까운 사람 순서 그대로)
			for _, slot in ipairs(point.slots) do
				if slot.capSkipped and slot.used and alive < caps.maxMonsters and not (slot.model and hooks.alive(slot.model)) then
					slot.capSkipped = nil
					slot.model = hooks.spawn(point, slot)
					report.spawned += slot.model and 1 or 0
					alive += slot.model and 1 or 0
				end
			end
		elseif wasActive and not active then
			point.active, point.size = false, nil
			for _, slot in ipairs(point.slots) do
				slot.capSkipped = nil
			end
			for _, slot in ipairs(point.slots) do
				local model = slot.model
				slot.model = nil
				if model and hooks.alive(model) then
					if hooks.claim(model) then
						hooks.remove(model)
						report.cleared += 1
						alive -= 1
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
		local _, aliveNow = SpawnSites.stats()
		if aliveNow >= CFG.caps.maxMonsters then
			entry.slot.capSkipped = true -- M1-4 서버 상한: 리스폰도 넘기지 않는다 - 틱이 상한 여유가 생기면 채운다(리뷰: 영구히 비던 문제)
			return true
		end
		if entry.point.active and entry.slot.used and not (entry.slot.model and liveHooks.alive(entry.slot.model)) then
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
	print(("[forge-game] 스폰 지점 %d곳 대기(구역당 %d · 무리 최대 %d · 활성 반경 %d · 유지 %d · 정리 %d초 · 전투 보류 %d초 · 상한 서버 %d마리 · 사람당 무리 %d)"):format(#points, CFG.pointsPerRange, CFG.group.maxSize, CFG.activateRadius, CFG.keepRadius, CFG.idleSeconds, CFG.combatHoldSeconds, CFG.caps.maxMonsters, CFG.caps.maxGroupsPerPlayer))
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
