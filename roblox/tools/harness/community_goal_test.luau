-- QUEUE-ALL7 B5 하네스: 주간 합동 목표 = 끝 두 자리 00 · ±25% · 문턱 순서.
--   실행: LUAU=<luau.exe> ECON_RES=res_goal.txt python build_run.py community_goal_test.luau
local R, D = MODS.CommunityGoalRules, MODS.CommunityGoalData
local pass, total = 0, 0
local function check(label, ok)
	total += 1
	pass += ok and 1 or 0
	print(("[GOAL] %s %s"):format(label, ok and "O" or "X"))
end
local function is00(v)
	return type(v) == "number" and v % 100 == 0
end
local function thresholdsOk(target)
	local th = R.thresholds(target)
	local ok = #th == #D.tiers
	for i, v in ipairs(th) do
		ok = ok and is00(v) and (i == 1 or v > th[i - 1])
	end
	return ok and th[#th] == target, th
end
local function fmt(th)
	local t = {}
	for _, v in ipairs(th) do
		table.insert(t, tostring(v))
	end
	return table.concat(t, " < ")
end

print("| 입력 | 경로 | 목표 | 문턱(60 · 85 · 100%) | 00 · 순서 |")
-- ① 기준값(가중 평균 = 그 값) · 지난 목표 없음(제한 없음)
for _, base in ipairs({ 0, 7, 149, 150, 999, 1049, 12345 }) do
	local target = R.targetFromHistory({ { total = base } })
	local path = "지난주 기록"
	if not target then
		target = R.week1Target(base)
		path = "기록 0 → 1주차(24시간 " .. base .. ")"
	end
	local ok, th = thresholdsOk(target)
	local want = math.max(D.minTarget, R.round(base * D.targetFactor))
	print(("| %d | %s | %d | %s | %s |"):format(base, path, target, fmt(th), ok and "O" or "X"))
	check(("기준 %d → 목표 %d(00 · 최소 %d · 기대 ≥ %d)"):format(base, target, D.minTarget, want), ok and is00(target) and target >= D.minTarget and target >= (path == "지난주 기록" and want or D.minTarget))
end
-- ② 1주차 24시간 실측
for _, t24 in ipairs({ 0, 7, 149, 150, 999, 1049, 12345 }) do
	local target = R.week1Target(t24)
	local ok, th = thresholdsOk(target)
	local raw = t24 * 7 * D.week1Factor
	print(("| 24h %d | 1주차 × 7 × %.1f = %.1f | %d | %s | %s |"):format(t24, D.week1Factor, raw, target, fmt(th), ok and "O" or "X"))
	check(("1주차 24h %d → %d(반올림 %d · 최소 %d)"):format(t24, target, R.round(raw), D.minTarget), ok and target >= D.minTarget and math.abs(target - math.max(D.minTarget, R.round(raw))) <= 100)
end
-- ③ 지난주 대비 +60% · −60%(지난 목표 10,000 · 12,400 · 1,300)
for _, prev in ipairs({ 10000, 12400, 1300 }) do
	for _, change in ipairs({ 1.6, 0.4 }) do
		local base = prev * change / D.targetFactor -- 기준 × 0.95 = prev × change
		local target = R.targetFromHistory({ { total = base, target = prev } })
		local bound = prev * (change > 1 and (1 + D.weeklyChangeCap) or (1 - D.weeklyChangeCap))
		local ok, th = thresholdsOk(target)
		local within = math.abs(target - prev) <= prev * D.weeklyChangeCap + 100
		print(("| 지난 %d × %.1f | 제한 ±%d%% → %.0f | %d | %s | %s |"):format(prev, change, D.weeklyChangeCap * 100, bound, target, fmt(th), (ok and within) and "O" or "X"))
		check(("지난 목표 %d · 변화 ×%.1f → %d(제한값 %.0f · 차이 %d ≤ 100 · ±25%% 안 %s)"):format(prev, change, target, bound, math.abs(target - R.round(bound)), tostring(within)), ok and within and math.abs(target - math.max(D.minTarget, R.round(bound))) <= 100)
	end
end
-- ④ 순서 고정(반올림을 제한보다 먼저 하지 않는다): 지난 1,300 · 크게 오름 → 1,625 → 1,600(먼저 반올림했으면 기준 반올림 뒤 제한 = 1,625 그대로 00 아님)
local t = R.targetFromHistory({ { total = 99999, target = 1300 } })
check(("제한 → 반올림: 지난 1,300 · 크게 오름 → %d(기대 1,600)"):format(t), t == 1600)
-- ⑤ 칸 판정 = 00 문턱
local th = R.thresholds(12400)
check(("12,400 문턱 %s · 진행 7,399 = %d칸 · 7,400 = %d칸(60%% = 7,440 → 문턱 7,400 - 보이는 숫자로 판정)"):format(fmt(th), R.tiersReached(7399, 12400), R.tiersReached(7400, 12400)), R.tiersReached(7399, 12400) == 0 and R.tiersReached(7400, 12400) == 1)
-- ⑥ 작은 목표 = 85% · 100% 겹침 → 위 칸 +100 · 목표 = 마지막 칸
local small = R.week1Target(1)
local okS, thS = thresholdsOk(small)
check(("최솟값 목표 %d · 문턱 %s(겹치면 위 칸 +100 · 목표 = 마지막 칸)"):format(small, fmt(thS)), okS)
-- ⑦ 리뷰: 이미 정해진 옛 목표(00 아님)는 주 중간에 문턱이 안 바뀐다(닿은 칸이 뒤로 가지 않게)
local old = R.thresholds(1260)
check(("옛 목표 1,260 문턱 = %.0f · %.0f · %.0f(옛 식) · 합계 1,270 = %d칸 · 옛 목표 50 · 합계 60 = %d칸"):format(old[1], old[2], old[3], R.tiersReached(1270, 1260), R.tiersReached(60, 50)), R.tiersReached(1270, 1260) == 3 and R.tiersReached(60, 50) == 3 and old[3] == 1260)
print(("[GOAL] 끝 %d/%d"):format(pass, total))
