-- QUEUE-ALL1 P3 §4 전 서버 합동 목표(서버). 규칙 · 수치 = shared/CommunityGoalRules · shared/data/CommunityGoalData.
--   note(player, kind) = 기여(보스 처치 · 초월) → 1인 하루 상한(MemoryStore) → 이 서버 대기 몫 + 그 사람 주간 기여(profile.communityGoal.contributed).
--   flushSeconds마다 대기 몫을 DataStore 주 키에 더하고(UpdateAsync) 합계 · 목표를 다시 읽어 Workspace 속성(CommunityGoalTotal · Target · Week)에 싣는다.
--   목표 = 그 주 키에 없으면 지난 3주 기록으로 정하고(주 중간 불변) · 기록이 없으면 첫 기여부터 24시간 실측 × 7 × week1Factor.
--   칸 달성 = 이 서버가 합계를 읽다가 넘은 것을 보면 전원 배너(서버마다 스스로 - 첫 읽기 때는 알리지 않는다).
--   수령 = RemoteFunction CommunityGoalClaim(칸 번호) → 닿았고 · 그 주 기여 ≥ 1 · 안 받았으면 보상(QuestService.grant · 칭호 = grantTitle).
local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local D = require(ReplicatedStorage.Shared.data.CommunityGoalData)
local Rules = require(ReplicatedStorage.Shared.CommunityGoalRules)
local Quest = require(ReplicatedStorage.Shared.Quest)
local Text = require(ReplicatedStorage.Shared.Text)
local NestData = require(ReplicatedStorage.Shared.data.NestData)
local PlayerProfile = require(script.Parent.PlayerProfile)
local RequestGate = require(script.Parent.RequestGate) -- QUEUE-ALL4 B: 공통 요청 제한

local CommunityGoalService = {}
local store = DataStoreService:GetDataStore(D.storeName)
local dailyMap = nil
pcall(function()
	dailyMap = MemoryStoreService:GetHashMap(D.dailyMapName)
end)
local prefix = RunService:IsStudio() and D.studioKeyPrefix or ""

local pending = 0
local sessionDaily = {} -- [userId .. day] = 이 세션에서 센 양(MemoryStore 실패 때의 상한)
local lastTier = nil -- 이 서버가 본 칸(nil = 아직 첫 읽기 전 - 알리지 않는다)
local bannerRemote = Instance.new("RemoteEvent")
bannerRemote.Name = "CommunityGoalBanner" -- 서버 → 클라: { tier, percent }
bannerRemote.Parent = ReplicatedStorage
local claimRemote = Instance.new("RemoteFunction")
claimRemote.Name = "CommunityGoalClaim" -- 클라 → 서버: 칸 번호 → { ok, message }
claimRemote.Parent = ReplicatedStorage

local function weekNow()
	return Quest.weekOf(os.time())
end
local function keyOf(week)
	return prefix .. "week_" .. tostring(week)
end

-- 그 사람의 주간 기록(주가 바뀌면 새로)
local function recordOf(player)
	local r = PlayerProfile.getCommunityGoal(player)
	if not r then
		return nil
	end
	local w = weekNow()
	if r.week ~= w then
		r.week, r.contributed, r.claimed = w, 0, {}
	end
	return r
end

-- 1인 하루 상한: 받아들인 양(0 ~ amount)
local function acceptDaily(player, amount)
	local day = math.floor(os.time() / 86400)
	local key = tostring(player.UserId) .. "_" .. tostring(day)
	local accepted = nil
	if dailyMap then
		local ok = pcall(function()
			dailyMap:UpdateAsync(key, function(current)
				current = tonumber(current) or 0
				accepted = math.max(0, math.min(amount, D.dailyCapPerPlayer - current))
				return current + accepted
			end, (day + 1) * 86400 - os.time() + D.dailyTtlMarginSeconds) -- QUEUE-ALL4 C: 그날 UTC 끝 + 여유(옛 = 2일 - 메모리 한도가 동시 접속 기준이라 하루 접속자 키가 두 배로 쌓였다)
		end)
		if ok and accepted then
			return accepted
		end
	end
	local used = sessionDaily[key] or 0
	accepted = math.max(0, math.min(amount, D.dailyCapPerPlayer - used))
	sessionDaily[key] = used + accepted
	return accepted
end

function CommunityGoalService.note(player, kind)
	local weight = D.weights[kind]
	if not (weight and typeof(player) == "Instance" and player:IsA("Player")) then
		return
	end
	task.spawn(function()
		local accepted = kind == "transcendent" and weight or acceptDaily(player, weight) -- 초월 = 상한 밖(드물고 큰 칸)
		if accepted <= 0 then
			return
		end
		pending += accepted
		local r = recordOf(player)
		if r then
			r.contributed += accepted
			player:SetAttribute("CommunityGoalContributed", r.contributed)
		end
	end)
end

local function publish(rec, week)
	Workspace:SetAttribute("CommunityGoalWeek", week)
	Workspace:SetAttribute("CommunityGoalTotal", rec.total or 0)
	local target = type(rec.target) == "number" and Rules.finalTarget(rec.target) or nil -- QUEUE-ALL7 B: 이번 주 이미 정해진 옛 목표(00 아님)도 보여 주는 값 · 칸 판정은 00으로(저장된 기록은 그대로)
	Workspace:SetAttribute("CommunityGoalTarget", target)
	local tier = Rules.tiersReached(rec.total or 0, target)
	if lastTier ~= nil and tier > lastTier then
		local t = D.tiers[tier]
		bannerRemote:FireAllClients({ tier = tier, percent = math.floor(t.fraction * 100 + 0.5), label = t.label })
	end
	lastTier = tier
end

local function flush()
	local week = weekNow()
	local add = pending
	pending = 0
	local rec = nil
	local ok = pcall(function()
		rec = store:UpdateAsync(keyOf(week), function(current)
			current = type(current) == "table" and current or { total = 0 }
			current.total = (current.total or 0) + add
			if add > 0 and not current.firstAt then
				current.firstAt = os.time()
			end
			if current.firstAt and not current.total24 and os.time() - current.firstAt >= 86400 then
				current.total24 = current.total
			end
			return current
		end)
	end)
	if not ok then
		pending += add -- 다음 번에 다시
		return
	end
	if type(rec) == "table" and not rec.target then
		-- 목표 정하기(지난 3주 기록 · 없으면 1주차 24시간 실측) - 한 번 정하면 주 중간에 안 바뀐다
		local hist = {}
		for i = 1, #D.baselineWeights do
			local okh, h = pcall(function()
				return store:GetAsync(keyOf(week - i))
			end)
			hist[i] = okh and type(h) == "table" and h or nil
		end
		local target = Rules.targetFromHistory(hist)
		if not target and rec.total24 then
			target = Rules.week1Target(rec.total24)
		end
		if target then
			pcall(function()
				rec = store:UpdateAsync(keyOf(week), function(current)
					current = type(current) == "table" and current or rec
					current.target = current.target or target
					return current
				end)
			end)
		end
	end
	if type(rec) == "table" then
		publish(rec, week)
	end
end

local function claim(player, tierIndex)
	local t = type(tierIndex) == "number" and D.tiers[tierIndex]
	local r = recordOf(player)
	if not (t and r) then
		return { ok = false, message = "?" }
	end
	local reached = Rules.tiersReached(Workspace:GetAttribute("CommunityGoalTotal") or 0, Workspace:GetAttribute("CommunityGoalTarget"))
	if tierIndex > reached then
		return { ok = false, message = D.text.locked }
	end
	if (r.contributed or 0) < 1 then
		return { ok = false, message = D.text.needContribute }
	end
	if r.claimed[tostring(tierIndex)] then
		return { ok = false, message = D.text.claimed }
	end
	if t.reward.egg and #PlayerProfile.getEggs(player) + t.reward.egg > NestData.eggCap then
		return { ok = false, message = Text.getFor(player, "shop.reason.eggFull") } -- QUEUE-ALL4 B: 받은 표시 전에(옛 코드 = 칸은 받음 · 알은 가방 가득으로 사라짐 - QuestService.claim과 같은 규칙)
	end
	r.claimed[tostring(tierIndex)] = true
	if t.reward.title then
		PlayerProfile.grantTitle(player, t.reward.title)
	end
	local rest = table.clone(t.reward)
	rest.title = nil
	require(script.Parent.QuestService).grant(player, rest)
	require(script.Parent.ImmediateSave).request(player)
	player:SetAttribute("CommunityGoalClaimed", table.concat((function()
		local list = {}
		for k in pairs(r.claimed) do
			table.insert(list, k)
		end
		table.sort(list)
		return list
	end)(), ","))
	return { ok = true, message = t.label }
end
CommunityGoalService.claim = claim -- 하네스 · 검증
claimRemote.OnServerInvoke = function(player, tierIndex)
	return RequestGate.invoke(player, "CommunityGoalClaim", tostring(tierIndex), function() -- QUEUE-ALL4 B: 공통 요청 제한(함수 기본 통)
		return claim(player, tierIndex)
	end)
end

function CommunityGoalService.onLoaded(player)
	local r = recordOf(player)
	if r then
		player:SetAttribute("CommunityGoalContributed", r.contributed or 0)
		local list = {}
		for k in pairs(r.claimed or {}) do
			table.insert(list, k)
		end
		table.sort(list)
		player:SetAttribute("CommunityGoalClaimed", table.concat(list, ","))
	end
end

function CommunityGoalService.start()
	task.spawn(function()
		while true do
			local okf, err = pcall(flush)
			if not okf then
				warn("[CommunityGoal] " .. tostring(err))
			end
			task.wait(D.flushSeconds)
		end
	end)
	game:BindToClose(function() -- QUEUE-ALL5 D②: 종료 때 마지막 주기의 기여분(pending)도 합계에 넣는다(개인 contributed는 저장되는데 합계만 빠졌다)
		if pending > 0 then
			pcall(flush)
		end
	end)
end

-- 검증 · 개발 전용
CommunityGoalService.debugFlush = flush
function CommunityGoalService.debugPending()
	return pending
end

return CommunityGoalService
