-- SEC-FIX-1 1 · 2 저장 · 수령 재현 하네스(실제 SaveSystem · SlotSave · SaveCoordinator · ImmediateSave · SlotSwitch + 가짜 DataStore · 가상 시계 - 스캐폴드 = slot_save_test 앞부분 그대로).
-- 실행: LUAU=<luau.exe> EXTRA_SERVER=SaveSystem,SlotSave,SaveCoordinator,ImmediateSave,SlotSwitch,SaveServer.server ECON_RES=res_secsave.txt python build_run.py sec_save_test.luau
-- 옛 코드 실패 확인 = ECON_SRC=<옛 src 스냅샷>으로 같은 명령(옛 = X가 나와야 재현).
-- 묶음: 1-a 칸 전환 중 자동저장 · 1-b 계정 키만 실패 · 1-c 새 캐릭터 첫 저장 순서 · 2 같은 서버 재접속(실제 SaveServer.server) - 끝 줄 "[SECSAVE] 끝 n/m".
local pass, total = 0, 0
local function check(tag, label, ok, detail)
	total += 1
	if ok then
		pass += 1
	end
	print(("[%s] %s %s %s"):format(tag, label, detail or "", ok and "O" or "X"))
end

-- ═══ 가상 시계 · 스케줄러(task.wait/spawn/delay가 실제로 양보한다 - 동시 저장 · 재시도 대기 · 마감을 초 단위로 잰다) ═══
local NOW = 0
local BASE_UNIX = 1790000000
local realos = os
os = setmetatable({
	clock = function() return NOW end,
	time = function(t) if t then return realos.time(t) end return BASE_UNIX + math.floor(NOW) end,
}, { __index = realos })
local sleepers = {}
HALT = false -- 2절: SaveServer 자동저장 루프(while true)를 끝에 멈춘다
task.wait = function(s)
	s = s or 0.03
	if HALT then
		coroutine.yield()
		return s
	end
	local co = coroutine.running()
	if not co or not coroutine.isyieldable() then
		NOW += s
		return s
	end
	table.insert(sleepers, { co = co, at = NOW + s })
	coroutine.yield()
	return s
end
local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		print("[SECSAVE] 스레드 에러 " .. tostring(err))
	end
end
task.spawn = function(f, ...)
	local co = type(f) == "thread" and f or coroutine.create(f)
	resume(co, ...)
	return co
end
task.delay = function(s, f, ...)
	local co = coroutine.create(f)
	table.insert(sleepers, { co = co, at = NOW + (s or 0), args = table.pack(...) })
	return co
end
task.defer = function(f, ...)
	return task.delay(0, f, ...)
end
task.cancel = function(co)
	for i = #sleepers, 1, -1 do
		if sleepers[i].co == co then
			table.remove(sleepers, i)
		end
	end
end
local function runUntilIdle(limit)
	while #sleepers > 0 do
		table.sort(sleepers, function(a, b) return a.at < b.at end)
		if limit and sleepers[1].at > limit then
			NOW = limit
			return
		end
		local s = table.remove(sleepers, 1)
		if s.at > NOW then
			NOW = s.at
		end
		if coroutine.status(s.co) == "suspended" then
			resume(s.co, table.unpack(s.args or { n = 0 }))
		end
	end
end

-- ═══ 가짜 DataStore(이름 + 키 → 값 · 호출 수 · 지연 · 실패 주입 · "써진 뒤 에러") ═══
local function deepCopy(v)
	if type(v) ~= "table" then
		return v
	end
	local c = {}
	for k, x in pairs(v) do
		c[k] = deepCopy(x)
	end
	return c
end
local DS = { data = {}, count = { Get = 0, Update = 0, Set = 0, Remove = 0 }, latency = 0.2, failKeys = {}, echoKeys = {}, sizeLimit = 4 * 1024 * 1024 }
local function jsonSize(v)
	local t = type(v)
	if t == "string" then
		return #v + 2
	elseif t == "number" then
		return #tostring(v)
	elseif t == "boolean" then
		return v and 4 or 5
	elseif t == "table" then
		local n = 2
		for k, x in pairs(v) do
			n += jsonSize(tostring(k)) + 1 + jsonSize(x) + 1
		end
		return n
	end
	return 4
end
local function maybeFail(full)
	local left = DS.failKeys[full]
	if left and left > 0 then
		DS.failKeys[full] = left - 1
		error("502: 가짜 DataStore 장애(" .. full .. ")")
	end
end
local function makeStore(name)
	local s = {}
	function s:GetAsync(key)
		local full = name .. "/" .. key
		DS.count.Get += 1
		task.wait(DS.latency)
		maybeFail(full)
		return deepCopy(DS.data[full])
	end
	function s:UpdateAsync(key, fn)
		local full = name .. "/" .. key
		DS.count.Update += 1
		task.wait(DS.latency)
		maybeFail(full)
		local v = fn(deepCopy(DS.data[full]))
		if v ~= nil then
			if jsonSize(v) > DS.sizeLimit then
				error("105: 값이 4MB를 넘음")
			end
			DS.data[full] = deepCopy(v)
		end
		if (DS.echoKeys[full] or 0) > 0 then
			DS.echoKeys[full] -= 1
			error("가짜 타임아웃(써진 뒤 에러)")
		end
		return v
	end
	function s:SetAsync(key, v)
		DS.count.Set += 1
		task.wait(DS.latency)
		DS.data[name .. "/" .. key] = deepCopy(v)
	end
	function s:RemoveAsync(key)
		DS.count.Remove += 1
		task.wait(DS.latency)
		DS.data[name .. "/" .. key] = nil
	end
	return s
end
local stores = {}
local guidN = 0
local baseGetService = game.GetService
game.GetService = function(self, svc)
	if svc == "DataStoreService" then
		return { GetDataStore = function(_, name)
			stores[name] = stores[name] or makeStore(name)
			return stores[name]
		end }
	end
	if svc == "HttpService" then
		return { GenerateGUID = function() guidN += 1 return "SERVER-" .. guidN end }
	end
	if svc == "RunService" then -- 라이브 경로(Studio 수동 · 검증 키 분리 없음 - 실제 키 1개 읽기 · 쓰기로 센다)
		return setmetatable({ IsStudio = function() return false end, IsServer = function() return true end }, { __index = function() return P end })
	end
	return baseGetService(self, svc)
end

-- PlayerProfile 대역(SaveCoordinator가 쓰는 것만): 플레이어 → 프로필
local PROFILES = {}
LOADERS["PlayerProfile"] = function()
	return {
		getProfile = function(p) return PROFILES[p] end,
		getWeapon = function() return nil end,
		clear = function(p) PROFILES[p] = nil end,
	}
end

-- ═══ SlotSwitch가 부르는 서버 모듈 대역(저장 경로 = 실제 SaveSystem · SaveCoordinator · ImmediateSave · SlotSwitch) ═══
LOADERS["BossEncounter"] = function() return { classChangeBlocked = function() return false end } end
LOADERS["MenuBlock"] = function() return { reason = function() return nil end } end
LOADERS["PartyState"] = function() return { leave = function() end } end
LOADERS["ProfileBoot"] = function() return { apply = function(p, profile) PROFILES[p] = profile end } end
LOADERS["CharacterRuntime"] = function() return { restore = function() end, capture = function() end } end
for _, n in ipairs({ "BuffState", "StuckArrowState", "SummonState", "SkillCooldowns" }) do
	LOADERS[n] = function() return { clearAll = function() end, clearForPlayer = function() end, clear = function() end } end
end

local function main()
	local SaveConfig = MODS.SaveConfig
	local SaveA = MODS.SaveSystem
	local Coord = MODS.SaveCoordinator
	local Switch = MODS.SlotSwitch
	local STORE = SaveConfig.dataStoreName
	local function raw(key)
		return DS.data[STORE .. "/" .. key]
	end
	local function mkPlayer(id)
		local p = { Name = "P" .. id, UserId = id, Parent = true, attrs = {} }
		function p:GetAttribute(k) return self.attrs[k] end
		function p:SetAttribute(k, v) self.attrs[k] = v end
		function p:LoadCharacter() self.Character = {} end
		return p
	end
	-- 옛 단일 프로필 표본(대검 = 지금 직업 · 활 = 진행 있음) → 첫 로드가 칸 2개로 이관
	local function seedLegacy(id)
		local legacy = SaveA.defaultProfile()
		legacy.version = SaveConfig.saveVersion
		legacy.savedAt = 1789000000
		legacy.classId = "greatsword"
		legacy.gold = 5000
		legacy.classes.greatsword.characterExp = 50000
		legacy.classes.greatsword.stageProgress.infinite, legacy.classes.greatsword.stageProgress.infiniteBest = 120, 130
		legacy.classes.bow.characterExp = 9000
		legacy.classes.bow.stageProgress.infinite, legacy.classes.bow.stageProgress.infiniteBest = 40, 45
		DS.data[STORE .. "/Player_" .. id] = deepCopy(legacy)
	end
	-- "받음" 표시(계정 키) + 보상(골드 = 캐릭터 키)을 같은 순간에 - 재접속 뒤 "보상은 있는데 표시가 없음" = 다시 받기(복제)
	local function claim(profile, key, gold)
		profile.codex.claimed[key] = true
		profile.gold += gold
	end
	local function reloadRaw(id, slotNo)
		local acct = raw("Acct_" .. id)
		local sl = acct and acct.slots[slotNo]
		local ch = sl and raw("Char_" .. id .. "_" .. sl.charId)
		return acct, ch
	end

	-- ═══ 1-a. 캐릭터 칸 전환 중 자동저장 끼어듦(SaveCoordinator 전환 잠금) ═══
	do
		DS.latency = 0.5 -- 저장 · 읽기 한 번 = 0.5초(전환 flush 0 ~ 1초 · 새 칸 읽기 1 ~ 2초 - 그 사이 1.1초에 자동저장)
		seedLegacy(701)
		local p = mkPlayer(701)
		local prof = SaveA.loadSlotProfile(p)
		PROFILES[p] = prof
		runUntilIdle()
		local t0 = NOW
		local okSw, whySw
		task.spawn(function()
			okSw, whySw = Switch.switch(p, 2)
		end)
		task.delay(1.1, function()
			Coord.saveForPlayer(p) -- 주기 자동저장(SaveServer 60초 틱)이 전환 도중에 걸림
		end)
		runUntilIdle()
		check("SECSAVE", "1-a 전환 성공 · 새 칸 = 활", okSw == true and PROFILES[p] and PROFILES[p].classId == "bow", tostring(whySw) .. " · " .. tostring(NOW - t0) .. "초")
		local bowProf = PROFILES[p]
		NOW += 2
		claim(bowProf, "box:sec1a", 1000)
		local okSave = Coord.saveForPlayer(p)
		check("SECSAVE", "1-a 전환 뒤 첫 저장 성공(옛 = 전환 중 자동저장이 계정 키 기준을 낡게 해 stale_session · 그 접속 저장 중단)", okSave == true and not Coord.isSuspended(p), "저장 " .. tostring(okSave) .. " · 중단 " .. tostring(Coord.isSuspended(p)))
		local acct, ch = reloadRaw(701, 2)
		local goldIn = ch and ch.data.gold == bowProf.gold
		local flagIn = acct and acct.shared.codex and acct.shared.codex.claimed["box:sec1a"] == true
		check("SECSAVE", "1-a 재접속 뒤 보상 ⇒ 받음 표시(다시 받기 0)", (not goldIn) or flagIn, ("저장된 골드 %s · 받음 %s"):format(tostring(ch and ch.data.gold), tostring(flagIn)))
		check("SECSAVE", "1-a 재접속 뒤 진행 보존(보상 · 표시 둘 다 저장)", goldIn and flagIn)
		DS.latency = 0.2
	end

	-- ═══ 1-b. 계정 키만 실패(DataStore 장애 4회 = 재시도 소진) - 보상만 써지고 표시가 빠지면 안 됨 ═══
	do
		seedLegacy(702)
		local p = mkPlayer(702)
		local prof = SaveA.loadSlotProfile(p, 1)
		PROFILES[p] = prof
		runUntilIdle()
		NOW += 5
		local goldBefore = reloadRaw(702, 1) and select(2, reloadRaw(702, 1)).data.gold
		claim(prof, "box:sec1b", 777)
		DS.failKeys[STORE .. "/Acct_702"] = SaveConfig.saveRetryCount + 1
		local okFail = Coord.saveForPlayer(p)
		local acct, ch = reloadRaw(702, 1)
		local flagIn = acct.shared.codex and acct.shared.codex.claimed["box:sec1b"] == true
		check("SECSAVE", "1-b 계정 키 실패 = 저장 실패 보고", okFail == false)
		check("SECSAVE", "1-b 계정 키 실패 때 캐릭터 키 보상도 안 써짐(옛 = 골드만 써져 재접속 후 다시 받기)", ch.data.gold == goldBefore and not flagIn, ("저장된 골드 %s(전 %s) · 받음 %s"):format(tostring(ch.data.gold), tostring(goldBefore), tostring(flagIn)))
		NOW += 5
		local okAgain = Coord.saveForPlayer(p)
		acct, ch = reloadRaw(702, 1)
		check("SECSAVE", "1-b 다음 저장 = 보상 · 표시 함께", okAgain == true and ch.data.gold == prof.gold and acct.shared.codex.claimed["box:sec1b"] == true)
	end

	-- ═══ 1-c. 새 캐릭터 첫 저장 = 캐릭터 키 먼저(계정 칸이 없는 키를 가리키지 않게) ═══
	do
		seedLegacy(703)
		local p = mkPlayer(703)
		SaveA.loadSlotProfile(p, 1)
		SaveA.forgetSlotSession(p)
		local pn = SaveA.loadSlotProfile(p, "new")
		pn.classId = "healer"
		DS.failKeys[STORE .. "/Char_703_3"] = SaveConfig.saveRetryCount + 1
		local okN = SaveA.saveProfile(p, pn)
		local acct = raw("Acct_703")
		check("SECSAVE", "1-c 새 캐릭터 키 실패 = 계정 칸 안 생김(다음 로드 missing_character 0)", okN == false and acct.slots[3] == false, tostring(acct.slots[3]))
		local okN2 = SaveA.saveProfile(p, pn)
		acct = raw("Acct_703")
		check("SECSAVE", "1-c 다시 저장 = 칸 + 캐릭터 키", okN2 == true and acct.slots[3] and raw("Char_703_" .. acct.slots[3].charId) ~= nil)
	end

	-- ═══ 2. 같은 서버 재접속(AUDIT1 #15) - 실제 SaveServer.server.lua(접속 로드 · 퇴장 저장 · 자동저장 배선)를 가짜 Players로 ═══
	do
		local added, removing, list = {}, {}, {}
		local FakePlayers = {
			PlayerAdded = { Connect = function(_, f) table.insert(added, f) end },
			PlayerRemoving = { Connect = function(_, f) table.insert(removing, f) end },
			GetPlayers = function() return table.clone(list) end,
		}
		local prevGS = game.GetService
		game.GetService = function(self, svc)
			if svc == "Players" then
				return FakePlayers
			end
			return prevGS(self, svc)
		end
		game.BindToClose = function() end
		local function stubStart() return { start = function() end, custom = function() end, onLeaving = function() end } end
		for _, n in ipairs({ "AcquisitionAudit", "QuestService", "PetService", "CommunityGoalService", "WeeklyChallengeService", "CodexService", "SocialRewardService", "SettingsService", "MonetizationService", "Telemetry" }) do
			LOADERS[n] = stubStart
		end
		local _ = MODS["SaveServer.server"] -- 스크립트 본문 실행(PlayerAdded · PlayerRemoving · 자동저장 루프 연결)
		local function join(p)
			table.insert(list, p)
			for _, f in ipairs(added) do
				task.spawn(f, p)
			end
		end
		local function leave(p)
			table.remove(list, table.find(list, p))
			p.Parent = nil
			for _, f in ipairs(removing) do
				task.spawn(f, p)
			end
		end
		seedLegacy(801)
		local p1 = mkPlayer(801)
		join(p1)
		runUntilIdle(NOW + 5)
		local prof1 = PROFILES[p1]
		check("SECSAVE", "2 첫 접속 로드", prof1 ~= nil and prof1.gold == 5000, tostring(prof1 and prof1.gold))
		NOW += 30
		prof1.gold = 12345 -- 이 접속의 진행
		DS.failKeys[STORE .. "/Acct_801"] = 1 -- 퇴장 저장 첫 시도 장애 → 1초 뒤 재시도(퇴장 저장이 길어짐)
		leave(p1)
		local p2 = mkPlayer(801) -- 같은 서버로 0.3초 뒤 다시 들어옴(새 Player 인스턴스 · 같은 UserId)
		task.delay(0.3, join, p2)
		runUntilIdle(NOW + 20)
		local prof2 = PROFILES[p2]
		check("SECSAVE", "2 재접속 로드 = 퇴장 저장 뒤 값(옛 = 퇴장 저장 전에 읽어 옛 골드)", prof2 ~= nil and prof2.gold == 12345, tostring(prof2 and prof2.gold))
		if prof2 then
			prof2.gold += 1
		end
		runUntilIdle(NOW + SaveConfig.autosaveIntervalSeconds + 5) -- 자동저장 한 주기
		local _, ch = reloadRaw(801, 1)
		check("SECSAVE", "2 재접속 뒤 자동저장 진행 저장(옛 = stale_session으로 그 접속 저장 중단)", not Coord.isSuspended(p2) and ch and prof2 and ch.data.gold == prof2.gold,
			("중단 %s · 저장된 골드 %s"):format(tostring(Coord.isSuspended(p2)), tostring(ch and ch.data.gold)))
		leave(p2)
		runUntilIdle(NOW + 30)
		local _, ch2 = reloadRaw(801, 1)
		check("SECSAVE", "2 다시 나감 = 마지막 진행 저장", ch2 and prof2 and ch2.data.gold == prof2.gold, tostring(ch2 and ch2.data.gold))
	end
	HALT = true -- 자동저장 루프 멈춤(가상 시계가 끝나게)
end

task.spawn(function()
	local okMain, errMain = pcall(main)
	if not okMain then
		print("[SECSAVE] 하네스 에러 " .. tostring(errMain))
	end
end)
runUntilIdle()
print(("[SECSAVE] 끝 %d/%d"):format(pass, total))
