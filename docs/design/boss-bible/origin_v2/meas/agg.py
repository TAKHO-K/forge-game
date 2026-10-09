"""측정 줄(rig/act|kind|dist|fwd|right|lock) → 스킬별 표본 수 · 최대 · 중앙값 · fwd/right 중앙값."""
import statistics
import sys

rows = {}
for f in sys.argv[1:]:
    for line in open(f, encoding="utf-8"):
        line = line.strip()
        if "|" not in line or "/" not in line.split("|")[0]:
            continue
        key, kind, d, fw, rt, lock = line.split("|")[:6]
        rows.setdefault(key, []).append((float(d), float(fw), float(rt), kind, lock))
for k in sorted(rows):
    v = rows[k]
    ds = [x[0] for x in v]
    print("%-38s n=%2d max %5.2f med %5.2f | fwd med %6.2f right med %6.2f | 맞춘 뒤 최대(중앙값 빼고) %5.2f | %s lock=%s" % (
        k, len(v), max(ds), statistics.median(ds), statistics.median([x[1] for x in v]), statistics.median([x[2] for x in v]),
        max(((x[1] - statistics.median([y[1] for y in v])) ** 2 + (x[2] - statistics.median([y[2] for y in v])) ** 2) ** 0.5 for x in v),
        ",".join(sorted(set(x[3] for x in v))), ",".join(sorted(set(x[4] for x in v)))))
