"""GUARDIAN-V3 임시 자수정 바나나(교체 슬롯 GuardianBanana - 나중에 Meshy 메시로 바꾼다).

사용: blender --background --python roblox/tools/blender/guardian_banana.py
결과: roblox/art/fx/guardian_banana.blend · .fbx(원점 = 가운데 · 길이 약 5.5 · 6각 단면 각진 면 = 수정 느낌 · 삼각형 약 250)
색은 게임이 입힌다(노랑 Neon + 보라 빛 · 꼬리 트레일 - client/BossBananaView · BossFxData.guardianBanana).
"""
import math
import os

import bpy
import bmesh
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "fx")
SIDES = 6  # 단면 6각(각진 수정 면)
RINGS = 11  # 길이 방향 마디
LENGTH = 5.5
BEND = 0.9  # 휨(라디안 - 활 모양 전체 각)
RADIUS = 0.55

bpy.ops.wm.read_factory_settings(use_empty=True)
mesh = bpy.data.meshes.new("GuardianBanana")
obj = bpy.data.objects.new("GuardianBanana", mesh)
bpy.context.scene.collection.objects.link(obj)

bm = bmesh.new()
R = LENGTH / BEND  # 휨 반지름
rings = []
for i in range(RINGS):
    u = i / (RINGS - 1)
    a = -BEND / 2 + BEND * u
    center = Vector((math.sin(a) * R, (math.cos(a) - 1) * R + R * (1 - math.cos(BEND / 2)), 0))
    tangent = Vector((math.cos(a), -math.sin(a), 0))
    normal = Vector((math.sin(a), math.cos(a), 0))
    binormal = Vector((0, 0, 1))
    # 두께: 양 끝으로 가늘어짐(끝 = 꼭지 · 반대 끝 = 뾰족) · 가운데 통통
    taper = math.sin(math.pi * u) ** 0.6
    r = RADIUS * (0.12 + 0.88 * taper)
    if i == RINGS - 1:
        r = RADIUS * 0.22  # 꼭지(줄기)
    ring = []
    for k in range(SIDES):
        t = k / SIDES * 2 * math.pi + (math.pi / SIDES if i % 2 else 0) * 0.35  # 마디마다 살짝 비틀어 면이 깎인 수정처럼
        p = center + normal * math.cos(t) * r + binormal * math.sin(t) * r
        ring.append(bm.verts.new(p))
    rings.append(ring)
for i in range(RINGS - 1):
    a, b = rings[i], rings[i + 1]
    for k in range(SIDES):
        bm.faces.new((a[k], a[(k + 1) % SIDES], b[(k + 1) % SIDES], b[k]))
# 끝 막기: 뾰족한 끝 = 점 하나로 · 꼭지 = 평면
tip = bm.verts.new(rings[0][0].co.copy())
tip.co = sum((v.co for v in rings[0]), Vector()) / SIDES + Vector((-0.25, 0.05, 0))
for k in range(SIDES):
    bm.faces.new((rings[0][(k + 1) % SIDES], rings[0][k], tip))
bm.faces.new(rings[-1])
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bmesh.ops.triangulate(bm, faces=bm.faces)
bm.to_mesh(mesh)
bm.free()
for poly in mesh.polygons:
    poly.use_smooth = False  # 각진 면(flat) = 수정

# 원점 = 경계 상자 가운데
bpy.context.view_layer.objects.active = obj
obj.select_set(True)
bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
obj.location = (0, 0, 0)

os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "guardian_banana.blend"))
bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, "guardian_banana.fbx"), use_selection=True, apply_unit_scale=True, object_types={"MESH"}, mesh_smooth_type="FACE")
print("[banana] tris", len(mesh.polygons), "dims", tuple(round(x, 2) for x in obj.dimensions))
