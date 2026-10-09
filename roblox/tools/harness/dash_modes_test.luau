-- FINAL-1 3 MOVE-2 대시 모드 · 두 번 연속 누름(shared/DashModes) · 거리 식(JumpMath.dashRangeStuds 기본 거리 인자)
-- 실행: LUAU=<luau.exe> PRELUDE=server_prelude.luau ECON_RES=res_dash.txt python build_run.py dash_modes_test.luau
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then pass += 1 end
	print(("[DASH] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end
local function near(a, b) return math.abs(a - b) < 1e-6 end
local ok, err = pcall(function()
	local DM, DC, JM = MODS.DashModes, MODS.DashConfig, MODS.JumpMath
	local r, d = DM.base("long")
	check("긴 대시 = rangeStuds · durationSeconds", near(r, DC.rangeStuds) and near(d, DC.durationSeconds), ("%.2f %.2f"):format(r, d))
	r, d = DM.base("short")
	check("짧은 대시 = modes.short", near(r, DC.modes.short.rangeStuds) and near(d, DC.modes.short.durationSeconds), ("%.2f %.2f"):format(r, d))
	check("모르는 모드 = 긴 대시", near((DM.base("teleport")), DC.rangeStuds))
	local dz = DC.analog.deadzone
	check("기울기 deadzone 이하 = 짧은", near((DM.base("analog", dz * 0.5)), DC.modes.short.rangeStuds))
	check("기울기 1 = 긴", near((DM.base("analog", 1)), DC.rangeStuds))
	local mid = DM.base("analog", dz + (1 - dz) / 2)
	check("기울기 중간 = 가운데", near(mid, (DC.modes.short.rangeStuds + DC.rangeStuds) / 2), ("%.2f"):format(mid))
	check("기울기 1 넘음 = 긴(상한)", near((DM.base("analog", 5)), DC.rangeStuds))
	check("기울기 없음(nil) = 긴", near((DM.base("analog", nil)), DC.rangeStuds))
	-- 두 번 연속 누름
	local st = DM.newTapState()
	local w = DC.doubleTap.windowSeconds
	check("첫 누름 = 아님", DM.tap(st, "W", 10) == false)
	check("창 안 두 번째 = 연속", DM.tap(st, "W", 10 + w * 0.9) == true)
	check("세 번째(판정 뒤) = 아님", DM.tap(st, "W", 10 + w * 1.0) == false)
	check("창 밖 = 아님", DM.tap(st, "W", 10 + w * 3) == false)
	check("다른 키 = 아님", DM.tap(st, "A", 10 + w * 3 + 0.05) == false)
	check("그 키 다시 = 연속", DM.tap(st, "A", 10 + w * 3 + 0.1) == true)
	-- 거리 식(장비 걷기 배율 · 공중 배율 · 모드 기본 거리)
	check("짧은 대시 × 이속 상한", near(JM.dashRangeStuds(2, 1, DC.modes.short.rangeStuds), DC.modes.short.rangeStuds * DC.speedScaleMax))
	check("긴 대시 기본 인자 없음 = 옛 호출 그대로", near(JM.dashRangeStuds(1), DC.rangeStuds))
	check("긴 대시 최대(이속 상한 × 공중 1.25)", near(JM.dashRangeStuds(9, 1.25), DC.rangeStuds * DC.speedScaleMax * 1.25), ("%.2f"):format(JM.dashRangeStuds(9, 1.25)))
end)
if not ok then print("[DASH] 하네스 에러 " .. tostring(err)) end
print(("[DASH] 끝 %d/%d"):format(pass, total))
