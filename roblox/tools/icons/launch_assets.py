# -*- coding: utf-8 -*-
# QUEUE-ALL2 P6 출시 준비물(09 D): 썸네일 3장 × (글자 있음 · 없음) 1920 × 1080 + 아이콘 3장 512 × 512.
#   입력 = Studio Play 실제 장면 캡처(Claude outputs/QUEUE-ALL2/launch/src - 1920 × 788 · UI 숨김) · 과장 금지: 그림 속 장면은 손대지 않고 자르기 · 늘리기 · 글자 · 테두리만 얹는다.
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.environ.get("LAUNCH_ROOT") or os.path.join(os.path.dirname(__file__), "..", "..", "..", "Claude outputs", "QUEUE-ALL2", "launch")  # QUEUE-STUDIO: 재촬영 폴더를 따로 줄 수 있게
SRC = os.path.join(ROOT, "src")
FONT = "C:/Windows/Fonts/malgunbd.ttf"
TAGLINE = "뜨는 순간, 전 서버가 본다"
INK = (30, 27, 46)
GOLD = (255, 214, 90)


def cover(img, w, h, cx=0.5, cy=0.5):
    # 비율을 지키며 w × h를 덮게 늘리고 (cx, cy) 기준으로 자른다
    s = max(w / img.width, h / img.height)
    big = img.resize((round(img.width * s), round(img.height * s)), Image.LANCZOS)
    x = min(max(round(big.width * cx - w / 2), 0), big.width - w)
    y = min(max(round(big.height * cy - h / 2), 0), big.height - h)
    return big.crop((x, y, x + w, y + h))


def outlined(draw, xy, text, font, fill, stroke, width, anchor="mm"):
    draw.text(xy, text, font=font, fill=fill, stroke_width=width, stroke_fill=stroke, anchor=anchor)


def thumb(name, src, cx, cy):
    if not os.path.exists(os.path.join(SRC, src)):
        return
    img = cover(Image.open(os.path.join(SRC, src)).convert("RGB"), 1920, 1080, cx, cy)
    img.save(os.path.join(ROOT, "thumb_%s_plain.png" % name))
    # 글자판: 아래 띠(어두운 그라데이션) + 금 글자 굵은 외곽선
    band = Image.new("L", (1920, 1080), 0)
    bd = ImageDraw.Draw(band)
    for y in range(700, 1080):
        bd.line([(0, y), (1920, y)], fill=int(190 * (y - 700) / 380))
    dark = Image.new("RGB", (1920, 1080), INK)
    img = Image.composite(dark, img, band)
    d = ImageDraw.Draw(img)
    outlined(d, (960, 950), TAGLINE, ImageFont.truetype(FONT, 104), GOLD, INK, 10)
    img.save(os.path.join(ROOT, "thumb_%s_text.png" % name))


def icon(name, src, box, tint):
    if not os.path.exists(os.path.join(SRC, src)):  # QUEUE-STUDIO: 그 원본을 안 찍은 재촬영 폴더면 건너뜀
        return
    img = Image.open(os.path.join(SRC, src)).convert("RGB").crop(box).resize((512, 512), Image.LANCZOS)
    # 가장자리 살짝 어둡게(가운데 캐릭터 강조) + 굵은 외곽선 둥근 테두리
    vignette = Image.new("L", (512, 512), 0)
    ImageDraw.Draw(vignette).ellipse((-80, -60, 592, 600), fill=255)
    vignette = vignette.filter(ImageFilter.GaussianBlur(60))
    shade = Image.new("RGB", (512, 512), tint)
    img = Image.composite(img, shade, vignette)
    mask = Image.new("L", (512, 512), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, 511, 511), radius=96, fill=255)
    out = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    ImageDraw.Draw(out).rounded_rectangle((6, 6, 505, 505), radius=92, outline=INK + (255,), width=14)
    ImageDraw.Draw(out).rounded_rectangle((18, 18, 493, 493), radius=82, outline=GOLD + (255,), width=5)
    out.save(os.path.join(ROOT, "icon_%s.png" % name))


thumb("A_transcend", "transcend_pillar.jpg", 0.5, 0.55)
thumb("B_codex", "codex.jpg", 0.47, 0.5)
thumb("C_hub", "hub_tree.jpg", 0.5, 0.5)
# 캐릭터 근접(1920 × 788 캡처 · 캐릭터 가운데 약 (1065, 520))
icon("A_grass", "char_close.jpg", (796, 250, 1334, 788), (60, 110, 60))
icon("B_pillar", "char_close_pillar.jpg", (720, 250, 1258, 788), (120, 100, 30))
icon("C_tight", "char_close.jpg", (865, 300, 1265, 700), (40, 60, 90))
print("ok")
