# -*- coding: utf-8 -*-
# BOSS-NIGHT-3 1-⑤c 수정 여왕 홀 쥔 손(사용자 10-10): Meshy 오른손(Hand_R · 정점 127)은 손가락이 홀 자루 앞면에 닿기만 하고(편 손) 엄지가 앞 아래로 뻗어 있다
#   (Blender 실측: 손목 x 1.50 → 손가락 끝 x 1.86 = 수평으로 자루(축 x 2.00 · y 0.27 · 반경 0.10) 쪽 · 엄지 끝 (1.35, −0.31, 1.49)).
#   쥔 모양 = ① 손가락: 손가락 마디(KNUCKLE_X)를 넘은 정점을 자루 축 둘레로 돌린다(마디에서 멀수록 많이 - 끝 = CURL_DEG · 수평면 · 앞(−y)을 돌아 뒤로) ·
#   ② 엄지: 엄지 정점을 자루 앞(손가락 반대쪽)으로 당긴다 · ③ 자루 안으로 들어간 정점은 표면 + 틈으로 밀어낸다.
#   홀은 Hand_R 자식(리그 고정)이라 모든 자세(바로 쥠 · 빔의 거꾸로 쥠)에서 같은 쥔 모양. UV · 정점 수 · 오브젝트 원점(관절) 그대로 → 메타 center만 다시 잼.
# 실행: bash bl.sh crystal_grip.py   (art/bosses/crystal_queen_v2m.blend를 열어 고친 뒤 .blend · .fbx · .meta.json을 다시 씀 · 두 번 돌리면 멈춤)
#       → python ../opencloud/upload.py bosses/crystal_queen_v2m.fbx(같은 assetId 새 버전) → python meta_to_luau.py crystal_queen_v2m
import bpy
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import artlib as A  # noqa: E402
from mathutils import Vector  # noqa: E402

ART = os.path.normpath(os.path.join(HERE, "..", "..", "art", "bosses"))
NAME = "crystal_queen_v2m"
GAP = 0.025  # 자루 표면 ↔ 손 틈(Blender 단위)
KNUCKLE_X = 1.64  # 이 x를 넘은 손가락 정점부터 감음(손바닥 끝)
CURL_DEG = 230  # 손가락 끝이 자루 둘레로 도는 각(앞을 돌아 뒤쪽까지)
HUG = 0.05  # 굽은 손가락 끝의 두께(자루 표면 + 틈 밖)
THUMB_Y = 0.06  # 이 y보다 앞(−y) = 엄지
THUMB_PULL = 0.85  # 엄지 끝을 자루 앞 목표점 쪽으로 당기는 몫

bpy.ops.wm.open_mainfile(filepath=os.path.join(ART, NAME + ".blend"))
hand = bpy.data.objects["Hand_R"]
sc = bpy.data.objects["Scepter"]
if hand.get("GripWrapped"):
    sys.exit("이미 감음(GripWrapped) - 두 번 감지 않는다")
mw, mwi = hand.matrix_world, hand.matrix_world.inverted()
hv = [mw @ v.co for v in hand.data.vertices]
zlo, zhi = min(v.z for v in hv), max(v.z for v in hv)
# 자루 축: 손 높이 띠 안의 홀 정점 가운데(장식 나선 포함 - 중앙값)
band = [sc.matrix_world @ v.co for v in sc.data.vertices]
band = [v for v in band if zlo - 0.1 <= v.z <= zhi + 0.1]
xs, ys = sorted(v.x for v in band), sorted(v.y for v in band)
c = Vector((xs[len(xs) // 2], ys[len(ys) // 2], 0))
ds = sorted((Vector((v.x, v.y, 0)) - c).length for v in band)
r = ds[len(ds) // 2]
fing = [w for w in hv if w.x > KNUCKLE_X and w.y > THUMB_Y]
L = max(w.x for w in fing) - KNUCKLE_X
thumb = [w for w in hv if w.y < THUMB_Y]
tip = min(thumb, key=lambda w: w.y) if thumb else None
print("[GRIP] 자루 축 %.3f, %.3f · 반경 %.3f · 손 z %.3f ~ %.3f · 손가락 정점 %d(마디 → 끝 %.3f) · 엄지 정점 %d" % (c.x, c.y, r, zlo, zhi, len(fing), L, len(thumb)))


def around(p, ang):
    """p(수평)를 자루 축 둘레로 ang(라디안 · +x → −y 쪽이 아니라 수학 방향 반시계)만큼 돌림"""
    d = Vector((p.x - c.x, p.y - c.y, 0))
    ca, sa = math.cos(ang), math.sin(ang)
    return Vector((c.x + d.x * ca - d.y * sa, c.y + d.x * sa + d.y * ca, p.z))


def push_out(p):
    d = Vector((p.x - c.x, p.y - c.y, 0))
    if d.length < r + GAP and zlo - 0.05 <= p.z <= zhi + 0.05:
        d = (d.normalized() if d.length > 1e-6 else Vector((-1, 0, 0))) * (r + GAP)
        return Vector((c.x + d.x, c.y + d.y, p.z))
    return p


# 손가락은 자루 −x 쪽에서 앞(−y)으로 돈다 = 수학 방향(반시계 · x → y)으로 각이 늘면 −x에서 −y로 → 각 +
thumb_goal = Vector((c.x + (r + GAP + 0.04) * math.cos(math.radians(250)), c.y + (r + GAP + 0.04) * math.sin(math.radians(250)), 0))
moved = 0
for v, w in zip(hand.data.vertices, hv):
    nw = w.copy()
    if w.x > KNUCKLE_X and w.y > THUMB_Y:
        s = (w.x - KNUCKLE_X) / max(L, 1e-6)
        nw = around(w, math.radians(CURL_DEG) * s * s)  # 끝으로 갈수록 많이 굽음
        d = Vector((nw.x - c.x, nw.y - c.y, 0))  # 굽은 손가락을 자루 표면 쪽으로 당김(마디 근처 손가락이 큰 반경으로 돌아 옆으로 튀어나오지 않게)
        rr = d.length * (1 - s) + (r + GAP + HUG) * s
        if d.length > 1e-6:
            d = d.normalized() * rr
            nw = Vector((c.x + d.x, c.y + d.y, nw.z))
    elif w.y < THUMB_Y and tip is not None:
        k = min(1.0, (THUMB_Y - w.y) / max(THUMB_Y - tip.y, 1e-6)) * THUMB_PULL
        goal = Vector((thumb_goal.x, thumb_goal.y, w.z + (1.62 - tip.z) * k))
        nw = Vector((w.x + (goal.x - tip.x) * k, w.y + (goal.y - tip.y) * k, goal.z))
    nw = push_out(nw)
    if (nw - w).length > 1e-5:
        v.co = mwi @ nw
        moved += 1
hand.data.update()
hand["GripWrapped"] = 1
print("[GRIP] 옮긴 정점 %d / %d" % (moved, len(hv)))

# 메타: 이 손의 center만 다시(경계 가운데 - MeshSwap 맞춤) · 나머지 값 그대로
mp = os.path.join(ART, NAME + ".meta.json")
meta = json.load(open(mp, encoding="utf-8"))
old = meta["parts"]["Hand_R"]["center"]
meta["parts"]["Hand_R"]["center"] = A.roblox_center(hand)
print("[GRIP] 메타 Hand_R center %s → %s" % (old, meta["parts"]["Hand_R"]["center"]))
A.write_json(mp, meta)
objs = [o for o in bpy.data.objects if o.type == "MESH"]
print("[GRIP] 내보내기 오브젝트 %d(메타 partCount %d)" % (len(objs), meta["partCount"]))
A.export_fbx(os.path.join(ART, NAME + ".fbx"), objs)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ART, NAME + ".blend"))
print("[GRIP] 끝")
