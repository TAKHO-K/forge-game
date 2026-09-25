-- BR1-2 음파 포효(docs/design/boss-br1-2.md §6-2 · 사용자 보강 B) - primitive = "sonic"(보스 이름이 들어간 분기 없음 - 서리 거인 포효가 쓴다).
-- 흐름(수치 = 스킬 데이터):
--   시작: 멤버마다 곁(pillars.minStuds ~ maxStuds)에 큰 얼음 기둥(props[pillars.prop] - 내구 durabilityTicks) + extra개 → 전조 telegraphSeconds(보스가 숨을 들이쉰다)
--   → 음파 틱 ticks번(tickSeconds 간격): 틱마다 보스 → 사람 시야가 엄폐물(얼음 기둥 · 낙빙 기둥 · 맵 구조물)에 가리면 0(가려짐 표시), 아니면 최대 체력 × tickFraction(보호막 무시)
--     + 엄폐물은 틱마다 내구 1씩 깎인다(작은 구조물 cover.obstacleTicks · 큰 블록 cover.climbableTicks · 기둥 = 그 지형의 durabilityTicks) - 0이면 부서진다 → 그 뒤 사람은 다음 틱부터 맞는다.
--   전부 맞으면 ticks × tickFraction(= 90% - 진짜 즉사는 K). 판정은 서버(시야 = 2D 선분 · 원 - BossPropMath.isShielded), 고리 · 금 · 흔들림은 클라(BossSonicView).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossPropMath = require(ReplicatedStorage.Shared.BossPropMath)
local Reach = require(ReplicatedStorage.Shared.Reach)
local BossArenaProps = require(script.Parent.BossArenaProps)
local BossArenaMap = require(script.Parent.BossArenaMap)
local BossTrap = require(script.Parent.BossTrap)
local PlayerDamage = require(script.Parent.PlayerDamage)
local PlayerState = require(script.Parent.PlayerState)
local MonsterState = require(script.Parent.MonsterState)

local BossSonic = {}

local kit
local rng = Random.new()

-- 엄폐물 목록(지금 서 있는 것): { key, kind("prop"/"obstacle"), id, circles = { { center, r } }, hp, maxHp, position, radius }
local function coverList(c)
	local st, skill = c.st, c.skill
	st.sonicHp = st.sonicHp or {}
	local list = {}
	for _, prop in ipairs(BossArenaProps.list(c.model)) do
		local def = c.data.props and c.data.props[prop.kind]
		if def and def.durabilityTicks then
			local key = "p" .. prop.id
			st.sonicHp[key] = st.sonicHp[key] or def.durabilityTicks
			table.insert(list, { key = key, kind = "prop", id = prop.id, circles = { { center = prop.position, r = prop.radius } }, hp = st.sonicHp[key], maxHp = def.durabilityTicks, position = prop.position, radius = prop.radius })
		end
	end
	local zoneKey = MonsterState.getZoneKey(c.model)
	for _, obstacle in ipairs(BossArenaMap.obstacles(zoneKey)) do
		local key = "o" .. obstacle.id
		local maxHp = obstacle.climbable and skill.cover.climbableTicks or skill.cover.obstacleTicks
		st.sonicHp[key] = st.sonicHp[key] or maxHp
		local circles = {}
		for _, collider in ipairs(obstacle.colliders or {}) do
			table.insert(circles, { center = collider.center, r = collider.r })
		end
		if #circles == 0 then
			circles = { { center = obstacle.center, r = obstacle.radius } }
		end
		table.insert(list, { key = key, kind = "obstacle", id = obstacle.id, circles = circles, hp = st.sonicHp[key], maxHp = maxHp, position = obstacle.center, radius = obstacle.radius })
	end
	return list
end

-- 보스 → 이 사람의 시야를 가리는 엄폐물(없으면 nil). 가장자리는 플레이어에게 유리하게(몸통 반폭).
function BossSonic.coverFor(from, position, covers)
	local half = BossData.mechanics.dodge.characterHalfWidthStuds
	for _, cover in ipairs(covers) do
		for _, circle in ipairs(cover.circles) do
			if BossPropMath.isShielded(from, position, circle.center, circle.r, half) then
				return cover
			end
		end
	end
	return nil
end

local function spawnPillars(c)
	local st, skill = c.st, c.skill
	local spec = skill.pillars
	local def = c.data.props and c.data.props[spec.prop]
	if not def then
		return {}
	end
	local zone = kit.zoneOf(c.model)
	local zoneKey = MonsterState.getZoneKey(c.model)
	local anchors = {}
	for _, v in ipairs(kit.victims(st)) do
		table.insert(anchors, kit.xz(v.root.Position))
	end
	for _ = 1, spec.extra or 0 do
		local a = rng:NextNumber(0, 2 * math.pi)
		table.insert(anchors, kit.xz(zone.center) + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(30, (zone.radius or 140) * 0.6))
	end
	local made = {}
	for _, anchor in ipairs(anchors) do
		for _ = 1, 12 do
			local a = rng:NextNumber(0, 2 * math.pi)
			local spot = kit.clampToZone(anchor + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(spec.minStuds, spec.maxStuds), zone, def.radiusStuds + 6)
			local clear = not BossArenaMap.overlapsObstacle(zoneKey, spot, def.radiusStuds, 2)
			for _, v in ipairs(kit.victims(st)) do
				clear = clear and Reach.horizontalDistance(v.root.Position, spot) >= def.radiusStuds + 2
			end
			for _, other in ipairs(BossArenaProps.list(c.model)) do
				clear = clear and Reach.horizontalDistance(other.position, spot) >= def.radiusStuds + other.radius + 2
			end
			if clear then
				local position = Vector3.new(spot.X, st.floorY, spot.Z)
				local prop, evicted = BossArenaProps.spawn(c.model, spec.prop, def, position)
				kit.sendPropsRemoved(st, evicted)
				kit.send(st, "propSpawn", { id = prop.id, kind = prop.kind, position = position, radius = prop.radius, height = prop.height, color = def.color })
				table.insert(made, position)
				break
			end
		end
	end
	return made
end

BossSonic.handler = {
	bubbleSeconds = function(c)
		return c.skill.telegraphSeconds
	end,
	start = function(c)
		local st, skill = c.st, c.skill
		st.phase = "sonicTelegraph"
		st.phaseEndsAt = c.now + skill.telegraphSeconds
		st.sonicTick = 0
		st.sonicHp = {}
		local pillars = spawnPillars(c)
		kit.send(st, "sonicTelegraph", { center = Vector3.new(c.position.X, st.floorY, c.position.Z), seconds = skill.telegraphSeconds, bossId = c.data.id, pillars = pillars, ticks = skill.ticks, tickSeconds = skill.tickSeconds })
		print(("[forge-game] 음파 포효 전조: 큰 얼음 기둥 %d개 · %.1f초 뒤 %d틱"):format(#pillars, skill.telegraphSeconds, skill.ticks))
	end,
	step = function(c)
		local st, skill = c.st, c.skill
		if c.now < st.phaseEndsAt then
			return
		end
		if st.sonicTick >= skill.ticks then
			kit.send(st, "sonicEnd", {})
			kit.endSkill(c.model, st, c.data, c.now)
			return
		end
		st.phase = "sonicWave"
		st.sonicTick += 1
		st.phaseEndsAt = c.now + (st.sonicTick >= skill.ticks and (skill.recoverSeconds or 0.5) or skill.tickSeconds)
		local from = c.model:GetPivot().Position
		local covers = coverList(c)
		local shielded, hit = {}, {}
		kit.judgeBegin()
		for _, v in ipairs(kit.victims(st)) do
			if not BossTrap.isTrapped(v.player) and (PlayerState.getHp(v.player) or 0) > 0 then
				local cover = BossSonic.coverFor(from, v.root.Position, covers)
				if cover then
					table.insert(shielded, typeof(v.player) == "Instance" and v.player.UserId or 0)
					kit.debugEvent("sonicShield", { player = v.player, tick = st.sonicTick, cover = cover.key, at = c.now })
				else
					PlayerDamage.applyMaxHpFraction(v.player, skill.tickFraction, skill.damageLabel, { ignoresShield = true })
					BossTrap.noteSkillHit(v.player)
					table.insert(hit, typeof(v.player) == "Instance" and v.player.UserId or 0)
					kit.debugEvent("sonicHit", { player = v.player, tick = st.sonicTick, at = c.now })
				end
			end
		end
		kit.judgeEnd(c, { kind = "sonic", tick = st.sonicTick })
		-- 엄폐물 깎기(전부 1씩) · 0이면 부서진다
		local eroded, brokenProps = {}, {}
		local zoneKey = MonsterState.getZoneKey(c.model)
		for _, cover in ipairs(covers) do
			local hp = cover.hp - 1
			st.sonicHp[cover.key] = hp
			table.insert(eroded, { position = cover.position, radius = cover.radius, left = math.max(hp, 0) / cover.maxHp, broken = hp <= 0 })
			if hp <= 0 then
				if cover.kind == "prop" then
					table.insert(brokenProps, cover.id)
				else
					BossArenaMap.breakObstacle(zoneKey, cover.id, "sonic")
				end
			end
		end
		if #brokenProps > 0 then
			local set = {}
			for _, id in ipairs(brokenProps) do
				set[id] = true
			end
			kit.sendPropsRemoved(st, BossArenaProps.removeWhere(c.model, function(prop)
				return set[prop.id] == true
			end))
		end
		kit.send(st, "sonicTick", { center = Vector3.new(from.X, st.floorY, from.Z), tick = st.sonicTick, ticks = skill.ticks, shielded = shielded, hit = hit, eroded = eroded })
	end,
	interrupt = function(c)
		kit.send(c.st, "sonicEnd", {})
	end,
}

function BossSonic.register(handlers, patternKit)
	kit = patternKit
	handlers.sonic = BossSonic.handler
end

return BossSonic
