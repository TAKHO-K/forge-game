import itertools, json, sys
from all10 import load, metrics, simulate, speed, DEFAULT, PROFILES

DATA = {n: load(n) for n in PROFILES}


def summary(P):
    res = {}
    for n in PROFILES:
        rows = DATA[n]
        m = metrics(n, rows, P)
        base = simulate(rows, P, enable=False)
        S0 = m["S0"]
        brkBase = speed(base["track"], S0, S0 + P["breakL"])
        m["brkSame"] = (m["brk"] / brkBase) if (m["brk"] and brkBase) else None
        m["brkPre"] = (m["brk"] / m["pre"]) if (m["brk"] and m["pre"]) else None
        m["postRatio"] = (m["post"] / m["postBase"]) if (m["post"] and m["postBase"]) else None
        late = [s for s in m["segs"] if s["a"] >= 12000]
        m["maxSurplus"] = max((s["surplus"] for s in late), default=None)
        m["maxHold"] = max((s["holdH"] for s in late), default=None)
        res[n] = m
    return res


def score(res):
    top, nor = res["top"], res["normal"]
    t253 = top["new"].get(25300)
    ok = {}
    ok["top25300"] = t253 is not None and 2150 <= t253 <= 2400
    ok["brk"] = all(r["brkSame"] and 2.0 <= r["brkSame"] <= 3.0 for r in res.values())
    ok["post"] = all(r["postRatio"] and 0.9 <= r["postRatio"] <= 1.1 for r in res.values())
    ok["adv15k"] = all(r["advDone"] and abs(r["advDone"][1] - 15000) <= 1500 for r in (top, nor))
    ok["trans25k"] = (top["transDone"] is not None and top["transDone"][1] >= 23500) or (top["final"][0] >= 19)
    ok["surplus"] = all(r["maxSurplus"] is not None and r["maxSurplus"] <= 0.2 for r in res.values())
    ok["hold"] = all(r["maxHold"] is not None and r["maxHold"] <= 48 for r in res.values())
    return ok


def line(P, res, ok):
    top = res["top"]
    return "%s | top25300 %s | brkSame %s | post %s | adv %s | trans top %s | surplus %s | hold %s | %s" % (
        " ".join("%s=%g" % (k, P[k]) for k in ("transKills", "breakR", "curveKappa", "curveStart", "weaponBase", "advK0")),
        top["new"].get(25300), [round(r["brkSame"] or 0, 2) for r in res.values()], [round(r["postRatio"] or 0, 2) for r in res.values()],
        [(round(r["advDone"][1]) if r["advDone"] else None) for r in (res["top"], res["normal"])],
        top["transDone"] and round(top["transDone"][1]) or top["final"], [round(r["maxSurplus"] or 0, 2) for r in res.values()],
        [round(r["maxHold"] or 0) for r in res.values()], sum(ok.values()))


if __name__ == "__main__":
    grid = dict(transKills=[150000, 200000, 250000, 300000], breakR=[2.5], curveKappa=[0.0, 0.04, 0.08, 0.12], weaponBase=[1.25], advK0=[3200])
    for extra in sys.argv[1:]:
        k, v = extra.split("=")
        grid[k] = [float(x) for x in v.split(",")]
    keys = list(grid)
    best = []
    for vals in itertools.product(*(grid[k] for k in keys)):
        P = dict(DEFAULT)
        P.update(dict(zip(keys, vals)))
        res = summary(P)
        ok = score(res)
        print(line(P, res, ok), flush=True)
