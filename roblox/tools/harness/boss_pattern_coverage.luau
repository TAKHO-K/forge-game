-- BOSS-NIGHT-3 addendum-2 15: 패턴 등장 판 비율(1번 이상 나온 판 ÷ 전체 판) - 6보스 새 몸 · 스테이지 100 · 솔로 · 아는 보스 · 근/원 평균.
--   줄 = COVER 보스 패턴 등장판%(근 · 원 평균) 판당 횟수 근거리% 원거리%
-- 목표 = 기믹 · 환경 제외 모든 패턴 80% 판 이상. ECON_SRC로 옛 src 사본을 같은 파일로 돌려 전후 비교.
-- 실행: PRELUDE=server_prelude.luau ECON_RES=res_cover.txt python build_run.py boss_pattern_coverage.luau(COVER_RUNS 전역으로 판 수 덮기)
local Sim, BR, BF = MODS.BossDifficultySim, MODS.BossRules, MODS.BossFramework
local walk = MODS.WorldConfig.playerWalkSpeedStuds
local RUNS = COVER_RUNS or 300
local GIMMICK = { gimmick = true, colorMatch = true, sandSearch = true, orgel = true, sonic = true, lightningRods = true }
for _, id in ipairs({ "section_guardian", "crystal_queen", "abyssal_lord", "scorpion_queen", "storm_lord", "frost_giant" }) do
	local g = BF.applyV3(BF.applyBodyEdge(BR.buildInstanceData(100, id, 1), id .. "_v2", walk), id .. "_v2")
	local ids = {}
	for _, sid in ipairs(g.skillOrder) do
		if not GIMMICK[g.skills[sid].primitive] and g.skills[sid].role ~= "gimmick" then
			table.insert(ids, sid)
		end
	end
	local present, total, seconds, n = {}, {}, 0, 0
	local byRole = { melee = {}, ranged = {} }
	for _, role in ipairs({ "melee", "ranged" }) do
		for seed = 1, RUNS do
			local r = Sim.run(id, { partySize = 1, role = role, familiar = true, stage = 100, bodyEdgeRig = id .. "_v2", seed = seed * 7919 + 13 })
			n += 1
			seconds += r.seconds
			for _, sid in ipairs(ids) do
				local c = r.counts[sid] or 0
				total[sid] = (total[sid] or 0) + c
				if c > 0 then
					present[sid] = (present[sid] or 0) + 1
					byRole[role][sid] = (byRole[role][sid] or 0) + 1
				end
			end
		end
	end
	local below = 0
	for _, sid in ipairs(ids) do
		local share = (present[sid] or 0) / n
		below += share < 0.8 and 1 or 0
		print(("COVER\t%s\t%s\t%.1f\t%.2f\t%.1f\t%.1f"):format(id, sid, share * 100, (total[sid] or 0) / n, (byRole.melee[sid] or 0) / RUNS * 100, (byRole.ranged[sid] or 0) / RUNS * 100))
	end
	print(("COVERBOSS\t%s\t전투 평균 %.1f초\t80%% 미만 %d/%d"):format(id, seconds / n, below, #ids))
end
print("COVER END")
