-- BR1 첫 도전 난이도 모형(docs/design/boss-br1.md §5) - 순수 계산. 실제 스케줄러(BossScheduler)로 패턴 순서를 내고, 판정마다 "첫 도전 실수 확률"로 맞을지를 굴린다.
--   목표(사용자): 첫 도전 솔로 45 ~ 90초 · 받은 피해 합 80 ~ 150%(최대체력 대비) · 전멸률 30 ~ 50%.
--   단위: 보스 HP = 기준 플레이어 순딜 referenceKillSeconds(60)초분 × N^p(BossSim과 같다) · 멤버 딜 1/초 · 피해 = 최대체력 비율.
--   가정 값 = BossData.mechanics.sim.difficulty(보고서에 같이 싣는다). 신규 보호(스테이지 1 ~ 20)는 넣지 않는다 - 그 밖의 스테이지 기준이다.
-- 모형이 넣는 것: 평타 노출 · 강화 평타 · 패턴 판정(무게 · 여유 · 종류) · 공중 회피 → 체공 → 대공 잡기(조건 · 대상) · 기믹 실패(85% + 잡힘 딜 0) ·
--   게이트(×g) · 기회 창 · 환경 변화(체력 50%부터 · 도트 · 겹침 미루기) · 격노. 넣지 않는 것: 흡혈 · 쉴드 · 물약 · 파티원 구출(잡힘은 자동 해제까지).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossRules = require(ReplicatedStorage.Shared.BossRules)
local BossScheduler = require(ReplicatedStorage.Shared.BossScheduler)
local BossSkillMath = require(ReplicatedStorage.Shared.BossSkillMath)
local BossOverlap = require(ReplicatedStorage.Shared.BossOverlap)
local BalanceAnchorConfig = require(ReplicatedStorage.Shared.data.BalanceAnchorConfig)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)

local BossDifficultySim = {}

local function newRng(seed)
	local state = seed % 2147483648
	return function()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
end

local ANTI_AIR = { projectile = true, grab = true }

-- 판정 목록: { at(스킬 시작부터 초), share(맞으면 최대체력 비율 · 현재 체력 비율이면 current = true), class(확률 키), slack, perMember }
local function judgmentsOf(skill, surviveHits)
	local list = {}
	local dodge = BossSkillMath.dodgeChecks(skill, 8, WorldConfig.playerWalkSpeedStuds)
	local minSlack = math.huge
	for _, check in ipairs(dodge) do
		minSlack = math.min(minSlack, check.availableSeconds - check.requiredSeconds)
	end
	if minSlack == math.huge then
		minSlack = 1
	end
	local single, total = BossSkillMath.damageShares(skill, surviveHits)
	local function weightClass(share)
		if share < 0.2 then
			return "small"
		elseif share < 0.35 then
			return "medium"
		end
		return "large"
	end
	local p = skill.primitive
	if p == "gimmick" then
		table.insert(list, { at = skill.telegraphSeconds, gimmick = true, slack = minSlack })
	elseif p == "grab" then
		table.insert(list, { at = skill.telegraphSeconds, grab = true, slack = minSlack })
	elseif p == "ring" then
		for _, wave in ipairs(BossSkillMath.ringWaves(skill)) do
			table.insert(list, { at = wave.startSeconds + 0.5, share = single, class = wave.air and "airWave" or "jump", slack = minSlack })
		end
	elseif p == "projectile" then
		for i = 1, skill.count or 1 do
			table.insert(list, { at = skill.telegraphSeconds + (skill.launchIntervalSeconds or 0) * (i - 1) + 1, share = single, class = (skill.targetRule and skill.targetRule ~= "target") and "antiAir" or weightClass(single), slack = minSlack, antiAir = skill.targetRule ~= nil and skill.targetRule ~= "target" })
		end
	elseif p == "circleTarget" and skill.shots then
		local at = 0
		for _, shot in ipairs(BossSkillMath.shotsOf(skill)) do
			at += shot.telegraphSeconds
			table.insert(list, { at = at, share = shot.multiplier / surviveHits, class = weightClass(shot.multiplier / surviveHits), slack = minSlack, ground = true })
		end
	elseif (p == "line" or p == "sector") and skill.volleyShots then
		local at = 0
		for _, volley in ipairs(BossSkillMath.volleysOf(skill)) do
			at += volley.telegraphSeconds
			table.insert(list, { at = at, share = volley.multiplier / surviveHits, class = weightClass(volley.multiplier / surviveHits), slack = minSlack, ground = true })
		end
	else
		local hits = math.max(1, math.floor(total / math.max(single, 1e-6) + 0.5))
		local bound = BossSkillMath.boundSeconds(skill, 96, 1.5)
		for i = 1, hits do
			table.insert(list, {
				at = math.min(skill.telegraphSeconds + (bound - skill.telegraphSeconds) * (i - 1) / math.max(hits, 1), bound),
				share = single, class = (p == "sector" and skill.jumpable) and "jump" or weightClass(single), slack = minSlack,
				maxHp = skill.damage.kind == "maxHp", ground = p ~= "vortex",
			})
		end
	end
	return list
end

-- options = { partySize(1), seed, role("ranged"/"melee"), stage(nil) }
function BossDifficultySim.run(bossId, options)
	options = options or {}
	local boss = BossData.bosses[bossId]
	local sim = BossData.mechanics.sim
	local cfg = sim.difficulty
	local rng = newRng(options.seed or 1)
	local tick = sim.tickSeconds
	local n = options.partySize or 1
	local surviveHits = BalanceAnchorConfig.surviveTargetHits
	local skills, order, config = boss.skills, boss.skillOrder, boss.scheduler
	local gateMultiplier = BossRules.gateDamageTakenMultiplier()
	local trapSeconds = BossData.mechanics.trap.autoReleaseSeconds
	local grabConfig = BossData.mechanics.airGrab
	local fail = BossData.mechanics.gimmickFail
	local env = boss.environment
	local exposure = cfg.basicExposure[options.role or "ranged"]
	local familiar = options.familiar == true
	local hitScale = familiar and cfg.familiar.hitScale or 1

	local maxHp = sim.referenceKillSeconds * BossRules.partySizeHpMultiplier(n)
	local hp = maxHp
	local members = {}
	for i = 1, n do
		members[i] = { hp = 1, taken = 0, alive = true, airUntil = -1, airSince = nil, evadeUntil = 0, trappedUntil = 0 }
	end
	local state = BossScheduler.newState(skills, order, 0, false)
	local t = 0
	local current, currentEnd, pending = nil, 0, {}
	local armed, gateStarted, windowMultiplier, windowUntil = false, false, 1, 0
	local gimmickSeen = 0
	local gateRounds = 0
	local failSeenBySkill = {} -- [기믹 id] = 이 판에서 본 횟수(처음 = firstMaxHpFraction)
	local gardenRounds = 0
	local envPhase, envAt, envUntil, envUsedImpossible = "idle", 0, 0, false
	local counts = {}
	local deferred = 0
	local basicTimer = 0

	local ctx = { graceUntil = config.entryGraceSeconds }
	function ctx.conditionMet(condition)
		local kind = condition.type
		if kind == "hpBelow" then
			return hp / maxHp <= condition.value
		elseif kind == "hpAbove" then
			return hp / maxHp > condition.value
		elseif kind == "memberAirborneFor" or kind == "memberAirborne" then
			for _, m in ipairs(members) do
				if m.alive and m.airSince and t < m.airUntil and t - m.airSince >= (condition.seconds or 0.2) then
					return true
				end
			end
			return false
		elseif kind == "gateArmed" then
			return armed == condition.value
		elseif kind == "gateArmedFor" then
			return armed
		elseif kind == "membersNearSafeSpot" then
			return true
		end
		return rng() < 0.6 -- 위치 조건(거리 · 밀집)
	end
	function ctx.boundSeconds(id)
		return BossSkillMath.boundSeconds(skills[id], 96, nil)
	end

	local bySource = {}
	local function damage(m, share, current_, source)
		if not m.alive then
			return
		end
		local dealt = current_ and m.hp * share or share
		bySource[source or "?"] = (bySource[source or "?"] or 0) + dealt
		m.hp -= dealt
		m.taken += dealt
		if m.hp <= 0 then
			m.alive = false
		end
	end

	local seenCount = {} -- [스킬] = 판정을 본 횟수(학습 - 두 번째부터 learnedMultiplier)
	local function hitChance(j)
		local base
		if j.gimmick then
			base = (gimmickSeen <= 1 and not familiar) and cfg.hitChance.gimmickFirst or cfg.hitChance.gimmickLater
		else
			base = (cfg.hitChance[j.class] or cfg.hitChance.medium) * hitScale
			if (seenCount[j.skill] or 0) > 1 then
				base *= cfg.learnedMultiplier
			end
		end
		if j.slack < cfg.slack.tightSeconds then
			base *= cfg.slack.tightMultiplier
		elseif j.slack > cfg.slack.looseSeconds then
			base *= cfg.slack.looseMultiplier
		end
		return math.clamp(base, 0, 0.95)
	end

	local function anyAlive()
		for _, m in ipairs(members) do
			if m.alive then
				return true
			end
		end
		return false
	end

	local limit = 400
	while t < limit and hp > 0 and anyAlive() do
		-- 환경 트랙
		if env then
			if envPhase == "idle" and hp / maxHp <= env.hpBelow then
				envPhase, envAt = "armed", t + env.firstDelaySeconds
			elseif (envPhase == "armed" or envPhase == "cooldown") and t >= envAt then
				envPhase, envAt, envUsedImpossible = "telegraph", t + env.telegraphSeconds, false
			elseif envPhase == "telegraph" and t >= envAt then
				envPhase, envUntil = "active", t + env.durationSeconds
				for _, m in ipairs(members) do
					if m.alive and rng() < cfg.hitChance.env then
						local ticks = cfg.envTicks.min + math.floor(rng() * (cfg.envTicks.max - cfg.envTicks.min + 1))
						local share = math.min(ticks * (env.tick and env.tick.fraction or 0), BossData.mechanics.environment.maxHpFractionPerActivation)
						if env.onStart and env.onStart.damage then
							share += env.onStart.damage.multiplier / surviveHits
						elseif env.onStart and env.onStart.seesaw then -- 널뛰기: 판 위 자리 평균(지렛대 0.5)
							share += (env.onStart.seesaw.minMultiplier + env.onStart.seesaw.maxMultiplier) / 2 / surviveHits
						end
						damage(m, share, nil, "환경")
					end
				end
			elseif envPhase == "active" and t >= envUntil then
				envPhase, envAt = "cooldown", t + env.cooldownSeconds
				if env.kind == "cores" then
					-- 수정 공중 정원: 두 핵을 창 안에 치면 기절(딜 창) · 못 치면 전원 기믹 실패(85%)
					gardenRounds = (gardenRounds or 0) + 1
					if rng() < ((gardenRounds <= 1 and not familiar) and cfg.gardenSolveChance.first or cfg.gardenSolveChance.later) then
						windowMultiplier, windowUntil = 1.3, t + env.garden.stunSeconds
					else
						for _, m in ipairs(members) do
							if m.alive then
								damage(m, gardenRounds <= 1 and fail.firstMaxHpFraction or fail.maxHpFraction, nil, "환경")
							end
						end
					end
				end
			end
		end
		if not current then
			ctx.now = t
			ctx.enraged = hp / maxHp <= config.enragedHpFraction
			local pick = BossScheduler.pick(state, skills, order, config, ctx)
			if pick and env and (envPhase == "telegraph" or envPhase == "active") and BossOverlap.classOf(boss.id, pick) == "impossible" then
				local overlap = BossData.mechanics.environment.overlap
				if envUsedImpossible or rng() < overlap.deferChance then
					state.readyAt[pick] = t + overlap.deferSeconds
					deferred += 1
					pick = nil
				else
					envUsedImpossible = true
				end
			end
			if pick then
				local skill = skills[pick]
				BossScheduler.onSkillStart(state, pick)
				counts[pick] = (counts[pick] or 0) + 1
				local bound = BossSkillMath.boundSeconds(skill, 96, 1.5)
				current, currentEnd = pick, t + bound
				local evade = (skill.sim and skill.sim.evadeSeconds) or cfg.evadeSeconds[skill.primitive] or 1.0
				for _, m in ipairs(members) do
					m.evadeUntil = math.max(m.evadeUntil, t + evade)
				end
				for _, j in ipairs(judgmentsOf(skill, surviveHits)) do
					j.at += t
					j.skill = skill
					j.id = pick
					table.insert(pending, j)
				end
				if skill.primitive == "gimmick" or skill.gate then
					if not gateStarted then
						gateStarted, armed = true, true
					end
				end
				if skill.gate then
					-- 게이트 판정 스킬(낙뢰): 회차가 끝날 때 풀었는가(가정 - gateSolveChance)
					gateRounds = (gateRounds or 0) + 1
					local chance = (gateRounds <= 1 and not familiar) and cfg.gateSolveChance.first or cfg.gateSolveChance.later
					table.insert(pending, { at = t + bound, gateJudge = true, solved = rng() < chance, skill = skill, id = pick })
				end
			end
		end
		-- 판정
		for i = #pending, 1, -1 do
			local j = pending[i]
			if t >= j.at then
				table.remove(pending, i)
				seenCount[j.skill] = (seenCount[j.skill] or 0) + 1
				if j.gateJudge then
					armed = not j.solved
					if j.solved and j.skill.gate.breakWindow then
						windowMultiplier, windowUntil = j.skill.gate.breakWindow.damageTakenMultiplier, t + j.skill.gate.breakWindow.seconds
					end
				elseif j.gimmick then
					gimmickSeen += 1
					failSeenBySkill[j.id] = (failSeenBySkill[j.id] or 0) + 1
					local anySafe = false
					for _, m in ipairs(members) do
						if m.alive and t >= m.trappedUntil then
							if rng() < hitChance(j) then
								local firstTime = (failSeenBySkill[j.id] or 0) <= 1
								damage(m, j.skill.failPenalty == false and 0 or (firstTime and fail.firstMaxHpFraction or fail.maxHpFraction), nil, j.id)
								if j.skill.failPenalty ~= false and j.skill.failTraps ~= false then
									m.trappedUntil = t + trapSeconds
									m.evadeUntil = math.max(m.evadeUntil, t + trapSeconds)
								end
							else
								anySafe = true
							end
						end
					end
					if j.skill.judgesGate ~= false then
						armed = not anySafe
						if anySafe and j.skill.breakWindow then
							windowMultiplier, windowUntil = j.skill.breakWindow.damageTakenMultiplier, t + j.skill.breakWindow.seconds
						end
					end
				elseif j.grab then
					for _, m in ipairs(members) do
						if m.alive and m.airSince and t < m.airUntil and t - m.airSince >= grabConfig.warnAirSeconds and rng() < cfg.grabCatchChance then
							-- 잡혔다: 들려 있다가(구출 없음 - 솔로 모형) 던짐 = 현재 체력 비율
							damage(m, grabConfig.currentHpFraction, true, j.id)
							m.evadeUntil = math.max(m.evadeUntil, t + grabConfig.holdSeconds)
							m.airSince, m.airUntil = nil, -1
						end
					end
				else
					for _, m in ipairs(members) do
						if m.alive and t >= m.trappedUntil then
							local chance = hitChance(j)
							local airborne = m.airSince and t < m.airUntil
							if j.antiAir and not airborne then
								chance *= 0.4 -- 땅에서는 걸어서 따돌린다
							elseif j.class == "airWave" and not airborne then
								chance *= 0.5
							end
							if rng() < chance then
								damage(m, j.share, nil, j.id)
							elseif j.ground and rng() < cfg.airDodgeShare then
								-- 공중으로 피했다 → 한동안 떠 있다(대공 잡기 · 대공 투사체의 조건)
								local air = cfg.airSecondsMin + rng() * (cfg.airSecondsMax - cfg.airSecondsMin)
								m.airSince, m.airUntil = t - 0.3, t - 0.3 + air
							end
						end
					end
				end
			end
		end
		if current and t >= currentEnd then
			BossScheduler.onSkillEnd(state, skills, current, t)
			current = nil
		end
		-- 자유 체공: 회피가 아니어도 이동 중에 뛴다(freeAirPerSecond - 평균 그 간격에 한 번, airSecondsMin ~ Max) → 대공 잡기 · 대공 투사체의 조건
		for _, m in ipairs(members) do
			if m.alive and not (m.airSince and t < m.airUntil) and rng() < cfg.freeAirPerSecond * tick then
				local air = cfg.airSecondsMin + rng() * (cfg.airSecondsMax - cfg.airSecondsMin)
				m.airSince, m.airUntil = t, t + air
			end
		end
		-- 평타(스킬 사이 · 사거리 안 몫만)
		if not current then
			basicTimer += tick
			if basicTimer >= boss.basicAttack.cooldownSeconds then
				basicTimer = 0
				local target = members[1 + math.floor(rng() * n)]
				if target.alive and t >= target.trappedUntil and rng() < exposure then
					damage(target, boss.basicAttack.damageMultiplier / surviveHits, nil, "평타")
				end
			end
		end
		-- 딜
		local multiplier = armed and gateMultiplier or (t < windowUntil and windowMultiplier or 1)
		if env and envPhase == "active" then
			multiplier *= cfg.envDpsMultiplier
		end
		for _, m in ipairs(members) do
			if m.alive and t >= m.evadeUntil then
				hp -= multiplier * tick
			end
		end
		t += tick
	end

	local takenSum, dead = 0, 0
	for _, m in ipairs(members) do
		takenSum += m.taken
		dead += m.alive and 0 or 1
	end
	return {
		seconds = t, killed = hp <= 0, wiped = not anyAlive(), deadCount = dead,
		takenAverage = takenSum / n, counts = counts, deferred = deferred, bySource = bySource,
	}
end

-- 여러 판(seed 1..runs): 처치 시간(처치한 판만) 분위 · 받은 피해 평균(1인) · 전멸률 · 스킬 등장 수.
function BossDifficultySim.monteCarlo(bossId, options, runs)
	runs = runs or BossData.mechanics.sim.difficulty.runs
	local times, taken, wipes, killed = {}, 0, 0, 0
	local counts, deferred, bySource = {}, 0, {}
	for seed = 1, runs do
		local opts = table.clone(options or {})
		opts.seed = seed * 7919 + 13
		local r = BossDifficultySim.run(bossId, opts)
		taken += r.takenAverage
		deferred += r.deferred
		if r.wiped then
			wipes += 1
		elseif r.killed then
			killed += 1
			table.insert(times, r.seconds)
		end
		for id, c in pairs(r.counts) do
			counts[id] = (counts[id] or 0) + c
		end
		for id, d in pairs(r.bySource) do
			bySource[id] = (bySource[id] or 0) + d / runs / (opts.partySize or 1)
		end
	end
	table.sort(times)
	local function pct(p)
		return #times > 0 and times[math.clamp(math.ceil(p * #times), 1, #times)] or 0
	end
	return {
		runs = runs, wipeRate = wipes / runs, killRate = killed / runs, takenMean = taken / runs,
		p10 = pct(0.1), p50 = pct(0.5), p90 = pct(0.9), counts = counts, deferredPerRun = deferred / runs, bySource = bySource,
	}
end

return BossDifficultySim
