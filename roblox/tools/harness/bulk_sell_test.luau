-- QUEUE-ALL9C 1-9 등급 체크 일괄 판매 검증(75칸 가득): 체크한 등급만 · 잠금 · 스킬 변형 · 착용 제외 · 전설 이상은 어떤 조합으로도 안 팔림 ·
--   확인 창(클라 S.bulkSellEstimate = Loot.isBulkSellTarget + getSellPrice)과 서버 결과 개수 · 골드 일치 · 확인 뒤 가방이 바뀌면 거부 · 연타 두 번째 0.
Random = { new = function(seed) math.randomseed(seed or 1); return { NextInteger = function(_, a, b) return math.random(a, b) end, NextNumber = function(_, a, b) a = a or 0; b = b or 1; return a + math.random() * (b - a) end } end }
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then pass += 1 end
	print(("[BULK] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end
local ok, err = pcall(function()
	local SaveSystem, PlayerProfile, Loot, ArmorData = MODS.SaveSystem, MODS.PlayerProfile, MODS.Loot, MODS.ArmorData
	local InventorySync = MODS.InventorySync
	local attrs = {}
	local player = setmetatable({ Name = "Bulk", UserId = 77, Parent = true }, { __index = function(_, k)
		if k == "SetAttribute" then return function(_, n, v) attrs[n] = v end end
		if k == "GetAttribute" then return function(_, n) return attrs[n] end end
		if k == "FindFirstChild" or k == "WaitForChild" or k == "FindFirstChildOfClass" then return function() return nil end end
		if k == "IsA" then return function() return false end end
		if k == "GetAttributeChangedSignal" then return function() return { Connect = function() end } end end
		return nil
	end })
	local profile = SaveSystem.migrate({})
	profile.tutorial = profile.tutorial or {}
	profile.tutorial.completed = true
	PlayerProfile.init(player, profile)
	PlayerProfile.setClassId(player, "bow")
	local p = PlayerProfile.getProfile(player)
	-- 75칸: 확장 패스 + 스타터 출처
	p.gamepasses = p.gamepasses or {}
	p.gamepasses.bagExpand = true
	p.purchases.bagSources.starter = true
	local cap = InventorySync.capacity(p)
	check("가방 75칸(기본 35 + 패스 20 + 스타터 20)", cap == 75, tostring(cap))

	local PARTS = { "armor", "gloves", "shoes" }
	local function fill()
		local inv = {}
		for i = 1, 75 do
			local grade = ArmorData.gradeOrder[(i - 1) % #ArmorData.gradeOrder + 1]
			table.insert(inv, { grade = grade, part = PARTS[(i - 1) % 3 + 1], itemLevel = 5 + i, dropStage = 10 + i * 7, tierIndex = 1 + (i % 6),
				locked = (i % 7 == 0) or nil, skillVariant = (i % 11 == 0) and "x" or nil })
		end
		p.inventory = inv
	end
	local function estimate(set) -- 클라 확인 창(Store.bulkSellEstimate)과 같은 계산
		local n, g = 0, 0
		for _, it in ipairs(p.inventory) do
			if Loot.isBulkSellTarget(it, set) then
				n += 1
				g += Loot.getSellPrice(it)
			end
		end
		return n, g
	end
	local function independent(set) -- 함수와 무관한 손 계산(조건을 직접 적음)
		local n = 0
		for _, it in ipairs(p.inventory) do
			if set[it.grade] and not it.locked and not it.skillVariant then
				n += 1
			end
		end
		return n
	end
	local cs = p.classes[p.classId]
	local equipSnapshot = {}
	for slot, it in pairs(cs.equipment or {}) do
		equipSnapshot[slot] = it
	end

	-- ① 체크 조합 7가지(일반 · 희귀 · 영웅의 공집합 아닌 부분집합) × 75칸
	local G = ArmorData.bulkSellGrades
	local allOk, rows = true, {}
	for mask = 1, bit32.lshift(1, #G) - 1 do
		fill()
		local set, list = {}, {}
		for i, id in ipairs(G) do
			if bit32.band(bit32.rshift(mask, i - 1), 1) == 1 then
				set[id] = true
				table.insert(list, id)
			end
		end
		local n, g = estimate(set)
		local gold0 = p.gold
		local sold, gold = PlayerProfile.sellItemsByGrades(player, list, n)
		local leftBad, highLeft = 0, 0
		for _, it in ipairs(p.inventory) do
			if Loot.isBulkSellTarget(it, set) then
				leftBad += 1
			end
		end
		for i = 1, 75 do -- 원래 가방의 전설 이상은 전부 남았나
			local grade = ArmorData.gradeOrder[(i - 1) % #ArmorData.gradeOrder + 1]
			local idx = table.find(ArmorData.gradeOrder, grade)
			if idx > table.find(ArmorData.gradeOrder, ArmorData.bulkSellMaxGrade) - 1 then
				highLeft += 1
			end
		end
		local highNow = 0
		for _, it in ipairs(p.inventory) do
			if table.find(ArmorData.gradeOrder, it.grade) >= table.find(ArmorData.gradeOrder, "legendary") then
				highNow += 1
			end
		end
		local good = sold == n and  gold == g and p.gold - gold0 == g and leftBad == 0 and #p.inventory == 75 - n and highNow == highLeft
		allOk = allOk and good
		table.insert(rows, ("%s=%d개/%d골드%s"):format(table.concat(list, "+"), sold, gold or 0, good and "" or "(X)"))
	end
	check("체크 조합 7가지 × 75칸: 확인 창 개수 · 골드 = 서버 판매 · 손 계산 · 남은 가방에 대상 0 · 전설 이상 전부 남음", allOk, table.concat(rows, " · "))
	-- 손 계산과 확인 창이 같은지(체크 조합 하나 - 위 good 식의 independent 비교는 판매 뒤라 판매 전 다시)
	fill()
	local setNR = { normal = true, rare = true }
	local nEst = estimate(setNR)
	check("확인 창 개수 = 조건 직접 계산(일반 + 희귀 · 잠금 · 스킬 변형 제외)", nEst == independent(setNR), ("%d = %d"):format(nEst, independent(setNR)))

	-- ② 잠금 · 스킬 변형 남음 · 착용 그대로
	fill()
	local lockedBefore, variantBefore = 0, 0
	for _, it in ipairs(p.inventory) do
		lockedBefore += it.locked and 1 or 0
		variantBefore += it.skillVariant and 1 or 0
	end
	local nAll = estimate({ normal = true, rare = true, epic = true })
	PlayerProfile.sellItemsByGrades(player, { "normal", "rare", "epic" }, nAll)
	local lockedAfter, variantAfter = 0, 0
	for _, it in ipairs(p.inventory) do
		lockedAfter += it.locked and 1 or 0
		variantAfter += it.skillVariant and 1 or 0
	end
	local equipSame = true
	for slot, it in pairs(cs.equipment or {}) do
		equipSame = equipSame and equipSnapshot[slot] == it
	end
	check("잠금 · 스킬 변형 장비 전부 남음 · 착용 장비 그대로", lockedAfter == lockedBefore and variantAfter == variantBefore and equipSame,
		("잠금 %d → %d · 스킬 변형 %d → %d"):format(lockedBefore, lockedAfter, variantBefore, variantAfter))

	-- ③ 서버 재검증: 확인 뒤 가방이 바뀜(1개 주움) = 거부 · 연타 두 번째 0 · 전설 · 겹침 · 모르는 등급 = 거부
	fill()
	local n1 = estimate(setNR)
	table.remove(p.inventory) -- 75 → 74 후 대상 하나 추가(확인 창이 뜬 사이 주움)
	table.insert(p.inventory, { grade = "normal", part = "armor", itemLevel = 9, dropStage = 99, tierIndex = 1 })
	local nNow = estimate(setNR)
	local gold0 = p.gold
	local s1, _, why1 = PlayerProfile.sellItemsByGrades(player, { "normal", "rare" }, n1)
	local mismatchOk = (nNow == n1 and s1 == n1) or (nNow ~= n1 and s1 == 0 and why1 == "count_mismatch" and p.gold == gold0)
	local s2 = PlayerProfile.sellItemsByGrades(player, { "normal", "rare" }, nNow)
	local s3 = PlayerProfile.sellItemsByGrades(player, { "normal", "rare" }, nNow)
	check("확인 뒤 가방 바뀜 = 거부(골드 그대로) · 새 개수로 다시 = 판매 · 같은 요청 두 번째 = 0", mismatchOk and s2 == nNow and s3 == 0,
		("확인 %d · 지금 %d · 1회 %d(%s) · 2회 %d · 3회 %d"):format(n1, nNow, s1, tostring(why1), s2, s3))
	fill()
	local r1 = { PlayerProfile.sellItemsByGrades(player, { "legendary" }, 1) }
	local r2 = { PlayerProfile.sellItemsByGrades(player, { "normal", "normal" }, 1) }
	local r3 = { PlayerProfile.sellItemsByGrades(player, { "mythic" }, 1) }
	local r4 = { PlayerProfile.sellItemsByGrades(player, { "normal", "rare", "epic", "legendary" }, 1) }
	check("전설 · 겹침 · 모르는 등급 · 네 개 = 거부(가방 75 그대로)", r1[1] == 0 and r2[1] == 0 and r3[1] == 0 and r4[1] == 0 and #p.inventory == 75,
		("%s · %s · %s · %s"):format(tostring(r1[3]), tostring(r2[3]), tostring(r3[3]), tostring(r4[3])))

	-- ④ QUEUE-ALL9C 1-10 분해 안내 = 서버가 실제로 넣는 보석(한 개 · 일괄)
	do
		local gems = p.classes[p.classId].gemInventory
		p.inventory = { { grade = "epic", part = "armor", itemLevel = 37, dropStage = 200, tierIndex = 3, option = { stat = "crit", value = 5 } } }
		local want = Loot.dismantleReward(p.inventory[1])
		local before = #gems
		PlayerProfile.dismantleItem(player, 1)
		local got = gems[#gems]
		local one = #gems == before + 1 and got.grade == want.grade and got.itemLevel == want.itemLevel and got.option == want.option
		fill()
		local expect, expGrades = 0, {}
		for _, it in ipairs(p.inventory) do
			if Loot.isBulkDismantleTarget(it, "legendary") then
				expect += 1
				local g = Loot.dismantleReward(it).grade
				expGrades[g] = (expGrades[g] or 0) + 1
			end
		end
		local b2 = #gems
		local n = PlayerProfile.dismantleItemsUpTo(player, "legendary")
		local gotGrades = {}
		for i = b2 + 1, #gems do
			gotGrades[gems[i].grade] = (gotGrades[gems[i].grade] or 0) + 1
		end
		local same = n == expect
		for g, c in pairs(expGrades) do
			same = same and gotGrades[g] == c
		end
		check("분해 안내(Loot.dismantleReward) = 서버 결과: 한 개(등급 · 레벨 · 옵션) · 일괄(개수 · 등급별)", one and same, ("한 개 %s · 일괄 %d = %d"):format(tostring(one), n, expect))
	end
	do -- QUEUE-N1004 A-1 줍는 순간 자동 정리: 태초 · 초월은 어떤 설정(기준 등급 × 방식 × 잠금 × 출처)에서도 처리 안 됨 · 유물 이상 · 잠금 · 보스 세트 제외 · 방식(판매/분해)
		p.autoProcess = { enabled = true, maxGrade = "epic" }
		p.settings = p.settings or {}
		local leaks, cases = 0, 0
		for _, maxGrade in ipairs({ "normal", "rare", "epic", "legendary", "relic", "ancient", "primordial", "transcendent", "off" }) do
			for _, mode in ipairs({ "sell", "dismantle" }) do
				for _, locked in ipairs({ false, true }) do
					for _, kind in ipairs({ "field", "boss", "sparkle" }) do
						for _, grade in ipairs({ "primordial", "transcendent" }) do
							cases += 1
							p.autoProcess = { enabled = true, maxGrade = maxGrade }
							p.settings.autoProcessMode = mode
							local item = { grade = grade, part = "armor", itemLevel = 50, dropStage = 900, tierIndex = 6, locked = locked, source = { kind = kind, zone = "tier1" } }
							if Loot.isAutoProcessTarget(item, maxGrade) or PlayerProfile.autoProcessDrop(player, item) ~= nil then
								leaks += 1
							end
						end
					end
				end
			end
		end
		check("자동 정리: 태초 · 초월 = 어떤 설정에서도 처리 안 됨", leaks == 0, ("%d경우 중 새는 것 %d"):format(cases, leaks))
		local function drop(grade, extra)
			local item = { grade = grade, part = "gloves", itemLevel = 30, dropStage = 300, tierIndex = 3, source = { kind = "field", zone = "tier2" }, option = grade ~= "normal" and grade ~= "rare" and { stat = "crit", value = 3 } or nil }
			for k, v in pairs(extra or {}) do
				item[k] = v
			end
			return item
		end
		p.autoProcess = { enabled = true, maxGrade = "epic" }
		local relicKept = PlayerProfile.autoProcessDrop(player, drop("relic")) == nil and PlayerProfile.autoProcessDrop(player, drop("legendary")) == nil
		local lockedKept = PlayerProfile.autoProcessDrop(player, drop("normal", { locked = true })) == nil
		local bossKept = PlayerProfile.autoProcessDrop(player, drop("normal", { source = { kind = "boss", bossId = "x" } })) == nil
		local variantKept = PlayerProfile.autoProcessDrop(player, drop("rare", { skillVariant = "v1" })) == nil
		p.settings.autoProcessMode = "dismantle"
		local d = PlayerProfile.autoProcessDrop(player, drop("epic"))
		local n = PlayerProfile.autoProcessDrop(player, drop("normal"))
		p.settings.autoProcessMode = "sell"
		local sEpic = PlayerProfile.autoProcessDrop(player, drop("epic"))
		p.settings.autoProcessMode = nil -- 옛 저장(키 없음) = 기본 dismantle = G1-2 옛 동작
		local old = PlayerProfile.autoProcessDrop(player, drop("epic"))
		p.autoProcess = { enabled = true, maxGrade = "normal" }
		local above = PlayerProfile.autoProcessDrop(player, drop("rare")) == nil
		p.autoProcess = { enabled = false, maxGrade = "epic" }
		local off = PlayerProfile.autoProcessDrop(player, drop("normal")) == nil
		check("자동 정리 제외(유물 · 전설 · 잠금 · 보스 세트 · 스킬 변형 · 기준 위 · 끔)", relicKept and lockedKept and bossKept and variantKept and above and off,
			("%s %s %s %s %s %s"):format(tostring(relicKept), tostring(lockedKept), tostring(bossKept), tostring(variantKept), tostring(above), tostring(off)))
		check("자동 정리 방식: 분해 = 영웅 보석 · 일반 판매 / 판매 = 영웅도 골드 / 키 없음 = 분해(옛 동작)",
			d and d.kind == "dismantle" and n and n.kind == "sell" and n.gold > 0 and sEpic and sEpic.kind == "sell" and sEpic.gold == Loot.getSellPrice(drop("epic")) and old and old.kind == "dismantle",
			("%s %s %s %s"):format(d and d.kind or "nil", n and n.kind or "nil", sEpic and sEpic.kind or "nil", old and old.kind or "nil"))
	end
end)
if not ok then print("[BULK] 에러 " .. tostring(err)) end
-- QUEUE-ALL10 0-5(결정 5): 첫 가득 참 안내 [켜기] 기본 = 희귀 이하(서버가 받는 선택지 안) · 태초 · 초월은 희귀 기준에서도 제외
local ok5, err5 = pcall(function()
	local ArmorData, Loot = MODS.ArmorData, MODS.Loot
	local def = ArmorData.autoProcessHintDefault
	local function item(g) return { id = "x", grade = g, part = "armor", stats = {} } end
	check("ALL10 0-5 첫 안내 기본 = rare(선택지 안) · 희귀 O · 영웅 X · 태초 · 초월 X", def == "rare" and table.find(ArmorData.autoProcessGradeChoices, def) ~= nil
		and Loot.isAutoProcessTarget(item("rare"), def) and not Loot.isAutoProcessTarget(item("epic"), def)
		and not Loot.isAutoProcessTarget(item("primordial"), def) and not Loot.isAutoProcessTarget(item("transcendent"), def), tostring(def))
end)
if not ok5 then print("[BULK] 에러 " .. tostring(err5)) end
print(("[BULK] 끝 %d/%d"):format(pass, total))
