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
					if not atGoal and GuidePath.buried(w.Position + Vector3.new(0, 0.5, 0), rp) then -- 웨이포인트 = 발밑(지면 높이) → 0.5 위가 묻혔나
						under += 1
						local hit = Workspace:Raycast(w.Position + Vector3.new(0, 0.5 + 3, 0), Vector3.new(0, -2.95, 0), rp)
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

return HubPathVerify
