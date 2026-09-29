# -*- coding: utf-8 -*-
# A2-N1 맵 요소 · 소품(Blender bpy): 강화대(forge) · 보스 관문 공통 틀(boss_gate) · 환생 제단(rebirth_altar) + 구역 소품 키트(PROPS에 추가).
#   파트 이름 = 지금 코드의 파트 이름(ArtV1Models.forge · BossGateKit.frame · HuntingGround.createRebirthAltar) · 원점 = 그 파트의 자리(모델 로컬 - 바닥 y 0 · −Z 앞).
#   같은 이름이 여럿인 파트(관문 GateStep 2개 등)는 _1 · _2 / _L · _R를 붙인다(가져올 때 이름 표 = 메타 "codeName").
#   이전 버전 = 같은 표의 상자 · 원기둥 · 쐐기(OLD 표)로 짓는다(--old).
# 실행: bash bl.sh make_props.py --items forge[,boss_gate ...] [--render 폴더] [--old] [--no-export]
import bpy
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import artlib as A  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "art", "props"))


def C(r, g, b):
    return (r, g, b)


# ────────────────────────── 강화대(ArtV1Models.forge · 배율 전 로컬) ──────────────────────────
FD = dict(wood=C(104, 66, 40), woodTop=C(140, 96, 58), iron=C(78, 82, 100), ironTop=C(150, 156, 176), ironShade=C(52, 54, 68),
          stone=C(156, 96, 70), stoneShade=C(104, 64, 54), ember=C(255, 140, 50), ingot=C(255, 170, 60), sign=C(255, 230, 90), signBoard=C(96, 62, 40))
# 이전(도형) 표: 이름 → (크기, 색, 자리, 모양, Z 회전(도))
FORGE_OLD = [
    ("Stump", (1.7, 3.3, 3.3), FD["wood"], (0, 0.85, 0), "cyl_y", 0), ("StumpTop", (0.18, 3.5, 3.5), FD["woodTop"], (0, 1.78, 0), "cyl_y", 0),
    ("AnvilFoot", (1.9, 0.6, 1.4), FD["ironShade"], (0, 2.15, 0), "box", 0), ("AnvilWaist", (1.0, 0.7, 0.85), FD["iron"], (0, 2.8, 0), "box", 0),
    ("AnvilFace", (3.0, 0.72, 1.5), FD["iron"], (0.2, 3.5, 0), "box", 0), ("AnvilTopShine", (3.0, 0.08, 1.5), FD["ironTop"], (0.2, 3.9, 0), "box", 0),
    ("AnvilHorn", (1.5, 0.72, 1.2), FD["iron"], (-1.9, 3.5, 0), "horn", 0), ("HotIngot", (0.9, 0.22, 0.5), FD["ingot"], (0.5, 4.05, 0), "box", 0),
    ("HammerHandle", (0.2, 1.8, 0.2), FD["wood"], (2.05, 2.6, -0.4), "box", -18), ("HammerHead", (0.9, 0.5, 0.5), FD["ironShade"], (2.35, 3.45, -0.4), "box", -18),
    ("Hearth", (3.2, 2.4, 2.4), FD["stone"], (0, 1.2, 3.4), "box", 0), ("HearthTop", (3.4, 0.35, 2.6), FD["stoneShade"], (0, 2.55, 3.4), "box", 0),
    ("HearthMouth", (1.7, 0.9, 0.12), FD["ember"], (0, 1.05, 2.18), "box", 0), ("Chimney", (1.3, 6.2, 1.3), FD["stoneShade"], (0.6, 5.8, 3.7), "box", 0),
    ("ChimneyCap", (1.8, 0.4, 1.8), FD["ironShade"], (0.6, 9.1, 3.7), "box", 0), ("ChimneyGlow", (1.0, 0.2, 1.0), FD["ember"], (0.6, 9.35, 3.7), "box", 0),
    ("SignPole", (0.35, 7.2, 0.35), FD["wood"], (-2.9, 3.6, 1.2), "box", 0), ("SignBoard", (2.4, 1.7, 0.25), FD["signBoard"], (-2.9, 6.2, 1.0), "box", 0),
    ("EmblemHandle", (0.22, 1.1, 0.1), FD["sign"], (-2.9, 6.05, 0.83), "box", -35), ("EmblemHead", (0.95, 0.42, 0.1), FD["sign"], (-2.62, 6.5, 0.83), "box", -35),
]
NEON = {"HotIngot", "HearthMouth", "ChimneyGlow", "EmblemHandle", "EmblemHead", "Orb", "BossGateTrim", "Crystal"}


def old_geo(size, pos, shape, rz):
    sx, sy, sz = size
    if shape == "cyl_y":
        g = A.lathe([(0.0, -sx / 2), (sy / 2, -sx / 2), (sy / 2, sx / 2), (0.0, sx / 2)], 14)
    elif shape == "horn":  # 뒤집은 쐐기(−X로 뾰족 · 윗면 평평)
        v = [(sx / 2, sy / 2, -sz / 2), (sx / 2, sy / 2, sz / 2), (-sx / 2, sy / 2, -sz / 2), (-sx / 2, sy / 2, sz / 2), (sx / 2, -sy / 2, -sz / 2), (sx / 2, -sy / 2, sz / 2)]
        g = (v, [(0, 2, 3, 1), (0, 1, 5, 4), (2, 0, 4), (1, 3, 5), (2, 4, 5, 3)])
    elif shape == "ball":
        g = A.ellipsoid((sx / 2, sy / 2, sz / 2), n=14, rings=8)
    elif shape == "wedge":
        v = [(-sx / 2, -sy / 2, -sz / 2), (sx / 2, -sy / 2, -sz / 2), (sx / 2, -sy / 2, sz / 2), (-sx / 2, -sy / 2, sz / 2), (-sx / 2, sy / 2, sz / 2), (sx / 2, sy / 2, sz / 2)]
        g = (v, [(0, 1, 2, 3), (3, 2, 5, 4), (0, 4, 5, 1), (0, 3, 4), (1, 5, 2)])
    else:
        g = A.box(sx, sy, sz)
    return A.xform(g, m=A.rot(rz=rz), t=pos)


def forge_parts():
    F = FD
    out = {}
    # 그루터기: 뿌리가 퍼진 밑동 + 나이테 윗면(홈 한 줄)
    prof = [(0.0, 0.0), (2.05, 0.0), (1.85, 0.18), (1.66, 0.55), (1.6, 1.2), (1.64, 1.62), (1.5, 1.7), (0.0, 1.7)]
    stump = A.lathe(prof, 20)
    roots = [A.tube([(1.3 * math.cos(a), 0.9, 1.3 * math.sin(a)), (1.9 * math.cos(a), 0.25, 1.9 * math.sin(a)), (2.35 * math.cos(a), 0.05, 2.35 * math.sin(a))], lambda u: 0.36 * (1 - u) + 0.1, sides=6, tip_end=True)
             for a in (math.radians(d) for d in (20, 140, 250, 320))]
    out["Stump"] = A.merge(stump, *roots)
    out["StumpTop"] = A.lathe([(0.0, 1.69), (1.62, 1.69), (1.68, 1.8), (1.2, 1.87), (1.15, 1.83), (0.8, 1.84), (0.0, 1.87)], 20)
    # 모루: 퍼진 발 · 잘록한 허리 · 두툼한 얼굴(뒤꿈치 쪽 단) · 과장된 곡선 뿔(−X)
    out["AnvilFoot"] = _yloft([(1.85, 2.2, 1.6, 0.14), (2.25, 1.75, 1.28, 0.12), (2.45, 1.15, 0.92, 0.1)])
    out["AnvilWaist"] = _yloft([(2.4, 1.15, 0.92, 0.1), (2.8, 0.85, 0.72, 0.1), (3.18, 1.3, 1.05, 0.1)])
    out["AnvilFace"] = _xloft([(-1.25, 0.62, 1.38, 3.48), (1.35, 0.72, 1.5, 3.5), (1.75, 0.5, 1.3, 3.57)], 0.12)
    out["AnvilTopShine"] = A.box(2.9, 0.08, 1.36, b=0.03, center=(0.15, 3.88, 0))
    horn_path = A.bezier((-1.2, 3.55, 0), (-1.9, 3.5, 0), (-2.6, 3.52, 0), (-3.15, 3.85, 0), n=9)
    out["AnvilHorn"] = A.tube(horn_path, lambda u: 0.44 * (1 - u) ** 0.9 + 0.03, sides=8, flat=0.85, tip_end=True)
    out["HotIngot"] = A.xform(A.box(0.95, 0.24, 0.5, b=0.08), m=A.rot(ry=12), t=(0.5, 4.05, 0))
    out["AnvilHorn"] = _scale_about(out["AnvilHorn"], 1.15, (-1.2, 3.55, 0))  # 모루 ×1.2와 합쳐 ≈ 1.4배
    for n_ in ("AnvilFoot", "AnvilWaist", "AnvilFace", "AnvilTopShine", "AnvilHorn", "HotIngot"):  # 주인공 = 모루 ×1.2(발바닥 = 그루터기 윗면 고정)
        out[n_] = _scale_about(out[n_], 1.2, (0.2, 1.85, 0))
    out["HammerHandle"] = A.xform(A.tube([(0, -0.95, 0), (0, 0.0, 0), (0, 0.9, 0)], lambda u: 0.13 - 0.04 * u, sides=6), m=A.rot(rz=-18), t=(2.05, 2.6, -0.4))
    head = A.loft([[(x, yy, zz) for yy, zz in A.chamfer_rect(w, w, 0.08)] for x, w in ((-0.5, 0.58), (-0.28, 0.46), (0.28, 0.46), (0.5, 0.62))])  # 양 끝 넓은 망치 머리
    out["HammerHead"] = A.xform(head, m=A.rot(rz=-18), t=(2.35, 3.45, -0.4))
    # 벽돌 화덕: 아래 넓고 위로 좁아지는 돔형 상자 · 벽돌 줄(단마다 살짝 튀어나옴)
    hs = []
    for k in range(7):
        y0, y1 = 0.343 * k, 0.343 * (k + 1)
        w = 4.6 - 0.08 * k
        d = 2.5 - 0.045 * k
        hs.append((y0, w, d, 0.2))
        hs.append((y1 - 0.06, w + 0.08, d + 0.08, 0.2))
    out["Hearth"] = A.xform(_yloft(hs), t=(0, 0, 3.4))
    out["HearthTop"] = A.box(4.75, 0.38, 2.75, b=0.12, center=(0, 2.55, 3.4))
    arch = [(0.85 * math.cos(math.pi * i / 8), 0.12 + 0.95 * math.sin(math.pi * i / 8)) for i in range(9)] + [(-0.85, -0.45), (0.85, -0.45)]
    out["HearthMouth"] = _extrude_xy(arch, 0.14, (0, 1.05 - 0.2, 2.16))
    # 굴뚝: 테이퍼 + 살짝 기욺(4°) + 벽돌 띠 2
    cs = [(y * 0.8, w, d, b) for y, w, d, b in ((0.0, 1.6, 1.6, 0.12), (2.0, 1.46, 1.46, 0.12), (2.1, 1.6, 1.6, 0.12), (2.3, 1.46, 1.46, 0.12), (4.3, 1.32, 1.32, 0.12), (4.4, 1.46, 1.46, 0.12), (4.6, 1.32, 1.32, 0.12), (6.2, 1.22, 1.22, 0.1))]
    lean = 8.0  # 굴뚝 높이 −20% · 8° 기욺(곡선 대신 한쪽 과장)
    top = 2.7 + 6.2 * 0.8
    dx = lambda y: (y - 2.7) * math.tan(math.radians(lean))
    out["Chimney"] = A.xform(_yloft(cs), m=A.rot(rz=-lean), t=(0.6, 2.7, 3.7))
    out["ChimneyCap"] = A.xform(_yloft([(0.0, 1.45, 1.45, 0.1), (0.18, 2.05, 2.05, 0.12), (0.42, 1.9, 1.9, 0.12)]), m=A.rot(rz=-lean), t=(0.6 + dx(top - 0.3), top - 0.3, 3.7))
    out["ChimneyGlow"] = A.xform(A.lathe([(0.0, 0.0), (0.55, 0.0), (0.46, 0.18), (0.0, 0.26)], 8), m=A.rot(rz=-lean), t=(0.6 + dx(top + 0.1), top + 0.1, 3.7))
    pole = A.tube([(-2.9, 0.0, 1.2), (-2.95, 3.5, 1.2), (-2.88, 7.1, 1.2)], lambda u: 0.39 - 0.15 * u, sides=6)
    arm = A.tube([(-2.88, 7.0, 1.2), (-2.9, 7.05, 0.6)], 0.1, sides=5)
    out["SignPole"] = A.merge(pole, arm)
    shield = [(-1.2, 0.85), (1.2, 0.85), (1.15, -0.2), (0.7, -0.7), (0.0, -0.95), (-0.7, -0.7), (-1.15, -0.2)]
    out["SignBoard"] = _extrude_xy(shield, 0.14, (-2.9, 6.2, 1.0))
    out["EmblemHandle"] = A.xform(_extrude_xy([(-0.11, -0.55), (0.11, -0.55), (0.1, 0.55), (-0.1, 0.55)], 0.06), m=A.rot(rz=-35), t=(-2.9, 6.05, 0.82))
    out["EmblemHead"] = A.xform(_extrude_xy([(-0.5, -0.2), (0.5, -0.24), (0.55, 0.24), (-0.46, 0.2), (-0.56, 0.0)], 0.07), m=A.rot(rz=-35), t=(-2.62, 6.5, 0.8))
    colors = {n: c for n, _, c, _, _, _ in FORGE_OLD}
    origins = {n: p for n, _, _, p, _, _ in FORGE_OLD}
    return [(n, out[n], colors[n], origins[n]) for n, *_ in FORGE_OLD]


def _scale_about(geo, k, c):
    v, f = geo
    return [(c[0] + (x - c[0]) * k, c[1] + (y - c[1]) * k, c[2] + (z - c[2]) * k) for x, y, z in v], f


def _yloft_dx(stations):
    """세로 로프트 + 단마다 X 이동: [(y, w, d, b, dx), ...]"""
    rings = [[(x + dx, y, z) for x, z in A.chamfer_rect(w, d, b)] for y, w, d, b, dx in stations]
    return A.loft(rings)


def _yloft(stations):
    """세로(Y) 로프트: stations = [(y, 가로 w, 깊이 d, 모따기 b), ...] 아래 → 위"""
    rings = [[(x, y, z) for x, z in A.chamfer_rect(w, d, b)] for y, w, d, b in stations]
    return A.loft(rings)


def _xloft(stations, b):
    """가로(X) 로프트: stations = [(x, 높이 h, 깊이 d, 가운데 y), ...]"""
    rings = [[(x, cy + yy, zz) for zz, yy in A.chamfer_rect(d, h, b)] for x, h, d, cy in stations]
    return A.loft(rings)


def _extrude_xy(outline, depth, center=(0, 0, 0)):
    """XY 윤곽(반시계)을 Z로 두께 depth만큼 밀어낸 판"""
    n = len(outline)
    v = [(x, y, depth / 2) for x, y in outline] + [(x, y, -depth / 2) for x, y in outline]
    f = [tuple(range(n)), tuple(reversed(range(n, 2 * n)))]
    for i in range(n):
        j = (i + 1) % n
        f.append((i, n + i, n + j, j))
    return A.xform((v, f), t=center)


# ────────────────────────── 보스 관문 공통 틀(BossGateKit.frame 돌 부분 - 빛 테 · 문양 · 막 · 발판은 코드 파트 그대로) ──────────────────────────
GD = dict(width=40, height=44, P=8, beam=7, emblem=9)
GATE_STONE, GATE_LIGHT, GATE_DARK = (120, 118, 124), (168, 166, 172), (74, 70, 86)  # 렌더용(실제 색 = 보스 색이 스민 돌 - 코드가 칠한다)


def gate_layout():
    W, H, P, BEAM, EM = GD["width"], GD["height"], GD["P"], GD["beam"], GD["emblem"]
    half = W / 2
    beamY = H + BEAM / 2 + 1
    gableH, gableW = 11, (W + P + 10) / 2
    keyY = beamY + BEAM / 2 + 1.4 + gableH * 0.45
    return dict(W=W, H=H, P=P, BEAM=BEAM, EM=EM, half=half, beamY=beamY, gableH=gableH, gableW=gableW, keyY=keyY)


def gate_old():
    L = gate_layout()
    W, H, P, BEAM, half, beamY = L["W"], L["H"], L["P"], L["BEAM"], L["half"], L["beamY"]
    items = [("GateStep_1", (W + P + 16, 1.2, P + 14), GATE_STONE, (0, 0.1, 0), "box", 0), ("GateStep_2", (W + P + 8, 1.2, P + 8), GATE_LIGHT, (0, 1.0, 0), "box", 0)]
    for tag, sx in (("L", -1), ("R", 1)):
        x = sx * half
        items += [("BossGatePostBase_" + tag, (P + 4, 4, P + 4), GATE_STONE, (x, 3.6, 0), "box", 0), ("BossGatePost_" + tag, (P, H - 5, P), GATE_DARK, (x, 1.6 + (H - 1.6) / 2 + 1, 0), "box", 0),
                  ("BossGatePostBand_" + tag, (P + 1.2, 1.6, P + 1.2), GATE_LIGHT, (x, H * 0.55, 0), "box", 0), ("BossGateCapital_" + tag, (P + 3, 3, P + 3), GATE_STONE, (x, H - 0.5, 0), "box", 0)]
    items += [("BossGateTop", (W + P + 8, BEAM, P + 3), GATE_DARK, (0, beamY, 0), "box", 0), ("BossGateCornice", (W + P + 12, 1.4, P + 5), GATE_LIGHT, (0, beamY + BEAM / 2 + 0.7, 0), "box", 0),
              ("BossGateKeystone", (L["EM"] + 4, L["EM"] + 4, P + 3), GATE_DARK, (0, L["keyY"], 0), "box", 45)]
    gw, gh = L["gableW"], L["gableH"]
    for tag, sx in (("L", -1), ("R", 1)):  # 박공 = 쐐기(높은 쪽 가운데) - 이전 버전 근사
        items.append(("BossGateGable_" + tag, (gw, gh, P + 2), GATE_STONE, (sx * gw / 2, beamY + BEAM / 2 + 1.4 + gh / 2, 0), "gable%d" % sx, 0))
    return items


def gate_parts():
    L = gate_layout()
    W, H, P, BEAM, half, beamY, gw, gh = L["W"], L["H"], L["P"], L["BEAM"], L["half"], L["beamY"], L["gableW"], L["gableH"]
    out = {}
    out["GateStep_1"] = _yloft([(-0.5, W + P + 16, P + 14, 1.2), (0.7, W + P + 15, P + 13, 1.0)])
    out["GateStep_2"] = _yloft([(0.4, W + P + 8, P + 8, 1.0), (1.6, W + P + 7, P + 7, 0.8)])
    for tag, sx in (("L", -1), ("R", 1)):
        x = sx * half
        out["BossGatePostBase_" + tag] = A.xform(_yloft([(1.6, P + 5, P + 5, 1.2), (3.2, P + 4.2, P + 4.2, 1.0), (4.4, P + 3, P + 3, 0.9), (5.6, P + 2, P + 2, 0.7)]), t=(x, 0, 0))
        # 기둥: 돌 드럼 5단(단마다 조금씩 좁아지고 살짝 어긋남 = 손으로 쌓은 돌) · 밑동 넓게 - 오른쪽 기둥만 금 간 홈(비대칭)
        drums = []
        y0, y1 = 5.2, H - 1.6
        for k in range(5):
            a0 = y0 + (y1 - y0) * k / 5
            a1 = y0 + (y1 - y0) * (k + 1) / 5
            w0 = P + 2.4 - 3.9 * k / 5  # 밑동 10.4 → 위 6.5(1.6배 테이퍼)
            w1 = P + 2.4 - 3.9 * (k + 1) / 5
            off = 0.25 * math.sin(k * 2.3 + sx)
            st = [(a0 + 0.12, w0 - 0.5, w0 - 0.5, 0.6, 0), (a0 + 0.45, w0, w0, 0.8, 0), (a1 - 0.45, w1 + 0.1, w1 + 0.1, 0.8, 0), (a1 - 0.12, w1 - 0.5, w1 - 0.5, 0.6, 0)]
            if sx > 0 and k == 2:  # 오른쪽 기둥 가운데 드럼: 바깥(+X) 모서리만 V자로 파인 금(실루엣 비대칭)
                am, wm = (a0 + a1) / 2, (w0 + w1) / 2
                st = st[:2] + [(am - 2.2, wm, wm, 0.8, 0), (am, wm - 3.6, wm, 0.6, -1.8), (am + 1.4, wm, wm, 0.8, 0)] + st[2:]
            drums.append(A.xform(_yloft_dx([(y_, w_, d_, b_, dx_ - sx * 0.035 * (y_ - 5.2)) for y_, w_, d_, b_, dx_ in st]), m=A.rot(ry=4 * math.sin(k * 1.7)), t=(x + off, 0, 0)))  # 위로 갈수록 안쪽으로 2° 기욺(사다리꼴 문)
        g = A.merge(*drums)
        if sx > 0:
            crack = A.tube([(x - P / 2 + 0.2, H * 0.72, -P / 2 - 0.4), (x - P / 2 + 1.4, H * 0.64, -P / 2 - 0.4), (x - P / 2 + 0.9, H * 0.55, -P / 2 - 0.4), (x - P / 2 + 2.3, H * 0.44, -P / 2 - 0.4)], 0.45, sides=4, flat=0.5)
            g = A.merge(g, crack)
        out["BossGatePost_" + tag] = g
        out["BossGatePostBand_" + tag] = A.xform(_yloft([(H * 0.55 - 0.9, P + 1.0, P + 1.0, 0.4), (H * 0.55, P + 1.6, P + 1.6, 0.5), (H * 0.55 + 0.9, P + 1.0, P + 1.0, 0.4)]), t=(x, 0, 0))
        out["BossGateCapital_" + tag] = A.xform(_yloft([(H - 2.0, P - 0.6, P - 0.6, 0.6), (H - 0.9, P + 3.4, P + 3.4, 1.0), (H + 1.0, P + 3.2, P + 3.2, 1.0)]), t=(x, 0, 0))
    # 들보: 가운데가 솟은 아치 곡선(아래면이 휨)
    # 들보: 아랫면이 크게 휜 아치(가운데 4.5 솟음) · 쐐기돌 줄눈(7마디 - 마디 경계가 살짝 파임)
    n = 22
    rings = []
    span = W + P + 8
    for i in range(n):
        u = i / (n - 1)
        x = -span / 2 + span * u
        lift = 7.0 * math.sin(math.pi * u) ** 0.8
        groove = 0.35 if (i % 3 == 0 and 0 < i < n - 1) else 0.0
        sec = A.chamfer_rect(P + 3 - groove, BEAM, 0.9)
        rings.append([(x, beamY + yy + (lift * (0.5 - yy / BEAM) if yy < 0 else 0), zz) for zz, yy in sec])
    out["BossGateTop"] = A.loft(rings)
    # 처마: 양 끝이 위로 들린 곡선 판(관문 실루엣의 주인공 - 멀리서도 "보스 문")
    cn = 16
    cspan = W + P + 16
    cst = []
    for i in range(cn):
        u = i / (cn - 1)
        e = abs(2 * u - 1)
        cst.append((-cspan / 2 + cspan * u, 1.8 + 1.2 * e ** 3, P + 5, 3.2 * e ** 3))
    out["BossGateCornice"] = A.xform(_xloft(cst, 0.5), t=(0, beamY + BEAM / 2 + 0.7, 0))
    base = beamY + BEAM / 2 + 1.4
    for tag, sx in (("L", -1), ("R", 1)):
        # 박공 반쪽: 바깥 낮고 가운데 높은 삼각 판(두께 P+2) - 처마 끝이 살짝 들림(곡선)
        outline = [(0.0, base), (sx * gw, base), (sx * (gw + 0.8), base + 1.4), (sx * gw * 0.5, base + gh * 0.62), (0.0, base + gh)]
        if sx < 0:
            outline = list(reversed(outline))
        ridge = A.tube([(0.0, base + gh + 0.4, 0), (sx * gw * 0.5, base + gh * 0.62 + 0.5, 0), (sx * (gw + 0.8), base + 1.9, 0)], 0.75, sides=6, flat=1.6)  # 용마루(처마 끝까지 굵은 테)
        out["BossGateGable_" + tag] = A.merge(_extrude_xy(outline, P + 2), ridge)
    k_ = L["EM"] + 4
    key = _extrude_xy([(0, k_ * 0.72), (k_ * 0.62, 0), (0, -k_ * 0.8), (-k_ * 0.62, 0)], P + 3.5)
    face = _extrude_xy([(0, k_ * 0.5), (k_ * 0.42, 0), (0, -k_ * 0.56), (-k_ * 0.42, 0)], 1.4, (0, 0, -(P + 3.5) / 2 - 0.6))  # 앞으로 튀어나온 마름모 면(두 겹)
    out["BossGateKeystone"] = A.xform(A.merge(key, face), t=(0, L["keyY"], 0))
    old = {n_: (c, p) for n_, _, c, p, _, _ in gate_old()}
    return [(n_, out[n_], old[n_][0], old[n_][1]) for n_ in old]


def gate_old_geo(name, size, pos, shape, rz):
    if shape.startswith("gable"):
        sx_ = int(shape[5:])
        w, h, d = size
        v = [(-w / 2, -h / 2, -d / 2), (w / 2, -h / 2, -d / 2), (w / 2, -h / 2, d / 2), (-w / 2, -h / 2, d / 2)]
        hx = -sx_ * w / 2  # 높은 쪽 = 가운데
        v += [(hx, h / 2, -d / 2), (hx, h / 2, d / 2)]
        f = [(0, 1, 2, 3), (0, 3, 5, 4) if hx < 0 else (1, 4, 5, 2), (0, 4, 1) if hx < 0 else (0, 4, 1), (3, 2, 5), (1, 2, 5, 4) if hx < 0 else (0, 3, 5, 4)]
        return A.xform((v, f), t=pos)
    return old_geo(size, pos, shape, rz)


# ────────────────────────── 환생 제단(HuntingGround.createRebirthAltar - 바닥 y 0 로컬) ──────────────────────────
ALTAR_OLD = [("Base", (5, 2, 5), (90, 90, 100), (0, 1, 0), "box", 0), ("Orb", (2.6, 2.6, 2.6), (160, 130, 60), (0, 3.6, 0), "ball", 0)]


def altar_parts():
    # 3단 원형 계단 + 가운데 받침(Base 한 메시) · 떠 있는 결정(Orb - 이름 유지 · 프롬프트가 붙는다) · 순환 고리(Ring - 새 장식 파트)
    prof = [(0.0, 0.0), (2.9, 0.0), (2.9, 0.45), (2.3, 0.5), (2.3, 0.95), (1.7, 1.0), (1.7, 1.45), (1.05, 1.5), (0.8, 1.7), (0.95, 2.05), (0.6, 2.15), (0.0, 2.15)]
    base = A.lathe(prof, 28)
    orb = A.crystal(1.75, 0.85, sides=8, tip_h=0.6, base_h=0.45, center=(0, 3.6, 0))  # 결정 높이 −35%(덩어리 비율 = 작은 것)
    n = 24
    R = 1.9  # 고리 지름 = 결정 폭의 2.2배 · 15° 기울임
    ring_path = [(R * math.cos(2 * math.pi * i / n), 0.0, R * math.sin(2 * math.pi * i / n)) for i in range(n + 1)]
    ring = A.tube(ring_path, 0.22, sides=6, cap0=False, flat=1.5)
    runes = [A.crystal(0.62, 0.2, sides=4, tip_h=0.22, base_h=0.16, center=(R * math.cos(a), 0.0, R * math.sin(a))) for a in (0.3, 2.4, 4.4)]
    ring = A.xform(A.merge(ring, *runes), m=A.rot(rx=15, rz=-8), t=(0, 3.6, 0))
    return [("Base", base, (230, 226, 240), (0, 1, 0)), ("Orb", orb, (140, 110, 230), (0, 3.6, 0)), ("Ring", ring, (140, 110, 230), (0, 3.6, 0))]


ITEMS = {"forge": dict(parts=forge_parts, old=lambda: FORGE_OLD, budget=3000, partCap=24),
         "boss_gate": dict(parts=gate_parts, old=gate_old, budget=3000, partCap=30),
         "rebirth_altar": dict(parts=altar_parts, old=lambda: ALTAR_OLD, budget=1500, partCap=8)}


def build(item, old=False):
    col = A.new_collection(("old_" if old else "") + item)
    objs = []
    if old:
        for name, size, rgb, pos, shape, rz in ITEMS[item]["old"]():
            g = gate_old_geo(name, size, pos, shape, rz) if item == "boss_gate" else old_geo(size, pos, shape, rz)
            objs.append(A.make_obj(name, g, rgb, col, neon=name.split("_")[0] in NEON, origin=pos, mat_name="old_%s_%s" % (item, name)))
    else:
        for name, g, rgb, origin in ITEMS[item]["parts"]():
            objs.append(A.make_obj(name, g, rgb, col, neon=name.split("_")[0] in NEON, origin=origin, bevel=0.0, mat_name="%s_%s" % (item, name)))
    return col, objs


def parse():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opt = {"items": [], "render": None, "export": True, "old": False}
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--items":
            opt["items"] = argv[i + 1].split(","); i += 1
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
    for item in opt["items"]:
        A.reset()
        col, objs = build(item)
        total = sum(A.tri_count(o) for o in objs)
        cfg = ITEMS[item]
        print("[make_props] %s 파트 %d(상한 %d) · 삼각형 %d / %d = %.0f%% · %s" % (item, len(objs), cfg["partCap"], total, cfg["budget"], 100 * total / cfg["budget"], {o.name: A.tri_count(o) for o in objs}))
        if opt["export"]:
            A.export_fbx(os.path.join(OUT, "%s.fbx" % item), objs)
            meta = A.meta_of(objs, cfg["budget"], {"version": "A2-N1", "item": item, "partCap": cfg["partCap"]})
            for n_, p in meta["parts"].items():
                p["codeName"] = n_.rsplit("_", 1)[0] if n_.endswith(("_L", "_R", "_1", "_2")) else n_
            A.write_json(os.path.join(OUT, "%s.meta.json" % item), meta)
            bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "%s.blend" % item))
        if opt["render"]:
            A.render_views(objs, os.path.join(opt["render"], item), hull=0.05 if item != "boss_gate" else 0.3, res=(900, 900))
            if opt["old"]:
                for o in objs:
                    o.hide_render = True
                _, olds = build(item, old=True)
                A.render_views(olds, os.path.join(opt["render"], "old_" + item), views=("front", "34"), kinds=("game",), sil=False, hull=0.05 if item != "boss_gate" else 0.3, res=(900, 900))
    print("[make_props] 끝")


if __name__ == "__main__":
    main()
