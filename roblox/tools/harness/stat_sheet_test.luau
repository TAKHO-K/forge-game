-- QUEUE-ALL9C 1-2(C1) 상세 능력치 하네스: PlayerProfile.getStatSheet 합계 = 전투가 쓰는 값(getStatSummary · getCombatPower 인자) · 줄 = StatSheetData.rows · 출처 = StatSheetData.sources 안.
-- 실행: LUAU=<luau.exe> PRELUDE=server_prelude.luau EXTRA_SERVER=$(python deps.py PlayerProfile,PetService,QuestService,SaveSystem) ECON_RES=res_sheet.txt python build_run.py stat_sheet_test.luau
Random = { new = function(seed) math.randomseed(seed or 1); return { NextInteger = function(_, a, b) return math.random(a, b) end, NextNumber = function(_, a, b) a = a or 0; b = b or 1; return a + math.random() * (b - a) end } end }
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then pass += 1 end
	print(("[SHEET] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end
local function near(a, b)
	return math.abs(a - b) <= 1e-9 * math.max(1, math.abs(b))
end
local ok, err = pcall(function()
	local SaveSystem, PlayerProfile, Data = MODS.SaveSystem, MODS.PlayerProfile, MODS.StatSheetData
	local attrs = {}
	local player = setmetatable({ Name = "Sheet", UserId = 5151, Parent = true }, { __index = function(_, k)
		if k == "SetAttribute" then return function(_, n, v) attrs[n] = v end end
		if k == "GetAttribute" then return function(_, n) return attrs[n] end end
		if k == "FindFirstChild" or k == "WaitForChild" or k == "FindFirstChildOfClass" then return function() return nil end end
		if k == "IsA" then return function() return false end end
		if k == "GetAttributeChangedSignal" then return function() return { Connect = function() end } end end
		return nil
	end })
	local profile = SaveSystem.migrate({})
	profile.tutorial.completed = true
	PlayerProfile.init(player, profile)
	PlayerProfile.setClassId(player, "bow")
	local p = PlayerProfile.getProfile(player)
	local cs = p.classes.bow
	local function verify(label)
		local sheet = PlayerProfile.getStatSheet(player)
		local sum = PlayerProfile.getStatSummary(player)
		local byId = {}
		for _, row in ipairs(sheet.rows) do byId[row.id] = row end
		local class = MODS.ClassData.classes.bow
		local okRows = #sheet.rows == #Data.rows
		local srcOk = true
		for _, row in ipairs(sheet.rows) do
			for _, part in ipairs(row.parts) do
				srcOk = srcOk and table.find(Data.sources, part.source) ~= nil and (part.kind == "mult" or part.kind == "add" or part.kind == "flat")
			end
		end
		check(label .. ": 줄 = StatSheetData.rows · 출처 = sources 안", okRows and srcOk, ("%d줄"):format(#sheet.rows))
		check(label .. ": 공격력 · 방어 · 최대 체력 · 공속 = getStatSummary", near(byId.attack.total, sum.attack) and near(byId.defense.total, sum.defense) and near(byId.maxHp.total, sum.maxHp) and near(byId.attackSpeed.total, MODS.PlayerCombat.getSpeedMultiplier(sum.speedPercent)),
			("공격 %.6g/%.6g · 방어 %.6g/%.6g · 체력 %.6g/%.6g"):format(byId.attack.total, sum.attack, byId.defense.total, sum.defense, byId.maxHp.total, sum.maxHp))
		check(label .. ": 치명 확률 · 피해 = 직업 + getCritBonus", near(byId.critRate.total, class.critRate + sum.critRate) and near(byId.critDmg.total, class.critDmg + sum.critDmg))
		-- 더하기 몫 합 = 합계(공속 · 치명)
		local function addSum(row) local s = 0 for _, part in ipairs(row.parts) do if part.kind == "add" then s += part.value end end return s end
		check(label .. ": 공속 · 치명 확률 출처 합 = 합계", near(addSum(byId.attackSpeed), sum.speedPercent) and near(addSum(byId.critRate), byId.critRate.total), ("공속 몫 %.4g/%.4g · 치명 %.4g/%.4g"):format(addSum(byId.attackSpeed), sum.speedPercent, addSum(byId.critRate), byId.critRate.total))
		return byId
	end
	verify("맨몸")
	-- 장비 3부위 · 보석 · 강화 · 수련을 넣고 다시
	cs.equipment.armor = { id = "s1", part = "armor", grade = "epic", itemLevel = 300, tierIndex = 2, option = { id = "defensePercent", roll = 1, roll2 = 1 } }
	cs.equipment.gloves = { id = "s2", part = "gloves", grade = "legendary", itemLevel = 300, tierIndex = 2, option = { id = "attackPercent", roll = 1, roll2 = 1 } }
	cs.equipment.shoes = { id = "s3", part = "shoes", grade = "epic", itemLevel = 300, tierIndex = 2, option = { id = "speedPercent", roll = 1, roll2 = 1 } }
	cs.weapon.level = 22
	cs.weapon.grade = 3
	cs.weapon.gems[1] = { grade = "legendary", itemLevel = 300, option = { id = "crit", roll = 1, roll2 = 1 } }
	p.training.attack, p.training.hp, p.training.defense = 10, 10, 10
	local byId = verify("장비 · 보석 · +22 · 수련")
	local srcs = {}
	for _, part in ipairs(byId.attack.parts) do srcs[part.source] = true end
	check("공격력 출처에 기본 · 장비 · 강화 · 수련이 나뉘어 나옴", srcs.base and srcs.gear and srcs.enhance and srcs.training, "")
end)
if not ok then print("[SHEET] 하네스 에러 " .. tostring(err)) end
print(("[SHEET] 끝 %d/%d"):format(pass, total))
