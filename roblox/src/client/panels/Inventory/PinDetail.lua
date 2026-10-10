-- UI-1c 5단계 장비 상세 고정 창 + 보석 2단(I v1 §3 · pc_07 · pc_08 · pc_09 · ph_05 · 스위치 UiV2Flags.gearPin).
--   상세 판(DetailSheet의 Detail 프레임 = 내용 · 버튼 · 잠금 그대로)을 창 밖(ScreenGui 자식)으로 옮겨 누른 칸 옆에 고정한다: 하늘 테 3 · 머리 "고정됨 · 바깥 누르면 닫힘" + [닫기] · 칸 ↔ 창 하늘 선(PC).
--   닫기 = 같은 칸 다시 누름(기존 토글) · 창 바깥 누름 · [닫기]. 다른 칸 누름 = 그 칸 것으로 바뀜(창 하나 - 선택 상태 하나).
--   상세 안 보석 홈 누름(무기) = 보석 창 겹침(자홍 테 · 상세 오른쪽 · 고른 홈 = 흰 고리 + 자홍 점선) · 같은 홈 다시 / [×] = 보석 창만 · 바깥 = 둘 다.
--   보석 "빼기"는 서버에 없다(항상 교체 - GemActions) → [빼기] = 회색 + 이유 토스트 · [바꾸기] = 보석 탭의 그 홈.
--   InventoryGui = Global z → 고정 창 · 보석 창 자식 전부 z + zBump(칸 위 · 확인 창 22 아래).
-- PinDetail.attach(S, R, detail, card) -> pin = { head(phone), size(L), place(L, w, h), update(), shown() }
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local P = require(ReplicatedStorage.Shared.data.UiLayoutData).bag.pin
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local Gem = require(ReplicatedStorage.Shared.Gem)
local GradeColor = require(ReplicatedStorage.Shared.GradeColor)
local ItemDescribe = require(ReplicatedStorage.Shared.ItemDescribe)
local Text = require(ReplicatedStorage.Shared.Text)
local ItemIcons = require(script.Parent.Parent.Parent.ItemIcons)
local Toast = require(script.Parent.Parent.Parent.ui.kit.Toast)
local UiKit = require(script.Parent.Parent.Parent.ui.v2.UiKit)
local V9 = require(script.Parent.Parent.Parent.ui.v2.UiV9)

local PinDetail = {}
local C = P.colors

local function gradeName(gradeId)
	local g = ArmorData.grades[gradeId]
	return g and Text.name(g.displayName) or tostring(gradeId) -- 영어 = 이름 표(Text.name)
end

function PinDetail.attach(S, R, detail, card)
	local gui = R.screenGui
	local player = Players.LocalPlayer
	local function geo()
		return S.mode == "phone" and P.phone or P.pc
	end

	-- z: 고정 창 · 보석 창 · 선 = 자식까지 + zBump(한 번만 · 나중에 생기는 자식도)
	local function bump(inst)
		if inst:IsA("GuiObject") and not inst:GetAttribute("PinZ") then
			inst:SetAttribute("PinZ", true)
			inst.ZIndex += P.zBump
		end
	end
	local function bumpTree(root)
		bump(root)
		for _, d in ipairs(root:GetDescendants()) do
			bump(d)
		end
		root.DescendantAdded:Connect(bump)
	end

	detail.Parent = gui -- 창(ClipsDescendants) 밖으로: 칸 옆이 창 끝을 넘어도 보임
	local stroke = detail:FindFirstChild("CardStroke")
	if stroke then
		stroke.Color = V9.hex(C.sky)
		stroke.Thickness = P.pc.stroke
		stroke.Transparency = 0
	end
	detail.BackgroundColor3 = V9.hex(C.panel)
	detail.BackgroundTransparency = 0.02
	detail.Active = true -- 창 밖 형제라 뒤 칸으로 클릭이 새지 않게(폰에서 갑옷 칸이 눌림 - Play 발견)

	-- 머리: 고정 표시 + [닫기]
	local head = Instance.new("Frame")
	head.Name = "PinHead"
	head.BackgroundTransparency = 1
	head.Parent = detail
	local dot = Instance.new("Frame")
	dot.Name = "PinDot"
	dot.BackgroundTransparency = 1
	dot.AnchorPoint = Vector2.new(0, 0.5)
	dot.Size = UDim2.fromOffset(16, 16)
	dot.Parent = head
	V9.corner(dot, "pill")
	V9.stroke(dot, C.sky, 2)
	local dotIn = V9.frame(dot, { 5, 5, 6, 6 }, C.sky, "In")
	V9.corner(dotIn, "pill")
	local pinned = V9.label(head, Text.get("ui1c.gear.pinned"), V9.px(15), C.sky, { name = "Pinned" })
	local closeB = UiKit.button({ kind = "secondary", name = "PinClose", text = Text.get("ui1c.gear.close"), textSize = "body", padX = 8, align = Enum.TextXAlignment.Center, parent = head, rect = { 0, 0, 88, 36 }, onActivated = function()
		PinDetail._close()
	end }).root
	local headLine = V9.frame(head, { 0, 0, 0, 1 }, C.rowLine, "Line")

	-- 칸 ↔ 창 하늘 선(PC) · 끝 점
	local line = Instance.new("Frame")
	line.Name = "PinLine"
	line.BorderSizePixel = 0
	line.BackgroundColor3 = V9.hex(C.sky)
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Visible = false
	line.Parent = gui
	local lineDot = Instance.new("Frame")
	lineDot.Name = "PinLineDot"
	lineDot.BorderSizePixel = 0
	lineDot.BackgroundColor3 = V9.hex(C.sky)
	lineDot.AnchorPoint = Vector2.new(0.5, 0.5)
	lineDot.Size = UDim2.fromOffset(12, 12)
	lineDot.Visible = false
	lineDot.Parent = gui
	V9.corner(lineDot, "pill")

	-- 보석 창(2단)
	local gemPop = Instance.new("Frame")
	gemPop.Name = "GemPin"
	gemPop.BackgroundColor3 = V9.hex(C.panel)
	gemPop.BackgroundTransparency = 0.02
	gemPop.Visible = false
	gemPop.Active = true
	gemPop.Parent = gui
	V9.corner(gemPop, 14)
	V9.stroke(gemPop, C.magenta, P.pc.stroke)
	local dashes = Instance.new("Folder")
	dashes.Name = "GemPinDashes"
	dashes.Parent = gui
	bumpTree(detail)
	bumpTree(gemPop)
	bump(line)
	bump(lineDot)

	local pin = {}
	local gemSlot = nil -- 보석 창이 보여 주는 홈
	local hits = {} -- [slot] = 누름 칸
	local selKey, serial = nil, 0

	local function rel(v)
		return v - gui.AbsolutePosition
	end
	local function lang()
		return Text.languageFor() == "en"
	end

	function pin.head()
		return geo().head
	end
	function pin.size(L)
		local g = geo()
		local w = lang() and g.wEn or g.w
		if S.mode == "phone" then
			w = math.min(w, math.floor(L.winW * 0.56))
			return w, L.winH - L.headerH - 8 -- 머리 아래부터(재화 줄 덮음 - 폰 높이 302라 내용 칸 확보)
		end
		return w, math.min(g.h, L.screenH - 16)
	end

	local function visibleInTree(a)
		local o = a
		while o and o:IsA("GuiObject") do
			if not o.Visible then
				return false
			end
			o = o.Parent
		end
		return o ~= nil
	end
	local function anchorRect()
		local a = S.pinAnchor
		if a and a.Parent and a:IsA("GuiObject") and a.AbsoluteSize.X > 0 and visibleInTree(a) then
			return rel(a.AbsolutePosition), a.AbsoluteSize
		end
		return nil
	end

	local lastPos
	function pin.place(L, w, h)
		local sw, sh = gui.AbsoluteSize.X, gui.AbsoluteSize.Y
		local win = R.win
		local x, y
		local ap, as = anchorRect()
		if S.mode == "phone" then
			local wp = rel(win.AbsolutePosition)
			x, y = wp.X + 8, wp.Y + L.headerH + 4
		elseif ap then
			local gap = geo().gap
			x = ap.X + as.X + gap
			if x + w > sw - 8 then
				x = ap.X - gap - w
			end
			x = math.clamp(x, 8, math.max(8, sw - w - 8))
			y = math.clamp(ap.Y - 60, 8, math.max(8, sh - h - 8))
		elseif lastPos then
			x, y = lastPos.X, lastPos.Y
		else -- 보석 탭 등 칸 없는 선택 = 창 오른쪽 안
			local wp, ws = rel(win.AbsolutePosition), win.AbsoluteSize
			x, y = wp.X + ws.X - w - 16, wp.Y + L.headerH + 12
		end
		lastPos = Vector2.new(x, y)
		detail.Position = UDim2.fromOffset(x, y)
		detail.Size = UDim2.fromOffset(w, h)
		local hd = pin.head()
		head.Position = UDim2.fromOffset(12, 0)
		head.Size = UDim2.fromOffset(w - 24, hd)
		dot.Position = UDim2.fromOffset(0, hd / 2)
		pinned.Position = UDim2.fromOffset(24, 0)
		pinned.Size = UDim2.fromOffset(w - 24 - 24 - 96, hd)
		closeB.Position = UDim2.fromOffset(w - 24 - 88, math.floor((hd - 36) / 2))
		headLine.Position = UDim2.fromOffset(0, hd - 1)
		headLine.Size = UDim2.fromOffset(w - 24, 1)
		-- 하늘 선: 칸 가장자리 가운데 → 창 가장자리(PC · 칸이 있을 때)
		local showLine = S.mode ~= "phone" and ap ~= nil and geo().line > 0
		line.Visible, lineDot.Visible = showLine, showLine
		if showLine then
			local right = x >= ap.X + as.X
			local ay = ap.Y + as.Y / 2
			local from = Vector2.new(right and ap.X + as.X or ap.X, ay)
			local to = Vector2.new(right and x or x + w, math.clamp(ay, y + 24, y + h - 24))
			local d = to - from
			line.Position = UDim2.fromOffset((from.X + to.X) / 2, (from.Y + to.Y) / 2)
			line.Size = UDim2.fromOffset(math.max(1, d.Magnitude), geo().line)
			line.Rotation = math.deg(math.atan2(d.Y, d.X))
			lineDot.Position = UDim2.fromOffset(from.X, from.Y)
		end
	end

	-- ═══ 보석 창 ═══
	local function clearDashes()
		for _, c in ipairs(dashes:GetChildren()) do
			c:Destroy()
		end
	end
	local function hideGem()
		gemSlot = nil
		gemPop.Visible = false
		clearDashes()
		for _, h in pairs(hits) do
			local ring = h.Parent and h.Parent:FindFirstChild("PinRing")
			if ring then
				ring.Enabled = false
			end
		end
	end

	local function drawDashes(from, to)
		clearDashes()
		local d = to - from
		local len = d.Magnitude
		local n = math.floor(len / 14)
		for i = 0, n - 1 do
			local p = from + d * ((i * 14 + 4) / len)
			local seg = Instance.new("Frame")
			seg.BorderSizePixel = 0
			seg.BackgroundColor3 = V9.hex(C.magenta)
			seg.AnchorPoint = Vector2.new(0.5, 0.5)
			seg.Position = UDim2.fromOffset(p.X, p.Y)
			seg.Size = UDim2.fromOffset(8, 3)
			seg.Rotation = math.deg(math.atan2(d.Y, d.X))
			seg.ZIndex = 1 + P.zBump + 2
			seg.Parent = dashes
		end
	end

	local function showGem(slot)
		local state = S.gemState and S.gemState()
		local gem = state and Gem.isFilled(state.gems, slot) and state.gems[slot]
		if not gem then
			hideGem()
			return
		end
		gemSlot = slot
		for _, c in ipairs(gemPop:GetChildren()) do
			if not c:IsA("UICorner") and not c:IsA("UIStroke") then
				c:Destroy()
			end
		end
		local phone = S.mode == "phone"
		local g = geo()
		local W, H = g.gemW, g.gemH
		local dp, ds = rel(detail.AbsolutePosition), detail.AbsoluteSize
		local sw = gui.AbsoluteSize.X
		local x = dp.X + ds.X + (phone and 8 or 24)
		if phone and sw - x - 8 >= 260 then
			W = math.min(W, sw - x - 8) -- 폰: 상세 옆 남은 폭에 맞춤(나란히 - ph_05)
		elseif x + W > sw - 8 then
			x = math.max(8, sw - W - 8)
		end
		local y = dp.Y + (phone and 40 or math.floor(ds.Y * 0.45))
		y = math.clamp(y, 8, math.max(8, gui.AbsoluteSize.Y - H - 8))
		gemPop.Position = UDim2.fromOffset(x, y)
		gemPop.Size = UDim2.fromOffset(W, H)
		local described = ItemDescribe.gem(gem, player:GetAttribute("ClassId"))
		local pad = phone and 10 or 18
		local icon = g.gemIcon
		local holder = V9.frame(gemPop, { pad, pad, icon, icon }, nil, "GemIcon")
		ItemIcons.gem(holder, gem, GradeColor.border(gem.grade))
		local tx = pad + icon + 12
		local closeSize = phone and 32 or 40
		V9.label(gemPop, described.title, V9.px(phone and 14 or 22), "FFFFFF", { name = "GemName", rect = { tx, pad, W - tx - closeSize - pad - 6, phone and 22 or 30 } })
		local pill = V9.frame(gemPop, { tx, pad + (phone and 24 or 34), 0, phone and 20 or 26 }, GradeColor.border(gem.grade), "GradePill")
		pill.AutomaticSize = Enum.AutomaticSize.X
		V9.corner(pill, "pill")
		local pl = V9.label(pill, gradeName(gem.grade), V9.px(phone and 12 or 15), "FFFFFF", { name = "Grade", align = Enum.TextXAlignment.Center })
		pl.AutomaticSize = Enum.AutomaticSize.X
		pl.Size = UDim2.fromOffset(0, phone and 20 or 26)
		pl.TextTruncate = Enum.TextTruncate.None
		local pp = Instance.new("UIPadding")
		pp.PaddingLeft, pp.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
		pp.Parent = pill
		UiKit.closeButton({ parent = gemPop, name = "GemClose", rect = { W - pad - closeSize, pad, closeSize, closeSize }, onActivated = hideGem })
		-- 줄: 효과 · 홈(데이터에 없는 "얻은 곳"은 안 그림)
		local effect = {}
		for _, o in ipairs(described.options or {}) do
			table.insert(effect, o.text)
		end
		local rows = {
			{ Text.get("ui1c.gear.gem.effect"), table.concat(effect, " · ") },
			{ Text.get("ui1c.gear.gem.slot"), Text.get("ui1c.gear.gem.slotLine", { slot = tostring(slot), grade = gradeName(Gem.gradeCapForSlot(slot, state.transcendSlots)) }) },
		}
		local rowH = phone and 30 or 44
		local ry = pad + icon + (phone and 6 or 14)
		for i, r in ipairs(rows) do
			V9.frame(gemPop, { pad, ry, W - pad * 2, 1 }, C.rowLine, "RowLine" .. i)
			V9.label(gemPop, r[1], V9.px(phone and 12 or 15), C.label, { name = "RowKey" .. i, rect = { pad, ry, phone and 44 or 90, rowH } })
			V9.label(gemPop, r[2], V9.px(phone and 13 or 18), "FFFFFF", { name = "RowVal" .. i, rect = { pad + (phone and 50 or 100), ry, W - pad * 2 - (phone and 50 or 100), rowH } })
			ry += rowH
		end
		local bh = phone and 40 or 52
		local by = H - pad - bh
		local bw = math.floor((W - pad * 3) / 2)
		UiKit.button({ kind = "secondary", name = "GemRemove", text = Text.get("ui1c.gear.gem.remove"), textSize = "body", align = Enum.TextXAlignment.Center, parent = gemPop, rect = { pad, by, bw, bh }, onActivated = function()
			Toast.push("TC", { text = Text.get("ui1c.gear.gem.removeNo"), colorName = "textPrimary", seconds = 3 })
		end }).title.TextColor3 = V9.hex(C.muted) -- 서버에 빼기 없음 = 흐린 글자 + 누르면 이유
		UiKit.button({ kind = "primary", name = "GemSwap", text = Text.get("ui1c.gear.gem.swap"), textSize = "body", align = Enum.TextXAlignment.Center, parent = gemPop, rect = { pad * 2 + bw, by, bw, bh }, onActivated = function()
			local s = slot
			PinDetail._close()
			S.pinAnchor, lastPos = nil, nil
			R.selectTab("보석")
			S.selectedKind, S.selectedValue = "gemSlot", s
			S.refreshDetail()
		end })
		gemPop.Visible = true
		-- 고른 홈 = 흰 고리 + 자홍 점선(홈 → 보석 창)
		for s2, h in pairs(hits) do
			local ring = h.Parent and h.Parent:FindFirstChild("PinRing")
			if ring then
				ring.Enabled = s2 == slot
			end
		end
		local h = hits[slot]
		if h and h.Parent then
			local sp, ss = rel(h.Parent.AbsolutePosition), h.Parent.AbsoluteSize
			drawDashes(Vector2.new(sp.X + ss.X, sp.Y + ss.Y / 2), Vector2.new(x, y + 40))
		end
	end

	-- 상세 안 보석 홈 = 누름 칸(무기 상세의 GemRow · 홈 Frame 위)
	local function hookSockets()
		local row = card.scroll:FindFirstChild("GemRow", true)
		if not row then
			return
		end
		for slot = 1, Gem.slotCount do
			local socket = row:FindFirstChild("Socket" .. slot)
			if socket and not hits[slot] then
				local ring = Instance.new("UIStroke")
				ring.Name = "PinRing"
				ring.Color = V9.hex(C.socketRing)
				ring.Thickness = 3
				ring.Enabled = false
				ring.Parent = socket
				local b = Instance.new("TextButton")
				b.Name = "PinHit"
				b.Text = ""
				b.BackgroundTransparency = 1
				b.AnchorPoint = Vector2.new(0.5, 0.5)
				b.Position = UDim2.fromScale(0.5, 0.5)
				b.Size = UDim2.fromOffset(P.socketHit, P.socketHit)
				b.ZIndex = socket.ZIndex + 3
				b.Parent = socket
				b.Activated:Connect(function()
					local state = S.gemState and S.gemState()
					if state and Gem.isFilled(state.gems, slot) then
						if gemSlot == slot then
							hideGem()
						else
							showGem(slot)
						end
					elseif state and state.slotUnlocked and state.slotUnlocked[slot] then
						PinDetail._close()
						S.pinAnchor, lastPos = nil, nil
						R.selectTab("보석")
						S.selectedKind, S.selectedValue = "gemSlot", slot
						S.refreshDetail()
					else
						Toast.push("TC", { text = Text.get("ui1.bag.gemSoon"), colorName = "textPrimary", seconds = 2 })
					end
				end)
				hits[slot] = b
			end
		end
	end

	function pin.shown()
		return S.selectedKind ~= nil
	end

	-- refreshDetail 뒤: 보임 · 선 · 보석 창(선택이 바뀌면 보석 창 닫음)
	function pin.update()
		local key = tostring(S.selectedKind) .. ":" .. tostring(S.selectedValue)
		if key ~= selKey then
			selKey = key
			serial += 1
			hideGem()
		end
		local shown = pin.shown() and R.screenGui.Enabled and R.win.Visible -- 가방을 닫으면 Window만 숨는다(ScreenGui는 켜짐) → 창 밖 형제인 고정 창도 같이
		detail.Visible = shown
		if not shown then
			line.Visible, lineDot.Visible = false, false
			hideGem()
			return
		end
		for _, st in ipairs(detail:GetChildren()) do -- 하늘 테 3(03 v2 모양 코드가 CardStroke를 끄고 SectionStroke를 붙인다 - 보이는 테 전부)
			if st:IsA("UIStroke") then
				st.Color = V9.hex(C.sky)
				st.Thickness = geo().stroke
				st.Transparency = 0
			end
		end
		if S.compareTip and S.compareTip.hide then
			S.compareTip.hide() -- 열기 전 마우스 올림 설명이 남지 않게
		end
		hookSockets()
		if gemSlot then
			showGem(gemSlot)
		end
	end

	function PinDetail._close()
		hideGem()
		if S.selectedKind ~= nil then
			S.selectedKind, S.selectedValue = nil, nil
			S.refreshDetail()
			if S.paintBagSelection then
				S.paintBagSelection()
			end
		end
	end

	-- 바깥 누름 = 둘 다 닫힘(누른 곳이 칸이면 그 칸의 선택이 먼저 바뀌어 닫지 않는다 · 확인 창 · 필터 판(z ≥ 20) · 다른 창 위 누름은 무시)
	local function inside(obj, root)
		return obj == root or obj:IsDescendantOf(root)
	end
	-- 누르기 시작 때의 선택 번호를 기억 → 손 뗀 뒤 그대로면(칸 누름이 선택을 안 바꿈) 닫음. 칸 Activated와 InputEnded 순서는 정해져 있지 않다.
	local pressSerial = nil
	UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			pressSerial = serial
			if gui.Enabled then -- 기준 칸 = 창 안에서 실제로 누른 버튼(보석 탭 칸 등 · 가방 · 착용 칸은 Activated에서 다시 정함)
				for _, o in ipairs(player.PlayerGui:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y)) do
					if o:IsA("GuiButton") and o:IsDescendantOf(R.win) then
						S.pinAnchor = o
						break
					elseif inside(o, detail) or inside(o, gemPop) then
						break
					end
				end
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local before = pressSerial
		pressSerial = nil
		if not (before and detail.Visible and gui.Enabled and R.win.Visible) then
			return
		end
		local objs = player.PlayerGui:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y)
		local top = objs[1]
		if top and not top:IsDescendantOf(gui) then
			return -- 다른 창 위
		end
		for _, o in ipairs(objs) do
			if inside(o, detail) or inside(o, gemPop) then
				return
			end
			if o:IsDescendantOf(gui) and o.Visible and o.ZIndex >= 20 then
				return -- 확인 창 · 필터 판 · 비교
			end
		end
		task.delay(0.05, function()
			if serial == before and detail.Visible then
				PinDetail._close()
			end
		end)
	end)
	local function onShownChanged()
		if not (gui.Enabled and R.win.Visible) then
			PinDetail._close() -- 가방을 닫으면 고정도 풀림(다시 열면 빈 상태 - 기준 칸 없이 뜨지 않게)
			detail.Visible = false
			line.Visible, lineDot.Visible = false, false
		elseif R.layout and pin.shown() then
			S.refreshDetail()
		end
	end
	gui:GetPropertyChangedSignal("Enabled"):Connect(onShownChanged)
	R.win:GetPropertyChangedSignal("Visible"):Connect(onShownChanged)

	return pin
end

return PinDetail
