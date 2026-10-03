import json, math
from all10 import load, metrics, simulate, speed, DEFAULT, PROFILES
from grid import summary, score

REC = dict(DEFAULT)
REC.update(transKills=280000, transSub=5, transPerLevel=0.05, weaponBase=1.25, gem=1.08, advPerLevel=0.01, advK0=1840, advR=1.03,
           advCapStart=10000, advCapStep=100, defUnlock=12000, defLevels=30, defK0=6000, defR=1.05, breakL=1500, breakR=2.4,
           curveStart=16000, curveKappa=0.12)
FAST = dict(REC); FAST.update(breakR=3.0, curveKappa=0.14)
SLOW = dict(REC); SLOW.update(breakR=2.0, curveKappa=0.10)
NAMES = {"casual": "캐주얼", "normal": "일반", "top": "상위 1%", "unluckyP90": "운 나쁜 P90"}


def fmt(x, d=1):
    return "-" if x is None else (("%." + str(d) + "f") % x)


def block(title, P):
    res = summary(P)
    ok = score(res)
    L = ["### " + title, ""]
    L.append("| 프로필 | 계승(+30) | 12,000 기준선 → 새 | 15,000 기준선 → 새 | 20,000 기준선 → 새 | 25,300 기준선 → 새 | 돌파 속도(같은 구간 기준선 대비) | 돌파 속도(직전 300 스테이지 대비) | 복귀(돌파 뒤 1,500 · 기준선 대비) | 고급 수련 100 | 초월 강화 끝 |")
    L.append("|---|---|---|---|---|---|---|---|---|---|---|")
    for n in PROFILES:
        r = res[n]
        cells = []
        for m in (12000, 15000, 20000, 25300):
            cells.append("%s → %s h" % (fmt(r["base"].get(m)), fmt(r["new"].get(m))))
        L.append("| %s | %.1fh · s%s | %s | ×%s | ×%s | ×%s | %s | %s |" % (
            NAMES[n], r["t0"], format(r["S0"], ","), " | ".join(cells), fmt(r["brkSame"], 2), fmt(r["brkPre"], 2), fmt(r["postRatio"], 2),
            ("s%s · %.0fh" % (format(round(r["advDone"][1]), ","), r["advDone"][0])) if r["advDone"] else "미완",
            ("+20 · s%s · %.0fh" % (format(round(r["transDone"][1]), ","), r["transDone"][0])) if r["transDone"] else "+%.1f(25,300 때)" % r["final"][0]))
    L.append("")
    L.append("목표 판정: " + " · ".join("%s %s" % (k, "통과" if v else "실패") for k, v in ok.items()))
    L.append("")
    return res, ok, L


out = ["# ALL10-P1 격자 탐색 원자료(QUEUE-N1004 C-2)", "", "> 모형 = `server/EconSimAll10.lua`(계승 뒤 오버레이 - 기준선 EconSim 청크 위) · 원형 = 스크래치패드 `all10.py` · `grid.py`(같은 식). 추천 매개변수 = 아래 REC.", "", "REC = " + json.dumps(REC, ensure_ascii=False), ""]
res, ok, L = block("추천안(REC)", REC); out += L
_, _, L = block("대안 A - 더 빠른 돌파(breakR 3.0 · kappa 0.14)", FAST); out += L
_, _, L = block("대안 B - 더 완만한 돌파(breakR 2.0 · kappa 0.10)", SLOW); out += L

# 골드 표(추천안)
out += ["### 골드 - 구간별 유입 · 소모 · 잉여율 · 보유 시간(추천안)", "", "| 프로필 | 구간 | 시간 | 유입 | 소모 | 잉여율 | 구간 평균 보유 시간 | 구간 끝 보유 |", "|---|---|---|---|---|---|---|---|"]
for n in PROFILES:
    for s in res[n]["segs"]:
        out.append("| %s | %s ~ %s | %.0fh | %.3g | %.3g | %.0f%% | %.1fh | %.3g |" % (NAMES[n], format(s["a"], ","), format(s["b"], ","), s["hours"], s["inc"], s["spend"], 100 * s["surplus"], s["holdH"], s["balEnd"]))
out += ["", "| 프로필 | 보유 2^53 처음 넘는 때 | 새 소모처 합계(초월 강화 · 고급 수련 · 방어 수련) |", "|---|---|---|"]
for n in PROFILES:
    r = res[n]
    sp = r["spendNew"]
    out.append("| %s | %s | %.3g · %.3g · %.3g |" % (NAMES[n], ("%.0fh · s%s" % (r["p53"][0], format(round(r["p53"][1]), ","))) if r["p53"] else "없음", sp["trans"], sp["adv"], sp["dfn"]))
out.append("")

# 운 좋은 빌드: 같은 빌드에서 옵션 굴림만 바꿔 잼(luck.luau - BalanceSim.buildLoadout · 태초 장비 3부위 공격% 옵션 + 태초 보석 5개)
out += ["### 운 좋은 빌드(옵션 굴림: 평균 1.0 → 상위 30% 1.0875 → 상위 10% 1.1125 → 최대 1.125)", ""]
for line in open("r_luck.txt", encoding="utf-8"):
    if line.startswith("LUCK|"):
        out.append("- " + line.strip().replace("LUCK|", "").replace("|", " · "))
out += ["", "- 공격 배수(상위 10% ÷ 평균) = ×1.025 · 같은 스테이지 처치 시간 = 타수 문턱을 넘을 때 최대 ×1.17(1.72초 → 1.47초) - 참고 상한 ×1.5 안 · 막지 않음(D10). 기준선끼리(옵션 굴림만 바꾼 EconSim 전체 실행) 비교는 강화 난수 경로가 갈라져 같은 시각 스테이지 차가 일반 +327 · 상위 1% −75로 잡음이 커서 쓰지 않았다.", ""]
# 곱셈 중첩(추천안 · 완료 시점 · 태초 +30 = 1)
w = REC["weaponBase"]; t = 1 + 20 * REC["transPerLevel"]; a = 1 + 50 * REC["advPerLevel"]; g = REC["gem"]
out += ["### 곱셈 중첩(공격 · 태초 +30 빌드 = 1)", "", "| 요소 | 배수 | 누적 |", "|---|---|---|"]
acc = 1
for name, v in (("초월 무기 +0(계승)", w), ("초월 강화 +20(합 +100% - 무기 강화 줄)", t), ("고급 수련 51 ~ 100(+1%/단계)", a), ("초월 보석 1개", g), ("초월 방어구(드랍 - 지금 장비 축 그대로)", 1.0), ("운 옵션(상위 10%)", None)):
    if v is None:
        out.append("| %s | 위 운 빌드 표(측정) | - |" % name)
        continue
    acc *= v
    out.append("| %s | ×%.2f | ×%.2f |" % (name, v, acc))
out.append("")
out.append("- 전체 ×%.2f = 몹 HP 기준 %.0f 스테이지 분량(ln ÷ ln 1.02). 전역 곡선 재조정(16,000부터 성장률 +12%%)이 25,300까지 HP를 ×%.3g 더 키워 이 몫과 돌파 앞섬을 거둬들인다." % (acc, math.log(acc) / math.log(1.02), 1.02 ** (0.12 * (25300 - 16000))))
out.append("")

# 폭주 검사: 구간별 스테이지 속도 · 시간당 수입 증가(추천안 · 상위 1%)
out += ["### 선순환 폭주 검사(상위 1% · 1,000 스테이지 구간 - 처치 시간 목표는 EconSim 사냥 규칙 그대로)", "", "| 구간 | 기준선 속도(스테이지/h) | 새 속도 | 새 시간당 수입 | 수입 증가(직전 구간 대비) |", "|---|---|---|---|---|"]
tb = simulate(load("top"), REC, enable=False)["track"]; tn = simulate(load("top"), REC)["track"]
prev = None
for a_ in range(9000, 25300, 2000):
    b_ = min(a_ + 2000, 25300)
    vb = speed(tb, a_, b_); vn = speed(tn, a_, b_)
    inc = sum(x[3] for x in tn if a_ <= x[1] < b_); hrs = None
    ts = [x[0] for x in tn if a_ <= x[1] < b_]
    perH = inc / (ts[-1] - ts[0]) if len(ts) > 1 and ts[-1] > ts[0] else None
    out.append("| %s ~ %s | %s | %s | %s | %s |" % (format(a_, ","), format(b_, ","), fmt(vb), fmt(vn), ("%.3g" % perH) if perH else "-", ("×%.2f" % (perH / prev)) if (perH and prev) else "-"))
    prev = perH
out.append("")
open("all10_tables.md", "w", encoding="utf-8").write("\n".join(out) + "\n")
print("\n".join(out)[:6000])
