-- M1 길 안내(공용 - 보스 관문 · 보스 선택 창 [여기로 안내] · 튜토리얼 · 덩굴 승강기가 같이 쓴다).
-- QUEUE-ALL1 ★0: 지형 · 높이를 따라가는 경로(shared/GuidePath - 길찾기 → 길 합류 · 지면 + groundLift) 위에 가까운 구간만 빛줄기 조각 + 화살표.
--   경로에서 벗어나면(순간이동 · 옆길) 다시 계산(recomputeSeconds 상한) · 목적지 빛기둥 + 거리(지형에 가려도 보이는 표시) · 목적지가 화면 밖이면 가장자리 화살표.
--   로컬 파트만(서버 · 다른 사람에게 안 보인다) · 파티클 없음 · 충돌 · 쿼리 · 터치 없음. 아트 스위치와 무관(길 안내 = 끔에서도). 수치 = WorldMapData.guide.
--   Wayfinder.setPoints(owner, points, opts) - owner 문자열마다 경로 하나(나중에 켠 owner가 보인다) · opts = { label = 빛기둥 글씨, clearOnArrive = 도착하면 지움 }
--   Wayfinder.clear(owner) · Wayfinder.routeToGate(zoneKey) = 허브에서 관문까지 길목 목록.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)
local GuidePath = require(ReplicatedStorage.Shared.GuidePath)

local Wayfinder = {}

local G = WorldMapData.guide
local METERS = WorldMapData.hub.tree.metersPerStud
local player = Players.LocalPlayer
local routes = {} -- [owner] = { points, order, label, clearOnArrive }
local order = 0
-- BR1-4c c-6: 사람이 안내를 껐나(우상단 거리 표시의 [안내 끄기] - 이번 접속 동안만 · 저장은 P4d) · 목적지를 다시 고르면(setPoints) 다시 켜진다.
local hidden = false
local changed = Instance.new("BindableEvent")
Wayfinder.changed = changed.Event
local folder, segments, arrows, beacon, beaconTip = nil, {}, {}, nil, nil
local edgeGui, edgeArrow, edgeLabel = nil, nil, nil

-- 지금 그리는 경로(GuidePath.build 결과) · 어느 경로로 만들었나 · 계산 중 표 · 마지막 계산 시각 · 진행 번호
local built, builtFor, token, lastCompute, cursor = nil, nil, 0, -math.huge, 1
local showJumpHint

local function localPart(name, class)
	local p = Instance.new(class or "Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Transparency = 1
	p.Parent = folder
	return p
end

local function ensureParts()
	if folder and folder.Parent then
		return
	end
	folder = Instance.new("Folder")
	folder.Name = "WayfinderLocal"
	folder.Parent = Workspace
	segments = {}
	for i = 1, G.drawSegments do
		local s = localPart("GuideBeam")
		s.Color = Color3.fromRGB(120, 220, 255)
		s.Size = Vector3.new(G.beamWidth, 0.2, 1)
		segments[i] = s
	end
	-- QUEUE-ALL3 Q11: 노란 쐐기 → 두 겹 꺾쇠 그림(바닥 판 윗면 Decal) · 폰은 개수 상한
	arrows = {}
	local chevronImage = require(script.Parent.ui.ArtImage).get("icons/ui/guide_chevron")
	local count = require(script.Parent.ui.kit.Theme).isMobile and G.chevronsShownPhone or G.chevronsShown
	for i = 1, count do
		local a = localPart("GuideChevron")
		a.Size = Vector3.new(G.chevronSize, 0.05, G.chevronSize)
		local d = Instance.new("Decal")
		d.Name = "Chevron"
		d.Face = Enum.NormalId.Top
		d.Texture = chevronImage or ""
		d.Color3 = Color3.fromRGB(150, 235, 255)
		d.Transparency = 1
		d.Parent = a
		if not chevronImage then -- 그림이 없으면 옛 쐐기 모양을 대신 보이게(빛 판)
			a.Color = Color3.fromRGB(120, 220, 255)
		end
		arrows[i] = a
	end
	local B = G.beacon
	beacon = localPart("GuideBeacon")
	beacon.Shape = Enum.PartType.Cylinder
	beacon.Color = Color3.fromRGB(B.color[1], B.color[2], B.color[3])
	beacon.Size = Vector3.new(B.height, B.width, B.width)
	-- 빛기둥 글씨: 지형에 가려도 보이게(AlwaysOnTop) · 거리 제한 없음
	local anchor = localPart("GuideBeaconTip")
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	local bb = Instance.new("BillboardGui")
	bb.Name = "BeaconLabel"
	bb.AlwaysOnTop = true
	bb.MaxDistance = math.huge
	bb.Size = UDim2.fromOffset(200, 40)
	bb.LightInfluence = 0
	bb.Adornee = anchor
	bb.Parent = anchor
	local text = Instance.new("TextLabel")
	text.Name = "Caption"
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBold
	text.TextSize = 18
	text.TextColor3 = Color3.fromRGB(255, 245, 200)
	text.TextStrokeTransparency = 0.2
	text.Parent = bb
	beaconTip = anchor
end

local function ensureEdge()
	if edgeGui and edgeGui.Parent then
		return
	end
	edgeGui = Instance.new("ScreenGui")
	edgeGui.Name = "WayfinderEdge"
	edgeGui.IgnoreGuiInset = true
	edgeGui.ResetOnSpawn = false
	edgeGui.DisplayOrder = 5
	edgeGui.Parent = player:WaitForChild("PlayerGui")
	local size = G.edgeArrowSize
	-- 화살표 = 돌린 틀 안의 두 막대(^) - 기호 글자(폰트에 없을 수 있음) 대신 도형
	edgeArrow = Instance.new("Frame")
	edgeArrow.Name = "EdgeArrow"
	edgeArrow.AnchorPoint = Vector2.new(0.5, 0.5)
	edgeArrow.Size = UDim2.fromOffset(size, size)
	edgeArrow.BackgroundColor3 = Color3.fromRGB(20, 30, 40)
	edgeArrow.BackgroundTransparency = 0.35
	edgeArrow.Visible = false
	edgeArrow.Parent = edgeGui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = edgeArrow
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(120, 220, 255)
	stroke.Thickness = 2
	stroke.Parent = edgeArrow
	for _, side in ipairs({ -1, 1 }) do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Size = UDim2.fromOffset(size * 0.5, 5)
		bar.Position = UDim2.new(0.5, side * size * 0.15, 0.5, -size * 0.02)
		bar.Rotation = side * 45
		bar.BackgroundColor3 = Color3.fromRGB(255, 230, 120)
		bar.BorderSizePixel = 0
		bar.Parent = edgeArrow
	end
	edgeLabel = Instance.new("TextLabel")
	edgeLabel.Name = "EdgeDistance"
	edgeLabel.AnchorPoint = Vector2.new(0.5, 0)
	edgeLabel.Size = UDim2.fromOffset(80, 18)
	edgeLabel.BackgroundTransparency = 1
	edgeLabel.Font = Enum.Font.GothamBold
	edgeLabel.TextSize = 14
	edgeLabel.TextColor3 = Color3.fromRGB(255, 245, 200)
	edgeLabel.TextStrokeTransparency = 0.2
	edgeLabel.Visible = false
	edgeLabel.Parent = edgeGui
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

function Wayfinder.setPoints(owner, points, opts)
	order += 1
	opts = opts or {}
	routes[owner] = { points = points, order = order, label = opts.label, clearOnArrive = opts.clearOnArrive == true }
	if hidden then
		hidden = false -- 목적지 재선택 = 안내 다시 켜기
		changed:Fire()
	end
end

function Wayfinder.setHidden(value)
	hidden = value == true
	changed:Fire()
end

function Wayfinder.destination()
	local r = current()
	return r and r.points[#r.points] or nil
end

-- 지금 안내의 이름(setPoints opts.label - 목표 표시 글씨)
function Wayfinder.label()
	local r = current()
	return r and r.label
end

function Wayfinder.isHidden()
	return hidden
end

-- 보이는가: 경로가 있고 · 안 껐고 · 보스전 중이 아니다(보스전에 들어가면 끄고 돌아오면 이전 목적지로 다시 보인다 - 경로는 그대로 기억)
function Wayfinder.isShowing()
	return current() ~= nil and not hidden and player:GetAttribute("BossEncounterId") == nil
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
	return require(ReplicatedStorage.Shared.RoadNet).guidePoints(zone) -- M1-4 곡선 길을 따라
end

Wayfinder.nextIndex = GuidePath.nextIndex

local function rayParams()
	local list = { folder }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	return GuidePath.rayParams(list)
end

-- QUEUE-ALL2 P0-3: 고립 꼭대기(사방 절벽 - 안전 내리막 없음)에서는 가장 낮은 낙하 지점에 "여기서 뛰어내려요" 말풍선(접속당 1회 · 짧게) - 고장처럼 보이지 않게
local jumpHintShown = false
function showJumpHint(route)
	local at = not jumpHintShown and route.safeGrid == "relaxed" and GuidePath.worstDropPoint(route)
	if not at then
		return
	end
	jumpHintShown = true
	ensureParts()
	local anchor = localPart("GuideJumpHint")
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(at + Vector3.new(0, 4, 0))
	local bb = Instance.new("BillboardGui")
	bb.AlwaysOnTop = true
	bb.Size = UDim2.fromOffset(190, 36)
	bb.LightInfluence = 0
	bb.Adornee = anchor
	bb.Parent = anchor
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundColor3 = Color3.fromRGB(20, 30, 40)
	text.BackgroundTransparency = 0.25
	text.Font = Enum.Font.GothamBold
	text.TextSize = 16
	text.TextColor3 = Color3.fromRGB(255, 245, 200)
	text.Text = require(ReplicatedStorage.Shared.Text).get("guide.jumpHere")
	text.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = text
	task.delay(G.jumpHintSeconds or 5, function()
		anchor:Destroy()
	end)
end

local function recompute(r, feet)
	token += 1
	local mine = token
	lastCompute = os.clock()
	builtFor = r
	task.spawn(function()
		local route = GuidePath.build(feet, r.points, rayParams(), G.groundNear)
		if mine == token then
			built, cursor = route, 1
			showJumpHint(route)
		end
	end)
end

local function hideAll()
	for _, s in ipairs(segments) do
		s.Transparency = 1
	end
	for _, a in ipairs(arrows) do
		a.Transparency = 1
		if a:FindFirstChild("Chevron") then
			a.Chevron.Transparency = 1
		end
	end
	if beacon then
		beacon.Transparency = 1
		beaconTip.BeaconLabel.Enabled = false
	end
	if edgeArrow then
		edgeArrow.Visible = false
		edgeLabel.Visible = false
	end
end

-- 진행 번호: 지난 번호 근처에서 발과 가장 가까운 점(수평) - 되돌아가도 따라간다
local function nearest(route, feet)
	local pts = route.points
	local lo, hi = math.max(1, cursor - 30), math.min(#pts, cursor + 120)
	local bestI, bestD = cursor, math.huge
	for i = lo, hi do
		local d = (Vector3.new(pts[i].X - feet.X, (pts[i].Y - feet.Y) * 0.5, pts[i].Z - feet.Z)).Magnitude
		if d < bestD then
			bestI, bestD = i, d
		end
	end
	return bestI, bestD
end

local function refresh()
	local r = current()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not r or not root or #r.points == 0 or not Wayfinder.isShowing() then
		hideAll()
		return
	end
	ensureParts()
	ensureEdge()
	local feet = root.Position - Vector3.new(0, 3, 0)
	local finalP = r.points[#r.points]
	if (Vector3.new(feet.X - finalP.X, 0, feet.Z - finalP.Z)).Magnitude <= G.arriveStuds then
		hideAll()
		if r.clearOnArrive then
			routes[r.owner] = nil
		end
		return
	end
	if builtFor ~= r then
		built = nil
		recompute(r, feet)
	end
	-- 빛기둥: 목적지(길 점 높이) 위로 · 글씨 = 이름 · 거리
	local B = G.beacon
	beacon.CFrame = CFrame.new(finalP + Vector3.new(0, B.height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	beacon.Transparency = 0.55
	beaconTip.CFrame = CFrame.new(finalP + Vector3.new(0, B.billboardStuds, 0))
	local meters = math.floor((Vector3.new(finalP.X - feet.X, 0, finalP.Z - feet.Z)).Magnitude * METERS + 0.5)
	local label = beaconTip.BeaconLabel
	label.Enabled = true
	label.Caption.Text = r.label and ("%s · %dm"):format(require(ReplicatedStorage.Shared.Text).name(r.label), meters) or ("%dm"):format(meters)
	edgeLabel.Text = ("%dm"):format(meters)
	if not built then
		for _, s in ipairs(segments) do
			s.Transparency = 1
		end
		for _, a in ipairs(arrows) do
			a.Transparency = 1
		end
		return
	end
	local i, off = nearest(built, feet)
	cursor = i
	if off > G.offPathStuds and os.clock() - lastCompute >= G.recomputeSeconds then
		recompute(r, feet)
	end
	-- 빛줄기: 진행 번호부터 drawStuds까지(지면 못 읽은 점은 지금 다시 읽는다)
	--   새로 읽은 점이 있으면 그 구간에 꺾은 선 · 가운데 점 처리(GuidePath.liftRange - 서버 검사와 같은 규칙)
	local params = rayParams()
	local hi = math.min(#built.points, i + #segments + 1)
	local fresh = false
	for k = i, hi do
		if not built.ok[k] then
			fresh = GuidePath.ground(built, k, params) or fresh
		end
	end
	if fresh then
		GuidePath.liftRange(built, params, i, hi)
		GuidePath.liftRange(built, params, i, hi + #segments)
	end
	local pts = built.points
	-- QUEUE-ALL3 Q11: 꺾쇠 = 발밑부터 chevronEvery 간격 · 흐름(시간 위상) · 빛줄기 = 꺾쇠를 잇는 얇은 청록 선 · 모퉁이 = 꺾쇠가 다음 조각 방향을 본다
	local phase = (os.clock() * G.chevronFlow) % G.chevronEvery
	local used, walked, placed, nextAt = 0, 0, 0, phase
	local lift = Vector3.new(0, G.chevronLift, 0)
	for k = i + 1, #pts do
		if used >= #segments or walked >= G.drawStuds then
			break
		end
		local a, b = pts[k - 1], pts[k]
		local len = (b - a).Magnitude
		if len > 0.05 and not GuidePath.segmentVisible(a, b, params) then
			while nextAt <= walked + len do -- 묻힌 조각(기둥 속 · 아치 아래) = 안 그림 · 그 자리 꺾쇠도 건너뜀
				nextAt += G.chevronEvery
			end
		elseif len > 0.05 then
			used += 1
			local s = segments[used]
			s.Size = Vector3.new(G.beamWidth, 0.12, len)
			s.CFrame = CFrame.lookAt((a + b) / 2 + lift * 0.5, b + lift * 0.5)
			s.Transparency = 0.35 + 0.55 * (walked / G.drawStuds)
			while placed < #arrows and nextAt <= walked + len and nextAt <= G.drawStuds do
				local at = a:Lerp(b, (nextAt - walked) / len)
				placed += 1
				local c = arrows[placed]
				-- 판 윗면(+Y)이 지면 경사를 따라 눕고 -Z(그림 위쪽 = 꺾쇠 끝)가 가는 방향
				c.CFrame = CFrame.lookAt(at + lift, b + lift)
				local fade = nextAt / G.drawStuds
				if c:FindFirstChild("Chevron") and c.Chevron.Texture ~= "" then
					c.Transparency = 1
					c.Chevron.Transparency = 0.05 + 0.75 * fade
				else
					c.Transparency = 0.2 + 0.6 * fade
				end
				nextAt += G.chevronEvery
			end
		end
		walked += len
	end
	for k = used + 1, #segments do
		segments[k].Transparency = 1
	end
	for k = placed + 1, #arrows do
		arrows[k].Transparency = 1
		if arrows[k]:FindFirstChild("Chevron") then
			arrows[k].Chevron.Transparency = 1
		end
	end
end

-- 가장자리 화살표: 목적지 빛기둥 글씨 자리가 안쪽 사각형(edgeInset) 밖(또는 뒤)이면 그 사각형 테두리에서 그쪽을 가리킨다
local function updateEdge()
	if not edgeArrow then
		return
	end
	local r = current()
	local camera = Workspace.CurrentCamera
	if not r or not camera or not Wayfinder.isShowing() or not beaconTip or not beaconTip.BeaconLabel.Enabled then
		edgeArrow.Visible, edgeLabel.Visible = false, false
		return
	end
	local vp = camera:WorldToViewportPoint(beaconTip.Position)
	local size = camera.ViewportSize
	local I = G.edgeInset
	local x0, x1, y0, y1 = size.X * I.left, size.X * (1 - I.right), size.Y * I.top, size.Y * (1 - I.bottom)
	local inside = vp.Z > 0 and vp.X >= x0 and vp.X <= x1 and vp.Y >= y0 and vp.Y <= y1
	if inside then
		edgeArrow.Visible, edgeLabel.Visible = false, false
		return
	end
	local center = Vector2.new((x0 + x1) / 2, (y0 + y1) / 2)
	local dir = Vector2.new(vp.X, vp.Y) - center
	if vp.Z < 0 then
		dir = -dir
	end
	if dir.Magnitude < 1e-3 then
		dir = Vector2.new(0, -1)
	end
	local k = math.min(((x1 - x0) / 2) / math.max(math.abs(dir.X), 1e-6), ((y1 - y0) / 2) / math.max(math.abs(dir.Y), 1e-6))
	local at = center + dir * k
	edgeArrow.Position = UDim2.fromOffset(at.X, at.Y)
	edgeArrow.Rotation = math.deg(math.atan2(dir.Y, dir.X)) + 90
	edgeLabel.Position = UDim2.fromOffset(at.X, at.Y + G.edgeArrowSize / 2 + 2)
	edgeArrow.Visible, edgeLabel.Visible = true, true
end

-- 검사 훅: 클라 execute_luau에서 LocalPlayer:SetAttribute("GuideDebugZone", "tier3") → 그 구역 관문까지 안내(nil = 지움). 로컬 Attribute라 서버 · 남에게 안 간다.
player:GetAttributeChangedSignal("GuideDebugZone"):Connect(function()
	local key = player:GetAttribute("GuideDebugZone")
	local route = key and Wayfinder.routeToGate(key)
	if route then
		Wayfinder.setPoints("debug", route, { label = key .. " 관문" })
	else
		Wayfinder.clear("debug")
	end
end)

-- 검사 훅 2(자동 이동 도착률): GuideDebugPoints = "x,y,z;x,y,z;…"(서버가 복제 Attribute로 준다) → 그 점 목록으로 안내(빈 문자열 = 지움)
player:GetAttributeChangedSignal("GuideDebugPoints"):Connect(function()
	local text = player:GetAttribute("GuideDebugPoints")
	local pts = {}
	for x, y, z in string.gmatch(text or "", "([%-%d%.]+),([%-%d%.]+),([%-%d%.]+)") do
		table.insert(pts, Vector3.new(tonumber(x), tonumber(y), tonumber(z)))
	end
	if #pts > 0 then
		Wayfinder.setPoints("debug", pts, { label = "검사" })
	else
		Wayfinder.clear("debug")
	end
end)

local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed >= G.refreshSeconds then
		elapsed = 0
		refresh()
	end
end)
RunService.RenderStepped:Connect(updateEdge)

-- 자동 이동(client/AutoWalk)이 같은 경로를 따라간다: 지금 경로(GuidePath.build 결과) · 진행 번호 · owner. 경로가 아직 없으면 nil.
function Wayfinder.route()
	local r = current()
	if not r or builtFor ~= r or not built or not Wayfinder.isShowing() then
		return nil
	end
	return built, cursor, r.owner
end

-- 끼임 대책: 지금 자리에서 경로를 새로 계산(상한 없이 - AutoWalk가 횟수를 센다)
function Wayfinder.recomputeNow()
	local r = current()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if r and root then
		recompute(r, root.Position - Vector3.new(0, 3, 0))
	end
end

-- 검사용: 지금 보이는 안내(빛줄기 조각 · 화살표 수 · 경로 owner · 길찾기 성공 · 그린 구간의 지면 최소 여유 · 파고든 점 수)
function Wayfinder.debugState()
	local shown, beams = 0, 0
	for _, a in ipairs(arrows) do
		shown += a.Transparency < 1 and 1 or 0
	end
	for _, s in ipairs(segments) do
		beams += s.Transparency < 1 and 1 or 0
	end
	local minGap, under = nil, nil
	if built and folder then
		minGap, under = GuidePath.clearance(built, rayParams(), cursor, cursor + beams + 1)
	end
	return {
		owner = Wayfinder.activeOwner(),
		segments = beams,
		arrows = shown,
		pathfound = built and built.pathfound,
		points = built and #built.points or 0,
		minGap = minGap,
		under = under,
		beacon = beacon ~= nil and beacon.Transparency < 1,
		edgeArrow = edgeArrow ~= nil and edgeArrow.Visible,
	}
end

return Wayfinder
