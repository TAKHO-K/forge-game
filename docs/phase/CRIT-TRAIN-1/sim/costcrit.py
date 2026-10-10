# CRIT-TRAIN-1 §3 치명 수련 가격 · 가치 표(해석 계산). 값 = 시뮬 시안(critlib CRITCFG.train)과 같은 숫자.
#   가격 = 공격 수련 26 ~ 50 구간 가격(400 × 1.04^(n − 1)마리분 - PROG-2 A안) × 가치 비 · 골드 = niceReward(마리분 × 4.95 × M(계정 최고 s)) · M = GOLD-CURVE-1 C
#   가치(한 단계 기대 피해) = 공격 +1%: 0.01 ÷ 영구 버킷 · 치명 확률 +1%p: (m − 1) ÷ (1 + p(m − 1)) × 0.01 · 치명 피해 +2%: p × 0.02 ÷ (1 + p(m − 1))
import math

def M_C(s):
    return 1.001 ** (s - 1) if s <= 1000 else 1.001 ** 999 * math.sqrt(s / 1000)

def nice(v):
    step = 100 if v < 1000 else 500 if v < 10000 else 10 ** (math.floor(math.log10(v)) - 1)
    return max(100, math.floor(v / step + 0.5) * step)

def ev(p, m):
    return 1 + p * (m - 1)

print("## 가치 비(중앙값 = 일반 프로필 B0 궤적 · 영구 버킷 · 치명 피해 배율)")
print("| 지점 | 영구 버킷 | 확률 p · 치명 피해 m | 공격 +1% | 치명 확률 +1%p | 치명 피해 +2% | 확률 ÷ 공격 | 피해 ÷ 공격 |")
print("|---|---|---|---|---|---|---|---|")
for name, perm, p, m in [("s2,000(확률 0단계)", 1.62, 0.842, 2.39), ("s3,000(8단계)", 1.64, 0.922, 2.39), ("s3,900(16단계 = 100%)", 1.70, 0.99, 2.39),
                         ("s5,000(피해 0단계)", 1.72, 1.0, 2.40), ("s7,500(25단계)", 1.77, 1.0, 2.90), ("s10,000(50단계)", 1.84, 1.0, 3.40),
                         ("예: 피해 +220% 상태(활 m 4.5 · p 0.9)", 1.70, 0.9, 4.5)]:
    a = 0.01 / perm
    r = 0.01 * (m - 1) / ev(p, m)
    d = p * 0.02 / ev(p, m)
    print("| %s | %.2f | %.0f%% · ×%.2f | +%.2f%% | +%.2f%% | +%.2f%% | %.2f | %.2f |" % (name, perm, p * 100, m, a * 100, r * 100, d * 100, r / a, d / a))
print()
print("## 가격 표(마리분 · 중앙값 1마리분 ≈ 1초 → 분)")
print("| 항목 | 1단계 | 10단계 | 25단계 | 50단계 | 합 | 골드 예(1단계 · 끝 단계) |")
print("|---|---|---|---|---|---|---|")
for name, n, scale, s_first, s_last in [("치명타 확률 수련(+1%p × 25)", 25, 1.0, 2000, 5000), ("치명타 피해 수련(+2% × 50)", 50, 1.2, 5000, 10000)]:
    k = lambda i: 400 * 1.04 ** (i - 1) * scale
    tot = sum(k(i) for i in range(1, n + 1))
    cells = []
    for i in (1, 10, 25, 50):
        cells.append("%.0f(%.1f분)" % (k(i), k(i) / 60) if i <= n else "-")
    g1, g2 = nice(k(1) * 4.95 * M_C(s_first)), nice(k(n) * 4.95 * M_C(s_last))
    print("| %s | %s | %s(%.1fh) | s%s %s · s%s %s |" % (name, " | ".join(cells), "{:,.0f}".format(tot), tot / 3600, "{:,}".format(s_first), "{:,}".format(int(g1)), "{:,}".format(s_last), "{:,}".format(int(g2))))
