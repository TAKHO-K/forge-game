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
local BossOrigin = require(ReplicatedStorage.Shared.BossOrigin)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local BalanceAnchorConfig = require(ReplicatedStorage.Shared.data.BalanceAnchorConfig)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local DashConfig = require(ReplicatedStorage.Shared.data.DashConfig) -- FINAL-1b 3단계 대시 회피

local BossDifficultySim = {}

local function newRng(seed)
	local state = seed % 2147483648
	return function()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
end

-- 판정 목록: { at(스킬 시작부터 초), share(맞으면 최대체력 비율 · 현재 체력 비율이면 current = true), class(확률 키), slack, perMember }
local function judgmentsOf(skill, surviveHits, standoff, originForward)
	local list = {}
	local dodge = BossSkillMath.dodgeChecks(skill, standoff or 8, WorldConfig.playerWalkSpeedStuds, originForward) -- GUARDIAN-V2: 서 있는 거리 = 추격 정지 거리(6보스 모두 8 - 몸 가장자리 장치가 켜진 새 몸만 늘어난다) · BOSS-NIGHT-2 C 발생 지점
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

-- options = { partySize(1), seed, role("ranged"/"melee"), familiar(false), stage(100), bodyEdgeRig(GUARDIAN-V2 - 새 몸 리그 키: 실전 스폰과 같은 몸 가장자리 반경 · 밸런스 사본),
--   noV3(GUARDIAN-V3 - true면 V3 설정을 얹지 않는다 = V2 비교), origin(BOSS-NIGHT-2 C - true면 bodyEdgeRig의 발생 지점 표(BossOriginData)를 회피 여유 계산에 넣는다 · 기본 끔 = 옛 값), assistFails(첫 보스 도움 - 이번 판 앞의 전멸 수 → 받는 피해 배율) }
-- GUARDIAN-V3 반응 스킬(바나나 · 도약 - BossScheduler ⑧): 대상이 30 stud 밖인 구간을 가정으로 굴린다(원거리 rangedFarShare · 근접 meleeFarShare - 구간 평균 farSegmentSeconds) →
--   조건이 차면 패턴이 안 도는 틈에 시작 · 바나나 명중 = bananaHit(처음 · 두 번째부터) · 빗나감 2회/12초 → 도약(leapHit) · 도약 뒤 대상은 가까이(구간 끝). 가정 값 = BossFrameworkData.v3[보스].sim.
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
	if options.bodyEdgeRig then
		local BossFramework = require(ReplicatedStorage.Shared.BossFramework)
		data = BossFramework.applyBodyEdge(data, options.bodyEdgeRig, WorldConfig.playerWalkSpeedStuds)
		if not options.noV3 then
			data = BossFramework.applyV3(data, options.bodyEdgeRig) -- GUARDIAN-V3(실전 spawnEncounter와 같은 순서)
		end
	end
	local v3sim = data.v3 and data.v3.sim
	local boss = BossData.bosses[bossId]
	local skills, order, config = data.skills, data.skillOrder, data.scheduler
	local gateMultiplier = BossRules.gateDamageTakenMultiplier()
	local trapSeconds = BossData.mechanics.trap.autoReleaseSeconds
	local grabConfig = BossData.mechanics.airGrab
	local fail = BossData.mechanics.gimmickFail
	local env = boss.environment
	local familiar = options.familiar == true
	local hitScale = familiar and cfg.familiar.hitScale or 1
	local dashSim = options.dash and cfg.dash or nil -- FINAL-1b 3단계 대시 회피(가정 = cfg.dash · 값 = DashConfig)
	local dashCharges = options.dashCharges or 1
	local walk = WorldConfig.playerWalkSpeedStuds
	local dashUses = { short = 0, long = 0, protectOnly = 0, protected = 0 }
	local protect = PlayerCombat.getNewbieDamageMultiplier(stage) -- 스테이지 1 ~ 30 신규 보호(최고 스테이지 = 이 스테이지로 본다)
	if data.firstAssist and options.assistFails then -- GUARDIAN-V3 첫 보스 도움(받는 피해 배율 - 모든 피해)
		protect *= require(ReplicatedStorage.Shared.BossFramework).assistMultiplier(data.firstAssist, options.assistFails, false)
	end
	local exposureCfg = cfg.basicExposureBR12
	local innerCircle = data.innerSafeRadiusStuds ~= nil
	local exposure = role == "melee" and (innerCircle and exposureCfg.innerCircleMelee or exposureCfg.melee) or exposureCfg.ranged

	local hpScale = boss.hpMultiplier / (sim.referenceKillSeconds / BalanceAnchorConfig.killTargetSeconds) -- 보스별 HP 배율(수정 여왕 0.7 - 보호막 보정)
	local dmgScale = data.bodyEdgeDamageScale or 1 -- GUARDIAN-V2: 새 몸 밸런스 - 평타(모형은 BossData 평타 배율을 읽는다 · 스킬 배율은 data.skills 사본에 이미 곱해짐)
	local maxHp = sim.referenceKillSeconds * hpScale * BossRules.partySizeHpMultiplier(n) * (data.bodyEdgeHpScale or 1) -- GUARDIAN-V2: 새 몸 밸런스(BossFrameworkData.bodyEdge.hpScale)
	local hp = maxHp
	local members = {}
	for i = 1, n do
		members[i] = { hp = 1, taken = 0, alive = true, airUntil = -1, airSince = nil, evadeUntil = 0, trappedUntil = 0, dashReadyAt = -math.huge, dashSecondUntil = -math.huge }
	end
	local state = BossScheduler.newState(skills, order, 0, false, config)
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
	local tgDone = false -- BOSS-NIGHT-1 변신 무적 한 번

	local ctx = { graceUntil = config.entryGraceSeconds, rng = rng } -- BOSS-NIGHT-3 addendum-2 15: 가중치 뽑기(실전과 같은 규칙)
	-- GUARDIAN-V3 반응 스킬 상태: 대상이 멀리(30 stud 밖) 있는 구간 · 빗나감 기록
	local far, farSince, farUntil, missLog = false, nil, 0, {}
	local farShare = v3sim and (role == "ranged" and v3sim.rangedFarShare or v3sim.meleeFarShare) or 0
	-- BOSS-NIGHT-1 뒤쪽 반응 스킬(매머드 뒷발차기): 대상이 등 뒤에 머무는 구간(behindShare - 근접 · 원거리 · 평균 behindSegmentSeconds)
	local behind, behindSince, behindUntil = false, nil, 0
	local behindShare = (v3sim and v3sim.behindShare) and (v3sim.behindShare[role] or 0) or 0
	function ctx.conditionMet(condition)
		local kind = condition.type
		if kind == "targetBehindFor" then
			return behind and behindSince ~= nil and t - behindSince >= condition.seconds
		elseif kind == "targetBeyondFor" then
			return far and farSince ~= nil and t - farSince >= condition.seconds
		elseif kind == "memberBeyond" then -- BOSS-NIGHT-2 3 수정 여왕 마법 미사일: 원거리 구간(far)에 있으면 바로(솔로 모형 = 대상 한 명)
			return far
		elseif kind == "missesWithin" then
			local n = 0
			for _, at in ipairs(missLog) do
				n += (t - at <= condition.seconds) and 1 or 0
			end
			return n >= condition.count
		elseif kind == "hpBelow" then
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

	-- 대시 시도(준비됐고 쓸 확률을 넘으면): 쿨 · 2단 창을 기록하고 true. 일반 판정 · 반응 스킬 판정이 같이 쓴다(BOSS-NIGHT-3 7단계 VERIFY-2 10).
	local function tryDash(m, t)
		if not (dashSim and (t >= m.dashReadyAt or t <= m.dashSecondUntil) and rng() < (familiar and dashSim.useChance.familiar or dashSim.useChance.first)) then
			return false
		end
		if t <= m.dashSecondUntil then
			m.dashSecondUntil, m.dashReadyAt = -math.huge, t + DashConfig.cooldownSeconds -- 2단 대시 두 번째 = 쿨 시작
		else
			m.dashReadyAt = t + DashConfig.cooldownSeconds
			m.dashSecondUntil = dashCharges >= 2 and t + DashConfig.primordialShoes.chainWindowSeconds or -math.huge
		end
		return true
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
	local function hitChance(j, slackOverride)
		local slack = slackOverride or j.slack
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
		if slack < cfg.slack.tightSeconds then
			base *= cfg.slack.tightMultiplier
		elseif slack > cfg.slack.looseSeconds then
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
								share += env.fall.wipe and BossData.mechanics.gimmickFail.firstMaxHpFraction or env.fall.maxHpFraction -- BR1-3 무너진 바닥 낙사 한 번(가정) · BR1-4a 붕괴 = 전멸기 첫 낙하
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
		-- BOSS-NIGHT-1: 등 뒤 구간 굴리기(근접 = 가끔 · 원거리 = 드물게)
		if behindShare > 0 and t >= behindUntil then
			local mean = v3sim.behindSegmentSeconds or 3
			if behind then
				behind, behindSince = false, nil
				behindUntil = t + mean * (1 - behindShare) / math.max(behindShare, 1e-3) * (0.5 + rng())
			else
				behind, behindSince = true, t
				behindUntil = t + mean * (0.5 + rng())
			end
		end
		-- GUARDIAN-V3: 멀리 있는 구간 굴리기(원거리 = 대부분 · 근접 = 가끔)
		if v3sim and v3sim.farSegmentSeconds and t >= farUntil then
			local mean = v3sim.farSegmentSeconds
			if far then
				far, farSince = false, nil
				farUntil = t + mean * (1 - farShare) / math.max(farShare, 1e-3) * (0.5 + rng())
			else
				far, farSince = true, t
				farUntil = t + mean * (0.5 + rng())
			end
		end
		-- BOSS-NIGHT-1 폭풍 변신 무적(v3.transformGuard): 처음 hpBelow 아래 = 진행 중 스킬 끊김 · seconds 동안 딜 0 · 패턴 없음(보호막과 같은 처리)
		local tg = data.v3 and data.v3.transformGuard
		if tg and not tgDone and hp / maxHp <= (tg.hpBelow or 0.5) then
			tgDone = true
			currentEnd = math.min(currentEnd, t) -- 끝 처리(스케줄러 onSkillEnd)는 아래 평소 경로가 한다
			for i = #pending, 1, -1 do
				if not pending[i].gateJudge then
					table.remove(pending, i)
				end
			end
			shieldUntil = math.max(shieldUntil, t + tg.seconds)
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
				BossScheduler.onSkillStart(state, pick, t, skills, config)
				counts[pick] = (counts[pick] or 0) + 1
				local bound = BossSkillMath.boundSeconds(skill, 96, 1.5)
				current, currentEnd = pick, t + bound
				local evade = (skill.sim and skill.sim.evadeSeconds) or cfg.evadeSeconds[skill.primitive] or 1.0
				for _, m in ipairs(members) do
					m.evadeUntil = math.max(m.evadeUntil, t + evade)
				end
				local originForward = nil -- BOSS-NIGHT-2 C: 발생 지점이 대상 쪽으로 앞선 거리(크기 배율 · 폼 = 체력 50% - 실전 BossOrigin.point와 같은 값)
				if options.origin and options.bodyEdgeRig then
					local p = BossOrigin.point(options.bodyEdgeRig, data.sizeScale, hp / maxHp, pick, Vector3.zero, Vector3.new(0, 0, -100), 0)
					originForward = p and -p.Z or nil
				end
				local beamJump = skill.beamFromOrigin and skill.beamFromOrigin.jumpOverMinRebirth and (options.rebirth or 0) >= skill.beamFromOrigin.jumpOverMinRebirth -- BOSS-NIGHT-3 7단계: 빔 점프 회피(환생별)
				for _, j in ipairs(judgmentsOf(skill, surviveHits, data.chaseStopDistanceStuds, originForward)) do
					j.at += t
					j.skill = skill
					j.id = pick
					if beamJump then
						j.class = "jump" -- 2단 점프로 넘는 레이저 = 점프 판정 확률(hitChance.jump) · 대시 거리 몫 없음(noDistanceClasses)
					end
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
		-- GUARDIAN-V3 ⑧ 반응 스킬: 패턴이 안 도는 틈 · 전역 쿨 무관
		if not current and t >= shieldUntil and data.reactiveOrder then
			ctx.now = t
			local id = BossScheduler.pickReactive(state, skills, data.reactiveOrder, ctx)
			if id then
				local skill = skills[id]
				counts[id] = (counts[id] or 0) + 1
				for _, o in ipairs(skill.overrides or {}) do
					if hp / maxHp <= o.hpBelow then
						skill = table.clone(skill)
						for k, v in pairs(o.set) do
							skill[k] = v
						end
						break
					end
				end
				if id == "leap" then
					missLog = {}
				end
				local flight = skill.flightSeconds or 0.3
				current, currentEnd = id, t + skill.telegraphSeconds + flight
				table.insert(pending, { at = t + skill.telegraphSeconds + flight, reactive = id, skill = skills[id], shots = skill.count or 1, id = id })
			end
		end
		-- 판정
		for i = #pending, 1, -1 do
			local j = pending[i]
			if t >= j.at then
				table.remove(pending, i)
				seenCount[j.skill] = (seenCount[j.skill] or 0) + 1
				if j.reactive then
					-- GUARDIAN-V3 바나나 · 도약: 대상 한 명(살아 있는 사람 중 무작위)
					local alive = {}
					for _, m in ipairs(members) do
						if m.alive and t >= m.trappedUntil then
							table.insert(alive, m)
						end
					end
					local m = alive[1 + math.floor(rng() * math.max(#alive, 1))]
					local first = (seenCount[j.skill] or 0) <= 1 and not familiar
					-- BOSS-NIGHT-3 7단계(VERIFY-2 10): 반응 스킬에도 대시 - 쓸 확률 · 맞아도 보호 창 확률만큼 × 0.5 · 대시 통과 스킬(수정 미사일) = 피해 0. 명중 가정 값은 그대로(보수적).
					local dashed = m ~= nil and tryDash(m, t)
					if dashed then
						dashUses.reactive = (dashUses.reactive or 0) + 1
					end
					local function reactiveDamage(share, source)
						if dashed and rng() < dashSim.protectOverlap then
							dashUses.protected += 1
							if j.skill.passThrough ~= "dash" then
								damage(m, share * DashConfig.incomingDamageMultiplier, nil, source)
							end
						else
							damage(m, share, nil, source)
						end
					end
					if m and j.reactive == "banana" then
						local hc = (first and v3sim.bananaHit.first or v3sim.bananaHit.later) * hitScale
						local ref = v3sim.bananaHit.refSpeedStuds
						if ref and j.skill.speedStuds and j.skill.speedStuds < ref then -- BOSS-NIGHT-3 3단계(VERIFY-2 7): 가정 명중률 = 속도 ref 기준 → 피할 여유(예고 + 25 ÷ 속도 − 반응)가 늘어난 비로 낮춘다
							local rule = BossData.mechanics.projectileDodge
							local function spare(speed)
								return math.max(j.skill.telegraphSeconds + rule.distanceStuds / speed - rule.reactionSeconds, 0.05)
							end
							hc *= spare(ref) / spare(j.skill.speedStuds)
						end
						local hits = 0
						for k = 1, j.shots do
							if rng() < hc * (k > 1 and cfg.extraProjectileHit or 1) then
								hits += 1
							end
						end
						if hits > 0 then
							reactiveDamage(j.skill.damage.fraction * hits, "바나나")
						else
							table.insert(missLog, t)
						end
					elseif m and j.reactive == "leap" then
						local hc = (first and v3sim.leapHit.first or v3sim.leapHit.later) * hitScale
						if rng() < hc then
							reactiveDamage(j.skill.damage.multiplier / surviveHits, "도약")
						end
						far, farSince, farUntil = false, nil, t -- 도약 뒤 = 가까이(다음 틱에 구간을 새로 굴린다)
					elseif m and v3sim.hit and v3sim.hit[j.reactive] then
						-- BOSS-NIGHT-1 일반 반응 스킬(뒷발차기): 명중 = hit[id](처음 · 두 번째부터) · 피해 = 공격력 배율 ÷ 생존 타수 · 맞든 아니든 구간 끝(밀려남 · 비킴)
						local h = v3sim.hit[j.reactive]
						if rng() < (first and h.first or h.later) * hitScale then
							reactiveDamage(j.skill.damage.multiplier * (h.damageScale or 1) / surviveHits, j.skill.damageLabel) -- BOSS-NIGHT-2: damageScale = 검기 평균 거리 배율
						end
						if not h.keepFar then -- BOSS-NIGHT-2: 원거리 반응 스킬(검기 · 전류 구슬)은 대상이 멀리 있는 구간을 끊지 않는다(뒷발차기 = 밀려나 구간 끝)
							behind, behindSince, behindUntil = false, nil, t
						end
					end
				elseif j.gateJudge then
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
							-- FINAL-1b 3단계: 대시(준비됐고 피하려 하면) = 번 시간만큼 회피 여유 + 맞아도 보호 창 확률만큼 × 0.5(통과 스킬 = 0)
							local slackOverride = nil
							local dashed = tryDash(m, t)
							if dashed then
								if not dashSim.noDistanceClasses[j.class] then
									local shortSaved = DashConfig.modes.short.rangeStuds / walk - DashConfig.modes.short.durationSeconds
									local longSaved = DashConfig.rangeStuds / walk - DashConfig.durationSeconds
									local saved = (j.slack + shortSaved > cfg.slack.looseSeconds) and shortSaved or longSaved
									slackOverride = j.slack + saved
									dashUses[saved == shortSaved and "short" or "long"] += 1
								else
									dashUses.protectOnly += 1
								end
							end
							local chance = hitChance(j, slackOverride)
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
								if dashed and rng() < dashSim.protectOverlap then
									if not (j.skill and j.skill.passThrough == "dash") then -- 미사일 통과 = 피해 0
										damage(m, j.share * DashConfig.incomingDamageMultiplier, nil, j.id)
									end
									dashUses.protected += 1
								else
									damage(m, j.share, nil, j.id)
								end
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
			if skills[current] and skills[current].reactive then
				BossScheduler.onReactiveEnd(state, skills, current, t) -- GUARDIAN-V3 ⑧: 전역 쿨 그대로
			else
				BossScheduler.onSkillEnd(state, skills, current, t, config)
			end
			current = nil
		end
		for _, m in ipairs(members) do
			if m.alive and not (m.airSince and t < m.airUntil) and rng() < cfg.freeAirPerSecond * tick then
				local air = cfg.airSecondsMin + rng() * (cfg.airSecondsMax - cfg.airSecondsMin)
				m.airSince, m.airUntil = t, t + air
			end
		end
		-- 평타(스킬 사이): 근접 원형 구역 보스는 원 밖 전원을 쓴다 · 아니면 한 명(수정 부수기 동안은 없다)
		if not current and t >= shieldUntil and not data.basicDisabled then -- BOSS-NIGHT-2 3: 근접 평타 없는 보스(수정 여왕 = 마법 미사일)
			basicTimer += tick
			if basicTimer >= boss.basicAttack.cooldownSeconds then
				basicTimer = 0
				local share = boss.basicAttack.damageMultiplier / surviveHits * dmgScale
				if innerCircle then
					local lanes = BossData.mechanics.lanes
					for _, m in ipairs(members) do
						local roll = rng()
						local ground = t < shieldUntil and cfg.courseGroundHitScale or 1
						if m.alive and t >= m.trappedUntil and roll < exposure * ground then
							damage(m, share, nil, "평타")
						elseif m.alive and t >= m.trappedUntil and lanes and lanes.enabled and role == "melee" and roll < (exposure + exposureCfg.innerSwingMelee) * ground then
							damage(m, share * lanes.innerSwingScale, nil, "평타(원 안)") -- A2-N4 원 안 약한 휘두름
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
		takenAverage = takenSum / n, counts = counts, deferred = deferred, bySource = bySource, dashUses = dashUses,
	}
end

-- 여러 판(seed 1..runs): 처치 시간(처치한 판만) 분위 · 받은 피해 평균(1인) · 전멸률 · 한 명 이상 사망률 · 스킬 등장 수.
function BossDifficultySim.monteCarlo(bossId, options, runs)
	runs = runs or BossData.mechanics.sim.difficulty.runs
	local times, taken, wipes, killed, anyDead = {}, 0, 0, 0, 0
	local counts, deferred, bySource = {}, 0, {}
	local dashUses = { short = 0, long = 0, protectOnly = 0, protected = 0 }
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
		for k, v in pairs(r.dashUses or {}) do
			dashUses[k] = (dashUses[k] or 0) + v / runs -- BOSS-NIGHT-3 7단계: reactive(반응 스킬 대시) 칸도
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
		p10 = pct(0.1), p50 = pct(0.5), p90 = pct(0.9), counts = counts, deferredPerRun = deferred / runs, bySource = bySource, dashUsesPerRun = dashUses,
	}
end

return BossDifficultySim
