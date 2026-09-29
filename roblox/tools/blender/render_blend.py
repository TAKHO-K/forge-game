# -*- coding: utf-8 -*-
# A2-N1 비교 렌더: 이미 있는 .blend(이전 버전)를 열어 컬렉션마다 같은 조건(artlib 렌더)으로 찍는다.
# 실행: bash bl.sh render_blend.py --blend <파일> --out <폴더> [--prefix 이름] [--rot -90,0,0] [--views front,34] [--kinds game,form] [--hull 0.045]
#   컬렉션 이름 = 파일 이름 뒤쪽(예: greatsword_normal → <prefix>_normal_game_front.png). 메시가 없는 컬렉션은 건너뛴다.
import bpy
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import artlib as A  # noqa: E402


def parse():
    argv = sys.argv[sys.argv.index("--") + 1:]
    opt = {"rot": "0,0,0", "views": "front,34", "kinds": "game,form", "hull": "0.045", "prefix": "old"}
    for i in range(0, len(argv) - 1, 2):
        opt[argv[i].lstrip("-")] = argv[i + 1]
    return opt


def main():
    opt = parse()
    bpy.ops.wm.open_mainfile(filepath=os.path.abspath(opt["blend"]))
    A._CAM.clear()
    for o in list(bpy.data.objects):
        if o.type != "MESH":
            bpy.data.objects.remove(o)
    rot = tuple(math.radians(float(a)) for a in opt["rot"].split(","))
    for col in list(bpy.data.collections):
        objs = [o for o in col.objects if o.type == "MESH" and not o.name.endswith("_Outline")]
        if not objs:
            continue
        for o in objs:
            o.modifiers.clear()
            o.hide_render = False
        tail = col.name.split("_", 1)[1] if "_" in col.name else col.name
        e = A.stand(objs)
        e.rotation_euler = rot
        A.render_views(objs, os.path.join(os.path.abspath(opt["out"]), "%s_%s" % (opt["prefix"], tail)),
                       views=tuple(opt["views"].split(",")), kinds=tuple(opt["kinds"].split(",")), hull=float(opt["hull"]), res=(700, 900))
        A.unstand(objs, e)
        print("[render_blend]", col.name, len(objs), sum(A.tri_count(o) for o in objs))


if __name__ == "__main__":
    main()
