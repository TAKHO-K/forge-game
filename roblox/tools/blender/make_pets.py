# -*- coding: utf-8 -*-
# A2-N1 펫(Blender bpy): PetData.rigs 몸 틀 3종(dog · cat · dragon) × 알 등급 3(normal · good · rare) 외형 차이.
#   파트 이름 · 중심 위치 = PetData 그대로(코드가 이름 · 중심으로 움직인다 - 원점 = 파트 pos) · 파트 수 고정(≤ 8) → 등급 차이는 같은 파트 안의 형태 추가:
#     A2-N2: 보통 = 기본형 · 좋은 = 장식 1개 · 희귀 = 장식 + 보석 빛 + 무늬 + 작은 왕관(아래 NECK 주석).
#   색 = 코드가 구역 색을 입힌다(여기 색은 렌더용: base = 구역 색 예시 · accent = ×0.55 · eye = 검정). 크기 = 캐릭터 머리(≈ 1.2).
#   예산 = art-direction §6에 펫 칸이 없어 무기와 같은 800(따라다니는 모델) - 보고서 결정 필요.
# 실행: bash bl.sh make_pets.py --items dog:normal,dog:good,... [--render 폴더] [--old] [--no-export]
import bpy
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import artlib as A  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "art", "pets"))
BUDGET = 800
RANK = {"normal": 0, "good": 1, "rare": 2}
BASE = {"dog": (170, 90, 255), "cat": (40, 140, 255), "dragon": (255, 150, 60)}  # 렌더 예시 = 구역 관문 색(T1 · T3 · T4)

# PetData.rigs 그대로(이름 · 크기 · 중심 · 색 역할 · 쐐기)
RIGS = {
    "dog": [("Body", (0.7, 0.55, 1.0), (0, 0, 0), "base"), ("Head", (0.6, 0.55, 0.55), (0, 0.4, -0.6), "base"), ("Ear_L", (0.14, 0.3, 0.2), (-0.26, 0.62, -0.55), "accent"),
            ("Ear_R", (0.14, 0.3, 0.2), (0.26, 0.62, -0.55), "accent"), ("Leg_F", (0.6, 0.3, 0.2), (0, -0.4, -0.3), "accent"), ("Leg_B", (0.6, 0.3, 0.2), (0, -0.4, 0.3), "accent"),
            ("Tail", (0.14, 0.14, 0.4), (0, 0.2, 0.62), "accent"), ("Eyes", (0.4, 0.1, 0.05), (0, 0.48, -0.88), "eye")],
    "cat": [("Body", (0.6, 0.5, 1.0), (0, 0, 0), "base"), ("Head", (0.6, 0.5, 0.5), (0, 0.42, -0.58), "base"), ("Ear_L", (0.18, 0.24, 0.1), (-0.2, 0.78, -0.58), "accent"),
            ("Ear_R", (0.18, 0.24, 0.1), (0.2, 0.78, -0.58), "accent"), ("Leg_F", (0.5, 0.3, 0.18), (0, -0.38, -0.3), "accent"), ("Leg_B", (0.5, 0.3, 0.18), (0, -0.38, 0.3), "accent"),
            ("Tail", (0.12, 0.7, 0.12), (0, 0.35, 0.6), "accent"), ("Eyes", (0.38, 0.1, 0.05), (0, 0.48, -0.84), "eye")],
    "dragon": [("Body", (0.6, 0.55, 0.9), (0, 0, 0), "base"), ("Head", (0.55, 0.5, 0.6), (0, 0.4, -0.6), "base"), ("Horn", (0.4, 0.2, 0.1), (0, 0.72, -0.5), "accent"),
               ("Wing_L", (0.9, 0.06, 0.5), (-0.7, 0.3, 0), "accent"), ("Wing_R", (0.9, 0.06, 0.5), (0.7, 0.3, 0), "accent"), ("Tail", (0.16, 0.16, 0.7), (0, 0, 0.75), "accent"),
               ("Eyes", (0.36, 0.1, 0.05), (0, 0.48, -0.91), "eye")],
}


def color(role, body):
    return {"base": BASE[body], "accent": A.mul(BASE[body], 0.55), "eye": (25, 18, 22)}[role]


def add(a, b):
    return tuple(a[i] + b[i] for i in range(3))


def eyes(c, dx, r=(0.07, 0.09, 0.04)):
    return A.merge(*[A.ellipsoid(r, n=5, rings=3, center=add(c, (s * dx, 0, 0))) for s in (-1, 1)])


def ruff(center, r, k=8, y=0.0):
    """목 털: 머리와 몸 사이 뾰족 털 고리(좋은 이상)"""
    tufts = []
    for i in range(k):
        a = 2 * math.pi * i / k
        base = add(center, (r * 0.7 * math.cos(a), y, r * 0.7 * math.sin(a)))
        tip = add(center, (r * 1.15 * math.cos(a), y - 0.08, r * 1.15 * math.sin(a)))
        tufts.append(A.tube([base, tip], lambda u: 0.11 * (1 - u) + 0.01, sides=4, tip_end=True))
    return A.merge(A.ellipsoid((r * 0.8, 0.12, r * 0.8), n=8, rings=3, center=add(center, (0, y, 0))), *tufts)


# ── A2-N2 등급 장식(사용자 결정): 보통 = 기본 · 좋은 = 장식 1개(강아지 목줄 · 고양이 리본 · 용 스카프) · 희귀 = 장식 + 빛 포인트(보석) + 무늬 + 작은 왕관.
#   파트 수 고정(PetData ≤ 8)이라 장식은 "움직이지 않는 accent 파트"에 합친다(PetView: Wing · Head만 움직임):
#   장식 · 보석 → Leg_F(용 = Tail) · 무늬 → Leg_B(용 = Tail) · 왕관 → Ear_L(용 = Horn). 보석 빛 = 메타 glowPoint(코드가 PointLight - 영웅 빛과 같은 방식).
NECK = {"dog": ((0, 0.2, -0.44), 0.25, -48), "cat": ((0, 0.2, -0.42), 0.22, -50), "dragon": ((0, 0.22, -0.44), 0.23, -45)}  # 목 중심 · 반경 · 기울기(rx)
HEAD_TOP = {"dog": (0, 0.74, -0.6), "cat": (0, 0.7, -0.58), "dragon": (0, 0.8, -0.62)}
BODY_ELL = {"dog": (0.4, 0.33, 0.54, 0.02), "cat": (0.33, 0.28, 0.52, 0.0), "dragon": (0.32, 0.3, 0.46, 0.0)}
GLOW = {}


def ring_at(center, r, tilt, thick=0.07, flat=0.6):
    pts = [(r * math.cos(a), 0.0, r * math.sin(a)) for a in (2 * math.pi * i / 10 for i in range(11))]
    return A.xform(A.tube(pts, thick, sides=3, cap0=False, flat=flat), m=A.rot(rx=tilt), t=center)


def gem_on(body, where):
    GLOW[body] = where
    return A.crystal(0.22, 0.1, sides=6, tip_h=0.08, base_h=0.06, center=where, m=A.rot(rx=-80))


def small_crown(body):
    """A2-N2 2차(검토 - 띠 왕관이 머리 뭉치로 읽혔다): 얇은 띠 + 뾰족 가시 3(가운데 ×1.3 · 높이 = 머리 높이 35%) + 앞 보석 · 금 Deco 파트"""
    x, y, z = HEAD_TOP[body]
    band = A.lathe([(0.17, -0.035), (0.2, -0.035), (0.2, 0.035), (0.17, 0.035)], 8)
    h = 0.24
    spikes = [A.crystal(h * (1.3 if k == 0 else 1.0), 0.06, sides=4, tip_h=0.14, base_h=0.02, center=(0.19 * math.cos(a), 0.03, 0.19 * math.sin(a)))
              for k, a in enumerate((-math.pi / 2, -math.pi / 2 - 1.0, -math.pi / 2 + 1.0))]
    return A.xform(A.merge(band, *spikes), m=A.rot(rx=-10), t=(x, y + 0.02, z))


def spots(body, pts, r=(0.12, 0.035, 0.1)):
    """몸 윗면 무늬 판(accent) - pts = (x, z) · 높이는 몸 타원면에서"""
    rx, ry, rz, cy = BODY_ELL[body]
    out = []
    for x, z in pts:
        k = max(0.0, 1 - (x / rx) ** 2 - ((z - 0.02) / rz) ** 2)
        out.append(A.ellipsoid(r, n=5, rings=2, center=(x, cy + ry * math.sqrt(k) - 0.005, z), squash_bottom=0.4))
    return A.merge(*out)


def stripes(body, zs):
    rx, ry, rz, cy = BODY_ELL[body]
    out = []
    for z in zs:
        k = math.sqrt(max(0.0, 1 - ((z - 0.02) / rz) ** 2))
        pts = [(rx * k * 1.04 * math.cos(a), cy + ry * k * 1.04 * math.sin(a), z) for a in (math.radians(d) for d in range(30, 160, 40))]
        out.append(A.tube(pts, lambda u: 0.045 * math.sin(math.pi * (0.1 + 0.8 * u)) + 0.012, sides=3, flat=0.5, tip_end=False))
    return A.merge(*out)


def dog(grade):
    g = RANK[grade]
    o = {}
    o["Body"] = A.ellipsoid((0.4, 0.33, 0.54), n=9, rings=5, center=(0, 0.02, 0.02))
    head = A.merge(A.ellipsoid((0.35, 0.32, 0.31), n=9, rings=5, center=(0, 0.42, -0.6)),
                   A.ellipsoid((0.17, 0.13, 0.16), n=7, rings=4, center=(0, 0.33, -0.86)),  # 주둥이
                   A.ellipsoid((0.06, 0.05, 0.05), n=6, rings=3, center=(0, 0.38, -1.0)))  # 코
    o["Head"] = head
    for n, s in (("Ear_L", -1), ("Ear_R", 1)):  # 늘어진 귀(안쪽 → 바깥 아래)
        path = [(s * 0.2, 0.66, -0.56), (s * 0.34, 0.62, -0.54), (s * 0.4, 0.44, -0.52), (s * 0.37, 0.3 if g < 2 else 0.26, -0.5)]
        o[n] = A.tube(A.bezier(*path, n=5), lambda u: 0.09 + 0.03 * math.sin(math.pi * u), sides=5, flat=0.45, tip_end=False)
    for n, z in (("Leg_F", -0.3), ("Leg_B", 0.3)):
        leg = A.merge(A.lathe([(0.0, -0.18), (0.11, -0.16), (0.085, 0.0), (0.09, 0.15), (0.0, 0.16)], 6), A.ellipsoid((0.1, 0.05, 0.12), n=6, rings=2, center=(0, -0.16, -0.04)))
        o[n] = A.merge(*[A.xform(leg, t=(s * 0.2, -0.4, z)) for s in (-1, 1)])  # 다리 한 쌍 = 파트 하나(리그 Leg_F · Leg_B)
    if g >= 1:  # 좋은 = 두꺼운 목줄 + 둥근 이름표
        c, r, tilt = NECK["dog"]
        tag = A.xform(A.lathe([(0.0, -0.035), (0.18, -0.035), (0.18, 0.035), (0.0, 0.035)], 10, axis="Z"), t=(0, -0.02, -0.72))  # 2차: 이름표 지름 ×1.8 · 목줄 두께 ×1.6
        o["Deco"] = A.merge(ring_at(c, r * 1.08, tilt, 0.17), *([tag] if g < 2 else []))  # 3차: 목줄 = 따로 칠하는 Deco 파트(몸 강조색에 묻혔다 - 총괄 검토) · 두께 ×1.3
    if g >= 2:  # 희귀 = 금 Deco(목줄 + 왕관 + 이름표 자리 보석) - 무늬는 뺐다(모음 크기에서 안 보였다 · 예산)
        o["Deco"] = A.merge(o["Deco"], small_crown("dog"), gem_on("dog", (0, -0.02, -0.74)))
    k = 1.0
    tip = (0, 0.12 + 0.24 * k, 0.5 + 0.24 * k)  # 짧은 꼬리(≤ 0.35) · 45° 위 - 고양이의 긴 S자와 구별
    tail = A.tube([(0, 0.1, 0.46), (0, 0.2, 0.6), tip], lambda u: 0.085 * (1 - 0.4 * u) + 0.02, sides=6, tip_end=False)
    o["Tail"] = tail
    o["Eyes"] = eyes((0, 0.5, -0.86), 0.14)
    return o


def cat(grade):
    g = RANK[grade]
    o = {}
    o["Body"] = A.ellipsoid((0.33, 0.28, 0.52), n=9, rings=5, center=(0, 0.0, 0.02))
    head = A.merge(A.ellipsoid((0.36, 0.28, 0.28), n=9, rings=5, center=(0, 0.42, -0.58)),
                   *[A.ellipsoid((0.12, 0.09, 0.1), n=6, rings=3, center=(s * 0.26, 0.32, -0.62)) for s in (-1, 1)])  # 볼 털
    o["Head"] = head
    for n, s in (("Ear_L", -1), ("Ear_R", 1)):  # 세모 귀(희귀 = 귀 끝 털)
        ear = A.xform(A.lathe([(0.0, 0.0), (0.11, 0.0), (0.0, 0.26)], 4), s=(1, 1, 0.55), m=A.rot(rz=-s * 12), t=(s * 0.2, 0.64, -0.58))
        o[n] = ear
    leg = lambda x, z: A.xform(A.merge(A.lathe([(0.0, -0.16), (0.09, -0.16), (0.08, 0.0), (0.075, 0.15), (0.0, 0.16)], 5), A.ellipsoid((0.09, 0.045, 0.1), n=5, rings=2, center=(0, -0.15, -0.03))), t=(x, -0.38, z))
    o["Leg_F"] = A.merge(leg(-0.17, -0.3), leg(0.17, -0.3))
    o["Leg_B"] = A.merge(leg(-0.17, 0.3), leg(0.17, 0.3))
    if g >= 1:  # 좋은 = 목 리본(얇은 띠 + 앞 나비 매듭 - 옆으로 넓은 실루엣)
        c = (0, 0.22, -0.64)
        lobes = [A.ellipsoid((0.19, 0.12, 0.07), n=6, rings=2, center=(c[0] + sgn * 0.19, c[1] + 0.03, c[2] - 0.02)) for sgn in (-1, 1)]  # 2차: 나비 ×1.6
        tails = [A.xform(A.box(0.09, 0.23, 0.05, b=0.015), m=A.rot(rz=sgn * 25), t=(c[0] + sgn * 0.09, c[1] - 0.17, c[2] - 0.02)) for sgn in (-1, 1)]  # 늘어짐 ×1.8
        o["Deco"] = A.merge(ring_at(*NECK["cat"], thick=0.1), A.ellipsoid((0.09, 0.09, 0.07), n=5, rings=2, center=c), *lobes, *tails)  # 3차: 리본 = Deco 파트(대비 색) · 띠 두께 ×1.3
    if g >= 2:  # 희귀 = 금 Deco(리본 + 왕관 + 리본 가운데 보석) - 줄무늬는 뺐다
        o["Deco"] = A.merge(o["Deco"], small_crown("cat"), gem_on("cat", (0, 0.22, -0.74)))
    k = 1.0
    tail_path = A.bezier((0, 0.05, 0.5), (0, 0.2, 0.75), (0, 0.55 * k, 0.55), (0.12, 0.78 * k, 0.72), n=7)  # 위로 선 S자 긴 꼬리
    o["Tail"] = A.tube(tail_path, lambda u: 1.2 * (0.07 * (1 - 0.3 * u) + 0.02), sides=5, tip_end=False)
    o["Eyes"] = eyes((0, 0.48, -0.83), 0.14, r=(0.065, 0.1, 0.04))
    return o


def pet_wing(s, fingers):
    """작은 막 날개(XY 평면에 짓고 앞 −Z로 두께) - 손가락 수 = 등급"""
    tips = [(0.95, 0.42), (0.9, 0.0), (0.62, -0.3)][:fingers]
    outline = [(0.05, 0.12)]
    prev = None
    for fx, fy in tips:
        if prev:
            outline.append(((prev[0] + fx) / 2 * 0.78, (prev[1] + fy) / 2 * 0.78))
        outline.append((fx, fy))
        prev = (fx, fy)
    outline.append((0.08, -0.18))
    n = len(outline)
    v = [(x, y, 0.03) for x, y in outline] + [(x, y, -0.03) for x, y in outline]
    f = [tuple(range(n)), tuple(reversed(range(n, 2 * n)))] + [(i, n + i, n + (i + 1) % n, (i + 1) % n) for i in range(n)]
    bones = [A.tube([(0.0, 0.05, 0), (fx, fy, 0)], lambda u: 0.045 * (1 - u) + 0.012, sides=4, tip_end=True) for fx, fy in tips]
    g = A.merge((v, f), *bones)
    g = A.xform(g, m=A.rot(rx=40))  # 날개 판을 50° 기울인다(수평이면 정면에서 선 · 세우면 Z축 날갯짓이 판 안에서 돌아 안 보인다)
    return A.mirror_x(g) if s < 0 else g


def dragon(grade):
    g = RANK[grade]
    o = {}
    body = A.ellipsoid((0.32, 0.3, 0.46), n=9, rings=5, center=(0, 0, 0.02))
    belly = A.ellipsoid((0.22, 0.2, 0.3), n=8, rings=4, center=(0, -0.08, -0.12))
    o["Body"] = A.merge(body, belly)
    o["Head"] = A.xform(A.merge(A.ellipsoid((0.3, 0.27, 0.3), n=9, rings=5, center=(0, 0.42, -0.58)), A.ellipsoid((0.2, 0.14, 0.18), n=7, rings=4, center=(0, 0.34, -0.84))), s=(1.15, 1.15, 1.15), t=(0, 0.42 * -0.15, -0.6 * -0.15))  # 머리 ×1.15(중심 고정)
    horns = [A.tube(A.bezier((s * 0.13, 0.6, -0.52), (s * 0.18, 0.74, -0.46), (s * 0.2, 0.84, -0.36), (s * 0.18, 0.88, -0.28), n=4), lambda u: 0.06 * (1 - u) + 0.01, sides=5, tip_end=True) for s in (-1, 1)]
    o["Horn"] = A.merge(*horns)
    fingers = 2  # 날개 뼈 2갈래(몸을 삼키지 않게)
    for n, s in (("Wing_L", -1), ("Wing_R", 1)):
        o[n] = A.xform(pet_wing(s, fingers), m=A.rot(rz=s * 32), t=(s * 0.22, 0.3, 0.0), s=(0.7, 1, 0.7))  # 폭 70%
    tail = A.tube(A.bezier((0, 0.0, 0.4), (0, -0.05, 0.7), (0.08, 0.05, 0.95), (0.15, 0.15, 1.1), n=6), lambda u: 0.12 * (1 - u) + 0.03, sides=6, tip_end=False)
    spade = 0.13
    tail = A.merge(tail, A.xform(A.lathe([(0.0, 0.0), (spade, 0.08), (spade * 0.6, 0.18), (0.0, 0.3)], 4), s=(1, 1, 0.35), m=A.rot(rx=-60), t=(0.15, 0.15, 1.1)))
    if g >= 1:  # 좋은 = 목 스카프(고리 + 오른 어깨 뒤로 날리는 두 자락) - 움직이지 않는 Tail 파트에 합침
        c, r, tilt = NECK["dragon"]
        ends = [A.tube(A.bezier((0.18, 0.26, -0.36), (0.45, 0.3, -0.12), (0.6 + 0.1 * k_, 0.16 - 0.16 * k_, 0.2), (0.72 + 0.12 * k_, 0.06 - 0.24 * k_, 0.55), n=5),
                       lambda u: 0.13 * (1 - 0.4 * u) + 0.03, sides=4, flat=0.35, tip_end=True) for k_ in (0, 1)]  # 2차: 두께 ×1.6 · 날림 ×1.8
        o["Deco"] = A.merge(ring_at(c, r * 1.06, tilt, 0.18), *ends)  # 3차: 스카프 = Deco 파트(대비 색)
    if g >= 2:  # 희귀 = 금 Deco(스카프 + 뿔 사이 왕관 + 스카프 매듭 보석) - 비늘 무늬는 뺐다
        o["Deco"] = A.merge(o["Deco"], small_crown("dragon"), gem_on("dragon", (0.1, 0.3, -0.68)))
    o["Tail"] = tail
    o["Eyes"] = eyes((0, 0.48, -0.86), 0.13, r=(0.07, 0.09, 0.04))
    return o


BUILD = {"dog": dog, "cat": cat, "dragon": dragon}


def old_geo(size, pos, wedge=False):
    return A.box(*size, center=pos)


DECO_GOLD = (242, 201, 76)  # 2차: 희귀 장식 = 금(구역 강조색에 묻혔다 - 검토)
DECO_GOOD = {"dog": (63, 201, 181), "cat": (255, 181, 71), "dragon": (63, 201, 181)}  # 3차: 좋은 장식 = 몸(구역 색)과 대비 - 강아지 · 용 청록 #3FC9B5 · 고양이 살구 #FFB547(렌더 예시 색 기준 · 게임은 코드가 구역 색 보색을 고른다)


def build(body, grade, old=False):
    col = A.new_collection("%s%s_%s" % ("old_" if old else "", body, grade))
    geos = None if old else BUILD[body](grade)
    objs = []
    rig = list(RIGS[body])
    if geos and "Deco" in geos:
        if body in ("dog", "cat"):  # 파트 상한 8: 움직이지 않는 Tail을 Leg_B에 합쳐 자리를 만든다(PetView = Wing · Head만 움직임)
            geos["Leg_B"] = A.merge(geos["Leg_B"], geos.pop("Tail"))
            rig = [r for r in rig if r[0] != "Tail"]
        rig.append(("Deco", None, HEAD_TOP[body], "deco"))
    for name, size, pos, role in rig:
        geo = old_geo(size, pos) if old else geos[name]
        c = (DECO_GOLD if grade == "rare" else DECO_GOOD[body]) if role == "deco" else color(role, body)
        objs.append(A.make_obj(name, geo, c, col, origin=pos, mat_name="%s%s_%s_%s" % ("old_" if old else "", body, grade, name)))
    return col, objs


def parse():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opt = {"items": [], "render": None, "export": True, "old": False}
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--items":
            opt["items"] = [tuple(x.split(":")) for x in argv[i + 1].split(",")]; i += 1
        elif a == "--render":
            opt["render"] = os.path.abspath(argv[i + 1]); i += 1
        elif a == "--no-export":
            opt["export"] = False
        elif a == "--old":
            opt["old"] = True
        i += 1
    return opt


def main():
    opt = parse()
    A.reset()
    metas = {}
    for body, grade in opt["items"]:
        col, objs = build(body, grade)
        total = sum(A.tri_count(o) for o in objs)
        print("[make_pets] %s %s 파트 %d · 삼각형 %d / %d = %.0f%% · %s" % (body, grade, len(objs), total, BUDGET, 100 * total / BUDGET, {o.name: A.tri_count(o) for o in objs}))
        metas.setdefault(body, {})[grade] = A.meta_of(objs, BUDGET)
        if opt["export"]:
            A.export_fbx(os.path.join(OUT, "%s_%s.fbx" % (body, grade)), objs)
        if opt["render"]:
            A.render_views(objs, os.path.join(opt["render"], "%s_%s" % (body, grade)), views=("front", "34", "side"), hull=0.02, res=(600, 600))
        for o in objs:
            o.name = "%s.%s" % (o.name, grade)
            o.hide_render = True
        if opt["old"] and grade == "normal" and opt["render"]:
            _, olds = build(body, grade, old=True)
            A.render_views(olds, os.path.join(opt["render"], "old_%s" % body), views=("34",), kinds=("game",), sil=False, hull=0.02, res=(600, 600))
            for o in olds:
                o.hide_render = True
    if opt["export"]:
        for body, looks in metas.items():
            A.write_json(os.path.join(OUT, "%s.meta.json" % body), {"version": "A2-N2", "body": body, "pivot": "파트 중심(PetData pos)", "triBudget": BUDGET, "looks": looks,
                                                                   "gradeDeco": "3차: 좋은 · 희귀 모두 새 파트 Deco(좋은 = 목줄 · 리본 · 스카프를 몸과 대비 색 - 예 청록 #3FC9B5 · 살구 #FFB547 / 희귀 = 장식 + 왕관 가시 3 + 보석 금 #F2C94C · 원점 = 머리 위) · 강아지 · 고양이는 좋은 · 희귀 둘 다 Tail을 Leg_B에 합침(파트 8 유지 - PetData.rigs 좋은 · 희귀 표 필요) · 눈 흰자 + 점은 파트 상한 8이라 불가(결정 후보)",
                                                                   "glowPoint": list(GLOW.get(body, (0, 0, 0))), "glowNote": "희귀 알 펫 = 이 자리(몸 기준)에 PointLight(범위 4 · 밝기 1 · 구역 색) - 코드"})
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "pets.blend"))
    print("[make_pets] 끝")


if __name__ == "__main__":
    main()
