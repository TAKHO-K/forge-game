# QUEUE-ALL9E1 LOOK3 A: a10run.py + 청크마다 다음 항목 비용(NXT 열) - 남는 골드 재측정용. 사용: python p3b_run.py <prof> on <tag>
# QUEUE-ALL10 3-1: 실제 EconSim(runProgress) 프로필 × 스위치 끔/켬 덤프. 사용: python a10run.py <prof> <on|off>
import os, subprocess, sys
SP = os.path.dirname(os.path.abspath(__file__))
prof, mode = sys.argv[1], sys.argv[2]
tag = sys.argv[3] if len(sys.argv) > 3 else ""
sets = os.environ.get("A10_SET", "")
setLua = chr(10).join("MODS.All10Data.%s" % kv for kv in sets.split(";") if kv.strip())
test = setLua + """
ATTR.All10Economy = %s
ATTR.ResetMinus4 = %s
local PROF = "%s"
local M = MODS

local function nextCost(c)
	if not c.transcendLevel then return -1 end
	local A = M.All10
	local t = math.floor(c.transcendLevel + 1e-9)
	local adv, guard, reach = c.training.advanced or 0, c.training.guard or 0, c.reach
	local tCap, advCap = A.transcendCap(reach), A.advancedCap(reach, true)
	local guardOn, guardMax = A.defenseUnlocked(reach, true), M.All10Data.defenseTraining.maxLevel
	local nl = t + 1
	local cT = t < tCap and (A.transcendBand(nl) and A.transcendAttemptCost(nl, reach) or A.transcendSlotCost(reach)) or nil
	local cA = adv < advCap and A.advancedCost(adv, reach) or nil
	local cG = guardOn and guard < guardMax and A.defenseCost(guard, reach) or nil
	local prof = M.EconSimConfig.profiles[PROF]
	if prof and prof.all10Order then
		local item = A.nextSpend({ t = t, tCap = tCap, adv = adv, advCap = advCap, guard = guard, guardOn = guardOn, guardMax = guardMax, last = nil })
		if item == "transcend" and cT and cA and t >= M.All10Data.spendOrder.sureTo and adv >= M.All10Data.spendOrder.advancedTo then
			return math.min(cT, cA) -- 번갈아 구간: last를 모르므로 싼 쪽(남는 골드를 크게 잡는 쪽)
		end
		return item == "transcend" and cT or item == "advanced" and cA or item == "guard" and cG or -1
	end
	local m
	for _, v in ipairs({ cT or math.huge, cA or math.huge, cG or math.huge }) do if not m or v < m then m = v end end
	return m == math.huge and -1 or m
end
local t0 = os.clock()
local run = M.EconSim.runProgress(PROF, %s)
local t = run.tutorialSeconds or 0
local prevBal, prevSp = 0, 0
print("HDR|t_h|reach|bal|inc|spend|sec|perKill|wlv|grade|trans|adv|guard|sp_trans|sp_adv|sp_guard|tg")
for _, c in ipairs(run.chunks) do
	local sec = c.seconds + c.bossSeconds
	t += sec
	local sp = 0
	for _, v in pairs(c.spend) do sp += v end
	local inc = (c.goldBalance - prevBal) + (sp - prevSp)
	print(("ROW|%%.4f|%%d|%%.6g|%%.6g|%%.6g|%%.3f|%%.6g|%%d|%%d|%%s|%%d|%%d|%%.6g|%%.6g|%%.6g|%%.4f|%%s|%%d|%%.2f|%%d"):format(t / 3600, c.reach, c.goldBalance, inc, sp - prevSp, sec, c.goldPerKill or 0,
		c.weaponLevel or 0, c.weaponGrade or 0, c.transcendLevel and ("%%.2f"):format(c.transcendLevel) or "-", c.training and c.training.advanced or 0, c.training and c.training.guard or 0,
		c.spend.transcend or 0, c.spend.advanced or 0, c.spend.guard or 0, c.tgDrops or 0, tostring(c.limiter), c.stage or 0, c.killSeconds or 0, c.level or 0) .. ("|NXT|%%.6g"):format(nextCost(c)))
	prevBal, prevSp = c.goldBalance, sp
end
print(("INH|%%s"):format(run.inheritAt and ("%%.4f|%%d"):format(((run.tutorialSeconds or 0) + run.inheritAt.seconds) / 3600, run.inheritAt.stage) or "-"))
print(("ADV|%%s"):format(run.advancedDoneAt and ("%%.4f|%%d"):format(((run.tutorialSeconds or 0) + run.advancedDoneAt.seconds) / 3600, run.advancedDoneAt.stage) or "-"))
print(("TRD|%%s"):format(run.transcendDoneAt and ("%%.4f|%%d"):format(((run.tutorialSeconds or 0) + run.transcendDoneAt.seconds) / 3600, run.transcendDoneAt.stage) or "-"))
for lv, at in pairs(run.transcendAt or {}) do print(("TLV|%%d|%%.4f|%%d"):format(lv, ((run.tutorialSeconds or 0) + at.seconds) / 3600, at.stage)) end
print(("TAT|%%d"):format(run.final.transcendAttempts or 0))
print(("CPU|%%.1f"):format(os.clock() - t0))
""" % ("true" if mode == "on" else "false", "true" if mode == "on" else "false", prof, os.environ.get("A10_WHATIF", "{}"))
name = "x10_%s_%s%s.luau" % (prof, mode, tag)
open(os.path.join(SP, name), "w", encoding="utf-8").write(test)
env = dict(os.environ, ECON_OUT="o_" + name, ECON_RES="r_a10_%s_%s%s.txt" % (prof, mode, tag), EXTRA_SERVER=os.environ.get("EXTRA_SERVER", ""))
subprocess.run([sys.executable, os.path.join(SP, "mk_econ.py"), name], env=env)
