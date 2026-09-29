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


def wing_membrane(sign, span=2.3, bone=0.08):
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
    bones = [A.tube([(0, 0.1, 0), (fx * 0.45, fy * 0.5 + 0.2, 0.04), (fx, fy, 0.02)], lambda u: bone * (1 - u) + bone * 0.3, sides=4, tip_end=True) for fx, fy in fingers]
    arm = A.tube([(0, 0, 0), (span * 0.35, 0.45, 0.02), (span * 0.62, 0.55, 0.02)], bone * 1.12, sides=4)
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


def local(p, geo):
    """부위 로컬(가운데 원점 · 리그 회전) → 월드"""
    return A.xform(geo, m=rig_m(p), t=tuple(p["center"]))


def ribbed_column(r, h, ribs=8, depth=0.18, rings=5, top_round=0.35, n_top=3):
    """선인장 기둥: 골(ribs) 파인 별 단면 로프트 + 둥근 윗면(아래 = y −h/2)"""
    sec = [(r * (1 - depth * (i % 2)) * math.cos(math.pi * i / ribs), r * (1 - depth * (i % 2)) * math.sin(math.pi * i / ribs)) for i in range(2 * ribs)]
    rs = []
    for k in range(rings):
        y = -h / 2 + (h - r * top_round) * k / (rings - 1)
        rs.append([(x, y, z) for x, z in sec])
    for k in range(1, n_top + 1):
        a = math.pi / 2 * k / (n_top + 1)
        rs.append([(x * math.cos(a), h / 2 - r * top_round + r * top_round * math.sin(a) / math.sin(math.pi / 2 * n_top / (n_top + 1)), z * math.cos(a)) for x, z in sec])
    return A.loft(rs, tip1=(0, h / 2, 0))


def zigzag(points, width, depth):
    """번개 모양 납작 띠(XY 윤곽 · 두께 depth)"""
    outline = []
    n = len(points)
    for i, (x, y) in enumerate(points):
        outline.append((x + width * (1 - i / n), y))
    for i, (x, y) in reversed(list(enumerate(points))):
        outline.append((x - width * (1 - i / n) * 0.6, y))
    v = [(x, y, depth / 2) for x, y in outline] + [(x, y, -depth / 2) for x, y in outline]
    m = len(outline)
    f = [tuple(range(m)), tuple(reversed(range(m, 2 * m)))] + [(i, m + i, m + (i + 1) % m, (i + 1) % m) for i in range(m)]
    return v, f


def sand_scorpion(P):
    b = P["Body"]["center"]
    segs = []
    for k in range(4):  # 등딱지 마디 4(뒤로 갈수록 좁게)
        z0, z1 = -1.1 + 0.55 * k, -1.1 + 0.55 * (k + 1)
        w = 1.75 - 0.15 * k
        segs.append(A.loft([[(x, y + b[1], z) for x, y in A.chamfer_rect(w * s, 0.78 * s, 0.25)] for z, s in ((z0, 0.9), (z0 + 0.12, 1.0), (z1 - 0.06, 0.96))]))
    body = A.merge(*segs)
    h = P["Head"]["center"]
    head = A.loft([[(x, y + h[1], z) for x, y in A.chamfer_rect(w_, 0.5, 0.18)] for z, w_ in ((-1.2, 1.05), (-1.55, 0.95), (-1.85, 0.6))])
    fangs = [A.tube([(s * 0.18, h[1] - 0.15, -1.8), (s * 0.28, h[1] - 0.25, -2.05), (s * 0.1, h[1] - 0.25, -2.15)], lambda u: 0.07 * (1 - u) + 0.02, sides=4, tip_end=True) for s in (-1, 1)]
    head = A.merge(head, *fangs)
    eyes = eye_pair(0, -0.66, -1.8, r=(0.1, 0.1, 0.07), dx=0.2, n=8)
    claws = {}
    for name, s in (("Claw_L", -1), ("Claw_R", 1)):
        j = P[name]["joint"]
        arm = A.tube([(j[0] - s * 0.2, j[1], j[2] + 0.4), (j[0] + s * 0.15, j[1] + 0.05, j[2]), (j[0] + s * 0.1, j[1] + 0.08, j[2] - 0.3)], 0.14, sides=5)
        pc = (j[0] + s * 0.1, j[1] + 0.08, j[2] - 0.5)
        palm = A.ellipsoid((0.3, 0.22, 0.32), n=8, rings=5, center=pc)
        up = A.tube(A.bezier(add(pc, (0, 0.08, -0.1)), add(pc, (s * 0.2, 0.12, -0.35)), add(pc, (s * 0.05, 0.1, -0.6)), add(pc, (-s * 0.1, 0.05, -0.62)), n=4), lambda u: 0.13 * (1 - u) + 0.02, sides=5, tip_end=True)
        lo = A.tube(A.bezier(add(pc, (0, -0.06, -0.12)), add(pc, (-s * 0.18, -0.08, -0.3)), add(pc, (-s * 0.1, -0.05, -0.5)), add(pc, (0.02 * s, 0.0, -0.55)), n=4), lambda u: 0.1 * (1 - u) + 0.02, sides=5, tip_end=True)
        claws[name] = A.merge(arm, palm, up, lo)
    legs = {}
    for name, s in (("Leg_L", -1), ("Leg_R", 1)):
        legs[name] = A.merge(*[A.tube(A.bezier((s * 0.7, -1.0, dz), (s * 1.15, -0.75, dz + sp * 0.3), (s * 1.35, -1.1, dz + sp * 0.8), (s * 1.4, -1.55, dz + sp), n=4), lambda u: 0.12 * (1 - u) + 0.06, sides=4)
                               for dz, sp in ((-0.55, -0.3), (0.05, 0.0), (0.6, 0.3))])
    tails = {}
    for name, w0, w1 in (("Tail1", 0.55, 0.48), ("Tail2", 0.5, 0.42)):
        p = P[name]
        sy = p["size"][1]
        seg = A.merge(A.lathe([(0.0, -sy / 2), (w0 * 0.55, -sy / 2 + 0.04), (w0 * 0.62, -sy * 0.2), (w1 * 0.6, sy * 0.3), (w1 * 0.5, sy / 2), (0.0, sy / 2)], 7),
                      A.ellipsoid((w0 * 0.66, 0.12, w0 * 0.66), n=8, rings=3, center=(0, -sy * 0.3, 0)))
        tails[name] = local(p, seg)
    p = P["Tail3"]
    sy = p["size"][1]
    bulb = A.ellipsoid((0.3, 0.36, 0.3), n=10, rings=6, center=(0, -0.08, 0))
    sting = A.tube(A.bezier((0, 0.15, 0), (0, 0.5, -0.05), (0, 0.72, -0.3), (0, 0.62, -0.55), n=5), lambda u: 0.14 * (1 - u) + 0.015, sides=6, tip_end=True)
    tails["Tail3"] = local(p, A.merge(bulb, sting))
    return dict(Body=body, Head=head, Eyes=eyes, **claws, **legs, **tails)


def cactus_imp(P):
    b = P["Body"]
    body = local(b, ribbed_column(0.62, 2.4, ribs=7, depth=0.16, rings=5, top_round=0.5))
    spines = [A.tube([(0.62 * math.cos(a), yy, 0.62 * math.sin(a)), (0.85 * math.cos(a), yy + 0.12, 0.85 * math.sin(a))], lambda u: 0.05 * (1 - u) + 0.005, sides=3, tip_end=True)
              for a, yy in ((0.4, 0.2), (2.2, -0.5), (3.8, 0.4), (5.3, -0.2), (1.3, -1.0))]
    body = A.merge(body, *[A.xform(sp, t=tuple(b["center"])) for sp in spines])
    h = P["Head"]
    head = local(h, A.xform(ribbed_column(0.54, 0.7, ribs=7, depth=0.14, rings=2, top_round=0.9, n_top=3), t=(0, 0.0, 0)))
    f = P["Flower"]
    petals = [A.xform(A.ellipsoid((0.2, 0.08, 0.34), n=6, rings=3), m=A.rot(rx=-25, ry=72 * k), t=(0.24 * math.sin(math.radians(72 * k)), 0.02, 0.24 * math.cos(math.radians(72 * k)))) for k in range(5)]
    center = A.ellipsoid((0.13, 0.12, 0.13), n=6, rings=3, center=(0, 0.1, 0))
    flower = local(f, A.xform(A.merge(center, *petals), m=A.rot(rz=12), s=(1.75, 1.5, 1.75)))
    eyes = eye_pair(0, P["Eyes"]["center"][1], -0.66, r=(0.13, 0.16, 0.07), dx=0.22, n=10)
    arms = {}
    for name, s, up in (("Arm_L", -1, 0.9), ("Arm_R", 1, 0.55)):  # 한쪽 팔이 더 높이 솟음(비대칭)
        j = P[name]["joint"]
        path = [(j[0] - s * 0.35, j[1] - 0.05, j[2]), (j[0] + s * 0.05, j[1] - 0.05, j[2]), (j[0] + s * 0.22, j[1] + 0.25, j[2]), (j[0] + s * 0.24, j[1] + up, j[2])]
        arms[name] = A.merge(A.tube(A.bezier(*path, n=6), 0.25, sides=7), A.ellipsoid((0.25, 0.22, 0.25), n=7, rings=4, center=(j[0] + s * 0.24, j[1] + up, j[2])))
    return dict(Body=body, Head=head, Flower=flower, Eyes=eyes, **arms)


def bolt_imp(P):
    body = local(P["Body"], A.lathe([(0.0, -0.6), (0.48, -0.55), (0.62, -0.25), (0.58, 0.15), (0.42, 0.5), (0.0, 0.62)], 12))
    h = P["Head"]
    head = A.merge(A.ellipsoid((0.64, 0.52, 0.55), n=14, rings=8, center=tuple(h["center"])),
                   A.ellipsoid((0.28, 0.2, 0.2), n=8, rings=4, center=add(tuple(h["center"]), (0, -0.28, -0.4))))
    ears = [A.tube([add(tuple(h["center"]), (s * 0.55, 0.05, 0)), add(tuple(h["center"]), (s * 0.95, 0.2, 0.05))], lambda u: 0.14 * (1 - u) + 0.01, sides=5, flat=0.5, tip_end=True) for s in (-1, 1)]
    head = A.merge(head, *ears)
    eyes = eye_pair(0, P["Eyes"]["center"][1], P["Eyes"]["center"][2] + 0.02, r=(0.15, 0.17, 0.08), dx=0.24, n=10)
    horns = {}
    for name, s in (("Horn_L", -1), ("Horn_R", 1)):
        j = P[name]["joint"]
        pts = [(0, -0.3), (s * 0.12, -0.05), (-s * 0.06, 0.08), (s * 0.12, 0.34)]
        horns[name] = A.xform(zigzag(pts, 0.16, 0.14), m=rig_m(P[name]), t=tuple(P[name]["center"]))
    limbs = {}
    for name in ("Arm_L", "Arm_R", "Leg_L", "Leg_R"):
        p = P[name]
        sx, sy, sz = p["size"]
        s = -1 if name.endswith("_L") else 1
        if name.startswith("Arm"):
            g = A.merge(A.tube([(0, sy / 2, 0), (s * 0.08, 0, -0.05), (0, -sy / 2 + 0.1, -0.1)], lambda u: 0.17 - 0.04 * u, sides=6), A.ellipsoid((0.2, 0.18, 0.2), n=7, rings=4, center=(0, -sy / 2 + 0.05, -0.1)))
        else:
            g = A.merge(A.tube([(0, sy / 2, 0), (0, 0, 0.05), (0, -sy / 2 + 0.12, 0)], lambda u: 0.22 - 0.05 * u, sides=6), A.ellipsoid((0.22, 0.14, 0.32), n=8, rings=4, center=(0, -sy / 2 + 0.08, -0.1)))
        limbs[name] = local(p, g)
    j = P["Tail"]["joint"]
    bolt = zigzag([(0.0, 0.0), (0.45, 0.35), (0.2, 0.55), (0.75, 0.95), (0.55, 1.1), (1.15, 1.5)], 0.26, 0.16)  # 60° 꺾임 3번 · 몸 옆 위로
    head_ = A.xform(A.lathe([(0.0, 0.0), (0.24, 0.0), (0.0, 0.42)], 4), s=(1, 1, 0.4), m=A.rot(rz=-35), t=(1.15, 1.5, 0))  # 화살촉
    tail = A.xform(A.merge(bolt, head_), t=(j[0] + 0.1, j[1] - 0.1, j[2] + 0.25))
    return dict(Body=body, Head=head, Eyes=eyes, **horns, **limbs, Tail=tail)


def puff(center, r, k=7, seed=1.0, squash=0.85):
    """구름 · 털 뭉치: 공 여러 개를 겹친 덩어리"""
    cx, cy, cz = center
    balls = [A.ellipsoid((r * 0.72, r * 0.72 * squash, r * 0.72), n=9, rings=5, center=(cx, cy, cz))]
    for i in range(k):
        a = seed + 2 * math.pi * i / k
        e = 0.35 * math.sin(i * 1.9 + seed)
        balls.append(A.ellipsoid((r * 0.45, r * 0.45 * squash, r * 0.45), n=7, rings=4, center=(cx + r * 0.55 * math.cos(a), cy + r * e * 0.6, cz + r * 0.55 * math.sin(a))))
    return A.merge(*balls)


def cloud_sheep(P):
    b = P["Body"]["center"]
    body = puff(tuple(b), 1.3, k=6, seed=0.3)
    body = ([(x, y, z * 1.12) for x, y, z in body[0]], body[1])
    wool = puff(tuple(P["Wool"]["center"]), 0.95, k=5, seed=1.1)
    h = P["Head"]["center"]
    head = A.merge(A.ellipsoid((0.46, 0.46, 0.55), n=12, rings=7, center=tuple(h)),
                   *[A.xform(A.ellipsoid((0.28, 0.1, 0.16), n=6, rings=3), m=A.rot(rz=s * 30), t=add(tuple(h), (s * 0.5, 0.12, 0.05))) for s in (-1, 1)],  # 귀
                   *[A.tube([add(tuple(h), (s * 0.3, 0.32, 0.05)), add(tuple(h), (s * 0.62, 0.42, 0.2)), add(tuple(h), (s * 0.66, 0.1, 0.12)), add(tuple(h), (s * 0.48, 0.12, -0.05))], lambda u: 0.12 * (1 - u) + 0.04, sides=5, tip_end=True) for s in (-1, 1)])  # 말린 뿔
    eyes = eye_pair(0, P["Eyes"]["center"][1], P["Eyes"]["center"][2] + 0.02, r=(0.11, 0.13, 0.07), dx=0.2, n=10)
    legs = {n_: cone_leg(tuple(P[n_]["joint"]), -1.55, 0.2, 0.16, 0.22, 7) for n_ in ("Leg_FL", "Leg_FR", "Leg_BL", "Leg_BR")}
    return dict(Body=body, Wool=wool, Head=head, Eyes=eyes, **legs)


def facet(stations, twist=0.35, sides=9):
    """깎인 얼음 덩어리: 단면 6각 · 단마다 비틀고 반지름 흔들어 면이 어긋나게. stations = [(y, rx, rz), ...]"""
    rings = []
    for k, (y, rx_, rz_) in enumerate(stations):
        a0 = twist * k
        rings.append([(rx_ * (1 + 0.08 * math.sin(i * 2.3 + k)) * math.cos(a0 + 2 * math.pi * i / sides), y, rz_ * (1 + 0.08 * math.cos(i * 1.7 + k)) * math.sin(a0 + 2 * math.pi * i / sides)) for i in range(sides)])
    return A.loft(rings)


def ice_golem(P):
    b = P["Body"]["center"]
    body = A.xform(facet([(-1.0, 1.0, 0.75), (-0.6, 1.18, 0.8), (-0.3, 1.3, 0.85), (0.1, 1.4, 0.88), (0.5, 1.45, 0.9), (0.8, 1.35, 0.84), (1.0, 1.2, 0.75)], 0.1, 7), t=tuple(b))  # 비틀림 작게 · 7면 = 큰 깎인 면(가는 줄무늬 = 털처럼 보였다)
    shards = [A.crystal(h_, 0.2, sides=5, tip_h=0.3, base_h=0.1, center=add(tuple(b), (x_, 1.0, z_)), m=A.rot(rz=-x_ * 25, rx=15)) for x_, z_, h_ in ((-0.9, 0.2, 0.9), (-0.55, 0.35, 0.65), (0.8, 0.3, 0.75))]
    body = A.merge(body, *shards)
    head = A.xform(facet([(-0.4, 0.45, 0.42), (-0.15, 0.52, 0.47), (0.05, 0.55, 0.5), (0.25, 0.48, 0.44), (0.4, 0.35, 0.36)], 0.15, 7), s=(1.3, 1.3, 1.3), t=tuple(P["Head"]["center"]))
    eyes = eye_pair(0, P["Eyes"]["center"][1], P["Eyes"]["center"][2] - 0.14, r=(0.12, 0.12, 0.08), dx=0.24, n=8)
    parts = {}
    for name, s in (("Arm_L", -1), ("Arm_R", 1)):
        p = P[name]
        parts[name] = local(p, facet([(0.8, 0.42, 0.42), (0.4, 0.46, 0.45), (0.1, 0.46, 0.44), (-0.4, 0.42, 0.4), (-0.8, 0.36, 0.36)], 0.12, 7))
    for name, k in (("Fist_L", 1.0), ("Fist_R", 1.25)):  # 오른 주먹이 더 크다(비대칭 과장)
        p = P[name]
        fist = A.merge(A.crystal(1.25, 0.72, sides=6, tip_h=0.38, base_h=0.32, m=A.rot(rz=8, ry=15)), A.crystal(0.7, 0.28, sides=5, tip_h=0.25, base_h=0.1, center=(0.35, -0.25, -0.3), m=A.rot(rx=-60, rz=40)))  # 날카로운 6면 결정 주먹 + 옆 결정
        parts[name] = local(p, A.xform(fist, s=(k, k, k)))
    for name in ("Leg_L", "Leg_R"):
        p = P[name]
        parts[name] = local(p, facet([(0.45, 0.4, 0.4), (0.15, 0.38, 0.39), (-0.1, 0.36, 0.38), (-0.3, 0.42, 0.45), (-0.45, 0.48, 0.52)], 0.12, 7))
    return dict(Body=body, Head=head, Eyes=eyes, **parts)


def blue_dragon(P):
    b = P["Body"]["center"]
    body = A.loft([[(x, y + b[1] + dy, z) for x, y in A.circle2d(r * 1.1, 10, rx=r * 1.45)] for z, r, dy in ((-2.5, 0.95, 0.12), (-1.8, 1.38, 0.06), (-0.9, 1.42, 0.0), (0.4, 1.32, 0.0), (1.6, 1.12, 0.0), (2.4, 0.8, 0.05))])  # 가슴 앞으로 볼록 · 박스보다 두툼(2차 패스 ×1.15)
    body = A.merge(body, *[A.crystal(1.0 - 0.1 * i, 0.22, sides=4, tip_h=0.4, base_h=0.08, center=(0, b[1] + 1.3, -1.3 + 0.8 * i), m=A.rot(rx=25), ) for i in range(4)])  # 등 가시
    legs = {}
    for n_ in ("Leg_FL", "Leg_FR", "Leg_BL", "Leg_BR"):
        j = P[n_]["joint"]
        front = n_[4] == "F"
        leg = A.tube(A.bezier(j, (j[0], j[1] - 0.6, j[2] + (0.25 if front else -0.25)), (j[0], j[1] - 1.1, j[2] - (0.1 if front else -0.1)), (j[0], -1.38, j[2] - 0.15), n=4), lambda u: 0.6 - 0.12 * u, sides=6)
        foot = A.ellipsoid((0.56, 0.24, 0.66), n=7, rings=3, center=(j[0], -1.38, j[2] - 0.3))
        toes = [A.tube([(j[0] + dx, -1.4, j[2] - 0.62), (j[0] + dx * 1.2, -1.45, j[2] - 0.88)], lambda u: 0.08 * (1 - u) + 0.02, sides=4, tip_end=True) for dx in (-0.2, 0.0, 0.2)]
        legs[n_] = A.merge(leg, foot, *toes)
    nk = P["Neck1"]
    spine = A.bezier((0, -1.4, 0.05), (0, -0.5, -0.35), (0, 0.4, 0.2), (0, 1.4, -0.15), n=6)  # S자(앞으로 기울었다 머리 쪽에서 다시 수평)
    neck = local(nk, A.merge(A.tube(spine, lambda u: 0.7 - 0.22 * u, sides=10), *[A.crystal(0.42, 0.12, sides=4, tip_h=0.16, base_h=0.05, center=(0, yy, 0.55 - 0.1 * i), m=A.rot(rx=70)) for i, yy in enumerate((-0.7, 0.1, 0.9))]))
    h = P["Head"]
    snout = A.loft([[(x, y, z) for x, y in A.chamfer_rect(w, hh, 0.18)] for z, w, hh in ((0.9, 1.3, 1.05), (0.1, 1.45, 1.1), (-0.6, 1.1, 0.8), (-1.15, 0.8, 0.55))])
    horns = [A.tube(A.bezier((s * 0.5, 0.45, 0.6), (s * 0.75, 1.05, 0.95), (s * 0.75, 1.6, 1.5), (s * 0.55, 1.75, 2.1), n=5), lambda u, s=s: (0.27 if s < 0 else 0.24) * (1 - u) + 0.03, sides=6, tip_end=True) for s in (-1, 1)]
    brow = A.box(1.4, 0.18, 0.5, b=0.06, center=(0, 0.42, -0.35))
    head = local(h, A.xform(A.merge(snout, brow), s=(1.18, 1.18, 1.18)))  # A2-N2 머리 ×1.18
    head_horns = local(h, A.merge(*horns))
    head = A.merge(head, head_horns)
    jaw = local(P["Jaw"], A.merge(A.loft([[(x, y, z) for x, y in A.chamfer_rect(w, 0.3, 0.1)] for z, w in ((0.75, 1.15), (0.0, 1.2), (-0.8, 0.75))]),
                                  *[A.tube([(s * 0.35, 0.12, -0.55), (s * 0.35, 0.34, -0.6)], lambda u: 0.07 * (1 - u) + 0.02, sides=4, tip_end=True) for s in (-1, 1)]))  # 둥근 송곳니
    e = P["Eyes"]
    eyes = A.merge(*[A.xform(A.ellipsoid((0.2, 0.13, 0.08), n=8, rings=4), m=A.rot(rz=s * 15) @ rig_m(e), t=add(tuple(e["center"]), (s * 0.42, 0, 0.1))) for s in (-1, 1)])
    wings = {}
    for n_, s in (("Wing_L", -1), ("Wing_R", 1)):
        j = P[n_]["joint"]
        wings[n_] = A.xform(wing_membrane(s, span=6.4, bone=0.26), m=A.rot(rz=s * 24) @ A.rot(rx=-12), t=tuple(j), s=(1, 1.6, 1))  # A2-N2: 폭 4.3 → 6.4 · 높이 ×1.6(T6 최상위 - 날개 끝 사이 ≈ 몸 길이의 2.6배)
    tails = {}
    for n_, r0, r1 in (("Tail1", 0.55, 0.42), ("Tail2", 0.42, 0.3)):
        p = P[n_]
        L = p["size"][2]
        seg = A.merge(A.loft([[(x, y, z) for x, y in A.circle2d(r, 8, rx=r * 1.15)] for z, r in ((-L / 2, r0), (L / 2, r1))]),
                      A.crystal(0.42, 0.1, sides=4, tip_h=0.16, base_h=0.05, center=(0, r0 * 0.9, 0), m=A.rot(rx=30)))
        tails[n_] = local(p, seg)
    p = P["Tail3"]
    L = p["size"][2]
    tip = A.merge(A.loft([[(x, y, z) for x, y in A.circle2d(r, 8, rx=r * 1.1)] for z, r in ((-L / 2, 0.3), (L * 0.1, 0.2))]),
                  A.xform(A.crystal(1.3, 0.42, sides=5, tip_h=0.55, base_h=0.25), m=A.rot(rx=90), t=(0, 0, L * 0.35)))  # 꼬리 끝 얼음 결정
    tails["Tail3"] = local(p, tip)
    return dict(Body=body, **legs, Neck1=neck, Head=head, Jaw=jaw, Eyes=eyes, **wings, **tails)


# 작은 Bevel(빛 맺힘)은 깎은 덩어리에만 - 저폴리 공 · 튜브에 걸면 삼각형만 2 ~ 3배로 늘고 차이가 안 보인다
BEVEL = {"rock_boar": {"Body", "Head"}, "crystal_beetle": {"Head"}, "hermit_knight": set(), "amethyst_bat": set(), "bubble_jelly": set(), "moss_slime": set()}

SPECIES = {"rock_boar": rock_boar, "crystal_beetle": crystal_beetle, "amethyst_bat": amethyst_bat, "hermit_knight": hermit_knight,
           "bubble_jelly": bubble_jelly, "moss_slime": moss_slime, "sand_scorpion": sand_scorpion, "cactus_imp": cactus_imp, "bolt_imp": bolt_imp,
           "cloud_sheep": cloud_sheep, "ice_golem": ice_golem, "blue_dragon": blue_dragon}


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
            A.write_json(os.path.join(OUT, "%s.meta.json" % sid), dict(A.meta_of(objs, budget), version=("A2-N2" if sid == "blue_dragon" else "A2-N1"), rigId=sid, kind=rig.get("kind", "monster")))
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
