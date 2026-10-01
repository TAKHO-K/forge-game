# -*- coding: utf-8 -*-
# QUEUE-ALL5 E 출시 아이콘 - Blender 원본 렌더(bpy). 기존 메시 빌더를 그대로 불러 투명 PNG 두 장씩(평면 조명 · 스튜디오 조명) 찍는다.
#   make_store_icons.py(Pillow)가 두 장을 합쳐 3톤 음영(render_codex_portraits.shade와 같은 방식)을 입히고 타일 · 배경에 얹는다.
#   찍는 것(파일 = <이름>.png · <이름>__shade.png):
#     hero        = 쌍검 캐릭터(render_codex_portraits "class" 몸 + make_armor_class 전설 외형 + make_weapons 쌍검 영웅) · 팔을 벌린 자세 - 게임 아이콘 A · B · C
#     slime       = 이끼 슬라임(make_monsters) - 게임 아이콘 A 곁
#     dragon_wing = 푸른 드래곤 날개 2장(make_monsters blue_dragon Wing_L · Wing_R · 색 = ArtV1CosmeticData.gliders.dragonWing.color) - glider_dragonWing
#     cloud_whale = 구름 고래(make_cosmetics.parts - 시즌 1 유료 줄 대표) - season_premium
#     pet         = 보통 강아지 펫(make_pets dog normal) - pickupRadius
#   리포의 FBX · 메타는 건드리지 않는다(내보내기 없음 · 렌더만).
# 실행: bash roblox/tools/blender/bl.sh roblox/tools/icons/store_renders_blender.py [--out 폴더](기본 = docs/release/icons/src)
import bpy
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
BL = os.path.normpath(os.path.join(HERE, "..", "blender"))
REPO = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, BL)
import artlib as A  # noqa: E402
import make_monsters as MM  # noqa: E402
import make_pets as MP  # noqa: E402
import make_weapons as W  # noqa: E402
import make_armor_wear as AW  # noqa: E402
import make_armor_class as AC  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

RES = 1024
HULL_REL = 0.012  # 외곽선 껍데기 두께 = 물체 최대 크기 × 이 값(도감 초상화 0.014 - 512 아이콘이라 조금 얇게)


def lin(rgb):
    c = [A.srgb_to_linear(v) for v in rgb]
    return (c[0], c[1], c[2], 1.0)


def recolor(o, rgb):
    for m in o.data.materials[:1]:
        m.diffuse_color = lin(rgb)


def setup(light, res):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = scene.render.resolution_y = res
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.display_settings.display_device = "sRGB"
    scene.view_settings.view_transform = "Standard"
    scene.display.render_aa = "16"
    sh = scene.display.shading
    sh.color_type = "MATERIAL"
    sh.show_backface_culling = True
    sh.show_shadows = False
    sh.show_specular_highlight = False
    sh.show_object_outline = False
    sh.show_cavity = True
    sh.cavity_type = "WORLD"
    sh.cavity_ridge_factor = 0.4
    sh.cavity_valley_factor = 1.0
    if light == "flat":
        sh.light = "FLAT"
    else:
        sh.light = "STUDIO"
        sh.studio_light = "Default"
        sh.studiolight_rotate_z = math.radians(-30)
    return scene


def shoot(objs, out, name, yaw, pitch, res=RES, pad=1.08):
    scene = setup("flat", res)
    for o in scene.objects:
        if o.type == "MESH":
            o.hide_render = o not in objs
    lo, hi = A.bbox_world(objs)
    size = max((hi - lo).x, (hi - lo).y, (hi - lo).z)
    for o in objs:
        A.add_hull(o, size * HULL_REL)
    cam = A.camera()
    cam.data.ortho_scale = (hi - lo).length * pad
    cam.data.clip_end = size * 20 + 100
    A.aim(cam, (lo + hi) / 2, yaw, pitch, dist=size * 5 + 20)
    for light, suffix in (("flat", ""), ("studio", "__shade")):
        setup(light, res)
        scene.render.filepath = os.path.join(out, name + suffix + ".png")
        bpy.ops.render.render(write_still=True)
    A.remove_hulls(objs)
    print("[store_renders]", name, len(objs))


def pivot_group(objs, pivot_roblox, rot_roblox_deg):
    """objs를 Roblox 좌표 pivot 둘레로 돌린다(팔 자세). rot = (x, y, z)도 - Roblox 축"""
    e = bpy.data.objects.new("Pivot", None)
    bpy.context.scene.collection.objects.link(e)
    e.location = A.C @ Vector(pivot_roblox)
    bpy.context.view_layer.update()
    for o in objs:
        mw = o.matrix_world.copy()
        o.parent = e
        o.matrix_parent_inverse = e.matrix_world.inverted()
        o.matrix_world = mw
    R = A.C @ A.rot(*rot_roblox_deg) @ A.CT  # Roblox 회전 → Blender 회전
    e.rotation_euler = R.to_euler()
    bpy.context.view_layer.update()
    return e


def hero():
    """쌍검 캐릭터 - 도감 직업 초상화(render_codex_portraits "class")와 같은 몸 + 전설 외형 + 영웅 쌍검 · 팔 벌린 전투 자세"""
    A.reset()
    col = A.new_collection("hero")
    objs, part_of = [], {}
    skin, pants, hair = (246, 208, 168), (70, 74, 104), (150, 88, 44)
    for part, (c, s) in AW.REF.items():
        is_skin = part in ("Head", "LeftHand", "RightHand")
        o = A.make_obj("B_" + part, A.box(*s, b=0.16 if part == "Head" else 0.06, center=c), skin if is_skin else pants, col, mat_name="hero_" + part)
        objs.append(o)
        part_of[o.name] = part
    # 얼굴: 큰 눈(어두운 세로 타원 + 흰 광택 점) · 작은 입
    eyes = A.merge(*[A.ellipsoid((0.11, 0.17, 0.05), n=10, rings=5, center=(x, 1.68, -0.6)) for x in (-0.24, 0.24)])
    shine = A.merge(*[A.ellipsoid((0.04, 0.05, 0.03), n=6, rings=3, center=(x + 0.04, 1.75, -0.645)) for x in (-0.24, 0.24)])
    mouth = A.box(0.22, 0.05, 0.04, center=(0, 1.36, -0.61))
    objs.append(A.make_obj("B_Eyes", eyes, A.OUTLINE, col, mat_name="hero_eyes"))
    objs.append(A.make_obj("B_Shine", shine, (255, 255, 255), col, mat_name="hero_shine"))
    objs.append(A.make_obj("B_Mouth", mouth, (150, 80, 70), col, mat_name="hero_mouth"))
    # 머리카락: 덮개 + 앞머리 뭉치(레퍼런스 캡처의 갈색 머리 느낌)
    tufts = [A.ellipsoid((0.72, 0.36, 0.72), n=12, rings=6, center=(0, 2.2, 0.05))]
    for x, y, z, r in ((-0.42, 2.02, -0.5, 0.3), (0.0, 2.08, -0.56, 0.32), (0.42, 2.02, -0.5, 0.3), (-0.66, 1.8, -0.1, 0.28), (0.66, 1.8, -0.1, 0.28),
                       (-0.6, 1.75, 0.35, 0.3), (0.6, 1.75, 0.35, 0.3), (0, 1.9, 0.6, 0.4)):
        tufts.append(A.ellipsoid((r, r * 0.9, r), n=8, rings=4, center=(x, y, z)))
    objs.append(A.make_obj("B_Hair", A.merge(*tufts), hair, col, mat_name="hero_hair"))
    for slot in AC.SLOTS:
        _, aobjs, info = AC.build("dualblade", slot, "legendary")
        for o in aobjs:
            part_of[o.name] = info[o.name]
        objs += aobjs
    # 팔 자세: 어깨 둘레로 바깥 · 앞으로
    arm_parts = {"R": ("RightUpperArm", "RightLowerArm", "RightHand"), "L": ("LeftUpperArm", "LeftLowerArm", "LeftHand")}
    for side, sx in (("R", 1), ("L", -1)):
        grp = [o for o in objs if part_of.get(o.name) in arm_parts[side]]
        hand = Vector((sx * 1.5, -1.37, 0))
        wobj = []
        _, wobjs = W.build("dualblade", "epic")
        e = A.stand(wobjs, "W_" + side)
        # 역수(거꾸로 쥠): 칼끝 아래 + 바깥으로 기울임 · 날 면이 카메라 쪽 · 손등 앞(레퍼런스 캡처 = 주먹 아래로 뻗은 쌍검)
        e.rotation_euler = (Matrix.Rotation(math.radians(sx * 22), 3, "Y") @ Matrix.Rotation(math.radians(90), 3, "X")).to_euler()
        e.location = A.C @ (hand + Vector((0.0, 0.05, -0.62)))
        bpy.context.view_layer.update()
        for o in wobjs:
            mw = o.matrix_world.copy()
            o.parent = None
            o.matrix_world = mw
        bpy.data.objects.remove(e)
        wobj = wobjs
        objs += wobj
        pivot_group(grp + wobj, (sx * 1.5, 0.95, 0), (32, 0, sx * 14))  # 앞으로 들고(+X 회전 = 손이 앞 −Z) 살짝 바깥
    return objs


def slime():
    A.reset()
    _, _, objs = MM.build("moss_slime")
    return objs


def dragon_wing():
    A.reset()
    _, _, objs = MM.build("blue_dragon")
    keep = [o for o in objs if o.name.split(".")[0] in ("Wing_L", "Wing_R")]
    for o in objs:
        if o not in keep:
            bpy.data.objects.remove(o)
    for o in keep:
        recolor(o, (70, 130, 205))
        o.scale = (1.0, 1.0, 1.6)  # 렌더 전용: 막 면을 위아래로 1.6배(정면에서 띠처럼 가늘어 타일 면적이 작았다 - 메시 · FBX는 그대로)
    return keep


def pet():
    """자동 줍기 패스: 보통 강아지 펫(make_pets 몸 틀 그대로 · 렌더 색)"""
    A.reset()
    _, objs = MP.build("dog", "normal")
    return objs


def cloud_whale():
    """make_cosmetics.py는 불러오면 main()이 FBX를 다시 내보낸다 → main 앞까지만 실행해 parts()만 쓴다"""
    A.reset()
    path = os.path.join(BL, "make_cosmetics.py")
    src = open(path, encoding="utf-8").read()
    ns = {"__file__": path, "__name__": "make_cosmetics_parts"}
    exec(compile(src[:src.index("\ndef main")], path, "exec"), ns)
    col = A.new_collection("cloud_whale")
    return [A.make_obj(n_, g, rgb, col, neon=neon, smooth=True, mat_name="cw_" + n_) for n_, g, rgb, neon in ns["parts"]()]


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = os.path.abspath(argv[argv.index("--out") + 1]) if "--out" in argv else os.path.join(REPO, "docs", "release", "icons", "src")
    os.makedirs(out, exist_ok=True)
    shoot(hero(), out, "hero", yaw=22, pitch=10, res=1536)
    shoot(slime(), out, "slime", yaw=-30, pitch=16)
    shoot(dragon_wing(), out, "dragon_wing", yaw=0, pitch=0, pad=1.5)
    shoot(cloud_whale(), out, "cloud_whale", yaw=-125, pitch=14)
    shoot(pet(), out, "pet", yaw=-28, pitch=18)
    print("[store_renders] 끝", out)


main()
