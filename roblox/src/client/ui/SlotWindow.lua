-- QUEUE-MENU2 E 이어하기 창(기본 모양 - 화면 꾸밈은 Claude Design 목업 확정 뒤 · DESIGN-BACKLOG 14).
--   오른쪽에서 미끄러져 펼침(0.25초 · 폰 = 화면 오른쪽 절반 이상 · 버튼 높이 ≥ 터치 하한) · 카드 = 직업 + 번호(①) · 레벨 · 최고 스테이지 · 환생 · 대표 무기(등급색 테두리 + 강화) · 총 플레이 · 마지막 플레이.
--   마지막 플레이 캐릭터가 맨 위 + 선택 · 같은 카드 한 번 더 = 시작 · 빈 칸 = + 새 캐릭터 · 잠긴 칸 = 새 직업 출시 때 열림 · ⋯ = 보관(확인) · 아래 [보관함] = 복구.
--   SlotWindow.new(parent, { onPlay = fn(slot), onNew = fn() }) → { open(), close(), refresh(), isOpen() }
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArmorData = require(Shared.data.ArmorData)
local SlotSaveData = require(Shared.data.SlotSaveData)
local GradeColor = require(Shared.GradeColor)
local UIColors = require(Shared.data.UIColors)
local Text = require(Shared.Text)
local Theme = require(script.Parent.kit.Theme)

local SlotWindow = {}

local function playTime(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))
	local h, m = math.floor(seconds / 3600), math.floor(seconds % 3600 / 60)
	return h > 0 and Text.get("menu.slot.hm", { h = tostring(h), m = tostring(m) }) or Text.get("menu.slot.m", { m = tostring(m) })
end

local function dateOf(t)
	return t and os.date("%m-%d", t) or "-"
end

function SlotWindow.new(parent, opts)
	local remote = ReplicatedStorage:WaitForChild("SlotRequest", 10)
	local frame = Instance.new("Frame")
	frame.Name = "SlotWindow"
	frame.AnchorPoint = Vector2.new(1, 0)
	frame.BackgroundColor3 = Theme.color("panel")
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.ZIndex = 20
	frame.Parent = parent
	Theme.corner(frame, Theme.corner.panel)

	local title = Theme.label(frame, Text.get("menu.slot.title"), "title", "textPrimary")
	title.Position = UDim2.new(0, 16, 0, 12)
	title.Size = UDim2.new(1, -32, 0, 28)
	title.ZIndex = 21

	local status = Theme.label(frame, "", "caption", "textSecondary")
	status.Name = "Status"
	status.AnchorPoint = Vector2.new(0, 1)
	status.Size = UDim2.new(1, -32, 0, 18)
	status.ZIndex = 21

	local list = Instance.new("ScrollingFrame")
	list.Name = "Cards"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.new(0, 12, 0, 48)
	list.ScrollBarThickness = 4
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ZIndex = 21
	list.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, Theme.space[2])
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local storageButton = Instance.new("TextButton")
	storageButton.Name = "StorageButton"
	storageButton.AnchorPoint = Vector2.new(0, 1)
	storageButton.BackgroundColor3 = Theme.color("slot")
	storageButton.Font = Theme.font
	storageButton.TextColor3 = Theme.color("textPrimary")
	storageButton.TextSize = Theme.textSize("body")
	storageButton.ZIndex = 21
	storageButton.Parent = frame
	Theme.corner(storageButton, Theme.corner.button)

	local self = { selected = nil, data = nil, mode = "slots", busy = false, confirmArchive = nil }
	local isOpen = false

	local function layoutFrame()
		local size = parent.AbsoluteSize
		local mobile = Theme.isMobile
		local w = mobile and math.max(size.X * 0.52, 360) or math.min(math.max(size.X * 0.36, 380), 520)
		frame.Size = UDim2.new(0, w, 1, -24)
		frame.Position = UDim2.new(1, isOpen and -12 or w + 24, 0, 12)
		local bh = math.max(Theme.buttonHeight, Theme.touchMin)
		storageButton.Size = UDim2.new(1, -24, 0, bh)
		storageButton.Position = UDim2.new(0, 12, 1, -12)
		status.Position = UDim2.new(0, 16, 1, -18 - bh)
		list.Size = UDim2.new(1, -24, 1, -48 - bh - 44)
	end
	parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutFrame)

	local function setStatus(text, colorName)
		status.Text = text or ""
		status.TextColor3 = Theme.color(colorName or "textSecondary")
	end

	local function errText(reason)
		reason = type(reason) == "string" and reason:match("^[%w_]+") or reason
		return Text.get(SlotSaveData.errorReasons[reason] and ("menu.slot.err." .. reason) or "menu.slot.err.default")
	end

	local function call(action, arg)
		if not remote then
			return nil
		end
		local ok, res = pcall(function()
			return remote:InvokeServer(action, arg)
		end)
		return ok and res or nil
	end

	local function clearCards()
		for _, c in ipairs(list:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
	end

	local function cardFrame(order, height)
		local b = Instance.new("TextButton")
		b.AutoButtonColor = true
		b.Text = ""
		b.BackgroundColor3 = Theme.color("slot")
		b.Size = UDim2.new(1, -8, 0, height)
		b.LayoutOrder = order
		b.ZIndex = 22
		b.Parent = list
		Theme.corner(b, Theme.corner.chip)
		return b
	end

	local render

	local function charName(s)
		local glyph = SlotSaveData.numberGlyphs[s.number or 1] or tostring(s.number or 1)
		return Text.get("menu.slot.name", { class = Text.get("class.name." .. tostring(s.classId)), number = glyph })
	end

	local function onCard(slot)
		if self.busy then
			return
		end
		if self.selected == slot then
			self.busy = true
			setStatus(Text.get("menu.slot.loading"))
			local ok, why = opts.onPlay(slot)
			self.busy = false
			if not ok then
				setStatus(errText(why), "danger")
			end
			return
		end
		self.selected = slot
		self.confirmArchive = nil
		setStatus(Text.get("menu.slot.tapAgain"))
		render()
	end

	local function slotCard(order, slot, s)
		local selected = self.selected == slot
		local h = Theme.isMobile and 104 or 92
		local b = cardFrame(order, h)
		b.Name = "Slot" .. slot
		b:SetAttribute("CharId", s.charId)
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Thickness = selected and 3 or 1.5
		stroke.Color = selected and Theme.color("ember") or (UIColors.classAccent[s.classId] or Theme.color("rim"))
		stroke.Parent = b
		local accent = Instance.new("Frame")
		accent.BorderSizePixel = 0
		accent.BackgroundColor3 = UIColors.classAccent[s.classId] or Theme.color("rim")
		accent.Size = UDim2.new(0, 6, 1, -12)
		accent.Position = UDim2.new(0, 6, 0, 6)
		accent.ZIndex = 23
		accent.Parent = b
		local name = Theme.label(b, charName(s), "header", "textPrimary")
		name.Position = UDim2.new(0, 20, 0, 8)
		name.Size = UDim2.new(1, -150, 0, 22)
		name.ZIndex = 23
		local sub = Theme.label(b, Text.get("menu.slot.cardSub", { level = tostring(s.level or 1), best = tostring(s.best or 1), rebirth = tostring(s.rebirth or 0) }), "body", "textSecondary")
		sub.Position = UDim2.new(0, 20, 0, 32)
		sub.Size = UDim2.new(1, -28, 0, 18)
		sub.ZIndex = 23
		local meta = Theme.label(b, Text.get("menu.slot.play", { time = playTime(s.playSeconds) }) .. " · " .. Text.get("menu.slot.last", { date = dateOf(s.lastPlayedAt) }), "caption", "textTertiary")
		meta.Position = UDim2.new(0, 20, 1, -24)
		meta.Size = UDim2.new(1, -28, 0, 16)
		meta.ZIndex = 23
		-- 대표 무기: 등급색 테두리 + 강화 단계(초월이면 초월 +N)
		local gradeId = ArmorData.gradeOrder[(s.weaponGrade or 0) + 1] or "normal"
		local chip = Theme.label(b, s.transcend and Text.get("menu.slot.weaponT", { n = tostring(s.transcend) }) or Text.get("menu.slot.weapon", { n = tostring(s.weaponLevel or 0) }), "caption", "textPrimary")
		chip.Name = "WeaponChip"
		chip.AnchorPoint = Vector2.new(1, 0)
		chip.Position = UDim2.new(1, -48, 0, 8)
		chip.Size = UDim2.new(0, 96, 0, 22)
		chip.TextXAlignment = Enum.TextXAlignment.Center
		chip.BackgroundTransparency = 0.2
		chip.BackgroundColor3 = Theme.color("panel")
		chip.ZIndex = 23
		Theme.corner(chip, 6)
		local cs = Instance.new("UIStroke")
		cs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border -- 글자 외곽선이 아니라 칩 테두리
		cs.Thickness = 2
		cs.Color = GradeColor.of(gradeId)
		cs.Parent = chip
		local more = Instance.new("TextButton")
		more.Name = "More"
		more.AnchorPoint = Vector2.new(1, 0)
		more.Position = UDim2.new(1, -4, 0, 2)
		more.Size = UDim2.new(0, Theme.touchMin - 4, 0, Theme.touchMin - 4)
		more.BackgroundTransparency = 1
		more.Font = Theme.font
		more.TextSize = Theme.textSize("header")
		more.TextColor3 = Theme.color("textSecondary")
		more.Text = Text.get("menu.slot.more")
		more.ZIndex = 24
		more.Parent = b
		more.Activated:Connect(function()
			self.confirmArchive = slot
			render()
		end)
		b.Activated:Connect(function()
			onCard(slot)
		end)
		if self.confirmArchive == slot then
			local c = cardFrame(order + 0.5, math.max(Theme.buttonHeight, Theme.touchMin) + 48)
			c.AutoButtonColor = false
			local q = Theme.label(c, Text.get("menu.slot.archiveConfirm", { name = charName(s) }), "caption", "textPrimary")
			q.Position = UDim2.new(0, 12, 0, 6)
			q.Size = UDim2.new(1, -24, 0, 36)
			q.TextWrapped = true
			q.ZIndex = 23
			local function small(text, x, cb, colorName)
				local btn = Instance.new("TextButton")
				btn.AnchorPoint = Vector2.new(0, 1)
				btn.Position = UDim2.new(x, x == 0 and 12 or 4, 1, -6)
				btn.Size = UDim2.new(0.5, -16, 0, math.max(Theme.buttonHeight, Theme.touchMin))
				btn.BackgroundColor3 = Theme.color(colorName)
				btn.Font = Theme.font
				btn.TextSize = Theme.textSize("body")
				btn.TextColor3 = Theme.color("textPrimary")
				btn.Text = text
				btn.ZIndex = 24
				btn.Parent = c
				Theme.corner(btn, Theme.corner.button)
				btn.Activated:Connect(cb)
			end
			small(Text.get("menu.slot.archive"), 0, function()
				local res = call("archive", slot)
				self.confirmArchive = nil
				if res and res.ok then
					self.refresh()
				else
					setStatus(errText(res and res.reason), "danger")
					render()
				end
			end, "danger")
			small(Text.get("menu.slot.cancel"), 0.5, function()
				self.confirmArchive = nil
				render()
			end, "slot")
		end
	end

	local function emptyCard(order)
		local b = cardFrame(order, math.max(56, Theme.touchMin + 8))
		b.Name = "NewCharacter"
		local l = Theme.label(b, Text.get("menu.slot.new"), "header", "textPrimary")
		l.Size = UDim2.fromScale(1, 1)
		l.TextXAlignment = Enum.TextXAlignment.Center
		l.ZIndex = 23
		b.Activated:Connect(function()
			if self.busy then
				return
			end
			self.busy = true
			setStatus(Text.get("menu.slot.loading"))
			local ok, why = opts.onNew()
			self.busy = false
			if not ok then
				setStatus(errText(why), "danger")
			end
		end)
	end

	local function lockedCard(order)
		local f = Instance.new("Frame")
		f.Name = "Locked"
		f.BackgroundColor3 = Theme.color("slot")
		f.BackgroundTransparency = 0.5
		f.Size = UDim2.new(1, -8, 0, math.max(56, Theme.touchMin + 8))
		f.LayoutOrder = order
		f.ZIndex = 22
		f.Parent = list
		Theme.corner(f, Theme.corner.chip)
		local l = Theme.label(f, Text.get("menu.slot.locked"), "body", "textTertiary")
		l.Size = UDim2.fromScale(1, 1)
		l.TextXAlignment = Enum.TextXAlignment.Center
		l.ZIndex = 23
	end

	local function storageView()
		local arch = self.data and self.data.archive or {}
		if #arch == 0 then
			local l = Theme.label(list, Text.get("menu.slot.storageEmpty"), "body", "textSecondary")
			l.Size = UDim2.new(1, -8, 0, 40)
			l.ZIndex = 22
			return
		end
		for i, s in ipairs(arch) do
			local b = cardFrame(i, math.max(64, Theme.touchMin + 16))
			b.Name = "Archived" .. i
			b.AutoButtonColor = false
			local n = Theme.label(b, Text.get("class.name." .. tostring(s.classId)) .. " · Lv." .. tostring(s.level or 1), "header", "textPrimary")
			n.Position = UDim2.new(0, 12, 0, 8)
			n.Size = UDim2.new(1, -120, 0, 22)
			n.ZIndex = 23
			local r = Instance.new("TextButton")
			r.Name = "Restore"
			r.AnchorPoint = Vector2.new(1, 0.5)
			r.Position = UDim2.new(1, -8, 0.5, 0)
			r.Size = UDim2.new(0, 96, 0, math.max(Theme.buttonHeight, Theme.touchMin))
			r.BackgroundColor3 = Theme.color("success")
			r.Font = Theme.font
			r.TextSize = Theme.textSize("body")
			r.TextColor3 = Theme.color("panel")
			r.Text = Text.get("menu.slot.restore")
			r.ZIndex = 24
			r.Parent = b
			Theme.corner(r, Theme.corner.button)
			r.Activated:Connect(function()
				local res = call("restore", i)
				if res and res.ok then
					self.mode = "slots"
					self.refresh()
				else
					setStatus(errText(res and res.reason), "danger")
				end
			end)
		end
	end

	render = function()
		clearCards()
		local d = self.data
		if not d then
			return
		end
		storageButton.Text = self.mode == "storage" and Text.get("menu.back") or Text.get("menu.slot.storage", { n = tostring(#(d.archive or {})), max = tostring(d.maxArchive or 10) })
		if self.mode == "storage" then
			storageView()
			return
		end
		-- 마지막 플레이가 맨 위(사용 칸 = 마지막 플레이 순) → 빈 칸 → 잠긴 칸
		local used = {}
		for i = 1, d.slotCount or 0 do
			if d.slots[i] then
				table.insert(used, i)
			end
		end
		table.sort(used, function(a, b)
			return (d.slots[a].lastPlayedAt or 0) > (d.slots[b].lastPlayedAt or 0)
		end)
		local order = 0
		for _, i in ipairs(used) do
			order += 1
			slotCard(order, i, d.slots[i])
		end
		for i = 1, d.slotCount or 0 do
			if not d.slots[i] then
				order += 1
				emptyCard(order)
				break -- 빈 칸은 한 장(+ 새 캐릭터)만
			end
		end
		for _ = 1, d.lockedPreview or 0 do
			order += 1
			lockedCard(order)
		end
	end

	function self.refresh()
		self.data = call("list")
		if not (self.data and self.data.enabled ~= false and self.data.slots) then
			return false
		end
		local d = self.data
		if not (self.selected and d.slots[self.selected]) then
			local best, bestAt = nil, -1
			for i = 1, d.slotCount or 0 do
				local s = d.slots[i]
				if s and (s.lastPlayedAt or 0) > bestAt then
					best, bestAt = i, s.lastPlayedAt or 0
				end
			end
			self.selected = best
		end
		setStatus(self.selected and Text.get("menu.slot.tapAgain") or "")
		render()
		return true
	end

	storageButton.Activated:Connect(function()
		self.mode = self.mode == "storage" and "slots" or "storage"
		self.confirmArchive = nil
		render()
	end)

	function self.open()
		if not self.refresh() then
			return false
		end
		isOpen = true
		frame.Visible = true
		layoutFrame()
		local target = frame.Position
		frame.Position = UDim2.new(1, frame.AbsoluteSize.X + 24, 0, 12)
		TweenService:Create(frame, TweenInfo.new(SlotSaveData.windowSlideSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = target }):Play()
		return true
	end

	function self.close()
		isOpen = false
		frame.Visible = false
		self.mode = "slots"
		self.confirmArchive = nil
	end

	function self.isOpen()
		return isOpen
	end

	self.frame = frame
	layoutFrame()
	return self
end

return SlotWindow
