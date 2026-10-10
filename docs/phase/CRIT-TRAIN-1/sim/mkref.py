# CRIT-TRAIN-1 몹 HP 보정 기준 빌드 표: 일반 프로필(중앙값) 실제 궤적 → CRITCFG.comp.ref Lua 표
# 사용: python mkref.py <OUT_DIR> <태그>  → { 스테이지, 넘침 전 치명 확률, 치명 피해 추가분(상한 전), 위력 버킷, 레벨 }(스테이지 창 ±10% 중앙값)
import sys, os, statistics
out, tag = sys.argv[1], sys.argv[2]
H = "t_h|reach|stage|tier|level|rebirth|rate|rawRate|base|lv|rb|opt|trn|critDmg|dmgRaw|overAtk|apb|atk|hitScale|mobHp|hitsNon|hitsCrit|hitsAvg|repHits|trRate|trDmg|trAtk|perm".split("|")
rows = []
for line in open(os.path.join(out, "r_cr_normal_%s.txt" % tag), encoding="utf-8", errors="replace"):
    if line.startswith("CR|"):
        rows.append(dict(zip(H, map(float, line.strip().split("|")[1:]))))
pts = [1, 100, 300, 500, 600, 700, 800, 1000, 1500, 2000, 2500, 3000, 3500, 4000, 5000, 6000, 7500, 8500, 10000, 12500, 15000, 20000, 25300, 40000]
res = []
for s in pts:
    win = [r for r in rows if s * 0.9 <= r["reach"] <= s * 1.1 + 5]
    if not win:
        win = [min(rows, key=lambda r: abs(r["reach"] - s))]
    md = lambda k: statistics.median(r[k] for r in win)
    res.append("{ %d, %.4f, %.4f, %.4f, %d }" % (s, md("rawRate"), md("dmgRaw"), md("apb"), md("level")))
print("{ " + ", ".join(res) + " }")
