-- M1-3 지형 형상(순수 · 결정적 - Instance를 만들지 않는다). 수치 = data/TerrainGenData · 자리 = WorldMapLayout(길 · 캠프 · 관문 · 옛 지형) + WorldStructures(구조물 · 둥지 마스크).
-- 굽기(server/TerrainBake) · 스폰 지점 판정 · 물살(클라 · 서버) · 검증이 모두 이 식을 읽는다 - 굽기 결과와 판정이 같은 식에서 나온다.
-- 단계(한 열 x, z의 윗면 높이):
--   S1 자연 = 평지 + 언덕(fbm) + 구역 원 테두리 능선 + 외곽 설산 + 봉우리 + 사구
--   S2 모양 = 대지(mesa) · 산길(trail) · 골짜기 벽(gorge) - "이 높이로 맞춘다"
--   S3 평탄 = 길 · 캠프 · 사냥 지대 · 관문 · 옛 지형 · 봉인 입구 분지 · 허브(가장 강하다 - 필수 길은 늘 평지)
--   S4 구조물 · 둥지 = 받침(pad - 이 높이로) + 흙더미(mound - 이만큼 솟게: 비밀 둥지를 덮는다)
--   S5 깎기 = 골짜기 · 강 · 호수 · 바다 만(원뿔 둑 - 헤엄쳐 나올 기슭)
--   3D = 굴(zone caves) + 보호 부피(둥지 · 통로 - 굽기 뒤 한 번 더 비운다) → 공기(아래가 물 높이면 물).
-- 좌표는 월드(stud). 높이 = 월드 Y. 구역 = 방위(꽃잎 60°).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TerrainGenData = require(ReplicatedStorage.Shared.data.TerrainGenData)
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)

local TerrainShape = {}
local G = TerrainGenData
local FLOOR = WorldMapData.floorTopY
local FLAT = FLOOR + G.flatLevel
TerrainShape.flatY = FLAT
TerrainShape.data = G

-- ─────────────────────────── 잡음(결정적 - math.noise는 로컬 하네스에 없고 시드가 없다) ───────────────────────────
local function hash2(ix, iz, s)
	local h = (ix * 374761 + iz * 668265 + s * 91813) % 4294967296
	h = bit32.bxor(h, bit32.rshift(h, 13))
	h = (h * 12741) % 4294967296
	h = bit32.bxor(h, bit32.rshift(h, 16))
	h = (h * 7309) % 4294967296
	h = bit32.bxor(h, bit32.rshift(h, 11))
	return (h % 1000003) / 1000003
end
local function smooth(t)
	return t * t * (3 - 2 * t)
end
-- 값 잡음 0 ~ 1(격자 1)
local function noise2(x, z, s)
	local ix, iz = math.floor(x), math.floor(z)
	local fx, fz = smooth(x - ix), smooth(z - iz)
	local a, b = hash2(ix, iz, s), hash2(ix + 1, iz, s)
	local c, d = hash2(ix, iz + 1, s), hash2(ix + 1, iz + 1, s)
	return (a + (b - a) * fx) + ((c + (d - c) * fx) - (a + (b - a) * fx)) * fz
end
-- fbm −1 ~ 1
local function fbm(x, z, s, octaves)
	local sum, amp, norm = 0, 1, 0
	for o = 1, octaves or 3 do
		sum += (noise2(x, z, s + o * 131) * 2 - 1) * amp
		norm += amp
		x, z, amp = x * 2.03 + 17.1, z * 2.03 - 9.7, amp * 0.5
	end
	return sum / norm
end
local function noise1(t, s)
	return noise2(t, 0.5, s) * 2 - 1
end
TerrainShape.fbm = fbm

local function smoothstep(e0, e1, x)
	local t = math.clamp((x - e0) / (e1 - e0), 0, 1)
	return t * t * (3 - 2 * t)
end
TerrainShape.smoothstep = smoothstep

-- ─────────────────────────── 기하 도우미 ───────────────────────────
local ZONES = WorldMapData.zones
local zoneOf = {} -- [key] = zone
for _, z in ipairs(ZONES) do
	zoneOf[z.key] = z
end

-- 방위 → 구역(꽃잎 60°)
function TerrainShape.zoneAt(x, z)
	local ang = math.deg(math.atan2(z, x))
	local best, bestD = nil, math.huge
	for _, zone in ipairs(ZONES) do
		local d = math.abs(((ang - zone.angleDeg + 180) % 360) - 180)
		if d < bestD then
			best, bestD = zone, d
		end
	end
	return best
end

local function w2(zone, r, lat)
	local p = WorldMapLayout.toWorld(zone, r, lat)
	return p.X, p.Z
end

-- 선분(ax, az)-(bx, bz)까지 거리 · t
local function segDist(px, pz, ax, az, bx, bz)
	local dx, dz = bx - ax, bz - az
	local len2 = dx * dx + dz * dz
	local t = len2 > 1e-6 and math.clamp(((px - ax) * dx + (pz - az) * dz) / len2, 0, 1) or 0
	local qx, qz = ax + dx * t - px, az + dz * t - pz
	return math.sqrt(qx * qx + qz * qz), t
end
TerrainShape.segDist = segDist

-- ─────────────────────────── 마스크 목록(한 번 짓는다) ───────────────────────────
-- 원형 받침 { kind = "pad", x, z, radius, blend, level(월드 Y), mode = "set" | "raise" | "flat" }
-- 선 받침 { kind = "path", pts = { {x, z, y} }, half, blend, mode } - 점 사이 높이 선형
-- 깎기 { kind = "carve", pts = { {x, z, level} }, inner, slope(둑 기울기 tan), depth, water(bool), flow, gorge } · 원형 깎기(호수 · 만)는 pts 1개
-- 공기 부피 { kind = "box", cf, half(Vector3), water(월드 Y 또는 nil) } · { kind = "tunnel", pts = { {x, z, floor} }, radius, height } · { kind = "dome", x, z, floor, radius, height }
local masks = nil

local function addPad(list, x, z, radius, blend, level, mode, tag)
	table.insert(list, { kind = "pad", x = x, z = z, radius = radius, blend = blend, level = level, mode = mode or "set", tag = tag,
		minX = x - radius - blend, maxX = x + radius + blend, minZ = z - radius - blend, maxZ = z + radius + blend })
end
local function addPath(list, pts, half, blend, mode, tag)
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, p in ipairs(pts) do
		minX, maxX = math.min(minX, p[1]), math.max(maxX, p[1])
		minZ, maxZ = math.min(minZ, p[2]), math.max(maxZ, p[2])
	end
	local e = half + blend
	table.insert(list, { kind = "path", pts = pts, half = half, blend = blend, mode = mode or "set", tag = tag, minX = minX - e, maxX = maxX + e, minZ = minZ - e, maxZ = maxZ + e })
end
local function addCarve(list, c)
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, p in ipairs(c.pts) do
		minX, maxX = math.min(minX, p[1]), math.max(maxX, p[1])
		minZ, maxZ = math.min(minZ, p[2]), math.max(maxZ, p[2])
	end
	local e = c.inner + (c.reach or 60)
	c.kind = "carve"
	c.minX, c.maxX, c.minZ, c.maxZ = minX - e, maxX + e, minZ - e, maxZ + e
	table.insert(list, c)
end

local function buildMasks()
	local shape, flat, struct, carves, air = {}, {}, {}, {}, {}
	local F = G.flatten
	-- 허브(평지 - 파트 바닥 · 나무)
	addPad(flat, 0, 0, G.hub.radius, G.hub.ramp * 0.25, FLAT, "flat", "hub")
	-- 구역: 길 · 캠프 · 사냥 지대 · 관문 · 토벌 관문 · 옛 지형 · 모양 · 깎기
	for _, zone in ipairs(ZONES) do
		local zd = G.zones[zone.key] or {}
		local route = WorldMapLayout.route(zone)
		local pts = {}
		for _, pt in ipairs(route) do
			table.insert(pts, { pt.p.X, pt.p.Z, FLAT })
		end
		addPath(flat, pts, WorldMapData.layout.roadWidth / 2 + F.roadMargin, F.roadBlend, "flat", "road_" .. zone.key)
		local c = WorldMapLayout.camp(zone)
		addPad(flat, c.X, c.Z, F.campRadius, F.blend, FLAT, "flat", "camp")
		for _, g in ipairs(WorldMapLayout.grounds(zone)) do
			addPad(flat, g.center.X, g.center.Z, F.groundRadius, F.blend, FLAT, "flat", "ground")
		end
		local gate = WorldMapLayout.gate(zone)
		addPad(flat, gate.X, gate.Z, F.gateRadius, F.blend, FLAT, "flat", "gate")
		local raid = WorldMapLayout.toWorld(zone, WorldMapData.layout.gate.r, WorldMapData.layout.raidLat)
		addPad(flat, raid.X, raid.Z, F.raidRadius, F.blend * 0.5, FLAT, "flat", "raid")
		-- 옛 지형(M1): plateau = 걸어 오르는 대지(사방 33° - 파트 대신 지형) · cliff = 절벽 대지(지형) · 그 밖(탑 · 굴 · 폭포 · 기둥) = 파트 밑 평지
		for _, f in ipairs(zone.features) do
			local fx, fz = w2(zone, f.r, f.lat)
			if f.kind == "plateau" then
				addPad(shape, fx, fz, math.max(f.w, f.d) / 2, f.h / math.tan(math.rad(33)), FLAT + f.h, "set", "plateau")
			elseif f.kind == "cliff" then
				addPad(shape, fx, fz, math.max(f.w, f.d) / 2, 8, FLAT + f.h, "set", "cliff")
			else
				local fp = math.max(f.w or 0, f.d or 0, (f.size or 0) * 1.5 + 12) / 2
				addPad(flat, fx, fz, fp + F.featureMargin, F.blend, FLAT, "flat", "feature")
			end
		end
		-- 랜드마크(옛 M1 - 파트): 평지(바다 만 속 신전은 만이 깎는다)
		local lm = zone.landmark
		local lx, lz = w2(zone, lm.r + 90, 0)
		if not (zd.bay) then
			addPad(flat, lx, lz, lm.radius + 50, F.blend, FLAT, "flat", "landmark")
		end
		for _, m in ipairs(zd.mesas or {}) do
			local mx, mz = w2(zone, m.r, m.lat)
			addPad(shape, mx, mz, m.radius, m.blend, FLAT + m.level, "set", "mesa:" .. (m.material or ""))
		end
		for _, t in ipairs(zd.trails or {}) do
			local tp = {}
			for _, p in ipairs(t.pts) do
				local x, z = w2(zone, p[1], p[2])
				table.insert(tp, { x, z, FLAT + p[3] })
			end
			addPath(shape, tp, t.width / 2, t.blend, "set", "trail")
		end
		for _, v in ipairs(zd.valleys or {}) do
			local vp = {}
			for _, p in ipairs(v.pts) do
				local x, z = w2(zone, p[1], p[2])
				table.insert(vp, { x, z, FLAT - v.depth })
			end
			addCarve(carves, { pts = vp, inner = v.width / 2, slope = v.depth / v.blend, depth = 0, floor = true, stream = v.stream, reach = v.blend + v.depth * 3, tag = "valley" })
		end
		if zd.river then
			local R = zd.river
			local rp = {}
			for _, p in ipairs(R.pts) do
				local x, z = w2(zone, p[1], p[2])
				table.insert(rp, { x, z, FLOOR + p[3] }) -- 수면 level은 바닥 윗면 기준
			end
			local gorge = R.gorge
			addCarve(carves, { pts = rp, inner = R.width / 2, slope = 0.55, depth = R.depth, water = true, flow = R.flowSpeed, reach = 90, tag = "river",
				gorge = gorge and { from = gorge.from, to = gorge.to, slope = gorge.wallHeight / gorge.wallBlend } })
			if gorge then
				-- 계곡 벽: 그 구간 양옆을 벽 높이로 솟게(깎기가 가운데를 다시 판다)
				local gp = {}
				for i = gorge.from, gorge.to do
					table.insert(gp, { rp[i][1], rp[i][2], FLAT + gorge.wallHeight })
				end
				addPath(shape, gp, R.width / 2 + 34, 24, "raise", "gorgeWall")
			end
			local s = R.pts[1]
			local sx, sz = w2(zone, s[1], s[2])
			addPad(shape, sx, sz, R.spring.radius + 10, 20, FLOOR + s[3] + 1, "set", "spring")
		end
		for _, l in ipairs(zd.lakes or {}) do
			local x, z = w2(zone, l.r, l.lat)
			addCarve(carves, { pts = { { x, z, FLOOR + l.level } }, inner = l.radius, slope = 0.6, depth = l.depth, water = true, reach = l.blend + 40, tag = "lake" })
		end
		if zd.bay then
			local b = zd.bay
			local x, z = w2(zone, b.r, b.lat)
			local depth = b.level - b.bed
			addCarve(carves, { pts = { { x, z, FLOOR + b.level } }, inner = b.radius, slope = depth / b.shoreBlend, depth = depth, water = true, reach = b.shoreBlend + 200, tag = "bay", flatBed = true })
			local ox, oz = w2(zone, b.channel.toR, b.lat)
			addCarve(carves, { pts = { { x, z, FLOOR + b.level }, { ox, oz, FLOOR + b.level } }, inner = b.channel.width / 2, slope = depth / b.shoreBlend, depth = depth, water = true, reach = b.shoreBlend + 200, tag = "bay", flatBed = true })
		end
		for _, cv in ipairs(zd.caves or {}) do
			local cp = {}
			for _, p in ipairs(cv.pts) do
				local x, z = w2(zone, p[1], p[2])
				table.insert(cp, { x, z, FLAT + p[3] })
			end
			table.insert(air, { kind = "tunnel", pts = cp, radius = cv.radius, height = cv.height, tag = "cave" })
			if cv.chamber then
				local x, z = w2(zone, cv.chamber.r, cv.chamber.lat)
				table.insert(air, { kind = "dome", x = x, z = z, floor = cp[#cp][3], radius = cv.chamber.radius, height = cv.chamber.height, tag = "cave" })
			end
		end
	end
	-- 봉인 입구 · 바깥 고리 분지(꽃잎 사이 설산 속 - 허브 쪽 골짜기로 걸어 들어간다)
	local RB = G.reservedBasin
	for _, a in ipairs(WorldMapData.reserved.outerRing.angles) do
		local d = WorldMapLayout.dirOf(a)
		addPad(flat, d.X * RB.centerR, d.Z * RB.centerR, RB.radius, RB.blend, FLAT, "flat", "basin")
		addPath(flat, { { d.X * RB.corridorFromR, d.Z * RB.corridorFromR, FLAT }, { d.X * RB.centerR, d.Z * RB.centerR, FLAT } }, RB.corridorWidth / 2, RB.corridorBlend, "flat", "basinCorridor")
	end
	for _, e in ipairs(WorldMapData.sealed.entrances) do
		if e.region == "outerRing" then
			local d = WorldMapLayout.dirOf(e.at.angleDeg)
			addPad(flat, d.X * e.at.r, d.Z * e.at.r, F.sealedRadius, F.blend, FLAT, "flat", "sealed")
		end
	end
	for _, v in ipairs(air) do
		TerrainShape.boundsOf(v)
	end
	return { shape = shape, flat = flat, struct = struct, carves = carves, air = air }
end

-- 구조물 · 둥지(비밀 둥지 먼저 - 받침 · 흙더미 · 보호 부피). 기본 마스크와 따로 짓는다: 구조물이 "지형에 붙어 서는" 자리를 기본 높이(baseHeight)로 묻기 때문(순환 방지).
local function buildStructMasks()
	local struct, air = {}, {}
	local WorldStructures = require(ReplicatedStorage.Shared.WorldStructures)
	local sm = WorldStructures.terrainMasks()
	for _, p in ipairs(sm.pads) do
		addPad(struct, p.x, p.z, p.radius, p.blend, p.level, p.mode, p.tag)
	end
	for _, p in ipairs(sm.paths or {}) do
		addPath(struct, p.pts, p.half, p.blend, p.mode, p.tag)
	end
	for _, v in ipairs(sm.protect) do
		v.protect = true
		TerrainShape.boundsOf(v)
		table.insert(air, v)
	end
	return { shape = {}, flat = {}, struct = struct, carves = {}, air = air }
end

-- 공기 부피의 평면 경계(버킷 · 빠른 거르기)
function TerrainShape.boundsOf(v)
	local m = G.protectMargin
	if v.kind == "box" then
		local c, h = v.cf.Position, v.half
		local r = math.sqrt(h.X * h.X + h.Z * h.Z) + m
		v.minX, v.maxX, v.minZ, v.maxZ = c.X - r, c.X + r, c.Z - r, c.Z + r
		v.minY, v.maxY = c.Y - h.Y - m, c.Y + h.Y + m
	elseif v.kind == "tunnel" then
		local minX, maxX, minZ, maxZ, minY, maxY = math.huge, -math.huge, math.huge, -math.huge, math.huge, -math.huge
		for _, p in ipairs(v.pts) do
			minX, maxX, minZ, maxZ = math.min(minX, p[1]), math.max(maxX, p[1]), math.min(minZ, p[2]), math.max(maxZ, p[2])
			minY, maxY = math.min(minY, p[3]), math.max(maxY, p[3])
		end
		local r = v.radius + m
		v.minX, v.maxX, v.minZ, v.maxZ, v.minY, v.maxY = minX - r, maxX + r, minZ - r, maxZ + r, minY - 1, maxY + v.height + m
	else
		local r = v.radius + m
		v.minX, v.maxX, v.minZ, v.maxZ, v.minY, v.maxY = v.x - r, v.x + r, v.z - r, v.z + r, v.floor - 1, v.floor + v.height + m
	end
	return v
end

-- 버킷(격자 BUCKET)으로 마스크를 나눠 한 열이 가까운 것만 본다
local BUCKET = 128
local buckets, structMasks, structBuckets = nil, nil, nil
local building = false
local function bucketKey(ix, iz)
	return ix * 100000 + iz
end
local function fill(set)
	local out = {}
	for _, group in ipairs({ "shape", "flat", "struct", "carves", "air" }) do
		for _, m in ipairs(set[group]) do
			for ix = math.floor(m.minX / BUCKET), math.floor(m.maxX / BUCKET) do
				for iz = math.floor(m.minZ / BUCKET), math.floor(m.maxZ / BUCKET) do
					local k = bucketKey(ix, iz)
					local b = out[k]
					if not b then
						b = { shape = {}, flat = {}, struct = {}, carves = {}, air = {} }
						out[k] = b
					end
					table.insert(b[group], m)
				end
			end
		end
	end
	return out
end
local function ensure()
	if not masks then
		masks = buildMasks()
		buckets = fill(masks)
	end
end
local function ensureStruct()
	ensure()
	if not structMasks and not building then
		building = true
		structMasks = buildStructMasks()
		structBuckets = fill(structMasks)
		building = false
	end
end
local EMPTY = { shape = {}, flat = {}, struct = {}, carves = {}, air = {} }
local function bucketAt(x, z)
	ensure()
	return buckets[bucketKey(math.floor(x / BUCKET), math.floor(z / BUCKET))] or EMPTY
end
local function structBucketAt(x, z)
	ensureStruct()
	return structBuckets and structBuckets[bucketKey(math.floor(x / BUCKET), math.floor(z / BUCKET))] or EMPTY
end
function TerrainShape.masks()
	ensureStruct()
	return masks, structMasks
end
-- 검증 · 재굽기: 마스크를 다시 짓는다(데이터를 바꾼 뒤)
function TerrainShape.reset()
	masks, buckets, structMasks, structBuckets = nil, nil, nil, nil
end

-- ─────────────────────────── 마스크 적용 ───────────────────────────
-- 받침 가중치(0 ~ 1)와 목표 높이
local function padWeight(m, x, z)
	local dx, dz = x - m.x, z - m.z
	local d = math.sqrt(dx * dx + dz * dz)
	if d <= m.radius then
		return 1
	end
	if m.blend <= 0 then
		return 0
	end
	return 1 - smoothstep(m.radius, m.radius + m.blend, d)
end
local function pathWeight(m, x, z)
	local best, bestT, bestI = math.huge, 0, 1
	for i = 2, #m.pts do
		local a, b = m.pts[i - 1], m.pts[i]
		local d, t = segDist(x, z, a[1], a[2], b[1], b[2])
		if d < best then
			best, bestT, bestI = d, t, i
		end
	end
	local a, b = m.pts[bestI - 1], m.pts[bestI]
	local level = a[3] + (b[3] - a[3]) * bestT
	if best <= m.half then
		return 1, level
	end
	return 1 - smoothstep(m.half, m.half + m.blend, best), level
end
local function applyGroup(list, x, z, h)
	for _, m in ipairs(list) do
		if x >= m.minX and x <= m.maxX and z >= m.minZ and z <= m.maxZ then
			local w, level
			if m.kind == "pad" then
				w, level = padWeight(m, x, z), m.level
			else
				w, level = pathWeight(m, x, z)
			end
			if w > 0 then
				if m.mode == "raise" then
					if level > h then
						h = h + (level - h) * w
					end
				else -- set · flat
					h = h + (level - h) * w
				end
			end
		end
	end
	return h
end

-- 깎기 목표 높이 · 물 높이(원뿔 둑). 반환: target(or nil), waterY(or nil), flow(Vector3 or nil)
local function carveAt(m, x, z)
	local best, bestT, bestI = math.huge, 0, 1
	for i = 2, #m.pts do
		local a, b = m.pts[i - 1], m.pts[i]
		local d, t = segDist(x, z, a[1], a[2], b[1], b[2])
		if d < best then
			best, bestT, bestI = d, t, i
		end
	end
	local level
	if #m.pts == 1 then
		local dx, dz = x - m.pts[1][1], z - m.pts[1][2]
		best, level = math.sqrt(dx * dx + dz * dz), m.pts[1][3]
	else
		local a, b = m.pts[bestI - 1], m.pts[bestI]
		level = a[3] + (b[3] - a[3]) * bestT
	end
	local slope = m.slope
	if m.gorge and bestI - 1 >= m.gorge.from and bestI <= m.gorge.to then
		slope = m.gorge.slope
	end
	local target
	if m.floor then -- 골짜기: 바닥 = level(평지 − 깊이) · 둑 기울기 slope
		target = level + math.max(0, best - m.inner) * slope * 3
	else
		local bed = level - m.depth
		if best <= m.inner then
			local k = m.flatBed and smoothstep(m.inner * 0.55, m.inner, best) or (best / m.inner) ^ 2
			target = bed + (level - 1 - bed) * k
		else
			target = level - 1 + (best - m.inner) * slope
		end
	end
	local waterY, flow = nil, nil
	if m.water and best <= m.inner + 30 then
		waterY = level
		if m.flow and #m.pts > 1 and best <= m.inner + 2 then
			local a, b = m.pts[bestI - 1], m.pts[bestI]
			local dx, dz = b[1] - a[1], b[2] - a[2]
			local len = math.sqrt(dx * dx + dz * dz)
			flow = Vector3.new(dx / len * m.flow, 0, dz / len * m.flow)
		end
	elseif m.stream and best <= m.inner * 0.45 then
		waterY = level + m.stream
	end
	return target, waterY, flow
end

-- ─────────────────────────── S1 자연 ───────────────────────────
local RIM_CENTERS = {}
for _, zone in ipairs(ZONES) do
	local c = WorldMapLayout.regionCenter(zone)
	table.insert(RIM_CENTERS, { x = c.X, z = c.Z })
end
local PEAKS = {}
local DUNES = {}
for _, zone in ipairs(ZONES) do
	local zd = G.zones[zone.key] or {}
	for _, p in ipairs(zd.peaks or {}) do
		local x, z = w2(zone, p.r, p.lat)
		table.insert(PEAKS, { x = x, z = z, h = p.h, radius = p.radius, name = p.name, zone = zone.key })
	end
	if zd.dunes then
		local a = math.rad(zone.angleDeg + zd.dunes.dirDeg)
		DUNES[zone.key] = { amp = zd.dunes.amp, lambda = zd.dunes.lambda, warp = zd.dunes.warp, dx = math.cos(a), dz = math.sin(a) }
	end
end
TerrainShape.peaks = PEAKS

-- 외곽 봉우리 줄(방위마다 고정 시드 - 버킷 = 정수 각도 → 가까운 봉우리)
local EDGE_PEAKS = {}
do
	local E = G.edge
	local seed = G.seed % 2147483647
	local function rand()
		seed = (seed * 48271) % 2147483647
		return seed / 2147483647
	end
	for a = 0, 359, E.peakEveryDeg do
		local ang = a + (rand() * 2 - 1) * E.peakJitterDeg
		local r = E.peakR[1] + rand() * (E.peakR[2] - E.peakR[1])
		local h = E.peakH[1] + rand() ^ 1.5 * (E.peakH[2] - E.peakH[1])
		local w = E.peakWidth[1] + rand() * (E.peakWidth[2] - E.peakWidth[1])
		table.insert(EDGE_PEAKS, { ang = ang, x = math.cos(math.rad(ang)) * r, z = math.sin(math.rad(ang)) * r, h = h, w = w })
	end
end
local EDGE_BY_DEG = {}
for d = -180, 180 do
	local list = {}
	for _, pk in ipairs(EDGE_PEAKS) do
		if math.abs(((pk.ang - d + 180) % 360) - 180) <= 12 then
			table.insert(list, pk)
		end
	end
	EDGE_BY_DEG[d] = list
end
function TerrainShape.edgePeaksNear(angDeg)
	return EDGE_BY_DEG[math.floor(angDeg + 0.5)] or EDGE_BY_DEG[180]
end
TerrainShape.edgePeaks = EDGE_PEAKS

function TerrainShape.naturalAt(x, z)
	local R = math.sqrt(x * x + z * z)
	local zone = TerrainShape.zoneAt(x, z)
	local zd = G.zones[zone.key] or {}
	local s = G.seed
	local hubK = smoothstep(G.hub.radius, G.hub.radius + G.hub.ramp, R)
	local H = G.hills
	local big = math.max(0, fbm(x / H.bigLambda, z / H.bigLambda, s + 1, 2)) * H.bigAmp
	local h = FLAT + ((fbm(x / H.lambda, z / H.lambda, s, 3) * 0.5 + 0.5) * H.amp + fbm(x / H.lambda2, z / H.lambda2, s + 7, 2) * H.amp2 + big) * (zd.hills or 1) * hubK
	-- 테두리 능선(원 둘레 잡음 높이)
	local rim = G.rim
	for i, c in ipairs(RIM_CENTERS) do
		local dx, dz = x - c.x, z - c.z
		local d = math.sqrt(dx * dx + dz * dz)
		local around = math.atan2(dz, dx)
		local arc = around * rim.radius
		local off = d - rim.radius - rim.wobble * noise1(arc / rim.wobbleLambda, s + i * 17)
		if math.abs(off) < rim.sigma * 3 then
			-- 방향별 세기: 허브 쪽(원 중심에서 원점 방향) inner · 옆 side · 바깥 outer
			local toHub = math.atan2(-c.z, -c.x)
			local phi = math.abs(((around - toHub + math.pi) % (2 * math.pi)) - math.pi) / math.pi -- 0 = 허브 쪽 · 1 = 바깥
			local wdir = phi < 0.5 and (rim.inner + (rim.side - rim.inner) * smoothstep(0.05, 0.45, phi)) or (rim.side + (rim.outer - rim.side) * smoothstep(0.55, 0.95, phi))
			local rh = math.max(0, rim.base + rim.vary * noise1(arc / rim.lambda, s + i * 11)) * wdir
			local k = math.exp(-(off / rim.sigma) ^ 2)
			local v = FLAT + (rh + fbm(x / 40, z / 40, s + 3, 2) * 6) * k * hubK
			if v > h then
				h = v
			end
		end
	end
	-- 외곽 설산(산맥: 밑 둔덕 + 봉우리 줄 + 능선 결)
	local E = G.edge
	local ang = math.deg(math.atan2(z, x))
	local start = E.start - E.startVary * math.max(0, noise1(ang / E.startLambdaDeg, s + 51))
	if R > start - 200 then
		local e = smoothstep(start, E.full, R) ^ 1.4
		local eh = E.base + E.vary * noise1(ang / E.lambdaDeg, s + 5)
		local ridge = (1 - math.abs(fbm(x / E.ridgeLambda, z / E.ridgeLambda, s + 9, 3))) ^ 2 * E.ridgeAmp
		local v = FLAT + e * (eh + ridge)
		for _, pk in ipairs(TerrainShape.edgePeaksNear(ang)) do
			local dx, dz = x - pk.x, z - pk.z
			local k = math.exp(-2 * (dx * dx + dz * dz) / (pk.w * pk.w))
			if k > 0.01 then
				local pv = FLAT + pk.h * k * (0.85 + 0.3 * (1 - math.abs(fbm(x / 70, z / 70, s + 13, 2))))
				if pv > v then
					v = pv
				end
			end
		end
		if R > E.backFill then -- 세계 끝 뒤(투명 벽 밖)는 채워 끝이 안 보이게 - 평평한 띠가 되지 않게 능선 결 · 잡음
			v = math.max(v, FLAT + eh * 0.9 + ridge * 1.6 + fbm(x / 160, z / 160, s + 17, 3) * 70)
		end
		if v > h then
			h = v
		end
	end
	-- 봉우리(가우스 + 결)
	for _, p in ipairs(PEAKS) do
		local dx, dz = x - p.x, z - p.z
		local d2 = dx * dx + dz * dz
		local lim = p.radius * 2
		if d2 < lim * lim then
			local k = math.exp(-2 * d2 / (p.radius * p.radius))
			local v = FLAT + p.h * k * (1 + 0.12 * fbm(x / 60, z / 60, s + 21, 2))
			if v > h then
				h = v
			end
		end
	end
	-- 사구(바람 방향 줄무늬 + 휨)
	local du = DUNES[zone.key]
	if du then
		local t = (x * du.dx + z * du.dz) / du.lambda + fbm(x / du.warp / 4, z / du.warp / 4, s + 31, 2) * 1.2
		local crest = (math.sin(t * 2 * math.pi) * 0.5 + 0.5) ^ 1.6
		h += du.amp * crest * hubK * (0.6 + 0.4 * (fbm(x / 300, z / 300, s + 33, 2) * 0.5 + 0.5))
	end
	return h
end

-- ─────────────────────────── 한 열 ───────────────────────────
-- 반환 { h = 윗면 Y, water = 수면 Y 또는 nil, flow = Vector3 또는 nil, zone = 구역, tag = 가장 센 마스크 표시(재질) }
function TerrainShape.column(x, z, skipStruct)
	local b = bucketAt(x, z)
	local h = TerrainShape.naturalAt(x, z)
	h = applyGroup(b.shape, x, z, h)
	h = applyGroup(b.flat, x, z, h)
	if not skipStruct then
		h = applyGroup(structBucketAt(x, z).struct, x, z, h)
	end
	local water, flow, carved = nil, nil, false
	for _, m in ipairs(b.carves) do
		if x >= m.minX and x <= m.maxX and z >= m.minZ and z <= m.maxZ then
			local target, wy, f = carveAt(m, x, z)
			if target < h then
				h = target
				carved = true
			end
			if wy and wy > h then
				water = math.max(water or -math.huge, wy)
				flow = f or flow
			end
		end
	end
	h = math.max(h, FLOOR + G.minBedY)
	return { h = h, water = water, flow = flow, zone = TerrainShape.zoneAt(x, z), carved = carved }
end

function TerrainShape.height(x, z)
	return TerrainShape.column(x, z).h
end
-- 구조물 · 둥지 받침 전(자연 + 모양 + 평탄 + 깎기) - "지형에 붙어 서는" 구조물이 쓴다
function TerrainShape.baseHeight(x, z)
	return TerrainShape.column(x, z, true).h
end

-- 3D: 이 점이 공기 부피(굴 · 보호 부피) 안인가. 반환: 공기?, 그 점에서 부피 바닥 높이(굽기가 바로 아래 칸의 점유율을 이 높이에 맞춘다 - 표면 = 칸 위 + 2 규칙)
local function inAir(v, x, y, z, margin)
	if v.kind == "box" then
		local l = v.cf:PointToObjectSpace(Vector3.new(x, y, z))
		local h = v.half
		if math.abs(l.X) <= h.X + margin and math.abs(l.Z) <= h.Z + margin and l.Y >= -h.Y and l.Y <= h.Y + margin then
			return true, v.cf.Position.Y - h.Y
		end
		return false
	elseif v.kind == "tunnel" then
		for i = 2, #v.pts do
			local a, b = v.pts[i - 1], v.pts[i]
			local d, t = segDist(x, z, a[1], a[2], b[1], b[2])
			local r = v.radius + margin
			if d <= r then
				local floor = a[3] + (b[3] - a[3]) * t
				local top = floor + (v.height + margin) * math.sqrt(math.max(0, 1 - (d / r) ^ 2))
				if y >= floor and y <= top then
					return true, floor
				end
			end
		end
		return false
	else
		local dx, dz = x - v.x, z - v.z
		local r = v.radius + margin
		local d = math.sqrt(dx * dx + dz * dz)
		if d > r then
			return false
		end
		if y >= v.floor and y <= v.floor + (v.height + margin) * math.sqrt(math.max(0, 1 - (d / r) ^ 2)) then
			return true, v.floor
		end
		return false
	end
end
-- 이 열에 공기 부피가 걸치는가(굽기가 3D 검사를 할지) - 굴(기본) + 보호 부피(구조물)
function TerrainShape.airVolumesNear(x, z)
	local list = nil
	for _, group in ipairs({ bucketAt(x, z).air, structBucketAt(x, z).air }) do
		for _, v in ipairs(group) do
			if x >= v.minX and x <= v.maxX and z >= v.minZ and z <= v.maxZ then
				list = list or {}
				table.insert(list, v)
			end
		end
	end
	return list
end
function TerrainShape.airAt(x, y, z, list)
	for _, v in ipairs(list or TerrainShape.airVolumesNear(x, z) or {}) do
		if y >= v.minY and y <= v.maxY then
			local inside, floor = inAir(v, x, y, z, v.protect and G.protectMargin or 0)
			if inside then
				return true, v.water, floor
			end
		end
	end
	return false, nil, nil
end
TerrainShape.inAir = inAir

-- 물 높이 · 물살(클라 물살 · 서버 상한 검사 · 스폰 판정)
function TerrainShape.waterAt(x, z)
	local c = TerrainShape.column(x, z)
	return c.water, c.flow
end

-- ─────────────────────────── 재질 ───────────────────────────
-- 열 정보 + 기울기(도) → 재질 이름. 물 아래 = 바닥 재질 · 가파르면 바위 · 높으면 눈 · 구역 기본 + 얼룩.
function TerrainShape.material(x, z, col, slopeDeg)
	local pal = G.palette[col.zone.key]
	local R = math.sqrt(x * x + z * z)
	if R < G.hub.radius then
		return G.hub.material
	end
	local above = col.h - FLOOR
	if col.water and col.water > col.h then
		return pal.bed
	end
	if above > G.snowLine + G.snowVary * fbm(x / 90, z / 90, G.seed + 41, 2) then
		return slopeDeg > G.steepDeg + 15 and G.rockMaterial or G.snowMaterial
	end
	if slopeDeg > G.steepDeg then
		return pal.cliff
	end
	if slopeDeg > G.steepDeg * 0.6 then
		return pal.slope
	end
	if fbm(x / 55, z / 55, G.seed + 43, 2) > 0.28 then
		return pal.ground2
	end
	return pal.ground
end

-- ─────────────────────────── 서버 경계 백업(사용자 보강 ②) ───────────────────────────
-- 발이 서 있어도 되는 반경(방위마다): 기본 edgeGuard.allowR · 봉인 입구 분지 골짜기 · 바다 만 물 위는 basinAllowR.
function TerrainShape.edgeAllowR(x, z)
	local EG = G.edgeGuard
	local R = math.sqrt(x * x + z * z)
	if R <= EG.allowR then
		return EG.allowR
	end
	local RB = G.reservedBasin
	for _, a in ipairs(WorldMapData.reserved.outerRing.angles) do
		local d = WorldMapLayout.dirOf(a)
		local along = x * d.X + z * d.Z
		local side = math.abs(-x * d.Z + z * d.X)
		if along > RB.corridorFromR - 50 and side <= math.max(RB.corridorWidth / 2 + 10, (along > RB.centerR - RB.radius) and RB.radius or 0) then
			return EG.basinAllowR
		end
	end
	local c = TerrainShape.column(x, z)
	if c.water then
		return EG.basinAllowR
	end
	return EG.allowR
end

return TerrainShape
