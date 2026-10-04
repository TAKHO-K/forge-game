# QUEUE-ALL9E1 0-6 / ADD E 판정 표: r_a10_<prof>_on<TAG>.txt + 끔 기준선 r_a10_<prof>_off_e1.txt
import os, sys
SP = os.path.dirname(os.path.abspath(__file__))
TAG = sys.argv[1]
PROFS = ["casual", "normal", "top", "unluckyP90"]

def load(path):
    rows, meta, tlv = [], {}, {}
    for line in open(path, encoding="utf-8", errors="replace"):
        p = line.strip().split("|")
        if p[0] == "ROW":
            rows.append(dict(t=float(p[1]), reach=int(p[2]), bal=float(p[3]), inc=float(p[4]), spend=float(p[5]), sec=float(p[6]), trans=None if p[10] == "-" else float(p[10]), adv=int(p[11]), guard=int(p[12])))
        elif p[0] in ("INH", "ADV", "TRD") and len(p) >= 3:
            meta[p[0]] = (float(p[1]), int(p[2]))
        elif p[0] == "TLV":
            tlv[int(p[1])] = (float(p[2]), int(p[3]))
    return rows, meta, tlv

def tAt(rows, s):
    for r in rows:
        if r["reach"] >= s:
            return r["t"]
    return None

def seg(rows, a, b):
    inc = sp = 0
    holds = []
    for r in rows:
        if a <= r["reach"] < b:
            inc += r["inc"]; sp += r["spend"]
            rate = r["inc"] / (r["sec"] / 3600) if r["sec"] > 0 else 0
            if rate > 0:
                holds.append((r["bal"] / rate, r["sec"]))
    w = sum(x[1] for x in holds)
    return ((inc - sp) / inc if inc > 0 else 0), (sum(x[0] * x[1] for x in holds) / w if w else 0)

def two53(rows):
    for r in rows:
        if r["bal"] >= 2 ** 53:
            return r["t"], r["reach"]
    return None

out = []
for prof in PROFS:
    on = os.path.join(SP, "r_a10_%s_on%s.txt" % (prof, TAG))
    off = os.path.join(SP, "r_a10_%s_off_e1.txt" % prof)
    if not os.path.exists(on):
        continue
    R, M, T = load(on)
    O, _, _ = load(off)
    s0 = M.get("INH", (None, None))[1]
    brk = rec = None
    if s0:
        a, b, c = s0, s0 + 1500, s0 + 3000
        on1, off1 = tAt(R, b) - tAt(R, a), tAt(O, b) - tAt(O, a)
        on2, off2 = (tAt(R, c) or 0) - tAt(R, b), (tAt(O, c) or 0) - tAt(O, b)
        brk = off1 / on1 if on1 > 0 else None
        rec = (off2 / on2) if on2 > 0 else None
    last_s, last_h = seg(R, 22500, 25300)
    post_s, post_h = seg(R, s0 or 0, (s0 or 0) + 3000)
    cap = T.get(20)
    bal_at_cap = None
    if cap:
        for r in R:
            if r["t"] >= cap[0]:
                bal_at_cap = r["bal"]; break
    out.append("## %s" % prof)
    out.append("계승 스테이지 %s · 시각 %.0fh" % (s0, M.get("INH", (0, 0))[0]))
    out.append("돌파 배수(같은 1,500 구간 끔 ÷ 켬) %.2f · 다음 1,500 %.2f" % (brk or 0, rec or 0))
    out.append("도달 h(끔 → 켬): 1,000 %.1f → %.1f · 15,000 %.0f → %.0f · 25,300 %.0f → %.0f" % (tAt(O, 1000), tAt(R, 1000), tAt(O, 15000), tAt(R, 15000), tAt(O, 25300) or -1, tAt(R, 25300) or -1))
    out.append("계승 뒤 3,000 잉여 %.1f%% · 보유 %.1fh / 22,500 ~ 25,300 잉여 %.1f%% · 보유 %.1fh" % (post_s * 100, post_h, last_s * 100, last_h))
    out.append("고급 100 %s · 초월 +20 %s · 천장(+20) 때 보유 골드 %s" % (M.get("ADV"), M.get("TRD"), ("%.3g" % bal_at_cap) if bal_at_cap else "-"))
    o53, r53 = two53(O), two53(R)
    out.append("2^53(끔 → 켬) %s → %s" % (o53, r53))
    out.append("초월 단계 도달(스테이지): " + " ".join("+%d s%d" % (k, T[k][1]) for k in sorted(T) if k in (1, 5, 6, 10, 15, 20, 25)))
print("\n".join(out))
