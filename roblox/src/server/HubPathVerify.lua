-- QUEUE-ALL7B 3 허브 동선 검사(수동 호출 - 서버 execute_luau에서 require(...).run()). 건물 메시를 바꾼 뒤 길이 막히지 않았는지 잰다.
--   ① 길 막힘: 구역 본길 점(RoadNet) 중 허브 건물 충돌 상자(Facility_*) 안(길 반폭 6 = 폭 12 만큼 넓힌 상자)에 든 수 = 0
--   ② 길 찾기: 허브 안 무작위 시작점 starts개 → 허브 기능 · 시설 · 구역 출구 중 하나(PathfindingService - 캐릭터 크기) · 도착률 · 땅속 웨이포인트 수
--   ③ 안 C 동선: 체크포인트(허브 −65° r180) → 각 기능 · NPC 자리 걷는 시간(경로 길이 ÷ 걷기 속도) · 가장 먼 곳
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RoadNet = require(ReplicatedStorage.Shared.RoadNet)
local GuidePath = require(ReplicatedStorage.Shared.GuidePath)
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)
local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)

local HubPathVerify = {}
local H = WorldMapData.hub
local FLOOR = WorldMapData.floorTopY

local function buildingBoxes()
	local out = {}
	local hub = Workspace:FindFirstChild("Ground") and Workspace.Ground:FindFirstChild("Hub")
	for _, d in ipairs(hub and hub:GetDescendants() or {}) do
		if d:IsA("BasePart") and d.Name:match("^Facility_") then
			table.insert(out, d)
		end
	end
	return out
end

local function inside(part, p, pad)
	local l = part.CFrame:PointToObjectSpace(p)
	local h = part.Size / 2
	return math.abs(l.X) <= h.X + pad and math.abs(l.Z) <= h.Z + pad
end

local function targets()
	local list = {}
	local function add(name, p)
		table.insert(list, { name = name, pos = Vector3.new(p.X, FLOOR + 3, p.Z) })
	end
	for _, name in ipairs(WorldMapLayout.facilityOrder) do
		add("시설 " .. name, WorldMapLayout.facility(name))
		for _, sp in ipairs(H.facilities[name].spots or {}) do
			if not sp.disabled then -- QUEUE-ALL8 G5: 판매 자리 없음
				add("자리 " .. sp.id, WorldMapLayout.spot(sp.id))
			end
		end
	end
	for _, zone in ipairs(WorldMapData.zones) do
		local pts = RoadNet.zonePath(zone).pts
		local first = pts[1]
		add("출구 " .. zone.key, Vector3.new(first.x, 0, first.z))
	end
	return list
end

local function groundY(p, rp)
	local hit = Workspace:Raycast(Vector3.new(p.X, p.Y + 60, p.Z), Vector3.new(0, -200, 0), rp)
	return hit and hit.Position.Y
end

local function pathLength(from, to)
	local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 6 })
	local ok = pcall(function()
		path:ComputeAsync(from, to)
	end)
	if not ok or path.Status ~= Enum.PathStatus.Success then
		return nil
	end
	local wps = path:GetWaypoints()
	local len = 0
	for i = 2, #wps do
		len += (wps[i].Position - wps[i - 1].Position).Magnitude
	end
	-- 경로 끝이 목표에서 멀면 = 못 감(부분 경로)
	if ((wps[#wps].Position - to) * Vector3.new(1, 0, 1)).Magnitude > 8 then
		return nil
	end
	return len, wps
end

function HubPathVerify.run(opts)
	opts = opts or {}
	local out = {}
	local boxes = buildingBoxes()
	-- ⓪ 자리 기둥 수 = 데이터(비활성 제외) - QUEUE-ALL8: 줄 가운데 주석이 자리를 지운 결함을 다시 잡는다
	local want, have = 0, 0
	for _, name in ipairs(WorldMapLayout.facilityOrder) do
		for _, sp in ipairs(H.facilities[name].spots or {}) do
			if not sp.disabled then
				want += 1
			end
		end
	end
	local hubModel = Workspace:FindFirstChild("Ground") and Workspace.Ground:FindFirstChild("Hub")
	for _, d in ipairs(hubModel and hubModel:GetDescendants() or {}) do
		if d:IsA("BasePart") and d.Name:match("^Spot_") and d:GetAttribute("District") then
			have += 1
		end
	end
	table.insert(out, ("⓪ 시설 자리 기둥 %d / 데이터 %d %s"):format(have, want, have == want and "O" or "X"))
	-- ① 길 막힘
	local blocked = 0
	for _, path in ipairs(RoadNet.all()) do
		for _, q in ipairs(path.pts) do
			local p = Vector3.new(q.x, FLOOR, q.z)
			if p.Magnitude < H.safeRadius + 80 then
				for _, b in ipairs(boxes) do
					if inside(b, p, 6) then
						blocked += 1
					end
				end
			end
		end
	end
	table.insert(out, ("① 건물 상자 %d개 · 구역 길 점(허브 둘레) 중 상자 안(폭 12로 넓힘) %d %s"):format(#boxes, blocked, blocked == 0 and "O" or "X"))
	-- ② 길 찾기
	local ex = {}
	for _, pl in ipairs(game:GetService("Players"):GetPlayers()) do
		if pl.Character then
			table.insert(ex, pl.Character)
		end
	end
	if Workspace:FindFirstChild("HubArt") then
		table.insert(ex, Workspace.HubArt)
	end
	local rp = GuidePath.rayParams(ex) -- 길 안내와 같은 기준(충돌하는 표면만 - 잎 · 지붕 메시 · 장식 제외)
	local op = OverlapParams.new() -- 가슴 높이 판정(정확한 도형 - GetPartBoundsInRadius는 경계 상자라 큰 줄기 원통 둘레를 속으로 셌다)
	op.RespectCanCollide = true
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = ex
	local probe = Instance.new("Part")
	probe.Shape = Enum.PartType.Ball
	probe.Size = Vector3.one * 0.1 -- 점(가슴 점이 도형 속인가 - 0.8 공은 모서리를 0.4 안 스치는 것까지 셌다)
	probe.Anchored, probe.CanCollide, probe.CanTouch, probe.CanQuery = true, false, false, false
	local rng = Random.new(opts.seed or 20261002)
	local T = targets()
	local starts, arrived, under, tries = opts.starts or 60, 0, 0, 0
	local fails, underAt = {}, {}
	local n = 0
	while n < starts and tries < starts * 10 do
		tries += 1
		local a = rng:NextNumber(0, 2 * math.pi)
		local r = rng:NextNumber(70, H.safeRadius - 20)
		local p = Vector3.new(math.cos(a) * r, FLOOR, math.sin(a) * r)
		local free = true
		for _, b in ipairs(boxes) do
			if inside(b, p, 3) then
				free = false
			end
		end
		local gy = free and groundY(p, rp)
		if gy and gy < FLOOR + 6 then -- 뿌리 · 나무 위 같은 높은 곳 제외(허브 바닥 시작)
			n += 1
			local t = T[rng:NextInteger(1, #T)]
			local len, wps = pathLength(Vector3.new(p.X, gy + 3, p.Z), t.pos)
			if len then
				arrived += 1
				for _, w in ipairs(wps) do
					local atGoal = ((w.Position - t.pos) * Vector3.new(1, 0, 1)).Magnitude < 4 -- 목적지 = 자리 기둥 속(검사 자리 - 길이 아니다)
					-- QUEUE-ALL8 H6: 점프 지점(장애물 윗면 바로 아래 발 - 뛰어오르는 자리)은 "위에 표면"이 당연 → 뺀다. 가슴 높이가 단단한 도형 속이면 점프여도 센다
					probe.CFrame = CFrame.new(w.Position + Vector3.new(0, 2.5, 0))
					local inSolid = #Workspace:GetPartsInPart(probe, op) > 0
					local jump = w.Action == Enum.PathWaypointAction.Jump
					-- 보이지 않는 충돌 상자(가지 채움 BranchFill) 윗면이 발 1 stud 안 위 = 길찾기 높이 양자화(그 위에 선다 · 선도 안 가린다) → 묻힘 아님
					local hit = Workspace:Raycast(w.Position + Vector3.new(0, 0.5 + 3, 0), Vector3.new(0, -2.95, 0), rp)
					local step = hit and hit.Instance.Transparency >= 1 and hit.Position.Y - w.Position.Y <= 1
					if not atGoal and (inSolid or (not jump and not step and GuidePath.buried(w.Position + Vector3.new(0, 0.5, 0), rp))) then -- 웨이포인트 = 발밑(지면 높이) → 0.5 위가 묻혔나
						under += 1
						if #underAt < 8 then
							table.insert(underAt, ("(%d, %.1f, %d %s)"):format(w.Position.X, w.Position.Y, w.Position.Z, hit and hit.Instance.Name or "?"))
						end
					end
				end
			else
				table.insert(fails, ("(%d, %d) → %s"):format(p.X, p.Z, t.name))
			end
		end
	end
	probe:Destroy()
	local rate = n > 0 and arrived / n or 0
	table.insert(out, ("② 시작점 %d · 도착 %d(%.1f%%) · 땅속 웨이포인트 %d %s%s"):format(n, arrived, rate * 100, under, (rate >= 0.95 and under == 0) and "O" or "X",
		#fails > 0 and (" · 실패: " .. table.concat(fails, " / ")) or "") .. (#underAt > 0 and (" · 묻힘: " .. table.concat(underAt, " ")) or ""))
	-- ③ 안 C 동선(체크포인트 → 기능 · NPC)
	local cp = WorldMapLayout.hubPoint(-65, 180)
	local from = Vector3.new(cp.X, FLOOR + 3, cp.Z)
	local worst, worstName, worstLine, rows = 0, "-", 0, {}
	for _, t in ipairs(T) do
		if not t.name:match("^출구") then
			local len = pathLength(from, t.pos)
			local sec = len and len / MovementConfig.walkSpeedStuds
			local line = ((t.pos - from) * Vector3.new(1, 0, 1)).Magnitude / MovementConfig.walkSpeedStuds
			table.insert(rows, ("%s %s(직선 %.1f)"):format((t.name:gsub("^자리 ", ""):gsub("^시설 ", "")), sec and ("%.1f초"):format(sec) or "못 감", line))
			if sec and sec > worst then
				worst, worstName = sec, t.name
			end
			worstLine = math.max(worstLine, line)
		end
	end
	table.insert(out, ("③ 체크포인트 → 가장 먼 곳 %s 경로 %.1f초 · 직선 최대 %.1f초(옛 안 C 9.4초) · %s"):format(worstName, worst, worstLine, table.concat(rows, " · ")))
	return table.concat(out, "\n")
end

-- QUEUE-ALL8 B3 소품 배치 검사: 놓인 소품마다 비워 둘 거리(HubPropLayout.clearViolations - 구역 길 · 걷는 길 · 기능 자리 · 건물 · 뿌리)를 다시 잰다.
--   경계 랜턴(boundary) = 옛 기둥 자리 그대로라 따로 센다. 반환 = 출처별 개수 · 어긴 수 · 예
function HubPathVerify.props()
	local HubPropLayout = require(ReplicatedStorage.Shared.HubPropLayout)
	local HubArt = require(script.Parent.HubArt)
	local folder = Workspace:FindFirstChild("HubArt") and Workspace.HubArt:FindFirstChild("Props")
	if not folder then
		return "소품 없음(아트 끔?)"
	end
	local bySource, bad, ex = {}, {}, {}
	for _, m in ipairs(folder:GetChildren()) do
		local src = m:GetAttribute("Source") or "?"
		bySource[src] = (bySource[src] or 0) + 1
		local v = HubPropLayout.clearViolations(m.WorldPivot.Position, HubArt.propSizeOf(m.Name) * 0.6, m.Name)
		if #v > 0 then
			bad[src] = (bad[src] or 0) + 1
			if #ex < 8 and src ~= "boundary" then
				table.insert(ex, ("%s@(%d, %d) %s"):format(m.Name:gsub("^prop_", ""), m.WorldPivot.X, m.WorldPivot.Z, table.concat(v, "·")))
			end
		end
	end
	local rows = {}
	for src, n in pairs(bySource) do
		table.insert(rows, ("%s %d(어김 %d)"):format(src, n, bad[src] or 0))
	end
	table.sort(rows)
	local nonBoundary = 0
	for src, n in pairs(bad) do
		if src ~= "boundary" then
			nonBoundary += n
		end
	end
	return ("소품 %s · 길 위(경계 랜턴 빼고) %d %s%s"):format(table.concat(rows, " · "), nonBoundary, nonBoundary == 0 and "O" or "X", #ex > 0 and (" · 예: " .. table.concat(ex, " / ")) or "")
end

-- QUEUE-ALL8 B1 밀도: 허브 활동 영역(반경 rMin ~ rMax · 건물 상자 밖) 4 stud 격자마다 15 stud 안에 "볼거리"가 있나.
--   볼거리 = 바닥 위 0.8 stud 넘게 솟은 파트(건물 · 소품 · 나무 · 꽃 · 노점 · NPC · 기둥) - 바닥판 · 지형 · 캐릭터 · 투명 = 아님.
--   반환 = 빈 칸 비율 · 빈 칸 면적(stud²) · 가장 큰 빈 덩어리 쪽(각도 구간별 빈 비율) 요약
function HubPathVerify.density(opts)
	opts = opts or {}
	local rMin, rMax, step, reach = opts.rMin or 60, opts.rMax or 330, opts.step or 4, opts.reach or 15
	local boxes = buildingBoxes()
	local interest = {}
	local players = {}
	for _, pl in ipairs(game:GetService("Players"):GetPlayers()) do
		if pl.Character then
			players[pl.Character] = true
		end
	end
	local function isInterest(p)
		if not p:IsA("BasePart") or p:IsA("Terrain") then
			return false
		end
		if p.Transparency >= 0.95 and not p:GetAttribute("HubBuilding") then
			return false
		end
		local m = p:FindFirstAncestorOfClass("Model")
		while m do
			if players[m] then
				return false
			end
			m = m.Parent and m.Parent:FindFirstAncestorOfClass("Model")
		end
		local top = p.Position.Y + p.Size.Y / 2
		local horiz = math.max(p.Size.X, p.Size.Z)
		if top < FLOOR + 0.8 or p.Position.Y > FLOOR + 60 then
			return false -- 바닥판 · 높은 잎 덮개
		end
		return horiz < 400 -- 허브 바닥 원판 같은 큰 판 제외
	end
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d:IsA("BasePart") and Vector2.new(d.Position.X, d.Position.Z).Magnitude < rMax + reach + 40 and isInterest(d) then
			table.insert(interest, d)
		end
	end
	-- 볼거리 점(파트 경계 상자를 4 stud 간격 점으로 - 큰 건물도 가장자리에서 거리 계산)
	local pts = {}
	for _, p in ipairs(interest) do
		local hx, hz = p.Size.X / 2, p.Size.Z / 2
		for x = -hx, hx, math.max(4, hx) do
			for z = -hz, hz, math.max(4, hz) do
				local w = p.CFrame:PointToWorldSpace(Vector3.new(x, 0, z))
				table.insert(pts, Vector2.new(w.X, w.Z))
			end
		end
	end
	local grid = {} -- 버킷(20 stud) 가속
	local B = 20
	for _, v in ipairs(pts) do
		local k = math.floor(v.X / B) .. ":" .. math.floor(v.Y / B)
		grid[k] = grid[k] or {}
		table.insert(grid[k], v)
	end
	-- 활동 영역 = 시설 · 기능 자리 · 체크포인트 · 스폰에서 activityRadius 안(허브 뒤쪽 빈 들판은 "마을 밖")
	local anchors = {}
	for _, t in ipairs(targets()) do
		if not t.name:match("^출구") then
			table.insert(anchors, Vector2.new(t.pos.X, t.pos.Z))
		end
	end
	local cp = WorldMapLayout.hubPoint(-65, 180)
	local sp = WorldMapLayout.spawnPoint()
	table.insert(anchors, Vector2.new(cp.X, cp.Z))
	table.insert(anchors, Vector2.new(sp.X, sp.Z))
	local activityR = opts.activityRadius or 70
	local function inActivity(x, z)
		if opts.whole then
			return true
		end
		for _, a in ipairs(anchors) do
			if (a - Vector2.new(x, z)).Magnitude <= activityR then
				return true
			end
		end
		return false
	end
	local total, empty = 0, 0
	local sectors = {}
	for i = 1, 12 do
		sectors[i] = { n = 0, e = 0 }
	end
	for x = -rMax, rMax, step do
		for z = -rMax, rMax, step do
			local r = math.sqrt(x * x + z * z)
			if r >= rMin and r <= rMax and inActivity(x, z) then
				local c = Vector3.new(x, FLOOR, z)
				local inBox = false
				for _, b in ipairs(boxes) do
					if inside(b, c, 0) then
						inBox = true
					end
				end
				if not inBox then
					total += 1
					local found = false
					local bx, bz = math.floor(x / B), math.floor(z / B)
					for i = -1, 1 do
						for j = -1, 1 do
							for _, v in ipairs(grid[(bx + i) .. ":" .. (bz + j)] or {}) do
								if not found and (v - Vector2.new(x, z)).Magnitude <= reach then
									found = true
								end
							end
						end
					end
					local sIdx = math.floor(((math.deg(math.atan2(z, x)) + 360) % 360) / 30) + 1
					sectors[sIdx].n += 1
					if not found then
						empty += 1
						sectors[sIdx].e += 1
					end
				end
			end
		end
	end
	local srow = {}
	for i, s in ipairs(sectors) do
		table.insert(srow, ("%d°~%d° %d%%"):format((i - 1) * 30, i * 30, s.n > 0 and math.floor(s.e / s.n * 100 + 0.5) or 0))
	end
	return ((opts.whole and "밀도(허브 전체 고리)" or ("밀도(활동 영역 = 시설 · 기능 · 체크포인트 · 스폰 %d 안)"):format(activityR)) .. (": 반경 %d ~ %d · 격자 %d · 칸 %d · 15 stud 안 볼거리 없는 칸 %d(%.1f%% · 약 %d stud²) · 볼거리 파트 %d · 30°마다 빈 비율: %s")):format(rMin, rMax, step, total, empty, total > 0 and empty / total * 100 or 0, empty * step * step, #interest, table.concat(srow, " · "))
end

return HubPathVerify
