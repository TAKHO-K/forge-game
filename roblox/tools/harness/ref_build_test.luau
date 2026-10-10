-- PROG-2B-1 3 몹 기준 함수(shared/ReferenceBuild - CRIT-TRAIN-1 C7 · PROG-2A ④): 계수 = 수련 버킷 비 × 치명 비 · 몹 HP · 권장 전투력 · 시뮬 · UI가 같은 계수 · 아는 보스 HP × 0.75.
-- 실행: LUAU=<luau.exe> PRELUDE=server_prelude.luau EXTRA_SERVER=$(python deps.py BossEncounter) ECON_RES=res_refb.txt python build_run.py ref_build_test.luau
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then pass += 1 end
	print(("[REFB] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end
local function near(a, b, tol) return math.abs(a - b) <= (tol or 1e-12) * math.max(1, math.abs(b)) end

local ok, err = pcall(function()
	local RB, IS, MS, CF, BS, MD = MODS.ReferenceBuild, MODS.InfiniteStage, MODS.MonsterStats, MODS.CombatFormula, MODS.BalanceSim, MODS.MonsterData
	local STAGES = { 1, 50, 100, 500, 999, 1000, 2000, 3920, 5000, 8500, 15000, 25300 }

	-- ══ 1 계수 = 수련 버킷 비 × 치명 비 ══
	local prodOk, rows = true, {}
	for _, s in ipairs(STAGES) do
		prodOk = prodOk and RB.hpFactor(s) == RB.bucketFactor(s) * RB.critFactor(s)
		table.insert(rows, ("%d:%.4f×%.4f"):format(s, RB.bucketFactor(s), RB.critFactor(s)))
	end
	check("1-1 계수 = 수련 버킷 비 × 치명 비(스테이지 12지점)", prodOk, table.concat(rows, " "))
	local ca = 0.000375 * math.min(50, math.floor(1000 / 10)) -- 활 숙련(옛 직업 능력 - 그대로 두 쪽에)
	check("1-2 수련 버킷 비(1,000) = (1.05 + 능력 + 0.5) ÷ (1.05 + 능력 + 0.05) · 1 ~ 19 = 1", near(RB.bucketFactor(1000), (1.05 + ca + 0.5) / (1.05 + ca + 0.05)) and RB.bucketFactor(19) == 1, ("%.6f"):format(RB.bucketFactor(1000)))
	-- 치명 비: 옛 규칙과 같은 곡선 · 수련 · 넘침이면 정확히 1(새 규칙 몫만 비율로)
	local critCfg = MODS.CombatConfig
	local saved = { curve = critCfg.critCurve, over = critCfg.overCrit }
	critCfg.critCurve = MODS.ReferenceBuildData.crit.legacyCritCurve
	critCfg.overCrit = { attackPercentPerCrit = MODS.ReferenceBuildData.crit.legacyOverCritPerCrit }
	local saveStats = MODS.TrainingData.stats
	local noCrit = {}
	for _, def in ipairs(saveStats) do if not def.critAxis then table.insert(noCrit, def) end end
	MODS.TrainingData.stats = noCrit
	local one = true
	for _, s in ipairs(STAGES) do one = one and RB.critFactor(s) == 1 end
	MODS.TrainingData.stats = saveStats
	critCfg.critCurve, critCfg.overCrit = saved.curve, saved.over
	check("1-3 치명 규칙이 옛 것과 같으면 치명 비 = 정확히 1(12지점)", one)
	-- 기대 피해 식(critHit) = 손 계산
	local h = RB.critHit(0.84, 0.09, 0, 1.6, 2.3, "legacy", 1)
	check("1-4 critHit(84% · +0.09 · 위력 1.6 · 활 ×2.3) = (1 + 1.6) × (1 + 0.84 × 1.39)", near(h, 2.6 * (1 + 0.84 * 1.39)), ("%.6f"):format(h))
	local o = RB.critHit(1.1, 0, 0, 1.0, 2.3, "equal")
	check("1-5 넘침 같은 기대 피해: 110% · ×2.3 · 위력 1 = (1 + 1 + 0.1 × 1.3/2.3 × 2) × 2.3", near(o, (2 + 0.1 * 1.3 / 2.3 * 2) * 2.3), ("%.6f"):format(o))

	-- ══ 2 같은 계수가 HP · 권장 · 시뮬 · UI에 ══
	local hpOk, recOk, simOk = true, true, true
	for _, s in ipairs(STAGES) do
		local base = MD.tier3
		hpOk = hpOk and near(MS.trashHp(base.hp, s), IS.getTrashHp(base.hp, s) * MODS.All10.hpCurveFactor(s) * RB.hpFactor(s))
		local recOld = IS.getTrashHp(base.hp, s) / CF.representativeHits(s) * CF.lateLift(s)
		local pts = MODS.CombatFormulaData.representative.displayHits or MODS.CombatFormulaData.representative.hits
		local saveRB = RB.hpFactor
		RB.hpFactor = function() return 1 end -- 옛 식(계수 없음) 표시값
		local dispOld = CF.displayRecommendedPower(s, base.hp)
		RB.hpFactor = saveRB
		recOk = recOk and pts ~= nil and near(CF.recommendedPower(s, base.hp), math.max(recOld * RB.hpFactor(s), 1e-9)) and near(CF.displayRecommendedPower(s, base.hp), dispOld * RB.hpFactor(s))
		simOk = simOk and BS.getMonsterHp(s, "tier3") == MS.trashHp(base.hp, s) and MS.trash(base, s).hp == MS.trashHp(base.hp, s)
	end
	check("2-1 몹 HP(잡몹) = 옛 곡선 × 계수(서버 MonsterStats)", hpOk)
	check("2-2 권장 전투력(판정 · 표시) = 옛 식 × 같은 계수(CRIT-TRAIN-1 C7 - 안 곱하면 벽 벌칙 이탈)", recOk)
	check("2-3 시뮬(BalanceSim) = 서버 = 몹 정보 UI(MonsterStats.trash) 같은 HP", simOk)
	local bd = MODS.BossRules.buildInstanceData(1000, "section_guardian", 1)
	local hpNoRb = bd.hp / RB.hpFactor(1000)
	check("2-4 보스 HP도 같은 계수(MonsterStats.bossHp)", near(bd.hp, hpNoRb * RB.hpFactor(1000)) and RB.hpFactor(1000) > 1, ("×%.4f"):format(RB.hpFactor(1000)))

	-- ══ 3 아는 보스 HP × 0.75 ══
	local BE, PP = MODS.BossEncounter, MODS.PlayerProfile
	local cleared, best = {}, {}
	local oldHas, oldBest = PP.hasBossFirstClearReward, PP.getAccountBestStage
	PP.hasBossFirstClearReward = function(p, s) return cleared[p] ~= nil and cleared[p][s] == true end
	PP.getAccountBestStage = function(p) return best[p] or 1 end
	local A, B, C = { Name = "A" }, { Name = "B" }, { Name = "C" }
	cleared[A] = { [500] = true }
	best[B] = 820 -- 500을 지나감(그 보스를 깸)
	best[C] = 500 -- 500에 막 닿음(아직 안 깸)
	local function hpWith(members)
		local d = MODS.BossRules.buildInstanceData(500, "section_guardian", #members)
		local base = d.hp
		local applied = BE.applyKnownBoss(d, 500, members)
		return d.hp / base, applied, d.knownBoss
	end
	local rA, aA, kA = hpWith({ A })
	local rC = select(1, hpWith({ C }))
	local rAB = select(1, hpWith({ A, B }))
	local rABC, aABC = hpWith({ A, B, C })
	local rDummy = select(1, hpWith({ A, { Name = "dummy" } }))
	PP.hasBossFirstClearReward, PP.getAccountBestStage = oldHas, oldBest
	check("3-1 솔로 아는 보스(첫 클리어 기록) = HP × 0.75 · 표시 knownBoss", near(rA, 0.75) and aA and kA == true and MODS.BossData.knownBossHpMultiplier == 0.75, ("×%.3f"):format(rA))
	check("3-2 처음(최고 = 그 스테이지) = 원래 체력", rC == 1)
	check("3-3 파티 모두 앎(기록 · 최고가 지나감) = × 0.75 · 한 명이라도 처음 = 원래 · 더미(프로필 없음) = 처음", near(rAB, 0.75) and rABC == 1 and not aABC and rDummy == 1,
		("%.3f · %.3f · %.3f"):format(rAB, rABC, rDummy))
end)
if not ok then
	print("[REFB] 하네스 에러 " .. tostring(err))
end
print(("[REFB] 끝 %d/%d"):format(pass, total))
