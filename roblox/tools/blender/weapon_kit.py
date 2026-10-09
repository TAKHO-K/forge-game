# -*- coding: utf-8 -*-
# FINAL-1 2 WEAPON-HOLD 무기 KIT(Blender bpy · 패키지 설치 없음): Meshy GLB(claude-design-handoff\40_gear\_3d\gear_weapon_<종류>_gN_remesh*.glb) 한 자루 →
#   ① 방향 = 게임 규칙(WeaponRigSpec: 칼 · 단검 +Z 칼끝 · +X 날 / 지팡이 +Y 머리 / 활 X 날개 · +Z 시위 쪽) - 칼끝 · 머리 · 시위 쪽은 단면 폭으로 자동 판정
#   ② 손잡이 자동 측정(긴 축을 80칸으로 잘라 단면 폭): 칼 · 단검 = 아래 45% 안 가장 가는 연속 구간 · 지팡이 = 가운데 감긴 구간(30 ~ 60%) · 활 = 가운데 두꺼운 구간
#   ③ 원점 = 손잡이 점(Grip = 0) · 길이 = --length(지금 게임 무기 길이 · 단검 = 등급 비율) · ④ 감량(--tris 상한) · 새 UV + 원본 고해상 색 굽기(--bake)
#   ⑤ 내보내기 art/weapons/v4/<이름>.fbx · _atlas1.png · .meta.json(부착점 Grip · Tip · Support · StringNock · Glow · 손잡이 두께 · 길이) · 렌더(--render)
#   --mirror = 좌우 반전(쌍검 왼손) - 같은 아틀라스를 쓴다(UV 그대로).
# 좌표는 전부 Roblox 공간(artlib C/CT)으로 계산하고 Blender에 적용한다.
# 실행: bash bl.sh weapon_kit.py --glb <GLB> --kind gs|db|bow|staff --name <이름> --length 5.5 --tris 5000 --bake 1024 [--mirror] [--render 폴더]
import bpy
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import artlib as A  # noqa: E402
import boss_kit as K  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

ART = os.path.normpath(os.path.join(HERE, "..", "..", "art"))
BINS = 80


def parse():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    o = {"glb": None, "kind": None, "name": None, "length": 1.0, "tris": 5000, "bake": 1024, "mirror": False, "render": None, "out": "weapons/v4"}
    i = 0
    while i < len(a):
        k = a[i]
        if k == "--mirror":
            o["mirror"] = True
            i += 1
            continue
        v = a[i + 1]
        if k in ("--tris", "--bake"):
            o[k[2:]] = int(v)
        elif k == "--length":
            o["length"] = float(v)
        else:
            o[k[2:]] = v
        i += 2
    return o


def rverts(obj):
    """Roblox 공간 꼭짓점 목록"""
    return [A.CT @ v.co for v in obj.data.vertices]


def rsamples(obj, n=40000):
    """Roblox 공간 면 위 고른 점(면적 비례 · 결정적 격자 바리센트릭) - 감량 메시의 듬성한 꼭짓점 대신 단면 폭을 잰다"""
    me = obj.data
    me.calc_loop_triangles()
    tris = []
    total = 0.0
    for t in me.loop_triangles:
        a, b, c = (me.vertices[i].co for i in t.vertices)
        ar = ((b - a).cross(c - a)).length / 2
        tris.append((a, b, c, ar))
        total += ar
    pts = []
    for a, b, c, ar in tris:
        k = max(1, int(round(n * ar / total))) if total > 0 else 1
        m = max(1, int(math.ceil(math.sqrt(k))))
        for i in range(m):
            for j in range(m - i):
                u, v = (i + 0.33) / m, (j + 0.33) / m
                pts.append(A.CT @ (a + (b - a) * u + (c - a) * v))
    return pts


def apply_roblox(obj, M):
    """Roblox 공간 4×4 변환 M을 메시에 적용"""
    C4 = A.C.to_4x4()
    obj.data.transform(C4 @ M @ C4.transposed())


def slices(vs, ax, lo, hi):
    """긴 축 ax 방향 BINS칸: 칸마다 (두 수직 축 중 넓은 폭, 수직 축 폭 2개, 꼭짓점 목록)"""
    others = [k for k in range(3) if k != ax]
    rows = [[] for _ in range(BINS)]
    span = hi - lo
    for v in vs:
        t = (v[ax] - lo) / span
        rows[min(BINS - 1, max(0, int(t * BINS)))].append(v)
    out = []
    for r in rows:
        if r:
            w = [max(p[k] for p in r) - min(p[k] for p in r) for k in others]
            out.append({"w": max(w), "w2": w, "vs": r})
        else:
            out.append(None)
    # 빈 칸 = 이웃 값
    for i in range(BINS):
        if out[i] is None:
            j = i - 1 if i > 0 and out[i - 1] else i + 1
            while j < BINS and out[j] is None:
                j += 1
            out[i] = dict(out[j if j < BINS else i - 1], vs=[])
    return out, others


def run_around(ws, idx, limit, lo_i, hi_i):
    """idx를 품고 폭 ≤ limit인 연속 칸 [a, b] (lo_i ~ hi_i 안)"""
    a = b = idx
    while a - 1 >= lo_i and ws[a - 1] <= limit:
        a -= 1
    while b + 1 <= hi_i and ws[b + 1] <= limit:
        b += 1
    return a, b


def centroid(rows, a, b, axes):
    pts = [v for r in rows[a:b + 1] for v in r["vs"]]
    if not pts:
        return [0.0 for _ in axes]
    return [sum(p[k] for p in pts) / len(pts) for k in axes]


def orient(obj, kind):
    """긴 축 → 규칙 축 · 끝 방향 판정. 반환: 끝 축 이름"""
    vs = rsamples(obj)
    lo = Vector([min(v[k] for v in vs) for k in range(3)])
    hi = Vector([max(v[k] for v in vs) for k in range(3)])
    ext = hi - lo
    ax = max(range(3), key=lambda k: ext[k])
    rows, others = slices(vs, ax, lo[ax], hi[ax])
    ws = [r["w"] for r in rows]
    # 끝 방향 부호: +1 = 긴 축 + 끝이 끝(칼끝 · 머리)
    if kind in ("gs", "db"):
        # 가드 = 가장 넓은 칸 · 가드에서 가까운 끝 = 자루 쪽(칼날이 자루보다 길다) → 칼끝 = 먼 쪽
        g = max(range(BINS), key=lambda i: ws[i])
        sign = 1 if g < BINS / 2 else -1
    elif kind == "staff":
        top = sum(ws[int(BINS * 0.8):]) / (BINS - int(BINS * 0.8))
        bot = sum(ws[:int(BINS * 0.2)]) / int(BINS * 0.2)
        sign = 1 if top >= bot else -1
    else:
        sign = 1
    # 수직 축: 칼 = 넓은 쪽(날 폭) → +X · 활 = 날개-가운데 깊이 차가 큰 축 → Z
    w0 = sum(r["w2"][0] for r in rows) / BINS
    w1 = sum(r["w2"][1] for r in rows) / BINS
    wide, thin = (others[0], others[1]) if w0 >= w1 else (others[1], others[0])
    def unit(k, s=1.0):
        u = Vector((0, 0, 0))
        u[k] = s
        return u
    tipv = unit(ax, sign)
    if kind in ("gs", "db"):
        X, Z = unit(wide), tipv
        Y = Z.cross(X)
    elif kind == "staff":
        Y = tipv
        X = unit(wide)
        Z = X.cross(Y)
    else:  # bow: 날개 = X(긴 축 + 끝) · 시위 쪽 = 가운데(손잡이)에서 날개 끝 쪽 깊이 방향 = +Z
        X = tipv
        mid = centroid(rows, int(BINS * 0.45), int(BINS * 0.55), others)
        ends = centroid(rows, 0, 3, others)
        ends2 = centroid(rows, BINS - 4, BINS - 1, others)
        best, bk, bs = -1, others[0], 1.0
        for j, k in enumerate(others):
            d = (ends[j] + ends2[j]) / 2 - mid[j]
            if abs(d) > best:
                best, bk, bs = abs(d), k, (1.0 if d > 0 else -1.0)
        Z = unit(bk, bs)
        Y = Z.cross(X)
    # 새 축으로: R의 행 = 새 축(옛 좌표에서 새 좌표로)
    R = Matrix((X, Y, Z))
    apply_roblox(obj, R.to_4x4())
    return {"gs": "+Z", "db": "+Z", "staff": "+Y", "bow": "+X"}[kind]


def measure(obj, kind, length):
    """크기 맞춤 + 손잡이 측정 + 원점 = 손잡이. 반환: 메타 부착점"""
    tip_ax = {"gs": 2, "db": 2, "staff": 1, "bow": 0}[kind]
    vs = rverts(obj)
    lo = Vector([min(v[k] for v in vs) for k in range(3)])
    hi = Vector([max(v[k] for v in vs) for k in range(3)])
    s = length / (hi[tip_ax] - lo[tip_ax])
    apply_roblox(obj, Matrix.Diagonal((s, s, s, 1)) @ Matrix.Translation(-lo))
    vs = rsamples(obj)
    L = length
    rows, others = slices(vs, tip_ax, 0.0, L)
    ws = [r["w"] for r in rows]
    if os.environ.get("WEAPON_PROFILE"):
        print("[PROFILE] " + " ".join("%.2f" % w for w in ws))
    if kind in ("gs", "db"):
        # 자루 쪽(0 ~ 가드) 안에서 가장 긴 "가는" 연속 구간 = 손잡이(자루 끝 장식 · 가드 제외)
        g = max(range(int(BINS * 0.5)), key=lambda i: ws[i])
        hilt = list(range(1, g))
        base = sorted(ws[i] for i in hilt)[len(hilt) // 3] if hilt else ws[0]
        limit = base * 1.25
        best = (0, 0)
        i = 1
        while i < g:
            if ws[i] <= limit:
                j = i
                while j + 1 < g and ws[j + 1] <= limit:
                    j += 1
                if j - i > best[1] - best[0]:
                    best = (i, j)
                i = j + 1
            else:
                i += 1
        a, b = best
    elif kind == "staff":
        rng = (int(BINS * 0.25), int(BINS * 0.65))
        shaft = min(ws[int(BINS * 0.1):int(BINS * 0.8)])
        cand = [i for i in range(*rng) if ws[i] >= shaft * 1.06 and ws[i] <= shaft * 1.8]  # 감긴 손잡이 = 자루보다 조금 두꺼움
        if len(cand) >= 3:
            a, b = min(cand), max(cand)
        else:
            c = int(BINS * 0.42)
            a, b = c - 3, c + 3
    else:
        # 활 손잡이 = 가운데(30 ~ 70%)에서 폭이 고른 가장 긴 구간(감은 손잡이 - 양옆 날개 시작부는 넓어진다)
        rng = (int(BINS * 0.3), int(BINS * 0.7))
        mid = BINS // 2
        base = min(ws[mid - 3:mid + 4])
        a, b = run_around(ws, min(range(mid - 3, mid + 4), key=lambda i: ws[i]), base * 1.12, rng[0], rng[1] - 1)
    t0, t1 = a / BINS * L, (b + 1) / BINS * L
    gc = centroid(rows, a, b, others)
    grip = Vector((0, 0, 0))
    grip[tip_ax] = (t0 + t1) / 2
    for j, k in enumerate(others):
        grip[k] = gc[j]
    thick = sorted(ws[a:b + 1])[(b - a) // 2]
    glen = t1 - t0
    support = None
    if kind == "gs":  # 양손: 오른손 = 손잡이 위쪽 · 왼손(보조) = 아래쪽 · 사이 ≥ 0.45
        half = max(glen * 0.22, 0.225)
        g2 = grip.copy()
        grip[tip_ax] += half
        g2[tip_ax] -= half
        support = g2
    # 원점 = 손잡이
    apply_roblox(obj, Matrix.Translation(-grip))
    vs = rverts(obj)
    lo = Vector([min(v[k] for v in vs) for k in range(3)])
    hi = Vector([max(v[k] for v in vs) for k in range(3)])
    tip = Vector((0, 0, 0))
    tip[tip_ax] = hi[tip_ax]
    att = {"Grip": [0.0, 0.0, 0.0], "Tip": list(tip)}
    if support is not None:
        att["Support"] = list(support - grip)
    if kind == "bow":
        # 시위 = 날개 끝 두 점을 잇는 선의 가운데(깊이 = 끝 깊이) · 끝 = 위 날개 끝
        top = [v for v in vs if v[0] > hi[0] - 0.04 * L]
        zt = sum(v[2] for v in top) / len(top)
        att["StringNock"] = [0.0, 0.0, zt]
        att["Tip"] = [hi[0], 0.0, zt]
    # 빛(보석 · 룬 근처 추정): 칼 · 단검 = 손잡이 끝(가드) 위 · 지팡이 = 머리 · 활 = 손잡이 위 - 태초 자홍 발광 노브 자리
    glow = Vector((0, 0, 0))
    if kind in ("gs", "db"):
        glow[tip_ax] = (t1 - (t0 + t1) / 2) + 0.06 * L
    elif kind == "staff":
        glow[tip_ax] = hi[tip_ax] - 0.1 * L
    att["Glow"] = list(glow)
    info = {"gripThickness": round(thick, 4), "gripLength": round(glen, 4), "gripFrom": round(t0 / L, 4), "gripTo": round(t1 / L, 4),
            "size": [round(hi[k] - lo[k], 4) for k in range(3)], "tipAxis": {0: "+X", 1: "+Y", 2: "+Z"}[tip_ax]}
    att = {k: [round(x, 4) for x in v] for k, v in att.items()}
    return att, info


def main():
    o = parse()
    A.reset()
    src = K.import_glb(o["glb"], 0.0)
    src_tris = K.tris(src)
    tip_axis = orient(src, o["kind"])
    att, info = measure(src, o["kind"], o["length"])
    if o["mirror"]:  # 반전 사본(쌍검 왼손): 방향 · 손잡이를 정한 뒤 X를 거울(손잡이 원점 그대로 · 같은 아틀라스)
        apply_roblox(src, Matrix.Scale(-1, 4, Vector((1, 0, 0))))
        src.data.flip_normals()
        att = {k: [-v[0], v[1], v[2]] for k, v in att.items()}
    hiobj = src.copy()
    hiobj.data = src.data.copy()
    bpy.context.scene.collection.objects.link(hiobj)
    hiobj.name = "KIT_HI"
    low = src
    low.name = o["name"]
    if src_tris > o["tris"]:
        K.decimate(low, o["tris"])
    out = os.path.join(ART, o["out"])
    os.makedirs(out, exist_ok=True)
    fn = "%s_atlas1.png" % o["name"]
    # FINAL-1 2: Cycles DIFFUSE 색 = 바탕색 × (1 − 금속도) → 금속 무기가 거의 검게 구워졌다(gs_g1 평균 19 · 원본 94). 굽기 원본만 금속도 0(텍스처 색 그대로)
    for slot in hiobj.material_slots:
        nt = slot.material and slot.material.use_nodes and slot.material.node_tree
        for node in (nt.nodes if nt else []):
            if node.type == "BSDF_PRINCIPLED":
                for link in list(node.inputs["Metallic"].links):
                    nt.links.remove(link)
                node.inputs["Metallic"].default_value = 0.0
    K.bake_atlas([low], hiobj, {"size": o["bake"], "extrusion": 0.02 * o["length"], "distance": 0.06 * o["length"]}, os.path.join(out, fn))
    bpy.data.objects.remove(hiobj, do_unlink=True)
    low["RigPart"] = "Weapon"
    low["TriCount"] = K.tris(low)
    A.export_fbx(os.path.join(out, "%s.fbx" % o["name"]), [low])
    meta = A.meta_of([low], o["tris"], {"version": "WEAPON4", "metaName": o["name"], "kind": o["kind"], "length": o["length"], "attachments": att, "hold": info,
                                       "texture": {"atlases": [fn], "parts": ["Weapon"]},
                                       "kit": {"source": os.path.basename(o["glb"]), "sourceTris": src_tris, "mirror": o["mirror"]},
                                       "space": "Roblox 공간 · 원점 = 손잡이(Grip) · 끝 축 %s" % tip_axis})
    A.write_json(os.path.join(out, "%s.meta.json" % o["name"]), meta)
    for im in list(bpy.data.images):
        if im.name != "KIT_BAKE":
            bpy.data.images.remove(im)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "%s.blend" % o["name"]))
    print("[WEAPON] %s(%s): 삼각형 %d → %d · 길이 %.2f · 손잡이 %.0f ~ %.0f%% · 두께 %.3f · 부착점 %s" % (
        o["name"], o["kind"], src_tris, K.tris(low), o["length"], info["gripFrom"] * 100, info["gripTo"] * 100, info["gripThickness"], att))
    if o["render"]:
        orig = A.setup_render

        def tex_setup(kind, res=(600, 600)):
            sc = orig(kind, res)
            if kind == "game":
                sc.display.shading.color_type = "TEXTURE"
            return sc
        A.setup_render = tex_setup
        A.render_views([low], os.path.join(o["render"], o["name"]), kinds=("game",), sil=False, hull=0.0, res=(600, 600))
        A.setup_render = orig


if __name__ == "__main__":
    main()
