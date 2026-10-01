"""QUEUE-ALL7 D2 지도 굽기 2단계: Studio 로그의 [MAPGEN] 줄(server/MapGenSample) + 길 · 지점(roads_points.txt - roads_dump.luau) → 카툰 지도 PNG.

사용: python roblox/tools/mapgen/render.py [--log <Studio 로그>] [--out roblox/art/map]
  결과 = world_full.png(2048² 미리보기) + world_mini.png(1024² - 미니맵 한 장) + world_0_0 · world_0_1 · world_1_0 · world_1_1.png(1024² 타일 - 업로드 단위, 행_열 = 위 → 아래 · 왼 → 오른)
  좌표 = 월드 x,z → u = (x + EDGE) / (2·EDGE), v = (z + EDGE) / (2·EDGE)(위 = −Z) - shared/data/MapImageData와 같은 식.
맵을 고치면: Play(맵이 지어진 뒤) → 서버 execute_luau `for r = 0, 1023, 128 do require(game.ServerScriptService.MapGenSample)(r, 128) end`
  → roads_dump.luau(harness) → 이 스크립트 → upload.py map/*.png → Studio에서 이미지 id 읽기(upload.py --images) → MapImageData.
패키지: 표준 라이브러리 + Pillow(이미 설치됨 - 새로 깔지 않는다).
"""
import argparse
import glob
import math
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
N = 1024
EDGE = 2960.0
Y0, YSTEP = -40, 10
PX = 2  # 셀당 픽셀(2048² 전체)
S = N * PX

PAL = {
    "G": [(156, 214, 106), (128, 196, 88), (102, 172, 72), (84, 146, 62), (120, 140, 96)],  # 풀: 낮은 땅 연두 → 진한 초록 → 높은 곳 올리브
    "P": [(156, 214, 106), (128, 196, 88), (102, 172, 72), (84, 146, 62), (120, 140, 96)],
    "D": [(206, 182, 128), (190, 164, 110), (168, 142, 94), (146, 124, 84), (150, 140, 120)],  # 흙
    "K": [(176, 166, 152), (160, 150, 138), (146, 136, 126), (180, 174, 168), (226, 222, 216)],  # 바위 → 꼭대기 회백
    "S": [(236, 214, 156), (226, 202, 140), (214, 188, 126), (200, 176, 118), (196, 182, 150)],
    "N": [(240, 244, 248)] * 5,
    "I": [(196, 230, 244)] * 5,
    "C": [(190, 160, 236)] * 5,
    "X": [(40, 52, 66)] * 5,
    "H": [(222, 208, 176)] * 5,  # 허브 광장(밝은 돌바닥)
}
WATER = (82, 164, 224)
SHORE = (150, 210, 244)
TREE_DARK, TREE_LIGHT, TREE_EDGE = (52, 128, 60), (86, 170, 82), (30, 84, 38)
BLD_ROOF_HUB, BLD_STONE, BLD_EDGE = (204, 92, 66), (190, 172, 146), (70, 56, 44)
CLIFF = (70, 62, 56)
ROAD_FILL, ROAD_EDGE = (236, 218, 168), (118, 88, 54)


def band(y):  # 높이 → 5단계(포스터 칠)
    return 0 if y < 15 else 1 if y < 45 else 2 if y < 100 else 3 if y < 200 else 4


def newest_log():
    base = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Roblox", "logs")
    files = glob.glob(os.path.join(base, "*Studio*_last.log"))
    return max(files, key=os.path.getmtime) if files else None


def parse_row(s):
    out = []
    i = 0
    while i < len(s):
        c, h = s[i], ord(s[i + 1]) - 40
        i += 2
        n = 1
        if i < len(s) and s[i] == "~":
            j = s.index(";", i)
            n = int(s[i + 1 : j])
            i = j + 1
        out.extend([(c, h)] * n)
    return out


def load_grid(log):
    rows = {}
    with open(log, encoding="utf-8", errors="replace") as f:
        for line in f:
            k = line.find("[MAPGEN] ")
            if k < 0:
                continue
            body = line[k + 9 :].rstrip("\n")
            key, _, data = body.partition(":")
            z, _, seg = key.partition(".")
            rows.setdefault(int(z), {})[int(seg or 0)] = data  # 같은 조각이 여러 번이면 마지막(가장 최근 굽기)
    rows = {z: "".join(segs[i] for i in sorted(segs)) for z, segs in rows.items() if len(segs) == N // 256}
    missing = [z for z in range(N) if z not in rows]
    if missing:
        sys.exit(f"[MAPGEN] 줄 빠짐 {len(missing)}개(예: {missing[:5]}) - 표본을 다시 뽑는다")
    grid = []
    for z in range(N):
        r = parse_row(rows[z])
        if len(r) != N:
            sys.exit(f"줄 {z} 길이 {len(r)} ≠ {N}")
        grid.append(r)
    return grid


def w2p(x, z):
    return ((x + EDGE) / (2 * EDGE) * S, (z + EDGE) / (2 * EDGE) * S)


def load_roads(path):
    roads, points = [], []
    with open(path, encoding="utf-8") as f:
        for line in f:
            if line.startswith("[ROAD] "):
                parts = line.split(" ", 3)
                pts = [tuple(map(float, p.split(","))) for p in parts[3].strip().split(";") if p]
                roads.append((parts[1], parts[2], pts))
            elif line.startswith("[POINT] "):
                kind, name, xz = line.split(" ")[1:4]
                x, z = map(float, xz.strip().split(","))
                points.append((kind, name, x, z))
    return roads, points


def render(grid, roads):
    img = Image.new("RGB", (S, S), PAL["X"][0])
    px = img.load()
    hy = [[Y0 + h * YSTEP for (_, h) in row] for row in grid]
    for z in range(N):
        for x in range(N):
            c, h = grid[z][x]
            y = hy[z][x]
            if c == "W":
                col = WATER
                # 물가 밝은 띠: 이웃에 땅이 있으면
                for dz, dx in ((0, 1), (1, 0), (0, -1), (-1, 0), (2, 0), (0, 2), (-2, 0), (0, -2)):
                    zz, xx = z + dz, x + dx
                    if 0 <= zz < N and 0 <= xx < N and grid[zz][xx][0] not in ("W", "X"):
                        col = SHORE
                        break
            elif c in ("T",):
                col = PAL["G"][min(band(y), 3)]
            elif c in ("B", "R"):
                col = PAL["H"][0] if math.hypot(x - N / 2, z - N / 2) < 80 else PAL["D"][1]
            else:
                col = PAL.get(c, PAL["G"])[band(y)]
                # 언덕 그늘(북서쪽 빛): 북서 이웃이 더 높으면 어둡게 · 낮으면 밝게(±8%)
                if c != "X" and x > 0 and z > 0:
                    d = hy[z - 1][x - 1] - y
                    f = max(-0.08, min(0.08, d * 0.004))
                    col = tuple(max(0, min(255, int(v * (1 - f)))) for v in col)
            for oy in range(PX):
                for ox in range(PX):
                    px[x * PX + ox, z * PX + oy] = col
    d = ImageDraw.Draw(img)
    # 절벽 · 높이차 경계(굵은 어두운 선): 이웃 셀 높이차 ≥ 30 stud
    for z in range(1, N):
        for x in range(1, N):
            c = grid[z][x][0]
            if c in ("X", "W", "T", "B", "H", "R") or grid[z][x - 1][0] in ("T", "B", "H") or grid[z - 1][x][0] in ("T", "B", "H"):
                continue
            if abs(hy[z][x] - hy[z][x - 1]) >= 30 or abs(hy[z][x] - hy[z - 1][x]) >= 30:
                d.rectangle([x * PX - 1, z * PX - 1, x * PX + 1, z * PX + 1], fill=CLIFF)
    # 산 봉우리 기호(삼각형 + 한쪽 그림자): 높은 바위 · 눈의 지역 최대점
    step = 24
    for z0 in range(0, N, step):
        for x0 in range(0, N, step):
            best = None
            for z in range(z0, min(N, z0 + step)):
                for x in range(x0, min(N, x0 + step)):
                    c = grid[z][x][0]
                    if c in ("K", "N") and hy[z][x] >= 150 and (best is None or hy[z][x] > best[0]):
                        best = (hy[z][x], x, z)
            if best:
                _, x, z = best
                cx, cy, r = x * PX, z * PX, 11
                d.polygon([(cx, cy - r), (cx - r, cy + r * 0.8), (cx + r, cy + r * 0.8)], fill=(150, 140, 130), outline=CLIFF)
                d.polygon([(cx, cy - r), (cx + r, cy + r * 0.8), (cx + 2, cy + r * 0.8)], fill=(110, 100, 92))
                d.polygon([(cx, cy - r), (cx - r * 0.35, cy - r * 0.3), (cx + r * 0.35, cy - r * 0.3)], fill=(245, 245, 245))
    # 길(데이터): 진한 테두리 → 베이지 채움
    for kind, zone, pts in roads:
        line = [w2p(x, z) for x, z in pts]
        if len(line) < 2:
            continue
        w = 9 if kind == "main" else 6
        d.line(line, fill=ROAD_EDGE, width=w + 5, joint="curve")
        d.line(line, fill=ROAD_FILL, width=w, joint="curve")
    # 숲: 동글동글 나무 기호(나무 셀 격자 3칸마다 - 실제 나무 자리)
    for z in range(0, N, 4):
        for x in range(0, N, 4):
            if any(grid[zz][xx][0] == "T" for zz in range(z, min(N, z + 4)) for xx in range(x, min(N, x + 4))):
                cx, cy = x * PX + 4, z * PX + 4
                r = 8
                d.ellipse([cx - r, cy - r + 1, cx + r, cy + r + 1], fill=TREE_EDGE)
                d.ellipse([cx - r + 1, cy - r, cx + r - 1, cy + r - 2], fill=TREE_DARK)
                d.ellipse([cx - r + 2, cy - r + 1, cx + 1, cy - 1], fill=TREE_LIGHT)
    # 큰 건물: 위에서 본 윤곽 + 지붕 색(허브 = 붉은 기와 · 나머지 = 돌)
    for z in range(N):
        for x in range(N):
            if grid[z][x][0] != "B":
                continue
            wx = -EDGE + (x + 0.5) * (2 * EDGE / N)
            wz = -EDGE + (z + 0.5) * (2 * EDGE / N)
            roof = BLD_ROOF_HUB if math.hypot(wx, wz) < 460 else BLD_STONE
            edge = any(not (0 <= z + dz < N and 0 <= x + dx < N) or grid[z + dz][x + dx][0] != "B" for dz, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)))
            d.rectangle([x * PX, z * PX, x * PX + PX - 1, z * PX + PX - 1], fill=BLD_EDGE if edge else roof)
    return img


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--log")
    ap.add_argument("--out", default=os.path.join(ROOT, "art", "map"))
    ap.add_argument("--roads", default=os.path.join(HERE, "roads_points.txt"))
    a = ap.parse_args()
    log = a.log or newest_log()
    grid = load_grid(log)
    roads, points = load_roads(a.roads)
    img = render(grid, roads)
    img = img.filter(ImageFilter.SMOOTH)
    os.makedirs(a.out, exist_ok=True)
    img.save(os.path.join(a.out, "world_full.png"))
    img.resize((1024, 1024), Image.LANCZOS).save(os.path.join(a.out, "world_mini.png"))  # 미니맵 한 장(ImageRect로 잘라 쓴다 - 원형 · 회전)
    half = S // 2
    for r in range(2):
        for c in range(2):
            img.crop((c * half, r * half, (c + 1) * half, (r + 1) * half)).save(os.path.join(a.out, f"world_{r}_{c}.png"))
    counts = {}
    for row in grid:
        for c, _ in row:
            counts[c] = counts.get(c, 0) + 1
    print("셀 분류:", " ".join(f"{k}={v}" for k, v in sorted(counts.items())))
    print("길", len(roads), "· 지점", len(points), "· 저장", a.out)


if __name__ == "__main__":
    main()
