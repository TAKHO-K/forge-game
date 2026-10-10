# PROG-2B-1 2: BossFirstClearGoldData(옛 곡선으로 구운 골드 숫자표) → 마리분 표(곡선이 바뀌어도 따라감). 마리분 = 옛 골드 ÷ (4.95 × 1.001^(s − 1)) · 유효 숫자 3자리.
# 대조: 지금 곡선 A에서 niceReward(4.95 × 마리분 × 1.001^(s − 1)) = 옛 값(앞 두 자리)인지 · 새 곡선 C 값 표.
import io, math, re, sys
src = io.open(sys.argv[1], encoding="utf-8").read()
tab = {int(k): int(v) for k, v in re.findall(r"\[(\d+)\] = (\d+)", src)}
U = 4.95
def nice(n):
    if n < 1000: step = 100
    elif n < 10000: step = 500
    else: step = 10 ** (math.floor(math.log10(n)) - 1)
    return max(100, math.floor(n / step + 0.5) * step)
def MA(s): return 1.001 ** (s - 1)
def MC(s): return MA(s) if s <= 1000 else 1.001 ** 999 * math.sqrt(s / 1000)
def sig3(x):
    e = math.floor(math.log10(x)) - 2
    return round(x / 10 ** e) * 10 ** e
out, bad = [], 0
for s in sorted(tab):
    k = sig3(tab[s] / (U * MA(s)))
    a = nice(math.floor(U * k * MA(s)))
    if a != tab[s]: bad += 1
    out.append((s, k, tab[s], a, nice(math.floor(U * k * MC(s)))))
print("되돌림 다른 칸 %d / %d" % (bad, len(out)))
for s, k, old, a, c in out[:6] + out[-3:]:
    print("s%d 마리분 %g · 옛 %d · A 재계산 %d · C %d" % (s, k, old, a, c))
line = []
for i, (s, k, *_ ) in enumerate(out):
    line.append("[%d] = %s" % (s, ("%d" % k) if k >= 1 else ("%g" % k)))
print("KILLS")
for i in range(0, len(line), 8):
    print("\t" + ", ".join(line[i:i + 8]) + ",")
