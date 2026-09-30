# -*- coding: utf-8 -*-
"""A2-N4 §3-2 슬라임 구역 가장자리 풀 덤불(카툰 · 한 파트 · 삼각형 ≤ 120) → roblox/art/props/grass_tuft.fbx(+ .meta.json).

실행: bash roblox/tools/blender/bl.sh roblox/tools/blender/make_grass_tuft.py -- [--render <폴더>]
모양: 바닥 원점 · 높이 약 2.2 stud · 잎 7장(끝이 뾰족한 3면 쐐기 · 바깥으로 벌어지며 살짝 휨) · 색은 Studio 클라가 칠한다(여기 색 = 미리보기).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import artlib as A  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
RENDER = None
for i, a in enumerate(argv):
    if a == "--render":
        RENDER = os.path.abspath(argv[i + 1])

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "props")
BUDGET = 120


def blade(angle_deg, lean, height, width, bend):
    """Roblox 공간 잎 하나: 밑변 삼각형(두께) → 가운데 → 끝 점. 바깥(angle 방향)으로 lean만큼 기울고 bend만큼 휜다."""
    a = math.radians(angle_deg)
    d = (math.cos(a), 0.0, math.sin(a))
    s = (-math.sin(a), 0.0, math.cos(a))
    t = width * 0.35
    r0 = 0.28  # 밑동 반경(잎이 한 점에서 안 나온다 - 덤불처럼 벌어진 밑)
    o = (d[0] * r0, 0.0, d[2] * r0)
    base = [(o[0] + s[0] * width - d[0] * t, 0.0, o[2] + s[2] * width - d[2] * t), (o[0] - s[0] * width - d[0] * t, 0.0, o[2] - s[2] * width - d[2] * t), (o[0] + d[0] * t, 0.0, o[2] + d[2] * t)]
    mid_off = (o[0] + d[0] * lean * 0.45, height * 0.5, o[2] + d[2] * lean * 0.45)
    mid = [((p[0] - o[0]) * 0.6 + mid_off[0], mid_off[1], (p[2] - o[2]) * 0.6 + mid_off[2]) for p in base]
    tip = (o[0] + d[0] * (lean + bend), height, o[2] + d[2] * (lean + bend))
    verts = base + mid + [tip]
    faces = []
    for k in range(3):
        n = (k + 1) % 3
        faces.append((k, n, 3 + n, 3 + k))
        faces.append((3 + k, 3 + n, 6))
    faces.append((2, 1, 0))
    return verts, faces


def main():
    A.reset()
    col = A.new_collection("GrassTuft")
    geos = []
    n = 7
    for i in range(n):
        ang = i / n * 360 + (17 if i % 2 else 0)
        h = 1.2 + 0.6 * ((i * 37) % 10) / 10
        geos.append(blade(ang, 0.8 + 0.25 * (i % 3), h, 0.2, 0.45))
    geo = A.merge(*geos)
    obj = A.make_obj("Tuft", geo, (111, 192, 74), col, origin=(0, 0, 0))
    tris = A.tri_count(obj)
    print("[grass_tuft] 삼각형 %d / %d" % (tris, BUDGET))
    A.export_fbx(os.path.join(OUT, "grass_tuft.fbx"), [obj])
    A.write_json(os.path.join(OUT, "grass_tuft.meta.json"), A.meta_of([obj], BUDGET, {"version": "A2-N4", "item": "grass_tuft"}))
    if RENDER:
        A.render_views([obj], os.path.join(RENDER, "grass_tuft"), hull=0.02, res=(600, 600))


main()
