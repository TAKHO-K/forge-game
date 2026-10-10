-- PROG-2B-1 4 치명(CRIT-TRAIN-1 C1 ~ C10): 레벨 곡선 끝 0.30 · 치명 수련 2종(열림 · 가격 · 상한 밖) · 넘침 원칙(치명 · 공속 · 버프 치명 = 같은 기대 피해 → 위력 버킷 · 상한 안) · 게임 = 시뮬 같은 함수 · 몹 기준 함수 치명 비.
-- 실행: LUAU=<luau.exe> PRELUDE=server_prelude.luau EXTRA_SERVER=SaveSystem,SlotSave ECON_RES=res_crit.txt python build_run.py crit_train_test.luau
MODS.SlotSaveData.enabled = false
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then pass += 1 end
	print(("[CRIT] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end
local function near(a, b, tol) return math.abs(a - b) <= (tol or 1e-9) * math.max(1, math.abs(b)) end

local ok, err = pcall(function()
	local PC, CC, T, TD, CD, OD = MODS.PlayerCombat, MODS.CombatConfig, MODS.Training, MODS.TrainingData, MODS.ClassData, MODS.OptionData
	local bow = CD.classes.bow

	-- ══ C1 레벨 곡선 ══
	check("C1 레벨 치명 곡선 끝 0.30(250 0.22 · 400 0.26 · 500 0.30 · 100 이하 그대로 0.12)", PC.getLevelCritBonus(500) == 0.30 and PC.getLevelCritBonus(250) == 0.22 and PC.getLevelCritBonus(400) == 0.26
		and PC.getLevelCritBonus(100) == 0.12 and PC.getLevelCritBonus(9999) == 0.30)
	check("C1 활 레벨 500 · 환생 5 · 옵션 0 = 15 + 30 + 30 = 75%(옛 100%)", near(bow.critRate + PC.resolveCrit("bow", 500, 5, 0, 0), 0.75))

	-- ══ C2 · C3 · C4 치명 수련 ══
	local rate, dmg = T.statDef("crit_rate"), T.statDef("crit_dmg")
	check("C2 치명타 확률 수련 +1%p × 25 · 2,000부터 120칸마다(1,999 = 0 · 2,120 = 1 · 4,999 = 24 · 5,000 = 25 · 9,999 = 25)", rate and rate.perLevel == 0.01 and rate.maxLevel == 25
		and T.capFor(rate, 1999) == 0 and T.capFor(rate, 2000) == 0 and T.capFor(rate, 2120) == 1 and T.capFor(rate, 4999) == 24 and T.capFor(rate, 5000) == 25 and T.capFor(rate, 9999) == 25, rate and ("%d · %d"):format(T.capFor(rate, 4999), T.capFor(rate, 5000)))
	check("C3 치명타 피해 수련 +2% × 50 · 5,000부터 100칸마다(10,000 = 50)", dmg and dmg.perLevel == 0.02 and dmg.maxLevel == 50 and T.capFor(dmg, 5099) == 0 and T.capFor(dmg, 5100) == 1 and T.capFor(dmg, 10000) == 50)
	local atk = T.statDef("attack")
	check("C4 가격 = 공격 수련 (25 + n) 구간 가격 × 가치 비(확률 1.0 · 피해 1.2)", T.costFor(rate, 0, 3000) == math.floor(T.costFor(atk, 25, 3000) * 1.0) and T.costFor(dmg, 10, 8000) == math.floor(T.costFor(atk, 35, 8000) * 1.2)
		and T.killsFor(atk, 25) == 400, ("%d · %d"):format(T.costFor(rate, 0, 3000), T.costFor(dmg, 10, 8000)))
	local r, d = T.critValues({ crit_rate = 10, crit_dmg = 60, attack = 50 })
	check("C2 · C3 몫 = 단계 × perLevel · 저장값 상한 넘으면 계산 때만 자름(피해 60 → 50) · 공격 버킷 · 축 몫에 안 섞임", near(r, 0.10) and near(d, 1.0) and T.bucketBonus({ crit_rate = 10, crit_dmg = 5 }, {}, "bow", "attack") == 0)
	check("C2 수련 확률 = 레벨 · 환생 · 옵션과 같은 줄(활 Lv1 + 수련 0.1 = 직업 + 0.10 + 0.10)", near(bow.critRate + PC.resolveCrit("bow", 1, 0, 0, 0.1), bow.critRate + 0.2))

	-- ══ C5 · C9 넘침 원칙 ══
	local m = bow.critDmg
	local apb, conv = PC.attackPercentWithOverflow(0.2, 0.5, 0.1, m, 0)
	check("C5 확률 110% = 위력 몫 × (1 + 0.1 × (m − 1)/m)(같은 기대 피해) · 장갑 0.2 + 옵션 0.5", near((1 + apb) / 1.7, 1 + 0.1 * (m - 1) / m) and near(conv, 0.1 * (m - 1) / m * 1.7), ("+%.4f"):format(conv))
	local apbCap = PC.attackPercentWithOverflow(0, OD.options.attackPercent.cap - 0.01, 0.5, m, 0)
	check("C5 위력 버킷 상한 2.55 안(옵션 2.54 + 큰 넘침 → 2.55)", near(apbCap, OD.options.attackPercent.cap))
	local cap = CC.attackSpeedMaxMultiplier
	local apbS, convS = PC.attackPercentWithOverflow(0, 0.3, 0, m, 2.0) -- 공속 원래 ×3.0
	check("C9 공속 ×3.0(상한 ×2.5) → 위력 몫 × 3.0/2.5 · 상한 아래 = 0", near((1 + apbS) / 1.3, 3.0 / cap) and select(2, PC.attackPercentWithOverflow(0, 0.3, 0, m, 1.4)) == 0, ("+%.4f"):format(convS))
	local apbB = PC.attackPercentWithOverflow(0, 0.3, 0.1, m, 2.0)
	check("넘침 둘 = 곱(같은 기대 피해) · 치명 피해 상한 넘침(C6) = 전환 없음", near((1 + apbB) / 1.3, (1 + 0.1 * (m - 1) / m) * 3.0 / cap))
	local sc, used = PC.overflowHitScale(PC.overCritLost(0.2, m), 1.0, 10)
	local sc2, used2 = PC.overflowHitScale(PC.overCritLost(0.2, m), 1.0, 0.05)
	check("C8 버프 치명 넘침 20%p = 한 타 × (1 + 0.2 (m − 1)/m) · 버킷 남은 자리 0.05면 거기까지", near(sc, 1 + 0.2 * (m - 1) / m) and near(sc2, (2 + 0.05) / 2) and near(used2, 0.05))
	check("광폭 = 같은 함수(옛 2.6 + 0.1 → 2.7/2.6 · 상한 아래 = 1)", near(PC.getFrenzyOverflowLost(1.6, 0.1), 2.7 / 2.6) and PC.getFrenzyOverflowLost(1.0, 0.1) == 1 and PC.getFrenzyOverflowLost(1.45, 0.1) == 2.55 / 2.5)

	-- ══ 게임 = 시뮬 같은 함수(BalanceSim) ══
	local BS = MODS.BalanceSim
	local L0 = BS.buildLoadout({ classId = "bow", level = 600, weaponLevel = 20, weaponGrade = 5, rebirth = 5 })
	local L1 = BS.buildLoadout({ classId = "bow", level = 600, weaponLevel = 20, weaponGrade = 5, rebirth = 5, critTraining = { rate = 0.25, dmg = 1.0 } })
	check("시뮬: 수련 확률 +25%p · 피해 +100%(상한 밖) · 넘침 = 위력", near(L1.critRate, math.min(1, L0.critRate + 0.25)) and near(L1.critDmg, L0.critDmg + 1.0) and L1.atk >= L0.atk,
		("%.3f → %.3f · ×%.2f → ×%.2f"):format(L0.critRate, L1.critRate, L0.critDmg, L1.critDmg))

	-- ══ 몹 기준 함수 치명 비(CRIT-TRAIN-1 4-1 계수 표 ±0.02) ══
	local RB = MODS.ReferenceBuild
	local want = { [1000] = 0.908, [2000] = 0.878, [3000] = 0.932, [5000] = 1.000, [8500] = 1.304, [15000] = 1.435 }
	local okT, rows = true, {}
	for _, s in ipairs({ 1000, 2000, 3000, 5000, 8500, 15000 }) do
		local v = RB.critFactor(s)
		okT = okT and math.abs(v - want[s]) <= 0.02
		table.insert(rows, ("%d:%.3f(%.3f)"):format(s, v, want[s]))
	end
	check("몹 기준 함수 치명 비 = CRIT-TRAIN-1 계수 표(±0.02)", okT, table.concat(rows, " "))
	check("100 · 500 = 1(레벨 곡선 같음 · 수련 전)", near(RB.critFactor(100), 1) and math.abs(RB.critFactor(500) - 1) < 0.02, ("%.4f · %.4f"):format(RB.critFactor(100), RB.critFactor(500)))

	-- ══ 저장 v79 ══
	local SaveSystem = MODS.SaveSystem
	local d = SaveSystem.defaultProfile()
	d.version = 78
	d.training.crit_rate, d.training.crit_dmg = nil, nil
	local mg = SaveSystem.migrate(d)
	check("저장 v79: 옛 계정 training.crit_rate · crit_dmg = 0 · 새 계정 기본값 0", mg.version == 79 and mg.training.crit_rate == 0 and mg.training.crit_dmg == 0 and SaveSystem.defaultProfile().training.crit_rate == 0
		and SaveSystem.migrate({}).training.crit_dmg == 0)
	local bad = SaveSystem.defaultProfile()
	bad.training.crit_rate, bad.training.crit_dmg = 0 / 0, 99
	SaveSystem.sanitizeAll10(bad)
	check("저장 값 정리: NaN = 0 · 큰 값 그대로(상한은 계산 때 - 롤백 안전)", bad.training.crit_rate == 0 and bad.training.crit_dmg == 99)
end)
if not ok then
	print("[CRIT] 하네스 에러 " .. tostring(err))
end
print(("[CRIT] 끝 %d/%d"):format(pass, total))
