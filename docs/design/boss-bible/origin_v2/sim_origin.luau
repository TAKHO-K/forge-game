-- BOSS-NIGHT-2 C: 발생 지점 끔(옛 모형) ↔ 켬 - 스테이지 100 · 600판 · 솔로 · 새 몸
local Sim = MODS.BossDifficultySim
local RUNS = SIM_RUNS or 600
local BOSS = SIM_BOSS
local RIG = BOSS .. "_v2"
for _, role in ipairs({ "ranged", "melee" }) do
	for _, fam in ipairs({ true, false }) do
		for _, origin in ipairs({ false, true }) do
			local r = Sim.monteCarlo(BOSS, { partySize = 1, role = role, familiar = fam, stage = 100, bodyEdgeRig = RIG, origin = origin }, RUNS)
			print(("SIMO\t%s\t%s\t%s\t%s\t%.1f\t%.1f\t%.1f"):format(BOSS, role, fam and "familiar" or "first", origin and "on" or "off", r.wipeRate * 100, r.takenMean * 100, r.p50))
		end
	end
end
