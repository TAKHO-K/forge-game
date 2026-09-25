-- BR1-2 폭풍 군주 전멸기 "번개 조준경"(docs/design/boss-br1-2.md §6-6 · 사용자). primitive = "lightningRods"(보스 이름이 들어간 분기 없음 - 피뢰침 = 아레나 kit의 rodTag 구역).
-- 흐름(수치 = 스킬 데이터):
--   전조 telegraphSeconds → 방전 번개 discharges번(차례로): 표적 한 명(살아 있는 · 안 잡힌 멤버를 번갈아 - 머리 위 표시) → markSeconds 뒤 조준경이 trackSeconds 동안 그 사람의 발밑을
--   따라간다(스나이퍼) → 멈춘 자리(서버가 그 순간 잡는다 = 조준경이 선 자리) → lockSeconds 뒤 낙뢰: 반경 strike.radiusStuds 안 사람 피해 · 피뢰침 rodReachStuds 안이면 그 피뢰침 충전(이미 빛나면 인정 없음).
--   그동안 일반 번개(ambient)가 everySeconds마다 무작위 멤버 발밑에 떨어진다. 충전 수가 필요 수(인원에 따라)에 닿으면 즉시 성공(보스 기절 stunSeconds) ·
--   방전을 다 쓰고도 모자라면 실패 = 최대 체력 failMaxHpFraction · 보호막 무시(전원).
-- 판정은 서버, 조준경 · 표시 · 빛남 · 남은 수 표시는 클라(BossRodsView).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossPropMath = require(ReplicatedStorage.Shared.BossPropMath)
local Reach = require(ReplicatedStorage.Shared.Reach)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local BossTrap = require(script.Parent.BossTrap)
local PlayerDamage = require(script.Parent.PlayerDamage)
local PlayerState = require(script.Parent.PlayerState)
local MonsterState = require(script.Parent.MonsterState)

local BossLightningRods = {}

local kit
local rng = Random.new()

-- 순수: 인원 n에서 필요한 충전 수(피뢰침 개수가 상한).
function BossLightningRods.requiredFor(skill, memberCount, rodCount)
	return math.min(skill.requiredBase + skill.requiredPerExtra * math.max((memberCount or 1) - 1, 0), rodCount or math.huge)
end

-- 순수: 낙뢰 자리 position이 충전시키는 피뢰침 번호(가장 가까운 것 · reach 안 · 아직 안 빛나는 것). 없으면 nil.
function BossLightningRods.rodHit(rods, charged, position, reach)
	local best, bestDistance = nil, math.huge
	for _, rod in ipairs(rods) do
		local d = Reach.horizontalDistance(rod.center, position)
		if d <= reach and d < bestDistance then
			best, bestDistance = rod.index, d
		end
	end
	if best and charged[best] then
		return nil, best -- 이미 빛나는 피뢰침(인정 없음)
	end
	return best, nil
end

local function aliveVictims(st)
	local list = {}
	for _, v in ipairs(kit.victims(st)) do
		if not BossTrap.isTrapped(v.player) and (PlayerState.getHp(v.player) or 0) > 0 then
			table.insert(list, v)
		end
	end
	return list
end

local function userIdOf(player)
	return typeof(player) == "Instance" and player.UserId or 0
end

local function status(c)
	local st = c.st
	kit.send(st, "rodsStatus", { charged = st.rodsCount, required = st.rodsRequired, left = c.skill.discharges - st.rodsDone, chargedIndex = st.rodsCharged })
end

local function startDischarge(c)
	local st = c.st
	local list = aliveVictims(st)
	if #list == 0 then
		return false
	end
	st.rodsTurn = (st.rodsTurn or 0) + 1
	local v = list[((st.rodsTurn - 1) % #list) + 1] -- 번갈아(파티면 돌아가며)
	st.rodsTarget = v.player
	st.rodsPhase = "mark"
	st.rodsPhaseEndsAt = c.now + c.skill.markSeconds
	kit.send(st, "rodsTarget", { userId = userIdOf(v.player), markSeconds = c.skill.markSeconds, trackSeconds = c.skill.trackSeconds, lockSeconds = c.skill.lockSeconds })
	return true
end

local function targetFeet(c)
	for _, v in ipairs(kit.victims(c.st)) do
		if v.player == c.st.rodsTarget then
			return Vector3.new(v.root.Position.X, c.st.floorY, v.root.Position.Z)
		end
	end
	return nil
end

local function strike(c, position, radius, multiplier, label)
	local st = c.st
	kit.judgeBegin()
	for _, v in ipairs(kit.victims(st)) do
		if Reach.horizontalDistance(v.root.Position, position) <= radius and Reach.sameLayer(v.groundFeet, position) then
			kit.applySkillDamage(c.model, c.data, { damage = { kind = "attack", multiplier = multiplier }, damageLabel = label }, v.player)
		end
	end
	kit.judgeEnd(c, { kind = "circle", centers = { position }, radius = radius, inner = 0 })
end

local function finish(c, success)
	local st, skill = c.st, c.skill
	st.rodsPhase = nil
	if success then
		kit.send(st, "rodsEnd", { success = true })
		kit.send(st, "gimmickResolve", { broken = true, windowSeconds = skill.stunSeconds })
		print(("[forge-game] 번개 조준경 파훼: 피뢰침 %d/%d → 보스 기절 %.1f초"):format(st.rodsCount, st.rodsRequired, skill.stunSeconds))
		kit.endSkill(c.model, st, c.data, c.now)
		kit.stun(c.model, st, c.data, skill.stunSeconds)
		return
	end
	for _, v in ipairs(aliveVictims(st)) do
		PlayerDamage.applyMaxHpFraction(v.player, skill.failMaxHpFraction, skill.damageLabel, { ignoresShield = true })
		BossTrap.noteSkillHit(v.player)
	end
	kit.send(st, "rodsEnd", { success = false })
	kit.send(st, "gimmickResolve", { broken = false })
	print(("[forge-game] 번개 조준경 실패: 피뢰침 %d/%d → 폭풍 %.0f%%"):format(st.rodsCount, st.rodsRequired, skill.failMaxHpFraction * 100))
	kit.endSkill(c.model, st, c.data, c.now)
end

BossLightningRods.handler = {
	bubbleSeconds = function(c)
		return c.skill.telegraphSeconds
	end,
	start = function(c)
		local st, skill = c.st, c.skill
		local arena = WorldConfig.zones[MonsterState.getZoneKey(c.model) or ""]
		local center = arena and arena.center or kit.zoneOf(c.model).center
		st.rodsList = BossPropMath.kitZones(c.data.arenaKit, center, st.floorY, skill.rodTag)
		st.rodsCharged = {}
		st.rodsCount = 0
		st.rodsDone = 0
		st.rodsTurn = 0
		st.rodsRequired = BossLightningRods.requiredFor(skill, #aliveVictims(st), #st.rodsList)
		st.rodsAmbientAt = c.now + skill.telegraphSeconds + skill.ambient.everySeconds
		st.rodsAmbient = {}
		st.phase = "rodsTelegraph"
		st.rodsPhase = "telegraph"
		st.rodsPhaseEndsAt = c.now + skill.telegraphSeconds
		local rods = {}
		for _, rod in ipairs(st.rodsList) do
			table.insert(rods, { index = rod.index, center = rod.center })
		end
		kit.send(st, "rodsStart", { rods = rods, required = st.rodsRequired, discharges = skill.discharges, seconds = skill.telegraphSeconds, bossId = c.data.id })
		status(c)
		print(("[forge-game] 번개 조준경: 피뢰침 %d · 필요 %d · 방전 %d번"):format(#rods, st.rodsRequired, skill.discharges))
	end,
	step = function(c)
		local st, skill = c.st, c.skill
		-- 일반 번개(계속)
		if st.rodsPhase and c.now >= st.rodsAmbientAt then
			st.rodsAmbientAt = c.now + skill.ambient.everySeconds
			local list = aliveVictims(st)
			if #list > 0 then
				local v = list[rng:NextInteger(1, #list)]
				local at = Vector3.new(v.root.Position.X, st.floorY, v.root.Position.Z)
				table.insert(st.rodsAmbient, { position = at, at = c.now + skill.ambient.telegraphSeconds })
				kit.send(st, "rodsAmbient", { position = at, radius = skill.ambient.radiusStuds, seconds = skill.ambient.telegraphSeconds })
			end
		end
		for i = #st.rodsAmbient, 1, -1 do
			local a = st.rodsAmbient[i]
			if c.now >= a.at then
				table.remove(st.rodsAmbient, i)
				strike(c, a.position, skill.ambient.radiusStuds, skill.ambient.multiplier, "번개")
				kit.send(st, "rodsAmbientHit", { position = a.position, radius = skill.ambient.radiusStuds })
			end
		end
		if c.now < st.rodsPhaseEndsAt then
			return
		end
		local phase = st.rodsPhase
		if phase == "telegraph" or phase == "gap" then
			if st.rodsDone >= skill.discharges then
				finish(c, st.rodsCount >= st.rodsRequired)
				return
			end
			if not startDischarge(c) then
				finish(c, false)
			end
		elseif phase == "mark" then
			st.rodsPhase = "track"
			st.rodsPhaseEndsAt = c.now + skill.trackSeconds
		elseif phase == "track" then
			local at = targetFeet(c) or st.rodsLockAt or Vector3.new(c.position.X, st.floorY, c.position.Z)
			st.rodsLockAt = at
			st.rodsPhase = "lock"
			st.rodsPhaseEndsAt = c.now + skill.lockSeconds
			kit.send(st, "rodsLock", { position = at, seconds = skill.lockSeconds, radius = skill.strike.radiusStuds, reach = skill.rodReachStuds })
		elseif phase == "lock" then
			local at = st.rodsLockAt
			strike(c, at, skill.strike.radiusStuds, skill.strike.multiplier, "방전 번개")
			st.rodsDone += 1
			local hit, already = BossLightningRods.rodHit(st.rodsList, st.rodsCharged, at, skill.rodReachStuds)
			if hit then
				st.rodsCharged[hit] = true
				st.rodsCount += 1
			end
			kit.send(st, "rodsStrike", { position = at, radius = skill.strike.radiusStuds, rodIndex = hit, already = already })
			kit.debugEvent("rodsStrike", { at = c.now, rod = hit, already = already, count = st.rodsCount })
			status(c)
			if st.rodsCount >= st.rodsRequired then
				finish(c, true)
				return
			end
			st.rodsPhase = "gap"
			st.rodsPhaseEndsAt = c.now + skill.gapSeconds
		end
	end,
	interrupt = function(c)
		c.st.rodsPhase = nil
		kit.send(c.st, "rodsEnd", { success = false, interrupted = true })
	end,
}

function BossLightningRods.register(handlers, patternKit)
	kit = patternKit
	handlers.lightningRods = BossLightningRods.handler
end

return BossLightningRods
