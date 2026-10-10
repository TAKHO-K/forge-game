-- PROG-2B-1 2 골드 곡선 C(GOLD-CURVE-1 G1 ~ G5 · G8): 곡선 · 보스 첫 처치 마리분 표 · 시즌 패스 · 견습 마리분 · 보너스 합 + 상한 · 2^53 공용 검증 · 보유 골드 환산 이관(v78).
-- 실행: LUAU=<luau.exe> PRELUDE=server_prelude.luau EXTRA_SERVER=SaveSystem,SlotSave ECON_RES=res_goldc.txt python build_run.py gold_curve_test.luau
MODS.SlotSaveData.enabled = false
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then pass += 1 end
	print(("[GOLDC] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end
local function near(a, b, tol) return math.abs(a - b) <= (tol or 1e-9) * math.max(1, math.abs(b)) end

local ok, err = pcall(function()
	local IS, ISC, GoldCost, MonsterData = MODS.InfiniteStage, MODS.InfiniteStageConfig, MODS.GoldCost, MODS.MonsterData
	local unit = MonsterData.tier1.goldDrop

	-- ══ 1 곡선 ══
	local m1000 = 1.001 ^ 999
	check("1-1 1,000까지 지금 식 그대로(1 · 500 · 1,000 = 1.001^(s−1))", IS.getGoldMultiplier(1) == 1 and IS.getGoldMultiplier(500) == 1.001 ^ 499 and IS.getGoldMultiplier(1000) == m1000)
	check("1-2 뒤 = M(1,000) × √(s ÷ 1,000) · 8,500 ≈ 7.91 · 25,300 ≈ 13.65", near(IS.getGoldMultiplier(8500), m1000 * math.sqrt(8.5)) and near(IS.getGoldMultiplier(25300), m1000 * math.sqrt(25.3))
		and math.abs(IS.getGoldMultiplier(8500) - 7.91) < 0.01 and math.abs(IS.getGoldMultiplier(25300) - 13.65) < 0.01, ("%.3f · %.3f"):format(IS.getGoldMultiplier(8500), IS.getGoldMultiplier(25300)))
	local mono = true
	for s = 2, 30000, 7 do
		mono = mono and IS.getGoldMultiplier(s) > IS.getGoldMultiplier(s - 1)
	end
	check("1-3 단조 증가(2 ~ 30,000) · 꺾임에서 끊김 없음(1,000 → 1,001 비 < 1.001)", mono and IS.getGoldMultiplier(1001) / IS.getGoldMultiplier(1000) < 1.001)
	check("1-4 비용 = 수입과 같은 함수(GoldCost.scale(8,500) = M(8,500))", GoldCost.scale(8500, "enhance") == IS.getGoldMultiplier(8500))
	check("1-5 초월 강화 levelKills = 43만 × 1.16(G3)", MODS.All10Data.transcendEnhance.levelKills == 498800)

	-- ══ 2 보스 첫 처치 = 마리분 표 ══
	local Enhance = MODS.Enhance
	local saved = ISC.goldCurve
	ISC.goldCurve = nil -- 지금 곡선 A로 되돌리면 옛 숫자표와 같아야(앞 두 자리)
	local back = Enhance.getBossGrantGold(360) == 2000 and Enhance.getBossGrantGold(720) == 12000 and Enhance.getBossGrantGold(5040) == 910000 and Enhance.getBossGrantGold(25200) == 520000000000000
	ISC.goldCurve = saved
	check("2-1 곡선 A로 되돌리면 옛 표(360 = 2,000 · 720 = 12,000 · 5,040 = 91만 · 25,200 = 5.2e14)", back)
	local g = Enhance.getBossGrantGold(25200)
	check("2-2 곡선 C: 25,200 = niceReward(4.95 × 1,210 × M(25,200)) · 1,000 이하 그대로 · 표 밖 = 0", g == GoldCost.niceReward(math.floor(unit * 1210 * IS.getGoldMultiplier(25200))) and Enhance.getBossGrantGold(900) == 14000
		and Enhance.getBossGrantGold(361) == 0, tostring(g))

	-- ══ 3 시즌 패스 = 마리분 ══
	local Season, Mon = MODS.SeasonPassData, MODS.Monetization
	local rows = Season.rowsFor(1)
	local okFree, paidGold = true, {}
	for tier = 1, Season.tiers do
		local f = rows.free[tier]
		if tier == 20 or tier == 40 then
			okFree = okFree and f.goldKills == nil and f.gold == nil
		else
			local want = math.floor((600 + 1200 * (tier - 1) / 38) / 10 + 0.5) * 10 + (tier == 25 and 600 or tier == 35 and 900 or 0)
			okFree = okFree and f.gold == nil and f.goldKills == want
		end
		for k in pairs(rows.paid[tier]) do
			if k == "gold" or k == "goldKills" then table.insert(paidGold, tier) end
		end
	end
	check("3-1 무료 줄 = 마리분(10 → 30분 직선 · 25칸 +10분 · 35칸 +15분 · 고정 골드 없음)", okFree, ("1칸 %d · 39칸 %d"):format(rows.free[1].goldKills, rows.free[39].goldKills))
	check("3-2 프리미엄(유료) 줄에 골드 없음(로벅스 = 힘 금지 재확인)", #paidGold == 0 and Season.bonus.paid.gold == nil and Season.bonus.paid.goldKills == nil, table.concat(paidGold, ","))
	local okSP, why = Mon.checkSeasonPass(MODS.MonetizationData, Season, MODS.CosmeticSlotData)
	check("3-3 시즌 패스 검사 통과(goldKills = 무료 줄만 허용 · 10 단위)", okSP, table.concat(why or {}, " / "))
	local bad = { tiers = 1, rows = { free = { { sparkleShard = 1 } }, paid = { { goldKills = 600 } } } }
	check("3-4 유료 줄에 goldKills = 검사 실패", not Mon.checkSeasonPass(MODS.MonetizationData, bad, MODS.CosmeticSlotData))
	local r1 = GoldCost.resolveKillGold(rows.free[1], unit, 1)
	local r85 = GoldCost.resolveKillGold(rows.free[39], unit, 8500)
	check("3-5 받는 순간 = niceReward(4.95 × 마리분 × M(계정 최고)) · 1칸 s1 = 3,000 · 39칸 s8,500", r1.gold == 3000 and r1.goldKills == nil and r1.enhanceStone == rows.free[1].enhanceStone
		and r85.gold == GoldCost.niceReward(math.floor(unit * 1800 * IS.getGoldMultiplier(8500))), ("%d · %d"):format(r1.gold, r85.gold))
	check("3-6 반복 보너스 = 10분(600마리분) · 토큰 1", Season.bonus.free.goldKills == 600 and Season.bonus.free.sparkleShard == 1 and Season.bonus.free.gold == nil)
	local sk = Mon.skippedFreeReward(Season, rows.free[2])
	check("3-7 건너뛴 칸: 마리분 골드도 성장 재화 → 토큰", sk.goldKills == nil and sk.gold == nil and sk.sparkleShard == 1)

	-- ══ 4 견습 완료 = 마리분 ══
	local TD = MODS.TutorialData
	check("4-1 견습 완료 = 100마리분(스테이지 20 = 500 · 1,000 = 1,500 - 1,342를 500 단위)", TD.tutorialCompletionGoldKills == 100 and GoldCost.rewardGold(unit, 100, 20) == 500 and GoldCost.rewardGold(unit, 100, 1000) == 1500,
		("%d · %d"):format(GoldCost.rewardGold(unit, 100, 20), GoldCost.rewardGold(unit, 100, 1000)))

	-- ══ 5 보너스 = 합 · 상한 +100% ══
	local GB = MODS.GoldBonus
	check("5-1 합(균열 +25% · 다른 +30% = +55%) · 상한(+60 · +70 = +100%) · 음수 · NaN = 0", near(GB.total({ 0.25, 0.3 }), 0.55) and GB.total({ 0.6, 0.7 }) == 1 and GB.total({ -1, 0 / 0, 0.25 }) == 0.25 and GB.total({}) == 0)
	check("5-2 처치 골드 = floor(기본 × (1 + 합) + 덤) · 반짝이 덤은 균열에 안 곱함(옛 (0.5g + 125u) × 1.25)", GB.killGold(100, { 0.25 }, 50) == 175 and GB.killGold(7, {}, 0) == 7)

	-- ══ 6 2^53 공용 검증 ══
	local NG = MODS.NumberGuard
	local g53, clamped = NG.gold(2 ^ 60)
	check("6-1 골드 상한 2^53(넘으면 자름) · 정상 그대로", g53 == 2 ^ 53 and clamped and select(1, NG.gold(12345)) == 12345 and not select(2, NG.gold(12345)))
	check("6-2 NaN · ±inf · 음수 · 숫자 아님 = 대체값(피해 · 체력 · 비용 같은 함수)", NG.amount(0 / 0) == 0 and NG.amount(math.huge) == 0 and NG.amount(-5) == 0 and NG.amount("9") == 0 and NG.amount(-1, 7) == 7 and NG.amount(3.5) == 3.5)
	check("6-3 비용 공용 검증: 음수 기본 비용 = 못 삼(math.huge)", GoldCost.cost(-100, 10, "enhance") == math.huge and GoldCost.cost(100, 1, "enhance") == 100)
	local SaveSystem = MODS.SaveSystem
	local p1, p2, p3 = { gold = 2 ^ 60 }, { gold = 0 / 0 }, { gold = "x" }
	SaveSystem.clampGold(p1)
	check("6-4 저장 직전 골드: 2^60 → 2^53 · NaN · 숫자 아님 = 기존 고침(기록 남김)에 맡김(그대로)", p1.gold == 2 ^ 53 and not SaveSystem.clampGold(p2) and p2.gold ~= p2.gold and not SaveSystem.clampGold(p3) and p3.gold == "x")

	-- ══ 7 보유 골드 환산 이관(v78 · G8) ══
	local function v77(best, gold)
		local d = SaveSystem.defaultProfile()
		d.version = 77
		d.gold = gold
		d.classes.bow = d.classes.bow or SaveSystem.defaultProfile().classes.bow
		d.classes.bow.stageProgress.infiniteBest = best
		return d
	end
	local a = SaveSystem.migrate(v77(8500, 1e9))
	local wantA = math.floor(1e9 * IS.getGoldMultiplier(8500) / 1.001 ^ 8499)
	check("7-1 계정 최고 8,500: 보유 × M_새 ÷ M_옛 · 기록 { from · to · stage } · 버전 78 이상", a.version >= 78 and a.gold == wantA and a.goldCurveRescale and a.goldCurveRescale.from == 1e9
		and a.goldCurveRescale.to == wantA and a.goldCurveRescale.stage == 8500, ("%s → %s"):format(tostring(1e9), tostring(a.gold)))
	local b = SaveSystem.migrate(v77(700, 54321))
	check("7-2 계정 최고 1,000 이하 = 숫자 그대로(배율 1)", b.gold == 54321 and b.goldCurveRescale.to == 54321)
	local c0 = v77(8500, 1e9)
	c0.goldCurveRescale = { from = 1, to = 1, stage = 1 }
	local c = SaveSystem.migrate(c0)
	check("7-3 기록이 있으면 다시 환산 안 함(멱등)", c.gold == 1e9)
	local n = SaveSystem.migrate({})
	check("7-4 새 계정(migrate({})) = 환산 기록 없음 · 버전 78 이상", n.goldCurveRescale == nil and n.version >= 78)
	local d = SaveSystem.migrate(v77(99999999, 1e6))
	check("7-5 손상된 큰 스테이지 = 하드 상한(25,300)으로 환산", d.goldCurveRescale.stage == ISC.hardMaxStage)
end)
if not ok then
	print("[GOLDC] 하네스 에러 " .. tostring(err))
end
print(("[GOLDC] 끝 %d/%d"):format(pass, total))
