-- 미니맵(QUEUE-ALL3 Q4 → QUEUE-ALL7 D3 · ALL7B 1 다시 짬). 화면 오른쪽 위 원형 - 자리 = ScreenMap TR.minimap(칩 스택 · 지역 이름 아래 · 폰은 칩 스택 왼쪽 열 옆 - place()).
--   켜기 = 플레이어 설정 minimapOn(기본 꺼짐 · 지도 창 M의 "미니맵 표시" 토글 · 이 미니맵의 톱니 메뉴 "미니맵 끄기") - 상태 = Attribute MinimapOn 한 곳(ui/SettingSave가 저장).
--   그림 = 구운 지도 한 장(MapImageData.mini - 1024²) · ImageLabel 하나의 ImageRect로 보이는 칸만 자르고 UICorner(반지름 0.5)로 원형 · 회전 = Rotation
--     (ClipsDescendants는 사각형만 자르고 돌린 자식을 못 자른다 · CanvasGroup 금지 · ViewportFrame은 데칼을 안 그린다 - 2026-10-02 실측).
--   기본 = 북쪽 위 고정 + 내 화살표가 돈다 · 설정 minimapRotate = 내 방향이 위(지도가 돈다) · 확대 2단계(minimapFar = 반경 × 2).
--   아이콘 = 글자 없이 모양 + 색(같은 크기) · 가까운 순 최대 30개 · 10 Hz · 허브 · 대장간 · 관문(늘 - 지도 창과 같게) · 발견한 체크포인트 · 내 핀 · 파티원 · 길 안내 목적지(밖이면 테두리).
--   둥지 · 탐험 지점은 안 그린다. 숨김 = 보스 아레나(BossEncounterId) · 입력 막힘(창 · 보스 등장 연출 - UIManager.isInputBlocked). 누르면 전체 지도(worldMap).
--   드랍 피드(Toast TR)는 투명 칸 MinimapFeedAnchor(ScreenMap TR.minimapColumn) 아래에 놓인다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local MapImageData = require(ReplicatedStorage.Shared.data.MapImageData)
local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local Text = require(ReplicatedStorage.Shared.Text)
local ScreenMap = require(script.Parent.Parent.ui.ScreenMap)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local ArtImage = require(script.Parent.Parent.ui.ArtImage)
local SettingSave = require(script.Parent.Parent.ui.SettingSave)
local HubPlaces = require(script.Parent.Parent.HubPlaces)
local UIManager = require(script.Parent.Parent.UIManager)
local MapPins = require(script.Parent.Parent.MapPins)
local Wayfinder = require(script.Parent.Parent.Wayfinder)
local PartyColors = require(script.Parent.Parent.PartyColors)
local Toast = require(script.Parent.Parent.ui.kit.Toast)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local D = WorldMapData
local MM = D.map.minimap
local miniImage = ArtImage.get(MapImageData.mini) or ""
local hubImage = ArtImage.get(MapImageData.hub.key) -- QUEUE-ALL8 D2(없으면 nil = 세계 한 장만)
local ICON_MAX = 30
local GEAR_HIT = 44 -- 톱니 터치 영역(모바일 최소)
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

local function enabled()
	return player:GetAttribute("MinimapOn") == true
end
local function rangeStuds()
	return MM.rangeStuds * (player:GetAttribute("MinimapFar") == true and 2 or 1)
end
local function rotating()
	return player:GetAttribute("MinimapRotate") == true
end

local function iconPx()
	return Theme.isMobile and MM.iconPhone or MM.icon
end

-- 아이콘 하나(이미지가 아직 없으면 색 점) - 겉 칸 px 자리
local function icon(parent, iconName, px, fallbackColor)
	local img = ArtImage.get(require(game:GetService("ReplicatedStorage").Shared.UiModel).mapIcon(iconName)) -- ALL7B 2: 마을 기능 = 전체 경로 · UI-1 ⑦ 핀 키(UiIconData.map)
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

-- 정적 장소(월드 자리 목록 - 바뀔 때만 다시) · 화면 자리는 10 Hz에 계산
local places = {}
local function rebuildPlaces()
	places = {}
	local function put(iconName, position, color, name)
		table.insert(places, { icon = iconName, position = position, color = color, name = name })
	end
	put("pin_hub", Vector3.new(0, D.floorTopY, 0), Theme.color("gold"), Text.get("map.hub"))
	put("pin_forge", WorldMapLayout.facility("forge"), Theme.color("gold"), Text.name(D.hub.facilities.forge.displayName))
	for _, e in ipairs(HubPlaces.list()) do -- QUEUE-ALL7B 2 · 4: 마을 기능 · NPC(아이콘만 - 이름 = 말풍선)
		if e.icon then
			put(e.icon, e.position, Theme.color("gold"), e.name)
		end
	end
	for _, zone in ipairs(D.zones) do
		put("pin_gate", WorldMapLayout.gate(zone), Color3.fromRGB(230, 90, 90), Text.get("map.gate", { zone = zone.theme })) -- 리뷰: 지도 창과 같게 관문은 늘(길 잃지 않게)
	end
	local found = player:GetAttribute("CheckpointsFound")
	if D.checkpoints and type(found) == "string" and found ~= "" then
		for _, cp in ipairs(D.checkpoints.list) do
			if string.find("," .. found .. ",", "," .. cp.id .. ",", 1, true) then
				local pos = cp.hub and WorldMapLayout.spawnPoint() or WorldMapLayout.camp(WorldMapLayout.zoneByKey(cp.zone))
				put("pin_checkpoint", pos, Theme.color("success"), Text.get("map.checkpoint", { name = cp.name }))
			end
		end
	end
	for _, pin in ipairs(MapPins.list()) do
		put("pin_user", pin.position, Color3.fromRGB(176, 120, 255), pin.label)
	end
	if refs then
		for _, inst in ipairs(refs.icons) do
			inst:Destroy()
		end
		refs.icons = {}
	end
end

local function textButton(parent, name, text, y)
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = UDim2.new(1, -12, 0, GEAR_HIT)
	b.Position = UDim2.fromOffset(6, y)
	b.BackgroundColor3 = Color3.fromRGB(52, 58, 76)
	b.AutoButtonColor = true
	b.Font = Theme.font
	b.TextSize = 14
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text
	b.ZIndex = 21
	b.Parent = parent
	Theme.corner(b, 8)
	return b
end

local function build()
	local root = Instance.new("Frame")
	root.Name = "Minimap"
	root.BackgroundTransparency = 1
	root.Visible = false
	root.Parent = gui

	-- 지도 = 한 장(원형 · ImageRect)
	local mapImage = Instance.new("ImageLabel")
	mapImage.Name = "MapImage"
	mapImage.AnchorPoint = Vector2.new(0.5, 0.5)
	mapImage.Position = UDim2.fromScale(0.5, 0.5)
	mapImage.Size = UDim2.fromScale(1, 1)
	mapImage.BackgroundColor3 = Color3.fromRGB(40, 52, 66)
	mapImage.Image = miniImage
	mapImage.ScaleType = Enum.ScaleType.Stretch
	mapImage.ZIndex = 2
	mapImage.Parent = root
	Theme.corner(mapImage, 9999)

	-- 움직이는 것(px 자리): 장소 아이콘 · 파티원 점 · 목적지 · 내 화살표(가운데 고정)
	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.BackgroundTransparency = 1
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 6
	overlay.Parent = root
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
	ArtImage.label(me, require(game:GetService("ReplicatedStorage").Shared.UiModel).mapIcon("map.me"), UDim2.fromScale(1, 1), "▲").ZIndex = 8

	-- 테두리(원)
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.BackgroundTransparency = 1
	ring.Size = UDim2.fromScale(1, 1)
	ring.ZIndex = 9
	ring.Parent = root
	Theme.corner(ring, 9999)
	local stroke = Instance.new("UIStroke")
	stroke.Color = UIColors.rim
	stroke.Thickness = 2
	stroke.Parent = ring
	-- QUEUE-ALL8 E2: 북쪽 표지 "N"(테두리 위 - 지도 회전을 켰을 때만 · 북쪽 방향으로 같이 돈다 · 끄면 위가 늘 북쪽이라 숨김)
	local north = Instance.new("TextLabel")
	north.Name = "North"
	north.AnchorPoint = Vector2.new(0.5, 0.5)
	north.Size = UDim2.fromOffset(16, 16)
	north.BackgroundColor3 = UIColors.rim
	north.TextColor3 = Color3.new(1, 1, 1)
	north.Font = Theme.font
	north.TextSize = 11
	north.Text = "N"
	north.ZIndex = 10
	north.Visible = false
	north.Parent = root
	Theme.corner(north, 9999)

	-- 누르면 전체 지도(톱니 밖 전체)
	local open = Instance.new("TextButton")
	open.Name = "OpenMap"
	open.Text = ""
	open.BackgroundTransparency = 1
	open.Size = UDim2.fromScale(1, 1)
	open.ZIndex = 10
	open.Parent = root
	-- QUEUE-ALL7B 4: 아이콘 = 이름 없이 · 올리거나(PC) 누르면(폰 · PC 클릭) 이름 말풍선 - 아이콘 위를 누른 것은 지도 창을 열지 않는다
	local bubble = Instance.new("TextLabel")
	bubble.Name = "NameBubble"
	bubble.AnchorPoint = Vector2.new(0.5, 1)
	bubble.AutomaticSize = Enum.AutomaticSize.X
	bubble.Size = UDim2.fromOffset(0, 20)
	bubble.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
	bubble.BackgroundTransparency = 0.1
	bubble.Font = Theme.font
	bubble.TextSize = 12
	bubble.TextColor3 = Color3.new(1, 1, 1)
	bubble.ZIndex = 12
	bubble.Visible = false
	bubble.Parent = root
	Theme.corner(bubble, 6)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 6), UDim.new(0, 6)
	pad.Parent = bubble
	local bubbleToken, suppressOpenUntil = 0, 0
	local function iconAt(screen)
		local best, bestD = nil, math.huge
		for _, inst in ipairs(refs.icons) do
			if inst.Visible and inst:GetAttribute("PlaceName") then
				local c = inst.AbsolutePosition + inst.AbsoluteSize / 2
				local d = (Vector2.new(screen.X, screen.Y) - c).Magnitude
				if d <= inst.AbsoluteSize.X / 2 + 6 and d < bestD then
					best, bestD = inst, d
				end
			end
		end
		return best
	end
	local function showBubble(inst, seconds)
		bubbleToken += 1
		if not inst then
			bubble.Visible = false
			return
		end
		bubble.Text = inst:GetAttribute("PlaceName")
		bubble.Position = UDim2.fromOffset(inst.AbsolutePosition.X - root.AbsolutePosition.X + inst.AbsoluteSize.X / 2, inst.AbsolutePosition.Y - root.AbsolutePosition.Y - 2)
		bubble.Visible = true
		if seconds then
			local mine = bubbleToken
			task.delay(seconds, function()
				if bubbleToken == mine then
					bubble.Visible = false
				end
			end)
		end
	end
	open.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			showBubble(iconAt(input.Position))
		end
	end)
	open.MouseLeave:Connect(function()
		showBubble(nil)
	end)
	open.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			local inst = iconAt(input.Position)
			if inst then
				suppressOpenUntil = os.clock() + 0.6
				showBubble(inst, 2.5)
			end
		end
	end)
	open.Activated:Connect(function()
		if os.clock() < suppressOpenUntil then
			return
		end
		UIManager.openLazy("worldMap")
	end)

	-- 톱니(설정 메뉴) - 그림 작게 · 터치 44 × 44
	local gear = Instance.new("TextButton")
	gear.Name = "GearButton"
	gear.AnchorPoint = Vector2.new(0.5, 0.5)
	gear.Size = UDim2.fromOffset(GEAR_HIT, GEAR_HIT)
	gear.BackgroundTransparency = 1
	gear.Text = ""
	gear.ZIndex = 12
	gear.Parent = root
	local gearDot = Instance.new("Frame")
	gearDot.Name = "Glyph"
	gearDot.AnchorPoint = Vector2.new(0.5, 0.5)
	gearDot.Position = UDim2.fromScale(0.5, 0.5)
	gearDot.Size = UDim2.fromOffset(24, 24)
	gearDot.BackgroundColor3 = Color3.fromRGB(34, 40, 56)
	gearDot.ZIndex = 12
	gearDot.Parent = gear
	Theme.corner(gearDot, 9999)
	local gearImg = ArtImage.label(gearDot, "icons/hud/settings", UDim2.fromOffset(18, 18), "≡") -- 설정 메뉴 아이콘(HUD 설정과 같은 그림)
	gearImg.AnchorPoint = Vector2.new(0.5, 0.5)
	gearImg.Position = UDim2.fromScale(0.5, 0.5)
	gearImg.ZIndex = 13
	local gs = Instance.new("UIStroke")
	gs.Color = UIColors.rim
	gs.Thickness = 1
	gs.Parent = gearDot

	local menu = Instance.new("Frame")
	menu.Name = "GearMenu"
	menu.AnchorPoint = Vector2.new(1, 0)
	menu.Size = UDim2.fromOffset(170, 6 + 3 * (GEAR_HIT + 4) + 2)
	menu.BackgroundColor3 = Color3.fromRGB(26, 30, 44)
	menu.BackgroundTransparency = 0.05
	menu.Visible = false
	menu.ZIndex = 20
	menu.Parent = gui
	Theme.corner(menu, 10)
	local offBtn = textButton(menu, "MinimapOff", Text.get("minimap.off"), 6)
	local zoomBtn = textButton(menu, "MinimapZoom", "", 6 + GEAR_HIT + 4)
	local rotateBtn = textButton(menu, "MinimapRotate", "", 6 + 2 * (GEAR_HIT + 4))
	local function renderMenu()
		zoomBtn.Text = Text.get(player:GetAttribute("MinimapFar") == true and "minimap.zoomNear" or "minimap.zoomFar")
		rotateBtn.Text = Text.get(rotating() and "minimap.rotateOff" or "minimap.rotateOn")
	end
	gear.Activated:Connect(function()
		menu.Visible = not menu.Visible
		renderMenu()
	end)
	offBtn.Activated:Connect(function()
		menu.Visible = false
		SettingSave("minimapOn", false)
	end)
	zoomBtn.Activated:Connect(function()
		SettingSave("minimapFar", player:GetAttribute("MinimapFar") ~= true)
		renderMenu()
	end)
	rotateBtn.Activated:Connect(function()
		SettingSave("minimapRotate", not rotating())
		renderMenu()
	end)
	refs = { root = root, mapImage = mapImage, overlay = overlay, quest = quest, me = me, gear = gear, menu = menu, icons = {}, dots = {}, bubble = bubble, north = north }
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
local HudData = require(game:GetService("ReplicatedStorage").Shared.data.HudData)
local HudLayout = require(game:GetService("ReplicatedStorage").Shared.data.UiLayoutData).hud
local function place()
	local chips = shownRect("TopChipsRow")
	if not chips then
		return nil
	end
	if HudData.menuV5 and not Theme.isMobile then -- QUEUE-UI2 UI2-4 HUD v5: PC 미니맵 = 재화 왼쪽(UiLayoutData.hud.pc.minimap · 화면 오른쪽 끝 기준 · 원형 그대로)
		local m = HudLayout.pc.minimap
		local screen = gui.AbsoluteSize
		local s = math.min(screen.X / 1920, screen.Y / 1080)
		local size = math.floor(m[3] * s)
		if require(game:GetService("ReplicatedStorage").Shared.data.UiV2Flags).hud then -- UI-1 0단계: 02 v6 (오른쪽 424, 66) · 상단 바 밖 · HUD 배율 m(HudPlace) · 이 Gui = 인셋 아래 좌표
			local HudPlace = require(game:GetService("ReplicatedStorage").Shared.HudPlace)
			local view = workspace.CurrentCamera.ViewportSize
			local r6 = HudLayout.v6.pc.minimap
			local mm = HudPlace.scale(view.X, view.Y, false)
			local r = HudPlace.screenRect(r6, r6.anchor, view.X, view.Y, mm, false)
			local inset = game:GetService("GuiService"):GetGuiInset().Y
			return "side", square(math.floor(r[1] - (view.X - screen.X)), math.floor(r[2] - inset), math.floor(r[3])), chips
		end
		return "side", square(screen.X - math.floor((1920 - m[1]) * s), math.floor(m[2] * s), size), chips
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

local function applyPlace(show)
	local mode, r, chips = nil, nil, nil
	if show then
		mode, r, chips = place()
	else
		chips = shownRect("TopChipsRow")
	end
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
		local arrow = iconPx() + 4
		refs.me.Size = UDim2.fromOffset(arrow, arrow)
		local d = s / 2 * 0.7071 -- 원의 오른쪽 위(45°) 테두리
		refs.gear.Position = UDim2.fromOffset(s / 2 + d, s / 2 - d)
	end
	refs.menu.Position = UDim2.fromOffset(r.min.X - 6, math.clamp(r.min.Y, 0, math.max(0, gui.AbsoluteSize.Y - refs.menu.AbsoluteSize.Y))) -- 미니맵 왼쪽으로 연다(아래는 폰 · 낮은 창에서 잘린다)
	return true
end

-- ═══ 10 Hz 갱신 ═══
-- 원 안으로 붙이기(margin = 아이콘 반) - 밖이면 테두리 안쪽, ok = 원 안이었나
local function rimClamp(offset, margin)
	local limit = size / 2 - margin
	if offset.Magnitude > limit then
		return offset.Unit * limit, false
	end
	return offset, true
end

local function updateDynamic(root)
	local me = root.Position
	local range = rangeStuds()
	local ppu = size / (2 * range) -- px / stud
	local look = root.CFrame.LookVector
	local heading = math.atan2(look.X, -look.Z) -- 북쪽(−Z) 기준 시계 방향(rad)
	local rot = rotating() and -heading or 0 -- 지도 회전(내 방향이 위)
	-- 그림: 보이는 칸 = 반경 range를 덮는 정사각형(회전해도 원 안이 다 차게 √2배)
	-- QUEUE-ALL8 D2: 허브 안 + 보이는 칸이 허브 고해상도 그림 안 = 그 그림(1.6 stud/px) · 아니면 세계 한 장(5.8 stud/px)
	local H = MapImageData.hub
	local useHub = hubImage ~= nil and math.max(math.abs(me.X), math.abs(me.Z)) + range <= H.half
	local img = useHub and hubImage or miniImage
	if refs.mapImage.Image ~= img then
		refs.mapImage.Image = img
	end
	local uv = useHub and MapImageData.toHubUV(me.X, me.Z) or MapImageData.toUV(me.X, me.Z)
	local px = useHub and H.pixels or MapImageData.miniPixels
	-- 회전해도 원(정사각형에 내접)은 돌린 정사각형 안에 늘 다 들어간다 → 같은 칸 · 같은 크기로 Rotation만
	local spanPx = (2 * range) / (2 * (useHub and H.half or MapImageData.half)) * px
	refs.mapImage.ImageRectOffset = Vector2.new(uv.X * px - spanPx / 2, uv.Y * px - spanPx / 2)
	refs.mapImage.ImageRectSize = Vector2.new(spanPx, spanPx)
	refs.mapImage.Rotation = math.deg(rot)
	refs.me.Rotation = rotating() and 0 or math.deg(heading)
	refs.north.Visible = rotating()
	if rotating() then -- 북(월드 −Z)을 화면으로 돌린 방향 = (sin, −cos)(아래 toScreen과 같은 회전) · 테두리 안쪽 반 칸
		local r = size / 2 - 2
		refs.north.Position = UDim2.new(0.5, math.sin(rot) * r, 0.5, -math.cos(rot) * r)
	end
	local cosR, sinR = math.cos(rot), math.sin(rot)
	local function toScreen(p)
		local dx, dz = (p.X - me.X) * ppu, (p.Z - me.Z) * ppu
		return Vector2.new(dx * cosR - dz * sinR, dx * sinR + dz * cosR)
	end
	-- 장소 아이콘: 가까운 순 ICON_MAX · 원 안만
	local px2 = iconPx()
	local sorted = {}
	for _, pl in ipairs(places) do
		table.insert(sorted, { pl = pl, d = (Vector2.new(pl.position.X - me.X, pl.position.Z - me.Z)).Magnitude })
	end
	table.sort(sorted, function(a, b)
		return a.d < b.d
	end)
	for i = 1, math.max(#sorted, #refs.icons) do
		local item = sorted[i]
		local inst = refs.icons[i]
		if item and i <= ICON_MAX then
			local offset, inside = rimClamp(toScreen(item.pl.position), px2 / 2 + 1)
			if not inst or inst.Name ~= "Icon_" .. item.pl.icon then
				if inst then
					inst:Destroy()
				end
				inst = icon(refs.overlay, item.pl.icon, px2, item.pl.color)
				refs.icons[i] = inst
			end
			inst.Visible = inside
			inst:SetAttribute("PlaceName", item.pl.name)
			inst.Position = UDim2.fromOffset(size / 2 + offset.X, size / 2 + offset.Y)
		elseif inst then
			inst.Visible = false
		end
	end
	-- 목적지(밖이면 테두리)
	local dest = Wayfinder.isShowing() and Wayfinder.destination()
	if typeof(dest) == "Vector3" then
		local offset = rimClamp(toScreen(dest), px2 / 2 + 2)
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
			local offset = rimClamp(toScreen(otherRoot.Position), dotPx / 2 + 1)
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
rebuildPlaces()
MapPins.changed:Connect(rebuildPlaces)
for _, name in ipairs({ "ZonesUnlocked", "CheckpointsFound", Text.languageAttribute }) do -- 리뷰: 언어가 바뀌면 말풍선 이름도
	player:GetAttributeChangedSignal(name):Connect(rebuildPlaces)
end
workspace:GetAttributeChangedSignal(Text.devLanguageAttribute):Connect(rebuildPlaces)
player:GetAttributeChangedSignal("MinimapOn"):Connect(function()
	if not enabled() then
		refs.menu.Visible = false
	end
end)
player:GetAttributeChangedSignal("ForceTouchLayout"):Connect(function()
	Theme.recompute()
	size = 0 -- 폰 · PC 크기 · 아이콘 크기 다시
	rebuildPlaces()
end)

-- 검증 · 촬영 훅(Studio): 상태 읽기
if RunService:IsStudio() then
	local hook = Instance.new("BindableFunction")
	hook.Name = "MinimapHook"
	hook.OnInvoke = function()
		return { on = enabled(), shown = refs.root.Visible, size = size, rotate = rotating(), far = player:GetAttribute("MinimapFar") == true, icons = #refs.icons, menu = refs.menu.Visible }
	end
	hook.Parent = gui
end

local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < 1 / MM.updateHz then
		return
	end
	elapsed = 0
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	-- ALL7B 1-6: 켜져 있어도 보스 아레나 · 보스 등장 연출 · 창(모달)이 열려 있으면 잠시 숨김
	local want = enabled() and root ~= nil and player:GetAttribute("BossEncounterId") == nil and not UIManager.isInputBlocked()
	local placed = applyPlace(want)
	local show = want and placed
	refs.root.Visible = show
	-- QUEUE-ALL9A 3-3: 폰 = 위 가운데 알림 줄(TC)이 미니맵을 가리지 않게 알림 폭을 미니맵 왼쪽까지로
	Toast.setRightLimit("TC", (show and Theme.isMobile) and math.floor(refs.root.AbsolutePosition.X - MM.gap) or nil, refs.root.AbsolutePosition.Y)
	if not show then
		refs.menu.Visible = false
		return
	end
	updateDynamic(root)
end)
