# -*- coding: utf-8 -*-
# A2-N1 아이템 아이콘(Blender bpy): 무기 4종 × 8등급을 같은 카메라 · 조명으로 256×256 투명 PNG.
#   물체만(등급 테두리 색은 UI가 입힌다) · 게임 느낌 렌더(평면 조명 + 뒤집은 껍데기 외곽선) · 긴 축을 대각선(↗)으로 눕혀 칸을 채운다.
#   파일명 = <직업 id>_<등급 키>.png(무기는 아이템 ID가 따로 없고 저장 = classes[직업].weapon.grade - ArmorData.gradeOrder 키) → roblox/art/icons/weapons/.
#   512로 렌더해 시스템 python(Pillow)이 256으로 줄인다(--size로 바꿈). 방어구 아이콘은 make_armor.py가 같은 함수(render_icon)를 쓴다.
# 실행: bash bl.sh make_icons.py --weapons greatsword,dualblade,bow,healer [--grades normal,...] [--out 폴더]
import bpy
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import artlib as A  # noqa: E402
import make_weapons as W  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "art", "icons", "weapons"))
RES = 512
# 아이콘 자세: 표시 회전(DISPLAY_ROT - 긴 축이 위) 뒤에 화면 평면에서 ↗ 대각(ICON_ROLL) · 살짝 기울여 두께가 보이게
ICON_ROLL = -38.0  # −45°는 칼끝 테이퍼(축에서 약 31°) 한쪽 모서리가 거의 수평이 돼 끝이 잘린 것처럼 보였다(착시 - 실측)
ICON_TILT = (12.0, 18.0)  # (앞으로 숙임 · 옆으로 돌림) 도


def render_icon(objs, path, base_rot=(0, 0, 0), roll=ICON_ROLL, tilt=ICON_TILT, hull=0.04, pad=1.08):
    """objs를 아이콘 한 장으로. base_rot = 긴 축을 화면 위로 세우는 회전(도) · roll = 화면 평면 회전"""
    e = A.stand(objs)
    R = (Matrix.Rotation(math.radians(roll), 3, "Y") @ Matrix.Rotation(math.radians(tilt[0]), 3, "X") @ Matrix.Rotation(math.radians(tilt[1]), 3, "Z")
         @ (Matrix.Rotation(math.radians(base_rot[2]), 3, "Z") @ Matrix.Rotation(math.radians(base_rot[1]), 3, "Y") @ Matrix.Rotation(math.radians(base_rot[0]), 3, "X")))
    e.rotation_euler = R.to_euler()
    scene = A.setup_render("game", (RES, RES))
    if os.environ.get("ICON_STYLE") == "v31":  # QUEUE-ALL6 E3: 왼쪽 위 주광 + 그림자 · 하이라이트 · 모서리 강조(외곽선 · 등급 뒤 빛 · 맞춤은 icon_post.py)
        sh = scene.display.shading
        sh.light = os.environ.get("ICON_LIGHT", "MATCAP")  # 매트캡 toon_light = 흰 몸은 희게 · 만화풍 면 음영(STUDIO는 전체가 어두워 태초가 회색)
        sh.studio_light = os.environ.get("ICON_STUDIO", "toon_light.exr")
        sh.show_specular_highlight = True
        sh.show_shadows = True
        sh.shadow_intensity = 0.35
        sh.show_cavity = True
        sh.cavity_type = "BOTH"
        sh.cavity_ridge_factor = 1.2
        sh.cavity_valley_factor = 0.8
        sh.curvature_ridge_factor = 1.0
        scene.display.light_direction = (-0.55, 0.45, 0.70)
        scene.display.shadow_shift = 0.08
        hull = 0  # 외곽선은 후처리(알파 팽창)로 - 고르게 굵게
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    hidden = [o for o in scene.objects if o.type == "MESH" and o not in objs]
    for o in hidden:
        o.hide_render = True
    if hull:
        for o in objs:
            A.add_hull(o, hull)
    lo, hi = A.bbox_world(objs)
    center = (lo + hi) / 2
    cam = A.camera()
    cam.data.ortho_scale = max((hi - lo).x, (hi - lo).z) * pad  # 카메라 = 앞(+Y)에서 봄 → 화면 = X · Z
    cam.data.clip_end = 500
    A.aim(cam, center, 0, 0)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    if hull:
        A.remove_hulls(objs)
    for o in hidden:
        o.hide_render = False
    A.unstand(objs, e)


def parse():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opt = {"weapons": list(W.BUILDERS), "grades": list(A.GRADES), "out": OUT}
    for i in range(0, len(argv) - 1, 2):
        k = argv[i].lstrip("-")
        opt[k] = argv[i + 1].split(",") if k in ("weapons", "grades") else os.path.abspath(argv[i + 1])
    return opt


def main():
    opt = parse()
    os.makedirs(opt["out"], exist_ok=True)
    for weapon in opt["weapons"]:
        for grade in opt["grades"]:
            A.reset()
            col, objs = W.build(weapon, grade)
            objs = [o for o in objs if o.name.split(".")[0] != "String"] if weapon != "bow" else objs  # 활 시위는 아이콘에 남긴다(활로 읽히게)
            path = os.path.join(opt["out"], "%s_%s.png" % (weapon, grade))
            render_icon(objs, path, base_rot=W.DISPLAY_ROT[weapon])
            print("[make_icons]", weapon, grade, path)
    print("[make_icons] 끝")


if __name__ == "__main__":
    main()
