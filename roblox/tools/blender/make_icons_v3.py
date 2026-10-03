# -*- coding: utf-8 -*-
# QUEUE-ALL9C 2-5 장비 아이콘 v3(docs/design/gear-art-v3.md 8절) - Blender bpy · 512 투명 PNG(후처리 = icons_v3.py가 256 · 맞춤 · 외곽선).
#   대상 = 4직업 × 3부위(갑옷 · 장갑 · 신발) × 8등급 + 무기 4 × 8 = 128장. 세트는 굽지 않는다(세트 구분 = 칸 배지 - UI).
#   색: 본체 = 등급 메인 · 부착물 = 등급 밝은 색(ItemVisualData.gradeVisuals - 등급 색 한 곳) · 빛 조각(Glow) = 밝은 색 그대로.
#   같은 부위 = 같은 각도(VIEW): 갑옷 정면 15° 위 · 장갑 오른손 손등 45° · 신발 오른발 측면 30° · 무기 대각 45°(끝 우상단). 크기 맞춤 = 후처리(경계 상자 · 여백 10%).
#   메시 = make_armor_class.build(지금 v3 메시 · 외형 = ArtImportData.armorLookOfGrade) · make_weapons.build → ALL9E 새 메시도 같은 함수 이름이면 그대로 다시 돌린다.
# 실행: bash bl.sh make_icons_v3.py --items armor:greatsword:normal,weapon:bow:transcendent,... [--out 폴더]   (보통은 icons_v3.py가 부른다)
import bpy
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import artlib as A  # noqa: E402
import make_armor_class as AC  # noqa: E402
import make_weapons as W  # noqa: E402
from mathutils import Vector  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "art", "icons", "gear_v3")
IVD = os.path.join(ROOT, "src", "shared", "data", "ItemVisualData.lua")
RES = 512

# 부위별 카메라(yaw = 0 정면 · +90 = 캐릭터 오른쪽에서 · pitch = 위에서 내려다본 각) · 무기 = 받침 회전 뒤 정면
VIEW = {"armor": (0.0, 15.0), "gloves": (45.0, 15.0), "shoes": (60.0, 15.0)}
ONLY_RIGHT = {"gloves": ("Glove_R", "Bracer_R"), "shoes": ("Boot_R", "Greave_R")}  # 장갑 · 신발 = 오른쪽 한 짝
WEAPON_ROLL = -45.0  # 긴 축(위) → 화면에서 45° 오른쪽으로 눕힘 = 끝이 우상단
WEAPON_TILT = (10.0, 15.0)
LOOK_OF_GRADE = {"normal": "normal", "rare": "normal", "epic": "normal", "legendary": "legendary", "relic": "legendary", "ancient": "legendary",
                 "primordial": "transcendent", "transcendent": "transcendent"}  # = ArtImportData.armorLookOfGrade
BODY_ROLES = ("", "_Steel", "_Grade")  # 본체(등급 메인 - 판금 · 큰 껍데기) · 나머지(_Leather 끈 · _Trim 테 · _Glow 빛) = 부착물(밝은 색)


def grade_colors():
    src = open(IVD, encoding="utf-8").read()
    out = {}
    for g in A.GRADES:
        m = re.search(r"\n\t\t" + g + r" = \{(.*?)\n\t\t\},", src, re.S)
        body = m.group(1) if m else ""

        def rgb(key):
            k = re.search(r"\b" + key + r" = Color3\.fromRGB\((\d+), (\d+), (\d+)\)", body)
            return tuple(int(x) for x in k.groups()) if k else None
        out[g] = {"main": rgb("color"), "light": rgb("light")}
    return out


def paint(objs, colors, weapon=False):
    main, light = colors["main"], colors["light"] or colors["main"]
    if weapon:  # 무기: 가장 큰 조각(칼날 · 활 몸 · 지팡이 머리) = 본체 · 나머지 = 부착물
        vols = {o: o.dimensions.x * o.dimensions.y * o.dimensions.z for o in objs}
        body = max(vols, key=vols.get)
        for o in objs:
            o.active_material = A.material("v3icon_%s_%s" % (o.name, "main" if o is body else "light"), main if o is body else light)
        return
    for o in objs:
        role = re.sub(r"^[A-Za-z]+(_[LR])?", "", o.name.split(".")[0])
        is_body = role in BODY_ROLES
        o.active_material = A.material("v3icon_%s_%s" % (o.name, "main" if is_body else "light"), main if is_body else light)


def style(scene):
    sh = scene.display.shading
    sh.light = "MATCAP"
    sh.studio_light = "toon_light.exr"
    sh.color_type = "MATERIAL"
    sh.show_specular_highlight = True
    sh.show_shadows = True
    sh.shadow_intensity = 0.3
    sh.show_cavity = True
    sh.cavity_type = "BOTH"
    sh.cavity_ridge_factor = 1.2
    sh.cavity_valley_factor = 0.8
    scene.display.light_direction = (-0.55, 0.45, 0.70)
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"


def render(objs, path, yaw, pitch):
    scene = A.setup_render("game", (RES, RES))
    style(scene)
    for o in scene.objects:
        if o.type == "MESH" and o not in objs:
            o.hide_render = True
    lo, hi = A.bbox_world(objs)
    cam = A.camera()
    cam.data.ortho_scale = (hi - lo).length * 1.05  # 넉넉히(맞춤은 후처리가 알파 경계로)
    cam.data.clip_end = 500
    A.aim(cam, (lo + hi) / 2, yaw, pitch)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def item(kind, cls, grade, out, colors):
    A.reset()
    if kind == "weapon":
        _, objs = W.build(cls, grade)
        paint(objs, colors[grade], weapon=True)
        e = A.stand(objs)
        rot = W.DISPLAY_ROT[cls]
        from mathutils import Matrix
        R = (Matrix.Rotation(math.radians(WEAPON_ROLL), 3, "Y") @ Matrix.Rotation(math.radians(WEAPON_TILT[0]), 3, "X") @ Matrix.Rotation(math.radians(WEAPON_TILT[1]), 3, "Z")
             @ Matrix.Rotation(math.radians(rot[2]), 3, "Z") @ Matrix.Rotation(math.radians(rot[1]), 3, "Y") @ Matrix.Rotation(math.radians(rot[0]), 3, "X"))
        e.rotation_euler = R.to_euler()
        render(objs, os.path.join(out, "weapon_%s_%s.png" % (cls, grade)), 0.0, 0.0)
        A.unstand(objs, e)
        return
    _, objs, _ = AC.build(cls, kind, LOOK_OF_GRADE[grade])
    keep = ONLY_RIGHT.get(kind)
    if keep:
        for o in list(objs):
            if not o.name.split(".")[0].startswith(keep):
                bpy.data.objects.remove(o)
                objs.remove(o)
    paint(objs, colors[grade])
    yaw, pitch = VIEW[kind]
    render(objs, os.path.join(out, "%s_%s_%s.png" % (kind, cls, grade)), yaw, pitch)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    items, out = [], OUT
    for i in range(0, len(argv) - 1, 2):
        if argv[i] == "--items":
            items = [tuple(s.split(":")) for s in argv[i + 1].split(",") if s]
        elif argv[i] == "--out":
            out = os.path.abspath(argv[i + 1])
    os.makedirs(out, exist_ok=True)
    colors = grade_colors()
    for kind, cls, grade in items:
        item(kind, cls, grade, out, colors)
        print("[icons_v3]", kind, cls, grade)
    print("[icons_v3] 끝 %d" % len(items))


if __name__ == "__main__":
    main()
