# PROG-2A 결과 분석: p2run.py 덤프(r_p2_<프로필>_<태그>.txt)에서 도달 시간 · G(s)(분당 골드) · 구간 소모율 · 2^53 · 상한 도달을 뽑는다.
# 사용: python p2an.py <결과 폴더> <태그> [프로필 ...]
import os, sys
D, TAG = sys.argv[1], sys.argv[2]
PROFS = sys.argv[3:] or ["casual", "normal", "top"]
MS = [100, 1000, 5000, 10000, 15000, 20000, 25300]
SEGS = [(1, 100), (101, 1000), (1001, 5000), (5001, 10000), (10001, 17000), (17001, 25300)]
ESSENTIAL = {"enhance", "protection", "training", "ability", "transcend", "advanced", "guard", "gem", "awaken", "gemHome", "classAb"}

def load(prof, tag):
    p = os.path.join(D, "r_p2_%s_%s.txt" % (prof, tag))
    rows, extra = [], {}
    for line in open(p, encoding="utf-8"):
        f = line.rstrip("\n").split("|")
        if f[0] == "ROW":
            sp = {}
            for kv in f[17].split(","):
                if "=" in kv:
                    k, v = kv.split("=")
                    sp[k] = float(v)
            rows.append(dict(t=float(f[1]), reach=int(f[2]), level=int(f[3]), rb=int(f[4]), bal=float(f[5]), inc=float(f[6]), sec=float(f[7]),
                             gpk=float(f[8]), stage=int(f[9]), ks=float(f[10]), spend=sp, tr=(int(f[14]), int(f[15]), int(f[16]))))
        elif f[0] in ("INH", "STALL", "CPU", "RB") or f[0].startswith("X"):
            extra.setdefault(f[0], []).append("|".join(f[1:]))
    return rows, extra

def tAt(rows, s):
    for r in rows:
        if r["reach"] >= s:
            return r["t"]
    return None

def fmt(x):
    return "-" if x is None else ("%.1f" % x)

for prof in PROFS:
    try:
        rows, extra = load(prof, TAG)
    except FileNotFoundError:
        print(prof, "없음"); continue
    print("== %s [%s] STALL=%s INH=%s" % (prof, TAG, extra.get("STALL"), extra.get("INH")))
    print("도달h " + " ".join("%d:%s" % (s, fmt(tAt(rows, s))) for s in MS))
    b53 = next((r for r in rows if r["bal"] >= 2 ** 53), None)
    b50 = next((r for r in rows if r["bal"] >= 2 ** 50), None)
    print("2^53 %s · 2^50 %s · 최대 보유 %.3g" % (b53 and "%.0fh s%d" % (b53["t"], b53["reach"]), b50 and "%.0fh s%d" % (b50["t"], b50["reach"]), max(r["bal"] for r in rows)))
    # 구간: 수입 · 소모 비율(필수 = 성장) · G(s) 평균
    for a, b in SEGS:
        seg = [r for r in rows if a <= r["reach"] <= b]
        if not seg:
            continue
        inc = sum(r["inc"] for r in seg)
        sec = sum(r["sec"] for r in seg)
        i0 = rows.index(seg[0])
        before = rows[i0 - 1]["spend"] if i0 > 0 else {}
        after = seg[-1]["spend"]
        d = {k: after.get(k, 0) - before.get(k, 0) for k in after}
        tot = sum(d.values())
        ess = sum(v for k, v in d.items() if k in ESSENTIAL)
        top = sorted(((v, k) for k, v in d.items() if v > 0), reverse=True)[:4]
        print("  s%d-%d  %.1fh  G≈%.4g/분  소모 %.0f%%(필수 %.0f%%)  %s" % (a, b, sec / 3600, inc / max(sec, 1) * 60, 100 * tot / max(inc, 1), 100 * ess / max(inc, 1),
              " ".join("%s %.0f%%" % (k, 100 * v / max(tot, 1)) for v, k in top)))
    for k, v in extra.items():
        if k.startswith("X"):
            for x in v:
                print("  %s %s" % (k, x))
