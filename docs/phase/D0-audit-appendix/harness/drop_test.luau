math.randomseed(20260925)
Random.new = function() return { NextNumber = function(_, a, b) local u = math.random() if a then return a + (b - a) * u end return u end, NextInteger = function(_, a, b) return math.random(a, b) end } end
local Loot = MODS.Loot
local DropTable = MODS.DropTable
local MonsterData = MODS.MonsterData
local order = { "normal", "rare", "epic", "legendary", "relic", "ancient", "primordial" }
local function run(label, stage, best, tier, n)
	local counts, items = {}, 0
	local rate = DropTable.effectiveRate({ bestStage = best }, { tierIndex = tier }, stage)
	for _ = 1, n do
		for _, it in ipairs(Loot.rollArmorDrop(stage, tier, 1, "archer", rate)) do
			counts[it.grade] = (counts[it.grade] or 0) + 1
			items += 1
		end
	end
	local row = DropTable.gradeRow(tier, rate)
	local parts = {}
	for _, g in ipairs(order) do
		if counts[g] or row[g] then
			table.insert(parts, ("%s %d(%.1f%% / 기대 %.2f%%)"):format(g, counts[g] or 0, 100 * (counts[g] or 0) / math.max(items, 1), 100 * (row[g] or 0)))
		end
	end
	print(("%s | 처치 %d · 장비 %d(처치당 %.3f / 기대 %.3f) | %s"):format(label, n, items, items / n, Loot.expectedArmorDropCount(tier, 1), table.concat(parts, " · ")))
end
for t = 1, 6 do print("tier", t, "r", MonsterData.getRewardRatio(t), "hpx", MonsterData["tier" .. t].hp / MonsterData.tier1.hp, "dropx", MonsterData["tier" .. t].dropCountMultiplier) end
run("①보스처치직후 st40 best40 tier6", 40, 40, 6, 1000)
run("②일반진입 st40 best40 tier6", 40, 40, 6, 1000)
run("③재접속 st40 best40 tier6", 40, 40, 6, 1000)
run("참고 st40 tier5", 40, 40, 5, 1000)
run("참고 st40 tier3", 40, 40, 3, 1000)
print("보스 첫클리어표(환생1+)") for g, c in pairs(MonsterData.bossFirstClearGradeTable) do print(" ", g, c) end
print("보스 첫클리어표(환생0)") for g, c in pairs(MonsterData.bossFirstClearUpgradedGradeTable) do print(" ", g, c) end
