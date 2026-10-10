Random = { new = function(seed) math.randomseed(seed or 1); return { NextInteger = function(_, a, b) return math.random(a, b) end, NextNumber = function(_, a, b) a = a or 0; b = b or 1; return a + math.random() * (b - a) end } end }
-- SEC-FIX-1 14 보석 [빼기] 재현 하네스(실제 PlayerProfile · GemEquip · TranscendService). 옛 코드 = 빼기 없음(GemEquip.unequip nil → X).
-- 실행: LUAU=<luau.exe> PRELUDE=server_prelude.luau EXTRA_SERVER=$(python deps.py PlayerProfile,PetService,QuestService,SaveSystem,GemEquip,TranscendService) ECON_RES=res_secgem.txt python build_run.py sec_gem_test.luau
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then pass += 1 end
	print(("[SECGEM] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end
local ok, err = pcall(function()
	local SaveSystem, PlayerProfile, Gem, GemEquip = MODS.SaveSystem, MODS.PlayerProfile, MODS.Gem, MODS.GemEquip
	local attrs = {}
	local player = setmetatable({ Name = "GemOut", UserId = 91, Parent = true }, { __index = function(_, k)
		if k == "SetAttribute" then return function(_, n, v) attrs[n] = v end end
		if k == "GetAttribute" then return function(_, n) return attrs[n] end end
		if k == "FindFirstChild" or k == "WaitForChild" or k == "FindFirstChildOfClass" then return function() return nil end end
		if k == "IsA" then return function() return false end end
		if k == "GetAttributeChangedSignal" then return function() return { Connect = function() end } end end
		return nil
	end })
	PlayerProfile.init(player, SaveSystem.migrate({}))
	PlayerProfile.setClassId(player, "bow")
	local p = PlayerProfile.getProfile(player)
	local cs = p.classes.bow
	cs.weapon.slotUnlocked = cs.weapon.slotUnlocked or {}
	for s = 1, Gem.slotCount do cs.weapon.slotUnlocked[s] = true end
	local gem = Gem.buildGrantedGem(1, "bow", 120)
	cs.weapon.gems[1] = { grade = gem.grade, itemLevel = gem.itemLevel, option = gem.option }
	cs.gemInventory = {}
	local unequip = GemEquip.unequip or function() return false, "no_unequip" end
	local optId = gem.option and gem.option.id
	local bonus0 = optId and PlayerProfile.getOptionBonus(player, optId) or 0

	local ok1, why1 = unequip(player, 1)
	check("14 빼기 → 보석함 +1 · 홈 빈칸 · 무료(골드 그대로)(옛 = 빼기 없음)", ok1 == true and #cs.gemInventory == 1 and not Gem.isFilled(cs.weapon.gems, 1) and p.gold == 0, tostring(why1))
	local moved = cs.gemInventory[1]
	check("14 100% 보존(등급 · 레벨 · 옵션 그대로)", moved and moved.grade == gem.grade and moved.itemLevel == gem.itemLevel and moved.option and gem.option and moved.option.id == gem.option.id and moved.option.roll == gem.option.roll)
	local okEq = GemEquip.handle(player, 1, 1)
	local bonus1 = optId and PlayerProfile.getOptionBonus(player, optId) or 0
	check("14 빼고 다시 끼우기 → 능력치 원래대로", okEq and math.abs(bonus1 - bonus0) < 1e-9 and #cs.gemInventory == 0, ("%s → %s"):format(tostring(bonus0), tostring(bonus1)))

	-- 연타 10번 → 1개만(두 번째부터 = 빈 홈)
	local okN, emptyN = 0, 0
	for _ = 1, 10 do
		local okX, whyX = unequip(player, 1)
		if okX then okN += 1 elseif whyX == "empty" then emptyN += 1 end
	end
	check("14 같은 홈 연타 10번 → 1개만 옮김 · 나머지 empty(복제 0)", okN == 1 and emptyN == 9 and #cs.gemInventory == 1, ("성공 %d · 빈 홈 %d · 보석함 %d"):format(okN, emptyN, #cs.gemInventory))

	-- 보석함이 아주 많아도 = 소멸 0(PROG-2B-1 6: 칸 수를 넘은 몫은 넘침 보관함)
	GemEquip.handle(player, 1, 1)
	for i = 1, 1000 do
		table.insert(cs.gemInventory, { grade = "epic", itemLevel = i, option = gem.option })
	end
	local before = #cs.gemInventory
	local okBig = unequip(player, 1)
	local overN = type(cs.gemOverflow) == "table" and #cs.gemOverflow or 0 -- PROG-2B-1 6: 보석함 상한 = 가방 칸 수 · 넘친 몫 = 넘침 보관함(소멸 0)
	check("14 보석함 1,000개 + 빼기 = 보석함(칸 수) + 넘침 보관함 합이 그대로 +1(소멸 0 · PROG-2B-1 6)", okBig == true and #cs.gemInventory + overN == before + 1 and #cs.gemInventory <= MODS.PlayerProfile.inventoryCapacity(p)
		and not Gem.isFilled(cs.weapon.gems, 1), ("%d → 보석함 %d + 보관함 %d"):format(before, #cs.gemInventory, overN))
	cs.gemInventory, cs.gemOverflow = {}, {}

	-- 잘못된 홈 · 빈 홈 · 표 모양
	local a, wa = unequip(player, 0)
	local b, wb = unequip(player, 99)
	local c, wc = unequip(player, "1")
	check("14 잘못된 홈(0 · 99 · 문자열) = 거절 · 아무 변화 없음", not a and not b and not c and #cs.gemInventory == 0, ("%s · %s · %s"):format(tostring(wa), tostring(wb), tostring(wc)))

	-- 초월 보석 사본(D16): 빼기 = 계정 목록으로(보석함 X · 복제 0)
	p.transcendGems = p.transcendGems or { list = {}, seq = 0 }
	table.insert(p.transcendGems.list, { id = "TGX", grade = "transcendent", itemLevel = 200, option = gem.option, socket = { classId = "bow", slot = 1 } })
	cs.weapon.gems[1] = { grade = "transcendent", itemLevel = 200, option = gem.option, transcendGemId = "TGX" }
	local okT, kindT = unequip(player, 1)
	local tg = p.transcendGems.list[#p.transcendGems.list]
	check("14 초월 보석(D16) = 계정 목록으로(socket 풀림) · 보석함 안 늚 · 홈 빈칸", okT == true and kindT == "transcend" and tg.socket == nil and #cs.gemInventory == 0 and not Gem.isFilled(cs.weapon.gems, 1), tostring(kindT))
	-- 저장 왕복: 빼기 뒤 저장 → 다시 읽어도 보석함 1 · 홈 빈칸(같은 캐릭터 키 · 한 번의 저장)
	cs.weapon.gems[1] = { grade = gem.grade, itemLevel = gem.itemLevel, option = gem.option }
	unequip(player, 1)
	local mig = SaveSystem.migrate(SaveSystem.migrate(p))
	check("14 저장 왕복(이관 두 번) = 보석함 1 · 홈 빈칸 그대로(증발 · 복제 0)", #mig.classes.bow.gemInventory == 1 and not Gem.isFilled(mig.classes.bow.weapon.gems, 1))
end)
if not ok then print("[SECGEM] 에러 " .. tostring(err)) end
print(("[SECGEM] 끝 %d/%d"):format(pass, total))
