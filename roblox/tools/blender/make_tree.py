# -*- coding: utf-8 -*-
# QUEUE-ALL8 H 허브 큰 나무 줄기 · 뿌리 · 가지 · 링 발판 겉모습(Blender bpy). 충돌 · 기능은 코드 도형(WorldMapLayout.buildTree) 그대로 - 이 메시는 겉모습만(server/HubArt.dressTree).
#   tree_trunk_base = 밑동(실제 크기 - 반경 78 → 48 · 뿌리 각도마다 버팀 혹 · 이끼 · 버섯 · 옹이 구멍) · tree_trunk_section = 줄기 한 칸(단위 - 반지름 1 · 높이 1 · 넓은 결 · 살짝 비틀림)
#   tree_root = 장식 뿌리 하나(실제 크기 - 줄기 표면에서 바깥 +X로 · 아치처럼 땅에 파고든다) · tree_branch = 점프맵 가지 발판(단위 - X 길이 1 · 지름 1 · 윗면 = 코드 발판 윗면)
#   tree_stem = 줄기에서 가지로 이어지는 굵은 가지(단위 - X 길이 1 · 끝이 조금 올라간다) · tree_deck = 링 발판 한 칸(실제 깊이 42 · 두께 2 · 폭 34 기준 - X만 늘린다) + 바깥 난간.
#   결과 = roblox/art/props/tree_*.fbx + roblox/src/shared/data/TreeArtMeta.lua(생성 표 - 크기 · 조각 색 · 삼각형)
# 실행: bash bl.sh make_tree.py [--render 폴더] [--no-export]
import bpy
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import artlib as A  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "art", "props"))
LUA = os.path.normpath(os.path.join(HERE, "..", "..", "src", "shared", "data", "TreeArtMeta.lua"))

BARK = (142, 90, 60)
BARK_DARK = (110, 68, 46)
BARK_LIGHT = (166, 110, 74)
MOSS = (104, 156, 74)
CAP = (222, 86, 70)
STEM = (240, 228, 206)
HOLE = (58, 36, 26)
DECK = (176, 124, 78)
DECK_DARK = (126, 84, 52)
# 코드 데이터와 같은 값(WorldMapData.hub.tree) - 바뀌면 여기도
TRUNK_R = 48
ROOT_ANGLES = [55, 80, 115, 150, 172, 212, 330]


def ring_pts(n, rfun, y):
    return [(rfun(2 * math.pi * k / n) * math.cos(2 * math.pi * k / n), y, rfun(2 * math.pi * k / n) * math.sin(2 * math.pi * k / n)) for k in range(n)]


def t_base():
    H, n = 34.0, 56
    heights = [0, 4, 10, 18, 26, H]

    def lobe(theta):
        best = 0.0
        deg = math.degrees(theta) % 360
        for a in ROOT_ANGLES:
            d = abs(((deg - a + 540) % 360) - 180)
            if d < 24:
                best = max(best, math.cos(d / 24 * math.pi / 2) ** 2)
        return best

    rings = []
    for y in heights:
        f = (1 - y / H) ** 1.6
        rings.append(ring_pts(n, lambda th, f=f: TRUNK_R + 6 * f + 26 * f * lobe(th), y))
    body = A.loft(rings, cap0=True, cap1=True)  # 닫아야 법선이 바깥(열린 통은 뒤집힐 수 있다 - Roblox는 한 면만 그린다)
    moss = []
    for k, (a, y, s) in enumerate([(20, 12, 5), (95, 20, 6), (140, 8, 5), (200, 16, 7), (260, 24, 5), (305, 10, 6)]):
        th = math.radians(a)
        r = TRUNK_R + 6 * (1 - y / H) ** 1.6 + 26 * (1 - y / H) ** 1.6 * lobe(th) - 0.6
        moss.append(A.xform(A.ellipsoid((s, s * 0.55, 1.2), n=8, rings=3), m=A.rot(ry=-a + 90), t=(r * math.cos(th), y, r * math.sin(th))))
    caps, stems = [], []
    for a, r in [(68, 66), (125, 70), (190, 64), (245, 58)]:
        th = math.radians(a)
        x, z = r * math.cos(th), r * math.sin(th)
        stems.append(A.lathe([(0.0, 0.0), (0.45, 0.0), (0.38, 1.4), (0.0, 1.4)], 8, ) and A.xform(A.lathe([(0.0, 0.0), (0.45, 0.0), (0.38, 1.4), (0.0, 1.4)], 8), t=(x, 0, z)))
        caps.append(A.xform(A.lathe([(0.0, 1.2), (1.3, 1.2), (1.1, 1.8), (0.0, 2.2)], 8), t=(x, 0, z)))
    holes = []
    for a, y in [(250, 22), (40, 28)]:
        th = math.radians(a)
        r = TRUNK_R + 6 * (1 - y / H) ** 1.6 + 26 * (1 - y / H) ** 1.6 * lobe(th) + 0.2
        holes.append(A.xform(A.ellipsoid((3.2, 4.6, 0.8), n=10, rings=4), m=A.rot(ry=-a + 90), t=(r * math.cos(th), y, r * math.sin(th))))
    return [("Bark", body, BARK), ("Moss", A.merge(*moss), MOSS), ("MushStem", A.merge(*stems), STEM), ("MushCap", A.merge(*caps), CAP), ("Hole", A.merge(*holes), HOLE)], 2000


def t_section():
    n, rows = 28, 7  # 넓은 결 14개(산 · 골 번갈아) · 7층 · 아래 → 위 20° 비틀림
    rings = []
    for i in range(rows):
        y = -0.5 + i / (rows - 1)
        tw = math.radians(20) * i / (rows - 1)
        rings.append([((1.0 if k % 2 == 0 else 0.93) * math.cos(2 * math.pi * k / n + tw), y, (1.0 if k % 2 == 0 else 0.93) * math.sin(2 * math.pi * k / n + tw)) for k in range(n)])
    return [("Bark", A.loft(rings, cap0=True, cap1=True), BARK_LIGHT)], 600


def t_root():
    # +X 방향: 줄기 속(r 40)부터 r 165까지 · 위 = 24(1 − t)^1.8 + 3 sin(πt) · 두께 10 → 3 · 바닥은 땅속(−3)까지
    stations, n = 11, 8
    rings = []
    for i in range(stations):
        t = i / (stations - 1)
        x = 40 + t * (165 - 40)
        top = 22 * (1 - t) ** 1.6 + 7 * math.sin(math.pi * t) ** 2 - (3.5 if i == stations - 1 else 0)  # 줄기에서 내려오다 한 번 솟고(무릎) 땅으로 파고든다
        thick = 14 - 10 * t
        w = 22 - 14 * t
        cy = top - thick / 2
        rings.append([(x, cy + math.sin(2 * math.pi * k / n) * thick / 2, math.cos(2 * math.pi * k / n) * w / 2) for k in range(n)])
    return [("Bark", A.loft(rings, cap0=True, cap1=True), BARK_DARK)], 400


def t_branch():
    n = 10
    rings = []
    for x, s in [(-0.5, 0.82), (-0.46, 1.0), (0.46, 1.0), (0.5, 0.82)]:
        rings.append([(x, (0.5 * s if k % 2 == 0 else 0.46 * s) * math.sin(2 * math.pi * k / n), (0.5 * s if k % 2 == 0 else 0.46 * s) * math.cos(2 * math.pi * k / n)) for k in range(n)])
    ends = A.merge(A.xform(A.lathe([(0.0, -0.01), (0.4, -0.01), (0.4, 0.01), (0.0, 0.01)], 10, axis="X"), t=(-0.505, 0, 0)), A.xform(A.lathe([(0.0, -0.01), (0.4, -0.01), (0.4, 0.01), (0.0, 0.01)], 10, axis="X"), t=(0.505, 0, 0)))
    return [("Bark", A.loft(rings), BARK), ("Rings", ends, BARK_LIGHT)], 200


def t_stem():
    n, seg = 8, 6
    rings = []
    for i in range(seg + 1):
        t = i / seg
        x = -0.5 + t
        y = 0.18 * t * t  # 끝이 조금 올라간다(줄기에서 휘어 나와 발판 밑으로)
        r = 0.5 - 0.12 * t
        rings.append([(x, y + r * math.sin(2 * math.pi * k / n), r * math.cos(2 * math.pi * k / n)) for k in range(n)])
    return [("Bark", A.loft(rings), BARK_DARK)], 200


def t_deck():
    W, Dd, T = 34.0, 42.0, 2.0
    top = A.box(W, T, Dd, b=0.2, center=(0, 0, 0))
    lines = A.merge(*[A.box(W - 0.4, 0.12, 0.25, center=(0, T / 2 + 0.03, -Dd / 2 + Dd * k / 6)) for k in range(1, 6)])
    posts = A.merge(*[A.box(0.6, 3.0, 0.6, center=(x, T / 2 + 1.5, Dd / 2 - 0.6)) for x in (-W / 2 + 1, 0, W / 2 - 1)])
    rail = A.merge(A.box(W, 0.4, 0.4, center=(0, T / 2 + 2.8, Dd / 2 - 0.6)), A.box(W, 0.3, 0.3, center=(0, T / 2 + 1.5, Dd / 2 - 0.6)))
    return [("Deck", top, DECK), ("Lines", lines, DECK_DARK), ("Rail", A.merge(posts, rail), DECK_DARK)], 300


def outward(obj):
    """별 모양(세로축 둘레) 물체: 면 법선이 축(Blender Z축 · 높이 가운데)에서 바깥을 보도록 뒤집는다(열린 통 · 오목 뚜껑의 법선 계산이 뒤집혀 Roblox에서 안 보였다)"""
    import bmesh
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    zs = [v.co.z for v in bm.verts]
    mid = (min(zs) + max(zs)) / 2
    flip = []
    for f in bm.faces:
        c = f.calc_center_median()
        n = f.normal
        out = (c.x, c.y, c.z - mid)
        if n.x * out[0] + n.y * out[1] + n.z * out[2] < 0:
            flip.append(f)
    if flip:
        bmesh.ops.reverse_faces(bm, faces=flip)
    bm.to_mesh(me)
    bm.free()
    print("[make_tree] %s 바깥 법선으로 뒤집은 면 %d" % (obj.name, len(flip)))


ITEMS = {"tree_trunk_base": t_base, "tree_trunk_section": t_section, "tree_root": t_root, "tree_branch": t_branch, "tree_stem": t_stem, "tree_deck": t_deck}


def lua_val(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return ("%.3f" % v).rstrip("0").rstrip(".")
    if isinstance(v, str):
        return '"%s"' % v
    if isinstance(v, (list, tuple)):
        return "{ " + ", ".join(lua_val(x) for x in v) + " }"
    if isinstance(v, dict):
        return "{ " + ", ".join("%s = %s" % (k, lua_val(v[k])) for k in sorted(v)) + " }"
    raise TypeError(v)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    render = os.path.abspath(argv[argv.index("--render") + 1]) if "--render" in argv else None
    export = "--no-export" not in argv
    rows = {}
    for item, fn in ITEMS.items():
        A.reset()
        col = A.new_collection(item)
        parts, budget = fn()
        objs = [A.make_obj(name, g, rgb, col, origin=(0, 0, 0), mat_name="%s_%s" % (item, name)) for name, g, rgb in parts]
        if item in ("tree_trunk_base", "tree_trunk_section"):
            for o in objs:
                if o.name.startswith("Bark"):
                    outward(o)
        total = sum(A.tri_count(o) for o in objs)
        lo, hi = A.bbox_world(objs)
        ext = A.CT @ (hi - lo)
        size = [abs(ext.x), abs(ext.y), abs(ext.z)]
        print("[make_tree] %s 파트 %d · 삼각형 %d / %d · 크기(w, h, d) %.2f × %.2f × %.2f" % (item, len(objs), total, budget, size[0], size[1], size[2]))
        assert total <= budget, item
        rows[item] = {"tris": total, "budget": budget, "bounds": [round(x, 3) for x in size], "parts": {o.name.split(".")[0]: {"rgb": list(c)} for o, (_, _, c) in zip(objs, parts)}}
        if export:
            A.export_fbx(os.path.join(OUT, "%s.fbx" % item), objs)
        if render:
            A.render_views(objs, os.path.join(render, item), views=("front", "34"), kinds=("game",), sil=False, hull=0.05, res=(600, 600))
    if export:
        lines = ["-- 생성 파일(roblox/tools/blender/make_tree.py) - 손으로 고치지 않는다. QUEUE-ALL8 H 큰 나무 겉모습 메시 표(키 = props/<이름> · bounds = w, h, d · parts = 조각 색 · tris = 삼각형).", "return {"]
        for item in sorted(rows):
            lines.append("\t%s = %s," % (item, lua_val(rows[item])))
        lines.append("}")
        with open(LUA, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lines) + "\n")
        print("[make_tree] 표 = " + LUA)
    print("[make_tree] 끝")


if __name__ == "__main__":
    main()
