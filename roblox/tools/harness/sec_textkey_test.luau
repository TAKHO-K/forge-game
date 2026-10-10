-- SEC-FIX-1 12(VERIFY-6 #18) 없는 키 런타임 수집 · 키당 경고 1번(실제 shared/Text). 실행: LUAU=<luau.exe> PRELUDE=server_prelude.luau ECON_RES=res_sectk.txt python build_run.py sec_textkey_test.luau
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then pass += 1 end
	print(("[SECTK] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end
local okRun, err = pcall(function()
	local Text = MODS.Text
	local warns = 0
	local realWarn = warn
	warn = function(...) warns += 1 end
	local a = Text.format("ko", "sec.fix.no.such.key")
	local b = Text.format("ko", "sec.fix.no.such.key")
	warn = realWarn
	check("12 없는 키 = 키 문자열 그대로(옛과 같음)", a == "sec.fix.no.such.key" and b == a)
	check("12 없는 키 수집(Text.missingKeys) · 경고 키당 1번(옛 = 부를 때마다)", type(Text.missingKeys) == "table" and Text.missingKeys["sec.fix.no.such.key"] == "ko" and warns == 1, ("경고 %d"):format(warns))
end)
if not okRun then print("[SECTK] 하네스 에러 " .. tostring(err)) end
print(("[SECTK] 끝 %d/%d"):format(pass, total))
