-- 보스 스킬 상태 머신(21-3 → 29-2 재편, PRD-forge-game-roblox.md 20.75). MonsterAI.server.lua가 매 Heartbeat마다
-- step()을 부르고, 반환값이 true(스킬 진행 중 - 보스 구속)면 추격·평타를 건너뛴다. 판정은 전부 서버가 한다 -
-- 클라는 어떤 상태도 보고하지 않고(점프 여부조차), BossPatternEvent로 받은 예고·연출만 그린다
-- (BossPatternVisuals.client.lua).
--
-- 29-2: 두 가지가 이 파일에서 빠져나갔다.
--   · "어느 스킬을 언제 시작하는가" → shared/BossScheduler.lua(쿨타임 + 우선순위 + 전역 쿨 + 굶주림 + 연속 금지 +
--     자리 비우기). 모형(BossSim)과 같은 함수를 쓴다. 이 파일은 시계(os.clock)와 발동 조건의 실제 값을 댈 뿐이다.
--   · "스킬 하나가 어떻게 도는가" → 아래 HANDLERS 표. 키는 스킬의 primitive(circleBoss·ring·circleTarget·charge·
--     line·gimmick)이고 보스 이름이 들어간 함수는 없다(CLAUDE.md "조각 조합으로 정의한다"). 같은 핸들러가
--     파라미터만 달리 받아 6종의 스킬을 전부 처리한다 - 기본형 강공격과 서리 거인의 빙결 강타, 심해 군주의
--     도넛 휩쓸기, 수정 여왕의 2연속 펄스가 전부 circleBoss다.
--
-- 상태는 MonsterState.getBossPatternState(model)이 돌려주는 테이블 하나에 산다 - 보스가 죽거나 물러나
-- MonsterState.clear가 불리면 같이 사라진다. 겹침 방지: phase가 "normal"일 때만 새 스킬을 고른다.
--
-- 22-4 높이 규칙(PRD 20.50 [2]): 모든 판정은 XZ 수평 + |ΔY| ≤ TerrainConfig.heightToleranceStuds. 파동·원·직선은
-- "그 스킬의 지면 Y"(보스 발밑 또는 낙하점 지면) 기준이라 8 넘게 높은 언덕 위에는 닿지 않는다. 돌진 이동은 매 틱
-- 지면 Y를 따르고, 경사 한계를 넘는 단차를 만나면 그 자리에서 끝난다(헤롱 시작).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local PlayerState = require(script.Parent.PlayerState)
local TerrainConfig = require(ReplicatedStorage.Shared.data.TerrainConfig)
local Reach = require(ReplicatedStorage.Shared.Reach)
local MonsterState = require(script.Parent.MonsterState)
local PlayerDamage = require(script.Parent.PlayerDamage)
local GroundProbe = require(script.Parent.GroundProbe)
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossScheduler = require(ReplicatedStorage.Shared.BossScheduler)
local BossSkillMath = require(ReplicatedStorage.Shared.BossSkillMath)
local BossMechanics = require(script.Parent.BossMechanics)

local BossPatterns = {}

-- 클라 연출 채널. 아레나 안 멤버 전원(st.members - 24-1 파티, 솔로면 그 한 명)에게 보낸다.
local patternEvent = Instance.new("RemoteEvent")
patternEvent.Name = "BossPatternEvent"
patternEvent.Parent = ReplicatedStorage

local scatterRng = Random.new()

local function xz(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function serverNow()
	return Workspace:GetServerTimeNow()
end

-- 보스가 속한 아레나 zone(WorldConfig.zones.bossArenaN). 없으면(DevTools로 사냥터에 띄운 경우 등) 스폰 지점
-- 중심의 같은 크기 정사각형으로 대신한다.
local function zoneOf(model)
	local zone = WorldConfig.zones[MonsterState.getZoneKey(model) or ""]
	if zone then
		return zone
	end
	return { center = xz(MonsterState.getSpawnPosition(model)), halfSize = WorldConfig.bossArena.halfSizeStuds }
end

-- origin에서 XZ 단위벡터 dir 방향으로 아레나 AABB(margin만큼 안쪽) 안에 머무는 최대 거리.
-- 돌진 도착점·직선 길이가 이걸로 잘려 담장 밖으로 절대 안 나간다.
local function clipToZone(origin, dir, zone, margin)
	local tMax = math.huge
	for _, axis in ipairs({ "X", "Z" }) do
		local d = dir[axis]
		if math.abs(d) > 1e-6 then
			local lo = zone.center[axis] - zone.halfSize + margin
			local hi = zone.center[axis] + zone.halfSize - margin
			local t = ((d > 0 and hi or lo) - origin[axis]) / d
			tMax = math.min(tMax, t)
		end
	end
	return math.max(tMax, 0)
end

local function clampToZone(position, zone, margin)
	return Vector3.new(
		math.clamp(position.X, zone.center.X - zone.halfSize + margin, zone.center.X + zone.halfSize - margin),
		position.Y,
		math.clamp(position.Z, zone.center.Z - zone.halfSize + margin, zone.center.Z + zone.halfSize - margin)
	)
end

-- 점 p에서 선분 a-b(XZ)까지의 거리.
local function distanceToSegment(p, a, b)
	local ab = b - a
	local len2 = ab:Dot(ab)
	if len2 < 1e-6 then
		return (p - a).Magnitude
	end
	local t = math.clamp((p - a):Dot(ab) / len2, 0, 1)
	return (p - (a + ab * t)).Magnitude
end

-- 공중 판정(ring). 21-3 실측(서버 시점): Humanoid 상태(Jumping/Freefall)는 점프 시작 순간 즉시 복제되지만
-- FloorMaterial은 약 0.2초 늦고 착지 상태는 아직 3~6stud 높이에서 먼저 바뀐다 - 그래서 "지면 거리"를 레이캐스트로
-- 직접 재는 것을 주 판정으로, 상태는 점프 시작 직후의 보조 판정으로만 쓴다.
local function isAirborne(character, clearanceStuds)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then
		return false
	end
	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
		return true
	end
	local standing = humanoid.HipHeight + rootPart.Size.Y / 2
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local hit = Workspace:Raycast(rootPart.Position, Vector3.new(0, -(standing + clearanceStuds + 2), 0), params)
	return hit == nil or hit.Distance > standing + clearanceStuds
end

local function floorYUnder(position)
	-- 22-4: 지면 폴더만 본다(GroundProbe) - 옛 무필터 Raycast는 보스 자기 몸통을 맞힐 수 있었다.
	return GroundProbe.surfaceY(position.X, position.Z, position.Y) or (position.Y - TerrainConfig.monsterFootOffsetStuds)
end

local function setBodyColor(model, color)
	local body = model:FindFirstChild("Body")
	if body then
		body.Color = color
	end
end

local function send(st, kind, payload)
	for _, member in ipairs(st.members or {}) do
		if member.Parent then
			patternEvent:FireClient(member, kind, payload)
		end
	end
end

-- 24-1 파티: 판정 대상 = 아레나 안 멤버 전원(각자 따로 맞는다). 캐릭터가 없거나 이미 죽은 멤버는 뺀다.
local function victims(st)
	local list = {}
	for _, member in ipairs(st.members or {}) do
		local character = member.Parent and member.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and (PlayerState.getHp(member) or 0) > 0 then
			table.insert(list, { player = member, root = root })
		end
	end
	return list
end

-- 판정 한 번의 피해. attack 배율은 감소식을 거친 피해에 곱한다(21-3 - 방어가 먹힌다). %최대체력은 방어를
-- 무시하고, 한 번의 발동에서 한 사람이 받는 합이 mechanics.gimmickFailMaxHpFraction을 넘지 않는다(BossMechanics).
local function applySkillDamage(model, data, skill, player)
	local damage = skill.damage
	if damage.kind == "maxHp" then
		BossMechanics.applyGimmickDamage(model, player, damage.fraction, skill.damageLabel)
	else
		PlayerDamage.applyHit(player, data.attack, skill.damageLabel, damage.multiplier)
	end
end

-- 헤롱 자세 해제 - 똑바로 세운다(돌진 종료·중단·리셋 공통).
local function clearDaze(model, st)
	if st.dazeBase then
		model:PivotTo(CFrame.new(st.dazeBase))
		st.dazeBase = nil
	end
end

-- ─────────────────────────── 발동 조건(실제 월드) ───────────────────────────
-- 조각의 뜻은 BossScheduler.lua 주석. notAfter는 스케줄러가 직접 판정한다.
local function conditionMet(model, st, condition)
	local kind = condition.type
	if kind == "hpBelow" then
		return MonsterState.getHpRatio(model) <= condition.value
	elseif kind == "hpAbove" then
		return MonsterState.getHpRatio(model) > condition.value
	elseif kind == "targetWithin" or kind == "targetBeyond" then
		local targetRoot = st.targetRoot
		if not targetRoot then
			return false
		end
		local distance = Reach.horizontalDistance(targetRoot.Position, st.position)
		if kind == "targetWithin" then
			return distance <= condition.studs
		end
		return distance > condition.studs
	elseif kind == "membersClustered" then
		local list = victims(st)
		for _, a in ipairs(list) do
			local near = 0
			for _, b in ipairs(list) do
				if Reach.horizontalDistance(a.root.Position, b.root.Position) <= condition.studs then
					near += 1
				end
			end
			if near >= condition.count then
				return true
			end
		end
		return false
	elseif kind == "gateArmed" then
		return BossMechanics.isGateArmed(model) == condition.value
	elseif kind == "gateArmedFor" then
		return BossMechanics.gateArmedSeconds(model) >= condition.seconds
	end
	return true
end

-- 시계를 "지금"부터 새로 잰다 - 스폰·어그로 시작·사망 리셋 때 부른다(재도전 = 처음부터).
-- 견습 모드는 data.skills가 부분집합이다(BossRules.buildTutorialInstanceData) - 없는 스킬은 시계 자체가 없다.
local function restartClocks(st, data, now)
	st.sched = BossScheduler.newState(data.skills, data.skillOrder, now)
end

local function ensureState(model, data)
	local st = MonsterState.getBossPatternState(model)
	if st and not st.phase then
		local now = os.clock()
		st.phase = "normal"
		st.phaseEndsAt = 0
		st.graceUntil = now + (data.scheduler.entryGraceSeconds or 0)
		st.waves = {}
		st.floorY = floorYUnder(MonsterState.getSpawnPosition(model))
		st.position = MonsterState.getSpawnPosition(model)
		-- 스케줄러에 넘기는 문맥은 한 번만 만든다(매 틱 클로저를 새로 만들지 않는다).
		st.pickCtx = {
			conditionMet = function(condition)
				return conditionMet(model, st, condition)
			end,
			boundSeconds = function(id)
				return BossSkillMath.boundSeconds(data.skills[id], zoneOf(model).halfSize)
			end,
		}
		restartClocks(st, data, now)
	end
	return st
end

local function endSkill(model, st, data, now)
	local id = st.current
	if id then
		print(("[forge-game] 보스 패턴 종료: %s (%.2f초 소요)"):format(id, now - (st.currentStartedAt or now)))
	end
	st.phase = "normal"
	st.current = nil
	st.skill = nil
	BossScheduler.onSkillEnd(st.sched, data.skills, id, now)
	MonsterState.setLastAttackTick(model, now) -- 스킬 직후 바로 평타가 또 나가지 않게(15-1과 같다)
end

-- ─────────────────────────── 프리미티브 핸들러 ───────────────────────────
-- 핸들러 = { start(c), step(c), bubbleSeconds(c), interrupt(c)? }. c = { model, st, data, skill, now, position, targetRoot }.
-- step은 스킬이 끝났으면 endSkill을 부른다. phase 이름은 21-3부터 쓰던 것을 그대로 둔다(로그·검증 블록 호환).

local HANDLERS = {}

-- ── circleBoss: 보스 중심 원. innerRadiusStuds가 있으면 도넛(안쪽이 안전), pulses가 있으면 연속 펄스 ──
-- 25-4: 판정이 "보스 좌표에서 반경 안"이라 위험 범위 도형도 보스 중심이다. 예고가 끝나는 순간의 거리만 본다 -
-- 그 사이 벗어났으면 완전히 무효(15-1 그대로).
local function beginPulse(c)
	local st, skill = c.st, c.skill
	local pulse = BossSkillMath.pulsesOf(skill)[st.pulseIndex]
	st.phase = "heavyTelegraph"
	st.phaseEndsAt = c.now + skill.telegraphSeconds
	setBodyColor(c.model, c.data.telegraphColor)
	send(st, "heavyTelegraph", {
		center = Vector3.new(c.position.X, st.floorY, c.position.Z),
		radius = pulse.radiusStuds,
		innerRadius = (pulse.innerRadiusStuds or 0) > 0 and pulse.innerRadiusStuds or nil,
		seconds = skill.telegraphSeconds,
	})
end

HANDLERS.circleBoss = {
	bubbleSeconds = function(c)
		return c.skill.telegraphSeconds * #BossSkillMath.pulsesOf(c.skill)
	end,
	start = function(c)
		c.st.pulseIndex = 1
		beginPulse(c)
	end,
	step = function(c)
		local st, skill = c.st, c.skill
		if c.now < st.phaseEndsAt then
			return
		end
		local pulses = BossSkillMath.pulsesOf(skill)
		local pulse = pulses[st.pulseIndex]
		local inner = pulse.innerRadiusStuds or 0
		for _, v in ipairs(victims(st)) do
			if Reach.within(v.root.Position, c.position, pulse.radiusStuds) -- 22-4: 수평 + 높이차 상한
				and Reach.horizontalDistance(v.root.Position, c.position) >= inner then
				applySkillDamage(c.model, c.data, skill, v.player)
			end
		end
		-- 25-4: 판정 순간 흰 섬광 - "임팩트 = 흰색".
		send(st, "heavyImpact", {
			center = Vector3.new(c.position.X, st.floorY, c.position.Z),
			radius = pulse.radiusStuds,
			innerRadius = inner > 0 and inner or nil,
		})
		if st.pulseIndex < #pulses then
			st.pulseIndex += 1
			beginPulse(c)
			return
		end
		setBodyColor(c.model, c.data.bodyColor)
		endSkill(c.model, st, c.data, c.now)
	end,
	interrupt = function(c)
		setBodyColor(c.model, c.data.bodyColor)
	end,
}

-- ── ring: 퍼지는 띠(진동파). 보스가 떠올랐다 찍는 동작이 예고, 찍는 순간 파동이 퍼진다. 점프로만 피한다 ──
local function startHop(c, seconds)
	local st, skill = c.st, c.skill
	st.phase = "shockHop"
	st.hopStartedAt = c.now
	st.hopSeconds = seconds
	st.phaseEndsAt = c.now + seconds
	send(st, "shockTelegraph", {
		center = Vector3.new(st.hopBase.X, st.floorY, st.hopBase.Z),
		seconds = seconds,
		hopHeight = skill.hopHeightStuds,
	})
end

-- 매 틱 모든 살아있는 파동에 대해: 파동 띠[반경-두께, 반경]가 대상을 지나는 동안 한 순간이라도 공중이면 회피,
-- 띠가 완전히 지나갔는데 한 번도 공중이 아니었으면 피격. 24-1: 멤버마다 touched/dodged/resolved를 따로 기록한다 -
-- 한 파동이 네 사람을 서로 다른 시각에 지나간다. 파동은 최대 반경까지 살아 있다.
local function updateWaves(c)
	local st, skill = c.st, c.skill
	local maxRadius = zoneOf(c.model).halfSize * BossSkillMath.WAVE_MAX_RADIUS_FACTOR
	local alive = {}
	local targets = victims(st)
	for _, wave in ipairs(st.waves) do
		local radius = (c.now - wave.startedAt) * skill.waveSpeedStuds
		wave.byPlayer = wave.byPlayer or {}
		for _, v in ipairs(targets) do
			local rec = wave.byPlayer[v.player]
			if not rec then
				rec = {}
				wave.byPlayer[v.player] = rec
			end
			local d = (xz(v.root.Position) - wave.center).Magnitude
			-- 22-4: 파동은 지면을 타고 퍼진다 - 파동 중심 지면(floorY)에서 높이차 상한 너머(절벽 위)는 안 닿는다.
			local inBand = d <= radius and d >= radius - skill.waveThicknessStuds
				and Reach.sameLayer(v.root.Position, Vector3.new(0, st.floorY, 0))
			if inBand then
				rec.touched = true
				if isAirborne(v.player.Character, skill.airborneClearanceStuds) then
					rec.dodged = true
				end
			elseif rec.touched and not rec.resolved and d < radius - skill.waveThicknessStuds then
				rec.resolved = true
				if not rec.dodged then
					applySkillDamage(c.model, c.data, skill, v.player)
				end
			end
		end
		if radius <= maxRadius then
			table.insert(alive, wave)
		end
	end
	st.waves = alive
end

-- 한 번 찍을 때 파동을 layers개 낸다 - 겹마다 startedAt을 layerGapSeconds만큼 늦춰 서로 다른 링으로 퍼지게 한다.
local function slam(c)
	local st, skill = c.st, c.skill
	c.model:PivotTo(CFrame.new(st.hopBase))
	local maxRadius = zoneOf(c.model).halfSize * BossSkillMath.WAVE_MAX_RADIUS_FACTOR
	for layer = 1, (skill.layers or 1) do
		local delay = (layer - 1) * (skill.layerGapSeconds or 0)
		table.insert(st.waves, { center = xz(st.hopBase), startedAt = c.now + delay })
		send(st, "shockwave", {
			center = Vector3.new(st.hopBase.X, st.floorY, st.hopBase.Z),
			serverStart = serverNow() + delay,
			speed = skill.waveSpeedStuds,
			thickness = skill.waveThicknessStuds,
			maxRadius = maxRadius,
		})
	end
	st.wavesSpawned += 1
end

HANDLERS.ring = {
	bubbleSeconds = function(c)
		return c.skill.telegraphSeconds + c.skill.repeatIntervalSeconds * (c.skill.waveCount - 1)
	end,
	start = function(c)
		local st = c.st
		st.hopBase = xz(c.position) + Vector3.new(0, MonsterState.getSpawnPosition(c.model).Y, 0)
		st.wavesSpawned = 0
		st.waves = {}
		startHop(c, c.skill.telegraphSeconds)
	end,
	step = function(c)
		local st, skill = c.st, c.skill
		updateWaves(c)
		if st.phase == "shockHop" then
			if c.now < st.phaseEndsAt then
				local progress = (c.now - st.hopStartedAt) / st.hopSeconds
				c.model:PivotTo(CFrame.new(st.hopBase + Vector3.new(0, skill.hopHeightStuds * math.sin(math.pi * progress), 0)))
				return
			end
			slam(c)
			if st.wavesSpawned < skill.waveCount then
				startHop(c, skill.repeatIntervalSeconds)
			else
				st.phase = "shockWait"
			end
		elseif #st.waves == 0 then -- shockWait
			endSkill(c.model, st, c.data, c.now)
		end
	end,
	interrupt = function(c)
		if c.st.hopBase then
			c.model:PivotTo(CFrame.new(c.st.hopBase))
		end
	end,
}

-- ── circleTarget: 대상 위치의 원. 기본은 count개 동시 산개(낙석), sequential이면 하나가 터진 뒤 그 순간의 대상 위치에 다음 것 ──
-- count는 입장 인원에 비례할 수 있다(countPerMember - 서리 거인 낙빙 N+2).
local function circleCount(data, skill)
	return skill.count + (skill.countPerMember or 0) * (data.partySize or 1)
end

local function beginCircles(c, positions, seconds)
	local st, skill = c.st, c.skill
	for i, p in ipairs(positions) do
		-- 22-4: 낙하점 Y는 그 자리 지면(언덕 위면 언덕 위). 못 찾으면 보스 발밑.
		positions[i] = Vector3.new(p.X, GroundProbe.surfaceY(p.X, p.Z, st.floorY) or st.floorY, p.Z)
	end
	st.meteorPositions = positions
	st.phase = "meteorTelegraph"
	st.phaseEndsAt = c.now + seconds
	send(st, "meteor", { positions = positions, radius = skill.radiusStuds, seconds = seconds })
end

HANDLERS.circleTarget = {
	bubbleSeconds = function(c)
		local skill = c.skill
		if skill.sequential then
			return skill.telegraphSeconds + (skill.repeatTelegraphSeconds or skill.telegraphSeconds) * (circleCount(c.data, skill) - 1)
		end
		return skill.telegraphSeconds
	end,
	start = function(c)
		local skill = c.skill
		local zone = zoneOf(c.model)
		local first = xz(c.targetRoot.Position)
		local positions = { clampToZone(first, zone, 2) }
		c.st.shotIndex = 1
		if not skill.sequential then
			for _ = 2, circleCount(c.data, skill) do
				local offset = Vector3.new(scatterRng:NextNumber(-1, 1), 0, scatterRng:NextNumber(-1, 1))
				if offset.Magnitude > 1 then
					offset = offset.Unit
				end
				table.insert(positions, clampToZone(first + offset * skill.scatterStuds, zone, 2))
			end
		end
		beginCircles(c, positions, skill.telegraphSeconds)
	end,
	step = function(c)
		local st, skill = c.st, c.skill
		if c.now < st.phaseEndsAt then
			return
		end
		for _, v in ipairs(victims(st)) do
			local p = xz(v.root.Position)
			for _, spot in ipairs(st.meteorPositions) do
				if (p - xz(spot)).Magnitude <= skill.radiusStuds and Reach.sameLayer(v.root.Position, spot) then -- 22-4
					applySkillDamage(c.model, c.data, skill, v.player)
					break
				end
			end
		end
		send(st, "meteorImpact", { positions = st.meteorPositions, radius = skill.radiusStuds })
		if skill.sequential and st.shotIndex < circleCount(c.data, skill) and c.targetRoot then
			st.shotIndex += 1
			beginCircles(c, { clampToZone(xz(c.targetRoot.Position), zoneOf(c.model), 2) }, skill.repeatTelegraphSeconds or skill.telegraphSeconds)
			return
		end
		endSkill(c.model, st, c.data, c.now)
	end,
}

-- ── charge: 정신집중 → 돌진. 느낌표가 뜨는 순간의 대상 좌표를 고정한다(이후 추적 안 함). dashCount만큼 잇는다 ──
local function startDash(c, fromPosition, dashIndex)
	local st, skill = c.st, c.skill
	local zone = zoneOf(c.model)
	local origin = xz(fromPosition)
	local snapshot = xz(c.targetRoot.Position)
	local dir = snapshot - origin
	if dir.Magnitude < 1e-3 then
		local look = c.model.PrimaryPart.CFrame.LookVector
		dir = Vector3.new(look.X, 0, look.Z)
		if dir.Magnitude < 1e-3 then
			dir = Vector3.new(0, 0, -1)
		end
	end
	dir = dir.Unit
	local length = clipToZone(origin, dir, zone, skill.arenaMarginStuds)
	st.chargeDashIndex = dashIndex
	st.chargeFrom = Vector3.new(origin.X, fromPosition.Y, origin.Z)
	st.chargeTo = st.chargeFrom + dir * length
	st.chargeHitBy = {} -- 24-1: 돌진 한 번에 멤버마다 한 번씩만(경로 위 전원 대상)
	st.phase = "focus"
	st.phaseEndsAt = c.now + skill.telegraphSeconds
	send(st, "focus", {
		bossPosition = st.chargeFrom,
		endPosition = st.chargeTo,
		halfWidth = skill.pathHalfWidthStuds,
		seconds = skill.telegraphSeconds,
		floorY = st.floorY,
	})
end

HANDLERS.charge = {
	bubbleSeconds = function(c)
		return c.skill.telegraphSeconds
	end,
	start = function(c)
		startDash(c, c.position, 1)
	end,
	step = function(c)
		local st, skill = c.st, c.skill
		if st.phase == "focus" then
			if c.now < st.phaseEndsAt then
				return
			end
			local length = (st.chargeTo - st.chargeFrom).Magnitude
			st.phase = "charge"
			st.chargeStartedAt = c.now
			st.chargeSeconds = length / skill.speedStuds
			send(st, "charge", { startPosition = st.chargeFrom, endPosition = st.chargeTo, durationSeconds = st.chargeSeconds })
		elseif st.phase == "charge" then
			local position = c.position
			local prev = xz(position)
			local progress = math.min((c.now - st.chargeStartedAt) / math.max(st.chargeSeconds, 1e-3), 1)
			local newPos = st.chargeFrom:Lerp(st.chargeTo, progress)
			-- 22-4: 돌진도 지면을 따른다. 계단 한 단(maxStepHeight)보다 큰 단차·심연이면 여기서 돌진을 끝낸다.
			local footY = position.Y - TerrainConfig.monsterFootOffsetStuds
			local groundY = GroundProbe.groundY(newPos.X, newPos.Z, footY)
			if groundY == nil or math.abs(groundY - footY) > TerrainConfig.maxStepHeightStuds then
				newPos = position
				progress = 1
			else
				newPos = Vector3.new(newPos.X, groundY + TerrainConfig.monsterFootOffsetStuds, newPos.Z)
			end
			c.model:PivotTo(CFrame.new(newPos))
			for _, v in ipairs(victims(st)) do
				if not st.chargeHitBy[v.player] and distanceToSegment(xz(v.root.Position), prev, xz(newPos)) <= skill.pathHalfWidthStuds
					and Reach.sameLayer(v.root.Position, newPos) then
					st.chargeHitBy[v.player] = true
					applySkillDamage(c.model, c.data, skill, v.player)
				end
			end
			if progress >= 1 then
				if st.chargeDashIndex < (skill.dashCount or 1) and c.targetRoot then
					-- 헤롱 없이 바로 다음 돌진(현재 위치·현재 대상 좌표로 재조준). 마지막 돌진에서만 헤롱.
					startDash(c, newPos, st.chargeDashIndex + 1)
				else
					-- 헤롱(주저앉기) - 몸을 내려 기울인다. 끝날 때(endSkill/interrupt) 똑바로 되돌린다.
					st.phase = "chargeRecover"
					st.phaseEndsAt = c.now + skill.recoverSeconds
					st.dazeBase = newPos
					c.model:PivotTo(CFrame.new(newPos - Vector3.new(0, skill.dazeSinkStuds, 0)) * CFrame.Angles(0, 0, math.rad(skill.dazeTiltDeg)))
					send(st, "daze", { seconds = skill.recoverSeconds })
				end
			end
		elseif c.now >= st.phaseEndsAt then -- chargeRecover
			clearDaze(c.model, st)
			endSkill(c.model, st, c.data, c.now)
		end
	end,
	interrupt = function(c)
		clearDaze(c.model, c.st)
	end,
}

-- ── line: 보스 중심에서 벽까지 뻗는 직선 directions개. 첫 빔은 대상 방향(centered면 부채의 한가운데가 대상 방향),
--    빔 사이 각 stepDeg. volleys만큼 반복 - 다음 볼리는 rotateDeg 돌리거나(십자) 그 순간의 대상으로 다시 겨눈다(reaim) ──
local function angleToTarget(c)
	local toTarget = xz(c.targetRoot.Position) - xz(c.position)
	return toTarget.Magnitude > 1e-3 and math.deg(math.atan2(toTarget.Z, toTarget.X)) or 0
end

local function firstBeamAngle(c)
	local skill = c.skill
	local spread = skill.centered and skill.stepDeg * ((skill.directions or 1) - 1) / 2 or 0
	return angleToTarget(c) - spread
end

local function startVolley(c, angleDeg)
	local st, skill = c.st, c.skill
	local zone = zoneOf(c.model)
	local origin = xz(c.model.PrimaryPart.Position)
	local beams, lengths = {}, {}
	for k = 0, (skill.directions or 1) - 1 do
		local a = math.rad(angleDeg + skill.stepDeg * k)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local length = clipToZone(origin, dir, zone, 1)
		table.insert(beams, { dir = dir, length = length })
		lengths[k + 1] = length
	end
	st.crossOrigin = origin
	st.crossBeams = beams
	st.crossAngle = angleDeg
	st.phase = "crossTelegraph"
	st.phaseEndsAt = c.now + skill.telegraphSeconds
	send(st, "cross", {
		center = Vector3.new(origin.X, st.floorY, origin.Z),
		angleDeg = angleDeg,
		stepDeg = skill.stepDeg,
		lengths = lengths,
		halfWidth = skill.halfWidthStuds,
		seconds = skill.telegraphSeconds,
	})
end

HANDLERS.line = {
	bubbleSeconds = function(c)
		return c.skill.telegraphSeconds * (c.skill.volleys or 1)
	end,
	start = function(c)
		c.st.crossVolley = 1
		startVolley(c, firstBeamAngle(c))
	end,
	step = function(c)
		local st, skill = c.st, c.skill
		if c.now < st.phaseEndsAt then
			return
		end
		for _, v in ipairs(victims(st)) do
			local rel = xz(v.root.Position) - st.crossOrigin
			for _, beam in ipairs(st.crossBeams) do
				local along = rel:Dot(beam.dir)
				if along >= 0 and along <= beam.length and (rel - beam.dir * along).Magnitude <= skill.halfWidthStuds
					and Reach.sameLayer(v.root.Position, Vector3.new(0, st.floorY, 0)) then -- 22-4: 지면을 탄다
					applySkillDamage(c.model, c.data, skill, v.player)
					break
				end
			end
		end
		send(st, "crossFire", { angleDeg = st.crossAngle })
		if st.crossVolley < (skill.volleys or 1) then
			st.crossVolley += 1
			startVolley(c, (skill.reaim and c.targetRoot) and firstBeamAngle(c) or (st.crossAngle + skill.rotateDeg))
			return
		end
		endSkill(c.model, st, c.data, c.now)
	end,
}

-- ── gimmick: 전역 기믹의 뼈대(29-1). 예고(게이트가 선다) → 판정(보스별 파훼 조건은 BossMechanics.registerJudge) ──
-- 힌트 단계(20.73 [1-5]): 1 = 말풍선 ×bubbleScale + 안전지대 흰 화살표, 2 이상 = 예고 ×telegraphMultiplier.
local function gimmickTelegraphSeconds(st, skill)
	local seconds = skill.telegraphSeconds
	if (st.hintLevel or 0) >= BossData.mechanics.hint.maxLevel then
		seconds *= BossData.mechanics.hint.telegraphMultiplier
	end
	return seconds
end

HANDLERS.gimmick = {
	bubbleSeconds = function(c)
		return gimmickTelegraphSeconds(c.st, c.skill)
	end,
	start = function(c)
		local st, skill = c.st, c.skill
		local seconds = gimmickTelegraphSeconds(st, skill)
		local hintLevel = st.hintLevel or 0
		BossMechanics.onGimmickStart(c.model)
		st.phase = "gimmickTelegraph"
		st.phaseEndsAt = c.now + seconds
		send(st, "gimmickTelegraph", {
			kind = skill.kind,
			center = Vector3.new(c.position.X, st.floorY, c.position.Z),
			seconds = seconds,
			hintLevel = hintLevel,
			-- 힌트 1단계부터 클라가 흰 화살표를 세우는 자리. 보스별 세션이 skill.safeSpots(model, data)를 채운다.
			safeSpots = (hintLevel >= 1 and skill.safeSpots) and skill.safeSpots(c.model, c.data) or nil,
		})
	end,
	step = function(c)
		local st, skill = c.st, c.skill
		if st.phase == "gimmickTelegraph" then
			if c.now < st.phaseEndsAt then
				return
			end
			local broken = BossMechanics.resolveGimmick(c.model, c.data, skill, victims(st), skill.damageLabel)
			send(st, "gimmickResolve", {
				broken = broken,
				windowSeconds = broken and skill.breakWindow and skill.breakWindow.seconds or nil,
			})
			if (skill.recoverSeconds or 0) > 0 then
				st.phase = "gimmickRecover"
				st.phaseEndsAt = c.now + skill.recoverSeconds
				return
			end
		elseif c.now < st.phaseEndsAt then -- gimmickRecover
			return
		end
		endSkill(c.model, st, c.data, c.now)
	end,
}

-- ─────────────────────────── 틱 ───────────────────────────

local function context(model, st, data, now, position, targetRoot)
	local c = st.context
	if not c then
		c = { model = model, st = st, data = data }
		st.context = c
	end
	c.skill = st.skill
	c.now = now
	c.position = position
	c.targetRoot = targetRoot
	return c
end

local function startSkill(model, st, data, id, now, position, targetRoot)
	local skill = data.skills[id]
	st.current = id
	st.skill = skill
	st.currentStartedAt = now
	BossScheduler.onSkillStart(st.sched, id)
	BossMechanics.beginActivation(model) -- %최대체력 피해의 발동당 1인 누적을 비운다
	print(("[forge-game] 보스 패턴 시작: %s (직전 종료 후 %.2f초)"):format(id, now - st.sched.lastEndAt))
	local c = context(model, st, data, now, position, targetRoot)
	local handler = HANDLERS[skill.primitive]
	-- 전조 말풍선 - 모든 스킬이 예고 시작 순간 하나씩 띄운다. 그림은 클라(BossPatternVisuals)가 bubble 키로 고른다.
	send(st, "bubble", {
		pattern = skill.bubble or id,
		seconds = handler.bubbleSeconds(c),
		scale = (skill.primitive == "gimmick" and (st.hintLevel or 0) >= 1) and BossData.mechanics.hint.bubbleScale or nil,
	})
	handler.start(c)
end

-- 반환: true면 스킬 진행 중(보스 구속 - MonsterAI는 추격·평타를 건너뛴다).
-- members(24-1): 이 보스와 싸우는 멤버 목록(BossEncounter.getMembersOfModel) - 피해·연출 대상. 생략하면 target 하나.
function BossPatterns.step(model, data, position, target, targetRoot, dt, members)
	local st = ensureState(model, data)
	if not st then
		return false
	end
	st.target = target
	st.targetRoot = targetRoot
	st.position = position
	st.members = (members and #members > 0) and members or { target }
	local now = os.clock()
	BossMechanics.tick(st.members, dt) -- 29-1: 잡힌 멤버의 구출 핸들러

	if st.phase == "normal" then
		local pickCtx = st.pickCtx
		pickCtx.now = now
		pickCtx.graceUntil = st.graceUntil
		-- 격노(HP ≤ enragedHpFraction)에서만 전역 쿨이 짧아진다(사용자 지시 - 연속 사용은 체력 20% 이하에서만).
		pickCtx.enraged = MonsterState.getHpRatio(model) <= data.scheduler.enragedHpFraction
		local pick = BossScheduler.pick(st.sched, data.skills, data.skillOrder, data.scheduler, pickCtx)
		if pick then
			startSkill(model, st, data, pick, now, position, targetRoot)
			return true
		end
		return false
	end

	local handler = HANDLERS[st.skill.primitive]
	handler.step(context(model, st, data, now, position, targetRoot))
	return true
end

-- 진행 중인 스킬을 즉시 취소한다(대상 사망·퇴장·리쉬). 안 하면 다음에 다시 어그로를 잡았을 때 지난 예고가
-- 그대로 남아 재회 즉시 "공짜 강타"가 나가거나, 색·높이가 예고 상태로 멈춘 채 남는다.
function BossPatterns.interrupt(model, data)
	local st = MonsterState.getBossPatternState(model)
	if not st or not st.phase or st.phase == "normal" then
		return
	end
	setBodyColor(model, data.bodyColor)
	local handler = st.skill and HANDLERS[st.skill.primitive]
	if handler and handler.interrupt then
		handler.interrupt(context(model, st, data, os.clock(), st.position, st.targetRoot))
	end
	clearDaze(model, st)
	st.waves = {}
	send(st, "reset", {})
	endSkill(model, st, data, os.clock())
end

-- 어그로가 붙는 순간(idle→chasing) 시계를 새로 잰다 - "첫 예고는 전투 시작 뒤 쿨만큼"을 재도전·재어그로에도 유지한다.
function BossPatterns.onAggro(model, data)
	local st = ensureState(model, data)
	if st then
		restartClocks(st, data, os.clock())
	end
end

-- 플레이어 사망 리셋(21-3 [1], BossEncounter.resetFor) - 스킬·파동·연출·게이트 전부 처음 상태로.
function BossPatterns.reset(model, data)
	BossPatterns.interrupt(model, data)
	local st = ensureState(model, data)
	if st then
		restartClocks(st, data, os.clock())
		st.target = nil
	end
	BossMechanics.reset(model)
end

-- 입장·재도전 유예(20.44 [3](다)) - 이 시각 전엔 스킬을 시작하지 않는다.
function BossPatterns.setGrace(model, data, seconds)
	local st = ensureState(model, data)
	if st then
		st.graceUntil = os.clock() + seconds
	end
end

-- DevTools 전용 - 진행 중인 스킬을 끊고 다음 틱에 특정 스킬을 강제로 시작한다(전역 쿨·유예·쿨·조건 전부 무시).
function BossPatterns.force(model, data, id)
	local st = ensureState(model, data)
	if not st or not data.skills[id] then -- 견습 모드는 data.skills가 부분집합이다 - 없는 스킬은 강제도 막는다
		return false
	end
	BossPatterns.interrupt(model, data)
	BossScheduler.force(st.sched, id)
	st.graceUntil = 0
	return true
end

function BossPatterns.getPhase(model)
	local st = MonsterState.getBossPatternState(model)
	return st and st.phase or "normal"
end

-- 29-1 힌트 단계(PRD 20.73 [1-5]) - BossEncounter가 스폰·전멸 리셋 때 넣는다.
function BossPatterns.setHintLevel(model, data, level)
	local st = ensureState(model, data)
	if st then
		st.hintLevel = level
	end
end

function BossPatterns.getHintLevel(model)
	local st = MonsterState.getBossPatternState(model)
	return st and st.hintLevel or 0
end

-- 자동 검증 전용 - 스킬별 "다음에 쓸 수 있을 때까지 남은 시간(초)" 사본, 시계가 시작된 시각(os.clock 기준), 지금 도는 스킬.
-- 시계는 어그로가 붙는 순간 다시 시작되므로(onAggro) 실시간 검증은 반드시 이 시각을 기준으로 잰다(29-1의 교훈).
function BossPatterns.debugClocks(model)
	local st = MonsterState.getBossPatternState(model)
	local clocks = {}
	if st and st.sched then
		local now = os.clock()
		for id, at in pairs(st.sched.readyAt) do
			clocks[id] = at - now
		end
		return clocks, st.sched.startedAt, st.current
	end
	return clocks, nil, nil
end

return BossPatterns
