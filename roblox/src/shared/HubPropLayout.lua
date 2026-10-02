-- QUEUE-ALL8 B 허브 소품 배치 기하(순수 - Instance를 만들지 않는다). 배치(server/HubArt) · 검사(server/HubPathVerify.props)가 같은 식을 쓴다. 수치 = data/HubPropsData.
--   list() = 모든 소품 { kind, cf(바닥 · 앞 −Z), rgb, source } · clearViolations(pos, radius) = 비워 둘 거리를 어긴 항목 이름 목록(빈 표 = 통과).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local D = require(ReplicatedStorage.Shared.data.HubPropsData)
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)
local RoadNet = require(ReplicatedStorage.Shared.RoadNet)

local HubPropLayout = {}
local H = WorldMapData.hub
local FLOOR = WorldMapData.floorTopY

local function dirOf(angleDeg)
	local a = math.rad(angleDeg)
	return Vector3.new(math.cos(a), 0, math.sin(a))
end

-- 시설 프레임(바닥 가운데 · 로컬 −Z = 나무 쪽 · +X = 거리 방향) - WorldMapLayout.spot과 같은 식
function HubPropLayout.facilityFrame(name)
	local f = H.facilities[name]
	local p = WorldMapLayout.facility(name)
	local base = Vector3.new(p.X, FLOOR, p.Z)
	return CFrame.lookAt(base, base - dirOf(f.angleDeg))
end

function HubPropLayout.frameOf(e)
	local cf
	if e.facility then
		cf = HubPropLayout.facilityFrame(e.facility) * CFrame.new(e.along or 0, 0, e.side or 0)
	else
		local p = WorldMapLayout.hubPoint(e.angleDeg, e.r)
		local base = Vector3.new(p.X, FLOOR, p.Z)
		cf = CFrame.lookAt(base, Vector3.new(0, FLOOR, 0)) -- 앞 = 허브 가운데(나무)
	end
	return cf * CFrame.Angles(0, math.rad(e.yaw or 0), 0)
end

local function segDist(p, a, b)
	local ab = b - a
	local t = ab.Magnitude > 0 and math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1) or 0
	return (p - (a + ab * t)).Magnitude
end

local cache
local function geometry()
	if cache then
		return cache
	end
	local g = { roads = {}, corridors = {}, spots = {}, buildings = {}, floors = {}, centers = {} }
	for _, path in ipairs(RoadNet.all()) do
		for i = 2, #path.pts do
			local a, b = path.pts[i - 1], path.pts[i]
			if Vector2.new(a.x, a.z).Magnitude < H.safeRadius + 100 then
				table.insert(g.roads, { Vector2.new(a.x, a.z), Vector2.new(b.x, b.z) })
			end
		end
	end
	local anchors = {}
	local cp = WorldMapLayout.hubPoint(-65, 180)
	local sp = WorldMapLayout.spawnPoint()
	table.insert(anchors, Vector2.new(cp.X, cp.Z))
	table.insert(anchors, Vector2.new(sp.X, sp.Z))
	local targets = {}
	for _, name in ipairs(WorldMapLayout.facilityOrder) do
		local c = WorldMapLayout.facility(name)
		table.insert(targets, Vector2.new(c.X, c.Z))
		table.insert(g.centers, Vector2.new(c.X, c.Z))
		local f = H.facilities[name]
		for _, s in ipairs(f.spots or {}) do
			local q = WorldMapLayout.spot(s.id)
			if q then
				table.insert(targets, Vector2.new(q.X, q.Z))
				table.insert(g.spots, Vector2.new(q.X, q.Z))
			end
		end
		for _, b in ipairs(WorldMapLayout.rowBuildings(name)) do
			table.insert(g.buildings, b)
		end
		local cf = HubPropLayout.facilityFrame(name)
		if f.radius then
			table.insert(g.floors, { disc = Vector2.new(c.X, c.Z), r = f.radius })
		elseif f.plaza then
			table.insert(g.floors, { disc = Vector2.new(c.X, c.Z), r = f.plaza })
		elseif f.street then
			table.insert(g.floors, { rect = cf * CFrame.new(0, 0, 4), w = f.street.w, d = f.street.d })
		end
	end
	for _, zone in ipairs(WorldMapData.zones) do
		local first = RoadNet.zonePath(zone).pts[1]
		table.insert(targets, Vector2.new(first.x, first.z))
	end
	for _, a in ipairs(anchors) do
		for _, t in ipairs(targets) do
			table.insert(g.corridors, { a, t })
		end
	end
	-- 나무 입구(코스 시작 안내판) · 리프트
	local course = H.tree.course
	if course and course.station and course.entranceBoard then
		local q = WorldMapLayout.hubPoint(course.station.startAngleDeg, course.entranceBoard.r)
		table.insert(g.spots, Vector2.new(q.X, q.Z))
	end
	g.rootAngles = table.clone(H.tree.roots.angles)
	table.insert(g.rootAngles, H.tree.courseRoot.angleDeg)
	cache = g
	return g
end

-- 비워 둘 거리를 어긴 항목(빈 표 = 통과). radius = 소품 반지름(겉 크기 반)
function HubPropLayout.clearViolations(pos, radius, kind)
	local C = D.clear
	local g = geometry()
	local p = Vector2.new(pos.X, pos.Z)
	local out = {}
	for _, s in ipairs(g.roads) do
		if segDist(p, s[1], s[2]) < C.road + radius then
			table.insert(out, "구역 길")
			break
		end
	end
	for _, s in ipairs(g.corridors) do
		if segDist(p, s[1], s[2]) < C.corridor + radius then
			table.insert(out, "걷는 길")
			break
		end
	end
	for _, s in ipairs(g.spots) do
		if (p - s).Magnitude < C.spot + radius then
			table.insert(out, "기능 자리")
			break
		end
	end
	for _, c in ipairs(g.centers) do
		if (p - c).Magnitude < 10 + radius then
			table.insert(out, "시설 가운데")
			break
		end
	end
	for _, b in ipairs(g.buildings) do
		local l = b.cf:PointToObjectSpace(Vector3.new(pos.X, FLOOR, pos.Z))
		if math.abs(l.X) < b.w / 2 + C.building + radius and math.abs(l.Z) < b.d / 2 + C.building + radius then
			table.insert(out, "건물")
			break
		end
	end
	local r = p.Magnitude
	if r < C.rootR then
		local a = (math.deg(math.atan2(p.Y, p.X)) + 360) % 360
		for _, ra in ipairs(g.rootAngles) do
			local d = math.abs(((a - ra + 540) % 360) - 180)
			if d < C.rootAngleDeg then
				table.insert(out, "나무 뿌리")
				break
			end
		end
	end
	return out
end

-- 거리 · 광장 바닥 위인가(흩뿌리기 금지 · 손 배치는 허용)
function HubPropLayout.onFloor(pos, radius)
	local g = geometry()
	local p = Vector2.new(pos.X, pos.Z)
	for _, f in ipairs(g.floors) do
		if f.disc and (p - f.disc).Magnitude < f.r + D.clear.floor + radius then
			return true
		elseif f.rect then
			local l = f.rect:PointToObjectSpace(Vector3.new(pos.X, FLOOR, pos.Z))
			if math.abs(l.X) < f.w / 2 + D.clear.floor + radius and math.abs(l.Z) < f.d / 2 + D.clear.floor + radius then
				return true
			end
		end
	end
	return false
end

function HubPropLayout.floors()
	return geometry().floors
end

-- 활동 영역(시설 · 기능 자리 · 체크포인트 · 스폰 radius 안)
local function inActivity(p, radius)
	local g = geometry()
	local cp = WorldMapLayout.hubPoint(-65, 180)
	local sp = WorldMapLayout.spawnPoint()
	local pts = { Vector2.new(cp.X, cp.Z), Vector2.new(sp.X, sp.Z) }
	for _, c in ipairs(g.centers) do
		table.insert(pts, c)
	end
	for _, s in ipairs(g.spots) do
		table.insert(pts, s)
	end
	for _, q in ipairs(pts) do
		if (p - q).Magnitude <= radius then
			return true
		end
	end
	return false
end

-- 모든 소품(배치 순서 고정): 손 배치 → 거리 랜턴 → 울타리 → 흩뿌리기. sizeOf(kind) = 겉 크기 반지름(HubArtMeta bounds)
--   비워 둘 거리를 어기는 것은 놓지 않는다(손 배치 · 랜턴 · 울타리도 - 빠진 것 = dropped로 돌려준다 · 울타리는 길이 지나는 칸만 비어 문이 된다).
function HubPropLayout.list(sizeOf)
	local out, dropped = {}, {}
	local NUDGE = { { 0, 0 }, { 0, 4 }, { 0, -4 }, { 4, 0 }, { -4, 0 }, { 4, 4 }, { -4, 4 }, { 4, -4 }, { -4, -4 }, { 0, 8 }, { 0, -8 }, { 8, 0 }, { -8, 0 }, { 8, 8 }, { -8, 8 }, { 8, -8 }, { -8, -8 } }
	local function add(e, nudge) -- nudge = 8 stud 안에서 가장 가까운 비워 둘 거리 밖 자리로 옮겨 본다(손 배치 · 랜턴 - 뜻은 그대로)
		for _, o in ipairs(nudge and NUDGE or { { 0, 0 } }) do
			local cf = e.cf * CFrame.new(o[1], 0, o[2])
			if #HubPropLayout.clearViolations(cf.Position, sizeOf(e.kind) * 0.6, e.kind) == 0 then
				e.cf = cf
				e.nudged = o[1] ~= 0 or o[2] ~= 0
				table.insert(out, e)
				return
			end
		end
		table.insert(dropped, e)
	end
	for _, e in ipairs(D.placements) do
		add({ kind = e.kind, cf = HubPropLayout.frameOf(e), rgb = e.rgb, source = "hand" }, true)
	end
	for _, e in ipairs(D.lanterns) do
		add({ kind = "prop_lantern", cf = HubPropLayout.frameOf(e), source = "lantern" }, true)
	end
	local F = D.fences
	for _, name in ipairs(F.facilities) do
		local rows = WorldMapLayout.rowBuildings(name)
		if #rows > 0 then
			local cf = HubPropLayout.facilityFrame(name)
			local minX, maxX, back = math.huge, -math.huge, -math.huge
			for _, b in ipairs(rows) do
				local l = cf:PointToObjectSpace(b.cf.Position)
				minX = math.min(minX, l.X - b.w / 2)
				maxX = math.max(maxX, l.X + b.w / 2)
				back = math.max(back, l.Z + b.d / 2)
			end
			minX, maxX = minX - F.edgeExtra, maxX + F.edgeExtra
			local n = math.max(1, math.floor((maxX - minX) / F.segment))
			for i = 0, n - 1 do
				local x = minX + (i + 0.5) * (maxX - minX) / n
				add({ kind = F.kind, cf = cf * CFrame.new(x, 0, back + F.backGap), source = "fence" })
			end
		end
	end
	local S = D.scatter
	local rng = Random.new(S.seed)
	local total = 0
	for _, k in ipairs(S.kinds) do
		total += k.weight
	end
	for x = -S.rMax, S.rMax, S.spacing do
		for z = -S.rMax, S.rMax, S.spacing do
			local jx, jz = rng:NextNumber(-1, 1) * S.spacing * S.jitter, rng:NextNumber(-1, 1) * S.spacing * S.jitter
			local roll = rng:NextNumber(0, total)
			local yaw = rng:NextNumber(0, 360)
			local px, pz = x + jx, z + jz
			local r = math.sqrt(px * px + pz * pz)
			if r >= S.rMin and r <= S.rMax and inActivity(Vector2.new(px, pz), S.activityRadius) then
				local kind
				for _, k in ipairs(S.kinds) do
					roll -= k.weight
					if roll <= 0 and not kind then
						kind = k.kind
					end
				end
				kind = kind or S.kinds[1].kind
				local pos = Vector3.new(px, FLOOR, pz)
				local rad = sizeOf(kind)
				if #HubPropLayout.clearViolations(pos, rad, kind) == 0 and not HubPropLayout.onFloor(pos, rad) then
					table.insert(out, { kind = kind, cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(yaw), 0), source = "scatter" })
				end
			end
		end
	end
	return out, dropped
end

return HubPropLayout
