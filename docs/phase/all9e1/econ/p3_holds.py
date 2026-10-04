# 계승 뒤 보유 시간(보유 골드 ÷ 시간당 수입) 구간별 · 무엇에 썼나. 사용: python holds.py <prof> <tag> [step]
import os, sys
SP = os.path.dirname(os.path.abspath(__file__))
prof, tag = sys.argv[1], sys.argv[2]
step = int(sys.argv[3]) if len(sys.argv) > 3 else 500
rows, s0 = [], None
for line in open(os.path.join(SP, "r_a10_%s_on%s.txt" % (prof, tag)), encoding="utf-8", errors="replace"):
    p = line.strip().split("|")
    if p[0] == "ROW":
        rows.append(dict(t=float(p[1]), reach=int(p[2]), bal=float(p[3]), inc=float(p[4]), spend=float(p[5]), sec=float(p[6]), trans=p[10], adv=int(p[11]), guard=int(p[12]),
                         sptr=float(p[13]), spadv=float(p[14]), spg=float(p[15])))
    elif p[0] == "INH" and len(p) >= 3:
        s0 = int(p[2])
a = s0
while a < s0 + 3000:
    b = a + step
    num = w = inc = sp = 0
    last = None
    for r in rows:
        if a <= r["reach"] < b and r["sec"] > 0 and r["inc"] > 0:
            num += r["bal"] / (r["inc"] / (r["sec"] / 3600)) * r["sec"]; w += r["sec"]; inc += r["inc"]; sp += r["spend"]; last = r
    if last:
        print("s%d-%d 보유 %.1fh · 잉여 %.0f%% · 끝 초월 %s 고급 %d 방어 %d · 누적 지출 초월 %.3g 고급 %.3g 방어 %.3g" % (a, b, num / w, (inc - sp) / inc * 100, last["trans"], last["adv"], last["guard"], last["sptr"], last["spadv"], last["spg"]))
    a = b
