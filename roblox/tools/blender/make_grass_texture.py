"""A2-N4 §3-2 슬라임 구역 카툰 잔디 텍스처(이음매 없음 · 512 × 512) - Blender 안에서 numpy로 그려 PNG로 저장.

실행: bash roblox/tools/blender/bl.sh roblox/tools/blender/make_grass_texture.py -- [--out roblox/art/terrain/grass_v1.png] [--seed 7] [--gray]
모양(art-direction-v1 카툰 규칙): 밝은 잔디 바탕 · 넓은 명암 얼룩(저주파 · 2톤) · 짧은 풀잎 획(3톤 - 밝은 끝 · 어두운 뿌리) · 작은 꽃 점 약간. 모든 도형은 가장자리를 감싸 그린다(타일 이음매 0).
"""
import os
import sys

import bpy
import numpy as np

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = "roblox/art/terrain/grass_v1.png"
SEED = 7
GRAY = "--gray" in argv  # A2-N4 Play: 색 텍스처 × 지형 재질 색(MaterialColors)이 곱해져 짙어지고 다른 구역(T3 이끼) 색까지 바뀌었다 → 명암 결만(색 = 구역 재질 색)
for i, a in enumerate(argv):
    if a == "--out":
        OUT = argv[i + 1]
    if a == "--seed":
        SEED = int(argv[i + 1])

N = 512
rng = np.random.default_rng(SEED)


def hexc(h):
    return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)])


BASE = hexc("7BC950")     # 바닥 잔디(ArtStyleV1 T1 잔디와 같은 색)
SHADE = hexc("62B044")    # 얼룩 그늘
LIGHT = hexc("98DA68")    # 얼룩 밝은 쪽
BLADE_DARK = hexc("4E9A38")
BLADE_MID = hexc("6FC04A")
BLADE_TIP = hexc("B4EA7C")
FLOWER = [hexc("FFF4C8"), hexc("FFD2E6")]

if GRAY:  # 밝은 회색 명암만(평균 ≈ 0.9 - 재질 색을 거의 그대로 보이게)
    g = lambda v: np.array([v, v, v])
    BASE, SHADE, LIGHT = g(0.9), g(0.8), g(0.97)
    BLADE_DARK, BLADE_MID, BLADE_TIP = g(0.72), g(0.86), g(1.0)
    FLOWER = [g(1.0)]

img = np.zeros((N, N, 3))
img[:] = BASE

# 1) 넓은 명암 얼룩: 주기 함수(이음매 없음) 합 → 2톤 계단(카툰)
yy, xx = np.mgrid[0:N, 0:N] / N
field = np.zeros((N, N))
for _ in range(6):
    fx, fy = rng.integers(1, 4), rng.integers(1, 4)
    ph1, ph2 = rng.uniform(0, 2 * np.pi, 2)
    field += np.sin(2 * np.pi * fx * xx + ph1) * np.sin(2 * np.pi * fy * yy + ph2)
field /= np.abs(field).max()
img[field < -0.35] = SHADE
img[field > 0.45] = LIGHT


def stamp_tri(x0, y0, x1, y1, x2, y2, color):
    """삼각형을 감싸 그린다(9칸 복사 - 가장자리 넘는 조각이 반대편에)."""
    xs = np.array([x0, x1, x2])
    ys = np.array([y0, y1, y2])
    minx, maxx = int(np.floor(xs.min())), int(np.ceil(xs.max()))
    miny, maxy = int(np.floor(ys.min())), int(np.ceil(ys.max()))
    gx, gy = np.meshgrid(np.arange(minx, maxx + 1), np.arange(miny, maxy + 1))
    d = (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2)
    if abs(d) < 1e-6:
        return
    a = ((y1 - y2) * (gx - x2) + (x2 - x1) * (gy - y2)) / d
    b = ((y2 - y0) * (gx - x2) + (x0 - x2) * (gy - y2)) / d
    c = 1 - a - b
    inside = (a >= 0) & (b >= 0) & (c >= 0)
    px, py = gx[inside] % N, gy[inside] % N
    img[py, px] = color


# 2) 풀잎 획: 뿌리(어둡게) → 몸통 → 끝(밝게) 3톤 · 살짝 기운 짧은 삼각형
for _ in range(2600):
    x, y = rng.uniform(0, N, 2)
    h = rng.uniform(9, 18)
    w = rng.uniform(2.2, 3.6)
    lean = rng.uniform(-5, 5)
    stamp_tri(x - w, y, x + w, y, x + lean * 0.6, y - h * 0.55, BLADE_DARK)
    stamp_tri(x - w * 0.7, y - h * 0.25, x + w * 0.7, y - h * 0.25, x + lean * 0.85, y - h * 0.8, BLADE_MID)
    stamp_tri(x - w * 0.35, y - h * 0.6, x + w * 0.35, y - h * 0.6, x + lean, y - h, BLADE_TIP)

# 3) 작은 꽃 점(드물게)
for _ in range(26):
    x, y = rng.uniform(0, N, 2)
    col = FLOWER[rng.integers(0, len(FLOWER))]
    for k in range(5):
        ang = k / 5 * 2 * np.pi
        cx, cy = x + np.cos(ang) * 2.2, y + np.sin(ang) * 2.2
        stamp_tri(cx - 1.4, cy, cx + 1.4, cy, cx, cy - 1.8, col)

# Blender 이미지로 저장(pixels = 아래에서 위 · RGBA)
rgba = np.ones((N, N, 4))
rgba[:, :, :3] = img[::-1]
im = bpy.data.images.new("grass_v1", width=N, height=N, alpha=False)
im.pixels = rgba.ravel().tolist()
os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
im.filepath_raw = os.path.abspath(OUT)
im.file_format = "PNG"
im.save()
print("[grass] 저장:", os.path.abspath(OUT), N, "x", N)
