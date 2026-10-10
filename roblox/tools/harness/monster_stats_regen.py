# PROG-2B-1: 몹 스탯 골든 표 다시 뽑기(의도한 변경 뒤에만 - 몹 기준 함수 · 체력 눈금). monster_stats_test.luau의 GOLDEN_LINES 키 그대로 지금 코드 값을 뽑아
#   ① 옛 값 대비 비율을 키 종류별로 요약(의도한 계수와 맞는지 눈으로 확인 - 기대 = hp 키 × 계수(스테이지) · atk 키 × 체력 눈금) ② --write면 테스트 · golden.txt를 새 값으로 바꾼다.
# 사용: LUAU=<luau.exe> python monster_stats_regen.py [--write]
import io, os, re, subprocess, sys
SP = os.path.dirname(os.path.abspath(__file__))
TEST = os.path.join(SP, "monster_stats_test.luau")
GOLD = os.path.join(SP, "monster_stats_golden.txt")
src = io.open(TEST, encoding="utf-8").read()
m = re.search(r"GOLDEN_LINES = \{\n(.*?)\n\}\n", src, re.S)
old = [l.strip().strip('",') for l in m.group(1).split("\n")]
keys = [l.split("|")[1] for l in old]
oldv = {l.split("|")[1]: l.split("|")[2] for l in old}
body = 'KEYS = {%s}\n' % ",".join('"%s"' % k for k in keys) + r'''
local MS, MD, BR, BS, PD = MODS.MonsterStats, MODS.MonsterData, MODS.BossRules, MODS.BalanceSim, MODS.MonsterPrefixData
local prefixById = {}
for _, p in ipairs(PD.prefixes) do prefixById[p.id] = p end
ATTR.All10Economy = false
for _, k in ipairs(KEYS) do
	local got
	local parts = string.split(k, ".")
	if parts[1] == "trash" and #parts == 4 then
		local st = MS.trash(MD[parts[3]], tonumber(parts[4]))
		got = parts[2] == "hp" and st.hp or st.attack
	elseif parts[1] == "trash" and #parts == 5 then
		got = MS.trash(MD[parts[3]], tonumber(parts[5]), prefixById[parts[4]]).hp
	elseif parts[1] == "sim" then
		local s = tonumber(parts[4])
		got = parts[2] == "hp" and BS.getMonsterHp(s, parts[3]) or BS.getMonsterAttack(s, parts[3])
	elseif parts[1] == "boss" then
		local d0 = BR.buildInstanceData(tonumber(parts[5]), parts[3], tonumber(parts[4]))
		got = parts[2] == "hp" and d0.hp or d0.attack
	elseif parts[1] == "tutorial" then
		local d0 = BR.buildTutorialInstanceData(3, tonumber(parts[3]), {}, 0.5, 1.2)
		got = parts[2] == "hp" and d0.hp or d0.attack
	end
	print(("G|%s|%.17g"):format(k, got))
end
'''
out = os.environ.get("TEMP", ".")
tf = os.path.join(out, "mstat_regen.luau")
io.open(tf, "w", encoding="utf-8", newline="\n").write(body)
env = dict(os.environ, PRELUDE="server_prelude.luau", ECON_RES="res_mstat_regen.txt", ECON_OUT="out_mstat_regen.luau")
subprocess.run([sys.executable, os.path.join(SP, "build_run.py"), tf], env=env, cwd=SP, check=True)
res = io.open(os.path.join(out, "res_mstat_regen.txt"), encoding="utf-8").read()
new = [l for l in res.split("\n") if l.startswith("G|")]
assert len(new) == len(keys), "값 수 %d ≠ %d - %s" % (len(new), len(keys), res[-500:])
# 비율 요약(키 종류 × 스테이지 → 최소 · 최대)
summ = {}
for l in new:
    _, k, v = l.split("|")
    p = k.split(".")
    kind = p[0] + "." + p[1]
    s = int(p[-1])
    r = float(v) / float(oldv[k]) if float(oldv[k]) != 0 else float("nan")
    a = summ.setdefault((kind, s), [r, r])
    a[0], a[1] = min(a[0], r), max(a[1], r)
for (kind, s), (lo, hi) in sorted(summ.items()):
    print("%-12s s%-6d 새/옛 %.6f ~ %.6f" % (kind, s, lo, hi))
if "--write" in sys.argv:
    lines = "\n".join('\t"%s",' % l for l in new)
    src2 = src[:m.start(1)] + lines + src[m.end(1):]
    io.open(TEST, "w", encoding="utf-8", newline="\n").write(src2)
    io.open(GOLD, "w", encoding="utf-8", newline="\n").write("\n".join(new) + "\n")
    print("썼다: %d값" % len(new))
