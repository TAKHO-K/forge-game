-- 리더보드 L1 서버(P3a B). 화면은 P3b - 여기는 기록 쓰기 · 순위 캐시 · 조회 Remote만 있다.
--
-- 저장소(시즌별로 전부 분리 - 이름 = LeaderboardConfig.namePrefix[_verify]_s<시즌>_<종류>):
--   personal          정렬 · 키 u<UserId> · 값 = 클리어한 보스 스테이지 최고(개인 순위)
--   class_<직업 id>    정렬 · 키 u<UserId> · 값 = LeaderboardRules.encode(스테이지, 클리어 시간) - 클리어 당시 직업의 저장소
--   party             정렬 · 키 = LeaderboardRules.partyKey(멤버 UserId) · 값 = encode(스테이지, 시간)
--   partyDetail       일반 · 같은 키 · 값 = { members = { { userId, name, classId } }, stage, seconds, at }(파티 기록 1건)
--   cards             일반 · 키 u<UserId>_<직업 id>(직업별) · u<UserId>(가장 최근 기록) · 값 = 무기만 공개한 카드(PlayerInspect.buildSnapshot의 weapon · 이름 · 레벨 · 환생 - 방어구는 싣지 않는다)
-- 쓰기는 기록이 오를 때만(보스 클리어로 개인 최고가 오른 멤버) · 정렬 값은 UpdateAsync로 "더 좋을 때만" 바꾼다(서버 여러 대의 경합에서도 값이 내려가지 않는다).
-- 읽기는 서버가 refreshSeconds마다 순위표별 상위 topN을 한 번 가져와 캐시하고, 클라는 캐시만 받는다(Remote LeaderboardRequest).
--
-- 부정 방지(B3): 서버가 잰 시간만 쓴다 · 이론 최소 시간보다 빠르면 거절(로그) · /gg가 돈 계정(leaderboardTainted) · 제외 목록 · Studio 수동 Play는 쓰지 않는다
-- (검증 모드는 _verify 저장소에만 쓴다 - COMMON §3).

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LeaderboardConfig = require(ReplicatedStorage.Shared.data.LeaderboardConfig)
local DevToolsConfig = require(ReplicatedStorage.Shared.data.DevToolsConfig)
local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local PartyConfig = require(ReplicatedStorage.Shared.data.PartyConfig)
local LeaderboardRules = require(ReplicatedStorage.Shared.LeaderboardRules)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local PlayerProfile = require(script.Parent.PlayerProfile)
local PlayerInspect = require(script.Parent.PlayerInspect)

local Leaderboard = {}

-- ═══ 모드 · 저장소 ═══

-- "live" = 실제 저장소 · "verify" = Studio 검증 모드(_verify 저장소) · "off" = Studio 수동 Play(쓰지 않는다 - Studio 계정은 개발 계정).
function Leaderboard.writeMode()
	if not RunService:IsStudio() then
		return "live"
	end
	return DevToolsConfig.verifyArmed and "verify" or "off"
end

local function storeName(kind)
	local prefix = LeaderboardConfig.namePrefix .. (DevToolsConfig.verifyArmed and "_verify" or "")
	return ("%s_s%d_%s"):format(prefix, LeaderboardConfig.seasonId, kind)
end
Leaderboard.storeName = storeName

local stores = {}
local function ordered(kind)
	local name = storeName(kind)
	stores[name] = stores[name] or DataStoreService:GetOrderedDataStore(name)
	return stores[name]
end

local function plain(kind)
	local name = storeName(kind)
	stores[name] = stores[name] or DataStoreService:GetDataStore(name)
	return stores[name]
end

-- 요청 수 계측(검증 · 보고가 공식 한도와 비교한다). kind = orderedWrite · plainWrite · orderedRead · list · plainRead.
local stats = { orderedWrite = 0, plainWrite = 0, orderedRead = 0, list = 0, plainRead = 0, failures = 0, rejected = 0, skipped = 0 }
function Leaderboard.stats()
	return table.clone(stats)
end

local function withRetry(label, fn)
	local ok, result = pcall(fn)
	for _, delaySeconds in ipairs(LeaderboardConfig.writeRetryDelaysSeconds) do
		if ok then
			break
		end
		warn(("[Leaderboard] %s 실패(%s) - %.0f초 뒤 재시도"):format(label, tostring(result), delaySeconds))
		task.wait(delaySeconds)
		ok, result = pcall(fn)
	end
	if not ok then
		stats.failures += 1
		warn(("[Leaderboard] %s 최종 실패 - 버림(다음 기록 때 다시 쓴다): %s"):format(label, tostring(result)))
	end
	return ok, result
end

-- 정렬 값은 "더 클 때만" 올린다 - 같은 키를 서버 두 대가 동시에 써도(드문 경합) 큰 값이 남는다.
local function raiseOrdered(kind, key, value)
	stats.orderedWrite += 1
	return withRetry(("쓰기 %s/%s"):format(kind, key), function()
		ordered(kind):UpdateAsync(key, function(old)
			if type(old) == "number" and old >= value then
				return nil -- 바꾸지 않는다
			end
			return value
		end)
	end)
end

local function setPlain(kind, key, value)
	stats.plainWrite += 1
	return withRetry(("쓰기 %s/%s"):format(kind, key), function()
		plain(kind):SetAsync(key, value)
	end)
end

-- 대기 중인 쓰기 수(검증이 쓰기가 끝날 때까지 기다린다).
local pendingWrites = 0
function Leaderboard.pendingWrites()
	return pendingWrites
end

local function spawnWrite(fn)
	pendingWrites += 1
	task.spawn(function()
		local ok, err = pcall(fn)
		if not ok then
			stats.failures += 1
			warn(("[Leaderboard] 쓰기 작업 에러: %s"):format(tostring(err)))
		end
		pendingWrites -= 1
	end)
end

-- ═══ 기록 ═══

local function playerKey(userId)
	return "u" .. tostring(userId)
end

-- 이 멤버의 기록을 쓸 수 있는가. 반환 (bool, 이유).
local function eligibility(member)
	if typeof(member) ~= "Instance" or not member:IsA("Player") then
		return false, "stand_in"
	end
	local mode = Leaderboard.writeMode()
	if mode == "off" then
		return false, "studio_manual"
	end
	if table.find(LeaderboardConfig.excludedUserIds, member.UserId) then
		return false, "excluded"
	end
	if mode == "live" and member.UserId <= 0 then
		return false, "test_account"
	end
	if PlayerProfile.isLeaderboardTainted(member) then
		return false, "gg_tainted"
	end
	if not PlayerProfile.getClassId(member) then
		return false, "no_class"
	end
	return true, "ok"
end
Leaderboard.eligibility = eligibility

-- 보스가 받는 피해 배율의 최대(파훼 창) - 데이터에서 한 번 계산한다.
local maxBossDamageTaken = 1
for _, boss in pairs(BossData.bosses) do
	for _, skill in pairs(boss.skills or {}) do
		local window = skill.breakWindow or (skill.gate and skill.gate.breakWindow)
		if window and window.damageTakenMultiplier then
			maxBossDamageTaken = math.max(maxBossDamageTaken, window.damageTakenMultiplier)
		end
	end
end

-- 멤버 한 명의 이론 최대 DPS(실제 전투 함수 그대로의 공격력 · 공속 · 치명 피해 + 최대 버프 · 여유 배율).
function Leaderboard.memberDpsCap(member)
	local summary = typeof(member) == "Instance" and PlayerProfile.getStatSummary(member)
	local classId = summary and PlayerProfile.getClassId(member)
	if not summary or not classId then
		return 0
	end
	local class = ClassData.classes[classId]
	local cooldown = PlayerCombat.getAttackCooldown(classId, summary.speedPercent)
	local critDamage = class.critDmg + (summary.critDmg or 0) + CombatConfig.guaranteedCritOverflowBonus
	return LeaderboardRules.memberDpsCap(summary.attack, cooldown, critDamage, maxBossDamageTaken * (1 + PartyConfig.healerBuffFraction))
end

local function writeCard(member, classId)
	local profile = PlayerProfile.getProfile(member)
	local classState = profile and profile.classes[classId]
	if not classState then
		return
	end
	local snapshot = PlayerInspect.buildSnapshot({
		userId = member.UserId, name = member.Name, displayName = member.DisplayName, classId = classId, classState = classState,
	})
	-- 무기만 공개(PRD 20.12-1) - 방어구(equipment)는 카드에 싣지 않는다(화면은 "?"로 그린다 - P3b).
	-- 두 키: u<id>_<직업>(직업별 순위의 카드) · u<id>(개인 순위 = 가장 최근 기록의 카드).
	local card = {
		userId = snapshot.userId, name = snapshot.name, displayName = snapshot.displayName, classId = snapshot.classId,
		level = snapshot.level, rebirthCount = snapshot.rebirthCount, weapon = snapshot.weapon, at = os.time(),
	}
	setPlain("cards", ("%s_%s"):format(playerKey(member.UserId), classId), card)
	setPlain("cards", playerKey(member.UserId), card)
end

-- 최근 판정 기록(검증이 읽는다).
local lastJudgement = nil
function Leaderboard.lastJudgement()
	return lastJudgement
end

-- CombatResolution.handleBossDeath가 진도 판정 직후 부른다.
-- info = { stage, bossId, bossMaxHp, seconds(서버 시간 - nil이면 기록 없음), isParty, partyRecord, members = { { player, advanced, reason, ratio } } }
function Leaderboard.onBossCleared(info)
	local judgement = { stage = info.stage, seconds = info.seconds, writes = {}, reasons = {}, party = false }
	lastJudgement = judgement
	if not info.seconds then
		judgement.rejected = "no_server_time"
		return judgement
	end
	-- 부정 방지: 이론 최소 시간(멤버 전원의 이론 최대 DPS 합 - 10% 미만 멤버도 피해를 넣었다)보다 빠르면 이 처치의 기록을 전부 거절한다.
	local caps = {}
	for _, entry in ipairs(info.members) do
		table.insert(caps, Leaderboard.memberDpsCap(entry.player))
	end
	judgement.minSeconds = LeaderboardRules.minClearSeconds(info.bossMaxHp or 0, caps)
	if info.seconds < judgement.minSeconds then
		stats.rejected += 1
		judgement.rejected = "too_fast"
		warn(("[Leaderboard] 기록 거절: 스테이지 %d · %.2f초 < 이론 최소 %.2f초(보스 HP %.3g ÷ DPS 상한 합)"):format(
			info.stage, info.seconds, judgement.minSeconds, info.bossMaxHp or 0))
		return judgement
	end

	local allEligible = true
	for _, entry in ipairs(info.members) do
		local ok, reason = eligibility(entry.player)
		allEligible = allEligible and ok
		judgement.reasons[entry.player] = reason
		if entry.advanced and ok then
			local member, classId = entry.player, PlayerProfile.getClassId(entry.player)
			local key = playerKey(member.UserId)
			local value = LeaderboardRules.encode(info.stage, info.seconds)
			table.insert(judgement.writes, { player = member, classId = classId, value = value })
			spawnWrite(function()
				raiseOrdered("personal", key, info.stage)
				raiseOrdered("class_" .. classId, key, value)
				writeCard(member, classId)
			end)
		elseif entry.advanced then
			stats.skipped += 1
		end
	end

	if info.partyRecord and allEligible then
		local ids, detail = {}, { members = {}, stage = info.stage, seconds = info.seconds, at = os.time() }
		for _, entry in ipairs(info.members) do
			table.insert(ids, entry.player.UserId)
			table.insert(detail.members, { userId = entry.player.UserId, name = entry.player.Name, classId = PlayerProfile.getClassId(entry.player) })
		end
		local key = LeaderboardRules.partyKey(ids)
		judgement.party = key
		local value = LeaderboardRules.encode(info.stage, info.seconds)
		spawnWrite(function()
			raiseOrdered("party", key, value)
			setPlain("partyDetail", key, detail)
		end)
	end
	print(("[forge-game] 리더보드: 스테이지 %d · %.1f초(최소 %.2f) · 개인 쓰기 %d · 파티 %s · 모드 %s"):format(
		info.stage, info.seconds, judgement.minSeconds, #judgement.writes, judgement.party or "없음", Leaderboard.writeMode()))
	return judgement
end

-- ═══ 읽기 캐시 ═══

-- 순위표 id 목록: personal · class:<직업> · party.
local function boardIds()
	local list = { "personal", "party" }
	for _, classId in ipairs(ClassData.order) do
		table.insert(list, "class:" .. classId)
	end
	return list
end

local function kindOf(boardId)
	if boardId == "personal" or boardId == "party" then
		return boardId
	end
	local classId = boardId:match("^class:(.+)$")
	if classId and ClassData.classes[classId] then
		return "class_" .. classId
	end
	return nil
end

local cache = {} -- [boardId] = { entries = { { rank, key, userId, stage, seconds } }, updatedAt = os.time() }

local function decodeEntry(boardId, rank, item)
	local entry = { rank = rank, key = item.key }
	entry.userId = tonumber(item.key:match("^u(%-?%d+)$"))
	if boardId == "personal" then
		entry.stage = item.value
	else
		entry.stage, entry.seconds = LeaderboardRules.decode(item.value)
	end
	return entry
end

function Leaderboard.refreshBoard(boardId)
	local kind = kindOf(boardId)
	if not kind then
		return false
	end
	stats.list += 1
	local ok, pages = withRetry("읽기 " .. kind, function()
		return ordered(kind):GetSortedAsync(false, LeaderboardConfig.topN)
	end)
	if not ok then
		return false
	end
	local entries = {}
	for rank, item in ipairs(pages:GetCurrentPage()) do
		entries[rank] = decodeEntry(boardId, rank, item)
	end
	cache[boardId] = { entries = entries, updatedAt = os.time() }
	return true
end

function Leaderboard.refreshAll()
	for _, boardId in ipairs(boardIds()) do
		Leaderboard.refreshBoard(boardId)
	end
end

function Leaderboard.getBoard(boardId)
	return cache[boardId]
end

-- 캐시 안에서 내 순위(상위 topN 밖이면 nil).
function Leaderboard.rankInCache(boardId, userId)
	local board = cache[boardId]
	for _, entry in ipairs(board and board.entries or {}) do
		if entry.userId == userId then
			return entry.rank, entry
		end
	end
	return nil
end

-- ═══ 조회 Remote ═══

local remote = Instance.new("RemoteFunction")
remote.Name = "LeaderboardRequest"
remote.Parent = ReplicatedStorage

local lastRequestAt = {} -- [Player] = { [action] = os.clock() }
local cardCache = {} -- [저장 키] = { value, at }

local function rateLimited(player, action, now)
	local byAction = lastRequestAt[player] or {}
	lastRequestAt[player] = byAction
	local last = byAction[action]
	if last and now - last < (LeaderboardConfig.requestIntervalSeconds[action] or 1) then
		return true
	end
	byAction[action] = now
	return false
end

local function seasonInfo()
	local endsAt = LeaderboardConfig.seasonStartUnix > 0 and (LeaderboardConfig.seasonStartUnix + LeaderboardConfig.seasonLengthDays * 86400) or nil
	return { id = LeaderboardConfig.seasonId, lengthDays = LeaderboardConfig.seasonLengthDays, endsAt = endsAt }
end

-- 요청 하나. action = "board"(boardId) · "me"(boardId) · "card"(boardId, key). now는 검증이 시간을 주입할 때만.
function Leaderboard.handle(player, action, boardId, key, now)
	now = now or os.clock()
	if type(action) ~= "string" or type(boardId) ~= "string" or not kindOf(boardId) then
		return { ok = false, reason = "bad_request" }
	end
	if rateLimited(player, action, now) then
		return { ok = false, reason = "rate_limited" }
	end
	if action == "board" then
		local board = cache[boardId]
		return { ok = true, entries = board and board.entries or {}, updatedAt = board and board.updatedAt or nil, season = seasonInfo() }
	elseif action == "me" then
		-- 캐시 안이면 그 순위, 밖이면 내 저장 값 하나만 읽는다(정렬 저장소에는 "몇 위인가" 조회가 없다 - 상위 topN 밖은 "topN위 밖"으로 보인다).
		local rank, entry = Leaderboard.rankInCache(boardId, player.UserId)
		if rank then
			return { ok = true, rank = rank, stage = entry.stage, seconds = entry.seconds }
		end
		stats.orderedRead += 1
		local ok, value = withRetry("내 기록 읽기", function()
			return ordered(kindOf(boardId)):GetAsync(playerKey(player.UserId))
		end)
		if not ok then
			return { ok = false, reason = "store_error" }
		end
		if type(value) ~= "number" then
			return { ok = true, rank = nil, outOfTop = false }
		end
		local decoded = decodeEntry(boardId, nil, { key = playerKey(player.UserId), value = value })
		return { ok = true, rank = nil, outOfTop = true, topN = LeaderboardConfig.topN, stage = decoded.stage, seconds = decoded.seconds }
	elseif action == "card" then
		if type(key) ~= "string" or #key > 50 then
			return { ok = false, reason = "bad_request" }
		end
		local kind = kindOf(boardId)
		local storeKind, storeKey = "cards", key
		if kind == "party" then
			storeKind = "partyDetail"
		else
			if not key:match("^u%-?%d+$") then
				return { ok = false, reason = "bad_request" }
			end
			local classId = boardId:match("^class:(.+)$")
			if classId then
				storeKey = ("%s_%s"):format(key, classId) -- 직업별 순위 = 그 직업의 카드 · 개인 순위 = 가장 최근 기록의 카드(u<id>)
			end
		end
		local cached = cardCache[storeKey]
		if cached and os.clock() - cached.at < LeaderboardConfig.cardCacheSeconds then
			return { ok = true, card = cached.value }
		end
		stats.plainRead += 1
		local ok, value = withRetry("카드 읽기", function()
			return plain(storeKind):GetAsync(storeKey)
		end)
		if not ok then
			return { ok = false, reason = "store_error" }
		end
		cardCache[storeKey] = { value = value, at = os.clock() }
		return { ok = true, card = value }
	end
	return { ok = false, reason = "bad_request" }
end

remote.OnServerInvoke = function(player, action, boardId, key)
	return Leaderboard.handle(player, action, boardId, key)
end

Players.PlayerRemoving:Connect(function(player)
	lastRequestAt[player] = nil
end)

-- 주기 갱신: 서버에 사람이 있을 때만(빈 서버가 한도를 쓰지 않는다). 첫 갱신은 첫 접속 직후.
task.spawn(function()
	while true do
		if #Players:GetPlayers() > 0 then
			Leaderboard.refreshAll()
			task.wait(LeaderboardConfig.refreshSeconds)
		else
			task.wait(5)
		end
	end
end)

return Leaderboard
