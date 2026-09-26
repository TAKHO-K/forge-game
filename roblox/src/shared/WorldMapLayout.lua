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

-- M1-3 관문 등록: 보스 관문 목록 = BossData 보스마다 gate 칸(zone = 구역 관문 자리 · at = { angleDeg, r } = 구역 없는 새 보스). 새 보스는 gate 한 줄로 등록 · 원격 입장 · 길 안내가 붙는다.
-- 반환: { { bossId, name, zoneKey(없을 수 있음), position(지면), dir(관문이 보는 바깥 방향), color({r,g,b}) } } - 보스 id 순(고정)
local gateCache = nil
function Layout.bossGates()
	if gateCache then
		return gateCache
	end
	local BossData = require(ReplicatedStorage.Shared.data.BossData)
	gateCache = {}
	local ids = {}
	for id, boss in pairs(BossData.bosses) do
		if boss.gate then
			table.insert(ids, id)
		end
	end
	table.sort(ids) -- 고정 순서(pairs 순서에 기대지 않는다)
	for _, id in ipairs(ids) do
		local boss = BossData.bosses[id]
		local g = boss.gate
		do
			local zone = g.zone and Layout.zoneByKey(g.zone)
			local position, dir
			if zone then
				position, dir = Layout.gate(zone), dirOf(zone.angleDeg)
			else
				dir = dirOf(g.at.angleDeg)
				position = dir * g.at.r + Vector3.new(0, FLOOR, 0)
			end
			table.insert(gateCache, { bossId = boss.id, name = boss.displayName, zoneKey = zone and zone.key or nil, position = position, dir = dir, color = g.color })
		end
	end
	return gateCache
end
function Layout.bossGate(bossId)
	for _, g in ipairs(Layout.bossGates()) do
		if g.bossId == bossId then
			return g
		end
	end
	return nil
end
-- 관문까지 길(길 안내): 구역 관문 = 구역 길 · 구역 없는 관문 = 허브 끝 → 관문 직선
function Layout.bossGateRoute(bossId)
	local g = Layout.bossGate(bossId)
	if not g then
		return nil
	end
	local zone = g.zoneKey and Layout.zoneByKey(g.zoneKey)
	local list = {}
	if zone then
		list = require(ReplicatedStorage.Shared.RoadNet).guidePoints(zone) -- M1-4 곡선 길을 따라
	else
		table.insert(list, g.dir * D.hub.safeRadius + Vector3.new(0, FLOOR, 0))
		table.insert(list, g.position)
	end
	return list
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
Layout.facilityOrder = { "portal", "forge", "market", "community" } -- 짓는 순서(고정 - pairs 순서에 기대지 않는다)
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
	-- M1-4: 곡선 길 길이(RoadNet) - 옛 직선 길이는 Layout.routeLengthStraight
	return require(ReplicatedStorage.Shared.RoadNet).length(zone, fromId, toId)
end
function Layout.routeLengthStraight(zone, fromId, toId)
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

-- ─────────────────────────── 몬스터 스폰 범위(M1-2) ───────────────────────────
-- 지형이 차지하는 반경(스폰 지점이 피한다 · buildFeature의 footprint와 같은 식)
local function featureFootprint(f)
	return math.max(f.w or 0, f.d or 0, (f.size or 0) * 1.5 + 12) / 2 + ((f.kind == "plateau") and f.h / math.tan(math.rad(35)) or 0)
end

-- 구역의 스폰 범위: { zoneKey, name, center(지면), radius, monsters }
function Layout.huntRange(zone)
	local H = D.spawnSites.huntRange
	return { zoneKey = zone.key, name = zone.hunt.name, center = Layout.toWorld(zone, H.r, H.lat), radius = H.radius, monsters = zone.hunt.monsters }
end

-- 이 점이 어느 스폰 범위 안인가(없으면 nil) - 클라 지역명 · 검증
function Layout.huntRangeAt(position)
	for _, z in ipairs(D.zones) do
		local range = Layout.huntRange(z)
		if Vector3.new(position.X - range.center.X, 0, position.Z - range.center.Z).Magnitude <= range.radius then
			return range, z
		end
	end
	return nil
end

-- 스폰 지점(캐시 · 고정 시드): [i] = { index, position(지면), slots = { 지면 위치 × group.count } }. 범위 안에 흩어 둔다(최소 간격 · 캠프 · 관문 · 옛 지형 · 둥지 · 선인장 밭 회피).
-- M1-3 지형: 슬롯 + 둘레가 걷는 땅이어야 한다 - 물 없음 · 높이 차(가운데 · 슬롯 · 둘레 표본) ≤ terrain.maxRelief · 평지 위 terrain.maxAbove 이하(능선 · 대지 위 금지). 슬롯 높이 = 지형 윗면.
local huntPointCache = {}
function Layout.huntPoints(zone)
	if huntPointCache[zone.key] then
		return huntPointCache[zone.key]
	end
	local TerrainShape = require(ReplicatedStorage.Shared.TerrainShape)
	local WorldStructures = require(ReplicatedStorage.Shared.WorldStructures)
	local WSD = require(ReplicatedStorage.Shared.data.WorldStructureData)
	local S = D.spawnSites
	local TT = S.terrain
	local range = Layout.huntRange(zone)
	local seed = (S.seed + (table.find(D.zones, zone) or 1) * 7919) % 2147483647
	local function rand()
		seed = (seed * 48271) % 2147483647
		return seed / 2147483647
	end
	local blockers = {
		{ p = Layout.camp(zone), r = S.avoid.camp },
		{ p = Layout.gate(zone), r = S.avoid.gate },
	}
	for _, f in ipairs(zone.features) do
		table.insert(blockers, { p = Layout.toWorld(zone, f.r, f.lat), r = featureFootprint(f) + S.avoid.feature })
	end
	for _, n in ipairs(WorldStructures.nestList()) do
		if n.zone == zone.key then
			local c = n.cf and n.cf.Position or n.spot
			local r = (n.pads and n.pads[1] and n.pads[1].radius) or 10
			table.insert(blockers, { p = c, r = math.max(r, 12) + S.avoid.nest })
		end
	end
	if WSD.cactus.zone == zone.key then
		for _, f in ipairs(WSD.cactus.fields) do
			table.insert(blockers, { p = Layout.toWorld(zone, f.r, f.lat), r = f.outer + S.avoid.cactus })
		end
	end
	local function flat(a, b)
		return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
	end
	-- 걷는 땅인가(물 · 경사 · 높이) - 반환: ok, 슬롯 높이 목록
	local function groundOk(p, turn)
		local hs = {}
		local lo, hi = math.huge, -math.huge
		local function sample(x, z)
			local c = TerrainShape.column(x, z)
			if c.water then
				return nil
			end
			lo, hi = math.min(lo, c.h), math.max(hi, c.h)
			return c.h
		end
		local h0 = sample(p.X, p.Z)
		if not h0 then
			return false
		end
		for k = 1, S.group.count do
			local sa = turn + (k - 1) / S.group.count * 2 * math.pi
			local h = sample(p.X + math.cos(sa) * S.group.radius, p.Z + math.sin(sa) * S.group.radius)
			if not h then
				return false
			end
			hs[k] = h
		end
		for k = 0, TT.ringSamples - 1 do
			local a = k / TT.ringSamples * 2 * math.pi
			if not sample(p.X + math.cos(a) * TT.ringRadius, p.Z + math.sin(a) * TT.ringRadius) then
				return false
			end
		end
		return hi - lo <= TT.maxRelief and hi - TerrainShape.flatY <= TT.maxAbove, hs
	end
	local points = {}
	local maxR = range.radius - S.edgeMargin - S.group.radius
	for _ = 1, 12000 do
		if #points >= S.pointsPerRange then
			break
		end
		local a, rr = rand() * 2 * math.pi, math.sqrt(rand()) * maxR
		local p = range.center + Vector3.new(math.cos(a) * rr, 0, math.sin(a) * rr)
		local turn = rand() * 2 * math.pi
		local ok = true
		for _, b in ipairs(blockers) do
			if flat(p, b.p) < b.r + S.group.radius then
				ok = false
				break
			end
		end
		for _, q in ipairs(points) do
			if not ok then
				break
			end
			ok = flat(p, q.position) >= S.pointSpacing
		end
		local hs
		if ok then
			ok, hs = groundOk(p, turn)
		end
		if ok then
			local slots = {}
			for k = 1, S.group.count do
				local sa = turn + (k - 1) / S.group.count * 2 * math.pi
				slots[k] = Vector3.new(p.X + math.cos(sa) * S.group.radius, hs[k], p.Z + math.sin(sa) * S.group.radius)
			end
			local c = TerrainShape.column(p.X, p.Z)
			table.insert(points, { index = #points + 1, position = Vector3.new(p.X, c.h, p.Z), slots = slots })
		end
	end
	huntPointCache[zone.key] = points
	return points
end

-- ─────────────────────────── 도형 도우미 ───────────────────────────
local function prim(list, model, name, size, cf, color, opts)
	opts = opts or {}
	table.insert(list, {
		model = model, name = name, size = size, cf = cf, color = color or D.colors.block,
		material = opts.material or "Concrete", shape = opts.shape or "Block", collide = opts.collide ~= false,
		transparency = opts.transparency, attrs = opts.attrs, neon = opts.neon, mesh = opts.mesh, query = opts.query,
	})
end
-- 바닥에 선 상자(중심 xz · 윗면 높이 top). M1-3: 지형 위에 서므로 밑을 COLUMN_SINK만큼 땅속으로(복셀 높이 오차 · 뜬 틈 방지)
local COLUMN_SINK = 2
local function column(list, model, name, cfFlat, w, d, top, color, opts)
	prim(list, model, name, Vector3.new(w, top + COLUMN_SINK, d), cfFlat * CFrame.new(0, (top - COLUMN_SINK) / 2, 0), color, opts)
end
local function flatYaw(p, lookDir)
	local base = Vector3.new(p.X, FLOOR, p.Z)
	return CFrame.lookAt(base, base + Vector3.new(lookDir.X, 0, lookDir.Z))
end


-- 삼각형(a, b, c) = 쐐기 2개(로우폴리 면 - 메시 에셋 없이). 반환 = { { size, cf }, { size, cf } }. 두께 thickness(안쪽으로).
function Layout.triangle(a, b, c, thickness)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	return {
		{ size = Vector3.new(thickness, height, math.abs(ab:Dot(back))), cf = CFrame.fromMatrix((a + b) / 2, right, up, back) },
		{ size = Vector3.new(thickness, height, math.abs(ac:Dot(back))), cf = CFrame.fromMatrix((a + c) / 2, -right, up, -back) },
	}
end

-- 이동 한 번(오름 rise · 간격 gap - 끝에서 끝)에 필요한 가장 쉬운 기술(movement-metrics v2 - 간격은 80% 여유 · 높이는 최대 도달 − 0.3).
-- 반환: 난이도("easy" | "normal" | "hard") · 조합 이름 | nil, "불가". 격자 계산이라 결과를 캐시한다(검증 · 시간 표 전용 - 매 프레임 쓰지 않는다).
local skillCache = {}
local COMBOS = {
	{ name = "1단", air = 0, dash = false, skill = "easy" },
	{ name = "공중1", air = 1, dash = false, skill = "normal" },
	{ name = "공중2", air = 2, dash = false, skill = "normal" },
	{ name = "1단+대시", air = 0, dash = true, skill = "hard" },
	{ name = "공중1+대시", air = 1, dash = true, skill = "hard" },
	{ name = "공중2+대시", air = 2, dash = true, skill = "hard" },
}
function Layout.moveSkill(rise, gap)
	local JumpMath = require(ReplicatedStorage.Shared.JumpMath)
	local MC = require(ReplicatedStorage.Shared.data.MovementConfig)
	for _, c in ipairs(COMBOS) do
		local key = c.name .. ":" .. math.floor(math.max(rise, 0) * 2 + 0.5)
		local g = skillCache[key]
		if not g then
			local air = JumpMath.maxAirSeconds(MC.jumpHeightStuds, c.air, c.dash and 0.3 or nil, math.max(rise, 0), nil, 24)
			g = MC.walkSpeedStuds * (air - (c.dash and 0.3 or 0)) + (c.dash and 16 or 0)
			skillCache[key] = g
		end
		if rise <= JumpMath.maxReachStuds(MC.jumpHeightStuds, c.air) - 0.3 and gap <= 0.8 * g then
			return c.skill, c.name
		end
	end
	return nil, "불가"
end

-- ─────────────────────────── 나무 점프맵(M1 재설계 - 두 갈래 길) ───────────────────────────
-- 결과(캐시): { elements = { … }, moves = { … }, stations = { … }, deck, tunnels = { … } }
--   element = { leg, path("inner" | "outer"), index, k, center(Vector3), top(서 있는 윗면 Y), angle, radius, spec }
--   move = { leg, path, from, to, rise, gap, via("jump" | "bounce" | "launch" | "climb" | "ring" | "tunnel" | "start"), k(도착 요소 종류) } - 검증 · 시간 표
local treeCache = nil

local function tangentAt(angle, dir)
	return Vector3.new(-math.sin(angle), 0, math.cos(angle)) * dir
end

-- 길을 따라 차지하는 반길이(원통 가지 · 잎 = 길이 방향 · 열매 = 지름 · 덩굴 = 1)
local function halfAlong(spec)
	local k = spec.k
	if k == "branch" or k == "leaf" then
		return spec.len / 2
	elseif k == "bounce" or k == "soft" or k == "hang" then
		return spec.dia / 2
	elseif k == "pad" then
		return (spec.padSize or 7) / 2
	elseif k == "vine" then
		return 1
	elseif k == "step" then
		return spec.w / 2
	end
	return 2
end

-- 밟는 칸 크기 배율(course.elementScale) 적용본 - 간격 · 오름(끝에서 끝)은 그대로, 칸만 작아진다
local function scaledSpec(spec, scale)
	local s = table.clone(spec)
	if s.len then
		s.len = s.len * scale
	end
	if s.dia and (s.k == "bounce" or s.k == "soft" or s.k == "hang") then
		s.dia = math.max(4, s.dia * scale)
	end
	if s.w then
		s.w = math.max(2.5, s.w * scale)
	end
	s.padSize = 7 * scale
	return s
end

function Layout.tree()
	if treeCache then
		return treeCache
	end
	local tree = D.hub.tree
	local C = tree.course
	local out = { elements = {}, moves = {}, stations = {}, tunnels = {} }
	local St = C.station
	local startAngle = math.rad(St.startAngleDeg)
	local pathState = {
		inner = { angle = startAngle, y = 0, half = 0, prevK = "ground" },
		outer = { angle = startAngle, y = 0, half = 0, prevK = "ground" },
	}
	for legIndex, leg in ipairs(C.legs) do
		for _, pathName in ipairs({ "inner", "outer" }) do
			local P = C[pathName]
			local s = pathState[pathName]
			local pattern = leg[pathName]
			local k = 0
			local index = 0
			local function place(rawSpec, via)
				local spec = scaledSpec(rawSpec, C.elementScale or 1)
				index += 1
				local half = halfAlong(spec)
				local rise, gap = spec.rise, spec.gap
				local fromY, fromK = s.y, s.prevK
				s.angle += P.dir * (s.half + gap + half) / P.radius
				s.y += rise
				local center = Vector3.new(math.cos(s.angle) * P.radius, FLOOR + s.y, math.sin(s.angle) * P.radius)
				local el = { leg = legIndex, path = pathName, index = index, k = spec.k, center = center, top = s.y, angle = s.angle, radius = P.radius, spec = spec, dir = P.dir }
				table.insert(out.elements, el)
				local moveVia = via or (fromK == "bounce" and "bounce") or (fromK == "pad" and "launch") or (spec.k == "vine" and "climb") or "jump"
				table.insert(out.moves, { leg = legIndex, path = pathName, rise = rise, gap = gap, via = moveVia, k = spec.k, fromY = fromY, toY = s.y, from = fromK, element = el })
				s.half = half
				s.prevK = spec.k
				if spec.k == "tunnel" then
					-- 줄기 속: 들어간 구멍 반대편(각 + π)으로 나온다 · 안쪽 계단 두 단(+4 · +8)
					table.insert(out.tunnels, { angle = s.angle, y = s.y, exitAngle = s.angle + math.pi })
					s.angle += math.pi
					s.y += 8
					s.half = 0
					s.prevK = "tunnel"
					table.insert(out.moves, { leg = legIndex, path = pathName, rise = 8, gap = 6, via = "tunnel", k = "tunnel", fromY = s.y - 8, toY = s.y })
				end
				return el
			end
			while true do
				local spec = pattern[k % #pattern + 1]
				if s.y + spec.rise > leg.untilY - 2 then
					break
				end
				place(spec)
				k += 1
			end
			-- 정거장 높이까지 남은 오름이 finalRiseMax보다 크면 쉬운 혹(step)으로 채운다
			while leg.untilY - s.y > C.finalRiseMax do
				place({ k = "step", rise = math.min(5, leg.untilY - s.y - 2), gap = 5, w = 4 })
			end
			-- 정거장 고리(또는 전망대)로 올라선다
			local ringEdge = pathName == "inner" and St.ringInner or St.ringOuter
			table.insert(out.moves, { leg = legIndex, path = pathName, rise = leg.untilY - s.y, gap = math.max(math.abs(P.radius - ringEdge) - s.half * 0.3, 1), via = "ring", k = "ring", fromY = s.y, toY = leg.untilY })
			s.y = leg.untilY
			s.half = 0
			s.prevK = "ring"
			s.angle += P.dir * 8 / P.radius -- 고리 위에서 조금 걸어 다음 구간 시작
		end
		table.insert(out.stations, { index = legIndex, y = leg.untilY, name = C.stations[legIndex] and C.stations[legIndex].name or "정상 전망대",
			unlockLevel = C.stations[legIndex] and C.stations[legIndex].unlockLevel or nil, deck = C.stations[legIndex] == nil })
	end
	treeCache = out
	return out
end

-- 정거장 목록(Travel · 클라): [i] = { index, name, unlockLevel, y, top(고리 위 리프트 도착 자리), ringInner, ringOuter } · deck = 정상
function Layout.stations()
	local list = {}
	local St = D.hub.tree.course.station
	for _, s in ipairs(Layout.tree().stations) do
		local mid = (St.ringInner + St.ringOuter) / 2
		local a = math.rad(St.startAngleDeg)
		local entry = { index = s.index, name = s.name, unlockLevel = s.unlockLevel, y = FLOOR + s.y, top = Vector3.new(math.cos(a) * mid, FLOOR + s.y, math.sin(a) * mid), ringInner = St.ringInner, ringOuter = St.ringOuter }
		if s.deck then
			list.deck = entry
		else
			list[s.index] = entry
		end
	end
	return list
end

-- M1-2c 발사 설계(점프대 · 통통 열매 - 요소 번호 i = TreePad · FruitId). 클라 발사(TreeFx) · 서버 허가(LaunchPermit) · 검증이 같은 값을 읽는다.
--   출발 발 = 윗면 ~ 윗면 + (launchProbeStuds − 루트 높이)(클라가 루트 아래 광선으로 "밟았다"를 읽는다 - 떨어지며 밟으면 조금 위에서 출발) → 그 범위의 최고 정점.
--   반환: { kind, top(윗면 Y), flightApexFeetY(비행만의 발 정점), apexFeetY(= 비행 정점 + 공중 점프 전부 - 정점마다 눌러도), radius(윗면 반경), target(착지 루트 · 점프대만) } 또는 nil
function Layout.treeLaunch(i)
	local JumpMath = require(ReplicatedStorage.Shared.JumpMath)
	local MC = require(ReplicatedStorage.Shared.data.MovementConfig)
	local C = D.hub.tree.course
	local T = Layout.tree()
	local el = T.elements[i]
	if not el or (el.k ~= "pad" and el.k ~= "bounce") then
		return nil
	end
	local top = el.center.Y -- 점프대 갓 · 열매 공 모두 center = 윗면(buildTree)
	local rise = C.launchProbeStuds - MC.rootAboveFeetStuds
	if el.k == "bounce" then
		local apex = top + rise + C.bounce.reachStuds
		return { kind = "bounce", top = top, flightApexFeetY = apex, apexFeetY = apex + JumpMath.airJumpsOnlyStuds(), radius = el.spec.dia / 2 }
	end
	local nextEl = T.elements[i + 1]
	if not nextEl then
		return nil
	end
	local target = nextEl.center + Vector3.new(0, C.pad.landRootAboveStuds, 0)
	local apex = -math.huge
	for _, lift in ipairs({ 0, rise }) do
		local from = Vector3.new(el.center.X, top + lift + MC.rootAboveFeetStuds, el.center.Z)
		local _, up = JumpMath.arcLaunch(from, target, C.pad.flightSeconds)
		apex = math.max(apex, top + lift + up)
	end
	return { kind = "pad", top = top, flightApexFeetY = apex, apexFeetY = apex + JumpMath.airJumpsOnlyStuds(), radius = el.spec.padSize / 2, target = target }
end

-- 오르는 시간 추정(보통 실력 가정 course.secondsPer): 필요한 기술(skillOf - 검증이 넣어 준다)별 시간 + 요소 추가 시간.
-- 반환: { [leg] = { inner = 초, outer = 초, innerMoves, outerMoves } }, 바닥 → 정상(빠른 길 · 느린 길), 최고 정거장 → 정상(빠른 · 느린)
function Layout.treeClimbSeconds(skillOf)
	local C = D.hub.tree.course
	local sec = C.secondsPer
	local legs = {}
	for _, m in ipairs(Layout.tree().moves) do
		local row = legs[m.leg] or { inner = 0, outer = 0, innerMoves = 0, outerMoves = 0 }
		legs[m.leg] = row
		local t
		if m.via == "bounce" then
			t = sec.bounce
		elseif m.via == "launch" then
			t = sec.launch
		elseif m.via == "climb" then
			t = m.rise / C.climbStudsPerSecond + sec.climbExtra
		elseif m.via == "tunnel" then
			t = sec.tunnel
		else
			t = sec[skillOf(m.rise, m.gap)] or sec.hard
		end
		if m.k == "soft" then
			t += sec.soft
		elseif m.k == "hang" then
			t += sec.hang
		end
		row[m.path] += t
		row[m.path .. "Moves"] += 1
	end
	local fastAll, slowAll = 0, 0
	for _, row in ipairs(legs) do
		fastAll += math.min(row.inner, row.outer)
		slowAll += math.max(row.inner, row.outer)
	end
	local last = legs[#legs]
	return legs, fastAll, slowAll, math.min(last.inner, last.outer), math.max(last.inner, last.outer)
end

-- 뿌리 곡선(M1-2): t(0 = 줄기 표면 · 1 = 끝) → 반경 · 윗면 높이 · 폭
function Layout.rootAt(t)
	local tree = D.hub.tree
	local Rt = tree.roots
	return tree.trunkRadius + t * Rt.reach, Rt.height * (1 - t) ^ Rt.curve, Rt.width + (Rt.tipWidth - Rt.width) * t
end

-- 뿌리 하나의 조각(기울인 상자 - 윗면이 곡선을 따른다 · 아래는 땅속 · 마지막 조각은 끝이 sink만큼 땅속으로). fromT = 이 t부터(코스 뿌리 = 끊긴 끝).
-- 반환: { { size, cf, t0, t1 } }
function Layout.rootSegments(angleDeg, fromT)
	local Rt = D.hub.tree.roots
	local d = dirOf(angleDeg)
	local out = {}
	local n = Rt.segments
	for i = 1, n do
		local t0, t1 = (i - 1) / n, i / n
		if t1 > fromT then
			t0 = math.max(t0, fromT)
			local r0, h0 = Layout.rootAt(t0)
			local r1, h1, w = Layout.rootAt(t1)
			if t0 == 0 then
				r0 -= 3 -- 줄기 속으로 조금 묻는다(틈 없게)
			end
			if i == n then
				h1 = -Rt.sink -- 끝이 땅속으로 파고든다
			end
			local _, _, w0 = Layout.rootAt(t0)
			local top0 = d * r0 + Vector3.new(0, FLOOR + h0, 0)
			local top1 = d * r1 + Vector3.new(0, FLOOR + h1, 0)
			local len = (top1 - top0).Magnitude + 1
			local thick = math.max(h0, h1) + Rt.sink + 2
			local cf = CFrame.lookAt((top0 + top1) / 2, top1) * CFrame.new(0, -thick / 2, 0)
			table.insert(out, { size = Vector3.new((w + w0) / 2, thick, len), cf = cf, t0 = t0, t1 = t1 })
		end
	end
	return out
end

-- 코스 뿌리 이동 표(검증 · 문서): 걷는 끝 → 혹 1 → 혹 2 → 안쪽 길 5번째 요소. { { from, to, rise, gap } }
function Layout.courseRootMoves()
	local tree = D.hub.tree
	local CR = tree.courseRoot
	local rEnd, hEnd = Layout.rootAt(CR.walkFrom)
	local nodes = { { name = "뿌리 끝", p = Layout.hubPoint(CR.angleDeg, rEnd), top = hEnd, half = 0 } }
	for i, k in ipairs(CR.knobs) do
		table.insert(nodes, { name = "혹 " .. i, p = Layout.hubPoint(k.angleDeg, k.r), top = k.top, half = CR.knobWidth / 2 })
	end
	local target
	for _, el in ipairs(Layout.tree().elements) do
		if el.leg == 1 and el.path == "inner" and el.index == 5 then
			target = el
		end
	end
	local tan = tangentAt(target.angle, target.dir)
	table.insert(nodes, { name = "안쪽 길 " .. target.index .. "번(" .. target.k .. ")", p = target.center, top = target.top, tangent = tan, len = target.spec.len or 4, dia = target.spec.dia or 4 })
	local moves = {}
	for i = 2, #nodes do
		local a, b = nodes[i - 1], nodes[i]
		local v = Vector3.new(b.p.X - a.p.X, 0, b.p.Z - a.p.Z)
		local halfB = b.half
		if b.tangent then
			local u = v.Unit
			halfB = math.abs(u:Dot(b.tangent)) * b.len / 2 + (1 - math.abs(u:Dot(b.tangent))) * b.dia / 2
		end
		table.insert(moves, { from = a.name, to = b.name, rise = b.top - a.top, gap = math.max(v.Magnitude - a.half - halfB, 0.5) })
	end
	return moves, target
end

-- 나무 도형(BigTree = Persistent: 줄기 · 뿌리 · 결 · 잎 / TreeCourse = 점프맵 요소 · 정거장 고리 · 코스 뿌리)
function Layout.buildTree(list)
	local tree = D.hub.tree
	local C = tree.course
	local R = tree.trunkRadius
	local bark = tree.bark
	local barkDark = tree.barkDark
	local T = Layout.tree()
	-- 줄기: 통로 높이에서 끊는다(속이 빈 고리)
	local cuts = {}
	for _, tn in ipairs(T.tunnels) do
		table.insert(cuts, { from = tn.y - 1, to = tn.y + 23 })
	end
	table.sort(cuts, function(a, b)
		return a.from < b.from
	end)
	local y0 = 0
	local function trunkPiece(a, b)
		if b - a > 0.5 then
			prim(list, "BigTree", "Trunk", Vector3.new(b - a, R * 2, R * 2), CFrame.new(0, FLOOR + (a + b) / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), bark, { shape = "Cylinder", material = tree.barkMaterial })
		end
	end
	for _, c in ipairs(cuts) do
		trunkPiece(y0, c.from)
		y0 = c.to
	end
	trunkPiece(y0, tree.trunkHeight)
	-- 줄기 속 통로: 벽 고리(두 구멍) + 바닥 · 천장 + 안쪽 계단
	for _, tn in ipairs(T.tunnels) do
		local segments = 16
		for i = 1, segments do
			local a = (i - 0.5) / segments * 2 * math.pi
			local function near(target)
				local d = math.abs(((a - target) + math.pi) % (2 * math.pi) - math.pi)
				return d < 0.28
			end
			if not near(tn.angle) and not near(tn.exitAngle) then
				local p = Vector3.new(math.cos(a) * (R - 3), 0, math.sin(a) * (R - 3))
				local cf = CFrame.lookAt(Vector3.new(p.X, FLOOR + tn.y + 11, p.Z), Vector3.new(0, FLOOR + tn.y + 11, 0))
				prim(list, "BigTree", "TunnelWall", Vector3.new(2 * math.pi * R / segments + 1, 22, 6), cf, bark, { material = tree.barkMaterial })
			end
		end
		prim(list, "BigTree", "TunnelFloor", Vector3.new(2, (R - 1) * 2, (R - 1) * 2), CFrame.new(0, FLOOR + tn.y - 1, 0) * CFrame.Angles(0, 0, math.rad(90)), barkDark, { shape = "Cylinder", material = tree.barkMaterial })
		prim(list, "BigTree", "TunnelCeiling", Vector3.new(2, R * 2, R * 2), CFrame.new(0, FLOOR + tn.y + 23, 0) * CFrame.Angles(0, 0, math.rad(90)), bark, { shape = "Cylinder", material = tree.barkMaterial })
		-- 안쪽 계단(출구 쪽 두 단)
		local ex = Vector3.new(math.cos(tn.exitAngle), 0, math.sin(tn.exitAngle))
		prim(list, "TreeCourse", "TunnelStep", Vector3.new(8, 4, 8), CFrame.new(ex * (R - 24) + Vector3.new(0, FLOOR + tn.y + 2, 0)), barkDark, { material = tree.barkMaterial, attrs = { TreeTunnel = true } })
		prim(list, "TreeCourse", "TunnelStep", Vector3.new(8, 8, 8), CFrame.new(ex * (R - 10) + Vector3.new(0, FLOOR + tn.y + 4, 0)), barkDark, { material = tree.barkMaterial, attrs = { TreeTunnel = true } })
	end
	-- 뿌리(M1-2 - 밟을 수 있다 · 끝이 땅속으로) · 코스 뿌리(끊긴 끝 + 좁은 혹) · 줄기 결(장식 - 충돌 없음)
	for _, a in ipairs(tree.roots.angles) do
		for _, seg in ipairs(Layout.rootSegments(a, 0)) do
			prim(list, "BigTree", "Root", seg.size, seg.cf, barkDark, { material = tree.barkMaterial })
		end
	end
	local CR = tree.courseRoot
	for _, seg in ipairs(Layout.rootSegments(CR.angleDeg, CR.walkFrom)) do
		prim(list, "TreeCourse", "CourseRoot", seg.size, seg.cf, barkDark, { material = tree.barkMaterial, attrs = { CourseRoot = true } })
	end
	for i, k in ipairs(CR.knobs) do
		local p = Layout.hubPoint(k.angleDeg, k.r)
		prim(list, "TreeCourse", "CourseRootKnob", Vector3.new(CR.knobWidth, k.top, CR.knobWidth), CFrame.new(p.X, FLOOR + k.top / 2, p.Z), barkDark, { material = tree.barkMaterial, attrs = { CourseRoot = true, CourseRootKnob = i } })
	end
	local Rg = tree.ridges
	for i = 1, Rg.count do
		local a = (i - 0.5) / Rg.count * 2 * math.pi
		local p = Vector3.new(math.cos(a), 0, math.sin(a)) * (R + Rg.depth / 2 - 1)
		prim(list, "BigTree", "Ridge", Vector3.new(Rg.width, tree.trunkHeight * 0.95, Rg.depth), CFrame.lookAt(Vector3.new(p.X, FLOOR + tree.trunkHeight * 0.475, p.Z), Vector3.new(0, FLOOR + tree.trunkHeight * 0.475, 0)),
			barkDark, { material = tree.barkMaterial, collide = false })
	end
	-- 메타세쿼이아 수관(층층 로우폴리 원뿔): 층마다 각진 원뿔대 치마 - 면 = 삼각형 2장(사각형) · 삼각형 = 쐐기 2개.
	local CS = tree.crownShape
	local season = tree.leaves.seasons[tree.leaves.season]
	local function crownRadius(y)
		if y <= CS.shoulderY then
			return CS.baseRadius + (CS.shoulderRadius - CS.baseRadius) * (y - CS.baseY) / (CS.shoulderY - CS.baseY)
		end
		return CS.shoulderRadius * math.max(0, 1 - (y - CS.shoulderY) / (CS.tipY - CS.shoulderY))
	end
	local J = CS.jitter
	local seed = J.seed % 2147483647
	local function rand()
		seed = (seed * 48271) % 2147483647
		return seed / 2147483647
	end
	local function spread(v)
		return (rand() * 2 - 1) * v
	end
	local CT = CS.coneTiers
	local tierIndex = 0
	local function skirt(topY, bottomY, innerR, outerR, role)
		tierIndex += 1
		local n = CT.facets[1] + math.floor(rand() * (CT.facets[2] - CT.facets[1] + 1))
		local twist = math.rad(spread(J.twistDeg)) + tierIndex * 0.37
		local tops, bottoms = {}, {}
		for k = 1, n do
			local a = (k - 1) / n * 2 * math.pi + twist + spread(0.12)
			local d = Vector3.new(math.cos(a), 0, math.sin(a))
			local ro = outerR * (1 + spread(J.radius))
			tops[k] = d * math.max(innerR, 0.01) + Vector3.new(0, FLOOR + topY + spread(J.y * 0.4), 0)
			bottoms[k] = d * ro + Vector3.new(0, FLOOR + bottomY + spread(J.y), 0)
		end
		for k = 1, n do
			local k2 = k % n + 1
			local tint = 1 + spread(J.tint)
			local c = season[role]
			local col = { math.clamp(c[1] * tint, 0, 255), math.clamp(c[2] * tint, 0, 255), math.clamp(c[3] * tint, 0, 255) }
			local opts = { material = season.material, collide = false, attrs = { SeasonRole = role, SeasonTint = tint } }
			local faces = { { bottoms[k], bottoms[k2], tops[k] } }
			if innerR > 0.5 then
				table.insert(faces, { tops[k], bottoms[k2], tops[k2] })
			end
			for _, f in ipairs(faces) do
				for _, w in ipairs(Layout.triangle(f[1], f[2], f[3], CT.thickness)) do
					prim(list, "BigTree.Leaves", "Needle", w.size, w.cf, col, { shape = "Wedge", material = opts.material, collide = false, attrs = opts.attrs })
				end
			end
		end
	end
	-- 어깨(점프맵 끝) 아래: 안쪽 가장자리 = clearRadius(길 밖) · 위: 줄기까지 닫힌 원뿔
	local y = CS.shoulderY
	local layers = {}
	while y > CS.baseY do
		table.insert(layers, y)
		y -= CT.spacing
	end
	for li = #layers, 1, -1 do
		local top = layers[li]
		local bottom = top - CT.skirt
		skirt(top, bottom, CS.clearRadius, crownRadius(bottom), (li % 2 == 0) and "leaves" or "leavesDeep")
	end
	-- 어깨 위(M1-2): 아래와 같은 규칙의 층이 위로 갈수록 작아진다 - 마지막은 뾰족한 끝(안쪽 0). 아래 가장자리는 전망대(760) 눈높이 위.
	for i, t in ipairs(CS.topTiers) do
		skirt(t.top, t.bottom, t.inner, t.outer, (i % 2 == 0) and "leavesDeep" or "leaves")
	end
	-- 꼭대기: 줄기가 가늘어지며 끝난다(원통 조각 - 충돌 없음)
	local topY = tree.trunkHeight
	local pieces = 4
	for k = 1, pieces do
		local y1 = topY + (CS.tipY - topY) * (k - 1) / pieces
		local y2 = topY + (CS.tipY - topY) * k / pieces
		local r = R * (1 - (k - 0.5) / pieces) * 0.8
		prim(list, "BigTree", "Spire", Vector3.new(y2 - y1, r * 2, r * 2), CFrame.new(0, FLOOR + (y1 + y2) / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), bark, { shape = "Cylinder", material = tree.barkMaterial, collide = false })
	end
	-- 정거장 고리 · 전망대(고리) + 이름표 · 내려가기 판 · 하루 1회 자리
	local St = C.station
	for _, s in ipairs(T.stations) do
		for i = 1, St.segments do
			local a = (i - 0.5) / St.segments * 2 * math.pi
			local mid = (St.ringInner + St.ringOuter) / 2
			local p = Vector3.new(math.cos(a) * mid, FLOOR + s.y - St.thickness / 2, math.sin(a) * mid)
			local w = 2 * math.pi * St.ringOuter / St.segments + 1
			prim(list, "TreeCourse", s.deck and "Deck" or "Station", Vector3.new(w, St.thickness, St.ringOuter - St.ringInner), CFrame.lookAt(p, Vector3.new(0, p.Y, 0)), barkDark,
				{ attrs = { Station = s.deck and nil or s.index, CourseKind = s.deck and "deck" or "station" } })
		end
		local a = math.rad(St.startAngleDeg)
		local mid = (St.ringInner + St.ringOuter) / 2
		local label = s.deck and "정상 전망대" or ("%s(Lv %d)"):format(s.name, s.unlockLevel)
		local sign = Vector3.new(math.cos(a) * mid, FLOOR + s.y + 0.2, math.sin(a) * mid)
		prim(list, "TreeCourse", "StationSign", Vector3.new(3, 0.4, 3), CFrame.new(sign), D.colors.marker, { collide = false, neon = true, attrs = { Label = label } })
		if s.deck then
			prim(list, "TreeCourse", "DailyEggSpot", Vector3.new(3, 0.4, 3), CFrame.new(sign + Vector3.new(0, 0, 10)), D.colors.marker,
				{ collide = false, neon = true, attrs = { Spot = "dailyEgg", Label = C.dailyEgg.label } })
		else
			local b = math.rad(St.startAngleDeg + 12)
			prim(list, "TreeCourse", "StationDown", Vector3.new(0.3, 4, 4), CFrame.new(math.cos(b) * mid, FLOOR + s.y + 0.15, math.sin(b) * mid) * CFrame.Angles(0, 0, math.rad(90)), D.colors.barrier,
				{ shape = "Cylinder", material = "SmoothPlastic", attrs = { StationDown = s.index } })
		end
	end
	-- 점프맵 요소
	local FC = tree.fruitColors
	local moving = 0
	for i, el in ipairs(T.elements) do
		local spec = el.spec
		local tan = tangentAt(el.angle, el.dir)
		local c = el.center
		local attrs = { CourseLeg = el.leg, CoursePath = el.path, CourseIndex = el.index }
		local model = "TreeCourse"
		if spec.k == "branch" then
			prim(list, model, "Branch", Vector3.new(spec.len, spec.dia, spec.dia), CFrame.lookAt(c - Vector3.new(0, spec.dia / 2, 0), c - Vector3.new(0, spec.dia / 2, 0) + tan) * CFrame.Angles(0, math.rad(90), 0), bark,
				{ shape = "Cylinder", material = tree.barkMaterial, attrs = attrs })
			-- 줄기에서 뻗어 나온 가지(장식 - 충돌 없음)
			local radial = Vector3.new(c.X, 0, c.Z).Unit
			local from = radial * R + Vector3.new(0, c.Y - spec.dia / 2 - 3, 0)
			local to = c - Vector3.new(0, spec.dia / 2, 0)
			prim(list, model, "BranchStem", Vector3.new((to - from).Magnitude, spec.dia * 0.7, spec.dia * 0.7), CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, math.rad(90), 0), barkDark,
				{ shape = "Cylinder", material = tree.barkMaterial, collide = false })
		elseif spec.k == "bounce" or spec.k == "soft" or spec.k == "hang" then
			local a2 = table.clone(attrs)
			a2.TreeFruit = spec.k
			if spec.k == "hang" then
				moving += 1
				a2.HangPivotY = c.Y - spec.dia / 2 + D.hub.tree.course.hang.rope
				a2.HangTanX, a2.HangTanZ = tan.X, tan.Z
				prim(list, model, "Rope", Vector3.new(0.4, D.hub.tree.course.hang.rope, 0.4), CFrame.new(c + Vector3.new(0, D.hub.tree.course.hang.rope / 2, 0)), barkDark, { collide = false, attrs = { RopeFor = i } })
			end
			a2.FruitId = i
			if spec.k == "bounce" then
				a2.DesignApexFeetY = Layout.treeLaunch(i).apexFeetY -- M1-2c: 설계 정점(공중 점프 몫 포함 - 서버 허가 = 이 값 + 여유)
			end
			prim(list, model, "Fruit_" .. spec.k, Vector3.new(spec.dia, spec.dia, spec.dia), CFrame.new(c - Vector3.new(0, spec.dia / 2, 0)), FC[spec.k], { shape = "Ball", material = "SmoothPlastic", attrs = a2 })
		elseif spec.k == "pad" then
			prim(list, model, "PadStem", Vector3.new(2, 6, 2), CFrame.new(c - Vector3.new(0, 3.6, 0)), barkDark, { attrs = attrs })
			local a2 = table.clone(attrs)
			a2.TreePad = i
			local launchSpec = Layout.treeLaunch(i)
			a2.DesignApexFeetY = launchSpec and launchSpec.apexFeetY or nil
			local nextEl = T.elements[i + 1]
			if nextEl then
				a2.PadTargetX, a2.PadTargetY, a2.PadTargetZ = nextEl.center.X, nextEl.center.Y, nextEl.center.Z
				-- 착지 지점 표시(다음 요소 위 네온 원)
				prim(list, model, "PadLanding", Vector3.new(0.2, 5, 5), CFrame.new(nextEl.center + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), FC.pad,
					{ shape = "Cylinder", material = "SmoothPlastic", collide = false, neon = true, transparency = 0.3 })
			end
			prim(list, model, "PadCap", Vector3.new(1.2, spec.padSize, spec.padSize), CFrame.new(c - Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90)), FC.pad, { shape = "Cylinder", material = "SmoothPlastic", attrs = a2 })
		elseif spec.k == "vine" then
			-- 덩굴 사다리(TrussPart - 기본 오르기): 밑 = 앞 요소 높이 · 위 = 이 요소 높이(+ 발판 한 칸)
			local h = 2 * math.ceil((spec.rise + 2) / 2) -- TrussPart 높이는 2의 배수
			prim(list, model, "Vine", Vector3.new(2, h, 2), CFrame.new(c.X, c.Y - h / 2 + 2, c.Z), { 70, 110, 60 }, { shape = "Truss", attrs = attrs })
			prim(list, model, "VineTop", Vector3.new(4, 1, 4), CFrame.new(c.X, c.Y - 0.5, c.Z) + tan * 2.5, bark, { attrs = attrs })
		elseif spec.k == "leaf" then
			local a2 = table.clone(attrs)
			a2.SeasonRole = "leafPad"
			if spec.sway then
				moving += 1
				a2.LeafSway = true
			end
			local season = D.hub.tree.leaves.seasons[D.hub.tree.leaves.season]
			prim(list, model, "LeafPad", Vector3.new(spec.len * 0.7, 0.8, spec.len), CFrame.lookAt(c - Vector3.new(0, 0.4, 0), c - Vector3.new(0, 0.4, 0) + tan), season.leafPad, { material = season.material, attrs = a2 })
		elseif spec.k == "step" then
			prim(list, model, "Knot", Vector3.new(spec.w, 1.5, spec.w), CFrame.lookAt(c - Vector3.new(0, 0.75, 0), c - Vector3.new(0, 0.75, 0) + tan), bark, { material = tree.barkMaterial, attrs = attrs })
		elseif spec.k == "tunnel" then
			-- 입구 턱(줄기 구멍 앞 - 통로 바닥 높이)
			prim(list, model, "TunnelLip", Vector3.new(6, 1, 8), CFrame.lookAt(c - Vector3.new(0, 0.5, 0), Vector3.new(0, c.Y - 0.5, 0)) * CFrame.new(0, 0, -2), bark, { material = tree.barkMaterial, attrs = attrs })
		end
	end
	-- 숨은 지름길(잎 뒤 덩굴) · 이스터에그 자리
	for legIndex, leg in ipairs(C.legs) do
		if leg.shortcut then
			local from, to
			for _, el in ipairs(T.elements) do
				if el.leg == legIndex and el.path == leg.shortcut.path then
					if el.index == leg.shortcut.fromIndex then
						from = el
					elseif el.index == leg.shortcut.fromIndex + leg.shortcut.skip then
						to = el
					end
				end
			end
			if from and to then
				-- 줄기 쪽(반경 − 6)으로 숨긴 덩굴: 아래 요소 높이 → 위 요소 높이
				local radial = Vector3.new(to.center.X, 0, to.center.Z).Unit
				local base = radial * (R + 3)
				local h = to.top - from.top + 3
				prim(list, "TreeCourse", "ShortcutVine", Vector3.new(2, h, 2), CFrame.new(base.X, FLOOR + from.top + h / 2 - 1, base.Z), { 70, 110, 60 }, { shape = "Truss", attrs = { Shortcut = legIndex } })
				prim(list, "TreeCourse", "ShortcutLedge", Vector3.new(4, 1, 4), CFrame.new(base.X, FLOOR + from.top - 0.5, base.Z) + radial * 3, bark, { material = tree.barkMaterial, attrs = { Shortcut = legIndex } })
			end
		end
		if leg.egg then
			for _, el in ipairs(T.elements) do
				if el.leg == legIndex and el.path == leg.egg.path and el.index == leg.egg.index then
					local radial = Vector3.new(el.center.X, 0, el.center.Z).Unit
					prim(list, "TreeCourse", "EasterEggSpot", Vector3.new(3, 3, 3), CFrame.new(el.center + radial * 6 + Vector3.new(0, 1.5, 0)), D.colors.marker,
						{ collide = false, transparency = 1, attrs = { EasterEgg = leg.egg.id, Zone = "hub" } })
				end
			end
		end
	end
	T.movingCount = moving
	return T
end

-- ─────────────────────────── 구역 지형 ───────────────────────────
-- 반환: 탐험 지점 · 이스터에그 자리 목록(월드) - 도형은 list에.
local function buildFeature(zone, f, list)
	local model = "Zone_" .. zone.key
	local look = dirOf(zone.angleDeg)
	local base = Layout.toWorld(zone, f.r, f.lat)
	local cf0 = flatYaw(base, look)
	local points = {}
	-- M1-3: 파트 색 · 재질 = 구역 지형 절벽 재질(지형과 이어져 보이게) · 대지(plateau) · 절벽(cliff)은 이제 지형(TerrainShape 모양 단계)이 만든다
	local stone = require(ReplicatedStorage.Shared.WorldStructureKits).look(zone.key)
	local c, cd = stone.color, stone.dark
	local mat = { material = stone.material }
	local FLAT_TOP = FLOOR + require(ReplicatedStorage.Shared.data.TerrainGenData).flatLevel
	if f.kind == "plateau" then
		local run = f.h / math.tan(math.rad(33))
		points.top = Vector3.new(base.X, FLAT_TOP + f.h, base.Z)
		points.base = (cf0 * CFrame.new(0, 0, math.max(f.w, f.d) / 2 + run + 6)).Position
	elseif f.kind == "tower" then
		column(list, model, "Tower", cf0, f.size, f.size, f.h, cd, mat)
		-- 1단 점프 계단 나선(오름 4 · 간격 4 · 폭 4 - 쉬움) - 탑 둘레 반경 R
		local R = f.size / 2 * math.sqrt(2) + 3
		local a, y = 0, 0
		while y + 4 <= f.h do
			a += 2 * math.asin(8 / (2 * R))
			y += 4
			local p = cf0 * CFrame.new(math.cos(a) * R, 0, math.sin(a) * R)
			column(list, model, "TowerStep", p, 4, 4, y, c, mat)
		end
		points.top = (cf0 * CFrame.new(0, f.h, 0)).Position
		points.base = (cf0 * CFrame.new(0, 0, R + 6)).Position
	elseif f.kind == "cliff" then
		points.base = (cf0 * CFrame.new(0, 0, f.d / 2 + 10)).Position
	elseif f.kind == "cave" then
		local t = 8
		column(list, model, "CaveWall", cf0 * CFrame.new(-(f.w / 2 - t / 2), 0, 0), t, f.d, f.h, cd, mat)
		column(list, model, "CaveWall", cf0 * CFrame.new(f.w / 2 - t / 2, 0, 0), t, f.d, f.h, cd, mat)
		column(list, model, "CaveBack", cf0 * CFrame.new(0, 0, -(f.d / 2 - t / 2)), f.w, t, f.h, cd, mat)
		prim(list, model, "CaveRoof", Vector3.new(f.w, 6, f.d), cf0 * CFrame.new(0, f.h + 3, 0), cd, mat)
		points.inside = (cf0 * CFrame.new(0, 0, -f.d / 4)).Position
		points.base = (cf0 * CFrame.new(0, 0, f.d / 2 + 8)).Position
	elseif f.kind == "falls" then
		-- 폭포 벽(앞) + 뒤 벽 · 사이 공간(옆으로 들어간다)
		prim(list, model, "FallsFront", Vector3.new(f.w, f.h, 4), cf0 * CFrame.new(0, f.h / 2, 0), D.colors.blockLight, { collide = true, transparency = 0.3 })
		column(list, model, "FallsBack", cf0 * CFrame.new(0, 0, -16), f.w + 20, 6, f.h + 10, cd, mat)
		points.behind = (cf0 * CFrame.new(0, 0, -8)).Position
		points.base = (cf0 * CFrame.new(0, 0, 12)).Position
	elseif f.kind == "spire" then
		column(list, model, "Spire", cf0, f.size, f.size, f.h * 0.6, cd, mat)
		column(list, model, "Spire", cf0, f.size * 0.6, f.size * 0.6, f.h, cd, mat)
		points.base = (cf0 * CFrame.new(0, 0, f.size + 6)).Position
	end
	if f.explore then
		local at = points.top or points.inside or points.behind or points.base
		prim(list, model, "ExplorePoint", Vector3.new(4, 4, 4), CFrame.new(at + Vector3.new(0, 2, 0)), D.colors.marker,
			{ collide = false, transparency = 1, attrs = { ExploreName = f.explore, ExploreZone = zone.key } })
	end
	points.footprint = featureFootprint(f)
	points.center = base
	return points
end

local function buildLandmark(zone, list)
	local m = zone.landmark
	local model = "Landmark_" .. zone.key
	local center = Layout.toWorld(zone, m.r + 90, 0)
	local cf0 = flatYaw(center, dirOf(zone.angleDeg))
	local look = require(ReplicatedStorage.Shared.WorldStructureKits).look(zone.key)
	local cd = look.dark
	local mat = { material = look.material }
	if m.kind == "sunkenTemple" then
		return center -- M1-3: 바다 만 속 수중 신전 = WorldStructures(둥지 t3_b_temple)가 짓는다
	elseif m.kind == "monoliths" or m.kind == "spires" or m.kind == "iceWall" then
		for i = 1, m.count do
			local a = (i - 1) / m.count * 2 * math.pi
			-- M1-4 소품 라이브러리(비석 · 수정 첨탑 · 얼음 벽 판 - 틀 높이 34 · 130 · 120에 y 배율)
			local at = cf0 * CFrame.new(math.cos(a) * m.radius, 0, math.sin(a) * m.radius) * CFrame.Angles(0, a, 0)
			local h = m.height * (m.kind == "spires" and (0.6 + 0.4 * (i % 2)) or 1)
			local name, ref = "T1_Monolith", 34
			if m.kind == "spires" then
				name, ref = "T2_CrystalSpire", 130
			elseif m.kind == "iceWall" then
				name, ref = "T6_IceWallSlab", 120
			end
			require(ReplicatedStorage.Shared.PropKit).place(list, model, name, at, Vector3.new(1, h / ref, 1))
		end
	elseif m.kind == "temple" or m.kind == "pyramid" then
		local layers = m.kind == "pyramid" and 6 or 4
		for i = 1, layers do
			local s = m.radius * 2 * (1 - (i - 1) / layers)
			column(list, model, "Landmark", cf0, s, s, m.height * i / layers, cd, mat)
		end
	elseif m.kind == "stormSpire" then
		column(list, model, "Landmark", cf0, m.radius, m.radius, m.height * 0.5, cd, mat)
		column(list, model, "Landmark", cf0, m.radius * 0.6, m.radius * 0.6, m.height, cd, mat)
		column(list, model, "Landmark", cf0, m.radius * 0.3, m.radius * 0.3, m.height + 40, cd, mat)
	end
	return center
end

-- 구역 하나의 도형 + 메타(탐험 · 이스터에그 · 둥지)
function Layout.buildZone(zone, list)
	local model = "Zone_" .. zone.key
	local tint = zone.floorTint
	-- M1-3: 구역 바닥 색 원판 · 스폰 범위 원판/고리는 지형(재질 · 높낮이)이 대신한다(삭제) - 사냥터 이름 표시(클라)는 그대로
	local _ = tint
	-- 캠프(안전 · 포탈)
	local camp = Layout.camp(zone)
	prim(list, model, "Camp", Vector3.new(0.2, L.camp.radius * 2, L.camp.radius * 2), CFrame.new(camp.X, FLOOR + 0.35, camp.Z) * CFrame.Angles(0, 0, math.rad(90)), D.colors.safe, { shape = "Cylinder", material = "SmoothPlastic" })
	-- 도로 = M1-4부터 Terrain 재질 띠(곡선 · 지형 높이 - shared/RoadNet · 지형 굽기가 칠한다). 파트 없음. 갈림길 · 결계 문 표지판만(소품 + 이름표)
	local RoadNet = require(ReplicatedStorage.Shared.RoadNet)
	local PropKit = require(ReplicatedStorage.Shared.PropKit)
	for _, sg in ipairs(RoadNet.signs()) do
		if sg.zone == zone.key then
			PropKit.place(list, "Floor_" .. zone.key, "Common_Signpost", sg.cf, nil, { snap = true })
			prim(list, "Floor_" .. zone.key, "SignLabel", Vector3.new(1, 1, 1), sg.cf * CFrame.new(0, require(ReplicatedStorage.Shared.data.RoadData).sign.height, 0), D.colors.marker,
				{ collide = false, transparency = 1, attrs = { Label = sg.label, LabelSmall = true } })
		end
	end
	-- 결계 문(길이 구역 원을 지나는 자리 - 늘 보인다 · 잠김 표시는 클라)
	local bg = Layout.toWorld(zone, L.barrierGateR, 0)
	local gcf = flatYaw(bg, dirOf(zone.angleDeg))
	local B = D.barrier
	column(list, model, "BarrierGatePost", gcf * CFrame.new(-B.gateWidth / 2, 0, 0), 4, 4, B.gateHeight, D.colors.blockDark)
	column(list, model, "BarrierGatePost", gcf * CFrame.new(B.gateWidth / 2, 0, 0), 4, 4, B.gateHeight, D.colors.blockDark)
	prim(list, model, "BarrierGateTop", Vector3.new(B.gateWidth + 4, 3, 4), gcf * CFrame.new(0, B.gateHeight + 1.5, 0), D.colors.blockDark, { attrs = { BarrierGate = zone.key } })
	-- 보스 관문 = Layout.buildBossGates(보스 목록 BossData gate 칸 - M1-3 관문 등록) · 여기는 토벌 관문 자리(BR2)만
	local raid = Layout.toWorld(zone, L.gate.r, L.raidLat)
	local raidcf = flatYaw(raid, dirOf(zone.angleDeg))
	column(list, model, "RaidGatePost", raidcf * CFrame.new(-10, 0, 0), 4, 4, 22, D.colors.block)
	column(list, model, "RaidGatePost", raidcf * CFrame.new(10, 0, 0), 4, 4, 22, D.colors.block)
	prim(list, model, "RaidGateTop", Vector3.new(24, 3, 4), raidcf * CFrame.new(0, 23.5, 0), D.colors.block, { attrs = { RaidGate = zone.key, Label = "토벌 관문(BR2)" } })

	local meta = { features = {}, eggs = {}, nests = {}, explore = {} } -- nests = M1-3 둥지 3트랙(WorldStructures - buildAll이 채운다)
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
	meta.landmark = buildLandmark(zone, list)
	return meta
end

-- ─────────────────────────── 허브 ───────────────────────────
function Layout.buildHub(list)
	local H = D.hub
	local tree = H.tree
	-- 허브 바닥(안전 지대 원판)
	prim(list, "Hub", "HubFloor", Vector3.new(0.2, H.safeRadius * 2, H.safeRadius * 2), CFrame.new(0, FLOOR + 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), D.colors.safe, { shape = "Cylinder", material = "SmoothPlastic" })
	-- 나무(세계수 - Persistent 모델 "BigTree" · 점프맵 "TreeCourse")
	Layout.buildTree(list)
	-- 경계 등불(뿌리는 나무 도형 - M1-2에서 옛 긴 경사로 8개를 뺐다)
	for i = 1, H.lanterns.count do
		local a = (i - 1) / H.lanterns.count * 2 * math.pi
		local p = Vector3.new(math.cos(a), 0, math.sin(a)) * H.safeRadius
		prim(list, "Hub", "LanternPost", Vector3.new(1, 8, 1), CFrame.new(p.X, FLOOR + 4, p.Z), D.colors.blockDark, { collide = false })
		prim(list, "Hub", "Lantern", Vector3.new(2, 2, 2), CFrame.new(p.X, FLOOR + 9, p.Z), D.colors.marker, { collide = false, neon = true })
	end
	-- 시설 = 거리(M1-2): 가운데 = 기능 물체 자리(강화대 · 보석상인 · 환생 제단은 자기 스크립트가 세운다) · 양옆 자리 표시 · 바깥쪽 건물 줄 · 거리 바닥(광장 = 원판)
	for _, name in ipairs(Layout.facilityOrder) do
		local f = H.facilities[name]
		local p = Layout.facility(name)
		local out = dirOf(f.angleDeg)
		if f.radius then
			prim(list, "Hub", "PortalPlaza", Vector3.new(0.2, f.radius * 2, f.radius * 2), CFrame.new(p.X, FLOOR + 0.25, p.Z) * CFrame.Angles(0, 0, math.rad(90)), D.colors.blockLight, { shape = "Cylinder", material = "SmoothPlastic", attrs = { Facility = name, Label = f.displayName } })
		else
			local cf = flatYaw(p, -out) -- 로컬 −Z = 나무 쪽 · +X = 거리 방향
			if f.plaza then
				prim(list, "Hub", "DistrictFloor", Vector3.new(0.2, f.plaza * 2, f.plaza * 2), CFrame.new(p.X, FLOOR + 0.25, p.Z) * CFrame.Angles(0, 0, math.rad(90)), D.colors.road, { shape = "Cylinder", material = "SmoothPlastic", attrs = { District = name } })
			else
				prim(list, "Hub", "DistrictFloor", Vector3.new(f.street.w, 0.2, f.street.d), cf * CFrame.new(0, 0.25, 4), D.colors.road, { material = "SmoothPlastic", attrs = { District = name } })
			end
			local R = f.row
			local back = (f.plaza or f.street.d / 2) + 6 + R.d / 2
			for i = 1, R.count do
				local x = (i - (R.count + 1) / 2) * (R.w + R.gap)
				local mid = i == math.ceil(R.count / 2)
				column(list, "Hub", "Facility_" .. name, cf * CFrame.new(x, 0, back), R.w, R.d, R.h + (mid and 4 or 0), D.colors.blockLight,
					{ attrs = { Facility = name, Label = mid and f.displayName or nil } })
			end
			for _, sp in ipairs(f.spots) do
				column(list, "Hub", "Spot_" .. sp.id, cf * CFrame.new(sp.along, 0, sp.side), 6, 2, 5, D.colors.block, { attrs = { Spot = sp.id, Label = sp.label, District = name } })
			end
		end
	end
	-- 덩굴 리프트(허브 바닥) · 구름층(연출 자리 - 옅은 원판 · 충돌 없음)
	-- M1-2c: 정거장 1 고리 아래 → 땅까지 굵은 덩굴(두 가닥 · 잎 뭉치) + 잎사귀 바구니(VineLift - [F] 프롬프트 자리) + 표지 기둥. 색 = 잠김(시든) · 열림은 클라가 사람마다 칠한다(VineLiftView).
	local lift = tree.course.lift
	local lp = Layout.hubPoint(lift.angleDeg, lift.r)
	local LC = lift.colors
	local vineTop = FLOOR + tree.course.legs[1].untilY - tree.course.station.thickness
	local vineLen = vineTop - FLOOR
	local outward = Vector3.new(lp.X, 0, lp.Z).Unit
	local side = Vector3.new(-outward.Z, 0, outward.X)
	prim(list, "Hub", "LiftVine", Vector3.new(vineLen, lift.vineDia, lift.vineDia), CFrame.new(lp.X, FLOOR + vineLen / 2, lp.Z) * CFrame.Angles(0, 0, math.rad(90)), LC.withered,
		{ shape = "Cylinder", material = "SmoothPlastic", collide = false, attrs = { LiftPart = "vine" } })
	prim(list, "Hub", "LiftVine", Vector3.new(vineLen, lift.vineDia * 0.5, lift.vineDia * 0.5), CFrame.new(Vector3.new(lp.X, FLOOR + vineLen / 2, lp.Z) + side * lift.vineDia * 0.6) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(math.rad(4), 0, 0), LC.withered,
		{ shape = "Cylinder", material = "SmoothPlastic", collide = false, attrs = { LiftPart = "vine" } })
	for i = 1, math.floor((vineLen - 14) / lift.leafEvery) do
		local y = FLOOR + 12 + i * lift.leafEvery
		local s = (i % 2 == 0) and 1 or -1
		prim(list, "Hub", "LiftLeaf", Vector3.new(2.6, 0.3, 1.4), CFrame.lookAt(Vector3.new(lp.X, y, lp.Z) + side * s * 1.8, Vector3.new(lp.X, y, lp.Z) + side * s * 4) * CFrame.Angles(math.rad(-20), 0, 0), LC.withered,
			{ material = "SmoothPlastic", collide = false, attrs = { LiftPart = "leaf" } })
	end
	local br = lift.basketRadius
	prim(list, "Hub", "VineLift", Vector3.new(0.6, br * 2, br * 2), CFrame.new(lp.X, FLOOR + 0.5, lp.Z) * CFrame.Angles(0, 0, math.rad(90)), LC.withered,
		{ shape = "Cylinder", material = "SmoothPlastic", attrs = { VineLift = true, LiftPart = "basket" } })
	for k = 0, 9 do -- 바구니 테두리 잎(비스듬히 세운 잎 10장 - 충돌 없음)
		local a = k / 10 * 2 * math.pi
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local at = Vector3.new(lp.X, FLOOR + 1.6, lp.Z) + dir * (br - 0.3)
		prim(list, "Hub", "LiftBasketLeaf", Vector3.new(2.6, 2.4, 0.3), CFrame.lookAt(at, at + dir) * CFrame.Angles(math.rad(-25), 0, 0), LC.withered,
			{ material = "SmoothPlastic", collide = false, attrs = { LiftPart = "leaf" } })
	end
	-- 표지(자물쇠 · 정거장 안내 글은 클라 - 이 파트는 자리만): 바구니 옆 기둥 + 머리
	local post = Vector3.new(lp.X, FLOOR, lp.Z) + outward * (br + 2.5)
	prim(list, "Hub", "LiftSignPost", Vector3.new(0.6, lift.signHeight - 2, 0.6), CFrame.new(post + Vector3.new(0, (lift.signHeight - 2) / 2, 0)), tree.barkDark, { material = "SmoothPlastic" })
	prim(list, "Hub", "LiftSign", Vector3.new(1, 1, 1), CFrame.new(post + Vector3.new(0, lift.signHeight, 0)), tree.barkDark,
		{ material = "SmoothPlastic", collide = false, transparency = 1, attrs = { LiftPart = "sign" } })
	-- 나무 입구 정거장 안내판(코스 시작 각 · 바깥 길 밖): 판(글 = 클라 SurfaceGui) + 기둥 둘
	local EB = tree.course.entranceBoard
	local ea = tree.course.station.startAngleDeg
	local ep = Layout.hubPoint(ea, EB.r)
	local eo = Vector3.new(ep.X, 0, ep.Z).Unit
	local boardCf = CFrame.lookAt(Vector3.new(ep.X, FLOOR + EB.bottom + EB.h / 2, ep.Z), Vector3.new(ep.X, FLOOR + EB.bottom + EB.h / 2, ep.Z) + eo)
	prim(list, "Hub", "StationBoard", Vector3.new(EB.w, EB.h, 0.6), boardCf, tree.barkDark, { material = "SmoothPlastic", attrs = { StationBoard = true } })
	for _, sx in ipairs({ -1, 1 }) do
		local foot = boardCf * CFrame.new(sx * (EB.w / 2 - 0.6), -EB.h / 2, 0.5)
		prim(list, "Hub", "StationBoardPost", Vector3.new(0.6, EB.bottom + EB.h, 0.6), CFrame.new(foot.Position.X, FLOOR + (EB.bottom + EB.h) / 2, foot.Position.Z), tree.bark, { material = "SmoothPlastic" })
	end
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

-- ─────────────────────────── 봉인 입구(M1 티저) ───────────────────────────
-- 문 좌표계: 원점 = 문 바닥 가운데 · 로컬 −Z = 문 앞(사람이 서는 쪽) · +Z = 봉인 상자 안쪽.
function Layout.sealedFrame(entry)
	local d = dirOf(entry.at.angleDeg)
	local p = d * entry.at.r + Vector3.new(0, FLOOR + (entry.at.y or 0), 0)
	local front = entry.facing == "out" and d or -d
	return CFrame.lookAt(p, p + front)
end

-- 봉인 상자(서버 구역 검사 · 투명 벽): { id, name, cf(문 좌표계), w, d, h, ledge = { localPos(문 좌표계 선반 윗면 가운데), halfX, halfZ } }
function Layout.sealedBoxes()
	local S = D.sealed
	local list = {}
	for _, e in ipairs(S.entrances) do
		local cf = Layout.sealedFrame(e)
		local door = S.door
		local ledgeX = door.width / 2 + door.frame + door.wallW / 2
		table.insert(list, { id = e.id, name = e.name, cf = cf, w = e.box.w, d = e.box.d, h = e.box.h,
			ledge = { localPos = Vector3.new(ledgeX, door.ledgeH, -1), halfX = door.wallW / 2, halfZ = 3 } })
	end
	return list
end

-- 점이 봉인 상자 안인가(문 좌표계로 옮겨 잰다)
function Layout.insideSealed(box, position)
	local l = box.cf:PointToObjectSpace(position)
	return math.abs(l.X) < box.w / 2 and l.Z > 1 and l.Z < box.d + 1 and l.Y > -2 and l.Y < box.h
end

local SEALED_PROPS = {}
function SEALED_PROPS.clockTower(list, model, cf, door)
	-- 바늘 없는 시계판(문 위 탑 벽) · 멈춘 큰 톱니(문 옆에 기대어) · 째깍 소리 자리
	prim(list, model, "TowerFace", Vector3.new(22, 22, 3), cf * CFrame.new(0, door.height + 4 + 11, 0.5), { 120, 116, 110 }, { material = "SmoothPlastic" })
	prim(list, model, "ClockFace", Vector3.new(1, 14, 14), cf * CFrame.new(0, door.height + 17, -1.5) * CFrame.Angles(0, math.rad(90), 0), { 235, 225, 200 }, { shape = "Cylinder", material = "SmoothPlastic" })
	prim(list, model, "ClockRim", Vector3.new(0.8, 16, 16), cf * CFrame.new(0, door.height + 17, -1) * CFrame.Angles(0, math.rad(90), 0), { 150, 120, 60 }, { shape = "Cylinder", material = "SmoothPlastic" })
	local gear = cf * CFrame.new(-(door.width / 2 + 9), 9, -6) * CFrame.Angles(0, 0, math.rad(78))
	prim(list, model, "Gear", Vector3.new(2, 16, 16), gear * CFrame.Angles(0, math.rad(90), 0), { 160, 140, 90 }, { shape = "Cylinder", material = "SmoothPlastic" })
	for k = 1, 10 do
		local a = k / 10 * 2 * math.pi
		prim(list, model, "GearTooth", Vector3.new(2, 3, 2), gear * CFrame.new(math.cos(a) * 8.6, math.sin(a) * 8.6, 0) * CFrame.Angles(0, 0, a), { 160, 140, 90 }, { material = "SmoothPlastic" })
	end
	prim(list, model, "TickSpot", Vector3.new(1, 1, 1), cf * CFrame.new(0, door.height + 12, -3), { 0, 0, 0 }, { collide = false, transparency = 1, attrs = { SealedSound = "tick" } })
end
function SEALED_PROPS.giantKitchen(list, model, cf, door)
	-- 문틈에 걸린 거대 포크(손잡이 + 살 4) · 굴러 나온 빵 조각
	local fork = cf * CFrame.new(3, 10, -3) * CFrame.Angles(math.rad(-25), math.rad(10), math.rad(-35))
	prim(list, model, "ForkHandle", Vector3.new(30, 3, 3), fork * CFrame.new(-12, 0, 0), { 200, 200, 210 }, { shape = "Cylinder", material = "SmoothPlastic" })
	prim(list, model, "ForkNeck", Vector3.new(4, 2, 12), fork * CFrame.new(4, 0, 0), { 200, 200, 210 }, { material = "SmoothPlastic" })
	for k = 1, 4 do
		prim(list, model, "ForkTine", Vector3.new(12, 1.4, 1.4), fork * CFrame.new(11, 0, -4.5 + (k - 1) * 3), { 200, 200, 210 }, { material = "SmoothPlastic" })
	end
	prim(list, model, "Bread", Vector3.new(10, 6, 7), cf * CFrame.new(-8, 3, -14) * CFrame.Angles(0, math.rad(30), math.rad(8)), { 214, 160, 90 }, { material = "SmoothPlastic", mesh = "Sphere" })
	prim(list, model, "BreadCrumb", Vector3.new(3, 2, 3), cf * CFrame.new(-2, 1, -20), { 214, 160, 90 }, { material = "SmoothPlastic", mesh = "Sphere" })
end
function SEALED_PROPS.puppetTheater(list, model, cf, door)
	-- 반쯤 걷힌 커튼(양옆) · 끊어진 줄에 매달린 작은 인형
	prim(list, model, "Curtain", Vector3.new(6, door.height + 4, 1.5), cf * CFrame.new(-(door.width / 2 - 2), (door.height + 4) / 2, -2.5), { 170, 30, 45 }, { material = "Fabric" })
	prim(list, model, "Curtain", Vector3.new(4, door.height, 1.5), cf * CFrame.new(door.width / 2 - 1, door.height / 2 + 2, -2.5) * CFrame.Angles(0, 0, math.rad(6)), { 170, 30, 45 }, { material = "Fabric" })
	prim(list, model, "PuppetString", Vector3.new(0.2, 7, 0.2), cf * CFrame.new(2, door.height - 3.5, -4), { 230, 230, 230 }, { collide = false })
	prim(list, model, "PuppetHead", Vector3.new(1.6, 1.6, 1.6), cf * CFrame.new(2, door.height - 8, -4), { 240, 210, 180 }, { shape = "Ball", material = "SmoothPlastic", collide = false })
	prim(list, model, "PuppetBody", Vector3.new(1.6, 2.4, 1), cf * CFrame.new(2, door.height - 10, -4) * CFrame.Angles(0, 0, math.rad(12)), { 60, 90, 170 }, { material = "SmoothPlastic", collide = false })
	prim(list, model, "BrokenString", Vector3.new(0.2, 3, 0.2), cf * CFrame.new(-1, door.height - 2, -4) * CFrame.Angles(0, 0, math.rad(30)), { 230, 230, 230 }, { collide = false })
end
function SEALED_PROPS.cloudWhale(list, model, cf, door, entry)
	-- 구름 발판(전망대 바깥) + 구름 문(흰 구름 뭉치가 문틀을 감싼다) + 큰 그림자 자리(로컬 연출)
	local pl = entry.platform
	local d = dirOf(entry.at.angleDeg)
	local pp = d * pl.r + Vector3.new(0, FLOOR + entry.at.y - 1.5, 0)
	prim(list, model, "CloudPlatform", Vector3.new(3, pl.size, pl.size), CFrame.new(pp) * CFrame.Angles(0, 0, math.rad(90)), { 245, 248, 252 }, { shape = "Cylinder", material = "SmoothPlastic" })
	for k = 1, 6 do
		local a = k / 6 * math.pi
		prim(list, model, "CloudPuff", Vector3.new(10, 7, 7), cf * CFrame.new(math.cos(a) * (door.width / 2 + 3), math.sin(a) * (door.height * 0.7) + door.height * 0.4, -1.5), { 250, 252, 255 },
			{ material = "SmoothPlastic", mesh = "Sphere", collide = false })
	end
	prim(list, model, "WhaleShadowSpot", Vector3.new(1, 1, 1), cf * CFrame.new(0, 120, 60), { 0, 0, 0 }, { collide = false, transparency = 1, attrs = { SealedFx = "whaleShadow" } })
end
function SEALED_PROPS.moleMine(list, model, cf)
	-- 어둠으로 이어진 레일 · 멈춘 광차 · 튀어나왔다 사라지는 흙더미 자리
	for side = -1, 1, 2 do
		prim(list, model, "Rail", Vector3.new(0.6, 0.6, 44), cf * CFrame.new(side * 2.2, 0.3, -18), { 90, 90, 95 }, { material = "SmoothPlastic" })
	end
	for k = 0, 6 do
		prim(list, model, "Sleeper", Vector3.new(7, 0.5, 1.4), cf * CFrame.new(0, 0.25, -2 - k * 6), { 110, 80, 55 }, { material = "SmoothPlastic" })
	end
	local cart = cf * CFrame.new(0, 3, -26)
	prim(list, model, "Cart", Vector3.new(6, 4, 7), cart, { 120, 100, 80 }, { material = "SmoothPlastic" })
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			prim(list, model, "Wheel", Vector3.new(0.8, 2.2, 2.2), cart * CFrame.new(sx * 3.2, -2, sz * 2.4), { 60, 60, 65 }, { shape = "Cylinder", material = "SmoothPlastic" })
		end
	end
	prim(list, model, "MoundSpot", Vector3.new(1, 1, 1), cf * CFrame.new(9, 0, -32), { 0, 0, 0 }, { collide = false, transparency = 1, attrs = { SealedFx = "moleMound" } })
end

function Layout.buildSealed(list)
	local S = D.sealed
	local door = S.door
	for _, e in ipairs(S.entrances) do
		local model = "Sealed_" .. e.id
		local cf = Layout.sealedFrame(e)
		local stone, stoneDark = { 120, 116, 110 }, { 84, 80, 76 }
		-- 문틀 · 문짝(어둡다) · 사슬 X · 덩굴 · 잠든 문장 · 낡은 명판("이름 ???" - 작게)
		for side = -1, 1, 2 do
			prim(list, model, "DoorPost", Vector3.new(door.frame, door.height + 4, door.frame + 1), cf * CFrame.new(side * (door.width / 2 + door.frame / 2), (door.height + 4) / 2, 0), stone, { material = "SmoothPlastic" })
		end
		prim(list, model, "DoorLintel", Vector3.new(door.width + door.frame * 2, 4, door.frame + 1), cf * CFrame.new(0, door.height + 2, 0), stone, { material = "SmoothPlastic" })
		prim(list, model, "DoorSlab", Vector3.new(door.width, door.height, 1.5), cf * CFrame.new(0, door.height / 2, 0.5), { 40, 34, 32 }, { material = "SmoothPlastic" })
		for side = -1, 1, 2 do
			local len = math.sqrt(door.width ^ 2 + door.height ^ 2)
			local ang = math.atan2(door.height, door.width) * side
			prim(list, model, "Chain", Vector3.new(len, 0.9, 0.9), cf * CFrame.new(0, door.height / 2, -0.6) * CFrame.Angles(0, 0, ang), { 150, 150, 160 }, { shape = "Cylinder", material = "SmoothPlastic", collide = false })
		end
		for k = 1, 3 do
			prim(list, model, "Vine", Vector3.new(0.7, door.height * (0.6 + k * 0.1), 0.7), cf * CFrame.new(-door.width / 2 + k * 4, door.height * 0.55, -1) * CFrame.Angles(0, 0, math.rad(-12 + k * 9)), { 70, 110, 60 },
				{ material = "SmoothPlastic", collide = false })
		end
		prim(list, model, "SealEmblem", Vector3.new(0.4, door.emblemSize, door.emblemSize), cf * CFrame.new(0, door.height / 2, -0.4) * CFrame.Angles(0, math.rad(90), 0), { 170, 150, 230 },
			{ shape = "Cylinder", neon = true, collide = false, transparency = 0.5, attrs = { SealEmblem = e.id } })
		prim(list, model, "Plaque", Vector3.new(8, 1.6, 0.4), cf * CFrame.new(0, door.height + 5, -1.6), { 110, 90, 70 },
			{ material = "SmoothPlastic", attrs = { Label = e.name .. " ???", LabelSmall = true } })
		-- 무너진 담 + 틈 선반(선반 높이 ledgeH · 위 구멍 holeH · 그 위 담)
		local lx = door.width / 2 + door.frame + door.wallW / 2
		prim(list, model, "CrumbledWall", Vector3.new(door.wallW, door.ledgeH, 6), cf * CFrame.new(lx, door.ledgeH / 2, -1), stoneDark, { material = "SmoothPlastic", attrs = { SealedLedge = e.id } })
		local upperY = door.ledgeH + door.holeH
		prim(list, model, "CrumbledWall", Vector3.new(door.wallW, door.height + 4 - upperY, 4), cf * CFrame.new(lx, upperY + (door.height + 4 - upperY) / 2, 0), stoneDark, { material = "SmoothPlastic" })
		prim(list, model, "Wall", Vector3.new(door.wallW, door.height + 4, 4), cf * CFrame.new(-lx, (door.height + 4) / 2, 0), stoneDark, { material = "SmoothPlastic" })
		-- 봉인 상자(투명 충돌 벽 5면 - 조준 광선 · 지면 광선에 안 걸리게 쿼리 없음). 안쪽은 비운다.
		local walls = "SealedWalls_" .. e.id
		local w, dd, h = e.box.w, e.box.d, e.box.h
		local inv = { transparency = 1, query = false }
		prim(list, walls, "SealWall", Vector3.new(w, h, 2), cf * CFrame.new(0, h / 2, 2), stone, inv)
		prim(list, walls, "SealWall", Vector3.new(w, h, 2), cf * CFrame.new(0, h / 2, dd + 2), stone, inv)
		prim(list, walls, "SealWall", Vector3.new(2, h, dd), cf * CFrame.new(-w / 2, h / 2, dd / 2 + 2), stone, inv)
		prim(list, walls, "SealWall", Vector3.new(2, h, dd), cf * CFrame.new(w / 2, h / 2, dd / 2 + 2), stone, inv)
		prim(list, walls, "SealWall", Vector3.new(w, 2, dd), cf * CFrame.new(0, h, dd / 2 + 2), stone, inv)
		SEALED_PROPS[e.props](list, model, cf, door, e)
	end
end

-- ─────────────────────────── 보스 관문(M1-3 관문 등록) ───────────────────────────
-- 한눈에 관문(사용자): 보스 색 큰 아치(기둥 · 들보) + 들보 앞 문양(등록하면 켜진다 - 클라가 사람마다 칠한다) + 안쪽 빛 막 + 발판(밟으면 입장) + 빛기둥(Persistent - 멀리서 등록 여부).
--   PromptAnchor = 등록 상호작용(F · 폰 버튼 - 서버 BossGate가 ProximityPrompt를 붙인다). 모델 = BossGate_<bossId>.
function Layout.buildBossGates(list)
	local G = D.bossGate
	for _, g in ipairs(Layout.bossGates()) do
		local model = "BossGate_" .. g.bossId
		local cf = flatYaw(g.position, g.dir)
		local half = G.width / 2
		local dark = { math.floor(g.color[1] * 0.45), math.floor(g.color[2] * 0.45), math.floor(g.color[3] * 0.45) }
		column(list, model, "BossGatePost", cf * CFrame.new(-half, 0, 0), G.postSize, G.postSize, G.height, dark, { material = "SmoothPlastic" })
		column(list, model, "BossGatePost", cf * CFrame.new(half, 0, 0), G.postSize, G.postSize, G.height, dark, { material = "SmoothPlastic" })
		prim(list, model, "BossGateTop", Vector3.new(G.width + G.postSize + 6, G.beam, G.postSize + 2), cf * CFrame.new(0, G.height + G.beam / 2, 0), dark, { material = "SmoothPlastic" })
		-- 기둥 안쪽 모서리 띠(보스 색 - 늘 켜짐 · 아치 윤곽)
		for _, sx in ipairs({ -1, 1 }) do
			prim(list, model, "BossGateTrim", Vector3.new(1.2, G.height, 1.2), cf * CFrame.new(sx * (half - G.postSize / 2 - 0.6), G.height / 2, G.postSize / 2 + 0.2), g.color, { collide = false, neon = true })
		end
		prim(list, model, "BossGateTrim", Vector3.new(G.width - G.postSize, 1.2, 1.2), cf * CFrame.new(0, G.height - 0.6, G.postSize / 2 + 0.2), g.color, { collide = false, neon = true })
		-- 문양(들보 앞 · 허브 쪽 면 = 로컬 +Z - flatYaw의 −Z가 바깥): 마름모 + 가로 띠 - 등록 전 꺼짐 · 등록 뒤 켜짐(클라)
		prim(list, model, "BossGateEmblem", Vector3.new(G.emblem, G.emblem, 1), cf * CFrame.new(0, G.height + G.beam / 2, G.postSize / 2 + 1.6) * CFrame.Angles(0, 0, math.rad(45)), g.color,
			{ collide = false, neon = true, attrs = { GateEmblem = g.bossId } })
		prim(list, model, "BossGateEmblem", Vector3.new(G.width * 0.7, 1.4, 1), cf * CFrame.new(0, G.height + G.beam / 2, G.postSize / 2 + 1.4), g.color,
			{ collide = false, neon = true, attrs = { GateEmblem = g.bossId } })
		-- 안쪽 빛 막(문 안 - 통과 가능 · 흐릿하게)
		prim(list, model, "BossGateVeil", Vector3.new(G.width - G.postSize, G.height, 0.4), cf * CFrame.new(0, G.height / 2, 0), g.color, { collide = false, neon = true, transparency = 0.78 })
		-- 발판(밟으면 입장 - 서버 거리 폴링) · 등록 프롬프트 자리
		prim(list, model, "BossGatePad", Vector3.new(0.4, L.gate.radius * 2, L.gate.radius * 2), CFrame.new(g.position.X, FLOOR + 0.45, g.position.Z) * CFrame.Angles(0, 0, math.rad(90)), g.color,
			{ shape = "Cylinder", material = "SmoothPlastic", attrs = { BossGate = g.zoneKey or g.bossId, BossId = g.bossId } })
		prim(list, model, "PromptAnchor", Vector3.new(2, 2, 2), cf * CFrame.new(0, 5, G.promptOffset), -- 허브 쪽 · 발판(반경 18) 밖
			 g.color, { collide = false, transparency = 1, attrs = { GatePrompt = g.bossId } })
		-- 빛기둥(Persistent · 보스 색 - 등록 전 흐리게 깜빡 · 뒤 밝게 꾸준히 = 클라)
		local P = D.gatePillar
		prim(list, "GatePillars", "GatePillar", Vector3.new(P.width, P.height, P.width), CFrame.new(g.position.X, FLOOR + P.height / 2, g.position.Z), g.color,
			{ collide = false, neon = true, transparency = P.transparency, attrs = { GatePillar = g.zoneKey or g.bossId, BossId = g.bossId } })
	end
end

-- ─────────────────────────── 세계 전체 ───────────────────────────
-- 반환: prims, meta{ zones[key] = 구역 메타 }
function Layout.buildAll()
	local list = {}
	-- M1-3: 바닥 = 로블록스 Terrain(굽기 - server/TerrainBake · 식 shared/TerrainShape). 옛 바닥 타일은 없다.
	-- 세계 끝: 투명 벽(실제 차단 백업 - 보이는 경계 = 외곽 설산 지형 · 서버 밀어내기 = Travel)
	local E = D.edge
	for i = 1, E.segments do
		local a = (i - 0.5) / E.segments * 2 * math.pi
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local len = 2 * math.pi * E.radius / E.segments + 4
		local p = d * E.radius
		local cf = CFrame.lookAt(Vector3.new(p.X, FLOOR, p.Z), Vector3.new(p.X, FLOOR, p.Z) + d)
		prim(list, "Edge", "EdgeWall", Vector3.new(len, E.wallHeight, 4), cf * CFrame.new(0, E.wallHeight / 2 - 2, 2), D.colors.block, { transparency = 1 })
	end
	Layout.buildHub(list)
	Layout.buildSealed(list)
	local meta = { zones = {} }
	for _, z in ipairs(D.zones) do
		meta.zones[z.key] = Layout.buildZone(z, list)
	end
	Layout.buildBossGates(list)
	-- M1-3 둥지 3트랙 · 구조물(비밀 둥지 먼저 - 지형 마스크도 같은 목록에서 나온다)
	local S = require(ReplicatedStorage.Shared.WorldStructures).build(list)
	for _, n in ipairs(S.nests) do
		local zm = meta.zones[n.zone]
		if zm then
			table.insert(zm.nests, n)
		end
	end
	meta.structures = S
	-- M1-4 빈 공간 채우기(소품 흩뿌리기 · 절벽 사다리 - shared/PropScatter)
	meta.scatter = require(ReplicatedStorage.Shared.PropScatter).build(list)
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
	local RoadNet = require(ReplicatedStorage.Shared.RoadNet)
	for _, z in ipairs(D.zones) do
		local route = {} -- M1-4 곡선 길(본길 · 갈림길) 조각
		for _, path in ipairs({ RoadNet.zonePath(z), RoadNet.branchPath(z) }) do
			for i = 1, #path.pts, 3 do
				local q = path.pts[i]
				table.insert(route, { id = path.kind .. i, p = Vector3.new(q.x, 0, q.z) })
			end
		end
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
				if route[i].id:match("^%a+") == route[i - 1].id:match("^%a+") and segDist(p, route[i - 1].p, route[i].p) < radius + L.roadWidth / 2 + 4 then
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
		-- (M1-3: 둥지 3트랙은 WorldCheck가 잰다 - 필수 길 · 구조물 겹침)
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
