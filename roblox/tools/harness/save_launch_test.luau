-- QUEUE-ALL4 C 출시 전 저장 · 예산 감사 하네스(실제 SaveSystem · SaveCoordinator · ImmediateSave + 가짜 DataStore · 가상 시계 스케줄러).
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
		print("[LAUNCH] 스레드 에러 " .. tostring(err))
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
	local SaveA = MODS.SaveSystem -- 서버 A(SaveCoordinator가 쓰는 사본)
	local Coord = MODS.SaveCoordinator
	local Immediate = MODS.ImmediateSave
	local STORE = SaveConfig.dataStoreName
	local V = SaveConfig.saveVersion
	local function keyOf(userId)
		return STORE .. "/Player_" .. userId
	end
	local function mkPlayer(id)
		return { Name = "P" .. id, UserId = id, Parent = true }
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
	local function count(t)
		local n = 0
		for _ in pairs(t or {}) do
			n += 1
		end
		return n
	end
	local BossData = MODS.BossData
	local gateBoss
	for id, b in pairs(BossData.bosses) do
		if b.gate and b.gate.zone then
			gateBoss = id
			break
		end
	end

	-- ═══ 1. 이관 ═══
	-- v0(버전 필드 없음 · 골드만) · v1(ca11a29 defaultProfile 그대로)
	do
		local m0 = SaveA.migrate({ gold = 777 })
		check("MIG", "v0(버전 없음) → 현재", m0.version == V and m0.gold == 777 and SaveA.isValidProfile(m0), ("v%s 골드 %s"):format(tostring(m0.version), tostring(m0.gold)))
		local v1 = { version = 1, savedAt = 1700000000, gold = 4200, equipment = { weapon = nil, armor = nil, gloves = nil, boots = nil }, stageProgress = { normal = 1, infinite = 0 }, inventorySlots = 20, gamepasses = {} }
		local m1 = SaveA.migrate(v1)
		local gs = m1.classes and m1.classes.greatsword
		check("MIG", "v1(ca11a29 모양) → 현재 · 골드 · 시작 무기 · 진도 1", m1.version == V and m1.gold == 4200 and SaveA.isValidProfile(m1) and gs and gs.weapon.level == 0 and gs.stageProgress.infinite == 1 and m1.savedAt == 1700000000,
			("v%d · 진도 %s · savedAt 보존 %s"):format(m1.version, tostring(gs and gs.stageProgress.infinite), tostring(m1.savedAt == 1700000000)))
		check("MIG", "v1: 옛 계정 = 이정표 · 출석 없음(새 계정 전용)", m1.quests and m1.quests.guide == nil and m1.quests.attendance == nil)
	end
	-- v12(5000a91 모양 - 직업 분리 전 · 장비 tierIndex)
	local m12
	do
		local item = { grade = "rare", dropStage = 30, locked = true, itemLevel = 55, part = "gloves", tierIndex = 2 }
		local v12 = { version = 12, savedAt = 1710000000, gold = 98765, characterExp = 5000, classId = "greatsword",
			equipment = { weapon = { id = MODS.WeaponData.starterId, level = 7 }, armor = { grade = "normal", dropStage = 20, locked = false, itemLevel = 22, part = "armor", tierIndex = 1 } },
			stageProgress = { normal = 1, infinite = 18, infiniteBest = 21, bestBossCleared = 20 }, inventorySlots = 24, inventory = { item, deepCopy(item) }, gamepasses = {} }
		m12 = SaveA.migrate(v12)
		local gs = m12.classes.greatsword
		check("MIG", "v12 → 현재 · 강화 7 · 최고 21 · 장비 · 가방 2", SaveA.isValidProfile(m12) and gs.weapon.level == 7 and gs.stageProgress.infiniteBest == 21 and gs.equipment.armor ~= nil and #m12.inventory == 2 and m12.gold == 98765 and m12.inventorySlots == 24,
			("레벨 경험치 %s · 장비 itemLevel %s"):format(tostring(math.floor(gs.characterExp)), tostring(m12.inventory[1].itemLevel)))
		check("MIG", "v12: 보스 깬 계정 = 견습 완료 · 리더보드 제외 표시", m12.tutorial.completed == true and m12.leaderboardTainted == true)
		local again = SaveA.migrate(deepCopy(m12))
		check("MIG", "v12 결과를 다시 이관 = 그대로(멱등)", deepEqual(again, m12))
	end
	-- v21(0658b61 모양 - 4직업 · 보석 optionId · 숫자 키 집합)
	do
		local function cls(level, rebirth)
			return { characterExp = 2000, weapon = { id = MODS.WeaponData.starterId, level = level, grade = rebirth, gems = { { optionId = "연속격", grade = "epic" }, false, false, false, false }, slotUnlocked = { true, false, false, false, false } },
				equipment = {}, stageProgress = { infinite = 30, infiniteBest = 35, bestBossCleared = 30, bossFirstClearStages = { [5] = true, [10] = true, ["15"] = true } },
				rebirthCount = rebirth, gemInventory = { { optionId = nil, grade = "ancient" } }, bossRotation = { order = {}, index = 1, pending = false, history = {}, debugForceNextId = false } }
		end
		local classes = {}
		for _, id in ipairs(MODS.ClassData.order) do
			classes[id] = cls(12, 1)
		end
		local v21 = { version = 21, savedAt = 1720000000, gold = 5555, inventorySlots = 20, bulkSellCutoffGrade = "rare", inventoryWindowPosition = { x = 10, y = 20 }, inventory = {}, gamepasses = {},
			purchases = { optionRerollTickets = { ancient = 3, primordial = 1 } }, classId = "bow", classes = classes, tutorial = { completed = true, step = 7, granted = { [1] = true, [2] = true }, lendBaseline = nil } }
		local m = SaveA.migrate(v21)
		local bow = m.classes.bow
		local gem = bow.weapon.gems[1]
		check("MIG", "v21 → 현재 · 보석 옵션 치환 · 문자열 키 · 변환권 · 창 위치", SaveA.isValidProfile(m) and type(gem) == "table" and gem.option and gem.option.id == "attackPercent" and gem.grade == "epic"
			and bow.stageProgress.bossFirstClearStages["5"] == true and bow.stageProgress.bossFirstClearStages[5] == nil and m.tutorial.granted["1"] == true and m.purchases.optionRerollTickets.ancient == 3
			and m.inventoryWindowPosition.x == 10 and m.bulkSellCutoffGrade == "rare",
			("보석 %s/%s · 키 %d개"):format(tostring(gem and gem.option and gem.option.id), tostring(gem and gem.grade), count(bow.stageProgress.bossFirstClearStages)))
	end
	-- v34 · v44 · v54: 지금 모양에서 그 버전 뒤에 생긴 필드를 걷어낸 표본(그 시절 defaultProfile과 같은 칸 - git show 556f7af · 40be64d · e6ab9ea 대조)
	local AFTER = {
		[34] = { "autoProcess", "world", "peakLevel", "titles", "eggs", "audit", "comeback", "training", "quests", "pets", "settings", "sessionId", "cosmetics", "mailbox", "seasonPass", "communityGoal", "redeemedCodes", "weeklyChallenge", "codex", "checkpoints" },
		[44] = { "comeback", "training", "quests", "pets", "settings", "sessionId", "cosmetics", "mailbox", "seasonPass", "communityGoal", "redeemedCodes", "weeklyChallenge", "codex", "checkpoints" },
		[54] = { "sessionId", "cosmetics", "mailbox", "seasonPass", "communityGoal", "redeemedCodes", "weeklyChallenge", "codex", "checkpoints" },
	}
	local function sampleAt(ver)
		local d = SaveA.migrate({})
		d.version, d.savedAt, d.gold = ver, 1730000000 + ver, 1000 * ver
		for _, f in ipairs(AFTER[ver]) do
			d[f] = nil
		end
		if ver < 37 then
			d.hints = { gemMerchantUsed = true }
		elseif ver < 42 then
			d.hints.stealLockSeen = nil
		end
		if ver < 40 and d.world then
			d.world.bossGates = nil
		end
		for _, cs in pairs(d.classes) do
			if ver < 46 then
				cs.reclaimLevel = nil
			end
			if ver < 50 then
				cs.abilities = nil
			end
			cs.characterExp = 50000
			cs.stageProgress.infiniteBest = 60
			cs.stageProgress.bestBossCleared = 55
		end
		if ver < 56 then
			d.purchases.receipts, d.purchases.log = nil, nil
		end
		local source = ver >= 43 and { kind = "boss", bossId = gateBoss, stage = 40 } or nil
		d.inventory = {
			{ grade = "epic", part = "armor", dropStage = 40, itemLevel = 42, tierIndex = 3, locked = false, option = { id = "attackPercent", roll = 1.0 }, source = source,
				setZone = ver >= 49 and MODS.SetBonus.zoneFromSource(source) or nil },
			{ grade = "primordial", part = "shoes", dropStage = 50, itemLevel = 52, tierIndex = 4, locked = ver >= 43, primordial = ver >= 43 and { legacy = true, grade = ver >= 47 and "primordial" or nil } or nil },
		}
		if ver >= 50 and d.quests then
			d.quests.main, d.quests.mainN, d.quests.guide, d.quests.attendance = 5, nil, nil, nil
		end
		return d
	end
	for _, ver in ipairs({ 34, 44, 54 }) do
		local m = SaveA.migrate(sampleAt(ver))
		local prim = m.inventory[2]
		local ok = SaveA.isValidProfile(m) and m.version == V and m.gold == 1000 * ver and m.sessionId == "" and type(m.codex) == "table" and type(m.checkpoints) == "table" and m.quests and m.quests.guide == nil
			and type(m.pets) == "table" and type(m.cosmetics) == "table" and m.peakLevel >= 1
		local detail = ("골드 %d · 태초 잠금 %s · 세트 %s · 메인 %s"):format(m.gold, tostring(prim.locked), tostring(m.inventory[1].setZone), tostring(m.quests and m.quests.main))
		ok = ok and prim.primordial and prim.primordial.legacy == true and prim.locked == true and prim.primordial.grade == "primordial" -- v43 소급 각인 · v47 각인 grade
		if ver >= 43 then
			ok = ok and m.inventory[1].setZone ~= nil
		end
		check("MIG", ("v%d 모양 → v%d"):format(ver, V), ok, detail)
		check("MIG", ("v%d 결과 다시 이관 = 그대로"):format(ver), deepEqual(SaveA.migrate(deepCopy(m)), m))
	end
	do
		local full = SaveA.migrate({})
		full.gold, full.classId = 31337, "dualblade"
		full.classes.dualblade.weapon.level = 22
		full.settings = { musicVolume = 0.3 }
		full.pets.list = { { species = "x", grade = "good" } }
		local before = deepCopy(full)
		check("MIG", "현재 버전 꽉 찬 표본 다시 이관 = 그대로(멱등)", deepEqual(SaveA.migrate(full), before))
		local fresh = SaveA.migrate({})
		check("MIG", "새 계정 migrate({}) = 현재 버전 · 이정표 1 · 출석 0 · 유효", fresh.version == V and fresh.quests.guide == 1 and fresh.quests.attendance.count == 0 and SaveA.isValidProfile(fresh) and SaveA.repairProfile ~= nil and #SaveA.repairProfile(deepCopy(fresh)) == 0)
	end

	-- ═══ 2. 손상 복구(loadProfile 전체 경로 - 가짜 DataStore에 손상 값을 넣고 읽는다) ═══
	local function loadRaw(raw)
		local p = mkPlayer(5000 + math.random(1, 100000))
		DS.data[keyOf(p.UserId)] = raw
		local profile, err, info = SaveA.loadProfile(p)
		return profile, err, info, DS.data[keyOf(p.UserId)]
	end
	local function corrupt(mutator)
		local d = SaveA.migrate({})
		d.savedAt = os.time() - 1000
		d.gold = 500
		mutator(d)
		return d
	end
	local BAD = {
		{ "골드 숫자 문자열 \"1500\" → 1500", function(d) d.gold = "1500" end, function(p) return p and p.gold == 1500 end },
		{ "골드 NaN → 0", function(d) d.gold = 0 / 0 end, function(p) return p and p.gold == 0 end },
		{ "골드 inf → 0", function(d) d.gold = math.huge end, function(p) return p and p.gold == 0 end },
		{ "골드 음수 → 0(통계 값)", function(d) d.gold = -500 end, function(p, info) return p and p.gold == 0 and info.negativeGold == -500 end },
		{ "버전 숫자 문자열 \"61\" → 로드", function(d) d.version = tostring(V) end, function(p) return p and p.version == V end },
		{ "버전 쓰레기 문자열 → invalid_schema(에러 없이)", function(d) d.version = "abc" end, function(p, info, err) return p == nil and err == "invalid_schema" end },
		{ "안내 · 세계 · 칭호 · 알 가방 nil → 빈 표", function(d) d.hints, d.world, d.titles, d.eggs = nil, nil, nil, nil end, function(p) return p and type(p.world.nests) == "table" and type(p.hints) == "table" end },
		{ "재료 문자열 · 음수 · 없음 → 정수 0 이상", function(d) d.materials = { enhanceStone = "30", highEnhanceStone = -4 } end, function(p) return p and p.materials.enhanceStone == 30 and p.materials.highEnhanceStone == 0 end },
		{ "보석 가루 소수 · 마일스톤 음수 → 정수", function(d) d.gemDust, d.milestoneUnlocks = 12.5, -3 end, function(p) return p and p.gemDust == 12 and p.milestoneUnlocks == 0 end },
		{ "방지권 nil 표 → 0장", function(d) d.purchases.protectionTickets = nil end, function(p) return p and p.purchases.protectionTickets.drop == 0 end },
		{ "도감 도장에 없어진 보스 id → 뺌(다른 도장 유지)", function(d) d.purchases.bossCodex = { ghost_boss_removed = true, [gateBoss] = true } end, function(p) return p and p.purchases.bossCodex.ghost_boss_removed == nil and p.purchases.bossCodex[gateBoss] == true end },
		{ "직업 하나 빠짐(새 직업 추가) → 기본 상태", function(d) d.classes.healer = nil end, function(p) return p and p.classes.healer and p.classes.healer.weapon.level == 0 end },
		{ "중첩 NaN(직업 경험치) → 0", function(d) d.classes.bow.characterExp = 0 / 0 end, function(p) return p and p.classes.bow.characterExp == 0 end },
		{ "강화 게이지 상한 넘음 → 상한", function(d) d.classes.bow.weapon.enhanceGauge = 999999 end, function(p) return p and p.classes.bow.weapon.enhanceGauge == MODS.EnhanceConfig.gauge.max end },
		{ "자동 처리 등급 모름 → epic · 끔", function(d) d.autoProcess.maxGrade = "mythic" d.autoProcess.enabled = true end, function(p) return p and p.autoProcess.maxGrade == "epic" and p.autoProcess.enabled == false end },
		{ "classes 문자열 → invalid_schema(고치지 않음)", function(d) d.classes = "broken" end, function(p, info, err) return p == nil and err == "invalid_schema" end },
		{ "classes 빈 표 → invalid_schema(진행 덮어쓰기 방지)", function(d) d.classes = {} end, function(p, info, err) return p == nil and err == "invalid_schema" end },
		{ "inventory nil → invalid_schema(고치지 않음)", function(d) d.inventory = nil end, function(p, info, err) return p == nil and err == "invalid_schema" end },
		{ "모르는 옵션 id → 로드 O · 그 장비만 보관 칸(QUEUE-ALL5 A3 - 옛 기대 = invalid_schema)", function(d) d.inventory = { { grade = "epic", part = "armor", option = { id = "removedOption" } } } end, function(p, info, err) return p ~= nil and #p.inventory == 0 and #p.quarantine == 1 and p.quarantine[1].why == "option:removedOption" and info.quarantined and #info.quarantined == 1 end },
	}
	for _, case in ipairs(BAD) do
		local raw = corrupt(case[2])
		local rawCopy = deepCopy(raw)
		local profile, err, info, after = loadRaw(raw)
		local ok = case[3](profile, info or {}, err)
		ok = ok and deepEqual(after, rawCopy) -- 로드는 저장소를 바꾸지 않는다(고친 값은 다음 저장 때 써진다)
		check("BAD", case[1], ok, ("에러=%s · 고친 칸 %s"):format(tostring(err), info and info.repaired and table.concat(info.repaired, ",") or "-"))
	end
	do
		local profile, err = loadRaw("garbage-string")
		check("BAD", "저장값이 표가 아님(문자열) → invalid_schema", profile == nil and err == "invalid_schema", tostring(err))
		local big = SaveA.migrate({})
		for i = 1, 20000 do
			big.inventory[i] = { grade = "epic", part = "armor", dropStage = 40, itemLevel = 42, tierIndex = 3, locked = false, option = { id = "attackPercent", roll = 0.9731 }, source = { kind = "field", zone = "tier1", stage = 40 }, setZone = "tier1" }
		end
		for i = 1, 3000 do
			big.classes.bow.gemInventory[i] = { grade = "ancient", option = { id = "crit", roll = 1.0 }, itemLevel = 300 }
		end
		local p2, e2 = loadRaw(big)
		local bytes = jsonSize(big)
		check("BAD", "거대 배열(가방 20,000 · 보석 3,000) → 로드 · 크기 추정", p2 ~= nil and #p2.inventory == 20000, ("에러 %s · 약 %.2fMB(한도 4MB)"):format(tostring(e2), bytes / 1048576))
		local normal = SaveA.migrate({})
		for i = 1, 200 do
			normal.inventory[i] = big.inventory[1]
		end
		check("BAD", "현실 최대급 프로필(가방 200) 크기", jsonSize(normal) < 200 * 1024, ("약 %.1fKB"):format(jsonSize(normal) / 1024))
	end
	runUntilIdle()

	-- ═══ 3. 세션 잠금 · 두 서버 ═══
	local SaveB = LOADERS["SaveSystem"]() -- 서버 B(다른 SERVER_SESSION_ID)
	check("LOCK", "두 서버 표식이 다르다", SaveA.serverSessionId ~= SaveB.serverSessionId, SaveA.serverSessionId .. " / " .. SaveB.serverSessionId)
	do
		local p = mkPlayer(42)
		DS.data[keyOf(42)] = nil
		local pa = SaveA.loadProfile(p)
		pa.gold = 100
		check("LOCK", "A 로드 · 저장(표식 A)", SaveA.saveProfile(p, pa) and DS.data[keyOf(42)].sessionId == SaveA.serverSessionId)
		-- 같은 사람이 B에 접속(A가 아직 쥠) → B는 상한까지 기다리고 그대로 진행
		local gets0, t0 = DS.count.Get, NOW
		local pb, _, infoB = SaveB.loadProfile(p)
		check("LOCK", "A가 쥔 채 B 접속 → 10초 기다리고 진행(풀림 X)", pb and infoB.lockWaitedSeconds == SaveConfig.sessionLockMaxWaitSeconds and infoB.lockReleased == false,
			("대기 %.1f초 · 읽기 %d회"):format(NOW - t0, DS.count.Get - gets0))
		-- A가 더 진행하고 퇴장 저장(놓음) → B의 다음 저장은 stale(덮어쓰기 막힘 · A 진행 보존)
		pa.gold = 250
		SaveA.markReleasing(p, true)
		SaveA.saveProfile(p, pa)
		SaveA.markReleasing(p, false)
		pb.gold = 999
		local okB, whyB = SaveB.saveProfile(p, pb)
		check("LOCK", "두 서버 동시 진행 → 늦게 읽은 B 저장 = stale · 저장값 = A의 마지막", okB == false and whyB == "stale_session" and DS.data[keyOf(42)].gold == 250, ("B=%s · 저장 골드 %d"):format(tostring(whyB), DS.data[keyOf(42)].gold))
		-- 옮겨 접속: A가 쥔 상태에서 B 로드 중에 A 퇴장 저장 도착 → B는 풀린 값으로 로드
		pa.gold = 300
		SaveA.saveProfile(p, pa) -- 다시 쥠(표식 A)
		task.delay(3, function()
			pa.gold = 333
			SaveA.markReleasing(p, true)
			SaveA.saveProfile(p, pa)
			SaveA.markReleasing(p, false)
		end)
		local pb2, _, info2 = SaveB.loadProfile(p)
		check("LOCK", "옮겨 접속: B가 기다리는 중 A 퇴장 저장 도착 → 새 값으로 로드", pb2 and pb2.gold == 333 and info2.lockReleased == true, ("골드 %s · 대기 %s초"):format(tostring(pb2 and pb2.gold), tostring(info2.lockWaitedSeconds)))
		pb2.gold = 400
		check("LOCK", "옮긴 뒤 B 저장 정상(stale 아님)", SaveB.saveProfile(p, pb2) == true)
		-- 메아리: 첫 시도가 써진 뒤 에러 → 재시도는 자기 값을 보고도 stale이 아니어야 한다
		pb2.gold = 450
		DS.echoKeys[keyOf(42)] = 1
		local okE, whyE = SaveB.saveProfile(p, pb2)
		check("LOCK", "써진 뒤 타임아웃 → 재시도가 내 메아리를 stale로 오판하지 않음", okE == true and DS.data[keyOf(42)].gold == 450, tostring(whyE))
		-- 퇴장 저장(놓음)의 메아리: 같은 초 남의 놓음과 구분할 수 없어 stale로 끝나지만 값은 이미 써졌다(손실 없음)
		pb2.gold = 470
		DS.echoKeys[keyOf(42)] = 1
		SaveB.markReleasing(p, true)
		local okR, whyR = SaveB.saveProfile(p, pb2)
		SaveB.markReleasing(p, false)
		check("LOCK", "퇴장 저장 메아리 = stale 표시지만 값은 써짐", okR == false and whyR == "stale_session" and DS.data[keyOf(42)].gold == 470 and DS.data[keyOf(42)].sessionId == "", ("%s · 저장 골드 %d"):format(tostring(whyR), DS.data[keyOf(42)].gold))
	end
	runUntilIdle()

	-- ═══ 4. 실패 처리(SaveCoordinator) ═══
	do
		local p = mkPlayer(77)
		DS.data[keyOf(77)] = nil
		PROFILES[p] = SaveA.loadProfile(p)
		PROFILES[p].gold = 10
		DS.failKeys[keyOf(77)] = 4 -- 첫 시도 + 재시도 3 전부 실패
		local t0 = NOW
		local ok1 = Coord.saveForPlayer(p)
		check("FAIL", "4번 다 실패 → false · 저장 중단 안 함", ok1 == false and not Coord.isSuspended(p), ("%.1f초(재시도 대기 1+3+6)"):format(NOW - t0))
		PROFILES[p].gold = 20
		check("FAIL", "다음 주기 저장은 성공(진행 반영)", Coord.saveForPlayer(p) == true and DS.data[keyOf(77)].gold == 20)
		-- stale(다른 서버가 더 새 저장)은 중단 유지
		DS.data[keyOf(77)].savedAt = os.time() + 100
		local ok3 = Coord.saveForPlayer(p)
		check("FAIL", "stale_session → 저장 중단(덮어쓰기 막음)", ok3 == false and Coord.isSuspended(p))
		check("FAIL", "중단된 뒤 저장 시도 = 건너뜀", Coord.saveForPlayer(p) == false and Coord.activeSaves() == 0)
		PROFILES[p] = nil
	end
	runUntilIdle()

	-- ═══ 5. 종료 저장(12명) ═══
	local function setupPlayers(base, n)
		local list = {}
		for i = 1, n do
			local p = mkPlayer(base + i)
			DS.data[keyOf(p.UserId)] = nil
			PROFILES[p] = SaveA.loadProfile(p)
			PROFILES[p].gold = i
			table.insert(list, p)
		end
		runUntilIdle()
		return list
	end
	do
		DS.latency = 0.3
		local list = setupPlayers(1000, 12)
		local u0 = DS.count.Update
		local done, secs
		task.spawn(function()
			done, secs = Immediate.flushAllForShutdown(list, SaveConfig.shutdownSaveDeadlineSeconds, function(pl) SaveA.markReleasing(pl, true) end)
		end)
		runUntilIdle()
		local released = 0
		for _, pl in ipairs(list) do
			if DS.data[keyOf(pl.UserId)].sessionId == "" then
				released += 1
			end
		end
		check("CLOSE", "평시 12명 동시 종료 저장 → 마감 안", done == true and released == 12, ("%.1f초 · 쓰기 %d · 놓음 %d/12"):format(secs or -1, DS.count.Update - u0, released))
		-- 장애: 사람마다 처음 3번 실패(4번째 성공 - 재시도 대기 1 + 3 + 6초)
		local list2 = setupPlayers(2000, 12)
		for _, pl in ipairs(list2) do
			DS.failKeys[keyOf(pl.UserId)] = 3
		end
		task.spawn(function()
			done, secs = Immediate.flushAllForShutdown(list2, SaveConfig.shutdownSaveDeadlineSeconds)
		end)
		runUntilIdle()
		local saved = 0
		for _, pl in ipairs(list2) do
			if DS.data[keyOf(pl.UserId)].gold == PROFILES[pl].gold and DS.data[keyOf(pl.UserId)].savedAt > 0 then
				saved += 1
			end
		end
		check("CLOSE", "장애(사람마다 3번 실패) 12명 동시 → 30초 안 전원 저장", done == true and saved == 12 and secs < 30, ("%.1f초 · 저장 %d/12"):format(secs or -1, saved))
		-- 옛 방식(한 명씩 차례) 같은 장애
		local list3 = setupPlayers(3000, 12)
		for _, pl in ipairs(list3) do
			DS.failKeys[keyOf(pl.UserId)] = 3
		end
		local seqSecs, savedBy30 = 0, 0
		task.spawn(function()
			local t0 = NOW
			for _, pl in ipairs(list3) do
				Immediate.flush(pl)
				if NOW - t0 <= 30 then
					savedBy30 += 1
				end
			end
			seqSecs = NOW - t0
		end)
		runUntilIdle()
		check("CLOSE", "참고: 옛 차례 방식 같은 장애 → 30초 넘음(고친 이유)", seqSecs > 30, ("%.1f초 · 30초 안 저장 %d/12"):format(seqSecs, savedBy30))
		-- 마지막 사람이 나가며 서버가 닫힘: 퇴장 저장이 진행 중(GetPlayers 빈 목록) → 종료가 그 저장을 기다린다
		local list4 = setupPlayers(4000, 1)
		local last = list4[1]
		DS.latency = 2
		PROFILES[last].gold = 4242
		local leaving = true
		task.spawn(function()
			Immediate.flush(last)
			leaving = false
		end)
		local closedAt
		task.spawn(function()
			local ok = Immediate.flushAllForShutdown({}, SaveConfig.shutdownSaveDeadlineSeconds, nil, function() return leaving end)
			closedAt = NOW
			check("CLOSE", "빈 목록 종료 = 진행 중 퇴장 저장이 끝난 뒤 닫힘", ok == true and DS.data[keyOf(last.UserId)].gold == 4242, ("닫힌 시각 저장 골드 %s"):format(tostring(DS.data[keyOf(last.UserId)].gold)))
		end)
		runUntilIdle()
		DS.latency = 0.2
		for p in pairs(PROFILES) do
			PROFILES[p] = nil
		end
	end

	-- ═══ 6. 12인 호출 수(분당) ═══
	do
		local function snap()
			return { Get = DS.count.Get, Update = DS.count.Update, Set = DS.count.Set, Remove = DS.count.Remove }
		end
		local function diff(a, b)
			return { Get = b.Get - a.Get, Update = b.Update - a.Update, Set = b.Set - a.Set, Remove = b.Remove - a.Remove }
		end
		local W_CONS, R_CONS = 60 + 10 * 12, 60 + 10 * 12 -- 지시서 · 코드 주석 값(옛 공식 문서)
		local W_NOW, R_NOW = 60 + 40 * 12, 60 + 40 * 12 -- 2026 공식 문서(서버 표준 저장소)
		-- 동시 접속 12명(모두 새 계정 · 잠금 없음)
		local s0 = snap()
		local list = {}
		for i = 1, 12 do
			local p = mkPlayer(6000 + i)
			table.insert(list, p)
			task.spawn(function()
				PROFILES[p] = SaveA.loadProfile(p)
			end)
		end
		runUntilIdle()
		local join = diff(s0, snap())
		check("BUDGET", "12명 동시 접속: 프로필 읽기 = 12(+ 선물함 12 = SaveServer 밖 · 표 참고)", join.Get == 12, ("읽기 %d · 쓰기 %d"):format(join.Get, join.Update))
		-- 잠금 대기 최악: 12명 모두 다른 서버가 쥔 채(옮겨 접속 실패) → 사람당 1 + 5 읽기
		for _, p in ipairs(list) do
			local d = DS.data[keyOf(p.UserId)] or SaveA.migrate({})
			d.sessionId, d.savedAt = "OTHER", os.time()
			DS.data[keyOf(p.UserId)] = d
		end
		local s1 = snap()
		for _, p in ipairs(list) do
			task.spawn(function()
				SaveA.loadProfile(p)
			end)
		end
		runUntilIdle()
		local lockJoin = diff(s1, snap())
		check("BUDGET", "최악 접속(12명 전원 잠금 대기): 읽기 72 ≤ 한도(10초 안)", lockJoin.Get == 12 * (1 + SaveConfig.sessionLockMaxWaitSeconds / SaveConfig.sessionLockPollSeconds) and lockJoin.Get <= R_CONS,
			("읽기 %d · 한도 %d(보수) / %d(현행)"):format(lockJoin.Get, R_CONS, R_NOW))
		for _, p in ipairs(list) do
			DS.data[keyOf(p.UserId)].sessionId = ""
			PROFILES[p] = SaveA.migrate(deepCopy(DS.data[keyOf(p.UserId)]))
		end
		-- 1분 최악 플레이: 전원이 매초 즉시 저장 요청(강화 연타 · 수령 연타) + 60초 자동 저장
		local s2 = snap()
		local t0 = NOW
		for _, p in ipairs(list) do
			task.spawn(function()
				while NOW - t0 < 60 do
					Immediate.request(p)
					task.wait(1)
				end
			end)
		end
		task.delay(59.9, function()
			for _, p in ipairs(list) do
				Coord.saveForPlayer(p)
			end
		end)
		runUntilIdle(t0 + 60)
		runUntilIdle()
		local minute = diff(s2, snap())
		check("BUDGET", "최악 1분(12명 매초 즉시 저장 + 자동 저장): 쓰기 ≤ 보수 한도 180", minute.Update <= W_CONS, ("쓰기 %d/분 · 보수 %d · 현행 %d"):format(minute.Update, W_CONS, W_NOW))
		-- 평시 1분: 자동 저장만
		local s3 = snap()
		for _, p in ipairs(list) do
			Coord.saveForPlayer(p)
		end
		runUntilIdle()
		local calm = diff(s3, snap())
		check("BUDGET", "평시 1분(자동 저장): 쓰기 12", calm.Update == 12, ("쓰기 %d"):format(calm.Update))
		-- 동시 퇴장 12명
		local s4 = snap()
		for _, p in ipairs(list) do
			task.spawn(function()
				SaveA.markReleasing(p, true)
				Immediate.flush(p)
				SaveA.markReleasing(p, false)
				PROFILES[p] = nil
			end)
		end
		runUntilIdle()
		local leave = diff(s4, snap())
		check("BUDGET", "12명 동시 퇴장: 쓰기 12", leave.Update == 12, ("쓰기 %d"):format(leave.Update))
		print(("[BUDGET] 요약 접속 읽기 %d · 잠금 최악 읽기 %d · 최악 1분 쓰기 %d · 평시 1분 쓰기 %d · 퇴장 쓰기 %d"):format(join.Get, lockJoin.Get, minute.Update, calm.Update, leave.Update))
	end
end

task.spawn(function()
	local ok, err = pcall(main)
	if not ok then
		print("[LAUNCH] 에러 " .. tostring(err))
	end
end)
runUntilIdle()
print(("[LAUNCH] 끝 %d/%d"):format(pass, total))
