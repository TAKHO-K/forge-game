# -*- coding: utf-8 -*-
"""QUEUE-ALL9E1 LOOK3 C: LOOK3 아이콘 후처리 + 옛 아이콘 비교 시트(시스템 python + Pillow).

사용: python roblox/tools/blender/icons_look3.py <make_icons_look3 원본 폴더>
  ① 원본 512 → roblox/art/icons/gear_v3_look3/<부위>_<직업>_<등급>.png(256 · icons_v3.post와 같은 맞춤 · 외곽선)
  ② 비교 시트 → docs/art/ref/compare/icons-look3-vs-current.png: 부위마다 [지금 게임 아이콘(icons/armor/<부위>_tier1_<등급>) 한 줄 + LOOK3 4직업 4줄] × 8등급(틀 ⑥ 씌움 · 석조 평원 배지)
  게임은 사용자 선택 전까지 옛 아이콘 그대로(이 폴더는 업로드 · ArtAssetIds 연결 안 함 - 옛 파일 · 에셋 삭제 금지).
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import icons_v3 as IV  # noqa: E402

ROOT = IV.ROOT
OUT = os.path.join(ROOT, "art", "icons", "gear_v3_look3")
OLD = os.path.join(ROOT, "art", "icons", "armor")
SHEET = os.path.join(IV.COMPARE, "icons-look3-vs-current.png")
GRADES = ["normal", "rare", "epic", "legendary", "relic", "ancient", "primordial", "transcendent"]
GRADE_KO = ["일반", "희귀", "영웅", "전설", "유물", "고대", "태초", "초월"]
CLASSES = ["greatsword", "dualblade", "bow", "healer"]
CLASS_KO = {"greatsword": "대검", "dualblade": "쌍검", "bow": "활", "healer": "치유사"}
SLOT_KO = {"armor": "갑옷", "gloves": "장갑", "shoes": "신발"}


def main():
    raw = sys.argv[1]
    os.makedirs(OUT, exist_ok=True)
    n = 0
    for f in sorted(os.listdir(raw)):
        if f.endswith(".png"):
            IV.post(os.path.join(raw, f), os.path.join(OUT, f))
            n += 1
    colors = IV.grade_colors()
    cell, label_w, head = 112, 150, 40
    rows = []
    for slot in ("armor", "gloves", "shoes"):
        rows.append(("지금 %s" % SLOT_KO[slot], [os.path.join(OLD, "%s_tier1_%s.png" % (slot, g)) for g in GRADES]))
        for cls in CLASSES:
            rows.append(("LOOK3 %s %s" % (CLASS_KO[cls], SLOT_KO[slot]), [os.path.join(OUT, "%s_%s_%s.png" % (slot, cls, g)) for g in GRADES]))
    W, H = label_w + cell * 8, head + cell * len(rows) + 8 * 3
    sheet = Image.new("RGBA", (W, H), (236, 238, 243, 255))
    d = ImageDraw.Draw(sheet)
    font = ImageFont.truetype(IV.FONT, 15)
    for i, g in enumerate(GRADE_KO):
        d.text((label_w + i * cell + cell // 2 - 14, 12), g, fill=(40, 40, 50), font=font)
    y = head
    for r, (label, paths) in enumerate(rows):
        if r and r % 5 == 0:
            y += 8
        d.text((8, y + cell // 2 - 9), label, fill=(30, 30, 40) if label.startswith("LOOK3") else (150, 60, 40), font=font)
        for i, p in enumerate(paths):
            sheet.alpha_composite(IV.framed(p, GRADES[i], "tier1", colors, size=cell - 6), (label_w + i * cell + 3, y + 3))
        y += cell
    sheet.convert("RGB").save(SHEET, optimize=True)
    print("icons_look3: 아이콘 %d → %s · 시트 %s" % (n, OUT, SHEET))


if __name__ == "__main__":
    main()
