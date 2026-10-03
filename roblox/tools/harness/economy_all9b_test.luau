-- QUEUE-ALL9B 경제 · 시즌 하네스: 판매가(1) · 수련 50단계(2) · 꾸미기 토큰(3) · 시즌 패스 가치(4) · 출석판(5).
--   실제 shared 모듈(Loot · GemCraft · Training · Monetization · SeasonPassData · CodexRules …)만 쓴다(서버 의존 없음).
--   실행: LUAU=<luau.exe> ECON_RES=res_all9b.txt python build_run.py economy_all9b_test.luau
local Loot, GemCraft, ArmorData = MODS.Loot, MODS.GemCraft, MODS.ArmorData
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	pass += ok and 1 or 0
	print(("[ALL9B] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end

-- ══ 1 판매가 ══
local GRADES = { "normal", "rare", "epic", "legendary", "relic", "ancient", "primordial" }
local STAGES = { 1, 5, 10, 40, 100, 400, 1000, 5000, 25300 }
do
	local bad = {}
	for tier = 1, 6 do
		for _, stage in ipairs(STAGES) do
			local prev
			for _, g in ipairs(GRADES) do
				local p = Loot.getSellPrice({ grade = g, tierIndex = tier, dropStage = stage, itemLevel = stage })
				if p <= 0 or (prev and p < prev) or (prev and (g == "rare" or g == "epic") and p <= prev) then
					table.insert(bad, ("T%d s%d %s=%d(앞 %s)"):format(tier, stage, g, p, tostring(prev)))
				end
				prev = p
			end
		end
	end
	check("1-2 등급 순서(일반 < 희귀 < 영웅 ≤ … ≤ 태초 · 0 없음) 6티어 × 9스테이지", #bad == 0, table.concat(bad, ", "))
	check("1-2 초월 판매가 0", Loot.getSellPrice({ grade = "transcendent", tierIndex = 6, dropStage = 100 }) == 0)
end
do
	local bad, dustWins = {}, {}
	for _, stage in ipairs(STAGES) do
		for _, g in ipairs({ "epic", "legendary", "relic", "ancient", "primordial" }) do
			local tier = math.clamp(1 + math.floor(stage / 200), 1, 6)
			local sell = Loot.getSellPrice({ grade = g, tierIndex = tier, dropStage = stage, itemLevel = stage })
			local gem = { grade = g, itemLevel = stage }
			if sell < GemCraft.sellPrice(gem, stage) then
				table.insert(bad, ("%s s%d 판매 %d < 보석 판매 %d"):format(g, stage, sell, GemCraft.sellPrice(gem, stage)))
			end
			if GemCraft.dustGoldValue(gem, stage) > sell then
				dustWins[g] = (dustWins[g] or 0) + 1
			end
		end
	end
	check("1-3 영웅 이상 바로 판매 ≥ 분해 → 보석 판매(같은 골드 - 바로 팔기가 늘 손해이던 역전 없음)", #bad == 0, table.concat(bad, ", "))
	local all = true
	for _, g in ipairs({ "epic", "legendary", "relic" }) do
		all = all and (dustWins[g] or 0) > 0
	end
	check("1-3 영웅 · 전설 · 유물: 분해 가루 가치 > 판매가인 스테이지가 있음(가루가 필요하면 분해)", all)
end
do
	-- 사용자 예: 스테이지 40 장비 16개(T1 등급표 기대 - 일반 · 희귀 · 영웅 몫)
	local function sixteen()
		local row = MODS.DropTable.gradeRow(1)
		local sum, n = 0, 0
		for _, g in ipairs({ "normal", "rare", "epic" }) do
			sum += (row[g] or 0) * Loot.getSellPrice({ grade = g, tierIndex = 1, dropStage = 40, itemLevel = 40 })
			n += row[g] or 0
		end
		return sum / n * 16
	end
	local after = sixteen()
	local scale, floor = ArmorData.sellGoldScale, ArmorData.sellFloorGemSell
	ArmorData.sellGoldScale, ArmorData.sellFloorGemSell = 1, false
	local before = sixteen()
	ArmorData.sellGoldScale, ArmorData.sellFloorGemSell = scale, floor
	check("1-4 스테이지 40 장비 16개(T1 일반 · 희귀 · 영웅 기대 섞임) 판매 전 → 후 ×3 이상", after >= before * 3, ("%.0f → %.0f골드"):format(before, after))
end

-- ══ 끝 ══
print(("===ALL9B 끝 %d/%d"):format(pass, total))
