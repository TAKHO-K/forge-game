-- M1 맵 기하(순수 - Instance를 만들지 않는다). 수치 = data/WorldMapData. 서버 빌더(server/WorldMap) · 클라 결계 · 길 안내 · 검증 M1(가)가 같은 식을 읽는다.
-- 도형 명세(prim) = { model, name, size(Vector3), cf(CFrame), color({r,g,b}), material, shape("Block"|"Ball"|"Cylinder"|"Wedge"), collide(bool - true면 지면 폴더), attrs }.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)

local Layout = {}

local D = WorldMapData
local L = D.layout
local FLOOR = D.floorTopY

Layout.data = D

-- ─────────────────────────── 좌표 ───────────────────────────
local function dirOf(angleDeg)
	local a = math.rad(angleDeg)
	return Vector3.new(math.cos(a), 0, math.sin(a))
end
local function sideOf(angleDeg)
	local a = math.rad(angleDeg)
	return Vector3.new(-math.sin(a), 0, math.cos(a))
end
Layout.dirOf = dirOf

function Layout.zoneByKey(key)
	for _, z in ipairs(D.zones) do
		if z.key == key then
			return z
		end
	end
	return nil
end

-- 구역 좌표(r · lat) → 월드(y = 지면 윗면 + y)
function Layout.toWorld(zone, r, lat, y)
	return dirOf(zone.angleDeg) * r + sideOf(zone.angleDeg) * (lat or 0) + Vector3.new(0, FLOOR + (y or 0), 0)
end

function Layout.regionCenter(zone)
	return dirOf(zone.angleDeg) * L.regionCenterR
end
function Layout.camp(zone)
	return Layout.toWorld(zone, L.camp.r, L.camp.lat)
end
function Layout.gate(zone)
	return Layout.toWorld(zone, L.gate.r, L.gate.lat)
end
function Layout.grounds(zone)
	local list = {}
	for i, g in ipairs(L.grounds) do
		list[i] = { index = i, center = Layout.toWorld(zone, g.r, g.lat), radius = g.radius }
	end
	return list
end
function Layout.hubPoint(angleDeg, r, y)
	return dirOf(angleDeg) * r + Vector3.new(0, FLOOR + (y or 0), 0)
end
function Layout.facility(name)
	local f = D.hub.facilities[name]
	return Layout.hubPoint(f.angleDeg, f.r)
end
function Layout.spawnPoint()
	return Layout.hubPoint(D.hub.spawn.angleDeg, D.hub.spawn.r)
end
-- 허브 포탈 광장 안 구역 포탈(구역 순서대로 원둘레)
function Layout.hubPortal(zone)
	local plaza = Layout.facility("portal")
	local i = table.find(D.zones, zone) or 1
	local a = (i - 1) / #D.zones * 2 * math.pi
	return plaza + Vector3.new(math.cos(a), 0, math.sin(a)) * D.hub.portalRingRadius
end
function Layout.campPortal(zone)
	return Layout.toWorld(zone, L.camp.r, L.camp.lat + 14)
end

-- 길: 허브 끝 → 결계 문 → 캠프 → 사냥 지대 1 · 2 · 3 → 관문(길 안내 · 거리 표 · 도로 도형)
function Layout.route(zone)
	local points = {
		{ id = "hubEdge", p = dirOf(zone.angleDeg) * D.hub.safeRadius + Vector3.new(0, FLOOR, 0) },
		{ id = "barrierGate", p = Layout.toWorld(zone, L.barrierGateR, 0) },
		{ id = "camp", p = Layout.camp(zone) },
	}
	for i, g in ipairs(Layout.grounds(zone)) do
		table.insert(points, { id = "ground" .. i, p = g.center })
	end
	table.insert(points, { id = "gate", p = Layout.gate(zone) })
	return points
end

function Layout.routeLength(zone, fromId, toId)
	local pts = Layout.route(zone)
	local total, on = 0, false
	for i = 1, #pts do
		if pts[i].id == fromId then
			on = true
		elseif on then
			total += (Vector3.new(pts[i].p.X, 0, pts[i].p.Z) - Vector3.new(pts[i - 1].p.X, 0, pts[i - 1].p.Z)).Magnitude
			if pts[i].id == toId then
				return total
			end
		end
	end
	return total
end

-- 이 점이 어느 구역 원 안인가(없으면 nil)
function Layout.zoneAt(position)
	for _, z in ipairs(D.zones) do
		local c = Layout.regionCenter(z)
		if (Vector3.new(position.X - c.X, 0, position.Z - c.Z)).Magnitude <= L.regionRadius then
			return z
		end
	end
	return nil
end

function Layout.inHub(position)
	return Vector3.new(position.X, 0, position.Z).Magnitude <= D.hub.safeRadius
end

-- ─────────────────────────── 도형 도우미 ───────────────────────────
local function prim(list, model, name, size, cf, color, opts)
	opts = opts or {}
	table.insert(list, {
		model = model, name = name, size = size, cf = cf, color = color or D.colors.block,
		material = opts.material or "Concrete", shape = opts.shape or "Block", collide = opts.collide ~= false,
		transparency = opts.transparency, attrs = opts.attrs, neon = opts.neon,
	})
end
-- 바닥에 선 상자(중심 xz · 윗면 높이 top)
local function column(list, model, name, cfFlat, w, d, top, color, opts)
	prim(list, model, name, Vector3.new(w, top, d), cfFlat * CFrame.new(0, top / 2, 0), color, opts)
end
local function flatYaw(p, lookDir)
	local base = Vector3.new(p.X, FLOOR, p.Z)
	return CFrame.lookAt(base, base + Vector3.new(lookDir.X, 0, lookDir.Z))
end

-- 경사로(쐐기): 바닥 cf에서 앞(-Z 로컬 = lookDir)으로 run만큼 가며 0 → h로 오른다. 높은 면이 앞쪽 끝.
local function ramp(list, model, name, baseCf, run, h, width, color)
	-- WedgePart: 높은 면 = 로컬 +Z · 경사 = -Z(ZoneTerrain 실측 주석). 우리는 앞(-Z)으로 오르게 하려고 Y축 180° 돌린다.
	prim(list, model, name, Vector3.new(width, h, run), baseCf * CFrame.new(0, h / 2, -run / 2) * CFrame.Angles(0, math.pi, 0), color, { shape = "Wedge" })
end

-- ─────────────────────────── 나무 점프맵 ───────────────────────────
-- 발판 목록: { cf, size, section(이름) · difficulty, rise, gap(끝에서 끝), dash, kind = "step" | "checkpoint" | "deck" }
function Layout.treeCourse()
	local tree = D.hub.tree
	local course = tree.course
	local R = tree.trunkRadius + course.ringOffset
	local angle = math.rad(course.startAngleDeg)
	local y = 0 -- 지금 서 있는 발판 윗면(바닥 기준)
	local prevWidth = 0 -- 0 = 바닥(첫 발판은 바닥에서)
	local steps = {}
	local function place(width, rise, gap, info)
		local chord = gap + (prevWidth + width) / 2
		if prevWidth == 0 then
			chord = width / 2 + gap -- 바닥에서 첫 발판: 발판 가장자리까지 gap(바닥은 어디든 선다 - 실제로는 발판 바로 옆에서 뛴다)
		end
		angle += 2 * math.asin(math.clamp(chord / (2 * R), -1, 1))
		y += rise
		local center = Vector3.new(math.cos(angle) * R, 0, math.sin(angle) * R)
		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
		local thickness = 1.5
		local cf = CFrame.lookAt(center + Vector3.new(0, FLOOR + y - thickness / 2, 0), center + Vector3.new(0, FLOOR + y - thickness / 2, 0) + tangent)
		info.cf, info.size, info.rise, info.gap, info.top = cf, Vector3.new(width, thickness, width), rise, gap, y
		info.worldTop = center + Vector3.new(0, FLOOR + y, 0)
		table.insert(steps, info)
		prevWidth = width
	end
	for si, section in ipairs(course.sections) do
		local k = 0
		while true do
			local pat = section.pattern[k % #section.pattern + 1]
			if y + pat.rise > section.untilY - 4 then
				break
			end
			place(section.width, pat.rise, pat.gap, { kind = "step", section = section.name, difficulty = section.difficulty, dash = pat.dash, sectionIndex = si })
			k += 1
		end
		-- 체크포인트: 구간 끝 높이까지 남은 오름(≤ 구간 최대 오름)을 한 번 더 - 넓은 발판
		-- 가지 정거장(구간 1 ~ 5의 끝 - 넓은 발판 · 체크포인트). 마지막 구간은 정거장 없이 전망대 계단으로.
		local station = course.stations[si]
		if station then
			local maxRise = 0
			for _, pat in ipairs(section.pattern) do
				maxRise = math.max(maxRise, pat.rise)
			end
			local rise = math.clamp(section.untilY - y, 2, maxRise)
			place(course.checkpointSize, rise, rise <= 5 and 4 or 6, { kind = "station", station = si, stationName = station.name, unlockLevel = station.unlockLevel, section = section.name, difficulty = section.difficulty, sectionIndex = si })
		end
	end
	-- 전망대까지 쉬운 계단
	while y + 4 < course.deck.y do
		place(5, 4, 4, { kind = "step", section = "전망대 계단", difficulty = "easy", sectionIndex = #course.sections + 1 })
	end
	place(course.checkpointSize, course.deck.y - y, 4, { kind = "deck", section = "정상 전망대", difficulty = "easy", sectionIndex = #course.sections + 1 })
	return steps
end

-- 오르는 시간 추정(보통 실력 가정 secondsPerStep): 반환 = 바닥 → 정상 초, 최고 정거장 → 정상 초, 구간별 { name, steps, seconds, topY }
function Layout.treeClimbSeconds()
	local course = D.hub.tree.course
	local total, fromTop = 0, 0
	local sections, lastStation = {}, 0
	for _, s in ipairs(Layout.treeCourse()) do
		local sec = course.secondsPerStep[s.difficulty]
		total += sec
		if s.kind == "station" then
			lastStation = s.station
			fromTop = 0
		else
			fromTop += sec
		end
		local key = s.section
		sections[key] = sections[key] or { name = key, steps = 0, seconds = 0, topY = 0, order = s.sectionIndex }
		sections[key].steps += 1
		sections[key].seconds += sec
		sections[key].topY = s.top
	end
	local list = {}
	for _, v in pairs(sections) do
		table.insert(list, v)
	end
	table.sort(list, function(a, b)
		return a.order < b.order or (a.order == b.order and a.topY < b.topY)
	end)
	return total, fromTop, list, lastStation
end

-- 정거장 목록(월드 발판 윗면 · 이름 · 기준 레벨)
function Layout.stations()
	local list = {}
	for _, s in ipairs(Layout.treeCourse()) do
		if s.kind == "station" then
			list[s.station] = { index = s.station, name = s.stationName, unlockLevel = s.unlockLevel, top = s.worldTop, size = s.size.X }
		elseif s.kind == "deck" then
			list.deck = { top = s.worldTop, size = s.size.X }
		end
	end
	return list
end

-- ─────────────────────────── 둥지 ───────────────────────────
-- 반환: prims에 도형을 넣고, 메타 { top = 둥지 자리(월드), difficulty, leaps = { { rise, gap, from, to } } }(검증이 이동 표로 잰다)
function Layout.nest(zone, index, list)
	local spec = zone.nests[index]
	local N = D.nest
	local model = "Zone_" .. zone.key
	local look = dirOf(zone.angleDeg)
	local base = Layout.toWorld(zone, spec.r, spec.lat)
	local cf0 = flatYaw(base, look)
	local meta = { difficulty = spec.difficulty, leaps = {}, index = index }
	local c = D.colors.blockLight
	if spec.difficulty == "walk" then
		local w = N.walk
		local run = w.ledgeH / math.tan(math.rad(w.slopeDeg))
		column(list, model, "NestLedge", cf0, w.ledge, w.ledge, w.ledgeH, c)
		ramp(list, model, "NestRamp", cf0 * CFrame.new(0, 0, w.ledge / 2 + run), run, w.ledgeH, w.width, c)
		meta.top = (cf0 * CFrame.new(0, w.ledgeH, 0)).Position
		meta.slopeDeg = w.slopeDeg
	elseif spec.difficulty == "chain" then
		local ch = N.chain
		local spacing = ch.gap + ch.width
		for i = 1, ch.steps do
			local w = i == ch.steps and ch.ledge or ch.width
			local z = -(i - 1) * spacing - (i == ch.steps and (ch.ledge - ch.width) / 2 or 0)
			column(list, model, i == ch.steps and "NestLedge" or "NestStep", cf0 * CFrame.new(0, 0, z), w, w, i * ch.rise, c)
			table.insert(meta.leaps, { rise = ch.rise, gap = ch.gap, need = "easy" })
		end
		meta.top = (cf0 * CFrame.new(0, ch.steps * ch.rise, -(ch.steps - 1) * spacing - (ch.ledge - ch.width) / 2)).Position
	else
		local pz = N.puzzle
		-- 계단 2단(4 · 8) → 기둥(pillarH) → 도약(오름 rise · 간격 gap) → 선반(pillarH + rise)
		local s = pz.stairGap + 4
		column(list, model, "NestStep", cf0 * CFrame.new(0, 0, s * 2), 4, 4, pz.stairRise, c)
		column(list, model, "NestStep", cf0 * CFrame.new(0, 0, s), 4, 4, pz.stairRise * 2, c)
		column(list, model, "NestPillar", cf0, pz.pillarSize, pz.pillarSize, pz.pillarH, c)
		local ledgeZ = -(pz.pillarSize / 2 + pz.gap + pz.ledge / 2)
		local ledgeTop = pz.pillarH + pz.rise
		column(list, model, "NestLedge", cf0 * CFrame.new(0, 0, ledgeZ), pz.ledge, pz.ledge, ledgeTop, c)
		table.insert(meta.leaps, { rise = pz.stairRise, gap = pz.stairGap, need = "easy" })
		table.insert(meta.leaps, { rise = pz.pillarH - pz.stairRise * 2, gap = pz.stairGap, need = "easy" })
		table.insert(meta.leaps, { rise = pz.rise, gap = pz.gap, need = "puzzle" })
		meta.top = (cf0 * CFrame.new(0, ledgeTop, ledgeZ)).Position
		meta.ledgeFromGround = ledgeTop
	end
	-- 자리 표시(기능은 펫 단계)
	prim(list, model, "NestSpot", Vector3.new(N.marker.size, 0.4, N.marker.size), CFrame.new(meta.top + Vector3.new(0, 0.2, 0)), D.colors.marker,
		{ collide = false, neon = true, attrs = { NestZone = zone.key, NestIndex = index, NestDifficulty = spec.difficulty } })
	return meta
end

-- ─────────────────────────── 구역 지형 ───────────────────────────
-- 반환: 탐험 지점 · 이스터에그 자리 목록(월드) - 도형은 list에.
local function buildFeature(zone, f, list)
	local model = "Zone_" .. zone.key
	local look = dirOf(zone.angleDeg)
	local base = Layout.toWorld(zone, f.r, f.lat)
	local cf0 = flatYaw(base, look)
	local points = {}
	local c, cd = D.colors.block, D.colors.blockDark
	if f.kind == "plateau" then
		column(list, model, "Plateau", cf0, f.w, f.d, f.h, c)
		local run = f.h / math.tan(math.rad(35))
		ramp(list, model, "PlateauRamp", cf0 * CFrame.new(0, 0, f.d / 2 + run), run, f.h, 12, c)
		points.top = (cf0 * CFrame.new(0, f.h, 0)).Position
		points.base = (cf0 * CFrame.new(0, 0, f.d / 2 + run + 6)).Position
	elseif f.kind == "tower" then
		column(list, model, "Tower", cf0, f.size, f.size, f.h, cd)
		-- 1단 점프 계단 나선(오름 4 · 간격 4 · 폭 4 - 쉬움) - 탑 둘레 반경 R
		local R = f.size / 2 * math.sqrt(2) + 3
		local a, y = 0, 0
		while y + 4 <= f.h do
			a += 2 * math.asin(8 / (2 * R))
			y += 4
			local p = cf0 * CFrame.new(math.cos(a) * R, 0, math.sin(a) * R)
			column(list, model, "TowerStep", p, 4, 4, y, c)
		end
		points.top = (cf0 * CFrame.new(0, f.h, 0)).Position
		points.base = (cf0 * CFrame.new(0, 0, R + 6)).Position
	elseif f.kind == "cliff" then
		column(list, model, "Cliff", cf0, f.w, f.d, f.h, cd)
		points.base = (cf0 * CFrame.new(0, 0, f.d / 2 + 10)).Position
	elseif f.kind == "cave" then
		local t = 8
		column(list, model, "CaveWall", cf0 * CFrame.new(-(f.w / 2 - t / 2), 0, 0), t, f.d, f.h, cd)
		column(list, model, "CaveWall", cf0 * CFrame.new(f.w / 2 - t / 2, 0, 0), t, f.d, f.h, cd)
		column(list, model, "CaveBack", cf0 * CFrame.new(0, 0, -(f.d / 2 - t / 2)), f.w, t, f.h, cd)
		prim(list, model, "CaveRoof", Vector3.new(f.w, 6, f.d), cf0 * CFrame.new(0, f.h + 3, 0), cd)
		points.inside = (cf0 * CFrame.new(0, 0, -f.d / 4)).Position
		points.base = (cf0 * CFrame.new(0, 0, f.d / 2 + 8)).Position
	elseif f.kind == "falls" then
		-- 폭포 벽(앞) + 뒤 벽 · 사이 공간(옆으로 들어간다)
		prim(list, model, "FallsFront", Vector3.new(f.w, f.h, 4), cf0 * CFrame.new(0, f.h / 2, 0), D.colors.blockLight, { collide = true, transparency = 0.3 })
		column(list, model, "FallsBack", cf0 * CFrame.new(0, 0, -16), f.w + 20, 6, f.h + 10, cd)
		points.behind = (cf0 * CFrame.new(0, 0, -8)).Position
		points.base = (cf0 * CFrame.new(0, 0, 12)).Position
	elseif f.kind == "spire" then
		column(list, model, "Spire", cf0, f.size, f.size, f.h * 0.6, cd)
		column(list, model, "Spire", cf0, f.size * 0.6, f.size * 0.6, f.h, cd)
		points.base = (cf0 * CFrame.new(0, 0, f.size + 6)).Position
	end
	if f.explore then
		local at = points.top or points.inside or points.behind or points.base
		prim(list, model, "ExplorePoint", Vector3.new(4, 4, 4), CFrame.new(at + Vector3.new(0, 2, 0)), D.colors.marker,
			{ collide = false, transparency = 1, attrs = { ExploreName = f.explore, ExploreZone = zone.key } })
	end
	points.footprint = math.max(f.w or 0, f.d or 0, (f.size or 0) * 1.5 + 12) / 2 + ((f.kind == "plateau") and f.h / math.tan(math.rad(35)) or 0)
	points.center = base
	return points
end

local function buildLandmark(zone, list)
	local m = zone.landmark
	local model = "Landmark_" .. zone.key
	local center = Layout.toWorld(zone, m.r + 90, 0)
	local cf0 = flatYaw(center, dirOf(zone.angleDeg))
	local cd = D.colors.blockDark
	if m.kind == "monoliths" or m.kind == "spires" or m.kind == "iceWall" then
		for i = 1, m.count do
			local a = (i - 1) / m.count * 2 * math.pi
			local w = m.kind == "iceWall" and 40 or 10
			column(list, model, "Landmark", cf0 * CFrame.new(math.cos(a) * m.radius, 0, math.sin(a) * m.radius) * CFrame.Angles(0, a, 0), w, 10, m.height * (m.kind == "spires" and (0.6 + 0.4 * (i % 2)) or 1), cd)
		end
	elseif m.kind == "temple" or m.kind == "pyramid" then
		local layers = m.kind == "pyramid" and 6 or 4
		for i = 1, layers do
			local s = m.radius * 2 * (1 - (i - 1) / layers)
			column(list, model, "Landmark", cf0, s, s, m.height * i / layers, cd)
		end
	elseif m.kind == "stormSpire" then
		column(list, model, "Landmark", cf0, m.radius, m.radius, m.height * 0.5, cd)
		column(list, model, "Landmark", cf0, m.radius * 0.6, m.radius * 0.6, m.height, cd)
		column(list, model, "Landmark", cf0, m.radius * 0.3, m.radius * 0.3, m.height + 40, cd)
	end
	return center
end

-- 구역 하나의 도형 + 메타(탐험 · 이스터에그 · 둥지)
function Layout.buildZone(zone, list)
	local model = "Zone_" .. zone.key
	local tint = zone.floorTint
	local center = Layout.regionCenter(zone)
	-- 구역 바닥(옅은 색 원판 - 구역 구분) · 사냥 지대 원판(평평)
	prim(list, "Floor_" .. zone.key, "ZoneFloor", Vector3.new(0.2, L.regionRadius * 2, L.regionRadius * 2), CFrame.new(center.X, FLOOR + 0.1, center.Z) * CFrame.Angles(0, 0, math.rad(90)), tint, { shape = "Cylinder", material = "SmoothPlastic" })
	for _, g in ipairs(Layout.grounds(zone)) do
		prim(list, model, "HuntingGround", Vector3.new(0.2, g.radius * 2, g.radius * 2), CFrame.new(g.center.X, FLOOR + 0.3, g.center.Z) * CFrame.Angles(0, 0, math.rad(90)), D.colors.blockLight, { shape = "Cylinder", material = "SmoothPlastic", attrs = { HuntingGround = g.index, Zone = zone.key } })
	end
	-- 캠프(안전 · 포탈)
	local camp = Layout.camp(zone)
	prim(list, model, "Camp", Vector3.new(0.2, L.camp.radius * 2, L.camp.radius * 2), CFrame.new(camp.X, FLOOR + 0.35, camp.Z) * CFrame.Angles(0, 0, math.rad(90)), D.colors.safe, { shape = "Cylinder", material = "SmoothPlastic" })
	-- 도로(허브 끝 → … → 관문)
	local route = Layout.route(zone)
	for i = 2, #route do
		local a, b = route[i - 1].p, route[i].p
		local mid = (a + b) / 2
		local len = (Vector3.new(b.X - a.X, 0, b.Z - a.Z)).Magnitude
		prim(list, "Floor_" .. zone.key, "Road", Vector3.new(L.roadWidth, 0.2, len + L.roadWidth), CFrame.lookAt(Vector3.new(mid.X, FLOOR + 0.2, mid.Z), Vector3.new(b.X, FLOOR + 0.2, b.Z)), D.colors.road, { material = "SmoothPlastic" })
	end
	-- 결계 문(길이 구역 원을 지나는 자리 - 늘 보인다 · 잠김 표시는 클라)
	local bg = Layout.toWorld(zone, L.barrierGateR, 0)
	local gcf = flatYaw(bg, dirOf(zone.angleDeg))
	local B = D.barrier
	column(list, model, "BarrierGatePost", gcf * CFrame.new(-B.gateWidth / 2, 0, 0), 4, 4, B.gateHeight, D.colors.blockDark)
	column(list, model, "BarrierGatePost", gcf * CFrame.new(B.gateWidth / 2, 0, 0), 4, 4, B.gateHeight, D.colors.blockDark)
	prim(list, model, "BarrierGateTop", Vector3.new(B.gateWidth + 4, 3, 4), gcf * CFrame.new(0, B.gateHeight + 1.5, 0), D.colors.blockDark, { attrs = { BarrierGate = zone.key } })
	-- 보스 관문 + 토벌 관문 자리(BR2)
	local gate = Layout.gate(zone)
	local gatecf = flatYaw(gate, dirOf(zone.angleDeg))
	column(list, model, "BossGatePost", gatecf * CFrame.new(-16, 0, 6), 5, 5, 30, D.colors.blockDark)
	column(list, model, "BossGatePost", gatecf * CFrame.new(16, 0, 6), 5, 5, 30, D.colors.blockDark)
	prim(list, model, "BossGateTop", Vector3.new(37, 4, 5), gatecf * CFrame.new(0, 32, 6), D.colors.blockDark)
	prim(list, model, "BossGatePad", Vector3.new(0.4, L.gate.radius * 2, L.gate.radius * 2), CFrame.new(gate.X, FLOOR + 0.45, gate.Z) * CFrame.Angles(0, 0, math.rad(90)), D.colors.barrier,
		{ shape = "Cylinder", material = "SmoothPlastic", attrs = { BossGate = zone.key } })
	-- 빛기둥(보스 고유 색 - 빌더가 BossData에서 칠한다)
	local P = D.gatePillar
	prim(list, "GatePillars", "GatePillar", Vector3.new(P.width, P.height, P.width), CFrame.new(gate.X, FLOOR + P.height / 2, gate.Z), D.colors.marker,
		{ collide = false, neon = true, transparency = P.transparency, attrs = { GatePillar = zone.key, BossId = zone.bossId } })
	local raid = Layout.toWorld(zone, L.gate.r, L.raidLat)
	local raidcf = flatYaw(raid, dirOf(zone.angleDeg))
	column(list, model, "RaidGatePost", raidcf * CFrame.new(-10, 0, 0), 4, 4, 22, D.colors.block)
	column(list, model, "RaidGatePost", raidcf * CFrame.new(10, 0, 0), 4, 4, 22, D.colors.block)
	prim(list, model, "RaidGateTop", Vector3.new(24, 3, 4), raidcf * CFrame.new(0, 23.5, 0), D.colors.block, { attrs = { RaidGate = zone.key, Label = "토벌 관문(BR2)" } })

	local meta = { features = {}, eggs = {}, nests = {}, explore = {} }
	for i, f in ipairs(zone.features) do
		local pts = buildFeature(zone, f, list)
		meta.features[i] = pts
		if f.explore then
			table.insert(meta.explore, { name = f.explore, position = pts.top or pts.inside or pts.behind or pts.base })
		end
	end
	for _, e in ipairs(zone.eggs) do
		local pts = meta.features[e.feature]
		local at = pts and (pts[e.at] or pts.base)
		if at then
			prim(list, model, "EasterEggSpot", Vector3.new(3, 3, 3), CFrame.new(at + Vector3.new(0, 1.5, 0)), D.colors.marker,
				{ collide = false, transparency = 1, attrs = { EasterEgg = e.id, Zone = zone.key } })
			table.insert(meta.eggs, { id = e.id, position = at })
		end
	end
	for i = 1, #zone.nests do
		meta.nests[i] = Layout.nest(zone, i, list)
	end
	meta.landmark = buildLandmark(zone, list)
	return meta
end

-- ─────────────────────────── 허브 ───────────────────────────
function Layout.buildHub(list)
	local H = D.hub
	local tree = H.tree
	-- 허브 바닥(안전 지대 원판)
	prim(list, "Hub", "HubFloor", Vector3.new(0.2, H.safeRadius * 2, H.safeRadius * 2), CFrame.new(0, FLOOR + 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), D.colors.safe, { shape = "Cylinder", material = "SmoothPlastic" })
	-- 나무(Persistent 모델 "BigTree" - 줄기 + 잎 모델)
	prim(list, "BigTree", "Trunk", Vector3.new(tree.trunkHeight, tree.trunkRadius * 2, tree.trunkRadius * 2), CFrame.new(0, FLOOR + tree.trunkHeight / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), { 110, 100, 92 }, { shape = "Cylinder", material = "Wood" })
	local leaf = tree.leaves.seasons[tree.leaves.season]
	for _, ring in ipairs(tree.leaves.rings) do
		for i = 1, ring.count do
			local a = (i - 1) / ring.count * 2 * math.pi + ring.radius
			prim(list, "BigTree.Leaves", "Leaf", Vector3.new(ring.diameter, ring.diameter, ring.diameter), CFrame.new(math.cos(a) * ring.radius, FLOOR + ring.y, math.sin(a) * ring.radius), leaf.color,
				{ shape = "Ball", material = leaf.material, collide = false })
		end
	end
	-- 뿌리(낮은 경사 - 걸어 넘는다) · 경계 등불
	for i = 1, H.roots.count do
		local a = (i - 0.5) / H.roots.count * 2 * math.pi
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local startP = d * tree.trunkRadius
		local cf = CFrame.lookAt(Vector3.new(startP.X, FLOOR, startP.Z), Vector3.new(startP.X, FLOOR, startP.Z) + d)
		ramp(list, "Hub", "Root", cf * CFrame.new(0, 0, -H.roots.length) * CFrame.Angles(0, math.pi, 0), H.roots.length, H.roots.height, H.roots.width, { 110, 100, 92 })
	end
	for i = 1, H.lanterns.count do
		local a = (i - 1) / H.lanterns.count * 2 * math.pi
		local p = Vector3.new(math.cos(a), 0, math.sin(a)) * H.safeRadius
		prim(list, "Hub", "LanternPost", Vector3.new(1, 8, 1), CFrame.new(p.X, FLOOR + 4, p.Z), D.colors.blockDark, { collide = false })
		prim(list, "Hub", "Lantern", Vector3.new(2, 2, 2), CFrame.new(p.X, FLOOR + 9, p.Z), D.colors.marker, { collide = false, neon = true })
	end
	-- 시설 건물(강화대 · 제단 · 상인은 자기 스크립트가 앞 자리에 세운다 - 건물은 그 뒤 바깥쪽)
	for name, f in pairs(H.facilities) do
		local p = Layout.facility(name)
		local out = dirOf(f.angleDeg)
		if f.size then
			local bp = p + out * (f.size[3] / 2 + 14)
			local cf = flatYaw(bp, -out)
			column(list, "Hub", "Facility_" .. name, cf, f.size[1], f.size[3], f.size[2], D.colors.blockLight, { attrs = { Facility = name, Label = f.displayName } })
		else
			prim(list, "Hub", "PortalPlaza", Vector3.new(0.2, f.radius * 2, f.radius * 2), CFrame.new(p.X, FLOOR + 0.25, p.Z) * CFrame.Angles(0, 0, math.rad(90)), D.colors.blockLight, { shape = "Cylinder", material = "SmoothPlastic", attrs = { Facility = name, Label = f.displayName } })
		end
	end
	-- 커뮤니티 · 시장 자리 표시
	local function spots(fname, entries)
		local p = Layout.facility(fname)
		local f = H.facilities[fname]
		local cf = flatYaw(p, -dirOf(f.angleDeg))
		for _, s in ipairs(entries) do
			column(list, "Hub", "Spot_" .. s.id, cf * CFrame.new(s.offset[1], 0, s.offset[3]), 6, 2, 5, D.colors.block, { attrs = { Spot = s.id, Label = s.label } })
		end
	end
	spots("community", H.communitySpots)
	spots("market", H.marketSpots)
	-- 점프맵 발판(TreeCourse 모델) + 체크포인트 · 전망대 · 알 자리
	for i, s in ipairs(Layout.treeCourse()) do
		local color = s.kind == "step" and D.colors.block or D.colors.blockLight
		prim(list, "TreeCourse", s.kind == "step" and "CourseStep" or (s.kind == "deck" and "Deck" or "Station"), s.size, s.cf, color,
			{ attrs = { CourseIndex = i, CourseSection = s.section, CourseKind = s.kind, Station = s.station, Label = s.stationName and ("%s(Lv %d)"):format(s.stationName, s.unlockLevel) or nil } })
		if s.kind == "station" then
			-- 내려가기 판(허브로 - 떨어짐 복귀 기록을 지운다)
			prim(list, "TreeCourse", "StationDown", Vector3.new(0.3, 4, 4), s.cf * CFrame.new(s.size.X / 2 - 2.5, s.size.Y / 2 + 0.15, 0) * CFrame.Angles(0, 0, math.rad(90)), D.colors.barrier,
				{ shape = "Cylinder", material = "SmoothPlastic", attrs = { StationDown = s.station } })
		end
		if s.kind == "deck" then
			prim(list, "TreeCourse", "DailyEggSpot", Vector3.new(3, 0.4, 3), CFrame.new(s.worldTop + Vector3.new(0, 0.2, 0)), D.colors.marker,
				{ collide = false, neon = true, attrs = { Spot = "dailyEgg", Label = tree.course.dailyEgg.label } })
		end
	end
	-- 덩굴 리프트(허브 바닥) · 구름층(연출 자리 - 옅은 원판 · 충돌 없음)
	local lift = tree.course.lift
	local lp = Layout.hubPoint(lift.angleDeg, lift.r)
	prim(list, "Hub", "VineLift", Vector3.new(0.4, 10, 10), CFrame.new(lp.X, FLOOR + 0.5, lp.Z) * CFrame.Angles(0, 0, math.rad(90)), D.colors.barrier,
		{ shape = "Cylinder", material = "SmoothPlastic", attrs = { VineLift = true, Label = lift.label } })
	local cloud = tree.cloudLayer
	prim(list, "BigTree", "CloudLayer", Vector3.new(cloud.thickness, cloud.radius * 2, cloud.radius * 2), CFrame.new(0, FLOOR + cloud.y, 0) * CFrame.Angles(0, 0, math.rad(90)), { 245, 245, 250 },
		{ shape = "Cylinder", material = "SmoothPlastic", collide = false, transparency = cloud.transparency })
	-- 허브 포탈 판(구역마다 - 개방 여부는 서버 · 클라)
	for _, z in ipairs(D.zones) do
		local p = Layout.hubPortal(z)
		prim(list, "Hub", "HubPortal", Vector3.new(0.4, D.travel.portalRadius * 2, D.travel.portalRadius * 2), CFrame.new(p.X, FLOOR + 0.5, p.Z) * CFrame.Angles(0, 0, math.rad(90)), D.colors.barrier,
			{ shape = "Cylinder", material = "SmoothPlastic", attrs = { Portal = z.key, PortalSide = "hub" } })
	end
end

-- ─────────────────────────── 세계 전체 ───────────────────────────
-- 반환: prims, meta{ zones[key] = 구역 메타 }
function Layout.buildAll()
	local list = {}
	-- 바닥 타일(세계 원 안)
	local T = D.floorTileStuds
	local n = math.ceil(D.worldRadiusStuds / T)
	for ix = -n, n - 1 do
		for iz = -n, n - 1 do
			local cx, cz = (ix + 0.5) * T, (iz + 0.5) * T
			local nearest = Vector3.new(math.clamp(0, ix * T, (ix + 1) * T), 0, math.clamp(0, iz * T, (iz + 1) * T)).Magnitude
			if nearest < D.worldRadiusStuds then
				prim(list, "Floor", "FloorTile", Vector3.new(T, D.floorThickness, T), CFrame.new(cx, FLOOR - D.floorThickness / 2, cz), D.colors.ground, { material = "SmoothPlastic" })
			end
		end
	end
	-- 세계 끝: 투명 벽 + 낮은 능선
	local E = D.edge
	for i = 1, E.segments do
		local a = (i - 0.5) / E.segments * 2 * math.pi
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local len = 2 * math.pi * E.radius / E.segments + 4
		local p = d * E.radius
		local cf = CFrame.lookAt(Vector3.new(p.X, FLOOR, p.Z), Vector3.new(p.X, FLOOR, p.Z) + d)
		prim(list, "Edge", "EdgeWall", Vector3.new(len, E.wallHeight, 4), cf * CFrame.new(0, E.wallHeight / 2 - 2, 2), D.colors.block, { transparency = 1 })
		prim(list, "Edge", "EdgeRidge", Vector3.new(len, E.ridgeHeight, E.ridgeWidth), cf * CFrame.new(0, E.ridgeHeight / 2, -E.ridgeWidth / 2 - 4), D.colors.blockDark)
	end
	Layout.buildHub(list)
	local meta = { zones = {} }
	for _, z in ipairs(D.zones) do
		meta.zones[z.key] = Layout.buildZone(z, list)
	end
	return list, meta
end

-- 결계 벽 조각(클라 - 잠긴 구역마다). 구역 원 둘레를 segmentLength로 나눈 투명 벽 + 발밑 빛 선.
function Layout.barrierSegments(zone)
	local B = D.barrier
	local c = Layout.regionCenter(zone)
	local R = L.regionRadius
	local count = math.ceil(2 * math.pi * R / B.segmentLength)
	local list = {}
	for i = 1, count do
		local a = (i - 0.5) / count * 2 * math.pi
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local p = c + d * R
		local len = 2 * math.pi * R / count + 2
		local cf = CFrame.lookAt(Vector3.new(p.X, FLOOR, p.Z), Vector3.new(p.X, FLOOR, p.Z) + d)
		-- 세계 밖으로 나간 조각은 만들지 않는다(세계 끝 벽이 막는다)
		if Vector3.new(p.X, 0, p.Z).Magnitude < D.edge.radius then
			table.insert(list, { cf = cf, length = len })
		end
	end
	return list
end

-- ─────────────────────────── 검증(순수) ───────────────────────────
-- 배치 규칙 위반 목록: 지형 · 둥지가 사냥 지대 · 도로 · 캠프 · 관문과 겹침 · 구역 원 밖 · 세계 밖.
function Layout.validate()
	local problems = {}
	local function segDist(p, a, b)
		local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local ap = Vector3.new(p.X - a.X, 0, p.Z - a.Z)
		local t = math.clamp(ap:Dot(ab) / math.max(ab:Dot(ab), 1e-6), 0, 1)
		return (ap - ab * t).Magnitude
	end
	for _, z in ipairs(D.zones) do
		local route = Layout.route(z)
		local center = Layout.regionCenter(z)
		local keep = {}
		for _, g in ipairs(Layout.grounds(z)) do
			table.insert(keep, { p = g.center, r = g.radius + 30, what = "사냥 지대 " .. g.index })
		end
		table.insert(keep, { p = Layout.camp(z), r = L.camp.radius + 20, what = "캠프" })
		table.insert(keep, { p = Layout.gate(z), r = 60, what = "관문" })
		local function check(name, p, radius)
			for _, k in ipairs(keep) do
				if (Vector3.new(p.X - k.p.X, 0, p.Z - k.p.Z)).Magnitude < radius + k.r then
					table.insert(problems, ("%s %s: %s와 겹침"):format(z.key, name, k.what))
				end
			end
			for i = 2, #route do
				if segDist(p, route[i - 1].p, route[i].p) < radius + L.roadWidth / 2 + 4 then
					table.insert(problems, ("%s %s: 도로 %s→%s와 겹침"):format(z.key, name, route[i - 1].id, route[i].id))
				end
			end
			if (Vector3.new(p.X - center.X, 0, p.Z - center.Z)).Magnitude + radius > L.regionRadius - 10 then
				table.insert(problems, ("%s %s: 구역 원 밖(결계에 걸림)"):format(z.key, name))
			end
		end
		local solids = {} -- 지형 · 둥지끼리도 겹치지 않게
		for i, f in ipairs(z.features) do
			local footprint = math.max(f.w or 0, f.d or 0, (f.size or 0) * 1.5 + 12) / 2 + ((f.kind == "plateau") and f.h / math.tan(math.rad(35)) or 0)
			local p = Layout.toWorld(z, f.r, f.lat)
			check(("지형 %d(%s)"):format(i, f.kind), p, footprint)
			table.insert(solids, { name = ("지형 %d"):format(i), p = p, r = footprint })
		end
		for i, n in ipairs(z.nests) do
			local meta = Layout.nest(z, i, {})
			local p = Layout.toWorld(z, n.r, n.lat)
			check(("둥지 %d(%s) 시작"):format(i, n.difficulty), p, 20)
			check(("둥지 %d(%s) 끝"):format(i, n.difficulty), meta.top, 12)
			table.insert(solids, { name = ("둥지 %d"):format(i), p = p, r = 20 })
			table.insert(solids, { name = ("둥지 %d 끝"):format(i), p = meta.top, r = 12 })
		end
		for i = 1, #solids do
			for j = i + 1, #solids do
				local a, b = solids[i], solids[j]
				local same = a.name:match("^둥지 %d+") and a.name:match("^둥지 %d+") == b.name:match("^둥지 %d+")
				if not same and (Vector3.new(a.p.X - b.p.X, 0, a.p.Z - b.p.Z)).Magnitude < a.r + b.r + 6 then
					table.insert(problems, ("%s %s와 %s 겹침"):format(z.key, a.name, b.name))
				end
			end
		end
	end
	return problems
end

return Layout
