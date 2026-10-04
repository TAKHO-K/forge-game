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
		and All10.advancedBonus(100) == 0 and All10.advancedCap(25300, true) == 50 and All10.transcendEnhanceBonus({ level = 20, slot = 0 }) == 0
		and All10.defenseTakeMultiplier(30) == 1 and not All10.defenseUnlocked(25300, true) and All10.evolutionCapBonus(25300) == 0
		and not All10.canInherit({ grade = 6, level = 30 }) and not All10.transcendGemUnlocked({ at = 1 })
	check("스위치 끔 = 계수 1 · 보너스 0 · 해금 없음(몹 곡선 · 돌파 · 고급 · 방어 · 초월 강화 · 진화 · 계승 · 보석)", offOk)

	-- ② 켬 = 제안서 식
	ATTR.All10Economy = true
	local mc = Data.monsterCurve
	local hp25 = All10.hpCurveFactor(25300)
	check("전역 재조정 HP: 16,000 전 = 1 · 25,300 = 1.02^(0.12 × 9,300) ≈ 3.96e9", All10.hpCurveFactor(15999) == 1 and All10.hpCurveFactor(16000) == 1
		and near(hp25, math.exp(0.12 * LN * 9300), 1e-12) and hp25 > 3.9e9 and hp25 < 4.0e9, ("%.4g"):format(hp25))
	local atk25 = All10.attackCurveFactor(25300)
	check("전역 재조정 공격: 25,300 ≈ ×1.35(방어 수련 30단계 0.99^30 = 0.74가 상쇄)", near(atk25, 1.35, 0.01) and near(atk25 * All10.defenseTakeMultiplier(30), 1.0, 0.02), ("%.4f · %.4f"):format(atk25, atk25 * All10.defenseTakeMultiplier(30)))
	local b0, b750, b1500, b3000 = All10.breakFactor(10000, 10000), All10.breakFactor(10750, 10000), All10.breakFactor(11500, 10000), All10.breakFactor(13000, 10000)
	local beta = 1 - 1 / mc.breakRatio
	check("돌파 계수: 계승 지점 1 · 750 = 1.02^(−0.583 × 750) · 1,500 = 끝 · 그 뒤 유지(앞선 몫) · 계승 전 스테이지 = 1 · 계승 안 함 = 1",
		b0 == 1 and near(b750, math.exp(-beta * LN * 750), 1e-12) and near(b1500, math.exp(-beta * LN * 1500), 1e-12) and b3000 == b1500
		and All10.breakFactor(9000, 10000) == 1 and All10.breakFactor(12000, nil) == 1, ("%.4g · %.4g"):format(b750, b1500))
	-- 돌파 속도: 같은 공격력에서 처치 시간 ∝ HP → 1,500 구간을 지나는 데 드는 "HP 성장 지수" = 기준선의 1/2.4
	check("돌파 2.4배: 1,500 구간 HP 성장 지수(ln) = 기준선 × 1/2.4", near((1500 * LN + math.log(b1500)) / (1500 * LN), 1 / mc.breakRatio, 1e-12))

	-- 초월 강화(10칸): 칸마다 효과 1/10 · +20 = +100% · 칸 가격 = 단계 비용 ÷ 10 · 효율 일정(공격 1%당 비용 = 단계 무관)
	local te = Data.transcendEnhance
	check("초월 강화: +0 칸 3 = +1.5% · +7 칸 0 = +35% · +20 = +100%(칸 무시)", near(All10.transcendEnhanceBonus({ level = 0, slot = 3 }), 0.015) and near(All10.transcendEnhanceBonus({ level = 7, slot = 0 }), 0.35)
		and near(All10.transcendEnhanceBonus({ level = 20, slot = 5 }), 1.0))
	local slot10k = All10.transcendSlotCost(10000)
	local want10k = GoldCost.cost(MonsterData.tier1.goldDrop * te.levelKills / te.slots * Data.killUnitScale, 10000, "transcend")
	check("초월 칸 가격 = tier1 골드 × 28만 ÷ 10 × 1.76 × GoldCost(최고 스테이지) · 스테이지 오르면 수입과 같은 율", slot10k == want10k and near(All10.transcendSlotCost(12000) / slot10k, 1.001 ^ 2000, 1e-6), ("%.4g"):format(slot10k))

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
	check("계승 조건: 태초(6) +30 O · +29 X · 유물(5) +30 X · 초월(7) X", All10.canInherit({ grade = 6, level = 30 }) and not All10.canInherit({ grade = 6, level = 29 })
		and not All10.canInherit({ grade = 5, level = 30 }) and not All10.canInherit({ grade = 7, level = 30, transcend = { level = 0, slot = 0 } }))
	ATTR.All10Economy = nil
end)
if not ok then print("[A10] 에러 " .. tostring(err)) end

-- 1-1 저장 v70: 새 계정 · 옛 저장(v69) 이관 · 빈 값 · 큰 수 · NaN 방어 · 멱등 · 지우는 필드 없음
local okS, errS = pcall(function()
	local SaveSystem, SaveConfig, A, All10 = MODS.SaveSystem, MODS.SaveConfig, MODS.All10Data, MODS.All10
	ATTR.All10Economy = true
	local fresh = SaveSystem.migrate({})
	check("v70 새 계정: training.advanced 50 · guard 0 · transcendGems 빈 목록 · 무기 transcend 없음 · 계승 기록 없음", SaveConfig.saveVersion == 70 and fresh.version == 70
		and fresh.training.advanced == 50 and fresh.training.guard == 0 and type(fresh.transcendGems.list) == "table" and #fresh.transcendGems.list == 0 and fresh.transcendGems.seq == 0
		and fresh.classes.bow.weapon.transcend == nil and fresh.classes.bow.transcendInherit == nil)
	local old = SaveSystem.migrate({})
	old.version = 69
	old.training.advanced, old.training.guard, old.transcendGems = nil, nil, nil
	old.gold = 12345
	local m = SaveSystem.migrate(old)
	check("v69 → v70: 빈 칸 채움 · 다른 값 그대로(골드 · 수련 공격) · 멱등", m.version == 70 and m.training.advanced == 50 and m.training.guard == 0 and type(m.transcendGems) == "table"
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
		and All10.transcendEnhanceBonus(tb) == All10.transcendEnhanceBonus({ level = 20, slot = 0 }) and th.level == 0 and th.slot == 0
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
print(("[A10] 끝 %d/%d"):format(pass, total))
