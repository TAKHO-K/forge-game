-- BR1 새 조각 핸들러(docs/design/boss-br1.md §0) - BossPatterns의 HANDLERS 표에 primitive 이름으로 꽂는다(보스 이름이 들어간 함수는 없다).
--   sector     보스 중심 부채꼴 · 반원 · 반면(angleDeg · radiusStuds · innerRadiusStuds · facing = "target" / "randomSide", jumpable, volleyShots)
--   projectile 투사체(count · speedStuds · turnRateDeg · radiusStuds · lifetimeSeconds · targetRule · heightMode "air"/"ground" · pierce · onHit)
--              쏜 뒤에는 스킬과 떨어져 난다(st.projectiles - BossPatterns.step이 매 틱 stepProjectiles를 부른다) - 보스는 다음 스킬을 고를 수 있다.
--   vortex     소용돌이(끌림 telegraphSeconds 동안 · 클라가 자기 캐릭터를 당긴다 - 걷기보다 느리게) → 중심 폭발 원
-- 판정은 전부 여기(서버), 그림은 클라(BossBR1View) - 보이는 장판 = 실제 판정. kit = BossPatterns가 넘기는 공용 함수 표(victims · send · …).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossSkillMath = require(ReplicatedStorage.Shared.BossSkillMath)
local BossCurveData = require(ReplicatedStorage.Shared.data.BossCurveData)
local Reach = require(ReplicatedStorage.Shared.Reach)
local BossTrap = require(script.Parent.BossTrap)
local PlayerState = require(script.Parent.PlayerState)
local DashWindow = require(script.Parent.DashWindow) -- FINAL-1 3: 대시 통과 판정 한 곳
local MonsterState = require(script.Parent.MonsterState)
local PlayerDamage = require(script.Parent.PlayerDamage)
local HeightGuard = require(script.Parent.HeightGuard)
local AirState = require(script.Parent.AirState) -- 파트 0: 원거리 공중 정지 = 체공
local BossMechanics = require(script.Parent.BossMechanics) -- BR1-3 아르마딜로 태세(반사의 귀)
local PlayerStun = require(script.Parent.PlayerStun) -- BR1-4c c-11 눈덩이에서 튀어나온 뒤 기절
local BossArenaMap = require(script.Parent.BossArenaMap) -- BR1-4c c-11 배출 자리(구조물 밖)
local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)
local BossOrigin = require(ReplicatedStorage.Shared.BossOrigin) -- BOSS-NIGHT-3 1-④ 부위마다 발생 지점 · 1-⑤ 빔 홀

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
	local so = kit.originOf(c) -- BOSS-NIGHT-2 3: 땅 가르기 · 발 구르기 = 내려친 부위 아래에서(표에 없는 휘두르기는 몸 중심)
	st.sectorOrigin = so and kit.xz(so) or kit.xz(c.position)
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
		noFloor = skill.noFloor, -- GUARDIAN-V3: 바닥 전조 없음(판정 그대로)
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
		local first = firstSectorAngle(c)
		if c.skill.facing == "randomSide" and typeof(c.model) == "Instance" then
			-- BOSS-NIGHT-3 1-③ 수호자 대지 가르기: 무작위 방향(대상 선의 왼쪽/오른쪽 반원)으로 보이는 몸을 먼저 돌려 그 쪽을 내려친다
			--   (옛 = 몸은 대상을 봐 끌어내리는 손이 부채 반대쪽 = "몸 중심 예외") · 판정 · 서버 루트 그대로 · 스킬 끝에 풀림(BossPatterns.endSkill)
			local r = math.rad(first)
			c.model:SetAttribute("BossAimLockYaw", math.atan2(-math.cos(r), -math.sin(r)))
		end
		beginSectorVolley(c, first)
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
			radius = st.sectorRadius, innerRadius = skill.innerRadiusStuds, bossId = c.data.id, motion = skill.motion, noFloor = skill.noFloor,
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
	if rule == "missileTarget" then -- BOSS-NIGHT-2 3 수정 여왕 마법 미사일: preferBeyondStuds 밖 우선(그중 가장 먼) · 같은 사람 연속 금지(다른 대상이 있으면) · 없으면 가장 가까운
		local last = c.st.lastMissileTarget
		local function pick(list, farthest)
			local best, bestD = nil, nil
			for _, v in ipairs(list) do
				local d = Reach.horizontalDistance(v.root.Position, c.position)
				if not bestD or (farthest and d > bestD) or (not farthest and d < bestD) then
					best, bestD = v, d
				end
			end
			return best
		end
		local far, farOthers, others = {}, {}, {}
		for _, v in ipairs(all) do
			local beyond = Reach.horizontalDistance(v.root.Position, c.position) > (c.skill.preferBeyondStuds or 12)
			if beyond then
				table.insert(far, v)
				if v.player ~= last then
					table.insert(farOthers, v)
				end
			end
			if v.player ~= last then
				table.insert(others, v)
			end
		end
		local chosen = pick(farOthers, true) or (#others == 0 and pick(far, true)) or pick(others, false) or pick(all, false)
		c.st.lastMissileTarget = chosen and chosen.player or nil
		return chosen and { chosen } or {}
	end
	if rule == "farthestBeyond" then -- BOSS-NIGHT-2 3 수정 여왕 마법 미사일: beyondStuds 밖 멤버 중 가장 먼 한 명
		local best, bestD = nil, c.skill.beyondStuds or 18
		for _, v in ipairs(all) do
			local d = Reach.horizontalDistance(v.root.Position, c.position)
			if d > bestD then
				best, bestD = v, d
			end
		end
		return best and { best } or {}
	end
	if rule == "beyond" then -- BOSS-NIGHT-2 폭풍 전류 구슬: 보스에게서 beyondStuds 밖 멤버 전원(가까운 순 · 최대 maxTargets)
		local far = {}
		for _, v in ipairs(all) do
			local d = Reach.horizontalDistance(v.root.Position, c.position)
			if d > (c.skill.beyondStuds or 30) then
				table.insert(far, { v = v, d = d })
			end
		end
		table.sort(far, function(x, y)
			return x.d < y.d
		end)
		local out = {}
		for i = 1, math.min(#far, c.skill.maxTargets or 4) do
			out[i] = far[i].v
		end
		return out
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
		at += velocity * t * (skill.leadFraction or 1) -- GUARDIAN-V3: 리드 조준 비율(바나나 50%)
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
	local po = st.projOrigin
	if st.projOriginSides and #st.projOriginSides > 0 then
		po = st.projOriginSides[(index - 1) % #st.projOriginSides + 1] or po
	end
	local origin = po and kit.xz(po) or kit.xz(c.position)
	local y = skill.heightMode == "ground" and (st.floorY + skill.radiusStuds * 0.6) or (po and po.Y or (st.floorY + (skill.launchHeightStuds or 9)))
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
		radius = skill.radiusStuds, expiresAt = c.now + (skill.lifetimeSeconds or 6), target = target.player, bornAt = c.now, origin = position,
		heightMode = skill.heightMode or "air", pierce = skill.pierce == true, hitBy = {}, skill = skill, data = c.data, model = c.model,
		bouncesLeft = skill.bounces or 0,
		-- BR1-2 반사 대비(K 성기사 패링 · 반사 대결): 소유자 · 반사 가능 · 반사 횟수
		owner = { kind = "boss", model = c.model }, reflectable = skill.reflectable ~= false, reflections = 0,
		throw = st.projThrow, -- GUARDIAN-V3: 한 번 던진 묶음(부채 3갈래 포함) - 묶음 전부가 대상을 못 맞히면 빗나감(onMiss)
		volley = skill.lockOnFirstHit and st.projVolley or nil, -- BOSS-NIGHT-2 3: 같은 묶음 - 한 발이 대상에 맞으면 나머지 고정 추적
		index = index, -- BOSS-NIGHT-2 3: 몇 번째 발(skill.lastOnHit = 마지막 발에만)
	}
	if st.projThrow then
		st.projThrow.left += 1
	end
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
		st.projThrow = skill.onMiss and { left = 0, hit = false, skill = skill, data = c.data } or nil
		st.projOrigin = kit.originOf(c) -- BOSS-NIGHT-2 3: 쏘는 부위(손 · 지팡이 · 홀 끝 · 입 · 꼬리 끝)에서 - 표에 없으면 보스 중심
		-- BOSS-NIGHT-3 1-④: 표에 부위마다(sides) 자리가 있으면 발 번호대로 번갈아(매머드 상아 쏘기 = 1발 왼 · 2발 오른 상아 - 옛 = 두 상아 가운데 하나에서 2.9 어긋남)
		st.projOriginSides = nil
		local entry = BossOrigin.entry(c.model:GetAttribute("BossRigKey"), c.st.current)
		if entry and entry.sides then
			st.projOriginSides = {}
			for i = 1, #entry.sides do
				st.projOriginSides[i] = kit.originOf(c, nil, i)
			end
		end
		st.projVolley = skill.lockOnFirstHit and { locked = false } or nil
		local userIds = {}
		for _, v in ipairs(st.projTargets) do
			table.insert(userIds, typeof(v.player) == "Instance" and v.player.UserId or 0)
		end
		local po = st.projOrigin -- BOSS-NIGHT-2 3: 예고 구체도 실제 발사점 위(예고 = 판정 = 이펙트)
		kit.send(st, "projTelegraph", {
			center = Vector3.new((po or c.position).X, st.floorY, (po or c.position).Z), seconds = skill.telegraphSeconds, count = skill.count or 1,
			style = skill.projectileStyle, heightMode = skill.heightMode or "air", targetUserIds = userIds, bossId = c.data.id, motion = skill.motion,
			launchHeight = po and math.max(po.Y - st.floorY, 0.5) or skill.launchHeightStuds or 9,
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

-- ─────────────────────────── BR1-4c c-11 눈덩이 파묻힘(skill.engulf) ───────────────────────────
-- 맞은 사람은 잡힘(BossTrap kind "snowball" - 구출 없음 · 면역)으로 눈덩이 중심 위에 고정된다(서버 = 판정 자리 · 클라가 겉에 반쯤 파묻힌 모습 · 구르기를 그린다).
-- 서버가 옮기는 동안은 높이 검사 예외(HeightGuard.exempt - 되돌림 0). 대공 잡기는 잡힌 사람(가둠 제외)을 얼리지도 체공으로 세지도 않는다 = 땅을 구르는 중은 지면 취급.
local function riderRoot(player)
	local character = typeof(player) == "Instance" and player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function setRiderAttributes(player, id, phase)
	if typeof(player) == "Instance" and player.Parent then
		player:SetAttribute("BossSnowballId", id)
		player:SetAttribute("BossSnowballPhase", phase)
	end
end

local placeSafe -- 아래(ejectPoint 뒤)에서 정의

local function sendRiders(st, p)
	local e = p.skill.engulf
	kit.send(st, "projRiders", { id = p.id, scale = math.min(1 + e.growPerRider * #p.riders, e.maxGrow) })
end

local function engulf(model, st, p, v, now)
	local e = p.skill.engulf
	if (PlayerState.getHp(v.player) or 0) <= 0 or BossTrap.isTrapped(v.player) then
		return
	end
	if not BossTrap.trap(v.player, { kind = "snowball", autoReleaseSeconds = e.maxSeconds + 1, context = { bossModel = model, snowballId = p.id },
		onAutoRelease = function(player) -- 리뷰 2: 투사체 틱이 멈춰(보스 복귀 등) 안전장치로 풀릴 때도 안전한 자리로 옮기고 속성 · 예외를 정리한다
			placeSafe(model, st, p, player)
		end,
	}) then
		return
	end
	p.riders = p.riders or {}
	local phase = #p.riders * 2.1
	table.insert(p.riders, { player = v.player, untilAt = now + e.maxSeconds, phase = phase })
	HeightGuard.exempt(v.player, e.maxSeconds + 1)
	setRiderAttributes(v.player, p.id, phase)
	sendRiders(st, p)
	kit.debugEvent("snowballEngulf", { player = v.player, id = p.id, at = now })
end

-- 튀어나올 자리: 눈덩이 자리(지면) - 구조물과 겹치면 아레나 가운데 쪽으로 옮겨 가며 찾는다(벽 안 · 구조물 안 X). 무너진 조각 위면 기존 낙하 규칙(전멸기 + 복귀)이 받는다.
local function ejectPoint(model, st, p)
	local zone = kit.zoneOf(model)
	local zoneKey = MonsterState.getZoneKey(model)
	local clearance = p.skill.engulf.ejectClearanceStuds
	local half = BossData.mechanics.dodge.characterHalfWidthStuds
	local center = Vector3.new(zone.center.X, st.floorY, zone.center.Z)
	local at = Vector3.new(p.position.X, st.floorY, p.position.Z)
	local toCenter = center - at
	local limit = (zone.radius or 140) - half - clearance
	if toCenter.Magnitude > 1e-3 and (at - center).Magnitude > limit then
		at = center - toCenter.Unit * limit
	end
	for _ = 1, 24 do
		if not (zoneKey and BossArenaMap.overlapsObstacle(zoneKey, at, half, clearance)) then
			break
		end
		toCenter = center - at
		if toCenter.Magnitude < 2 then
			break
		end
		at += toCenter.Unit * 2
	end
	return at + Vector3.new(0, MovementConfig.rootAboveFeetStuds, 0)
end

-- 안전한 자리로 옮기고 속성 · 높이 검사 예외를 정리한다(배출 · 안전장치 해제 · 처치 순간 공통). 반환: 옮긴 자리.
placeSafe = function(model, st, p, player)
	setRiderAttributes(player, nil, nil)
	p.hitBy[player] = true -- 리뷰 1: 튕김이 hitBy를 비운 틱에 튀어나와도 같은 눈덩이에 다시 안 맞는다
	local at = ejectPoint(model, st, p)
	local root = riderRoot(player)
	if root then
		root.CFrame = CFrame.new(at) * CFrame.Angles(0, math.atan2(-p.dir.X, -p.dir.Z), 0)
		HeightGuard.reset(player)
		HeightGuard.endExempt(player) -- 리뷰 3
	elseif type(player) == "table" and player.root then
		player.root.Position = at
	end
	return at
end

local function eject(model, st, p, rider, why)
	local player = rider.player
	if not BossTrap.isTrapped(player) or (BossTrap.getRecord(player).kind ~= "snowball") then
		setRiderAttributes(player, nil, nil)
		return -- 이미 다른 길(리셋 · 퇴장 · 안전장치)로 풀렸다
	end
	local at = placeSafe(model, st, p, player)
	BossTrap.release(player, "snowball")
	local seconds = p.skill.engulf.stunSeconds
	if PlayerStun.stun(player, seconds, true) then
		kit.send(st, "playerStun", { userId = typeof(player) == "Instance" and player.UserId or nil, seconds = seconds, style = "snow" })
	end
	kit.debugEvent("snowballEject", { player = player, id = p.id, at = os.clock(), why = why, position = at })
end

local function stepRiders(model, st, p, now, bounced, finished)
	if not p.riders or #p.riders == 0 then
		return
	end
	local keep = {}
	for _, rider in ipairs(p.riders) do
		local record = BossTrap.getRecord(rider.player)
		if not record or record.kind ~= "snowball" then
			setRiderAttributes(rider.player, nil, nil) -- 다른 길로 풀렸다
		elseif finished or bounced or now >= rider.untilAt then
			eject(model, st, p, rider, finished and "end" or (bounced and "wall" or "time"))
		else
			local root = riderRoot(rider.player)
			if root then
				root.CFrame = CFrame.new(p.position + Vector3.new(0, p.radius * 0.5, 0)) * root.CFrame.Rotation
			end
			table.insert(keep, rider)
		end
	end
	if #keep ~= #p.riders then
		p.riders = keep
		sendRiders(st, p)
	end
end

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
		local bounced = false
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
			-- BR1-4c c-3: 따라가는 시간은 homingSeconds까지(날기 시작부터 - 반사로 모으던 시간 제외) · 목표 자리는 retargetSeconds마다 대상의 지금 자리로 갱신
			local homing = BossData.mechanics.homing
			local flying = now - (p.holdUntil or p.bornAt or now)
			local locked = p.volley and p.volley.locked -- BOSS-NIGHT-2 3: 묶음 첫 명중 뒤 = 빠른 회전 · 유도 시간 무제한 · 매 틱 지금 자리
			local turnRad = locked and math.rad(p.skill.lockOnFirstHit.turnRateDeg) or p.turnRad -- 고정이 풀리면(대시로 한 발 소멸) 원래 회전으로
			if locked then
				p.retargetAt = 0
			end
			if target and turnRad > 0 and (locked or flying <= (p.skill.homingSeconds or homing.homingSeconds)) then -- BOSS-NIGHT-2: 스킬별 유도 시간(전류 구슬 2.5초)
				if not p.aimAt or now >= (p.retargetAt or 0) then
					p.aimAt = target.root.Position
					p.retargetAt = now + homing.retargetSeconds
				end
				local desired = p.aimAt - p.position
				if p.heightMode == "ground" then
					desired = Vector3.new(desired.X, 0, desired.Z)
				end
				if desired.Magnitude > 1e-3 then
					desired = desired.Unit
					local angle = math.acos(math.clamp(p.dir:Dot(desired), -1, 1))
					local maxTurn = turnRad * dt
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
					bounced = true
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
				-- BOSS-NIGHT-2 3: skill.passThrough = 무적 · 대시 중에는 통과(맞지 않고 소모 · 고정 추적도 안 걸림 - 피할 수 없는 피해 금지)
				local passing = p.skill.passThrough and (PlayerState.isInvulnerable(v.player) or (p.skill.passThrough == DashWindow.sourceKey and DashWindow.isActive(v.player)) or PlayerState.hasIncomingSource(v.player, p.skill.passThrough))
				-- 대시 · 무적 중에 닿은 발 = 그 자리에서 소멸(피해 없음) + 묶음 고정 추적 풀림(Studio 시험: 통과만 하면 그 발이 계속 쫓아와 대시가 끝난 뒤 맞았다 = 대시가 쓸모없음)
				if passing and not p.hitBy[v.player] and not BossTrap.isTrapped(v.player) and (v.root.Position - p.position).Magnitude <= p.radius + half + 0.5 then
					if p.volley then
						p.volley.locked = false
					end
					done = true
					if RunService:IsStudio() then
						print(("[BossMissile] 무적으로 무시됨(대시 · 무적 중 - 소멸 · 고정 추적 풀림): %s · %d번째 발"):format(tostring(v.player), p.index or 0)) -- Studio 검증용
					end
					break
				end
				if not passing and not p.hitBy[v.player] and not BossTrap.isTrapped(v.player) then
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
						if p.volley and v.player == p.target then
							p.volley.locked = true -- BOSS-NIGHT-2 3: 첫 명중 → 같은 묶음 나머지 고정 추적
						end
						local c = { model = model, st = st, data = data, skill = p.skill, now = now, position = p.position }
						kit.judgeBegin()
						if p.skill.damage.kind == "maxHpRaw" then -- BR1-2 반사된 투사체: 한 방에 죽을 수 있는 큰 피해(감소 · 1 ~ 30 보호 적용)
							PlayerDamage.applyMaxHpFraction(v.player, p.skill.damage.fraction, p.skill.damageLabel)
							BossTrap.noteSkillHit(v.player)
						elseif p.skill.distanceDamage and p.origin then -- BOSS-NIGHT-2 검기: 피해 = 기본 × (1 + perMax × 비행 거리 ÷ maxStuds)(최대 × (1 + perMax))
							local dd = p.skill.distanceDamage
							local flown = Vector3.new(p.position.X - p.origin.X, 0, p.position.Z - p.origin.Z).Magnitude
							damageWith(c, p.skill.damage.multiplier * (1 + dd.perMax * math.min(flown / dd.maxStuds, 1)), v.player)
						else
							damageWith(c, nil, v.player)
						end
						kit.judgeEnd(c, { kind = "projectile", center = p.position, radius = p.radius })
						if p.skill.onHit then
							kit.runHitEffects(c, p.skill.onHit, v, p.position - Vector3.new(0, 0, 0), 1)
						end
						if p.skill.lastOnHit and p.index == (p.skill.count or 1) then -- BOSS-NIGHT-2 3: 마지막 발에만(약한 경직 - PlayerStun 면역 창이 이어짐을 막는다)
							kit.runHitEffects(c, p.skill.lastOnHit, v, p.position, 1)
						end
						if p.skill.trapOnHits then
							BossHandlersBR1.noteTrapHit(c, v, p.skill.trapOnHits)
						end
						if p.skill.engulf then
							engulf(model, st, p, v, now)
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
		stepRiders(model, st, p, now, bounced, done)
		if done and p.throw then
			local g = p.throw
			g.hit = g.hit or p.hitBy[p.target] == true -- 대상(조준한 사람)에게 맞았는가
			g.left -= 1
			if g.left <= 0 and not g.hit then
				kit.runEffects({ model = model, st = st, data = g.data, skill = g.skill, now = now, position = p.position }, g.skill.onMiss, {})
				kit.debugEvent("projectileMiss", { at = now, skill = g.skill.damageLabel })
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
		for _, p in ipairs(st.projectiles) do -- BR1-4c c-11: 눈덩이에 파묻힌 사람은 튀어나온다(처치 · 리셋 순간)
			for _, rider in ipairs(p.riders or {}) do
				local record = BossTrap.getRecord(rider.player)
				if record and record.kind == "snowball" then
					if st.model and st.floorY then
						placeSafe(st.model, st, p, rider.player) -- 리뷰 2: 제자리(구조물 안 · 구멍 위)에서 풀지 않는다
					else
						setRiderAttributes(rider.player, nil, nil)
					end
					BossTrap.release(rider.player, "snowball")
				else
					setRiderAttributes(rider.player, nil, nil)
				end
			end
		end
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
		airborne = airborne or AirState.isHovering(member, now) -- 파트 0: 원거리 공중 정지도 체공(서버 AirState 기록 - 클라 상태가 잠깐 바뀌어도 이어 센다)
		-- BR1-4a 4a-2: 강제 체공(넉백 · 발사 - 클라가 PlatformStand라 Jumping · Freefall이 아니다)도 체공 = 발사 허가가 살아 있고 발밑이 공중
		if not airborne and humanoid and typeof(member) == "Instance" and humanoid.FloorMaterial == Enum.Material.Air then
			local guard = HeightGuard.getState(member)
			airborne = guard ~= nil and guard.permit ~= nil and now <= guard.permit.expiresAt -- 설계 체공 안의 허가만(Play 1: 지난 허가가 남은 고정 루트를 체공으로 셌다)
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

-- ─────────────────────────── sweep(BR1-3 에네르기파 휩쓸기 → BR1-4a 낮은 빔 540°) ───────────────────────────
-- 기 모으기(전조 - 보스 앞 빛 · 회전 화살표 · 빔 시작선 · 빈틈이면 보스 곁 안전 원) → 낮은 빔(발 위 beamHeightStuds)이 innerStuds(빈틈 = gapInnerStuds) ~ 길이(아레나 반지름 ×
-- lengthArenaFraction × 2)를 sweepDeg(540°) 돈다. 판정 = 빔이 지난 각(지난 틱 ~ 이번 틱 · 반폭 + 몸통)에 든 사람 · 발이 빔 높이 이하 · 같은 층 · 면역 · 끌림 중 아님.
-- 걸리면 끌림(클라 - 보스 쪽 speedStuds · maxSeconds) + tickSeconds 도트(능력치 기반) → 풀림 + immuneSeconds 면역. 시전당 한 사람 총 피해 ≤ 최대 체력 × castMaxHpFraction.
-- 옛 반원 휩쓸기(beamHeightStuds 없는 스킬)는 없다 - 데이터가 새 규칙만 쓴다.
local function beamRelease(c, player, now)
	local st, skill = c.st, c.skill
	st.beamLocks[player] = nil
	st.beamImmune[player] = now + skill.pull.immuneSeconds
	kit.send(st, "beamRelease", { userId = typeof(player) == "Instance" and player.UserId or nil })
end

BossHandlersBR1.sweep = {
	bubbleSeconds = function(c)
		return c.skill.telegraphSeconds + c.skill.sweepSeconds
	end,
	start = function(c)
		local st, skill = c.st, c.skill
		local zone = kit.zoneOf(c.model)
		st.phase = "sweepCharge"
		st.phaseEndsAt = c.now + skill.telegraphSeconds
		st.sweepCenterDeg = angleToTarget(c)
		st.sweepDir = kit.rng:NextNumber() < 0.5 and 1 or -1
		st.sweepOrigin = kit.xz(c.position)
		st.sweepLength = (zone.radius or skill.radiusStuds) * 2 * skill.lengthArenaFraction
		st.sweepGap = kit.rng:NextNumber() < skill.gapChance
		st.sweepInner = st.sweepGap and skill.gapInnerStuds or skill.innerStuds
		st.beamLocks, st.beamImmune, st.beamDealt = {}, {}, {}
		local startDeg = BossSkillMath.sweepAngleAt(skill, st.sweepCenterDeg, st.sweepDir, 0)
		-- BOSS-NIGHT-3 1-⑤ 수정 여왕 에네르기파 = 홀 보석에서(옛 = 몸 중심): 발생 지점 표(ScepterGem)의 수평 자리를 빔 방향 기준 옆(lat) · 앞(fwd)으로 나눠 둔다 →
		--   빔 = 중심에서 옆으로 lat만큼 비킨 평행선이 fwd부터 · 보이는 몸은 빔 각도를 따라 돈다(BossAimLockYaw · 클라 그림 = 같은 lat · fwd)
		st.sweepLat, st.sweepFwd, st.beamBottom, st.beamTop = 0, 0, nil, nil
		local gem = BossOrigin.point(c.model:GetAttribute("BossRigKey"), c.data.sizeScale, MonsterState.getHpRatio(c.model), c.st.current,
			c.position, c.position + Vector3.new(math.cos(math.rad(startDeg)), 0, math.sin(math.rad(startDeg))), st.floorY)
		if gem then
			local rel = kit.xz(gem) - st.sweepOrigin
			local u = Vector3.new(math.cos(math.rad(startDeg)), 0, math.sin(math.rad(startDeg)))
			local n = Vector3.new(-u.Z, 0, u.X)
			st.sweepLat, st.sweepFwd = rel:Dot(n), math.max(rel:Dot(u), 0)
			local lift = skill.beamFromOrigin
			if lift then -- 1-⑤f 레이저 = 홀 보석 가운데 높이 ± 굵기/2(아래 끝 ≤ maxBottom) · 그림 · 판정 같은 값
				local h = gem.Y - st.floorY
				st.beamBottom = math.min(h - lift.thicknessStuds / 2, lift.maxBottomStuds)
				st.beamTop = h + lift.thicknessStuds / 2
			end
		end
		c.model:SetAttribute("BossAimLockYaw", math.atan2(-math.cos(math.rad(startDeg)), -math.sin(math.rad(startDeg))))
		kit.send(st, "sweepTelegraph", {
			center = Vector3.new(st.sweepOrigin.X, st.floorY, st.sweepOrigin.Z), angleDeg = st.sweepCenterDeg, startDeg = startDeg, sweepDeg = skill.sweepDeg, startLeadDeg = skill.startLeadDeg,
			length = st.sweepLength, inner = st.sweepInner, gap = st.sweepGap, halfWidth = skill.halfWidthStuds, beamHeight = skill.beamHeightStuds, lat = st.sweepLat, fwd = st.sweepFwd, beamBottom = st.beamBottom, beamTop = st.beamTop,
			dirSign = st.sweepDir, seconds = skill.telegraphSeconds, sweepSeconds = skill.sweepSeconds, bossId = c.data.id, color = c.data.headColor,
		})
		kit.debugEvent("sweepStart", { at = c.now, gap = st.sweepGap, inner = st.sweepInner, length = st.sweepLength, dir = st.sweepDir, startDeg = startDeg })
	end,
	step = function(c)
		local st, skill = c.st, c.skill
		if st.phase == "sweepCharge" then
			if c.now < st.phaseEndsAt then
				return
			end
			st.phase = "sweepFire"
			st.sweepStartedAt = c.now
			st.sweepPrevProgress = 0
			kit.send(st, "sweepFire", { seconds = skill.sweepSeconds })
		end
		local t = c.now - st.sweepStartedAt
		local f = math.clamp(t / skill.sweepSeconds, 0, 1)
		local progress = skill.sweepDeg * f -- 시작 각에서 돈 양(0 ~ 540)
		local startDeg = BossSkillMath.sweepAngleAt(skill, st.sweepCenterDeg, st.sweepDir, 0)
		local floor = Vector3.new(0, st.floorY, 0)
		local maxSeconds = skill.pull.maxSeconds
		if f < 1 and c.now >= (st.sweepYawAt or 0) and typeof(c.model) == "Instance" then -- 1-⑤ 보이는 몸 = 빔 각도(0.1초마다)
			st.sweepYawAt = c.now + 0.1
			-- 0.1초 앞선 각: 클라 몸 회전 부드럽게 하기(지수 계수 10 = 일정 회전에서 약 0.1초 늦음)를 메움(Studio 실측 - 회전 기울기를 끈 뒤: 0.07초 = 보석이 8.6° 늦음 · 1-⑤d 깊은 숙임 자세에서 0.13초 = 약 5° 앞섬)
			local a = math.rad(BossSkillMath.sweepAngleAt(skill, st.sweepCenterDeg, st.sweepDir, t + 0.1))
			c.model:SetAttribute("BossAimLockYaw", math.atan2(-math.cos(a), -math.sin(a)))
		end
		local lat = st.sweepLat or 0
		-- 새로 걸린 사람
		if f < 1 then
			for _, v in ipairs(kit.victims(st)) do
				local p = v.player
				if not st.beamLocks[p] and c.now >= (st.beamImmune[p] or 0) and not BossTrap.isTrapped(p) then
					local rel = kit.xz(v.root.Position) - st.sweepOrigin
					local r = rel.Magnitude
					local feetAbove = v.feet.Y - st.floorY
					-- 1-⑤: 옆으로 lat 비킨 평행 빔 - 빔 각 θ에서 이 사람에 닿는 조건 r·sin(φ − θ) = lat → θ = φ − asin(lat / r) · 빔 위 거리 s = √(r² − lat²) ≥ fwd
					local along = math.sqrt(math.max(r * r - lat * lat, 0))
					if r >= st.sweepInner - 0.5 and r > math.abs(lat) and along >= (st.sweepFwd or 0) - 0.5 and along <= st.sweepLength and (if st.beamTop then (feetAbove <= st.beamTop and feetAbove + skill.beamFromOrigin.bodyHeightStuds >= st.beamBottom) else feetAbove <= skill.beamHeightStuds) and Reach.sameLayer(v.groundFeet, floor) then -- 1-⑤f 몸이 레이저 띠와 겹침
						local half = math.deg(math.atan((skill.halfWidthStuds + 1) / math.max(along, 1)))
						local phi = math.deg(math.atan2(rel.Z, rel.X)) - math.deg(math.asin(math.clamp(lat / r, -1, 1)))
						local o0 = ((phi - startDeg) * st.sweepDir) % 360
						local hit = false
						for k = 0, math.ceil(skill.sweepDeg / 360) do
							local o = o0 + 360 * k
							if o >= st.sweepPrevProgress - half and o <= progress + half then
								hit = true
							end
						end
						if hit then
							st.beamLocks[p] = { untilAt = c.now + maxSeconds, nextTickAt = c.now, ticks = 0, maxTicks = math.floor(maxSeconds / skill.tickSeconds + 1e-6) + 1 } -- BR1-4b 리뷰 3: 틱을 개수로 센다(0 · 0.25 · … · 1.5 = 7회 - 부동소수점에 따라 6회로 빠지던 것)
							st.beamDealt[p] = st.beamDealt[p] or 0
							HeightGuard.grantBurst(p, skill.pull.speedStuds * maxSeconds + 4) -- 끌림(클라)만큼 수평 허가
							kit.send(st, "beamPull", { userId = typeof(p) == "Instance" and p.UserId or nil, toward = Vector3.new(st.sweepOrigin.X, st.floorY, st.sweepOrigin.Z), speed = skill.pull.speedStuds, seconds = maxSeconds })
							kit.debugEvent("beamHit", { player = p, at = c.now, r = r, feetAbove = feetAbove })
						end
					end
				end
			end
		end
		-- 걸린 사람: 도트(시전당 상한) · 끌림 끝 → 풀림 + 면역
		for p, lock in pairs(st.beamLocks) do
			if (PlayerState.getHp(p) or 0) <= 0 or (st.members and not table.find(st.members, p)) then -- QUEUE-ALL5 D②: 끌리는 중 보스전을 떠난 사람(파티 탈퇴 · [마을])은 도트를 그만 받는다
				st.beamLocks[p] = nil
			else
				while c.now >= lock.nextTickAt and lock.ticks < lock.maxTicks do
					local remaining = PlayerState.getMaxHp(p) * skill.castMaxHpFraction - st.beamDealt[p]
					if remaining > 0 then
						st.beamDealt[p] += PlayerDamage.applyHit(p, c.data.attack, skill.damageLabel, skill.damage.multiplier, { maxDamage = remaining })
						BossTrap.noteSkillHit(p)
					end
					lock.nextTickAt += skill.tickSeconds
					lock.ticks += 1
				end
				if c.now >= lock.untilAt or f >= 1 then
					beamRelease(c, p, c.now)
				end
			end
		end
		st.sweepPrevProgress = progress
		if f >= 1 and next(st.beamLocks) == nil then
			kit.send(st, "sweepEnd", {})
			kit.endSkill(c.model, st, c.data, c.now)
		end
	end,
	interrupt = function(c)
		for p in pairs(c.st.beamLocks or {}) do
			beamRelease(c, p, c.now)
		end
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
		local bo = kit.originOf(c) -- BOSS-NIGHT-2 3: 삼지창 던지기 = 삼지창 끝에서(분신 돌격 = 몸 - 표에 없음)
		local origin = bo and kit.xz(bo) or kit.xz(c.position)
		local spread = skill.centered and skill.stepDeg * ((skill.directions or 1) - 1) / 2 or 0
		local bases = { angleToTarget(c) - spread }
		if skill.perMember and not c.targetRoot then
			bases = {} -- 대상 없음 = 쓸모없는 0° 줄을 만들지 않는다(리뷰 2)
		end
		if skill.perMember then -- QUEUE-ALL1 01 D-2: 인당 조준 - 대상 말고도 안 잡힌 멤버마다 같은 모양을 그 사람 쪽으로
			for _, v in ipairs(kit.victims(st)) do
				local to = kit.xz(v.root.Position) - origin
				if v.root ~= c.targetRoot and not BossTrap.isTrapped(v.player) and to.Magnitude > 1e-3 then
					table.insert(bases, math.deg(math.atan2(to.Z, to.X)) - spread)
				end
			end
		end
		local lines, payload = {}, {}
		-- 맞음 기록 = 한 시전 전체가 같이 쓴다: 붙어 선 두 사람의 줄(인당 · 리뷰 2) · 분신 3줄(BOSS-NIGHT-3 1-① VERIFY-1 상-1 - 옛 = 줄마다 따로라 근접 유저가 3줄 × 가고 오며 최대 6타)이 겹쳐도
		--   1인 가는 길 1회 · 오는 길 1회
		local sharedHit = { out = {}, back = {} }
		for _, base in ipairs(bases) do
			for k = 0, (skill.directions or 1) - 1 do
				local deg = base + skill.stepDeg * k
				local a = math.rad(deg)
				local dir = Vector3.new(math.cos(a), 0, math.sin(a))
				local length = kit.clipToZone(origin, dir, zone, skill.arenaMarginStuds or 4)
				table.insert(lines, { dir = dir, length = length, hit = sharedHit })
				table.insert(payload, { angleDeg = deg, length = length })
			end
		end
		st.boomOrigin = origin
		st.boomLines = lines
		st.phase = "boomTelegraph"
		st.phaseEndsAt = c.now + skill.telegraphSeconds
		kit.send(st, "boomTelegraph", {
			center = Vector3.new(origin.X, st.floorY, origin.Z), lines = payload, halfWidth = skill.halfWidthStuds, seconds = skill.telegraphSeconds,
			outSpeed = skill.outSpeedStuds, backSpeed = skill.backSpeedStuds, turnSeconds = skill.turnSeconds, bossId = c.data.id, color = c.data.headColor, style = skill.projectileStyle,
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
