# -*- coding: utf-8 -*-
# QUEUE-ALL5 E 출시 아이콘(Pillow): Creator Hub 개발자 상품 8 · 게임패스 5(512 × 512 투명) + 게임 아이콘 후보 3(512 × 512 꽉 찬 사각).
#   스타일 = make_hud_icons.py와 같다(1024로 그려 줄임 · 둥근 사각 타일 20% + 아래 두께 + 위 밝은 띠 · 3톤(기본 · ×1.18 밝게 · ×0.72 그늘) · 굵은 외곽선 #1E1B2E).
#     기준: docs/art/art-direction-v1.md §3-3(3톤 · 순검정 금지 · 가장 어두운 색 = #1E1B2E) · §3-4(위험색 = 주황빨강 330 ~ 50° → 보스 전조 전용)
#           make_hud_icons.py · make_ui_icons_v2.py 머리 주석(금지 색: 강한 주황 · 빨강 넓은 면 · 흰 + 자홍(태초) · 검정 + 금(초월) · 그림 안 글자 없음)
#           ArtV1CosmeticData.lua 머리 주석(치장 색 = TrailSkin.check 금지 - 주황 · 빨강 330 ~ 50° 채도 ≥ 0.35)
#   3D 물체(드래곤 날개 · 구름 고래 · 캐릭터 · 슬라임) = store_renders_blender.py 원본(평면 + 스튜디오 두 장)을 render_codex_portraits.shade로 합쳐 3톤으로 얹는다.
#   파일명 = MonetizationData 키(.png) → docs/release/icons/ · 확인용 _sheet.png(회색 · 어두운 바탕).
# 실행: bash roblox/tools/blender/bl.sh roblox/tools/icons/store_renders_blender.py   (원본 → docs/release/icons/src - 모양이 바뀔 때만)
#       python roblox/tools/icons/make_store_icons.py
import colorsys
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.normpath(os.path.join(HERE, "..", "blender")))
from make_hud_icons import INK, S, W, WHITE, Pen, lighten, mul, tile  # noqa: E402
import make_hud_icons as H  # noqa: E402
from make_ui_icons_v2 import CREAM, CREAM_D, GOLD, GOLD_D, STEEL_D, WOOD, cross, egg_pts, ring, sparkle, star_pts, stroke  # noqa: E402
from render_codex_portraits import shade  # noqa: E402

OUT = os.path.join(REPO, "docs", "release", "icons")
SRC = os.path.join(OUT, "src")
SIZE = 512


def rgba(c):
    return tuple(c[:3]) + (255,)


def hi(c):
    return mul(c, 1.18)


def lo(c):
    return mul(c, 0.72)


# ── 3D 원본 → 3톤 RGBA(외곽 상자로 잘림) ──
def model(name, k=0.55):
    flat = Image.open(os.path.join(SRC, name + ".png")).convert("RGBA")
    studio = Image.open(os.path.join(SRC, name + "__shade.png")).convert("RGBA")
    im = shade(flat, studio, k)
    return im.crop(im.split()[3].point(lambda v: 255 if v > 8 else 0).getbbox())


def place(img, im, box):
    """im을 box(x0, y0, x1, y1) 안에 비율 유지로 맞춰 가운데에"""
    x0, y0, x1, y1 = box
    k = min((x1 - x0) / im.width, (y1 - y0) / im.height)
    im = im.resize((max(1, int(im.width * k)), max(1, int(im.height * k))), Image.LANCZOS)
    img.alpha_composite(im, (int((x0 + x1 - im.width) / 2), int((y0 + y1 - im.height) / 2)))


def soft_shadow(img, box, alpha=90):
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse(box, fill=INK[:3] + (alpha,))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(14)))


def streaks(p, c, y0=640):
    """대시 트레일 표시(테마 세트 공통 - 왼쪽 아래 속도선 두 줄)"""
    stroke(p, [(170, y0), (330, y0 - 90)], lighten(c, 0.55), 30)
    stroke(p, [(200, y0 + 110), (330, y0 + 40)], lighten(c, 0.55), 22)


# ── 개발자 상품: 테마 세트 4(타일 = 그 세트의 색 · 기호 = 세트 입자 모양 + 대시 속도선) ──
def theme_starlight(p, c):  # 별빛: 남색 → 보라 + 흰 별
    streaks(p, c, 660)
    star = star_pts(560, 450, 270, 0.48)
    p.poly(star, (214, 226, 255, 255), w=0)
    p.poly([(560, 450)] + star[1:5], (170, 182, 240, 255), w=0)  # 오른쪽 아래 그늘(3톤 그늘 쪽)
    p.d.line(star + [star[0]], fill=INK, width=W, joint="curve")
    p.ellipse((470, 330, 540, 400), WHITE, w=0)
    sparkle(p, 260, 300, 70)
    sparkle(p, 800, 720, 56)


def flame_pts(cx, by, w, h):
    """불꽃: 아래 둥근 몸(반지름 w · 바닥 by) + 위로 휜 뾰족 끝(높이 h)"""
    return [(cx - w * 0.95, by - w * 1.25), (cx - w * 0.35, by - h * 0.62), (cx + w * 0.15, by - h), (cx + w * 0.45, by - h * 0.55), (cx + w * 0.95, by - w * 1.3)] + \
        [(cx + w * math.cos(math.radians(a)), by - w + w * math.sin(math.radians(a))) for a in range(-15, 196, 7)]


def theme_ember(p, c):  # 불씨: 금노랑 불꽃 + 튀는 불씨(색상 51 ~ 56° - 위험색 밖)
    streaks(p, c, 690)
    outer = flame_pts(560, 790, 230, 560)
    p.poly(outer, (255, 238, 130, 255))
    p.poly(flame_pts(585, 790, 230, 560)[-16:] + [(560, 600)], (232, 206, 70, 255), w=0)
    p.d.line(outer + [outer[0]], fill=INK, width=W, joint="curve")
    p.poly(flame_pts(560, 770, 120, 330), (255, 250, 214, 255), w=22)
    for x, y, r in ((290, 330, 38), (790, 300, 30), (830, 520, 24), (330, 520, 26)):
        p.poly(star_pts(x, y, r * 1.6, 0.42, 4), (255, 236, 110, 255), w=14)


def snowflake(p, cx, cy, r, col):
    arms = []
    for i in range(6):
        a = math.radians(-90 + i * 60)
        u = (math.cos(a), math.sin(a))
        tip = (cx + u[0] * r, cy + u[1] * r)
        arms.append([(cx, cy), tip])
        for k, L in ((0.55, 0.32), (0.8, 0.2)):
            b = (cx + u[0] * r * k, cy + u[1] * r * k)
            for s in (1, -1):
                aa = a + s * math.radians(50)
                arms.append([b, (b[0] + math.cos(aa) * r * L, b[1] + math.sin(aa) * r * L)])
    for seg in arms:
        p.line(seg, INK, 64 + 2 * W - 30)
    for seg in arms:
        p.line(seg, col, 34)
    p.poly([(cx + 70 * math.cos(math.radians(-90 + i * 60)), cy + 70 * math.sin(math.radians(-90 + i * 60))) for i in range(6)], (206, 246, 255, 255), w=16)


def theme_frost(p, c):  # 서리꽃: 옅은 청록 + 흰 결정
    streaks(p, c, 690)
    snowflake(p, 560, 450, 300, (236, 252, 255, 255))
    sparkle(p, 250, 290, 56)


def theme_jelly(p, c):  # 말랑 젤리: 라임 + 민트 방울
    streaks(p, c, 700)
    body = [(560 + 260 * math.cos(math.radians(a)) * (1 + 0.06 * math.sin(math.radians(a * 3))), 560 + 220 * math.sin(math.radians(a)) * (0.85 if a > 180 else 1.0)) for a in range(0, 360, 6)]
    body = [(x, y if y > 560 else 560 - (560 - y) * 1.35) for x, y in body]
    p.poly(body, (206, 250, 150, 255))
    p.d.chord((300, 560, 820, 790), 0, 180, fill=(170, 222, 112, 255))  # 아래 그늘(×0.72에 가깝게 - 라임이 탁해지지 않게 0.85)
    p.d.line(body + [body[0]], fill=INK, width=W, joint="curve")
    p.ellipse((420, 330, 520, 420), WHITE, w=0)
    p.ellipse((540, 340, 580, 380), WHITE, w=0)
    for x, y, r in ((260, 330, 48), (800, 300, 36), (850, 470, 26)):
        p.ellipse((x - r, y - r, x + r, y + r), (190, 250, 200, 255), w=16)
        p.ellipse((x - r * 0.45, y - r * 0.55, x - r * 0.05, y - r * 0.15), WHITE, w=0)


# ── 개발자 상품: 글라이더 3(타일 = 하늘색 공통 · 물체가 상품 모양) ──
SKY_TILE = (140, 200, 244)  # 드래곤 날개 파랑(70, 130, 205)과 대비가 나게 옅은 하늘


def glider_frame(p):
    stroke(p, [(512, 560), (512, 760)], STEEL_D, 24)
    stroke(p, [(410, 760), (614, 760)], STEEL_D, 26)


def glider_petal(p, c):  # 꽃잎 글라이더: 꽃잎 5장 캐노피(분홍 · 크림 · 연두 가운데)
    glider_frame(p)
    pink, pink_d = (255, 182, 204, 255), (226, 140, 170, 255)
    for a in (-160, -125, -90, -55, -20):
        r = math.radians(a)
        cx, cy = 512 + 230 * math.cos(r), 520 + 230 * math.sin(r)
        pts = [(cx + 150 * math.cos(math.radians(t)) * math.cos(r) - 100 * math.sin(math.radians(t)) * math.sin(r),
                cy + 150 * math.cos(math.radians(t)) * math.sin(r) + 100 * math.sin(math.radians(t)) * math.cos(r)) for t in range(0, 360, 10)]
        p.poly(pts, pink if a != -20 else pink_d)
        p.d.line([(512, 520), (cx + 60 * math.cos(r), cy + 60 * math.sin(r))], fill=pink_d, width=12)
    p.ellipse((432, 440, 592, 600), (150, 214, 110, 255))
    p.ellipse((470, 470, 520, 520), lighten((150, 214, 110), 0.5), w=0)


def glider_kite(p, c):  # 연 글라이더: 마름모 연(파랑 · 옅은 노랑 4칸) + 꼬리 리본
    stroke(p, [(512, 700), (560, 790), (640, 830), (720, 900)], (240, 240, 230, 255), 14)
    for x, y in ((560, 790), (690, 870)):
        p.poly([(x - 50, y - 34), (x, y), (x - 50, y + 34)], (120, 214, 140, 255), w=16)
        p.poly([(x + 50, y - 34), (x, y), (x + 50, y + 34)], (120, 214, 140, 255), w=16)
    T, R, B, L, M = (512, 150), (780, 420), (512, 720), (244, 420), (512, 420)
    blue, yel = (92, 140, 236, 255), (250, 240, 150, 255)
    p.poly([T, R, M], yel, w=0)
    p.poly([R, B, M], lo(blue), w=0)
    p.poly([B, L, M], mul(yel, 0.86), w=0)
    p.poly([L, T, M], blue, w=0)
    p.d.line([T, B], fill=WOOD, width=22)
    p.d.line([L, R], fill=WOOD, width=22)
    p.d.line([T, R, B, L, T], fill=INK, width=W, joint="curve")
    for q in (T, R, B, L):
        p.d.ellipse((q[0] - W / 2, q[1] - W / 2, q[0] + W / 2, q[1] + W / 2), fill=INK)


def glider_dragonWing(img, p, c):  # 푸른 드래곤 날개: Blender 렌더(몬스터 날개 메시 그대로) - 양쪽을 V로 세움
    wing = model("dragon_wing")
    w2 = wing.width // 2
    halves = []
    for box, ang in (((0, 0, w2, wing.height), -18), ((w2, 0, wing.width, wing.height), 18)):
        h_ = wing.crop(box)
        h_ = h_.crop(h_.split()[3].getbbox()).rotate(ang, resample=Image.BICUBIC, expand=True)
        halves.append(h_.crop(h_.split()[3].getbbox()))
    left, right = halves
    gap = 30  # 두 날개 뿌리 사이(등 자리)
    both = Image.new("RGBA", (left.width + right.width + gap, max(left.height, right.height)), (0, 0, 0, 0))
    both.alpha_composite(left, (0, both.height - left.height))
    both.alpha_composite(right, (left.width + gap, both.height - right.height))
    place(img, both, (56, 110, 968, 820))  # 타일 윗면(94 ~ 930)을 넘칠 만큼 크게 - 날개 끝은 타일 테 위로 살짝 나가도 된다
    p.rrect((482, 560, 542, 700), 26, (60, 100, 170, 255))  # 등에 메는 고리(날개 사이)


def season_premium(img, p, c):  # 시즌 패스 유료 줄: 구름 고래(시즌 1 대표 탈것) + 위 왕관 리본
    sparkle(p, 230, 270, 60)
    sparkle(p, 820, 250, 44)
    place(img, model("cloud_whale"), (150, 300, 874, 800))
    # 왕관(유료 줄 표시 - 금 + 흰. 검정 + 금 아님)
    crown = [(400, 300), (420, 170), (470, 240), (512, 140), (554, 240), (604, 170), (624, 300)]
    p.poly(crown, GOLD)
    p.poly([(512, 140), (554, 240), (604, 170), (624, 300), (512, 300)], GOLD_D, w=0)
    p.d.line(crown + [crown[0]], fill=INK, width=W, joint="curve")
    for x, y in ((420, 170), (512, 140), (604, 170)):
        p.ellipse((x - 24, y - 24, x + 24, y + 24), (214, 226, 255, 255), w=12)


# ── 게임패스 5 ──
def bagExpand(p, c):  # 가방 + 20칸: 큰 가방(HUD 가방 기호) + 더하기 배지
    H.bag(Pen(p.d), (236, 196, 120, 255))
    p.ellipse((600, 560, 860, 820), (90, 190, 100, 255))
    cross(p, 730, 690, 84, 26, WHITE)


def gem(p, x, y, s, g):
    p.poly([(x, y - s * 1.2), (x + s, y), (x, y + s * 1.2), (x - s, y)], g)
    p.poly([(x, y - s * 1.2), (x + s, y), (x, y + s * 1.2)], mul(g, 0.72), w=0)
    p.d.line([(x, y - s * 1.2), (x + s, y), (x, y + s * 1.2), (x - s, y), (x, y - s * 1.2)], fill=INK, width=W, joint="curve")
    p.ellipse((x - s * 0.45, y - s * 0.6, x - s * 0.1, y - s * 0.25), WHITE, w=0)


def coin(p, x, y, r):
    p.ellipse((x - r, y - r, x + r, y + r), GOLD, w=0)
    p.d.chord((x - r, y - r, x + r, y + r), 20, 200, fill=GOLD_D)  # 아래 그늘
    p.ellipse((x - r * 0.5, y - r * 0.5, x + r * 0.5, y + r * 0.5), lighten(GOLD, 0.4), w=14)
    p.d.ellipse((x - r - W / 2, y - r - W / 2, x + r + W / 2, y + r + W / 2), outline=INK, width=W)  # 외곽선은 바깥에(채움이 묻히지 않게)


def pickupRadius(img, p, c):  # 자동 줍기 반경: 가운데 펫(make_pets 강아지 렌더) + 점선 원 + 안쪽으로 끌려오는 보석 · 금화 3
    cx, cy, r = 512, 470, 345
    for i in range(12):  # 점선 원(잉크 테 + 흰 조각)
        a0 = i * 30 + 4
        p.d.arc((cx - r - 24, cy - r - 24, cx + r + 24, cy + r + 24), a0, a0 + 20, fill=INK, width=60)
        p.d.arc((cx - r - 8, cy - r - 8, cx + r + 8, cy + r + 8), a0 + 2, a0 + 18, fill=WHITE, width=28)
    items = ((215, 300, "gem"), (830, 380, "coin"), (250, 690, "coin"))
    for x, y, _ in items:  # 끌려오는 방향 = 펫 쪽 꺾쇠 2개(흰 + 잉크)
        u = ((cx - x), (cy - y))
        n = math.hypot(*u)
        u = (u[0] / n, u[1] / n)
        v = (-u[1], u[0])
        for k in (100, 155):
            t = (x + u[0] * (k + 40), y + u[1] * (k + 40))
            b = (x + u[0] * k, y + u[1] * k)
            stroke(p, [(b[0] + v[0] * 36, b[1] + v[1] * 36), t, (b[0] - v[0] * 36, b[1] - v[1] * 36)], WHITE, 20)
    soft_shadow(img, (370, 610, 660, 690), 70)
    place(img, model("pet"), (340, 250, 690, 680))
    for x, y, kind in items:
        if kind == "gem":
            gem(p, x, y, 70, (110, 200, 255, 255))
        else:
            coin(p, x, y, 70)


def recallCooldown(p, c):  # 빠른 귀환: 집 + 감싸는 화살 고리 + 번개(빠름)
    ringc = lighten(c, 0.55)
    cx, cy, r = 500, 500, 280
    p.d.arc((cx - r - 22, cy - r - 22, cx + r + 22, cy + r + 22), 200, 480, fill=INK, width=110)
    p.d.arc((cx - r, cy - r, cx + r, cy + r), 202, 478, fill=ringc, width=66)
    a = math.radians(480)
    ex, ey = cx + r * math.cos(a), cy + r * math.sin(a)
    tx, ty = -math.sin(a), math.cos(a)
    nx, ny = math.cos(a), math.sin(a)
    p.poly([(ex + tx * 110, ey + ty * 110), (ex + nx * 95, ey + ny * 95), (ex - nx * 95, ey - ny * 95)], ringc)
    wall, roof = CREAM, (110, 140, 220, 255)
    p.rrect((390, 480, 610, 660), 20, wall)
    p.poly([(350, 500), (500, 360), (650, 500)], roof)
    p.rrect((465, 560, 535, 660), 14, WOOD)
    bolt = [(760, 560), (680, 720), (740, 720), (700, 860), (850, 660), (780, 660), (830, 560)]
    p.poly(bolt, GOLD)


def plate(p, box, fill):
    p.rrect(box, (box[3] - box[1]) // 2, fill)


def nameplateColor(img, p, c):  # 이름표 색(QUEUE-STUDIO 0-4 다시): 타일 가득 큰 무지개 이름표 띠(비스듬한 색 줄) + 반짝임 - 배지 아이콘과 실루엣이 다르게(가로 띠 vs 세로 방패)
    box = (110, 330, 914, 640)
    plate(p, box, WHITE)
    cols = [(92, 156, 240), (80, 200, 220), (90, 200, 120), (250, 236, 120), (170, 120, 240)]  # 무지개(위험색 330 ~ 50° 뺌)
    inner = Image.new("L", (S, S), 0)
    ImageDraw.Draw(inner).rounded_rectangle((box[0] + W // 2, box[1] + W // 2, box[2] - W // 2, box[3] - W // 2), radius=(box[3] - box[1]) // 2 - W // 2, fill=255)
    bands = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bands)
    step, slant = 190, 120
    for i in range(-1, 7):
        x0 = box[0] - 60 + i * step
        col = cols[i % len(cols)]
        bd.polygon([(x0, box[3]), (x0 + slant, box[1]), (x0 + slant + step, box[1]), (x0 + step, box[3])], fill=rgba(col))
        bd.polygon([(x0 + slant * 0.86, box[1] + 30), (x0 + slant * 0.72, box[1] + 70), (x0 + slant * 0.72 + step, box[1] + 70), (x0 + slant * 0.86 + step, box[1] + 30)], fill=lighten(col, 0.35))
    img.paste(bands, (0, 0), Image.composite(bands, Image.new("RGBA", (S, S), (0, 0, 0, 0)), inner).split()[3])
    p.d.rounded_rectangle(box, radius=(box[3] - box[1]) // 2, outline=INK, width=W)
    for x, y, r in ((220, 250, 52), (800, 720, 60), (880, 250, 36)):
        p.poly(star_pts(x, y, r * 1.8, 0.3, 4), (255, 250, 214, 255), w=12)


def nameplateBadge(p, c):  # 이름표 배지(QUEUE-STUDIO 0-4 다시): 타일 가운데 큰 방패 배지(별) + 뒤로 지나가는 짧은 크림 이름표 띠 - 색 아이콘과 실루엣이 다르게
    plate(p, (150, 470, 874, 600), CREAM)
    p.rrect((560, 510, 800, 560), 25, CREAM_D, w=0)  # 이름 자리(글자 대신 빈 줄)
    sh = [(512, 170), (760, 260), (760, 560), (512, 860), (264, 560), (264, 260)]
    p.poly(sh, (92, 156, 240, 255))
    p.poly([(512, 170), (760, 260), (760, 560), (512, 860)], (66, 112, 190, 255), w=0)
    p.poly([(512, 230), (700, 300), (700, 340), (512, 280), (324, 340), (324, 300)], lighten((92, 156, 240), 0.35), w=0)  # 윗면 밝은 띠
    p.d.line(sh + [sh[0]], fill=INK, width=W, joint="curve")
    p.poly(star_pts(512, 500, 190, 0.45), GOLD, w=18)

# ── QUEUE-ALL6 H 꾸미기 TOP 10(테마 2 · 글라이더 1 · 소품 7) ──
def hammer(p, cx, cy, s, head, handle, ang=-35):
    """망치: 자루(나무) + 가로 머리(head 색) - ang도 기울임"""
    a = math.radians(ang)
    ux, uy = math.cos(a), math.sin(a)  # 머리 가로 방향
    vx, vy = -uy, ux  # 자루 방향(아래)
    stroke(p, [(cx, cy), (cx + vx * s * 1.5, cy + vy * s * 1.5)], handle, s * 0.22)
    hw, hh = s * 0.75, s * 0.32
    pts = [(cx - ux * hw - vx * hh, cy - uy * hw - vy * hh), (cx + ux * hw - vx * hh, cy + uy * hw - vy * hh),
           (cx + ux * hw + vx * hh, cy + uy * hw + vy * hh), (cx - ux * hw + vx * hh, cy - uy * hw + vy * hh)]
    p.poly(pts, head)
    p.poly([pts[2], pts[3], ((pts[2][0] + pts[3][0]) / 2 - vx * hh * 0.6, (pts[2][1] + pts[3][1]) / 2 - vy * hh * 0.6)], lo(head), w=0)


def theme_anvil(p, c):  # 망치와 모루: 모루(강철) + 금노랑 망치 + 불꽃 튐
    streaks(p, c, 700)
    anvil = [(300, 560), (760, 560), (820, 520), (840, 600), (700, 640), (640, 760), (720, 820), (380, 820), (450, 760), (400, 640), (300, 620)]
    p.poly(anvil, (150, 160, 178, 255))
    p.poly([(400, 640), (700, 640), (640, 760), (450, 760)], (112, 120, 140, 255), w=0)
    p.d.line(anvil + [anvil[0]], fill=INK, width=W, joint="curve")
    hammer(p, 560, 330, 190, (255, 236, 110, 255), WOOD)
    for x, y, r in ((300, 380, 40), (800, 380, 34), (850, 250, 26), (250, 250, 24)):
        p.poly(star_pts(x, y, r * 1.6, 0.42, 4), (255, 244, 170, 255), w=14)


def bat_shape(p, cx, cy, s, col):
    wing = [(cx, cy - s * 0.1), (cx - s * 0.35, cy - s * 0.45), (cx - s * 0.8, cy - s * 0.35), (cx - s * 1.1, cy - s * 0.6), (cx - s * 1.05, cy),
            (cx - s * 0.75, cy - s * 0.08), (cx - s * 0.55, cy + s * 0.18), (cx - s * 0.3, cy + s * 0.05), (cx, cy + s * 0.3)]
    pts = wing + [(2 * cx - x, y) for x, y in reversed(wing)]
    p.poly(pts, col)
    p.ellipse((cx - s * 0.2, cy - s * 0.3, cx + s * 0.2, cy + s * 0.25), mul(col, 0.8), w=0)
    p.ellipse((cx - s * 0.12, cy - s * 0.15, cx - s * 0.04, cy - s * 0.07), (255, 244, 170, 255), w=0)
    p.ellipse((cx + s * 0.04, cy - s * 0.15, cx + s * 0.12, cy - s * 0.07), (255, 244, 170, 255), w=0)


def theme_halloween(p, c):  # 할로윈 박쥐: 보라 타일 + 박쥐 셋 + 아래 차분한 호박(채도 낮은 갈색 - 위험색 밖)
    pk = (196, 166, 130, 255)
    for dx in (-110, 110):
        p.ellipse((512 + dx - 150, 600, 512 + dx + 150, 860), mul(pk, 0.9))
    p.ellipse((362, 580, 662, 870), pk)
    stroke(p, [(512, 590), (530, 520)], (76, 120, 76, 255), 30)
    bat_shape(p, 512, 360, 260, (70, 44, 104, 255))
    bat_shape(p, 230, 600, 110, (96, 64, 140, 255))
    bat_shape(p, 820, 560, 120, (96, 64, 140, 255))


def glider_slimeParachute(p, c):  # 슬라임 낙하산: 연두 슬라임 반원 캐노피 + 눈 + 줄
    glider_frame(p)
    green = (120, 214, 126, 255)
    dome = [(512 + 330 * math.cos(math.radians(a)), 520 + 280 * math.sin(math.radians(a))) for a in range(180, 361, 6)]
    drips = [(842, 520), (790, 570), (740, 530), (680, 585), (620, 530), (512, 590), (420, 530), (350, 580), (290, 530), (230, 575), (182, 520)]
    p.poly(dome + drips, green)
    for x in (300, 512, 724):
        p.d.line([(x, 560), (512, 760)], fill=STEEL_D, width=10)
    p.ellipse((410, 330, 470, 400), (30, 40, 30, 255), w=0)
    p.ellipse((554, 330, 614, 400), (30, 40, 30, 255), w=0)
    p.ellipse((424, 342, 446, 364), WHITE, w=0)
    p.ellipse((568, 342, 590, 364), WHITE, w=0)
    p.ellipse((300, 300, 380, 360), lighten(green, 0.6), w=0)


def item_rocketPop(p, c):  # 로켓 반짝: 하늘로 날아가는 작은 슬라임 + 궤적 + 반짝 별
    stroke(p, [(200, 840), (330, 700), (440, 600)], lighten(c, 0.5), 60)
    stroke(p, [(300, 880), (420, 760)], lighten(c, 0.5), 36)
    slime = [(560 + 190 * math.cos(math.radians(a)), 520 + 160 * math.sin(math.radians(a)) * (1.25 if a > 180 else 1.0)) for a in range(0, 360, 8)]
    p.poly(slime, (150, 214, 140, 255))
    p.ellipse((500, 440, 540, 490), INK, w=0)
    p.ellipse((590, 440, 630, 490), INK, w=0)
    p.ellipse((450, 380, 500, 420), WHITE, w=0)
    p.poly(star_pts(760, 270, 190, 0.38, 4), (255, 244, 170, 255))
    sparkle(p, 300, 300, 60)
    sparkle(p, 840, 520, 48)


def item_balloonPop(p, c):  # 풍선 펑: 터지는 풍선(하늘 · 보라) + 색종이
    p.ellipse((330, 240, 640, 590), (150, 200, 255, 255))
    p.poly([(470, 590), (500, 590), (485, 630)], (120, 170, 230, 255), w=16)
    stroke(p, [(485, 630), (470, 760), (500, 860)], (240, 240, 230, 255), 10)
    p.ellipse((390, 300, 450, 380), WHITE, w=0)
    p.poly(star_pts(720, 430, 200, 0.45, 8), (255, 244, 170, 255))
    for x, y, col in ((250, 220, (190, 160, 255, 255)), (830, 230, (170, 240, 190, 255)), (850, 720, (150, 200, 255, 255)), (640, 800, (190, 160, 255, 255))):
        p.poly([(x - 30, y - 18), (x + 30, y - 30), (x + 34, y + 18), (x - 26, y + 28)], col, w=12)


def item_crystalBlade(p, c):  # 수정 결정 무기: 반투명 자수정 칼날(면 셋) + 금 손잡이
    blade = [(512, 140), (610, 300), (580, 680), (444, 680), (414, 300)]
    p.poly(blade, (196, 160, 244, 255))
    p.poly([(512, 140), (610, 300), (580, 680), (512, 680)], (160, 120, 220, 255), w=0)
    p.poly([(512, 200), (540, 320), (512, 600), (484, 320)], (230, 214, 255, 255), w=0)
    p.d.line(blade + [blade[0]], fill=INK, width=W, joint="curve")
    p.rrect((360, 670, 664, 730), 20, GOLD)
    p.rrect((482, 730, 542, 880), 16, WOOD)
    p.ellipse((470, 860, 554, 940), GOLD)
    sparkle(p, 300, 260, 60)
    sparkle(p, 740, 480, 44)


def item_goldenHammer(p, c):  # 황금 망치: 큰 금 망치 + 내려찍는 반짝 고리
    ring(p, (230, 700, 790, 860), (255, 244, 170, 255), 26)
    hammer(p, 520, 330, 240, (255, 226, 92, 255), (190, 150, 84, 255), -25)
    sparkle(p, 250, 300, 64)
    sparkle(p, 820, 560, 54)


def item_forgeBrazier(p, c):  # 대장간 화로: 무쇠 화로 그릇 + 금노랑 불꽃
    outer = flame_pts(512, 560, 170, 420)
    p.poly(outer, (255, 238, 130, 255))
    p.poly(flame_pts(512, 540, 90, 240), (255, 250, 214, 255), w=18)
    bowl = [(260, 520), (764, 520), (700, 700), (324, 700)]
    p.poly(bowl, (82, 78, 90, 255))
    p.poly([(290, 600), (734, 600), (700, 700), (324, 700)], (60, 56, 66, 255), w=0)
    p.d.line(bowl + [bowl[0]], fill=INK, width=W, joint="curve")
    for x in (360, 664):
        stroke(p, [(x, 700), (x + (-40 if x < 512 else 40), 860)], (82, 78, 90, 255), 30)
    for x, y, r in ((260, 330, 30), (780, 300, 26), (820, 460, 20)):
        p.poly(star_pts(x, y, r * 1.6, 0.42, 4), (255, 236, 110, 255), w=12)


def hand(p, cx, cy, s, flip, col):
    """손바닥(손가락 넷 + 엄지) - flip = 좌우 뒤집기"""
    k = -1 if flip else 1
    p.poly([(cx - k * s * 0.4, cy + s * 0.5), (cx - k * s * 0.45, cy - s * 0.1), (cx + k * s * 0.4, cy - s * 0.15), (cx + k * s * 0.45, cy + s * 0.5)], col)
    for i in range(4):
        x = cx - k * s * 0.33 + k * i * s * 0.24
        p.rrect((x - s * 0.13, cy - s * 0.75 + abs(i - 1.5) * s * 0.08, x + s * 0.13, cy + s * 0.05), s * 0.12, col, w=16)
    tx = cx - k * s * 0.62
    p.rrect((tx - s * 0.14, cy, tx + s * 0.14, cy + s * 0.35), s * 0.12, col, w=16)


def item_highFive(p, c):  # 하이파이브: 두 손바닥이 맞닿는 가운데 별 터짐
    hand(p, 330, 580, 300, False, CREAM)
    hand(p, 694, 580, 300, True, CREAM_D)
    p.poly(star_pts(512, 330, 150, 0.42, 8), (255, 244, 170, 255))
    sparkle(p, 250, 230, 54)
    sparkle(p, 790, 230, 54)


def item_petCrown(p, c):  # 펫 왕관: 금 왕관(뾰족 셋 + 파란 보석) - 강아지 귀 두 개 위에 얹힘
    for x in (300, 724):
        p.poly([(x - 110, 860), (x, 600), (x + 110, 860)], (232, 196, 150, 255))
    crown = [(240, 700), (240, 360), (370, 500), (512, 260), (654, 500), (784, 360), (784, 700)]
    p.poly(crown, (250, 216, 92, 255))
    p.poly([(240, 610), (784, 610), (784, 700), (240, 700)], (226, 186, 66, 255), w=0)
    p.d.line(crown + [crown[0]], fill=INK, width=W, joint="curve")
    gem(p, 512, 560, 64, (120, 190, 255, 255))
    for x, y in ((240, 360), (512, 260), (784, 360)):
        p.ellipse((x - 34, y - 34, x + 34, y + 34), (255, 244, 170, 255), w=14)



# 이름 → (종류, 타일 색, 그리기, 그리기가 img를 받는가)
ICONS = [
    ("theme_starlight", "product", (84, 96, 214), theme_starlight, False),
    ("theme_ember", "product", (238, 212, 62), theme_ember, False),
    ("theme_frost", "product", (120, 206, 232), theme_frost, False),
    ("theme_jelly", "product", (92, 200, 150), theme_jelly, False),
    ("glider_petal", "product", SKY_TILE, glider_petal, False),
    ("glider_kite", "product", SKY_TILE, glider_kite, False),
    ("glider_dragonWing", "product", SKY_TILE, glider_dragonWing, True),
    ("season_premium", "product", (150, 120, 232), season_premium, True),
    ("bagExpand", "pass", (50, 168, 160), bagExpand, False),
    ("pickupRadius", "pass", (86, 186, 96), pickupRadius, True),
    ("recallCooldown", "pass", (64, 150, 230), recallCooldown, False),
    ("nameplateColor", "pass", (140, 92, 226), nameplateColor, True),
    ("nameplateBadge", "pass", (56, 74, 150), nameplateBadge, False),  # QUEUE-STUDIO 0-4: 남색(색 아이콘 보라와 한눈에 구분)
    ("theme_anvil", "product", (120, 132, 156), theme_anvil, False),  # QUEUE-ALL6 H 꾸미기 TOP 10
    ("theme_halloween", "product", (132, 96, 186), theme_halloween, False),
    ("glider_slimeParachute", "product", SKY_TILE, glider_slimeParachute, False),
    ("item_rocketPop", "product", (92, 132, 220), item_rocketPop, False),
    ("item_balloonPop", "product", (120, 190, 210), item_balloonPop, False),
    ("item_crystalBlade", "product", (98, 76, 150), item_crystalBlade, False),
    ("item_goldenHammer", "product", (96, 110, 170), item_goldenHammer, False),
    ("item_forgeBrazier", "product", (100, 92, 120), item_forgeBrazier, False),
    ("item_highFive", "product", (90, 170, 150), item_highFive, False),
    ("item_petCrown", "product", (150, 120, 220), item_petCrown, False),
]


def danger(c):
    """art-direction §3-4 · TrailSkin.check: 주황빨강 330 ~ 50° · 채도 ≥ 0.35 = 위험색(타일 넓은 면 금지)"""
    h, s, v = colorsys.rgb_to_hsv(*(x / 255 for x in c[:3]))
    h *= 360
    return (h >= 330 or h <= 50) and s >= 0.35


def build(name, color, fn, wants_img):
    color = rgba(color)
    assert not danger(color), name + " 타일 색이 위험색"
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = tile(img, color)
    p = Pen(d)
    if wants_img:
        fn(img, p, color)
    else:
        fn(p, color)
    return img.resize((SIZE, SIZE), Image.LANCZOS)


# ── 게임 아이콘 후보(꽉 찬 사각 · 글자 없음) ──
def field(img, horizon=430):
    d = ImageDraw.Draw(img)
    for y in range(S):  # 하늘 그라데이션
        t = y / S
        d.line([(0, y), (S, y)], fill=(int(150 + 70 * t), int(206 + 34 * t), 255, 255))
    for cx, r, col in ((120, 260, (92, 170, 80)), (560, 320, (104, 182, 88)), (980, 280, (92, 170, 80))):  # 먼 언덕
        d.ellipse((cx - r * 1.6, horizon - r * 0.55, cx + r * 1.6, horizon + r), fill=col + (255,))
    # 돌담(석조 평원 돌 #A8A29A · 그늘 #6E6A66)
    x = -40
    k = 0
    while x < S:
        w = 110 + (k * 37) % 50
        top = horizon - 40 - (k * 23) % 30
        d.polygon([(x, horizon + 60), (x + 10, top), (x + w * 0.6, top - 20), (x + w, top + 8), (x + w + 6, horizon + 60)], fill=(168, 162, 154, 255), outline=INK, width=8)
        d.polygon([(x + w * 0.6, top - 20), (x + w, top + 8), (x + w + 6, horizon + 60), (x + w * 0.55, horizon + 60)], fill=(130, 125, 120, 255))
        x += w
        k += 1
    d.rectangle((0, horizon + 50, S, S), fill=(123, 201, 80, 255))  # 바닥 T1 #7BC950
    d.rectangle((0, horizon + 50, S, horizon + 80), fill=hi((123, 201, 80, 255)))
    return d


def tufts(img, spots):
    d = ImageDraw.Draw(img)
    for x, y, s in spots:
        for dx, h, lean in ((-30, 1.0, -0.35), (0, 1.3, 0.05), (30, 0.95, 0.4)):
            bx = x + dx * s
            pts = [(bx - 14 * s, y), (bx + lean * 90 * s, y - 120 * h * s), (bx + 14 * s, y)]
            d.polygon(pts, fill=(86, 170, 70, 255), outline=INK, width=max(4, int(8 * s)))
            d.polygon([pts[1], pts[2], (bx, y)], fill=(70, 140, 58, 255))


def frame(img):
    d = ImageDraw.Draw(img)
    m = Image.new("L", (S, S), 255)
    ImageDraw.Draw(m).rounded_rectangle((44, 44, S - 44, S - 44), radius=110, fill=0)
    img.paste(INK, (0, 0, S, S), m)
    d.rounded_rectangle((44, 44, S - 44, S - 44), radius=110, outline=(255, 214, 92, 255), width=12)


def beam(img, cx, top, bottom, w):
    lay = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    for i in range(10, 0, -1):
        ww = w * i / 10
        d.rectangle((cx - ww, top, cx + ww, bottom), fill=(255, 240, 150, int(30 + 12 * (10 - i))))
    d.rectangle((cx - w * 0.22, top, cx + w * 0.22, bottom), fill=(255, 252, 226, 230))
    img.alpha_composite(lay.filter(ImageFilter.GaussianBlur(18)))


def glow_ring(img, box, col=(255, 240, 120)):
    lay = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    d.ellipse(box, fill=col + (170,))
    x0, y0, x1, y1 = box
    d.ellipse((x0 + 60, y0 + 20, x1 - 60, y1 - 20), fill=(255, 252, 220, 210))
    img.alpha_composite(lay.filter(ImageFilter.GaussianBlur(10)))


def bust_crop(im, top, bottom, width):
    """원본 렌더에서 알파가 있는 곳 기준 세로 top ~ bottom 비율만 잘라 폭 width로 키운다"""
    x0, y0, x1, y1 = im.getbbox()
    h = y1 - y0
    part = im.crop((x0, y0 + int(h * top), x1, y0 + int(h * bottom)))
    k = width / part.width
    return part.resize((int(part.width * k), int(part.height * k)), Image.LANCZOS)


def game_icon(kind, hero, slime):
    img = Image.new("RGBA", (S, S), (0, 0, 0, 255))
    if kind == "A":  # 풀밭: 전신 + 곁의 이끼 슬라임 + 풀 덤불
        field(img, 420)
        tufts(img, [(140, 640, 1.1), (900, 600, 0.9), (260, 900, 1.2)])
        soft_shadow(img, (330, 860, 790, 960))
        place(img, slime, (110, 640, 420, 920))
        place(img, hero, (300, 150, 830, 930))
        tufts(img, [(820, 960, 1.0), (120, 980, 0.9)])
    elif kind == "B":  # 빛기둥: 발밑 빛 고리 + 하늘로 뻗는 금빛 기둥(전설 드랍 연출)
        field(img, 400)
        beam(img, 560, 0, 900, 190)
        tufts(img, [(150, 660, 1.1), (210, 900, 1.2)])
        glow_ring(img, (300, 800, 820, 960))
        place(img, hero, (320, 170, 800, 920))
        for x, y, r in ((300, 300, 40), (800, 240, 32), (850, 560, 26), (250, 560, 24)):
            ImageDraw.Draw(img).polygon(star_pts(x, y, r * 1.8, 0.3, 4), fill=(255, 250, 214, 255), outline=INK, width=8)
    elif kind == "D":  # QUEUE-STUDIO 0-4: C 구도(얼굴 가까이) + 초월(흑금) 대검을 치켜듦 + 뒤 빛기둥
        field(img, 600)
        beam(img, 400, 0, S, 210)
        lay = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        d = ImageDraw.Draw(lay)
        for i in range(12):  # 기둥 둘레 옅은 방사 빛살(C와 같은 빛살 - 더 옅게)
            a = math.radians(i * 30 + 8)
            d.polygon([(400, 300), (400 + 900 * math.cos(a - 0.08), 300 + 900 * math.sin(a - 0.08)), (400 + 900 * math.cos(a + 0.08), 300 + 900 * math.sin(a + 0.08))], fill=(255, 250, 220, 50))
        img.alpha_composite(lay.filter(ImageFilter.GaussianBlur(6)))
        bust = bust_crop(hero, 0.0, 0.66, 1180)  # 칼끝은 위로 나가도 된다 - 얼굴이 가운데 아래
        img.alpha_composite(bust, ((S - bust.width) // 2 - 10, S - bust.height + 20))
        for x, y, r in ((170, 300, 30), (880, 210, 26), (900, 520, 20)):
            ImageDraw.Draw(img).polygon(star_pts(x, y, r * 1.8, 0.3, 4), fill=(255, 236, 150, 255), outline=INK, width=8)
    else:  # 근접: 상반신 · 쌍검이 화면 아래로
        field(img, 520)
        lay = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        d = ImageDraw.Draw(lay)
        for i in range(12):  # 뒤 방사 빛살
            a = math.radians(i * 30 + 8)
            d.polygon([(512, 420), (512 + 900 * math.cos(a - 0.09), 420 + 900 * math.sin(a - 0.09)), (512 + 900 * math.cos(a + 0.09), 420 + 900 * math.sin(a + 0.09))], fill=(255, 250, 220, 70))
        img.alpha_composite(lay.filter(ImageFilter.GaussianBlur(6)))
        bust = hero.crop((0, 0, hero.width, int(hero.height * 0.68)))
        k = 1000 / bust.width
        bust = bust.resize((int(bust.width * k), int(bust.height * k)), Image.LANCZOS)
        img.alpha_composite(bust, ((S - bust.width) // 2, S - bust.height + 60))
    frame(img)
    return img.convert("RGB").resize((SIZE, SIZE), Image.LANCZOS).convert("RGBA")


def sheet(made, path):
    cols, cell, pad = 8, 180, 12
    rows = (len(made) + cols - 1) // cols
    W_ = cols * (cell + pad) + pad
    out = Image.new("RGBA", (W_, rows * 2 * (cell + pad) + pad), (0, 0, 0, 255))
    for half, bg in ((0, (128, 128, 128, 255)), (1, (34, 32, 44, 255))):
        ImageDraw.Draw(out).rectangle((0, half * rows * (cell + pad), W_, (half + 1) * rows * (cell + pad) + pad), fill=bg)
        for i, (_, im) in enumerate(made):
            x = pad + (i % cols) * (cell + pad)
            y = pad + half * rows * (cell + pad) + (i // cols) * (cell + pad)
            small = im.resize((150, 150), Image.LANCZOS)  # 150px 읽힘 확인(상점 칸 크기)
            out.alpha_composite(small, (x + 15, y + 15))
    out.save(path)


def check(name, im, full):
    assert im.size == (SIZE, SIZE) and im.mode == "RGBA", name
    if not full:
        for xy in ((0, 0), (SIZE - 1, 0), (0, SIZE - 1), (SIZE - 1, SIZE - 1)):
            assert im.getpixel(xy)[3] == 0, name + " 모서리 불투명"


def main():
    os.makedirs(OUT, exist_ok=True)
    made = []
    for name, kind, color, fn, wants_img in ICONS:
        im = build(name, color, fn, wants_img)
        check(name, im, False)
        im.save(os.path.join(OUT, name + ".png"))
        made.append((name, im))
    hero, slime, raised = model("hero"), model("slime"), model("hero_raise")
    for k in ("A", "B", "C", "D"):
        im = game_icon(k, raised if k == "D" else hero, slime)
        check(k, im, True)
        im.save(os.path.join(OUT, "game_icon_blender_%s.png" % k))
        made.append(("game_icon_blender_" + k, im))
    sheet(made, os.path.join(OUT, "_sheet.png"))
    print("store icons", len(made), OUT)


if __name__ == "__main__":
    main()
