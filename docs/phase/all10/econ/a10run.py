# QUEUE-ALL10 3-1: 실제 EconSim(runProgress) 프로필 × 스위치 끔/켬 덤프. 사용: python a10run.py <prof> <on|off>
import os, subprocess, sys
SP = os.path.dirname(os.path.abspath(__file__))
prof, mode = sys.argv[1], sys.argv[2]
tag = sys.argv[3] if len(sys.argv) > 3 else ""
sets = os.environ.get("A10_SET", "")
setLua = "
".join("MODS.All10Data.%s" % kv for kv in sets.split(";") if kv.strip())
test = setLua + """
ATTR.All10Economy = %s
local PROF = "%s"
local M = MODS
local t0 = os.clock()
local run = M.EconSim.runProgress(PROF, {})
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
		c.spend.transcend or 0, c.spend.advanced or 0, c.spend.guard or 0, c.tgDrops or 0, tostring(c.limiter), c.stage or 0, c.killSeconds or 0, c.level or 0))
	prevBal, prevSp = c.goldBalance, sp
end
print(("INH|%%s"):format(run.inheritAt and ("%%.4f|%%d"):format(((run.tutorialSeconds or 0) + run.inheritAt.seconds) / 3600, run.inheritAt.stage) or "-"))
print(("ADV|%%s"):format(run.advancedDoneAt and ("%%.4f|%%d"):format(((run.tutorialSeconds or 0) + run.advancedDoneAt.seconds) / 3600, run.advancedDoneAt.stage) or "-"))
print(("TRD|%%s"):format(run.transcendDoneAt and ("%%.4f|%%d"):format(((run.tutorialSeconds or 0) + run.transcendDoneAt.seconds) / 3600, run.transcendDoneAt.stage) or "-"))
print(("CPU|%%.1f"):format(os.clock() - t0))
""" % ("true" if mode == "on" else "false", prof)
name = "a10_%s_%s%s.luau" % (prof, mode, tag)
open(os.path.join(SP, name), "w", encoding="utf-8").write(test)
env = dict(os.environ, ECON_OUT="o_" + name, ECON_RES="r_a10_%s_%s%s.txt" % (prof, mode, tag), EXTRA_SERVER=os.environ.get("EXTRA_SERVER", "PlayerProfile,PartyState"))
subprocess.run([sys.executable, os.path.join(SP, "mk_econ.py"), name], env=env)
