-- QUEUE-ALL9A 1-5 시즌 패스 하네스: 접속 패턴 6종 × 8주 → 도달 칸 · 완주 주차(주말 2배 · 보너스 칸 포함) + 주말 경계 시각.
--   실제 shared/Monetization(weekendWindow · passExpMultiplier · seasonReach) · SeasonPassData · QuestData · Quest.dailyFor를 쓴다.
--   실행: LUAU=<luau.exe> ECON_RES=res_season.txt python build_run.py season_pass_test.luau
--   가정: 접속 = 한국 저녁 20:00(UTC 11:00) · 접속한 날 = 접속 보상 + 그날 일간 전부 + 일일 상자 · 주간 미션 = 1 ~ 6주 차 끝(일요일)에 전부(주간 6회 - 근거 주석과 같다).
local Mon, Season, QuestData, Quest = MODS.Monetization, MODS.SeasonPassData, MODS.QuestData, MODS.Quest
local W = Season.weekend
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	pass += ok and 1 or 0
	print(("[SEASON] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end

local DAY, WEEK = 86400, 7 * 86400
local now0 = 1790000000 -- 2026-09 근처 아무 시각
local monday = now0 - (now0 - 4 * DAY) % WEEK -- 1970-01-05 = 월요일 → 이번 주 월요일 00:00 UTC

local function mult(source, t)
	return Mon.passExpMultiplier(source, (Mon.weekendWindow(t, W)), W)
end

-- ① 주말 경계(UTC 금 14:59/15:00 · 월 06:59/07:00) · 주간 미션은 2배 아님
local fri = monday + 4 * DAY
local nextMon = monday + WEEK
check("금 14:59:59 UTC = 1배", mult("daily", fri + 15 * 3600 - 1) == 1)
check("금 15:00:00 UTC = 2배(한국 토 00:00)", mult("daily", fri + 15 * 3600) == 2)
check("토 · 일 = 2배", mult("login", monday + 5 * DAY + 3600) == 2 and mult("chest", monday + 6 * DAY + 23 * 3600) == 2)
check("월 06:59:59 UTC = 2배(한국 월 15:59)", mult("daily", nextMon + 7 * 3600 - 1) == 2)
check("월 07:00:00 UTC = 1배(한국 월 16:00)", mult("daily", nextMon + 7 * 3600) == 1)
check("주말에도 주간 미션 = 1배", mult("weekly", monday + 5 * DAY + 3600) == 1)
local a1, s1, e1 = Mon.weekendWindow(nextMon + 3600, W)
check("월 01:00 창 = 지난 금 15:00 ~ 이번 월 07:00", a1 and s1 == fri + 15 * 3600 and e1 == nextMon + 7 * 3600)
local a2, s2 = Mon.weekendWindow(monday + 2 * DAY, W)
check("수요일 = 창 밖 · 다음 창 = 이번 금 15:00", not a2 and s2 == fri + 15 * 3600)

-- ② 하루 · 주간 경험치(데이터에서)
local function dailyExp(dayIndex)
	local n = 0
	for _, q in ipairs(Quest.dailyFor(dayIndex)) do
		n += q.reward.passExp or 0
	end
	return n
end
local weeklyExp = 0
for _, q in ipairs(QuestData.weekly) do
	weeklyExp += q.reward.passExp or 0
end
local loginExp, chestExp = QuestData.loginReward.passExp or 0, QuestData.dailyChest.passExp or 0
local full = Season.tiers * Season.expPerTier

-- ③ 패턴 6종 × 8주(요일 1 = 월 … 7 = 일)
local PATTERNS = {
	{ "매일", { 1, 2, 3, 4, 5, 6, 7 } },
	{ "주6(일 쉼)", { 1, 2, 3, 4, 5, 6 } },
	{ "평일만 주4(월 ~ 목)", { 1, 2, 3, 4 } },
	{ "주말2 + 평일2(화 · 목 · 토 · 일)", { 2, 4, 6, 7 } },
	{ "주말만(토 · 일)", { 6, 7 } },
	{ "주3(월 · 수 · 금)", { 1, 3, 5 } },
}
local function simulate(days, weeklies)
	local exp, finishWeek, weekendDays = 0, nil, 0
	for week = 1, 8 do
		for _, wd in ipairs(days) do
			local t = monday + (week - 1) * WEEK + (wd - 1) * DAY + 11 * 3600
			local dayIndex = math.floor(t / DAY)
			local m = mult("daily", t)
			weekendDays += m > 1 and 1 or 0
			exp += loginExp * mult("login", t) + dailyExp(dayIndex) * m + chestExp * mult("chest", t)
			if not finishWeek and exp >= full then
				finishWeek = week
			end
		end
		if week <= weeklies then
			exp += weeklyExp * mult("weekly", monday + (week - 1) * WEEK + 6 * DAY + 11 * 3600)
			if not finishWeek and exp >= full then
				finishWeek = week
			end
		end
	end
	local reach = Mon.seasonReach(exp, Season.expPerTier)
	return exp, math.min(reach, Season.tiers), math.max(0, reach - Season.tiers), finishWeek, weekendDays
end

print(("하루(평일) = 접속 %d + 일간 %d + 상자 %d · 주간 전부 = %d · 40칸 = %d × %d = %d"):format(loginExp, dailyExp(math.floor(monday / DAY)), chestExp, weeklyExp, Season.tiers, Season.expPerTier, full))
print("| 패턴 | 8주 접속일 | 그중 주말 2배 날 | 주간 6회: 경험치 · 칸 · 보너스 · 완주 주차 | 주간 0회: 경험치 · 칸 · 보너스 · 완주 주차 |")
print("|---|---|---|---|---|")
local results = {}
for _, p in ipairs(PATTERNS) do
	local e6, t6, b6, f6, wk = simulate(p[2], 6)
	local e0, t0, b0, f0 = simulate(p[2], 0)
	results[p[1]] = { t6 = t6, f6 = f6, b6 = b6, t0 = t0 }
	print(("| %s | %d | %d | %d · %d칸 · %d회 · %s | %d · %d칸 · %d회 · %s |"):format(p[1], #p[2] * 8, wk, e6, t6, b6, f6 and (f6 .. "주") or "못 함", e0, t0, b0, f0 and (f0 .. "주") or "못 함"))
end
check("평일만 주4 + 주간 6회 = 40칸 완주", results["평일만 주4(월 ~ 목)"].t6 == 40, ("완주 %s주"):format(tostring(results["평일만 주4(월 ~ 목)"].f6)))
check("매일 = 40칸 + 보너스 칸이 생김", results["매일"].t6 == 40 and results["매일"].b6 > 0, ("보너스 %d회"):format(results["매일"].b6))
check("주말만은 주말 2배로 평일만 주4의 절반 넘게", results["주말만(토 · 일)"].t6 >= 20)

-- ④ 보너스 칸 받기 규칙(canClaim): 41칸 = 보너스 · 도달 전 X · bonus 꺼짐 = bad_tier
local p0 = { premium = false, claimedFree = {}, claimedPaid = {} }
local reach = Mon.seasonReach(full + Season.expPerTier * 2 + 5, Season.expPerTier)
local okB1 = Mon.canClaim(p0, "free", 41, reach, Season.tiers, true)
local okB3, whyB3 = Mon.canClaim(p0, "free", 43, reach, Season.tiers, true)
local okOff, whyOff = Mon.canClaim(p0, "free", 41, reach, Season.tiers, false)
local okPaid, whyPaid = Mon.canClaim(p0, "paid", 41, reach, Season.tiers, true)
check("보너스 41 · 42칸 O · 43칸 not_reached · bonus 끔 bad_tier · 유료 줄 not_premium", okB1 and not okB3 and whyB3 == "not_reached" and not okOff and whyOff == "bad_tier" and not okPaid and whyPaid == "not_premium")
check("보너스 칸 보상 = 무료 토큰 1 + 골드 10분(PROG-2B-1 600마리분) · 유료 토큰 2(QUEUE-ALL9B 보완 5-1)", Season.rewardAt(1, "free", 41).sparkleShard == 1 and Season.rewardAt(1, "free", 41).goldKills == 600 and Season.rewardAt(1, "paid", 99).sparkleShard == 2 and Season.rewardAt(1, "free", 40).gliderSkin ~= nil)

print(("[SEASON] 끝 %d/%d"):format(pass, total))
