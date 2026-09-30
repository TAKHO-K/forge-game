# -*- coding: utf-8 -*-
# QUEUE-ALL3 Q7 둥근 모서리 블록(Blender bpy): 기본 도형(Block · Wedge) 겉모습 교체용 베벨 메시.
#   MeshPart는 축마다 따로 늘어나므로 비율 등급(class)을 여러 개 둔다 - 원래 파트 크기에 가장 가까운 비율 등급을 골라 Size를 맞추면
#   베벨이 짧은 변의 약 8 ~ 12%로 남는다. 등급마다 가장 짧은 변 = 1 stud · 베벨 반지름 = 짧은 변의 10% · 2단 둥근 베벨 · ≤ 200 삼각형.
#   쐐기 = Roblox WedgePart 모양(직각 삼각 기둥): 바닥 전체 · 높은 모서리는 뒤(+Z) 위 · 경사면이 앞(−Z)과 위를 본다.
#   축 = Roblox(+Y 위 · −Z 앞) · 1 Blender 단위 = 1 stud · 원점 = 경계 상자 가운데(= Roblox 파트 CFrame 자리) · 평면 음영(카툰 면 음영).
#   출력: roblox/art/props/bevel/bevel_<등급>.fbx · bevel.meta.json · --render <폴더> = 등급마다 512px 미리보기
# 실행: bash bl.sh make_bevel_blocks.py [--render 폴더]
import bmesh
import bpy
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import artlib as A  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "art", "props", "bevel"))
TRI_BUDGET = 200
BEVEL_FRAC = 0.10
SEGMENTS = 2
STONE = (168, 162, 154)  # 미리보기색(tier1 main) - 게임은 원래 파트 색을 그대로 옮긴다

# 등급 → (모양, (x, y, z)) - 가장 짧은 변 = 1
CLASSES = {
    "cube": ("box", (1, 1, 1)),
    "slab": ("box", (4, 1, 4)),
    "plate": ("box", (12, 1, 12)),
    "pillar": ("box", (1, 4, 1)),
    "beam": ("box", (4, 1, 1)),
    "wall": ("box", (4, 4, 1)),
    "wedge": ("wedge", (1, 1, 1)),
    "wedge_ramp": ("wedge", (2, 1, 3)),
}


def base_geo(shape, size):
    x, y, z = size[0] / 2, size[1] / 2, size[2] / 2
    if shape == "box":
        v = [(-x, -y, -z), (x, -y, -z), (x, y, -z), (-x, y, -z), (-x, -y, z), (x, -y, z), (x, y, z), (-x, y, z)]
        f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (3, 7, 6, 2), (0, 4, 7, 3), (1, 2, 6, 5)]
    else:  # 쐐기: 앞 아래 모서리(z = −) · 뒤 위 모서리(z = +)
        v = [(-x, -y, -z), (x, -y, -z), (x, -y, z), (-x, -y, z), (-x, y, z), (x, y, z)]
        f = [(0, 1, 2, 3), (3, 2, 5, 4), (0, 4, 5, 1), (0, 3, 4), (1, 5, 2)]
    return v, f


def bevelled(shape, size):
    """Roblox 공간에서 베벨까지 마친 점 · 면(make_obj가 Blender 축으로 바꾼다)"""
    r = BEVEL_FRAC * min(size)
    v, f = base_geo(shape, size)
    bm = bmesh.new()
    bv = [bm.verts.new(p) for p in v]
    for face in f:
        bm.faces.new([bv[i] for i in face])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.bevel(bm, geom=list(bm.edges) + list(bm.verts), offset=r, offset_type="OFFSET", segments=SEGMENTS, profile=0.5,
                    affect="EDGES", clamp_overlap=True)
    # 쐐기의 예각 모서리는 둥글리면 경계 상자가 줄어든다(1:1:1 → 0.95) → 축마다 늘려 경계 = 원래 크기 · 가운데 = 원점으로 맞춘다
    lo = [min(p.co[i] for p in bm.verts) for i in range(3)]
    hi = [max(p.co[i] for p in bm.verts) for i in range(3)]
    verts = [tuple((p.co[i] - (lo[i] + hi[i]) / 2) * size[i] / (hi[i] - lo[i]) for i in range(3)) for p in bm.verts]
    idx = {p: i for i, p in enumerate(bm.verts)}
    faces = [tuple(idx[p] for p in face.verts) for face in bm.faces]
    bm.free()
    return (verts, faces), r


def build():
    A.reset()
    col = A.new_collection("Bevel")
    out, meta = {}, {}
    for cls, (shape, size) in CLASSES.items():
        name = "bevel_" + cls
        geo, r = bevelled(shape, size)
        o = A.make_obj("Block", geo, STONE, col, smooth=False, mat_name=name + "_Block")
        o.name = "Block"
        A.export_fbx(os.path.join(OUT, name + ".fbx"), [o])
        lo, hi = A.bbox_world([o])
        lo_r, hi_r = A.CT @ lo, A.CT @ hi
        bbox = [round(abs(hi_r[i] - lo_r[i]), 4) for i in range(3)]
        tris = A.tri_count(o)
        meta[name] = {"file": name + ".fbx", "shape": "Wedge" if shape == "wedge" else "Block", "ratio": "%g:%g:%g" % size,
                      "sizeStuds": bbox, "tris": tris, "triBudget": TRI_BUDGET, "bevelFraction": BEVEL_FRAC, "bevelStuds": round(r, 4),
                      "bevelSegments": SEGMENTS, "origin": "경계 상자 가운데", "part": "Block"}
        o.name = name
        out[name] = o
        flag = "" if tris <= TRI_BUDGET else "  <-- 예산 초과"
        print("[make_bevel_blocks] %-18s 비율 %-8s 삼각형 %3d · 경계 %s%s" % (name, meta[name]["ratio"], tris, bbox, flag))
    meta = {"_summary": {"units": "1 Blender 단위 = 1 stud · FBX 축 −Z 앞 / Y 위 · FBX_SCALE_NONE(make_trees.py와 같음) · Open Cloud LoadAsset은 cm(×100) · Y180으로 온다 → MeshPart.Size = 원래 파트 Size로 덮어 쓰면 단위와 무관",
                         "wedge": "Roblox WedgePart와 같은 방향: 경사면이 −Z(앞)와 +Y를 본다 · 높은 모서리 = +Z 위",
                         "pick": "원래 파트 Size를 가장 짧은 변으로 나눈 비율과 ratio의 로그 거리가 가장 가까운 등급(같은 모양) - 축 순서가 다르면 겉모습 메시를 돌려 붙인다"},
            **meta}
    A.write_json(os.path.join(OUT, "bevel.meta.json"), meta)
    return out


def render_each(out, folder, res=512):
    os.makedirs(folder, exist_ok=True)
    cam = A.camera()
    for name, obj in out.items():
        for o in out.values():
            o.hide_render = o is not obj
        A.setup_render("form", (res, res))
        bpy.context.scene.display.shading.show_backface_culling = True
        lo, hi = A.bbox_world([obj])
        size = max((hi - lo).x, (hi - lo).y, (hi - lo).z)
        cam.data.ortho_scale = size * 1.5
        cam.data.clip_start = 0.01
        cam.data.clip_end = size * 10
        A.aim(cam, (lo + hi) / 2, 35, 25, dist=size * 3)
        bpy.context.scene.render.filepath = os.path.join(folder, name + ".png")
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = build()
    if "--render" in argv:
        render_each(out, argv[argv.index("--render") + 1])
