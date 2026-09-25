-- BR1 새 조각 핸들러(docs/design/boss-br1.md §0) - BossPatterns의 HANDLERS 표에 primitive 이름으로 꽂는다(보스 이름이 들어간 함수는 없다).
--   sector     보스 중심 부채꼴 · 반원 · 반면(angleDeg · radiusStuds · innerRadiusStuds · facing = "target" / "randomSide", jumpable, volleyShots)
--   projectile 투사체(count · speedStuds · turnRateDeg · radiusStuds · lifetimeSeconds · targetRule · heightMode "air"/"ground" · pierce · onHit)
--              쏜 뒤에는 스킬과 떨어져 난다(st.projectiles - BossPatterns.step이 매 틱 stepProjectiles를 부른다) - 보스는 다음 스킬을 고를 수 있다.
--   vortex     소용돌이(끌림 telegraphSeconds 동안 · 클라가 자기 캐릭터를 당긴다 - 걷기보다 느리게) → 중심 폭발 원
-- 판정은 전부 여기(서버), 그림은 클라(BossBR1View) - 보이는 장판 = 실제 판정. kit = BossPatterns가 넘기는 공용 함수 표(victims · send · …).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossSkillMath = require(ReplicatedStorage.Shared.BossSkillMath)
local BossCurveData = require(ReplicatedStorage.Shared.data.BossCurveData)
local Reach = require(ReplicatedStorage.Shared.Reach)
local BossTrap = require(script.Parent.BossTrap)
local PlayerState = require(script.Parent.PlayerState)
local MonsterState = require(script.Parent.MonsterState)
local PlayerDamage = require(script.Parent.PlayerDamage)
local HeightGuard = require(script.Parent.HeightGuard)
local BossMechanics = require(script.Parent.BossMechanics) -- BR1-3 아르마딜로 태세(반사의 귀)

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
		outline = skill.outline, weaponFlash = skill.weaponFlash, -- BR1-3 강화 평타: 흰 테두리 두 줄 · 무기 번쩍
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
					if skill.onHit then -- BR1-3 강화 평타 기절
						kit.runHitEffects(c, skill.onHit, v, Vector3.new(st.sectorOrigin.X, st.floorY, st.sectorOrigin.Z), 1)
					end
				end
			end
		end
		kit.judgeEnd(c, { kind = "sector", origin = Vector3.new(st.sectorOrigin.X, st.floorY, st.sectorOrigin.Z), angleDeg = st.sectorCenterDeg, widthDeg = volley.angleDeg, radius = st.sectorRadius, inner = inner })
		kit.send(st, "sectorImpact", {
			center = Vector3.new(st.sectorOrigin.X, st.floorY, st.sectorOrigin.Z), angleDeg = st.sectorCenterDeg, widthDeg = volley.angleDeg,
			radius = st.sectorRadius, innerRadius = skill.innerRadiusStuds, bossId = c.data.id, motion = skill.motion,
		})
		if skill.afterField then -- BR1 판정 뒤 남는 장(빙판 - 미끄러짐은 클라 관성 · 판정 없음)
			kit.send(st, "field", { kind = skill.afterField.kind, center = Vector3.new(st.sectorOrigin.X, st.floorY, st.sectorOrigin.Z), radius = skill.afterField.radiusStuds, seconds = skill.afterField.seconds })
		end
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
-- 대상 규칙: "airborne"(공중에 뜬 사람만 - 없으면 쏘지 않는다: 스킬 조건 memberAirborne이 막는다) · "airbornePreferred"(뜬 사람이 있으면 그들, 없으면 전원) · "target"(전원).
-- BR1-2 인당(docs/design/boss-br1-2.md §1): 반환 = 대상 멤버 목록 - 한 사람마다 skill.count(곡선의 인당 개수)발을 쏜다(4인 × 8 = 32).
local function pickProjectileTargets(c)
	local rule = c.skill.targetRule or "target"
	local all, airborne = {}, {}
	for _, v in ipairs(kit.victims(c.st)) do
		if not BossTrap.isTrapped(v.player) then
			table.insert(all, v)
			if kit.airSecondsOf(c.st, v.player, c.now) >= (c.skill.minAirSeconds or 0.2) then -- 리뷰 7: 발동 조건(memberAirborne)과 같은 잣대
				table.insert(airborne, v)
			end
		end
	end
	if rule == "airborne" or (rule == "airbornePreferred" and #airborne > 0) then
		return airborne
	end
	return all
end

-- 예측 조준(사용자 - 이속이 높으니 유도 공격도 따라와야 한다): 대상의 지금 속도(루트 AssemblyLinearVelocity - 캐릭터 물리는 그 클라 소유라 서버로 복제된다)로
-- "투사체가 닿을 즈음의 자리"를 겨눈다. 예측 시간 = 거리 ÷ 투사체 속도(상한 skill.leadSeconds). 지면 투사체는 수평 속도만. 스탠드인(속도 없음)은 지금 자리.
local function predictedAim(skill, from, root, heightMode)
	local at = root.Position
	local velocity = typeof(root) == "Instance" and root.AssemblyLinearVelocity or nil
	local lead = skill.leadSeconds or 0
	if velocity and lead > 0 then
		if heightMode == "ground" then
			velocity = Vector3.new(velocity.X, 0, velocity.Z)
		end
		local t = math.min((at - from).Magnitude / math.max(skill.speedStuds, 1), lead)
		at += velocity * t
	end
	return at
end

local nextProjectileId = 0

local function aliveProjectileCount(st)
	return st.projectiles and #st.projectiles or 0
end

local function launchProjectile(c, index, target)
	local st, skill = c.st, c.skill
	if not target or aliveProjectileCount(st) >= BossCurveData.arenaProjectileCap then
		return false -- BR1-2 아레나당 동시 투사체 상한(성능)
	end
	local origin = kit.xz(c.position)
	local y = skill.heightMode == "ground" and (st.floorY + skill.radiusStuds * 0.6) or (st.floorY + (skill.launchHeightStuds or 9))
	local position = Vector3.new(origin.X, y, origin.Z)
	local aim = predictedAim(skill, position, target.root, skill.heightMode)
	if skill.heightMode == "ground" then
		aim = Vector3.new(aim.X, y, aim.Z)
	end
	-- 부채 폭은 곡선으로 개수가 늘어도 전체 ±30° 안(BR1-2 - 8발이면 칸 사이 60 ÷ 7)
	local step = skill.count > 1 and math.min(skill.spreadDeg or 0, 60 / (skill.count - 1)) or 0
	local spread = step * (index - (skill.count + 1) / 2)
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
		bouncesLeft = skill.bounces or 0,
		-- BR1-2 반사 대비(K 성기사 패링 · 반사 대결): 소유자 · 반사 가능 · 반사 횟수
		owner = { kind = "boss", model = c.model }, reflectable = skill.reflectable ~= false, reflections = 0,
	}
	st.projectiles = st.projectiles or {}
	table.insert(st.projectiles, projectile)
	kit.send(st, "projSpawn", {
		id = projectile.id, position = position, dir = dir, speed = skill.speedStuds, radius = skill.radiusStuds, style = skill.projectileStyle,
		heightMode = projectile.heightMode, bossId = c.data.id, targetUserId = typeof(target.player) == "Instance" and target.player.UserId or nil,
	})
	return true
end

BossHandlersBR1.projectile = {
	bubbleSeconds = function(c)
		return c.skill.telegraphSeconds
	end,
	start = function(c)
		local st, skill = c.st, c.skill
		st.phase = "projTelegraph"
		st.phaseEndsAt = c.now + skill.telegraphSeconds
		st.projTargets = pickProjectileTargets(c)
		st.projLaunched = 0
		local userIds = {}
		for _, v in ipairs(st.projTargets) do
			table.insert(userIds, typeof(v.player) == "Instance" and v.player.UserId or 0)
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
		-- 한 사람 몫은 interval 간격으로 차례로, 멤버끼리는 같은 순간(라운드마다 대상 전원에게 한 발씩)
		while st.projLaunched < (skill.count or 1) and c.now >= st.phaseEndsAt + interval * st.projLaunched do
			st.projLaunched += 1
			for _, target in ipairs(st.projTargets) do
				launchProjectile(c, st.projLaunched, target)
			end
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
		local holding = p.holdUntil and now < p.holdUntil -- BR1-2 반사: 보스 곁에서 모으는 중
		if not done and not holding and p.holdUntil and not p.announced then
			p.announced = true
			kit.send(st, "projSpawn", { id = p.id, position = p.position, dir = p.dir, speed = p.speed, radius = p.radius, style = p.skill.projectileStyle, heightMode = p.heightMode, bossId = data.id })
		end
		if not done and not holding then
			-- 방향 돌리기(turnRad/초 상한) - 대상의 지금 자리 쪽으로.
			local target = nil
			for _, v in ipairs(targets) do
				if v.player == p.target then
					target = v
				end
			end
			if target and p.turnRad > 0 then
				local desired = predictedAim(p.skill, p.position, target.root, p.heightMode) - p.position -- 예측 조준으로 돈다
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
				if p.bouncesLeft > 0 then
					-- 벽 튕김(skill.bounces): 벽 안으로 되돌리고, bounceRetarget = "farthest"면 **튕기는 순간 가장 먼 사람의 (예측) 자리**를 기억해
					-- 그쪽으로 곧게 간다(아니면 거울 반사). 튕길 때마다 이미 맞은 사람도 다시 맞을 수 있다.
					p.bouncesLeft -= 1
					local outward = Vector3.new(p.position.X - zone.center.X, 0, p.position.Z - zone.center.Z).Unit
					p.position = Vector3.new(zone.center.X, p.position.Y, zone.center.Z) + outward * (zone.radius - p.radius - 0.5)
					local newDir = nil
					if p.skill.bounceRetarget == "farthest" then
						local far, farDistance = nil, -1
						for _, v in ipairs(targets) do
							if not BossTrap.isTrapped(v.player) then
								local d = Vector3.new(v.root.Position.X - p.position.X, 0, v.root.Position.Z - p.position.Z).Magnitude
								if d > farDistance then
									far, farDistance = v, d
								end
							end
						end
						if far then
							local aim = predictedAim(p.skill, p.position, far.root, p.heightMode)
							local flat = Vector3.new(aim.X - p.position.X, 0, aim.Z - p.position.Z)
							if flat.Magnitude > 1e-3 then
								newDir = flat.Unit
								p.target = far.player
								p.bounceAim = aim
							end
						end
					end
					if not newDir then
						local d = Vector3.new(p.dir.X, 0, p.dir.Z)
						newDir = (d - outward * (2 * d:Dot(outward))).Unit
					end
					p.dir = newDir
					p.hitBy = {}
					p.expiresAt = math.max(p.expiresAt, now + (p.skill.bounceLifetimeSeconds or 6))
					kit.send(st, "projBounce", { id = p.id, position = p.position, dir = p.dir, aim = p.bounceAim })
					kit.debugEvent("projectileBounce", { id = p.id, at = now, target = p.target, left = p.bouncesLeft })
				else
					done = true
				end
			end
		end
		if not done and not holding and p.owner and p.owner.kind == "player" then
			-- BR1-2 되튕겨진 투사체(K 패링 · 지금은 /gg reflectshot): 사람은 안 치고 보스에 맞으면 에어본(BossPatterns.bossAirborne)
			local cfg = BossData.mechanics.bossAirborne
			local bossAt = model:GetPivot().Position
			if (Vector3.new(bossAt.X, p.position.Y, bossAt.Z) - p.position).Magnitude <= cfg.hitRadiusStuds + p.radius then
				done = true
				kit.bossAirborne(model, st, data, now, p)
			end
		elseif not done and not holding then -- 모으는 중(반사 윈드업)에는 아무도 안 맞는다
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
						if p.skill.damage.kind == "maxHpRaw" then -- BR1-2 반사된 투사체: 한 방에 죽을 수 있는 큰 피해(감소 · 1 ~ 30 보호 적용)
							PlayerDamage.applyMaxHpFraction(v.player, p.skill.damage.fraction, p.skill.damageLabel)
							BossTrap.noteSkillHit(v.player)
						else
							damageWith(c, nil, v.player)
						end
						kit.judgeEnd(c, { kind = "projectile", center = p.position, radius = p.radius })
						if p.skill.onHit then
							kit.runHitEffects(c, p.skill.onHit, v, p.position - Vector3.new(0, 0, 0), 1)
						end
						if p.skill.trapOnHits then
							BossHandlersBR1.noteTrapHit(c, v, p.skill.trapOnHits)
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

-- BR1-2 공중 가둠(설계 §4): 이 사람이 trapOnHits.windowSeconds 안에 hits번 맞았으면 그 자리 발 + liftStuds 공중에 가둔다(BossTrap kind "bubbled" - 면역 · 행동 막힘 ·
-- seconds 뒤 떨어진다). 탈출 = 점프 연타 presses회(BossAirGrab.press) 또는 동료 F 홀드(rescue.bubble). 갇힌 동안은 "공중"(대공 잡기의 얼림 대상).
function BossHandlersBR1.noteTrapHit(c, v, spec)
	local st = c.st
	st.trapHits = st.trapHits or {}
	local list = st.trapHits[v.player] or {}
	st.trapHits[v.player] = list
	table.insert(list, c.now)
	while #list > 0 and c.now - list[1] > spec.windowSeconds do
		table.remove(list, 1)
	end
	if #list < spec.hits or BossTrap.isTrapped(v.player) or (PlayerState.getHp(v.player) or 0) <= 0 then
		return false
	end
	st.trapHits[v.player] = {}
	local lifted = v.root.Position + Vector3.new(0, spec.liftStuds, 0)
	if not BossTrap.trap(v.player, {
		kind = "bubbled", rescueType = "bubble", autoReleaseSeconds = spec.seconds,
		context = { origin = lifted, zoneKey = MonsterState.getZoneKey(c.model), bossModel = c.model, style = spec.style, presses = spec.presses, pressed = 0 },
	}) then
		return false
	end
	HeightGuard.exempt(v.player, spec.seconds + 2)
	if typeof(v.root) == "Instance" then
		v.root.CFrame = CFrame.new(lifted) * v.root.CFrame.Rotation
	else
		v.root.Position = lifted
	end
	kit.send(st, "bubbleTrap", { userId = typeof(v.player) == "Instance" and v.player.UserId or nil, position = lifted, seconds = spec.seconds, style = spec.style, presses = spec.presses })
	kit.debugEvent("bubbleTrap", { player = v.player, at = c.now })
	print(("[forge-game] 공중 가둠(%s): %s - %d번 맞음"):format(spec.style, tostring(v.player.Name), spec.hits))
	return true
end

-- BR1-2 개발 명령(/gg reflectshot): 보스의 투사체 스킬 skillId 모양으로 "되튕겨진 투사체"를 플레이어 자리에서 보스 쪽으로 쏜다(성기사 패링 흉내 - 소유자 = 그 플레이어 · 반사 1회).
function BossHandlersBR1.debugReflectedShot(model, st, data, player, skillId)
	local skill = data.skills[skillId]
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not (skill and skill.primitive == "projectile" and root) then
		return false
	end
	local bossAt = model:GetPivot().Position
	local from = root.Position + Vector3.new(0, 1, 0)
	local flat = Vector3.new(bossAt.X - from.X, bossAt.Y - from.Y, bossAt.Z - from.Z)
	local dir = flat.Magnitude > 1e-3 and flat.Unit or Vector3.new(1, 0, 0)
	nextProjectileId += 1
	local projectile = {
		id = nextProjectileId, position = from, dir = dir, speed = 30, turnRad = 0, radius = skill.radiusStuds,
		expiresAt = os.clock() + flat.Magnitude / 30 + 2, heightMode = "air", pierce = false, hitBy = {}, bouncesLeft = 0, model = model, data = data,
		skill = skill, owner = { kind = "player", player = player }, reflectable = true, reflections = 1,
	}
	st.projectiles = st.projectiles or {}
	table.insert(st.projectiles, projectile)
	kit.send(st, "projSpawn", { id = projectile.id, position = from, dir = dir, speed = 30, radius = skill.radiusStuds, style = skill.projectileStyle, heightMode = "air", bossId = data.id })
	return true
end

function BossHandlersBR1.clearProjectiles(st)
	if st and st.projectiles then
		st.projectiles = {}
	end
	if st then
		st.spikes = nil -- BR1-3 떨어지던 가시도(리셋 · 중단)
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

-- ─────────────────────────── reflect(BR1-2 투사체 반사 - 설계 §5) ───────────────────────────
-- 전조(결계가 솟는다) → 반사 stanceSeconds. 반사 동안 원거리 평타가 닿으면 AttackServer가 BossHandlersBR1.tryReflect를 부른다 → 피해 0 · 되돌리는 투사체(보스 판정).
local RANGED_CLASSES = { bow = true, healer = true } -- ProjectileConfig.kindByClass와 같은 직업(원거리 평타 = 투사체)

local function rangedUserIds(st)
	local ids = {}
	for _, v in ipairs(kit.victims(st)) do
		if typeof(v.player) == "Instance" and RANGED_CLASSES[v.player:GetAttribute("ClassId") or ""] then
			table.insert(ids, v.player.UserId)
		end
	end
	return ids
end

BossHandlersBR1.reflect = {
	bubbleSeconds = function(c)
		return c.skill.telegraphSeconds
	end,
	start = function(c)
		local st, skill = c.st, c.skill
		st.phase = "reflectTelegraph"
		st.phaseEndsAt = c.now + skill.telegraphSeconds
		st.reflectBy = {}
		kit.send(st, "reflectTelegraph", { center = Vector3.new(c.position.X, st.floorY, c.position.Z), seconds = skill.telegraphSeconds, radius = skill.barrierRadiusStuds,
			bossId = c.data.id, motion = skill.motion, color = c.data.headColor, style = skill.counter and "armadillo" or nil })
	end,
	step = function(c)
		local st, skill = c.st, c.skill
		if c.now < st.phaseEndsAt then
			return
		end
		if st.phase == "reflectTelegraph" then
			st.phase = "reflectStance"
			st.phaseEndsAt = c.now + skill.stanceSeconds
			if skill.counter then
				-- BR1-3 아르마딜로: 받는 피해 0 · 때린 사람(근접 · 원거리 모두 - 설치형 규칙은 beginReflect가 본다)의 그 순간 자리로 가시
				local model, data = c.model, c.data
				BossMechanics.beginReflect(model, { damageTakenMultiplier = 0 }, skill.damageLabel, function(player)
					BossHandlersBR1.throwSpike(model, st, data, skill, player)
				end, true)
			end
			kit.send(st, "reflectStance", { center = Vector3.new(c.position.X, st.floorY, c.position.Z), seconds = skill.stanceSeconds, radius = skill.barrierRadiusStuds,
				bossId = c.data.id, color = c.data.headColor, rangedUserIds = (not skill.counter) and rangedUserIds(st) or {}, style = skill.counter and "armadillo" or nil })
			return
		end
		if skill.counter then
			BossMechanics.endReflect(c.model)
		end
		kit.send(st, "reflectEnd", {})
		kit.endSkill(c.model, st, c.data, c.now)
	end,
	interrupt = function(c)
		if c.skill and c.skill.counter and c.st.phase == "reflectStance" then
			BossMechanics.endReflect(c.model)
		end
		kit.send(c.st, "reflectEnd", {})
	end,
}

-- BR1-3 아르마딜로 반격 가시: 때린 사람의 **그 순간 자리**에 counter.delaySeconds 뒤 떨어진다(바닥 원 = 판정). 스킬이 끝나도 떨어진다(stepSpikes - 투사체처럼 따로 돈다).
function BossHandlersBR1.throwSpike(model, st, data, skill, player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local counter = skill.counter
	local at = Vector3.new(root.Position.X, st.floorY, root.Position.Z)
	local now = os.clock()
	st.spikes = st.spikes or {}
	table.insert(st.spikes, { position = at, landAt = now + counter.delaySeconds, radius = counter.radiusStuds, multiplier = counter.multiplier, label = skill.damageLabel, data = data })
	local bossAt = model:GetPivot().Position
	kit.send(st, "spikeMark", { from = bossAt, position = at, radius = counter.radiusStuds, seconds = counter.delaySeconds, color = data.headColor })
	kit.debugEvent("spikeMark", { player = player, at = now, position = at })
	print(("[forge-game] 아르마딜로 반격 가시: %s 자리로 %.1f초 뒤"):format(tostring(player.Name), counter.delaySeconds))
end

function BossHandlersBR1.stepSpikes(model, st, now)
	local list = st.spikes
	if not list or #list == 0 then
		return
	end
	for i = #list, 1, -1 do
		local spike = list[i]
		if now >= spike.landAt then
			table.remove(list, i)
			local c = { model = model, st = st, data = spike.data, now = now }
			kit.judgeBegin()
			for _, v in ipairs(kit.victims(st)) do
				if Reach.horizontalDistance(v.root.Position, spike.position) <= spike.radius and Reach.sameLayer(v.groundFeet, spike.position) then
					kit.applySkillDamage(model, spike.data, { damage = { kind = "attack", multiplier = spike.multiplier }, damageLabel = spike.label }, v.player)
					kit.debugEvent("spikeHit", { player = v.player, at = now })
				end
			end
			kit.judgeEnd(c, { kind = "circle", centers = { spike.position }, radius = spike.radius, inner = 0 })
			kit.send(st, "spikeImpact", { position = spike.position, radius = spike.radius })
		end
	end
end

-- AttackServer(원거리 평타가 닿는 순간)가 부른다. 반사 중이면 true(피해 0) - 쏜 사람 1인당 windowSeconds에 한 발만 되돌린다(나머지는 흡수).
function BossHandlersBR1.tryReflect(model, shooter)
	local st = MonsterState.getBossPatternState(model)
	if not (st and st.phase == "reflectStance" and st.skill and st.skill.primitive == "reflect" and not st.skill.counter and st.context) then -- BR1-3 아르마딜로는 반사 대신 가시(피해 0 · 귀)
		return false
	end
	local skill = st.skill
	local now = os.clock()
	local last = st.reflectBy[shooter]
	if last and now - last < skill.windowSeconds then
		return true
	end
	st.reflectBy[shooter] = now
	local shooterRoot = shooter.Character and shooter.Character:FindFirstChild("HumanoidRootPart")
	if not shooterRoot then
		return true
	end
	local c = st.context
	local bossAt = model:GetPivot().Position
	local from = Vector3.new(bossAt.X, st.floorY + 3, bossAt.Z)
	local flat = Vector3.new(shooterRoot.Position.X - from.X, 0, shooterRoot.Position.Z - from.Z)
	local dir = flat.Magnitude > 1e-3 and flat.Unit or Vector3.new(1, 0, 0)
	local spec = skill.projectile
	nextProjectileId += 1
	local projectile = {
		id = nextProjectileId, position = from, dir = dir, speed = spec.speedStuds, turnRad = 0, radius = spec.radiusStuds,
		expiresAt = now + spec.windupSeconds + (flat.Magnitude + 40) / spec.speedStuds, holdUntil = now + spec.windupSeconds,
		heightMode = "air", pierce = false, hitBy = {}, bouncesLeft = 0, model = model, data = c.data,
		skill = { damage = { kind = "maxHpRaw", fraction = spec.maxHpFraction }, damageLabel = skill.damageLabel, projectileStyle = "reflected" },
		owner = { kind = "reflected", player = shooter }, reflectable = true, reflections = 1, -- K 성기사 패링 대비
	}
	st.projectiles = st.projectiles or {}
	table.insert(st.projectiles, projectile)
	kit.send(st, "reflectShot", { from = from, to = from + dir * math.min(flat.Magnitude + 40, 200), windup = spec.windupSeconds, shooterUserId = shooter.UserId, color = c.data.headColor })
	kit.debugEvent("reflectShot", { shooter = shooter, at = now })
	print(("[forge-game] 투사체 반사: %s의 원거리 공격을 되돌린다"):format(tostring(shooter.Name)))
	return true
end

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

-- ─────────────────────────── sweep(BR1-3 에네르기파 휩쓸기) ───────────────────────────
-- 기 모으기(전조 - 보스 앞 빛이 커진다 · 머리 위 회전 화살표) → 빔이 보스 둘레 sweepDeg를 sweepSeconds 동안 돈다. 판정 = 빔이 지나간 각(지난 틱 ~ 이번 틱)에 든 사람 ·
-- 반경 radiusStuds 안 · 발 기준 같은 층 - 한 사람 한 번. 휩쓰는 범위 = 대상 방향이 한가운데인 반원(바닥에 보이는 반원 = 판정 - 빔 굵기는 그림).
BossHandlersBR1.sweep = {
	bubbleSeconds = function(c)
		return c.skill.telegraphSeconds + c.skill.sweepSeconds
	end,
	start = function(c)
		local st, skill = c.st, c.skill
		st.phase = "sweepCharge"
		st.phaseEndsAt = c.now + skill.telegraphSeconds
		st.sweepCenterDeg = angleToTarget(c)
		st.sweepDir = kit.rng:NextNumber() < 0.5 and 1 or -1
		st.sweepOrigin = kit.xz(c.position)
		st.sweepHit = {}
		local startDeg = BossSkillMath.sweepAngleAt(skill, st.sweepCenterDeg, st.sweepDir, 0)
		kit.send(st, "sweepTelegraph", {
			center = Vector3.new(st.sweepOrigin.X, st.floorY, st.sweepOrigin.Z), angleDeg = st.sweepCenterDeg, startDeg = startDeg, widthDeg = skill.sweepDeg,
			radius = skill.radiusStuds, halfWidth = skill.halfWidthStuds, dirSign = st.sweepDir, seconds = skill.telegraphSeconds, sweepSeconds = skill.sweepSeconds,
			bossId = c.data.id, color = c.data.headColor,
		})
	end,
	step = function(c)
		local st, skill = c.st, c.skill
		if st.phase == "sweepCharge" then
			if c.now < st.phaseEndsAt then
				return
			end
			st.phase = "sweepFire"
			st.sweepStartedAt = c.now
			st.sweepPrevOffset = 0
			kit.send(st, "sweepFire", { seconds = skill.sweepSeconds })
		end
		local t = c.now - st.sweepStartedAt
		local f = math.clamp(t / skill.sweepSeconds, 0, 1)
		local offset = skill.sweepDeg * f
		local startDeg = BossSkillMath.sweepAngleAt(skill, st.sweepCenterDeg, st.sweepDir, 0)
		local floor = Vector3.new(0, st.floorY, 0)
		kit.judgeBegin()
		for _, v in ipairs(kit.victims(st)) do
			if not st.sweepHit[v.player] then
				local rel = kit.xz(v.root.Position) - st.sweepOrigin
				local d = rel.Magnitude
				local o = ((math.deg(math.atan2(rel.Z, rel.X)) - startDeg) * st.sweepDir) % 360
				if d <= skill.radiusStuds and (d < 1e-3 or (o >= st.sweepPrevOffset - 1e-6 and o <= offset + 1e-6)) and Reach.sameLayer(v.groundFeet, floor) then
					st.sweepHit[v.player] = true
					kit.applySkillDamage(c.model, c.data, skill, v.player)
				end
			end
		end
		kit.judgeEnd(c, { kind = "sector", origin = Vector3.new(st.sweepOrigin.X, st.floorY, st.sweepOrigin.Z), angleDeg = st.sweepCenterDeg, widthDeg = skill.sweepDeg, radius = skill.radiusStuds, inner = 0 })
		st.sweepPrevOffset = offset
		if f >= 1 then
			kit.send(st, "sweepEnd", {})
			kit.endSkill(c.model, st, c.data, c.now)
		end
	end,
	interrupt = function(c)
		kit.send(c.st, "sweepEnd", {})
	end,
}

-- ─────────────────────────── boomerang(BR1-3 분신 돌격) ───────────────────────────
-- 분신 directions개가 대상 쪽 부채(가운데 = 대상 · ±stepDeg)로 벽(arenaMarginStuds 안쪽)까지 → turnSeconds → 같은 길로 돌아와 보스에 흡수(패턴 끝).
-- 판정 = 분신 몸(반폭 halfWidthStuds + 몸통)에 닿은 사람 · 길마다 · 가는 길 / 오는 길 따로 1번. 사람을 통과한다(분신은 멈추지 않는다).
BossHandlersBR1.boomerang = {
	bubbleSeconds = function(c)
		return c.skill.telegraphSeconds
	end,
	start = function(c)
		local st, skill = c.st, c.skill
		local zone = kit.zoneOf(c.model)
		local origin = kit.xz(c.position)
		local spread = skill.centered and skill.stepDeg * ((skill.directions or 1) - 1) / 2 or 0
		local base = angleToTarget(c) - spread
		local lines, payload = {}, {}
		for k = 0, (skill.directions or 1) - 1 do
			local deg = base + skill.stepDeg * k
			local a = math.rad(deg)
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local length = kit.clipToZone(origin, dir, zone, skill.arenaMarginStuds or 4)
			table.insert(lines, { dir = dir, length = length, hit = { out = {}, back = {} } })
			table.insert(payload, { angleDeg = deg, length = length })
		end
		st.boomOrigin = origin
		st.boomLines = lines
		st.phase = "boomTelegraph"
		st.phaseEndsAt = c.now + skill.telegraphSeconds
		kit.send(st, "boomTelegraph", {
			center = Vector3.new(origin.X, st.floorY, origin.Z), lines = payload, halfWidth = skill.halfWidthStuds, seconds = skill.telegraphSeconds,
			outSpeed = skill.outSpeedStuds, backSpeed = skill.backSpeedStuds, turnSeconds = skill.turnSeconds, bossId = c.data.id, color = c.data.headColor,
		})
	end,
	step = function(c)
		local st, skill = c.st, c.skill
		if st.phase == "boomTelegraph" then
			if c.now < st.phaseEndsAt then
				return
			end
			st.phase = "boomRun"
			st.boomStartedAt = c.now
			kit.send(st, "boomRun", {})
		end
		local t = c.now - st.boomStartedAt
		local half = BossData.mechanics.dodge.characterHalfWidthStuds
		local floor = Vector3.new(0, st.floorY, 0)
		local running = false
		local targets = kit.victims(st)
		for _, line in ipairs(st.boomLines) do
			local distance, leg = BossSkillMath.boomerangAt(skill, line.length, t)
			if distance then
				running = true
				local at = st.boomOrigin + line.dir * distance
				local hitSet = leg == "back" and line.hit.back or line.hit.out
				for _, v in ipairs(targets) do
					if not hitSet[v.player] and (kit.xz(v.root.Position) - at).Magnitude <= skill.halfWidthStuds + half and Reach.sameLayer(v.groundFeet, floor) then
						hitSet[v.player] = true
						kit.judgeBegin()
						kit.applySkillDamage(c.model, c.data, skill, v.player)
						kit.judgeEnd(c, { kind = "circle", centers = { Vector3.new(at.X, st.floorY, at.Z) }, radius = skill.halfWidthStuds, inner = 0 })
						kit.debugEvent("boomerangHit", { player = v.player, leg = leg, at = c.now })
					end
				end
			end
		end
		if not running then
			kit.send(st, "boomEnd", { center = Vector3.new(st.boomOrigin.X, st.floorY, st.boomOrigin.Z) })
			kit.endSkill(c.model, st, c.data, c.now)
		end
	end,
	interrupt = function(c)
		kit.send(c.st, "boomEnd", {})
	end,
}

function BossHandlersBR1.register(handlers, patternKit)
	kit = patternKit
	kit.airSecondsOf = BossHandlersBR1.airSecondsOf
	handlers.sector = BossHandlersBR1.sector
	handlers.projectile = BossHandlersBR1.projectile
	handlers.vortex = BossHandlersBR1.vortex
	handlers.reflect = BossHandlersBR1.reflect
	handlers.sweep = BossHandlersBR1.sweep -- BR1-3
	handlers.boomerang = BossHandlersBR1.boomerang -- BR1-3
end

return BossHandlersBR1
