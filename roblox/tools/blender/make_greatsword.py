# -*- coding: utf-8 -*-
# A2-S2 대검 저폴리 카툰(Blender bpy) - 형태 1개 × 등급 look 3단계(normal · legendary · transcendent). 치수 · 색 = ArtStyleV1Data.greatsword와 같은 값.
#   파트마다 오브젝트 1개(이름 = ArtV1Models 파트 이름: Blade · Fuller · Guard · Grip · Pommel · Wing_R · Wing_L · Gem · Crack1 · Crack2)
#   원점(피벗) = 손잡이 점(WeaponRigSpec greatsword grip) · 부착점 Grip(0) · Tip(칼끝) · Support(보조 손)은 메타에 적는다.
#   출력(--out 폴더 · 기본 roblox/art/weapons - Rojo 동기화 밖):
#     greatsword_<look>.fbx(Studio 3D 가져오기 · Open Cloud용) · greatsword.blend · greatsword.meta.json(파트별 삼각형 · 부착점)
#     greatsword_<look>.preview.luau(Studio 확인용 - EditableMesh로 같은 모양을 짓는 execute_luau 코드 · Play 전용 · 저장 안 됨)
#   --render <폴더>: 정면 · 45도 PNG(Workbench · 외곽선)
# 실행: blender -b --factory-startup -P make_greatsword.py -- [--out 폴더] [--render 폴더]
# 좌표: 도형은 Roblox 무기 로컬(+Z 칼끝 · +X 날 폭 · Y 두께 · stud)로 짓고 Blender에는 make_rig_mesh.py와 같은 축 바꾸기(Blender = (X, -Z, Y))로 놓는다.
import bpy
import bmesh
import json
import math
import os
import sys
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "art", "weapons"))
RENDER = None

C = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))  # Roblox → Blender
TRI_BUDGET = 800  # style-bible §12 무기

# ── 치수(ArtStyleV1Data.greatsword - 손잡이 점 z = -1.1을 원점으로 옮긴 값) ──
G = 1.1
BLADE = dict(width=0.96, thick=0.2, bevel=0.14, z0=-0.17 + G, z1=2.95 + G, tip=0.62)
FULLER = dict(width=0.22, thick=0.24, z0=0.05 + G, z1=2.55 + G)
GUARD = dict(size=(1.7, 0.34, 0.38), z=-0.36 + G)
GRIP = dict(length=1.15, radius=0.15, z=0.0, sides=8)
POMMEL = dict(radius=0.23, z=-1.78 + G)
WING = dict(size=(0.3, 0.75, 0.6), x=1.05)  # ArtStyleV1Data(0.95 × 0.85)는 메시 날개가 가시처럼 커 보였다(첫 렌더) → 줄임
GEM = 0.5
CRACKS = [dict(x=0.18, z=0.8 + G, ry=18), dict(x=-0.2, z=1.9 + G, ry=-22)]
ATTACH = dict(Grip=(0, 0, 0), Tip=(0, 0, BLADE["z1"] + BLADE["tip"]), Support=(0, 0, -1.58 + G))

GRADE_LEGENDARY = (255, 153, 51)  # ItemVisualData.legendary.color
GOLD = (214, 176, 62)
LOOKS = {
    "normal": dict(steel=(206, 212, 224), fuller=(150, 158, 174), guard=(112, 104, 98), grip=(96, 62, 40), pommel=(112, 104, 98)),
    "legendary": dict(steel=(232, 236, 244), fuller=GRADE_LEGENDARY, guard=GRADE_LEGENDARY, grip=(90, 48, 30), pommel=GRADE_LEGENDARY,
                      wings=True, gem=(255, 244, 214), neon=("Gem",)),
    "transcendent": dict(steel=(38, 34, 48), fuller=GOLD, guard=GOLD, grip=(24, 22, 32), pommel=GOLD,
                         wings=True, gem=(255, 214, 90), cracks=(255, 208, 92), neon=("Fuller", "Gem", "Crack1", "Crack2")),
}


def parse_args():
    global OUT, RENDER
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for i, a in enumerate(argv):
        if a == "--out":
            OUT = os.path.abspath(argv[i + 1])
        elif a == "--render":
            RENDER = os.path.abspath(argv[i + 1])


# ── 도형(Roblox 공간 점 · 면 목록) ──
def prism(section, z0, z1, tip_z=None):
    """단면(xy 목록 · 반시계)을 z0 → z1로 밀고, tip_z가 있으면 끝을 한 점으로 모은다(없으면 뚜껑)"""
    n = len(section)
    verts = [(x, y, z0) for x, y in section] + [(x, y, z1) for x, y in section]
    faces = [tuple(reversed(range(n)))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    if tip_z is None:
        faces.append(tuple(range(n, 2 * n)))
    else:
        verts.append((0, 0, tip_z))
        t = len(verts) - 1
        for i in range(n):
            faces.append((n + i, n + (i + 1) % n, t))
    return verts, faces


def box(sx, sy, sz, bevel=0.0):
    hx, hy, hz = sx / 2, sy / 2, sz / 2
    b = min(bevel, hx * 0.9, hy * 0.9)
    sec = [(hx, -hy + b), (hx, hy - b), (hx - b, hy), (-hx + b, hy), (-hx, hy - b), (-hx, -hy + b), (-hx + b, -hy), (hx - b, -hy)] if b > 0 else [(hx, -hy), (hx, hy), (-hx, hy), (-hx, -hy)]
    return prism(sec, -hz, hz)


def ico(radius, scale=(1, 1, 1), subdiv=1):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius)
    verts = [(v.co.x * scale[0], v.co.y * scale[1], v.co.z * scale[2]) for v in bm.verts]
    faces = [tuple(v.index for v in f.verts) for f in bm.faces]
    bm.free()
    return verts, faces


def moved(geo, dx=0, dy=0, dz=0, ry_deg=0, rz_deg=0):
    verts, faces = geo
    cy, sy = math.cos(math.radians(ry_deg)), math.sin(math.radians(ry_deg))
    cz, sz = math.cos(math.radians(rz_deg)), math.sin(math.radians(rz_deg))
    out = []
    for x, y, z in verts:
        x, z = x * cy + z * sy, -x * sy + z * cy
        x, y = x * cz - y * sz, x * sz + y * cz
        out.append((x + dx, y + dy, z + dz))
    return out, faces


def parts_for(look):
    L = LOOKS[look]
    b = BLADE
    hw, ht, bv = b["width"] / 2, b["thick"] / 2, b["bevel"]
    # 날 단면 = 모따기한 육각(가운데 두껍고 날 쪽으로 얇게 - 판처럼 보이지 않게)
    blade_sec = [(hw, 0), (hw - bv, ht), (-hw + bv, ht), (-hw, 0), (-hw + bv, -ht), (hw - bv, -ht)]
    parts = [
        ("Blade", prism(blade_sec, b["z0"], b["z1"], b["z1"] + b["tip"]), L["steel"]),
        ("Fuller", moved(box(FULLER["width"], FULLER["thick"], FULLER["z1"] - FULLER["z0"], 0.05), dz=(FULLER["z0"] + FULLER["z1"]) / 2), L["fuller"]),
        ("Guard", moved(box(*GUARD["size"], bevel=0.08), dz=GUARD["z"]), L["guard"]),
        ("Grip", prism([(GRIP["radius"] * math.cos(a), GRIP["radius"] * math.sin(a)) for a in [i * 2 * math.pi / GRIP["sides"] for i in range(GRIP["sides"])]],
                       GRIP["z"] - GRIP["length"] / 2, GRIP["z"] + GRIP["length"] / 2), L["grip"]),
        ("Pommel", moved(ico(POMMEL["radius"], subdiv=1), dz=POMMEL["z"]), L["pommel"]),
    ]
    if L.get("wings"):
        sx, sy, sz = WING["size"]
        wz = GUARD["z"] + GUARD["size"][2] / 2 + sy / 2 - 0.1
        # 날개 = 칼끝 쪽으로 솟은 삼각 판(바깥이 높다)
        for name, sgn in (("Wing_R", 1), ("Wing_L", -1)):
            sec = [(0, -sy / 2), (sgn * sz, -sy / 2 + 0.1), (sgn * sz * 0.35, sy / 2)]
            if sgn < 0:
                sec = list(reversed(sec))
            verts, faces = prism([(x, z) for x, z in sec], -sx / 2, sx / 2)
            # 단면 (x, y) = (바깥, 위) → Roblox (x, z) · 두께 = y
            verts = [(x + sgn * (WING["x"] - sz * 0.5), zz, yy + wz) for x, yy, zz in verts]
            parts.append((name, (verts, faces), L["guard"]))
    if L.get("gem"):
        parts.append(("Gem", moved(ico(GEM / 2, scale=(1, 1, 1.2), subdiv=1), dz=GUARD["z"]), L["gem"]))
    if L.get("cracks"):
        for i, c in enumerate(CRACKS):
            parts.append(("Crack%d" % (i + 1), moved(box(0.07, 0.25, 1.1), dx=c["x"], dz=c["z"], ry_deg=c["ry"]), L["cracks"]))
    return parts


def srgb_to_linear(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def material(name, rgb, neon):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    lin = [srgb_to_linear(c) for c in rgb]
    mat.diffuse_color = (lin[0], lin[1], lin[2], 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (lin[0], lin[1], lin[2], 1.0)
        bsdf.inputs["Roughness"].default_value = 1.0
        for key in ("Specular IOR Level", "Specular"):
            if key in bsdf.inputs:
                bsdf.inputs[key].default_value = 0.0
        if neon and "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = (lin[0], lin[1], lin[2], 1.0)
            bsdf.inputs["Emission Strength"].default_value = 1.5
    mat["PaletteRGB"] = "#%02X%02X%02X" % tuple(rgb)
    mat["Neon"] = bool(neon)
    return mat


def make_object(look, name, geo, rgb, neon, col):
    verts, faces = geo
    mesh = bpy.data.meshes.new("%s_%s" % (look, name))
    mesh.from_pydata([tuple(C @ Vector(v)) for v in verts], [], faces)
    mesh.validate()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)  # 손으로 적은 면 순서가 섞여도 바깥 법선
    bm.to_mesh(mesh)
    bm.free()
    for p in mesh.polygons:
        p.use_smooth = False
    obj = bpy.data.objects.new(name, mesh)  # 이름 = 파트 이름(내보낸 뒤 main이 look 접미사를 붙여 다음 look과 안 겹치게)
    obj.location = (0, 0, 0)  # 원점 = 손잡이 점
    col.objects.link(obj)
    obj.data.materials.append(material("greatsword_%s_%s" % (look, name), rgb, neon))
    tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
    obj["TriCount"] = tris
    obj["RigPart"] = name
    return obj, tris


def triangulate(verts, faces):
    out = []
    for f in faces:
        for i in range(1, len(f) - 1):
            out.append((f[0], f[i], f[i + 1]))
    return out


def geo_of(obj):
    """Blender 메시(법선 정리 뒤) → Roblox 공간 점 · 면"""
    Ct = C.transposed()
    return [tuple(Ct @ v.co) for v in obj.data.vertices], [tuple(p.vertices) for p in obj.data.polygons]


def preview_luau(look, parts):
    """Studio 확인용: EditableMesh로 파트를 짓고 ReplicatedStorage.Shared.WeaponModels.greatsword(클라 복사본)에 넣는다(Play 전용)"""
    L = LOOKS[look]
    neon = set(L.get("neon", ()))
    lines = [
        "-- 생성: roblox/tools/blender/make_greatsword.py (%s) - Studio Play 클라 execute_luau 전용(EditableMesh는 저장 · 복제 안 됨)" % look,
        "local AssetService = game:GetService('AssetService')",
        "local RS = game:GetService('ReplicatedStorage')",
        "local P = {",
    ]
    for name, (verts, faces), rgb in parts:
        tris = triangulate(verts, faces)
        lo = [min(v[i] for v in verts) for i in range(3)]
        hi = [max(v[i] for v in verts) for i in range(3)]
        ctr = [(lo[i] + hi[i]) / 2 for i in range(3)]
        flat = []
        for t in tris:
            for k in t:
                v = verts[k]
                flat.append("%.4f,%.4f,%.4f" % (v[0] - ctr[0], v[1] - ctr[1], v[2] - ctr[2]))
        lines.append("  { name = '%s', color = Color3.fromRGB(%d, %d, %d), neon = %s, center = Vector3.new(%.4f, %.4f, %.4f), v = { %s } }," % (
            name, rgb[0], rgb[1], rgb[2], "true" if name in neon else "false", ctr[0], ctr[1], ctr[2], ",".join(flat)))
    lines += [
        "}",
        "local model = Instance.new('Model')",
        "model.Name = 'greatsword'",
        "local blade",
        "for _, p in ipairs(P) do",
        "  local em = AssetService:CreateEditableMesh()",
        "  for i = 1, #p.v, 9 do",
        "    local a = em:AddVertex(Vector3.new(p.v[i], p.v[i + 1], p.v[i + 2]))",
        "    local b = em:AddVertex(Vector3.new(p.v[i + 3], p.v[i + 4], p.v[i + 5]))",
        "    local c = em:AddVertex(Vector3.new(p.v[i + 6], p.v[i + 7], p.v[i + 8]))",
        "    em:AddTriangle(a, b, c)",
        "  end",
        "  local part = AssetService:CreateMeshPartAsync(Content.fromObject(em))",
        "  part.Name = p.name",
        "  part.Color = p.color",
        "  part.Material = p.neon and Enum.Material.Neon or Enum.Material.SmoothPlastic",
        "  part.CFrame = CFrame.new(p.center)",
        "  part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false",
        "  part:SetAttribute('TriCount', #p.v // 9)",
        "  part.Parent = model",
        "  if p.name == 'Blade' then blade = part end",
        "end",
        "for name, pos in pairs({ Grip = Vector3.new(%.4f, %.4f, %.4f), Tip = Vector3.new(%.4f, %.4f, %.4f), Support = Vector3.new(%.4f, %.4f, %.4f) }) do" % (
            ATTACH["Grip"] + ATTACH["Tip"] + ATTACH["Support"]),
        "  local a = Instance.new('Attachment')",
        "  a.Name = name",
        "  a.Position = blade.CFrame:PointToObjectSpace(pos)",
        "  a.Parent = blade",
        "end",
        "model:SetAttribute('TrailTop', Vector3.new(0, 0, %.4f))" % (2.2 + G),
        "model:SetAttribute('TrailBottom', Vector3.new(0, 0, %.4f))" % (-1.3 + G),
        "model:SetAttribute('BlenderLook', '%s')" % look,
        "model.PrimaryPart = blade",
        "model.WorldPivot = CFrame.identity",
        "local folder = RS.Shared:FindFirstChild('WeaponModels') or Instance.new('Folder')",
        "folder.Name = 'WeaponModels'",
        "folder.Parent = RS.Shared",
        "local old = folder:FindFirstChild('greatsword')",
        "if old then old:Destroy() end",
        "model.Parent = folder",
        "return ('blender greatsword %s: parts %%d'):format(#model:GetChildren())" % look,
    ]
    return "\n".join(lines) + "\n"


def export_fbx(path, objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"}, global_scale=1.0, apply_unit_scale=True,
                             apply_scale_options="FBX_SCALE_NONE", axis_forward="-Z", axis_up="Y", bake_space_transform=True,
                             mesh_smooth_type="FACE", use_custom_props=True, add_leaf_bones=False, bake_anim=False, embed_textures=False)


def render(groups):
    """세 look을 나란히 세워(칼끝 위) 정면 · 45도 PNG"""
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    sh = scene.display.shading
    sh.light = "STUDIO"
    sh.color_type = "MATERIAL"
    sh.show_object_outline = True
    sh.object_outline_color = (0.118, 0.106, 0.180)
    sh.show_cavity = False
    sh.show_specular_highlight = False
    scene.render.resolution_x, scene.render.resolution_y = 1200, 1000
    scene.render.film_transparent = False
    world = scene.world or bpy.data.worlds.new("World")
    scene.world = world
    sh.background_type = "VIEWPORT"
    sh.background_color = (0.86, 0.9, 0.95)
    for i, (look, objs) in enumerate(groups):
        pivot = bpy.data.objects.new("Stand_" + look, None)
        scene.collection.objects.link(pivot)
        pivot.location = ((i - 1) * 3.0, 0, 0)
        pivot.rotation_euler = (math.radians(-90), 0, 0)  # 칼끝(Blender -y) → 위(+z)
        for o in objs:
            o.parent = pivot
    target = bpy.data.objects.new("Target", None)
    scene.collection.objects.link(target)
    target.location = (0, 0, 1.9)
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 9.5
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    tc = cam.constraints.new("TRACK_TO")
    tc.target = target
    tc.track_axis = "TRACK_NEGATIVE_Z"
    tc.up_axis = "UP_Y"
    os.makedirs(RENDER, exist_ok=True)
    shots = {"front": (0, -20, 1.9), "34": (14.1, -14.1, 5.0)}
    for name, loc in shots.items():
        if name == "34":  # 45도: 각 칼을 제자리에서 45° 돌린다(나란히 선 줄은 그대로)
            for grp in bpy.data.objects:
                if grp.name.startswith("Stand_"):
                    grp.rotation_euler = (math.radians(-90), 0, math.radians(45))  # 세운 뒤 월드 Z(칼 긴 축)로 45°
            loc = (0, -20, 6.0)
        cam.location = loc
        scene.render.filepath = os.path.join(RENDER, "blender-greatsword-%s.png" % name)
        bpy.ops.render.render(write_still=True)
        print("[make_greatsword] 렌더 %s" % scene.render.filepath)


def main():
    parse_args()
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    meta = {"rigId": "greatsword", "source": "blender %s" % bpy.app.version_string, "pivot": "Grip", "attachments": ATTACH, "triBudget": TRI_BUDGET, "looks": {}}
    groups = []
    for look in ("normal", "legendary", "transcendent"):
        col = bpy.data.collections.new("greatsword_" + look)
        bpy.context.scene.collection.children.link(col)
        parts = parts_for(look)
        neon = set(LOOKS[look].get("neon", ()))
        objs, total, per = [], 0, {}
        for name, geo, rgb in parts:
            o, tris = make_object(look, name, geo, rgb, name in neon, col)
            objs.append(o)
            per[name] = tris
            total += tris
        meta["looks"][look] = {"parts": per, "totalTris": total}
        print("[make_greatsword] %s 파트 %d · 삼각형 합 %d(예산 %d)%s" % (look, len(objs), total, TRI_BUDGET, " 초과!" if total > TRI_BUDGET else ""))
        export_fbx(os.path.join(OUT, "greatsword_%s.fbx" % look), objs)
        with open(os.path.join(OUT, "greatsword_%s.preview.luau" % look), "w", encoding="utf-8", newline="\n") as f:
            f.write(preview_luau(look, [(o.name, geo_of(o), rgb) for o, (_, _, rgb) in zip(objs, parts)]))
        for o in objs:
            o.name = "%s.%s" % (o.name, look)
        groups.append((look, objs))
    with open(os.path.join(OUT, "greatsword.meta.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(meta, f, ensure_ascii=False, indent=1)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "greatsword.blend"))
    if RENDER:
        render(groups)
    print("[make_greatsword] 끝 · 출력 %s" % OUT)


if __name__ == "__main__":
    main()
