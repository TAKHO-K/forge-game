# PROG-2A 펫 합성 · 판매 표(해석 계산 - 시뮬 1e5회로 대조). 게임 데이터는 읽기만(EggData 부화표 · 둥지 A 알 분포 숫자를 아래에 옮겨 둠).
import random
GR = ["일반", "희귀", "영웅", "전설"]
# 부화표(부화 레벨 5 = 누적 50회 · pets-q11.md 2절) · 둥지 A 알 분포 80/18/2(EggData.lua:113-122)
HATCH = {"normal": [58, 32.2, 8.1, 1.7], "good": [33, 47.2, 16.6, 3.2], "rare": [8, 52.2, 31.6, 8.2]}
MIX = {"normal": 0.80, "good": 0.18, "rare": 0.02}
pg = [sum(MIX[e] * HATCH[e][g] / 100 for e in MIX) for g in range(4)]
SAME = 0.5  # 알 후보 2종 50:50 → 원하는 종일 확률
SELL = [10, 40, 600, 2400]  # 판매가(마리분 · 영웅 = 일반 프로필 그 단계 1레벨 골드 ≈ 600마리분 ≈ 10분)
P_UP, P_GREAT = 0.09, 0.01
FAILS = {
    "F1 좋은 1 남김 + 2마리 판매가 100% 환급": (1, 1.0),
    "F2 좋은 1 남김 + 2마리 판매가 50% 환급": (1, 0.5),
    "F3 2마리 남김 + 1마리 판매가 100% 환급": (2, 1.0),
}

def per_egg(g):
    return SAME * pg[g]

print("알 1개당 등급 확률(둥지 A 평균 · 부화 Lv5): " + " · ".join("%s %.1f%%" % (GR[g], pg[g] * 100) for g in range(4)))
ev = sum(pg[g] * SELL[g] for g in range(4))
print("알 1개 기대 판매가 = %.0f마리분 → 시간당 알 2개 = %.0f · 6개 = %.0f마리분(일반 U≈60 → 수입의 %.1f%% · %.1f%%)" % (ev, 2 * ev, 6 * ev, 200 * ev / 3600, 600 * ev / 3600))
print()
print("| 실패 처리 | 합성 | 성공 1회까지 기대 시도 | 같은 종 소모(마리) | 필요한 알(개) | 알 2개/h | 알 6개/h | 실패 환급 합(마리분) |")
print("|---|---|---|---|---|---|---|---|")
for name, (keep, refund) in FAILS.items():
    for g in range(3):
        p = P_UP + P_GREAT
        tries = 1 / p
        need = 3 + (3 - keep) * (tries - 1)
        eggs = need / per_egg(g)
        back = (tries - 1) * (3 - keep) * SELL[g] * refund
        print("| %s | %s → %s | %.0f | %.0f | %.0f | %.0fh | %.0fh | %.0f |" % (name, GR[g], GR[g + 1], tries, need, eggs, eggs / 2, eggs / 6, back))
# 몬테카를로 대조(F1 · 일반 → 희귀)
random.seed(7)
tot = 0
N = 100000
for _ in range(N):
    used = 3
    while random.random() >= P_UP + P_GREAT:
        used += 2
    tot += used
print("\n대조(F1 일반 → 희귀 · %d회): 평균 소모 %.2f마리(식 21)" % (N, tot / N))
print("\n직접 부화로 같은 종 한 마리 얻기(알 개수): " + " · ".join("%s %.0f" % (GR[g], 1 / per_egg(g)) for g in range(4)))
