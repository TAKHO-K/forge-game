# -*- coding: utf-8 -*-
# QUEUE-ALL2 UI 아이콘 v2(PIL): 기준 = docs/art/ref/16 · 17 · 18 + make_hud_icons.py 스타일(1024로 그려 줄임 · 3톤 · 굵은 외곽선 #1E1B2E).
#   A 스킬(직업색 타일)    → roblox/art/icons/skills/<직업>_<q|e|r|t>.png · dash_<직업>.png
#   B HUD 메뉴(없는 것만)  → roblox/art/icons/hud/<이름>.png(이미 있는 파일은 덮어쓰지 않는다)
#   C 도감 탭(둥근 타일)   → roblox/art/icons/codex/tab_<id>.png
#   D 보상 · 재화(타일 X)  → roblox/art/icons/reward/<id>.png + _map.json
#   E 길 안내 · F 지도 핀 · G 대상 원 · 자물쇠 배지 → roblox/art/icons/ui/
#   금지 색(make_hud_icons.py와 같음): 강한 주황 · 빨강 넓은 면(보스 경고) · 흰 + 자홍 · 검정 + 금. 그림 안 글자 없음.
# 실행: python roblox/tools/icons/make_ui_icons_v2.py [--preview 파일.png]
import json
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_hud_icons as H  # noqa: E402
from make_hud_icons import INK, S, W, WHITE, Pen, lighten, mul, tile  # noqa: E402

ART = os.path.normpath(os.path.join(HERE, "..", "..", "art", "icons"))

GOLD, GOLD_D = (255, 214, 92, 255), (214, 150, 40, 255)
STEEL, STEEL_D = (214, 222, 238, 255), (120, 130, 160, 255)
WOOD = (140, 92, 58, 255)
CREAM, CREAM_D = (252, 238, 206, 255), (214, 180, 120, 255)
SKIN = (255, 226, 196, 255)
LEAF = (86, 190, 96, 255)

# 직업색(스킬 타일) - 전사 파랑 · 도적 보라 · 궁수 초록 · 치유사 금노랑
CLASS_COLOR = {"greatsword": (74, 128, 226), "dualblade": (140, 92, 226), "bow": (78, 176, 90), "healer": (232, 186, 60)}


# ── 벡터 · 도형 도우미 ──
def unit(a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    n = math.hypot(dx, dy) or 1
    return dx / n, dy / n


def at(p, u, k, v=(0, 0), j=0):
    return (p[0] + u[0] * k + v[0] * j, p[1] + u[1] * k + v[1] * j)


def stroke(p, pts, color, w):
    p.line(pts, INK, int(w + 2 * W))
    p.line(pts, color, int(w))


def arcpts(cx, cy, rx, a0, a1, ry=None, n=48):
    ry = rx if ry is None else ry
    return [(cx + rx * math.cos(math.radians(a0 + (a1 - a0) * i / n)), cy + ry * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def star_pts(cx, cy, r, k=0.45, n=5, rot=-90):
    return [(cx + r * (1 if i % 2 == 0 else k) * math.cos(math.radians(rot + i * 180 / n)),
             cy + r * (1 if i % 2 == 0 else k) * math.sin(math.radians(rot + i * 180 / n))) for i in range(2 * n)]


def sparkle(p, cx, cy, r, color=WHITE, w=14):
    p.poly(star_pts(cx, cy, r, 0.3, 4), color, w=w)


def ring(p, box, color, w):
    x0, y0, x1, y1 = box
    p.d.ellipse((x0 - W, y0 - W, x1 + W, y1 + W), outline=INK, width=w + 2 * W)
    p.d.ellipse(box, outline=color, width=w)


def motion_arrow(p, pts, color, w, hs):
    a, b = pts[-2], pts[-1]
    u = unit(a, b)
    v = (-u[1], u[0])
    base = at(b, u, -hs * 0.85)
    stroke(p, pts[:-1] + [base], color, w)
    p.poly([b, at(base, v, hs * 0.75), at(base, v, -hs * 0.75)], color)


def real_arrow(p, a, b, head=STEEL, fl=WHITE, w=30, hs=110):
    u = unit(a, b)
    v = (-u[1], u[0])
    for s in (1, -1):
        p.poly([at(a, u, 20), at(a, u, 130), at(a, u, 90, v, s * 62), at(a, u, -10, v, s * 62)], fl)
    base = at(b, u, -hs)
    stroke(p, [at(a, u, 30), base], WOOD, w)
    p.poly([b, at(base, u, -18, v, hs * 0.55), at(base, u, 22), at(base, u, -18, v, -hs * 0.55)], head)


def sword(p, P, T, bw, blade=STEEL, dark=STEEL_D, guard=GOLD, grip=WOOD, hilt=0.24, gw=2.4):
    L = math.hypot(T[0] - P[0], T[1] - P[1])
    u = unit(P, T)
    v = (-u[1], u[0])
    g = at(P, u, L * hilt)
    stroke(p, [P, g], grip, bw * 0.8)
    tb = at(T, u, -bw * 1.7)
    pts = [at(g, v, bw), at(tb, v, bw), T, at(tb, v, -bw), at(g, v, -bw)]
    p.d.polygon(pts, fill=blade)
    p.d.polygon([g, T, at(tb, v, -bw), at(g, v, -bw)], fill=dark)
    p.d.line(pts + [pts[0]], fill=INK, width=W, joint="curve")
    for q in pts:
        p.d.ellipse((q[0] - W / 2, q[1] - W / 2, q[0] + W / 2, q[1] + W / 2), fill=INK)
    gl, gt = bw * gw, bw * 0.42
    p.poly([at(g, u, -gt, v, gl), at(g, u, gt, v, gl), at(g, u, gt, v, -gl), at(g, u, -gt, v, -gl)], guard)
    c = at(P, u, -bw * 0.15)
    r = bw * 0.6
    p.ellipse((c[0] - r, c[1] - r, c[0] + r, c[1] + r), guard)


def figure(p, cx, cy, s, body, head=SKIN):
    p.d.pieslice((cx - s, cy, cx + s, cy + s * 2.1), 180, 360, fill=body, outline=INK, width=W)
    r = s * 0.55
    p.ellipse((cx - r, cy - r * 1.9 - 10, cx + r, cy + r * 0.1 - 10), head)


def shield_pts(cx, cy, w, h):
    pts = [(cx - w, cy - h * 0.55), (cx, cy - h * 0.75), (cx + w, cy - h * 0.55)]
    for i in range(1, 17):
        t = i / 16
        pts.append((cx + w * (1 - t) ** 0.9 * math.cos(t * 0.9), cy - h * 0.55 + (h * 1.4) * math.sin(t * math.pi / 2)))
    pts[-1] = (cx, cy + h * 0.85)
    left = [(2 * cx - x, y) for x, y in reversed(pts[3:-1])]
    return pts + left


def egg_pts(cx, cy, rx, ry, n=64):
    return [(cx + rx * math.cos(2 * math.pi * i / n) * (1 + 0.14 * math.sin(2 * math.pi * i / n)), cy + ry * math.sin(2 * math.pi * i / n)) for i in range(n)]


def horn(p, base, ctrl, tip, w0, color):
    left, right = [], []
    for i in range(21):
        t = i / 20
        x = (1 - t) ** 2 * base[0] + 2 * (1 - t) * t * ctrl[0] + t * t * tip[0]
        y = (1 - t) ** 2 * base[1] + 2 * (1 - t) * t * ctrl[1] + t * t * tip[1]
        dx = 2 * (1 - t) * (ctrl[0] - base[0]) + 2 * t * (tip[0] - ctrl[0])
        dy = 2 * (1 - t) * (ctrl[1] - base[1]) + 2 * t * (tip[1] - ctrl[1])
        n = math.hypot(dx, dy) or 1
        hw = w0 * (1 - t * 0.95)
        left.append((x - dy / n * hw, y + dx / n * hw))
        right.append((x + dy / n * hw, y - dx / n * hw))
    p.poly(left + right[::-1], color)


def crystal(p, cx, cy, s, c):
    o = [(cx, cy - 1.0 * s), (cx + 0.46 * s, cy - 0.5 * s), (cx + 0.46 * s, cy + 0.5 * s), (cx, cy + 1.0 * s), (cx - 0.46 * s, cy + 0.5 * s), (cx - 0.46 * s, cy - 0.5 * s)]
    p.d.polygon(o, fill=c)
    p.d.polygon([o[0], (cx + 0.14 * s, cy - 0.5 * s), (cx + 0.14 * s, cy + 0.5 * s), o[3], (cx - 0.14 * s, cy + 0.5 * s), (cx - 0.14 * s, cy - 0.5 * s)], fill=lighten(c, 0.45))
    p.d.polygon([o[5], (cx - 0.14 * s, cy - 0.5 * s), (cx - 0.14 * s, cy + 0.5 * s), o[4]], fill=mul(c, 0.7))
    for a, b in (((cx - 0.14 * s, cy - 0.5 * s), (cx - 0.14 * s, cy + 0.5 * s)), ((cx + 0.14 * s, cy - 0.5 * s), (cx + 0.14 * s, cy + 0.5 * s))):
        p.d.line([a, b], fill=INK, width=int(W * 0.5))
    p.d.line(o + [o[0]], fill=INK, width=W, joint="curve")
    for q in o:
        p.d.ellipse((q[0] - W / 2, q[1] - W / 2, q[0] + W / 2, q[1] + W / 2), fill=INK)


def cross(p, cx, cy, a, b, color):
    p.poly([(cx - b, cy - a), (cx + b, cy - a), (cx + b, cy - b), (cx + a, cy - b), (cx + a, cy + b), (cx + b, cy + b), (cx + b, cy + a),
            (cx - b, cy + a), (cx - b, cy + b), (cx - a, cy + b), (cx - a, cy - b), (cx - b, cy - b)], color)


def ticket(p, box, color):
    x0, y0, x1, y1 = box
    r = 50
    cy = (y0 + y1) / 2
    pts = [(x0, y0), (x1, y0), (x1, cy - r)] + arcpts(x1, cy, r, 270, 90, n=16)[::-1][1:-1] + [(x1, cy + r), (x1, y1), (x0, y1), (x0, cy + r)] + arcpts(x0, cy, r, 90, -90, n=16)[1:-1] + [(x0, cy - r)]
    p.poly(pts, color)
    for y in range(int(y0 + 50), int(y1 - 30), 60):
        p.d.line([(x0 + 140, y), (x0 + 140, y + 28)], fill=mul(color, 0.6), width=14)


# ── A 스킬 기호(타일 가운데 ≈ (512, 480)) ──
def gs_q(p, c):  # 관통돌진: 앞으로 찌르는 대검 + 뒤 속도선 + 끝 충격
    P, T = (250, 690), (760, 330)
    p.poly(star_pts(790, 305, 120, 0.5, 6), (255, 240, 170, 255))
    u = unit(P, T)
    v = (-u[1], u[0])
    for off, ln in ((-130, 150), (0, 0), (120, 190)):
        if ln:
            a = at(P, u, 60, v, off)
            stroke(p, [a, at(a, u, -ln)], lighten(c, 0.7), 32)
    sword(p, P, T, 64)


def gs_e(p, c):  # 회전베기: 둥근 휘두름 두 줄 + 가운데 대검
    col = lighten(c, 0.6)
    motion_arrow(p, arcpts(512, 490, 300, 200, 335), col, 48, 120)
    motion_arrow(p, arcpts(512, 490, 300, 20, 155), col, 48, 120)
    sword(p, (390, 650), (650, 300), 56)


def gs_r(p, c):  # 전장의 포효: 뿔나팔 + 소리 물결
    left, right = [], []
    A, C, E = (250, 740), (270, 470), (500, 430)
    for i in range(25):
        t = i / 24
        x = (1 - t) ** 2 * A[0] + 2 * (1 - t) * t * C[0] + t * t * E[0]
        y = (1 - t) ** 2 * A[1] + 2 * (1 - t) * t * C[1] + t * t * E[1]
        dx = 2 * (1 - t) * (C[0] - A[0]) + 2 * t * (E[0] - C[0])
        dy = 2 * (1 - t) * (C[1] - A[1]) + 2 * t * (E[1] - C[1])
        n = math.hypot(dx, dy)
        r = 28 + 130 * t ** 1.8
        left.append((x - dy / n * r, y + dx / n * r))
        right.append((x + dy / n * r, y - dx / n * r))
    p.poly(left + right[::-1], (244, 232, 204, 255))
    for t0 in (0.35, 0.7):
        i = int(t0 * 24)
        stroke(p, [left[i], right[i]], GOLD, 30)
    p.ellipse((E[0] - 50, E[1] - 160, E[0] + 50, E[1] + 160), mul((244, 232, 204, 255), 0.75))
    for r in (150, 240, 330):
        stroke(p, arcpts(E[0] + 20, E[1], r, -38, 38, n=20), WHITE, 34)


def gs_t(p, c):  # 파괴의 화신: 꽂힌 거대 대검 + 뒤 폭발 빛
    p.poly(star_pts(512, 430, 360, 0.62, 12), (255, 236, 150, 255))
    p.poly(star_pts(512, 430, 230, 0.6, 12), (255, 250, 220, 255), w=0)
    sword(p, (512, 820), (512, 170), 78, gw=2.8)


def db_q(p, c):  # 그림자분신: 앞 캐릭터 + 뒤 그림자 분신(눈만 빛남)
    sh = mul(c, 0.42)
    figure(p, 620, 430, 150, sh, head=sh)
    for x in (585, 650):
        p.d.ellipse((x - 22, 320, x + 22, 345), fill=(236, 220, 255, 255))
    figure(p, 400, 500, 160, lighten(c, 0.45))
    for x0, y0 in ((170, 440), (190, 560)):
        stroke(p, [(x0, y0), (x0 + 60, y0)], lighten(c, 0.7), 26)


def db_e(p, c):  # 난무: 교차 단검 + 방사 베기선
    for a, ln in ((-60, 330), (-15, 360), (30, 330), (150, 330), (195, 360), (240, 330)):
        u = (math.cos(math.radians(a)), math.sin(math.radians(a)))
        stroke(p, [at((512, 480), u, 250), at((512, 480), u, ln + 30)], lighten(c, 0.75), 26)
    sword(p, (330, 700), (690, 290), 46, gw=2.0)
    sword(p, (694, 700), (334, 290), 46, gw=2.0)


def db_r(p, c):  # 암영 표식: 조준 원 + 가운데 표식 + 꽂히는 단검
    ring(p, (282, 250, 742, 710), lighten(c, 0.6), 40)
    for a in (0, 90, 180, 270):
        u = (math.cos(math.radians(a)), math.sin(math.radians(a)))
        stroke(p, [at((512, 480), u, 190), at((512, 480), u, 290)], lighten(c, 0.6), 36)
    p.poly([(512, 400), (592, 480), (512, 560), (432, 480)], (255, 220, 110, 255))
    sword(p, (800, 180), (560, 430), 44, gw=2.0)


def db_t(p, c):  # 죽음의 계약: 계약서 + 보라 봉인 + 뒤 단검
    sword(p, (230, 230), (790, 790), 44, gw=2.0)
    p.rrect((320, 280, 700, 760), 30, CREAM)
    p.rrect((290, 230, 730, 320), 45, CREAM_D)
    p.rrect((290, 720, 730, 810), 45, CREAM_D)
    for y in (400, 470, 540):
        p.line([(380, y), (600, y)], mul(CREAM_D, 0.7), 22)
    p.ellipse((520, 540, 720, 740), mul(c, 0.75))
    p.poly(star_pts(620, 640, 70, 0.45), lighten(c, 0.7), w=12)


def bow_q(p, c):  # 강궁: 당긴 활 + 굵은 화살
    limb = (176, 116, 66, 255)
    top, bot = (330, 210), (330, 770)
    stroke(p, [top] + arcpts(520, 490, 300, 222, 138)[1:-1] + [bot], limb, 52)
    p.line([top, (470, 490), bot], INK, 12)
    real_arrow(p, (430, 490), (870, 490), w=40, hs=140, fl=lighten(c, 0.6))
    for y in (400, 580):
        stroke(p, [(640, y), (760, y)], WHITE, 22)


def bow_e(p, c):  # 백스텝샷: 앞으로 쏘는 화살 + 뒤로 물러나는 곡선 화살표
    real_arrow(p, (250, 380), (820, 300), fl=lighten(c, 0.6))
    motion_arrow(p, arcpts(560, 560, 200, 350, 170)[::1], lighten(c, 0.65), 56, 130)


def bow_r(p, c):  # 사냥꾼의 덫: 벌린 쇠 턱 + 큰 이빨
    p.ellipse((200, 650, 824, 830), (70, 64, 96, 255))
    for a0, a1 in ((178, 262), (278, 362)):
        pts = arcpts(512, 660, 280, a0, a1, n=30)
        for i in (4, 12, 20, 27):
            q = pts[i]
            u = unit(q, (512, 660))
            v = (-u[1], u[0])
            p.poly([at(q, v, 44), at(q, u, 120), at(q, v, -44)], WHITE, w=18)
        stroke(p, pts, STEEL, 60)
    p.ellipse((447, 680, 577, 810), GOLD)
    for i, (x, y) in enumerate(((680, 800), (760, 760), (840, 800))):  # 사슬
        box = (x - 50, y - 30, x + 50, y + 30) if i % 2 == 0 else (x - 30, y - 50, x + 30, y + 50)
        ring(p, box, STEEL, 20)


def bow_t(p, c):  # 천궁의 폭우: 구름 + 쏟아지는 화살
    for i, x in enumerate((250, 400, 550, 700)):
        y = 400 + (i % 2) * 70
        real_arrow(p, (x, y), (x + 90, y + 360), w=26, hs=90, fl=lighten(c, 0.6))
    cl = lighten(c, 0.85)
    for x, y, r in ((330, 300, 110), (512, 240, 150), (690, 300, 110), (430, 330, 100), (600, 330, 100)):
        p.ellipse((x - r, y - r, x + r, y + r), cl)
    p.d.rectangle((330, 300, 690, 400), fill=cl)
    p.d.line([(330, 410), (690, 410)], fill=INK, width=W)


def hl_q(p, c):  # 치유: 방패 + 흰 십자 + 반짝
    p.poly(shield_pts(512, 470, 250, 360), lighten(c, 0.55))
    cross(p, 512, 480, 170, 62, (96, 200, 110, 255))
    sparkle(p, 800, 250, 70)
    sparkle(p, 230, 700, 55)


def hl_e(p, c):  # 딜링모드: 지팡이 + 구슬 + 번개
    stroke(p, [(300, 820), (590, 380)], WOOD, 46)
    p.ellipse((520, 220, 720, 420), (170, 140, 255, 255))
    p.ellipse((560, 250, 640, 320), (230, 220, 255, 255), w=0)
    p.poly([(700, 420), (820, 470), (740, 540), (840, 700), (660, 560), (730, 520), (640, 460)], (255, 244, 150, 255))


def hl_r(p, c):  # 구원의 기도: 날개 + 후광 + 빛 구슬
    feathers = []
    for s in (1, -1):
        root = (512 + s * 50, 540)
        for ang, ln in ((-15, 300), (-42, 280), (-70, 230)):
            a = math.radians(ang)
            feathers.append((root, (root[0] + s * ln * math.cos(a), root[1] + ln * math.sin(a))))
    for r, t in feathers:
        stroke(p, [r, t], WHITE, 88)
    for r, t in feathers:
        p.line([r, t], lighten(c, 0.75), 26)
    p.ellipse((412, 440, 612, 640), lighten(c, 0.6))
    cross(p, 512, 540, 60, 20, WHITE)
    ring(p, (362, 180, 662, 280), GOLD, 34)


def hl_t(p, c):  # 생명의 성역: 바닥 마법진 + 빛 돔 + 새싹
    p.ellipse((170, 600, 854, 820), lighten(c, 0.5))
    p.d.ellipse((260, 640, 764, 780), outline=mul(c, 0.7), width=18)
    stroke(p, arcpts(512, 700, 300, 180, 360, ry=470), WHITE, 32)
    stroke(p, [(512, 700), (512, 470)], (60, 140, 70, 255), 30)
    p.poly([(512, 540), (380, 450), (330, 350), (450, 380)], LEAF)
    p.poly([(512, 500), (640, 390), (720, 290), (590, 320)], lighten(LEAF, 0.2))
    sparkle(p, 300, 300, 50)
    sparkle(p, 760, 520, 45)


def dash(p, c):  # 대시: 두 겹 꺾쇠 + 속도선
    for x in (430, 620):
        stroke(p, [(x - 110, 290), (x + 90, 480), (x - 110, 670)], WHITE, 70)
    for y, x0 in ((360, 170), (480, 130), (600, 170)):
        stroke(p, [(x0, y), (x0 + 110, y)], lighten(c, 0.6), 30)


SKILLS = {
    "greatsword": {"q": gs_q, "e": gs_e, "r": gs_r, "t": gs_t},
    "dualblade": {"q": db_q, "e": db_e, "r": db_r, "t": db_t},
    "bow": {"q": bow_q, "e": bow_e, "r": bow_r, "t": bow_t},
    "healer": {"q": hl_q, "e": hl_e, "r": hl_r, "t": hl_t},
}


# ── B HUD 새 기호(make_hud_icons.py에 없는 것) ──
def training(p, c):  # 수련: 아령 + 오르는 화살표
    stroke(p, [(270, 560), (754, 560)], STEEL, 50)
    for s in (1, -1):
        x = 512 + s * 180
        p.rrect((x - 40, 400, x + 40, 720), 26, STEEL_D)
        x2 = 512 + s * 250
        p.rrect((x2 - 34, 440, x2 + 34, 680), 22, mul(STEEL_D, 0.8))
    motion_arrow(p, [(512, 460), (512, 230)], WHITE, 50, 120)


def zone_select(p, c):  # 구역 선택: 갈림 표지판
    stroke(p, [(512, 260), (512, 810)], WOOD, 50)
    p.poly([(300, 300), (680, 300), (760, 370), (680, 440), (300, 440)], CREAM)
    p.poly([(724, 490), (344, 490), (264, 560), (344, 630), (724, 630)], lighten(c, 0.55))
    p.ellipse((482, 230, 542, 290), GOLD, w=16)


def character(p, c):  # 캐릭터: 투구 앞모습 + 깃털
    p.poly([(512, 180), (600, 200), (640, 270), (540, 300), (470, 250)], lighten(c, 0.5))
    p.d.chord((270, 260, 754, 760), 180, 360, fill=STEEL, outline=INK, width=W)
    p.poly([(270, 510), (754, 510), (740, 760), (590, 790), (512, 700), (434, 790), (284, 760)], STEEL)
    p.poly([(512, 260), (560, 300), (560, 520), (464, 520), (464, 300)], mul(STEEL, 0.85), w=0)
    p.rrect((320, 520, 704, 590), 30, (60, 56, 84, 255))
    p.rrect((476, 590, 548, 700), 20, STEEL_D)


def friend_invite(p, c):  # 친구 초대: 사람 + 더하기 배지
    figure(p, 440, 470, 190, (92, 156, 240, 255))
    p.ellipse((560, 520, 820, 780), (90, 190, 100, 255))
    cross(p, 690, 650, 80, 26, WHITE)


def attendance(p, c):  # 출석: 달력 + 체크
    p.rrect((270, 290, 754, 800), 50, CREAM)
    p.rrect((270, 290, 754, 420), 50, mul(c, 0.8))
    p.d.rectangle((270 + W // 2, 380, 754 - W // 2, 420), fill=mul(c, 0.8))
    p.d.line([(270, 420), (754, 420)], fill=INK, width=W)
    for x in (380, 644):
        p.rrect((x - 24, 230, x + 24, 340), 20, STEEL)
    for i in range(3):
        for j in range(4):
            p.d.ellipse((330 + j * 110 - 16, 480 + i * 100 - 16, 330 + j * 110 + 16, 480 + i * 100 + 16), fill=CREAM_D)
    stroke(p, [(390, 610), (480, 700), (660, 480)], (70, 180, 90, 255), 56)


def more(p, c):  # 더보기: 점 세 개
    for x in (322, 512, 702):
        p.ellipse((x - 70, 420, x + 70, 560), WHITE)


HUD_NEW = {
    "training": ((86, 194, 106), training), "zone_select": ((40, 170, 150), zone_select), "character": ((92, 140, 230), character),
    "friend_invite": ((240, 120, 104), friend_invite), "attendance": ((98, 146, 232), attendance), "more": ((140, 146, 170), more),
    # recall = 기존 return.png(귀환) 재사용 - 덮어쓰지 않는다
}


# ── C 도감 탭(둥근 타일 · 가운데 (512, 500)) ──
def disc(img, color):
    d = ImageDraw.Draw(img)
    d.ellipse((70, 70, 954, 994), fill=INK)
    d.ellipse((100, 130, 924, 964), fill=mul(color, 0.72))
    d.ellipse((100, 100, 924, 924), fill=color)
    d.ellipse((270, 140, 754, 330), fill=lighten(color, 0.25))
    d.ellipse((100, 100, 924, 924), outline=INK, width=W)
    return d


def t_equipment(p, c):
    p.poly([(380, 280), (450, 300), (512, 340), (574, 300), (644, 280), (760, 360), (700, 480), (660, 460), (660, 760), (364, 760), (364, 460), (324, 480), (264, 360)], STEEL)
    p.poly([(512, 340), (574, 300), (644, 280), (660, 460), (660, 760), (512, 760)], mul(STEEL, 0.85), w=0)
    p.d.line([(512, 340), (512, 760)], fill=INK, width=18)
    p.rrect((364, 560, 660, 620), 10, GOLD)


def t_pet(p, c):
    H.pet(p, c)


def t_explore(p, c):
    p.poly(egg_pts(512, 430, 150, 200), CREAM)
    for x, y, r in ((460, 380, 30), (560, 440, 36), (500, 520, 24)):
        p.d.ellipse((x - r, y - r, x + r, y + r), fill=(90, 180, 200, 255))
    p.d.chord((230, 420, 794, 780), 0, 180, fill=(170, 120, 70, 255), outline=INK, width=W)
    p.d.line([(230, 600), (794, 600)], fill=INK, width=W)
    for x0, x1 in ((300, 460), (420, 600), (560, 720)):
        p.d.line([(x0, 660), (x1, 700)], fill=(120, 80, 48, 255), width=18)


def t_monster(p, c):
    body = (130, 214, 250, 255)
    p.poly(arcpts(512, 700, 270, 180, 360, ry=400) + [(782, 700), (242, 700)], body)
    p.d.ellipse((330, 360, 420, 440), fill=lighten(body, 0.6))
    for x in (440, 590):
        p.ellipse((x - 36, 500, x + 36, 590), INK, w=0)
        p.d.ellipse((x - 16, 512, x + 4, 536), fill=WHITE)


def t_boss(p, c):
    bone = (244, 232, 204, 255)
    horn(p, (330, 560), (220, 420), (250, 230), 60, bone)
    horn(p, (694, 560), (804, 420), (774, 230), 60, bone)
    p.poly([(300, 720), (300, 420), (400, 540), (512, 360), (624, 540), (724, 420), (724, 720)], GOLD)
    p.rrect((280, 660, 744, 770), 26, GOLD_D)
    p.ellipse((472, 520, 552, 600), (140, 200, 255, 255), w=16)


def t_class(p, c):
    sword(p, (300, 760), (700, 290), 46, gw=2.0)
    sword(p, (724, 760), (324, 290), 46, gw=2.0)


def t_rewards(p, c):
    box = (240, 190, 110, 255)
    p.rrect((280, 440, 744, 780), 30, box)
    p.rrect((250, 360, 774, 470), 30, lighten(box, 0.2))
    p.rrect((470, 360, 554, 780), 10, GOLD)
    for s in (1, -1):
        p.poly([(512, 360), (512 + s * 170, 240), (512 + s * 200, 330), (512 + s * 60, 370)], GOLD)


def t_title(p, c):
    rib = (100, 150, 240, 255)
    p.poly([(420, 560), (360, 820), (430, 780), (480, 840), (512, 600)], rib)
    p.poly([(604, 560), (664, 820), (594, 780), (544, 840), (512, 600)], mul(rib, 0.8))
    p.poly(star_pts(512, 460, 230, 0.78, 12), GOLD)
    p.ellipse((382, 330, 642, 590), GOLD_D)
    p.poly(star_pts(512, 462, 90, 0.45), WHITE, w=14)


CODEX = {
    "equipment": ((124, 132, 168), t_equipment), "pet": ((242, 178, 116), t_pet), "explore": ((57, 194, 214), t_explore),
    "monster": ((86, 194, 106), t_monster), "boss": ((155, 92, 240), t_boss), "class": ((92, 140, 230), t_class),
    "rewards": ((245, 195, 59), t_rewards), "title": ((240, 120, 104), t_title),
}


# ── D 보상 · 재화(타일 없음 - 그린 뒤 알맞게 맞춤) ──
def r_gold(p):
    for i in range(4):
        y = 700 - i * 60
        p.ellipse((200, y - 70, 520, y + 70), GOLD_D)
    p.ellipse((380, 300, 800, 720), GOLD)
    p.ellipse((450, 370, 730, 650), GOLD_D, w=16)
    p.poly(star_pts(590, 510, 100, 0.45), (255, 240, 170, 255), w=14)


def r_stone(c, big=False):
    def f(p):
        if big:
            crystal(p, 330, 600, 190, mul(c, 0.9))
            crystal(p, 700, 600, 190, mul(c, 0.9))
        else:
            crystal(p, 340, 640, 150, mul(c, 0.9))
        crystal(p, 512, 480, 330, c)
        sparkle(p, 700, 230, 70 if big else 55)
        if big:
            sparkle(p, 290, 300, 55)
    return f


def r_egg(p):
    p.poly(egg_pts(512, 500, 260, 340), CREAM)
    for x, y, r in ((420, 380, 50), (600, 460, 60), (470, 620, 44), (640, 660, 34)):
        p.d.ellipse((x - r, y - r, x + r, y + r), fill=(96, 176, 110, 255))
    p.d.ellipse((380, 250, 450, 330), fill=WHITE)


def r_sparkle(p):
    p.poly(star_pts(512, 500, 360, 0.36, 4), (150, 228, 255, 255))
    p.poly(star_pts(512, 500, 200, 0.4, 4), (225, 248, 255, 255), w=0)
    sparkle(p, 790, 230, 70)
    sparkle(p, 230, 780, 55)


def r_dust(p):
    heap = (206, 180, 240, 255)
    p.poly(arcpts(512, 760, 330, 180, 360, ry=420) + [(842, 760), (182, 760)], heap)
    for x, y, col in ((400, 640, (90, 150, 240)), (540, 560, (90, 200, 120)), (620, 680, (250, 110, 130)), (470, 720, (255, 214, 92)), (690, 740, (90, 150, 240)), (330, 730, (250, 110, 130))):
        p.d.polygon([(x, y - 26), (x + 22, y), (x, y + 26), (x - 22, y)], fill=col + (255,))
    sparkle(p, 700, 380, 70)
    sparkle(p, 330, 440, 50)


def r_passexp(p):
    col = (110, 176, 255, 255)
    p.poly(star_pts(512, 520, 360, 0.52), col)
    motion_arrow(p, [(512, 700), (512, 360)], WHITE, 70, 150)


def r_rebirth_ticket(p):
    ticket(p, (150, 290, 874, 730), (170, 120, 245, 255))
    c = (512 + 60, 510)
    motion_arrow(p, arcpts(c[0], c[1], 140, 60, 330), WHITE, 40, 90)
    p.poly(star_pts(c[0], c[1], 70, 0.45), GOLD, w=14)


def r_protect(kind):
    def f(p):
        col = (96, 156, 230, 255) if kind == "drop" else (80, 186, 150, 255)
        p.poly(shield_pts(512, 480, 300, 420), col)
        p.poly(shield_pts(512, 480, 220, 320), lighten(col, 0.3), w=0)
        if kind == "drop":
            motion_arrow(p, [(512, 300), (512, 610)], WHITE, 60, 150)
            stroke(p, [(380, 680), (644, 680)], GOLD, 44)
        else:
            motion_arrow(p, arcpts(512, 490, 150, -50, 235), WHITE, 46, 110)
            p.ellipse((472, 460, 552, 540), GOLD, w=14)
    return f


def r_reroll_ticket(p):
    ticket(p, (150, 290, 874, 730), (70, 190, 190, 255))
    motion_arrow(p, [(420, 440), (760, 440)], WHITE, 40, 100)
    motion_arrow(p, [(740, 590), (400, 590)], WHITE, 40, 100)


def r_title(p):  # 칭호: 리본 휘장(도감 칭호 탭과 같은 모양 · 보라 리본)
    t_title(p, None)


def r_theme(p):
    p.poly(egg_pts(470, 520, 330, 280)[::-1], CREAM)
    p.d.ellipse((560, 590, 660, 690), fill=(0, 0, 0, 0))
    ring(p, (560, 590, 660, 690), CREAM_D, 10)
    for x, y, col in ((330, 420, (90, 150, 240)), (470, 350, (90, 200, 120)), (610, 400, (255, 214, 92)), (320, 590, (240, 130, 170))):
        p.ellipse((x - 58, y - 58, x + 58, y + 58), col + (255,))
    stroke(p, [(640, 820), (840, 540)], WOOD, 34)
    p.poly([(840, 540), (900, 440), (880, 560)], (90, 150, 240, 255))


def r_glider(p):
    col = (110, 200, 255, 255)
    p.poly([(512, 240), (880, 640), (512, 560), (144, 640)], col)
    p.poly([(512, 240), (512, 560), (144, 640)], lighten(col, 0.4), w=0)
    p.d.line([(144, 640), (512, 240), (880, 640), (512, 560), (144, 640)], fill=INK, width=W, joint="curve")
    p.d.line([(512, 240), (512, 560)], fill=INK, width=18)
    stroke(p, [(512, 560), (512, 780)], STEEL_D, 24)
    stroke(p, [(420, 780), (604, 780)], STEEL_D, 24)


def _nothing(p):
    pass


# id → (그림, 뜻, 데이터 키)
REWARDS = {
    "gold": (r_gold, "골드", ["gold", "goldKills"]),
    "enhanceStone": (r_stone((90, 156, 240, 255)), "강화석", ["enhanceStone"]),
    "highEnhanceStone": (r_stone((164, 110, 240, 255), True), "상급 강화석", ["highEnhanceStone"]),
    "egg": (r_egg, "알(구역 알 - 색은 UI가 구역색으로 바꿀 수 있음)", ["egg", "eggZone"]),
    "sparkleShard": (r_sparkle, "반짝 조각", ["sparkleShard"]),
    "gemDust": (r_dust, "보석 가루", ["gemDust"]),
    "passExp": (r_passexp, "시즌 패스 경험치", ["passExp"]),
    "rebirthTicket": (r_rebirth_ticket, "환생 무료권", ["rebirthTicket"]),
    "protectDrop": (r_protect("drop"), "하락 방지권(EnhanceConfig.protection.drop - 10 문서 §3 구간 도움 재화 후보)", ["protection.drop"]),
    "protectReset": (r_protect("reset"), "초기화 방지권(EnhanceConfig.protection.reset)", ["protection.reset"]),
    "rerollTicket": (r_reroll_ticket, "옵션 변환권(GemData dust.ticketDust)", ["rerollTicket"]),
    "title": (r_title, "칭호(도감 줄 · 합동 목표 등)", ["title"]),
    "cosmeticTheme": (r_theme, "치장 테마(시즌 패스)", ["cosmeticTheme"]),
    "gliderSkin": (r_glider, "글라이더 외형(시즌 패스)", ["gliderSkin"]),
}


# ── F 지도 핀(128) ──
def pin_disc(color, glyph, fit=560):
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((60, 60, 964, 964), fill=INK)
    d.ellipse((60 + 44, 60 + 44, 964 - 44, 964 - 44), fill=color + (255,))
    d.ellipse((230, 130, 794, 330), fill=lighten(color, 0.22))
    g = draw_fit(glyph, fit)
    img.alpha_composite(g)
    return img


def g_gate(p):
    stone = (236, 226, 250, 255)
    p.poly(arcpts(512, 470, 240, 180, 360) + [(752, 820), (272, 820)], stone)
    p.poly(arcpts(512, 490, 130, 180, 360) + [(642, 820), (382, 820)], (80, 50, 140, 255))


def g_forge(p):
    p.poly([(150, 400), (350, 360), (800, 360), (800, 470), (660, 510), (630, 620), (740, 690), (740, 770), (284, 770), (284, 690), (394, 620), (364, 510), (320, 490), (230, 460)], STEEL)


def g_checkpoint(p):
    p.poly([(512, 150), (650, 320), (600, 820), (424, 820), (374, 320)], (200, 244, 255, 255))
    p.poly([(512, 150), (560, 320), (540, 820), (512, 820)], WHITE, w=0)
    p.d.line([(512, 150), (512, 820)], fill=INK, width=14)


def g_hub(p):
    p.rrect((300, 480, 724, 800), 20, CREAM)
    p.poly([(220, 500), (512, 230), (804, 500)], (110, 170, 100, 255))
    p.rrect((460, 620, 564, 800), 16, WOOD)


def g_quest(p):
    p.rrect((440, 200, 584, 640), 60, INK, w=0)
    p.ellipse((432, 690, 592, 850), INK, w=0)


def g_boss(p):
    t_boss(p, None)


def g_user(p):
    pass


def pin_user():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    p = Pen(ImageDraw.Draw(img))
    col = (140, 110, 250, 255)
    pts = arcpts(512, 400, 300, 150, 390, n=60) + [(512, 960)]
    d = p.d
    d.polygon(pts, fill=INK)
    d.line(pts + [pts[0]], fill=INK, width=2 * W + 30, joint="curve")
    d.polygon(pts, fill=col)
    d.ellipse((392, 280, 632, 520), fill=(236, 232, 255, 255), outline=INK, width=W)
    return img


def pin_player():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    p = Pen(ImageDraw.Draw(img))
    col = (120, 220, 255, 255)
    pts = [(512, 90), (860, 900), (512, 700), (164, 900)]
    p.d.line(pts + [pts[0]], fill=INK, width=2 * W + 40, joint="curve")
    p.d.polygon(pts, fill=col)
    p.d.polygon([(512, 90), (512, 700), (164, 900)], fill=WHITE)
    p.d.line(pts + [pts[0]], fill=INK, width=W + 10, joint="curve")
    return img


def pin_party():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((230, 230, 794, 794), fill=INK)
    d.ellipse((290, 290, 734, 734), fill=(92, 156, 240, 255))
    d.ellipse((360, 330, 540, 470), fill=(190, 220, 255, 255))
    return img


PINS = {
    "pin_player": pin_player, "pin_party": pin_party,
    "pin_quest": lambda: pin_disc((245, 195, 59), g_quest, 480),
    "pin_gate": lambda: pin_disc((155, 92, 240), g_gate),
    "pin_forge": lambda: pin_disc((124, 132, 168), g_forge),
    "pin_checkpoint": lambda: pin_disc((57, 194, 214), g_checkpoint),
    "pin_hub": lambda: pin_disc((86, 194, 106), g_hub),
    "pin_user": pin_user,
    "pin_boss": lambda: pin_disc((96, 52, 150), g_boss, 600),
}


# ── E · G · 자물쇠 ──
def guide_chevron():
    base = (120, 220, 255, 255)
    shapes = [[(200, 470), (512, 190), (824, 470)], [(200, 800), (512, 520), (824, 800)]]
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for s in shapes:
        gd.line(s, fill=(120, 220, 255, 150), width=190, joint="curve")
    glow = glow.filter(ImageFilter.GaussianBlur(40))
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    img.alpha_composite(glow)
    d = ImageDraw.Draw(img)
    for s in shapes:
        for w, col in ((120, base), (46, (228, 250, 255, 255))):
            d.line(s, fill=col, width=w, joint="curve")
            for q in (s[0], s[-1]):
                d.ellipse((q[0] - w / 2, q[1] - w / 2, q[0] + w / 2, q[1] + w / 2), fill=col)
    return img


def guide_dot():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((260, 260, 764, 764), fill=(120, 220, 255, 170))
    img = img.filter(ImageFilter.GaussianBlur(70))
    d = ImageDraw.Draw(img)
    d.ellipse((392, 392, 632, 632), fill=(120, 220, 255, 255))
    d.ellipse((440, 440, 584, 584), fill=(236, 250, 255, 255))
    return img


def target_ring():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(img).ellipse((32, 32, 992, 992), outline=WHITE, width=26)
    return img


def lock_badge():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    p = Pen(ImageDraw.Draw(img))
    stroke(p, [(330, 520)] + arcpts(512, 380, 182, 180, 360)[1:-1] + [(694, 520)], (190, 196, 212, 255), 64)
    p.rrect((230, 460, 794, 900), 70, GOLD)
    p.rrect((230, 460, 794, 560), 50, lighten(GOLD, 0.35), w=0)
    p.rrect((230, 460, 794, 900), 70, None)
    p.ellipse((462, 590, 562, 690), INK, w=0)
    p.poly([(490, 660), (534, 660), (556, 800), (468, 800)], INK, w=0)
    return img


# ── 조립 ──
def draw_fit(fn, box=860):
    """투명 1024에 그리고 외곽 상자를 box에 맞춰 가운데로(보상 · 핀 글리프 공용)."""
    raw = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    fn(Pen(ImageDraw.Draw(raw)))
    bb = raw.getbbox()
    cr = raw.crop(bb)
    k = min(box / cr.width, box / cr.height, 1.4)
    cr = cr.resize((max(1, int(cr.width * k)), max(1, int(cr.height * k))), Image.LANCZOS)
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    out.alpha_composite(cr, ((S - cr.width) // 2, (S - cr.height) // 2))
    return out


def tiled(color, fn):
    color = tuple(color[:3]) + (255,)
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = tile(img, color)
    fn(Pen(d), color)
    return img


def disced(color, fn):
    color = tuple(color[:3]) + (255,)
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = disc(img, color)
    fn(Pen(d), color)
    return img


def save(img, sub, name, size=256):
    path = os.path.join(ART, sub, name + ".png")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img = img.resize((size, size), Image.LANCZOS)
    img.save(path)
    return path, img


def main():
    made = {}  # 묶음 → [(이름, 256 이미지)]
    skipped = []

    def add(group, sub, name, img, size=256):
        _, im = save(img, sub, name, size)
        made.setdefault(group, []).append((name, im))

    for cls, slots in SKILLS.items():
        col = CLASS_COLOR[cls]
        for slot, fn in slots.items():
            add("skills", "skills", f"{cls}_{slot}", tiled(col, fn))
        add("skills", "skills", f"dash_{cls}", tiled(col, dash))

    for name, (col, fn) in HUD_NEW.items():
        if name in H.ICONS:  # make_hud_icons.py가 만드는 기존 아이콘은 건드리지 않는다
            skipped.append(name)
            continue
        add("hud", "hud", name, tiled(col, fn))

    for tid, (col, fn) in CODEX.items():
        add("codex", "codex", f"tab_{tid}", disced(col, fn))

    rmap = {}
    for rid, (fn, meaning, keys) in REWARDS.items():
        add("reward", "reward", rid, draw_fit(fn))
        rmap[rid] = {"meaning": meaning, "dataKeys": keys}
    with open(os.path.join(ART, "reward", "_map.json"), "w", encoding="utf-8") as f:
        json.dump(rmap, f, ensure_ascii=False, indent=2)

    add("ui", "ui", "lock_badge", lock_badge())
    add("ui", "ui", "guide_chevron", guide_chevron())
    add("ui", "ui", "guide_dot", guide_dot())
    add("ui", "ui", "target_ring", target_ring())
    for name, fn in PINS.items():
        add("ui", "ui", name, fn(), 128)

    if "--preview" in sys.argv:
        contact(made, sys.argv[sys.argv.index("--preview") + 1])
    for g, items in made.items():
        print(g, len(items))
    if skipped:
        print("skipped (exists):", skipped)


def contact(made, path):
    font = ImageFont.truetype(H.FONT, 13)
    cols, cw, ch = 6, 230, 170
    rows = sum((len(v) + cols - 1) // cols for v in made.values()) + len(made)
    sheet = Image.new("RGBA", (cols * cw, rows * ch // 1 + 20), (40, 44, 60, 255))
    d = ImageDraw.Draw(sheet)
    y = 10
    for g, items in made.items():
        d.text((10, y), g, font=ImageFont.truetype(H.FONT, 22), fill=WHITE)
        y += 36
        for i, (name, im) in enumerate(items):
            x = (i % cols) * cw + 10
            if i and i % cols == 0:
                y += ch - 36
            yy = y
            bg = (120, 150, 90, 255) if name in ("target_ring", "guide_chevron", "guide_dot") else None
            if bg:
                d.rectangle((x, yy, x + 128, yy + 128), fill=bg)
            sheet.alpha_composite(im.resize((128, 128), Image.LANCZOS), (x, yy))
            sheet.alpha_composite(im.resize((64, 64), Image.LANCZOS), (x + 140, yy))
            sheet.alpha_composite(im.resize((40, 40), Image.LANCZOS), (x + 140, yy + 76))
            d.text((x, yy + 132), name, font=font, fill=(220, 224, 236, 255))
        y += ch
    sheet = sheet.crop((0, 0, sheet.width, y + 10))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sheet.save(path)


if __name__ == "__main__":
    main()
