-- QUEUE-UI2 UI2-4 HUD v5 메뉴(02_hud/v5 spec): PC 왼쪽 "내 캐릭터 관리"(가방 · 성장 · 수련 · 지도 · 더보기) + 오른쪽 "진행 · 보상"(구역 · 퀘스트 · 보상 · 상점) + 귀환(둥근 판) ·
--   폰 위 줄(가방 · 보상 · 더보기) + 더보기(자주 쓰는 것 + 나머지 4열). 항목 = HudData · 좌표 = UiLayoutData.hud · 키 칩 = PanelRegistry(창 키 · 행동 키) · 버튼 = UiKit(판 B · 둥근 판 · 손맛).
--   스위치 HudData.menuV5 = false → 옛 hud/MenuBar(그 스크립트가 같은 스위치를 본다). 보스전(BossEncounterId) = 오른쪽 열 숨김 · 왼쪽 작게 · 반투명 · 이름표 없음.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local HudData = require(ReplicatedStorage.Shared.data.HudData)
if not HudData.menuV5 then
	return
end
local Layout = require(ReplicatedStorage.Shared.data.UiLayoutData).hud
local V6 = Layout.v6 -- UI-1 0단계: 02 v6 오른쪽 열 접기(B-7) · 상단 바 아래 기준 세로 자리
local HudPlace = require(ReplicatedStorage.Shared.HudPlace)
local UiModel = require(ReplicatedStorage.Shared.UiModel)
local Tokens = require(ReplicatedStorage.Shared.data.UiTokens)
local RewardHub = require(ReplicatedStorage.Shared.RewardHub)
local Text = require(ReplicatedStorage.Shared.Text)
local client = script.Parent.Parent
local PanelRegistry = require(client.ui.PanelRegistry)
local UIManager = require(client.UIManager)
local Toast = require(client.ui.kit.Toast)
local UiRoot = require(client.ui.v2.UiRoot)
local UiKit = require(client.ui.v2.UiKit)

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "HudMenuV2Gui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- 자식(아이콘 · 칩 · 점) = 부모 위(펼침 창 버튼 ZIndex를 올려도 아이콘이 가려지지 않게)
gui.IgnoreGuiInset = true -- spec 좌표 원점 = 화면 왼쪽 위(로블록스 버튼 자리 0 ~ 60 비움 포함)
gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets -- UI-1 0단계(02 v6 §2): 노치 = 기기 안전 영역 안 · 상단 바는 좌표로 비움
gui.DisplayOrder = 150 -- 창 딤(100 ~ 149) 위 · overlay(200 ~) 아래 - 열린 창을 같은 버튼으로 닫는다(옛 MenuBar와 같은 층)
gui.Parent = player:WaitForChild("PlayerGui")
local recallEvent = Instance.new("BindableEvent") -- 귀환 = WorldClient(시전 · 취소 · 쿨 - 같은 동작)
recallEvent.Name = "HudRecallPress"
recallEvent.Parent = gui

local leftRoot = UiRoot.new(gui, "HudLeft", 0, 0, true) -- UI-1 0단계: HUD 배율 하나(m - HudPlace.scale)
local rightRoot = UiRoot.new(gui, "HudRight", 1, 0, true)
local phone = leftRoot.isPhone
local L = phone and Layout.phone or Layout.pc
if phone and require(ReplicatedStorage.Shared.data.UiV2Flags).hud then -- UI-1 2단계(02 v6 §4): 폰 메뉴 줄 = 상단 바 밖 (8, 62) · 펼침 창 = 그 아래
	L = table.clone(Layout.phone)
	L.top, L.moreWindow, L.rewardWindow = V6.phone.menuTop, V6.phone.moreWindow, V6.phone.rewardWindow
end
for _, r in ipairs({ leftRoot, rightRoot }) do
	r.frame.ZIndex = 1
end

local HIDE = {
	tutorial = function()
		return player:GetAttribute("TutorialCompleted") ~= true and (player:GetAttribute("TutorialStep") or 0) > 0
	end,
	noClass = function()
		local c = player:GetAttribute("ClassId")
		return c == nil or c == ""
	end,
}
local function hidden(id)
	local def = HudData.items[id]
	local reg = def.panel and PanelRegistry.get(def.panel)
	for _, name in ipairs(reg and reg.menuHiddenWhile or {}) do
		if HIDE[name] and HIDE[name]() then
			return true
		end
	end
	return false
end
local function inBoss()
	return player:GetAttribute("BossEncounterId") ~= nil
end

-- 키 칩 글자 = 게임 실제 키(창 = PanelRegistry.hotkeyOf · 행동 = actionKey) - 없으면 칩 없음
local function keyOf(id)
	local def = HudData.items[id]
	local code = def.panel and PanelRegistry.hotkeyOf(def.panel) or (def.action == "hubReturn" and PanelRegistry.actionKey("hubReturn")) or nil
	return code and code.Name or nil
end

local lastToast = { text = nil, at = 0 }
local function notifyBlocked(text)
	if lastToast.text == text and os.clock() - lastToast.at < 3 then
		return
	end
	lastToast.text, lastToast.at = text, os.clock()
	Toast.push("TC", { text = text, colorName = "textPrimary" })
end

local items = {} -- id → { button, ctl, dot, label, chip, id }
local moreWin, rewardWin
local setMore, setReward

local function press(id)
	local def = HudData.items[id]
	if def.action == "more" then
		setReward(false)
		setMore(not moreWin.Visible)
		return
	end
	if def.action == "reward" then
		setMore(false)
		setReward(not rewardWin.Visible)
		return
	end
	setMore(false)
	setReward(false)
	if def.action == "shop" then
		require(client.panels.Shop).openFromHud("recommend")
	elseif def.action == "pet" then
		require(client.panels.EggInfo).toggle()
	elseif def.action == "hubReturn" then
		recallEvent:Fire()
	elseif def.panel then
		local blocked = UIManager.switchBlockedReason(def.panel)
		if blocked then
			notifyBlocked(blocked)
			return
		end
		local ok, text = UIManager.openLazy(def.panel)
		if not ok and text then
			notifyBlocked(text)
		end
	end
end

local function makeItem(parent, id, size, withLabel)
	local def = HudData.items[id]
	local kind = def.round and "combat" or "plate"
	local b = UiKit.imageButton(kind, "Menu_" .. id)
	b.Size = UDim2.fromOffset(size, size)
	b.ZIndex = 2
	local icon = UiKit.icon(b, phone and def.phoneIcon or def.icon, math.floor(size * (def.round and 0.6 or 0.78)), { center = true })
	icon.ZIndex = 3
	b.Parent = parent
	local ctl = UiKit.attachPress(b, { kind = kind, onActivated = function()
		press(id)
	end, icons = { icon } })
	local item = { id = id, button = b, ctl = ctl, icon = icon }
	local key = not phone and keyOf(id)
	if key then -- 키 칩(오른쪽 아래 · 진한 바탕)
		local chip = UiKit.label(b, key, "micro", "text.primary", { name = "KeyChip", font = "number", align = Enum.TextXAlignment.Center })
		chip.BackgroundTransparency = 0
		chip.BackgroundColor3 = UiKit.color("bg.deep")
		chip.AnchorPoint = Vector2.new(1, 1)
		chip.Position = UDim2.new(1, 4, 1, 4)
		chip.Size = UDim2.fromOffset(HudData.keyChip.pc, HudData.keyChip.pc)
		chip.ZIndex = 4
		UiKit.corner(chip, 6)
		item.chip = chip
	end
	if withLabel then -- 이름표(PC 버튼 아래 · 보스전 숨김)
		local l = UiKit.label(b, Text.get(def.label), "caption", "text.primary", { name = "NameTag", align = Enum.TextXAlignment.Center })
		l.AnchorPoint = Vector2.new(0.5, 0)
		l.Position = UDim2.new(0.5, 0, 1, 4)
		l.Size = UDim2.new(1, 40, 0, 0)
		l.AutomaticSize = Enum.AutomaticSize.Y
		l.TextWrapped = true
		l.TextStrokeTransparency = 0.3
		l.TextStrokeColor3 = UiKit.color("bg.deep")
		l.ZIndex = 3
		item.label = l
	end
	local dotPx = phone and HudData.alertDot.phone or HudData.alertDot.pc
	local dot = Instance.new("Frame") -- 알림 점(빨강 = 작게만 · 숫자 없음)
	dot.Name = "AlertDot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.new(1, -6, 0, 6)
	dot.Size = UDim2.fromOffset(dotPx, dotPx)
	dot.BackgroundColor3 = UiKit.color("warning")
	dot.Visible = false
	dot.ZIndex = 5
	UiKit.corner(dot, dotPx)
	UiKit.stroke(dot, "bg.deep", 2)
	dot.Parent = b
	item.dot = dot
	items[id] = item
	return item
end

-- 펼침 창(더보기 · 보상 공통 모양 - 창 몸통 + 테두리)
local function popup(parent, name, rect)
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = UiKit.color("panel.window")
	UiKit.place(f, rect)
	UiKit.corner(f, Tokens.corner.window)
	UiKit.stroke(f, "line", Tokens.stroke.window)
	f.Visible = false
	f.ZIndex = 10
	f.Parent = parent
	return f
end

-- ── 짓기 ──
local columns = {}
if phone then
	local T = L.top
	local row = Instance.new("Frame")
	row.Name = "TopRow"
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 1)
	row.Parent = leftRoot.frame
	columns.top = { frame = row, ids = HudData.phone.top, spec = T, dir = "x" }
	for _, id in ipairs(HudData.phone.top) do
		makeItem(row, id, T.size, false)
	end
	moreWin = popup(leftRoot.frame, "MorePanel", L.moreWindow)
	local head = UiKit.label(moreWin, Text.get("hud.more.frequent"), "caption", "text.secondary", { name = "FrequentHead" })
	UiKit.place(head, { 14, 8, 200, 26 })
	head.ZIndex = 11
	local band = Instance.new("Frame") -- 자주 쓰는 것 칸 바탕
	band.Name = "FrequentBand"
	band.BackgroundColor3 = UiKit.color("panel.section")
	UiKit.place(band, L.moreFrequent)
	UiKit.corner(band, Tokens.corner.card)
	band.ZIndex = 10
	band.Parent = moreWin
	columns.more = { frame = moreWin, lists = { HudData.phone.moreFrequent, HudData.phone.moreRest }, spec = L.moreItem }
	for _, list in ipairs(columns.more.lists) do
		for _, id in ipairs(list) do
			makeItem(moreWin, id, L.moreItem.size, false).button.ZIndex = 11
		end
	end
else
	columns.left = { frame = leftRoot.frame, ids = HudData.pc.left, spec = L.left, dir = "y" }
	for _, id in ipairs(HudData.pc.left) do
		makeItem(leftRoot.frame, id, L.left.size, true)
	end
	local rightIds = table.clone(HudData.pc.right)
	table.insert(rightIds, HudData.pc.returnItem)
	columns.right = { frame = rightRoot.frame, ids = rightIds, spec = L.right, dir = "y" }
	for _, id in ipairs(rightIds) do
		makeItem(rightRoot.frame, id, L.right.size, true)
	end
	moreWin = popup(leftRoot.frame, "MorePanel", L.moreWindow)
	columns.more = { frame = moreWin, lists = { HudData.pc.more }, spec = L.moreItem }
	for _, id in ipairs(HudData.pc.more) do
		makeItem(moreWin, id, L.moreItem.size, false).button.ZIndex = 11
	end
end

-- 보상 창: 줄(출석 · 시즌 출석판 · 선물함) + 줄 점
rewardWin = popup(phone and leftRoot.frame or rightRoot.frame, "RewardPanel", L.rewardWindow)
local rewardRows = {}
do
	local title = UiKit.label(rewardWin, Text.get("hud.reward.title"), "heading", "text.primary", { name = "Title", font = "korean" })
	UiKit.place(title, { 16, 6, L.rewardWindow[3] - 32, phone and 34 or 44 })
	title.ZIndex = 11
	local rowH = phone and 44 or 46
	local y0 = phone and 42 or 52
	for i, r in ipairs(HudData.rewards) do
		local b = UiKit.imageButton("sec", "Reward_" .. r.id)
		UiKit.place(b, { 10, y0 + (i - 1) * (rowH + 4), L.rewardWindow[3] - 20, rowH })
		b.ZIndex = 11
		b.Parent = rewardWin
		local ic = UiKit.icon(b, r.icon, rowH - 12)
		ic.Position = UDim2.fromOffset(8, 6)
		ic.ZIndex = 12
		local l = UiKit.label(b, Text.get(r.label), "body", "text.primary", { name = "Label", font = "korean" })
		l.Position = UDim2.fromOffset(rowH + 6, 0)
		l.Size = UDim2.new(1, -(rowH + 30), 1, 0)
		l.ZIndex = 12
		local dotPx = phone and HudData.alertDot.phone or HudData.alertDot.pc
		local dot = Instance.new("Frame")
		dot.Name = "AlertDot"
		dot.AnchorPoint = Vector2.new(1, 0.5)
		dot.Position = UDim2.new(1, -12, 0.5, 0)
		dot.Size = UDim2.fromOffset(dotPx, dotPx)
		dot.BackgroundColor3 = UiKit.color("warning")
		dot.Visible = false
		dot.ZIndex = 13
		UiKit.corner(dot, dotPx)
		dot.Parent = b
		UiKit.attachPress(b, { kind = "sec", onActivated = function()
			setReward(false)
			if r.id == "attendance" then
				require(client.panels.Attendance).open()
			elseif r.id == "seasonBoard" then
				require(client.panels.SeasonBoard).open()
			elseif r.id == "gift" then
				if (player:GetAttribute("GiftPending") or 0) > 0 then
					ReplicatedStorage:WaitForChild("ShopRequest"):FireServer("giftOpen")
				else
					Toast.push("TC", { text = Text.get("hud.reward.giftEmpty"), colorName = "textPrimary" })
				end
			end
		end })
		rewardRows[r.id] = { button = b, dot = dot }
	end
end

-- ── 배치(보스전 · 숨김 항목 = 앞으로 당김) ──
-- UI-1 0단계 오른쪽 열(02 v6 §9 B-7 접기): 시작 = 상단 바 아래 기준 y(HudPlace.topY - 옛 fitRight는 배율을 y 전체에 곱해 1366×768에서 상단 바 쪽으로 올라갔다) ·
--   메인 퀘스트 칸이 그보다 길면 그 아래(둘 다 AbsolutePosition 공통 좌표) · 칸 수 = 보이는 칸 · 이름표 높이(글자 배율) = 마지막 칸까지 포함.
--   1단계 = 1열 · 2단계 = 바깥 3 + 안쪽 2 · 3단계 = 바깥 2 + 안쪽 1 + 나머지(상점 · 귀환)는 더보기 안으로.
local foldedToMore = {} -- 3단계에서 더보기로 보낸 오른쪽 열 칸 id
local function rightTop(m)
	local top = HudPlace.topY(V6.rightFold.y, 0, 0, m, Tokens.base.pc) / m
	local tg = player.PlayerGui:FindFirstChild("TodayGoalGui")
	local box = tg and tg:FindFirstChild("TodayGoal")
	local ng = player.PlayerGui:FindFirstChild("NextGoalGui")
	local card = ng and ng.Enabled and ng:FindFirstChild("NextGoal")
	if card and card.AbsoluteSize.Y > 0 then -- UI-1 2단계: 다음 목표 카드 아래(카드가 칩 묶음 따라 내려가면 같이)
		top = math.max(top, math.ceil((card.AbsolutePosition.Y + card.AbsoluteSize.Y - rightRoot.frame.AbsolutePosition.Y) / m) + V6.rightFold.gap)
	end
	if box and tg.Enabled and box.Visible and box.AbsoluteSize.Y > 0 then -- UI-1 2단계: 옛 3줄 칸이 꺼져 있으면(다음 목표 카드) 밀지 않음
		-- AbsolutePosition = 모든 ScreenGui 공통 "상단 바 아래" 좌표(IgnoreGuiInset Gui 안 프레임도 화면 맨 위 = −58 · Studio 실측) → 인셋을 더하지 않는다(옛 = 58 이중 차감 · 02 MISSING 1)
		local bottom = box.AbsolutePosition.Y + box.AbsoluteSize.Y
		top = math.max(top, math.ceil((bottom - rightRoot.frame.AbsolutePosition.Y) / m) + 12)
	end
	return top
end

local function placeRight(col, boss)
	local m = math.max(rightRoot.scale.Scale, 0.01)
	local visible = {}
	for _, id in ipairs(col.ids) do
		if not hidden(id) then
			table.insert(visible, id)
		end
	end
	local F = V6.rightFold
	local top = rightTop(m)
	local spec = table.clone(F)
	spec.y = top
	local fold = HudPlace.rightFold(spec, #visible, gui.AbsoluteSize.Y, m, UiModel.textMul(UiKit.textStep(), UiKit.platformTextName()))
	table.clear(foldedToMore)
	local slot = {}
	for i, id in ipairs(visible) do
		if i <= fold.outer then
			slot[id] = { 0, i - 1 }
		elseif i <= fold.outer + fold.inner then
			slot[id] = { 1, i - fold.outer - 1 }
		else
			table.insert(foldedToMore, id)
		end
	end
	local x0 = col.spec.x
	for _, id in ipairs(col.ids) do
		local item = items[id]
		local at = slot[id]
		local show = at ~= nil and not boss
		local folded = table.find(foldedToMore, id) ~= nil and not boss
		item.button.Parent = folded and moreWin or rightRoot.frame
		item.button.ZIndex = folded and 11 or 2
		item.button.Visible = show or folded
		if show then
			item.button.Size = UDim2.fromOffset(F.size, F.size)
			item.button.Position = UDim2.fromOffset(x0 - at[1] * (F.size + F.innerGap), top + at[2] * (F.size + fold.labelH + F.gap))
		end
		if item.label then
			item.label.Visible = show
		end
		if item.chip then
			item.chip.Visible = show
		end
	end
	col.fold = fold
end

local function placeColumn(col, boss)
	local spec = col.spec
	if boss and col == columns.left then
		spec = L.leftBoss
	end
	local labelsFit = true
	if col == columns.left then -- 로블록스 위쪽 버튼 줄(CoreGui · 화면 px 고정 - 우리 배율로 안 줄어듦) 아래에서 시작 · 아래 끝 안(작은 창)
		local s = math.max(leftRoot.scale.Scale, 0.01)
		local insetBase = math.ceil((GuiService:GetGuiInset().Y + 8) / s)
		if spec.y < insetBase then
			local n = #col.ids
			local room = Tokens.base.pc.h - 24 - insetBase
			local gap = math.max(10, math.min(spec.gap, math.floor((room - n * spec.size) / math.max(1, n - 1))))
			spec = { x = spec.x, y = insetBase, size = spec.size, gap = gap }
			labelsFit = gap >= 30
		end
	end
	if col == columns.right then
		placeRight(col, boss)
		for _, id in ipairs(col.ids) do
			local item = items[id]
			item.icon.ImageTransparency = boss and HudData.boss.menuTransparency or 0
			item.button.ImageTransparency = boss and HudData.boss.menuTransparency or 0
		end
		return
	end
	local n = 0
	for _, id in ipairs(col.ids) do
		local item = items[id]
		local show = not hidden(id) and not (boss and col == columns.right)
		item.button.Visible = show
		if show then
			local off = n * (spec.size + spec.gap)
			item.button.Size = UDim2.fromOffset(spec.size, spec.size)
			if col.dir == "x" then
				item.button.Position = UDim2.fromOffset(spec.x + off, spec.y)
			else
				item.button.Position = UDim2.fromOffset(spec.x, spec.y + off)
			end
			n += 1
		end
		if item.label then
			item.label.Visible = show and not boss and labelsFit
		end
		if item.chip then
			item.chip.Visible = show and not boss
		end
		item.icon.ImageTransparency = boss and HudData.boss.menuTransparency or 0
		item.button.ImageTransparency = boss and HudData.boss.menuTransparency or 0
	end
end

local function placeMore()
	local spec = columns.more.spec
	if phone then
		local rowIndex, col = 1, 0
		for li, list in ipairs(columns.more.lists) do
			if li > 1 then
				rowIndex, col = 2, 0
			end
			for _, id in ipairs(list) do
				local item = items[id]
				item.button.Visible = not hidden(id)
				if item.button.Visible then
					if col >= HudData.phone.moreCols then
						rowIndex, col = rowIndex + 1, 0
					end
					item.button.Position = UDim2.fromOffset(spec.x + col * (spec.size + spec.gap), spec.rowsY[math.min(rowIndex, #spec.rowsY)])
					col += 1
				end
			end
		end
	else
		local col = 0
		local list = table.clone(columns.more.lists[1])
		for _, id in ipairs(foldedToMore) do -- UI-1 0단계 접기 3단계: 상점 · 귀환 = 더보기 끝에
			table.insert(list, id)
		end
		for _, id in ipairs(list) do
			local item = items[id]
			item.button.Visible = not hidden(id)
			if item.button.Visible then
				item.button.Size = UDim2.fromOffset(spec.size, spec.size)
				item.button.Position = UDim2.fromOffset(spec.x + col * (spec.size + spec.gap), spec.y)
				if item.label and table.find(foldedToMore, id) then
					item.label.Visible = false
				end
				col += 1
			end
		end
		moreWin.Size = UDim2.fromOffset(math.max(L.moreWindow[3], spec.x * 2 + col * spec.size + math.max(col - 1, 0) * spec.gap), L.moreWindow[4])
	end
end

local function publishReserve()
	if phone then
		UIManager.hudReserve = { left = 0, right = 0 }
		return
	end
	local s = leftRoot.scale.Scale
	local lw = (L.left.x + L.left.size + 12) * s
	local rw = (Tokens.base.pc.w - L.right.x + 12) * s
	UIManager.hudReserve = { left = math.ceil(lw), right = math.ceil(rw) }
end

local function relayout()
	publishReserve()
	local boss = inBoss()
	for _, key in ipairs({ "left", "right", "top" }) do
		if columns[key] then
			placeColumn(columns[key], boss)
		end
	end
	placeMore()
	if boss then
		setMore(false)
		setReward(false)
	end
end

setMore = function(open)
	moreWin.Visible = open == true and not inBoss()
end
setReward = function(open)
	rewardWin.Visible = open == true and not inBoss()
	local rb = items.reward and items.reward.button
	if rewardWin.Visible and rb and not phone then -- PC: 보상 버튼 왼쪽(열이 퀘스트 칸에 밀려 내려와도 버튼 옆) · 화면 아래 안
		local w, h = L.rewardWindow[3], L.rewardWindow[4]
		local y = math.min(rb.Position.Y.Offset, Tokens.base.pc.h - 24 - h)
		rewardWin.Position = UDim2.fromOffset(rb.Position.X.Offset - 16 - w, y)
	end
end

-- ── 알림 점: 퀘스트 · 수련 · 가방(가득 · 새 아이템) · 상점(시즌 패스 받을 칸) · 보상(출석 · 시즌 출석판 · 선물함) · 더보기(안에 점) ──
local bagFull = false
local function setDot(id, on)
	if items[id] then
		items[id].dot.Visible = on == true
	end
end
local function refreshAlerts()
	setDot("quests", player:GetAttribute("QuestClaimable") == true)
	setDot("training", player:GetAttribute("TrainingReady") == true)
	setDot("inventory", bagFull or (player:GetAttribute("InventoryNewCount") or 0) > 0)
	setDot("shop", (player:GetAttribute("ShopClaimable") or 0) > 0)
	local view = require(client.panels.Attendance).currentView()
	local dots, any = RewardHub.dots(view, player:GetAttribute("GiftPending"))
	setDot("reward", any)
	for id, row in pairs(rewardRows) do
		row.dot.Visible = dots[id] == true
	end
	local inMore = false
	for _, list in ipairs({ foldedToMore, table.unpack(columns.more.lists) }) do
		for _, id in ipairs(list) do
			if items[id] and items[id].dot.Visible and items[id].button.Visible then
				inMore = true
			end
		end
	end
	setDot("more", inMore)
end
for _, name in ipairs({ "QuestClaimable", "TrainingReady", "ShopClaimable", "InventoryNewCount", "GiftPending" }) do
	player:GetAttributeChangedSignal(name):Connect(refreshAlerts)
end
ReplicatedStorage:WaitForChild("QuestUpdate").OnClientEvent:Connect(function()
	task.defer(refreshAlerts) -- Attendance가 먼저 view를 갱신한 뒤
end)
ReplicatedStorage:WaitForChild("InventoryFull").OnClientEvent:Connect(function()
	bagFull = true
	refreshAlerts()
end)

-- 잠김(지금 못 여는 창) = disabled 그림 + 누르면 흔들림 · 이유 토스트 / 열린 창 = 판 그대로(창이 위에 뜬다)
local function refreshLook()
	for id, item in pairs(items) do
		local def = HudData.items[id]
		local blocked = def.panel ~= nil and UIManager.switchBlockedReason(def.panel) ~= nil and not UIManager.isOpen(def.panel)
		item.ctl.setEnabled(not blocked)
		if blocked then
			item.button:SetAttribute("BlockedReason", UIManager.switchBlockedReason(def.panel))
		end
	end
end
UIManager.changed:Connect(function(id, isOpen)
	if isOpen then
		setMore(false)
		setReward(false)
	end
	if id == "inventory" and isOpen then
		bagFull = false
		refreshAlerts()
	end
	refreshLook()
end)
-- 잠긴 버튼 누름 = 흔들림(UiKit) + 이유 토스트
for _, item in pairs(items) do
	item.button.InputBegan:Connect(function(input)
		if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and item.ctl.bp.disabled then
			notifyBlocked(item.button:GetAttribute("BlockedReason") or UIManager.blockedTexts.canOpen)
		end
	end)
end

-- 귀환 둥근 판: 시전 · 쿨 시간(서버 Attribute - WorldClient와 같은 값) = 이름표 자리
local recall = items.hubReturn
if recall and recall.label then
	local function mmss(sec)
		local left = math.max(0, math.ceil(sec))
		return ("%d:%02d"):format(left // 60, left % 60)
	end
	RunService.Heartbeat:Connect(function()
		local now = Workspace:GetServerTimeNow()
		local castUntil, readyAt = player:GetAttribute("RecallCastUntil"), player:GetAttribute("RecallReadyAt")
		local t = Text.get("scene.world.recall")
		if castUntil and castUntil > now then
			t = ("%.1f"):format(castUntil - now)
		elseif readyAt and readyAt > now then
			t = mmss(readyAt - now)
		end
		recall.label.Text = t
		recall.label.TextTransparency = (readyAt and readyAt > now and not (castUntil and castUntil > now)) and 0.45 or 0
	end)
end

-- 환생 가능 알림 ④(한 회차에 한 번 - 접속 중) · 환생 = 마을 제단(메뉴 없음)
do
	local CharacterLevel = require(ReplicatedStorage.Shared.CharacterLevel)
	local GemData = require(ReplicatedStorage.Shared.data.GemData)
	local noticed = {}
	local function checkRebirth()
		local count = player:GetAttribute("RebirthCount") or 0
		if noticed[count] or player:GetAttribute("InMainMenu") == true then
			return
		end
		if RewardHub.rebirthReady(player:GetAttribute("CharacterLevel"), count, CharacterLevel.getRebirthRequiredLevel(count), GemData.maxRebirthCount) then
			noticed[count] = true
			Toast.push("TC", { text = Text.get("hud.rebirthReady"), grade = "notice", seconds = 5 })
		end
	end
	for _, name in ipairs({ "CharacterLevel", "RebirthCount", "InMainMenu" }) do
		player:GetAttributeChangedSignal(name):Connect(checkRebirth)
	end
	task.defer(checkRebirth)
end

-- 펼침 창 밖 누름 = 닫기
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		return
	end
	task.defer(function()
		setMore(false)
		setReward(false)
	end)
end)

task.spawn(function() -- 메인 퀘스트 칸 크기 · 자리가 바뀌면 오른쪽 열 다시
	local tg = player.PlayerGui:WaitForChild("TodayGoalGui", 30)
	local box = tg and tg:WaitForChild("TodayGoal", 10)
	if box then
		for _, prop in ipairs({ "AbsoluteSize", "AbsolutePosition", "Visible" }) do
			box:GetPropertyChangedSignal(prop):Connect(relayout)
		end
		relayout()
	end
end)
task.spawn(function() -- UI-1 2단계: 다음 목표 카드 자리 · 크기 · 켜짐이 바뀌면 오른쪽 열 다시
	local ng = player.PlayerGui:WaitForChild("NextGoalGui", 30)
	local card = ng and ng:WaitForChild("NextGoal", 10)
	if card then
		for _, prop in ipairs({ "AbsoluteSize", "AbsolutePosition" }) do
			card:GetPropertyChangedSignal(prop):Connect(relayout)
		end
		ng:GetPropertyChangedSignal("Enabled"):Connect(relayout)
		relayout()
	end
end)
rightRoot.scale:GetPropertyChangedSignal("Scale"):Connect(relayout)
for _, name in ipairs({ "TutorialCompleted", "TutorialStep", "ClassId", "BossEncounterId" }) do
	player:GetAttributeChangedSignal(name):Connect(function()
		relayout()
		refreshAlerts()
	end)
end
-- UI-1 0단계 ⑤: 메뉴 아이콘 · 판 그림 미리 받기(처음 보일 때 빈 칸 방지 · 더보기 안 아이콘 포함)
task.spawn(function()
	local list = {}
	for _, item in pairs(items) do
		for _, inst in ipairs({ item.icon, item.button }) do
			if inst and (inst:IsA("ImageLabel") or inst:IsA("ImageButton")) and inst.Image ~= "" then
				table.insert(list, inst)
			end
		end
	end
	pcall(function()
		game:GetService("ContentProvider"):PreloadAsync(list)
	end)
end)

-- 메뉴 화면(InMainMenu) 동안 숨김 - 월드에 들어오면 보임
local function refreshVisible()
	gui.Enabled = player:GetAttribute("InMainMenu") ~= true
end
player:GetAttributeChangedSignal("InMainMenu"):Connect(refreshVisible)
refreshVisible()
relayout()
refreshLook()
refreshAlerts()
if RunService:IsStudio() then -- 촬영 · 점검: 더보기 · 보상 펼침
	player:GetAttributeChangedSignal("DebugMenuMore"):Connect(function()
		setMore(player:GetAttribute("DebugMenuMore") == true)
	end)
	player:GetAttributeChangedSignal("DebugMenuReward"):Connect(function()
		setReward(player:GetAttribute("DebugMenuReward") == true)
	end)
end
