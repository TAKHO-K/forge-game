-- UI-1 7단계 F 자동 창(08 v5-auto-boss §1 ~ 4 · v6-auto-boss-v2 pc_01 · pc_02 · ph_01 · ph_02): 7일 출석 + 시즌 출석판 = 창 1개 · 탭 2.
--   받을 것 있는 탭부터 · 탭마다 빨간 점 · 버튼 = 두 탭 모두 [오늘 모두 받기](숫자 = 두 탭 + 접속 보상 합) · 시즌판 32칸 한 화면(스크롤 없음) · 받음 = 칸 오른쪽 아래 작은 체크 배지.
--   자동 창 규칙: 한 번에 하나 · 마을 2초 뒤(받을 것 있을 때만) · 큰 창이 열려 있으면 · 보스전 중(BossEncounterId)이면 기다림 · 닫히고 1초 뒤 선물함(있을 때만) · 닫으면 그날 다시 자동으로 안 뜸.
--   받기 = 옛 창과 같은 QuestRequest("claim", login / attendance / board / boardBonus) · 연출 = 옛 받기 연출(AttendanceClaimFx - 재화 칸으로 날아감) 재사용 · 내일 칸 남은 시간 꼬리표는 쓰지 않음(카운트다운 없음).
--   스위치 = UiV2Flags.auto(끄면 옛 Attendance · SeasonBoard 창 그대로). 좌표 · 색 · 아이콘 = UiLayoutData.auto.v6.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QuestData = require(ReplicatedStorage.Shared.data.QuestData)
local HELP = require(ReplicatedStorage.Shared.data.UiV2Flags).help -- UI-1b 1절 3: 안내 줄 = [?]
local SeasonBoardData = require(ReplicatedStorage.Shared.data.SeasonBoardData)
local TitleData = require(ReplicatedStorage.Shared.data.TitleData)
local CosmeticSlotData = require(ReplicatedStorage.Shared.data.CosmeticSlotData)
local HudPlace = require(ReplicatedStorage.Shared.HudPlace)
local UiModel = require(ReplicatedStorage.Shared.UiModel)
local Text = require(ReplicatedStorage.Shared.Text)
local L = require(ReplicatedStorage.Shared.data.UiLayoutData).auto.v6
local ArtImage = require(script.Parent.Parent.ui.ArtImage)
local RewardIcons = require(script.Parent.Parent.ui.RewardIcons)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local UiKit = require(script.Parent.Parent.ui.v2.UiKit)
local UIManager = require(script.Parent.Parent.UIManager)
local ClaimFx = require(script.Parent.Parent.ui.AttendanceClaimFx)

local AttendanceV2 = {}
AttendanceV2.id = "attendanceV2"

local player = Players.LocalPlayer
local C = L.colors
local requestRemote = ReplicatedStorage:WaitForChild("QuestRequest")
local updateRemote = ReplicatedStorage:WaitForChild("QuestUpdate")

local view = nil
local built = nil -- { gui, root, win, body, phone, tab, cells = { week = {}, season = {} }, button, ... }
local autoDay = nil -- 자동으로 연(또는 닫힌) 날(UTC 날짜) - 그날은 다시 자동으로 안 뜸
local pendingGifts = nil
local claiming = false

local function hex(h)
	return Color3.fromHex(h)
end
local function utcDay()
	return os.time() // 86400
end
local function px(n)
	return math.floor(n * UiModel.textMul(UiKit.textStep(), UiKit.platformTextName()) + 0.5)
end

local function label(parent, text, size, color, font, align)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = UiKit.font(font or "koreanBold")
	l.TextSize = size
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.Text = text or ""
	l.Parent = parent
	return l
end
local function corner(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
end
local function stroke(inst, color, t)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = t
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst
	return s
end

-- 받을 것 목록(요청 순서): 접속 보상 → 7일 칸(받을 수 있는 날 전부) → 시즌판 오늘 칸 / 다 받은 뒤 하루 토큰
local function claimList(v)
	local list = {}
	if not v then
		return list
	end
	if v.loginReady then
		table.insert(list, { "login" })
	end
	local att = v.attendance
	if att then
		for _, e in ipairs(att.rewards or QuestData.attendance) do
			if e.day <= (att.count or 0) and att.claimed[tostring(e.day)] ~= true then
				table.insert(list, { "attendance", tostring(e.day), week = true })
			end
		end
	end
	local b = v.board
	if b and b.todayKind == "cell" then
		table.insert(list, { "board", tostring(b.todayCell), season = true })
	elseif b and b.todayKind == "bonus" then
		table.insert(list, { "boardBonus", season = true })
	end
	return list
end
local function weekHas(v)
	for _, c in ipairs(claimList(v)) do
		if c.week or c[1] == "login" then
			return true
		end
	end
	return false
end
local function seasonHas(v)
	return v and v.board and v.board.todayKind ~= nil
end

-- 보상 표 → { { key, icon, qty } } (gold = 몇 마리분 → 실제 골드 글자 - 서버 지급과 같은 식)
local function rewardParts(reward)
	local out = {}
	for _, key in ipairs(L.rewardOrder) do
		local v = reward[key]
		if v then
			local qty
			if key == "gold" then
				qty = "×" .. RewardIcons.goldText(v)
			elseif key == "title" or key == "cosmeticItem" then
				qty = nil
			else
				qty = "×" .. tostring(v)
			end
			table.insert(out, { key = key, icon = L.rewardIcons[key], qty = qty, value = v })
		end
	end
	return out
end
local function titleName(id)
	for _, t in pairs(TitleData) do
		if type(t) == "table" and type(t[id]) == "table" and t[id].name then
			return Text.name(t[id].name)
		end
	end
	return Text.get("ui1.att.title16")
end
local function cosmeticName(id)
	for _, item in ipairs(CosmeticSlotData.items or {}) do
		if item.id == id then
			return Text.name(item.name)
		end
	end
	return id
end

local function icon(parent, path, size)
	local i = Instance.new("ImageLabel")
	i.BackgroundTransparency = 1
	i.Image = ArtImage.get(path) or ""
	i.Size = UDim2.fromOffset(size, size)
	i.Parent = parent
	return i
end

-- 받음 배지(칸 오른쪽 아래 · PC 28 · 폰 20) - 그림 · 수량은 어둡게만(가리지 않음)
local function badge(cell, P)
	local b = icon(cell, L.check, P.badge)
	b.Name = "ClaimedBadge"
	b.AnchorPoint = Vector2.new(1, 1)
	b.Position = UDim2.new(1, -4, 1, -4)
	b.ZIndex = 4
end

local function rewardStack(cell, parts, size, phone, vertical)
	local holder = Instance.new("Frame")
	holder.Name = "Rewards"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = cell
	local list = Instance.new("UIListLayout")
	list.FillDirection = vertical and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, vertical and 10 or 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = holder
	for i, p in ipairs(parts) do
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.AutomaticSize = Enum.AutomaticSize.X
		row.Size = UDim2.fromOffset(0, size)
		row.LayoutOrder = i
		row.Parent = holder
		local rl = Instance.new("UIListLayout")
		rl.FillDirection = Enum.FillDirection.Horizontal
		rl.VerticalAlignment = Enum.VerticalAlignment.Center
		rl.Padding = UDim.new(0, 4)
		rl.Parent = row
		local ic = icon(row, p.icon, size)
		ic.Name = "Icon_" .. p.key
		local text = p.qty
		if p.key == "title" then
			text = titleName(p.value)
		elseif p.key == "cosmeticItem" then
			text = cosmeticName(p.value)
		end
		if text then
			local q = label(row, text, phone and 12 or (size >= 40 and 18 or 15), Color3.new(1, 1, 1), (p.qty and "number") or "koreanBold") -- 칸 안 수량 = 고정 크기(C 규칙)
			q.AutomaticSize = Enum.AutomaticSize.X
			q.Size = UDim2.fromOffset(0, size)
		end
	end
	return holder
end

local function dimRewards(cell)
	for _, d in ipairs(cell:GetDescendants()) do
		if d:IsA("ImageLabel") and d.Name ~= "ClaimedBadge" then
			d.ImageTransparency = 0.55
		elseif d:IsA("TextLabel") then
			d.TextTransparency = 0.5
		end
	end
end

local function todayPill(cell, phone)
	local p = label(cell, Text.get("ui1.att.today"), phone and 10 or 13, hex("2A1E00"), "koreanBold", Enum.TextXAlignment.Center)
	p.Name = "TodayPill"
	p.BackgroundTransparency = 0
	p.BackgroundColor3 = hex(C.today)
	p.AnchorPoint = Vector2.new(0.5, 0.5)
	p.Position = UDim2.new(0.5, 0, 0, 0)
	p.Size = UDim2.fromOffset(phone and 36 or 48, phone and 16 or 22)
	p.ZIndex = 5
	corner(p, 8)
end

local function renderWeek(body, P, phone)
	local att = view and view.attendance
	local cells = {}
	if not att then
		return cells
	end
	if not phone and not HELP then -- UI-1b 1절 3: 안내 줄 = 제목 옆 [?] 안
		local note = label(body, Text.get("ui1.att.note"), px(16), Color3.fromRGB(200, 204, 220))
		note.Position = UDim2.fromOffset(P.pad, P.note.y)
		note.Size = UDim2.new(1, -P.pad * 2, 0, P.note.h)
	end
	local W = P.weekCell
	for i, e in ipairs(att.rewards or QuestData.attendance) do
		local key = tostring(e.day)
		local claimed = att.claimed[key] == true
		local ready = e.day <= (att.count or 0) and not claimed
		local today = e.day == att.count
		local cell = Instance.new("Frame")
		cell.Name = "Day" .. key
		cell.BackgroundColor3 = claimed and hex(C.cellClaimed) or hex(C.cell)
		cell.Position = UDim2.fromOffset(P.pad + (i - 1) * (W.w + W.gap), W.y)
		cell.Size = UDim2.fromOffset(W.w, W.h)
		cell.Parent = body
		corner(cell, phone and 10 or 12)
		stroke(cell, (ready or (today and not claimed)) and hex(C.today) or (e.day == 7 and hex(C.day7) or hex(C.stroke)), (ready or (today and not claimed)) and 3 or 2)
		local day = label(cell, Text.get("ui1.att.day", { n = key }), phone and 13 or 18, Color3.new(1, 1, 1), "koreanBold", Enum.TextXAlignment.Center)
		day.Position = UDim2.fromOffset(0, phone and 6 or 12)
		day.Size = UDim2.new(1, 0, 0, phone and 16 or 22)
		local stack = rewardStack(cell, rewardParts(e.reward), W.icon, phone, true)
		stack.Position = UDim2.fromOffset(0, phone and 8 or 16)
		if today and not claimed then
			todayPill(cell, phone)
		end
		if claimed then
			dimRewards(cell)
			day.TextTransparency = 0.5
			badge(cell, P)
		end
		cells[e.day] = cell
	end
	return cells
end

local function renderSeason(body, P, phone)
	local b = view and view.board
	local cells = {}
	if not b then
		return cells
	end
	local total = #SeasonBoardData.cells
	local got = 0
	for _, yes in pairs(b.claimed or {}) do
		got += yes and 1 or 0
	end
	if not phone then -- 위 줄: 시즌 n · 진행 막대 · n / 32 · 안내
		local T = P.seasonTop
		local head = label(body, Text.get("ui1.att.seasonHead", { s = tostring(b.season or 1) }), px(18), Color3.new(1, 1, 1))
		head.Position = UDim2.fromOffset(P.pad, T.y)
		head.Size = UDim2.fromOffset(100, T.h)
		local bar = Instance.new("Frame")
		bar.BackgroundColor3 = hex(C.tabOff)
		bar.Position = UDim2.fromOffset(P.pad + 108, T.y + T.h / 2 - 4)
		bar.Size = UDim2.fromOffset(310, 8)
		bar.Parent = body
		corner(bar, 4)
		local fill = Instance.new("Frame")
		fill.BackgroundColor3 = hex(C.tabOn)
		fill.Size = UDim2.fromScale(got / total, 1)
		fill.Parent = bar
		corner(fill, 4)
		local cnt = label(body, Text.get("ui1.att.seasonCount", { n = tostring(got), total = tostring(total) }), px(16), Color3.new(1, 1, 1), "number")
		cnt.Position = UDim2.fromOffset(P.pad + 430, T.y)
		cnt.Size = UDim2.fromOffset(70, T.h)
		local note = label(body, Text.get("ui1.att.seasonNote", { n = tostring(SeasonBoardData.after.sparkleShard or 1) }), px(14), Color3.fromRGB(150, 156, 180))
		note.Visible = not HELP -- UI-1b 1절 3: = [?] 안
		note.Position = UDim2.fromOffset(P.pad + 500, T.y)
		note.Size = UDim2.new(1, -(P.pad * 2 + 500), 0, T.h)
		note.TextTruncate = Enum.TextTruncate.AtEnd
	end
	local S = P.seasonCell
	for n, reward in ipairs(SeasonBoardData.cells) do
		local key = tostring(n)
		local claimed = b.claimed[key] == true
		local today = b.todayKind == "cell" and b.todayCell == n
		local col, row = (n - 1) % 8, (n - 1) // 8
		local cell = Instance.new("Frame")
		cell.Name = "Cell" .. key
		cell.BackgroundColor3 = claimed and hex(C.cellClaimed) or hex(C.cell)
		cell.Position = UDim2.fromOffset(P.pad + col * (S.w + S.gapX), S.y + row * (S.h + S.gapY))
		cell.Size = UDim2.fromOffset(S.w, S.h)
		cell.Parent = body
		corner(cell, phone and 8 or 10)
		local special = n == 16 or n == total
		stroke(cell, today and hex(C.today) or (special and hex(C.day7) or hex(C.stroke)), today and 3 or 2)
		local num = label(cell, key, phone and 10 or 13, Color3.fromRGB(200, 204, 220), "number")
		num.Position = UDim2.fromOffset(phone and 5 or 10, phone and 2 or 8)
		num.Size = UDim2.fromOffset(24, phone and 12 or 16)
		local stack = rewardStack(cell, rewardParts(reward), S.icon, phone, false)
		if phone then -- 폰 88 × 40: 번호(왼쪽) · 그림 + 수량 · 배지(오른쪽 20) 자리를 나눔(겹침 0)
			stack.Position = UDim2.fromOffset(14, 0)
			stack.Size = UDim2.new(1, -(14 + P.badge + 6), 1, 0)
		else
			stack.Position = UDim2.fromOffset(0, 8)
		end
		if today then
			if not phone then
				todayPill(cell, phone)
			end
		end
		if claimed then
			dimRewards(cell)
			num.TextTransparency = 0.5
			badge(cell, P)
		end
		cells[n] = cell
	end
	return cells
end

local function tomorrowText()
	return Text.get("ui1.att.tomorrow", { h = tostring((L.resetHourUtc + L.kstOffset) % 24) })
end

local function summaryText()
	local parts = {}
	local list = claimList(view)
	local weekDay, seasonCell, login = nil, nil, false
	for _, c in ipairs(list) do
		if c[1] == "attendance" then
			weekDay = c[2]
		elseif c[1] == "board" then
			seasonCell = c[2]
		elseif c[1] == "login" then
			login = true
		end
	end
	if login then
		table.insert(parts, Text.get("ui1.att.sumLogin"))
	end
	if weekDay then
		table.insert(parts, Text.get("ui1.att.sumWeek", { d = weekDay }))
	end
	if seasonCell then
		table.insert(parts, Text.get("ui1.att.sumSeason", { n = seasonCell }))
	elseif view and view.board and view.board.todayKind == "bonus" then
		table.insert(parts, Text.get("ui1.att.bonus", { n = tostring(SeasonBoardData.after.sparkleShard or 1) }))
	end
	if #parts == 0 then
		return Text.get("ui1.att.allDone")
	end
	return #parts == 1 and Text.get("ui1.att.sumOne", { a = parts[1] }) or Text.get("ui1.att.sumJoin", { a = table.concat(parts, " + ", 1, #parts - 1), b = parts[#parts] })
end

local function build()
	Theme.recompute()
	local phone = Theme.isMobile
	local base = phone and HudPlace.base.phone or HudPlace.base.pc
	local gui = Instance.new("ScreenGui")
	gui.Name = "AttendanceV2Gui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local dim = Instance.new("TextButton") -- 모달 딤(뒤 입력 막기)
	dim.Name = "Dim"
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.55
	dim.Size = UDim2.fromScale(1, 1)
	dim.Parent = gui
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(base.w, base.h)
	root.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = root
	local function fit()
		local v = gui.AbsoluteSize
		if v.X > 1 then
			scale.Scale = phone and math.min(v.X / base.w, v.Y / base.h) or math.min(v.X / base.w, v.Y / base.h)
		end
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	built = { gui = gui, root = root, phone = phone, tab = "week", cells = { week = {}, season = {} } }
	UIManager.register(AttendanceV2.id, {
		kind = "window",
		screenGui = gui,
		hasCloseButton = true,
		onOpen = function()
			gui.Enabled = true
			if not require(game:GetService("ReplicatedStorage").Shared.data.UiV2Flags).layers then gui.DisplayOrder = math.max(gui.DisplayOrder, L.displayOrder) end -- UI-1b: 층 표(창 = HUD 메뉴 위)면 따로 안 올림(나중에 연 창이 위) -- 폰 창(y 62)이 HUD 메뉴 줄(HudMenuV2 150) 위에 오게
			autoDay = utcDay()
			AttendanceV2.render()
		end,
		onClose = function()
			gui.Enabled = false
			AttendanceV2.flushGifts(L.giftDelay) -- 닫히고 1초 뒤 선물함
		end,
	})
end

function AttendanceV2.render()
	local B = built
	if not B or not B.gui.Enabled then
		return
	end
	if B.win then
		B.win:Destroy()
	end
	local phone = B.phone
	local P = phone and L.phone or L.pc
	if not (view and view.attendance) then
		B.tab = "season"
	end
	local season = B.tab == "season"
	local win = Instance.new("Frame")
	win.Name = "Window"
	win.BackgroundColor3 = hex(C.window)
	if phone then
		win.Position = UDim2.fromOffset(P.x, P.y)
		win.Size = UDim2.fromOffset(P.w, P.h)
	else
		local spec = season and P.season or P.week
		win.Position = UDim2.fromOffset(P.x, spec.y)
		win.Size = UDim2.fromOffset(P.w, spec.h)
	end
	win.Parent = B.root
	corner(win, phone and 14 or 18)
	stroke(win, hex(C.stroke), 3)
	B.win = win
	-- 머리: 아이콘 · "출석" · (PC) 오늘 받을 것 n개 · 닫기 · 노랑 줄
	local headIcon = icon(win, L.headIcon, phone and 30 or 40)
	headIcon.AnchorPoint = Vector2.new(0, 0.5)
	headIcon.Position = UDim2.new(0, P.pad + 4, 0, P.head / 2)
	local title = label(win, Text.get("ui1.att.title"), px(phone and 18 or 26), Color3.new(1, 1, 1), "korean")
	title.Position = UDim2.fromOffset(P.pad + (phone and 40 or 54), 0)
	title.Size = UDim2.fromOffset(phone and 52 or 70, P.head)
	local helpW = 0
	if HELP then -- UI-1b 1절 3: 제목 옆 [?] = 7일 · 시즌판 · 초기화 안내
		local HB = require(script.Parent.Parent.ui.v2.HelpButton)
		HB.besideLabel(title, "attendance", { rows = function()
			return { { Text.get("ui1b.help.row.week"), Text.get("ui1.att.note") }, { Text.get("ui1b.help.row.season"), Text.get("ui1.att.seasonNote", { n = tostring(SeasonBoardData.after.sparkleShard or 1) }) } }
		end })
		helpW = require(ReplicatedStorage.Shared.data.UiLayoutData).helpButton.pcSize + 14
	end
	local n = #claimList(view)
	if not phone then
		local sub = label(win, n > 0 and Text.get("ui1.att.sub", { n = tostring(n) }) or "", px(16), Color3.fromRGB(190, 196, 214))
		sub.Position = UDim2.fromOffset(P.pad + 130 + helpW, 0)
		sub.Size = UDim2.fromOffset(300, P.head)
	end
	local line = Instance.new("Frame")
	line.BorderSizePixel = 0
	line.BackgroundColor3 = hex(C.line)
	line.Position = UDim2.fromOffset(0, P.head)
	line.Size = UDim2.new(1, 0, 0, P.line)
	line.Parent = win
	UiKit.closeButton({ parent = win, name = "Close", rect = { P.w - P.close - (phone and 6 or 10), (P.head - P.close) / 2, P.close, P.close }, onActivated = function()
		UIManager.close(AttendanceV2.id)
	end })
	-- 탭 2(PC = 머리 아래 · 폰 = 머리 안)
	local tabs = { { id = "week", text = phone and "ui1.att.tabWeekShort" or "ui1.att.tabWeek", has = weekHas(view), show = view and view.attendance ~= nil },
		{ id = "season", text = phone and "ui1.att.tabSeasonShort" or "ui1.att.tabSeason", has = seasonHas(view), show = view and view.board ~= nil } }
	local tx = phone and (P.pad + 100) or P.pad
	for _, t in ipairs(tabs) do
		if t.show then
			local on = B.tab == t.id
			local b = Instance.new("TextButton")
			b.Name = "Tab_" .. t.id
			b.AutoButtonColor = false
			b.Text = Text.get(t.text)
			b.Font = UiKit.font("korean")
			b.TextSize = px(phone and 14 or 18)
			b.TextColor3 = on and hex("2A1E00") or Color3.new(1, 1, 1)
			b.BackgroundColor3 = on and hex(C.tabOn) or hex(C.tabOff)
			b.Position = UDim2.fromOffset(tx, phone and (P.head - P.tabH) / 2 or P.tabY)
			b.Size = UDim2.fromOffset(P.tabW + (phone and 0 or 0), P.tabH)
			b.AutomaticSize = Enum.AutomaticSize.X
			b.Parent = win
			corner(b, 10)
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
			pad.Parent = b
			if t.has then
				local dot = Instance.new("Frame")
				dot.Name = "Dot"
				dot.BackgroundColor3 = hex(C.dot)
				dot.AnchorPoint = Vector2.new(0.5, 0.5)
				dot.Position = UDim2.new(1, 12, 0, 0)
				dot.Size = UDim2.fromOffset(P.dot, P.dot)
				dot.Parent = b
				corner(dot, P.dot / 2)
				stroke(dot, Color3.new(1, 1, 1), 2)
			end
			b.Activated:Connect(function()
				if B.tab ~= t.id then
					B.tab = t.id
					AttendanceV2.render()
				end
			end)
			tx += P.tabW + 12
		end
	end
	-- 본문(칸)
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Size = UDim2.fromScale(1, 1)
	body.Parent = win
	B.cells.week, B.cells.season = {}, {}
	if season then
		B.cells.season = renderSeason(body, P, phone)
	else
		B.cells.week = renderWeek(body, P, phone)
	end
	-- 아래 줄: 왼쪽 안내(줄어듦) + 오른쪽 버튼(고정 · 겹침 0)
	local F, bw, bh = P.foot, P.button[1], P.button[2]
	local foot = Instance.new("Frame")
	foot.Name = "Foot"
	foot.BackgroundTransparency = 1
	foot.AnchorPoint = Vector2.new(0, 1)
	foot.Position = UDim2.new(0, P.pad, 1, -F.bottom)
	foot.Size = UDim2.new(1, -P.pad * 2, 0, F.h)
	foot.Parent = win
	if not phone then
		local sep = Instance.new("Frame")
		sep.BorderSizePixel = 0
		sep.BackgroundColor3 = hex(C.stroke)
		sep.Position = UDim2.fromOffset(0, -12)
		sep.Size = UDim2.new(1, 0, 0, 1)
		sep.Parent = foot
	end
	local textW = P.w - P.pad * 2 - bw - 16
	local sum = label(foot, summaryText(), px(phone and 13 or 17), Color3.new(1, 1, 1)) -- 왼쪽 글자 = 남은 폭 안에서 줄어듦(끝 말줄임 · TextScaled는 Studio에서 칸보다 작게 그려 안 씀)
	sum.Size = UDim2.fromOffset(textW, F.h * 0.5)
	sum.TextTruncate = Enum.TextTruncate.AtEnd
	local tm = label(foot, tomorrowText(), px(phone and 11 or 14), Color3.fromRGB(150, 156, 180))
	tm.Position = UDim2.fromOffset(0, F.h * 0.5)
	tm.Size = UDim2.fromOffset(textW, F.h * 0.5)
	tm.TextTruncate = Enum.TextTruncate.AtEnd
	local btn = UiKit.button({ parent = foot, kind = "primary", name = "ClaimAll", text = Text.get(n > 0 and "ui1.att.claimAll" or "ui1.att.allDone"), align = Enum.TextXAlignment.Center,
		rect = { P.w - P.pad * 2 - bw, (F.h - bh) / 2, bw, bh }, onActivated = function()
			AttendanceV2.claimAll()
		end })
	btn.setEnabled(n > 0 and not claiming)
	if n > 0 then
		local cnt = label(btn.root, tostring(n), phone and 12 or 15, Color3.new(1, 1, 1), "number", Enum.TextXAlignment.Center)
		cnt.Name = "Count"
		cnt.BackgroundTransparency = 0
		cnt.BackgroundColor3 = hex(C.dot)
		cnt.AnchorPoint = Vector2.new(1, 0.5)
		cnt.Position = UDim2.new(1, -14, 0.5, -2)
		cnt.Size = UDim2.fromOffset(phone and 22 or 28, phone and 22 or 28)
		cnt.ZIndex = 8
		corner(cnt, 14)
		stroke(cnt, Color3.new(1, 1, 1), 2)
	end
	B.button = btn
end

-- [오늘 모두 받기]: 받을 것을 차례로 요청(서버 동작별 0.2초 제한 → 0.3초 간격) · 결과마다 받기 연출
function AttendanceV2.claimAll()
	if claiming then
		return
	end
	local list = claimList(view)
	if #list == 0 then
		return
	end
	claiming = true
	if built and built.button then
		built.button.setEnabled(false)
	end
	task.spawn(function()
		for i, c in ipairs(list) do
			if i > 1 then
				task.wait(0.3)
			end
			requestRemote:FireServer("claim", c[1], c[2])
		end
		task.wait(1.2)
		claiming = false
		AttendanceV2.render()
		if #claimList(view) == 0 then -- 다 받음 = 잠깐 보여 준 뒤 닫힘(닫히고 1초 뒤 선물함)
			task.wait(0.8)
			if #claimList(view) == 0 and UIManager.isOpen(AttendanceV2.id) then
				UIManager.close(AttendanceV2.id)
			end
		end
	end)
end

local function onClaimResult(kind, id, granted)
	if not built or not UIManager.isOpen(AttendanceV2.id) then
		return
	end
	if kind ~= "login" and kind ~= "attendance" and kind ~= "board" and kind ~= "boardBonus" then
		return
	end
	local cell = nil
	if kind == "attendance" then
		cell = built.cells.week[tonumber(id) or 0]
	elseif kind == "board" then
		cell = built.cells.season[tonumber(id) or 0]
	end
	cell = cell or (built.button and built.button.root)
	ClaimFx.play({ cell = cell, granted = granted, onDone = function()
		AttendanceV2.render()
		if #claimList(view) == 0 and not claiming then
			task.delay(0.6, function()
				if #claimList(view) == 0 then
					UIManager.close(AttendanceV2.id)
				end
			end)
		end
	end })
end

local function canAutoNow()
	return #UIManager.getStack() == 0 and player:GetAttribute("BossEncounterId") == nil
end

-- 자동 창: 마을 2초 뒤 · 받을 것 있을 때만 · 한 번에 하나(큰 창 · 보스전이면 기다림) · 그날 한 번
local autoWaiting = false
local function tryAuto()
	if autoWaiting or autoDay == utcDay() or #claimList(view) == 0 or player:GetAttribute("TutorialCompleted") ~= true then
		return
	end
	autoWaiting = true
	task.delay(L.openDelay, function()
		while autoDay ~= utcDay() and #claimList(view) > 0 do
			if canAutoNow() then
				AttendanceV2.open(nil, true)
				break
			end
			task.wait(1)
		end
		autoWaiting = false
		AttendanceV2.flushGifts(L.giftDelay) -- 출석이 안 뜬 날 = 선물함만(있을 때)
	end)
end

-- 선물함(서버 GiftPopup): 출석 창이 끝날 때까지 기다렸다 1초 뒤 · 다른 창 · 보스전이면 기다림
function AttendanceV2.queueGift(gifts)
	pendingGifts = gifts
	if not autoWaiting and not UIManager.isOpen(AttendanceV2.id) then
		AttendanceV2.flushGifts(L.giftDelay)
	end
end
local flushing = false
function AttendanceV2.flushGifts(delay)
	if not pendingGifts or flushing then
		return
	end
	flushing = true
	task.delay(delay or 0, function()
		while pendingGifts and (autoWaiting or not canAutoNow()) do
			task.wait(1)
		end
		local g = pendingGifts
		pendingGifts = nil
		flushing = false
		if g and player.Parent then
			require(script.Parent.Shop.GiftPopup).show(g)
		end
	end)
end

-- tab = "week" | "season" | nil(받을 것 있는 탭부터)
function AttendanceV2.open(tab, auto)
	if not built then
		build()
	end
	built.tab = tab or ((weekHas(view) or not seasonHas(view)) and (view and view.attendance and "week" or "season") or "season")
	if auto and not canAutoNow() then
		return false
	end
	if UIManager.isOpen(AttendanceV2.id) then
		AttendanceV2.render()
		return true
	end
	return UIManager.switchTo(AttendanceV2.id) ~= false
end

function AttendanceV2.currentView()
	return view
end

function AttendanceV2.init()
	ReplicatedStorage:WaitForChild("QuestClaimResult").OnClientEvent:Connect(onClaimResult)
	updateRemote.OnClientEvent:Connect(function(v)
		view = v
		if built and UIManager.isOpen(AttendanceV2.id) and not ClaimFx.isPlaying() and not claiming then
			AttendanceV2.render()
		end
		tryAuto()
	end)
	player:GetAttributeChangedSignal("TutorialCompleted"):Connect(tryAuto)
end

return AttendanceV2
