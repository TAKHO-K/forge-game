# -*- coding: utf-8 -*-
# A2-N2: 이미 만든 .blend에서 파트 경계 상자 가운데(center)만 메타 json에 채운다(형태 · fbx는 그대로).
#   키 = artlib.meta_of와 같은 규칙(RigPart · 껍데기는 자기 이름) · origin이 메타와 다르면 경고(다른 판 .blend).
# 실행: bash bl.sh meta_center.py <blend 경로> [...]
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import artlib as A  # noqa: E402


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for blend in argv:
        meta_path = blend[:-6] + ".meta.json"
        bpy.ops.wm.open_mainfile(filepath=os.path.abspath(blend))
        import json
        meta = json.load(open(meta_path, encoding="utf-8"))
        parts = meta["parts"]
        done, bad = 0, []
        for o in bpy.data.objects:
            if o.type != "MESH" or not (o.get("RigPart") or o.get("OutlineHull")) or o.name.startswith("old_"):
                continue
            key = o.name.split(".")[0] if o.get("OutlineHull") else o["RigPart"]
            if key not in parts:
                continue
            if max(abs(a - b) for a, b in zip(A.roblox_origin(o), parts[key]["origin"])) > 1e-3:
                bad.append(key)
                continue
            parts[key]["center"] = A.roblox_center(o)
            done += 1
        A.write_json(meta_path, meta)
        print("[meta_center] %s center %d / %d · origin 불일치 %s" % (os.path.basename(meta_path), done, len(parts), bad))


if __name__ == "__main__":
    main()
