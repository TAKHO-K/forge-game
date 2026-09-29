# -*- coding: utf-8 -*-
# A2-N1 여유 작업(Blender bpy):
#   ① 보스 VFX 공통 메시(vfx) - 전조 원 · 전조 부채꼴 · 충격파 링 · 경고 기둥 · 타격 별. 흰색 단색(색 · 투명도 · 크기는 코드가 입힌다 - 위험색은 보스 장판 · 전조 전용).
#   ② 초월 획득 소품(transcend) - 기울어진 검은 결정 기둥 + 금빛 균열 + 도는 흑금 조각 3 + 금 받침 고리(설계서 §6).
#   ③ 관문 보스별 장식(gate_decor) - BossGateKit DECOR의 메시판(default 깃발 · abyss · storm) + 나머지 보스 새 후보(수호자 룬 판 · 서리 고드름 · 수정 왕관 · 전갈 꼬리 아치).
#      장식 파트 이름 = 코드 prim 이름(GateBanner · GateCoral …) · 좌표 = 관문 로컬(BossGateKit와 같은 치수 - make_props.gate_layout).
# 실행: bash bl.sh make_extras.py [--only vfx,transcend,gate_decor] [--render 폴더]
import bpy
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import artlib as A  # noqa: E402
import make_props as PR  # noqa: E402
import make_weapons as W  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "art", "extras"))
WHITE = (245, 245, 250)


def flat_ring(r0, r1, n=32, h=0.06, notch=0):
    """바닥 원 테(두께 h) · notch > 0이면 안쪽으로 향한 화살 톱니"""
    inner = [(r0 * math.cos(2 * math.pi * i / n), r0 * math.sin(2 * math.pi * i / n)) for i in range(n)]
    outer = [(r1 * math.cos(2 * math.pi * i / n), r1 * math.sin(2 * math.pi * i / n)) for i in range(n)]
    verts, faces = [], []
    for y in (h / 2, -h / 2):
        verts += [(x, y, z) for x, z in outer] + [(x, y, z) for x, z in inner]
    o0, i0, o1, i1 = 0, n, 2 * n, 3 * n
    for k in range(n):
        j = (k + 1) % n
        faces += [(o0 + k, o0 + j, i0 + j, i0 + k), (o1 + k, i1 + k, i1 + j, o1 + j), (o0 + k, o1 + k, o1 + j, o0 + j), (i0 + k, i0 + j, i1 + j, i1 + k)]
    g = (verts, faces)
    if notch:
        arrows = []
        for k in range(notch):
            a = 2 * math.pi * k / notch
            tip = (r0 * 0.78 * math.cos(a), 0, r0 * 0.78 * math.sin(a))
            b1 = (r0 * math.cos(a + 0.08), 0, r0 * math.sin(a + 0.08))
            b2 = (r0 * math.cos(a - 0.08), 0, r0 * math.sin(a - 0.08))
            arrows.append(([(p[0], h / 2, p[2]) for p in (tip, b1, b2)] + [(p[0], -h / 2, p[2]) for p in (tip, b1, b2)], [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]))
        g = A.merge(g, *arrows)
    return g


def vfx_parts():
    parts = {}
    parts["TelegraphCircle"] = flat_ring(4.6, 5.0, 40, 0.05, notch=8)  # 반지름 5 기준(코드가 배율) · 안쪽 화살 = "여기서 나가라"
    fan = []
    ang = math.radians(60)
    n = 16
    outline = [(0.0, 0.0)] + [(10 * math.sin(-ang / 2 + ang * i / n), -10 * math.cos(-ang / 2 + ang * i / n)) for i in range(n + 1)]
    m = len(outline)
    v = [(x, 0.025, z) for x, z in outline] + [(x, -0.025, z) for x, z in outline]
    f = [tuple(range(m)), tuple(reversed(range(m, 2 * m)))] + [(i, m + i, m + (i + 1) % m, (i + 1) % m) for i in range(m)]
    chevrons = []
    for d in (4, 6.5, 9):  # 바깥으로 향한 꺾쇠 3(방향 읽기)
        chevrons.append(A.tube([(-1.2, 0.04, -d + 0.8), (0, 0.04, -d), (1.2, 0.04, -d + 0.8)], 0.18, sides=4, flat=0.3))
    parts["TelegraphCone"] = A.merge((v, f), *chevrons)  # 부채꼴 60° · 길이 10 · 앞 = −Z
    # 충격파 링: 바깥이 들쭉날쭉한 낮은 원통 띠(위로 갈수록 좁게)
    ring = []
    N = 36
    rings = []
    for y, r in ((0.0, 5.0), (0.5, 4.85), (0.9, 4.5)):
        rings.append([((r + (0.35 if (i % 3 == 0 and y < 0.6) else 0)) * math.cos(2 * math.pi * i / N), y, (r + (0.35 if (i % 3 == 0 and y < 0.6) else 0)) * math.sin(2 * math.pi * i / N)) for i in range(N)])
    parts["ShockRing"] = A.loft(rings, cap0=False, cap1=False)
    # 경고 기둥: 열린 원통 + 띠 3(아래 진하고 위 투명은 코드)
    col = A.lathe([(1.2, 0.0), (1.2, 12.0)], 16)
    bands = [A.xform(A.lathe([(1.25, -0.15), (1.35, 0.0), (1.25, 0.15)], 16), t=(0, y, 0)) for y in (0.4, 4.0, 8.0)]
    parts["WarnPillar"] = A.merge(col, *bands)
    # 타격 별: 납작 8갈래 별(가운데 두툼)
    pts = []
    for i in range(16):
        r = 3.0 if i % 2 == 0 else 1.1
        a = 2 * math.pi * i / 16
        pts.append((r * math.cos(a), r * math.sin(a)))
    m = len(pts)
    v = [(x, y, 0.15) for x, y in pts] + [(x, y, -0.15) for x, y in pts] + [(0, 0, 0.45), (0, 0, -0.45)]
    f = [(2 * m, i, (i + 1) % m) for i in range(m)] + [(2 * m + 1, m + (i + 1) % m, m + i) for i in range(m)] + [(i, m + i, m + (i + 1) % m, (i + 1) % m) for i in range(m)]
    parts["ImpactStar"] = (v, f)
    return [(n_, g, WHITE, n_ in ("WarnPillar",)) for n_, g in parts.items()]


def transcend_parts():
    crystal = A.xform(A.crystal(4.2, 1.1, sides=6, tip_h=1.3, base_h=0.6), m=A.rot(rz=-10, rx=6), t=(0, 2.6, 0))
    side = A.xform(A.crystal(2.2, 0.6, sides=5, tip_h=0.7, base_h=0.3), m=A.rot(rz=25, rx=-10), t=(0.9, 1.4, 0.3))
    crack = W.crack_line([(-0.35, 1.2, -0.95), (0.1, 2.0, -1.05), (-0.25, 2.8, -1.0), (0.2, 3.6, -0.9), (0.0, 4.2, -0.7)], 0.16, 0.09)
    shards = W.float_shards([(-2.0, 3.2, 0.3), (1.9, 4.0, -0.4), (0.4, 5.6, 0.6)], 0.45)
    base = A.merge(A.lathe([(0.0, 0.0), (1.9, 0.0), (1.7, 0.3), (1.2, 0.45), (0.0, 0.5)], 16), W.halo_ring((0, 0.7, 0), 2.3, axis="Y", tilt=0, thick=0.1, n=16))
    return [("Crystal", A.merge(crystal, side), A.BLACK_BODY, False), ("Crack", crack, A.GOLD_GLOW, True), ("Shards", shards, A.BLACK_BODY, False), ("Base", base, A.GOLD, False)]


# ────────────────────────── 관문 장식 ──────────────────────────
GATE_BOSS = {"section_guardian": (170, 90, 255), "frost_giant": (190, 240, 255), "abyssal_lord": (40, 140, 255), "crystal_queen": (120, 230, 255),
             "scorpion_queen": (255, 170, 40), "storm_lord": (255, 240, 80)}


def banner(x, y, z):
    """GateBanner(4 × 14 · 0.3): 위 가로대 + 아래 제비꼬리 천 + 가운데 문양 돋음"""
    w, h = 4.0, 14.0
    outline = [(-w / 2, h / 2), (w / 2, h / 2), (w / 2, -h / 2), (0, -h / 2 + 2.2), (-w / 2, -h / 2)]
    n = len(outline)
    v = [(px + x, py + y, z + 0.15) for px, py in outline] + [(px + x, py + y, z - 0.15) for px, py in outline]
    f = [tuple(range(n)), tuple(reversed(range(n, 2 * n)))] + [(i, n + i, n + (i + 1) % n, (i + 1) % n) for i in range(n)]
    rod = A.tube([(x - w / 2 - 0.5, y + h / 2 + 0.2, z), (x + w / 2 + 0.5, y + h / 2 + 0.2, z)], 0.25, sides=6)
    emblem = A.xform(A.lathe([(0.0, -1.0), (1.0, 0.0), (0.0, 1.0)], 4, axis="Z"), s=(1, 1.3, 0.3), t=(x, y + 1.5, z + 0.25))
    return A.merge((v, f), rod, emblem)


def gate_decor(boss):
    L = PR.gate_layout()
    half, H, P, keyY, gableH = L["half"], L["H"], L["P"], L["keyY"], L["gableH"]
    c = GATE_BOSS[boss]
    out = []
    if boss in ("section_guardian", "frost_giant", "crystal_queen", "scorpion_queen"):  # default 깃발(모든 보스 공통 바탕)
        out.append(("GateBanner", A.merge(*[banner(sx * half, H * 0.6, -(P / 2 + 0.6)) for sx in (-1, 1)]), A.mul(c, 0.8), False))
    if boss == "section_guardian":  # 새 후보: 룬 새긴 돌판(기둥 머리 위 선돌 2 · 박공 룬 원)
        slabs = [A.xform(A.loft([[(x, y, z) for x, z in A.chamfer_rect(3.2, 2.2, 0.6)] for y in (0, 11)], tip1=(0, 13, 0)), m=A.rot(rz=-sx * 6), t=(sx * (half + P / 2 + 4.5), 0.5, -1.0)) for sx in (-1, 1)]  # 기둥 바깥 바닥의 룬 선돌(처마에 가리지 않게)
        out.append(("GateRuneStone", A.merge(*slabs), (150, 146, 140), False))
        out.append(("GateRune", A.merge(*[A.xform(A.box(0.5, 3.0, 0.4, b=0.1), m=A.rot(rz=a), t=(sx * (half + P / 2 + 4.5), 7.5, -2.3)) for a in (0, 60, 120) for sx in (-1, 1)]), c, True))  # 선돌 앞면 룬(발광)
    if boss == "frost_giant":  # 새 후보: 들보 밑 고드름 술 + 눈 덮개
        ic = [A.crystal(2.2 + 1.6 * ((k * 7) % 3), 0.55, sides=5, tip_h=1.2, base_h=0.2, center=(-half + 4 + 4.2 * k, L["beamY"] - L["BEAM"] / 2 - 1.5, -(P / 2 + 1.0)), m=A.rot(rx=180)) for k in range(9)]
        out.append(("GateIcicle", A.merge(*ic), (200, 235, 250), False))
        out.append(("GateSnow", A.xform(A.ellipsoid(((L["W"] + P + 14) / 2, 1.2, (P + 6) / 2), n=16, rings=4, squash_bottom=0.3), t=(0, L["beamY"] + L["BEAM"] / 2 + 1.6, 0)), (236, 240, 246), False))
    if boss == "crystal_queen":  # 새 후보: 박공 위 결정 왕관 + 기둥 결정
        crown = [A.crystal(h, 1.2, sides=6, tip_h=h * 0.3, base_h=0.4, center=(x, keyY + gableH * 0.55 + h * 0.35, 0), m=A.rot(rz=-x * 1.2)) for x, h in ((-8, 6), (-4, 9), (0, 12), (4, 9), (8, 6))]
        side = [A.crystal(7, 1.1, sides=6, tip_h=2, base_h=0.4, center=(sx * (half + 5.5), 4, 0), m=A.rot(rz=-sx * 15)) for sx in (-1, 1)]
        out.append(("GateCrystal", A.merge(*crown, *side), c, True))
    if boss == "scorpion_queen":  # 새 후보: 박공 위로 휜 전갈 꼬리 아치 + 기둥 집게 뿔
        tail = A.tube(A.bezier((-half, H + 2, 0), (-half * 0.6, keyY + gableH + 10, 0), (half * 0.6, keyY + gableH + 14, 0), (half * 0.7, keyY + gableH + 4, 0), n=14), lambda u: 1.6 * (1 - 0.5 * u) + 0.3, sides=8)
        segs = [A.xform(A.lathe([(1.7, -0.3), (2.0, 0.0), (1.7, 0.3)], 10, axis="X"), t=p) for p in A.bezier((-half, H + 2, 0), (-half * 0.6, keyY + gableH + 10, 0), (half * 0.6, keyY + gableH + 14, 0), (half * 0.7, keyY + gableH + 4, 0), n=7)[1:-1]]
        sting = A.tube([(half * 0.7, keyY + gableH + 4, 0), (half * 0.78, keyY + gableH, 0), (half * 0.66, keyY + gableH - 3, 0)], lambda u: 1.2 * (1 - u) + 0.1, sides=6, tip_end=True)
        out.append(("GateTail", A.merge(tail, *segs), (168, 95, 38), False))
        out.append(("GateStinger", sting, c, True))
    if boss == "abyssal_lord":  # DECOR.abyss 메시판: 산호 뿔 · 해초 · 물결 볏 · 조개 테
        teal, tealLight, coral = (60, 150, 160), (120, 210, 210), (230, 120, 140)
        corals, weeds = [], []
        for sx in (-1, 1):
            x = sx * half
            for k, (w_, h_, a_) in enumerate(((1.2, 10, 25), (1.0, 7, -20), (0.8, 6, 50))):
                base = (x + sx * (k - 1) * 1.5, H - 0.5, (k - 1) * 1.8)
                d = (-sx * math.sin(math.radians(a_)), math.cos(math.radians(a_)), 0.2)
                corals.append(A.tube([base, tuple(base[i] + d[i] * h_ * 0.5 for i in range(3)), tuple(base[i] + d[i] * h_ + (sx * 1.5 if i == 0 else 0) for i in range(3))], lambda u, w_=w_: w_ * 0.6 * (1 - 0.6 * u) + 0.15, sides=6))
            for k in range(3):
                x0 = x + (k - 1) * 2.2
                weeds.append(A.tube([(x0, 3 + k, -(P / 2 + 2.6)), (x0 + 0.8, 6 + k * 1.6, -(P / 2 + 2.8)), (x0 - 0.5, 9 + k * 2.2, -(P / 2 + 2.6))], lambda u: 0.45 * (1 - u) + 0.08, sides=5, flat=0.5, tip_end=True))
        out.append(("GateCoral", A.merge(*corals), tealLight, False))
        out.append(("GateSeaweed", A.merge(*weeds), (50, 120, 90), False))
        wave = A.tube([(k * 3.0, keyY + gableH * 0.55 - abs(k) * 1.1 + 0.8 * math.sin(k * 1.3), 0) for k in range(-5, 6)], 0.9, sides=6, flat=0.5)
        out.append(("GateWave", wave, teal, False))
        shell = A.merge(*[A.xform(A.box(1.4, 7, 0.6, b=0.3), m=A.rot(rz=k * 26), t=(4.5 * math.sin(math.radians(-k * 26)), keyY + 4.5 * math.cos(math.radians(k * 26)), -(P / 2 + 1.4))) for k in range(-2, 3)])
        out.append(("GateShell", shell, tealLight, False))
    if boss == "storm_lord":  # DECOR.storm 메시판: 피뢰 뿔 · 끝 · 전기 줄 · 톱니 볏
        metal, yellow = (150, 160, 180), (255, 236, 110)
        rods = [A.lathe([(0.7, 0.0), (0.5, 12.0), (0.0, 14.5)], 8) for _ in (0,)]
        top = L["beamY"] + L["BEAM"] / 2 + 1.4  # 처마 위
        out.append(("GateRod", A.merge(*[A.xform(rods[0], t=(sx * half, top, 0)) for sx in (-1, 1)]), metal, False))
        out.append(("GateRodTip", A.merge(*[A.xform(A.crystal(2.4, 0.9, sides=4, tip_h=0.9, base_h=0.9), t=(sx * half, top + 15.0, 0)) for sx in (-1, 1)]), metal, False))
        bolts = []
        for sx in (-1, 1):
            pts = [(sx * half + (1.4 if k % 2 == 0 else -1.4), 8 + k * 7, -(P / 2 + 0.4)) for k in range(5)]
            bolts.append(A.tube(pts, 0.3, sides=4))
        out.append(("GateBolt", A.merge(*bolts), yellow, True))
        spikes = [A.crystal(7 - abs(k) * 1.5, 1.4, sides=4, tip_h=3, base_h=0.3, center=(k * 5, keyY + gableH * 0.5 - abs(k) * 2.2 + (7 - abs(k) * 1.5) / 2, 0)) for k in range(-2, 3)]
        out.append(("GateSpike", A.merge(*spikes), A.mul(c, 0.42), False))
    return out


def build(kind, key=None):
    col = A.new_collection("%s_%s" % (kind, key or ""))
    parts = {"vfx": vfx_parts, "transcend": transcend_parts}[kind]() if kind != "gate_decor" else gate_decor(key)
    objs = [A.make_obj(n_, g, rgb, col, neon=neon, mat_name="%s_%s_%s" % (kind, key, n_)) for n_, g, rgb, neon in parts]
    return col, objs


def parse():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opt = {"only": ["vfx", "transcend", "gate_decor"], "render": None}
    for i in range(0, len(argv) - 1, 2):
        k = argv[i].lstrip("-")
        opt[k] = argv[i + 1].split(",") if k == "only" else os.path.abspath(argv[i + 1])
    return opt


def main():
    opt = parse()
    meta = {}
    if "vfx" in opt["only"]:
        A.reset()
        col, objs = build("vfx")
        for o in objs:  # 부품마다 따로 내보냄(코드가 하나씩 복제)
            A.export_fbx(os.path.join(OUT, "vfx", "%s.fbx" % o.name), [o])
            meta[o.name] = A.tri_count(o)
        if opt["render"]:
            for k, o in enumerate(objs):
                A.render_views([o], os.path.join(opt["render"], "vfx_%s" % o.name), views=("34",), kinds=("form",), sil=False, hull=0.0, res=(400, 400))
    if "transcend" in opt["only"]:
        A.reset()
        col, objs = build("transcend")
        A.export_fbx(os.path.join(OUT, "transcend_crystal.fbx"), objs)
        meta["transcend_crystal"] = sum(A.tri_count(o) for o in objs)
        if opt["render"]:
            A.render_views(objs, os.path.join(opt["render"], "transcend_crystal"), views=("front", "34"), kinds=("game",), sil=True, hull=0.05, res=(600, 600))
    if "gate_decor" in opt["only"]:
        for boss, c in GATE_BOSS.items():
            A.reset()
            fcol, frame = PR.build("boss_gate")
            stone = A.mix(A.mul(c, 0.3), (120, 118, 124), 0.55)
            for o in frame:
                o.data.materials[0].diffuse_color = tuple([A.srgb_to_linear(v) for v in A.mix(stone, (200, 198, 204), 0.2)] + [1.0])
            col, objs = build("gate_decor", boss)
            A.export_fbx(os.path.join(OUT, "gate_decor", "%s.fbx" % boss), objs)
            meta["gate_decor_" + boss] = sum(A.tri_count(o) for o in objs)
            if opt["render"]:
                A.render_views(frame + objs, os.path.join(opt["render"], "gate_%s" % boss), views=("front", "34"), kinds=("game",), sil=False, hull=0.3, res=(600, 600))
    A.write_json(os.path.join(OUT, "extras.meta.json"), {"version": "A2-N1", "tris": meta})
    print("[make_extras]", meta)


if __name__ == "__main__":
    main()
