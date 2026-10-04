-- QUEUE-UI UI-1 메인 메뉴 겉모습(01_main-menu/v1 spec · checklist): 메인(제목 · 주 버튼 · 직업 선택 · 설정 · 소식) · 첫 실행 설정 문구 1회 · 이어하기 창(카드 · 빈 칸 · 잠긴 칸 · 보관 확인 · 보관함) ·
--   직업 선택(새 캐릭터 · 구경 모드). 기능(MENU2 - 칸 저장 · 전환 · 메뉴 왕복)은 그대로 쓴다: SlotRequest(list · play · new · archive · restore) · ClassSelectRequest · MainMenu.enter.
--   값 = UiTokens · 좌표 = UiLayoutData.mainMenu · 아이콘 = UiIconData · 직업 · 스킬 = UiModel(게임 데이터) · 글 = TextData_menu.
--   MainMenuV2.new(gui, deps) → { show(), hide(), isMainVisible(), openSlots(), refresh(), onEnterKey() }
--   deps = { enter(mode), showOldPage(name), slotRemote, classSelectRequest, settingSave(key, v) }
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tokens = require(Shared.data.UiTokens)
local SlotSaveData = require(Shared.data.SlotSaveData)
local GameInfoData = require(Shared.data.GameInfoData)
local UIColors = require(Shared.data.UIColors)
local ArtAssetIds = require(Shared.data.ArtAssetIds)
local UiModel = require(Shared.UiModel)
local Text = require(Shared.Text)
local UiRoot = require(script.Parent.UiRoot)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer
local MainMenuV2 = {}

local function className(id)
	local key = "class.name." .. tostring(id)
	local t = Text.get(key)
	if t == key or t == "" then
		local info = UiModel.classInfo(id)
		return info and info.name or tostring(id)
	end
	return t
end

local function commas(n)
	local s = tostring(math.floor(tonumber(n) or 0))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function agoText(t)
	if not t then
		return ""
	end
	local d = math.max(0, os.time() - t)
	if d < 3600 then
		return Text.get("menu.v2.agoM", { n = tostring(math.max(1, math.floor(d / 60))) })
	elseif d < 86400 then
		return Text.get("menu.v2.agoH", { n = tostring(math.floor(d / 3600)) })
	end
	return Text.get("menu.v2.agoD", { n = tostring(math.floor(d / 86400)) })
end

local function image(key)
	local e = key and ArtAssetIds[key]
	return e and e.image and ("rbxassetid://" .. tostring(e.image)) or nil
end

-- 얼굴: 그림(face 키 · 없으면 전설 그림을 faceRect로 잘라) · 없으면 직업 색 원 + 첫 글자(임시 - 01 MISSING)
local function face(parent, rect, classId)
	local info = UiModel.classInfo(classId) or {}
	local holder = Instance.new("Frame")
	holder.Name = "Face"
	holder.BackgroundColor3 = UIColors.classAccent[classId] or UiKit.color("panel.slot")
	UiKit.place(holder, rect)
	UiKit.corner(holder, Tokens.corner.card)
	holder.ClipsDescendants = true
	local img = image(info.face)
	local legend = image(info.legend)
	if img or (legend and info.faceRect) then
		local l = Instance.new("ImageLabel")
		l.Name = "FaceImage"
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, 1)
		l.Image = img or legend
		if not img then
			l.ImageRectOffset = Vector2.new(info.faceRect[1], info.faceRect[2])
			l.ImageRectSize = Vector2.new(info.faceRect[3], info.faceRect[3])
		end
		l.Parent = holder
	else
		local t = UiKit.label(holder, utf8.char(utf8.codepoint(className(classId), 1)), "cardName", "text.primary", { name = "Initial", align = Enum.TextXAlignment.Center, font = "korean" })
		t.Size = UDim2.fromScale(1, 1)
	end
	holder.Parent = parent
	return holder
end

function MainMenuV2.new(gui, deps)
	local ui = UiRoot.new(gui, "MenuV2")
	ui.frame.ZIndex = 5
	local L = ui.layout("mainMenu")
	local phone = ui.isPhone
	local self = { mode = "main", expanded = false, list = nil }
	local texts = {} -- 언어 바꾸면 다시

	-- ── 제목 ──
	local function gameName()
		return GameInfoData.names[Text.languageFor(nil)] or GameInfoData.name
	end
	local title = UiKit.label(ui.frame, gameName(), "title", "text.primary", { name = "GameTitle", font = "korean", rect = L.title })
	title.TextScaled = false
	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = UiKit.color("bg.deep")
	titleStroke.Thickness = phone and Tokens.titleStroke.phone or Tokens.titleStroke.pc
	titleStroke.Parent = title
	local titleSub = UiKit.label(ui.frame, Text.get("menu.v2.titleSub"), "titleSub", "title.sub", { name = "TitleSub", font = "number", rect = L.titleSub })
	local subSpacing = Instance.new("UIStroke")
	subSpacing.Thickness = 0
	subSpacing.Parent = titleSub

	-- ── 메뉴 버튼 ──
	local menu = Instance.new("Frame")
	menu.Name = "MainPage"
	menu.BackgroundTransparency = 1
	menu.Size = UDim2.fromScale(1, 1)
	menu.Parent = ui.frame
	local M = L.menu
	local mainBtn = UiKit.button({ parent = menu, kind = "primary", name = "MenuContinue", text = "", sub = "", textSize = "mainButton", onActivated = function()
		self.onMain()
	end })
	local classBtn = UiKit.button({ parent = menu, kind = "secondary", name = "MenuClasses", text = Text.get("menu.classSelect"), onActivated = function()
		self.onClasses()
	end })
	local browseNote = UiKit.label(classBtn.face, "", "cardInfo", "text.secondary", { name = "BrowseNote", align = Enum.TextXAlignment.Right })
	browseNote.Size = UDim2.fromScale(1, 1)
	local settingsBtn = UiKit.button({ parent = menu, kind = "secondary", name = "MenuSettings", text = Text.get("menu.settings"), align = phone and Enum.TextXAlignment.Center or nil, onActivated = function()
		deps.showOldPage("SettingsPage")
	end })
	local newsBtn = UiKit.button({ parent = menu, kind = "secondary", name = "MenuNews", text = Text.get("menu.news"), align = phone and Enum.TextXAlignment.Center or nil, onActivated = function()
		deps.showOldPage("NewsPage")
	end })
	table.insert(texts, function()
		title.Text = gameName()
		titleSub.Text = Text.get("menu.v2.titleSub")
		classBtn.setText(Text.get("menu.classSelect"))
		settingsBtn.setText(Text.get("menu.settings"))
		newsBtn.setText(Text.get("menu.news"))
	end)

	local function hasChar()
		local id = player:GetAttribute("ClassId")
		return type(id) == "string" and id ~= ""
	end
	local function countChars()
		local d = self.list
		local n = 0
		for i = 1, d and d.slotCount or 0 do
			if d.slots[i] then
				n += 1
			end
		end
		return n, d and d.slotCount or 0
	end

	-- 배치(접힘 / 펼침) - 좌표 = 표
	local function placeMenu()
		local ex = self.expanded and not phone
		local w = ex and M.widthExpanded or M.width
		local mainY, mainH = ex and M.main.yExpanded or M.main.y, ex and M.main.hExpanded or M.main.h
		UiKit.place(mainBtn.root, { M.x, mainY, w, mainH })
		local y = mainY + mainH + M.items.gap
		local itemH = ex and M.items.hExpanded or M.items.h
		local gap = ex and M.items.gapExpanded or M.items.gap
		local n = countChars()
		classBtn.root.Visible = hasChar() or n > 0 -- 01: 캐릭터 0개 = [직업 선택] 숨김([시작하기]와 같은 곳)
		if classBtn.root.Visible then
			UiKit.place(classBtn.root, { M.x, y, w, itemH })
			y += itemH + gap
		end
		if M.items.pairLast then -- 폰: 설정 · 소식 한 줄
			local half = math.floor((w - gap) / 2)
			UiKit.place(settingsBtn.root, { M.x, y, half, itemH })
			UiKit.place(newsBtn.root, { M.x + half + gap, y, w - half - gap, itemH })
		else
			UiKit.place(settingsBtn.root, { M.x, y, w, itemH })
			UiKit.place(newsBtn.root, { M.x, y + itemH + gap, w, itemH })
		end
		UiKit.place(title, ex and L.titleExpanded or L.title)
		UiKit.place(titleSub, ex and L.titleSubExpanded or L.titleSub)
		title.TextSize = UiKit.size(ex and "titleExpanded" or "title")
		local bs = ex and "buttonExpanded" or "button"
		for _, b in ipairs({ classBtn, settingsBtn, newsBtn }) do
			b.title.TextSize = UiKit.size(bs)
		end
	end

	local function refreshMain()
		local n, total = countChars()
		if hasChar() or n > 0 then
			local s = self.list and self.list.slots and self.list.lastSlot and self.list.slots[self.list.lastSlot]
			local sub = s and Text.get("menu.continueSub", { class = className(s.classId), level = tostring(s.level or 1), stage = commas(s.best or s.stage or 1) })
				or Text.get("menu.continueSub", { class = className(player:GetAttribute("ClassId")), level = tostring(player:GetAttribute("CharacterLevel") or 1), stage = commas(player:GetAttribute("InfiniteStage") or 1) })
			mainBtn.setText(Text.get("menu.continue"), sub)
			mainBtn.sub.Visible = true
			mainBtn.title.Size = UDim2.new(1, 0, 0.58, 0)
			mainBtn.title.TextYAlignment = Enum.TextYAlignment.Bottom
		else
			mainBtn.setText(Text.get("menu.start"), "")
			mainBtn.sub.Visible = false -- 01: 캐릭터 0개 = 부제 없음
			mainBtn.title.Size = UDim2.fromScale(1, 1)
			mainBtn.title.TextYAlignment = Enum.TextYAlignment.Center
		end
		browseNote.Text = (total > 0 and n >= total) and Text.get("menu.v2.browseNote") or ""
		placeMenu()
	end

	-- ── 첫 실행 설정 문구(1회 - 설정 menuLoreSeen) ──
	local function showLore()
		if player:GetAttribute("MenuLoreSeen") == true then
			return
		end
		deps.settingSave("menuLoreSeen", true)
		local holder
		if phone then -- 전체 덮개 · 아무 데나 탭 = 바로
			holder = Instance.new("TextButton")
			holder.AutoButtonColor = false
			holder.Text = ""
			holder.BackgroundColor3 = UiKit.color("bg.deep")
			holder.BackgroundTransparency = 0.15
		else
			holder = Instance.new("Frame")
			holder.BackgroundTransparency = 1
		end
		holder.Name = "Lore"
		holder.ZIndex = 40
		UiKit.place(holder, L.lore)
		local l = UiKit.label(holder, Text.get("menu.v2.lore"), "lore", "lore.text", { name = "LoreText", wrap = true, font = "korean" })
		l.ZIndex = 41
		if phone then
			l.Position = UDim2.fromScale(0.18, 0.25)
			l.Size = UDim2.fromScale(0.64, 0.5)
			l.TextXAlignment = Enum.TextXAlignment.Center
		else
			l.Size = UDim2.fromScale(1, 1)
		end
		holder.Parent = ui.frame
		local gone = false
		local function fade()
			if gone then
				return
			end
			gone = true
			local info = TweenInfo.new(0.5)
			TweenService:Create(l, info, { TextTransparency = 1 }):Play()
			if holder:IsA("TextButton") then
				TweenService:Create(holder, info, { BackgroundTransparency = 1 }):Play()
			end
			task.delay(0.55, function()
				holder:Destroy()
			end)
		end
		if phone then
			holder.Activated:Connect(fade)
		else
			task.delay(3, fade)
		end
	end

	-- ── 서버 칸 목록 ──
	local function call(action, arg)
		if not deps.slotRemote then
			return nil
		end
		local ok, res = pcall(function()
			return deps.slotRemote:InvokeServer(action, arg)
		end)
		return ok and res or nil
	end
	local function errText(reason)
		reason = type(reason) == "string" and reason:match("^[%w_]+") or reason
		return Text.get(SlotSaveData.errorReasons[reason] and ("menu.slot.err." .. reason) or "menu.slot.err.default")
	end
	local function loadList()
		local d = call("list")
		self.list = (d and d.enabled ~= false and d.slots) and d or nil
		return self.list
	end

	-- ── 이어하기 창 ──
	local win = UiKit.window({ parent = ui.frame, rect = L.slotWindow, title = Text.get("menu.continue"), sub = "", name = "SlotWindow", titleX = phone and 56 or 24 })
	win.root.Visible = false
	win.root.ZIndex = 10
	win.title.AutomaticSize = Enum.AutomaticSize.X
	win.title.TextTruncate = Enum.TextTruncate.None
	win.title.Size = UDim2.new(0, 0, 1, 0)
	if win.sub then
		win.sub.AnchorPoint = Vector2.new(0, 0)
		win.sub.Position = UDim2.new(0, 0, 0, 0)
	end
	local headRow = Instance.new("UIListLayout") -- 제목 + "1 / 4칸"
	headRow.FillDirection = Enum.FillDirection.Horizontal
	headRow.VerticalAlignment = Enum.VerticalAlignment.Center
	headRow.Padding = UDim.new(0, 12)
	headRow.SortOrder = Enum.SortOrder.LayoutOrder
	local headBox = Instance.new("Frame")
	headBox.Name = "HeadText"
	headBox.BackgroundTransparency = 1
	headBox.Position = UDim2.fromOffset(phone and 56 or 24, 0)
	headBox.Size = UDim2.new(1, -(phone and 140 or 100), 1, 0)
	headBox.Parent = win.head
	headRow.Parent = headBox
	win.title.Parent = headBox
	win.title.Position = UDim2.new()
	win.title.LayoutOrder = 1
	if win.sub then
		win.sub.Parent = headBox
		win.sub.AutomaticSize = Enum.AutomaticSize.X
		win.sub.TextTruncate = Enum.TextTruncate.None
		win.sub.Size = UDim2.new(0, 0, 1, 0)
		win.sub.LayoutOrder = 2
	end
	local closeBtn = UiKit.closeButton({ parent = win.root, rect = L.slotClose, name = "Close", icon = phone and "back" or "close", colorToken = phone and "panel.slot" or "warning", onActivated = function()
		self.closeSlots()
	end })
	closeBtn.ZIndex = 12
	local listFrame = Instance.new("ScrollingFrame")
	listFrame.Name = "Cards"
	listFrame.BackgroundTransparency = 1
	listFrame.BorderSizePixel = 0
	listFrame.ScrollBarThickness = 4
	listFrame.CanvasSize = UDim2.new()
	listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	local SL = L.slotList
	local footerTop = phone and 0 or L.slotArchive[2] - 14
	local LIST_PAD = 6 -- 선택 카드 테두리(3)가 스크롤 틀에 잘리지 않게
	listFrame.Position = UDim2.fromOffset(0, SL.y - LIST_PAD)
	listFrame.Size = UDim2.new(1, 0, 0, (phone and L.slotWindow[4] or footerTop) - SL.y - 4 + LIST_PAD)
	listFrame.Parent = win.root
	local archiveBtn = UiKit.button({ parent = win.root, kind = "secondary", name = "StorageButton", rect = L.slotArchive, text = "", textSize = "cardInfo", padX = 10, onActivated = function()
		self.storage = not self.storage
		self.renderSlots()
	end })
	UiKit.icon(archiveBtn.face, "archive", phone and 16 or 20).Position = UDim2.fromOffset(-2, phone and 12 or 12)
	archiveBtn.title.Position = UDim2.fromOffset(phone and 14 or 24, 0)
	local footer = nil
	if not phone then
		local line = Instance.new("Frame")
		line.Name = "FooterLine"
		line.BackgroundColor3 = UiKit.color("panel.section")
		line.BorderSizePixel = 0
		line.Position = UDim2.fromOffset(0, footerTop)
		line.Size = UDim2.new(1, 0, 0, 2)
		line.Parent = win.root
		footer = UiKit.label(win.root, Text.get("menu.v2.slotRule"), "caption", "text.muted", { name = "FooterNote", wrap = true, rect = L.slotFooterNote })
	end
	local status = UiKit.label(win.root, "", "caption", "text.secondary", { name = "Status", align = Enum.TextXAlignment.Center })
	status.Position = UDim2.new(0, 0, 1, phone and -2 or -(L.slotWindow[4] - footerTop) - 26)
	status.Size = UDim2.new(1, 0, 0, 22)
	status.AnchorPoint = Vector2.new(0, phone and 1 or 0)

	local function setStatus(text, warn)
		status.Text = text or ""
		status.TextColor3 = UiKit.color(warn and "warning" or "text.secondary")
	end

	local function clearList()
		for _, c in ipairs(listFrame:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
	end

	local function charLabel(row)
		local name = className(row.summary.classId)
		if row.number then
			name = Text.get("menu.slot.name", { class = name, number = SlotSaveData.numberGlyphs[row.number] or tostring(row.number) })
		end
		return name
	end

	local function askArchive(row)
		UiKit.confirm({
			parent = ui.frame, rect = L.confirm, title = Text.get("menu.v2.archiveTitle"),
			body = Text.get("menu.v2.archiveBody", { name = charLabel(row) }), sub = Text.get("menu.v2.archiveSub"),
			cancelText = Text.get("menu.slot.cancel"), okText = Text.get("menu.slot.archive"), okKind = "secondary",
			cancelRect = L.confirmCancel, okRect = L.confirmOk, focus = "cancel", name = "ArchiveConfirm",
			onAnswer = function(yes)
				if not yes then
					return
				end
				local res = call("archive", row.slot)
				if res and res.ok then
					self.refreshSlots()
				else
					setStatus(errText(res and res.reason), true)
				end
			end,
		})
	end

	local function play(slot)
		if self.busy then
			return
		end
		self.busy = true
		setStatus(Text.get("menu.slot.loading"))
		local ok, res = pcall(function()
			return deps.slotRemote:InvokeServer("play", slot)
		end)
		self.busy = false
		if ok and res and res.ok then
			deps.enter("continue")
		else
			setStatus(errText(ok and res and res.reason), true)
		end
	end

	local function cardRow(row, y, h, selected)
		local s = row.summary
		local c = UiKit.card(listFrame, { SL.x, y, SL.w, h }, selected, "Slot" .. row.slot)
		c.root:SetAttribute("CharId", s.charId)
		face(c.root, L.slotFace, s.classId)
		local x0 = L.slotFace[1] + L.slotFace[3] + (phone and 10 or 16)
		local infoW = L.slotWeapon[1] - x0 - 8
		local nameRow = Instance.new("Frame")
		nameRow.Name = "NameRow"
		nameRow.BackgroundTransparency = 1
		nameRow.Position = UDim2.fromOffset(x0, phone and 8 or 14)
		nameRow.Size = UDim2.fromOffset(infoW, phone and 20 or 30)
		nameRow.Parent = c.root
		local nl = Instance.new("UIListLayout")
		nl.FillDirection = Enum.FillDirection.Horizontal
		nl.VerticalAlignment = Enum.VerticalAlignment.Center
		nl.Padding = UDim.new(0, 8)
		nl.Parent = nameRow
		local n = UiKit.label(nameRow, charLabel(row), "cardName", "text.primary", { name = "Name", font = "korean" })
		n.AutomaticSize = Enum.AutomaticSize.X
		n.TextTruncate = Enum.TextTruncate.None
		n.Size = UDim2.new(0, 0, 1, 0)
		n.LayoutOrder = 1
		nl.SortOrder = Enum.SortOrder.LayoutOrder
		if self.list and self.list.lastSlot == row.slot then
			local badge = UiKit.label(nameRow, Text.get("menu.v2.lastPlayed"), "caption", "text.secondary", { name = "LastBadge", align = Enum.TextXAlignment.Center })
			badge.BackgroundTransparency = 0
			badge.BackgroundColor3 = UiKit.color("panel.slot")
			badge.AutomaticSize = Enum.AutomaticSize.X
			badge.TextTruncate = Enum.TextTruncate.None
			badge.Size = UDim2.new(0, 0, 0.8, 0)
			badge.LayoutOrder = 2
			UiKit.corner(badge, Tokens.corner.chip)
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
			pad.Parent = badge
		end
		local lh = phone and 16 or 26
		local line1 = UiKit.label(c.root, Text.get("menu.v2.cardLine1", { level = tostring(s.level or 1), best = commas(s.best or 1) }), "cardInfo", "text.primary", { name = "Line1", font = "number" })
		UiKit.place(line1, { x0, (phone and 30 or 48), infoW, lh })
		local hours = math.floor((tonumber(s.playSeconds) or 0) / 3600)
		local line2 = UiKit.label(c.root, Text.get("menu.v2.cardLine2", { rebirth = tostring(s.rebirth or 0), hours = tostring(hours), ago = agoText(s.lastPlayedAt) }), "cardInfo", "text.secondary", { name = "Line2" })
		UiKit.place(line2, { x0, (phone and 48 or 76), infoW, lh })
		if selected and self.armed == row.slot then
			local hint = Instance.new("Frame")
			hint.Name = "TapAgain"
			hint.BackgroundTransparency = 1
			UiKit.place(hint, { x0, phone and 68 or 104, infoW, phone and 22 or 30 })
			hint.Parent = c.root
			local hl = Instance.new("UIListLayout")
			hl.FillDirection = Enum.FillDirection.Horizontal
			hl.VerticalAlignment = Enum.VerticalAlignment.Center
			hl.Padding = UDim.new(0, 6)
			hl.Parent = hint
			UiKit.icon(hint, "play", phone and 14 or 20)
			local ht = UiKit.label(hint, Text.get("menu.slot.tapAgain"), "cardInfo", "accent", { name = "Text", font = "korean" })
			ht.AutomaticSize = Enum.AutomaticSize.X
			ht.TextTruncate = Enum.TextTruncate.None
			ht.Size = UDim2.new(0, 0, 1, 0)
		end
		UiKit.iconSlot({ parent = c.root, rect = L.slotWeapon, gradeId = UiModel.gradeId(s.weaponGrade), level = s.weaponLevel, transcendLevel = s.transcend, iconKey = UiModel.weaponIconKey(s.classId, s.weaponGrade), name = "Weapon" })
		local more = Instance.new("TextButton")
		more.Name = "More"
		more.AutoButtonColor = false
		more.Text = ""
		more.BackgroundColor3 = UiKit.color("panel.slot")
		UiKit.place(more, L.slotMore)
		UiKit.corner(more, Tokens.corner.chip)
		UiKit.icon(more, "more", phone and 20 or 24, { center = true })
		more.Parent = c.root
		more.Activated:Connect(function()
			askArchive(row)
		end)
		c.root.Activated:Connect(function()
			if self.busy then
				return
			end
			if self.armed == row.slot then -- 같은 카드 두 번 = 시작(미리 선택만으로는 시작 안 함 - 10-05 버그 지시)
				play(row.slot)
				return
			end
			self.selected, self.armed = row.slot, row.slot
			setStatus("")
			self.renderSlots()
		end)
	end

	local function storageRows()
		local arch = self.list and self.list.archive or {}
		local y = LIST_PAD
		if #arch == 0 then
			local l = UiKit.label(listFrame, Text.get("menu.slot.storageEmpty"), "cardInfo", "text.secondary", { name = "Empty", align = Enum.TextXAlignment.Center })
			UiKit.place(l, { SL.x, 8, SL.w, 40 })
			return
		end
		for i, s in ipairs(arch) do
			local h = SL.emptyH
			local c = UiKit.card(listFrame, { SL.x, y, SL.w, h }, false, "Archived" .. i)
			face(c.root, { 10, math.floor((h - (phone and 36 or 64)) / 2), phone and 36 or 64, phone and 36 or 64 }, s.classId)
			local n = UiKit.label(c.root, className(s.classId) .. "  Lv." .. tostring(s.level or 1), "cardName", "text.primary", { name = "Name", font = "korean" })
			UiKit.place(n, { phone and 56 or 90, 0, SL.w - (phone and 160 or 260), h })
			UiKit.button({ parent = c.root, kind = "secondary", name = "Restore", rect = { SL.w - (phone and 100 or 150), math.floor((h - 48) / 2), phone and 90 or 136, 48 }, text = Text.get("menu.slot.restore"), align = Enum.TextXAlignment.Center, textSize = "cardInfo", padX = 6,
				onActivated = function()
					local res = call("restore", i)
					if res and res.ok then
						self.storage = false
						self.refreshSlots()
					else
						setStatus(errText(res and res.reason), true)
					end
				end })
			y += h + SL.gap
		end
	end

	function self.renderSlots()
		clearList()
		local d = self.list
		if not d then
			return
		end
		local n = countChars()
		if win.sub then
			win.sub.Text = Text.get("menu.v2.slotCount", { n = tostring(n), max = tostring(d.slotCount or 0) })
		end
		archiveBtn.setText(self.storage and Text.get("menu.back") or Text.get("menu.v2.storage", { n = tostring(#(d.archive or {})) }))
		win.title.Text = self.storage and Text.get("menu.v2.storageTitle") or Text.get("menu.continue")
		if self.storage then
			storageRows()
			return
		end
		local rows = UiModel.slotRows(d.slots, d.slotCount or 0, d.lockedPreview or 0)
		local y = LIST_PAD
		for _, row in ipairs(rows) do
			if row.kind == "card" then
				local sel = self.selected == row.slot
				local h = sel and SL.selectedH or SL.cardH
				cardRow(row, y, h, sel)
				y += h + SL.gap
			elseif row.kind == "empty" then
				local e = UiKit.emptySlot(listFrame, { SL.x, y, SL.w, SL.emptyH }, Text.get("menu.v2.newChar"), Text.get("menu.v2.newCharSub"), "NewCharacter")
				e.Activated:Connect(function()
					self.openClasses("new")
				end)
				y += SL.emptyH + SL.gap
			else
				UiKit.lockedSlot(listFrame, { SL.x, y, SL.w, SL.lockedH }, Text.get("menu.slot.locked"), "Locked")
				y += SL.lockedH + SL.gap
			end
		end
	end

	function self.refreshSlots()
		if not loadList() then
			return false
		end
		local d = self.list
		if not (self.selected and d.slots[self.selected]) then
			self.selected = d.lastSlot and d.slots[d.lastSlot] and d.lastSlot or nil
			if not self.selected then
				local rows = UiModel.slotRows(d.slots, d.slotCount or 0, 0)
				self.selected = rows[1] and rows[1].kind == "card" and rows[1].slot or nil
			end
		end
		self.renderSlots()
		refreshMain()
		return true
	end

	function self.openSlots()
		if not self.refreshSlots() then
			return false
		end
		self.mode = "slots"
		self.armed = nil
		self.storage = false
		setStatus("")
		self.renderSlots()
		self.expanded = true
		menu.Visible = not phone -- 폰 = 메뉴 숨김 → 같은 자리에 창
		title.Visible, titleSub.Visible = not phone, not phone
		placeMenu()
		win.root.Visible = true
		local target = UDim2.fromOffset(L.slotWindow[1], L.slotWindow[2])
		win.root.Position = UDim2.fromOffset(L.slotWindow[1] - L.slotWindowSlide, L.slotWindow[2])
		TweenService:Create(win.root, TweenInfo.new(Tokens.tweenSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = target }):Play()
		return true
	end

	function self.closeSlots()
		win.root.Visible = false
		self.expanded = false
		self.selected, self.armed = nil, nil
		listFrame.CanvasPosition = Vector2.zero
		menu.Visible = true
		title.Visible, titleSub.Visible = true, true
		self.mode = "main"
		placeMenu()
	end

	-- ── 직업 선택(새 캐릭터 · 구경) ──
	local cls = Instance.new("Frame")
	cls.Name = "ClassSelectV2"
	cls.BackgroundTransparency = 1
	cls.Size = UDim2.fromScale(1, 1)
	cls.Visible = false
	cls.ZIndex = 20
	cls.Parent = ui.frame
	local clsDim = Instance.new("Frame") -- 키 아트를 한 단 어둡게(목업 pc_06)
	clsDim.Name = "Dim"
	clsDim.BackgroundColor3 = UiKit.color("bg.deep")
	clsDim.BackgroundTransparency = 0.45
	clsDim.BorderSizePixel = 0
	clsDim.Size = UDim2.fromScale(4, 1)
	clsDim.Parent = cls
	local band = UiKit.band(cls, L.browseBand, Text.get("menu.v2.browseBand"))
	local clsTitle = UiKit.label(cls, Text.get("menu.classSelect"), "windowTitle", "text.primary", { name = "ClassTitle", font = "korean" })
	clsTitle.TextSize = math.floor(UiKit.size("title") * (phone and 0.6 or 0.5))
	clsTitle.AutomaticSize = Enum.AutomaticSize.X
	clsTitle.TextTruncate = Enum.TextTruncate.None
	UiKit.place(clsTitle, { L.classBack[1] + L.classBack[3] + 16, L.classBack[2], 0, L.classBack[4] })
	clsTitle.Visible = not phone
	local clsSub = UiKit.label(cls, "", "cardInfo", "text.secondary", { name = "ClassSub" })
	clsSub.AutomaticSize = Enum.AutomaticSize.X
	clsSub.TextTruncate = Enum.TextTruncate.None
	clsSub.Visible = not phone
	local backBtn = UiKit.button({ parent = cls, kind = "secondary", name = "Back", rect = L.classBack, text = phone and "" or Text.get("menu.v2.back"), textSize = "cardInfo", padX = phone and 0 or 14, onActivated = function()
		self.closeClasses()
	end })
	UiKit.icon(backBtn.face, "back", phone and 18 or 20).Position = UDim2.fromOffset(phone and 13 or -6, phone and 11 or 12)
	if not phone then
		backBtn.title.Position = UDim2.fromOffset(18, 0)
	end
	local artHolder = Instance.new("Frame")
	artHolder.Name = "Legend"
	artHolder.BackgroundTransparency = 1
	artHolder.Parent = cls
	local artImg = Instance.new("ImageLabel")
	artImg.Name = "LegendImage"
	artImg.BackgroundTransparency = 1
	artImg.ScaleType = Enum.ScaleType.Fit
	artImg.Size = UDim2.fromScale(1, 1)
	artImg.Parent = artHolder
	local silhouette = Instance.new("Frame") -- 임시 실루엣(그림 없는 직업)
	silhouette.Name = "Silhouette"
	silhouette.BackgroundColor3 = UiKit.color("bg.deep")
	silhouette.BackgroundTransparency = 0.2
	silhouette.Size = UDim2.fromScale(1, 1)
	silhouette.Parent = artHolder
	UiKit.corner(silhouette, 400)
	local silText = UiKit.label(silhouette, "", "windowTitle", "text.muted", { name = "Temp", align = Enum.TextXAlignment.Center })
	silText.Size = UDim2.fromScale(1, 1)
	local infoWin = nil
	local startBtn = UiKit.button({ parent = cls, kind = "primary", name = "StartClass", rect = L.classStart, text = "", textSize = "mainButton", align = Enum.TextXAlignment.Center, onActivated = function()
		self.startClass()
	end })
	local startNote = UiKit.label(cls, "", "caption", "text.secondary", { name = "StartNote", wrap = true })
	UiKit.place(startNote, { L.classStart[1], L.classStart[2] - (phone and 0 or 56), L.classStart[3], phone and 0 or 50 })
	startNote.Visible = not phone
	local startLock = UiKit.icon(startBtn.face, "lock", phone and 18 or 24)
	startLock.Position = UDim2.fromOffset(phone and 8 or 20, phone and 14 or 20)
	local classCards = {}
	local CL = L.classList
	for i, info in ipairs(UiModel.classList()) do
		local c = UiKit.card(cls, { CL.x, CL.y + (i - 1) * (CL.h + CL.gap), CL.w, CL.h }, false, "Class_" .. info.id)
		local accent = Instance.new("Frame")
		accent.Name = "Accent"
		accent.BackgroundColor3 = UIColors.classAccent[info.id] or UiKit.color("accent")
		accent.BorderSizePixel = 0
		accent.Position = UDim2.fromOffset(8, 10)
		accent.Size = UDim2.new(0, phone and 4 or 6, 1, -20)
		accent.Parent = c.root
		UiKit.corner(accent, 3)
		local fx = phone and 14 or 24
		if not phone then -- 카드 얼굴(목업 pc_06 · 그림 없으면 직업 색 + 첫 글자)
			face(c.root, { 16, 14, 76, 76 }, info.id)
			fx = 108
		end
		local nameRow = Instance.new("Frame") -- 이름 + "그림 곧 공개" 칩(가로 줄)
		nameRow.Name = "NameRow"
		nameRow.BackgroundTransparency = 1
		UiKit.place(nameRow, { fx, phone and 4 or 22, CL.w - fx - 8, phone and 24 or 34 })
		nameRow.Parent = c.root
		local rowList = Instance.new("UIListLayout")
		rowList.FillDirection = Enum.FillDirection.Horizontal
		rowList.VerticalAlignment = Enum.VerticalAlignment.Center
		rowList.SortOrder = Enum.SortOrder.LayoutOrder
		rowList.Padding = UDim.new(0, 8)
		rowList.Parent = nameRow
		local n = UiKit.label(nameRow, className(info.id), "cardName", "text.primary", { name = "Name", font = "korean" })
		n.AutomaticSize = Enum.AutomaticSize.X
		n.TextTruncate = Enum.TextTruncate.None
		n.Size = UDim2.new(0, 0, 1, 0)
		n.LayoutOrder = 1
		if info.temp then
			local chip = UiKit.label(nameRow, Text.get("menu.v2.temp"), "caption", "text.secondary", { name = "TempChip", align = Enum.TextXAlignment.Center })
			chip.LayoutOrder = 2
			chip.BackgroundTransparency = 0
			chip.BackgroundColor3 = UiKit.color("panel.slot")
			chip.AutomaticSize = Enum.AutomaticSize.X
			chip.TextTruncate = Enum.TextTruncate.None
			UiKit.corner(chip, Tokens.corner.chip)
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 6), UDim.new(0, 6)
			pad.Parent = chip
			chip.Size = UDim2.new(0, 0, 0, phone and 18 or 22)
		end
		local r = UiKit.label(c.root, Text.get("class.role." .. info.role), "cardInfo", "text.secondary", { name = "Role" })
		UiKit.place(r, { fx, phone and 26 or 58, CL.w - fx - 12, phone and 20 or 28 })
		c.root.Activated:Connect(function()
			self.pickClass(info.id)
		end)
		classCards[info.id] = c
	end

	local function tendencyRows(parent, info, y0)
		local bh = phone and 10 or 14
		for i, t in ipairs(info.tendency) do
			local y = y0 + (i - 1) * (phone and 18 or 28)
			local l = UiKit.label(parent, Text.get("class.tend." .. t.key), "cardInfo", "text.secondary", { name = "Tend_" .. t.key })
			UiKit.place(l, { phone and 12 or 24, y, phone and 40 or 70, bh + 8 })
			for b = 1, Tokens.tendencyBlocks do
				local f = Instance.new("Frame")
				f.Name = "Block" .. b
				f.BackgroundColor3 = UiKit.color(b <= t.value and "info" or "panel.slot")
				f.BorderSizePixel = 0
				local bw = phone and 26 or 52
				UiKit.place(f, { (phone and 56 or 100) + (b - 1) * (bw + 4), y + 4, bw, bh })
				UiKit.corner(f, 3)
				f.Parent = parent
			end
			if not phone then
				local word = UiKit.label(parent, Text.get("menu.v2.tend." .. tostring(t.value)), "caption", "text.secondary", { name = "TendWord_" .. t.key })
				UiKit.place(word, { 100 + Tokens.tendencyBlocks * 56 + 8, y, 90, bh + 8 })
			end
		end
	end

	function self.pickClass(id)
		self.pickedClass = id
		for cid, c in pairs(classCards) do
			c.setSelected(cid == id)
		end
		local info = UiModel.classInfo(id)
		local img = image(info.legend)
		artImg.Image = img or ""
		artImg.Visible = img ~= nil
		silhouette.Visible = img == nil
		silText.Text = Text.get("menu.v2.temp")
		UiKit.place(artHolder, img and L.classArt or L.classArtSilhouette)
		if infoWin then
			infoWin.root:Destroy()
		end
		local rect = table.clone(self.classMode == "browse" and L.classInfoBrowse or L.classInfo)
		infoWin = UiKit.window({ parent = cls, rect = rect, title = className(id), name = "ClassInfo" })
		local body = infoWin.body
		local px = phone and 12 or 24
		local y = phone and 6 or 14
		local stars = string.rep("★", info.difficulty) .. string.rep("☆", 3 - info.difficulty)
		local diff = UiKit.label(body, Text.get("menu.v2.difficulty", { stars = stars, word = Text.get("menu.v2.diff." .. tostring(info.difficulty)) }) .. "   " .. Text.get("class.role." .. info.role), "cardInfo", "text.secondary", { name = "Difficulty" })
		UiKit.place(diff, { px, y, rect[3] - px * 2, phone and 18 or 28 })
		y += phone and 20 or 40
		if not phone then
			local head = UiKit.label(body, Text.get("menu.v2.skillsHead"), "cardInfo", "text.secondary", { name = "SkillsHead" })
			UiKit.place(head, { px, y, 200, 24 })
			y += 30
		end
		for _, k in ipairs({ "q", "e", "ult" }) do
			local name = info.skills[k]
			if name then
				if not phone then
					local box = Instance.new("Frame")
					box.Name = "SkillBox_" .. k
					box.BackgroundColor3 = UiKit.color("panel.slot")
					UiKit.place(box, { px, y, 40, 40 })
					UiKit.corner(box, Tokens.corner.chip)
					UiKit.stroke(box, k == "ult" and "accent" or "line", 2)
					box.Parent = body
				end
				local sl = UiKit.label(body, phone and Text.get("menu.v2.skill." .. k, { name = Text.name(name) }) or Text.name(name), phone and "cardInfo" or "cardName", "text.primary", { name = "Skill_" .. k, font = "korean" })
				sl.AutomaticSize = Enum.AutomaticSize.X
				sl.TextTruncate = Enum.TextTruncate.None
				UiKit.place(sl, { phone and px or px + 52, y, 0, phone and 18 or 40 })
				if k == "ult" and not phone then
					local ub = UiKit.label(body, Text.get("menu.v2.ult"), "caption", "accent.text", { name = "UltBadge", align = Enum.TextXAlignment.Center })
					ub.BackgroundTransparency = 0
					ub.BackgroundColor3 = UiKit.color("accent")
					ub.AutomaticSize = Enum.AutomaticSize.X
					ub.TextTruncate = Enum.TextTruncate.None
					UiKit.corner(ub, Tokens.corner.chip)
					local pad = Instance.new("UIPadding")
					pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 6), UDim.new(0, 6)
					pad.Parent = ub
					local yy = y
					task.defer(function()
						UiKit.place(ub, { px + 52 + sl.AbsoluteSize.X / math.max(ui.scale.Scale, 0.01) + 10, yy + 9, 0, 22 })
					end)
				end
				y += phone and 18 or 44
			end
		end
		y += phone and 4 or 8
		if not phone then
			local th = UiKit.label(body, Text.get("menu.v2.tendHead"), "cardInfo", "text.secondary", { name = "TendHead" })
			UiKit.place(th, { px, y, 200, 24 })
			y += 30
		end
		tendencyRows(body, info, y)
		self.renderStart()
	end

	function self.renderStart()
		local id = self.pickedClass
		if not id then
			return
		end
		local name = className(id)
		startBtn.setText(Text.get("menu.v2.startAs", { name = Text.languageFor(nil) == "ko" and (name .. UiModel.josaRo(name)) or name })) -- 받침 있으면 "으로"
		local browse = self.classMode == "browse"
		startBtn.setEnabled(not browse)
		startLock.Visible = browse
		startNote.Text = browse and "" or Text.get("menu.v2.startNote", { name = name })
		local n, total = countChars()
		clsSub.Text = browse and Text.get("menu.v2.classSubBrowse") or Text.get("menu.v2.classSubNew", { n = tostring(math.max(0, total - n)) })
		task.defer(function()
			UiKit.place(clsSub, { L.classBack[1] + L.classBack[3] + 32 + clsTitle.AbsoluteSize.X / math.max(ui.scale.Scale, 0.01), L.classBack[2] + 4, 0, L.classBack[4] })
		end)
	end

	function self.openClasses(mode)
		self.classMode = mode
		band.root.Visible = mode == "browse"
		UiKit.place(backBtn.root, mode == "browse" and L.classBackBrowse or L.classBack)
		win.root.Visible = false
		menu.Visible = false
		title.Visible, titleSub.Visible = false, false
		cls.Visible = true
		self.mode = "classes"
		self.pickClass(self.pickedClass or UiModel.classList()[1].id)
	end

	function self.closeClasses()
		cls.Visible = false
		self.closeSlots()
	end

	function self.startClass()
		if self.classMode == "browse" or self.busy or not self.pickedClass then
			return
		end
		self.busy = true
		local id = self.pickedClass
		local ok = true
		if deps.slotRemote then -- 새 캐릭터 칸(캐릭터 없음으로 전환 - 이미 캐릭터 없는 새 계정이면 그대로)
			local hasNow = hasChar()
			if hasNow then
				local okCall, res = pcall(function()
					return deps.slotRemote:InvokeServer("new")
				end)
				ok = okCall and res and res.ok
				if not ok then
					self.busy = false
					setStatus(errText(okCall and res and res.reason), true)
					self.closeClasses()
					self.openSlots()
					return
				end
			end
		end
		deps.classSelectRequest:FireServer(id)
		local t0 = os.clock()
		while player:GetAttribute("ClassId") ~= id and os.clock() - t0 < 5 do
			task.wait(0.05)
		end
		self.busy = false
		deps.enter("continue")
	end

	-- ── 메인 버튼 동작 ──
	function self.onMain()
		loadList()
		if countChars() == 0 and not hasChar() then
			self.openClasses("new") -- 01: 캐릭터 0개 = 이어하기 창 없이 바로 직업 선택
			return
		end
		if not self.openSlots() then
			deps.enter("continue") -- 칸 저장 끔 = 옛 동작
		end
	end
	function self.onClasses()
		loadList()
		local n, total = countChars()
		self.openClasses((total > 0 and n >= total) and "browse" or "new")
	end

	function self.show()
		ui.frame.Visible = true
		loadList()
		self.closeSlots()
		cls.Visible = false
		refreshMain()
		showLore()
	end
	function self.hide()
		ui.frame.Visible = false
	end
	function self.isMainVisible()
		return ui.frame.Visible and self.mode == "main"
	end
	function self.onEnterKey()
		if self.isMainVisible() then
			self.onMain()
		end
	end
	function self.refreshTexts()
		for _, f in ipairs(texts) do
			f()
		end
		refreshMain()
	end
	for _, attr in ipairs({ "ClassId", "CharacterLevel", "InfiniteStage" }) do
		player:GetAttributeChangedSignal(attr):Connect(function()
			if ui.frame.Visible and self.mode == "main" then
				refreshMain()
			end
		end)
	end
	self.frame = ui.frame
	ui.frame.Visible = false
	placeMenu()
	return self
end

return MainMenuV2
