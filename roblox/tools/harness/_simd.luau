-- FINAL-1b 3단계: BossSim 대시 끔 ↔ 켬(발생 지점 켬 · 스테이지 100 · 솔로 · 600판 · 새 몸) - 첫 줄에 SIM_BOSS · SIM_RUNS를 붙여 실행
local Sim = MODS.BossDifficultySim
local RUNS = SIM_RUNS or 600
local BOSS = SIM_BOSS
local RIG = BOSS .. "_v2"
for _, role in ipairs({ "ranged", "melee" }) do
	for _, fam in ipairs({ true, false }) do
		for _, dash in ipairs({ false, true }) do
			local r = Sim.monteCarlo(BOSS, { partySize = 1, role = role, familiar = fam, stage = 100, bodyEdgeRig = RIG, origin = true, dash = dash }, RUNS)
			local u = r.dashUsesPerRun or {}
			print(("SIMD\t%s\t%s\t%s\t%s\t%.1f\t%.1f\t%.1f\t%.2f\t%.2f\t%.2f\t%.2f"):format(BOSS, role, fam and "familiar" or "first", dash and "on" or "off", r.wipeRate * 100, r.takenMean * 100, r.p50, u.long or 0, u.short or 0, u.protectOnly or 0, u.protected or 0))
		end
	end
end
