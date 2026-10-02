"""QUEUE-ALL9A 4 큰 나무 카툰 껍질 · 발코니 나무 판 무늬(이음매 없는 512² 타일) → roblox/art/terrain/tree_bark.png · tree_plank.png.

사용: python roblox/tools/mapgen/bark_texture.py   (Pillow만 - 이미 설치됨)
  ALL8 자갈길(cobble_texture.py)과 같은 방식: ArtStyleV1 평면 재질 위에 Texture로 붙인다(server/HubArt · 데이터 = HubPropsData.treeTexture).
  껍질 = 세로 홈 + 옹이 몇 개 · 따뜻한 갈색 3톤(옛 단색 142,90,60 · 166,110,74보다 한 톤 밝게) / 판 = 가로 판자 + 이음 + 못.
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

N = 512
ART = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "art", "terrain"))
BARK_BASE = (178, 120, 80)
BARK_TONES = [(184, 126, 84), (170, 112, 74), (192, 134, 90)]
BARK_GROOVE = (122, 78, 50)
BARK_HI = (206, 150, 104)
PLANK_TONES = [(204, 154, 102), (192, 142, 92), (212, 164, 110)]
PLANK_SEAM = (128, 86, 54)


def tiled(draw_fn, seed):
    """3 × 3으로 그린 뒤 가운데를 잘라 이음매 없게."""
    rng = random.Random(seed)
    big = Image.new("RGB", (N * 3, N * 3), BARK_BASE)
    d = ImageDraw.Draw(big)
    shapes = draw_fn(rng)
    for tx in (-1, 0, 1):
        for ty in (-1, 0, 1):
            for kind, pts, col, w in shapes:
                moved = [(x + N + tx * N, y + N + ty * N) for x, y in pts]
                if kind == "poly":
                    d.polygon(moved, fill=col)
                elif kind == "line":
                    d.line(moved, fill=col, width=w, joint="curve")
                elif kind == "ellipse":
                    (x0, y0), (x1, y1) = moved
                    d.ellipse((x0, y0, x1, y1), fill=col)
                elif kind == "ring":
                    (x0, y0), (x1, y1) = moved
                    d.ellipse((x0, y0, x1, y1), outline=col, width=w)
    return big.crop((N, N, 2 * N, 2 * N))


def bark(rng):
    shapes = []
    cols = 9  # 세로 판(홈 사이 껍질 띠)
    xs = [i * N / cols + rng.uniform(-6, 6) for i in range(cols)]
    for i, x0 in enumerate(xs):
        x1 = xs[i + 1] if i + 1 < cols else xs[0] + N
        col = rng.choice(BARK_TONES)
        shapes.append(("poly", [(x0, 0), (x1, 0), (x1, N), (x0, N)], col, 0))
    for x in xs:  # 세로 홈(살짝 흔들리는 선 · 위아래 끝이 같아야 이음매 없음)
        pts = []
        phase = rng.uniform(0, 2 * math.pi)
        for k in range(0, 17):
            y = k * N / 16
            pts.append((x + 5 * math.sin(phase + 2 * math.pi * k / 16 * 2), y))
        shapes.append(("line", pts, BARK_GROOVE, 7))
        shapes.append(("line", [(p[0] + 6, p[1]) for p in pts], BARK_HI, 2))  # 홈 옆 밝은 테
    for _ in range(14):  # 짧은 가로 갈라짐
        x, y = rng.uniform(0, N), rng.uniform(0, N)
        shapes.append(("line", [(x, y), (x + rng.uniform(14, 26), y + rng.uniform(-3, 3))], BARK_GROOVE, 3))
    for _ in range(3):  # 옹이
        x, y = rng.uniform(40, N - 40), rng.uniform(40, N - 40)
        rx, ry = rng.uniform(14, 20), rng.uniform(20, 28)
        shapes.append(("ellipse", [(x - rx - 6, y - ry - 6), (x + rx + 6, y + ry + 6)], BARK_HI, 0))
        shapes.append(("ellipse", [(x - rx, y - ry), (x + rx, y + ry)], BARK_GROOVE, 0))
        shapes.append(("ring", [(x - rx * 0.55, y - ry * 0.55), (x + rx * 0.55, y + ry * 0.55)], (96, 60, 40), 3))
    return shapes


def plank(rng):
    shapes = []
    rows = 8
    h = N / rows
    for r in range(rows):
        y0, y1 = r * h, (r + 1) * h
        col = rng.choice(PLANK_TONES)
        shapes.append(("poly", [(0, y0), (N, y0), (N, y1), (0, y1)], col, 0))
        shapes.append(("line", [(0, y0), (N, y0)], PLANK_SEAM, 5))
        shapes.append(("line", [(0, y0 + 4), (N, y0 + 4)], tuple(min(255, c + 16) for c in col), 2))
        off = rng.uniform(0, N)
        for k in range(2):  # 판 이음(세로) + 못 두 개
            x = (off + k * N / 2) % N
            shapes.append(("line", [(x, y0), (x, y1)], PLANK_SEAM, 4))
            for ny in (y0 + h * 0.3, y0 + h * 0.7):
                shapes.append(("ellipse", [(x + 7, ny - 3), (x + 13, ny + 3)], (110, 80, 60), 0))
        for _ in range(3):  # 나뭇결
            gy = rng.uniform(y0 + 10, y1 - 8)
            gx = rng.uniform(0, N)
            shapes.append(("line", [(gx, gy), (gx + rng.uniform(40, 90), gy + rng.uniform(-2, 2))], tuple(c - 18 for c in col), 2))
    return shapes


def main():
    os.makedirs(ART, exist_ok=True)
    for name, fn, seed in (("tree_bark.png", bark, 20261003), ("tree_plank.png", plank, 20261004)):
        img = tiled(fn, seed).filter(ImageFilter.SMOOTH)
        out = os.path.join(ART, name)
        img.save(out)
        print("저장", out)


if __name__ == "__main__":
    main()
