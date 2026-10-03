# ALL10-P1 계승 뒤 오버레이 모형(설계 · 격자 탐색용 원형 - 확정 모형은 roblox/src/server/EconSimAll10.lua로 옮긴다)
import math, os, sys, json, itertools
SP = os.path.dirname(os.path.abspath(__file__))
LN = math.log(1.02)
GOLD = math.log(1.001)
PROFILES = ["casual", "normal", "top", "unluckyP90"]


def load(name, prefix="rd_"):
    rows = []
    for line in open(os.path.join(SP, prefix + name + ".txt"), encoding="utf-8"):
        if line.startswith("ROW|"):
            p = line.strip().split("|")
            rows.append(dict(t=float(p[1]), reach=int(p[2]), bal=float(p[3]), inc=float(p[4]), spend=float(p[5]), sec=float(p[6]), perKill=float(p[7]), wlv=int(p[8]), rb=int(p[9]), grade=int(p[10])))
    return rows


DEFAULT = dict(
    # 초월 무기(계승 직후 +0) = 태초 +30 대비 공격 배수
    weaponBase=1.25,
    # 초월 강화 0 → 20: 단계마다 공격 +a(합연산 - 무기 강화 줄에 더함) · 비용 = 처치 환산(kill-equivalent) = 효율 일정(%당 같은 처치 수)
    transPerLevel=0.05, transKills=250000, transSub=5,
    # 고급 수련 51 ~ 100: 단계마다 공격 +p · 비용 = k0 × r^(l-51) 처치 환산
    advPerLevel=0.01, advK0=3200, advR=1.03, advCapStart=10000, advCapStep=100,
    # 방어 수련(고급 수련 안): 개방 스테이지 · 단계 수 · 비용(처치 환산) - 처치 속도엔 영향 없음(생존 축)
    defUnlock=12000, defLevels=30, defK0=2000, defR=1.05,
    # 초월 보석(계승 보상 1개): 공격 배수
    gem=1.08,
    # 돌파(D3): 계승 스테이지부터 L 스테이지 동안 몹 HP 성장 × (1 - 1/R) 깎음 → 속도 R배
    breakL=1500, breakR=2.5,
    # 전역 곡선 재조정(R4 · R20): S_c 뒤 몹 HP 성장률 + kappa(스테이지당 ln1.02 몫)
    curveStart=12000, curveKappa=0.08,
)


def solve_stage(sb, lnM, S0, P):
    beta = 1 - 1 / P["breakR"]
    def f(s):
        x = s - S0
        lnB = -beta * LN * min(max(x, 0), P["breakL"])
        lnC = P["curveKappa"] * LN * max(0.0, s - P["curveStart"])
        return (s - sb) * LN + lnC + lnB - lnM
    lo, hi = sb - 3000, sb + 6000
    for _ in range(60):
        mid = (lo + hi) / 2
        if f(mid) > 0:
            hi = mid
        else:
            lo = mid
    return (lo + hi) / 2


def simulate(rows, P, enable=True, cap=25300):
    i30 = next((i for i, r in enumerate(rows) if r["wlv"] >= 30 and r["grade"] >= 6), None)
    out = dict(i30=i30, events=[])
    if i30 is None:
        return out
    S0 = rows[i30]["reach"]
    t0 = rows[i30]["t"]
    trans, adv, dfn = 0, 50, 0
    bal = rows[i30]["bal"]
    track = []
    spendNew = dict(trans=0.0, adv=0.0, dfn=0.0)
    defUnlocked = False
    reached = {}
    advDoneAt = transDoneAt = None
    for i in range(i30, len(rows)):
        r = rows[i]
        sb = r["reach"]
        if not enable:
            s = sb; M = 1.0
        else:
            M = P["weaponBase"] * (1 + trans / P["transSub"] * P["transPerLevel"]) * (1 + (adv - 50) * P["advPerLevel"]) * P["gem"]
            s = solve_stage(sb, math.log(M), S0, P)
        s = min(s, cap)
        factor = math.exp(GOLD * (s - sb))
        inc = r["inc"] * factor
        sp = r["spend"] * factor
        perKill = r["perKill"] * factor
        bal += inc - sp
        newSp = 0.0
        if enable:
            # 사고 싶은 것 중 처치 환산이 가장 싼 것부터(그때 스테이지 골드로 환산)
            bought = True
            while bought:
                bought = False
                opts = []
                if trans < 20 * P["transSub"]:
                    opts.append(("trans", P["transKills"] / P["transSub"]))
                advCap = min(100, 50 + max(0, int((s - P["advCapStart"]) // P["advCapStep"])))
                if adv < advCap:
                    opts.append(("adv", P["advK0"] * P["advR"] ** (adv - 50)))
                if s >= P["defUnlock"] and dfn < P["defLevels"]:
                    opts.append(("dfn", P["defK0"] * P["defR"] ** dfn))
                opts.sort(key=lambda o: o[1])
                for kind, kills in opts:
                    cost = kills * perKill
                    if bal >= cost:
                        bal -= cost; newSp += cost; spendNew[kind] += cost
                        if kind == "trans":
                            trans += 1
                            if trans == 20 * P["transSub"]: transDoneAt = (r["t"], s)
                        elif kind == "adv":
                            adv += 1
                            if adv == 100: advDoneAt = (r["t"], s)
                        else:
                            dfn += 1
                        bought = True
                        break
        for m in (1000, 5000, 10000, 12000, 15000, 20000, 25300):
            if m not in reached and s >= m:
                reached[m] = r["t"]
        track.append((r["t"], s, sb, inc, sp + newSp, bal, M if enable else 1.0, trans, adv, dfn))
        if s >= cap:
            break
    out.update(S0=S0, t0=t0, track=track, reached=reached, advDoneAt=advDoneAt, transDoneAt=transDoneAt, final=(trans / P["transSub"], adv, dfn), spendNew=spendNew)
    return out


def speed(track, s_from, s_to):
    ta = tb = None
    for t, s, *_ in track:
        if ta is None and s >= s_from: ta = t
        if tb is None and s >= s_to: tb = t; break
    if ta is None or tb is None or tb <= ta:
        return None
    return (s_to - s_from) / (tb - ta)


def metrics(name, rows, P):
    base = simulate(rows, P, enable=False)
    new = simulate(rows, P, enable=True)
    S0, t0 = new["S0"], new["t0"]
    # 직전 속도 = 계승 직전 300 스테이지(기준선) · 돌파 = 계승 뒤 1,500 스테이지 · 복귀 = 그 뒤 1,500 스테이지(같은 구간 기준선 대비)
    pre = speed([(r["t"], r["reach"]) for r in rows], S0 - 300, S0)
    brk = speed(new["track"], S0, S0 + P["breakL"])
    post = speed(new["track"], S0 + P["breakL"], S0 + 2 * P["breakL"])
    postBase = speed(base["track"], S0 + P["breakL"], S0 + 2 * P["breakL"])
    # 골드: 구간별 유입 · 소모 · 보유 · 보유 시간
    segs = []
    edges = [S0, 12000, 15000, 20000, 22500, 25300]
    tr = new["track"]
    for a, b in zip(edges, edges[1:]):
        inc = sp = 0.0; balEnd = None; t_a = t_b = None
        balT = 0.0; prev_t = None
        for (t, s, sb, i_, sp_, bal, *_r) in tr:
            if a <= s < b:
                if t_a is None: t_a = t
                if prev_t is not None: balT += bal * (t - prev_t)
                prev_t = t
                inc += i_; sp += sp_; balEnd = bal; t_b = t
        if t_a is not None and t_b and t_b > t_a:
            perH = inc / (t_b - t_a)
            avgBal = balT / (t_b - t_a)
            segs.append(dict(a=a, b=b, hours=t_b - t_a, inc=inc, spend=sp, surplus=(inc - sp) / inc if inc else 0, balEnd=balEnd, avgBal=avgBal, holdH=avgBal / perH if perH else 0, holdEndH=balEnd / perH if perH else 0, perH=perH))
    p53 = next(((t, s) for (t, s, sb, i_, sp_, bal, *_r) in tr if bal >= 2 ** 53), None)
    return dict(name=name, S0=S0, t0=t0, base=base["reached"], new=new["reached"], pre=pre, brk=brk, post=post, postBase=postBase,
                advDone=new["advDoneAt"], transDone=new["transDoneAt"], final=new["final"], segs=segs, p53=p53, spendNew=new["spendNew"])


if __name__ == "__main__":
    P = dict(DEFAULT)
    for a in sys.argv[1:]:
        k, v = a.split("=")
        P[k] = float(v)
    for name in PROFILES:
        m = metrics(name, load(name), P)
        print(json.dumps(m, ensure_ascii=False, default=lambda o: round(o, 3) if isinstance(o, float) else o)[:1500])
