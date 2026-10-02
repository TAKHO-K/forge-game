"""QUEUE-ALL7 D5 → QUEUE-ALL8 D5 지도 정확도: 지도 아이콘 자리(데이터 - roads_points.txt [POINT] = 지도 창 · 미니맵이 아이콘을 찍는 자리)를
Play 중 실제 인스턴스 자리(Studio 로그 [REF] - server/MapGenSample.refs: 캠프 판 · 관문 · 랜드마크 모델 경계 상자 가운데 · 시설 거리 바닥 · 큰 나무)와 같은 지도 식으로 재서
지도 폭 대비 %를 낸다(23곳 모두 숫자 - 옛 판정은 "그 자리에 구조물 셀이 있나"라 평지 캠프 · 빙하 관문은 "> 40"으로 숫자가 없었다).
그림 쪽 맞춤(굽기 좌표식)은 길 점 검사(render.py 굽기 - 길 데이터가 흙길 셀 위)로 따로 잰다 - 아래 "구조물 셀" 열은 참고(옛 방식).

사용: python roblox/tools/mapgen/accuracy.py [--log <Studio 로그>]  (render.py와 같은 로그 · roads_points.txt)
판정 = 오차 ≤ 지도 폭 2%.
"""
import argparse
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import render  # noqa: E402

WANT = {"hub": "TH", "facility": "BHR", "camp": "BHRP", "landmark": "BKC", "gate": "BR"}  # 참고 열(옛 방식) - 그 지점 가까운 구조물 셀 분류


def load_refs(log):
    refs = []
    with open(log, encoding="utf-8", errors="replace") as f:
        for line in f:
            k = line.find("[REF] ")
            if k < 0:
                continue
            parts = line[k + 6 :].strip().split(" ")
            if parts[0] == "끝" or len(parts) < 3:
                if parts[0] == "끝":
                    refs = refs[-int(parts[1]) :] if len(parts) > 1 and parts[1].isdigit() else refs  # 마지막 묶음만
                continue
            x, z = map(float, parts[2].split(","))
            refs.append((parts[0], parts[1], x, z))
    return refs


def nearest_cell(grid, kind, u, v):
    N = render.N
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
    return best


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--log")
    a = ap.parse_args()
    log = a.log or render.newest_log()
    grid = render.load_grid(log)
    refs = load_refs(log)
    if not refs:
        sys.exit("[REF] 줄 없음 - Play 중 서버 execute_luau: require(game.ServerScriptService.MapGenSample).refs()")
    _, points = render.load_roads(os.path.join(HERE, "roads_points.txt"))
    W = 2 * render.EDGE  # 지도 폭(stud) - 지도 u, v 차이 × 폭 = stud
    rows, worst, n, ok_n = [], 0.0, 0, 0
    for kind, name, x, z in points:
        if kind not in WANT:
            continue
        cand = [r for r in refs if r[0] == kind and (kind != "landmark" and kind != "camp" and kind != "facility" or r[1] == name)]
        if kind == "hub":
            cand = [r for r in refs if r[0] == "hub"]
        if not cand:
            rows.append(f"| {kind} | {name} | {x:.0f}, {z:.0f} | - | - | - | X(실제 자리 없음) |")
            n += 1
            continue
        ref = min(cand, key=lambda r: math.hypot(r[2] - x, r[3] - z))  # 관문 = 가장 가까운 BossGate 모델
        du = (x - ref[2]) / W
        dv = (z - ref[3]) / W
        pct = math.hypot(du, dv) * 100
        u = (x + render.EDGE) / W * render.N
        v = (z + render.EDGE) / W * render.N
        cell = nearest_cell(grid, kind, u, v)
        ok = pct <= 2
        worst = max(worst, pct)
        n += 1
        ok_n += ok
        rows.append(f"| {kind} | {name} | {x:.0f}, {z:.0f} | {ref[2]:.0f}, {ref[3]:.0f} | {math.hypot(x - ref[2], z - ref[3]):.1f} | {pct:.2f}% | {'O' if ok else 'X'} | {('%.1f' % cell) if cell is not None else '> 40'} |")
    print("| 종류 | 지점 | 지도 아이콘(데이터) x, z | 실제 인스턴스 x, z | 차(stud) | 지도 폭 대비 | ≤ 2% | 참고: 구조물 셀까지(옛 방식) |")
    print("|---|---|---|---|---|---|---|---|")
    print("\n".join(rows))
    print(f"[ACC] 지점 {n}개 · 최대 오차 {worst:.2f}% · 통과 {ok_n}/{n}")


if __name__ == "__main__":
    main()
