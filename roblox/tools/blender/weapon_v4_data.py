"""FINAL-1 2 WEAPON-HOLD: art/weapons/v4/*.meta.json(weapon_kit.py 결과) → src/shared/data/WeaponV4Data.lua 의 rows 표만 다시 쓴다.

사용: python roblox/tools/blender/weapon_v4_data.py
  표 바깥(스위치 · 발광 노브)은 손으로 고친 그대로 둔다 - "-- rows:begin" ~ "-- rows:end" 사이만 바꾼다.
"""
import glob
import json
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))  # roblox/
SRC = os.path.join(ROOT, "art", "weapons", "v4")
LUA = os.path.join(ROOT, "src", "shared", "data", "WeaponV4Data.lua")
STAFF_SUPPORT_UP = 0.9  # 지팡이 보조 손 자리 = 손잡이 위 0.9 stud
REF = {"gs": 5.5, "db": 2.6, "bow": 5.74, "staff": 5.6}  # WeaponRigSpec refLength


def v3(v):
    return "Vector3.new(%s)" % ", ".join("%.4f" % (0.0 if abs(x) < 5e-5 else x) for x in v)


def main():
    lines = []
    for path in sorted(glob.glob(os.path.join(SRC, "*.meta.json"))):
        m = json.load(open(path, encoding="utf-8"))
        name, h, a = m["metaName"], m["hold"], m["attachments"]
        if name.endswith("_L"):
            continue  # 쌍검 왼손 = 오른손 행을 쓴다(같은 손잡이 · X만 뒤집힘)
        kind = m["kind"]
        if kind == "staff" and "Support" not in a:
            a = dict(a, Support=[0.0, STAFF_SUPPORT_UP, 0.0])  # 규격(WeaponRigSpec healer.support) 검사용 - 한 손 지팡이라 IK는 안 쓴다 · 손잡이 구간 안
        if kind != "bow" and "Butt" not in a:  # 자루 끝(끝 축 반대쪽 끝) - 바닥 위 유지(WeaponVisual)가 양 끝을 본다
            t = a["Tip"]
            n = (t[0] ** 2 + t[1] ** 2 + t[2] ** 2) ** 0.5
            back = m["length"] - n
            a = dict(a, Butt=[-t[0] / n * back, -t[1] / n * back, -t[2] / n * back])
        att = ", ".join("%s = %s" % (k, v3(a[k])) for k in ("Grip", "Tip", "Butt", "Support", "StringNock", "Glow") if k in a)
        lines.append(
            '\t["%s"] = { length = %.3f, refScale = %.3f, tris = %d, gripFrom = %.3f, gripTo = %.3f, gripThickness = %.3f, attachments = { %s } },'
            % (name, m["length"], m["length"] / REF[kind], m["totalTris"], h["gripFrom"], h["gripTo"], h["gripThickness"], att))
    text = open(LUA, encoding="utf-8").read()
    head, rest = text.split("-- rows:begin\n", 1)
    _, tail = rest.split("-- rows:end", 1)
    open(LUA, "w", encoding="utf-8", newline="\n").write(head + "-- rows:begin\n" + "\n".join(lines) + "\n-- rows:end" + tail)
    print("rows", len(lines))


if __name__ == "__main__":
    main()
