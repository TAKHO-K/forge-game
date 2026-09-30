# A2-M1 보스 디테일 JSON 뽑기(Blender 없이 · luau CLI만). 결과 = roblox/tools/blender/rigs/boss_detail.json
# 사용: LUAU=<luau.exe 경로> python detail_dump.py
import io, os, subprocess, sys, tempfile, json

HERE = os.path.dirname(os.path.abspath(__file__))
HARNESS = os.path.join(HERE, "..", "harness")
OUT = os.environ.get("OUT_DIR", tempfile.gettempdir())

if __name__ == "__main__":
    env = dict(os.environ, PRELUDE="motion_prelude.luau", ECON_OUT="out_detail_dump.luau", ECON_RES="res_detail_dump.txt", OUT_DIR=OUT)
    subprocess.run([sys.executable, os.path.join(HARNESS, "build_run.py"), os.path.join(HERE, "detail_dump.luau")], cwd=HARNESS, env=env, check=True)
    text = io.open(os.path.join(OUT, "res_detail_dump.txt"), encoding="utf-8").read()
    if "===DETAILJSON===" not in text:
        raise SystemExit("dump failed:\n" + text)
    raw = text.split("===DETAILJSON===", 1)[1].split("===DETAILJSON END===", 1)[0].strip()
    data = json.loads(raw)
    os.makedirs(os.path.join(HERE, "rigs"), exist_ok=True)
    dst = os.path.join(HERE, "rigs", "boss_detail.json")
    io.open(dst, "w", encoding="utf-8", newline="\n").write(json.dumps(data, ensure_ascii=False, indent=1))
    print("wrote", dst, {k: (len(v["joints"]), len(v["deco"])) for k, v in data.items()})
