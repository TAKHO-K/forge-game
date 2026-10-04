# -*- coding: utf-8 -*-
# QUEUE-ALL9E1 LOOK3: make_gear_look3.py --bake 원본(_raw_<키>_color · _raw_<키>_mask) → 게임 지도. 시스템 python(PIL).
#   <키>.png = 색 지도 RGBA: 천(마스크 R) = 알파 낮음 + 검정(AlphaMode Overlay → 파트 Color = 세트 색1이 비치고 틈 음영만 얹힘) · 나머지 알파 1
#   <키>_e.png = 발광 마스크(마스크 G · 회색 · 색 지도의 절반 해상도) - 발광 구역이 없는 키(일반 등)는 만들지 않는다
# 사용: python roblox/tools/blender/look3_maps.py
import glob
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
MAPS = os.path.normpath(os.path.join(HERE, "..", "..", "art", "textures", "gear_v3", "look3"))


def main():
    n = e = 0
    for raw in sorted(glob.glob(os.path.join(MAPS, "_raw_*_color.png"))):
        key = os.path.basename(raw)[len("_raw_"):-len("_color.png")]
        col = Image.open(raw).convert("RGB")
        mask = Image.open(os.path.join(MAPS, "_raw_%s_mask.png" % key)).convert("RGB")
        cr, cg, cb = col.split()
        mr, mg, _ = mask.split()
        # 천 알파 = (1 − 음영) × 0.9(틈 그림자만) · 천 아닌 곳 = 1 → 섞임 테두리는 마스크 비율대로
        shade = Image.merge("RGB", (cr, cg, cb)).convert("L")
        cloth_a = shade.point(lambda v: int(max(0, min(255, (255 - v) * 0.9))))
        alpha = Image.composite(cloth_a, Image.new("L", col.size, 255), mr)
        black = Image.new("RGB", col.size, (0, 0, 0))
        rgb = Image.composite(black, col, mr)
        out = rgb.copy()
        out.putalpha(alpha)
        out.save(os.path.join(MAPS, "%s.png" % key), optimize=True)
        n += 1
        if mg.getextrema()[1] > 8:
            mg.resize((col.size[0] // 2, col.size[1] // 2), Image.LANCZOS).save(os.path.join(MAPS, "%s_e.png" % key), optimize=True)
            e += 1
    print("look3_maps: 색 %d · 발광 %d" % (n, e))


if __name__ == "__main__":
    main()
