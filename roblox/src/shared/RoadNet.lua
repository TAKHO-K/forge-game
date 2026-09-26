-- M1-4 길(순수 · 결정적). 수치 = data/RoadData. 길목 = WorldMapLayout.route(id 그대로) · 곡선 = Catmull-Rom + 구불거림(사인 2겹 · 길목 근처 0) · 막힘 회피(둥지 · 옛 지형 · 구조물 · 물).
-- 높이 = 자연 지형(TerrainShape.naturalAt) 폭 방향 평균 → 창 평균 → 캠프 · 사냥 지대 · 관문 = 평지 → 경사 상한(앞뒤 두 번). 부르는 곳: TerrainShape(길 마스크 · 재질 띠) ·
-- PropScatter(소품 회피) · WorldCheck · WorldMapLayout(거리 · 길 안내 · 표지판 · 검사) · 클라 Wayfinder. WorldStructures를 부르지 않는다(지형 마스크가 이 모듈을 먼저 부른다 - 순환 방지).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoadData = require(ReplicatedStorage.Shared.data.RoadData)
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local TerrainGenData = require(ReplicatedStorage.Shared.data.TerrainGenData)
local NestData = require(ReplicatedStorage.Shared.data.NestData)
local WorldStructureData = require(ReplicatedStorage.Shared.data.WorldStructureData)

local RoadNet = {}
local R = RoadData
local D = WorldMapData
local L = D.layout
local FLAT = D.floorTopY + TerrainGenData.flatLevel

local cache = {}

local function smoothstep(e0, e1, x)
	local t = math.clamp((x - e0) / (e1 - e0), 0, 1)
	return t * t * (3 - 2 * t)
end
local function segDist(px, pz, ax, az, bx, bz)
	local dx, dz = bx - ax, bz - az
	local len2 = dx * dx + dz * dz
	local t = len2 > 1e-6 and math.clamp(((px - ax) * dx + (pz - az) * dz) / len2, 0, 1) or 0
	local qx, qz = ax + dx * t - px, az + dz * t - pz
	return math.sqrt(qx * qx + qz * qz)
end

-- Catmull-Rom 한 점
local function cr(p0, p1, p2, p3, t)
	local t2, t3 = t * t, t * t * t
	local function f(a, b, c, d)
		return 0.5 * (2 * b + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3)
	end
	return f(p0[1], p1[1], p2[1], p3[1]), f(p0[2], p1[2], p2[2], p3[2])
end

-- 막는 것(구불거림이 비껴간다): 원 { x, z, r } · 선 { ax, az, bx, bz, r }
local function blockers(zone)
	local Layout = require(ReplicatedStorage.Shared.WorldMapLayout)
	local list = {}
	local m = R.avoidMargin + R.half
	local function circle(p, r)
		table.insert(list, { x = p.X, z = p.Z, r = r + m })
	end
	for _, f in ipairs(zone.features) do
		local fp = math.max(f.w or 0, f.d or 0, (f.size or 0) * 1.5 + 12) / 2 + ((f.kind == "plateau") and f.h / math.tan(math.rad(33)) or 0) + ((f.kind == "cliff") and 8 or 0)
		circle(Layout.toWorld(zone, f.r, f.lat), fp)
	end
	for _, n in ipairs(NestData.nests) do
		if n.zone == zone.key and n.r and n.lat then
			circle(Layout.toWorld(zone, n.r, n.lat), 26)
		end
	end
	local zd = TerrainGenData.zones[zone.key] or {}
	for _, ms in ipairs(zd.mesas or {}) do
		circle(Layout.toWorld(zone, ms.r, ms.lat), ms.radius + ms.blend)
	end
	for _, lk in ipairs(zd.lakes or {}) do
		circle(Layout.toWorld(zone, lk.r, lk.lat), lk.radius + lk.blend)
	end
	for _, v in ipairs(zd.valleys or {}) do
		for i = 2, #v.pts do
			local a, b = Layout.toWorld(zone, v.pts[i - 1][1], v.pts[i - 1][2]), Layout.toWorld(zone, v.pts[i][1], v.pts[i][2])
			table.insert(list, { ax = a.X, az = a.Z, bx = b.X, bz = b.Z, r = v.width / 2 + v.blend + m })
		end
	end
	if zd.river then
		local pts = zd.river.pts
		for i = 2, #pts do
			local a, b = Layout.toWorld(zone, pts[i - 1][1], pts[i - 1][2]), Layout.toWorld(zone, pts[i][1], pts[i][2])
			table.insert(list, { ax = a.X, az = a.Z, bx = b.X, bz = b.Z, r = zd.river.width / 2 + zd.river.bankBlend + m })
		end
	end
	local C = WorldStructureData.colonnade
	if C.zone == zone.key then
		circle(Layout.toWorld(zone, C.r, C.lat), C.dais.w / 2)
	end
	local CA = WorldStructureData.cactus
	if CA.zone == zone.key then
		for _, f in ipairs(CA.fields) do
			circle(Layout.toWorld(zone, f.r, f.lat), f.outer)
		end
	end
	return list
end

local function blockedAt(list, x, z)
	for _, b in ipairs(list) do
		if b.ax then
			if segDist(x, z, b.ax, b.az, b.bx, b.bz) < b.r then
				return true
			end
		elseif (x - b.x) ^ 2 + (z - b.z) ^ 2 < b.r * b.r then
			return true
		end
	end
	return false
end

-- 곡선 + 구불거림 + 높이. waypoints = { { id, x, z, clear, flat } } → { pts = { { x, z, y, s } }, marks = { [id] = 번호 } }
local function makePath(zone, waypoints, style, phase, list)
	local TerrainShape = require(ReplicatedStorage.Shared.TerrainShape)
	-- 1) Catmull-Rom 표본(길목마다 표본 번호 기록)
	local base, marks = {}, {}
	local n = #waypoints
	for i = 1, n - 1 do
		local p0 = waypoints[math.max(1, i - 1)]
		local p1, p2 = waypoints[i], waypoints[i + 1]
		local p3 = waypoints[math.min(n, i + 2)]
		local chord = math.sqrt((p2.x - p1.x) ^ 2 + (p2.z - p1.z) ^ 2)
		local k = math.max(2, math.ceil(chord / R.step))
		if i == 1 then
			marks[p1.id] = 1
		end
		for j = (i == 1) and 0 or 1, k do
			local x, z = cr({ p0.x, p0.z }, { p1.x, p1.z }, { p2.x, p2.z }, { p3.x, p3.z }, j / k)
			table.insert(base, { x = x, z = z })
		end
		marks[p2.id] = #base
	end
	-- 2) 구불거림(길목 근처 0 · 막히면 줄인다)
	local s = 0
	local offs = {}
	for i, q in ipairs(base) do
		if i > 1 then
			s += math.sqrt((q.x - base[i - 1].x) ^ 2 + (q.z - base[i - 1].z) ^ 2)
		end
		q.s = s
		local a, b = base[math.max(1, i - 1)], base[math.min(#base, i + 1)]
		local tx, tz = b.x - a.x, b.z - a.z
		local tl = math.sqrt(tx * tx + tz * tz)
		q.nx, q.nz = -tz / math.max(tl, 1e-6), tx / math.max(tl, 1e-6)
		local taper = 1
		for _, w in ipairs(waypoints) do
			local d = math.sqrt((q.x - w.x) ^ 2 + (q.z - w.z) ^ 2)
			taper = math.min(taper, smoothstep(w.clear, w.clear + 80, d))
		end
		local o = style.amp * (math.sin(2 * math.pi * s / style.lambda + phase) + 0.35 * math.sin(2 * math.pi * s / (style.lambda * 0.43) + phase * 2.3)) / 1.35 * taper
		local chosen = 0
		for _, k in ipairs({ 1, 0.6, 0.3, 0, -0.3 }) do
			if not blockedAt(list, q.x + q.nx * o * k, q.z + q.nz * o * k) then
				chosen = o * k
				break
			end
		end
		offs[i] = chosen
	end
	-- 오프셋 부드럽게(창 5)
	local pts = {}
	for i, q in ipairs(base) do
		local sum, cnt = 0, 0
		for j = math.max(1, i - 2), math.min(#base, i + 2) do
			sum += offs[j]
			cnt += 1
		end
		local o = sum / cnt
		table.insert(pts, { x = q.x + q.nx * o, z = q.z + q.nz * o })
	end
	-- 3) 높이: 자연 지형 폭 평균
	s = 0
	for i, p in ipairs(pts) do
		if i > 1 then
			s += math.sqrt((p.x - pts[i - 1].x) ^ 2 + (p.z - pts[i - 1].z) ^ 2)
		end
		p.s = s
		local q = base[i]
		local h = 0
		for _, k in ipairs({ -1, 0, 1 }) do
			h += TerrainShape.naturalAt(p.x + q.nx * R.half * k, p.z + q.nz * R.half * k)
		end
		p.raw = h / 3
	end
	-- 창 평균
	for i, p in ipairs(pts) do
		local sum, cnt = 0, 0
		for j = i, 1, -1 do
			if p.s - pts[j].s > R.smoothStuds / 2 then
				break
			end
			sum += pts[j].raw
			cnt += 1
		end
		for j = i + 1, #pts do
			if pts[j].s - p.s > R.smoothStuds / 2 then
				break
			end
			sum += pts[j].raw
			cnt += 1
		end
		p.y = sum / cnt
	end
	-- 평지(캠프 · 사냥 지대 · 관문) · 허브
	for _, p in ipairs(pts) do
		local w = 0
		for _, wp in ipairs(waypoints) do
			if wp.flat then
				local d = math.sqrt((p.x - wp.x) ^ 2 + (p.z - wp.z) ^ 2)
				w = math.max(w, 1 - smoothstep(wp.flat, wp.flat + 60, d))
			end
		end
		local hr = math.sqrt(p.x * p.x + p.z * p.z)
		w = math.max(w, 1 - smoothstep(TerrainGenData.hub.radius - 40, TerrainGenData.hub.radius + 40, hr))
		p.y = p.y + (FLAT - p.y) * w
		p.y = math.max(p.y, FLAT - 2)
	end
	-- 경사 상한(앞 · 뒤)
	local g = math.tan(math.rad(R.designGradeDeg))
	for pass = 1, 2 do
		local from, to, dir = 2, #pts, 1
		if pass == 2 then
			from, to, dir = #pts - 1, 1, -1
		end
		for i = from, to, dir do
			local prev = pts[i - dir]
			local ds = math.abs(pts[i].s - prev.s)
			pts[i].y = math.clamp(pts[i].y, prev.y - g * ds, prev.y + g * ds)
		end
	end
	return { pts = pts, marks = marks, length = s }
end

local function zoneIndex(zone)
	return table.find(D.zones, zone) or 1
end

-- 구역 본길(허브 끝 → … → 관문). 반환 { zone, pts, marks, length, material, kind = "main" }
function RoadNet.zonePath(zone)
	local key = "main:" .. zone.key
	if cache[key] then
		return cache[key]
	end
	local Layout = require(ReplicatedStorage.Shared.WorldMapLayout)
	local C, F = R.clearAt, R.flatAt
	local wps = {}
	for _, pt in ipairs(Layout.route(zone)) do
		local kind = pt.id:match("^ground") and "ground" or pt.id
		table.insert(wps, { id = pt.id, x = pt.p.X, z = pt.p.Z, clear = C[kind] or 40, flat = F[kind] })
	end
	local style = R.zones[zone.key]
	local out = makePath(zone, wps, style, zoneIndex(zone) * 1.7, blockers(zone))
	out.zone, out.material, out.kind = zone.key, style.material, "main"
	cache[key] = out
	return out
end

-- 갈림길: 관문 앞 → 랜드마크(바다 만 속 신전은 없음 - 관문 자체가 신전 둑길 끝)
function RoadNet.branchPath(zone)
	local key = "branch:" .. zone.key
	if cache[key] ~= nil then
		return cache[key] or nil
	end
	local lm = zone.landmark
	if lm.kind == "sunkenTemple" then
		cache[key] = false
		return nil
	end
	local Layout = require(ReplicatedStorage.Shared.WorldMapLayout)
	local main = RoadNet.zonePath(zone)
	local gi = main.marks.gate
	local gs = main.pts[gi].s - R.landmarkBranch.fromBeforeGate
	local fork = main.pts[gi]
	for i = gi, 1, -1 do
		if main.pts[i].s <= gs then
			fork = main.pts[i]
			break
		end
	end
	local side = (zoneIndex(zone) % 2 == 0) and 1 or -1
	local mid = Layout.toWorld(zone, L.gate.r + 20, side * 80)
	local lc = Layout.toWorld(zone, lm.r + 90, 0)
	local toHub = Vector3.new(-lc.X, 0, -lc.Z).Unit
	local sideV = Layout.toWorld(zone, 0, side) - Layout.toWorld(zone, 0, 0)
	local endP = lc + (toHub * 0.4 + Vector3.new(sideV.X, 0, sideV.Z).Unit).Unit * (lm.radius + 30)
	local wps = {
		{ id = "fork", x = fork.x, z = fork.z, clear = 20 },
		{ id = "mid", x = mid.X, z = mid.Z, clear = 30 },
		{ id = "landmark", x = endP.X, z = endP.Z, clear = R.clearAt.landmark },
	}
	local style = { amp = R.zones[zone.key].amp * 0.4, lambda = R.zones[zone.key].lambda * 0.6 }
	local out = makePath(zone, wps, style, zoneIndex(zone) * 2.9, blockers(zone))
	-- 갈림 초입(본길과 붙은 구간 - 두 띠가 겹친다)은 본길 높이를 그대로 따른다 → 그 뒤로 경사 상한 다시(가로 기울기가 생기지 않게)
	local near = 2 * (R.half + R.shoulder) + R.blend * 0.5
	local lastNear = 1
	for i, q in ipairs(out.pts) do
		local best, by = math.huge, nil
		for j = 2, #main.pts do
			local a, b = main.pts[j - 1], main.pts[j]
			local dx, dz = b.x - a.x, b.z - a.z
			local len2 = dx * dx + dz * dz
			local t = len2 > 1e-6 and math.clamp(((q.x - a.x) * dx + (q.z - a.z) * dz) / len2, 0, 1) or 0
			local d = math.sqrt((a.x + dx * t - q.x) ^ 2 + (a.z + dz * t - q.z) ^ 2)
			if d < best then
				best, by = d, a.y + (b.y - a.y) * t
			end
		end
		if best < near then
			q.y = by
			lastNear = i
		end
	end
	local g = math.tan(math.rad(R.designGradeDeg))
	for i = lastNear + 1, #out.pts do
		local prev = out.pts[i - 1]
		out.pts[i].y = math.clamp(out.pts[i].y, prev.y - g * (out.pts[i].s - prev.s), prev.y + g * (out.pts[i].s - prev.s))
	end
	out.zone, out.material, out.kind, out.fork = zone.key, R.zones[zone.key].material, "branch", fork
	cache[key] = out
	return out
end

-- 모든 길(본길 + 갈림길)
function RoadNet.all()
	local list = {}
	for _, zone in ipairs(D.zones) do
		table.insert(list, RoadNet.zonePath(zone))
		local b = RoadNet.branchPath(zone)
		if b then
			table.insert(list, b)
		end
	end
	return list
end

-- 길목 사이 길이(곡선) - 거리 표 · 이동 시간
function RoadNet.length(zone, fromId, toId)
	local p = RoadNet.zonePath(zone)
	local a, b = p.marks[fromId], p.marks[toId]
	if not a or not b then
		return 0
	end
	return math.abs(p.pts[b].s - p.pts[a].s)
end

-- 길 안내 점(간격 약 24 - 길목 포함)
function RoadNet.guidePoints(zone, spacing)
	local p = RoadNet.zonePath(zone)
	local out, last = {}, -math.huge
	for i, q in ipairs(p.pts) do
		if q.s - last >= (spacing or 24) or i == #p.pts then
			table.insert(out, Vector3.new(q.x, q.y, q.z))
			last = q.s
		end
	end
	return out
end

-- 가장 가까운 길까지 수평 거리(검사 · 소품 · 스폰)
function RoadNet.distance(x, z)
	local best = math.huge
	for _, path in ipairs(RoadNet.all()) do
		local pts = path.pts
		for i = 2, #pts do
			local a, b = pts[i - 1], pts[i]
			if math.abs(a.x - x) < best + 20 and math.abs(a.z - z) < best + 20 then
				best = math.min(best, segDist(x, z, a.x, a.z, b.x, b.z))
			end
		end
	end
	return best
end

-- 표지판 자리: 캠프 앞(허브 쪽) · 갈림길 · 결계 문 안쪽 - { cf(바닥 · −Z = 길 쪽), label, zone }
function RoadNet.signs()
	if cache.signs then
		return cache.signs
	end
	local list = {}
	for _, zone in ipairs(D.zones) do
		local main = RoadNet.zonePath(zone)
		local function at(i, label, sideK)
			local q, nq = main.pts[i], main.pts[math.min(#main.pts, i + 1)]
			local tx, tz = nq.x - q.x, nq.z - q.z
			local tl = math.max(math.sqrt(tx * tx + tz * tz), 1e-6)
			local nx, nz = -tz / tl, tx / tl
			local x, z = q.x + nx * (R.half + 4) * sideK, q.z + nz * (R.half + 4) * sideK
			table.insert(list, { cf = CFrame.lookAt(Vector3.new(x, q.y, z), Vector3.new(q.x, q.y, q.z)), label = label, zone = zone.key })
		end
		at(main.marks.barrierGate, "캠프 · 관문 →", 1)
		local b = RoadNet.branchPath(zone)
		if b then
			local fi = 1
			for i, q in ipairs(main.pts) do
				if q.x == b.fork.x and q.z == b.fork.z then
					fi = i
				end
			end
			at(fi, "관문 ↑ · 전망 ↗", -1)
		end
	end
	cache.signs = list
	return list
end

function RoadNet.reset()
	cache = {}
end

return RoadNet
