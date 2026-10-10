# PROG-2B-1 7: 기준선(PROG-2B 전) vs 합친 상태 - 초반 도달(h) · 25,300 · 몹 타수 · 치명 100%
import os, sys
D = sys.argv[1]
MS = [10, 50, 100, 300, 500, 1000, 2000, 5000, 10000, 25300]
def rows(path):
    out = []
    for line in open(path, encoding="utf-8"):
        f = line.split("|")
        if f[0] == "ROW":
            out.append((float(f[1]), int(f[2])))
    return out
def tAt(r, s):
    for t, reach in r:
        if reach >= s:
            return t
    return float("nan")
print("프로필 | 판 | " + " | ".join(str(m) for m in MS))
for p in ["casual", "normal", "top", "unluckyP90"]:
    for tag, d in [("기준선", os.path.join(D, "r9", "r_p2_%s_base.txt" % p)), ("합친", os.path.join(D, "r8", "r_p2_%s_cur.txt" % p))]:
        r = rows(d)
        print("%s | %s | %s" % (p, tag, " | ".join("%.2f" % tAt(r, m) for m in MS)))
