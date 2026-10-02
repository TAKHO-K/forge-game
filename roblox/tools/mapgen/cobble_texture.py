"""QUEUE-ALL8 B2 허브 거리 · 광장 카툰 자갈 무늬(이음매 없는 512² 타일) → roblox/art/terrain/hub_cobble.png.

사용: python roblox/tools/mapgen/cobble_texture.py   (Pillow만 - 이미 설치됨)
  ArtStyleV1이 재질을 평면(CartoonFlat) 변형으로 덮어 Pavement · Cobblestone 무늬가 안 보인다 → 파트 윗면 Texture로 붙인다(server/HubArt).
  색 = 지도 큰 길(render.py ROAD_FILL 236,218,168 · ROAD_EDGE 118,88,54) 계열 · 돌 = 둥근 다각형 · 줄눈 = 진한 갈색.
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

N = 512
CELL = 64
OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "art", "terrain", "hub_cobble.png"))
MORTAR = (150, 118, 84)
STONES = [(234, 216, 176), (224, 204, 162), (238, 222, 186), (214, 194, 152), (228, 210, 172)]


def main():
    rng = random.Random(20261002)
    big = Image.new("RGB", (N * 3, N * 3), MORTAR)
    d = ImageDraw.Draw(big)
    cells = []
    for gy in range(N // CELL):
        for gx in range(N // CELL):
            off = (CELL / 2) if gy % 2 else 0  # 엇갈린 줄(벽돌 쌓기처럼)
            cx = gx * CELL + off + CELL / 2 + rng.uniform(-6, 6)
            cy = gy * CELL + CELL / 2 + rng.uniform(-6, 6)
            rx, ry = CELL * 0.56 - rng.uniform(0, 3), CELL * 0.56 - rng.uniform(0, 3)
            sides = rng.choice([7, 8, 9])
            rot = rng.uniform(0, math.pi)
            col = rng.choice(STONES)
            cells.append((cx, cy, rx, ry, sides, rot, col))
    for tx in (-1, 0, 1):  # 이음매 없게 3 × 3으로 그린 뒤 가운데를 자른다
        for ty in (-1, 0, 1):
            for cx, cy, rx, ry, sides, rot, col in cells:
                pts = []
                for k in range(sides):
                    a = rot + 2 * math.pi * k / sides
                    pts.append((N + tx * N + cx + math.cos(a) * rx, N + ty * N + cy + math.sin(a) * ry))
                d.polygon(pts, fill=col)
                # 위쪽 밝은 테(카툰 하이라이트)
                hl = [(p[0], p[1] - 2) for p in pts[: max(2, sides // 2)]]
                d.line(hl, fill=tuple(min(255, c + 14) for c in col), width=3)
    img = big.crop((N, N, 2 * N, 2 * N)).filter(ImageFilter.SMOOTH)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT)
    print("저장", OUT)


if __name__ == "__main__":
    main()
