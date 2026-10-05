-- BOSS-NIGHT-1: 새 몸 보스 첫 도전 모형(옛 몸 ↔ 새 몸 - 몸 가장자리 · V3 노브 · 신규 패턴) - 원거리 · 근거리 · 아는 보스 · 처음 · 스테이지 100 · 500.
-- 실행: SIM_BOSS = "frost_giant" 등을 테스트 파일 앞에 두고 PRELUDE=server_prelude.luau ECON_RES=sim.txt python build_run.py <파일>(SIM_RUNS · SIM_STAGES 덮기)
local Sim = MODS.BossDifficultySim
local RUNS = SIM_RUNS or 600
local BOSS = SIM_BOSS
local RIG = BOSS .. "_v2"
local function line(label, r)
	local parts = {}
	for id, n in pairs(r.counts) do
		table.insert(parts, ("%s %.1f"):format(id, n / r.runs))
	end
	table.sort(parts)
	print(("%-30s 처치 p50 %5.1f초 · 받은 피해 %5.1f%% · 전멸 %5.1f%% · 처치율 %5.1f%%"):format(label, r.p50, r.takenMean * 100, r.wipeRate * 100, r.killRate * 100))
	if SIM_COUNTS then
		print("    회수/판 " .. table.concat(parts, " · "))
	end
end
for _, stage in ipairs(SIM_STAGES or { 100, 500 }) do
	for _, role in ipairs({ "ranged", "melee" }) do
		for _, fam in ipairs({ true, false }) do
			for _, new in ipairs(SIM_ONLY_NEW and { true } or { false, true }) do
				local r = Sim.monteCarlo(BOSS, { partySize = 1, role = role, familiar = fam, stage = stage, bodyEdgeRig = new and RIG or nil }, RUNS)
				line(("st%d %s %s %s"):format(stage, role == "ranged" and "원거리" or "근거리", fam and "아는보스" or "처음", new and "새 몸" or "옛 몸"), r)
			end
		end
	end
end
