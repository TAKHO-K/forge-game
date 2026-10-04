# -*- coding: utf-8 -*-
# QUEUE-ALL9E1 LOOK3 C: 최종 3D(LOOK3 등급 메시 + 구운 색 지도)로 방어구 아이콘 96장(4직업 × 3부위 × 8등급) - 512 투명 PNG 원본.
#   각도 · 조명 = make_icons_v3(갑옷 정면 15° 위 · 장갑 오른손 45° · 신발 오른발 60° · 툰 매트캡 + 외곽 공동) · 후처리(256 · 80% 맞춤 · 외곽선) = icons_v3.post(icons_look3.py)
#   천(세트 색 자리) = 직업 바닥층 천 색(중립 - 세트 구분은 칸 배지) · 무기는 LOOK3 대상 아님(3D 무기 그대로 = 옛 아이콘 유지)
# 실행: bash bl.sh make_icons_look3.py --out <폴더> [--classes ..] [--grades ..]
import bpy  # noqa: F401
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import artlib as A  # noqa: E402
import make_gear_look3 as L3  # noqa: E402
import make_icons_v3 as IV  # noqa: E402

KEEP = {"armor": None, "gloves": ("Glove_R", "Bracer_R"), "shoes": ("Boot_R", "Greave_R")}
CLOTH = {"greatsword": (43, 53, 80), "dualblade": (43, 53, 80), "bow": (232, 220, 192), "healer": (232, 220, 192)}  # GearV3Data.look2.cloth(직업 바닥층 색)


def tint_cloth(key, rgb):
    img = bpy.data.images.get("%s_color" % key)
    mk = bpy.data.images.get("%s_mask" % key)
    px, m = list(img.pixels), list(mk.pixels)
    cc = [A.srgb_to_linear(v) for v in rgb]
    for i in range(0, len(px), 4):
        w = m[i]
        if w > 0.01:
            for k in range(3):
                px[i + k] = px[i + k] * (1 - w) + cc[k] * min(1.0, px[i + k] * 1.15) * w
    img.pixels[:] = px


def style(scene):
    IV.style(scene)
    scene.display.shading.color_type = "TEXTURE"


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = argv[argv.index("--out") + 1]
    classes = argv[argv.index("--classes") + 1].split(",") if "--classes" in argv else L3.CLASSES
    grades = argv[argv.index("--grades") + 1].split(",") if "--grades" in argv else L3.GRADES
    os.makedirs(out, exist_ok=True)
    L3.PAL = L3.palette_all()
    L3.MAPS = os.path.join(out, "_maps")  # 굽기 원본은 출력 폴더 아래(게임 지도 폴더를 건드리지 않음)
    n = 0
    for cls in classes:
        for slot in L3.SLOTS:
            for grade in grades:
                A.reset()
                key, col, objs, info = L3.build(cls, slot, grade)
                L3.bake(objs, key, L3.MAP_RES[slot], grade)
                tint_cloth(key, CLOTH[cls])
                keep = KEEP[slot]
                if keep:
                    for o in list(objs):
                        if o.name.split(".")[0] not in keep:
                            bpy.data.objects.remove(o)
                            objs.remove(o)
                scene = A.setup_render("game", (IV.RES, IV.RES))
                style(scene)
                for o in scene.objects:
                    if o.type == "MESH" and o not in objs:
                        o.hide_render = True
                lo, hi = A.bbox_world(objs)
                cam = A.camera()
                cam.data.ortho_scale = (hi - lo).length * 1.05
                cam.data.clip_end = 500
                yaw, pitch = IV.VIEW[slot]
                if slot != "armor":
                    pitch = 2.0  # LOOK3: 15° 위에서는 팔 · 다리 절단면 뚜껑이 아이콘의 절반을 차지 - 장갑 · 신발만 거의 수평
                A.aim(cam, (lo + hi) / 2, yaw, pitch)
                scene.render.filepath = os.path.join(out, "%s_%s_%s.png" % (slot, cls, grade))
                bpy.ops.render.render(write_still=True)
                n += 1
                print("[icons_look3]", slot, cls, grade)
    print("[icons_look3] 끝", n)


if __name__ == "__main__":
    main()
