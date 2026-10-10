# PROG-2B-1 0번 분석: p2run 덤프(r_p2_<프로필>_<태그>.txt)의 도달 시간 · 사냥 간격(최고 − 사냥 스테이지, 시간 가중) · 보유 골드 비중.
# 사용: python an0.py <결과 폴더> <프로필> <태그,...>
import os, sys
D, PROF, TAGS = sys.argv[1], sys.argv[2], sys.argv[3].split(",")
MS = [1000, 5000, 10000, 15000, 20000, 25300]

def load(tag):
    rows, extra = [], {}
    for line in open(os.path.join(D, "r_p2_%s_%s.txt" % (PROF, tag)), encoding="utf-8"):
        f = line.rstrip("\n").split("|")
        if f[0] == "ROW":
            rows.append(dict(t=float(f[1]), reach=int(f[2]), bal=float(f[5]), inc=float(f[6]), sec=float(f[7]), stage=int(f[9])))
        elif f[0].startswith("X") or f[0] in ("STALL", "CPU"):
            extra[f[0]] = "|".join(f[1:])
    return rows, extra

def tAt(rows, s):
    for r in rows:
        if r["reach"] >= s:
            return r["t"]
    return float("nan")

base = None
print("태그 | " + " | ".join(str(m) for m in MS) + " | 25,300 대비 A | 사냥 간격(시간 가중 평균 · 구간 1,001~25,300) | 보유/수입(청크 끝 보유 ÷ 청크 수입 중앙)")
for tag in TAGS:
    rows, ex = load(tag)
    ts = [tAt(rows, m) for m in MS]
    if base is None:
        base = ts[-1]
    w = g = 0.0
    ratios = []
    for r in rows:
        if 1000 < r["reach"] <= 25300:
            w += r["sec"]
            g += r["sec"] * (r["reach"] - r["stage"])
            if r["inc"] > 0:
                ratios.append(r["bal"] / r["inc"])
    ratios.sort()
    med = ratios[len(ratios) // 2] if ratios else 0
    print("%s | %s | %+.2f%% | %.1f | %.2f | %s" % (tag, " | ".join("%.1f" % t for t in ts), (ts[-1] / base - 1) * 100, g / w if w else 0, med, ex.get("X_INC", "")))
