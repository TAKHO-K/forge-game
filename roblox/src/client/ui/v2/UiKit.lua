-- QUEUE-UI UI-0 공용 부품(새 화면 전용 - 값은 shared/data/UiTokens · 아이콘은 UiIconData · 좌표는 UiLayoutData에서만).
--   주 버튼(노랑 + 아래턱 + 눌림) · 보조 버튼 · 닫기 · 창(머리 + 노랑 줄) · 카드 · 빈 칸 · 잠긴 칸 · 확인 창(첫 포커스) · 안내 띠 · 토글 · 아이콘 · 아이콘 칸 틀 + 등급 배지 + 강화 칩.
--   rect = { X, Y, W, H }(기준 px - UiRoot 안). 노랑(accent) 주 버튼은 시작 · 구매에만 쓴다(01 spec).
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Tokens = require(ReplicatedStorage.Shared.data.UiTokens)
local IconData = require(ReplicatedStorage.Shared.data.UiIconData)
local ArtAssetIds = require(ReplicatedStorage.Shared.data.ArtAssetIds)
local GradeColor = require(ReplicatedStorage.Shared.GradeColor)
local WeaponFx = require(ReplicatedStorage.Shared.WeaponFx)
local Theme = require(script.Parent.Parent.kit.Theme)

local UiKit = {}

local colorCache = {}
function UiKit.color(token)
	local c = colorCache[token]
	if c then
		return c
	end
	local hex = Tokens.colors[token]
	assert(hex, "UiKit.color: UiTokens에 없는 색 - " .. tostring(token))
	c = Color3.fromHex(hex)
	colorCache[token] = c
	return c
end

function UiKit.isPhone()
	return Theme.isMobile
end

function UiKit.size(name)
	local t = Tokens.text[name]
	assert(t, "UiKit.size: UiTokens.text에 없는 글자 - " .. tostring(name))
	return UiKit.isPhone() and math.max(t.phone, Tokens.minPhoneText) or t.pc
end

function UiKit.font(kind)
	return Enum.Font[Tokens.fonts[kind or "koreanBold"]]
end

function UiKit.place(inst, r)
	inst.Position = UDim2.fromOffset(r[1], r[2])
	inst.Size = UDim2.fromOffset(r[3], r[4])
	return inst
end

local function corner(inst, px)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px)
	c.Parent = inst
	return c
end
local function stroke(inst, token, thickness)
	local s = Instance.new("UIStroke")
	s.Color = UiKit.color(token)
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst
	return s
end
UiKit.corner, UiKit.stroke = corner, stroke

function UiKit.label(parent, text, sizeName, colorToken, props)
	props = props or {}
	local l = Instance.new("TextLabel")
	l.Name = props.name or "Label"
	l.BackgroundTransparency = 1
	l.Font = UiKit.font(props.font)
	l.TextSize = UiKit.size(sizeName)
	l.TextColor3 = UiKit.color(colorToken or "text.primary")
	l.Text = text or ""
	l.TextXAlignment = props.align or Enum.TextXAlignment.Left
	l.TextYAlignment = props.alignY or Enum.TextYAlignment.Center
	l.TextTruncate = props.wrap and Enum.TextTruncate.None or Enum.TextTruncate.AtEnd
	l.TextWrapped = props.wrap == true
	l.RichText = props.rich == true
	if props.rect then
		UiKit.place(l, props.rect)
	end
	l.Parent = parent
	return l
end

-- 버튼(주 = 노랑 · 보조 = 남색): 바닥 Frame(아래턱 색) 위에 얼굴 TextButton이 lip만큼 떠 있다 → 누르면 얼굴이 아래로(눌림)
local LOOKS = {
	primary = { face = "accent", lip = "accent.lip", text = "accent.text", stroke = nil },
	secondary = { face = "panel.slot", lip = "panel.empty", text = "text.primary", stroke = "line" },
}
function UiKit.button(props)
	local look = LOOKS[props.kind or "secondary"]
	assert(look, "UiKit.button: kind - " .. tostring(props.kind))
	local lip = Tokens.lip
	local holder = Instance.new("Frame")
	holder.Name = props.name or "Button"
	holder.BackgroundColor3 = UiKit.color(look.lip)
	holder.BorderSizePixel = 0
	if props.rect then
		UiKit.place(holder, props.rect)
	end
	corner(holder, Tokens.corner.button)
	local face = Instance.new("TextButton")
	face.Name = "Face"
	face.AutoButtonColor = false
	face.Text = ""
	face.BackgroundColor3 = UiKit.color(look.face)
	face.BorderSizePixel = 0
	face.Size = UDim2.new(1, 0, 1, -lip)
	face.Parent = holder
	corner(face, Tokens.corner.button)
	if look.stroke then
		stroke(face, look.stroke, Tokens.stroke.button)
	end
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, props.padX or 22)
	pad.PaddingRight = UDim.new(0, props.padX or 22)
	pad.Parent = face
	local title = UiKit.label(face, props.text, props.textSize or "button", look.text, { name = "Title", align = props.align, font = "korean" })
	title.Size = UDim2.new(1, 0, props.sub and 0.58 or 1, 0)
	local sub = nil
	if props.sub then
		title.TextYAlignment = Enum.TextYAlignment.Bottom
		sub = UiKit.label(face, props.sub, props.subSize or "mainButtonSub", look.text, { name = "Sub", align = props.align })
		sub.Position = UDim2.fromScale(0, 0.6)
		sub.Size = UDim2.new(1, 0, 0.32, 0)
		sub.TextYAlignment = Enum.TextYAlignment.Top
	end
	holder.Parent = props.parent
	local enabled = true
	local function setDown(down)
		face.Position = UDim2.fromOffset(0, down and lip or 0)
	end
	face.InputBegan:Connect(function(input)
		if enabled and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			setDown(true)
		end
	end)
	face.InputEnded:Connect(function()
		setDown(false)
	end)
	face.MouseLeave:Connect(function()
		setDown(false)
	end)
	if props.onActivated then
		face.Activated:Connect(function()
			if enabled then
				props.onActivated()
			end
		end)
	end
	local refs = { root = holder, face = face, title = title, sub = sub }
	function refs.setEnabled(on)
		enabled = on
		face.BackgroundColor3 = UiKit.color(on and look.face or "disabled.bg")
		holder.BackgroundColor3 = UiKit.color(on and look.lip or "panel.empty")
		title.TextColor3 = UiKit.color(on and look.text or "text.muted")
		if sub then
			sub.TextColor3 = title.TextColor3
		end
	end
	function refs.setText(text, subText)
		title.Text = text
		if sub and subText then
			sub.Text = subText
		end
	end
	return refs
end

-- 아이콘(아이콘 표 한 곳): 그림이 있으면 ImageLabel(tint = 바탕 원 없이 글리프 색만 - 칠하기는 부르는 쪽 칸 바탕) · 없으면 fallback 글자
function UiKit.icon(parent, id, sizePx, props)
	props = props or {}
	local def = IconData.icons[id]
	assert(def, "UiKit.icon: UiIconData에 없는 아이콘 - " .. tostring(id))
	local e = def.asset and ArtAssetIds[def.asset]
	local inst
	if e and e.image then
		inst = Instance.new("ImageLabel")
		inst.Image = "rbxassetid://" .. tostring(e.image)
		inst.ScaleType = Enum.ScaleType.Fit
		if def.tint then
			inst.ImageColor3 = UiKit.color(props.color or def.tintFg)
		end
	else
		inst = Instance.new("TextLabel")
		inst.Text = def.fallback or "?"
		inst.Font = UiKit.font("koreanBold")
		inst.TextScaled = true
		inst.TextColor3 = UiKit.color(props.color or def.tintFg or "text.primary")
	end
	inst.Name = "Icon_" .. id
	inst.BackgroundTransparency = 1
	inst.Size = UDim2.fromOffset(sizePx, sizePx)
	if props.center then
		inst.AnchorPoint = Vector2.new(0.5, 0.5)
		inst.Position = UDim2.fromScale(0.5, 0.5)
	end
	inst.Parent = parent
	return inst
end

-- 닫기(빨강 원 44 + 흰 테두리 3 + X) · 눌림 = UIScale 0.92
function UiKit.closeButton(props)
	local b = Instance.new("TextButton")
	b.Name = props.name or "Close"
	b.AutoButtonColor = false
	b.Text = ""
	b.BackgroundColor3 = UiKit.color(props.colorToken or "warning")
	UiKit.place(b, props.rect)
	corner(b, Tokens.close.size)
	stroke(b, "text.primary", Tokens.stroke.close)
	UiKit.icon(b, props.icon or "close", math.floor(props.rect[3] * 0.5), { center = true, color = "text.primary" })
	local s = Instance.new("UIScale")
	s.Parent = b
	b.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			s.Scale = Tokens.close.pressScale
		end
	end)
	b.InputEnded:Connect(function()
		s.Scale = 1
	end)
	if props.onActivated then
		b.Activated:Connect(props.onActivated)
	end
	b.Parent = props.parent
	return b
end

-- 창: 몸통 + 머리(제목 · 보조 글) + 머리 아래 노랑 줄 → { root, head, body, title, sub }
function UiKit.window(props)
	local phone = UiKit.isPhone()
	local headH = phone and Tokens.windowHead.phone or Tokens.windowHead.pc
	local lineH = phone and Tokens.windowLine.phone or Tokens.windowLine.pc
	local root = Instance.new("Frame")
	root.Name = props.name or "Window"
	root.BackgroundColor3 = UiKit.color("panel.window")
	UiKit.place(root, props.rect)
	corner(root, Tokens.corner.window)
	stroke(root, "line", Tokens.stroke.window)
	root.ClipsDescendants = false
	local head = Instance.new("Frame")
	head.Name = "Head"
	head.BackgroundColor3 = UiKit.color("panel.section")
	head.Size = UDim2.new(1, 0, 0, headH)
	head.Parent = root
	corner(head, Tokens.corner.window)
	local headFill = Instance.new("Frame") -- 머리 아래 모서리는 각지게
	headFill.Name = "HeadFill"
	headFill.BackgroundColor3 = head.BackgroundColor3
	headFill.BorderSizePixel = 0
	headFill.Position = UDim2.new(0, 0, 1, -Tokens.corner.window)
	headFill.Size = UDim2.new(1, 0, 0, Tokens.corner.window)
	headFill.Parent = head
	local line = Instance.new("Frame")
	line.Name = "AccentLine"
	line.BackgroundColor3 = UiKit.color("accent")
	line.BorderSizePixel = 0
	line.Position = UDim2.fromOffset(0, headH)
	line.Size = UDim2.new(1, 0, 0, lineH)
	line.Parent = root
	local title = UiKit.label(head, props.title, "windowTitle", "text.primary", { name = "Title", font = "korean" })
	title.Position = UDim2.fromOffset(phone and 56 or 24, 0)
	title.Size = UDim2.new(0.6, 0, 1, 0)
	title.AutomaticSize = Enum.AutomaticSize.X
	local sub = nil
	if props.sub then
		sub = UiKit.label(head, props.sub, "cardInfo", "text.secondary", { name = "Sub", font = "number" })
		sub.Size = UDim2.new(0.3, 0, 1, 0)
	end
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(0, headH + lineH)
	body.Size = UDim2.new(1, 0, 1, -(headH + lineH))
	body.Parent = root
	root.Parent = props.parent
	return { root = root, head = head, body = body, title = title, sub = sub, headH = headH + lineH }
end

-- 카드(캐릭터 · 직업) - selected = 노랑 테두리 3
function UiKit.card(parent, rect, selected, name)
	local f = Instance.new("TextButton")
	f.Name = name or "Card"
	f.AutoButtonColor = false
	f.Text = ""
	f.BackgroundColor3 = UiKit.color("panel.section")
	UiKit.place(f, rect)
	corner(f, Tokens.corner.card)
	local s = stroke(f, selected and "accent" or "panel.slot", selected and Tokens.stroke.cardSelected or Tokens.stroke.card)
	f.Parent = parent
	local refs = { root = f, stroke = s }
	function refs.setSelected(on)
		s.Color = UiKit.color(on and "accent" or "panel.slot")
		s.Thickness = on and Tokens.stroke.cardSelected or Tokens.stroke.card
	end
	return refs
end

-- 빈 칸(실선 - 점선 쓰지 않음) + 노랑 + 아이콘 · 글
function UiKit.emptySlot(parent, rect, text, sub, name)
	local f = Instance.new("TextButton")
	f.Name = name or "EmptySlot"
	f.AutoButtonColor = false
	f.Text = ""
	f.BackgroundColor3 = UiKit.color("panel.empty")
	UiKit.place(f, rect)
	corner(f, Tokens.corner.card)
	stroke(f, "line", Tokens.stroke.slotEmpty)
	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 1)
	row.Parent = f
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 12)
	list.Parent = row
	local circle = Instance.new("Frame")
	circle.Name = "PlusCircle"
	circle.BackgroundColor3 = UiKit.color("panel.slot")
	local c = UiKit.isPhone() and 32 or 46
	circle.Size = UDim2.fromOffset(c, c)
	corner(circle, c)
	circle.LayoutOrder = 1
	circle.Parent = row
	UiKit.icon(circle, "plus", math.floor(c * 0.6), { center = true })
	local t = UiKit.label(row, text, "cardName", "text.primary", { name = "Title", font = "korean" })
	t.AutomaticSize = Enum.AutomaticSize.X
	t.Size = UDim2.new(0, 0, 1, 0)
	t.LayoutOrder = 2
	if sub and not UiKit.isPhone() then
		local s2 = UiKit.label(row, sub, "cardInfo", "text.secondary", { name = "Sub" })
		s2.AutomaticSize = Enum.AutomaticSize.X
		s2.Size = UDim2.new(0, 0, 1, 0)
		s2.LayoutOrder = 3
	end
	f.Parent = parent
	return f
end

-- 잠긴 칸(누를 수 없음) + 자물쇠 + 글
function UiKit.lockedSlot(parent, rect, text, name)
	local f = Instance.new("Frame")
	f.Name = name or "LockedSlot"
	f.BackgroundColor3 = UiKit.color("panel.locked")
	UiKit.place(f, rect)
	corner(f, Tokens.corner.card)
	stroke(f, "panel.section", Tokens.stroke.slotLocked)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 1)
	row.Parent = f
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 10)
	list.Parent = row
	UiKit.icon(row, "lock", UiKit.isPhone() and 16 or 22).LayoutOrder = 1
	local t = UiKit.label(row, text, "cardInfo", "text.muted", { name = "Title", font = "korean" })
	t.AutomaticSize = Enum.AutomaticSize.X
	t.Size = UDim2.new(0, 0, 1, 0)
	t.LayoutOrder = 2
	f.Parent = parent
	return f
end

-- 안내 띠(구경 모드 등): 높이 64(폰 52) + 아래 info 선 3 + 정보 아이콘
function UiKit.band(parent, rect, text)
	local f = Instance.new("Frame")
	f.Name = "Band"
	f.BackgroundColor3 = UiKit.color("panel.section")
	f.BorderSizePixel = 0
	UiKit.place(f, rect)
	local line = Instance.new("Frame")
	line.Name = "InfoLine"
	line.BackgroundColor3 = UiKit.color("info")
	line.BorderSizePixel = 0
	line.Position = UDim2.new(0, 0, 1, -3)
	line.Size = UDim2.new(1, 0, 0, 3)
	line.Parent = f
	local icon = UiKit.icon(f, "info", UiKit.isPhone() and 22 or 30)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, UiKit.isPhone() and 56 or 150, 0.5, -1)
	local l = UiKit.label(f, text, "cardInfo", "text.primary", { name = "Text", font = "korean" })
	l.Position = UDim2.new(0, (UiKit.isPhone() and 56 or 150) + 40, 0, 0)
	l.Size = UDim2.new(1, -((UiKit.isPhone() and 56 or 150) + 52), 1, -3)
	l.TextWrapped = true
	f.Parent = parent
	return { root = f, label = l }
end

-- 토글(켜짐 = success · 꺼짐 = slot) → { root, set(v), get() }
function UiKit.toggle(parent, rect, value, onChanged)
	local b = Instance.new("TextButton")
	b.Name = "Toggle"
	b.AutoButtonColor = false
	b.Text = ""
	UiKit.place(b, rect)
	corner(b, rect[4])
	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.BackgroundColor3 = UiKit.color("text.primary")
	knob.Size = UDim2.fromOffset(rect[4] - 8, rect[4] - 8)
	corner(knob, rect[4])
	knob.Parent = b
	local v = value == true
	local function paint()
		b.BackgroundColor3 = UiKit.color(v and "success" or "panel.slot")
		knob.Position = v and UDim2.new(1, -(rect[4] - 4), 0, 4) or UDim2.fromOffset(4, 4)
	end
	b.Activated:Connect(function()
		v = not v
		paint()
		if onChanged then
			onChanged(v)
		end
	end)
	paint()
	b.Parent = parent
	return { root = b, set = function(x) v = x == true paint() end, get = function() return v end }
end

-- 확인 창(모달): dim 위 창 · 열 때 UIScale 0.9 → 1 · 첫 포커스 = props.focus("cancel" 기본) · Enter = 첫 포커스 버튼.
--   props = { parent(UiRoot.frame), rect, title, body, sub, cancelText, okText, okKind("secondary" 기본 - 노랑은 시작 · 구매만), cancelRect, okRect, onAnswer(bool) }
function UiKit.confirm(props)
	local dim = Instance.new("TextButton")
	dim.Name = props.name or "ConfirmDim"
	dim.AutoButtonColor = false
	dim.Text = ""
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = Tokens.dimTransparency
	dim.Size = UDim2.fromScale(1, 1)
	dim.ZIndex = 50
	local win = UiKit.window({ parent = dim, rect = props.rect, title = props.title, name = "ConfirmWindow" })
	win.root.ZIndex = 51
	for _, d in ipairs(win.root:GetDescendants()) do
		if d:IsA("GuiObject") then
			d.ZIndex = 51
		end
	end
	local body = UiKit.label(win.body, props.body, "confirmBody", "text.primary", { name = "Body", wrap = true, font = "korean" })
	body.Position = UDim2.fromOffset(24, 16)
	body.Size = UDim2.new(1, -48, 0, 60)
	body.TextYAlignment = Enum.TextYAlignment.Top
	if props.sub then
		local s = UiKit.label(win.body, props.sub, "confirmSub", "text.secondary", { name = "Sub", wrap = true })
		s.Position = UDim2.fromOffset(24, 76)
		s.Size = UDim2.new(1, -48, 0, 40)
		s.TextYAlignment = Enum.TextYAlignment.Top
	end
	local answered = false
	local function answer(v)
		if answered then
			return
		end
		answered = true
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(dim) then
			GuiService.SelectedObject = nil
		end
		dim:Destroy()
		if props.onAnswer then
			props.onAnswer(v)
		end
	end
	local cancel = UiKit.button({ parent = win.root, kind = "secondary", name = "Cancel", rect = props.cancelRect, text = props.cancelText, align = Enum.TextXAlignment.Center, textSize = "button", onActivated = function() answer(false) end })
	local ok = UiKit.button({ parent = win.root, kind = props.okKind or "secondary", name = "Ok", rect = props.okRect, text = props.okText, align = Enum.TextXAlignment.Center, textSize = "button", onActivated = function() answer(true) end })
	for _, b in ipairs({ cancel, ok }) do
		for _, d in ipairs(b.root:GetDescendants()) do
			if d:IsA("GuiObject") then
				d.ZIndex = 52
			end
		end
		b.root.ZIndex = 52
	end
	local first = props.focus == "ok" and ok or cancel
	first.face.SelectionImageObject = nil
	local focusStroke = stroke(first.face, "accent", 3) -- 첫 포커스 표시
	focusStroke.Name = "FocusStroke"
	local scale = Instance.new("UIScale")
	scale.Scale = Tokens.confirmOpenScale
	scale.Parent = win.root
	dim.Parent = props.parent
	TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	pcall(function()
		GuiService.SelectedObject = first.face
	end)
	local conn
	conn = UserInputService.InputBegan:Connect(function(input)
		if answered then
			conn:Disconnect()
			return
		end
		if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter then
			answer(first == ok)
		elseif input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace then
			answer(false)
		end
	end)
	return { root = dim, cancel = cancel, ok = ok, first = first, answer = answer }
end

-- 아이콘 칸 틀 + 등급 배지 + 강화 칩(07-B 계승 전 +20 ~ +30 띠 · 07-C 초월 = shared/WeaponFx.stepOf 한 판정).
--   props = { parent, rect, gradeId, level, transcendLevel, iconKey(ArtAssetIds 키 - 무기 = icons/weapons/<직업>_<등급>) }
function UiKit.iconSlot(props)
	local f = Instance.new("Frame")
	f.Name = props.name or "IconSlot"
	f.BackgroundColor3 = UiKit.color("panel.slot")
	UiKit.place(f, props.rect)
	corner(f, Tokens.corner.card)
	local border = GradeColor.border(props.gradeId or "normal")
	local s = Instance.new("UIStroke")
	s.Color = typeof(border) == "Color3" and border or UiKit.color("line")
	s.Thickness = 3
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = f
	local e = props.iconKey and ArtAssetIds[props.iconKey]
	if e and e.image then
		local img = Instance.new("ImageLabel")
		img.Name = "Icon"
		img.BackgroundTransparency = 1
		img.Image = "rbxassetid://" .. tostring(e.image)
		img.ScaleType = Enum.ScaleType.Fit
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.fromScale(0.5, 0.5)
		img.Size = UDim2.fromScale(0.86, 0.86)
		img.Parent = f
	end
	local level = tonumber(props.level) or 0
	local step = WeaponFx.stepOf(props.gradeId, level, props.transcendLevel)
	local chipText = (props.gradeId == "transcendent" and props.transcendLevel) and ("+" .. tostring(props.transcendLevel)) or (level > 0 and ("+" .. level) or nil)
	if chipText then
		local chip = Instance.new("TextLabel")
		chip.Name = "EnhanceChip"
		chip.Font = UiKit.font("number")
		chip.TextScaled = true
		chip.Text = chipText
		chip.BackgroundColor3 = UiKit.color("bg.deep")
		chip.AnchorPoint = Vector2.new(0, 1)
		chip.Position = UDim2.new(0, 4, 1, -4)
		chip.Size = UDim2.new(0.55, 0, 0.26, 0)
		local band = step and step.band and step.band.hex
		chip.TextColor3 = band and Color3.fromHex(band) or (step and step.kind == "transcend" and UiKit.color("title.sub") or UiKit.color("accent"))
		corner(chip, Tokens.corner.chip)
		local cs = Instance.new("UIStroke")
		cs.Color = chip.TextColor3
		cs.Thickness = 1.5
		cs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		cs.Parent = chip
		chip.Parent = f
	end
	f.Parent = props.parent
	return f
end

return UiKit
