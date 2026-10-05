# -*- coding: utf-8 -*-
# BOSS-NIGHT-1 보스 소품 KIT(Blender bpy · 패키지 설치 없음): Meshy GLB 한 덩어리(투사체 · 무기 · 변신 부품) → 감량 메시 1개 FBX + 구운 색 아틀라스 + 메타.
#   boss_kit.py(리그 부위 자르기)와 달리 자르지 않는다 - 통째 한 MeshPart. 감량 · 굽기 함수는 boss_kit 것을 그대로 쓴다.
#   1 가져오기(--yaw 도) · 2 정리(--cut 축,값,남길쪽 = 평면 자르기 - 폭풍 건틀릿 팔꿈치 관 · --islands r = 가장 큰 조각 면 수 × r 미만 조각 삭제 - 날개 불꽃 부스러기 ·
#      --mirror = X 반전(왼쪽 사본)) · 3 크기(--length = 가장 긴 축 길이 · 원점 = 경계 상자 가운데) · 4 감량(--tris) · 5 새 UV + 원본 고해상 색 굽기(--bake 크기)
#   6 내보내기 art/<--out>/<--name>.fbx · _atlas1.png · .meta.json · .blend(원본 텍스처 미포함) · 렌더(--render 폴더).
# 좌표: 결과 메시 축 = 원본 GLB 축(Blender Z 위 → FBX Y 위). 게임에서 쓰는 쪽(손에 쥐는 축 · 나는 방향)은 클라 코드가 메타 size로 정한다.
# 실행: bash bl.sh prop_kit.py --glb <GLB> --name guardian_banana_m --out fx --tris 3000 --length 1 --bake 512 [--render 폴더]
import bpy
import bmesh
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import artlib as A  # noqa: E402
import boss_kit as K  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

ART = os.path.normpath(os.path.join(HERE, "..", "..", "art"))


def parse():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    o = {"glb": None, "name": None, "out": "fx", "tris": 3000, "length": 1.0, "bake": 512, "yaw": 0.0, "cut": [], "islands": 0.0, "mirror": False, "render": None,
         "extrusion": 0.02, "distance": 0.06}
    i = 0
    while i < len(a):
        k, v = a[i], a[i + 1] if i + 1 < len(a) else None
        if k == "--mirror":
            o["mirror"] = True
            i += 1
            continue
        if k == "--cut":
            ax, val, keep = v.split(",")
            o["cut"].append((ax, float(val), keep))
        elif k in ("--tris", "--bake"):
            o[k[2:]] = int(v)
        elif k in ("--length", "--yaw", "--islands", "--extrusion", "--distance"):
            o[k[2:]] = float(v)
        else:
            o[k[2:]] = v
        i += 2
    return o


def bounds(obj):
    vs = [v.co for v in obj.data.vertices]
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    return lo, hi


def cut(obj, ax, val, keep, lo, hi):
    """정규 좌표(0 = 경계 최소 · 1 = 최대) 평면으로 자르고 한쪽만 남긴다 + 자른 면 막기"""
    i = "xyz".index(ax)
    plane = lo[i] + (hi[i] - lo[i]) * val
    no = Vector((0, 0, 0))
    no[i] = 1.0
    co = Vector((0, 0, 0))
    co[i] = plane
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=no, clear_inner=(keep == ">"), clear_outer=(keep == "<"))
    edges = [e for e in bm.edges if e.is_boundary]
    if edges:
        bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    bm.to_mesh(obj.data)
    bm.free()


def drop_islands(obj, ratio):
    isl = K.islands_of(obj.data)
    count = {}
    for f in isl:
        count[f] = count.get(f, 0) + 1
    big = max(count.values())
    kill = {k for k, n in count.items() if n < big * ratio}
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    dead = [bm.faces[fi] for fi, k in enumerate(isl) if k in kill]
    bmesh.ops.delete(bm, geom=dead, context="FACES")
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()
    return len(kill), len(dead)


def main():
    o = parse()
    A.reset()
    src = K.import_glb(o["glb"], o["yaw"])
    src_tris = K.tris(src)
    lo, hi = bounds(src)
    for ax, val, keep in o["cut"]:
        cut(src, ax, val, keep, lo, hi)
    dropped = (0, 0)
    if o["islands"] > 0:
        dropped = drop_islands(src, o["islands"])
    if o["mirror"]:
        src.data.transform(Matrix.Scale(-1, 4, Vector((1, 0, 0))))
        src.data.flip_normals()
    # 크기 · 원점: 가장 긴 축 = length · 경계 상자 가운데 = 0
    lo, hi = bounds(src)
    s = o["length"] / max(hi - lo)
    mid = (lo + hi) / 2
    src.data.transform(Matrix.Diagonal((s, s, s, 1)) @ Matrix.Translation(-mid))
    hiobj = src.copy()
    hiobj.data = src.data.copy()
    bpy.context.scene.collection.objects.link(hiobj)
    hiobj.name = "KIT_HI"
    low = src
    low.name = o["name"]
    K.decimate(low, o["tris"])
    out = os.path.join(ART, o["out"])
    os.makedirs(out, exist_ok=True)
    fn = "%s_atlas1.png" % o["name"]
    K.bake_atlas([low], hiobj, {"size": o["bake"], "extrusion": o["extrusion"] * o["length"], "distance": o["distance"] * o["length"]}, os.path.join(out, fn))
    bpy.data.objects.remove(hiobj, do_unlink=True)
    low["RigPart"] = o["name"]
    low["TriCount"] = K.tris(low)
    lo, hi = bounds(low)
    size = [round(x, 4) for x in (A.CT @ (hi - lo))]
    size = [abs(x) for x in size]
    A.export_fbx(os.path.join(out, "%s.fbx" % o["name"]), [low])
    meta = A.meta_of([low], o["tris"], {"version": "PROP1", "metaName": o["name"], "size": size, "texture": {"atlases": [fn], "parts": [o["name"]]},
                                       "kit": {"source": os.path.basename(o["glb"]), "sourceTris": src_tris, "cut": o["cut"], "islandsDropped": dropped[0], "facesDropped": dropped[1], "mirror": o["mirror"]},
                                       "space": "원점 = 경계 상자 가운데 · 가장 긴 축 = %.3f · 축 = 원본 GLB(Roblox Y 위)" % o["length"]})
    A.write_json(os.path.join(out, "%s.meta.json" % o["name"]), meta)
    for im in list(bpy.data.images):
        if im.name != "KIT_BAKE":
            bpy.data.images.remove(im)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "%s.blend" % o["name"]))
    print("[PROP] %s: 원본 삼각형 %d → %d · 조각 삭제 %d(면 %d) · 자르기 %d · 반전 %s · 크기(Roblox) %s · 아틀라스 %s(%d)" % (
        o["name"], src_tris, K.tris(low), dropped[0], dropped[1], len(o["cut"]), o["mirror"], size, fn, o["bake"]))
    if o["render"]:
        orig = A.setup_render

        def tex_setup(kind, res=(700, 700)):
            sc = orig(kind, res)
            if kind == "game":
                sc.display.shading.color_type = "TEXTURE"
            return sc
        A.setup_render = tex_setup
        A.render_views([low], os.path.join(o["render"], o["name"]), kinds=("game",), sil=False, hull=0.0, res=(700, 700))
        A.setup_render = orig


if __name__ == "__main__":
    main()
