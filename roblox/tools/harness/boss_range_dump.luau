-- BOSS-NIGHT-3 3단계: 6보스 × 단계 구간 범위 · 예고 덤프(전후 비교 - ECON_SRC로 옛 src 사본을 같은 파일로 돌린다).
-- 실행: PRELUDE=server_prelude.luau ECON_RES=res_range.txt python build_run.py boss_range_dump.luau
--   줄 = RANGE \t 보스 \t 몸(old = buildInstanceData 실전 · v3 = 새 몸 applyV3) \t 단계 \t 스킬 \t 모양 \t 반경 \t 안 반경 \t 반폭 \t 예고
local BR, BF = MODS.BossRules, MODS.BossFramework
local walk = MODS.WorldConfig.playerWalkSpeedStuds
local function n(v)
	return v and string.format("%.2f", v) or "-"
end
for _, id in ipairs({ "section_guardian", "crystal_queen", "abyssal_lord", "scorpion_queen", "storm_lord", "frost_giant" }) do
	for _, stage in ipairs({ 100, 200, 400, 1000, 6000 }) do
		local d = BR.buildInstanceData(stage, id, 1)
		local g = BF.applyV3(BF.applyBodyEdge(d, id .. "_v2", walk), id .. "_v2")
		for body, inst in pairs({ old = d, v3 = g }) do
			local ids = {}
			for sid in pairs(inst.skills) do
				table.insert(ids, sid)
			end
			table.sort(ids)
			for _, sid in ipairs(ids) do
				local s = inst.skills[sid]
				local r = s.radiusStuds or (s.pulses and s.pulses[1] and s.pulses[1].radiusStuds) or (s.shots and s.shots[1] and s.shots[1].radiusStuds)
				local ir = s.innerRadiusStuds or (s.pulses and s.pulses[1] and s.pulses[1].innerRadiusStuds)
				print(("RANGE\t%s\t%s\t%d\t%s\t%s\t%s\t%s\t%s\t%s"):format(id, body, stage, sid, tostring(s.primitive), n(r), n(ir), n(s.halfWidthStuds), n(s.telegraphSeconds)))
			end
		end
	end
end
print("RANGE END")
