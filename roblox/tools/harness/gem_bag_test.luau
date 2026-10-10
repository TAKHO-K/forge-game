-- PROG-2B-1 6 보석함 상한(= 장비 가방 칸 수) · 넘침 보관함(소멸 0 · 자리가 나면 오래된 것부터 돌아옴) · 보관함 가득 = 분해만 막음 · 저장 v80 · 저장 크기(가방 최대 + 보관함 가득 vs DataStore 키당 4MB).
-- 실행: LUAU=<luau.exe> PRELUDE=server_prelude.luau EXTRA_SERVER=$(python deps.py PlayerProfile,PetService,QuestService,SaveSystem) ECON_RES=res_gembag.txt python build_run.py gem_bag_test.luau
Random = { new = function(seed) math.randomseed(seed or 1); return { NextInteger = function(_, a, b) return math.random(a, b) end, NextNumber = function(_, a, b) a = a or 0; b = b or 1; return a + math.random() * (b - a) end } end }
MODS.SlotSaveData.enabled = false
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then pass += 1 end
	print(("[GEMBAG] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end
local function jsonSize(v)
	local t = type(v)
	if t == "string" then return #v + 2 elseif t == "number" then return #tostring(v) elseif t == "boolean" then return v and 4 or 5
	elseif t == "table" then
		local n = 2
		for k, x in pairs(v) do n += jsonSize(tostring(k)) + 1 + jsonSize(x) + 1 end
		return n
	end
	return 4
end

local ok, err = pcall(function()
	local PP, SaveSystem, GemData = MODS.PlayerProfile, MODS.SaveSystem, MODS.GemData
	local attrs = {}
	local player = setmetatable({ Name = "Gem", UserId = 5151, Parent = true }, { __index = function(_, k)
		if k == "SetAttribute" then return function(_, n, v) attrs[n] = v end end
		if k == "GetAttribute" then return function(_, n) return attrs[n] end end
		if k == "FindFirstChild" or k == "WaitForChild" or k == "FindFirstChildOfClass" then return function() return nil end end
		if k == "IsA" then return function() return false end end
		if k == "GetAttributeChangedSignal" then return function() return { Connect = function() end } end end
		return nil
	end })
	local profile = SaveSystem.migrate({})
	profile.tutorial.completed = true
	PP.init(player, profile)
	PP.setClassId(player, "bow")
	local p = PP.getProfile(player)
	local cs = p.classes.bow
	local OPT = "attackPercent"
	local function gem(i) return { grade = "relic", itemLevel = i, option = { id = OPT, roll = 1 } } end
	local cap = PP.inventoryCapacity(p)
	check("6-1 보석함 상한 = 장비 가방 칸 수(같은 함수)", select(1, PP.settleGemBag(player)) == cap and cap == MODS.InventorySync.capacity(p), tostring(cap))
	cs.gemInventory, cs.gemOverflow = {}, {}
	for i = 1, cap + 7 do table.insert(cs.gemInventory, gem(i)) end
	local _, over = PP.settleGemBag(player)
	check("6-2 넘친 7개 = 넘침 보관함(소멸 0 · 들어온 순서 그대로) · 보석함 = 칸 수", #cs.gemInventory == cap and over == 7 and #cs.gemOverflow == 7 and cs.gemOverflow[1].itemLevel == cap + 1 and cs.gemOverflow[7].itemLevel == cap + 7 and cs.gemInventory[cap].itemLevel == cap,
		("%d · %d"):format(#cs.gemInventory, #cs.gemOverflow))
	table.remove(cs.gemInventory, 1); table.remove(cs.gemInventory, 1)
	PP.settleGemBag(player)
	check("6-3 자리 2칸 = 보관함 앞(가장 오래된 것)부터 저절로 들어옴", #cs.gemInventory == cap and #cs.gemOverflow == 5 and cs.gemInventory[cap].itemLevel == cap + 2, tostring(cs.gemInventory[cap].itemLevel))
	-- 가방 확장(구매 출처)하면 보석함도 같이
	p.purchases.bagSources.starter = true
	local cap2 = PP.inventoryCapacity(p)
	PP.settleGemBag(player)
	check("6-4 가방 확장(스타터 +20) = 보석함 칸도 같이 · 보관함 비워짐(남은 5개 들어옴)", cap2 > cap and #cs.gemInventory == cap + 5 and #cs.gemOverflow == 0, ("%d → %d"):format(cap, cap2))
	-- 분해: 보석함 + 보관함 가득 = 막음(가방 장비 그대로) · 자리 있으면 됨
	cs.gemInventory, cs.gemOverflow = {}, {}
	for i = 1, cap2 do table.insert(cs.gemInventory, gem(i)) end
	for i = 1, GemData.gemBag.overflowMax do table.insert(cs.gemOverflow, gem(1000 + i)) end
	p.inventory = { { id = "d1", grade = "epic", part = "armor", tierIndex = 1, dropStage = 100, itemLevel = 100, option = { id = OPT, roll = 1 } } }
	local okFull, why = PP.dismantleItem(player, 1)
	check("6-5 보석함 + 넘침 보관함(200) 가득 = 분해 막음(gem_full · 장비 그대로)", not okFull and why == "gem_full" and #p.inventory == 1, tostring(why))
	local nBulk, whyBulk = PP.dismantleItemsUpTo(player, "epic")
	check("6-6 일괄 분해도 막음(일부만 하지 않음)", nBulk == 0 and whyBulk == "gem_full" and #p.inventory == 1)
	table.remove(cs.gemOverflow)
	local okRoom = PP.dismantleItem(player, 1)
	check("6-7 보관함 한 칸 비면 분해 됨 · 새 보석 = 보관함 끝", okRoom and #p.inventory == 0 and #cs.gemOverflow == GemData.gemBag.overflowMax)
	-- 저장 v80
	local d = SaveSystem.defaultProfile()
	d.version = 79
	for _, c in pairs(d.classes) do c.gemOverflow = nil end
	local m = SaveSystem.migrate(d)
	local all = true
	for _, c in pairs(m.classes) do all = all and type(c.gemOverflow) == "table" end
	check("6-8 저장 v80: 직업마다 gemOverflow = {}(추가만) · 새 계정 기본값", m.version == 80 and all and type(SaveSystem.defaultProfile().classes.bow.gemOverflow) == "table")
	local bad = SaveSystem.defaultProfile()
	bad.classes.bow.gemOverflow = { { grade = "relic", itemLevel = 1, option = { id = "nope_option" } } }
	check("6-9 보관함 모양 검사(모르는 옵션 = 손상 판정 · 보석함과 같은 규칙)", not SaveSystem.isValidProfile(bad))
	-- 저장 크기: 가방 최대(80) + 보석함 80 + 보관함 200(직업 하나 = 캐릭터 키 · 옛 단일 키는 4직업 모두)
	local big = SaveSystem.defaultProfile()
	big.classId = "greatsword"
	big.purchases.bagSources.starter = true
	big.gamepasses.bagExpand = true
	local bagMax = MODS.InventorySync.maxCapacity(big)
	for i = 1, bagMax do
		big.inventory[i] = { grade = "transcendent", dropStage = 25300, locked = true, itemLevel = 25300, part = "armor", option = { id = OPT, roll = 0.987654321 }, source = { kind = "boss_first_clear", stage = 25300, at = 1789000000 }, setZone = "tier6", skillVariant = "v3", primordial = { world = 123456, at = 1789000000 } }
	end
	for _, c in pairs(big.classes) do
		c.gemInventory, c.gemOverflow = {}, {}
		for i = 1, bagMax do table.insert(c.gemInventory, { grade = "transcendent", itemLevel = 25300, option = { id = OPT, roll = 0.987654321, roll2 = 0.912345678 } }) end
		for i = 1, GemData.gemBag.overflowMax do table.insert(c.gemOverflow, { grade = "transcendent", itemLevel = 25300, option = { id = OPT, roll = 0.987654321, roll2 = 0.912345678 } }) end
	end
	local LIMIT = 4 * 1024 * 1024
	local chData = MODS.SlotSave.extractCharacter(big, "greatsword")
	local sizeChar = jsonSize({ charId = 1, classId = "greatsword", data = chData })
	local sizeLegacy = jsonSize(big)
	check("6-10 저장 크기: 캐릭터 키(가방 · 보석함 최대 + 보관함 가득) · 옛 단일 키(4직업 모두 가득) ≤ 4MB × 25%", sizeChar <= LIMIT * 0.25 and sizeLegacy <= LIMIT * 0.25,
		("가방 %d칸 · 캐릭터 키 %d자(%.2f%% · 여유 %.1f%%) · 옛 단일 키 %d자(%.2f%% · 여유 %.1f%%)"):format(bagMax, sizeChar, sizeChar / LIMIT * 100, 100 - sizeChar / LIMIT * 100, sizeLegacy, sizeLegacy / LIMIT * 100, 100 - sizeLegacy / LIMIT * 100))
end)
if not ok then
	print("[GEMBAG] 하네스 에러 " .. tostring(err))
end
print(("[GEMBAG] 끝 %d/%d"):format(pass, total))
