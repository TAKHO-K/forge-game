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


def blade_section(wp, wn, t):
    """+X 쪽 반폭 wp · −X 쪽 반폭 wn · 가운데 두께 t(반) - 가운데 능선 + 날 쪽으로 얇게(10점)"""
    return [(wp, 0), (wp * 0.3, t), (-wn * 0.3, t), (-wn, 0), (-wn * 0.3, -t), (wp * 0.3, -t)]


def gs_blade(grade):
    # 잎 모양(가드 쪽 1.0 → 배 1.14 → 끝 0.58) · +X 날에만 톱니 1개(비대칭)
    st = [(0.84, 0.50, 0.50, 0.125), (1.28, 0.57, 0.56, 0.122), (1.40, 0.37, 0.565, 0.12),
          (1.52, 0.585, 0.57, 0.12), (2.3, 0.565, 0.565, 0.108), (3.3, 0.45, 0.45, 0.09), (4.1, 0.29, 0.29, 0.07)]
    rings = [[(x, y, z) for x, y in blade_section(wp, wn, t)] for z, wp, wn, t in st]
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
    wide = 1.35 if at_least(grade, "legendary") else 1.0
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
        return 0.06 + 0.11 * c ** 0.7

    g = A.tube(path, rad, sides=4, flat=1.35, twist=math.pi / 4)
    collar_w = 0.62 if at_least(grade, "legendary") else 0.46
    collar = A.box(collar_w, 0.36, 0.3, b=0.07, center=(0, 0, gz))
    return A.merge(g, collar)


def gs_grip():
    zs = [-0.56, -0.3, -0.04, 0.22, 0.58]
    rings = []
    for i, z in enumerate(zs):
        r = 0.15 if i % 2 == 0 else 0.128  # 감개 줄(두툼 · 가늘 번갈아)
        rings.append([(x, y, z) for x, y in A.circle2d(r, 6, start=math.pi / 6)])
    return A.loft(rings)


def gs_pommel(grade):
    z = GS["pommelZ"]
    prof = [(0.0, -0.34), (0.12, -0.3), (0.21, -0.19), (0.215, -0.06), (0.15, 0.04), (0.11, 0.08)]
    g = A.xform(A.lathe(prof, 6, axis="Z"), t=(0, 0, z))
    g = A.xform(g, t=(0, 0, 0))
    if at_least(grade, "relic"):
        spikes = []
        for k in range(4):
            a = math.pi / 4 + k * math.pi / 2
            d = (math.cos(a), math.sin(a) * 0.8, -0.35)
            L = math.sqrt(sum(c * c for c in d))
            d = tuple(c / L for c in d)
            base = (d[0] * 0.14, d[1] * 0.14, z - 0.16 + d[2] * 0.1)
            tip = (base[0] + d[0] * 0.28, base[1] + d[1] * 0.28, base[2] + d[2] * 0.28)
            spikes.append(A.tube([base, tip], lambda u: 0.07 * (1 - u) + 0.01, sides=4, tip_end=True))
        g = A.merge(g, *spikes)
    return g


def gs_gem():
    prof = [(0.0, -0.21), (0.17, -0.1), (0.23, 0.0), (0.17, 0.1), (0.0, 0.21)]
    return A.xform(A.lathe(prof, 5, axis="Y"), t=(0, 0, GS["guardZ"]))


def gs_runes():
    # 날 양면 돋은 룬 3개(각 2획) - 획 = 모따기 막대
    out = []
    glyphs = [(2.3, [((0, -0.14), (0, 0.14)), ((-0.1, 0.02), (0.1, 0.12))]),
              (2.85, [((-0.1, -0.12), (0.1, 0.12)), ((0.1, -0.12), (-0.1, 0.12))]),
              (3.35, [((0, -0.12), (0, 0.12)), ((-0.09, -0.12), (0.09, -0.12))])]
    for zc, strokes in glyphs:
        for side in (1, -1):
            t = 0.105 if zc < 2.6 else 0.095
            for (x0, z0), (x1, z1) in strokes:
                out.append(A.tube([(x0, side * t, zc + z0), (x1, side * t, zc + z1)], 0.035, sides=3, flat=0.6))
    return A.merge(*out)


def gs_wing(sign):
    feathers = []
    root = (sign * 1.18, 0, GS["guardZ"] + 0.18)
    for k, (length, ang) in enumerate(((1.15, 14), (0.9, 34), (0.66, 56))):
        a = math.radians(ang)
        d = (sign * math.sin(a), 0, math.cos(a))
        pts = [(root[0] + d[0] * length * u - sign * 0.05 * k, 0, root[2] + d[2] * length * u - 0.08 * k) for u in (0, 0.5, 1.0)]
        feathers.append(A.tube(pts, lambda u: 0.13 * math.sin(math.pi * (0.2 + 0.8 * u)) + 0.04, sides=4, flat=0.3, tip_end=True))
    return A.merge(*feathers)


def gs_crystals():
    out = []
    for k, (a, z, h) in enumerate(((20, 1.5, 0.62), (150, 2.15, 0.5), (265, 1.25, 0.42))):
        r = math.radians(a)
        out.append(A.crystal(h, 0.13, sides=4, tip_h=0.2, base_h=0.12, center=(math.cos(r) * 0.98, math.sin(r) * 0.45, z), m=A.rot(rx=90 + 12 * math.sin(k), ry=-a * 0.15)))
    return A.merge(*out)


def gs_shards():
    out = []
    for k, (a, z, s) in enumerate(((15, 1.55, 0.26), (140, 2.3, 0.2), (250, 1.2, 0.22), (320, 3.1, 0.16), (80, 3.6, 0.14))):
        r = math.radians(a)
        out.append(A.shard(s, seed=k + 1, center=(math.cos(r) * 1.0, math.sin(r) * 0.4, z), m=A.rot(rx=70 + 20 * k, rz=a)))
    return A.merge(*out)


def gs_halo():
    n = 10
    path = [(0.82 * math.cos(2 * math.pi * i / n), 0.3 * math.sin(2 * math.pi * i / n), 1.7 + 0.18 * math.cos(2 * math.pi * i / n)) for i in range(n + 1)]
    return A.tube(path, 0.05, sides=3, cap0=False)


def gs_cracks():
    out = []
    for zs, xs in (((0.95, 1.35, 1.7, 2.2, 2.6), (0.12, -0.08, 0.14, -0.05, 0.1)), ((2.6, 3.0, 3.35, 3.8), (-0.18, 0.02, -0.12, 0.04))):
        # 균열 = 날을 관통하는 납작 띠 1줄(양면에 동시에 보인다 - Y 반경 > 날 두께)
        pts = [(x, 0, z) for z, x in zip(zs, xs)]
        out.append(A.tube(pts, 0.045, sides=4, flat=3.2, twist=math.pi / 4))
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
    parts += [("Guard", gs_guard(grade), P["guard"], False, 0.0), ("Grip", gs_grip(), P["grip"], False, 0.0), ("Pommel", gs_pommel(grade), P["pommel"], False, 0.0)]
    if at_least(grade, "legendary"):
        parts.append(("Gem", gs_gem(), P["gem"], True, 0.0))
    if grade == "relic":  # 고대부터는 날개가 실루엣 자리를 넘겨받는다(삼각형 예산 - 룬은 윤곽 밖 변화가 없다)
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


# ────────────────────────── 공통 짓기 ──────────────────────────
BUILDERS = {"greatsword": greatsword_parts}
ATTACH = {"greatsword": dict(Grip=(0, 0, 0), Tip=(0, 0, GS["tipZ"]), Support=(0, 0, GS["supportZ"]))}


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


DISPLAY_ROT = {"greatsword": (-90, 0, 0)}  # 칼끝(Roblox +Z = Blender −Y) → 위 · 날 면이 +Y(카메라 정면)


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
            A.write_json(path, {"version": "A2-N1", "rigId": weapon, "pivot": "Grip", "attachments": ATTACH[weapon], "triBudget": TRI_BUDGET, "looks": looks})
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
