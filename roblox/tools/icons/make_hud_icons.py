# -*- coding: utf-8 -*-
# QUEUE-ALL1 01 A-4 HUD 메뉴 아이콘(PIL): 기준 = docs/art/ref/16_ui_hud.png - 기능별 색 타일(둥근 사각 20% · 아래 두께 · 위 밝은 띠) + 3톤 기호 + 굵은 외곽선(#1E1B2E).
#   1024로 그려 256으로 줄인다(가장자리 부드럽게) · 투명 PNG → roblox/art/icons/hud/<이름>.png → upload.py(Decal) → HudIcons 표(ArtAssetIds image).
#   단축키 칩 · 알림 빨간 점 · 잠김 자물쇠는 UI가 얹는다(PNG에 없음). 금지 색: 강한 주황 · 빨강 넓은 면(보스 경고) · 흰 + 자홍 · 검정 + 금.
# 실행: python roblox/tools/icons/make_hud_icons.py [--preview 파일.png]
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "art", "icons", "hud"))
S = 1024
INK = (30, 27, 46, 255)
W = 30  # 외곽선 굵기(1024 기준)
WHITE = (255, 255, 255, 255)
FONT = "C:/Windows/Fonts/arialbd.ttf"


def mul(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c[:3]) + (255,)


def lighten(c, t):
    return tuple(int(v + (255 - v) * t) for v in c[:3]) + (255,)


class Pen:
    def __init__(self, d):
        self.d = d

    def poly(self, pts, fill, w=W):
        self.d.polygon(pts, fill=fill)
        if w:
            self.d.line(pts + [pts[0]], fill=INK, width=w, joint="curve")
            for p in pts:
                self.d.ellipse((p[0] - w / 2, p[1] - w / 2, p[0] + w / 2, p[1] + w / 2), fill=INK)

    def ellipse(self, box, fill, w=W):
        self.d.ellipse(box, fill=fill, outline=INK if w else None, width=w)

    def rrect(self, box, r, fill, w=W):
        self.d.rounded_rectangle(box, radius=r, fill=fill, outline=INK if w else None, width=w)

    def line(self, pts, color=INK, w=W):
        self.d.line(pts, fill=color, width=w, joint="curve")
        for p in (pts[0], pts[-1]):
            self.d.ellipse((p[0] - w / 2, p[1] - w / 2, p[0] + w / 2, p[1] + w / 2), fill=color)

    def text(self, xy, s, size, fill):
        f = ImageFont.truetype(FONT, size)
        l, t, r, b = self.d.textbbox((0, 0), s, font=f, stroke_width=int(W * 0.7))
        self.d.text((xy[0] - (r - l) / 2 - l, xy[1] - (b - t) / 2 - t), s, font=f, fill=fill, stroke_width=int(W * 0.7), stroke_fill=INK)


def tile(img, color):
    d = ImageDraw.Draw(img)
    m, r = 64, 190
    d.rounded_rectangle((m, m + 70, S - m, S - m), radius=r, fill=INK)  # 바깥 잉크(아래 두께 포함)
    d.rounded_rectangle((m + W, m + 70 + W - 36, S - m - W, S - m - W), radius=r - 20, fill=mul(color, 0.72))  # 아래 두께
    d.rounded_rectangle((m + W, m + W, S - m - W, S - m - W - 60), radius=r - 20, fill=color)  # 윗면
    d.rounded_rectangle((m + W + 40, m + W + 26, S - m - W - 40, m + W + 150), radius=90, fill=lighten(color, 0.28))  # 위 밝은 띠
    d.rounded_rectangle((m + W, m + W, S - m - W, S - m - W - 60), radius=r - 20, outline=INK, width=W)
    return d


# ── 기호(가운데 ≈ (512, 480) · 폭 ≈ 560) ──
def bag(p, c):
    body = lighten(c, 0.55)
    p.rrect((300, 330, 724, 780), 110, body)
    p.poly([(300, 470), (724, 470), (724, 520), (300, 520)], mul(c, 0.85), w=0)
    p.rrect((300, 330, 724, 530), 110, mul(c, 0.9))  # 덮개
    p.rrect((392, 580, 632, 720), 50, lighten(c, 0.3))  # 앞주머니
    p.line([(420, 330), (420, 250), (604, 250), (604, 330)], INK, 34)  # 손잡이
    p.rrect((470, 470, 554, 560), 22, lighten(c, 0.8))  # 버클


def growth(p, c):
    for i, (x, h) in enumerate(((300, 180), (430, 300), (560, 430))):
        p.rrect((x, 760 - h, x + 104, 760), 18, lighten(c, 0.6) if i < 2 else WHITE)
    p.line([(290, 520), (420, 420), (520, 470), (720, 290)], mul(c, 0.55), 46)
    p.poly([(720, 250), (760, 400), (620, 330)], mul(c, 0.55), w=0)
    p.line([(290, 520), (420, 420), (520, 470), (720, 290)], INK, 12)


def map_(p, c):
    cream = (252, 238, 206, 255)
    pan = [[(280, 330), (420, 290), (420, 740), (280, 780)], [(420, 290), (604, 340), (604, 790), (420, 740)], [(604, 340), (744, 300), (744, 750), (604, 790)]]
    for i, q in enumerate(pan):
        p.poly(q, cream if i != 1 else (236, 214, 170, 255))
    for x, y in ((330, 690), (380, 620), (450, 600), (520, 560), (560, 490)):
        p.d.ellipse((x - 14, y - 14, x + 14, y + 14), fill=(214, 90, 70, 255))
    p.line([(610, 400), (700, 490)], (214, 70, 60, 255), 34)
    p.line([(700, 400), (610, 490)], (214, 70, 60, 255), 34)


def rank(p, c):
    gold, dark = (255, 214, 92, 255), (214, 150, 40, 255)
    p.line([(360, 360), (270, 380), (290, 470), (370, 500)], INK, 34)
    p.line([(664, 360), (754, 380), (734, 470), (654, 500)], INK, 34)
    p.poly([(340, 300), (684, 300), (650, 520), (512, 590), (374, 520)], gold)
    p.poly([(512, 300), (684, 300), (650, 520), (512, 590)], dark, w=0)
    p.rrect((470, 590, 554, 690), 10, dark)
    p.rrect((380, 680, 644, 770), 26, gold)
    star = [(512 + 70 * math.cos(math.radians(-90 + i * 36)) * (1 if i % 2 == 0 else 0.45), 430 + 70 * math.sin(math.radians(-90 + i * 36)) * (1 if i % 2 == 0 else 0.45)) for i in range(10)]
    p.poly(star, WHITE, w=12)


def party(p, c):
    p.ellipse((250, 300, 450, 500), (255, 226, 196, 255))
    p.d.pieslice((200, 520, 500, 860), 180, 360, fill=(92, 156, 240, 255), outline=INK, width=W)
    p.ellipse((560, 300, 760, 500), (255, 226, 196, 255))
    p.d.pieslice((510, 520, 810, 860), 180, 360, fill=(250, 150, 170, 255), outline=INK, width=W)


def pet(p, c):
    pad = lighten(c, 0.62)
    p.ellipse((360, 480, 664, 760), pad)
    for x, y, r in ((300, 420, 70), (420, 320, 76), (604, 320, 76), (724, 420, 70)):
        p.ellipse((x - r, y - r, x + r, y + r), pad)


def codex(p, c):
    p.rrect((300, 280, 724, 780), 34, mul(c, 0.7))
    p.rrect((340, 300, 700, 760), 26, lighten(c, 0.35))
    p.rrect((300, 280, 360, 780), 20, mul(c, 0.55))
    p.rrect((430, 400, 630, 620), 30, (252, 238, 206, 255))
    f = ImageFont.truetype(FONT, 190)
    l, t, r, b = p.d.textbbox((0, 0), "?", font=f)
    p.d.text((530 - (r - l) / 2 - l, 510 - (b - t) / 2 - t), "?", font=f, fill=mul(c, 0.55))


def rebirth(p, c):
    ring = lighten(c, 0.55)
    cx, cy, r = 512, 512, 240
    p.d.arc((cx - r - 22, cy - r - 22, cx + r + 22, cy + r + 22), 60, 320, fill=INK, width=110)
    p.d.arc((cx - r, cy - r, cx + r, cy + r), 62, 318, fill=ring, width=66)
    a = math.radians(320)
    ex, ey = cx + r * math.cos(a), cy + r * math.sin(a)
    tx, ty = -math.sin(a), math.cos(a)  # 호가 도는 방향(각이 느는 쪽 = 화면 시계 방향)의 접선
    nx, ny = math.cos(a), math.sin(a)
    p.poly([(ex + tx * 110, ey + ty * 110), (ex + nx * 95, ey + ny * 95), (ex - nx * 95, ey - ny * 95)], ring)
    star = [(cx + 150 * math.cos(math.radians(-90 + i * 36)) * (1 if i % 2 == 0 else 0.45), cy + 150 * math.sin(math.radians(-90 + i * 36)) * (1 if i % 2 == 0 else 0.45)) for i in range(10)]
    p.poly(star, (255, 214, 92, 255))


def return_(p, c):
    p.poly([(470, 560), (554, 560), (574, 800), (450, 800)], (140, 92, 58, 255))
    for x, y, r in ((400, 470, 130), (624, 470, 130), (512, 360, 150)):
        p.ellipse((x - r, y - r, x + r, y + r), lighten(c, 0.3))
    p.ellipse((440, 300, 560, 400), lighten(c, 0.6), w=0)


def shop(p, c):
    bag_c = (236, 196, 120, 255)
    p.poly([(420, 330), (604, 330), (660, 280), (364, 280)], mul(bag_c, 0.8))
    p.ellipse((270, 360, 754, 800), bag_c)
    p.rrect((400, 330, 624, 390), 20, mul(bag_c, 0.7))
    p.ellipse((400, 460, 624, 684), (255, 214, 92, 255))
    p.text((512, 572), "$", 170, (130, 90, 30, 255))


def forge(p, c):
    steel, dark = (196, 204, 224, 255), (110, 118, 150, 255)
    p.poly([(250, 520), (774, 520), (704, 610), (320, 610)], steel)
    p.poly([(400, 610), (624, 610), (600, 700), (424, 700)], dark)
    p.rrect((340, 690, 684, 770), 24, dark)
    p.line([(560, 460), (720, 260)], (140, 92, 58, 255), 50)
    p.rrect((640, 190, 800, 300), 26, steel)
    for x1, y1, x2, y2 in ((440, 440, 400, 360), (480, 420, 480, 330), (520, 440, 560, 370)):
        p.line([(x1, y1), (x2, y2)], (255, 214, 92, 255), 26)


def settings(p, c):
    body = lighten(c, 0.5)
    cx, cy = 512, 512
    teeth = []
    for i in range(8):
        a = math.radians(i * 45)
        ux, uy = math.cos(a), math.sin(a)
        vx, vy = -uy, ux
        w, r0, r1 = 58, 150, 262
        teeth.append([(cx + ux * r0 + vx * w, cy + uy * r0 + vy * w), (cx + ux * r1 + vx * w * 0.8, cy + uy * r1 + vy * w * 0.8),
                      (cx + ux * r1 - vx * w * 0.8, cy + uy * r1 - vy * w * 0.8), (cx + ux * r0 - vx * w, cy + uy * r0 - vy * w)])
    # 두 번 그리기: 잉크(외곽선 두께만큼 큰 모양) → 채움 - 톱니와 몸통의 외곽선이 하나로 이어진다
    for t in teeth:
        p.d.polygon(t, fill=INK)
        p.d.line(t + [t[0]], fill=INK, width=W * 2, joint="curve")
    p.d.ellipse((cx - 200 - W, cy - 200 - W, cx + 200 + W, cy + 200 + W), fill=INK)
    for t in teeth:
        p.d.polygon(t, fill=body)
    p.d.ellipse((cx - 200, cy - 200, cx + 200, cy + 200), fill=body)
    p.ellipse((cx - 86, cy - 86, cx + 86, cy + 86), mul(c, 0.6))


def quest(p, c):
    paper, dark = (252, 238, 206, 255), (214, 180, 120, 255)
    p.rrect((300, 300, 724, 760), 40, paper)
    p.rrect((260, 250, 764, 340), 45, dark)
    p.rrect((260, 720, 764, 810), 45, dark)
    for y in (430, 510, 590):
        p.line([(360, y), (520, y)], mul(dark, 0.7), 22)
    p.line([(560, 540), (620, 610), (720, 450)], (60, 170, 90, 255), 52)
    p.line([(560, 540), (620, 610), (720, 450)], INK, 12)


# 이름 → (타일 색, 기호) · 색 = 레퍼런스 기능 계열(성장 초록 · 전투/강화 회청 · 소셜 주황 · 탐험 청록)
ICONS = {
    "bag": ((243, 154, 60), bag), "growth": ((86, 194, 106), growth), "map": ((57, 194, 214), map_), "rank": ((245, 195, 59), rank),
    "party": ((240, 120, 104), party), "pet": ((242, 178, 116), pet), "codex": ((62, 158, 142), codex), "rebirth": ((155, 92, 240), rebirth),
    "return": ((77, 176, 74), return_), "shop": ((201, 160, 106), shop), "forge": ((124, 132, 168), forge), "settings": ((184, 188, 200), settings),
    "quest": ((217, 164, 91), quest),
}


def build(name):
    color, fn = ICONS[name]
    color = color + (255,)
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = tile(img, color)
    fn(Pen(d), color)
    return img.resize((256, 256), Image.LANCZOS)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    out = []
    for name in ICONS:
        im = build(name)
        im.save(os.path.join(OUT, name + ".png"))
        out.append(im)
    if "--preview" in sys.argv:
        sheet = Image.new("RGBA", (256 * 7, 256 * 2), (40, 44, 60, 255))
        for i, im in enumerate(out):
            sheet.alpha_composite(im, ((i % 7) * 256, (i // 7) * 256))
        sheet.save(sys.argv[sys.argv.index("--preview") + 1])
    print("icons", len(out), OUT)
