-- 보스 패턴 상태 머신 + 스케줄러(21-3, PRD-forge-game-roblox.md 20.44 [3](나) 설계의 구현).
-- 15-1의 tryBossAttack(예고 후 강한 일격 하나)을 "패턴 5종이 한 번에 하나씩 도는" 구조로
-- 일반화했다. MonsterAI.server.lua는 매 Heartbeat마다 step()을 부르고, 반환값이 true(패턴
-- 진행 중 - 보스 구속)면 추격·평타를 건너뛴다. 판정은 전부 서버가 한다 - 클라는 어떤 상태도
-- 보고하지 않고(점프 여부조차), BossPatternEvent로 받은 예고·연출만 그린다(BossPatternVisuals.
-- client.lua). 상수는 전부 BossData.bosses[id].patterns(단일 출처)에서 읽는다.
--
-- 상태는 MonsterState.getBossPatternState(model)이 돌려주는 테이블 하나에 산다 - 보스가
-- 죽거나 물러나 MonsterState.clear가 불리면 같이 사라진다(별도 정리 코드가 필요 없다).
--
-- 스케줄러 규칙(겹침 방지가 이 파일의 존재 이유 - 지시 [5]):
--   (1) phase가 "normal"일 때만 새 패턴을 시작한다 → 두 패턴이 동시에 도는 일이 구조적으로
--       없다. (2) 직전 패턴 종료 후 patternMinGapSeconds가 지나야 한다. (3) 입장·재도전
--       유예(graceUntil) 중엔 시작하지 않는다. (4) 후보(자기 nextAt이 지난 패턴) 중 가장
--       오래 기다린 것부터. 각 패턴의 nextAt은 "그 패턴이 끝난 시각 + intervalSeconds"다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local TerrainConfig = require(ReplicatedStorage.Shared.data.TerrainConfig)
local Reach = require(ReplicatedStorage.Shared.Reach)
local MonsterState = require(script.Parent.MonsterState)
local PlayerDamage = require(script.Parent.PlayerDamage)
local GroundProbe = require(script.Parent.GroundProbe)

local BossPatterns = {}

-- 22-4 높이 규칙(다음 세션 보스맵이 그대로 쓴다, PRD 20.50 [2]):
--   · 모든 패턴 판정은 XZ 수평 + |ΔY| ≤ TerrainConfig.heightToleranceStuds(8). 파동·낙석·십자
--     화염은 "그 패턴의 지면 Y"(파동 중심 = 보스 발밑, 낙석 = 낙하점 지면, 십자 = 보스 발밑)
--     기준이라 8 넘게 높은 언덕 위 플레이어에겐 닿지 않는다(절벽 = 안전지대, 의도).
--   · 돌진 이동은 매 틱 지면 Y를 따른다(GroundProbe) - 경사에서 땅에 박히거나 뜨지 않는다.
--     경사 한계를 넘는 단차를 만나면 그 자리에서 돌진이 끝난다(헤롱 시작).
--   · 낙석 낙하점 Y는 그 XZ의 지면 Y(못 찾으면 보스 발밑 floorY).

-- 클라 연출 채널. 개인 아레나라 대상 플레이어 한 명에게만 보낸다(FireClient).
local patternEvent = Instance.new("RemoteEvent")
patternEvent.Name = "BossPatternEvent"
patternEvent.Parent = ReplicatedStorage

-- 파동 최대 반경 - 아레나 대각선 반(96×√2≈136)보다 조금 크게. 여기까지 퍼지면 파동을 지운다.
local WAVE_MAX_RADIUS_FACTOR = math.sqrt(2) + 0.05

local PATTERN_ORDER = { "heavy", "shockwave", "meteor", "charge", "cross" }

local scatterRng = Random.new()

local function xz(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function serverNow()
	return Workspace:GetServerTimeNow()
end

-- 보스가 속한 아레나 zone(WorldConfig.zones.bossArenaN). 없으면(DevTools로 사냥터에 띄운
-- 경우 등) 스폰 지점 중심의 같은 크기 정사각형으로 대신한다.
local function zoneOf(model)
	local zone = WorldConfig.zones[MonsterState.getZoneKey(model) or ""]
	if zone then
		return zone
	end
	return { center = xz(MonsterState.getSpawnPosition(model)), halfSize = WorldConfig.bossArena.halfSizeStuds }
end

-- origin에서 XZ 단위벡터 dir 방향으로 아레나 AABB(margin만큼 안쪽) 안에 머무는 최대 거리.
-- 돌진 도착점·십자 화염 길이가 이걸로 잘려 담장 밖으로 절대 안 나간다(지시 [3]).
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

-- 공중 판정(진동파). 21-3 실측(서버 시점): Humanoid 상태(Jumping/Freefall)는 점프 시작 순간
-- 즉시 복제되지만 FloorMaterial은 약 0.2초 늦고 착지 상태(Landed/Running)는 아직 3~6stud
-- 높이에서 먼저 바뀐다 - 그래서 "지면 거리"를 레이캐스트로 직접 재는 것을 주 판정으로,
-- 상태는 점프 시작 직후(아직 높이가 안 붙은 0.1초)의 보조 판정으로만 쓴다. 서 있을 때의
-- 지면 거리 = HipHeight + 루트 반높이(R15 기본 2+1=3, 아바타 스케일이 달라도 이 식은 같다).
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

local function intervalOf(data, id)
	if id == "heavy" then
		return data.heavyAttackIntervalSeconds
	end
	return data.patterns[id].intervalSeconds
end

-- 패턴 시계를 "지금"부터 새로 잰다 - 스폰·어그로 시작·사망 리셋 때 부른다(재도전 = 처음부터).
local function restartClocks(st, data, now)
	st.nextAt = {}
	for _, id in ipairs(PATTERN_ORDER) do
		st.nextAt[id] = now + intervalOf(data, id)
	end
	st.lastPatternEndAt = now
end

local function ensureState(model, data)
	local st = MonsterState.getBossPatternState(model)
	if st and not st.phase then
		local now = os.clock()
		st.phase = "normal"
		st.phaseEndsAt = 0
		st.graceUntil = now + (data.entryGraceSeconds or 0)
		st.waves = {}
		st.floorY = floorYUnder(MonsterState.getSpawnPosition(model))
		restartClocks(st, data, now)
	end
	return st
end

local function setBodyColor(model, color)
	local body = model:FindFirstChild("Body")
	if body then
		body.Color = color
	end
end

local function send(st, kind, payload)
	if st.target and st.target.Parent then
		patternEvent:FireClient(st.target, kind, payload)
	end
end

-- 헤롱 자세 해제 - 똑바로 세운다(돌진 종료·중단·리셋 공통).
local function clearDaze(model, st)
	if st.dazeBase then
		model:PivotTo(CFrame.new(st.dazeBase))
		st.dazeBase = nil
	end
end

local function endPattern(model, st, data, now)
	local id = st.current
	if id then
		print(("[forge-game] 보스 패턴 종료: %s (%.2f초 소요)"):format(id, now - (st.currentStartedAt or now)))
	end
	st.phase = "normal"
	st.current = nil
	st.lastPatternEndAt = now
	if id then
		st.nextAt[id] = now + intervalOf(data, id)
	end
	MonsterState.setLastAttackTick(model, now) -- 패턴 직후 바로 평타가 또 나가지 않게(15-1과 같다)
end

-- ─────────────────────────── 패턴 시작 ───────────────────────────

local function startHeavy(model, st, data, now)
	st.phase = "heavyTelegraph"
	st.phaseEndsAt = now + data.telegraphWarmupSeconds
	setBodyColor(model, data.telegraphColor)
end

local function startShockHop(model, st, data, now, seconds)
	local cfg = data.patterns.shockwave
	st.phase = "shockHop"
	st.hopStartedAt = now
	st.hopSeconds = seconds
	st.phaseEndsAt = now + seconds
	send(st, "shockTelegraph", {
		center = Vector3.new(st.hopBase.X, st.floorY, st.hopBase.Z),
		seconds = seconds,
		hopHeight = cfg.hopHeightStuds,
	})
end

local function startShockwave(model, st, data, now, position)
	local base = xz(position) + Vector3.new(0, MonsterState.getSpawnPosition(model).Y, 0)
	st.hopBase = base
	st.wavesSpawned = 0
	st.waves = {}
	startShockHop(model, st, data, now, data.patterns.shockwave.telegraphSeconds)
end

local function startCharge(model, st, data, now, position, targetRoot)
	local cfg = data.patterns.charge
	local zone = zoneOf(model)
	local origin = xz(position)
	-- 느낌표가 뜨는 "이 순간"의 좌표를 고정한다(지시 [3] - 이후 추적 안 함).
	local snapshot = xz(targetRoot.Position)
	local dir = snapshot - origin
	if dir.Magnitude < 1e-3 then
		local look = model.PrimaryPart.CFrame.LookVector
		dir = Vector3.new(look.X, 0, look.Z)
		if dir.Magnitude < 1e-3 then
			dir = Vector3.new(0, 0, -1)
		end
	end
	dir = dir.Unit
	local length = clipToZone(origin, dir, zone, cfg.arenaMarginStuds)
	local y = position.Y
	st.chargeFrom = Vector3.new(origin.X, y, origin.Z)
	st.chargeTo = st.chargeFrom + dir * length
	st.chargeDir = dir
	st.chargeHit = false
	st.phase = "focus"
	st.phaseEndsAt = now + cfg.focusSeconds
	send(st, "focus", {
		bossPosition = st.chargeFrom,
		endPosition = st.chargeTo,
		halfWidth = cfg.pathHalfWidthStuds,
		seconds = cfg.focusSeconds,
		floorY = st.floorY,
	})
end

local function startMeteor(model, st, data, now, targetRoot)
	local cfg = data.patterns.meteor
	local zone = zoneOf(model)
	local first = xz(targetRoot.Position)
	local positions = { clampToZone(first, zone, 2) }
	for _ = 2, cfg.count do
		local offset = Vector3.new(scatterRng:NextNumber(-1, 1), 0, scatterRng:NextNumber(-1, 1))
		if offset.Magnitude > 1 then
			offset = offset.Unit
		end
		table.insert(positions, clampToZone(first + offset * cfg.scatterStuds, zone, 2))
	end
	for i, p in ipairs(positions) do
		-- 22-4: 낙하점 Y는 그 자리 지면(언덕 위면 언덕 위). 못 찾으면 보스 발밑.
		positions[i] = Vector3.new(p.X, GroundProbe.surfaceY(p.X, p.Z, st.floorY) or st.floorY, p.Z)
	end
	st.meteorPositions = positions
	st.phase = "meteorTelegraph"
	st.phaseEndsAt = now + cfg.telegraphSeconds
	send(st, "meteor", { positions = positions, radius = cfg.radiusStuds, seconds = cfg.telegraphSeconds })
end

local function crossBeams(model, st, data, angleDeg)
	local zone = zoneOf(model)
	local origin = xz(model.PrimaryPart.Position)
	local beams = {}
	for k = 0, 3 do
		local a = math.rad(angleDeg + 90 * k)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		table.insert(beams, { dir = dir, length = clipToZone(origin, dir, zone, 1) })
	end
	return origin, beams
end

local function startCrossVolley(model, st, data, now, angleDeg)
	local cfg = data.patterns.cross
	local origin, beams = crossBeams(model, st, data, angleDeg)
	st.crossOrigin = origin
	st.crossBeams = beams
	st.crossAngle = angleDeg
	st.phase = "crossTelegraph"
	st.phaseEndsAt = now + cfg.telegraphSeconds
	local lengths = {}
	for i, b in ipairs(beams) do
		lengths[i] = b.length
	end
	send(st, "cross", {
		center = Vector3.new(origin.X, st.floorY, origin.Z),
		angleDeg = angleDeg,
		lengths = lengths,
		halfWidth = cfg.halfWidthStuds,
		seconds = cfg.telegraphSeconds,
	})
end

local function startCross(model, st, data, now, position, targetRoot)
	local toTarget = xz(targetRoot.Position) - xz(position)
	local angle = toTarget.Magnitude > 1e-3 and math.deg(math.atan2(toTarget.Z, toTarget.X)) or 0
	st.crossVolley = 1
	startCrossVolley(model, st, data, now, angle)
end

-- 말풍선이 떠 있는 시간 = 그 패턴이 "예고 중"인 전체 구간(진동파는 세 번 찍기까지, 십자는
-- 두 볼리까지). 돌진은 정신집중 동안만 - 이후 헤롱 말풍선이 따로 뜬다.
local function bubbleSecondsOf(data, id)
	if id == "heavy" then
		return data.telegraphWarmupSeconds
	elseif id == "charge" then
		return data.patterns.charge.focusSeconds
	elseif id == "shockwave" then
		local cfg = data.patterns.shockwave
		return cfg.telegraphSeconds + cfg.repeatIntervalSeconds * (cfg.waveCount - 1)
	elseif id == "cross" then
		local cfg = data.patterns.cross
		return cfg.telegraphSeconds * cfg.volleys
	end
	return data.patterns[id].telegraphSeconds
end

local function startPattern(model, st, data, id, now, position, targetRoot)
	st.current = id
	st.currentStartedAt = now
	print(("[forge-game] 보스 패턴 시작: %s (직전 종료 후 %.2f초)"):format(id, now - st.lastPatternEndAt))
	-- 전조 말풍선(사용자 지시 - 느낌표·물음표·바닥 그림으로 "스킬을 쓰겠구나"를 읽게) -
	-- 모든 패턴이 예고 시작 순간 하나씩 띄운다. 그림은 클라(BossPatternVisuals)가 고른다.
	send(st, "bubble", { pattern = id, seconds = bubbleSecondsOf(data, id) })
	if id == "heavy" then
		startHeavy(model, st, data, now)
	elseif id == "shockwave" then
		startShockwave(model, st, data, now, position)
	elseif id == "charge" then
		startCharge(model, st, data, now, position, targetRoot)
	elseif id == "meteor" then
		startMeteor(model, st, data, now, targetRoot)
	elseif id == "cross" then
		startCross(model, st, data, now, position, targetRoot)
	end
end

-- ─────────────────────────── 진동파 판정 ───────────────────────────

-- 매 틱 모든 살아있는 파동에 대해: 파동 띠[반경-두께, 반경]가 대상 플레이어를 지나는 동안
-- 한 순간이라도 공중이면 회피, 띠가 완전히 지나갔는데 한 번도 공중이 아니었으면 피격.
-- "지나는 동안 한 순간이라도"라 점프 입력 창 = 체공 + 통과 시간(BossData 주석 참고).
local function updateWaves(model, st, data, now, target, targetRoot)
	local cfg = data.patterns.shockwave
	local maxRadius = zoneOf(model).halfSize * WAVE_MAX_RADIUS_FACTOR
	local alive = {}
	for _, wave in ipairs(st.waves) do
		local radius = (now - wave.startedAt) * cfg.waveSpeedStuds
		local d = (xz(targetRoot.Position) - wave.center).Magnitude
		-- 22-4: 파동은 지면을 타고 퍼진다 - 파동 중심 지면(floorY)에서 높이차 상한 너머(절벽 위)는 안 닿는다.
		local inBand = d <= radius and d >= radius - cfg.waveThicknessStuds
			and Reach.sameLayer(targetRoot.Position, Vector3.new(0, st.floorY, 0))
		if inBand then
			wave.touched = true
			if isAirborne(target.Character, cfg.airborneClearanceStuds) then
				wave.dodged = true
			end
		elseif wave.touched and not wave.resolved and d < radius - cfg.waveThicknessStuds then
			wave.resolved = true
			if not wave.dodged then
				PlayerDamage.applyHit(target, data.attack, "진동파", cfg.damageMultiplier)
			end
		end
		if not wave.resolved and radius <= maxRadius then
			table.insert(alive, wave)
		end
	end
	st.waves = alive
end

local function slam(model, st, data, now)
	local cfg = data.patterns.shockwave
	model:PivotTo(CFrame.new(st.hopBase))
	local wave = { center = xz(st.hopBase), startedAt = now }
	table.insert(st.waves, wave)
	st.wavesSpawned += 1
	send(st, "shockwave", {
		center = Vector3.new(st.hopBase.X, st.floorY, st.hopBase.Z),
		serverStart = serverNow(),
		speed = cfg.waveSpeedStuds,
		thickness = cfg.waveThicknessStuds,
		maxRadius = zoneOf(model).halfSize * WAVE_MAX_RADIUS_FACTOR,
	})
end

-- ─────────────────────────── 틱 ───────────────────────────

-- 반환: true면 패턴 진행 중(보스 구속 - MonsterAI는 추격·평타를 건너뛴다).
function BossPatterns.step(model, data, position, target, targetRoot, dt)
	local st = ensureState(model, data)
	if not st then
		return false
	end
	st.target = target
	local now = os.clock()

	if st.phase == "normal" then
		-- 격노(HP ≤ 20%)에서만 패턴을 연속으로 쓴다(사용자 지시) - 평소엔 긴 간격.
		local enraged = MonsterState.getHpRatio(model) <= data.enragedHpFraction
		local gap = enraged and data.enragedPatternMinGapSeconds or data.patternMinGapSeconds
		if now < st.graceUntil or now < st.lastPatternEndAt + gap then
			return false
		end
		local pick, pickAt = nil, math.huge
		for _, id in ipairs(PATTERN_ORDER) do
			local at = st.nextAt[id]
			if now >= at and at < pickAt then
				pick, pickAt = id, at
			end
		end
		if pick then
			startPattern(model, st, data, pick, now, position, targetRoot)
			return true
		end
		return false
	end

	if st.phase == "heavyTelegraph" then
		if now < st.phaseEndsAt then
			return true
		end
		-- 예고가 끝나는 이 순간의 거리만 본다 - 그 사이 벗어났으면 완전히 무효(15-1 그대로).
		if Reach.within(targetRoot.Position, position, data.attackRangeStuds) then -- 22-4: 수평 + 높이차 상한
			PlayerDamage.applyHit(target, data.attack, "강공격", data.heavyAttackMultiplier)
		end
		setBodyColor(model, data.bodyColor)
		endPattern(model, st, data, now)
		return true
	end

	if st.phase == "shockHop" then
		updateWaves(model, st, data, now, target, targetRoot)
		local cfg = data.patterns.shockwave
		if now < st.phaseEndsAt then
			local progress = (now - st.hopStartedAt) / st.hopSeconds
			model:PivotTo(CFrame.new(st.hopBase + Vector3.new(0, cfg.hopHeightStuds * math.sin(math.pi * progress), 0)))
			return true
		end
		slam(model, st, data, now)
		if st.wavesSpawned < cfg.waveCount then
			startShockHop(model, st, data, now, cfg.repeatIntervalSeconds)
		else
			st.phase = "shockWait"
		end
		return true
	end

	if st.phase == "shockWait" then
		updateWaves(model, st, data, now, target, targetRoot)
		if #st.waves == 0 then
			endPattern(model, st, data, now)
		end
		return true
	end

	if st.phase == "focus" then
		if now < st.phaseEndsAt then
			return true
		end
		local cfg = data.patterns.charge
		local length = (st.chargeTo - st.chargeFrom).Magnitude
		st.phase = "charge"
		st.chargeStartedAt = now
		st.chargeSeconds = length / cfg.speedStuds
		send(st, "charge", { startPosition = st.chargeFrom, endPosition = st.chargeTo, durationSeconds = st.chargeSeconds })
		return true
	end

	if st.phase == "charge" then
		local cfg = data.patterns.charge
		local prev = xz(position)
		local progress = math.min((now - st.chargeStartedAt) / math.max(st.chargeSeconds, 1e-3), 1)
		local newPos = st.chargeFrom:Lerp(st.chargeTo, progress)
		-- 22-4: 돌진도 지면을 따른다. 발밑 기준 프로브 창(±4) 안에 지면이 있으면 그 위로, 계단 한
		-- 단(maxStepHeight)보다 큰 단차·심연이면 여기서 돌진을 끝낸다(진행도 1로 강제 → 헤롱).
		local footY = position.Y - TerrainConfig.monsterFootOffsetStuds
		local groundY = GroundProbe.groundY(newPos.X, newPos.Z, footY)
		if groundY == nil or math.abs(groundY - footY) > TerrainConfig.maxStepHeightStuds then
			newPos = position
			progress = 1
		else
			newPos = Vector3.new(newPos.X, groundY + TerrainConfig.monsterFootOffsetStuds, newPos.Z)
		end
		model:PivotTo(CFrame.new(newPos))
		if not st.chargeHit and distanceToSegment(xz(targetRoot.Position), prev, xz(newPos)) <= cfg.pathHalfWidthStuds
			and Reach.sameLayer(targetRoot.Position, newPos) then
			st.chargeHit = true
			PlayerDamage.applyMaxHpFraction(target, cfg.damageMaxHpFraction, "돌진")
		end
		if progress >= 1 then
			-- 헤롱(주저앉기) - 몸을 내려 기울인다. 이 상태의 위치·기울기는 st.dazeBase로 기억해
			-- 끝날 때(endPattern/interrupt) 똑바로 되돌린다.
			st.phase = "chargeRecover"
			st.phaseEndsAt = now + cfg.recoverSeconds
			st.dazeBase = newPos
			model:PivotTo(CFrame.new(newPos - Vector3.new(0, cfg.dazeSinkStuds, 0)) * CFrame.Angles(0, 0, math.rad(cfg.dazeTiltDeg)))
			send(st, "daze", { seconds = cfg.recoverSeconds })
		end
		return true
	end

	if st.phase == "chargeRecover" then
		if now >= st.phaseEndsAt then
			clearDaze(model, st)
			endPattern(model, st, data, now)
		end
		return true
	end

	if st.phase == "meteorTelegraph" then
		if now < st.phaseEndsAt then
			return true
		end
		local cfg = data.patterns.meteor
		local p = xz(targetRoot.Position)
		for _, spot in ipairs(st.meteorPositions) do
			if (p - xz(spot)).Magnitude <= cfg.radiusStuds and Reach.sameLayer(targetRoot.Position, spot) then -- 22-4
				PlayerDamage.applyHit(target, data.attack, "낙석", cfg.damageMultiplier)
				break
			end
		end
		send(st, "meteorImpact", { positions = st.meteorPositions, radius = cfg.radiusStuds })
		endPattern(model, st, data, now)
		return true
	end

	if st.phase == "crossTelegraph" then
		if now < st.phaseEndsAt then
			return true
		end
		local cfg = data.patterns.cross
		local rel = xz(targetRoot.Position) - st.crossOrigin
		for _, beam in ipairs(st.crossBeams) do
			local along = rel:Dot(beam.dir)
			if along >= 0 and along <= beam.length and (rel - beam.dir * along).Magnitude <= cfg.halfWidthStuds
				and Reach.sameLayer(targetRoot.Position, Vector3.new(0, st.floorY, 0)) then -- 22-4: 화염은 지면을 탄다
				PlayerDamage.applyHit(target, data.attack, "십자 화염", cfg.damageMultiplier)
				break
			end
		end
		send(st, "crossFire", { angleDeg = st.crossAngle })
		if st.crossVolley < cfg.volleys then
			st.crossVolley += 1
			startCrossVolley(model, st, data, now, st.crossAngle + cfg.rotateDeg)
		else
			endPattern(model, st, data, now)
		end
		return true
	end

	return false
end

-- 진행 중인 패턴을 즉시 취소한다(대상 사망·퇴장·리쉬 - 15-1 resetBossPhaseIfNeeded의 일반화).
-- 안 하면 다음에 다시 어그로를 잡았을 때 지난 예고가 그대로 남아 재회 즉시 "공짜 강타"가
-- 나가거나, 색·높이가 예고 상태로 멈춘 채 남는다.
function BossPatterns.interrupt(model, data)
	local st = MonsterState.getBossPatternState(model)
	if not st or not st.phase or st.phase == "normal" then
		return
	end
	setBodyColor(model, data.bodyColor)
	if st.hopBase and (st.phase == "shockHop" or st.phase == "shockWait") then
		model:PivotTo(CFrame.new(st.hopBase))
	end
	clearDaze(model, st)
	st.waves = {}
	send(st, "reset", {})
	endPattern(model, st, data, os.clock())
end

-- 어그로가 붙는 순간(idle→chasing) 패턴 시계를 새로 잰다 - "첫 예고는 전투 시작 뒤 주기만큼"
-- 이라는 15-1의 체감(스폰 6초 뒤 첫 강공격)을 재도전·재어그로에도 그대로 유지한다.
function BossPatterns.onAggro(model, data)
	local st = ensureState(model, data)
	if st then
		restartClocks(st, data, os.clock())
	end
end

-- 플레이어 사망 리셋(21-3 [1], BossEncounter.resetFor) - 패턴·파동·연출 전부 처음 상태로.
function BossPatterns.reset(model, data)
	BossPatterns.interrupt(model, data)
	local st = ensureState(model, data)
	if st then
		restartClocks(st, data, os.clock())
		st.target = nil
	end
end

-- 입장·재도전 유예(20.44 [3](다)) - 이 시각 전엔 패턴을 시작하지 않는다.
function BossPatterns.setGrace(model, data, seconds)
	local st = ensureState(model, data)
	if st then
		st.graceUntil = os.clock() + seconds
	end
end

-- DevTools 전용 - 진행 중인 패턴을 끊고 다음 틱에 특정 패턴을 강제로 시작한다(간격·유예·
-- 시계 전부 무시).
function BossPatterns.force(model, data, id)
	local st = ensureState(model, data)
	if not st or not table.find(PATTERN_ORDER, id) then
		return false
	end
	BossPatterns.interrupt(model, data)
	st.nextAt[id] = -math.huge -- 가장 오래 기다린 패턴이 되어 다음 틱에 뽑힌다
	st.lastPatternEndAt = -math.huge
	st.graceUntil = 0
	return true
end

function BossPatterns.getPhase(model)
	local st = MonsterState.getBossPatternState(model)
	return st and st.phase or "normal"
end

return BossPatterns
