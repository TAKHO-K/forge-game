# -*- coding: utf-8 -*-
# A2-N1 무기(Blender bpy) - 대검 8등급 사다리 + 쌍검 · 활 · 지팡이 × 일반 · 전설 · 초월. 설계 = docs/art/asset-design-n1.md §1 · §2.
#   좌표 = 무기 로컬(WeaponRigSpec): 대검 · 쌍검 +Z 칼끝 · +X 날 폭 · Y 두께 / 활 +X 끝 축 / 지팡이 +Y 머리. 원점 = 손잡이 점(Grip).
#   출력: roblox/art/weapons/<무기>_<등급>.fbx · <무기>.blend · <무기>.meta.json(등급별 파트 · 삼각형 · 부착점)
#   렌더: --render <폴더> → <무기>_<등급>_{game,form}_{front,side,34}.png · _sil_front.png(합치기는 compose.py)
# 실행: blender -b --factory-startup -P make_weapons.py -- --items greatsword:normal[,greatsword:rare ...] [--render 폴더] [--no-export] [--ladder 폴더] [--compare-old 폴더]
import bpy
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import artlib as A  # noqa: E402
from mathutils import Vector  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "art", "weapons"))
TRI_BUDGET = 800
PART_CAP = {"normal": 8, "rare": 8, "epic": 8, "legendary": 12, "relic": 12, "ancient": 12, "primordial": 16, "transcendent": 16}
RANK = {g: i for i, g in enumerate(A.GRADES)}


def at_least(grade, g):
    return RANK[grade] >= RANK[g]


# ────────────────────────── 대검 ──────────────────────────
GS = dict(tipZ=4.74, pommelZ=-0.66, guardZ=0.74, supportZ=-0.48)


def detail(grade):
    """손잡이 · 폼멜 단면 점 수: 일반 ~ 전설 = 8(예산 50 ~ 80%를 형태에) · 유물 이상 = 6(상한 800 안에서 장식에 양보)"""
    return 8 if RANK[grade] <= RANK["legendary"] else 6


def blade_fine(grade):
    """날 쪽 모따기 한 단 더(10점 단면)는 장식이 적은 일반 · 희귀만 - 영웅부터는 가드 말림이 그 삼각형을 쓴다"""
    return RANK[grade] <= RANK["rare"]


def blade_section(wp, wn, t, fine=False):
    """+X 쪽 반폭 wp · −X 쪽 반폭 wn · 가운데 두께 t(반) - 가운데 능선 + 날 쪽으로 얇게. fine = 날 쪽 모따기 한 단 더(빛 맺힘)"""
    if fine:
        return [(wp, 0), (wp * 0.62, t * 0.62), (wp * 0.3, t), (-wn * 0.3, t), (-wn * 0.62, t * 0.62), (-wn, 0), (-wn * 0.62, -t * 0.62), (-wn * 0.3, -t), (wp * 0.3, -t), (wp * 0.62, -t * 0.62)]
    return [(wp, 0), (wp * 0.3, t), (-wn * 0.3, t), (-wn, 0), (-wn * 0.3, -t), (wp * 0.3, -t)]


def gs_blade(grade):
    # 넓은 쐐기(가드 1.04 → 폭을 3/4까지 유지 → 끝 0.78) · −X 날만 배부르게(한쪽 과장) · +X 날에만 톱니 1개(비대칭)
    st = [(0.84, 0.52, 0.52, 0.125), (1.28, 0.6, 0.6, 0.122), (1.40, 0.38, 0.62, 0.12),
          (1.52, 0.62, 0.63, 0.12), (2.5, 0.6, 0.68, 0.11), (3.45, 0.54, 0.64, 0.095), (4.15, 0.36, 0.42, 0.075)]
    rings = [[(x, y, z) for x, y in blade_section(wp, wn, t, blade_fine(grade))] for z, wp, wn, t in st]
    return A.loft(rings, tip1=(0, 0, GS["tipZ"]))


SLOT = dict(z0=0.98, z1=1.86, w=0.2)


def slot_loop(pad=0.0, n=14):
    """관통 홈 윤곽(XZ 평면 · 둥근 끝 길쭉한 창)"""
    r = SLOT["w"] / 2 + pad
    za, zb = SLOT["z0"] + SLOT["w"] / 2, SLOT["z1"] - SLOT["w"] / 2
    pts = []
    half = n // 2
    for i in range(half + 1):
        a = math.pi * i / half
        pts.append((r * math.cos(a), zb + r * math.sin(a)))
    for i in range(half + 1):
        a = math.pi + math.pi * i / half
        pts.append((r * math.cos(a), za + r * math.sin(a)))
    return pts


def frame_loop(loop, inset, outset, h):
    """윤곽(XZ) 둘레의 테(안쪽 inset · 바깥 outset · 두께 ±h - Y). 닫힌 고리 사각 튜브"""
    n = len(loop)
    cx = sum(p[0] for p in loop) / n
    cz = sum(p[1] for p in loop) / n
    rings = []
    for d, y in ((outset, h), (-inset, h), (-inset, -h), (outset, -h)):
        ring = []
        for x, z in loop:
            vx, vz = x - cx, z - cz
            L = math.hypot(vx, vz) or 1
            ring.append((x + vx / L * d, y, z + vz / L * d))
        rings.append(ring)
    verts = [p for r in rings for p in r]
    faces = []
    for k in range(4):
        a, b = k * n, ((k + 1) % 4) * n
        for i in range(n):
            j = (i + 1) % n
            faces.append((a + i, a + j, b + j, b + i))
    return verts, faces


def gs_guard(grade):
    wide = 1.6 if at_least(grade, "legendary") else 1.0
    gz = GS["guardZ"]
    # 오른쪽 반: 가운데 → 끝(칼끝 쪽으로 살짝 휨) [+ 영웅부터 끝 말림]
    half = A.bezier((0, 0, gz - 0.04), (0.35, 0, gz - 0.1), (0.7, 0, gz - 0.02), (0.95, 0, gz + 0.16), n=4)
    if at_least(grade, "epic"):
        cx, cz, r0 = 0.95, gz + 0.36, 0.2
        curl = []
        for i in range(1, 6):
            u = i / 5
            a = u * 1.55 * math.pi  # 아래 → 바깥 → 위 → 안쪽(칼 쪽)
            r = r0 * (1 - 0.45 * u)
            curl.append((cx + r * math.sin(a), 0, cz - r * math.cos(a)))
        half = half + curl
    half = [(x * wide, y, z) for x, y, z in half]
    path = [(-x, y, z) for x, y, z in reversed(half)] + half[1:]
    n = len(path)

    def rad(u):
        c = 1 - abs(u - 0.5) * 2  # 가운데 1 → 끝 0
        return 0.1 + 0.08 * c ** 0.7

    g = A.tube(path, rad, sides=4, flat=1.35, twist=math.pi / 4)
    collar_w = 0.62 if at_least(grade, "legendary") else 0.46
    collar = A.box(collar_w, 0.36, 0.3, b=0.07, center=(0, 0, gz))
    return A.merge(g, collar)


def gs_grip(grade):
    zs = [-0.56, -0.3, -0.04, 0.22, 0.58]
    rings = []
    for i, z in enumerate(zs):
        r = 0.22 if i % 2 == 0 else 0.19  # 감개 줄(두툼 · 가늘 번갈아) - 날 폭의 25% 이상(두툼함)
        rings.append([(x, y, z) for x, y in A.circle2d(r, detail(grade), start=math.pi / 6)])
    return A.loft(rings)


def gs_pommel(grade):
    z = GS["pommelZ"]
    prof = [(0.0, -0.34), (0.12, -0.3), (0.21, -0.19), (0.215, -0.06), (0.15, 0.04), (0.11, 0.08)]
    g = A.xform(A.lathe(prof, detail(grade), axis="Z"), t=(0, 0, z))
    g = A.xform(g, t=(0, 0, 0))
    if at_least(grade, "relic"):
        spikes = []
        for k in range(4):
            a = math.pi / 4 + k * math.pi / 2
            d = (math.cos(a), math.sin(a) * 0.8, -0.35)
            L = math.sqrt(sum(c * c for c in d))
            d = tuple(c / L for c in d)
            base = (d[0] * 0.18, d[1] * 0.18, z - 0.16 + d[2] * 0.1)
            tip = (base[0] + d[0] * 0.42, base[1] + d[1] * 0.42, base[2] + d[2] * 0.42)
            spikes.append(A.tube([base, tip], lambda u: 0.1 * (1 - u) + 0.01, sides=4, tip_end=True))
        g = A.merge(g, *spikes)
    return g


def gs_gem():
    # 가드 위아래로 튀어나온 마름모(실루엣에 드러남 - 아래는 손잡이 양옆으로 보인다)
    prof = [(0.0, -0.2), (0.17, -0.08), (0.2, 0.0), (0.17, 0.08), (0.0, 0.2)]
    return A.xform(A.lathe(prof, 4, axis="Y"), s=(1.2, 1, 2.3), t=(0, 0, GS["guardZ"]))


def gs_runes():
    # 룬 가시 2쌍: 날 양 가장자리에서 칼끝 쪽으로 돋은 가시(0.25 돌출 - 윤곽에 드러나는 유물 단계 · 고대 이상 누적)
    out = []
    for z, xp, xn in ((2.35, 0.6, 0.67), (2.95, 0.57, 0.66)):
        for x0, sgn in ((xp, 1), (-xn, -1)):
            out.append(A.tube([(x0 - sgn * 0.1, 0, z - 0.14), (x0 + sgn * 0.36, 0, z + 0.2)], lambda u: 0.1 * (1 - u) + 0.01, sides=4, flat=1.4, tip_end=True))  # 밑동 폭 0.28 쐐기 · 돌출 ≈ 날 폭 40%
    return A.merge(*out)


def gs_wing(sign):
    feathers = []
    root = (sign * 1.18, 0, GS["guardZ"] + 0.18)
    for k, (length, ang) in enumerate(((1.15, 14), (0.9, 34), (0.66, 56))):
        a = math.radians(ang)
        d = (sign * math.sin(a), 0, math.cos(a))
        pts = [(root[0] + d[0] * length * u - sign * 0.05 * k, 0, root[2] + d[2] * length * u - 0.08 * k) for u in (0, 0.5, 1.0)]
        feathers.append(A.tube(pts, lambda u: (0.19 * math.sin(math.pi * (0.2 + 0.8 * u)) + 0.05) / 3.0, sides=4, flat=3.0, tip_end=True))  # 법선 = Y(두께) · 종법선 = 앞에서 보이는 폭
    return A.merge(*feathers)


def gs_crystals():
    out = []
    for k, (a, z, h) in enumerate(((20, 1.5, 0.68), (165, 2.2, 0.56))):
        r = math.radians(a)
        out.append(A.crystal(h, 0.13, sides=4, tip_h=0.2, base_h=0.12, center=(math.cos(r) * 0.98, math.sin(r) * 0.45, z), m=A.rot(rx=90 + 12 * math.sin(k), ry=-a * 0.15)))
    return A.merge(*out)


def gs_shards():
    out = []
    # 3개 · 날 폭의 35 ~ 40% · 날 옆 0.4 간격 · 날 길이 60 ~ 90% 높이(비대칭 - 오른쪽 둘 · 왼쪽 하나)
    for k, (x, z, s, tilt) in enumerate(((1.12, 3.05, 0.4, -25), (1.0, 4.05, 0.3, -35), (-1.18, 3.55, 0.36, 30))):
        out.append(A.shard(s, seed=k + 1, center=(x, 0.0, z), m=A.rot(rx=90, ry=tilt)))
    return A.merge(*out)


def gs_halo():
    n = 8
    path = [(0.95 * math.cos(2 * math.pi * i / n), 0.3 * math.sin(2 * math.pi * i / n), 2.0 + 0.42 * math.sin(2 * math.pi * i / n)) for i in range(n + 1)]  # 정면에서 타원으로 보이게 기울임
    return A.tube(path, 0.09, sides=3, cap0=False)


def gs_cracks():
    out = []
    for zs, xs in (((1.95, 2.3, 2.7, 3.1, 3.5), (0.3, 0.02, 0.22, -0.12, 0.08)), ((2.5, 2.95, 3.4, 3.85, 4.2), (-0.42, -0.14, -0.3, -0.02, -0.1))):
        # 균열 = 날을 관통하는 납작 띠 1줄(양면에 동시에 보인다 - Y 반경 > 날 두께)
        pts = [(x, 0, z) for z, x in zip(zs, xs)]
        out.append(A.tube(pts, lambda u: 0.2, sides=4, flat=0.36, twist=math.pi / 4))  # Y 반경 > 날 두께(양면으로 뚫고 나옴) · 앞에서 보이는 폭 = ×0.5
    return out


def gs_palette(grade):
    gc = A.GRADE_COLOR[grade]
    p = dict(blade=A.STEEL, guard=A.IRON, grip=A.LEATHER, pommel=A.IRON, fuller=gc, gem=(255, 244, 214), runes=gc, wing=gc, crystal=gc, halo=gc)
    if at_least(grade, "epic"):
        p.update(guard=gc, pommel=gc)
    if at_least(grade, "legendary"):
        p.update(blade=A.STEEL_BRIGHT, grip=A.LEATHER_DARK)
    if grade == "relic":
        p.update(runes=(255, 226, 90))
    if grade == "primordial":
        p.update(blade=(244, 242, 250), guard=(236, 232, 246), pommel=(236, 232, 246), grip=(120, 70, 130), wing=(250, 236, 248))
    if grade == "transcendent":
        p.update(blade=A.BLACK_BODY, guard=A.GOLD, pommel=A.GOLD, grip=A.BLACK_SHADE, fuller=A.GOLD, gem=(255, 214, 90), wing=A.BLACK_BODY, halo=A.GOLD_GLOW, crack=A.GOLD_GLOW)
    return p


def greatsword_parts(grade):
    """[(이름, geo, 색, neon, bevel)] - 등급이 오를수록 실루엣 한 겹씩(설계서 §1 표)"""
    P = gs_palette(grade)
    parts = [("Blade", gs_blade(grade), P["blade"], False, 0.022)]
    if at_least(grade, "rare"):
        parts.append(("Fuller", frame_loop(slot_loop(n=6), 0.0, 0.06, 0.135), P["fuller"], False, 0.0))
    parts += [("Guard", gs_guard(grade), P["guard"], False, 0.0), ("Grip", gs_grip(grade), P["grip"], False, 0.0), ("Pommel", gs_pommel(grade), P["pommel"], False, 0.0)]
    if at_least(grade, "legendary"):
        parts.append(("Gem", gs_gem(), P["gem"], True, 0.0))
    if at_least(grade, "relic"):  # 유물 = 룬 가시(발광) · 고대 이상은 같은 가시가 등급 색으로 남는다(누적)
        parts.append(("Runes", gs_runes(), P["runes"], grade == "relic", 0.0))
    if at_least(grade, "ancient"):
        parts += [("Wing_R", gs_wing(1), P["wing"], False, 0.0), ("Wing_L", gs_wing(-1), P["wing"], False, 0.0)]
    if grade == "primordial":
        parts += [("Crystals", gs_crystals(), P["crystal"], True, 0.0), ("Halo", gs_halo(), P["halo"], True, 0.0)]
    if grade == "transcendent":
        c1, c2 = gs_cracks()
        parts += [("Shards", gs_shards(), A.BLACK_BODY, False, 0.0),
                  ("Crack1", c1, P["crack"], True, 0.0), ("Crack2", c2, P["crack"], True, 0.0)]
    return parts


def cut_slot(blade, col):
    """희귀부터: 날에 관통 홈(Boolean 차집합 - 실루엣에 구멍)"""
    loop = slot_loop(n=8)
    rings = [[(x, y, z) for x, z in loop] for y in (-0.5, 0.5)]
    cutter = A.make_obj("Cutter", A.loft(rings), (0, 0, 0), col)
    m = blade.modifiers.new("Slot", "BOOLEAN")
    m.operation = "DIFFERENCE"
    m.solver = "EXACT"
    m.object = cutter
    bpy.context.view_layer.objects.active = blade
    with bpy.context.temp_override(object=blade, active_object=blade):
        bpy.ops.object.modifier_apply(modifier="Slot")
    bpy.data.objects.remove(cutter)
    blade["TriCount"] = A.tri_count(blade)


# ────────────────────────── 공통 초월 언어(4무기) ──────────────────────────
def float_shards(anchors, size=0.16):
    """떠 있는 흑금 조각 - anchors = [(x, y, z), ...] (무기 로컬)"""
    return A.merge(*[A.shard(size * (1 - 0.12 * k), seed=k + 3, center=p, m=A.rot(rx=60 + 25 * k, rz=40 * k)) for k, p in enumerate(anchors)])


def crack_line(pts, depth, width):
    """금빛 균열 = 본체를 관통하는 납작 띠(depth = 법선 쪽 반경 > 본체 반두께 · width = 앞에서 보이는 반폭)"""
    return A.tube(pts, depth, sides=4, flat=width / depth, twist=math.pi / 4)


def common_palette(grade, base, trim):
    """base = 본체 색 · trim = 장식(가드 · 끝) 색. 전설 = 장식 등급 색 · 초월 = 검은 본체 + 금 장식"""
    gc = A.GRADE_COLOR[grade]
    p = dict(base=base, trim=trim, grip=A.LEATHER, gem=(255, 244, 214), accent=gc)
    if at_least(grade, "legendary"):
        p.update(trim=gc, grip=A.LEATHER_DARK)
    if grade == "transcendent":
        p.update(base=A.BLACK_BODY, trim=A.GOLD, grip=A.BLACK_SHADE, gem=(255, 214, 90), accent=A.GOLD)
    return p


# ────────────────────────── 쌍검(한 자루 - BladeRight · BladeLeft 공용) ──────────────────────────
DB = dict(tipZ=2.1, baseZ=0.28, pommelZ=-0.52, guardZ=0.2)


def db_center_x(u):
    return 0.42 * u * u  # 칼끝이 날(+X) 쪽으로 들린 초승달 → 등(−X)이 볼록


def db_blade(grade):
    fine = RANK[grade] <= RANK["legendary"]
    rings = []
    for u in (0.0, 0.15, 0.35, 0.55, 0.75, 0.9):
        z = DB["baseZ"] + (DB["tipZ"] - DB["baseZ"]) * u
        wp = 0.25 + 0.08 * math.sin(math.pi * min(1, u / 0.6)) * (1 - u) - 0.12 * u * u  # 날 쪽 배(0.3 부근) → 끝으로 가늘게
        wn = 0.1 - 0.06 * u
        t = 0.09 - 0.045 * u
        cx = db_center_x(u)
        sec = [(wp, 0), (wp * 0.7, t * 0.5), (wp * 0.3, t), (-wn, t * 0.85), (-wn, -t * 0.85), (wp * 0.3, -t), (wp * 0.7, -t * 0.5)] if fine else \
            [(wp, 0), (wp * 0.35, t), (-wn, t * 0.85), (-wn, -t * 0.85), (wp * 0.35, -t)]
        rings.append([(x + cx, y, z) for x, y in sec])
    g = A.loft(rings, tip1=(db_center_x(1.0), 0, DB["tipZ"]))
    # 등 뒤 이빨 1개(비대칭 포인트) - 가드 쪽 1/4
    z0 = DB["baseZ"] + 0.35
    tooth = A.tube([(-0.05, 0, z0 - 0.08), (-0.2, 0, z0 + 0.02), (-0.3, 0, z0 + 0.16)], lambda u: 0.06 * (1 - u) + 0.01, sides=4, flat=0.6, tip_end=True)
    return A.merge(g, tooth)


def db_guard(grade):
    gz = DB["guardZ"]
    collar = A.box(0.46, 0.2, 0.12, b=0.045, center=(0.02, 0, gz))
    # D자 손가락 보호 고리(+X = 손가락 쪽 · 곡선 덩어리)
    bow = A.bezier((0.2, 0, gz - 0.02), (0.62, 0, gz - 0.02), (0.6, 0, DB["pommelZ"] + 0.02), (0.1, 0, DB["pommelZ"] + 0.04), n=7)
    g = A.merge(collar, A.tube(bow, lambda u: 0.05 + 0.02 * math.sin(math.pi * u), sides=5, flat=0.8))
    if at_least(grade, "legendary"):  # 고리 바깥 가시 1(실루엣 한 단계)
        mid = A.bezier((0.2, 0, gz - 0.02), (0.62, 0, gz - 0.02), (0.6, 0, DB["pommelZ"] + 0.02), (0.1, 0, DB["pommelZ"] + 0.04), n=2)[1]
        g = A.merge(g, A.tube([mid, (mid[0] + 0.32, 0, mid[2] + 0.12)], lambda u: 0.07 * (1 - u) + 0.01, sides=4, flat=0.7, tip_end=True))
    return g


def db_grip(grade):
    rings = [[(x, y, z) for x, y in A.circle2d(0.075 if i % 2 else 0.085, detail(grade))] for i, z in enumerate((-0.44, -0.2, 0.0, 0.16))]
    return A.loft(rings)


def db_pommel(grade):
    prof = [(0.0, -0.2), (0.08, -0.17), (0.12, -0.08), (0.09, 0.0), (0.06, 0.03)]
    return A.xform(A.lathe(prof, detail(grade), axis="Z"), t=(0, 0, DB["pommelZ"] + 0.06))


def dualblade_parts(grade):
    P = common_palette(grade, A.STEEL, A.IRON)
    parts = [("Blade", db_blade(grade), P["base"], False, 0.015), ("Guard", db_guard(grade), P["trim"], False, 0.0),
             ("Grip", db_grip(grade), P["grip"], False, 0.0), ("Pommel", db_pommel(grade), P["trim"], False, 0.0)]
    if at_least(grade, "legendary"):
        parts.append(("Gem", A.crystal(0.2, 0.08, sides=4, tip_h=0.08, base_h=0.08, center=(0.02, -0.12, DB["guardZ"]), m=A.rot(rx=90)), P["gem"], True, 0.0))
    if grade == "transcendent":
        pts = [(db_center_x(u) + dx, 0, DB["baseZ"] + (DB["tipZ"] - DB["baseZ"]) * u) for u, dx in ((0.12, 0.02), (0.3, 0.1), (0.48, -0.01), (0.66, 0.07), (0.8, 0.0))]
        parts += [("Shards", float_shards([(-0.62, 0.0, 1.15), (0.78, 0.0, 1.55), (-0.45, 0.0, 2.05)], 0.22), A.BLACK_BODY, False, 0.0),
                  ("Crack1", crack_line(pts, 0.11, 0.06), A.GOLD_GLOW, True, 0.0)]
    return parts


# ────────────────────────── 활(+X 위 날개 · +Z 시위 쪽 · 원점 = 손잡이) ──────────────────────────
BW = dict(tipX=2.87, nockZ=1.40)


def bw_limb_path(sign):
    """손잡이 → 날개 끝(시위 매듭) → 바깥(−Z)으로 되감긴 반곡. 위 날개(+)가 더 크게 말림(비대칭)"""
    body = A.bezier((0.42, 0, 0.0), (1.4, 0, -0.22), (2.45, 0, 0.42), (BW["tipX"], 0, BW["nockZ"]), n=9)
    curl = [(3.1, 0, 1.46), (3.36, 0, 1.28), (3.46, 0, 0.98)] if sign > 0 else [(3.06, 0, 1.46), (3.26, 0, 1.3), (3.32, 0, 1.1)]
    return [(sign * x, y, z) for x, y, z in body + curl]


def bw_limb(sign, grade):
    path = bw_limb_path(sign)
    n = len(path)
    g = A.tube(path, lambda u: 0.21 - 0.12 * u, sides=6 if RANK[grade] <= RANK["legendary"] else 4, flat=1.1, tip_end=True)  # 법선 = Y(날개 너비) · 종법선 = 휨 평면 두께(두툼하게)
    if at_least(grade, "legendary"):  # 날개 끝 지느러미(실루엣 한 단계) - 되감긴 곳 바깥
        a = path[n - 3]
        g = A.merge(g, A.tube([a, (a[0] + sign * 0.3, 0, a[2] - 0.58)], lambda u: 0.13 * (1 - u) + 0.01, sides=4, flat=0.8, tip_end=True))
    return g


def bw_riser(grade):
    prof = [(0.0, -0.66), (0.14, -0.6), (0.21, -0.42), (0.23, 0.0), (0.21, 0.42), (0.14, 0.6), (0.0, 0.66)]
    return A.xform(A.lathe(prof, detail(grade), axis="X"), s=(1, 1, 1.25), t=(0, 0, -0.03))


def bw_grip(grade):
    rings = [[(x, y, z) for x, y, z in [(xx, math.cos(2 * math.pi * k / detail(grade)) * r, math.sin(2 * math.pi * k / detail(grade)) * r * 1.2) for k in range(detail(grade))]] for xx, r in ((-0.34, 0.25), (-0.1, 0.27), (0.1, 0.27), (0.34, 0.25))]
    return A.loft(rings)


def bow_parts(grade):
    P = common_palette(grade, A.WOOD, A.WOOD_TOP)
    parts = [("Riser", bw_riser(grade), P["base"], False, 0.0), ("Grip", bw_grip(grade), P["grip"], False, 0.0),
             ("Limb_Top", bw_limb(1, grade), P["base"], False, 0.0), ("Limb_Bottom", bw_limb(-1, grade), P["base"], False, 0.0),
             ("String", A.tube([(BW["tipX"], 0, BW["nockZ"]), (-BW["tipX"], 0, BW["nockZ"])], 0.028, sides=3), (235, 235, 235), False, 0.0)]
    if at_least(grade, "legendary"):
        caps = A.merge(*[A.xform(A.lathe([(0.0, -0.2), (0.18, -0.1), (0.17, 0.1), (0.0, 0.2)], 5, axis="X"), t=(s * BW["tipX"], 0, BW["nockZ"])) for s in (1, -1)])
        # 손잡이 위아래 화살받이 판 2(과녁 쪽 −Z로 0.4 돌출 · 두께 0.25 - 전설 실루엣 한 단계)
        rests = A.merge(*[A.tube([(s * 0.5, 0, -0.1), (s * 0.62, 0, -0.45), (s * 0.5, 0, -0.68)], lambda u: 0.14 * (1 - u) + 0.04, sides=4, flat=0.9, tip_end=True) for s in (1, -1)])
        parts += [("Tips", A.merge(caps, rests), P["trim"], False, 0.0),
                  ("Gem", A.crystal(0.36, 0.15, sides=4, tip_h=0.12, base_h=0.12, center=(0, 0, -0.36), m=A.rot(rx=90)), P["gem"], True, 0.0)]
    if grade == "transcendent":
        pts = [(x, 0, z) for x, _, z in bw_limb_path(1)[1:6]]
        pts = [(x + 0.02 * (-1) ** i, 0, z - 0.03 * (-1) ** i) for i, (x, _, z) in enumerate(pts)]
        parts += [("Shards", float_shards([(1.05, 0.0, -0.75), (-1.35, 0.0, -0.7), (0.1, 0.0, -1.0)], 0.4), A.BLACK_BODY, False, 0.0),
                  ("Crack1", crack_line(pts, 0.19, 0.07), A.GOLD_GLOW, True, 0.0),
                  ("Crack2", crack_line([(-x, y, z) for x, y, z in pts], 0.19, 0.07), A.GOLD_GLOW, True, 0.0)]
    return parts


# ────────────────────────── 지팡이(+Y 머리 · 원점 = 오른손 손잡이) ──────────────────────────
ST = dict(bottomY=-2.2, topY=3.4, orbY=3.02, neckY=2.5)


def st_shaft(grade):
    n = detail(grade) - 2 if RANK[grade] <= RANK["legendary"] else 5  # 6각(일반 · 전설) · 4각(초월) - 도는 단면 = 비틀림
    rings = []
    K = 12
    ys = [ST["bottomY"] + 0.2 + (ST["neckY"] - ST["bottomY"] - 0.2) * k / K for k in range(K + 1)]
    for k, y in enumerate(ys):
        u = k / K
        r = 0.17 + 0.08 * u ** 1.4  # 아래로 가늘게(두툼함 - 밑동도 0.34 지름)
        cx = 0.07 * math.sin(math.pi * u)  # 살짝 휜 나무
        rings.append([(x + cx, y, z) for x, z in A.circle2d(r, n, start=2 * math.pi * u * 0.9)])
    return A.loft(rings)


def st_hooks(grade):
    """머리에서 갈라져 구슬을 감싸는 갈고리 두 가닥 - 왼쪽이 더 길게 말림(비대칭)"""
    oy = ST["orbY"]
    left = A.bezier((-0.04, ST["neckY"], 0), (-0.72, oy - 0.25, 0), (-0.68, oy + 0.65, 0), (-0.02, oy + 0.54, 0), n=7) + [(0.16, oy + 0.36, 0)]
    right = A.bezier((0.06, ST["neckY"], 0), (0.62, oy - 0.3, 0), (0.6, oy + 0.2, 0), (0.28, oy + 0.36, 0), n=5)
    sides = 5 if RANK[grade] <= RANK["legendary"] else 4
    k = 1.25  # 머리 = 전체 길이의 약 18%(구슬 중심 기준 확대)
    left, right = [[(x * k, oy + (y - oy) * k, z) for x, y, z in pts] for pts in (left, right)]
    g = A.merge(A.tube(left, lambda u: 0.17 - 0.13 * u, sides=sides, flat=0.8, tip_end=True),
                A.tube(right, lambda u: 0.16 - 0.12 * u, sides=sides, flat=0.8, tip_end=True))
    if at_least(grade, "legendary"):  # 머리 위 가시 왕관 3(실루엣 한 단계)
        spikes = [A.tube([(dx * 0.5, oy + 0.3, 0), (dx, oy + 0.3 + h, 0)], lambda u: 0.06 * (1 - u) + 0.01, sides=4, tip_end=True) for dx, h in ((-0.12, 0.62), (0.02, 0.78), (0.16, 0.55))]
        g = A.merge(g, *[A.xform(s_, t=(0, 0.1, 0)) for s_ in spikes])
    return g


def st_leaf():
    path = [(0.1, 1.95, 0), (0.38, 2.08, 0.02), (0.56, 2.3, 0.04), (0.6, 2.52, 0.05)]
    return A.tube(path, lambda u: 0.16 * math.sin(math.pi * min(1.0, 0.15 + u)) + 0.02, sides=4, flat=0.3, tip_end=True)


def healer_parts(grade):
    P = common_palette(grade, A.WOOD, A.IRON)
    orb = (140, 240, 200) if grade != "transcendent" else (255, 214, 90)
    parts = [("Shaft", st_shaft(grade), P["base"], False, 0.0), ("Head", st_hooks(grade), P["trim"] if grade != "normal" else A.WOOD_TOP, False, 0.0),
             ("Orb", A.ellipsoid((0.42, 0.42, 0.42), n=detail(grade), rings=5, center=(0, ST["orbY"], 0)), orb, grade != "normal", 0.0),
             ("Leaf", st_leaf(), (126, 196, 70) if grade != "transcendent" else A.GOLD, False, 0.0),
             ("Ferrule", A.xform(A.lathe([(0.0, -0.12), (0.07, -0.08), (0.11, 0.1), (0.1, 0.22)], detail(grade) - 2), t=(0, ST["bottomY"], 0)), P["trim"] if grade != "normal" else A.IRON, False, 0.0)]
    if at_least(grade, "legendary"):
        ring = [(0.2 * math.cos(2 * math.pi * k / 8), ST["neckY"] - 0.08, 0.2 * math.sin(2 * math.pi * k / 8)) for k in range(9)]
        parts.append(("Band", A.tube(ring, 0.06, sides=4, cap0=False), P["accent"], False, 0.0))
    if grade == "transcendent":
        pts = [(0.05 * (-1) ** k + 0.07 * math.sin(math.pi * (y - ST["bottomY"]) / (ST["neckY"] - ST["bottomY"])), y, 0) for k, y in enumerate((-1.2, -0.5, 0.2, 0.9, 1.6, 2.2))]
        parts += [("Shards", float_shards([(-1.15, 3.3, 0.0), (1.1, 2.7, 0.0), (0.75, 3.95, 0.0)], 0.34), A.BLACK_BODY, False, 0.0),
                  ("Crack1", crack_line(pts, 0.28, 0.07), A.GOLD_GLOW, True, 0.0)]
    return parts


# ────────────────────────── 공통 짓기 ──────────────────────────
BUILDERS = {"greatsword": greatsword_parts, "dualblade": dualblade_parts, "bow": bow_parts, "healer": healer_parts}
ATTACH = {"greatsword": dict(Grip=(0, 0, 0), Tip=(0, 0, GS["tipZ"]), Support=(0, 0, GS["supportZ"])),
          "dualblade": dict(Grip=(0, 0, 0), Tip=(0, 0, DB["tipZ"])),
          "bow": dict(Grip=(0, 0, 0), Tip=(BW["tipX"], 0, BW["nockZ"]), StringNock=(0, 0, BW["nockZ"])),
          "healer": dict(Grip=(0, 0, 0), Tip=(0, ST["topY"], 0), Support=(0, 1.0, 0))}
NOTES = {"dualblade": "한 자루 모델을 BladeRight · BladeLeft 두 조각에 같이 쓴다(WeaponModels.dualblade 자식 2개로 복제)",
         "bow": "String 파트는 렌더 · 아이콘 전용 - 게임은 시위를 코드로 그린다(가져올 때 String은 지운다)"}


def build(weapon, grade):
    col = A.new_collection("%s_%s" % (weapon, grade))
    objs = []
    for name, geo, rgb, neon, bev in BUILDERS[weapon](grade):
        o = A.make_obj(name, geo, rgb, col, neon=neon, bevel=bev, bevel_angle=50.0, mat_name="%s_%s_%s" % (weapon, grade, name))
        if weapon == "greatsword" and name == "Blade" and at_least(grade, "rare"):
            cut_slot(o, col)
        objs.append(o)
    return col, objs


def parse():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opt = {"items": [], "render": None, "export": True, "ladder": None}
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--items":
            opt["items"] = [tuple(s.split(":")) for s in argv[i + 1].split(",")]
            i += 1
        elif a == "--render":
            opt["render"] = os.path.abspath(argv[i + 1])
            i += 1
        elif a == "--ladder":
            opt["ladder"] = os.path.abspath(argv[i + 1])
            i += 1
        elif a == "--no-export":
            opt["export"] = False
        i += 1
    return opt


# 렌더용 받침 회전(도) - 긴 축이 화면 위, 모양이 보이는 면이 카메라 정면(Blender +Y 쪽)
DISPLAY_ROT = {"greatsword": (-90, 0, 0), "dualblade": (-90, 0, 0),  # 칼끝(Roblox +Z = Blender −Y) → 위
               "bow": (-90, -90, 0),  # 날개(Roblox +X) → 위 · 시위(Roblox +Z)는 화면 오른쪽 - 활의 휨이 정면에 보인다
               "healer": (0, 0, 0)}  # 머리 = Roblox +Y = Blender +Z(이미 위)


def main():
    opt = parse()
    A.reset()
    metas = {}
    groups = []
    for weapon, grade in opt["items"]:
        col, objs = build(weapon, grade)
        total = sum(A.tri_count(o) for o in objs)
        cap = PART_CAP[grade]
        print("[make_weapons] %s %s 파트 %d(상한 %d) · 삼각형 %d / %d = %.0f%% · %s" % (weapon, grade, len(objs), cap, total, TRI_BUDGET, 100 * total / TRI_BUDGET, {o.name: A.tri_count(o) for o in objs}))
        metas.setdefault(weapon, {})[grade] = A.meta_of(objs, TRI_BUDGET, {"partCap": cap})
        if opt["export"]:
            A.export_fbx(os.path.join(OUT, "%s_%s.fbx" % (weapon, grade)), objs)
        for o in objs:
            o.name = "%s.%s" % (o.name, grade)
        groups.append((weapon, grade, objs))
    if opt["export"]:
        for weapon, grades in metas.items():
            path = os.path.join(OUT, "%s.meta.json" % weapon)
            old = {}
            if os.path.exists(path):
                import json
                with open(path, encoding="utf-8") as f:
                    old = json.load(f)
            looks = old.get("looks", {}) if old.get("version") == "A2-N1" else {}
            looks.update(grades)
            A.write_json(path, {"version": "A2-N1", "rigId": weapon, "pivot": "Grip", "attachments": ATTACH[weapon], "triBudget": TRI_BUDGET, "note": NOTES.get(weapon, ""), "looks": looks})
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "%s.blend" % groups[0][0]))
    if opt["render"]:
        for weapon, grade, objs in groups:
            e = A.stand(objs)
            e.rotation_euler = tuple(math.radians(a) for a in DISPLAY_ROT[weapon])
            A.render_views(objs, os.path.join(opt["render"], "%s_%s" % (weapon, grade)), hull=0.045, res=(700, 900))
            A.unstand(objs, e)
    print("[make_weapons] 끝")


if __name__ == "__main__":
    main()
