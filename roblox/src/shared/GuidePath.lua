-- QUEUE-ALL1 ★0 길 안내 경로: 지형 · 높이를 따라가는 점 목록. 클라 Wayfinder(그리기)와 서버 검사(GuideVerify)가 같이 쓴다.
--   경로 = 지금 자리 → (PathfindingService 경유점 · 실패하면 직선) → 길(RoadNet 점)에 합류 → 목적지.
--   모든 점은 sampleStuds 간격으로 나눈 뒤 위에서 아래로 레이캐스트한 지면 + groundLift에 놓는다(지면 아래 점 0).
--   멀어서 아직 지면을 못 읽은 점(스트리밍)은 ok = false로 두고, 가까워지면 다시 읽는다(GuidePath.ground).
-- 수치 = WorldMapData.guide.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local Workspace = game:GetService("Workspace")

local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local G = WorldMapData.guide
local SAFE_DROP = require(ReplicatedStorage.Shared.data.MovementConfig).fall.safeHeight

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
			-- QUEUE-ALL6 B1: 가파르지 않은데 가운데만 묻힌 선분(높이가 같은 두 점 사이의 작은 지면 혹)은 꺾은 선이 퇴화(꺾은 점 = 끝점)해 못 고쳤다 → 아래 가운데 점 들기로
			local steep = math.abs(b.Y - a.Y) > h * G.steepRatio
			if steep or (GuidePath.buried(mid, params) and math.abs(b.Y - a.Y) > 0.5) then
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
-- 경유점 사이 가장 큰 내려감(나무 둘레 밖 - 나무 둘레는 낙하 판정 제외)
function GuidePath.maxDrop(list)
	local worst = 0
	for k = 2, #list do
		if Vector3.new(list[k - 1].X, 0, list[k - 1].Z).Magnitude > WorldMapData.progress.treeRadius then
			worst = math.max(worst, list[k - 1].Y - list[k].Y)
		end
	end
	return worst
end

-- QUEUE-ALL1 R1: 안전 내리막 찾기(격자 A*) - 길찾기(PathfindingService)는 뛰어내림 높이 제한이 없어 절벽으로 내려간다.
--   from 둘레 격자 칸의 지면(이웃 칸 높이를 예상으로 읽음 - 아치 · 다리 위 제외)을 필요할 때만 레이캐스트 · 칸 사이 = 내려감 ≤ SAFE_DROP · 오름 ≤ rise · 가슴 높이 선 막힘 없음.
--   도착 = 길 점(joinFrom 번호부터) goalStuds 안 칸. 반환 = 경유점 목록 · 합류한 길 점 번호(못 찾으면 nil)
function GuidePath.safeDescent(from, road, params, joinFrom, relaxed)
	local S = G.safeGrid
	local sp = S.spacing
	local function key(ix, iz)
		return ix * 100003 + iz
	end
	local ox, oz = from.X, from.Z
	local heights, open, came, gScore = {}, {}, {}, {}
	local startY = GuidePath.groundY(from, params) or from.Y
	local sk = key(0, 0)
	heights[sk] = startY
	gScore[sk] = 0
	local goals = {}
	for k = joinFrom or 1, #road do
		local p = road[k]
		if (flat(p) - flat(from)).Magnitude <= S.radius + S.goalStuds then
			table.insert(goals, { p = p, k = k })
		end
	end
	if #goals == 0 then
		return nil
	end
	local function h(x, z)
		local best = math.huge
		for _, g in ipairs(goals) do
			best = math.min(best, (Vector3.new(g.p.X - x, 0, g.p.Z - z)).Magnitude)
		end
		return best
	end
	local function goalAt(x, z, y)
		for _, g in ipairs(goals) do
			if (Vector3.new(g.p.X - x, 0, g.p.Z - z)).Magnitude <= S.goalStuds then
				if g.ground == nil then
					g.ground = GuidePath.groundY(g.p, params) or false -- 길 점의 실제 지면(바로 위 절벽 턱에서 뛰어내리는 합류 막기)
				end
				if g.ground and math.abs(g.ground - y) <= SAFE_DROP then
					return g.k
				end
			end
		end
		return nil
	end
	-- 이진 힙(f 작은 것 먼저)
	local function push(node)
		table.insert(open, node)
		local i = #open
		while i > 1 do
			local parent = i // 2
			if open[parent].f <= open[i].f then
				break
			end
			open[parent], open[i] = open[i], open[parent]
			i = parent
		end
	end
	local function pop()
		local top = open[1]
		local last = table.remove(open)
		if #open > 0 then
			open[1] = last
			local i = 1
			while true do
				local l, r, m = i * 2, i * 2 + 1, i
				if l <= #open and open[l].f < open[m].f then
					m = l
				end
				if r <= #open and open[r].f < open[m].f then
					m = r
				end
				if m == i then
					break
				end
				open[m], open[i] = open[i], open[m]
				i = m
			end
		end
		return top
	end
	push({ f = h(ox, oz), ix = 0, iz = 0 })
	local visited, count = {}, 0
	while #open > 0 and count < S.maxNodes do
		local cur = pop()
		local ck = key(cur.ix, cur.iz)
		if not visited[ck] then
			visited[ck] = true
			count += 1
			local cx, cz, cy = ox + cur.ix * sp, oz + cur.iz * sp, heights[ck]
			local hit = goalAt(cx, cz, cy)
			if hit then
				local list, k = {}, ck
				while k do
					local ix, iz = math.floor((k + 50001) / 100003), nil
					iz = k - ix * 100003
					table.insert(list, 1, Vector3.new(ox + ix * sp, heights[k], oz + iz * sp))
					k = came[k]
				end
				list[1] = from
				table.insert(list, road[hit])
				return list, hit
			end
			for dx = -1, 1 do
				for dz = -1, 1 do
					if dx ~= 0 or dz ~= 0 then
						local nx, nz = cur.ix + dx, cur.iz + dz
						local nk = key(nx, nz)
						local px, pz = ox + nx * sp, oz + nz * sp
						if not visited[nk] and (Vector3.new(px - ox, 0, pz - oz)).Magnitude <= S.radius then
							local ny = heights[nk]
							if ny == nil then
								ny = GuidePath.groundY(Vector3.new(px, cy, pz), params) or false
								heights[nk] = ny
							end
							if ny then
								local dy = ny - cy
								local run = sp * math.sqrt(dx * dx + dz * dz)
								local over = -dy - SAFE_DROP -- 안전 높이를 넘는 내려감(relaxed = 벌점 붙여 허용 - 고립된 바위 · 턱 꼭대기에서 가장 낮은 곳으로 한 번)
								if (over <= 0 or (relaxed and -dy <= S.relaxMaxDrop)) and dy <= S.rise * run / sp then
									local a, b = Vector3.new(cx, cy + S.probe, cz), Vector3.new(px, ny + S.probe, pz)
									local blocked = Workspace:Raycast(a, b - a, params)
									if not blocked and over <= 0 then -- 칸 사이 가운데가 꺼진 틈(경로 점은 4 stud마다 다시 지면에 붙는다) = 못 감
										local mid = GuidePath.groundY(Vector3.new((cx + px) / 2, math.max(cy, ny), (cz + pz) / 2), params)
										blocked = mid == nil or math.max(cy, ny) - mid > SAFE_DROP
									end
									if not blocked then
										local g = gScore[ck] + run + math.max(0, -dy) * 0.5 + (over > 0 and (S.dropPenalty + over * S.dropPenaltyPerStud) or 0)
										if gScore[nk] == nil or g < gScore[nk] then
											gScore[nk], came[nk] = g, ck
											push({ f = g + h(px, pz), ix = nx, iz = nz })
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end
	return nil
end

-- 경로 안의 낙하 피해 내려감 수 · 가장 큰 내려감(나무 둘레 제외 · 지면 읽은 점만)
function GuidePath.dropCount(route)
	local n, worst = 0, 0
	for k = 2, #route.points do
		local a, b = route.points[k - 1], route.points[k]
		if route.ok[k - 1] and route.ok[k] and a.Y - b.Y > SAFE_DROP and Vector3.new(a.X, 0, a.Z).Magnitude > WorldMapData.progress.treeRadius then
			n += 1
			worst = math.max(worst, a.Y - b.Y)
		end
	end
	return n, worst
end

-- QUEUE-ALL2 P0-3: 가장 큰 낙하의 윗점(고립 꼭대기 = 안전 내리막 없음 → "여기서 뛰어내려요" 말풍선 자리). 낙하 피해 내려감이 없으면 nil
function GuidePath.worstDropPoint(route)
	local best, worst = nil, SAFE_DROP
	for k = 2, #route.points do
		local a, b = route.points[k - 1], route.points[k]
		if route.ok[k - 1] and route.ok[k] and a.Y - b.Y > worst and Vector3.new(a.X, 0, a.Z).Magnitude > WorldMapData.progress.treeRadius then
			best, worst = a, a.Y - b.Y
		end
	end
	return best
end

local function finish(from, road, params, groundNear, legs, pathfound, i)
	local raw = {}
	for _, p in ipairs(legs) do
		table.insert(raw, p)
	end
	for k = i + 1, #road do
		table.insert(raw, road[k])
	end
	-- sampleStuds 간격으로 나눔(수평 거리 기준)
	local route = { points = { raw[1] }, ok = { false }, pathfound = pathfound, joinIndex = #legs, maxDrop = GuidePath.maxDrop(legs) }
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

function GuidePath.build(from, road, params, groundNear)
	local i = GuidePath.nextIndex(road, from)
	local legs, pathfound = GuidePath.approach(from, road[i])
	-- 길찾기가 낙하 피해 높이를 넘는 절벽으로 뛰어내리면 다른 합류점(joinTries - 길 점 번호 차)으로 다시 찾아 절벽 없는 쪽을 쓴다(없으면 처음 것)
	if GuidePath.maxDrop(legs) > SAFE_DROP then
		for _, off in ipairs(G.joinTries) do
			local j = math.clamp(i + off, 1, #road)
			if j ~= i then
				local other, found = GuidePath.approach(from, road[j])
				if found and GuidePath.maxDrop(other) <= SAFE_DROP then
					legs, pathfound, i = other, found, j
					break
				end
			end
		end
	end
	local route = finish(from, road, params, groundNear, legs, pathfound, i)
	-- QUEUE-ALL1 R1: 지면에 붙인 뒤에도 낙하 피해 내려감이 남으면 격자 A*로 안전 내리막을 찾아 다시 만든다(줄어들 때만 바꾼다 · 못 찾으면 그대로 - 자동 이동은 큰 절벽 앞에서 멈춘다)
	local drops, worst = GuidePath.dropCount(route)
	if drops > 0 then
		for _, relaxed in ipairs({ false, true }) do -- 먼저 낙하 0 · 없으면(고립 꼭대기) 가장 낮은 낙하
			local safe, k = GuidePath.safeDescent(from, road, params, math.max(1, i - 6), relaxed)
			if safe then
				local other = finish(from, road, params, groundNear, safe, true, k)
				local otherDrops, otherWorst = GuidePath.dropCount(other)
				if otherDrops < drops or (otherDrops == drops and otherWorst < worst - 1) then
					route, drops, worst = other, otherDrops, otherWorst
					route.safeGrid = relaxed and "relaxed" or true
				end
				if drops == 0 then
					break
				end
			end
		end
	end
	route.dropWorst = worst
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
