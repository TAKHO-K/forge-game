# -*- coding: utf-8 -*-
# QUEUE-ALL9E1 LOOK2 3번: 장비 v3 굽은 음영 지도 → SurfaceAppearance 템플릿 파일(Rojo) 생성. 시스템 python(Blender 밖).
#   입력 = roblox/art/asset-ids.json의 textures/gear_v3/maps/<키>.png 이미지 id(upload.py + --images로 기록) · 균일 금속/거칠기 지도(sa_metal_* · sa_rough_*)
#   출력 = roblox/src/shared/GearV3Looks.rbxmx(Folder) - 키마다 3개: <키>_metalHi(금속 1 · 거칠기 0.25) · <키>_metal(금속 1 · 0.5) · <키>_cloth(금속 0 · 0.85)
#   게임 = shared/GearV3.surfaceFor가 복제 → SurfaceAppearance.Color = 구역 색(틴트). 게임 스크립트는 지도 속성을 못 쓰므로 템플릿 파일로 둔다.
# 사용: python roblox/tools/blender/gear_v3_looks.py
import json
import os
from xml.sax.saxutils import escape

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
IDS = os.path.join(ROOT, "art", "asset-ids.json")
OUT = os.path.join(ROOT, "src", "shared", "GearV3Looks.rbxmx")
VARIANTS = {"metalHi": ("sa_metal_1", "sa_rough_25"), "metal": ("sa_metal_1", "sa_rough_50"), "cloth": ("sa_metal_0", "sa_rough_85")}


def main():
    ids = json.load(open(IDS, encoding="utf-8"))

    def image(path):
        row = ids.get(path)
        return row and row.get("imageId")

    flat = {k: image("textures/gear_v3/%s.png" % k) for k in ("sa_metal_0", "sa_metal_1", "sa_rough_25", "sa_rough_50", "sa_rough_85")}
    if not all(flat.values()):
        raise SystemExit("균일 지도 이미지 id 없음: %s" % [k for k, v in flat.items() if not v])
    keys = sorted(p[len("textures/gear_v3/maps/"):-4] for p in ids if p.startswith("textures/gear_v3/maps/") and p.endswith(".png") and image(p))
    ref = [0]

    def item(name, color, metal, rough):
        ref[0] += 1
        return ('<Item class="SurfaceAppearance" referent="RBX%d"><Properties><string name="Name">%s</string><token name="AlphaMode">0</token>'
                '<Content name="ColorMap"><url>rbxassetid://%d</url></Content><Content name="MetalnessMap"><url>rbxassetid://%d</url></Content>'
                '<Content name="RoughnessMap"><url>rbxassetid://%d</url></Content></Properties></Item>') % (ref[0], escape(name), color, metal, rough)

    body = []
    for key in keys:
        color = image("textures/gear_v3/maps/%s.png" % key)
        for var, (m, r) in VARIANTS.items():
            body.append(item("%s_%s" % (key, var), color, flat[m], flat[r]))
    xml = ('<roblox version="4"><Item class="Folder" referent="RBX0"><Properties><string name="Name">GearV3Looks</string></Properties>%s</Item></roblox>\n') % "".join(body)
    open(OUT, "w", encoding="utf-8", newline="\n").write(xml)
    print("GearV3Looks: 키 %d · 템플릿 %d → %s" % (len(keys), len(body), OUT))


if __name__ == "__main__":
    main()
