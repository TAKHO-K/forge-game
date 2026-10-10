# PROG-2A 가격표: 능력치 수련 A안 · B안 · 직업 능력 - 골드(깔끔한 숫자) · T = 마리분 ÷ U(s)(일반 프로필 분당 마리분 - 기준선 EconSim 실측)
import math
U = [(100, 56), (200, 64), (500, 59), (1000, 72), (2000, 45), (3000, 54), (5000, 47), (7500, 59), (10000, 78), (15000, 74), (20000, 128), (25000, 126)]

def u(s):
    if s <= U[0][0]:
        return U[0][1]
    for (a, x), (b, y) in zip(U, U[1:]):
        if s <= b:
            return x + (y - x) * (s - a) / (b - a)
    return U[-1][1]

def nice(n):  # GoldCost.niceReward와 같은 규칙
    if n < 1000:
        step = 100
    elif n < 10000:
        step = 500
    else:
        step = 10 ** (math.floor(math.log10(n)) - 1)
    return max(100, math.floor(n / step + 0.5) * step)

def gold(kills, s):
    return nice(4.95 * kills * 1.001 ** (s - 1))

def bands_kills(bands, L):
    band = bands[0]
    for b in bands:
        if L >= b[0]:
            band = b
    return band[2] * band[3] ** (L - band[0]) if len(band) == 4 else band[1] * band[2] ** (L - band[0])

A = [(1, 40, 1.04), (26, 400, 1.04)]
B = [(1, 40, 1.04), (26, 400, 1.04), (51, 1600, 1.04), (76, 4000, 1.04)]

def adv(L):  # 고급 수련 51 ~ 100(All10Data) + A안 76 ~ 100 × 2
    k = 1840 * 1.03 ** (L - 51)
    if L <= 60:
        k *= 0.4
    if L >= 76:
        k *= 2
    return k

print("### A안(1 ~ 50 = 스테이지 ÷ 20으로 열림 · 51 ~ 100 = 고급 수련 · 초월 무기 뒤 · 열림 = 10,000 + (단계 − 50) × 100)")
print("| 단계 | 마리분 | 열리는 스테이지 | 그때 골드 | T(일반 · 분) | 스테이지 7,500에서 골드 | T(7,500) |")
print("|---|---|---|---|---|---|---|")
tot = 0
for L in [1, 10, 25, 26, 40, 50, 51, 60, 61, 75, 76, 90, 100]:
    k = bands_kills(A, L) if L <= 50 else adv(L)
    s = 20 * L if L <= 50 else 10000 + (L - 50) * 100
    print("| %d | %.0f | %d | %s | %.1f | %s | %.1f |" % (L, k, s, format(gold(k, s), ","), k / u(s), format(gold(k, 7500), ","), k / u(7500)))
for name, rng, f in [("1 ~ 25", range(1, 26), lambda L: bands_kills(A, L)), ("26 ~ 50", range(26, 51), lambda L: bands_kills(A, L)), ("51 ~ 75", range(51, 76), adv), ("76 ~ 100", range(76, 101), adv)]:
    k = sum(f(L) for L in rng)
    print("구간 %s 합 = %.0f마리분 ≈ 일반 %.1f시간(U 60)" % (name, k, k / 60 / 60))
old = sum(32 * 1.08 ** L for L in range(50))
print("옛 공용 수련 1 ~ 50 합 = %.0f마리분(한 항목) · 새 A안 1 ~ 50 합 = %.0f" % (old, sum(bands_kills(A, L) for L in range(1, 51))))
print()
print("### B안(1 ~ 100 공용 · 스테이지 ÷ 20 · 고급 수련 없음)")
for name, a, b in [("1 ~ 25", 1, 25), ("26 ~ 50", 26, 50), ("51 ~ 75", 51, 75), ("76 ~ 100", 76, 100)]:
    k = sum(bands_kills(B, L) for L in range(a, b + 1))
    print("구간 %s: 첫 단계 %.0f마리분 · 합 %.0f마리분 ≈ 일반 %.1f시간" % (name, bands_kills(B, a), k, k / 3600))
print()
print("### 직업 능력 Lv2 · Lv3(고정 vs GoldCost 연동 - 기준 스테이지 1,000)")
print("| 단계 | 스테이지 | 고정 골드 | 고정 T(일반 · 분) | 연동 골드 | 연동 T(분) |")
print("|---|---|---|---|---|---|")
for lv, base in [(2, 100000), (3, 250000)]:
    for s in ([500, 1000, 2000, 3000, 5000] if lv == 2 else [7000, 8560, 10000, 15000]):
        unit = 4.95 * 1.001 ** (s - 1)
        scaled = nice(base * 1.001 ** (s - 1000))
        print("| Lv%d | %d | %s | %.1f | %s | %.0f |" % (lv, s, format(base, ","), base / unit / u(s), format(scaled, ","), scaled / unit / u(s)))
