# QUEUE-ALL9E1 P3 결정 2-1/2-2: 같은 규칙(켬) 안에서 돌파만 끈 기준(_nb계열)과 비교. 사용: python judge2.py <ON_TAG> <BASE_TAG>
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from judge import load, tAt, seg
SP = os.path.dirname(os.path.abspath(__file__))
ON, BASE = sys.argv[1], sys.argv[2]
PROFS = ["casual", "normal", "top", "unluckyP90"]

def holdAfter(R, s0, span=3000):
    # 계승 직후 보유 시간: 계승 ~ +span 구간에서 보유 골드 ÷ 시간당 수입(시간 가중 평균)과 최대값
    num = w = mx = 0
    for r in R:
        if s0 <= r["reach"] < s0 + span and r["sec"] > 0 and r["inc"] > 0:
            h = r["bal"] / (r["inc"] / (r["sec"] / 3600))
            num += h * r["sec"]; w += r["sec"]; mx = max(mx, h)
    return (num / w if w else 0), mx

for prof in PROFS:
    pa = os.path.join(SP, "r_a10_%s_on%s.txt" % (prof, ON))
    pb = os.path.join(SP, "r_a10_%s_on%s.txt" % (prof, BASE))
    if not (os.path.exists(pa) and os.path.exists(pb)):
        continue
    R, M, T = load(pa)
    B, _, _ = load(pb)
    s0 = M["INH"][1]
    a, b, c = s0, s0 + 1500, s0 + 3000
    on1, base1 = tAt(R, b) - tAt(R, a), tAt(B, b) - tAt(B, a)
    on2, base2 = tAt(R, c) - tAt(R, b), tAt(B, c) - tAt(B, b)
    post_s, _ = seg(R, s0, s0 + 3000)
    hAvg, hMax = holdAfter(R, s0)
    print("%-10s 계승 s%d · 돌파 %.2f(구간 %.1fh ← %.1fh) · 다음 1,500 %.2f · 1,000 %.2fh · 15,000 %.0fh · 25,300 %sh · 계승 뒤 3,000 잉여 %.1f%% · 보유 평균 %.1fh 최대 %.1fh · 고급100 s%d · +20 s%d" % (
        prof, s0, base1 / on1, on1, base1, base2 / on2, tAt(R, 1000), tAt(R, 15000), ("%.0f" % tAt(R, 25300)) if tAt(R, 25300) else "-", post_s * 100, hAvg, hMax,
        M.get("ADV", (0, 0))[1], M.get("TRD", (0, 0))[1]))
