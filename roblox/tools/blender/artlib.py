# -*- coding: utf-8 -*-
# A2-N1 Blender 공용 라이브러리 - 팔레트 · 형태 도우미(테이퍼 로프트 · 곡선 튜브 · 회전체 · Bevel) · 등급 사다리 색 · 렌더 2종 · FBX 내보내기 · 메타.
#   도형은 전부 Roblox 공간(+Y 위 · −Z 앞 · stud)으로 짓고 오브젝트를 만들 때 Blender 축((X, −Z, Y))으로 바꾼다(make_greatsword.py · make_rig_mesh.py와 같은 규칙).
#   오브젝트 1개 = 파트 1개 · 이름 = 리그 파트 이름 · 원점 = 관절(무기 = 손잡이) · 재질 = 단색 1개(색은 Studio에서 데이터가 칠한다 - 여기 색은 렌더 · 미리보기용).
#   FBX = A2-S2에서 고친 방식(재질 커스텀 속성은 문자열 · 축 −Z 앞 / Y 위 · FBX_SCALE_NONE · 모디파이어 미적용 = 렌더용 외곽선 껍데기는 안 나간다).
import bpy
import bmesh
import json
import math
import os
from mathutils import Matrix, Vector

C = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))  # Roblox → Blender
CT = C.transposed()

# ── 팔레트(art-direction-v1 §3 · ItemVisualData · CartoonStyleData) ──
OUTLINE = (30, 27, 46)  # #1E1B2E - 가장 어두운 색(순검정 금지)
GRADES = ["normal", "rare", "epic", "legendary", "relic", "ancient", "primordial", "transcendent"]
GRADE_KO = {"normal": "일반", "rare": "희귀", "epic": "영웅", "legendary": "전설", "relic": "유물", "ancient": "고대", "primordial": "태초", "transcendent": "초월"}
GRADE_COLOR = {
    "normal": (230, 230, 230), "rare": (77, 166, 255), "epic": (166, 77, 255), "legendary": (255, 153, 51),
    "relic": (255, 215, 0), "ancient": (224, 57, 62), "primordial": (255, 60, 200), "transcendent": (214, 176, 62),
}
GOLD = (214, 176, 62)
GOLD_GLOW = (255, 208, 92)
BLACK_BODY = (38, 34, 48)
BLACK_SHADE = (24, 22, 32)
STEEL = (206, 212, 224)
STEEL_BRIGHT = (232, 236, 244)
STEEL_SHADE = (150, 158, 174)
IRON = (112, 104, 98)
LEATHER = (96, 62, 40)
LEATHER_DARK = (90, 48, 30)
WOOD = (104, 66, 40)
WOOD_TOP = (140, 96, 58)
ZONE = {
    "hub": dict(ground=(108, 194, 74), main=(217, 201, 163), shade=(139, 90, 43), accent=(79, 209, 255)),
    "tier1": dict(ground=(123, 201, 80), main=(168, 162, 154), shade=(110, 106, 102), accent=(92, 224, 138)),
    "tier2": dict(ground=(75, 58, 140), main=(210, 108, 240), shade=(42, 31, 85), accent=(210, 108, 240)),
    "tier3": dict(ground=(46, 196, 214), main=(201, 228, 234), shade=(27, 127, 168), accent=(127, 240, 255)),
}


def mul(c, k):
    return tuple(max(0, min(255, int(round(v * k)))) for v in c)


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


# ── 기하(점 목록 · 면 목록 - Roblox 공간) ──
def merge(*geos):
    verts, faces = [], []
    for v, f in geos:
        base = len(verts)
        verts += list(v)
        faces += [tuple(i + base for i in face) for face in f]
    return verts, faces


def xform(geo, m=None, t=(0, 0, 0), s=(1, 1, 1)):
    """점마다 배율 s → 회전 행렬 m(3×3 Matrix) → 이동 t"""
    v, f = geo
    out = []
    for p in v:
        q = Vector((p[0] * s[0], p[1] * s[1], p[2] * s[2]))
        if m is not None:
            q = m @ q
        out.append((q.x + t[0], q.y + t[1], q.z + t[2]))
    return out, f


def rot(rx=0, ry=0, rz=0):
    """도 단위 · 적용 순서 X → Y → Z(Roblox CFrame.Angles와 같은 곱 순서)"""
    return (Matrix.Rotation(math.radians(rx), 3, "X") @ Matrix.Rotation(math.radians(ry), 3, "Y") @ Matrix.Rotation(math.radians(rz), 3, "Z"))


def mirror_x(geo):
    v, f = geo
    return [(-x, y, z) for x, y, z in v], [tuple(reversed(face)) for face in f]


def loft(rings, cap0=True, cap1=True, tip0=None, tip1=None):
    """rings = 같은 점 수의 고리 목록(각 고리 = 3D 점 목록, 순서 일정). 옆면 사각 + 끝은 뚜껑 또는 한 점(tip)으로 모은다."""
    n = len(rings[0])
    verts = [p for ring in rings for p in ring]
    faces = []
    for r in range(len(rings) - 1):
        a, b = r * n, (r + 1) * n
        for i in range(n):
            j = (i + 1) % n
            faces.append((a + i, a + j, b + j, b + i))
    last = (len(rings) - 1) * n
    if tip0 is not None:
        verts.append(tuple(tip0))
        t = len(verts) - 1
        faces += [(t, (i + 1) % n, i) for i in range(n)]
    elif cap0:
        faces.append(tuple(reversed(range(n))))
    if tip1 is not None:
        verts.append(tuple(tip1))
        t = len(verts) - 1
        faces += [(last + i, last + (i + 1) % n, t) for i in range(n)]
    elif cap1:
        faces.append(tuple(range(last, last + n)))
    return verts, faces


def section_z(sec2d, z, sx=1.0, sy=1.0, dx=0.0, dy=0.0):
    """2D 단면(x, y)을 높이 z(축 = Roblox Z)에 놓는다 - 테이퍼 = sx · sy"""
    return [(x * sx + dx, y * sy + dy, z) for x, y in sec2d]


def taper_prism(sec2d, stations, tip=None, tip_base=False):
    """stations = [(z, sx, sy, dx), ...] - 끝으로 갈수록 가늘게. tip = 마지막 고리 뒤 한 점(칼끝)"""
    rings = [section_z(sec2d, z, sx, sy, dx) for z, sx, sy, dx in stations]
    return loft(rings, tip1=tip)


def circle2d(r, n, rx=None, start=0.0):
    rx = r if rx is None else rx
    return [(rx * math.cos(start + 2 * math.pi * i / n), r * math.sin(start + 2 * math.pi * i / n)) for i in range(n)]


def chamfer_rect(w, h, b):
    """모서리를 b만큼 깎은 8각 단면(가로 w · 세로 h)"""
    hx, hy = w / 2, h / 2
    b = min(b, hx * 0.95, hy * 0.95)
    return [(hx, -hy + b), (hx, hy - b), (hx - b, hy), (-hx + b, hy), (-hx, hy - b), (-hx, -hy + b), (-hx + b, -hy), (hx - b, -hy)]


def box(sx, sy, sz, b=0.0, center=(0, 0, 0)):
    sec = chamfer_rect(sx, sy, b) if b > 0 else [(sx / 2, -sy / 2), (sx / 2, sy / 2), (-sx / 2, sy / 2), (-sx / 2, -sy / 2)]
    g = loft([section_z(sec, -sz / 2), section_z(sec, sz / 2)])
    return xform(g, t=center)


def lathe(profile, n=10, axis="Y"):
    """profile = [(반지름, 높이), ...] 아래 → 위. 반지름 0인 끝은 한 점으로 모은다. axis = 회전축(Roblox)"""
    rings, tip0, tip1 = [], None, None
    pts = list(profile)
    if pts[0][0] <= 1e-6:
        tip0 = (0, pts[0][1], 0)
        pts = pts[1:]
    if pts[-1][0] <= 1e-6:
        tip1 = (0, pts[-1][1], 0)
        pts = pts[:-1]
    for r, h in pts:
        rings.append([(r * math.cos(2 * math.pi * i / n), h, r * math.sin(2 * math.pi * i / n)) for i in range(n)])
    # 고리 방향을 바깥 법선이 되게(아래 → 위 · 반시계를 위에서 봤을 때) - 법선은 오브젝트에서 다시 계산한다
    g = loft(rings, tip0=tip0, tip1=tip1)
    if axis == "Z":
        g = xform(g, m=rot(rx=90))
    elif axis == "X":
        g = xform(g, m=rot(rz=-90))
    return g


def ellipsoid(r=(1, 1, 1), n=10, rings=6, center=(0, 0, 0), squash_bottom=1.0):
    """저폴리 타원체(위아래 극 한 점). squash_bottom < 1 = 아랫면을 납작하게(슬라임 · 몸통 바닥)"""
    prof = []
    for k in range(rings + 1):
        a = -math.pi / 2 + math.pi * k / rings
        y = math.sin(a)
        if y < 0:
            y *= squash_bottom
        prof.append((math.cos(a), y))
    prof[0] = (0.0, prof[0][1])
    prof[-1] = (0.0, prof[-1][1])
    g = lathe(prof, n)
    return xform(g, s=r, t=center)


def frames_along(path):
    """경로 점마다 (접선 T, 법선 N, 종법선 B) - 평행 이동 틀(뒤틀림 없음)"""
    pts = [Vector(p) for p in path]
    tans = []
    for i in range(len(pts)):
        a = pts[max(0, i - 1)]
        b = pts[min(len(pts) - 1, i + 1)]
        tans.append((b - a).normalized())
    ref = Vector((0, 0, 1)) if abs(tans[0].z) < 0.9 else Vector((1, 0, 0))
    n = tans[0].cross(ref).normalized()
    out = []
    for i, t in enumerate(tans):
        if i > 0:
            n = (n - t * n.dot(t)).normalized()
        out.append((t, n, t.cross(n).normalized()))
    return pts, out


def tube(path, radius, sides=6, cap0=True, tip_end=False, flat=1.0, twist=0.0):
    """곡선 튜브(가드 말림 · 꼬리 · 뿔 · 엄니). radius = 숫자 또는 함수(0..1 → r). flat = 단면 납작 비율(1 = 원). tip_end = 끝을 한 점으로"""
    pts, fr = frames_along(path)
    rings = []
    m = len(pts)
    rng = range(m - 1) if tip_end else range(m)
    for i in rng:
        u = i / (m - 1)
        r = radius(u) if callable(radius) else radius
        t, nrm, bn = fr[i]
        ring = []
        for k in range(sides):
            a = 2 * math.pi * k / sides + twist
            off = nrm * (math.cos(a) * r) + bn * (math.sin(a) * r * flat)
            ring.append(tuple(pts[i] + off))
        rings.append(ring)
    return loft(rings, cap0=cap0, tip1=tuple(pts[-1]) if tip_end else None)


def bezier(p0, p1, p2, p3, n=8):
    out = []
    for i in range(n + 1):
        t = i / n
        a = (1 - t) ** 3
        b = 3 * (1 - t) ** 2 * t
        c = 3 * (1 - t) * t * t
        d = t ** 3
        out.append(tuple(a * p0[k] + b * p1[k] + c * p2[k] + d * p3[k] for k in range(3)))
    return out


def spiral(center, r0, r1, turns, n, plane="XY", z=0.0, start=0.0, direction=1):
    """평면 나선(가드 끝 말림 · 소라 껍데기)"""
    out = []
    for i in range(n + 1):
        u = i / n
        a = start + direction * 2 * math.pi * turns * u
        r = r0 + (r1 - r0) * u
        x, y = math.cos(a) * r, math.sin(a) * r
        if plane == "XY":
            out.append((center[0] + x, center[1] + y, center[2] + z * u))
        elif plane == "XZ":
            out.append((center[0] + x, center[1] + z * u, center[2] + y))
        else:
            out.append((center[0] + z * u, center[1] + x, center[2] + y))
    return out


def crystal(h, r, sides=5, tip_h=0.35, base_h=0.15, center=(0, 0, 0), m=None):
    """깎은 결정(위 뾰족 · 아래 짧게 뾰족) - 태초 결정 · 수정 등껍질 · 흑금 조각"""
    sec = circle2d(r, sides)
    rings = [[(x, (-h / 2) + base_h, y) for x, y in sec], [(x * 0.92, h / 2 - tip_h, y * 0.92) for x, y in sec]]
    g = loft(rings, tip0=(0, -h / 2, 0), tip1=(0, h / 2, 0))
    return xform(g, m=m, t=center)


def shard(size, seed=0, center=(0, 0, 0), m=None):
    """불규칙 조각(사면체 두 개 붙인 쐐기) - 초월 떠 있는 흑금 조각"""
    s = size
    j = 0.25 * math.sin(seed * 12.9898) + 0.1
    v = [(0, s * 1.2, 0), (s * 0.5, 0, s * (0.2 + j)), (-s * 0.45, 0, s * 0.3), (0.05 * s, 0, -s * 0.5), (0, -s * 0.8, 0)]
    f = [(0, 1, 3), (0, 3, 2), (0, 2, 1), (4, 3, 1), (4, 2, 3), (4, 1, 2)]
    return xform((v, f), m=m, t=center)


# ── 오브젝트 · 재질 ──
def srgb_to_linear(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def material(name, rgb, neon=False):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    lin = [srgb_to_linear(c) for c in rgb]
    mat.diffuse_color = (lin[0], lin[1], lin[2], 1.0)
    mat.roughness = 1.0
    mat.metallic = 0.0
    mat.specular_intensity = 0.0
    mat["PaletteRGB"] = "#%02X%02X%02X" % tuple(rgb)  # 문자열(FBX는 정수 목록 속성을 float64 단정에서 거부 - A2-S2)
    mat["Neon"] = bool(neon)
    return mat


def outline_material():
    return material("OUTLINE_HULL", OUTLINE)


def new_collection(name):
    col = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(col)
    return col


def make_obj(name, geo, rgb, col, neon=False, origin=(0, 0, 0), bevel=0.0, bevel_angle=35.0, smooth=False, mat_name=None):
    """geo = Roblox 공간 점 · 면(월드 좌표). origin = 관절(Roblox 월드) - 오브젝트 원점이 여기 오고 점은 원점 기준으로 옮긴다.
    bevel > 0 = 각진 모서리(각도 ≥ bevel_angle)만 작게 모따기(빛 맺힘)."""
    verts, faces = geo
    o = Vector(origin)
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(C @ (Vector(v) - o)) for v in verts], [], faces)
    mesh.validate()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if bevel > 0:
        edges = [e for e in bm.edges if e.is_manifold and len(e.link_faces) == 2 and e.calc_face_angle(0) >= math.radians(bevel_angle)]
        if edges:
            bmesh.ops.bevel(bm, geom=edges, offset=bevel, segments=1, affect="EDGES", profile=0.5, clamp_overlap=True)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    for p in mesh.polygons:
        p.use_smooth = smooth
    obj = bpy.data.objects.new(name, mesh)
    obj.location = tuple(C @ o)
    col.objects.link(obj)
    obj.data.materials.append(material(mat_name or ("%s_%s" % (col.name, name)), rgb, neon))
    obj["TriCount"] = tri_count(obj)
    obj["RigPart"] = name.split(".")[0]
    obj["Neon"] = bool(neon)
    return obj


def tri_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def add_hull(obj, thickness=0.035, export=False, col=None):
    """외곽선 = 뒤집은 껍데기. export=False → 렌더 전용 모디파이어(FBX에 안 나감). True → 실제 메시 복제(보스 굵은 외곽선 · 이름 <파트>_Outline)"""
    if export:
        me = obj.data.copy()
        bm = bmesh.new()
        bm.from_mesh(me)
        for v in bm.verts:
            v.co += v.normal * thickness
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
        me.materials.clear()
        me.materials.append(outline_material())
        h = bpy.data.objects.new(obj.name.split(".")[0] + "_Outline", me)
        h.location = obj.location
        (col or obj.users_collection[0]).objects.link(h)
        h["TriCount"] = tri_count(h)
        h["RigPart"] = obj["RigPart"]
        h["OutlineHull"] = True
        return h
    if len(obj.data.materials) < 2:
        obj.data.materials.append(outline_material())
    m = obj.modifiers.new("Hull", "SOLIDIFY")
    m.thickness = thickness
    m.offset = 1.0
    m.use_flip_normals = True
    m.use_rim = False
    m.use_even_offset = True
    m.material_offset = 1
    return m


def remove_hulls(objs):
    for o in objs:
        for m in list(o.modifiers):
            if m.name == "Hull":
                o.modifiers.remove(m)


# ── 렌더 ──
def _scene_common(res=(900, 900)):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.render.film_transparent = False
    scene.display_settings.display_device = "sRGB"
    scene.view_settings.view_transform = "Standard"
    sh = scene.display.shading
    sh.background_type = "VIEWPORT"
    sh.show_cavity = False
    sh.show_specular_highlight = False
    sh.show_shadows = False
    sh.show_object_outline = False
    sh.show_backface_culling = False
    return scene, sh


def setup_render(kind, res=(900, 900)):
    """kind: game = 단색 조명(평면) + 외곽선 껍데기 / form = 기본 스튜디오 조명(형태 확인) / sil = 검정 실루엣"""
    scene, sh = _scene_common(res)
    if kind == "game":
        sh.light = "FLAT"
        sh.color_type = "MATERIAL"
        sh.show_backface_culling = True  # 껍데기 안쪽 면만 보이게
        sh.show_cavity = True
        sh.cavity_type = "WORLD"
        sh.cavity_ridge_factor = 0.0
        sh.cavity_valley_factor = 1.0
        sh.background_color = (0.80, 0.86, 0.93)
    elif kind == "form":
        sh.light = "STUDIO"
        sh.studio_light = "Default"
        sh.color_type = "MATERIAL"
        sh.show_shadows = False
        sh.background_color = (0.62, 0.64, 0.68)
    else:
        sh.light = "FLAT"
        sh.color_type = "SINGLE"
        sh.single_color = (0.0, 0.0, 0.0)
        sh.background_color = (1.0, 1.0, 1.0)
    return scene


def bbox_world(objs):
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    bpy.context.view_layer.update()
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector((min(lo[i], w[i]) for i in range(3)))
            hi = Vector((max(hi[i], w[i]) for i in range(3)))
    return lo, hi


_CAM = {}


def camera():
    scene = bpy.context.scene
    if "cam" not in _CAM or _CAM["cam"].name not in bpy.data.objects:
        cd = bpy.data.cameras.new("ArtCam")
        cd.type = "ORTHO"
        cam = bpy.data.objects.new("ArtCam", cd)
        scene.collection.objects.link(cam)
        _CAM["cam"] = cam
    scene.camera = _CAM["cam"]
    return _CAM["cam"]


def stand(objs, name="Stand"):
    """렌더용 받침 빈 오브젝트 - 부모로 묶어 돌린다(오브젝트 원점 · 회전은 그대로 = 내보내기 전에 부모를 푼다)"""
    e = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(e)
    for o in objs:
        o.parent = e
    return e


def unstand(objs, e):
    for o in objs:
        o.parent = None  # 로컬 변환(= 원래 자리)으로 돌아간다
    bpy.data.objects.remove(e)


def aim(cam, target, yaw_deg, pitch_deg, dist=40.0):
    """target(Blender 월드)을 yaw(Z축 · 0 = 앞 +Y에서 봄) · pitch(위에서 내려다봄)로 본다"""
    y, p = math.radians(yaw_deg), math.radians(pitch_deg)
    d = Vector((math.sin(y) * math.cos(p), math.cos(y) * math.cos(p), math.sin(p)))
    cam.location = Vector(target) + d * dist
    f = -d
    right = f.cross(Vector((0, 0, 1))).normalized()
    up = right.cross(f).normalized()
    m = Matrix((right, up, -f)).transposed()  # 카메라 로컬 X = 오른쪽 · Y = 위 · −Z = 앞(롤 없음)
    cam.rotation_euler = m.to_euler()


VIEWS = {"front": (0, 0), "side": (90, 0), "34": (45, 20)}


def render_views(objs, out_prefix, views=("front", "side", "34"), kinds=("game", "form"), sil=True, hull=0.035, res=(900, 900), yaw_offset=0.0, pad=1.15):
    """오브젝트 묶음을 여러 각도 × 렌더 종류로 찍는다. 반환 = {"game_front": 경로, ...}.
    앞 = Roblox −Z(= Blender +Y)를 카메라가 보도록 yaw 0. 무기처럼 보여 줄 면이 다르면 yaw_offset."""
    out = {}
    lo, hi = bbox_world(objs)
    center = (lo + hi) / 2
    size = max((hi - lo).x, (hi - lo).y, (hi - lo).z)
    cam = camera()
    cam.data.ortho_scale = size * pad
    cam.data.clip_end = 500
    hidden = [o for o in bpy.context.scene.objects if o.type == "MESH" and o not in objs]
    for o in hidden:
        o.hide_render = True
    kinds = list(kinds) + (["sil"] if sil else [])
    for kind in kinds:
        setup_render(kind, res)
        if kind == "game" and hull:
            for o in objs:
                add_hull(o, hull)
        vlist = ("front",) if kind == "sil" else views
        for v in vlist:
            yaw, pitch = VIEWS[v]
            aim(cam, center, yaw + yaw_offset, pitch)
            path = "%s_%s_%s.png" % (out_prefix, kind, v)
            bpy.context.scene.render.filepath = path
            bpy.ops.render.render(write_still=True)
            out["%s_%s" % (kind, v)] = path
        if kind == "game" and hull:
            remove_hulls(objs)
    for o in hidden:
        o.hide_render = False
    return out


# ── 내보내기 · 메타 ──
def export_fbx(path, objs):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"}, global_scale=1.0, apply_unit_scale=True,
                             apply_scale_options="FBX_SCALE_NONE", axis_forward="-Z", axis_up="Y", bake_space_transform=True,
                             use_mesh_modifiers=False, mesh_smooth_type="FACE", use_custom_props=True, add_leaf_bones=False,
                             bake_anim=False, embed_textures=False)


def roblox_origin(obj):
    return [round(x, 4) for x in (CT @ obj.location)]


def meta_of(objs, budget, extra=None):
    # 외곽선 껍데기(<파트>_Outline)는 RigPart가 원래 파트와 같아 키가 겹친다 → 껍데기는 자기 이름으로(합쳐지면 삼각형 · 파트 수가 빠졌다)
    parts = {(o.name.split(".")[0] if o.get("OutlineHull") else o["RigPart"]): {"tris": tri_count(o), "origin": roblox_origin(o), "neon": bool(o.get("Neon", False)),
                            "color": o.data.materials[0].get("PaletteRGB") if o.data.materials else None} for o in objs}
    total = sum(p["tris"] for p in parts.values())
    d = {"parts": parts, "partCount": len(parts), "totalTris": total, "triBudget": budget, "budgetUse": round(total / budget, 3)}
    if extra:
        d.update(extra)
    return d


def write_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _CAM.clear()
