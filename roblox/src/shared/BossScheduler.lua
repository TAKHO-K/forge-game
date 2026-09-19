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
-- 선행 조건(skill.precondition = { type, ..., otherwise = 스킬 id }, 29-3 - 규칙 ⑦): conditions와 달리 "후보에서 빼는"
-- 것이 아니라 "고른 뒤 다른 스킬로 바꿔 시작한다". 종류:
--   membersNearSafeSpot { prop, studs, marginStuds } 살아 있는(안 잡힌) 멤버 전원에게 studs 안에 그 지형의 "뒤 자리"가 있다

local BossScheduler = {}

local function isLive(skill, includeDesign)
	return skill ~= nil and (skill.enabled ~= false or includeDesign == true)
end

-- 전투 시작(스폰·어그로·전멸 리셋) 시각 now 기준으로 시계를 새로 잰다.
-- includeDesign(모형 전용): enabled=false인 설계 스킬도 포함한다.
function BossScheduler.newState(skills, skillOrder, now, includeDesign)
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
	if now < (ctx.graceUntil or 0) or now < state.lastEndAt + gap then
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
		if readyAt and now >= readyAt and conditionsMet(state, skill, ctx) then
			local holdsReservation = skill.reserveFirstUse and not state.seen[id]
			local blocked = not holdsReservation and reserved ~= nil and now + ctx.boundSeconds(id) + gap > reserved
			if not blocked then
				local priority = skill.priority or 0
				if skill.starvationSeconds and now - state.lastUsedAt[id] >= skill.starvationSeconds then
					priority += config.starvationPriorityBonus
				end
				table.insert(candidates, { id = id, priority = priority, readyAt = readyAt })
			end
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

function BossScheduler.onSkillStart(state, id)
	state.seen[id] = true
	if id ~= state.substituteId then
		state.substitutedFor, state.substituteId = nil, nil
	end
end

-- 스킬이 끝난 시각 now - 내부 쿨·전역 쿨·굶주림 시계가 전부 여기서 다시 돈다.
function BossScheduler.onSkillEnd(state, skills, id, now)
	state.lastEndAt = now
	if id and skills[id] then
		state.readyAt[id] = now + skills[id].cooldownSeconds
		state.lastUsedAt[id] = now
		state.lastSkillId = id
	end
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
	state.lastSkillId = nil
	state.forced = id
end

return BossScheduler
