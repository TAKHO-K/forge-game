# -*- coding: utf-8 -*-
# A2-N1 구역 소품 키트(Blender bpy): PropData.lua 틀(크기 · 충돌 = 계약)을 읽어 파트마다 같은 상자 · 자리 · 회전 안에 구역 스타일 메시를 짓는다.
#   스타일: 돌(깎은 덩어리 · 면 흔들림) · 석회 폐허(홈 파인 기둥 · 모서리 깨짐) · 수정/얼음(결정 기둥) · 사암(층진 띠) · 눈(둥근 덮개) · 나무(판자 · 통나무) · 선인장(골 기둥).
#   새 후보(NEW - 틀이 없는 구역을 5 ~ 8개로 채움) = 같은 형식의 틀을 여기 둔다 → 채택되면 PropData.templates에 옮긴다.
#   출력: roblox/art/props/kit/<틀 이름>.fbx · kit.meta.json(파트 · 삼각형) · 렌더 --render 폴더(game 45도 · 실루엣)
#   예산 = art-direction §6 소품(파트 8 · 1,500). 파트 이름 = 틀 이름 n(같은 이름 여럿이면 _1 · _2) · 원점 = 틀 p.
# 실행: bash bl.sh make_kit.py [--items T1_RockPillar,...] [--render 폴더] [--old]
import bpy
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import artlib as A  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.normpath(os.path.join(HERE, "..", "..", "src", "shared", "data", "PropData.lua"))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "art", "props", "kit"))
BUDGET, PART_CAP = 1500, 8
MAT = {"Grass": (106, 138, 78), "LeafyGrass": (88, 128, 70), "Limestone": (196, 190, 170), "Rock": (128, 124, 118), "Slate": (74, 70, 88), "Basalt": (70, 72, 84),
       "Sand": (214, 190, 138), "Sandstone": (186, 150, 104), "Cobblestone": (118, 114, 116), "Snow": (236, 240, 246), "Ice": (190, 222, 240), "Glacier": (160, 200, 226)}
CRYSTAL = (120, 230, 255)
WOOD = (142, 84, 58)
KIT = {"T1": ["T1_RuinPillar", "T1_RuinPillarBroken", "T1_RuinFallen", "T1_RockPillar", "T1_StoneArch", "T1_BalancedRock", "T1_Boulder", "T1_Monolith"],
       "T2": ["T2_CrystalCluster", "T2_CrystalSpike", "T2_CaveMouth", "T2_Boulder", "T2_CrystalSpire"],
       "T3": ["T3_CoastRock", "T3_Shipwreck", "T3_SunkenColumn", "T3_CoralFan", "T3_GiantClam"],
       "T4": ["T4_Cactus", "T4_MushroomRock", "T4_Hoodoo", "T4_Boulder", "T4_SandUrn"],
       "T5": ["T5_SpireRock", "T5_StruckRock", "T5_Boulder", "T5_RodPillar", "T5_FloatStone"],
       "T6": ["T6_IcePillar", "T6_IceChunk", "T6_SnowBoulder", "T6_IceWallSlab", "T6_SnowPine"]}

# 새 후보 틀(PropData와 같은 형식: n · s · p · r · c · sh · col)
NEW = {
    "T3_SunkenColumn": [dict(n="SunkenColumn", s=(10, 3.2, 3.2), p=(0, 5, 0), r=(0, 0, 90 - 8), c="Limestone", sh="Cylinder"),
                        dict(n="ColumnCap", s=(4.6, 1, 4.6), p=(0.7, 10.2, 0), r=(0, 0, -8), c="Limestone"),
                        dict(n="Coral", s=(3, 3, 3), p=(1.6, 1.5, -1.2), c=(235, 110, 90), col=False)],
    "T3_CoralFan": [dict(n="CoralFan", s=(7, 6, 1), p=(0, 3, 0), c=(235, 110, 90), col=False), dict(n="CoralRock", s=(4, 2, 3), p=(0, 0.6, 0), c="Rock")],
    "T3_GiantClam": [dict(n="ClamBottom", s=(6, 2, 5), p=(0, 1, 0), c=(201, 228, 234)), dict(n="ClamTop", s=(6, 2, 5), p=(0, 3.2, 1.2), r=(-35, 0, 0), c=(201, 228, 234)),
                     dict(n="Pearl", s=(1.4, 1.4, 1.4), p=(0, 2.4, -0.4), c=(250, 245, 255), sh="Ball", col=False)],
    "T4_SandUrn": [dict(n="Urn", s=(4, 6, 4), p=(0, 3, 0), c=(190, 152, 90)), dict(n="UrnSand", s=(6, 1, 5), p=(0.5, 0.3, 0.3), c="Sand", col=False)],
    "T5_RodPillar": [dict(n="RodBase", s=(6, 6, 6), p=(0, 3, 0), c="Basalt"), dict(n="Rod", s=(0.6, 12, 0.6), p=(0, 12, 0), c=(150, 156, 176)),
                     dict(n="RodGlow", s=(1.2, 1.2, 1.2), p=(0, 18.4, 0), c=(170, 200, 255), sh="Ball", col=False)],
    "T5_FloatStone": [dict(n="FloatStone", s=(6, 4, 5), p=(0, 7, 0), r=(8, 20, -6), c="Basalt", col=False), dict(n="FloatStone", s=(3, 2, 3), p=(4, 10, 2), r=(-10, 40, 12), c="Cobblestone", col=False),
                      dict(n="FloatBase", s=(5, 1.5, 5), p=(0, 0.5, 0), c="Cobblestone")],
    "T6_SnowPine": [dict(n="PineTrunk", s=(1.2, 4, 1.2), p=(0, 2, 0), c=WOOD), dict(n="PineCone", s=(7, 12, 7), p=(0, 9, 0), c=(70, 110, 90), col=False), dict(n="SnowCap", s=(5, 1.4, 5), p=(0, 13.5, 0), c="Snow", col=False)],
}


# 구역 장식(새 파트 - 틀에 추가 제안): T1 이끼 모자 · T2 결정 돌기 · T5 번개 줄기 + 떠 있는 조각
DECOR = {
    "T1_Boulder": [dict(n="MossCap", s=(6, 1.2, 5), p=(0.3, 4.6, 0), r=(10, 20, 8), c=(92, 150, 70))],
    "T2_Boulder": [dict(n="CrystalBit", s=(1.2, 2.4, 1.2), p=(1.5, 4.8, -0.5), r=(15, 0, -20), c=(150, 220, 255)),
                   dict(n="CrystalBit", s=(0.9, 1.6, 0.9), p=(5.4, 3.0, 2), r=(-10, 0, 25), c=(150, 220, 255))],
    "T5_Boulder": [dict(n="BoltVein", s=(0.5, 5, 0.5), p=(0.2, 2.6, -3.2), c=(170, 200, 255))],
    "T5_StruckRock": [dict(n="FloatChip", s=(2.4, 1.6, 2), p=(0.3, 11.5, 0.5), r=(20, 30, 15), c="Cobblestone")],
}


# ────────────────────────── PropData.lua 읽기 ──────────────────────────
def lua_vec(txt, key):
    m = re.search(r"\b%s = \{\s*(-?[\d.]+),\s*(-?[\d.]+),\s*(-?[\d.]+)\s*\}" % key, txt)
    return tuple(float(x) for x in m.groups()) if m else None


def _entries(body):
    """body 안의 '{ n = ... }' 파트 항목을 중괄호 짝으로 잘라 낸다(한 줄 · 여러 줄 틀 모두)"""
    out, k = [], 0
    while True:
        k = body.find("{ n = ", k)
        if k < 0:
            return out
        depth, e = 0, k
        while e < len(body):
            if body[e] == "{":
                depth += 1
            elif body[e] == "}":
                depth -= 1
                if depth == 0:
                    break
            e += 1
        out.append(body[k:e + 1])
        k = e + 1


def parse_templates():
    src = open(SRC, encoding="utf-8").read()
    consts = {"CRYSTAL": CRYSTAL, "WOOD": WOOD, "LEAF": (88, 128, 70)}
    heads = [(m.start(), m.group(1)) for m in re.finditer(r"\n\t\t(\w+) = \{", src)]
    out = {}
    for idx, (pos, name) in enumerate(heads):
        end = heads[idx + 1][0] if idx + 1 < len(heads) else len(src)
        parts = []
        for line in _entries(src[pos:end]):
            p = dict(n=re.search(r'n = "(\w+)"', line).group(1), s=lua_vec(line, "s"), p=lua_vec(line, "p"), r=lua_vec(line, "r") or (0, 0, 0))
            cm = re.search(r'\bc = ("(\w+)"|(\w+)|\{ (\d+), (\d+), (\d+) \})', line)
            if cm.group(2):
                p["c"] = cm.group(2)
            elif cm.group(3):
                p["c"] = consts.get(cm.group(3), (150, 150, 150))
            else:
                p["c"] = tuple(int(x) for x in cm.groups()[3:6])
            sh = re.search(r'sh = "(\w+)"', line)
            p["sh"] = sh.group(1) if sh else "Block"
            p["col"] = "col = false" not in line
            dk = re.search(r"dk = ([\d.]+)", line)
            p["dk"] = float(dk.group(1)) if dk else 0.0
            parts.append(p)
        if parts:
            out[name] = parts
    for k, v in NEW.items():
        out[k] = [dict(dict(r=(0, 0, 0), sh="Block", col=True, dk=0.0), **p) for p in v]
    for k, v in DECOR.items():  # 구역 장식 파트(틀 발자국 안 · col = false) - 같은 회색 바위가 구역마다 구별되게
        if k in out:
            out[k] = out[k] + [dict(dict(r=(0, 0, 0), sh="Block", col=False, dk=0.0), **p) for p in v]
    return out


def color(p):
    c = p["c"]
    rgb = MAT.get(c, (150, 150, 150)) if isinstance(c, str) else c
    return A.mul(rgb, 1 - p.get("dk", 0.0))


# ────────────────────────── 스타일 형태(파트 로컬 - 크기 s 상자 안) ──────────────────────────
def jitter(v, seed, amp):
    return tuple(c + amp * math.sin(seed * 12.9898 + i * 78.233 + c * 3.1) for i, c in enumerate(v))


def rock(sx, sy, sz, seed=1, sides=8, rings=4, amp=0.035):
    """깎은 바위: 단면 7각 · 층마다 비틀고 반지름 흔들기 · 위아래 모서리 깎음(상자 안)"""
    rs = []
    for k in range(rings):
        u = k / (rings - 1)
        y = -sy / 2 + sy * u
        shrink = 0.72 + 0.28 * math.sin(math.pi * (0.15 + 0.7 * u))
        tw = 0.12 * k + seed
        ring = []
        for i in range(sides):
            a = tw + 2 * math.pi * i / sides
            r = 1 + amp * math.sin(seed * 3 + i * 2.1 + k * 1.3)
            ring.append((sx / 2 * shrink * r * math.cos(a), y, sz / 2 * shrink * r * math.sin(a)))
        rs.append(ring)
    return A.loft(rs)


def fluted_column(L, r, broken=False, seed=1):
    """홈 파인 기둥(축 Y) · 부러진 기둥은 윗면이 비스듬히 깨짐"""
    flutes = 12
    sec = [((r if i % 2 == 0 else r * 0.88) * math.cos(math.pi * i / flutes), (r if i % 2 == 0 else r * 0.88) * math.sin(math.pi * i / flutes)) for i in range(2 * flutes)]
    rings = []
    ys = [-L / 2, -L / 2 + 0.35, L / 2 - 0.35, L / 2]
    for k, y in enumerate(ys):
        k2 = 1.12 if k in (0, 3) and not broken else 1.0
        rings.append([(x * k2, y, z * k2) for x, z in sec])
    if broken:  # 윗면 비스듬히(한쪽이 더 높게)
        rings[-1] = [(x, L / 2 - 0.9 + 0.9 * (x / r + 1) / 2 + 0.25 * math.sin(i * 1.7 + seed), z) for i, (x, _, z) in enumerate(rings[-1])]
        rings[-2] = [(x, min(y, L / 2 - 1.1), z) for x, y, z in rings[-2]]
    return A.loft(rings)


def crystal_in(sx, sy, sz, seed=1):
    return A.crystal(sy, min(sx, sz) / 2 * 0.95, sides=6, tip_h=sy * 0.22, base_h=sy * 0.06)


def layered(sx, sy, sz, seed=1, bands=4):
    """층진 사암: 층마다 조금씩 튀어나오고 들어감"""
    st = []
    for k in range(bands):
        y0 = -sy / 2 + sy * k / bands
        y1 = -sy / 2 + sy * (k + 1) / bands
        w = 0.86 + 0.1 * math.sin(k * 2.3 + seed)
        st += [(y0 + 0.02, w * 0.97), (y1 - 0.06, w)]
    rings = []
    for y, w in st:
        rings.append([(x * w, y, z * w) for x, z in A.chamfer_rect(sx, sz, min(sx, sz) * 0.2)])
    return A.loft(rings)


def pillow(sx, sy, sz):
    """눈 덮개: 둥근 방석(위 볼록 · 가장자리 늘어짐)"""
    return A.ellipsoid((sx / 2, sy / 2, sz / 2), n=12, rings=5, squash_bottom=0.35)


def ribbed(L, r, axis="Y"):
    """선인장 골 기둥(축 Y) + 둥근 끝"""
    ribs = 8
    sec = [((r if i % 2 == 0 else r * 0.82) * math.cos(math.pi * i / ribs), (r if i % 2 == 0 else r * 0.82) * math.sin(math.pi * i / ribs)) for i in range(2 * ribs)]
    rings = [[(x, y, z) for x, z in sec] for y in (-L / 2, 0, L / 2 - r * 0.5)]
    rings.append([(x * 0.55, L / 2 - r * 0.1, z * 0.55) for x, z in sec])
    return A.loft(rings, tip1=(0, L / 2 + r * 0.15, 0))


def planks_hull(sx, sy, sz):
    """난파선 선체 반쪽(쐐기 자리): 휜 판자 줄"""
    out = []
    for k in range(4):
        y = -sy / 2 + sy * (k + 0.5) / 4
        x = -sx / 2 + sx * (1 - (k / 3.2) ** 1.6) * 0.95
        out.append(A.xform(A.box(0.6, sy / 4.3, sz * (0.92 - 0.1 * k), b=0.12), t=(x * 0.9, y, 0)))
    keel = A.box(sx * 0.95, 0.5, sz * 0.9, b=0.15, center=(0, -sy / 2 + 0.25, 0))
    return A.merge(keel, *out)


def coral_fan(sx, sy, sz):
    out = []
    for k in range(7):
        a = math.radians(-60 + 20 * k)
        L = sy * (0.7 + 0.3 * math.cos(a))
        out.append(A.tube([(0, -sy / 2, 0), (math.sin(a) * L * 0.5, -sy / 2 + math.cos(a) * L * 0.5, 0.1), (math.sin(a) * L * 0.9, -sy / 2 + math.cos(a) * L * 0.95, 0)],
                          lambda u: 0.3 * (1 - u) + 0.1, sides=5))
    return A.merge(*out)


def shell_half(sx, sy, sz, top=False):
    g = A.ellipsoid((sx / 2, sy / 2, sz / 2), n=14, rings=5, squash_bottom=0.1 if not top else 1.0)
    ribs = [A.tube([(sx / 2 * 0.95 * math.cos(a), 0, sz / 2 * 0.95 * math.sin(a)), (0, sy / 2 * (1 if top else 0.6), 0)], 0.12, sides=4) for a in (0.4, 1.0, 1.6, 2.2, 2.8)]
    return A.merge(g, *ribs)


def urn(sx, sy, sz):
    prof = [(0.0, -sy / 2), (sx * 0.3, -sy / 2), (sx * 0.5, -sy * 0.15), (sx * 0.48, sy * 0.15), (sx * 0.25, sy * 0.35), (sx * 0.2, sy * 0.42), (sx * 0.3, sy / 2), (sx * 0.22, sy / 2)]
    return A.merge(A.lathe(prof, 12), *[A.tube([(s * sx * 0.25, sy * 0.3, 0), (s * sx * 0.55, sy * 0.25, 0), (s * sx * 0.48, sy * 0.0, 0)], 0.18, sides=5) for s in (-1, 1)])


def pine(sx, sy, sz):
    tiers = [A.lathe([(0.0, -sy / 2 + sy * k * 0.28), (sx / 2 * (1 - 0.22 * k), -sy / 2 + sy * k * 0.28), (0.0, -sy / 2 + sy * k * 0.28 + sy * 0.45)], 9) for k in range(3)]
    return A.merge(*tiers)


def shape_for(tname, p, idx):
    sx, sy, sz = p["s"]
    n, sh = p["n"], p["sh"]
    seed = idx + len(tname)
    if sh == "Cylinder":  # Roblox 원통 축 = X → 여기서 Y로 짓고 Z 90°로 눕힌 다음 틀 회전을 곱한다(틀이 r z 90으로 세운다)
        L, r = sx, min(sy, sz) / 2
        if n in ("Cactus", "CactusArm"):
            g = ribbed(L, r)
        elif n in ("Mast",):
            g = A.lathe([(r * 0.8, -L / 2), (r, 0), (r * 0.75, L / 2)], 8)
        else:
            g = fluted_column(L, r, broken=(tname in ("T1_RuinPillarBroken",)), seed=seed) if "Ruin" in n or "Column" in n else rock(r * 2, L, r * 2, seed)
        return A.xform(g, m=A.rot(rz=-90))
    if sh == "Ball":
        return A.ellipsoid((sx / 2, sy / 2, sz / 2), n=12, rings=7)
    if n in ("Crystal", "CrystalSpike", "CaveCrystal", "IcePillar"):
        return crystal_in(sx, sy, sz, seed)
    if n in ("Landmark",):
        if tname == "T2_CrystalSpire":
            return A.merge(A.crystal(sy, sx * 0.42, sides=6, tip_h=sy * 0.14, base_h=sy * 0.03, center=(0, 0, 0)),
                           A.crystal(sy * 0.72, sx * 0.34, sides=6, tip_h=sy * 0.12, base_h=sy * 0.03, center=(sx * 0.32, -sy * 0.14, sz * 0.12), m=A.rot(rz=-6)),
                           A.crystal(sy * 0.55, sx * 0.3, sides=6, tip_h=sy * 0.1, base_h=sy * 0.03, center=(-sx * 0.3, -sy * 0.22, -sz * 0.1), m=A.rot(rz=7)))  # 결정 기둥 3개 묶음(바늘 → 덩어리)
        if tname == "T6_IceWallSlab":
            return A.merge(*[A.xform(A.crystal(sy * h, sx * 0.14, sides=5, tip_h=sy * 0.12, base_h=1.0), t=(sx * (k / 4 - 0.5) * 0.85, -sy * (1 - h) / 2, 0)) for k, h in enumerate((0.7, 0.95, 1.0, 0.85, 0.6))])
        stone = A.loft([[(x * w, y, z * w) for x, z in A.chamfer_rect(sx, sz, sx * 0.22)] for y, w in ((-sy / 2, 1.0), (sy * 0.3, 0.92), (sy / 2 - sx * 0.3, 0.8))], tip1=(0, sy / 2, 0))  # 비석: 상자 폭을 채운 모따기 돌 + 뾰족 머리 + 앞면 룬
        rune = A.xform(A.box(sx * 0.12, sy * 0.35, 0.6, b=0.2), t=(0, sy * 0.1, -sz * 0.45))
        return A.merge(stone, rune)
    if n in ("RuinCapital", "ColumnCap"):
        return A.merge(A.box(sx, sy * 0.55, sz, b=0.15, center=(0, sy * 0.22, 0)), A.lathe([(sx * 0.32, -sy / 2), (sx * 0.42, 0.0), (sx * 0.3, sy * 0.0)], 12))
    if n in ("SnowCap", "MossCap"):
        return pillow(sx, sy, sz)
    if n == "CrystalBit":
        return A.crystal(sy, sx / 2, sides=5, tip_h=sy * 0.3, base_h=sy * 0.1)
    if n == "BoltVein":
        return A.merge(*[A.xform(A.box(0.35, sy / 3.2, 0.3), m=A.rot(rz=(-1) ** k * 28), t=((-1) ** k * 0.35, -sy / 3 + sy / 3 * k, 0)) for k in range(3)])
    if n == "FloatChip":
        return rock(sx, sy, sz, 7, 6, 3, 0.06)
    if n in ("Barnacle", "Scorch", "UrnSand"):
        return A.ellipsoid((sx / 2, sy / 2, sz / 2), n=12, rings=3, squash_bottom=0.2)
    if n in ("CaveDark",):
        return A.box(sx, sy, sz)
    if n in ("ScorchGlow",):
        return A.merge(*[A.xform(A.box(0.3, sy / 3, 0.3), m=A.rot(rz=(-1) ** k * 25), t=((-1) ** k * 0.2, -sy / 3 + sy / 3 * k, 0)) for k in range(3)])  # 번개 모양 틈
    if n == "Hull":
        return planks_hull(sx, sy, sz)
    if n == "HullRib":
        return A.tube([(0, -sy / 2, 0), (0.4, 0, 0), (0.2, sy / 2, 0)], 0.35, sides=5)
    if n == "CoralFan":
        return coral_fan(sx, sy, sz)
    if n == "Coral":
        return A.merge(*[A.tube([(0, -sy / 2, 0), (dx * 0.5, 0, dz * 0.5), (dx, sy / 2, dz)], lambda u: 0.35 * (1 - u) + 0.12, sides=5) for dx, dz in ((0.8, 0.2), (-0.6, 0.5), (0.1, -0.8))])
    if n in ("ClamBottom", "ClamTop"):
        return shell_half(sx, sy, sz, top=(n == "ClamTop"))
    if n == "Urn":
        return urn(sx, sy, sz)
    if n == "Rod":
        return A.merge(A.lathe([(sx * 1.25, -sy / 2), (sx, sy / 2 - 1.5), (0.0, sy / 2)], 6), *[A.tube([(0, sy / 2 - 3 - 2.4 * k, 0), (s * 1.9, sy / 2 - 2.0 - 2.4 * k, 0)], lambda u: 0.35 * (1 - u) + 0.06, sides=4, tip_end=True) for k, s in ((0, 1), (1, -1))])  # 막대 ×2.5 · 가지 굵게
    if n == "PineCone":
        return pine(sx, sy, sz)
    if n == "PineTrunk":
        return A.lathe([(sx / 2, -sy / 2), (sx / 2 * 0.8, sy / 2)], 8)
    if n in ("Hoodoo", "RockStem", "RockCap") or (tname.startswith("T4_") and n == "Boulder"):
        if n == "RockCap":
            return A.merge(layered(sx, sy * 0.6, sz, seed, 2), A.xform(rock(sx * 0.9, sy * 0.5, sz * 0.9, seed, 7, 3, 0.05), t=(0, sy * 0.15, 0)))
        return layered(sx, sy, sz, seed, 4 if sy > 6 else 3)
    if n in ("IceChunk",):
        return rock(sx, sy, sz, seed, sides=5, rings=3, amp=0.12)
    if n in ("RuinWall", "RuinRubble", "RuinBeam"):
        return rock(sx, sy, sz, seed, sides=4, rings=3, amp=0.05)
    if n in ("CactusArm",):
        return ribbed(sx, min(sy, sz) / 2)
    if n in ("CoralRock", "FloatBase", "RodBase", "CrystalRock"):
        return rock(sx, sy, sz, seed, 8, 3, 0.08)
    return rock(sx, sy, sz, seed)  # 기본 = 깎은 바위


def old_geo(p):
    sx, sy, sz = p["s"]
    if p["sh"] == "Cylinder":
        return A.lathe([(0.0, -sx / 2), (sy / 2, -sx / 2), (sy / 2, sx / 2), (0.0, sx / 2)], 12, axis="X")
    if p["sh"] == "Ball":
        return A.ellipsoid((sx / 2, sy / 2, sz / 2), n=12, rings=7)
    if p["sh"] == "Wedge":
        v = [(-sx / 2, -sy / 2, -sz / 2), (sx / 2, -sy / 2, -sz / 2), (sx / 2, -sy / 2, sz / 2), (-sx / 2, -sy / 2, sz / 2), (-sx / 2, sy / 2, sz / 2), (sx / 2, sy / 2, sz / 2)]
        return v, [(0, 1, 2, 3), (3, 2, 5, 4), (0, 4, 5, 1), (0, 3, 4), (1, 5, 2)]
    return A.box(sx, sy, sz)


def build(tname, parts, old=False):
    col = A.new_collection(("old_" if old else "") + tname)
    objs = []
    names = [p["n"] for p in parts]
    for i, p in enumerate(parts):
        local = old_geo(p) if old else shape_for(tname, p, i)
        rx, ry, rz = p["r"]
        g = A.xform(local, m=A.rot(rx=rx, ry=ry, rz=rz), t=p["p"])
        nm = p["n"] if names.count(p["n"]) == 1 else "%s_%d" % (p["n"], names[:i + 1].count(p["n"]))
        objs.append(A.make_obj(nm, g, color(p), col, neon=p["n"] in ("RodGlow", "ScorchGlow", "Pearl", "BoltVein"), origin=p["p"], mat_name="%s%s_%s" % ("old_" if old else "", tname, nm)))
    return col, objs


def parse():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opt = {"items": [t for z in KIT.values() for t in z], "render": None, "old": False}
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--items":
            opt["items"] = argv[i + 1].split(","); i += 1
        elif a == "--render":
            opt["render"] = os.path.abspath(argv[i + 1]); i += 1
        elif a == "--old":
            opt["old"] = True
        i += 1
    return opt


def main():
    opt = parse()
    T = parse_templates()
    meta = {}
    for tname in opt["items"]:
        A.reset()
        col, objs = build(tname, T[tname])
        tri = sum(A.tri_count(o) for o in objs)
        meta[tname] = {"parts": len(objs), "tris": tri, "new": tname in NEW}
        print("[make_kit] %s 파트 %d / %d · 삼각형 %d / %d%s" % (tname, len(objs), PART_CAP, tri, BUDGET, " (새 후보)" if tname in NEW else ""))
        A.export_fbx(os.path.join(OUT, "%s.fbx" % tname), objs)
        if opt["render"]:
            A.render_views(objs, os.path.join(opt["render"], tname), views=("34",), kinds=("game",), sil=True, hull=0.08, res=(500, 500))
            if opt["old"] and tname not in NEW:
                for o in objs:
                    o.hide_render = True
                _, olds = build(tname, T[tname], old=True)
                A.render_views(olds, os.path.join(opt["render"], "old_" + tname), views=("34",), kinds=("game",), sil=False, hull=0.08, res=(500, 500))
    path = os.path.join(OUT, "kit.meta.json")
    old = {}
    if os.path.exists(path):
        import json
        old = json.load(open(path, encoding="utf-8")).get("items", {})
    old.update(meta)
    A.write_json(path, {"version": "A2-N1", "budget": BUDGET, "partCap": PART_CAP, "kit": KIT, "items": old})
    print("[make_kit] 끝")


if __name__ == "__main__":
    main()
