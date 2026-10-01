-- 미니맵(QUEUE-ALL3 Q4 · 10 문서 4절). 화면 오른쪽 위 작은 원형 - 자리 = ScreenMap TR.minimap(칩 스택 아래 · 폰은 칩 스택 왼쪽 열 옆 - place()).
--   그림 = 전체 지도(panels/WorldMapPanel)와 같은 세계 → 지도 식 · 같은 도형 지도(세계 원 · 6구역 원 · 허브 원 · 안 가 본 구역 흐리게)를 세계 전체 크기 캔버스로
--   한 번 그려 두고, 둥근 사각형 자르는 칸(ClipsDescendants) 안에서 캔버스만 옮겨 내가 가운데 오게 한다(3D 다시 그리기 · ViewportFrame 없음). 북쪽 위 고정 · 내 화살표만 돈다.
--   표시 = 나(화살표) · 파티원(파티원 색 점 - PartyColors) · 길 안내 목적지(Wayfinder - 별 · 밖이면 테두리에 붙음) · 허브 · 대장간 · 관문(열린 · 들른 구역) ·
--   발견한 체크포인트(CheckpointsFound) · 내 지도 핀(MapPins). 둥지 · 탐험 지점은 안 그린다(전체 지도와 같은 규칙).
--   보스 아레나(BossEncounterId)에서 숨김. 누르면 전체 지도(worldMap). 갱신 = updateHz(10 Hz) - 캔버스 위치 · 화살표 · 파티원 · 목적지만, 정적 아이콘은 바뀔 때만 다시 짓는다.
--   드랍 피드(Toast TR)는 투명 칸 MinimapFeedAnchor(ScreenMap TR.minimapColumn) 아래에 놓인다 - 미니맵이 칩 스택 아래에 있으면 그 칸이 미니맵 아래 끝까지 늘어난다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local ScreenMap = require(script.Parent.Parent.ui.ScreenMap)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local ArtImage = require(script.Parent.Parent.ui.ArtImage)
local UIManager = require(script.Parent.Parent.UIManager)
local MapPins = require(script.Parent.Parent.MapPins)
local Wayfinder = require(script.Parent.Parent.Wayfinder)
local PartyColors = require(script.Parent.Parent.PartyColors)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local D = WorldMapData
local MM = D.map.minimap
local EDGE = D.edge.radius
-- 자리를 피해야 하는 칩 스택 왼쪽 열 · 위 줄 HUD(보일 때만)
local NEIGHBORS = { "TravelHubButton", "TravelBackButton", "TravelPartyButton", "RegionLabel" }

local gui = Instance.new("ScreenGui")
gui.Name = "MinimapGui"
gui.ResetOnSpawn = false
gui.Parent = playerGui

-- 드랍 피드 기준 칸(투명). 칩 스택을 찾기 전에도 칩 스택 기본 자리를 덮게 먼저 만든다(FeedLayout이 이 칸을 못 찾으면 피드가 칩 스택 위 끝에 놓인다).
local feedAnchor = Instance.new("Frame")
feedAnchor.Name = "MinimapFeedAnchor"
feedAnchor.BackgroundTransparency = 1
feedAnchor.AnchorPoint = Vector2.new(1, 0)
feedAnchor.Position = UDim2.new(1, -ScreenMap.edgeMargin, 0, 52)
feedAnchor.Size = UDim2.fromOffset(80, 180)
feedAnchor.Parent = gui

local refs
local size = 0 -- 지금 미니맵 한 변(px)
local visited = {} -- [zoneKey] = true(이번 접속에 들른 구역 - 전체 지도와 같은 규칙)

local function toMap(position)
	return Vector2.new((position.X + EDGE) / (2 * EDGE), (position.Z + EDGE) / (2 * EDGE))
end

local function zoneBright(zone, index)
	return index <= (player:GetAttribute("ZonesUnlocked") or D.progress.startUnlocked) or visited[zone.key] == true
end

local function circle(parent, name, color, center, radiusRatio)
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(center.X, center.Y)
	f.Size = UDim2.fromScale(radiusRatio * 2, radiusRatio * 2)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Parent = parent
	Theme.corner(f, 9999)
	return f
end

-- 아이콘 하나(이미지가 아직 없으면 색 점). parent = 캔버스(비율 자리) 또는 겉 칸(px 자리)
local function icon(parent, iconName, px, fallbackColor)
	local img = ArtImage.get("icons/ui/" .. iconName)
	local inst
	if img then
		inst = Instance.new("ImageLabel")
		inst.Image = img
		inst.ScaleType = Enum.ScaleType.Fit
		inst.BackgroundTransparency = 1
	else
		inst = Instance.new("Frame")
		inst.BackgroundColor3 = fallbackColor
		Theme.corner(inst, 9999)
	end
	inst.Name = "Icon_" .. iconName
	inst.AnchorPoint = Vector2.new(0.5, 0.5)
	inst.Size = UDim2.fromOffset(px, px)
	inst.BorderSizePixel = 0
	inst.ZIndex = 5
	inst.Parent = parent
	return inst
end

local function iconPx()
	return Theme.isMobile and MM.iconPhone or MM.icon
end

-- 정적 아이콘: 허브 · 대장간 · 관문 · 발견한 체크포인트 · 핀(캔버스 비율 자리 - 캔버스와 같이 움직인다)
local function renderMarkers()
	if not refs then
		return
	end
	refs.markers:ClearAllChildren()
	local px = iconPx()
	local function put(iconName, position, color)
		local r = toMap(position)
		icon(refs.markers, iconName, px, color).Position = UDim2.fromScale(r.X, r.Y)
	end
	put("pin_hub", Vector3.new(0, D.floorTopY, 0), Theme.color("gold"))
	put("pin_forge", WorldMapLayout.facility("forge"), Theme.color("gold"))
	for index, zone in ipairs(D.zones) do
		local bright = zoneBright(zone, index)
		if bright then
			put("pin_gate", WorldMapLayout.gate(zone), Color3.fromRGB(230, 90, 90))
		end
		local disc = refs.zoneDiscs[index]
		disc.BackgroundTransparency = bright and 0 or 0.55
	end
	local found = player:GetAttribute("CheckpointsFound")
	if D.checkpoints and type(found) == "string" and found ~= "" then
		for _, cp in ipairs(D.checkpoints.list) do
			if string.find("," .. found .. ",", "," .. cp.id .. ",", 1, true) then
				local pos = cp.hub and WorldMapLayout.spawnPoint() or WorldMapLayout.camp(WorldMapLayout.zoneByKey(cp.zone))
				put("pin_checkpoint", pos, Theme.color("success"))
			end
		end
	end
	for _, pin in ipairs(MapPins.list()) do
		put("pin_user", pin.position, Color3.fromRGB(176, 120, 255))
	end
end

-- QUEUE-ALL6 L 정적 상세 지도(캔버스 비율 자리 - 캔버스와 같이 움직인다 · 갱신 없음): 길(RoadNet 본길 · 갈림길) · 물(폭포 · 만) · 랜드마크(탐험 지형 · 구역 상징) ·
--   세부 지역 경계(구역 축에 수직인 줄) · 세부 지역 이름(WorldMapData.subAreas - 글씨 12 · 외곽선). 판정과 무관한 그림만.
local buildDetail
local function segment(parent, a, b, px, color, transparency)
	local pa, pb = toMap(a), toMap(b)
	local mid, d = (pa + pb) / 2, pb - pa
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(mid.X, mid.Y)
	f.Size = UDim2.new(d.Magnitude, 0, 0, px)
	f.Rotation = math.deg(math.atan2(d.Y, d.X))
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency or 0
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end
buildDetail = function(canvas)
	local RoadNet = require(ReplicatedStorage.Shared.RoadNet)
	local Text = require(ReplicatedStorage.Shared.Text)
	local detail = Instance.new("Frame")
	detail.Name = "Detail"
	detail.BackgroundTransparency = 1
	detail.Size = UDim2.fromScale(1, 1)
	detail.ZIndex = 2
	detail.Parent = canvas
	local ROAD, WATER, LINE, MARK = Color3.fromRGB(214, 196, 150), Color3.fromRGB(72, 142, 204), Color3.fromRGB(235, 240, 245), Color3.fromRGB(70, 74, 84)
	local SA = D.subAreas
	for _, zone in ipairs(D.zones) do
		-- 길(본길 · 갈림길) - 약 60 stud마다 한 조각
		for _, path in ipairs({ RoadNet.zonePath(zone), RoadNet.branchPath(zone) }) do
			local last
			for _, q in ipairs(path and path.pts or {}) do
				local p = Vector3.new(q.x, 0, q.z)
				if not last then
					last = p
				elseif (p - last).Magnitude >= 60 then
					segment(detail, last, p, 2, ROAD).Name = "Road"
					last = p
				end
			end
		end
		-- 물: 폭포 지형 · 물 관문(만)
		for _, f in ipairs(zone.features or {}) do
			local at = WorldMapLayout.toWorld(zone, f.r, f.lat)
			if f.kind == "falls" then
				circle(detail, "Water", WATER, toMap(at), 45 / (2 * EDGE))
			elseif f.explore then
				circle(detail, "Landmark", MARK, toMap(at), 22 / (2 * EDGE)) -- 탐험 지형(탑 · 굴 · 언덕)
			end
		end
		local site = D.layout.gateSites and D.layout.gateSites[zone.key]
		if site and site.water then
			circle(detail, "Water", WATER, toMap(WorldMapLayout.toWorld(zone, site.r, 0)), 140 / (2 * EDGE))
		end
		-- 세부 지역 경계(구역 원 안 현) · 이름
		local R, C = D.layout.regionRadius, D.layout.regionCenterR
		for _, edgeR in ipairs(SA.bandsR) do
			local half = math.sqrt(math.max(0, R * R - (edgeR - C) ^ 2))
			segment(detail, WorldMapLayout.toWorld(zone, edgeR, -half), WorldMapLayout.toWorld(zone, edgeR, half), 1, LINE, 0.55).Name = "AreaEdge"
		end
		for index, name in ipairs(SA.names[zone.key]) do
			local c = toMap(WorldMapLayout.subAreaCenter(zone, index))
			local label = Instance.new("TextLabel")
			label.Name = "AreaName"
			label.AnchorPoint = Vector2.new(0.5, 0.5)
			label.Position = UDim2.fromScale(c.X, c.Y)
			label.Size = UDim2.fromOffset(120, 14)
			label.BackgroundTransparency = 1
			label.Font = Theme.font
			label.TextSize = 12
			label.TextColor3 = Color3.new(1, 1, 1)
			label.TextStrokeTransparency = 0.3
			label.Text = Text.name(name)
			label.ZIndex = 3
			label.Parent = detail
		end
	end
end

local function build()
	local root = Instance.new("TextButton")
	root.Name = "Minimap"
	root.Text = ""
	root.AutoButtonColor = false
	root.BackgroundTransparency = 1
	root.Visible = false
	root.Parent = gui

	-- 둥근 사각형 칸 + ClipsDescendants(사각형 자름). CanvasGroup(원형 자름)은 대체 경로로 떨어지면 아예 안 잘려 세계 원이 화면 반을 덮었다(Studio Play 실측 - GPU 여유가 없는 폰도 같은 경로)
	local clip = Instance.new("Frame")
	clip.Name = "Clip"
	clip.Size = UDim2.fromScale(1, 1)
	clip.BackgroundColor3 = Color3.fromRGB(24, 30, 44)
	clip.BorderSizePixel = 0
	clip.ClipsDescendants = true
	clip.Parent = root
	Theme.corner(clip, MM.corner)

	local canvas = Instance.new("Frame")
	canvas.Name = "Canvas"
	canvas.BackgroundTransparency = 1
	canvas.Parent = clip
	-- 바탕(전체 지도 drawVectorMap과 같은 도형 · 같은 색 - 구역 이름 글씨만 뺐다)
	circle(canvas, "World", Color3.fromRGB(46, 70, 92), Vector2.new(0.5, 0.5), 0.5)
	local zoneDiscs = {}
	for index, zone in ipairs(D.zones) do
		local tint = zone.floorTint or { 140, 150, 140 }
		local color = Color3.fromRGB(tint[1], tint[2], tint[3]):Lerp(Color3.fromRGB(96, 160, 90), 0.35)
		zoneDiscs[index] = circle(canvas, "Zone_" .. zone.key, color, toMap(WorldMapLayout.regionCenter(zone)), D.layout.regionRadius / (2 * EDGE))
	end
	circle(canvas, "Hub", Color3.fromRGB(120, 190, 100), Vector2.new(0.5, 0.5), D.hub.safeRadius / (2 * EDGE))
	buildDetail(canvas) -- QUEUE-ALL6 L: 길 · 물 · 랜드마크 · 세부 지역 경계 · 이름(정적 - 한 번만 짓는다)
	local markers = Instance.new("Frame")
	markers.Name = "Markers"
	markers.BackgroundTransparency = 1
	markers.Size = UDim2.fromScale(1, 1)
	markers.ZIndex = 4
	markers.Parent = canvas

	-- 움직이는 것(겉 칸 px 자리): 파티원 점 · 목적지 별 · 내 화살표(가운데 고정)
	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.BackgroundTransparency = 1
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 6
	overlay.Parent = clip
	local quest = icon(overlay, "pin_quest", iconPx() + 2, Theme.color("gold"))
	quest.Name = "QuestMark"
	quest.ZIndex = 7
	quest.Visible = false
	local me = Instance.new("Frame")
	me.Name = "Me"
	me.AnchorPoint = Vector2.new(0.5, 0.5)
	me.Position = UDim2.fromScale(0.5, 0.5)
	me.BackgroundTransparency = 1
	me.ZIndex = 8
	me.Parent = overlay
	ArtImage.label(me, "icons/ui/pin_player", UDim2.fromScale(1, 1), "▲").ZIndex = 8

	-- 테두리(자르는 칸 밖 - 잘리지 않게)
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.BackgroundTransparency = 1
	ring.Size = UDim2.fromScale(1, 1)
	ring.ZIndex = 9
	ring.Parent = root
	Theme.corner(ring, MM.corner)
	local stroke = Instance.new("UIStroke")
	stroke.Color = UIColors.rim
	stroke.Thickness = 2
	stroke.Parent = ring

	root.Activated:Connect(function()
		UIManager.openLazy("worldMap")
	end)
	refs = { root = root, canvas = canvas, markers = markers, zoneDiscs = zoneDiscs, overlay = overlay, quest = quest, me = me, dots = {} }
end

-- ═══ 자리 ═══
local cache, missedAt = {}, {}
local function find(name)
	local inst = cache[name]
	if inst and inst.Parent then
		return inst
	end
	if missedAt[name] and os.clock() - missedAt[name] < 2 then
		return nil -- 못 찾은 이름은 2초마다만 다시 찾는다(PlayerGui 전체 재귀 검색을 10 Hz로 돌리지 않게)
	end
	inst = playerGui:FindFirstChild(name, true)
	cache[name] = inst
	missedAt[name] = not inst and os.clock() or nil
	return inst
end

local function shownRect(name)
	local inst = find(name)
	if not inst or inst.AbsoluteSize.X <= 0 or inst.AbsoluteSize.Y <= 0 then
		return nil
	end
	local node = inst
	while node and node ~= playerGui do
		if (node:IsA("GuiObject") and not node.Visible) or (node:IsA("ScreenGui") and not node.Enabled) then
			return nil
		end
		node = node.Parent
	end
	return { min = inst.AbsolutePosition, max = inst.AbsolutePosition + inst.AbsoluteSize }
end

local function hits(a, b)
	return a.min.X < b.max.X and b.min.X < a.max.X and a.min.Y < b.max.Y and b.min.Y < a.max.Y
end

local function square(x, y, s)
	return { min = Vector2.new(x, y), max = Vector2.new(x + s, y + s) }
end

-- 반환: mode("below" = 칩 스택 아래 · "side" = 칩 스택 왼쪽 열 옆 · nil = 둘 다 안 됨), 자리(rect), 칩 스택 rect
local function place()
	local chips = shownRect("TopChipsRow")
	if not chips then
		return nil
	end
	local screen = gui.AbsoluteSize
	local blockers = { ScreenMap.centerRect(screen), chips }
	if Theme.isMobile then
		for _, fractions in pairs(ScreenMap.mobileReserved) do
			table.insert(blockers, ScreenMap.rectFromFractions(fractions, screen))
		end
	end
	local near = {}
	for _, name in ipairs(NEIGHBORS) do
		local r = shownRect(name)
		if r then
			table.insert(blockers, r)
			table.insert(near, r)
		end
	end
	local function fits(r)
		if r.min.X < 0 or r.min.Y < 0 or r.max.X > screen.X or r.max.Y > screen.Y then
			return false
		end
		for _, b in ipairs(blockers) do
			if hits(r, b) then
				return false
			end
		end
		return true
	end
	local want = Theme.isMobile and MM.phone or MM.pc
	for s = want, MM.minSize, -MM.sizeStep do
		local r = square(chips.max.X - s, chips.max.Y + MM.gap, s)
		if fits(r) then
			return "below", r, chips
		end
	end
	for s = want, MM.minSize, -MM.sizeStep do
		local right = chips.min.X -- 이 크기의 세로 띠(칩 스택 위 끝 ~ + s)에 걸리는 왼쪽 열 버튼들의 왼쪽 끝
		for _, n in ipairs(near) do
			if n.min.Y < chips.min.Y + s and n.max.Y > chips.min.Y then
				right = math.min(right, n.min.X)
			end
		end
		local r = square(right - MM.gap - s, chips.min.Y, s)
		if fits(r) then
			return "side", r, chips
		end
	end
	return nil, nil, chips
end

local function applyPlace()
	local mode, r, chips = place()
	if chips then
		local top = chips.min
		local bottomRight = chips.max
		if mode == "below" then
			top = Vector2.new(math.min(chips.min.X, r.min.X), chips.min.Y)
			bottomRight = Vector2.new(math.max(chips.max.X, r.max.X), r.max.Y)
		end
		feedAnchor.AnchorPoint = Vector2.zero
		feedAnchor.Position = UDim2.fromOffset(top.X, top.Y)
		feedAnchor.Size = UDim2.fromOffset(bottomRight.X - top.X, bottomRight.Y - top.Y)
	end
	if not mode then
		return false
	end
	local s = r.max.X - r.min.X
	refs.root.Position = UDim2.fromOffset(r.min.X, r.min.Y)
	if s ~= size then
		size = s
		refs.root.Size = UDim2.fromOffset(s, s)
		local side = EDGE * s / MM.rangeStuds -- 세계 지름(2 × EDGE)을 2 × rangeStuds = s px로
		refs.canvas.Size = UDim2.fromOffset(side, side)
		local arrow = iconPx() + 4
		refs.me.Size = UDim2.fromOffset(arrow, arrow)
	end
	return true
end

-- ═══ 10 Hz 갱신 ═══
-- 가운데에서 offset(px)만큼 떨어진 점 - 원 밖이면 테두리 안쪽에 붙인다
local function rimClamp(offset, margin)
	local limit = size / 2 - margin
	if offset.Magnitude > limit then
		return offset.Unit * limit, true
	end
	return offset, false
end

local function updateDynamic(root)
	local me = root.Position
	local ppu = size / (2 * MM.rangeStuds)
	local r = toMap(me)
	local side = EDGE * size / MM.rangeStuds
	refs.canvas.Position = UDim2.fromOffset(size / 2 - r.X * side, size / 2 - r.Y * side)
	local look = root.CFrame.LookVector
	refs.me.Rotation = math.deg(math.atan2(look.X, -look.Z))
	-- 목적지
	local dest = Wayfinder.isShowing() and Wayfinder.destination()
	if typeof(dest) == "Vector3" then
		local offset = rimClamp(Vector2.new(dest.X - me.X, dest.Z - me.Z) * ppu, iconPx() / 2 + 2)
		refs.quest.Position = UDim2.fromOffset(size / 2 + offset.X, size / 2 + offset.Y)
		refs.quest.Visible = true
	else
		refs.quest.Visible = false
	end
	-- 파티원(같은 PartyId - 파티원 색 · 밖이면 테두리)
	local dotPx = Theme.isMobile and MM.dotPhone or MM.dot
	local seen = {}
	for _, other in ipairs(Players:GetPlayers()) do
		local otherRoot = other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		local color = otherRoot and PartyColors.of(other)
		if color then
			seen[other] = true
			local dot = refs.dots[other]
			if not dot then
				dot = Instance.new("Frame")
				dot.Name = "PartyDot"
				dot.AnchorPoint = Vector2.new(0.5, 0.5)
				dot.ZIndex = 7
				dot.Parent = refs.overlay
				Theme.corner(dot, 9999)
				local st = Instance.new("UIStroke")
				st.Color = Color3.new(1, 1, 1)
				st.Thickness = 1
				st.Parent = dot
				refs.dots[other] = dot
			end
			local p = otherRoot.Position
			local offset = rimClamp(Vector2.new(p.X - me.X, p.Z - me.Z) * ppu, dotPx / 2 + 1)
			dot.Size = UDim2.fromOffset(dotPx, dotPx)
			dot.BackgroundColor3 = color
			dot.Position = UDim2.fromOffset(size / 2 + offset.X, size / 2 + offset.Y)
		end
	end
	for other, dot in pairs(refs.dots) do
		if not seen[other] then
			dot:Destroy()
			refs.dots[other] = nil
		end
	end
end

build()
renderMarkers()
MapPins.changed:Connect(renderMarkers)
for _, name in ipairs({ "ZonesUnlocked", "CheckpointsFound" }) do
	player:GetAttributeChangedSignal(name):Connect(renderMarkers)
end
player:GetAttributeChangedSignal("ForceTouchLayout"):Connect(function()
	Theme.recompute()
	size = 0 -- 폰 · PC 크기 · 아이콘 크기 다시
	renderMarkers()
end)

local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < 1 / MM.updateHz then
		return
	end
	elapsed = 0
	local placed = applyPlace()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local show = placed and root ~= nil and player:GetAttribute("BossEncounterId") == nil
	refs.root.Visible = show
	if not show then
		return
	end
	local zone = WorldMapLayout.zoneAt(root.Position)
	if zone and not visited[zone.key] then
		visited[zone.key] = true
		renderMarkers()
	end
	updateDynamic(root)
end)
