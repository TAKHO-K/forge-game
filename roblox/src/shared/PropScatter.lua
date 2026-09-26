-- M1-4 빈 공간 채우기(순수 · 결정적 - 고정 시드). 수치 = data/PropScatterData · 소품 = data/PropData(PropKit).
-- 격자 칸마다 후보 한 점 → 막는 곳(필수 길 · 캠프 · 관문 · 사냥 지대 · 둥지 · 보호 부피 · 옛 지형 · 구조물 · 봉인 분지 · 물)을 피하고 가장 가까운 볼거리가 minGap보다 멀 때만
-- 구역 테마 묶음(sets)을 놓는다 - "빈 곳에만". 소품 높이 = 발자국 안 지형 최저(뜨지 않게). 절벽 사다리(cliffLadders) = 옛 cliff 지형 면 + 꼭대기 발판.
-- 부르는 곳: WorldMapLayout.buildAll(도형) · 스폰 지점(소품 회피) · 검증 M1-4(빈 공간 · 보호 부피 침범 · 필수 길).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PropScatterData = require(ReplicatedStorage.Shared.data.PropScatterData)
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local TerrainGenData = require(ReplicatedStorage.Shared.data.TerrainGenData)
local WorldStructureData = require(ReplicatedStorage.Shared.data.WorldStructureData)
local PropKit = require(ReplicatedStorage.Shared.PropKit)

local PropScatter = {}
local S = PropScatterData
local D = WorldMapData
local L = D.layout
local FLOOR = D.floorTopY
local FLAT = FLOOR + TerrainGenData.flatLevel

local cache = nil -- { placements = { { prop, cf, scale, zone, x, z, fp, top } }, ladders = { … }, stats }

local function segDist(px, pz, ax, az, bx, bz)
	local dx, dz = bx - ax, bz - az
	local len2 = dx * dx + dz * dz
	local t = len2 > 1e-6 and math.clamp(((px - ax) * dx + (pz - az) * dz) / len2, 0, 1) or 0
	local qx, qz = ax + dx * t - px, az + dz * t - pz
	return math.sqrt(qx * qx + qz * qz)
end

-- 막는 것 목록(원 · 선분 · 상자 경계) - 한 번 짓는다
local function buildBlockers(extra)
	local Layout = require(ReplicatedStorage.Shared.WorldMapLayout)
	local WorldStructures = require(ReplicatedStorage.Shared.WorldStructures)
	local A = S.avoid
	local circles, segs, rects = {}, {}, {}
	local function circle(p, r, why)
		table.insert(circles, { x = p.X, z = p.Z, r = r, why = why })
	end
	for _, zone in ipairs(D.zones) do
		local RoadNet = require(ReplicatedStorage.Shared.RoadNet) -- M1-4 곡선 길(본길 · 갈림길)
		for _, path in ipairs({ RoadNet.zonePath(zone), RoadNet.branchPath(zone) }) do
			for i = 3, #path.pts, 2 do
				local a, b = path.pts[i - 2], path.pts[i]
				table.insert(segs, { ax = a.x, az = a.z, bx = b.x, bz = b.z, r = L.roadWidth / 2 + A.road, why = "road" })
			end
		end
		for _, sg in ipairs(RoadNet.signs()) do
			if sg.zone == zone.key then
				circle(sg.cf.Position, 6, "sign")
			end
		end
		circle(Layout.camp(zone), A.camp, "camp")
		circle(Layout.campPortal(zone), A.portal, "portal")
		for _, g in ipairs(Layout.grounds(zone)) do
			circle(g.center, g.radius + A.ground, "ground")
		end
		circle(Layout.toWorld(zone, L.gate.r, L.raidLat), 40, "raid")
		for _, f in ipairs(zone.features) do
			local fp = math.max(f.w or 0, f.d or 0, (f.size or 0) * 1.5 + 12) / 2 + ((f.kind == "plateau") and f.h / math.tan(math.rad(33)) or 0) + ((f.kind == "cliff") and 8 or 0)
			circle(Layout.toWorld(zone, f.r, f.lat), fp + A.feature, "feature")
		end
		local lm = zone.landmark
		circle(Layout.toWorld(zone, lm.r + 90, 0), lm.radius + 50, "landmark")
		local zd = TerrainGenData.zones[zone.key] or {}
		for _, m in ipairs(zd.mesas or {}) do
			circle(Layout.toWorld(zone, m.r, m.lat), m.radius + m.blend + A.feature, "mesa")
		end
	end
	for _, g in ipairs(Layout.bossGates()) do
		circle(g.position, A.gate, "gate")
		for _, a in ipairs(g.approach or {}) do
			circle(a, A.gate * 0.5, "gateApproach")
		end
	end
	-- 둥지(받침 반경) · 보호 부피(평면 경계 상자)
	for _, n in ipairs(WorldStructures.nestList()) do
		local c = n.cf and n.cf.Position or n.spot
		local r = (n.pads and n.pads[1] and n.pads[1].radius) or 10
		circle(c, math.max(r, 12) + A.nest, "nest")
		circle(n.spot, 12 + A.nest, "nest")
		for _, p in ipairs(n.path or {}) do
			circle(p, 6 + A.nest, "nestPath")
		end
	end
	for _, v in ipairs(WorldStructures.data().protect) do
		local lo, hi = PropScatter.protectBounds(v)
		table.insert(rects, { minX = lo.X - A.protect, maxX = hi.X + A.protect, minZ = lo.Z - A.protect, maxZ = hi.Z + A.protect, why = "protect" })
	end
	-- 구조물(폐허 · 선인장 밭 · 수정)
	local C = WorldStructureData.colonnade
	circle(Layout.toWorld(Layout.zoneByKey(C.zone), C.r, C.lat), C.dais.w / 2 + A.structure, "ruins")
	local CA = WorldStructureData.cactus
	for _, f in ipairs(CA.fields) do
		circle(Layout.toWorld(Layout.zoneByKey(CA.zone), f.r, f.lat), f.outer + A.structure, "cactus")
	end
	local CR = WorldStructureData.crystals
	for _, c in ipairs(CR.clusters) do
		circle(Layout.toWorld(Layout.zoneByKey(CR.zone), c[1], c[2]), 8 + A.structure * 0.5, "crystal")
	end
	-- 봉인 분지 · 골짜기(바깥 고리 - 확장 자리는 비워 둔다)
	local RB = TerrainGenData.reservedBasin
	for _, a in ipairs(D.reserved.outerRing.angles) do
		local d = Layout.dirOf(a)
		circle(d * RB.centerR, RB.radius + A.basin, "basin")
		table.insert(segs, { ax = d.X * RB.corridorFromR, az = d.Z * RB.corridorFromR, bx = d.X * RB.centerR, bz = d.Z * RB.centerR, r = RB.corridorWidth / 2 + A.basin, why = "basin" })
	end
	for _, e in ipairs(extra or {}) do
		table.insert(circles, e)
	end
	-- 버킷
	local B = 128
	local buckets = {}
	local function put(item, minX, maxX, minZ, maxZ)
		for ix = math.floor(minX / B), math.floor(maxX / B) do
			for iz = math.floor(minZ / B), math.floor(maxZ / B) do
				local k = ix * 100000 + iz
				buckets[k] = buckets[k] or {}
				table.insert(buckets[k], item)
			end
		end
	end
	for _, c in ipairs(circles) do
		c.kind = "c"
		put(c, c.x - c.r, c.x + c.r, c.z - c.r, c.z + c.r)
	end
	for _, s in ipairs(segs) do
		s.kind = "s"
		put(s, math.min(s.ax, s.bx) - s.r, math.max(s.ax, s.bx) + s.r, math.min(s.az, s.bz) - s.r, math.max(s.az, s.bz) + s.r)
	end
	for _, r in ipairs(rects) do
		r.kind = "r"
		put(r, r.minX, r.maxX, r.minZ, r.maxZ)
	end
	return { buckets = buckets, B = B, count = #circles + #segs + #rects }
end

-- 보호 부피(box · tunnel · dome)의 평면 경계 → lo, hi(Vector3 - y 무시)
function PropScatter.protectBounds(v)
	if v.kind == "box" then
		local c, h = v.cf.Position, v.half
		local r = math.sqrt(h.X * h.X + h.Z * h.Z)
		return Vector3.new(c.X - r, 0, c.Z - r), Vector3.new(c.X + r, 0, c.Z + r)
	elseif v.kind == "tunnel" then
		local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
		for _, p in ipairs(v.pts) do
			minX, maxX, minZ, maxZ = math.min(minX, p[1]), math.max(maxX, p[1]), math.min(minZ, p[2]), math.max(maxZ, p[2])
		end
		return Vector3.new(minX - v.radius, 0, minZ - v.radius), Vector3.new(maxX + v.radius, 0, maxZ + v.radius)
	end
	return Vector3.new(v.x - v.radius, 0, v.z - v.radius), Vector3.new(v.x + v.radius, 0, v.z + v.radius)
end

-- 막힘 검사: 점(x, z) + 반경 r이 막는 것에 걸리면 이유(문자열) · 아니면 nil
local function blockedBy(bl, x, z, r)
	local k = math.floor(x / bl.B) * 100000 + math.floor(z / bl.B)
	for _, dx in ipairs({ -1, 0, 1 }) do
		for _, dz in ipairs({ -1, 0, 1 }) do
			for _, it in ipairs(bl.buckets[k + dx * 100000 + dz] or {}) do
				if it.kind == "c" then
					if (x - it.x) ^ 2 + (z - it.z) ^ 2 < (it.r + r) ^ 2 then
						return it.why
					end
				elseif it.kind == "s" then
					if segDist(x, z, it.ax, it.az, it.bx, it.bz) < it.r + r then
						return it.why
					end
				elseif x + r > it.minX and x - r < it.maxX and z + r > it.minZ and z - r < it.maxZ then
					return it.why
				end
			end
		end
	end
	return nil
end
PropScatter.blockedBy = blockedBy

local function rotY(x, z, deg)
	local a = math.rad(deg)
	local c, s = math.cos(a), math.sin(a)
	return x * c + z * s, -x * s + z * c
end

-- 발자국(반경 fp) 지면: 물이 있거나 높이 차가 크면 nil · 아니면 가장 낮은 높이
local function groundUnder(TerrainShape, x, z, fp)
	local lo, hi = math.huge, -math.huge
	local pts = { { 0, 0 }, { fp, 0 }, { -fp, 0 }, { 0, fp }, { 0, -fp }, { fp * 0.7, fp * 0.7 }, { -fp * 0.7, -fp * 0.7 } }
	for _, o in ipairs(pts) do
		local c = TerrainShape.column(x + o[1], z + o[2])
		if c.water then
			return nil, "water"
		end
		lo, hi = math.min(lo, c.h), math.max(hi, c.h)
	end
	if hi - lo > S.maxRelief then
		return nil, "relief"
	end
	return lo
end

local function build()
	local TerrainShape = require(ReplicatedStorage.Shared.TerrainShape)
	local Layout = require(ReplicatedStorage.Shared.WorldMapLayout)
	local seed = S.seed % 2147483647
	local function rand()
		seed = (seed * 48271) % 2147483647
		return seed / 2147483647
	end
	local placements, ladders = {}, {}
	local stats = { candidates = 0, placed = 0, items = 0, reject = {} }
	local function reject(why)
		stats.reject[why] = (stats.reject[why] or 0) + 1
	end
	-- 절벽 사다리(먼저 - 흩뿌리기가 피한다)
	local LD = S.ladder
	for _, cl in ipairs(S.cliffLadders) do
		local zone = Layout.zoneByKey(cl.zone)
		local f = zone.features[cl.feature]
		local c = Layout.toWorld(zone, f.r, f.lat)
		local R = math.max(f.w, f.d) / 2
		local blend = 8 -- TerrainShape: cliff = 받침 반경 R · 가장자리 8
		local toHub = Vector3.new(-c.X, 0, -c.Z).Unit
		local a = math.rad(cl.side or 0)
		local out = Vector3.new(toHub.X * math.cos(a) - toHub.Z * math.sin(a), 0, toHub.X * math.sin(a) + toHub.Z * math.cos(a))
		local base = Vector3.new(c.X, 0, c.Z) + out * (R + blend + LD.standoff)
		local top = FLAT + f.h
		local groundY = TerrainShape.baseHeight(base.X, base.Z)
		local h = 2 * math.ceil((top - groundY + 1) / 2) -- TrussPart 높이 = 2의 배수 · 윗면보다 조금 위
		local cf = CFrame.lookAt(Vector3.new(base.X, groundY, base.Z), Vector3.new(base.X, groundY, base.Z) + out)
		table.insert(ladders, { zone = cl.zone, cf = cf, height = h, top = top, base = Vector3.new(base.X, groundY, base.Z), landing = blend + LD.standoff + LD.landing, out = out })
	end
	local extra = {}
	for _, ld in ipairs(ladders) do
		table.insert(extra, { x = ld.base.X, z = ld.base.Z, r = 14, why = "ladder" })
	end
	local bl = buildBlockers(extra)
	-- 흩뿌리기
	local near = {} -- 버킷(64) → 놓인 소품 · 기존 볼거리 점
	local NB = 64
	local function nearKey(x, z)
		return math.floor(x / NB) * 100000 + math.floor(z / NB)
	end
	local function addNear(x, z)
		local k = nearKey(x, z)
		near[k] = near[k] or {}
		table.insert(near[k], { x = x, z = z })
	end
	for _, p in ipairs(PropScatter.existingPoints()) do
		addNear(p.X, p.Z)
	end
	local function nearest(x, z, lim)
		local best = lim
		local r = math.ceil(lim / NB)
		local ix, iz = math.floor(x / NB), math.floor(z / NB)
		for i = ix - r, ix + r do
			for j = iz - r, iz + r do
				for _, p in ipairs(near[i * 100000 + j] or {}) do
					local d = math.sqrt((p.x - x) ^ 2 + (p.z - z) ^ 2)
					if d < best then
						best = d
					end
				end
			end
		end
		return best
	end
	local hubR = D.hub.safeRadius + S.hubMargin
	local span = 2800
	local cell = S.cell
	for gx = -span, span, cell do
		for gz = -span, span, cell do
			local x = gx + cell / 2 + (rand() * 2 - 1) * cell / 2 * S.jitter
			local z = gz + cell / 2 + (rand() * 2 - 1) * cell / 2 * S.jitter
			local pick, yaw = rand(), rand() * 360
			local R = math.sqrt(x * x + z * z)
			if R > hubR and R < TerrainShape.edgeAllowR(x, z) - S.edgeMargin then
				stats.candidates += 1
				local zone = TerrainShape.zoneAt(x, z)
				local sets = S.sets[zone.key]
				local why = nil
				if not sets then
					why = "noSet"
				elseif TerrainShape.fbm(x / S.density.lambda, z / S.density.lambda, S.seed % 100000, 2) < S.density.sparse then
					why = "sparse"
				elseif nearest(x, z, S.minGap) < S.minGap then
					why = "notEmpty"
				else
					why = blockedBy(bl, x, z, 12)
				end
				if not why then
					-- 묶음 고르기
					local total = 0
					for _, st in ipairs(sets) do
						total += st.weight
					end
					local t, set = pick * total, sets[#sets]
					for _, st in ipairs(sets) do
						t -= st.weight
						if t <= 0 then
							set = st
							break
						end
					end
					local placedAny = false
					for i, it in ipairs(set.items) do
						local ox, oz = rotY(it[2], it[3], yaw)
						local px, pz = x + ox, z + oz
						local sc = (it[5][1] + rand() * (it[5][2] - it[5][1])) * (S.sizeMul or 1)
						local lo, hi = PropKit.bounds(it[1], sc)
						local fp = math.sqrt(math.max(lo.X * lo.X, hi.X * hi.X) + math.max(lo.Z * lo.Z, hi.Z * hi.Z))
						local w2 = blockedBy(bl, px, pz, fp)
						local gy, gwhy = nil, nil
						if not w2 then
							gy, gwhy = groundUnder(TerrainShape, px, pz, fp)
						end
						if not w2 and gy and gy - TerrainShape.flatY <= S.maxAbove then
							local cf = CFrame.new(px, gy - 0.3, pz) * CFrame.Angles(0, math.rad(yaw + it[4]), 0)
							table.insert(placements, { prop = it[1], cf = cf, scale = sc, zone = zone.key, x = px, z = pz, fp = fp, top = gy + hi.Y })
							addNear(px, pz)
							stats.items += 1
							placedAny = true
						elseif i == 1 then
							why = w2 or gwhy or "high"
							break
						end
					end
					if placedAny then
						stats.placed += 1
					end
				end
				if why then
					reject(why)
				end
			end
		end
	end
	return { placements = placements, ladders = ladders, stats = stats, blockers = bl.count }
end

-- 이미 있는 볼거리(부르는 순서와 무관하게 같은 결과 - 스폰 지점 · 검증이 buildAll보다 먼저 불러도 같다): 둥지 · 구조물 도형 · 옛 지형 · 랜드마크 · 관문 · 결계 문 · 봉인 입구
function PropScatter.existingPoints()
	local Layout = require(ReplicatedStorage.Shared.WorldMapLayout)
	local WorldStructures = require(ReplicatedStorage.Shared.WorldStructures)
	local pts = {}
	for _, p in ipairs(WorldStructures.data().prims) do
		table.insert(pts, p.cf.Position)
	end
	for _, zone in ipairs(D.zones) do
		for _, f in ipairs(zone.features) do
			table.insert(pts, Layout.toWorld(zone, f.r, f.lat))
		end
		table.insert(pts, Layout.toWorld(zone, zone.landmark.r + 90, 0))
		table.insert(pts, Layout.toWorld(zone, L.barrierGateR, 0))
		table.insert(pts, Layout.toWorld(zone, L.gate.r, L.raidLat))
	end
	for _, g in ipairs(Layout.bossGates()) do
		table.insert(pts, g.position)
	end
	for _, e in ipairs(D.sealed.entrances) do
		if e.region == "outerRing" then
			table.insert(pts, Layout.dirOf(e.at.angleDeg) * e.at.r)
		end
	end
	return pts
end

function PropScatter.data()
	if not cache then
		cache = build()
	end
	return cache
end
function PropScatter.placements()
	return PropScatter.data().placements
end
function PropScatter.reset()
	cache = nil
end

-- 도형 목록에 넣기(WorldMapLayout.buildAll) · 반환 = data
function PropScatter.build(list)
	local out = PropScatter.data()
	for _, p in ipairs(out.placements) do
		PropKit.place(list, "Fill_" .. p.zone, p.prop, p.cf, p.scale, { snap = true })
	end
	for i, ld in ipairs(out.ladders) do
		local model = "Struct_" .. ld.zone .. "_ladder" .. i
		PropKit.place(list, model, "Common_Ladder", ld.cf, Vector3.new(1, ld.height / 10, 1))
		-- 꼭대기 발판: 사다리 꼭대기(윗면 높이)에서 절벽 쪽(+Z)으로
		local topCf = CFrame.lookAt(Vector3.new(ld.base.X, ld.top, ld.base.Z), Vector3.new(ld.base.X, ld.top, ld.base.Z) + ld.out)
		PropKit.place(list, model, "Common_LadderLanding", topCf, Vector3.new(1, 1, ld.landing / 6))
	end
	return out
end

return PropScatter
