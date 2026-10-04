-- QUEUE-UI UI-0 공용 부품(새 화면 전용 - 값은 shared/data/UiTokens · 아이콘은 UiIconData · 좌표는 UiLayoutData에서만).
--   주 버튼 · 보조 버튼 · 닫기 · 창(머리 + 노랑 줄) · 카드 · 빈 칸 · 잠긴 칸 · 확인 창(첫 포커스) · 안내 띠 · 토글 · 아이콘 · 아이콘 칸 틀 + 등급 배지 + 강화 칩.
--   rect = { X, Y, W, H }(기준 px - UiRoot 안). 노랑(pri) 주 버튼은 시작 · 구매에만 · 빨강(danger)은 확인 창 안에서만(00 spec).
--   QUEUE-UI2 UI2-2: 버튼 = 9-slice 상태 그림 5개(00 spec) + 손맛(UiKit.attachPress - shared/ButtonPress 판정) · 글자 = UiModel.textPx(설정 글자 크기 · PreferredTextSize · 루트 배율 보정).
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Tokens = require(ReplicatedStorage.Shared.data.UiTokens)
local IconData = require(ReplicatedStorage.Shared.data.UiIconData)
local ArtAssetIds = require(ReplicatedStorage.Shared.data.ArtAssetIds)
local GradeColor = require(ReplicatedStorage.Shared.GradeColor)
local WeaponFx = require(ReplicatedStorage.Shared.WeaponFx)
local UiModel = require(ReplicatedStorage.Shared.UiModel)
local ButtonPress = require(ReplicatedStorage.Shared.ButtonPress)
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

-- 글자 크기(UI2-2): 토큰 × max(설정 글자 크기, 로블록스 PreferredTextSize) × 루트 배율 보정(UiModel.textPx). 루트 배율 = UiRoot가 알려 준다.
UiKit.rootScale = 1
local function platformTextName()
	local ok, v = pcall(function()
		return GuiService.PreferredTextSize
	end)
	return ok and v and v.Name or "Medium"
end
UiKit.platformTextName = platformTextName
function UiKit.textStep()
	local lp = Players.LocalPlayer
	return lp and lp:GetAttribute("UiTextScale") or "normal"
end
function UiKit.size(name)
	return UiModel.textPx(name, UiKit.isPhone(), UiKit.textStep(), platformTextName(), UiKit.rootScale)
end

-- 글자 칸 등록 → 설정 · 루트 배율 · PreferredTextSize가 바뀌면 다시 계산. 강한 표 + Destroying에서 지움(Instance 키 약한 표는 프록시가 수거되어 조용히 빠진다)
local textLabels = {}
function UiKit.setTextSize(label, name)
	if textLabels[label] == nil then
		label.Destroying:Connect(function()
			textLabels[label] = nil
		end)
	end
	textLabels[label] = name
	label.TextSize = UiKit.size(name)
end
function UiKit.refreshText()
	for label, name in pairs(textLabels) do
		if label.Parent then
			label.TextSize = UiKit.size(name)
		end
	end
end
function UiKit.setRootScale(s)
	if s and s > 0 and math.abs(s - UiKit.rootScale) > 1e-4 then
		UiKit.rootScale = s
		UiKit.refreshText()
	end
end
do
	local lp = Players.LocalPlayer
	if lp then
		lp:GetAttributeChangedSignal("UiTextScale"):Connect(UiKit.refreshText)
	end
	pcall(function()
		GuiService:GetPropertyChangedSignal("PreferredTextSize"):Connect(UiKit.refreshText)
	end)
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
	UiKit.setTextSize(l, sizeName)
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

-- ── 버튼 손맛(UI2-2 · 00 spec "버튼 상태 5개") ──
--   상태 그림 = ui/ds/btn-<종류>-<normal|hover|pressed|disabled>(9-slice · SliceScale 0.5) · 누름 = 그림 교체 + UIScale 0.95(0.06초 Quad) · 뗌 = 1.0(0.10초 Back Out).
--   판정 = shared/ButtonPress(뗄 때만 · 밖으로 끌면 풀림 · 다시 들어오면 복귀 · 스크롤 목록 8px 끌기 취소 · 전투 = 누르는 순간). Activated는 쓰지 않는다.
local P = Tokens.press
local function stateImage(kind, state)
	local e = kind and ArtAssetIds["ui/ds/btn-" .. kind .. "-" .. state]
	return e and e.image and ("rbxassetid://" .. tostring(e.image)) or nil
end
UiKit.stateImage = stateImage

local function applySlice(img, kind)
	local sl = Tokens.slice[kind]
	if sl and sl.center then
		img.ScaleType = Enum.ScaleType.Slice
		img.SliceCenter = Rect.new(sl.center[1], sl.center[2], sl.center[3], sl.center[4])
		img.SliceScale = Tokens.sliceScale
	else
		img.ScaleType = Enum.ScaleType.Stretch
	end
end

-- 선택 테두리(게임패드 · 키보드만 - 로블록스 SelectionImageObject) = focus-ring r12 · 탭 r10 · 원
local function focusRing(kind)
	local ring = (kind == "close" or kind == "combat") and Tokens.focusRing.circle or ((kind or ""):match("^tab") and Tokens.focusRing.r10 or Tokens.focusRing.r12)
	local e = ArtAssetIds[ring.key]
	if not (e and e.image) then
		return nil
	end
	local r = Instance.new("ImageLabel")
	r.Name = "FocusRing"
	r.BackgroundTransparency = 1
	r.Image = "rbxassetid://" .. tostring(e.image)
	if ring.center then
		r.ScaleType = Enum.ScaleType.Slice
		r.SliceCenter = Rect.new(ring.center[1], ring.center[2], ring.center[3], ring.center[4])
		r.SliceScale = Tokens.sliceScale
	end
	local o = P.focusOutset
	r.Position = UDim2.fromOffset(-o, -o)
	r.Size = UDim2.new(1, o * 2, 1, o * 2)
	return r
end

local controllers = {} -- 버튼 → 손맛 묶음(강한 표 + Destroying에서 지움)
local CONFIRM_KEYS = { [Enum.KeyCode.Return] = true, [Enum.KeyCode.KeypadEnter] = true, [Enum.KeyCode.ButtonA] = true }

-- 아무 GuiButton에 손맛 붙이기 → ctl { Activated(신호), setEnabled(on), bp }
--   opts = { kind(상태 그림 종류 - 없으면 크기만), mode("release" | "instant" 전투), content(누르면 y +2 · 흔들림 대상), onActivated, icons(비활성 = 반투명) }
--   전투 버튼(공격 · Q/E/R/T · 대시 · 점프 · 고정)은 mode = "instant"로 누름 모양만 공통(발동은 자기 입력 경로 그대로 둘 수 있다 - onActivated 없이).
function UiKit.attachPress(btn, opts)
	opts = opts or {}
	local bp = ButtonPress.new({ mode = opts.mode, dragCancel = P.dragCancel })
	local scale = btn:FindFirstChild("PressScale") or Instance.new("UIScale")
	scale.Name = "PressScale"
	scale.Parent = btn
	local event = Instance.new("BindableEvent")
	local content = opts.content
	local contentPos = content and content.Position or nil
	local hovering = false
	local active = nil
	local conns = {}
	local isImage = btn:IsA("ImageButton")
	local function setImage(state)
		if isImage and opts.kind then
			local img = stateImage(opts.kind, state) or stateImage(opts.kind, "normal")
			if img then
				btn.Image = img
			end
		end
	end
	local function tween(target, seconds, style)
		TweenService:Create(scale, TweenInfo.new(seconds, style, Enum.EasingDirection.Out), { Scale = target }):Play()
	end
	local function paint(state)
		if bp.disabled then
			setImage("disabled")
			scale.Scale = 1
			if content then
				content.Position = contentPos
			end
			return
		end
		if state == "pressed" then
			setImage("pressed")
			tween(P.downScale, P.downSeconds, Enum.EasingStyle.Quad)
			if content then
				content.Position = contentPos + UDim2.fromOffset(0, P.contentDown)
			end
		else
			setImage(hovering and "hover" or "normal")
			tween(hovering and P.hoverScale or 1, hovering and P.hoverSeconds or P.upSeconds, hovering and Enum.EasingStyle.Quad or Enum.EasingStyle.Back)
			if content then
				content.Position = contentPos
			end
		end
	end
	local shaking = false
	local function shake()
		if shaking then
			return
		end
		shaking = true
		local target = content or btn
		local base = target.Position
		local step = P.shakeSeconds / (P.shakeCount * 2)
		task.spawn(function()
			for i = 1, P.shakeCount * 2 do
				target.Position = base + UDim2.fromOffset((i % 2 == 1) and P.shakePx or -P.shakePx, 0)
				task.wait(step)
			end
			target.Position = base
			shaking = false
		end)
	end
	local function apply(r)
		if r.paint then
			paint(r.paint)
		end
		if r.shake then
			shake()
		end
		if r.fire then
			event:Fire()
			if opts.onActivated then
				task.spawn(opts.onActivated)
			end
		end
	end
	local function inside(pos)
		local a, sz = btn.AbsolutePosition, btn.AbsoluteSize
		return pos.X >= a.X and pos.X <= a.X + sz.X and pos.Y >= a.Y and pos.Y <= a.Y + sz.Y
	end
	local function isPointer(input)
		return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	end
	local function sameRelease(input)
		return input == active or (active.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1)
	end
	table.insert(conns, btn.InputBegan:Connect(function(input)
		if active or not isPointer(input) then
			return
		end
		bp.inList = btn:FindFirstAncestorWhichIsA("ScrollingFrame") ~= nil
		if not bp.disabled then
			active = input
		end
		apply(bp:pressBegan(input.Position.X, input.Position.Y))
	end))
	table.insert(conns, UserInputService.InputChanged:Connect(function(input)
		if not active then
			return
		end
		if input == active or (active.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement) then
			apply(bp:pressMoved(input.Position.X, input.Position.Y, inside(input.Position)))
		end
	end))
	table.insert(conns, UserInputService.InputEnded:Connect(function(input)
		if active and sameRelease(input) then
			active = nil
			apply(bp:pressEnded(inside(input.Position), btn.Visible))
		end
	end))
	table.insert(conns, btn.MouseEnter:Connect(function()
		if UserInputService.MouseEnabled and not UserInputService.TouchEnabled then
			hovering = true
			if not bp.down then
				paint("normal")
			end
		end
	end))
	table.insert(conns, btn.MouseLeave:Connect(function()
		hovering = false
		if not bp.down then
			paint("normal")
		end
	end))
	-- 게임패드 · 키보드: 고른 버튼(GuiService.SelectedObject)에서 확인 키 = 같은 누름 모양
	table.insert(conns, UserInputService.InputBegan:Connect(function(input)
		if CONFIRM_KEYS[input.KeyCode] and GuiService.SelectedObject == btn then
			apply(bp:keyBegan())
		end
	end))
	table.insert(conns, UserInputService.InputEnded:Connect(function(input)
		if CONFIRM_KEYS[input.KeyCode] and bp.keyDown then
			apply(bp:keyEnded())
		end
	end))
	btn.Destroying:Connect(function()
		for _, c in ipairs(conns) do
			c:Disconnect()
		end
		controllers[btn] = nil
		event:Destroy()
	end)
	local ring = focusRing(opts.kind)
	if ring then
		btn.SelectionImageObject = ring
	end
	local ctl = { Activated = event.Event, bp = bp }
	function ctl.setEnabled(on)
		bp:setDisabled(not on)
		if not on then
			active = nil
		end
		for _, ic in ipairs(opts.icons or {}) do
			if ic:IsA("ImageLabel") then
				ic.ImageTransparency = on and 0 or P.disabledIconTransparency
			end
		end
		paint("normal")
	end
	controllers[btn] = ctl
	paint("normal")
	return ctl
end

-- 손맛이 붙은 버튼의 발동 신호에 연결(UiKit 부품 = 이 길 · GuiButton.Activated 대신)
function UiKit.onActivated(btn, fn)
	local ctl = controllers[btn]
	assert(ctl, "UiKit.onActivated: attachPress 안 된 버튼 - " .. btn:GetFullName())
	return ctl.Activated:Connect(fn)
end
function UiKit.controller(btn)
	return controllers[btn]
end

-- 그림 버튼 바탕(ImageButton + 9-slice 상태 그림) - 그림이 없으면(업로드 전) 색 바탕 + 모서리
local FALLBACK = {
	pri = "accent", primal = "accent", sec = "panel.slot", danger = "warning", plate = "plate.b", card = "panel.section",
	["tab-on"] = "accent", ["tab-off"] = "panel.slot", combat = "panel.slot", close = "warning",
}
local function imageButton(kind, name)
	local b = Instance.new("ImageButton")
	b.Name = name or "Button"
	b.AutoButtonColor = false
	b.BackgroundTransparency = 1
	b.BorderSizePixel = 0
	applySlice(b, kind)
	local img = stateImage(kind, "normal")
	if img then
		b.Image = img
	else
		b.BackgroundTransparency = 0
		b.BackgroundColor3 = UiKit.color(FALLBACK[kind] or "panel.slot")
		corner(b, Tokens.corner.button)
	end
	return b
end
UiKit.imageButton = imageButton

-- 옛 화면(배율 1 · ZIndexBehavior Global)의 TextButton · Frame에 상태 그림 9-slice를 깔기(QUEUE-UI2 UI2-5 2차 장비창 겉모습).
--   그림 = 같은 z의 자식 ImageLabel "Skin" · 부모 z +1(Global에서 글자가 그림 위) · 부모 바탕 투명. 그림이 없으면 nil(옛 겉모습 그대로).
--   opts.pad = { left, right } · opts.keepZ - 부모 UIPadding만큼 그림을 바깥으로 넓힌다(UIPadding은 자식 크기에도 걸린다).
function UiKit.skin(parent, kind, opts)
	opts = opts or {}
	local image = stateImage(kind, opts.state or "normal")
	if not image then
		return nil
	end
	local s = Instance.new("ImageLabel")
	s.Name = "Skin"
	s.BackgroundTransparency = 1
	local padL, padR = opts.pad and opts.pad[1] or 0, opts.pad and opts.pad[2] or 0
	s.Position = UDim2.fromOffset(-padL, 0)
	s.Size = UDim2.new(1, padL + padR, 1, 0)
	s.Image = image
	applySlice(s, kind)
	s.ZIndex = parent.ZIndex
	s.Parent = parent
	if not opts.keepZ then -- keepZ = 부모에 글자가 없을 때(칸 바탕) - 자식 아이콘들의 z를 그대로 둔다
		parent.ZIndex += 1
	end
	parent.BackgroundTransparency = 1
	return s
end

-- 버튼(주 = 노랑 pri · 보조 = sec · 위험 = danger(확인 창 안에서만) · 판 B = plate · 태초 = primal)
--   refs = { root(ImageButton), button(= root), face(내용 Frame - 글자 · 아이콘 자리), title, sub, setEnabled, setText, Activated }
local KIND = { primary = "pri", secondary = "sec", danger = "danger", plate = "plate", primal = "primal", card = "card", tabOn = "tab-on", tabOff = "tab-off" }
local TEXT_TOKEN = { pri = "accent.text", primal = "bg.deep", plate = "outline.warm" }
function UiKit.button(props)
	local kind = KIND[props.kind or "secondary"] or props.kind
	assert(Tokens.slice[kind], "UiKit.button: kind - " .. tostring(props.kind))
	local textToken = TEXT_TOKEN[kind] or "text.primary"
	local lip = Tokens.lip
	local holder = imageButton(kind, props.name)
	if props.rect then
		UiKit.place(holder, props.rect)
	end
	local face = Instance.new("Frame") -- 내용(글자 · 아이콘) - 누르면 y +2
	face.Name = "Face"
	face.BackgroundTransparency = 1
	face.Size = UDim2.new(1, 0, 1, -lip)
	face.Parent = holder
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, props.padX or 22)
	pad.PaddingRight = UDim.new(0, props.padX or 22)
	pad.Parent = face
	local title = UiKit.label(face, props.text, props.textSize or "button", textToken, { name = "Title", align = props.align, font = "korean" })
	title.Size = UDim2.new(1, 0, props.sub and 0.58 or 1, 0)
	local sub = nil
	if props.sub then
		title.TextYAlignment = Enum.TextYAlignment.Bottom
		sub = UiKit.label(face, props.sub, props.subSize or "mainButtonSub", textToken, { name = "Sub", align = props.align })
		sub.Position = UDim2.fromScale(0, 0.6)
		sub.Size = UDim2.new(1, 0, 0.32, 0)
		sub.TextYAlignment = Enum.TextYAlignment.Top
	end
	holder.Parent = props.parent
	local icons = {}
	local ctl = UiKit.attachPress(holder, { kind = kind, mode = props.mode, content = face, onActivated = props.onActivated, icons = icons })
	local refs = { root = holder, button = holder, face = face, title = title, sub = sub, Activated = ctl.Activated, icons = icons }
	function refs.setEnabled(on)
		ctl.setEnabled(on)
		title.TextColor3 = UiKit.color(on and textToken or "text.muted")
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

-- 아이콘(아이콘 표 한 곳 · 별칭 = 넘김 묶음 파일 이름): 그림이 있으면 ImageLabel(tint = 글리프 색만 입힘) · 없으면 fallback 글자
function UiKit.icon(parent, id, sizePx, props)
	props = props or {}
	local def = IconData.icons[id] or (IconData.aliases and IconData.icons[IconData.aliases[id] or ""])
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

function UiKit.hasIcon(id)
	return IconData.icons[id] ~= nil or (IconData.aliases ~= nil and IconData.aliases[id] ~= nil)
end

-- 닫기 = btn-close 원(상태 그림 88) + 흰 X(icon-x) · props.plate = 판 B(양피지 9-slice) + 아이콘(폰 [<] 등)
function UiKit.closeButton(props)
	local kind = props.plate and "plate" or "close"
	local b = imageButton(kind, props.name or "Close")
	UiKit.place(b, props.rect)
	if not stateImage(kind, "normal") then -- 그림 없음(업로드 전) = 옛 원 + 테두리
		corner(b, Tokens.close.size)
		b.BackgroundColor3 = UiKit.color(props.colorToken or "warning")
		if props.ring ~= false then
			stroke(b, "text.primary", Tokens.stroke.close)
		end
	end
	local icon = UiKit.icon(b, props.icon or (props.plate and "back" or "x"), math.floor(props.rect[3] * (props.plate and 0.62 or 0.5)), { center = true, color = "text.primary" })
	b.Parent = props.parent
	UiKit.attachPress(b, { kind = kind, onActivated = props.onActivated, icons = { icon } })
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
	title.Position = UDim2.fromOffset(props.titleX or 24, 0)
	title.Size = UDim2.new(0.6, 0, 1, 0)
	title.AutomaticSize = Enum.AutomaticSize.X
	title.TextTruncate = Enum.TextTruncate.None
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

-- 카드(캐릭터 · 직업) = btn-card 상태 그림(9-slice · 테두리 포함) · selected = 노랑 테두리 3 추가 · 발동 = refs.Activated(손맛 판정 - 목록 끌기 취소)
function UiKit.card(parent, rect, selected, name)
	local f = imageButton("card", name or "Card")
	UiKit.place(f, rect)
	corner(f, Tokens.corner.card)
	local hasImage = stateImage("card", "normal") ~= nil
	local s = stroke(f, selected and "accent" or "panel.slot", selected and Tokens.stroke.cardSelected or Tokens.stroke.card)
	s.Transparency = (selected or not hasImage) and 0 or 1
	f.Parent = parent
	local ctl = UiKit.attachPress(f, { kind = "card" })
	local refs = { root = f, stroke = s, Activated = ctl.Activated }
	function refs.setSelected(on)
		s.Color = UiKit.color(on and "accent" or "panel.slot")
		s.Thickness = on and Tokens.stroke.cardSelected or Tokens.stroke.card
		s.Transparency = (on or not hasImage) and 0 or 1
	end
	return refs
end

-- 빈 칸(실선 - 점선 쓰지 않음) + 노랑 + 아이콘 · 글 · 손맛(크기만 - 상태 그림 없음)
function UiKit.emptySlot(parent, rect, text, sub, name)
	local f = Instance.new("ImageButton")
	f.Name = name or "EmptySlot"
	f.AutoButtonColor = false
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
	list.SortOrder = Enum.SortOrder.LayoutOrder
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
	t.TextTruncate = Enum.TextTruncate.None
	t.Size = UDim2.new(0, 0, 1, 0)
	t.LayoutOrder = 2
	if sub and not UiKit.isPhone() then
		local s2 = UiKit.label(row, sub, "cardInfo", "text.secondary", { name = "Sub" })
		s2.AutomaticSize = Enum.AutomaticSize.X
		s2.TextTruncate = Enum.TextTruncate.None
		s2.Size = UDim2.new(0, 0, 1, 0)
		s2.LayoutOrder = 3
	end
	f.Parent = parent
	UiKit.attachPress(f, {})
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
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 10)
	list.Parent = row
	UiKit.icon(row, "lock", UiKit.isPhone() and 16 or 22).LayoutOrder = 1
	local t = UiKit.label(row, text, "cardInfo", "text.muted", { name = "Title", font = "korean" })
	t.AutomaticSize = Enum.AutomaticSize.X
	t.TextTruncate = Enum.TextTruncate.None
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
	if rect[1] == 0 and rect[3] >= (UiKit.isPhone() and Tokens.base.phone.w or Tokens.base.pc.w) then
		f.Size = UDim2.fromOffset(rect[3] * 3, rect[4]) -- 화면 폭 띠 = 넓은 화면에서도 오른쪽 끝까지
	end
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
--   props = { parent(UiRoot.frame), rect, title, body, sub, cancelText, okText, okKind("secondary" 기본 - 노랑은 시작 · 구매만 · 위험 = "danger"(빨강은 확인 창 안에서만)), cancelRect, okRect, onAnswer(bool) }
function UiKit.confirm(props)
	local layer = Instance.new("Frame") -- 루트 크기 층(창 좌표 = 기준 px) · 어둡게 덮개는 화면 밖까지(넓은 화면 = 루트 밖도 덮는다)
	layer.Name = props.name or "ConfirmDim"
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	layer.ZIndex = 50
	local dim = Instance.new("TextButton")
	dim.Name = "Dim"
	dim.AutoButtonColor = false
	dim.Text = ""
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = Tokens.dimTransparency
	dim.AnchorPoint = Vector2.new(0.5, 0.5)
	dim.Position = UDim2.fromScale(0.5, 0.5)
	dim.Size = UDim2.fromScale(6, 6)
	dim.ZIndex = 50
	dim.Parent = layer
	local win = UiKit.window({ parent = layer, rect = props.rect, title = props.title, name = "ConfirmWindow" })
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
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(layer) then
			GuiService.SelectedObject = nil
		end
		layer:Destroy()
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
	local focusStroke = stroke(first.button, "accent", 3) -- 첫 포커스 표시(마우스 · 터치에도 보임) · 게임패드 · 키보드 = 선택 테두리(focus-ring)
	focusStroke.Name = "FocusStroke"
	local scale = Instance.new("UIScale")
	scale.Scale = Tokens.confirmOpenScale
	scale.Parent = win.root
	layer.Parent = props.parent
	TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	pcall(function()
		GuiService.SelectedObject = first.button
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
	return { root = layer, cancel = cancel, ok = ok, first = first, answer = answer }
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
