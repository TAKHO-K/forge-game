# -*- coding: utf-8 -*-
# A2-N1 렌더 합치기(시스템 python + Pillow - Blender 밖). 격자 한 장 + 칸 이름 + 제목.
# 사용: python compose.py --out <png> --cols N [--title 글] [--cell 360] 이미지1::이름1 이미지2::이름2 ...
#   이름에 "|"를 넣으면 두 줄. 이미지가 없으면 빈 칸(회색).
import os
import sys
from PIL import Image, ImageDraw, ImageFont

FONT = "C:/Windows/Fonts/malgunbd.ttf" if os.path.exists("C:/Windows/Fonts/malgunbd.ttf") else "C:/Windows/Fonts/malgun.ttf"


def compose(out, items, cols=4, title="", cell=360):
    """items = [(이미지 경로, 이름), ...] - 명령줄 없이 다른 스크립트(sheets.py)에서 부를 때"""
    args = ["--out", out, "--cols", str(cols), "--title", title, "--cell", str(cell)] + ["%s::%s" % it for it in items]
    main(args)


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    out, cols, title, cell = None, 4, "", 360
    items = []
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--out":
            out = argv[i + 1]; i += 1
        elif a == "--cols":
            cols = int(argv[i + 1]); i += 1
        elif a == "--title":
            title = argv[i + 1]; i += 1
        elif a == "--cell":
            cell = int(argv[i + 1]); i += 1
        else:
            path, _, label = a.partition("::")
            items.append((path, label))
        i += 1
    rows = (len(items) + cols - 1) // cols
    lab_h = 54
    top = 60 if title else 10
    W = cols * cell + (cols + 1) * 8
    H = top + rows * (cell + lab_h + 8) + 8
    sheet = Image.new("RGB", (W, H), (40, 38, 52))
    d = ImageDraw.Draw(sheet)
    f_title = ImageFont.truetype(FONT, 30)
    f_lab = ImageFont.truetype(FONT, 17)
    if title:
        d.text((12, 12), title, fill=(255, 255, 255), font=f_title)
    for k, (path, label) in enumerate(items):
        r, c = divmod(k, cols)
        x = 8 + c * (cell + 8)
        y = top + r * (cell + lab_h + 8)
        if path and os.path.exists(path):
            im = Image.open(path).convert("RGB")
            im.thumbnail((cell, cell))
            bg = Image.new("RGB", (cell, cell), im.getpixel((2, 2)))
            bg.paste(im, ((cell - im.width) // 2, (cell - im.height) // 2))
            sheet.paste(bg, (x, y))
        else:
            d.rectangle((x, y, x + cell, y + cell), fill=(90, 90, 100))
        for li, line in enumerate(label.split("|")[:2]):
            d.text((x + 4, y + cell + 4 + li * 23), line, fill=(235, 235, 245), font=f_lab)
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    sheet.save(out)
    print("compose", out, sheet.size)


if __name__ == "__main__":
    main()
