# -*- coding: utf-8 -*-
# ============================================================================================
#  [미실행 · 미검증] 이 스크립트는 Blender가 없는 환경에서 작성했다. 첫 실행 때 README의 "첫 실행 확인 목록"을 본다.
# ============================================================================================
# B3 저폴리 카툰 생물 템플릿(Blender bpy): 리그 규격 JSON(rig_dump.py 결과 - 예 rigs/moss_slime.rig.json)으로
#   ① 파트마다 오브젝트 1개(이름 = 리그 파트 이름) · 원점(피벗) = 관절 자리 · 기준 자세(규격 rot) 그대로
#   ② 팔레트 색 재질(파트마다 1색 - 색 = 리그 색 역할 · 스폰과 같은 색) · 평면 음영(질감 없음)
#   ③ 삼각형 수를 커스텀 속성 "TriCount"로(오브젝트마다) + Luau 메타 파일(roblox/src/shared/MeshMeta/<리그 id>.lua)
#   ④ 기준 루트 "HumanoidRootPart"(원점의 작은 상자 - 검사기 · 교체 도우미가 기준 프레임으로 읽는다)
#   ⑤ FBX 내보내기(Roblox 3D Importer용 축 · 배율 · 변환 적용)
# 모양은 "시작점"이다: 기본 도형(공 = 아이코스피어 · 상자 = 모서리 깎은 상자 · 쐐기)을 규격 크기로 놓는다 → 아티스트가 Edit 모드에서
#   다듬는다(오브젝트 원점 · 이름은 건드리지 않는다). 다듬은 뒤 이 스크립트를 --export-only로 다시 돌리면 삼각형 수 · 메타 · FBX만 새로 쓴다.
#
# 실행(명령줄 - Blender 3.6 이상 가정):
#   blender --background --python make_rig_mesh.py -- --rig rigs/moss_slime.rig.json
#   blender moss_slime.blend --background --python make_rig_mesh.py -- --rig rigs/moss_slime.rig.json --export-only
# 실행(Blender 안): Scripting 탭 → 이 파일 열기 → 아래 CONFIG의 rig 경로를 고치고 Run Script.
#
# 좌표: 리그 JSON = Roblox 공간(+Y 위 · -Z 앞 · stud). Blender = +Z 위. FBX 내보내기 axis_forward="-Z" · axis_up="Y"(Blender 기본값)는
#   Roblox(X, Y, Z) = Blender(x, z, -y)로 바꾼다 → 여기서는 거꾸로 Blender(x, y, z) = Roblox(X, -Z, Y)로 놓는다(= 모델 앞이 Blender +Y).
#   1 Blender 단위 = 1 stud(Studio 가져오기 단위 = Stud - 문서 §4).
import bpy
import bmesh
import json
import os
import sys
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROBLOX = os.path.normpath(os.path.join(HERE, "..", ".."))  # roblox/

CONFIG = {
    "rig": os.path.join(HERE, "rigs", "moss_slime.rig.json"),
    "fbx_dir": os.path.join(REPO_ROBLOX, "art", "rigs"),  # 내보낸 FBX · .blend(원본) 자리 - Rojo 동기화 밖
    "meta_dir": os.path.join(REPO_ROBLOX, "src", "shared", "MeshMeta"),  # Luau 메타(Rojo → ReplicatedStorage.Shared.MeshMeta)
    "ico_subdiv": 2,  # 공 = 아이코스피어 2단계(80삼각형)
    "bevel_ratio": 0.12,  # 상자 모서리 깎기 = 가장 짧은 변 × 이 값(1단 - 44삼각형)
    "root_size": 0.2,  # 기준 루트 상자 한 변(stud)
    "export_only": False,
}

# Roblox → Blender 축 바꾸기(고유 회전 - 거울 아님)
C = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))


def r2b(v):
    return C @ Vector(v)


def rot_r2b(r9):
    R = Matrix(((r9[0], r9[1], r9[2]), (r9[3], r9[4], r9[5]), (r9[6], r9[7], r9[8])))
    return C @ R @ C.transposed()


def srgb_to_linear(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--rig":
            CONFIG["rig"] = os.path.abspath(argv[i + 1]); i += 1
        elif a == "--fbx-dir":
            CONFIG["fbx_dir"] = os.path.abspath(argv[i + 1]); i += 1
        elif a == "--meta-dir":
            CONFIG["meta_dir"] = os.path.abspath(argv[i + 1]); i += 1
        elif a == "--export-only":
            CONFIG["export_only"] = True
        i += 1


def material_for(name, rgb):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    lin = [srgb_to_linear(c) for c in rgb]
    mat.diffuse_color = (lin[0], lin[1], lin[2], 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (lin[0], lin[1], lin[2], 1.0)
        bsdf.inputs["Roughness"].default_value = 1.0
        # 스펙큘러 0(카툰 - style-bible §0-2). Blender 4.x = "Specular IOR Level" · 3.x = "Specular"
        for key in ("Specular IOR Level", "Specular"):
            if key in bsdf.inputs:
                bsdf.inputs[key].default_value = 0.0
    # 정수 목록 속성은 FBX 내보내기(use_custom_props)가 float64 단정에서 멈춘다(Blender 5.2 첫 실행 - A2-S2) → 16진 문자열
    mat["PaletteRGB"] = "#%02X%02X%02X" % tuple(int(c) for c in rgb)
    return mat


def build_bmesh(shape, size):
    """원점 가운데 · 크기 = size(Blender 축 - 이미 바꾼 값)인 도형"""
    bm = bmesh.new()
    if shape == "ball":
        bmesh.ops.create_icosphere(bm, subdivisions=CONFIG["ico_subdiv"], radius=0.5)
    elif shape == "wedge":
        # Roblox WedgePart: 경사면이 앞(-Z) 위를 향한다 - 뒤(+Z) 면이 높은 면. Roblox 로컬 → 여기서 바로 Blender 축으로
        pts = [(-0.5, -0.5, -0.5), (0.5, -0.5, -0.5), (-0.5, -0.5, 0.5), (0.5, -0.5, 0.5), (-0.5, 0.5, 0.5), (0.5, 0.5, 0.5)]
        vs = [bm.verts.new(r2b(p)) for p in pts]
        for f in ((0, 1, 3, 2), (2, 3, 5, 4), (0, 2, 4), (1, 5, 3), (0, 4, 5, 1)):
            bm.faces.new([vs[i] for i in f])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    else:  # block · cyl(지금 BossRig.build는 cyl도 상자로 짓는다)
        bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size.x, v.co.y * size.y, v.co.z * size.z))
    if shape not in ("ball", "wedge"):
        width = min(size.x, size.y, size.z) * CONFIG["bevel_ratio"]
        try:
            bmesh.ops.bevel(bm, geom=list(bm.edges), offset=width, segments=1, affect="EDGES", profile=0.5)
        except TypeError:  # Blender 2.9x 이하 인자 이름
            bmesh.ops.bevel(bm, geom=list(bm.edges), offset=width, segments=1, vertex_only=False, profile=0.5)
    return bm


def tri_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def make_part(rig_id, part, collection):
    name = part["name"]
    joint_b = r2b(part["joint"])
    center_b = r2b(part["center"])
    R_b = rot_r2b(part["rotation"])
    s = part["size"]
    size_b = Vector((abs(s[0]), abs(s[2]), abs(s[1])))  # Roblox (X, Y, Z) 크기 → Blender (x, y, z) = (X, Z, Y)
    bm = build_bmesh(part["shape"], size_b)
    # 파트 로컬(가운데 원점) → 관절 원점 공간: 회전(기준 자세) 뒤 (가운데 − 관절) 만큼 옮긴다
    offset = center_b - joint_b
    for v in bm.verts:
        v.co = R_b @ v.co + offset
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = False  # 평면 음영
    obj = bpy.data.objects.new(name, mesh)
    obj.location = joint_b  # 원점(피벗) = 관절
    collection.objects.link(obj)
    obj.data.materials.append(material_for("%s_%s" % (rig_id, name), part["color"]))
    obj["RigPart"] = name
    obj["JointName"] = part["jointName"]
    return obj


def make_root(collection, rig_id):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=CONFIG["root_size"])
    mesh = bpy.data.meshes.new("HumanoidRootPart")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("HumanoidRootPart", mesh)
    obj.location = (0, 0, 0)
    collection.objects.link(obj)
    obj.data.materials.append(material_for("%s_Root" % rig_id, (30, 27, 46)))
    return obj


def rig_collection(rig_id):
    col = bpy.data.collections.get(rig_id)
    if not col:
        col = bpy.data.collections.new(rig_id)
        bpy.context.scene.collection.children.link(col)
    return col


def write_meta(rig, objs):
    os.makedirs(CONFIG["meta_dir"], exist_ok=True)
    path = os.path.join(CONFIG["meta_dir"], rig["rigId"] + ".lua")
    lines = [
        "-- 생성: roblox/tools/blender/make_rig_mesh.py(손으로 고치지 않는다 - Blender에서 다시 내보내면 덮어쓴다)",
        "-- 가져온 모델 %s의 파트별 삼각형 수 · Blender 원점(관절 · Roblox 공간). 검사기(/gg mesh check)가 파트 Attribute TriCount가 없을 때 읽는다." % rig["rigId"],
        "return {",
        '\trigId = "%s",' % rig["rigId"],
        '\tsource = "blender %s",' % bpy.app.version_string,
        "\tparts = {",
    ]
    total = 0
    for obj in objs:
        tris = tri_count(obj)
        total += tris
        loc = obj.location
        jr = (loc.x, loc.z, -loc.y)  # Blender → Roblox
        lines.append("\t\t%s = { tris = %d, joint = { %.4f, %.4f, %.4f } }," % (obj.name, tris, jr[0], jr[1], jr[2]))
    lines += ["\t},", "\ttotalTris = %d," % total, "}", ""]
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    return path, total


def export_fbx(rig_id, objs):
    os.makedirs(CONFIG["fbx_dir"], exist_ok=True)
    path = os.path.join(CONFIG["fbx_dir"], rig_id + ".fbx")
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=True,
        object_types={"MESH"},
        global_scale=1.0,
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_NONE",
        axis_forward="-Z",
        axis_up="Y",
        bake_space_transform=True,  # "Apply Transform" - 축 바꾸기를 메시에 굽는다(가져온 파트 회전 0)
        use_mesh_modifiers=True,
        mesh_smooth_type="FACE",  # 면 단위 법선 = 평면 음영
        use_custom_props=True,  # TriCount → (가져오기가 옮겨 주면) Attribute - 미검증
        add_leaf_bones=False,
        bake_anim=False,
        path_mode="AUTO",
        embed_textures=False,
    )
    return path


def main():
    parse_args()
    with open(CONFIG["rig"], encoding="utf-8") as f:
        rig = json.load(f)
    rig_id = rig["rigId"]
    col = rig_collection(rig_id)
    names = [p["name"] for p in rig["parts"]]
    if CONFIG["export_only"]:
        objs = [bpy.data.objects[n] for n in names if n in bpy.data.objects]
        missing = [n for n in names if n not in bpy.data.objects]
        if missing:
            raise SystemExit("리그 파트 오브젝트가 없다: " + ", ".join(missing))
    else:
        for n in names + ["HumanoidRootPart"]:  # 다시 만들기: 같은 이름 오브젝트를 지운다
            old = bpy.data.objects.get(n)
            if old:
                bpy.data.objects.remove(old, do_unlink=True)
        objs = [make_part(rig_id, p, col) for p in rig["parts"]]
    for o in objs:
        o["TriCount"] = tri_count(o)
    root = bpy.data.objects.get("HumanoidRootPart") or make_root(col, rig_id)
    meta_path, total = write_meta(rig, objs)
    budget = rig.get("triBudget")
    print("[make_rig_mesh] %s 파트 %d · 삼각형 합 %d(예산 %s) · 메타 %s" % (rig_id, len(objs), total, budget, meta_path))
    if budget and total > budget:
        print("[make_rig_mesh] 경고: 예산 초과 - 검사 ③-2가 X")
    fbx = export_fbx(rig_id, objs + [root])
    blend = os.path.join(CONFIG["fbx_dir"], rig_id + ".blend")
    if not bpy.data.filepath:
        bpy.ops.wm.save_as_mainfile(filepath=blend)
    print("[make_rig_mesh] FBX %s" % fbx)


if __name__ == "__main__":
    main()
