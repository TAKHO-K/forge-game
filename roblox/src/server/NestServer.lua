-- M1-3 둥지 3트랙 서버: 알 줍기(ProximityPrompt - F · 폰 상호작용 버튼) · 개인 쿨다운(모두에게 보이고 각자 기준 · 저장 v41 world.nests) · 순환형 비밀 둥지(하루 1곳) ·
--   번개 문(시간형) · 줍기 위치 검증(M1-2c 서버 위치 기록 - 순간이동 줍기 차단) · 알 등급 · 개체 후보 뽑기 · 비밀 둥지 발견 도감(칭호) · 클라 동기화(NestSync).
--   수치 = data/NestData(자리 · 재생성 · 줍기) · data/EggData(등급 분포 · 후보 풀). 도형 = shared/WorldStructures(NestSpot 앵커).
--   알 등급은 "사람 × 둥지 × 줍기 회차"마다 서버 비밀값으로 고정(다시 들어와도 같은 알 - 등급을 보고 고르기 · 재접속 뽑기 없음). 둥지에 보이는 알 = 그 사람이 주울 알(클라 NestView).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local NestData = require(ReplicatedStorage.Shared.data.NestData)
local EggData = require(ReplicatedStorage.Shared.data.EggData)
local WorldStructures = require(ReplicatedStorage.Shared.WorldStructures)
local PlayerProfile = require(script.Parent.PlayerProfile)
local LaunchPermit = require(script.Parent.LaunchPermit)
local ImmediateSave = require(script.Parent.ImmediateSave)

local NestServer = {}
local SALT = 918273 -- 서버 전용(등급 · 후보 뽑기 씨앗 - 클라에 없다)
local P = NestData.pickup
local specById = {}
for _, spec in ipairs(NestData.nests) do
	specById[spec.id] = spec
end
NestServer.specById = specById
NestServer.stats = { picked = 0, rejected = {} }
NestServer.debugDayShift = 0 -- 검증 전용(Studio): 날짜를 밀어 순환을 본다
NestServer.debugUnixShift = 0 -- 검증 전용: 쿨다운 시각을 밀어 본다

local anchors = {} -- [id] = { part, prompt }
local timedDoors = {} -- [id] = { door parts }
local lastRequestAt = {}
local syncRemote, pickedRemote

local function unixNow()
	return os.time() + NestServer.debugUnixShift
end
function NestServer.dayIndex(unix)
	return math.floor((unix + NestData.dayOffsetSeconds) / 86400) + NestServer.debugDayShift
end
local function nextDayStart(unix)
	local d = math.floor((unix + NestData.dayOffsetSeconds) / 86400) + 1
	return d * 86400 - NestData.dayOffsetSeconds
end

-- 순환형(C-진짜 히든): 구역 후보 5곳 중 오늘 1곳(구역 키 해시 + 날짜 - 이웃 날은 다른 곳)
local hiddenByZone = {}
for _, spec in ipairs(NestData.nests) do
	if spec.sub == "hidden" then
		hiddenByZone[spec.zone] = hiddenByZone[spec.zone] or {}
		table.insert(hiddenByZone[spec.zone], spec.id)
	end
end
function NestServer.activeHidden(zoneKey, day)
	local list = hiddenByZone[zoneKey]
	if not list then
		return nil
	end
	return list[(WorldStructures.hashStr(zoneKey) + day) % #list + 1]
end
function NestServer.isActive(spec, day)
	if spec.sub ~= "hidden" then
		return true
	end
	return NestServer.activeHidden(spec.zone, day) == spec.id
end

-- 번개 문(시간형): 서버 시각 주기 중 열린 구간
function NestServer.timedOpen(serverTime)
	local T = NestData.timedDoor
	return (serverTime % T.periodSeconds) < T.openSeconds
end

-- 트랙 → 등급 분포 · 재생성 키
function NestServer.gradeKey(spec)
	if spec.track == "A" then
		return spec.high and "Ahigh" or "A"
	elseif spec.track == "B" then
		return spec.top and "Btop" or "B"
	end
	return spec.sub == "village" and "Cvillage" or (spec.sub == "field" and "Cfield" or "Chidden")
end

local function seedOf(userId, nestId, picks)
	return (SALT + (userId % 1000003) * 7919 + WorldStructures.hashStr(nestId) * 31 + picks * 104729) % 2147483647
end

-- 순수: 이 사람이 이 둥지에서 picks번째로 주울 알(등급 · 후보 2 · 구역) - 서버 비밀 씨앗으로 고정
function NestServer.rollEgg(userId, spec, picks)
	local rng = Random.new(seedOf(userId, spec.id, picks))
	local dist = EggData.grades[NestServer.gradeKey(spec)]
	local total = 0
	for _, g in ipairs(EggData.gradeOrder) do
		total += dist[g] or 0
	end
	local roll = rng:NextNumber() * total
	local grade = EggData.gradeOrder[#EggData.gradeOrder]
	for _, g in ipairs(EggData.gradeOrder) do
		roll -= dist[g] or 0
		if roll < 0 then
			grade = g
			break
		end
	end
	local zoneKey = spec.eggZone or (spec.zone ~= "hub" and spec.zone) or "tier1"
	local pool = EggData.zones[zoneKey].pool
	local a = rng:NextInteger(1, #pool)
	local b = rng:NextInteger(1, #pool - 1)
	if b >= a then
		b += 1
	end
	return { zone = zoneKey, grade = grade, species = { pool[a], pool[b] }, nest = spec.id }
end

-- 순수: 다음에 주울 수 있는 unix 시각
function NestServer.nextAt(userId, spec, picks, unix)
	local R = NestData.respawn[NestServer.gradeKey(spec)] or NestData.respawn.B
	if R.daily then
		return nextDayStart(unix)
	elseif R.seconds then
		return unix + R.seconds
	end
	local rng = Random.new(seedOf(userId, spec.id, picks) + 17)
	return unix + math.floor(R.minSeconds + rng:NextNumber() * (R.maxSeconds - R.minSeconds))
end

-- 순수: 서버 위치 기록(samples = { { t, pos } })이 "그 자리에 있었다"인가. 반환: ok, 이유
function NestServer.checkPresence(samples, spot, now)
	local n, prev = 0, nil
	for _, s in ipairs(samples) do
		if now - s.t <= P.historySeconds then
			if prev and (s.pos - prev).Magnitude > P.maxStepStuds then
				return false, "teleport"
			end
			local flat = Vector3.new(s.pos.X - spot.X, 0, s.pos.Z - spot.Z).Magnitude
			local dy = (s.pos.Y - 3) - spot.Y
			if flat > P.radius or dy < -4 or dy > 8 then
				return false, "far"
			end
			n += 1
			prev = s.pos
		end
	end
	if n < P.minSamples then
		return false, "few_samples"
	end
	return true
end

local function reject(why)
	NestServer.stats.rejected[why] = (NestServer.stats.rejected[why] or 0) + 1
	return false, why
end

-- 줍기 한 번(프롬프트 · 검증). opts.samples(검증 - 합성 기록) · opts.skipTimed. 반환: ok, 이유/알
function NestServer.tryPickup(player, nestId, opts)
	opts = opts or {}
	local now = os.clock()
	local spec = specById[nestId]
	local meta = WorldStructures.nest(nestId)
	if not spec or not meta then
		return reject("unknown")
	end
	local unix = unixNow()
	if not NestServer.isActive(spec, NestServer.dayIndex(unix)) then
		return reject("inactive")
	end
	if spec.cover == "timed" and not opts.skipTimed and not NestServer.timedOpen(Workspace:GetServerTimeNow()) then
		return reject("closed")
	end
	if now - (lastRequestAt[player] or -math.huge) < P.requestGapSeconds then
		return reject("too_fast")
	end
	lastRequestAt[player] = now
	if not PlayerProfile.getProfile(player) then
		return reject("no_profile")
	end
	local rec = PlayerProfile.getNestRecord(player, nestId)
	if unix < rec.next then
		return reject("cooldown")
	end
	local ok, why = NestServer.checkPresence(opts.samples or LaunchPermit.recentSamples(player), meta.spot, now)
	if not ok then
		print(("[forge-game] 알 줍기 거절: %s - %s(%s)"):format(player.Name, nestId, why))
		return reject(why)
	end
	local egg = NestServer.rollEgg(player.UserId, spec, rec.picks)
	egg.at = unix
	local nextAt = NestServer.nextAt(player.UserId, spec, rec.picks, unix)
	if not PlayerProfile.recordNestPick(player, nestId, nextAt, egg, NestData.eggCap) then
		if pickedRemote and typeof(player) == "Instance" then
			pickedRemote:FireClient(player, { id = nestId, full = true, cap = NestData.eggCap })
		end
		return reject("full")
	end
	local discovered, dexCount, title = false, nil, nil
	if spec.track == "C" then
		discovered, dexCount = PlayerProfile.discoverNest(player, nestId)
		if discovered then
			for _, t in ipairs(NestData.dex.titles) do
				if dexCount >= t.count and PlayerProfile.grantTitle(player, t.id) then
					title = t.id
				end
			end
		end
	end
	NestServer.stats.picked += 1
	print(("[forge-game] 알 줍기: %s - %s(%s) → %s %s 알 · 후보 %s/%s · 다음 %d초 뒤%s"):format(player.Name, nestId, NestServer.gradeKey(spec), egg.zone, egg.grade,
		egg.species[1], egg.species[2], nextAt - unix, discovered and (" · 비밀 둥지 발견 " .. dexCount) or ""))
	ImmediateSave.request(player)
	if pickedRemote and typeof(player) == "Instance" then
		pickedRemote:FireClient(player, { id = nestId, egg = egg, discovered = discovered, dexCount = dexCount, title = title })
		NestServer.sync(player)
	end
	return true, egg
end

-- 클라 동기화: 둥지마다 { next(unix) · grade(다음에 주울 알 등급 - 겉모습) } + 알 가방 · 도감 수 · 서버 unix
function NestServer.payload(player)
	local unix = unixNow()
	local day = NestServer.dayIndex(unix)
	local nests = {}
	for _, spec in ipairs(NestData.nests) do
		if NestServer.isActive(spec, day) then
			local rec = PlayerProfile.getNestRecord(player, spec.id)
			nests[spec.id] = { next = rec.next, grade = NestServer.rollEgg(player.UserId, spec, rec.picks).grade }
		end
	end
	local dex = 0
	for _ in pairs(PlayerProfile.getNestDex(player)) do
		dex += 1
	end
	return { nests = nests, unix = unix, eggs = PlayerProfile.getEggs(player), dex = dex, cap = NestData.eggCap }
end
function NestServer.sync(player)
	if syncRemote and PlayerProfile.getProfile(player) then
		syncRemote:FireClient(player, NestServer.payload(player))
	end
end

-- 앵커(NestSpot) 활성 표시 · 프롬프트 켜기(순환 · 모두 같다 - 개인 쿨다운은 클라가 자기 프롬프트만 끈다)
local lastDay = nil
local function refreshActive()
	local day = NestServer.dayIndex(unixNow())
	for id, a in pairs(anchors) do
		local on = NestServer.isActive(specById[id], day)
		a.part:SetAttribute("NestActive", on)
		a.prompt.Enabled = on
	end
	if day ~= lastDay then
		lastDay = day
		for _, player in ipairs(Players:GetPlayers()) do
			NestServer.sync(player)
		end
	end
end
NestServer.refreshActive = refreshActive

function NestServer.start()
	if syncRemote then
		return
	end
	syncRemote = Instance.new("RemoteEvent")
	syncRemote.Name = "NestSync"
	syncRemote.Parent = ReplicatedStorage
	pickedRemote = Instance.new("RemoteEvent")
	pickedRemote.Name = "NestPicked"
	pickedRemote.Parent = ReplicatedStorage
	local ground = Workspace:WaitForChild("Ground")
	for _, part in ipairs(ground:GetDescendants()) do
		local id = part:IsA("BasePart") and part:GetAttribute("NestId")
		if id and specById[id] then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "NestPrompt"
			prompt.KeyboardKeyCode = Enum.KeyCode.F
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = P.promptDistance
			prompt.RequiresLineOfSight = false -- 방 · 지붕 밑 둥지
			prompt.ActionText = "" -- 문구 = 클라(TextData · NestView)
			prompt.Parent = part
			anchors[id] = { part = part, prompt = prompt }
			prompt.Triggered:Connect(function(player)
				NestServer.tryPickup(player, id)
			end)
		elseif part:IsA("BasePart") and part:GetAttribute("TimedDoor") then
			local key = part:GetAttribute("TimedDoor")
			timedDoors[key] = timedDoors[key] or {}
			table.insert(timedDoors[key], part)
		end
	end
	refreshActive()
	-- 번개 문(서버가 열고 닫는다 - 충돌 · 투명 복제) · 날짜 바뀜(순환)
	local acc, doorOpen = 0, nil
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		local open = NestServer.timedOpen(Workspace:GetServerTimeNow())
		if open ~= doorOpen then
			doorOpen = open
			for _, parts in pairs(timedDoors) do
				for _, door in ipairs(parts) do
					door.CanCollide = not open
					door.Transparency = open and 0.85 or 0
				end
			end
			Workspace:SetAttribute("NestTimedOpen", open)
		end
		if math.floor(os.clock()) % 30 == 0 then
			refreshActive()
		end
	end)
	local function onJoin(player)
		for _ = 1, 120 do
			if PlayerProfile.getProfile(player) or not player.Parent then
				break
			end
			task.wait(0.5)
		end
		NestServer.sync(player)
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onJoin, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastRequestAt[player] = nil
	end)
	local count = 0
	for _ in pairs(anchors) do
		count += 1
	end
	print(("[forge-game] 둥지 %d곳 · 번개 문 %d · 오늘 순환 = %s"):format(count, #(timedDoors[next(timedDoors) or ""] or {}), table.concat((function()
		local t = {}
		for zoneKey in pairs(hiddenByZone) do
			table.insert(t, NestServer.activeHidden(zoneKey, NestServer.dayIndex(unixNow())))
		end
		table.sort(t)
		return t
	end)(), ", ")))
end

function NestServer.anchor(id)
	return anchors[id]
end

return NestServer
