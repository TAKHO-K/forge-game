-- UI-1 6단계 강화대 창(05_enhance-inherit/v4 spec §4 · §5 · §6): 강화대 근처 = 빠른 강화 창 · 큰 창(옛 강화 패널) = [i]로 열기(계승 · 초월 · 환생은 큰 창에서만).
--   PC = 아래 가운데 640 · 아래 끝 846(체력바 위) · 머리 / 단계 줄 / 확률 칩 / 불씨 칸 / 아래 줄(방지 · [i] · 비용 · [강화]) / 모자람 줄.
--   폰 = x 266 · 아래 끝 352 · 388 + 둥근 [강화] 96(B 공격 버튼 자리) · 창이 열린 동안 폰 전투 버튼 숨김(Attribute EnhanceStationOpen → SkillSlots).
--   결과 = 단계 줄 자리에 띠(2초 뒤 접힘 · 누르면 바로) + 불씨 칸 움직임(EmberBar.play) · 성공 = 창 테 초록 0.3초 · 07 강화 빛(WeaponEnhanceVisual)은 WeaponLevel로 그대로 바뀜.
--   UIManager station으로 등록(가방 등 window가 열리면 닫힘 · Esc) - 큰 창도 station이라 [i]를 누르면 이 창이 닫히고 큰 창이 열린다. 좌표 · 색 = UiLayoutData.enhance.v4.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enhance = require(ReplicatedStorage.Shared.Enhance)
local HudPlace = require(ReplicatedStorage.Shared.HudPlace)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Text = require(ReplicatedStorage.Shared.Text)
local L = require(ReplicatedStorage.Shared.data.UiLayoutData).enhance.v4
local BIG = require(ReplicatedStorage.Shared.data.UiV2Flags).enhanceBig
local ArtImage = require(script.Parent.Parent.Parent.ui.ArtImage)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)
local Toggle = require(script.Parent.Parent.Parent.ui.kit.Toggle)
local UiKit = require(script.Parent.Parent.Parent.ui.v2.UiKit)
local UIManager = require(script.Parent.Parent.Parent.UIManager)
local Controller = require(script.Parent.Controller)
local OddsView = require(script.Parent.OddsView)
local EmberBar = require(script.Parent.EmberBar)

local StationV4 = {}
StationV4.id = "EnhanceStationV4"
StationV4.dismissed = false -- 닫기 · Esc로 닫음 = 강화대를 벗어났다 돌아올 때까지 다시 안 열림

local player = Players.LocalPlayer
local W = L.window
local built = nil
local onInfo = nil -- [i] = 큰 창 열기(init이 넣는다)

local function hex(h)
	return Color3.fromHex(h)
end
local px = EmberBar.textPx

local function label(parent, text, size, color, font, align)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = UiKit.font(font or "koreanBold")
	l.TextSize = px(size)
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.RichText = true
	l.Text = text or ""
	l.Parent = parent
	return l
end

local function corner(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
end

local function row(parent, order, h, name)
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.LayoutOrder = order
	f.Size = UDim2.new(1, 0, 0, h)
	f.Parent = parent
	return f
end

local CHIP_KEYS = { "success", "maintain", "down1", "down2", "reset" }

local function chipText(key, level)
	if key == "reset" then
		local to = Enhance.getResetToLevel(level)
		return Text.get("ui1.enh.chip.reset", { n = tostring(to and (level - to) or 0) })
	end
	return Text.get("ui1.enh.chip." .. key)
end

-- 폰 강화대 창 = 체력 · 상태 줄도 숨김(스킬 · 대시 · 점프 · 고정은 SkillSlots가 EnhanceStationOpen으로 숨김 - spec §5)
local HIDE_ON_PHONE = { "PlayerHealthBarGui", "StatusHudGui" }
local function setCombatHud(on)
	local pg = player:FindFirstChild("PlayerGui")
	for _, name in ipairs(HIDE_ON_PHONE) do
		local g = pg and pg:FindFirstChild(name)
		if g then
			g.Enabled = on
		end
	end
end

local function build()
	Theme.recompute()
	local phone = Theme.isMobile
	local P = phone and L.phone or L.pc
	local base = phone and HudPlace.base.phone or HudPlace.base.pc
	local gui = Instance.new("ScreenGui")
	gui.Name = "EnhanceStationV4"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local root = Instance.new("Frame") -- 기준 해상도 판(PC = 아래 가운데 · 폰 = 오른쪽 아래 - 전투 버튼과 같은 기준)
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.AnchorPoint = phone and Vector2.new(1, 1) or Vector2.new(0.5, 1)
	root.Position = phone and UDim2.fromScale(1, 1) or UDim2.fromScale(0.5, 1)
	root.Size = UDim2.fromOffset(base.w, base.h)
	root.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = root
	local win -- 아래에서 만든다(배율 상한 계산에 높이를 씀)
	local function fit()
		local v = gui.AbsoluteSize
		if v.X > 1 then
			local m = HudPlace.scale(v.X, v.Y, phone)
			local s = m * (BIG and (phone and L.zoom.phone or L.zoom.pc) or 1) -- UI-1b 1절 15: 1.3배
			if BIG and win and win.AbsoluteSize.Y > 0 and scale.Scale > 0 then -- 창 위 끝 = 상단 바(+ 8) 아래까지만(작은 창에서 배율 하한 0.75 × 1.3이 상단 바를 덮던 것)
				local baseH = win.AbsoluteSize.Y / scale.Scale
				local top = game:GetService("GuiService"):GetGuiInset().Y + 8
				s = math.max(m, math.min(s, (v.Y - top) / (baseH + base.h - P.bottom)))
			end
			scale.Scale = s
		end
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()

	win = Instance.new("Frame")
	win.Name = "Window"
	win.BackgroundColor3 = hex(W.bg)
	win.BackgroundTransparency = W.bgT
	win.AutomaticSize = Enum.AutomaticSize.Y -- 글자 1.3 = 위로 늘어남(아래 끝 고정)
	win.Size = UDim2.fromOffset(P.w, 0)
	if phone then
		win.AnchorPoint = Vector2.new(0, 1)
		win.Position = UDim2.fromOffset(P.x, P.bottom)
	else
		win.AnchorPoint = Vector2.new(0.5, 1)
		win.Position = UDim2.fromOffset(P.cx, P.bottom)
	end
	win.Parent = root
	win:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		task.defer(fit)
	end)
	corner(win, phone and 12 or 16)
	local ws = Instance.new("UIStroke")
	ws.Thickness = 3
	ws.Color = hex(W.stroke)
	ws.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ws.Parent = win
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, P.pad), UDim.new(0, P.pad)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, phone and 6 or 10), UDim.new(0, phone and 6 or 10)
	pad.Parent = win
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, P.gap)
	list.Parent = win
	local innerW = P.w - P.pad * 2

	local R = { gui = gui, win = win, stroke = ws, phone = phone }
	-- 1. 머리
	local head = row(win, 1, P.head + (px(20) - 20), "Head")
	local icon = UiKit.icon(head, "growth", phone and 26 or 34)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.fromScale(0, 0.5)
	local x0 = (phone and 26 or 34) + 8
	if phone then
		R.levelText = label(head, "", 20, Color3.new(1, 1, 1), "number")
		R.levelText.Position = UDim2.fromOffset(x0, 0)
		R.levelText.Size = UDim2.new(1, -(x0 + P.close + 4), 1, 0)
	else
		local t = label(head, Text.get("ui1.enh.station"), 20, Color3.new(1, 1, 1), "korean")
		t.Name = "Title"
		t.Position = UDim2.fromOffset(x0, 0)
		t.Size = UDim2.new(0, 90, 1, 0)
		t.AutomaticSize = Enum.AutomaticSize.X
		R.weapon = label(head, "", 15, Color3.fromRGB(170, 176, 200))
		R.weapon.Position = UDim2.fromOffset(x0 + 96, 0)
		R.weapon.Size = UDim2.new(0, 200, 1, 0)
		local pill = Instance.new("Frame")
		pill.Name = "GoldPill"
		pill.BackgroundColor3 = hex("0E1120")
		pill.AnchorPoint = Vector2.new(1, 0.5)
		pill.Position = UDim2.new(1, -(P.close + 10), 0.5, 0)
		pill.Size = UDim2.fromOffset(110, 34)
		pill.Parent = head
		corner(pill, 17)
		local gi = UiKit.icon(pill, "gold", 20)
		gi.AnchorPoint = Vector2.new(0, 0.5)
		gi.Position = UDim2.new(0, 10, 0.5, 0)
		R.gold = label(pill, "", 15, Color3.new(1, 1, 1), "number")
		R.gold.Position = UDim2.fromOffset(34, 0)
		R.gold.Size = UDim2.new(1, -40, 1, 0)
	end
	local close = Instance.new("ImageButton")
	close.Name = "Close"
	close.BackgroundColor3 = hex(L.window.close)
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Position = UDim2.fromScale(1, 0.5)
	close.Size = UDim2.fromOffset(P.close, P.close)
	close.Parent = head
	corner(close, P.close / 2)
	local cx = UiKit.icon(close, "x", math.floor(P.close * 0.5), { center = true })
	cx.Name = "X"
	close.Activated:Connect(function()
		UIManager.close(StationV4.id)
	end)
	R.close = close
	if BIG then -- UI-1b 1절 15: "유물 무기" 줄 없앰(장비 이름 · 등급색 테로 충분) · 재화 칸 = 큰 아이콘 + "골드" + 숫자 · 누르면 A 설명 창
		if R.weapon then
			R.weapon.Visible = false
		end
		local old = head:FindFirstChild("GoldPill")
		if old then
			old.Visible = false
		end
		local G = phone and L.goldChip.phone or L.goldChip.pc
		local chip = Instance.new("TextButton")
		chip.Name = "GoldChip"
		chip.Text = ""
		chip.AutoButtonColor = false
		chip.BackgroundColor3 = hex("0E1120")
		chip.AnchorPoint = Vector2.new(1, 0.5)
		chip.Position = UDim2.new(1, -(P.close + 10 + (G.gainW or 0)), 0.5, 0) -- 폰: 머리 줄 오른쪽 "공격력 +n%" 글자 왼쪽
		chip.AutomaticSize = Enum.AutomaticSize.X
		chip.Size = UDim2.fromOffset(0, G.h)
		chip.Parent = head
		corner(chip, G.h / 2)
		local cp = Instance.new("UIPadding")
		cp.PaddingLeft, cp.PaddingRight = UDim.new(0, 6), UDim.new(0, 12)
		cp.Parent = chip
		local cl = Instance.new("UIListLayout")
		cl.FillDirection = Enum.FillDirection.Horizontal
		cl.VerticalAlignment = Enum.VerticalAlignment.Center
		cl.Padding = UDim.new(0, 6)
		cl.SortOrder = Enum.SortOrder.LayoutOrder
		cl.Parent = chip
		local gi = UiKit.icon(chip, "gold", G.icon)
		gi.LayoutOrder = 1
		local nm = label(chip, Text.get("item.name.gold"), G.name, Color3.fromRGB(184, 192, 214), "korean")
		nm.LayoutOrder = 2
		nm.AutomaticSize = Enum.AutomaticSize.X
		nm.Size = UDim2.fromOffset(0, G.h)
		R.gold = label(chip, "", G.num, Color3.new(1, 1, 1), "number")
		R.gold.LayoutOrder = 3
		R.gold.AutomaticSize = Enum.AutomaticSize.X
		R.gold.Size = UDim2.fromOffset(0, G.h)
		UiKit.attachPress(chip, { onActivated = function()
			require(script.Parent.Parent.Parent.ui.v2.InfoTip).currency(chip, "gold")
		end })
		if phone and R.levelText then
			R.levelText.Size = UDim2.new(1, -(x0 + P.close + 4 + G.levelRoom), 1, 0)
		end
	end

	-- 2. 단계 줄(PC) + 결과 띠(같은 자리)
	local levelRow
	if not phone then
		levelRow = row(win, 2, L.pc.levelRow + (px(28) - 28), "LevelRow")
		R.levelText = label(levelRow, "", 28, Color3.new(1, 1, 1), "number")
		R.levelText.Size = UDim2.fromScale(0.45, 1)
		R.gainText = label(levelRow, "", 18, hex(W.success), "koreanBold", Enum.TextXAlignment.Right)
		R.gainText.AnchorPoint = Vector2.new(1, 0)
		R.gainText.Position = UDim2.fromScale(1, 0)
		R.gainText.Size = UDim2.fromScale(0.55, 1)
	else
		R.gainText = label(head, "", 14, hex(W.success), "koreanBold", Enum.TextXAlignment.Right)
		R.gainText.AnchorPoint = Vector2.new(1, 0)
		R.gainText.Position = UDim2.new(1, -(P.close + 6), 0, 0)
		R.gainText.Size = UDim2.new(0, 90, 1, 0)
		levelRow = head
	end
	local band = Instance.new("TextButton")
	band.Name = "ResultBand"
	band.AutoButtonColor = false
	band.Text = ""
	band.Size = UDim2.fromScale(1, 1)
	band.BackgroundColor3 = hex("1E2438")
	band.Visible = false
	band.ZIndex = 5
	band.Parent = levelRow
	corner(band, 10)
	local bst = Instance.new("UIStroke")
	bst.Thickness = 3
	bst.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bst.Parent = band
	local bandText = label(band, "", phone and 18 or 24, Color3.new(1, 1, 1), "koreanBold", Enum.TextXAlignment.Center)
	bandText.Size = UDim2.fromScale(1, 1)
	bandText.ZIndex = 6
	band.Activated:Connect(function()
		band.Visible = false
	end)
	R.band, R.bandStroke, R.bandText = band, bst, bandText

	-- 3. 확률 칩
	local chips = row(win, 3, P.chips, "Chips")
	R.chips = chips
	-- 4. 불씨 칸
	local emberHolder = row(win, 4, EmberBar.height(phone), "Ember")
	R.ember = EmberBar.build(emberHolder, phone and (innerW - 352) / 2 or 0, 0, phone and 352 or innerW, phone)
	if require(ReplicatedStorage.Shared.data.UiV2Flags).help then -- UI-1b 1절 3: 불씨 규칙 줄(실패 1번 = 불씨 +n% · +n 칸 = 실패 n번) = 제목 옆 [?] 안 "지금" 줄
		local foot, footR = emberHolder:FindFirstChild("Foot", true), emberHolder:FindFirstChild("FootRight", true)
		for _, l in ipairs({ foot, footR }) do
			if l then
				l.Visible = false
			end
		end
		local anchorLabel = phone and R.levelText or head:FindFirstChild("Title")
		if anchorLabel then
			require(script.Parent.Parent.Parent.ui.v2.HelpButton).besideLabel(anchorLabel, "ember", { rows = function()
				local now = {}
				for _, l in ipairs({ foot, footR }) do
					if l and l.Text ~= "" then
						table.insert(now, l.Text)
					end
				end
				return #now > 0 and { { Text.get("ui1b.help.row.now"), table.concat(now, " · ") } } or {}
			end })
		end
	end

	-- 5. 아래 줄: 방지 토글 · [i] · 비용 · [강화](PC)
	local foot = row(win, 5, P.foot + (phone and 0 or (px(15) - 15)), "Foot")
	local shield = Instance.new("ImageLabel")
	shield.Name = "Shield"
	shield.BackgroundTransparency = 1
	shield.AnchorPoint = Vector2.new(0, 0.5)
	shield.Position = UDim2.fromScale(0, 0.5)
	shield.Size = UDim2.fromOffset(phone and 22 or 30, phone and 22 or 30)
	shield.Parent = foot
	R.shield = shield
	local gx = (phone and 22 or 30) + 6
	R.guardName = label(foot, Text.get("ui1.enh.guard"), phone and 12 or 15, Color3.new(1, 1, 1))
	R.guardName.Position = UDim2.fromOffset(gx, phone and 0 or 4)
	R.guardName.Size = UDim2.new(0, phone and 110 or 170, phone and 1 or 0.5, 0)
	R.guardSub = label(foot, "", phone and 11 or 12, Color3.fromRGB(150, 156, 180))
	R.guardSub.Position = phone and UDim2.fromOffset(gx + 112, 0) or UDim2.new(0, gx, 0.5, 0)
	R.guardSub.Size = UDim2.new(0, phone and 40 or 170, phone and 1 or 0.5, -4)
	R.toggle = Toggle.build({
		parent = foot,
		name = "GuardToggle",
		text = "",
		width = phone and 214 or 200, -- 이름 · 비용 배수 글자까지 누름 영역(트랙 = 오른쪽 끝)
		position = UDim2.new(0, gx, 0.5, 0),
		onChanged = function(value)
			for _, kind in ipairs(Controller.ticketKinds) do
				Controller.setToggle(kind, value)
			end
			StationV4.refresh()
		end,
	})
	R.toggle.root.AnchorPoint = Vector2.new(0, 0.5)
	R.cost = label(foot, "", phone and 13 or 16, Color3.new(1, 1, 1), "number", Enum.TextXAlignment.Right)
	if phone then
		R.cost.AnchorPoint = Vector2.new(1, 0)
		R.cost.Position = UDim2.fromScale(1, 0)
		R.cost.Size = UDim2.new(0, 110, 1, 0)
	else
		local bw, bh = L.pc.button[1], L.pc.button[2]
		R.button = UiKit.button({ parent = foot, kind = "primary", name = "EnhanceV4", text = Text.get("ui1.enh.button"), rect = { innerW - bw, 0, bw, bh }, align = Enum.TextXAlignment.Center,
			onActivated = function()
				StationV4.tryEnhance()
			end })
		R.cost.AnchorPoint = Vector2.new(1, 0)
		R.cost.Position = UDim2.new(1, -(bw + 10), 0, 0)
		R.cost.Size = UDim2.new(0, 120, 1, 0)
		local info = Instance.new("ImageButton")
		info.Name = "Info"
		info.BackgroundColor3 = hex("232A42")
		info.AnchorPoint = Vector2.new(1, 0.5)
		info.Position = UDim2.new(1, -(bw + 140), 0.5, 0)
		info.Size = UDim2.fromOffset(L.pc.info, L.pc.info)
		info.Parent = foot
		corner(info, 10)
		UiKit.icon(info, "info", 24, { center = true })
		info.Activated:Connect(function()
			if onInfo then
				onInfo()
			end
		end)
		R.info = info
	end
	-- 6. 모자람 줄
	R.short = label(win, "", phone and 11 or 13, hex(W.down))
	R.short.LayoutOrder = 6
	R.short.Size = UDim2.new(1, 0, 0, px(phone and 11 or 13) + 4)
	R.short.Visible = false

	-- 폰 둥근 [강화](B 공격 버튼 자리) + [i](머리 왼쪽 아이콘을 누르면 큰 창)
	if phone then
		local rr = L.phone.round
		local rb = Instance.new("ImageButton")
		rb.Name = "RoundEnhance"
		rb.BackgroundTransparency = 1
		rb.Position = UDim2.fromOffset(rr[1], rr[2])
		rb.Size = UDim2.fromOffset(rr[3], rr[4])
		rb.Image = ArtImage.get(L.images.round.normal) or ""
		rb.PressedImage = ArtImage.get(L.images.round.pressed) or ""
		rb.Parent = root
		local rt = label(rb, Text.get("ui1.enh.button"), 22, hex("3A2A00"), "korean", Enum.TextXAlignment.Center)
		rt.Size = UDim2.fromScale(1, 0.92)
		rb.Activated:Connect(function()
			StationV4.tryEnhance()
		end)
		R.round, R.roundText = rb, rt
		local ib = Instance.new("ImageButton") -- 큰 창 열기 = 머리 아이콘(누름 영역 44)
		ib.Name = "Info"
		ib.BackgroundTransparency = 1
		ib.Size = UDim2.fromOffset(44, 44)
		ib.AnchorPoint = Vector2.new(0, 0.5)
		ib.Position = UDim2.new(0, -6, 0.5, 0)
		ib.Parent = head
		ib.Activated:Connect(function()
			if onInfo then
				onInfo()
			end
		end)
		R.info = ib
	end

	local function attr()
		StationV4.refresh()
	end
	for _, name in ipairs(Controller.attributeNames()) do
		player:GetAttributeChangedSignal(name):Connect(attr)
	end
	Controller.connectResult(function(data)
		if built and gui.Enabled then
			StationV4.onResult(data)
		end
	end)

	UIManager.register(StationV4.id, {
		kind = "station",
		screenGui = gui,
		hasCloseButton = true,
		onOpen = function()
			gui.Enabled = true
			if phone then
				player:SetAttribute("EnhanceStationOpen", true)
				setCombatHud(false)
			end
			StationV4.refresh()
		end,
		onClose = function()
			gui.Enabled = false
			player:SetAttribute("EnhanceStationOpen", nil)
			setCombatHud(true)
			band.Visible = false
			task.defer(function() -- 닫기 · Esc = 다시 안 열림(큰 창 · 가방 등에 밀려 닫힘 · 걸어서 벗어남은 아님)
				if Controller.isNear() and #UIManager.getStack() == 0 then
					StationV4.dismissed = true
				end
			end)
		end,
	})
	built = R
end

function StationV4.ensure()
	Theme.recompute()
	if built and built.phone ~= Theme.isMobile then
		UIManager.unregister(StationV4.id)
		built.gui:Destroy()
		built = nil
	end
	if not built then
		build()
	end
end

function StationV4.setInfo(fn)
	onInfo = fn
end

function StationV4.isOpen()
	return built ~= nil and UIManager.isOpen(StationV4.id)
end

function StationV4.open()
	StationV4.ensure()
	return UIManager.open(StationV4.id)
end

function StationV4.close()
	if built then
		UIManager.close(StationV4.id)
	end
end

function StationV4.tryEnhance()
	local st = Controller.getState()
	if st.maxed or not st.canAfford then
		return
	end
	if built then
		built.reqLevel = st.level
		built.pendingUntil = os.clock() + 3 -- 결과가 올 때까지 불씨 칸은 시도 전 모습(서버가 Attribute를 먼저 바꾼다 → 연출이 결과에서 출발)
	end
	Controller.requestEnhance(StationV4.id, OddsView.formatPercent)
end

local function renderChips(R, st)
	for _, c in ipairs(R.chips:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local items = {}
	if st.gaugeFull and not st.maxed then
		table.insert(items, { text = Text.get("ui1.enh.chipFull"), color = hex(W.success) })
	elseif st.outcomes then
		for _, key in ipairs(CHIP_KEYS) do
			local p = st.outcomes[key] or 0
			if p > 0 and not (R.phone and key == "maintain") then -- 폰 = 그대로 칩 뺌(나머지에서 알 수 있음)
				local down = key ~= "success" and key ~= "maintain"
				table.insert(items, { text = chipText(key, st.level), p = OddsView.formatPercent(p), down = down, success = key == "success" })
			end
		end
	end
	local n = math.max(1, #items)
	local gap = R.phone and 4 or 6
	for i, it in ipairs(items) do
		local f = Instance.new("Frame")
		f.Name = "Chip"
		f.BackgroundColor3 = hex("1E2438")
		f.Position = UDim2.new((i - 1) / n, (i - 1) * gap / n, 0, 0)
		f.Size = UDim2.new(1 / n, -gap + gap / n, 1, 0)
		f.Parent = R.chips
		corner(f, 8)
		local color = it.success and hex(W.success) or (it.down and hex(W.down) or Color3.new(1, 1, 1))
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = UiKit.font("koreanBold")
		t.TextSize = R.phone and 12 or px(14) -- 폰 칩 글자 고정(1.3에서도)
		t.RichText = true
		t.TextColor3 = Color3.new(1, 1, 1)
		t.Text = it.p and (("%s%s <font color=\"#%s\">%s</font>"):format(it.down and "▼ " or "", it.text, color:ToHex(), it.p)) or it.text
		if not it.p then
			t.TextColor3 = color
		end
		t.Parent = f
	end
end

function StationV4.refresh()
	local R = built
	if not R or not R.gui.Enabled then
		return
	end
	local st = Controller.getState()
	local maxed = st.maxed
	local nextLv = st.level + 1
	R.levelText.Text = maxed and ("+%d"):format(st.level) or ("+%d <font color=\"#%s\">→ +%d</font>"):format(st.level, L.ember.amber, nextLv)
	local gain = maxed and 0 or (Enhance.getDamageMultiplier(nextLv) / Enhance.getDamageMultiplier(st.level) - 1)
	R.gainText.Text = maxed and "" or Text.get(R.phone and "ui1.enh.gainShort" or "ui1.enh.gain", { p = ("%.1f"):format(gain * 100) })
	if R.weapon then
		R.weapon.Text = Text.get("ui1.enh.weapon", { grade = st.gradeName })
	end
	if R.gold then
		R.gold.Text = NumberFormat.currency(st.gold, Text.languageFor())
	end
	renderChips(R, st)
	if not (R.pendingUntil and os.clock() < R.pendingUntil) then
		R.ember.update(st)
	end
	-- 방지: 이 단계에서 켤 수 있는 것이 하나라도 있으면 토글 · 가득 = "방지 필요 없음"
	local enabled, want, k = false, false, nil
	for _, kind in ipairs(Controller.ticketKinds) do
		local t = st.tickets[kind]
		if t.enabled then
			enabled = true
			want = want or t.want
		end
	end
	k = st.guardInfo and st.guardInfo.k
	R.toggle.setValue(want and enabled, true)
	R.toggle.setEnabled(enabled)
	R.shield.Image = ArtImage.get(want and enabled and L.images.shieldOn or L.images.shieldOff) or ""
	local short = R.phone and BIG -- UI-1b: 폰 = 글자가 커져 칸(40)을 넘으면 스위치 위로 번짐 → 짧은 문구("+19부터" · "없음")
	R.guardSub.Text = st.gaugeFull and Text.get(short and "ui1b.enh.guardNoneShort" or "ui1.enh.guardNone") or (k and Text.get(R.phone and "ui1.enh.guardCostShort" or "ui1.enh.guardCost", { k = ("%.1f"):format(k):gsub("%.0$", "") }) or Text.get(short and "ui1b.enh.guardFromShort" or "ui1.enh.guardFrom"))
	R.guardName.TextTransparency = enabled and 0 or 0.45
	-- 비용 · 버튼 · 모자람
	local costText = maxed and "" or NumberFormat.currency(st.cost or 0, Text.languageFor())
	local goldShort = st.cost and st.gold < st.cost
	R.cost.Text = maxed and "" or Text.get("ui1.enh.thisCost", { cost = costText, color = goldShort and W.down or "FFFFFF" })
	local btnText = maxed and Text.get("forge.enhance.buttonMax") or (st.gaugeFull and Text.get(R.phone and "ui1.enh.roundFull" or "ui1.enh.buttonFull") or Text.get("ui1.enh.button"))
	if R.button then
		R.button.setText(btnText)
		R.button.setEnabled(st.canAfford and not maxed)
	end
	if R.round then
		R.roundText.Text = btnText
		local img = L.images.round
		R.round.Image = ArtImage.get((maxed or not st.canAfford) and img.disabled or (st.gaugeFull and img.full or img.normal)) or ""
		R.round.Active = st.canAfford and not maxed
	end
	local short = nil
	if goldShort then
		short = Text.get("ui1.enh.shortGold", { n = NumberFormat.currency(st.gold, Text.languageFor()) })
	elseif st.material and st.material.have < st.material.need then -- 강화석 · 상급 강화석(+19 ~ +29 · 보고 대상 - 지시 "골드만"과 다름)
		short = Text.get("ui1.enh.shortMat", { name = st.material.name, have = tostring(st.material.have), need = tostring(st.material.need) })
	end
	R.short.Text = short and ("▼ " .. short) or ""
	R.short.Visible = short ~= nil
	R.stroke.Color = st.gaugeFull and hex(W.strokeFull) or hex(W.stroke)
end

-- 결과: 띠(2초 · 누르면 접힘) + 불씨 칸 + 성공 = 창 테 초록 0.3초
function StationV4.onResult(data)
	local R = built
	local after = Controller.getState()
	local res = data.result
	if res ~= "success" and res ~= "maintain" and res ~= "down1" and res ~= "down2" and res ~= "reset" then
		StationV4.refresh()
		return
	end
	local from = res == "success" and (data.level - 1) or nil
	local text, color
	if res == "success" then
		text = Text.get("ui1.enh.bandUp", { a = tostring(from), b = tostring(data.level) })
		color = hex(W.success)
	elseif res == "maintain" then
		text = data.blockedBy and Text.get("ui1.enh.bandBlocked", { a = tostring(data.level) }) or Text.get("ui1.enh.bandKeep", { a = tostring(data.level) })
		color = data.blockedBy and hex(W.success) or Color3.fromRGB(150, 156, 180)
	else
		local before = R.reqLevel or data.level
		text = Text.get("ui1.enh.bandDown", { a = tostring(before), b = tostring(data.level), color = W.down })
		color = Color3.fromRGB(150, 156, 180)
	end
	R.bandText.Text = text
	R.bandText.TextColor3 = res == "success" and hex(W.success) or Color3.new(1, 1, 1)
	R.bandStroke.Color = color
	R.band.BackgroundColor3 = res == "success" and hex("1F3A2C") or hex("1E2438")
	R.band.Visible = true
	local token = {}
	R.bandToken = token
	task.delay(L.band.seconds, function()
		if R.bandToken == token then
			R.band.Visible = false
		end
	end)
	R.pendingUntil = nil
	R.ember.play(data, after)
	if res == "success" then
		R.stroke.Color = hex(W.success)
		task.delay(0.3, function()
			StationV4.refresh()
		end)
	end
	task.delay(0.55, function()
		StationV4.refresh()
	end)
end

return StationV4
