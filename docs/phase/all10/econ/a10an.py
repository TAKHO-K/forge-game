# QUEUE-ALL10 3-1 목표 판정(실제 EconSim 덤프 r_a10_<prof>_<on|off>.txt)
import os, sys, math
SP = os.path.dirname(os.path.abspath(__file__))
PROFS = ["casual", "normal", "top", "unluckyP90"]

TAG = sys.argv[1] if len(sys.argv) > 1 else ""
PROFS = sys.argv[2].split(",") if len(sys.argv) > 2 else PROFS
def load(prof, mode):
    rows, meta = [], {}
    p = os.path.join(SP, "r_a10_%s_%s%s.txt" % (prof, mode, TAG if mode == "on" else ""))
    if not os.path.exists(p):
        return None, None
    for line in open(p, encoding="utf-8", errors="replace"):
        parts = line.strip().split("|")
        if parts[0] == "ROW":
            rows.append(dict(t=float(parts[1]), reach=int(parts[2]), bal=float(parts[3]), inc=float(parts[4]), spend=float(parts[5]), sec=float(parts[6]),
                             perKill=float(parts[7]), wlv=int(parts[8]), grade=int(parts[9]), trans=None if parts[10] == "-" else float(parts[10]),
                             adv=int(parts[11]), guard=int(parts[12])))
        elif parts[0] in ("INH", "ADV", "TRD") and len(parts) >= 3:
            meta[parts[0]] = (float(parts[1]), int(parts[2]))
        elif parts[0] == "CPU":
            meta["CPU"] = float(parts[1])
    return rows, meta

def tAt(rows, stage):
    for r in rows:
        if r["reach"] >= stage:
            return r["t"]
    return None

def segment(rows, a, b):
    inc = sp = sec = 0
    holds = []
    for i, r in enumerate(rows):
        if a <= r["reach"] < b:
            inc += r["inc"]; sp += r["spend"]; sec += r["sec"]
            rate = r["inc"] / (r["sec"] / 3600) if r["sec"] > 0 else 0
            if rate > 0:
                holds.append((r["bal"] / rate, r["sec"]))
    surplus = (inc - sp) / inc if inc > 0 else 0
    tw = sum(w for _, w in holds)
    hold = sum(h * w for h, w in holds) / tw if tw > 0 else 0
    return surplus, hold, sec / 3600

out = []
res = {}
for prof in PROFS:
    on, mon = load(prof, "on")
    off, moff = load(prof, "off")
    if not on or not off:
        out.append("%s: 덤프 없음" % prof)
        continue
    r = res[prof] = {}
    r["t1000"] = (tAt(off, 1000), tAt(on, 1000))
    r["early"] = [(s, tAt(off, s), tAt(on, s)) for s in (100, 500, 1000, 2000, 5000)]
    r["mile"] = [(s, tAt(off, s), tAt(on, s)) for s in (10000, 12000, 15000, 20000, 25300)]
    inh = mon.get("INH")
    r["inh"] = inh
    if inh:
        S0 = inh[1]
        def span(rows, a, b):
            ta, tb = tAt(rows, a), tAt(rows, b)
            return (tb - ta) if ta is not None and tb is not None else None
        so, sn = span(off, S0, S0 + 1500), span(on, S0, S0 + 1500)
        r["break"] = (so / sn) if so and sn else None
        ro, rn = span(off, S0 + 1500, S0 + 3000), span(on, S0 + 1500, S0 + 3000)
        r["after"] = (ro / rn) if ro and rn else None
        segs = [(S0, 12000), (12000, 15000), (15000, 20000), (20000, 22500), (22500, 25300)]
        r["segs"] = [(a, b) + segment(on, a, b) for a, b in segs if b > a]
    r["adv"] = mon.get("ADV")
    r["trd"] = mon.get("TRD")
    last = on[-1]
    r["final"] = (last["reach"], last["trans"], last["adv"], last["guard"])
    b53 = next((x for x in on if x["bal"] >= 2 ** 53), None)
    b53o = next((x for x in off if x["bal"] >= 2 ** 53), None)
    r["b53"] = ((b53o["t"], b53o["reach"]) if b53o else None, (b53["t"], b53["reach"]) if b53 else None)
    r["cpu"] = (moff.get("CPU"), mon.get("CPU"))

def f(x, n=1):
    return "-" if x is None else ("%." + str(n) + "f") % x

for prof, r in res.items():
    out.append("## %s" % prof)
    out.append("캐주얼 1,000(끔 → 켬): %s → %s h" % (f(r["t1000"][0], 2), f(r["t1000"][1], 2)))
    out.append("초반 곡선(끔/켬 h): " + " · ".join("%d: %s/%s" % (s, f(a, 2), f(b, 2)) for s, a, b in r["early"]))
    out.append("고스테이지(끔 → 켬 h): " + " · ".join("%d: %s → %s" % (s, f(a), f(b)) for s, a, b in r["mile"]))
    out.append("계승: %s" % (("%.1fh · s%d" % r["inh"]) if r["inh"] else "-"))
    out.append("돌파 배수(같은 구간 끔 ÷ 켬): %s · 뒤 1,500 복귀: %s" % (f(r.get("break"), 2), f(r.get("after"), 2)))
    out.append("고급 수련 100: %s · 초월 +20: %s · 끝(스테이지 · 초월 · 고급 · 방어): %s" % (("%.1fh s%d" % r["adv"]) if r["adv"] else "-", ("%.1fh s%d" % r["trd"]) if r["trd"] else "-", str(r["final"])))
    for a, b, surplus, hold, hours in r.get("segs", []):
        out.append("  구간 %d ~ %d: %s h · 잉여율 %s%% · 보유 %s h" % (a, b, f(hours), f(surplus * 100), f(hold)))
    out.append("2^53(끔 → 켬): %s → %s" % (str(r["b53"][0]), str(r["b53"][1])))
    out.append("CPU 초(끔/켬): %s" % str(r["cpu"]))
print("\n".join(out))
