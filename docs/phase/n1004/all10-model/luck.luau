local M = MODS
local function build(roll)
	local gear = {}
	for _, part in ipairs({ "armor", "gloves", "shoes" }) do
		gear[part] = { grade = "primordial", itemLevel = 10000, option = { id = "attackPercent", roll = roll, roll2 = roll } }
	end
	local gems = {}
	for i = 1, 5 do
		table.insert(gems, M.EconSim.makeGem(i <= 3 and "attackPercent" or "critDamage", "primordial", 10000, roll))
	end
	return M.BalanceSim.buildLoadout({ classId = "bow", level = 3000, weaponLevel = 30, weaponGrade = 6, gear = gear, gems = gems, permanentMultiplier = 1.2, permanentHpMultiplier = 1.2, rebirth = 5 })
end
local hp = build(1.0).atk * 30
for _, r in ipairs({ 1.0, 1.0875, 1.1125, 1.125 }) do
	local L = build(r)
	local ks = M.EconSim.killSeconds(L, hp, 600)
	print(("LUCK|roll %.4f|atk %.6g|kill %.6g"):format(r, L.atk, ks))
end
print("[LUCK] 끝")
