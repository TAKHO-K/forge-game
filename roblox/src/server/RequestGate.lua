-- 공통 요청 제한 입구(QUEUE-6h-b 후속 - security-audit-alpha F6 · F7). 수치 = shared/data/RequestLimitConfig.
--   RemoteEvent: 핸들러 첫 줄 `if not RequestGate.allow(player, "<Remote 이름>") then return end`
--   RemoteFunction: `return RequestGate.invoke(player, "<이름>", 인자 키, function() ... end)` - 통이 비면 계산하지 않고 그 인자의 마지막 결과(없으면 nil).
-- 사람 × Remote마다 토큰 통(burst개 · 초당 perSecond개 충전). 버린 요청 수는 RequestGate.dropped(검증 · 하네스용).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RequestLimitConfig = require(ReplicatedStorage.Shared.data.RequestLimitConfig)

local RequestGate = {}

local buckets = {} -- [Player] = { [key] = { tokens, at } }
local results = {} -- [Player] = { [key] = { argKey, at, value } }
RequestGate.dropped = {} -- [key] = 버린 수

local function take(player, key, limit)
	local now = os.clock()
	local perPlayer = buckets[player]
	if not perPlayer then
		perPlayer = {}
		buckets[player] = perPlayer
	end
	local b = perPlayer[key]
	if not b then
		b = { tokens = limit.burst, at = now }
		perPlayer[key] = b
	end
	b.tokens = math.min(limit.burst, b.tokens + (now - b.at) * limit.perSecond)
	b.at = now
	if b.tokens < 1 then
		RequestGate.dropped[key] = (RequestGate.dropped[key] or 0) + 1
		return false
	end
	b.tokens -= 1
	return true
end

function RequestGate.allow(player, key)
	return take(player, key, RequestLimitConfig.remotes[key] or RequestLimitConfig.default)
end

function RequestGate.invoke(player, key, argKey, compute)
	local perPlayer = results[player]
	if not perPlayer then
		perPlayer = {}
		results[player] = perPlayer
	end
	local last = perPlayer[key]
	if not take(player, key, RequestLimitConfig.remotes[key] or RequestLimitConfig.functionDefault) then
		return last and last.argKey == argKey and last.value or nil
	end
	local value = compute()
	perPlayer[key] = { argKey = argKey, value = value }
	return value
end

Players.PlayerRemoving:Connect(function(player)
	buckets[player] = nil
	results[player] = nil
end)

return RequestGate
