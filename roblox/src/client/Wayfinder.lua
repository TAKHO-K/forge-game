-- M1 길 안내(공용 - 보스 관문 · 보스 선택 창 [여기로 안내] · 튜토리얼이 같이 쓴다). 바닥 빛줄기(지금 자리 → 다음 길목) + 앞으로 갈 길 위 화살표.
-- 로컬 파트만(서버 · 다른 사람에게 안 보인다) · 파티클 없음 · 충돌 · 쿼리 · 터치 없음. 수치 = WorldMapData.guide.
--   Wayfinder.setPoints(owner, points) - owner 문자열마다 경로 하나(나중에 켠 owner가 보인다) · Wayfinder.clear(owner) · Wayfinder.routeToGate(zoneKey) = 허브에서 관문까지 길목 목록.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)

local Wayfinder = {}

local G = WorldMapData.guide
local player = Players.LocalPlayer
local routes = {} -- [owner] = { points, order }
local order = 0
local folder, beam, arrows = nil, nil, {}

local function ensureParts()
	if folder and folder.Parent then
		return
	end
	folder = Instance.new("Folder")
	folder.Name = "WayfinderLocal"
	folder.Parent = Workspace
	local function neon(name, size, color)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = color
		p.Size = size
		p.Transparency = 0.25
		p.Parent = folder
		return p
	end
	beam = neon("GuideBeam", Vector3.new(G.beamWidth, 0.2, 1), Color3.fromRGB(120, 220, 255))
	arrows = {}
	for i = 1, G.arrowsShown do
		local a = Instance.new("WedgePart")
		a.Name = "GuideArrow"
		a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch, a.CastShadow = true, false, false, false, false
		a.Material = Enum.Material.Neon
		a.Color = Color3.fromRGB(255, 230, 120)
		a.Size = Vector3.new(4, 0.6, 5)
		a.Parent = folder
		arrows[i] = a
	end
end

local function current()
	local best, bestOrder = nil, -1
	for owner, r in pairs(routes) do
		if r.order > bestOrder then
			best, bestOrder = r, r.order
			best.owner = owner
		end
	end
	return best
end

function Wayfinder.setPoints(owner, points)
	order += 1
	routes[owner] = { points = points, order = order }
end

function Wayfinder.clear(owner)
	routes[owner] = nil
end

function Wayfinder.activeOwner()
	local r = current()
	return r and r.owner
end

-- 허브 → 관문 길목(WorldMapLayout.route - 허브 끝 · 결계 문 · 캠프 · 사냥 지대 · 관문)
function Wayfinder.routeToGate(zoneKey)
	local zone = WorldMapLayout.zoneByKey(zoneKey)
	if not zone then
		return nil
	end
	local list = {}
	for _, pt in ipairs(WorldMapLayout.route(zone)) do
		table.insert(list, pt.p)
	end
	return list
end

-- 순수: 지금 자리에서 다음 길목 번호(가장 가까운 선분의 끝 - 이미 지난 길목은 건너뛴다)
function Wayfinder.nextIndex(points, position)
	local p = Vector3.new(position.X, 0, position.Z)
	local bestI, bestD = 1, math.huge
	for i = 1, #points do
		local a = Vector3.new(points[i].X, 0, points[i].Z)
		local d = (p - a).Magnitude
		if i > 1 then
			local b = Vector3.new(points[i - 1].X, 0, points[i - 1].Z)
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

local function hideAll()
	if beam then
		beam.Transparency = 1
		for _, a in ipairs(arrows) do
			a.Transparency = 1
		end
	end
end

local function refresh()
	local r = current()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not r or not root or #r.points == 0 then
		hideAll()
		return
	end
	ensureParts()
	local feet = root.Position - Vector3.new(0, 3, 0)
	local pts = r.points
	local i = Wayfinder.nextIndex(pts, feet)
	local target = pts[i]
	local finalP = pts[#pts]
	if (Vector3.new(feet.X - finalP.X, 0, feet.Z - finalP.Z)).Magnitude <= G.arriveStuds then
		hideAll()
		return
	end
	local y = WorldMapData.floorTopY + 0.5
	local from = Vector3.new(feet.X, y, feet.Z)
	local to = Vector3.new(target.X, y, target.Z)
	local len = (to - from).Magnitude
	if len > 0.5 then
		beam.Size = Vector3.new(G.beamWidth, 0.2, len)
		beam.CFrame = CFrame.lookAt((from + to) / 2, to)
		beam.Transparency = 0.25
	else
		beam.Transparency = 1
	end
	-- 화살표: 지금 자리부터 길을 따라 arrowEvery마다
	local path = { from }
	for k = i, #pts do
		table.insert(path, Vector3.new(pts[k].X, y, pts[k].Z))
	end
	local placed, walked, nextAt = 0, 0, G.arrowEvery
	for k = 2, #path do
		local a, b = path[k - 1], path[k]
		local seg = (b - a).Magnitude
		while placed < #arrows and nextAt <= walked + seg do
			local t = (nextAt - walked) / math.max(seg, 1e-6)
			local at = a:Lerp(b, t)
			placed += 1
			-- 쐐기 높은 면(+Z)이 뒤 - 앞(-Z)으로 뾰족하게 누운 화살표
			arrows[placed].CFrame = CFrame.lookAt(at + Vector3.new(0, 0.3, 0), b + Vector3.new(0, 0.3, 0))
			arrows[placed].Transparency = 0.2
			nextAt += G.arrowEvery
		end
		walked += seg
	end
	for k = placed + 1, #arrows do
		arrows[k].Transparency = 1
	end
end

local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed >= G.refreshSeconds then
		elapsed = 0
		refresh()
	end
end)

-- 검사용: 지금 보이는 안내(빛줄기 길이 · 화살표 수 · 경로 owner)
function Wayfinder.debugState()
	local shown = 0
	for _, a in ipairs(arrows) do
		shown += a.Transparency < 1 and 1 or 0
	end
	return { owner = Wayfinder.activeOwner(), beamLength = beam and beam.Transparency < 1 and beam.Size.Z or 0, arrows = shown }
end

return Wayfinder
