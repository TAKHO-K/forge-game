Random = { new = function(seed) math.randomseed(seed or 1); return { NextInteger = function(_, a, b) return math.random(a, b) end, NextNumber = function(_, a, b) a = a or 0; b = b or 1; return a + math.random() * (b - a) end } end }
-- QUEUE-6h-b R3 공격 하네스: 실제 서버 핸들러(OnServerEvent)에 잘못된 인자 · 연타 · 남의 번호 · 위조 표시를 넣는다.
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then pass += 1 end
	print(("[R3] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end
local ok, err = pcall(function()
	local SaveSystem, PlayerProfile = MODS.SaveSystem, MODS.PlayerProfile
	local attrs = {}
	local player = setmetatable({ Name = "Atk", UserId = 77, Parent = true }, { __index = function(_, k)
		if k == "SetAttribute" then return function(_, n, v) attrs[n] = v end end
		if k == "GetAttribute" then return function(_, n) return attrs[n] end end
		if k == "FindFirstChild" or k == "WaitForChild" or k == "FindFirstChildOfClass" then return function() return nil end end
		if k == "IsA" then return function() return false end end
		if k == "GetAttributeChangedSignal" then return function() return { Connect = function() end } end end
		return nil
	end })
	local profile = SaveSystem.migrate({})
	PlayerProfile.init(player, profile)
	PlayerProfile.setClassId(player, "bow")
	local p = PlayerProfile.getProfile(player)
	p.tutorial = p.tutorial or {}
	p.tutorial.completed = true
	local _ = MODS["InventoryServer.server"]
	MODS.QuestService.start()
	MODS.PetService.start()
	MODS.SettingsService.start()
	local captured
	local FallServer = MODS.FallServer
	FallServer.start()
	FallServer.onLanded = function(_, _, flags) captured = flags end
	local function fire(name, ...)
		local rec = REMOTES[name]
		if not rec or not rec.onEvent then return "no_remote" end
		local okCall, e = pcall(rec.onEvent, player, ...)
		return okCall and "ok" or ("에러: " .. tostring(e):match(":%d+: (.*)$"))
	end

	-- ① 판매: 잘못된 인자 · 연타 100회
	p.inventory = {}
	for i = 1, 5 do table.insert(p.inventory, { grade = "epic", part = "armor", itemLevel = 5, dropStage = 5, tierIndex = 1 }) end
	local bad = {}
	for _, args in ipairs({ { "sell", "x" }, { "sell", 0 / 0 }, { "sell", 1e308 }, { "sell", -5 }, { "sell", 99 }, { "sellBulk", {} }, { "nope", 1 }, { nil } }) do
		local r = fire("SellRequest", table.unpack(args))
		if r ~= "ok" then table.insert(bad, tostring(args[1]) .. "/" .. tostring(args[2]) .. "=" .. r) end
	end
	check("판매 잘못된 인자 8종 = 에러 없이 무시", #bad == 0 and #p.inventory == 5, table.concat(bad, " · "))
	local t0 = os.clock()
	while os.clock() - t0 < 0.32 do end -- 앞 요청의 0.3초 간격 창이 지나게
	for _ = 1, 100 do fire("SellRequest", "sell", 1) end
	check("판매 연타 100회(같은 순간) = 1개만 팔림", #p.inventory == 4, ("남은 %d"):format(#p.inventory))

	-- ② 퀘스트: 모르는 동작 · 임의 문자열 · 없는 칸
	local qbad = {}
	for _, args in ipairs({ { nil }, { {} }, { string.rep("x", 1000) }, { "claim", "attendance", "99" }, { "claim", 5, 5 }, { "train", "stat", nil } }) do
		local r = fire("QuestRequest", table.unpack(args))
		if r ~= "ok" then table.insert(qbad, r) end
	end
	check("퀘스트 잘못된 인자 6종 = 에러 없이 무시", #qbad == 0, table.concat(qbad, " · "))

	-- ③ 펫: NaN · 거대 · 음수 번호 · 남의 알(획득 시각 불일치)
	p.eggs = { { zone = "tier1", grade = "normal", species = { "stoneTurtle", "mossHare" }, nest = "t", at = 5 } }
	local pbad = {}
	for _, args in ipairs({ { "hatch", 0 / 0, 5 }, { "hatch", 1e308, 5 }, { "hatch", -1, 5 }, { "hatch", 1, 999 }, { "claim", 1 }, { "equip", 42 }, { "zzz" } }) do
		local r = fire("PetRequest", table.unpack(args))
		if r ~= "ok" then table.insert(pbad, r) end
	end
	check("펫 잘못된 인자 7종 = 에러 없음 · 알 그대로", #pbad == 0 and #p.eggs == 1, table.concat(pbad, " · "))

	-- ④ 설정: 타입 틀림 · 없는 프리셋 · 없는 키
	fire("SettingsSave", "reduceFlashes", "yes")
	fire("SettingsSave", "autoStage", "godmode")
	fire("SettingsSave", 123, true)
	local st = PlayerProfile.getSettings(player)
	check("설정 잘못된 값 3종 = 저장 안 됨", st.reduceFlashes == nil and st.autoStage == nil and st[123] == nil)

	-- ⑤ 낙하 위조: server 표시를 보내도 핸들러가 걸러 준다(F1)
	fire("FallLanded", 0, { server = true, water = true, ladder = true })
	check("낙하 신고 위조 server 표시 = 버려짐(water · ladder만 전달)", captured ~= nil and captured.server == nil and captured.water == true, captured and tostring(captured.server) or "nil")
end)
if not ok then print("[R3] 하네스 에러 " .. tostring(err)) end
print(("[R3] 끝 %d/%d"):format(pass, total))
