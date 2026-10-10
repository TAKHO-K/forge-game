# GOLD-CURVE-1 §2 앵커 표: 곡선별(A · B · C) 덤프에서 스테이지 s 근처 분당 골드 G(s) · "10만 = 몇 분" · "25만 = 몇 분" · 그 스테이지까지 보유 골드 최대.
#   §3 강화 표: X_LOG enh_* (그 단계 다음 1회 비용)을 주변 구간 평균 G로 나눈 분.
# 사용: python anchors.py <결과 폴더> <프로필> <태그 ...>
import os, sys
D, PROF, TAGS = sys.argv[1], sys.argv[2], sys.argv[3:]
ST = [1, 100, 500, 1000, 3000, 5000, 8500, 15000, 25300]

def load(tag):
    rows, logs = [], {}
    for line in open(os.path.join(D, "r_p2_%s_%s.txt" % (PROF, tag)), encoding="utf-8"):
        f = line.rstrip("\n").split("|")
        if f[0] == "ROW":
            rows.append((float(f[1]), int(f[2]), float(f[5]), float(f[6]), float(f[7])))
        elif f[0] == "X_LOG" and f[1].startswith("enh_"):
            logs[f[1][4:]] = (int(f[3]), float(f[4]))
    return rows, logs

def G(rows, s):
    lo, hi = (1, 60) if s <= 60 else (s * 0.95, s * 1.05)
    seg = [r for r in rows if lo <= r[1] <= hi]
    if not seg:  # 빨리 지나가는 구간(상위 1% 스테이지 100) = 범위를 넓힘
        seg = [r for r in rows if s * 0.7 <= r[1] <= s * 1.4]
    inc, sec = sum(r[3] for r in seg), sum(r[4] for r in seg)
    return inc / sec * 60 if sec > 0 else None

data = {t: load(t) for t in TAGS}
print("| 스테이지 | " + " | ".join("%s G(분당) · 10만 · 25만(분) · 보유 최대" % t for t in TAGS) + " |")
print("|---|" + "---|" * len(TAGS))
for s in ST:
    cells = []
    for t in TAGS:
        rows, _ = data[t]
        g = G(rows, s)
        held = max([r[2] for r in rows if r[1] <= s] or [0])
        cells.append("—" if not g else "%s · %s · %s · %.3g" % (format(round(g), ","), "%.1f" % (1e5 / g), "%.1f" % (2.5e5 / g), held))
    print("| %s | %s |" % (format(s, ","), " | ".join(cells)))
print()
keys = sorted(set(k for t in TAGS for k in data[t][1]))
print("| 강화 단계 | " + " | ".join("%s 스테이지 · 1회 비용 · 분" % t for t in TAGS) + " |")
print("|---|" + "---|" * len(TAGS))
for k in keys:
    cells = []
    for t in TAGS:
        rows, logs = data[t]
        if k not in logs:
            cells.append("—")
            continue
        reach, cost = logs[k]
        g = G(rows, reach)
        cells.append("%s · %.3g · %.1f" % (format(reach, ","), cost, cost / g))
    print("| %s | %s |" % (k, " | ".join(cells)))
