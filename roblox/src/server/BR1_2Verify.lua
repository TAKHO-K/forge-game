-- BR1-2 자동 검증(docs/design/boss-br1-2.md). (가) = 서버 시작 때 순수 계산(Play 없이도 로컬 하네스로 돈다).
--   (가) 난이도 곡선 표 검사: 표본 스테이지(BossCurveData.sampleStages) × 6종 × 인원 1 · 4 - 투사체 인당 개수 · 반경 · 장판 범위 · 장판 개수 · 연쇄 칸이
--        앞 표본보다 줄지 않는가 · 인당 8 초과 없음 · 회피 부등식(전조 맞춤 뒤) 통과.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossCurveData = require(ReplicatedStorage.Shared.data.BossCurveData)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local BossRules = require(ReplicatedStorage.Shared.BossRules)
local BossSkillMath = require(ReplicatedStorage.Shared.BossSkillMath)

local BR1_2Verify = {}

local ALL_BOSSES = { "section_guardian", "frost_giant", "abyssal_lord", "crystal_queen", "scorpion_queen", "storm_lord" }

local function newRecorder(tag)
	local passCount, totalCount = 0, 0
	local r = {}
	function r.check(label, ok)
		totalCount += 1
		passCount += ok and 1 or 0
		print(("[BR1-2][%s] %s %s"):format(tag, label, ok and "O" or "X"))
	end
	function r.note(label)
		print(("[BR1-2][%s] %s"):format(tag, label))
	end
	function r.section(name, fn)
		local ok, err = pcall(fn)
		if not ok then
			r.check(("%s 실행 중 에러: %s"):format(name, tostring(err)), false)
		end
	end
	function r.summary()
		return passCount, totalCount
	end
	return r
end

-- 스킬 하나의 "크기" 지표(줄면 안 되는 것)
local function metrics(skill)
	local m = {}
	if skill.primitive == "projectile" then
		m.count = skill.count
		m.radius = skill.radiusStuds
	else
		m.radius = skill.radiusStuds or 0
		m.halfWidth = skill.halfWidthStuds or skill.pathHalfWidthStuds or 0
		m.scatter = skill.scatterStuds or 0
		if skill.densityScalable then
			m.count = skill.count
		end
		if skill.chain then
			m.chain = skill.chain.count
		end
	end
	return m
end

function BR1_2Verify.curveCheck(r)
	local stages = BossCurveData.sampleStages
	for _, bossId in ipairs(ALL_BOSSES) do
		for _, party in ipairs({ 1, 4 }) do
			local prev = nil
			local shrinks, overCap, dodgeFails, fittedTotal = {}, {}, {}, 0
			for _, stage in ipairs(stages) do
				local data = BossRules.buildInstanceData(stage, bossId, party)
				local now = {}
				for id, skill in pairs(data.skills) do
					now[id] = metrics(skill)
					if skill.primitive == "projectile" and skill.count > BossCurveData.perPersonMax then
						table.insert(overCap, ("%s@%d=%d"):format(id, stage, skill.count))
					end
					if skill.primitive ~= "gimmick" then
						for _, ch in ipairs(BossSkillMath.dodgeChecks(skill, 8, WorldConfig.playerWalkSpeedStuds)) do
							if not ch.ok and ch.distanceStuds > 0 then
								table.insert(dodgeFails, ("%s@%d %s(%.2f<%.2f)"):format(id, stage, ch.label, ch.availableSeconds, ch.requiredSeconds))
							end
						end
					end
					if prev and prev[id] then
						for key, value in pairs(now[id]) do
							if prev[id][key] and value < prev[id][key] - 1e-9 then
								table.insert(shrinks, ("%s.%s@%d %.2f<%.2f"):format(id, key, stage, value, prev[id][key]))
							end
						end
					end
				end
				prev = now
			end
			r.check(("곡선 %s %d인: 표본 %d개 - 줄어듦 %d · 인당 8 초과 %d · 회피 실패 %d%s"):format(bossId, party, #stages, #shrinks, #overCap, #dodgeFails,
				(#shrinks + #overCap + #dodgeFails) > 0 and (" " .. table.concat(shrinks, " / ") .. table.concat(overCap, " / ") .. table.concat(dodgeFails, " / ")) or ""),
				#shrinks == 0 and #overCap == 0 and #dodgeFails == 0)
		end
	end
end

-- 표본 스테이지마다 단계 · 스킬별 인당 투사체 · 전조를 늘린 스킬(보고서 표).
function BR1_2Verify.curveTable(r)
	for _, stage in ipairs(BossCurveData.sampleStages) do
		local row = BossSkillMath.curveRow(stage)
		local cells, fitted = {}, {}
		for _, bossId in ipairs(ALL_BOSSES) do
			local boss = BossData.bosses[bossId]
			local skills, fit = BossSkillMath.applyCurve(BossSkillMath.scaleSkills(boss.skills, BossRules.skillRangeScale(stage)), row, row.zoneExtra, WorldConfig.playerWalkSpeedStuds)
			for _, id in ipairs(boss.skillOrder) do
				local skill = skills[id]
				if skill and skill.primitive == "projectile" then
					table.insert(cells, ("%s %d(r%.1f)"):format(id, skill.count, skill.radiusStuds))
				end
				if fit[id] then
					table.insert(fitted, ("%s.%s +%.2f"):format(bossId, id, fit[id]))
				end
			end
		end
		r.note(("표본 %d: 단계 %d · 장판 ×%.2f(이속 보정 ×%.3f) · 개수 %+d · 연쇄 %+d | 인당 투사체 %s | 전조 늘림 %s"):format(stage, row.tier, row.zoneRangeScale,
			BossRules.skillRangeScale(stage), row.zoneExtra, row.chainExtra, table.concat(cells, " "), #fitted > 0 and table.concat(fitted, " ") or "없음"))
	end
end

function BR1_2Verify.runPure()
	print("===BR1-2 검증 시작(가)===")
	local r = newRecorder("가")
	r.section("곡선 표", function()
		BR1_2Verify.curveCheck(r)
		BR1_2Verify.curveTable(r)
	end)
	local pass, total = r.summary()
	print(("===BR1-2 검증 끝(가)=== %d/%d 통과"):format(pass, total))
	return pass, total
end

return BR1_2Verify
