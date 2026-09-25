-- M1 세계 이동(서버). 수치 = WorldMapData(progress · travel · hub.tree.course) · 기하 = WorldMapLayout.
--   · 구역 개방(개인 · 계정): 구역 k+1 = 구역 k 보스 첫 처치(계정 최고 보스 기록 ≥ 그 보스가 처음 나오는 스테이지). Player Attribute ZonesUnlocked(개수).
--   · 잠긴 구역 밀어내기(보조 - 주 수단은 클라 결계 벽 client/WorldBarrier): 잠긴 구역 원 안이면 원 밖 pushOutStuds로.
--   · 포탈: 입구 캠프에 처음 들어가면 그 구역 포탈 개방(저장 world.portals) · 허브 포탈 광장 판 ↔ 캠프 판. PortalsOpen Attribute(쉼표 목록).
--   · 허브 귀환(쿨) · 파티원 곁으로(쿨 · 제한) = 요청(TravelRequest RemoteEvent) · 덩굴 리프트(가장 높은 열린 정거장) · 정거장(체크포인트) · 떨어지면 마지막 정거장.
--   · 보스 관문 판 → BossGate.enter. 세계 밖 · 너무 높은 곳에 서 있으면 허브로.
--   · 모든 순간이동 전에 RequestStreamAroundAsync(도착지 미리 불러오기 - 스트리밍).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossRules = require(ReplicatedStorage.Shared.BossRules)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)
local PlayerProfile = require(script.Parent.PlayerProfile)
local PlayerState = require(script.Parent.PlayerState)
local BossEncounter = require(script.Parent.BossEncounter)
local PartyState = require(script.Parent.PartyState)
local HeightGuard = require(script.Parent.HeightGuard)
local BossGate = require(script.Parent.BossGate)
local ImmediateSave = require(script.Parent.ImmediateSave)

local Travel = {}

local T = WorldMapData.travel
local P = WorldMapData.progress
local ZONES = WorldMapData.zones
local PAD_COOLDOWN = 1.5

local state = setmetatable({}, { __mode = "k" }) -- [Player] = { padAt, hubAt, partyAt, hurtAt, lastHp, checkpoint(정거장 번호), gateAt, pushes }

local function stateOf(player)
	local st = state[player]
	if not st then
		st = { padAt = -math.huge, hubAt = -math.huge, partyAt = -math.huge, hurtAt = -math.huge, gateAt = -math.huge, pushes = 0 }
		state[player] = st
	end
	return st
end
Travel.stateOf = stateOf

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- ─────────────────────────── 구역 개방 ───────────────────────────
-- 구역 k(1부터)의 보스가 처음 나오는 스테이지(배치표 - 스테이지만의 함수). 못 찾으면 math.huge.
local firstStageCache = {}
function Travel.firstBossStage(bossId)
	if firstStageCache[bossId] then
		return firstStageCache[bossId]
	end
	local interval = require(ReplicatedStorage.Shared.data.BossData).stageInterval
	for stage = interval, interval * 200, interval do
		if BossRules.bossIdForStage(stage) == bossId then
			firstStageCache[bossId] = stage
			return stage
		end
	end
	firstStageCache[bossId] = math.huge
	return math.huge
end

-- 순수: 계정 최고 보스 기록 → 열린 구역 수
function Travel.unlockedCountFor(bestBossCleared)
	local count = P.startUnlocked
	for k = 1, #ZONES - 1 do
		if bestBossCleared >= Travel.firstBossStage(ZONES[k].bossId) then
			count = math.max(count, k + 1)
		else
			break
		end
	end
	return math.min(count, #ZONES)
end

function Travel.unlockedCount(player)
	if Travel.debugUnlockAll then
		return #ZONES
	end
	-- 검증 전용(Studio): 잠금 · 밀어내기 · 결계를 개발 계정 기록과 무관하게 - ReplicatedStorage Attribute DebugZonesUnlocked(execute_luau의 require는 모듈 사본이라 Attribute로 받는다)
	local debugCount = RunService:IsStudio() and ReplicatedStorage:GetAttribute("DebugZonesUnlocked")
	if type(debugCount) == "number" then
		return debugCount
	end
	local count = Travel.unlockedCountFor(PlayerProfile.getAccountBestBossCleared(player))
	-- 견습(튜토리얼)은 단계마다 tier 1 ~ 6 구역을 차례로 돈다 - 진행 중인 단계의 구역까지는 연다(튜토리얼 본편 단계에서 다시 본다)
	local TutorialState = require(script.Parent.TutorialState)
	local step = TutorialState.getActiveStep(player)
	local stepData = step and require(ReplicatedStorage.Shared.data.TutorialData).steps[step]
	if stepData then
		count = math.max(count, math.min(stepData.tierIndex, #ZONES))
	end
	return count
end

function Travel.isZoneOpen(player, zoneKey)
	local zone = WorldMapLayout.zoneByKey(zoneKey)
	return zone ~= nil and zone.tierIndex <= Travel.unlockedCount(player)
end

-- 순수: 잠긴 구역 안 점 → 허브 쪽으로 구역 원 밖 pushOutStuds 자리
function Travel.pushOutPoint(zone, feet)
	local c = flat(WorldMapLayout.regionCenter(zone))
	local p = flat(feet)
	local toHub = p.Magnitude > 1e-3 and -p.Unit or -WorldMapLayout.dirOf(zone.angleDeg)
	local limit = WorldMapData.layout.regionRadius + P.pushOutStuds
	local t = 0
	while (p + toHub * t - c).Magnitude < limit and t < 4000 do
		t += 2
	end
	return p + toHub * t
end

-- ─────────────────────────── 순간이동 ───────────────────────────
-- 도착지 미리 불러오기(스트리밍) 뒤 옮긴다. 반환: 미리 불러오기 성공 여부(로그 · 검증).
function Travel.teleport(player, position, why)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local streamed = pcall(function()
		player:RequestStreamAroundAsync(position, T.streamTimeoutSeconds)
	end)
	if not root.Parent then
		return false
	end
	root.AssemblyLinearVelocity = Vector3.zero
	root.CFrame = CFrame.new(position) * root.CFrame.Rotation
	HeightGuard.reset(player)
	print(("[forge-game] 이동(%s): %s → (%.0f, %.0f, %.0f) · 미리 불러오기 %s"):format(why or "?", player.Name, position.X, position.Y, position.Z, streamed and "O" or "X"))
	Travel.lastTeleport = { player = player, position = position, why = why, streamed = streamed }
	return streamed
end

local function up(p, h)
	return Vector3.new(p.X, WorldMapData.floorTopY + (h or 3), p.Z)
end

-- ─────────────────────────── 요청(허브 귀환 · 파티원 곁으로) ───────────────────────────
-- 반환: ok, 이유 코드
function Travel.requestHub(player, now)
	now = now or os.clock()
	local st = stateOf(player)
	if BossEncounter.getEncounter(player) then
		return false, "in_boss"
	end
	if now - st.hubAt < T.hubReturnCooldownSeconds then
		return false, "cooldown"
	end
	st.hubAt = now
	st.checkpoint = nil
	Travel.teleport(player, WorldConfig.zones.spawn.arrival + Vector3.new(0, WorldMapData.floorTopY + 3, 0), "허브 귀환")
	return true, "ok"
end

function Travel.partyTeleportCheck(player, target, now)
	now = now or os.clock()
	local st = stateOf(player)
	local party = PartyState.getParty(player)
	if not party or not target or target == player or PartyState.getParty(target) ~= party then
		return false, "not_party"
	end
	if BossEncounter.getEncounter(player) or BossEncounter.getEncounter(target) then
		return false, "in_boss"
	end
	if now - st.hurtAt < T.combatLockSeconds then
		return false, "combat"
	end
	if now - st.partyAt < T.partyTeleportCooldownSeconds then
		return false, "cooldown"
	end
	local root = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false, "no_target"
	end
	local zone = WorldMapLayout.zoneAt(root.Position)
	if zone and not Travel.isZoneOpen(player, zone.key) then
		return false, "locked_zone"
	end
	return true, "ok", root.Position
end

-- 대상을 안 고르면: 리더가 아니면 리더 · 리더면 첫 다른 멤버(실제 Player만)
function Travel.defaultPartyTarget(player)
	local party = PartyState.getParty(player)
	if not party then
		return nil
	end
	local fallback = nil
	for _, record in ipairs(party.members) do
		local p = record.player
		if typeof(p) == "Instance" and p ~= player then
			if PartyState.isLeader(p) then
				return p
			end
			fallback = fallback or p
		end
	end
	return fallback
end

function Travel.requestParty(player, target, now)
	local ok, why, at = Travel.partyTeleportCheck(player, target, now)
	if not ok then
		return false, why
	end
	stateOf(player).partyAt = now or os.clock()
	Travel.teleport(player, at + Vector3.new(T.arriveOffsetStuds, 0, 0), "파티원 곁으로")
	return true, "ok"
end

-- ─────────────────────────── 나무(리프트 · 정거장) ───────────────────────────
local stations -- WorldMapLayout.stations()
local function stationList()
	stations = stations or WorldMapLayout.stations()
	return stations
end

-- 가장 높은 열린 정거장 번호(0 = 없음)
function Travel.highestStation(peakLevel)
	local best = 0
	for i, s in ipairs(stationList()) do
		if peakLevel >= s.unlockLevel then
			best = i
		end
	end
	return best
end

-- 정거장 = 줄기 둘레 고리 발판(반경 ringInner ~ ringOuter · 높이 y)
local function onStation(feet)
	local r = flat(feet).Magnitude
	for i, s in ipairs(stationList()) do
		if r >= s.ringInner - 1 and r <= s.ringOuter + 1 and math.abs(feet.Y - s.y) <= 3 then
			return i
		end
	end
	return nil
end

-- ─────────────────────────── 폴링 ───────────────────────────
local hubPortals, campPortals, gates, liftPoint
local function buildPoints()
	hubPortals, campPortals, gates = {}, {}, {}
	for _, z in ipairs(ZONES) do
		hubPortals[z.key] = WorldMapLayout.hubPortal(z)
		campPortals[z.key] = WorldMapLayout.campPortal(z)
		gates[z.key] = WorldMapLayout.gate(z)
	end
	local lift = WorldMapData.hub.tree.course.lift
	liftPoint = WorldMapLayout.hubPoint(lift.angleDeg, lift.r)
end

local function portalsAttribute(player)
	local keys = {}
	for _, z in ipairs(ZONES) do
		if PlayerProfile.isPortalOpen(player, z.key) then
			table.insert(keys, z.key)
		end
	end
	return table.concat(keys, ",")
end

-- 한 사람 한 번(0.25초마다). feet = 발 위치 · grounded = 서 있는가.
function Travel.pollPlayer(player, root, humanoid, now)
	local st = stateOf(player)
	local feet = root.Position - Vector3.new(0, 3, 0)
	local grounded = humanoid and humanoid.FloorMaterial ~= Enum.Material.Air
	-- 피해 받음(전투 중 판정)
	local hp = PlayerState.getHp(player)
	if hp and st.lastHp and hp < st.lastHp then
		st.hurtAt = now
	end
	st.lastHp = hp
	-- 구역 개방 · 포탈 Attribute
	local unlocked = Travel.unlockedCount(player)
	if player:GetAttribute("ZonesUnlocked") ~= unlocked then
		player:SetAttribute("ZonesUnlocked", unlocked)
	end
	local portals = portalsAttribute(player)
	if player:GetAttribute("PortalsOpen") ~= portals then
		player:SetAttribute("PortalsOpen", portals)
	end
	BossGate.refreshGuide(player)
	local inParty = PartyState.getParty(player) ~= nil
	if player:GetAttribute("InParty") ~= inParty then
		player:SetAttribute("InParty", inParty)
	end
	if BossEncounter.getEncounter(player) then
		return -- 보스 아레나(세계 밖 슬롯) - 이 아래 규칙은 필드 전용
	end
	-- 세계 밖 · 너무 높은 곳에 서 있다 → 허브
	if flat(feet).Magnitude > WorldMapData.edge.radius + 10 or (grounded and feet.Y > WorldMapData.hub.tree.course.deck.y + 60) then
		Travel.teleport(player, WorldConfig.zones.spawn.arrival + Vector3.new(0, WorldMapData.floorTopY + 3, 0), "세계 밖 복귀")
		return
	end
	-- 잠긴 구역 밀어내기
	local zone = WorldMapLayout.zoneAt(feet)
	if zone and zone.tierIndex > unlocked then
		-- 허브 쪽으로(구역 원 밖 + pushOutStuds) - 꽃잎 부채꼴 안의 반지름 선은 이웃 구역 원을 지나지 않는다(핑퐁 없음)
		local out = Travel.pushOutPoint(zone, feet)
		st.pushes += 1
		Travel.teleport(player, up(out, 3), "잠긴 구역 밀어내기(" .. zone.key .. ")")
		PartyState.notify(player, ("잠긴 구역 - %s 보스를 처음 잡으면 열린다"):format(ZONES[zone.tierIndex - 1] and ZONES[zone.tierIndex - 1].theme or "이전 구역"))
		return
	end
	local padReady = now - st.padAt >= PAD_COOLDOWN
	local nearFloor = feet.Y <= WorldMapData.floorTopY + 4
	-- 캠프 도착 = 포탈 개방
	if zone and nearFloor and (flat(feet) - flat(WorldMapLayout.camp(zone))).Magnitude <= T.campDiscoverRadius then
		if PlayerProfile.openPortal(player, zone.key) then
			print(("[forge-game] 포탈 개방: %s - %s"):format(player.Name, zone.key))
			PartyState.notify(player, ("포탈 개방 - %s(허브 포탈 광장에서 바로 온다)"):format(zone.theme))
			ImmediateSave.request(player)
		end
	end
	if padReady and nearFloor then
		for _, z in ipairs(ZONES) do
			if (flat(feet) - flat(hubPortals[z.key])).Magnitude <= T.portalRadius then
				st.padAt = now
				if PlayerProfile.isPortalOpen(player, z.key) and Travel.isZoneOpen(player, z.key) then
					Travel.teleport(player, up(WorldMapLayout.camp(z), 3), "포탈 → " .. z.key)
				else
					PartyState.notify(player, ("포탈 잠김 - %s 입구 캠프에 한 번 걸어가면 열린다"):format(z.theme))
				end
				return
			end
			if (flat(feet) - flat(campPortals[z.key])).Magnitude <= T.portalRadius then
				st.padAt = now
				Travel.teleport(player, up(WorldMapLayout.facility("portal"), 3), "포탈 → 허브")
				return
			end
		end
		if (flat(feet) - flat(liftPoint)).Magnitude <= 5 then
			st.padAt = now
			local best = Travel.highestStation(PlayerProfile.getPeakLevel(player))
			if best > 0 then
				local s = stationList()[best]
				st.checkpoint = best
				player:SetAttribute("TreeCheckpoint", best)
				Travel.teleport(player, s.top + Vector3.new(0, 3, 0), ("덩굴 리프트 → 정거장 %d"):format(best))
			else
				PartyState.notify(player, ("덩굴 리프트 - 역대 최고 레벨 %d부터 첫 정거장이 열린다"):format(stationList()[1].unlockLevel))
			end
			return
		end
		-- 보스 관문
		for key, g in pairs(gates) do
			if (flat(feet) - flat(g)).Magnitude <= WorldMapData.layout.gate.radius and now - st.gateAt >= 3 then
				st.gateAt = now
				local result = BossGate.enter(player, key)
				print(("[forge-game] 관문 %s: %s → %s"):format(key, player.Name, result))
				if result == "not_boss_stage" or result == "wrong_gate" then
					PartyState.notify(player, "관문 - 이 구역 보스의 스테이지를 고르면 열린다")
				end
				return
			end
		end
	end
	-- 정거장(체크포인트) · 내려가기 판 · 떨어지면 마지막 정거장
	local on = grounded and onStation(feet)
	if on then
		if st.checkpoint ~= on then
			st.checkpoint = on
			player:SetAttribute("TreeCheckpoint", on)
		end
	end
	if st.checkpoint then
		local s = stationList()[st.checkpoint]
		local inTree = flat(feet).Magnitude <= 160
		if inTree and grounded and feet.Y < s.y - WorldMapData.hub.tree.course.fallDropStuds then
			Travel.teleport(player, s.top + Vector3.new(0, 3, 0), ("떨어짐 → 정거장 %d"):format(st.checkpoint))
			return
		end
		if not inTree then
			st.checkpoint = nil
			player:SetAttribute("TreeCheckpoint", nil)
		end
	end
end

-- 정거장 내려가기 판(Station 가장자리 원판) - 서 있으면 허브로 · 기록 지움
function Travel.checkStationDown(player, feet, grounded)
	local st = stateOf(player)
	if not grounded then
		return false
	end
	for _, part in ipairs(Travel.downPads or {}) do
		if (flat(feet) - flat(part.Position)).Magnitude <= 2 and math.abs(feet.Y - part.Position.Y) <= 3 then
			st.checkpoint = nil
			player:SetAttribute("TreeCheckpoint", nil)
			Travel.teleport(player, WorldConfig.zones.spawn.arrival + Vector3.new(0, WorldMapData.floorTopY + 3, 0), "정거장 내려가기")
			return true
		end
	end
	return false
end

function Travel.start(downPads)
	buildPoints()
	Travel.downPads = downPads
	local request = Instance.new("RemoteEvent")
	request.Name = "TravelRequest"
	request.Parent = ReplicatedStorage
	request.OnServerEvent:Connect(function(player, kind, targetUserId)
		local ok, why
		if kind == "hub" then
			ok, why = Travel.requestHub(player)
		elseif kind == "party" then
			ok, why = Travel.requestParty(player, type(targetUserId) == "number" and Players:GetPlayerByUserId(targetUserId) or Travel.defaultPartyTarget(player))
		else
			return
		end
		if not ok then
			local text = ({ in_boss = "보스전 중에는 못 간다", cooldown = "아직 쿨타임", combat = "전투 중(최근 피해)에는 못 간다", locked_zone = "그 사람은 나에게 잠긴 구역에 있다",
				not_party = "파티원만", no_target = "대상을 찾지 못했다" })[why] or why
			PartyState.notify(player, "이동 불가 - " .. text)
		end
	end)
	-- 나무 통통 열매 · 점프대: 클라가 튕기기 직전에 알린다 → 그 요소가 발 가까이(10 안)에 있으면 높이 검증 예외(점프대 비행 + 여유)
	local launchEvent = Instance.new("RemoteEvent")
	launchEvent.Name = "TreeLaunch"
	launchEvent.Parent = ReplicatedStorage
	local launchParts = {}
	local course = require(script.Parent.WorldMap).model("TreeCourse")
	for _, part in ipairs(course and course:GetDescendants() or {}) do
		local id = part:GetAttribute("FruitId") or part:GetAttribute("TreePad")
		if id and (part:GetAttribute("TreeFruit") == "bounce" or part:GetAttribute("TreePad")) then
			launchParts[id] = part
		end
	end
	launchEvent.OnServerEvent:Connect(function(player, id)
		local part = type(id) == "number" and launchParts[id]
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if part and root and (root.Position - part.Position).Magnitude <= 10 then
			HeightGuard.exempt(player, WorldMapData.hub.tree.course.pad.flightSeconds + 1.5)
		end
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.25 then
			return
		end
		elapsed = 0
		local now = os.clock()
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if root and PlayerProfile.getProfile(player) then
				local grounded = humanoid and humanoid.FloorMaterial ~= Enum.Material.Air
				if not Travel.checkStationDown(player, root.Position - Vector3.new(0, 3, 0), grounded) then
					Travel.pollPlayer(player, root, humanoid, now)
				end
			end
		end
	end)
	print(("[forge-game] 세계 이동 준비 - 구역 %d · 정거장 %d · 포탈 %d쌍"):format(#ZONES, #stationList(), #ZONES))
end

return Travel
