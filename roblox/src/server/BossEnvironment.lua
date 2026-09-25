-- BR1 환경 변화(docs/design/boss-br1.md §4) - 보스 체력 hpBelow(50%)부터 도는 **두 번째 시계**. 기본 패턴(BossScheduler)과 따로 돌아 서로 겹친다(사용자 결정).
-- 데이터 = BossData 보스의 environment 표(보스 이름이 들어간 분기 없음 - 구역 모양 · 효과 조각의 조합):
--   zones.shape  "circle"(원 radiusStuds - perMember면 멤버 발밑마다 + extra개 무작위) · "ring"(아레나 중심에서 beyondStuds 밖) · "rect"(사각 판 - 멤버 발밑 우선,
--                1 + ⌊인원 ÷ 2⌋개) · "pit"(아레나 중심 원 radiusStuds - 클라가 당긴다 · 중심 coreRadiusStuds만 도트) · "wind"(바람 - 클라가 민다 · 바람이 불어 가는
--                반원의 beyondStuds 밖만 도트, rotateEverySeconds마다 rotateDeg 돈다)
--   onStart      { launch = { heightStuds, distanceStuds }, damage = { kind = "attack", multiplier } } - 활성 순간 구역 안(발 기준 같은 층)의 사람에게
--   tick         { seconds, fraction } - 활성 동안 구역 안(발 기준 같은 층)에 있으면 seconds마다 최대체력 fraction. 환경 발동 하나의 1인 합 ≤ maxHpFraction(55%)
-- 흐름: (체력 hpBelow 이하가 된 뒤 firstDelaySeconds) → 전조 telegraphSeconds(보이는 구역 = 판정 구역) → 활성 durationSeconds → 끝 → cooldownSeconds 뒤 다시.
-- 서버 = 구역 판정 · 도트 · 튕김만. 기울기 · 물 · 모래 소용돌이 · 바람 줄기 · 끌림/밀림은 클라(BossEnvironmentView).
-- 겹침(§4-3): shouldDefer - 환경이 도는 동안 "피할 수 없음" 쌍(BossOverlap.classify)의 패턴은 나올 차례에 deferChance로 미루고, 같은 발동 안에서 두 번 나오지 않는다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossOverlap = require(ReplicatedStorage.Shared.BossOverlap)
local Reach = require(ReplicatedStorage.Shared.Reach)
local BossSkillMath = require(ReplicatedStorage.Shared.BossSkillMath)
local CollectionService = game:GetService("CollectionService")
local MonsterState = require(script.Parent.MonsterState)
local MonsterSpawner = require(script.Parent.MonsterSpawner)
local PlayerDamage = require(script.Parent.PlayerDamage)
local BossTrap = require(script.Parent.BossTrap)
local GroundProbe = require(script.Parent.GroundProbe)
local HeightGuard = require(script.Parent.HeightGuard)
local JumpMath = require(ReplicatedStorage.Shared.JumpMath)
local BossJumpCourse = require(script.Parent.BossJumpCourse)
local BossArenaMap = require(script.Parent.BossArenaMap) -- BR1-3 멤버 스폰(복귀) 자리 - 그 조각은 무너지지 않는다
local BossArenaContainment = require(script.Parent.BossArenaContainment) -- BR1-3 복귀 직후 보호 중이면 떨어지지 않는다

local BossEnvironment = {}

local ENV = BossData.mechanics.environment
local kit
local rng = Random.new()

local function xz(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- ─────────────────────────── 구역 ───────────────────────────
-- 구역 목록(서버 판정 · 클라 그림이 같은 표를 쓴다). 각 항목 = { shape, center, radius, halfLength, halfWidth, angleDeg, beyond, core }.
local function placeZones(model, st, data, env)
	local zone = kit.zoneOf(model)
	local center = xz(zone.center)
	local arenaRadius = zone.radius or (zone.halfSize or 96)
	local spec = env.zones
	local list = {}
	local members = kit.victims(st)
	if spec.shape == "circle" then
		local spots = {}
		if spec.perMember then
			for _, v in ipairs(members) do
				table.insert(spots, xz(v.root.Position))
			end
		end
		for _ = 1, (spec.extra or 0) do
			local angle = rng:NextNumber(0, 2 * math.pi)
			local distance = rng:NextNumber(0, arenaRadius - spec.radiusStuds)
			table.insert(spots, center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance)
		end
		for _, spot in ipairs(spots) do
			local p = kit.clampToZone(spot, zone, spec.radiusStuds * 0.5)
			table.insert(list, { shape = "circle", center = Vector3.new(p.X, st.floorY, p.Z), radius = spec.radiusStuds })
		end
	elseif spec.shape == "ring" then
		table.insert(list, { shape = "ring", center = Vector3.new(center.X, st.floorY, center.Z), beyond = spec.beyondStuds, radius = arenaRadius })
	elseif spec.shape == "rect" and spec.halfMap then
		-- BR1-2 맵 절반 판: 무작위 방위 θ - 길이 방향 = θ(지름 전체) · 폭 = 반경(한쪽 반). 판 가운데 = 중심 + 옆 방향 × 반경 ÷ 2.
		local angle = rng:NextNumber(0, 360)
		if spec.walkOutStuds then
			-- BR1-3 판 털기: 판 위 멤버가 모두 walkOutStuds 안에서 경계(지름)를 넘어 나갈 수 있는 방향만(dirTries번 뽑아 가장 나은 것 - 회피 부등식)
			local bestAngle, bestDepth = angle, math.huge
			for _ = 1, spec.dirTries or 12 do
				local candidate = rng:NextNumber(0, 360)
				local worst = 0
				for _, v in ipairs(members) do
					worst = math.max(worst, BossSkillMath.halfMapDepth(center, math.rad(candidate), v.root.Position) or 0)
				end
				if worst < bestDepth then
					bestAngle, bestDepth = candidate, worst
				end
				if worst <= spec.walkOutStuds then
					break
				end
			end
			angle = bestAngle
		end
		local a = math.rad(angle)
		local side = Vector3.new(-math.sin(a), 0, math.cos(a))
		local c = center + side * (arenaRadius / 2)
		table.insert(list, { shape = "rect", halfMap = true, center = Vector3.new(c.X, st.floorY, c.Z), angleDeg = angle, halfLength = arenaRadius, halfWidth = arenaRadius / 2 })
	elseif spec.shape == "rect" then
		local count = 1 + math.floor(#members / 2)
		for i = 1, count do
			local v = members[((i - 1) % math.max(#members, 1)) + 1]
			local spot = v and xz(v.root.Position) or center
			local angle = rng:NextNumber(0, 360)
			local p = kit.clampToZone(spot, zone, math.min(spec.halfLengthStuds, spec.halfWidthStuds))
			table.insert(list, { shape = "rect", center = Vector3.new(p.X, st.floorY, p.Z), angleDeg = angle, halfLength = spec.halfLengthStuds, halfWidth = spec.halfWidthStuds })
		end
	elseif spec.shape == "pit" and (spec.perMember or spec.extra) then
		-- BR1-2 여러 구덩이: 멤버 발밑마다 1개 + 무작위 extra개(서로 minGapStuds - 못 놓으면 건너뛴다)
		local spots = {}
		if spec.perMember then
			for _, v in ipairs(members) do
				table.insert(spots, xz(v.root.Position))
			end
		end
		for _ = 1, (spec.extra or 0) * 10 do
			if #spots >= #members + (spec.extra or 0) then
				break
			end
			local angle = rng:NextNumber(0, 2 * math.pi)
			local spot = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * rng:NextNumber(0, arenaRadius - spec.radiusStuds - 4)
			local clear = true
			for _, other in ipairs(spots) do
				clear = clear and (other - spot).Magnitude >= (spec.minGapStuds or 0)
			end
			if clear then
				table.insert(spots, spot)
			end
		end
		for _, spot in ipairs(spots) do
			local p = kit.clampToZone(spot, zone, spec.radiusStuds * 0.5)
			table.insert(list, { shape = "pit", center = Vector3.new(p.X, st.floorY, p.Z), radius = spec.radiusStuds, core = spec.coreRadiusStuds, pull = spec.pullStudsPerSecond })
		end
	elseif spec.shape == "pit" then
		table.insert(list, { shape = "pit", center = Vector3.new(center.X, st.floorY, center.Z), radius = spec.radiusStuds, core = spec.coreRadiusStuds, pull = spec.pullStudsPerSecond })
	elseif spec.shape == "wind" then
		table.insert(list, { shape = "wind", center = Vector3.new(center.X, st.floorY, center.Z), angleDeg = rng:NextNumber(0, 360), beyond = spec.beyondStuds, radius = arenaRadius, push = spec.pushStudsPerSecond, airMultiplier = spec.airMultiplier })
	end
	return list
end

-- 이 점이 구역의 "도트가 드는 곳"인가(pit = 중심부 · wind = 바람이 불어 가는 반원의 가장자리). 가장자리는 플레이어에게 유리하게(몸통 반폭만큼 안쪽만).
function BossEnvironment.insideHazard(z, position)
	local half = BossData.mechanics.dodge.characterHalfWidthStuds
	local rel = xz(position) - xz(z.center)
	local d = rel.Magnitude
	if z.shape == "circle" then
		return d <= z.radius - half
	elseif z.shape == "ring" then
		return d >= z.beyond + half
	elseif z.shape == "pit" then
		return d <= z.core - half
	elseif z.shape == "rect" then
		local a = math.rad(z.angleDeg)
		local along = Vector3.new(math.cos(a), 0, math.sin(a))
		local side = Vector3.new(-along.Z, 0, along.X)
		return math.abs(rel:Dot(along)) <= z.halfLength - half and math.abs(rel:Dot(side)) <= z.halfWidth - half
	elseif z.shape == "wind" then
		local a = math.rad(z.angleDeg)
		local downwind = Vector3.new(math.cos(a), 0, math.sin(a))
		return d >= z.beyond + half and rel:Dot(downwind) > 0
	elseif z.shape == "slice" then
		-- BR1-3 피자 조각: 허브 밖 · 조각의 두 경계선 안쪽(몸통 반폭만큼 - 경계에 걸친 사람은 안 떨어진다)
		if d < z.hub + half then
			return false
		end
		local offset = (math.deg(math.atan2(rel.Z, rel.X)) - z.startDeg) % 360
		local margin = math.deg(math.asin(math.min(1, half / math.max(d, 1e-3))))
		return offset >= margin and offset <= z.widthDeg - margin
	end
	return false
end

local function inAnyHazard(zones, position)
	for _, z in ipairs(zones) do
		if BossEnvironment.insideHazard(z, position) then
			return true
		end
	end
	return false
end

-- ─────────────────────────── 수정 부수기(kind = "jumpCourse" - BR1-2 · server/BossJumpCourse) ───────────────────────────
-- 전조 때 두 수정 자리의 코스(저장 공간에 지어 둔 것 중 무작위)를 정하고, 활성 순간 복제해 세운다 · 보스 보호막(피해 무효) · 아레나 가장자리 투명 벽.
-- 두 수정을 다 깨면 성공(보호막 해제 · 보스 기절 stunSeconds · 코스를 치운다). 시간 제한 없음(그동안 보스는 패턴을 계속 쓴다).
local courses = {} -- [보스 Model] = true(코스가 서 있다)

-- 리뷰 1(BR1)의 뜻 그대로: 이 점이 지금 서 있는 코스 발판 위인가 - MonsterAI가 "대상이 다른 층으로 갔다"로 보스를 되돌리지 않게 묻는다.
function BossEnvironment.onGardenPlatform(model, position)
	if not courses[model] then
		return false
	end
	for _, part in ipairs(GroundProbe.folder():GetChildren()) do
		if part:GetAttribute("CourseSite") then
			local rel = position - part.Position
			if math.abs(rel.X) <= part.Size.X / 2 + 1 and math.abs(rel.Z) <= part.Size.Z / 2 + 1 and rel.Y >= 0 and rel.Y <= 12 then
				return true
			end
		end
	end
	return false
end

-- 사용자(BR1-2 후속): 수정 부수기 동안 보스는 패턴을 쓰지 않는다(BossPatterns.step이 묻는다 - 보호막 속에서 멈춰 선다 · 평타도 없다).
function BossEnvironment.isCourseActive(model)
	return courses[model] == true
end

local function clearCourse(model)
	if courses[model] then
		courses[model] = nil
		MonsterState.setShielded(model, false)
	end
	BossJumpCourse.clear(model)
end

-- ─────────────────────────── 무너진 바닥(BR1-3 - 피자 조각 · 들린 판) ───────────────────────────
-- 조각 번호 목록 → 구역 목록(서버 판정 · 클라 그림이 같은 표).
local function sliceZones(center, floorY, radius, spec, indices)
	local list = {}
	local width = 360 / spec.count
	for _, k in ipairs(indices) do
		table.insert(list, { shape = "slice", index = k, center = Vector3.new(center.X, floorY, center.Z), startDeg = (k - 1) * width, widthDeg = width, hub = spec.hubRadiusStuds, radius = radius })
	end
	return list
end

-- 이번 붕괴의 조각: 보스가 선 조각 · 멤버 스폰(복귀 자리) 조각은 빼고 · 서로 붙지 않게 · 지난번 조각은 되도록 피한다(BossSkillMath.pickSlices).
local function planSlices(model, st, env, e)
	local zone = kit.zoneOf(model)
	local center = xz(zone.center)
	local spec = env.zones
	local excluded = {}
	local bossSlice = BossSkillMath.sliceIndexOf(center, st.position or center, spec.count, spec.hubRadiusStuds, 0)
	if bossSlice then
		excluded[bossSlice] = true
	end
	local count = math.max(#(st.members or {}), 1)
	for i = 1, count do
		local ok, point = pcall(BossArenaMap.entryPosition, st.zoneKey, i, count)
		local k = ok and point and BossSkillMath.sliceIndexOf(center, point, spec.count, spec.hubRadiusStuds, 0)
		if k then
			excluded[k] = true
		end
	end
	local previous = {}
	for _, z in ipairs(e.collapsed or {}) do
		previous[z.index] = true
	end
	local indices = BossSkillMath.pickSlices(spec.count, spec.collapse, excluded, previous, spec.nonAdjacent, function()
		return rng:NextNumber()
	end)
	return sliceZones(center, st.floorY, zone.radius or 140, spec, indices)
end

-- 지금 무너진(빈) 바닥의 구역 목록(없으면 nil) - 피자 조각은 다음 붕괴까지 · 판 털기는 들린 동안.
local function voidZonesOf(st, env)
	local e = st and st.env
	if not (e and env) then
		return nil
	end
	if env.kind == "collapse" then
		return e.collapsed
	elseif env.voidFall and e.phase == "active" then
		return e.zones
	end
	return nil
end

-- 이 자리가 무너진 바닥인가 - 보스 이동 · 돌진이 묻는다(MonsterAI · BossPatterns). 몸통 여유 없이(경계선 그대로).
function BossEnvironment.blocksBoss(model, position)
	local data = MonsterState.getData(model)
	local st = MonsterState.getBossPatternState(model)
	local zones = voidZonesOf(st, data and data.environment)
	if not zones then
		return false
	end
	for _, z in ipairs(zones) do
		local rel = xz(position) - xz(z.center)
		if z.shape == "slice" then
			local offset = (math.deg(math.atan2(rel.Z, rel.X)) - z.startDeg) % 360
			if rel.Magnitude >= z.hub and offset <= z.widthDeg then
				return true
			end
		elseif BossEnvironment.insideHazard(z, position) then
			return true
		end
	end
	return false
end

-- 선분(origin → dir × length)에서 처음 무너진 바닥에 닿기 직전 거리(없으면 nil) - 돌진이 거기서 멈춘다.
function BossEnvironment.firstBlockedAlong(model, origin, dir, length)
	local d = 1
	while d <= length do
		if BossEnvironment.blocksBoss(model, origin + dir * d) then
			return math.max(d - 2, 0)
		end
		d += 1
	end
	return nil
end

-- 발을 딛으면 떨어진다: 최대 체력 fall.maxHpFraction + 바닥 아래로(맵 이탈 복귀가 본인 스폰 · 보호 0.75초로 받는다 - BossArenaContainment).
-- 떠 있으면 아직 · 잡힌 사람 · 복귀 보호 중 · 이번 발동에 날아간 사람(판 털기)은 안 떨어진다.
local function checkFalls(st, env, e, zones, now)
	e.fell = e.fell or {}
	for _, v in ipairs(kit.victims(st)) do
		local player = v.player
		local recently = e.fell[player] and now - e.fell[player] < 1.5
		if not recently and not BossTrap.isTrapped(player) and not BossArenaContainment.isProtected(player) and not (e.launched and e.launched[player])
			and Reach.sameLayer(v.groundFeet, Vector3.new(0, st.floorY, 0)) and inAnyHazard(zones, v.root.Position) then
			local airborne
			if typeof(player) == "Instance" then
				airborne = kit.isAirborne(player.Character, 0.5)
			else
				airborne = player.debugAirborne == true
			end
			if not airborne then
				e.fell[player] = now
				PlayerDamage.applyMaxHpFraction(player, env.fall.maxHpFraction, env.damageLabel .. " - 낙사")
				BossTrap.noteSkillHit(player)
				local down = Vector3.new(v.root.Position.X, st.floorY - env.fall.dropStuds, v.root.Position.Z)
				if typeof(v.root) == "Instance" then
					v.root.CFrame = CFrame.new(down) * v.root.CFrame.Rotation
					v.root.AssemblyLinearVelocity = Vector3.new(0, -30, 0)
				else
					v.root.Position = down
				end
				kit.send(st, "voidFall", { userId = typeof(player) == "Instance" and player.UserId or nil, position = Vector3.new(down.X, st.floorY, down.Z) })
				kit.debugEvent("voidFall", { player = player, at = now })
				print(("[forge-game] 낙사(%s): %s - 최대 체력 %.0f%% · 복귀"):format(env.id, tostring(player.Name), env.fall.maxHpFraction * 100))
			end
		end
	end
end

-- ─────────────────────────── 틱 ───────────────────────────
local function stateOf(st)
	st.env = st.env or { phase = "idle", taken = {} }
	return st.env
end

local function envOf(data)
	return data.environment
end

local function dotDamage(model, e, env, player, fraction)
	local taken = e.taken[player] or 0
	local applied = math.min(fraction, ENV.maxHpFractionPerActivation - taken)
	if applied <= 0 then
		return
	end
	e.taken[player] = taken + applied
	PlayerDamage.applyMaxHpFraction(player, applied, env.damageLabel)
end

local function begin(model, st, data, env, e, now)
	e.phase = "telegraph"
	e.phaseEndsAt = now + env.telegraphSeconds
	e.zones = env.kind == "collapse" and planSlices(model, st, env, e) or placeZones(model, st, data, env)
	e.launched = nil
	e.taken = {}
	e.usedImpossible = false
	e.activation = (e.activation or 0) + 1
	if env.kind == "jumpCourse" then
		local zone = kit.zoneOf(model)
		e.garden = { courses = BossJumpCourse.plan(zone.center, st.floorY, zone.radius or 140), wallRadius = zone.radius or 140 }
	else
		e.garden = nil
	end
	print(("[forge-game] 환경 변화 전조: %s - 구역 %d개, %.1f초"):format(env.id, #e.zones, env.telegraphSeconds))
	kit.send(st, "envTelegraph", { id = env.id, style = env.style, zones = e.zones, seconds = env.telegraphSeconds, bossId = data.id, motion = env.motion, garden = e.garden, shakes = env.shakes })
end

local function activate(model, st, data, env, e, now)
	e.phase = "active"
	e.phaseEndsAt = now + env.durationSeconds
	e.lastTickAt = {}
	if env.kind == "collapse" then
		-- BR1-3: 이전 조각이 돌아오고 새 조각이 무너진다 - 무너진 채 다음 붕괴(cooldownSeconds)까지
		local restored = e.collapsed
		e.collapsed = e.zones
		e.phaseEndsAt = now + env.cooldownSeconds
		local names = {}
		for _, z in ipairs(e.zones) do
			table.insert(names, tostring(z.index))
		end
		print(("[forge-game] 지반 붕괴: 조각 %s 무너짐 · 복구 %d"):format(table.concat(names, ","), #(restored or {})))
		kit.send(st, "envStart", { id = env.id, style = env.style, zones = e.zones, restored = restored, seconds = env.cooldownSeconds, bossId = data.id, color = data.headColor })
		return
	end
	e.launched = {}
	e.windTurnAt = now + (env.zones.rotateEverySeconds or math.huge)
	-- 활성 순간 효과(onStart - 밥상뒤집기의 튕김 + 피해): 구역 안(발 기준 같은 층 - 떠 있으면 안 맞는다)의 사람.
	local onStart = env.onStart
	if onStart and onStart.pan then
		-- BR1-2 프라이팬: 판 위 전원(떠 있어도 - 더 멀리) · 판 바깥쪽 ± 흩어짐 · 높은 포물선 · 피해 뒤 발사 · 멀리 가면 별 반짝(아레나 멤버 전원)
		local random01 = function()
			return rng:NextNumber()
		end
		for _, z in ipairs(e.zones) do
			if z.shape == "rect" then
				local a = math.rad(z.angleDeg)
				local alongDir = Vector3.new(math.cos(a), 0, math.sin(a))
				local sideDir = Vector3.new(-alongDir.Z, 0, alongDir.X)
				for _, v in ipairs(kit.victims(st)) do
					local rel = xz(v.root.Position) - xz(z.center)
					local inside = math.abs(rel:Dot(alongDir)) <= z.halfLength and math.abs(rel:Dot(sideDir)) <= z.halfWidth
					local airborne
					if typeof(v.player) == "Instance" then
						airborne = kit.isAirborne(v.player.Character, 0.5)
					else
						airborne = v.player.debugAirborne == true -- 검증 스탠드인(표)만 - 진짜 Player에는 이 필드가 없다(읽으면 에러)
					end
					if inside and not BossTrap.isTrapped(v.player) and (airborne or Reach.sameLayer(v.groundFeet, Vector3.new(0, st.floorY, 0))) then
						local dir, height, distance, multiplier, star = BossSkillMath.panLaunch(onStart.pan, rel, airborne, random01)
						e.launched[v.player] = true -- BR1-3 판 털기: 날아간 사람은 이번 발동의 빈 공간 낙사 면제
						kit.applySkillDamage(model, data, { damage = { kind = "attack", multiplier = multiplier }, damageLabel = env.damageLabel }, v.player)
						local c = { model = model, st = st, data = data, now = now }
						kit.runHitEffects(c, { { type = "launch", heightStuds = height, distanceStuds = distance, escape = true } }, v, v.root.Position - dir * 5, 1)
						kit.debugEvent("pan", { player = v.player, height = height, distance = distance, airborne = airborne, star = star, at = now })
						if star then
							local airSeconds = JumpMath.launchAirSeconds(height)
							local land = xz(v.root.Position) + dir * distance
							kit.send(st, "starTwinkle", { position = Vector3.new(land.X, st.floorY + height * 0.8 + 12, land.Z), delay = airSeconds * 0.85, userId = typeof(v.player) == "Instance" and v.player.UserId or nil })
						end
					end
				end
			end
		end
	elseif onStart then
		for _, v in ipairs(kit.victims(st)) do
			if not BossTrap.isTrapped(v.player) and Reach.sameLayer(v.groundFeet, Vector3.new(0, st.floorY, 0)) and inAnyHazard(e.zones, v.root.Position) then
				if onStart.damage then
					kit.applySkillDamage(model, data, { damage = onStart.damage, damageLabel = env.damageLabel }, v.player)
				end
				if onStart.launch then
					local c = { model = model, st = st, data = data, now = now }
					local zone = kit.zoneOf(model)
					-- 판 가운데 → 아레나 중심 쪽으로 튕긴다(맵 밖으로 던지지 않는다 - 튕김 상한 · 착지 경계는 기존 조각이 자른다)
					local toward = xz(zone.center) - xz(v.root.Position)
					local from = v.root.Position - (toward.Magnitude > 1e-3 and toward.Unit or Vector3.new(1, 0, 0)) * 5
					kit.runHitEffects(c, { { type = "launch", heightStuds = onStart.launch.heightStuds, distanceStuds = onStart.launch.distanceStuds } }, v, from, 1)
				end
			end
		end
	end
	if e.garden then
		local zone = kit.zoneOf(model)
		courses[model] = true
		MonsterState.setShielded(model, true)
		e.phaseEndsAt = math.huge -- 시간 제한 없음(두 수정을 깨야 끝난다)
		BossJumpCourse.build(model, e.garden.courses, zone.center, st.floorY, zone.radius or 140, MonsterState.getZoneKey(model), env.garden, function(site, broken, hits)
			kit.send(st, "gardenCoreHit", { index = site, broken = broken, hits = hits })
		end, function(stage, positions)
			kit.send(st, "courseHelp", { stage = stage, positions = positions }) -- BR1-2 도움 단계 알림 + 발판 강조
		end)
	end
	print(("[forge-game] 환경 변화 시작: %s - %.1f초"):format(env.id, env.durationSeconds))
	kit.send(st, "envStart", { id = env.id, style = env.style, zones = e.zones, seconds = env.durationSeconds, bossId = data.id, garden = e.garden, color = data.headColor, shakes = env.shakes })
end

local function finish(model, st, env, e, now)
	e.phase = "cooldown"
	e.phaseEndsAt = now + env.cooldownSeconds
	e.zones = nil
	e.garden = nil
	clearCourse(model)
	kit.send(st, "envEnd", { id = env.id })
	print(("[forge-game] 환경 변화 끝: %s"):format(env.id))
end

function BossEnvironment.step(model, st, data, now, _dt)
	local env = envOf(data)
	if not env or data.isTutorial then
		return
	end
	local e = stateOf(st)
	if e.phase == "idle" then
		if MonsterState.getHpRatio(model) <= env.hpBelow then
			e.phase = "armed"
			e.phaseEndsAt = now + env.firstDelaySeconds
		end
		return
	end
	local voids = voidZonesOf(st, env)
	if voids and #voids > 0 then
		checkFalls(st, env, e, voids, now) -- BR1-3 무너진 조각 · 들린 판
	end
	if e.phase == "armed" or e.phase == "cooldown" or (env.kind == "collapse" and e.phase == "active") then
		if now >= e.phaseEndsAt then
			begin(model, st, data, env, e, now)
		end
		return
	end
	if e.phase == "telegraph" then
		if now >= e.phaseEndsAt then
			activate(model, st, data, env, e, now)
		end
		return
	end
	-- active: 도트 · 바람 회전
	if env.tick then
		for _, v in ipairs(kit.victims(st)) do
			if not BossTrap.isTrapped(v.player) and Reach.sameLayer(v.groundFeet, Vector3.new(0, st.floorY, 0)) and inAnyHazard(e.zones, v.root.Position) then
				local last = e.lastTickAt[v.player]
				if not last or now - last >= env.tick.seconds then
					e.lastTickAt[v.player] = now
					dotDamage(model, e, env, v.player, env.tick.fraction)
				end
			end
		end
	end
	if env.zones.shape == "wind" and now >= e.windTurnAt then
		e.windTurnAt = now + env.zones.rotateEverySeconds
		for _, z in ipairs(e.zones) do
			z.angleDeg = (z.angleDeg + env.zones.rotateDeg) % 360
		end
		kit.send(st, "envWind", { zones = e.zones })
	end
	-- 수정 부수기: 체크포인트 · 두 수정을 다 깨면 성공(보호막 해제 · 기절 · 코스 치움). 시간 제한 없음.
	if courses[model] then
		BossJumpCourse.step(model, kit.victims(st), st.floorY, now)
		local broken, total = BossJumpCourse.brokenCount(model)
		if total > 0 and broken >= total then
			print(("[forge-game] 수정 부수기 성공 → 보호막 해제 · 보스 기절 %.1f초"):format(env.garden.stunSeconds))
			kit.send(st, "gimmickResolve", { broken = true, windowSeconds = env.garden.stunSeconds })
			finish(model, st, env, e, now)
			kit.stun(model, st, data, env.garden.stunSeconds)
		end
		return
	end
	if now >= e.phaseEndsAt then
		finish(model, st, env, e, now)
	end
end

-- 겹침: 환경이 도는 동안 "피할 수 없음" 쌍(BossOverlap.classify - 자동 검사)은 나올 차례에 deferChance로 미룬다 · 같은 발동 안에서 두 번 안 나온다.
function BossEnvironment.shouldDefer(_model, st, data, skillId, _now)
	local env = envOf(data)
	local e = st.env
	if not env or not e or (e.phase ~= "telegraph" and e.phase ~= "active") then
		return false
	end
	local class = BossOverlap.classOf(data.id, skillId)
	if class ~= "impossible" then
		return false
	end
	if e.usedImpossible or rng:NextNumber() < ENV.overlap.deferChance then
		return true
	end
	e.usedImpossible = true
	print(("[forge-game] 환경 겹침: %s + %s(피할 수 없음) - 이번 발동에 한 번 허용"):format(env.id, skillId))
	return false
end

function BossEnvironment.deferSeconds()
	return ENV.overlap.deferSeconds
end

-- 전멸 리셋 · 사망 리셋: 처음 상태(체력 50%를 다시 넘어야 온다). 클라 그림은 "reset"이 지운다. 수정 공중 정원의 파트도 치운다.
function BossEnvironment.reset(model, st)
	if st then
		if st.env and (st.env.phase == "telegraph" or st.env.phase == "active") and kit then
			kit.send(st, "envEnd", {}) -- 리뷰 4: 패턴 "reset"은 환경 그림을 안 지운다 - 환경 리셋은 이 신호로
		end
		st.env = nil
	end
	clearCourse(model)
end

-- 보스전 종료(처치 · 이탈): 수정 공중 정원의 파트(발판 · 점프대 · 핵)를 치운다 - 구역은 논리뿐이라 남는 것이 없다.
function BossEnvironment.clear(model)
	clearCourse(model)
end

-- 자동 검증 전용: 지금 이 보스의 코스 파트 수(발판 + 벽) · 수정 수
function BossEnvironment.debugGarden(model)
	local parts, walls, crystals = BossJumpCourse.debugCounts(model)
	return parts + walls, crystals
end

function BossEnvironment.register(patternKit)
	kit = patternKit
	task.defer(BossOverlap.warm) -- 겹침 분류표를 서버 시작 때 채운다(첫 환경 발동 틱이 튀지 않게)
end

-- 자동 검증 · 하네스 전용
BossEnvironment.debug = { placeZones = function(...) return placeZones(...) end }

return BossEnvironment
