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
local HeightGuard = require(script.Parent.HeightGuard) -- G2a: 보스전 중 높이 보정을 받은 판은 기록 거절

local Leaderboard = {}

-- ═══ 모드 · 저장소 ═══

-- "live" = 실제 저장소 · "verify" = Studio 검증 모드(_verify 저장소) · "off" = Studio 수동 Play(쓰지 않는다 - Studio 계정은 개발 계정).
function Leaderboard.writeMode()
	if not RunService:IsStudio() then
		return "live"
	end
	return DevToolsConfig.verifyArmed and "verify" or "off"
end

-- P3c C7: 지금 시즌(시작일 + 28일마다 자동 - LeaderboardRules.seasonAt). 검증은 debugSeason으로 시즌을 고정한다.
Leaderboard.debugSeason = nil
function Leaderboard.currentSeason()
	return Leaderboard.debugSeason or LeaderboardRules.seasonAt(os.time(), LeaderboardConfig)
end

local function prefix()
	return LeaderboardConfig.namePrefix .. (DevToolsConfig.verifyArmed and "_verify" or "")
end

-- season을 안 주면 지금 시즌 - 새 시즌이 되면 저장소 이름이 바뀌어 순위표가 0부터 시작한다.
local function storeName(kind, season)
	return ("%s_s%d_%s"):format(prefix(), season or Leaderboard.currentSeason(), kind)
end
Leaderboard.storeName = storeName

local stores = {}
local function ordered(kind, season)
	local name = storeName(kind, season)
	stores[name] = stores[name] or DataStoreService:GetOrderedDataStore(name)
	return stores[name]
end

local function plain(kind, season)
	local name = storeName(kind, season)
	stores[name] = stores[name] or DataStoreService:GetDataStore(name)
	return stores[name]
end

-- 명예의 전당 저장소(시즌과 무관한 하나 - 키 s<시즌>).
local function hallStore()
	local name = prefix() .. "_hall"
	stores[name] = stores[name] or DataStoreService:GetDataStore(name)
	return stores[name]
end
Leaderboard.hallStoreName = function()
	return prefix() .. "_hall"
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

-- 정렬 값은 "더 클 때만" 올린다 - 같은 키를 서버 두 대가 동시에 써도(드문 경합) 큰 값이 남는다. 반환: (성공, 실제로 올렸는가).
local function raiseOrdered(kind, key, value)
	stats.orderedWrite += 1
	local raised = false
	local ok = withRetry(("쓰기 %s/%s"):format(kind, key), function()
		raised = false
		ordered(kind):UpdateAsync(key, function(old)
			if type(old) == "number" and old >= value then
				raised = false
				return nil -- 바꾸지 않는다
			end
			raised = true
			return value
		end)
	end)
	return ok, ok and raised
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
	-- P3d G-g: 라이브에서만 뺀다 - 개발 계정이 목록에 있어도 Studio 검증 모드(_verify 저장소)는 그 계정으로 기록 경로를 잰다.
	if mode == "live" and table.find(LeaderboardConfig.excludedUserIds, member.UserId) then
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
	-- 부정 방지: 이론 최소 시간(피해를 넣은 사람 전원의 이론 최대 DPS 합 - 10% 미만 멤버 · 도중에 빠진 멤버도 피해를 넣었다)보다 빠르면 이 처치의 기록을 전부 거절한다.
	local caps, counted = {}, {}
	for _, entry in ipairs(info.members) do
		counted[entry.player] = true
		table.insert(caps, Leaderboard.memberDpsCap(entry.player))
	end
	for _, contributor in ipairs(info.contributors or {}) do
		if not counted[contributor] then
			counted[contributor] = true
			table.insert(caps, Leaderboard.memberDpsCap(contributor))
		end
	end
	judgement.minSeconds = LeaderboardRules.minClearSeconds(info.bossMaxHp or 0, caps)
	if info.seconds < judgement.minSeconds then
		stats.rejected += 1
		judgement.rejected = "too_fast"
		warn(("[Leaderboard] 기록 거절: 스테이지 %d · %.2f초 < 이론 최소 %.2f초(보스 HP %.3g ÷ DPS 상한 합)"):format(
			info.stage, info.seconds, judgement.minSeconds, info.bossMaxHp or 0))
		return judgement
	end
	-- G2a(D0 결정 3): 이 보스전이 시작된 뒤 서버 높이 검증이 되돌린 사람이 있으면(피해를 넣은 사람 전원 - 위와 같은 범위) 이 처치의 기록을 전부 거절한다.
	local startedAt = os.clock() - info.seconds
	for contributor in pairs(counted) do
		if HeightGuard.flaggedSince(contributor, startedAt) then
			stats.rejected += 1
			judgement.rejected = "height_guard"
			warn(("[Leaderboard] 기록 거절: 스테이지 %d - %s 높이 보정(보스전 중)"):format(info.stage, tostring(contributor.Name)))
			return judgement
		end
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
			-- 상세는 순위 값이 실제로 올랐을 때만 쓴다(리뷰 5 - 같은 구성이 다른 직업으로 더 낮은 스테이지를 깨도 상세가 덮이지 않게).
			local _, raised = raiseOrdered("party", key, value)
			if raised then
				setPlain("partyDetail", key, detail)
			end
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

-- ═══ 이름(P3b A) ═══
-- 정렬 저장소에는 키(u<UserId> · p<id>_<id>)와 숫자만 있다 - 화면 이름은 서버가 UserService로 한 번에 풀어 캐시한다(순위표 갱신 때 모르는 id만 · 요청 수 = 새 id 200명당 1회).
-- 같은 서버에 있는 사람은 Players에서 바로 읽는다. 못 풀면 화면이 "#<id>"로 그린다.
local UserService = game:GetService("UserService")
local nameById = {} -- [userId] = 표시 이름
local nameCount = 0
local NAME_CACHE_LIMIT = 5000
local NAME_BATCH = 200

local function keyUserIds(key)
	local ids = {}
	for id in key:sub(2):gmatch("[^_]+") do
		table.insert(ids, tonumber(id))
	end
	return ids
end

local function resolveNames(ids)
	local unknown = {}
	for _, id in ipairs(ids) do
		if id and not nameById[id] then
			local online = Players:GetPlayerByUserId(id)
			if online then
				nameById[id] = online.DisplayName
			elseif id > 0 and not table.find(unknown, id) then
				table.insert(unknown, id)
			end
		end
	end
	if nameCount > NAME_CACHE_LIMIT then
		table.clear(nameById)
		nameCount = 0
	end
	for start = 1, #unknown, NAME_BATCH do
		local batch = table.move(unknown, start, math.min(start + NAME_BATCH - 1, #unknown), 1, {})
		local ok, infos = pcall(function()
			return UserService:GetUserInfosByUserIdsAsync(batch)
		end)
		if ok and type(infos) == "table" then
			for _, info in ipairs(infos) do
				nameById[info.Id] = info.DisplayName
				nameCount += 1
			end
		else
			warn(("[Leaderboard] 이름 조회 실패(%d명): %s"):format(#batch, tostring(infos)))
		end
	end
end

-- 목록에 나오는 사람들의 이름 표(클라가 행을 그릴 때 쓴다).
local function namesFor(entries)
	local names = {}
	for _, entry in ipairs(entries) do
		for _, id in ipairs(entry.members or { entry.userId }) do
			if nameById[id] then
				names[tostring(id)] = nameById[id]
			end
		end
	end
	return names
end

local function decodeEntry(boardId, rank, item)
	local entry = { rank = rank, key = item.key }
	entry.userId = tonumber(item.key:match("^u(%-?%d+)$"))
	if boardId == "party" then
		entry.members = keyUserIds(item.key) -- 파티 키 = 멤버 UserId(오름차순)
	end
	if boardId == "personal" then
		entry.stage = item.value
	else
		entry.stage, entry.seconds = LeaderboardRules.decode(item.value)
	end
	return entry
end

-- 한 시즌 한 순위표의 상위 count명(이름 조회 포함). 반환: entries 또는 nil(읽기 실패).
local function readTop(boardId, season, count)
	local kind = kindOf(boardId)
	stats.list += 1
	local ok, pages = withRetry("읽기 " .. kind, function()
		return ordered(kind, season):GetSortedAsync(false, count)
	end)
	if not ok then
		return nil
	end
	local entries = {}
	for rank, item in ipairs(pages:GetCurrentPage()) do
		entries[rank] = decodeEntry(boardId, rank, item)
	end
	local ids = {}
	for _, entry in ipairs(entries) do
		for _, id in ipairs(entry.members or { entry.userId }) do
			table.insert(ids, id)
		end
	end
	resolveNames(ids)
	return entries
end

function Leaderboard.refreshBoard(boardId)
	if not kindOf(boardId) then
		return false
	end
	local entries = readTop(boardId, nil, LeaderboardConfig.topN)
	if not entries then
		return false
	end
	cache[boardId] = { entries = entries, updatedAt = os.time() }
	return true
end

-- ═══ 명예의 전당(P3c C7 · E2) ═══
-- 끝난 시즌의 순위표마다 상위 hallTopN을 저장소 하나(키 s<시즌>)에 **한 번만** 쓴다(UpdateAsync - 이미 있으면 그대로: 서버 여러 대가 동시에 해도 처음 것이 남는다).
-- 시즌 저장소는 지우지 않으므로 복사가 늦어도 잃는 것은 없다. 조회는 지난 시즌(지금 − 1)의 값을 hallCacheSeconds마다 한 번 읽는다.
local hallCache = {} -- [season] = { value = 전당 값 또는 false(없음), at = os.clock() }
local hallChecked = {} -- [season] = true(이 서버가 이미 쓰기를 시도했다)

function Leaderboard.snapshotHall(season)
	if season < 1 or hallChecked[season] or Leaderboard.writeMode() == "off" then
		return false
	end
	hallChecked[season] = true
	-- 리뷰 3: 먼저 전당이 이미 있는지 한 번만 본다(있으면 순위표 6개 읽기를 하지 않는다 - 서버가 켜질 때마다 정렬 읽기 6회를 쓰지 않게).
	stats.plainRead += 1
	local existsOk, existing = withRetry(("전당 확인 s%d"):format(season), function()
		return hallStore():GetAsync("s" .. season)
	end)
	if not existsOk then
		hallChecked[season] = nil
		return false
	end
	if existing ~= nil then
		hallCache[season] = { value = type(existing) == "table" and existing or false, at = os.clock() }
		return false
	end
	local boards, names = {}, {}
	for _, boardId in ipairs(boardIds()) do
		local entries = readTop(boardId, season, LeaderboardConfig.hallTopN)
		if not entries then
			hallChecked[season] = nil -- 읽기 실패 - 다음 갱신에서 다시
			return false
		end
		boards[boardId] = entries
		for key, value in pairs(namesFor(entries)) do
			names[key] = value
		end
	end
	local value = { season = season, boards = boards, names = names, savedAt = os.time() }
	stats.plainWrite += 1
	local wrote = false
	withRetry(("전당 쓰기 s%d"):format(season), function()
		wrote = false
		hallStore():UpdateAsync("s" .. season, function(old)
			if old ~= nil then
				return nil -- 이미 있다(다른 서버가 먼저 썼다) - 그대로
			end
			wrote = true
			return value
		end)
	end)
	hallCache[season] = nil
	print(("[forge-game] 명예의 전당: 시즌 %d 상위 %d 복사 %s"):format(season, LeaderboardConfig.hallTopN, wrote and "완료" or "(이미 있음)"))
	return wrote
end

-- 전당 한 시즌 읽기(캐시). 반환: 값 또는 nil.
function Leaderboard.getHall(season)
	if season < 1 or Leaderboard.writeMode() == "off" then
		return nil
	end
	local cached = hallCache[season]
	if cached and os.clock() - cached.at < LeaderboardConfig.hallCacheSeconds then
		return cached.value or nil
	end
	stats.plainRead += 1
	local ok, value = withRetry(("전당 읽기 s%d"):format(season), function()
		return hallStore():GetAsync("s" .. season)
	end)
	if not ok then
		return nil
	end
	hallCache[season] = { value = type(value) == "table" and value or false, at = os.clock() }
	return type(value) == "table" and value or nil
end

local lastSeason = nil
function Leaderboard.refreshAll()
	-- P3c C7: 시즌이 바뀌었으면 캐시를 비우고(새 시즌 = 빈 순위표) 끝난 시즌을 전당에 복사한다. 서버가 처음 돌 때도 지난 시즌을 한 번 확인한다.
	local season = Leaderboard.currentSeason()
	if lastSeason ~= season then
		if lastSeason then
			table.clear(cache)
			print(("[forge-game] 리더보드 시즌 전환: %d → %d(새 순위표)"):format(lastSeason, season))
		end
		lastSeason = season
		Leaderboard.snapshotHall(season - 1)
	end
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

-- 캐시(상위 topN) 안의 내 줄 - 파티는 내가 든 가장 높은 기록. 없으면 nil.
local function mineInCache(boardId, userId)
	for _, entry in ipairs((cache[boardId] or {}).entries or {}) do
		if table.find(entry.members or { entry.userId }, userId) then
			return { rank = entry.rank, stage = entry.stage, seconds = entry.seconds, key = entry.key }
		end
	end
	return nil
end

-- Studio 화면 확인용 가짜 순위(P3b - /gg lb fake). 수동 Play(쓰기 off)에서만 채운다 - 저장소 요청 0. [boardId] = "me" 응답(캐시 밖 표시용).
local fakeMine = nil

-- ═══ 조회 Remote ═══

local remote = Instance.new("RemoteFunction")
remote.Name = "LeaderboardRequest"
remote.Parent = ReplicatedStorage

local lastRequestAt = {} -- [Player] = { [action] = os.clock() }
local cardCache = {} -- [저장 키] = { value, at }
local cardCacheCount = 0
local CARD_CACHE_LIMIT = 500

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
	local season = Leaderboard.currentSeason()
	return { id = season, lengthDays = LeaderboardConfig.seasonLengthDays, endsAt = LeaderboardRules.seasonEndsAt(season, LeaderboardConfig) }
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
	if action == "hall" then
		-- P3c E2: 지난 시즌 순위표(명예의 전당 - C7과 같은 데이터). 저장소 요청은 서버 캐시(hallCacheSeconds)에만 - 요청마다 읽지 않는다.
		local previous = Leaderboard.currentSeason() - 1
		local hall = Leaderboard.getHall(previous)
		local entries = hall and hall.boards and hall.boards[boardId] or {}
		return { ok = true, season = previous, entries = entries, names = hall and hall.names or {}, exists = hall ~= nil }
	end
	if action == "board" then
		local board = cache[boardId]
		local entries = board and board.entries or {}
		-- P3b A: 이름 표 + 캐시 안의 내 줄(있으면 - 저장소 요청 0). 캐시 밖이면 클라가 "me"를 따로 묻는다.
		return { ok = true, entries = entries, updatedAt = board and board.updatedAt or nil, season = seasonInfo(), names = namesFor(entries), mine = mineInCache(boardId, player.UserId) }
	elseif action == "me" then
		-- 캐시 안이면 그 순위, 밖이면 내 저장 값 하나만 읽는다(정렬 저장소에는 "몇 위인가" 조회가 없다 - 상위 topN 밖은 "topN위 밖"으로 보인다).
		if boardId == "party" then
			-- 파티 키는 멤버 구성이라 내 키가 하나가 아니다 - 캐시(상위 topN)에서 내가 든 가장 높은 기록만 찾는다(저장소 요청 0).
			local token = tostring(player.UserId)
			for _, entry in ipairs((cache.party or {}).entries or {}) do
				for id in entry.key:sub(2):gmatch("[^_]+") do
					if id == token then
						return { ok = true, rank = entry.rank, stage = entry.stage, seconds = entry.seconds, key = entry.key }
					end
				end
			end
			return { ok = true, rank = nil, outOfTop = true, topN = LeaderboardConfig.topN }
		end
		local rank, entry = Leaderboard.rankInCache(boardId, player.UserId)
		if rank then
			return { ok = true, rank = rank, stage = entry.stage, seconds = entry.seconds }
		end
		if Leaderboard.writeMode() == "off" then
			-- Studio 수동 Play는 저장소를 읽지 않는다(리뷰 10) - 가짜 순위(/gg lb fake)의 "캐시 밖" 값만 돌려준다.
			local fake = fakeMine and fakeMine[boardId]
			return fake and table.clone(fake) or { ok = true, rank = nil, outOfTop = false }
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
			if not key:match("^p%-?%d[%d_%-]*$") then
				return { ok = false, reason = "bad_request" }
			end
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
		cardCacheCount += 1
		if cardCacheCount > CARD_CACHE_LIMIT then -- 캐시 상한(리뷰 8) - 넘으면 통째로 비운다(다음 조회가 다시 읽는다)
			table.clear(cardCache)
			cardCacheCount = 1
		end
		cardCache[storeKey] = { value = value, at = os.clock() }
		return { ok = true, card = value }
	end
	return { ok = false, reason = "bad_request" }
end

-- 자동 검증 전용(검증 모드만): 정렬 저장소에 value를 쓰고 다시 읽는다 - 공식 문서에 값 범위가 없어(로그 인용) 최대 인코딩을 실측한다. 반환: (같은가, 읽은 값).
function Leaderboard.debugRoundTrip(value)
	if Leaderboard.writeMode() ~= "verify" then
		return false, nil
	end
	stats.orderedWrite += 1
	stats.orderedRead += 1
	local ok, back = pcall(function()
		local store = ordered("probe")
		store:SetAsync("roundtrip", value)
		return store:GetAsync("roundtrip")
	end)
	return ok and back == value, back
end

-- Studio 화면 확인 전용(P3b - /gg lb fake · 검증 (나)): 수동 Play(쓰기 off)에서만 캐시 · 이름 · 카드를 가짜로 채운다(저장소 요청 0).
-- 요청한 사람은 개인 37위 · 자기 직업 12위 · 파티 5위에 넣고, 다른 직업 순위표에는 넣지 않고 "100위 밖"(스테이지 40)을 준다.
-- 반환 = 채운 순위표 수(off가 아니면 0 - 검증 모드 · 라이브에서는 아무것도 안 한다).
local FAKE_NAMES = { "강철손", "불꽃망치", "새벽검", "달빛궁수", "은빛방패", "폭풍칼날", "바람걸음", "별똥별", "모루지기", "화염심장" }
function Leaderboard.debugFill(player)
	if Leaderboard.writeMode() ~= "off" then
		return 0
	end
	local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
	local gemOptions = { "attackPercent", "speedPercent", "crit", "maxHpPercent", "lifesteal" }
	local myClass = PlayerProfile.getClassId(player)
	local rng = Random.new(3)
	local fakeBase = 900000000
	local function fakeCard(id, classId)
		local gems = {}
		for slot = 1, 5 do
			gems[slot] = slot <= rng:NextInteger(1, 5) and {
				grade = ArmorData.gradeOrder[rng:NextInteger(3, 7)], itemLevel = rng:NextInteger(20, 120),
				option = { id = gemOptions[rng:NextInteger(1, #gemOptions)], roll = rng:NextNumber(0.875, 1.125), roll2 = rng:NextNumber(0.875, 1.125) },
			} or false
		end
		return {
			userId = id, name = "fake" .. id, displayName = nameById[id], classId = classId,
			level = rng:NextInteger(30, 99), rebirthCount = rng:NextInteger(0, 6),
			weapon = { gradeId = ArmorData.gradeOrder[rng:NextInteger(3, 7)], level = rng:NextInteger(8, 30), gems = gems }, at = os.time(),
		}
	end
	local function putCard(storeKey, card)
		cardCache[storeKey] = { value = card, at = math.huge } -- 만료 없음(Play가 끝나면 사라진다)
	end
	local filled = 0
	for _, boardId in ipairs(boardIds()) do
		local classId = boardId:match("^class:(.+)$")
		local entries = {}
		for rank = 1, LeaderboardConfig.topN do
			local stage = 5 * math.max(1, 60 - math.floor(rank / 2))
			local seconds = 40 + rank * 3.7
			local entry = { rank = rank, stage = stage, seconds = boardId ~= "personal" and seconds or nil }
			if boardId == "party" then
				local ids = {}
				for m = 1, 2 + rank % 3 do
					table.insert(ids, fakeBase + rank * 10 + m)
				end
				if rank == 5 then
					ids[1] = player.UserId
				end
				entry.members = ids
				entry.key = LeaderboardRules.partyKey(ids)
			else
				local id = (rank == 37 and boardId == "personal" or rank == 12 and classId == myClass) and player.UserId or (fakeBase + rank)
				entry.userId, entry.key = id, playerKey(id)
			end
			for i, id in ipairs(entry.members or { entry.userId }) do
				if id ~= player.UserId then
					nameById[id] = FAKE_NAMES[(id + i) % #FAKE_NAMES + 1] .. tostring(id % 1000)
					local cardClass = classId or ClassData.order[id % #ClassData.order + 1]
					local card = fakeCard(id, cardClass)
					putCard(playerKey(id), card)
					putCard(("%s_%s"):format(playerKey(id), cardClass), card)
				end
			end
			entries[rank] = entry
		end
		cache[boardId] = { entries = entries, updatedAt = os.time() }
		filled += 1
	end
	-- 내 카드 = 실제 프로필의 무기(카드 쓰기 경로와 같은 모양 - 방어구 없음).
	nameById[player.UserId] = player.DisplayName
	local profile = PlayerProfile.getProfile(player)
	if myClass and profile then
		local snapshot = PlayerInspect.buildSnapshot({ userId = player.UserId, name = player.Name, displayName = player.DisplayName, classId = myClass, classState = profile.classes[myClass] })
		local card = { userId = snapshot.userId, name = snapshot.name, displayName = snapshot.displayName, classId = myClass, level = snapshot.level, rebirthCount = snapshot.rebirthCount, weapon = snapshot.weapon, at = os.time() }
		putCard(playerKey(player.UserId), card)
		putCard(("%s_%s"):format(playerKey(player.UserId), myClass), card)
	end
	fakeMine = {}
	for _, classId in ipairs(ClassData.order) do
		if classId ~= myClass then
			fakeMine["class:" .. classId] = { ok = true, rank = nil, outOfTop = true, topN = LeaderboardConfig.topN, stage = 40, seconds = 612.3 }
		end
	end
	return filled
end

-- 자동 검증 전용: 검증이 주입한 시각으로 남긴 요청 간격 기록을 지운다(안 지우면 그 세션의 실제 요청이 간격에 막힌다).
function Leaderboard.debugResetRateLimit(player)
	lastRequestAt[player] = nil
end

remote.OnServerInvoke = function(player, action, boardId, key)
	return Leaderboard.handle(player, action, boardId, key)
end

Players.PlayerRemoving:Connect(function(player)
	lastRequestAt[player] = nil
end)

-- 주기 갱신: 서버에 사람이 있을 때만(빈 서버가 한도를 쓰지 않는다). 첫 갱신은 첫 접속 직후. Studio 수동 Play(쓰기 off)는 읽지도 않는다(리뷰 10 - 라이브 저장소 목록 요청 · 경고 폭주).
task.spawn(function()
	while true do
		if #Players:GetPlayers() > 0 and Leaderboard.writeMode() ~= "off" then
			Leaderboard.refreshAll()
			task.wait(LeaderboardConfig.refreshSeconds)
		else
			task.wait(5)
		end
	end
end)

return Leaderboard
