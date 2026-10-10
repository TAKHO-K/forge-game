-- SEC-FIX-1 7 보석 판매가 차익(AUDIT1 #7 · #8) · 일괄 분해 개수 불일치(#10) 재현 하네스(실제 PlayerProfile · Loot · GemCraft).
-- 실행: LUAU=<luau.exe> PRELUDE=server_prelude.luau EXTRA_SERVER=$(python deps.py PlayerProfile,PetService,QuestService,SaveSystem,MonetizationService,InventorySync) ECON_RES=res_sececon.txt python build_run.py sec_econ_test.luau
-- 옛 코드 실패 확인 = ECON_SRC=<옛 src>. 끝 줄 "[SECECON] 끝 n/m".
Random = { new = function(seed) math.randomseed(seed or 1); return { NextInteger = function(_, a, b) return math.random(a, b) end, NextNumber = function(_, a, b) a = a or 0; b = b or 1; return a + math.random() * (b - a) end } end }
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then pass += 1 end
	print(("[SECECON] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end
local ok, err = pcall(function()
	local SaveSystem, PlayerProfile, Loot, GemCraft, GemData = MODS.SaveSystem, MODS.PlayerProfile, MODS.Loot, MODS.GemCraft, MODS.GemData
	local attrs = {}
	local player = setmetatable({ Name = "Econ", UserId = 78, Parent = true }, { __index = function(_, k)
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
	local cs = p.classes.bow
	cs.stageProgress.infinite, cs.stageProgress.infiniteBest = 20000, 20000
	local best = PlayerProfile.getAccountBestStage(player)
	check("계정 최고 스테이지 = 20,000(고스테이지 계정)", best >= 20000, tostring(best))

	-- ═══ #7 · #8: 저스테이지에서 주운 영웅 → 바로 팔기 vs 분해 → 보석 판매(서버 sellGem) ═══
	local GRADES = { "epic", "legendary", "relic", "ancient" }
	local worst, rows = 0, {}
	for _, g in ipairs(GRADES) do
		for _, stage in ipairs({ 1, 10, 100, 1000 }) do
			local item = { grade = g, part = "armor", itemLevel = stage + 2, dropStage = stage, tierIndex = 1 }
			local direct = Loot.getSellPrice(item)
			cs.gemInventory = { Loot.dismantleReward(item) }
			local goldBefore = p.gold
			local okSell = PlayerProfile.sellGem(player, 1)
			local viaGem = p.gold - goldBefore
			if okSell and viaGem > direct then
				worst = math.max(worst, viaGem / math.max(direct, 1))
				table.insert(rows, ("%s s%d 바로 %d < 분해→판매 %d"):format(g, stage, direct, viaGem))
			end
		end
	end
	check("7 저스테이지 주운 장비(최고 20,000 계정): 분해 → 보석 판매 ≤ 바로 팔기(옛 = 계정 최고 스테이지 값 · 차익)", #rows == 0,
		("%d건 · 최대 %.0f배 · %s"):format(#rows, worst, table.concat(rows, " / ", 1, math.min(#rows, 3))))
	-- 같은 스테이지(정상 경로) = 둘이 같다(QUEUE-ALL9B 1-3 의도 그대로)
	local item = { grade = "epic", part = "armor", itemLevel = 500, dropStage = 500, tierIndex = 3 }
	cs.stageProgress.infiniteBest = 500
	cs.gemInventory = { Loot.dismantleReward(item) }
	local g0 = p.gold
	PlayerProfile.sellGem(player, 1)
	check("7 같은 스테이지 = 분해 → 판매 ≤ 바로 팔기(1-3 의도 유지)", p.gold - g0 <= Loot.getSellPrice(item), ("%d ≤ %d"):format(p.gold - g0, Loot.getSellPrice(item)))
	cs.stageProgress.infiniteBest = 20000

	-- ═══ 재련 경로: 판매가 상승 ≤ 먹이 판매가 + 재련 골드(가루는 공짜로 쳐도) ═══
	local bad = {}
	for _, t in ipairs(GRADES) do
		for _, f in ipairs(GRADES) do
			for _, lt in ipairs({ 1, 100, 1000 }) do
				for _, lf in ipairs({ 101, 1001, 5000, 20000 }) do
					if lf > lt then
						local target, fodder = { grade = t, itemLevel = lt }, { grade = f, itemLevel = lf }
						local gain = GemCraft.sellPrice(GemCraft.refinedGem(target, fodder), best) - GemCraft.sellPrice(target, best)
						local refineGold = GemCraft.refineCost(t, best)
						local cost = GemCraft.sellPrice(fodder, best) + refineGold
						if gain > cost then
							table.insert(bad, ("%s←%s L%d→%d 이득 %d > 비용 %d"):format(t, f, lt, lf, gain, cost))
						end
					end
				end
			end
		end
	end
	check("7 재련으로 레벨 올린 뒤 판매 = 이득 ≤ 먹이 판매가 + 재련 골드(4 × 4 등급 × 레벨 12쌍)", #bad == 0, ("%d건 %s"):format(#bad, table.concat(bad, " / ", 1, math.min(#bad, 3))))
	-- 보석 판매가 ≤ 가루 가치(분해가 기본 선택 - 규칙 유지)
	local dustBad = 0
	for _, g in ipairs(GRADES) do
		for _, l in ipairs({ 1, 100, 5000, 20000 }) do
			local gem = { grade = g, itemLevel = l }
			if GemCraft.sellPrice(gem, best) > GemCraft.dustGoldValue(gem, GemCraft.sellStage and GemCraft.sellStage(gem, best) or best) then
				dustBad += 1
			end
		end
	end
	check("7 보석 판매가 ≤ 같은 보석 가루 가치(분해가 기본)", dustBad == 0, tostring(dustBad))

	-- ═══ #10 일괄 분해 개수 대조 ═══
	local function heroes(n)
		local inv = {}
		for i = 1, n do
			table.insert(inv, { grade = "epic", part = "armor", itemLevel = 50 + i, dropStage = 50, tierIndex = 1 })
		end
		return inv
	end
	p.inventory = heroes(3)
	cs.gemInventory = {}
	local n1, why1 = PlayerProfile.dismantleItemsUpTo(player, "epic", 2) -- 확인 창 = 2개였는데 그 사이 1개 주움
	check("10 확인 창 2개 · 실제 3개 = 분해 0 · count_mismatch(옛 = 3개 다 분해 - 되돌릴 수 없음)", n1 == 0 and why1 == "count_mismatch" and #p.inventory == 3 and #cs.gemInventory == 0,
		("분해 %s · 이유 %s · 가방 %d · 보석 %d"):format(tostring(n1), tostring(why1), #p.inventory, #cs.gemInventory))
	local n2 = PlayerProfile.dismantleItemsUpTo(player, "epic", 3)
	check("10 개수 같음 = 그대로 분해(정상 경로)", n2 == 3 and #p.inventory == 0 and #cs.gemInventory == 3)
end)
if not ok then print("[SECECON] 하네스 에러 " .. tostring(err)) end
print(("[SECECON] 끝 %d/%d"):format(pass, total))
