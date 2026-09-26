-- C1 악용 시뮬레이터(순수) - 잡몹 기준 스테이지 규칙(shared/MobShare)과 옛 C안(때린 사람 스테이지로 환산)을 같은 대본으로 돌려 "받는 사람의 드랍 가치/분"을 비교한다.
-- 가정(보고서 C1 ⑤와 같다):
--   · 힘 = "그 스테이지 몹을 BalanceAnchorConfig.killTargetSeconds초에 잡는 순딜" - power 스테이지 p의 초당 피해 = H(p) ÷ T. 몹 HP H(s) = k^(s − 1)(기본 HP · 접두사 1).
--   · 처치 1마리 가치 = 받는 사람 자기 스테이지의 장비 가치 CharacterLevel.getItemLevelMultiplier(스테이지)(드랍 itemLevel = 자기 스테이지 ±2). 골드 · 경험치 · 처치 시간 보정은 뺀다
--     (보정은 빠른 처치를 깎으므로 "전" 악용 이득은 상한값).
--   · 처치 사이 이동 = DropTableData.fairness.travelSeconds · 틱 0.1초 · 10분.
-- 판정: 정상 대비 +5% 이하 O · 5 ~ 15% 주의 · 15% 초과 X(지시 C1 [5]).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MobShare = require(ReplicatedStorage.Shared.MobShare)
local RaidRules = require(ReplicatedStorage.Shared.RaidRules)
local BossRules = require(ReplicatedStorage.Shared.BossRules)
local CharacterLevel = require(ReplicatedStorage.Shared.CharacterLevel)
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)
local InfiniteStageConfig = require(ReplicatedStorage.Shared.data.InfiniteStageConfig)
local BalanceAnchorConfig = require(ReplicatedStorage.Shared.data.BalanceAnchorConfig)
local DropTableData = require(ReplicatedStorage.Shared.data.DropTableData)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local BossData = require(ReplicatedStorage.Shared.data.BossData)

local C1Sim = {}

local T = BalanceAnchorConfig.killTargetSeconds
local TRAVEL = DropTableData.fairness.travelSeconds
local DT = 0.1
local DURATION = 600
local k = InfiniteStageConfig.growthRate

function C1Sim.value(stage)
	return CharacterLevel.getItemLevelMultiplier(math.max(1, stage))
end

-- ── 몹 하나(mode = "old" | "new") ──
local function newMob(mode)
	local mob = MobShare.fresh({ mode = mode })
	return mob
end

-- who = { power, stage } · 한 틱 피해. 반환 = 죽었는가.
local function hit(mob, who, now)
	if mob.mode == "old" then
		local ratio = k ^ (who.power - who.stage) / T * DT
		mob.hpRatio -= ratio
		mob.contributions[who] = (mob.contributions[who] or 0) + ratio
		mob.partStage[who] = mob.partStage[who] or who.stage
		return mob.hpRatio <= 0
	end
	local ref, _wasReset, _rose, blocked = MobShare.touch(mob, who, who.stage, now)
	if blocked then
		return false, true -- C1 후속: 더 낮은 사람이 때리는 몹 - 피해 0
	end
	local ratio = k ^ (who.power - ref) / T * DT -- H(power) ÷ H(ref) - 절대 HP를 만들지 않는다
	if ratio ~= ratio then
		ratio = 0
	end
	return MobShare.applyRatio(mob, who, ratio, now)
end

-- 스테이지 변경(새 규칙 = 서버 onStageChanged와 같은 순서 · 옛 = 기록 그대로)
local function changeStage(mobs, who, stage, now)
	who.stage = stage
	for _, mob in ipairs(mobs) do
		if mob.mode == "new" and mob.partStage[who] ~= nil and mob.partStage[who] ~= stage then
			if not MobShare.purge(mob, who) then
				MobShare.refresh(mob, now)
			end
		end
	end
end

-- 죽은 몹 보상 → 사람마다 가치 누적
local function payout(mob, earned, now)
	for who, c in pairs(mob.contributions) do
		local ok
		if mob.mode == "old" then
			ok = c >= CombatConfig.contributionRewardThreshold
		else
			MobShare.refresh(mob, now)
			ok = MobShare.eligible(mob, who, who.stage)
		end
		if ok then
			earned[who] = (earned[who] or 0) + C1Sim.value(who.stage)
		end
	end
end

local function perMinute(total)
	return total / (DURATION / 60)
end

-- 정상 기준: n명이 같은 스테이지(= 자기 힘)에서 같은 몹을 같이 친다.
function C1Sim.normalRate(stage, n)
	local killSeconds = math.ceil(T / (n or 1) / DT - 1e-9) * DT
	return 60 / (killSeconds + TRAVEL) * C1Sim.value(stage)
end

-- 대본 러너: script(state, now) → 이번 틱의 행동(state가 몹 · 사람을 들고 있다). 몹이 죽으면 이동 시간 뒤 새 몹.
local function run(mode, setup, step)
	local state = setup(mode)
	state.earned = {}
	local now = 0
	while now < DURATION do
		step(state, now)
		now += DT
	end
	return state
end

-- 한 몹 사이클 헬퍼: state.mob가 죽으면 보상 · 이동 대기 · 새 몹
local function resolve(state, dead, now, key)
	key = key or "mob"
	if dead and not state[key .. "Dead"] then
		payout(state[key], state.earned, now)
		state[key .. "Dead"] = true
		state[key .. "RespawnAt"] = now + TRAVEL
	end
end

local function respawn(state, now, key)
	key = key or "mob"
	if state[key .. "Dead"] and now >= state[key .. "RespawnAt"] - 1e-9 then
		state[key] = newMob(state.mode)
		state[key .. "Dead"] = false
		state.mobs = state.mobs or {}
		table.insert(state.mobs, state[key])
		if #state.mobs > 8 then
			table.remove(state.mobs, 1)
		end
		return true
	end
	return false
end

local function start(mode, extra)
	local state = extra or {}
	state.mode = mode
	state.mob = newMob(mode)
	state.mobDead = false
	state.mobs = { state.mob }
	return state
end

local HIGH = 3000

-- a: 강한 계정 A(힘 HIGH)가 스테이지 1에 두고 B(HIGH)의 몹을 깎는다. B가 10% 넘기면 A가 친다. 받는 사람 = B. 정상 = 둘이 HIGH에서 파티.
local function scenarioA(mode)
	local state = run(mode, function(m)
		return start(m, { A = { power = HIGH, stage = 1, name = "A" }, B = { power = HIGH, stage = HIGH, name = "B" } })
	end, function(s, now)
		if respawn(s, now) or s.mobDead then
			return
		end
		local dead = hit(s.mob, s.B, now)
		if not dead and (s.mob.contributions[s.B] or 0) >= 0.1 then
			dead = hit(s.mob, s.A, now)
		end
		resolve(s, dead, now)
	end)
	return perMinute(state.earned[state.B] or 0), C1Sim.normalRate(HIGH, 2), perMinute(state.earned[state.A] or 0)
end

-- b: 낮은 계정 L 4개(힘 1 · 스테이지 1)가 몹을 85 ~ 89% 깎아 두고(친구가 10%를 넘기게 남긴다) 높은 친구 F(HIGH)가 마무리. 받는 사람 = F. 정상 = F 혼자.
local function scenarioB(mode)
	local lows = {}
	for i = 1, 4 do
		lows[i] = { power = 1, stage = 1, name = "L" .. i }
	end
	local state = run(mode, function(m)
		local s = start(m, { F = { power = HIGH, stage = HIGH }, lows = lows, prepped = {}, queue = {} })
		s.mob = nil
		s.mobs = {}
		for i = 1, 4 do
			local mob = newMob(m)
			s.prepped[i] = mob
			table.insert(s.mobs, mob)
		end
		return s
	end, function(s, now)
		-- 낮은 계정 i가 자기 몹을 90%까지(10% 남김) → 대기열
		for i, low in ipairs(s.lows) do
			local mob = s.prepped[i]
			if mob and mob.hpRatio > 0.15 then
				hit(mob, low, now)
				if mob.hpRatio <= 0.15 then
					table.insert(s.queue, mob)
					s.prepped[i] = nil
					s.lowReadyAt = s.lowReadyAt or {}
					s.lowReadyAt[i] = now + TRAVEL
				end
			elseif not mob and s.lowReadyAt and now >= s.lowReadyAt[i] then
				s.prepped[i] = newMob(s.mode)
			end
		end
		-- F: 대기열 맨 앞을 마무리(없으면 자기 몹을 처음부터)
		if s.fBusyUntil and now < s.fBusyUntil then
			return
		end
		s.fMob = s.fMob or table.remove(s.queue, 1) or newMob(s.mode)
		local dead, blocked = hit(s.fMob, s.F, now)
		if blocked then
			s.fMob = newMob(s.mode) -- 낮은 계정이 잡는 몹 = 못 친다 → 자기 몹으로
			dead = hit(s.fMob, s.F, now)
		end
		if dead then
			payout(s.fMob, s.earned, now)
			s.fMob = nil
			s.fBusyUntil = now + TRAVEL
		end
	end)
	return perMinute(state.earned[state.F] or 0), C1Sim.normalRate(HIGH, 1)
end

-- c: 약한 P(힘 1)가 스테이지 1에서 F(HIGH)의 몹을 10% 깎고 → 스테이지 HIGH로 올림 → F가 마무리 → 다시 1로(1초 제한 지킴). 받는 사람 = P. 정상 = P 혼자 스테이지 1.
local function scenarioC(mode)
	local state = run(mode, function(m)
		return start(m, { P = { power = 1, stage = 1 }, F = { power = HIGH, stage = HIGH }, phase = "low", switchAt = 0 })
	end, function(s, now)
		if respawn(s, now) then
			s.phase = "low"
			changeStage(s.mobs, s.P, 1, now)
			s.switchAt = now
			return
		end
		if s.mobDead then
			return
		end
		local dead = false
		if s.phase == "low" then
			dead = hit(s.mob, s.P, now)
			if (s.mob.contributions[s.P] or 0) >= 0.1 and now - s.switchAt >= 1 then
				changeStage(s.mobs, s.P, HIGH, now)
				s.phase = "high"
				s.switchAt = now
			end
		else
			dead = hit(s.mob, s.F, now)
		end
		resolve(s, dead, now)
	end)
	return perMinute(state.earned[state.P] or 0), C1Sim.normalRate(1, 1)
end

-- d: P(힘 300 · 스테이지 300)가 몹을 반쯤 깎을 때마다 스테이지를 299 ↔ 300으로 연타(1초 1회)해 몹을 초기화 · 어그로를 푼다. 받는 사람 = P. 정상 = P 혼자.
local function scenarioD(mode)
	local state = run(mode, function(m)
		return start(m, { P = { power = 300, stage = 300 }, lastSwitch = -10, resets = 0 })
	end, function(s, now)
		if respawn(s, now) or s.mobDead then
			return
		end
		local dead = hit(s.mob, s.P, now)
		if not dead and s.mob.hpRatio < 0.5 and now - s.lastSwitch >= CombatConfig.stageChangeCooldownSeconds and s.resets < 3 then
			changeStage(s.mobs, s.P, s.P.stage == 300 and 299 or 300, now)
			s.lastSwitch = now
			s.resets += 1
		end
		if dead then
			s.resets = 0
		end
		resolve(s, dead, now)
	end)
	return perMinute(state.earned[state.P] or 0), C1Sim.normalRate(300, 1)
end

-- e: 섞인 파티 1 · 300 · 3,000이 같은 무리에서 각자 자기 몹을 잡는다. overlap = 내 몹 중 바로 위 파티원의 광역이 한 번 스치는 비율(0 = 각자 몹만).
--   새 규칙: 스치면 기준이 그 사람 스테이지로 올라 HP바가 가득으로 튄다 → 주인은 그 몹을 두고 새 몹으로(이동 1초). 스친 사람은 마무리하지 않는다(가장 나쁜 경우).
--   옛 규칙: 스쳐도 스친 사람 스테이지 비율만 빠져 주인이 계속 친다.
local function scenarioE(mode, overlap, stages)
	stages = stages or { 1, 300, 3000 }
	local people = {}
	for _, st in ipairs(stages) do
		table.insert(people, { power = st, stage = st })
	end
	local state = run(mode, function(m)
		local s = start(m, { people = people, own = {}, deadUntil = {}, spillAt = {}, count = {}, acc = {} })
		for i = 1, 3 do
			s.own[i] = newMob(m)
			s.count[i] = 0
			s.acc[i] = 0
		end
		return s
	end, function(s, now)
		for i, who in ipairs(s.people) do
			if s.deadUntil[i] then
				if now >= s.deadUntil[i] - 1e-9 then
					s.own[i] = newMob(s.mode)
					s.deadUntil[i] = nil
					-- 결정적 표본: 누적 overlap이 1을 넘을 때마다 그 몹이 스친다(몹 수명의 절반쯤)
					s.acc[i] += overlap
					if i < 3 and s.acc[i] >= 1 - 1e-9 then
						s.acc[i] -= 1
						s.spillAt[i] = now + T / 2
					end
				end
			elseif s.spillAt[i] and now >= s.spillAt[i] then
				s.spillAt[i] = nil
				local before = s.own[i].hpRatio
				if hit(s.own[i], s.people[i + 1], now) then
					payout(s.own[i], s.earned, now)
					s.deadUntil[i] = now + TRAVEL
				elseif s.own[i].hpRatio > before + 0.2 then
					s.deadUntil[i] = now + TRAVEL -- HP바가 크게 튐(기준 상승) → 두고 새 몹(조금 오른 건 계속 친다)
				end
			elseif hit(s.own[i], who, now) then
				payout(s.own[i], s.earned, now)
				s.deadUntil[i] = now + TRAVEL
			end
		end
	end)
	local rows = {}
	for _, who in ipairs(people) do
		table.insert(rows, { stage = who.stage, rate = perMinute(state.earned[who] or 0), normal = C1Sim.normalRate(who.stage, 1) })
	end
	return rows
end

-- f: 잠수 파티원 M(스테이지 1 · 무행동 · 가끔 쫓김 = 어그로 참여) + 사냥꾼 H(HIGH). 받는 사람 = M(버스). 정상 = 0(한 일 없음 → 0이어야 O).
local function scenarioF(mode)
	local state = run(mode, function(m)
		return start(m, { M = { power = 1, stage = 1 }, H = { power = HIGH, stage = HIGH } })
	end, function(s, now)
		if respawn(s, now) or s.mobDead then
			return
		end
		if s.mode == "new" then
			MobShare.touch(s.mob, s.M, s.M.stage, now, true) -- 몹이 잠수 멤버를 쫓는다(어그로 참여 = passive)
		end
		resolve(s, hit(s.mob, s.H, now), now)
	end)
	return perMinute(state.earned[state.M] or 0), perMinute(state.earned[state.H] or 0), C1Sim.normalRate(HIGH, 1)
end

-- i: 방해 - 높은 H(3,000)가 낮은 L(1)의 몹에 2초마다 광역 한 틱. L은 자기 몹을 계속 잡는다. 반환 = L 가치/분 · H가 L 몹에서 얻은 가치/분.
--   옛 규칙: H의 한 틱은 H 스테이지 비율(4%)이라 L 몹을 거들고, 10%를 넘기면 H가 스테이지 3,000 보상을 가져간다(막타 저격).
local function scenarioI(mode)
	local state = run(mode, function(m)
		return start(m, { L = { power = 1, stage = 1 }, H = { power = HIGH, stage = HIGH }, nextSpill = 1 })
	end, function(s, now)
		if respawn(s, now) or s.mobDead then
			return
		end
		local dead = hit(s.mob, s.L, now)
		if not dead and now >= s.nextSpill then
			s.nextSpill = now + 2
			local before = s.mob.hpRatio
			dead = hit(s.mob, s.H, now)
			if not dead and s.mob.hpRatio > before then
				s.mob = newMob(s.mode) -- (C1 1차) 기준 상승 = 진행 소실 → 새 몹
				table.insert(s.mobs, s.mob)
			end
		end
		resolve(s, dead, now)
	end)
	return perMinute(state.earned[state.L] or 0), C1Sim.normalRate(1, 1), perMinute(state.earned[state.H] or 0)
end

-- j: 스테이지 1 탱커 T(힘 3,000 · 어그로만 · 안 때림) + 높은 딜러 D(3,000). 몹은 1초마다 T를 친다. T는 받는 스테이지 x에서 surviveTargetHits × k^(힘 − x)타를 버틴다.
--   T가 죽으면 부활 + 복귀 15초 동안 파티 사냥이 멈춘다(가정). 받는 사람 = D. 정상 = T가 3,000에서 탱킹(같은 사람 · 정상 파티).
--   옛 규칙 = 받는 피해가 T 자기 스테이지(1) → 사실상 안 죽는다. 새 규칙 = 몹 기준 스테이지(D가 때려 3,000).
--   pull = 새 몹마다 T가 끌어오는 초(그동안 D는 안 친다 - 몹 참여자는 쫓기는 T뿐이라 기준 = T 스테이지). 한 틱 순서 = D 타격 → 몹 공격.
--   새 규칙: 몹은 나보다 높은 참여자와 스틸 불가한 사람을 쫓지 않는다(MonsterState.canChase → MobShare.tooWeakFor) → D가 쳐서 기준이 3,000이 되면 T를 놓고 D를 문다(D도 7타 · 죽으면 15초).
local function scenarioJ(mode, normal, pull)
	pull = pull or 0
	local surviveHits = BalanceAnchorConfig.surviveTargetHits
	local state = run(mode, function(m)
		return start(m, { T = { power = HIGH, stage = normal and HIGH or 1 }, D = { power = HIGH, stage = HIGH }, hp = {}, nextBite = 0, downUntil = 0, mobAt = 0 })
	end, function(s, now)
		if now < s.downUntil then
			return
		end
		if respawn(s, now) then
			s.mobAt = now
			return
		end
		if s.mobDead then
			return
		end
		local victim = s.T
		if s.mode == "new" then
			MobShare.refresh(s.mob, now)
			if not MobShare.tooWeakFor(s.mob, s.T, s.T.stage) then -- 어그로 필터 = 서버 MonsterState.canChase와 같은 canShare
				MobShare.touch(s.mob, s.T, s.T.stage, now, true) -- 쫓김 = passive 참여
			else
				victim = s.D -- 기준 − 10보다 낮은 T는 안 쫓는다
			end
		end
		if now - s.mobAt >= pull - 1e-9 then
			local dead = hit(s.mob, s.D, now)
			resolve(s, dead, now)
			if dead then
				return
			end
		end
		if now >= s.nextBite then
			s.nextBite = now + 1
			local received = s.mode == "new" and (s.mob.refStage or victim.stage) or victim.stage
			s.hp[victim] = (s.hp[victim] or 1) - 1 / (surviveHits * k ^ (victim.power - received))
			if s.hp[victim] <= 0 then
				s.hp[victim] = 1
				s.downUntil = now + 15
			end
		end
	end)
	return perMinute(state.earned[state.D] or 0)
end

-- k: 사다리 - 스테이지 270 · 280 · 290 · 300(힘 = 스테이지) 네 명이 한 몹을 이어서 깎는다. i번째는 몹이 1 − 0.2i까지 줄면 손을 떼고 다음 사람이 넘겨받는다
--   (막히면 풀릴 때까지 매 틱 재시도). 마지막 300이 마무리. 받는 사람 = 300. 정상 = 같은 네 명이 스테이지 300에서 함께(정상 파티).
local function scenarioK(mode, normal)
	local ladder = { 270, 280, 290, 300 }
	local people = {}
	for _, st in ipairs(ladder) do
		table.insert(people, { power = st, stage = normal and 300 or st })
	end
	local state = run(mode, function(m)
		return start(m, { people = people, step = 1 })
	end, function(s, now)
		if respawn(s, now) then
			s.step = 1
			return
		end
		if s.mobDead then
			return
		end
		if normal then
			for _, who in ipairs(s.people) do
				if not s.mobDead then
					resolve(s, hit(s.mob, who, now), now)
				end
			end
			return
		end
		local who = s.people[s.step]
		local dead, blocked = hit(s.mob, who, now)
		resolve(s, dead, now)
		if not dead and not blocked and s.step < #s.people and s.mob.hpRatio <= 1 - 0.2 * s.step then
			s.step += 1
		end
	end)
	return perMinute(state.earned[people[4]] or 0)
end

-- l · m(C1 마무리): 스틸 시도 - 주인 O가 자기 몹을 잡고, 도둑 X(힘 = 자기 스테이지)는 O가 10%를 넘긴 몹에 매 틱 끼어든다(자기 몹 없음).
--   반환 = X가 O의 몹에서 가져간 가치/분(정상 0) · O 가치/분 · O 솔로. 사람 = { stage, level, rebirth }(MobShare.profileOf가 읽는다).
local function scenarioSteal(mode, owner, thief)
	local state = run(mode, function(m)
		return start(m, { O = { power = owner.stage, stage = owner.stage, level = owner.level, rebirth = owner.rebirth, party = owner.party },
			X = { power = thief.power or thief.stage, stage = thief.stage, level = thief.level, rebirth = thief.rebirth, party = thief.party } })
	end, function(s, now)
		if respawn(s, now) or s.mobDead then
			return
		end
		local dead = hit(s.mob, s.O, now)
		if not dead and (s.mob.contributions[s.O] or 0) >= 0.1 then
			dead = hit(s.mob, s.X, now)
		end
		resolve(s, dead, now)
	end)
	return perMinute(state.earned[state.X] or 0), perMinute(state.earned[state.O] or 0), C1Sim.normalRate(owner.stage, 1)
end

-- g: 토벌 - 보스 35를 깬 직후(힘 35) 스테이지를 낮췄다 올리며 토벌 스테이지를 고른다. 토벌 1회 = 보스 HP(몹 × hpMultiplier) 처치 + 입장 이동. 가치/분의 최대 vs 35.
local RAID_BOSS = BossRules.bossIdForStage(BossData.stageInterval) -- 첫 보스(스테이지 5) - 35 클리어면 만난 보스

function C1Sim.raidRate(raidStage, power)
	local bossSeconds = BossData.bosses[RAID_BOSS].hpMultiplier * T * k ^ (raidStage - power)
	return 60 / (bossSeconds + TRAVEL * 10) * C1Sim.value(raidStage)
end

local function scenarioG()
	local best, bestStage = 0, nil
	local rows = {}
	for _, current in ipairs({ 1, 10, 25, 30, 34, 35, 36, 40 }) do
		local ok, _, raid = RaidRules.check({ currentStage = current, bestBossCleared = 35, bossId = RAID_BOSS, remote = false, gateUsable = true })
		local rate = ok and C1Sim.raidRate(raid, 35) or 0
		table.insert(rows, { current = current, raid = raid, rate = rate })
		if rate > best then
			best, bestStage = rate, current
		end
	end
	return best, C1Sim.raidRate(35, 35), bestStage, rows
end

-- h: 미클리어 보스 스테이지 40(최고 클리어 35 · 도달 40)에서 토벌 · 일반 사냥. 토벌 = 거절이어야 · 사냥 가치/분 vs 스테이지 39.
local function scenarioH()
	local ok, reason = RaidRules.check({ currentStage = 40, bestBossCleared = 35, bossId = RAID_BOSS, remote = true, gateUsable = true })
	return ok, reason, C1Sim.normalRate(40, 1), C1Sim.normalRate(39, 1)
end

-- [6] 고스테이지 표본: 스테이지마다 규칙 1 ~ 4 수치. 반환 행 = { stage, log10MaxHp(가장 큰 몹 HP × 접두사 최대 · 보스 배율), tick(4% 한 틱 뒤 비율), tickErr,
--   riseFrom(기준 오르기 전 스테이지), riseRatio(50% 깎인 몹이 기준 상승 뒤 남은 비율), riseContrib(낮은 사람 기여 50% → ?), nearFrom · nearRatio(5칸 아래에서 오를 때),
--   itemMin · itemMax(잡몹 드랍 itemLevel), bossItemMax(토벌 보스 드랍 최대), raid(토벌 스테이지 - 최고 클리어 = 그 아래 보스 스테이지), ok(전부 유한 · 0 ≤ 비율 ≤ 1 · 정수 < 2^53) }
function C1Sim.samples(stages, monsterData, prefixData, armorData)
	local maxBase = 0
	for _, entry in pairs(monsterData) do
		if type(entry) == "table" and type(entry.hp) == "number" and entry.hp > maxBase then
			maxBase = entry.hp
		end
	end
	local maxPrefix = 1
	for _, prefix in pairs(prefixData.prefixes or prefixData) do
		if type(prefix) == "table" and type(prefix.hpMultiplier) == "number" and prefix.hpMultiplier > maxPrefix then
			maxPrefix = prefix.hpMultiplier
		end
	end
	local bossMult = 0
	for _, boss in pairs(BossData.bosses) do
		bossMult = math.max(bossMult, boss.hpMultiplier or 0)
	end
	local function deltaRange(tbl)
		local lo, hi = math.huge, -math.huge
		for _, row in ipairs(tbl) do
			lo, hi = math.min(lo, row.delta), math.max(hi, row.delta)
		end
		return lo, hi
	end
	local dLo, dHi = deltaRange(armorData.itemLevelDelta)
	local _, bHi = deltaRange(armorData.bossItemLevelDelta)
	local function finite(v)
		return type(v) == "number" and v == v and math.abs(v) ~= math.huge
	end
	local rows = {}
	for _, stage in ipairs(stages) do
		local maxHp = InfiniteStage.getMonsterHp(maxBase, stage) * maxPrefix * math.max(1, bossMult)
		local who, low, near = {}, {}, {}
		-- 4% 한 틱(기준 = 자기 스테이지)
		local mob = MobShare.fresh({})
		MobShare.touch(mob, who, stage, 0)
		MobShare.applyRatio(mob, who, InfiniteStage.getMonsterHp(maxBase, stage) * 0.04 / InfiniteStage.getMonsterHp(maxBase, stage), 0)
		local tick = mob.hpRatio
		-- 절반 스테이지에서 50% 깎은 몹에 이 스테이지 사람이 참여
		local riseFrom = math.max(1, math.floor(stage / 2))
		local m2 = MobShare.fresh({})
		MobShare.touch(m2, low, riseFrom, 0)
		MobShare.applyRatio(m2, low, 0.5, 0)
		MobShare.touch(m2, who, stage, CombatConfig.participationWindowSeconds + 1) -- 낮은 사람이 때리는 동안은 막힘 - 창 밖이 된 뒤 참여
		-- 5칸 아래에서 50% → 오를 때(가까운 스테이지 - 값이 남는 경우)
		local nearFrom = math.max(1, stage - 5)
		local m3 = MobShare.fresh({})
		MobShare.touch(m3, near, nearFrom, 0)
		MobShare.applyRatio(m3, near, 0.5, 0)
		MobShare.touch(m3, who, stage, CombatConfig.participationWindowSeconds + 1)
		local best = BossData.stageInterval * math.floor(stage / BossData.stageInterval)
		local raid = RaidRules.raidStage(stage, best)
		local itemMax, bossItemMax = stage + dHi, (raid or stage) + bHi
		local row = {
			stage = stage, log10MaxHp = math.log10(maxHp), tick = tick, tickErr = math.abs(tick - 0.96),
			riseFrom = riseFrom, riseRatio = m2.hpRatio, riseContrib = m2.contributions[low], refAfter = m2.refStage,
			nearFrom = nearFrom, nearRatio = m3.hpRatio, nearContrib = m3.contributions[near],
			itemMin = math.max(1, stage + dLo), itemMax = itemMax, bossItemMax = bossItemMax, raid = raid,
		}
		row.ok = finite(maxHp) and finite(tick) and row.tickErr < 1e-9 and finite(row.riseRatio) and row.riseRatio >= 0 and row.riseRatio <= 1
			and finite(row.riseContrib) and finite(row.nearRatio) and row.nearRatio >= 0.5 and row.nearRatio <= 1 and row.refAfter == stage
			and itemMax < 2 ^ 53 and bossItemMax < 2 ^ 53
		table.insert(rows, row)
	end
	return rows
end

C1Sim.SAMPLE_STAGES = { 5, 30, 100, 500, 1000, 2000, 5000, 10000, 20000, 25300, 34230 }

function C1Sim.verdict(gain)
	if gain <= 0.05 + 1e-9 then
		return "O"
	elseif gain <= 0.15 then
		return "주의"
	end
	return "X"
end

local function gainOf(rate, normal)
	if rate == nil then
		return nil
	end
	if normal <= 0 then
		return rate > 0 and math.huge or 0
	end
	return rate / normal - 1
end

-- 전체 실행 → 행 목록 { id, label, before = { rate, gain }, after = { rate, gain }, normal, verdictBefore, verdictAfter, note }
function C1Sim.runAll()
	local rows = {}
	local function add(id, label, beforeRate, afterRate, normal, note)
		local gb, ga = gainOf(beforeRate, normal), gainOf(afterRate, normal)
		table.insert(rows, { id = id, label = label, normal = normal, beforeRate = beforeRate, afterRate = afterRate, gainBefore = gb, gainAfter = ga,
			verdictBefore = beforeRate and C1Sim.verdict(gb) or "-", verdictAfter = C1Sim.verdict(ga), note = note })
	end
	local ab, normalA = scenarioA("old")
	local aa = scenarioA("new")
	add("a", "강한 계정 스테이지 1 → 높은 몹 대신 깎기(받는 사람 B)", ab, aa, normalA)
	local bb, normalB = scenarioB("old")
	local ba = scenarioB("new")
	add("b", "낮은 계정 4개가 85 ~ 89% · 높은 친구 마무리(받는 사람 F)", bb, ba, normalB)
	local cb, normalC = scenarioC("old")
	local ca = scenarioC("new")
	add("c", "스테이지 1에서 깎고 → 높은 스테이지로 전환(받는 사람 P)", cb, ca, normalC)
	local db, normalD = scenarioD("old")
	local da = scenarioD("new")
	add("d", "스테이지 연타로 몹 초기화(받는 사람 P)", db, da, normalD)
	for _, set in ipairs({ { 1, 300, 3000 }, { 295, 300, 305 } }) do
		for _, overlap in ipairs({ 0, 0.1, 0.3 }) do
			local eb, ea = scenarioE("old", overlap, set), scenarioE("new", overlap, set)
			local pct = math.floor(overlap * 100 + 0.5)
			for i = 1, 3 do
				add(("e%d-%d-%d"):format(i, pct, set[1]), ("섞인 파티(%s) - 스테이지 %d · 스침 %d%%(솔로 대비)"):format(table.concat(set, "·"), ea[i].stage, pct), eb[i].rate, ea[i].rate, ea[i].normal)
			end
		end
	end
	local fb, fbH = scenarioF("old")
	local fa, faH, normalF = scenarioF("new")
	add("f", "잠수 파티원 버스(받는 사람 = 잠수 M · 정상 0)", fb, fa, 0, ("사냥꾼 H %.1f → %.1f / 솔로 %.1f"):format(fbH, faH, normalF))
	local ib, iNormal, ibH = scenarioI("old")
	local ia, _, iaH = scenarioI("new")
	add("i-L", "방해: 높은 유저가 낮은 유저 몹에 2초마다 광역(받는 사람 = 낮은 L · 솔로 대비)", ib, ia, iNormal)
	add("i-H", "방해: 같은 대본 - 높은 H가 L의 몹에서 가져간 가치(정상 0)", ibH, iaH, 0)
	local kNormal = scenarioK("new", true)
	add("k", "사다리 270 → 280 → 290 → 300 이어 깎기(받는 사람 = 300 · 정상 = 네 명이 300에서 파티)", scenarioK("old"), scenarioK("new"), kNormal)
	for _, pull in ipairs({ 0, 1, 2 }) do
		local jNormal = scenarioJ("new", true, pull)
		add(("j-%d"):format(pull), ("스테이지 1 탱커 + 높은 딜러 파티 · 끌기 %d초(받는 사람 = 딜러 D · 정상 = 탱커가 3,000)"):format(pull),
			scenarioJ("old", false, pull), scenarioJ("new", false, pull), jNormal)
	end
	local stealCases = {
		{ id = "l", label = "스틸: 환생 · 레벨 같고 스테이지 1(주인) vs 3,000(도둑)", owner = { stage = 1, level = 300, rebirth = 2 }, thief = { stage = 3000, level = 300, rebirth = 2 } },
		{ id = "m", label = "스틸: 환생 다름(0 vs 1) · 레벨 같음 · 스테이지 100(주인) vs 105(도둑)", owner = { stage = 100, level = 150, rebirth = 0 }, thief = { stage = 105, level = 150, rebirth = 1 } },
		-- n(C1 결정 5 보정): 강한 계정(환생 2 · 레벨 400 · 힘 = 스테이지 3,000)이 스테이지를 초보와 같게 / 낮게 맞춰 초보 몹을 친다
		{ id = "n", label = "스틸: 강한 계정(환생 2 · 레벨 400 · 힘 3,000)이 스테이지를 초보(환생 0 · 레벨 30 · 100)와 같게 100", owner = { stage = 100, level = 30, rebirth = 0 }, thief = { stage = 100, level = 400, rebirth = 2, power = 3000 } },
		{ id = "n-low", label = "스틸: 같은 강한 계정이 스테이지를 초보보다 낮게 95", owner = { stage = 100, level = 30, rebirth = 0 }, thief = { stage = 95, level = 400, rebirth = 2, power = 3000 } },
	}
	for _, case in ipairs(stealCases) do
		local xb, ob = scenarioSteal("old", case.owner, case.thief)
		local xa, oa, oSolo = scenarioSteal("new", case.owner, case.thief)
		add(case.id, case.label .. " - 받는 사람 = 도둑(정상 0)", xb, xa, 0, ("주인 %.3g → %.3g / 솔로 %.3g · 판정 canShare = %s"):format(ob, oa, oSolo,
			tostring(MobShare.canShare(case.owner, case.thief))))
	end
	-- o(D1-2 파티원 예외): n과 같은 두 계정이 같은 파티 - 강한 파티원이 초보 파티원이 먼저 친 몹을 같이 친다(막힘 없음). 받는 사람 = 초보(파티 버스 · 보상 규칙은 그대로 - 기여 10%).
	--   o-solo = 파티가 아니면 그대로 막힌다(= n). 정상 = 초보 솔로.
	local partyOwner, partyStrong = { stage = 100, level = 30, rebirth = 0, party = 1 }, { stage = 100, level = 400, rebirth = 2, power = 3000, party = 1 }
	local strongParty, ownerParty, ownerSolo = scenarioSteal("new", partyOwner, partyStrong)
	add("o", "파티원 예외: 강한 파티원(n의 강한 계정)이 초보 파티원(n의 초보) 몹을 같이 침 - 받는 사람 = 초보(솔로 대비)", nil, ownerParty, ownerSolo,
		("강한 파티원이 가져간 가치 %.3g/분 · 막힘 %s"):format(strongParty, tostring(MobShare.isBlocked(MobShare.fresh({}), partyStrong, 100, 0))))
	local strongOut = scenarioSteal("new", { stage = 100, level = 30, rebirth = 0, party = 1 }, { stage = 100, level = 400, rebirth = 2, power = 3000, party = 2 })
	add("o-other", "파티원 예외: 다른 파티끼리는 그대로 막힘(= n) - 받는 사람 = 강한 계정(정상 0)", nil, strongOut, 0)
	local gBest, gNormal, gStage, gRows = scenarioG()
	local gNote = {}
	for _, r in ipairs(gRows) do
		table.insert(gNote, ("%d→%s"):format(r.current, r.raid and tostring(r.raid) or "거절"))
	end
	add("g", "토벌 스테이지 조작(보스 35 직후 낮췄다 올리기)", nil, gBest, gNormal, ("최고 = 선택 %s · 토벌 %s"):format(tostring(gStage), table.concat(gNote, " ")))
	local hOk, hReason, h40, h39 = scenarioH()
	add("h", "미클리어 보스 스테이지 40에서 사냥(대 39)", nil, h40, h39, ("토벌 시도 = %s(%s)"):format(hOk and "허용" or "거절", tostring(hReason)))
	return rows
end

return C1Sim
