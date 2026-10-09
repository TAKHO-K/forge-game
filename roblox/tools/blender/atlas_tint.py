# -*- coding: utf-8 -*-
# BOSS-NIGHT-2 아틀라스 색조 변형(PIL · Blender 불필요): KIT 아틀라스 → <이름>_<태그>.png(색상 + 도 · 채도 × · 명도 ×).
#   MeshPart.TextureID는 Color로 물들지 않아(불투명 텍스처) 색조 노브(BossFrameworkData.atlasTint)는 미리 구운 변형 아틀라스를 고른다.
#   전갈 모래 쪽(tag sand): 컨셉(scorpion_v1_*) 대비 3D가 채도 높고 어두움(채도 0.67 vs 0.62 · 명도 0.63 vs 0.69) → 색상 +6 · 채도 × 0.82 · 명도 × 1.08.
# 실행: python atlas_tint.py <아틀라스.png> <태그> <색상 도> <채도 배율> <명도 배율>
import colorsys
import os
import sys

import numpy as np
from PIL import Image

src, tag = sys.argv[1], sys.argv[2]
dh, ks, kv = float(sys.argv[3]), float(sys.argv[4]), float(sys.argv[5])
im = Image.open(src).convert("RGBA")
a = np.asarray(im).astype(np.float32) / 255.0
rgb = a[..., :3]
mx, mn = rgb.max(-1), rgb.min(-1)
v = mx
s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
d = np.maximum(mx - mn, 1e-6)
r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) / 6.0
h = np.where(mx == mn, 0, h)
h = (h + dh / 360.0) % 1.0
s = np.clip(s * ks, 0, 1)
v = np.clip(v * kv, 0, 1)
i = np.floor(h * 6).astype(int) % 6
f = h * 6 - np.floor(h * 6)
p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
out = np.zeros_like(rgb)
for k, (R, G, B) in enumerate([(v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q)]):
    m = i == k
    out[..., 0][m], out[..., 1][m], out[..., 2][m] = R[m], G[m], B[m]
res = np.concatenate([out, a[..., 3:]], -1)
dst = os.path.splitext(src)[0] + "_" + tag + ".png"
Image.fromarray((res * 255 + 0.5).astype(np.uint8), "RGBA").save(dst)
print("wrote", dst)
