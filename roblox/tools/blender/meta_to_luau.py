# A2-N2 3절: Blender 메타(json) → Studio 메타 모듈(ReplicatedStorage.Shared.MeshMeta.<리그 id> - /gg mesh check · swap이 읽는다)
#   parts[이름] = { tris, origin = 관절(Roblox 리그 공간), center = 월드 경계 가운데 } - 교체 도우미가 center로 가져온 모델을 맞춘다(shared/MeshSwap.alignFromMeta).
#   사용: python roblox/tools/blender/meta_to_luau.py            (monsters · bosses 전부)
#         python roblox/tools/blender/meta_to_luau.py rock_boar  (하나)
import json, os, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "src", "shared", "MeshMeta")
KINDS = ["monsters", "bosses"]


def num(v):
    return ("%.3f" % v).rstrip("0").rstrip(".") if isinstance(v, float) else str(v)


def vec(v):
    return "{ " + ", ".join(num(x) for x in v) + " }"


def convert(path):
    d = json.load(open(path, encoding="utf-8"))
    rig = d.get("rigId") or os.path.basename(path).split(".")[0]
    lines = [
        "-- 자동 생성(roblox/tools/blender/meta_to_luau.py) - 손으로 고치지 말 것. 원본 = roblox/art/%s" % os.path.relpath(path, os.path.join(ROOT, "art")).replace("\\", "/"),
        "return {",
        '\trigId = "%s", version = "%s", totalTris = %d,' % (rig, d.get("version", ""), d.get("totalTris", 0)),
        "\tparts = {",
    ]
    for name, p in d["parts"].items():
        if "center" not in p:
            continue
        lines.append('\t\t["%s"] = { tris = %d, origin = %s, center = %s },' % (name, p.get("tris", 0), vec(p["origin"]), vec(p["center"])))
    lines += ["\t},", "}", ""]
    os.makedirs(OUT, exist_ok=True)
    out = os.path.join(OUT, rig + ".lua")
    open(out, "w", encoding="utf-8", newline="\n").write("\n".join(lines))
    return out


# A2-N3: 무기 메타 → MeshMeta.<직업>(부착점 · 등급 look별 파트 색 · 네온) - client/WeaponVisual이 Open Cloud 메시에 부착점을 달고 칠한다(shared/ArtMeshKit.weaponModel).
def convert_weapon(path):
    d = json.load(open(path, encoding="utf-8"))
    rig = d.get("rigId") or os.path.basename(path).split(".")[0]
    lines = [
        "-- 자동 생성(roblox/tools/blender/meta_to_luau.py) - 손으로 고치지 말 것. 원본 = roblox/art/%s" % os.path.relpath(path, os.path.join(ROOT, "art")).replace("\\", "/"),
        "return {",
        '	rigId = "%s", version = "%s", pivot = "%s",' % (rig, d.get("version", ""), d.get("pivot", "")),
        "	attachments = { %s }," % ", ".join('%s = %s' % (k, vec(v)) for k, v in d.get("attachments", {}).items()),
        "	looks = {",
    ]
    for look, l in d["looks"].items():
        lines.append('		%s = { totalTris = %d, parts = {' % (look, l.get("totalTris", 0)))
        for name, p in l["parts"].items():
            lines.append('			["%s"] = { color = "%s", neon = %s },' % (name, p.get("color", "#FFFFFF"), "true" if p.get("neon") else "false"))
        lines.append("		} },")
    lines += ["	},", "}", ""]
    out = os.path.join(OUT, rig + ".lua")
    open(out, "w", encoding="utf-8", newline="\n").write("\n".join(lines))
    return out


def main():
    only = set(sys.argv[1:])
    n = 0
    wfolder = os.path.join(ROOT, "art", "weapons")
    for f in sorted(os.listdir(wfolder)):
        if f.endswith(".meta.json") and (not only or f.split(".")[0] in only):
            print(convert_weapon(os.path.join(wfolder, f)))
            n += 1
    for kind in KINDS:
        folder = os.path.join(ROOT, "art", kind)
        for f in sorted(os.listdir(folder)):
            if f.endswith(".meta.json") and (not only or f.split(".")[0] in only):
                print(convert(os.path.join(folder, f)))
                n += 1
    print("meta_to_luau: %d개" % n)


if __name__ == "__main__":
    main()
