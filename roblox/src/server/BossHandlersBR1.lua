-- BR1 새 조각 핸들러(docs/design/boss-br1.md §0) - BossPatterns의 HANDLERS 표에 primitive 이름으로 꽂는다(보스 이름이 들어간 함수는 없다).
--   sector     보스 중심 부채꼴 · 반원 · 반면(angleDeg · radiusStuds · innerRadiusStuds · facing = "target" / "randomSide", jumpable, volleyShots)
--   projectile 투사체(count · speedStuds · turnRateDeg · radiusStuds · lifetimeSeconds · targetRule · heightMode "air"/"ground" · pierce · onHit)
--              쏜 뒤에는 스킬과 떨어져 난다(st.projectiles - BossPatterns.step이 매 틱 stepProjectiles를 부른다) - 보스는 다음 스킬을 고를 수 있다.
--   vortex     소용돌이(끌림 telegraphSeconds 동안 · 클라가 자기 캐릭터를 당긴다 - 걷기보다 느리게) → 중심 폭발 원
-- 판정은 전부 여기(서버), 그림은 클라(BossBR1View) - 보이는 장판 = 실제 판정. kit = BossPatterns가 넘기는 공용 함수 표(victims · send · …).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossSkillMath = require(ReplicatedStorage.Shared.BossSkillMath)
local Reach = require(ReplicatedStorage.Shared.Reach)
local BossTrap = require(script.Parent.BossTrap)
local PlayerState = require(script.Parent.PlayerState)

local BossHandlersBR1 = {}

local PROJECTILE_SYNC_SECONDS = 0.1 -- 투사체 위치를 멤버에게 알리는 간격(클라는 사이를 잇는다)

local kit -- register가 받는다

local function angleToTarget(c)
	if not c.targetRoot then
		return 0
	end
	local toTarget = kit.xz(c.targetRoot.Position) - kit.xz(c.position)
	return toTarget.Magnitude > 1e-3 and math.deg(math.atan2(toTarget.Z, toTarget.X)) or 0
end

-- 두 각(도)의 차(−180 ~ 180).
local function angleDiff(a, b)
	return (a - b + 180) % 360 - 180
end

-- 스킬 피해를 배율만 바꿔 넣는다(볼리 · 칸마다 배율이 다른 스킬).
local function damageWith(c, multiplier, player, label)
	local skill = c.skill
	if multiplier and skill.damage.kind == "attack" and multiplier ~= skill.damage.multiplier then
		kit.applySkillDamage(c.model, c.data, { damage = { kind = "attack", multiplier = multiplier }, damageLabel = label or skill.damageLabel }, player)
	else
		kit.applySkillDamage(c.model, c.data, skill, player)
	end
end

-- ─────────────────────────── sector ───────────────────────────
local function beginSectorVolley(c, centerDeg)
	local st, skill = c.st, c.skill
	local volley = BossSkillMath.volleysOf(skill)[st.sectorVolley]
	st.sectorCenterDeg = centerDeg
	st.sectorOrigin = kit.xz(c.position)
	st.phase = "sectorTelegraph"
	st.phaseEndsAt = c.now + volley.telegraphSeconds
	local radius = volley.radiusStuds or kit.zoneOf(c.model).radius or 140
	st.sectorRadius = radius
	kit.send(st, "sector", {
		center = Vector3.new(st.sectorOrigin.X, st.floorY, st.sectorOrigin.Z),
		angleDeg = centerDeg, widthDeg = volley.angleDeg, radius = radius, innerRadius = skill.innerRadiusStuds,
		seconds = volley.telegraphSeconds, jumpable = skill.jumpable == true,
		bossId = c.data.id, motion = skill.motion, volley = st.sectorVolley,
		zoneCenter = kit.zoneOf(c.model).center, zoneRadius = kit.zoneOf(c.model).radius,
	})
end

local function firstSectorAngle(c)
	local skill = c.skill
	local base = angleToTarget(c)
	if skill.facing == "randomSide" then
		return base + (kit.rng:NextNumber() < 0.5 and 90 or -90) -- 보스 → 대상 선의 왼쪽 반 또는 오른쪽 반
	end
	return base
end

BossHandlersBR1.sector = {
	bubbleSeconds = function(c)
		local total = 0
		for _, volley in ipairs(BossSkillMath.volleysOf(c.skill)) do
			total += volley.telegraphSeconds
		end
		return total
	end,
	start = function(c)
		c.st.sectorVolley = 1
		beginSectorVolley(c, firstSectorAngle(c))
	end,
	step = function(c)
		local st, skill = c.st, c.skill
		if c.now < st.phaseEndsAt then
			return
		end
		local volleys = BossSkillMath.volleysOf(skill)
		local volley = volleys[st.sectorVolley]
		local inner = skill.innerRadiusStuds or 0
		local floor = Vector3.new(0, st.floorY, 0)
		kit.judgeBegin()
		for _, v in ipairs(kit.victims(st)) do
			local rel = kit.xz(v.root.Position) - st.sectorOrigin
			local d = rel.Magnitude
			local inWedge = d <= st.sectorRadius and d >= inner
				and (d < 1e-3 or math.abs(angleDiff(math.deg(math.atan2(rel.Z, rel.X)), st.sectorCenterDeg)) <= volley.angleDeg / 2)
			if inWedge and Reach.sameLayer(v.groundFeet, floor) then -- 발 기준(P3a D3)
				if not (skill.jumpable and kit.isAirborne(v.player.Character, 0.5)) then
					damageWith(c, volley.multiplier, v.player)
				end
			end
		end
		kit.judgeEnd(c, { kind = "sector", origin = Vector3.new(st.sectorOrigin.X, st.floorY, st.sectorOrigin.Z), angleDeg = st.sectorCenterDeg, widthDeg = volley.angleDeg, radius = st.sectorRadius, inner = inner })
		kit.send(st, "sectorImpact", {
			center = Vector3.new(st.sectorOrigin.X, st.floorY, st.sectorOrigin.Z), angleDeg = st.sectorCenterDeg, widthDeg = volley.angleDeg,
			radius = st.sectorRadius, innerRadius = skill.innerRadiusStuds, bossId = c.data.id, motion = skill.motion,
		})
		if st.sectorVolley < #volleys then
			st.sectorVolley += 1
			local nextVolley = volleys[st.sectorVolley]
			beginSectorVolley(c, nextVolley.rotateDeg and (st.sectorCenterDeg + nextVolley.rotateDeg) or firstSectorAngle(c))
			return
		end
		kit.endSkill(c.model, st, c.data, c.now)
	end,
}

-- ─────────────────────────── projectile ───────────────────────────
-- 대상 규칙: "airborne"(공중에 뜬 사람만 - 없으면 쏘지 않는다: 스킬 조건 memberAirborne이 막는다) · "airbornePreferred"(뜬 사람 우선, 없으면 어그로 대상) · "target"(어그로 대상).
local function pickProjectileTargets(c, count)
	local rule = c.skill.targetRule or "target"
	local list = {}
	if rule ~= "target" then
		local airborne = {}
		for _, v in ipairs(kit.victims(c.st)) do
			if not BossTrap.isTrapped(v.player) and kit.isAirborne(v.player.Character, 0.5) then
				table.insert(airborne, v)
			end
		end
		table.sort(airborne, function(a, b)
			return kit.airSecondsOf(c.st, a.player, c.now) > kit.airSecondsOf(c.st, b.player, c.now)
		end)
		for i = 1, count do
			if #airborne > 0 then
				list[i] = airborne[((i - 1) % #airborne) + 1]
			end
		end
		if rule == "airborne" then
			return list
		end
	end
	for i = 1, count do
		if not list[i] then
			for _, v in ipairs(kit.victims(c.st)) do
				if v.root == c.targetRoot then
					list[i] = v
				end
			end
		end
	end
	return list
end

local nextProjectileId = 0

local function launchProjectile(c, index)
	local st, skill = c.st, c.skill
	local target = st.projTargets[index]
	if not target then
		return
	end
	local origin = kit.xz(c.position)
	local y = skill.heightMode == "ground" and (st.floorY + skill.radiusStuds * 0.6) or (st.floorY + (skill.launchHeightStuds or 9))
	local position = Vector3.new(origin.X, y, origin.Z)
	local aim = target.root.Position
	if skill.heightMode == "ground" then
		aim = Vector3.new(aim.X, y, aim.Z)
	end
	local spread = (skill.spreadDeg or 0) * (index - (skill.count + 1) / 2)
	local dir = aim - position
	if dir.Magnitude < 1e-3 then
		dir = Vector3.new(1, 0, 0)
	end
	dir = (CFrame.fromAxisAngle(Vector3.yAxis, math.rad(spread)) * dir).Unit
	nextProjectileId += 1
	local projectile = {
		id = nextProjectileId, position = position, dir = dir, speed = skill.speedStuds, turnRad = math.rad(skill.turnRateDeg or 0),
		radius = skill.radiusStuds, expiresAt = c.now + (skill.lifetimeSeconds or 6), target = target.player,
		heightMode = skill.heightMode or "air", pierce = skill.pierce == true, hitBy = {}, skill = skill, data = c.data, model = c.model,
	}
	st.projectiles = st.projectiles or {}
	table.insert(st.projectiles, projectile)
	kit.send(st, "projSpawn", {
		id = projectile.id, position = position, dir = dir, speed = skill.speedStuds, radius = skill.radiusStuds, style = skill.projectileStyle,
		heightMode = projectile.heightMode, bossId = c.data.id, targetUserId = typeof(target.player) == "Instance" and target.player.UserId or nil,
	})
end

BossHandlersBR1.projectile = {
	bubbleSeconds = function(c)
		return c.skill.telegraphSeconds
	end,
	start = function(c)
		local st, skill = c.st, c.skill
		st.phase = "projTelegraph"
		st.phaseEndsAt = c.now + skill.telegraphSeconds
		st.projTargets = pickProjectileTargets(c, skill.count or 1)
		st.projLaunched = 0
		local userIds = {}
		for i, v in pairs(st.projTargets) do
			userIds[i] = typeof(v.player) == "Instance" and v.player.UserId or nil
		end
		kit.send(st, "projTelegraph", {
			center = Vector3.new(c.position.X, st.floorY, c.position.Z), seconds = skill.telegraphSeconds, count = skill.count or 1,
			style = skill.projectileStyle, heightMode = skill.heightMode or "air", targetUserIds = userIds, bossId = c.data.id, motion = skill.motion,
			launchHeight = skill.launchHeightStuds or 9,
		})
	end,
	step = function(c)
		local st, skill = c.st, c.skill
		local interval = skill.launchIntervalSeconds or 0
		while st.projLaunched < (skill.count or 1) and c.now >= st.phaseEndsAt + interval * st.projLaunched do
			st.projLaunched += 1
			launchProjectile(c, st.projLaunched)
		end
		if st.projLaunched >= (skill.count or 1) then
			kit.endSkill(c.model, st, c.data, c.now)
		end
	end,
}

-- 살아 있는 투사체를 한 틱 움직이고 맞힌다(스킬 진행과 무관 - BossPatterns.step이 매 틱 부른다).
function BossHandlersBR1.stepProjectiles(model, st, data, now, dt)
	local list = st.projectiles
	if not list or #list == 0 then
		return
	end
	local zone = kit.zoneOf(model)
	local half = BossData.mechanics.dodge.characterHalfWidthStuds
	local targets = kit.victims(st)
	local alive = {}
	local ended = {}
	for _, p in ipairs(list) do
		local done = now >= p.expiresAt
		if not done then
			-- 방향 돌리기(turnRad/초 상한) - 대상의 지금 자리 쪽으로.
			local target = nil
			for _, v in ipairs(targets) do
				if v.player == p.target then
					target = v
				end
			end
			if target and p.turnRad > 0 then
				local desired = target.root.Position - p.position
				if p.heightMode == "ground" then
					desired = Vector3.new(desired.X, 0, desired.Z)
				end
				if desired.Magnitude > 1e-3 then
					desired = desired.Unit
					local angle = math.acos(math.clamp(p.dir:Dot(desired), -1, 1))
					local maxTurn = p.turnRad * dt
					if angle <= maxTurn or angle < 1e-4 then
						p.dir = desired
					else
						local axis = p.dir:Cross(desired)
						if axis.Magnitude < 1e-4 then
							axis = Vector3.yAxis
						end
						p.dir = (CFrame.fromAxisAngle(axis.Unit, maxTurn) * p.dir).Unit
					end
				end
			end
			p.position += p.dir * p.speed * dt
			if p.heightMode == "ground" then
				p.position = Vector3.new(p.position.X, st.floorY + p.radius * 0.6, p.position.Z)
			end
			-- 아레나 밖으로 나가면 끝(벽에 부서진다).
			local fromCenter = Vector3.new(p.position.X - zone.center.X, 0, p.position.Z - zone.center.Z).Magnitude
			if zone.radius and fromCenter > zone.radius then
				done = true
			end
		end
		if not done then
			for _, v in ipairs(targets) do
				if not p.hitBy[v.player] and not BossTrap.isTrapped(v.player) then
					local hit
					if p.heightMode == "ground" then
						-- 지면을 굴러 온다: 수평 반경 안 + 발이 지면 + groundHitHeightStuds 아래(점프로 넘는다).
						local groundHeight = v.groundFeet.Y - st.floorY
						hit = Reach.horizontalDistance(v.root.Position, p.position) <= p.radius + half and groundHeight <= (p.skill.groundHitHeightStuds or 4)
					else
						hit = (v.root.Position - p.position).Magnitude <= p.radius + half
					end
					if hit then
						p.hitBy[v.player] = true
						local c = { model = model, st = st, data = data, skill = p.skill, now = now, position = p.position }
						kit.judgeBegin()
						damageWith(c, nil, v.player)
						kit.judgeEnd(c, { kind = "projectile", center = p.position, radius = p.radius })
						if p.skill.onHit then
							kit.runHitEffects(c, p.skill.onHit, v, p.position - Vector3.new(0, 0, 0), 1)
						end
						kit.debugEvent("projectileHit", { player = v.player, id = p.id, at = now })
						if not p.pierce then
							done = true
							break
						end
					end
				end
			end
		end
		if done then
			table.insert(ended, { id = p.id, position = p.position })
		else
			table.insert(alive, p)
		end
	end
	st.projectiles = alive
	for _, e in ipairs(ended) do
		kit.send(st, "projEnd", e)
	end
	if #alive > 0 and now - (st.projSyncAt or 0) >= PROJECTILE_SYNC_SECONDS then
		st.projSyncAt = now
		local sync = {}
		for _, p in ipairs(alive) do
			table.insert(sync, { id = p.id, position = p.position, dir = p.dir })
		end
		kit.send(st, "projSync", { list = sync })
	end
end

function BossHandlersBR1.clearProjectiles(st)
	if st and st.projectiles then
		st.projectiles = {}
	end
end

-- ─────────────────────────── vortex ───────────────────────────
-- 끌림(클라): 반경 안에 있는 동안 자기 캐릭터를 중심 쪽으로 pullStudsPerSecond(걷기 16보다 느리게 - 버티면 나간다). 서버는 끌림을 계산하지 않는다 -
-- 끌림은 "피하기를 어렵게 하는 힘"일 뿐이고 판정은 끌림이 끝나는 순간의 폭발 원이다(보이는 원 = 판정).
BossHandlersBR1.vortex = {
	bubbleSeconds = function(c)
		return c.skill.telegraphSeconds
	end,
	start = function(c)
		local st, skill = c.st, c.skill
		st.phase = "vortexPull"
		st.phaseEndsAt = c.now + skill.telegraphSeconds
		st.vortexCenter = Vector3.new(c.position.X, st.floorY, c.position.Z)
		kit.send(st, "vortex", {
			center = st.vortexCenter, radius = skill.radiusStuds, pullStudsPerSecond = skill.pullStudsPerSecond,
			seconds = skill.telegraphSeconds, burstRadius = skill.burstRadiusStuds, bossId = c.data.id, motion = skill.motion,
		})
	end,
	step = function(c)
		local st, skill = c.st, c.skill
		if c.now < st.phaseEndsAt then
			return
		end
		kit.judgeBegin()
		for _, v in ipairs(kit.victims(st)) do
			if Reach.horizontalDistance(v.root.Position, st.vortexCenter) <= skill.burstRadiusStuds and Reach.sameLayer(v.groundFeet, st.vortexCenter) then
				kit.applySkillDamage(c.model, c.data, skill, v.player)
			end
		end
		kit.judgeEnd(c, { kind = "circle", centers = { st.vortexCenter }, radius = skill.burstRadiusStuds, inner = 0 })
		kit.send(st, "vortexBurst", { center = st.vortexCenter, radius = skill.burstRadiusStuds })
		kit.endSkill(c.model, st, c.data, c.now)
	end,
}

-- ─────────────────────────── 체공 추적(대공 잡기 · 투사체 · 발동 조건) ───────────────────────────
-- 멤버마다 "연속으로 떠 있기 시작한 시각". 매 틱 Humanoid 상태(Jumping · Freefall - 서버로 즉시 복제된다)로 싸게 갱신한다 - 잡기 판정 순간에는
-- 지면 거리까지 재는 kit.isAirborne으로 한 번 더 확인한다(BossAirGrab). 착지하면 0.
local AIR_STATES = { [Enum.HumanoidStateType.Jumping] = true, [Enum.HumanoidStateType.Freefall] = true }

function BossHandlersBR1.trackAir(st, now)
	st.airSince = st.airSince or {}
	local seen = {}
	for _, member in ipairs(st.members or {}) do
		local character = typeof(member) == "Instance" and member.Character or (type(member) == "table" and member.Character)
		local humanoid = character and character.FindFirstChildOfClass and character:FindFirstChildOfClass("Humanoid")
		local airborne = false
		if humanoid then
			airborne = AIR_STATES[humanoid:GetState()] == true
		elseif type(member) == "table" and member.debugAirborne ~= nil then
			airborne = member.debugAirborne -- 검증 스탠드인
		end
		if airborne and (PlayerState.getHp(member) or 0) > 0 then
			st.airSince[member] = st.airSince[member] or now
		else
			st.airSince[member] = nil
		end
		seen[member] = true
	end
	for member in pairs(st.airSince) do
		if not seen[member] then
			st.airSince[member] = nil
		end
	end
end

function BossHandlersBR1.airSecondsOf(st, player, now)
	local since = st.airSince and st.airSince[player]
	return since and (now - since) or 0
end

function BossHandlersBR1.register(handlers, patternKit)
	kit = patternKit
	kit.airSecondsOf = BossHandlersBR1.airSecondsOf
	handlers.sector = BossHandlersBR1.sector
	handlers.projectile = BossHandlersBR1.projectile
	handlers.vortex = BossHandlersBR1.vortex
end

return BossHandlersBR1
