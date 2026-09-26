-- BR1 첫 도전 난이도 모형 → BR1-2 갱신(docs/design/boss-br1-2.md §9) - 순수 계산. 실제 스케줄러(BossScheduler)로 패턴 순서를 내고, 판정마다 "첫 도전 실수 확률"로 맞을지를 굴린다.
--   목표(사용자): 솔로(원거리 · 근접) · 2인 · 4인 처치 45 ~ 90초 · 받은 피해 80 ~ 150% · 첫 도전 전멸 30 ~ 50%(근접 60% 이하). 스테이지 1 ~ 30은 보호 적용 뒤 따로.
--   단위: 보스 HP = 기준 플레이어 순딜 referenceKillSeconds(60)초분 × N^hpExponent · 멤버 딜 1/초 · 피해 = 최대체력 비율.
--   가정 값 = BossData.mechanics.sim.difficulty(보고서에 같이 싣는다).
-- BR1-2가 넣은 것: 스테이지 곡선(인당 투사체 · 범위 · 전조 - BossRules.buildInstanceData) · 신규 보호(스테이지 ≤ 30) · 평타 사거리 26(역할별 노출) · 근접 원형 구역(원 밖 전원 쓸기) ·
--   반사(원거리만) · 음파 포효(틱 · 엄폐) · 색 맞추기(인원이 많을수록 혼란) · 대공 잡기 발악(풀리면 기절) · 수정 부수기(보호막 동안 딜 0) · 파티 전역 쿨.
-- 넣지 않는 것: 흡혈 · 쉴드 · 물약 · 파티원 구출(잡힘은 자동 해제까지) · 반사를 몸으로 막기.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossRules = require(ReplicatedStorage.Shared.BossRules)
local BossScheduler = require(ReplicatedStorage.Shared.BossScheduler)
local BossSkillMath = require(ReplicatedStorage.Shared.BossSkillMath)
local BossOverlap = require(ReplicatedStorage.Shared.BossOverlap)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
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
	if p == "gimmick" or p == "colorMatch" then
		table.insert(list, { at = skill.telegraphSeconds, gimmick = true, slack = minSlack, fraction = p == "colorMatch" and skill.failMaxHpFraction or nil, color = p == "colorMatch" })
	elseif p == "lightningRods" then
		local total = skill.telegraphSeconds + skill.discharges * (skill.markSeconds + skill.trackSeconds + skill.lockSeconds + skill.gapSeconds)
		table.insert(list, { at = total, gimmick = true, slack = minSlack, fraction = skill.failMaxHpFraction })
		for i = 1, skill.discharges do
			table.insert(list, { at = skill.telegraphSeconds + i * (skill.markSeconds + skill.trackSeconds + skill.lockSeconds), share = skill.strike.multiplier / surviveHits, class = "small", slack = minSlack, ground = true, follow = true })
		end
	elseif p == "sonic" then
		table.insert(list, { at = skill.telegraphSeconds + skill.tickSeconds * skill.ticks, gimmick = true, sonic = true, slack = minSlack })
	elseif p == "reflect" and skill.counter then
		-- BR1-3 아르마딜로: 태세 중 때린 사람(근접 · 원거리 모두)에게 반격 가시(바닥 원 - 피할 수 있다)
		table.insert(list, { at = skill.telegraphSeconds + 1.5, reflect = true, counter = true, share = skill.counter.multiplier / surviveHits, slack = minSlack })
	elseif p == "reflect" then
		table.insert(list, { at = skill.telegraphSeconds + 1.5, reflect = true, share = skill.projectile.maxHpFraction, slack = minSlack })
	elseif p == "sandSearch" or p == "orgel" then
		-- BR1-3 파티 단위 전멸기(누가 풀어도 전원 성공 · 실패하면 전원 failMaxHpFraction) - 판정 한 번(party = 파티 한 번 굴림)
		table.insert(list, { at = skill.telegraphSeconds + skill.limitSeconds, gimmick = true, party = true, slack = minSlack, fraction = skill.failMaxHpFraction })
	elseif p == "grab" then
		table.insert(list, { at = skill.telegraphSeconds, grab = true, slack = minSlack })
	elseif p == "ring" then
		for _, wave in ipairs(BossSkillMath.ringWaves(skill)) do
			table.insert(list, { at = wave.startSeconds + 0.5, share = single, class = wave.air and "airWave" or "jump", slack = minSlack })
		end
	elseif p == "projectile" then
		-- 인당 count발(곡선) - 한 사람에게 줄지어 온다: 첫 발 = 기본 확률 · 둘째부터 × extraProjectileHit
		for i = 1, skill.count or 1 do
			table.insert(list, { at = skill.telegraphSeconds + (skill.launchIntervalSeconds or 0) * (i - 1) + 1, share = single, class = (skill.targetRule and skill.targetRule ~= "target") and "antiAir" or weightClass(single),
				slack = minSlack, antiAir = skill.targetRule ~= nil and skill.targetRule ~= "target", follow = i > 1 })
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

-- options = { partySize(1), seed, role("ranged"/"melee"), familiar(false), stage(100) }
function BossDifficultySim.run(bossId, options)
	options = options or {}
	local sim = BossData.mechanics.sim
	local cfg = sim.difficulty
	local rng = newRng(options.seed or 1)
	local tick = sim.tickSeconds
	local n = options.partySize or 1
	local stage = options.stage or 100
	local role = options.role or "ranged"
	local surviveHits = BalanceAnchorConfig.surviveTargetHits
	local data = BossRules.buildInstanceData(stage, bossId, n) -- 곡선 · 파티 전역 쿨이 얹힌 인스턴스 표
	local boss = BossData.bosses[bossId]
	local skills, order, config = data.skills, data.skillOrder, data.scheduler
	local gateMultiplier = BossRules.gateDamageTakenMultiplier()
	local trapSeconds = BossData.mechanics.trap.autoReleaseSeconds
	local grabConfig = BossData.mechanics.airGrab
	local fail = BossData.mechanics.gimmickFail
	local env = boss.environment
	local familiar = options.familiar == true
	local hitScale = familiar and cfg.familiar.hitScale or 1
	local protect = PlayerCombat.getNewbieDamageMultiplier(stage) -- 스테이지 1 ~ 30 신규 보호(최고 스테이지 = 이 스테이지로 본다)
	local exposureCfg = cfg.basicExposureBR12
	local innerCircle = data.innerSafeRadiusStuds ~= nil
	local exposure = role == "melee" and (innerCircle and exposureCfg.innerCircleMelee or exposureCfg.melee) or exposureCfg.ranged

	local hpScale = boss.hpMultiplier / (sim.referenceKillSeconds / BalanceAnchorConfig.killTargetSeconds) -- 보스별 HP 배율(수정 여왕 0.7 - 보호막 보정)
	local maxHp = sim.referenceKillSeconds * hpScale * BossRules.partySizeHpMultiplier(n)
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
	local failSeenBySkill = {}
	local envPhase, envAt, envUntil, envUsedImpossible = "idle", 0, 0, false
	local counts = {}
	local deferred = 0
	local basicTimer = 0
	local shieldUntil = -1 -- 수정 부수기(보호막) - 이때까지 딜 0

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
		elseif kind == "targetWithin" and innerCircle and condition.studs <= data.innerSafeRadiusStuds then
			return role == "melee" and rng() < 0.8 -- 원 안 강공격: 근접이 원 안에 있을 때
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
		local dealt = (current_ and m.hp * share or share) * protect
		bySource[source or "?"] = (bySource[source or "?"] or 0) + dealt
		m.hp -= dealt
		m.taken += dealt
		if m.hp <= 0 then
			m.alive = false
		end
	end

	local seenCount = {}
	local function hitChance(j)
		local base
		if j.gimmick then
			base = (gimmickSeen <= 1 and not familiar) and cfg.hitChance.gimmickFirst or cfg.hitChance.gimmickLater
			local own = j.skill and j.skill.sim and j.skill.sim.failChance -- BR1-3 스킬별 가정(수정 오르골 - 무작위 5개 기억)
			if own then
				base = (gimmickSeen <= 1 and not familiar) and own.first or own.later
			end
			if j.color then
				base *= 1 + cfg.colorPartyPenalty * (n - 1)
			end
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
				if env.kind == "jumpCourse" then
					-- 수정 부수기: 보호막 동안 딜 0 - 솔로는 두 코스 · 파티는 나눠서(가정 courseSeconds ± jitter)
					local base = n == 1 and cfg.courseSeconds.solo or cfg.courseSeconds.party
					local seconds = base * (1 + (rng() * 2 - 1) * cfg.courseSeconds.jitter)
					envPhase, envUntil = "active", t + seconds
					shieldUntil = envUntil
				else
					envPhase, envUntil = "active", t + env.durationSeconds
					for _, m in ipairs(members) do
						if m.alive and rng() < cfg.hitChance.env then
							local ticks = cfg.envTicks.min + math.floor(rng() * (cfg.envTicks.max - cfg.envTicks.min + 1))
							local share = math.min(ticks * (env.tick and env.tick.fraction or 0), BossData.mechanics.environment.maxHpFractionPerActivation)
							if env.fall and not env.onStart then -- 판 털기는 날아간 사람이 낙사 면제(날아감 = onStart 몫)
								share += env.fall.maxHpFraction -- BR1-3 무너진 바닥 낙사 한 번(가정)
							end
							if env.onStart and env.onStart.damage then
								share += env.onStart.damage.multiplier / surviveHits
							elseif env.onStart and env.onStart.pan then
								share += env.onStart.pan.multiplier / surviveHits
							end
							damage(m, share, nil, "환경")
						end
					end
				end
			elseif envPhase == "active" and t >= envUntil then
				envPhase, envAt = "cooldown", t + env.cooldownSeconds
				if env.kind == "jumpCourse" then
					windowMultiplier, windowUntil = 1, t + env.garden.stunSeconds -- 성공 뒤 기절(딜 창 - 배율 1)
				end
			end
		end
		if not current and t >= shieldUntil then -- 수정 부수기 동안 보스는 패턴을 쓰지 않는다(사용자)
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
				if skill.primitive == "gimmick" or skill.gate or skill.primitive == "sandSearch" or skill.primitive == "orgel" then -- BR1-3 새 전멸기도 게이트를 세운다(서버 onGimmickStart)
					if not gateStarted then
						gateStarted, armed = true, true
					end
				end
				if skill.gate then
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
				elseif j.gimmick and j.party then
					-- BR1-3 파티 단위: 실패 확률 = 1인 확률 ^ (1 + partySolveExponent × (인원 − 1))(여럿이 찾으면 쉽다 - 가정) · 실패면 살아 있는 전원 fraction
					gimmickSeen += 1
					-- M1 A안: 인원별 둔덕 수 · 제한 시간 · 순서 길이로 1인 실패 확률을 먼저 올린다(BossSkillMath.partyGimmickHardness - 가정)
					local single = 1 - (1 - hitChance(j)) ^ BossSkillMath.partyGimmickHardness(j.skill, n)
					-- M1-2 C안: 멤버마다 오답 한 번(확률 = 1인 실패 × partyWrongPressFactor) → 본인 벌(decoyBlast · wrongShock) + 파티면 전원 partyShareMaxHp × 오답 수
					local wrong = j.skill.decoyBlast or j.skill.wrongShock
					if wrong and cfg.partyWrongPressFactor then
						local wrongs = 0
						for _, m in ipairs(members) do
							if m.alive and t >= m.trappedUntil and rng() < single * cfg.partyWrongPressFactor then
								wrongs += 1
								damage(m, wrong.multiplier / surviveHits, nil, j.id .. " 오답")
							end
						end
						local share = wrong.partyShareMaxHpByParty and wrong.partyShareMaxHpByParty[math.min(n, #wrong.partyShareMaxHpByParty)] or 0
						if wrongs > 0 and share > 0 then
							for _, m in ipairs(members) do
								damage(m, share * wrongs, nil, "공동 책임(오답)")
							end
						end
					end
					local failed = rng() < single ^ (1 + cfg.partySolveExponent * (n - 1))
					for _, m in ipairs(members) do
						if m.alive and t >= m.trappedUntil and failed then
							damage(m, j.fraction, nil, j.id)
						end
					end
					armed = failed
					if not failed and j.skill.breakWindow then
						windowMultiplier, windowUntil = j.skill.breakWindow.damageTakenMultiplier, t + j.skill.breakWindow.seconds
					end
				elseif j.gimmick then
					gimmickSeen += 1
					failSeenBySkill[j.id] = (failSeenBySkill[j.id] or 0) + 1
					local anySafe = false
					for _, m in ipairs(members) do
						if m.alive and t >= m.trappedUntil then
							local failed = rng() < hitChance(j)
							if j.sonic then
								-- 음파: 실패 = 가려진 틱이 min ~ max뿐(나머지 틱 × 15%) · 성공 = 한 틱 늦게 숨음(30%)
								local skill = j.skill
								local safeTicks = failed and (cfg.sonicSafeTicks.min + math.floor(rng() * (cfg.sonicSafeTicks.max - cfg.sonicSafeTicks.min + 1))) or (rng() < 0.3 and skill.ticks - 1 or skill.ticks)
								damage(m, skill.tickFraction * (skill.ticks - safeTicks), nil, j.id)
								anySafe = anySafe or not failed
							elseif failed then
								m.failedGimmickAt = t
								local firstTime = (failSeenBySkill[j.id] or 0) <= 1
								local fraction = j.fraction or (j.skill.failPenalty == false and 0 or (firstTime and fail.firstMaxHpFraction or fail.maxHpFraction))
								damage(m, fraction, nil, j.id)
								if j.skill.primitive == "gimmick" and j.skill.failPenalty ~= false and j.skill.failTraps ~= false then
									m.trappedUntil = t + trapSeconds
									m.evadeUntil = math.max(m.evadeUntil, t + trapSeconds)
								end
							else
								anySafe = true
							end
						end
					end
					-- BR1-2 파티 공동 책임(설계 §8 - 기믹 요구 증가): 전멸기를 누가 실패하면 나머지도 실패한 인원 × partyFailShare(보호막 무시)
					if n > 1 and cfg.partyFailShare and cfg.partyFailShare > 0 and not j.sonic and j.skill.failPenalty ~= false then
						local failedCount = 0
						for _, m in ipairs(members) do
							failedCount += (m.failedGimmickAt == t) and 1 or 0
						end
						if failedCount > 0 then
							for _, m in ipairs(members) do
								if m.alive and m.failedGimmickAt ~= t then
									damage(m, cfg.partyFailShare * failedCount, nil, "공동 책임")
								end
							end
						end
					end
					if j.skill.primitive == "gimmick" and j.skill.judgesGate ~= false then
						armed = not anySafe
						if anySafe and j.skill.breakWindow then
							windowMultiplier, windowUntil = j.skill.breakWindow.damageTakenMultiplier, t + j.skill.breakWindow.seconds
						end
					end
				elseif j.reflect then
					-- 반사: 원거리만(근접 평타는 반사 대상이 아니다) - 되돌아온 것에 맞을 확률(처음 · 두 번째부터)
					if role == "ranged" or j.counter then
						for _, m in ipairs(members) do
							local chance = ((seenCount[j.skill] or 0) <= 1 and not familiar) and cfg.reflectHit.first or cfg.reflectHit.later
							if m.alive and t >= m.trappedUntil and rng() < chance * hitScale then
								damage(m, j.share, nil, j.id)
							end
						end
					end
				elseif j.grab then
					local caught = 0
					for _, m in ipairs(members) do
						if m.alive and m.airSince and t < m.airUntil and t - m.airSince >= grabConfig.warnAirSeconds and rng() < cfg.grabCatchChance then
							caught += 1
							m.airSince, m.airUntil = nil, -1
							m.caught = true
						end
					end
					if caught > 0 then
						if rng() < cfg.grabEscape then
							windowMultiplier, windowUntil = 1, t + grabConfig.stunSeconds -- 발악 성공 = 기절(딜 창)
							for _, m in ipairs(members) do
								if m.caught then
									m.evadeUntil = math.max(m.evadeUntil, t + 3)
									m.caught = nil
								end
							end
						else
							for _, m in ipairs(members) do
								if m.caught then
									damage(m, grabConfig.currentHpFraction, true, j.id)
									m.evadeUntil = math.max(m.evadeUntil, t + grabConfig.holdSeconds + 2)
									m.caught = nil
								end
							end
						end
					end
				else
					for _, m in ipairs(members) do
						if m.alive and t >= m.trappedUntil then
							local chance = hitChance(j)
							if j.follow then
								chance *= cfg.extraProjectileHit
							end
							local airborne = m.airSince and t < m.airUntil
							if j.antiAir and not airborne then
								chance *= 0.4 -- 땅에서는 걸어서 따돌린다
							elseif j.class == "airWave" and not airborne then
								chance *= 0.5
							end
							if t < shieldUntil and j.ground then
								chance *= cfg.courseGroundHitScale -- 수정 부수기: 점프맵 위 사람은 바닥 판정을 덜 맞는다
							end
							if rng() < chance then
								damage(m, j.share, nil, j.id)
							elseif j.ground and rng() < cfg.airDodgeShare then
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
		for _, m in ipairs(members) do
			if m.alive and not (m.airSince and t < m.airUntil) and rng() < cfg.freeAirPerSecond * tick then
				local air = cfg.airSecondsMin + rng() * (cfg.airSecondsMax - cfg.airSecondsMin)
				m.airSince, m.airUntil = t, t + air
			end
		end
		-- 평타(스킬 사이): 근접 원형 구역 보스는 원 밖 전원을 쓴다 · 아니면 한 명(수정 부수기 동안은 없다)
		if not current and t >= shieldUntil then
			basicTimer += tick
			if basicTimer >= boss.basicAttack.cooldownSeconds then
				basicTimer = 0
				local share = boss.basicAttack.damageMultiplier / surviveHits
				if innerCircle then
					for _, m in ipairs(members) do
						if m.alive and t >= m.trappedUntil and rng() < exposure * (t < shieldUntil and cfg.courseGroundHitScale or 1) then
							damage(m, share, nil, "평타")
						end
					end
				else
					local target = members[1 + math.floor(rng() * n)]
					if target.alive and t >= target.trappedUntil and rng() < exposure * (t < shieldUntil and cfg.courseGroundHitScale or 1) then
						damage(target, share, nil, "평타")
					end
				end
			end
		end
		-- 딜
		local multiplier = armed and gateMultiplier or (t < windowUntil and windowMultiplier or 1)
		if env and envPhase == "active" then
			multiplier *= cfg.envDpsMultiplier
		end
		if t < shieldUntil then
			multiplier = 0 -- 보호막(수정 부수기)
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

-- 여러 판(seed 1..runs): 처치 시간(처치한 판만) 분위 · 받은 피해 평균(1인) · 전멸률 · 한 명 이상 사망률 · 스킬 등장 수.
function BossDifficultySim.monteCarlo(bossId, options, runs)
	runs = runs or BossData.mechanics.sim.difficulty.runs
	local times, taken, wipes, killed, anyDead = {}, 0, 0, 0, 0
	local counts, deferred, bySource = {}, 0, {}
	for seed = 1, runs do
		local opts = table.clone(options or {})
		opts.seed = seed * 7919 + 13
		local r = BossDifficultySim.run(bossId, opts)
		taken += r.takenAverage
		deferred += r.deferred
		anyDead += r.deadCount > 0 and 1 or 0
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
		runs = runs, wipeRate = wipes / runs, killRate = killed / runs, takenMean = taken / runs, deathRate = anyDead / runs,
		p10 = pct(0.1), p50 = pct(0.5), p90 = pct(0.9), counts = counts, deferredPerRun = deferred / runs, bySource = bySource,
	}
end

return BossDifficultySim
