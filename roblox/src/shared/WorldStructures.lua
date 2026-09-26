-- M1-3 구조물 · 둥지 조립(순수). 둥지 자리 = data/NestData · 구조물 = data/WorldStructureData · 키트 = shared/WorldStructureKits.
-- 비밀 둥지 먼저(사용자): 둥지 · 구조물이 받침(pad) · 흙더미(raise) · 보호 부피(protect)를 내면 TerrainShape가 그 자리를 비우고 둘레에 지형을 쌓는다(terrainMasks).
-- 부르는 곳: WorldMapLayout.buildAll(도형) · TerrainShape(지형 마스크) · 서버 NestServer · 선인장 피해 · 검증 M1-3T.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NestData = require(ReplicatedStorage.Shared.data.NestData)
local TerrainGenData = require(ReplicatedStorage.Shared.data.TerrainGenData)
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local WorldStructureData = require(ReplicatedStorage.Shared.data.WorldStructureData)
local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)
local Kits = require(ReplicatedStorage.Shared.WorldStructureKits)

local WorldStructures = {}
local FLOOR = WorldMapData.floorTopY
local FLAT = FLOOR + TerrainGenData.flatLevel
local K = NestData.kit
local prim, col, box = Kits.prim, Kits.col, Kits.box

local function hashStr(s)
	local h = 7
	for i = 1, #s do
		h = (h * 31 + s:byte(i)) % 1000003
	end
	return h
end
WorldStructures.hashStr = hashStr

local function toHubDir(x, z)
	local m = math.sqrt(x * x + z * z)
	return m > 1e-3 and Vector3.new(-x / m, 0, -z / m) or Vector3.new(0, 0, -1)
end
local function rotY(v, deg)
	local a = math.rad(deg or 0)
	local c, s = math.cos(a), math.sin(a)
	return Vector3.new(v.X * c + v.Z * s, 0, -v.X * s + v.Z * c)
end
local function zoneOf(key)
	return WorldMapLayout.zoneByKey(key)
end
local function mesaOf(zoneKey, index)
	local zone = zoneOf(zoneKey)
	local m = TerrainGenData.zones[zoneKey].mesas[index]
	local p = WorldMapLayout.toWorld(zone, m.r, m.lat)
	return { x = p.X, z = p.Z, radius = m.radius, blend = m.blend, level = FLAT + m.level }
end
-- 받침 높이: 숫자 = 평지 + 그만큼 · 없으면 자연 높이(굽기 전 식 - 언덕 위면 언덕 높이 · 둥지 받침이 언덕을 원형으로 깎아 분화구처럼 보이지 않게)
local function baseYAt(spec, x, z)
	if spec.base ~= nil and spec.base ~= "natural" then
		return FLAT + (tonumber(spec.base) or 0)
	end
	local h = require(ReplicatedStorage.Shared.TerrainShape).baseHeight(x, z)
	return math.max(FLAT, h)
end

-- ─────────────────────────── 특수 둥지(구조물을 통째로 짓는다) ───────────────────────────
local SPECIAL = {}

-- T3 수중 신전(랜드마크 · 바다 만 바닥 · 아래층 = 빈 방 + 지붕 · 앞 문 = 물속) - B 최상위
function SPECIAL.sunken(ctx, list)
	local zone = zoneOf(ctx.spec.zone)
	local lm = zone.landmark
	local bay = TerrainGenData.zones[zone.key].bay
	local center = WorldMapLayout.toWorld(zone, lm.r + 90, 0)
	local baseY = FLOOR + bay.bed + 1
	local look = Kits.look(zone.key)
	local toHub = toHubDir(center.X, center.Z)
	local cf = CFrame.lookAt(Vector3.new(center.X, baseY, center.Z), Vector3.new(center.X, baseY, center.Z) + toHub)
	ctx.model = "Landmark_" .. zone.key
	local layers, lh = 4, lm.height / 4
	local s1, t = lm.radius * 2, 3
	local door = { w = 7, h = 9 }
	-- 1층: 벽 4(앞 = 문) + 지붕
	col(list, ctx.model, "TempleWall", cf * CFrame.new(0, 0, s1 / 2 - t / 2), s1, t, lh, look)
	for _, sx in ipairs({ -1, 1 }) do
		col(list, ctx.model, "TempleWall", cf * CFrame.new(sx * (s1 / 2 - t / 2), 0, 0), t, s1 - 2 * t, lh, look)
		local side = (s1 - door.w) / 2
		col(list, ctx.model, "TempleWall", cf * CFrame.new(sx * (door.w / 2 + side / 2), 0, -(s1 / 2 - t / 2)), side, t, lh, look)
	end
	prim(list, ctx.model, "TempleWall", Vector3.new(door.w, lh - door.h, t), cf * CFrame.new(0, door.h + (lh - door.h) / 2, -(s1 / 2 - t / 2)), look.color, { material = look.material })
	prim(list, ctx.model, "TempleRoof", Vector3.new(s1, t, s1), cf * CFrame.new(0, lh - t / 2, 0), look.dark, { material = look.material })
	for i = 2, layers do
		local s = s1 * (1 - (i - 1) / layers)
		prim(list, ctx.model, "TempleTier", Vector3.new(s, lh, s), cf * CFrame.new(0, lh * (i - 0.5), 0), i % 2 == 0 and look.color or look.dark, { material = look.material })
	end
	for _, sx in ipairs({ -1, 1 }) do -- 꼭대기 기둥 둘(물 위 실루엣)
		prim(list, ctx.model, "TempleSpire", Vector3.new(3, 12, 3), cf * CFrame.new(sx * 7, lm.height + 6, 0), look.dark, { material = look.material })
	end
	-- 방 안 기둥 몇 개(장식 · 충돌) + 둥지
	for _, p in ipairs({ { -24, -24 }, { 24, -24 }, { -24, 24 }, { 24, 24 } }) do
		col(list, ctx.model, "TempleColumn", cf * CFrame.new(p[1], 0, p[2]), 4, 4, lh - t, look)
	end
	local spot = (cf * CFrame.new(0, 0, 18)).Position
	local water = FLOOR + bay.level
	return {
		spot = spot, leaps = {}, swim = true,
		roof = { y = baseY + lh - t, center = cf.Position, halfX = s1 / 2, halfZ = s1 / 2 },
		door = { pos = (cf * CFrame.new(0, 0, -s1 / 2)).Position, width = door.w, dir = cf.LookVector },
		path = { (cf * CFrame.new(0, 1, -s1 / 2 - 6)).Position, (cf * CFrame.new(0, 1, -s1 / 2 + 3)).Position, spot + Vector3.new(0, 1, 0) },
		protect = { box(cf * CFrame.new(0, (lh - t) / 2, 0), Vector3.new(s1 / 2 - t, (lh - t) / 2, s1 / 2 - t), water), box(cf * CFrame.new(0, door.h / 2 + 1, -s1 / 2 - 5), Vector3.new(door.w / 2 + 2, door.h / 2 + 1, 5), water) },
		pads = {}, baseY = baseY, cf = cf,
	}
end

-- T5 흔들다리(두 어깨 대지 사이 · 가운데 오두막 = B 둥지) - 흔들림은 클라 연출만(BridgePlank · 서버 판정 = 고정 위치)
function SPECIAL.bridgeHut(ctx, list)
	local zkey = ctx.spec.zone
	local a, b = mesaOf(zkey, 1), mesaOf(zkey, 2)
	local B = K.bridge
	local pa, pb = Vector3.new(a.x, 0, a.z), Vector3.new(b.x, 0, b.z)
	local dir = (pb - pa).Unit
	local startP = pa + dir * (a.radius - 2)
	local endP = pb - dir * (b.radius - 2)
	local L = (endP - startP).Magnitude
	local y0 = a.level
	local n = math.ceil(L / B.plank)
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local model = "Struct_" .. zkey .. "_bridge"
	ctx.model = model
	local hutT0, hutT1 = 0.5 - (B.hut / 2) / L, 0.5 + (B.hut / 2) / L
	local look = Kits.look(zkey)
	for i = 1, n do
		local t = (i - 0.5) / n
		if t < hutT0 or t > hutT1 then
			local p = startP + dir * (L * t)
			local y = y0 - B.sag * math.sin(math.pi * t)
			local slope = -B.sag * math.pi * math.cos(math.pi * t) / L
			local cf = CFrame.lookAt(Vector3.new(p.X, y - 0.5, p.Z), Vector3.new(p.X, y - 0.5, p.Z) + dir) * CFrame.Angles(math.atan(slope), 0, 0)
			prim(list, model, "BridgePlank", Vector3.new(B.width, 1, B.plank + 0.15), cf, Kits.WOOD.color, { material = "Wood", attrs = { BridgePlank = i } })
			for _, sx in ipairs({ -1, 1 }) do
				prim(list, model, "BridgeRope", Vector3.new(0.4, 0.4, B.plank + 0.3), cf * CFrame.new(sx * (B.width / 2 - 0.2), B.rail, 0), { 150, 120, 80 }, { collide = false, attrs = { BridgePlank = i } })
			end
		end
	end
	for _, e in ipairs({ { startP, a }, { endP, b } }) do
		for _, sx in ipairs({ -1, 1 }) do
			local p = e[1] + side * sx * (B.width / 2 + 0.8)
			prim(list, model, "BridgePost", Vector3.new(1.2, 6, 1.2), CFrame.new(p.X, y0 + 2.5, p.Z), Kits.WOOD.color, { material = "Wood" })
		end
	end
	-- 오두막(가운데): 바닥 · 옆벽 · 양끝 문 · 지붕
	local mid = startP + dir * (L / 2)
	local hy = y0 - B.sag
	local cf = CFrame.lookAt(Vector3.new(mid.X, hy, mid.Z), Vector3.new(mid.X, hy, mid.Z) + dir)
	local s, h = B.hut, B.hutH
	prim(list, model, "HutFloor", Vector3.new(s, 1, s), cf * CFrame.new(0, -0.5, 0), Kits.WOOD.color, { material = "Wood" })
	for _, sx in ipairs({ -1, 1 }) do
		prim(list, model, "HutWall", Vector3.new(1, h, s), cf * CFrame.new(sx * (s / 2 - 0.5), h / 2, 0), look.color, { material = look.material })
		for _, sz in ipairs({ -1, 1 }) do
			local sideW = (s - 5) / 2
			prim(list, model, "HutWall", Vector3.new(sideW, h, 1), cf * CFrame.new(sx * (2.5 + sideW / 2), h / 2, sz * (s / 2 - 0.5)), look.color, { material = look.material })
		end
	end
	for _, sz in ipairs({ -1, 1 }) do
		prim(list, model, "HutWall", Vector3.new(5, h - 6.5, 1), cf * CFrame.new(0, 6.5 + (h - 6.5) / 2, sz * (s / 2 - 0.5)), look.color, { material = look.material })
	end
	prim(list, model, "HutRoof", Vector3.new(s + 2, 1.4, s + 2), cf * CFrame.new(0, h + 0.7, 0), look.dark, { material = look.material })
	local spot = (cf * CFrame.new(-s / 4, 0, 0)).Position
	local protect = {}
	for i = 0, 4 do
		local t = i / 4
		local p = startP + dir * (L * t)
		table.insert(protect, box(CFrame.lookAt(Vector3.new(p.X, y0 + 3, p.Z), Vector3.new(p.X, y0 + 3, p.Z) + dir), Vector3.new(B.width / 2 + 1, 7, L / 8 + 2)))
	end
	ctx.bridge = { startP = startP, endP = endP, y0 = y0, length = L, planks = n }
	return {
		spot = spot, leaps = {}, walk = true, bridge = ctx.bridge,
		roof = { y = hy + h, center = cf.Position, halfX = s / 2, halfZ = s / 2 },
		door = { pos = (cf * CFrame.new(0, 0, -s / 2)).Position, width = 5, dir = -dir },
		path = { Vector3.new(startP.X, y0, startP.Z), (cf * CFrame.new(0, 0, -s / 2 - 2)).Position, (cf * CFrame.new(0, 0, -s / 2 + 1)).Position, spot },
		protect = protect, pads = {},
	}
end

-- 허브 C-마을: 대장간 굴뚝 · 시장 다락 · 줄기 밑동 구멍 · 포탈 아치 위(상자 계단으로 쉽게 - 한 단계 낮은 보상)
local function facilityRow(name)
	local f = WorldMapData.hub.facilities[name]
	local p = WorldMapLayout.facility(name)
	local out = WorldMapLayout.dirOf(f.angleDeg)
	local base = Vector3.new(p.X, FLOOR, p.Z)
	local cf = CFrame.lookAt(base, base - out) -- −Z = 나무 쪽 · +X = 거리 방향(WorldMapLayout.buildHub와 같다)
	local R = f.row
	local back = (f.plaza or f.street.d / 2) + 6 + R.d / 2
	return cf, R, back
end
local function crates(ctx, list, cf, heights, dirZ)
	local leaps, prev = {}, 0
	for i, hgt in ipairs(heights) do
		col(list, ctx.model, "Crate", cf * CFrame.new(0, 0, dirZ * (i - 1) * 7), 4.5, 4.5, hgt, Kits.WOOD, { material = "WoodPlanks" })
		table.insert(leaps, { rise = hgt - prev, gap = i == 1 and 0 or 2.5 })
		prev = hgt
	end
	return leaps, prev
end
function SPECIAL.chimney(ctx, list)
	local cf, R, back = facilityRow(ctx.spec.facility)
	local x = (1 - (R.count + 1) / 2) * (R.w + R.gap)
	local roofY = R.h
	local bcf = cf * CFrame.new(x, 0, back)
	local look = Kits.look("tier1", "pillar")
	local ch = bcf * CFrame.new(R.w / 2 - 5, roofY, R.d / 2 - 5)
	local wall, inner, hh = 1, 4.4, 8
	local o = inner / 2 + wall / 2
	prim(list, ctx.model, "Chimney", Vector3.new(inner + 2 * wall, hh, wall), ch * CFrame.new(0, hh / 2, o), look.color, { material = "Brick" })
	for _, sx in ipairs({ -1, 1 }) do
		prim(list, ctx.model, "Chimney", Vector3.new(wall, hh, inner), ch * CFrame.new(sx * o, hh / 2, 0), look.color, { material = "Brick" })
	end
	prim(list, ctx.model, "Chimney", Vector3.new(inner + 2 * wall, hh - 5.8, wall), ch * CFrame.new(0, 5.8 + (hh - 5.8) / 2, -o), look.color, { material = "Brick" })
	prim(list, ctx.model, "ChimneyCap", Vector3.new(inner + 4, 1, inner + 4), ch * CFrame.new(0, hh + 0.5, 0), look.dark, { material = "Brick" })
	prim(list, ctx.model, "ChimneySoot", Vector3.new(inner, 0.2, inner), ch * CFrame.new(0, 0.1, 0), { 40, 36, 34 }, { collide = false })
	local leaps, top = crates(ctx, list, bcf * CFrame.new(-(R.w / 2 + 3), 0, -R.d / 2 + 2.5), { 5, 10, 15 }, 1)
	table.insert(leaps, { rise = roofY - top, gap = 1 })
	return {
		spot = ch.Position, leaps = leaps,
		roof = { y = ch.Position.Y + hh, center = ch.Position, halfX = inner / 2 + wall, halfZ = inner / 2 + wall },
		door = { pos = (ch * CFrame.new(0, 0, -o)).Position, width = inner, dir = ch.LookVector },
		path = { (ch * CFrame.new(0, 0, -o - 3)).Position, (ch * CFrame.new(0, 0, -o + 0.5)).Position, ch.Position }, protect = {}, pads = {},
	}
end
function SPECIAL.attic(ctx, list)
	local cf, R, back = facilityRow(ctx.spec.facility)
	local roofY = R.h + 4
	local bcf = cf * CFrame.new(0, 0, back)
	local look = Kits.look("tier1", "bark")
	local a = bcf * CFrame.new(0, roofY, 2) * CFrame.Angles(0, math.pi, 0) -- 문 = 건물 뒤쪽(+Z) 방향
	local w, h, t = 8, 6.5, 1
	prim(list, ctx.model, "Attic", Vector3.new(w + 2 * t, h, t), a * CFrame.new(0, h / 2, w / 2 + t / 2), look.color, { material = "WoodPlanks" })
	for _, sx in ipairs({ -1, 1 }) do
		prim(list, ctx.model, "Attic", Vector3.new(t, h, w), a * CFrame.new(sx * (w / 2 + t / 2), h / 2, 0), look.color, { material = "WoodPlanks" })
		prim(list, ctx.model, "Attic", Vector3.new(1.5, h, t), a * CFrame.new(sx * (2.5 + 0.75), h / 2, -(w / 2 + t / 2)), look.color, { material = "WoodPlanks" })
	end
	prim(list, ctx.model, "Attic", Vector3.new(5, 0.5, t), a * CFrame.new(0, h - 0.25, -(w / 2 + t / 2)), look.color, { material = "WoodPlanks" })
	prim(list, ctx.model, "AtticRoof", Vector3.new(w + 4, 1, w + 4), a * CFrame.new(0, h + 0.5, 0) * CFrame.Angles(0, 0, math.rad(8)), look.dark, { material = "WoodPlanks" })
	local leaps, top = crates(ctx, list, bcf * CFrame.new(-8, 0, R.d / 2 + 3), { 5, 10, 15 }, 1)
	table.insert(leaps, { rise = roofY - top, gap = 1 })
	return {
		spot = a.Position, leaps = leaps,
		roof = { y = a.Position.Y + h, center = a.Position, halfX = w / 2 + t, halfZ = w / 2 + t },
		door = { pos = (a * CFrame.new(0, 0, -(w / 2 + t))).Position, width = 5, dir = a.LookVector },
		path = { (a * CFrame.new(0, 0, -(w / 2 + t) - 3)).Position, (a * CFrame.new(0, 0, -w / 2 + 0.5)).Position, a.Position }, protect = {}, pads = {},
	}
end
function SPECIAL.trunk(ctx, list)
	local T = WorldMapData.hub.tree
	local A = K.alcove
	local r = T.trunkRadius + A.d / 2 + A.wall + 0.5
	local p = WorldMapLayout.hubPoint(ctx.spec.angleDeg, r)
	local out = WorldMapLayout.dirOf(ctx.spec.angleDeg)
	local base = Vector3.new(p.X, FLOOR, p.Z)
	ctx.cf = CFrame.lookAt(base, base + out)
	ctx.spec = setmetatable({ cover = "vine", style = "bark", noMound = true, hint = { "fireflies" } }, { __index = ctx.spec })
	return Kits.alcove(ctx, list)
end
function SPECIAL.arch(ctx, list)
	local f = WorldMapData.hub.facilities[ctx.spec.facility]
	local plaza = WorldMapLayout.facility(ctx.spec.facility)
	local toTree = toHubDir(plaza.X, plaza.Z)
	local c = Vector3.new(plaza.X, FLOOR, plaza.Z) + toTree * (f.radius + 8)
	local cf = CFrame.lookAt(c, c + toTree) -- −Z = 나무 쪽
	local look = Kits.look("tier1", "pillar")
	local span, ph = 13, 18
	for _, sx in ipairs({ -1, 1 }) do
		col(list, ctx.model, "ArchPillar", cf * CFrame.new(sx * span, 0, 0), 4, 4, ph, look)
	end
	prim(list, ctx.model, "ArchBeam", Vector3.new(2 * span + 6, 4, 6), cf * CFrame.new(0, ph + 2, 0), look.color, { material = look.material })
	-- 쐐기돌 속 틈(지붕 · 나무 쪽 문)
	local n = cf * CFrame.new(0, ph + 4, 0)
	local w, h, t = 5.5, 6, 1
	prim(list, ctx.model, "Keystone", Vector3.new(w + 2 * t, h, t), n * CFrame.new(0, h / 2, w / 2 + t / 2), look.dark, { material = look.material })
	for _, sx in ipairs({ -1, 1 }) do
		prim(list, ctx.model, "Keystone", Vector3.new(t, h, w), n * CFrame.new(sx * (w / 2 + t / 2), h / 2, 0), look.dark, { material = look.material })
	end
	prim(list, ctx.model, "KeystoneTop", Vector3.new(w + 4, 1.5, w + 4), n * CFrame.new(0, h + 0.75, 0), look.color, { material = look.material })
	local leaps, top = crates(ctx, list, cf * CFrame.new(span + 5, 0, 4), { 5, 10, 15, 20 }, -1)
	table.insert(leaps, { rise = ph + 4 - top, gap = 2 })
	return {
		spot = n.Position, leaps = leaps,
		roof = { y = n.Position.Y + h, center = n.Position, halfX = w / 2 + t, halfZ = w / 2 + t },
		door = { pos = (n * CFrame.new(0, 0, -w / 2)).Position, width = w, dir = n.LookVector },
		path = { (n * CFrame.new(0, 0, -w / 2 - 2)).Position, n.Position }, protect = {}, pads = {},
	}
end

-- ─────────────────────────── 둥지 조립 ───────────────────────────
local built = nil -- { prims, nests = { meta… }, byId, structures, pads, protect }

local function nestPos(spec)
	local zone = zoneOf(spec.zone)
	if spec.kit == "feature" then
		local f = zone.features[spec.feature]
		local off = spec.offset or { 0, 0 }
		local p = WorldMapLayout.toWorld(zone, f.r + off[1], f.lat + off[2])
		local topY = (f.kind == "plateau") and (FLAT + f.h) or (FLOOR + f.h)
		return Vector3.new(p.X, topY, p.Z)
	elseif spec.kit == "landmark" then
		local lm = zone.landmark
		local p = WorldMapLayout.toWorld(zone, lm.r + 90, 0)
		return Vector3.new(p.X, FLOOR + lm.height, p.Z)
	end
	local p = WorldMapLayout.toWorld(zone, spec.r, spec.lat)
	return Vector3.new(p.X, 0, p.Z)
end

local function buildNest(spec, list, templeCf)
	local ctx = { spec = spec, zone = spec.zone, model = "Nest_" .. spec.id, jitter = (hashStr(spec.id) % 100) / 100 * 0.5 }
	local meta
	if SPECIAL[spec.kit] then
		meta = SPECIAL[spec.kit](ctx, list)
	elseif spec.kit == "feature" or spec.kit == "landmark" then
		local spot = nestPos(spec)
		local leaps = spec.kit == "landmark" and { { rise = 15, gap = 0 }, { rise = 15, gap = 0 }, { rise = 15, gap = 0 }, { rise = 15, gap = 0 }, { rise = 15, gap = 0 }, { rise = 15, gap = 0 } } or { { rise = 4, gap = 4 } }
		meta = { spot = spot, leaps = leaps, open = true, protect = { box(CFrame.new(spot + Vector3.new(0, 3.5, 0)), Vector3.new(3, 3, 3)) }, pads = {} }
	else
		local p
		if spec.r then
			p = nestPos(spec)
		elseif spec.mesa then
			local m = mesaOf(spec.zone, spec.mesa)
			p = Vector3.new(m.x, 0, m.z)
		else -- 구역 굴 방
			local cv = TerrainGenData.zones[spec.zone].caves[spec.cave]
			local cp = WorldMapLayout.toWorld(zoneOf(spec.zone), cv.chamber.r, cv.chamber.lat)
			p = Vector3.new(cp.X, 0, cp.Z)
		end
		local toHub = toHubDir(p.X, p.Z)
		local look = rotY(toHub, spec.face)
		local baseY = baseYAt(spec, p.X, p.Z)
		if spec.templeBack and templeCf then
			local T = K.alcove
			local tw = 30
			local back = -templeCf.LookVector
			local q = templeCf.Position + back * (tw / 2 + T.d / 2 + T.wall + 0.2)
			p, look, baseY = Vector3.new(q.X, 0, q.Z), back, templeCf.Position.Y + 1.5 -- 신전 받침단 위(받침단이 방 바닥 안으로 들어오지 않게 - M1-3 Play 1)
		end
		if spec.cover == "underwater" then
			local zone = zoneOf(spec.zone)
			local R = TerrainGenData.zones[spec.zone].river
			local a, b = R.pts[spec.river], R.pts[spec.river + 1]
			local wa, wb = WorldMapLayout.toWorld(zone, a[1], a[2]), WorldMapLayout.toWorld(zone, b[1], b[2])
			local ab = Vector3.new(wb.X - wa.X, 0, wb.Z - wa.Z)
			local t = math.clamp((Vector3.new(p.X - wa.X, 0, p.Z - wa.Z)):Dot(ab) / ab:Dot(ab), 0, 1)
			local c = Vector3.new(wa.X, 0, wa.Z) + ab * t
			local level = FLOOR + a[3]
			local toRiver = Vector3.new(c.X - p.X, 0, c.Z - p.Z).Unit
			local bank = c - toRiver * (R.width / 2 + 2)
			ctx.river = { x = c.X, z = c.Z, bankX = bank.X, bankZ = bank.Z, level = level, bedY = level - R.depth + 1 }
			look, baseY = toRiver, level + 1.2
		end
		-- 흙더미에 묻는 숨은 방: 문 = 자연 지형이 가장 낮은 쪽(내리막 - 물리적으로 말이 되게 · 문 앞 통로가 언덕에 막히지 않게). 신전 뒤 · 물속 · 흙더미 없는 방은 그대로.
		if spec.kit == "alcove" and not spec.templeBack and spec.cover ~= "underwater" and not spec.noMound and spec.cover ~= "slab" and spec.cover ~= "oasis" and spec.cover ~= "trunk" then
			local TerrainShape = require(ReplicatedStorage.Shared.TerrainShape)
			local best, bestH = look, math.huge
			for k = 0, 15 do
				local a = k / 16 * 2 * math.pi
				local d = Vector3.new(math.cos(a), 0, math.sin(a))
				local q = p + d * 22
				local h = TerrainShape.baseHeight(q.X, q.Z) + 0.02 * (1 - d:Dot(look)) -- 같으면 원래 방향 쪽
				if h < bestH then
					best, bestH = d, h
				end
			end
			look = best
		end
		ctx.toHub = toHub
		ctx.cf = CFrame.lookAt(Vector3.new(p.X, baseY, p.Z), Vector3.new(p.X, baseY, p.Z) + look)
		ctx.baseY = baseY
		if spec.kit == "mesaEdge" or spec.kit == "mesaShrine" then
			ctx.mesa = mesaOf(spec.zone, spec.mesa)
			local c = Vector3.new(ctx.mesa.x, 0, ctx.mesa.z)
			ctx.toHub = toHubDir(c.X, c.Z)
			ctx.baseY = FLAT
		elseif spec.kit == "cave" then
			local zone = zoneOf(spec.zone)
			local cv = TerrainGenData.zones[spec.zone].caves[spec.cave]
			local cp = WorldMapLayout.toWorld(zone, cv.chamber.r, cv.chamber.lat)
			ctx.chamber = { x = cp.X, z = cp.Z, floor = FLAT + cv.pts[#cv.pts][3], radius = cv.chamber.radius, height = cv.chamber.height }
			ctx.caveRadius = cv.radius
			ctx.toHub = toHubDir(cp.X, cp.Z)
		elseif spec.kit == "tower" and spec.temple then
			ctx.model = "Landmark_" .. spec.zone .. "_temple"
		end
		meta = Kits[spec.kit](ctx, list)
		meta.cf = ctx.cf
		meta.baseY = meta.baseY or ctx.baseY
	end
	meta.id, meta.zone, meta.track, meta.sub, meta.top, meta.high, meta.kit, meta.cover = spec.id, spec.zone, spec.track, spec.sub, spec.top, spec.high, spec.kit, spec.cover
	meta.model = ctx.model
	meta.cf = meta.cf or ctx.cf
	Kits.nestMarker(ctx, list, meta.spot)
	return meta
end

-- ─────────────────────────── 구조물(둥지 아님) ───────────────────────────
local function buildColonnade(list, out)
	local C = WorldStructureData.colonnade
	local zone = zoneOf(C.zone)
	local p = WorldMapLayout.toWorld(zone, C.r, C.lat)
	local look = rotY(toHubDir(p.X, p.Z), C.face)
	local cf = CFrame.lookAt(Vector3.new(p.X, FLAT, p.Z), Vector3.new(p.X, FLAT, p.Z) + look)
	local m = "Struct_" .. C.zone .. "_ruins"
	local stone = Kits.look(C.zone, "pillar")
	prim(list, m, "RuinDais", Vector3.new(C.dais.w, C.dais.h + 2, C.dais.d), cf * CFrame.new(0, C.dais.h / 2 - 1, 0), stone.dark, { material = stone.material })
	local idx = 0
	for row = 1, C.rows do
		for c = 1, C.cols do
			idx += 1
			local x, z = (c - (C.cols + 1) / 2) * C.spacing, (row - 1.5) * C.rowGap
			local h = C.broken[idx] or C.h
			prim(list, m, "RuinPillar", Vector3.new(h, C.dia, C.dia), cf * CFrame.new(x, C.dais.h + h / 2, z) * CFrame.Angles(0, 0, math.rad(90)), stone.color, { shape = "Cylinder", material = stone.material })
			if not C.broken[idx] then
				prim(list, m, "RuinCapital", Vector3.new(C.dia + 1.6, 1, C.dia + 1.6), cf * CFrame.new(x, C.dais.h + h + 0.5, z), stone.color, { material = stone.material })
			end
		end
	end
	for row = 1, C.rows do -- 들보 조각(몇 칸만 남음)
		local z = (row - 1.5) * C.rowGap
		prim(list, m, "RuinBeam", Vector3.new(C.spacing * 2 + 3, 1.6, C.dia), cf * CFrame.new(-C.spacing * 1.5 + (row - 1) * C.spacing * 2, C.dais.h + C.h + 1.8, z), stone.color, { material = stone.material })
	end
	for i, k in ipairs(C.fallen) do
		local x = (k - (C.cols + 1) / 2) * C.spacing
		prim(list, m, "RuinFallen", Vector3.new(C.h - 2, C.dia, C.dia), cf * CFrame.new(x + 3, C.dais.h + C.dia / 2, C.rowGap * 0.9 + i * 3) * CFrame.Angles(0, math.rad(20 + i * 35), 0), stone.color, { shape = "Cylinder", material = stone.material })
	end
	table.insert(out.pads, { x = p.X, z = p.Z, radius = C.dais.w / 2 + 6, blend = 30, level = FLAT, mode = "set", tag = "ruins" })
	out.structures.colonnade = { center = p, cf = cf }
end

local function crystalCluster(list, model, cf, scale, look)
	local spec = { { 0, 0, 9, 0, 0 }, { 2.2, 0.8, 6, 18, 20 }, { -2, 1.2, 5, -22, 50 }, { 0.8, -2.2, 4.5, 15, -40 }, { -1.4, -1.8, 3.5, -12, 130 } }
	for _, s in ipairs(spec) do
		local h = s[3] * scale
		prim(list, model, "Crystal", Vector3.new(1.6 * scale, h, 1.6 * scale), cf * CFrame.new(s[1] * scale, 0, s[2] * scale) * CFrame.Angles(math.rad(s[4]), math.rad(s[5]), 0) * CFrame.new(0, h / 2 - 1, 0),
			look.color, { material = look.material, transparency = 0.25, collide = false })
	end
end
local function buildCrystals(list, out)
	local C = WorldStructureData.crystals
	local zone = zoneOf(C.zone)
	local look = Kits.look(C.zone, "crystal")
	local TerrainShape = require(ReplicatedStorage.Shared.TerrainShape)
	for i, c in ipairs(C.clusters) do
		local p = WorldMapLayout.toWorld(zone, c[1], c[2])
		local y = TerrainShape.baseHeight(p.X, p.Z)
		crystalCluster(list, "Struct_" .. C.zone .. "_crystals", CFrame.new(p.X, y, p.Z) * CFrame.Angles(0, i * 1.3, 0), c[3], look)
	end
end

local function buildCactus(list, out)
	local C = WorldStructureData.cactus
	local zone = zoneOf(C.zone)
	local TerrainShape = require(ReplicatedStorage.Shared.TerrainShape)
	local color = TerrainGenData.materialColors[C.material]
	out.cactus = {}
	for fi, f in ipairs(C.fields) do
		local c = WorldMapLayout.toWorld(zone, f.r, f.lat)
		local seed = f.seed
		local function rand()
			seed = (seed * 48271) % 2147483647
			return seed / 2147483647
		end
		local placed = 0
		for _ = 1, f.count * 20 do
			if placed >= f.count then
				break
			end
			local a, rr = rand() * 2 * math.pi, f.inner + math.sqrt(rand()) * (f.outer - f.inner)
			local x, z = c.X + math.cos(a) * rr, c.Z + math.sin(a) * rr
			local ok = true
			for _, q in ipairs(out.cactus) do
				if (q.x - x) ^ 2 + (q.z - z) ^ 2 < 7 * 7 then
					ok = false
					break
				end
			end
			if ok then
				placed += 1
				local h = C.height[1] + rand() * (C.height[2] - C.height[1])
				local y = TerrainShape.baseHeight(x, z)
				local cf = CFrame.new(x, y, z) * CFrame.Angles(0, rand() * 6.28, 0)
				local model = "Struct_" .. C.zone .. "_cactus" .. fi
				prim(list, model, "Cactus", Vector3.new(h + 1, C.trunk, C.trunk), cf * CFrame.new(0, h / 2 - 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)), color, { shape = "Cylinder", material = C.material, attrs = { Cactus = true } })
				for _, s in ipairs({ -1, 1 }) do
					local ah = h * (s > 0 and 0.45 or 0.6)
					prim(list, model, "CactusArm", Vector3.new(2.2, C.arm, C.arm), cf * CFrame.new(s * 1.6, ah, 0), color, { material = C.material, collide = false })
					prim(list, model, "CactusArm", Vector3.new(3, C.arm, C.arm), cf * CFrame.new(s * 2.4, ah + 1.6, 0) * CFrame.Angles(0, 0, math.rad(90)), color, { shape = "Cylinder", material = C.material, collide = false })
				end
				table.insert(out.cactus, { x = x, z = z, y = y, h = h, radius = C.trunk / 2 + 2.4, touch = C.trunk / 2 + 1, field = fi }) -- touch = 몸통 + 팔 뿌리(팔 끝은 충돌 없음)
			end
		end
	end
end

-- T3 계곡(물 사이) 기슭 계단: 계곡 구간 양옆 벽에 exitEvery마다 번갈아 - 물에서 벽 위까지(헤엄쳐 나올 자리)
local function buildGorgeExits(list, out)
	out.gorgeExits = {}
	for _, zone in ipairs(WorldMapData.zones) do
		local R = TerrainGenData.zones[zone.key] and TerrainGenData.zones[zone.key].river
		if R and R.gorge then
			local g, E = R.gorge, K.gorgeExit
			local look = Kits.look(zone.key)
			local a, b = R.pts[g.from], R.pts[g.to]
			local wa, wb = WorldMapLayout.toWorld(zone, a[1], a[2]), WorldMapLayout.toWorld(zone, b[1], b[2])
			local dir = Vector3.new(wb.X - wa.X, 0, wb.Z - wa.Z)
			local L = dir.Magnitude
			dir = dir.Unit
			local side = Vector3.new(-dir.Z, 0, dir.X)
			local waterY = FLOOR + a[3]
			local k = 0
			for s = -g.exitEvery * 1.5, L + g.exitEvery * 1.5, g.exitEvery do -- 벽이 양끝 너머까지 이어진다(솟은 벽 둘레) - 앞뒤로 한 칸 더
				k += 1
				local sx = (k % 2 == 1) and 1 or -1
				for j = 0, E.steps - 1 do
					local c = Vector3.new(wa.X, 0, wa.Z) + dir * (s + j * (E.size + 0.4)) + side * sx * (R.width / 2 - E.size / 2)
					local top = waterY + 1 + j * E.rise
					local bot = waterY - R.depth
					prim(list, "Struct_" .. zone.key .. "_gorge", "GorgeStep", Vector3.new(E.size, top - bot, E.size), CFrame.new(c.X, (top + bot) / 2, c.Z), look.color, { material = look.material })
				end
				table.insert(out.gorgeExits, { along = s, side = sx, pos = Vector3.new(wa.X, waterY, wa.Z) + dir * s + side * sx * (R.width / 2) })
			end
			out.gorge = { from = wa, to = wb, length = L, waterY = waterY, every = g.exitEvery }
		end
	end
end

-- ─────────────────────────── 전체 ───────────────────────────
local function buildAll()
	if built then
		return built
	end
	local list = {}
	local out = { nests = {}, byId = {}, pads = {}, paths = {}, protect = {}, structures = {} }
	-- 신전(폭풍)을 먼저: 번개 문 둥지가 신전 뒤에 붙는다
	local templeCf
	for _, spec in ipairs(NestData.nests) do
		if spec.temple == "thunder" then
			local meta = buildNest(spec, list)
			templeCf = meta.cf
			table.insert(out.nests, meta)
			out.byId[spec.id] = meta
		end
	end
	for _, spec in ipairs(NestData.nests) do
		if spec.temple ~= "thunder" then
			local meta = buildNest(spec, list, templeCf)
			table.insert(out.nests, meta)
			out.byId[spec.id] = meta
		end
	end
	-- 둥지 받침 · 흙더미 · 보호 부피 → 지형 마스크
	for _, meta in ipairs(out.nests) do
		for _, pd in ipairs(meta.pads or {}) do
			local c = meta.cf and (meta.cf * CFrame.new(pd.offset or Vector3.zero)).Position or meta.spot
			local base = meta.baseY or c.Y
			table.insert(out.pads, { x = c.X, z = c.Z, radius = pd.radius, blend = pd.blend, level = pd.raise and (base + pd.raise) or base, mode = pd.raise and "raise" or "set", tag = meta.id })
		end
		for _, v in ipairs(meta.protect or {}) do
			v.nest = meta.id
			table.insert(out.protect, v)
		end
	end
	buildColonnade(list, out)
	buildCrystals(list, out)
	buildCactus(list, out)
	buildGorgeExits(list, out)
	-- 받침은 "맞춤(set)" 먼저 · "솟게(raise)" 나중(흙더미가 받침에 지워지지 않게)
	table.sort(out.pads, function(a, b)
		if a.mode ~= b.mode then
			return a.mode == "set"
		end
		return a.tag < b.tag
	end)
	out.prims = list
	built = out
	return out
end

function WorldStructures.build(list)
	local out = buildAll()
	for _, p in ipairs(out.prims) do
		table.insert(list, p)
	end
	return out
end
function WorldStructures.nestList()
	return buildAll().nests
end
function WorldStructures.nest(id)
	return buildAll().byId[id]
end
function WorldStructures.data()
	return buildAll()
end
function WorldStructures.terrainMasks()
	local out = buildAll()
	return { pads = out.pads, paths = out.paths, protect = out.protect }
end
function WorldStructures.reset()
	built = nil
end

return WorldStructures
