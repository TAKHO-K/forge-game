# -*- coding: utf-8 -*-
# A2-N1 리그 JSON 만들기(Studio 없이 - 시스템 python): MonsterRigSpec.lua의 J(...) 표 + MonsterSpeciesData 색 → rigs/<종>.rig.json(rig_dump.luau와 같은 형식).
#   변환 = BossRig.build와 같은 식: 파트 = 부모 × C0(at · 회전) × C1(pivot)⁻¹ · 관절 = 부모 × C0. 색 = BossRigSpec.colorOf(어두움 = 몸 ×0.7 · 눈 = 흰색 ↔ 강조 0.35).
#   검증: --check rock_boar → 이미 있는 Studio 덤프 JSON과 center · joint · color 대조.
# 사용: python rig_from_lua.py sand_scorpion cactus_imp ...   |   python rig_from_lua.py --check rock_boar
import json
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.normpath(os.path.join(HERE, "..", "..", "src", "shared", "data"))
NUM = r"-?\d+(?:\.\d+)?"
VEC = r"V\(\s*(%s)\s*,\s*(%s)\s*,\s*(%s)\s*\)" % (NUM, NUM, NUM)


def read(name):
    with open(os.path.join(SRC, name), encoding="utf-8") as f:
        return f.read()


def parse_rig(sid):
    src = read("MonsterRigSpec.lua")
    m = re.search(r"rigs\.%s = \{.*?joints = \{(.*?)\n\} \}" % sid, src, re.S)
    joints = []
    for line in m.group(1).splitlines():
        jm = re.search(r'J\("(\w+)",\s*(\w+|"\w+"),\s*%s,\s*"(\w+)",\s*%s(.*)\)' % (VEC, VEC), line)
        if not jm:
            continue
        g = jm.groups()
        part, parent = g[0], g[1].strip('"')
        parent = "HumanoidRootPart" if parent == "R" else parent
        size = [float(x) for x in g[2:5]]
        color = g[5]
        at = [float(x) for x in g[6:9]]
        rest = g[9]
        pv = re.search(r"pivot = " + VEC, rest)
        rt = re.search(r"rot = " + VEC, rest)
        sh = re.search(r'shape = "(\w+)"', rest)
        mt = re.search(r'material = "(\w+)"', rest)
        joints.append(dict(part=part, parent=parent, size=size, color=color, at=at, pivot=[float(x) for x in pv.groups()] if pv else [0, 0, 0],
                           rot=[float(x) for x in rt.groups()] if rt else None, shape=sh.group(1) if sh else "block", material=mt.group(1) if mt else "SmoothPlastic",
                           name="RootJoint" if part == "Body" else ("Neck" if part == "Head" else part)))
    return joints


def species_colors(sid):
    src = read("MonsterSpeciesData.lua")
    line = re.search(r"\b%s = \{[^\n]*" % sid, src).group(0)
    get = lambda k: [int(x) for x in re.search(r"\b%s = C\((\d+), (\d+), (\d+)\)" % k, line).groups()]
    return get("body"), get("head"), get("accent")


# 3×3 행렬 · 변환(R, t)
def mm(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def mv(a, v):
    return [sum(a[i][k] * v[k] for k in range(3)) for i in range(3)]


def rx(d):
    c, s = math.cos(math.radians(d)), math.sin(math.radians(d))
    return [[1, 0, 0], [0, c, -s], [0, s, c]]


def ry(d):
    c, s = math.cos(math.radians(d)), math.sin(math.radians(d))
    return [[c, 0, s], [0, 1, 0], [-s, 0, c]]


def rz(d):
    c, s = math.cos(math.radians(d)), math.sin(math.radians(d))
    return [[c, -s, 0], [s, c, 0], [0, 0, 1]]


I3 = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]


def compose(A_, B_):
    """(R, t) ∘ (R, t)"""
    return mm(A_[0], B_[0]), [a + b for a, b in zip(mv(A_[0], B_[1]), A_[1])]


def color_of(role, body, head, accent):
    if role == "head":
        return head
    if role == "dark":
        return [round(c * 0.7) for c in body]
    if role == "accent":
        return accent
    if role == "eye":
        return [round(255 + (a - 255) * 0.35) for a in accent]
    if role == "mouth":
        return [25, 18, 22]
    return body


def build(sid):
    body, head, accent = species_colors(sid)
    world = {"HumanoidRootPart": (I3, [0.0, 0.0, 0.0])}
    parts = []
    for j in parse_rig(sid):
        R0 = mm(mm(rx(j["rot"][0]), ry(j["rot"][1])), rz(j["rot"][2])) if j["rot"] else I3
        c0 = (R0, j["at"])
        c1inv = (I3, [-p for p in j["pivot"]])
        p0 = world[j["parent"]]
        jw = compose(p0, c0)
        w = compose(jw, c1inv)
        world[j["part"]] = w
        parts.append({"center": [round(x, 6) for x in w[1]], "color": [float(c) for c in color_of(j["color"], body, head, accent)], "colorRole": j["color"],
                      "joint": [round(x, 6) for x in jw[1]], "jointName": j["name"], "material": j["material"], "name": j["part"], "parent": j["parent"],
                      "rotation": [round(x, 6) for row in w[0] for x in row], "shape": j["shape"], "size": j["size"]})
    budget = 1500.0
    return {"kind": "monster", "referenceRoot": "HumanoidRootPart", "rigId": sid, "space": "roblox(+Y 위 · -Z 앞)", "triAttribute": "TriCount", "triBudget": budget,
            "units": "stud", "source": "rig_from_lua.py(MonsterRigSpec.lua)", "parts": parts}


def main():
    args = sys.argv[1:]
    if args and args[0] == "--check":
        sid = args[1]
        mine = {p["name"]: p for p in build(sid)["parts"]}
        with open(os.path.join(HERE, "rigs", "%s.rig.json" % sid), encoding="utf-8") as f:
            ref = {p["name"]: p for p in json.load(f)["parts"]}
        bad = 0
        for n, p in ref.items():
            for k in ("center", "joint", "color"):
                d = max(abs(a - b) for a, b in zip(p[k], mine[n][k]))
                if d > 0.02 * (255 if k == "color" else 1):
                    bad += 1
                    print("다름", n, k, p[k], mine[n][k])
        print("check %s: 파트 %d · 다름 %d" % (sid, len(ref), bad))
        return
    for sid in args:
        d = build(sid)
        path = os.path.join(HERE, "rigs", "%s.rig.json" % sid)
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write('{"kind": "monster", "referenceRoot": "HumanoidRootPart", "rigId": "%s", "source": "%s", "space": "%s", "triAttribute": "TriCount", "triBudget": 1500.0, "units": "stud", "parts": [\n' % (sid, d["source"], d["space"]))
            f.write(",\n".join("  " + json.dumps(p, ensure_ascii=False) for p in d["parts"]))
            f.write("\n]}\n")
        print("rig", sid, len(d["parts"]))


if __name__ == "__main__":
    main()
