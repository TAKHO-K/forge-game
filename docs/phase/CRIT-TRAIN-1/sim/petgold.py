# CRIT-TRAIN-1 §5 펫 합성 골드 비용 표(해석 계산 + 몬테카를로 대조). 게임 데이터는 읽기만(부화표 · 둥지 A 분포 = PROG-2A petmerge.py와 같은 숫자).
# 규칙(사용자 확정 10-11): 같은 종 · 같은 등급 3마리 → 상승 9% · 대성공 1%(상승 + 1마리 더 = 결과 등급 75% / 한 등급 위 25% - PROG-2 2-8 그대로)
#   · 독립 시행 · 천장 없음 · 실패 = 1마리 남음(2마리 소모) · 전용 외형 없음 · 시도마다 골드.
# 골드 = niceReward(n분 × 60마리분 × 4.95 × M(계정 최고 s)) - 중앙값 1마리분 ≈ 1초(GOLD-CURVE-1 §4 규칙)
import math, random
GR = ["일반", "희귀", "영웅", "전설"]
HATCH = {"normal": [58, 32.2, 8.1, 1.7], "good": [33, 47.2, 16.6, 3.2], "rare": [8, 52.2, 31.6, 8.2]}
MIX = {"normal": 0.80, "good": 0.18, "rare": 0.02}
pg = [sum(MIX[e] * HATCH[e][g] / 100 for e in MIX) for g in range(4)]
SAME = 0.5
P_UP, P_GREAT = 0.09, 0.01
N_MIN = {1: 1, 2: 5, 3: 15}  # 결과 등급(희귀 · 영웅 · 전설) → 시도 1회 = 사냥 n분
SELL = [10, 40, 600, 2400]  # PROG-2 2-8 판매가(마리분)

def M_C(s):  # GOLD-CURVE-1 C(√ 완만)
    return 1.001 ** (s - 1) if s <= 1000 else 1.001 ** 999 * math.sqrt(s / 1000)

def nice(v):  # GoldCost.niceReward와 같은 식(1,000 미만 100 · 1만 미만 500 · 그 위 앞 두 자리)
    step = 100 if v < 1000 else 500 if v < 10000 else 10 ** (math.floor(math.log10(v)) - 1)
    return max(100, math.floor(v / step + 0.5) * step)

p = P_UP + P_GREAT
tries = 1 / p
per_try_pets = p * 3 + (1 - p) * 2
pets_per_success = per_try_pets * tries
# 대성공 덤: 성공 1회당 결과 등급 덤 기대 = (0.01/0.10) × 0.75 · 한 등급 위 = × 0.25
bonus_same, bonus_up = P_GREAT / p * 0.75, P_GREAT / p * 0.25

print("알 1개당 등급(둥지 A · 부화 Lv5): " + " · ".join("%s %.2f%%" % (GR[g], pg[g] * 100) for g in range(4)))
print("성공 1회 기대 시도 %.1f · 같은 종 아래 등급 소모 %.1f마리 · 대성공 덤(같은 등급 %.3f · 한 등급 위 %.3f)" % (tries, pets_per_success, bonus_same, bonus_up))
print()
print("| 결과 등급 | 시도 1회 골드(n분 · 마리분) | 성공 1회 기대 = 펫 · 골드(분) | 그 펫을 알로 모으면(알 개수 · 2개/h) | 직접 부화로 같은 종 1마리(알) | s1,000 · s5,000 · s8,500 시도 골드(C 곡선) |")
print("|---|---|---|---|---|---|")
for g in (1, 2, 3):
    n = N_MIN[g]
    eggs_low = pets_per_success / (SAME * pg[g - 1])
    direct = 1 / (SAME * pg[g])
    golds = " · ".join("{:,}".format(int(nice(n * 60 * 4.95 * M_C(s)))) for s in (1000, 5000, 8500))
    print("| %s | %d분 · %d마리분 | %s %.0f마리 + %d분(%.1fh) | %.0f개 · %.0fh | %.0f개 | %s |" % (GR[g], n, n * 60, GR[g - 1], pets_per_success, n * tries, n * tries / 60, eggs_low, eggs_low / 2, direct, golds))
# 일반 → 전설 사슬(같은 종)
need = {3: 1.0}
gold = 0.0
for g in (3, 2, 1):
    need[g - 1] = need[g] * pets_per_success
    gold += need[g] * tries * N_MIN[g]
print()
print("사슬(같은 종 일반 → 전설 1마리): 일반 %.0f마리(알 %.0f개) + 골드 %.0f분(%.1fh) · 직접 부화 전설 같은 종 = 알 %.0f개" % (need[0], need[0] / (SAME * pg[0]), gold, gold / 60, 1 / (SAME * pg[3])))
# 몬테카를로 대조(희귀 → 영웅 · 시도 수 · 소모)
random.seed(11)
N = 200000
tt = tp = 0
for _ in range(N):
    used, t = 0, 0
    while True:
        t += 1
        r = random.random()
        if r < p:
            used += 3
            break
        used += 2
    tt += t
    tp += used
print("대조(%d회): 성공까지 시도 %.2f(식 %.1f) · 소모 %.2f마리(식 %.1f)" % (N, tt / N, tries, tp / N, pets_per_success))
