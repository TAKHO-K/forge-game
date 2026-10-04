Random = { new = function(seed) math.randomseed(seed or 1); return { NextInteger = function(_, a, b) return math.random(a, b) end, NextNumber = function(_, a, b) a = a or 0; b = b or 1; return a + math.random() * (b - a) end } end }
-- QUEUE-ALL9B G(사용자 10-03) 강화 최상위 구간 · 초기화 바닥 · 방지 옵션(방지권 폐지) 하네스.
-- 순수 함수(Enhance) + 실제 서버 처리(EnhanceService.handleRequest - 가짜 플레이어를 강화대 위에 세운다) + 저장 이관(SaveSystem.migrate v68 환산).
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then pass += 1 end
	print(("[G] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end
local ok, err = pcall(function()
	local Enhance, Cfg, GoldCost = MODS.Enhance, MODS.EnhanceConfig, MODS.GoldCost
	local SaveSystem, PlayerProfile, WorldConfig = MODS.SaveSystem, MODS.PlayerProfile, MODS.WorldConfig

	-- ══ QUEUE-ALL9E1 0-3 스위치 ResetMinus4 켬: 도착점 = 시도 단계 − 4 · 불씨 유지 · 표 밖 nil ══
	ATTR.ResetMinus4 = true
	local m = {}
	for L = 22, 29 do m[L] = Enhance.getResetToLevel(L) end
	local m28 = Enhance.tryEnhance(28, 300, { false, false }, 0.999999)
	local args = Enhance.getResetFloorArgs()
	check("0-3 ResetMinus4 켬: +22 → 18 · +26 → 22 · +28 → 24 · +29 → 25 · +21 nil · +28 초기화 = 24(불씨 += 실패분) · 문구 = floorMinus", m[22] == 18 and m[26] == 22 and m[28] == 24 and m[29] == 25
		and Enhance.getResetToLevel(21) == nil and m28.result == "reset" and m28.level == 24 and m28.gauge == 300 + Enhance.getGaugeGain(28) and args.n == "4" and args.ex == "24" and args.floor ~= nil,
		("%s %d · %s"):format(m28.result, m28.level, tostring(args.floor)))
	local k3on = Enhance.getGuardMultiplier(Cfg.guardBands[3])
	ATTR.ResetMinus4 = false -- 아래 = 옛 고정 바닥(스위치 끔 = 지금 게임)
	check("0-3 방지 배수 k 재탐색: 켬 = 1.7 · 3.0 · 1.9 / 끔 = 1.7 · 3.0 · 2.1(옛 값)", k3on == 1.9 and Enhance.getGuardMultiplier(Cfg.guardBands[3]) == 2.1
		and Enhance.getGuardMultiplier(Cfg.guardBands[1]) == 1.7 and Enhance.getGuardMultiplier(Cfg.guardBands[2]) == 3.0)

	-- ══ G1 초기화 도착점 ══
	local resetTo = {}
	for L = 22, 29 do resetTo[L] = Enhance.getResetToLevel(L) end
	check("G1 초기화 도착점 +22 ~ +26 → 17 · +27 ~ +29 → 22", resetTo[22] == 17 and resetTo[26] == 17 and resetTo[27] == 22 and resetTo[29] == 22 and Enhance.getResetToLevel(21) == nil,
		("22 %s · 26 %s · 27 %s · 29 %s"):format(tostring(resetTo[22]), tostring(resetTo[26]), tostring(resetTo[27]), tostring(resetTo[29])))
	local r22 = Enhance.tryEnhance(22, 300, { false, false }, 0.999999)
	local r27 = Enhance.tryEnhance(27, 300, { false, false }, 0.999999)
	check("G1 초기화 뒤 불씨 유지(+22 → 17 · +27 → 22 · 불씨 += 실패분)", r22.result == "reset" and r22.level == 17 and r22.gauge == 300 + Enhance.getGaugeGain(22)
		and r27.result == "reset" and r27.level == 22 and r27.gauge == 300 + Enhance.getGaugeGain(27), ("%s %d %d · %s %d %d"):format(r22.result, r22.level, r22.gauge, r27.result, r27.level, r27.gauge))

	-- ══ G2 확률 · 불씨 ══
	local rates, noDrop = {}, true
	for L = 26, 29 do
		local p = Cfg.probability[L + 1]
		rates[L] = p
		noDrop = noDrop and p.down1 == 0 and p.down2 == 0
	end
	check("G2 +26 ~ +29 성공 4 · 2.5 · 1.5 · 1% · 초기화 0.5 · 0.6 · 0.8 · 1% · 하락 없음", noDrop and rates[26].success == 0.04 and rates[27].success == 0.025 and rates[28].success == 0.015 and rates[29].success == 0.01
		and rates[26].reset == 0.005 and rates[27].reset == 0.006 and rates[28].reset == 0.008 and rates[29].reset == 0.01)
	check("G2 경계: +25 시도 = 옛 규칙(성공 12% · 하락 4 · 2%) · +26 = 새 규칙", Cfg.probability[26].success == 0.12 and Cfg.probability[26].down1 == 0.04 and Cfg.probability[27].down1 == 0
		and Enhance.getGaugeGain(25) == math.floor(0.12 * 500 + 0.5) and Enhance.getGaugeGain(26) == 40, ("불씨 +25 %d · +26 %d"):format(Enhance.getGaugeGain(25), Enhance.getGaugeGain(26)))
	local nOk = true
	for L, N in pairs({ [26] = 25, [27] = 28, [28] = 30, [29] = 30 }) do
		local g = 0
		for i = 1, N do
			local r = Enhance.tryEnhance(L, g, { false, false }, 0.5) -- 유지(롤 0.5 = 유지 칸)
			nOk = nOk and r.result == "maintain" and (i < N and r.gauge < Cfg.gauge.max or r.gauge >= Cfg.gauge.max)
			g = r.gauge
		end
		local last = Enhance.tryEnhance(L, g, { false, false }, 0.999999)
		nOk = nOk and last.result == "success" and last.gaugeWasFull and last.gauge == 0
	end
	check("G2 N번 실패 → 다음 시도 확정 성공(N = 25 · 28 · 30 · 30 · 롤이 초기화 칸이어도)", nOk)

	-- ══ G3 비용 · 방지 옵션 ══
	local S = 1950
	local off26, on26 = Enhance.getCost(26, S, false, false), Enhance.getCost(26, S, false, true)
	local off19, on19 = Enhance.getCost(19, S, false, false), Enhance.getCost(19, S, true, false)
	local off22, on22, both22 = Enhance.getCost(22, S, false, false), Enhance.getCost(22, S, true, false), Enhance.getCost(22, S, true, true)
	check("G3 방지 켬 = 기본 × k(구간 1.7 · 3.0 · 2.1 · 끝자리 0 - niceReward)", on19 == GoldCost.niceReward(off19 * 1.7) and on22 == GoldCost.niceReward(off22 * 3.0) and both22 == on22
		and on26 == GoldCost.niceReward(GoldCost.cost(67200, S, "enhance") * 2.1) and off26 == GoldCost.niceReward(GoldCost.cost(67200, S, "enhance")) and on26 % 10 == 0 and off26 % 10 == 0,
		("+19 %d→%d · +22 %d→%d · +26 %d→%d"):format(off19, on19, off22, on22, off26, on26))
	check("G3 방지 구간 밖은 배수 없음(+18 · 켜도 같은 값) · +26 하락 방지는 못 켬", Enhance.getCost(18, S, true, true) == Enhance.getCost(18, S, false, false)
		and Enhance.getCost(26, S, true, false) == off26)
	local d1, r1 = Enhance.resolveProtectionFlags(19, false, true, true)
	local d2, r2 = Enhance.resolveProtectionFlags(22, false, true, true)
	local d3, r3 = Enhance.resolveProtectionFlags(26, false, true, true)
	local d4, r4 = Enhance.resolveProtectionFlags(27, true, true, true)
	local d5, r5 = Enhance.resolveProtectionFlags(18, false, true, true)
	check("G3 켤 수 있는 방지: +19 하락만 · +22 둘 다 · +26 초기화만 · 불씨 가득 = 없음 · +18 = 없음", d1 and not r1 and d2 and r2 and not d3 and r3 and not d4 and not r4 and not d5 and not r5)
	check("G3 ceilingDiscount 중복 할인 없음(+26 이상 = 스테이지 6,000에서도 배수 1)", Enhance.getCost(26, 6000, false, false) == GoldCost.niceReward(GoldCost.cost(67200, 6000, "enhance"))
		and Enhance.getCost(25, 6000, false, false) < GoldCost.cost(23800, 6000, "enhance"))
	local g1 = Enhance.tryEnhance(26, 0, { false, true }, 0.999999)
	local g2 = Enhance.tryEnhance(23, 0, { true, true }, 0.999999)
	local g3 = Enhance.tryEnhance(23, 0, { true, false }, 0.12 + 0.81 + 0.01)
	check("G3 방지 켬 → 초기화 · 하락 대신 유지(+26 초기화 · +23 초기화 · +23 하락)", g1.result == "maintain" and g1.blockedBy == "reset" and g1.level == 26 and g2.result == "maintain" and g2.blockedBy == "reset"
		and g3.result == "maintain" and g3.blockedBy == "drop", ("%s/%s · %s/%s · %s/%s"):format(g1.result, tostring(g1.blockedBy), g2.result, tostring(g2.blockedBy), g3.result, tostring(g3.blockedBy)))
	-- QUEUE-ALL9C 0-5(결정 3): 보스별 표 = 옛 방지권 장수 × 옛 상점가(niceReward) · 표 칸 = 지급 일정(getBossGrant)과 정확히 같음
	local tableOk, tableN, bad = true, 0, nil
	for stage in pairs(MODS.BossFirstClearGoldData) do
		local d, r = Enhance.getBossGrant(stage)
		local want = GoldCost.niceReward(d * Enhance.getProtectionPrice("drop", stage) + r * Enhance.getProtectionPrice("reset", stage))
		tableN += 1
		if d == 0 or Enhance.getBossGrantGold(stage) ~= want or want % 100 ~= 0 then tableOk, bad = false, stage end
	end
	local schedN, s0 = 0, Cfg.protection.bossGrant.firstStage
	while s0 <= MODS.InfiniteStageConfig.hardMaxStage do schedN += 1; s0 += Cfg.protection.bossGrant.stepStages end
	check("G3 보스 첫 처치 골드 = 보스별 표(옛 방지권 장수 × 옛 상점가 · 끝자리 00) · 표 칸 = 지급 일정 · 지급 없는 스테이지 0", tableOk and tableN == schedN and Enhance.getBossGrantGold(365) == 0
		and Enhance.getBossGrantGold(360) == 2000 and Enhance.getBossGrantGold(720) == 12000, ("표 %d칸 · 일정 %d칸 · 360 %d · 720 %d · 어긋난 칸 %s"):format(tableN, schedN, Enhance.getBossGrantGold(360), Enhance.getBossGrantGold(720), tostring(bad)))

	-- ══ 서버 처리(EnhanceService) ══
	local station = WorldConfig.huntingGround.center + WorldConfig.enhance.stationOffset
	local function makePlayer(name, id)
		local attrs = {}
		local root = { Position = station }
		local character = { FindFirstChild = function(_, n) return n == "HumanoidRootPart" and root or nil end, FindFirstChildOfClass = function() return nil end }
		return setmetatable({ Name = name, UserId = id, Parent = true, Character = character, DisplayName = name }, { __index = function(_, k)
			if k == "SetAttribute" then return function(_, n, v) attrs[n] = v end end
			if k == "GetAttribute" then return function(_, n) return attrs[n] end end
			if k == "FindFirstChild" or k == "WaitForChild" or k == "FindFirstChildOfClass" then return function() return nil end end
			if k == "IsA" then return function() return false end end
			if k == "GetAttributeChangedSignal" then return function() return { Connect = function() end } end end
			return nil
		end })
	end
	local EnhanceService = MODS.EnhanceService
	local pl = makePlayer("ForgeG", 77)
	PlayerProfile.init(pl, SaveSystem.migrate({}))
	PlayerProfile.setClassId(pl, "bow")
	PlayerProfile.setWeaponLevel(pl, 26)
	PlayerProfile.addMaterial(pl, "highEnhanceStone", 999)
	local stage = PlayerProfile.getAccountBestStage(pl)
	local cOff, cOn = Enhance.getCost(26, stage, false, false), Enhance.getCost(26, stage, false, true)
	PlayerProfile.addGold(pl, cOn - 1)
	local function clearCooldown() local t0 = os.clock(); while os.clock() - t0 < EnhanceService.requestCooldownSeconds + 0.05 do end end -- 요청 쿨다운(0.5초)을 실제로 기다린다
	clearCooldown()
	local before = PlayerProfile.getGold(pl)
	local res = EnhanceService.handleRequest(pl, false, true)
	check("서버: 방지 켬 비용(× k)보다 골드가 모자라면 시도 안 됨(골드 · 단계 그대로)", res and res.result == "insufficient_gold" and res.cost == cOn and PlayerProfile.getGold(pl) == before and PlayerProfile.getWeapon(pl).level == 26,
		res and ("%s 비용 %s · 골드 %d"):format(res.result, tostring(res.cost), PlayerProfile.getGold(pl)) or "nil")
	PlayerProfile.addGold(pl, 1)
	clearCooldown()
	EnhanceService.debugRolls[pl] = 0.999999 -- 초기화 칸(Studio 전용 표는 하네스에서 IsStudio = 가짜 prelude 값에 따른다)
	local g0 = PlayerProfile.getEnhanceGauge(pl)
	res = EnhanceService.handleRequest(pl, false, true)
	check("서버: 방지 켬 → 비용 × k 차감 · 결과 유지 · 단계 그대로 · 불씨 +", res and res.cost == cOn and PlayerProfile.getGold(pl) == 0 and PlayerProfile.getWeapon(pl).level == 26
		and (res.result == "maintain" or res.result == "success") and res.guarded == true, res and ("%s · 비용 %d · 불씨 %d → %d"):format(res.result, res.cost, g0, PlayerProfile.getEnhanceGauge(pl)) or "nil")
	PlayerProfile.addGold(pl, cOff)
	clearCooldown()
	res = EnhanceService.handleRequest(pl, true, false) -- +26 하락 방지는 없다 → 끔 비용
	check("서버: +26 하락 방지 요청 = 무시(끔 비용 · guarded 없음)", res and res.cost == cOff and res.guarded == nil, res and ("비용 %d"):format(res.cost) or "nil")

	-- ══ 저장 왕복 · v68 환산 ══
	local old = SaveSystem.migrate({})
	old.version = 67
	old.purchases.protectionTickets = { drop = 7, reset = 3 }
	old.purchases.protectionRefund = nil
	old.gold = 1000
	for _, cs in pairs(old.classes) do cs.stageProgress.infiniteBest = 1950 end
	local m = SaveSystem.migrate(old)
	local want = 7 * Enhance.getProtectionPrice("drop", 1950) + 3 * Enhance.getProtectionPrice("reset", 1950)
	check("v67 → v68 방지권 7 · 3장 → 골드 환산(상점가 × 장수 · 손해 0) · 키는 0장으로 남음", m.version >= 68 and m.gold == 1000 + want and m.purchases.protectionTickets.drop == 0 and m.purchases.protectionTickets.reset == 0
		and m.purchases.protectionRefund.gold == want and m.purchases.protectionRefund.drop == 7, ("골드 1000 → %d(+%d)"):format(m.gold, want))
	local again = SaveSystem.migrate(m)
	check("v68 환산 멱등(다시 돌려도 골드 그대로)", again.gold == m.gold)
	local bad = SaveSystem.migrate({})
	bad.version = 67
	bad.purchases.protectionRefund = nil
	bad.purchases.protectionTickets = { drop = 0, reset = 2 }
	bad.gold = 500
	for _, cs in pairs(bad.classes) do cs.stageProgress.infiniteBest = 1e12 end
	local mb = SaveSystem.migrate(bad)
	check("v68 환산: 손상된 큰 스테이지 = 상한으로 자름 · 0장 칸은 곱하지 않음(골드 NaN 아님)", mb.gold == mb.gold and mb.gold < math.huge and mb.purchases.protectionRefund.stage == MODS.InfiniteStageConfig.hardMaxStage,
		("골드 %s · 기준 스테이지 %s"):format(tostring(mb.gold), tostring(mb.purchases.protectionRefund.stage)))
	-- ══ QUEUE-ALL9C 0-1: ALL9B 리뷰 수정 지킴이 ══
	local linked = {}
	for L = 18, 29 do linked[L] = Enhance.guardsLinked(L) end
	check("리뷰: 방지 토글 묶음 = +22 ~ +25만(한 배수 구간) · +19 ~ +21 · +26 ~ +29 · +18 아님", linked[22] and linked[25] and not linked[21] and not linked[19] and not linked[26] and not linked[29] and not linked[18],
		("21 %s · 22 %s · 25 %s · 26 %s"):format(tostring(linked[21]), tostring(linked[22]), tostring(linked[25]), tostring(linked[26])))
	local noDrop26 = true
	for L = 26, Cfg.maxLevel - 1 do
		local p = Cfg.probability[L + 1]
		noDrop26 = noDrop26 and (p.down1 or 0) == 0 and (p.down2 or 0) == 0
	end
	local helpKo, helpEn = MODS.TextData.ko["enhance.help.detail"], MODS.TextData.en["enhance.help.detail"]
	check("리뷰: 도움말 \"+26부터 하락 없음\"(ko · en) = 확률표 +26 ~ +29 하락 0", noDrop26 and helpKo:find("+26부터는 하락이 없습니다", 1, true) ~= nil and helpEn:find("no drops from +26", 1, true) ~= nil)
	-- 회귀 블록 기대값 3(P2 C1.1 · P25a C5.2 · P25c D1)과 같은 규칙: +26 이상 비용 = niceReward · 0 ~ 29 비감소 · +25 ÷ +20 = 1.035^4
	local c11, monotone = true, true
	for level = 0, Cfg.maxLevel - 1 do
		local nice = level >= 26 and GoldCost.niceReward or function(n) return n end
		c11 = c11 and Enhance.getCost(level, 1) == nice(Cfg.goldCost[level + 1]) and Enhance.getCost(level, 100) == nice(math.floor(Cfg.goldCost[level + 1] * MODS.InfiniteStage.getGoldMultiplier(100)))
		if level > 0 then monotone = monotone and Enhance.getCost(level) >= Enhance.getCost(level - 1) end
	end
	local ratio = Cfg.goldCost[26] / Cfg.goldCost[21]
	check("리뷰: 회귀 블록 기대값 - P2 C1.1(+26 이상 niceReward) · P25a C5.2(비감소) · P25c D1(+25 ÷ +20 시도 = 1.035^5 · +20 20,000 · +16 14,900)", c11 and monotone
		and math.abs(ratio - 1.035 ^ 5) <= 0.01 and Cfg.goldCost[21] == 20000 and Cfg.goldCost[17] == 14900, ("C1.1 %s · 비감소 %s · 비 %.3f"):format(tostring(c11), tostring(monotone), ratio))
	local fresh = SaveSystem.migrate({})
	check("새 계정 = 환산 0 · 골드 0", fresh.purchases.protectionRefund.gold == 0 and fresh.gold == 0)
	local okValid = SaveSystem.isValidProfile == nil or SaveSystem.isValidProfile(m)
	check("환산 뒤 프로필 검사 통과(저장 가능)", okValid ~= false)
	-- 강화 상태 저장 왕복(단계 · 불씨)
	local snap = SaveSystem.migrate({})
	for _, cs in pairs(snap.classes) do cs.weapon = cs.weapon or {} end
	local profileOut = SaveSystem.migrate(table.clone(PlayerProfile.getProfile(pl))) -- getProfile = 저장되는 그 표
	if profileOut then
		local back = SaveSystem.migrate(profileOut)
		local ws
		for _, cs in pairs(back.classes) do if cs.weapon and cs.weapon.level == 26 then ws = cs.weapon end end
		check("강화 상태 저장 왕복(+26 · 불씨 유지)", ws ~= nil and ws.enhanceGauge == PlayerProfile.getEnhanceGauge(pl), ws and ("불씨 %s"):format(tostring(ws.enhanceGauge)) or "무기 없음")
	end
end)
if not ok then
	print("[G] 하네스 에러 " .. tostring(err))
end
print(("[G] 끝 %d/%d"):format(pass, total))
