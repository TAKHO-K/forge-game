-- D1 태초 세계 기록(② 세계 번호 · ③ 전 서버 알림 · ④ 명예의 전당 원본). 규칙 값 = shared/data/PrimordialData.lua.
--   · 원본 = DataStore UpdateAsync(원자적 - 두 서버가 동시에 올려도 번호가 겹치지 않는다). 카운터 키 하나 + 최근 목록 키 하나.
--   · 알림 = MessagingService(best-effort - 유실돼도 원본은 DataStore에 있고 명예의 전당이 거기서 읽는다).
--   · Studio(수동 · 검증 Play)는 라이브와 같은 유니버스 저장소에 붙으므로 항상 시험 키(testKeyPrefix) · 시험 토픽을 쓴다 - 실제 세계 번호를 안 올린다.
--     /gg drop force도 시험 키(개발 계정만).
-- 태초 각인(item.primordial) = { no = 세계 번호(nil = 번호 확정 실패 · legacy = 옛 태초), ownerId, ownerName, at = unix 초, source = item.source 복사 }.
-- 출처(item.source) = M2 출처 태그와 같은 구조 { kind = "boss" | "raid" | "field" | "sparkle", bossId?, zone?, stage } - CombatResolution이 모든 드랍에 붙인다.

local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local PrimordialData = require(ReplicatedStorage.Shared.data.PrimordialData)
local Workspace = game:GetService("Workspace")

local PrimordialRegistry = {}

local store = DataStoreService:GetDataStore(PrimordialData.storeName)
local isStudio = RunService:IsStudio()
local topic = PrimordialData.topic .. (isStudio and "_studio" or "")

local bannerRemote = Instance.new("RemoteEvent")
bannerRemote.Name = "PrimordialBanner" -- 서버 → 클라: 상단 배너 + 채팅 줄(전 서버 태초 · 같은 서버 고대)
bannerRemote.Parent = ReplicatedStorage

-- 검증 · 시험 계측: 번호 발급 · 기록 · 알림 시도 수
local stats = { claims = 0, claimFails = 0, published = 0, received = 0 }
function PrimordialRegistry.stats()
	return stats
end

local function keyFor(base, test)
	if test or isStudio then
		return PrimordialData.testKeyPrefix .. base
	end
	return base
end
PrimordialRegistry.keyFor = keyFor

-- 이름 필터(전 서버 방송용). 실패하면 기본 이름(원문을 그대로 내보내지 않는다).
function PrimordialRegistry.filterName(name, fromUserId)
	local ok, result = pcall(function()
		return TextService:FilterStringAsync(name, fromUserId):GetNonChatStringForBroadcastAsync()
	end)
	if ok and type(result) == "string" and result ~= "" and not result:find("#") then
		return result
	end
	return PrimordialData.fallbackName
end

-- 카운터 +1 → 새 번호(재시도 포함 · 실패 = nil). 순수 UpdateAsync 하나 - 동시 요청이 겹쳐도 각자 다른 값을 받는다.
function PrimordialRegistry.nextNumber(test)
	local key = keyFor(PrimordialData.counterKey, test)
	for _ = 1, PrimordialData.claimRetries do
		local ok, value = pcall(function()
			return store:UpdateAsync(key, function(current)
				return (tonumber(current) or 0) + 1
			end)
		end)
		if ok and type(value) == "number" then
			return value
		end
		task.wait(0.5)
	end
	return nil
end

-- 최근 목록 앞에 기록을 넣는다(recentKeep개 유지 · 같은 번호는 한 번만).
local function appendRecent(entry, test)
	local key = keyFor(PrimordialData.recentKey, test)
	local ok = pcall(function()
		store:UpdateAsync(key, function(list)
			list = type(list) == "table" and list or {}
			for _, row in ipairs(list) do
				if row.no == entry.no then
					return list
				end
			end
			table.insert(list, 1, entry)
			while #list > PrimordialData.recentKeep do
				table.remove(list)
			end
			return list
		end)
	end)
	return ok
end

-- 최근 목록 읽기(명예의 전당 - 알림이 유실돼도 여기서 복원된다).
function PrimordialRegistry.readRecent(test)
	local ok, list = pcall(function()
		return store:GetAsync(keyFor(PrimordialData.recentKey, test))
	end)
	if ok and type(list) == "table" then
		return list
	end
	return nil
end

-- 알림 한 건 → 이 서버 전원 배너 + 채팅 줄. entry = { no, name, grade, part, source, jobId }.
local announceHooks = {} -- 서버 안 구독자(명예의 전당 - 알림이 오면 바로 한 줄 더한다)
function PrimordialRegistry.onAnnounce(fn)
	table.insert(announceHooks, fn)
end

local function announceLocal(entry)
	bannerRemote:FireAllClients(entry)
	for _, fn in ipairs(announceHooks) do
		task.spawn(fn, entry)
	end
end
PrimordialRegistry.announceLocal = announceLocal

-- 태초를 받은 순간(서버 · CombatResolution · /gg drop force): 각인 · 잠금은 바로 붙이고(번호 = 발급 중), 번호 발급 · 원본 기록 · 알림은 비동기다.
-- 리뷰 2: 처치 판정(CombatResolution) 안에서 DataStore를 기다리면 광역 스킬 · 보스 보상 · despawn이 멈추고 기여 표 순회 중 새 키가 생길 수 있다 → 기다리지 않는다.
-- 번호가 나오면 같은 아이템 표(가방 · 착용 칸이 같은 참조를 들고 있다)에 채우고 onNumbered(가방 동기화 · 즉시 저장)를 부른다.
-- 번호 발급이 실패해도 알림은 보낸다(번호 없음 - 리뷰 6). options.test = 시험 키(개발 명령 · 검증) · options.silent = 알림 없이 번호만.
-- 반환 = 번호를 기다릴 수 있는 함수(검증 · 개발 명령 전용 - 게임 경로는 안 기다린다).
function PrimordialRegistry.claim(player, item, options)
	options = options or {}
	stats.claims += 1
	local ownerName = player and player.Name or "?"
	local stamp = {
		no = nil,
		pending = true,
		ownerId = player and player.UserId or 0,
		ownerName = ownerName,
		at = os.time(),
		source = item.source,
	}
	item.primordial = stamp
	item.locked = true -- ⑦ 태초 기본 잠금
	local done = false
	task.spawn(function()
		local no = PrimordialRegistry.nextNumber(options.test)
		stamp.no = no
		stamp.pending = nil
		done = true
		if not no then
			stats.claimFails += 1
			warn(("[D1] 태초 세계 번호 발급 실패(DataStore) - %s · 번호 없이 지급"):format(ownerName))
		end
		if options.onNumbered then
			pcall(options.onNumbered, no)
		end
		if options.silent then
			return
		end
		local shownName = PrimordialRegistry.filterName(ownerName, player and player.UserId or 0)
		local entry = { no = no, name = shownName, userId = stamp.ownerId, at = stamp.at, part = item.part, source = item.source, jobId = game.JobId }
		if no then
			appendRecent(entry, options.test)
		end
		announceLocal(entry)
		local ok = pcall(function()
			MessagingService:PublishAsync(topic, entry)
		end)
		if ok then
			stats.published += 1
		end
	end)
	return function(timeoutSeconds)
		local t0 = os.clock()
		while not done and os.clock() - t0 < (timeoutSeconds or 15) do
			task.wait(0.1)
		end
		return stamp.no
	end
end

-- 다른 서버의 알림 → 이 서버 배너(자기 서버가 보낸 것은 이미 알렸다).
function PrimordialRegistry.start()
	task.spawn(function()
		for attempt = 1, 6 do -- 리뷰 8: 구독 실패 = 뒤로 미루며 다시(명예의 전당은 5분 폴링으로 따로 복원된다)
			local ok = pcall(function()
				MessagingService:SubscribeAsync(topic, function(message)
					local entry = message and message.Data
					if type(entry) == "table" and entry.jobId ~= game.JobId then
						stats.received += 1
						announceLocal(entry)
					end
				end)
			end)
			if ok then
				return
			end
			task.wait(5 * 2 ^ (attempt - 1))
		end
		warn("[D1] 태초 알림 구독 실패(6회) - 다른 서버 배너는 이 서버에 안 온다(명예의 전당 폴링은 동작)")
	end)
end

local fxRemote = Instance.new("RemoteEvent")
fxRemote.Name = "PrimordialFx" -- 서버 → 받은 사람: 본인 획득 연출(태초 = 섬광 · 슬로우 · 효과음 / 고대 = 고대 색 빛기둥)
fxRemote.Parent = ReplicatedStorage

-- ① 태초 흰 빛기둥(같은 서버 전원 30초): 서버 파트 · 스트리밍 Persistent(멀리 있는 사람에게도 내려간다 - 부모 연결 전에 설정). 파티클 없이 파트 + 투명도.
local function spawnBeacon(position)
	local model = Instance.new("Model")
	model.Name = "PrimordialBeacon"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local height = PrimordialData.pillarHeights.primordial * 2
	local pillar = Instance.new("Part")
	pillar.Name = "Pillar"
	pillar.Anchored, pillar.CanCollide, pillar.CanQuery, pillar.CanTouch, pillar.CastShadow = true, false, false, false, false
	pillar.Material = Enum.Material.Neon
	pillar.Color = PrimordialData.auraColor
	pillar.Transparency = 0.15
	pillar.Size = Vector3.new(PrimordialData.beaconWidth, height, PrimordialData.beaconWidth)
	pillar.CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0))
	pillar.Parent = model
	for i = 1, 6 do -- 흰 빛줄기 6(15번 시트 ⑦ 2컷 - 바닥에서 비스듬히)
		local ray = Instance.new("Part")
		ray.Name = "Ray"
		ray.Anchored, ray.CanCollide, ray.CanQuery, ray.CanTouch, ray.CastShadow = true, false, false, false, false
		ray.Material = Enum.Material.Neon
		ray.Color = PrimordialData.auraColor
		ray.Transparency = 0.45
		ray.Size = Vector3.new(0.3, 14, 0.3)
		ray.CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(60 * i), 0) * CFrame.Angles(math.rad(35), 0, 0) * CFrame.new(0, 7, 0)
		ray.Parent = model
	end
	model.PrimaryPart = pillar
	model.Parent = Workspace
	task.delay(PrimordialData.pillarSeconds, function()
		model:Destroy()
	end)
	return model
end
PrimordialRegistry.spawnBeacon = spawnBeacon

-- 굴려진 순간의 연출 · 칭호(CombatResolution · /gg drop force). 태초: 번호 발급(claim) → 칭호 → 30초 흰 빛기둥(전원) → 본인 연출(보스전 중이면 슬로우 없음).
-- 고대: 본인 큰 연출(고대 색 빛기둥 - 본인 화면만) · 같은 서버 알림은 DropNotice(서버 범위)가 한다 · 전 서버 알림 없음.
-- deps = { PlayerProfile, ImmediateSave }(순환 require를 피하려고 호출부가 넘긴다).
function PrimordialRegistry.onRolled(player, item, position, inBossFight, deps, options)
	if item.grade == "primordial" then
		options = table.clone(options or {})
		options.onNumbered = function()
			-- 번호가 채워진 아이템을 클라에 다시 보내고(가방 · 착용 어디에 있든 같은 참조) 즉시 저장
			if deps and deps.PlayerProfile and typeof(player) == "Instance" and player.Parent then
				deps.PlayerProfile.pushInventory(player)
				if deps.ImmediateSave then
					deps.ImmediateSave.request(player)
				end
			end
		end
		local wait = PrimordialRegistry.claim(player, item, options)
		if deps and deps.PlayerProfile and typeof(player) == "Instance" then
			deps.PlayerProfile.grantTitle(player, PrimordialData.titleId)
		end
		spawnBeacon(position)
		if typeof(player) == "Instance" and player:IsA("Player") then
			fxRemote:FireClient(player, { grade = "primordial", position = position, inBoss = inBossFight == true })
		end
		return wait
	elseif item.grade == "ancient" then
		if typeof(player) == "Instance" and player:IsA("Player") then
			fxRemote:FireClient(player, { grade = "ancient", position = position, inBoss = inBossFight == true })
		end
	end
	return nil
end

-- 개발 계정 · 검증 전용: 배너 원격(수신 확인용)
function PrimordialRegistry.bannerRemote()
	return bannerRemote
end

return PrimordialRegistry
