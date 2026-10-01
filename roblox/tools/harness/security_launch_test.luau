Random = { new = function(seed) math.randomseed(seed or 1); return { NextInteger = function(_, a, b) return math.random(a, b) end, NextNumber = function(_, a, b) a = a or 0; b = b or 1; return a + math.random() * (b - a) end } end }
-- QUEUE-ALL4 B 출시 전 보안 하네스(security-audit-launch): 알파 감사 뒤 새로 생긴 클라 → 서버 입구에 잘못된 인자 · 연타 · 이중 요청을 넣는다.
--   대상 = RedeemCode · 초대 보상 · CodexRequest · CommunityGoalClaim · WeeklyChallengeStart/Top · TravelRequest(체크포인트 · 귀환 취소 · 견습 바로 가기) · SpectateRequest.
--   가짜 서비스(DataStore · OrderedDataStore · MemoryStore · Players · Workspace)는 이 파일이 game.GetService를 덮어 넣는다(save_lock_test와 같은 방식).
--   실행: LUAU=<luau.exe> PRELUDE=server_prelude.luau EXTRA_SERVER=$(python deps.py SocialRewardService,CodexService,CommunityGoalService,WeeklyChallengeService,SpectateService.server,RequestGate,QuestService,PlayerProfile,SaveSystem,Travel) ECON_RES=res_sec.txt python build_run.py security_launch_test.luau
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then pass += 1 end
	print(("[SEC] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end

-- TextData의 동적 require(script.Parent[name])를 MODS로 돌린다(build_run의 정적 치환이 못 바꾸는 꼴)
local function moduleMarker(name) -- script.Parent.Parent.CodexRules 같은 사슬도 마지막 이름으로
	return setmetatable({ __harnessModule = name }, { __index = function(_, k) return moduleMarker(k) end })
end
setmetatable(script.Parent, { __index = function(_, k) return moduleMarker(k) end })
local baseRequire = require
require = function(m)
	if type(m) == "table" and m.__harnessModule then
		return MODS[m.__harnessModule]
	end
	if m == nil then
		error("require(nil) " .. debug.traceback())
	end
	return baseRequire(m)
end

Vector3.xAxis, Vector3.yAxis, Vector3.zAxis = Vector3.new(1, 0, 0), Vector3.new(0, 1, 0), Vector3.new(0, 0, 1)
CFrame.fromMatrix = function() return {} end
CFrame.Angles = CFrame.Angles or function() return {} end
CFrame.lookAt = CFrame.lookAt or function() return {} end
-- 가짜 Instance 판정(합동 목표 note가 typeof == "Instance"를 본다)
typeof = function(v)
	if type(v) == "table" and rawget(v, "__inst") then
		return "Instance"
	end
	return type(v)
end

-- ── 가짜 서비스 ──
local STORES = {}
local function storeOf(key)
	STORES[key] = STORES[key] or { data = {}, updates = 0 }
	return STORES[key]
end
local sortedCalls, nameCalls = 0, 0
local function fakeStore(key)
	local s = storeOf(key)
	return {
		GetAsync = function(_, k) return s.data[k] end,
		SetAsync = function(_, k, v) s.data[k] = v end,
		RemoveAsync = function(_, k) s.data[k] = nil end,
		UpdateAsync = function(_, k, fn) s.updates += 1; local v = fn(s.data[k]); if v ~= nil then s.data[k] = v end; return v end,
		GetSortedAsync = function(_, asc, n)
			sortedCalls += 1
			local list = {}
			for k, v in pairs(s.data) do table.insert(list, { key = k, value = v }) end
			table.sort(list, function(a, b) if asc then return a.value < b.value end return a.value > b.value end)
			local page = {}
			for i = 1, math.min(n, #list) do page[i] = list[i] end
			return { GetCurrentPage = function() return page end }
		end,
	}
end
local MEM = { data = {}, fail = false }
local fakeHashMap = {
	UpdateAsync = function(_, k, fn)
		if MEM.fail then error("memorystore down") end
		local v = fn(MEM.data[k])
		if v ~= nil then MEM.data[k] = v end
		return v
	end,
}
local WS_ATTR = {}
local WS = setmetatable({
	GetAttribute = function(_, k) return WS_ATTR[k] end,
	SetAttribute = function(_, k, v) WS_ATTR[k] = v end,
	Raycast = function() return nil end,
	GetServerTimeNow = function() return os.clock() end,
}, { __index = function() return P end })
workspace = WS
local byId = {}
local PlayersFake = setmetatable({
	GetPlayerByUserId = function(_, id) return byId[id] end,
	GetNameFromUserIdAsync = function(_, id) nameCalls += 1; return "U" .. tostring(id) end,
	GetPlayers = function() local t = {} for _, p in pairs(byId) do table.insert(t, p) end return t end,
}, { __index = function() return P end })
local baseGetService = game.GetService
game.GetService = function(self, name)
	if name == "DataStoreService" then
		return { GetDataStore = function(_, n) return fakeStore(n) end, GetOrderedDataStore = function(_, n, scope) return fakeStore(n .. "/" .. tostring(scope)) end }
	end
	if name == "MemoryStoreService" then return { GetHashMap = function() return fakeHashMap end } end
	if name == "Workspace" then return WS end
	if name == "Players" then return PlayersFake end
	return baseGetService(self, name)
end

-- 서버 무거운 모듈은 입구 판정에 필요한 함수만 대역(이 파일 안에서만)
local encounterOf, weeklySpawns = {}, 0
LOADERS["BossEncounter"] = function()
	return {
		getEncounter = function(p) return encounterOf[p] end,
		getActive = function(p) return encounterOf[p] end,
		spawnWeeklyFor = function(p) weeklySpawns += 1; encounterOf[p] = { weekly = true }; return encounterOf[p] end,
		isEntryExcluded = function() return false end,
	}
end
LOADERS["BossGate"] = function() return { setupPrompts = function() end, setupRaidRemote = function() end } end
LOADERS["TutorialState"] = function() return { getActiveStep = function() return nil end } end
LOADERS["PlayerState"] = function() return { getHp = function() return 100 end } end
LOADERS["HeightGuard"] = function() return { reset = function() end } end
LOADERS["LaunchPermit"] = function() return { start = function() end, register = function() end } end
LOADERS["TeleportArrival"] = function() return { mark = function() end, preloadAsync = function() end } end
LOADERS["AirState"] = function() return { reset = function() end } end
LOADERS["GroundProbe"] = function() return { folder = function() return nil end } end
LOADERS["WorldMap"] = function() return { model = function() return nil end } end
local partyActivity = {} -- QUEUE-ALL5 A2: 실제 PartyState의 활동 기록(os.clock)과 같은 뜻
LOADERS["PartyState"] = function() return { notify = function() end, getParty = function() return nil end, getExpBonusForCount = function() return 0 end,
	noteActivity = function(p, at) partyActivity[p] = at or os.clock() end, clearActivity = function(p) partyActivity[p] = nil end, getLastActivity = function(p) return partyActivity[p] end } end

local function makePlayer(name, id, opts)
	opts = opts or {}
	local attrs = {}
	local pl = { __inst = true, Name = name, UserId = id, Parent = true, AccountAge = opts.age or 30, Character = opts.character }
	return setmetatable(pl, { __index = function(_, k)
		if k == "SetAttribute" then return function(_, n, v) attrs[n] = v end end
		if k == "GetAttribute" then return function(_, n) return attrs[n] end end
		if k == "IsA" then return function(_, c) return c == "Player" end end
		if k == "GetJoinData" then return function() return opts.join or {} end end
		if k == "FindFirstChild" or k == "WaitForChild" or k == "FindFirstChildOfClass" then return function() return nil end end
		if k == "GetAttributeChangedSignal" then return function() return { Connect = function() end } end end
		if k == "RequestStreamAroundAsync" then return function() end end
		return nil
	end })
end

local function busyWait(seconds)
	local t0 = os.clock()
	while os.clock() - t0 < seconds do end
end

local ok, err = pcall(function()
	local SaveSystem, PlayerProfile = MODS.SaveSystem, MODS.PlayerProfile
	local Gate = MODS.RequestGate
	local function newPlayer(name, id, opts, saved)
		local pl = makePlayer(name, id, opts)
		local data = SaveSystem.migrate({})
		if saved then data.savedAt = os.time() end
		PlayerProfile.init(pl, data)
		local p = PlayerProfile.getProfile(pl)
		p.tutorial = p.tutorial or {}
		p.tutorial.completed = true
		byId[id] = pl
		return pl
	end
	local function shards(pl)
		local q = PlayerProfile.getQuestState(pl)
		return q and q.currencies.sparkleShard or 0
	end
	local function invoke(name, pl, ...)
		local rec = REMOTES[name]
		assert(rec and rec.onInvoke, "no RF " .. name)
		local okCall, res = pcall(rec.onInvoke, pl, ...)
		return okCall and res or ("에러: " .. tostring(res))
	end
	local function fire(name, pl, ...)
		local rec = REMOTES[name]
		assert(rec and rec.onEvent, "no RE " .. name)
		local okCall, e = pcall(rec.onEvent, pl, ...)
		return okCall and "ok" or ("에러: " .. tostring(e))
	end

	-- ═══ 1. 코드(RedeemCode) ═══
	local Social = MODS.SocialRewardService
	local bad = 0
	for _, v in ipairs({ 123, {}, "", "ab", string.rep("A", 25), "FORGE 2026", "FORGE-2026", "포지2026", string.rep("x", 100000) }) do
		if Social.normalize(v) ~= nil then bad += 1 end
	end
	check("코드 정리: 숫자 · 표 · 빈 문자 · 짧음 · 25자 · 가운데 공백 · 기호 · 한글 · 100KB = 전부 거절", bad == 0 and Social.normalize(nil) == nil, ("통과 %d"):format(bad))
	local c1 = newPlayer("Code1", 1001)
	local s0 = shards(c1)
	local r1 = invoke("RedeemCode", c1, "  forge2026 ")
	check("소문자 · 앞뒤 공백 코드 = 지급(대소문자 무시)", type(r1) == "table" and r1.ok == true and shards(c1) > s0, type(r1) == "table" and tostring(r1.message) or tostring(r1))
	local s1 = shards(c1)
	local slow = 0
	for _ = 1, 5 do
		local r = invoke("RedeemCode", c1, "FORGE2026")
		if type(r) == "table" and r.ok == false then slow += 1 end
	end
	check("연타 5번(쿨 안) = 전부 거절 · 추가 지급 0", slow == 5 and shards(c1) == s1)
	busyWait(3.05)
	local r2 = invoke("RedeemCode", c1, "FORGE2026")
	check("쿨 뒤 같은 코드 다시 = 이미 받음(계정당 1회)", type(r2) == "table" and r2.ok == false and shards(c1) == s1, type(r2) == "table" and tostring(r2.message) or "")
	local _, before = Social.find("RIFTOPEN", os.time({ year = 2026, month = 11, day = 30, hour = 23, min = 59, sec = 0 }))
	local _, after = Social.find("RIFTOPEN", os.time({ year = 2026, month = 12, day = 1, hour = 0, min = 0, sec = 1 }))
	local none = Social.find("NOPE123")
	check("만료: 마지막 날 23:59 = 유효 · 다음 날 = 만료 · 없는 코드 = nil", before == true and after == false and none == nil)
	local rBad = invoke("RedeemCode", newPlayer("Code2", 1002), { "FORGE2026" })
	check("코드 자리에 표 = 거절(에러 없음)", type(rBad) == "table" and rBad.ok == false)

	-- ═══ 2. 초대 보상 ═══
	local inviter = newPlayer("Inviter", 2000, nil, true)
	local inviteStore = storeOf("SocialInvite_v1_studio")
	local function invitee(id, refId, age, saved)
		local pl = newPlayer("Inv" .. id, id, { join = { ReferredByPlayerId = refId }, age = age }, saved)
		Social.onLoaded(pl)
		return pl
	end
	local u0 = inviteStore.updates
	local selfInv = invitee(2101, 2101)
	check("자기 초대 = 보상 0 · 저장소 쓰기 0", shards(selfInv) == 0 and inviteStore.updates == u0)
	local i0 = shards(inviter)
	local good = invitee(2102, 2000, 30)
	check("정상 초대(첫 접속 · 30일) = 양쪽 보상", shards(good) > 0 and shards(inviter) > i0, ("받은 %d · 초대자 +%d"):format(shards(good), shards(inviter) - i0))
	local i1 = shards(inviter)
	local again = invitee(2102, 2000, 30)
	check("같은 쌍 다시(새 프로필로 재접속) = 보상 0", shards(again) == 0 and shards(inviter) == i1)
	local young = invitee(2103, 2000, 3)
	check("계정 나이 3일 = 초대받은 쪽만 · 초대자 0", shards(young) > 0 and shards(inviter) == i1)
	local oldAcc = invitee(2104, 2000, 30, true)
	check("저장 있는 계정(첫 접속 아님) = 보상 0", shards(oldAcc) == 0)
	local counted = 0
	for id = 2110, 2116 do
		local before2 = shards(inviter)
		invitee(id, 2000, 30)
		if shards(inviter) > before2 then counted += 1 end
	end
	local Data = MODS.SocialRewardData
	check(("초대자 하루 상한(%d) - 7명 더 와도 상한까지만(앞 1명 포함)"):format(Data.invite.inviterDailyCap), counted == Data.invite.inviterDailyCap - 1, ("이번에 받은 %d"):format(counted))

	-- ═══ 3. 도감(CodexRequest) ═══
	local Codex = MODS.CodexService
	local cx = newPlayer("Codex", 3001)
	Codex.onLoaded(cx)
	local rec = PlayerProfile.getCodex(cx)
	local gold0 = PlayerProfile.getGold(cx)
	local errs = 0
	for _, args in ipairs({ { nil }, { {} }, { 5 }, { "claim", 1 }, { "claim", {} }, { "claim", "board:xyz" }, { "claim", "nope" }, { "claim", "all" }, { "title", 9 }, { "title", "nope" } }) do
		busyWait(0.21)
		if fire("CodexRequest", cx, table.unpack(args)) ~= "ok" then errs += 1 end
	end
	check("도감 잘못된 인자 10종 = 에러 0 · 골드 변화 0", errs == 0 and PlayerProfile.getGold(cx) == gold0, ("에러 %d"):format(errs))
	local cells = Codex.built.cells
	local cellA, cellB = cells[1].id, cells[2].id
	rec.done[cellA], rec.done[cellB] = 50, 50
	busyWait(0.21)
	fire("CodexRequest", cx, "claim", cellA)
	local gold1 = PlayerProfile.getGold(cx)
	fire("CodexRequest", cx, "claim", cellB) -- 0.2초 안 = 버림
	check("도감 연타(0.2초 안 두 번째) = 버림", rec.claimed[cellB] ~= true and PlayerProfile.getGold(cx) == gold1)
	busyWait(0.21)
	fire("CodexRequest", cx, "claim", cellA)
	busyWait(0.21)
	fire("CodexRequest", cx, "claim", "all")
	busyWait(0.21)
	fire("CodexRequest", cx, "claim", "all")
	check("같은 칸 다시 · 모두 받기 두 번 = 칸마다 1회(A는 이미 · B만 1회)", rec.claimed[cellA] == true and rec.claimed[cellB] == true and PlayerProfile.getGold(cx) - gold1 <= (PlayerProfile.getGold(cx) - gold0), ("골드 %d → %d → %d"):format(gold0, gold1, PlayerProfile.getGold(cx)))
	local goldAll = PlayerProfile.getGold(cx)
	busyWait(0.21)
	fire("CodexRequest", cx, "claim", "all")
	check("다 받은 뒤 모두 받기 = 골드 변화 0", PlayerProfile.getGold(cx) == goldAll)
	busyWait(0.21)
	fire("CodexRequest", cx, "title", "communityHero")
	check("가지지 않은 칭호 선택 = 거절", rec.title == nil and cx:GetAttribute("SelectedTitle") ~= "communityHero")

	-- ═══ 4. 합동 목표(CommunityGoalClaim · 1인 하루 상한) ═══
	local CG = MODS.CommunityGoalService
	local CGD = MODS.CommunityGoalData
	local cgClaim = CG.claim or function(pl, v) return REMOTES.CommunityGoalClaim.onInvoke(pl, v) end -- 수정 전 코드(대조 실행)에는 CG.claim이 없다
	local g = newPlayer("Goal", 4001)
	local rejected = 0
	for _, v in ipairs({ "1", 1.5, 0 / 0, -1, 0, 99, true }) do
		local r = cgClaim(g, v)
		if type(r) == "table" and r.ok == false then rejected += 1 end
	end
	local rNil = cgClaim(g, nil)
	check("잘못된 칸 번호 8종(문자 · 소수 · NaN · 음수 · 0 · 범위 밖 · bool · nil) = 거절", rejected == 7 and type(rNil) == "table" and rNil.ok == false, ("거절 %d"):format(rejected))
	WS_ATTR.CommunityGoalTotal, WS_ATTR.CommunityGoalTarget = 1000, 1000
	local rNo = cgClaim(g, 1)
	check("기여 0 = 받을 수 없음", type(rNo) == "table" and rNo.ok == false and rNo.message == CGD.text.needContribute)
	for _ = 1, CGD.dailyCapPerPlayer + 10 do CG.note(g, "bossKill") end
	local cgRec = PlayerProfile.getCommunityGoal(g)
	check(("1인 하루 상한(MemoryStore) = 처치 %d번 중 %d만"):format(CGD.dailyCapPerPlayer + 10, CGD.dailyCapPerPlayer), cgRec.contributed == CGD.dailyCapPerPlayer, ("기여 %d"):format(cgRec.contributed))
	MEM.fail = true
	local g2 = newPlayer("Goal2", 4002)
	for _ = 1, CGD.dailyCapPerPlayer + 10 do CG.note(g2, "bossKill") end
	MEM.fail = false
	check("MemoryStore 실패 = 이 서버 세션 상한으로 같은 값", PlayerProfile.getCommunityGoal(g2).contributed == CGD.dailyCapPerPlayer, ("기여 %d"):format(PlayerProfile.getCommunityGoal(g2).contributed))
	local st0 = PlayerProfile.getMaterial and PlayerProfile.getMaterial(g, "enhanceStone") or 0
	local a1 = cgClaim(g, 1)
	local a2 = cgClaim(g, 1)
	local st1 = PlayerProfile.getMaterial and PlayerProfile.getMaterial(g, "enhanceStone") or 0
	check("칸 1 받기 = 1회 · 두 번째 = 받음", type(a1) == "table" and a1.ok == true and type(a2) == "table" and a2.ok == false and (st1 - st0) == (CGD.tiers[1].reward.enhanceStone or 0), ("강화석 +%d"):format(st1 - st0))
	local eggs = PlayerProfile.getProfile(g).eggs -- getEggs는 사본
	local NestData = MODS.NestData
	while #eggs < NestData.eggCap do table.insert(eggs, { zone = "tier1", grade = "normal", species = { "a", "b" }, nest = "h", at = 0 }) end
	local e1 = cgClaim(g, 2)
	check("알 칸 + 알 가방 가득 = 거절 · 받음 표시 안 함(다시 받을 수 있게)", type(e1) == "table" and e1.ok == false and cgRec.claimed["2"] == nil, type(e1) == "table" and tostring(e1.message) or "")
	local computed = 0
	for _ = 1, 30 do
		local r = invoke("CommunityGoalClaim", g, 3)
		if type(r) == "table" then computed += 1 end
	end
	check("RF 연타 30 = 공통 요청 제한(버림 기록)", (Gate.dropped.CommunityGoalClaim or 0) >= 10, ("버림 %d"):format(Gate.dropped.CommunityGoalClaim or 0))

	-- ═══ 5. 주간 도전 ═══
	local WC = MODS.WeeklyChallengeService
	local w = newPlayer("Weekly", 5001)
	for _ = 1, 10 do
		encounterOf[w] = nil -- 매번 보스전 밖(최악 = 스폰 실패가 반복돼도)
		fire("WeeklyChallengeStart", w)
	end
	local lim = MODS.RequestLimitConfig.remotes.WeeklyChallengeStart or { burst = 2 } -- 대조 실행(수정 전)에는 항목이 없다
	check(("입장 연타 10 = 스폰 %d번 이하(통)"):format(lim.burst), weeklySpawns <= lim.burst and weeklySpawns >= 1, ("스폰 %d"):format(weeklySpawns))
	local spawnsBefore = weeklySpawns
	encounterOf[w] = { weekly = true }
	busyWait(2.1)
	fire("WeeklyChallengeStart", w)
	check("보스전 중 입장 = 거절", weeklySpawns == spawnsBefore)
	-- QUEUE-ALL5 A2(D2): 입장 조건 = 체크포인트 순간이동과 같은 규칙(Travel.busyReason) + 견습
	do
		local TravelM = MODS.Travel
		local st = TravelM.stateOf(w)
		encounterOf[w] = { weekly = true }
		local inBoss = WC.entryBlocked(w)
		encounterOf[w] = nil
		st.hurtAt = os.clock()
		local hurt = WC.entryBlocked(w)
		local hurtLater = WC.entryBlocked(w, os.clock() + MODS.WorldMapData.travel.combatLockSeconds + 0.5)
		busyWait(2.1)
		local sp0 = weeklySpawns
		fire("WeeklyChallengeStart", w)
		local hurtSpawn = weeklySpawns - sp0
		st.hurtAt = -math.huge
		MODS.PartyState.noteActivity(w)
		local hit = WC.entryBlocked(w)
		MODS.PartyState.clearActivity(w)
		st.recall = { startAt = os.clock() }
		local casting = WC.entryBlocked(w)
		st.recall = nil
		w:SetAttribute("TutorialActive", true)
		local tut = WC.entryBlocked(w)
		w:SetAttribute("TutorialActive", nil)
		local free = WC.entryBlocked(w)
		busyWait(2.1)
		local sp1 = weeklySpawns
		fire("WeeklyChallengeStart", w)
		local okSpawn = weeklySpawns - sp1
		encounterOf[w] = nil
		check("주간 입장: 아레나 = in_boss · 방금 피격 = combat(스폰 0) · 8초 뒤 = 가능 · 방금 명중 = combat · 집중 중 = casting_already · 견습 = tutorial · 평소 = 스폰 1",
			inBoss == "in_boss" and hurt == "combat" and hurtLater == nil and hurtSpawn == 0 and hit == "combat" and casting == "casting_already" and tut == "tutorial" and free == nil and okSpawn == 1,
			("%s · %s · %s · 스폰 %d · %s · %s · %s · %s · 스폰 %d"):format(tostring(inBoss), tostring(hurt), tostring(hurtLater), hurtSpawn, tostring(hit), tostring(casting), tostring(tut), tostring(free), okSpawn))
		local keys = MODS.TextData_server
		local allKeys = true
		for _, why in ipairs({ "in_boss", "combat", "casting_already", "tutorial", "failed" }) do
			local k = "srv.weekly.blocked." .. why
			allKeys = allKeys and type(keys.ko[k]) == "string" and type(keys.en[k]) == "string" and #keys.en[k] <= 40
		end
		check("주간 입장 거절 문구 ko/en 5종 · en 40자 이하", allKeys)
	end
	local ws0 = shards(w)
	for _, v in ipairs({ 0 / 0, -1, 0, math.huge, "5", nil }) do WC.onCleared(w, v) end
	check("처치 시간 NaN · 음수 · 0 · inf · 문자 · nil = 기록 · 보상 0", shards(w) == ws0 and PlayerProfile.getWeeklyChallenge(w).best == nil)
	WC.onCleared(w, 90)
	WC.onCleared(w, 70)
	WC.onCleared(w, 120)
	local wr = PlayerProfile.getWeeklyChallenge(w)
	check("처치 3번 = 참여 보상 1번 · 최고 기록 = 가장 빠른 것", shards(w) - ws0 == MODS.WeeklyChallengeData.participation.sparkleShard and wr.best == 70, ("+%d · 최고 %s"):format(shards(w) - ws0, tostring(wr.best)))
	sortedCalls, nameCalls = 0, 0
	local others = { newPlayer("W2", 5002), newPlayer("W3", 5003), newPlayer("W4", 5004) }
	local rows = 0
	for _, pl in ipairs(others) do
		for _ = 1, 4 do
			local r = invoke("WeeklyChallengeTop", pl)
			if type(r) == "table" and r.rows then rows += 1 end
		end
	end
	check("순위 창 3명 × 4번 = 순위 읽기 1번(서버 캐시) · 이름 조회 ≤ topShown", sortedCalls == 1 and nameCalls <= MODS.WeeklyChallengeData.topShown and rows >= 9, ("읽기 %d · 이름 %d · 응답 %d"):format(sortedCalls, nameCalls, rows))

	-- ═══ 6. 체크포인트 · 귀환 취소 · 견습 바로 가기(TravelRequest) ═══
	local Travel = MODS.Travel
	local root = { Position = Vector3.new(0, 10, 0), CFrame = {}, AssemblyLinearVelocity = Vector3.zero, Parent = true }
	local character = { FindFirstChild = function(_, n) if n == "HumanoidRootPart" then return root end return nil end, FindFirstChildOfClass = function() return nil end }
	local t = newPlayer("Travel", 6001, { character = character })
	WS_ATTR[MODS.WorldMapData.checkpoints.attribute] = true
	local cpRec = PlayerProfile.getCheckpoints(t)
	local function cp(id) return select(2, Travel.requestCheckpoint(t, id, os.clock())) end
	local unknown = { cp(nil), cp(5), cp({}), cp("tier9"), cp("tier2") }
	local allUnknown = true
	for _, why in ipairs(unknown) do allUnknown = allUnknown and why == "cp_unknown" end
	check("체크포인트 nil · 숫자 · 표 · 없는 id · 안 찾은 곳 = cp_unknown(발견 = 서버 기록)", allUnknown, table.concat(unknown, ","))
	table.insert(cpRec.found, "tier6")
	check("찾았지만 잠긴 구역(tier6 · 보스 0) = cp_locked", cp("tier6") == "cp_locked")
	encounterOf[t] = {}
	table.insert(cpRec.found, "tier1")
	check("보스전 중 = in_boss", cp("tier1") == "in_boss")
	encounterOf[t] = nil
	Travel.stateOf(t).hurtAt = os.clock()
	check("전투 중(방금 피해) = combat", cp("tier1") == "combat")
	Travel.stateOf(t).hurtAt = -math.huge
	MODS.PartyState.noteActivity(t)
	check("전투 중(방금 적에게 명중) = combat(QUEUE-ALL5 A2 - 주간 도전과 같은 규칙)", cp("tier1") == "combat")
	MODS.PartyState.clearActivity(t)
	local w1 = cp("tier1")
	local w2 = cp("tier1")
	check("정상 = 시전 시작 · 바로 또 = casting_already", w1 == "casting" and w2 == "casting_already", w1 .. "," .. w2)
	Travel.cancelRecall(t, "key")
	Travel.stateOf(t).checkpointTeleportAt = os.clock()
	check("도착 직후(쿨) = cooldown", cp("tier1") == "cooldown")
	Travel.stateOf(t).checkpointTeleportAt = nil
	check("귀환 취소: 시전 없음 = not_casting · 이상한 이유 문자열은 key로", select(2, Travel.cancelRecall(t, { 1 })) == "not_casting")

	local okStart, eStart = pcall(Travel.start, {})
	if okStart then
		local tz = 0
		Travel.requestTutorialZone = function() tz += 1; return true, "ok" end
		local t2 = newPlayer("Travel2", 6002, { character = character })
		for _ = 1, 10 do fire("TravelRequest", t2, "tutorialZone") end
		local tzLim = MODS.RequestLimitConfig.remotes.TravelTutorialZone or { burst = 2 }
		check(("견습 바로 가기 연타 10 = 순간이동 %d번"):format(tzLim.burst), tz == tzLim.burst, ("이동 %d"):format(tz))
		local d0 = Gate.dropped.TravelRequest or 0
		local t3 = newPlayer("Travel3", 6003, { character = character })
		for _ = 1, 30 do fire("TravelRequest", t3, "cancelRecall", "move") end
		check("TravelRequest 연타 30 = 기본 통만 통과", (Gate.dropped.TravelRequest or 0) - d0 == 30 - MODS.RequestLimitConfig.default.burst, ("버림 %d"):format((Gate.dropped.TravelRequest or 0) - d0))
		local errT = 0
		for _, args in ipairs({ {}, { 5 }, { {} }, { "checkpoint", 1e308 }, { "party", 0 / 0 }, { "zzz" } }) do
			busyWait(0.11)
			if fire("TravelRequest", newPlayer("Travel4", 6100 + errT, { character = character }), table.unpack(args)) ~= "ok" then errT += 1 end
		end
		check("TravelRequest 잘못된 인자 6종 = 에러 0", errT == 0, ("에러 %d"):format(errT))
	else
		check("Travel.start(입구 연결) 대역 실행", false, tostring(eStart))
	end

	-- ═══ 7. 구경 가기(SpectateRequest) ═══
	local _ = MODS["SpectateService.server"]
	local sp = newPlayer("Spec", 7001)
	local errS = 0
	for _, v in ipairs({ nil, 5, "short", string.rep("j", 65), {} }) do
		if fire("SpectateRequest", sp, v) ~= "ok" then errS += 1 end
	end
	local dBefore = Gate.dropped.SpectateRequest or 0
	check("잘못된 jobId 5종 = 에러 0 · 제한 통을 쓰지도 않음", errS == 0 and dBefore == 0)
	fire("SpectateRequest", sp, "aaaaaaaa-bbbb-cccc")
	fire("SpectateRequest", sp, "aaaaaaaa-bbbb-cccc")
	fire("SpectateRequest", sp, "aaaaaaaa-bbbb-dddd")
	check("구경 가기 연타 3 = 1번만(20초 통)", (Gate.dropped.SpectateRequest or 0) == 2, ("버림 %d"):format(Gate.dropped.SpectateRequest or 0))
end)
if not ok then print("[SEC] 하네스 에러 " .. tostring(err)) end
print(("[SEC] 끝 %d/%d"):format(pass, total))
