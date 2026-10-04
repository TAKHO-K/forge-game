# -*- coding: utf-8 -*-
# QUEUE-ALL9E1 LOOK3(10-04 밤 · 사용자 "아이콘 요청안을 최대한 · 렉 감수"): 장비 3D를 아이콘 수준으로. 규격 = docs/design/gear-art-v3.md 3-1(색 구역) · 3-2(LOOK3 예산).
#   메시 = 직업 4 × 부위 3 × 등급 8 = 96벌(문 부품 없음 - 등급마다 메시) · 키 look3_<부위>_<직업>_<등급> · 조각 = 붙는 R15 파트마다 하나(장식은 한 메시로 합침):
#     갑옷 Main(UpperTorso: 가슴 · 목깃 · 벨트 · 어깨판 · 망토/스카프 · 부유) + Tasset(LowerTorso: 허리 아래 판 · 앞 천) (+ 게임이 세트 문장 1 = 3)
#     장갑 Glove_L/R(손) + Bracer_L/R(아래팔) = 4 · 신발 Boot_L/R(발) + Greave_L/R(정강이 + 무릎 판) = 4 → 1벌 11(≤ 16)
#   색 = 등급마다 색 지도(1024 · 장갑/신발 512)에 굽는다: 에나멜(등급 메인 × 밝기) · 금속(등급대) · 가죽 · 보석 · 균열 + 손그림 음영(윗면 빛 · 모서리 밝은 선 · 틈 그림자)
#     세트 천 = 지도 알파 0(AlphaMode Overlay → 파트 Color = 세트 색1이 비침 · 틈은 반투명 검정으로 음영) · 발광 = 별도 마스크(EmissiveMaskContent - 보석 · 균열 · 부유)
#   아이콘의 "몸 전체 등급색"은 따르지 않는다(3-1절 - 등급색 = 주 판금 에나멜 · 장갑/신발 = 커프 띠 · 무릎 판만).
# 실행: bash bl.sh make_gear_look3.py [--classes ..] [--slots ..] [--grades ..] [--bake] [--export] [--render 폴더]
import bpy  # noqa: F401
import bmesh
import json
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import artlib as A  # noqa: E402
from mathutils import Vector  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "art", "armor")
MAPS = os.path.join(ROOT, "art", "textures", "gear_v3", "look3")
IVD = os.path.join(ROOT, "src", "shared", "data", "ItemVisualData.lua")
G3D = os.path.join(ROOT, "src", "shared", "data", "GearV3Data.lua")
CLASSES = ["greatsword", "dualblade", "bow", "healer"]
SLOTS = ["armor", "gloves", "shoes"]
GRADES = ["normal", "rare", "epic", "legendary", "relic", "ancient", "primordial", "transcendent"]
REF = {"UpperTorso": ((0, 0.2, 0), (2, 1.6, 1)), "LowerTorso": ((0, -0.8, 0), (2, 0.4, 1)),
       "LeftLowerArm": ((-1.5, -0.69, 0), (1, 1.05, 1)), "RightLowerArm": ((1.5, -0.69, 0), (1, 1.05, 1)),
       "LeftHand": ((-1.5, -1.37, 0), (1, 0.3, 1)), "RightHand": ((1.5, -1.37, 0), (1, 0.3, 1)),
       "LeftLowerLeg": ((-0.5, -2.8, 0), (1, 1.19, 1)), "RightLowerLeg": ((0.5, -2.8, 0), (1, 1.19, 1)),
       "LeftFoot": ((-0.5, -3.55, 0), (1, 0.3, 1)), "RightFoot": ((0.5, -3.55, 0), (1, 0.3, 1))}  # = make_armor_wear.REF(기준 체형)
PIECES = {"armor": [("Main", "UpperTorso"), ("Tasset", "LowerTorso")],
          "gloves": [("Glove_L", "LeftHand"), ("Glove_R", "RightHand"), ("Bracer_L", "LeftLowerArm"), ("Bracer_R", "RightLowerArm")],
          "shoes": [("Boot_L", "LeftFoot"), ("Boot_R", "RightFoot"), ("Greave_L", "LeftLowerLeg"), ("Greave_R", "RightLowerLeg")]}
# LOOK3 예산(사용자 승인 10-04 밤 · GearV3Data.look3 미러): 부위당 삼각형 · MeshPart
BUDGET_TRIS = {"normal": 2500, "rare": 2500, "epic": 2500, "legendary": 4000, "relic": 4000, "ancient": 4000, "primordial": 6000, "transcendent": 6000}
BUDGET_PARTS = 4
MAP_RES = {"armor": 1024, "gloves": 512, "shoes": 512}


# ────────────────────────── 색(한 곳 = ItemVisualData · GearV3Data 읽기) ──────────────────────────
def _lua_rgb(body, key):
    m = re.search(r"\b" + key + r" = (?:Color3\.fromRGB\()?\{?\s*(\d+), (\d+), (\d+)", body)
    return tuple(int(x) for x in m.groups()) if m else None


def palette_all():
    ivd = open(IVD, encoding="utf-8").read()
    g3 = open(G3D, encoding="utf-8").read()
    look2 = g3[g3.index("look2 = {"):]
    trim = look2[look2.index("trimMetal"):look2.index("leather =")]
    bright = re.search(r"brightness = \{(.*?)\}", look2).group(1)
    core = g3[g3.index("coreGem = {"):g3.index("crack =")]
    out = {}
    for g in GRADES:
        m = re.search(r"\n\t\t" + g + r" = \{(.*?)\n\t\t\},", ivd, re.S)
        body = m.group(1)
        gv = {k: _lua_rgb(body, k) for k in ("color", "light", "dark")}
        metal = _lua_rgb(trim, g)
        b = float(re.search(r"\b" + g + r" = ([\d.]+)", bright).group(1))
        cg = re.search(r"\b" + g + r" = \{ body = \{ (\d+), (\d+), (\d+) \}, core = \{ (\d+), (\d+), (\d+) \}", core)
        enamel = A.mul(gv["color"], b)
        gem = (tuple(int(x) for x in cg.groups()[:3]), tuple(int(x) for x in cg.groups()[3:])) if cg else (gv["light"], gv["light"])
        p = {"enamel": enamel, "enamel2": A.mul(enamel, 0.8), "metal": metal, "metal2": A.mul(metal, 0.72), "leather": _lua_rgb(look2, "leather"),
             "leather2": A.mul(_lua_rgb(look2, "leather"), 0.75), "cloth": (255, 255, 255), "gem": gem[0], "gemCore": gem[1], "accent": gv["color"],
             "crack": _lua_rgb(g3, "crack"), "float": gem[1]}
        if g == "primordial":
            p["accent"] = (233, 91, 200)  # 자홍 포인트(커프 띠 · 받침)
            p["float"] = (233, 91, 200)
        if g == "transcendent":
            p["float"] = p["crack"]
        if g in ("normal",):
            p["gem"] = p["gemCore"] = metal  # 일반 = 보석 없음(금속 징)
        out[g] = p
    return out


PAL = None
# 발광 마스크(0 ~ 1): 보석 = 희귀 ~ 전설 0.55 · 유물 이상 1 · 균열 · 부유 = 1
def emissive_of(zone, grade):
    gi = GRADES.index(grade)
    if zone in ("crack", "float"):
        return 1.0
    if zone in ("gem", "gemCore"):
        return 0.0 if gi == 0 else (0.55 if gi <= 3 else 1.0)
    if zone == "accent" and grade == "primordial":
        return 0.25
    return 0.0


# ────────────────────────── 기하 도우미(Roblox 공간 · 앞 = −Z) ──────────────────────────
def sec(a, b, n=14, p=2.6, dz=0.0, front=1.0):
    """둥근 사각(초타원) 단면 - 가로 반폭 a · 앞뒤 반깊이 b · front = 앞쪽(−Z) 깊이 배율(가슴 볼록)"""
    pts = []
    for i in range(n):
        t = 2 * math.pi * i / n
        c, s = math.cos(t), math.sin(t)
        x = a * math.copysign(abs(c) ** (2 / p), c)
        z = b * math.copysign(abs(s) ** (2 / p), s)
        if z < 0:
            z *= front
        pts.append((x, z + dz))
    return pts


def shell(st, n=14, p=2.6):
    """세로 로프트 st = [(y, a, b, dz, front)] - 아래 → 위"""
    rings = [[(x, y, z) for x, z in sec(a, b, n, p, dz, fr)] for y, a, b, dz, fr in st]
    return A.loft(rings)


def trim_ring(y, a, b, t=0.05, h=0.08, dz=0.0, front=1.0, n=12, p=2.6):
    """둘레 금속 테(둥근 볼록) - 단면 a · b 위에 두께 t"""
    return shell([(y - h / 2, a, b, dz, front), (y - h * 0.2, a + t, b + t, dz, front), (y + h * 0.2, a + t, b + t, dz, front), (y + h / 2, a, b, dz, front)], n, p)


def dome(rx, ry, rz, n=14, rings=4, squash=0.25):
    return A.ellipsoid((rx, ry, rz), n=n, rings=rings, squash_bottom=squash)


def rim(rx, rz, t=0.05, h=0.07, n=14):
    """돔 둘레(적도) 금속 테"""
    return A.xform(A.lathe([(1.0, -h / 2), (1.0 + t / max(rx, rz), 0.0), (1.0, h / 2)], n), s=(rx, 1, rz))


def rivet(c, r=0.045):
    return A.ellipsoid((r, r, r), n=5, rings=2, center=c, squash_bottom=0.4)


def facet_gem(c, r, kind="brilliant", face=(0, 0, -1)):
    """도톰한 패싯 보석(앞 −Z를 본다): brilliant(16면) · oval(12) · step(계단 사각) · cab(둥근 6)"""
    if kind == "step":
        g = A.merge(A.box(r * 1.8, r * 1.4, r * 0.55, b=r * 0.25, center=(0, 0, 0)), A.box(r * 1.25, r * 0.9, r * 0.35, b=r * 0.18, center=(0, 0, -r * 0.4)))
    elif kind == "cab":
        g = A.ellipsoid((r, r * 0.85, r * 0.75), n=8, rings=3, squash_bottom=0.15)
    else:
        sides = 16 if kind == "brilliant" else 12
        prof = [(0.0, -r * 0.55), (r, -r * 0.08), (r * 0.92, r * 0.12), (r * 0.55, r * 0.4), (0.0, r * 0.42)]
        g = A.xform(A.lathe(prof, sides), m=A.rot(rx=-90))  # 위(+Y) → 앞(−Z)
        if kind == "oval":
            g = A.xform(g, s=(0.8, 1.15, 1.0))
    if face != (0, 0, -1):
        fx, fy, fz = face
        yaw = math.degrees(math.atan2(-fx, -fz))
        g = A.xform(g, m=A.rot(ry=yaw))
    return A.xform(g, t=c)


def setting(c, r, t=0.04, face=(0, 0, -1)):
    """보석 받침 테(금속)"""
    g = A.xform(A.lathe([(r, -t), (r + t * 1.6, 0.0), (r, t)], 12), m=A.rot(rx=90))
    if face != (0, 0, -1):
        fx, fy, fz = face
        g = A.xform(g, m=A.rot(ry=math.degrees(math.atan2(-fx, -fz))))
    return A.xform(g, t=c)


def bar(p0, p1, w, d):
    """두 점을 잇는 각진 막대(필리그리 · 끈 · 균열)"""
    v = Vector(p1) - Vector(p0)
    L = v.length
    g = A.box(w, L, d)
    up = Vector((0, 1, 0))
    axis = up.cross(v.normalized())
    if axis.length > 1e-6:
        ang = math.acos(max(-1, min(1, up.dot(v.normalized()))))
        from mathutils import Matrix
        g = A.xform(g, m=Matrix.Rotation(ang, 3, axis.normalized()))
    mid = (Vector(p0) + Vector(p1)) / 2
    return A.xform(g, t=tuple(mid))


def arc(c, r, a0, a1, n, w, d, plane="XY"):
    """필리그리 호(금속 장식 선)"""
    pts = []
    for i in range(n + 1):
        a = math.radians(a0 + (a1 - a0) * i / n)
        if plane == "XY":
            pts.append((c[0] + r * math.cos(a), c[1] + r * math.sin(a), c[2]))
        else:
            pts.append((c[0] + r * math.cos(a), c[1], c[2] + r * math.sin(a)))
    return A.merge(*[bar(pts[i], pts[i + 1], w, d) for i in range(n)])


def crack_lines(c, size, seed, n=3):
    """초월 금 균열(발광) - 꺾인 선 n개"""
    import random
    rng = random.Random(seed)
    segs = []
    for k in range(n):
        x, y = c[0] + rng.uniform(-size, size) * 0.6, c[1] + rng.uniform(-size, size) * 0.6
        for _ in range(3):
            nx, ny = x + rng.uniform(-size, size) * 0.45, y + rng.uniform(-size, size) * 0.55
            segs.append(bar((x, y, c[2]), (nx, ny, c[2]), 0.035, 0.03))
            x, y = nx, ny
    return A.merge(*segs)


def mirror(geo):
    return A.mirror_x(geo)


# ────────────────────────── 조각 만들기 ──────────────────────────
class Z:
    """구역별 기하 모음 - add(구역, geo)"""

    def __init__(self):
        self.d = {}

    def add(self, zone, *geos):
        self.d.setdefault(zone, []).extend(geos)

    def xform(self, **kw):
        for k in self.d:
            self.d[k] = [A.xform(g, **kw) for g in self.d[k]]
        return self

    def merge_from(self, other):
        for k, v in other.d.items():
            self.add(k, *v)


def gi_of(grade):
    return GRADES.index(grade)


def lame(side, r, y, h, t=0.07, span=110, n=8):
    """팔을 바깥쪽에서 감싸는 곡면 겹판(부분 고리 · 세로축 = 윗팔) - 각도 = 바깥(side·X) 기준 ±span"""
    rings = []
    for yy, rr in ((y - h / 2, r + 0.02), (y + h / 2, r - 0.04)):
        ring_o, ring_i = [], []
        for i in range(n + 1):
            a = math.radians(-span + 2 * span * i / n)
            ring_o.append((side * (rr + t) * math.cos(a), yy, (rr + t) * math.sin(a)))
            ring_i.append((side * rr * math.cos(a), yy, rr * math.sin(a)))
        rings.append((ring_o, ring_i))
    (o0, i0), (o1, i1) = rings
    verts = o0 + o1 + i0 + i1
    m = n + 1
    faces = []
    for i in range(n):
        faces += [(i, i + 1, m + i + 1, m + i), (2 * m + i + 1, 2 * m + i, 3 * m + i, 3 * m + i + 1),
                  (i + 1, i, 2 * m + i, 2 * m + i + 1), (m + i, m + i + 1, 3 * m + i + 1, 3 * m + i)]
    faces += [(0, m, 3 * m, 2 * m), (m - 1, 2 * m + m - 1, 3 * m + m - 1, m + m - 1)]
    return verts, faces


def pauldron(z, side, grade, layers, big):
    """둥근 겹판 어깨(UpperTorso 로컬) - 둥근 위 돔(어깨 감쌈) + 아래로 작아지며 팔을 바깥에서 감싸는 겹판 · 판마다 금속 테 · 등급 장식 진화"""
    gi = gi_of(grade)
    ax = side * 1.45  # 윗팔 축
    q = Z()
    rx, ry, rz = 0.86 * big, 0.55 * big, 0.74 * big
    top = 0.6
    q.add("enamel", A.xform(dome(rx, ry, rz, n=14, rings=5, squash=0.15), t=(ax - side * 0.12, top, 0)))
    q.add("metal", A.xform(rim(rx, rz, t=0.06 + 0.03 * (gi >= 3), h=0.1, n=14), t=(ax - side * 0.12, top - 0.02, 0)))
    for i in range(1, layers):
        r = (0.72 - 0.05 * i) * big
        y = top - 0.12 - 0.26 * i * big
        q.add("enamel" if i % 2 else "enamel2", A.xform(lame(side, r, 0, 0.3 * big, t=0.08, span=118 - 8 * i), t=(ax, y, 0)))
        q.add("metal", A.xform(lame(side, r + 0.075, 0, 0.06, t=0.03, span=118 - 8 * i), t=(ax, y - 0.13 * big, 0)))
        if gi >= 1:
            q.add("metal", *[rivet((ax + side * (r + 0.09) * math.cos(math.radians(a)), y + 0.04, (r + 0.09) * math.sin(math.radians(a)))) for a in (-55, 0, 55)])
    if gi >= 1:  # 위 돔 리벳
        q.add("metal", *[rivet((ax - side * 0.12 + rx * 0.7 * math.cos(math.radians(a)), top + ry * 0.55, rz * 0.7 * math.sin(math.radians(a)))) for a in (30, 150, 210, 330)])
    if gi >= 3:  # 전설+: 돔 위 필리그리(앞뒤로 휘는 금속 선)
        q.add("metal", arc((ax - side * 0.12, top + ry * 0.62, 0), rx * 0.5, -70, 70, 6, 0.05, 0.05, plane="XZ") if side > 0 else
              arc((ax - side * 0.12, top + ry * 0.62, 0), rx * 0.5, 110, 250, 6, 0.05, 0.05, plane="XZ"))
    if gi >= 2:  # 영웅+: 돔 바깥 보석
        r = 0.1 + 0.02 * (gi >= 4) + 0.02 * (gi >= 6)
        c = (ax - side * 0.12 + side * rx * 0.92, top + 0.12, 0)
        q.add("gem", facet_gem(c, r, "cab" if gi <= 3 else "brilliant", face=(side, 0, 0)))
        q.add("metal", setting((c[0] - side * 0.02, c[1], c[2]), r * 1.06, face=(side, 0, 0)))
    if gi >= 5:  # 고대+: 둥근 마루 왕관(가시 금지)
        q.add("metal", *[A.ellipsoid((0.09, 0.2, 0.09), n=8, rings=3, center=(ax - side * 0.12, top + ry * 0.9 + 0.08, dz), squash_bottom=0.5) for dz in (-0.28, 0.0, 0.28)])
    if gi == 6:  # 태초: 날개 지느러미(백금) + 자홍 띠
        for k in range(3):
            q.add("metal", A.xform(A.box(0.06, 0.55 - 0.12 * k, 0.18, b=0.03), m=A.rot(rz=-side * (40 + 18 * k)), t=(ax + side * (0.45 + 0.08 * k), top + 0.25 - 0.1 * k, 0.15)))
        q.add("accent", A.xform(rim(rx * 0.72, rz * 0.72, t=0.04, h=0.05), t=(ax - side * 0.12, top + ry * 0.45, 0)))
    if gi == 7:  # 초월: 금 균열(발광)
        q.add("crack", A.xform(crack_lines((0, 0, 0), rx * 0.7, 11 + side, 2), m=A.rot(rx=-90), t=(ax - side * 0.12, top + ry * 0.75, 0)))
    z.merge_from(q)


def core_gem(z, grade, c, scale=1.0):
    gi = gi_of(grade)
    if gi == 0:
        z.add("metal", rivet(c, 0.09))
        return
    kind = "cab" if gi <= 3 else ("oval" if gi == 4 else ("step" if gi == 5 else "brilliant"))
    r = (0.11 + 0.015 * gi) * scale
    z.add("gem", facet_gem(c, r, kind))
    z.add("metal", setting((c[0], c[1], c[2] + 0.03), r * 1.08, t=0.045))
    if gi >= 4:  # 받침 발톱 4
        z.add("metal", *[rivet((c[0] + r * 1.15 * math.cos(math.radians(a)), c[1] + r * 1.15 * math.sin(math.radians(a)), c[2] - 0.02), 0.035) for a in (45, 135, 225, 315)])


def floats(z, cls, grade):
    """부유 조각(2절 · 5절 ②): 유물 · 고대 1 · 태초 · 초월 3(작게) - 어깨 뒤 위 · 발광"""
    gi = gi_of(grade)
    if gi < 4:
        return
    pts = [(0.0, 1.35, 0.85)] if gi < 6 else [(1.15, 1.2, 0.7), (-1.15, 1.2, 0.7), (0.0, 1.55, 0.9)]
    for i, p in enumerate(pts):
        s = 0.2 if gi < 6 else 0.16
        if cls == "healer":
            z.add("float", A.xform(A.lathe([(s, -0.03), (s + 0.05, 0), (s, 0.03)], 10), m=A.rot(rx=90), t=p))
        elif cls == "dualblade":
            z.add("float", A.xform(A.crystal(s * 2.4, s * 0.35, sides=4, tip_h=0.2, base_h=0.05), m=A.rot(rz=25), t=p))
        else:
            z.add("float", A.xform(A.crystal(s * 2.0, s * 0.45, sides=5, tip_h=0.3, base_h=0.12), t=p))


def armor_main(cls, grade):
    """UpperTorso 로컬(가운데 0 · 크기 2 × 1.6 × 1) - 가슴 · 목깃 · 벨트 · 어깨판 · 천(망토/스카프/후드/로브 앞판) · 부유"""
    gi = gi_of(grade)
    z = Z()
    heavy = cls == "greatsword"
    tt = 0.05 + 0.02 * (gi >= 3)  # 테 두께(전설+ 굵은 금 테)
    # 가슴판(에나멜) - 대검 = 통 판금 · 쌍검 · 활 = 가죽 조끼 위 가슴판 · 치유사 = 로브 위 작은 판
    if heavy:
        z.add("enamel", shell([(-0.82, 1.1, 0.62, 0, 1.0), (-0.3, 1.12, 0.64, -0.02, 1.08), (0.25, 1.16, 0.66, -0.04, 1.16), (0.66, 1.06, 0.6, -0.02, 1.08), (0.84, 0.82, 0.5, 0, 1.0)]))
        z.add("metal", bar((0, -0.6, -0.76), (0, 0.66, -0.77), 0.08, 0.06))  # 가운데 마루
        for y in (-0.38, -0.6):  # 배 겹판 선
            z.add("metal", trim_ring(y, 1.1, 0.63, t=0.03, h=0.05, front=1.05))
    else:
        z.add("leather", shell([(-0.82, 1.08, 0.6, 0, 1.0), (0.2, 1.1, 0.62, -0.02, 1.06), (0.84, 0.86, 0.5, 0, 1.0)]))
        a = 0.62 if cls != "healer" else 0.5
        plate = shell([(-0.1, a, 0.2, -0.52, 1.0), (0.3, a + 0.06, 0.24, -0.56, 1.0), (0.66, a - 0.08, 0.2, -0.5, 1.0)], n=12)
        for sx in ((-0.5, 0.5) if cls == "dualblade" else (0,)):
            z.add("enamel", A.xform(plate, t=(sx, 0, 0)))
            z.add("metal", A.xform(trim_ring(0.66, a - 0.08, 0.2, t=0.04, h=0.06, dz=-0.5), t=(sx, 0, 0)), A.xform(trim_ring(-0.1, a, 0.2, t=0.04, h=0.06, dz=-0.52), t=(sx, 0, 0)))
        if cls == "dualblade":  # 교차 가죽 끈 + 버클
            for s in (-1, 1):
                z.add("leather2", bar((-s * 0.95, 0.75, -0.66), (s * 0.85, -0.75, -0.68), 0.16, 0.05))
            z.add("metal", A.box(0.2, 0.2, 0.06, b=0.04, center=(0, 0.0, -0.73)))
    # 목깃(금속 · 고대+ 층 · 태초/초월 넓게) - 아래팔 링 아님(목 둘레)
    z.add("metal", trim_ring(0.82, 0.7, 0.44, t=0.06 + 0.04 * (gi >= 5), h=0.12 + 0.06 * (gi >= 5)))
    if gi >= 5:
        z.add("enamel2", trim_ring(0.95, 0.66, 0.42, t=0.07, h=0.1))
    if cls == "healer" and gi >= 6:  # 치유사 왕관형 목깃
        for k in range(8):
            a = math.radians(200 + 140 * k / 7)
            z.add("metal", A.xform(A.box(0.08, 0.22, 0.05, b=0.02), t=(0.72 * math.cos(a), 1.02, 0.46 * math.sin(a))))
    # 가슴 테두리(굵은 금속) · 리벳 · 필리그리
    if heavy:
        z.add("metal", trim_ring(0.7, 1.08, 0.62, t=tt, h=0.08, dz=-0.02, front=1.08), trim_ring(-0.8, 1.12, 0.64, t=tt, h=0.08))
        if gi >= 1:
            z.add("metal", *[rivet((x, 0.55, -0.83)) for x in (-0.85, -0.55, 0.55, 0.85)])
        if gi >= 2:  # 영웅+ 이중 테두리
            z.add("metal", trim_ring(0.55, 1.1, 0.64, t=0.03, h=0.04, dz=-0.03, front=1.1))
        if gi >= 3:  # 전설+ 필리그리(가슴 양옆 소용돌이 호)
            for s in (-1, 1):
                z.add("metal", arc((s * 0.46, 0.42, -0.84), 0.4, 200, 340, 8, 0.05, 0.045))
    else:
        if gi >= 1:
            z.add("metal", *[rivet((x, 0.6, -0.77)) for x in ((-0.6, -0.4, 0.4, 0.6) if cls == "dualblade" else (-0.4, 0.4))])
        if gi >= 3:
            for s in (-1, 1):
                z.add("metal", arc((s * 0.3, 0.42, -0.8), 0.26, 200, 340, 6, 0.04, 0.04))
    # 핵심 보석(문장 위 · 목 아래) - 문장(세트) 자리 EMBLEM_AT(0, 0.05, −0.74)는 비워 둠
    core_gem(z, grade, (0.0, 0.5, -0.8 if heavy else -0.78), 1.0 if heavy else 0.85)
    if gi >= 2:  # 영웅+: 가슴 양옆 작은 보석
        for s in (-1, 1):
            c = (s * 0.72, 0.42, -0.79 if heavy else -0.6)
            z.add("gem", facet_gem(c, 0.07, "cab"))
            z.add("metal", setting((c[0], c[1], c[2] + 0.02), 0.075, t=0.03))
    if gi == 6:  # 태초 자홍 띠(가슴 아래 · 커프 포인트)
        z.add("accent", trim_ring(-0.68, 1.12 if heavy else 1.1, 0.64 if heavy else 0.62, t=0.035, h=0.05))
    if gi == 7:
        z.add("crack", A.xform(crack_lines((0.0, -0.15, -0.79), 0.75, 7, 3), t=(0, 0, -0.01 if heavy else 0.1)))
    # 벨트(가죽 · LowerTorso 위 = 로컬 y −0.8 ~ −1.15) + 큰 버클
    z.add("leather", shell([(-1.14, 1.1, 0.6, 0, 1.0), (-0.86, 1.1, 0.6, 0, 1.0)]))
    z.add("metal", A.box(0.38, 0.3, 0.08, b=0.05, center=(0, -1.0, -0.66)), A.box(0.22, 0.14, 0.06, b=0.03, center=(0, -1.0, -0.71)))
    if gi >= 3:
        z.add("metal", *[rivet((x, -1.0, -0.63)) for x in (-0.8, -0.5, 0.5, 0.8)])
    # 어깨판(1.3 ~ 1.5배 · 겹판 3) - 직업 실루엣: 대검 양쪽 3장 · 쌍검 오른쪽 3 + 왼쪽 1(비대칭) · 활 왼쪽(활 든 팔) 2 + 오른쪽 가죽 받이 · 치유사 작은 판 + 천 망토
    big = [0.85, 0.88, 0.92, 1.0, 1.04, 1.08, 1.14, 1.14][gi]
    if heavy:
        for s in (-1, 1):
            pauldron(z, s, grade, 3 if gi >= 3 else 2, big)  # 실루엣 진화: 겹판 2 → 전설+ 3
    elif cls == "dualblade":
        pauldron(z, 1, grade, 3, big * 0.9)
        pauldron(z, -1, grade, 1, big * 0.7)
    elif cls == "bow":
        pauldron(z, -1, grade, 2, big * 0.85)
        z.add("leather", A.xform(dome(0.6, 0.26, 0.56, n=12, rings=3), t=(1.38, 0.74, 0)))
    else:
        for s in (-1, 1):
            pauldron(z, s, grade, 2, big * 0.72)
    # 천(세트 색1 - 지도 알파): 대검 = 등 망토 · 쌍검 = 목 스카프 + 꼬리 · 활 = 후드(내림) + 망토 · 치유사 = 어깨 망토(케이프렛)
    if heavy or cls == "bow":
        cape_len = -2.4 if heavy else -2.0
        cape = A.loft([[(x * w, y, 0.55 + 0.12 * (x * x) + (0.0 if y > 0.5 else 0.1)) for x in (-1, -0.6, -0.2, 0.2, 0.6, 1)] + [(x * w, y, 0.62 + 0.12 * (x * x) + (0.0 if y > 0.5 else 0.1)) for x in (1, 0.6, 0.2, -0.2, -0.6, -1)]
                       for y, w in ((0.78, 0.85), (0.0, 0.95), (-1.2, 1.05), (cape_len, 1.15))])
        z.add("cloth", cape)
        if gi >= 3:  # 망토 끝 금속 테
            z.add("metal", A.box(2.3, 0.08, 0.1, center=(0, cape_len + 0.05, 0.84)))
    if cls == "bow":  # 후드(목 뒤로 내린 두건) + 목 둘레 망토
        z.add("cloth", A.xform(A.ellipsoid((0.62, 0.42, 0.5), n=12, rings=4, squash_bottom=0.5), t=(0, 0.95, 0.42)))
        z.add("cloth", trim_ring(0.72, 0.9, 0.58, t=0.1, h=0.22))
    if cls == "dualblade":
        z.add("cloth", trim_ring(0.78, 0.78, 0.52, t=0.12, h=0.26))
        z.add("cloth", A.xform(A.box(0.32, 1.1, 0.06, b=0.03), m=A.rot(rz=12), t=(0.35, 0.15, 0.62)))
    if cls == "healer":
        cap = shell([(0.2, 1.2, 0.7, 0, 1.0), (0.55, 1.12, 0.66, 0, 1.0), (0.84, 0.8, 0.52, 0, 1.0)], n=16)
        z.add("cloth", cap)
        z.add("metal", trim_ring(0.2, 1.2, 0.7, t=tt, h=0.07))
    floats(z, cls, grade)
    return z


def armor_tasset(cls, grade):
    """LowerTorso 로컬(가운데 0 · 크기 2 × 0.4 × 1 · 허벅지는 아래 −0.2 ~ −1.4) - 허리 아래 판(에나멜 + 금속 테) · 앞 천 띠(세트) · 치유사 = 로브 치마(에나멜 판 + 천 앞판)"""
    gi = gi_of(grade)
    z = Z()
    long_ = {"greatsword": 0.75, "dualblade": 0.5, "bow": 0.55, "healer": 1.5}[cls]
    if cls == "healer":  # 로브 치마(에나멜 면 - 단색 면) + 금속 단
        z.add("enamel", shell([(-long_, 1.25, 0.78, 0, 1.0), (-0.6, 1.12, 0.66, 0, 1.0), (0.1, 1.06, 0.58, 0, 1.0)], n=16))
        z.add("metal", trim_ring(-long_ + 0.05, 1.25, 0.78, t=0.05 + 0.02 * (gi >= 3), h=0.09))
        if gi >= 3:
            z.add("metal", trim_ring(-long_ + 0.25, 1.22, 0.76, t=0.03, h=0.04))
    else:
        layers = 1 + (gi >= 3) + (gi >= 5)
        for s in (-1, 1):
            for k in range(layers):
                w, h = 0.62 - 0.04 * k, long_ - 0.12 * k
                y0 = -0.05 - 0.18 * k
                pl = A.xform(A.box(w, h, 0.07, b=0.05), m=A.rot(rx=-8, rz=s * 4), t=(s * (0.48 + 0.04 * k), y0 - h / 2, -0.6 - 0.03 * k))
                z.add("enamel" if k % 2 == 0 else "enamel2", pl)
                z.add("metal", A.xform(A.box(w + 0.06, 0.06, 0.09), m=A.rot(rx=-8, rz=s * 4), t=(s * (0.48 + 0.04 * k), y0 - h + 0.03, -0.62 - 0.03 * k)))
                if gi >= 1:
                    z.add("metal", rivet((s * (0.48 + 0.04 * k), y0 - 0.06, -0.66 - 0.03 * k)))
            # 옆 판
            z.add("enamel2" if cls != "dualblade" else "leather", A.xform(A.box(0.07, long_ * 0.8, 0.6, b=0.03), m=A.rot(rz=s * 7), t=(s * 1.1, -long_ * 0.4, 0.0)))
            z.add("metal", A.xform(A.box(0.09, 0.05, 0.64), m=A.rot(rz=s * 7), t=(s * 1.13, -long_ * 0.8 + 0.03, 0.0)))
    # 앞 천 띠(세트 색1 - 태바드) · 대검 · 치유사 길게
    tab = {"greatsword": 1.3, "dualblade": 0.0, "bow": 0.7, "healer": 1.4}[cls]
    if tab:
        z.add("cloth", A.xform(A.box(0.56, tab, 0.05, b=0.02), m=A.rot(rx=-4), t=(0, -tab / 2 + 0.05, -0.68 if cls != "healer" else -0.85)))
        if gi >= 3:
            z.add("metal", A.box(0.62, 0.07, 0.07, center=(0, -tab + 0.06, -0.73 if cls != "healer" else -0.9)))
    if gi == 7:
        z.add("crack", crack_lines((0.48, -0.3, -0.67), 0.3, 21, 1), crack_lines((-0.48, -0.3, -0.67), 0.3, 22, 1))
    if gi == 6:
        z.add("accent", A.box(2.15, 0.05, 1.16, center=(0, -0.02, 0)))
    return z


def glove(cls, side, grade):
    """손 로컬(1 × 0.3 × 1) - 가죽 장갑 + 금속 마디 판 · 손등(바깥 = side·X) 판 + 보석"""
    gi = gi_of(grade)
    z = Z()
    z.add("leather", shell([(-0.19, 0.54, 0.53, 0, 1.0), (0.05, 0.56, 0.55, 0, 1.0), (0.21, 0.51, 0.5, 0, 1.0)], n=12, p=2.8))
    z.add("metal", *[A.ellipsoid((0.13, 0.12, 0.13), n=8, rings=3, center=(x, -0.06, -0.55)) for x in (-0.33, -0.11, 0.11, 0.33)])  # 마디 판
    z.add("leather2", A.tube([(-side * 0.46, 0.0, -0.1), (-side * 0.7, -0.02, -0.32), (-side * 0.66, 0.04, -0.52)], lambda u: 0.14 - 0.03 * u, sides=6))  # 엄지
    hp = A.xform(A.box(0.07, 0.3, 0.6, b=0.03), t=(side * 0.58, 0.02, 0))  # 손등(바깥) 금속 판
    z.add("metal", hp)
    if gi >= 2:
        c = (side * 0.64, 0.02, 0.0)
        z.add("gem", facet_gem(c, 0.07 + 0.01 * (gi >= 4), "cab" if gi <= 3 else "brilliant", face=(side, 0, 0)))
    if gi == 7:
        z.add("crack", A.xform(crack_lines((0, 0, 0), 0.2, 31 + side, 1), m=A.rot(ry=90), t=(side * 0.62, 0.0, 0.0)))
    return z


def bracer(cls, side, grade):
    """아래팔 로컬(1 × 1.05 × 1) - 손목 쪽 커프(금속) + 등급 띠(accent) + 바깥 판 · 가죽 감개"""
    gi = gi_of(grade)
    z = Z()
    z.add("leather", shell([(-0.53, 0.6, 0.6, 0, 1.0), (-0.1, 0.56, 0.56, 0, 1.0)], n=14))
    z.add("metal", shell([(-0.53, 0.64, 0.64, 0, 1.0), (-0.42, 0.62, 0.62, 0, 1.0)], n=14), trim_ring(-0.12, 0.56, 0.56, t=0.04, h=0.07, n=14))
    band = "accent" if gi != 7 else "metal"
    z.add(band, trim_ring(-0.32, 0.57, 0.57, t=0.035, h=0.1, n=14))  # 등급 띠(LOOK2 3-1: 장갑 등급색 = 커프 띠만)
    if gi >= 1:
        z.add("metal", *[rivet((0.6 * math.cos(math.radians(a)), -0.47, 0.6 * math.sin(math.radians(a)))) for a in (0, 90, 180, 270)])
    if gi >= 3:  # 전설+ 바깥 필리그리
        z.add("metal", A.xform(arc((0, -0.25, 0), 0.14, -90, 90, 5, 0.035, 0.03), m=A.rot(ry=90 * side), t=(side * 0.6, 0, 0)))
    if gi >= 5:  # 고대+ 바깥 둥근 마루
        z.add("metal", A.ellipsoid((0.08, 0.22, 0.14), n=8, rings=3, center=(side * 0.66, -0.3, 0)))
    if gi == 6:
        z.add("metal", *[A.xform(A.box(0.05, 0.28 - 0.06 * k, 0.12, b=0.02), m=A.rot(rz=side * (30 + 15 * k)), t=(side * (0.66 + 0.06 * k), -0.2 - 0.06 * k, 0.1)) for k in range(2)])
    if gi == 7:
        z.add("crack", A.xform(crack_lines((0, -0.3, 0), 0.25, 41 + side, 1), m=A.rot(ry=90 * side), t=(side * 0.64, 0, 0)))
    return z


def boot(cls, side, grade):
    """발 로컬(1 × 0.3 × 1) - 가죽 장화 + 금속 앞코 · 밑창"""
    gi = gi_of(grade)
    z = Z()
    z.add("leather", A.loft([[(x, y + yc, zz) for x, y in A.chamfer_rect(w, h, 0.1)] for zz, w, h, yc in ((0.55, 1.1, 0.46, 0.04), (-0.2, 1.14, 0.44, 0.0), (-0.85, 1.0, 0.32, -0.04), (-1.03, 0.72, 0.18, 0.0))]))
    z.add("leather2", A.box(1.18, 0.14, 1.62, b=0.04, center=(0, -0.3, -0.24)))  # 밑창
    z.add("metal", A.loft([[(x, y + yc, zz) for x, y in A.chamfer_rect(w, h, 0.1)] for zz, w, h, yc in ((-0.7, 1.06, 0.38, 0.0), (-0.92, 0.94, 0.3, -0.03), (-1.07, 0.74, 0.2, 0.0))]))  # 앞코 판(사바톤 - 앞 끝만)
    if gi >= 1:
        z.add("metal", A.box(1.16, 0.06, 0.08, center=(0, 0.08, -0.68)))
    if gi >= 3:
        z.add("metal", *[rivet((x, 0.1, -0.8)) for x in (-0.3, 0.3)])
    if gi >= 5:
        z.add("gem", facet_gem((0, 0.12, -0.78), 0.07, "cab"))
    return z


def greave(cls, side, grade):
    """정강이 로컬(1 × 1.19 × 1) - 장화 목(가죽) + 금속 커프 + 등급 띠 + 무릎 판(에나멜 · PLATE) + 테"""
    gi = gi_of(grade)
    z = Z()
    z.add("leather", shell([(-0.6, 0.56, 0.56, 0, 1.0), (-0.1, 0.55, 0.55, 0, 1.0)], n=14))
    z.add("metal", shell([(-0.18, 0.58, 0.58, 0, 1.0), (-0.04, 0.6, 0.6, 0, 1.0)], n=14))
    band = "accent" if gi != 7 else "metal"
    z.add(band, trim_ring(-0.24, 0.565, 0.565, t=0.03, h=0.08, n=14))
    # 무릎 판(에나멜) + 금속 테 + 날개 판
    z.add("enamel", A.ellipsoid((0.36, 0.28, 0.18), n=12, rings=4, center=(0, 0.45, -0.53)))
    z.add("metal", A.xform(rim(0.36, 0.18, t=0.04, h=0.05), m=A.rot(rx=90), t=(0, 0.45, -0.5)))
    if gi >= 2:
        for s in (-1, 1):
            z.add("enamel2", A.xform(A.ellipsoid((0.16, 0.22, 0.08), n=8, rings=3), m=A.rot(ry=s * 40), t=(s * 0.36, 0.43, -0.42)))
    if gi >= 3:  # 정강이 앞 판(에나멜 - 무릎 아래 짧게) + 테
        z.add("enamel2", A.xform(A.box(0.5, 0.42, 0.08, b=0.04), t=(0, 0.12, -0.6)))
        z.add("metal", A.box(0.56, 0.05, 0.1, center=(0, -0.09, -0.6)))
    if gi >= 4:
        c = (0, 0.46, -0.72)
        z.add("gem", facet_gem(c, 0.08, "brilliant" if gi >= 6 else "cab"))
        z.add("metal", setting((0, 0.46, -0.69), 0.085, t=0.03))
    if gi == 7:
        z.add("crack", crack_lines((0, 0.45, -0.71), 0.22, 51 + side, 1))
    return z


def piece_zones(cls, slot, grade, piece):
    side = -1 if piece.endswith("_L") else 1
    if piece == "Main":
        return armor_main(cls, grade)
    if piece == "Tasset":
        return armor_tasset(cls, grade)
    kind = piece.split("_")[0]
    return {"Glove": glove, "Bracer": bracer, "Boot": boot, "Greave": greave}[kind](cls, side, grade)


# ────────────────────────── 오브젝트 · 재질(구역 = 재질 슬롯) ──────────────────────────
def make_zoned(name, zgeo, col, origin, key):
    verts, faces, mats = [], [], []
    zones = sorted(zgeo.d)
    for zi, zone in enumerate(zones):
        for g in zgeo.d[zone]:
            v, f = g
            base = len(verts)
            verts += list(v)
            faces += [tuple(i + base for i in face) for face in f]
            mats += [zi] * len(f)
    o = Vector(origin)
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(A.C @ (Vector(p) - o)) for p in verts], [], faces)
    for p, mi in zip(mesh.polygons, mats):
        p.material_index = mi
    mesh.validate()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    for p in mesh.polygons:
        p.use_smooth = False
    obj = bpy.data.objects.new(name, mesh)
    obj.location = tuple(A.C @ o)
    col.objects.link(obj)
    for zone in zones:
        mat = A.material("L3_%s_%s" % (key, zone), PAL_G[zone])
        mat["Zone"] = zone
        obj.data.materials.append(mat)
    return obj


PAL_G = None


def build(cls, slot, grade):
    global PAL_G
    PAL_G = PAL[grade]
    key = "look3_%s_%s_%s" % (slot, cls, grade)
    col = A.new_collection(key)
    objs, info = [], {}
    for piece, part in PIECES[slot]:
        pc, _ = REF[part]
        zg = piece_zones(cls, slot, grade, piece)
        zg.xform(t=pc)
        o = make_zoned(piece, zg, col, pc, key)
        objs.append(o)
        info[piece] = part
    return key, col, objs, info


# ────────────────────────── 굽기: 색 지도(손그림 음영) + 마스크(R = 천 · G = 발광) ──────────────────────────
def _shade_nodes(nt, color_rgb):
    N = nt.nodes.new
    geo = N("ShaderNodeNewGeometry")
    bev = N("ShaderNodeBevel")
    bev.inputs["Radius"].default_value = 0.025
    bev.samples = 8
    dot = N("ShaderNodeVectorMath")
    dot.operation = "DOT_PRODUCT"
    nt.links.new(bev.outputs["Normal"], dot.inputs[0])
    nt.links.new(geo.outputs["Normal"], dot.inputs[1])
    edge = N("ShaderNodeMath")  # 모서리 밝은 선: (1 − dot) × 8
    edge.operation = "MULTIPLY_ADD"
    edge.inputs[1].default_value = -8.0
    edge.inputs[2].default_value = 8.0
    edge.use_clamp = True
    nt.links.new(dot.outputs["Value"], edge.inputs[0])
    sep = N("ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Normal"], sep.inputs[0])
    up = N("ShaderNodeMath")  # 윗면 빛(손그림 하이라이트): 0.82 + 0.2 × nz(Blender Z = 위)
    up.operation = "MULTIPLY_ADD"
    up.inputs[1].default_value = 0.3
    up.inputs[2].default_value = 0.78
    nt.links.new(sep.outputs["Z"], up.inputs[0])
    hl = N("ShaderNodeMath")
    hl.operation = "MULTIPLY_ADD"
    hl.inputs[1].default_value = 0.45
    nt.links.new(edge.outputs["Value"], hl.inputs[0])
    nt.links.new(up.outputs["Value"], hl.inputs[2])
    ao = N("ShaderNodeAmbientOcclusion")
    ao.inputs["Distance"].default_value = 0.15
    aom = N("ShaderNodeMapRange")
    aom.inputs["To Min"].default_value = 0.38
    nt.links.new(ao.outputs["AO"], aom.inputs["Value"])
    mul = N("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    nt.links.new(hl.outputs["Value"], mul.inputs[0])
    nt.links.new(aom.outputs["Result"], mul.inputs[1])
    rgb = N("ShaderNodeRGB")
    lin = [A.srgb_to_linear(c) for c in color_rgb]
    rgb.outputs[0].default_value = (lin[0], lin[1], lin[2], 1.0)
    mix = N("ShaderNodeVectorMath")  # 색 × 음영(밝은 선은 1을 넘겨 하이라이트 - 1에서 자름)
    mix.operation = "SCALE"
    nt.links.new(rgb.outputs[0], mix.inputs[0])
    nt.links.new(mul.outputs["Value"], mix.inputs["Scale"])
    return mix.outputs["Vector"]


def bake(objs, key, res, grade):
    scene = bpy.context.scene
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(55), island_margin=0.012, area_weight=0.0, scale_to_bounds=True)
    bpy.ops.object.mode_set(mode="OBJECT")
    imgs = {}
    for kind in ("color", "mask"):
        img = bpy.data.images.new("%s_%s" % (key, kind), res, res, alpha=False)
        imgs[kind] = img
        done = set()
        for o in objs:
            for mat in o.data.materials:
                if mat.name in done:
                    continue
                done.add(mat.name)
                zone = mat["Zone"]
                mat.use_nodes = True
                nt = mat.node_tree
                for n in list(nt.nodes):
                    nt.nodes.remove(n)
                out = nt.nodes.new("ShaderNodeOutputMaterial")
                emit = nt.nodes.new("ShaderNodeEmission")
                if kind == "color":
                    nt.links.new(_shade_nodes(nt, PAL[grade][zone]), emit.inputs["Color"])
                else:
                    emit.inputs["Color"].default_value = (1.0 if zone == "cloth" else 0.0, emissive_of(zone, grade), 0.0, 1.0)
                nt.links.new(emit.outputs["Emission"], out.inputs["Surface"])
                tex = nt.nodes.new("ShaderNodeTexImage")
                tex.image = img
                nt.nodes.active = tex
        scene.render.engine = "CYCLES"
        scene.cycles.device = "CPU"
        scene.cycles.samples = 20 if kind == "color" else 1
        scene.render.bake.margin = 6
        bpy.ops.object.bake(type="EMIT")
        img.filepath_raw = os.path.join(MAPS, "_raw_%s_%s.png" % (key, kind))
        img.file_format = "PNG"
        os.makedirs(MAPS, exist_ok=True)
        img.save()
    # 미리보기용: 굽은 색을 재질에 다시 연결(Workbench 텍스처 렌더)
    for o in objs:
        for mat in o.data.materials:
            nt = mat.node_tree
            for n in nt.nodes:
                if n.type == "TEX_IMAGE":
                    n.image = imgs["color"]
                    nt.nodes.active = n
    return [os.path.join(MAPS, "_raw_%s_%s.png" % (key, k)) for k in ("color", "mask")]


def parse():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opt = {"classes": CLASSES, "slots": SLOTS, "grades": GRADES, "render": None, "export": False, "bake": False, "full": False}
    i = 0
    while i < len(argv):
        a = argv[i]
        if a in ("--classes", "--slots", "--grades"):
            opt[a[2:]] = argv[i + 1].split(","); i += 1
        elif a == "--render":
            opt["render"] = os.path.abspath(argv[i + 1]); i += 1
        elif a in ("--export", "--bake", "--full"):
            opt[a[2:]] = True
        i += 1
    return opt


def render_preview(objs, prefix, textured):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x, scene.render.resolution_y = 520, 640
    scene.display_settings.display_device = "sRGB"
    scene.view_settings.view_transform = "Standard"
    sh = scene.display.shading
    sh.light = "FLAT" if textured else "STUDIO"
    sh.color_type = "TEXTURE" if textured else "MATERIAL"
    sh.background_type = "VIEWPORT"
    sh.background_color = (0.16, 0.17, 0.2)
    sh.show_cavity = False
    sh.show_shadows = False
    sh.show_object_outline = False
    lo, hi = A.bbox_world(objs)
    center = (lo + hi) / 2
    size = max((hi - lo).x, (hi - lo).y, (hi - lo).z)
    cam = A.camera()
    cam.data.ortho_scale = size * 1.12
    cam.data.clip_end = 500
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            o.hide_render = o not in objs
    out = []
    for nm, (yaw, pitch) in (("front", (0, 12)), ("back", (180, 12)), ("34", (40, 15))):
        A.aim(cam, center, yaw, pitch)
        scene.render.filepath = "%s_%s.png" % (prefix, nm)
        bpy.ops.render.render(write_still=True)
        out.append(scene.render.filepath)
    return out


FULL_BODY = {"UpperTorso": (2, 1.6, 1), "LowerTorso": (2, 0.4, 1), "LeftUpperArm": (1, 1.17, 1), "RightUpperArm": (1, 1.17, 1), "LeftLowerArm": (1, 1.05, 1),
             "RightLowerArm": (1, 1.05, 1), "LeftHand": (1, 0.3, 1), "RightHand": (1, 0.3, 1), "LeftUpperLeg": (1, 1.22, 1), "RightUpperLeg": (1, 1.22, 1),
             "LeftLowerLeg": (1, 1.19, 1), "RightLowerLeg": (1, 1.19, 1), "LeftFoot": (1, 0.3, 1), "RightFoot": (1, 0.3, 1), "Head": (1.2, 1.2, 1.2)}
FULL_POS = {"UpperTorso": (0, 0.2, 0), "LowerTorso": (0, -0.8, 0), "LeftUpperArm": (-1.5, 0.42, 0), "RightUpperArm": (1.5, 0.42, 0), "LeftLowerArm": (-1.5, -0.69, 0),
            "RightLowerArm": (1.5, -0.69, 0), "LeftHand": (-1.5, -1.37, 0), "RightHand": (1.5, -1.37, 0), "LeftUpperLeg": (-0.5, -1.6, 0), "RightUpperLeg": (0.5, -1.6, 0),
            "LeftLowerLeg": (-0.5, -2.8, 0), "RightLowerLeg": (0.5, -2.8, 0), "LeftFoot": (-0.5, -3.55, 0), "RightFoot": (0.5, -3.55, 0), "Head": (0, 1.6, 0)}
CLOTH_PREVIEW = {"greatsword": (102, 131, 74), "dualblade": (102, 131, 74), "bow": (102, 131, 74), "healer": (102, 131, 74)}  # 미리보기 세트 = 석조 평원 색1


def full_preview(cls, grade, outdir):
    """미리보기 전용: 마네킹(바닥층 색) + 3부위를 한 장면에 굽고 앞 · 뒤 · 3/4 렌더(천 = 세트 색1로 바꿔 칠함)"""
    global PAL_G
    A.reset()
    col = A.new_collection("full")
    base = (43, 53, 80) if cls in ("greatsword", "dualblade") else (232, 220, 192)
    man = []
    for part, size in FULL_BODY.items():
        man.append(A.make_obj("M_" + part, A.box(*size, b=0.06, center=FULL_POS[part]), (230, 200, 170) if part == "Head" else base, col))
    allobjs = []
    for slot in SLOTS:
        key, c2, objs, info = build(cls, slot, grade)
        bake(objs, key, MAP_RES[slot], grade)
        img = bpy.data.images.get("%s_color" % key)
        # 천 = 세트 색으로(게임: 알파 0 → 파트 색)
        px = list(img.pixels)
        mk = list(bpy.data.images.get("%s_mask" % key).pixels)
        cc = [A.srgb_to_linear(v) for v in CLOTH_PREVIEW[cls]]
        for i in range(0, len(px), 4):
            m = mk[i]
            if m > 0.01:
                for k in range(3):
                    px[i + k] = px[i + k] * (1 - m) + cc[k] * px[i + k] * m
        img.pixels[:] = px
        allobjs += objs
    for m in man:
        for mat in m.data.materials:
            mat.use_nodes = True
            nt = mat.node_tree
            for n in list(nt.nodes):
                if n.type == "TEX_IMAGE":
                    nt.nodes.remove(n)
    return render_preview(allobjs + man, os.path.join(outdir, "full_%s_%s" % (cls, grade)), True)


def main():
    global PAL
    PAL = palette_all()
    opt = parse()
    if opt["full"]:
        for cls in opt["classes"]:
            for grade in opt["grades"]:
                full_preview(cls, grade, opt["render"])
        return
    stats, meta = {}, {}
    for cls in opt["classes"]:
        for slot in opt["slots"]:
            for grade in opt["grades"]:
                A.reset()
                key, col, objs, info = build(cls, slot, grade)
                tri = sum(A.tri_count(o) for o in objs)
                stats[key] = dict(tris=tri, parts=len(objs), maxMeshTris=max(A.tri_count(o) for o in objs))
                if tri > BUDGET_TRIS[grade] or len(objs) > BUDGET_PARTS:
                    print("[look3] 예산 초과", key, tri, len(objs))
                if opt["bake"]:
                    bake(objs, key, MAP_RES[slot], grade)
                if opt["export"]:
                    A.export_fbx(os.path.join(OUT, "%s.fbx" % key), objs)
                    for o in objs:
                        pc = REF[info[o.name]][0]
                        cen = A.roblox_center(o)
                        meta.setdefault(key, {})[o.name] = dict(attach=info[o.name], offset=[round(cen[i] - pc[i], 3) for i in range(3)], refSize=list(REF[info[o.name]][1]), tris=A.tri_count(o), neon=False)
                if opt["render"]:
                    render_preview(objs, os.path.join(opt["render"], key), opt["bake"])
                print("[look3]", key, tri, len(objs))
    path = os.path.join(OUT, "look3.stats.json")
    old = json.load(open(path, encoding="utf-8")) if os.path.exists(path) else {}
    old.update(stats)
    A.write_json(path, old)
    if meta:
        mpath = os.path.join(OUT, "armor_wear.meta.json")
        d = json.load(open(mpath, encoding="utf-8"))
        d["pieces"].update(meta)
        A.write_json(mpath, d)
    print("[look3] 끝", len(stats))


if __name__ == "__main__":
    main()
