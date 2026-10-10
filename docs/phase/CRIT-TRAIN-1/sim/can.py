# CRIT-TRAIN-1 결과 분석: python can.py <OUT_DIR> <태그> [프로필...]
#   스테이지별(첫 도달 청크) 치명 확률 · 넘침 전 합 · 치명 피해 · 전환 몫 · 타수(비치명 / 치명 / 기대) + 25,300 도달 h + 100% 첫 도달 · 안정(그 뒤 계속 100%) 스테이지
import sys, os
out, tag = sys.argv[1], sys.argv[2]
profs = sys.argv[3:] or ["casual", "normal", "top"]
STAGES = [100, 500, 1000, 2000, 3000, 5000, 8500, 15000, 25300]
H = "t_h|reach|stage|tier|level|rebirth|rate|rawRate|base|lv|rb|opt|trn|critDmg|dmgRaw|overAtk|apb|atk|hitScale|mobHp|hitsNon|hitsCrit|hitsAvg|repHits|trRate|trDmg|trAtk|perm".split("|")
for p in profs:
    f = os.path.join(out, "r_cr_%s_%s.txt" % (p, tag))
    if not os.path.exists(f):
        print("없음", f)
        continue
    rows, reach_t, extra = [], {}, []
    for line in open(f, encoding="utf-8", errors="replace"):
        if line.startswith("CR|"):
            v = line.strip().split("|")[1:]
            rows.append({k: (float(x) if k not in () else x) for k, x in zip(H, v)})
        elif line.startswith("ROW|"):
            v = line.split("|")
            t, reach = float(v[1]), int(v[2])
            for s in STAGES:
                if reach >= s and s not in reach_t:
                    reach_t[s] = t
        elif line.startswith(("X_CCOMP", "STALL", "INH")):
            extra.append(line.strip())
    print("== %s %s · 25,300 도달 %s h" % (p, tag, ("%.1f" % reach_t[25300]) if 25300 in reach_t else "-"))
    print("| 스테이지 | h | 레벨 · 환생 | 치명 확률 | 넘침 전 합(직업 · 레벨 · 환생 · 옵션 · 수련) | 치명 피해(배) · 추가분 상한 전 | 전환 위력 | 위력 버킷 | 비치명 · 치명 · 기대 타수 | 대표 타수 |")
    print("|---|---|---|---|---|---|---|---|---|---|")
    for s in STAGES:
        r = next((x for x in rows if x["reach"] >= s), None)
        if not r:
            continue
        print("| %s | %.1f | %d · %d | %.1f%% | %.1f%%(%.0f · %.0f · %.0f · %.1f · %.1f) | ×%.2f · +%.2f | +%.1f%% | %.2f | %.1f · %.1f · %.1f | %.1f |" % (
            "{:,}".format(s), r["t_h"], r["level"], r["rebirth"], r["rate"] * 100, r["rawRate"] * 100, r["base"] * 100, r["lv"] * 100, r["rb"] * 100, r["opt"] * 100, r["trn"] * 100,
            r["critDmg"], r["dmgRaw"], r["overAtk"] * 100, r["apb"], r["hitsNon"], r["hitsCrit"], r["hitsAvg"], r["repHits"]))
    first = next((x for x in rows if x["rate"] >= 0.9999), None)
    stable = None
    for i, x in enumerate(rows):
        if x["rate"] >= 0.9999 and all(y["rate"] >= 0.9999 for y in rows[i:]):
            stable = x
            break
    print("100%% 첫 도달: %s · 안정(그 뒤 계속 100%%): %s" % (
        ("s%d(%.1fh)" % (first["reach"], first["t_h"])) if first else "-", ("s%d(%.1fh)" % (stable["reach"], stable["t_h"])) if stable else "-"))
    # 넘친 확률(%p) 구간 평균(시간 가중)
    bands = [(1, 1000), (1001, 3000), (3001, 5000), (5001, 10000), (10001, 17000), (17001, 25300)]
    seg = []
    for a, b in bands:
        tw = sw = 0
        prev_t = None
        for i, x in enumerate(rows):
            dt = x["t_h"] - (rows[i - 1]["t_h"] if i else 0)
            if a <= x["reach"] <= b:
                tw += dt
                sw += dt * max(0, x["rawRate"] - 1)
        seg.append("%d~%d %.1f%%p" % (a, b, 100 * sw / tw if tw else 0))
    print("넘친 확률(시간 가중 평균): " + " · ".join(seg))
    for e in extra:
        print(e)
    print()
