# -*- coding: utf-8 -*-
# QUEUE-ALL7B 3 허브 건물 · NPC(Blender bpy): 대장간 · 상점 · 명예의 전당(핵심 25 ~ 35) · 일반 집 · 재봉집(15 ~ 25) · 마을 게시판 · NPC 5명.
#   공간 = Roblox(stud · +Y 위 · −Z 앞 = 거리 쪽) · 원점 = 바닥 가운데. 파트 = 색 하나씩(Studio에서 HubArtMeta 색으로 칠한다).
#   캐릭터 키 ≈ 5 → 문 높이 ≥ 7.5(1.5배) · NPC 키 5.2 ~ 5.6. 카툰 중세(갑옷 v3와 같은 모따기 - make_obj bevel).
#   결과 = roblox/art/props/hub_<종류>.fbx · .meta.json + roblox/src/shared/data/HubArtMeta.lua(크기 · 파트 색 · 관절 · 굴뚝 자리 · 삼각형 - 코드가 읽는 표 · 생성 파일).
# 실행: bash bl.sh make_hub.py [--items hub_forge,...] [--render 폴더] [--no-export]
import bpy
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import artlib as A  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "art", "props"))
LUA = os.path.normpath(os.path.join(HERE, "..", "..", "src", "shared", "data", "HubArtMeta.lua"))

# ── 팔레트 ──
PLASTER = (236, 222, 196)
PLASTER_SHADE = (214, 198, 170)
TIMBER = (112, 72, 44)
STONE = (168, 160, 150)
STONE_DARK = (122, 116, 110)
DOOR = (92, 58, 36)
WINDOW = (255, 214, 120)
ROOF_RED = (196, 72, 52)
ROOF_BLUE = (64, 116, 206)
ROOF_GREEN = (86, 150, 92)
ROOF_PLUM = (150, 90, 160)
ROOF_WOOD = (140, 96, 58)
MARBLE = (240, 238, 232)
MARBLE_SHADE = (214, 210, 202)
GOLD = A.GOLD
EMBER = (255, 140, 50)
SKIN = (240, 196, 160)
NEON_PARTS = {"Window", "Ember", "Lamp", "Glow"}
WOOD_DECK = (168, 120, 76)
BEVEL = 0.18


def slab(c, t):
    """윗면 네 점(순서대로) + 두께 t(아래로) = 기운 판(지붕 · 차양)"""
    v = [tuple(p) for p in c] + [(p[0], p[1] - t, p[2]) for p in c]
    f = [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
    return v, f


def prism(section, axis, a0, a1):
    """볼록 단면 하나를 축(x 또는 z)으로 a0 → a1 밀어낸 기둥(박공 벽 · 신전 지붕 - 닫힌 볼록 = 법선 깨끗)"""
    if axis == "x":
        rings = [[(a, y, z) for z, y in section] for a in (a0, a1)]
    else:
        rings = [[(x, y, a) for x, y in section] for a in (a0, a1)]
    return A.loft(rings)


def gable_roof(w, d, y0, rh, oh=1.4, t=0.8):
    """용마루 = X 방향 · 앞뒤(±Z)로 경사 · 처마 내밈 oh"""
    X, D = w / 2 + oh, d / 2 + oh
    k = oh / (d / 2)  # 내민 만큼 처마를 낮춘다(같은 경사)
    ye = y0 - rh * k
    front = slab([(-X, ye, -D), (X, ye, -D), (X, y0 + rh, 0), (-X, y0 + rh, 0)], t)
    back = slab([(X, ye, D), (-X, ye, D), (-X, y0 + rh, 0), (X, y0 + rh, 0)], t)
    return A.merge(front, back)


def tile_rows(w, d, y0, rh, oh=1.4, rows=3):
    """기와 줄(지붕 위 가는 띠) - 빨간 지붕 결"""
    X, D = w / 2 + oh, d / 2 + oh
    out = []
    for i in range(1, rows + 1):
        f = i / (rows + 1)
        z = -D + (D) * f
        y = (y0 - rh * oh / (d / 2)) + (rh + rh * oh / (d / 2)) * f + 0.05
        for sz in (1, -1):
            out.append(A.box(2 * X, 0.25, 0.5, center=(0, y, sz * z)))
    return A.merge(*out)


def house(w, d, wall_h, roof_h, roof_rgb, door_w=4.6, door_h=8.0, chimney=False, tiles=False, extra=None):
    """일반 집 틀: 돌 받침 · 회벽 · 나무 골조 · 박공지붕 · 문(앞 −Z) · 창 2. 반환 = 파트 목록 + 정보"""
    base_h = 1.4
    y0 = base_h + wall_h
    parts = []
    parts.append(("Base", A.box(w + 1.2, base_h, d + 1.2, b=0.3, center=(0, base_h / 2, 0)), STONE))
    wall = prism([(-d / 2, base_h), (d / 2, base_h), (d / 2, y0), (0, y0 + roof_h), (-d / 2, y0)], "x", -w / 2, w / 2)
    parts.append(("Wall", wall, PLASTER))
    tim = []
    for sx in (-1, 1):
        for sz in (-1, 1):
            tim.append(A.box(0.9, wall_h, 0.9, center=(sx * (w / 2 - 0.2), base_h + wall_h / 2, sz * (d / 2 - 0.2))))
    for yy in (base_h + wall_h * 0.52, y0 - 0.35):
        tim.append(A.box(w + 0.3, 0.7, 0.5, center=(0, yy, -d / 2 - 0.05)))
        tim.append(A.box(w + 0.3, 0.7, 0.5, center=(0, yy, d / 2 + 0.05)))
    # 앞면 X자 골조(문 양옆 위층)
    for sx in (-1, 1):
        cx = sx * w * 0.3
        L = wall_h * 0.42
        tim.append(A.xform(A.box(0.45, L, 0.4), m=A.rot(rz=sx * 32), t=(cx, base_h + wall_h * 0.76, -d / 2 - 0.12)))
    parts.append(("Timber", A.merge(*tim), TIMBER))
    lift = 0.85  # 지붕 판 밑면이 벽 경사면 위로(같은 면이면 겹쳐 비친다 - z 싸움)
    parts.append(("Roof", gable_roof(w, d, y0 + lift, roof_h), roof_rgb))
    parts.append(("Ridge", A.box(w + 3.2, 0.7, 0.9, b=0.15, center=(0, y0 + lift + roof_h + 0.1, 0)), A.mul(roof_rgb, 0.72)))
    if tiles:
        parts.append(("Tiles", tile_rows(w, d, y0 + lift, roof_h), A.mul(roof_rgb, 0.8)))
    door = A.merge(A.box(door_w, door_h, 0.5, center=(0, base_h + door_h / 2, -d / 2 - 0.15)),
                   A.xform(A.lathe([(0.0, 0.0), (door_w / 2, 0.0), (door_w / 2, 0.5), (0.0, 0.5)], 10, axis="Z"), t=(0, base_h + door_h, -d / 2 - 0.4)))
    parts.append(("Door", door, DOOR))
    frame = A.merge(A.box(0.6, door_h + 0.4, 0.7, center=(-door_w / 2 - 0.3, base_h + door_h / 2, -d / 2 - 0.2)),
                    A.box(0.6, door_h + 0.4, 0.7, center=(door_w / 2 + 0.3, base_h + door_h / 2, -d / 2 - 0.2)))
    parts.append(("DoorFrame", frame, TIMBER))
    # QUEUE-ALL8 B2: 문 앞 나무 계단 한 칸(돌 받침 1.4 → 0.7 → 바닥)
    parts.append(("Porch", A.box(door_w + 2.6, 0.7, 1.6, b=0.1, center=(0, 0.35, -d / 2 - 0.6 - 0.8)), WOOD_DECK))
    win = []
    for sx in (-1, 1):
        win.append(A.box(2.6, 2.8, 0.3, center=(sx * w * 0.3, base_h + wall_h * 0.3 + 0.6, -d / 2 - 0.15)))
    parts.append(("Window", A.merge(*win), WINDOW))
    info = {"wallTop": y0, "height": y0 + lift + roof_h + 0.45, "doorH": door_h, "doorW": door_w}
    if chimney:
        cx, cz = w * 0.28, d * 0.18
        top = y0 + roof_h + 3.0
        ch = A.merge(A.box(2.4, top - y0, 2.4, b=0.25, center=(cx, (y0 + top) / 2, cz)), A.box(3.0, 0.6, 3.0, b=0.15, center=(cx, top + 0.3, cz)))
        parts.append(("Chimney", ch, STONE_DARK))
        info["chimney"] = [cx, top + 0.6, cz]
        info["height"] = max(info["height"], top + 0.6)
    if extra:
        parts += extra
    return parts, info


def sign(x, y, z, w_, h_, rgb, emblem=None):
    """벽에서 앞(−Z)으로 내민 걸이 간판"""
    arm = A.box(0.35, 0.35, 2.4, center=(x, y + h_ / 2 + 0.5, z - 1.2))
    board = A.box(w_, h_, 0.35, b=0.12, center=(x, y, z - 2.2))
    out = [("SignArm", arm, TIMBER), ("SignBoard", board, rgb)]
    if emblem:
        out.append(("Emblem", A.xform(emblem, t=(x, y, z - 2.45)), GOLD))
    return out


def hammer_emblem():
    return A.merge(A.xform(A.box(0.3, 1.6, 0.12), m=A.rot(rz=-35)), A.xform(A.box(1.2, 0.55, 0.12), m=A.rot(rz=-35), t=(0.42, 0.62, 0)))


# ── 건물 ──
def b_forge():
    # 핵심(25 ~ 35): 넓은 대장간 + 빨간 기와 + 굴뚝(연기 = 코드) + 앞 화덕 불빛
    w, d = 28.0, 20.0
    parts, info = house(w, d, 13.0, 9.0, ROOF_RED, door_w=6.0, door_h=9.0, chimney=True, tiles=True)
    parts.append(("Ember", A.box(4.0, 1.4, 0.3, center=(w * 0.3, 2.8, -d / 2 - 0.2)), EMBER))
    ax, az = -w * 0.08 - 6.0, -d / 2 - 3.2
    anvil = A.merge(A.box(1.6, 1.6, 1.6, b=0.2, center=(ax, 0.8, az)), A.box(1.0, 0.7, 0.8, center=(ax, 1.95, az)), A.box(2.8, 0.7, 1.2, b=0.12, center=(ax + 0.2, 2.65, az)))
    parts.append(("Anvil", anvil, (78, 82, 100)))
    parts += sign(-w * 0.32, 10.6, -d / 2, 3.6, 2.4, (96, 62, 40), hammer_emblem())
    return parts, info, dict(w=w, d=d, budget=3000)


def b_shop():
    # 핵심: 파란 지붕 상점 + 줄무늬 차양 + 상자
    w, d = 26.0, 18.0
    parts, info = house(w, d, 14.0, 10.0, ROOF_BLUE, door_w=5.6, door_h=8.5)
    aw = []
    for i in range(6):
        x0 = -w / 2 + 1 + i * (w - 2) / 6
        x1 = x0 + (w - 2) / 6
        aw.append(slab([(x0, 9.4, -d / 2 - 0.3), (x1, 9.4, -d / 2 - 0.3), (x1, 7.8, -d / 2 - 4.0), (x0, 7.8, -d / 2 - 4.0)], 0.3))
    parts.append(("Awning", A.merge(*aw[0::2]), ROOF_BLUE))
    parts.append(("AwningStripe", A.merge(*aw[1::2]), (246, 244, 236)))
    crates = A.merge(A.box(2.2, 2.2, 2.2, b=0.15, center=(-w * 0.38, 2.5, -d / 2 - 2.4)), A.box(1.8, 1.8, 1.8, b=0.15, center=(-w * 0.38 + 2.3, 2.3, -d / 2 - 2.0)),
                     A.box(1.6, 1.6, 1.6, b=0.15, center=(-w * 0.38 + 0.6, 4.4, -d / 2 - 2.4)))
    parts.append(("Crates", crates, (176, 124, 72)))
    coin = A.xform(A.lathe([(0.0, -0.1), (0.9, -0.1), (0.9, 0.1), (0.0, 0.1)], 12, axis="Z"), t=(0, 0, 0))
    parts += sign(w * 0.34, 10.2, -d / 2, 3.2, 2.2, (60, 90, 160), coin)
    info["height"] = max(info["height"], 0)
    return parts, info, dict(w=w, d=d, budget=3000)


def b_hall():
    # 핵심: 흰 돌 + 금장 명예의 전당(계단 · 기둥 6 · 삼각 박공 · 금 테 · 별)
    w, d = 30.0, 22.0
    parts = []
    steps = A.merge(A.box(w + 4, 1.0, d + 4, b=0.2, center=(0, 0.5, 0)), A.box(w + 2, 1.0, d + 2, b=0.2, center=(0, 1.5, 0)), A.box(w, 1.0, d, b=0.2, center=(0, 2.5, 0)))
    parts.append(("Steps", steps, MARBLE_SHADE))
    body_h = 15.0
    parts.append(("Body", A.box(w - 6, body_h, d - 6, center=(0, 3 + body_h / 2, 1.5)), MARBLE))
    cols = []
    for i in range(6):
        x = -w / 2 + 2.2 + i * (w - 4.4) / 5
        cols.append(A.xform(A.lathe([(1.0, 0.0), (1.0, 0.6), (0.8, 0.9), (0.75, body_h - 0.9), (0.95, body_h - 0.5), (1.1, body_h)], 10), t=(x, 3.0, -d / 2 + 1.8)))
    parts.append(("Columns", A.merge(*cols), MARBLE))
    y0 = 3 + body_h
    parts.append(("Entablature", A.box(w + 0.6, 1.6, d + 0.6, b=0.2, center=(0, y0 + 0.8, 0)), MARBLE_SHADE))
    yr = y0 + 1.6
    roof = prism([(-w / 2 - 0.6, yr), (w / 2 + 0.6, yr), (0, yr + 6.5)], "z", -d / 2 - 0.4, d / 2 + 0.4)
    parts.append(("Roof", roof, MARBLE))
    ped = prism([(-w / 2 + 1.2, yr + 0.3), (w / 2 - 1.2, yr + 0.3), (0, yr + 5.6)], "z", -d / 2 - 0.7, -d / 2 - 0.4)
    parts.append(("Pediment", ped, MARBLE_SHADE))
    sl = math.degrees(math.atan2(6.5, w / 2 + 0.6))
    L = math.hypot(6.5, w / 2 + 0.6)
    trim = A.merge(A.box(w + 1.0, 0.45, 0.5, center=(0, y0 + 1.75, -d / 2 - 0.65)),
                   A.xform(A.box(L, 0.45, 0.5), m=A.rot(rz=sl), t=(-(w / 2 + 0.6) / 2, yr + 3.25 + 0.2, -d / 2 - 0.65)),
                   A.xform(A.box(L, 0.45, 0.5), m=A.rot(rz=-sl), t=((w / 2 + 0.6) / 2, yr + 3.25 + 0.2, -d / 2 - 0.65)))
    star = []
    n = 5
    for i in range(n):
        a = math.pi / 2 + 2 * math.pi * i / n
        star.append(A.xform(A.box(0.7, 2.4, 0.3), m=A.rot(rz=math.degrees(a) - 90), t=(0.9 * math.cos(a), yr + 2.4 + 0.9 * math.sin(a), -d / 2 - 0.95)))
    parts.append(("Gold", A.merge(trim, *star), GOLD))
    door = A.box(6.0, 10.0, 0.5, center=(0, 3 + 5.0, -d / 2 + 4.3))
    parts.append(("Door", door, (120, 92, 52)))
    h = y0 + 1.6 + 6.5 + 0.45
    return parts, {"wallTop": y0, "height": h, "doorH": 10.0, "doorW": 6.0}, dict(w=w, d=d, budget=3500)


def b_house_a():
    w, d = 20.0, 16.0
    parts, info = house(w, d, 10.0, 7.0, ROOF_GREEN)
    return parts, info, dict(w=w, d=d, budget=2500)


def b_house_b():
    w, d = 22.0, 16.0
    parts, info = house(w, d, 11.0, 7.5, ROOF_RED, tiles=True)
    return parts, info, dict(w=w, d=d, budget=2500)


def b_tailor():
    # 일반(15 ~ 25): 자주 지붕 + 실패 간판
    w, d = 20.0, 16.0
    spool = A.merge(A.lathe([(0.0, -0.6), (0.9, -0.6), (0.9, -0.45), (0.55, -0.45), (0.55, 0.45), (0.9, 0.45), (0.9, 0.6), (0.0, 0.6)], 10))
    parts, info = house(w, d, 10.5, 7.5, ROOF_PLUM, extra=sign(w * 0.32, 9.6, -d / 2, 2.8, 2.2, (120, 70, 140), spool))
    return parts, info, dict(w=w, d=d, budget=2500)


def b_board():
    # 마을 게시판(작은 구조물): 기둥 2 · 판 · 나무 지붕(키 8)
    parts = []
    posts = A.merge(A.box(0.7, 7.2, 0.7, b=0.12, center=(-3.4, 3.6, 0)), A.box(0.7, 7.2, 0.7, b=0.12, center=(3.4, 3.6, 0)))
    parts.append(("Posts", posts, TIMBER))
    parts.append(("Board", A.box(6.4, 3.8, 0.4, b=0.15, center=(0, 3.9, 0)), (176, 132, 86)))
    papers = A.merge(A.box(1.6, 1.9, 0.08, center=(-1.8, 4.3, -0.25)), A.box(1.4, 1.5, 0.08, center=(0.2, 3.6, -0.25)), A.box(1.5, 1.8, 0.08, center=(2.0, 4.4, -0.25)))
    parts.append(("Papers", papers, (250, 246, 232)))
    parts.append(("Roof", gable_roof(7.6, 1.6, 7.2, 1.1, oh=0.7, t=0.35), ROOF_WOOD))
    return parts, {"wallTop": 7.2, "height": 8.5, "doorH": 0, "doorW": 0}, dict(w=8.0, d=2.0, budget=800)


# ── NPC(키 ≈ 5.4 · 관절 = 어깨 · 목) ──
SHOULDER_Y, NECK_Y = 3.55, 3.95


def npc_base(outfit, legs_rgb, hat=None, hat_rgb=None):
    parts = []
    legs = A.merge(A.box(0.8, 1.9, 0.9, b=0.12, center=(-0.45, 0.95, 0)), A.box(0.8, 1.9, 0.9, b=0.12, center=(0.45, 0.95, 0)),
                   A.box(0.9, 0.35, 1.2, b=0.1, center=(-0.45, 0.17, -0.12)), A.box(0.9, 0.35, 1.2, b=0.1, center=(0.45, 0.17, -0.12)))
    parts.append(("Legs", legs, legs_rgb))
    parts.append(("Torso", A.box(2.0, 1.95, 1.15, b=0.22, center=(0, 2.85, 0)), outfit))
    parts.append(("Head", A.box(1.75, 1.6, 1.6, b=0.4, center=(0, NECK_Y + 0.85, 0)), SKIN))
    eyes = A.merge(A.box(0.22, 0.38, 0.1, center=(-0.38, NECK_Y + 0.95, -0.82)), A.box(0.22, 0.38, 0.1, center=(0.38, NECK_Y + 0.95, -0.82)))
    parts.append(("Face", eyes, (40, 34, 52)))
    for side, name in ((-1, "ArmL"), (1, "ArmR")):
        arm = A.merge(A.box(0.62, 1.7, 0.62, b=0.12, center=(side * 1.32, SHOULDER_Y - 0.75, 0)), A.box(0.66, 0.5, 0.66, b=0.15, center=(side * 1.32, SHOULDER_Y - 1.75, 0)))
        parts.append((name, arm, outfit if name == "ArmL" else outfit))
    if hat:
        parts.append(("Hat", hat, hat_rgb))
    return parts


def npc_smith():
    p = npc_base((150, 96, 62), (70, 60, 56), hat=A.box(1.9, 0.5, 1.75, b=0.15, center=(0, NECK_Y + 1.75, 0)), hat_rgb=(60, 50, 46))
    p.append(("Apron", A.box(1.7, 2.2, 0.15, center=(0, 2.4, -0.62)), (96, 62, 40)))
    hammer = A.merge(A.box(0.22, 1.5, 0.22, center=(1.32, SHOULDER_Y - 2.3, -0.2)), A.box(0.9, 0.5, 0.5, b=0.08, center=(1.32, SHOULDER_Y - 3.0, -0.2)))
    p.append(("ToolR", hammer, (90, 92, 104)))
    return p


def npc_merchant():
    hat = A.merge(A.lathe([(0.0, 0.0), (1.3, 0.0), (1.3, 0.15), (0.75, 0.2), (0.7, 0.9), (0.0, 0.95)], 12), )
    p = npc_base((64, 116, 206), (80, 70, 60), hat=A.xform(hat, t=(0, NECK_Y + 1.6, 0)), hat_rgb=(220, 196, 120))
    p.append(("Bag", A.box(0.9, 1.0, 0.6, b=0.15, center=(-1.25, 2.3, -0.3)), (176, 124, 72)))
    return p


def npc_tailor():
    hat = A.box(1.5, 0.35, 1.5, b=0.12, center=(0, NECK_Y + 1.75, 0))
    p = npc_base((150, 90, 160), (70, 56, 80), hat=hat, hat_rgb=(236, 214, 120))
    tape = A.box(2.1, 0.22, 1.25, center=(0, 3.45, 0))
    p.append(("Tape", tape, (236, 214, 120)))
    sc = A.merge(A.xform(A.box(0.12, 0.9, 0.08), m=A.rot(rz=18), t=(1.32, SHOULDER_Y - 2.3, -0.3)), A.xform(A.box(0.12, 0.9, 0.08), m=A.rot(rz=-18), t=(1.32, SHOULDER_Y - 2.3, -0.3)))
    p.append(("ToolR", sc, (200, 206, 218)))
    return p


def npc_knight():
    helm = A.merge(A.box(1.95, 1.75, 1.8, b=0.45, center=(0, NECK_Y + 0.9, 0)), A.box(0.25, 0.9, 1.9, center=(0, NECK_Y + 1.9, 0)))
    p = npc_base((206, 212, 224), (150, 158, 174), hat=helm, hat_rgb=(206, 212, 224))
    p = [x for x in p if x[0] != "Face"]
    p.append(("Face", A.box(1.2, 0.22, 0.1, center=(0, NECK_Y + 0.95, -0.92)), (40, 34, 52)))
    p.append(("Plume", A.box(0.3, 0.7, 1.6, b=0.1, center=(0, NECK_Y + 2.55, 0.1)), (210, 60, 70)))
    shield = A.box(1.5, 1.9, 0.25, b=0.2, center=(-1.62, 2.55, -0.45))
    p.append(("ToolL", shield, (210, 60, 70)))
    sword = A.merge(A.box(0.3, 1.45, 0.12, center=(1.32, 0.78, -0.55)), A.box(1.1, 0.22, 0.3, center=(1.32, 1.58, -0.55)), A.box(0.2, 0.5, 0.2, center=(1.32, 1.95, -0.55)))
    p.append(("ToolR", sword, (232, 236, 244)))
    return p


def npc_keeper():
    hat = A.box(1.85, 0.3, 1.7, b=0.1, center=(0, NECK_Y + 1.72, -0.15))
    p = npc_base((92, 140, 96), (90, 74, 60), hat=hat, hat_rgb=(70, 100, 72))
    scroll = A.xform(A.lathe([(0.0, -0.7), (0.32, -0.7), (0.32, 0.7), (0.0, 0.7)], 8, axis="X"), t=(1.32, SHOULDER_Y - 2.15, -0.35))
    p.append(("ToolR", scroll, (250, 240, 210)))
    return p


NPC_PIVOTS = {"Head": [0, NECK_Y, 0], "ArmL": [-1.32, SHOULDER_Y, 0], "ArmR": [1.32, SHOULDER_Y, 0]}



# ── QUEUE-ALL8 B3 소품(삼각형 ≤ 300 · 원점 = 바닥 가운데 · −Z 앞) ──
BARK = (120, 80, 50)
LEAF = (98, 170, 84)
LEAF_DARK = (70, 138, 66)


def p_barrel():
    body = A.lathe([(0.0, 0.0), (1.05, 0.0), (1.3, 1.5), (1.05, 3.0), (0.0, 3.0)], 12)
    bands = A.merge(A.xform(A.lathe([(1.12, 0.5), (1.24, 0.5), (1.27, 0.75), (1.15, 0.75)], 12)), A.xform(A.lathe([(1.15, 2.25), (1.27, 2.25), (1.24, 2.5), (1.12, 2.5)], 12)))
    return [("Body", body, (150, 100, 58)), ("Bands", bands, (90, 92, 104))], 300


def p_crates():
    g = A.merge(A.box(2.4, 2.4, 2.4, b=0.15, center=(0, 1.2, 0)), A.xform(A.box(2.0, 2.0, 2.0, b=0.15), m=A.rot(ry=18), t=(2.4, 1.0, 0.3)), A.xform(A.box(1.7, 1.7, 1.7, b=0.15), m=A.rot(ry=-12), t=(0.6, 3.25, 0.1)))
    slats = A.merge(A.box(2.5, 0.25, 0.3, center=(0, 1.2, -1.25)), A.box(0.3, 2.5, 0.3, center=(0, 1.2, -1.25)))
    return [("Crates", g, (186, 136, 82)), ("Slats", slats, (130, 90, 54))], 300


def p_cart():
    bed = A.box(4.6, 1.2, 2.8, b=0.15, center=(0, 2.0, 0))
    sides = A.merge(A.box(4.6, 0.9, 0.25, center=(0, 3.0, -1.3)), A.box(4.6, 0.9, 0.25, center=(0, 3.0, 1.3)), A.box(0.25, 0.9, 2.8, center=(2.2, 3.0, 0)))
    handles = A.merge(A.box(2.6, 0.25, 0.25, center=(-3.4, 2.1, -1.0)), A.box(2.6, 0.25, 0.25, center=(-3.4, 2.1, 1.0)))
    wheels = A.merge(A.xform(A.lathe([(0.0, -0.18), (1.25, -0.18), (1.25, 0.18), (0.0, 0.18)], 10, axis="Z"), t=(0.6, 1.25, -1.6)), A.xform(A.lathe([(0.0, -0.18), (1.25, -0.18), (1.25, 0.18), (0.0, 0.18)], 10, axis="Z"), t=(0.6, 1.25, 1.6)))
    load = A.merge(A.box(1.4, 1.0, 1.2, b=0.1, center=(0.6, 3.1, -0.4)), A.ellipsoid((0.7, 0.6, 0.7), n=8, rings=4, center=(-0.9, 3.0, 0.5)))
    return [("Bed", A.merge(bed, sides, handles), (150, 100, 58)), ("Wheels", wheels, (96, 64, 40)), ("Load", load, (230, 170, 70))], 300


def p_stall():
    posts = A.merge(*[A.box(0.35, 5.6, 0.35, center=(x, 2.8, z)) for x in (-3.2, 3.2) for z in (-1.6, 1.6)])
    counter = A.box(6.8, 1.2, 1.4, b=0.12, center=(0, 2.4, -1.4))
    aw = []
    for i in range(6):
        x0 = -3.6 + i * 1.2
        aw.append(slab_raw([(x0, 5.8, -2.4), (x0 + 1.2, 5.8, -2.4), (x0 + 1.2, 6.6, 1.8), (x0, 6.6, 1.8)], 0.15))
    goods = A.merge(A.ellipsoid((0.45, 0.4, 0.45), n=8, rings=4, center=(-2.0, 3.35, -1.4)), A.ellipsoid((0.45, 0.4, 0.45), n=8, rings=4, center=(-1.0, 3.35, -1.4)), A.box(0.9, 0.7, 0.7, b=0.1, center=(1.5, 3.35, -1.4)))
    return [("Posts", A.merge(posts, counter), (150, 100, 58)), ("Awning", A.merge(*aw[0::2]), (210, 70, 70)), ("AwningStripe", A.merge(*aw[1::2]), (246, 240, 226)), ("Goods", goods, (240, 190, 70))], 300


def p_lantern():
    post = A.merge(A.box(0.45, 6.4, 0.45, center=(0, 3.2, 0)), A.box(1.2, 0.5, 1.2, b=0.1, center=(0, 0.25, 0)), A.box(1.6, 0.3, 0.3, center=(0.6, 6.2, 0)))
    cage = A.merge(A.box(1.0, 0.2, 1.0, center=(1.2, 6.0, 0)), A.box(0.9, 0.25, 0.9, center=(1.2, 4.75, 0)))
    lamp = A.box(0.7, 1.0, 0.7, center=(1.2, 5.4, 0))
    return [("Post", post, (60, 52, 50)), ("Cage", cage, (60, 52, 50)), ("Lamp", lamp, (255, 214, 120))], 300


def p_fence():
    posts = A.merge(A.box(0.5, 2.4, 0.5, b=0.08, center=(-3.75, 1.2, 0)), A.box(0.5, 2.4, 0.5, b=0.08, center=(3.75, 1.2, 0)), A.box(0.45, 2.1, 0.45, center=(0, 1.05, 0)))
    rails = A.merge(A.box(8.0, 0.35, 0.25, center=(0, 0.9, 0)), A.box(8.0, 0.35, 0.25, center=(0, 1.8, 0)))
    return [("Posts", posts, (150, 104, 64)), ("Rails", rails, (178, 128, 80))], 300


def p_flowerpot():
    pot = A.lathe([(0.0, 0.0), (0.6, 0.0), (0.85, 0.9), (0.95, 1.0), (0.0, 1.0)], 10)
    bloom = A.merge(A.ellipsoid((0.45, 0.35, 0.45), n=6, rings=3, center=(-0.25, 1.35, 0.1)), A.ellipsoid((0.4, 0.3, 0.4), n=6, rings=3, center=(0.3, 1.45, -0.15)), A.ellipsoid((0.35, 0.3, 0.35), n=6, rings=3, center=(0.0, 1.6, 0.3)))
    leaves = A.ellipsoid((0.8, 0.35, 0.8), n=8, rings=3, center=(0, 1.1, 0))
    return [("Pot", pot, (196, 108, 72)), ("Leaves", leaves, LEAF), ("Bloom", bloom, (250, 120, 160))], 300


def p_bench():
    seat = A.box(5.0, 0.35, 1.4, b=0.08, center=(0, 1.5, 0))
    back = A.box(5.0, 1.2, 0.3, b=0.06, center=(0, 2.4, 0.6))
    legs = A.merge(*[A.box(0.35, 1.5, 1.2, center=(x, 0.75, 0)) for x in (-2.1, 2.1)])
    return [("Seat", A.merge(seat, back), (176, 124, 76)), ("Legs", legs, (70, 62, 60))], 300


def p_well():
    ring = A.lathe([(1.8, 0.0), (2.5, 0.0), (2.5, 2.0), (1.9, 2.0), (1.9, 0.3), (1.8, 0.3)], 12)
    water = A.lathe([(0.0, 1.2), (1.85, 1.2), (1.85, 1.3), (0.0, 1.3)], 12)
    posts = A.merge(A.box(0.35, 4.4, 0.35, center=(-2.1, 3.2, 0)), A.box(0.35, 4.4, 0.35, center=(2.1, 3.2, 0)), A.box(4.6, 0.3, 0.3, center=(0, 5.0, 0)))
    roof = A.merge(slab_raw([(-2.8, 5.0, -1.8), (2.8, 5.0, -1.8), (2.8, 6.4, 0), (-2.8, 6.4, 0)], 0.25), slab_raw([(2.8, 5.0, 1.8), (-2.8, 5.0, 1.8), (-2.8, 6.4, 0), (2.8, 6.4, 0)], 0.25))
    bucket = A.lathe([(0.0, 3.2), (0.35, 3.2), (0.42, 3.8), (0.0, 3.8)], 8)
    return [("Ring", ring, (168, 160, 150)), ("Water", water, (90, 170, 220)), ("Posts", A.merge(posts, bucket), (130, 90, 54)), ("Roof", roof, (196, 72, 52))], 300


def p_flag():
    pole = A.merge(A.lathe([(0.0, 0.0), (0.18, 0.0), (0.14, 9.0), (0.0, 9.0)], 8), A.ellipsoid((0.3, 0.3, 0.3), n=6, rings=3, center=(0, 9.2, 0)), A.box(1.2, 0.4, 1.2, b=0.1, center=(0, 0.2, 0)))
    cloth = A.merge(slab_raw([(0.15, 8.6, 0.0), (3.2, 8.4, -0.15), (3.2, 6.6, -0.15), (0.15, 6.8, 0.0)], 0.1))
    return [("Pole", pole, (220, 214, 200)), ("Cloth", cloth, (210, 60, 70))], 300


def p_sign():
    post = A.box(0.4, 4.0, 0.4, center=(0, 2.0, 0))
    boards = A.merge(A.xform(A.box(2.8, 0.7, 0.2, b=0.06), m=A.rot(ry=12), t=(0.9, 3.4, -0.3)), A.xform(A.box(2.6, 0.7, 0.2, b=0.06), m=A.rot(ry=-160), t=(-0.8, 2.6, -0.3)))
    return [("Post", post, (130, 90, 54)), ("Boards", boards, (196, 150, 98))], 300


def p_bush():
    g = A.merge(A.ellipsoid((1.5, 1.2, 1.3), n=8, rings=4, center=(0, 1.1, 0)), A.ellipsoid((1.0, 0.9, 1.0), n=8, rings=4, center=(1.1, 0.9, 0.4)), A.ellipsoid((0.9, 0.8, 0.9), n=8, rings=4, center=(-1.1, 0.8, -0.3)))
    return [("Leaves", g, LEAF_DARK)], 300


def p_flowers():
    bed = A.box(6.0, 0.5, 3.6, b=0.2, center=(0, 0.25, 0))
    leaves = A.merge(*[A.ellipsoid((0.7, 0.45, 0.7), n=6, rings=3, center=(x, 0.75, z)) for x, z in ((-2.0, -0.8), (-0.6, 0.7), (0.9, -0.6), (2.1, 0.8))])
    bloomA = A.merge(*[A.ellipsoid((0.35, 0.3, 0.35), n=6, rings=3, center=(x, 1.25, z)) for x, z in ((-2.2, -0.6), (0.8, -0.9), (2.3, 0.6))])
    bloomB = A.merge(*[A.ellipsoid((0.35, 0.3, 0.35), n=6, rings=3, center=(x, 1.2, z)) for x, z in ((-0.7, 0.9), (1.5, 0.1), (-1.5, 0.4))])
    return [("Bed", bed, (120, 84, 56)), ("Leaves", leaves, LEAF), ("BloomA", bloomA, (255, 214, 90)), ("BloomB", bloomB, (240, 110, 150))], 300


def p_tree_small():
    trunk = A.lathe([(0.0, 0.0), (0.7, 0.0), (0.45, 4.2), (0.0, 4.2)], 8)
    crown = A.merge(A.ellipsoid((2.6, 2.3, 2.6), n=8, rings=4, center=(0, 6.0, 0)), A.ellipsoid((1.6, 1.4, 1.6), n=8, rings=4, center=(1.0, 7.6, 0.4)))
    return [("Trunk", trunk, BARK), ("Crown", crown, LEAF)], 300


def p_gem_bench():
    top = A.box(4.0, 0.4, 2.2, b=0.1, center=(0, 3.0, 0))
    legs = A.merge(*[A.box(0.35, 2.8, 0.35, center=(x, 1.4, z)) for x in (-1.7, 1.7) for z in (-0.9, 0.9)])
    gems = A.merge(A.crystal(0.8, 0.3, sides=5, center=(-1.0, 3.2, -0.3)), A.crystal(0.6, 0.25, sides=5, center=(-0.4, 3.2, 0.3)), A.crystal(0.7, 0.28, sides=5, center=(0.2, 3.2, -0.5)))
    lens = A.merge(A.xform(A.lathe([(0.35, -0.05), (0.5, -0.05), (0.5, 0.05), (0.35, 0.05)], 10, axis="Z"), t=(1.2, 3.9, 0)), A.box(0.12, 0.8, 0.12, center=(1.2, 3.4, 0)))
    return [("Bench", A.merge(top, legs), (150, 100, 58)), ("Gems", gems, (110, 200, 240)), ("Lens", lens, (214, 176, 62))], 300


def p_refine_furnace():
    body = A.box(3.0, 3.2, 2.6, b=0.25, center=(0, 1.6, 0.2))
    mouth = A.box(1.4, 1.0, 0.2, center=(0, 1.3, -1.15))
    chimney = A.box(1.0, 2.0, 1.0, b=0.1, center=(0.6, 4.2, 0.6))
    crucible = A.lathe([(0.0, 3.2), (0.65, 3.2), (0.8, 3.9), (0.0, 3.9)], 10)
    glow = A.lathe([(0.0, 3.85), (0.7, 3.85), (0.7, 3.95), (0.0, 3.95)], 10)
    return [("Body", A.merge(body, chimney), (150, 96, 70)), ("Mouth", mouth, (255, 140, 50)), ("Crucible", crucible, (78, 82, 100)), ("Glow", glow, (255, 170, 60))], 300


def p_anvil_statue():
    plinth = A.merge(A.box(3.6, 1.2, 3.6, b=0.2, center=(0, 0.6, 0)), A.box(2.8, 0.8, 2.8, b=0.15, center=(0, 1.6, 0)))
    anvil = A.merge(A.box(1.4, 0.8, 1.0, center=(0, 2.4, 0)), A.box(0.8, 0.8, 0.7, center=(0, 3.2, 0)), A.box(3.0, 0.9, 1.3, b=0.12, center=(0.2, 4.05, 0)), A.box(1.2, 0.5, 0.9, center=(-1.8, 4.2, 0)))
    hammer = A.merge(A.xform(A.box(0.25, 2.2, 0.25), m=A.rot(rz=-30), t=(1.1, 5.2, 0)), A.xform(A.box(1.0, 0.55, 0.55), m=A.rot(rz=-30), t=(1.65, 6.15, 0)))
    return [("Plinth", plinth, (168, 160, 150)), ("Anvil", anvil, (110, 116, 132)), ("Hammer", hammer, A.GOLD)], 300


def slab_raw(c, t):
    v = [tuple(q) for q in c] + [(q[0], q[1] - t, q[2]) for q in c]
    f = [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
    return v, f


PROP_FNS = {"prop_barrel": p_barrel, "prop_crates": p_crates, "prop_cart": p_cart, "prop_stall": p_stall, "prop_lantern": p_lantern, "prop_fence": p_fence,
            "prop_flowerpot": p_flowerpot, "prop_bench": p_bench, "prop_well": p_well, "prop_flag": p_flag, "prop_sign": p_sign, "prop_bush": p_bush,
            "prop_flowers": p_flowers, "prop_tree_small": p_tree_small, "prop_gem_bench": p_gem_bench, "prop_refine_furnace": p_refine_furnace,
            "prop_anvil_statue": p_anvil_statue}

ITEMS = {
    "hub_forge": ("building", b_forge), "hub_shop": ("building", b_shop), "hub_hall": ("building", b_hall),
    "hub_house_a": ("building", b_house_a), "hub_house_b": ("building", b_house_b), "hub_tailor": ("building", b_tailor),
    "hub_board": ("building", b_board),
    "npc_smith": ("npc", npc_smith), "npc_merchant": ("npc", npc_merchant), "npc_tailor": ("npc", npc_tailor),
    "npc_knight": ("npc", npc_knight), "npc_keeper": ("npc", npc_keeper),
}
for _k, _fn in PROP_FNS.items():
    ITEMS[_k] = ("prop", _fn)


def build(item):
    kind, fn = ITEMS[item]
    col = A.new_collection(item)
    if kind == "npc":
        parts, info, cfg = fn(), {}, dict(budget=1500)
    elif kind == "prop":
        parts, budget = fn()
        info, cfg = {}, dict(budget=budget)
    else:
        parts, info, cfg = fn()
    objs = []
    for name, g, rgb in parts:
        bev = BEVEL if kind == "building" and name in ("Base", "Wall", "Body", "Steps", "Entablature") else 0.0
        objs.append(A.make_obj(name, g, rgb, col, neon=name in NEON_PARTS, origin=(0, 0, 0), bevel=bev, mat_name="%s_%s" % (item, name)))
    return kind, objs, info, cfg, {n: rgb for n, _, rgb in parts}


def lua_val(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return ("%.3f" % v).rstrip("0").rstrip(".")
    if isinstance(v, str):
        return '"%s"' % v
    if isinstance(v, (list, tuple)):
        return "{ " + ", ".join(lua_val(x) for x in v) + " }"
    if isinstance(v, dict):
        return "{ " + ", ".join("%s = %s" % (k, lua_val(v[k])) for k in sorted(v)) + " }"
    raise TypeError(v)


def write_lua(rows):
    lines = ["-- 생성 파일(roblox/tools/blender/make_hub.py) - 손으로 고치지 않는다. QUEUE-ALL7B 3 허브 건물 · NPC 메시 표.",
             "--   키 = props/<이름>(ArtAssetIds) · size = 발밑 가운데 기준 경계(가로 w · 깊이 d · 높이 h - 충돌 상자 = 이 w × d × wallTop) · parts = 메시 조각 색(RGB) · 네온",
             "--   kind = building | npc | prop(QUEUE-ALL8 B3 소품 - 삼각형 ≤ 300) · NPC pivots = 관절(어깨 · 목 - 대기 동작이 이 점을 축으로 돈다) · chimney = 굴뚝 끝(연기 자리) · tris = 삼각형(상한 budget).",
             "return {"]
    for item in sorted(rows):
        lines.append("\t%s = %s," % (item, lua_val(rows[item])))
    lines.append("}")
    with open(LUA, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")


def parse():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opt = {"items": list(ITEMS), "render": None, "export": True}
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--items":
            opt["items"] = argv[i + 1].split(","); i += 1
        elif a == "--render":
            opt["render"] = os.path.abspath(argv[i + 1]); i += 1
        elif a == "--no-export":
            opt["export"] = False
        i += 1
    return opt


def main():
    opt = parse()
    rows = {}
    for item in opt["items"]:
        A.reset()
        kind, objs, info, cfg, colors = build(item)
        total = sum(A.tri_count(o) for o in objs)
        lo, hi = A.bbox_world(objs)
        ext = A.CT @ (hi - lo)
        size = [abs(ext.x), abs(ext.y), abs(ext.z)]
        print("[make_hub] %s 파트 %d · 삼각형 %d / %d · 크기(w, h, d) %.1f × %.1f × %.1f" % (item, len(objs), total, cfg["budget"], size[0], size[1], size[2]))
        assert total <= cfg["budget"], item
        row = {"kind": kind, "tris": total, "budget": cfg["budget"], "bounds": [round(x, 2) for x in size],
               "parts": {o.name.split(".")[0]: {"rgb": list(colors[o.name.split(".")[0]]), "neon": o.name.split(".")[0] in NEON_PARTS} for o in objs}}
        if kind == "building":
            row.update({"w": cfg["w"], "d": cfg["d"], "wallTop": round(info["wallTop"], 2), "height": round(info["height"], 2), "doorH": info["doorH"], "doorW": info["doorW"]})
            if "chimney" in info:
                row["chimney"] = [round(x, 2) for x in info["chimney"]]
        elif kind == "npc":
            row["pivots"] = NPC_PIVOTS
            row["height"] = round(size[1], 2)
        else:
            row["height"] = round(size[1], 2)
        rows[item] = row
        if opt["export"]:
            A.export_fbx(os.path.join(OUT, "%s.fbx" % item), objs)
            A.write_json(os.path.join(OUT, "%s.meta.json" % item), A.meta_of(objs, cfg["budget"], {"version": "QUEUE-ALL7B", "item": item}))
        if opt["render"]:
            A.render_views(objs, os.path.join(opt["render"], item), views=("front", "34"), kinds=("game",), sil=False, hull=0.12 if kind == "building" else 0.04, res=(700, 700))
    if opt["export"] and set(opt["items"]) == set(ITEMS):
        write_lua(rows)
        print("[make_hub] 표 = " + LUA)
    print("[make_hub] 끝")


if __name__ == "__main__":
    main()
