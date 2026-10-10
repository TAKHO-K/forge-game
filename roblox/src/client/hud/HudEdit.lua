-- UI-1 7b단계 HUD 편집 모드(08 v7 §6 · pc_09 · pc_10 · ph_06): 화면 35% 어둡게 + 격자 24(폰 16) · 옮길 요소 = 하늘 테 + 이름표 · 끌기 = 노랑 테 · 놓으면 격자에 붙음 ·
--   금지 자리(상단 바 · 로블록스 버튼 · 화면 밖) = 회색 + 자물쇠 이름표 · 놓으면 원래 자리 · 요소끼리 겹침 = 호박 테 + "다른 요소와 겹쳐요"(저장 가능) ·
--   편집 줄 = [한 번 되돌리기] [처음 위치로] [저장하고 나가기] · 저장 = SettingsSave(hudLayoutPc | hudLayoutPhone · hudLayoutVersion) → 토스트 · 전투 · 보스전 중 = 못 들어감(이유 토스트).
--   편집 중 = UIManager window(게임 입력 막힘 · 걷기 0) · 미리보기 = Attribute HudLayoutPreview(HudLayoutApply가 실제 HUD를 같이 옮김).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local HudEditRules = require(ReplicatedStorage.Shared.HudEditRules)
local HudPlace = require(ReplicatedStorage.Shared.HudPlace)
local Text = require(ReplicatedStorage.Shared.Text)
local E = require(ReplicatedStorage.Shared.data.UiLayoutData).hudEdit.v7
local UiKit = require(script.Parent.Parent.ui.v2.UiKit)
local UIManager = require(script.Parent.Parent.UIManager)
local Toast = require(script.Parent.Parent.ui.kit.Toast)
local Confirm = require(script.Parent.Parent.ui.kit.Confirm)

local HudEdit = {}
HudEdit.id = "hudEdit"

local player = Players.LocalPlayer
local saveRemote = ReplicatedStorage:WaitForChild("SettingsSave")
local gui, state = nil, nil -- state = { device, m, positions = { id = { x, y } }, history = {}, boxes = {} }

local function hex(h)
	return Color3.fromHex(h)
end

local function deviceNow()
	local cam = workspace.CurrentCamera
	local v = cam.ViewportSize
	local phone = HudPlace.isPhone(v.X, v.Y, UserInputService.TouchEnabled, UserInputService.KeyboardEnabled) or ReplicatedStorage:GetAttribute("ForceTouchLayout") == true
	return phone and "phone" or "pc", HudPlace.scale(math.max(v.X, 1), math.max(v.Y, 1), phone), v
end

-- 기준 px 사각형 → 화면 px(상단 바 포함 좌표 · IgnoreGuiInset 화면)
local function toScreen(e, x, y)
	local r = HudPlace.screenRect({ x, y, e.rect[3], e.rect[4] }, e.anchor, state.view.X, state.view.Y, state.m, state.device == "phone")
	return r
end

local function snap(v)
	local g = E.grid[state.device]
	return math.floor(v / g + 0.5) * g
end

local function preview()
	player:SetAttribute("HudLayoutPreview", HudEditRules.serialize(state.positions, state.device))
end

local function renderBoxes()
	local overl = {}
	for _, pair in ipairs(HudEditRules.overlaps(state.device, state.positions)) do
		overl[pair[1]], overl[pair[2]] = true, true
	end
	for id, b in pairs(state.boxes) do
		local e = b.e
		local p = state.positions[id] or { e.rect[1], e.rect[2] }
		local r = toScreen(e, p[1], p[2])
		local c = state.corr[id] or Vector2.zero -- 모듈이 기준 자리에서 따로 옮긴 만큼(다음 목표 카드 = 칩 줄 따라감)
		b.frame.Position = UDim2.fromOffset(r[1] + c.X, r[2] + c.Y)
		b.frame.Size = UDim2.fromOffset(r[3], r[4])
		b.stroke.Color = b.dragging and hex(E.colors.drag) or (overl[id] and hex(E.colors.overlap) or hex(E.colors.box))
		b.warn.Visible = overl[id] == true and not b.dragging
	end
	preview()
end

local function pushHistory()
	local copy = {}
	for k, v in pairs(state.positions) do
		copy[k] = { v[1], v[2] }
	end
	table.insert(state.history, copy)
	if #state.history > 30 then
		table.remove(state.history, 1)
	end
end

local function makeBox(parent, e)
	local f = Instance.new("TextButton")
	f.Name = "Box_" .. e.id
	f.Text = ""
	f.AutoButtonColor = false
	f.BackgroundColor3 = hex(E.colors.box)
	f.BackgroundTransparency = e.ghost and 0.9 or 0.8
	f.ZIndex = 5
	f.Parent = parent
	local st = Instance.new("UIStroke")
	st.Thickness = 3
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = f
	local tag = UiKit.label(f, Text.get(e.label), "caption", "text.primary", { name = "Tag" })
	tag.BackgroundTransparency = 0.1
	tag.BackgroundColor3 = hex(E.colors.bar)
	tag.AutomaticSize = Enum.AutomaticSize.X
	tag.Size = UDim2.fromOffset(0, 22)
	tag.Position = UDim2.fromOffset(0, -24)
	tag.ZIndex = 7
	UiKit.corner(tag, 6)
	local warn = UiKit.label(f, Text.get("ui1.hudEdit.overlap"), "caption", "text.primary", { name = "Warn" })
	warn.TextColor3 = hex(E.colors.overlap)
	warn.AutomaticSize = Enum.AutomaticSize.X
	warn.Size = UDim2.fromOffset(0, 20)
	warn.Position = UDim2.new(0, 0, 1, 2)
	warn.ZIndex = 7
	warn.Visible = false
	local b = { e = e, frame = f, stroke = st, warn = warn }
	local dragStart, from
	f.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			local p = state.positions[e.id] or { e.rect[1], e.rect[2] }
			dragStart, from = Vector2.new(input.Position.X, input.Position.Y), { p[1], p[2] }
			b.dragging = true
			pushHistory()
			renderBoxes()
		end
	end)
	-- UI-1b 0절(VERIFY-5): 전역 입력 연결은 state.conns에 모아 close에서 끊는다(옛 = 편집 모드에 들어갈 때마다 쌓임)
	table.insert(state.conns, UserInputService.InputChanged:Connect(function(input)
		if dragStart and state and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = (Vector2.new(input.Position.X, input.Position.Y) - dragStart) / state.m
			state.positions[e.id] = { from[1] + d.X, from[2] + d.Y }
			renderBoxes()
		end
	end))
	table.insert(state.conns, UserInputService.InputEnded:Connect(function(input)
		if dragStart and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragStart = nil
			b.dragging = false
			if state then
				local p = state.positions[e.id]
				local x, y = snap(p[1]), snap(p[2])
				if HudEditRules.placeOk(state.device, e.rect, x, y) then
					state.positions[e.id] = { x, y }
				else -- 금지 자리 · 화면 밖 = 원래 자리로
					state.positions[e.id] = from
					Toast.push("TC", { text = Text.get("ui1.hudEdit.forbidden"), colorName = "textPrimary" })
				end
				renderBoxes()
			end
		end
	end))
	return b
end

local function close(saveIt)
	if not state then
		return
	end
	if saveIt then
		local key = state.device == "phone" and "hudLayoutPhone" or "hudLayoutPc"
		local value = HudEditRules.serialize(state.positions, state.device)
		player:SetAttribute(state.device == "phone" and "HudLayoutPhone" or "HudLayoutPc", value)
		saveRemote:FireServer(key, value)
		saveRemote:FireServer("hudLayoutVersion", E.version)
		Toast.push("TC", { text = Text.get("ui1.hudEdit.saved", { device = Text.get(state.device == "phone" and "ui1.hudEdit.phone" or "ui1.hudEdit.pc") }), colorName = "success" })
	end
	player:SetAttribute("HudLayoutPreview", nil)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum and state.walk then
		hum.WalkSpeed = state.walk
	end
	for _, c in ipairs(state.conns) do
		c:Disconnect()
	end
	state = nil
	if gui then
		gui:Destroy()
		gui = nil
	end
	if UIManager.isOpen(HudEdit.id) then
		UIManager.close(HudEdit.id)
	end
end

local function build()
	local device, m, view = deviceNow()
	local cur = HudEditRules.parse(player:GetAttribute(device == "phone" and "HudLayoutPhone" or "HudLayoutPc"))
	state = { device = device, m = m, view = view, positions = cur, history = {}, boxes = {}, corr = {}, conns = {} }
	local inset = game:GetService("GuiService"):GetGuiInset().Y
	for _, e in ipairs(HudEditRules.elements(device)) do -- 실제 프레임이 보이면 그 자리에 상자를 맞춘다(보정 = 실제 − 기준 계산)
		local node = player.PlayerGui
		for part in (e.paths[1] or ""):gmatch("[^/]+") do
			node = node and node:FindFirstChild(part)
		end
		if node and node:IsA("GuiObject") and node.AbsoluteSize.X > 0 and node.AbsoluteSize.Y > 0 and not e.ghost then
			local p = cur[e.id] or { e.rect[1], e.rect[2] }
			local r = HudPlace.screenRect({ p[1], p[2], e.rect[3], e.rect[4] }, e.anchor, view.X, view.Y, m, device == "phone")
			local d = Vector2.new(node.AbsolutePosition.X - r[1], node.AbsolutePosition.Y + inset - r[2])
			local sameSize = math.abs(node.AbsoluteSize.X - r[3]) <= r[3] * 0.3 and math.abs(node.AbsoluteSize.Y - r[4]) <= r[4] * 0.3 -- 프레임 = 그 요소 모양일 때만(왼쪽 메뉴 루트 = 화면 크기 · 체력 + 상태 = 묶음은 제외)
			if sameSize and d.Magnitude < 300 then
				state.corr[e.id] = d
			end
		end
	end
	gui = Instance.new("ScreenGui")
	gui.Name = "HudEditGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = E.displayOrder
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- Instance.new 기본(Global)이면 편집 줄 버튼 글자가 줄 뒤로 숨는다
	gui.Parent = player:WaitForChild("PlayerGui")
	local dim = Instance.new("TextButton") -- 35% 어둡게 + 바깥 입력 막기
	dim.Name = "Dim"
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 1 - E.colors.dim
	dim.Size = UDim2.fromScale(1, 1)
	dim.Parent = gui
	-- 격자(기준 px 간격 × m)
	local g = E.grid[device] * m
	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.fromScale(1, 1)
	grid.ZIndex = 2
	grid.Parent = gui
	for x = 0, view.X, g do
		local l = Instance.new("Frame")
		l.BorderSizePixel = 0
		l.BackgroundColor3 = Color3.new(1, 1, 1)
		l.BackgroundTransparency = 0.88
		l.Position = UDim2.fromOffset(x, 0)
		l.Size = UDim2.new(0, 1, 1, 0)
		l.ZIndex = 2
		l.Parent = grid
	end
	for y = 0, view.Y, g do
		local l = Instance.new("Frame")
		l.BorderSizePixel = 0
		l.BackgroundColor3 = Color3.new(1, 1, 1)
		l.BackgroundTransparency = 0.88
		l.Position = UDim2.fromOffset(0, y)
		l.Size = UDim2.new(1, 0, 0, 1)
		l.ZIndex = 2
		l.Parent = grid
	end
	-- 금지 자리(회색 + 자물쇠 이름표)
	for _, f in ipairs(HudEditRules.forbidden(device)) do
		local r = HudPlace.screenRect(f, "TL", view.X, view.Y, m, device == "phone")
		if f[3] >= HudPlace.base[device].w - 1 then -- 상단 바 = 화면 폭 전체 · 화면 px 58 고정
			r = { 0, 0, view.X, HudPlace.topBarPx }
		end
		local z = Instance.new("Frame")
		z.Name = "Forbidden"
		z.BackgroundColor3 = hex(E.colors.forbidden)
		z.BackgroundTransparency = 0.45
		z.Position = UDim2.fromOffset(r[1], r[2])
		z.Size = UDim2.fromOffset(r[3], r[4])
		z.ZIndex = 3
		z.Parent = gui
		local t = UiKit.label(z, Text.get("ui1.hudEdit.forbiddenTag"), "caption", "text.primary", { name = "Tag", align = Enum.TextXAlignment.Center })
		t.Size = UDim2.fromScale(1, 1)
		t.ZIndex = 4
		local lock = UiKit.icon(z, "lock", 16)
		lock.AnchorPoint = Vector2.new(1, 0.5)
		lock.Position = UDim2.new(0.5, -(t.TextBounds.X / 2 + 4), 0.5, 0)
		lock.ZIndex = 4
	end
	for _, e in ipairs(HudEditRules.elements(device)) do
		state.boxes[e.id] = makeBox(gui, e)
	end
	-- 편집 줄
	local B = E.bar[device]
	local bar = Instance.new("Frame")
	bar.Name = "EditBar"
	bar.BackgroundColor3 = hex(E.colors.bar)
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, HudPlace.topBarPx + (B.y - HudPlace.topBarPx) * m)
	bar.Size = UDim2.fromOffset((device == "phone" and 560 or 900) * m, B.h * m)
	bar.ZIndex = 10
	bar.Parent = gui
	UiKit.corner(bar, 12)
	local sc = Instance.new("UIScale")
	sc.Scale = 1
	sc.Parent = bar
	local icon = UiKit.icon(bar, "hud-edit", B.h * m * 0.6)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 10, 0.5, 0)
	icon.ZIndex = 11
	local title = UiKit.label(bar, Text.get("ui1.hudEdit.title", { device = Text.get(device == "phone" and "ui1.hudEdit.phone" or "ui1.hudEdit.pc") }), "caption", "text.primary", { name = "Title" })
	title.Position = UDim2.fromOffset(B.h * m * 0.6 + 18, 0)
	title.Size = UDim2.new(0.35, 0, 1, 0)
	title.ZIndex = 11
	if require(ReplicatedStorage.Shared.data.UiV2Flags).help then -- UI-1b 1절 3: 편집 규칙(옮기기 · 금지 자리 · 겹침) = 제목 옆 [?]
		require(script.Parent.Parent.ui.v2.HelpButton).besideLabel(title, "hudEdit", { zIndex = 12 })
	end
	local bw, bh = (device == "phone" and 110 or 200) * m, (B.h - 12) * m
	local function btn(name, textKey, kind, i, fn)
		local b = UiKit.button({ parent = bar, kind = kind, name = name, text = Text.get(textKey), align = Enum.TextXAlignment.Center, padX = 6,
			rect = { bar.Size.X.Offset - i * (bw + 8), 6 * m, bw, bh }, onActivated = fn })
		b.root.ZIndex = 11
		return b
	end
	btn("SaveExit", device == "phone" and "ui1.hudEdit.saveShort" or "ui1.hudEdit.save", "primary", 1, function()
		close(true)
	end)
	btn("Reset", device == "phone" and "ui1.hudEdit.resetShort" or "ui1.hudEdit.reset", "secondary", 2, function()
		pushHistory()
		table.clear(state.positions)
		renderBoxes()
	end)
	btn("Undo", device == "phone" and "ui1.hudEdit.undoShort" or "ui1.hudEdit.undo", "secondary", 3, function()
		local last = table.remove(state.history)
		if last then
			state.positions = last
			renderBoxes()
		end
	end)
	-- 바깥(딤) 누름 · Esc = 저장 안 하고 나갈까요?
	dim.Activated:Connect(function()
		Confirm.ask({ title = Text.get("ui1.hudEdit.exitTitle"), body = Text.get("ui1.hudEdit.exitBody"), primaryText = Text.get("ui1.hudEdit.keepEditing"), secondaryText = Text.get("ui1.hudEdit.exitNoSave"), parentId = HudEdit.id },
			function(keep)
				if keep == false then
					close(false)
				end
			end)
	end)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then -- 게임 조작 멈춤(걷기) · 공격 · 스킬 = UIManager window가 막음
		state.walk = hum.WalkSpeed
		hum.WalkSpeed = 0
	end
	renderBoxes()
end

-- 들어가기: 전투 · 보스전 중 = 못 들어감
function HudEdit.enter()
	if state then
		return
	end
	if player:GetAttribute("BossEncounterId") ~= nil or player:GetAttribute("InCombat") == true then
		Toast.push("TC", { text = Text.get("ui1.hudEdit.townOnly"), colorName = "textPrimary" })
		return
	end
	if not UIManager.getKind(HudEdit.id) then
		UIManager.register(HudEdit.id, { kind = "window", hasCloseButton = true, onClose = function()
			if state then -- Esc 등으로 닫힘 = 저장 안 함
				close(false)
			end
		end })
	end
	UIManager.closeAll()
	UIManager.open(HudEdit.id)
	build()
end

-- 처음 위치로(설정 › 조작 · 확인 2단계 뒤): 이 기기 배치만 비움
function HudEdit.resetSaved()
	local device = deviceNow()
	player:SetAttribute(device == "phone" and "HudLayoutPhone" or "HudLayoutPc", "")
	saveRemote:FireServer(device == "phone" and "hudLayoutPhone" or "hudLayoutPc", "")
	Toast.push("TC", { text = Text.get("ui1.hudEdit.resetDone"), colorName = "success" })
end

function HudEdit.isEditing()
	return state ~= nil
end

return HudEdit
