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
local Text = require(ReplicatedStorage.Shared.Text)
local PlayerProfile = require(script.Parent.PlayerProfile)
local PlayerState = require(script.Parent.PlayerState)
local BossEncounter = require(script.Parent.BossEncounter)
local PartyState = require(script.Parent.PartyState)
local HeightGuard = require(script.Parent.HeightGuard)
local LaunchPermit = require(script.Parent.LaunchPermit)
local TeleportArrival = require(script.Parent.TeleportArrival)
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
-- 도착지 미리 불러오기(스트리밍) 뒤 옮긴다. 반환: 미리 불러오기 요청이 에러 없이 끝났는가(로그 · 검증).
--   M1-2c: 로그의 "미리 불러오기 O"는 숫자 0이 아니라 글자 O(= 요청 성공). 요청이 끝나도 발판이 다 들어왔다는 보장은 아니라 도착 알림(TeleportArrival)으로 클라가 발 아래를 한 번 더 본다.
function Travel.teleport(player, position, why)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local t0 = os.clock()
	local streamed = pcall(function()
		player:RequestStreamAroundAsync(position, T.streamTimeoutSeconds)
	end)
	local waited = os.clock() - t0
	if not root.Parent then
		return false
	end
	root.AssemblyLinearVelocity = Vector3.zero
	root.CFrame = CFrame.new(position) * root.CFrame.Rotation
	HeightGuard.reset(player)
	TeleportArrival.mark(player, position)
	stateOf(player).teleportAt = os.clock()
	print(("[forge-game] 이동(%s): %s → (%.0f, %.0f, %.0f) · 미리 불러오기 %s(%.2f초)"):format(why or "?", player.Name, position.X, position.Y, position.Z, streamed and "성공" or "실패", waited))
	Travel.lastTeleport = { player = player, position = position, why = why, streamed = streamed, waited = waited }
	return streamed
end

local function up(p, h)
	return Vector3.new(p.X, WorldMapData.floorTopY + (h or 3), p.Z)
end

-- ─────────────────────────── 요청(허브 귀환 · 돌아가기 · 파티원 곁으로) ───────────────────────────
-- M1-2 마을 귀환(사용자): 요청 → recall.castSeconds 시전(Player Attribute RecallCastUntil = 서버 시각 - 클라 시전 막대) → 끝나면 허브.
--   시전 중 맞으면(체력이 줄면) 취소(쿨 없음 - 다시 누를 수 있다) · 보스전이 시작돼도 취소. 쿨 = 도착 뒤 hubReturnCooldownSeconds.
--   도착하면 허브 밖에서 출발했을 때만 "돌아가기" 자리(출발 자리)를 recall.backSeconds 동안 1회 기억(Attribute RecallBackUntil) → [돌아가기] = 그 자리로.
-- 반환: ok, 이유 코드("casting" = 시전 시작)
local function serverNow()
	return workspace:GetServerTimeNow()
end

local function clearCast(player, st, why)
	st.recall = nil
	player:SetAttribute("RecallCastUntil", nil)
	if why then
		player:SetAttribute("RecallCancel", why) -- 클라 문구(시각이 아니라 이유 - 같은 이유가 연달아도 알리게 서버 시각을 붙인다)
		player:SetAttribute("RecallCancelAt", serverNow())
	end
end

function Travel.requestHub(player, now)
	now = now or os.clock()
	local st = stateOf(player)
	if BossEncounter.getEncounter(player) then
		return false, "in_boss"
	end
	if st.recall then
		return false, "casting_already"
	end
	if now - st.hubAt < T.hubReturnCooldownSeconds then
		return false, "cooldown"
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false, "no_character"
	end
	st.recall = { startAt = now, hp = PlayerState.getHp(player), origin = root.Position }
	player:SetAttribute("RecallCastUntil", serverNow() + T.recall.castSeconds)
	return true, "casting"
end

-- 시전 진행(Heartbeat 0.25초마다 · 검증은 now를 넣어 부른다). 반환: nil | "done" | "hit" | "boss"
function Travel.pollRecall(player, now)
	local st = stateOf(player)
	local cast = st.recall
	if not cast then
		return nil
	end
	if BossEncounter.getEncounter(player) then
		clearCast(player, st, "boss")
		return "boss"
	end
	local hp = PlayerState.getHp(player)
	if hp and cast.hp and hp < cast.hp - 0.001 then
		clearCast(player, st, "hit")
		return "hit"
	end
	cast.hp = hp or cast.hp -- 회복은 괜찮다(줄어들 때만 취소)
	if now - cast.startAt < T.recall.castSeconds then
		return nil
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local from = root and root.Position or cast.origin
	clearCast(player, st, nil)
	st.hubAt = now
	player:SetAttribute("RecallReadyAt", serverNow() + T.hubReturnCooldownSeconds) -- 클라 카드 "귀환 대기"
	st.checkpoint = nil
	if not WorldMapLayout.inHub(from) then
		st.back = { position = from, untilAt = now + T.recall.backSeconds }
		player:SetAttribute("RecallBackUntil", serverNow() + T.recall.backSeconds)
	end
	Travel.teleport(player, WorldConfig.zones.spawn.arrival + Vector3.new(0, WorldMapData.floorTopY + 3, 0), "허브 귀환")
	return "done"
end

-- [돌아가기]: 귀환한 자리로(1회 · backSeconds 안 · 보스전 중 불가 · 그 자리가 지금 나에게 잠긴 구역이면 불가)
function Travel.requestBack(player, now)
	now = now or os.clock()
	local st = stateOf(player)
	local back = st.back
	if not back or now > back.untilAt then
		st.back = nil
		player:SetAttribute("RecallBackUntil", nil)
		return false, "no_back"
	end
	if BossEncounter.getEncounter(player) then
		return false, "in_boss"
	end
	local zone = WorldMapLayout.zoneAt(back.position)
	if zone and not Travel.isZoneOpen(player, zone.key) then
		return false, "locked_zone"
	end
	st.back = nil
	player:SetAttribute("RecallBackUntil", nil)
	Travel.teleport(player, back.position + Vector3.new(0, 1, 0), "돌아가기")
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

-- 덩굴 리프트 타기(M1-2c - 바구니 앞 [F] 프롬프트 · 검증): 가장 높은 열린 정거장으로. 반환: 정거장 번호(0 = 잠김) · 보스전 중 · 멀면 nil
function Travel.rideLift(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or BossEncounter.getEncounter(player) then
		return nil
	end
	local L = WorldMapData.hub.tree.course.lift
	if (flat(root.Position) - flat(WorldMapLayout.hubPoint(L.angleDeg, L.r))).Magnitude > L.basketRadius + L.promptDistance + L.promptSlackStuds then
		return nil
	end
	local st = stateOf(player)
	local now = os.clock()
	if now - (st.liftAt or -math.huge) < L.rideCooldownSeconds then -- 리뷰 5: 미리 불러오기(최대 3초)를 기다리는 동안 [F] 연타로 겹쳐 옮기지 않게
		return nil
	end
	st.liftAt = now
	local best = Travel.highestStation(PlayerProfile.getPeakLevel(player))
	if best > 0 then
		local s = stationList()[best]
		st.checkpoint = best
		player:SetAttribute("TreeCheckpoint", best)
		Travel.teleport(player, s.top + Vector3.new(0, 3, 0), ("덩굴 리프트 → 정거장 %d"):format(best))
	else
		PartyState.notify(player, Text.get("lift.lockedNotice", { level = stationList()[1].unlockLevel }))
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

-- ─────────────────────────── 봉인 입구(M1 티저) ───────────────────────────
-- 봉인 상자 안(투명 벽 빈틈 · 순간이동 · 끼임 대비) = 입구 앞으로 부드럽게 되돌림(피해 없음). 틈 선반에 서면 짧은 문구 + 칭호(계정 1회).
local sealedBoxes
function Travel.sealedBoxes()
	sealedBoxes = sealedBoxes or WorldMapLayout.sealedBoxes()
	return sealedBoxes
end

function Travel.checkSealed(player, st, feet, grounded, now)
	local S = WorldMapData.sealed
	for _, box in ipairs(Travel.sealedBoxes()) do
		if WorldMapLayout.insideSealed(box, feet + Vector3.new(0, 1, 0)) then
			st.sealedPushes = (st.sealedPushes or 0) + 1
			Travel.teleport(player, (box.cf * CFrame.new(0, 3, -12)).Position, "봉인 되돌림(" .. box.id .. ")")
			if now - (st.sealedNoticeAt or -math.huge) > 3 then
				st.sealedNoticeAt = now
				PartyState.notify(player, S.title.line)
			end
			return true
		end
		if grounded then
			local l = box.cf:PointToObjectSpace(feet)
			local led = box.ledge
			if math.abs(l.X - led.localPos.X) <= led.halfX and math.abs(l.Z - led.localPos.Z) <= led.halfZ and math.abs(l.Y - led.localPos.Y) <= 2.5 then
				if PlayerProfile.grantTitle(player, S.title.id) then
					print(("[forge-game] 칭호: %s - %s(%s 틈)"):format(player.Name, S.title.name, box.id))
					PartyState.notify(player, ("%s  · 칭호 [%s]"):format(S.title.line, S.title.name))
					ImmediateSave.request(player)
				elseif now - (st.sealedNoticeAt or -math.huge) > 6 then
					st.sealedNoticeAt = now
					PartyState.notify(player, S.title.line)
				end
			end
		end
	end
	return false
end

-- ─────────────────────────── 폴링 ───────────────────────────
local hubPortals, campPortals, gates
local function buildPoints()
	hubPortals, campPortals, gates = {}, {}, {}
	for _, z in ipairs(ZONES) do
		hubPortals[z.key] = WorldMapLayout.hubPortal(z)
		campPortals[z.key] = WorldMapLayout.campPortal(z)
	end
	for _, g in ipairs(WorldMapLayout.bossGates()) do
		gates[g.bossId] = g.position -- M1-3: 관문 = 보스 목록(BossData gate) - 발판 키 = 보스 id
	end
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
	BossGate.refreshAttributes(player) -- M1-3: 등록 · 원격 입장 가능 목록(클라 관문 색 · 버튼)
	local inParty = PartyState.getParty(player) ~= nil
	if player:GetAttribute("InParty") ~= inParty then
		player:SetAttribute("InParty", inParty)
	end
	if BossEncounter.getEncounter(player) then
		return -- 보스 아레나(세계 밖 슬롯) - 이 아래 규칙은 필드 전용
	end
	if Travel.checkSealed(player, st, feet, grounded, now) then
		return
	end
	-- 세계 밖 · 너무 높은 곳에 서 있다 → 허브
	-- 높은 곳: 나무 둘레(treeRadius) 안 = 전망대 + 60 위 · 밖 = 오를 수 있는 가장 높은 구조물 + 여유(standMaxY) 위에 서 있으면(투명 벽 위 · 끼임 등)
	local P = WorldMapData.progress
	local tooHigh = grounded and (feet.Y > WorldMapData.hub.tree.course.deck.y + 60 or (flat(feet).Magnitude > P.treeRadius and feet.Y > P.standMaxY))
	if flat(feet).Magnitude > WorldMapData.edge.radius + 10 or tooHigh then
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
		-- 보스 관문
		for key, g in pairs(gates) do
			if (flat(feet) - flat(g)).Magnitude <= WorldMapData.layout.gate.radius and now - st.gateAt >= 3 then
				st.gateAt = now
				local result = BossGate.enter(player, key)
				print(("[forge-game] 관문 %s: %s → %s"):format(key, player.Name, result))
				if result == "not_boss_stage" or result == "wrong_gate" then
					PartyState.notify(player, "관문 - 이 보스의 스테이지를 고르면 열린다(등록은 관문 앞 [F])")
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
		-- M1-2c: 순간이동 직후 1초는 건너뛴다 - 클라가 옮겨진 자리를 받기 전에 보낸 옛 위치(바닥)를 떨어짐으로 읽어 같은 정거장으로 한 번 더 옮겼다(리프트 [F] 실측)
		local justMoved = now - (st.teleportAt or -math.huge) < WorldMapData.travel.arrival.fallSkipAfterTeleportSeconds
		if inTree and grounded and not justMoved and feet.Y < s.y - WorldMapData.hub.tree.course.fallDropStuds then
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
	BossGate.setupPrompts(require(script.Parent.GroundProbe).folder())
	Travel.downPads = downPads
	local request = Instance.new("RemoteEvent")
	request.Name = "TravelRequest"
	request.Parent = ReplicatedStorage
	request.OnServerEvent:Connect(function(player, kind, targetUserId)
		local ok, why
		if kind == "hub" then
			ok, why = Travel.requestHub(player)
		elseif kind == "back" then
			ok, why = Travel.requestBack(player)
		elseif kind == "party" then
			ok, why = Travel.requestParty(player, type(targetUserId) == "number" and Players:GetPlayerByUserId(targetUserId) or Travel.defaultPartyTarget(player))
		else
			return
		end
		if not ok then
			local text = ({ in_boss = "보스전 중에는 못 간다", cooldown = "아직 쿨타임", combat = "전투 중(최근 피해)에는 못 간다", locked_zone = "그 사람은 나에게 잠긴 구역에 있다",
				not_party = "파티원만", no_target = "대상을 찾지 못했다",
				casting_already = "이미 귀환 중", no_back = "돌아갈 자리가 없다(5분 · 1회)", no_character = "캐릭터가 없다" })[why] or why
			PartyState.notify(player, "이동 불가 - " .. text)
		end
	end)
	-- 나무 통통 열매 · 점프대: 클라가 튕기며 LaunchPermitRequest(파트)를 보낸다 → 서버 위치 기록으로 발판 위였음을 확인하면 설계 정점까지 높이 허가(M1-2c - LaunchPermit)
	LaunchPermit.start()
	local course = require(script.Parent.WorldMap).model("TreeCourse")
	local registered = 0
	for _, part in ipairs(course and course:GetDescendants() or {}) do
		local id = part:GetAttribute("TreePad") or (part:GetAttribute("TreeFruit") == "bounce" and part:GetAttribute("FruitId"))
		local spec = id and WorldMapLayout.treeLaunch(id)
		if spec then
			local c = WorldMapLayout.tree().elements[id].center
			LaunchPermit.register(part, { top = spec.top, center = c, radius = spec.radius, apexFeetY = spec.apexFeetY, source = ("나무 %s %d"):format(spec.kind == "pad" and "점프대" or "통통 열매", id) })
			registered += 1
		end
	end
	Travel.launchSources = registered
	-- 덩굴 리프트 [F](M1-2c): 바구니(VineLift)에 프롬프트 - 글(정거장 · 높이)과 켜짐(열림만)은 클라가 사람마다(VineLiftView)
	local hub = require(script.Parent.WorldMap).model("Hub")
	for _, part in ipairs(hub and hub:GetDescendants() or {}) do
		if part:IsA("BasePart") and part:GetAttribute("VineLift") then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "VineLiftPrompt"
			prompt.ObjectText = WorldMapData.hub.tree.course.lift.label
			prompt.ActionText = Text.get("lift.action")
			prompt.KeyboardKeyCode = Enum.KeyCode.F
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = WorldMapData.hub.tree.course.lift.promptDistance
			prompt.RequiresLineOfSight = false
			prompt.Parent = part
			prompt.Triggered:Connect(function(player)
				Travel.rideLift(player)
			end)
		end
	end
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
				local recall = Travel.pollRecall(player, now)
				if recall == "boss" then
					PartyState.notify(player, "귀환 취소 - 보스전") -- 맞아서 취소 = 세계 정보 카드 귀환 줄(M1-2 후속 - 한 틀) · 보스전 중엔 카드가 숨어 토스트로
				end
			end
		end
	end)
	print(("[forge-game] 세계 이동 준비 - 구역 %d · 정거장 %d · 포탈 %d쌍 · 발사 허가 발판 %d"):format(#ZONES, #stationList(), #ZONES, Travel.launchSources or 0))
end

return Travel
