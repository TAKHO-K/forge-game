-- QUEUE-ALL9E1 0-5(P3-5) 초월 강화 최초 달성 · 성공 알림. 숫자 · 키 = shared/data/All10Data.transcendFirsts.
--   ① 최초(levels): DataStore UpdateAsync 선점 - 키 하나(launchEpoch:단계)에 처음 쓴 사람만 남는다(두 서버가 동시에 올려도 UpdateAsync가 한쪽을 다시 돌려 진 쪽은 이미 있는 값을 본다).
--      이긴 사람 = 칭호 · 감사 기록 · 전 서버 배너(MessagingService - best-effort · 원본은 DataStore) · 명예의 전당 "초월 강화" 줄(HallOfFame이 원본을 5분마다 다시 읽는다).
--   ② 그 밖 localFromLevel 이상 성공 = 같은 서버 알림(최초면 ①이 대신한다).
--   Studio = 시험 키 · 시험 토픽(실제 기록을 안 올린다) · 개발 계정(LeaderboardConfig.excludedUserIds) = 최초 대상 아님(같은 서버 알림만).
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local All10Data = require(ReplicatedStorage.Shared.data.All10Data)
local PrimordialData = require(ReplicatedStorage.Shared.data.PrimordialData)
local LeaderboardConfig = require(ReplicatedStorage.Shared.data.LeaderboardConfig)
local Text = require(ReplicatedStorage.Shared.Text)

local TranscendFirsts = {}
local D = All10Data.transcendFirsts
local isStudio = RunService:IsStudio()
local topic = D.topic .. (isStudio and "_studio" or "")

-- 테스트 주입(하네스): store = { UpdateAsync, GetAsync } · test = 시험 키 강제
TranscendFirsts.deps = nil

local storeCache
local function store()
	if TranscendFirsts.deps and TranscendFirsts.deps.store then
		return TranscendFirsts.deps.store
	end
	storeCache = storeCache or DataStoreService:GetDataStore(D.storeName)
	return storeCache
end

function TranscendFirsts.keyFor(level)
	local key = D.launchEpoch .. ":" .. tostring(level)
	if isStudio or (TranscendFirsts.deps and TranscendFirsts.deps.test) then
		return PrimordialData.testKeyPrefix .. key
	end
	return key
end

function TranscendFirsts.isFirstLevel(level)
	return table.find(D.levels, level) ~= nil
end

function TranscendFirsts.excluded(userId)
	return table.find(LeaderboardConfig.excludedUserIds or {}, userId) ~= nil
end

-- 선점 시도: 반환 = 이겼나, 지금 기록(이긴 사람 표 | nil = 실패). 같은 사람이 다시 와도(재시도) 이긴 것으로 본다.
function TranscendFirsts.tryClaim(level, entry)
	local ok, result = pcall(function()
		return store():UpdateAsync(TranscendFirsts.keyFor(level), function(current)
			if type(current) == "table" and current.userId then
				return nil -- 이미 누가 있다 = 쓰지 않음(UpdateAsync nil = 취소)
			end
			return entry
		end)
	end)
	if not ok then
		return false, nil
	end
	local record = result
	if record == nil then -- 취소됨 = 이미 있던 값 읽기
		local okGet, cur = pcall(function()
			return store():GetAsync(TranscendFirsts.keyFor(level))
		end)
		record = okGet and cur or nil
	end
	return type(record) == "table" and record.userId == entry.userId, record
end

-- 기록 전부(명예의 전당) - { { level, userId, name, at } } 높은 단계부터 · 실패 = nil
function TranscendFirsts.readAll()
	local rows = {}
	for _, level in ipairs(D.levels) do
		local ok, cur = pcall(function()
			return store():GetAsync(TranscendFirsts.keyFor(level))
		end)
		if not ok then
			return nil
		end
		if type(cur) == "table" and cur.userId then
			table.insert(rows, { level = level, userId = cur.userId, name = cur.name, at = cur.at })
		end
	end
	table.sort(rows, function(a, b)
		return a.level > b.level
	end)
	return rows
end

local bannerRemote = Instance.new("RemoteEvent")
bannerRemote.Name = "TranscendFirstBanner" -- 서버 → 클라: { key, args } 상단 배너(각자 언어로 - 클라가 Text.get)
bannerRemote.Parent = ReplicatedStorage

local function noticeAll(key, args)
	local notice = ReplicatedStorage:FindFirstChild("SystemNotice")
	for _, other in ipairs(Players:GetPlayers()) do
		if notice then
			notice:FireClient(other, Text.getFor(other, key, args))
		end
	end
end

local function bannerAll(level, name)
	noticeAll("srv.transcend.firstAnnounce", { name = name, level = tostring(level) })
	bannerRemote:FireAllClients({ key = "srv.transcend.firstAnnounce", args = { name = name, level = tostring(level) } })
end

-- 단계 도달(TranscendService.payEnhance 성공 → task.spawn)
function TranscendFirsts.onReached(player, level)
	local name = player.DisplayName
	if TranscendFirsts.isFirstLevel(level) and not TranscendFirsts.excluded(player.UserId) then
		local entry = { userId = player.UserId, name = require(script.Parent.PrimordialRegistry).filterName(name, player.UserId), at = os.time(), level = level, jobId = game.JobId }
		local won = TranscendFirsts.tryClaim(level, entry)
		if won then
			local titleId = D.titleIds[level]
			if titleId then
				require(script.Parent.PlayerProfile).grantTitle(player, titleId)
			end
			require(script.Parent.AuditTrail).note(player, "transcendFirst", ("전 서버 최초 초월 +%d · %s"):format(level, TranscendFirsts.keyFor(level)))
			bannerAll(level, entry.name)
			pcall(function()
				MessagingService:PublishAsync(topic, { level = level, name = entry.name, jobId = game.JobId })
			end)
			local ok, HallOfFame = pcall(require, script.Parent.HallOfFame)
			if ok and HallOfFame.addFirst then
				HallOfFame.addFirst(entry)
			end
			return "first"
		end
	end
	if level >= D.localFromLevel then
		noticeAll("srv.transcend.enhAnnounce", { name = name, level = tostring(level) })
		return "local"
	end
	return nil
end

function TranscendFirsts.start()
	task.spawn(function()
		for attempt = 1, 6 do
			local ok = pcall(function()
				MessagingService:SubscribeAsync(topic, function(message)
					local data = message and message.Data
					if type(data) == "table" and data.jobId ~= game.JobId and tonumber(data.level) then
						bannerAll(data.level, tostring(data.name))
						local okH, HallOfFame = pcall(require, script.Parent.HallOfFame)
						if okH and HallOfFame.addFirst then
							HallOfFame.addFirst({ level = data.level, name = data.name, at = os.time() })
						end
					end
				end)
			end)
			if ok then
				return
			end
			task.wait(5 * 2 ^ (attempt - 1))
		end
		warn("[ALL9E1] 초월 최초 알림 구독 실패(6회) - 다른 서버 배너는 안 온다(명예의 전당 폴링은 동작)")
	end)
end

return TranscendFirsts
