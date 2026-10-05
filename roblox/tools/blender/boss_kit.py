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
# 실행: bash bl.sh boss_kit.py --rig rigs/section_guardian_v2.rig.json --fake section_guardian [--render 폴더]
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
         "atlas": 1024, "out": os.path.join(ART, "bosses"), "render": None, "hull": 0.06, "name": None}
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
        elif k in ("--out", "--render", "--name"):
            o[k[2:]] = v
        i += 2
    if not os.path.isabs(o["rig"]):
        o["rig"] = os.path.join(HERE, o["rig"])
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


# ─────────────────────────── 3 · 4 부위 자르기 + 겹침 ───────────────────────────
def segment(obj, parts, overlap, forced):
    """반환: { 부위 이름: [면 번호] } · forced = { 면 번호: 부위 }(따로 만든 부위 GLB) · Neon 면은 가까운(0.25 안) Neon 리그 부위(눈 · 룬)를 먼저"""
    me = obj.data
    byName = {p["name"]: p for p in parts}
    assign = {p["name"]: [] for p in parts}
    neonParts = [p for p in parts if p["material"] == "Neon"]
    centers = []
    for f in me.polygons:
        c = CT @ f.center
        centers.append(c)
        if f.index in forced:
            assign[forced[f.index]].append(f.index)
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
        for p in parts:
            d = sdf(c, p)
            if d < bd:
                best, bd = p["name"], d
        assign[best].append(f.index)
    copies = 0
    for p in parts:
        par = byName.get(p["parent"])
        if not par:
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
    if edges:
        res = bmesh.ops.holes_fill(bm, edges=edges, sides=0)
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
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
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
    m = o.modifiers.new("KitDecimate", "DECIMATE")
    m.decimate_type = "COLLAPSE"
    m.ratio = max(target / t, 0.01)
    m.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier=m.name)


# ─────────────────────────── 8 아틀라스 ───────────────────────────
def base_color(m):
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


def textures_of(objs):
    imgs = []
    for o in objs:
        for m in o.data.materials:
            if m and m.use_nodes:
                for n in m.node_tree.nodes:
                    if n.type == "TEX_IMAGE" and n.image and n.image not in imgs:
                        imgs.append(n.image)
    return imgs


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
    # 아주 큰 원본은 먼저 전체를 예산 × 4로 줄인다(자르기 속도)
    if tris(src) > o["budget"] * 4:
        decimate(src, o["budget"] * 4)
    fit(src, parts)
    assign, copies = segment(src, parts, o["overlap"], forced)
    col = A.new_collection("KIT_" + name)
    objs, capped, empty = [], 0, []
    byName = {p["name"]: p for p in parts}
    for p in parts:
        faces = assign[p["name"]]
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
    def nfaces(x):
        return sum(1 for p in x.data.polygons if p.material_index < len(x.data.materials) and is_neon(x.data.materials[p.material_index]))
    cands = sorted([x for x in objs if x not in rigNeon and nfaces(x) > 0], key=lambda x: -nfaces(x))
    room = max(0, 10 - len(rigNeon))
    decos, demoted = [], []
    for x in cands[:room]:
        decos += split_neon(x, col)
    for x in cands[room:]:
        demoted.append(x.name)
        for m in x.data.materials:
            if m and m.name.startswith("NEON_"):
                m.name = m.name[5:] + "_demoted"
                m["Neon"] = False
    # 7 감량(부위 ≤ partCap · 합계 ≤ budget - 원본 비율로 나눔)
    total = sum(tris(x) for x in objs + decos)
    if total > o["budget"]:
        k = o["budget"] / total
        for x in objs + decos:
            decimate(x, min(o["partCap"], max(12, int(tris(x) * k))))
    for x in objs:
        decimate(x, o["partCap"])
    # 8 텍스처(아틀라스)
    imgs = textures_of(objs)
    atlas_files = []
    if imgs:
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
    cand = sorted([x for x in objs if x.name not in ("Eyes", "Mouth") and x.name not in empty and tris(x) >= 24],
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
        k = o["outlineTris"] / ht
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
        "texture": {"atlases": atlas_files, "parts": [x.name for x in objs if x.name not in empty and x not in rigNeon]}, "kit": {"neonDemoted": demoted, "source": os.path.basename(glb), "sourceTris": src_tris, "overlapCopies": copies, "capped": capped, "empty": empty},
        "space": "sizeScale 1 · 루트 원점 · 발바닥 y −1.5 · 앞 −Z"})
    A.write_json(os.path.join(o["out"], "%s.meta.json" % name), meta)
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


main()
