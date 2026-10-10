# HP-SCALE-1 EconSim 러너(설계 시뮬 전용 - 게임 데이터 · 코드 안 바꿈). PROG-2A p2run.py와 같은 ROW 줄 + hplib.lua(H 시나리오 · HP 표).
# 사용: LUAU=<luau.exe> OUT_DIR=<폴더> EXTRA_SERVER=<deps> python hprun.py <프로필> <태그> [시나리오.lua]
#   시나리오 = "HPCFG = {...}" 줄(없으면 지금 게임) · 결과 = OUT_DIR/r_hp_<프로필>_<태그>.txt
import os, subprocess, sys
SP = os.path.dirname(os.path.abspath(__file__))
HARNESS = os.path.normpath(os.path.join(SP, "..", "..", "..", "..", "roblox", "tools", "harness"))
prof, tag = sys.argv[1], sys.argv[2]
scen = open(sys.argv[3], encoding="utf-8").read() if len(sys.argv) > 3 else ""
pre = scen + "\n" + open(os.path.join(SP, "hplib.lua"), encoding="utf-8").read()
test = pre + """
local PROF = "%s"
local M = MODS
local t0 = os.clock()
local run = M.EconSim.runProgress(PROF, {})
local t = run.tutorialSeconds or 0
for _, c in ipairs(run.chunks) do
	local sec = c.seconds + c.bossSeconds
	t += sec
	print(("ROW|%%.4f|%%d|%%d|%%d|%%.6g|%%.3f|%%d|%%.3f"):format(t / 3600, c.reach, c.level, c.rebirth, c.goldBalance, sec, c.stage or 0, c.killSeconds or 0))
end
print(("STALL|%%s"):format(tostring(run.stall)))
HPS.report(run, PROF)
print(("CPU|%%.1f"):format(os.clock() - t0))
""" % prof
out = os.environ.get("OUT_DIR") or os.environ.get("TEMP") or "."
name = "hp_%s_%s.luau" % (prof, tag)
open(os.path.join(out, name), "w", encoding="utf-8").write(test)
env = dict(os.environ, OUT_DIR=out, ECON_OUT="o_" + name, ECON_RES="r_hp_%s_%s.txt" % (prof, tag),
	EXTRA_SERVER=os.environ.get("EXTRA_SERVER", "PlayerProfile,PartyState"), PRELUDE=os.environ.get("PRELUDE", "server_prelude.luau"))
subprocess.run([sys.executable, os.path.join(HARNESS, "build_run.py"), os.path.join(out, name)], env=env, cwd=HARNESS)
