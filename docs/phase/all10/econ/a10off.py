# QUEUE-ALL10 3-4: 스위치 끈 실제 EconSim = 바꾸기 전 기준선(N1004 rd_<prof>.txt - ALL10 전 코드) 줄 단위 대조(시각 · 스테이지 · 보유 골드 · 처치당 골드 · 무기 단계)
import os
SP = os.path.dirname(os.path.abspath(__file__))
for prof in ["casual", "normal", "top", "unluckyP90"]:
    base = [l.split("|") for l in open(os.path.join(SP, "rd_%s.txt" % prof), encoding="utf-8", errors="replace") if l.startswith("ROW|")]
    off = [l.split("|") for l in open(os.path.join(SP, "r_a10_%s_off.txt" % prof), encoding="utf-8", errors="replace") if l.startswith("ROW|")]
    n = min(len(base), len(off))
    diff = 0
    first = None
    for i in range(n):
        b, o = base[i], off[i]
        same = b[1] == o[1] and b[2] == o[2] and b[3] == o[3] and b[7] == o[7] and b[8] == o[8]
        if not same:
            diff += 1
            if first is None:
                first = (i, b[1:4], o[1:4])
    print("%s: 기준선 %d줄 · 끔 %d줄 · 다른 줄 %d · 첫 차이 %s" % (prof, len(base), len(off), diff, first))
