# -*- coding: utf-8 -*-
# A2-N1 몬스터(Blender bpy): 리그 JSON(rigs/<종>.rig.json) → 파트마다 메시 1개(이름 = 리그 파트 · 원점 = 관절 · 색 = 리그 색).
#   설계 = docs/art/asset-design-n1.md §3 · §6. 형태는 종별 함수(아래 SPECIES) - 공용 도형은 artlib.
#   이전 버전(비교) = 같은 리그 JSON의 상자 · 공(도형 리그)을 그대로 짓는다(--old).
#   출력: roblox/art/monsters/<종>.fbx · .blend · .meta.json / 렌더 --render <폴더> → <종>_{game,form}_{front,side,34}.png · _sil_front.png
# 실행: bash bl.sh make_monsters.py --species rock_boar[,crystal_beetle ...] [--render 폴더] [--old] [--no-export]
import bpy
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import artlib as A  # noqa: E402
from mathutils import Matrix  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "art", "monsters"))
BUDGET = {"monster": 1500, "boss": 6000}


def load_rig(sid):
    with open(os.path.join(HERE, "rigs", "%s.rig.json" % sid), encoding="utf-8") as f:
        rig = json.load(f)
    return rig, {p["name"]: p for p in rig["parts"]}


def rig_m(p):
    r = p["rotation"]
    return Matrix(((r[0], r[1], r[2]), (r[3], r[4], r[5]), (r[6], r[7], r[8])))


def rgb(p):
    return tuple(int(c) for c in p["color"])


def V(*a):
    return tuple(a)


def add(a, b, k=1.0):
    return tuple(a[i] + b[i] * k for i in range(3))


# ────────────────────────── 이전 버전(도형 리그 그대로) ──────────────────────────
def old_geo(p):
    sx, sy, sz = p["size"]
    if p["shape"] == "ball":
        g = A.ellipsoid((sx / 2, sy / 2, sz / 2), n=12, rings=8)
    else:
        g = A.box(sx, sy, sz)
    return A.xform(g, m=rig_m(p), t=tuple(p["center"]))


# ────────────────────────── 공용 형태 ──────────────────────────
def chisel_loft(stations, sides_b=0.3, twist=0.0):
    """깎은 바위 몸통: stations = [(z, w, h, cy), ...] 앞(−Z) → 뒤. 모따기 8각 단면 · 조금씩 비틀어 면이 어긋나게(깎은 느낌)"""
    rings = []
    for k, (z, w, h, cy) in enumerate(stations):
        sec = A.chamfer_rect(w, h, min(w, h) * sides_b)
        a = twist * math.sin(k * 1.7)
        ca, sa = math.cos(a), math.sin(a)
        rings.append([(x * ca - y * sa, y * ca + x * sa + cy, z) for x, y in sec])
    return A.loft(rings)


def dome(r, h, n=10, rings=4, center=(0, 0, 0), skirt=0.0, wave=0.0, waves=5, flat_bottom=True):
    """종 모양 돔(위 둥글고 아래 퍼짐). skirt = 아래로 내려오는 치마 길이 · wave = 치마 끝 물결 진폭(반지름 비)"""
    prof = []
    for k in range(rings + 1):
        a = math.pi / 2 * k / rings
        prof.append((r * math.cos(a), h * math.sin(a)))
    prof = list(reversed(prof))  # 위(0, h) → 아래(r, 0)
    verts, faces = [], []
    ring_pts = []
    for i, (rr, y) in enumerate(prof):
        if rr < 1e-6:
            continue
        ring_pts.append([(rr * math.cos(2 * math.pi * j / n), y, rr * math.sin(2 * math.pi * j / n)) for j in range(n)])
    if skirt > 0:
        last = []
        for j in range(n):
            a = 2 * math.pi * j / n
            k = 1 + wave * math.cos(waves * a)
            last.append((r * 1.08 * k * math.cos(a), -skirt * (1 + 0.6 * wave * math.cos(waves * a)), r * 1.08 * k * math.sin(a)))
        ring_pts.append(last)
    rings_all = list(reversed(ring_pts))  # 아래 → 위(loft 순서)
    g = A.loft(rings_all, cap0=flat_bottom, tip1=(0, h, 0))
    return A.xform(g, t=center)


def cone_leg(top, bottom_y, r_top, r_mid, r_foot, n=6):
    """짧은 다리(위 굵고 가운데 조임 · 발 넓게)"""
    x, y, z = top
    h = y - bottom_y
    prof = [(0.0, -h), (r_foot, -h), (r_foot * 0.95, -h * 0.82), (r_mid, -h * 0.55), (r_top, 0.0), (r_top * 0.6, 0.1)]
    return A.xform(A.lathe(prof, n), t=(x, y, z))


def eye_pair(cx, cy, cz, r=(0.14, 0.17, 0.08), dx=0.3, n=8):
    return A.merge(A.ellipsoid(r, n=n, rings=4, center=(cx - dx, cy, cz)), A.ellipsoid(r, n=n, rings=4, center=(cx + dx, cy, cz)))


# ────────────────────────── 종 ──────────────────────────
def rock_boar(P):
    b = P["Body"]["center"]
    body = chisel_loft([(-1.55, 1.55, 1.35, 0.0), (-1.0, 1.95, 1.8, 0.1), (-0.1, 1.95, 1.7, 0.05), (0.8, 1.7, 1.38, -0.08), (1.45, 1.2, 0.95, -0.22), (1.62, 0.6, 0.5, -0.25)], 0.3, twist=0.06)
    body = A.xform(body, t=(0, b[1], 0))
    head = chisel_loft([(-1.35, 1.4, 1.2, 0.0), (-1.9, 1.3, 1.1, -0.02), (-2.3, 1.05, 0.85, -0.12), (-2.55, 0.8, 0.6, -0.2)], 0.32)
    head = A.xform(head, t=(0, -0.05, 0))
    eyes = eye_pair(0, 0.2, -2.24, r=(0.13, 0.16, 0.1), dx=0.34)
    tusks = {}
    for name, sgn, k in (("Tusk_L", -1, 1.3), ("Tusk_R", 1, 1.0)):  # 왼쪽 엄니가 더 크다(비대칭)
        x = sgn * 0.4
        path = A.bezier((x, -0.32, -2.3), (x * 1.9, -0.75, -2.85 - 0.15 * k), (x * (2.9 + 0.4 * k), -0.2 * k, -3.1 - 0.15 * k), (x * (2.7 + 0.5 * k), 0.6 + 0.35 * k, -2.75), n=7)
        tusks[name] = A.tube(path, lambda u, k=k: (0.2 * k) * (1 - u) ** 0.8 + 0.03, sides=6, tip_end=True)  # 머리 폭 밖으로 휘어 위로 - 정면 실루엣의 "튀어나온 것"
    moss = A.merge(*[A.ellipsoid((0.55 * s, 0.28 * s, 0.5 * s), n=7, rings=4, center=(0.08 * math.sin(i * 2.1), 0.72 + 0.12 * s, z), squash_bottom=0.4)
                     for i, (z, s) in enumerate(((-0.95, 1.15), (-0.3, 1.2), (0.35, 1.0), (0.9, 0.78)))])
    legs = {n_: cone_leg(tuple(P[n_]["joint"]), -1.58, 0.3, 0.22, 0.27, 6) for n_ in ("Leg_FL", "Leg_FR", "Leg_BL", "Leg_BR")}
    return dict(Body=body, Head=head, Eyes=eyes, Moss=moss, **tusks, **legs)


def crystal_beetle(P):
    shell = A.ellipsoid((1.12, 0.78, 1.32), n=16, rings=9, center=(0, -0.72, 0.08), squash_bottom=0.35)
    ridge = A.tube([(0, 0.02, -1.0), (0, 0.1, 0.0), (0, -0.05, 1.1)], 0.07, sides=4, cap0=True)
    body = A.merge(shell, ridge)
    head = chisel_loft([(-1.3, 0.95, 0.66, 0.0), (-1.75, 0.85, 0.58, -0.04), (-2.05, 0.6, 0.4, -0.08)], 0.35)
    head = A.xform(head, t=(0, -0.72, 0))
    jaws = [A.tube(A.bezier((s * 0.22, -0.82, -2.0), (s * 0.45, -0.85, -2.35), (s * 0.2, -0.85, -2.65), (-s * 0.02, -0.82, -2.6), n=5), lambda u: 0.13 * (1 - u) + 0.03, sides=4, tip_end=True) for s in (-1, 1)]
    head = A.merge(head, *jaws)
    eyes = eye_pair(0, -0.58, -2.0, r=(0.12, 0.12, 0.09), dx=0.3, n=10)
    legs = {}
    for name, s in (("Leg_L", -1), ("Leg_R", 1)):
        g = []
        for dz, spread in ((-0.7, -0.35), (0.0, 0.0), (0.7, 0.35)):
            g.append(A.tube(A.bezier((s * 0.8, -0.95, dz), (s * 1.25, -0.7, dz + spread * 0.3), (s * 1.45, -1.0, dz + spread * 0.8), (s * 1.45, -1.55, dz + spread), n=5), lambda u: 0.16 * (1 - u) + 0.08, sides=6))
        legs[name] = A.merge(*g)
    shells = {}
    for name, h, r, lean in (("Shell1", 1.6, 0.36, -8), ("Shell2", 2.35, 0.46, -22), ("Shell3", 1.3, 0.32, -5)):  # 가운데가 가장 크고 앞(−Z)으로 기욺
        p = P[name]
        m = rig_m(p) @ A.rot(rx=lean)
        base = tuple(p["joint"])
        shells[name] = A.crystal(h, r, sides=7, tip_h=0.42 * h / 1.4, base_h=0.14, center=(base[0], base[1] - 0.1, base[2]), m=m)
    return dict(Body=body, Head=head, Eyes=eyes, **legs, **shells)


def wing_membrane(sign, span=2.3):
    """뼈 세 갈래로 파인 막 날개(XY 평면 · 두께 0.1) + 뼈 튜브. 관절 = 어깨(원점) 기준 로컬"""
    fingers = [(span, 0.55), (span * 0.9, -0.2), (span * 0.62, -0.75)]  # 손가락 끝(x, y)
    outline = [(0.0, 0.25)]
    prev = None
    for k, (fx, fy) in enumerate(fingers):
        if prev is not None:  # 두 손가락 사이 막이 안쪽으로 파임
            mx, my = (prev[0] + fx) / 2, (prev[1] + fy) / 2
            outline.append((mx * 0.78, my * 0.78 + 0.02))
        outline.append((fx, fy))
        prev = (fx, fy)
    outline.append((0.15, -0.55))
    t = 0.05
    top = [(x, y, t) for x, y in outline]
    bot = [(x, y, -t) for x, y in outline]
    n = len(outline)
    verts = top + bot
    faces = [tuple(range(n)), tuple(reversed(range(n, 2 * n)))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, n + i, n + j, j))
    mem = (verts, faces)
    bones = [A.tube([(0, 0.1, 0), (fx * 0.45, fy * 0.5 + 0.2, 0.04), (fx, fy, 0.02)], lambda u: 0.08 * (1 - u) + 0.025, sides=4, tip_end=True) for fx, fy in fingers]
    arm = A.tube([(0, 0, 0), (span * 0.35, 0.45, 0.02), (span * 0.62, 0.55, 0.02)], 0.09, sides=4)
    g = A.merge(mem, arm, *bones)
    if sign < 0:
        g = A.mirror_x(g)
    return g


def amethyst_bat(P):
    body = A.merge(A.ellipsoid((0.8, 0.72, 0.72), n=16, rings=10, center=(0, 0.8, 0)),
                   A.ellipsoid((0.5, 0.42, 0.3), n=10, rings=6, center=(0, 0.72, -0.5)))  # 가슴 털 뭉치
    head = A.merge(A.ellipsoid((0.62, 0.42, 0.5), n=14, rings=8, center=(0, 1.52, -0.08)),
                   A.ellipsoid((0.26, 0.18, 0.2), n=6, rings=3, center=(0, 1.42, -0.52)))  # 주둥이
    ears = {}
    for name, s in (("Ear_L", -1), ("Ear_R", 1)):
        j = P[name]["joint"]
        tipbend = (-0.25 if s < 0 else 0.0)  # 왼쪽 귀 끝만 꺾임(비대칭)
        path = [(j[0], j[1] - 0.2, j[2]), (j[0] + s * 0.18, j[1] + 0.4, j[2]), (j[0] + s * 0.32 + tipbend * 0.4, j[1] + 0.85, j[2] + 0.02), (j[0] + s * 0.3 + tipbend * 1.6, j[1] + 1.02 + tipbend * 0.5, j[2] + 0.05)]
        ears[name] = A.tube(A.bezier(path[0], path[1], path[2], path[3], n=6), lambda u: 0.24 * (1 - u) + 0.02, sides=6, flat=0.45, tip_end=True)
    eyes = eye_pair(0, 1.08, -0.62, r=(0.17, 0.2, 0.1), dx=0.3, n=12)
    wings = {}
    for name, s in (("Wing_L", -1), ("Wing_R", 1)):
        j = P[name]["joint"]
        g = A.xform(wing_membrane(s), m=A.rot(rz=s * 14), t=tuple(j))
        wings[name] = g
    return dict(Body=body, Head=head, Eyes=eyes, **ears, **wings)


def hermit_knight(P):
    body = A.ellipsoid((0.98, 0.48, 0.78), n=10, rings=5, center=(0, -0.72, -0.05), squash_bottom=0.6)
    head = A.merge(A.ellipsoid((0.45, 0.3, 0.3), n=8, rings=4, center=(0, -0.1, -0.72)))
    eyes = A.merge(*[A.merge(A.tube([(s * 0.2, 0.0, -0.85), (s * 0.28, 0.3, -0.9)], 0.06, sides=4), A.ellipsoid((0.14, 0.16, 0.14), n=6, rings=4, center=(s * 0.29, 0.38, -0.92))) for s in (-1, 1)])
    # 나선 소라: 층진 원뿔(회전체) + 층마다 뿔 돌기 · 뒤(+Z) 위로 기울임
    prof = [(0.0, -0.95), (0.95, -0.75), (1.02, -0.35), (0.72, -0.22), (0.82, 0.08), (0.52, 0.2), (0.58, 0.5), (0.3, 0.62), (0.32, 0.86), (0.0, 1.3)]
    shell = A.lathe(prof, 9)
    spikes = []
    for k, (r, y, cnt) in enumerate(((1.0, -0.4, 4), (0.8, 0.05, 3), (0.57, 0.46, 2))):
        for i in range(cnt):
            a = 2 * math.pi * (i / cnt) + k * 0.7
            d = (math.cos(a), 0.35, math.sin(a))
            base = (r * 0.95 * math.cos(a), y, r * 0.95 * math.sin(a))
            spikes.append(A.tube([base, add(base, d, 0.32)], lambda u: 0.1 * (1 - u) + 0.01, sides=4, tip_end=True))
    shell = A.xform(A.merge(shell, *spikes), m=A.rot(rx=32, rz=-10), t=(0, 0.35, 0.55))
    claws = {}
    for name, s, k in (("Claw_L", -1, 0.5), ("Claw_R", 1, 1.9)):  # 오른쪽만 거대한 집게(비대칭 과장 - 몸 폭 1.0배 · 왼쪽 0.45배)
        j = P[name]["joint"]
        palm_c = (j[0] + s * 0.5 * k, j[1] + (0.02 if k < 1 else 0.3 * k), j[2] - 0.35 * k)  # 큰 집게는 몸 위선보다 들어 올림
        arm = A.tube([(j[0] - s * 0.2, j[1], j[2] + 0.2), (j[0] + s * 0.25 * k, j[1] + (0.0 if k < 1 else 0.15 * k), j[2] - 0.15 * k), (j[0] + s * 0.45 * k, palm_c[1], palm_c[2])], 0.16 * max(k, 0.8), sides=5)
        palm = A.ellipsoid((0.38 * k, 0.3 * k, 0.4 * k), n=8, rings=4, center=palm_c)
        lower = A.tube(A.bezier(add(palm_c, (0, -0.1 * k, -0.25 * k)), add(palm_c, (s * 0.1 * k, -0.15 * k, -0.6 * k)), add(palm_c, (0, -0.05 * k, -0.85 * k)), add(palm_c, (-s * 0.1 * k, 0.05 * k, -0.95 * k)), n=4), lambda u: 0.2 * k * (1 - u) + 0.03, sides=5, tip_end=True)
        upper = A.tube(A.bezier(add(palm_c, (0, 0.15 * k, -0.2 * k)), add(palm_c, (s * 0.05 * k, 0.45 * k, -0.45 * k)), add(palm_c, (0, 0.4 * k, -0.75 * k)), add(palm_c, (-s * 0.05 * k, 0.15 * k, -0.85 * k)), n=4), lambda u: 0.14 * k * (1 - u) + 0.03, sides=5, tip_end=True)
        claws[name] = A.merge(arm, palm, lower, upper)
    legs = {}
    for name, s in (("Leg_L", -1), ("Leg_R", 1)):
        legs[name] = A.merge(*[A.tube([(s * 0.8, -0.8, dz), (s * 1.25, -0.72, dz * 1.2), (s * 1.35, -1.55, dz * 1.35)], lambda u: 0.16 * (1 - u) + 0.13, sides=4) for dz in (-0.45, 0.05, 0.5)])
    return dict(Body=body, Head=head, Eyes=eyes, Shell=shell, **claws, **legs)


def bubble_jelly(P):
    body = dome(1.12, 1.3, n=20, rings=7, center=(0, 0.45, 0), skirt=0.32, wave=0.1, waves=6)
    head = A.ellipsoid((0.62, 0.4, 0.6), n=14, rings=6, center=(0.12, 1.72, 0.05), squash_bottom=0.5)  # 꼭대기 반짝 혹(살짝 한쪽)
    eyes = eye_pair(0, 1.02, -1.04, r=(0.24, 0.3, 0.1), dx=0.42, n=12)  # 눈 = 몸 폭의 22%
    tents = {}
    for k, name in enumerate(("Tentacle1", "Tentacle2", "Tentacle3", "Tentacle4")):
        j = P[name]["joint"]
        sx, sz = (1 if j[0] > 0 else -1), (1 if j[2] > 0 else -1)
        curl = 1 if k % 2 == 0 else -1
        path = [(j[0], j[1] + 0.25, j[2]), (j[0] + sx * 0.12, j[1] - 0.5, j[2] + sz * 0.1), (j[0] - sx * 0.05, j[1] - 1.1, j[2] + sz * 0.22),
                (j[0] + sx * 0.25 * curl, j[1] - 1.6, j[2] + sz * 0.2), (j[0] + sx * 0.55 * curl, j[1] - 1.45, j[2] + sz * 0.05), (j[0] + sx * 0.5 * curl, j[1] - 1.2, j[2])]
        tents[name] = A.tube(path, lambda u: 0.26 * (1 - u) + 0.06, sides=8, tip_end=True)
    return dict(Body=body, Head=head, Eyes=eyes, **tents)


def moss_slime(P):
    # 물방울: 바닥 퍼짐 · 꼭대기 한쪽으로 휜 뾰족(비대칭)
    prof = [(0.0, -1.5), (1.05, -1.5), (1.3, -1.4), (1.4, -1.15), (1.4, -0.85), (1.34, -0.5), (1.2, -0.15), (1.0, 0.18), (0.76, 0.46), (0.5, 0.68), (0.25, 0.86), (0.0, 1.02)]
    body = A.xform(A.lathe(prof, 20), t=(0, 0.0, 0))
    body = ([(x + 0.22 * max(0.0, y - 0.1) ** 2, y, z) for x, y, z in body[0]], body[1])
    cap = dome(1.0, 0.38, n=20, rings=5, center=(0.06, 0.28, 0.0), skirt=0.22, wave=0.14, waves=7)
    leaves = [A.tube([(0.1, 0.6, 0), (0.3, 1.05, -0.05), (0.75, 1.3, -0.1)], lambda u: 0.26 * math.sin(math.pi * min(1.0, 0.1 + u)) + 0.02, sides=4, flat=0.3, tip_end=True),
              A.tube([(-0.05, 0.6, 0), (-0.25, 0.95, 0.05), (-0.5, 1.08, 0.08)], lambda u: 0.17 * math.sin(math.pi * min(1.0, 0.1 + u)) + 0.02, sides=4, flat=0.3, tip_end=True)]
    head = A.merge(cap, *leaves)  # 새싹 잎 두 장(오른쪽이 크다)
    eye = lambda x: A.ellipsoid((0.18, 0.26, 0.1), n=12, rings=6, center=(x, -0.15, -1.24))
    return dict(Body=body, Head=head, Eye_L=eye(-0.45), Eye_R=eye(0.45))


# 작은 Bevel(빛 맺힘)은 깎은 덩어리에만 - 저폴리 공 · 튜브에 걸면 삼각형만 2 ~ 3배로 늘고 차이가 안 보인다
BEVEL = {"rock_boar": {"Body", "Head"}, "crystal_beetle": {"Head"}, "hermit_knight": set(), "amethyst_bat": set(), "bubble_jelly": set(), "moss_slime": set()}

SPECIES = {"rock_boar": rock_boar, "crystal_beetle": crystal_beetle, "amethyst_bat": amethyst_bat, "hermit_knight": hermit_knight,
           "bubble_jelly": bubble_jelly, "moss_slime": moss_slime}


# ────────────────────────── 짓기 · 내보내기 ──────────────────────────
def build(sid, old=False):
    rig, P = load_rig(sid)
    col = A.new_collection(("old_" if old else "") + sid)
    geos = {n: old_geo(p) for n, p in P.items()} if old else SPECIES[sid](P)
    missing = set(P) - set(geos)
    extra = set(geos) - set(P)
    assert not missing and not extra, "리그 파트 불일치 %s / %s" % (missing, extra)
    bevel_parts = BEVEL.get(sid, set())
    objs = []
    for name, p in P.items():
        neon = p.get("material") == "Neon"
        o = A.make_obj(name, geos[name], rgb(p), col, neon=neon, origin=tuple(p["joint"]), bevel=0.03 if (not old and name in bevel_parts) else 0.0, bevel_angle=40.0,
                       mat_name="%s%s_%s" % ("old_" if old else "", sid, name))
        objs.append(o)
    return rig, col, objs


def parse():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opt = {"species": [], "render": None, "export": True, "old": False}
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--species":
            opt["species"] = argv[i + 1].split(","); i += 1
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
    for sid in opt["species"]:
        A.reset()
        rig, col, objs = build(sid)
        total = sum(A.tri_count(o) for o in objs)
        budget = int(rig.get("triBudget", 1500))
        print("[make_monsters] %s 파트 %d · 삼각형 %d / %d = %.0f%% · %s" % (sid, len(objs), total, budget, 100 * total / budget, {o.name: A.tri_count(o) for o in objs}))
        if opt["export"]:
            A.export_fbx(os.path.join(OUT, "%s.fbx" % sid), objs)
            A.write_json(os.path.join(OUT, "%s.meta.json" % sid), dict(A.meta_of(objs, budget), version="A2-N1", rigId=sid, kind=rig.get("kind", "monster")))
            bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "%s.blend" % sid))
        if opt["render"]:
            A.render_views(objs, os.path.join(opt["render"], sid), hull=0.035, res=(800, 800))
            if opt["old"]:
                for o in objs:
                    o.hide_render = True
                _, _, olds = build(sid, old=True)
                A.render_views(olds, os.path.join(opt["render"], "old_" + sid), views=("front", "34"), kinds=("game",), hull=0.035, res=(800, 800))
    print("[make_monsters] 끝")


if __name__ == "__main__":
    main()
