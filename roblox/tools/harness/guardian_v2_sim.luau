-- GUARDIAN-V2 5: 수호자 첫 도전 모형 전/후(옛 몸 · 새 몸 = 몸 가장자리 + BossFrameworkData.bodyEdge 밸런스) - 원거리 · 근거리 · 아는 보스 · 처음
-- 실행: PRELUDE=server_prelude.luau ECON_RES=sim_g.txt python build_run.py guardian_v2_sim.luau
local Sim = MODS.BossDifficultySim
local RUNS = SIM_RUNS or 600
local function line(label, r)
	print(("%-44s 처치 p50 %5.1f초(p10 %5.1f · p90 %5.1f) · 받은 피해 %5.1f%% · 전멸 %5.1f%% · 처치율 %5.1f%%"):format(label, r.p50, r.p10, r.p90, r.takenMean * 100, r.wipeRate * 100, r.killRate * 100))
end
for _, stage in ipairs(SIM_STAGES or { 100, 500 }) do
	for _, role in ipairs({ "ranged", "melee" }) do
		for _, fam in ipairs({ true, false }) do
			for _, edge in ipairs(SIM_EDGE or { false, true }) do
				local r = Sim.monteCarlo("section_guardian", { partySize = 1, role = role, familiar = fam, stage = stage, bodyEdgeRig = edge and "section_guardian_v2" or nil }, RUNS)
				line(("st%d %s %s %s"):format(stage, role == "ranged" and "원거리" or "근거리", fam and "아는보스" or "처음", edge and "새몸" or "옛몸"), r)
			end
		end
	end
end
