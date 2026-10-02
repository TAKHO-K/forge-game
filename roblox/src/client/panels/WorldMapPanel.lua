-- 전체 지도(QUEUE-ALL3 Q4 · 10 문서 4절 · 09 문서 B-3 M). 단축키 M · 왼쪽 메뉴 상시 칸(PanelRegistry "worldMap").
--   그림 = 위에서 본 지도 PNG(icons 경로 WorldMapData.map.image - 업로드 뒤) 위에 아이콘 · 없으면 지형 데이터로 그린다(허브 원 · 6구역 원 · 길목 점).
--   표시 = 발견한 장소만: 허브 시설 · 구역 캠프 · 사냥 지대 · 관문 · 체크포인트(발견한 것 - Player Attribute CheckpointsFound). 둥지 · 탐험 지점은 그리지 않는다(위치 누설 금지).
--   한 번도 안 가 본 구역(열린 구역 수 ZonesUnlocked 밖 · 이번 접속에 안 들른 곳) = 흐리게. 확대/축소(휠 · [+][−]) · 끌기 · 핀(빈 곳 누르기 = 핀 · 다시 누르면 지움 · 최대 3).
--   고른 장소 · 핀 → [자동 이동](AutoWalk - 핀 · 장소 허용) · [길 안내](안내선만) · 체크포인트면 [순간이동](정신 집중 3초 · 편도 - 서버 Travel "checkpoint" · 스위치 CheckpointTeleport).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)
local Text = require(ReplicatedStorage.Shared.Text)
local Panel = require(script.Parent.Parent.ui.kit.Panel)
local Button = require(script.Parent.Parent.ui.kit.Button)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local ArtImage = require(script.Parent.Parent.ui.ArtImage)
local UIManager = require(script.Parent.Parent.UIManager)
local MapPins = require(script.Parent.Parent.MapPins)
local MapImageData = require(ReplicatedStorage.Shared.data.MapImageData)
local Toggle = require(script.Parent.Parent.ui.kit.Toggle)
local SettingSave = require(script.Parent.Parent.ui.SettingSave)
local HubPlaces = require(script.Parent.Parent.HubPlaces)
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")

local WorldMapPanel = {}
WorldMapPanel.id = "worldMap"

local player = Players.LocalPlayer
local D = WorldMapData
local MAP = D.map
local PANEL_SIZE = Vector2.new(720, 480)
local SIDE_W = 210
local EDGE = D.edge.radius -- 세계 반경(지도 한 변 = 2 × EDGE)

local built
local zoom, offset = 1, Vector2.zero -- 확대 배율 · 지도 가운데 이동(px)
local selected -- { kind, name, position, checkpointId }
local visited = {} -- [zoneKey] = true(이번 접속에 들른 구역)

-- 월드 X · Z → 지도 캔버스 비율(0 ~ 1) · 위 = −Z(석조 평원 쪽) - QUEUE-ALL7 D2 공통 식(MapImageData 한 곳 - 미니맵 · 핀 · 굽기와 같다)
local function toMap(position)
	return MapImageData.toUV(position.X, position.Z)
end
local function toWorld(ratio)
	return MapImageData.toWorld(ratio.X, ratio.Y, D.floorTopY)
end

local function zoneBright(zone, index)
	return index <= (player:GetAttribute("ZonesUnlocked") or D.progress.startUnlocked) or visited[zone.key] == true
end

-- 장소 목록(발견한 것만)
local function places()
	local list = {
		{ kind = "hub", icon = "pin_hub", name = Text.get("map.hub"), position = Vector3.new(0, D.floorTopY, 0) },
	}
	for _, name in ipairs(WorldMapLayout.facilityOrder) do
		local f = D.hub.facilities[name]
		table.insert(list, { kind = "facility", icon = name == "forge" and "pin_forge" or "pin_hub", name = Text.name(f.displayName), position = WorldMapLayout.facility(name), named = true, priority = 0 })
	end
	-- QUEUE-ALL7B 2 · 4: 마을 기능 · 이름 있는 건물 · NPC(이름 층 · 누르면 핀 + 길 안내 - 건물은 아이콘 없이 이름만)
	for _, e in ipairs(HubPlaces.list()) do
		e.small, e.named = true, true
		table.insert(list, e)
	end
	local unlocked = player:GetAttribute("ZonesUnlocked") or D.progress.startUnlocked
	for index, zone in ipairs(D.zones) do
		if index <= unlocked or visited[zone.key] then
			table.insert(list, { kind = "camp", icon = "pin_checkpoint", name = Text.get("map.camp", { zone = zone.theme }), position = WorldMapLayout.camp(zone), zoneIndex = index })
			for _, g in ipairs(WorldMapLayout.grounds(zone)) do
				table.insert(list, { kind = "ground", icon = "pin_quest", name = Text.get("map.ground", { zone = zone.hunt.name, n = tostring(g.index) }), position = g.center, small = true })
			end
		end
		table.insert(list, { kind = "gate", icon = "pin_gate", name = Text.get("map.gate", { zone = zone.theme }), position = WorldMapLayout.gate(zone) }) -- QUEUE-ALL7 D4: 관문은 안 가 본 구역도 늘 보인다(길 잃지 않게)
	end
	-- 체크포인트(Q5 - 발견한 것만 · 스위치 켬일 때)
	local found = player:GetAttribute("CheckpointsFound")
	if D.checkpoints and type(found) == "string" and found ~= "" then
		for _, cp in ipairs(D.checkpoints.list) do
			if string.find("," .. found .. ",", "," .. cp.id .. ",", 1, true) then
				local pos = cp.hub and (cp.angleDeg and WorldMapLayout.hubPoint(cp.angleDeg, cp.r) or WorldMapLayout.spawnPoint()) or WorldMapLayout.camp(WorldMapLayout.zoneByKey(cp.zone))
				table.insert(list, { kind = "checkpoint", icon = "pin_checkpoint", name = Text.get("map.checkpoint", { name = cp.name }), position = pos, checkpointId = cp.id })
			end
		end
	end
	return list
end

local function marker(parent, place, size)
	if not place.icon then
		return nil
	end
	local b = Instance.new("ImageButton")
	b.Name = "Marker_" .. place.kind
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	local r = toMap(place.position)
	b.Position = UDim2.fromScale(r.X, r.Y)
	b.Size = UDim2.fromOffset(size, size)
	b.BackgroundTransparency = 1
	b.ZIndex = 5
	local img = ArtImage.get(place.icon:find("/", 1, true) and place.icon or ("icons/ui/" .. place.icon)) -- ALL7B 2: 마을 기능 = 전체 경로
	if img then
		b.Image = img
	else
		b.BackgroundTransparency = 0
		b.BackgroundColor3 = place.kind == "checkpoint" and Theme.color("success") or Theme.color("gold")
		Theme.corner(b, size)
	end
	b.Parent = parent
	b.Activated:Connect(function()
		WorldMapPanel.select(place)
		if place.named then
			WorldMapPanel.pinAndGuide(place)
		end
	end)
	return b
end

-- QUEUE-ALL7B 4 이름 층(UI - 아이콘 위): 허브 시설 · 건물 · 기능 · NPC 이름. 자리 = 아이콘 아래 → 겹치면 위 · 더 아래 · 더 위 → 그래도 겹치면 숨김(확대하면 간격이 벌어져 보인다).
local LABEL_SIZE = 12
local namePinAt -- 이름을 눌러 찍은 핀 자리(하나만)
local HUB_PIN_NEAR = 6 -- 같은 자리 핀 판정(stud - 허브 기능 간격 약 30이라 지도 클릭용 pinPickStuds 120은 너무 넓다)
local LABEL_TRIES = { { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 }, { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 }, { 0, 2.1 }, { 0, -2.1 }, { 2.1, 0 }, { -2.1, 0 },
	{ 2.1, 1 }, { -2.1, 1 }, { 2.1, -1 }, { -2.1, -1 }, { 0, 3.2 }, { 0, -3.2 }, { 1, 2.1 }, { -1, 2.1 }, { 1, -2.1 }, { -1, -2.1 } } -- QUEUE-ALL8 D4: 한 칸 더 먼 자리(최대 배율에서 붐비는 시장 · 광장의 이름도 다 보이게) -- 아래 · 위 · 오른쪽 · 왼쪽 · 대각 · 한 칸 더(x × (아이콘 반 + 글 폭 반 + 3) · y × (아이콘 반 + 글 높이 반 + 2))
local function nameLabel(parent, place)
	local text = place.name or ""
	local ts = TextService:GetTextSize(text, LABEL_SIZE, Theme.font, Vector2.new(400, 40))
	local b = Instance.new("TextButton")
	b.Name = "Name_" .. place.kind
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Size = UDim2.fromOffset(ts.X + 10, ts.Y + 4)
	b.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
	b.BackgroundTransparency = 0.35
	b.AutoButtonColor = false
	b.Font = Theme.font
	b.TextSize = LABEL_SIZE
	b.TextColor3 = place.kind == "facility" and Theme.color("gold") or Color3.new(1, 1, 1)
	b.Text = text
	b.ZIndex = 7
	b.Parent = parent
	Theme.corner(b, 6)
	b.Activated:Connect(function()
		WorldMapPanel.select(place)
		WorldMapPanel.pinAndGuide(place)
	end)
	return b
end

local function layoutLabels()
	if not built or not built.labels then
		return
	end
	local side = built.canvas.AbsoluteSize.X
	local taken = {}
	local function free(c, s)
		for _, r in ipairs(taken) do
			if math.abs(c.X - r.c.X) * 2 < s.X + r.s.X and math.abs(c.Y - r.c.Y) * 2 < s.Y + r.s.Y then
				return false
			end
		end
		return true
	end
	for _, b in ipairs(built.markers:GetChildren()) do -- 모든 아이콘 자리를 먼저 막는다(이름이 아이콘을 덮지 않게 - 허브 · 캠프 · 핀 포함)
		if b:IsA("ImageButton") then
			table.insert(taken, { c = Vector2.new(b.Position.X.Scale * side, b.Position.Y.Scale * side), s = b.AbsoluteSize })
		end
	end
	for _, L in ipairs(built.labels) do
		local a = toMap(L.place.position) * side
		local s = L.inst.AbsoluteSize
		local iconHalf = L.place.icon and L.icon / 2 or 0
		local step = Vector2.new(iconHalf + s.X / 2 + 3, iconHalf + s.Y / 2 + 2)
		local placed = false
		for _, k in ipairs(L.place.icon and LABEL_TRIES or { { 0, 0 }, { 0, 1 }, { 0, -1 }, { 0, 2 }, { 0, -2 }, { 0.6, 0 }, { -0.6, 0 }, { 0.6, 1 }, { -0.6, 1 }, { 0.6, -1 }, { -0.6, -1 }, { 0, 3 }, { 0, -3 }, { 1.2, 0 }, { -1.2, 0 } }) do -- 아이콘 없는 건물 이름 = 그 자리 가운데부터 · ALL8 D4: 붐비면 조금 더 먼 자리
			local c = a + Vector2.new(k[1] * step.X, k[2] * step.Y)
			if free(c, s) then
				table.insert(taken, { c = c, s = s })
				L.inst.Position = UDim2.new(0, c.X, 0, c.Y)
				placed = true
				break
			end
		end
		L.inst.Visible = placed
	end
end

local function drawVectorMap(canvas)
	-- 바탕: 세계 원(바다 · 먼 산 쪽 어둡게) + 6구역 원(바닥 색) + 허브 원
	local world = Instance.new("Frame")
	world.Name = "World"
	world.BackgroundColor3 = Color3.fromRGB(46, 70, 92)
	world.Size = UDim2.fromScale(1, 1)
	world.Parent = canvas
	Theme.corner(world, 9999)
	for index, zone in ipairs(D.zones) do
		local c = toMap(WorldMapLayout.regionCenter(zone))
		local rr = D.layout.regionRadius / (2 * EDGE)
		local disc = Instance.new("Frame")
		disc.Name = "Zone_" .. zone.key
		disc.AnchorPoint = Vector2.new(0.5, 0.5)
		disc.Position = UDim2.fromScale(c.X, c.Y)
		disc.Size = UDim2.fromScale(rr * 2, rr * 2)
		local tint = zone.floorTint or { 140, 150, 140 }
		disc.BackgroundColor3 = Color3.fromRGB(tint[1], tint[2], tint[3]):Lerp(Color3.fromRGB(96, 160, 90), 0.35)
		disc.Parent = canvas
		Theme.corner(disc, 9999)
		local name = Theme.label(disc, Text.name(zone.theme), "header", "textPrimary")
		name.Name = "ZoneName"
		name.AnchorPoint = Vector2.new(0.5, 0.5)
		name.Position = UDim2.fromScale(0.5, 0.5)
		name.Size = UDim2.new(1, 0, 0, 24)
		name.TextXAlignment = Enum.TextXAlignment.Center
		name.TextStrokeTransparency = 0.3
		disc:SetAttribute("ZoneIndex", index)
	end
	local hubR = D.hub.safeRadius / (2 * EDGE)
	local hub = Instance.new("Frame")
	hub.Name = "Hub"
	hub.AnchorPoint = Vector2.new(0.5, 0.5)
	hub.Position = UDim2.fromScale(0.5, 0.5)
	hub.Size = UDim2.fromScale(hubR * 2, hubR * 2)
	hub.BackgroundColor3 = Color3.fromRGB(120, 190, 100)
	hub.Parent = canvas
	Theme.corner(hub, 9999)
end

-- QUEUE-ALL7 D4 구운 지도 위 UI 층: 안 가 본 구역 흐림(어두운 원 - 갈 수 있는 곳만 또렷하게) · 구역 이름 · 세부 지역 이름(ko/en - 이미지에 굽지 않는다)
local function drawImageMap(canvas)
	for r = 1, #MapImageData.tiles do
		for c = 1, #MapImageData.tiles[r] do
			local tile = Instance.new("ImageLabel")
			tile.Name = ("MapTile_%d_%d"):format(r - 1, c - 1)
			tile.BackgroundTransparency = 1
			tile.Image = ArtImage.get(MapImageData.tiles[r][c]) or ""
			tile.Size = UDim2.fromScale(1 / #MapImageData.tiles[r], 1 / #MapImageData.tiles)
			tile.Position = UDim2.fromScale((c - 1) / #MapImageData.tiles[r], (r - 1) / #MapImageData.tiles)
			tile.ZIndex = 1
			tile.Parent = canvas
		end
	end
	-- QUEUE-ALL8 D2: 허브 고해상도 한 장(확대 MapImageData.hub.zoomFrom 이상 - applyView가 보이기를 바꾼다)
	local H = MapImageData.hub
	local hubImg = ArtImage.get(H.key)
	if hubImg then
		local a, b = MapImageData.toUV(-H.half, -H.half), MapImageData.toUV(H.half, H.half)
		local detail = Instance.new("ImageLabel")
		detail.Name = "HubDetail"
		detail.BackgroundTransparency = 1
		detail.Image = hubImg
		detail.Position = UDim2.fromScale(a.X, a.Y)
		detail.Size = UDim2.fromScale(b.X - a.X, b.Y - a.Y)
		detail.ZIndex = 2
		detail.Visible = false
		detail.Parent = canvas
	end
	for index, zone in ipairs(D.zones) do
		local c = toMap(WorldMapLayout.regionCenter(zone))
		local rr = D.layout.regionRadius / (2 * EDGE)
		local fog = Instance.new("Frame")
		fog.Name = "Fog_" .. zone.key
		fog.AnchorPoint = Vector2.new(0.5, 0.5)
		fog.Position = UDim2.fromScale(c.X, c.Y)
		fog.Size = UDim2.fromScale(rr * 2, rr * 2)
		fog.BackgroundColor3 = Color3.fromRGB(28, 34, 48)
		fog.BackgroundTransparency = 1
		fog.ZIndex = 2
		fog:SetAttribute("ZoneIndex", index)
		fog.Parent = canvas
		Theme.corner(fog, 9999)
		local name = Theme.label(canvas, Text.name(zone.theme), "header", "textPrimary")
		name.Name = "ZoneName_" .. zone.key
		name.AnchorPoint = Vector2.new(0.5, 0.5)
		name.Position = UDim2.fromScale(c.X, c.Y - 0.045) -- 구역 가운데의 사냥 지대 아이콘과 겹치지 않게 위로
		name.Size = UDim2.fromOffset(220, 24)
		name.TextXAlignment = Enum.TextXAlignment.Center
		name.TextStrokeTransparency = 0.2
		name.ZIndex = 6 -- 아이콘(5) 위 - 글자는 입력을 안 막는다
		name:SetAttribute("ZoneIndex", index)
		for i, area in ipairs(D.subAreas.names[zone.key] or {}) do
			local ac = toMap(WorldMapLayout.subAreaCenter(zone, i))
			local a = Theme.label(canvas, Text.name(area), "caption", "textPrimary")
			a.Name = "AreaName"
			a.AnchorPoint = Vector2.new(0.5, 0.5)
			a.Position = UDim2.fromScale(ac.X, ac.Y + 0.012)
			a.Size = UDim2.fromOffset(140, 16)
			a.TextXAlignment = Enum.TextXAlignment.Center
			a.TextStrokeTransparency = 0.3
			a.ZIndex = 3
			a:SetAttribute("ZoneIndex", index)
			a:SetAttribute("SubArea", true)
		end
	end
end

local function refreshDim()
	if not built then
		return
	end
	for _, child in ipairs(built.canvas:GetChildren()) do
		local index = child:GetAttribute("ZoneIndex")
		if index then
			local bright = zoneBright(D.zones[index], index)
			if child.Name:match("^Fog_") then
				child.BackgroundTransparency = bright and 1 or 0.45
			elseif child:IsA("TextLabel") then
				child.TextTransparency = bright and 0 or 0.5
				if child:GetAttribute("SubArea") then
					child.Visible = bright and zoom >= 1.6 -- 세부 지역 이름 = 확대했을 때만(겹침 · 지저분함 방지)
				end
			else
				child.BackgroundTransparency = bright and 0 or 0.55
				local zn = child:FindFirstChild("ZoneName")
				if zn then
					zn.TextTransparency = bright and 0 or 0.5
				end
			end
		end
	end
end

local function applyView()
	local base = built.view.AbsoluteSize
	local side = math.min(base.X, base.Y) * zoom
	built.canvas.Size = UDim2.fromOffset(side, side)
	built.canvas.Position = UDim2.fromOffset(base.X / 2 - side / 2 + offset.X, base.Y / 2 - side / 2 + offset.Y)
	local detail = built.canvas:FindFirstChild("HubDetail")
	if detail then
		detail.Visible = zoom >= MapImageData.hub.zoomFrom
	end
	refreshDim()
	task.defer(layoutLabels)
end

local function renderMarkers()
	for _, child in ipairs(built.markers:GetChildren()) do
		child:Destroy()
	end
	built.labels = {}
	for _, place in ipairs(places()) do
		local size = place.small and 14 or 22
		marker(built.markers, place, size)
		if place.named and not place.nameHidden then -- QUEUE-ALL9A 3-1 자기 건물 가까운 기능 = 건물 이름만
			table.insert(built.labels, { place = place, icon = size, inst = nameLabel(built.markers, place) })
		end
	end
	table.sort(built.labels, function(a, b)
		return a.place.priority < b.place.priority
	end)
	task.defer(layoutLabels) -- 글 크기(AbsoluteSize)가 잡힌 뒤
	for _, pin in ipairs(MapPins.list()) do
		marker(built.markers, { kind = "pin", icon = "pin_user", name = pin.label, position = pin.position, pin = pin }, 24)
	end
	refreshDim()
end

-- QUEUE-ALL7B 4: 이름 · 아이콘을 누르면 그 자리에 핀(이미 있으면 그대로) + 길 안내(창은 열린 채 - 자동 이동은 옆 버튼)
function WorldMapPanel.pinAndGuide(place)
	-- 리뷰: 이름 누르기 핀은 하나만(지난 이름 핀을 옮긴다) · 칸이 차 있으면 핀 없이 안내만 - 사용자가 찍은 핀은 지우지 않는다
	local function pinNear(pos)
		for _, pin in ipairs(MapPins.list()) do
			if ((pin.position - pos) * Vector3.new(1, 0, 1)).Magnitude <= HUB_PIN_NEAR then
				return pin
			end
		end
		return nil
	end
	if not pinNear(place.position) then
		if namePinAt and pinNear(namePinAt) then
			MapPins.toggleAt(namePinAt, HUB_PIN_NEAR) -- 지난 이름 핀 지움
		end
		namePinAt = nil
		if #MapPins.list() < MAP.maxPins then
			MapPins.toggleAt(place.position, HUB_PIN_NEAR)
			namePinAt = place.position
		end
	end
	MapPins.go(place.position, place.name, false)
end

function WorldMapPanel.select(place)
	selected = place
	if not built then
		return
	end
	built.title.Text = place and place.name or Text.get("map.pickHint")
	built.autoButton.setEnabled(place ~= nil)
	built.guideButton.setEnabled(place ~= nil)
	built.teleButton.root.Visible = place ~= nil and place.checkpointId ~= nil and D.checkpoints ~= nil and workspace:GetAttribute("CheckpointTeleport") == true
end

local function build()
	local panel = Panel.create({ id = WorldMapPanel.id, kind = "window", title = Text.get("map.title"), size = PANEL_SIZE,
		onOpen = function()
			task.defer(function()
				applyView()
				renderMarkers()
				WorldMapPanel.select(selected)
				-- ALL7B 1-5: 처음 연 한 번만 "미니맵 표시" 토글이 은은하게 반짝(0.8 Hz · 4번 - 깜빡임 < 3/s) + 한 줄 안내
				if player:GetAttribute("MapHintSeen") ~= true and built then
					SettingSave("mapHintSeen", true)
					built.firstHint.Visible = true
					local glow = Instance.new("UIStroke")
					glow.Name = "FirstGlow"
					glow.Color = Theme.color("gold")
					glow.Thickness = 2
					glow.Transparency = 1
					glow.Parent = built.minimapToggle.root
					local t = TweenService:Create(glow, TweenInfo.new(0.625, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 7, true), { Transparency = 0.1 })
					t:Play()
					t.Completed:Connect(function()
						glow:Destroy()
						built.firstHint.Visible = false -- 안내 줄도 반짝임과 같이 끝(두 번째부터 안 뜸 = mapHintSeen)
					end)
				end
			end)
		end })
	local content = panel.content
	local view = Instance.new("Frame")
	view.Name = "MapView"
	view.BackgroundColor3 = Color3.fromRGB(24, 30, 44)
	view.ClipsDescendants = true
	view.Position = UDim2.fromOffset(10, 8)
	view.Size = UDim2.new(1, -(SIDE_W + 20), 1, -16)
	view.Active = true
	view.Parent = content
	Theme.corner(view, 10)
	local canvas = Instance.new("Frame")
	canvas.Name = "Canvas"
	canvas.BackgroundTransparency = 1
	canvas.Parent = view
	if ArtImage.get(MapImageData.tiles[1][1]) then -- QUEUE-ALL7 D: 구운 지도 2 × 2 타일 + UI 층 · 없으면 옛 도형 지도
		drawImageMap(canvas)
	else
		drawVectorMap(canvas)
	end
	local markers = Instance.new("Frame")
	markers.Name = "Markers"
	markers.BackgroundTransparency = 1
	markers.Size = UDim2.fromScale(1, 1)
	markers.ZIndex = 4
	markers.Parent = canvas
	-- 나 · 파티원(0.2초마다)
	local me = Instance.new("Frame")
	me.Name = "Me"
	me.AnchorPoint = Vector2.new(0.5, 0.5)
	me.Size = UDim2.fromOffset(18, 18)
	me.BackgroundTransparency = 1
	me.ZIndex = 8
	me.Parent = canvas
	local arrow = ArtImage.label(me, "icons/ui/pin_player", UDim2.fromScale(1, 1), "▲")
	arrow.ZIndex = 8

	-- 오른쪽: 고른 것 이름 · 버튼 · 확대
	local side = Instance.new("Frame")
	side.Name = "Side"
	side.BackgroundTransparency = 1
	side.Position = UDim2.new(1, -(SIDE_W + 6), 0, 8)
	side.Size = UDim2.new(0, SIDE_W, 1, -16)
	side.Parent = content
	local title = Theme.label(side, Text.get("map.pickHint"), "header", "textPrimary")
	title.Name = "Selected"
	title.TextWrapped = true
	title.Size = UDim2.new(1, 0, 0, 64)
	local autoButton = Button.build({ parent = side, kind = "primary", width = SIDE_W, height = 48, text = Text.get("map.autoWalk"), position = UDim2.fromOffset(0, 72),
		onActivated = function()
			if selected then
				MapPins.go(selected.position, selected.name, true)
				UIManager.close(WorldMapPanel.id)
			end
		end })
	autoButton.root.Name = "AutoWalkButton"
	local guideButton = Button.build({ parent = side, kind = "secondary", width = SIDE_W, height = 48, text = Text.get("map.guide"), position = UDim2.fromOffset(0, 128),
		onActivated = function()
			if selected then
				MapPins.go(selected.position, selected.name, false)
				UIManager.close(WorldMapPanel.id)
			end
		end })
	guideButton.root.Name = "GuideButton"
	local teleButton = Button.build({ parent = side, kind = "primary", width = SIDE_W, height = 48, text = Text.get("map.teleport"), position = UDim2.fromOffset(0, 184),
		onActivated = function()
			if selected and selected.checkpointId then
				ReplicatedStorage:WaitForChild("TravelRequest"):FireServer("checkpoint", selected.checkpointId)
				UIManager.close(WorldMapPanel.id)
			end
		end })
	teleButton.root.Name = "TeleportButton"
	teleButton.root.Visible = false
	local hint = Theme.label(side, Text.get("map.pinHint", { n = tostring(MAP.maxPins) }), "caption", "textSecondary")
	hint.TextWrapped = true
	hint.Position = UDim2.fromOffset(0, 244)
	hint.Size = UDim2.new(1, 0, 0, 40)
	-- QUEUE-ALL7 D3 · ALL7B 1-2: 미니맵 표시 토글(상태 = 설정 minimapOn 한 곳 - 미니맵 톱니 "끄기"도 같은 값) · 1-5 첫 안내(한 번만 은은하게)
	local minimapToggle = Toggle.build({ parent = side, name = "MinimapToggle", text = Text.get("map.minimapToggle"), value = player:GetAttribute("MinimapOn") == true,
		width = SIDE_W, position = UDim2.fromOffset(0, 288), onChanged = function(v)
			SettingSave("minimapOn", v)
		end })
	player:GetAttributeChangedSignal("MinimapOn"):Connect(function()
		minimapToggle.setValue(player:GetAttribute("MinimapOn") == true, true)
	end)
	local firstHint = Theme.label(side, Text.get("map.minimapHint"), "caption", "gold")
	firstHint.Name = "MinimapFirstHint"
	firstHint.TextWrapped = true
	firstHint.Position = UDim2.fromOffset(0, 288 + 46)
	firstHint.Size = UDim2.new(1, 0, 0, 18)
	firstHint.Visible = false
	local legendButton = Button.build({ parent = side, kind = "secondary", width = 64, height = 48, text = "?", position = UDim2.new(0, 144, 1, -48), onActivated = function()
		built.legend.Visible = not built.legend.Visible
	end })
	legendButton.root.Name = "LegendButton"
	local zoomIn = Button.build({ parent = side, kind = "secondary", width = 64, height = 48, text = "+", position = UDim2.new(0, 0, 1, -48), onActivated = function()
		zoom = math.clamp(zoom * 1.4, MAP.zoomMin, MAP.zoomMax)
		applyView()
	end })
	zoomIn.root.Name = "ZoomIn"
	local zoomOut = Button.build({ parent = side, kind = "secondary", width = 64, height = 48, text = "−", position = UDim2.new(0, 72, 1, -48), onActivated = function()
		zoom = math.clamp(zoom / 1.4, MAP.zoomMin, MAP.zoomMax)
		if zoom <= 1 then
			offset = Vector2.zero
		end
		applyView()
	end })
	zoomOut.root.Name = "ZoomOut"

	-- 입력: 휠 = 확대 · 끌기 = 이동 · 짧게 누름(움직임 < 6px) = 핀 찍기/지우기
	local dragStart, dragFrom, moved
	view.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragStart, dragFrom, moved = Vector2.new(input.Position.X, input.Position.Y), offset, false
		end
	end)
	view.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			zoom = math.clamp(zoom * (input.Position.Z > 0 and 1.2 or 1 / 1.2), MAP.zoomMin, MAP.zoomMax)
			applyView()
		elseif dragStart and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = Vector2.new(input.Position.X, input.Position.Y) - dragStart
			if d.Magnitude > 6 then
				moved = true
			end
			offset = dragFrom + d
			applyView()
		end
	end)
	view.InputEnded:Connect(function(input)
		if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and dragStart then
			if not moved then
				local abs, size = canvas.AbsolutePosition, canvas.AbsoluteSize
				local ratio = (Vector2.new(input.Position.X, input.Position.Y) - abs) / size
				if ratio.X >= 0 and ratio.X <= 1 and ratio.Y >= 0 and ratio.Y <= 1 then
					local placed = MapPins.toggleAt(toWorld(ratio), MAP.pinPickStuds / zoom)
					if placed then
						local pins = MapPins.list()
						local pin = pins[#pins]
						WorldMapPanel.select({ kind = "pin", name = pin.label, position = pin.position })
					else
						WorldMapPanel.select(nil)
					end
				end
			end
			dragStart = nil
		end
	end)
	-- QUEUE-ALL7 D4 범례(아이콘 뜻 - [?])
	local legend = Instance.new("Frame")
	legend.Name = "Legend"
	legend.AnchorPoint = Vector2.new(0, 1)
	legend.Position = UDim2.new(0, 8, 1, -8)
	legend.Size = UDim2.fromOffset(200, 10 + 6 * 26)
	legend.BackgroundColor3 = Color3.fromRGB(22, 26, 38)
	legend.BackgroundTransparency = 0.1
	legend.ZIndex = 20
	legend.Visible = false
	legend.Parent = view
	Theme.corner(legend, 8)
	for i, item in ipairs({ { "pin_player", "map.legend.me" }, { "pin_hub", "map.legend.hub" }, { "pin_forge", "map.legend.forge" }, { "pin_gate", "map.legend.gate" }, { "pin_checkpoint", "map.legend.checkpoint" }, { "pin_user", "map.legend.pin" } }) do
		local ic = ArtImage.label(legend, "icons/ui/" .. item[1], UDim2.fromOffset(20, 20), "•")
		ic.Position = UDim2.fromOffset(8, 6 + (i - 1) * 26)
		ic.ZIndex = 21
		local t = Theme.label(legend, Text.get(item[2]), "caption", "textPrimary")
		t.Position = UDim2.fromOffset(34, 6 + (i - 1) * 26)
		t.Size = UDim2.new(1, -40, 0, 20)
		t.ZIndex = 21
	end
	built = { panel = panel, view = view, canvas = canvas, markers = markers, me = me, title = title, autoButton = autoButton, guideButton = guideButton, teleButton = teleButton, legend = legend, minimapToggle = minimapToggle, firstHint = firstHint }
	view:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyView)
end

local lastMe = 0
RunService.Heartbeat:Connect(function()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		local zone = WorldMapLayout.zoneAt(root.Position)
		if zone and not visited[zone.key] then
			visited[zone.key] = true
			refreshDim()
		end
	end
	if not built or not UIManager.isOpen(WorldMapPanel.id) or os.clock() - lastMe < 0.2 or not root then
		return
	end
	lastMe = os.clock()
	local r = toMap(root.Position)
	built.me.Position = UDim2.fromScale(r.X, r.Y)
	local look = root.CFrame.LookVector
	built.me.Rotation = math.deg(math.atan2(look.X, -look.Z))
end)

function WorldMapPanel.init()
	build()
	MapPins.changed:Connect(function()
		if UIManager.isOpen(WorldMapPanel.id) then
			renderMarkers()
		end
	end)
	for _, name in ipairs({ "ZonesUnlocked", "CheckpointsFound" }) do
		player:GetAttributeChangedSignal(name):Connect(function()
			if UIManager.isOpen(WorldMapPanel.id) then
				renderMarkers()
			end
		end)
	end
	WorldMapPanel.select(nil)
end

function WorldMapPanel.toggle()
	UIManager.switchTo(WorldMapPanel.id)
end

return WorldMapPanel
