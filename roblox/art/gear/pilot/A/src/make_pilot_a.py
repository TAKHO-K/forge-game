# -*- coding: utf-8 -*-
# PILOT-A(2026-10-05): 장비 3D 제작 방식 시범 A안 = Blender 스크립트 모델링 개선. 대검(전사) 몸통 갑옷 · 전설 · 석조 평원 1벌.
#   범위 = 가슴판(UpperTorso) + 왼어깨 + 오른어깨(따로 떼는 오브젝트 3개 · 셋 다 UpperTorso에 붙음 - gear-art-v3.md 6절 LOOK3 판정).
#   LOOK3와 다른 점(방식):
#     ① 몸통 곡면 함수 S(x, y, h) 위에 2D 도안(판 · 테두리 · 문장 · 리벳)을 투영 → 판이 몸을 따라 휘고 가장자리가 둥근 테로 감싼다(LOOK3 = 상자 · 고리 조합)
#     ② 매끈 음영 + 각도 기준 날카로운 모서리(smooth by angle) - LOOK3 = 평면 음영
#     ③ 색 = 팔레트 1장(256² · 색마다 세로 명암 띠) + UV v에 빛 · AO(광선) · 볼록 모서리 하이라이트를 굽는다 → 세트 · 등급 교체 = 팔레트 칸만 바꿈
#   색 = docs/design/gear-art-v3.md 3-1(등급색 = 판 에나멜 · 전설 테 = 금 #E2B45A · 가죽 #5A3E2B) · 3절(석조 평원 색1 이끼 #66834A · 색2 청동 #A87945)
#   값 출처 = GearV3Data.lua(look2 · tier1) · ItemVisualData.lua(legendary) - 이 시범 파일 안에 숫자를 옮겨 적음(게임 코드 아님 · 새 파일만 규칙)
# 실행: bash roblox/tools/blender/bl.sh roblox/art/gear/pilot/A/src/make_pilot_a.py [--render] [--export]
import bpy
import bmesh
import json
import math
import os
import sys
import time
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

T0 = time.time()
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, ".."))
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
C = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))  # Roblox(x, y, z · 앞 = −Z) → Blender(x, −z, y · 앞 = +Y)

# ────────────────────────── 팔레트(칸 = 색 구역) ──────────────────────────
ENAMEL = tuple(min(255, round(c * 1.1)) for c in (216, 120, 40))  # 전설 메인 #D87828 × look2.brightness 1.1
SWATCH = {  # 이름: (기본색, 하이라이트 쪽 섞을 빛 색, 섞는 양, 그늘 배율)
    "enamel": (ENAMEL, (255, 214, 150), 0.30, 0.52),
    "enamel2": (tuple(round(c * 0.84) for c in ENAMEL), (255, 200, 140), 0.24, 0.5),
    "gold": ((226, 180, 90), (255, 246, 214), 0.55, 0.45),
    "leather": ((90, 62, 43), (160, 120, 88), 0.30, 0.55),
    "leather2": ((64, 44, 31), (120, 90, 66), 0.25, 0.55),
    "moss": ((102, 131, 74), (190, 214, 150), 0.32, 0.5),
    "bronze": ((168, 121, 69), (240, 206, 150), 0.40, 0.48),
    "gem": ((232, 150, 40), (255, 238, 170), 0.75, 0.55),  # 전설 핵심 보석 = 호박 캐보숑(2-1절 · 밝은 #FFC36A 쪽으로)
    "groove": ((52, 44, 40), (90, 80, 70), 0.2, 0.7),  # 문장 균열 · 틈
}
ORDER = list(SWATCH)
PAL_RES = 256
COL_W = PAL_RES // 16


def ramp(name, v):
    base, lite, k, dk = SWATCH[name]
    cool = (46, 40, 70)
    dark = tuple(base[i] * dk * 0.8 + cool[i] * 0.2 for i in range(3))
    hi = tuple(base[i] + (lite[i] - base[i]) * k for i in range(3))
    if v < 0.55:
        t = v / 0.55
        t = t * t * (3 - 2 * t)
        return tuple(dark[i] + (base[i] - dark[i]) * t for i in range(3))
    t = ((v - 0.55) / 0.45) ** 1.6
    return tuple(base[i] + (hi[i] - base[i]) * t for i in range(3))


def palette_image(path):
    img = bpy.data.images.new("PilotA_Palette", PAL_RES, PAL_RES, alpha=False)
    px = [0.0] * (PAL_RES * PAL_RES * 4)
    for y in range(PAL_RES):
        v = (y + 0.5) / PAL_RES
        cols = [ramp(n, v) for n in ORDER]
        for x in range(PAL_RES):
            ci = x // COL_W
            c = cols[ci] if ci < len(cols) else (128, 128, 128)
            i = (y * PAL_RES + x) * 4
            px[i:i + 4] = [c[0] / 255, c[1] / 255, c[2] / 255, 1.0]
    img.filepath_raw = path
    img.file_format = "PNG"
    img.pixels[:] = px
    img.update()
    img.save()
    bpy.data.images.remove(img)
    img = bpy.data.images.load(path)
    img.colorspace_settings.name = "sRGB"
    return img


# ────────────────────────── 몸통 곡면(UpperTorso 로컬 · 파트 2 × 1.6 × 1) ──────────────────────────
P_EXP = 2.8
A_CTRL = [(-0.88, 1.08), (-0.5, 1.07), (0.0, 1.08), (0.5, 1.09), (0.74, 1.07), (0.86, 0.97), (0.93, 0.64)]
BF_CTRL = [(-0.88, 0.58), (-0.5, 0.585), (0.0, 0.61), (0.42, 0.63), (0.74, 0.58), (0.86, 0.5), (0.93, 0.41)]
BB_CTRL = [(-0.88, 0.57), (-0.5, 0.56), (0.0, 0.57), (0.5, 0.58), (0.74, 0.56), (0.86, 0.5), (0.93, 0.41)]


def interp(ctrl, y):
    if y <= ctrl[0][0]:
        return ctrl[0][1]
    if y >= ctrl[-1][0]:
        return ctrl[-1][1]
    for i in range(len(ctrl) - 1):
        (y0, a), (y1, b) = ctrl[i], ctrl[i + 1]
        if y0 <= y <= y1:
            p0 = ctrl[i - 1][1] if i > 0 else a
            p3 = ctrl[i + 2][1] if i + 2 < len(ctrl) else b
            t = (y - y0) / (y1 - y0)
            return 0.5 * ((2 * a) + (-p0 + b) * t + (2 * p0 - 5 * a + 4 * b - p3) * t * t + (-p0 + 3 * a - 3 * b + p3) * t ** 3)


def se(c, e):
    return math.copysign(abs(c) ** e, c)


def ring_pt(y, t, grow=0.0):
    a, bf, bb = interp(A_CTRL, y) + grow, interp(BF_CTRL, y) + grow, interp(BB_CTRL, y) + grow
    c, s = math.cos(t), math.sin(t)
    return (a * se(c, 2 / P_EXP), y, (bb if s > 0 else bf) * se(s, 2 / P_EXP))


def S(x, y, h, back=False):
    """몸통 앞(또는 뒤) 곡면에서 (x, y) 위치 · 바깥 법선으로 h만큼 띄운 점"""
    a = interp(A_CTRL, y)
    d = interp(BB_CTRL if back else BF_CTRL, y)
    u = max(-0.995, min(0.995, x / a))
    w = (1 - abs(u) ** P_EXP) ** (1 / P_EXP)
    z = d * w * (1 if back else -1)
    gx = P_EXP * abs(u) ** (P_EXP - 1) * math.copysign(1, u) / a
    gz = P_EXP * abs(z / d) ** (P_EXP - 1) * math.copysign(1, z) / d
    n = Vector((gx, 0, gz)).normalized()
    return (x + n.x * h, y, z + n.z * h)


# ────────────────────────── 기하 도우미(Roblox 공간 점 · 면) ──────────────────────────
class Geo:
    def __init__(self):
        self.parts = []  # (구역, verts, faces)

    def add(self, zone, g):
        self.parts.append((zone, g[0], g[1]))
        if "--stats" in ARGS:
            import traceback
            ln = traceback.extract_stack()[-2].lineno
            print("[stat] L%d %s %d" % (ln, zone, sum(len(f) - 2 for f in g[1])))


def resample(poly, step, closed=True):
    out = []
    n = len(poly)
    for i in range(n if closed else n - 1):
        a, b = poly[i], poly[(i + 1) % n]
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        k = max(1, int(math.ceil(L / step)))
        for j in range(k):
            t = j / k
            out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    if not closed:
        out.append(poly[-1])
    return out


def area2(poly):
    return sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1] for i in range(len(poly))) / 2


def offsets2d(poly, closed=True):
    """점마다 바깥쪽 2D 법선(미터) - 반시계 다각형 기준"""
    n = len(poly)
    sgn = 1 if area2(poly) > 0 else -1
    out = []
    for i in range(n):
        if not closed and (i == 0 or i == n - 1):
            a, b = (poly[0], poly[1]) if i == 0 else (poly[-2], poly[-1])
            d = Vector((b[0] - a[0], b[1] - a[1])).normalized()
            out.append(Vector((d.y, -d.x)) * sgn)
            continue
        p0, p1, p2 = poly[i - 1], poly[i], poly[(i + 1) % n]
        d0 = Vector((p1[0] - p0[0], p1[1] - p0[1])).normalized()
        d1 = Vector((p2[0] - p1[0], p2[1] - p1[1])).normalized()
        n0, n1 = Vector((d0.y, -d0.x)), Vector((d1.y, -d1.x))
        m = (n0 + n1)
        m = m.normalized() if m.length > 1e-6 else n0
        k = 1 / max(0.35, m.dot(n0))
        out.append(m * k * sgn)
    return out


def plate(surf, outline, h_top, step=0.1, rings=3, pillow=0.35, bevel=0.03):
    """2D 도안 → 곡면 위 도톰한 판(가장자리 경사 + 가운데 볼록) · 안쪽 고리는 한 점이 아니라 가운데 선(긴 축)으로 줄어듦
    (한 점 부채꼴은 긴 판에서 가늘고 긴 삼각형 → 명암 번짐 톱니가 생겼다)"""
    ol = resample(outline, step)
    n = len(ol)
    cx = sum(p[0] for p in ol) / n
    cy = sum(p[1] for p in ol) / n
    sxx = sum((p[0] - cx) ** 2 for p in ol)
    syy = sum((p[1] - cy) ** 2 for p in ol)
    sxy = sum((p[0] - cx) * (p[1] - cy) for p in ol)
    ang = 0.5 * math.atan2(2 * sxy, sxx - syy)
    ax = (math.cos(ang), math.sin(ang))
    along = [(p[0] - cx) * ax[0] + (p[1] - cy) * ax[1] for p in ol]
    across = [-(p[0] - cx) * ax[1] + (p[1] - cy) * ax[0] for p in ol]
    L = max(0.0, (max(along) - min(along)) / 2 - (max(across) - min(across)) / 2)
    offs = offsets2d(ol)
    edge = [(p[0] - offs[i].x * bevel, p[1] - offs[i].y * bevel) for i, p in enumerate(ol)]
    hb = h_top * (1 - pillow * 0.35)
    verts = [surf(p[0], p[1], -0.02) for p in ol] + [surf(p[0], p[1], h_top * (1 - pillow)) for p in ol] + [surf(q[0], q[1], hb) for q in edge]
    for k in range(1, rings):
        f = 1 - k / rings
        for q in edge:
            t = max(-L, min(L, (q[0] - cx) * ax[0] + (q[1] - cy) * ax[1]))
            m = (cx + ax[0] * t, cy + ax[1] * t)
            r = (m[0] + (q[0] - m[0]) * f, m[1] + (q[1] - m[1]) * f)
            verts.append(surf(r[0], r[1], hb + h_top * pillow * 0.35 * (k / rings) ** 0.7))
    R = 3 + rings - 1
    faces = []
    for r in range(R - 1):
        for i in range(n):
            j = (i + 1) % n
            faces.append((r * n + i, r * n + j, (r + 1) * n + j, (r + 1) * n + i))
    faces.append(tuple(range((R - 1) * n, R * n)))  # 가운데 = n각 뚜껑(내보내기 전 beauty 삼각화)
    return verts, faces


def rim(surf, path, w, h, h0=-0.015, step=0.1, closed=True, prof=None):
    """2D 경로를 따라 둥근 테(단면 = 바깥 오프셋 · 높이) - 곡면 위"""
    pts = resample(path, step, closed)
    offs = offsets2d(pts, closed)
    prof = prof or [(-w / 2, h0), (-w * 0.4, h), (w * 0.4, h), (w / 2, h0)]
    rings = []
    for p, o in zip(pts, offs):
        rings.append([surf(p[0] + o.x * dx, p[1] + o.y * dx, dz) for dx, dz in prof])
    return sweep_faces(rings, closed)


def sweep_faces(rings, closed, bottom=False):
    """단면 고리 줄을 잇는다 - 단면 첫 점 · 끝 점 사이(곡면에 묻힌 바닥)는 bottom=True일 때만 닫음 · 열린 경로 = 양 끝 뚜껑"""
    m = len(rings[0])
    verts = [p for r in rings for p in r]
    faces = []
    nr = len(rings)
    for r in range(nr if closed else nr - 1):
        a, b = r * m, ((r + 1) % nr) * m
        for i in range(m - 1):
            faces.append((a + i, a + i + 1, b + i + 1, b + i))
        if bottom:
            faces.append((a + m - 1, a, b, b + m - 1))
    if not closed:
        faces.append(tuple(reversed(range(m))))
        faces.append(tuple(range((nr - 1) * m, nr * m)))
    return verts, faces


def dome_on(surf, x, y, r, h, n=8, rings=2, base=-0.01):
    """곡면 위 둥근 리벳 · 캐보숑(법선 방향 볼록)"""
    verts = []
    prof = [(1.0, base)] + [(math.cos(math.pi / 2 * k / rings) * 1.0, h * math.sin(math.pi / 2 * k / rings)) for k in range(rings)]
    for rr, hh in prof:
        for i in range(n):
            a = 2 * math.pi * i / n
            verts.append(surf(x + r * rr * math.cos(a), y + r * rr * math.sin(a), hh))
    verts.append(surf(x, y, h))
    faces = []
    L = len(prof)
    for k in range(L - 1):
        for i in range(n):
            j = (i + 1) % n
            faces.append((k * n + i, k * n + j, (k + 1) * n + j, (k + 1) * n + i))
    c = len(verts) - 1
    last = (L - 1) * n
    faces += [(last + i, last + (i + 1) % n, c) for i in range(n)]
    return verts, faces


def gem_on(g, surf, x, y, r, h, n=10):
    g.add("gold", rim(surf, [(x + r * 1.18 * math.cos(2 * math.pi * i / 14), y + r * 1.18 * math.sin(2 * math.pi * i / 14)) for i in range(14)], 0.045, h * 0.55, step=1))
    g.add("gem", dome_on(surf, x, y, r, h, n=n, rings=3))


# ────────────────────────── 가슴판(Chest) ──────────────────────────
SHIELD = [(0.0, 0.53), (0.12, 0.47), (0.27, 0.5), (0.27, 0.22), (0.22, -0.02), (0.12, -0.15), (0.0, -0.24),
          (-0.12, -0.15), (-0.22, -0.02), (-0.27, 0.22), (-0.27, 0.5), (-0.12, 0.47)]
PEC_R = [(0.36, 0.76), (0.86, 0.76), (0.99, 0.52), (0.98, 0.02), (0.68, -0.14), (0.4, -0.04), (0.34, 0.26)]


def mir(poly):
    return [(-x, y) for x, y in reversed(poly)]


def body_shell():
    """가죽 바탕 흉갑(한 겹 - 안쪽은 몸에 가려 안 보임 · 아래 · 목 테가 가장자리를 덮음)"""
    ys = [-0.88, -0.45, 0.0, 0.42, 0.68, 0.82, 0.89, 0.93]
    N = 24
    rings = [[ring_pt(y, 2 * math.pi * i / N + math.pi / N) for i in range(N)] for y in ys]
    verts = [p for r in rings for p in r]
    faces = []
    for r in range(len(ys) - 1):
        for i in range(N):
            j = (i + 1) % N
            faces.append((r * N + i, r * N + j, (r + 1) * N + j, (r + 1) * N + i))
    return verts, faces


def loop_sweep(y, grow, prof, N=28):
    """몸통 둘레 고리를 따라 단면 prof(바깥 dx, 위 dy) 스윕 - 목깃 · 아래 테"""
    rings = []
    for i in range(N):
        t = 2 * math.pi * i / N + math.pi / N
        p = Vector(ring_pt(y, t, grow))
        q = Vector(ring_pt(y, t + 0.01, grow))
        tan = (q - p).normalized()
        out = tan.cross(Vector((0, 1, 0))).normalized()
        if out.dot(Vector((p.x, 0, p.z))) < 0:
            out = -out
        rings.append([tuple(p + out * dx + Vector((0, dy, 0))) for dx, dy in prof])
    m = len(prof)
    verts = [p for r in rings for p in r]
    faces = []
    for r in range(N):
        a, b = r * m, ((r + 1) % N) * m
        for i in range(m):
            k = (i + 1) % m
            faces.append((a + i, a + k, b + k, b + i))
    return verts, faces


def chest():
    g = Geo()
    F = lambda x, y, h: S(x, y, h)  # noqa: E731
    B = lambda x, y, h: S(x, y, h, back=True)  # noqa: E731
    g.add("leather", body_shell())
    # 가슴 양쪽 판(에나멜) + 굵은 금 테 + 리벳
    for poly in (PEC_R, mir(PEC_R)):
        g.add("enamel", plate(F, poly, 0.075, step=0.14, rings=2))
        g.add("gold", rim(F, poly, 0.07, 0.1, step=0.15))
        s = 1 if poly[0][0] > 0 else -1
        for x, y in ((0.86, 0.62), (0.9, 0.12), (0.52, 0.64)):
            g.add("gold", dome_on(F, s * x, y, 0.035, 0.11, n=6, rings=2))
    # 배 겹판 3장(위가 아래를 덮음) - 아래로 갈수록 살짝 좁고 어둡게
    for k, (y0, y1, w) in enumerate(((-0.32, -0.1, 0.92), (-0.53, -0.3, 0.9), (-0.76, -0.51, 0.86))):
        poly = [(-w, y1), (w, y1), (w - 0.02, y0 + 0.01), (w * 0.5, y0 - 0.005), (0, y0 - 0.01), (-w * 0.5, y0 - 0.005), (-(w - 0.02), y0 + 0.01)]
        hh = 0.07 - 0.012 * k
        g.add("enamel2", plate(F, poly, hh, step=0.16, rings=2, pillow=0.2))
        g.add("gold", rim(F, poly[2:], 0.05, hh + 0.025, closed=False, step=0.16))
    # 가운데 문장(석조 평원 = 돌 방패 + 가운데 균열) - 이끼 바탕 · 청동 테 · 균열 홈
    g.add("moss", plate(F, SHIELD, 0.12, step=0.09, rings=2, pillow=0.4))
    g.add("bronze", rim(F, SHIELD, 0.075, 0.15, step=0.1))
    crack = [(0.0, 0.4), (0.05, 0.26), (-0.03, 0.14), (0.04, 0.0), (-0.01, -0.12)]
    g.add("groove", rim(F, crack, 0.035, 0.125, closed=False, step=0.05, prof=[(-0.018, 0.1), (0, 0.128), (0.018, 0.1)]))
    for s in (-1, 1):  # 돌 덩이 느낌 = 방패 양쪽 작은 돌출 2
        g.add("moss", dome_on(F, s * 0.15, 0.3, 0.05, 0.145, n=6, rings=2))
    # 핵심 보석(전설 = 호박 캐보숑) - 목 아래
    gem_on(g, F, 0.0, 0.66, 0.085, 0.14)
    # 목깃(굵은 금) + 흉갑 아래 테(금)
    g.add("gold", loop_sweep(0.9, -0.22, [(0.0, -0.06), (0.08, 0.0), (0.05, 0.12), (-0.04, 0.06)], N=16))
    g.add("gold", loop_sweep(-0.86, 0.0, [(-0.02, -0.045), (0.05, -0.03), (0.05, 0.035), (-0.02, 0.045)], N=24))
    # 등판(에나멜) + 테 + 리벳
    back = [(-0.78, 0.74), (0.78, 0.74), (0.92, 0.3), (0.74, -0.55), (0.0, -0.66), (-0.74, -0.55), (-0.92, 0.3)]
    g.add("enamel", plate(B, back, 0.06, step=0.16, rings=2, pillow=0.2))
    g.add("gold", rim(B, back, 0.065, 0.09, step=0.16))
    for x, y in ((-0.62, 0.6), (0.62, 0.6), (-0.7, -0.35), (0.7, -0.35)):
        g.add("gold", dome_on(B, x, y, 0.035, 0.1, n=6, rings=2))
    g.add("gold", rim(B, [(0.0, 0.6), (0.0, -0.5)], 0.05, 0.1, closed=False, step=0.1))  # 등 가운데 마루
    # 옆구리 가죽 끈 + 금 버클(좌우)
    for s_ in (-1, 1):
        g.add("leather2", side_strap(s_))
        g.add("gold", side_buckle(s_))
    return g


def side_strap(s):
    """옆구리 세로 가죽 끈(곡면 옆 = t ≈ 0 · π)"""
    t = 0.0 if s > 0 else math.pi
    rings = []
    for y in (0.35, 0.1, -0.15, -0.4, -0.62):
        p = Vector(ring_pt(y, t, 0.0))
        out = Vector((s, 0, 0))
        side = Vector((0, 0, 1))
        rings.append([tuple(p + out * dx + side * dz) for dx, dz in ((-0.01, -0.11), (0.03, -0.1), (0.035, 0.0), (0.03, 0.1), (-0.01, 0.11))])
    return sweep_faces(rings, False)


def side_buckle(s):
    t = 0.0 if s > 0 else math.pi
    p = Vector(ring_pt(-0.15, t, 0.0))
    x0, x1 = p.x + s * 0.0, p.x + s * 0.075
    v = [(x, p.y + yy, p.z + zz) for x in (x0, x1) for yy in (-0.08, 0.08) for zz in (-0.13, 0.13)]
    f = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    return v, f


# ────────────────────────── 어깨(Pauldron_L / _R · UpperTorso 로컬) ──────────────────────────
def shell_cap(rx, ry, rz, t, th_max, n=18, rings=6):
    """위가 둥근 껍데기(극 = 위) · 두께 t 닫힌 입체 · th_max = 극에서 내려오는 각"""
    outer, inner = [], []
    for k in range(1, rings + 1):
        th = th_max * (k / rings) ** 0.9
        ro, ri = [], []
        for i in range(n):
            ph = 2 * math.pi * i / n
            d = (math.sin(th) * math.cos(ph), math.cos(th), math.sin(th) * math.sin(ph))
            ro.append((rx * d[0], ry * d[1], rz * d[2]))
            ri.append(((rx - t) * d[0], (ry - t) * d[1], (rz - t) * d[2]))
        outer.append(ro)
        inner.append(ri)
    verts = [(0, ry, 0), (0, ry - t, 0)] + [p for r in outer for p in r] + [p for r in inner for p in r]
    o0, i0 = 2, 2 + rings * n
    faces = [(0, o0 + (i + 1) % n, o0 + i) for i in range(n)] + [(1, i0 + i, i0 + (i + 1) % n) for i in range(n)]
    for k in range(rings - 1):
        for i in range(n):
            j = (i + 1) % n
            faces.append((o0 + k * n + i, o0 + k * n + j, o0 + (k + 1) * n + j, o0 + (k + 1) * n + i))
            faces.append((i0 + k * n + j, i0 + k * n + i, i0 + (k + 1) * n + i, i0 + (k + 1) * n + j))
    k = rings - 1
    for i in range(n):
        j = (i + 1) % n
        faces.append((o0 + k * n + i, o0 + k * n + j, i0 + k * n + j, i0 + k * n + i))
    return verts, faces


def lame_band(r_top, r_bot, y_top, y_bot, span, t, n=12, ecc=1.06):
    """팔을 바깥에서 감싸는 원뿔대 조각(바깥 = +X 기준 ±span°) · 닫힌 입체"""
    def P(r, y, a, off):
        return ((r + off) * math.cos(a), y, (r + off) * ecc * math.sin(a))
    rows = []
    for r, y in ((r_top, y_top), (r_bot, y_bot)):
        rows.append([P(r, y, math.radians(-span + 2 * span * i / n), 0) for i in range(n + 1)])
        rows.append([P(r, y, math.radians(-span + 2 * span * i / n), -t) for i in range(n + 1)])
    (ot, it), (ob, ib) = (rows[0], rows[1]), (rows[2], rows[3])
    m = n + 1
    verts = ot + ob + it + ib
    faces = []
    for i in range(n):
        faces += [(i, i + 1, m + i + 1, m + i), (2 * m + i + 1, 2 * m + i, 3 * m + i, 3 * m + i + 1),
                  (2 * m + i, 2 * m + i + 1, i + 1, i), (m + i, m + i + 1, 3 * m + i + 1, 3 * m + i)]
    faces += [(0, m, 3 * m, 2 * m), (m - 1, 2 * m + m - 1, 3 * m + m - 1, m + m - 1)]
    return verts, faces


def band_rim(r, y, span, w, h, n=12, ecc=1.06):
    """겹판 아래 가장자리 금 테(둥근 단면 호)"""
    prof = [(-0.01, -w / 2), (h * 0.7, -w / 2), (h, 0), (h * 0.7, w / 2), (-0.01, w / 2)]
    rings = []
    for i in range(n + 1):
        a = math.radians(-span + 2 * span * i / n)
        rings.append([((r + dr) * math.cos(a), y + dy, (r + dr) * ecc * math.sin(a)) for dr, dy in prof])
    return sweep_faces(rings, False)


def xf(g, m=None, t=(0, 0, 0)):
    v, f = g
    out = []
    for p in v:
        q = Vector(p)
        if m is not None:
            q = m @ q
        out.append((q.x + t[0], q.y + t[1], q.z + t[2]))
    return out, f


def pauldron(side):
    """오른쪽(side +1) 기준으로 만들고 왼쪽은 X 거울. 큰 돔 + 겹판 2 + 금 테 · 마루 · 이끼 띠 · 호박 보석 · 리벳"""
    g = Geo()
    cx, cy = 1.44, 0.6
    tilt = Matrix.Rotation(math.radians(-11), 3, "Z")
    rx, ry, rz, th = 0.86, 0.58, 0.82, math.radians(110)

    def D(th_, ph, off=0.0):  # 돔 표면 점(로컬 → 기울임 → 자리)
        d = Vector((math.sin(th_) * math.cos(ph), math.cos(th_), math.sin(th_) * math.sin(ph)))
        p = Vector(((rx + off) * d.x, (ry + off) * d.y, (rz + off) * d.z))
        q = tilt @ p
        return (q.x + cx, q.y + cy, q.z)

    def place(gg):
        return xf(gg, tilt, (cx, cy, 0))
    g.add("enamel", place(shell_cap(rx, ry, rz, 0.07, th, n=16, rings=4)))
    # (돔 가장자리 금 테는 뺐다: 겹판 1이 돔 아래 가장자리를 덮어 앞 끝만 가시처럼 튀어나왔다 - 금 테 = 겹판 아래 테가 맡음)
    # 이끼 띠(세트 색1 = 천 띠 · 테두리): 돔 위를 앞뒤로 넘는 도톰한 띠(x 고정 작은 원) + 양옆 금 선
    def Dv(d, off):
        p = Vector(((rx + off) * d.x, (ry + off) * d.y, (rz + off) * d.z))
        q = tilt @ p
        return (q.x + cx, q.y + cy, q.z)
    for sx0, zone, w, hgt in ((0.0, "moss", 0.22, 0.04), (0.125, "gold", 0.035, 0.05), (-0.125, "gold", 0.035, 0.05)):
        rings = []
        for k in range(7):
            a_ = -th * 0.8 + 2 * th * 0.8 * k / 6
            row = []
            for dw, dh in ((-w / 2, -0.01), (-w / 2, hgt * 0.7), (0, hgt), (w / 2, hgt * 0.7), (w / 2, -0.01)):
                sx = sx0 + dw
                row.append(Dv(Vector((math.sin(sx), math.cos(sx) * math.cos(a_), math.cos(sx) * math.sin(a_))), dh))
            rings.append(row)
        g.add(zone, sweep_faces(rings, False))
    # 겹판 2(팔 바깥 감쌈) - 에나멜 / 에나멜2 번갈아 + 아래 금 테 + 리벳
    ax = 1.5
    for i, (yt, yb, r, span) in enumerate(((0.44, 0.16, 0.8, 122), (0.22, -0.08, 0.77, 112))):
        g.add("enamel2" if i == 0 else "enamel", xf(lame_band(r - 0.04, r, yt, yb, span, 0.05), None, (ax, 0, 0)))
        g.add("gold", xf(band_rim(r + 0.005, yb + 0.02, span, 0.06, 0.05), None, (ax, 0, 0)))
        for a in (-60, 0, 60):
            aa = math.radians(a)
            rr = r + 0.0
            g.add("gold", xf(rivet_at((rr * math.cos(aa), yb + 0.13, rr * 1.06 * math.sin(aa)), (math.cos(aa), 0.2, math.sin(aa)), n=6, rings=2, h=0.03), None, (ax, 0, 0)))
    # 호박 보석(돔 바깥 옆) + 금 받침
    gp = Vector(D(math.radians(62), 0.0, 0.0))
    nrm = (Vector(D(math.radians(62), 0.0, 0.1)) - gp).normalized()
    g.add("gold", rivet_at(tuple(gp - nrm * 0.02), tuple(nrm), r=0.13, h=0.05, n=12))
    g.add("gem", rivet_at(tuple(gp + nrm * 0.01), tuple(nrm), r=0.09, h=0.06, n=10, rings=3))
    if side < 0:
        g.parts = [(z, [(-x, y, zz) for x, y, zz in v], [tuple(reversed(f)) for f in fs]) for z, v, fs in g.parts]
    return g


def rivet_at(c, nrm, r=0.035, h=0.04, n=6, rings=2):
    nz = Vector(nrm).normalized()
    up = Vector((0, 1, 0)) if abs(nz.y) < 0.9 else Vector((1, 0, 0))
    u = up.cross(nz).normalized()
    v = nz.cross(u)
    verts = []
    prof = [(1.0, -0.01)] + [(math.cos(math.pi / 2 * k / rings), h * math.sin(math.pi / 2 * k / rings)) for k in range(rings)]
    for rr, hh in prof:
        for i in range(n):
            a = 2 * math.pi * i / n
            p = Vector(c) + u * (r * rr * math.cos(a)) + v * (r * rr * math.sin(a)) + nz * hh
            verts.append(tuple(p))
    verts.append(tuple(Vector(c) + nz * h))
    faces = []
    L = len(prof)
    for k in range(L - 1):
        for i in range(n):
            j = (i + 1) % n
            faces.append((k * n + i, k * n + j, (k + 1) * n + j, (k + 1) * n + i))
    cc = len(verts) - 1
    faces += [((L - 1) * n + i, (L - 1) * n + (i + 1) % n, cc) for i in range(n)]
    return verts, faces


def sweep_faces_closed_loop(rings):
    m = len(rings[0])
    nr = len(rings)
    verts = [p for r in rings for p in r]
    faces = []
    for r in range(nr):
        a, b = r * m, ((r + 1) % nr) * m
        for i in range(m):
            k = (i + 1) % m
            faces.append((a + i, a + k, b + k, b + i))
    return verts, faces


# ────────────────────────── 오브젝트 · UV(팔레트 칸 + 명암) ──────────────────────────
def orient(bm, ref):
    """연결 덩어리마다 법선 맞춤: 닫힌 덩어리 = recalc · 열린 덩어리(곡면에 붙은 판 · 테) = ref(점 → 방향)에서 바깥으로"""
    seen = set()
    for f0 in bm.faces:
        if f0.index in seen:
            continue
        region, stack = [], [f0]
        seen.add(f0.index)
        while stack:
            f = stack.pop()
            region.append(f)
            for e in f.edges:
                for g in e.link_faces:
                    if g.index not in seen:
                        seen.add(g.index)
                        stack.append(g)
        open_ = any(e.is_boundary for f in region for e in f.edges)
        bmesh.ops.recalc_face_normals(bm, faces=region)
        if open_:
            score = sum(f.calc_area() * f.normal.dot(ref(f.calc_center_median())) for f in region)
            if score < 0:
                bmesh.ops.reverse_faces(bm, faces=region)


def to_object(name, g, col, mat, ref):
    verts, faces, zones = [], [], []
    for zone, v, f in g.parts:
        base = len(verts)
        verts += v
        faces += [tuple(i + base for i in ff) for ff in f]
        zones += [zone] * len(f)
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(C @ Vector(p)) for p in verts], [], faces)
    mesh.validate()
    zi = mesh.attributes.new("zone", "INT", "FACE")
    for i, z in enumerate(zones):
        zi.data[i].value = ORDER.index(z)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.faces.ensure_lookup_table()
    bm.faces.index_update()
    orient(bm, ref)
    bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="BEAUTY")
    bm.to_mesh(mesh)
    bm.free()
    mesh.shade_smooth()
    mesh.set_sharp_from_angle(angle=math.radians(42))
    mesh.uv_layers.new(name="UVMap")
    obj = bpy.data.objects.new(name, mesh)
    col.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def bake_uv(objs, occluders):
    """UV u = 팔레트 칸 가운데 · v = 명암(반 램버트 빛 + 위쪽 빛 + 광선 AO + 볼록 모서리 하이라이트)"""
    light = (C @ Vector((-0.35, 1.0, -0.55))).normalized()
    up = Vector((0, 0, 1))
    trees = []
    for o in objs + occluders:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bm.transform(o.matrix_world)
        trees.append(BVHTree.FromBMesh(bm))
        bm.free()
    dirs = []
    K = 24
    for i in range(K):  # 반구 고른 방향(피보나치)
        zz = 1 - (i + 0.5) / K
        r = math.sqrt(1 - zz * zz)
        a = i * 2.39996
        dirs.append(Vector((r * math.cos(a), r * math.sin(a), zz)))
    for o in objs:
        me = o.data
        mw = o.matrix_world
        bm = bmesh.new()
        bm.from_mesh(me)
        bm.verts.ensure_lookup_table()
        ao, conv = [], []
        for v in bm.verts:
            p = mw @ v.co
            n = (mw.to_3x3() @ v.normal).normalized()
            t = n.orthogonal().normalized()
            b = n.cross(t)
            hit = 0
            for d in dirs:
                w = t * d.x + b * d.y + n * d.z
                for tr in trees:
                    loc, _, _, dist = tr.ray_cast(p + n * 0.006, w, 0.28)
                    if loc is not None:
                        hit += 1 - dist / 0.28 * 0.5
                        break
            ao.append(max(0.0, 1 - 1.15 * hit / K))
            c = 0.0
            for e in v.link_edges:
                d = (e.other_vert(v).co - v.co)
                if d.length > 1e-6:
                    c -= v.normal.dot(d.normalized())
            conv.append(c / max(1, len(v.link_edges)))
        bm.free()
        zone = me.attributes["zone"].data
        cn = me.corner_normals
        uv = me.uv_layers["UVMap"].data
        for poly in me.polygons:
            u = (ORDER.index(ORDER[zone[poly.index].value]) * COL_W + COL_W / 2) / PAL_RES
            for li in poly.loop_indices:
                vi = me.loops[li].vertex_index
                n = (mw.to_3x3() @ Vector(cn[li].vector)).normalized()
                lam = (n.dot(light) * 0.5 + 0.5) ** 1.3
                s = 0.12 + 0.62 * lam + 0.14 * max(0.0, n.dot(up))
                s *= 0.45 + 0.55 * ao[vi]
                s += max(0.0, min(0.16, conv[vi] * 0.9))
                uv[li].uv = (u, max(0.03, min(0.97, s)))


def palette_material(img):
    mat = bpy.data.materials.new("PilotA_Palette")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Linear"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.55
    bsdf.inputs["Metallic"].default_value = 0.0
    return mat


# ────────────────────────── 렌더용 마네킹(R15 블록 · UpperTorso 기준) ──────────────────────────
BODY = {"UpperTorso": ((0, 0, 0), (2, 1.6, 1)), "LowerTorso": ((0, -1.0, 0), (2, 0.4, 1)), "Head": ((0, 1.4, 0), (1.2, 1.2, 1.2)),
        "LeftUpperArm": ((-1.5, 0.22, 0), (1, 1.17, 1)), "RightUpperArm": ((1.5, 0.22, 0), (1, 1.17, 1)),
        "LeftLowerArm": ((-1.5, -0.89, 0), (1, 1.05, 1)), "RightLowerArm": ((1.5, -0.89, 0), (1, 1.05, 1)),
        "LeftHand": ((-1.5, -1.57, 0), (1, 0.3, 1)), "RightHand": ((1.5, -1.57, 0), (1, 0.3, 1)),
        "LeftUpperLeg": ((-0.5, -1.8, 0), (1, 1.22, 1)), "RightUpperLeg": ((0.5, -1.8, 0), (1, 1.22, 1))}


def mannequin(col):
    out = []
    for nm, (c, s) in BODY.items():
        bpy.ops.mesh.primitive_cube_add(size=1)
        o = bpy.context.active_object
        o.name = "Dummy_" + nm
        o.scale = (s[0], s[2], s[1])
        o.location = tuple(C @ Vector(c))
        bv = o.modifiers.new("b", "BEVEL")
        bv.width = 0.08
        bv.segments = 3
        for c2 in o.users_collection:
            c2.objects.unlink(o)
        col.objects.link(o)
        m = bpy.data.materials.new("Dummy_" + nm)
        rgb = (232, 196, 160) if nm == "Head" else (43, 53, 80)  # 머리 = 피부 · 몸 = 바닥층 천(대검 진남색 #2B3550)
        m.diffuse_color = tuple(((c3 / 255) ** 2.2) for c3 in rgb) + (1,)
        m.use_nodes = True
        m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = m.diffuse_color
        m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.8
        o.data.materials.append(m)
        out.append(o)
    return out


def setup_render():
    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            sc.render.engine = eng
            break
        except TypeError:
            continue
    sc.render.resolution_x = sc.render.resolution_y = 1024
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "Standard"
    w = bpy.data.worlds.new("W")
    sc.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.56, 0.6, 1)
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
    for nm, rot, e in (("Key", (52, 0, -35), 3.2), ("Rim", (60, 0, 150), 1.6)):
        ld = bpy.data.lights.new(nm, "SUN")
        ld.energy = e
        lo = bpy.data.objects.new(nm, ld)
        lo.rotation_euler = tuple(math.radians(a) for a in rot)
        sc.collection.objects.link(lo)
    cd = bpy.data.cameras.new("Cam")
    cd.type = "ORTHO"
    cd.ortho_scale = 4.9
    cam = bpy.data.objects.new("Cam", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    return cam


def aim(cam, target, yaw, pitch, dist=30):
    y, p = math.radians(yaw), math.radians(pitch)
    d = Vector((math.sin(y) * math.cos(p), math.cos(y) * math.cos(p), math.sin(p)))
    cam.location = target + d * dist
    f = -d
    right = f.cross(Vector((0, 0, 1))).normalized()
    upv = right.cross(f).normalized()
    cam.rotation_euler = Matrix((right, upv, -f)).transposed().to_euler()


def main():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    col = bpy.data.collections.new("PilotA")
    bpy.context.scene.collection.children.link(col)
    dcol = bpy.data.collections.new("Dummy")
    bpy.context.scene.collection.children.link(dcol)
    img = palette_image(os.path.join(OUT, "pilotA_palette.png"))
    mat = palette_material(img)
    t1 = time.time()
    radial = lambda c: Vector((c.x, c.y, 0)).normalized()  # noqa: E731 - 몸통 축(Blender Z)에서 바깥
    arm = lambda sx: (lambda c: (c - Vector((sx * 1.4, 0, 0.3))).normalized())  # noqa: E731
    objs = [to_object("Chest", chest(), col, mat, radial), to_object("Pauldron_L", pauldron(-1), col, mat, arm(-1)),
            to_object("Pauldron_R", pauldron(1), col, mat, arm(1))]
    dummy = mannequin(dcol)
    bpy.context.view_layer.update()
    bake_uv(objs, dummy)
    tris = {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs}
    print("[pilotA] tris", tris, "total", sum(tris.values()), "build %.1fs" % (time.time() - t1))
    meta = {"attach": "UpperTorso", "refSize": [2, 1.6, 1], "tris": tris, "total": sum(tris.values()), "pieces": {}}
    for o in objs:
        pts = [o.matrix_world @ v.co for v in o.data.vertices]
        lo = Vector([min(p[i] for p in pts) for i in range(3)])
        hi = Vector([max(p[i] for p in pts) for i in range(3)])
        cen = C.transposed() @ ((lo + hi) / 2)
        size = C.transposed() @ (hi - lo)
        meta["pieces"][o.name] = {"offset": [round(c, 4) for c in cen], "size": [round(abs(c), 4) for c in size]}
    with open(os.path.join(OUT, "pilotA.meta.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=1)
    if "--export" in ARGS:
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, "pilotA_armor_greatsword_legendary_stoneplains.fbx"), use_selection=True, object_types={"MESH"},
                                 global_scale=1.0, apply_unit_scale=True, apply_scale_options="FBX_SCALE_NONE", axis_forward="-Z", axis_up="Y",
                                 bake_space_transform=True, use_mesh_modifiers=False, mesh_smooth_type="OFF", add_leaf_bones=False, bake_anim=False,
                                 path_mode="STRIP", embed_textures=False)
    if "--render" in ARGS:
        cam = setup_render()
        target = C @ Vector((0, 0.35, 0))
        rdir = os.path.join(OUT, "renders")
        os.makedirs(rdir, exist_ok=True)
        for nm, yaw, pitch in (("front", 0, 6), ("34", 38, 12), ("side", 90, 6), ("back", 180, 6)):
            aim(cam, target, yaw, pitch)
            bpy.context.scene.render.filepath = os.path.join(rdir, "pilotA_%s.png" % nm)
            bpy.ops.render.render(write_still=True)
    img.filepath = "//pilotA_palette.png"
    bpy.context.preferences.filepaths.save_version = 0  # .blend1 백업 안 남김
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "pilotA_armor_greatsword_legendary_stoneplains.blend"))
    print("[pilotA] done %.1fs" % (time.time() - T0))


main()
