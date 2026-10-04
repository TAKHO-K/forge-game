-- QUEUE-MENU2 B 캐릭터 칸 저장 하네스(실제 SaveSystem · SlotSave + 가짜 DataStore · 가상 시계 - 스캐폴드 = save_launch_test 앞부분 그대로).
-- 실행: LUAU=<luau.exe> EXTRA_SERVER=SaveSystem,SlotSave ECON_RES=res_slot.txt python build_run.py slot_save_test.luau
-- (옛 머리말) QUEUE-ALL4 C 출시 전 저장 · 예산 감사 하네스(실제 SaveSystem · SaveCoordinator · ImmediateSave + 가짜 DataStore · 가상 시계 스케줄러).
-- 실행: LUAU=<luau.exe> PRELUDE=server_prelude.luau EXTRA_SERVER=SaveSystem,SaveCoordinator,ImmediateSave ECON_RES=res_launch.txt python build_run.py save_launch_test.luau
-- 묶음: [MIG] 이관(v0 · v1 · v12 · v21 · v34 · v44 · v54 표본 → 현재 · 멱등 · 새 계정) · [BAD] 손상 복구 · [LOCK] 세션 잠금 · 두 서버 · 메아리
--       [FAIL] 실패 처리 · [CLOSE] 종료 저장(12명 · 동시 vs 옛 차례) · [BUDGET] 12인 호출 수(분당) - 끝 줄 "[LAUNCH] 끝 n/m".
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
task.wait = function(s)
	s = s or 0.03
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
		print("[SLOT] 스레드 에러 " .. tostring(err))
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

local function main()
	local SaveConfig = MODS.SaveConfig
	local SlotSaveData = MODS.SlotSaveData
	local SlotSave = MODS.SlotSave
	local SaveA = MODS.SaveSystem
	local STORE = SaveConfig.dataStoreName
	local function mkPlayer(id)
		return { Name = "P" .. id, UserId = id, Parent = true }
	end
	local function raw(key)
		return DS.data[STORE .. "/" .. key]
	end
	local function deepEqual(a, b)
		if type(a) ~= type(b) then
			return false
		end
		if type(a) ~= "table" then
			return a == b or (a ~= a and b ~= b)
		end
		for k, v in pairs(a) do
			if not deepEqual(v, b[k]) then
				return false
			end
		end
		for k in pairs(b) do
			if a[k] == nil then
				return false
			end
		end
		return true
	end
	local function item(n)
		return { grade = "rare", dropStage = 30, locked = false, itemLevel = 40 + n, part = "armor", option = nil }
	end

	-- 옛 단일 프로필(현재 버전) 표본: 대검(지금 직업 · 진행) · 활(진행) · 쌍검 · 치유사(진행 없음)
	local legacy = SaveA.defaultProfile()
	legacy.version = SaveConfig.saveVersion
	legacy.savedAt = 1789000000
	legacy.classId = "greatsword"
	legacy.gold = 5000
	legacy.gemDust = 77
	legacy.inventory = { item(1), item(2), item(3) }
	legacy.training.attack = 10
	local T1, T2 = nil, nil
	for id in pairs(MODS.TitleData.titles) do
		if not T1 then T1 = id elseif not T2 then T2 = id end
	end
	legacy.titles = { [T1] = true }
	legacy.purchases.receipts = { { id = "R1", at = 1 } }
	legacy.gamepasses = { bagExpand = true }
	local gs = legacy.classes.greatsword
	gs.characterExp = 50000
	gs.stageProgress.infinite, gs.stageProgress.infiniteBest = 120, 130
	gs.weapon.level = 12
	local bow = legacy.classes.bow
	bow.characterExp = 9000
	bow.stageProgress.infinite, bow.stageProgress.infiniteBest = 40, 45
	legacy.transcendGems = { list = { { id = "TG1", grade = "transcendent", socket = { classId = "bow", slot = 1 } }, { id = "TG2", grade = "transcendent" } }, seq = 2 }
	local p = mkPlayer(501)
	DS.data[STORE .. "/Player_501"] = deepCopy(legacy)
	local legacyBefore = deepCopy(raw("Player_501"))

	-- ═══ 1. 이관 ═══
	local prof, err, info = SaveA.loadSlotProfile(p)
	local acct = raw("Acct_501")
	check("SLOT", "이관: 로드 성공 · 지금 직업 = 대검", prof ~= nil and prof.classId == "greatsword", tostring(err))
	check("SLOT", "이관: 계정 키 + 캐릭터 2(진행 있는 직업만)", acct ~= nil and raw("Char_501_1") ~= nil and raw("Char_501_2") ~= nil and raw("Char_501_3") == nil, tostring(info and info.slotMigrated))
	check("SLOT", "이관: 옛 키 그대로(legacy 보존 · 읽기만)", deepEqual(raw("Player_501"), legacyBefore))
	check("SLOT", "이관: 칸 1 = 대검 · 칸 2 = 활 · 나머지 빈 칸", acct and acct.slots[1] and acct.slots[1].classId == "greatsword" and acct.slots[2] and acct.slots[2].classId == "bow" and acct.slots[3] == false and acct.slots[4] == false)
	check("SLOT", "이관: 대검 = 공유 재화 전부(골드 · 가방 · 가루)", prof.gold == 5000 and #prof.inventory == 3 and prof.gemDust == 77)
	check("SLOT", "이관: 수련 = 모든 캐릭터 복사", raw("Char_501_2").data.training.attack == 10 and prof.training.attack == 10)
	check("SLOT", "이관: 활 캐릭터 = 골드 0 · 가방 비어 있음(복제 0)", raw("Char_501_2").data.gold == 0 and #raw("Char_501_2").data.inventory == 0)
	local tg1, tg2 = raw("Char_501_1").data.transcendGems.list, raw("Char_501_2").data.transcendGems.list
	check("SLOT", "이관: 초월 보석 = 박힌 직업으로(활 1 · 안 박힌 것 대검 1)", #tg1 == 1 and tg1[1].id == "TG2" and #tg2 == 1 and tg2[1].id == "TG1")
	check("SLOT", "계정 키에 캐릭터 필드 없음(골드 · 가방 · 직업 칸)", acct.shared.gold == nil and acct.shared.inventory == nil and acct.shared.classes == nil and acct.shared.titles ~= nil)
	check("SLOT", "캐릭터 키 이름 ≤ 50자", #("Char_" .. tostring(9999999999) .. "_" .. tostring(99)) <= 50 and #("Acct_" .. tostring(9999999999)) <= 50)

	-- ═══ 2. 저장 · 분리 ═══
	prof.gold = 6000
	table.insert(prof.inventory, item(4))
	prof.titles[T2] = true
	local okS, whyS = SaveA.saveProfile(p, prof)
	check("SLOT", "저장(캐릭터 키 → 계정 키)", okS == true, tostring(whyS))
	check("SLOT", "저장: 골드 · 가방 = 캐릭터 키 · 칭호 = 계정 키", raw("Char_501_1").data.gold == 6000 and #raw("Char_501_1").data.inventory == 4 and raw("Acct_501").shared.titles[T2] == true and raw("Acct_501").shared.gold == nil)
	check("SLOT", "저장 중 옛 키 안 씀", deepEqual(raw("Player_501"), legacyBefore))
	SaveA.forgetSlotSession(p)
	local profBow = SaveA.loadSlotProfile(p, 2)
	check("SLOT", "활 캐릭터 로드: 대검 골드 · 가방 안 보임 · 칭호(공유) 보임", profBow and profBow.classId == "bow" and profBow.gold == 0 and #profBow.inventory == 0 and profBow.titles[T2] == true)
	check("SLOT", "활 캐릭터: 가방 확장 권리 · 영수증(계정) 보임", profBow.gamepasses.bagExpand == true and profBow.purchases.receipts[1].id == "R1")
	check("SLOT", "활 캐릭터: 대검 진도 안 보임(계정 최고 = 캐릭터 최고)", profBow.classes.greatsword.stageProgress.infiniteBest <= 1 and profBow.classes.bow.stageProgress.infiniteBest == 45)
	check("SLOT", "활 캐릭터: 메인 퀘스트 = 캐릭터별(처음부터)", profBow.quests == nil or profBow.quests.main == 1)

	-- ═══ 3. 새 캐릭터 · 같은 직업 중복 · 칸 상한 ═══
	SaveA.forgetSlotSession(p)
	local pNew = SaveA.loadSlotProfile(p, "new")
	check("SLOT", "새 캐릭터 로드: 직업 없음(직업 선택 = 새 캐릭터)", pNew and pNew.classId == nil and pNew.gold == 0 and pNew.titles[T2] == true)
	pNew.classId = "bow"
	local okN = SaveA.saveProfile(p, pNew)
	local a2 = raw("Acct_501")
	check("SLOT", "같은 직업 중복 생성(활 2)", okN == true and a2.slots[3] and a2.slots[3].classId == "bow" and raw("Char_501_3") ~= nil)
	check("SLOT", "같은 직업 번호(활 ① · 활 ②)", SlotSave.classNumber(a2, 2) == 1 and SlotSave.classNumber(a2, 3) == 2)
	SaveA.forgetSlotSession(p)
	local p4 = SaveA.loadSlotProfile(p, "new")
	p4.classId = "healer"
	SaveA.saveProfile(p, p4)
	SaveA.forgetSlotSession(p)
	local p5 = SaveA.loadSlotProfile(p, "new")
	p5.classId = "dualblade"
	local ok5, why5 = SaveA.saveProfile(p, p5)
	check("SLOT", "칸 상한(4) = 다섯째 거절", ok5 == false and why5 == "slots_full", tostring(why5))
	-- 보관 · 복구
	local acc = deepCopy(raw("Acct_501"))
	local okA1 = SlotSave.archiveSlot(acc, 3)
	check("SLOT", "보관: 칸에서 빠짐 · 보관함 1", okA1 == true and acc.slots[3] == false and #acc.archive == 1)
	local slotR = SlotSave.restoreArchived(acc, 1)
	check("SLOT", "복구: 빈 칸으로", slotR == 3 and acc.slots[3] and #acc.archive == 0)
	local accFull = deepCopy(acc)
	accFull.archive = {}
	for i = 1, SlotSaveData.maxArchive do
		accFull.archive[i] = { charId = 100 + i, classId = "bow" }
	end
	local okFull, whyFull = SlotSave.archiveSlot(accFull, 1)
	check("SLOT", "보관 최대 10", okFull == nil and whyFull == "archive_full")
	local accNoFree = deepCopy(acc)
	SlotSave.archiveSlot(accNoFree, 4)
	accNoFree.slots[4] = { charId = 99, classId = "bow" }
	check("SLOT", "복구에 빈 칸 필요", SlotSave.restoreArchived(accNoFree, 1) == nil)

	-- ═══ 4. 두 서버 · 빠른 재접속 ═══
	SaveA.forgetSlotSession(p)
	local pa = SaveA.loadSlotProfile(p, 1)
	SaveA.saveProfile(p, pa) -- A가 쥔다(sessionId = A)
	local SaveB = LOADERS["SaveSystem"]()
	local pb, _, infoB = SaveB.loadSlotProfile(p, 1)
	check("SLOT", "두 서버: B 로드가 잠금 대기", infoB and (infoB.lockWaitedSeconds or 0) > 0, tostring(infoB and infoB.lockWaitedSeconds))
	pb.gold = pb.gold + 1
	SaveB.saveProfile(p, pb)
	pa.gold = 999999
	local okA2, whyA2 = SaveA.saveProfile(p, pa)
	check("SLOT", "두 서버: 늦은 A 저장 = stale(복제 0)", okA2 == false and whyA2 == "stale_session" and raw("Char_501_1").data.gold == pb.gold, tostring(whyA2) .. " 골드 " .. tostring(raw("Char_501_1").data.gold))

	-- ═══ 5. 스위치 끔(손실 0) · 다시 켬 ═══
	SlotSaveData.enabled = false
	local SaveC = LOADERS["SaveSystem"]()
	local pc = SaveC.loadProfile(p)
	local sumGold = 0
	for i = 1, 4 do
		local c = raw("Char_501_" .. i)
		if c then
			sumGold += c.data.gold
		end
	end
	check("SLOT", "끔: 모든 캐릭터 합침(골드 합 · 활 진도 · 칭호)", pc and pc.gold == sumGold and pc.classes.bow.stageProgress.infiniteBest == 45 and pc.titles[T2] == true, ("골드 %s / 합 %d"):format(tostring(pc and pc.gold), sumGold))
	pc.gold += 5
	local okC = SaveC.saveProfile(p, pc)
	check("SLOT", "끔: 옛 키에 저장", okC == true and raw("Player_501").gold == sumGold + 5)
	SlotSaveData.enabled = true
	SlotSaveData.legacyRecheck = true -- 운영: 다시 켤 때 재확인
	local SaveD = LOADERS["SaveSystem"]()
	local pd, _, infoD = SaveD.loadSlotProfile(p)
	check("SLOT", "다시 켬: 옛 키가 더 새로움 → 다시 이관(끈 동안 진행 유지)", pd and infoD.slotRemigrated == true and pd.gold == sumGold + 5, tostring(pd and pd.gold))
	check("SLOT", "다시 켬: 새 캐릭터 번호 = 옛 번호 뒤(덮어쓰기 0)", raw("Acct_501").slots[1].charId > 4)
	SlotSaveData.legacyRecheck = false

	-- ═══ 예산: 평소 접속 읽기 = 계정 + 캐릭터(옛 키 안 읽음) · 저장 쓰기 = 2 ═══
	do
		SaveD.markReleasing(p, true) -- 앞 서버가 퇴장 저장으로 잠금을 놓은 뒤 접속(평소 경로)
		SaveD.saveProfile(p, pd)
		SaveD.markReleasing(p, false)
		local SaveE = LOADERS["SaveSystem"]()
		local before = { Get = DS.count.Get, Update = DS.count.Update }
		local pe = SaveE.loadSlotProfile(p)
		local reads = DS.count.Get - before.Get
		local b2 = DS.count.Update
		SaveE.saveProfile(p, pe)
		check("SLOT", "예산: 평소 접속 읽기 2(계정 + 캐릭터) · 저장 쓰기 2", reads == 2 and DS.count.Update - b2 == 2, ("읽기 %d · 쓰기 %d"):format(reads, DS.count.Update - b2))
	end

	-- ═══ 6. 크기(가방 80 · 최대 데이터) ═══
	local OPT = next(MODS.OptionData.options)
	local big = SaveA.defaultProfile()
	big.classId = "greatsword"
	for i = 1, 80 do
		big.inventory[i] = { grade = "transcendent", dropStage = 25300, locked = true, itemLevel = 25300, part = "armor", option = { id = OPT, roll = 0.987654321 }, source = { kind = "boss_first_clear", stage = 25300, at = 1789000000 }, setZone = "tier6", skillVariant = "v3", primordial = { world = 123456, at = 1789000000 } }
	end
	local chBig = { charId = 1, classId = "greatsword", data = SlotSave.extractCharacter(big, "greatsword") }
	local sizeChar = jsonSize({ charId = 1, classId = "greatsword", data = chBig.data })
	local accBig = SlotSave.newAccount(SlotSave.extractShared(big), 0)
	local sizeAcct = jsonSize(accBig)
	check("SLOT", "크기: 캐릭터 키(가방 80) ≤ 4MB × 25%", sizeChar <= DS.sizeLimit * 0.25, ("%d자(%.2f%%)"):format(sizeChar, sizeChar / DS.sizeLimit * 100))
	check("SLOT", "크기: 계정 키 ≤ 4MB × 25%", sizeAcct <= DS.sizeLimit * 0.25, ("%d자(%.2f%%)"):format(sizeAcct, sizeAcct / DS.sizeLimit * 100))

	-- ═══ 7. 새 계정 ═══
	local pn = mkPlayer(777)
	local fresh = SaveA.loadSlotProfile(pn)
	check("SLOT", "새 계정: 캐릭터 없음 · 계정 키 생김", fresh and fresh.classId == nil and raw("Acct_777") ~= nil and raw("Acct_777").slots[1] == false)
	fresh.classId = "healer"
	SaveA.saveProfile(pn, fresh)
	check("SLOT", "새 계정: 첫 직업 = 칸 1", raw("Acct_777").slots[1] and raw("Acct_777").slots[1].classId == "healer" and raw("Char_777_1") ~= nil)
	check("SLOT", "새 계정: 옛 키 안 만듦", raw("Player_777") == nil)
end

task.spawn(function()
	local okMain, errMain = pcall(main)
	if not okMain then
		print("[SLOT] 하네스 에러 " .. tostring(errMain))
	end
end)
runUntilIdle()
print(("[SLOT] 끝 %d/%d"):format(pass, total))
