-- UI-1c 3단계 명예의 전당 창(I v1 §1 · pc_01 · ph_01) - H 순위 창 대체(스위치 UiV2Flags.hall · 끔 = panels/Leaderboard 옛 창).
--   같은 창 id "leaderboard"(L 키 · 더보기 [순위] · 마을 명예의 전당 [E] · 게시판 [E]가 모두 Leaderboard.open → 여기).
--   탭 4(사용자 결정 10-10): 전체 = 역대 최고 스테이지(all) · 직업별 = 같은 기준 직업마다(allclass:<직업>) · 파티 = 이번 시즌 파티로 처치한 보스 수(partyKills) · 시즌 = 이번 시즌 최고 스테이지(personal).
--   단상 1 · 2 · 3(HeadShot · 이름 · 값) + 4등부터 목록(목록만 스크롤) + 내 줄 고정(목록에 내가 보여도 유지) · 시즌 알약 = 끝 날짜만(남은 시간 · 카운트다운 · 변동 화살표 · "n위 차이" 없음).
--   직업 열 = 순위 줄에 직업이 있을 때만(직업별 탭) · 값 열 이름 = 탭 기준(파티 = "보스 처치(파티)" · 단상 = "처치 n").
--   데이터 = 서버 캐시(Leaderboard.lua - LeaderboardRequest "board" · "me" · "card")만. 단상 그리기 = HallOfFameV1.podium(마을 게시판 겉면도 같은 함수).
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local HudPlace = require(ReplicatedStorage.Shared.HudPlace)
local Text = require(ReplicatedStorage.Shared.Text)
local UiModel = require(ReplicatedStorage.Shared.UiModel)
local Tokens = require(ReplicatedStorage.Shared.data.UiTokens)
local Flags = require(ReplicatedStorage.Shared.data.UiV2Flags)
local L = require(ReplicatedStorage.Shared.data.UiLayoutData).hall
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local Toast = require(script.Parent.Parent.ui.kit.Toast)
local UiKit = require(script.Parent.Parent.ui.v2.UiKit)
local UiParts = require(script.Parent.Parent.ui.v2.UiParts)
local ArtImage = require(script.Parent.Parent.ui.ArtImage)
local UIManager = require(script.Parent.Parent.UIManager)

local HallOfFameV1 = {}
HallOfFameV1.id = "leaderboard"

local player = Players.LocalPlayer
local request = ReplicatedStorage:WaitForChild("LeaderboardRequest")
local C = L.colors
local ME_CACHE_SECONDS = 60

local TABS = {
	{ id = "all", textKey = "ui.rank.tab.all" },
	{ id = "class", textKey = "ui.rank.tab.class" },
	{ id = "party", textKey = "ui.rank.tab.party" },
	{ id = "season", textKey = "ui.rank.tab.season" },
}

local built = nil
local state = { tab = "all", classId = nil, boards = {}, me = {}, token = 0, classMenu = false }

local function hex(h)
	return Color3.fromHex(h)
end
-- spec 글자 = 새 보통 기준 → 설정 3단(1.0 · 1.15 · 1.3)만 곱함(textBase는 다시 안 곱함)
function HallOfFameV1.px(n)
	local base = Flags.text and Tokens.textBase or 1
	return math.floor(n * UiModel.textMul(UiKit.textStep(), UiKit.platformTextName()) / base + 0.5)
end
local px = HallOfFameV1.px
local function corner(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = r == "pill" and UDim.new(1, 0) or UDim.new(0, r)
	c.Parent = inst
	return c
end
local function stroke(inst, color, thick, transparency)
	local s = Instance.new("UIStroke")
	s.Color = typeof(color) == "Color3" and color or hex(color)
	s.Thickness = thick
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst
	return s
end
local function frame(parent, rect, color, name)
	local f = Instance.new("Frame")
	f.Name = name or "Frame"
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color and hex(color) or Color3.new()
	f.BackgroundTransparency = color and 0 or 1
	f.Position = UDim2.fromOffset(rect[1], rect[2])
	f.Size = UDim2.fromOffset(rect[3], rect[4])
	f.Parent = parent
	return f
end
local function label(parent, text, size, color, props)
	props = props or {}
	local l = Instance.new("TextLabel")
	l.Name = props.name or "Label"
	l.BackgroundTransparency = 1
	l.Font = UiKit.font(props.font or "koreanBold")
	l.TextSize = size
	l.TextColor3 = typeof(color) == "Color3" and color or hex(color or "FFFFFF")
	l.TextXAlignment = props.align or Enum.TextXAlignment.Left
	l.TextYAlignment = props.alignY or Enum.TextYAlignment.Center
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.RichText = props.rich == true
	l.Text = text or ""
	if props.rect then
		l.Position = UDim2.fromOffset(props.rect[1], props.rect[2])
		l.Size = UDim2.fromOffset(props.rect[3], props.rect[4])
	end
	l.Parent = parent
	return l
end
HallOfFameV1.label = label

-- 이름 · 직업 · 값 글
local function nameOf(names, id)
	if id == player.UserId then
		return player.DisplayName
	end
	return (names and names[tostring(id)]) or ("#" .. tostring(id))
end
local function className(classId)
	return classId and ClassData.classes[classId] and Text.get("class.name." .. classId) or nil
end
-- 값: 파티 탭(보스 처치 수) = count · 나머지 = 스테이지
local function valueOf(entry)
	if entry == nil then
		return ""
	end
	if entry.count ~= nil then
		return tostring(entry.count)
	end
	return entry.stage ~= nil and tostring(entry.stage) or ""
end
HallOfFameV1.valueOf = valueOf
function HallOfFameV1.podiumValue(entry)
	if entry and entry.count ~= nil then
		return Text.get("ui1c.hall.value.kills", { n = tostring(entry.count) })
	end
	return valueOf(entry)
end

-- 아바타 = HeadShot 썸네일(불러오는 중 · 실패 = 회색 원 + 이름 첫 글자) · 사람마다 한 번만 요청
local thumbs = {} -- [userId] = 그림 문자열 | false(실패) | "pending"
local waiting = {} -- [userId] = { ImageLabel }
function HallOfFameV1.avatar(parent, userId, name, sizePx, ringColor, ringW)
	local holder = Instance.new("Frame")
	holder.Name = "Avatar"
	holder.BackgroundColor3 = hex(C.faceBg)
	holder.Size = UDim2.fromOffset(sizePx, sizePx)
	holder.Parent = parent
	corner(holder, "pill")
	if ringColor then
		stroke(holder, ringColor, ringW or 3)
	end
	local initial = (name and name ~= "") and utf8.char(utf8.codepoint(name, 1, 1)) or "?"
	local first = label(holder, initial, math.floor(sizePx * 0.45), C.faceText, { name = "Initial", align = Enum.TextXAlignment.Center, font = "number" })
	first.Size = UDim2.fromScale(1, 1)
	first.TextTruncate = Enum.TextTruncate.None
	local img = Instance.new("ImageLabel")
	img.Name = "HeadShot"
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Visible = false
	img.Parent = holder
	corner(img, "pill")
	local function apply(content)
		if content then
			img.Image = content
			img.Visible = true
			first.Visible = false
		end
	end
	local id = tonumber(userId)
	if not id or id <= 0 then
		return holder
	end
	local known = thumbs[id]
	if type(known) == "string" and known ~= "pending" then
		apply(known)
	elseif known == nil or known == "pending" then
		waiting[id] = waiting[id] or {}
		table.insert(waiting[id], apply)
		if known == nil then
			thumbs[id] = "pending"
			task.spawn(function()
				local ok, content, ready = pcall(function()
					return Players:GetUserThumbnailAsync(id, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
				end)
				thumbs[id] = (ok and ready and content) or false
				for _, fn in ipairs(waiting[id] or {}) do
					fn(thumbs[id] or nil)
				end
				waiting[id] = nil
			end)
		end
	end
	return holder
end

-- 단상(창 · 게시판 공용): rect 판 안에 2 · 1 · 3 블록 + 아바타 + 왕관 · entries = 1 ~ 3등(없으면 회색 빈 자리)
--   P = { width, block, heights, avatar, crown, name, small, value, rank, rankT, avatarStroke } · textPx = 글자 함수(창 = px · 게시판 = 그대로)
function HallOfFameV1.podium(parent, rect, entries, names, P, textPx)
	textPx = textPx or px
	local panel = frame(parent, rect, "FFFFFF", "Podium") -- 색 = 그라데이션(바탕 흰색 × 그라데이션 색)
	panel.ClipsDescendants = true
	corner(panel, 12)
	local g = Instance.new("UIGradient") -- 가운데 위 빛(투명 그라데이션)
	g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, hex(C.panel)), ColorSequenceKeypoint.new(0.5, hex(C.panelLight)), ColorSequenceKeypoint.new(1, hex(C.panel)) })
	g.Parent = panel
	local beam = frame(panel, { math.floor(rect[3] / 2 - P.width / 6), 0, math.floor(P.width / 3), rect[4] }, "FFFFFF", "Beam")
	beam.BackgroundTransparency = 0.94
	local bg = Instance.new("UIGradient")
	bg.Rotation = 90
	bg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	bg.Parent = beam
	local colW = P.width / 3
	local x0 = (rect[3] - P.width) / 2
	local order = { 2, 1, 3 }
	local palette = { C.gold, C.silver, C.bronze }
	for col, rank in ipairs(order) do
		local e = entries[rank]
		local pal = e and palette[rank] or C.empty
		local bw = math.floor(colW * P.block)
		local bh = math.floor(rect[4] * P.heights[rank])
		local bx = math.floor(x0 + (col - 1) * colW + (colW - bw) / 2)
		local by = rect[4] - bh
		local block = frame(panel, { bx, by, bw, bh + 16 }, "FFFFFF", "Block" .. rank)
		corner(block, 14)
		local bgr = Instance.new("UIGradient")
		bgr.Rotation = 90
		bgr.Color = ColorSequence.new(hex(pal[1]), hex(pal[2]))
		bgr.Parent = block
		stroke(block, pal[2], 2, 0.3)
		local textCol = hex(pal[3])
		local id = e and (e.userId or (e.members and e.members[1]))
		local nm = e and nameOf(names, id) or ""
		label(block, nm, textPx(P.name), textCol, { name = "Name", align = Enum.TextXAlignment.Center, rect = { 4, math.floor(bh * 0.08), bw - 8, textPx(P.name) + 6 } })
		if e then
			local cls = className(e.classId)
			local line = (cls and ('<font size="%d">%s</font>  '):format(textPx(P.small), cls) or "") .. ("<b>%s</b>"):format(HallOfFameV1.podiumValue(e))
			label(block, line, textPx(P.value), textCol, { name = "Value", align = Enum.TextXAlignment.Center, rich = true, rect = { 4, math.floor(bh * 0.08) + textPx(P.name) + 8, bw - 8, textPx(P.value) + 6 } })
		end
		local num = label(block, tostring(rank), P.rank, textCol, { name = "RankNo", align = Enum.TextXAlignment.Center, font = "number", rect = { 0, bh - P.rank - 4, bw, P.rank + 4 } })
		num.TextTransparency = P.rankT
		-- 아바타(블록 위) · 1등 = 왕관
		local a = P.avatar[rank]
		local av = HallOfFameV1.avatar(panel, e and id or nil, nm, a, e and hex(pal[1]) or hex(C.empty[3]), P.avatarStroke)
		av.Position = UDim2.fromOffset(math.floor(bx + bw / 2 - a / 2), by - a - math.floor(a * 0.08))
		if not e then
			av:FindFirstChild("Initial").Text = ""
		end
		if rank == 1 and e then
			local crown = ArtImage.label(panel, "ui/v9/rank-crown", UDim2.fromOffset(P.crown, math.floor(P.crown * 75 / 96)), "♛")
			crown.Name = "Crown"
			crown.Position = UDim2.fromOffset(math.floor(bx + bw / 2 - P.crown / 2), by - a - math.floor(a * 0.08) - math.floor(P.crown * 0.7))
		end
	end
	return panel
end

local function boardIdOf(tab)
	if tab == "all" then
		return "all"
	elseif tab == "class" then
		return "allclass:" .. state.classId
	elseif tab == "party" then
		return "partyKills"
	end
	return "personal"
end

local function seasonText(season)
	if type(season) ~= "table" then
		return nil
	end
	if season.endsAt then
		local t = os.date("!*t", season.endsAt + 9 * 3600 - 1) -- 끝 날짜(한국 시간 · 끝 시각 직전 날)
		return Text.get("ui1c.hall.seasonUntil", { season = tostring(season.id), month = tostring(t.month), day = tostring(t.day) })
	end
	return Text.get("ui1c.hall.season", { season = tostring(season.id) })
end
HallOfFameV1.seasonText = seasonText

local render -- 앞 선언

local function fetch(boardId)
	state.token += 1
	local token = state.token
	task.spawn(function()
		local ok, r = pcall(function()
			return request:InvokeServer("board", boardId)
		end)
		if ok and type(r) == "table" and r.ok then
			state.boards[boardId] = r
		end
		if token == state.token and built and built.gui.Enabled then
			render()
		end
		-- 캐시 밖 내 줄 = "me" 1회(서버 10초 간격 · 창 60초 캐시)
		local board = state.boards[boardId]
		local cached = state.me[boardId]
		if board and board.mine == nil and (not cached or os.clock() - cached.at > ME_CACHE_SECONDS) then
			local ok2, me = pcall(function()
				return request:InvokeServer("me", boardId)
			end)
			if ok2 and type(me) == "table" and me.ok then
				state.me[boardId] = { result = me, at = os.clock() }
				if built and built.gui.Enabled and boardIdOf(state.tab) == boardId then
					render()
				end
			end
		end
	end)
end

local function openCard(boardId, key)
	task.spawn(function()
		local ok, result = pcall(function()
			return request:InvokeServer("card", boardId, key)
		end)
		if not ok or type(result) ~= "table" or not result.ok then
			Toast.push("TC", { text = Text.get(result and result.reason == "rate_limited" and "ui.rank.card.rateLimited" or "ui.rank.card.failed"), colorName = "textPrimary" })
			return
		end
		if type(result.card) ~= "table" or type(result.card.weapon) ~= "table" then
			Toast.push("TC", { text = Text.get("ui.rank.card.noGear"), colorName = "textPrimary" })
			return
		end
		if UIManager.isOpen(HallOfFameV1.id) then
			require(script.Parent.Inspect).openCard(result.card, HallOfFameV1.id)
		end
	end)
end

local function build()
	Theme.recompute()
	local phone = Theme.isMobile
	local base = phone and HudPlace.base.phone or HudPlace.base.pc
	local gui = Instance.new("ScreenGui")
	gui.Name = "HallOfFameV1Gui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- UI-1b: 새 창 = 처음부터 Sibling
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local dim = Instance.new("TextButton")
	dim.Name = "Dim"
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.55
	dim.Size = UDim2.fromScale(1, 1)
	dim.Parent = gui
	dim.Activated:Connect(function()
		UIManager.close(HallOfFameV1.id)
	end)
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
			scale.Scale = math.min(v.X / base.w, v.Y / base.h)
		end
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	built = { gui = gui, root = root, phone = phone }
	UIManager.register(HallOfFameV1.id, {
		kind = "window",
		screenGui = gui,
		hasCloseButton = true,
		onOpen = function()
			gui.Enabled = true
			if not Flags.layers then
				gui.DisplayOrder = math.max(gui.DisplayOrder, L.displayOrder)
			end
			state.classId = state.classId or (ClassData.classes[player:GetAttribute("ClassId") or ""] and player:GetAttribute("ClassId")) or ClassData.order[1]
			render()
			fetch(boardIdOf(state.tab))
		end,
		onClose = function()
			gui.Enabled = false
			state.classMenu = false
		end,
	})
end

local function selectTab(id)
	state.tab = id
	state.classMenu = false
	render()
	fetch(boardIdOf(id))
end

render = function()
	local B = built
	if not B or not B.gui.Enabled then
		return
	end
	if B.win then
		B.win:Destroy()
	end
	local phone = B.phone
	local P = phone and L.phone or L.pc
	local W, H = P.win[3], P.win[4]
	local win = frame(B.root, P.win, C.window, "Window")
	corner(win, phone and 14 or 18)
	stroke(win, C.stroke, 3)
	B.win = win
	-- 머리: 왕관 + 제목 + [?] · 닫기
	local headLine = frame(win, { 0, P.head, W, phone and 3 or 4 }, "FFC83D", "AccentLine")
	headLine.ZIndex = 2
	local icon = UiKit.icon(win, "rank", P.icon)
	icon.Position = UDim2.fromOffset(phone and 12 or 20, math.floor((P.head - P.icon) / 2))
	local title = label(win, Text.get("ui1c.hall.title"), px(P.title), "FFFFFF", { name = "Title", font = "korean", rect = { (phone and 12 or 20) + P.icon + 10, 0, W * 0.5, P.head } })
	title.TextTruncate = Enum.TextTruncate.None
	if Flags.help then
		local hb = require(script.Parent.Parent.ui.v2.HelpButton).besideLabel(title, "hall")
		hb.Size = UDim2.fromOffset(phone and 26 or 36, phone and 26 or 36)
	end
	UiKit.closeButton({ parent = win, name = "Close", rect = { W - P.close - 10, math.floor((P.head - P.close) / 2), P.close, P.close }, onActivated = function()
		UIManager.close(HallOfFameV1.id)
	end })
	-- 탭 4
	local T = P.tabs
	local tx = T.x
	for _, tab in ipairs(TABS) do
		local on = state.tab == tab.id
		local b = Instance.new("TextButton")
		b.Name = "Tab_" .. tab.id
		b.AutoButtonColor = false
		b.BackgroundColor3 = hex(on and C.tabOn or C.tabOff)
		b.Font = UiKit.font("koreanBold")
		b.TextSize = px(T.text)
		b.TextColor3 = hex(on and C.tabOnText or C.tabOffText)
		b.Text = Text.get(tab.textKey)
		b.Position = UDim2.fromOffset(tx, T.y)
		local tw = TextService:GetTextSize(b.Text, b.TextSize, b.Font, Vector2.new(1000, 200)).X + T.padX * 2
		b.Size = UDim2.fromOffset(tw, T.h)
		b.Parent = win
		corner(b, 8)
		UiKit.attachPress(b, { onActivated = function()
			selectTab(tab.id)
		end })
		tx += tw + T.gap
	end
	-- 오른쪽: 시즌 알약 · 기준 상자
	local boardId = boardIdOf(state.tab)
	local board = state.boards[boardId]
	local BS = P.basis
	local pill = frame(win, { 0, T.y, 0, BS.h }, C.pill, "SeasonPill")
	pill.AnchorPoint = Vector2.new(1, 0)
	pill.Position = UDim2.fromOffset(W - T.x, T.y)
	pill.AutomaticSize = Enum.AutomaticSize.X
	corner(pill, "pill")
	stroke(pill, C.stroke, 2)
	local pl = Instance.new("UIListLayout")
	pl.FillDirection = Enum.FillDirection.Horizontal
	pl.VerticalAlignment = Enum.VerticalAlignment.Center
	pl.Padding = UDim.new(0, 8)
	pl.Parent = pill
	local pp = Instance.new("UIPadding")
	pp.PaddingLeft = UDim.new(0, 14)
	pp.PaddingRight = UDim.new(0, 16)
	pp.Parent = pill
	local pc = ArtImage.label(pill, "ui/v9/rank-crown", UDim2.fromOffset(math.floor(BS.h * 0.55), math.floor(BS.h * 0.43)), "♛")
	pc.LayoutOrder = 1
	local ptext = label(pill, seasonText(board and board.season) or Text.get("ui1c.hall.loading"), px(BS.small), "FFFFFF", { name = "Season" })
	ptext.AutomaticSize = Enum.AutomaticSize.X
	ptext.Size = UDim2.fromOffset(0, BS.h)
	ptext.TextTruncate = Enum.TextTruncate.None
	ptext.LayoutOrder = 2
	if not phone then
		local basisKey = state.tab == "party" and "ui1c.hall.basis.partyKills" or "ui1c.hall.basis.stage"
		local box = Instance.new("TextButton")
		box.Name = "Basis"
		box.AutoButtonColor = false
		box.AnchorPoint = Vector2.new(1, 0)
		box.BackgroundColor3 = hex(C.tabOff)
		box.Font = UiKit.font("koreanBold")
		box.TextSize = px(BS.text)
		box.TextColor3 = Color3.new(1, 1, 1)
		box.AutomaticSize = Enum.AutomaticSize.X
		box.Size = UDim2.fromOffset(0, BS.h)
		box.Text = state.tab == "class" and Text.get("ui1c.hall.basis.class", { class = className(state.classId) or "" }) or Text.get(basisKey)
		local bp = Instance.new("UIPadding")
		bp.PaddingLeft = UDim.new(0, 16)
		bp.PaddingRight = UDim.new(0, state.tab == "class" and 40 or 16)
		if state.tab == "class" then -- ▾ = 선 두 개(글꼴에 ▾ 없음 - 두부)
			for i, rot in ipairs({ 45, -45 }) do
				local seg = Instance.new("Frame")
				seg.Name = "Chevron" .. i
				seg.BorderSizePixel = 0
				seg.BackgroundColor3 = Color3.new(1, 1, 1)
				seg.AnchorPoint = Vector2.new(0.5, 0.5)
				seg.Size = UDim2.fromOffset(10, 3)
				seg.Rotation = rot
				seg.Position = UDim2.new(1, i == 1 and 20 or 26, 0.5, 0)
				seg.Parent = box
			end
		end
		bp.Parent = box
		box.Parent = win
		corner(box, 8)
		task.defer(function() -- 알약 폭이 정해진 뒤 그 왼쪽에
			if not box.Parent then
				return
			end
			local s = B.root:FindFirstChildOfClass("UIScale").Scale
			box.Position = UDim2.fromOffset(W - T.x - pill.AbsoluteSize.X / s - 12, T.y)
			local by = label(win, Text.get("ui1c.hall.basis"), px(BS.small), C.muted, { name = "BasisLabel", align = Enum.TextXAlignment.Right })
			by.AnchorPoint = Vector2.new(1, 0)
			by.Position = UDim2.fromOffset(W - T.x - pill.AbsoluteSize.X / s - 12 - box.AbsoluteSize.X / s - 10, T.y)
			by.Size = UDim2.fromOffset(80, BS.h)
		end)
		if state.tab == "class" then -- ▾ = 직업 고르기(작은 목록)
			UiKit.attachPress(box, { onActivated = function()
				state.classMenu = not state.classMenu
				render()
			end })
		end
	end
	if phone and state.tab == "class" then -- 폰: 직업 = 탭 줄 오른쪽 작은 칸(누를 때마다 다음 직업)
		local chip = Instance.new("TextButton")
		chip.Name = "ClassChip"
		chip.AutoButtonColor = false
		chip.BackgroundColor3 = hex(C.tabOff)
		chip.Font = UiKit.font("koreanBold")
		chip.TextSize = px(T.text)
		chip.TextColor3 = Color3.new(1, 1, 1)
		chip.Text = Text.get("ui1c.hall.basis.class", { class = className(state.classId) or "" })
		chip.Position = UDim2.fromOffset(tx, T.y)
		chip.Size = UDim2.fromOffset(84, T.h)
		chip.Parent = win
		corner(chip, 8)
		UiKit.attachPress(chip, { onActivated = function()
			local i = table.find(ClassData.order, state.classId) or 0
			state.classId = ClassData.order[i % #ClassData.order + 1]
			selectTab("class")
		end })
	end
	-- 단상 · 목록 · 내 줄
	local entries = board and board.entries or {}
	local names = board and board.names or {}
	HallOfFameV1.podium(win, P.podium, entries, names, P.podium)
	local LS = P.list
	local me = P.me
	local meY = H - me.bottom - me.h
	local showClass = false
	for _, e in ipairs(entries) do
		if e.classId then
			showClass = true
			break
		end
	end
	local list = frame(win, LS, C.row, "List")
	corner(list, 12)
	stroke(list, C.rowLine, 2)
	local valueHead = Text.get(state.tab == "party" and "ui1c.hall.basis.partyKills" or "ui1c.hall.basis.stage")
	if LS.headH > 0 then
		label(list, Text.get("ui1c.hall.col.rank"), px(LS.small), C.muted, { align = Enum.TextXAlignment.Center, rect = { 0, 0, LS.rankW, LS.headH } })
		label(list, Text.get("ui1c.hall.col.name"), px(LS.small), C.muted, { rect = { LS.rankW + LS.face + 24, 0, 400, LS.headH } })
		if showClass then
			label(list, Text.get("ui1c.hall.col.class"), px(LS.small), C.muted, { rect = { LS.classX, 0, 160, LS.headH } })
		end
		label(list, valueHead, px(LS.small), C.muted, { align = Enum.TextXAlignment.Right, rect = { LS[3] - LS.padR - 300, 0, 300, LS.headH } })
		frame(list, { 0, LS.headH, LS[3], 2 }, C.rowLine, "HeadLine")
	end
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Rows"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(0, LS.headH + (LS.headH > 0 and 2 or 0))
	scroll.Size = UDim2.new(1, 0, 1, -(LS.headH + (LS.headH > 0 and 2 or 0)))
	scroll.ScrollBarThickness = phone and 4 or 6
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.Parent = list
	local function row(parent, y, e, rankText, isMe, w, h, textSize)
		local r = frame(parent, { 0, y, w, h }, nil, isMe and "MeRow" or ("Row" .. tostring(e and e.rank or "")))
		local id = e and (e.userId or (e.members and e.members[1])) or player.UserId
		local nm = e and nameOf(names, id) or player.DisplayName
		label(r, rankText, px(textSize), isMe and C.me or "FFFFFF", { name = "Rank", align = Enum.TextXAlignment.Center, font = "number", rect = { 0, 0, LS.rankW, h } })
		local av = HallOfFameV1.avatar(r, id, nm, LS.face, isMe and hex(C.me) or nil, 2)
		av.Position = UDim2.fromOffset(LS.rankW + 8, math.floor((h - LS.face) / 2))
		label(r, isMe and Text.get("ui1c.hall.me", { name = player.DisplayName }) or nm, px(textSize), "FFFFFF", { name = "Name", rect = { LS.rankW + LS.face + 24, 0, LS.classX - (LS.rankW + LS.face + 32), h } })
		local cls = className(e and e.classId)
		if showClass and cls then
			label(r, cls, px(textSize), C.muted, { name = "Class", rect = { LS.classX, 0, 160, h } })
		end
		label(r, e and valueOf(e) or "", px(textSize), "FFFFFF", { name = "Value", align = Enum.TextXAlignment.Right, font = "number", rect = { w - LS.padR - 200, 0, 200, h } })
		if e and not isMe then
			local hit = Instance.new("TextButton")
			hit.Name = "Hit"
			hit.Text = ""
			hit.BackgroundTransparency = 1
			hit.Size = UDim2.fromScale(1, 1)
			hit.Parent = r
			hit.Activated:Connect(function()
				openCard(boardId, e.key)
			end)
		end
		return r
	end
	local y = 0
	for i = 4, #entries do
		local e = entries[i]
		row(scroll, y, e, tostring(e.rank), false, LS[3] - 8, LS.rowH, LS.text)
		frame(scroll, { 12, y + LS.rowH - 1, LS[3] - 32, 1 }, C.rowLine, "Line")
		y += LS.rowH
	end
	scroll.CanvasSize = UDim2.fromOffset(0, y)
	if #entries == 0 and board then -- 빈 상태 = H 그대로(왕관 + "아직 기록이 없어요" + [구역 선택 열기])
		UiParts.emptyState(list, "rank", function()
			UIManager.close(HallOfFameV1.id)
			UIManager.openLazy("stageSelect")
		end)
	elseif not board then
		label(list, Text.get("ui1c.hall.loading"), px(LS.text), C.muted, { align = Enum.TextXAlignment.Center, rect = { 0, 0, LS[3], LS[4] } })
	end
	-- 내 줄(노랑 테 3 · 고정)
	local mine = board and board.mine
	local meRes = state.me[boardId] and state.me[boardId].result
	local meX = phone and LS[1] or 16
	local meW = phone and LS[3] or (W - 32)
	local meRow = frame(win, { meX, meY, meW, me.h }, C.meBg, "Me")
	corner(meRow, 12)
	stroke(meRow, C.me, me.stroke)
	local rankText, entry
	if mine then
		rankText, entry = tostring(mine.rank), { userId = player.UserId, stage = mine.stage, count = mine.count, classId = state.tab == "class" and state.classId or nil }
	elseif meRes then
		entry = (meRes.stage or meRes.count) and { userId = player.UserId, stage = meRes.stage, count = meRes.count, classId = state.tab == "class" and state.classId or nil } or nil
		if meRes.rank then
			rankText = tostring(meRes.rank)
		elseif meRes.topPercent then
			rankText = Text.get("ui1c.hall.me.percent", { percent = tostring(meRes.topPercent) })
		elseif meRes.outOfTop and entry then
			rankText = Text.get("ui1c.hall.me.out", { top = tostring(meRes.topN or 100) })
		else
			rankText = "-"
		end
	else
		rankText = "-"
	end
	local saveW = LS.rankW
	if #rankText > 4 then
		LS = table.clone(LS)
		LS.rankW = math.max(LS.rankW, phone and 64 or 120)
	end
	local r = row(meRow, 0, entry, rankText, true, meW, me.h, me.text)
	if not entry then
		r:FindFirstChild("Value").Text = Text.get("ui1c.hall.me.none")
		r:FindFirstChild("Value").TextColor3 = hex(C.muted)
	end
	LS.rankW = saveW
	-- 직업 고르기 목록(직업별 탭 · PC)
	if state.classMenu and not phone then
		local box = win:FindFirstChild("Basis")
		local menu = frame(win, { 0, T.y + BS.h + 6, 220, #ClassData.order * 44 + 8 }, C.window, "ClassMenu")
		menu.ZIndex = 10
		corner(menu, 10)
		stroke(menu, C.stroke, 2)
		task.defer(function()
			if box and box.Parent and menu.Parent then
				local s = B.root:FindFirstChildOfClass("UIScale").Scale
				menu.Position = UDim2.fromOffset((box.AbsolutePosition.X - win.AbsolutePosition.X) / s, T.y + BS.h + 6)
			end
		end)
		for i, cid in ipairs(ClassData.order) do
			local b = Instance.new("TextButton")
			b.Name = "Class_" .. cid
			b.ZIndex = 11
			b.AutoButtonColor = false
			b.BackgroundColor3 = hex(cid == state.classId and C.tabOn or C.tabOff)
			b.TextColor3 = hex(cid == state.classId and C.tabOnText or C.tabOffText)
			b.Font = UiKit.font("koreanBold")
			b.TextSize = px(BS.text)
			b.Text = className(cid) or cid
			b.Position = UDim2.fromOffset(4, 4 + (i - 1) * 44)
			b.Size = UDim2.fromOffset(212, 40)
			b.Parent = menu
			corner(b, 8)
			b.Activated:Connect(function()
				state.classId = cid
				selectTab("class")
			end)
		end
	end
end

local function ensureBuilt()
	Theme.recompute()
	if built and built.phone ~= Theme.isMobile then
		UIManager.unregister(HallOfFameV1.id)
		built.gui:Destroy()
		built = nil
	end
	if not built then
		build()
	end
end

function HallOfFameV1.open()
	ensureBuilt()
	return UIManager.open(HallOfFameV1.id)
end

function HallOfFameV1.toggle()
	ensureBuilt()
	local ok, text = UIManager.switchTo(HallOfFameV1.id)
	if not ok and text then
		Toast.push("TC", { text = text, colorName = "textPrimary" })
	end
end

function HallOfFameV1.init()
	ensureBuilt()
	local lKey = require(script.Parent.Parent.ui.PanelRegistry).actionKey("leaderboard")
	game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == lKey then
			HallOfFameV1.toggle()
		end
	end)
end

-- 검사용: 지금 상태(탭 · 순위표 id · 단상 이름 · 줄 수 · 내 줄 글)
function HallOfFameV1.debugState()
	local B = built
	local win = B and B.win
	local out = { tab = state.tab, boardId = boardIdOf(state.tab), open = B and B.gui.Enabled or false }
	if win then
		local pod = win:FindFirstChild("Podium")
		out.podium = {}
		for rank = 1, 3 do
			local b = pod and pod:FindFirstChild("Block" .. rank)
			out.podium[rank] = b and b:FindFirstChild("Name") and b.Name.Text or nil
		end
		local rows = win:FindFirstChild("List") and win.List:FindFirstChild("Rows")
		out.rows = rows and #rows:GetChildren() or 0
		local meRow = win:FindFirstChild("Me")
		out.me = meRow and meRow:FindFirstChild("MeRow") and (meRow.MeRow.Rank.Text .. " | " .. meRow.MeRow.Value.Text) or nil
	end
	return out
end

return HallOfFameV1
