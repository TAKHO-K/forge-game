-- 지형 배치 모듈(22-5, PRD 20.49 [5] 3단계 + 20.50 개정 규칙). ZoneTerrainData의 요소 목록을 읽어
-- (1) 원시 도형(Block/Wedge/CornerWedge/Ball/Cylinder)으로 펼치고, (2) 각 요소가 만드는 "위험"
-- (급경사·절벽·심연·키 큰 충돌 장식·높이차 상한 초과)이 몬스터 도달원(슬롯 중심 반경 = 리쉬)과
-- 겹치는지 검사해 어기면 warn + 그 요소를 생략하고, (3) 통과한 것만 Part로 만든다. 지면(밟는 것)은
-- Workspace.Ground(GroundProbe.folder)에, 장식은 Workspace.ZoneDecor에 넣는다.
--
-- 구역 바닥도 여기서 만든다 - 웅덩이(pit)·구멍(hole)이 바닥에 진짜 구멍을 내야 해서(파트는 CSG 없이
-- 안 뚫린다) 바닥을 "구역 사각형 - 구멍들"의 조각 여러 개로 깐다(splitRects). 맵 밑판도 같은
-- 함수로 "맵 사각형 - 구역 9개"를 깔아 구역 바닥과 겹치지 않게 한다(웅덩이 밑에 밑판이 보이지 않게).
--
-- 규칙 상수는 TerrainConfig(경사 45°·단차 2·높이차 8)와 WorldConfig(리쉬·슬롯 격자)만 읽는다 -
-- 여기 숫자를 다시 적지 않는다.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local TerrainConfig = require(ReplicatedStorage.Shared.data.TerrainConfig)
local ZoneTerrainData = require(ReplicatedStorage.Shared.data.ZoneTerrainData)
local GroundProbe = require(script.Parent.GroundProbe)

local ZoneTerrain = {}
ZoneTerrain.TAG = "ZoneTerrain"

-- 로블록스 기본 도형의 방향(22-5 Studio 실측으로 확정):
--   WedgePart: 세로로 선 면(높은 쪽)이 local +Z(Back), 경사면이 -Z(Front)로 내려간다.
--   CornerWedgePart: 꼭짓점(높이 Y)이 local (+X, -Z) 모서리 위에 있고 나머지 세 모서리는 높이 0
--   (10×10×10 실측: (+4,-4)에서 9.0, 나머지 세 모서리 1.0).
local WEDGE_TALL_DIR = Vector2.new(0, 1)
local CORNER_WEDGE_APEX = Vector2.new(1, -1)

local decorFolder = nil
local function getDecorFolder()
	if decorFolder and decorFolder.Parent then
		return decorFolder
	end
	decorFolder = Workspace:FindFirstChild("ZoneDecor")
	if not decorFolder then
		decorFolder = Instance.new("Folder")
		decorFolder.Name = "ZoneDecor"
		decorFolder.Parent = Workspace
	end
	return decorFolder
end

-- ═══ 기하 도우미 ═══

-- CFrame.Angles(0, yaw, 0)는 local (x, z)를 (x·cos + z·sin, -x·sin + z·cos)로 보낸다.
local function rotateXZ(v, yaw)
	local c, s = math.cos(yaw), math.sin(yaw)
	return Vector2.new(v.X * c + v.Y * s, -v.X * s + v.Y * c)
end

-- 도형의 고유 방향(native)이 world 방향 want를 향하게 하는 yaw(90° 단위 네 후보 중 하나).
local function yawToAlign(native, want)
	for _, quarter in ipairs({ 0, 1, 2, 3 }) do
		local yaw = quarter * math.pi / 2
		local r = rotateXZ(native, yaw)
		if (r - want).Magnitude < 0.01 then
			return yaw
		end
	end
	error(("yawToAlign: (%s)→(%s) 불가"):format(tostring(native), tostring(want)))
end

-- 축 정렬 사각형 { minX, maxX, minZ, maxZ }(world).
local function rect(cx, cz, w, d)
	return { minX = cx - w / 2, maxX = cx + w / 2, minZ = cz - d / 2, maxZ = cz + d / 2 }
end

-- 회전한 사각형의 네 꼭짓점(world XZ, Vector2 목록).
local function rotatedCorners(cx, cz, w, d, yaw)
	local corners = {}
	for _, sign in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
		local local2 = Vector2.new(sign[1] * w / 2, sign[2] * d / 2)
		local r = rotateXZ(local2, yaw)
		table.insert(corners, Vector2.new(cx + r.X, cz + r.Y))
	end
	return corners
end

local function segmentDistance(p, a, b)
	local ab = b - a
	local len2 = ab:Dot(ab)
	if len2 < 1e-9 then
		return (p - a).Magnitude
	end
	local t = math.clamp((p - a):Dot(ab) / len2, 0, 1)
	return (p - (a + ab * t)).Magnitude
end

local function pointInPolygon(p, polygon)
	local inside = false
	local j = #polygon
	for i = 1, #polygon do
		local a, b = polygon[i], polygon[j]
		if (a.Y > p.Y) ~= (b.Y > p.Y) then
			local x = (b.X - a.X) * (p.Y - a.Y) / (b.Y - a.Y) + a.X
			if p.X < x then
				inside = not inside
			end
		end
		j = i
	end
	return inside
end

-- 다각형(또는 2점 선분)이 원과 겹치는가.
local function polygonHitsCircle(polygon, center, radius)
	if #polygon >= 3 and pointInPolygon(center, polygon) then
		return true
	end
	local n = #polygon
	for i = 1, n do
		local a = polygon[i]
		local b = polygon[i % n + 1]
		if n == 2 and i == 2 then
			break
		end
		if segmentDistance(center, a, b) <= radius then
			return true
		end
	end
	return false
end

local function polygonBounds(polygon)
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, p in ipairs(polygon) do
		minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
		minZ, maxZ = math.min(minZ, p.Y), math.max(maxZ, p.Y)
	end
	return minX, maxX, minZ, maxZ
end

-- 사각형 목록에서 hole을 잘라낸다(길로틴 분할 - 겹치는 사각형을 좌/우/상/하 최대 4조각으로).
function ZoneTerrain.splitRects(rects, hole)
	local out = {}
	for _, r in ipairs(rects) do
		if hole.minX >= r.maxX or hole.maxX <= r.minX or hole.minZ >= r.maxZ or hole.maxZ <= r.minZ then
			table.insert(out, r)
		else
			if hole.minX > r.minX then
				table.insert(out, { minX = r.minX, maxX = hole.minX, minZ = r.minZ, maxZ = r.maxZ })
			end
			if hole.maxX < r.maxX then
				table.insert(out, { minX = hole.maxX, maxX = r.maxX, minZ = r.minZ, maxZ = r.maxZ })
			end
			local midMin, midMax = math.max(hole.minX, r.minX), math.min(hole.maxX, r.maxX)
			if hole.minZ > r.minZ then
				table.insert(out, { minX = midMin, maxX = midMax, minZ = r.minZ, maxZ = hole.minZ })
			end
			if hole.maxZ < r.maxZ then
				table.insert(out, { minX = midMin, maxX = midMax, minZ = hole.maxZ, maxZ = r.maxZ })
			end
		end
	end
	return out
end

-- ═══ 재질 ═══

local function surfaceOf(name)
	local s = ZoneTerrainData.surfaces[name]
	if not s then
		error(("ZoneTerrain: 알 수 없는 surface '%s'"):format(tostring(name)))
	end
	return s
end

local function applySurface(part, s)
	part.Material = Enum.Material[s.material]
	part.Color = Color3.fromRGB(s.color[1], s.color[2], s.color[3])
	-- 22-6: 물(반투명)·슬라이드(저마찰)는 재질 표의 필드로만 표현한다 - 요소 데이터에는 색·마찰이 없다.
	if s.transparency then
		part.Transparency = s.transparency
	end
	if s.friction then
		part.CustomPhysicalProperties = PhysicalProperties.new(0.7, s.friction, 0, 100, 1)
	end
	-- 커스텀 텍스처(20.49 [4] 발주분)가 오면 surfaces 표의 textureId만 채운다 - 여기서 면마다 붙인다.
	if s.textureId then
		for _, faceName in ipairs(s.faces or { "Top" }) do
			local texture = Instance.new("Texture")
			texture.Texture = s.textureId
			texture.Face = Enum.NormalId[faceName]
			texture.StudsPerTileU = s.studsPerTile or 16
			texture.StudsPerTileV = s.studsPerTile or 16
			texture.Parent = part
		end
	end
end

-- ═══ 요소 → 원시 도형 + 위험 ═══
-- prim = { shape, cframe, size, surface, collide, ground, name, snap, sink }
-- hazard = { kind = "slope"|"cliff"|"obstacle"|"void"|"tall", polygon = {Vector2...} }

local function wedgeCFrame(center, tallDir)
	return CFrame.new(center) * CFrame.Angles(0, yawToAlign(WEDGE_TALL_DIR, tallDir), 0)
end

local SIDE_DIRS = { Vector2.new(1, 0), Vector2.new(-1, 0), Vector2.new(0, 1), Vector2.new(0, -1) }
local CORNER_SIGNS = { Vector2.new(1, 1), Vector2.new(1, -1), Vector2.new(-1, 1), Vector2.new(-1, -1) }

local function slopeDegrees(rise, run)
	if run <= 0 then
		return 90
	end
	return math.deg(math.atan(rise / run))
end

local expanders = {}

-- 언덕: 정상 박스 + 사면 쐐기 4(높은 면이 정상 쪽) + 모서리 코너쐐기 4(꼭짓점이 정상 모서리).
function expanders.hill(f, ctx, out)
	local w, d = f.top[1], f.top[2]
	local h, run = f.height, f.run
	local yaw = math.rad(f.rotation or 0)
	local base = CFrame.new(ctx.center.X + f.x, 0, ctx.center.Z + f.z) * CFrame.Angles(0, yaw, 0)
	local top = ctx.floorTopY
	local s = f.surface
	table.insert(out.prims, { shape = "Block", cframe = base * CFrame.new(0, top + h / 2, 0), size = Vector3.new(w, h, d), surface = s, ground = true })
	for _, dir in ipairs(SIDE_DIRS) do
		local along = dir.X ~= 0 and d or w
		local offset = Vector3.new(dir.X * (w / 2 + run / 2), top + h / 2, dir.Y * (d / 2 + run / 2))
		local localCF = CFrame.new(offset) * CFrame.Angles(0, yawToAlign(WEDGE_TALL_DIR, -dir), 0)
		table.insert(out.prims, { shape = "Wedge", cframe = base * localCF, size = Vector3.new(along, h, run), surface = s, ground = true })
	end
	for _, sign in ipairs(CORNER_SIGNS) do
		local offset = Vector3.new(sign.X * (w / 2 + run / 2), top + h / 2, sign.Y * (d / 2 + run / 2))
		local localCF = CFrame.new(offset) * CFrame.Angles(0, yawToAlign(CORNER_WEDGE_APEX, -sign), 0)
		table.insert(out.prims, { shape = "CornerWedge", cframe = base * localCF, size = Vector3.new(run, h, run), surface = s, ground = true })
	end
	local footprint = rotatedCorners(ctx.center.X + f.x, ctx.center.Z + f.z, w + 2 * run, d + 2 * run, yaw)
	out.footprint = footprint
	if slopeDegrees(h, run) > TerrainConfig.maxSlopeDegrees then
		table.insert(out.hazards, { kind = "slope", polygon = footprint })
	end
	if h > TerrainConfig.heightToleranceStuds then
		table.insert(out.hazards, { kind = "tall", polygon = footprint })
	end
end

-- 웅덩이: 바닥에 구멍(외곽 = 바닥 + 2·run) + 낮은 바닥 박스 + 테두리 쐐기 4(높은 면이 바깥). 쐐기는
-- 외곽 전체 길이라 모서리에서 둘이 겹치고, 겹친 곳의 윗면은 두 사면의 max = 오목한 골이 된다 -
-- 별도 모서리 조각 없이 경사가 45° 이하로 유지된다.
function expanders.pit(f, ctx, out)
	local bw, bd = f.bottom[1], f.bottom[2]
	local depth, run = f.depth, f.run
	local ow, od = bw + 2 * run, bd + 2 * run
	local cx, cz = ctx.center.X + f.x, ctx.center.Z + f.z
	local top = ctx.floorTopY
	table.insert(out.holes, rect(cx, cz, ow, od))
	table.insert(out.prims, {
		shape = "Block",
		cframe = CFrame.new(cx, top - depth - ctx.floorThickness / 2, cz),
		size = Vector3.new(bw, ctx.floorThickness, bd),
		surface = f.surface,
		ground = true,
	})
	for _, dir in ipairs(SIDE_DIRS) do
		local along = dir.X ~= 0 and od or ow
		local center = Vector3.new(cx + dir.X * (bw / 2 + run / 2), top - depth / 2, cz + dir.Y * (bd / 2 + run / 2))
		table.insert(out.prims, { shape = "Wedge", cframe = wedgeCFrame(center, dir), size = Vector3.new(along, depth, run), surface = f.rampSurface or f.surface, ground = true })
	end
	local footprint = rotatedCorners(cx, cz, ow, od, 0)
	out.footprint = footprint
	if slopeDegrees(depth, run) > TerrainConfig.maxSlopeDegrees then
		table.insert(out.hazards, { kind = "slope", polygon = footprint })
	end
	if depth > TerrainConfig.heightToleranceStuds then
		table.insert(out.hazards, { kind = "tall", polygon = footprint })
	end
end

local AXIS_DIR = { ["+x"] = Vector2.new(1, 0), ["-x"] = Vector2.new(-1, 0), ["+z"] = Vector2.new(0, 1), ["-z"] = Vector2.new(0, -1) }

-- 단(terrace): 평평한 단 박스 + 한쪽 면에서 내려오는 계단(단 높이를 단차 상한으로 나눈 수). 계단 아닌
-- 세 면과 계단의 양 옆은 절벽(높이 > 단차)이라 도달원 밖이어야 한다.
function expanders.terrace(f, ctx, out)
	local cx, cz = ctx.center.X + f.x, ctx.center.Z + f.z
	local top = ctx.floorTopY
	local h = f.height
	local dir = AXIS_DIR[f.stairsSide]
	if not dir then
		error(("terrace stairsSide '%s'"):format(tostring(f.stairsSide)))
	end
	table.insert(out.prims, { shape = "Block", cframe = CFrame.new(cx, top + h / 2, cz), size = Vector3.new(f.w, h, f.d), surface = f.surface, ground = true })
	-- 1e-6: maxStepHeight = 2·tan(45°)는 부동소수로 1.9999999…라 4/2가 2.0000…4 → ceil 3이 된다(실측).
	local steps = math.max(1, math.ceil(h / TerrainConfig.maxStepHeightStuds - 1e-6))
	local rise = h / steps
	local stepDepth = f.stepDepth or 3
	local halfAlong = (dir.X ~= 0 and f.w or f.d) / 2 -- 계단이 붙는 면까지의 거리(중심에서)
	local width = f.stairsWidth or (dir.X ~= 0 and f.d or f.w)
	for i = 1, steps - 1 do
		local stepTop = rise * i
		local distance = halfAlong + stepDepth * (steps - i) - stepDepth / 2
		local center = Vector3.new(cx + dir.X * distance, top + stepTop / 2, cz + dir.Y * distance)
		local size = dir.X ~= 0 and Vector3.new(stepDepth, stepTop, width) or Vector3.new(width, stepTop, stepDepth)
		table.insert(out.prims, { shape = "Block", cframe = CFrame.new(center), size = size, surface = f.stairSurface or f.surface, ground = true })
	end
	local stairRun = stepDepth * (steps - 1)
	local corners = rotatedCorners(cx, cz, f.w, f.d, 0)
	local totalW = f.w + (dir.X ~= 0 and stairRun or 0)
	local totalD = f.d + (dir.Y ~= 0 and stairRun or 0)
	out.footprint = rotatedCorners(cx + dir.X * stairRun / 2, cz + dir.Y * stairRun / 2, totalW, totalD, 0)
	if h > TerrainConfig.maxStepHeightStuds then
		-- 단의 네 변 중 계단이 없는 세 변 = 절벽 선분.
		local edges = {
			{ corners[1], corners[2], Vector2.new(0, -1) }, -- -Z 변
			{ corners[2], corners[3], Vector2.new(1, 0) }, -- +X 변
			{ corners[3], corners[4], Vector2.new(0, 1) }, -- +Z 변
			{ corners[4], corners[1], Vector2.new(-1, 0) }, -- -X 변
		}
		for _, e in ipairs(edges) do
			if (e[3] - dir).Magnitude > 0.01 then
				table.insert(out.hazards, { kind = "cliff", polygon = { e[1], e[2] } })
			end
		end
		-- 계단 양 옆(단 모서리에서 계단 끝까지) - 두 번째 단부터 높이가 단차를 넘는다.
		local side = Vector2.new(-dir.Y, dir.X)
		for _, s in ipairs({ 1, -1 }) do
			local a = Vector2.new(cx, cz) + dir * halfAlong + side * (s * width / 2)
			local b = a + dir * stairRun
			table.insert(out.hazards, { kind = "cliff", polygon = { a, b } })
		end
	end
	if h > TerrainConfig.heightToleranceStuds then
		table.insert(out.hazards, { kind = "tall", polygon = out.footprint })
	end
end

-- 오두막(못 들어간다 - 3인칭 카메라가 천장에 막히고(20.49의 동굴 거부와 같은 이유), 띠는 이미
-- 어그로가 안 붙는 곳이라 실내 안전지대가 아무것도 더해 주지 않는다): 벽 4 + 지붕 쐐기 2 + 문 +
-- 창 2 + 굴뚝 = 10파트. 발자국 전체가 충돌 장애물.
function expanders.hut(f, ctx, out)
	local w, d = f.w, f.d
	local wh, rh = f.wallHeight, f.roofHeight
	local yaw = math.rad(f.rotation or 0)
	local base = CFrame.new(ctx.center.X + f.x, 0, ctx.center.Z + f.z) * CFrame.Angles(0, yaw, 0)
	local top = ctx.floorTopY
	local t = 1
	local function wall(offset, size)
		table.insert(out.prims, { shape = "Block", cframe = base * CFrame.new(offset), size = size, surface = f.wallSurface, collide = true })
	end
	wall(Vector3.new(0, top + wh / 2, -d / 2 + t / 2), Vector3.new(w, wh, t))
	wall(Vector3.new(0, top + wh / 2, d / 2 - t / 2), Vector3.new(w, wh, t))
	wall(Vector3.new(-w / 2 + t / 2, top + wh / 2, 0), Vector3.new(t, wh, d - 2 * t))
	wall(Vector3.new(w / 2 - t / 2, top + wh / 2, 0), Vector3.new(t, wh, d - 2 * t))
	-- 지붕: 용마루가 X축을 따라 중앙(z=0), 양쪽으로 내려간다. 높은 면이 중앙을 향한다.
	local overhang = 1
	for _, s in ipairs({ 1, -1 }) do
		local half = d / 2 + overhang
		local offset = Vector3.new(0, top + wh + rh / 2, s * half / 2)
		local localCF = CFrame.new(offset) * CFrame.Angles(0, yawToAlign(WEDGE_TALL_DIR, Vector2.new(0, -s)), 0)
		table.insert(out.prims, { shape = "Wedge", cframe = base * localCF, size = Vector3.new(w + 2 * overhang, rh, half), surface = f.roofSurface, collide = true })
	end
	-- 문(앞면 -Z) · 창 2(양 옆) · 굴뚝
	table.insert(out.prims, { shape = "Block", cframe = base * CFrame.new(0, top + 2.25, -d / 2 - 0.15), size = Vector3.new(3, 4.5, 0.3), surface = f.trimSurface, collide = false })
	for _, s in ipairs({ 1, -1 }) do
		table.insert(out.prims, { shape = "Block", cframe = base * CFrame.new(s * (w / 2 + 0.15), top + wh * 0.6, 0), size = Vector3.new(0.3, 1.6, 1.6), surface = f.trimSurface, collide = false })
	end
	table.insert(out.prims, { shape = "Block", cframe = base * CFrame.new(w / 4, top + wh + rh * 0.5 + 1, d / 6), size = Vector3.new(1.5, rh + 1, 1.5), surface = f.trimSurface, collide = true })
	out.footprint = rotatedCorners(ctx.center.X + f.x, ctx.center.Z + f.z, w + 2 * overhang, d + 2 * overhang, yaw)
	table.insert(out.hazards, { kind = "obstacle", polygon = out.footprint })
end

-- 나무: 줄기(충돌) + 수관(비충돌 - 카메라·이동을 막지 않는다).
--   canopyStyle "ball"(기본, 22-5): 구 1개 - 파트 2, 삼각형 96+432=528(22-7 실측: 구는 크기 무관 432).
--   canopyStyle "cube"(22-6 숲용): 상자 2개를 45° 엇갈려 쌓는다(탑다운에서 8각 별로 읽힌다) - 삼각형 24.
--   trunkShape "box"(22-6): 줄기도 상자(12) - 숲 40그루면 원기둥(96)과 3,400 삼각형 차이.
--   → "cube"+"box" 나무 = 파트 3, 삼각형 36. 구 수관 나무의 1/15. 파트 예산엔 +1, 삼각형 예산엔 −492.
function expanders.tree(f, ctx, out)
	local cx, cz = ctx.center.X + f.x, ctx.center.Z + f.z
	local top = ctx.floorTopY + (f.y or 0)
	local th, td = f.trunkHeight, f.trunkDiameter
	if f.trunkShape == "box" then
		table.insert(out.prims, { shape = "Block", cframe = CFrame.new(cx, top + th / 2, cz), size = Vector3.new(td, th, td), surface = f.trunkSurface, collide = true })
	else
		table.insert(out.prims, {
			shape = "Cylinder",
			cframe = CFrame.new(cx, top + th / 2, cz) * CFrame.Angles(0, 0, math.pi / 2),
			size = Vector3.new(th, td, td),
			surface = f.trunkSurface,
			collide = true,
		})
	end
	local cd = f.canopyDiameter
	if f.canopyStyle == "cube" then
		local yaw = math.rad(f.rotation or 0)
		local lowerH, upperH = cd * 0.55, cd * 0.5
		local lowerY = top + th - cd * 0.15 -- 줄기 끝을 조금 덮는다
		table.insert(out.prims, { shape = "Block", cframe = CFrame.new(cx, lowerY + lowerH / 2, cz) * CFrame.Angles(0, yaw, 0), size = Vector3.new(cd, lowerH, cd), surface = f.canopySurface, collide = false })
		table.insert(out.prims, { shape = "Block", cframe = CFrame.new(cx, lowerY + lowerH + upperH / 2 - cd * 0.08, cz) * CFrame.Angles(0, yaw + math.pi / 4, 0), size = Vector3.new(cd * 0.72, upperH, cd * 0.72), surface = f.canopySurface, collide = false })
	else
		table.insert(out.prims, { shape = "Ball", cframe = CFrame.new(cx, top + th + cd * 0.3, cz), size = Vector3.new(cd, cd, cd), surface = f.canopySurface, collide = false })
	end
	out.footprint = rotatedCorners(cx, cz, td, td, 0)
	table.insert(out.hazards, { kind = "obstacle", polygon = out.footprint })
end

-- 띠(strip, 22-6): 꺾은선 points를 따라 폭 width·두께 thickness의 상자를 잇는다 - 개울·흙길·낮은 성벽.
-- 기본은 비충돌·비지면(시각 전용, y 위로 살짝 띄운 판). collide=true면 장애물(두께 > 단차면 obstacle
-- 위험), ground=true면 밟는 지면(두께 ≤ 단차여야 도달원 안에 둘 수 있다). 각 마디는 폭만큼 길게 만들어
-- 꺾이는 곳이 벌어지지 않게 한다.
function expanders.strip(f, ctx, out)
	local top = ctx.floorTopY + (f.y or 0)
	local t = f.thickness or 0.2
	local w = f.width
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for i = 1, #f.points - 1 do
		local a, b = f.points[i], f.points[i + 1]
		local ax, az = ctx.center.X + a[1], ctx.center.Z + a[2]
		local bx, bz = ctx.center.X + b[1], ctx.center.Z + b[2]
		local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
		local mid = Vector3.new((ax + bx) / 2, top + t / 2, (az + bz) / 2)
		local cframe = CFrame.lookAt(mid, Vector3.new(bx, top + t / 2, bz))
		table.insert(out.prims, { shape = "Block", cframe = cframe, size = Vector3.new(w, t, len + w), surface = f.surface, collide = f.collide == true, ground = f.ground == true })
		-- 마디가 끝점 너머로 폭/2만큼 길므로 발자국도 그만큼 넓힌다(끝점이 구역 경계에서 폭/2 안쪽이어야 통과).
		minX, maxX = math.min(minX, ax - w / 2, bx - w / 2), math.max(maxX, ax + w / 2, bx + w / 2)
		minZ, maxZ = math.min(minZ, az - w / 2, bz - w / 2), math.max(maxZ, az + w / 2, bz + w / 2)
	end
	out.footprint = { Vector2.new(minX, minZ), Vector2.new(maxX, minZ), Vector2.new(maxX, maxZ), Vector2.new(minX, maxZ) }
	local topAboveFloor = (f.y or 0) + t
	if f.ground and topAboveFloor > TerrainConfig.maxStepHeightStuds then
		table.insert(out.hazards, { kind = "cliff", polygon = out.footprint })
	elseif f.collide and topAboveFloor > TerrainConfig.maxStepHeightStuds then
		table.insert(out.hazards, { kind = "obstacle", polygon = out.footprint })
	end
end

-- 원시 도형 공통: box / ball / cylinder / wedge.
local function expandPrimitive(f, ctx, out)
	local cx, cz = ctx.center.X + f.x, ctx.center.Z + f.z
	local top = ctx.floorTopY + (f.y or 0)
	local yaw = math.rad(type(f.rotation) == "number" and f.rotation or 0)
	local collide = f.collide ~= false
	local size, cframe, footprintW, footprintD, height
	if f.kind == "ball" then
		local dia = type(f.size) == "table" and f.size[1] or f.size
		size = Vector3.new(dia, dia, dia)
		cframe = CFrame.new(cx, top + dia / 2 - (f.sink or 0), cz) * CFrame.Angles(0, yaw, 0)
		footprintW, footprintD, height = dia, dia, dia - (f.sink or 0)
	elseif f.kind == "cylinder" then
		size = Vector3.new(f.height, f.diameter, f.diameter)
		cframe = CFrame.new(cx, top + f.height / 2 - (f.sink or 0), cz) * CFrame.Angles(0, yaw, math.pi / 2)
		footprintW, footprintD, height = f.diameter, f.diameter, f.height - (f.sink or 0)
	else
		size = Vector3.new(f.size[1], f.size[2], f.size[3])
		cframe = CFrame.new(cx, top + size.Y / 2 - (f.sink or 0), cz) * CFrame.Angles(0, yaw, 0)
		if f.kind == "wedge" then
			local tallDir = AXIS_DIR[f.tallDir or "+z"]
			cframe = CFrame.new(cx, top + size.Y / 2 - (f.sink or 0), cz) * CFrame.Angles(0, yawToAlign(WEDGE_TALL_DIR, tallDir), 0)
		end
		footprintW, footprintD, height = size.X, size.Z, size.Y - (f.sink or 0)
	end
	local shape = f.kind == "wedge" and "Wedge" or f.kind == "ball" and "Ball" or f.kind == "cylinder" and "Cylinder" or "Block"
	table.insert(out.prims, { shape = shape, cframe = cframe, size = size, surface = f.surface, collide = collide, ground = f.ground == true, snap = f.snap, sink = f.sink })
	out.footprint = rotatedCorners(cx, cz, footprintW, footprintD, yaw)
	local topAboveFloor = (f.y or 0) + height
	if f.kind == "wedge" then
		if slopeDegrees(size.Y, size.Z) > TerrainConfig.maxSlopeDegrees then
			table.insert(out.hazards, { kind = "slope", polygon = out.footprint })
		end
		if size.Y > TerrainConfig.maxStepHeightStuds then
			table.insert(out.hazards, { kind = "cliff", polygon = out.footprint }) -- 양 옆·높은 면은 수직
		end
	elseif f.ground then
		if topAboveFloor > TerrainConfig.maxStepHeightStuds then
			table.insert(out.hazards, { kind = "cliff", polygon = out.footprint })
		end
	elseif collide and topAboveFloor > TerrainConfig.maxStepHeightStuds then
		table.insert(out.hazards, { kind = "obstacle", polygon = out.footprint })
	end
	if topAboveFloor > TerrainConfig.heightToleranceStuds and (f.ground or collide) then
		table.insert(out.hazards, { kind = "tall", polygon = out.footprint })
	end
end
expanders.box, expanders.ball, expanders.cylinder, expanders.wedge = expandPrimitive, expandPrimitive, expandPrimitive, expandPrimitive

-- 구멍: 바닥만 뚫는다(드래곤 돌길·검사 도구용). 도달원 안이면 항상 위반.
function expanders.hole(f, ctx, out)
	local r = rect(ctx.center.X + f.x, ctx.center.Z + f.z, f.w, f.d)
	table.insert(out.holes, r)
	out.footprint = { Vector2.new(r.minX, r.minZ), Vector2.new(r.maxX, r.minZ), Vector2.new(r.maxX, r.maxZ), Vector2.new(r.minX, r.maxZ) }
	table.insert(out.hazards, { kind = "void", polygon = out.footprint })
end

-- ═══ 검사 ═══

local function reachCircles(zone)
	local circles = {}
	if zone.role == "tier" then
		for _, offset in ipairs(WorldConfig.zoneMonsterGrid.offsets) do
			table.insert(circles, { center = Vector2.new(zone.center.X + offset.X, zone.center.Z + offset.Z), radius = WorldConfig.aggro.leashRangeStuds })
		end
	end
	return circles
end

local HAZARD_LABEL = {
	slope = "경사 45° 초과",
	cliff = "단차 2 초과(절벽)",
	obstacle = "키 큰 충돌 장식",
	void = "심연(바닥 없음)",
	tall = "높이차 상한 8 초과",
}

-- 펼친 요소 하나의 위반 사유(없으면 nil).
local function violationOf(expanded, zone, circles)
	local minX, maxX, minZ, maxZ = polygonBounds(expanded.footprint)
	local half = zone.halfSize
	if minX < zone.center.X - half or maxX > zone.center.X + half or minZ < zone.center.Z - half or maxZ > zone.center.Z + half then
		return "구역 밖으로 나간다"
	end
	for _, hazard in ipairs(expanded.hazards) do
		for i, circle in ipairs(circles) do
			if polygonHitsCircle(hazard.polygon, circle.center, circle.radius) then
				return ("%s가 슬롯 %d 도달원(반경 %.1f) 안"):format(HAZARD_LABEL[hazard.kind] or hazard.kind, i, circle.radius)
			end
		end
	end
	return nil
end

local function describe(f)
	if f.points then
		return ("%s@(%s,%s)…"):format(f.kind, tostring(f.points[1][1]), tostring(f.points[1][2]))
	end
	return ("%s@(%s,%s)"):format(f.kind, tostring(f.x), tostring(f.z))
end

-- 흩뿌리기: 결정론적(seed) 무작위 위치 count개. 제외 사각형·구역 밖은 다시 뽑는다(최대 20회).
local function expandScatter(f, ctx)
	local rng = Random.new(f.seed or 1)
	local generated = {}
	local region = f.region
	local half = ctx.zone.halfSize
	for _ = 1, f.count do
		for _ = 1, 20 do
			local x = region.x + rng:NextNumber(-region.w / 2, region.w / 2)
			local z = region.z + rng:NextNumber(-region.d / 2, region.d / 2)
			local ok = math.abs(x) <= half - 2 and math.abs(z) <= half - 2
			if ok and f.exclude then
				for _, ex in ipairs(f.exclude) do
					if math.abs(x - ex.x) <= ex.w / 2 and math.abs(z - ex.z) <= ex.d / 2 then
						ok = false
						break
					end
				end
			end
			if ok then
				local item = table.clone(f.template)
				item.x, item.z = x, z
				if type(item.size) == "table" and #item.size == 2 and item.kind == "ball" then
					item.size = rng:NextNumber(item.size[1], item.size[2])
				end
				if item.rotation == "random" then
					item.rotation = rng:NextNumber(0, 360)
				end
				if item.snap == nil then
					item.snap = true
				end
				table.insert(generated, item)
				break
			end
		end
	end
	return generated
end

-- 요소 목록을 펼치고 검사한다(인스턴스 생성 없음). 반환: { accepted = {expanded...}, holes, violations = {문자열} }
function ZoneTerrain.plan(zone, features, floorTopY, floorThickness)
	local ctx = { zone = zone, center = zone.center, floorTopY = floorTopY, floorThickness = floorThickness }
	local circles = reachCircles(zone)
	local result = { accepted = {}, holes = {}, violations = {}, featureCount = 0 }
	local queue = {}
	for _, f in ipairs(features or {}) do
		if f.kind == "scatter" then
			for _, item in ipairs(expandScatter(f, ctx)) do
				table.insert(queue, item)
			end
		else
			table.insert(queue, f)
		end
	end
	for _, f in ipairs(queue) do
		result.featureCount += 1
		local expander = expanders[f.kind]
		if not expander then
			table.insert(result.violations, ("%s: 알 수 없는 kind"):format(describe(f)))
			continue
		end
		local out = { prims = {}, hazards = {}, holes = {}, footprint = nil }
		expander(f, ctx, out)
		local reason = violationOf(out, zone, circles)
		if reason then
			table.insert(result.violations, ("%s: %s"):format(describe(f), reason))
		else
			table.insert(result.accepted, out)
			for _, h in ipairs(out.holes) do
				table.insert(result.holes, h)
			end
		end
	end
	return result
end

-- ═══ 생성 ═══

local function instantiate(prim, zoneKey, name)
	local part
	if prim.shape == "Wedge" then
		part = Instance.new("WedgePart")
	elseif prim.shape == "CornerWedge" then
		part = Instance.new("CornerWedgePart")
	else
		part = Instance.new("Part")
		part.Shape = Enum.PartType[prim.shape]
	end
	part.Name = name
	part.Size = prim.size
	part.CFrame = prim.cframe
	part.Anchored = true
	part.CanCollide = prim.collide ~= false
	part.CastShadow = prim.ground ~= true -- 지면은 그림자를 안 드리운다(드로우 비용, 시각 차이 없음)
	applySurface(part, surfaceOf(prim.surface))
	part:SetAttribute("ZoneKey", zoneKey)
	CollectionService:AddTag(part, ZoneTerrain.TAG)
	part.Parent = prim.ground and GroundProbe.folder() or getDecorFolder()
	return part
end

-- 지면에 스냅(장식 전용 - 언덕 위 잔돌이 뜨거나 묻히지 않게). 지면 파트가 먼저 만들어진 뒤 부른다.
local function snapToGround(part, prim)
	local p = part.Position
	local groundY = GroundProbe.surfaceY(p.X, p.Z, p.Y + 20)
	if groundY then
		local bottomOffset = part.Size.Y / 2
		if prim.shape == "Cylinder" then
			bottomOffset = part.Size.X / 2 -- 세워 둔 원기둥은 길이가 X
		end
		local currentBottom = p.Y - bottomOffset
		local delta = groundY - (prim.sink or 0) - currentBottom
		part.CFrame = part.CFrame + Vector3.new(0, delta, 0)
	end
end

-- 구역 하나: 바닥(구멍 제외 조각들) + 요소 전부. opts = { floorSurface = 이름 또는 {material,color},
-- floorTopY, floorThickness }. 반환 { parts, groundParts, decorParts, violations }.
function ZoneTerrain.build(zone, opts)
	local data = ZoneTerrainData.zones[zone.key]
	local features = data and data.features or {}
	local planResult = ZoneTerrain.plan(zone, features, opts.floorTopY, opts.floorThickness)
	for _, v in ipairs(planResult.violations) do
		warn(("[ZoneTerrain] %s: 배치 거부 - %s"):format(zone.key, v))
	end

	-- 바닥: 구역 사각형에서 구멍들을 뺀 조각들.
	local half = zone.halfSize
	local pieces = { rect(zone.center.X, zone.center.Z, half * 2, half * 2) }
	for _, hole in ipairs(planResult.holes) do
		pieces = ZoneTerrain.splitRects(pieces, hole)
	end
	local floorSurface = opts.floorSurface
	if type(floorSurface) == "string" then
		floorSurface = surfaceOf(floorSurface)
	end
	local counts = { parts = 0, groundParts = 0, decorParts = 0, floorParts = 0, violations = planResult.violations, featureCount = planResult.featureCount }
	for i, piece in ipairs(pieces) do
		local floor = Instance.new("Part")
		floor.Name = i == 1 and ("ZoneFloor_" .. zone.key) or ("ZoneFloor_" .. zone.key .. "_" .. i)
		floor.Size = Vector3.new(piece.maxX - piece.minX, opts.floorThickness, piece.maxZ - piece.minZ)
		floor.Position = Vector3.new((piece.minX + piece.maxX) / 2, opts.floorTopY - opts.floorThickness / 2, (piece.minZ + piece.maxZ) / 2)
		floor.Anchored = true
		floor.CastShadow = false
		applySurface(floor, floorSurface)
		floor:SetAttribute("ZoneKey", zone.key)
		CollectionService:AddTag(floor, ZoneTerrain.TAG)
		floor.Parent = GroundProbe.folder()
		counts.floorParts += 1
		counts.groundParts += 1
	end

	-- 지면 요소 먼저(스냅의 기준), 장식은 그 뒤.
	local pending = {}
	local index = 0
	for _, expanded in ipairs(planResult.accepted) do
		for _, prim in ipairs(expanded.prims) do
			index += 1
			local name = ("Terrain_%s_%d"):format(zone.key, index)
			if prim.ground then
				instantiate(prim, zone.key, name)
				counts.groundParts += 1
			else
				table.insert(pending, { prim = prim, name = name })
			end
		end
	end
	for _, item in ipairs(pending) do
		local part = instantiate(item.prim, zone.key, item.name)
		if item.prim.snap then
			snapToGround(part, item.prim)
		end
		counts.decorParts += 1
	end
	counts.parts = counts.groundParts + counts.decorParts
	return counts
end

-- 맵 밑판: 맵 사각형(테두리 포함)에서 구역 9개를 뺀 조각들 - 복도와 바깥 테두리만 덮는다.
-- 구역 바닥과 겹치지 않으므로 웅덩이 밑에 밑판이 비치지 않고, Raycast가 웅덩이 바닥을 그대로 본다.
function ZoneTerrain.buildMapBase(opts)
	local size = WorldConfig.superGrid.mapSizeStuds + opts.borderStuds * 2
	local pieces = { rect(0, 0, size, size) }
	for _, key in ipairs(WorldConfig.zoneOrder) do
		local zone = WorldConfig.zones[key]
		pieces = ZoneTerrain.splitRects(pieces, rect(zone.center.X, zone.center.Z, zone.halfSize * 2, zone.halfSize * 2))
	end
	for i, piece in ipairs(pieces) do
		local base = Instance.new("Part")
		base.Name = i == 1 and "MapBase" or ("MapBase_" .. i)
		base.Size = Vector3.new(piece.maxX - piece.minX, opts.thickness, piece.maxZ - piece.minZ)
		base.Position = Vector3.new((piece.minX + piece.maxX) / 2, opts.topY - opts.thickness / 2, (piece.minZ + piece.maxZ) / 2)
		base.Anchored = true
		base.CastShadow = false
		applySurface(base, surfaceOf(opts.surface))
		CollectionService:AddTag(base, ZoneTerrain.TAG)
		base.Parent = GroundProbe.folder()
	end
	return #pieces
end

-- 맵 가장자리 바위 능선(장식) - ZoneTerrainData.perimeter. 네 변을 따라 segmentLength마다 바위 블록
-- 하나(높이·폭·회전·색 무작위), boulder.every 칸마다 안쪽에 둥근 바위 하나.
function ZoneTerrain.buildPerimeterRidge(floorTopY)
	local spec = ZoneTerrainData.perimeter
	local rng = Random.new(spec.seed)
	local halfMap = WorldConfig.superGrid.mapSizeStuds / 2
	local count = 0
	local surface = surfaceOf(spec.surface)
	local boulderSurface = spec.boulder and surfaceOf(spec.boulder.surface)
	local segments = math.floor(halfMap * 2 / spec.segmentLength)
	local function jitteredColor(s)
		local j = spec.colorJitter or 0
		local d = rng:NextInteger(-j, j)
		return Color3.fromRGB(math.clamp(s.color[1] + d, 0, 255), math.clamp(s.color[2] + d, 0, 255), math.clamp(s.color[3] + d, 0, 255))
	end
	for _, side in ipairs({ { axis = "x", sign = 1 }, { axis = "x", sign = -1 }, { axis = "z", sign = 1 }, { axis = "z", sign = -1 } }) do
		for i = 0, segments - 1 do
			local along = -halfMap + spec.segmentLength * (i + 0.5)
			local across = side.sign * (halfMap + rng:NextNumber(-spec.insetJitter, spec.insetJitter))
			local h = rng:NextNumber(spec.heightRange[1], spec.heightRange[2])
			local w = rng:NextNumber(spec.widthRange[1], spec.widthRange[2])
			local yaw = math.rad(rng:NextNumber(-spec.yawJitterDegrees, spec.yawJitterDegrees))
			local x, z = across, along
			local size = Vector3.new(w, h, spec.segmentLength + 2)
			if side.axis == "z" then
				x, z = along, across
				size = Vector3.new(spec.segmentLength + 2, h, w)
			end
			local part = Instance.new("Part")
			part.Name = "PerimeterRidge"
			part.Size = size
			part.CFrame = CFrame.new(x, floorTopY + h / 2 - 1, z) * CFrame.Angles(0, yaw, 0)
			part.Anchored = true
			part.CanCollide = true
			applySurface(part, surface)
			part.Color = jitteredColor(surface)
			CollectionService:AddTag(part, ZoneTerrain.TAG)
			part.Parent = getDecorFolder()
			count += 1
			if spec.boulder and i % spec.boulder.every == 0 then
				local d = rng:NextNumber(spec.boulder.diameterRange[1], spec.boulder.diameterRange[2])
				local inward = side.sign * (halfMap - spec.boulder.inset - rng:NextNumber(0, 4))
				local bx, bz = inward, along + rng:NextNumber(-6, 6)
				if side.axis == "z" then
					bx, bz = along + rng:NextNumber(-6, 6), inward
				end
				-- 구역 지형(오두막·전망대 등)이 이미 차지한 자리면 건너뛴다 - 바닥·밑판은 겹침으로 안 친다.
				local overlap = OverlapParams.new()
				overlap.FilterType = Enum.RaycastFilterType.Include
				overlap.FilterDescendantsInstances = { getDecorFolder(), GroundProbe.folder() }
				local occupied = false
				for _, other in ipairs(workspace:GetPartBoundsInRadius(Vector3.new(bx, floorTopY + d / 2, bz), d / 2 + 1, overlap)) do
					if other.Name:sub(1, 9) ~= "ZoneFloor" and other.Name:sub(1, 7) ~= "MapBase" and other.Name ~= "PerimeterRidge" then
						occupied = true
						break
					end
				end
				if occupied then
					continue
				end
				local boulder = Instance.new("Part")
				boulder.Name = "PerimeterBoulder"
				boulder.Shape = Enum.PartType.Ball
				boulder.Size = Vector3.new(d, d, d)
				boulder.CFrame = CFrame.new(bx, floorTopY + d / 2 - d * 0.3, bz)
				boulder.Anchored = true
				boulder.CanCollide = true
				applySurface(boulder, boulderSurface)
				boulder.Color = jitteredColor(boulderSurface)
				CollectionService:AddTag(boulder, ZoneTerrain.TAG)
				boulder.Parent = getDecorFolder()
				count += 1
			end
		end
	end
	return count
end

return ZoneTerrain
