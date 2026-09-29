# -*- coding: utf-8 -*-
# A2-N1 펫(Blender bpy): PetData.rigs 몸 틀 3종(dog · cat · dragon) × 알 등급 3(normal · good · rare) 외형 차이.
#   파트 이름 · 중심 위치 = PetData 그대로(코드가 이름 · 중심으로 움직인다 - 원점 = 파트 pos) · 파트 수 고정(≤ 8) → 등급 차이는 같은 파트 안의 형태 추가:
#     보통 = 기본형 · 좋은 = 목 털 · 큰 꼬리(실루엣 한 단계) · 희귀 = 거기에 머리 볏 · 꼬리 끝 장식(한 단계 더 - 빛은 코드 PointLight).
#   색 = 코드가 구역 색을 입힌다(여기 색은 렌더용: base = 구역 색 예시 · accent = ×0.55 · eye = 검정). 크기 = 캐릭터 머리(≈ 1.2).
#   예산 = art-direction §6에 펫 칸이 없어 무기와 같은 800(따라다니는 모델) - 보고서 결정 필요.
# 실행: bash bl.sh make_pets.py --items dog:normal,dog:good,... [--render 폴더] [--old] [--no-export]
import bpy
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import artlib as A  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "art", "pets"))
BUDGET = 800
RANK = {"normal": 0, "good": 1, "rare": 2}
BASE = {"dog": (170, 90, 255), "cat": (40, 140, 255), "dragon": (255, 150, 60)}  # 렌더 예시 = 구역 관문 색(T1 · T3 · T4)

# PetData.rigs 그대로(이름 · 크기 · 중심 · 색 역할 · 쐐기)
RIGS = {
    "dog": [("Body", (0.7, 0.55, 1.0), (0, 0, 0), "base"), ("Head", (0.6, 0.55, 0.55), (0, 0.4, -0.6), "base"), ("Ear_L", (0.14, 0.3, 0.2), (-0.26, 0.62, -0.55), "accent"),
            ("Ear_R", (0.14, 0.3, 0.2), (0.26, 0.62, -0.55), "accent"), ("Leg_F", (0.6, 0.3, 0.2), (0, -0.4, -0.3), "accent"), ("Leg_B", (0.6, 0.3, 0.2), (0, -0.4, 0.3), "accent"),
            ("Tail", (0.14, 0.14, 0.4), (0, 0.2, 0.62), "accent"), ("Eyes", (0.4, 0.1, 0.05), (0, 0.48, -0.88), "eye")],
    "cat": [("Body", (0.6, 0.5, 1.0), (0, 0, 0), "base"), ("Head", (0.6, 0.5, 0.5), (0, 0.42, -0.58), "base"), ("Ear_L", (0.18, 0.24, 0.1), (-0.2, 0.78, -0.58), "accent"),
            ("Ear_R", (0.18, 0.24, 0.1), (0.2, 0.78, -0.58), "accent"), ("Leg_F", (0.5, 0.3, 0.18), (0, -0.38, -0.3), "accent"), ("Leg_B", (0.5, 0.3, 0.18), (0, -0.38, 0.3), "accent"),
            ("Tail", (0.12, 0.7, 0.12), (0, 0.35, 0.6), "accent"), ("Eyes", (0.38, 0.1, 0.05), (0, 0.48, -0.84), "eye")],
    "dragon": [("Body", (0.6, 0.55, 0.9), (0, 0, 0), "base"), ("Head", (0.55, 0.5, 0.6), (0, 0.4, -0.6), "base"), ("Horn", (0.4, 0.2, 0.1), (0, 0.72, -0.5), "accent"),
               ("Wing_L", (0.9, 0.06, 0.5), (-0.7, 0.3, 0), "accent"), ("Wing_R", (0.9, 0.06, 0.5), (0.7, 0.3, 0), "accent"), ("Tail", (0.16, 0.16, 0.7), (0, 0, 0.75), "accent"),
               ("Eyes", (0.36, 0.1, 0.05), (0, 0.48, -0.91), "eye")],
}


def color(role, body):
    return {"base": BASE[body], "accent": A.mul(BASE[body], 0.55), "eye": (25, 18, 22)}[role]


def add(a, b):
    return tuple(a[i] + b[i] for i in range(3))


def eyes(c, dx, r=(0.07, 0.09, 0.04)):
    return A.merge(*[A.ellipsoid(r, n=6, rings=3, center=add(c, (s * dx, 0, 0))) for s in (-1, 1)])


def ruff(center, r, k=8, y=0.0):
    """목 털: 머리와 몸 사이 뾰족 털 고리(좋은 이상)"""
    tufts = []
    for i in range(k):
        a = 2 * math.pi * i / k
        base = add(center, (r * 0.7 * math.cos(a), y, r * 0.7 * math.sin(a)))
        tip = add(center, (r * 1.15 * math.cos(a), y - 0.08, r * 1.15 * math.sin(a)))
        tufts.append(A.tube([base, tip], lambda u: 0.11 * (1 - u) + 0.01, sides=4, tip_end=True))
    return A.merge(A.ellipsoid((r * 0.8, 0.12, r * 0.8), n=8, rings=3, center=add(center, (0, y, 0))), *tufts)


def dog(grade):
    g = RANK[grade]
    o = {}
    o["Body"] = A.merge(A.ellipsoid((0.4, 0.33, 0.54), n=9, rings=5, center=(0, 0.02, 0.02)),
                        *([ruff((0, 0.2, -0.36), 0.46, k=5, y=0.0)] if g >= 1 else []))  # 좋은 = 5갈래 톱니 칼라(몸 폭 1.2배)
    head = A.merge(A.ellipsoid((0.35, 0.32, 0.31), n=9, rings=5, center=(0, 0.42, -0.6)),
                   A.ellipsoid((0.17, 0.13, 0.16), n=7, rings=4, center=(0, 0.33, -0.86)),  # 주둥이
                   A.ellipsoid((0.06, 0.05, 0.05), n=6, rings=3, center=(0, 0.38, -1.0)))  # 코
    if g >= 2:  # 머리 볏(털 세 가닥)
        head = A.merge(head, *[A.tube([(dx, 0.7, -0.6), (dx * 1.6, 0.88, -0.52 - 0.04 * abs(dx) * 10)], lambda u: 0.07 * (1 - u) + 0.01, sides=4, tip_end=True) for dx in (-0.07, 0.0, 0.07)])
    o["Head"] = head
    for n, s in (("Ear_L", -1), ("Ear_R", 1)):  # 늘어진 귀(안쪽 → 바깥 아래)
        path = [(s * 0.2, 0.66, -0.56), (s * 0.34, 0.62, -0.54), (s * 0.4, 0.44, -0.52), (s * 0.37, 0.3 if g < 2 else 0.26, -0.5)]
        o[n] = A.tube(A.bezier(*path, n=5), lambda u: 0.09 + 0.03 * math.sin(math.pi * u), sides=5, flat=0.45, tip_end=False)
    for n, z in (("Leg_F", -0.3), ("Leg_B", 0.3)):
        leg = A.merge(A.lathe([(0.0, -0.18), (0.11, -0.16), (0.085, 0.0), (0.09, 0.15), (0.0, 0.16)], 6), A.ellipsoid((0.1, 0.05, 0.12), n=6, rings=2, center=(0, -0.16, -0.04)))
        o[n] = A.merge(*[A.xform(leg, t=(s * 0.2, -0.4, z)) for s in (-1, 1)])  # 다리 한 쌍 = 파트 하나(리그 Leg_F · Leg_B)
    k = 1.0 if g == 0 else 1.2
    tip = (0, 0.12 + 0.24 * k, 0.5 + 0.24 * k)  # 짧은 꼬리(≤ 0.35) · 45° 위 - 고양이의 긴 S자와 구별
    tail = A.tube([(0, 0.1, 0.46), (0, 0.2, 0.6), tip], lambda u: 0.085 * (1 - 0.4 * u) + 0.02, sides=6, tip_end=False)
    if g >= 2:  # 꼬리 끝 털 뭉치
        tail = A.merge(tail, A.ellipsoid((0.12, 0.12, 0.12), n=7, rings=4, center=tip))
    o["Tail"] = tail
    o["Eyes"] = eyes((0, 0.5, -0.86), 0.14)
    return o


def cat(grade):
    g = RANK[grade]
    o = {}
    o["Body"] = A.merge(A.ellipsoid((0.33, 0.28, 0.52), n=9, rings=5, center=(0, 0.0, 0.02)),
                        *([ruff((0, 0.2, -0.36), 0.32, y=0.0, k=7)] if g >= 1 else []))
    head = A.merge(A.ellipsoid((0.36, 0.28, 0.28), n=9, rings=5, center=(0, 0.42, -0.58)),
                   *[A.ellipsoid((0.12, 0.09, 0.1), n=6, rings=3, center=(s * 0.26, 0.32, -0.62)) for s in (-1, 1)])  # 볼 털
    o["Head"] = head
    for n, s in (("Ear_L", -1), ("Ear_R", 1)):  # 세모 귀(희귀 = 귀 끝 털)
        ear = A.xform(A.lathe([(0.0, 0.0), (0.11, 0.0), (0.0, 0.26)], 4), s=(1, 1, 0.55), m=A.rot(rz=-s * 12), t=(s * 0.2, 0.64, -0.58))
        if g >= 2:
            ear = A.merge(ear, A.tube([(s * 0.25, 0.86, -0.58), (s * 0.3, 1.0, -0.58)], lambda u: 0.04 * (1 - u) + 0.005, sides=3, tip_end=True))
        o[n] = ear
    leg = lambda x, z: A.xform(A.merge(A.lathe([(0.0, -0.16), (0.09, -0.16), (0.08, 0.0), (0.075, 0.15), (0.0, 0.16)], 6), A.ellipsoid((0.09, 0.045, 0.1), n=6, rings=3, center=(0, -0.15, -0.03))), t=(x, -0.38, z))
    o["Leg_F"] = A.merge(leg(-0.17, -0.3), leg(0.17, -0.3))
    o["Leg_B"] = A.merge(leg(-0.17, 0.3), leg(0.17, 0.3))
    k = 1.0 if g == 0 else 1.2
    tail_path = A.bezier((0, 0.05, 0.5), (0, 0.2, 0.75), (0, 0.55 * k, 0.55), (0.12, 0.78 * k, 0.72), n=7)  # 위로 선 S자 긴 꼬리
    th = 1.0 if g == 0 else 1.5  # 좋은 = 꼬리 1.5배 + 끝 뭉치
    tail = A.tube(tail_path, lambda u: th * (0.07 * (1 - 0.3 * u) + 0.02), sides=6, tip_end=False)
    if g >= 1:
        tail = A.merge(tail, A.ellipsoid((0.17, 0.17, 0.17), n=7, rings=4, center=(0.12, 0.78 * k, 0.72)))
    if g >= 2:  # 희귀 = 두 갈래 꼬리 끝
        tail = A.merge(tail, A.tube([(0.12, 0.78 * k, 0.72), (0.26, 0.92 * k, 0.66)], lambda u: 0.06 * (1 - u) + 0.01, sides=5, tip_end=True),
                       A.tube([(0.12, 0.78 * k, 0.72), (0.0, 0.95 * k, 0.8)], lambda u: 0.06 * (1 - u) + 0.01, sides=5, tip_end=True))
    o["Tail"] = tail
    o["Eyes"] = eyes((0, 0.48, -0.83), 0.14, r=(0.065, 0.1, 0.04))
    return o


def pet_wing(s, fingers):
    """작은 막 날개(XY 평면에 짓고 앞 −Z로 두께) - 손가락 수 = 등급"""
    tips = [(0.95, 0.42), (0.9, 0.0), (0.62, -0.3)][:fingers]
    outline = [(0.05, 0.12)]
    prev = None
    for fx, fy in tips:
        if prev:
            outline.append(((prev[0] + fx) / 2 * 0.78, (prev[1] + fy) / 2 * 0.78))
        outline.append((fx, fy))
        prev = (fx, fy)
    outline.append((0.08, -0.18))
    n = len(outline)
    v = [(x, y, 0.03) for x, y in outline] + [(x, y, -0.03) for x, y in outline]
    f = [tuple(range(n)), tuple(reversed(range(n, 2 * n)))] + [(i, n + i, n + (i + 1) % n, (i + 1) % n) for i in range(n)]
    bones = [A.tube([(0.0, 0.05, 0), (fx, fy, 0)], lambda u: 0.045 * (1 - u) + 0.012, sides=4, tip_end=True) for fx, fy in tips]
    g = A.merge((v, f), *bones)
    g = A.xform(g, m=A.rot(rx=40))  # 날개 판을 50° 기울인다(수평이면 정면에서 선 · 세우면 Z축 날갯짓이 판 안에서 돌아 안 보인다)
    return A.mirror_x(g) if s < 0 else g


def dragon(grade):
    g = RANK[grade]
    o = {}
    body = A.ellipsoid((0.32, 0.3, 0.46), n=9, rings=5, center=(0, 0, 0.02))
    belly = A.ellipsoid((0.22, 0.2, 0.3), n=8, rings=4, center=(0, -0.08, -0.12))
    spikes = [A.crystal(0.3, 0.08, sides=4, tip_h=0.14, base_h=0.04, center=(0, 0.34, z), m=A.rot(rx=20)) for z in (-0.15, 0.1, 0.32)] if g >= 1 else []  # 좋은 = 등 가시 높이 0.25
    o["Body"] = A.merge(body, belly, *spikes)
    o["Head"] = A.xform(A.merge(A.ellipsoid((0.3, 0.27, 0.3), n=9, rings=5, center=(0, 0.42, -0.58)), A.ellipsoid((0.2, 0.14, 0.18), n=7, rings=4, center=(0, 0.34, -0.84))), s=(1.15, 1.15, 1.15), t=(0, 0.42 * -0.15, -0.6 * -0.15))  # 머리 ×1.15(중심 고정)
    horns = [A.tube(A.bezier((s * 0.13, 0.6, -0.52), (s * 0.18, 0.74, -0.46), (s * 0.2, 0.84, -0.36), (s * 0.18, 0.88, -0.28), n=4), lambda u: 0.06 * (1 - u) + 0.01, sides=5, tip_end=True) for s in (-1, 1)]
    if g >= 2:  # 희귀 = 뿔 왕관 3(가운데 하나 더)
        horns.append(A.tube([(0, 0.66, -0.5), (0, 0.84, -0.46), (0.02, 1.0, -0.38)], lambda u: 0.09 * (1 - u) + 0.01, sides=5, tip_end=True))  # 가운데 뿔 = 머리 높이의 40%
    o["Horn"] = A.merge(*horns)
    fingers = 2  # 날개 뼈 2갈래(몸을 삼키지 않게)
    for n, s in (("Wing_L", -1), ("Wing_R", 1)):
        o[n] = A.xform(pet_wing(s, fingers), m=A.rot(rz=s * 32), t=(s * 0.22, 0.3, 0.0), s=(0.7 if g < 2 else 0.82, 1, 0.7 if g < 2 else 0.82))  # 폭 70%(희귀 82%)
    tail = A.tube(A.bezier((0, 0.0, 0.4), (0, -0.05, 0.7), (0.08, 0.05, 0.95), (0.15, 0.15, 1.1), n=6), lambda u: 0.12 * (1 - u) + 0.03, sides=6, tip_end=False)
    spade = 0.13 if g < 2 else 0.2  # 꼬리 끝 스페이드(희귀 = 크게)
    tail = A.merge(tail, A.xform(A.lathe([(0.0, 0.0), (spade, 0.08), (spade * 0.6, 0.18), (0.0, 0.3)], 4), s=(1, 1, 0.35), m=A.rot(rx=-60), t=(0.15, 0.15, 1.1)))
    o["Tail"] = tail
    o["Eyes"] = eyes((0, 0.48, -0.86), 0.13, r=(0.07, 0.09, 0.04))
    return o


BUILD = {"dog": dog, "cat": cat, "dragon": dragon}


def old_geo(size, pos, wedge=False):
    return A.box(*size, center=pos)


def build(body, grade, old=False):
    col = A.new_collection("%s%s_%s" % ("old_" if old else "", body, grade))
    geos = None if old else BUILD[body](grade)
    objs = []
    for name, size, pos, role in RIGS[body]:
        geo = old_geo(size, pos) if old else geos[name]
        objs.append(A.make_obj(name, geo, color(role, body), col, origin=pos, mat_name="%s%s_%s_%s" % ("old_" if old else "", body, grade, name)))
    return col, objs


def parse():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opt = {"items": [], "render": None, "export": True, "old": False}
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--items":
            opt["items"] = [tuple(x.split(":")) for x in argv[i + 1].split(",")]; i += 1
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
    A.reset()
    metas = {}
    for body, grade in opt["items"]:
        col, objs = build(body, grade)
        total = sum(A.tri_count(o) for o in objs)
        print("[make_pets] %s %s 파트 %d · 삼각형 %d / %d = %.0f%% · %s" % (body, grade, len(objs), total, BUDGET, 100 * total / BUDGET, {o.name: A.tri_count(o) for o in objs}))
        metas.setdefault(body, {})[grade] = A.meta_of(objs, BUDGET)
        if opt["export"]:
            A.export_fbx(os.path.join(OUT, "%s_%s.fbx" % (body, grade)), objs)
        if opt["render"]:
            A.render_views(objs, os.path.join(opt["render"], "%s_%s" % (body, grade)), views=("front", "34", "side"), hull=0.02, res=(600, 600))
        for o in objs:
            o.name = "%s.%s" % (o.name, grade)
            o.hide_render = True
        if opt["old"] and grade == "normal" and opt["render"]:
            _, olds = build(body, grade, old=True)
            A.render_views(olds, os.path.join(opt["render"], "old_%s" % body), views=("34",), kinds=("game",), sil=False, hull=0.02, res=(600, 600))
            for o in olds:
                o.hide_render = True
    if opt["export"]:
        for body, looks in metas.items():
            A.write_json(os.path.join(OUT, "%s.meta.json" % body), {"version": "A2-N1", "body": body, "pivot": "파트 중심(PetData pos)", "triBudget": BUDGET, "looks": looks})
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "pets.blend"))
    print("[make_pets] 끝")


if __name__ == "__main__":
    main()
