-- QUEUE-ALL1 P3 §1 초월 알림 밀도(docs/design/v2/04) - 떨어진 서버가 한 번 판정해 entry.full · entry.fullReason을 붙인다(받는 서버는 그대로 따른다).
--   수치 = TranscendentData.announce.density · 원본 = PrimordialRegistry와 같은 DataStore(Studio = 시험 키).
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PrimordialData = require(ReplicatedStorage.Shared.data.PrimordialData)
local TranscendentData = require(ReplicatedStorage.Shared.data.TranscendentData)
local LeaderboardRules = require(ReplicatedStorage.Shared.LeaderboardRules)
local LeaderboardConfig = require(ReplicatedStorage.Shared.data.LeaderboardConfig)

local TranscendentPolicy = {}
local D = TranscendentData.announce.density
local store = DataStoreService:GetDataStore(PrimordialData.storeName)

-- 순수: 세계 번호가 이정표인가
function TranscendentPolicy.isMilestone(no)
	if type(no) ~= "number" then
		return false
	end
	return table.find(D.milestones, no) ~= nil or (no % D.milestoneEvery == 0)
end

-- 키를 원자적으로 +1 → 처음(1)이면 true
local function firstOf(key)
	local ok, value = pcall(function()
		return store:UpdateAsync(key, function(current)
			return (tonumber(current) or 0) + 1
		end)
	end)
	return ok and value == 1
end

-- 마지막 풀 연출에서 cooldownSeconds가 지났으면 지금으로 바꾸고 true(여러 서버가 겹쳐도 하나만 true)
local function cooldownPassed(key, now)
	local passed = false
	pcall(function()
		store:UpdateAsync(key, function(last)
			last = tonumber(last) or 0
			if now - last >= D.cooldownSeconds then
				passed = true
				return now
			end
			passed = false
			return nil -- 바꾸지 않음
		end)
	end)
	return passed
end

-- entry = { no, part, ... } · keyFor = PrimordialRegistry.keyFor(시험 키 규칙) · test = 시험
function TranscendentPolicy.decide(entry, keyFor, test, now)
	now = now or os.time()
	local season = LeaderboardRules.seasonAt(now, LeaderboardConfig)
	local reason = nil
	if firstOf(keyFor(D.seasonKeyPrefix .. tostring(season), test)) then
		reason = "seasonFirst"
	end
	if type(entry.part) == "string" and firstOf(keyFor(D.firstPartKeyPrefix .. entry.part .. "_s" .. tostring(season), test)) then
		reason = reason or "partFirst"
	end
	if TranscendentPolicy.isMilestone(entry.no) then
		reason = reason or "milestone"
	end
	local lastKey = keyFor(D.lastFullKey, test)
	if reason then
		pcall(function()
			store:UpdateAsync(lastKey, function()
				return now
			end)
		end)
	elseif cooldownPassed(lastKey, now) then
		reason = "cooldown"
	end
	entry.full = reason ~= nil
	entry.fullReason = reason
	return entry.full, reason
end

return TranscendentPolicy
