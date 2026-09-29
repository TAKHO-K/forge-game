# -*- coding: utf-8 -*-
# A2-N1 방어구 세트(Blender bpy): 세트 계열 = 구역 6(SetData · item.setZone) × 부위 3(갑옷 armor · 장갑 gloves · 신발 shoes - EquipSlots 키).
#   구역 테마가 실루엣에 드러나게(석조 = 돌판 · 수정 = 결정 · 수몰 사원 = 조개 · 산호 · 모래 유적 = 천 감개 + 청동 · 폭풍 첨탑 = 번개 날 · 빙하 = 털 + 고드름).
#   등급 차이 = 무기 사다리 축소판(색 · 장식 누적): 희귀 = 테 띠 · 영웅 = 장식 등급 색 · 전설 = 보석 + 큰 어깨 · 유물 = 룬 가시 · 고대 = 깃 날개 · 태초 = 흰 본체 + 결정 · 초월 = 흑금.
#   파트 = Base(본체 - 구역 색) · Trim(장식 - 구역 강조 → 영웅부터 등급 색) · Gem · Deco(룬 · 날개) · Fx(결정 · 흑금 조각) · Crack.
#   게임에 방어구 착용 모델은 아직 없다 → 아이콘(8등급 전부) + 메시(일반 · 전설 · 초월 look FBX)만. 예산 = 무기와 같은 800(결정 필요).
#   아이콘 파일명 = <슬롯>_<구역 키>_<등급>.png → roblox/art/icons/armor/.
# 실행: bash bl.sh make_armor.py [--zones tier1,...] [--slots armor,gloves,shoes] [--icons] [--render 폴더] [--export]
import bpy
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import artlib as A  # noqa: E402
import make_weapons as W  # noqa: E402  (공통 부품: feather_wing · halo_ring · float_crystals · float_shards · crack_line · spike)
import make_icons as I  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "art", "armor"))
ICON_OUT = os.path.normpath(os.path.join(HERE, "..", "..", "art", "icons", "armor"))
BUDGET = 800
RANK = W.RANK
at_least = W.at_least
ZONES = {  # 본체 · 그늘 · 강조(art-direction §3-2 구역 팔레트) · 테마
    "tier1": dict(base=(168, 162, 154), shade=(110, 106, 102), accent=(92, 224, 138), theme="석조 평원"),
    "tier2": dict(base=(120, 96, 190), shade=(75, 58, 140), accent=(210, 108, 240), theme="수정 동굴"),
    "tier3": dict(base=(201, 228, 234), shade=(27, 127, 168), accent=(235, 110, 90), theme="수몰 사원"),
    "tier4": dict(base=(217, 186, 140), shade=(168, 97, 46), accent=(205, 150, 60), theme="모래 유적"),
    "tier5": dict(base=(88, 92, 128), shade=(58, 63, 92), accent=(120, 230, 255), theme="폭풍 첨탑"),
    "tier6": dict(base=(236, 240, 246), shade=(127, 147, 168), accent=(111, 200, 255), theme="빙하 동굴"),
}
SLOTS = ["armor", "gloves", "shoes"]


def palette(zone, grade):
    Z = ZONES[zone]
    gc = A.GRADE_COLOR[grade]
    p = dict(base=Z["base"], trim=Z["accent"], shade=Z["shade"], gem=(255, 244, 214), deco=gc)
    if at_least(grade, "rare"):
        p["band"] = gc
    if at_least(grade, "epic"):
        p["trim"] = gc
    if grade == "primordial":
        p.update(base=(244, 242, 250), shade=(220, 214, 236))
    if grade == "transcendent":
        p.update(base=A.BLACK_BODY, shade=A.BLACK_SHADE, trim=A.GOLD, gem=(255, 214, 90), deco=A.BLACK_BODY)
    return p


def yl(st, b=0.1):
    """세로 로프트 [(y, w, d, dz), ...]"""
    return A.loft([[(x, y, z + dz) for x, z in A.chamfer_rect(w, d, min(b, w * 0.3, d * 0.3))] for y, w, d, dz in st])


# ────────────────────────── 부위 기본형 ──────────────────────────
def armor_base():
    torso = yl([(-0.9, 1.55, 1.0, 0.02), (-0.4, 1.75, 1.12, -0.02), (0.3, 1.95, 1.2, -0.06), (0.8, 1.75, 1.0, 0.0), (0.95, 1.1, 0.75, 0.05)], 0.24)
    return torso


def gloves_base():
    """장갑 = 나팔 소매 + 손등 + 주먹 쥔 손가락 4 마디(앞 −Z로 말림) + 옆 엄지"""
    cuff = yl([(0.15, 0.56, 0.56, 0), (0.45, 0.72, 0.7, 0), (0.78, 0.98, 0.92, 0)], 0.14)
    palm = yl([(-0.55, 0.7, 0.5, -0.04), (-0.2, 0.74, 0.56, -0.02), (0.15, 0.6, 0.54, 0)], 0.14)
    fingers = [A.tube([(x, -0.5, -0.12), (x, -0.72, -0.24), (x, -0.7, -0.42), (x, -0.52, -0.48)], 0.1, sides=6) for x in (-0.24, -0.08, 0.08, 0.24)]
    thumb = A.tube([(0.32, -0.15, -0.1), (0.5, -0.32, -0.22), (0.44, -0.5, -0.36)], lambda u: 0.12 - 0.03 * u, sides=6, tip_end=False)
    return A.merge(cuff, palm, thumb, *fingers)


def shoes_base():
    shaft = yl([(0.2, 0.62, 0.66, 0.05), (0.7, 0.66, 0.7, 0.06), (1.1, 0.74, 0.78, 0.06)], 0.12)
    foot = A.loft([[(x, y + yc, z) for x, y in A.chamfer_rect(w, h, 0.1)] for z, w, h, yc in ((0.4, 0.64, 0.5, 0.0), (-0.2, 0.68, 0.46, -0.02), (-0.7, 0.62, 0.36, -0.07), (-0.98, 0.46, 0.24, -0.12))])
    return A.merge(shaft, foot)


BASE = {"armor": armor_base, "gloves": gloves_base, "shoes": shoes_base}


# ────────────────────────── 구역 테마(부위별 Base 추가 · Trim) ──────────────────────────
def pauldron_pos(s):
    return (s * 1.08, 0.72, 0.0)


def zone_features(zone, slot, big=1.0):
    """반환 (base 추가 geo 목록, trim geo 목록) - big = 전설 이상 어깨 · 장식 확대"""
    b, t = [], []
    if zone == "tier1":  # 석조: 깎은 돌판 어깨 · 돌 주먹 · 돌 장화 + 이끼(강조)
        if slot == "armor":
            for s in (-1, 1):
                x, y, z = pauldron_pos(s)
                b.append(A.xform(yl([(-0.2, 0.9 * big, 1.1 * big, 0), (0.15, 1.05 * big, 1.2 * big, 0), (0.35, 0.8 * big, 0.95 * big, 0)], 0.2), m=A.rot(rz=-s * 15), t=(x, y, z)))
                t.append(A.ellipsoid((0.32 * big, 0.12, 0.4 * big), n=8, rings=3, center=(x - s * 0.05, y + 0.4 * big, z), squash_bottom=0.3))
            t.append(A.box(1.7, 0.2, 1.12, b=0.06, center=(0, -0.72, 0)))
        elif slot == "gloves":
            b.append(A.box(0.8, 0.26, 0.3, b=0.08, center=(0, -0.8, -0.3)))
            t.append(A.ellipsoid((0.3, 0.1, 0.3), n=8, rings=3, center=(0, 0.72, 0.1), squash_bottom=0.3))
        else:
            b.append(A.box(0.74, 0.22, 0.5, b=0.08, center=(0, -0.08, -0.82)))
            t.append(A.box(0.78, 0.12, 1.45, b=0.04, center=(0, -0.3, -0.25)))
    elif zone == "tier2":  # 수정: 어깨 · 손등 · 뒤꿈치 결정
        if slot == "armor":
            for s in (-1, 1):
                x, y, z = pauldron_pos(s)
                b.append(A.ellipsoid((0.5 * big, 0.36, 0.55 * big), n=10, rings=5, center=(x, y, z), squash_bottom=0.3))
                t += [A.crystal(h * big, 0.13, sides=5, tip_h=0.25, base_h=0.05, center=(x + s * dx, y + 0.3, dz), m=A.rot(rz=-s * ang)) for h, dx, dz, ang in ((0.9, 0.0, 0.0, 12), (0.6, 0.22, 0.2, 35), (0.5, -0.15, -0.2, -8))]
            t.append(A.crystal(0.5, 0.2, sides=6, tip_h=0.18, base_h=0.15, center=(0, 0.2, -0.66), m=A.rot(rx=90)))
        elif slot == "gloves":
            t += [A.crystal(h, 0.1, sides=5, tip_h=0.2, base_h=0.05, center=(dx, -0.5, 0.3), m=A.rot(rx=-60)) for h, dx in ((0.6, 0.0), (0.42, 0.2), (0.4, -0.2))]
        else:
            t += [A.crystal(0.6, 0.12, sides=5, tip_h=0.2, base_h=0.05, center=(dx, 0.2, 0.45), m=A.rot(rx=-50)) for dx in (-0.15, 0.15)]
    elif zone == "tier3":  # 수몰 사원: 조개 어깨 · 지느러미 · 산호
        if slot == "armor":
            for s in (-1, 1):
                x, y, z = pauldron_pos(s)
                b.append(A.ellipsoid((0.58 * big, 0.3, 0.62 * big), n=12, rings=4, center=(x, y + 0.05, z), squash_bottom=0.2))
                t += [A.tube([(x + 0.5 * math.cos(a) * big, y + 0.08, 0.52 * math.sin(a) * big), (x, y + 0.36, 0)], 0.06, sides=4) for a in (0.3, 1.1, 1.9, 2.7, 3.5, 4.3, 5.1, 5.9)]
            t.append(A.xform(W.feather_wing((0, 0.3, 0.55), 1, (0.7, 0.55, 0.4), (-40, 0, 40), up=(0, 1, 0), side=(1, 0, 0), width=0.16), t=(0, 0, 0)))  # 등 지느러미(산호 색)
        elif slot == "gloves":
            t.append(W.feather_wing((0.38, 0.2, 0.05), 1, (0.55, 0.42, 0.3), (40, 70, 100), up=(0, 1, 0), side=(1, 0, 0), width=0.12))
        else:
            t.append(W.feather_wing((0.36, 0.7, 0.2), 1, (0.55, 0.42, 0.3), (30, 60, 90), up=(0, 1, 0), side=(1, 0, 0), width=0.12))
    elif zone == "tier4":  # 모래 유적: 천 감개 띠 · 청동 스카라브 · 말린 앞코
        if slot == "armor":
            for k in range(3):
                t.append(yl([(-0.35 + 0.32 * k, 1.92, 1.22, -0.05), (-0.25 + 0.32 * k, 1.94, 1.24, -0.05)], 0.1))
            for s in (-1, 1):
                x, y, z = pauldron_pos(s)
                b.append(A.xform(yl([(-0.15, 0.85 * big, 0.95 * big, 0), (0.12, 0.95 * big, 1.05 * big, 0), (0.28, 0.7 * big, 0.8 * big, 0)], 0.18), t=(x, y, z)))
            t.append(A.xform(A.ellipsoid((0.26, 0.2, 0.09), n=8, rings=4), t=(0, 0.35, -0.64)))  # 스카라브
            t += [A.tube([(s * 0.12, 0.45, -0.64), (s * 0.3, 0.55, -0.64), (s * 0.32, 0.3, -0.64)], 0.035, sides=3) for s in (-1, 1)]
        elif slot == "gloves":
            t += [A.xform(A.lathe([(0.38, -0.04), (0.42, 0.0), (0.38, 0.04)], 10), t=(0, y, 0)) for y in (0.05, 0.3, 0.55)]
        else:
            b.append(A.tube(A.bezier((0, -0.1, -0.95), (0, -0.05, -1.25), (0, 0.25, -1.3), (0, 0.3, -1.1), n=5), lambda u: 0.14 * (1 - u) + 0.04, sides=6, tip_end=True))  # 말린 앞코
            t += [A.xform(A.lathe([(0.37, -0.04), (0.41, 0.0), (0.37, 0.04)], 10), t=(0, y, 0.05)) for y in (0.45, 0.8)]
    elif zone == "tier5":  # 폭풍 첨탑: 번개 날 어깨 · 날개 뒤꿈치
        if slot == "armor":
            for s in (-1, 1):
                x, y, z = pauldron_pos(s)
                b.append(A.ellipsoid((0.5 * big, 0.3, 0.52 * big), n=10, rings=4, center=(x, y, z), squash_bottom=0.25))
                bolt = [(0.0, 0.0), (0.25, 0.3), (0.05, 0.4), (0.35, 0.8)]
                outline = [(px + 0.1, py) for px, py in bolt] + [(px - 0.1, py) for px, py in reversed(bolt)]
                n = len(outline)
                v = [(px * s * big + x, py * big + y + 0.2, 0.06) for px, py in outline] + [(px * s * big + x, py * big + y + 0.2, -0.06) for px, py in outline]
                f = [tuple(range(n)), tuple(reversed(range(n, 2 * n)))] + [(i, n + i, n + (i + 1) % n, (i + 1) % n) for i in range(n)]
                t.append((v, f))
        elif slot == "gloves":
            t.append(W.feather_wing((0.36, 0.45, 0.1), 1, (0.5, 0.38, 0.28), (20, 45, 70), up=(0, 1, 0), side=(1, 0, 0), width=0.1))
        else:
            t.append(W.feather_wing((0.34, 0.75, 0.3), 1, (0.6, 0.45, 0.32), (20, 45, 70), up=(0, 1, 0.3), side=(1, 0, 0), width=0.12))
    elif zone == "tier6":  # 빙하: 털 깃 · 털 소매 · 고드름
        if slot == "armor":
            b += [A.ellipsoid((0.26, 0.2, 0.26), n=6, rings=3, center=(0.62 * math.cos(a), 0.9, 0.42 * math.sin(a))) for a in (2 * math.pi * i / 8 for i in range(8))]
            for s in (-1, 1):
                x, y, z = pauldron_pos(s)
                b.append(A.ellipsoid((0.5 * big, 0.36, 0.52 * big), n=10, rings=4, center=(x, y, z), squash_bottom=0.3))
                t += [A.crystal(0.5 * big, 0.1, sides=4, tip_h=0.25, base_h=0.04, center=(x + s * dx, y - 0.32, 0), m=A.rot(rx=180)) for dx in (-0.2, 0.05, 0.28)]
        elif slot == "gloves":
            b += [A.ellipsoid((0.2, 0.16, 0.2), n=6, rings=3, center=(0.46 * math.cos(a), 0.75, 0.46 * math.sin(a))) for a in (2 * math.pi * i / 7 for i in range(7))]
            t += [A.crystal(0.35, 0.07, sides=4, tip_h=0.14, base_h=0.03, center=(dx, -0.75, -0.32), m=A.rot(rx=-100)) for dx in (-0.18, 0.02, 0.2)]
        else:
            b += [A.ellipsoid((0.2, 0.17, 0.2), n=6, rings=3, center=(0.44 * math.cos(a), 1.1, 0.44 * math.sin(a) + 0.06)) for a in (2 * math.pi * i / 7 for i in range(7))]
            t.append(A.box(0.74, 0.12, 1.45, b=0.04, center=(0, -0.3, -0.25)))
    return b, t


# ────────────────────────── 등급 장식 ──────────────────────────
def grade_parts(zone, slot, grade, P):
    parts = []
    big = 1.18 if at_least(grade, "legendary") else 1.0
    add_b, trim = zone_features(zone, slot, big)
    base = A.merge(BASE[slot](), *add_b)
    parts.append(("Base", base, P["base"], False))
    parts.append(("Trim", A.merge(*trim) if trim else A.box(0.1, 0.1, 0.1), P["trim"], False))
    anchor = {"armor": (0, 0.25, -0.68), "gloves": (0, -0.55, -0.32), "shoes": (0, 0.55, -0.4)}[slot]
    if at_least(grade, "rare"):  # 희귀 = 등급 색 테 띠(가장자리)
        band = {"armor": A.box(1.62, 0.12, 1.06, b=0.04, center=(0, -0.92, 0)), "gloves": A.xform(A.lathe([(0.44, -0.05), (0.48, 0.0), (0.44, 0.05)], 10), t=(0, 0.72, 0)),
                "shoes": A.xform(A.lathe([(0.4, -0.05), (0.44, 0.0), (0.4, 0.05)], 10), t=(0, 1.1, 0.06))}[slot]
        parts.append(("Band", band, P["band"] if grade != "transcendent" else A.GOLD, False))
    if at_least(grade, "legendary"):  # 전설 = 보석 1(발광)
        parts.append(("Gem", A.crystal(0.34, 0.14, sides=5, tip_h=0.12, base_h=0.1, center=anchor, m=A.rot(rx=90)), P["gem"], True))
    if at_least(grade, "relic"):  # 유물 = 룬 가시 2(유물만 발광)
        sp = {"armor": [W.spike((s * 1.25, 1.05, 0), (s * 0.6, 0.8, 0), 0.45, 0.1) for s in (-1, 1)],
              "gloves": [W.spike((s * 0.42, 0.5, 0.0), (s * 0.9, 0.45, 0), 0.35, 0.08) for s in (-1, 1)],
              "shoes": [W.spike((s * 0.38, 0.95, 0.2), (s * 0.8, 0.6, 0.2), 0.32, 0.08) for s in (-1, 1)]}[slot]
        parts.append(("Runes", A.merge(*sp), P["deco"] if grade == "relic" else P["trim"], grade == "relic"))
    if at_least(grade, "ancient"):  # 고대 = 깃 날개(등 · 손목 · 뒤꿈치)
        wg = {"armor": A.merge(*[W.feather_wing((s * 0.75, 0.5, 0.45), s, (1.3, 1.05, 0.8), (35, 60, 85), up=(0, 1, 0.2), side=(1, 0, 0), width=0.2) for s in (-1, 1)]),  # 옆으로 펼쳐 정면에서 보이게
              "gloves": W.feather_wing((-0.4, 0.55, 0.1), -1, (0.6, 0.45, 0.32), (30, 55, 80), up=(0, 1, 0), side=(1, 0, 0), width=0.12),
              "shoes": W.feather_wing((-0.36, 0.8, 0.3), -1, (0.62, 0.48, 0.34), (25, 50, 75), up=(0, 1, 0.3), side=(1, 0, 0), width=0.12)}[slot]
        parts.append(("Wings", wg, P["deco"], False))
    c = {"armor": (0, 0.2, 0), "gloves": (0, 0.0, 0), "shoes": (0, 0.4, 0)}[slot]
    if grade == "primordial":  # 태초 = 결정 2 + 빛 테
        parts.append(("Fx", A.merge(W.float_crystals([(c[0] - 1.0, c[1] + 0.9, 0), (c[0] + 1.05, c[1] + 0.5, 0)], 0.5, 0.12),
                                    W.halo_ring((c[0], c[1] + (1.25 if slot == "armor" else 1.0), 0), 0.55, axis="Z", tilt=20, thick=0.06)), A.GRADE_COLOR["primordial"], True))
    if grade == "transcendent":  # 초월 = 흑금 조각 3 + 금빛 균열
        parts.append(("Fx", W.float_shards([(c[0] - 1.0, c[1] + 0.8, 0), (c[0] + 1.0, c[1] + 0.3, 0), (c[0] + 0.3, c[1] + 1.3, 0)], 0.3), A.BLACK_BODY, False))
        crack = {"armor": [(-0.4, 0.7, -0.62), (0.1, 0.3, -0.66), (-0.15, -0.1, -0.64), (0.3, -0.5, -0.6)], "gloves": [(-0.2, 0.6, -0.36), (0.1, 0.2, -0.38), (-0.1, -0.3, -0.34)],
                 "shoes": [(-0.15, 1.0, -0.4), (0.1, 0.6, -0.4), (-0.05, 0.25, -0.36)]}[slot]
        parts.append(("Crack", W.crack_line(crack, 0.12, 0.06), A.GOLD_GLOW, True))
    return parts


def build(zone, slot, grade):
    P = palette(zone, grade)
    col = A.new_collection("%s_%s_%s" % (slot, zone, grade))
    objs = []
    for name, geo, rgb, neon in grade_parts(zone, slot, grade, P):
        objs.append(A.make_obj(name, geo, rgb, col, neon=neon, mat_name="%s_%s_%s_%s" % (slot, zone, grade, name)))
    return col, objs


ICON_TURN = {"armor": 20.0, "gloves": 55.0, "shoes": -40.0}  # 앞(Roblox −Z)은 이미 카메라 쪽 - 아이콘은 대각 굴림 없이 살짝 돌려(도) 옆 두께가 보이게


def parse():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opt = {"zones": list(ZONES), "slots": SLOTS, "grades": list(A.GRADES), "icons": False, "render": None, "export": False}
    i = 0
    while i < len(argv):
        a = argv[i]
        if a in ("--zones", "--slots", "--grades"):
            opt[a[2:]] = argv[i + 1].split(","); i += 1
        elif a == "--render":
            opt["render"] = os.path.abspath(argv[i + 1]); i += 1
        elif a == "--icons":
            opt["icons"] = True
        elif a == "--export":
            opt["export"] = True
        i += 1
    return opt


def main():
    opt = parse()
    os.makedirs(ICON_OUT, exist_ok=True)
    stats = {}
    for zone in opt["zones"]:
        for slot in opt["slots"]:
            for grade in opt["grades"]:
                A.reset()
                col, objs = build(zone, slot, grade)
                tri = sum(A.tri_count(o) for o in objs)
                stats["%s_%s_%s" % (slot, zone, grade)] = tri
                if opt["export"] and grade in ("normal", "legendary", "transcendent"):
                    A.export_fbx(os.path.join(OUT, "%s_%s_%s.fbx" % (slot, zone, grade)), objs)
                if opt["icons"]:
                    I.render_icon(objs, os.path.join(ICON_OUT, "%s_%s_%s.png" % (slot, zone, grade)), base_rot=(0, 0, 0), roll=0.0, tilt=(-12.0, ICON_TURN[slot]), hull=0.03, pad=1.12)
                if opt["render"] and grade in ("normal", "legendary", "transcendent"):
                    A.render_views(objs, os.path.join(opt["render"], "%s_%s_%s" % (slot, zone, grade)), views=("front", "34"), kinds=("game",), sil=True, hull=0.03, res=(500, 500))
    over = {k: v for k, v in stats.items() if v > BUDGET}
    print("[make_armor] 삼각형 최소 %d · 최대 %d · 상한 초과 %s" % (min(stats.values()), max(stats.values()), over))
    if opt["export"]:
        A.write_json(os.path.join(OUT, "armor.meta.json"), {"version": "A2-N1", "triBudget": BUDGET, "tris": stats, "zones": {k: v["theme"] for k, v in ZONES.items()}})
    print("[make_armor] 끝")


if __name__ == "__main__":
    main()
