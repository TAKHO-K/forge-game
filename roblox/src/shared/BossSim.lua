-- 보스 처치 시간 모형 + 스킬표 검사기(29-1 → 29-2 재작성, PRD 20.75). 스킬 선택은 실제 전투와 같은
-- shared/BossScheduler.lua를 그대로 부른다 - 모형이 코드와 어긋날 수 없다. BossData만 읽는 순수 계산이라
-- 서버 자동 검증 블록, DevTools "/gg boss sim", 로컬 Luau 하네스 어디서나 같은 값을 낸다(난수도 자체 LCG).
--
--   run          한 판: 기준 플레이어가 스킬을 전부 피하며 싸우면 몇 초 걸리는가(+ 스킬별 횟수·최소 간격·인접 피해 합)
--   monteCarlo   run을 seed만 바꿔 여러 번(F-8) - 회피 비용·돌진 이동 시간·위치 조건을 흔든다
--   checkDodge   회피 부등식 표(B) - 스킬표를 고치면 여기서 걸린다
--   checkPairs   인접 가능한 스킬 쌍의 "실수 2회" 합계 전수 검사(D)
--   checkDensity 스테이지 밀도(S14) - 원이 늘어난 산개 스킬이 예고 안에 벗어날 수 있는가(무작위 배치 · 분위 + 최댓값)
--
-- 모형의 가정(BossData.mechanics.sim): 보스 HP = 기준 플레이어 순딜 60초분 × N^p, 파티 딜 = N배. 스킬이 시작되면
-- 회피 비용만큼 딜이 0. 게이트(20.73 [2-8] A-3): 첫 기믹 예고와 함께 서고(×g) 판정 때만 바뀐다 - 성공이면 열리고
-- (기회 창이 있으면 그 배율), 실패면 서고 + 전원이 잡혀 trap.autoReleaseSeconds 동안 딜 0.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossRules = require(ReplicatedStorage.Shared.BossRules)
local BossScheduler = require(ReplicatedStorage.Shared.BossScheduler)
local BossSkillMath = require(ReplicatedStorage.Shared.BossSkillMath)
local BalanceAnchorConfig = require(ReplicatedStorage.Shared.data.BalanceAnchorConfig)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)

local BossSim = {}

-- 자체 난수(선형 합동) - Roblox Random에 기대지 않아 로컬 하네스와 서버가 같은 수열을 낸다.
local function newRng(seed)
	local state = seed % 2147483648
	return function()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
end

local POSITIONAL = { targetWithin = true, targetBeyond = true, membersClustered = true }

local function evadeSecondsOf(skill)
	if skill.sim and skill.sim.evadeSeconds then
		return skill.sim.evadeSeconds
	end
	local evade = BossData.mechanics.sim.evadeSeconds
	local primitive = skill.primitive
	if primitive == "circleBoss" then
		return evade.circleBoss + evade.circleTargetRepeat * (#BossSkillMath.pulsesOf(skill) - 1)
	elseif primitive == "ring" then
		return evade.ringPerWave * skill.waveCount
	elseif primitive == "circleTarget" then
		local first = skill.radiusStuds > BossData.mechanics.sim.largeCircleRadiusStuds and evade.circleTargetLarge or evade.circleTarget
		return first + (skill.sequential and evade.circleTargetRepeat * (skill.count - 1) or 0)
	elseif primitive == "charge" then
		return evade.chargePerDash * (skill.dashCount or 1)
	elseif primitive == "line" then
		return evade.linePerVolley * (skill.volleys or 1)
	end
	return 0
end

-- 이 스킬의 판정이 게이트를 바꾸는가 + 실패하면 잡히는가. 기믹 스킬은 켜져 있으면 실전이므로 live 모형에서도 게이트가
-- 선다(29-3 - 서리 거인·전갈 여왕). skill.gate(29-4 - 폭풍 군주의 낙뢰)는 기믹이 아닌 스킬이 게이트를 판정하는 경우다 -
-- 실패해도 잡히지 않는다. judgesGate = false(과충전)는 게이트를 안 바꾸는 기믹이다.
local function gateRoleOf(skill)
	if skill.primitive == "gimmick" then
		-- failPenalty = false(29-3 갑각 태세): 판정 실패에 잡힘이 없다 - 실패의 값은 반사로 이미 치렀다(속박은 피할 수 있는 꼬리에서만
		-- 온다). 29-5 튜닝에서 바로잡았다 - 그 전의 모형은 이 기믹도 실패마다 9초 잡힌다고 세어 전갈 여왕의 파훼 전 시간을 부풀렸다.
		return skill.judgesGate ~= false, skill.failPenalty ~= false, skill.breakWindow
	elseif skill.gate then
		return true, false, skill.gate.breakWindow
	end
	return false, false, nil
end

-- options = { partySize(1), design(bool - enabled=false 스킬과 게이트 포함), breaks("always"/"never"/"failFirst"),
--             seed(nil이면 결정 모형: 흔들림 0·위치 조건 참), fixedSeconds(HP 무시하고 이만큼 돌린다 - 굶주림 검사),
--             hpRatio(fixedSeconds일 때 고정할 보스 체력 비율, 기본 0.5) }
function BossSim.run(bossId, options)
	options = options or {}
	local boss = BossData.bosses[bossId]
	if not boss then
		return nil
	end
	local sim = BossData.mechanics.sim
	local mc = sim.monteCarlo
	local rng = options.seed and newRng(options.seed) or nil
	local tick = sim.tickSeconds
	local n = options.partySize or 1
	local design = options.design == true
	local breaks = options.breaks or "always"
	-- densityExtra(S14): 스테이지 밀도로 낙하 원이 늘어난 표로 돌린다. 모형은 원의 개수를 회피 비용에 반영하지 않는다(evadeSecondsOf) -
	-- 개수가 닿는 곳은 낙빙이 세우는 얼음 기둥 수(아래 propCounts)뿐이다.
	local skills, order, config = BossSkillMath.densifySkills(boss.skills, options.densityExtra or 0), boss.skillOrder, boss.scheduler
	local arenaHalf = WorldConfig.bossArena.halfSizeStuds
	local gateMultiplier = BossRules.gateDamageTakenMultiplier()
	local trapSeconds = BossData.mechanics.trap.autoReleaseSeconds
	local surviveHits = BalanceAnchorConfig.surviveTargetHits

	local maxHp = sim.referenceKillSeconds * BossRules.partySizeHpMultiplier(n)
	local hp = maxHp
	local state = BossScheduler.newState(skills, order, 0, design)
	local t = 0
	local current, currentEnd, evadeUntil = nil, 0, 0
	local armed, armedSince, gateStarted = false, nil, false
	local windowMultiplier, windowUntil = 1, 0
	local pendingResolve, pendingSkill = nil, nil
	local judgedIndex = 0
	local counts, lastStartAt, maxWait = {}, {}, {}
	for _, id in ipairs(order) do
		if state.readyAt[id] then
			counts[id], lastStartAt[id], maxWait[id] = 0, 0, 0
		end
	end
	local firstGimmickAt, gimmickCount = nil, 0
	local minGap, previousEnd = math.huge, nil
	local previousId, worstPair, worstPairSum = nil, nil, 0
	local sequence = {} -- 처음 40개 스킬의 { id, at } - 기본형 회귀 검사 · 29-3 "실수 뒤 생존 확률" 계산(전투 하나가 다 들어간다)

	local ctx = { graceUntil = config.entryGraceSeconds }
	local positionalSample = {}
	-- 29-3 동적 지형의 개수(종류별). 모형의 가정: 지형은 그것을 세우는 스킬(onImpact spawnProp)이 나올 때마다 생기고
	-- (상한 boss.props[kind].maxCount), 기믹을 풀 때마다 가려 준 하나가 부서진다. 강타가 부수는 몫은 0으로 둔다 -
	-- "기둥을 강타 범위 밖에 만든다"가 이 보스의 해법이고 모형은 해법대로 싸우는 사람을 잰다.
	local propCounts = {}
	function ctx.conditionMet(condition)
		local kind = condition.type
		if kind == "membersNearSafeSpot" then
			return (propCounts[condition.prop] or 0) > 0
		elseif kind == "hpBelow" then
			return (options.fixedSeconds and (options.hpRatio or 0.5) or hp / maxHp) <= condition.value
		elseif kind == "hpAbove" then
			return (options.fixedSeconds and (options.hpRatio or 0.5) or hp / maxHp) > condition.value
		elseif kind == "gateArmed" then
			return armed == condition.value
		elseif kind == "gateArmedFor" then
			return armed and armedSince ~= nil and t - armedSince >= condition.seconds
		elseif POSITIONAL[kind] then
			if not rng then
				return true
			end
			-- 같은 결정 시점 안에서는 같은 조건이 같은 답을 낸다.
			if positionalSample[kind] == nil then
				positionalSample[kind] = rng() < mc.positionalConditionChance
			end
			return positionalSample[kind]
		end
		return true
	end
	local chargeTravel = sim.chargeTravelSeconds
	function ctx.boundSeconds(id)
		return BossSkillMath.boundSeconds(skills[id], arenaHalf, nil) -- 자리 비우기는 서버와 같은 상한으로
	end

	local limit = options.fixedSeconds or 2000
	while t < limit and (options.fixedSeconds or hp > 0) do
		if not current then
			ctx.now = t
			ctx.enraged = not options.fixedSeconds and hp / maxHp <= config.enragedHpFraction
			positionalSample = {}
			local pick = BossScheduler.pick(state, skills, order, config, ctx)
			if pick then
				local skill = skills[pick]
				BossScheduler.onSkillStart(state, pick)
				local jitter = rng and (1 + (rng() * 2 - 1) * mc.evadeJitter) or 1
				if rng and skill.primitive == "charge" then
					chargeTravel = mc.chargeTravelMinSeconds + rng() * (mc.chargeTravelMaxSeconds - mc.chargeTravelMinSeconds)
				end
				local bound = BossSkillMath.boundSeconds(skill, arenaHalf, chargeTravel)
				local judges = select(1, gateRoleOf(skill))
				local succeed = breaks == "always" or (breaks == "failFirst" and judgedIndex >= 1)
				if skill.primitive == "gimmick" and skill.sim and skill.sim.resolveSeconds and succeed then
					bound = skill.sim.resolveSeconds + (skill.recoverSeconds or 0) -- 제한 시간 전에 풀었다
				end
				current, currentEnd = pick, t + bound
				evadeUntil = math.max(evadeUntil, t + evadeSecondsOf(skill) * jitter)
				for _, effect in ipairs(skill.onImpact or {}) do
					if effect.type == "spawnProp" and boss.props and boss.props[effect.prop] then
						local made = skill.count + (skill.countPerMember or 0) * n
						propCounts[effect.prop] = math.min((propCounts[effect.prop] or 0) + made, boss.props[effect.prop].maxCount)
					end
				end
				counts[pick] += 1
				if #sequence < 40 then
					table.insert(sequence, { id = pick, at = t })
				end
				maxWait[pick] = math.max(maxWait[pick], t - lastStartAt[pick])
				lastStartAt[pick] = t
				if previousEnd then
					minGap = math.min(minGap, t - previousEnd)
				end
				if previousId then
					local a = BossSkillMath.mistakeShare(skills[previousId], surviveHits)
					local b = BossSkillMath.mistakeShare(skill, surviveHits)
					if a + b > worstPairSum then
						worstPairSum, worstPair = a + b, previousId .. " → " .. pick
					end
				end
				if skill.primitive == "gimmick" or skill.gate then
					gimmickCount += 1
					firstGimmickAt = firstGimmickAt or t
				end
				if judges or skill.primitive == "gimmick" then
					if judges and not gateStarted then
						gateStarted, armed, armedSince = true, true, t
					end
					local resolveAfter = (skill.sim and skill.sim.resolveSeconds and succeed) and skill.sim.resolveSeconds
						or (skill.primitive == "gimmick" and skill.telegraphSeconds or bound)
					pendingResolve, pendingSkill = t + resolveAfter, skill
				end
			end
		end
		if pendingResolve and t >= pendingResolve then
			local skill = pendingSkill
			pendingResolve, pendingSkill = nil, nil
			local judges, traps, window = gateRoleOf(skill)
			local succeed = breaks == "always" or (breaks == "failFirst" and judgedIndex >= 1)
			judgedIndex += 1
			if succeed then
				for _, effect in ipairs(skill.onResolve or {}) do
					if effect.type == "destroyProps" and effect.which == "shielding" then
						propCounts[effect.prop] = math.max((propCounts[effect.prop] or 0) - 1, 0)
					end
				end
			end
			if judges then
				if succeed then
					armed, armedSince = false, nil
					if window then
						windowMultiplier, windowUntil = window.damageTakenMultiplier, t + window.seconds
					end
				elseif not armed then
					armed, armedSince = true, t
				end
			end
			if not succeed and traps then
				evadeUntil = math.max(evadeUntil, t + trapSeconds)
			end
		end
		if current and t >= currentEnd then
			BossScheduler.onSkillEnd(state, skills, current, t)
			previousEnd, previousId = t, current
			current = nil
		end
		if t >= evadeUntil and not options.fixedSeconds then
			local multiplier = armed and gateMultiplier or (t < windowUntil and windowMultiplier or 1)
			hp -= n * multiplier * tick
		end
		t += tick
	end

	for id in pairs(counts) do
		maxWait[id] = math.max(maxWait[id], t - lastStartAt[id])
	end
	return {
		seconds = t,
		counts = counts,
		maxWaitSeconds = maxWait,
		firstGimmickAt = firstGimmickAt,
		gimmickCount = gimmickCount,
		minGapSeconds = minGap,
		worstAdjacentPair = worstPair,
		worstAdjacentShare = worstPairSum,
		sequence = sequence,
	}
end

-- seed 1..runs로 run을 돌려 처치 시간 분포를 낸다.
function BossSim.monteCarlo(bossId, options, runs)
	runs = runs or BossData.mechanics.sim.monteCarlo.runs
	local samples = {}
	local sum, firstGimmickLatest, gimmickMin = 0, 0, math.huge
	for seed = 1, runs do
		local opts = table.clone(options or {})
		opts.seed = seed * 7919
		local result = BossSim.run(bossId, opts)
		table.insert(samples, result.seconds)
		sum += result.seconds
		if result.firstGimmickAt then
			firstGimmickLatest = math.max(firstGimmickLatest, result.firstGimmickAt)
		end
		gimmickMin = math.min(gimmickMin, result.gimmickCount)
	end
	table.sort(samples)
	local function percentile(p)
		return samples[math.clamp(math.ceil(p * #samples), 1, #samples)]
	end
	return {
		runs = runs, mean = sum / runs, p5 = percentile(0.05), p50 = percentile(0.5), p95 = percentile(0.95),
		min = samples[1], max = samples[#samples],
		latestFirstGimmickAt = firstGimmickLatest, minGimmickCount = gimmickMin,
	}
end

-- 회피 부등식 표. rangeScale = 스테이지 범위 배율(BossRules.skillRangeScale), walkSpeedStuds = 검사 속도
-- (기본 = 신발 없는 기본 걷기 - 누구나 피할 수 있어야 한다).
-- 반환: { { skillId, label, availableSeconds, requiredSeconds, distanceStuds, ok }, ... }, 전부 통과했는가
function BossSim.checkDodge(bossId, rangeScale, walkSpeedStuds)
	local boss = BossData.bosses[bossId]
	local skills = BossSkillMath.scaleSkills(boss.skills, rangeScale or 1)
	local speed = walkSpeedStuds or WorldConfig.playerWalkSpeedStuds
	local rows, allOk = {}, true
	for _, id in ipairs(boss.skillOrder) do
		for _, check in ipairs(BossSkillMath.dodgeChecks(skills[id], boss.chaseStopDistanceStuds, speed)) do
			check.skillId = id
			table.insert(rows, check)
			allOk = allOk and check.ok
		end
	end
	return rows, allOk
end

-- 스테이지 밀도 검사기(S14, PRD 20.81 [C-3]): 밀도로 원이 늘어난 스킬이 여전히 "예고 안에 벗어날 수 있는가".
-- 배치는 BossPatterns.HANDLERS.circleTarget.start와 같은 규칙이다 - 첫 원 = 대상의 자리(원점), 나머지 = 원점 + (x, z 각각 [-1, 1] 균등)을 길이 1로 잘라
-- (밖은 단위원 둘레로 눌린다 - 코드가 단위원 안 균등이 아니라 상자 뽑기 + Unit이다) × scatterStuds'. 4인의 낙빙에서 다른 멤버 몫의 원은 실제로는 그 멤버의 발밑이지만
-- (위치를 알 수 없다) 전부 산개 원으로 친다 - 대상 곁에 원이 가장 많이 몰리는 경우라 d가 커지는 쪽(보수적)이다. 아레나 벽의 눌림(clampToZone)은 열린 땅으로 본다.
-- d = 원점에서 어느 원에도 안 덮인 가장 가까운 점까지(방위 directions개 × stepStuds 간격 - 격자라 실제보다 stepStuds 안쪽으로 크게 나온다 = 보수적).
-- t = 인지 + d ÷ 걷기 속도 × 여유(dodge와 같은 식). 몸 반폭(dodge.characterHalfWidthStuds)은 기준식에 없다 - 참고 열(pBody · maxBody)로만 함께 낸다.
-- options = { rangeScale(1), partySize(1), walkSpeedStuds(신발 없는 기본 걷기) }. 반환: nil(밀도 대상 스킬이 아님) 또는
-- { p99, max, mean, pBody, maxBody, telegraphSeconds, count, scatterStuds, radiusStuds, ok }. 난수는 자체 LCG(seed) - 로컬 하네스와 서버가 같은 값을 낸다.
function BossSim.checkDensity(bossId, skillId, extra, trials, seed, options)
	options = options or {}
	local boss = BossData.bosses[bossId]
	if not boss or not boss.skills[skillId] or not boss.skills[skillId].densityScalable then
		return nil
	end
	local density = BossData.mechanics.stageDensity
	local dodge = BossData.mechanics.dodge
	local skills = BossSkillMath.densifySkills(BossSkillMath.scaleSkills(boss.skills, options.rangeScale or 1), extra)
	local skill = skills[skillId]
	local total = skill.count + (skill.countPerMember or 0) * (options.partySize or 1)
	local radius, scatter = skill.radiusStuds, skill.scatterStuds
	local directions, step = density.check.directions, density.check.stepStuds
	local secondsPerStud = dodge.marginFactor / (options.walkSpeedStuds or WorldConfig.playerWalkSpeedStuds)
	local rng = newRng(seed)

	local dirX, dirZ = {}, {}
	for index = 1, directions do
		local angle = 2 * math.pi * (index - 1) / directions
		dirX[index], dirZ[index] = math.cos(angle), math.sin(angle)
	end
	-- 첫 원이 덮는 반경 이후의 첫 격자점부터 본다(그 안쪽은 정의상 덮여 있다).
	local firstRing = (math.floor(radius / step) + 1) * step
	local radiusSquared = radius * radius
	local centerX, centerZ = table.create(total), table.create(total)
	local samples, sum = table.create(trials), 0
	for trial = 1, trials do
		for index = 2, total do
			local offsetX, offsetZ = rng() * 2 - 1, rng() * 2 - 1
			local magnitude = math.sqrt(offsetX * offsetX + offsetZ * offsetZ)
			if magnitude > 1 then
				offsetX, offsetZ = offsetX / magnitude, offsetZ / magnitude
			end
			centerX[index], centerZ[index] = offsetX * scatter, offsetZ * scatter
		end
		local nearest = math.huge
		for direction = 1, directions do
			local ux, uz = dirX[direction], dirZ[direction]
			local distance = firstRing
			-- 이미 찾은 가장 가까운 점보다 먼 곳은 볼 필요가 없다.
			while distance < nearest do
				local px, pz = ux * distance, uz * distance
				local covered = false
				for index = 2, total do
					local dx, dz = px - centerX[index], pz - centerZ[index]
					if dx * dx + dz * dz <= radiusSquared then
						covered = true
						break
					end
				end
				if not covered then
					nearest = distance
					break
				end
				distance += step
			end
		end
		local seconds = dodge.perceptionSeconds + nearest * secondsPerStud
		samples[trial] = seconds
		sum += seconds
	end
	table.sort(samples)
	local bodySeconds = dodge.characterHalfWidthStuds * secondsPerStud
	local p99 = samples[math.clamp(math.ceil(density.check.percentile * trials), 1, trials)]
	local max = samples[trials]
	return {
		p99 = p99, max = max, mean = sum / trials, pBody = p99 + bodySeconds, maxBody = max + bodySeconds,
		telegraphSeconds = skill.telegraphSeconds, count = total, scatterStuds = scatter, radiusStuds = radius,
		ok = p99 <= skill.telegraphSeconds + 1e-9 and max <= skill.telegraphSeconds + density.check.maxOverSeconds + 1e-9,
	}
end

-- 인접 가능한 스킬 쌍 전수(설계 스킬 포함). b가 a 바로 다음에 올 수 있는가: b의 notAfter에 a가 없고, a == b면
-- 그 스킬의 쿨이 전역 쿨 이하일 때만(연속 금지는 다른 후보가 없을 때만 풀린다 - 쿨이 더 길면 준비 자체가 안 된다).
-- 반환: { { first, second, share, possible }, ... }(share 내림차순), 100%를 넘는 가능한 쌍의 수
function BossSim.checkPairs(bossId)
	local boss = BossData.bosses[bossId]
	local surviveHits = BalanceAnchorConfig.surviveTargetHits
	local rows, violations = {}, 0
	for _, a in ipairs(boss.skillOrder) do
		for _, b in ipairs(boss.skillOrder) do
			local possible = true
			for _, condition in ipairs(boss.skills[b].conditions or {}) do
				if condition.type == "notAfter" and table.find(condition.skills, a) then
					possible = false
				end
			end
			if a == b and boss.skills[a].cooldownSeconds > boss.scheduler.globalCooldownSeconds then
				possible = false
			end
			local shareA = BossSkillMath.mistakeShare(boss.skills[a], surviveHits)
			local shareB = BossSkillMath.mistakeShare(boss.skills[b], surviveHits)
			table.insert(rows, { first = a, second = b, share = shareA + shareB, possible = possible })
			if possible and shareA + shareB >= 1 then
				violations += 1
			end
		end
	end
	table.sort(rows, function(x, y)
		return x.share > y.share
	end)
	return rows, violations
end

return BossSim
