-- PROG-2B-1 5 체력 눈금(HP-SCALE-1 D1 ~ D3): CombatConfig.hpScale = 5 · 체력 · 방어 · 몹 / 보스 공격 · 흡혈 요청량에 같은 H → 몇 대 맞으면 죽나 · 감소율 · 권장 방어 비 = 정확히 그대로.
-- 실행: LUAU=<luau.exe> PRELUDE=server_prelude.luau EXTRA_SERVER=$(python deps.py PlayerProfile) ECON_RES=res_hps.txt python build_run.py hp_scale_test.luau
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then pass += 1 end
	print(("[HPS] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end
local function near(a, b, tol) return math.abs(a - b) <= (tol or 1e-12) * math.max(1, math.abs(b)) end

local ok, err = pcall(function()
	local CC, BS, MS, MD, CF, PC = MODS.CombatConfig, MODS.BalanceSim, MODS.MonsterStats, MODS.MonsterData, MODS.CombatFormula, MODS.PlayerCombat
	check("D1 · D2 hpScale = 5(상수)", CC.hpScale == 5)
	local function snap(H)
		CC.hpScale = H
		local out = {}
		for _, s in ipairs({ 46, 1000, 8500, 25300 }) do
			local L = BS.buildLoadout({ classId = "bow", level = math.min(s, 2000), weaponLevel = 10, weaponGrade = 3, rebirth = 3,
				gear = { armor = { grade = "epic", itemLevel = math.max(1, s - 40) }, gloves = { grade = "epic", itemLevel = s }, shoes = { grade = "epic", itemLevel = s } } })
			local atk = BS.getMonsterAttack(s, "tier5")
			local hits = BS.getSurviveHits(L, atk)
			local boss = MODS.BossRules.buildInstanceData(math.max(10, math.floor(s / 10) * 10), "section_guardian", 1)
			out[s] = { maxHp = L.maxHp, def = L.defense, atk = atk, hits = hits, bossAtk = boss and boss.attack, recDef = CF.recommendedDefense(s), q = L.defense / CF.recommendedDefense(s) }
		end
		return out
	end
	local one, five = snap(1), snap(5)
	CC.hpScale = 5
	local scaleOk, hitsOk, qOk, rows = true, true, true, {}
	for s, a in pairs(one) do
		local b = five[s]
		scaleOk = scaleOk and near(b.maxHp, a.maxHp * 5) and near(b.def, a.def * 5) and near(b.atk, a.atk * 5) and near(b.bossAtk, a.bossAtk * 5) and near(b.recDef, a.recDef * 5)
		hitsOk = hitsOk and near(b.hits, a.hits, 1e-9)
		qOk = qOk and near(b.q, a.q, 1e-9)
		table.insert(rows, ("%d: 체력 %.4g → %.4g · 몹 %.4g → %.4g · %.3f대"):format(s, a.maxHp, b.maxHp, a.atk, b.atk, b.hits))
	end
	check("체력 · 방어 · 몹 · 보스 공격 · 권장 방어 = 정확히 ×5(4지점)", scaleOk)
	check("몇 대 맞으면 죽나(생존 타수) = 그대로(4지점 · 1e-9)", hitsOk, table.concat(rows, " / "))
	check("C2 방어 ÷ 권장 방어 = 그대로(받는 피해 배율 불변)", qOk)
	-- 감소율(PlayerDamage 식) = 방어 ÷ (방어 + α × 몹 공격) - 둘 다 H배면 그대로
	local D, A, al = 100, 300, CC.damageReductionAlpha
	check("감소율 = 방어 ÷ (방어 + α 공격) 그대로(H 지워짐)", near(D / (D + al * A), (5 * D) / (5 * D + al * 5 * A)))
	-- D3 흡혈 요청량 × H
	local PP, PS = MODS.PlayerProfile, MODS.PlayerState
	local asked = {}
	local oldGet, oldTry, oldOpt = PS.getHp, PS.tryLifesteal, PP.getOptionBonus
	PS.getHp = function() return 50 end
	PS.tryLifesteal = function(_, amount) table.insert(asked, amount); return 0 end
	PP.getOptionBonus = function(_, axis) return axis == "lifesteal" and 0.03 or 0 end
	PP.applyLifesteal({ Name = "LS" }, 1000)
	PS.getHp, PS.tryLifesteal, PP.getOptionBonus = oldGet, oldTry, oldOpt
	check("D3 흡혈 요청량 = 준 피해 × 비율 × H(1,000 × 0.03 × 5 = 150)", #asked == 1 and near(asked[1], 150), tostring(asked[1]))
end)
if not ok then
	print("[HPS] 하네스 에러 " .. tostring(err))
end
print(("[HPS] 끝 %d/%d"):format(pass, total))
