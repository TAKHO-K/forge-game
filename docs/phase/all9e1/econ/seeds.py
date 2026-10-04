# QUEUE-ALL9E1 0-3: 상위 1% 프로필(강화 시드만 다름) 20개 × ResetMinus4 끔/켬 - 태초 +29 / +30 첫 도달 · 초기화 경험(스위치 All10 끔 = 계승 없이 +30까지)
# 사용: python seeds.py <minus4 true|false> <i0> <i1> [kvals "k1,k2,k3"]
import os, subprocess, sys
SP = os.path.dirname(os.path.abspath(__file__))
mode, i0, i1 = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
kv = sys.argv[4] if len(sys.argv) > 4 else ""
procs = []
for i in range(i0, i1):
    seed = 20260923 + i * 7919
    kset = ""
    if kv:
        ks = kv.split(",")
        kset = "\n".join("MODS.EnhanceConfig.guardBands[%d].costMultiplier = %s" % (j + 1, k) for j, k in enumerate(ks))
    test = """ATTR.All10Economy = false
ATTR.ResetMinus4 = %s
%s
MODS.EconSimConfig.profiles.top.seed = %d
local run = MODS.EconSim.runProgress("top", {})
local t0 = run.tutorialSeconds or 0
local st = run.final
local a = st.primordialAt or {}
local function f(x) return x and ("%%.4f|%%d|%%d"):format((t0 + x.seconds) / 3600, x.stage, x.resets) or "-|-|-" end
print(("SEED|%d|%%s|%%s|%%d"):format(f(a[29]), f(a[30]), st.resetCount or 0))
""" % (mode, kset, seed, seed)
    tag = "s%s_%d_%s" % (mode[0], i, kv.replace(",", "_"))
    name = "sd_%s.luau" % tag
    open(os.path.join(SP, name), "w", encoding="utf-8").write(test)
    env = dict(os.environ, ECON_OUT="o_" + name, ECON_RES="r_" + tag + ".txt", EXTRA_SERVER="")
    procs.append(subprocess.Popen([sys.executable, os.path.join(SP, "mk_econ.py"), name], env=env, stdout=subprocess.DEVNULL))
for p in procs:
    p.wait()
print("done")
