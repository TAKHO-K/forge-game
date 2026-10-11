-- 보스 스킬 구동(29-2, PRD 20.75 A) - 쿨타임 + 우선순위. 순수 함수만 있다: 실제 전투(server/BossPatterns.lua)와
-- 처치 시간 모형(shared/BossSim.lua)이 **같은 선택 로직**을 쓴다(28-2·29-1에서 손으로 옮긴 모형이 코드와 두 번
-- 어긋났다 - 20.73 [3]). 시계는 호출부가 준다(now) - 서버는 os.clock(), 모형은 가상 시각.
--
-- 규칙:
--   ① 한 번에 하나. 호출부는 스킬이 도는 동안 pick을 부르지 않는다.
--   ② 전역 쿨(GCD): 직전 스킬이 끝난 뒤 globalCooldownSeconds(격노면 enragedGlobalCooldownSeconds)가 지나야
--      다음이 시작된다 - 쿨이 겹쳐도 회피 불가 구간이 생기지 않는다. 입장 유예(graceUntil) 중에도 시작하지 않는다.
--   ③ 후보 = 내부 쿨이 찼고(readyAt) 발동 조건이 전부 참인 스킬.
--   ④ 자리 비우기: reserveFirstUse 스킬이 아직 한 번도 안 나왔으면, 그 첫 발동 시각을 넘겨 끝날 다른 스킬은
--      후보에서 뺀다(29-1 - 없으면 첫 기믹이 10초가 아니라 13.5초로 밀린다).
--   ⑤ 연속 금지: 다른 후보가 있으면 직전에 쓴 스킬은 뺀다(전 스킬 공통). 그 스킬 하나만 준비됐다면 허용한다 -
--      스킬이 하나뿐인 보스(견습 1단계)가 멈추지 않게. 쿨 ≥ 전역 쿨인 스킬은 어차피 연속으로 준비되지 않는다.
--   ⑥ 우선순위가 큰 쪽. 굶주림: starvationSeconds 이상 안 나온 스킬은 starvationPriorityBonus가 더해진다.
--      같으면 가장 오래 기다린 것(readyAt이 이른 것), 그것도 같으면 skillOrder 순 - 21-3의 "가장 오래 기다린
--      것부터"가 우선순위가 전부 같은 보스(구간 수호자)에서 그대로 재현된다.
--      BOSS-NIGHT-3 addendum-2 15: config.waitWeightedPick이고 ctx.rng가 있으면(실전 · 모형) 가장 높은 우선순위 후보 중에서 "마지막 사용(또는 전투 시작) 뒤
--      기다린 초"를 가중치로 뽑는다(목록 앞 · 먼저 준비된 패턴만 나오던 것을 고침). ctx.rng가 없는 검증은 옛 규칙 그대로.
--
-- 발동 조건 조각(skill.conditions = { {type=...}, ... } - 전부 참이어야 한다):
--   hpBelow / hpAbove { value }        보스 체력 비율
--   targetWithin / targetBeyond { studs } 지금 조준 대상까지의 수평 거리
--   membersClustered { studs, count }   어떤 멤버 주변 studs 안에 멤버가 count명 이상
--   gateArmed { value }                 파훼 게이트가 서 있는가
--   gateArmedFor { seconds }            게이트가 이만큼 이어서 서 있었는가
--   membersNearZone { tag, studs }      살아 있는(안 잡힌) 멤버 전원이 그 아레나 kit 구역에서 studs 안(29-4 과충전 - 닿을 수 없으면 안 쏜다)
--   memberWithin { studs }              살아 있는(안 잡힌) 멤버가 **한 명이라도** 보스에서 studs 안(29-5 분열 - 제한 시간 안에 진짜에게
--                                       닿을 수 있는 사람이 있어야 쏜다. 성공이 파티 단위인 기믹의 도달 가능성 조건 - 모형은 참으로 본다)
--   notAfter { skills = {...} }         직전 스킬이 이 목록에 없다(인접시키면 안 되는 조합을 데이터로 막는다)
-- notAfter만 이 모듈이 직접 판정한다(직전 스킬은 스케줄러 상태다). 나머지는 호출부가 ctx.conditionMet으로 답한다 -
-- 서버는 실제 월드에서, 모형은 가정에서.
--
-- ⑧ 반응 스킬(GUARDIAN-V3 - skill.reactive · data.reactiveOrder): 일반 후보(skillOrder)에 없다. 패턴이 안 도는 틈(phase normal)에 pickReactive가
--   reactiveOrder 순서로 "내부 쿨이 찼고 조건이 전부 참인" 첫 스킬을 고른다 - 전역 쿨 · 강공격 줄 · 연속 금지를 보지 않고(입장 유예만 본다),
--   끝나도 전역 쿨 · 직전 스킬을 건드리지 않는다(onReactiveEnd - 내부 쿨만). 조건 조각:
--   targetBeyondFor { studs, seconds }  대상이 studs 밖에 seconds 이상 이어서 있었다(호출부가 시각을 잰다)
--   missesWithin { key, count, seconds } 최근 seconds 안 빗나감 기록(key)이 count 이상(결과 조각 noteMiss · clearMisses)
-- 선행 조건(skill.precondition = { type, ..., otherwise = 스킬 id }, 29-3 - 규칙 ⑦): conditions와 달리 "후보에서 빼는"
-- 것이 아니라 "고른 뒤 다른 스킬로 바꿔 시작한다". 종류:
--   membersNearSafeSpot { prop, studs, marginStuds } 살아 있는(안 잡힌) 멤버 전원에게 studs 안에 그 지형의 "뒤 자리"가 있다

local BossScheduler = {}

local function isLive(skill, includeDesign)
	return skill ~= nil and (skill.enabled ~= false or includeDesign == true)
end

-- A2-N4 §2-1 강공격 줄(config.lanes - BossData.mechanics.lanes). lanes가 없거나 꺼져 있으면 옛 규칙(전역 쿨 하나)과 완전히 같다.
local function lanesOf(config)
	local lanes = config and config.lanes
	return (lanes and lanes.enabled) and lanes or nil
end

function BossScheduler.isHeavy(skill, config)
	local lanes = lanesOf(config)
	return lanes ~= nil and skill ~= nil and skill.bubble == lanes.heavyBubble
end

-- 전투 시작(스폰·어그로·전멸 리셋) 시각 now 기준으로 시계를 새로 잰다.
-- includeDesign(모형 전용): enabled=false인 설계 스킬도 포함한다. config(A2-N4 - 선택): 강공격 줄이 켜져 있으면 강공격의 첫 준비를 firstHeavySeconds 안으로 당긴다.
function BossScheduler.newState(skills, skillOrder, now, includeDesign, config)
	local state = {
		startedAt = now,
		readyAt = {},
		lastUsedAt = {},
		seen = {},
		lastSkillId = nil,
		lastEndAt = now,
		includeDesign = includeDesign == true,
	}
	for _, id in ipairs(skillOrder) do
		local skill = skills[id]
		if isLive(skill, includeDesign) then
			state.readyAt[id] = now + (skill.firstAvailableSeconds or skill.cooldownSeconds)
			if BossScheduler.isHeavy(skill, config) then
				state.readyAt[id] = math.min(state.readyAt[id], now + lanesOf(config).firstHeavySeconds)
			end
			state.lastUsedAt[id] = now
		end
	end
	return state
end

local function conditionsMet(state, skill, ctx)
	if not skill.conditions then
		return true
	end
	for _, condition in ipairs(skill.conditions) do
		if condition.type == "notAfter" then
			if state.lastSkillId and table.find(condition.skills, state.lastSkillId) then
				return false
			end
		elseif not ctx.conditionMet(condition) then
			return false
		end
	end
	return true
end

-- ctx = { now, enraged(bool), graceUntil, conditionMet(condition) → bool, boundSeconds(id) → 그 스킬이 보스를 묶는 시간의 상한 }
-- 반환: 시작할 스킬 id(없으면 nil).
function BossScheduler.pick(state, skills, skillOrder, config, ctx)
	local now = ctx.now
	if state.forced then
		local forced = state.forced
		state.forced = nil
		return forced
	end
	local gap = ctx.enraged and config.enragedGlobalCooldownSeconds or config.globalCooldownSeconds
	local lanes = lanesOf(config)
	-- 패턴 줄 = 전역 쿨(+ 강공격 줄이 켜져 있으면 강공격 끝 + patternAfterHeavySeconds) · 강공격 줄 = 전 강공격 전조 끝 + heavyMinGapSeconds만
	-- QUEUE-ALL1 결정 1: 전조 있는 공격(강공격 · 패턴 공통 - 평타 제외) 사이 최소 간격 = 전 전조 끝 + telegraphMinGapSeconds(없으면 끔)
	local telegraphOpen = not (lanes and lanes.telegraphMinGapSeconds) or now >= (state.telegraphGapUntil or -math.huge)
	local patternOpen = telegraphOpen and now >= state.lastEndAt + gap and (not lanes or now >= (state.heavyEndAt or -math.huge) + lanes.patternAfterHeavySeconds)
	local heavyOpen = telegraphOpen and lanes ~= nil and not config.heavyOff and now >= (state.heavyGapUntil or -math.huge)
	if now < (ctx.graceUntil or 0) or not (patternOpen or heavyOpen) then
		return nil
	end

	local reserved = nil
	for _, id in ipairs(skillOrder) do
		local skill = skills[id]
		if state.readyAt[id] and skill.reserveFirstUse and not state.seen[id] and (not reserved or state.readyAt[id] < reserved) then
			reserved = state.readyAt[id]
		end
	end

	local candidates = {}
	for _, id in ipairs(skillOrder) do
		local skill = skills[id]
		local readyAt = state.readyAt[id]
		local heavy = lanes ~= nil and skill ~= nil and skill.bubble == lanes.heavyBubble
		local laneOpen = (heavy and heavyOpen) or (not heavy and patternOpen) -- config.heavyOff(초반 완화 구간) = 강공격 줄 끔
		if readyAt and laneOpen and now >= readyAt and conditionsMet(state, skill, ctx) then
			local holdsReservation = skill.reserveFirstUse and not state.seen[id]
			local blocked = not holdsReservation and reserved ~= nil and now + ctx.boundSeconds(id) + (heavy and lanes.patternAfterHeavySeconds or gap) > reserved
			if not blocked then
				local priority = skill.priority or 0
				if skill.starvationSeconds and now - state.lastUsedAt[id] >= skill.starvationSeconds then
					-- BOSS-NIGHT-3 addendum-2 15: starvedFlat = 굶주린 스킬은 원래 우선순위와 관계없이 같은 값(시그니처 50이 굶주린 일반 스킬을 늘 이기던 것 - 굶주린 것끼리는 가중치 뽑기)
					-- BN3-finish 0-②(VERIFY-4 6-e): starvedFlatSkipRole(시그니처)은 균등화에서 뺀다 = 원래 값 + 가산 → 굶주리면 굶주린 일반 스킬보다 먼저(판당 등장 보장)
					local flat = config.starvedFlat and not (config.starvedFlatSkipRole and skill.role == config.starvedFlatSkipRole)
					priority = flat and config.starvationPriorityBonus or priority + config.starvationPriorityBonus
				end
				-- ⑥-2(BR1-4a): lowerAfter = { skills, priority } - 직전 스킬이 목록에 있으면 우선순위를 그만큼 낮춘다(후보에서 빼지는 않는다 - notAfter와 다르다)
				-- BN3-finish 0-①(VERIFY-4 6-d): 굶주림 뒤에 적용(옛 = 앞에서 빼고 starvedFlat이 덮어써 감점이 사라졌다 - 회오리 직후 대공 잡기)
				if skill.lowerAfter and state.lastSkillId and table.find(skill.lowerAfter.skills, state.lastSkillId) then
					priority -= skill.lowerAfter.priority
				end
				table.insert(candidates, { id = id, priority = priority, readyAt = readyAt, heavy = heavy })
			end
		end
	end

	-- A2-N4: 두 줄 다 후보가 있으면 패턴 먼저(강공격이 패턴을 굶기지 않게)
	if lanes then
		local patterns = {}
		for _, candidate in ipairs(candidates) do
			if not candidate.heavy then
				table.insert(patterns, candidate)
			end
		end
		if #patterns > 0 then
			candidates = patterns
		end
	end

	if #candidates > 1 and state.lastSkillId then
		for index, candidate in ipairs(candidates) do
			if candidate.id == state.lastSkillId then
				table.remove(candidates, index)
				break
			end
		end
	end

	local best = nil
	for _, candidate in ipairs(candidates) do
		if not best or candidate.priority > best.priority
			or (candidate.priority == best.priority and candidate.readyAt < best.readyAt) then
			best = candidate
		end
	end
	if not best then
		return nil
	end
	if config.waitWeightedPick and ctx.rng then
		local pool, sum = {}, 0
		for _, candidate in ipairs(candidates) do
			if candidate.priority == best.priority then
				local weight = math.max(now - (state.lastUsedAt[candidate.id] or state.startedAt or now), 1)
				sum += weight
				table.insert(pool, { candidate = candidate, weight = weight })
			end
		end
		local roll = ctx.rng() * sum
		for _, entry in ipairs(pool) do
			roll -= entry.weight
			if roll <= 0 then
				best = entry.candidate
				break
			end
		end
	end

	-- ⑦ 선행 조건(29-3): 고른 스킬의 precondition이 거짓이면 그 스킬 대신 precondition.otherwise를 시작한다 - 고른
	--    스킬의 쿨·자리 비우기는 그대로 남아 다음 선택에서 다시 나온다("피할 방법이 없는 포효는 없다": 기둥이 없으면
	--    포효 대신 낙빙이 먼저 온다). 대신 시작한 스킬 바로 다음에는 조건을 다시 묻지 않는다 - 방금 발밑에 생긴 기둥을
	--    스스로 떠난 것은 선택이고, 누군가 멀리 서 있는 것만으로 기믹(= 게이트)이 영영 안 서는 구멍도 막는다.
	local pre = skills[best.id].precondition
	if pre and state.readyAt[pre.otherwise] ~= nil
		and not (state.substitutedFor == best.id and state.lastSkillId == pre.otherwise)
		and not ctx.conditionMet(pre) then
		state.substitutedFor, state.substituteId = best.id, pre.otherwise
		return pre.otherwise
	end
	return best.id
end

-- now · skills · config(A2-N4 - 선택): 강공격이면 다음 강공격은 이 전조 끝 + heavyMinGapSeconds 뒤부터.
function BossScheduler.onSkillStart(state, id, now, skills, config)
	state.seen[id] = true
	local skill = skills and skills[id]
	if now and BossScheduler.isHeavy(skill, config) then
		state.heavyGapUntil = now + (skill.telegraphSeconds or 0) + lanesOf(config).heavyMinGapSeconds
		state.heavyRunning = true
	end
	local lanes = lanesOf(config)
	if now and skill and lanes and lanes.telegraphMinGapSeconds then
		state.telegraphGapUntil = now + (skill.telegraphSeconds or 0) + lanes.telegraphMinGapSeconds
	end
	if id ~= state.substituteId then
		state.substitutedFor, state.substituteId = nil, nil
	end
end

-- 스킬이 끝난 시각 now - 내부 쿨·전역 쿨·굶주림 시계가 전부 여기서 다시 돈다.
function BossScheduler.onSkillEnd(state, skills, id, now, config)
	if id and BossScheduler.isHeavy(skills[id], config) then
		state.heavyEndAt = now -- A2-N4: 강공격은 전역 쿨(lastEndAt)을 다시 걸지 않는다 - 패턴은 이 끝 + patternAfterHeavySeconds부터
		state.heavyRunning = false
	else
		state.lastEndAt = now
	end
	if id and skills[id] then
		state.readyAt[id] = now + skills[id].cooldownSeconds
		state.lastUsedAt[id] = now
		state.lastSkillId = id
	end
end

-- ⑧ 반응 스킬 고르기(위 주석). 반환 id 또는 nil.
function BossScheduler.pickReactive(state, skills, reactiveOrder, ctx)
	if not reactiveOrder or ctx.now < (ctx.graceUntil or 0) then
		return nil
	end
	state.reactiveReadyAt = state.reactiveReadyAt or {}
	for _, id in ipairs(reactiveOrder) do
		local skill = skills[id]
		if isLive(skill) and ctx.now >= (state.reactiveReadyAt[id] or -math.huge) and conditionsMet(state, skill, ctx) then
			return id
		end
	end
	return nil
end

function BossScheduler.onReactiveEnd(state, skills, id, now)
	state.reactiveReadyAt = state.reactiveReadyAt or {}
	state.reactiveReadyAt[id] = now + (skills[id] and skills[id].cooldownSeconds or 0)
end

-- DevTools 전용 - 다음 선택에서 이 스킬이 바로 나가게 한다(전역 쿨·유예·쿨 무시).
-- 29-5 탱커 훅 ②(PRD 20.80 [F]): 도발이 들어온 시각을 적어 둔다. **pick은 아직 이 값을 읽지 않는다** - 탱커가 생기면 여기서
-- "도발 직후의 반격"(전역 쿨을 건너뛰고 다음 스킬을 곧바로 고른다 - 전조는 그대로라 회피 부등식은 깨지지 않는다)을 연다.
function BossScheduler.noteTaunt(state, now)
	state.tauntedAt = now
end

function BossScheduler.force(state, id)
	state.readyAt[id] = -math.huge
	state.lastEndAt = -math.huge
	state.heavyGapUntil, state.heavyEndAt = nil, nil -- A2-N4
	state.telegraphGapUntil = nil
	state.lastSkillId = nil
	state.forced = id
end

return BossScheduler
