# HP-SCALE-1 결과 대조: 기준(B) 대비 시나리오의 도달 시간 · 청크별 생존 타수 비.
# 사용: python hpan.py <OUT_DIR> <시나리오...>
import os, sys
OUT = sys.argv[1]
SCENS = sys.argv[2:]
PROFS = ["casual", "normal", "top", "unluckyP90"]
MILES = [100, 500, 1000, 2000, 5000, 8500, 15000, 25300]

def load(p, sc):
    rows, hc = [], []
    for l in open(os.path.join(OUT, "r_hp_%s_%s.txt" % (p, sc)), encoding="utf-8"):
        f = l.rstrip("\n").split("|")
        if f[0] == "ROW":
            rows.append((float(f[1]), int(f[2])))
        elif f[0] == "HC":
            hc.append((int(f[1]), int(f[2]), int(f[3]), float(f[4]), float(f[5]), float(f[6]), float(f[7])))
    return rows, hc

def reach_h(rows, m):
    for t, r in rows:
        if r >= m:
            return t
    return None

for p in PROFS:
    br, bh = load(p, "B")
    print("== %s (B 청크 %d)" % (p, len(br)))
    print("B   " + " ".join("%d:%.1fh" % (m, reach_h(br, m) or -1) for m in MILES))
    for sc in SCENS:
        r, h = load(p, sc)
        line = []
        for m in MILES:
            a, b = reach_h(br, m), reach_h(r, m)
            line.append("%d:%+.2f%%" % (m, (b / a - 1) * 100) if a and b else "%d:-" % m)
        # 같은 (도달 · 사냥 스테이지 · 최대 체력 무관) 열쇠로 짝짓기 - 경로가 같으면 전부 짝이 된다
        same = len(r) == len(br) and all(x[1] == y[1] for x, y in zip(r, br))
        key = {}
        for y in bh:
            key.setdefault((y[1], y[2]), y)
        ratios, bratios = [], []
        for x in h:
            y = key.get((x[1], x[2]))
            if not y:
                continue
            if y[3] > 0:
                ratios.append(x[3] / y[3])
            if y[4] > 0 and x[4] > 0:
                bratios.append(x[4] / y[4])
        def st(v):
            if not v:
                return "-"
            v = sorted(v)
            return "min %.4f · max %.4f · 2%% 밖 %d/%d" % (v[0], v[-1], sum(1 for q in v if abs(q - 1) > 0.02), len(v))
        print("%-3s %s | 청크 %d 경로같음=%s" % (sc, " ".join(line), len(r), same))
        print("    몹 생존 타수 비: %s" % st(ratios))
        print("    보스 강공격 생존 타수 비: %s" % st(bratios))

# 구간별 생존 타수 중앙값(경로가 달라도 비교 가능) - 사냥 몹 · 보스 강공격
BANDS = [(1, 100), (101, 500), (501, 1000), (1001, 2000), (2001, 5000), (5001, 10000), (10001, 25300)]
def med(v):
    v = sorted(v)
    return v[len(v) // 2] if v else 0
print()
print("구간별 중앙값(몹 타수 / 보스 강공격 타수)")
for p in PROFS:
    for sc in ["B"] + SCENS:
        _, h = load(p, sc)
        cells = []
        for a, b in BANDS:
            m1 = med([x[3] for x in h if a <= x[1] <= b])
            m2 = med([x[4] for x in h if a <= x[1] <= b and x[4] > 0])
            cells.append("%.2f/%.2f" % (m1, m2))
        print("%-10s %-3s %s" % (p, sc, " ".join(cells)))
