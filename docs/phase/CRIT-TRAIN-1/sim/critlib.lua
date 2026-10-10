-- CRIT-TRAIN-1 시나리오 라이브러리(설계 시뮬 전용 - 하네스 메모리 안에서만 MODS 함수를 덮는다. 게임 데이터 · 코드 파일은 안 바뀐다).
-- p2lib.lua 뒤에 붙는다(crun.py). 손잡이 = CRITCFG(시나리오 파일):
--   train = { rate = { perLevel, maxLevel, stagesPerLevel, startStage, priceScale, priceOffset }, dmg = { … } }  치명타 확률 · 치명타 피해 수련(공용 수련 묶음 - 가격 = 공격 수련 (priceOffset + 단계) 가격 × priceScale)
--   over = { mode = "game" | "fixed" | "equal", rate = 넘친 확률 1(=100%p)당 공격력 %(fixed) , dmg = 넘친 치명 피해 1당 공격력 %(fixed · nil = 전환 없음) }
--   comp = { ref = { { 스테이지, 확률(상한 전 합), 치명 피해 추가분(상한 전), 위력 버킷, 레벨 }, … }, train = true, rec = true(권장 전투력에도 같은 계수) }  몹 HP 보정(중앙값 기준 빌드의 한 대 기대 피해 비)
local CC = CRITCFG or {}
CRIT = { log = {} }
local M = MODS
local PlayerCombat, BalanceSim, Training, TrainingData, CombatConfig, ClassData, All10, OptionData =
	M.PlayerCombat, M.BalanceSim, M.Training, M.TrainingData, M.CombatConfig, M.ClassData, M.All10, M.OptionData
local Option, Loot = M.Option, M.Loot

-- ── ① 치명 수련 항목(공용 수련 목록에 추가 - 버킷 · 축 없음 = 공격 · 체력 합에 안 섞임) ──
local tr = CC.train
local trainDefs = {}
if tr then
	for _, key in ipairs({ "rate", "dmg" }) do
		local t = tr[key]
		if t then
			local def = { id = "crit_" .. key, name = key == "rate" and "치명타 확률 수련" or "치명타 피해 수련", perLevel = t.perLevel, maxLevel = t.maxLevel,
				stagesPerLevel = t.stagesPerLevel or 20, critStart = t.startStage or 0, priceScale = t.priceScale or 1, priceOffset = t.priceOffset or 0 }
			table.insert(TrainingData.stats, def)
			trainDefs[key] = def
		end
	end
	-- 열림: startStage 뒤부터 (최고 − startStage) ÷ stagesPerLevel
	local oldCap = Training.capFor
	Training.capFor = function(def, bestStage)
		if def.critStart then
			return math.min(def.maxLevel, math.max(0, math.floor(((bestStage or 0) - def.critStart) / def.stagesPerLevel)))
		end
		return oldCap(def, bestStage)
	end
	-- 가격: 공격 수련 (priceOffset + 단계) 가격 × priceScale(같은 힘 = 같은 값 - 문서 3절)
	local oldCost = Training.costFor
	local atkDef = Training.statDef("attack")
	Training.costFor = function(def, level, bestStage)
		if def.critStart then
			return oldCost(atkDef, level + def.priceOffset, bestStage) * def.priceScale
		end
		return oldCost(def, level, bestStage)
	end
end
local CUR_TR = nil
local oldBucket = Training.bucketBonus
Training.bucketBonus = function(training, abilities, classId, bucket)
	CUR_TR = training
	return oldBucket(training, abilities, classId, bucket)
end
local function trainVal(key)
	local def = trainDefs[key]
	if not def or type(CUR_TR) ~= "table" then
		return 0
	end
	return def.perLevel * (tonumber(CUR_TR[def.id]) or 0)
end
CRIT.trainVal = trainVal

-- ── ② 치명 계산 기록 + 넘침 전환(게임 식 = PlayerCombat.resolveCrit · BalanceSim.buildLoadoutCore 그대로, 수련 몫 · 전환만 덧붙임) ──
local over = CC.over or { mode = "game" }
local OLD_CURVE = table.clone(CombatConfig.critCurve)
local function curveAt(curve, level)
	if level <= curve[1].level then return curve[1].bonus end
	for i = 2, #curve do
		local a, b = curve[i - 1], curve[i]
		if level <= b.level then return a.bonus + (b.bonus - a.bonus) * (level - a.level) / (b.level - a.level) end
	end
	return curve[#curve].bonus
end
if CC.critCurve then -- 레벨 치명 곡선 덮기(끝값 낮춤 - C4 결정 1)
	CombatConfig.critCurve = CC.critCurve
end
local LAST = {}
local oldResolve = PlayerCombat.resolveCrit
PlayerCombat.resolveCrit = function(classId, level, rebirthCount, optionCritRate)
	local class = ClassData.classes[classId]
	local base = class and class.critRate or 0
	local lv, rb = PlayerCombat.getLevelCritBonus(level), PlayerCombat.getRebirthCritBonus(rebirthCount)
	local opt = optionCritRate or 0
	local trn = trainVal("rate")
	LAST.src = { base = base, level = lv, rebirth = rb, option = opt, train = trn }
	local bonus = lv + rb + opt + trn
	local o = math.max(base + bonus - 1, 0)
	LAST.over = o
	if over.mode == "game" then
		return bonus - o, o * (CombatConfig.overCrit and CombatConfig.overCrit.attackPercentPerCrit or 0)
	end
	return bonus - o, 0 -- 전환은 아래 buildLoadout 뒤에서
end
local oldCapAtk = PlayerCombat.capAttackPercentOption
PlayerCombat.capAttackPercentOption = function(optionAttackPercent, overCritAttackPercent)
	LAST.gemAtk = optionAttackPercent or 0
	return oldCapAtk(optionAttackPercent, overCritAttackPercent)
end
local oldCritBonus = Option.critBonus
Option.critBonus = function(...)
	local r, d = oldCritBonus(...)
	LAST.gemDmg = d
	return r, d
end
local oldGloves = Loot.getGlovesCritDmgBonus
Loot.getGlovesCritDmgBonus = function(item)
	local v = oldGloves(item)
	LAST.glovesDmg = v
	return v
end
local ATK_CAP = OptionData.options.attackPercent.cap
local oldBuild = BalanceSim.buildLoadout
BalanceSim.buildLoadout = function(spec)
	LAST = {}
	local L = oldBuild(spec)
	L.perm = spec.permanentMultiplier or 1
	local class = ClassData.classes[spec.classId]
	local src = LAST.src or {}
	local dmgRaw = (LAST.glovesDmg or 0) + (LAST.gemDmg or 0) + (CC.trainDmgOutsideCap and 0 or trainVal("dmg"))
	local dmgCapped = math.min(dmgRaw, CombatConfig.critDmgBonusCap)
	local dmgOver = dmgRaw - dmgCapped
	local outside = CC.trainDmgOutsideCap and trainVal("dmg") or 0
	L.critDmg = class.critDmg + dmgCapped + outside
	L.critRawRate = (src.base or 0) + (src.level or 0) + (src.rebirth or 0) + (src.option or 0) + (src.train or 0)
	L.critSrc = src
	L.critDmgRaw = dmgRaw + outside
	L.critDmgOver = dmgOver
	local o = LAST.over or 0
	local gemAtk = LAST.gemAtk or 0
	local gloves = L.attackPercentBonus - oldCapAtk(gemAtk, over.mode == "game" and o * (CombatConfig.overCrit.attackPercentPerCrit or 0) or 0)
	local conv = 0
	if over.mode == "game" then
		conv = o * (CombatConfig.overCrit.attackPercentPerCrit or 0)
	else
		local m = L.critDmg
		local apb0 = gloves + oldCapAtk(gemAtk, 0)
		if over.mode == "fixed" then
			conv = o * (over.rate or 0) + dmgOver * (over.dmg or 0)
		elseif over.mode == "equal" then -- 100% 직전 1%p · 상한 직전 치명 피해 1과 같은 기대 피해 → 위력 버킷 값으로
			conv = o * (m - 1) / m * (1 + apb0) + (over.dmg and dmgOver / m * (1 + apb0) or 0)
		end
	end
	local apb = gloves + oldCapAtk(gemAtk, conv)
	L.atk = L.atk / (1 + L.attackPercentBonus) * (1 + apb)
	L.attackPercentBonus = apb
	L.overCritAttackPercent = apb - gloves - oldCapAtk(gemAtk, 0)
	L.critMultAvg = 1 + L.critRate * (L.critDmg - 1)
	return L
end

-- ── ③ 몹 HP 보정(중앙값 기준 빌드의 한 대 기대 피해 비 - PROG-2A ④와 같은 원칙) ──
local comp = CC.comp
if comp and comp.ref then
	local function interp(s)
		local t = comp.ref
		if s <= t[1][1] then return t[1] end
		for i = 2, #t do
			if s <= t[i][1] then
				local a, b = t[i - 1], t[i]
				local u = (s - a[1]) / (b[1] - a[1])
				return { s, a[2] + (b[2] - a[2]) * u, a[3] + (b[3] - a[3]) * u, a[4] + (b[4] - a[4]) * u, a[5] and (a[5] + (b[5] - a[5]) * u) }
			end
		end
		return t[#t]
	end
	local function capLv(def, s)
		return def and math.min(def.maxLevel, math.max(0, math.floor((s - def.critStart) / def.stagesPerLevel))) or 0
	end
	-- 한 대 기대 피해(기준 빌드): 확률 r · 치명 피해 추가분 d(상한 전) · 위력 버킷 a · 직업 치명 피해 m0 · 전환 규칙
	local function oneHit(r, d, a, m0, gameRatio)
		local dc = math.min(d, CombatConfig.critDmgBonusCap)
		local m = m0 + dc
		local o = math.max(r - 1, 0)
		local conv
		if over.mode == "game" then
			conv = o * gameRatio
		elseif over.mode == "fixed" then
			conv = o * (over.rate or 0) + (d - dc) * (over.dmg or 0)
		else
			conv = o * (m - 1) / m * (1 + a) + (over.dmg and (d - dc) / m * (1 + a) or 0)
		end
		return (1 + math.min(a + conv, ATK_CAP + 0.0)) * (1 + math.min(r, 1) * (m - 1))
	end
	CRIT.oneHit = oneHit
	local m0 = ClassData.classes.bow.critDmg
	local gameRatio = CombatConfig.overCrit.attackPercentPerCrit
	local oldHp = All10.hpCurveFactor
	All10.hpCurveFactor = function(stage)
		local s = stage or 0
		local x = interp(s)
		local r, d, a = x[2], x[3], x[4]
		local rN, dN = r, d
		if CC.critCurve and x[5] then -- 기준 빌드 레벨에서 곡선 차이만큼 뺌
			rN -= curveAt(OLD_CURVE, x[5]) - curveAt(CC.critCurve, x[5])
		end
		if comp.train then
			rN += (trainDefs.rate and trainDefs.rate.perLevel * capLv(trainDefs.rate, s) or 0)
			dN += (trainDefs.dmg and trainDefs.dmg.perLevel * capLv(trainDefs.dmg, s) or 0)
		end
		-- 분모 = 지금 게임 규칙(전환 1.0 · 수련 없음) 기준 빌드 · 분자 = 새 규칙 + 수련(상한까지 산다)
		local saved = over
		over = { mode = "game" }
		local den = oneHit(r, d, a, m0, gameRatio)
		over = saved
		local num = oneHit(rN, dN, a, m0, gameRatio)
		return oldHp(stage) * num / den
	end
	if comp.rec then -- 권장 전투력에도 같은 계수(몹 HP와 권장이 같은 기준 빌드를 따라감 - 3-b)
		local CombatFormula = M.CombatFormula
		local oldRec = CombatFormula.recommendedPower
		CombatFormula.recommendedPower = function(stage, baseHp)
			return oldRec(stage, baseHp) * All10.hpCurveFactor(stage) / oldHp(stage)
		end
	end
	CRIT.compAt = function(s)
		return All10.hpCurveFactor(s) / oldHp(s)
	end
end

-- ── ④ 보고: 청크별 치명 · 타수 줄 ──
CRIT.report = function(run)
	local EconSim = M.EconSim
	print("CHDR|t_h|reach|stage|tier|level|rebirth|rate|rawRate|base|lv|rb|opt|trn|critDmg|dmgRaw|overAtk|apb|atk|hitScale|mobHp|hitsNon|hitsCrit|hitsAvg|repHits|trRate|trDmg|trAtk|perm")
	for _, c in ipairs(run.chunks) do
		local L = c.loadout
		if L and L.critSrc then
			local s = L.critSrc
			local tier = EconSim.tierData(c.tier)
			local hp = EconSim.effectiveMonsterHp(L, tier.hp, c.stage)
			local _, hitScale = PlayerCombat.getAttackTempo(L.classId, L.speedPercentBonus, 1)
			local one = L.atk * hitScale
			local tt = c.training or {}
			print(("CR|%.3f|%d|%d|%d|%d|%d|%.4f|%.4f|%.3f|%.3f|%.3f|%.4f|%.4f|%.4f|%.4f|%.4f|%.4f|%.4g|%.3f|%.4g|%.3f|%.3f|%.3f|%.3f|%d|%d|%d|%.4f"):format(
				c.__t or 0, c.reach, c.stage, c.tier, c.levelAfter or c.level, c.rebirth, L.critRate, L.critRawRate, s.base or 0, s.level or 0, s.rebirth or 0, s.option or 0, s.train or 0,
				L.critDmg, L.critDmgRaw or 0, L.overCritAttackPercent or 0, L.attackPercentBonus, L.atk, hitScale, hp, hp / one, hp / (one * L.critDmg), hp / (one * L.critMultAvg),
				M.CombatFormula.representativeHits(c.stage), tt.crit_rate or 0, tt.crit_dmg or 0, tt.attack or 0, L.perm or 1))
		end
	end
	if CRIT.compAt then
		local t = {}
		for _, s in ipairs({ 100, 500, 1000, 2000, 3000, 5000, 8500, 15000, 25300 }) do
			table.insert(t, ("%d:%.4f"):format(s, CRIT.compAt(s)))
		end
		print("X_CCOMP|" .. table.concat(t, " "))
	end
end
