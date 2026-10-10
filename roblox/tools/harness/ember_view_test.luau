-- UI-1 6단계 불씨 칸 하네스(순수): 칸 수 = 05 v4 spec §2 표(+24 = 17칸 · 목업 22는 옛 값) · 가득까지 n번 · 하락 = 불씨 그대로 칸만 다시 나눔.
-- 실행: LUAU=<luau.exe> ECON_RES=res_ember.txt python build_run.py ember_view_test.luau
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then pass += 1 end
	print(("[EMBER] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end
local okRun, err = pcall(function()
	local E = MODS.EmberView
	local want = { [0] = 3, [7] = 3, [8] = 4, [10] = 4, [11] = 5, [13] = 5, [14] = 6, [16] = 6, [17] = 8, [19] = 8, [20] = 12, [22] = 12, [23] = 17, [24] = 17, [25] = 17, [26] = 25, [27] = 28, [28] = 30, [29] = 30 }
	local bad = {}
	for lv = 0, 29 do
		local c = E.compute(lv, 0).cells
		if want[lv] and want[lv] ~= c then
			table.insert(bad, ("+%d=%d(표 %d)"):format(lv, c, want[lv]))
		end
	end
	check("칸 수 = spec 표", #bad == 0, table.concat(bad, " "))
	check("+24 = 17칸", E.compute(24, 0).cells == 17, tostring(E.compute(24, 0).cells))
	check("불씨 0 = 가득까지 칸 수", E.compute(24, 0).left == 17)
	local v = E.compute(24, 270)
	check("27% = 가득까지 13번(목업 pc_01)", v.left == 13 and v.pct == 27, ("left %d pct %d"):format(v.left, v.pct))
	check("가득 = left 0 · full", E.compute(24, 1000).full and E.compute(24, 1000).left == 0)
	check("가득 = 칸 전부 칠함(+22)", E.compute(22, 1000).filled == E.compute(22, 1000).cells)
	local a, b = E.compute(24, 500), E.compute(22, 500)
	check("하락 = 불씨 % 그대로 · 칸만 다시", a.pct == b.pct and a.cells ~= b.cells, ("%d칸 → %d칸"):format(a.cells, b.cells))
	check("상한 +30 = 칸 0", E.compute(30, 0).cells == 0)
end)
if not okRun then
	print("[EMBER] 에러 " .. tostring(err))
end
print(("[EMBER] 끝 %d/%d"):format(pass, total))
