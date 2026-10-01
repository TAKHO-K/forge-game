"""QUEUE-ALL7 D5 지도 정확도: 알려진 지점(허브 · 시설 · 캠프 · 랜드마크 · 관문)의 월드 좌표를 지도 식(MapImageData와 같은 u,v)으로 찍고,
구운 표본(Studio 로그 [MAPGEN])에서 그 지점에 실제로 있는 구조물(건물 B · 나무 T · 광장 H · 길 R) 셀까지의 거리를 잰다 → 지도 폭 대비 %.

사용: python roblox/tools/mapgen/accuracy.py [--log <Studio 로그>]  (render.py와 같은 로그 · roads_points.txt)
판정 = 오차 ≤ 지도 폭 2% · 땅 위에 표지만 있는 곳(사냥 지대 가운데)은 구조물이 없어 뺀다.
"""
import argparse
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import render  # noqa: E402

WANT = {"hub": "TH", "facility": "BHR", "camp": "BHRP", "landmark": "BKC", "gate": "BR"}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--log")
    a = ap.parse_args()
    grid = render.load_grid(a.log or render.newest_log())
    _, points = render.load_roads(os.path.join(HERE, "roads_points.txt"))
    N = render.N
    rows, worst, n = [], 0.0, 0
    for kind, name, x, z in points:
        if kind not in WANT:
            continue
        u = (x + render.EDGE) / (2 * render.EDGE) * N
        v = (z + render.EDGE) / (2 * render.EDGE) * N
        cx, cz = int(u), int(v)
        best = None
        for r in range(0, 40):
            for dz in range(-r, r + 1):
                for dx in range(-r, r + 1):
                    if max(abs(dx), abs(dz)) != r:
                        continue
                    xx, zz = cx + dx, cz + dz
                    if 0 <= xx < N and 0 <= zz < N and grid[zz][xx][0] in WANT[kind]:
                        d = math.hypot(dx, dz)
                        if best is None or d < best:
                            best = d
            if best is not None and best <= r:
                break
        pct = (best if best is not None else 40) / N * 100
        ok = best is not None and pct <= 2
        worst = max(worst, pct)
        n += 1
        rows.append(f"| {kind} | {name} | {x:.0f}, {z:.0f} | {u / N:.4f}, {v / N:.4f} | {('%.1f' % best) if best is not None else '> 40'} 셀 | {pct:.2f}% | {'O' if ok else 'X'} |")
    print("| 종류 | 지점 | 월드 x, z | 지도 u, v | 가장 가까운 구조물 셀 | 지도 폭 대비 | ≤ 2% |")
    print("|---|---|---|---|---|---|---|")
    print("\n".join(rows))
    print(f"[ACC] 지점 {n}개 · 최대 오차 {worst:.2f}% · 통과 {sum(1 for r in rows if r.endswith('O |'))}/{n}")


if __name__ == "__main__":
    main()
