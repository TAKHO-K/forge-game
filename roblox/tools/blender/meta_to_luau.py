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
        extra = ""
        if p.get("color"):  # A2-N3: 남는 메시(장식 묶음) 색 · 네온
            extra = ', color = "%s", neon = %s' % (p["color"], "true" if p.get("neon") else "false")
        lines.append('\t\t["%s"] = { tris = %d, origin = %s, center = %s%s },' % (name, p.get("tris", 0), vec(p["origin"]), vec(p["center"]), extra))
    lines.append("\t},")
    if d.get("deco"):  # A2-N3: 장식 메시 → 붙는 부위 · 재질 · LOD 2(폰 · 먼 거리에서 숨김)
        lines.append("\tdeco = { %s }," % ", ".join('["%s"] = "%s"' % kv for kv in d["deco"].items()))
        lines.append("\tdecoMaterial = { %s }," % ", ".join('["%s"] = "%s"' % kv for kv in (d.get("decoMaterial") or {}).items()))
        lines.append("\tlod2 = { %s }," % ", ".join('["%s"] = true' % k for k in (d.get("lod2") or [])))
    if d.get("texture"):  # BOSS-FRAMEWORK 7 KIT: 아틀라스(ArtAssetIds 키 = bosses/<파일 이름> - image id) · 그 텍스처를 입는 부위
        t = d["texture"]
        if t.get("partAtlas"):  # BOSS-NIGHT-1: 아틀라스 여러 장 - 부위 값 = 몇 번째 아틀라스(atlases)
            lines.append('\ttexture = { atlas = "bosses/%s", atlases = { %s }, parts = { %s } },' % (t["atlases"][0].rsplit(".", 1)[0], ", ".join('"bosses/%s"' % a.rsplit(".", 1)[0] for a in t["atlases"]),
                                                                                              ", ".join('["%s"] = %d' % (k, t["partAtlas"].get(k, 1)) for k in t["parts"])))
        else:
            lines.append('\ttexture = { atlas = "bosses/%s", parts = { %s } },' % (t["atlases"][0].rsplit(".", 1)[0], ", ".join('["%s"] = true' % k for k in t["parts"])))
    lines += ["}", ""]
    os.makedirs(OUT, exist_ok=True)
    out = os.path.join(OUT, (d.get("metaName") or rig) + ".lua")  # GUARDIAN-V2: KIT --name(같은 리그 다른 메시) = 메시 이름 모듈(ArtMeshKit가 메시 키 이름부터 찾는다)
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


# A2-N3: 방어구 착용 메타 → MeshMeta.armor_wear(조각마다 붙는 R15 파트 · offset · refSize - client/ArmorWearView가 용접 자리 · 체형 배율에 쓴다)
def convert_armor(path):
    d = json.load(open(path, encoding="utf-8"))
    lines = [
        "-- 자동 생성(roblox/tools/blender/meta_to_luau.py) - 손으로 고치지 말 것. 원본 = roblox/art/armor/armor_wear.meta.json",
        "return {",
        '\tversion = "%s",' % d.get("version", ""),
        "\trefBody = {",
    ]
    for name, b in d["refBody"].items():
        lines.append('\t\t%s = { center = %s, size = %s },' % (name, vec(b["center"]), vec(b["size"])))
    lines += ["\t},", "\tpieces = {"]
    for model, pieces in d["pieces"].items():
        lines.append('\t\t["%s"] = {' % model)
        for name, p in pieces.items():
            tris = (", tris = %d" % p["tris"]) if model.startswith("look3_") and "tris" in p else ""  # QUEUE-ALL9E1 LOOK3: 하네스 예산 검사(gear_v3_test)
            lines.append('\t\t\t["%s"] = { attach = "%s", offset = %s, refSize = %s, neon = %s%s },' % (name, p["attach"], vec(p["offset"]), vec(p["refSize"]), "true" if p.get("neon") else "false", tris))
        lines.append("\t\t},")
    lines += ["\t},", "}", ""]
    out = os.path.join(OUT, "armor_wear.lua")
    open(out, "w", encoding="utf-8", newline="\n").write("\n".join(lines))
    return out


def main():
    only = set(sys.argv[1:])
    n = 0
    if not only or "armor_wear" in only:
        print(convert_armor(os.path.join(ROOT, "art", "armor", "armor_wear.meta.json")))
        n += 1
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
