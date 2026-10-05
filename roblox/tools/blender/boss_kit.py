# -*- coding: utf-8 -*-
# BOSS-FRAMEWORK 7 범용 보스 KIT(Blender bpy · 패키지 설치 없음): Meshy GLB(몸 전체 + 따로 만든 부위) → 리그 v2 부위 메시 FBX + 메타 + 아틀라스.
#   1 가져오기: --glb <몸 전체.glb> · --part <부위.glb>=<리그 부위 이름>(따로 만든 날개 · 꼬리 · 무기 · 머리 장식 - 그 부위에 통째로) · --yaw(도 - Meshy 정면 +Z면 180)
#      시험: --fake <옛 보스 id> = art/bosses/<id>.blend의 부위 메시(외곽선 제외)를 한 덩어리로 합쳐 GLB로 내보낸 뒤 그것을 입력으로(크레딧 없이 KIT 검증).
#   2 크기 맞춤: 리그 기준 자세 상자들(rigs/<리그 키>.rig.json - rig_dump.py)의 높이에 맞춰 균일 배율 · 바닥 = 발바닥(y −1.5) · X · Z 가운데.
#   3 부위 자르기: 면마다 가운데 점 → 리그 부위 상자(기준 자세 OBB)까지 부호 거리 최소인 부위(안쪽 = 가장 깊은 상자) · 따로 만든 부위 GLB는 통째로 그 부위.
#   4 관절 둘레 겹침: 부모 부위 면 중 자식 상자에서 overlap 안에 있는 면을 자식에도 복사(관절이 돌 때 틈이 안 보이게) · 5 자른 면 막기: 부위마다 열린 가장자리 holes_fill.
#   6 장식 합치기: 같은 부위로 들어간 장식은 그 부위 메시에 합쳐짐 · Neon 재질(이름 NEON_ · 방출) 면만 <부위>_DecoN 조각으로 따로(색 = 데이터 · 재질 Neon).
#   7 감량: 합계 ≤ --budget(30,000) · 부위 1개 ≤ --part-cap(5,000) · 외곽선 ≤ --outline-tris(8,000) - Decimate(collapse).
#   8 텍스처: 원본 텍스처가 있으면 이미지 ≤ 3장을 1024로 줄여 그대로(UV 유지) · 없으면(색 재질) 1024 팔레트 아틀라스 1장 + 면마다 색 칸 UV.
#   9 외곽선 껍데기 ≤ --outlines(12): 큰 부위부터 뒤집은 껍데기(<부위>_Outline - ArtMeshKit가 잉크색 · 용접).
#   10 내보내기: <out>/<리그 키>.fbx(부위 이름 = 리그 부위 · 원점 = 관절 · 회전 0 - make_boss와 같은 규칙) · .meta.json · 아틀라스 png · 렌더(--render).
#   다음(이 스크립트 밖): python ../opencloud/upload.py bosses/<키>.fbx bosses/<키>_atlas1.png → meta_to_luau.py <키> → BossKitData에 이미지 id 추가.
#   GUARDIAN-V2 추가(--kit <json> - 보스별 KIT 설정 · 없으면 옛 동작 그대로):
#      height(리그 단위 - 원본 높이를 이 값으로 · 발바닥 −1.5 · X · Z 경계 가운데 = 0 · 리그 상자 경계 대신) · yaw · islands(0 ~ 1 - 떨어진 조각(Meshy 돌판)을
#      면 과반이 가는 부위에 통째로 · 비율이 이 값 미만이면 면마다) · skip(원본 면을 받지 않는 부위 - 생성 Neon · 자리만 있는 턱) ·
#      faceParts(조각째 보내기에서 빼는 부위 - 머리 돌판 일부인 눈썹) · neonByColor = { parts, minValue, blueOverGreen, maxChannel }(그 부위에서 텍스처 색이 밝은 보라(수정)인 면 → Neon 조각 · 색 = 평균 → 가장 낮은 채널 ≤ maxChannel) ·
#      generate = [{ part | deco + host, shape = eyes(variant normal · angry · dazed) | rune | bell(profile · neon false = 리그 색 · 굽기 제외), at · size(리그 단위) · color }] (Neon 새 메시) ·
#      texture = "base"(Base Color에 연결된 이미지만 - 거칠기 · 노멀 맵 제외) · decoCap(수정 Neon 조각 삼각형 상한) ·
#      bake = { size, extrusion, distance }(감량하면 Meshy의 잘게 나뉜 UV가 무너진다 → 감량 부위에 새 UV(Smart UV · 한 장에 묶기) + 원본 고해상 메시 색을
#      Cycles로 굽기(선택 → 활성 · 색만) = 1024 아틀라스 1장).
# 실행: bash bl.sh boss_kit.py --rig rigs/section_guardian_v2.rig.json --fake section_guardian [--render 폴더]
#       bash bl.sh boss_kit.py --rig rigs/section_guardian_v2.rig.json --kit rigs/section_guardian_v2.kit.json --glb <Meshy.glb> --name section_guardian_v2m [--render 폴더]
import bpy
import bmesh
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import artlib as A  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

ART = os.path.normpath(os.path.join(HERE, "..", "..", "art"))
C, CT = A.C, A.CT


def parse():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    o = {"rig": None, "glb": None, "parts": [], "fake": None, "yaw": 0.0, "overlap": 0.18, "budget": 30000, "partCap": 5000, "outlines": 12, "outlineTris": 8000,
         "atlas": 1024, "out": os.path.join(ART, "bosses"), "render": None, "hull": 0.06, "name": None, "kit": None}
    i = 0
    while i < len(a):
        k = a[i]
        v = a[i + 1] if i + 1 < len(a) else None
        if k == "--rig":
            o["rig"] = v
        elif k == "--glb":
            o["glb"] = v
        elif k == "--part":
            path, part = v.split("=")
            o["parts"].append((path, part))
        elif k == "--fake":
            o["fake"] = v
        elif k in ("--yaw", "--overlap", "--hull"):
            o[k[2:]] = float(v)
        elif k in ("--budget", "--part-cap", "--outlines", "--outline-tris", "--atlas"):
            o[{"--part-cap": "partCap", "--outline-tris": "outlineTris"}.get(k, k[2:])] = int(v)
        elif k in ("--out", "--render", "--name", "--kit"):
            o[k[2:]] = v
        i += 2
    if not os.path.isabs(o["rig"]):
        o["rig"] = os.path.join(HERE, o["rig"])
    o["cfg"] = {}
    if o["kit"]:
        path = o["kit"] if os.path.isabs(o["kit"]) else os.path.join(HERE, o["kit"])
        o["cfg"] = json.load(open(path, encoding="utf-8"))
        for k in ("yaw", "overlap"):
            if k in o["cfg"]:
                o[k] = float(o["cfg"][k])
    return o


# ─────────────────────────── 리그(rig_dump JSON) ───────────────────────────
def load_rig(path):
    d = json.load(open(path, encoding="utf-8"))
    parts = []
    for p in d["parts"]:
        r = p["rotation"]
        R = Matrix(((r[0], r[1], r[2]), (r[3], r[4], r[5]), (r[6], r[7], r[8])))
        parts.append(dict(name=p["name"], parent=p["parent"], joint=Vector(p["joint"]), center=Vector(p["center"]), R=R, RT=R.transposed(),
                          half=Vector(p["size"]) / 2, size=Vector(p["size"]), color=p["color"], material=p.get("material", "SmoothPlastic"), jointName=p["jointName"]))
    return d["rigId"], parts


def sdf(p, part):
    q = part["RT"] @ (p - part["center"])
    d = Vector((abs(q.x) - part["half"].x, abs(q.y) - part["half"].y, abs(q.z) - part["half"].z))
    outside = Vector((max(d.x, 0), max(d.y, 0), max(d.z, 0))).length
    return outside + min(max(d.x, d.y, d.z), 0.0)


def rig_bounds(parts):
    lo, hi = Vector((1e9, 1e9, 1e9)), Vector((-1e9, -1e9, -1e9))
    for p in parts:
        for sx in (-1, 1):
            for sy in (-1, 1):
                for sz in (-1, 1):
                    c = p["center"] + p["R"] @ Vector((sx * p["half"].x, sy * p["half"].y, sz * p["half"].z))
                    lo = Vector((min(lo.x, c.x), min(lo.y, c.y), min(lo.z, c.z)))
                    hi = Vector((max(hi.x, c.x), max(hi.y, c.y), max(hi.z, c.z)))
    return lo, hi


# ─────────────────────────── 1 가져오기 ───────────────────────────
def build_fake(boss, out_glb):
    """옛 보스 .blend의 부위 메시(외곽선 껍데기 · 렌더용 Hull 모디파이어 제외)를 한 덩어리로 합쳐 GLB로(Meshy 몸 전체 대역). Neon 재질은 이름 앞에 NEON_."""
    bpy.ops.wm.open_mainfile(filepath=os.path.join(ART, "bosses", boss + ".blend"))
    objs = [o for o in bpy.data.objects if o.type == "MESH" and not o.name.endswith("_Outline")]
    for o in bpy.data.objects:
        if o.type == "MESH" and o not in objs:
            bpy.data.objects.remove(o, do_unlink=True)
    for o in objs:
        for m in list(o.modifiers):
            o.modifiers.remove(m)
        for slot in o.material_slots:
            m = slot.material
            if not m or m.get("_kitDone"):
                continue
            neon = bool(m.get("Neon", False)) or bool(o.get("Neon", False)) or (o.get("DecoMaterial") == "Neon")
            if neon and not m.name.startswith("NEON_"):
                m.name = "NEON_" + m.name
            m.use_nodes = True
            bsdf = m.node_tree.nodes.get("Principled BSDF")
            if bsdf:
                bsdf.inputs["Base Color"].default_value = m.diffuse_color
            m["_kitDone"] = True
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.hide_set(False)
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.join()
    bpy.ops.export_scene.gltf(filepath=out_glb, export_format="GLB", use_selection=True, export_apply=True)
    n = sum(len(p.vertices) - 2 for p in bpy.context.view_layer.objects.active.data.polygons)
    print("[KIT] 가짜 원본 %s ← %s 부위 %d개 합침 · 삼각형 %d" % (out_glb, boss, len(objs), n))


def import_glb(path, yaw):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in new:
        o.select_set(True)
    bpy.context.view_layer.objects.active = new[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(new) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    if yaw:
        obj.data.transform(Matrix.Rotation(math.radians(yaw), 4, "Z"))  # Blender Z = Roblox Y
    return obj


# ─────────────────────────── 2 크기 맞춤 ───────────────────────────
def fit(obj, parts):
    lo, hi = rig_bounds(parts)
    vs = [CT @ v.co for v in obj.data.vertices]
    slo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    shi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    s = (hi.y - lo.y) / max(shi.y - slo.y, 1e-6)
    cx, cz = (lo.x + hi.x) / 2, (lo.z + hi.z) / 2
    scx, scz = (slo.x + shi.x) / 2, (slo.z + shi.z) / 2
    for v in obj.data.vertices:
        r = CT @ v.co
        r = Vector(((r.x - scx) * s + cx, (r.y - slo.y) * s + lo.y, (r.z - scz) * s + cz))
        v.co = C @ r
    print("[KIT] 크기 맞춤 × %.4f · 리그 높이 %.2f · 폭 %.2f(원본 폭 × 배율 %.2f)" % (s, hi.y - lo.y, hi.x - lo.x, (shi.x - slo.x) * s))
    return s


def fit_height(obj, height, bounds=None):
    """GUARDIAN-V2: 원본 높이 → height(리그 단위) · 발바닥 −1.5 · X · Z 경계 가운데 = 0(리그 상자를 원본 실측으로 맞춘 경우 - 상자 경계는 팔 · 수정이 삐져나와 높이 기준이 못 된다)"""
    if bounds:  # 같은 변환(굽기 원본 ↔ 감량본)
        slo, shi = bounds
    else:
        vs = [CT @ v.co for v in obj.data.vertices]
        slo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
        shi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    s = height / max(shi.y - slo.y, 1e-6)
    scx, scz = (slo.x + shi.x) / 2, (slo.z + shi.z) / 2
    for v in obj.data.vertices:
        r = CT @ v.co
        v.co = C @ Vector(((r.x - scx) * s, (r.y - slo.y) * s - 1.5, (r.z - scz) * s))
    if not bounds:
        print("[KIT] 크기 맞춤(높이) × %.5f · 높이 %.2f · 폭 %.2f · 깊이 %.2f(리그 단위)" % (s, height, (shi.x - slo.x) * s, (shi.z - slo.z) * s))
    return slo, shi


def islands_of(me):
    """떨어진 조각 번호(면마다) - 꼭짓점 최소 번호 퍼뜨리기(numpy · scipy 없이)"""
    import numpy as np
    n = len(me.vertices)
    e = np.zeros(len(me.edges) * 2, dtype=np.int64)
    me.edges.foreach_get("vertices", e)
    e = e.reshape(-1, 2)
    lab = np.arange(n)
    while True:
        m = np.minimum(lab[e[:, 0]], lab[e[:, 1]])
        np.minimum.at(lab, e[:, 0], m)
        np.minimum.at(lab, e[:, 1], m)
        nxt = lab[lab]
        while not np.array_equal(nxt, lab):
            lab, nxt = nxt, nxt[nxt]
        if np.array_equal(lab[e[:, 0]], lab[e[:, 1]]):
            break
    first = np.zeros(len(me.polygons), dtype=np.int64)
    me.polygons.foreach_get("loop_start", first)
    lv = np.zeros(len(me.loops), dtype=np.int64)
    me.loops.foreach_get("vertex_index", lv)
    return lab[lv[first]]


# ─────────────────────────── 3 · 4 부위 자르기 + 겹침 ───────────────────────────
# ─────────────────────────── BOSS-NIGHT-1 부품 GLB(cfg.addons) ───────────────────────────
# cfg.addons = [{ glb, parts: [부위 …](그 부품 면은 이 부위들 중 가장 가까운 상자로만 · 몸 면은 이 부위로 안 감),
#   fit: 부위 이름(그 상자 · 회전) | "union"(parts 상자들의 축 정렬 합 - 망토 · 날개 사슬), rot: [rx, ry, rz](로블록스 도 - 맞추기 전 부품 회전),
#   fill(상자 대비 배율 · 기본 1) · scaleAxis("x" | "y" | "z" - 이 축 길이를 상자에 맞춤 · 기본 = 세 축 모두 상자 안), mirror(로블록스 X 반전 - 왼쪽 사본) ·
#   cut: [[축(x|y|z · 원본 GLB 블렌더 축), 값(0 ~ 1 경계 비율), "<" | ">"(남길 쪽)]] · islands(가장 큰 조각 × 비율 미만 조각 삭제) · yaw }
# cfg.partTris = { 부위: 삼각형 }(이 부위는 이 값까지 · 나머지 부위가 남은 예산을 나눔)
def bounds_of(obj):
    vs = [v.co for v in obj.data.vertices]
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    return lo, hi


def cut_plane(obj, ax, val, keep):
    """면 중심이 평면의 한쪽인 면만 남긴다(bisect + 막기는 수백 조각 Meshy 부품에서 감량을 막았다 - 폭풍 건틀릿 17,000에서 멈춤)"""
    lo, hi = bounds_of(obj)
    i = "xyz".index(ax)
    plane = lo[i] + (hi[i] - lo[i]) * val
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    dead = [f for f in bm.faces if (f.calc_center_median()[i] > plane) == (keep == "<")]
    bmesh.ops.delete(bm, geom=dead, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()


def drop_small_islands(obj, ratio):
    isl = islands_of(obj.data)
    count = {}
    for f in isl:
        count[int(f)] = count.get(int(f), 0) + 1
    big = max(count.values())
    kill = {k for k, n in count.items() if n < big * ratio}
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.faces[fi] for fi, k in enumerate(isl) if int(k) in kill], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()
    return len(kill)


def euler_r(r):
    return Matrix.Rotation(math.radians(r[0]), 3, "X") @ Matrix.Rotation(math.radians(r[1]), 3, "Y") @ Matrix.Rotation(math.radians(r[2]), 3, "Z")


def place_addon(spec, gi, byName, glbDir):
    path = spec["glb"] if os.path.isabs(spec["glb"]) else os.path.join(glbDir, spec["glb"])
    obj = import_glb(path, spec.get("yaw", 0))
    for ax, val, keep in spec.get("cut", []):
        cut_plane(obj, ax, val, keep)
    dropped = drop_small_islands(obj, spec["islands"]) if spec.get("islands") else 0
    names = spec["parts"]
    if spec.get("fit", "union") == "union":
        lo, hi = Vector((1e9, 1e9, 1e9)), Vector((-1e9, -1e9, -1e9))
        for n in names:
            l, h = rig_bounds([byName[n]])
            lo = Vector((min(lo.x, l.x), min(lo.y, l.y), min(lo.z, l.z)))
            hi = Vector((max(hi.x, h.x), max(hi.y, h.y), max(hi.z, h.z)))
        boxC, boxS, boxR = (lo + hi) / 2, hi - lo, Matrix.Identity(3)
    else:
        b = byName[spec["fit"]]
        boxC, boxS, boxR = b["center"], b["size"], b["R"]
    Rr = euler_r(spec.get("rot", [0, 0, 0]))
    pts = [Rr @ (CT @ v.co) for v in obj.data.vertices]
    plo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    phi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    pc, ps = (plo + phi) / 2, phi - plo
    ax = spec.get("scaleAxis")
    if ax:
        i = "xyz".index(ax)
        s = boxS[i] / max(ps[i], 1e-6)
    else:
        s = min(boxS[i] / max(ps[i], 1e-6) for i in range(3))
    s *= spec.get("fill", 1.0)
    mx = -1.0 if spec.get("mirror") else 1.0
    st = spec.get("stretch", [1, 1, 1])  # 맞춘 뒤 축별 배율(로블록스 상자 축 - 나가 삼지창 자루 굵게)
    for v, p in zip(obj.data.vertices, pts):
        q = (p - pc) * s
        q = Vector((q.x * mx * st[0], q.y * st[1], q.z * st[2]))
        v.co = C @ (boxC + boxR @ q)
    if spec.get("mirror"):
        obj.data.flip_normals()
    for i, m in enumerate(list(obj.data.materials)):
        if m:
            m2 = m.copy()
            m2.name = "FORCE__%d__%s" % (gi, m.name)
            obj.data.materials[i] = m2
    print("[KIT] 부품 %s → %s · 배율 %.3f · 조각 삭제 %d · 삼각형 %d" % (os.path.basename(path), ",".join(names), s, dropped, tris(obj)))
    return obj


def voxel_remesh(obj, size):
    """복셀 리메시(재질 · UV는 사라짐 - 색은 굽기 원본에서) · 재질 1번 슬롯 유지(부품 표식 FORCE__ 재질 이름이 남아야 한다)"""
    t0 = tris(obj)
    mats = list(obj.data.materials)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    obj.data.remesh_voxel_size = size
    obj.data.remesh_voxel_adaptivity = 0.0
    bpy.ops.object.voxel_remesh()
    obj.data.materials.clear()
    if mats:
        obj.data.materials.append(mats[0])
    if not obj.data.uv_layers:
        obj.data.uv_layers.new(name="UVMap")
    print("[KIT] 복셀 리메시 %s %.4f · 삼각형 %d → %d" % (obj.name, size, t0, tris(obj)))


def forced_from_materials(me, addons):
    forced = {}
    for f in me.polygons:
        m = me.materials[f.material_index] if f.material_index < len(me.materials) else None
        if m and m.name.startswith("FORCE__"):
            gi = int(m.name.split("__")[1])
            forced[f.index] = addons[gi]["parts"]
    return forced


def segment(obj, parts, overlap, forced, skip=(), islands=0.0, faceParts=(), addonParts=()):
    """반환: { 부위 이름: [면 번호] } · forced = { 면 번호: 부위 | [부위 …](BOSS-NIGHT-1 부품 GLB - 그중 가장 가까운 상자) } · Neon 면은 가까운(0.25 안) Neon 리그 부위(눈 · 룬)를 먼저
    addonParts = 부품 GLB만 받는 부위(몸 면은 안 감 · 다른 묶음 부모에서 겹침 복사 안 함)"""
    me = obj.data
    byName = {p["name"]: p for p in parts}
    assign = {p["name"]: [] for p in parts}
    addonSet = set(addonParts)
    neonParts = [p for p in parts if p["material"] == "Neon" and p["name"] not in skip and p["name"] not in addonSet]
    cutParts = [p for p in parts if p["name"] not in skip and p["name"] not in addonSet]
    prio = [p for p in cutParts if p["name"] in faceParts]
    centers = []
    for f in me.polygons:
        c = CT @ f.center
        centers.append(c)
        if f.index in forced:
            fp = forced[f.index]
            if isinstance(fp, list):
                fp = min(fp, key=lambda n: sdf(c, byName[n]))
            assign[fp].append(f.index)
            continue
        if neonParts and f.material_index < len(me.materials) and is_neon(me.materials[f.material_index]):
            np_, nd = None, 0.25
            for p in neonParts:
                d = sdf(c, p)
                if d < nd:
                    np_, nd = p["name"], d
            if np_:
                assign[np_].append(f.index)
                continue
        best, bd = None, 1e9
        for p in cutParts:
            d = sdf(c, p)
            if d < bd:
                best, bd = p["name"], d
        for p in prio:  # faceParts = 큰 상자 안에 박힌 작은 부위(눈썹): 상자 안이면 그 부위가 먼저
            if sdf(c, p) < 0:
                best = p["name"]
                break
        assign[best].append(f.index)
    if islands > 0:  # 떨어진 조각(돌판 · 수정 결정)을 면 과반이 가는 부위에 통째로(자른 틈 · 막은 면 없음)
        isl = islands_of(me)
        partOf = {}
        for name, fs in assign.items():
            for fi in fs:
                partOf[fi] = name
        votes = {}
        for fi, name in partOf.items():
            if fi in forced:
                continue
            v = votes.setdefault(int(isl[fi]), {})
            v[name] = v.get(name, 0) + 1
        winner = {}
        for k, v in votes.items():
            name, cnt = max(v.items(), key=lambda kv: kv[1])
            if cnt >= islands * sum(v.values()):
                winner[k] = name
        assign = {p["name"]: [] for p in parts}
        whole = 0
        for fi, name in partOf.items():
            w = winner.get(int(isl[fi]))
            if w and fi not in forced and name not in faceParts:  # faceParts(눈썹 등 큰 조각의 일부만 움직이는 부위) = 면마다 그대로
                whole += 1
                name = w
            assign[name].append(fi)
        print("[KIT] 조각 %d개 · 통째로 간 조각 %d · 그 면 %d / %d" % (len(votes), len(winner), whole, len(partOf)))
    copies = 0
    for p in parts:
        par = byName.get(p["parent"])
        if not par or overlap <= 0:  # 겹침 0 = 복사 없음(Meshy 돌판은 조각째 가서 틈이 안 보인다 · 같은 면 두 장 = z 싸움)
            continue
        if (p["name"] in addonSet) != (par["name"] in addonSet):  # BOSS-NIGHT-1: 몸 ↔ 부품 사이는 복사 안 함(지팡이에 손 면이 묻지 않게)
            continue
        r = overlap * min(p["size"].x, p["size"].y, p["size"].z) + 0.03
        extra = [fi for fi in assign[par["name"]] if sdf(centers[fi], p) <= r]
        assign[p["name"]] = assign[p["name"]] + extra
        copies += len(extra)
    return assign, copies


# ─────────────────────────── 5 · 6 부위 메시 만들기 ───────────────────────────
def is_neon(mat):
    if not mat:
        return False
    if mat.name.startswith("NEON_") or mat.get("Neon"):
        return True
    if mat.use_nodes:
        b = mat.node_tree.nodes.get("Principled BSDF")
        if b and "Emission Strength" in b.inputs and b.inputs["Emission Strength"].default_value > 0.5:
            return True
    return False


def extract(src, faces, name, origin_rb, col):
    """src 메시에서 면 목록만 새 오브젝트로(원점 = 관절 · 회전 0) · UV · 재질 번호 그대로 · 열린 가장자리 막기"""
    me = src.data
    uv = me.uv_layers.active
    vmap, verts, polys, mats, uvs = {}, [], [], [], []
    o = C @ origin_rb
    for fi in faces:
        f = me.polygons[fi]
        idx = []
        for li in f.loop_indices:
            vi = me.loops[li].vertex_index
            if vi not in vmap:
                vmap[vi] = len(verts)
                verts.append(me.vertices[vi].co - o)
            idx.append(vmap[vi])
            uvs.append(tuple(uv.data[li].uv) if uv else (0.0, 0.0))
        polys.append(idx)
        mats.append(f.material_index)
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], polys)
    for m in me.materials:
        mesh.materials.append(m)
    layer = mesh.uv_layers.new(name="UVMap")
    k = 0
    for p in mesh.polygons:
        p.material_index = mats[p.index]
        for li in p.loop_indices:
            layer.data[li].uv = uvs[k]
            k += 1
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    edges = [e for e in bm.edges if e.is_boundary]
    capped = 0
    capFaces = []
    if edges:
        res = bmesh.ops.holes_fill(bm, edges=edges, sides=0)
        capFaces = list(res.get("faces", []))
        for f in res.get("faces", []):
            # 막은 면 = 둘레에서 가장 많은 재질
            counts = {}
            for e in f.edges:
                for lf in e.link_faces:
                    if lf is not f:
                        counts[lf.material_index] = counts.get(lf.material_index, 0) + 1
            if counts:
                f.material_index = max(counts.items(), key=lambda kv: kv[1])[0]
            capped += 1
    # BOSS-NIGHT-1: 원본 면은 원본 감김(법선) 그대로 - 부위 전체 recalc가 털 덩어리 · 겹친 껍데기에서 면 일부(또는 전부)를 안쪽으로 뒤집어
    #   로블록스(뒷면 안 그림)에서 구멍 + 그 뒤 바깥선 껍데기가 검은 얼룩으로 보였다(매머드). 막은 면만 다시 계산한다.
    if capFaces:
        bmesh.ops.recalc_face_normals(bm, faces=capFaces)
    bm.to_mesh(mesh)
    bm.free()
    # BOSS-NIGHT-1: 겹친 털 덩어리 · 여러 껍데기(Meshy 리메시)에서 recalc가 부위 전체를 안쪽으로 뒤집었다(매머드 엉덩이 8%만 바깥 → 로블록스 뒷면 안 그림 · 바깥선이 비침)
    #   → 원본 면 법선과 대다수가 반대면 통째로 뒤집는다(원본 면 순서 = 앞쪽 len(faces)개 - 막은 면은 뒤에 붙음)
    agree = 0
    for i, fi in enumerate(faces[: len(mesh.polygons)]):
        agree += 1 if mesh.polygons[i].normal.dot(me.polygons[fi].normal) >= 0 else -1
    if agree < 0:
        mesh.flip_normals()
        print("[KIT]   %s 면 방향 뒤집음(원본과 반대였음)" % name)
    obj = bpy.data.objects.new(name, mesh)
    obj.location = o
    col.objects.link(obj)
    return obj, capped


def split_neon(obj, col):
    """Neon 재질 면을 <부위>_DecoN 오브젝트로 떼어 낸다(부위당 1개 - 재질별 색 1개)"""
    out = []
    me = obj.data
    neon_idx = [i for i, m in enumerate(me.materials) if is_neon(m)]
    if not neon_idx:
        return out
    for mi in [neon_idx]:  # 부위당 Neon 조각 1개(재질이 여럿이어도 - 색 = 면 수가 가장 많은 재질)
        faces = [p.index for p in me.polygons if p.material_index in mi]
        if not faces:
            continue
        name = "%s_Deco%d" % (obj.name, len(out) + 1)
        bm = bmesh.new()
        bm.from_mesh(me)
        bm.faces.ensure_lookup_table()
        keep = set(faces)
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index not in keep], context="FACES")
        m2 = bpy.data.meshes.new(name)
        bm.to_mesh(m2)
        bm.free()
        for m in me.materials:
            m2.materials.append(m)
        d = bpy.data.objects.new(name, m2)
        d.location = obj.location
        col.objects.link(d)
        d["Deco"], d["DecoMaterial"], d["Neon"] = obj.name, "Neon", True
        counts = {}
        for p in m2.polygons:
            counts[p.material_index] = counts.get(p.material_index, 0) + 1
        d["NeonMat"] = max(counts.items(), key=lambda kv: kv[1])[0]
        out.append(d)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index in neon_idx], context="FACES")
    bm.to_mesh(me)
    bm.free()
    return out


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def decimate(o, target):
    t = tris(o)
    if t <= target or t == 0:
        return
    # BOSS-NIGHT-1: 복셀 리메시 메시는 한 번에 약 × 0.09까지만 줄었다 → 목표에 닿을 때까지 최대 4번
    for _ in range(4):
        cur = tris(o)
        if cur <= target * 1.15:
            break
        m = o.modifiers.new("KitDecimate", "DECIMATE")
        m.decimate_type = "COLLAPSE"
        m.ratio = max(target / cur, 0.01)
        m.use_collapse_triangulate = True
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=m.name)
        if tris(o) >= cur * 0.98:
            break
    if tris(o) > target * 1.5:
        print("[KIT] 감량 덜 됨 %s %d → %d(목표 %d · 사용자 %d)" % (o.name, t, tris(o), target, o.data.users))


# ─────────────────────────── 8 아틀라스 ───────────────────────────
def base_color(m):
    if m and m.get("PaletteRGB"):  # artlib 재질(생성 Neon 등) = 지정 색(새 재질의 노드 기본 색 0.8 회색이 아니라)
        c = m.diffuse_color
        return (c[0], c[1], c[2])
    if m and m.use_nodes:
        b = m.node_tree.nodes.get("Principled BSDF")
        if b:
            c = b.inputs["Base Color"].default_value
            return (c[0], c[1], c[2])
    if m:
        c = m.diffuse_color
        return (c[0], c[1], c[2])
    return (0.6, 0.6, 0.6)


def lin_to_srgb(x):
    return 12.92 * x if x <= 0.0031308 else 1.055 * (x ** (1 / 2.4)) - 0.055


def textures_of(objs, base_only=False):
    imgs = []
    for o in objs:
        for m in o.data.materials:
            if m and m.use_nodes:
                for n in m.node_tree.nodes:
                    if n.type == "TEX_IMAGE" and n.image and n.image not in imgs:
                        if base_only and not any(l.to_socket.name == "Base Color" for l in n.outputs["Color"].links):
                            continue  # 거칠기 · 노멀 맵(로블록스 MeshPart TextureID = 색만)
                        imgs.append(n.image)
    return imgs


# ─────────────────────────── GUARDIAN-V2 굽기(감량 부위 ← 원본 고해상 색) ───────────────────────────
def bake_atlas(objs, hi, cfg, path, imgName="KIT_BAKE"):
    size = cfg.get("size", 1024)
    img = bpy.data.images.new(imgName, size, size, alpha=False)
    mat = bpy.data.materials.new("KIT_BAKE")
    mat.use_nodes = True
    nt = mat.node_tree
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    nt.links.new(tex.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
    nt.nodes.active = tex
    for o in objs:
        o.data.materials.clear()
        o.data.materials.append(mat)
        for uv in list(o.data.uv_layers):
            o.data.uv_layers.remove(uv)
        o.data.uv_layers.new(name="UVMap")
    # 새 UV: 부위 전부를 한 번에 편집 → Smart UV → 한 장에 묶기(부위끼리 겹치지 않음)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.004, area_weight=0.0, scale_to_bounds=False)
    bpy.ops.uv.pack_islands(margin=0.004, rotate=True)
    bpy.ops.object.mode_set(mode="OBJECT")
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 1
    b = sc.render.bake
    b.use_selected_to_active = True
    b.use_pass_direct, b.use_pass_indirect, b.use_pass_color = False, False, True
    b.cage_extrusion = cfg.get("extrusion", 0.04)
    b.max_ray_distance = cfg.get("distance", 0.12)
    b.margin = 6
    b.use_clear = False
    for o in objs:
        bpy.ops.object.select_all(action="DESELECT")
        h = hi(o) if callable(hi) else hi  # BOSS-NIGHT-1: 부위마다 굽기 원본(몸 / 부품 묶음 - 겹친 부품 표면 색을 집지 않게)
        h.select_set(True)
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, use_selected_to_active=True, use_clear=False, margin=6)
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    print("[KIT] 굽기 %d부위 → %s(%d)" % (len(objs), os.path.basename(path), size))


# ─────────────────────────── GUARDIAN-V2 텍스처 색 → Neon · 생성 Neon ───────────────────────────
def base_image(me):
    for m in me.materials:
        if m and m.use_nodes:
            for n in m.node_tree.nodes:
                if n.type == "TEX_IMAGE" and n.image and any(l.to_socket.name == "Base Color" for l in n.outputs["Color"].links):
                    return n.image
    return None


def face_colors(me, img):
    """면마다 텍스처 색(sRGB 0 ~ 1 - 면 UV 평균 자리 한 점)"""
    import numpy as np
    w, h = img.size
    px = np.zeros(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)
    uv = np.zeros(len(me.loops) * 2, dtype=np.float32)
    me.uv_layers.active.data.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2)
    start = np.zeros(len(me.polygons), dtype=np.int64)
    total = np.zeros(len(me.polygons), dtype=np.int64)
    me.polygons.foreach_get("loop_start", start)
    me.polygons.foreach_get("loop_total", total)
    idx = np.repeat(np.arange(len(me.polygons)), total)
    su = np.bincount(idx, weights=uv[:, 0]) / total
    sv = np.bincount(idx, weights=uv[:, 1]) / total
    x = np.clip((su % 1.0) * w, 0, w - 1).astype(np.int64)
    y = np.clip((sv % 1.0) * h, 0, h - 1).astype(np.int64)
    return px[y, x, :3]  # 이미지 픽셀 = sRGB 저장값


def neon_by_color(src, assign, cfg):
    """cfg.parts 부위 면 중 수정 색(밝고 파랑 > 초록) 면 → NEON_ 재질(split_neon이 <부위>_Deco로 뗀다) · 색 = 평균 → 가장 낮은 채널 ≤ maxChannel"""
    me = src.data
    img = base_image(me)
    if not img:
        return 0
    col = face_colors(me, img)
    vmax = col.max(axis=1)
    hit = (vmax >= cfg.get("minValue", 0.45)) & (col[:, 2] - col[:, 1] >= cfg.get("blueOverGreen", 0.08))
    n = 0
    for name in cfg["parts"]:
        fs = [fi for fi in assign.get(name, []) if hit[fi]]
        if not fs:
            print("[KIT] 수정 색 → Neon %-14s 면 0" % name)
            continue
        mean = col[fs].mean(axis=0)
        rgb = [c * 255 for c in mean]
        top = max(rgb)
        rgb = [min(255.0, c * 255 / top) for c in rgb]  # 가장 밝은 채널 = 255(빛)
        cap = cfg.get("maxChannel", 90)
        lo = min(range(3), key=lambda i: rgb[i])
        rgb[lo] = min(rgb[lo], cap)  # 흰 날림 방지(Neon 색 = 가장 낮은 채널 ≤ 90)
        rgb = tuple(int(round(c)) for c in rgb)
        mat = A.material("NEON_%s" % name, rgb, neon=True)
        me.materials.append(mat)
        mi = len(me.materials) - 1
        for fi in fs:
            me.polygons[fi].material_index = mi
        n += len(fs)
        print("[KIT] 수정 색 → Neon %-14s 면 %6d · 색 %s" % (name, len(fs), rgb))
    return n


def clip_half(poly, nx, ny, c):
    """볼록 다각형을 nx·x + ny·y ≤ c 쪽만 남긴다(Sutherland-Hodgman)"""
    out = []
    for i in range(len(poly)):
        a, b = poly[i], poly[(i + 1) % len(poly)]
        da, db = nx * a[0] + ny * a[1] - c, nx * b[0] + ny * b[1] - c
        if da <= 0:
            out.append(a)
        if (da < 0) != (db < 0):
            k = da / (da - db)
            out.append((a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k))
    return out


def plate(sec2d, at, depth):
    """2D 단면(x, y)을 앞(−Z)을 보는 판으로(두께 depth · 가운데 at)"""
    g = A.loft([A.section_z(sec2d, -depth / 2), A.section_z(sec2d, depth / 2)])
    return A.xform(g, t=at)


def gen_geo(g):
    at, size = g["at"], g["size"]
    if g["shape"] == "eyes":  # 두 눈(at = 두 눈 가운데 · size = [눈 사이 거리, 반지름, 두께])
        gap, r, dep = size
        geos = []
        for side in (-1, 1):
            cx = at[0] + side * gap / 2
            v = g.get("variant", "normal")
            if v == "angry":  # 위쪽 안쪽을 비스듬히 깎은 반달(눈썹이 누른 눈)
                poly = clip_half(A.circle2d(r, 20), -side * 0.6, 1.0, r * 0.12)
                geos.append(plate(poly, (cx, at[1], at[2]), dep))
            elif v == "dazed":  # 소용돌이(두 바퀴 · 띠 굵기 r × 0.13)
                pts = []
                for i in range(40):
                    k = i / 39.0
                    a = side * (k * 4 * math.pi)
                    rr = r * (0.18 + 0.82 * k)
                    pts.append((cx + rr * math.cos(a), at[1] + rr * math.sin(a), at[2]))
                geos.append(A.tube(pts, r * 0.13, sides=5))
            else:
                geos.append(plate(A.circle2d(r, 20), (cx, at[1], at[2]), dep))
        return A.merge(*geos)
    if g["shape"] == "rune":  # 마름모 판 + 앞으로 솟은 꼭지(빛 맺힘)
        w, h, dep = size
        ring = [(0, h / 2), (-w / 2, 0), (0, -h / 2), (w / 2, 0)]
        back = A.section_z(ring, at[2] + dep / 2)
        front = A.section_z([(x * 0.55, y * 0.55) for x, y in ring], at[2] - dep / 2)
        verts, faces = A.loft([back, front], cap0=True, tip1=(0, 0, at[2] - dep))
        return A.xform((verts, faces), t=(at[0], at[1], 0))
    if g["shape"] == "bell":  # BOSS-NIGHT-1 4: 닫힌 종 모양 치마(at = 허리 가운데 · profile = [[y, 반지름] …] 위 → 아래 · 두께 size[0] · 안팎 양면 + 단 = 닫힌 껍데기)
        seg_n, th = int(g.get("segments", 32)), size[0]
        prof = g["profile"]
        rings = [(y, r) for y, r in prof] + [(y, max(0.01, r - th)) for y, r in reversed(prof)]
        verts, faces = [], []
        for y, r in rings:
            for i in range(seg_n):
                a = 2 * math.pi * i / seg_n
                verts.append((at[0] + r * math.cos(a), y, at[2] + r * math.sin(a)))
        n = len(rings)
        for k in range(n):  # 마지막 고리 → 첫 고리(허리 위 테두리)까지 이어 닫는다
            k2 = (k + 1) % n
            for i in range(seg_n):
                i2 = (i + 1) % seg_n
                faces.append((k * seg_n + i, k * seg_n + i2, k2 * seg_n + i2, k2 * seg_n + i))
        return verts, faces
    raise ValueError("모양 %s" % g["shape"])


def palette_atlas(objs, size, path):
    """색 재질 → 팔레트 아틀라스 1장(칸 = size/32) · 면마다 칸 가운데 UV · 재질 1개(KIT_ATLAS)로 묶음"""
    cell = size // 32
    colors, index = [], {}
    for o in objs:
        for m in o.data.materials:
            c = tuple(round(lin_to_srgb(x), 4) for x in base_color(m))
            if c not in index:
                index[c] = len(colors)
                colors.append(c)
    assert len(colors) <= 32 * 32, "색이 너무 많다(%d)" % len(colors)
    img = bpy.data.images.new("KIT_ATLAS", size, size, alpha=False)
    px = [0.0] * (size * size * 4)
    for i, c in enumerate(colors):
        cx, cy = (i % 32) * cell, (i // 32) * cell
        for y in range(cy, cy + cell):
            row = y * size
            for x in range(cx, cx + cell):
                k = (row + x) * 4
                px[k], px[k + 1], px[k + 2], px[k + 3] = c[0], c[1], c[2], 1.0
    img.pixels = px
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    mat = bpy.data.materials.new("KIT_ATLAS")
    mat.use_nodes = True
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    mat.node_tree.links.new(tex.outputs["Color"], mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    for o in objs:
        me = o.data
        uv = me.uv_layers.active or me.uv_layers.new(name="UVMap")
        for p in me.polygons:
            c = tuple(round(lin_to_srgb(x), 4) for x in base_color(me.materials[p.material_index] if p.material_index < len(me.materials) else None))
            i = index[c]
            u = ((i % 32) * cell + cell / 2) / size
            v = ((i // 32) * cell + cell / 2) / size
            for li in p.loop_indices:
                uv.data[li].uv = (u, v)
        me.materials.clear()
        me.materials.append(mat)
    return len(colors)


# ─────────────────────────── 실행 ───────────────────────────
def main():
    o = parse()
    rigId, parts = load_rig(o["rig"])
    name = o["name"] or rigId
    os.makedirs(o["out"], exist_ok=True)
    scratch = os.path.join(o["out"], "_kit")
    os.makedirs(scratch, exist_ok=True)
    glb = o["glb"]
    if o["fake"]:
        glb = os.path.join(scratch, "%s_fake_source.glb" % o["fake"])
        build_fake(o["fake"], glb)
    A.reset()
    src = import_glb(glb, o["yaw"])
    src_tris = tris(src)
    forced = {}
    for path, part in o["parts"]:  # 따로 만든 부위: 몸 전체에 붙여 넣고 그 면은 그 부위로
        n0 = len(src.data.polygons)
        extra = import_glb(path, o["yaw"])
        bpy.ops.object.select_all(action="DESELECT")
        src.select_set(True)
        extra.select_set(True)
        bpy.context.view_layer.objects.active = src
        bpy.ops.object.join()
        for fi in range(n0, len(src.data.polygons)):
            forced[fi] = part
    addons = o["cfg"].get("addons") or []
    addonParts = [n for a in addons for n in a["parts"]]
    if addons:  # BOSS-NIGHT-1: 몸 높이 맞춤 → 부품을 리그 상자에 맞춰 붙임 → 그 뒤에 굽기 원본 복사(아래 fit는 건너뜀)
        byName0 = {p["name"]: p for p in parts}
        decimate(src, o["cfg"].get("bodyPreTris", 200000))
        fit_height(src, o["cfg"]["height"])
        glbDir = os.path.dirname(o["glb"])
        his = {}
        def hiCopy(obj, key):
            h = obj.copy()
            h.data = obj.data.copy()
            bpy.context.scene.collection.objects.link(h)
            h.name = "KIT_HI_%s" % key
            his[key] = h
        if o["cfg"].get("bake"):
            hiCopy(src, "body")
        partTris0 = o["cfg"].get("partTris", {})
        if o["cfg"].get("bodyVoxel"):  # BOSS-NIGHT-1: 원본(리메시본 없음)을 복셀로 다시 짜서(닫힌 매끈한 면) 감량 - 79만 → 1.8만 직접 감량은 조각난 톱니였다 · 색은 원본(굽기)
            voxel_remesh(src, o["cfg"]["bodyVoxel"])
            decimate(src, 4 * max(o["budget"] - sum(partTris0.values()), 4000))
        for gi, spec in enumerate(addons):
            a = place_addon(spec, gi, byName0, glbDir)
            decimate(a, spec.get("preTris", 60000))
            if o["cfg"].get("bake"):
                hiCopy(a, gi)
            if spec.get("voxel"):
                voxel_remesh(a, spec["voxel"])
                decimate(a, 4 * max(sum(partTris0.get(n, 500) for n in spec["parts"]), 1000))
            bpy.ops.object.select_all(action="DESELECT")
            src.select_set(True)
            a.select_set(True)
            bpy.context.view_layer.objects.active = src
            bpy.ops.object.join()
        src_tris = tris(src)
    hi = None
    if addons and o["cfg"].get("bake"):  # 부위 이름 → 그 묶음 굽기 원본
        groupOf = {n: gi for gi, a in enumerate(addons) for n in a["parts"]}
        hi = lambda ob: his[groupOf.get(ob.name, "body")]
    elif o["cfg"].get("bake"):  # 굽기 원본 = 감량 전 고해상(UV 그대로) - 아래에서 같은 크기 맞춤
        hi = src.copy()
        hi.data = src.data.copy()
        bpy.context.scene.collection.objects.link(hi)
        hi.name = "KIT_HI"
    # 아주 큰 원본은 먼저 전체를 예산 × 4로 줄인다(자르기 속도)
    if tris(src) > o["budget"] * 4 and not addons:  # BOSS-NIGHT-1: 부품 경로는 묶음별로 이미 줄였다(합친 뒤 전체 감량은 평평한 몸 면부터 지워 몸이 무너졌다)
        decimate(src, o["budget"] * 4)
    cfg = o["cfg"]
    if addons:
        forced = forced_from_materials(src.data, addons)
    elif cfg.get("height"):
        bounds = fit_height(hi or src, cfg["height"])
        if hi:
            fit_height(src, cfg["height"], bounds)
    else:
        fit(src, parts)
    skip = set(cfg.get("skip", []))
    assign, copies = segment(src, parts, o["overlap"], forced, skip, cfg.get("islands", 0.0), set(cfg.get("faceParts", [])), addonParts)
    if cfg.get("neonByColor"):
        neon_by_color(src, assign, cfg["neonByColor"])
    col = A.new_collection("KIT_" + name)
    objs, capped, empty = [], 0, []
    byName = {p["name"]: p for p in parts}
    gens = {g["part"]: g for g in cfg.get("generate", []) if g.get("part")}
    for p in parts:
        faces = assign[p["name"]]
        if p["name"] in gens:  # 생성 Neon 부위(눈 · 룬 - 원본 면 대신)
            g = gens[p["name"]]
            objs.append(A.make_obj(p["name"], gen_geo(g), tuple(g["color"]), col, neon=g.get("neon", True), origin=tuple(p["joint"]), smooth=not g.get("neon", True)))
            continue
        if not faces:
            empty.append(p["name"])
            # 빈 부위 = 관절 자리 아주 작은 상자(끼우기는 되고 옛 상자는 사라진다 - 보이지 않음)
            geo = A.box(0.02, 0.02, 0.02, center=tuple(p["center"]))
            ob = A.make_obj(p["name"], geo, (128, 128, 128), col, origin=tuple(p["joint"]))
            objs.append(ob)
            continue
        ob, c = extract(src, faces, p["name"], p["joint"], col)
        capped += c
        objs.append(ob)
    # Neon 조각 예산(≤ 10 - 리그 Neon 부위 포함): Neon 면이 많은 부위부터 조각으로 떼고, 넘치는 부위의 Neon 면은 일반 면(아틀라스 색)으로 남긴다
    rigNeon = [x for x in objs if byName[x.name]["material"] == "Neon"]
    genDecos = []
    for g in cfg.get("generate", []):  # 생성 Neon 장식(표정 눈 모양 - 부위에 용접 · 클라가 보이기를 바꾼다)
        if g.get("deco"):
            host = byName[g["host"]]
            d = A.make_obj(g["deco"], gen_geo(g), tuple(g["color"]), col, neon=True, origin=tuple(host["joint"]))
            d["Deco"], d["DecoMaterial"], d["Neon"], d["NeonMat"] = g["host"], "Neon", True, 0
            genDecos.append(d)
    def nfaces(x):
        return sum(1 for p in x.data.polygons if p.material_index < len(x.data.materials) and is_neon(x.data.materials[p.material_index]))
    cands = sorted([x for x in objs if x not in rigNeon and nfaces(x) > 0], key=lambda x: -nfaces(x))
    room = max(0, 10 - len(rigNeon) - len(genDecos))
    decos, demoted = list(genDecos), []
    for x in cands[:room]:
        decos += split_neon(x, col)
    for x in cands[room:]:
        demoted.append(x.name)
        for m in x.data.materials:
            if m and m.name.startswith("NEON_"):
                m.name = m.name[5:] + "_demoted"
                m["Neon"] = False
    # 7 감량(부위 ≤ partCap · 합계 ≤ budget - 원본 비율로 나눔)
    partTris = cfg.get("partTris", {})
    for x in objs:  # BOSS-NIGHT-1: 부위별 목표(부품 · 무기)
        if x.name in partTris:
            decimate(x, partTris[x.name])
    total = sum(tris(x) for x in objs + decos if x.name not in partTris)
    room = o["budget"] - sum(partTris[x.name] for x in objs if x.name in partTris)  # 부품 몫 = 목표값(감량이 덜 된 부품 때문에 몸이 뭉개지지 않게)
    if total > room:
        k = room / total
        for x in objs + decos:
            if x.name in gens or x in genDecos or x.name in partTris:  # 생성 Neon(눈 모양 · 룬) · 부위별 목표는 그대로
                continue
            decimate(x, min(o["partCap"], max(12, int(tris(x) * k))))
    for x in objs:
        decimate(x, o["partCap"])
    if cfg.get("decoCap"):  # 수정 Neon 조각 감량(통째로 빛나는 면 - 결정 모양만 남으면 된다)
        for d in decos:
            if d not in genDecos:
                decimate(d, cfg["decoCap"])
    # 8 텍스처(아틀라스)
    hi_baked = False
    imgs = textures_of(objs, cfg.get("texture") == "base")
    atlas_files = []
    partAtlas = {}
    if hi:
        bakeObjs = [x for x in objs if x not in rigNeon and x.name not in empty and x.name not in gens]  # 생성 부위(종 치마) = 리그 색 그대로(굽지 않음)
        groups = [set(g) for g in cfg.get("atlasGroups", [])]  # BOSS-NIGHT-1: 아틀라스 2 · 3장째로 보낼 부위(나머지 = 1장째) - 1024 × 3장 예산 안에서 해상도
        lists = [[x for x in bakeObjs if not any(x.name in g for g in groups)]] + [[x for x in bakeObjs if x.name in g] for g in groups]
        for ai, lst in enumerate(lists):
            if not lst:
                continue
            fn = "%s_atlas%d.png" % (name, ai + 1)
            bake_atlas(lst, hi, cfg["bake"], os.path.join(o["out"], fn), "KIT_BAKE" if ai == 0 else "KIT_BAKE%d" % (ai + 1))
            atlas_files.append(fn)
            for x in lst:
                partAtlas[x.name] = len(atlas_files)
        ncolors = None
        for h in (list(his.values()) if callable(hi) else [hi]):
            bpy.data.objects.remove(h, do_unlink=True)
        hi_baked = True
    elif imgs:
        assert len(imgs) <= 3, "원본 텍스처 %d장 > 3(아틀라스로 굽기 필요)" % len(imgs)
        for i, im in enumerate(imgs):
            if max(im.size) > o["atlas"]:
                im.scale(o["atlas"], o["atlas"])
            fn = "%s_atlas%d.png" % (name, i + 1)
            im.filepath_raw = os.path.join(o["out"], fn)
            im.file_format = "PNG"
            im.save()
            atlas_files.append(fn)
        ncolors = None
    else:
        fn = "%s_atlas1.png" % name
        ncolors = palette_atlas([x for x in objs if x not in rigNeon], o["atlas"], os.path.join(o["out"], fn))
        atlas_files.append(fn)
    # Neon 조각 색(메타 color = 재질 색 · Studio가 칠한다)
    for d in decos:
        mi = d.get("NeonMat", 0)
        c = base_color(d.data.materials[mi]) if len(d.data.materials) > mi else (1, 1, 1)
        d.data.materials.clear()
        d.data.materials.append(A.material("KIT_NEON_%s" % d.name, tuple(int(round(lin_to_srgb(x) * 255)) for x in c), neon=True))
    # 9 외곽선 껍데기(큰 부위부터 · 눈 · 입 · 아주 작은 부위 제외)
    cand = sorted([x for x in objs if x.name not in ("Eyes", "Mouth") and x.name not in empty and tris(x) >= 24 and x.name not in addonParts and x.name not in cfg.get("outlineSkip", [])],
                  key=lambda x: -(byName[x.name]["size"].x * byName[x.name]["size"].y * byName[x.name]["size"].z))
    for x in objs:
        x["RigPart"] = x.name
        x["TriCount"] = tris(x)
        x["Joint"] = byName[x.name]["jointName"]
    for d in decos:
        d["RigPart"] = d.name
        d["TriCount"] = tris(d)
    hulls = [A.add_hull(x, thickness=o["hull"], export=True, col=col) for x in cand[: o["outlines"]]]
    ht = sum(tris(h) for h in hulls)
    if ht > o["outlineTris"]:
        k = o["outlineTris"] * 0.95 / ht  # 감량은 목표를 조금 넘긴다(접힘) - 여유 5%
        for h in hulls:
            decimate(h, max(12, int(tris(h) * k)))
    for h in hulls:
        h["TriCount"] = tris(h)
    allo = objs + decos + hulls
    body_t = sum(tris(x) for x in objs + decos)
    out_t = sum(tris(h) for h in hulls)
    neon_n = len(decos) + len(rigNeon)
    over = [k for k, ok in (("삼각형", body_t <= o["budget"]), ("부위", max(tris(x) for x in objs) <= o["partCap"]), ("외곽선 삼각형", out_t <= o["outlineTris"]),
                            ("MeshPart", len(allo) <= 90), ("외곽선", len(hulls) <= 12), ("Neon", neon_n <= 10), ("아틀라스", len(atlas_files) <= 3)) if not ok]
    print("[KIT] %s: 원본 삼각형 %d → 부위 %d(빈 부위 %d %s) · Neon 조각 %d · 외곽선 %d · 삼각형 %d(외곽선 %d) · 겹침 복사 면 %d · 막은 면 %d · 아틀라스 %d장(%s) · 예산 초과 %s" % (
        name, src_tris, len(objs), len(empty), ",".join(empty), len(decos), len(hulls), body_t, out_t, copies, capped, len(atlas_files),
        ("색 %d칸" % ncolors) if ncolors else "원본 텍스처", ",".join(over) or "없음"))
    for x in objs:
        print("[KIT]   %-14s 삼각형 %5d" % (x.name, tris(x)))
    # 10 내보내기
    bpy.data.objects.remove(src, do_unlink=True)
    A.export_fbx(os.path.join(o["out"], "%s.fbx" % name), allo)
    meta = A.meta_of(allo, o["budget"], {
        "version": "KIT1", "rigId": rigId, "partCap": o["partCap"], "joints": {x.name: x["Joint"] for x in objs},
        "deco": {d.name: d["Deco"] for d in decos}, "decoMaterial": {d.name: "Neon" for d in decos}, "lod2": [], "outlineParts": [h.name for h in hulls],
        "texture": dict({"atlases": atlas_files, "parts": [x.name for x in objs if x.name not in empty and x not in rigNeon and not (hi_baked and x.name in gens)]}, **({"partAtlas": partAtlas} if len(atlas_files) > 1 else {})), "kit": {"neonDemoted": demoted, "source": os.path.basename(glb), "sourceTris": src_tris, "overlapCopies": copies, "capped": capped, "empty": empty},
        "space": "sizeScale 1 · 루트 원점 · 발바닥 y −1.5 · 앞 −Z", "metaName": name})
    A.write_json(os.path.join(o["out"], "%s.meta.json" % name), meta)
    if hi_baked:  # 원본(유료 · 비공개 라이선스) 텍스처를 .blend에 싸 넣지 않는다 - 구운 아틀라스만 남김
        for im in list(bpy.data.images):
            if not im.name.startswith("KIT_BAKE"):
                bpy.data.images.remove(im)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(o["out"], "%s.blend" % name))
    print("[KIT] 내보냄 %s.fbx · .meta.json · .blend · %s" % (os.path.join(o["out"], name), ", ".join(atlas_files)))
    if o["render"]:
        orig = A.setup_render

        def tex_setup(kind, res=(900, 900)):  # 아틀라스가 보이게(Workbench 텍스처 색)
            sc = orig(kind, res)
            if kind == "game":
                sc.display.shading.color_type = "TEXTURE"
            return sc
        A.setup_render = tex_setup
        A.render_views(objs + decos + hulls, os.path.join(o["render"], name), kinds=("game",), sil=False, hull=0.0, res=(900, 900))
        A.setup_render = orig


if __name__ == "__main__":  # BOSS-NIGHT-1: prop_kit.py가 decimate · bake_atlas를 가져다 쓴다(가져올 때는 main 안 돎)
    main()
