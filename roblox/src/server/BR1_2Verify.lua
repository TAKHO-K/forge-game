-- BR1-2 자동 검증(docs/design/boss-br1-2.md). (가) = 서버 시작 때 순수 계산(Play 없이도 로컬 하네스로 돈다).
--   (가) 난이도 곡선 표 검사: 표본 스테이지(BossCurveData.sampleStages) × 6종 × 인원 1 · 4 - 투사체 인당 개수 · 반경 · 장판 범위 · 장판 개수 · 연쇄 칸이
--        앞 표본보다 줄지 않는가 · 인당 8 초과 없음 · 회피 부등식(전조 맞춤 뒤) 통과.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossCurveData = require(ReplicatedStorage.Shared.data.BossCurveData)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local BossRules = require(ReplicatedStorage.Shared.BossRules)
local BossSkillMath = require(ReplicatedStorage.Shared.BossSkillMath)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)

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

-- 초반 보호(스테이지 1 ~ 30 - CombatConfig.newbieProtection): 1 = atStage1 · plateau = atPlateau · 오르막만 · 30 < 1 · 31 = 1 · 첫 보스 6종(5 ~ 30) 모두 보호 안.
function BR1_2Verify.protectionCheck(r)
	local p = CombatConfig.newbieProtection
	local cells, monotone, prev = {}, true, 0
	for stage = 1, 32 do
		local m = PlayerCombat.getNewbieDamageMultiplier(stage)
		if m < prev - 1e-12 then
			monotone = false
		end
		prev = m
		if stage == 1 or stage % 5 == 0 or stage == 24 or stage == 27 or stage == 31 then
			table.insert(cells, ("%d ×%.3f"):format(stage, m))
		end
	end
	local m1, mP, m30, m31 = PlayerCombat.getNewbieDamageMultiplier(1), PlayerCombat.getNewbieDamageMultiplier(p.plateauStage), PlayerCombat.getNewbieDamageMultiplier(30), PlayerCombat.getNewbieDamageMultiplier(31)
	r.check(("초반 보호 1 ~ %d: %s · 오르막 %s · nil → %s"):format(p.untilStage, table.concat(cells, " · "), tostring(monotone), tostring(PlayerCombat.getNewbieDamageMultiplier(nil))),
		monotone and math.abs(m1 - p.atStage1) < 1e-9 and math.abs(mP - p.atPlateau) < 1e-9 and m30 < 1 and m31 == 1 and PlayerCombat.getNewbieDamageMultiplier(nil) == 1)
end

-- 지진파 무작위 리듬(구간 수호자 진동파 randomRhythm): 가능한 모든 순서(3 · 4 · 5박 · 두 종류 · 같은 종류 3연속 없음)가 회피 부등식을 통과하는가 + 굴린 1,000번의 분포.
function BR1_2Verify.quakeCheck(r)
	local skill = BossData.bosses.section_guardian.skills.shockwave
	local spec = skill.randomRhythm
	local sequences, fails = 0, {}
	local function walk(types, count)
		if #types == count then
			local hasAir, hasGround, run, ok = false, false, 0, true
			for i, t in ipairs(types) do
				hasAir = hasAir or t == "air"
				hasGround = hasGround or t == "ground"
				run = (i > 1 and t == types[i - 1]) and run + 1 or 1
				ok = ok and run <= spec.maxSameInRow
			end
			if ok and hasAir and hasGround then
				sequences += 1
				for _, scale in ipairs({ 1, BossRules.maxSkillRangeScale() }) do
					local copy = table.clone(BossSkillMath.scaleSkills({ s = skill }, scale).s)
					copy.rhythm = BossSkillMath.rollRhythm(copy, nil, types)
					for _, ch in ipairs(BossSkillMath.dodgeChecks(copy, 8, WorldConfig.playerWalkSpeedStuds)) do
						if not ch.ok then
							table.insert(fails, table.concat(types, "-") .. " " .. ch.label)
						end
					end
				end
			end
			return
		end
		for _, t in ipairs({ "ground", "air" }) do
			local nextTypes = table.clone(types)
			table.insert(nextTypes, t)
			walk(nextTypes, count)
		end
	end
	for _, count in ipairs(spec.counts) do
		walk({}, count)
	end
	local seed = 12345
	local function rng()
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	local byCount = {}
	for _ = 1, 1000 do
		local rhythm = BossSkillMath.rollRhythm(skill, rng)
		byCount[#rhythm] = (byCount[#rhythm] or 0) + 1
	end
	r.check(("지진파 무작위: 가능한 순서 %d가지 × 범위 배율 1 · 최대 - 회피 실패 %d%s · 굴림 1,000번 3박 %d · 4박 %d · 5박 %d"):format(sequences, #fails,
		#fails > 0 and (" " .. table.concat(fails, " / ")) or "", byCount[3] or 0, byCount[4] or 0, byCount[5] or 0), #fails == 0 and sequences > 0 and (byCount[3] or 0) > 0 and (byCount[5] or 0) > 0)
end

-- 수정 부수기 점프맵(BossJumpMapData): 코스마다 완주 가능(단계마다 가장 약한 기술 조합의 최대 간격 × safety 안 · 대시 간격 · 어려운 단계 수 · 발판 폭 · 마지막 = 수정) + 8방위 자리 배치.
function BR1_2Verify.jumpCourseCheck(r)
	local BossJumpMapData = require(ReplicatedStorage.Shared.data.BossJumpMapData)
	local BossJumpCourseMath = require(ReplicatedStorage.Shared.BossJumpCourseMath)
	for _, course in ipairs(BossJumpMapData.courses) do
		local ok, problems, combos, hard = BossJumpCourseMath.validate(course)
		local labels = {}
		for i = 2, #course.steps do
			table.insert(labels, combos[i] and combos[i].label or "X")
		end
		local placed = 0
		for k = 0, 7 do
			if BossJumpCourseMath.place(course, k * math.pi / 4, Vector3.new(0, 0, 0), 0, 140) then
				placed += 1
			end
		end
		local layout = BossJumpCourseMath.layout(course)
		r.check(("점프맵 %s: 완주 %s · 어려운 단계 %d(≥ %d) · 꼭대기 %.0f · 8방위 배치 %d/8 · %s%s"):format(course.name, tostring(ok), hard, BossJumpMapData.minHardSteps, layout[#layout].position.Y, placed,
			table.concat(labels, " / "), #problems > 0 and (" | " .. table.concat(problems, " | ")) or ""), ok and placed == 8)
	end
end

function BR1_2Verify.runPure()
	print("===BR1-2 검증 시작(가)===")
	local r = newRecorder("가")
	r.section("초반 보호", function()
		BR1_2Verify.protectionCheck(r)
	end)
	r.section("지진파", function()
		BR1_2Verify.quakeCheck(r)
	end)
	r.section("점프맵", function()
		BR1_2Verify.jumpCourseCheck(r)
	end)
	r.section("곡선 표", function()
		BR1_2Verify.curveCheck(r)
		BR1_2Verify.curveTable(r)
	end)
	local pass, total = r.summary()
	print(("===BR1-2 검증 끝(가)=== %d/%d 통과"):format(pass, total))
	return pass, total
end

return BR1_2Verify
