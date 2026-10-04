# -*- coding: utf-8 -*-
# QUEUE-ALL9E1 블록 1 장비 v3 메시(규격 docs/design/gear-art-v3.md 4 · 5 · 6 · 7절 · 데이터 roblox/src/shared/data/GearV3Data.lua).
#   방어구 = 직업 4 × 부위 3 × 모양 단계 5(s1 일반 / s2 희귀·영웅 / s3 전설 / s4 유물·고대 / s5 태초·초월) = 60 · 문장 6(세트 공용) · 무기 = 4 × 5 = 20.
#   모양 바탕 = make_armor_class(직업 v3.1 - 같은 조각 · 착용 맞춤 그대로) + 단계마다 부품. 조각 이름 = <조각>_<구역>[_<문>]:
#     구역 Body(등급 메인) · Trim(밝은) · Inner(어두운) · Attach(세트 색1 · 천 띠) · Gem(세트 색2 · 보조 보석) · CoreGem(등급 보석 - s4 · s5) · Float(부유 - s4 · s5) · Crack(초월 균열 Neon)
#     문 Ep(영웅만 - 보석 2 · 이중 테두리) · Re(유물만 - 루비 오벌) · An(고대만 - 관 · 깃 층 · 에메랄드 스텝 컷) · Tr(초월만 - 균열 선)
#   1인 MeshPart ≤ 24: 조각마다 쓸 수 있는 구역을 정해(ZONES_OF) 나머지는 그 조각의 대표 구역으로 합친다(작은 조각 = 1파트).
#   착용 맞춤은 게임 코드(ArmorWearView - 손 · 발 +10% · 껍데기 0.15)가 하므로 장갑 · 신발에 가시 · 큰 돌기를 넣지 않는다(5절 ④).
# 실행: bash bl.sh make_gear_v3.py [--classes ..] [--slots ..] [--stages s1,..] [--weapons] [--emblems] [--render 폴더] [--export]
import bpy  # noqa: F401
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import artlib as A  # noqa: E402
import make_armor_wear as AW  # noqa: E402
import make_armor_class as AC  # noqa: E402
import make_weapons as W  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "art", "armor"))
WOUT = os.path.normpath(os.path.join(HERE, "..", "..", "art", "weapons"))
REF = AW.REF
CLASSES = AC.CLASSES
SLOTS = AC.SLOTS
STAGES = ["s1", "s2", "s3", "s4", "s5"]
# GearV3Data.budget 미러(7절)
BUDGET = {"armor": 1500, "gloves": 500, "shoes": 500, "weapon": 800, "float": 300, "coreGem": 120}
PARTS_PER_PLAYER = 24
# 단계 → make_armor_class 외형(바탕 장식 단계)
BASE_LOOK = {"s1": "normal", "s2": "normal", "s3": "legendary", "s4": "legendary", "s5": "legendary"}
# 단계 → 무기 등급(make_weapons 형태) · 문(같은 단계 위 등급 무기)
WEAPON_GRADE = {"s1": "normal", "s2": "rare", "s3": "legendary", "s4": "relic", "s5": "primordial"}
# 미리보기 색(렌더 전용 - 게임 색은 코드가 칠한다: 석조 평원 · 그 단계 아래 등급)
PREVIEW = {"Body": (146, 153, 161), "Trim": (193, 198, 204), "Inner": (98, 107, 117), "Attach": (102, 131, 74), "Gem": (168, 121, 69),
           "CoreGem": (185, 47, 72), "Float": (240, 107, 118), "Crack": (216, 185, 110), "Emblem": (168, 121, 69)}
NEON = {"CoreGem": False, "Float": True, "Crack": True}
# 조각 종류 → 쓸 수 있는 구역(첫째 = 대표 - 나머지는 대표로 합침)
ZONES_OF = {"Chest": ["Body", "Trim", "Inner", "Attach", "Gem", "CoreGem", "Crack"], "Shoulder": ["Body", "Trim"], "Belt": ["Inner"], "Tasset": ["Body"],
            "Glove": ["Inner"], "Bracer": ["Body"], "Boot": ["Inner"], "Greave": ["Body"]}
# make_armor_class 역할 → v3 구역(대검 가슴 태바드 · 등 망토 = 세트 천 = Attach)
ROLE_ZONE = {"base": "Body", "steel": "Body", "leather": "Inner", "trim": "Trim", "grade": "Trim", "glow": "Gem"}


def zone_of(kind, zone):
    allowed = ZONES_OF[kind]
    return zone if zone in allowed else allowed[0]


# ────────────────────────── 보석 컷(2-1절) - 앞(−Z)을 보는 납작한 보석 ──────────────────────────
def facet_lathe(profile, n):
    return A.xform(A.lathe(profile, n), m=A.rot(rx=90))


def cabochon(c, r=0.09):  # 희귀 · 영웅 · 전설: 둥근 면 6 ~ 8
    return A.xform(A.ellipsoid((r, r * 0.8, r * 0.5), n=7, rings=2, squash_bottom=0.2), t=c)


def oval_facet(c, r=0.15):  # 유물 루비 오벌(면 10 ~ 14)
    g = facet_lathe([(0.0, 0.07), (r * 0.62, 0.07), (r, 0.0), (r * 0.5, -0.05), (0.0, -0.07)], 12)
    return A.xform(g, s=(1.0, 1.3, 1.0), t=c)


def step_cut(c, w=0.26, h=0.2):  # 고대 에메랄드 스텝 컷(직사각 계단 면)
    return A.merge(A.box(w, h, 0.06, b=0.03, center=(c[0], c[1], c[2] + 0.02)), A.box(w * 0.7, h * 0.66, 0.06, b=0.02, center=(c[0], c[1], c[2] - 0.03)))


def brilliant(c, r=0.16):  # 태초 · 초월 브릴리언트(원형 다면 16 · 위 평평)
    return A.xform(facet_lathe([(0.0, 0.08), (r * 0.55, 0.08), (r, 0.02), (r * 0.9, -0.01), (0.0, -0.12)], 16), t=c)


def setting_ring(c, r):  # 받침 테(Trim)
    return A.xform(A.lathe([(r, -0.03), (r + 0.04, 0.0), (r, 0.03)], 10), m=A.rot(rx=90), t=c)


# ────────────────────────── 문장 6종(3절 - 세트 공용 · 가슴 앞) ──────────────────────────
def plate(outline, d=0.05):
    n = len(outline)
    v = [(x, y, -d / 2) for x, y in outline] + [(x, y, d / 2) for x, y in outline]
    return v, [tuple(reversed(range(n))), tuple(range(n, 2 * n))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]


def emblem(kind):
    s = 0.22
    if kind == "stone":  # 돌 방패 + 중앙 균열
        g = plate([(-s, s), (s, s), (s, -s * 0.2), (0, -s * 1.15), (-s, -s * 0.2)])
        crack = plate([(-0.02, s * 0.8), (0.03, s * 0.2), (-0.02, -s * 0.2), (0.02, -s * 0.8), (0.0, -s * 0.8), (-0.04, -s * 0.2), (0.01, s * 0.2), (-0.04, s * 0.8)], 0.07)
        return A.merge(g, crack)
    if kind == "crystal":  # 육각 결정 + 작은 별
        hexa = plate([(math.cos(math.radians(30 + 60 * i)) * s, math.sin(math.radians(30 + 60 * i)) * s * 1.15) for i in range(6)])
        star = A.xform(plate([(math.cos(math.radians(90 * i)) * (0.08 if i % 2 == 0 else 0.08), math.sin(math.radians(90 * i)) * 0.08) for i in range(4)], 0.07), m=A.rot(rz=45), t=(s * 0.8, s * 0.9, 0))
        return A.merge(hexa, star)
    if kind == "shell":  # 조개(부채) + 물결
        pts = [(0, -s)] + [(math.cos(math.radians(20 + 140 * i / 8)) * s * 1.1, math.sin(math.radians(20 + 140 * i / 8)) * s * 1.1 - s * 0.35) for i in range(9)]
        wave = A.box(s * 1.8, 0.04, 0.07, center=(0, -s * 0.95, 0))
        return A.merge(plate(pts), wave)
    if kind == "sun":  # 태양 원판 + 짧은 광선
        disc = plate([(math.cos(math.radians(30 * i)) * s * 0.7, math.sin(math.radians(30 * i)) * s * 0.7) for i in range(12)])
        rays = [A.xform(A.box(0.06, 0.12, 0.05), m=A.rot(rz=45 * i), t=(math.cos(math.radians(45 * i + 90)) * s * 0.95, math.sin(math.radians(45 * i + 90)) * s * 0.95, 0)) for i in range(8)]
        return A.merge(disc, *rays)
    if kind == "storm":  # 꺾인 번개 + 작은 구름
        bolt = plate([(-0.05, s), (0.1, s), (0.02, 0.03), (0.12, 0.03), (-0.08, -s * 1.1), (-0.01, -0.05), (-0.11, -0.05)])
        cloud = A.xform(A.ellipsoid((s * 0.75, s * 0.3, 0.05), n=8, rings=2), t=(0, s * 0.95, 0.01))
        return A.merge(bolt, cloud)
    # frost: 육각 눈꽃 + 수정 끝
    arms = [A.xform(A.box(0.05, s * 1.0, 0.05), m=A.rot(rz=60 * i), t=(0, 0, 0)) for i in range(3)]
    tips = [A.xform(A.box(0.09, 0.09, 0.05), m=A.rot(rz=45 + 60 * i), t=(math.cos(math.radians(90 + 60 * i)) * s * 0.5, math.sin(math.radians(90 + 60 * i)) * s * 0.5, 0)) for i in range(6)]
    return A.merge(*arms, *tips)


EMBLEMS = ["stone", "crystal", "shell", "sun", "storm", "frost"]
EMBLEM_AT = (0.0, 0.05, -0.74)  # UpperTorso 로컬(앞 가운데)
CORE_AT = (0.0, 0.52, -0.73)  # 핵심 보석(문장 위 · 목 아래)


# ────────────────────────── 단계 부품(4절 직업별 진화 · 5절 그림과 다르게) ──────────────────────────
def stage_extras(cls, kind, side, stage, z):
    """z = { 구역: [geo] } · 문 부품은 키 (구역, 문)"""
    def add(zone, geo, gate=None):
        z.setdefault((zone, gate) if gate else zone, []).append(geo)

    n = STAGES.index(stage) + 1
    if kind == "Chest":
        # 세트 천(Attach): 대검은 바탕 태바드 · 망토가 이미 Attach - 다른 직업 = 목 스카프 · 앞 띠(부착물 ≤ 25%)
        if cls == "dualblade":
            add("Attach", AW.ring_y(0.74, 0.56, 0.44, 0.07, 0.12, n=8))
        elif cls == "bow":
            add("Attach", A.box(0.36, 1.2, 0.05, b=0.03, center=(-0.55, -0.1, -0.64)))
        elif cls == "healer":
            add("Attach", A.box(0.5, 1.3, 0.05, b=0.03, center=(0, -0.15, -0.66)))
        if n >= 2:  # s2: 가슴 문양 선 2 + 작은 세트 보석
            add("Trim", A.box(1.5, 0.05, 0.04, center=(0, 0.32, -0.66)))
            add("Trim", A.box(1.5, 0.05, 0.04, center=(0, -0.42, -0.66)))
            add("Gem", cabochon((0.62, 0.48, -0.7), 0.08))
            add("Gem", A.merge(cabochon((-0.62, 0.48, -0.7), 0.08), cabochon((0.0, -0.58, -0.7), 0.07)), "Ep")  # 영웅 = 보석 2 더
            add("Trim", AW.ring_y(-0.7, 1.11, 0.62, 0.02, 0.05, n=10), "Ep")  # 이중 테두리
        if 3 <= n <= 4:  # s3 · s4: 금속 테두리(look legendary 바탕) + 문장 받침 테(s5 = 목깃 · 균열이 대신)
            add("Trim", A.xform(A.lathe([(0.27, -0.03), (0.31, 0.0), (0.27, 0.03)], 8), m=A.rot(rx=90), t=EMBLEM_AT))
        if n >= 4:  # s4: 룬 홈(가슴 양옆 세로 획) + 핵심 보석(유물 오벌 · 고대 스텝) + 받침
            add("Trim", A.merge(*[A.box(0.04, 0.3, 0.04, center=(x, 0.0, -0.67)) for x in (-0.82, 0.82)]))
            add("CoreGem", oval_facet(CORE_AT, 0.13), "Re")
            add("CoreGem", step_cut(CORE_AT, 0.24, 0.18), "An")
            add("Trim", setting_ring(CORE_AT, 0.16))
            add("Trim", A.xform(A.box(1.6, 0.16, 0.05, b=0.03), t=(0, 0.86, 0.32)), "An")  # 고대 = 목 뒤 관 · 깃 층
        if n >= 5:  # s5: 브릴리언트 핵심 보석 + 넓은 목깃(치유사 = 왕관형) + 초월 균열
            z.pop(("CoreGem", "Re"), None)
            z.pop(("CoreGem", "An"), None)
            add("CoreGem", brilliant(CORE_AT, 0.15))
            collar = AW.ring_y(0.82, 0.6, 0.46, 0.12 if cls == "healer" else 0.08, 0.2 if cls == "healer" else 0.12, n=8)
            add("Trim", collar)
            add("Crack", A.merge(A.xform(A.box(0.03, 0.55, 0.03), m=A.rot(rz=-22), t=(-0.35, -0.15, -0.69)),
                                 A.xform(A.box(0.03, 0.4, 0.03), m=A.rot(rz=28), t=(0.4, -0.25, -0.69)),
                                 A.xform(A.box(0.025, 0.3, 0.025), m=A.rot(rz=-8), t=(0.0, 0.25, -0.75))), "Tr")
    elif kind == "Shoulder":
        if 2 <= n <= 4:  # 어깨 보호대 테(대검 = 어깨판 겹은 바탕) - s5는 왕관 마루가 대신(예산)
            add("Trim", AW.ring_y(0.1, 0.64, 0.62, 0.03, 0.06, n=9))
        if n >= 5:  # s5 왕관형 어깨(둥근 마루 2 - 가시 금지) · 쌍검 = 좌우 비대칭(오른쪽만)
            if cls != "dualblade" or side > 0:
                ridges = [A.xform(A.ellipsoid((0.12, 0.18, 0.12), n=6, rings=2), t=(side * 0.08, 0.66, dz)) for dz in (-0.22, 0.22)]
                add("Trim", A.merge(*ridges))
    elif kind == "Bracer" and n >= 3 and cls != "dualblade":  # 쌍검 = 바탕 가죽 끈 셋이 이미 테  # 손목 테(돌기 없음 · 6각)
        add("Body", AW.ring_y(0.25, 0.56, 0.56, 0.02, 0.05, n=6))
    elif kind == "Greave" and n >= 3 and cls != "greatsword":  # 대검 정강이는 바탕 판금 테가 이미 있다(쌍 예산)
        add("Body", AW.ring_y(0.35, 0.56, 0.56, 0.02, 0.05, n=6))
    return z


def float_geo(cls, stage):
    """부유 조각(2절 · 5절 ②: s4 = 1 · s5 = 2 ~ 3 작게) - UpperTorso 로컬(어깨 뒤 위)"""
    n = 1 if stage == "s4" else (2 if cls == "healer" else 3)
    pts = [(1.25, 0.95, 0.25), (-1.25, 0.95, 0.25), (0.0, 1.35, 0.6)][:n]
    size = 0.22 if stage == "s4" else 0.16
    if cls == "dualblade":  # 작은 부유 칼날
        return A.merge(*[A.xform(A.box(0.05, size * 2.2, size * 0.5), m=A.rot(rz=20), t=p) for p in pts])
    if cls == "bow":  # 화살통 부유 장식(깃 조각)
        return A.merge(*[A.xform(A.crystal(size * 1.8, size * 0.45, sides=4, tip_h=0.1, base_h=0.05), t=p) for p in pts])
    if cls == "healer":  # 작은 부유 성물(고리)
        return A.merge(*[A.xform(A.lathe([(size, -0.03), (size + 0.05, 0), (size, 0.03)], 6), m=A.rot(rx=90), t=p) for p in pts])
    return A.merge(*[A.shard(size, seed=i, center=p) for i, p in enumerate(pts)])


def piece_zones(cls, slot, stage, piece):
    kind = piece.split("_")[0]
    side = -1 if piece.endswith("_L") else 1
    fn = {"Chest": lambda: AC.chest(cls), "Shoulder": lambda: AC.shoulder(cls, side), "Belt": lambda: AC.belt(cls), "Tasset": lambda: AC.tasset(cls, side),
          "Glove": lambda: AC.glove(cls, side), "Bracer": lambda: AC.bracer(cls, side), "Boot": lambda: AC.boot(cls), "Greave": lambda: AC.greave(cls)}[kind]
    r = fn()
    look = BASE_LOOK[stage] if slot == "armor" else "normal"  # 장갑 · 신발 = 바탕 장식 일반 고정(쌍 ≤ 500 · +10% - 단계 차이는 테 · 색)
    AC.look_extra(cls, kind, side, look, r)
    AC.detail_v31(cls, kind, side, look, r)
    z = {}
    for role, geos in r.items():
        if not geos:
            continue
        zone = ROLE_ZONE[role]
        if cls == "greatsword" and kind == "Chest" and role == "base":
            zone = "Attach"  # 대검 태바드 · 등 망토 = 세트 천(② 시안)
        z.setdefault(zone_of(kind, zone), []).extend(geos)
    stage_extras(cls, kind, side, stage, z)
    # 허용 밖 구역 → 대표로 합침(문 부품은 따로 유지 - 문은 그 등급에서만 보이는 별도 파트)
    out = {}
    for key, geos in z.items():
        zone, gate = (key if isinstance(key, tuple) else (key, None))
        zz = zone_of(kind, zone)
        out.setdefault((zz, gate), []).extend(geos)
    return out


def build(cls, slot, stage):
    col = A.new_collection("%s_%s_%s" % (slot, cls, stage))
    objs, info = [], {}
    for piece, part in AC.PIECES[cls][slot]:
        pc, _ = REF[part]
        for (zone, gate), geos in sorted(piece_zones(cls, slot, stage, piece).items(), key=lambda kv: (kv[0][0], kv[0][1] or "")):
            name = "%s_%s%s" % (piece, zone, ("_" + gate) if gate else "")
            o = A.make_obj(name, A.xform(A.merge(*geos), t=pc), PREVIEW[zone], col, neon=NEON.get(zone, False), origin=pc, mat_name="%s_%s_%s_%s" % (slot, cls, stage, name))
            objs.append(o)
            info[name] = part
    if slot == "armor" and stage in ("s4", "s5"):
        pc, _ = REF["UpperTorso"]
        o = A.make_obj("Float_Float", A.xform(float_geo(cls, stage), t=pc), PREVIEW["Float"], col, neon=True, origin=pc, mat_name="%s_%s_%s_Float" % (slot, cls, stage))
        objs.append(o)
        info["Float_Float"] = "UpperTorso"
    return col, objs, info


def build_emblem(kind):
    col = A.new_collection("emblem_" + kind)
    pc, _ = REF["UpperTorso"]
    g = A.xform(emblem(kind), t=(pc[0] + EMBLEM_AT[0], pc[1] + EMBLEM_AT[1], pc[2] + EMBLEM_AT[2]))
    o = A.make_obj("Emblem", g, PREVIEW["Emblem"], col, origin=pc, mat_name="emblem_" + kind)
    return col, [o], {"Emblem": "UpperTorso"}


# ────────────────────────── 무기(5 단계 · 구역) ──────────────────────────
W_ZONE = {"Blade": "Body", "Head": "Body", "Shaft": "Body", "Limb_U": "Body", "Limb_L": "Body", "Limbs": "Body", "Riser": "Body", "Fuller": "Trim", "Guard": "Trim", "Pommel": "Trim",
          "Grip": "Inner", "Gem": "CoreGem", "Runes": "Trim", "Wing_R": "Trim", "Wing_L": "Trim", "Crystals": "Float", "Halo": "Float", "Shards": "Float", "Crack1": "Crack", "Crack2": "Crack", "String": "Inner"}


def weapon_parts(weapon, stage):
    """[(이름, geo, 구역, 문)] - 형태 = make_weapons(단계 등급) · 초월 문 = 균열 · 흑요석은 색(코드)"""
    out = []
    for name, geo, _rgb, neon, _bev in W.BUILDERS[weapon](WEAPON_GRADE[stage]):
        if stage == "s5" and name == "Halo" and weapon in ("bow", "healer"):
            continue  # 초월 균열 자리(예산 800) - 태초 빛 테는 대검 · 쌍검만
        zone = W_ZONE.get(name.split("_")[0] if name not in W_ZONE else name, "Trim" if not neon else "Float")
        out.append((name, geo, zone, None))
    if stage == "s5":  # 초월 = 태초 형태 + 금빛 균열(make_weapons 초월 균열 · 보라 금지 → 색은 코드: 흑요석 #202127 + 균열 #D8B96E)
        for name, geo, _rgb, neon, _bev in W.BUILDERS[weapon]("transcendent"):
            if name.startswith("Crack"):
                out.append((name, geo, "Crack", "Tr"))
    return out


def build_weapon(weapon, stage):
    col = A.new_collection("%s_%s" % (weapon, stage))
    objs = []
    for name, geo, zone, gate in weapon_parts(weapon, stage):
        nm = "%s_%s%s" % (name, zone, ("_" + gate) if gate else "")
        o = A.make_obj(nm, geo, PREVIEW[zone], col, neon=NEON.get(zone, False), bevel=0.022 if (weapon == "greatsword" and name == "Blade") else 0.0, bevel_angle=50.0, mat_name="%s_%s_%s" % (weapon, stage, nm))
        objs.append(o)
    return col, objs


def parse():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opt = {"classes": CLASSES, "slots": SLOTS, "stages": STAGES, "render": None, "export": False, "weapons": False, "emblems": False, "armor": True}
    i = 0
    while i < len(argv):
        a = argv[i]
        if a in ("--classes", "--slots", "--stages"):
            opt[a[2:]] = argv[i + 1].split(","); i += 1
        elif a == "--render":
            opt["render"] = os.path.abspath(argv[i + 1]); i += 1
        elif a == "--export":
            opt["export"] = True
        elif a == "--weapons":
            opt["weapons"] = True
        elif a == "--emblems":
            opt["emblems"] = True
        elif a == "--no-armor":
            opt["armor"] = False
        i += 1
    return opt


def gate_visible_count(objs, gate_of_grade):
    """그 등급에서 실제로 보이는 파트 수(문 파트는 그 등급만)"""
    return sum(1 for o in objs if (len(o.name.split("_")) < 3 or o.name.split("_")[-1] not in ("Ep", "Re", "An", "Tr") or o.name.split("_")[-1] == gate_of_grade))


def main():
    opt = parse()
    stats, pieces_meta, wstats = {}, {}, {}
    if opt["armor"]:
        for cls in opt["classes"]:
            for slot in opt["slots"]:
                for stage in opt["stages"]:
                    A.reset()
                    col, objs, info = build(cls, slot, stage)
                    key = "%s_%s_%s" % (slot, cls, stage)
                    tri = sum(A.tri_count(o) for o in objs)
                    core = max([A.tri_count(o) for o in objs if "_CoreGem" in o.name] or [0])  # 문 파트(Re · An)는 한 번에 하나만 보인다
                    flo = sum(A.tri_count(o) for o in objs if "_Float" in o.name)
                    worst_parts = max(gate_visible_count(objs, g) for g in (None, "Ep", "Re", "An", "Tr"))
                    stats[key] = dict(tris=tri, parts=len(objs), visibleParts=worst_parts, coreGem=core, float=flo)
                    limit = BUDGET["armor"] if slot == "armor" else BUDGET[slot.replace("gloves", "gloves").replace("shoes", "shoes")]
                    if tri > limit or core > BUDGET["coreGem"] or flo > BUDGET["float"]:
                        print("[make_gear_v3] 예산 초과", key, tri, core, flo)
                    if opt["export"]:
                        A.export_fbx(os.path.join(OUT, "%s.fbx" % key), objs)
                        for o in objs:
                            pc = REF[info[o.name]][0]
                            cen = A.roblox_center(o)
                            pieces_meta.setdefault(key, {})[o.name] = dict(attach=info[o.name], offset=[round(cen[i] - pc[i], 3) for i in range(3)],
                                                                           refSize=list(REF[info[o.name]][1]), tris=A.tri_count(o), neon=bool(o.get("Neon", False)))
                    if opt["render"]:
                        man = AW.mannequin(slot)
                        A.render_views(objs + man, os.path.join(opt["render"], key), views=("front", "34"), kinds=("game",), sil=False, hull=0.03, res=(520, 700))
    if opt["emblems"]:
        for kind in EMBLEMS:
            A.reset()
            col, objs, info = build_emblem(kind)
            key = "emblem_%s" % kind
            stats[key] = dict(tris=sum(A.tri_count(o) for o in objs), parts=1, visibleParts=1, coreGem=0, float=0)
            if opt["export"]:
                A.export_fbx(os.path.join(OUT, "%s.fbx" % key), objs)
                o = objs[0]
                pc = REF["UpperTorso"][0]
                cen = A.roblox_center(o)
                pieces_meta[key] = {"Emblem": dict(attach="UpperTorso", offset=[round(cen[i] - pc[i], 3) for i in range(3)], refSize=list(REF["UpperTorso"][1]), tris=A.tri_count(o), neon=False)}
            if opt["render"]:
                A.render_views(objs, os.path.join(opt["render"], key), views=("front",), kinds=("game",), sil=False, hull=0.0, res=(300, 300))
    if opt["weapons"]:
        for weapon in ["greatsword", "dualblade", "bow", "healer"]:
            for stage in opt["stages"]:
                A.reset()
                col, objs = build_weapon(weapon, stage)
                key = "%s_%s" % (weapon, stage)
                tri = sum(A.tri_count(o) for o in objs)
                wstats[key] = dict(tris=tri, parts=len(objs))
                if tri > BUDGET["weapon"]:
                    print("[make_gear_v3] 무기 예산 초과", key, tri)
                if opt["export"]:
                    A.export_fbx(os.path.join(WOUT, "%s.fbx" % key), objs)
                if opt["render"]:
                    A.render_views(objs, os.path.join(opt["render"], key), views=("front", "34"), kinds=("game",), sil=False, hull=0.0, res=(520, 700))
    if stats:
        print("[make_gear_v3] 방어구 %d · 삼각형 최대 %s · 보이는 파트 최대 %d" % (len(stats), max(stats.items(), key=lambda kv: kv[1]["tris"]), max(v["visibleParts"] for v in stats.values())))
    if wstats:
        print("[make_gear_v3] 무기 %d · 삼각형 최대 %s" % (len(wstats), max(wstats.items(), key=lambda kv: kv[1]["tris"])))
    A.write_json(os.path.join(OUT, "gear_v3.stats.json"), {"armor": stats, "weapons": wstats})
    if opt["export"] and pieces_meta:
        path = os.path.join(OUT, "armor_wear.meta.json")
        old = json.load(open(path, encoding="utf-8")) if os.path.exists(path) else {}
        allp = old.get("pieces", {})
        allp.update(pieces_meta)
        old.update({"pieces": allp})
        A.write_json(path, old)
    print("[make_gear_v3] 끝")


if __name__ == "__main__":
    main()
