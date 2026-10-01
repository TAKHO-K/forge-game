-- 왼쪽 메뉴(QUEUE-ALL2 P2 - docs/art/ref/16_ui_hud.png · 09 문서 A · B-3 · B-4). 옛 S16 메뉴바(세로 1열 · 5칸)를 대신한다.
--   PC = 화면 왼쪽 세로 1줄: PanelRegistry.menuEntries() 7칸(가방 G · 캐릭터 C · 지도 M · 구역 N · 퀘스트 J · 도감 K · 수련 U) + [더보기 …](파티 · 순위 · 설정) + 금색 [상점].
--   폰 = 왼쪽 위 2열 격자: 상시 3칸(menuPinned - 가방 · 캐릭터 · 지도) + [더보기](나머지 전부) + [상점] - BL 터치 예약 구역(0.55H) 위에 들어간다. 키 칩은 숨긴다.
--   버튼 상태 4가지(ref 16 ②): 기본 · 눌림(아래로 4px) · 알림(빨간 점 + 숫자) · 잠김(회색 + 자물쇠 = 지금 못 여는 창 - 이유는 누르면 토스트).
--   폰 길게 누르면(0.45초) 이름 말풍선. 보스전 중(BossEncounterId) = 줄 반투명 + 작게(전조 · 몬스터 가독성 우선 - ref 16 아래 글).
--   누르면 UIManager.openLazy(열려 있으면 닫힘 · 다른 창은 닫고 연다 · 처음 여는 창은 opener 모듈이 짓는다). 단축키는 UIManager가 PanelRegistry 표로 문다.
--   그림 = icons/hud PNG 타일(IconTile - 아트 켬) · 없거나 아트 끔 = 옛 모양(슬롯 바탕 + HudIcons 도형 또는 이름 첫 글자).
--   옛 S16 자체 점검(`[S16][UI]` - 3칸 · 44px 기대값)은 설계 변경으로 기대값이 틀려 지웠다(보고서 "기대값 갱신 필요").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local Text = require(ReplicatedStorage.Shared.Text)
local HudIcons = require(script.Parent.Parent.HudIcons)
local PanelRegistry = require(script.Parent.Parent.ui.PanelRegistry)
local ScreenMap = require(script.Parent.Parent.ui.ScreenMap)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local Toast = require(script.Parent.Parent.ui.kit.Toast)
local UIManager = require(script.Parent.Parent.UIManager)
local IconTile = require(script.Parent.Parent.ui.IconTile)

local player = Players.LocalPlayer
local inventoryFull = ReplicatedStorage:WaitForChild("InventoryFull")

-- PNG 타일 이름(icons/hud/<이름>) - 없는 PNG는 옛 모양으로 대신한다
local ICON_IMAGE = { bag = "bag", character = "character", map = "map", zone_select = "zone_select", quest = "quest", codex = "codex", training = "training",
	party = "party", rank = "rank", settings = "settings", more = "more", shop = "shop" }
local M = ScreenMap.menuBar
local LONG_PRESS = 0.45
local PRESS_DROP = 4
local BOSS_SCALE = 0.72
local BOSS_ALPHA = 0.5
local BADGE_PANEL = "inventory"

local HIDE_CONDITIONS = {
	tutorial = function(who)
		return who:GetAttribute("TutorialCompleted") ~= true and (who:GetAttribute("TutorialStep") or 0) > 0
	end,
	noClass = function(who)
		local classId = who:GetAttribute("ClassId")
		return classId == nil or classId == ""
	end,
}

local function isHidden(entry)
	for _, name in ipairs(entry.menuHiddenWhile or {}) do
		if HIDE_CONDITIONS[name](player) then
			return true
		end
	end
	return false
end

local function inBoss()
	return player:GetAttribute("BossEncounterId") ~= nil
end

local function buttonSize()
	if Theme.isMobile then
		return M.mobileButton
	end
	local camera = workspace.CurrentCamera
	local h = camera and camera.ViewportSize.Y or 800
	return math.clamp(math.floor((h - 220) / 11), M.button, M.pcButtonMax or 60)
end

-- 막힌 이유 토스트(TC 줄 · 같은 글 3초에 한 번)
local lastToast = { text = nil, at = 0 }
local function notifyBlocked(text)
	local now = os.clock()
	if lastToast.text == text and now - lastToast.at < 3 then
		return
	end
	lastToast.text, lastToast.at = text, now
	Toast.push("TC", { text = text, colorName = "textPrimary" })
end

local refs = { items = {}, moreItems = {} }
local morePanelOpen = false
local setMoreOpen -- 아래에서 채운다

local function pressEntry(entry)
	setMoreOpen(false)
	if entry.onPress then
		entry.onPress()
		return
	end
	local ok, text = UIManager.openLazy(entry.id)
	if not ok and text then
		notifyBlocked(text)
	end
end

-- 이름 말풍선(폰 길게 누름 · 첫 접속 8초) - 버튼 오른쪽
local function showName(item, seconds)
	local text = item.entry.menuLabel or item.entry.id
	local old = item.button:FindFirstChild("NameTag")
	if old then
		old:Destroy()
	end
	local width = TextService:GetTextSize(text, Theme.textSize("body"), Theme.font, Vector2.new(400, 100)).X + 20
	local tag = Instance.new("TextLabel")
	tag.Name = "NameTag"
	tag.AnchorPoint = Vector2.new(0, 0.5)
	tag.Position = UDim2.new(1, 8, 0.5, 0)
	tag.Size = UDim2.new(0, width, 0, 30)
	tag.BackgroundColor3 = UIColors.panel
	tag.BackgroundTransparency = UIColors.panelTransparency
	tag.Font = Theme.font
	tag.TextSize = Theme.textSize("body")
	tag.TextColor3 = UIColors.textPrimary
	tag.Text = text
	tag.ZIndex = 20
	tag.Parent = item.button
	Theme.corner(tag, Theme.corner.chip)
	Theme.stroke(tag)
	task.delay(seconds, function()
		tag:Destroy()
	end)
end

-- 알림: n = 0 끔 · 1 = 점 · 2 이상 = 점 + 숫자
local function setAlert(item, n)
	item.alert = n or 0
	local dot = item.button:FindFirstChild("AlertDot")
	if item.alert > 0 and not dot then
		dot = Instance.new("TextLabel")
		dot.Name = "AlertDot"
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.new(1, -4, 0, 4)
		dot.BackgroundColor3 = UIColors.danger
		dot.Font = Theme.font
		dot.TextSize = 12
		dot.TextColor3 = Color3.new(1, 1, 1)
		dot.ZIndex = 12
		dot.Parent = item.button
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = dot
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.new(1, 1, 1)
		stroke.Thickness = 1.5
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = dot
	end
	if dot then
		dot.Visible = item.alert > 0
		dot.Text = item.alert > 1 and tostring(math.min(item.alert, 99)) or ""
		dot.Size = item.alert > 1 and UDim2.fromOffset(20, 20) or UDim2.fromOffset(12, 12)
	end
end

-- 기본 · 열림 · 잠김 모양(잠김 = 지금 전환이 막힘 - 회색 + 자물쇠). 눌림은 입력이 바꾼다.
local function applyLook(item)
	local open = UIManager.isOpen(item.entry.id)
	local blocked = item.entry.id ~= "more" and item.entry.id ~= "shop" and UIManager.switchBlockedReason(item.entry.id) ~= nil
	item.blocked = blocked
	item.stroke.Enabled = open or not item.tile
	item.stroke.Color = open and UIColors.ember or UIColors.rim
	item.stroke.Thickness = open and 3 or 1
	local alpha = inBoss() and BOSS_ALPHA or 0
	if item.tile then
		item.tile.image.ImageColor3 = blocked and Color3.fromRGB(120, 122, 130) or Color3.new(1, 1, 1)
		item.tile.image.ImageTransparency = alpha
		item.button.BackgroundTransparency = 1
	else
		item.button.BackgroundColor3 = blocked and UIColors.lockedBg or (item.entry.id == "shop" and UIColors.gold or UIColors.slot)
		item.button.BackgroundTransparency = math.max(alpha, blocked and 0 or UIColors.slotTransparency)
	end
	item.lock.Visible = blocked
end

local function tileFor(button, entry)
	local name = ICON_IMAGE[entry.iconKey]
	local key = entry.hotkey and entry.hotkey.Name or nil
	return name and IconTile.apply(button, name, key) or nil
end

-- 버튼 하나(메뉴 · 더보기 · 상점 공통)
local function makeButton(entry, parent, order)
	local button = Instance.new("TextButton")
	button.Name = "MenuButton_" .. entry.id
	button.LayoutOrder = order
	button.AutoButtonColor = false
	button.Text = ""
	button.BackgroundColor3 = UIColors.slot
	button.BackgroundTransparency = UIColors.slotTransparency
	button.Parent = parent
	Theme.corner(button, Theme.corner.button)
	local stroke = Theme.stroke(button)

	local item = { entry = entry, button = button, stroke = stroke, alert = 0 }
	item.tile = tileFor(button, entry)
	if not item.tile then
		-- 옛 모양: HudIcons 도형(있으면) 또는 이름 첫 두 글자 + 모서리 단축키 글자
		local draw = HudIcons[entry.iconKey]
		if draw then
			item.icon = draw(button, 26, UIColors.textPrimary)
			item.icon.Name = "Icon"
			item.icon.AnchorPoint = Vector2.new(0.5, 0.5)
			item.icon.Position = UDim2.fromScale(0.5, 0.5)
		else
			local label = Instance.new("TextLabel")
			label.Name = "Icon"
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 1)
			label.Font = Theme.font
			label.TextSize = 14
			label.TextColor3 = entry.id == "shop" and UIColors.panel or UIColors.textPrimary
			label.Text = entry.id == "more" and "···" or utf8.char(utf8.codepoint(entry.menuLabel or "?", 1))
			label.Parent = button
			item.icon = label
		end
		if entry.hotkey then
			local letter = Instance.new("TextLabel")
			letter.Name = "Hotkey"
			letter.AnchorPoint = Vector2.new(1, 1)
			letter.Position = UDim2.new(1, -2, 1, -1)
			letter.Size = UDim2.fromOffset(14, 14)
			letter.BackgroundTransparency = 1
			letter.Font = Theme.fontBody
			letter.TextSize = Theme.text.caption
			letter.TextColor3 = UIColors.textSecondary
			letter.Text = entry.hotkey.Name
			letter.Parent = button
			item.letter = letter
		end
	end
	-- 잠김 자물쇠(왼쪽 아래 작은 배지)
	local lock = Instance.new("Frame")
	lock.Name = "LockBadge"
	lock.BackgroundTransparency = 1
	lock.AnchorPoint = Vector2.new(0, 1)
	lock.Position = UDim2.new(0, 2, 1, -2)
	lock.Size = UDim2.fromOffset(16, 16)
	lock.ZIndex = 11
	lock.Visible = false
	lock.Parent = button
	HudIcons.lock(lock, 16, UIColors.gold)
	item.lock = lock

	-- 눌림(아래로 4px) · 폰 길게 누름 = 이름 말풍선(그 뒤 손을 떼도 열지 않는다)
	local function content()
		return item.tile and item.tile.image or item.icon
	end
	local pressAt, longShown = nil, false
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			local c = content()
			if c then
				c.Position = (c.Position :: UDim2) + UDim2.fromOffset(0, PRESS_DROP)
			end
			pressAt, longShown = os.clock(), false
			if input.UserInputType == Enum.UserInputType.Touch then
				local mine = pressAt
				task.delay(LONG_PRESS, function()
					if pressAt == mine then
						longShown = true
						showName(item, 1.6)
					end
				end)
			end
		end
	end)
	button.InputEnded:Connect(function(input)
		if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and pressAt then
			local c = content()
			if c then
				c.Position = (c.Position :: UDim2) - UDim2.fromOffset(0, PRESS_DROP)
			end
			pressAt = nil
		end
	end)
	button.Activated:Connect(function()
		if longShown then
			longShown = false
			return
		end
		if item.blocked then
			notifyBlocked(UIManager.switchBlockedReason(entry.id) or UIManager.blockedTexts.canOpen)
			return
		end
		pressEntry(entry)
	end)
	return item
end

local MORE_ENTRY = { id = "more", iconKey = "more", menuLabel = Text.get("hud.menu.more") }
local SHOP_ENTRY = { id = "shop", iconKey = "shop", menuLabel = Text.get("hud.menu.shop"), onPress = function()
	require(script.Parent.Parent.panels.Shop).openFromHud("recommend")
end }

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "MenuBarGui"
	gui.ResetOnSpawn = false
	-- window(100 ~ 149) 딤 위 · overlay(200 ~) 아래 - 열린 창을 같은 버튼으로 닫을 수 있게(S16 실제 클릭 결함)
	gui.DisplayOrder = 150
	gui.Parent = player:WaitForChild("PlayerGui")
	refs.gui = gui

	local bar = Instance.new("Frame")
	bar.Name = "MenuBar"
	bar.BackgroundTransparency = 1
	bar.Parent = gui
	refs.bar = bar
	local grid = Instance.new("UIGridLayout")
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.FillDirection = Enum.FillDirection.Horizontal
	grid.Parent = bar
	refs.grid = grid

	local more = Instance.new("Frame")
	more.Name = "MenuMorePanel"
	more.BackgroundColor3 = UIColors.panel
	more.BackgroundTransparency = UIColors.panelTransparency
	more.Visible = false
	more.Parent = gui
	Theme.corner(more, 10)
	Theme.stroke(more)
	local moreGrid = Instance.new("UIGridLayout")
	moreGrid.SortOrder = Enum.SortOrder.LayoutOrder
	moreGrid.Parent = more
	local pad = Instance.new("UIPadding")
	for _, side in ipairs({ "PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom" }) do
		pad[side] = UDim.new(0, 6)
	end
	pad.Parent = more
	refs.more, refs.moreGrid = more, moreGrid

	for _, entry in ipairs(PanelRegistry.menuEntries(false)) do
		table.insert(refs.items, makeButton(entry, bar, entry.menuOrder))
	end
	refs.moreButton = makeButton(MORE_ENTRY, bar, 90)
	refs.shopButton = makeButton(SHOP_ENTRY, bar, 91)
	for _, entry in ipairs(PanelRegistry.menuEntries(true)) do
		table.insert(refs.moreItems, makeButton(entry, more, entry.menuOrder))
	end
	MORE_ENTRY.onPress = function()
		setMoreOpen(not morePanelOpen)
	end
end

build()

local function all()
	local list = {}
	for _, item in ipairs(refs.items) do
		table.insert(list, item)
	end
	table.insert(list, refs.moreButton)
	table.insert(list, refs.shopButton)
	for _, item in ipairs(refs.moreItems) do
		table.insert(list, item)
	end
	return list
end

local function refreshLook()
	for _, item in ipairs(all()) do
		applyLook(item)
	end
end

-- 줄 위 칸 · 더보기 칸 나누기(폰 = 상시 칸만 줄 위 · 나머지는 더보기로 옮긴다) + 크기 · 자리
local function relayout()
	local size = buttonSize()
	local boss = inBoss()
	if boss then
		size = math.floor(size * BOSS_SCALE)
	end
	local gap = M.gap
	local shown = 0
	for _, item in ipairs(refs.items) do
		local hidden = isHidden(item.entry)
		local onBar = not hidden and (not Theme.isMobile or item.entry.menuPinned)
		item.button.Parent = onBar and refs.bar or refs.more
		item.button.Visible = not hidden
		if onBar then
			shown += 1
		end
	end
	for _, item in ipairs(refs.moreItems) do
		item.button.Visible = not isHidden(item.entry)
	end
	shown += 2 -- 더보기 · 상점
	local cols = Theme.isMobile and 2 or 1
	local rows = math.ceil(shown / cols)
	refs.grid.CellSize = UDim2.fromOffset(size, size)
	refs.grid.CellPadding = UDim2.fromOffset(gap, gap)
	refs.bar.Size = UDim2.fromOffset(cols * size + (cols - 1) * gap, rows * size + (rows - 1) * gap)
	refs.bar.Position = UDim2.fromOffset(ScreenMap.edgeMargin, Theme.isMobile and M.topMargin or (M.pcTop or 16))
	-- 더보기 칸: 더보기 버튼 오른쪽 · 2열
	local moreCount = 0
	for _, child in ipairs(refs.more:GetChildren()) do
		if child:IsA("GuiButton") and child.Visible then
			moreCount += 1
		end
	end
	local mSize = Theme.isMobile and M.mobileButton or math.max(M.button, math.floor(buttonSize() * 0.85))
	local mCols = math.min(3, moreCount)
	local mRows = math.ceil(moreCount / math.max(1, mCols))
	refs.moreGrid.CellSize = UDim2.fromOffset(mSize, mSize)
	refs.moreGrid.CellPadding = UDim2.fromOffset(gap, gap)
	refs.more.Size = UDim2.fromOffset(mCols * mSize + (mCols - 1) * gap + 12, mRows * mSize + (mRows - 1) * gap + 12)
	for _, item in ipairs(all()) do
		if item.tile and item.tile.chip then
			item.tile.chip.Visible = not boss
		end
		if item.letter then
			item.letter.Visible = not Theme.isMobile and not boss
		end
	end
	refreshLook()
	task.defer(function()
		local mb = refs.moreButton.button
		refs.more.Position = UDim2.fromOffset(mb.AbsolutePosition.X - refs.gui.AbsolutePosition.X + mb.AbsoluteSize.X + 8,
			math.max(4, mb.AbsolutePosition.Y - refs.gui.AbsolutePosition.Y))
	end)
end

setMoreOpen = function(open)
	morePanelOpen = open == true and not inBoss()
	refs.more.Visible = morePanelOpen
	refs.moreButton.stroke.Enabled = morePanelOpen or not refs.moreButton.tile
	refs.moreButton.stroke.Color = morePanelOpen and UIColors.ember or UIColors.rim
end

local function findItem(id)
	for _, item in ipairs(all()) do
		if item.entry.id == id then
			return item
		end
	end
	return nil
end

-- 알림: 퀘스트(받을 보상 = 서버 QuestClaimable · 출석 창을 닫았을 때 남는 점) · 가방(가득 · 새 아이템 수 InventoryNewCount) · 수련(TrainingReady) · 상점(ShopClaimable - 시즌 패스 받을 칸)
local function refreshAlerts()
	local quest = findItem("quests")
	if quest then
		setAlert(quest, player:GetAttribute("QuestClaimable") == true and 1 or 0)
	end
	local training = findItem("training")
	if training then
		setAlert(training, player:GetAttribute("TrainingReady") == true and 1 or 0)
	end
	local shop = refs.shopButton
	setAlert(shop, player:GetAttribute("ShopClaimable") or 0)
	local bag = findItem(BADGE_PANEL)
	if bag then
		setAlert(bag, math.max(bag.fullAlert and 1 or 0, player:GetAttribute("InventoryNewCount") or 0))
	end
	-- 더보기 안에 알림이 있으면 더보기 버튼에도 점
	local inMore = 0
	for _, item in ipairs(all()) do
		if item.button.Parent == refs.more and item.alert > 0 then
			inMore += 1
		end
	end
	setAlert(refs.moreButton, inMore > 0 and 1 or 0)
end
for _, name in ipairs({ "QuestClaimable", "TrainingReady", "ShopClaimable", "InventoryNewCount" }) do
	player:GetAttributeChangedSignal(name):Connect(refreshAlerts)
end

inventoryFull.OnClientEvent:Connect(function()
	local bag = findItem(BADGE_PANEL)
	if bag then
		bag.fullAlert = true
		refreshAlerts()
	end
end)

UIManager.changed:Connect(function(id, isOpen)
	refreshLook()
	if id == BADGE_PANEL and isOpen then
		local bag = findItem(BADGE_PANEL)
		if bag then
			bag.fullAlert = false
			refreshAlerts()
		end
	end
	if isOpen then
		setMoreOpen(false)
	end
end)

-- 아트 스위치가 늦게 복제돼도 켜지는 순간 타일을 입힌다
workspace:GetAttributeChangedSignal("ArtStyleV1"):Connect(function()
	for _, item in ipairs(all()) do
		if not item.tile then
			item.tile = tileFor(item.button, item.entry)
			if item.tile then
				if item.icon then
					item.icon.Visible = false
				end
				if item.letter then
					item.letter.Visible = false
				end
			end
		end
	end
	relayout()
end)

relayout()
refreshAlerts()
for _, item in ipairs(refs.items) do
	if item.button.Visible then
		showName(item, 8) -- 첫 접속 8초 이름표
	end
end
refs.gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
for _, name in ipairs({ "TutorialCompleted", "TutorialStep", "ClassId", "BossEncounterId" }) do
	player:GetAttributeChangedSignal(name):Connect(function()
		if inBoss() then
			setMoreOpen(false)
		end
		relayout()
	end)
end
UserInputService.InputBegan:Connect(function(input, processed)
	-- 더보기 밖을 누르면 닫는다
	if morePanelOpen and not processed and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		setMoreOpen(false)
	end
end)
if RunService:IsStudio() then
	player:GetAttributeChangedSignal("ForceTouchLayout"):Connect(function()
		Theme.recompute()
		relayout()
	end)
	player:GetAttributeChangedSignal("ShowMenuBarTags"):Connect(function()
		if player:GetAttribute("ShowMenuBarTags") then
			player:SetAttribute("ShowMenuBarTags", nil)
			for _, item in ipairs(refs.items) do
				showName(item, 8)
			end
		end
	end)
	-- 스크린샷 · 점검: 더보기 열기 · 알림 흉내
	player:GetAttributeChangedSignal("DebugMenuMore"):Connect(function()
		setMoreOpen(player:GetAttribute("DebugMenuMore") == true)
	end)
end
