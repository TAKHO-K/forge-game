-- GUARDIAN-V3 6: 수호자 첫 도전 모형 V2(몸 가장자리 + 피해 계수) ↔ V3(키 30 · 바닥 표시 끔 · 예비 연장 · 돌진 폭 = 몸 폭 · 이속 · 바나나 · 도약) - 원거리 · 근거리 · 아는 보스 · 처음
--   + 첫 보스 도움(처음 · 앞선 전멸 0 ~ 3회 → 받는 피해 × 1 · 0.9 · 0.8 · 0.7) + 보스 피해 출처(바나나 · 도약 몫).
-- 실행: PRELUDE=server_prelude.luau ECON_RES=sim_g3.txt python build_run.py guardian_v3_sim.luau(SIM_RUNS · SIM_STAGES · SIM_ONLY_V3 = 전역으로 덮기)
local Sim = MODS.BossDifficultySim
local RUNS = SIM_RUNS or 600
local RIG = "section_guardian_v2"
local function line(label, r)
	local src = r.bySource
	print(("%-34s 처치 p50 %5.1f초(p10 %5.1f · p90 %5.1f) · 받은 피해 %5.1f%% · 전멸 %5.1f%% · 처치율 %5.1f%% · 바나나 %4.1f%% · 도약 %4.1f%% · 바나나 %4.1f회 · 도약 %4.1f회"):format(label,
		r.p50, r.p10, r.p90, r.takenMean * 100, r.wipeRate * 100, r.killRate * 100, (src["바나나"] or 0) * 100, (src["도약"] or 0) * 100,
		(r.counts.banana or 0) / r.runs, (r.counts.leap or 0) / r.runs))
end
for _, stage in ipairs(SIM_STAGES or { 100, 500 }) do
	for _, role in ipairs({ "ranged", "melee" }) do
		for _, fam in ipairs({ true, false }) do
			for _, v3 in ipairs(SIM_ONLY_V3 and { true } or { false, true }) do
				local r = Sim.monteCarlo("section_guardian", { partySize = 1, role = role, familiar = fam, stage = stage, bodyEdgeRig = RIG, noV3 = not v3 }, RUNS)
				line(("st%d %s %s %s"):format(stage, role == "ranged" and "원거리" or "근거리", fam and "아는보스" or "처음", v3 and "V3" or "V2"), r)
			end
		end
	end
end
print("── 첫 보스 도움(V3 · 처음 · 스테이지 100 · 앞선 전멸 수) ──")
for _, role in ipairs({ "ranged", "melee" }) do
	for fails = 0, 3 do
		local r = Sim.monteCarlo("section_guardian", { partySize = 1, role = role, familiar = false, stage = 100, bodyEdgeRig = RIG, assistFails = fails }, RUNS)
		line(("도움 %s 전멸 %d회 뒤"):format(role == "ranged" and "원거리" or "근거리", fails), r)
	end
end
