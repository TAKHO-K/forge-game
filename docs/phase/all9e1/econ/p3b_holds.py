# 계승 ~ +3,000: 옛 보유(보유 골드 ÷ 시간당 수입) vs 새 남는 골드 보유(max(0, 보유 − 다음 항목 비용) ÷ 시간당 수입) · 시간 가중
import sys, os
TAG = os.environ.get("TAG", "_x1")
def run(prof, tag=TAG, step=500, span=3000):
    rows, s0 = [], None
    for line in open("r_a10_%s_on%s.txt" % (prof, tag), encoding="utf-8", errors="replace"):
        p = line.strip().split("|")
        if p[0] == "ROW":
            nx = float(p[p.index("NXT") + 1])
            rows.append(dict(reach=int(p[2]), bal=float(p[3]), inc=float(p[4]), sec=float(p[6]), nxt=nx, trans=p[10], adv=int(p[11])))
        elif p[0] == "INH" and len(p) >= 3:
            s0 = int(p[2])
    out = []
    def agg(a, b):
        no = nn = w = mo = mn = 0; zero = 0; last = None
        for r in rows:
            if a <= r["reach"] < b and r["sec"] > 0 and r["inc"] > 0:
                rate = r["inc"] / (r["sec"] / 3600)
                ho = r["bal"] / rate
                ex = r["bal"] if r["nxt"] < 0 else max(0.0, r["bal"] - r["nxt"])
                hn = ex / rate
                no += ho * r["sec"]; nn += hn * r["sec"]; w += r["sec"]; mo = max(mo, ho); mn = max(mn, hn); last = r
                if r["nxt"] < 0: zero += r["sec"]
        return (no / w if w else 0, nn / w if w else 0, mo, mn, zero / w if w else 0, last)
    o, n, mo, mn, cap, _ = agg(s0, s0 + span)
    print("%-10s 계승 s%d · 옛 보유 %.1fh(최대 %.1f) · 새 남는 골드 %.2fh(최대 %.2f) · 살 것 없음 비율 %.1f%%" % (prof, s0, o, mo, n, mn, cap * 100))
    a = s0
    while a < s0 + span:
        o, n, mo, mn, cap, last = agg(a, a + step)
        if last: print("   s%d-%d 옛 %.1fh · 새 %.2fh(최대 %.2f) · 끝 초월 %s 고급 %d" % (a, a + step, o, n, mn, last["trans"], last["adv"]))
        a += step
for p in sys.argv[1:]: run(p)
