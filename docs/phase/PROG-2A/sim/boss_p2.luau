-- PROG-2A BossSim 표(설계 사본 bossfork.py): 보스 하나 × 설정 × 근/원 × 처음/아는 · 대시 켬 · 발생 지점 켬 · 스테이지 100 · 솔로.
-- 첫 줄에 SIM_BOSS · SIM_RUNS · SIM_CFGS(설정 표)를 붙인다. 줄 = P2B 보스 설정 역할 숙련 전멸% 받은피해% p50 p90 회복수 시간초과%
local Sim = MODS.BossDifficultySim
local RUNS = SIM_RUNS or 400
local BOSS = SIM_BOSS
for _, cfg in ipairs(SIM_CFGS) do
	for _, role in ipairs({ "ranged", "melee" }) do
		for _, fam in ipairs({ false, true }) do
			local o = { partySize = 1, role = role, familiar = fam, stage = 100, bodyEdgeRig = BOSS .. "_v2", origin = true, dash = true, rebirth = SIM_REBIRTH or 0, limit = 900 }
			for k, v in pairs(cfg) do
				if k ~= "name" then
					o[k] = (type(v) == "table") and (fam and v[2] or v[1]) or v -- { 처음, 아는 } 짝이면 숙련별 값
				end
			end
			local r = Sim.monteCarlo(BOSS, o, RUNS)
			print(("P2B\t%s\t%s\t%s\t%s\t%.1f\t%.1f\t%.1f\t%.1f\t%.2f\t%.1f"):format(BOSS, cfg.name, role, fam and "familiar" or "first",
				r.wipeRate * 100, r.takenMean * 100, r.p50, r.p90, r.healsPerRun or 0, (r.timeoutRate or 0) * 100))
		end
	end
end
