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
	local pl3 = fresh(6, 29)
	local pl4 = fresh(5, 30)
	check("조건 미달: 태초 +29 · 유물 +30 = not_ready", TS.prepare(pl3).why == "not_ready" and TS.prepare(pl4).why == "not_ready")
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
	cs.weapon.transcend.level, cs.weapon.transcend.slot = A.transcendEnhance.maxLevel, 0
	check("초월 강화 +20 = max(더 낼 수 없음)", TS.payEnhance(pl).why == "max")
	cs.weapon.transcend.level = 1
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
print(("[A10] 끝 %d/%d"):format(pass, total))
