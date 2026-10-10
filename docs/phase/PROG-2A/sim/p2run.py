# PROG-2A EconSim 러너(설계 시뮬 전용 - 게임 데이터 · 코드 안 바꿈). 실제 EconSim.runProgress를 로컬 luau 하네스로 돌리고,
# 시나리오 패치(Lua 조각 = 메모리 안에서만 MODS 값을 덮음)를 앞에 붙인다.
# 사용: LUAU=<luau.exe> python p2run.py <프로필> <태그> [시나리오.lua]
#   결과 = OUT_DIR(기본 %TEMP%)/r_p2_<프로필>_<태그>.txt (ROW 줄 = 레벨 청크 하나)
import os, subprocess, sys
SP = os.path.dirname(os.path.abspath(__file__))
HARNESS = os.path.normpath(os.path.join(SP, "..", "..", "..", "..", "roblox", "tools", "harness"))
prof, tag = sys.argv[1], sys.argv[2]
pre = ""
if len(sys.argv) > 3:  # 시나리오 = PROG2CFG 한 줄(파일) + p2lib.lua
    pre = 'P2PROF = "%s"\n' % prof + open(sys.argv[3], encoding="utf-8").read() + "\n" + open(os.path.join(SP, "p2lib.lua"), encoding="utf-8").read()
test = pre + """
local PROF = "%s"
local M = MODS
local t0 = os.clock()
local whatIf = (PROG2 and PROG2.whatIf) or {}
local run = M.EconSim.runProgress(PROF, whatIf)
local t = run.tutorialSeconds or 0
local prevBal, prevSp = 0, {}
print("HDR|t_h|reach|level|rebirth|bal|inc|sec|goldPerKill|stage|killSec|wlv|wgrade|trans|tr_atk|tr_hp|tr_def|spend...")
for _, c in ipairs(run.chunks) do
	local sec = c.seconds + c.bossSeconds
	t += sec
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
print(("CPU|%%.1f"):format(os.clock() - t0))
""" % prof
out = os.environ.get("OUT_DIR") or os.environ.get("TEMP") or "."
name = "p2_%s_%s.luau" % (prof, tag)
open(os.path.join(out, name), "w", encoding="utf-8").write(test)
env = dict(os.environ, OUT_DIR=out, ECON_OUT="o_" + name, ECON_RES="r_p2_%s_%s.txt" % (prof, tag),
	EXTRA_SERVER=os.environ.get("EXTRA_SERVER", "PlayerProfile,PartyState"), PRELUDE=os.environ.get("PRELUDE", "server_prelude.luau"))
subprocess.run([sys.executable, os.path.join(HARNESS, "build_run.py"), os.path.join(out, name)], env=env, cwd=HARNESS)
