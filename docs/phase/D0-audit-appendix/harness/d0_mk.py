import io, os, re, subprocess, sys, glob

SRC = r"C:\Users\xkrgh\vibe\game\roblox\src"
SP = os.path.dirname(os.path.abspath(__file__))
LUAU = os.path.join(SP, "luau", "luau.exe")

def read(path):
    return io.open(path, encoding="utf-8").read()

def fix(src):
    src = re.sub(r"require\(ReplicatedStorage\.Shared\.(?:data\.)?(\w+)\)", r"MODS.\1", src)
    src = re.sub(r"require\(script\.Parent\.(\w+)\)", r"MODS.\1", src)
    src = re.sub(r"require\(game:GetService\(\"ReplicatedStorage\"\)\.Shared\.(?:data\.)?(\w+)\)", r"MODS.\1", src)
    return src

def patch(src, old, new, count=1):
    n = src.count(old)
    assert n == count, (old, n)
    return src.replace(old, new)

def patch_econ(src):
    src = src.replace("\r\n", "\n")
    src = patch(src, "\tlocal levelAtRebirth = state.level\n",
                "\tlocal levelAtRebirth = state.level\n\tlocal __pre = loadoutFor(state)\n\tlocal __preReach = state.reach\n")
    src = patch(src, "\t\tstate.weaponGrade = #ArmorData.gradeOrder - 1\n\tend\nend\n",
                "\t\tstate.weaponGrade = #ArmorData.gradeOrder - 1\n\tend\n\tD0.onRebirth(state, profile, __pre, loadoutFor(state), levelAtRebirth, __preReach)\nend\n")
    src = patch(src, "\t\tgear = state.gear,\n", "\t\tgear = D0.gearFor(state),\n")
    src = patch(src, "\t\tlocal effectiveHp = data.hp / (profile.bossDpsEfficiency * profile.partySize)\n",
                "\t\tlocal effectiveHp = data.hp / (profile.bossDpsEfficiency * profile.partySize) / D0.deal(state, bossStage)\n")
    src = patch(src, "PlayerCombat.getNewbieDamageMultiplier(bossStage)) < profile.minSurviveHits",
                "PlayerCombat.getNewbieDamageMultiplier(bossStage) * D0.take(state, bossStage)) < profile.minSurviveHits")
    src = patch(src, "\twhile state.reach < cap do\n", "\twhile state.reach < cap and not D0.stop do\n")
    src = patch(src, "\t\ttable.insert(run.chunks, chunk)\n", "\t\ttable.insert(run.chunks, chunk)\n\t\tD0.afterChunk(state, run, profile)\n")
    return src

mods = {}
for path in glob.glob(os.path.join(SRC, "shared", "*.lua")) + glob.glob(os.path.join(SRC, "shared", "data", "*.lua")):
    mods[os.path.splitext(os.path.basename(path))[0]] = path
for name in ["EconSim", "EconSimTables", "EconSimReport", "EconSimVerify"]:
    mods[name] = os.path.join(SRC, "server", name + ".lua")

prelude = read(os.path.join(SP, "econ_prelude.luau"))
out = [prelude]
for name, path in mods.items():
    if name in ("DevToolsConfig",):
        continue
    s = fix(read(path))
    if name == "EconSim":
        s = patch_econ(s)
    out.append('LOADERS["%s"] = function()\n%s\nend' % (name, s))
test = sys.argv[1]
out.append(read(os.path.join(SP, test)))
dst = os.path.join(SP, "out_d0.luau")
io.open(dst, "w", encoding="utf-8", newline="\n").write("\n".join(out))
res = subprocess.run([LUAU, dst], capture_output=True, text=True, encoding="utf-8", errors="replace")
resname = sys.argv[2] if len(sys.argv) > 2 else "d0_result.txt"
io.open(os.path.join(SP, resname), "w", encoding="utf-8").write(res.stdout + res.stderr)
print("exit", res.returncode, "lines", (res.stdout + res.stderr).count("\n"))
