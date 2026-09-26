-- M1-3 둥지 · 구조물 키트(순수 - 도형 명세만). 조립 · 지형 마스크 = shared/WorldStructures. 수치 = data/NestData.kit · WorldStructureData.
-- 키트 하나 = (ctx, spec) → meta { spot(둥지 자리 - 서는 면), leaps(오름 · 간격 - 검증이 이동표로 잰다), roof(위에서 착지 불가 판정), door, path(입구 → 둥지 캐릭터 통과 검사 점),
--   protect(보호 부피 - 지형이 못 들어온다), pads(받침 · 흙더미) }. 로컬 좌표: 원점 = 자리 바닥 · −Z = 앞(허브 쪽 기본 · face로 돌린다) · +X = 오른쪽.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NestData = require(ReplicatedStorage.Shared.data.NestData)
local PropKit = require(ReplicatedStorage.Shared.PropKit)
local TerrainGenData = require(ReplicatedStorage.Shared.data.TerrainGenData)
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)

local K = NestData.kit
local SINK = 2 -- 땅에 선 기둥은 이만큼 땅속으로(지형 복셀 높이 오차 · 틈 방지)
local Kits = {}

-- ─────────────────────────── 도우미 ───────────────────────────
local function prim(list, model, name, size, cf, color, opts)
	opts = opts or {}
	table.insert(list, {
		model = model, name = name, size = size, cf = cf, color = color, material = opts.material or "SmoothPlastic", shape = opts.shape or "Block",
		collide = opts.collide ~= false, transparency = opts.transparency, attrs = opts.attrs, neon = opts.neon, mesh = opts.mesh, query = opts.query,
	})
end
Kits.prim = prim
-- 땅(base cf)에 선 기둥: 윗면 = top
local function col(list, model, name, cf, w, d, top, look, opts)
	opts = opts or {}
	opts.material = opts.material or look.material
	prim(list, model, name, Vector3.new(w, top + SINK, d), cf * CFrame.new(0, (top - SINK) / 2, 0), opts.color or look.color, opts)
end
Kits.col = col
local function box(cf, half, water)
	return { kind = "box", cf = cf, half = half, water = water }
end
Kits.box = box

-- 구역 돌 재질(지형 절벽 재질 · 색과 같게 - 파트가 지형과 이어져 보인다)
function Kits.look(zoneKey, style)
	local G = TerrainGenData
	local mat
	if style == "pillar" then
		mat = "Limestone"
	elseif style == "sand" then
		mat = "Sandstone"
	elseif style == "ice" then
		mat = "Glacier"
	elseif style == "bark" then
		local b, bd = WorldMapData.hub.tree.bark, WorldMapData.hub.tree.barkDark
		return { material = "Wood", color = b, dark = bd }
	elseif style == "crystal" then
		local c = { 120, 230, 255 } -- 수정 여왕 관문 색(BossData)
		return { material = "Glass", color = c, dark = { 70, 140, 170 } }
	else
		local pal = G.palette[zoneKey] or G.palette.tier1
		mat = pal.cliff
	end
	local c = G.materialColors[mat] or { 128, 124, 118 }
	return { material = mat, color = c, dark = { math.floor(c[1] * 0.7), math.floor(c[2] * 0.7), math.floor(c[3] * 0.7) } }
end
local WOOD = { material = "Wood", color = WorldMapData.hub.tree.bark }
local LEAF = { material = "Grass", color = TerrainGenData.materialColors.LeafyGrass }
Kits.WOOD, Kits.LEAF = WOOD, LEAF

-- 둥지 표시(나뭇가지 고리 · 알 자리) - 알 겉모습은 클라가 사람마다(NestView). 앵커 = 서버 ProximityPrompt 자리(NestServer).
function Kits.nestMarker(ctx, list, spot)
	local M = K.marker
	prim(list, ctx.model, "NestRing", Vector3.new(M.ringH, M.ring, M.ring), CFrame.new(spot + Vector3.new(0, M.ringH / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		WOOD.color, { shape = "Cylinder", material = "Wood", collide = false })
	prim(list, ctx.model, "NestSpot", Vector3.new(2, 2, 2), CFrame.new(spot + Vector3.new(0, 1.4, 0)), { 255, 255, 255 },
		{ collide = false, transparency = 1, attrs = { NestId = ctx.spec.id, NestTrack = ctx.spec.track, NestSub = ctx.spec.sub, NestZone = ctx.spec.zone, NestTop = ctx.spec.top or nil, NestHigh = ctx.spec.high or nil } })
end

-- 오르기 발판 줄(원 둘레 나선): 중심 cf(바닥) · 반경 rc · 칸 크기 size · 높이 목록 heights · 시작 각(앞 = 0) → 발판 cf 목록
local function spiral(cf, rc, size, gap, heights, startA)
	local inc = (gap + size) / rc
	local out = {}
	for i, y in ipairs(heights) do
		local a = (startA or 0) + (i - 1) * inc
		table.insert(out, { cf = cf * CFrame.new(math.sin(a) * rc, 0, -math.cos(a) * rc), y = y })
	end
	return out
end

-- 높이 h 아래 rise 간격 발판 높이(마지막 도약 ≤ rise)
local function stepHeights(h, rise)
	local n = math.ceil(h / rise) - 1
	local list = {}
	for i = 1, n do
		table.insert(list, i * rise)
	end
	return list
end

local function leapsFor(heights, gap, top)
	local leaps = {}
	local prev = 0
	for i, y in ipairs(heights) do
		table.insert(leaps, { rise = y - prev, gap = i == 1 and 0 or gap })
		prev = y
	end
	table.insert(leaps, { rise = top - prev, gap = #heights > 0 and gap or 0 })
	return leaps
end

-- ─────────────────────────── A: 높은 바위 · 나무 · 대지 가장자리 · 선반 ───────────────────────────
function Kits.rock(ctx, list)
	local spec, cf = ctx.spec, ctx.cf
	local look = Kits.look(ctx.zone, spec.style)
	local sk = K.skill[spec.skill or "easy"]
	local R = K.rock
	local heights = stepHeights(spec.h, sk.rise)
	local rc = R.top / 2 + sk.gap + R.step / 2
	col(list, ctx.model, "NestRock", cf * CFrame.Angles(0, ctx.jitter * 0.6, 0), R.top, R.top, spec.h, look)
	local protect = { box(cf * CFrame.new(0, spec.h + 3.5, 0), Vector3.new(R.top / 2, 3, R.top / 2)) }
	for i, s in ipairs(spiral(cf, rc, R.step, sk.gap, heights, 0)) do
		col(list, ctx.model, "NestStep", s.cf * CFrame.Angles(0, ctx.jitter * i, 0), R.step, R.step, s.y, look)
		table.insert(protect, box(s.cf * CFrame.new(0, s.y + 4, 0), Vector3.new(R.step / 2, 3.5, R.step / 2)))
	end
	local spot = (cf * CFrame.new(0, spec.h, 0)).Position
	return { spot = spot, leaps = leapsFor(heights, sk.gap, spec.h), protect = protect, pads = { { radius = rc + R.step / 2 + 4, blend = 34 } }, open = true }
end

function Kits.tree(ctx, list)
	local spec, cf = ctx.spec, ctx.cf
	local T = K.tree
	local heights = stepHeights(spec.h, T.rise)
	local rc = T.trunk / 2 + T.gap + T.pad / 2
	prim(list, ctx.model, "NestTrunk", Vector3.new(spec.h + SINK + 1, T.trunk, T.trunk), cf * CFrame.new(0, (spec.h - SINK + 1) / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), WOOD.color,
		{ shape = "Cylinder", material = "Wood" })
	local protect = {}
	for i, s in ipairs(spiral(cf, rc, T.pad, T.gap, heights, 0)) do
		prim(list, ctx.model, "NestBranch", Vector3.new(1, T.pad, T.pad), s.cf * CFrame.new(0, s.y - 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)), WOOD.color, { shape = "Cylinder", material = "Wood" })
		-- 가지(줄기 → 발판 - 장식)
		local p = s.cf.Position
		local mid = Vector3.new((p.X + cf.Position.X) / 2, cf.Position.Y + s.y - 0.8, (p.Z + cf.Position.Z) / 2)
		prim(list, ctx.model, "NestLimb", Vector3.new(rc, 0.9, 0.9), CFrame.lookAt(mid, Vector3.new(p.X, mid.Y, p.Z)) * CFrame.Angles(0, math.rad(90), 0), WOOD.color, { material = "Wood", collide = false })
		table.insert(protect, box(s.cf * CFrame.new(0, s.y + 3.5, 0), Vector3.new(T.pad / 2, 3, T.pad / 2)))
	end
	prim(list, ctx.model, "NestCrown", Vector3.new(1.2, T.top, T.top), cf * CFrame.new(0, spec.h - 0.6, 0) * CFrame.Angles(0, 0, math.rad(90)), WOOD.color, { shape = "Cylinder", material = "Wood" })
	for k = 0, 2 do -- 잎(충돌 없음 - 둥지 위는 열려 있다: 옆으로 비껴 둔다)
		local a = k / 3 * 2 * math.pi + ctx.jitter
		PropKit.place(list, ctx.model, "Common_LeafClump", cf * CFrame.new(math.cos(a) * 9, spec.h + 1.5, math.sin(a) * 9)) -- M1-4 소품 라이브러리(14 × 9 틀)
	end
	table.insert(protect, box(cf * CFrame.new(0, spec.h + 3.5, 0), Vector3.new(T.top / 2, 3, T.top / 2)))
	return { spot = (cf * CFrame.new(0, spec.h, 0)).Position, leaps = leapsFor(heights, T.gap, spec.h), protect = protect, pads = { { radius = rc + T.pad / 2 + 4, blend = 34 } }, open = true }
end

-- 대지(지형 mesa) 가장자리: 절벽 밖 돌 발판(공중 점프 2) → 윗면 가장자리 둥지. ctx.mesa = { x, z, radius, level(월드 Y), blend }
local function mesaApproach(ctx, list, look)
	local m = ctx.mesa
	local toHub = ctx.toHub
	local side = Vector3.new(-toHub.Z, 0, toHub.X)
	local center = Vector3.new(m.x, 0, m.z)
	local topY = m.level
	local base = ctx.baseY
	local sk = K.skill.air2
	local heights = {}
	local y = topY - base - (sk.rise + 1)
	while y > 0.5 do
		table.insert(heights, 1, y)
		y -= sk.rise
	end
	local stepR = m.radius + m.blend * 0.5 + K.rock.step / 2
	local protect = {}
	local leaps = {}
	local prevY = 0
	for i, h in ipairs(heights) do
		local k = #heights - i -- 0 = 가장 높은(가장자리 바로 앞)
		local lateral = (k % 2 == 1) and (K.rock.step + sk.gap - 2) or 0
		local p = center + toHub * stepR + side * lateral
		local cf = CFrame.lookAt(Vector3.new(p.X, base, p.Z), Vector3.new(p.X, base, p.Z) - toHub)
		col(list, ctx.model, "NestStep", cf * CFrame.Angles(0, ctx.jitter * i, 0), K.rock.step, K.rock.step, h, look)
		table.insert(protect, box(cf * CFrame.new(0, h + 5, 0), Vector3.new(K.rock.step / 2 + 1, 5, K.rock.step / 2 + 1)))
		table.insert(leaps, { rise = h - prevY, gap = i == 1 and 0 or (K.rock.step + sk.gap - 2 - K.rock.step) })
		prevY = h
	end
	table.insert(leaps, { rise = topY - base - prevY, gap = stepR - K.rock.step / 2 - m.radius })
	return leaps, protect, center + toHub * (m.radius - 6) + Vector3.new(0, topY, 0)
end
function Kits.mesaEdge(ctx, list)
	local look = Kits.look(ctx.zone, "pillar")
	local leaps, protect, spot = mesaApproach(ctx, list, look)
	table.insert(protect, box(CFrame.new(spot + Vector3.new(0, 3.5, 0)), Vector3.new(4, 3, 4)))
	return { spot = spot, leaps = leaps, protect = protect, pads = {}, open = true }
end
function Kits.mesaShrine(ctx, list)
	local look = Kits.look(ctx.zone, "ice")
	local leaps, protect, edge = mesaApproach(ctx, list, look)
	local toHub = ctx.toHub
	local S = K.shrine
	local c = edge - toHub * (S.size / 2 - 1)
	local cf = CFrame.lookAt(c, c + toHub)
	local meta = Kits.shrineHouse(ctx, list, cf, look)
	for _, p in ipairs(protect) do
		table.insert(meta.protect, p)
	end
	meta.leaps = leaps
	return meta
end
function Kits.ledge(ctx, list)
	local spot = Vector3.new(ctx.cf.Position.X, TerrainGenData.flatLevel + WorldMapData.floorTopY + ctx.spec.level, ctx.cf.Position.Z)
	return { spot = spot, leaps = {}, walk = true, protect = { box(CFrame.new(spot + Vector3.new(0, 3.5, 0)), Vector3.new(4, 3, 4)) }, pads = {}, open = true }
end

-- ─────────────────────────── B: 탑(안쪽 점프맵) · 사당 코스 · 절벽 굴 ───────────────────────────
-- 사당(지붕 + 뒤 · 옆 벽 · 앞 열림): cf = 바닥 가운데(−Z = 열린 앞)
function Kits.shrineHouse(ctx, list, cf, look)
	local S = K.shrine
	local s, h = S.size, S.roofH
	for _, sx in ipairs({ -1, 1 }) do
		prim(list, ctx.model, "ShrineWall", Vector3.new(1.2, h, s), cf * CFrame.new(sx * (s / 2 - 0.6), h / 2, 0), look.color, { material = look.material })
	end
	prim(list, ctx.model, "ShrineWall", Vector3.new(s, h, 1.2), cf * CFrame.new(0, h / 2, s / 2 - 0.6), look.color, { material = look.material })
	prim(list, ctx.model, "ShrineRoof", Vector3.new(s + 3, 1.6, s + 3), cf * CFrame.new(0, h + 0.8, 0), look.dark, { material = look.material })
	prim(list, ctx.model, "ShrineRoofTop", Vector3.new(s * 0.6, 1.4, s * 0.6), cf * CFrame.new(0, h + 2.3, 0), look.dark, { material = look.material })
	local spot = (cf * CFrame.new(0, 0, s / 4)).Position
	return {
		spot = spot, protect = { box(cf * CFrame.new(0, h / 2, 0), Vector3.new(s / 2, h / 2, s / 2)) },
		roof = { y = (cf * CFrame.new(0, h, 0)).Position.Y, center = cf.Position, halfX = s / 2 + 1.5, halfZ = s / 2 + 1.5 },
		door = { pos = (cf * CFrame.new(0, 0, -s / 2)).Position, width = s - 2.4, dir = cf.LookVector },
		path = { (cf * CFrame.new(0, 0, -s / 2 - 3)).Position, (cf * CFrame.new(0, 0, -s / 2 + 1)).Position, spot },
		pads = {},
	}
end

function Kits.shrine(ctx, list)
	local S = K.shrine
	local look = Kits.look(ctx.zone)
	local cf = ctx.cf
	-- 받침(사당 바닥 = top · 옆은 오를 수 없는 벽 ≥ 23)
	col(list, ctx.model, "ShrineBase", cf, S.size, S.size, S.top, look)
	local house = Kits.shrineHouse(ctx, list, cf * CFrame.new(0, S.top, 0), look)
	-- 기둥 코스(앞쪽으로): 마지막 기둥 = 대시 간격 앞
	local z = -(S.size / 2 + S.dashGap + S.pillar / 2)
	local pillars = {}
	for i = #S.pillars, 1, -1 do
		table.insert(pillars, 1, { z = z, h = S.pillars[i].h })
		z -= S.pillar + S.pillars[i].gap
	end
	local leaps, prev = {}, 0
	for i, p in ipairs(pillars) do
		local x = (i % 2 == 0) and 1.5 or -1.5
		col(list, ctx.model, "ShrinePillar", cf * CFrame.new(x, 0, p.z) * CFrame.Angles(0, ctx.jitter * i, 0), S.pillar, S.pillar, p.h, look)
		table.insert(house.protect, box(cf * CFrame.new(x, p.h + 7, p.z), Vector3.new(S.pillar / 2 + 1, 7, S.pillar / 2 + 1)))
		table.insert(leaps, { rise = p.h - prev, gap = i == 1 and 0 or S.pillars[i].gap })
		prev = p.h
	end
	table.insert(leaps, { rise = S.top - prev, gap = S.dashGap })
	house.leaps = leaps
	house.pads = { { radius = (S.size + S.dashGap + 40) / 2 + 10, blend = 34, offset = Vector3.new(0, 0, -(S.dashGap + 30) / 2) } }
	return house
end

-- 탑(안쪽 점프맵 · 지붕 · 앞 문): w · h · cols(2 = 좌우 지그재그 · 3 = 좌 · 가운데 · 우)
function Kits.tower(ctx, list)
	local spec, cf = ctx.spec, ctx.cf
	local temple = spec.temple
	local T = K.tower
	local look = Kits.look(ctx.zone)
	local w, h, t = spec.w, spec.h, T.wall
	local half = w / 2 - t
	local rise = temple and K.templeTower.rise or T.rise
	local pad = temple and K.templeTower.pad or T.pad
	local door = T.door
	-- 벽 · 문 · 지붕
	col(list, ctx.model, "TowerWall", cf * CFrame.new(0, 0, w / 2 - t / 2), w, t, h, look)
	col(list, ctx.model, "TowerWall", cf * CFrame.new(-(w / 2 - t / 2), 0, 0), t, w - 2 * t, h, look)
	col(list, ctx.model, "TowerWall", cf * CFrame.new(w / 2 - t / 2, 0, 0), t, w - 2 * t, h, look)
	local side = (w - door.w) / 2
	col(list, ctx.model, "TowerWall", cf * CFrame.new(-(door.w / 2 + side / 2), 0, -(w / 2 - t / 2)), side, t, h, look)
	col(list, ctx.model, "TowerWall", cf * CFrame.new(door.w / 2 + side / 2, 0, -(w / 2 - t / 2)), side, t, h, look)
	prim(list, ctx.model, "TowerWall", Vector3.new(door.w, h - door.h, t), cf * CFrame.new(0, door.h + (h - door.h) / 2, -(w / 2 - t / 2)), look.color, { material = look.material })
	prim(list, ctx.model, "TowerRoof", Vector3.new(w + 2, 2, w + 2), cf * CFrame.new(0, h + 1, 0), look.dark, { material = look.material })
	-- 안쪽 발판(지그재그): 열 x · 같은 열 두 번째마다 z를 바꿔 머리 위를 비운다
	local xs = spec.cols == 3 and { -(half - pad / 2 - 0.5), 0, half - pad / 2 - 0.5, 0 } or { -(half - pad / 2 - 0.5), half - pad / 2 - 0.5 }
	local topFloor = h - T.headroom - 1
	local leaps, prevY = {}, 0
	local k, y = 0, 0
	local plats = {}
	while topFloor - y > rise do
		k += 1
		y = k * rise
		local x = xs[(k - 1) % #xs + 1]
		local z = (math.floor((k - 1) / #xs) % 2 == 0) and half * 0.3 or -half * 0.3
		table.insert(plats, { x = x, y = y, z = z })
	end
	for i, p in ipairs(plats) do
		prim(list, ctx.model, "TowerStep", Vector3.new(pad, 1, pad), cf * CFrame.new(p.x, p.y - 0.5, p.z), look.dark, { material = look.material })
		local gap
		if i == 1 then
			gap = 0
		else
			local q = plats[i - 1]
			local gx, gz = math.max(0, math.abs(p.x - q.x) - pad), math.max(0, math.abs(p.z - q.z) - pad)
			gap = math.sqrt(gx * gx + gz * gz)
		end
		table.insert(leaps, { rise = p.y - prevY, gap = gap })
		prevY = p.y
	end
	-- 꼭대기 바닥(마지막 발판 반대쪽 절반) · 둥지
	local last = plats[#plats]
	local sx = last.x <= 0 and 1 or -1
	local edgeX = last.x + sx * (pad / 2 + 1.5)
	local floorW = half - sx * edgeX
	local floorCx = edgeX + sx * floorW / 2
	prim(list, ctx.model, "TowerTop", Vector3.new(floorW, 1, 2 * half), cf * CFrame.new(floorCx, topFloor - 0.5, 0), look.dark, { material = look.material })
	table.insert(leaps, { rise = topFloor - last.y, gap = 1.5 })
	local spot = (cf * CFrame.new(floorCx + sx * (floorW / 2 - 4), topFloor, half * 0.4)).Position
	if temple == "thunder" then
		for _, sxx in ipairs({ -1, 1 }) do -- 피뢰 기둥(장식) + 받침 계단 모양 단
			prim(list, ctx.model, "TempleRod", Vector3.new(1, 18, 1), cf * CFrame.new(sxx * (w / 2 - 2), h + 11, 0), { 255, 240, 80 }, { neon = true, collide = false })
		end
		col(list, ctx.model, "TemplePlinth", cf * CFrame.new(0, 0, 0), w + 12, w + 12, 1.5, look)
	end
	return {
		spot = spot, leaps = leaps,
		roof = { y = (cf * CFrame.new(0, h, 0)).Position.Y, center = cf.Position, halfX = w / 2, halfZ = w / 2 },
		door = { pos = (cf * CFrame.new(0, 0, -w / 2)).Position, width = door.w, dir = cf.LookVector },
		path = { (cf * CFrame.new(0, 0, -w / 2 - 4)).Position, (cf * CFrame.new(0, 0, -w / 2 + 2)).Position },
		protect = { box(cf * CFrame.new(0, h / 2, 0), Vector3.new(half, h / 2, half)) },
		pads = { { radius = w / 2 + (temple and 12 or 8), blend = 34 } },
	}
end

-- 절벽 굴: 원점 = 굴 입구 바닥 가장자리(−Z = 허브 쪽) · 입구 높이 mouth · 앞으로 돌 발판(공중 점프 1) · 뒤 = 굴(보호 부피) · 흙더미가 지붕
function Kits.cliffCave(ctx, list)
	local spec, cf = ctx.spec, ctx.cf
	local C = K.cliffCave
	local look = Kits.look(ctx.zone)
	local my = spec.mouth
	local heights = {}
	local y = my
	while y > 0.5 do
		table.insert(heights, 1, y)
		y -= C.rise
	end
	local protect, leaps = {}, {}
	local zFront = -(C.ledge / 2 + 2)
	local prev = 0
	for i, h in ipairs(heights) do
		local k = #heights - i
		local z = zFront - k * (C.ledge + C.gap)
		col(list, ctx.model, "CaveLedge", cf * CFrame.new(0, 0, z) * CFrame.Angles(0, ctx.jitter * i, 0), C.ledge, C.ledge, h, look)
		table.insert(leaps, { rise = h - prev, gap = i == 1 and 0 or C.gap })
		prev = h
	end
	local nearZ = zFront - (#heights - 1) * (C.ledge + C.gap) - C.ledge
	-- 발판 앞 골(오르며 머리 위가 비게 - 폭 = 굴 폭)
	table.insert(protect, box(cf * CFrame.new(0, (my + C.height) / 2 + 0.5, (nearZ + 0) / 2), Vector3.new(C.width / 2, (my + C.height) / 2, -nearZ / 2)))
	-- 굴 · 방(바닥 판 = 입구 높이)
	local tunnelLen = C.depth
	table.insert(protect, box(cf * CFrame.new(0, my + C.height / 2, tunnelLen / 2), Vector3.new(C.width / 2, C.height / 2, tunnelLen / 2 + 1)))
	local chamberZ = tunnelLen + C.chamber / 2
	table.insert(protect, box(cf * CFrame.new(0, my + C.height / 2 + 1, chamberZ), Vector3.new(C.chamber / 2, C.height / 2 + 1, C.chamber / 2)))
	prim(list, ctx.model, "CaveFloor", Vector3.new(C.width, 1, tunnelLen + 2), cf * CFrame.new(0, my - 0.5, tunnelLen / 2 - 1), look.dark, { material = look.material })
	prim(list, ctx.model, "CaveFloor", Vector3.new(C.chamber, 1, C.chamber), cf * CFrame.new(0, my - 0.5, chamberZ), look.dark, { material = look.material })
	local spot = (cf * CFrame.new(0, my, chamberZ + C.chamber / 4)).Position
	local roofY = (cf * CFrame.new(0, my + C.height + 2, 0)).Position.Y
	return {
		spot = spot, leaps = leaps, terrainRoof = { y = roofY, need = my + C.height + 6 }, protect = protect,
		door = { pos = (cf * CFrame.new(0, my, 0)).Position, width = C.width, dir = cf.LookVector },
		path = { (cf * CFrame.new(0, my, -3)).Position, (cf * CFrame.new(0, my, tunnelLen / 2)).Position, (cf * CFrame.new(0, my, tunnelLen)).Position, spot },
		pads = {
			{ offset = Vector3.new(0, 0, nearZ / 2), radius = math.max(8, -nearZ / 2 + 4), blend = 12 },
			{ offset = Vector3.new(0, 0, chamberZ), radius = C.mound, blend = 24, raise = my + C.height + C.mound * 0.5 },
		},
	}
end

-- 구역 굴 안 수정 점프맵(T2 - 지형 굴 방): ctx.chamber = { x, z, floor, radius, height } · 기둥(유리 수정) → 선반
function Kits.cave(ctx, list)
	local ch = ctx.chamber
	local look = Kits.look(ctx.zone, "crystal")
	local CC = K.caveCourse
	local center = Vector3.new(ch.x, ch.floor, ch.z)
	local toHub = ctx.toHub
	local ang0 = math.atan2(toHub.Z, toHub.X)
	local ring = { { 18, 0 }, { 16, 40 }, { 13, 80 } }
	local leaps, prev, prevP = {}, 0, nil
	for i, p in ipairs(CC.pillars) do
		local a = ang0 + math.rad(ring[i][2])
		local pos = center + Vector3.new(math.cos(a), 0, math.sin(a)) * ring[i][1]
		prim(list, ctx.model, "CrystalPillar", Vector3.new(5, p.h + SINK, 5), CFrame.new(pos + Vector3.new(0, (p.h - SINK) / 2, 0)) * CFrame.Angles(0, a, 0), look.color,
			{ material = look.material, transparency = 0.15 })
		table.insert(leaps, { rise = p.h - prev, gap = prevP and math.max(0, (Vector3.new(pos.X - prevP.X, 0, pos.Z - prevP.Z)).Magnitude - 5) or 0 })
		prev, prevP = p.h, pos
	end
	local a = ang0 + math.rad(130)
	local lp = center + Vector3.new(math.cos(a), 0, math.sin(a)) * 6
	prim(list, ctx.model, "CrystalLedge", Vector3.new(8, 1.2, 8), CFrame.new(lp + Vector3.new(0, CC.ledge - 0.6, 0)), look.dark, { material = "Slate" })
	prim(list, ctx.model, "CrystalLedgeStem", Vector3.new(2.5, CC.ledge, 2.5), CFrame.new(lp + Vector3.new(0, CC.ledge / 2 - 1, 0)), look.color, { material = look.material, transparency = 0.2 })
	table.insert(leaps, { rise = CC.ledge - prev, gap = math.max(0, (Vector3.new(lp.X - prevP.X, 0, lp.Z - prevP.Z)).Magnitude - 2.5 - 4) })
	local spot = lp + Vector3.new(0, CC.ledge, 0)
	return {
		spot = spot, leaps = leaps, terrainRoof = { y = ch.floor + ch.height * 0.9, need = CC.ledge + 6 }, protect = {},
		door = { pos = center - toHub * ch.radius, width = 2 * ctx.caveRadius, dir = toHub }, path = { spot }, pads = {},
	}
end

-- ─────────────────────────── C: 숨은 방(덮개 변형) ───────────────────────────
-- 방: 안 w × d × h · 벽 두께 · 앞 문(door × doorH). 흙더미(raise)가 방을 덮고 보호 부피가 안과 문 앞을 비운다(끼임 0).
function Kits.alcove(ctx, list)
	local spec, cf = ctx.spec, ctx.cf
	local A = K.alcove
	local cover = spec.cover
	local look = Kits.look(ctx.zone, spec.style or ((cover == "ice") and "ice" or ((ctx.zone == "tier4") and "sand" or nil)))
	local w, d, h, t = A.w, A.d, A.h, A.wall
	local doorH = cover == "ice" and h or A.doorH
	local m = ctx.model
	local meta = { protect = {}, pads = {}, leaps = {} }
	if cover == "trunk" then
		-- 나무 줄기 속 구멍: 굵은 줄기 조각 고리(문 틈 하나) + 지붕 원판 + 잎
		local R, segs = 6.5, 10
		for i = 1, segs do
			local a = (i - 0.5) / segs * 2 * math.pi
			if math.abs(((a + math.pi) % (2 * math.pi)) - math.pi) > 0.42 then -- 앞(−Z) 한 칸 비움
				local p = cf * CFrame.new(math.sin(a) * R, 0, -math.cos(a) * R)
				prim(list, m, "HollowTrunk", Vector3.new(4.4, h + 16, 2.2), CFrame.lookAt(p.Position, cf.Position) * CFrame.new(0, (h + 16) / 2 - SINK, 0), WOOD.color, { material = "Wood" })
			end
		end
		prim(list, m, "HollowRoof", Vector3.new(2, 2 * R + 2, 2 * R + 2), cf * CFrame.new(0, h + 1, 0) * CFrame.Angles(0, 0, math.rad(90)), WOOD.color, { shape = "Cylinder", material = "Wood" })
		for k = 0, 3 do
			local a = k / 4 * 2 * math.pi + ctx.jitter
			PropKit.place(list, m, "Common_LeafClump", cf * CFrame.new(math.cos(a) * 8, h + 16, math.sin(a) * 8), Vector3.new(18 / 14, 12 / 9, 18 / 14)) -- M1-4 소품 라이브러리
		end
		for k = 1, 4 do -- 덩굴 커튼(통과)
			prim(list, m, "VineCurtain", Vector3.new(0.4, doorH + 3, 0.4), cf * CFrame.new(-2 + (k - 1) * 1.3, (doorH + 3) / 2, -R + 0.4), LEAF.color, { material = LEAF.material, collide = false })
		end
		meta.roof = { y = (cf * CFrame.new(0, h, 0)).Position.Y, center = cf.Position, halfX = R, halfZ = R }
		meta.door = { pos = (cf * CFrame.new(0, 0, -R)).Position, width = 4, dir = cf.LookVector }
		meta.path = { (cf * CFrame.new(0, 0, -R - 4)).Position, (cf * CFrame.new(0, 0, -R + 1)).Position, cf.Position }
		table.insert(meta.protect, box(cf * CFrame.new(0, h / 2, 0), Vector3.new(R - 1, h / 2, R - 1)))
		meta.pads = { { radius = R + 6, blend = 14 } }
		meta.spot = cf.Position
		return meta
	end
	-- 바닥 · 벽 · 지붕
	local wood = cover == "oasis"
	local mat = wood and WOOD or look
	prim(list, m, "AlcoveFloor", Vector3.new(w + 2 * t, 1, d + 2 * t), cf * CFrame.new(0, -0.5, 0), look.dark, { material = look.material })
	local wallH = cover == "oasis" and 3 or h
	if cover == "oasis" then -- 정자: 기둥 4 + 낮은 난간 3면 + 지붕
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				prim(list, m, "GazeboPost", Vector3.new(1, h, 1), cf * CFrame.new(sx * (w / 2 + t / 2), h / 2, sz * (d / 2 + t / 2)), WOOD.color, { material = "Wood" })
			end
		end
	end
	prim(list, m, "AlcoveWall", Vector3.new(w + 2 * t, wallH, t), cf * CFrame.new(0, wallH / 2, d / 2 + t / 2), mat.color, { material = mat.material })
	for _, sx in ipairs({ -1, 1 }) do
		prim(list, m, "AlcoveWall", Vector3.new(t, wallH, d), cf * CFrame.new(sx * (w / 2 + t / 2), wallH / 2, 0), mat.color, { material = mat.material })
	end
	local dw = cover == "slab" and w or A.door
	local sideW = (w + 2 * t - dw) / 2
	if sideW > 0.1 then
		for _, sx in ipairs({ -1, 1 }) do
			prim(list, m, "AlcoveWall", Vector3.new(sideW, wallH, t), cf * CFrame.new(sx * (dw / 2 + sideW / 2), wallH / 2, -(d / 2 + t / 2)), mat.color, { material = mat.material })
		end
	end
	if cover ~= "oasis" and h - doorH > 0.1 then
		prim(list, m, "AlcoveLintel", Vector3.new(dw, h - doorH, t), cf * CFrame.new(0, doorH + (h - doorH) / 2, -(d / 2 + t / 2)), mat.color, { material = mat.material })
	end
	if cover == "slab" then -- 쓰러진 큰 돌판이 지붕(기울어짐)
		prim(list, m, "FallenSlab", Vector3.new(w + 8, 2.4, d + 8), cf * CFrame.new(0, h + 1.4, 0) * CFrame.Angles(math.rad(6), 0, math.rad(-5)), look.color, { material = look.material })
	else
		prim(list, m, "AlcoveRoof", Vector3.new(w + 2 * t + (wood and 3 or 0), t, d + 2 * t + (wood and 3 or 0)), cf * CFrame.new(0, h + t / 2, 0), (wood and WOOD or look).dark or WOOD.color, { material = mat.material })
	end
	local doorZ = -(d / 2 + t)
	local doorCf = cf * CFrame.new(0, 0, doorZ)
	-- 덮개(통과 - 충돌 · 쿼리 없음)
	if cover == "fakeWall" then
		prim(list, m, "FakeWall", Vector3.new(dw + 2.5, doorH + 1.5, 1.4), doorCf * CFrame.new(0, (doorH + 1.5) / 2, -0.8), look.color, { material = look.material, collide = false })
	elseif cover == "vine" then
		for k = 1, 6 do
			prim(list, m, "VineCurtain", Vector3.new(0.35, doorH + 2, 0.35), doorCf * CFrame.new(-2.5 + (k - 1), (doorH + 2) / 2, -0.7), LEAF.color, { material = LEAF.material, collide = false })
		end
	elseif cover == "waterfall" then
		prim(list, m, "FallSheet", Vector3.new(dw + 6, 26, 0.6), doorCf * CFrame.new(0, 12, -2), { 120, 180, 230 }, { material = "Glass", transparency = 0.45, collide = false })
	elseif cover == "buried" then
		prim(list, m, "BuriedLintel", Vector3.new(dw + 5, 2, 3), doorCf * CFrame.new(0, doorH + 1, -0.6) * CFrame.Angles(0, 0, math.rad(4)), look.color, { material = look.material })
	elseif cover == "timed" then
		prim(list, m, "TimedDoor", Vector3.new(dw, doorH, 1), doorCf * CFrame.new(0, doorH / 2, 0), { 60, 58, 70 }, { material = look.material, attrs = { TimedDoor = spec.id } })
	end
	-- 흙더미(방을 덮는다 - 비밀 둥지 먼저 → 그 위에 지형) · 보호 부피(안 + 문 앞 통로)
	local noMound = spec.noMound or cover == "slab" or cover == "oasis" or cover == "timed"
	if not noMound then
		local lvl = (cover == "buried") and (h + t + 4) or (h + t + A.mound)
		-- 흙더미(방 뒤쪽) + 통로 입구 앞마당(바닥 높이 - 바깥 땅이 조금 높아 입구가 막히지 않게)
		meta.pads = { { radius = A.moundRadius, blend = A.moundBlend, raise = lvl, offset = Vector3.new(0, 0, A.moundBack) },
			{ radius = A.apron, blend = A.apronBlend, offset = Vector3.new(0, 0, -(d / 2 + t) - A.corridor - A.apron * 0.5) } }
	else
		meta.pads = { { radius = w / 2 + 8, blend = 14 } }
	end
	table.insert(meta.protect, box(cf * CFrame.new(0, h / 2, 0), Vector3.new(w / 2 + t, h / 2 + t / 2, d / 2 + t)))
	local corridor = noMound and 3 or A.corridor
	table.insert(meta.protect, box(cf * CFrame.new(0, doorH / 2 + 0.5, doorZ - corridor / 2), Vector3.new(dw / 2, doorH / 2 + 0.5, corridor / 2)))
	-- 물속 입구(T3): 방 바닥 = 강 수면 + 1 · 문 앞 굴이 강바닥까지 내려간다(물이 찬다)
	if cover == "underwater" and ctx.river then
		local rv = ctx.river
		local out = (cf * CFrame.new(0, 0, doorZ - 4)).Position
		table.insert(meta.protect, { kind = "tunnel", pts = { { out.X, out.Z, cf.Position.Y - 1 }, { rv.bankX, rv.bankZ, rv.bedY + 1 }, { rv.x, rv.z, rv.bedY } }, radius = 5, height = 8, water = rv.level })
		meta.path = { Vector3.new(rv.x, rv.bedY + 1, rv.z), Vector3.new(rv.bankX, rv.bedY + 2, rv.bankZ), out, cf.Position }
	else
		meta.path = { (doorCf * CFrame.new(0, 0, -(corridor + 3))).Position, (doorCf * CFrame.new(0, 0, -corridor / 2)).Position, doorCf.Position, cf.Position }
	end
	-- 환경 힌트(표시 없음 - 사람이 알아채는 것)
	for _, hint in ipairs(spec.hint or {}) do
		if hint == "stone" then
			prim(list, m, "OddStone", Vector3.new(3.2, 2.6, 2.4), doorCf * CFrame.new(dw / 2 + 3.5, 1.1, -2.5) * CFrame.Angles(math.rad(8), math.rad(23), math.rad(14)), look.color, { material = look.material })
		elseif hint == "moss" then
			prim(list, m, "MossLine", Vector3.new(0.5, 0.12, 9), doorCf * CFrame.new(-dw / 2 - 1, 0.15, -5) * CFrame.Angles(0, math.rad(12), 0), LEAF.color, { material = LEAF.material, collide = false })
		elseif hint == "fireflies" or hint == "birds" or hint == "flow" then
			prim(list, m, "NestHint", Vector3.new(1, 1, 1), doorCf * CFrame.new(0, doorH + 2, -4), { 0, 0, 0 }, { collide = false, transparency = 1, attrs = { NestHint = hint } })
			if hint == "birds" then -- 앉은 새(몸 · 머리 - 소리 에셋 없음)
				local perch = cf * CFrame.new(1.5, h + t + (noMound and 0.6 or A.mound + 0.6), 0)
				PropKit.place(list, m, "Common_Bird", perch * CFrame.new(0, -0.45, 0)) -- M1-4 소품 라이브러리
			end
		end
	end
	meta.roof = { y = (cf * CFrame.new(0, h, 0)).Position.Y, center = cf.Position, halfX = w / 2 + t, halfZ = d / 2 + t }
	meta.door = { pos = doorCf.Position, width = dw, dir = cf.LookVector }
	meta.spot = (cf * CFrame.new(0, 0, d / 4)).Position
	return meta
end

return Kits
