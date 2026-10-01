import io, os, re, subprocess, sys, glob, tempfile

SP = os.path.dirname(os.path.abspath(__file__))
SRC = os.environ.get("ECON_SRC", os.path.join(SP, "..", "..", "src"))
LUAU = os.environ.get("LUAU", os.path.join(SP, "luau", "luau.exe"))
OUT = os.environ.get("OUT_DIR", tempfile.gettempdir())

def read(path):
    return io.open(path, encoding="utf-8").read()

def fix(src):
    src = re.sub(r"require\(ReplicatedStorage\.Shared\.(?:data\.)?(\w+)\)", r"MODS.\1", src)
    src = re.sub(r"require\(script\.Parent\.data\.(\w+)\)", r"MODS.\1", src)
    src = re.sub(r"require\(script\.Parent\.Parent\.(\w+)\)", r"MODS.\1", src)  # TitleData(shared/data) → shared/CodexRules
    src = re.sub(r"require\(script\.Parent\.(\w+)\)", r"MODS.\1", src)
    src = re.sub(r"require\(game:GetService\(\"ReplicatedStorage\"\)\.Shared\.(?:data\.)?(\w+)\)", r"MODS.\1", src)
    src = re.sub(r"(?m)^(\s*)(MODS\.\w+)\s*(--.*)?$", lambda m: m.group(1) + "local _ = " + m.group(2), src)
    return src

mods = {}
for path in glob.glob(os.path.join(SRC, "shared", "*.lua")) + glob.glob(os.path.join(SRC, "shared", "data", "*.lua")):
    mods[os.path.splitext(os.path.basename(path))[0]] = path
for name in ["EconSim", "EconSimTables", "EconSimReport", "EconSimVerify"] + [x for x in os.environ.get("EXTRA_SERVER", "").split(",") if x]:
    mods[name] = os.path.join(SRC, "server", name + ".lua")

prelude = read(os.path.join(SP, os.environ.get("PRELUDE", "server_prelude.luau")))
out = [prelude]
for name, path in mods.items():
    if name in ("DevToolsConfig",):
        continue
    out.append("LOADERS[%r] = function()\n%s\nend" % (name, fix(read(path))))
test = sys.argv[1] if len(sys.argv) > 1 else "dupe_test.luau"
out.append(read(test if os.path.isabs(test) else os.path.join(SP, test)))
dst = os.path.join(OUT, os.environ.get("ECON_OUT", "out_harness.luau"))
io.open(dst, "w", encoding="utf-8", newline="\n").write("\n".join(out).replace("LOADERS['", 'LOADERS["').replace("'] = function()", '"] = function()'))
res = subprocess.run([LUAU, dst], capture_output=True, text=True, encoding="utf-8", errors="replace")
io.open(os.path.join(OUT, os.environ.get("ECON_RES", "harness_result.txt")), "w", encoding="utf-8").write(res.stdout + res.stderr)
print("exit", res.returncode, "lines", (res.stdout + res.stderr).count("\n"))
