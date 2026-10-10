# -*- coding: utf-8 -*-
# ART-PILOT-1 B2: Meshy 통메시(텍스처 1장) → 지금 몬스터 리그 부위 이름으로 자르기 → 부위 단색 · 삼각형 예산 → FBX + meta.json(시범 - 게임 데이터 아님).
#   부위 정하기 = 면 가운데 위치(머리/목 · 꼬리 · 다리 · 등 높이) + 텍스처 색(이끼 초록 · 엄니 흰색 · 눈 검정). 색 = spec 팔레트(텍스처 0장 - MeshImportCheckData.forbiddenChildren).
#   좌표 = artlib 규칙(Roblox +Y 위 · −Z 앞 · stud → Blender (X, −Z, Y)). Meshy 입력은 앞 = Blender −Y라 Z 180° 돌린다.
# 실행: bash bl.sh art_pilot_cut.py <입력.glb> <출력 폴더> [--height 2.65] [--budget 1500]
import bpy
import bmesh
import json
import os
import sys
import time

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import artlib as A  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = argv[0], argv[1]
HEIGHT = float(argv[argv.index("--height") + 1]) if "--height" in argv else 2.65
BUDGET = int(argv[argv.index("--budget") + 1]) if "--budget" in argv else 1500
FOOT_Y = -1.5  # MonsterRigSpec: 발바닥 = y −1.5

# rock_boar spec 기본 색(claude-design-handoff/50_art-pilot/v1/rock_boar/rock_boar_spec.png)
PAL = {"Body": "8C8A84", "Head": "A5A29B", "Shell": "9A968C", "Moss": "5A9646", "Leg": "5E5C58",
       "Eyes": "2A2230", "Tusk": "F2E8D0", "Tail": "8C8A84"}

t0 = time.time()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
src = [o for o in bpy.data.objects if o.type == "MESH"][0]
img = [i for i in bpy.data.images if i.name == "texture_0"][0]
W, H = img.size
px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)

# 1) Roblox 공간으로: 앞 −Y → +Y(Z 180°) · 키 HEIGHT · 발바닥 FOOT_Y · 앞뒤 가운데 0
bpy.context.view_layer.objects.active = src
src.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
me = src.data
me.transform(Matrix.Rotation(np.pi, 4, "Z"))
co = np.array([v.co[:] for v in me.vertices])
s = HEIGHT / (co[:, 2].max() - co[:, 2].min())
me.transform(Matrix.Scale(s, 4))
co = np.array([v.co[:] for v in me.vertices])
off = Vector((-(co[:, 0].max() + co[:, 0].min()) / 2, -(co[:, 1].max() + co[:, 1].min()) / 2, FOOT_Y - co[:, 2].min()))
me.transform(Matrix.Translation(off))
me.update()


def rbx(v):  # Blender → Roblox
    return A.CT @ Vector(v)


# 2) 면마다 위치 · 텍스처 색
bm = bmesh.new()
bm.from_mesh(me)
uvl = bm.loops.layers.uv.active
bm.faces.ensure_lookup_table()
F = len(bm.faces)
cen = np.zeros((F, 3))
nrm = np.zeros((F, 3))
col = np.zeros((F, 3))
for f in bm.faces:
    c = rbx(f.calc_center_median())
    cen[f.index] = c[:]
    nrm[f.index] = rbx(f.normal)[:]
    acc = np.zeros(3)
    for lp in f.loops:  # 꼭짓점 UV 3개 + 가운데 평균
        u, v = lp[uvl].uv
        acc += px[min(H - 1, int(v * H)), min(W - 1, int(u * W)), :3]
    col[f.index] = acc / len(f.loops)
srgb = np.where(col <= 0.0031308, col * 12.92, 1.055 * np.power(np.clip(col, 0, 1), 1 / 2.4) - 0.055) * 255
r, g, b = srgb[:, 0], srgb[:, 1], srgb[:, 2]
luma = 0.299 * r + 0.587 * g + 0.114 * b

# 3) 경계: 앞뒤 단면 폭으로 목 · 꼬리 자리(다리 위 몸 높이만)
X, Y, Z = cen[:, 0], cen[:, 1], cen[:, 2]
ymin, ymax = Y.min(), Y.max()
leg_top = ymin + 0.30 * (ymax - ymin)
zs = np.linspace(Z.min(), Z.max(), 41)
widths = []
for i in range(40):
    m = (Z >= zs[i]) & (Z < zs[i + 1]) & (Y > leg_top)
    widths.append(np.ptp(X[m]) if m.sum() > 3 else 0)
widths = np.array(widths)
body_w = np.percentile(widths[widths > 0], 75)
wide = np.where(widths >= 0.85 * body_w)[0]
z_neck = zs[wide.min()]  # 앞(−Z)에서 처음 몸 폭이 되는 곳
z_rear = zs[wide.max() + 1]  # 뒤에서 처음
body_top = np.percentile(Y[(Z > z_neck) & (Z < z_rear)], 80)
z_mid = (z_neck + z_rear) / 2
belly = (np.abs(Z - z_mid) < 0.3) & (np.abs(X) < 0.2)
belly_y = np.percentile(Y[belly], 3) if belly.sum() > 3 else leg_top  # 배 밑면 = 다리 사이 가운데에서 가장 낮은 면
leg_cut = min(leg_top, belly_y - 0.03)

part = np.empty(F, dtype=object)
for i in range(F):
    x, y, z = cen[i]
    if z < z_neck and y > leg_top - 0.15:
        if luma[i] < 70:
            part[i] = "Eyes"
        elif luma[i] > 185 and r[i] - b[i] > 15 and abs(x) > 0.25:  # 엄니 = 크림(빨강 > 파랑) · 회색 볼은 r ≈ b
            part[i] = "Tusk_L" if x < 0 else "Tusk_R"
        else:
            part[i] = "Head"
    elif z > z_rear and y > leg_top:
        part[i] = "Tail"
    elif y < leg_cut and not (nrm[i][1] < -0.7 and y > FOOT_Y + 0.2):  # 배 밑면(아래 향함 · 발바닥 위) = 몸통
        part[i] = ("Leg_F" if z < z_mid else "Leg_B") + ("L" if x < 0 else "R")
    elif g[i] > r[i] + 12 and g[i] > b[i] + 12:
        part[i] = "Moss"
    elif y > body_top:
        part[i] = "Shell"
    else:
        part[i] = "Body"

# 4) 부위 오브젝트로 나누기 · 단색 · 원점 = 관절 자리 · 예산 비례 감량
coll = A.new_collection("ROCK_BOAR_B2")
names = sorted(set(part))
src_tris = F
objs = []
for n in names:
    keep = set(np.where(part == n)[0].tolist())
    b2 = bm.copy()
    b2.faces.ensure_lookup_table()
    bmesh.ops.delete(b2, geom=[f for f in b2.faces if f.index not in keep], context="FACES")
    m2 = bpy.data.meshes.new(n)
    b2.to_mesh(m2)
    b2.free()
    while m2.uv_layers:
        m2.uv_layers.remove(m2.uv_layers[0])
    o = bpy.data.objects.new(n, m2)
    coll.objects.link(o)
    pc = np.array([rbx(v.co)[:] for v in m2.vertices])
    lo, hi = pc.min(0), pc.max(0)
    if n == "Body":
        org = (0, -0.1, 0)
    elif n == "Head":
        org = ((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, z_neck)  # 목 = 몸 앞면
    elif n.startswith("Leg_"):
        org = ((lo[0] + hi[0]) / 2, hi[1], (lo[2] + hi[2]) / 2)  # 다리 윗면 가운데(엉덩이 · 어깨)
    elif n == "Tail":
        org = ((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, z_rear)
    else:
        org = tuple((lo + hi) / 2)
    ob = A.C @ Vector(org)
    m2.transform(Matrix.Translation(-ob))
    o.location = ob
    key = "Leg" if n.startswith("Leg_") else ("Tusk" if n.startswith("Tusk") else n)
    rgb = tuple(int(PAL[key][k:k + 2], 16) for k in (0, 2, 4))
    m2.materials.append(A.material("B2_" + n, rgb))
    t_before = A.tri_count(o)
    ratio = min(1.0, BUDGET / src_tris)
    if ratio < 1.0 and t_before > 24:
        mod = o.modifiers.new("dec", "DECIMATE")
        mod.ratio = ratio
        bpy.context.view_layer.objects.active = o
        o.select_set(True)
        bpy.ops.object.modifier_apply(modifier="dec")
        o.select_set(False)
    o["TriCount"] = A.tri_count(o)
    o["RigPart"] = n
    o["Neon"] = False
    objs.append((o, t_before, org))
bm.free()
bpy.data.objects.remove(src)

# 5) 기준 루트(원점 작은 상자 - MeshImportCheckData.referenceRootName)
root = A.make_obj("HumanoidRootPart", A.box(0.2, 0.2, 0.2), (255, 255, 255), coll)

os.makedirs(OUT, exist_ok=True)
A.export_fbx(os.path.join(OUT, "rock_boar_b2.fbx"), [o for o, _, _ in objs] + [root])
for im in list(bpy.data.images):  # Meshy 원본 텍스처가 .blend에 싸여 들어가지 않게(GUARDIAN-V2 교훈)
    bpy.data.images.remove(im)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "rock_boar_b2.blend"))
meta = {"source": os.path.basename(SRC), "srcTris": src_tris, "scale": round(s, 4), "budget": BUDGET,
        "zNeck": round(float(z_neck), 3), "zRear": round(float(z_rear), 3), "legTop": round(float(leg_top), 3), "legCut": round(float(leg_cut), 3), "bodyTop": round(float(body_top), 3),
        "seconds": round(time.time() - t0, 1),
        "parts": {o.name: {"tris": o["TriCount"], "srcTris": tb, "origin": [round(float(c), 3) for c in org], "center": A.roblox_center(o),
                           "color": o.data.materials[0]["PaletteRGB"]} for o, tb, org in objs}}
meta["totalTris"] = sum(p["tris"] for p in meta["parts"].values())
with open(os.path.join(OUT, "rock_boar_b2.meta.json"), "w", encoding="utf-8") as f:
    json.dump(meta, f, ensure_ascii=False, indent=1)
print("B2META", json.dumps(meta, ensure_ascii=False))
