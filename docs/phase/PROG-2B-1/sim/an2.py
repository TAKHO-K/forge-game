# PROG-2B-1 골드 지표: 보유 골드 최대 · 스테이지 ±5% 창의 분당 골드 G → 10만 · 25만 = 몇 분(GOLD-CURVE-1 §2 앵커 표와 같은 정의).
# 사용: python an2.py <결과 폴더> <태그> [프로필 ...]
import os, sys
D, TAG = sys.argv[1], sys.argv[2]
PROFS = sys.argv[3:] or ["casual", "normal", "top", "unluckyP90"]
MS = [1000, 3000, 5000, 8500, 15000, 25300]
print("프로필 | 보유 최대(스테이지) | " + " | ".join("s%d G · 10만 · 25만(분)" % s for s in MS))
for prof in PROFS:
    rows = []
    for line in open(os.path.join(D, "r_p2_%s_%s.txt" % (prof, TAG)), encoding="utf-8"):
        f = line.split("|")
        if f[0] == "ROW":
            rows.append(dict(reach=int(f[2]), bal=float(f[5]), inc=float(f[6]), sec=float(f[7])))
    mx = max(rows, key=lambda r: r["bal"])
    cells = []
    for s in MS:
        inc = sec = 0.0
        for r in rows:
            if s * 0.95 <= r["reach"] <= s * 1.05:
                inc += r["inc"]; sec += r["sec"]
        g = inc / (sec / 60) if sec > 0 else 0
        cells.append("%.0f · %.1f · %.1f" % (g, 1e5 / g, 2.5e5 / g) if g > 0 else "-")
    print("%s | %.3g(s%d) | %s" % (prof, mx["bal"], mx["reach"], " | ".join(cells)))
