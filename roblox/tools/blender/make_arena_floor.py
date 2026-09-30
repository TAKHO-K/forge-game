# -*- coding: utf-8 -*-
# QUEUE-ALL1 P2 보스 아레나 바닥 v2(docs/design/v2/03-arena-floor-v2.md): 텍스처 없이 모델링한 동심원 석판(이음매 · 판마다 미세 기울기 = 명도 차).
#   구간 수호자 먼저: 붕괴 조각(8조각 · 각 = (k − 1) × 45° ~ k × 45°, +X에서 +Z 쪽 - server/BossArenaMap 조각 바닥과 같은 규칙)마다 메시 하나(Slice<k>) +
#   가운데 허브(Hub - 반경 8, 늘 남는다) + 룬 선(Runes - 허브 둘레 · 옅은 청록). 동심원 경계 = 안쪽 원 12(원 안 강공격) · 조각 경계 = 석판 이음매(어디가 무너질지 바닥이 말해 준다).
#   좌표 = Roblox(Y 위 · 바닥 윗면 = 0 · 아레나 중심 = 원점) · 판 윗면 +0.06(예고 도형 +0.15보다 낮게) · 판 아래 −0.04(이음매 틈 사이로 서버 바닥 = 줄눈 색이 보인다).
#   성능 상한(문서): 파트 ≤ 10 · 삼각형 ≤ 5,000.
# 실행: bash bl.sh make_arena_floor.py [--bosses guardian,frost,...] [--export]
#   나머지 5보스(붕괴 없음) = 판 두 톤 SlabA · SlabB(무작위 반반 = 명도 차) + 줄눈 원판 Grout(−0.03) + 보스 무늬 Detail(금 · 물웅덩이 · 결정 맥 · 번개 동심원) · 전갈 = 정사각 유적 타일(모래 줄눈)
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import artlib as A  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "art", "arena"))
RADIUS = 140.0
HUB = 8.0
RINGS = [HUB, 12.0, 30.0, 52.0, 76.0, 102.0, 126.0, RADIUS - 0.6]  # 동심원 경계(안쪽 원 12 = 원 안 강공격 원 · 바깥은 벽 안쪽 턱 앞까지)
SLAB_ARC = 15.0  # 판 하나의 호 길이(대략)
GAP = 0.22  # 이음매 반폭(판을 이만큼씩 안으로)
TOP, BOTTOM = 0.06, -0.04
TILT_DEG = 0.7  # 판마다 무작위 기울기(빛 받는 각이 달라 명도 ±5 ~ 8%)
SLICES = 8
BUDGET = 5000
PREVIEW = {"slab": (132, 136, 146), "hub": (140, 144, 154), "rune": (140, 220, 210)}
# Roblox 가져오기는 메시 한 축을 2,048(cm 기준 = 20.48 stud)로 자른다(Play 실측: 133 stud 조각이 20.5로 들어왔다) → 가로(X · Z)만 1/10로 내보내고
# 클라(BossArenaDressing floorMesh.scaleXZ = 10)가 되돌린다. 높이(두께 · 기울기)는 그대로.
XZ_EXPORT = 0.1


def sector_slab(r0, r1, a0, a1, rng):
    """고리 조각 판(안쪽 반경 r0 · 바깥 r1 · 각 a0 ~ a1 도) - 이음매만큼 안으로 줄이고 살짝 기울인다"""
    r0g, r1g = r0 + GAP, r1 - GAP
    mid_r = (r0 + r1) / 2
    da = math.degrees(GAP / mid_r)
    a0g, a1g = a0 + da, a1 - da
    n = max(2, int(math.ceil((a1g - a0g) * math.pi / 180 * r1g / 9.0)))
    pts = []
    for i in range(n + 1):
        a = math.radians(a0g + (a1g - a0g) * i / n)
        pts.append((math.cos(a), math.sin(a)))
    top = [(c * r1g, TOP, s * r1g) for c, s in pts] + [(c * r0g, TOP, s * r0g) for c, s in reversed(pts)]
    bot = [(x, BOTTOM, z) for x, _, z in top]
    m = len(top)
    verts = top + bot
    faces = [tuple(range(m))[::-1]]  # 윗면(바깥 호 → 안쪽 호 역순 · 위에서 보아 반시계)
    for i in range(m):
        j = (i + 1) % m
        faces.append((i, j, m + j, m + i))
    # 미세 기울기: 판 가운데를 축으로 무작위 방향 0 ~ TILT_DEG
    am = math.radians((a0 + a1) / 2)
    cx, cz = math.cos(am) * mid_r, math.sin(am) * mid_r
    tx, tz = rng.uniform(-TILT_DEG, TILT_DEG), rng.uniform(-TILT_DEG, TILT_DEG)
    geo = (verts, faces)
    geo = A.xform(geo, t=(-cx, 0, -cz))
    geo = A.xform(geo, m=A.rot(rx=tx, rz=tz))
    return A.xform(geo, t=(cx, 0, cz))


def slice_geo(k, rng):
    a0, a1 = (k - 1) * 360.0 / SLICES, k * 360.0 / SLICES
    parts = []
    for r0, r1 in zip(RINGS[:-1], RINGS[1:]):
        arc = (a1 - a0) * math.pi / 180 * (r0 + r1) / 2
        n = max(1, int(round(arc / SLAB_ARC)))
        # 고리마다 반 칸 어긋나게(벽돌 쌓기처럼 이음매가 한 줄로 안 이어진다) - 단 조각 경계(a0 · a1)는 늘 이음매
        offs = 0.5 if (RINGS.index(r0) % 2 == 1 and n >= 2) else 0.0
        edges = [a0] + [a0 + (a1 - a0) * (i + offs) / n for i in range(1, n)] + [a1]
        if offs:
            edges = [a0] + [a0 + (a1 - a0) * (i - 0.5) / n for i in range(1, n + 1)] + [a1]
        for e0, e1 in zip(edges[:-1], edges[1:]):
            if e1 - e0 > 0.5:
                parts.append(sector_slab(r0, r1, e0, e1, rng))
    return A.merge(*parts)


def hub_geo():
    # 가운데 원판(허브) - 가장자리 모따기 · 윗면 = 판과 같은 높이
    n = 24
    top = [(math.cos(2 * math.pi * i / n) * (HUB - GAP), TOP + 0.01, math.sin(2 * math.pi * i / n) * (HUB - GAP)) for i in range(n)]
    bot = [(x, BOTTOM, z) for x, _, z in top]
    verts = top + bot
    faces = [tuple(range(n))[::-1]] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    return (verts, faces)


def rune_geo():
    # 허브 둘레 새김 고리 + 룬 막대 8(조각 방향 = 조각 번호 표식) - 판보다 0.01 위(예고 도형보다 낮게)
    y = TOP + 0.02
    parts = [A.xform(A.lathe([(HUB - 1.6, -0.01), (HUB - 1.1, 0.0), (HUB - 1.6, 0.01)], 32, axis="Y"), t=(0, y, 0))]
    for k in range(SLICES):
        a = math.radians((k + 0.5) * 360.0 / SLICES)
        c, s = math.cos(a), math.sin(a)
        parts.append(A.xform(A.box(0.25, 0.02, 2.2), m=A.rot(ry=-math.degrees(a) + 90), t=(c * (HUB - 4.2), y, s * (HUB - 4.2))))
    return A.merge(*parts)


def build_guardian(rng, col, sx):
    objs = []
    for k in range(1, SLICES + 1):
        objs.append(A.make_obj("Slice%d" % k, sx(slice_geo(k, rng)), PREVIEW["slab"], col, mat_name="floor_guardian_slice%d" % k))
    objs.append(A.make_obj("Hub", sx(hub_geo()), PREVIEW["hub"], col, mat_name="floor_guardian_hub"))
    objs.append(A.make_obj("Runes", sx(rune_geo()), PREVIEW["rune"], col, neon=True, mat_name="floor_guardian_runes"))
    return objs


# ────────── 나머지 5보스(붕괴 없음): 판 두 톤(SlabA · SlabB) + 줄눈 원판(Grout) + 보스 무늬(Detail) ──────────
def ring_slabs(rings, arc, rng):
    a_list, b_list = [], []
    for ri, (r0, r1) in enumerate(zip(rings[:-1], rings[1:])):
        n = max(3, int(round(2 * math.pi * (r0 + r1) / 2 / arc)))
        off = rng.uniform(0, 360.0 / n)
        for i in range(n):
            e0 = off + 360.0 * i / n
            (a_list if rng.random() < 0.5 else b_list).append(sector_slab(r0, r1, e0, e0 + 360.0 / n, rng))
    return a_list, b_list


def grid_slabs(tile, rng):
    """유적 타일: 정사각 격자(원 안에 온전히 드는 타일만 - 벽 쪽 빈자리는 모래 줄눈)"""
    a_list, b_list = [], []
    n = int(RADIUS // tile) + 1
    for i in range(-n, n):
        for j in range(-n, n):
            x0, z0 = i * tile, j * tile
            corners = [(x0, z0), (x0 + tile, z0), (x0, z0 + tile), (x0 + tile, z0 + tile)]
            if max(math.hypot(x, z) for x, z in corners) > RADIUS - 1.0:
                continue
            w = tile - 2 * GAP * 1.4
            geo = A.box(w, TOP - BOTTOM, w, center=(x0 + tile / 2, (TOP + BOTTOM) / 2, z0 + tile / 2))
            geo = A.xform(geo, t=(-(x0 + tile / 2), 0, -(z0 + tile / 2)))
            geo = A.xform(geo, m=A.rot(rx=rng.uniform(-TILT_DEG, TILT_DEG), rz=rng.uniform(-TILT_DEG, TILT_DEG)))
            geo = A.xform(geo, t=(x0 + tile / 2, 0, z0 + tile / 2))
            (a_list if rng.random() < 0.5 else b_list).append(geo)
    return a_list, b_list


def grout_geo():
    n = 64
    y = -0.03
    top = [(math.cos(2 * math.pi * i / n) * RADIUS, y, math.sin(2 * math.pi * i / n) * RADIUS) for i in range(n)]
    return (top, [tuple(range(n))[::-1]])


def zig_ring(r, n, amp, w=0.35):
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        rr = r + (amp if i % 2 == 0 else -amp)
        pts.append((math.cos(a) * rr, math.sin(a) * rr))
    segs = []
    for i in range(n):
        (x0, z0), (x1, z1) = pts[i], pts[(i + 1) % n]
        L = math.hypot(x1 - x0, z1 - z0)
        yaw = math.degrees(math.atan2(x1 - x0, z1 - z0))
        segs.append(A.xform(A.box(w, 0.02, L + w), m=A.rot(ry=yaw), t=((x0 + x1) / 2, TOP + 0.015, (z0 + z1) / 2)))
    return A.merge(*segs)


def detail_geo(kind, rng):
    y = TOP + 0.012
    out = []
    if kind == "cracks":  # 얼음 금(가는 선 몇 줄기)
        for _ in range(26):
            a, r = rng.uniform(0, 2 * math.pi), rng.uniform(15, 125)
            x, z = math.cos(a) * r, math.sin(a) * r
            yaw = rng.uniform(0, 180)
            for k in range(3):
                L = rng.uniform(2.5, 5)
                out.append(A.xform(A.box(0.18, 0.02, L), m=A.rot(ry=yaw), t=(x, y, z)))
                x += math.sin(math.radians(yaw)) * L * 0.9
                z += math.cos(math.radians(yaw)) * L * 0.9
                yaw += rng.uniform(-40, 40)
    elif kind == "puddles":  # 얕은 물웅덩이(납작한 타원)
        for _ in range(12):
            a, r = rng.uniform(0, 2 * math.pi), rng.uniform(20, 120)
            rx, rz = rng.uniform(3, 7), rng.uniform(2, 5)
            n = 14
            ring = [(math.cos(a) * r + math.cos(2 * math.pi * i / n) * rx, y, math.sin(a) * r + math.sin(2 * math.pi * i / n) * rz) for i in range(n)]
            out.append((ring, [tuple(range(n))[::-1]]))
    elif kind == "veins":  # 결정 맥(지그재그 가는 선)
        for _ in range(18):
            a, r = rng.uniform(0, 2 * math.pi), rng.uniform(10, 120)
            x, z = math.cos(a) * r, math.sin(a) * r
            yaw = rng.uniform(0, 360)
            for k in range(4):
                L = rng.uniform(3, 6)
                out.append(A.xform(A.box(0.22, 0.02, L), m=A.rot(ry=yaw), t=(x, y, z)))
                x += math.sin(math.radians(yaw)) * L * 0.9
                z += math.cos(math.radians(yaw)) * L * 0.9
                yaw += rng.choice([-50, 50])
    elif kind == "bolts":  # 번개 문양 동심원 3줄
        for r, n in ((36, 28), (78, 50), (118, 70)):
            out.append(zig_ring(r, n, 1.4))
    return A.merge(*out) if out else None


BOSSES = {
    "guardian": None,
    "frost": dict(rings=[0, 10, 26, 46, 70, 96, 122, RADIUS - 0.6], arc=18.0, detail="cracks"),
    "abyssal": dict(rings=[0, 8, 22, 40, 62, 86, 112, RADIUS - 0.6], arc=12.0, detail="puddles"),
    "crystal": dict(rings=[0, 9, 24, 44, 68, 94, 120, RADIUS - 0.6], arc=14.0, detail="veins"),
    "scorpion": dict(grid=12.5, detail=None),
    "storm": dict(rings=[0, 12, 36, 58, 78, 98, 118, RADIUS - 0.6], arc=24.0, detail="bolts"),
}


def build(boss):
    rng = random.Random(20260930)
    col = A.new_collection("floor_" + boss)
    sx = lambda g: A.xform(g, s=(XZ_EXPORT, 1, XZ_EXPORT))  # noqa: E731
    if boss == "guardian":
        return build_guardian(rng, col, sx)
    cfg = BOSSES[boss]
    if cfg.get("grid"):
        a_list, b_list = grid_slabs(cfg["grid"], rng)
    else:
        rings = list(cfg["rings"])
        rings[0] = max(rings[0], 0.8)  # 가운데 점(반경 0)은 판이 안 된다
        a_list, b_list = ring_slabs(rings, cfg["arc"], rng)
    objs = [A.make_obj("SlabA", sx(A.merge(*a_list)), PREVIEW["slab"], col, mat_name="floor_%s_a" % boss),
            A.make_obj("SlabB", sx(A.merge(*b_list)), PREVIEW["hub"], col, mat_name="floor_%s_b" % boss),
            A.make_obj("Grout", sx(grout_geo()), (60, 60, 70), col, mat_name="floor_%s_grout" % boss)]
    d = cfg.get("detail") and detail_geo(cfg["detail"], rng)
    if d:
        objs.append(A.make_obj("Detail", sx(d), PREVIEW["rune"], col, neon=True, mat_name="floor_%s_detail" % boss))
    return objs


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    export = "--export" in argv
    bosses = argv[argv.index("--bosses") + 1].split(",") if "--bosses" in argv else list(BOSSES)
    for boss in bosses:
        A.reset()
        objs = build(boss)
        tris = sum(A.tri_count(o) for o in objs)
        print("[make_arena_floor] %s 파트 %d · 삼각형 %d(상한 %d)" % (boss, len(objs), tris, BUDGET))
        if export:
            os.makedirs(OUT, exist_ok=True)
            A.export_fbx(os.path.join(OUT, "floor_%s.fbx" % boss), objs)
    print("[make_arena_floor] 끝")


if __name__ == "__main__":
    main()
