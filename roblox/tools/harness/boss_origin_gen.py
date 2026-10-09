"""BOSS-NIGHT-2 3: boss_origin_dump.luau 출력(ORG 줄) → roblox/src/shared/data/BossOriginData.lua.
사용: python roblox/tools/harness/boss_origin_gen.py <origin.txt>
"""
import io
import json
import math
import os
import sys

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "src", "shared", "data", "BossOriginData.lua")
rows = {}
for line in io.open(sys.argv[1], encoding="utf-8"):
    if not line.startswith("ORG\t"):
        continue
    _, rig, sid, form, kind, x, y, z, parts, t = line.rstrip("\n").split("\t")
    rows.setdefault(rig, {}).setdefault(sid, {"kind": kind, "parts": parts, "t": t})[form] = (float(x), float(y), float(z))
# Studio 실측 보정(boss_origin_tune.json - stud): 리그 단위 = stud ÷ k(k = 그 스킬의 FK 수평 거리 대비 Studio 지점 거리 - 보정 파일의 pf/pr 대신 크기 표 KSCALE)
TUNE = json.load(io.open(os.path.join(os.path.dirname(__file__), "boss_origin_tune.json"), encoding="utf-8"))
KSCALE = json.load(io.open(os.path.join(os.path.dirname(__file__), "boss_origin_k.json"), encoding="utf-8"))
for rig in rows:
    for sid, e in rows[rig].items():
        # BOSS-NIGHT-2 A: "rig/skill@after" = 그 폼만의 보정(2폼 = 다른 부위로 때림 - 폭풍 주먹)
        for key, only in ((f"{rig}/{sid}", None), (f"{rig}/{sid}@before", "before"), (f"{rig}/{sid}@after", "after")):
            t = TUNE.get(key)
            if not t:
                continue
            k = KSCALE[rig]
            for f in ([only] if only else t.get("forms", ["before", "after"])):
                if f in e:
                    x, y, z = e[f]
                    e[f] = (x + t["right"] / k, y, z - t["fwd"] / k)
            e["tuned"] = e.get("tuned", 0) + t.get("n", 0)
out = ["-- BOSS-NIGHT-2 3 발생 지점 표(자동 생성 - tools/harness/boss_origin_dump.luau → boss_origin_gen.py · 손으로 고치지 말 것)",
       "-- [리그][스킬] = { kind = \"ground\"(그 부위 아래 바닥 - 파동 · 균열선 · 지면 투사체) | \"launch\"(부위 가운데 - 투사체), part = 부위, contact = 접촉 프레임(초 · 동작 시작부터),",
       "--   before / after = { x(오른쪽), y(지면 위), z(앞 = −) } 리그 단위 = 접촉 프레임의 보스 루트 기준 오프라인 FK + Studio 실측 보정(tuned = 표본 수 · boss_origin_tune.json) } · 월드 = × 크기(sizeScale × rig.scale) · 대상 쪽 방향으로 돌림(shared/BossOrigin)",
       "-- 서버는 애니메이션을 재생하지 않아 부위 자리를 그 프레임에 읽을 수 없다(②안) - 클라 그림도 서버가 보낸 같은 자리를 쓴다(예고 = 판정 = 이펙트).",
       "return {"]
for rig in sorted(rows):
    out.append(f"\t{rig} = {{")
    for sid in sorted(rows[rig]):
        e = rows[rig][sid]
        forms = " ".join(f"{f} = {{ {e[f][0]:.3f}, {e[f][1]:.3f}, {e[f][2]:.3f} }}," for f in ("after", "before") if f in e)
        tuned = f" tuned = {e['tuned']}," if e.get("tuned") else ""
        out.append(f"\t\t{sid} = {{ kind = \"{e['kind']}\", part = \"{e['parts']}\", contact = {e['t']},{tuned} {forms} }},")
    out.append("\t},")
out.append("}")
io.open(OUT, "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
print("wrote", os.path.normpath(OUT), sum(len(v) for v in rows.values()), "skills")
