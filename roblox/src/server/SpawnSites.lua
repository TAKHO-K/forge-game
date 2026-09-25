-- M1 몬스터 지대 활성화(최적화 핵심 - 서버 비용이 맵 크기가 아니라 인원에 비례). 사냥 지대 = 구역마다 3곳 × 9슬롯(WorldConfig.zoneMonsterGrid 격자).
-- 지대 중심 activateRadius 안에 사람이 있으면 그 지대 슬롯을 모두 세운다. keepRadius 밖으로 모두 나가고 idleSeconds가 지나면 지대의 몬스터를 치운다(리스폰도 멈춘다).
-- 개인 스테이지 수치(몬스터 HP · 보상이 보는 사람의 스테이지)는 그대로 - 여기서는 "있느냐 없느냐"만 정한다. 수치 = WorldMapData.spawnSites.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local MonsterSpawner = require(script.Parent.MonsterSpawner)
local MonsterState = require(script.Parent.MonsterState)

local SpawnSites = {}

local CFG = WorldMapData.spawnSites
local sites = {} -- { zoneKey, index, center, data, slots = { { position, model } }, active, lastNearAt }
local slotByKey = {} -- ["x:z"] = { site, slot }

local function key(position)
	return ("%d:%d"):format(math.floor(position.X + 0.5), math.floor(position.Z + 0.5))
end

local function flatDistance(a, b)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- 순수(검증용): 지대 하나의 다음 상태. near = activateRadius 안 사람 수 · kept = keepRadius 안 사람 수.
function SpawnSites.nextState(active, lastNearAt, near, kept, now)
	if near > 0 then
		return true, now
	end
	if active and kept > 0 then
		return true, now
	end
	if active and now - lastNearAt >= CFG.idleSeconds then
		return false, lastNearAt
	end
	return active, lastNearAt
end

local function spawnSlot(site, slot)
	local model = MonsterSpawner.spawn(site.data, slot.position, site.zoneKey)
	slot.model = model
	if model then
		slotByKey[key(MonsterState.getSpawnPosition(model) or slot.position)] = { site = site, slot = slot }
	end
end

local function activate(site)
	site.active = true
	for _, slot in ipairs(site.slots) do
		if not (slot.model and slot.model.Parent and MonsterState.getData(slot.model)) then
			spawnSlot(site, slot)
		end
	end
end

local function deactivate(site)
	site.active = false
	local cleared = 0
	for _, slot in ipairs(site.slots) do
		local model = slot.model
		slot.model = nil
		if model and model.Parent then
			MonsterState.clear(model)
			model:Destroy()
			cleared += 1
		end
	end
	return cleared
end

function SpawnSites.start()
	for _, zone in ipairs(WorldMapData.zones) do
		local data = MonsterData[MonsterData.tierOrder[zone.tierIndex]]
		for _, g in ipairs(WorldMapLayout.grounds(zone)) do
			local site = { zoneKey = zone.key, index = g.index, center = g.center, data = data, slots = {}, active = false, lastNearAt = -math.huge }
			for _, offset in ipairs(WorldConfig.zoneMonsterGrid.offsets) do
				table.insert(site.slots, { position = Vector3.new(g.center.X + offset.X, WorldMapData.floorTopY + 1.5, g.center.Z + offset.Z) })
			end
			table.insert(sites, site)
		end
	end
	-- 죽은 잡몹의 리스폰: 이 지대 슬롯이면 지대가 켜져 있을 때만 그 슬롯에 되살린다.
	MonsterSpawner.respawnHook = function(data, spawnPosition, zoneKey)
		local entry = slotByKey[key(spawnPosition)]
		if not entry or entry.site.zoneKey ~= zoneKey then
			return false
		end
		if entry.site.active then
			entry.slot.model = nil
			local model = MonsterSpawner.spawn(data, entry.slot.position, zoneKey)
			entry.slot.model = model
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
		local roots = {}
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				table.insert(roots, root.Position)
			end
		end
		for _, extra in ipairs(SpawnSites.debugFoci) do
			table.insert(roots, extra)
		end
		local now = os.clock()
		for _, extra in ipairs(ReplicatedStorage:GetAttribute("DebugSpawnFoci") and string.split(ReplicatedStorage:GetAttribute("DebugSpawnFoci"), ";") or {}) do
			local x, z = extra:match("^(%-?[%d%.]+),(%-?[%d%.]+)$") -- 검증 · 성능(Studio): "x,z;x,z" 가짜 초점(execute_luau 모듈 사본 대신 Attribute)
			if x then
				table.insert(roots, Vector3.new(tonumber(x), 0, tonumber(z)))
			end
		end
		for _, site in ipairs(sites) do
			local near, kept = 0, 0
			for _, p in ipairs(roots) do
				local d = flatDistance(p, site.center)
				if d <= CFG.activateRadius then
					near += 1
				end
				if d <= CFG.keepRadius then
					kept += 1
				end
			end
			local active, lastNearAt = SpawnSites.nextState(site.active, site.lastNearAt, near, kept, now)
			site.lastNearAt = lastNearAt
			if active and not site.active then
				activate(site)
				print(("[forge-game] 몬스터 지대 켜짐: %s-%d(%d마리)"):format(site.zoneKey, site.index, #site.slots))
			elseif not active and site.active then
				local cleared = deactivate(site)
				print(("[forge-game] 몬스터 지대 정리: %s-%d(%d마리)"):format(site.zoneKey, site.index, cleared))
			end
		end
		local activeSites, alive = SpawnSites.stats()
		ReplicatedStorage:SetAttribute("SpawnSitesActive", activeSites) -- 검증 · 성능 표(서버 상태를 Attribute로)
		ReplicatedStorage:SetAttribute("SpawnSitesAlive", alive)
	end)
	print(("[forge-game] 몬스터 지대 %d곳 대기(활성 반경 %d · 유지 %d · 정리 %d초)"):format(#sites, CFG.activateRadius, CFG.keepRadius, CFG.idleSeconds))
end

-- 검증 · 성능 측정용 가짜 초점(서버 가짜 플레이어 자리 - PerfProbe)
SpawnSites.debugFoci = {}

-- 지금 켜진 지대 수 · 살아 있는 지대 몬스터 수
function SpawnSites.stats()
	local activeSites, alive = 0, 0
	for _, site in ipairs(sites) do
		if site.active then
			activeSites += 1
		end
		for _, slot in ipairs(site.slots) do
			if slot.model and slot.model.Parent then
				alive += 1
			end
		end
	end
	return activeSites, alive, #sites
end

function SpawnSites.sites()
	return sites
end

return SpawnSites
