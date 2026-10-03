-- QUEUE-ALL9C 블록 1 화면 규칙 하네스(순수 shared 함수): 순위 "상위 약 n%"(LeaderboardRules.topPercent) 등.
-- 실행: LUAU=<luau.exe> PRELUDE=server_prelude.luau ECON_RES=res_ui.txt python build_run.py ui_rules_test.luau
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then pass += 1 end
	print(("[UI] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end
local ok, err = pcall(function()
	local LR = MODS.LeaderboardRules
	-- 구간 폭 50: 스테이지 0 ~ 49 = 0 · 50 ~ 99 = 1
	check("1-5 구간 번호(폭 50)", LR.histBucket(49, 50) == 0 and LR.histBucket(50, 50) == 1 and LR.histBucket(25300, 50) == 506 and LR.histBucket(nil, 50) == 0)
	local counts = { ["0"] = 600, ["1"] = 300, ["2"] = 90, ["10"] = 10 } -- 1,000명
	local p10 = LR.topPercent(counts, 520, 50) -- 맨 위 구간(10명 중 가운데) = (0 + 5 + 1) / 1000 = 0.6% → 1
	local p1 = LR.topPercent(counts, 60, 50) -- 위 100 + 같은 구간 150 + 1 = 251 / 1000 → 26%
	local p0 = LR.topPercent(counts, 10, 50) -- 위 400 + 300 + 1 = 701 → 71%
	check("1-5 상위 약 n%: 맨 위 1% · 중간 26% · 아래 71%", p10 == 1 and p1 == 26 and p0 == 71, ("%s · %s · %s"):format(tostring(p10), tostring(p1), tostring(p0)))
	check("1-5 빈 표 · 표 없음 = nil(옛 \"100위 밖\" 표시)", LR.topPercent({}, 100, 50) == nil and LR.topPercent(nil, 100, 50) == nil)
	check("1-5 음수 · 이상 값 칸 무시", LR.topPercent({ ["3"] = -5, x = 9, ["1"] = 10 }, 60, 50) == 60, tostring(LR.topPercent({ ["3"] = -5, x = 9, ["1"] = 10 }, 60, 50)))
end)
if not ok then print("[UI] 하네스 에러 " .. tostring(err)) end
print(("[UI] 끝 %d/%d"):format(pass, total))
