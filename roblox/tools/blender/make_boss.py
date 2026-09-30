# -*- coding: utf-8 -*-
# A2-N1 보스(Blender bpy): BossRigSpec(Lua) 관절 표를 파이썬으로 옮겨 휴식 자세(FK)를 계산하고 파트마다 메시 1개를 짓는다.
#   파트 이름 = 리그 part 이름(모션은 Motor6D 관절 이름만 본다) · 원점 = 관절 자리(부모 × C0) · 메시는 휴식 자세 월드 방향으로 굽는다(회전 0 - 몬스터와 같은 규칙).
#   굵은 외곽선 = 뒤집은 껍데기 실제 메시(<파트>_Outline · art-direction §4 결정) - 파트 상한 30 안에서 큰 파트에만(OUTLINE_PARTS).
#   이전 버전 = 같은 관절 표의 상자 · 공 · 쐐기 · 원기둥(도형 리그).
#   좌표 = sizeScale 1(게임이 BossData sizeScale을 곱한다) · 루트 = 원점 · 발바닥 y −1.5 · 앞 = −Z.
# 실행: bash bl.sh make_boss.py --bosses section_guardian [--render 폴더] [--old] [--no-export] [--merge-deco(A2-N3 결정 ③ - 장식을 몸 파트에 합침)]
import bpy
import io
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import artlib as A  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "art", "bosses"))
# A2-M1 사용자 지시(2026-09-30 "보스 파트 제한을 풀어 정성 들였다고 알 수 있게 · 폰 4인 렉 없이 적당히"): 게임 도형 파트 ≤ 80(전갈 110) + 외곽선 껍데기 10 → 95 · 120.
#   옛 = A2-N2 40 · 전갈 48. 삼각형 예산은 디테일만큼 늘린다(두 발 9,000 · 전갈 11,000 - art-direction §6 A2-M1 개정).
BUDGET, PART_CAP = 9000, 95
PART_CAP_OF = {"scorpion_queen": 120}
BUDGET_OF = {"scorpion_queen": 11000}
DETAIL_JSON = os.path.join(HERE, "rigs", "boss_detail.json")  # A2-M1: python detail_dump.py가 Lua 규격(BossDetailSpec)에서 뽑는다 - 손으로 옮겨 적지 않는다
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


def chain(J, prefix, parent, count, length, w0, w1, at, rot0, rot_step, color="body", flat=1.0, tip_color=None, tip_shape=None, tip_material=None):
    """BossRigSpec chain 이식: n마디 · 끝으로 굵기 w0 → w1 · 첫 마디 rot0 · 다음부터 rotStep"""
    for i in range(1, count + 1):
        f = (i - 1) / max(count - 1, 1)
        w = w0 + (w1 - w0) * f
        name = "%s%d" % (prefix, i)
        J.append(dict(name=name, parent=parent, part=name, size=(w * flat, length, w), color=(tip_color if (i == count and tip_color) else color),
                      material=(tip_material if i == count else None), shape=(tip_shape if (i == count and tip_shape) else "block"),
                      at=at if i == 1 else (0, -length / 2, 0), pivot=(0, length / 2, 0), rot=rot0 if i == 1 else rot_step))
        parent = name


def white(c, t=0.3):
    return tuple(int(round(x + (255 - x) * t)) for x in c)


TIER = {1: (111, 158, 76), 2: (63, 142, 92), 3: (74, 122, 46), 4: (168, 95, 38), 6: (224, 80, 92)}  # MonsterData 티어 색(BossData tierColor) · 머리 = 흰색 쪽 0.3


# A2-N2 사용자 결정: 보스 몸 색 = 종 테마 색(티어 색은 강조로만). 게임 BossData는 아직 티어 색 - 가져오기 때 ArtStyleV1 뒤에서 이 값(meta themeColors)으로 칠한다.
THEME = {"frost_giant": dict(body=(96, 150, 204), head=(226, 240, 250), accent=(170, 232, 255)),       # 얼음 청 · 흰
         "abyssal_lord": dict(body=(24, 66, 112), head=(36, 140, 146), accent=(70, 226, 214)),         # 심청 · 청록
         "storm_lord": dict(body=(92, 97, 128), head=(118, 124, 156), accent=(255, 224, 64)),          # 먹색 + 번개 노랑 · 2차: 몸 #5C6180(T5 바닥 #3A3F5C · 외곽선보다 밝게 - 검토)
         "crystal_queen": dict(body=(222, 120, 172), head=(246, 204, 224), accent=(84, 226, 214)),     # 분홍 + 청록 결정
         "scorpion_queen": dict(body=(168, 95, 38), head=(206, 150, 104), accent=(255, 196, 60))}      # 설계서 = 모래 적갈 + 금 독침(유지)


def themed(boss, d):
    d.update(THEME[boss])
    return d


def rig_frost_giant():
    J = biped(dict(hips=(1.4, 0.5, 0.9), torso=(1.9, 1.9, 1.15), head=(1.0, 1.0, 1.0), thigh=(0.62, 1.0), shin=(0.56, 1.0), foot=(0.72, 0.3, 1.0),
                   upperArm=(0.58, 1.05), forearm=(0.58, 1.0), hand=(0.72, 0.8, 0.72), shoulderX=1.22, stance=0.42))
    J.append(dict(name="Horn_L", parent="Head", part="LeftHorn", size=(0.3, 1.0, 0.3), shape="wedge", color="accent", at=(-0.45, 0.45, 0), pivot=(0, -0.45, 0), rot=(0, 0, 25)))
    J.append(dict(name="Horn_R", parent="Head", part="RightHorn", size=(0.3, 1.0, 0.3), shape="wedge", color="accent", at=(0.45, 0.45, 0), pivot=(0, -0.45, 0), rot=(0, 180, 25)))
    chain(J, "Beard", "Head", 3, 0.38, 0.62, 0.3, (0, -0.45, -0.3), (-8, 0, 0), (-6, 0, 0), color="accent", flat=1.1)
    J.append(dict(name="Club", parent="Hand_R", part="IceClub", size=(0.55, 2.6, 0.55), shape="cyl", color="accent", material="Ice", at=(0, -0.35, 0), pivot=(0, 0.9, 0)))
    return themed("frost_giant", dict(joints=J))


def rig_abyssal_lord():
    J = biped(dict(hips=(1.5, 0.5, 1.1), torso=(2.3, 1.6, 1.4), head=(1.1, 0.9, 1.1), thigh=(0.66, 0.72), shin=(0.6, 0.72), foot=(0.8, 0.25, 1.15),
                   upperArm=(0.62, 0.95), forearm=(0.6, 0.9), hand=(0.72, 0.72, 0.72), shoulderX=1.42, stance=0.46))
    J.append(dict(name="Fin_L", parent="Head", part="LeftFin", size=(0.25, 0.8, 0.9), shape="wedge", color="accent", at=(-0.6, 0.1, 0.1), pivot=(0, -0.2, 0), rot=(0, 0, 35)))
    J.append(dict(name="Fin_R", parent="Head", part="RightFin", size=(0.25, 0.8, 0.9), shape="wedge", color="accent", at=(0.6, 0.1, 0.1), pivot=(0, -0.2, 0), rot=(0, 0, -35)))
    J.append(dict(name="Crest", parent="Body", part="BackFin", size=(0.25, 1.1, 1.2), shape="wedge", color="accent", at=(0, 0.4, 0.7), pivot=(0, -0.3, 0), rot=(0, 180, 0)))
    chain(J, "Tail", "Hips", 6, 0.75, 0.75, 0.32, (0, -0.15, 0.5), (-75, 0, 0), (-9, 0, 0), color="head", flat=1.2, tip_color="accent", tip_shape="wedge")
    J.append(dict(name="Trident", parent="Hand_R", part="Trident", size=(0.22, 4.2, 0.22), shape="cyl", color="accent", at=(0, -0.3, 0), pivot=(0, -0.6, 0)))
    J.append(dict(name="TridentHead", parent="Trident", part="TridentHead", size=(0.9, 0.7, 0.15), shape="wedge", color="accent", material="Neon", at=(0, 2.1, 0), pivot=(0, -0.35, 0)))
    return themed("abyssal_lord", dict(joints=J))


def rig_crystal_queen():
    J = biped(dict(hips=(1.2, 0.5, 0.9), torso=(1.5, 1.7, 0.9), head=(0.9, 0.95, 0.9), headShape="ball", thigh=(0.5, 0.9), shin=(0.45, 0.9), foot=(0.55, 0.25, 0.9),
                   upperArm=(0.45, 0.95), forearm=(0.42, 0.9), hand=(0.5, 0.6, 0.5), shoulderX=0.95, stance=0.35))
    for i, (tag, at, r0) in enumerate((("F", (0, 0, -0.45), (12, 0, 0)), ("B", (0, 0, 0.45), (-12, 0, 0)), ("L", (-0.6, 0, 0), (0, 0, -12)), ("R", (0.6, 0, 0), (0, 0, 12)))):
        w0, w1 = (1.25, 1.35) if i < 2 else (0.95, 1.05)
        chain(J, "Skirt" + tag, "Hips", 2, 0.75, w0, w1, (at[0], at[1] - 0.1, at[2]), r0, tuple(x * 0.5 for x in r0), color="head", tip_color="accent", tip_material="Glass")
    J.append(dict(name="Crown", parent="Head", part="Crown", size=(0.8, 0.5, 0.8), shape="cyl", color="accent", material="Neon", at=(0, 0.5, 0), pivot=(0, -0.2, 0), rot=(0, 0, 90)))
    J.append(dict(name="Wing_L", parent="Body", part="LeftShard", size=(0.35, 1.6, 0.35), shape="wedge", color="accent", material="Glass", at=(-0.4, 0.5, 0.45), pivot=(0, -0.7, 0), rot=(-15, 0, 30)))
    J.append(dict(name="Wing_R", parent="Body", part="RightShard", size=(0.35, 1.6, 0.35), shape="wedge", color="accent", material="Glass", at=(0.4, 0.5, 0.45), pivot=(0, -0.7, 0), rot=(-15, 180, 30)))
    J.append(dict(name="Scepter", parent="Hand_R", part="Scepter", size=(0.18, 2.4, 0.18), shape="cyl", color="head", at=(0, -0.25, 0), pivot=(0, -0.5, 0)))
    J.append(dict(name="ScepterGem", parent="Scepter", part="ScepterGem", size=(0.5, 0.5, 0.5), shape="ball", color="accent", material="Neon", at=(0, 1.25, 0), pivot=(0, 0, 0)))
    return themed("crystal_queen", dict(joints=J))


def rig_storm_lord():
    J = biped(dict(hips=(1.3, 0.5, 0.9), torso=(1.7, 1.8, 1.0), head=(0.95, 1.0, 0.95), thigh=(0.55, 0.95), shin=(0.5, 0.95), foot=(0.6, 0.25, 0.95),
                   upperArm=(0.5, 1.0), forearm=(0.48, 0.95), hand=(0.55, 0.6, 0.55), shoulderX=1.05, stance=0.38))
    J.append(dict(name="Blade_L", parent="Body", part="LeftBlade", size=(0.3, 1.5, 0.3), shape="wedge", color="accent", at=(-0.95, 0.9, 0), pivot=(0, -0.6, 0), rot=(0, 0, 15)))
    J.append(dict(name="Blade_R", parent="Body", part="RightBlade", size=(0.3, 1.5, 0.3), shape="wedge", color="accent", at=(0.95, 0.9, 0), pivot=(0, -0.6, 0), rot=(0, 180, 15)))
    chain(J, "CapeL", "Body", 3, 0.8, 0.8, 0.95, (-0.42, 0.8, 0.55), (-6, 0, 0), (-3, 0, 0), color="dark", tip_color="lining")  # 2차: 찢어진 끝 마디 = 톤 다운 번개 노랑
    chain(J, "CapeR", "Body", 3, 0.8, 0.8, 0.95, (0.42, 0.8, 0.55), (-6, 0, 0), (-3, 0, 0), color="dark", tip_color="lining")
    J.append(dict(name="Staff", parent="Hand_R", part="Staff", size=(0.25, 4.6, 0.25), shape="cyl", color="dark", at=(0, -0.3, 0), pivot=(0, -0.4, 0)))
    J.append(dict(name="StaffOrb", parent="Staff", part="StaffOrb", size=(0.7, 0.7, 0.7), shape="ball", color="accent", material="Neon", at=(0, 2.35, 0), pivot=(0, 0, 0)))
    return themed("storm_lord", dict(joints=J))


def rig_scorpion_queen():
    J = [dict(name="RootJoint", parent="HumanoidRootPart", part="Body", size=(2.4, 0.9, 2.2), color="body", at=(0, -0.1, 0), pivot=(0, 0, 0)),
         dict(name="Neck", parent="Body", part="Head", size=(1.3, 0.7, 0.9), color="head", at=(0, 0.05, -1.1), pivot=(0, 0, 0.42)),
         dict(name="Eyes", parent="Head", part="Eyes", size=(0.8, 0.14, 0.08), color="eye", material="Neon", at=(0, 0.15, -0.45), pivot=(0, 0, 0.02)),
         dict(name="Jaw", parent="Head", part="Mouth", size=(0.6, 0.12, 0.08), color="mouth", at=(0, -0.18, -0.45), pivot=(0, 0.04, 0.02))]
    for side, x in (("L", -1), ("R", 1)):
        for k, z in enumerate((-0.6, 0.15, 0.85), 1):
            leg = "%d_%s" % (k, side)
            J.append(dict(name="Hip" + leg, parent="Body", part="Thigh" + leg, size=(0.28, 1.0, 0.28), color="head", at=(x * 1.2, -0.15, z), pivot=(0, 0.5, 0), rot=(0, 0, x * 125)))
            J.append(dict(name="Knee" + leg, parent="Thigh" + leg, part="Shin" + leg, size=(0.24, 1.95, 0.24), color="dark", at=(0, -0.5, 0), pivot=(0, 0.975, 0), rot=(0, 0, -x * 95)))
        J.append(dict(name="Shoulder_" + side, parent="Body", part="UpperArm_" + side, size=(0.4, 1.0, 0.4), color="head", at=(x * 0.95, 0.05, -1.05), pivot=(0, 0.5, 0), rot=(95, x * -25, 0)))
        J.append(dict(name="Elbow_" + side, parent="UpperArm_" + side, part="Forearm_" + side, size=(0.42, 1.0, 0.42), color="body", at=(0, -0.5, 0), pivot=(0, 0.5, 0), rot=(40, 0, 0)))
        J.append(dict(name="Wrist_" + side, parent="Forearm_" + side, part="Hand_" + side, size=(0.8, 0.9, 0.5), color="head", at=(0, -0.5, 0), pivot=(0, 0.4, 0), rot=(-45, 0, 0)))
        J.append(dict(name="Pincer_" + side, parent="Hand_" + side, part="Pincer_" + side, size=(0.3, 0.9, 0.3), shape="wedge", color="accent", at=(-x * 0.25, -0.4, 0), pivot=(0, 0.45, 0), rot=(0, 0, x * 10)))
    for t, yaw in enumerate((-30, 0, 30), 1):
        chain(J, "Tail%d_" % t, "Body", 8, 0.55, 0.45, 0.24, ((t - 2) * 0.45, 0.3, 1.0), (-127, yaw, 0), (-20, 0, 0), color="body", tip_color="accent", tip_shape="wedge", tip_material="Neon")
    return themed("scorpion_queen", dict(joints=J))


RIGS = {"section_guardian": rig_section_guardian, "frost_giant": rig_frost_giant, "abyssal_lord": rig_abyssal_lord, "crystal_queen": rig_crystal_queen,
        "storm_lord": rig_storm_lord, "scorpion_queen": rig_scorpion_queen}


def color_of(role, rig):
    if role == "head":
        return rig["head"]
    if role == "dark":
        return A.mul(rig["body"], 0.7)
    if role == "accent":
        return rig["accent"]
    if role == "eye":  # 밝은 얼굴(서리 · 수정)에서는 흰 눈이 묻힌다 → 강조색 그대로(A2-N2)
        return rig["accent"] if sum(rig["head"]) > 600 else A.mix((255, 255, 255), rig["accent"], 0.35)
    if role == "mouth":
        return (25, 18, 22)
    if role == "lining":  # 2차 폭풍 군주 망토 끝(#E8C040 - 발광 아님)
        return (232, 192, 64)
    # A2-M1 디테일 색 역할(BossRigSpec.colorOf와 같은 식)
    if role == "light":
        return A.mix(rig["head"], (255, 255, 255), 0.35)
    if role == "shadow":
        return A.mul(rig["body"], 0.5)
    if role == "stone":
        return A.mix(rig["body"], (140, 136, 150), 0.42)
    if role == "slab":
        return A.mix(rig["head"], (205, 200, 215), 0.4)
    if role == "metal":
        return A.mix(rig["head"], (150, 150, 160), 0.6)
    if isinstance(role, (list, tuple)):
        return tuple(role)
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
    if sh == "wedge":  # Roblox 쐐기: 아래 전체 · 위는 뒤(+Z) 모서리만
        v = [(-sx / 2, -sy / 2, -sz / 2), (sx / 2, -sy / 2, -sz / 2), (sx / 2, -sy / 2, sz / 2), (-sx / 2, -sy / 2, sz / 2), (-sx / 2, sy / 2, sz / 2), (sx / 2, sy / 2, sz / 2)]
        return v, [(0, 1, 2, 3), (3, 2, 5, 4), (0, 4, 5, 1), (0, 3, 4), (1, 5, 2)]
    return A.box(sx, sy, sz)  # "cyl"은 BossRig.newPart가 처리하지 않아 게임에서도 상자다


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


def taper_seg(sx, sy, sz, k_end=0.8, b=0.1, bulge=1.06):
    """마디(관절 = 위 +sy/2 · 끝 = 아래): 위에서 아래로 가늘어지는 모따기 덩어리"""
    return yloft([(-sy / 2, sx * k_end, sz * k_end, 0), (-sy * 0.1, sx * bulge, sz * bulge, 0), (sy / 2, sx, sz, 0)], b)


def biped_generic(part, j, st):
    """두 발 보스 공통 부위. st = 스타일: shoulders(어깨 폭 배) · waist(허리 폭 배) · head("helm" | "round" | "hood") · fist(주먹 배) · robe(치마 길이)"""
    sx, sy, sz = j["size"]
    if part == "Hips":
        g = yloft([(-sy / 2, sx * 0.9, sz * 0.9, 0), (0, sx * 1.05, sz * 1.05, 0), (sy / 2, sx, sz, 0)], 0.14)
        if st.get("robe"):
            r = st["robe"]
            g = A.merge(g, yloft([(-sy / 2 - r, sx * 1.35, sz * 1.35, 0.04), (-sy / 2 - r * 0.4, sx * 1.18, sz * 1.18, 0), (sy / 2 - 0.05, sx * 1.0, sz * 1.0, 0)], 0.16))
        return g
    if part == "Body":
        w0, w1 = st.get("waist", 0.8), st.get("shoulders", 1.1)
        return yloft([(-sy / 2, sx * w0, sz * 0.85, 0.04), (-sy * 0.15, sx * (w0 + w1) / 2, sz * 1.0, -0.05), (sy * 0.3, sx * w1, sz * 1.05, -0.08), (sy / 2, sx * w1 * 0.9, sz * 0.88, 0)], 0.22)
    if part == "Head":
        style = st.get("head", "helm")
        if style == "round" or j.get("shape") == "ball":
            return A.merge(A.ellipsoid((sx * 0.52, sy * 0.52, sz * 0.52), n=14, rings=8), A.ellipsoid((sx * 0.22, sy * 0.14, sz * 0.14), n=8, rings=4, center=(0, -sy * 0.18, -sz * 0.44)))
        if style == "hood":
            hood = yloft([(-sy / 2, sx * 0.9, sz * 0.95, 0.04), (0, sx * 1.1, sz * 1.1, 0.02), (sy * 0.35, sx * 0.95, sz, 0.08), (sy / 2 + 0.15, sx * 0.3, sz * 0.35, 0.3)], 0.14)
            return hood
        head = yloft([(-sy / 2, sx * 0.78, sz * 0.82, 0), (-sy * 0.1, sx * 0.98, sz, 0), (sy * 0.3, sx, sz, -0.03), (sy / 2, sx * 0.8, sz * 0.82, 0.04)], 0.15)
        return A.merge(head, A.box(sx * 1.02, sy * 0.14, 0.2, b=0.05, center=(0, sy * 0.22, -sz / 2 - 0.02)))
    if part == "Eyes":
        return A.merge(*[A.xform(A.box(sx * 0.42, sy * 1.3, 0.1, b=0.02), m=A.rot(rz=s * 10), t=(s * sx * 0.3, 0, -0.03)) for s in (-1, 1)])
    if part == "Mouth":
        return A.box(sx, sy, 0.1, b=0.03, center=(0, 0, -0.02))
    if part.startswith("Thigh"):
        return taper_seg(sx, sy, sz, 0.88, 0.14)
    if part.startswith("Shin"):
        return A.merge(taper_seg(sx, sy, sz, 1.08, 0.13, 0.95), A.ellipsoid((sx * 0.5, sy * 0.24, sz * 0.36), n=10, rings=5, center=(0, sy * 0.4, -sz * 0.32)))
    if part.startswith("Foot"):
        return A.loft([[(x, y, z) for x, y in A.chamfer_rect(w, h, 0.07)] for z, w, h in ((sz * 0.5, sx * 0.9, sy), (-sz * 0.2, sx, sy), (-sz * 0.5, sx * 0.82, sy * 0.7))])
    if part.startswith("UpperArm"):
        return taper_seg(sx, sy, sz, 0.88, 0.14)
    if part.startswith("Forearm"):
        return yloft([(-sy / 2, sx * 1.12, sz * 1.1, 0), (-sy * 0.15, sx * 1.1, sz * 1.08, 0), (sy / 2, sx * 0.9, sz * 0.9, 0)], 0.15)
    if part.startswith("Hand"):
        k = st.get("fist", 1.0)
        return A.merge(yloft([(-sy / 2 * k, sx * k, sz * 0.95 * k, 0), (0, sx * 1.08 * k, sz * 1.02 * k, 0), (sy / 2 * 0.9, sx * 0.92 * k, sz * 0.9 * k, 0)], 0.16),
                       A.xform(A.box(sx * 0.9 * k, sy * 0.3, 0.22, b=0.07), t=(0, -sy * 0.25, -sz * 0.52 * k)))
    return None


def chain_seg(j, flat_tail=False):
    """사슬 마디(관절 = 위): 위 → 아래로 좁아지는 둥근 마디"""
    sx, sy, sz = j["size"]
    rings = []
    for y, k in ((sy / 2, 1.0), (0.0, 1.06), (-sy / 2, 0.86)):
        rings.append([(x * k, y, z * k) for x, z in A.circle2d(sz / 2, 8, rx=sx / 2)])
    return A.loft(rings)


def frost_extra(part, j):
    sx, sy, sz = j["size"]
    if part.startswith("UpperArm"):  # 윗팔 + 어깨 위 얼음 결정 덩어리(갑주 자리 - 머리보다 높게 솟음)
        side = -1 if part.endswith("_L") else 1
        arm = biped_generic(part, j, STYLE["frost_giant"])
        cl = [A.crystal(h, r, sides=6, tip_h=h * 0.4, base_h=0.15, center=(side * dx, sy * 0.5 + h * 0.3, dz), m=A.rot(rz=-side * tilt, rx=tx))
              for h, r, dx, dz, tilt, tx in ((1.5, 0.36, 0.05, 0.0, 12, 0), (1.05, 0.26, 0.32, 0.15, 35, 10), (0.8, 0.22, -0.2, -0.2, -8, -15))]
        return A.merge(arm, *cl)
    if part in ("LeftHorn", "RightHorn"):  # 굽은 얼음 뿔(밑 굵고 끝 뾰족 · 바깥으로 휨)
        return A.tube(A.bezier((0, -sy / 2, 0), (0.05, 0.0, -0.05), (0.25, sy * 0.35, -0.1), (0.35, sy * 0.75, 0.05), n=6), lambda u: 0.24 * (1 - u) + 0.02, sides=6, tip_end=True)
    if part.startswith("Beard"):  # 얼음 고드름 수염(아래로 뾰족)
        n = int(part[-1])
        return A.merge(*[A.crystal(sy * (1.9 - 0.3 * abs(k)), sz * 0.36, sides=5, tip_h=sy * 0.5, base_h=0.05, center=(k * sx * 0.3, -sy * 0.1, 0), m=A.rot(rx=180)) for k in ((-1, 0, 1) if n < 3 else (-0.5, 0.5))])
    if part == "IceClub":  # 깎인 얼음 곤봉(손잡이 → 끝이 굵은 결정 덩어리)
        grip = A.lathe([(0.0, -1.3), (0.14, -1.3), (0.16, -0.4), (0.22, 0.2), (0.0, 0.3)], 8)
        head = A.crystal(1.7, 0.5, sides=6, tip_h=0.5, base_h=0.35, center=(0, 0.75, 0))
        spikes = [A.crystal(0.6, 0.12, sides=4, tip_h=0.2, base_h=0.05, center=(0.4 * math.cos(a), 0.9, 0.4 * math.sin(a)), m=A.rot(rz=-math.degrees(math.cos(a)) * 0.8, rx=math.degrees(math.sin(a)) * 0.8)) for a in (0.5, 2.6, 4.4)]
        return A.merge(grip, head, *spikes)
    return None


def fin_fan(w, h, lobes=3, depth=0.1):
    """부채 지느러미(XY 윤곽 · 끝 물결)"""
    outline = [(0.0, 0.0)]
    for i in range(lobes * 2 + 1):
        a = math.pi * 0.5 * i / (lobes * 2)
        r = h * (1.0 if i % 2 == 0 else 0.78)
        outline.append((w * math.sin(a) * r / h, r * math.cos(a)))
    n = len(outline)
    v = [(x, y, depth / 2) for x, y in outline] + [(x, y, -depth / 2) for x, y in outline]
    f = [tuple(range(n)), tuple(reversed(range(n, 2 * n)))] + [(i, n + i, n + (i + 1) % n, (i + 1) % n) for i in range(n)]
    return v, f


def abyssal_extra(part, j):
    sx, sy, sz = j["size"]
    if part in ("LeftFin", "RightFin"):  # 머리 옆 부채 지느러미
        g = A.xform(fin_fan(0.9, 1.0, 3, 0.1), m=A.rot(ry=90), t=(0, -sy / 2, 0.3))
        return g
    if part == "BackFin":  # 등 지느러미(높게 · 뒤로 휨)
        return A.xform(fin_fan(1.3, 1.4, 4, 0.14), m=A.rot(ry=90, rx=-20), t=(0, -sy / 2, 0.4))
    if part.startswith("Tail") and part[4:].isdigit():
        if part == "Tail6":  # 꼬리 끝 = 두 갈래 지느러미
            return A.merge(chain_seg(j), *[A.xform(fin_fan(0.7, 1.1, 2, 0.12), m=A.rot(rz=180 + s * 30), t=(0, -sy / 2, 0)) for s in (-1, 1)])
        return A.merge(chain_seg(j), A.crystal(0.4, 0.1, sides=4, tip_h=0.15, base_h=0.05, center=(0, 0, sz * 0.5), m=A.rot(rx=90)))
    if part == "Trident":
        return A.lathe([(0.0, -2.1), (0.2, -2.1), (0.24, 0.0), (0.2, 2.1), (0.0, 2.1)], 8)  # 자루 반경 2배
    if part == "TridentHead":  # 세 갈래 창날
        prongs = [A.tube([(x, -0.3, 0), (x * 1.1, 0.35, 0), (x * 0.9, 0.9 + (0.25 if x == 0 else 0), 0)], lambda u: 0.17 * (1 - u) + 0.02, sides=4, flat=0.6, tip_end=True) for x in (-0.6, 0.0, 0.6)]  # 머리 폭 1.5배
        bar = A.tube([(-0.64, -0.3, 0), (0, -0.45, 0), (0.64, -0.3, 0)], 0.15, sides=5)
        return A.merge(bar, *prongs)
    return None


def crystal_extra(part, j):
    sx, sy, sz = j["size"]
    if part.startswith("Skirt"):  # 수정 치마 판: 위 좁고 아래로 퍼지며 끝이 뾰족(끝 마디 = 결정)
        tip = part.endswith("2")
        rings = [[(x, y, z * 0.35) for x, z in A.chamfer_rect(w, sz, 0.08)] for y, w in ((sy / 2, sx * 0.85), (-sy / 2, sx * 1.05))]
        g = A.loft(rings, tip1=(0, -sy / 2 - (0.45 if tip else 0.0), 0)) if tip else A.loft(rings)
        return g
    if part == "Crown":  # 가시 왕관(리그 cyl 회전 90° - 로컬 X가 위)
        ring = A.lathe([(0.34, -0.12), (0.4, -0.12), (0.4, 0.1), (0.34, 0.1)], 12, axis="X")
        spikes = [A.xform(A.crystal(0.55 if k % 2 == 0 else 0.35, 0.09, sides=4, tip_h=0.2, base_h=0.04), m=A.rot(rz=-90), t=(0.2 + (0.2 if k % 2 == 0 else 0.1), 0.37 * math.cos(2 * math.pi * k / 6), 0.37 * math.sin(2 * math.pi * k / 6))) for k in range(6)]
        return A.merge(ring, *spikes)
    if part in ("LeftShard", "RightShard"):  # 등 수정 날개 = 큰 결정 + 작은 결정
        return A.merge(A.crystal(sy * 1.3, sx * 0.55, sides=5, tip_h=0.5, base_h=0.15, center=(0, 0.1, 0)), A.crystal(sy * 0.7, sx * 0.35, sides=5, tip_h=0.3, base_h=0.1, center=(0.25, -0.2, 0.1), m=A.rot(rz=-25)))
    if part == "Scepter":
        return A.merge(A.lathe([(0.0, -1.2), (0.15, -1.2), (0.17, 1.0), (0.28, 1.1), (0.0, 1.2)], 8))  # 홀 자루 2배
    if part == "ScepterGem":
        return A.crystal(0.7, 0.25, sides=6, tip_h=0.25, base_h=0.2)
    return None


def storm_extra(part, j):
    sx, sy, sz = j["size"]
    if part in ("LeftBlade", "RightBlade"):  # A2-N2: 어깨 번개 파편 = 위로 솟는 큰 지그재그 번개 2 + 작은 파편 1(노랑 · 정면 실루엣을 어깨 밖으로 키움)
        side = -1 if part == "LeftBlade" else 1
        big = A.xform(bolt_shape(2.3, 0.62, 0.2), m=A.rot(rz=-side * 18), t=(0, -sy * 0.35, 0))
        small = A.xform(bolt_shape(1.2, 0.38, 0.16), m=A.rot(rz=-side * 48), t=(side * 0.18 * 0 + 0.3, -sy * 0.5, 0.15))
        return A.merge(big, small)
    if part.startswith("Cape"):  # 망토: A2-N2 = 날개처럼 펼침(밑 폭 ≈ 어깨의 2.2배) · 끝 마디는 번개 모양으로 찢어진 끝
        last = part.endswith("3")
        idx = int(part[-1])
        spread = {1: (1.0, 1.35), 2: (1.35, 1.85), 3: (1.85, 2.45)}[idx]
        sgn = -1 if part.startswith("CapeL") else 1
        shift = sgn * (0.5 * (idx - 1))
        rings = [[(x + shift + sgn * 0.5 * k_, y, z * 0.18 + 0.12 * (idx - 1 + k_)) for x, z in A.chamfer_rect(w, sz, 0.05)] for k_, (y, w) in enumerate(((sy / 2, sx * spread[0]), (-sy / 2, sx * spread[1])))]
        g = A.loft(rings)
        if last:  # 찢어진 끝 = 아래로 뾰족한 삼각 3개(번개 톱니)
            x0 = shift + sgn * 0.5
            g = A.merge(g, *[A.xform(A.lathe([(0.0, 0.0), (sx * 0.34, 0.0), (0.0, -0.55 - 0.2 * (k % 2))], 4), s=(1, 1, 0.3), t=(x0 + (k - 1) * sx * 0.7, -sy / 2, 0.36)) for k in range(3)])
        return g
    if part == "Staff":  # 비틀린 지팡이 + 끝 갈고리
        rings = [[(x, y, z) for x, z in A.circle2d(0.26 - 0.04 * k / 6, 5, start=k * 0.5)] for k, y in enumerate([-2.3 + 4.6 * i / 6 for i in range(7)])]  # 자루 2배
        hook = A.tube([(0, 2.2, 0), (0.35, 2.55, 0), (0.1, 2.85, 0), (-0.3, 2.6, 0)], lambda u: 0.12 * (1 - u) + 0.03, sides=5, tip_end=True)
        return A.merge(A.loft(rings), hook)
    if part == "StaffOrb":  # 구슬 + 번개 고리 + 떠 있는 번개 파편 3(A2-N2)
        return A.merge(A.ellipsoid((sx / 2, sy / 2, sz / 2), n=12, rings=7),
                       *[A.xform(bolt_shape(0.8, 0.28, 0.12), m=A.rot(rz=dz_), t=(dx_, dy_, 0.1)) for dx_, dy_, dz_ in ((-1.35, 0.45, 30), (1.4, 0.25, -35), (0.1, 1.35, 0))],  # 2차: 파편 +0.6 벌림(어깨 번개와 겹쳐 붐볐다)
                       A.tube([(0.55 * math.cos(a), 0.12 * math.sin(3 * a), 0.55 * math.sin(a)) for a in (2 * math.pi * i / 12 for i in range(13))], 0.05, sides=4, cap0=False))
    return None


def scorpion_shape(part, j):
    sx, sy, sz = j["size"]
    if part == "Body":  # 마디 등딱지(가운데 볼록 · 뒤로 좁게) - 몸 1.4배(파트 크기보다 크게)
        sx, sy, sz = sx * 1.4, sy * 1.4, sz * 1.25
        segs = []
        for k in range(4):
            z0, z1 = -sz / 2 + sz * k / 4, -sz / 2 + sz * (k + 1) / 4
            w = sx * (1.0 - 0.08 * k)
            segs.append(A.loft([[(x, y, z) for x, y in A.chamfer_rect(w * s, sy * s, 0.3)] for z, s in ((z0, 0.92), (z0 + 0.1, 1.0), (z1 - 0.04, 0.97))]))
        return A.merge(*segs)
    if part == "Head":  # 왕관 달린 머리
        head = A.loft([[(x, y, z) for x, y in A.chamfer_rect(w, sy, 0.18)] for z, w in ((sz / 2, sx * 0.95), (0, sx), (-sz / 2, sx * 0.7))])
        crown = [A.crystal(0.75 if k == 0 else 0.5, 0.13, sides=4, tip_h=0.15, base_h=0.04, center=(0.3 * k, sy * 0.5, 0.1), m=A.rot(rz=-15 * k)) for k in (-1, 0, 1)]
        return A.merge(head, *crown)
    if part in ("Eyes", "Mouth"):
        return biped_generic(part, j, {})
    if part.startswith("Thigh"):
        return taper_seg(sx * 1.6, sy, sz * 1.6, 0.8, 0.08)
    if part.startswith("Shin"):  # 끝이 뾰족한 다리(1.5배 굵게)
        return A.loft([[(x, y, z) for x, z in A.circle2d(sx / 2 * k * 1.5, 6)] for y, k in ((sy / 2, 1.0), (0.1, 1.1), (-sy / 2 + 0.3, 0.55))], tip1=(0, -sy / 2, 0))
    if part.startswith("UpperArm") or part.startswith("Forearm"):
        return taper_seg(sx, sy, sz, 0.85, 0.1)
    if part.startswith("Hand"):  # 집게 몸통(두툼) + 고정 날 - A2-N2: ×1.4(여왕 실루엣 = 큰 집게)
        sx, sy, sz = sx * 1.4, sy * 1.4, sz * 1.4
        palm = A.ellipsoid((sx * 0.6, sy * 0.55, sz * 0.7), n=10, rings=6)
        fixed = A.tube(A.bezier((sx * 0.2, -sy * 0.3, 0), (sx * 0.35, -sy * 0.7, 0), (sx * 0.1, -sy * 1.0, 0), (-sx * 0.1, -sy * 1.05, 0), n=5), lambda u: 0.2 * (1 - u) + 0.03, sides=5, tip_end=True)
        return A.merge(palm, fixed)
    if part.startswith("Pincer"):  # 움직이는 날(휜 칼날) ×1.4
        sy = sy * 1.4
        return A.tube(A.bezier((0, sy / 2, 0), (-0.15, 0.0, 0), (-0.05, -sy * 0.4, 0), (0.15, -sy / 2, 0), n=5), lambda u: 0.2 * (1 - u) + 0.02, sides=5, tip_end=True)
    if part.startswith("Tail"):
        last = part.endswith("_8")
        if last:  # 독침(발광)
            return A.merge(A.ellipsoid((sx * 0.6, sy * 0.4, sz * 0.6), n=8, rings=5), A.tube(A.bezier((0, -0.1, 0), (0, -0.4, 0), (0, -0.6, -0.15), (0, -0.62, -0.35), n=4), lambda u: 0.12 * (1 - u) + 0.01, sides=5, tip_end=True))
        seg = chain_seg(j)
        if part.startswith("Tail2_"):  # 가운데 꼬리만 1.5배 굵게(주인공 꼬리)
            seg = A.xform(seg, s=(1.5, 1.0, 1.5))
        return A.merge(seg, A.crystal(0.24, 0.06, sides=4, tip_h=0.1, base_h=0.03, center=(0, 0, sz * 0.5 * (1.5 if part.startswith("Tail2_") else 1)), m=A.rot(rx=90)))
    return None


def body_decor(boss, part, j):
    """보스별 몸 장식(Body · Hips 메시에 합친다 - 파트 수 그대로): 수호자와 다른 실루엣 한 겹"""
    sx, sy, sz = j["size"]
    out = []
    if boss == "frost_giant" and part == "Body":
        for s in (-1, 1):  # 어깨 얼음 가시 3
            out += [A.crystal(h, r_, sides=6, tip_h=h * 0.35, base_h=0.12, center=(s * (sx * 0.62 - 0.2 * k), sy * 0.5 + h * 0.25, 0.12 * k - 0.08), m=A.rot(rz=-s * (12 + 14 * k), rx=8 * k))
                    for k, (h, r_) in enumerate(((1.25, 0.34), (0.95, 0.26), (0.7, 0.2)))]  # 얼음 어깨 덩어리(가장 큰 결정 = 머리 높이의 1.2배)
        out += [A.ellipsoid((0.3, 0.22, 0.3), n=8, rings=4, center=(0.42 * math.cos(a), sy * 0.5 + 0.02, 0.4 * math.sin(a) * 0.9)) for a in (2 * math.pi * i / 7 for i in range(7))]  # 털 깃
    if boss == "frost_giant" and part == "Hips":
        out += [A.ellipsoid((0.28, 0.24, 0.26), n=8, rings=4, center=(sx * 0.55 * math.cos(a), -0.05, sz * 0.55 * math.sin(a))) for a in (2 * math.pi * i / 8 for i in range(8))]  # 털 허리띠
    if boss == "abyssal_lord" and part == "Body":
        for s in (-1, 1):  # 조개 어깨(골 파인 반구)
            shell = A.ellipsoid((0.7, 0.42, 0.72), n=12, rings=5, center=(s * sx * 0.48, sy * 0.46, 0), squash_bottom=0.2)
            ribs = [A.tube([(s * sx * 0.48 + 0.55 * math.cos(a), sy * 0.46, 0.55 * math.sin(a)), (s * sx * 0.48, sy * 0.46 + 0.45, 0)], 0.06, sides=4) for a in (0.4, 1.3, 2.2, 3.1, 4.0, 5.0)]
            out += [shell] + ribs
        out += [A.ellipsoid((0.26, 0.2, 0.08), n=8, rings=3, center=(x, y, -sz * 0.55)) for y in (sy * 0.15, -sy * 0.05, -sy * 0.25) for x in (-0.36, 0.0, 0.36)]  # 가슴 비늘 판
    if boss == "abyssal_lord" and part == "Hips":  # 촉수 치마: 굵은 촉수 7이 아래로 퍼져 끝이 말림(밑 폭 = 어깨의 1.3배)
        for k in range(7):
            a = math.pi * (0.1 + 0.8 * k / 6) + math.pi
            dx, dz = math.cos(a), math.sin(a) * 0.9
            path = [(dx * 0.55, 0.0, dz * 0.45), (dx * 1.1, -0.7, dz * 0.8), (dx * 1.55, -1.3, dz * 1.1), (dx * 1.75, -1.45, dz * 1.2 - 0.25)]
            out.append(A.tube(A.bezier(*path, n=5), lambda u: 0.26 * (1 - u) + 0.07, sides=6, tip_end=True))
    if boss == "abyssal_lord" and part == "Body":  # 등 소라 껍데기(뒤로 튀어나온 나선 원뿔)
        cone = A.lathe([(0.0, -0.7), (0.75, -0.55), (0.8, -0.2), (0.55, -0.1), (0.6, 0.2), (0.35, 0.3), (0.38, 0.55), (0.0, 0.95)], 10)
        out.append(A.xform(cone, m=A.rot(rx=-60), t=(0, sy * 0.1, sz * 0.62)))
    if boss == "storm_lord" and part == "Body":
        collar = [A.xform(A.box(0.5, 1.0, 0.12, b=0.04), m=A.rot(rx=-25, rz=s * 30), t=(s * 0.45, sy * 0.62, 0.2)) for s in (-1, 1)]  # 높은 깃
        rune = A.xform(zigzag_bolt(), t=(0, 0.1, -sz * 0.55))
        out += collar + [rune]
    if boss == "storm_lord" and part == "Head":  # A2-N2: 후드 위로 뒤로 휜 큰 뿔 2(머리 높이의 1.3배 - 먹색 덩어리 위 실루엣)
        for sgn in (-1, 1):
            out.append(A.tube(A.bezier((sgn * 0.3, sy * 0.25, 0.0), (sgn * 0.62, sy * 0.7, 0.1), (sgn * 0.8, sy * 1.15, 0.45), (sgn * 0.75, sy * 1.7, 0.8), n=6),
                              lambda u: 0.27 * (1 - u) + 0.03, sides=6, tip_end=True))
    if boss == "crystal_queen" and part == "Body":
        for s in (-1, 1):
            out += [A.crystal(0.6, 0.14, sides=5, tip_h=0.22, base_h=0.05, center=(s * sx * 0.48, sy * 0.52, 0), m=A.rot(rz=-s * 30))]
        out += [A.crystal(0.45, 0.18, sides=6, tip_h=0.16, base_h=0.14, center=(0, sy * 0.15, -sz * 0.55), m=A.rot(rx=90))]  # 가슴 보석
    return out


def bolt_shape(h, w, d):
    """세운 지그재그 번개(아래 = 원점 · 위로 h) - 두께 d"""
    pts = [(0.0, 0.0), (w * 0.55, h * 0.45), (w * 0.05, h * 0.5), (w * 0.6, h)]
    outline = [(x + w * 0.22, y) for x, y in pts[1:]] + [(x - w * 0.22, y) for x, y in reversed(pts[:-1])]
    outline = [pts[0]] + outline
    n = len(outline)
    v = [(x, y, d / 2) for x, y in outline] + [(x, y, -d / 2) for x, y in outline]
    return v, [tuple(range(n)), tuple(reversed(range(n, 2 * n)))] + [(i, n + i, n + (i + 1) % n, (i + 1) % n) for i in range(n)]


def zigzag_bolt():
    pts = [(0.0, 0.45), (0.22, 0.1), (-0.05, 0.05), (0.18, -0.4)]
    outline = [(x + 0.1, y) for x, y in pts] + [(x - 0.1, y) for x, y in reversed(pts)]
    n = len(outline)
    v = [(x, y, 0.06) for x, y in outline] + [(x, y, -0.06) for x, y in outline]
    return v, [tuple(range(n)), tuple(reversed(range(n, 2 * n)))] + [(i, n + i, n + (i + 1) % n, (i + 1) % n) for i in range(n)]


def make_shape(boss, part, j):
    if boss == "scorpion_queen":
        g = scorpion_shape(part, j)
    else:
        extra = {"frost_giant": frost_extra, "abyssal_lord": abyssal_extra, "crystal_queen": crystal_extra, "storm_lord": storm_extra}[boss]
        g = extra(part, j)
        if g is None:
            g = biped_generic(part, j, STYLE[boss])
        deco = body_decor(boss, part, j)
        if g is not None and deco:
            g = A.merge(g, *deco)
    return g if g is not None else old_shape(j)


STYLE = {"frost_giant": dict(shoulders=1.45, waist=0.8, head="helm", fist=1.3), "abyssal_lord": dict(shoulders=1.12, waist=0.8, head="helm", fist=1.05),
         "crystal_queen": dict(shoulders=1.0, waist=0.62, head="round", fist=0.9, robe=0.35), "storm_lord": dict(shoulders=1.05, waist=0.7, head="hood", fist=0.95, robe=0.55)}


SHAPES = {"section_guardian": guardian_shape}
for _b in STYLE.keys() | {"scorpion_queen"}:
    SHAPES[_b] = (lambda b_: (lambda part, j: make_shape(b_, part, j)))(_b)
OUTLINE_PARTS = {"section_guardian": ["Body", "Head", "UpperArm_L", "UpperArm_R", "Forearm_L", "Forearm_R", "Hand_L", "Hand_R", "LeftPauldron", "RightPauldron"],
                 # A2-N2: 상한 40 → 두 발 보스 5종 모두 큰 덩어리 10개(균형) · 전갈 여왕 = 리그 48(예외 상한) → 껍데기 0 · Highlight 유지
                 "frost_giant": ["Body", "Head", "Hips", "UpperArm_L", "UpperArm_R", "Hand_L", "Hand_R", "Thigh_L", "Thigh_R", "IceClub"],
                 "abyssal_lord": ["Body", "Head", "Hips", "UpperArm_L", "UpperArm_R", "Forearm_L", "Forearm_R", "Hand_L", "Hand_R", "BackFin"],
                 "crystal_queen": ["Body", "Head", "Hips", "SkirtF1", "SkirtB1", "SkirtL1", "SkirtR1", "LeftShard", "RightShard", "Crown"],
                 "storm_lord": ["Body", "Head", "Hips", "UpperArm_L", "UpperArm_R", "LeftBlade", "RightBlade", "CapeL3", "CapeR3", "Staff"]}


def load_detail(boss):
    """A2-M1 디테일(새 관절 · 장식 · 부위 색) - rigs/boss_detail.json(detail_dump.py)"""
    if not os.path.exists(DETAIL_JSON):
        return None
    data = json.load(io.open(DETAIL_JSON, encoding="utf-8"))
    return data.get(boss)


def deco_groups(det, rig, world):
    """A2-N3 결정 ③(--merge-deco): 움직이지 않는 장식을 붙은 몸 파트 메시에 합친다. 부모와 색 역할 · 재질이 같은 장식 = 부모 메시에 합침,
    다른 장식 = (부모 · 색 · 재질 · LOD)마다 한 덩어리 <부모>_Deco<n>(색 · 네온 보존 - 게임은 부모 부위에 용접). 관절이 있는 것(망토 · 꼬리 · 떠 있는 결정 = detail 관절)은 그대로 따로."""
    joint_of = {j["part"]: j for j in rig["joints"]}
    into, groups = {}, {}
    for d in det["deco"]:
        P = world.get(d["parent"])
        if P is None:
            continue
        W = P @ Matrix.Translation(V(d["at"])) @ angles(tuple(d["rot"]) if d.get("rot") else None)
        geo = A.xform(old_shape({"size": d["size"], "shape": d.get("shape", "block")}), m=W.to_3x3(), t=tuple(W.translation))
        jp = joint_of.get(d["parent"], {})
        mat = d.get("material") or "SmoothPlastic"
        if d["color"] == jp.get("color") and mat == (jp.get("material") or "SmoothPlastic"):
            into.setdefault(d["parent"], []).append(geo)
        else:
            groups.setdefault((d["parent"], d["color"], mat, int(d.get("lod", 1))), []).append(geo)
    return into, groups


def build(boss, old=False, hull=True, detail=True, merge_deco=False):
    rig = RIGS[boss]()
    det = load_detail(boss) if (detail and not old) else None
    if det:
        for j in det["joints"]:
            rig["joints"].append(dict(name=j["name"], parent=j["parent"], part=j["part"], size=tuple(j["size"]), shape=j.get("shape", "block"), color=j["color"],
                                      material=j.get("material"), at=tuple(j["at"]), pivot=tuple(j["pivot"]), rot=tuple(j["rot"]) if j.get("rot") else None, detail=True))
        for j in rig["joints"]:
            if j["part"] in det.get("recolor", {}):
                j["color"] = det["recolor"][j["part"]]
    world, jpos = fk(rig["joints"])
    col = A.new_collection(("old_" if old else "") + boss)
    objs, hulls = [], []
    into, groups = deco_groups(det, rig, world) if (det and merge_deco) else ({}, {})
    for j in rig["joints"]:
        part = j["part"]
        local = old_shape(j) if (old or j.get("detail")) else SHAPES[boss](part, j)
        W = world[part]
        R = W.to_3x3()
        t = W.translation
        geo = A.xform(local, m=R, t=tuple(t))
        if into.get(part):
            geo = A.merge(geo, *into[part])
        o = A.make_obj(part, geo, color_of(j["color"], rig), col, neon=j.get("material") == "Neon", origin=jpos[part],
                       bevel=0.0, mat_name="%s%s_%s" % ("old_" if old else "", boss, part))
        o["Joint"] = j["name"]
        objs.append(o)
        if hull and not old and part in OUTLINE_PARTS.get(boss, []):
            hulls.append(A.add_hull(o, thickness=0.06, export=True, col=col))
    # A2-M1 장식(관절 없음 - 게임에서는 부모 부위에 용접): 이름 · 크기 · 자리 = BossDetailSpec 그대로 · 원점 = 장식 가운데
    if det and merge_deco:
        count = {}
        for (parent, color, mat, lod), geos in sorted(groups.items()):
            count[parent] = count.get(parent, 0) + 1
            name = "%s_Deco%d" % (parent, count[parent])
            o = A.make_obj(name, A.merge(*geos), color_of(color, rig), col, neon=mat == "Neon", origin=jpos[parent], bevel=0.0, mat_name="%s_%s" % (boss, name))
            o["Deco"] = parent
            o["DetailLod"] = lod
            o["DecoMaterial"] = mat
            objs.append(o)
    elif det:
        for d in det["deco"]:
            P = world.get(d["parent"])
            if P is None:
                continue
            W = P @ Matrix.Translation(V(d["at"])) @ angles(tuple(d["rot"]) if d.get("rot") else None)
            geo = A.xform(old_shape({"size": d["size"], "shape": d.get("shape", "block")}), m=W.to_3x3(), t=tuple(W.translation))
            o = A.make_obj(d["name"], geo, color_of(d["color"], rig), col, neon=d.get("material") == "Neon", origin=tuple(W.translation),
                           bevel=0.0, mat_name="%s_%s" % (boss, d["name"]))
            o["Deco"] = d["parent"]
            o["DetailLod"] = int(d.get("lod", 1))
            objs.append(o)
    return rig, col, objs, hulls


def parse():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opt = {"bosses": [], "render": None, "export": True, "old": False, "merge": False}
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
        elif a == "--merge-deco":
            opt["merge"] = True
        i += 1
    return opt


def main():
    opt = parse()
    for boss in opt["bosses"]:
        A.reset()
        rig, col, objs, hulls = build(boss, merge_deco=opt["merge"])
        allo = objs + hulls
        total = sum(A.tri_count(o) for o in allo)
        cap = PART_CAP_OF.get(boss, PART_CAP)
        budget = BUDGET_OF.get(boss, BUDGET)
        assert len(allo) <= cap, (boss, len(allo), cap)
        print("[make_boss] %s 파트 %d(+외곽선 %d = %d / %d) · 삼각형 %d(외곽선 포함) / %d = %.0f%% · %s" % (boss, len(objs), len(hulls), len(allo), cap, total, budget, 100 * total / budget,
                                                                                         {o.name: A.tri_count(o) for o in objs}))
        if opt["export"]:
            A.export_fbx(os.path.join(OUT, "%s.fbx" % boss), allo)
            meta = A.meta_of(allo, budget, {"version": "A2-M1", "rigId": boss, "partCap": cap,
                                            "themeColors": {k: list(rig[k]) for k in ("body", "head", "accent")}, "joints": {o.name: o["Joint"] for o in objs if "Joint" in o},
                                            "deco": {o.name: o["Deco"] for o in objs if "Deco" in o}, "decoMaterial": {o.name: o["DecoMaterial"] for o in objs if "DecoMaterial" in o}, "mergedDeco": opt["merge"], "lod2": [o.name for o in objs if o.get("DetailLod") == 2],
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
