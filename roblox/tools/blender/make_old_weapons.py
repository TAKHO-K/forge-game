# -*- coding: utf-8 -*-
# A2-N1 비교용: 지금 게임 무기(WeaponModelData)를 치수대로 도형으로 재현해 같은 조건으로 렌더한다(이전 버전 = "도형").
#   쌍검 · 지팡이는 외부 메시(rbxassetid)라 모양을 못 가져온다 → size 필드 치수의 상자 · 원기둥 대용(보고서에 "치수 재현" 표기).
#   활 = limbs 7개 상자(실측 좌표 그대로) + 시위.
# 실행: bash bl.sh make_old_weapons.py -- <출력 폴더>
import bpy
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import artlib as A  # noqa: E402

LIMBS = [((1.0095, 0.2524, 0.2524), (-0.9161, 0.0151, -0.5650), 15), ((1.0095, 0.2524, 0.2524), (-1.8146, 0.0151, -0.1915), 30),
         ((1.0625, 0.3028, 0.3180), (0.0038, 0, -0.6735), 0), ((1.0095, 0.2524, 0.2524), (0.9540, 0.0151, -0.5474), -15),
         ((1.0095, 0.2524, 0.2524), (1.8095, 0.0151, -0.1991), -30), ((1.0095, 0.2524, 0.2524), (-2.5616, 0.0151, 0.3788), 45),
         ((1.0095, 0.2524, 0.2524), (2.5616, 0.0151, 0.3763), -45)]


def main():
    out = os.path.abspath(sys.argv[sys.argv.index("--") + 1:][0])
    A.reset()
    sets = {}
    col = A.new_collection("old_dualblade")
    sets["dualblade"] = (col, [A.make_obj("Blade", A.box(0.5, 0.18, 2.0, center=(0, 0, 1.0)), (205, 232, 232), col),
                               A.make_obj("Guard", A.box(0.7, 0.24, 0.14, center=(0, 0, 0)), (205, 232, 232), col),
                               A.make_obj("Grip", A.lathe([(0.07, -0.6), (0.07, 0.0)], 6, axis="Z"), (205, 232, 232), col)], (-90, 0, 0))
    col = A.new_collection("old_bow")
    objs = [A.make_obj("Limb%d" % i, A.xform(A.box(*s), m=A.rot(ry=r), t=p), (160, 132, 79), col) for i, (s, p, r) in enumerate(LIMBS)]
    objs.append(A.make_obj("String", A.tube([(2.87, 0, 0.7347), (-2.87, 0, 0.7347)], 0.025, sides=3), (235, 235, 235), col))
    sets["bow"] = (col, objs, (-90, -90, 0))
    col = A.new_collection("old_healer")
    sets["healer"] = (col, [A.make_obj("Shaft", A.lathe([(0.12, -2.8), (0.12, 2.4)], 6), (215, 200, 235), col),
                            A.make_obj("Head", A.ellipsoid((0.4, 0.4, 0.4), n=8, rings=5, center=(0, 2.6, 0)), (215, 200, 235), col)], (0, 0, 0))
    for w, (col, objs, r) in sets.items():
        e = A.stand(objs)
        e.rotation_euler = tuple(math.radians(a) for a in r)
        A.render_views(objs, os.path.join(out, "old_%s" % w), views=("front",), kinds=("game",), sil=True, hull=0.045, res=(700, 900))
        A.unstand(objs, e)
    print("[make_old_weapons] 끝")


if __name__ == "__main__":
    main()
