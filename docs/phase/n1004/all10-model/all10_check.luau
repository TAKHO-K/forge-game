local M = MODS
local A = M.EconSimAll10
local off = A.runIfEnabled({ chunks = {} })
print("SWITCH|기본 꺼짐 → " .. tostring(off))
for _, prof in ipairs({ "top", "normal" }) do
	local run = M.EconSim.runProgress(prof, {})
	local o = A.overlay(run, M.EconSimConfig.all10, true)
	print(("ALL10|%s|S0 %d|25300 %.4f|15000 %.4f|adv %s|trans %.2f"):format(prof, o.S0, o.reached[25300] or -1, o.reached[15000] or -1, o.advDoneAt and ("%.1f"):format(o.advDoneAt[2]) or "-", o.final.trans))
end
print("[ALL10] 끝")
