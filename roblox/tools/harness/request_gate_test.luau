Random = { new = function(seed) math.randomseed(seed or 1); return { NextInteger = function(_, a, b) return math.random(a, b) end, NextNumber = function(_, a, b) a = a or 0; b = b or 1; return a + math.random() * (b - a) end } end }
-- QUEUE-6h-b 후속 안전장치 ③ 공통 요청 제한 하네스: 실제 서버 핸들러(REMOTES)에 연타를 넣고 RequestGate.dropped로 버린 수를 센다.
-- 의존 = python deps.py PlayerProfile,PetService,QuestService,SaveSystem,SettingsService,FallServer,InventoryServer.server,RequestGate(attack_test와 같은 묶음 + RequestGate - ClassServer · GemServer는 로드 때 도는 루프가 가짜 task.wait에서 멈춰 입구 함수로 직접 잰다)
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then pass += 1 end
	print(("[GATE] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end
local ok, err = pcall(function()
	local SaveSystem, PlayerProfile = MODS.SaveSystem, MODS.PlayerProfile
	local function makePlayer(name, id)
		local attrs = {}
		return setmetatable({ Name = name, UserId = id, Parent = true }, { __index = function(_, k)
			if k == "SetAttribute" then return function(_, n, v) attrs[n] = v end end
			if k == "GetAttribute" then return function(_, n) return attrs[n] end end
			if k == "FindFirstChild" or k == "WaitForChild" or k == "FindFirstChildOfClass" then return function() return nil end end
			if k == "IsA" then return function() return false end end
			if k == "GetAttributeChangedSignal" then return function() return { Connect = function() end } end end
			return nil
		end })
	end
	local a, b = makePlayer("GateA", 91), makePlayer("GateB", 92)
	for _, pl in ipairs({ a, b }) do
		PlayerProfile.init(pl, SaveSystem.migrate({}))
		PlayerProfile.setClassId(pl, "bow")
	end
	local _ = MODS["InventoryServer.server"]
	local Gate, Cfg = MODS.RequestGate, MODS.RequestLimitConfig
	local function fire(name, pl, n, ...)
		local rec = REMOTES[name]
		assert(rec and rec.onEvent, "no remote " .. name)
		for _ = 1, n do pcall(rec.onEvent, pl, ...) end
	end
	local function dropped(name) return Gate.dropped[name] or 0 end

	-- 1. 이벤트 연타: 잠금 30번(잘못된 칸 - 동작은 거부지만 입구는 센다) → burst만 통과
	fire("LockRequest", a, 30, 999, true)
	check("잠금 연타 30 → 기본 통 " .. Cfg.default.burst .. "개만 통과", dropped("LockRequest") == 30 - Cfg.default.burst, ("버림 %d"):format(dropped("LockRequest")))

	-- 2. 다른 사람은 따로 센다
	local before = dropped("LockRequest")
	fire("LockRequest", b, 5, 999, true)
	check("다른 사람 5번 = 버림 없음", dropped("LockRequest") == before)

	-- 3. 직업 전환은 더 좁다(초당 1 · 통 2)
	local passed = 0
	for _ = 1, 5 do if Gate.allow(a, "ClassSelectRequest") then passed += 1 end end
	check("직업 전환 5번 → 2개만(Remote별 표)", passed == 2 and dropped("ClassSelectRequest") == 3, ("통과 %d"):format(passed))

	-- 4. 시간이 지나면 다시 찬다(0.35초 = 기본 초당 10 → 3개)
	local t0 = os.clock()
	while os.clock() - t0 < 0.35 do end
	before = dropped("LockRequest")
	fire("LockRequest", a, 3, 999, true)
	check("0.35초 뒤 3번 통과", dropped("LockRequest") == before, ("버림 +%d"):format(dropped("LockRequest") - before))

	-- 5. 판매 · 장착 · 보석 이벤트도 같은 입구
	fire("SellRequest", a, 15, "sell", 999)
	fire("EquipRequest", a, 15, "equip", 999)
	fire("BulkSellCutoffRequest", a, 15, "nope")
	check("판매 · 장착 · 일괄판매 기준 연타 15 → 각 5 버림", dropped("SellRequest") == 5 and dropped("EquipRequest") == 5 and dropped("BulkSellCutoffRequest") == 5)

	-- 6. RemoteFunction: 통(20) 안은 매번 새로 계산 · 넘치면 마지막 결과(nil 아님)
	local calls = 0
	local results = {}
	for i = 1, 25 do
		results[i] = Gate.invoke(a, "HarnessFetch", "", function() calls += 1; return { n = calls } end)
	end
	check("함수 25번 → 20번 계산 · 넘친 5번 = 마지막 결과", calls == Cfg.functionDefault.burst and results[25] ~= nil and results[25].n == calls, ("계산 %d"):format(calls))
	local inv = REMOTES.InheritPreview and REMOTES.InheritPreview.onInvoke and REMOTES.InheritPreview.onInvoke(a, "weapon", 999)
	check("실제 InheritPreview 입구가 결과를 돌려준다", type(inv) == "table", type(inv))
end)
if not ok then print("[GATE] 에러 " .. tostring(err)) end
print(("[GATE] 끝 %d/%d"):format(pass, total))
