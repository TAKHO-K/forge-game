# -*- coding: utf-8 -*-
# QUEUE-ALL9C 2-3 메인 메뉴 안전 영역 안내 그림(시스템 python + Pillow - compose.py와 같은 도구).
# 키 아트를 실제 화면처럼 잘라(꽉 채움 · 가로 가운데 · 세로 focusY) PC 16:9 · 폰 19.5:9 두 칸에 그리고,
# 메뉴 묶음 · 로고 자리(왼쪽 menuZone 35% · 여백 menuMargin 4%)와 인물 · 무기 · 빛을 두는 자리(오른쪽 65%)를 표시한다.
# 사용: python roblox/tools/blender/menu_safe_zone.py [키 아트 경로] → docs/art/ref/menu-safe-zone.png
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))  # 저장소
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "roblox", "art", "ui", "menu_keyart_v1.png")
OUT = os.path.join(ROOT, "docs", "art", "ref", "menu-safe-zone.png")
FONT = "C:/Windows/Fonts/malgunbd.ttf"
FOCUS_Y = 0.55  # MenuBootData.focusY
MENU_ZONE, MENU_MARGIN, PANEL_W = 0.35, 0.04, 320  # MainMenuData
SCREENS = [("PC 16:9 (1920 × 1080)", 1920, 1080), ("폰 19.5:9 (844 × 390)", 844, 390)]
CELL_W = 960


def cover(art, w, h):
    aw, ah = art.size
    scale = max(w / aw, h / ah)
    sw, sh = round(aw * scale), round(ah * scale)
    big = art.resize((sw, sh), Image.LANCZOS)
    x = (sw - w) // 2
    y = round(FOCUS_Y * sh - FOCUS_Y * h)
    return big.crop((x, y, x + w, y + h))


def main():
    art = Image.open(SRC).convert("RGB")
    cells = []
    for title, w, h in SCREENS:
        shot = cover(art, w, h).convert("RGBA")
        layer = Image.new("RGBA", shot.size, (0, 0, 0, 0))  # 반투명 표시는 따로 그려 합성(직접 칠하면 덮어써진다)
        draw = ImageDraw.Draw(layer)
        zone = int(w * MENU_ZONE)
        x = max(16, int(w * MENU_MARGIN))
        mw = min(PANEL_W, zone - x)
        draw.rectangle((0, 0, zone, h), fill=(10, 14, 22, 110))
        draw.line((zone, 0, zone, h), fill=(255, 214, 90, 255), width=max(2, w // 400))
        # 메뉴 묶음(로고 56 + 카드 64(폰 72) + 버튼 3 × 32(폰 44) + 간격 8 × 4) 세로 가운데
        mobile = w < 1000
        btn = 44 if mobile else 32
        card = 72 if mobile else 64
        total = 56 + card + btn * 3 + 8 * 4
        y = (h - total) // 2
        f = ImageFont.truetype(FONT, max(12, w // 60))
        draw.rectangle((x, y, x + mw, y + 56), outline=(255, 255, 255, 255), width=2)
        draw.text((x + 6, y + 8), "로고 = GameInfoData.name", font=f, fill=(255, 255, 255, 255))
        y += 64
        draw.rectangle((x, y, x + mw, y + card), fill=(255, 122, 47, 200))
        draw.text((x + 6, y + 6), "이어하기", font=f, fill=(255, 255, 255, 255))
        y += card + 8
        for name in ("직업 선택", "설정", "소식"):
            draw.rectangle((x, y, x + mw, y + btn), fill=(30, 35, 45, 220))
            draw.text((x + 6, y + 4), name, font=f, fill=(255, 255, 255, 255))
            y += btn + 8
        draw.text((zone + 10, 8), "← 메뉴 · 로고 = 왼쪽 35% 안 | 인물 · 무기 · 빛 = 오른쪽 65% →", font=f, fill=(255, 214, 90, 255))
        shot = Image.alpha_composite(shot, layer)
        scale = CELL_W / w
        cell = shot.resize((CELL_W, round(h * scale)), Image.LANCZOS)
        cells.append((title, cell))
    tf = ImageFont.truetype(FONT, 22)
    height = sum(c.height + 44 for _, c in cells) + 50
    sheet = Image.new("RGB", (CELL_W + 40, height), (24, 26, 32))
    d = ImageDraw.Draw(sheet)
    d.text((20, 12), "메인 메뉴 안전 영역 - 키 아트 %s · 세로 기준점 %.2f · 꽉 채움(잘라내기)" % (os.path.basename(SRC), FOCUS_Y), font=tf, fill=(255, 255, 255))
    y = 50
    for title, cell in cells:
        d.text((20, y), title, font=tf, fill=(255, 214, 90))
        sheet.paste(cell.convert("RGB"), (20, y + 34))
        y += cell.height + 44
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    sheet.save(OUT, optimize=True)
    print("O " + os.path.relpath(OUT, ROOT))


if __name__ == "__main__":
    main()
