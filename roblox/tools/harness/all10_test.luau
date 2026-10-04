-- QUEUE-ALL10 ALL10-P2 하네스: ① 스위치(All10Economy) 끄면 모든 계산이 지금 게임 값(계수 1 · 보너스 0 · 해금 없음) ② 켜면 제안서 식 그대로
--   (블록 1 · 2에서 저장 이관 · 계승 원자성 · 초월 강화 · 고급 · 방어 수련 · 초월 보석 보존 · 몹 곡선을 이 파일에 더한다).
-- 실행: LUAU=<luau.exe> PRELUDE=server_prelude.luau EXTRA_SERVER=$(python deps.py ...) ECON_RES=res_all10.txt python build_run.py all10_test.luau
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then pass += 1 end
	print(("[A10] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end
local function near(a, b, tol)
	return math.abs(a - b) <= (tol or 1e-9) * math.max(1, math.abs(b))
end

local ok, err = pcall(function()
	local All10, Data = MODS.All10, MODS.All10Data
	local GoldCost, MonsterData = MODS.GoldCost, MODS.MonsterData
	local LN = math.log(1.02)

	-- ① 스위치 끔 = 지금 게임
	ATTR.All10Economy = false
	local offOk = not All10.enabled() and All10.hpCurveFactor(25300) == 1 and All10.attackCurveFactor(25300) == 1 and All10.breakFactor(12000, 10000) == 1
		and All10.advancedBonus(100) == 0 and All10.advancedCap(25300, true) == 50 and All10.breakFactor(10750, 10000) == 1 and All10.transcendEnhanceBonus({ level = 20, slot = 0 }) == 0
		and All10.defenseTakeMultiplier(30) == 1 and not All10.defenseUnlocked(25300, true) and All10.evolutionCapBonus(25300) == 0
		and not All10.canInherit({ grade = 6, level = 30 }) and not All10.transcendGemUnlocked({ at = 1 })
	check("스위치 끔 = 계수 1 · 보너스 0 · 해금 없음(몹 곡선 · 돌파 · 고급 · 방어 · 초월 강화 · 진화 · 계승 · 보석)", offOk)

	-- ② 켬 = 제안서 식
	ATTR.All10Economy = true
	local mc = Data.monsterCurve
	local hp25 = All10.hpCurveFactor(25300)
	check("전역 재조정 HP: 16,000 전 = 1 · 25,300 = 1.02^(kappa × 9,300)", All10.hpCurveFactor(15999) == 1 and All10.hpCurveFactor(16000) == 1
		and near(hp25, math.exp(mc.curveKappa * LN * 9300), 1e-12), ("%.4g"):format(hp25))
	local atk25 = All10.attackCurveFactor(25300)
	check("전역 재조정 공격: 25,300 ≈ ×1.35(방어 수련 30단계 0.99^30 = 0.74가 상쇄)", near(atk25, 1.35, 0.01) and near(atk25 * All10.defenseTakeMultiplier(30), 1.0, 0.02), ("%.4f · %.4f"):format(atk25, atk25 * All10.defenseTakeMultiplier(30)))
	-- 돌파 계수 = 기준 빌드 × (1,500 구간 1/2.4) - 진행 속도 ∝ 상대 힘이라 기준 빌드인 사람은 구간 안 2.4배 · 뒤 정상
	local S0 = 10000
	local ref0, ref750, ref1500 = All10.referenceBuild(10000, S0), All10.referenceBuild(10750, S0), All10.referenceBuild(11500, S0)
	local wantRef750 = Data.inherit.weaponMultiplier * (1 + Data.advancedTraining.perLevel * 7) * All10.transcendMultiplierAt(mc.refTranscend and mc.refTranscend[1][2] or Data.transcendEnhance.baseMaxLevel * 750 / (mc.refEndStage - S0)) -- QUEUE-ALL9E1 0-6: 중앙값 궤적 표(10,750 = 첫 점 앞 = 0단계)
	check("기준 빌드: 계승 지점 = ×1.25 · 10,750 = 1.25 × (1 + 고급 7%) × (1 + 초월 기대치) · 스테이지에 단조 증가", near(ref0, Data.inherit.weaponMultiplier) and near(ref750, wantRef750, 1e-12) and ref1500 > ref750, ("%.4f · %.4f"):format(ref0, ref750))
	check("돌파 계수: 구간 안 = 기준 빌드 ÷ 2.4 · 1,500부터 = 기준 빌드(정상 복귀) · 계승 전 · 계승 안 함 = 기준 빌드/1", near(All10.breakFactor(10750, S0), ref750 / mc.breakRatio, 1e-12)
		and near(All10.breakFactor(11500, S0), ref1500, 1e-12) and near(All10.breakFactor(9000, S0), All10.referenceBuild(9000, S0) / mc.breakRatio, 1e-12) and All10.breakFactor(12000, nil) == 1)
	check("돌파 2.4배: 기준 빌드인 사람의 상대 힘(빌드 ÷ 돌파 계수) = 구간 안 2.4 · 뒤 1.0", near(ref750 / All10.breakFactor(10750, S0), mc.breakRatio, 1e-12) and near(ref1500 / All10.breakFactor(11500, S0), 1, 1e-12))
	-- 초월 강화(10칸): 칸마다 효과 1/10 · +20 = +100% · 칸 가격 = 단계 비용 ÷ 10 · 효율 일정(공격 1%당 비용 = 단계 무관)
	local te = Data.transcendEnhance
	-- QUEUE-ALL9E1 0-4: +1 ~ +5 확정(칸) · +6 ~ 단계당 ×(1 + gain) 곱
	local g = 1 + te.gain
	check("초월 강화(0-4): +0 칸 3 = +1.5% · +5 = +25% · +7 = 1.25 × 1.22² · +20 = 1.25 × 1.22^15(칸 무시) · 한 단계 성공 = 처치 시간 15 ~ 25% 감소", near(All10.transcendEnhanceBonus({ level = 0, slot = 3 }), 0.015)
		and near(All10.transcendEnhanceBonus({ level = 5, slot = 0 }), 0.25) and near(All10.transcendEnhanceBonus({ level = 7, slot = 0 }), 1.25 * g ^ 2 - 1, 1e-12)
		and near(All10.transcendEnhanceBonus({ level = 20, slot = 5 }), 1.25 * g ^ 15 - 1, 1e-12) and 1 - 1 / g >= 0.15 and 1 - 1 / g <= 0.25, ("+20 ×%.2f · 처치 시간 −%.1f%%"):format(1 + All10.transcendEnhanceBonus({ level = 20 }), (1 - 1 / g) * 100))
	local bandOk = true
	local want = { [6] = { 0.40, 8 }, [8] = { 0.40, 8 }, [9] = { 0.30, 10 }, [12] = { 0.25, 12 }, [15] = { 0.15, 20 }, [18] = { 0.10, 30 }, [20] = { 0.10, 30 }, [21] = { 0.10, 30 }, [25] = { 0.10, 30 } }
	for lv, w in pairs(want) do
		local b = All10.transcendBand(lv)
		bandOk = bandOk and b ~= nil and b.chance == w[1] and b.ceiling == w[2]
	end
	check("확률 표(사용자 숫자): +6~8 40%·8 · +9~11 30%·10 · +12~14 25%·12 · +15~17 15%·20 · +18~20 10%·30 · +21~25 10%·30 · +1~5 = 확정(묶음 없음)", bandOk and All10.transcendBand(5) == nil and All10.transcendBand(1) == nil)
	local ceilOk = true
	for _, lv in ipairs({ 6, 9, 12, 15, 18 }) do
		local b = All10.transcendBand(lv)
		ceilOk = ceilOk and not All10.transcendAttemptSucceeds(lv, b.ceiling - 2, 0.9999) and All10.transcendAttemptSucceeds(lv, b.ceiling - 1, 0.9999) and All10.transcendAttemptSucceeds(lv, 0, b.chance - 1e-9)
	end
	local mcOk, mcTxt = true, {}
	for _, lv in ipairs({ 6, 9, 12, 15, 18 }) do
		local b, n, tries = All10.transcendBand(lv), 200000, 0
		for _ = 1, n do
			local f = 0
			while true do
				tries += 1
				if All10.transcendAttemptSucceeds(lv, f, math.random()) then break end
				f += 1
			end
		end
		local e = tries / n
		mcOk = mcOk and math.abs(e / All10.transcendExpectedAttempts(b) - 1) < 0.01
		table.insert(mcTxt, ("+%d %.3f/%.3f"):format(lv, e, All10.transcendExpectedAttempts(b)))
	end
	check("천장: N−1번 실패 뒤 N번째 = 확정 · 그 전 = 확률 · 기대 시도 수 식 = 몬테카를로 20만(±1%) → 시도 가격 × 기대 시도 = 단계 비용(실패 포함)", ceilOk and mcOk
		and near(All10.transcendAttemptCost(6, 10000) * All10.transcendExpectedAttempts(All10.transcendBand(6)) / (All10.transcendSlotCost(10000) * te.slots), 1, 1e-6), table.concat(mcTxt, " · "))
	check("+21 ~ +25 = 최고 스테이지 24,000 이상에서만(23,999 = 상한 20 · 24,000 = 25)", All10.transcendCap(23999) == 20 and All10.transcendCap(24000) == 25)
	local slot10k = All10.transcendSlotCost(10000)
	local want10k = GoldCost.cost(MonsterData.tier1.goldDrop * te.levelKills / te.slots * Data.killUnitScale, 10000, "transcend")
	check("초월 칸 가격 = tier1 골드 × levelKills ÷ 10 × 1.76 × GoldCost(최고 스테이지) · 스테이지 오르면 수입과 같은 율", slot10k == want10k and near(All10.transcendSlotCost(12000) / slot10k, 1.001 ^ 2000, 1e-6), ("%.4g"):format(slot10k))

	-- 고급 수련: 초월 무기 없으면 50(스테이지만으로 안 열림) · 있으면 50 + (s − 10,000) ÷ 100 · 15,000 = 100 · 51 ~ 60 비용 × 0.4
	check("고급 수련 상한: 초월 없음 25,300 = 50 · 초월 9,000 = 50 · 10,150 = 51 · 15,000 = 100 · 30,000 = 100", All10.advancedCap(25300, false) == 50 and All10.advancedCap(9000, true) == 50
		and All10.advancedCap(10150, true) == 51 and All10.advancedCap(15000, true) == 100 and All10.advancedCap(30000, true) == 100)
	local ad = Data.advancedTraining
	local c51, c60, c61 = All10.advancedCost(50, 12000), All10.advancedCost(59, 12000), All10.advancedCost(60, 12000)
	local unit = MonsterData.tier1.goldDrop * Data.killUnitScale
	check("고급 수련 비용: 51 = 1,840 × 0.4 · 60 = 1,840 × 1.03^9 × 0.4 · 61 = 1,840 × 1.03^10(완만 끝)", c51 == GoldCost.cost(unit * ad.baseKills * ad.early.factor, 12000, "advTraining")
		and c60 == GoldCost.cost(unit * ad.baseKills * ad.growth ^ 9 * ad.early.factor, 12000, "advTraining") and c61 == GoldCost.cost(unit * ad.baseKills * ad.growth ^ 10, 12000, "advTraining"))
	check("고급 수련 공격 몫: 50 = 0 · 75 = +25% · 100 = +50% · 120(손상) = +50%", All10.advancedBonus(50) == 0 and near(All10.advancedBonus(75), 0.25) and near(All10.advancedBonus(100), 0.5) and near(All10.advancedBonus(120), 0.5))
	-- 방어 수련
	check("방어 수련: 초월 + 12,000 열림 · 11,999 · 초월 없음 = 닫힘 · 받는 피해 0.99^단계(30 상한)", All10.defenseUnlocked(12000, true) and not All10.defenseUnlocked(11999, true) and not All10.defenseUnlocked(20000, false)
		and near(All10.defenseTakeMultiplier(10), 0.99 ^ 10) and near(All10.defenseTakeMultiplier(99), 0.99 ^ 30))
	-- 진화 · 계승 판정
	check("직업 특성 진화: 4,999 = 0 · 5,000 = +10 · 10,000 = +30", All10.evolutionCapBonus(4999) == 0 and All10.evolutionCapBonus(5000) == 10 and All10.evolutionCapBonus(10000) == 30)
	check("계승 조건(ALL9E1 0-2): 등급 무관 +29 이상 O(태초 +30 · +29 · 유물 +30 · 기본 무기(0) +29) · +28 X · 초월(7) X", All10.canInherit({ grade = 6, level = 30 }) and All10.canInherit({ grade = 6, level = 29 })
		and All10.canInherit({ grade = 5, level = 30 }) and All10.canInherit({ grade = 0, level = 29 }) and not All10.canInherit({ grade = 6, level = 28 })
		and not All10.canInherit({ grade = 7, level = 30, transcend = { level = 0, slot = 0 } }))
	ATTR.All10Economy = nil
end)
if not ok then print("[A10] 에러 " .. tostring(err)) end

-- 1-1 저장 v70: 새 계정 · 옛 저장(v69) 이관 · 빈 값 · 큰 수 · NaN 방어 · 멱등 · 지우는 필드 없음
local okS, errS = pcall(function()
	local SaveSystem, SaveConfig, A, All10 = MODS.SaveSystem, MODS.SaveConfig, MODS.All10Data, MODS.All10
	ATTR.All10Economy = true
	local fresh = SaveSystem.migrate({})
	check("v70 새 계정: training.advanced 50 · guard 0 · transcendGems 빈 목록 · 무기 transcend 없음 · 계승 기록 없음", SaveConfig.saveVersion >= 72 and fresh.version == SaveConfig.saveVersion
		and fresh.training.advanced == 50 and fresh.training.guard == 0 and type(fresh.transcendGems.list) == "table" and #fresh.transcendGems.list == 0 and fresh.transcendGems.seq == 0
		and fresh.classes.bow.weapon.transcend == nil and fresh.classes.bow.transcendInherit == nil)
	local old = SaveSystem.migrate({})
	old.version = 69
	old.training.advanced, old.training.guard, old.transcendGems = nil, nil, nil
	old.gold = 12345
	local m = SaveSystem.migrate(old)
	check("v69 → v72: 빈 칸 채움 · 다른 값 그대로(골드 · 수련 공격) · 멱등", m.version == SaveConfig.saveVersion and m.training.advanced == 50 and m.training.guard == 0 and type(m.transcendGems) == "table"
		and m.gold == 12345 and m.training.attack == 0 and SaveSystem.migrate(m).training.advanced == 50)
	local bad = SaveSystem.migrate({})
	bad.training.advanced, bad.training.guard = 0 / 0, "12"
	bad.transcendGems = "망가짐"
	bad.classes.bow.weapon.grade = 7
	bad.classes.bow.weapon.transcend = { level = 1e300, slot = -5 } -- 큰 수 = SANE_MAX(계산은 All10이 maxLevel로 자름)
	bad.classes.dualblade.weapon.grade = 7
	bad.classes.dualblade.weapon.transcend = "x" -- 초월 무기인데 모양 틀림 → 보관 칸 + { 0, 0 }
	bad.classes.healer.weapon.transcend = { level = 0 / 0, slot = math.huge }
	bad.classes.greatsword.weapon.transcend = 5 -- 초월 무기 아님 + 모양 틀림 → 보관 칸 + 없음
	bad.classes.bow.transcendInherit = { stage = 0 / 0, at = 5, fromGrade = 6, fromLevel = 30 }
	bad.classes.bow.stageProgress.infiniteBest = 12345
	bad.classes.healer.transcendInherit = "?"
	local s = SaveSystem.migrate(bad)
	local tb, th = s.classes.bow.weapon.transcend, s.classes.healer.weapon.transcend
	local q = 0
	for _, e in ipairs(s.quarantine) do if e.kind == "all10" then q += 1 end end
	check("손상 값 정리: NaN · inf → 기본 · 숫자 문자열 → 숫자 · 큰 수 보존(계산만 상한) · 모양 틀림 → 보관 칸 4 + 기본 · 계승 기록 다른 칸 보존 · 손상 stage = 지금 최고",
		s.training.advanced == 50 and s.training.guard == 12 and type(s.transcendGems.list) == "table" and tb.level == 1e6 and tb.slot == 0
		and All10.transcendEnhanceBonus(tb) == All10.transcendEnhanceBonus({ level = MODS.All10Data.transcendEnhance.maxLevel, slot = 0 }) and tb.fails == 0 and th.level == 0 and th.slot == 0
		and s.classes.dualblade.weapon.transcend.level == 0 and s.classes.greatsword.weapon.transcend == nil and q == 4
		and s.classes.bow.transcendInherit.stage == 12345 and s.classes.bow.transcendInherit.fromLevel == 30 and s.classes.healer.transcendInherit == nil and SaveSystem.isValidProfile(s),
		("adv %s guard %s bow %s/%s 보관 %d"):format(tostring(s.training.advanced), tostring(s.training.guard), tostring(tb.level), tostring(tb.slot), q))
	-- 정상 값 그대로 · 전체 멱등(두 번 이관해도 같은 표)
	local good = SaveSystem.migrate({})
	good.training.advanced, good.training.guard = 100, 30
	good.classes.bow.weapon.grade = 7
	good.classes.bow.weapon.transcend = { level = 7, slot = 4 }
	good.classes.bow.transcendInherit = { stage = 9885, at = 1790000000, fromGrade = 6, fromLevel = 30 }
	good.transcendGems = { list = { { id = "TG1", grade = "transcendent", locked = true } }, seq = 1 }
	local g1 = SaveSystem.migrate(good)
	local function dump(t, out, prefix)
		out = out or {}
		local keys = {}
		for k in pairs(t) do table.insert(keys, tostring(k)) end
		table.sort(keys)
		for _, k in ipairs(keys) do
			local v = t[k] ~= nil and t[k] or t[tonumber(k)]
			if type(v) == "table" then dump(v, out, (prefix or "") .. k .. ".") elseif k ~= "at" then table.insert(out, (prefix or "") .. k .. "=" .. tostring(v)) end
		end
		return out
	end
	local before = table.concat(dump(g1), "|")
	local g2 = SaveSystem.migrate(g1)
	check("정상 값 보존(초월 7 · 칸 4 · 고급 100 · 방어 30 · 계승 기록 · 보석 1) · 전체 멱등(두 번째 이관 = 같은 표)", g1.classes.bow.weapon.transcend.level == 7 and g1.classes.bow.weapon.transcend.slot == 4
		and g1.training.advanced == 100 and g1.training.guard == 30 and g1.classes.bow.transcendInherit.stage == 9885 and #g1.transcendGems.list == 1 and g1.transcendGems.seq == 1
		and table.concat(dump(g2), "|") == before)
	local seqFix = SaveSystem.migrate({})
	seqFix.transcendGems = { list = { {}, {} }, seq = 0 }
	check("보석 번호 < 개수 → 끌어올림(id 중복 방지)", SaveSystem.migrate(seqFix).transcendGems.seq == 2)
end)
if not okS then print("[A10] 에러 " .. tostring(errS)) end

-- 블록 2 서버(TranscendService · 실제 PlayerProfile · PlayerCombat): 계승 원자성 · 토큰 · 롤백 · 공격력 · 초월 강화 칸 · 수련 · 보석 보존 · 드랍 · 스위치 끔
local okT, errT = pcall(function()
	if not MODS.TranscendService then
		print("[A10] (서비스 하네스 건너뜀 - deps에 TranscendService 없음)")
		return
	end
	local SaveSystem, PP, TS, A, All10 = MODS.SaveSystem, MODS.PlayerProfile, MODS.TranscendService, MODS.All10Data, MODS.All10
	local PlayerCombat = MODS.PlayerCombat
	ATTR.All10Economy = true
	local clock = 1000
	local saveOk = true
	local g = 0
	TS.deps = { now = function() return clock end, save = function() return saveOk end, guid = function() g += 1; return "tok" .. g end }
	local uid = 500
	local function fresh(grade, level)
		uid += 1
		local at = {}
		local pl = setmetatable({ Name = "T" .. uid, UserId = uid, DisplayName = "T" .. uid, Parent = true }, { __index = function(_, k)
			if k == "SetAttribute" then return function(_, n, v) at[n] = v end end
			if k == "GetAttribute" then return function(_, n) return at[n] end end
			if k == "FindFirstChild" or k == "WaitForChild" or k == "FindFirstChildOfClass" then return function() return nil end end
			if k == "IsA" then return function() return false end end
			if k == "GetAttributeChangedSignal" then return function() return { Connect = function() end } end end
			return nil
		end })
		local prof = SaveSystem.migrate({})
		prof.classId = "bow"
		prof.gold = 1e30
		local cs = prof.classes.bow
		cs.weapon.grade, cs.weapon.level = grade or 6, level or 30
		cs.weapon.slotUnlocked = { true, true, true, true, true }
		cs.weapon.gems = { { grade = "primordial", itemLevel = 100, option = { id = "attackPercent", roll = 0.5 } }, false, false, false, false }
		cs.stageProgress.infinite, cs.stageProgress.infiniteBest = 10000, 10000
		cs.rebirthCount = 5
		PP.init(pl, prof)
		return pl, prof, cs
	end
	-- ① 계승
	local pl, prof, cs = fresh()
	local atkBefore = PlayerCombat.getAttack(cs.weapon, "bow", 100, 0, 0, 1, nil)
	local p1 = TS.prepare(pl)
	local badTok = TS.confirm(pl, "가짜")
	local p2 = TS.prepare(pl)
	local r = TS.confirm(pl, p2.token)
	local again = TS.confirm(pl, p2.token)
	local atkAfter = PlayerCombat.getAttack(cs.weapon, "bow", 100, 0, 0, 1, nil)
	check("계승: 태초 +30 → 초월(7) +0 · 단계 0 칸 0 · 계승 스테이지 = 최고 10,000 · 칭호 · 보석 1(잠금 · 계정 목록) · 가짜 토큰 X · 같은 토큰 두 번 X(중복 계승 방지)",
		p1.ok and not badTok.ok and badTok.why == "token" and r.ok and cs.weapon.grade == 7 and cs.weapon.level == 30 and cs.weapon.transcend.level == 0 and cs.weapon.transcend.slot == 0
		and cs.transcendInherit.stage == 10000 and cs.transcendInherit.fromLevel == 30 and PP.hasTitle(pl, "transcendHeir") and #prof.transcendGems.list == 1 and prof.transcendGems.list[1].locked
		and prof.transcendGems.list[1].grade == "transcendent" and not again.ok, ("%s · %s"):format(tostring(r.why), tostring(again.why)))
	check("계승 뒤 공격력 = 태초 +30 × 1.25(등급 줄) · 다시 계승 시도 = already", math.abs(atkAfter / atkBefore - 1.25) < 1e-12 and TS.prepare(pl).why == "already", ("×%.6f"):format(atkAfter / atkBefore))
	ATTR.All10Economy = false
	local atkOff = PlayerCombat.getAttack(cs.weapon, "bow", 100, 0, 0, 1, nil)
	ATTR.All10Economy = true
	check("스위치 끔이면 초월 무기 = 태초 +30 공격(이득 0)", atkOff == atkBefore)
	-- 토큰 만료 · 직업 바뀜 · 저장 실패 롤백
	local pl2, prof2, cs2 = fresh()
	local t1 = TS.prepare(pl2)
	clock += A.inherit.confirmTtlSeconds + 1
	local expired = TS.confirm(pl2, t1.token)
	local t2 = TS.prepare(pl2)
	saveOk = false
	local failed = TS.confirm(pl2, t2.token)
	saveOk = true
	local rolledBack = cs2.weapon.grade == 6 and cs2.weapon.transcend == nil and cs2.transcendInherit == nil and #prof2.transcendGems.list == 0 and not PP.hasTitle(pl2, "transcendHeir") and cs2.weapon.gems[1].grade == "primordial"
	local t3 = TS.prepare(pl2)
	prof2.classId = "healer"
	local changed = TS.confirm(pl2, t3.token)
	prof2.classId = "bow"
	local t4 = TS.prepare(pl2)
	local ok4 = TS.confirm(pl2, t4.token)
	check("토큰 만료 X · 저장 실패 = 무기 · 기록 · 보석 · 칭호 전부 되돌림 · 확인 사이 직업 바뀜 X · 다시 하면 성공", not expired.ok and expired.why == "token" and not failed.ok and failed.why == "save_failed"
		and rolledBack and not changed.ok and changed.why == "class_changed" and ok4.ok and cs2.weapon.grade == 7)
	-- 리뷰 높음: 저장 대기 중 다른 시스템이 무기 홈을 바꿔도(보석 교체) 실패 되돌림이 덮지 않음 · 진행 낮은 직업 계승 = 계정 최고 스테이지
	local pl5, prof5, cs5 = fresh()
	prof5.classes.healer.stageProgress.infiniteBest = 14000
	local t5 = TS.prepare(pl5)
	TS.deps.save = function()
		cs5.weapon.gems[2] = { grade = "epic", itemLevel = 5, option = { id = "attackPercent", roll = 0.1 } }
		return false
	end
	local f5 = TS.confirm(pl5, t5.token)
	TS.deps.save = function() return saveOk end
	local kept = not f5.ok and cs5.weapon.gems[2] and cs5.weapon.gems[2].grade == "epic" and cs5.weapon.grade == 6 and cs5.weapon.transcend == nil and #prof5.transcendGems.list == 0 and prof5.transcendGems.seq == 1
	local t6 = TS.prepare(pl5)
	local ok6 = TS.confirm(pl5, t6.token)
	check("리뷰: 실패 되돌림 = 바꾼 칸만(대기 중 보석 교체 보존 · 번호 재사용 없음 → 재시도 TG2) · 계승 스테이지 = 계정 최고(14,000)", kept and ok6.ok and prof5.transcendGems.list[1].id == "TG2" and cs5.transcendInherit.stage == 14000)
	local pl3 = fresh(6, 28)
	check("조건 미달: 태초 +28 = not_ready", TS.prepare(pl3).why == "not_ready")
	-- ALL9E1 0-2: +30 계승 = 증표 · +29 = 증표 없음(확인 창 안내) · 결과는 같은 초월 +0 · 환생 0회 = 히든 칭호 · 환생 뒤에도 초월 유지 · 저장 실패 = 증표 · 칭호도 되돌림
	local CS = MODS.CosmeticService
	check("+30 계승 = 증표(enhance30Mark) 지급 · 환생 5회 = 히든 칭호 없음", CS.ownsItem(pl, A.inherit.markItemId) and not PP.hasTitle(pl, A.inherit.unrebornTitleId))
	local pl7, prof7, cs7 = fresh(6, 29)
	local pre7 = TS.prepare(pl7)
	local r7 = TS.confirm(pl7, pre7.token)
	local atk7 = PlayerCombat.getAttack(cs7.weapon, "bow", 100, 0, 0, 1, nil)
	check("+29 계승: 확인 표 mark = false · 증표 없음 · 결과 무기 = +30 몫 초월 +0(공격 = +30 계승과 같음)", pre7.ok and pre7.mark == false and r7.ok and r7.mark == false
		and not CS.ownsItem(pl7, A.inherit.markItemId) and cs7.weapon.level == 30 and cs7.transcendInherit.fromLevel == 29 and atk7 == atkAfter, ("×%.4f"):format(pre7.weaponMultiplier or -1))
	local pl8, prof8, cs8 = fresh(0, 29)
	cs8.rebirthCount = 0
	cs8.weapon.slotUnlocked = { false, false, false, false, false }
	cs8.weapon.gems = { false, false, false, false, false }
	local pre8 = TS.prepare(pl8)
	saveOk = false
	local f8 = TS.confirm(pl8, pre8.token)
	saveOk = true
	local rb8 = not f8.ok and cs8.weapon.grade == 0 and cs8.weapon.level == 29 and not PP.hasTitle(pl8, A.inherit.unrebornTitleId) and not CS.ownsItem(pl8, A.inherit.markItemId)
	local r8 = TS.confirm(pl8, TS.prepare(pl8).token)
	check("기본 무기(0) +29 · 환생 0회: 배수 > 1.25(낮은 등급에서 오름) · 저장 실패 = 히든 칭호 되돌림 · 성공 = 히든 칭호 unrebornTranscendent · 기록 rebirth 0",
		pre8.ok and pre8.unreborn and pre8.weaponMultiplier > 1.25 and rb8 and r8.ok and r8.unreborn and PP.hasTitle(pl8, A.inherit.unrebornTitleId) and cs8.transcendInherit.rebirth == 0, ("×%.3f"):format(pre8.weaponMultiplier or -1))
	cs8.characterExp = 1e300
	local rbOk = PP.rebirth(pl8)
	check("환생 0회 계승 뒤 환생 = 초월(7) · 초월 강화 그대로(등급을 회차로 덮지 않음) · 1번 홈 지급 보석", rbOk and cs8.rebirthCount == 1 and cs8.weapon.grade == 7 and cs8.weapon.transcend ~= nil
		and type(cs8.weapon.gems[1]) == "table" and cs8.weapon.gems[1].transcendGemId == nil)
	-- ══ QUEUE-ALL9E1-ADD 블록 B 홈(소켓) 규칙 ══
	local Gem, GemData = MODS.Gem, MODS.GemData
	local function gemOf(grade, lv) return { grade = grade, itemLevel = lv or 50, option = { id = "attackPercent", roll = 0.5 } } end
	-- B1 환생 계승: 태초 상한 홈(1번) → 초월 홈 · 박힌 보석 3개(1 · 2 · 3) 그대로
	local pB1, prB1, csB1 = fresh(6, 30)
	csB1.weapon.gems = { gemOf("primordial"), gemOf("epic"), gemOf("legendary"), false, false }
	local g1, g2, g3 = csB1.weapon.gems[1], csB1.weapon.gems[2], csB1.weapon.gems[3]
	local rB1 = TS.confirm(pB1, TS.prepare(pB1).token)
	check("B1 환생 계승: 태초 홈(1번) → 초월 홈 · 박힌 보석 3개 그대로(같은 표) · 2 ~ 5번 상한 그대로", rB1.ok and csB1.weapon.transcendSlots[1] == true and csB1.weapon.transcendSlots[2] == nil
		and csB1.weapon.gems[1] == g1 and csB1.weapon.gems[2] == g2 and csB1.weapon.gems[3] == g3
		and Gem.gradeCapForSlot(1, csB1.weapon.transcendSlots) == "transcendent" and Gem.gradeCapForSlot(2, csB1.weapon.transcendSlots) == "epic")
	-- B3 환생 0회 · 홈 0개 → 새 초월 홈 1개(1번)
	local pB3, prB3, csB3 = fresh(0, 29)
	csB3.rebirthCount = 0
	csB3.weapon.slotUnlocked = { false, false, false, false, false }
	csB3.weapon.gems = { false, false, false, false, false }
	local preB3 = TS.prepare(pB3)
	local rB3 = TS.confirm(pB3, preB3.token, 4) -- 홈이 없으면 고른 값은 무시(새 홈 1번)
	check("B3 환생 0회 · 홈 0개: 확인 표 slotPick.new · 새 홈 1번 열림 · 초월 홈 = 1번만", preB3.slotPick and preB3.slotPick.new == 1 and rB3.ok and csB3.weapon.slotUnlocked[1] == true
		and csB3.weapon.slotUnlocked[2] == false and csB3.weapon.transcendSlots[1] == true and next(csB3.weapon.transcendSlots, 1) == nil)
	-- B3 환생 0회 · 홈 2개 → 두 번째 고름 · 잘못된 값(닫힌 홈 · 소수 · 문자 · 없음) 거부 · 토큰 유지
	local pB3b, prB3b, csB3b = fresh(0, 29)
	csB3b.rebirthCount = 0
	csB3b.weapon.slotUnlocked = { true, true, false, false, false }
	csB3b.weapon.gems = { gemOf("primordial"), gemOf("epic"), false, false, false }
	local preB3b = TS.prepare(pB3b)
	local bad1 = TS.confirm(pB3b, preB3b.token, 3)
	local bad2 = TS.confirm(pB3b, preB3b.token, 1.5)
	local bad3 = TS.handle(pB3b, "confirm", { token = preB3b.token, slot = "x" })
	local bad4 = TS.confirm(pB3b, preB3b.token, nil)
	local untouched = csB3b.weapon.grade == 0 and csB3b.weapon.transcendSlots == nil and csB3b.weapon.transcend == nil
	local okB3b = TS.handle(pB3b, "confirm", { token = preB3b.token, slot = 2 })
	check("B3 환생 0회 · 홈 2개: 고를 목록 = 1 · 2 · 닫힌 3 · 1.5 · 'x' · 없음 = bad_slot(무기 그대로 · 토큰 유지) · 2번 고름 = 초월 홈 2번 · 보석 그대로",
		#preB3b.slotPick.open == 2 and bad1.why == "bad_slot" and bad2.why == "bad_slot" and bad3.why == "bad_slot" and bad4.why == "bad_slot" and untouched
		and okB3b.ok and csB3b.weapon.transcendSlots[2] == true and csB3b.weapon.transcendSlots[1] == nil and csB3b.weapon.gems[2].grade == "epic", tostring(okB3b.why))
	-- 초월 보석 장착 = 초월 홈(고른 2번) · 초월 홈 상한 = 태초 보석도 들어감 · 일반 홈 상한 그대로
	local gidB = prB3b.transcendGems.list[1].id
	csB3b.weapon.slotUnlocked[2] = true
	local eqB = TS.equipGem(pB3b, gidB)
	check("B4 초월 보석 → 초월 홈(2번) · 원래 영웅 보석 → 보석칸(사라지지 않음) · canSocket: 초월 홈 = 태초 · 초월 O / 1번(태초 상한) 초월 X", eqB.ok and eqB.slot == 2
		and csB3b.weapon.gems[2].transcendGemId == gidB and Gem.canSocket("primordial", 2, csB3b.weapon.transcendSlots) and Gem.canSocket("transcendent", 2, csB3b.weapon.transcendSlots)
		and not Gem.canSocket("transcendent", 1, csB3b.weapon.transcendSlots) and csB3b.gemInventory[#csB3b.gemInventory].grade == "epic")
	-- B2 저장 실패 되돌림: 초월 홈 · 새로 연 홈도 원래대로
	local pBf, prBf, csBf = fresh(0, 29)
	csBf.rebirthCount = 0
	csBf.weapon.slotUnlocked = { false, false, false, false, false }
	csBf.weapon.gems = { false, false, false, false, false }
	saveOk = false
	local fBf = TS.confirm(pBf, TS.prepare(pBf).token)
	saveOk = true
	check("B 저장 실패 = 초월 홈 · 새로 연 홈까지 되돌림(무기 0 · +29 · 홈 닫힘)", not fBf.ok and csBf.weapon.transcendSlots == nil and csBf.weapon.slotUnlocked[1] == false and csBf.weapon.grade == 0 and csBf.weapon.level == 29)
	-- B5 박힌 보석 강화(재련 = 박힌 채 itemLevel만 오름 · 뺐다 넣기 없음) · 효과 즉시 다시 계산(서버 공격 % 합 = 화면 같은 함수)
	local pB5, prB5, csB5 = fresh(6, 30)
	csB5.weapon.gems[2] = gemOf("epic", 10)
	local before5 = PP.getAttackPercentBonus and PP.getAttackPercentBonus(pB5) or nil
	table.insert(csB5.gemInventory, gemOf("epic", 400))
	prB5.gemDust = 1e12
	local ok5 = PP.refineGem(pB5, "slot", 2, #csB5.gemInventory)
	local after5 = PP.getAttackPercentBonus and PP.getAttackPercentBonus(pB5) or nil
	check("B5 박힌 보석 재련 = 박힌 채 itemLevel 10 → 400 · 같은 표(뺐다 넣기 없음) · 공격 % 합 즉시 증가", ok5 and csB5.weapon.gems[2].itemLevel == 400 and csB5.weapon.gems[2].grade == "epic"
		and (before5 == nil or after5 > before5), ("%s → %s"):format(tostring(before5), tostring(after5)))
	-- B7 v70 · v71 저장 읽기: 옛 계승 무기 = 태초 상한 열린 홈 → 초월 홈 · 계승 안 한 무기 = 없음 · 멱등 · 손상 값 정리
	local old = SaveSystem.migrate({})
	old.version = 70
	old.classes.bow.weapon.grade, old.classes.bow.weapon.transcend = 7, { level = 3, slot = 2 }
	old.classes.bow.weapon.slotUnlocked = { true, true, false, false, false }
	old.classes.healer.weapon.slotUnlocked = { true, false, false, false, false }
	local m7 = SaveSystem.migrate(old)
	local m7b = SaveSystem.migrate(m7)
	local bad7 = SaveSystem.migrate({})
	bad7.classes.bow.weapon.grade, bad7.classes.bow.weapon.transcend = 7, { level = 1, slot = 0 }
	bad7.classes.bow.weapon.transcendSlots = { ["2"] = true, [9] = true, x = 1 }
	local s7 = SaveSystem.migrate(bad7)
	check("B7 v70 → v72: 옛 계승 무기 초월 홈 = {1}(태초 상한 · 열림) · 다른 직업 없음 · fails 0 · 멱등 · 손상 {'2', 9, x} → {2} + 보관 칸", m7.version == MODS.SaveConfig.saveVersion and m7.classes.bow.weapon.transcendSlots[1] == true
		and m7.classes.bow.weapon.transcendSlots[2] == nil and m7.classes.healer.weapon.transcendSlots == nil and m7.classes.bow.weapon.transcend.fails == 0 and m7b.classes.bow.weapon.transcendSlots[1] == true
		and s7.classes.bow.weapon.transcendSlots[2] == true and s7.classes.bow.weapon.transcendSlots[9] == nil and SaveSystem.isValidProfile(s7))
	-- 홈 판정 서버 = 화면: 서버 표(띄엄 키) vs GemSync 5칸 배열이 같은 결과(5홈 × 8등급)
	local same = true
	local map, arr = { [2] = true }, { false, true, false, false, false }
	for s = 1, 5 do
		for _, gid in ipairs(MODS.ArmorData.gradeOrder) do
			same = same and Gem.canSocket(gid, s, map) == Gem.canSocket(gid, s, arr) and Gem.socketBlockReason({ true, true, true, true, true }, s, gid, map) == Gem.socketBlockReason({ true, true, true, true, true }, s, gid, arr)
		end
	end
	check("B 홈 판정 서버(저장 모양) = 화면(GemSync 5칸 배열) - 5홈 × 8등급 · 상한 이하만 · 초월 홈 없으면 옛 규칙 그대로", same and Gem.canSocket("legendary", 2, nil) == false and Gem.canSocket("primordial", 1, nil))
	-- B2 장비가 사라지는 경로 조사(구조 증명): 보석은 무기 5홈에만 · 가방 장비(방어구)에는 홈 칸이 없다 · 판매 · 분해 · 일괄 · 자동 정리는 가방 칸 번호만 받는다(무기는 대상 아님)
	local inv = SaveSystem.migrate({})
	local hasGemField = false
	for _, item in ipairs(inv.inventory or {}) do if item.gems then hasGemField = true end end
	check("B2 구조: 보석이 박히는 곳 = 무기 5홈뿐(가방 장비에 gems 칸 없음 · 판매/분해 함수 = 가방 번호) → 장비가 사라지며 보석이 사라지는 경로 0(조사 표 = 보고서)", not hasGemField and type(inv.classes.bow.weapon.gems) == "table" and #inv.classes.bow.weapon.gems == 5)
	-- QUEUE-ALL9E1 LOOK2(v73): 내 아바타 옷 보이기 - 직업별 저장 · 기본 끔 · 연타 · 직업 전환 · 저장 왕복 · 옛 저장 이관 · 모양 틀림 = 보관 칸 · 바닥층 판정
	do
		local BL = MODS.BaseLayer
		local pC, profC = fresh()
		local d0 = SaveSystem.migrate({})
		local defOk = d0.classes.bow.showOwnClothes == false and d0.classes.healer.showOwnClothes == false
		local old = SaveSystem.migrate({})
		old.version = 72
		old.classes.bow.showOwnClothes = nil
		local m72 = SaveSystem.migrate(old)
		local bad = SaveSystem.migrate({})
		bad.classes.bow.showOwnClothes = "yes"
		local mb = SaveSystem.migrate(bad)
		local parked = false
		for _, q in ipairs(mb.quarantine or {}) do if q.why == "showOwnClothes_shape" then parked = true end end
		local first = PP.getShowOwnClothes(pC)
		for i = 1, 11 do PP.setShowOwnClothes(pC, i % 2 == 1) end -- 연타 11번 = 마지막 켬
		local afterSpam = PP.getShowOwnClothes(pC)
		profC.classId = "healer"
		local healerOff = PP.getShowOwnClothes(pC) == false
		profC.classId = "bow"
		local bowKept = PP.getShowOwnClothes(pC) == true
		local rt = SaveSystem.migrate(profC)
		local rejectBad = PP.setShowOwnClothes(pC, "켬") == false and PP.getShowOwnClothes(pC) == true
		local fakeP = { GetAttribute = function(_, k) return ({ ArmorLook_gloves = "tier2|epic" })[k] end }
		local noneP = { GetAttribute = function() return nil end }
		local decide = BL.wantBase(true, false) and not BL.wantBase(true, true) and not BL.wantBase(false, false) and BL.armorOn(fakeP) and not BL.armorOn(noneP)
		local s1, p1 = BL.templates("greatsword")
		local s2 = BL.templates("bow")
		local tplOk = type(s1) == "string" and s1:find("^rbxassetid://%d+$") ~= nil and type(p1) == "string" and s2 ~= s1
		check("LOOK2 v73 내 아바타 옷 보이기: 기본 끔 · v72 → v73 끔 · 모양 틀림 = 보관 칸 + 끔 · 연타 11번 = 마지막 값 · 직업별(치유사 끔 · 궁수 켬 유지) · 저장 왕복 유지 · 잘못된 값 거부 · 바닥층 판정(갑옷 + 끔만) · 직업 색 템플릿",
			defOk and m72.version == MODS.SaveConfig.saveVersion and m72.classes.bow.showOwnClothes == false and mb.classes.bow.showOwnClothes == false and parked
			and first == false and afterSpam == true and healerOff and bowKept and rt.classes.bow.showOwnClothes == true and rejectBad and decide and tplOk,
			("%s %s %s %s %s %s %s %s %s %s"):format(tostring(defOk), tostring(m72.classes.bow.showOwnClothes), tostring(parked), tostring(afterSpam), tostring(healerOff), tostring(bowKept), tostring(rt.classes.bow.showOwnClothes), tostring(rejectBad), tostring(decide), tostring(tplOk)))
	end
	-- ADD 2-3(P3 결정): 경로는 없지만 장비 제거 공용 함수 안전장치 - 홈 있는 가짜 장비(gems 3개)가 사라지면 보석 반환 · 거절이면 변화 없음 · 연타 복제 0
	do
		local pS, profS, csS = fresh()
		local function armor(grade) return { part = "armor", grade = grade, itemLevel = 50, dropStage = 300, tierIndex = 3, option = { id = "attackPercent", roll = 0.5 }, gems = { gemOf("rare"), gemOf("epic"), [4] = gemOf("legendary") } } end
		local function plain(grade) return { part = "armor", grade = grade, itemLevel = 50, dropStage = 300, tierIndex = 3, option = { id = "attackPercent", roll = 0.5 } } end
		local function gems() return #csS.gemInventory end
		profS.inventory = { armor("epic"), plain("epic") }
		local g0 = gems()
		local sold = PP.sellItem(pS, 1)
		local sellOk = type(sold) == "number" and gems() == g0 + 3 and #profS.inventory == 1 and profS.inventory[1].gems == nil
		local again = PP.sellItem(pS, 1) -- 연타: 다음 칸(홈 없음) 판매 · 보석 그대로
		local again2 = PP.sellItem(pS, 1) -- 빈 가방 = not_found
		local tapOk = type(again) == "number" and again2 == false and gems() == g0 + 3
		profS.inventory = { armor("epic") }
		local g1 = gems()
		local okD = PP.dismantleItem(pS, 1)
		local disOk = okD and gems() == g1 + 3 + 1 -- 박힌 3 + 분해 보석 1
		profS.inventory = { armor("epic"), armor("epic") }
		local g2 = gems()
		local nUp = PP.dismantleItemsUpTo(pS, "epic")
		local upOk = nUp == 2 and gems() == g2 + 2 * 4
		local bulkGrade = MODS.ArmorData.bulkSellGrades[1]
		profS.inventory = { armor(bulkGrade), armor(bulkGrade) }
		local g3 = gems()
		local nBad, _, why = PP.sellItemsByGrades(pS, { bulkGrade }, 3) -- 개수 틀림 = 아무것도 안 바뀜(보석도)
		local rejectOk = nBad == 0 and why == "count_mismatch" and gems() == g3 and #profS.inventory == 2 and Gem.socketedCount(profS.inventory[1]) == 3
		local nGood = PP.sellItemsByGrades(pS, { bulkGrade }, 2)
		local nAgain = PP.sellItemsByGrades(pS, { bulkGrade }, 2) -- 같은 요청 두 번 = none
		local byOk = nGood == 2 and nAgain == 0 and gems() == g3 + 6 and #profS.inventory == 0
		profS.inventory = { armor(bulkGrade) }
		local g4 = gems()
		local nUpTo = PP.sellItemsBulkUpTo(pS, bulkGrade)
		local bulkOk = nUpTo == 1 and gems() == g4 + 3
		check("ADD 2-3 B2 안전장치: 홈 있는 장비 판매 · 연타 · 분해 · 일괄 분해 · 등급 판매(개수 틀림 거절 = 변화 0 · 중복 요청 0) · 일괄 판매 → 박힌 보석 전부 반환 · 복제 0 · 홈 없는 장비 = 0개",
			sellOk and tapOk and disOk and upOk and rejectOk and byOk and bulkOk and Gem.socketedCount(plain("epic")) == 0,
			("%s %s %s %s %s %s %s"):format(tostring(sellOk), tostring(tapOk), tostring(disOk), tostring(upOk), tostring(rejectOk), tostring(byOk), tostring(bulkOk)))
	end
	-- ② 초월 강화: 칸 10개 = +1 · 칸 가격 · 골드 부족 = 변화 없음 · +20 = max
	local gold0 = prof.gold
	local slotCost = All10.transcendSlotCost(PP.getAccountBestStage(pl))
	local res
	for _ = 1, A.transcendEnhance.slots do res = TS.payEnhance(pl) end
	local paidOk = res.ok and res.leveled and cs.weapon.transcend.level == 1 and cs.weapon.transcend.slot == 0 and math.abs((gold0 - prof.gold) - slotCost * A.transcendEnhance.slots) <= 1e-6 * gold0
	local r1 = TS.payEnhance(pl)
	local atk1 = PlayerCombat.getAttack(cs.weapon, "bow", 100, 0, 0, 1, nil)
	prof.gold = 0
	local poor = TS.payEnhance(pl)
	prof.gold = 1e30
	check("초월 강화: 칸 10번 = +1(칸 0) · 칸당 가격 일정 · +1 칸 1 공격 = ×1.25 × (1 + 0.05 × 1.1) · 골드 부족 = 칸 그대로", paidOk and r1.ok and cs.weapon.transcend.slot == 1
		and math.abs(atk1 / atkBefore - 1.25 * (1 + 0.05 * 1.1)) < 1e-12 and not poor.ok and poor.why == "no_gold" and cs.weapon.transcend.slot == 1)
	-- QUEUE-ALL9E1 0-4 서버 확률 시도: 실패 = 골드만 · 단계 그대로 · 불씨 +1 · 성공 = +1 · 불씨 0 · 천장 = 확정 · 공격 ×1.22
	local te2 = A.transcendEnhance
	cs.weapon.transcend.level, cs.weapon.transcend.slot, cs.weapon.transcend.fails = 5, 0, 0
	local atk5 = PlayerCombat.getAttack(cs.weapon, "bow", 100, 0, 0, 1, nil)
	TS.deps.roll = function() return 0.99 end
	local gA = prof.gold
	local f1 = TS.payEnhance(pl)
	local failOk = f1.ok and f1.attempt and not f1.success and cs.weapon.transcend.level == 5 and cs.weapon.transcend.fails == 1 and math.abs((gA - prof.gold) - f1.cost) <= 1e-9 * gA
	for _ = 1, 6 do TS.payEnhance(pl) end
	local before8 = cs.weapon.transcend.fails
	local f8 = TS.payEnhance(pl)
	local atk6 = PlayerCombat.getAttack(cs.weapon, "bow", 100, 0, 0, 1, nil)
	TS.deps.roll = function() return 0.0 end
	local s7 = TS.payEnhance(pl)
	TS.deps.roll = nil
	check("확률 시도: 실패 = 골드만 · 단계 그대로 · 불씨 +1 · 7번 실패 뒤 8번째 확정(+6 · 불씨 0) · 공격 ×1.22 · 굴림 성공 = +7", failOk and before8 == 7 and f8.success and s7.success
		and cs.weapon.transcend.level == 7 and cs.weapon.transcend.fails == 0 and math.abs(atk6 / atk5 - (1 + te2.gain)) < 1e-9, ("×%.4f"):format(atk6 / atk5))
	cs.weapon.transcend.level = 20
	cs.stageProgress.infiniteBest = 23999
	local capWhy = TS.payEnhance(pl).why
	cs.weapon.transcend.level = te2.maxLevel
	check("초월 강화 +20 · 최고 23,999 = ext_stage(+21은 24,000부터) · +25 = max", capWhy == "ext_stage" and TS.payEnhance(pl).why == "max", tostring(capWhy))
	cs.stageProgress.infiniteBest = 10000
	cs.weapon.transcend.level, cs.weapon.transcend.fails = 1, 0
	-- ③ 고급 · 방어 수련
	local plN, profN = fresh()
	check("고급 수련: 초월 무기 없으면 not_transcend(스테이지 10,000이어도)", TS.buyAdvanced(plN).why == "not_transcend" and profN.training.advanced == 50)
	cs.stageProgress.infiniteBest = 10050 -- 상한 50 (10,050 → 50 + 0)
	local capped = TS.buyAdvanced(pl)
	cs.stageProgress.infiniteBest = 10300 -- 상한 53
	local b1, b2, b3, b4 = TS.buyAdvanced(pl), TS.buyAdvanced(pl), TS.buyAdvanced(pl), TS.buyAdvanced(pl)
	check("고급 수련: 상한 = 50 + (최고 − 10,000) ÷ 100 · 10,300 = 53까지 · 그다음 cap · 공격 버킷 +3%", capped.why == "cap" and b1.ok and b2.ok and b3.ok and not b4.ok and b4.why == "cap" and prof.training.advanced == 53
		and math.abs(PP.getMilestoneMultiplier(pl) - PP.getMilestoneMultiplier(plN) - 0.03) < 1e-12)
	local g0 = TS.buyGuard(pl)
	cs.stageProgress.infiniteBest = 12000
	local g1 = TS.buyGuard(pl)
	check("방어 수련: 11,999 이하 = stage · 12,000 = 열림 · 받는 피해 × 0.99", g0.why == "stage" and g1.ok and prof.training.guard == 1 and math.abs(PP.getGuardTakeMultiplier(pl) - 0.99) < 1e-12 and PP.getGuardTakeMultiplier(plN) == 1)
	-- ④ 초월 보석: 장착(1번 홈 · 원래 태초 보석은 보석칸으로) · 추출(목록 보존 · 홈 빔) · 일반 보석 교체가 사본을 밀어내면 목록으로 반환(보석칸 복제 X) · 판매 · 분해 대상 아님
	local gid = prof.transcendGems.list[1].id
	local invBefore = #cs.gemInventory
	local e1 = TS.equipGem(pl, gid)
	local socketed = cs.weapon.gems[1].transcendGemId == gid and cs.weapon.gems[1].grade == "transcendent" and prof.transcendGems.list[1].socket and #cs.gemInventory == invBefore + 1
	local ex = TS.extractGem(pl, gid)
	local extracted = cs.weapon.gems[1] == false and prof.transcendGems.list[1].socket == nil and #prof.transcendGems.list == 1
	TS.equipGem(pl, gid)
	local primIndex = #cs.gemInventory
	local okSwap = PP.equipGem(pl, 1, primIndex)
	local swapped = okSwap and cs.weapon.gems[1].grade == "primordial" and prof.transcendGems.list[1].socket == nil and #cs.gemInventory == invBefore
	local noCopyInInv = true
	for _, g in ipairs(cs.gemInventory) do if g.transcendGemId or g.grade == "transcendent" then noCopyInInv = false end end
	check("초월 보석: 장착(사본 · 태초 보석 → 보석칸) · 추출 100% 보존 · 일반 보석 교체 = 목록으로 반환 · 보석칸에 초월 사본 0(판매 · 분해 대상 없음)", e1.ok and socketed and ex.ok and extracted and swapped and noCopyInInv)
	check("초월 보석 장착: 계승 안 한 계정 = locked · 초월 무기 아님 = not_transcend", TS.equipGem(plN, gid).why == "locked")
	-- 드랍: 15,000 이상 · 0.2% · 계승한 계정만
	local n0 = #prof.transcendGems.list
	local dropLow = TS.rollBossDrop(pl, 14999, 0)
	local dropMiss = TS.rollBossDrop(pl, 15000, A.transcendGem.dropChance)
	local dropHit = TS.rollBossDrop(pl, 15000, A.transcendGem.dropChance - 1e-9)
	local dropN = TS.rollBossDrop(plN, 20000, 0)
	check("보스 드랍: 14,999 X · 굴림 ≥ 0.2% X · < 0.2% O(계정 목록 · 잠금 · 번호 TG2) · 계승 안 한 계정 X", dropLow == nil and dropMiss == nil and dropHit ~= nil and dropHit.locked and dropHit.id == "TG2" and dropN == nil and #prof.transcendGems.list == n0 + 1)
	-- 스위치 끔 = 모든 동작 disabled
	ATTR.All10Economy = false
	local off = TS.payEnhance(pl).why == "disabled" and TS.buyAdvanced(pl).why == "disabled" and TS.buyGuard(pl).why == "disabled" and TS.prepare(pl).why == "disabled" and TS.rollBossDrop(pl, 20000, 0) == nil
		and PP.getGuardTakeMultiplier(pl) == 1 and math.abs(PP.getMilestoneMultiplier(pl) - PP.getMilestoneMultiplier(plN)) < 1e-12
	ATTR.All10Economy = true
	check("스위치 끔 = 계승 · 강화 칸 · 수련 · 드랍 disabled · 고급 · 방어 효과 0", off)
	TS.deps = nil
end)
if not okT then print("[A10] 에러 " .. tostring(errT)) end

-- 3-1 고스테이지 골드 점 검증(도감 끔 · 균열 끔): 잡몹 = 게임 식(InfiniteStage.getGoldReward × 접두사 보상 · 반짝이 = 0.5배 + 기본형 125마리분)을 20만 마리 굴린 평균 vs
--   EconSim 기대(처치당 골드 × 반짝이 계수) - 마리당 · HP당(시간당) 둘 다 · 보스 = BossRules 골드(게임 · EconSim 같은 함수) · ALL10 켜도 골드 식은 그대로(스위치 끔 = 켬)
local okG, errG = pcall(function()
	local InfiniteStage, MD, PD, RC, BR = MODS.InfiniteStage, MODS.MonsterData, MODS.MonsterPrefixData, MODS.RareMonsterConfig, MODS.BossRules
	local rng = Random.new(20261004)
	local rows, worst = {}, 0
	for _, stage in ipairs({ 10000, 15000, 20000, 25300 }) do
		for _, key in ipairs({ "tier1", "tier6" }) do
			local t = MD[key]
			local base = InfiniteStage.getGoldReward(t.goldDrop, stage)
			local N, gold, hp = 200000, 0, 0
			for _ = 1, N do
				local r = rng:NextNumber()
				local prefix, acc = nil, 0
				for _, p in ipairs(PD.prefixes) do
					acc += p.chance
					if r < acc then
						prefix = p
						break
					end
				end
				local g = base * PD.getRewardMultiplier(prefix)
				if rng:NextNumber() < RC.sparkleChance then
					g = g * RC.goldMultiplier + base * RC.goldBonusKillEquivalent -- CombatResolution 반짝이 식
				end
				gold += g
				hp += prefix and prefix.hpMultiplier or 1
			end
			local expected = base * (1 + RC.sparkleChance * (RC.goldMultiplier - 1 + RC.goldBonusKillEquivalent)) -- EconSim.sparkleGoldFactor(도감 · 균열 끔)
			local perKill, perHp = (gold / N) / expected, (gold / hp) / expected
			worst = math.max(worst, math.abs(perHp - 1))
			table.insert(rows, ("%d %s 마리당 %.3f HP당 %.3f"):format(stage, key, perKill, perHp))
		end
	end
	check("고스테이지 골드 점 검증 10,000 · 15,000 · 20,000 · 25,300 × tier1 · tier6 × 20만 마리: HP당(시간당) 실제 ÷ 기대 ±10% 안(마리당은 접두사 보상 +6% 포함)", worst <= 0.10, table.concat(rows, " / "))
	ATTR.All10Economy = false
	local offBoss, offTrash = BR.buildInstanceData(25300, BR.bossIdForStage(25300), 1).goldDrop, InfiniteStage.getGoldReward(MD.tier6.goldDrop, 25300)
	ATTR.All10Economy = true
	local onBoss, onTrash = BR.buildInstanceData(25300, BR.bossIdForStage(25300), 1).goldDrop, InfiniteStage.getGoldReward(MD.tier6.goldDrop, 25300)
	ATTR.All10Economy = nil
	check("보스 · 잡몹 골드: 스위치 끔 = 켬(ALL10은 골드 식을 바꾸지 않음 - 계승자도 같은 골드)", offBoss == onBoss and offTrash == onTrash, ("보스 %.4g · 잡몹 %.4g"):format(onBoss, onTrash))
end)
if not okG then print("[A10] 에러 " .. tostring(errG)) end
-- QUEUE-ALL9E1 0-5 초월 최초 달성: 가짜 DataStore(UpdateAsync = 실제처럼 경쟁 시 변환 함수를 다시 돌림) - 두 서버 동시 → 1명만 · 같은 사람 재시도 = 이김 · 개발 계정 제외 · epoch 키
local okF, errF = pcall(function()
	local TF = MODS.TranscendFirsts
	local data = {}
	local interleave = nil
	local fake = {
		GetAsync = function(_, key) return data[key] end,
		UpdateAsync = function(_, key, fn)
			while true do
				local seen = data[key]
				local new = fn(seen)
				if interleave then -- 경쟁: 변환 뒤 커밋 전에 다른 서버가 먼저 씀 → 실제 UpdateAsync처럼 다시 돈다
					local f = interleave
					interleave = nil
					f()
				end
				if data[key] == seen then
					if new == nil then return nil end
					data[key] = new
					return new
				end
			end
		end,
	}
	TF.deps = { store = fake, test = true }
	local A1 = { userId = 1001, name = "A", at = 1 }
	local B1 = { userId = 1002, name = "B", at = 1 }
	interleave = function() TF.tryClaim(10, B1) end
	local wonA, recA = TF.tryClaim(10, A1)
	local wonB2 = TF.tryClaim(10, B1)
	local wonA15 = TF.tryClaim(15, A1)
	local wonA15again = TF.tryClaim(15, A1)
	local wonB15 = TF.tryClaim(15, B1)
	local rows = TF.readAll()
	check("0-5 두 서버 동시 +10 → 먼저 커밋한 B만 · A = 짐(기록 B) · B 다시(다른 직업) = 다시 최초 아님(리뷰) · +15 A 이김 · A 다시 = 아님 · B 짐 · 기록 2줄(높은 단계부터) · 키 = 시험 접두사 + epoch",
		not wonA and recA and recA.userId == 1002 and not wonB2 and wonA15 and not wonA15again and not wonB15 and #rows == 2 and rows[1].level == 15 and rows[2].level == 10
		and TF.keyFor(20) == "test_" .. MODS.All10Data.transcendFirsts.launchEpoch .. ":20", ("%s · %s"):format(tostring(recA and recA.userId), TF.keyFor(20)))
	check("0-5 대상 단계 10 · 15 · 20만 · 개발 계정 제외 · 칭호 3종 데이터", TF.isFirstLevel(10) and TF.isFirstLevel(20) and not TF.isFirstLevel(11) and TF.excluded(11595243049) and not TF.excluded(1001)
		and MODS.TitleData.titles.firstTranscend20 ~= nil and MODS.TitleData.titles.firstTranscend10 ~= nil)
end)
if not okF then print("[A10] 에러 " .. tostring(errF)) end

print(("[A10] 끝 %d/%d"):format(pass, total))
