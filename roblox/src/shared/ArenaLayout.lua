-- P3c B1 보스맵 무작위 배치(순수 함수 - 서버 BossArenaMap과 검증이 같은 함수를 쓴다). 규칙 · 수치 = BossArenaMapData.layout 주석.
-- 좌표는 전부 아레나 중심 기준 XZ 오프셋(숫자 x · z) - Vector3에 기대지 않아 하네스에서도 그대로 돈다.
--   generate(theme, seed, options)   시드 하나 → 구조물 목록(items) + 둔덕(mounds) + 검사 결과. 같은 시드 = 같은 배치(전멸 리셋 때 처음대로 다시 선다).
--   validate(layout, options)        벽 · 서로 · 중심 · 킷 · 입장 방위 · 연결(갇힘) · 돌진 보장 - 검증(P3c(가) 100시드)과 generate의 재시도 판정이 같이 쓴다.
--   firstOnPath(obstacles, …)        돌진 경로에 처음 걸리는 구조물(충돌 원 단위) - BossArenaMap.firstOnPath가 부른다.
--   kitFootprints(arenaKit)          보스 킷(발판 · 웅덩이 · 피뢰침 · 폐허 기둥)의 발자국 원 - 구조물 · 둔덕이 피한다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossArenaMapData = require(ReplicatedStorage.Shared.data.BossArenaMapData)

local LAYOUT = BossArenaMapData.layout
local OBSTACLE = BossArenaMapData.obstacle
local SHAPES = BossArenaMapData.featureShapes
local GEOMETRY = BossArenaMapData.geometry

local ArenaLayout = {}

local function newRng(seed)
	local state = math.floor(math.abs(seed or 1)) % 2147483648
	return function(lo, hi)
		state = (state * 1103515245 + 12345) % 2147483648
		local u = state / 2147483648
		if lo then
			return lo + (hi - lo) * u
		end
		return u
	end
end

local function angleDiffDeg(a, b)
	local d = (a - b) % 360
	return d > 180 and 360 - d or d
end

function ArenaLayout.kitFootprints(arenaKit)
	local list = {}
	for _, part in ipairs(arenaKit and arenaKit.parts or {}) do
		local r = part.radiusStuds or math.sqrt((part.size.X / 2) ^ 2 + (part.size.Z / 2) ^ 2)
		if part.shape == "cylinder" then
			r = part.size.Y / 2
		end
		table.insert(list, { x = part.offset.X, z = part.offset.Z, r = r })
	end
	return list
end

-- 한 구조물의 충돌 원 목록(아레나 기준 x · z). big · small = 원 하나, feature = featureShapes의 원들을 rotation만큼 돌린다.
local function collidersFor(group, kind, x, z, radius, rotationDeg)
	if group == "big" then
		return { { x = x, z = z, r = radius, h = OBSTACLE.climbHeightStuds, tall = false } }
	elseif group == "small" then
		return { { x = x, z = z, r = radius, h = OBSTACLE.heightStuds, tall = false } }
	end
	local shape = SHAPES[kind]
	local c, s = math.cos(math.rad(rotationDeg)), math.sin(math.rad(rotationDeg))
	local list = {}
	for _, spec in ipairs(shape.colliders) do
		local ox, oz = spec[1] * c - spec[2] * s, spec[1] * s + spec[2] * c
		table.insert(list, { x = x + ox, z = z + oz, r = spec[3], h = spec[4], tall = spec[5] == true })
	end
	return list
end

-- options = { radius, kit(kitFootprints), entryAngleDeg, entryDistanceStuds, coverageMin(돌진 보장 - 돌진 스킬이 없는 보스는 0) }
local function defaults(options)
	options = options or {}
	return {
		radius = options.radius or GEOMETRY.radiusStuds,
		kit = options.kit or {},
		entryAngleDeg = options.entryAngleDeg or GEOMETRY.entryAngleDeg,
		entryDistanceStuds = options.entryDistanceStuds or GEOMETRY.entryDistanceStuds,
		coverageMin = options.coverageMin or 0,
		-- G1-0(P3d-F 결정 3): 선택 - 긴 계산(연결 검사 · 재생성 자리 시도) 도중 자주 부르는 함수. 서버는 프레임 예산을 넘기면 여기서 다음 프레임으로 양보한다
		-- (BossArenaMap.planRegrow). 하네스 · 검사처럼 없으면 한 번에 끝까지 돈다.
		checkpoint = options.checkpoint,
	}
end

-- 보스 데이터 → 배치 옵션. 돌진 보장(chargeCoverageMin)은 돌진(charge) 스킬이 있는 보스에만 건다 - 돌진이 없는 보스(서리 거인 · 심해 군주 · 수정 여왕 · 폭풍 군주)에게는
-- 뜻이 없고, 심해 군주는 발판 11곳이 자리를 차지해 30%를 채울 수 없다(하네스 100시드 평균 19%).
function ArenaLayout.optionsFor(bossData)
	local hasCharge = false
	for _, skill in pairs(bossData and bossData.skills or {}) do
		hasCharge = hasCharge or skill.primitive == "charge"
	end
	return { kit = ArenaLayout.kitFootprints(bossData and bossData.arenaKit), coverageMin = hasCharge and LAYOUT.chargeCoverageMin or 0 }
end

-- 중심에서 무작위 방향으로 돌진할 때 구조물(충돌 원 + 보스 몸통 반폭)을 지나는 방위의 몫(0 ~ 1).
function ArenaLayout.chargeCoverage(items, bodyHalf)
	local intervals = {}
	for _, item in ipairs(items) do
		for _, c in ipairs(item.colliders) do
			local d = math.sqrt(c.x * c.x + c.z * c.z)
			local reach = c.r + (bodyHalf or OBSTACLE.chargeBodyHalfStuds)
			if d > reach then
				local center = math.deg(math.atan2(c.z, c.x))
				local half = math.deg(math.asin(reach / d))
				table.insert(intervals, { center - half, center + half })
			end
		end
	end
	-- 0 ~ 360으로 펼쳐 합집합 길이를 잰다(360도 넘어가는 구간은 둘로 자른다).
	local pieces = {}
	for _, iv in ipairs(intervals) do
		local a, b = iv[1] % 360, iv[1] % 360 + (iv[2] - iv[1])
		if b > 360 then
			table.insert(pieces, { a, 360 })
			table.insert(pieces, { 0, b - 360 })
		else
			table.insert(pieces, { a, b })
		end
	end
	table.sort(pieces, function(p, q)
		return p[1] < q[1]
	end)
	local covered, curA, curB = 0, nil, nil
	for _, p in ipairs(pieces) do
		if not curA then
			curA, curB = p[1], p[2]
		elseif p[1] <= curB then
			curB = math.max(curB, p[2])
		else
			covered += curB - curA
			curA, curB = p[1], p[2]
		end
	end
	if curA then
		covered += curB - curA
	end
	return covered / 360
end

local STEPS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } -- 리뷰 4: 칸마다 표를 새로 만들지 않는다

-- 갇힘 검사: 칸 격자에서 입장 자리부터 퍼져 나가 원 안(몸 반폭 1 여유)의 빈 칸이 전부 닿는가. 빈 칸 = 어느 충돌 원 + 1 안도 아니다(큰 블록도 막힌 것으로 본다 - 보수적).
-- 반환: 전부 닿는가, 빈 칸 수, 닿은 칸 수.
function ArenaLayout.connectivity(items, options)
	local o = defaults(options)
	local cell = LAYOUT.connectCellStuds
	local n = math.ceil(o.radius / cell)
	local limit = o.radius - 1
	local free = {}
	local function key(i, j)
		return i * 4096 + j
	end
	local count = 0
	local checkpoint = o.checkpoint
	for i = -n, n do
		if checkpoint then
			checkpoint()
		end
		for j = -n, n do
			local x, z = i * cell, j * cell
			if x * x + z * z <= limit * limit then
				free[key(i, j)] = true
				count += 1
			end
		end
	end
	local total = count -- P3d-F B4: 구조물 없는 아레나의 칸 수(이동 가능 면적 비율 = 남은 칸 ÷ total)
	for _, item in ipairs(items) do
		if checkpoint then
			checkpoint()
		end
		for _, c in ipairs(item.colliders) do
			local reach = c.r + 1
			for i = math.floor((c.x - reach) / cell), math.ceil((c.x + reach) / cell) do
				for j = math.floor((c.z - reach) / cell), math.ceil((c.z + reach) / cell) do
					local dx, dz = i * cell - c.x, j * cell - c.z
					if dx * dx + dz * dz < reach * reach and free[key(i, j)] then
						free[key(i, j)] = nil
						count -= 1
					end
				end
			end
		end
	end
	local ex = math.cos(math.rad(o.entryAngleDeg)) * o.entryDistanceStuds
	local ez = math.sin(math.rad(o.entryAngleDeg)) * o.entryDistanceStuds
	local si, sj = math.floor(ex / cell + 0.5), math.floor(ez / cell + 0.5)
	if not free[key(si, sj)] then
		return false, count, 0, total
	end
	-- 큐 = 칸 키(숫자) 배열(리뷰 4 - 칸마다 표를 만들던 것을 숫자로). key = i × 4096 + j → i · j를 되돌린다(j는 음수일 수 있다).
	local start = key(si, sj)
	local seen, queue, head, tail, reached = { [start] = true }, { start }, 1, 1, 0
	while head <= tail do
		local k0 = queue[head]
		head += 1
		reached += 1
		if checkpoint and head % 128 == 0 then
			checkpoint()
		end
		local i0 = math.floor((k0 + 2048) / 4096)
		local j0 = k0 - i0 * 4096
		for _, step in ipairs(STEPS) do
			local k = key(i0 + step[1], j0 + step[2])
			if free[k] and not seen[k] then
				seen[k] = true
				tail += 1
				queue[tail] = k
			end
		end
	end
	return reached == count, count, reached, total
end

-- 배치 검사(검증과 재시도 판정이 같이 쓴다). 반환 = report { ok, minWallGap, minPairGap, minCenter, minKitGap, entryViolations, connected, freeCells, reached, coverage, count }.
function ArenaLayout.validate(layout, options)
	local o = defaults(options)
	local items = layout.items
	local report = { minWallGap = math.huge, minPairGap = math.huge, minCenter = math.huge, minKitGap = math.huge, entryViolations = 0, count = #items }
	for index, item in ipairs(items) do
		local d = math.sqrt(item.x * item.x + item.z * item.z)
		for _, c in ipairs(item.colliders) do
			local dc = math.sqrt(c.x * c.x + c.z * c.z)
			report.minWallGap = math.min(report.minWallGap, o.radius - (dc + c.r))
			report.minCenter = math.min(report.minCenter, dc - c.r)
		end
		if angleDiffDeg(math.deg(math.atan2(item.z, item.x)), o.entryAngleDeg) < LAYOUT.entryClearDeg then
			report.entryViolations += 1
		end
		for other = index + 1, #items do
			local b = items[other]
			report.minPairGap = math.min(report.minPairGap, math.sqrt((item.x - b.x) ^ 2 + (item.z - b.z) ^ 2) - item.radius - b.radius)
		end
		for _, kit in ipairs(o.kit) do
			report.minKitGap = math.min(report.minKitGap, math.sqrt((item.x - kit.x) ^ 2 + (item.z - kit.z) ^ 2) - item.radius - kit.r)
		end
		report.minCenter = math.min(report.minCenter, d - item.radius)
	end
	report.coverage = ArenaLayout.chargeCoverage(items)
	-- 리뷰 4: 연결 검사(격자 BFS)가 가장 비싸다 - 싼 검사가 이미 실패했으면 건너뛴다(options.forceConnectivity = 검증이 늘 잰다).
	local cheapOk = report.minWallGap >= LAYOUT.wallGapStuds - 1e-6 and report.minPairGap >= LAYOUT.minGapStuds - 1e-6
		and report.minCenter >= LAYOUT.centerClearStuds - 1e-6 and report.minKitGap >= LAYOUT.kitGapStuds - 1e-6
		and report.entryViolations == 0 and report.coverage >= o.coverageMin - 1e-9
	if cheapOk or (options and options.forceConnectivity) then
		report.connected, report.freeCells, report.reached = ArenaLayout.connectivity(items, o)
	else
		report.connected, report.freeCells, report.reached = false, 0, 0
	end
	report.ok = report.minWallGap >= LAYOUT.wallGapStuds - 1e-6 and report.minPairGap >= LAYOUT.minGapStuds - 1e-6
		and report.minCenter >= LAYOUT.centerClearStuds - 1e-6 and report.minKitGap >= LAYOUT.kitGapStuds - 1e-6
		and report.entryViolations == 0 and report.connected and report.coverage >= o.coverageMin - 1e-9
	return report
end

-- 한 번 뽑기(재시도 없이). 반환: layout { items, mounds }.
local function drawOnce(theme, rng, o)
	local items, mounds = {}, {}
	local nextId = 0
	local groups = { big = 1, small = 2, feature = 3 }
	local specs = table.clone(theme.layout or {})
	table.sort(specs, function(a, b)
		return (groups[a.group] or 9) < (groups[b.group] or 9)
	end)
	for _, spec in ipairs(specs) do
		local count = spec.count[1] + math.floor(rng() * (spec.count[2] - spec.count[1] + 1))
		for _ = 1, count do
			local radius = spec.group == "feature" and SHAPES[spec.kind].footprint or rng(spec.radius[1], spec.radius[2])
			local rMin = LAYOUT.centerClearStuds + radius
			local rMax = o.radius - LAYOUT.wallGapStuds - radius
			for _ = 1, LAYOUT.tries do
				local d = math.sqrt(rng(rMin * rMin, rMax * rMax))
				local angle = rng(0, 360)
				if angleDiffDeg(angle, o.entryAngleDeg) >= LAYOUT.entryClearDeg then
					local x, z = math.cos(math.rad(angle)) * d, math.sin(math.rad(angle)) * d
					local clear = true
					for _, other in ipairs(items) do
						clear = clear and math.sqrt((x - other.x) ^ 2 + (z - other.z) ^ 2) - radius - other.radius >= LAYOUT.minGapStuds
					end
					for _, kit in ipairs(o.kit) do
						clear = clear and math.sqrt((x - kit.x) ^ 2 + (z - kit.z) ^ 2) - radius - kit.r >= LAYOUT.kitGapStuds
					end
					if clear then
						nextId += 1
						local rotation = rng(0, 360)
						table.insert(items, {
							id = nextId, kind = spec.kind, group = spec.group, x = x, z = z, radius = radius, rotationDeg = rotation,
							colliders = collidersFor(spec.group, spec.kind, x, z, radius, rotation), spec = spec,
							climbable = spec.group == "big",
						})
						break
					end
				end
			end
		end
	end
	-- 둔덕(B4): 구조물 · 킷 · 중심 · 입장 자리를 피한다.
	local m = LAYOUT.mounds
	local moundCount = m.count[1] + math.floor(rng() * (m.count[2] - m.count[1] + 1))
	local ex = math.cos(math.rad(o.entryAngleDeg)) * o.entryDistanceStuds
	local ez = math.sin(math.rad(o.entryAngleDeg)) * o.entryDistanceStuds
	for _ = 1, moundCount do
		local radius = rng(m.radiusStuds[1], m.radiusStuds[2])
		for _ = 1, LAYOUT.tries do
			local d = math.sqrt(rng((LAYOUT.centerClearStuds + radius) ^ 2, (o.radius - 8 - radius) ^ 2))
			local angle = rng(0, 360)
			local x, z = math.cos(math.rad(angle)) * d, math.sin(math.rad(angle)) * d
			local clear = math.sqrt((x - ex) ^ 2 + (z - ez) ^ 2) >= radius + 6
			for _, item in ipairs(items) do
				clear = clear and math.sqrt((x - item.x) ^ 2 + (z - item.z) ^ 2) - radius - item.radius >= m.gapStuds
			end
			for _, kit in ipairs(o.kit) do
				clear = clear and math.sqrt((x - kit.x) ^ 2 + (z - kit.z) ^ 2) - radius - kit.r >= LAYOUT.kitGapStuds
			end
			for _, other in ipairs(mounds) do
				clear = clear and math.sqrt((x - other.x) ^ 2 + (z - other.z) ^ 2) - radius - other.radius >= m.gapStuds
			end
			if clear then
				table.insert(mounds, { x = x, z = z, radius = radius, layers = math.floor(m.maxHeightStuds / m.stepStuds + 1e-6), stepStuds = m.stepStuds })
				break
			end
		end
	end
	return { items = items, mounds = mounds }
end

-- 시드 하나 → 배치. 검사를 통과할 때까지 retries번 다시 뽑는다(같은 시드 안의 난수를 이어 쓴다 - 결과는 시드만의 함수다).
function ArenaLayout.generate(theme, seed, options)
	local o = defaults(options)
	local rng = newRng(seed)
	local best, bestScore, bestReport = nil, -1, nil
	for attempt = 1, LAYOUT.retries do
		local layout = drawOnce(theme, rng, o)
		local report = ArenaLayout.validate(layout, o)
		local expected = 0
		for _, spec in ipairs(theme.layout or {}) do
			expected += spec.count[1]
		end
		local enough = #layout.items >= expected
		if report.ok and enough then
			layout.seed, layout.attempts, layout.report = seed, attempt, report
			return layout
		end
		local score = (report.connected and 4 or 0) + (report.coverage >= o.coverageMin and 2 or 0) + (enough and 1 or 0)
		if score > bestScore then
			best, bestScore, bestReport = layout, score, report
		end
	end
	best.seed, best.attempts, best.report = seed, LAYOUT.retries, bestReport
	return best
end

-- ═══ P3d D · E 재생성 자리(규칙 = BossArenaMapData.regrow 주석) ═══
-- items = 지금 서 있는 구조물({ x, z, radius, colliders = { { x, z, r } } } - 아레나 중심 기준), rng() → [0, 1), nextId = 새 칸 id.
-- options = defaults(반경 · 킷 · 입장) + members = { { x, z } } · boss = { x, z } · pits = { { x, z, r } } · mounds = { { x, z, radius } }.
-- 반환: 새 칸(item - underMember = 멤버 발밑을 노렸는가) 또는 nil, 시도 수, 마지막 실패 이유.
local REGROW = BossArenaMapData.regrow

local function regrowClear(x, z, radius, items, o, options)
	if math.sqrt(x * x + z * z) + radius > o.radius - LAYOUT.wallGapStuds + 1e-6 then
		return false, "wall"
	end
	if angleDiffDeg(math.deg(math.atan2(z, x)), o.entryAngleDeg) < LAYOUT.entryClearDeg then
		return false, "entry"
	end
	for _, other in ipairs(items) do
		if math.sqrt((x - other.x) ^ 2 + (z - other.z) ^ 2) - radius - other.radius < LAYOUT.minGapStuds - 1e-6 then
			return false, "obstacle"
		end
	end
	for _, kit in ipairs(o.kit) do
		if math.sqrt((x - kit.x) ^ 2 + (z - kit.z) ^ 2) - radius - kit.r < LAYOUT.kitGapStuds - 1e-6 then
			return false, "kit"
		end
	end
	local boss = options.boss
	if boss and math.sqrt((x - boss.x) ^ 2 + (z - boss.z) ^ 2) - radius < REGROW.bossClearStuds then
		return false, "boss"
	end
	for _, pit in ipairs(options.pits or {}) do
		if math.sqrt((x - pit.x) ^ 2 + (z - pit.z) ^ 2) - radius - pit.r < REGROW.pitGapStuds then
			return false, "pit"
		end
	end
	for _, mound in ipairs(options.mounds or {}) do
		if math.sqrt((x - mound.x) ^ 2 + (z - mound.z) ^ 2) - radius - mound.radius < LAYOUT.mounds.gapStuds then
			return false, "mound"
		end
	end
	return true, nil
end

-- 솟기 직전 다시 보기(리뷰 6): 이미 고른 칸이 지금도 맞는가(벽 · 입장 · 구조물 · 킷 · 보스 · 동적 지형 · 둔덕 · 연결). 반환: bool, 이유.
function ArenaLayout.regrowFits(item, items, options)
	local o = defaults(options)
	local ok, why = regrowClear(item.x, item.z, item.radius, items, o, options)
	if not ok then
		return false, why
	end
	local all = table.clone(items)
	table.insert(all, item)
	local open, why = ArenaLayout.regrowOpen(all, o)
	return open, why
end

-- P3d-F B4: 재생성 뒤 아레나가 열려 있는가 = 닫힌 공간 0(모든 빈 칸이 입장 자리와 이어짐) + 이동 가능 면적 비율 ≥ regrow.minWalkableFraction. 반환: bool, 이유, 비율.
function ArenaLayout.regrowOpen(items, o)
	local connected, freeCells, _, total = ArenaLayout.connectivity(items, o)
	local fraction = total > 0 and freeCells / total or 0
	if not connected then
		return false, "connectivity", fraction
	end
	if fraction < REGROW.minWalkableFraction then
		return false, "walkable", fraction
	end
	return true, nil, fraction
end

function ArenaLayout.regrowSpot(theme, items, rng, options, nextId)
	local o = defaults(options)
	local specs = {}
	for _, spec in ipairs(theme.layout or {}) do
		if spec.group ~= "big" then
			table.insert(specs, spec)
		end
	end
	if #specs == 0 then
		return nil, 0, "no_kind"
	end
	local members = options.members or {}
	local reason = nil
	for attempt = 1, REGROW.tries do
		if o.checkpoint then
			o.checkpoint()
		end
		local spec = specs[1 + math.floor(rng() * #specs)]
		local radius = spec.group == "feature" and SHAPES[spec.kind].footprint or (spec.radius[1] + (spec.radius[2] - spec.radius[1]) * rng())
		local x, z, underMember
		if #members > 0 and rng() < REGROW.underMemberChance then
			local m = members[1 + math.floor(rng() * #members)]
			local angle, d = rng() * 2 * math.pi, rng() * REGROW.underMemberStuds
			x, z, underMember = m.x + math.cos(angle) * d, m.z + math.sin(angle) * d, true
		else
			local angle, d = rng() * 2 * math.pi, math.sqrt(rng()) * (o.radius - LAYOUT.wallGapStuds - radius)
			x, z, underMember = math.cos(angle) * d, math.sin(angle) * d, false
		end
		local ok, why = regrowClear(x, z, radius, items, o, options)
		if ok then
			local rotation = rng() * 360
			local item = {
				id = nextId, kind = spec.kind, group = spec.group, x = x, z = z, radius = radius, rotationDeg = rotation,
				colliders = collidersFor(spec.group, spec.kind, x, z, radius, rotation), spec = spec, climbable = false, underMember = underMember,
			}
			local all = table.clone(items)
			table.insert(all, item)
			local open, openWhy = ArenaLayout.regrowOpen(all, o)
			if open then
				return item, attempt, nil
			end
			why = openWhy
		end
		reason = why
	end
	return nil, REGROW.tries, reason
end

-- 돌진 경로(origin에서 단위벡터 dir로 length)에 처음 걸리는 구조물과 "닿는 거리". obstacles = { { id, colliders = { { center(Vector3) 또는 x · z, r } } } 또는 { id, center, radius } }.
function ArenaLayout.firstOnPath(obstacles, origin, dir, length, bodyHalf)
	local best, bestDistance = nil, math.huge
	for _, obstacle in pairs(obstacles) do
		local circles = obstacle.colliders or { { center = obstacle.center, r = obstacle.radius } }
		for _, c in ipairs(circles) do
			local cx = c.center and c.center.X or c.x
			local cz = c.center and c.center.Z or c.z
			local rx, rz = cx - origin.X, cz - origin.Z
			local along = rx * dir.X + rz * dir.Z
			local reach = c.r + bodyHalf
			local lateral2 = rx * rx + rz * rz - along * along
			if along > 0 and lateral2 <= reach * reach then
				-- 이미 닿아 있으면(몸통 반폭 안) 0 - 그 자리에서 부딪힌다(P3a 리뷰 3).
				local contact = math.max(along - math.sqrt(reach * reach - lateral2), 0)
				if contact < length and contact < bestDistance then
					best, bestDistance = obstacle, contact
				end
			end
		end
	end
	if best then
		return best.id, bestDistance
	end
	return nil
end

return ArenaLayout
