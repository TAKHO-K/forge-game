# QUEUE-ALL9E1 0-6: levelKills 격자 × 기준 빌드(refTranscend) 고정점 - 일반 프로필 궤적 → 표 → 다시(ITER번) → 4프로필 최종
# 사용: python fit.py <lk1,lk2,...> [ITER] [extra A10_SET]
import os, subprocess, sys, threading
SP = os.path.dirname(os.path.abspath(__file__))
lks = [x for x in sys.argv[1].split(",")]
ITER = int(sys.argv[2]) if len(sys.argv) > 2 else 2
EXTRA = sys.argv[3] if len(sys.argv) > 3 else ""
START_REF = "{ { 15000, 0 }, { 16150, 1 }, { 17860, 2 }, { 18735, 3 }, { 19340, 4 }, { 19820, 5 }, { 19980, 6 }, { 20745, 7 }, { 21435, 8 }, { 22000, 9 }, { 22450, 10 }, { 22645, 11 }, { 22725, 12 }, { 22815, 13 }, { 22930, 14 }, { 23080, 15 }, { 23660, 16 }, { 23810, 17 }, { 24665, 18 }, { 24965, 19 }, { 25380, 20 } }"

def run(prof, tag, sets):
    env = dict(os.environ, A10_SET=sets)
    subprocess.run([sys.executable, os.path.join(SP, "a10run.py"), prof, "on", tag], env=env, stdout=subprocess.DEVNULL)
    return os.path.join(SP, "r_a10_%s_on%s.txt" % (prof, tag))

def traj(path):
    pts = {}
    for l in open(path, encoding="utf-8", errors="replace"):
        p = l.strip().split("|")
        if p[0] == "TLV":
            pts[int(p[1])] = int(p[3])
    ks = sorted(k for k in pts if k <= 20)
    if not ks:
        return None
    s1 = pts[ks[0]]
    out = ["{ %d, 0 }" % (s1 - 1000)]
    last = s1 - 1000
    for k in ks:
        s = max(pts[k], last + 1)
        out.append("{ %d, %d }" % (s, k))
        last = s
    return "{ " + ", ".join(out) + " }"

results = {}
def fit(lk):
    ref = START_REF
    base = "transcendEnhance.levelKills = %s" % lk + (";" + EXTRA if EXTRA else "")
    for i in range(ITER):
        path = run("normal", "_g%s_i%d" % (lk, i), base + ";monsterCurve.refTranscend = " + ref)
        new = traj(path)
        if new:
            ref = new
    sets = base + ";monsterCurve.refTranscend = " + ref
    ths = [threading.Thread(target=run, args=(p, "_g%s_fin" % lk, sets)) for p in ["casual", "normal", "top", "unluckyP90"]]
    [t.start() for t in ths]
    [t.join() for t in ths]
    results[lk] = ref
    open(os.path.join(SP, "refg_%s.txt" % lk), "w").write(ref)

ths = [threading.Thread(target=fit, args=(lk,)) for lk in lks]
[t.start() for t in ths]
[t.join() for t in ths]
print("done", list(results))
