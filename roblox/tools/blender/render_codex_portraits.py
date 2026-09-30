# -*- coding: utf-8 -*-
# QUEUE-ALL3 §1 도감 초상화(docs/design/v2/10-ingame-feedback-1001.md §1): 모든 도감 칸에 그림.
#   만드는 것(256 × 256 · 투명 배경 · 정면 약간 위 · 게임 느낌 = Workbench 스튜디오 조명 + 오목 음영 + 뒤집은 껍데기 외곽선) → roblox/art/icons/codex/
#     monster_<종 id>.png   = 사냥 구역 종(WorldMapData.zones[].hunt - 12) · make_monsters.build 그대로(색 = 리그 색)
#     boss_<보스 id>.png    = 구역 보스(WorldMapData.zones[].bossId - 6) · make_boss.build(외곽선 = 렌더 껍데기)
#     pet_<종>_<부화 등급>.png = EggData 풀 24 × hatchGrades 4 = 96. 게임과 같은 규칙: 몸 = PetData.bodyOf · 외형 = ArtImportData.petLookOfGrade ·
#                             base = 구역 알 색(BossData gate.color) · accent = base × EggData.look.patternDarken · 영웅 = 희귀 외형 + 구역 색 빛(2D 후광)
#     class_<직업>.png      = 기준 체형(make_armor_wear.REF) + 방어구 v3 일반 외형 3부위(석조 평원 미리보기 색) + 일반 무기
#     armor3_<부위>_<직업>_<외형>.png = 방어구 v3 36(부위 3 × 직업 4 × 외형 3) - 중립 밝은 회색(세트 색 = UI가 ImageColor3로 곱한다)
#   장비 칸(구역 × 등급 × 부위)은 기존 roblox/art/icons/armor/<부위>_<구역>_<등급>.png가 이미 덮는다(재렌더 안 함 - _map.json에 연결만).
#   _map.json = 도감 칸 id(CodexRules.build) → PNG 경로. 목록 · 색은 data/*.lua를 읽어서 쓴다(수치 복사 없음).
# 실행: bash roblox/tools/blender/bl.sh roblox/tools/blender/render_codex_portraits.py [--only monster,boss,pet,class,armor3] [--shade 0.5]
#   Blender가 원본(512)을 임시 폴더에 찍고 끝에 시스템 python으로 같은 파일을 --post로 불러 256 맞춤 · 후광 · _map.json · 대조표를 만든다.
#   python render_codex_portraits.py --post  (후처리만 다시)
import json
import math
import os
import re
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))  # roblox/
REPO = os.path.normpath(os.path.join(ROOT, ".."))
DATA = os.path.join(ROOT, "src", "shared", "data")
OUT = os.path.join(ROOT, "art", "icons", "codex")
RAW = os.path.join(tempfile.gettempdir(), "codex_portraits_raw")
SHEET_DIR = os.path.join(REPO, "Claude outputs", "QUEUE-ALL3", "codex")
RES = 512
SIZE = 256
FILL = 0.8
YAW, PITCH = 18.0, 20.0  # 정면에서 살짝 옆 · 위에서 20° 내려다봄
SHADE = 0.5  # 스튜디오 음영을 평면색에 입히는 세기(0 = 평면 · 1 = 스튜디오 그대로)
HULL_REL = 0.014  # 외곽선 두께 = 물체 최대 크기 × 이 값
CATS = ["monster", "boss", "pet", "class", "armor3"]


# ────────────────────────── 데이터(Lua 원문에서 읽기) ──────────────────────────
def lua(name):
    with open(os.path.join(DATA, name), encoding="utf-8") as f:
        return f.read()


def strs(s):
    return re.findall(r'"(\w+)"', s)


def block(text, head):
    """head = { ... } 의 중괄호 안쪽(짝 맞춤)"""
    i = text.index(head)
    j = text.index("{", i)
    depth = 0
    for k in range(j, len(text)):
        depth += {"{": 1, "}": -1}.get(text[k], 0)
        if depth == 0:
            return text[j + 1:k]
    raise ValueError(head)


def load_data():
    d = {}
    zones = []
    for line in lua("WorldMapData.lua").splitlines():
        m = re.search(r'key = "(tier\d)", tierIndex', line)
        if m and "hunt" in line:
            zones.append(dict(key=m.group(1), species=re.findall(r'species = "(\w+)"', line), boss=re.search(r'bossId = "(\w+)"', line).group(1)))
    d["zones"] = zones
    d["gateColor"] = {z: tuple(int(v) for v in c) for z, *c in re.findall(r'gate = \{ zone = "(tier\d)", color = \{ (\d+), (\d+), (\d+) \}', lua("BossData.lua"))}
    egg = lua("EggData.lua")
    d["pool"] = {z: strs(p) for z, p in re.findall(r'(tier\d) = \{ name = "[^"]*", pool = \{([^}]*)\}', egg)}
    d["hatchGrades"] = strs(block(egg, "hatchGrades ="))
    d["patternDarken"] = float(re.search(r"patternDarken = ([\d.]+)", egg).group(1))
    d["bodyOf"] = dict(re.findall(r'(\w+) = "(dog|cat|dragon)"', block(lua("PetData.lua"), "bodyOf =")))
    art = lua("ArtImportData.lua")
    d["petLook"] = dict(re.findall(r'(\w+) = "(\w+)"', block(art, "petLookOfGrade =")))
    d["armorLook"] = dict(re.findall(r'(\w+) = "(\w+)"', block(art, "armorLookOfGrade =")))
    d["classes"] = strs(block(lua("ClassData.lua"), "order ="))
    d["gradeOrder"] = strs(block(lua("ArmorData.lua"), "gradeOrder ="))
    codex = lua("CodexData.lua")
    d["codexArmorGrades"] = strs(block(codex, "grades ="))
    d["monsterSteps"] = re.findall(r'\{ id = "(\w+)", label', block(codex, "C.monster ="))
    d["bossSteps"] = [int(x) for x in re.findall(r"\d+", block(codex, "C.boss =").split("}")[0])]
    d["classGrades"] = int(re.search(r"C\.class = \{ grades = (\d+)", codex).group(1))
    return d


# ────────────────────────── Blender 쪽(렌더) ──────────────────────────
def blender_main(opt):
    import bpy
    sys.path.insert(0, HERE)
    import artlib as A
    import make_monsters as MM
    import make_boss as MB
    import make_pets as MP
    import make_weapons as W
    import make_armor_wear as AW
    import make_armor_class as AC

    D = load_data()
    os.makedirs(RAW, exist_ok=True)
    done = []

    def lin(rgb):
        c = [A.srgb_to_linear(v) for v in rgb]
        return (c[0], c[1], c[2], 1.0)

    def recolor(o, rgb):
        for m in o.data.materials[:1]:
            m.diffuse_color = lin(rgb)

    def setup(light):
        scene = bpy.context.scene
        scene.render.engine = "BLENDER_WORKBENCH"
        scene.render.resolution_x = scene.render.resolution_y = RES
        scene.render.film_transparent = True
        scene.render.image_settings.file_format = "PNG"
        scene.render.image_settings.color_mode = "RGBA"
        scene.display_settings.display_device = "sRGB"
        scene.view_settings.view_transform = "Standard"
        scene.display.render_aa = "16"
        sh = scene.display.shading
        sh.color_type = "MATERIAL"
        sh.show_backface_culling = True  # 껍데기 안쪽 면만(외곽선)
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
            sh.studiolight_rotate_z = math.radians(-30)  # 빛 = 앞 왼쪽 위(키) - 반대쪽은 스튜디오 조명의 채움 · 테두리
        return scene

    def shoot(objs, name, yaw=YAW, pitch=PITCH):
        scene = setup("flat")
        for o in scene.objects:
            if o.type == "MESH":
                o.hide_render = o not in objs
        lo, hi = A.bbox_world(objs)
        size = max((hi - lo).x, (hi - lo).y, (hi - lo).z)
        for o in objs:
            if not o.name.endswith("_Outline"):
                A.add_hull(o, size * HULL_REL)
        cam = A.camera()
        cam.data.ortho_scale = (hi - lo).length * 1.1  # 후처리가 알파 경계로 잘라 80%에 맞춘다
        cam.data.clip_end = size * 20 + 100
        A.aim(cam, (lo + hi) / 2, yaw, pitch, dist=size * 5 + 20)
        # 두 장: 평면 조명(게임 색 그대로 · 기존 아이콘과 같은 밝기) + 스튜디오 조명(3방향 음영) → 후처리가 음영만 SHADE만큼 입힌다(Workbench는 노출 설정을 무시해 스튜디오만 쓰면 어둡다)
        for light, suffix in (("flat", ""), ("studio", "__shade")):
            setup(light)
            scene.render.filepath = os.path.join(RAW, name + suffix + ".png")
            bpy.ops.render.render(write_still=True)
        A.remove_hulls(objs)
        done.append(name)
        print("[codex]", name, len(objs))

    only = opt["only"]
    if "monster" in only:
        for z in D["zones"]:
            for sid in z["species"]:
                A.reset()
                _, _, objs = MM.build(sid)
                wide = sid in ("amethyst_bat", "blue_dragon")  # 날개가 옆으로 길어 정면이면 작게 나온다 → 더 돌려 날개를 줄여 보이게
                shoot(objs, "monster_" + sid, yaw=38 if wide else YAW, pitch=26 if wide else PITCH)
    if "boss" in only:
        for z in D["zones"]:
            A.reset()
            _, _, objs, _ = MB.build(z["boss"], hull=False)
            shoot(objs, "boss_" + z["boss"])
    if "pet" in only:
        # 원본 = 몸 3 × 외형 3 × 구역 6(종마다 몸이 같으면 같은 그림 - 게임도 같다) · 종 × 부화 등급 파일은 후처리가 복사
        roles = {b: {r[0]: r[3] for r in MP.RIGS[b]} for b in MP.RIGS}
        for body in ("dog", "cat", "dragon"):
            for look in ("normal", "good", "rare"):
                for z in D["zones"]:
                    A.reset()
                    _, objs = MP.build(body, look)
                    base = D["gateColor"][z["key"]]
                    for o in objs:
                        role = roles[body].get(o.name.split(".")[0])
                        if role == "base":
                            recolor(o, base)
                        elif role == "accent":
                            recolor(o, A.mul(base, D["patternDarken"]))
                    shoot(objs, "petraw_%s_%s_%s" % (body, look, z["key"]), yaw=-28, pitch=18)  # 옆 모습이 조금 보이게(몸 · 꼬리)
    if "class" in only:
        C = A.C
        from mathutils import Vector
        for cls in D["classes"]:
            A.reset()
            col = A.new_collection("body_" + cls)
            objs = []
            for part, (c, s) in AW.REF.items():
                skin = part in ("Head", "LeftHand", "RightHand")
                objs.append(A.make_obj("B_" + part, A.box(*s, b=0.12 if part == "Head" else 0.06, center=c), (246, 208, 168) if skin else (96, 98, 116), col, mat_name="body_%s_%s" % (cls, part)))
            objs.append(A.make_obj("B_Eyes", A.merge(*[A.box(0.14, 0.26, 0.04, center=(x, 1.66, -0.61)) for x in (-0.24, 0.24)]), (30, 27, 46), col, mat_name="body_%s_eyes" % cls))
            objs.append(A.make_obj("B_Hair", A.box(1.28, 0.34, 1.28, b=0.1, center=(0, 2.1, 0.03)), (92, 62, 44), col, mat_name="body_%s_hair" % cls))
            for slot in AC.SLOTS:
                _, aobjs, _ = AC.build(cls, slot, "normal")
                objs += aobjs
            hands = {"R": Vector(C @ Vector((1.5, -1.37, 0))), "L": Vector(C @ Vector((-1.5, -1.37, 0)))}
            # 무기: 표시 회전(긴 축 = 위) 후 손 옆에 세움. 활 = 왼손 · 쌍검 = 양손 · 나머지 = 오른손
            spots = {"greatsword": [("R", (0.75, 0.5, 0.2))], "dualblade": [("R", (0.7, 0.5, 0.1)), ("L", (-0.7, 0.5, 0.1))],
                     "bow": [("L", (-0.8, 0.5, 1.3))], "healer": [("R", (0.75, 0.5, -0.4))]}[cls]
            for hand, off in spots:
                _, wobjs = W.build(cls, "normal")
                e = A.stand(wobjs, "W_" + hand)
                e.rotation_euler = tuple(math.radians(a) for a in W.DISPLAY_ROT[cls])
                e.location = hands[hand] + Vector(off)
                objs += wobjs
            shoot(objs, "class_" + cls, yaw=22, pitch=12)
    if "armor3" in only:
        from mathutils import Matrix
        ICON_TILT = {"armor": -10.0, "gloves": -20.0, "shoes": -12.0}
        NEUTRAL = {"": (236, 236, 240), "Trim": (200, 202, 210), "Grade": (218, 218, 226), "Steel": (186, 190, 200), "Leather": (150, 142, 136), "Glow": (255, 244, 214)}
        for cls in AC.CLASSES:
            for slot in AC.SLOTS:
                for look in AC.LOOKS:
                    A.reset()
                    _, objs, _ = AC.build(cls, slot, look)
                    if slot == "gloves":  # 장갑 = 두 짝을 가운데로 모은다(손 간격 3 stud → 약 1.3 - 한 짝만이면 상자로 읽혔다)
                        for o in objs:
                            o.location.x -= 0.85 if o.location.x > 0 else -0.85
                    for o in objs:
                        tail = o.name.split(".")[0].split("_")[-1]
                        recolor(o, NEUTRAL.get(tail, NEUTRAL[""]))
                    # 기존 방어구 아이콘(make_armor_wear --icons)과 같은 자세: 물체를 X 기울임 · Z 돌림 후 정면 카메라 · 장갑 팔찌 0.72배(주먹이 읽히게)
                    for o in objs:
                        if o.name.startswith("Bracer"):
                            o.scale = (0.72, 0.72, 0.72)
                    if slot == "armor":
                        e = A.stand(objs)
                        e.rotation_euler = (Matrix.Rotation(math.radians(ICON_TILT[slot]), 3, "X") @ Matrix.Rotation(math.radians(AW.ICON_VIEW[slot][1]), 3, "Z")).to_euler()
                        shoot(objs, "armor3_%s_%s_%s" % (slot, cls, look), yaw=0, pitch=0)
                    else:  # 장갑 · 신발 = 한 켤레를 정면 약간 옆 · 위에서
                        shoot(objs, "armor3_%s_%s_%s" % (slot, cls, look), yaw=28, pitch=18)
    print("[codex] 원본 %d장 · %s" % (len(done), RAW))


# ────────────────────────── 후처리(시스템 python + Pillow) ──────────────────────────
def fit(im):
    from PIL import Image
    a = im.split()[3].point(lambda v: 255 if v > 8 else 0)
    box = a.getbbox()
    if not box:
        return None
    im = im.crop(box)
    k = SIZE / max(im.size[0] / 0.92, im.size[1] / FILL)  # 높이 = 80% · 날개처럼 넓은 것은 폭 92%까지
    im = im.resize((max(1, round(im.size[0] * k)), max(1, round(im.size[1] * k))), Image.LANCZOS)
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    out.paste(im, ((SIZE - im.size[0]) // 2, (SIZE - im.size[1]) // 2), im)
    return out


def shade(flat, studio, k):
    """평면색 × (스튜디오 ÷ 평면)^k - 색은 게임 그대로 두고 밝고 어두운 면만 입힌다(3톤 느낌)"""
    import numpy as np
    from PIL import Image
    f = np.asarray(flat).astype(np.float32)
    s = np.asarray(studio).astype(np.float32)
    lf = f[..., :3].mean(axis=2, keepdims=True)
    ls = s[..., :3].mean(axis=2, keepdims=True)
    ratio = (ls + 4) / (lf + 4)
    opaque = f[..., 3] > 128
    if opaque.any():  # 스튜디오 전체 밝기(평면의 약 55%)는 빼고 면마다 차이만 남긴다 - 가장 밝은 쪽(상위 15%) = 평면색 그대로
        ratio = ratio / np.percentile(ratio[..., 0][opaque], 85)
    ratio = np.clip(ratio, 0.2, 1.6) ** k
    out = f.copy()
    out[..., :3] = np.clip(f[..., :3] * ratio, 0, 255)
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def glow(im, rgb):
    """영웅 펫 = 구역 색 후광(게임 = PointLight) - 그림 뒤에 번진 테두리"""
    from PIL import Image, ImageFilter
    a = im.split()[3].filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(9))
    halo = Image.new("RGBA", im.size, rgb + (0,))
    halo.putalpha(a.point(lambda v: int(v * 0.85)))
    halo.alpha_composite(im)
    return halo


def check(im):
    """빈 그림 · 검은 그림 판정: 불투명 비율 · 불투명 부분 평균 밝기"""
    px = [p for p in im.convert("RGBA").get_flattened_data() if p[3] > 128] if hasattr(im, "get_flattened_data") else [p for p in im.getdata() if p[3] > 128]
    cover = len(px) / (SIZE * SIZE)
    lum = sum(0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2] for p in px) / max(1, len(px))
    return cover, lum


def post(strength=SHADE):
    from PIL import Image, ImageDraw
    D = load_data()
    os.makedirs(OUT, exist_ok=True)
    rel = lambda p: os.path.relpath(p, REPO).replace("\\", "/")
    made, bad = {}, []

    def emit(raw_name, out_name, halo=None):
        src = os.path.join(RAW, raw_name + ".png")
        if not os.path.exists(src):
            bad.append((out_name, "원본 없음"))
            return
        im = Image.open(src).convert("RGBA")
        sh = src[:-4] + "__shade.png"
        if os.path.exists(sh):
            im = shade(im, Image.open(sh).convert("RGBA"), strength)
        im = fit(im)
        if im is None:
            bad.append((out_name, "빈 그림"))
            return
        if halo:
            im = glow(im, halo)
        cover, lum = check(im)
        if cover < 0.08 or lum < 35:
            bad.append((out_name, "덮음 %.2f · 밝기 %.0f" % (cover, lum)))
        path = os.path.join(OUT, out_name + ".png")
        im.save(path)
        made[out_name] = path

    for z in D["zones"]:
        for sid in z["species"]:
            emit("monster_" + sid, "monster_" + sid)
        emit("boss_" + z["boss"], "boss_" + z["boss"])
    for z in D["zones"]:
        for sp in D["pool"][z["key"]]:
            for hg in D["hatchGrades"]:
                look = D["petLook"][hg]
                emit("petraw_%s_%s_%s" % (D["bodyOf"][sp], look, z["key"]), "pet_%s_%s" % (sp, hg), halo=D["gateColor"][z["key"]] if hg == "epic" else None)
    for cls in D["classes"]:
        emit("class_" + cls, "class_" + cls)
    for slot in ("armor", "gloves", "shoes"):
        for cls in D["classes"]:
            for look in ("normal", "legendary", "transcendent"):
                n = "armor3_%s_%s_%s" % (slot, cls, look)
                emit(n, n)

    # 도감 칸 id(CodexRules.build) → 그림
    cells, missing = {}, []

    def link(cid, path):
        if os.path.exists(path):
            cells[cid] = rel(path)
        else:
            missing.append(cid)
    icons = os.path.join(ROOT, "art", "icons")
    for z in D["zones"]:
        for g in D["codexArmorGrades"]:
            for p in ("armor", "gloves", "shoes"):
                link("armor:%s:%s:%s" % (z["key"], g, p), os.path.join(icons, "armor", "%s_%s_%s.png" % (p, z["key"], g)))
        link("prim:" + z["key"], os.path.join(icons, "armor", "armor_%s_primordial.png" % z["key"]))
        for sp in D["pool"][z["key"]]:
            for hg in D["hatchGrades"]:
                link("pet:%s:%s" % (sp, hg), os.path.join(OUT, "pet_%s_%s.png" % (sp, hg)))
        for sid in z["species"]:
            for st in D["monsterSteps"]:
                link("mon:%s:%s" % (sid, st), os.path.join(OUT, "monster_%s.png" % sid))
        for n in D["bossSteps"]:
            link("boss:%s:%d" % (z["boss"], n), os.path.join(OUT, "boss_%s.png" % z["boss"]))
    weapon = {}
    for cls in D["classes"]:
        for g in range(D["classGrades"]):
            cid = "cls:%s:%d" % (cls, g)
            link(cid, os.path.join(OUT, "class_%s.png" % cls))
            wp = os.path.join(icons, "weapons", "%s_%s.png" % (cls, D["gradeOrder"][g]))
            if os.path.exists(wp):
                weapon[cid] = rel(wp)
            else:
                missing.append(cid + "(무기)")
    armor3 = {k[len("armor3_"):]: rel(v) for k, v in made.items() if k.startswith("armor3_")}
    data = {
        "version": "QUEUE-ALL3",
        "script": "roblox/tools/blender/render_codex_portraits.py",
        "cells": cells,
        "classWeapon": weapon,
        "armor3": armor3,
        "armor3LookOfGrade": D["armorLook"],
        "note": {
            "armor": "cells = 기존 구역 × 등급 아이콘(icons/armor). 방어구 v3 직업 외형 = armor3[\"<부위>_<직업>_<armor3LookOfGrade[등급]>\"] - 중립 밝은 회색이라 UI가 ImageColor3 = 세트 주색(ArtImportData.armorSetColors.main)으로 곱한다",
            "pet": "게임과 같은 색(몸 = PetData.bodyOf · 외형 = petLookOfGrade · 구역 알 색) - 영웅 = 희귀 외형 + 구역 색 후광",
            "unknown": "못 만난 칸 = 같은 그림을 ImageColor3 검정(0,0,0)으로 실루엣 + ?",
            "nest": "탐험(둥지) 칸 = 게임 안 촬영 사진(이 스크립트 범위 밖)",
        },
    }
    with open(os.path.join(OUT, "_map.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)

    # 대조표(체크 무늬 = 투명 확인) - 전체 + 분류별
    os.makedirs(SHEET_DIR, exist_ok=True)

    def sheet(names, path, cell=160, cols=10):
        rows = (len(names) + cols - 1) // cols
        S = Image.new("RGB", (cols * cell, rows * (cell + 16)), (255, 255, 255))
        dr = ImageDraw.Draw(S)
        tile = Image.new("RGB", (cell, cell), (205, 205, 210))
        td = ImageDraw.Draw(tile)
        for y in range(0, cell, 16):
            for x in range(0, cell, 16):
                if (x // 16 + y // 16) % 2:
                    td.rectangle([x, y, x + 15, y + 15], fill=(235, 235, 240))
        for i, n in enumerate(names):
            x, y = (i % cols) * cell, (i // cols) * (cell + 16)
            S.paste(tile, (x, y))
            im = Image.open(made[n]).resize((cell, cell), Image.LANCZOS)
            S.paste(im, (x, y), im)
            dr.text((x + 2, y + cell + 2), n.replace("armor3_", "").replace("monster_", "").replace("boss_", "B:")[:26], fill=(20, 20, 30))
        S.save(path)
    order = list(made)
    sheet(order, os.path.join(SHEET_DIR, "portraits_sheet.png"), cell=112, cols=14)
    for cat in ("monster", "boss", "pet", "class", "armor3"):
        names = [n for n in order if n.startswith(cat + "_")]
        if names:
            sheet(names, os.path.join(SHEET_DIR, "sheet_%s.png" % cat), cols=12 if cat == "pet" else 9)
    counts = {c: sum(1 for n in made if n.startswith(c + "_")) for c in CATS}
    print("[codex post] 만든 그림", counts, "· 칸 연결", len(cells), "· 무기", len(weapon))
    print("[codex post] 문제", bad or "없음", "· 빠진 칸", missing or "없음")
    return bad, missing


def parse():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    opt = {"only": CATS, "shade": SHADE, "post": False}
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--only":
            opt["only"] = argv[i + 1].split(","); i += 1
        elif a == "--shade":
            opt["shade"] = float(argv[i + 1]); i += 1
        elif a == "--post":
            opt["post"] = True
        i += 1
    return opt


if __name__ == "__main__":
    t0 = time.time()
    opt = parse()
    try:
        import bpy  # noqa: F401
        in_blender = True
    except ImportError:
        in_blender = False
    if in_blender:
        blender_main(opt)
        print("[codex] 렌더 %.1f초" % (time.time() - t0))
        subprocess.run(["python", os.path.abspath(__file__), "--post", "--shade", str(opt["shade"])], check=False, env=dict(os.environ, PYTHONIOENCODING="utf-8"))
    else:
        post(opt["shade"])
        print("[codex post] %.1f초" % (time.time() - t0))
