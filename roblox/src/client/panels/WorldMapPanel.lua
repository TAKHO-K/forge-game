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

-- 월드 X · Z → 지도 캔버스 비율(0 ~ 1) · 위 = −Z(석조 평원 쪽)
local function toMap(position)
	return Vector2.new((position.X + EDGE) / (2 * EDGE), (position.Z + EDGE) / (2 * EDGE))
end
local function toWorld(ratio)
	return Vector3.new(ratio.X * 2 * EDGE - EDGE, D.floorTopY, ratio.Y * 2 * EDGE - EDGE)
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
		table.insert(list, { kind = "facility", icon = name == "forge" and "pin_forge" or "pin_hub", name = Text.name(f.displayName), position = WorldMapLayout.facility(name) })
	end
	local unlocked = player:GetAttribute("ZonesUnlocked") or D.progress.startUnlocked
	for index, zone in ipairs(D.zones) do
		if index <= unlocked or visited[zone.key] then
			table.insert(list, { kind = "camp", icon = "pin_checkpoint", name = Text.get("map.camp", { zone = zone.theme }), position = WorldMapLayout.camp(zone), zoneIndex = index })
			for _, g in ipairs(WorldMapLayout.grounds(zone)) do
				table.insert(list, { kind = "ground", icon = "pin_quest", name = Text.get("map.ground", { zone = zone.hunt.name, n = tostring(g.index) }), position = g.center, small = true })
			end
			table.insert(list, { kind = "gate", icon = "pin_gate", name = Text.get("map.gate", { zone = zone.theme }), position = WorldMapLayout.gate(zone) })
		end
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
	local b = Instance.new("ImageButton")
	b.Name = "Marker_" .. place.kind
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	local r = toMap(place.position)
	b.Position = UDim2.fromScale(r.X, r.Y)
	b.Size = UDim2.fromOffset(size, size)
	b.BackgroundTransparency = 1
	b.ZIndex = 5
	local img = ArtImage.get("icons/ui/" .. place.icon)
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
	end)
	return b
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

local function refreshDim()
	if not built then
		return
	end
	for _, child in ipairs(built.canvas:GetChildren()) do
		local index = child:GetAttribute("ZoneIndex")
		if index then
			local bright = zoneBright(D.zones[index], index)
			child.BackgroundTransparency = bright and 0 or 0.55
			child.ZoneName.TextTransparency = bright and 0 or 0.5
		end
	end
end

local function applyView()
	local base = built.view.AbsoluteSize
	local side = math.min(base.X, base.Y) * zoom
	built.canvas.Size = UDim2.fromOffset(side, side)
	built.canvas.Position = UDim2.fromOffset(base.X / 2 - side / 2 + offset.X, base.Y / 2 - side / 2 + offset.Y)
end

local function renderMarkers()
	for _, child in ipairs(built.markers:GetChildren()) do
		child:Destroy()
	end
	for _, place in ipairs(places()) do
		marker(built.markers, place, place.small and 14 or 22)
	end
	for _, pin in ipairs(MapPins.list()) do
		marker(built.markers, { kind = "pin", icon = "pin_user", name = pin.label, position = pin.position, pin = pin }, 24)
	end
	refreshDim()
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
	local image = MAP.image and ArtImage.get(MAP.image)
	if image then
		local bg = Instance.new("ImageLabel")
		bg.Name = "MapImage"
		bg.BackgroundTransparency = 1
		bg.Image = image
		bg.Size = UDim2.fromScale(1, 1)
		bg.Parent = canvas
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
	hint.Size = UDim2.new(1, 0, 0, 52)
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
	built = { panel = panel, view = view, canvas = canvas, markers = markers, me = me, title = title, autoButton = autoButton, guideButton = guideButton, teleButton = teleButton }
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
