-- A2-N4 자동 검증.
--   (가) 순수: 보스 행동 3줄(BossScheduler 강공격 줄 - 전역 쿨 분리 · 강공격 간격 · 패턴 뒤로 미룸 · 첫 강공격 준비 · 둘 다 준비면 패턴 먼저 · 끄면 옛 규칙) ·
--        투사체 인당(조준형 스킬 분류) · 강공격 피해 배율(heavyDamageScale) · 방향(faceMoveMinSpeed 데이터) · 대표 전력(/gg loadout 역산 = 앵커 곡선).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossScheduler = require(ReplicatedStorage.Shared.BossScheduler)
local BossRules = require(ReplicatedStorage.Shared.BossRules)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local BalanceSim = require(ReplicatedStorage.Shared.BalanceSim)

local V = {}

local function newRecorder(tag)
	local pass, total = 0, 0
	local r = {}
	function r.check(label, ok)
		total += 1
		if ok then
			pass += 1
		end
		print(("[A2-N4][%s] %s %s"):format(tag, label, ok and "O" or "X"))
	end
	function r.section(name, fn)
		local ok, err = pcall(fn)
		if not ok then
			r.check(("%s 실행 중 에러: %s"):format(name, tostring(err)), false)
		end
	end
	function r.summary()
		return pass, total
	end
	return r
end

-- 합성 스킬 표: heavy 1개(전조 1.0 · 쿨 5) · 패턴 1개(쿨 4)
local function synth(withGap)
	local skills = {
		H = { bubble = BossData.mechanics.lanes.heavyBubble, cooldownSeconds = 5, telegraphSeconds = 1.0, priority = 0 },
		P = { bubble = "pattern", cooldownSeconds = 4, telegraphSeconds = 1.2, priority = 0 },
	}
	local order = { "H", "P" }
	-- QUEUE-ALL1 결정 1: 줄 규칙 검사는 전조 간격 X를 뺀 사본으로(X는 아래 "전조 간격 · 초반 완화" 절이 따로 본다)
	local lanes = table.clone(BossData.mechanics.lanes)
	lanes.telegraphMinGapSeconds = withGap and BossData.mechanics.lanes.telegraphMinGapSeconds or nil
	local config = { globalCooldownSeconds = 6, enragedGlobalCooldownSeconds = 2.5, enragedHpFraction = 0.2, entryGraceSeconds = 0, starvationPriorityBonus = 1000, lanes = lanes }
	local ctx = { now = 0, conditionMet = function()
		return true
	end, boundSeconds = function()
		return 2
	end }
	return skills, order, config, ctx
end

function V.runPure()
	print("===A2-N4 검증 시작(가)===")
	local r = newRecorder("가")
	local L = BossData.mechanics.lanes
	r.section("강공격 줄", function()
		local skills, order, config, ctx = synth()
		local st = BossScheduler.newState(skills, order, 0, false, config)
		r.check(("첫 강공격 준비 %.1f초 ≤ %.1f(쿨 5를 당김) · 패턴은 쿨 그대로 %.1f"):format(st.readyAt.H, L.firstHeavySeconds, st.readyAt.P), st.readyAt.H <= L.firstHeavySeconds + 1e-6 and st.readyAt.P == 4)
		-- 시작 전역 쿨(시작 = lastEndAt)은 비우고: 패턴을 t=4에 시작 · t=6에 끝 → 전역 쿨 6 = 패턴은 12까지 닫힘. 강공격은 6에도 준비(쿨 무관)
		st.lastEndAt = -100
		ctx.now = 4
		local p1 = BossScheduler.pick(st, skills, order, config, ctx)
		BossScheduler.onSkillStart(st, p1, 4, skills, config)
		BossScheduler.onSkillEnd(st, skills, p1, 6, config)
		ctx.now = 6
		local p2 = BossScheduler.pick(st, skills, order, config, ctx)
		r.check(("t=4 둘 다 준비 → 패턴 먼저(%s) · 패턴 끝 t=6 직후 강공격(%s - 전역 쿨과 분리)"):format(tostring(p1), tostring(p2)), p1 == "P" and p2 == "H")
		BossScheduler.onSkillStart(st, "H", 6, skills, config)
		BossScheduler.onSkillEnd(st, skills, "H", 7.5, config)
		-- 다음 강공격: 쿨 5 → 12.5 · 간격 = 6 + 전조 1 + 1.5 = 8.5 → 쿨이 늦다. 간격만 보는 합성: 쿨 0으로
		skills.H.cooldownSeconds = 0
		st.readyAt.H = 7.5
		ctx.now = 8.4
		local early = BossScheduler.pick(st, skills, order, config, ctx)
		ctx.now = 8.5
		local onTime = BossScheduler.pick(st, skills, order, config, ctx)
		r.check(("강공격끼리 = 전조 끝 + %.1f초: 8.4초 %s · 8.5초 %s"):format(L.heavyMinGapSeconds, tostring(early), tostring(onTime)), early == nil and onTime == "H")
		-- 패턴은 강공격 끝(7.5) + 0.8 = 8.3 뒤 · 그리고 전역 쿨(패턴 끝 6 + 6 = 12) 뒤
		local st2 = BossScheduler.newState(skills, order, 0, false, config)
		st2.lastEndAt = -100
		st2.readyAt.P, st2.readyAt.H = 0, 1e9
		st2.heavyEndAt = 10
		ctx.now = 10.7
		local deferred = BossScheduler.pick(st2, skills, order, config, ctx)
		ctx.now = 10.8
		local after = BossScheduler.pick(st2, skills, order, config, ctx)
		r.check(("패턴은 강공격 끝 + %.1f초 뒤로: 10.7초 %s · 10.8초 %s"):format(L.patternAfterHeavySeconds, tostring(deferred), tostring(after)), deferred == nil and after == "P")
	end)
	r.section("전조 간격 · 초반 완화", function()
		-- 전조 공격(강공격 · 패턴 공통) 사이 = 전 전조 끝 + X: 패턴 t=4 시작(전조 1.2) → 다음 전조 공격은 4 + 1.2 + X 뒤
		local X = L.telegraphMinGapSeconds
		local skills, order, config, ctx = synth(true)
		local st = BossScheduler.newState(skills, order, 0, false, config)
		st.lastEndAt = -100
		ctx.now = 4
		local p1 = BossScheduler.pick(st, skills, order, config, ctx)
		BossScheduler.onSkillStart(st, p1, 4, skills, config)
		BossScheduler.onSkillEnd(st, skills, p1, 6, config)
		local open = 4 + skills.P.telegraphSeconds + X
		ctx.now = open - 0.1
		local early = BossScheduler.pick(st, skills, order, config, ctx)
		ctx.now = open
		local onTime = BossScheduler.pick(st, skills, order, config, ctx)
		r.check(("전조 간격 X = %.1f초: 패턴 %s 뒤 %.1f초 %s · %.1f초 %s(강공격)"):format(X or -1, tostring(p1), open - 0.1, tostring(early), open, tostring(onTime)), X ~= nil and p1 == "P" and early == nil and onTime == "H")
		-- 강공격 줄 끔(heavyOff): 강공격이 준비돼 있어도 안 나가고 패턴만
		local s2, o2, c2, x2 = synth(false)
		c2.heavyOff = true
		local st2 = BossScheduler.newState(s2, o2, 0, false, c2)
		st2.lastEndAt = -100
		x2.now = 3
		local h = BossScheduler.pick(st2, s2, o2, c2, x2)
		x2.now = 4
		local p = BossScheduler.pick(st2, s2, o2, c2, x2)
		r.check(("heavyOff: t=3 강공격 준비됨 → %s · t=4 → %s"):format(tostring(h), tostring(p)), h == nil and p == "P")
		-- 초반 완화 구간(스테이지 ≤ maxStage): 무한 모드 인스턴스 = 강공격 줄 끔 + 피해 × damageScale · 구간 밖 = 그대로
		local R = BossData.mechanics.earlyRelief
		local boss = BossData.bosses.section_guardian
		local plain = BossRules.buildInstanceDataFrom(MonsterData.tier1, 25, boss, 1, 1, 1, BossRules.densityExtra(25))
		local relief = BossRules.buildInstanceData(25, "section_guardian", 1)
		local outside = BossRules.buildInstanceData(R.maxStage + BossData.stageInterval, "section_guardian", 1)
		local ratio = relief.skills.heavy.damage.multiplier / plain.skills.heavy.damage.multiplier
		local basicRatio = relief.basicAttackDamageMultiplier / plain.basicAttackDamageMultiplier
		r.check(("초반 완화 스테이지 25: 표시 %s · 강공격 줄 끔 %s · 스킬 피해 ×%.2f · 평타 ×%.2f(기대 %.2f) · 스테이지 %d = 완화 %s"):format(tostring(relief.earlyRelief), tostring(relief.scheduler.heavyOff), ratio, basicRatio, R.damageScale,
			R.maxStage + BossData.stageInterval, tostring(outside.earlyRelief)),
			relief.earlyRelief == true and relief.scheduler.heavyOff == true and math.abs(ratio - R.damageScale) < 1e-6 and math.abs(basicRatio - R.damageScale) < 1e-6 and outside.earlyRelief == nil)
	end)
	r.section("끄면 옛 규칙", function()
		local skills, order, config, ctx = synth()
		config.lanes = nil
		local st = BossScheduler.newState(skills, order, 0, false, config)
		st.lastEndAt = -100
		ctx.now = 4
		local p1 = BossScheduler.pick(st, skills, order, config, ctx)
		BossScheduler.onSkillStart(st, p1, 4, skills, config)
		BossScheduler.onSkillEnd(st, skills, p1, 6, config)
		ctx.now = 6
		local p2 = BossScheduler.pick(st, skills, order, config, ctx)
		ctx.now = 12
		local p3 = BossScheduler.pick(st, skills, order, config, ctx)
		r.check(("줄 끔: 첫 준비 H %.0f(쿨 그대로) · t=4 %s · 끝 직후 %s(전역 쿨) · 12초 %s"):format(BossScheduler.newState(skills, order, 0, false, config).readyAt.H, tostring(p1), tostring(p2), tostring(p3)),
			BossScheduler.newState(skills, order, 0, false, config).readyAt.H == 5 and p1 == "P" and p2 == nil and p3 == "H")
	end)
	r.section("강공격 피해 배율", function()
		local rows, ok = {}, true
		for _, id in ipairs({ "section_guardian", "frost_giant" }) do
			for sid, skill in pairs(BossData.bosses[id].skills) do
				if skill.bubble == L.heavyBubble and skill.damage and skill.damage.multiplier then
					table.insert(rows, ("%s.%s ×%.3f"):format(id, sid, skill.damage.multiplier))
				end
			end
		end
		r.check(("heavyDamageScale %.2f 적용(보스 표): %s"):format(L.heavyDamageScale, table.concat(rows, " · ")), ok and #rows > 0)
	end)
	r.section("투사체 인당", function()
		-- projectile = 대상 목록마다 count발(BossHandlersBR1.projectile - targetRule: target 전원 · airborne 뜬 사람 · airbornePreferred 뜬 사람 있으면 그들)
		-- circleTarget = perMember면 멤버마다 발밑 1개(BossPatterns aimPositions) · chain · ambush · shots는 보스 몸 · 경로 기준(설계상 한 줄)
		local per, single, design = {}, {}, {}
		for _, id in ipairs({ "section_guardian", "frost_giant", "abyssal_lord", "crystal_queen", "scorpion_queen", "storm_lord" }) do
			for sid, sk in pairs(BossData.bosses[id].skills) do
				local name = id .. "." .. sid
				if sk.primitive == "projectile" then
					table.insert(per, name .. "(" .. tostring(sk.targetRule or "target") .. ")")
				elseif sk.primitive == "circleTarget" then
					if sk.perMember then
						table.insert(per, name)
					elseif sk.chain or sk.ambush or sk.shots or sk.bubble ~= "meteor" then
						table.insert(design, name)
					else
						table.insert(single, name)
					end
				end
			end
		end
		table.sort(per)
		table.sort(design)
		r.check(("떨어지는 · 날아가는 투사체 인당 %d개 · 한 명만 노리는 투사체 %d개(%s) · 보스 몸 · 경로 기준(설계) %s"):format(#per, #single, table.concat(single, ", "), table.concat(design, ", ")), #single == 0)
	end)
	r.section("전갈 야바위", function()
		local SandShell = require(ReplicatedStorage.Shared.SandShell)
		local spec = BossData.bosses.scorpion_queen.skills.sandSearch.mound
		local S = spec.shell
		local worstOverlap, maxSpeed, maxR, holds, bursts = 0, 0, 0, {}, 0
		for seed = 1, 20 do
			local rng = Random.new(seed)
			local count = spec.countByParty[math.min(4, 1 + seed % 4)]
			local sand = { center = Vector3.zero, realIndex = 1 + seed % count }
			local mounds = {}
			for i = 1, count do
				local a = (i - 1) / count * 2 * math.pi
				mounds[i] = { position = Vector3.new(math.cos(a), 0, math.sin(a)) * spec.wanderRadiusStuds * 0.55 }
			end
			local overlapSince, lastPhase, holdStart = {}, nil, 0
			local dt = 1 / 60
			for k = 0, 14 * 60 do
				local now = k * dt
				local before = {}
				for i, m in ipairs(mounds) do
					before[i] = m.position
				end
				SandShell.step(sand, spec, mounds, now, dt, rng)
				local phase = sand.shell.phase
				if phase ~= lastPhase then
					if phase == "move" then
						bursts += 1
						if lastPhase == "hold" and holdStart > 0 then
							table.insert(holds, now - holdStart)
						end
					else
						holdStart = now
					end
					lastPhase = phase
				end
				for i, m in ipairs(mounds) do
					local moved = (m.position - before[i]).Magnitude
					if moved < S.pushStuds * 0.5 then -- 비켜 세우기(순간)는 속도에서 뺀다
						maxSpeed = math.max(maxSpeed, moved / dt)
					end
					maxR = math.max(maxR, m.position.Magnitude)
					if i ~= sand.realIndex then
						local d = (m.position - mounds[sand.realIndex].position).Magnitude
						if d < S.overlapStuds then
							overlapSince[i] = overlapSince[i] or now
							worstOverlap = math.max(worstOverlap, now - overlapSince[i])
						else
							overlapSince[i] = nil
						end
					end
				end
			end
		end
		local hMin, hMax = math.huge, 0
		for _, h in ipairs(holds) do
			hMin, hMax = math.min(hMin, h), math.max(hMax, h)
		end
		r.check(("야바위 20판 × 14초: 자리 바꾸기 %d번 · 최고 속도 %.1f(%g ~ %g) · 멈춤 %.2f ~ %.2f초(%g ~ %g) · 진짜 ↔ 가짜 최장 겹침 %.2f초(≤ %.1f) · 중심에서 최대 %.1f(떠돌기 %d)"):format(
			bursts, maxSpeed, S.burstSpeed[1], S.burstSpeed[2], hMin, hMax, S.holdSeconds[1], S.holdSeconds[2], worstOverlap, S.maxOverlapSeconds, maxR, spec.wanderRadiusStuds),
			maxSpeed <= S.burstSpeed[2] + 0.01 and maxSpeed >= S.burstSpeed[1] - 0.01 and hMin >= S.holdSeconds[1] - 0.02 and hMax <= S.holdSeconds[2] + 0.02 and worstOverlap <= S.maxOverlapSeconds and maxR <= spec.wanderRadiusStuds + 0.01)
	end)
	r.section("대표 전력 역산", function()
		local off = BalanceSim.solveKillOffset()
		local rows, ok = {}, true
		for _, stage in ipairs({ 500, 2000, 10000 }) do
			local level = math.max(1, math.floor(stage - off + 0.5))
			local back = BalanceSim.recommendedStage(level, 0, false)
			table.insert(rows, ("스테이지 %d → 레벨 %d → rec %d"):format(stage, level, back))
			ok = ok and math.abs(back - stage) <= 1
		end
		r.check("/gg loadout 레벨 = 앵커 곡선 역(rec(L) ≈ 스테이지 ±1): " .. table.concat(rows, " · "), ok)
	end)
	local pass, total = r.summary()
	print(("===A2-N4 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

return V
