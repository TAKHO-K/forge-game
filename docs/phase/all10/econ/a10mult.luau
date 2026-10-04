-- QUEUE-ALL10 3-1 곱셈 중첩 표: 실제 BalanceSim · PlayerCombat로 25,000 대표 빌드에서 요소를 하나씩 켠 공격력 배수
ATTR.All10Economy = true
local M = MODS
local BS, ES, Milestone = M.BalanceSim, M.EconSim, M.Milestone
local level = 25000
local gear = { armor = { grade = "primordial", itemLevel = 25000 }, gloves = { grade = "primordial", itemLevel = 25000 }, shoes = { grade = "primordial", itemLevel = 25000 } }
local function gems(slot1)
	local g = { slot1 }
	for i = 2, 5 do
		g[i] = ES.makeGem("attackPercent", M.GemData.slotGradeCap[i], 25000, 1)
	end
	return g
end
local primGem = ES.makeGem("attackPercent", "primordial", 25000, 1)
local transGem = ES.makeGem("attackPercent", "transcendent", 25000, 1)
local perm0 = Milestone.attackMultiplier(level) + 0.05
local function atk(spec)
	local s = { classId = "greatsword", level = level, weaponLevel = 30, weaponGrade = spec.grade or 6, weaponTranscend = spec.trans, gear = gear, gems = gems(spec.gem or primGem), permanentMultiplier = perm0 + (spec.adv or 0), rebirth = 5 }
	return BS.buildLoadout(s).atk
end
local base = atk({})
local w = atk({ grade = 7, trans = { level = 0, slot = 0 } })
local t20 = atk({ grade = 7, trans = { level = 20, slot = 0 } })
local a100 = atk({ grade = 7, trans = { level = 20, slot = 0 }, adv = 0.5 })
local g = atk({ grade = 7, trans = { level = 20, slot = 0 }, adv = 0.5, gem = transGem })
print(("MULT|base %.6g|weapon %.4f|trans20 %.4f|adv100 %.4f|gem %.4f|total %.4f|perm0 %.4f"):format(base, w / base, t20 / w, a100 / t20, g / a100, g / base, perm0))
