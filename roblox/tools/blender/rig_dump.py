# B3 리그 규격 → JSON 뽑기(Blender 없이 · luau CLI만). 결과 = roblox/tools/blender/rigs/<리그 id>.rig.json
# 사용: LUAU=<luau.exe 경로> python rig_dump.py moss_slime [다른 리그 id ...]
#   harness/build_run.py(shared 모듈 묶기)를 그대로 쓴다 - 임시 파일은 OUT_DIR(기본 %TEMP%)에.
import io, os, subprocess, sys, tempfile, json

HERE = os.path.dirname(os.path.abspath(__file__))
HARNESS = os.path.join(HERE, "..", "harness")
OUT = os.environ.get("OUT_DIR", tempfile.gettempdir())

def dump(rig_id):
    body = io.open(os.path.join(HERE, "rig_dump.luau"), encoding="utf-8").read()
    test = os.path.join(OUT, "rig_dump_%s.luau" % rig_id)
    io.open(test, "w", encoding="utf-8", newline="\n").write('RIG_ID = "%s"\n' % rig_id + body)
    env = dict(os.environ, PRELUDE="server_prelude.luau", ECON_OUT="out_rig_dump.luau", ECON_RES="res_rig_dump.txt", OUT_DIR=OUT)
    subprocess.run([sys.executable, os.path.join(HARNESS, "build_run.py"), test], cwd=HARNESS, env=env, check=True)
    text = io.open(os.path.join(OUT, "res_rig_dump.txt"), encoding="utf-8").read()
    if "===RIGJSON===" not in text:
        raise SystemExit("덤프 실패:\n" + text)
    raw = text.split("===RIGJSON===", 1)[1].split("===RIGJSON END===", 1)[0].strip()
    data = json.loads(raw)
    os.makedirs(os.path.join(HERE, "rigs"), exist_ok=True)
    dst = os.path.join(HERE, "rigs", rig_id + ".rig.json")
    parts = data.pop("parts")
    head = json.dumps(data, ensure_ascii=False)[:-1]
    rows = [json.dumps(p, ensure_ascii=False) for p in parts]
    io.open(dst, "w", encoding="utf-8", newline="\n").write(head + ', "parts": [\n  ' + ",\n  ".join(rows) + "\n]}\n")
    print("wrote", dst, "parts", len(parts))

if __name__ == "__main__":
    for rid in sys.argv[1:] or ["moss_slime"]:
        dump(rid)
