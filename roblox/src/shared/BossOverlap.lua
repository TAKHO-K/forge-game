-- BR1 겹침 분류(docs/design/boss-br1.md §4-3) - 순수 계산. "환경 변화가 도는 동안 이 패턴을 피할 수 있는가"를 보스마다 패턴마다 한 번 잰다.
--   방법: trials번 무작위 배치(자체 난수 - 서버 · 하네스가 같은 값) - 환경 구역을 깔고(BossEnvironment와 같은 모양), 플레이어를 환경의 안전한 곳에 세우고,
--   보스를 아레나 중심(또는 플레이어 곁 standoff)에 둔 뒤 패턴의 위험 모양을 그 자리에 놓는다. 탈출 = 패턴 밖 · 환경 위험 밖 · 아레나 안인 가장 가까운 점
--   (directions 방위 × stepStuds 간격, 최대 maxStuds). 이동 속도 = 걷기 − 환경의 힘(끌림 · 바람 - 나쁜 쪽으로). 필요 시간 = 인지 + 거리 ÷ 속도 × 여유.
--   분류: 분위(percentile)의 필요 시간이 전조 이하 - 여유 1.25(회피 부등식) = dodgeable · 여유 1.0 = hard · 둘 다 아니면 공중으로 피할 수 있는 바닥
--   판정이면 hard(공중만), 아니면 impossible.
-- 서버(BossEnvironment.shouldDefer)가 classOf로 읽고, 자동 검증 · 하네스가 classify 표를 보고서에 싣는다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossSkillMath = require(ReplicatedStorage.Shared.BossSkillMath)
local BossArenaMapData = require(ReplicatedStorage.Shared.data.BossArenaMapData)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)

local BossOverlap = {}

local ARENA_RADIUS = BossArenaMapData.geometry.radiusStuds

local function newRng(seed)
	local state = seed % 2147483648
	return function()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
end

local function v2(x, z)
	return { x = x, z = z }
end

local function len(x, z)
	return math.sqrt(x * x + z * z)
end

-- ── 환경 구역(서버 BossEnvironment.insideHazard와 같은 정의 - 2D) ──
local function envZones(env, rng, player)
	local spec = env.zones
	local list = {}
	if spec.shape == "circle" then
		-- 멤버 발밑(솔로 = 플레이어 자리 - 플레이어는 거기서 벗어난 뒤다) + extra개 무작위
		local count = (spec.perMember and 1 or 0) + (spec.extra or 0)
		for i = 1, count do
			local a, d = rng() * 2 * math.pi, rng() * (ARENA_RADIUS - spec.radiusStuds)
			table.insert(list, { shape = "circle", x = math.cos(a) * d, z = math.sin(a) * d, radius = spec.radiusStuds })
		end
	elseif spec.shape == "ring" then
		table.insert(list, { shape = "ring", x = 0, z = 0, beyond = spec.beyondStuds })
	elseif spec.shape == "rect" and spec.halfMap then
		-- BR1-2 맵 절반 판(급류 도트가 아레나 반쪽): 무작위 방위의 반쪽 - 서버 BossEnvironment.placeZones와 같은 모양
		local a = rng() * 2 * math.pi
		local sx, sz = -math.sin(a), math.cos(a)
		table.insert(list, { shape = "rect", x = sx * ARENA_RADIUS / 2, z = sz * ARENA_RADIUS / 2, angle = a, halfLength = ARENA_RADIUS, halfWidth = ARENA_RADIUS / 2 })
	elseif spec.shape == "rect" then
		local a = rng() * 2 * math.pi
		table.insert(list, { shape = "rect", x = player.x + math.cos(a) * 25, z = player.z + math.sin(a) * 25, angle = rng() * 2 * math.pi, halfLength = spec.halfLengthStuds, halfWidth = spec.halfWidthStuds })
	elseif spec.shape == "pit" and (spec.perMember or spec.extra) then
		-- BR1-2 여러 구덩이: 내 발밑에 생겼던 것(전조 동안 막 빠져나왔다 - 테두리 곁) + 무작위 extra개
		local a = rng() * 2 * math.pi
		table.insert(list, { shape = "pit", x = player.x + math.cos(a) * (spec.radiusStuds + 2), z = player.z + math.sin(a) * (spec.radiusStuds + 2), radius = spec.radiusStuds, core = spec.coreRadiusStuds, pull = spec.pullStudsPerSecond })
		for _ = 1, spec.extra or 0 do
			local b, d = rng() * 2 * math.pi, rng() * (ARENA_RADIUS - spec.radiusStuds)
			table.insert(list, { shape = "pit", x = math.cos(b) * d, z = math.sin(b) * d, radius = spec.radiusStuds, core = spec.coreRadiusStuds, pull = spec.pullStudsPerSecond })
		end
	elseif spec.shape == "pit" then
		table.insert(list, { shape = "pit", x = 0, z = 0, radius = spec.radiusStuds, core = spec.coreRadiusStuds, pull = spec.pullStudsPerSecond })
	elseif spec.shape == "wind" then
		table.insert(list, { shape = "wind", x = 0, z = 0, angle = rng() * 2 * math.pi, beyond = spec.beyondStuds, push = spec.pushStudsPerSecond })
	end
	return list
end

local function inEnvHazard(zones, x, z)
	for _, e in ipairs(zones) do
		local rx, rz = x - e.x, z - e.z
		local d = len(rx, rz)
		if e.shape == "circle" and d <= e.radius then
			return true
		elseif e.shape == "ring" and d >= e.beyond then
			return true
		elseif e.shape == "pit" and d <= e.core then
			return true
		elseif e.shape == "rect" then
			local ax, az = math.cos(e.angle), math.sin(e.angle)
			if math.abs(rx * ax + rz * az) <= e.halfLength and math.abs(-rx * az + rz * ax) <= e.halfWidth then
				return true
			end
		elseif e.shape == "wind" and d >= e.beyond and (rx * math.cos(e.angle) + rz * math.sin(e.angle)) > 0 then
			return true
		end
	end
	return false
end

-- 환경이 걷기를 늦추는 몫(나쁜 쪽 - 끌림 반경 안이거나 바람이면 그 힘만큼).
local function envDrag(zones, x, z)
	local drag = 0
	for _, e in ipairs(zones) do
		if e.shape == "pit" and len(x - e.x, z - e.z) <= e.radius then
			drag = math.max(drag, e.pull)
		elseif e.shape == "wind" then
			drag = math.max(drag, e.push)
		end
	end
	return drag
end

-- ── 패턴 위험 모양(2D) - 보스 b · 대상 p ──
-- 반환: hazard(x, z) → bool, available(전조 초), groundJudged(공중으로 피할 수 있는 바닥 판정인가), kind("walk" / "jump" / "land" / "outrun")
local function patternShape(skill, boss, player, zoneRadius)
	local primitive = skill.primitive
	local toward = { x = player.x - boss.x, z = player.z - boss.z }
	local tl = len(toward.x, toward.z)
	local dirx, dirz = tl > 1e-3 and toward.x / tl or 1, tl > 1e-3 and toward.z / tl or 0
	if primitive == "circleBoss" then
		local pulse = BossSkillMath.pulsesOf(skill)[1]
		local inner, outer = pulse.innerRadiusStuds or 0, pulse.radiusStuds
		return function(x, z)
			local d = len(x - boss.x, z - boss.z)
			return d <= outer and d >= inner
		end, skill.telegraphSeconds, true, "walk"
	elseif primitive == "sector" then
		local volley = BossSkillMath.volleysOf(skill)[1]
		local radius = volley.radiusStuds or zoneRadius
		local halfAngle = math.rad(volley.angleDeg / 2)
		local cx, cz = dirx, dirz
		if skill.facing == "randomSide" then
			cx, cz = -dirz, dirx -- 한쪽 반(분류는 대상이 그 반에 있는 나쁜 쪽)
			if (player.x - boss.x) * cx + (player.z - boss.z) * cz < 0 then
				cx, cz = -cx, -cz
			end
		end
		return function(x, z)
			local rx, rz = x - boss.x, z - boss.z
			local d = len(rx, rz)
			if d > radius or d < (skill.innerRadiusStuds or 0) then
				return false
			end
			if d < 1e-3 then
				return true
			end
			return math.acos(math.clamp((rx * cx + rz * cz) / d, -1, 1)) <= halfAngle
		end, volley.telegraphSeconds, true, skill.jumpable and "jump" or "walk"
	elseif primitive == "circleTarget" then
		local radius = skill.shots and BossSkillMath.shotsOf(skill)[1].radiusStuds or skill.radiusStuds
		local available = skill.shots and BossSkillMath.shotsOf(skill)[1].telegraphSeconds or (skill.ambush and skill.ambush.lockTelegraphSeconds) or skill.telegraphSeconds
		if skill.chain then
			return function(x, z)
				local rx, rz = x - boss.x, z - boss.z
				local along = rx * dirx + rz * dirz
				return along >= 0 and math.abs(-rx * dirz + rz * dirx) <= radius
			end, skill.telegraphSeconds, true, "walk"
		end
		return function(x, z)
			return len(x - player.x, z - player.z) <= radius
		end, available, true, "walk"
	elseif primitive == "line" then
		local half = BossSkillMath.volleysOf(skill)[1].halfWidthStuds
		local dirs = {}
		local spread = skill.centered and skill.stepDeg * ((skill.directions or 1) - 1) / 2 or 0
		local base = math.atan2(dirz, dirx) - math.rad(spread)
		for k = 0, (skill.directions or 1) - 1 do
			local a = base + math.rad(skill.stepDeg * k)
			table.insert(dirs, { math.cos(a), math.sin(a) })
		end
		return function(x, z)
			local rx, rz = x - boss.x, z - boss.z
			for _, d in ipairs(dirs) do
				local along = rx * d[1] + rz * d[2]
				if along >= 0 and math.abs(-rx * d[2] + rz * d[1]) <= half then
					return true
				end
			end
			return false
		end, BossSkillMath.volleysOf(skill)[1].telegraphSeconds, true, "walk"
	elseif primitive == "charge" then
		local half = skill.pathHalfWidthStuds
		return function(x, z)
			local rx, rz = x - boss.x, z - boss.z
			local along = rx * dirx + rz * dirz
			return along >= 0 and math.abs(-rx * dirz + rz * dirx) <= half
		end, skill.telegraphSeconds, true, "walk"
	elseif primitive == "projectile" then
		if skill.heightMode == "ground" then
			return function(x, z)
				local rx, rz = x - boss.x, z - boss.z
				local along = rx * dirx + rz * dirz
				return along >= 0 and math.abs(-rx * dirz + rz * dirx) <= skill.radiusStuds
			end, skill.telegraphSeconds + tl / skill.speedStuds, true, "walk"
		end
		return nil, skill.telegraphSeconds, false, "outrun"
	elseif primitive == "vortex" then
		return function(x, z)
			return len(x - boss.x, z - boss.z) <= skill.radiusStuds
		end, skill.telegraphSeconds, false, "vortex"
	elseif primitive == "ring" then
		return nil, skill.telegraphSeconds, false, "jump"
	elseif primitive == "grab" then
		return nil, skill.telegraphSeconds, false, "land"
	elseif primitive == "gimmick" then
		return nil, skill.telegraphSeconds, false, "gimmick"
	elseif primitive == "lightningRods" or primitive == "colorMatch" or primitive == "sonic" then
		-- BR1-2 전멸기: 안전 자리(피뢰침 · 같은 색 발판 · 엄폐물)까지 걷기 - 쓸 수 있는 시간 = 번개 조준경은 표적 뒤 조준경이 멈추기까지
		local available = primitive == "lightningRods" and (skill.markSeconds + skill.trackSeconds) or skill.telegraphSeconds
		return nil, available, false, "gimmick"
	end
	return nil, skill.telegraphSeconds, false, "jump"
end

local function percentile(list, p)
	table.sort(list)
	if #list == 0 then
		return 0
	end
	return list[math.clamp(math.ceil(#list * p), 1, #list)]
end

-- 한 보스의 분류 표: { [skillId] = { class = "dodgeable"/"hard"/"impossible", need125, need100, available, kind } }. 환경이 없으면 nil.
function BossOverlap.classify(bossId)
	local boss = BossData.bosses[bossId]
	local env = boss and boss.environment
	if not env then
		return nil
	end
	local mechanics = BossData.mechanics
	local check = mechanics.environment.overlap.check
	local dodge = mechanics.dodge
	local walk = WorldConfig.playerWalkSpeedStuds
	local result = {}
	for _, skillId in ipairs(boss.skillOrder) do
		local skill = boss.skills[skillId]
		if skill and skill.enabled ~= false then
			local rng = newRng(check.seed + #skillId * 131)
			local needs125, needs100 = {}, {}
			local available, groundJudged, kind = skill.telegraphSeconds, false, "jump"
			for _ = 1, check.trials do
				-- 플레이어: 환경 안전한 곳의 무작위 자리
				local player
				local zones
				for _ = 1, 40 do
					local a, d = rng() * 2 * math.pi, math.sqrt(rng()) * (ARENA_RADIUS - 6)
					player = v2(math.cos(a) * d, math.sin(a) * d)
					zones = envZones(env, rng, player)
					if not inEnvHazard(zones, player.x, player.z) then
						break
					end
				end
				-- 보스: 근접 거리(standoff)에서 대상 쪽 - 원거리 패턴도 보스 곁이 나쁜 쪽이다
				local a = rng() * 2 * math.pi
				local boss2 = v2(player.x + math.cos(a) * check.standoffStuds, player.z + math.sin(a) * check.standoffStuds)
				local hazard, avail, ground, k = patternShape(skill, boss2, player, ARENA_RADIUS)
				available, groundJudged, kind = avail, ground, k
				local drag = envDrag(zones, player.x, player.z)
				local speed = math.max(walk - drag, 0.5)
				local d = 0
				if kind == "vortex" then
					speed = math.max(walk - drag - skill.pullStudsPerSecond, 0.5)
					d = skill.radiusStuds - len(player.x - boss2.x, player.z - boss2.z) + dodge.characterHalfWidthStuds
				elseif kind == "outrun" then
					-- 땅에서 걸어 따돌린다: 속도가 투사체보다 느려지면(환경 힘) 못 따돌린다 → 궤도 바꾸기(공중) 필요 = hard
					d = (speed <= skill.speedStuds) and math.huge or 0
				elseif kind == "gimmick" then
					d = (skill.dodge and skill.dodge.distanceStuds or 0)
				elseif hazard then
					d = math.huge
					if not hazard(player.x, player.z) then
						d = 0
					else
						for step = check.stepStuds, check.maxStuds, check.stepStuds do
							local found = false
							for k2 = 0, check.directions - 1 do
								local ang = k2 / check.directions * 2 * math.pi
								local x, z = player.x + math.cos(ang) * step, player.z + math.sin(ang) * step
								if len(x, z) <= ARENA_RADIUS - 1 and not hazard(x, z) and not inEnvHazard(zones, x, z) then
									found = true
									break
								end
							end
							if found then
								d = step + dodge.characterHalfWidthStuds
								break
							end
						end
					end
				end
				table.insert(needs125, dodge.perceptionSeconds + d / speed * dodge.marginFactor)
				table.insert(needs100, dodge.perceptionSeconds + d / speed)
			end
			local n125, n100 = percentile(needs125, check.percentile), percentile(needs100, check.percentile)
			local class
			if kind == "jump" or kind == "land" then
				class = "dodgeable" -- 점프 · 착지로 피한다(환경은 땅의 자리만 막는다 - 안전한 곳에 서 있다)
			elseif n125 <= available then
				class = "dodgeable"
			elseif n100 <= available then
				class = "hard"
			elseif (groundJudged and available >= dodge.perceptionSeconds + check.airRiseSeconds) or kind == "outrun" then
				class = "hard" -- 걸어서는 못 피하고 공중으로만(공중 점프 1회 - 발 13.3 > 판정 층 8)
			else
				class = "impossible"
			end
			result[skillId] = { class = class, need125 = n125, need100 = n100, available = available, kind = kind }
		end
	end
	return result
end

local cache = {}

function BossOverlap.classOf(bossId, skillId)
	local table_ = cache[bossId]
	if table_ == nil then
		table_ = BossOverlap.classify(bossId) or false
		cache[bossId] = table_
	end
	local entry = table_ and table_[skillId]
	return entry and entry.class or "dodgeable"
end

-- 서버 시작 때 미리 채운다(처음 쓰는 틱이 튀지 않게).
function BossOverlap.warm()
	for bossId in pairs(BossData.bosses) do
		BossOverlap.classOf(bossId, "")
	end
end

return BossOverlap
