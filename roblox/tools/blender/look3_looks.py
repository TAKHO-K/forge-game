# -*- coding: utf-8 -*-
# QUEUE-ALL9E1 LOOK3: 등급 색 지도 → SurfaceAppearance 템플릿 파일(Rojo). 시스템 python. (LOOK2 = gear_v3_looks.py와 같은 방식 - 게임 스크립트는 지도 속성을 못 쓴다)
#   입력 = roblox/art/asset-ids.json의 textures/gear_v3/look3/<키>.png(색 · 천 알파) · <키>_e.png(발광 마스크 - 있으면) 이미지 id(upload.py + --images)
#   출력 = roblox/src/shared/GearV3Look3.rbxmx(Folder) - 키마다 1개: AlphaMode Overlay(천 = 파트 색) · EmissiveMaskContent · EmissiveStrength
#   게임 = shared/GearV3.look3Surface가 복제(client/ArmorWearView).
# 사용: python roblox/tools/blender/look3_looks.py [추가 ids json(같은 모양 - 덮어 읽음)]
import json
import os
import sys
from xml.sax.saxutils import escape

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
IDS = os.path.join(ROOT, "art", "asset-ids.json")
OUT = os.path.join(ROOT, "src", "shared", "GearV3Look3.rbxmx")
PREFIX = "textures/gear_v3/look3/"
EMISSIVE_STRENGTH = 2.0  # 보석 · 균열 · 부유 빛 세기(마스크 0 ~ 1 × 이 값)


def main():
    ids = json.load(open(IDS, encoding="utf-8"))
    for extra in sys.argv[1:]:
        ids.update(json.load(open(extra, encoding="utf-8")))

    def image(path):
        row = ids.get(path)
        return row and row.get("imageId")

    keys = sorted(p[len(PREFIX):-4] for p in ids if p.startswith(PREFIX) and p.endswith(".png") and not p.endswith("_e.png"))
    body, missing = [], []
    for i, key in enumerate(keys, 1):
        color = image(PREFIX + key + ".png")
        if not color:
            missing.append(key)
            continue
        emis = image(PREFIX + key + "_e.png")
        props = '<string name="Name">%s</string><token name="AlphaMode">0</token><Content name="ColorMap"><url>rbxassetid://%d</url></Content>' % (escape(key), color)
        if emis:
            props += '<Content name="EmissiveMaskContent"><url>rbxassetid://%d</url></Content><float name="EmissiveStrength">%s</float>' % (emis, EMISSIVE_STRENGTH)
        body.append('<Item class="SurfaceAppearance" referent="RBX%d"><Properties>%s</Properties></Item>' % (i, props))
    xml = '<roblox version="4"><Item class="Folder" referent="RBX0"><Properties><string name="Name">GearV3Look3</string></Properties>%s</Item></roblox>\n' % "".join(body)
    open(OUT, "w", encoding="utf-8", newline="\n").write(xml)
    print("GearV3Look3: 템플릿 %d · 이미지 id 없음 %d %s" % (len(body), len(missing), missing[:5]))


if __name__ == "__main__":
    main()
