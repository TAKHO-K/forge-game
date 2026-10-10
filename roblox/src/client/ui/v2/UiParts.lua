-- UI-1 1단계 A 공용 부품(00_design-system/v8): 게이지 · 쿨타임 덮개 · 상태 아이콘(+ 줄 · 설명 창) · 알림 배너 · 전투 문구 · 아이콘 받기 전 · 빈 상태.
--   값 = shared/data/UiPartsData · 상태 아이콘 = StatusIconData.icons · 글자 = Text(TextData_ui1) · 그림 = ArtAssetIds(ui/ds/*). B ~ H 단계가 이 부품을 다시 쓴다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")

local D = require(ReplicatedStorage.Shared.data.UiPartsData)
local StatusIconData = require(ReplicatedStorage.Shared.data.StatusIconData)
local Text = require(ReplicatedStorage.Shared.Text)
local ArtImage = require(script.Parent.Parent.ArtImage)
local UiKit = require(script.Parent.UiKit)

local UiParts = {}

local function hex(h)
	return Color3.fromHex(h)
end
local function tween(inst, seconds, props, style, dir)
	local t = TweenService:Create(inst, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end
local function image(parent, key, name)
	local i = Instance.new("ImageLabel")
	i.Name = name or "Image"
	i.BackgroundTransparency = 1
	i.Image = ArtImage.get(key) or ""
	i.Parent = parent
	return i
end
local function reduceFlash()
	local lp = Players.LocalPlayer
	return lp ~= nil and lp:GetAttribute("ReduceFlashes") == true
end
UiParts.reduceFlash = reduceFlash

-- ── §2 게이지: { root, set(ratio, instant) } · color = hex · h = 채움 높이(px) · w = 폭 ──
function UiParts.gauge(parent, props)
	local G = D.gauge
	local w, h = props.w, props.h
	local root = Instance.new("Frame")
	root.Name = props.name or "Gauge"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromOffset(w, h)
	root.Position = props.position or UDim2.new()
	root.Parent = parent
	local track = image(root, G.track.img, "Track")
	track.ScaleType = Enum.ScaleType.Slice
	track.SliceCenter = Rect.new(G.track.center[1], G.track.center[2], G.track.center[3], G.track.center[4])
	track.SliceScale = (h + G.track.pad * 2) / G.track.src
	track.Position = UDim2.fromOffset(-G.track.pad, -G.track.pad)
	track.Size = UDim2.fromOffset(w + G.track.pad * 2, h + G.track.pad * 2)
	local function clipWith(name, transparency, color)
		local clip = Instance.new("Frame")
		clip.Name = name
		clip.BackgroundTransparency = 1
		clip.ClipsDescendants = true
		clip.Size = UDim2.fromOffset(0, h)
		clip.Parent = root
		local f = image(clip, G.fill.img, "Fill")
		f.ScaleType = Enum.ScaleType.Slice
		f.SliceCenter = Rect.new(G.fill.center[1], G.fill.center[2], G.fill.center[3], G.fill.center[4])
		f.SliceScale = h / G.fill.src
		f.Size = UDim2.fromOffset(w, h)
		f.ImageColor3 = color
		f.ImageTransparency = transparency
		return clip, f
	end
	local ghostClip = clipWith("Ghost", G.ghostTransparency, Color3.new(1, 1, 1))
	local fillClip, fill = clipWith("FillClip", 0, hex(props.color or D.gaugeColors.exp))
	local shine = image(fillClip, G.shine, "Shine")
	shine.Size = UDim2.fromOffset(h * 2, h)
	shine.ImageTransparency = 1
	local tip = image(root, G.tip, "Tip")
	tip.AnchorPoint = Vector2.new(0.5, 0.5)
	tip.Size = UDim2.fromOffset(h * 1.4, h * 1.4)
	tip.Visible = false
	local flash = Instance.new("UIStroke")
	flash.Color = Color3.new(1, 1, 1)
	flash.Thickness = 3
	flash.Transparency = 1
	flash.Parent = track
	local ratio = 0
	local self = { root = root, fill = fill }
	function self.set(r, instant)
		r = math.clamp(tonumber(r) or 0, 0, 1)
		local px = math.floor(w * r + 0.5)
		tip.Visible = r > 0 and r < 1
		tip.Position = UDim2.fromOffset(px, h / 2)
		if instant then
			fillClip.Size = UDim2.fromOffset(px, h)
			ghostClip.Size = UDim2.fromOffset(px, h)
		elseif r >= ratio then
			tween(ghostClip, G.riseGhostSeconds, { Size = UDim2.fromOffset(px, h) }, Enum.EasingStyle.Linear)
			tween(fillClip, G.riseSeconds, { Size = UDim2.fromOffset(px, h) })
			if r > ratio and not reduceFlash() then
				shine.ImageTransparency = 0.2
				shine.Position = UDim2.fromOffset(-h * 2, 0)
				tween(shine, G.shineSeconds, { Position = UDim2.fromOffset(w, 0), ImageTransparency = 1 }, Enum.EasingStyle.Linear)
			end
			if r >= 1 and ratio < 1 then
				task.spawn(function()
					for _ = 1, G.fullFlashCount do
						flash.Transparency = 0
						tween(flash, G.fullFlashSeconds, { Transparency = 1 })
						task.wait(G.fullFlashSeconds + G.fullFlashGap)
					end
				end)
			end
		else
			fillClip.Size = UDim2.fromOffset(px, h)
			task.delay(G.fallHoldSeconds, function()
				if ratio == r then
					tween(ghostClip, G.fallSeconds, { Size = UDim2.fromOffset(px, h) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				end
			end)
		end
		ratio = r
	end
	function self.setColor(h2)
		fill.ImageColor3 = hex(h2)
	end
	self.set(props.value or 0, true)
	return self
end

-- ── §3 쿨타임 · 남은 시간 덮개: slot 위에 반쪽 두 장 + UIGradient. mode = "clear"(스킬 · 대시 - 다 덮인 채 시작 → 걷힘) | "fill"(상태 - 밝게 시작 → 덮임) ──
--   반환 { set(f = 지난 비율 0 ~ 1), setTransparency(t), flash() , destroy() }
function UiParts.cooldown(slot, props)
	local C = D.cooldown
	props = props or {}
	local mode = props.mode or "clear"
	local maskKey = props.circle and C.maskCircle or C.maskR18
	local z = (props.zIndex or slot.ZIndex) + 1
	local holder = Instance.new("Frame")
	holder.Name = "Cooldown"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = z
	holder.Parent = slot
	local halves = {}
	for _, side in ipairs({ "Right", "Left" }) do
		local half = Instance.new("Frame")
		half.Name = "Cd" .. side
		half.BackgroundTransparency = 1
		half.ClipsDescendants = true
		half.Size = UDim2.fromScale(0.5, 1)
		half.Position = UDim2.fromScale(side == "Right" and 0.5 or 0, 0)
		half.ZIndex = z
		half.Parent = holder
		local m = image(half, maskKey, "Mask")
		m.Size = UDim2.fromScale(2, 1)
		m.Position = UDim2.fromScale(side == "Right" and -1 or 0, 0)
		m.ImageColor3 = hex(C.color)
		m.ImageTransparency = props.transparency or (mode == "fill" and C.statusTransparency or C.skillTransparency)
		m.ZIndex = z
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(0.501, 1), NumberSequenceKeypoint.new(1, 1) })
		g.Parent = m
		halves[side] = { mask = m, grad = g }
	end
	local self = { root = holder }
	function self.set(f)
		f = math.clamp(f or 0, 0, 1)
		local a = 360 * f
		local add = mode == "clear" and 180 or 0
		halves.Right.grad.Rotation = math.clamp(a, 0, 180) + add
		halves.Left.grad.Rotation = math.clamp(a, 180, 360) + add
		holder.Visible = not (mode == "clear" and f >= 1) and not (mode == "fill" and f <= 0)
	end
	function self.setTransparency(t)
		for _, hv in pairs(halves) do
			hv.mask.ImageTransparency = t
		end
	end
	function self.flash(icon)
		if reduceFlash() then
			return
		end
		local fl = image(slot, props.circle and C.flashCircle or C.flashR18, "ReadyFlash")
		fl.AnchorPoint = Vector2.new(0.5, 0.5)
		fl.Position = UDim2.fromScale(0.5, 0.5)
		fl.Size = UDim2.fromScale(C.readyFlashScale, C.readyFlashScale)
		fl.ImageTransparency = 1
		fl.ZIndex = z + 3
		tween(fl, C.readyFlashSeconds, { ImageTransparency = 0 })
		task.delay(C.readyFlashSeconds, function()
			tween(fl, C.readyFlashFade, { ImageTransparency = 1 })
			task.delay(C.readyFlashFade, function()
				fl:Destroy()
			end)
		end)
		if icon then
			local s = icon:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
			s.Parent = icon
			s.Scale = C.readyIconPop
			tween(s, C.readyFlashFade, { Scale = 1 })
		end
	end
	function self.destroy()
		holder:Destroy()
	end
	self.set(mode == "clear" and 1 or 0)
	return self
end

-- 남은 초 글자(§3: 1초 이상 올림 정수 · 1초 미만 소수 1자리 · 60초 이상 "1분" - 스킬엔 없음)
function UiParts.secondsText(sec, allowMinutes)
	if sec <= 0 then
		return ""
	elseif sec < 1 then
		return ("%.1f"):format(sec)
	elseif allowMinutes and sec >= 60 then
		return ("%d:%02d"):format(math.floor(sec / 60), math.floor(sec % 60))
	end
	return tostring(math.ceil(sec))
end

-- ── §4 상태 아이콘 1칸 ──
function UiParts.statusIcon(parent, id, size, props)
	props = props or {}
	local def = StatusIconData.icons[id] or {}
	local root = Instance.new(props.button and "ImageButton" or "Frame")
	root.Name = "Status_" .. id
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromOffset(size, size)
	if root:IsA("ImageButton") then
		root.AutoButtonColor = false
		root.Image = ""
	end
	root.Parent = parent
	local glow
	if def.strong then
		glow = image(root, D.status.glow, "Glow")
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.Position = UDim2.fromScale(0.5, 0.5)
		glow.Size = UDim2.fromScale(D.status.glowScale, D.status.glowScale)
		glow.ImageColor3 = hex(D.statusColors.buff)
	end
	local icon = image(root, "ui/ds/status-" .. id, "Icon")
	icon.Size = UDim2.fromScale(1, 1)
	icon.ZIndex = 2
	if icon.Image == "" then -- 그림 업로드 기록 없음 = 범주 색 칸(임시)
		icon.BackgroundTransparency = 0
		icon.BackgroundColor3 = hex(D.statusColors[def.cat or "buff"])
		UiKit.corner(icon, math.floor(size * 0.18))
	end
	local cover = UiParts.cooldown(icon, { mode = "fill", zIndex = 2 })
	local count = Instance.new("TextLabel")
	count.Name = "Count"
	count.BackgroundTransparency = 1
	count.AnchorPoint = Vector2.new(1, 1)
	count.Position = UDim2.new(1, 2, 1, 2)
	count.Size = UDim2.fromOffset(size * 0.6, size * 0.45)
	count.Font = UiKit.font("number")
	count.TextScaled = true
	count.TextColor3 = Color3.new(1, 1, 1)
	count.TextStrokeTransparency = 0
	count.TextStrokeColor3 = hex("0E1120")
	count.TextXAlignment = Enum.TextXAlignment.Right
	count.Text = ""
	count.ZIndex = 5
	count.Parent = root
	local ring = Instance.new("UIStroke")
	ring.Color = Color3.new(1, 1, 1)
	ring.Thickness = 2
	ring.Transparency = 1
	ring.Parent = icon
	return { root = root, icon = icon, cover = cover, count = count, ring = ring, glow = glow, id = id, cat = def.cat or "buff" }
end

-- 상태 하나의 지금 값(데이터 연결 = StatusIconData.icons[id].src · trapKinds) → { active, endsAt(서버 시각) | nil, total, stacks }
--   ctx = { player, character, boss(Model | nil), buffs = { [buffId] = { endsAt, total, charges } } }
local trapKindToId
local function trapIdFor(kind)
	if not trapKindToId then
		trapKindToId = {}
		for id, def in pairs(StatusIconData.icons) do
			for _, k in ipairs(def.trapKinds or {}) do
				trapKindToId[k] = id
			end
		end
	end
	return trapKindToId[kind] or "trap-grab"
end
UiParts.trapIdFor = trapIdFor

function UiParts.readStatus(id, ctx, side)
	local def = StatusIconData.icons[id]
	if not def or def.unused then
		return nil
	end
	local now = workspace:GetServerTimeNow()
	if def.trapKinds and side ~= "boss" then
		local kind = ctx.player and ctx.player:GetAttribute("BossTrapKind")
		if kind and trapIdFor(kind) == id then
			local releaseAt = ctx.player:GetAttribute("BossTrapReleaseAt")
			local startedAt = ctx.player:GetAttribute("BossTrapStartedAt")
			return { endsAt = releaseAt, total = (releaseAt and startedAt) and (releaseAt - startedAt) or nil }
		end
		return nil
	end
	for _, src in ipairs(def.src or {}) do
		if src.buff and side ~= "boss" then
			local b = ctx.buffs and ctx.buffs[src.buff]
			if b then
				return { endsAt = b.endsAt, total = b.total, stacks = b.charges }
			end
		elseif src.attr and ((side == "boss") == (src.on == "boss")) then
			local inst = src.on == "boss" and ctx.boss or (src.on == "character" and ctx.character or ctx.player)
			local v = inst and inst:GetAttribute(src.attr)
			if src.mode == "untilServer" then
				if type(v) == "number" and v > now then
					return { endsAt = v }
				end
			elseif src.mode == "untilOs" then
				if type(v) == "number" and v > os.time() then
					return { endsAt = now + (v - os.time()) }
				end
			elseif src.mode == "positive" then
				if type(v) == "number" and v > 0 then
					return {}
				end
			elseif v ~= nil and v ~= false and v ~= 0 then
				return {}
			end
		end
	end
	return nil
end

-- ── §5 설명 창(하나만 - 다른 아이콘 = 내용 바꿈 · 같은 아이콘 다시 = 닫힘 · 폰 4초 자동 닫힘) ──
local tipState = { gui = nil, frame = nil, forId = nil, token = 0, anchor = nil }
do -- 바깥 누름 = 닫힘(누른 자리가 그 아이콘이면 그대로 - 아이콘의 Activated가 같은 아이콘 = 닫기를 처리)
	local UserInputService = game:GetService("UserInputService")
	UserInputService.InputBegan:Connect(function(input)
		if not (tipState.frame and tipState.frame.Visible) then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local a = tipState.anchor
		local p = Vector2.new(input.Position.X, input.Position.Y)
		if a and a.Parent then
			local lo, size = a.AbsolutePosition, a.AbsoluteSize
			if p.X >= lo.X and p.X <= lo.X + size.X and p.Y >= lo.Y and p.Y <= lo.Y + size.Y then
				return
			end
		end
		UiParts.closeTip()
	end)
end
function UiParts.closeTip()
	tipState.token += 1
	if tipState.frame then
		tipState.frame.Visible = false
	end
	tipState.forId = nil
end
function UiParts.openTip(anchor, id, info)
	if tipState.forId == id and tipState.frame and tipState.frame.Visible then
		UiParts.closeTip()
		return
	end
	local T = D.tip
	local phone = UiKit.isPhone()
	local lp = Players.LocalPlayer
	if not tipState.gui then
		local g = Instance.new("ScreenGui")
		g.Name = "StatusTipGui"
		g.ResetOnSpawn = false
		g.IgnoreGuiInset = true
		g.DisplayOrder = 160
		g.Parent = lp:WaitForChild("PlayerGui")
		tipState.gui = g
	end
	if tipState.frame then
		tipState.frame:Destroy()
	end
	local def = StatusIconData.icons[id] or {}
	local w = phone and T.width.phone or T.width.pc
	local head = phone and D.status.size.tipHead.phone or D.status.size.tipHead.pc
	local f = image(tipState.gui, T.panel, "StatusTip")
	f.ScaleType = Enum.ScaleType.Slice
	f.SliceCenter = Rect.new(T.center[1], T.center[2], T.center[3], T.center[4])
	f.Size = UDim2.fromOffset(w, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.ZIndex = 10
	if f.Image == "" then
		f.BackgroundTransparency = 0.05
		f.BackgroundColor3 = UiKit.color("panel.window")
		UiKit.corner(f, 12)
	end
	-- 판(f) = 색 띠 + 본문(body · 목록 배치) - 띠를 목록 밖에 두고 높이는 본문 크기로 맞춘다(목록 안 비율 높이 = 자동 크기와 순환)
	local band = Instance.new("Frame")
	band.Name = "Band"
	band.BorderSizePixel = 0
	band.BackgroundColor3 = hex(D.statusColors[def.cat or "buff"])
	band.Position = UDim2.fromOffset(4, 6)
	band.Size = UDim2.fromOffset(T.band, 0)
	band.ZIndex = 11
	band.Parent = f
	UiKit.corner(band, 3)
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Size = UDim2.new(1, 0, 0, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.ZIndex = 11
	body.Parent = f
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 18), UDim.new(0, 14), UDim.new(0, 12), UDim.new(0, 12)
	pad.Parent = body
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 4)
	list.Parent = body
	local function fitBand()
		band.Size = UDim2.fromOffset(T.band, math.max(body.AbsoluteSize.Y - 12, 0) / math.max(f.AbsoluteSize.X / w, 0.01))
	end
	body:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitBand)
	local top = Instance.new("Frame")
	top.Name = "Head"
	top.BackgroundTransparency = 1
	top.Size = UDim2.new(1, 0, 0, head)
	top.LayoutOrder = 1
	top.ZIndex = 11
	top.Parent = body
	local ic = image(top, "ui/ds/status-" .. id, "Icon")
	ic.Size = UDim2.fromOffset(head, head)
	ic.ZIndex = 12
	local name = UiKit.label(top, Text.get("ui1.status." .. id .. ".name"), "heading", "text.primary", { name = "Name", font = "korean" })
	name.Position = UDim2.fromOffset(head + 10, 0)
	name.Size = UDim2.new(1, -(head + 10), 1, 0)
	name.ZIndex = 12
	local desc = UiKit.label(body, Text.get("ui1.status." .. id .. ".desc"), "body", "text.primary", { name = "Desc", font = "korean", wrap = true })
	desc.Size = UDim2.new(1, 0, 0, 0)
	desc.AutomaticSize = Enum.AutomaticSize.Y
	desc.TextWrapped = true
	desc.LayoutOrder = 2
	desc.ZIndex = 12
	local sub = UiKit.label(body, "", "caption", "text.secondary", { name = "Sub", font = "korean", wrap = true })
	sub.Size = UDim2.new(1, 0, 0, 0)
	sub.AutomaticSize = Enum.AutomaticSize.Y
	sub.TextWrapped = true
	sub.LayoutOrder = 3
	sub.ZIndex = 12
	tipState.frame, tipState.forId, tipState.anchor = f, id, anchor
	tipState.token += 1
	local token = tipState.token
	-- 자리: 아이콘 위로(아래 끝 = 아이콘 위 14) · 화면 가운데 35% 영역에 닿으면 왼쪽 옆으로
	local view = tipState.gui.AbsoluteSize
	local a = anchor.AbsolutePosition + Vector2.new(0, 58) -- AbsolutePosition = 상단 바 아래 공통 좌표 → 이 Gui(IgnoreGuiInset) 화면 좌표
	local cx = a.X + anchor.AbsoluteSize.X / 2
	local x = math.clamp(cx - w / 2, 8, view.X - w - 8)
	f.AnchorPoint = Vector2.new(0, 1)
	f.Position = UDim2.fromOffset(x, a.Y - T.gap)
	local cam = workspace.CurrentCamera.ViewportSize
	local m = require(ReplicatedStorage.Shared.HudPlace).scale(cam.X, cam.Y, phone) -- HUD 배율 m(02 v6 §2)
	x = math.clamp(cx - w * m / 2, 8, view.X - w * m - 8)
	f.Position = UDim2.fromOffset(x, a.Y - T.gap * m)
	local scale = Instance.new("UIScale")
	scale.Scale = 0.9 * m
	scale.Parent = f
	tween(scale, T.openSeconds, { Scale = m })
	local function refresh()
		local st = info and info()
		if not st then
			return false
		end
		local remain = st.endsAt and math.max(st.endsAt - workspace:GetServerTimeNow(), 0)
		local parts = {}
		if remain then
			table.insert(parts, Text.get("ui1.status.remain", { seconds = ("%.1f"):format(remain) }))
		elseif def.cat == "buff" and id == "dealing-mode" then
			table.insert(parts, Text.get("ui1.status.endless"))
		end
		if st.from then
			table.insert(parts, Text.get("ui1.status.fromBoss", { name = st.from }))
		end
		sub.Text = table.concat(parts, " · ")
		sub.Visible = sub.Text ~= ""
		return true
	end
	refresh()
	task.spawn(function()
		local opened = os.clock()
		local auto = phone and D.status.tipAutoCloseSeconds.phone or nil
		while token == tipState.token and f.Parent do
			if not refresh() or (auto and os.clock() - opened >= auto) then -- 효과 끝남 · 폰 4초 = 닫힘
				if token == tipState.token then
					UiParts.closeTip()
				end
				return
			end
			task.wait(0.1)
		end
	end)
end

-- ── §4 상태 아이콘 줄: { root, update(list) } · list = { { id, endsAt, total, stacks } } · 정렬 = 빨강 → 노랑 → 파랑 · 같은 색 = 남은 시간 짧은 것 먼저(무기한 = 맨 뒤) ──
--   props = { parent, place = "row" | "boss" | "party", max, tappable, info(id) → 상태(설명 창 남은 시간) }
function UiParts.statusRow(props)
	local S = D.status
	local phone = UiKit.isPhone()
	local place = props.place or "row"
	local size = phone and S.size[place].phone or S.size[place].pc
	local cell = phone and S.cell[place].phone or S.cell[place].pc
	local maxN = props.max or (place == "party" and S.partyMax) or (phone and S.max.phone or S.max.pc)
	local root = Instance.new("Frame")
	root.Name = props.name or "StatusRow"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromOffset(cell * (maxN + 1), cell)
	root.Parent = props.parent
	local cells = {} -- id → icon
	local more
	local self = { root = root, cells = cells }
	local function sortKey(e)
		local remain = e.endsAt and (e.endsAt - workspace:GetServerTimeNow()) or math.huge
		return D.statusOrder[(StatusIconData.icons[e.id] or {}).cat or "buff"] or 3, remain
	end
	function self.update(list)
		table.sort(list, function(a, b)
			local ca, ra = sortKey(a)
			local cb, rb = sortKey(b)
			if ca ~= cb then
				return ca < cb
			end
			if ra ~= rb then
				return ra < rb
			end
			return a.id < b.id
		end)
		local seen = {}
		local now = workspace:GetServerTimeNow()
		for i, e in ipairs(list) do
			seen[e.id] = true
			local c = cells[e.id]
			local fresh = c == nil
			if fresh then
				c = UiParts.statusIcon(root, e.id, size, { button = props.tappable })
				c.startedAt = now
				cells[e.id] = c
				if props.tappable then
					c.root.Activated:Connect(function()
						UiParts.openTip(c.root, e.id, function()
							return props.info and props.info(e.id)
						end)
					end)
				end
				-- 새로 걸림: 1.25 → 1.0 · 상태이상만 흔들림 + 흰 테 + 소리 자리(status_cc)
				local sc = Instance.new("UIScale")
				sc.Scale = S.popScale
				sc.Parent = c.root
				tween(sc, S.popSeconds, { Scale = 1 }, Enum.EasingStyle.Back)
				if c.cat == "cc" and not reduceFlash() then
					c.ring.Transparency = 0
					tween(c.ring, S.ccFlashSeconds, { Transparency = 1 })
					task.spawn(function()
						for k = 1, S.shakeCount * 2 do
							c.icon.Position = UDim2.fromOffset((k % 2 == 1) and S.shakePx or -S.shakePx, 0)
							task.wait(S.shakeSeconds / (S.shakeCount * 2))
						end
						c.icon.Position = UDim2.new()
					end)
				end
			end
			c.root.Visible = i <= maxN
			c.root.Position = UDim2.fromOffset((i - 1) * cell + (cell - size) / 2, (cell - size) / 2)
			if e.endsAt then
				local total = e.total or c.total or math.max(e.endsAt - (c.startedAt or now), 0.01)
				c.total = total
				local remain = math.max(e.endsAt - now, 0)
				c.cover.set(1 - remain / total)
				local blink = remain <= S.blinkUnderSeconds
				if blink and reduceFlash() then
					c.ring.Thickness = 1
					c.ring.Transparency = 0
					c.icon.ImageTransparency = 0
				else
					c.icon.ImageTransparency = blink and ((math.floor(os.clock() / S.blinkPeriod) % 2 == 0) and 0 or 0.5) or 0
				end
			else
				c.cover.set(0)
				c.icon.ImageTransparency = 0
			end
			c.count.Text = (e.stacks and e.stacks > 1) and tostring(e.stacks) or ""
			if c.glow then
				c.glow.ImageTransparency = 0.15 + 0.3 * (0.5 + 0.5 * math.sin(os.clock() * 2 * math.pi / S.glowPeriod))
			end
		end
		for id, c in pairs(cells) do
			if not seen[id] then -- 끝남: 0.8배 + 투명
				cells[id] = nil
				local sc = c.root:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
				sc.Parent = c.root
				tween(sc, S.endSeconds, { Scale = S.endScale })
				tween(c.icon, S.endSeconds, { ImageTransparency = 1 })
				task.delay(S.endSeconds, function()
					c.root:Destroy()
				end)
			end
		end
		local extra = #list - maxN
		if extra > 0 then
			if not more then
				more = image(root, S.frameMore, "More")
				more.Size = UDim2.fromOffset(size, size)
				local t = Instance.new("TextLabel")
				t.Name = "N"
				t.BackgroundTransparency = 1
				t.Size = UDim2.fromScale(1, 1)
				t.Font = UiKit.font("number")
				t.TextScaled = true
				t.TextColor3 = Color3.new(1, 1, 1)
				t.TextStrokeTransparency = 0
				t.Parent = more
			end
			more.Visible = true
			more.Position = UDim2.fromOffset(maxN * cell + (cell - size) / 2, (cell - size) / 2)
			more.N.Text = Text.get("ui1.status.more", { n = tostring(extra) })
		elseif more then
			more.Visible = false
		end
	end
	return self
end

-- ── §6 알림 배너(한 번에 1개 · 최대 3 대기 · 같은 종류 합침 · 카운트다운 없음) ──
local bannerQueue, bannerBusy, bannerGui = {}, false, nil
local function showNextBanner()
	if bannerBusy or #bannerQueue == 0 then
		return
	end
	bannerBusy = true
	local b = table.remove(bannerQueue, 1)
	local B = D.banner
	local phone = UiKit.isPhone()
	local P = phone and B.phone or B.pc
	local lp = Players.LocalPlayer
	if not bannerGui then
		bannerGui = Instance.new("ScreenGui")
		bannerGui.Name = "BannerGui"
		bannerGui.ResetOnSpawn = false
		bannerGui.IgnoreGuiInset = true
		bannerGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
		bannerGui.DisplayOrder = 155
		bannerGui.Parent = lp:WaitForChild("PlayerGui")
	end
	local view = workspace.CurrentCamera.ViewportSize
	local m = require(ReplicatedStorage.Shared.HudPlace).scale(view.X, view.Y, phone)
	local y = lp:GetAttribute("BossEncounterId") ~= nil and P.bossY or P.y
	local btn = Instance.new("ImageButton")
	btn.Name = "Banner_" .. (b.kind or "info")
	btn.AutoButtonColor = false
	btn.BackgroundTransparency = 1
	btn.Image = ArtImage.get(B.panel) or ""
	btn.ScaleType = Enum.ScaleType.Slice
	btn.SliceCenter = Rect.new(B.center[1], B.center[2], B.center[3], B.center[4])
	btn.SliceScale = P.sliceScale or 1
	btn.AnchorPoint = Vector2.new(0.5, 0)
	btn.Size = UDim2.fromOffset(P.w, P.h)
	btn.AutomaticSize = Enum.AutomaticSize.Y
	local yPx = 58 + (y - 58) * m
	btn.Position = UDim2.new(0.5, 0, 0, yPx - 24)
	btn.ImageTransparency = 0
	btn.Parent = bannerGui
	local sc = Instance.new("UIScale")
	sc.Scale = m
	sc.Parent = btn
	local ic = image(btn, B.icons[b.kind] or B.icons.rift, "Icon")
	ic.Position = UDim2.fromOffset(12, (P.h - P.icon) / 2)
	ic.Size = UDim2.fromOffset(P.icon, P.icon)
	local title = UiKit.label(btn, b.title or "", "heading", "text.primary", { name = "Title", font = "korean" })
	title.Position = UDim2.fromOffset(P.icon + 24, phone and 4 or 8)
	title.Size = UDim2.new(1, -(P.icon + 36), 0, phone and 20 or 28)
	local line = UiKit.label(btn, b.line or "", "caption", "text.secondary", { name = "Line", font = "korean" })
	line.Position = UDim2.fromOffset(P.icon + 24, phone and 24 or 38)
	line.Size = UDim2.new(1, -(P.icon + 36), 0, phone and 18 or 24)
	line.TextWrapped = true
	tween(btn, B.inSeconds, { Position = UDim2.new(0.5, 0, 0, yPx) }, Enum.EasingStyle.Back)
	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		tween(btn, B.outSeconds, { Position = UDim2.new(0.5, 0, 0, yPx - 16), ImageTransparency = 1 })
		task.delay(B.outSeconds, function()
			btn:Destroy()
			bannerBusy = false
			showNextBanner()
		end)
	end
	btn.Activated:Connect(function()
		if b.onPress then
			b.onPress()
		end
		close()
	end)
	task.delay(B.inSeconds + B.stay, close)
end
-- b = { kind = "rift" | "golden" | "serverGoal", title, line, onPress }
function UiParts.banner(b)
	for _, q in ipairs(bannerQueue) do
		if q.kind == b.kind then -- 같은 종류 = 합침(새 문구로)
			q.title, q.line, q.onPress = b.title, b.line, b.onPress
			return
		end
	end
	if #bannerQueue >= D.banner.maxQueue then
		return
	end
	table.insert(bannerQueue, b)
	showNextBanner()
end

-- ── §7 전투 문구(한 번에 1개 · 새 것이 오면 옛 것 0.1초에 사라짐) ──
local ctGui, ctCurrent
function UiParts.combatText(kind)
	local C = D.combatText
	local k = C.kinds[kind]
	if not k then
		return
	end
	local phone = UiKit.isPhone()
	local lp = Players.LocalPlayer
	if not ctGui then
		ctGui = Instance.new("ScreenGui")
		ctGui.Name = "CombatTextGui"
		ctGui.ResetOnSpawn = false
		ctGui.IgnoreGuiInset = true
		ctGui.DisplayOrder = 140
		ctGui.Parent = lp:WaitForChild("PlayerGui")
	end
	if ctCurrent then
		local old = ctCurrent
		tween(old, 0.1, { GroupTransparency = 1 })
		task.delay(0.1, function()
			old:Destroy()
		end)
	end
	local view = workspace.CurrentCamera.ViewportSize
	local m = require(ReplicatedStorage.Shared.HudPlace).scale(view.X, view.Y, phone)
	local px = (phone and k.size.phone or k.size.pc)
	local g = Instance.new("CanvasGroup")
	g.Name = "CombatText_" .. kind
	g.BackgroundTransparency = 1
	g.AnchorPoint = Vector2.new(0.5, 0.5)
	g.Position = UDim2.new(0.5, 0, phone and C.y.phone or C.y.pc, 0)
	g.Size = UDim2.fromOffset(px * 10, px * 2.2)
	g.GroupTransparency = 0.8
	g.Parent = ctGui
	ctCurrent = g
	local sc = Instance.new("UIScale")
	sc.Scale = C.popFrom * m
	sc.Parent = g
	if k.rays and not reduceFlash() then
		local r = image(g, C.rays, "Rays")
		r.AnchorPoint = Vector2.new(0.5, 0.5)
		r.Position = UDim2.fromScale(0.5, 0.4)
		r.Size = UDim2.fromOffset(px * 3, px * 3)
		r.ImageColor3 = hex(k.bottom)
		r.ImageTransparency = 0.45
		tween(r, 0.6, { Rotation = 20 }, Enum.EasingStyle.Linear)
	end
	local en = Instance.new("TextLabel")
	en.Name = "En"
	en.BackgroundTransparency = 1
	en.Size = UDim2.new(1, 0, 0, px * 1.2)
	en.Font = UiKit.font("number")
	en.TextSize = px
	en.Text = k.en
	en.TextColor3 = Color3.new(1, 1, 1)
	en.ZIndex = 2
	en.Parent = g
	local st = Instance.new("UIStroke")
	st.Color = hex("0E1120")
	st.Thickness = math.max(2, px * C.strokeRatio)
	st.Parent = en
	local gr = Instance.new("UIGradient")
	gr.Rotation = 90
	gr.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, hex(k.top)), ColorSequenceKeypoint.new(0.4, hex(k.top)), ColorSequenceKeypoint.new(0.41, hex(k.bottom)), ColorSequenceKeypoint.new(1, hex(k.bottom)) })
	gr.Parent = en
	local ko = UiKit.label(g, Text.get(k.textKey), "heading", "text.primary", { name = "Ko", font = "korean", align = Enum.TextXAlignment.Center })
	ko.Position = UDim2.fromOffset(0, px * 1.2)
	ko.Size = UDim2.new(1, 0, 0, px * 0.6)
	ko.TextStrokeTransparency = 0
	ko.TextStrokeColor3 = hex("0E1120")
	ko.ZIndex = 2
	task.spawn(function()
		local peak = reduceFlash() and 1 or C.popPeak
		tween(g, C.popInSeconds, { GroupTransparency = 0 })
		tween(sc, C.popInSeconds, { Scale = peak * m }, Enum.EasingStyle.Back)
		task.wait(C.popInSeconds)
		tween(sc, C.settleSeconds, { Scale = m })
		task.wait(C.settleSeconds + C.holdSeconds)
		if ctCurrent ~= g then
			return
		end
		tween(g, C.outSeconds, { GroupTransparency = 1, Position = UDim2.new(0.5, 0, phone and C.y.phone or C.y.pc, -C.outRise * m) })
		task.wait(C.outSeconds)
		if ctCurrent == g then
			ctCurrent = nil
		end
		g:Destroy()
	end)
end

-- ── §8 아이콘 받기 전: 판 위 점선 틀 + 첫 글자 + 반짝 → 받으면 0.15초 교차 · 5초 넘으면 글자 그대로 ──
function UiParts.loadingIcon(img, firstLetter)
	local L = D.loading
	if not img or img.Image == "" then
		return
	end
	local ok, status = pcall(function()
		return ContentProvider:GetAssetFetchStatus(img.Image)
	end)
	if ok and status == Enum.AssetFetchStatus.Success then
		return
	end
	local holder = Instance.new("Frame")
	holder.Name = "LoadingIcon"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.ClipsDescendants = true
	holder.ZIndex = img.ZIndex + 1
	holder.Parent = img
	local ring = Instance.new("UIStroke")
	ring.Color = hex(L.ring)
	ring.Thickness = 2
	ring.Parent = holder
	UiKit.corner(holder, 10)
	local letter = UiKit.label(holder, firstLetter or "", "heading", "text.primary", { name = "Letter", font = "korean", align = Enum.TextXAlignment.Center })
	letter.Size = UDim2.fromScale(1, 1)
	letter.TextColor3 = hex(L.letter)
	letter.ZIndex = holder.ZIndex
	local shimmer = image(holder, L.shimmer, "Shimmer")
	shimmer.Size = UDim2.fromScale(0.5, 1)
	shimmer.ZIndex = holder.ZIndex + 1
	local keep = img.ImageTransparency
	img.ImageTransparency = 1
	task.spawn(function()
		local t0 = os.clock()
		while holder.Parent do
			local s = ContentProvider:GetAssetFetchStatus(img.Image)
			if s == Enum.AssetFetchStatus.Success then
				tween(letter, L.crossSeconds, { TextTransparency = 1 })
				tween(img, L.crossSeconds, { ImageTransparency = keep })
				task.wait(L.crossSeconds)
				holder:Destroy()
				return
			elseif os.clock() - t0 > L.timeout then
				shimmer:Destroy() -- 5초 넘음 = 첫 글자 그대로
				return
			end
			shimmer.Position = UDim2.fromScale(-0.5 + 2 * (((os.clock() - t0) % L.period) / L.period), 0)
			task.wait(0.05)
		end
	end)
end

-- ── §9 빈 상태: kind = "rank" | "bag" | "egg" → { root, button } ──
function UiParts.emptyState(parent, kind, onButton)
	local E = D.empty
	local k = E.kinds[kind]
	local phone = UiKit.isPhone()
	local ringPx = phone and E.size.phone or E.size.pc
	local root = Instance.new("Frame")
	root.Name = "Empty_" .. kind
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = parent
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, phone and 6 or 12)
	list.Parent = root
	local ring = image(root, E.ring, "Ring")
	ring.Size = UDim2.fromOffset(ringPx, ringPx)
	ring.LayoutOrder = 1
	local ic = UiKit.icon(ring, k.icon, math.floor(ringPx * E.iconRatio), { center = true })
	ic.Name = "Icon"
	local title = UiKit.label(root, Text.get(k.titleKey), "heading", "text.primary", { name = "Title", font = "korean", align = Enum.TextXAlignment.Center, wrap = true })
	title.Size = UDim2.new(1, 0, 0, 0)
	title.AutomaticSize = Enum.AutomaticSize.Y
	title.TextWrapped = true
	title.LayoutOrder = 2
	local line = UiKit.label(root, Text.get(k.lineKey), "body", "text.secondary", { name = "Line", font = "korean", align = Enum.TextXAlignment.Center, wrap = true })
	line.Size = UDim2.new(1, 0, 0, 0)
	line.AutomaticSize = Enum.AutomaticSize.Y
	line.TextWrapped = true
	line.LayoutOrder = 3
	local button
	if k.buttonKey and onButton then
		button = UiKit.button({ kind = "secondary", text = Text.get(k.buttonKey), parent = root, onActivated = onButton })
		button.root.LayoutOrder = 4
		button.root.Size = UDim2.fromOffset(phone and 220 or 320, phone and 44 or 56)
	end
	return { root = root, button = button }
end

return UiParts
