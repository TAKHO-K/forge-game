# -*- coding: utf-8 -*-
# QUEUE-ALL1 P6 로벅스 치장 메시(Blender bpy):
#   구름 고래(시즌 유료 줄 40칸 대표 · 활강 탈것) - 통통한 하늘색 몸 + 크림 배 + 가슴지느러미 + 꼬리 + 눈 + 배 밑 구름 뭉치.
#   좌표 = Roblox 공간(stud · 앞 = −Z · 위 = +Y) · 원점 = 등 위 앉는 자리(코드가 캐릭터 루트 밑에 붙인다). 파트 6 · 텍스처 없음(색 = 재질 색).
#   색 규칙(07 문서): 강한 주황 · 빨강 · 흰 + 자홍(태초) · 검정 + 금(초월) 금지 → 하늘색 · 크림 · 옅은 흰 구름.
# 실행: bash bl.sh make_cosmetics.py [--render 폴더]
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import artlib as A  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "art", "extras"))
SKY, CREAM, CLOUD, EYE, FIN = (126, 186, 240), (240, 238, 226), (236, 244, 252), (34, 44, 70), (104, 164, 226)


def body_rings(n=14):
    # 앞(−Z) 코 → 뒤(+Z) 꼬리 뿌리. (z, 반지름 x, 반지름 y, 위아래 이동)
    prof = [(-4.2, 0.9, 0.8, -0.3), (-3.6, 1.7, 1.5, -0.2), (-2.6, 2.2, 1.95, 0.0), (-1.2, 2.35, 2.05, 0.05), (0.4, 2.2, 1.9, 0.05), (1.8, 1.8, 1.55, 0.1), (3.0, 1.2, 1.0, 0.2), (3.9, 0.6, 0.55, 0.3)]
    return [A.section_z(A.circle2d(1.0, n), z, sx=rx, sy=ry, dy=dy - 2.2) for z, rx, ry, dy in prof]


def parts():
    body = A.loft(body_rings(), tip0=(0, -2.6, -4.6), tip1=(0, -1.8, 4.3))
    belly = A.ellipsoid(r=(1.9, 0.9, 3.4), n=12, rings=6, center=(0, -3.5, -0.6), squash_bottom=0.8)
    fins = A.merge(*[A.xform(A.ellipsoid(r=(1.5, 0.22, 0.75), n=8, rings=4), m=A.rot(rz=sx * -28, ry=sx * 20), t=(sx * 2.4, -3.2, -1.0)) for sx in (-1, 1)])
    tail_stem = A.tube([(0, -1.9, 3.9), (0, -1.5, 5.0), (0, -1.1, 5.8)], lambda u: 0.55 * (1 - 0.5 * u), sides=8)
    flukes = A.merge(*[A.xform(A.ellipsoid(r=(1.3, 0.18, 0.6), n=8, rings=4), m=A.rot(ry=sx * 30), t=(sx * 1.0, -1.05, 6.1)) for sx in (-1, 1)])
    eyes = A.merge(*[A.ellipsoid(r=(0.2, 0.3, 0.26), n=8, rings=4, center=(sx * 1.88, -1.95, -3.0)) for sx in (-1, 1)])
    cloud = A.merge(*[A.ellipsoid(r=(r, r * 0.6, r), n=10, rings=5, center=c) for c, r in (((0, -4.6, -1.8), 1.7), ((1.6, -4.7, 0.4), 1.5), ((-1.6, -4.7, 0.4), 1.5), ((0, -4.8, 2.2), 1.4), ((2.6, -4.4, -1.2), 1.0), ((-2.6, -4.4, -1.2), 1.0))])
    return [("Body", body, SKY, False), ("Belly", belly, CREAM, False), ("Fins", fins, FIN, False), ("Tail", A.merge(tail_stem, flukes), SKY, False), ("Eyes", eyes, EYE, False), ("Cloud", cloud, CLOUD, False)]


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    render = os.path.abspath(argv[argv.index("--render") + 1]) if "--render" in argv else None
    A.reset()
    col = A.new_collection("cloud_whale")
    objs = [A.make_obj(n_, g, rgb, col, neon=neon, smooth=True, mat_name="cloud_whale_" + n_) for n_, g, rgb, neon in parts()]
    A.export_fbx(os.path.join(OUT, "cloud_whale.fbx"), objs)
    meta = A.meta_of(objs, 2400, {"kind": "cosmetic"})
    A.write_json(os.path.join(OUT, "cloud_whale.meta.json"), meta)
    print("cloud_whale 파트 %d · 삼각형 %d" % (meta["partCount"], meta["totalTris"]))
    if render:
        A.render_views(objs, os.path.join(render, "cloud_whale"), views=("front", "side", "34"), kinds=("game",), sil=True, hull=0.05, res=(600, 600))


main()
