# -*- coding: utf-8 -*-
# QUEUE-ALL1 ★0-2 카툰 나무 세트(Blender bpy): 필드 나무(PropData Common_Tree 틀 - 충돌 = 줄기 원기둥 · 잎 공 2개) · 허브 큰 나무 잎 뭉치 덮개.
#   줄기(trunk_*) = 틀 공간(원점 = 틀 피벗 · 줄기 원기둥 y −1 ~ 13 · 잎 공 (0, 15, 0) 16×11×16 · (3, 20, −2) 11×8×11)에 짓는다 - 뿌리 벌어짐 · 갈라진 가지 · 살짝 휨.
#   잎 덩어리(clump_*) = 단위 공(지름 1 · 가운데 원점)에 맞춘 울퉁불퉁한 뭉치 3색: Leaves(중간) · Deco_Dark(아랫면) · Deco_Light(윗면 돌출) - 쓰는 쪽이 잎 공 크기로 늘린다.
#   색 = 미리보기용(게임은 TreeArtData 팔레트로 칠한다 - 같은 메시를 구역마다 다른 색으로 재사용). 예산: 나무 1그루(줄기 + 덩어리 2) ≤ 1,500 삼각형.
#   출력: roblox/art/props/trees/<이름>.fbx · trees.meta.json · --render <폴더> = game 렌더(조립한 나무 4종 + 덩어리)
# 실행: bash bl.sh make_trees.py [--render 폴더]
import bpy
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import artlib as A  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "art", "props", "trees"))
TREE_BUDGET = 1500
BARK = (112, 76, 52)
LEAF = (98, 150, 72)
LEAF_DARK = (62, 104, 56)
LEAF_LIGHT = (150, 196, 98)


def lumpy(r, center, seed, n=8, rings=4, jag=0.13, squash=1.0):
    """저폴리 타원체 + 점마다 반지름 흔들림(가장자리 들쭉날쭉한 실루엣)"""
    rnd = random.Random(seed)
    v, f = A.ellipsoid(r=r, n=n, rings=rings, center=(0, 0, 0), squash_bottom=squash)
    out = []
    for p in v:
        k = 1 + rnd.uniform(-jag, jag)
        out.append((p[0] * k + center[0], p[1] * k + center[1], p[2] * k + center[2]))
    return out, f


def clump(seed):
    """단위 공(지름 1) 안 뭉치: 가운데 큰 덩어리 + 둘레 덩어리 4 · 아랫면 어두운 납작 덩어리 2 · 윗면 밝은 작은 덩어리 3"""
    rnd = random.Random(seed)
    main = [lumpy((0.3, 0.26, 0.3), (0, 0.02, 0), seed * 10)]
    for i in range(4):
        a = 2 * math.pi * i / 4 + rnd.uniform(-0.4, 0.4)
        d = rnd.uniform(0.17, 0.22)
        main.append(lumpy((rnd.uniform(0.2, 0.25), rnd.uniform(0.17, 0.21), rnd.uniform(0.2, 0.25)),
                          (math.cos(a) * d, rnd.uniform(-0.06, 0.05), math.sin(a) * d), seed * 10 + i + 1))
    dark = []
    for i in range(2):
        a = math.pi * i + rnd.uniform(-0.5, 0.5)
        dark.append(lumpy((0.26, 0.1, 0.24), (math.cos(a) * 0.1, -0.16, math.sin(a) * 0.1), seed * 20 + i, jag=0.1))
    light = []
    for i in range(3):
        a = 2 * math.pi * i / 3 + rnd.uniform(-0.5, 0.5)
        d = rnd.uniform(0.08, 0.15)
        light.append(lumpy((0.15, 0.11, 0.15), (math.cos(a) * d, 0.2 + rnd.uniform(-0.02, 0.03), math.sin(a) * d), seed * 30 + i, jag=0.12))
    return A.merge(*main), A.merge(*dark), A.merge(*light)


def trunk(kind, seed):
    """틀 공간 줄기. kind = oak(곧고 두 갈래) · twin(굵고 세 갈래) · lean(해안 - 한쪽으로 기움)"""
    rnd = random.Random(seed)
    lean = {"oak": (0.4, 0.3), "twin": (-0.3, 0.2), "lean": (2.6, -1.0)}[kind]
    top = (lean[0], 12.6, lean[1])
    path = A.bezier((0, -1, 0), (0, 4, 0), (top[0] * 0.3, 8.5, top[2] * 0.3), top, n=7)
    base_r = {"oak": 1.5, "twin": 1.7, "lean": 1.4}[kind]
    geo = [A.tube(path, lambda u: base_r * (1.5 - 0.55 * u) if u < 0.18 else base_r * (1.0 - 0.45 * u), sides=7, cap0=True, tip_end=False)]
    # 뿌리 4갈래(바닥 쪽으로 벌어짐)
    for i in range(4):
        a = 2 * math.pi * i / 4 + rnd.uniform(-0.3, 0.3)
        d = (math.cos(a), 0, math.sin(a))
        root = A.bezier((d[0] * 0.5, 0.9, d[2] * 0.5), (d[0] * 1.3, 0.3, d[2] * 1.3), (d[0] * 2.0, -0.2, d[2] * 2.0), (d[0] * 2.6, -0.7, d[2] * 2.6), n=3)
        geo.append(A.tube(root, lambda u: 0.55 * (1 - 0.7 * u), sides=5, cap0=False, tip_end=True))
    # 가지: 잎 공(아래 (0,15,0) · 위 (3,20,−2)) 쪽으로
    tips = {"oak": [(-3.5, 15.5, 1.5), (3.0, 18.5, -1.8)], "twin": [(-4.0, 14.5, -2.0), (3.5, 19.0, -2.0), (1.0, 16.0, 3.5)], "lean": [(-1.0, 15.0, 1.0), (4.0, 18.5, -2.5)]}[kind]
    for i, tip in enumerate(tips):
        start_y = 8.8 + i * 1.1
        t = (start_y + 1) / 13.6
        sx, sz = top[0] * t * t, top[2] * t * t
        start = (sx, start_y, sz)
        mid = (start[0] + (tip[0] - start[0]) * 0.45, start[1] + (tip[1] - start[1]) * 0.7, start[2] + (tip[2] - start[2]) * 0.45)
        br = A.bezier(start, mid, (tip[0] * 0.9, tip[1] - 0.4, tip[2] * 0.9), tip, n=4)
        geo.append(A.tube(br, lambda u: 0.55 * (1 - 0.6 * u), sides=6, cap0=False, tip_end=True))
    return A.merge(*geo)


def crown(kind, seed):
    """틀 공간 수관(잎은 판정 없음 - 틀 잎 공과 무관하게 짓는다). 반환 (중간, 어두운 아랫면, 밝은 윗면)"""
    rnd = random.Random(seed)
    spec = {  # 가운데 · 돔 반지름 · 덩어리 크기
        "oak": dict(c=(0.6, 17.0, -0.6), r=(7.0, 4.4, 7.0), lump=(3.6, 4.8), n=8),
        "twin": dict(c=(0.0, 16.2, 0.0), r=(8.6, 3.8, 8.2), lump=(3.4, 4.6), n=9),
        "round": dict(c=(0.4, 18.0, -0.4), r=(6.0, 5.8, 6.0), lump=(3.4, 4.4), n=8),
        "coast": dict(c=(3.0, 16.6, -1.2), r=(8.2, 3.0, 7.4), lump=(3.2, 4.4), n=9),
        "shrub": dict(c=(0.0, 2.6, 0.0), r=(3.4, 2.2, 3.4), lump=(1.8, 2.4), n=6),
    }[kind]
    c, R = spec["c"], spec["r"]
    main = [lumpy((R[0] * 0.62, R[1] * 0.78, R[2] * 0.62), c, seed * 7, n=9, rings=5, jag=0.1)]
    for i in range(spec["n"]):
        a = 2 * math.pi * i / spec["n"] + rnd.uniform(-0.25, 0.25)
        el = rnd.uniform(-0.25, 0.55)  # 돔: 위쪽 덩어리가 더 많다
        ce = math.cos(el)
        p = (c[0] + math.cos(a) * R[0] * ce * 0.78, c[1] + math.sin(el) * R[1], c[2] + math.sin(a) * R[2] * ce * 0.78)
        s = rnd.uniform(*spec["lump"])
        main.append(lumpy((s, s * rnd.uniform(0.72, 0.9), s), p, seed * 7 + i + 1, jag=0.15))
    dark = []
    for i in range(3):
        a = 2 * math.pi * i / 3 + rnd.uniform(-0.4, 0.4)
        p = (c[0] + math.cos(a) * R[0] * 0.42, c[1] - R[1] * 0.62, c[2] + math.sin(a) * R[2] * 0.42)
        s = spec["lump"][1] * 1.05
        dark.append(lumpy((s, s * 0.38, s), p, seed * 11 + i, jag=0.12))
    light = []
    for i in range(4):
        a = 2 * math.pi * i / 4 + rnd.uniform(-0.5, 0.5)
        d = rnd.uniform(0.18, 0.42)
        p = (c[0] + math.cos(a) * R[0] * d, c[1] + R[1] * rnd.uniform(0.62, 0.8), c[2] + math.sin(a) * R[2] * d)
        s = spec["lump"][0] * 0.62
        light.append(lumpy((s, s * 0.7, s), p, seed * 13 + i, jag=0.14))
    return A.merge(*main), A.merge(*dark), A.merge(*light)


def topiary(seed):
    """허브 장식수: 가는 줄기 + 층층 둥근 수형 3단(아래 큰 → 위 작은)"""
    tiers = [((0, 7.0, 0), 3.4), ((0, 11.0, 0), 2.6), ((0, 14.2, 0), 1.8)]
    main, dark, light = [], [], []
    for i, (p, r) in enumerate(tiers):
        main.append(lumpy((r, r * 0.8, r), p, seed + i, n=9, rings=5, jag=0.1))
        dark.append(lumpy((r * 0.95, r * 0.3, r * 0.95), (p[0], p[1] - r * 0.55, p[2]), seed + 10 + i, jag=0.08))
        light.append(lumpy((r * 0.55, r * 0.35, r * 0.55), (p[0] + r * 0.2, p[1] + r * 0.55, p[2] - r * 0.2), seed + 20 + i, jag=0.1))
    stem = A.tube(A.bezier((0, -1, 0), (0, 4, 0), (0.2, 9, 0), (0, 15, 0), n=6), lambda u: 0.55 * (1 - 0.4 * u), sides=6, cap0=True, tip_end=False)
    return stem, A.merge(*main), A.merge(*dark), A.merge(*light)


def shrub_stem():
    return A.merge(*[A.tube(A.bezier((0, -0.5, 0), (math.cos(a) * 0.3, 0.8, math.sin(a) * 0.3), (math.cos(a) * 0.8, 1.6, math.sin(a) * 0.8), (math.cos(a) * 1.2, 2.2, math.sin(a) * 1.2), n=3),
                            lambda u: 0.35 * (1 - 0.6 * u), sides=5, cap0=True, tip_end=True) for a in (0.3, 2.4, 4.4)])


# 나무 세트: 이름 → (줄기, 수관 종류, 수관 씨앗) · 줄기 = trunk() 종류 · "stem" = 허브 전용
SET = {
    "tree_oak": ("oak", "oak", 41),
    "tree_twin": ("twin", "twin", 43),
    "tree_round": ("oak", "round", 47),
    "tree_coast": ("lean", "coast", 53),
}


def build():
    A.reset()
    col = A.new_collection("Trees")
    out, meta = {}, {}
    for name, (tk, ck, seed) in SET.items():
        g_main, g_dark, g_light = crown(ck, seed)
        out[name] = [A.make_obj("Trunk", trunk(tk, seed), BARK, col, mat_name=name + "_Bark"),
                     A.make_obj("Leaves", g_main, LEAF, col, mat_name=name + "_Mid"),
                     A.make_obj("Deco_Dark", g_dark, LEAF_DARK, col, mat_name=name + "_Dark"),
                     A.make_obj("Deco_Light", g_light, LEAF_LIGHT, col, mat_name=name + "_Light")]
    s_main, s_dark, s_light = crown("shrub", 61)
    out["hub_shrub"] = [A.make_obj("Trunk", shrub_stem(), BARK, col, mat_name="hub_shrub_Bark"),
                        A.make_obj("Leaves", s_main, LEAF, col, mat_name="hub_shrub_Mid"),
                        A.make_obj("Deco_Dark", s_dark, LEAF_DARK, col, mat_name="hub_shrub_Dark"),
                        A.make_obj("Deco_Light", s_light, LEAF_LIGHT, col, mat_name="hub_shrub_Light")]
    t_stem, t_main, t_dark, t_light = topiary(71)
    out["hub_topiary"] = [A.make_obj("Trunk", t_stem, BARK, col, mat_name="hub_topiary_Bark"),
                          A.make_obj("Leaves", t_main, LEAF, col, mat_name="hub_topiary_Mid"),
                          A.make_obj("Deco_Dark", t_dark, LEAF_DARK, col, mat_name="hub_topiary_Dark"),
                          A.make_obj("Deco_Light", t_light, LEAF_LIGHT, col, mat_name="hub_topiary_Light")]
    # 허브 큰 나무 잎 뭉치 덮개(단위 공 - 쓰는 쪽이 뭉치 크기로 늘린다)
    for i, seed in enumerate((101, 202, 303)):
        name = "clump_" + "abc"[i]
        g_main, g_dark, g_light = clump(seed)
        out[name] = [A.make_obj("Leaves", g_main, LEAF, col, mat_name=name + "_Mid"),
                     A.make_obj("Deco_Dark", g_dark, LEAF_DARK, col, mat_name=name + "_Dark"),
                     A.make_obj("Deco_Light", g_light, LEAF_LIGHT, col, mat_name=name + "_Light")]
    for name, objs in out.items():
        for o in objs:
            o.name = o["RigPart"]
        A.export_fbx(os.path.join(OUT, name + ".fbx"), objs)
        meta[name] = A.meta_of(objs, TREE_BUDGET)
        for o in objs:
            o.name = name + "_" + o["RigPart"]
        print("[make_trees] %s 삼각형 %d / %d" % (name, meta[name]["totalTris"], TREE_BUDGET))
    A.write_json(os.path.join(OUT, "trees.meta.json"), meta)
    return out


def assemble_preview(out, col):
    """렌더용: 필드 4종 + 허브 2종 나란히"""
    import mathutils
    names = ["tree_oak", "tree_twin", "tree_round", "tree_coast", "hub_topiary", "hub_shrub"]
    placed = []
    for i, name in enumerate(names):
        dx = (i - 2.5) * 22
        for src in out[name]:
            o = src.copy()
            o.data = src.data.copy()
            col.objects.link(o)
            o.location = o.location + A.C @ mathutils.Vector((dx, 0, 0))
            placed.append(o)
    return placed


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = build()
    if "--render" in argv:
        folder = argv[argv.index("--render") + 1]
        col = A.new_collection("Preview")
        placed = assemble_preview(out, col)
        for objs in out.values():
            for o in objs:
                o.hide_render = True
        A.render_views(placed, os.path.join(folder, "trees"), views=("front", "34"), kinds=("game",), sil=False, res=(1400, 700))
