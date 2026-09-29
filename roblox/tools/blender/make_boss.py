# -*- coding: utf-8 -*-
# A2-N1 보스(Blender bpy): BossRigSpec(Lua) 관절 표를 파이썬으로 옮겨 휴식 자세(FK)를 계산하고 파트마다 메시 1개를 짓는다.
#   파트 이름 = 리그 part 이름(모션은 Motor6D 관절 이름만 본다) · 원점 = 관절 자리(부모 × C0) · 메시는 휴식 자세 월드 방향으로 굽는다(회전 0 - 몬스터와 같은 규칙).
#   굵은 외곽선 = 뒤집은 껍데기 실제 메시(<파트>_Outline · art-direction §4 결정) - 파트 상한 30 안에서 큰 파트에만(OUTLINE_PARTS).
#   이전 버전 = 같은 관절 표의 상자 · 공 · 쐐기 · 원기둥(도형 리그).
#   좌표 = sizeScale 1(게임이 BossData sizeScale을 곱한다) · 루트 = 원점 · 발바닥 y −1.5 · 앞 = −Z.
# 실행: bash bl.sh make_boss.py --bosses section_guardian [--render 폴더] [--old] [--no-export]
import bpy
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import artlib as A  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "art", "bosses"))
BUDGET, PART_CAP = 6000, 30
V = Vector


# ────────────────────────── BossRigSpec 옮김(biped · chain) ──────────────────────────
def biped(o):
    J = []
    leg = o["thigh"][1] + o["shin"][1]
    hipY = -1.5 + o["foot"][1] + leg
    add = J.append
    add(dict(name="RootJoint", parent="HumanoidRootPart", part="Hips", size=o["hips"], color="dark", at=(0, hipY + o["hips"][1] / 2, 0), pivot=(0, 0, 0)))
    add(dict(name="Waist", parent="Hips", part="Body", size=o["torso"], color="body", at=(0, o["hips"][1] / 2, 0), pivot=(0, -o["torso"][1] / 2, 0)))
    add(dict(name="Neck", parent="Body", part="Head", size=o["head"], shape=o.get("headShape", "block"), color="head", at=(0, o["torso"][1] / 2, 0), pivot=(0, -o["head"][1] * 0.45, 0)))
    for side, x in (("L", -1), ("R", 1)):
        tw, tl = o["thigh"]
        sw, sl = o["shin"]
        uw, ul = o["upperArm"]
        fw, fl = o["forearm"]
        add(dict(name="Hip_" + side, parent="Hips", part="Thigh_" + side, size=(tw, tl, tw), color="body", at=(x * o["stance"], -o["hips"][1] / 2, 0), pivot=(0, tl / 2, 0)))
        add(dict(name="Knee_" + side, parent="Thigh_" + side, part="Shin_" + side, size=(sw, sl, sw), color="dark", at=(0, -tl / 2, 0), pivot=(0, sl / 2, 0)))
        add(dict(name="Ankle_" + side, parent="Shin_" + side, part="Foot_" + side, size=o["foot"], color="dark", at=(0, -sl / 2, 0), pivot=(0, o["foot"][1] / 2, o["foot"][2] * 0.25)))
        add(dict(name="Shoulder_" + side, parent="Body", part="UpperArm_" + side, size=(uw, ul, uw), color="body",
                 at=(x * o["shoulderX"], o["torso"][1] / 2 - uw * 0.45, 0), pivot=(0, ul / 2 - uw * 0.3, 0), rot=(0, 0, x * 6)))
        add(dict(name="Elbow_" + side, parent="UpperArm_" + side, part="Forearm_" + side, size=(fw, fl, fw), color="head", at=(0, -ul / 2, 0), pivot=(0, fl / 2, 0), rot=(8, 0, 0)))
        add(dict(name="Wrist_" + side, parent="Forearm_" + side, part="Hand_" + side, size=o["hand"], color="head", at=(0, -fl / 2, 0), pivot=(0, o["hand"][1] / 2, 0)))
    hx, hy, hz = o["head"]
    add(dict(name="Eyes", parent="Head", part="Eyes", size=(hx * 0.62, hy * 0.14, 0.08), color="eye", material="Neon", at=(0, hy * 0.12, -hz / 2), pivot=(0, 0, 0.02)))
    add(dict(name="Jaw", parent="Head", part="Mouth", size=(hx * 0.42, hy * 0.1, 0.08), color="mouth", at=(0, -hy * 0.22, -hz / 2), pivot=(0, hy * 0.04, 0.02)))
    return J


def rig_section_guardian():
    J = biped(dict(hips=(1.6, 0.5, 1.0), torso=(2.4, 1.7, 1.3), head=(1.1, 0.95, 1.0), thigh=(0.75, 0.8), shin=(0.7, 0.8), foot=(0.8, 0.3, 1.1),
                   upperArm=(0.75, 1.0), forearm=(0.8, 0.95), hand=(1.05, 1.0, 1.05), shoulderX=1.5, stance=0.5))
    J.append(dict(name="Pauldron_L", parent="UpperArm_L", part="LeftPauldron", size=(1.0, 0.5, 1.15), color="head", at=(-0.1, 0.45, 0), pivot=(0, 0, 0)))
    J.append(dict(name="Pauldron_R", parent="UpperArm_R", part="RightPauldron", size=(1.0, 0.5, 1.15), color="head", at=(0.1, 0.45, 0), pivot=(0, 0, 0)))
    J.append(dict(name="Rune", parent="Body", part="Rune", size=(0.7, 0.7, 0.08), color="accent", material="Neon", at=(0, 0.2, -0.66), pivot=(0, 0, 0)))
    return dict(joints=J, body=(60, 20, 70), head=(90, 30, 100), accent=(190, 110, 255))


RIGS = {"section_guardian": rig_section_guardian}


def color_of(role, rig):
    if role == "head":
        return rig["head"]
    if role == "dark":
        return A.mul(rig["body"], 0.7)
    if role == "accent":
        return rig["accent"]
    if role == "eye":
        return A.mix((255, 255, 255), rig["accent"], 0.35)
    if role == "mouth":
        return (25, 18, 22)
    return rig["body"]


def angles(rot):
    rx, ry, rz = rot or (0, 0, 0)
    return (A.rot(rx=rx) @ A.rot(ry=ry) @ A.rot(rz=rz)).to_4x4() if rot else Matrix.Identity(4)


def fk(joints):
    """부위 월드 변환(휴식 자세 · Roblox 공간) + 관절 월드 자리"""
    world = {"HumanoidRootPart": Matrix.Identity(4)}
    joint_pos = {}
    for j in joints:
        c0 = Matrix.Translation(V(j["at"])) @ angles(j.get("rot"))
        c1 = Matrix.Translation(V(j["pivot"]))
        p0 = world[j["parent"]]
        world[j["part"]] = p0 @ c0 @ c1.inverted()
        joint_pos[j["part"]] = tuple((p0 @ c0).translation)
    return world, joint_pos


# ────────────────────────── 형태(부위 로컬 - 가운데 원점 · 크기 = 리그 size) ──────────────────────────
def yloft(st, b=0.12):
    """[(y, w, d, dz), ...] 아래 → 위 · 모따기 8각 단면"""
    return A.loft([[(x, y, z + dz) for x, z in A.chamfer_rect(w, d, min(b, w * 0.3, d * 0.3))] for y, w, d, dz in st])


def old_shape(j):
    sx, sy, sz = j["size"]
    sh = j.get("shape", "block")
    if sh == "ball":
        return A.ellipsoid((sx / 2, sy / 2, sz / 2), n=12, rings=8)
    if sh == "cyl":
        return A.lathe([(0.0, -sx / 2), (sy / 2, -sx / 2), (sy / 2, sx / 2), (0.0, sx / 2)], 12, axis="X")
    return A.box(sx, sy, sz)


def guardian_shape(part, j):
    sx, sy, sz = j["size"]
    side = -1 if part.endswith("_L") or part.startswith("Left") else 1
    if part == "Hips":  # 허리띠 + 아래로 내려온 돌 치마(허벅지 위를 덮어 다리가 짧아 보이게)
        belt = yloft([(-sy / 2, sx * 0.85, sz * 0.9, 0), (0, sx * 1.05, sz * 1.05, 0), (sy / 2, sx, sz, 0)], 0.15)
        skirt = yloft([(-sy / 2 - 0.55, sx * 1.12, sz * 1.15, 0), (-sy / 2 - 0.1, sx * 1.08, sz * 1.1, 0), (-sy / 2 + 0.05, sx * 0.95, sz * 0.98, 0)], 0.18)
        return A.merge(belt, skirt)
    if part == "Body":  # 역삼각 상체: 아래 좁고 어깨 넓게 · 가슴 앞으로
        torso = yloft([(-sy / 2, sx * 0.72, sz * 0.85, 0.05), (-sy * 0.3, sx * 0.84, sz * 0.95, 0.0), (-sy * 0.1, sx * 0.95, sz * 1.02, -0.06), (sy * 0.12, sx * 1.06, sz * 1.06, -0.09),
                       (sy * 0.3, sx * 1.12, sz * 1.08, -0.1), (sy * 0.42, sx * 1.1, sz * 1.0, -0.06), (sy / 2, sx * 1.02, sz * 0.9, 0.0)], 0.28)
        chips = [A.crystal(0.5, 0.18, sides=5, tip_h=0.2, base_h=0.1, center=(sx * 0.42 * s, sy * 0.46, sz * 0.2), m=A.rot(rz=-s * 25, rx=15)) for s in (-1, 1)]  # 어깨 뒤 돌 가시(골렘)
        return A.merge(torso, *chips)
    if part == "Head":  # 투구 머리: 앞 이마 돌출 · 턱 좁게
        head = yloft([(-sy / 2, sx * 0.72, sz * 0.8, -0.02), (-sy * 0.1, sx * 0.95, sz, 0), (sy * 0.25, sx, sz * 1.02, -0.04), (sy / 2, sx * 0.78, sz * 0.8, 0.05)], 0.16)
        brow = A.box(sx * 1.02, sy * 0.16, 0.22, b=0.06, center=(0, sy * 0.24, -sz / 2 - 0.03))
        crest = A.tube([(0, sy * 0.45, -sz * 0.35), (0, sy * 0.72, 0), (0, sy * 0.6, sz * 0.45)], lambda u: 0.14 * math.sin(math.pi * (0.2 + 0.7 * u)) + 0.04, sides=4, flat=0.5)
        return A.xform(A.merge(head, brow, crest), t=(0, -0.45, 0))  # 머리를 가슴에 묻는다(어깨 갑주가 정수리보다 높게 - 역삼각)
    if part == "Eyes":  # 기울어진 눈 슬릿 둘(화난 표정)
        return A.merge(*[A.xform(A.box(sx * 0.52, sy * 1.6, 0.1, b=0.02), m=A.rot(rz=s * 12), t=(s * sx * 0.32, -0.45, -0.02)) for s in (-1, 1)])  # 머리와 같이 내림 · ×1.3
    if part == "Mouth":
        return A.merge(*[A.box(0.07, sy * 1.3, 0.1, center=(sx * (k / 3 - 0.5) * 0.9, -0.45, -0.02)) for k in range(4)])
    if part.startswith("Thigh"):
        return yloft([(-sy / 2, sx * 0.85, sz * 0.85, 0), (sy * 0.1, sx, sz, 0), (sy / 2, sx * 1.05, sz * 1.02, 0)], 0.16)
    if part.startswith("Shin"):  # 무릎 보호대 + 아래 넓은 정강이
        shin = yloft([(-sy / 2, sx * 1.1, sz * 1.1, 0), (0, sx * 0.9, sz * 0.9, 0), (sy / 2, sx * 0.85, sz * 0.85, 0)], 0.14)
        knee = A.ellipsoid((sx * 0.55, sy * 0.28, sz * 0.4), n=12, rings=6, center=(0, sy * 0.42, -sz * 0.35))
        return A.merge(shin, knee)
    if part.startswith("Foot"):
        return A.loft([[(x, y, z) for x, y in A.chamfer_rect(w, h, 0.08)] for z, w, h in ((sz * 0.55, sx * 0.9, sy), (-sz * 0.2, sx, sy), (-sz * 0.5, sx * 0.85, sy * 0.7))])
    if part.startswith("UpperArm"):
        return yloft([(-sy / 2, sx * 0.85, sz * 0.85, 0), (0, sx, sz, 0), (sy / 2, sx * 1.02, sz * 1.02, 0)], 0.16)
    if part.startswith("Forearm"):  # 주먹 쪽으로 굵어지는 팔뚝(망치 주먹)
        return yloft([(-sy / 2, sx * 1.22, sz * 1.18, 0), (-sy * 0.2, sx * 1.18, sz * 1.15, 0), (sy / 2, sx * 0.88, sz * 0.88, 0)], 0.18)
    if part.startswith("Hand"):  # 큰 주먹: 모따기 덩어리 + 손가락 마디 4
        k = 1.3  # 망치 주먹 = 팔뚝 폭의 1.4배
        fist = yloft([(-sy / 2 * k, sx * 1.05 * k, sz * k, 0), (-0.05, sx * 1.12 * k, sz * 1.08 * k, 0), (sy / 2 * 0.9, sx * 0.95 * k, sz * 0.92 * k, 0)], 0.26)
        ridge = A.xform(A.box(sx * 1.0 * k, sy * 0.36, 0.3, b=0.1), t=(0, -sy * 0.28, -sz * 0.55 * k))  # 손가락 마디 = 모따기 한 덩어리
        return A.merge(fist, ridge)
    if part in ("LeftPauldron", "RightPauldron"):
        big = part == "RightPauldron"  # 오른쪽만 뿔 달린 큰 판(비대칭)
        k = 1.35 if big else 1.0
        kw, kh, lift = 1.1 * k, 1.25 * k, 0.3  # 폭 ×1.1 · 높이 ×1.25 · 윗면이 정수리보다 높게
        plate = A.ellipsoid((sx * 0.62 * kw, sy * 0.75 * kh, sz * 0.62 * kw), n=16, rings=8, center=(0, 0.05 + lift, 0), squash_bottom=0.25)
        rim = A.tube([(sx * 0.62 * kw * math.cos(a), lift - 0.02, sz * 0.62 * kw * math.sin(a)) for a in (2 * math.pi * i / 16 for i in range(17))], 0.1, sides=5, cap0=False)
        g = A.merge(plate, rim)
        if big:
            horns = [A.tube(A.bezier((side * 0.1, sy * 0.4 + lift, dz), (side * 0.45, sy * 1.2 + lift, dz - 0.05), (side * 0.9, sy * 1.9 + lift, dz + 0.1), (side * 0.75, sy * 2.6 + lift, dz + 0.25), n=5),
                            lambda u, s_=s_: s_ * (0.22 * (1 - u) + 0.02), sides=7, tip_end=True) for dz, s_ in ((-0.25, 1.0), (0.3, 0.75))]
            g = A.merge(g, *horns)
        return g
    if part == "Rune":  # 가슴 룬: 마름모 테 + 가운데 세로 획
        dz = -0.3  # 가슴 앞 볼록(0.1) + 두께 밖으로 - 몸통에 묻히지 않게
        sx, sy = sx * 1.3, sy * 1.3
        pts = [(0, sy * 0.55), (sx * 0.55, 0), (0, -sy * 0.55), (-sx * 0.55, 0)]
        edges = []
        for i in range(4):  # 마름모 테 = 모서리 막대 4개(튜브는 평면 경로에서 틀이 누워 한쪽이 안 보였다)
            (x0, y0), (x1, y1) = pts[i], pts[(i + 1) % 4]
            L = math.hypot(x1 - x0, y1 - y0) + 0.12
            edges.append(A.xform(A.box(L, 0.14, 0.12, b=0.03), m=A.rot(rz=math.degrees(math.atan2(y1 - y0, x1 - x0))), t=((x0 + x1) / 2, (y0 + y1) / 2, dz)))
        ring = A.merge(*edges)
        return A.merge(ring, A.box(0.14, sy * 0.8, 0.12, center=(0, 0, dz)), A.box(sx * 0.5, 0.12, 0.12, center=(0, sy * 0.12, dz)))
    return A.box(sx, sy, sz)


SHAPES = {"section_guardian": guardian_shape}
OUTLINE_PARTS = {"section_guardian": ["Body", "Head", "UpperArm_L", "UpperArm_R", "Forearm_L", "Forearm_R", "Hand_L", "Hand_R", "LeftPauldron", "RightPauldron"]}


def build(boss, old=False, hull=True):
    rig = RIGS[boss]()
    world, jpos = fk(rig["joints"])
    col = A.new_collection(("old_" if old else "") + boss)
    objs, hulls = [], []
    for j in rig["joints"]:
        part = j["part"]
        local = old_shape(j) if old else SHAPES[boss](part, j)
        W = world[part]
        R = W.to_3x3()
        t = W.translation
        geo = A.xform(local, m=R, t=tuple(t))
        o = A.make_obj(part, geo, color_of(j["color"], rig), col, neon=j.get("material") == "Neon", origin=jpos[part],
                       bevel=0.0, mat_name="%s%s_%s" % ("old_" if old else "", boss, part))
        o["Joint"] = j["name"]
        objs.append(o)
        if hull and not old and part in OUTLINE_PARTS.get(boss, []):
            hulls.append(A.add_hull(o, thickness=0.06, export=True, col=col))
    return rig, col, objs, hulls


def parse():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opt = {"bosses": [], "render": None, "export": True, "old": False}
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--bosses":
            opt["bosses"] = argv[i + 1].split(","); i += 1
        elif a == "--render":
            opt["render"] = os.path.abspath(argv[i + 1]); i += 1
        elif a == "--no-export":
            opt["export"] = False
        elif a == "--old":
            opt["old"] = True
        i += 1
    return opt


def main():
    opt = parse()
    for boss in opt["bosses"]:
        A.reset()
        rig, col, objs, hulls = build(boss)
        allo = objs + hulls
        total = sum(A.tri_count(o) for o in allo)
        print("[make_boss] %s 파트 %d(+외곽선 %d = %d / %d) · 삼각형 %d(외곽선 포함) / %d = %.0f%% · %s" % (boss, len(objs), len(hulls), len(allo), PART_CAP, total, BUDGET, 100 * total / BUDGET,
                                                                                         {o.name: A.tri_count(o) for o in objs}))
        if opt["export"]:
            A.export_fbx(os.path.join(OUT, "%s.fbx" % boss), allo)
            meta = A.meta_of(allo, BUDGET, {"version": "A2-N1", "rigId": boss, "partCap": PART_CAP, "joints": {o.name: o["Joint"] for o in objs},
                                            "outlineParts": [h.name for h in hulls], "space": "sizeScale 1 · 루트 원점 · 발바닥 y −1.5 · 앞 −Z"})
            A.write_json(os.path.join(OUT, "%s.meta.json" % boss), meta)
            bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "%s.blend" % boss))
        if opt["render"]:
            # 게임 느낌 = 실제 껍데기 메시(Outline)로 외곽선 · 형태 확인 · 실루엣 = 본체만(render_views가 목록 밖 메시를 숨긴다)
            A.render_views(allo, os.path.join(opt["render"], boss), kinds=("game",), sil=False, hull=0.0, res=(900, 900))
            A.render_views(objs, os.path.join(opt["render"], boss), kinds=("form",), sil=True, hull=0.0, res=(900, 900))
            if opt["old"]:
                for o in allo:
                    o.hide_render = True
                _, _, olds, _ = build(boss, old=True, hull=False)
                A.render_views(olds, os.path.join(opt["render"], "old_" + boss), views=("front", "34"), kinds=("game",), sil=False, hull=0.05, res=(900, 900))
    print("[make_boss] 끝")


if __name__ == "__main__":
    main()
