# -*- coding: utf-8 -*-
# QUEUE-ALL1 P2 방어구 외형 v3(docs/design/v2/02-armor-look-v3.md): 직업 4 × 부위 3 × 외형 3(normal · legendary · transcendent) = 36 메시.
#   세트(구역 6) 차이 = 코드가 칠하는 색(client/ArmorWearView - ArtImportData.armorSetColors 주 · 보조 · 강조). 메시에는 색 역할만 싣는다:
#   <조각> = 주색 · <조각>_Trim = 보조 · <조각>_Grade = 강조(금속 장식) · <조각>_Glow = Neon(보석 빛).
#   조각 = R15 파트 로컬(가운데 원점 · Y 위 · −Z 앞)로 짓고 기준 체형(make_armor_wear.REF) 자리에 놓아 내보낸다 - 메타는 armor_wear.meta.json에 합친다
#   (같은 착용 코드가 읽는다 · 키 = <부위>_<직업>_<외형>). 착용 코드가 붙는 파트 실측 크기로 맞추므로(껍데기 ≤ 0.15 · 손발 +10%) 튀어나온 장식 없이 몸에 붙는 모양으로 짓는다.
#   중세 판타지 · 깨끗한 장비(해진 천 · 녹 없음) · 전신 단색 슈트 금지(부위마다 역할 색이 섞인다).
# 실행: bash bl.sh make_armor_class.py [--classes greatsword,...] [--slots ...] [--looks ...] [--render 폴더] [--export]
import bpy  # noqa: F401
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import artlib as A  # noqa: E402
import make_armor_wear as AW  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "art", "armor"))
BUDGET = 1050
PART_CAP = 18
REF = AW.REF
yl = AW.yl
ring_y = AW.ring_y
CLASSES = ["greatsword", "dualblade", "bow", "healer"]
SLOTS = ["armor", "gloves", "shoes"]
LOOKS = ["normal", "legendary", "transcendent"]
PIECES = {
    "greatsword": {"armor": [("Chest", "UpperTorso"), ("Shoulder_L", "LeftUpperArm"), ("Shoulder_R", "RightUpperArm"), ("Belt", "LowerTorso"), ("Tasset_L", "LeftUpperLeg"), ("Tasset_R", "RightUpperLeg")]},
    "dualblade": {"armor": [("Chest", "UpperTorso"), ("Shoulder_L", "LeftUpperArm"), ("Shoulder_R", "RightUpperArm"), ("Belt", "LowerTorso")]},
    "bow": {"armor": [("Chest", "UpperTorso"), ("Shoulder_L", "LeftUpperArm"), ("Shoulder_R", "RightUpperArm"), ("Belt", "LowerTorso")]},
    "healer": {"armor": [("Chest", "UpperTorso"), ("Shoulder_L", "LeftUpperArm"), ("Shoulder_R", "RightUpperArm"), ("Belt", "LowerTorso"), ("Tasset_L", "LeftUpperLeg"), ("Tasset_R", "RightUpperLeg")]},
}
for _c in CLASSES:
    PIECES[_c]["gloves"] = [("Glove_L", "LeftHand"), ("Glove_R", "RightHand"), ("Bracer_L", "LeftLowerArm"), ("Bracer_R", "RightLowerArm")]
    PIECES[_c]["shoes"] = [("Boot_L", "LeftFoot"), ("Boot_R", "RightFoot"), ("Greave_L", "LeftLowerLeg"), ("Greave_R", "RightLowerLeg")]
# 미리보기 색(렌더 전용 - 게임 색은 ArtImportData.armorSetColors · 여기 값 = 석조 평원)
PREVIEW = dict(base=(150, 138, 120), trim=(104, 140, 84), grade=(176, 128, 70), glow=(255, 244, 214))


def band(y0, y1, w, d, b=0.12, dz=0.0):
    """세로 껍데기 띠(파트를 감싸는 짧은 통)"""
    return yl([(y0, w, d, dz), (y1, w, d, dz)], b)


def strap(p0, p1, w=0.14, t=0.05):
    """두 점 사이의 납작한 끈(앞면에 붙는 가죽 · 금속 띠)"""
    return A.tube([p0, p1], w / 2, sides=4, flat=t / w)


def studs(pts, r=0.05):
    return A.merge(*[A.ellipsoid((r, r, r * 0.7), n=5, rings=2, center=p) for p in pts])


def gem(center, r=0.1, m=None):
    return A.crystal(r * 2.2, r, sides=5, tip_h=r * 0.8, base_h=r * 0.6, center=center, m=m if m is not None else A.rot(rx=90))


# 역할(조각 이름 접미사 · 착용 코드가 칠하는 색): base = "" 세트 주색(천 · 염색 가죽) · trim = _Trim 세트 보조 · grade = _Grade 세트 강조(금속 장식)
#   steel = _Steel 강철(중립) · leather = _Leather 가죽(중립) · glow = _Glow Neon. 중립 역할 덕에 한 벌이 세트 한 색으로 칠해지지 않는다(전신 단색 슈트 금지 - Play 1차: 쌍검 tier5가 남색 한 벌).
ROLE_SUFFIX = {"base": "", "trim": "_Trim", "grade": "_Grade", "steel": "_Steel", "leather": "_Leather", "glow": "_Glow"}
ROLE_ORDER = ["base", "steel", "leather", "trim", "grade", "glow"]
PREVIEW.update(steel=(186, 192, 204), leather=(112, 76, 50))


def R():
    return {k: [] for k in ROLE_ORDER}


# ────────────────────────── 몸통(UpperTorso 2 × 1.6 × 1) ──────────────────────────
def chest(cls):
    r = R()
    if cls == "greatsword":  # 판금 가슴판(강철 · 목 가리개) + 세트 색 태바드(앞 가운데) · 등 망토 조각 + 문장 자리
        r["steel"].append(yl([(-0.8, 2.1, 1.16, 0.0), (-0.3, 2.18, 1.22, -0.03), (0.35, 2.22, 1.26, -0.05), (0.8, 1.8, 1.08, 0.0)], 0.3))
        r["steel"].append(ring_y(0.84, 0.56, 0.42, 0.08, 0.14, n=8))
        r["base"].append(A.box(0.62, 1.5, 0.05, b=0.04, center=(0, -0.05, -0.66)))
        r["base"].append(A.xform(A.box(1.5, 1.3, 0.05, b=0.05), t=(0, 0.02, 0.64)))
        r["grade"].append(A.xform(A.box(0.34, 0.4, 0.04, b=0.06), t=(0, 0.25, -0.69)))  # (태바드 밑단 보조 띠는 뺐다 - 조각 수 상한 18)
    elif cls == "dualblade":  # 세트 색 가죽 조끼 + 사슬 속옷 밑단(강철) + X자 교차 벨트(가죽)
        r["base"].append(yl([(-0.62, 2.12, 1.16, 0.0), (0.2, 2.16, 1.18, -0.02), (0.8, 1.78, 1.06, 0.0)], 0.28))
        r["steel"].append(band(-0.8, -0.6, 2.16, 1.18, 0.28))
        r["leather"].append(strap((-0.85, 0.72, -0.62), (0.8, -0.62, -0.62), 0.16, 0.05))
        r["leather"].append(strap((0.85, 0.72, -0.62), (-0.8, -0.62, -0.62), 0.16, 0.05))
        r["trim"].append(ring_y(0.78, 0.5, 0.4, 0.05, 0.1, n=8))
        r["grade"].append(A.box(0.2, 0.2, 0.06, b=0.04, center=(0, 0.05, -0.66)))
    elif cls == "bow":  # 세트 색 누빔 조끼 + 목 뒤 내린 후드(보조) + 화살통 끈(가죽)
        r["base"].append(yl([(-0.8, 2.1, 1.14, 0.0), (0.2, 2.14, 1.16, -0.02), (0.8, 1.76, 1.04, 0.0)], 0.3))
        r["base"] += [A.box(1.9, 0.05, 0.05, center=(0, y, -0.6)) for y in (-0.45, -0.1, 0.25)]
        r["trim"].append(A.xform(A.ellipsoid((0.7, 0.28, 0.36), n=10, rings=3, squash_bottom=0.4), t=(0, 0.74, 0.34)))
        r["leather"].append(strap((0.78, 0.76, -0.6), (-0.9, -0.7, -0.6), 0.16, 0.05))
        r["leather"].append(strap((0.78, 0.76, 0.6), (-0.9, -0.7, 0.6), 0.16, 0.05))
        r["grade"].append(A.box(0.16, 0.16, 0.06, b=0.03, center=(0.28, 0.35, -0.64)))
    else:  # healer: 세트 색 로브 + 앞 태바드(보조) + 문양 · 금속 목깃(강조)
        r["base"].append(yl([(-0.8, 2.12, 1.16, 0.0), (0.3, 2.16, 1.18, -0.02), (0.8, 1.78, 1.06, 0.0)], 0.3))
        r["trim"].append(A.box(0.8, 1.5, 0.06, b=0.05, center=(0, -0.02, -0.63)))
        r["grade"].append(A.xform(A.box(0.4, 0.4, 0.05, b=0.02), m=A.rot(rz=45), t=(0, 0.12, -0.67)))
        r["grade"].append(ring_y(0.82, 0.54, 0.42, 0.1, 0.16, n=10))
    return r


def shoulder(cls, side):  # UpperArm(1 × 1.17 × 1) 위쪽 - 팔 움직임에 안 박히게 윗팔에 붙는다
    r = R()
    if cls == "greatsword":  # 판금 어깨판 두 겹(강철) + 세트 보조 테
        r["steel"].append(A.ellipsoid((0.64, 0.46, 0.62), n=10, rings=4, center=(side * 0.05, 0.36, 0), squash_bottom=0.25))
        r["steel"].append(A.ellipsoid((0.62, 0.24, 0.6), n=10, rings=3, center=(side * 0.05, 0.02, 0), squash_bottom=0.3))
        r["trim"].append(ring_y(-0.08, 0.63, 0.61, 0.04, 0.07, n=10))
    elif cls == "dualblade":  # 짧은 어깨 망토(세트 색) + 가죽 테
        r["base"].append(A.ellipsoid((0.62, 0.4, 0.6), n=9, rings=3, center=(side * 0.04, 0.34, 0), squash_bottom=0.3))
        r["leather"].append(ring_y(0.04, 0.62, 0.6, 0.04, 0.08, n=9))
    elif cls == "bow":  # 짧은 망토 어깨(세트 색 천) + 보조 테
        r["base"].append(A.ellipsoid((0.62, 0.42, 0.6), n=9, rings=3, center=(0, 0.32, 0), squash_bottom=0.5))
        r["trim"].append(ring_y(0.0, 0.62, 0.6, 0.03, 0.06, n=9))
    else:  # healer: 천 소매 윗단(세트 색) + 보조 테
        r["base"].append(band(0.1, 0.58, 1.14, 1.14, 0.2))
        r["trim"].append(ring_y(0.12, 0.58, 0.58, 0.04, 0.08, n=10))
    return r


def belt(cls):  # LowerTorso(2 × 0.4 × 1)
    r = R()
    if cls == "greatsword":  # 판금 허리(강철) + 가죽 띠 + 버클
        r["steel"].append(band(-0.2, 0.2, 2.18, 1.18, 0.28))
        r["leather"].append(band(-0.04, 0.08, 2.22, 1.22, 0.28))
        r["grade"].append(A.box(0.22, 0.2, 0.06, b=0.04, center=(0, 0.02, -0.64)))
    elif cls == "dualblade":  # 가죽 띠 + 세트 색 주머니 둘
        r["leather"].append(band(-0.12, 0.1, 2.2, 1.2, 0.28))
        r["base"] += [A.box(0.3, 0.26, 0.12, b=0.05, center=(x, -0.06, -0.62)) for x in (-0.55, 0.55)]
        r["grade"].append(A.box(0.18, 0.18, 0.05, b=0.03, center=(0, 0.0, -0.64)))
    elif cls == "bow":  # 가죽 띠 + 옆 주머니(보조)
        r["leather"].append(band(-0.12, 0.1, 2.2, 1.2, 0.28))
        r["trim"].append(A.box(0.12, 0.3, 0.34, b=0.05, center=(1.08, -0.06, 0.0)))
        r["grade"].append(A.box(0.16, 0.16, 0.05, b=0.03, center=(0, 0.0, -0.64)))
    else:  # healer: 허리 장식 띠(보조)
        r["trim"].append(band(-0.14, 0.12, 2.2, 1.2, 0.28))
        r["grade"].append(A.box(0.24, 0.2, 0.06, b=0.05, center=(0, 0.0, -0.64)))
    return r


def tasset(cls, side):  # UpperLeg(1 × 1.22 × 1) - 다리와 같이 움직인다(허리 치마가 허벅지에 안 박히게)
    r = R()
    if cls == "greatsword":  # 사슬 치마(강철) + 앞 태바드 자락(세트 색)
        r["steel"].append(yl([(0.0, 1.12, 1.12, 0), (0.62, 1.1, 1.1, 0)], 0.2))
        r["base"].append(A.box(0.5, 0.7, 0.05, b=0.03, center=(-side * 0.22, 0.26, -0.6)))
    else:  # healer: 로브 치마(앞 · 뒤 · 바깥 판 - 다리 사이는 비운다)
        r["base"].append(A.box(0.92, 1.0, 0.06, b=0.04, center=(0, 0.1, -0.6)))
        r["base"].append(A.box(0.92, 1.0, 0.06, b=0.04, center=(0, 0.1, 0.6)))
        r["base"].append(A.box(0.06, 1.0, 1.1, b=0.03, center=(side * 0.58, 0.1, 0)))
    return r


# ────────────────────────── 장갑(Hand 1 × 0.3 × 1 · LowerArm 1 × 1.05 × 1) ──────────────────────────
def hand_shell(z0, z1, w=1.04, h=0.32):
    return A.loft([[(x, y, z) for x, y in A.chamfer_rect(w, h, 0.1)] for z in (z0, z1)])


def glove(cls, side):
    r = R()
    if cls == "greatsword":  # 얇은 판금 건틀릿(강철) + 가죽 손바닥 띠
        r["steel"].append(yl([(-0.16, 1.04, 1.04, 0), (0.16, 1.06, 1.06, 0)], 0.16))
        r["leather"].append(A.box(0.9, 0.06, 0.12, b=0.02, center=(0, 0.12, -0.44)))
    elif cls == "dualblade":  # 손가락 없는 가죽 장갑(앞 절반은 비운다) + 보조 손목 띠
        r["leather"].append(hand_shell(0.5, -0.1, 1.06, 0.34))
        r["trim"].append(A.box(0.98, 0.08, 0.12, center=(0, 0.0, -0.12)))
    elif cls == "bow":  # 오른손 = 세 손가락 덮개 · 왼손 = 얇은 손목 감개
        if side > 0:
            r["leather"].append(hand_shell(0.5, -0.5))
            r["trim"] += [A.box(0.2, 0.08, 0.3, center=(x, 0.12, -0.36)) for x in (-0.26, 0.0, 0.26)]
        else:
            r["leather"].append(hand_shell(0.5, 0.2))
    else:  # healer: 얇은 천 감개(세트 색)
        r["base"].append(hand_shell(0.5, 0.05))
    return r


def bracer(cls, side):
    r = R()
    if cls == "greatsword":  # 판금 팔 보호대(강철) + 보조 턱
        r["steel"].append(yl([(-0.52, 1.12, 1.12, 0), (0.1, 1.08, 1.08, 0)], 0.2))
        r["trim"].append(ring_y(-0.46, 0.56, 0.56, 0.04, 0.08))
    elif cls == "dualblade":  # 세트 색 가죽 팔 보호대 + 가죽 끈 셋
        r["base"].append(yl([(-0.52, 1.1, 1.1, 0), (0.2, 1.08, 1.08, 0)], 0.2))
        r["leather"] += [ring_y(y, 0.55, 0.55, 0.03, 0.06) for y in (-0.36, -0.1, 0.14)]
    elif cls == "bow":  # 왼팔 = 활쏘기 팔찌(가죽 · 안쪽 세트 색 판 · 끈) · 오른팔 = 가는 띠
        if side < 0:
            r["leather"].append(yl([(-0.52, 1.12, 1.12, 0), (0.3, 1.1, 1.1, 0)], 0.2))
            r["base"].append(A.box(0.06, 0.66, 0.7, b=0.03, center=(0.58, -0.1, 0)))
            r["trim"] += [ring_y(y, 0.56, 0.56, 0.03, 0.05) for y in (-0.3, 0.1)]
        else:
            r["leather"].append(band(-0.52, -0.3, 1.08, 1.08, 0.2))
    else:  # healer: 천 소매 끝(나팔형 · 세트 색) + 얇은 금속 팔찌(강조)
        r["base"].append(yl([(-0.3, 1.16, 1.16, 0), (0.5, 1.08, 1.08, 0)], 0.2))
        r["grade"].append(ring_y(-0.4, 0.55, 0.55, 0.03, 0.06))
    return r


# ────────────────────────── 신발(Foot 1 × 0.3 × 1 · LowerLeg 1 × 1.19 × 1) ──────────────────────────
def boot(cls):
    r = R()
    shell = A.loft([[(x, y + yc, z) for x, y in A.chamfer_rect(w, h, 0.08)] for z, w, h, yc in ((0.5, 1.04, 0.34, 0.0), (-0.1, 1.06, 0.34, 0.0), (-0.5, 0.94, 0.28, -0.02))])
    sole = A.box(1.08, 0.07, 1.0, center=(0, -0.15, 0.0))
    if cls == "greatsword":  # 가죽 발등 + 강철 앞코
        r["leather"].append(shell)
        r["steel"].append(A.loft([[(x, y - 0.01, z) for x, y in A.chamfer_rect(w, h, 0.07)] for z, w, h in ((-0.1, 1.08, 0.36), (-0.52, 0.96, 0.3))]))
    elif cls == "dualblade":  # 부드러운 가죽 부츠 + 보조 밑창
        r["leather"].append(shell)
        r["trim"].append(sole)
    elif cls == "bow":  # 레인저 부츠(가죽) + 세트 색 발등 끈 + 보조 밑창
        r["leather"].append(shell)
        r["base"].append(strap((-0.5, 0.12, -0.1), (0.5, 0.12, -0.1), 0.12, 0.04))
        r["trim"].append(sole)
    else:  # healer: 천 신발(세트 색) + 금속 발끝(강조)
        r["base"].append(shell)
        r["grade"].append(A.loft([[(x, y, z) for x, y in A.chamfer_rect(w, h, 0.06)] for z, w, h in ((-0.3, 1.0, 0.34), (-0.52, 0.9, 0.28))]))
    return r


def greave(cls):
    r = R()
    if cls == "greatsword":  # 판금 정강이 + 무릎 받이(강철) + 보조 띠
        r["steel"].append(yl([(-0.6, 1.1, 1.1, -0.02), (0.45, 1.08, 1.1, -0.03)], 0.2))
        r["steel"].append(A.ellipsoid((0.34, 0.22, 0.16), n=8, rings=3, center=(0, 0.5, -0.54)))
        r["trim"].append(ring_y(-0.1, 0.56, 0.56, 0.03, 0.08))
    elif cls == "dualblade":  # 가죽 부츠 목 + 세트 색 무릎 보호대
        r["leather"].append(yl([(-0.6, 1.08, 1.08, 0), (0.2, 1.06, 1.06, 0)], 0.2))
        r["base"].append(A.ellipsoid((0.36, 0.26, 0.14), n=8, rings=3, center=(0, 0.46, -0.54)))
    elif cls == "bow":  # 긴 가죽 부츠 목 + 접은 윗단(세트 색) + 보조 끈
        r["leather"].append(yl([(-0.6, 1.08, 1.08, 0), (0.3, 1.06, 1.06, 0)], 0.2))
        r["base"].append(band(0.3, 0.52, 1.14, 1.14, 0.2))
        r["trim"].append(ring_y(-0.2, 0.55, 0.55, 0.03, 0.05))
    else:  # healer: 천 감개(아래 절반 · 세트 색) + 보조 줄
        r["base"].append(yl([(-0.6, 1.06, 1.06, 0), (-0.05, 1.04, 1.04, 0)], 0.2))
        r["trim"] += [ring_y(y, 0.54, 0.54, 0.02, 0.04) for y in (-0.42, -0.2)]
    return r


# ────────────────────────── 외형(등급 계열) ──────────────────────────
def look_extra(cls, kind, side, look, r):
    """전설 = 금속 장식(강조색) + 보석(Neon) · 초월 = 전설 + 금 테 더 + 금빛 균열(색은 착용 코드가 흑금으로)"""
    g, gl = r["grade"], r["glow"]
    if look == "normal":
        return
    if kind == "Chest":
        g.append(ring_y(-0.74, 1.1, 0.61, 0.03, 0.08, n=10))
        gl.append(gem((0, 0.3, -0.7), 0.1))
    elif kind == "Shoulder":
        g.append(ring_y(0.34 if cls != "healer" else 0.5, 0.64, 0.62, 0.03, 0.05, n=9))
        g.append(studs([(side * 0.1, 0.62, -0.42), (side * 0.1, 0.62, 0.42)], 0.06))
    elif kind == "Belt":
        gl.append(gem((0, 0.02, -0.7), 0.07))
    elif kind in ("Bracer", "Greave"):
        g.append(ring_y(0.02 if kind == "Bracer" else 0.2, 0.57, 0.57, 0.03, 0.05))
    elif kind in ("Glove", "Boot"):
        g.append(studs([(x, 0.14 if kind == "Glove" else 0.12, -0.2) for x in (-0.25, 0.25)], 0.05))
    if look == "transcendent":
        if kind == "Chest":
            g.append(A.box(0.06, 1.1, 0.04, center=(-0.5, 0.0, -0.64)))
            g.append(A.box(0.06, 1.1, 0.04, center=(0.5, 0.0, -0.64)))
            gl.append(A.xform(A.box(0.04, 0.5, 0.03), m=A.rot(rz=20), t=(-0.2, -0.3, -0.66)))
        elif kind == "Shoulder":
            g.append(A.xform(A.box(0.04, 0.04, 0.5), t=(side * 0.2, 0.74, 0)))


def piece_meshes(cls, slot, look, piece):
    kind = piece.split("_")[0]
    side = -1 if piece.endswith("_L") else 1
    fn = {"Chest": lambda: chest(cls), "Shoulder": lambda: shoulder(cls, side), "Belt": lambda: belt(cls), "Tasset": lambda: tasset(cls, side),
          "Glove": lambda: glove(cls, side), "Bracer": lambda: bracer(cls, side), "Boot": lambda: boot(cls), "Greave": lambda: greave(cls)}[kind]
    r = fn()
    look_extra(cls, kind, side, look, r)
    return [(ROLE_SUFFIX[role], A.merge(*r[role]), role, role == "glow") for role in ROLE_ORDER if r[role]]


def build(cls, slot, look):
    col = A.new_collection("%s_%s_%s" % (slot, cls, look))
    objs, info = [], {}
    for piece, part in PIECES[cls][slot]:
        pc, _ = REF[part]
        for suffix, geo, role, neon in piece_meshes(cls, slot, look, piece):
            name = piece + suffix
            o = A.make_obj(name, A.xform(geo, t=pc), PREVIEW[role], col, neon=neon, origin=pc, mat_name="%s_%s_%s_%s" % (slot, cls, look, name))
            objs.append(o)
            info[name] = part
    return col, objs, info


def parse():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opt = {"classes": CLASSES, "slots": SLOTS, "looks": LOOKS, "render": None, "export": False}
    i = 0
    while i < len(argv):
        a = argv[i]
        if a in ("--classes", "--slots", "--looks"):
            opt[a[2:]] = argv[i + 1].split(","); i += 1
        elif a == "--render":
            opt["render"] = os.path.abspath(argv[i + 1]); i += 1
        elif a == "--export":
            opt["export"] = True
        i += 1
    return opt


def main():
    opt = parse()
    stats, pieces_meta = {}, {}
    for cls in opt["classes"]:
        for slot in opt["slots"]:
            for look in opt["looks"]:
                A.reset()
                col, objs, info = build(cls, slot, look)
                tri = sum(A.tri_count(o) for o in objs)
                key = "%s_%s_%s" % (slot, cls, look)
                stats[key] = dict(tris=tri, parts=len(objs))
                if len(objs) > PART_CAP or tri > BUDGET:
                    print("[make_armor_class] 상한 초과", key, tri, len(objs))
                if opt["export"]:
                    A.export_fbx(os.path.join(OUT, "%s.fbx" % key), objs)
                    for o in objs:
                        pc = REF[info[o.name]][0]
                        cen = A.roblox_center(o)
                        pieces_meta.setdefault(key, {})[o.name] = dict(attach=info[o.name], offset=[round(cen[i] - pc[i], 3) for i in range(3)],
                                                                       refSize=list(REF[info[o.name]][1]), tris=A.tri_count(o), neon=bool(o.get("Neon", False)))
                if opt["render"]:
                    man = AW.mannequin(slot)
                    A.render_views(objs + man, os.path.join(opt["render"], key), views=("front", "34"), kinds=("game",), sil=False, hull=0.03, res=(520, 700))
    worst = max(stats.items(), key=lambda kv: kv[1]["tris"])
    print("[make_armor_class] %d개 · 삼각형 최소 %d · 최대 %s · 파트 최대 %d" % (len(stats), min(v["tris"] for v in stats.values()), worst, max(v["parts"] for v in stats.values())))
    if opt["export"]:
        path = os.path.join(OUT, "armor_wear.meta.json")
        old = json.load(open(path, encoding="utf-8")) if os.path.exists(path) else {}
        allp = old.get("pieces", {})
        allp.update(pieces_meta)
        allt = old.get("tris", {})
        allt.update(stats)
        old.update({"pieces": allp, "tris": allt, "classes": CLASSES})
        A.write_json(path, old)
    print("[make_armor_class] 끝")


if __name__ == "__main__":
    main()
