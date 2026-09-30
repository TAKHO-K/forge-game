-- QUEUE-ALL1 ★0 길 안내 경로: 지형 · 높이를 따라가는 점 목록. 클라 Wayfinder(그리기)와 서버 검사(GuideVerify)가 같이 쓴다.
--   경로 = 지금 자리 → (PathfindingService 경유점 · 실패하면 직선) → 길(RoadNet 점)에 합류 → 목적지.
--   모든 점은 sampleStuds 간격으로 나눈 뒤 위에서 아래로 레이캐스트한 지면 + groundLift에 놓는다(지면 아래 점 0).
--   멀어서 아직 지면을 못 읽은 점(스트리밍)은 ok = false로 두고, 가까워지면 다시 읽는다(GuidePath.ground).
-- 수치 = WorldMapData.guide.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local Workspace = game:GetService("Workspace")

local G = require(ReplicatedStorage.Shared.data.WorldMapData).guide

local GuidePath = {}

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- 지면 레이캐스트 조건: 충돌 켜진 것만(나무 잎 · 장식 제외) · 물 표면 포함 · exclude = 캐릭터 · 안내 파트 등
function GuidePath.rayParams(exclude)
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	p.FilterDescendantsInstances = exclude or {}
	p.RespectCanCollide = true
	p.IgnoreWater = false
	return p
end

-- 세로 줄의 표면들(위 → 아래, 지형을 만나면 멈춤): pos.Y + probeUp에서 아래로 최대 columnHits개
local function column(pos, params)
	local hits = {}
	local y, bottom = pos.Y + G.probeUp, pos.Y - G.probeDown
	for _ = 1, G.columnHits do
		local hit = Workspace:Raycast(Vector3.new(pos.X, y, pos.Z), Vector3.new(0, bottom - y, 0), params)
		if not hit then
			break
		end
		table.insert(hits, hit.Position.Y)
		if hit.Instance:IsA("Terrain") then
			break
		end
		y = hit.Position.Y - 0.05 -- 파트 안에서 시작한 광선은 그 파트를 안 맞힌다 → 아래 표면으로
	end
	return hits
end

-- (x, z)의 지면 높이(없으면 nil). pos.Y = 예상 높이(길 점 · 길찾기 점 · 직선 보간).
--   관문 아치 · 다리 위처럼 머리 위 표면을 고르지 않게 = 예상 + climbStuds 아래 표면 중 가장 높은 것 · 없으면(예상이 언덕 속) 가장 낮은 표면
function GuidePath.groundY(pos, params)
	local hits = column(pos, params)
	local best = nil
	for _, y in ipairs(hits) do
		if y <= pos.Y + G.climbStuds and (not best or y > best) then
			best = y
		end
	end
	return best or hits[#hits]
end

-- 점이 지면에 묻혔나: 점 바로 위(buriedStuds 안)에 표면이 있거나 · 점 아래 표면을 못 찾음
function GuidePath.buried(p, params)
	local hit = Workspace:Raycast(p + Vector3.new(0, G.buriedStuds, 0), Vector3.new(0, -G.buriedStuds + 0.05, 0), params)
	return hit ~= nil
end

-- 순수: 지금 자리에서 다음 점 번호(가장 가까운 선분의 끝 - 이미 지난 점은 건너뛴다)
function GuidePath.nextIndex(points, position)
	local p = flat(position)
	local bestI, bestD = 1, math.huge
	for i = 1, #points do
		local a = flat(points[i])
		local d = (p - a).Magnitude
		if i > 1 then
			local b = flat(points[i - 1])
			local ab = a - b
			local t = math.clamp((p - b):Dot(ab) / math.max(ab:Dot(ab), 1e-6), 0, 1)
			d = (p - (b + ab * t)).Magnitude
		end
		if d < bestD then
			bestI, bestD = i, d
		end
	end
	return bestI
end

-- 지금 자리 → 합류점: 길찾기 경유점(성공) 또는 { from, to }(실패 · 너무 멂)
function GuidePath.approach(from, to)
	if (flat(to) - flat(from)).Magnitude > G.pathMaxStuds then
		return { from, to }, false
	end
	local path = PathfindingService:CreatePath(G.agent)
	local ok = pcall(function()
		path:ComputeAsync(from, to)
	end)
	if not ok or path.Status ~= Enum.PathStatus.Success then
		return { from, to }, false
	end
	local list = {}
	for _, w in ipairs(path:GetWaypoints()) do
		table.insert(list, w.Position)
	end
	if #list < 2 then
		return { from, to }, false
	end
	return list, true
end

-- 점 하나를 지면 위로(읽었으면 true)
function GuidePath.ground(route, i, params)
	local y = GuidePath.groundY(route.points[i], params)
	if y then
		route.points[i] = Vector3.new(route.points[i].X, y + G.groundLift, route.points[i].Z)
		route.ok[i] = true
	end
	return route.ok[i]
end

-- 선분 가운데가 지면 아래로 파고들면(볼록한 언덕) 가운데 점을 끼워 넣고 · 절벽 · 턱은 꺾은 선으로. lo ~ hi 번호 선분만(클라 = 방금 지면을 읽은 구간).
--   반환 = 끼워 넣은 점 수(번호가 그만큼 밀린다). build는 전체를 두 번(끼워 넣은 가운데 점 양쪽을 한 번 더).
function GuidePath.liftRange(route, params, lo, hi)
	lo, hi = math.max(2, lo or 2), math.min(#route.points, hi or #route.points)
	local pts, ok = table.move(route.points, 1, lo - 1, 1, {}), table.move(route.ok, 1, lo - 1, 1, {})
	for i = lo, hi do
		local a, b = route.points[i - 1], route.points[i]
		local h = (flat(b) - flat(a)).Magnitude
		if route.ok[i - 1] and route.ok[i] and h >= 0.5 then
			local mid = (a + b) / 2
			if math.abs(b.Y - a.Y) > h * G.steepRatio or GuidePath.buried(mid, params) then
				-- 절벽(길찾기 뛰어내림 · 올라감) · 턱(바위 · 계단 옆면): 비스듬한 선은 옆면을 파고든다 → 높은 쪽 높이로 수평 이동 뒤 낮은 쪽 줄에서 수직
				table.insert(pts, b.Y < a.Y and Vector3.new(b.X, a.Y, b.Z) or Vector3.new(a.X, b.Y, a.Z))
				table.insert(ok, true)
			else
				local y = GuidePath.groundY(mid, params)
				if y and y + G.groundLift * 0.5 > mid.Y then
					table.insert(pts, Vector3.new(mid.X, y + G.groundLift, mid.Z))
					table.insert(ok, true)
				end
			end
		end
		table.insert(pts, b)
		table.insert(ok, route.ok[i])
	end
	local added = #pts - hi
	table.move(route.points, hi + 1, #route.points, #pts + 1, pts)
	table.move(route.ok, hi + 1, #route.ok, #ok + 1, ok)
	route.points, route.ok = pts, ok
	return added
end

-- 경로 만들기. road = 길 점 목록(목적지가 마지막) · from = 발 위치. 반환 { points, ok, pathfound, joinIndex }
--   groundNear = from에서 이 거리 안의 점만 지금 지면을 읽는다(나머지는 가까워지면 - 스트리밍 · 계산량)
function GuidePath.build(from, road, params, groundNear)
	local i = GuidePath.nextIndex(road, from)
	local legs, pathfound = GuidePath.approach(from, road[i])
	local raw = {}
	for _, p in ipairs(legs) do
		table.insert(raw, p)
	end
	for k = i + 1, #road do
		table.insert(raw, road[k])
	end
	-- sampleStuds 간격으로 나눔(수평 거리 기준)
	local route = { points = { raw[1] }, ok = { false }, pathfound = pathfound, joinIndex = #legs }
	for k = 2, #raw do
		local a, b = raw[k - 1], raw[k]
		local n = math.max(1, math.ceil((flat(b) - flat(a)).Magnitude / G.sampleStuds))
		for s = 1, n do
			table.insert(route.points, a:Lerp(b, s / n))
			table.insert(route.ok, false)
		end
	end
	local near = groundNear or math.huge
	for k = 1, #route.points do
		if (flat(route.points[k]) - flat(from)).Magnitude <= near then
			GuidePath.ground(route, k, params)
		end
	end
	GuidePath.liftRange(route, params)
	GuidePath.liftRange(route, params)
	return route
end

-- 마지막 안전장치: 이 선분을 그려도 되나(양 끝 · 가운데 모두 묻히지 않음). 길 위 기둥 · 아치 윗판 아래로 뛰어내림 등 꺾은 선으로도 못 피한 조각은 안 그린다.
function GuidePath.segmentVisible(a, b, params)
	return not (GuidePath.buried(a, params) or GuidePath.buried(b, params) or GuidePath.buried((a + b) / 2, params))
end

-- 검사용: 숨긴 조각(그리지 않는 선분) 수 · 가장 긴 연속 숨김 길이(수평 stud)
function GuidePath.hiddenRuns(route, params)
	local count, run, longest = 0, 0, 0
	for k = 2, #route.points do
		local a, b = route.points[k - 1], route.points[k]
		if route.ok[k - 1] and route.ok[k] and not GuidePath.segmentVisible(a, b, params) then
			count += 1
			run += (flat(b) - flat(a)).Magnitude
			longest = math.max(longest, run)
		else
			run = 0
		end
	end
	return count, longest
end

-- 검사용: 점 · 선분 가운데가 지면 아래인가(지면이 점보다 위 = 파고듦). 반환 최소 여유(점 y − 지면 y) · 파고든 수
function GuidePath.clearance(route, params, fromIndex, toIndex)
	local minGap, under, checked = math.huge, 0, 0
	local function test(p)
		checked += 1
		local y = GuidePath.groundY(p - Vector3.new(0, G.groundLift, 0), params)
		if y then
			minGap = math.min(minGap, p.Y - y)
		end
		if GuidePath.buried(p, params) then
			under += 1
		end
	end
	for k = fromIndex or 1, math.min(toIndex or #route.points, #route.points) do
		if route.ok[k] then
			test(route.points[k])
			if k > 1 and route.ok[k - 1] then
				test((route.points[k] + route.points[k - 1]) / 2)
			end
		end
	end
	return minGap, under, checked
end

return GuidePath
