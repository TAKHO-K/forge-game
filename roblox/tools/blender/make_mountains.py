# -*- coding: utf-8 -*-
# QUEUE-ALL3 Q10 먼 풍경 카툰 산(Blender bpy): 구역(tier1 ~ 6)마다 2 ~ 3종 · 게임은 회전 · 배율로 재사용한다.
#   산 1개 = 둥근 "덩어리" 여러 개(극좌표 높이장 - 가운데 꼭대기 한 점 + 고리)를 겹쳐 합친 것. 모서리 없는 둥근 윤곽 · 부드러운 음영.
#   파트(오브젝트 = 단색 재질 1개): Body(몸통) · Snow(눈 덮개 - 물결 경계선 · 몸통 위에 살짝 띄운 껍데기) · Cap(메사 윗면 밝은 띠) · Crystal(tier2 둥근 결정 혹).
#   크기 = 실제 stud(1 Blender 단위 = 1 stud · make_trees.py와 같은 FBX 설정) · 원점 = 바닥 가운데(y = 0이 바닥).
#   색 = 미리보기 · 메타 제안색(게임이 데이터로 칠한다). 예산: 메시 1개 ≤ 1,500 삼각형 · 본 메시 합 ≤ 20,000 · _lod ≤ 300.
#   출력: roblox/art/props/mountains/<이름>.fbx · mountains.meta.json · --render <폴더> = 메시마다 512px 미리보기
# 실행: bash bl.sh make_mountains.py [--render 폴더]
import bpy
import math
import os
import random
import sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import artlib as A  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "art", "props", "mountains"))
MESH_BUDGET = 1500
TOTAL_BUDGET = 20000
LOD_BUDGET = 300

# 몸통 높이 곡선 f(u) - u = 가운데 0 → 바닥 가장자리 1 · f(0) = 1 · f(1) = 0 · 단조 감소
PROF = {
    "hill": lambda u: (1 - u * u) ** 1.7,
    "rock": lambda u: (1 - u ** 1.8) ** 2.0,
    "peak": lambda u: (1 - u ** 2) ** 2.8,
    "spire": lambda u: (1 - u ** 2.2) ** 4,
    "mesa": lambda u: 0.86 * (1 - min(u / 0.86, 1.0) ** 14) ** 0.22 + 0.14 * (1 - u * u) ** 2,
    "cliff": lambda u: 0.75 * (1 - min(u / 0.9, 1.0) ** 3) ** 0.55 + 0.25 * (1 - u * u) ** 2,
}
# 고리 간격 지수 k: u_i = 1 − (1 − i/R)^k (산봉우리형) · RIM = 메사 · 절벽은 테두리(둥근 윗모서리) 근처에 고리를 모은다
RING_K = {"hill": 1.0, "rock": 1.0, "peak": 0.8, "spire": 0.8}  # k < 1 = 꼭대기 쪽이 촘촘(둥근 끝)
RIM = {"mesa": 0.86, "cliff": 0.9}


def ring_us(prof, R):
    """고리 u 목록(1..R · 마지막 = 1 바닥)"""
    if prof not in RIM:
        k = RING_K[prof]
        return [1 - (1 - i / R) ** k if k >= 1 else (i / R) ** (1 / k) for i in range(1, R + 1)]
    x0 = RIM[prof]
    if R <= 3:
        return [0.6 * x0, x0 * 0.97, 1.0][-R:] if R == 3 else [x0 * 0.95, 1.0][-R:]
    n_in = max(1, R // 3)
    n_rim = R - n_in - 1
    us = [0.78 * x0 * i / n_in for i in range(1, n_in + 1)]  # 윗면
    us += [x0 * (0.86 + 0.16 * i / n_rim) for i in range(1, n_rim + 1)]  # 둥근 윗모서리 → 벽
    return us + [1.0]

# 구역 색(제안): 몸통 · 덮개(눈 / 윗면) · 결정
ZONE_COLOR = {
    "tier1": dict(name="석조 평원", body=(112, 176, 86), cap=None),
    "tier2": dict(name="수정 동굴", body=(112, 84, 170), crystal=(210, 108, 240), cap=None),
    "tier3": dict(name="수몰 신전", body=(40, 142, 152), cap=(128, 214, 200)),
    "tier4": dict(name="모래 유적", body=(204, 142, 72), cap=(238, 198, 124)),
    "tier5": dict(name="폭풍 첨탑", body=(46, 54, 96), cap=(222, 230, 246)),
    "tier6": dict(name="빙하", body=(170, 192, 218), cap=(248, 251, 255)),
}


def L(x, z, rad, H, prof, S=22, R=8, cap=None, wob=0.08, lean=(0.0, 0.0), seed=1):
    """덩어리 1개. cap = (시작 높이 비율, 물결 진폭 비율, 물결 수) 또는 None"""
    return dict(c=(x, z), rad=rad, H=H, prof=prof, S=S, R=R, cap=cap, wob=wob, lean=lean, seed=seed)


# 산 목록: 이름 → (구역, 덩어리들, 결정 수, 덮개 이름)
SET = {
    "mountain_tier1_a": ("tier1", [L(0, 0, 380, 300, "hill", seed=11), L(-300, 60, 260, 200, "hill", 18, 6, seed=12), L(320, -40, 280, 230, "hill", 18, 6, seed=13)], 0),
    "mountain_tier1_b": ("tier1", [L(0, 0, 330, 360, "hill", 24, 8, seed=21), L(250, 80, 200, 170, "hill", 18, 6, seed=22)], 0),
    "mountain_tier1_c": ("tier1", [L(-380, 0, 230, 210, "hill", 18, 6, seed=31), L(-80, 20, 260, 260, "hill", 20, 7, seed=32),
                                   L(240, -10, 250, 230, "hill", 18, 6, seed=33), L(430, 30, 170, 150, "hill", 16, 5, seed=34)], 0),
    "mountain_tier2_a": ("tier2", [L(0, 0, 340, 520, "rock", 24, 9, lean=(20, -10), seed=41), L(-270, 80, 220, 300, "rock", 18, 6, seed=42),
                                   L(270, -60, 230, 340, "rock", 18, 7, seed=43)], 4),
    "mountain_tier2_b": ("tier2", [L(0, 0, 280, 440, "rock", 22, 8, lean=(-15, 10), seed=51), L(200, 90, 200, 280, "rock", 18, 6, seed=52)], 3),
    "mountain_tier3_a": ("tier3", [L(0, 0, 420, 290, "cliff", 26, 9, cap=(0.9, 0.03, 5), seed=61),
                                   L(260, -40, 190, 380, "cliff", 18, 7, cap=(0.9, 0.03, 4), seed=62)], 0),
    "mountain_tier3_b": ("tier3", [L(-200, 0, 260, 340, "cliff", 22, 8, cap=(0.9, 0.03, 4), seed=71), L(180, 40, 240, 260, "cliff", 20, 7, cap=(0.9, 0.03, 4), seed=72),
                                   L(0, -170, 160, 200, "cliff", 16, 6, seed=73)], 0),
    "mountain_tier4_a": ("tier4", [L(0, 0, 520, 280, "mesa", 28, 9, cap=(0.9, 0.025, 6), wob=0.1, seed=81)], 0),
    "mountain_tier4_b": ("tier4", [L(0, 0, 300, 440, "mesa", 24, 9, cap=(0.9, 0.025, 5), seed=91), L(-250, 60, 190, 200, "mesa", 18, 7, cap=(0.88, 0.03, 4), seed=92)], 0),
    "mountain_tier4_c": ("tier4", [L(-280, 0, 300, 260, "mesa", 22, 8, cap=(0.9, 0.025, 5), seed=101), L(300, 30, 260, 300, "mesa", 22, 8, cap=(0.9, 0.025, 5), seed=102)], 0),
    "mountain_tier5_a": ("tier5", [L(0, 0, 330, 120, "hill", 18, 5, seed=111), L(0, 0, 150, 585, "spire", 18, 8, cap=(0.8, 0.04, 4), lean=(25, 0), seed=112),
                                   L(-180, 60, 120, 430, "spire", 14, 7, cap=(0.8, 0.04, 3), lean=(-20, 10), seed=113),
                                   L(180, -50, 130, 480, "spire", 14, 7, cap=(0.8, 0.04, 3), lean=(15, -15), seed=114),
                                   L(40, 160, 100, 300, "spire", 12, 6, seed=115)], 0),
    "mountain_tier5_b": ("tier5", [L(0, 0, 300, 100, "hill", 18, 5, seed=121), L(-40, 0, 170, 520, "spire", 18, 8, cap=(0.8, 0.04, 4), lean=(-20, 0), seed=122),
                                   L(160, 40, 130, 380, "spire", 14, 7, cap=(0.8, 0.04, 3), lean=(20, 5), seed=123)], 0),
    "mountain_tier6_a": ("tier6", [L(0, 0, 420, 580, "peak", 24, 9, cap=(0.5, 0.06, 4), lean=(-20, 0), seed=131),
                                   L(330, 50, 260, 360, "peak", 18, 7, cap=(0.55, 0.06, 4), seed=132),
                                   L(-330, -30, 240, 300, "peak", 18, 6, cap=(0.6, 0.06, 4), seed=133)], 0),
    "mountain_tier6_b": ("tier6", [L(-220, 0, 330, 500, "peak", 22, 8, cap=(0.5, 0.06, 4), seed=141), L(230, 30, 320, 460, "peak", 22, 8, cap=(0.5, 0.06, 4), seed=142),
                                   L(0, 140, 200, 260, "rock", 16, 6, cap=(0.6, 0.05, 3), seed=143)], 0),
    "mountain_tier6_c": ("tier6", [L(0, 0, 420, 380, "rock", 24, 8, cap=(0.45, 0.05, 4), seed=151), L(-300, 50, 220, 220, "hill", 18, 6, cap=(0.55, 0.05, 4), seed=152)], 0),
}


class Lump:
    def __init__(self, s):
        self.s = s
        rnd = random.Random(s["seed"])
        self.ph = [rnd.uniform(0, 2 * math.pi) for _ in range(8)]
        self.f = PROF[s["prof"]]

    def point(self, u, th):
        s, ph = self.s, self.ph
        w = s["wob"]
        rad = s["rad"] * (1 + w * math.sin(2 * th + ph[0]) + w * 0.6 * math.sin(3 * th + ph[1]) + w * 0.3 * math.sin(5 * th + ph[2]))
        f = self.f(u)
        y = s["H"] * f * (1 + 0.05 * u * math.sin(2 * th + ph[3]))
        k = f * f  # 기울기(lean)는 위로 갈수록 - 바닥은 제자리
        return Vector((s["c"][0] + u * rad * math.cos(th) + s["lean"][0] * k, y, s["c"][1] + u * rad * math.sin(th) + s["lean"][1] * k))

    def normal(self, u, th):
        e = 1e-3
        if u < 0.02:
            return Vector((0, 1, 0))
        du = self.point(min(1, u + e), th) - self.point(max(0, u - e), th)
        dt = self.point(u, th + e) - self.point(u, th - e)
        n = dt.cross(du).normalized()
        return n if n.y >= 0 else -n

    def body(self, S, R):
        verts = [tuple(self.point(0, 0))]
        faces = []
        for u in ring_us(self.s["prof"], R):
            verts += [tuple(self.point(u, 2 * math.pi * j / S)) for j in range(S)]
        for j in range(S):
            faces.append((0, 1 + (j + 1) % S, 1 + j))
        for i in range(R - 1):
            a, b = 1 + i * S, 1 + (i + 1) * S
            for j in range(S):
                jn = (j + 1) % S
                faces.append((a + j, a + jn, b + jn, b + j))
        last = 1 + (R - 1) * S
        faces.append(tuple(last + j for j in range(S)))  # 바닥 뚜껑
        return verts, faces

    def cap_shell(self, S, Rs):
        """덮개: 경계선 = 높이 비율 sf ± 물결(각도마다 이분법으로 u를 찾는다) · 표면에서 법선으로 살짝 띄운 열린 껍데기"""
        sf, amp, waves = self.s["cap"]
        H = self.s["H"]
        off = max(1.5, 0.012 * H)
        verts = [tuple(self.point(0, 0) + Vector((0, off, 0)))]
        faces = []
        for i in range(1, Rs + 1):
            t = i / Rs
            for j in range(S):
                th = 2 * math.pi * j / S
                target = H * (sf + amp * math.sin(waves * th + self.ph[4]) + amp * 0.25 * math.sin(2 * waves * th + self.ph[5]))
                lo, hi = 0.0, 1.0
                for _ in range(30):
                    mid = (lo + hi) / 2
                    if self.point(mid, th).y > target:
                        lo = mid
                    else:
                        hi = mid
                u = lo * t
                o = off * (1.35 if i == Rs else 1.0)  # 가장자리 입술(두툼한 끝)
                verts.append(tuple(self.point(u, th) + self.normal(u, th) * o))
        for j in range(S):
            faces.append((0, 1 + (j + 1) % S, 1 + j))
        for i in range(Rs - 1):
            a, b = 1 + i * S, 1 + (i + 1) * S
            for j in range(S):
                jn = (j + 1) % S
                faces.append((a + j, a + jn, b + jn, b + j))
        return verts, faces


def crystal_bumps(lumps, n, seed, sides=6):
    """둥근 끝 결정 혹(뾰족 X) - 가장 큰 덩어리 둘레에 거의 곧게(법선 25%) 깊이 꽂는다(떠 보이지 않게)"""
    rnd = random.Random(seed)
    lp = max(lumps, key=lambda l: l.s["H"])
    geo = []
    for i in range(n):
        u = rnd.uniform(0.35, 0.6)
        th = 2 * math.pi * i / max(1, n) + rnd.uniform(-0.4, 0.4)
        p = lp.point(u, th)
        axis = (lp.normal(u, th) * 0.25 + Vector((0, 1, 0)) * 0.75).normalized()
        h = rnd.uniform(130, 190) * (lp.s["H"] / 500) ** 0.5
        r = h * rnd.uniform(0.32, 0.38)
        prof = [(0, -0.4 * h), (r, 0.0), (r * 1.08, 0.5 * h), (r * 0.78, 0.82 * h), (r * 0.36, 0.97 * h), (0, h)]
        g = A.lathe(prof, n=sides)
        m = Vector((0, 1, 0)).rotation_difference(axis).to_matrix() @ A.rot(ry=rnd.uniform(0, 360))
        geo.append(A.xform(g, m=m, t=tuple(p - axis * 0.3 * h)))
    return A.merge(*geo)


def build_mountain(name, zone, specs, n_cry, lod, col):
    zc = ZONE_COLOR[zone]
    lumps = [Lump(s) for s in specs]
    scale = 1.0
    while True:  # LOD = 고리 · 둘레 수를 줄여 예산 안으로
        bodies, caps = [], []
        for lp in lumps:
            S, R = lp.s["S"], lp.s["R"]
            if lod:
                S, R = max(7, int(S * 0.42 * scale)), max(2, int(R * 0.4 * scale + 0.5))
            bodies.append(lp.body(S, R))
            if lp.s["cap"]:
                caps.append(lp.cap_shell(S, 1 if lod else 3))
        cry = crystal_bumps(lumps, (2 if lod else n_cry) if n_cry else 0, sum(map(ord, name)), sides=4 if lod else 6) if n_cry else None
        tris = sum(sum(len(f) - 2 for f in g[1]) for g in bodies + caps + ([cry] if cry else []))
        if not lod or tris <= LOD_BUDGET or scale < 0.3:
            break
        scale *= 0.85
    suffix = "_lod" if lod else ""
    objs = [A.make_obj("Body", A.merge(*bodies), zc["body"], col, smooth=True, mat_name=name + suffix + "_Body")]
    if caps:
        cap_name = "Snow" if zone in ("tier5", "tier6") else "Cap"
        objs.append(A.make_obj(cap_name, A.merge(*caps), zc["cap"], col, smooth=True, mat_name=name + suffix + "_" + cap_name))
    if cry:
        objs.append(A.make_obj("Crystal", cry, zc["crystal"], col, smooth=True, mat_name=name + suffix + "_Crystal"))
    for p in objs[0].data.polygons:  # 바닥 뚜껑은 평면 음영(가장자리 법선이 아래로 번지지 않게)
        if p.normal.z < -0.99:
            p.use_smooth = False
    return objs


def size_studs(objs):
    lo, hi = A.bbox_world(objs)
    lo_r, hi_r = A.CT @ lo, A.CT @ hi
    return [round(abs(hi_r[i] - lo_r[i]), 2) for i in range(3)], [round(min(lo_r[i], hi_r[i]), 2) for i in range(3)]


def build():
    A.reset()
    col = A.new_collection("Mountains")
    out, meta = {}, {}
    total_main = total_lod = 0
    for name, (zone, specs, n_cry) in SET.items():
        for lod in (False, True):
            fname = name + ("_lod" if lod else "")
            objs = build_mountain(name, zone, specs, n_cry, lod, col)
            for o in objs:
                o.name = o["RigPart"]
            A.export_fbx(os.path.join(OUT, fname + ".fbx"), objs)
            size, mn = size_studs(objs)
            zc = ZONE_COLOR[zone]
            colors = {o["RigPart"]: o.data.materials[0].get("PaletteRGB") for o in objs}
            m = A.meta_of(objs, LOD_BUDGET if lod else MESH_BUDGET, {
                "file": fname + ".fbx", "zone": zone, "zoneName": zc["name"], "lod": lod, "lodOf": name if lod else None,
                "lodFile": None if lod else name + "_lod.fbx", "sizeStuds": size, "bboxMin": mn,
                "origin": "바닥 가운데(y = 0 바닥)", "suggestedColors": colors})
            meta[fname] = m
            for o in objs:
                o.name = fname + "_" + o["RigPart"]
            out[fname] = objs
            if lod:
                total_lod += m["totalTris"]
            else:
                total_main += m["totalTris"]
            flag = "" if m["totalTris"] <= (LOD_BUDGET if lod else MESH_BUDGET) else "  <-- 예산 초과"
            print("[make_mountains] %-22s 삼각형 %4d · 크기 %s%s" % (fname, m["totalTris"], size, flag))
    summary = {"meshTrisTotal": total_main, "meshTrisBudget": TOTAL_BUDGET, "lodTrisTotal": total_lod, "allTrisTotal": total_main + total_lod,
               "units": "1 Blender 단위 = 1 stud · FBX 축 −Z 앞 / Y 위 · FBX_SCALE_NONE(make_trees.py와 같음) · Open Cloud LoadAsset은 cm(×100) · Y180으로 온다 → ArtMeshKit.normalize 또는 MeshPart.Size = sizeStuds로 맞춘다"}
    A.write_json(os.path.join(OUT, "mountains.meta.json"), {"_summary": summary, **meta})
    print("[make_mountains] 본 메시 합 %d / %d · LOD 합 %d" % (total_main, TOTAL_BUDGET, total_lod))
    return out


def render_each(out, folder, res=512):
    os.makedirs(folder, exist_ok=True)
    cam = A.camera()
    for name, objs in out.items():
        for other in out.values():
            for o in other:
                o.hide_render = other is not objs
        A.setup_render("form", (res, res))
        bpy.context.scene.display.shading.show_backface_culling = True  # 뒤집힌 면 찾기
        lo, hi = A.bbox_world(objs)
        center = (lo + hi) / 2
        size = max((hi - lo).x, (hi - lo).y, (hi - lo).z)
        cam.data.ortho_scale = size * 1.12
        cam.data.clip_start = 1.0
        cam.data.clip_end = size * 10
        A.aim(cam, center, 30, 12, dist=size * 3)
        bpy.context.scene.render.filepath = os.path.join(folder, name + ".png")
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = build()
    if "--render" in argv:
        render_each(out, argv[argv.index("--render") + 1])
