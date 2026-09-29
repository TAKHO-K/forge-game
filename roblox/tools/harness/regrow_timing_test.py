# QUEUE-B1 결정 12 추가 확인: 재생성 파트가 프레임 장부 때문에 최대 spawnWaitMaxFrames 늦게 솟을 때 피해 판정이 실제 구조물 등장 시점에 맞는가.
# 실제 코드를 그대로 잘라 쓴다: BossArenaMap.lua의 프레임 장부(frameId ~ runInFrameBudget) + BossArenaMapData.regrow 수치 + BossPatterns.lua의 솟기 순서.
# 실행: LUAU=<luau.exe> python regrow_timing_test.py  → 결과 줄 [REGROW] … O/X · 끝 n/m
import io, os, re, subprocess, sys, tempfile
sys.stdout.reconfigure(encoding="utf-8")

SP = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(SP, "..", "..", "src")
LUAU = os.environ.get("LUAU", os.path.join(SP, "luau", "luau.exe"))

def read(rel):
    return io.open(os.path.join(SRC, rel), encoding="utf-8").read()

arena = read("server/BossArenaMap.lua")
a = arena.index("local frameId, frameUsed, frameUsedId, frameUsedPeak = 0, 0, 0, 0")
b = arena.index("-- 검증용: 나눠 도는 계산이 한 프레임에 쓴 합의 최댓값")
ledger = arena[a:b]
data = read("shared/data/BossArenaMapData.lua")
patterns = read("server/BossPatterns.lua")

results = []
def check(label, ok, detail=""):
    results.append((label, ok, detail))

# 1) 정적 순서: 솟기(spawnRegrown) → 피해 판정(applySkillDamage REGROW_SKILL) → 연출 신호(regrowSpawn) - 판정이 파트보다 먼저 오지 않는다
i_spawn = patterns.find("BossArenaMap.spawnRegrown(zoneKey, plan, context)")
i_judge = patterns.find("applySkillDamage(model, data, REGROW_SKILL, v.player)")
i_fx = patterns.find('send(st, "regrowSpawn"')
check("BossPatterns 순서: 파트 생성 → 피해 판정 → 연출 신호", 0 <= i_spawn < i_judge < i_fx, "위치 %d < %d < %d" % (i_spawn, i_judge, i_fx))
# 판정 대상 위치(v.feet)는 파트가 생긴 뒤(spawnRegrown 반환 뒤) 읽는다
i_contact = patterns.find("BossArenaMap.colliderContact(obstacle, v.feet, half)")
check("접촉 판정 = 파트 생성 뒤의 발 위치", i_spawn < i_contact < i_judge, "위치 %d < %d < %d" % (i_spawn, i_contact, i_judge))

luau = r'''
-- 데이터 파일이 부르는 Roblox 전역 대역(값은 안 쓴다 - regrow 수치만 읽는다)
local P
P = setmetatable({}, { __index = function() return P end, __call = function() return P end })
local game, require, Color3, Vector3, Enum, NumberRange = P, function() return P end, P, P, P, P
local REGROW = (function()
%s
end)().regrow
local connected = {}
local frameNow = 0
local RunService = { Heartbeat = {
	Connect = function(_, fn) table.insert(connected, fn); return { Disconnect = function() end } end,
	Wait = function() frameNow += 1; for _, fn in ipairs(connected) do fn() end; return 1 / 60 end,
} }
local BossArenaMap = {}
%s
local out = {}
local function check(label, ok, detail) table.insert(out, ("[REGROW] %%s %%s %%s"):format(label, detail or "", ok and "O" or "X")) end
-- 다른 아레나들이 매 프레임 장부를 채우는 상황(12아레나 동시 - 최악): fillFrames 동안 프레임마다 예산 전부를 먼저 쓴다
local function scenario(fillFrames)
	local filler = 0
	table.insert(connected, function()
		if filler < fillFrames then
			filler += 1
			addFrameUsed(REGROW.frameBudgetMs / 1000) -- 이 프레임의 나눠 도는 계산이 예산을 다 씀
		end
	end)
	RunService.Heartbeat:Wait() -- 새 프레임
	local telegraphEnd = frameNow -- 전조가 끝난 프레임(BossPatterns: remain 대기 끝 = 솟으려는 순간)
	local createdAt, judgedAt
	local obstacle = runInFrameBudget(function()
		createdAt = frameNow -- spawnObstacle: 파트가 여기서 생긴다
		return { id = 1 }
	end)
	judgedAt = obstacle and frameNow -- BossPatterns: spawnRegrown이 돌려준 뒤 같은 스레드에서 바로 접촉 · 피해 판정
	table.remove(connected)
	return telegraphEnd, createdAt, judgedAt
end
for _, fill in ipairs({ 0, 1, 2, 3, 10 }) do
	local t, c, j = scenario(fill)
	local late = c - t
	check(("장부 %%d프레임 차 있음: 전조 끝 %%d · 파트 생성 %%d(+%%d) · 판정 %%d"):format(fill, t, c, late, j),
		j == c and late >= 0 and late <= REGROW.spawnWaitMaxFrames and late == math.min(fill, REGROW.spawnWaitMaxFrames))
end
check(("늦음 상한 %%d프레임 ≈ %%.3f초(60fps) < 전조 %%.1f초의 5%%%%"):format(REGROW.spawnWaitMaxFrames, REGROW.spawnWaitMaxFrames / 60, REGROW.telegraphSeconds),
	REGROW.spawnWaitMaxFrames / 60 <= REGROW.telegraphSeconds * 0.05)
for _, line in ipairs(out) do print(line) end
''' % (data, ledger)

tmp = os.path.join(tempfile.gettempdir(), "regrow_timing_test_out.luau")
io.open(tmp, "w", encoding="utf-8", newline="\n").write(luau)
res = subprocess.run([LUAU, tmp], capture_output=True, text=True, encoding="utf-8", errors="replace")
lines = [l for l in (res.stdout + res.stderr).splitlines() if l.strip()]
passed = sum(1 for _, ok, _ in results if ok)
total = len(results)
for label, ok, detail in results:
    print("[REGROW] %s %s %s" % (label, detail, "O" if ok else "X"))
for l in lines:
    print(l)
    if l.startswith("[REGROW]"):
        total += 1
        passed += 1 if l.endswith(" O") else 0
    else:
        total += 1  # 에러 줄은 실패로 센다
print("[REGROW] 끝 %d/%d" % (passed, total))
sys.exit(0 if passed == total else 1)
