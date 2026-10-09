"""BOSS-NIGHT-2 3 아틀라스 가장자리 패딩(검은 배경 번짐 막기).

사용: python roblox/tools/blender/atlas_pad.py <png> [<png> ...]  (제자리 덮어씀 - git이 원본을 보관)
  KIT 굽기 아틀라스는 UV 조각 사이가 검정(0,0,0)이라 가까이선 조각 테두리에 검은 점 · 멀리선 밉맵이 검정을 섞어 검은 덩어리로 보였다(수정 여왕 날개).
  바깥과 이어진 검은 배경만 골라(테두리에서 flood fill - 조각 안의 검은 눈 · 선은 그대로) 이웃 색으로 iters번 번지게 채우고 남은 곳은 평균색.
"""
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ITERS = 24
MIN_BG = 300


def pad(path):
    img = Image.open(path).convert("RGB")
    a = np.asarray(img).astype(np.float32)
    black = a.sum(-1) < 12
    # 배경 = 큰 검은 덩어리(MIN_BG픽셀 이상 - 조각 사이 빈 곳) · 작은 덩어리(눈 · 선)는 그대로(scipy 연결 성분 - 모서리 flood fill은 조각이 벽처럼 막아 일부 배경을 놓쳤다)
    labels, n = ndimage.label(black)
    sizes = ndimage.sum(black, labels, range(n + 1))
    bg = (sizes >= MIN_BG)[labels] & black
    filled = ~bg
    out = a.copy()
    out[bg] = 0
    for _ in range(ITERS):
        acc = np.zeros_like(out)
        cnt = np.zeros(bg.shape, np.float32)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dx == 0 and dy == 0:
                    continue
                f = np.roll(np.roll(filled, dy, 0), dx, 1)
                c = np.roll(np.roll(out, dy, 0), dx, 1)
                acc += c * f[..., None]
                cnt += f
        grow = (~filled) & (cnt > 0)
        out[grow] = acc[grow] / cnt[grow][:, None]
        filled = filled | grow
    if (~filled).any():
        out[~filled] = a[~bg].mean(0)
    Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).save(path)
    print("padded", path, "background", round(float(bg.mean()), 3), "kept black", int((black & ~bg).sum()))


if __name__ == "__main__":
    for p in sys.argv[1:]:
        pad(p)
