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
	-- QUEUE-ALL4 G: QuestService.start가 탐험 판정 루프(while true + task.wait(2), Q3-1 c7de2e0)를 task.spawn한다 - 가짜 spawn은 바로 실행 · 가짜 wait는 양보 안 함 → 무한 루프. start 동안만 spawn을 비운다.
	local spawn0 = task.spawn
	task.spawn = function() end
	MODS.QuestService.start()
	task.spawn = spawn0
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
	for _, args in ipairs({ { "sell", "x" }, { "sell", 0 / 0 }, { "sell", 1e308 }, { "sell", -5 }, { "sell", 99 }, { "sellBulk", {} }, { "sellGrades", "legendary", 1 }, { "sellGrades", {}, 1 }, { "sellGrades", "normal", "x" }, { "nope", 1 }, { nil } }) do
		local r = fire("SellRequest", table.unpack(args))
		if r ~= "ok" then table.insert(bad, tostring(args[1]) .. "/" .. tostring(args[2]) .. "=" .. r) end
	end
	check("판매 잘못된 인자 11종(QUEUE-ALL8 G1 sellGrades 3종 포함) = 에러 없이 무시", #bad == 0 and #p.inventory == 5, table.concat(bad, " · "))
	local tGap = os.clock()
	while os.clock() - tGap < 1.1 do end -- 잘못된 인자 11번이 공통 요청 제한 통(10)을 다 썼다 → 채워질 때까지(사람 손 간격)
	p.inventory[1].option = nil
	p.inventory[2].itemLevel = 6 -- 칸마다 다른 장비(확인값이 달라지게)
	local sig = MODS.Loot.itemSignature(p.inventory[1])
	for _ = 1, 100 do fire("SellRequest", "sell", 1, sig) end
	check("판매 연타 100회(같은 칸 · 같은 확인값) = 1개만 팔림(밀려 올라온 다른 장비는 확인값 불일치로 거부)", #p.inventory == 4, ("남은 %d"):format(#p.inventory))
	local sig2 = MODS.Loot.itemSignature(p.inventory[1])
	local tWait = os.clock()
	while os.clock() - tWait < 0.25 do end -- QUEUE-6h-b 후속: 공통 요청 제한(통 10 · 초당 10) - 연타 100회 직후 같은 순간의 정상 판매는 버려진다(의도) → 사람 손 간격을 둔다
	fire("SellRequest", "sell", 1, sig2)
	fire("SellRequest", "sell", 2, "위조")
	check("정상 연속 판매는 바로 됨 · 확인값 위조는 거부", #p.inventory == 3, ("남은 %d"):format(#p.inventory))

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

	-- ⑥ UI-1b 0절(VERIFY-5): 여러 칸 판매 · 분해에 같은 번호 두 번 = 그 칸 하나만 · 당겨진 다른 장비 안 팔림 · 잠금 거절
	local function fill()
		p.inventory = {}
		for i = 1, 6 do table.insert(p.inventory, { grade = "epic", part = "armor", itemLevel = i, dropStage = 5, tierIndex = 1 }) end
	end
	local function gap() local t = os.clock() while os.clock() - t < 0.3 do end end
	local S = MODS.Loot.itemSignature
	for _, act in ipairs({ "sellList", "dismantleList" }) do
		fill()
		gap()
		local s5 = S(p.inventory[5])
		fire("SellRequest", act, { { 5, s5 }, { 5, s5 } })
		local levels = {}
		for _, it in ipairs(p.inventory) do table.insert(levels, it.itemLevel) end
		check(act .. " 같은 번호 두 번 = 5번만 처리(6번 남음)", #p.inventory == 5 and p.inventory[5].itemLevel == 6, table.concat(levels, ","))
	end
	fill()
	p.inventory[3].locked = true
	gap()
	fire("SellRequest", "sellList", { { 3, S(p.inventory[3]) }, { 4, S(p.inventory[4]) }, { 2, "위조" } })
	check("sellList 잠금 · 위조 거절 · 정상 칸만", #p.inventory == 5 and p.inventory[3].locked and p.inventory[4].itemLevel == 5 and p.inventory[2].itemLevel == 2, ("남은 %d"):format(#p.inventory))
end)
if not ok then print("[R3] 하네스 에러 " .. tostring(err)) end
print(("[R3] 끝 %d/%d"):format(pass, total))
