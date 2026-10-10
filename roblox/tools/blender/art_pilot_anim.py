# -*- coding: utf-8 -*-
# ART-PILOT-1: Meshy 스킨 FBX의 애니 → 프레임별 뼈 "월드 변화량"(포즈 월드 × 쉬는 자세 월드⁻¹) JSON.
#   변화량은 뼈 축 방향과 무관 → Studio에서 Roblox 쪽 쉬는 자세 뼈 월드에 곱하면 목표 월드가 나오고, Transform = (부모 월드 × bone.CFrame)⁻¹ × 목표.
#   Blender 축 · 단위 → Roblox는 Studio에서 쉬는 자세 뼈 위치를 맞춰 정한다(restHead = Blender 월드 m).
# 실행: bash bl.sh art_pilot_anim.py <입력.fbx> <출력.json>
import bpy
import json
import sys

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = argv[0], argv[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=SRC)
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
act = arm.animation_data.action
f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
sc = bpy.context.scene
names = [b.name for b in arm.data.bones]
R = lambda v: round(v, 5)  # noqa: E731
rest = {b.name: arm.matrix_world @ b.matrix_local for b in arm.data.bones}
out = {"source": SRC.replace("\\", "/").split("/")[-1], "fps": sc.render.fps, "frames": f1 - f0 + 1,
       "bones": [{"name": b.name, "parent": b.parent.name if b.parent else None, "restHead": [R(x) for x in rest[b.name].translation]} for b in arm.data.bones],
       "delta": []}
for f in range(f0, f1 + 1):
    sc.frame_set(f)
    fr = []
    for n in names:
        d = (arm.matrix_world @ arm.pose.bones[n].matrix) @ rest[n].inverted()
        fr.append([R(d[i][j]) for i in range(3) for j in range(4)])  # 3 × 4 행 우선(회전 3 × 3 + 이동)
    out["delta"].append(fr)
with open(OUT, "w", encoding="utf-8") as fh:
    json.dump(out, fh, separators=(",", ":"))
print("ANIM", out["source"], "bones", len(names), "frames", out["frames"], "fps", out["fps"])
