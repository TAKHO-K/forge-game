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
local CollectionService = game:GetService("CollectionService")
local MonsterState = require(script.Parent.MonsterState)
local MonsterSpawner = require(script.Parent.MonsterSpawner)
local PlayerDamage = require(script.Parent.PlayerDamage)
local BossTrap = require(script.Parent.BossTrap)
local GroundProbe = require(script.Parent.GroundProbe)

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
	elseif spec.shape == "rect" then
		local count = 1 + math.floor(#members / 2)
		for i = 1, count do
			local v = members[((i - 1) % math.max(#members, 1)) + 1]
			local spot = v and xz(v.root.Position) or center
			local angle = rng:NextNumber(0, 360)
			local p = kit.clampToZone(spot, zone, math.min(spec.halfLengthStuds, spec.halfWidthStuds))
			table.insert(list, { shape = "rect", center = Vector3.new(p.X, st.floorY, p.Z), angleDeg = angle, halfLength = spec.halfLengthStuds, halfWidth = spec.halfWidthStuds })
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

-- ─────────────────────────── 수정 공중 정원(kind = "cores") ───────────────────────────
-- 서버에 실제 파트를 세운다: 공중 발판(Workspace.Ground - 서버 지면 탐지 · 높이 검증이 지면으로 본다) · 점프대(태그 BossJumpPad + Attribute LaunchHeight -
-- 밟은 사람의 클라가 자기 캐릭터를 띄운다) · 수정 핵 2(구출 대상과 같은 타격 대상 - 평타 · 스킬 · 투사체). 두 핵의 마지막 타격이 coreWindowSeconds 안이면 성공.
local gardens = {} -- [보스 Model] = { parts = { Part }, cores = { Model }, lastHit = { [1] = t, [2] = t }, solved }

local function gardenLayout(model, st, env)
	local zone = kit.zoneOf(model)
	local center = xz(zone.center)
	local g = env.garden
	local layout = { platforms = {}, pads = {}, cores = {} }
	local base = rng:NextNumber(0, 360)
	for i = 1, g.platformCount do
		local a = math.rad(base + 360 * (i - 1) / g.platformCount)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local p = center + dir * g.platformRadiusStuds
		table.insert(layout.platforms, Vector3.new(p.X, st.floorY + g.platformHeightStuds, p.Z))
		local pad = center + dir * (g.platformRadiusStuds - g.padOffsetStuds)
		table.insert(layout.pads, Vector3.new(pad.X, st.floorY, pad.Z))
	end
	local a = rng:NextNumber(0, 2 * math.pi)
	local floorCore = center + Vector3.new(math.cos(a), 0, math.sin(a)) * g.coreFloorRadiusStuds
	layout.cores[1] = Vector3.new(floorCore.X, st.floorY, floorCore.Z)
	layout.cores[2] = layout.platforms[rng:NextInteger(1, #layout.platforms)] + Vector3.new(0, g.platformSize.Y / 2, 0)
	return layout
end

local function newGardenPart(name, size, cframe, color, material, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function clearGarden(model)
	local g = gardens[model]
	gardens[model] = nil
	if not g then
		return
	end
	for _, part in ipairs(g.parts) do
		part:Destroy()
	end
	for _, core in ipairs(g.cores) do
		MonsterSpawner.removeRescueTarget(core)
	end
end

local function buildGarden(model, st, data, env, layout)
	clearGarden(model)
	local spec = env.garden
	local g = { parts = {}, cores = {}, lastHit = {}, solved = false }
	gardens[model] = g
	for _, p in ipairs(layout.platforms) do
		local platform = newGardenPart("GardenPlatform", spec.platformSize, CFrame.new(p), spec.color, Enum.Material.Glass, GroundProbe.folder())
		table.insert(g.parts, platform)
	end
	for _, p in ipairs(layout.pads) do
		local pad = newGardenPart("GardenJumpPad", Vector3.new(spec.padSizeStuds, 0.4, spec.padSizeStuds), CFrame.new(p + Vector3.new(0, 0.2, 0)), spec.padColor, Enum.Material.Neon, GroundProbe.folder())
		pad:SetAttribute("LaunchHeight", spec.padLaunchHeightStuds)
		CollectionService:AddTag(pad, "BossJumpPad")
		table.insert(g.parts, pad)
	end
	for index, p in ipairs(layout.cores) do
		g.cores[index] = MonsterSpawner.spawnRescueTarget({
			displayName = "수정 핵",
			color = spec.color,
			bodyAspect = Vector3.new(1.2, 1.4, 1.2),
			footPosition = p,
			onHit = function()
				if g.solved or gardens[model] ~= g then
					return
				end
				g.lastHit[index] = os.clock()
				local other = g.lastHit[3 - index]
				kit.send(st, "gardenCoreHit", { index = index, windowSeconds = spec.coreWindowSeconds })
				if other and os.clock() - other <= spec.coreWindowSeconds then
					g.solved = true
				end
			end,
			remaining = function()
				return g.lastHit[index] and 0 or 1
			end,
		}, MonsterState.getZoneKey(model))
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
	e.zones = placeZones(model, st, data, env)
	e.taken = {}
	e.usedImpossible = false
	e.activation = (e.activation or 0) + 1
	e.garden = env.kind == "cores" and gardenLayout(model, st, env) or nil
	print(("[forge-game] 환경 변화 전조: %s - 구역 %d개, %.1f초"):format(env.id, #e.zones, env.telegraphSeconds))
	kit.send(st, "envTelegraph", { id = env.id, style = env.style, zones = e.zones, seconds = env.telegraphSeconds, bossId = data.id, motion = env.motion, garden = e.garden })
end

local function activate(model, st, data, env, e, now)
	e.phase = "active"
	e.phaseEndsAt = now + env.durationSeconds
	e.lastTickAt = {}
	e.windTurnAt = now + (env.zones.rotateEverySeconds or math.huge)
	-- 활성 순간 효과(onStart - 밥상뒤집기의 튕김 + 피해): 구역 안(발 기준 같은 층 - 떠 있으면 안 맞는다)의 사람.
	local onStart = env.onStart
	if onStart then
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
		buildGarden(model, st, data, env, e.garden)
	end
	print(("[forge-game] 환경 변화 시작: %s - %.1f초"):format(env.id, env.durationSeconds))
	kit.send(st, "envStart", { id = env.id, style = env.style, zones = e.zones, seconds = env.durationSeconds, bossId = data.id, garden = e.garden })
end

local function finish(model, st, env, e, now)
	e.phase = "cooldown"
	e.phaseEndsAt = now + env.cooldownSeconds
	e.zones = nil
	e.garden = nil
	clearGarden(model)
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
	if e.phase == "armed" or e.phase == "cooldown" then
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
	-- 수정 공중 정원: 두 핵을 창 안에 쳤으면 성공(보스 기절 · 정원 무너짐) · 시간을 넘기면 수정 폭풍(기믹 실패 - 85% · 쉴드 무시)
	local g = gardens[model]
	if g and g.solved then
		print(("[forge-game] 수정 공중 정원 파훼 → 보스 기절 %.1f초"):format(env.garden.stunSeconds))
		kit.send(st, "gimmickResolve", { broken = true, windowSeconds = env.garden.stunSeconds })
		kit.stun(model, st, data, env.garden.stunSeconds)
		finish(model, st, env, e, now)
		return
	end
	if now >= e.phaseEndsAt then
		if g then
			local fail = BossData.mechanics.gimmickFail
			for _, v in ipairs(kit.victims(st)) do
				if not BossTrap.isTrapped(v.player) then
					PlayerDamage.applyMaxHpFraction(v.player, fail.maxHpFraction, env.damageLabel, { ignoresShield = fail.ignoresShield })
				end
			end
			kit.send(st, "gimmickResolve", { broken = false })
			print("[forge-game] 수정 공중 정원 실패 → 수정 폭풍")
		end
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
		st.env = nil
	end
	clearGarden(model)
end

-- 보스전 종료(처치 · 이탈): 수정 공중 정원의 파트(발판 · 점프대 · 핵)를 치운다 - 구역은 논리뿐이라 남는 것이 없다.
function BossEnvironment.clear(model)
	clearGarden(model)
end

-- 자동 검증 전용: 지금 이 보스의 정원 파트 수(발판 + 점프대) · 핵 수
function BossEnvironment.debugGarden(model)
	local g = gardens[model]
	return g and #g.parts or 0, g and #g.cores or 0
end

function BossEnvironment.register(patternKit)
	kit = patternKit
	task.defer(BossOverlap.warm) -- 겹침 분류표를 서버 시작 때 채운다(첫 환경 발동 틱이 튀지 않게)
end

-- 자동 검증 · 하네스 전용
BossEnvironment.debug = { placeZones = function(...) return placeZones(...) end }

return BossEnvironment
