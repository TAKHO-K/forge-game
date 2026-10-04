# -*- coding: utf-8 -*-
# PILOT-B(2026-10-05): 장비 3D 제작 방식 시범 B안 = 그림 → AI 3D(Meshy 6 Lite) → Blender 정리. PILOT-A와 같은 부위(대검 몸통 · 가슴판 + 양 어깨) · 같은 결과 형식.
#   입력 GLB = claude-design-handoff/10_gear-rules/pilot/pilot_B_chest_meshy6lite.glb(약 346,000 삼각형 · 색 없음 · CC BY 4.0 - 시범 판단용 · 출시 에셋 금지)
#   단계: ① 가져오기 · 앞 = 게임 앞(180° 회전) ② 원본 그림을 같은 시점(실루엣 겹침 최대 각도 자동 탐색)에서 투영해 면마다 색 분류
#         → 초록(석조 평원 이끼 #66834A) · 금(#E2B45A) · 가죽(#5A3E2B) · 짙은 가죽 ③ 덩어리 분리(몸통 · 어깨 L/R · 어깨 안 숨은 껍데기 삭제)
#         ④ R15 UpperTorso 맞춤(축마다 배율 · 몸통 안쪽이 몸 상자를 감싸게) ⑤ 1차 감량 → R15 프록시에 가려 안 보이는 면 삭제(광선) → 최종 감량(합 ≤ 6,000)
#         ⑥ UV = 팔레트 칸 + 명암(PILOT-A와 같은 굽기) ⑦ 검사(뒤집힌 면 · 구멍 · 비다양체) ⑧ 내보내기 · 렌더
# 실행: bash roblox/tools/blender/bl.sh roblox/art/gear/pilot/B/src/make_pilot_b.py [--render] [--export]
import bpy
import bmesh
import json
import math
import os
import sys
import time
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

T0 = time.time()
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, ".."))
PIL_DIR = "C:/Users/xkrgh/vibe/claude-design-handoff/10_gear-rules/pilot"
GLB = PIL_DIR + "/pilot_B_chest_meshy6lite.glb"
REF_IMG = PIL_DIR + "/pilot_B_chest_nbp.png"
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
C = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))  # Roblox → Blender (PILOT-A와 같음 · 앞 = Blender +Y)
LOG = {}


def log(k, v):
    LOG[k] = v
    print("[pilotB]", k, v)


# ────────────────────────── 팔레트(PILOT-A와 같은 형식 · 사용자 지정 초록/금/갈색 가죽) ──────────────────────────
SWATCH = {
    "moss": ((102, 131, 74), (190, 214, 150), 0.32, 0.5),  # 석조 평원 색1 #66834A
    "gold": ((226, 180, 90), (255, 246, 214), 0.55, 0.45),  # 금 #E2B45A(3-1절 전설 ~ 고대)
    "leather": ((90, 62, 43), (160, 120, 88), 0.30, 0.55),  # 가죽 #5A3E2B
    "leather2": ((64, 44, 31), (120, 90, 66), 0.25, 0.55),  # 짙은 가죽(안쪽 · 틈)
}
ORDER = list(SWATCH)
PAL_RES = 256
COL_W = PAL_RES // 16
# 그림에서 분류 기준 색(그림 색은 분류에만 쓰고 결과 색은 위 팔레트 - 1절 "그림 스포이트 금지")
REF_CLASSES = [("moss", (104, 132, 74)), ("moss", (64, 88, 56)), ("moss", (130, 160, 90)), ("gold", (226, 170, 80)), ("gold", (190, 130, 60)),
               ("gold", (245, 205, 120)), ("leather", (120, 82, 64)), ("leather", (100, 66, 52)), ("leather2", (60, 36, 30)), ("leather2", (40, 26, 24))]


def ramp(name, v):
    base, lite, k, dk = SWATCH[name]
    cool = (46, 40, 70)
    dark = tuple(base[i] * dk * 0.8 + cool[i] * 0.2 for i in range(3))
    hi = tuple(base[i] + (lite[i] - base[i]) * k for i in range(3))
    if v < 0.55:
        t = v / 0.55
        t = t * t * (3 - 2 * t)
        return tuple(dark[i] + (base[i] - dark[i]) * t for i in range(3))
    t = ((v - 0.55) / 0.45) ** 1.6
    return tuple(base[i] + (hi[i] - base[i]) * t for i in range(3))


def palette_image(path):
    img = bpy.data.images.new("PilotB_Palette", PAL_RES, PAL_RES, alpha=False)
    px = np.zeros((PAL_RES, PAL_RES, 4), dtype=np.float32)
    px[..., :3] = 0.5
    px[..., 3] = 1
    for y in range(PAL_RES):
        v = (y + 0.5) / PAL_RES
        for ci, n in enumerate(ORDER):
            px[y, ci * COL_W:(ci + 1) * COL_W, :3] = np.array(ramp(n, v)) / 255
    img.filepath_raw = path
    img.file_format = "PNG"
    img.pixels[:] = px.ravel()
    img.update()
    img.save()
    bpy.data.images.remove(img)
    img = bpy.data.images.load(path)
    return img


# ────────────────────────── ① 가져오기 ──────────────────────────
def import_glb():
    bpy.ops.import_scene.gltf(filepath=GLB)
    o = [x for x in bpy.data.objects if x.type == "MESH"][0]
    o.name = "Raw"
    o.data.transform(Matrix.Rotation(math.pi, 4, "Z"))  # Meshy 앞 = −Y → 게임 앞 = Blender +Y
    o.data.update()
    has_custom = o.data.has_custom_normals
    bpy.context.view_layer.objects.active = o
    if has_custom:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.faces.ensure_lookup_table()
    before = [f.normal.copy() for f in bm.faces]
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    log("import_normals", {"customNormals": has_custom, "flippedByRecalc": sum(1 for f, n in zip(bm.faces, before) if f.normal.dot(n) < 0)})
    bm.to_mesh(o.data)
    bm.free()
    log("raw_tris", sum(len(p.vertices) - 2 for p in o.data.polygons))
    return o


# ────────────────────────── ② 그림 투영 색 분류 ──────────────────────────
def load_ref():
    img = bpy.data.images.load(REF_IMG)
    w, h = img.size
    a = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1, :, :3] * 255  # 위 → 아래 줄 순서
    bpy.data.images.remove(img)
    bg = np.median(np.concatenate([a[:40, :40].reshape(-1, 3), a[:40, -40:].reshape(-1, 3)]), axis=0)
    mask = np.linalg.norm(a - bg, axis=2) > 28
    mask[int(h * 0.88):, int(w * 0.62):] = False  # 오른쪽 아래 워터마크
    return a, mask


def view_basis(yaw, pitch):
    """카메라 방향(앞 +Y에서 바라봄 · 위에서 pitch°) → 화면 오른쪽 · 위 단위 벡터"""
    y, p = math.radians(yaw), math.radians(pitch)
    d = Vector((math.sin(y) * math.cos(p), math.cos(y) * math.cos(p), math.sin(p)))  # 물체 → 카메라
    f = -d
    r = f.cross(Vector((0, 0, 1))).normalized()
    u = r.cross(f).normalized()
    return d, r, u


def project(V, yaw, pitch):
    d, r, u = view_basis(yaw, pitch)
    return np.stack([V @ np.array(r), V @ np.array(u)], axis=1), d


def silhouette(P, res=192):
    lo, hi = P.min(0), P.max(0)
    s = (hi - lo).max()
    q = ((P - lo) / s * (res - 1)).astype(int)
    m = np.zeros((res, res), bool)
    m[q[:, 1], q[:, 0]] = True
    return m, lo, hi


def img_bbox(mask):
    ys, xs = np.nonzero(mask)
    return xs.min(), xs.max(), ys.min(), ys.max()


def fit_view(V, mask):
    """실루엣 겹침(IoU)이 가장 큰 yaw · pitch 찾기 - 둘 다 바운딩 박스로 맞춘 뒤 192² 격자 비교"""
    x0, x1, y0, y1 = img_bbox(mask)
    best = None
    sub = V[:: max(1, len(V) // 60000)]
    for pitch in range(0, 52, 3):
        for yaw in (0,):  # 그림 = 정면(좌우 대칭) - yaw를 풀면 IoU가 끝값(−20)으로 쏠려 색이 어긋났다
            P, _ = project(sub, yaw, pitch)
            lo, hi = P.min(0), P.max(0)
            res = 160
            # 메시 점 → 그림 박스로 맞춘 격자
            qx = ((P[:, 0] - lo[0]) / (hi[0] - lo[0]) * (res - 1)).astype(int)
            qy = ((hi[1] - P[:, 1]) / (hi[1] - lo[1]) * (res - 1)).astype(int)
            mm = np.zeros((res, res), bool)
            mm[qy, qx] = True
            mm = dilate(mm, 1)
            ys = np.linspace(y0, y1, res).astype(int)
            xs = np.linspace(x0, x1, res).astype(int)
            im = mask[np.ix_(ys, xs)]
            iou = (mm & im).sum() / max(1, (mm | im).sum())
            if best is None or iou > best[0]:
                best = (iou, yaw, pitch)
    return best


def dilate(m, k):
    out = m.copy()
    for dy in range(-k, k + 1):
        for dx in range(-k, k + 1):
            out |= np.roll(np.roll(m, dy, 0), dx, 1)
    return out


def classify(obj, a, mask, yaw, pitch):
    """면 가운데를 그림에 투영 · 카메라에서 보이는 면만 그림 색 → 분류. 안 보이는 면 = 앞뒤 거울 위치 투영(어깨 · 목 · 허리는 앞뒤가 비슷) · 그래도 가리면 가죽"""
    me = obj.data
    n = len(me.polygons)
    cen = np.zeros(n * 3, dtype=np.float32)
    me.polygons.foreach_get("center", cen)
    cen = cen.reshape(n, 3)
    nor = np.zeros(n * 3, dtype=np.float32)
    me.polygons.foreach_get("normal", nor)
    nor = nor.reshape(n, 3)
    V = np.zeros(len(me.vertices) * 3, dtype=np.float32)
    me.vertices.foreach_get("co", V)
    V = V.reshape(-1, 3)
    Pv, d = project(V, yaw, pitch)
    lo, hi = Pv.min(0), Pv.max(0)
    x0, x1, y0, y1 = img_bbox(mask)
    bvh = BVHTree.FromPolygons([tuple(v) for v in V], [tuple(p.vertices) for p in me.polygons])
    dv = Vector(d)

    def to_px(P):
        px = x0 + (P[:, 0] - lo[0]) / (hi[0] - lo[0]) * (x1 - x0)
        py = y0 + (hi[1] - P[:, 1]) / (hi[1] - lo[1]) * (y1 - y0)
        return px, py

    def visible(points):
        vis = np.zeros(len(points), bool)
        for i, p in enumerate(points):
            hit = bvh.ray_cast(Vector(p) + dv * 0.002, dv, 10.0)
            vis[i] = hit[0] is None
        return vis

    vis = (nor @ np.array(dv) > 0.05) & visible(cen)
    mirror = cen.copy()
    mirror[:, 1] = -mirror[:, 1]  # 앞뒤 거울(Blender Y)
    mnor = nor.copy()
    mnor[:, 1] = -mnor[:, 1]
    mvis = (~vis) & (mnor @ np.array(dv) > 0.05) & visible(mirror)
    src = np.where(vis[:, None], cen, mirror)
    P, _ = project(src, yaw, pitch)
    px, py = to_px(P)
    h, w = a.shape[:2]
    # 그림 3 × 3 평균(선 · 붓 자국 완화)
    ix = np.clip(px.astype(int), 1, w - 2)
    iy = np.clip(py.astype(int), 1, h - 2)
    col = sum(a[iy + dy, ix + dx] for dy in (-2, 0, 2) for dx in (-2, 0, 2)) / 9
    refc = np.array([c for _, c in REF_CLASSES], dtype=np.float32)
    lab = np.argmin(((col[:, None, :] - refc[None]) ** 2).sum(2), axis=1)
    cls = np.array([ORDER.index(REF_CLASSES[i][0]) for i in lab])
    if "--debug" in ARGS:  # 보이는 면 분류색을 그림 위에 찍어 정렬 확인
        dbg = a.copy() * 0.35
        pal = np.array([SWATCH[n][0] for n in ORDER], dtype=np.float32)
        sel = vis
        dbg[np.clip(py[sel].astype(int), 0, h - 1), np.clip(px[sel].astype(int), 0, w - 1)] = pal[cls[sel]]
        im = bpy.data.images.new("dbg", w, h, alpha=False)
        out = np.ones((h, w, 4), np.float32)
        out[..., :3] = dbg[::-1] / 255
        im.pixels[:] = out.ravel()
        im.filepath_raw = os.path.join(os.environ.get("PILOTB_DBG", OUT), "classify_debug.png")
        im.file_format = "PNG"
        im.save()
    cls[~(vis | mvis)] = ORDER.index("leather")
    log("classify_visible_front", int(vis.sum()))
    log("classify_mirror", int(mvis.sum()))
    log("classify_fallback_leather", int((~(vis | mvis)).sum()))
    return cls


def smooth_labels(obj, cls, iters=2):
    """이웃 면 다수결(선 · 경계 얼룩 정리)"""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    nb = [[g.index for e in f.edges for g in e.link_faces if g.index != f.index] for f in bm.faces]
    bm.free()
    K = len(ORDER)
    for _ in range(iters):
        new = cls.copy()
        for i, ns in enumerate(nb):
            cnt = np.bincount(cls[ns + [i, i]], minlength=K)
            new[i] = int(np.argmax(cnt))
        cls = new
    return cls


def classify_relief(obj):
    """형태 기반 분류(그림 투영은 AI 메시가 그림과 어긋나 실패 - labels 렌더로 확인): 정점 높이 = (정점 − 매끈 사본) · 법선
    · 작은 반경(6회) 높이 상위 = 테두리 턱 → 금 · 큰 반경(60회) 높이 상위 = 솟은 판 → 초록 · 나머지 = 가죽 · 안쪽 향한 면 · 맨 아래 띠 = 짙은 가죽/가죽"""
    me = obj.data
    nv = len(me.vertices)
    V = np.zeros(nv * 3)
    me.vertices.foreach_get("co", V)
    V = V.reshape(-1, 3)
    N = np.zeros(nv * 3)
    me.vertices.foreach_get("normal", N)
    N = N.reshape(-1, 3)
    E = np.zeros(len(me.edges) * 2, dtype=np.int64)
    me.edges.foreach_get("vertices", E)
    E = E.reshape(-1, 2)
    deg = np.bincount(E.ravel(), minlength=nv).astype(float)[:, None]

    def smooth(P, it):
        P = P.copy()
        for _ in range(it):
            acc = np.zeros_like(P)
            np.add.at(acc, E[:, 0], P[E[:, 1]])
            np.add.at(acc, E[:, 1], P[E[:, 0]])
            P = 0.5 * P + 0.5 * acc / np.maximum(deg, 1)
        return P
    s6 = smooth(V, 6)
    hs = ((V - s6) * N).sum(1)
    s60 = smooth(s6, 54)
    hl = ((V - s60) * N).sum(1)
    nf = len(me.polygons)
    F = np.zeros(nf * 3, dtype=np.int64)
    me.polygons.foreach_get("vertices", F)  # 전부 삼각형(Meshy)
    F = F.reshape(-1, 3)
    fs = hs[F].mean(1)
    fl = hl[F].mean(1)
    cen = V[F].mean(1)
    fn = np.zeros(nf * 3)
    me.polygons.foreach_get("normal", fn)
    fn = fn.reshape(-1, 3)
    cls = np.full(nf, ORDER.index("leather"))
    gold_t = np.percentile(fs, 82)
    green_t = np.percentile(fl, 62)
    cls[fl > green_t] = ORDER.index("moss")
    cls[fs > gold_t] = ORDER.index("gold")
    if obj.name == "Chest":
        z0, z1 = V[:, 2].min(), V[:, 2].max()
        belt = cen[:, 2] < z0 + 0.1 * (z1 - z0)
        cls[belt] = ORDER.index("leather")
        radial = cen[:, :2] - V[:, :2].mean(0)
        inward = (fn[:, :2] * radial).sum(1) < -0.2 * np.linalg.norm(radial, axis=1)
        cls[inward] = ORDER.index("leather2")
    else:
        cls[cls == ORDER.index("leather")] = ORDER.index("moss")  # 어깨 = 초록 판 + 금 테(그림)
    log("relief_%s" % obj.name, {k: int((cls == i).sum()) for i, k in enumerate(ORDER)})
    return cls


# ────────────────────────── ③ 덩어리 분리 ──────────────────────────
def split_islands(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="LOOSE")
    bpy.ops.object.mode_set(mode="OBJECT")
    parts = sorted([o for o in bpy.data.objects if o.type == "MESH"], key=lambda o: -len(o.data.vertices))
    body, pa, pb, ia, ib = parts[:5]
    body.name = "Chest"
    for p in (pa, pb):
        cx = sum(v.co.x for v in p.data.vertices) / len(p.data.vertices)
        p.name = "Pauldron_L" if cx < 0 else "Pauldron_R"  # Roblox 왼쪽 = −X(PILOT-A와 같음)
    hidden = []
    for p in (ia, ib):
        hidden.append(len(p.data.polygons))
        bpy.data.objects.remove(p)  # 어깨 안쪽 껍데기 = 어깨판 속에 완전히 묻힘(가져오기 직후 덩어리 색 렌더로 확인)
    log("removed_inner_shell_tris", hidden)
    return [body, bpy.data.objects["Pauldron_L"], bpy.data.objects["Pauldron_R"]]


# ────────────────────────── ④ R15 맞춤 ──────────────────────────
def fit_transform(body):
    """축마다 배율 + 가운데 맞춤. 기준 = 몸 쪽(UpperTorso 높이) 바깥 표면 점들의 5% 분위 거리 → 앞뒤 0.58 · 좌우 1.08 이상
    (최댓값 기준은 테두리 턱만 잡아 앞판이 몸 상자 앞면과 같은 깊이 → 가려졌다 · 정점 밀어내기는 안쪽 벽까지 밀려 방패가 짓눌려 버림)
    · 높이 = 목 고리 위 0.95 ~ 허리 띠 아래 −1.2"""
    me = body.data
    V = np.array([v.co[:] for v in me.vertices])
    N = np.array([v.normal[:] for v in me.vertices])
    z0, z1 = V[:, 2].min(), V[:, 2].max()
    sz = (0.95 - (-1.2)) / (z1 - z0)
    tz = 0.95 - z1 * sz
    Z = V[:, 2] * sz + tz
    band = (Z > -0.7) & (Z < 0.6)
    cx = (V[band, 0].min() + V[band, 0].max()) / 2
    cy = (V[band, 1].min() + V[band, 1].max()) / 2
    d = V - np.array([cx, cy, 0])
    w4 = 0.25 * (V[:, 0].max() - V[:, 0].min())
    front = band & (N[:, 1] > 0.6) & (d[:, 1] > 0) & (np.abs(d[:, 0]) < w4)  # 바깥 = 위치와 법선 부호가 같음(안쪽 벽 제외)
    back = band & (N[:, 1] < -0.6) & (d[:, 1] < 0) & (np.abs(d[:, 0]) < w4)
    side = (Z > -0.8) & (Z < -0.15) & (np.abs(N[:, 0]) > 0.6) & (N[:, 0] * d[:, 0] > 0) & (np.abs(d[:, 1]) < 0.2)  # 겨드랑이 구멍 아래
    fy = np.percentile(d[front, 1], 25)  # 5%는 틈 · 구멍 안쪽을 잡아 배율이 5배로 폭주
    by = -np.percentile(d[back, 1], 75)
    sxv = np.percentile(np.abs(d[side, 0]), 25)
    sy = 0.58 / min(fy, by)
    sx = 1.08 / sxv
    t = (-cx * sx, -cy * sy, tz)
    log("fit", {"front25": round(float(fy), 3), "back5": round(float(by), 3), "side5": round(float(sxv), 3), "scale": [round(float(sx), 3), round(float(sy), 3), round(float(sz), 3)]})
    return Matrix.Translation(t) @ Matrix.Diagonal((sx, sy, sz, 1))


def fit_pauldron(obj, side):
    """어깨 따로 맞춤: AI 어깨는 바깥 아래로 비스듬히 뻗은 관(팔을 벌린 자세) → 주축(PCA)을 R15 윗팔 방향(수직)으로 세우고
    단면이 팔 상자(1 × 1 · 대각 반 0.71)를 감싸게 균일 배율 → 윗팔 축(±1.5) · 위 끝 = 어깨 위 0.98"""
    me = obj.data
    V = np.array([v.co[:] for v in me.vertices])
    c = V.mean(0)
    U, S_, Wt = np.linalg.svd(V - c, full_matrices=False)
    ax = Wt[0]
    if ax[2] > 0:  # 주축이 아래(바깥 끝 쪽)를 향하게
        ax = -ax
    if np.dot(ax, [side, 0, 0]) < 0 and abs(ax[0]) > abs(ax[2]):
        ax = -ax
    R = Vector(ax).rotation_difference(Vector((0, 0, -1))).to_matrix().to_4x4()
    me.transform(Matrix.Translation(-Vector(c)))
    me.transform(R)
    V = np.array([v.co[:] for v in me.vertices])
    ext = V.max(0) - V.min(0)
    kx, ky, kz = 1.75 / ext[0], 1.75 / ext[1], 1.35 / ext[2]  # 단면 = 팔 상자 감쌈(반 0.875 > 대각 0.71) · 길이 = 윗팔(균일 배율은 팔뚝까지 내려온 소매가 됐다)
    k = (round(float(kx), 3), round(float(ky), 3), round(float(kz), 3))
    me.transform(Matrix.Diagonal((kx, ky, kz, 1)))
    V = np.array([v.co[:] for v in me.vertices])
    off = V.mean(0) - (V.max(0) + V.min(0)) / 2  # C자 껍데기 = 무게중심이 닫힌 쪽 → 닫힌 쪽을 바깥(±X)으로
    yaw = math.atan2(off[1], off[0])
    me.transform(Matrix.Rotation((0.0 if side > 0 else math.pi) - yaw, 4, "Z"))
    V = np.array([v.co[:] for v in me.vertices])
    mid = (V.max(0) + V.min(0)) / 2
    me.transform(Matrix.Translation((side * 1.5 - mid[0], -mid[1], 0.98 - V[:, 2].max())))
    k = k + (round(math.degrees(yaw), 1),)
    me.update()
    log("fit_%s" % obj.name, {"axis": [round(float(x), 2) for x in ax], "scale": k})


def push_out(obj, boxes, margin=0.06):
    """R15 상자(+여유) 안으로 들어간 정점을 가장 얕은 면 방향으로 밀어냄(축 배율만으로는 둥근 갑옷이 각진 몸을 못 감쌈 - 앞판이 몸 앞면과 같은 깊이라 가려졌다)
    boxes = [(가운데 Roblox, 크기, 밀 수 있는 면 목록)] · 면 = "+x" 등(아래가 열린 몸통은 −y(Roblox) 아래로는 안 밈)"""
    me = obj.data
    V = np.zeros(len(me.vertices) * 3, dtype=np.float64)
    me.vertices.foreach_get("co", V)
    V = V.reshape(-1, 3)
    moved = 0
    for c, size, faces in boxes:
        cb = np.array(C @ Vector(c))
        hb = np.abs(np.array(C @ Vector(size))) / 2 + margin
        d = V - cb
        inside = np.all(np.abs(d) < hb, axis=1)
        idx = np.nonzero(inside)[0]
        for i in idx:
            best = None
            for f in faces:  # Blender 축 기준 면
                ax = "xyz".index(f[1])
                sgn = 1 if f[0] == "+" else -1
                depth = hb[ax] - sgn * d[i, ax]
                if best is None or depth < best[0]:
                    best = (depth, ax, sgn)
            V[i, best[1]] = cb[best[1]] + best[2] * hb[best[1]]
        moved += len(idx)
    me.vertices.foreach_set("co", V.ravel())
    me.update()
    return moved


# ────────────────────────── ⑤ 감량 · 숨은 면 삭제 ──────────────────────────
def decimate(obj, target):
    n = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    if n <= target:
        return
    m = obj.modifiers.new("dec", "DECIMATE")
    m.decimate_type = "COLLAPSE"
    m.ratio = target / n
    m.use_symmetry = obj.name == "Chest"
    m.symmetry_axis = "X"
    m.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=m.name)


BODY = {"UpperTorso": ((0, 0, 0), (2, 1.6, 1)), "LowerTorso": ((0, -1.0, 0), (2, 0.4, 1)), "Head": ((0, 1.4, 0), (1.2, 1.2, 1.2)),
        "LeftUpperArm": ((-1.5, 0.22, 0), (1, 1.17, 1)), "RightUpperArm": ((1.5, 0.22, 0), (1, 1.17, 1)),
        "LeftLowerArm": ((-1.5, -0.89, 0), (1, 1.05, 1)), "RightLowerArm": ((1.5, -0.89, 0), (1, 1.05, 1)),
        "LeftHand": ((-1.5, -1.57, 0), (1, 0.3, 1)), "RightHand": ((1.5, -1.57, 0), (1, 0.3, 1)),
        "LeftUpperLeg": ((-0.5, -1.8, 0), (1, 1.22, 1)), "RightUpperLeg": ((0.5, -1.8, 0), (1, 1.22, 1))}  # = PILOT-A 렌더 마네킹(UpperTorso 기준)


def proxy_bvh():
    verts, faces = [], []
    for nm, (c, s) in BODY.items():
        if nm == "Head":
            continue
        b = len(verts)
        for dx in (-0.5, 0.5):
            for dy in (-0.5, 0.5):
                for dz in (-0.5, 0.5):
                    verts.append(tuple(C @ Vector((c[0] + dx * s[0], c[1] + dy * s[1], c[2] + dz * s[2]))))
        faces += [tuple(b + i for i in f) for f in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3))]
    return BVHTree.FromPolygons(verts, faces)


def remove_hidden(objs, proxy):
    """면 가운데에서 바깥 반구 32방향 광선이 전부 무언가(갑옷 · R15 프록시)에 3 stud 안에서 막히면 안 보이는 면 → 삭제"""
    trees = []
    for o in objs:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        trees.append(BVHTree.FromBMesh(bm))
        bm.free()
    trees.append(proxy)
    K = 32
    dirs = []
    for i in range(K):
        z = 1 - (i + 0.5) / K
        r = math.sqrt(1 - z * z)
        a = i * 2.39996
        dirs.append(Vector((r * math.cos(a), r * math.sin(a), z)))
    out = {}
    for o in objs:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        kill = []
        for f in bm.faces:
            c = f.calc_center_median()
            n = f.normal
            t = n.orthogonal().normalized()
            b = n.cross(t)
            open_ = False
            for d in dirs:
                w = t * d.x + b * d.y + n * d.z
                if all(tr.ray_cast(c + n * 0.004, w, 3.0)[0] is None for tr in trees):
                    open_ = True
                    break
            if not open_:
                kill.append(f)
        out[o.name] = len(kill)
        bmesh.ops.delete(bm, geom=kill, context="FACES")
        bm.to_mesh(o.data)
        bm.free()
    log("hidden_faces_removed", out)


# ────────────────────────── ⑥ UV(팔레트 칸 + 명암) - PILOT-A bake_uv와 같은 식 ──────────────────────────
def bake_uv(objs, occluders):
    light = (C @ Vector((-0.35, 1.0, -0.55))).normalized()
    up = Vector((0, 0, 1))
    trees = []
    for o in objs:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        trees.append(BVHTree.FromBMesh(bm))
        bm.free()
    trees.append(occluders)
    K = 24
    dirs = []
    for i in range(K):
        zz = 1 - (i + 0.5) / K
        r = math.sqrt(1 - zz * zz)
        a = i * 2.39996
        dirs.append(Vector((r * math.cos(a), r * math.sin(a), zz)))
    for o in objs:
        me = o.data
        if "UVMap" not in me.uv_layers:
            me.uv_layers.new(name="UVMap")
        bm = bmesh.new()
        bm.from_mesh(me)
        bm.verts.ensure_lookup_table()
        ao, conv = [], []
        for v in bm.verts:
            p = v.co
            n = v.normal
            t = n.orthogonal().normalized()
            b = n.cross(t)
            hit = 0
            for d in dirs:
                w = t * d.x + b * d.y + n * d.z
                for tr in trees:
                    loc, _, _, dist = tr.ray_cast(p + n * 0.006, w, 0.28)
                    if loc is not None:
                        hit += 1 - dist / 0.28 * 0.5
                        break
            ao.append(max(0.0, 1 - 1.15 * hit / K))
            c = 0.0
            for e in v.link_edges:
                dd = e.other_vert(v).co - v.co
                if dd.length > 1e-6:
                    c -= v.normal.dot(dd.normalized())
            conv.append(c / max(1, len(v.link_edges)))
        bm.free()
        zone = me.attributes["zone"].data
        cn = me.corner_normals
        uv = me.uv_layers["UVMap"].data
        for poly in me.polygons:
            u = (zone[poly.index].value * COL_W + COL_W / 2) / PAL_RES
            for li in poly.loop_indices:
                vi = me.loops[li].vertex_index
                n = Vector(cn[li].vector).normalized()
                lam = (n.dot(light) * 0.5 + 0.5) ** 1.3
                s = 0.12 + 0.62 * lam + 0.14 * max(0.0, n.dot(up))
                s *= 0.45 + 0.55 * ao[vi]
                s += max(0.0, min(0.16, conv[vi] * 0.9))
                uv[li].uv = (u, max(0.03, min(0.97, s)))


# ────────────────────────── ⑦ 검사 ──────────────────────────
def check(objs):
    res = {}
    for o in objs:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bm.faces.ensure_lookup_table()
        before = [f.normal.copy() for f in bm.faces]
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        flipped = sum(1 for f, n in zip(bm.faces, before) if f.normal.dot(n) < 0)
        res[o.name] = {"tris": sum(len(f.verts) - 2 for f in bm.faces), "boundaryEdges": sum(1 for e in bm.edges if e.is_boundary),
                       "nonManifoldEdges": sum(1 for e in bm.edges if not e.is_manifold and not e.is_boundary),
                       "flippedVsRecalc": flipped, "degenerate": sum(1 for f in bm.faces if f.calc_area() < 1e-8)}
        bm.free()
    return res


# ────────────────────────── 렌더 ──────────────────────────
def mannequin(col):
    out = []
    for nm, (c, s) in BODY.items():
        bpy.ops.mesh.primitive_cube_add(size=1)
        o = bpy.context.active_object
        o.name = "Dummy_" + nm
        o.scale = (s[0], s[2], s[1])
        o.location = tuple(C @ Vector(c))
        bv = o.modifiers.new("b", "BEVEL")
        bv.width = 0.08
        bv.segments = 3
        for c2 in o.users_collection:
            c2.objects.unlink(o)
        col.objects.link(o)
        m = bpy.data.materials.new("Dummy_" + nm)
        rgb = (232, 196, 160) if nm == "Head" else (43, 53, 80)
        m.use_nodes = True
        m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = tuple(((c3 / 255) ** 2.2) for c3 in rgb) + (1,)
        m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.8
        o.data.materials.append(m)
        out.append(o)
    return out


def setup_render():
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x = sc.render.resolution_y = 1024
    sc.view_settings.view_transform = "Standard"
    w = bpy.data.worlds.new("W")
    sc.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.56, 0.6, 1)
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
    for nm, rot, e in (("Key", (52, 0, -35), 3.2), ("Rim", (60, 0, 150), 1.6)):
        ld = bpy.data.lights.new(nm, "SUN")
        ld.energy = e
        lo = bpy.data.objects.new(nm, ld)
        lo.rotation_euler = tuple(math.radians(a) for a in rot)
        sc.collection.objects.link(lo)
    cd = bpy.data.cameras.new("Cam")
    cd.type = "ORTHO"
    cd.ortho_scale = 4.9
    cam = bpy.data.objects.new("Cam", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    return cam


def aim(cam, target, yaw, pitch, dist=30):
    y, p = math.radians(yaw), math.radians(pitch)
    d = Vector((math.sin(y) * math.cos(p), math.cos(y) * math.cos(p), math.sin(p)))
    cam.location = target + d * dist
    f = -d
    right = f.cross(Vector((0, 0, 1))).normalized()
    upv = right.cross(f).normalized()
    cam.rotation_euler = Matrix((right, upv, -f)).transposed().to_euler()


def render_views(prefix, views=(("front", 0, 6), ("34", 38, 12), ("side", 90, 6), ("back", 180, 6))):
    cam = bpy.context.scene.camera
    target = C @ Vector((0, 0.35, 0))
    for nm, yaw, pitch in views:
        aim(cam, target, yaw, pitch)
        bpy.context.scene.render.filepath = "%s_%s.png" % (prefix, nm)
        bpy.ops.render.render(write_still=True)


def gray_mat():
    m = bpy.data.materials.new("Gray")
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.5, 0.5, 0.52, 1)
    m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.6
    return m


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    t = time.time()
    raw = import_glb()
    a, mask = load_ref()
    V = np.zeros(len(raw.data.vertices) * 3, dtype=np.float32)
    raw.data.vertices.foreach_get("co", V)
    V = V.reshape(-1, 3)
    iou, yaw, pitch = fit_view(V, mask)
    log("view_fit", {"iou": round(float(iou), 3), "yaw": yaw, "pitch": pitch})
    if "--project" in ARGS:  # 그림 투영 분류(시험 · 실패 - 보고서 참고)
        cls = smooth_labels(raw, classify(raw, a, mask, yaw, pitch), 5)
    else:
        cls = np.zeros(len(raw.data.polygons), np.int32)
    za = raw.data.attributes.new("zone", "INT", "FACE")
    za.data.foreach_set("value", cls.astype(np.int32))
    log("t_classify_s", round(time.time() - t, 1))
    if "--labels" in ARGS:
        for n in ORDER:
            m = bpy.data.materials.new("L_" + n)
            m.diffuse_color = tuple((c / 255) ** 2.2 for c in SWATCH[n][0]) + (1,)
            raw.data.materials.append(m)
        raw.data.polygons.foreach_set("material_index", cls.astype(np.int32))
        sc = bpy.context.scene
        sc.render.engine = "BLENDER_WORKBENCH"
        sc.display.shading.color_type = "MATERIAL"
        sc.render.resolution_x = sc.render.resolution_y = 700
        cd = bpy.data.cameras.new("dc")
        cd.type = "ORTHO"
        cd.ortho_scale = 2.3
        cam = bpy.data.objects.new("dc", cd)
        sc.collection.objects.link(cam)
        sc.camera = cam
        for nm, yaw, pitch in (("front", 0, pitch), ("back", 180, 10), ("34", 35, 15)):
            aim(cam, Vector((0, 0, 0)), yaw, pitch, 10)
            sc.render.filepath = os.path.join(os.environ.get("PILOTB_DBG", OUT), "labels_%s.png" % nm)
            bpy.ops.render.render(write_still=True)
        return
    objs = split_islands(raw)
    if "--project" not in ARGS:
        for o in objs:
            c2 = smooth_labels(o, classify_relief(o), 3)
            o.data.attributes["zone"].data.foreach_set("value", c2.astype(np.int32))
    M = fit_transform(objs[0])
    R = C.copy().to_4x4()  # Blender 공간 그대로(이미 앞 = +Y) - 배율만
    objs[0].data.transform(M)
    objs[0].data.update()
    fit_pauldron(objs[1], -1)
    fit_pauldron(objs[2], 1)
    if "--debug" in ARGS:
        Vb = np.array([v.co[:] for v in objs[0].data.vertices])
        for zz in (-1.0, -0.6, -0.2, 0.2, 0.5, 0.8):
            bb = Vb[(np.abs(Vb[:, 2] - zz) < 0.04)]
            mid = bb[(np.abs(bb[:, 0]) < 0.6) & (np.abs(bb[:, 0]) > 0.25)]
            side = bb[np.abs(bb[:, 1]) < 0.3]
            log("slice_%.1f" % zz, {"n": len(bb), "front_y": [round(float(mid[:, 1].min()), 2), round(float(mid[:, 1].max()), 2)] if len(mid) else None,
                                     "side_x": [round(float(side[:, 0].min()), 2), round(float(side[:, 0].max()), 2)] if len(side) else None})
    # R15 상자 밖으로 밀어내기(Blender 축: x = 옆 · y = 앞뒤 · z = 위)
    torso = [((0, 0, 0), (2, 1.6, 1), ["+x", "-x", "+y", "-y", "+z"]), ((0, -1.0, 0), (2, 0.4, 1), ["+x", "-x", "+y", "-y"])]
    arm = lambda sx: [((sx * 1.5, 0.22, 0), (1, 1.17, 1), ["+x" if sx > 0 else "-x", "+y", "-y", "+z"])]  # noqa: E731
    if "--push" in ARGS:  # 시험: 안쪽 벽까지 밀려 방패가 짓눌림 → 기본 끔(분위 배율로 대신)
        log("push_out", {"Chest": push_out(objs[0], torso), "Pauldron_L": push_out(objs[1], arm(-1), 0.05), "Pauldron_R": push_out(objs[2], arm(1), 0.05)})
    col = bpy.data.collections.new("PilotB")
    bpy.context.scene.collection.children.link(col)
    for o in objs:
        for c2 in o.users_collection:
            c2.objects.unlink(o)
        col.objects.link(o)
    hi_tris = {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs}
    log("tris_before", hi_tris)
    # 감량 전 사본(비교 렌더용)
    before = []
    if "--render" in ARGS:
        bcol = bpy.data.collections.new("Before")
        bpy.context.scene.collection.children.link(bcol)
        for o in objs:
            c = o.copy()
            c.data = o.data.copy()
            c.name = o.name + "_before"
            bcol.objects.link(c)
            before.append(c)
    t = time.time()
    # 고해상도 라벨 기준(감량은 면 라벨을 흩뜨린다 → 끝에 가장 가까운 고해상도 면 다수결로 다시 옮김)
    hires = {}
    for o in objs:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        lab = np.zeros(len(o.data.polygons), np.int32)
        o.data.attributes["zone"].data.foreach_get("value", lab)
        hires[o.name] = (BVHTree.FromBMesh(bm), lab)
        bm.free()
    # 1차 감량 → 숨은 면 삭제 → 최종 감량
    first = {"Chest": 24000, "Pauldron_L": 6000, "Pauldron_R": 6000}
    for o in objs:
        decimate(o, first[o.name])
    proxy = proxy_bvh()
    if "--keep-hidden" not in ARGS:
        remove_hidden(objs, proxy)
    final = {"Chest": 3900, "Pauldron_L": 1000, "Pauldron_R": 1000}
    for o in objs:
        decimate(o, final[o.name])
    for o in objs:
        tree, lab = hires[o.name]
        me = o.data
        za = me.attributes["zone"].data
        for poly in me.polygons:
            pts = [Vector(poly.center)] + [me.vertices[i].co * 0.6 + Vector(poly.center) * 0.4 for i in poly.vertices]
            votes = np.zeros(len(ORDER), int)
            for q in pts:
                hit = tree.find_nearest(q)
                if hit[2] is not None:
                    votes[lab[hit[2]]] += 1
            za[poly.index].value = int(np.argmax(votes))
        lab2 = np.zeros(len(me.polygons), np.int32)
        za.foreach_get("value", lab2)
        za.foreach_set("value", smooth_labels(o, lab2, 2).astype(np.int32))  # 감량 뒤 금 점 얼룩 정리
    log("t_reduce_s", round(time.time() - t, 1))
    for o in objs:
        me = o.data
        me.shade_smooth()
        me.set_sharp_from_angle(angle=math.radians(42))
    img = palette_image(os.path.join(OUT, "pilotB_palette.png"))
    mat = bpy.data.materials.new("PilotB_Palette")
    mat.use_nodes = True
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.55
    for o in objs:
        o.data.materials.clear()
        o.data.materials.append(mat)
    bake_uv(objs, proxy)
    tris = {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs}
    log("tris_after", tris)
    log("tris_total", sum(tris.values()))
    log("check", check(objs))
    meta = {"attach": "UpperTorso", "refSize": [2, 1.6, 1], "tris": tris, "total": sum(tris.values()), "pieces": {}}
    for o in objs:
        pts = [o.matrix_world @ v.co for v in o.data.vertices]
        lo = Vector([min(p[i] for p in pts) for i in range(3)])
        hi = Vector([max(p[i] for p in pts) for i in range(3)])
        meta["pieces"][o.name] = {"offset": [round(c, 4) for c in C.transposed() @ ((lo + hi) / 2)], "size": [round(abs(c), 4) for c in C.transposed() @ (hi - lo)]}
    meta["log"] = LOG
    if "--export" in ARGS:
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, "pilotB_armor_greatsword_legendary_stoneplains.fbx"), use_selection=True, object_types={"MESH"},
                                 global_scale=1.0, apply_unit_scale=True, apply_scale_options="FBX_SCALE_NONE", axis_forward="-Z", axis_up="Y",
                                 bake_space_transform=True, use_mesh_modifiers=False, mesh_smooth_type="OFF", add_leaf_bones=False, bake_anim=False,
                                 path_mode="STRIP", embed_textures=False)
    if "--render" in ARGS:
        dcol = bpy.data.collections.new("Dummy")
        bpy.context.scene.collection.children.link(dcol)
        mannequin(dcol)
        setup_render()
        rdir = os.path.join(OUT, "renders")
        os.makedirs(rdir, exist_ok=True)
        g = gray_mat()
        for c in before:
            c.data.materials.clear()
            c.data.materials.append(g)
            c.hide_render = True
        render_views(os.path.join(rdir, "pilotB"))
        # 감량 전/후(회색 · 같은 각도)
        saved = {o: list(o.data.materials) for o in objs}
        for o in objs:
            o.hide_render = True
        for c in before:
            c.hide_render = False
        render_views(os.path.join(rdir, "pilotB_before"), (("front", 0, 6), ("34", 38, 12)))
        for c in before:
            c.hide_render = True
        for o in objs:
            o.hide_render = False
            o.data.materials.clear()
            o.data.materials.append(g)
        render_views(os.path.join(rdir, "pilotB_after_gray"), (("front", 0, 6), ("34", 38, 12)))
        for o in objs:
            o.data.materials.clear()
            for m in saved[o]:
                o.data.materials.append(m)
        for c in before:
            bpy.data.objects.remove(c)
    with open(os.path.join(OUT, "pilotB.meta.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=1)
    img.filepath = "//pilotB_palette.png"
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "pilotB_armor_greatsword_legendary_stoneplains.blend"))
    print("[pilotB] done %.1fs" % (time.time() - T0))


main()
