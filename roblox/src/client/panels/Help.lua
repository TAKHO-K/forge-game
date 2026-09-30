-- 도움말 백과사전 창(QUEUE-ALL2 P2 · ref 18 ②). 왼쪽 = 분류 목록(그림 + 이름) · 오른쪽 = 그림 하나 + 짧은 줄 5개 이하(한 줄 40자 이하).
--   분류 · 항목 · 문구 키 = shared/data/HelpCodexData.lua. "보스 기믹" 분류는 첫 만남 카드와 같은 그림 3컷(BossIntroDiagram.buildCard)을 보여 준다.
--   숫자는 문장 밖 칩 또는 원본 데이터에서 끼운다(ARGS - 여기에도 숫자를 적지 않는다). 키 칩은 PanelRegistry.hotkeySheet에서 읽는다(단축키가 바뀌면 같이 바뀐다).
-- 여는 법: HelpPanel.open(categoryId, entryId) - 분류 id(HelpCodexData.categories) · 항목 id(보스 기믹이면 보스 id). HelpPanel.toggle() = 마지막 분류로 열고 닫기.
--   왼쪽 메뉴 · 단축키 등록은 하지 않는다(PanelRegistry 소관). 말풍선(Bubble)의 누름은 HelpPanelBoot가 이 open으로 잇는다.
-- 배치: 창 크기 = Panel.create(window - PC 720 × 460 · 폰 92% × 88%, 최대 720 × 480). 오른쪽이 좁으면(< 440) 그림을 위, 줄을 아래로. 넘치면 오른쪽 스크롤.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local HelpCodexData = require(ReplicatedStorage.Shared.data.HelpCodexData)
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local EnhanceConfig = require(ReplicatedStorage.Shared.data.EnhanceConfig)
local PetData = require(ReplicatedStorage.Shared.data.PetData)
local Enhance = require(ReplicatedStorage.Shared.Enhance)
local Text = require(ReplicatedStorage.Shared.Text)
local Panel = require(script.Parent.Parent.ui.kit.Panel)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local ArtImage = require(script.Parent.Parent.ui.ArtImage)
local PanelRegistry = require(script.Parent.Parent.ui.PanelRegistry)
local UIManager = require(script.Parent.Parent.UIManager)
local BossIntroDiagram = require(script.Parent.Parent.BossIntroDiagram)

local HelpPanel = {}
HelpPanel.id = "help"

local PANEL_SIZE = Vector2.new(720, 460)
local PAD = 8
local ROW_H = 48 -- 분류 줄(터치 44 이상)
local SCROLL_BAR = 6
local NARROW_BELOW = 440 -- 오른쪽 폭이 이보다 좁으면 그림 위 · 줄 아래

local built -- { panel, left, body, rows = { [categoryId] = { button, stroke } } }
local current = { category = HelpCodexData.categories[1].id, entry = nil }

-- 숫자 인자(원본 데이터에서 읽는다 - 항목의 args 이름)
local ARGS = {
	enhance = function()
		local dropFrom, resetFrom = Enhance.getRiskStartLevels()
		return { safeTo = (dropFrom or 1) - 1, dropFrom = dropFrom or "?", resetFrom = resetFrom or "?", resetTo = EnhanceConfig.resetToLevel }
	end,
	stealLock = function()
		return { percent = math.floor(CombatConfig.contributionRewardThreshold * 100 + 0.5) }
	end,
	pet = function()
		return { level = PetData.unlocks.autoPickup, cap = PetData.petCap }
	end,
}

local function categoryById(id)
	for _, c in ipairs(HelpCodexData.categories) do
		if c.id == id then
			return c
		end
	end
	return nil
end

-- 분류의 항목 목록. 보스 기믹 = gimmickOrder(카드 데이터 · 보스가 있는 것만) - 항목 id = 보스 id.
local function entriesFor(category)
	local list = {}
	if category.gimmicks then
		for _, bossId in ipairs(HelpCodexData.gimmickOrder) do
			local boss = BossData.bosses[bossId]
			local card = HelpCodexData.gimmickCards[bossId]
			if boss and card then
				table.insert(list, { id = bossId, gimmick = true, icon = "icons/codex/boss_" .. bossId, card = card, boss = boss })
			end
		end
		return list
	end
	for _, e in ipairs(HelpCodexData.entries) do
		if e.category == category.id then
			table.insert(list, e)
		end
	end
	return list
end

-- 칩 글: hotkeySheet의 text 키면 그 줄의 keys, 아니면 TextData 키
local function chipText(chip)
	for _, row in ipairs(PanelRegistry.hotkeySheet or {}) do
		if row.text == chip then
			return row.keys
		end
	end
	return Text.get(chip)
end

local function textHeight(text, size, font, width)
	local bounds = TextService:GetTextSize(text, size, font, Vector2.new(math.max(width, 1), 2000))
	return bounds.Y
end

local function textWidth(text, size, font)
	return TextService:GetTextSize(text, size, font, Vector2.new(2000, 200)).X
end

local function clear(frame)
	for _, c in ipairs(frame:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local function panelWidth()
	if Theme.isMobile then
		local screen = built.panel.screenGui.AbsoluteSize
		local camera = workspace.CurrentCamera
		local w = screen.X > 0 and screen.X or (camera and camera.ViewportSize.X or PANEL_SIZE.X)
		return math.min(math.floor(w * 0.92), Panel.maxSize.X)
	end
	return PANEL_SIZE.X
end

local function leftWidth()
	return Theme.isMobile and 170 or 190
end

local render -- 아래(분류 · 항목 버튼이 부른다)

-- 항목 고르기 줄(항목이 둘 이상일 때): 아이콘이 있으면 정사각 아이콘 버튼, 없으면 제목 글 버튼. 넘치면 다음 줄로.
local function buildSelector(body, entries, selectedId, width)
	local h = Theme.isMobile and 44 or 36
	local x, y = 0, 0
	for _, e in ipairs(entries) do
		local label = e.gimmick and "" or Text.get(e.titleKey)
		local w = e.gimmick and h or math.floor(textWidth(label, Theme.textSize("caption"), Theme.font)) + 24
		if x > 0 and x + w > width then
			x, y = 0, y + h + 4
		end
		local b = Instance.new("TextButton")
		b.Name = "Entry_" .. e.id
		b.AutoButtonColor = false
		b.Text = label
		b.Font = Theme.font
		b.TextSize = Theme.textSize("caption")
		b.TextColor3 = Theme.color("textPrimary")
		b.BackgroundColor3 = Theme.color("slot")
		b.Position = UDim2.new(0, x, 0, y)
		b.Size = UDim2.new(0, w, 0, h)
		b.Parent = body
		Theme.corner(b, Theme.corner.chip)
		local stroke = Theme.stroke(b, e.id == selectedId and "ember" or nil, e.id == selectedId and 0 or nil)
		stroke.Thickness = e.id == selectedId and 2 or 1
		if e.gimmick then
			local img = ArtImage.label(b, e.icon, UDim2.new(1, -8, 1, -8), "")
			img.AnchorPoint = Vector2.new(0.5, 0.5)
			img.Position = UDim2.new(0.5, 0, 0.5, 0)
		end
		b.Activated:Connect(function()
			current.entry = e.id
			render()
		end)
		x += w + 4
	end
	return y + h
end

-- 그림 칸(아이콘 또는 도형 그림)
local function buildPicture(body, pic, x, y, size)
	local frame = Instance.new("Frame")
	frame.Name = "Picture"
	frame.Position = UDim2.new(0, x, 0, y)
	frame.Size = UDim2.new(0, size, 0, size)
	frame.BackgroundColor3 = Color3.fromRGB(38, 42, 62)
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = true
	frame.Parent = body
	Theme.corner(frame, 10)
	if pic and pic.icon then
		local img = ArtImage.label(frame, pic.icon, UDim2.new(1, -24, 1, -24), "")
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.new(0.5, 0, 0.5, 0)
	elseif pic and pic.draw then
		local inner = Instance.new("Frame")
		inner.Name = "Pic"
		inner.BackgroundTransparency = 1
		inner.Size = UDim2.new(1, 0, 1, 0)
		inner.Parent = frame
		BossIntroDiagram.drawPicture(inner, pic.draw)
	end
end

-- 짧은 줄들(칩 + 문장). 반환 = 끝 y
local function buildLines(body, entry, x, y, width)
	local args = entry.args and ARGS[entry.args] and ARGS[entry.args]() or nil
	local size = Theme.textSize("body")
	local chipSize = Theme.textSize("caption")
	for i, line in ipairs(entry.lines or {}) do
		local text = Text.get(line.key, args)
		local left = 0
		local rowH = size + 8
		if line.chip then
			local chip = chipText(line.chip)
			local chipW = math.floor(textWidth(chip, chipSize, Theme.font)) + 16
			local c = Theme.label(body, chip, "caption", "textPrimary")
			c.Name = "Chip" .. i
			c.Font = Theme.font
			c.TextXAlignment = Enum.TextXAlignment.Center
			c.TextTruncate = Enum.TextTruncate.None
			c.BackgroundTransparency = 0
			c.BackgroundColor3 = Theme.color("slot")
			c.Position = UDim2.new(0, x, 0, y + 1)
			c.Size = UDim2.new(0, chipW, 0, chipSize + 10)
			Theme.corner(c, 6)
			Theme.stroke(c)
			left = chipW + 8
		else
			local dot = Instance.new("Frame")
			dot.Name = "Dot" .. i
			dot.Position = UDim2.new(0, x + 2, 0, y + math.floor(size / 2) + 2)
			dot.Size = UDim2.new(0, 6, 0, 6)
			dot.BackgroundColor3 = Theme.color("ember")
			dot.BorderSizePixel = 0
			dot.Parent = body
			Theme.corner(dot, 3)
			left = 14
		end
		local w = width - left
		local h = math.max(textHeight(text, size, Theme.fontBody, w), size) + 4
		local label = Theme.label(body, text, "body", "textPrimary")
		label.Name = "Line" .. i
		label.TextWrapped = true
		label.TextTruncate = Enum.TextTruncate.None
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.Position = UDim2.new(0, x + left, 0, y + 3)
		label.Size = UDim2.new(0, w, 0, h)
		rowH = math.max(rowH, h + 6, line.chip and chipSize + 14 or 0)
		y += rowH + 4
	end
	return y
end

render = function()
	if not built then
		return
	end
	local mobile = Theme.isMobile
	for id, row in pairs(built.rows) do
		local on = id == current.category
		row.button.BackgroundColor3 = on and Theme.color("ember") or Theme.color("slot")
		row.stroke.Transparency = on and 1 or Theme.colors.rimTransparency
	end
	local body = built.body
	clear(body)
	body.CanvasPosition = Vector2.new(0, 0)
	local category = categoryById(current.category) or HelpCodexData.categories[1]
	local entries = entriesFor(category)
	local entry = entries[1]
	for _, e in ipairs(entries) do
		if e.id == current.entry then
			entry = e
		end
	end
	if not entry then
		return
	end
	local width = panelWidth() - leftWidth() - PAD * 3 - SCROLL_BAR - 4
	local y = 0
	if #entries > 1 then
		y = buildSelector(body, entries, entry.id, width) + 8
	end

	local titleText = entry.gimmick and Text.get("gimmick.cardTitle", { boss = entry.boss.displayName, gimmick = Text.get(entry.card.titleKey) }) or Text.get(entry.titleKey)
	local title = Theme.label(body, titleText, "header", entry.gimmick and "danger" or "textPrimary")
	title.Name = "EntryTitle"
	title.Position = UDim2.new(0, 0, 0, y)
	title.Size = UDim2.new(0, width, 0, Theme.textSize("header") + 8)
	y += Theme.textSize("header") + 14

	if entry.gimmick then
		local card = BossIntroDiagram.buildCard(body, entry.id, { width = width, position = UDim2.new(0, 0, 0, y), mobile = mobile, panelHeight = mobile and 90 or 120 })
		y += (card and card.height or 0) + 8
	else
		local picSize = mobile and 110 or 140
		if width >= NARROW_BELOW then
			buildPicture(body, entry.pic, 0, y, picSize)
			local endY = buildLines(body, entry, picSize + 14, y, width - picSize - 14)
			y = math.max(y + picSize, endY) + 8
		else
			buildPicture(body, entry.pic, math.floor((width - picSize) / 2), y, picSize)
			y = buildLines(body, entry, 0, y + picSize + 10, width) + 8
		end
	end
	body.CanvasSize = UDim2.new(0, 0, 0, y)
end

local function build()
	Theme.recompute()
	local panel = Panel.create({
		id = HelpPanel.id,
		kind = "window",
		title = Text.get("help.title"),
		size = PANEL_SIZE,
	})
	local content = panel.content
	local leftW = leftWidth()

	local left = Instance.new("ScrollingFrame")
	left.Name = "Categories"
	left.BackgroundTransparency = 1
	left.BorderSizePixel = 0
	left.Position = UDim2.new(0, PAD, 0, PAD)
	left.Size = UDim2.new(0, leftW, 1, -PAD * 2)
	left.ScrollBarThickness = 4
	left.ScrollBarImageColor3 = Theme.color("rim")
	left.CanvasSize = UDim2.new(0, 0, 0, #HelpCodexData.categories * (ROW_H + 4))
	left.Parent = content
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = left

	local rows = {}
	for i, c in ipairs(HelpCodexData.categories) do
		local b = Instance.new("TextButton")
		b.Name = "Cat_" .. c.id
		b.Text = ""
		b.AutoButtonColor = false
		b.LayoutOrder = i
		b.Size = UDim2.new(1, -6, 0, ROW_H)
		b.BackgroundColor3 = Theme.color("slot")
		b.Parent = left
		Theme.corner(b, Theme.corner.button)
		local stroke = Theme.stroke(b)
		local icon = ArtImage.label(b, c.icon, UDim2.fromOffset(32, 32), "")
		icon.Position = UDim2.new(0, 8, 0.5, -16)
		local label = Theme.label(b, Text.get(c.titleKey), "body", "textPrimary")
		label.Name = "Label"
		label.Font = Theme.font
		label.Position = UDim2.new(0, 48, 0, 0)
		label.Size = UDim2.new(1, -52, 1, 0)
		b.Activated:Connect(function()
			current.category = c.id
			current.entry = nil
			render()
		end)
		rows[c.id] = { button = b, stroke = stroke }
	end

	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Position = UDim2.new(0, leftW + PAD * 2, 0, PAD)
	body.Size = UDim2.new(1, -(leftW + PAD * 3), 1, -PAD * 2)
	body.ScrollBarThickness = SCROLL_BAR
	body.ScrollBarImageColor3 = Theme.color("rim")
	body.CanvasSize = UDim2.new(0, 0, 0, 0)
	body.Parent = content

	built = { panel = panel, left = left, body = body, rows = rows }
end

-- 도움말 창을 그 분류(· 항목)로 연다. 이미 열려 있으면 내용만 바꾼다. 모르는 분류면 첫 분류.
function HelpPanel.open(categoryId, entryId)
	if not built then
		build()
	end
	if categoryId and categoryById(categoryId) then
		current.category = categoryId
		current.entry = entryId
	end
	render()
	if not UIManager.isOpen(HelpPanel.id) then
		UIManager.open(HelpPanel.id)
	end
end

-- PanelRegistry opener 규약(toggle)을 맞춰 둔다 - 등록은 PanelRegistry 소관.
function HelpPanel.toggle()
	if built and UIManager.isOpen(HelpPanel.id) then
		UIManager.close(HelpPanel.id)
		return
	end
	HelpPanel.open()
end

function HelpPanel.debugRefs()
	return built
end

return HelpPanel
