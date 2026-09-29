# -*- coding: utf-8 -*-
# A2-N2 방어구 착용형(Blender bpy): docs/art/armor-wear-spec.md 규격 - 조각이 R15 파트에 붙는 형태(A2-N1 make_armor.py = 따로 선 물체 → 대체).
#   부위 3(armor · gloves · shoes) × 구역 6 × 등급 8. 조각 = 파트 로컬(가운데 원점 · −Z 앞)로 짓고 기준 체형 자리(REF)에 놓아 내보낸다.
#   MeshPart = <조각>(구역 본체) · <조각>_Trim(구역 강조 → 영웅부터 등급 색) · <조각>_Grade(띠 · 날개 = 등급 색) · <조각>_Glow(Neon).
#   메타 armor_wear.meta.json: 조각마다 attach(R15 파트) · offset(메시 경계 상자 가운데 - 파트 가운데 기준 · 파트 로컬) · refSize.
# 실행: bash bl.sh make_armor_wear.py [--zones tier1,...] [--slots ...] [--grades ...] [--icons] [--render 폴더] [--export]
import bpy
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import artlib as A  # noqa: E402
import make_weapons as W  # noqa: E402
import make_icons as I  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "art", "armor"))
ICON_OUT = os.path.normpath(os.path.join(HERE, "..", "..", "art", "icons", "armor"))
BUDGET = 800
PART_CAP = 12
RANK = W.RANK
at_least = W.at_least
ZONES = {  # 본체 · 강조(art-direction §3-2) · 테마 - A2-N1과 같은 값
    "tier1": dict(base=(168, 162, 154), accent=(92, 224, 138), theme="석조 평원"),
    "tier2": dict(base=(120, 96, 190), accent=(210, 108, 240), theme="수정 동굴"),
    "tier3": dict(base=(201, 228, 234), accent=(235, 110, 90), theme="수몰 사원"),
    "tier4": dict(base=(217, 186, 140), accent=(205, 150, 60), theme="모래 유적"),
    "tier5": dict(base=(88, 92, 128), accent=(120, 230, 255), theme="폭풍 첨탑"),
    "tier6": dict(base=(236, 240, 246), accent=(111, 200, 255), theme="빙하 동굴"),
}
SLOTS = ["armor", "gloves", "shoes"]
# 기준 체형(R15 블록형) - 파트 가운데(HumanoidRootPart 기준) · 크기
REF = {"UpperTorso": ((0, 0.2, 0), (2, 1.6, 1)), "LowerTorso": ((0, -0.8, 0), (2, 0.4, 1)),
       "LeftUpperArm": ((-1.5, 0.42, 0), (1, 1.17, 1)), "RightUpperArm": ((1.5, 0.42, 0), (1, 1.17, 1)),
       "LeftLowerArm": ((-1.5, -0.69, 0), (1, 1.05, 1)), "RightLowerArm": ((1.5, -0.69, 0), (1, 1.05, 1)),
       "LeftHand": ((-1.5, -1.37, 0), (1, 0.3, 1)), "RightHand": ((1.5, -1.37, 0), (1, 0.3, 1)),
       "LeftUpperLeg": ((-0.5, -1.6, 0), (1, 1.22, 1)), "RightUpperLeg": ((0.5, -1.6, 0), (1, 1.22, 1)),
       "LeftLowerLeg": ((-0.5, -2.8, 0), (1, 1.19, 1)), "RightLowerLeg": ((0.5, -2.8, 0), (1, 1.19, 1)),
       "LeftFoot": ((-0.5, -3.55, 0), (1, 0.3, 1)), "RightFoot": ((0.5, -3.55, 0), (1, 0.3, 1)),
       "Head": ((0, 1.6, 0), (1.2, 1.2, 1.2))}
PIECES = {"armor": [("Chest", "UpperTorso"), ("Shoulder_L", "LeftUpperArm"), ("Shoulder_R", "RightUpperArm"), ("Belt", "LowerTorso")],
          "gloves": [("Glove_L", "LeftHand"), ("Glove_R", "RightHand"), ("Bracer_L", "LeftLowerArm"), ("Bracer_R", "RightLowerArm")],
          "shoes": [("Boot_L", "LeftFoot"), ("Boot_R", "RightFoot"), ("Greave_L", "LeftLowerLeg"), ("Greave_R", "RightLowerLeg")]}
ANCHOR = {"armor": "Chest", "gloves": "Bracer_R", "shoes": "Greave_R"}  # 태초 · 초월 떠 있는 장식 · 고대 대표 날개


def palette(zone, grade):
    Z = ZONES[zone]
    gc = A.GRADE_COLOR[grade]
    p = dict(base=Z["base"], trim=Z["accent"], grade=gc, glow=(255, 244, 214))
    if at_least(grade, "epic"):
        p["trim"] = gc
    if grade == "primordial":
        p.update(base=(244, 242, 250), glow=A.GRADE_COLOR["primordial"])
    if grade == "transcendent":
        p.update(base=A.BLACK_BODY, trim=A.GOLD, grade=A.GOLD, glow=A.GOLD_GLOW)
    return p


def yl(st, b=0.1, n_sides=None):
    """세로 로프트 [(y, w, d, dz), ...] - 모따기 8각 단면"""
    return A.loft([[(x, y, z + dz) for x, z in A.chamfer_rect(w, d, min(b, w * 0.3, d * 0.3))] for y, w, d, dz in st])


def ring_y(y, rx, rz, thick=0.06, h=0.1, n=8):
    """세로축 띠(파트 둘레 감개)"""
    return A.xform(A.lathe([(1.0, -h / 2), (1.0 + thick, 0.0), (1.0, h / 2)], n), s=(rx, 1, rz), t=(0, y, 0))


def _bolt(h, w, d):
    pts = [(0.0, 0.0), (w * 0.55, h * 0.45), (w * 0.05, h * 0.5), (w * 0.6, h)]
    outline = [pts[0]] + [(x + w * 0.22, y) for x, y in pts[1:]] + [(x - w * 0.22, y) for x, y in reversed(pts[:-1])]
    n = len(outline)
    v = [(x, y, d / 2) for x, y in outline] + [(x, y, -d / 2) for x, y in outline]
    return v, [tuple(range(n)), tuple(reversed(range(n, 2 * n)))] + [(i, n + i, n + (i + 1) % n, (i + 1) % n) for i in range(n)]


# ────────────────────────── 조각 기본형(파트 로컬) ──────────────────────────
def chest_base():  # 몸통 2 × 1.6 × 1을 감싸는 껍데기 · 가슴 앞으로 볼록 · 목 둘레는 좁혀 열어 둠
    # 2차(검토 - 앞치마처럼 옆구리가 드러났다): 폭 ×1.08 · 옆 두께도 감싼다
    return A.xform(yl([(-0.8, 2.1, 1.14, 0.0), (-0.25, 2.16, 1.18, -0.03), (0.4, 2.2, 1.22, -0.06), (0.82, 1.74, 1.04, 0.0)], 0.3), s=(1.08, 1, 1))


def shoulder_base(side, big):  # 윗팔 위 절반을 덮는 둥근 받이(바깥쪽으로 넓게)
    return A.ellipsoid((0.7 * big, 0.46 * big, 0.66 * big), n=9, rings=4, center=(side * 0.12, 0.52, 0), squash_bottom=0.35)  # 윗면이 어깨선보다 0.4 높게 - 정면 실루엣


def belt_base():  # 허리띠 + 앞 · 옆 드림 4(얇게 - 허벅지 위 0.35까지)
    belt = yl([(-0.2, 2.1, 1.1, 0), (0.22, 2.12, 1.12, 0)], 0.25)
    flaps = [A.xform(A.box(0.62, 0.55, 0.08, b=0.03), m=A.rot(rx=-6), t=(x, -0.42, -0.58)) for x in (-0.5, 0.5)]
    flaps += [A.xform(A.box(0.08, 0.5, 0.6, b=0.03), m=A.rot(rz=s * 6), t=(s * 1.08, -0.4, 0)) for s in (-1, 1)]
    return A.merge(belt, *flaps)


def glove_base(side):  # 손 1 × 0.3 × 1 덮개 · 앞 마디 띠 · 안쪽 엄지(장갑으로 읽히게) · 손바닥(아래)은 얇게
    shell = yl([(-0.19, 1.08, 1.06, 0), (0.05, 1.12, 1.1, 0), (0.21, 1.02, 1.0, 0)], 0.18)
    knuckle = A.merge(*[A.ellipsoid((0.14, 0.21, 0.24), n=6, rings=2, center=(x, -0.12, -0.62)) for x in (-0.33, -0.11, 0.11, 0.33)])  # 2차: 말아 쥔 손가락 4를 앞으로 ×1.5(주먹 실루엣)
    thumb = A.tube([(-side * 0.46, 0.0, -0.12), (-side * 0.74, -0.02, -0.34), (-side * 0.7, 0.04, -0.56)], lambda u: 0.15 - 0.03 * u, sides=5)  # 엄지를 옆으로 빼냄
    return A.merge(shell, knuckle, thumb)


def bracer_base():  # 아래팔 아래 60%를 감싸고 손목 쪽이 나팔처럼 벌어짐
    return yl([(-0.53, 1.18, 1.18, 0), (-0.4, 1.1, 1.1, 0), (0.05, 1.07, 1.07, 0)], 0.18)


def boot_base():  # 발 껍데기(앞 −Z 길게 · 앞코 살짝 들림) + 발목 턱
    # 2차(검토 - 둥근 상자로 퇴보): 앞코 +0.35 · 굽 +0.12 → 장화 L자 윤곽
    shell = A.loft([[(x, y + yc, z) for x, y in A.chamfer_rect(w, h, 0.1)] for z, w, h, yc in ((0.55, 1.1, 0.46, 0.04), (-0.2, 1.14, 0.44, 0.0), (-0.85, 1.0, 0.32, -0.04), (-1.03, 0.72, 0.18, 0.0))])
    heel = A.box(1.06, 0.12, 0.42, center=(0, -0.29, 0.34))
    return A.merge(shell, heel)


def greave_base():  # 정강이 판(앞 두껍게) + 무릎 받이
    plate = yl([(-0.6, 1.12, 1.1, -0.02), (0.1, 1.1, 1.12, -0.04), (0.45, 1.02, 1.04, -0.02)], 0.2)
    knee = A.ellipsoid((0.36, 0.26, 0.2), n=8, rings=3, center=(0, 0.5, -0.54))
    return A.merge(plate, knee)


# ────────────────────────── 구역 테마(조각별 base 추가 · trim) ──────────────────────────
def zone_features(zone, piece, big):
    """반환 (base 추가 목록, trim 목록) - 조각 로컬"""
    side = -1 if piece.endswith("_L") else 1
    kind = piece.split("_")[0]
    b, t = [], []
    if zone == "tier1":  # 석조: 깎은 돌판 · 오른 어깨만 큰 바위판 · 이끼(강조)
        if kind == "Shoulder":
            if side > 0:
                b.append(A.xform(A.box(0.34, 1.0 * big, 0.95 * big, b=0.08), m=A.rot(rz=-22), t=(0.5, 0.95, 0)))  # 솟은 바위판(비대칭)
            t.append(A.ellipsoid((0.4 * big, 0.12, 0.42 * big), n=8, rings=3, center=(side * 0.02, 0.5 + 0.34 * big, 0), squash_bottom=0.3))
        elif kind == "Chest":
            b.append(A.box(1.0, 0.5, 0.18, b=0.07, center=(0, 0.2, -0.64)))  # 가슴 돌판
            t.append(A.xform(A.box(2.2, 0.12, 1.2, b=0.04), t=(0, -0.75, 0)))  # 이끼 밑단
        elif kind in ("Glove",):
            b.append(A.box(0.9, 0.22, 0.3, b=0.07, center=(0, 0.02, -0.6)))
        elif kind == "Bracer":
            b.append(A.xform(A.box(0.6, 0.5, 0.2, b=0.06), t=(side * 0.6, -0.15, 0), m=A.rot(ry=90)))
            t.append(ring_y(0.1, 0.56, 0.56, 0.1, 0.12))
        elif kind == "Boot":
            b.append(A.box(0.92, 0.26, 0.34, b=0.08, center=(0, 0.02, -0.62)))
        elif kind == "Greave":
            b.append(A.xform(A.box(0.66, 0.66, 0.2, b=0.06), m=A.rot(rx=-8), t=(0, -0.05, -0.62)))
            t.append(ring_y(0.45, 0.54, 0.54, 0.1, 0.12))
    elif zone == "tier2":  # 수정: 결정 묶음
        if kind == "Shoulder":
            t += [A.crystal(h * big, 0.13, sides=5, tip_h=0.25, base_h=0.05, center=(side * dx, 0.72, dz), m=A.rot(rz=-side * ang)) for h, dx, dz, ang in ((0.85, 0.1, 0.0, 14), (0.55, 0.36, 0.18, 38), (0.45, -0.12, -0.2, -6))]
        elif kind == "Chest":
            t.append(A.crystal(0.5, 0.2, sides=6, tip_h=0.18, base_h=0.12, center=(0, 0.25, -0.62), m=A.rot(rx=90)))
        elif kind == "Bracer":
            t += [A.crystal(h, 0.09, sides=4, tip_h=0.16, base_h=0.04, center=(side * 0.55, y, 0), m=A.rot(rz=-side * 70)) for h, y in ((0.5, -0.2), (0.36, 0.05))]
        elif kind == "Greave":
            t += [A.crystal(h, 0.1, sides=4, tip_h=0.16, base_h=0.04, center=(0, y, -0.56), m=A.rot(rx=-65)) for h, y in ((0.46, 0.1), (0.34, -0.25))]
        elif kind in ("Glove", "Boot"):
            t.append(A.crystal(0.3, 0.08, sides=4, tip_h=0.12, base_h=0.03, center=(0, 0.2, 0.1 if kind == "Glove" else 0.45), m=A.rot(rx=-40 if kind == "Glove" else -50)))
    elif zone == "tier3":  # 수몰 사원: 조개 어깨 · 산호 지느러미
        if kind == "Shoulder":
            b.append(A.xform(A.ellipsoid((0.78 * big, 0.3, 0.72 * big), n=10, rings=3, squash_bottom=0.2), m=A.rot(rz=-side * 16), t=(side * 0.14, 0.86, 0)))
            t += [A.xform(A.tube([(0.66 * math.cos(a) * big, 0.04, 0.6 * math.sin(a) * big), (0, 0.3, 0)], 0.045, sides=3), m=A.rot(rz=-side * 16), t=(side * 0.14, 0.86, 0)) for a in (0.4, 1.3, 2.2, 3.1, 4.0, 4.9, 5.8)]
        elif kind == "Chest":
            t.append(A.merge(*[W.feather_wing((sgn * 0.25, 0.7, 0.45), sgn, (0.55, 0.42, 0.3), (15, 40, 65), up=(0, 1, 0.3), side=(1, 0, 0), width=0.14) for sgn in (-1, 1)]))  # 목 뒤 지느러미
        elif kind in ("Bracer", "Greave"):
            t.append(W.feather_wing((side * 0.55, -0.1, 0.1), side, (0.5, 0.38, 0.26), (40, 70, 100), up=(0, 1, 0), side=(1, 0, 0), width=0.1))
    elif zone == "tier4":  # 모래 유적: 천 감개 · 청동 스카라브 · 말린 앞코
        if kind == "Shoulder":
            b.append(yl([(0.3, 1.2 * big, 1.14 * big, 0), (0.55, 1.28 * big, 1.2 * big, 0), (0.7, 1.0 * big, 0.95 * big, 0)], 0.18))  # 층진 사암 판
            t.append(A.xform(A.box(0.24, 0.14, 0.24, b=0.05), t=(side * 0.4, 0.8, 0)))
        elif kind == "Chest":
            t += [yl([(y, 2.2, 1.22, -0.04), (y + 0.1, 2.22, 1.24, -0.04)], 0.1) for y in (-0.45, -0.1)]
            t.append(A.xform(A.ellipsoid((0.26, 0.2, 0.09), n=8, rings=3), t=(0, 0.35, -0.64)))
        elif kind in ("Bracer", "Greave"):
            t += [ring_y(y, 0.54, 0.54, 0.08, 0.1) for y in ((-0.3, 0.0) if kind == "Bracer" else (-0.3, 0.15))]
        elif kind == "Boot":
            b.append(A.tube(A.bezier((0, 0.0, -0.9), (0, 0.02, -1.12), (0, 0.3, -1.16), (0, 0.34, -1.0), n=4), lambda u: 0.13 * (1 - u) + 0.04, sides=4, tip_end=True))  # 2차: 늘린 앞코 끝에서 말림
    elif zone == "tier5":  # 폭풍 첨탑: 번개 날 · 작은 날개
        if kind == "Shoulder":
            b.append(A.ellipsoid((0.6 * big, 0.26, 0.6 * big), n=8, rings=3, center=(side * 0.1, 0.62, 0), squash_bottom=0.25))
            t.append(A.xform(_bolt(1.0 * big, 0.42 * big, 0.12), m=A.rot(rz=-side * 18), t=(side * 0.25, 0.75, 0)))
        elif kind == "Chest":
            t.append(A.xform(_bolt(0.7, 0.34, 0.08), t=(0, -0.2, -0.64)))
        elif kind in ("Bracer", "Greave"):
            t.append(W.feather_wing((side * 0.55, 0.05, 0.15), side, (0.5, 0.36, 0.25), (20, 45, 70), up=(0, 1, 0.2), side=(1, 0, 0), width=0.09))
    elif zone == "tier6":  # 빙하: 털(본체 흰색) · 고드름(강조)
        if kind == "Shoulder":
            b += [A.ellipsoid((0.25, 0.2, 0.25), n=6, rings=2, center=(side * 0.1 + 0.44 * math.cos(a), 0.78, 0.4 * math.sin(a))) for a in (2 * math.pi * i / 5 for i in range(5))]
            t += [A.crystal(0.5 * big, 0.08, sides=4, tip_h=0.25, base_h=0.03, center=(side * 0.1 + dx, 0.4, dz), m=A.rot(rx=180)) for dx, dz in ((0.5, 0.0), (0.28, -0.32))]
        elif kind == "Chest":
            b += [A.ellipsoid((0.3, 0.22, 0.28), n=6, rings=2, center=(0.66 * math.cos(a), 0.86, 0.42 * math.sin(a))) for a in (2 * math.pi * i / 6 for i in range(6))]  # 털 깃
        elif kind in ("Bracer", "Boot"):
            y = 0.1 if kind == "Bracer" else 0.3
            b += [A.ellipsoid((0.2, 0.15, 0.2), n=6, rings=2, center=(0.5 * math.cos(a), y, 0.5 * math.sin(a))) for a in (2 * math.pi * i / 5 for i in range(5))]
            t += [A.crystal(0.32, 0.06, sides=4, tip_h=0.14, base_h=0.03, center=(0.5 * math.sin(a_), y - 0.12, -0.5 * math.cos(a_)), m=A.rot(rx=180)) for a_ in (-0.6, 0.0, 0.6)]
        elif kind == "Greave":
            t.append(A.crystal(0.4, 0.09, sides=4, tip_h=0.16, base_h=0.03, center=(0, 0.3, -0.56), m=A.rot(rx=180)))
    return b, t


# ────────────────────────── 등급(조각별) ──────────────────────────
def grade_extra(slot, piece, grade):
    """반환 (grade 목록(등급 색), glow 목록(Neon), base 추가(초월 흑금 조각))"""
    kind = piece.split("_")[0]
    side = -1 if piece.endswith("_L") else 1
    g, gl, b = [], [], []
    if at_least(grade, "rare"):  # 희귀 = 등급 색 띠(허리 · 팔찌 · 정강이)
        if kind == "Belt":
            g.append(yl([(-0.02, 2.16, 1.16, 0), (0.1, 2.16, 1.16, 0)], 0.25))
        elif kind == "Bracer":
            g.append(ring_y(-0.46, 0.62, 0.62, 0.08, 0.1))
        elif kind == "Greave":
            g.append(ring_y(-0.52, 0.56, 0.56, 0.08, 0.1))
    if at_least(grade, "legendary"):  # 전설 = 보석(Neon)
        where = {"Chest": (0, 0.28, -0.68), "Bracer": (side * 0.62, -0.2, 0), "Greave": (0, -0.1, -0.64)}.get(kind)
        if where:
            m = A.rot(rx=90) if kind != "Bracer" else A.rot(rz=-side * 90)
            gl.append(A.crystal(0.28, 0.12, sides=5, tip_h=0.1, base_h=0.08, center=where, m=m))
    if at_least(grade, "relic"):  # 유물 = 룬 가시(유물만 발광 - 이후 등급 색)
        sp = {"Shoulder": [W.spike((side * 0.55, 0.6, 0), (side * 0.7, 0.7, 0), 0.4, 0.09)],
              "Bracer": [W.spike((side * 0.58, 0.0, 0), (side * 0.9, 0.4, 0), 0.3, 0.07)],
              "Greave": [W.spike((side * 0.55, 0.1, 0), (side * 0.9, 0.4, 0), 0.3, 0.07)]}.get(kind, [])
        (gl if grade == "relic" else g).extend(sp)
    if at_least(grade, "ancient") and piece == ANCHOR[slot]:  # 고대 = 깃 날개(등 · 팔찌 · 발뒤꿈치 - 대표 조각)
        wing = {"armor": A.merge(*[W.feather_wing((s * 0.5, 0.5, 0.58), s, (1.2, 0.95, 0.7), (35, 60, 85), up=(0, 1, 0.25), side=(1, 0, 0), width=0.18) for s in (-1, 1)]),
                "gloves": W.feather_wing((0.58, 0.1, 0.1), 1, (0.6, 0.45, 0.32), (30, 55, 80), up=(0, 1, 0), side=(1, 0, 0), width=0.12),
                "shoes": W.feather_wing((0.56, -0.2, 0.35), 1, (0.62, 0.48, 0.34), (25, 50, 75), up=(0, 1, 0.3), side=(1, 0, 0), width=0.12)}[slot]
        g.append(wing)
    if piece == ANCHOR[slot]:
        c = {"armor": (0, 0.3, 0), "gloves": (0.3, 0.1, 0), "shoes": (0.3, 0.1, 0)}[slot]
        k = 1.0 if slot == "armor" else 0.6
        if grade == "primordial":
            gl += [W.float_crystals([(c[0] - 1.3 * k, c[1] + 0.7 * k, 0), (c[0] + 1.3 * k, c[1] + 0.3 * k, 0)], 0.5 * k, 0.12 * k),
                   W.halo_ring((c[0], c[1] + 1.05 * k if slot == "armor" else c[1] - 0.2, 0), 0.4 if slot == "armor" else 0.7, axis="Z", tilt=20, thick=0.05, n=7)]
        if grade == "transcendent":
            b.append(W.float_shards([(c[0] - 1.35 * k, c[1] + 0.6 * k, 0), (c[0] + 1.35 * k, c[1] + 0.2 * k, 0), (c[0] + 0.4 * k, c[1] + 1.3 * k, 0)], 0.3 * k))
            crack = {"armor": [(-0.4, 0.55, -0.64), (0.1, 0.2, -0.68), (-0.15, -0.2, -0.66), (0.3, -0.55, -0.62)],
                     "gloves": [(side * 0.58, 0.05, -0.2), (side * 0.6, -0.2, 0.1), (side * 0.58, -0.45, -0.1)],
                     "shoes": [(-0.15, 0.3, -0.6), (0.1, 0.0, -0.62), (-0.05, -0.35, -0.6)]}[slot]
            if slot == "armor":  # 2차: 금빛 균열은 가슴에만 · 가늘고 짧게(구역 형태가 주인공)
                gl.append(W.crack_line(crack[1:3], 0.06, 0.04))
    return g, gl, b


def piece_meshes(zone, slot, grade, piece):
    kind = piece.split("_")[0]
    side = -1 if piece.endswith("_L") else 1
    big = 1.18 if at_least(grade, "legendary") else 1.0
    if kind == "Shoulder":
        big *= 1.35  # 2차(검토 - 어깨 주인공이 A2-N1보다 작았다): 윗팔 폭 1 대비 가로 약 1.4
    base = {"Chest": chest_base, "Belt": belt_base, "Glove": glove_base, "Bracer": bracer_base, "Boot": boot_base, "Greave": greave_base}.get(kind)
    base = shoulder_base(side, big) if kind == "Shoulder" else (glove_base(side) if kind == "Glove" else base())
    add_b, trim = zone_features(zone, piece, big)
    if grade == "transcendent":  # 2차(검토 - 6구역 초월이 같은 "검은 판 + 금 번개"): 구역 형태 조각을 금 테로 옮겨 검은 본체 위에서 구역 실루엣이 금으로 읽히게
        trim, add_b = trim + add_b, []
    g, gl, b2 = grade_extra(slot, piece, grade)
    out = [("", A.merge(base, *add_b, *b2), "base", False)]
    if trim:
        out.append(("_Trim", A.merge(*trim), "trim", False))
    if g:
        out.append(("_Grade", A.merge(*g), "grade", False))
    if gl:
        out.append(("_Glow", A.merge(*gl), "glow", True))
    return out


def build(zone, slot, grade):
    P = palette(zone, grade)
    col = A.new_collection("%s_%s_%s" % (slot, zone, grade))
    objs, info = [], {}
    for piece, part in PIECES[slot]:
        pc, _ = REF[part]
        for suffix, geo, role, neon in piece_meshes(zone, slot, grade, piece):
            name = piece + suffix
            o = A.make_obj(name, A.xform(geo, t=pc), P[role], col, neon=neon, origin=pc, mat_name="%s_%s_%s_%s" % (slot, zone, grade, name))
            objs.append(o)
            info[name] = part
    return col, objs, info


def mannequin(slot):
    """회색 R15 기준 체형(렌더 전용) - 부위가 몸에 어떻게 붙는지"""
    col = A.new_collection("mannequin_" + slot)
    out = []
    for part, (c, s) in REF.items():
        out.append(A.make_obj("M_" + part, A.box(*s, b=0.06, center=c), (96, 98, 116), col, mat_name="mannequin_" + part))
    return out


ICON_VIEW = {"armor": (["Chest", "Shoulder_L", "Shoulder_R", "Belt"], 25.0), "gloves": (["Glove_R", "Bracer_R"], 30.0), "shoes": (["Boot_R", "Greave_R"], 300.0)}  # 2차: 장갑 = 옆 30°  # 장갑 = 안쪽(엄지) 옆 · 신발 = 옆(앞코 실루엣)


def parse():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opt = {"zones": list(ZONES), "slots": SLOTS, "grades": list(A.GRADES), "icons": False, "render": None, "export": False}
    i = 0
    while i < len(argv):
        a = argv[i]
        if a in ("--zones", "--slots", "--grades"):
            opt[a[2:]] = argv[i + 1].split(","); i += 1
        elif a == "--render":
            opt["render"] = os.path.abspath(argv[i + 1]); i += 1
        elif a == "--icons":
            opt["icons"] = True
        elif a == "--export":
            opt["export"] = True
        i += 1
    return opt


def main():
    opt = parse()
    os.makedirs(ICON_OUT, exist_ok=True)
    stats, pieces_meta = {}, {}
    for zone in opt["zones"]:
        for slot in opt["slots"]:
            for grade in opt["grades"]:
                A.reset()
                col, objs, info = build(zone, slot, grade)
                tri = sum(A.tri_count(o) for o in objs)
                key = "%s_%s_%s" % (slot, zone, grade)
                stats[key] = dict(tris=tri, parts=len(objs))
                if len(objs) > PART_CAP or tri > BUDGET:
                    print("[make_armor_wear] 상한 초과", key, tri, len(objs))
                if opt["export"] and grade in ("normal", "legendary", "transcendent"):
                    A.export_fbx(os.path.join(OUT, "%s.fbx" % key), objs)
                    for o in objs:  # offset = 메시 경계 상자 가운데 - 파트 가운데(기준 체형 · 파트 로컬 = 월드 축과 같음)
                        pc = REF[info[o.name]][0]
                        cen = A.roblox_center(o)
                        pieces_meta.setdefault(key, {})[o.name] = dict(attach=info[o.name], offset=[round(cen[i] - pc[i], 3) for i in range(3)],
                                                                       refSize=list(REF[info[o.name]][1]), tris=A.tri_count(o), neon=bool(o.get("Neon", False)))
                if opt["icons"]:
                    names, turn = ICON_VIEW[slot]
                    sel = [o for o in objs if o.name.split("_Trim")[0].split("_Grade")[0].split("_Glow")[0] in names]
                    if slot == "gloves":  # 2차: 아이콘에서 팔찌 : 주먹 = 0.7 : 1(렌더 전용 - FBX는 위에서 이미 내보냄)
                        for o in sel:
                            if o.name.startswith("Bracer"):
                                o.scale = (0.72, 0.72, 0.72)
                    I.render_icon(sel, os.path.join(ICON_OUT, "%s.png" % key), base_rot=(0, 0, 0), roll=0.0, tilt=(-10.0 if slot != "shoes" else -25.0, turn), hull=0.03, pad=1.02)
                    for o in sel:
                        o.scale = (1, 1, 1)
                if opt["render"] and grade in ("normal", "legendary", "transcendent"):
                    man = mannequin(slot)
                    A.render_views(objs + man, os.path.join(opt["render"], key), views=("front", "34"), kinds=("game",), sil=False, hull=0.03, res=(520, 700))
    worst = max(stats.items(), key=lambda kv: kv[1]["tris"])
    print("[make_armor_wear] 삼각형 최소 %d · 최대 %s · 파트 최대 %d" % (min(v["tris"] for v in stats.values()), worst, max(v["parts"] for v in stats.values())))
    if opt["export"]:
        path = os.path.join(OUT, "armor_wear.meta.json")
        old = {}
        if os.path.exists(path):
            import json
            old = json.load(open(path, encoding="utf-8"))
        allp = old.get("pieces", {})
        allp.update(pieces_meta)
        allt = old.get("tris", {})
        allt.update(stats)
        A.write_json(path, {"version": "A2-N2", "spec": "docs/art/armor-wear-spec.md", "triBudget": BUDGET, "partCap": PART_CAP,
                            "refBody": {k: dict(center=list(v[0]), size=list(v[1])) for k, v in REF.items()}, "pieces": allp, "tris": allt,
                            "zones": {k: v["theme"] for k, v in ZONES.items()}})
    print("[make_armor_wear] 끝")


if __name__ == "__main__":
    main()
