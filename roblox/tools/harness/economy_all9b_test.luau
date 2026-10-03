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

-- ══ 2 수련 50단계 ══
do
	local Training, TrainingData, GoldCost, MonsterData = MODS.Training, MODS.TrainingData, MODS.GoldCost, MODS.MonsterData
	local ok, rows = true, {}
	for _, def in ipairs(TrainingData.stats) do
		ok = ok and def.maxLevel == 50 and Training.capFor(def, 1000) == 50 and Training.capFor(def, 999) == 49 and Training.capFor(def, 99999) == 50
	end
	check("2-1 공용 수련 최대 50단계 · 상한 = 최고 스테이지 ÷ 20(1,000 = 50)", ok)
	local atk = Training.statDef("attack")
	local rising = true
	for L = 1, 49 do
		rising = rising and Training.costFor(atk, L, 1000) > Training.costFor(atk, L - 1, 1000)
	end
	check("2-2 단계마다 가격이 오른다(스테이지 1,000 · 0 ~ 49)", rising)
	-- 단계별 표(스테이지 1,000 가격 · 몇 마리분 · 누적 효과)
	local k1 = GoldCost.cost(MonsterData.tier1.goldDrop, 1000, "training")
	local acc = 0
	for L = 0, 49 do
		acc += Training.costFor(atk, L, 1000)
		if (L + 1) % 10 == 0 then
			table.insert(rows, ("%d단 누적 %s골드(%.0f마리분) · 공격 +%.2f%% 체력 +%.1f%% 방어 +%.1f%%"):format(L + 1, tostring(acc), acc / k1,
				Training.bucketBonus({ attack = L + 1 }, {}, "bow", "attack") * 100, Training.bucketBonus({ hp = L + 1 }, {}, "bow", "hp") * 100, (Training.axisValues({ defense = L + 1 }, {}, "bow", "defensePercent") or { 0 })[1] * 100))
		end
	end
	for _, line in ipairs(rows) do
		print("[ALL9B] 2-2 표 " .. line)
	end
	local maxAtk = Training.bucketBonus({ attack = 50 }, {}, "bow", "attack")
	local maxHp = Training.bucketBonus({ hp = 50 }, {}, "bow", "hp")
	check("2-3 최대 효과 = 공격 +3.75% · 체력 +20% · 방어 +10%(상위 1% 관문이 정한 공격 상한)", math.abs(maxAtk - 0.0375) < 1e-9 and math.abs(maxHp - 0.2) < 1e-9
		and math.abs(Training.axisValues({ defense = 50 }, {}, "bow", "defensePercent")[1] - 0.1) < 1e-9)
	local gf = MODS.BossData.mechanics and MODS.BossData.mechanics.gimmickFail
	check("2-3 보스 = 실력: 기믹 실패 피해 = 최대 체력 비율(체력 수련으로 버틸 수 없음)", gf ~= nil and gf.maxHpFraction < 1 and gf.firstMaxHpFraction < 1, gf and ("%.2f · %.2f"):format(gf.firstMaxHpFraction, gf.maxHpFraction) or "nil")
end

-- ══ 3 꾸미기 토큰 ══
do
	local Mon, Data, Cos, CodexRules, CodexData = MODS.Monetization, MODS.MonetizationData, MODS.CosmeticSlotData, MODS.CodexRules, MODS.CodexData
	local TI = MODS.TextData_items
	check("3-1 표시 이름 = 꾸미기 토큰 / Style Token(id sparkleShard 그대로)", TI.ko["item.name.sparkleShard"] == "꾸미기 토큰" and TI.en["item.name.sparkleShard"] == "Style Token")
	local nests = {}
	for _, spec in ipairs(MODS.SecretNestData) do
		if spec.track == "C" and spec.sub ~= "village" and CodexData.zoneShort[spec.zone] then
			nests[spec.zone] = nests[spec.zone] or {}
			table.insert(nests[spec.zone], spec.id)
		end
	end
	local book = CodexRules.build(nests)
	local total = CodexRules.totalTokens(book)
	-- 도감 1칸 추가(몬스터 종 하나 더 = 칸 5 · 같은 줄) → 토큰 증가 = 칸 × 1.5
	local zone = MODS.WorldMapData.zones[1]
	local saved = zone.hunt.monsters
	local more = table.clone(saved)
	table.insert(more, { species = saved[1].species .. "_test" })
	zone.hunt.monsters = more
	local book2 = CodexRules.build(nests)
	zone.hunt.monsters = saved
	local delta = CodexRules.totalTokens(book2) - total
	local newCells = #book2.cells - #book.cells
	check("3-6 도감 칸 추가 = 토큰 자동 증가(칸 + 줄 완성)", newCells == 5 and delta >= newCells, ("칸 %d개 추가 → 토큰 +%d(칸당 %.1f) · 도감 총 토큰 %d"):format(newCells, delta, delta / math.max(newCells, 1), total))
	local prog = Mon.premiumTokenProgress(Data, 280)
	check("3-7 다음 499급까지(토큰 280) = 420 남음 · 40%", prog.price == 700 and prog.need == 420 and math.abs(prog.ratio - 0.4) < 1e-9)
	local blocked = {}
	for _, list in ipairs({ Cos.sets, Cos.gliderSkins, Cos.items }) do
		for _, e in ipairs(list) do
			if e.seasonOnly or e.passOnly or e.boardOnly then
				table.insert(blocked, e.id)
			end
		end
	end
	local leak = {}
	for key, product in pairs(Data.products) do
		for _, g in ipairs(product.grants) do
			if Mon.tokenBlocked(Cos, g.kind, g.id) then
				table.insert(leak, key)
			end
		end
	end
	check("3-5 토큰 불가 치장(시즌 한정 · 패스 · 출석판 전용)은 상품에 없음", #leak == 0, ("불가 %s · 새는 상품 %s"):format(table.concat(blocked, ","), table.concat(leak, ",")))
	local untok = {}
	for key, product in pairs(Data.products) do
		local g1 = product.grants[1] and product.grants[1].kind
		if (g1 == "cosmeticTheme" or g1 == "gliderSkin" or g1 == "cosmeticItem") and not Mon.productTokenPrice(Data, Cos, key) then
			table.insert(untok, key)
		end
	end
	check("3-5 모든 상점 치장 = 토큰으로도 살 수 있음", #untok == 0, table.concat(untok, ","))
	local ok, reasons = Mon.checkCatalog(Data, Cos, MODS.SeasonPassData)
	check("3-4 카탈로그 검사 통과(499급 묶음 tier premium 포함)", ok, table.concat(reasons, " / "))
end

-- ══ 4 시즌 패스(보완 지시) ══
do
	local Mon, Data, Cos, Season = MODS.Monetization, MODS.MonetizationData, MODS.CosmeticSlotData, MODS.SeasonPassData
	local v = Mon.passValue(Data, Season, Cos, 1)
	for _, it in ipairs(v.items) do
		print(("[ALL9B] 4 유료 치장 %d칸 %dR$"):format(it.tier, it.robux))
	end
	check("4-1 · 보완 3-2 유료 줄 가치 ×5 ~ 8 · 토큰 ≤ 20%", v.multiple >= 5 and v.multiple <= 8 and v.tokenShare <= 0.2,
		("치장 %dR$ + 토큰 %d개(%.0fR$) = %.0fR$ ÷ %d = ×%.2f · 토큰 %.1f%%"):format(v.cosmeticRobux, v.tokens, v.tokenRobux, v.total, v.price, v.multiple, v.tokenShare * 100))
	local ok, reasons, _, warnings = Mon.checkCatalog(Data, Cos, Season)
	check("4-5 카탈로그 · 패스 검사 통과 · 2시즌 대표 = 경고", ok and #warnings > 0 and warnings[1]:find("2시즌") ~= nil, table.concat(reasons, " / ") .. " | " .. table.concat(warnings, " / "))
	local s0 = Season.seasonLimited[1]
	Season.seasonLimited[1] = nil
	local ok1 = Mon.checkSeasonPass(Data, Season, Cos)
	Season.seasonLimited[1] = s0
	check("4-5 1시즌 대표가 비면 검사 실패", not ok1)
	local rows = Season.rowsFor(1)
	local badGold, early, paidGrowth = {}, { gold = false, stone = false }, {}
	for tier = 1, Season.tiers do
		local f, pr = rows.free[tier], rows.paid[tier]
		print(("[ALL9B] 4 표 %d칸 | 무료 %s | 유료 %s"):format(tier, MODS.Monetization.rewardToGrants and (function()
			local t = {}
			for _, g in ipairs(Mon.rewardToGrants(f)) do table.insert(t, g.kind .. "=" .. tostring(g.id or g.amount)) end
			return table.concat(t, ",")
		end)() or "", (function()
			local t = {}
			for _, g in ipairs(Mon.rewardToGrants(pr)) do table.insert(t, g.kind .. "=" .. tostring(g.id or g.amount)) end
			return table.concat(t, ",")
		end)()))
		if f.gold and f.gold % 100 ~= 0 then table.insert(badGold, tier) end
		if tier <= 10 then
			early.gold = early.gold or f.gold ~= nil
			early.stone = early.stone or f.enhanceStone ~= nil
		end
		for k in pairs(pr) do
			if Season.growthKinds[k] or k == "egg" then table.insert(paidGrowth, tier .. ":" .. k) end
		end
	end
	check("보완 2-1 · 6-3 무료 줄 골드 끝 00 · 1 ~ 10칸에 골드 · 강화석", #badGold == 0 and early.gold and early.stone, table.concat(badGold, ","))
	check("보완 ② 유료 줄 = 성장 재화 · 알 없음(판매 금지 검사 그대로)", #paidGrowth == 0, table.concat(paidGrowth, ","))
	local sk = Mon.skippedFreeReward(Season, rows.free[5])
	local sk2 = Mon.skippedFreeReward(Season, rows.free[2])
	local sk3 = Mon.skippedFreeReward(Season, rows.free[20])
	check("4-8 · 보완 6-2 건너뛴 칸: 알 + 골드 → 토큰 3 · 골드 + 강화석 → 토큰 1 · 치장 그대로", sk.egg == nil and sk.gold == nil and sk.sparkleShard == 3 and sk2.gold == nil and sk2.enhanceStone == nil and sk2.sparkleShard == 1
		and sk3.cosmeticTheme == "meadowStar" and sk3.sparkleShard == nil)
	local pass = { premium = true, claimedFree = {}, claimedPaid = {} }
	local okB, whyB = Mon.canClaim(pass, "free", Season.tiers + Season.bonusCap + 1, 999, Season.tiers, true, Season.bonusCap)
	local okB2 = Mon.canClaim(pass, "free", Season.tiers + Season.bonusCap, 999, Season.tiers, true, Season.bonusCap)
	check("보완 5-2 반복 보너스 상한 20(61칸 = bonus_cap · 60칸 = 받음)", Season.bonusCap == 20 and not okB and whyB == "bonus_cap" and okB2)
	-- 보완 1-4 칸 ↔ 날짜(매일 · 주 4일): 1일차 = 월요일 · 평일 120 · 주말 240 · 일요일 주간 500
	local function dayOf(days)
		local exp, out = 0, {}
		for d = 1, 56 do
			local wd = (d - 1) % 7
			if days[wd] then exp += (wd >= 5) and 240 or 120 end
			if wd == 6 then exp += 500 end
			for t = 1, 80 do
				if not out[t] and exp >= t * Season.expPerTier then out[t] = d end
			end
		end
		return out
	end
	local daily = dayOf({ [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true })
	local four = dayOf({ [1] = true, [3] = true, [5] = true, [6] = true })
	local line = {}
	for _, t in ipairs({ 1, 5, 10, 20, 30, 40, 60 }) do
		table.insert(line, ("%d칸 매일 %s · 주4 %s"):format(t, tostring(daily[t]), tostring(four[t])))
	end
	check("보완 1-4 매일 40칸 30 ~ 32일 · 주 4일 56일 안 · 매일 반복 20회 56일 안", daily[40] >= 30 and daily[40] <= 32 and four[40] and four[40] <= 56 and daily[60] and daily[60] <= 56, table.concat(line, " | "))
end

-- ══ 끝 ══
print(("===ALL9B 끝 %d/%d"):format(pass, total))
