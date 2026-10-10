# CRIT-TRAIN-1 EconSim 러너(설계 시뮬 전용 - 게임 데이터 · 코드 안 바꿈). PROG-2A p2run.py와 같고, p2lib 뒤에 critlib.lua(치명 수련 · 넘침 전환 · 기록)를 붙인다.
# 사용: LUAU=<luau.exe> EXTRA_SERVER=<deps> python crun.py <프로필> <태그> [시나리오.lua]
#   시나리오 = "PROG2CFG = {...}"(PROG-2A · GOLD-CURVE-1 손잡이) + "CRITCFG = {...}"(이번 손잡이) 줄
#   결과 = OUT_DIR/r_cr_<프로필>_<태그>.txt (ROW = PROG-2A와 같은 줄 · CR = 청크별 치명 · 타수 줄)
import os, subprocess, sys
SP = os.path.dirname(os.path.abspath(__file__))
P2 = os.path.normpath(os.path.join(SP, "..", "..", "PROG-2A", "sim"))
HARNESS = os.path.normpath(os.path.join(SP, "..", "..", "..", "..", "roblox", "tools", "harness"))
prof, tag = sys.argv[1], sys.argv[2]
scen = open(sys.argv[3], encoding="utf-8").read() if len(sys.argv) > 3 else ""
pre = 'P2PROF = "%s"\n' % prof + scen + "\n" + open(os.path.join(P2, "p2lib.lua"), encoding="utf-8").read() + "\n" + open(os.path.join(SP, "critlib.lua"), encoding="utf-8").read()
test = pre + """
local PROF = "%s"
local M = MODS
local t0 = os.clock()
local whatIf = (PROG2 and PROG2.whatIf) or {}
local run = M.EconSim.runProgress(PROF, whatIf)
local t = run.tutorialSeconds or 0
local prevBal, prevSp = 0, {}
for _, c in ipairs(run.chunks) do
	local sec = c.seconds + c.bossSeconds
	t += sec
	c.__t = t / 3600
	local spTot, spPrev = 0, 0
	local parts = {}
	for k, v in pairs(c.spend) do
		spTot += v
		spPrev += prevSp[k] or 0
		table.insert(parts, k .. "=" .. ("%%.6g"):format(v))
	end
	table.sort(parts)
	local inc = (c.goldBalance - prevBal) + (spTot - spPrev)
	print(("ROW|%%.4f|%%d|%%d|%%d|%%.6g|%%.6g|%%.3f|%%.6g|%%d|%%.3f|%%d|%%d|%%s|%%d|%%d|%%d|%%s"):format(t / 3600, c.reach, c.level, c.rebirth, c.goldBalance, inc, sec, c.goldPerKill or 0,
		c.stage or 0, c.killSeconds or 0, c.weaponLevel or 0, c.weaponGrade or 0, c.transcendLevel and ("%%.2f"):format(c.transcendLevel) or "-",
		c.training.attack or 0, c.training.hp or 0, c.training.defense or 0, table.concat(parts, ",")))
	prevBal, prevSp = c.goldBalance, c.spend
end
for r, s in pairs(run.rebirthAt) do print(("RB|%%d|%%.4f"):format(r, ((run.tutorialSeconds or 0) + s) / 3600)) end
print(("INH|%%s"):format(run.inheritAt and ("%%.4f|%%d"):format(((run.tutorialSeconds or 0) + run.inheritAt.seconds) / 3600, run.inheritAt.stage) or "-"))
print(("STALL|%%s"):format(tostring(run.stall)))
if PROG2 and PROG2.report then PROG2.report(run) end
if CRIT and CRIT.report then CRIT.report(run) end
print(("CPU|%%.1f"):format(os.clock() - t0))
""" % prof
out = os.environ.get("OUT_DIR") or os.environ.get("TEMP") or "."
name = "cr_%s_%s.luau" % (prof, tag)
open(os.path.join(out, name), "w", encoding="utf-8").write(test)
env = dict(os.environ, OUT_DIR=out, ECON_OUT="o_" + name, ECON_RES="r_cr_%s_%s.txt" % (prof, tag),
	EXTRA_SERVER=os.environ.get("EXTRA_SERVER", "PlayerProfile,PartyState"), PRELUDE=os.environ.get("PRELUDE", "server_prelude.luau"))
subprocess.run([sys.executable, os.path.join(HARNESS, "build_run.py"), os.path.join(out, name)], env=env, cwd=HARNESS)
