# HP-SCALE-1 상수 H 고르기: D0 표(프로필 × 스테이지)에서 "몹 한 대 ÷ 내 한 대(비치명)"가 [1/10, 1/3] 안인 비율 · 중앙값.
# 사용: python hpgrid.py <OUT_DIR>
import os, sys
OUT = sys.argv[1]
data = {}
for p in ["casual", "normal", "top"]:
    for l in open(os.path.join(OUT, "r_hp_%s_D0.txt" % p), encoding="utf-8"):
        if l.startswith("HP|"):
            f = l.split("|")
            data.setdefault(p, []).append((int(f[1]), float(f[4]), float(f[6]), float(f[9])))
def med(v):
    v = sorted(v); return v[len(v) // 2]
for lo, hi, name in [(1, 1400, "1 ~ 1,400"), (1700, 25300, "1,700 ~ 25,300"), (1, 25300, "전체")]:
    print("==", name)
    for H in [1, 3, 5, 8, 10]:
        cells = []
        for p in ["casual", "normal", "top"]:
            r = [mh * H / atk for s, hp, atk, mh in data[p] if lo <= s <= hi]
            inside = sum(1 for x in r if 0.1 <= x <= 1 / 3)
            cells.append("%s 안 %d/%d 중앙 %.3f" % (p, inside, len(r), med(r)))
        print("H=%-2d %s" % (H, " | ".join(cells)))
