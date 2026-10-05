# -*- coding: utf-8 -*-
# BOSS-FRAMEWORK 0단계 측정: 보스 .blend(또는 KIT 결과 .fbx)의 메시 오브젝트마다 삼각형 수 → 부위별 · 합계 · 외곽선(_Outline) 별도 · Neon 조각 수.
#   Neon 판정 = 같은 이름의 meta.json parts[이름].neon(없으면 재질 이름에 "Neon"). 부위 묶음 = 장식(<부위>_DecoN) · 외곽선(<부위>_Outline)을 그 부위로 모은다.
#   예산 = 바이블 §1-4(삼각형 ≤ 30,000 · 부위 1개 ≤ 5,000 · 외곽선 ≤ 8,000 · 보이는 MeshPart ≤ 90 · 외곽선 ≤ 12 · Neon ≤ 10).
# 실행: bash bl.sh boss_measure.py [--bosses a,b] [--files x.fbx,...] [--out 폴더]  → <out>/boss_tris.json · boss_tris.md
import bpy
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
BOSS_DIR = os.path.normpath(os.path.join(HERE, "..", "..", "art", "bosses"))
ALL = ["section_guardian", "frost_giant", "abyssal_lord", "crystal_queen", "scorpion_queen", "storm_lord"]
BUDGET = {"tris": 30000, "partTris": 5000, "outlineTris": 8000, "parts": 90, "outlines": 12, "neon": 10}


def args():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    o = {"bosses": ALL, "files": [], "out": os.path.join(BOSS_DIR, "_measure")}
    for i, k in enumerate(a):
        if k == "--bosses":
            o["bosses"] = [x for x in a[i + 1].split(",") if x]
        elif k == "--files":
            o["files"] = [x for x in a[i + 1].split(",") if x]
            o["bosses"] = []
        elif k == "--out":
            o["out"] = a[i + 1]
    return o


def tris_of(obj):
    me = obj.data
    return sum(len(p.vertices) - 2 for p in me.polygons)


def host_of(name):
    if name.endswith("_Outline"):
        return name[: -len("_Outline")]
    i = name.find("_Deco")
    return name[:i] if i > 0 else name


def measure(label, meta):
    rows = {}
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        name = obj.name.split(".")[0] if obj.name not in (meta or {}).get("parts", {}) else obj.name
        t = tris_of(obj)
        outline = name.endswith("_Outline")
        pm = (meta or {}).get("parts", {}).get(name)
        neon = bool(pm and pm.get("neon")) or any(s.material and "neon" in s.material.name.lower() for s in obj.material_slots)
        rows[name] = {"tris": t, "outline": outline, "neon": neon and not outline, "host": host_of(name)}
    body = {k: v for k, v in rows.items() if not v["outline"]}
    outl = {k: v for k, v in rows.items() if v["outline"]}
    groups = {}
    for k, v in body.items():
        groups[v["host"]] = groups.get(v["host"], 0) + v["tris"]
    res = {
        "boss": label,
        "meshParts": len(rows), "bodyParts": len(body), "outlines": len(outl), "neon": sum(1 for v in body.values() if v["neon"]),
        "tris": sum(v["tris"] for v in body.values()), "outlineTris": sum(v["tris"] for v in outl.values()),
        "maxPart": max(body.items(), key=lambda kv: kv[1]["tris"])[0] if body else None,
        "maxPartTris": max((v["tris"] for v in body.values()), default=0),
        "maxGroup": max(groups.items(), key=lambda kv: kv[1])[0] if groups else None,
        "maxGroupTris": max(groups.values(), default=0),
        "groups": dict(sorted(groups.items(), key=lambda kv: -kv[1])),
        "parts": rows,
    }
    res["over"] = [k for k, lim in (("tris", BUDGET["tris"]), ("outlineTris", BUDGET["outlineTris"]), ("meshParts", BUDGET["parts"]),
                                     ("outlines", BUDGET["outlines"]), ("neon", BUDGET["neon"]), ("maxGroupTris", BUDGET["partTris"])) if res[k] > lim]
    return res


def main():
    o = args()
    os.makedirs(o["out"], exist_ok=True)
    out = []
    jobs = [(b, os.path.join(BOSS_DIR, b + ".blend")) for b in o["bosses"]] + [(os.path.splitext(os.path.basename(f))[0], f) for f in o["files"]]
    for label, path in jobs:
        meta = None
        mp = os.path.join(os.path.dirname(path), label + ".meta.json")
        if os.path.exists(mp):
            meta = json.load(open(mp, encoding="utf-8"))
        if path.endswith(".blend"):
            bpy.ops.wm.open_mainfile(filepath=path)
        else:
            bpy.ops.wm.read_factory_settings(use_empty=True)
            bpy.ops.import_scene.fbx(filepath=path) if path.endswith(".fbx") else bpy.ops.import_scene.gltf(filepath=path)
        r = measure(label, meta)
        out.append(r)
        print("MEASURE %s parts=%d outlines=%d neon=%d tris=%d outlineTris=%d maxGroup=%s(%d) over=%s" % (
            label, r["meshParts"], r["outlines"], r["neon"], r["tris"], r["outlineTris"], r["maxGroup"], r["maxGroupTris"], ",".join(r["over"]) or "-"))
    json.dump(out, open(os.path.join(o["out"], "boss_tris.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    lines = ["| 보스 | 보이는 MeshPart | 외곽선 | Neon | 삼각형(외곽선 제외) | 외곽선 삼각형 | 가장 큰 부위(장식 포함) | 예산 초과 |", "|---|---|---|---|---|---|---|---|"]
    for r in out:
        lines.append("| %s | %d | %d | %d | %s | %s | %s %s | %s |" % (r["boss"], r["meshParts"], r["outlines"], r["neon"], format(r["tris"], ","), format(r["outlineTris"], ","),
                                                            r["maxGroup"], format(r["maxGroupTris"], ","), ", ".join(r["over"]) or "없음"))
    lines.append("")
    for r in out:
        lines.append("### %s 부위별(장식 · 외곽선은 부위로 묶음 - 외곽선 삼각형 제외)" % r["boss"])
        lines.append("")
        lines.append(" · ".join("%s %s" % (k, format(v, ",")) for k, v in r["groups"].items()))
        lines.append("")
    open(os.path.join(o["out"], "boss_tris.md"), "w", encoding="utf-8").write("\n".join(lines))
    print("wrote", os.path.join(o["out"], "boss_tris.md"))


main()
