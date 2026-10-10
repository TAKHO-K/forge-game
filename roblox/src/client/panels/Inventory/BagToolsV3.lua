-- UI-1 4단계 가방 도구(03 v3 §6 · §8): 정렬 방향(높은 것 / 낮은 것 먼저) · 필터 판(등급 · 세트 구역 · 옵션 - 같은 묶음 = 또는 · 묶음끼리 = 그리고 · 켜진 수) ·
--   선택해서 정리(칸 오른쪽 위 원 · 잠금 = 고를 수 없음 + 흔들림 · 아래 막대 "n개 선택 · 받는 골드" + [취소] [판매] [분해] → 확인 창 - 위험 버튼은 확인 창 안에서만).
--   도구 버튼은 정렬 버튼과 같은 줄(PC 가방 줄 · 좁으면 머리 오른쪽)을 따라간다. 판매 · 분해 = 서버 SellRequest sellList · dismantleList(칸 + 확인값 · 큰 번호부터).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local OptionData = require(ReplicatedStorage.Shared.data.OptionData)
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local Loot = require(ReplicatedStorage.Shared.Loot)
local GradeColor = require(ReplicatedStorage.Shared.GradeColor)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Text = require(ReplicatedStorage.Shared.Text)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)
local SettingSave = require(script.Parent.Parent.Parent.ui.SettingSave)
local ItemConfirm = require(script.Parent.ItemConfirm)
local Toast = require(script.Parent.Parent.Parent.ui.kit.Toast)

local BagToolsV3 = {}

local function pill(text, order)
	local b = Instance.new("TextButton")
	b.Name = "Tool"
	b.AutoButtonColor = false
	b.LayoutOrder = order
	b.AutomaticSize = Enum.AutomaticSize.X
	b.Size = UDim2.new(0, 0, 0, 30)
	b.BackgroundColor3 = UIColors.panel
	b.BackgroundTransparency = UIColors.panelTransparency
	b.Font = Enum.Font.GothamBold
	b.TextSize = Theme.textSize("caption")
	b.TextColor3 = UIColors.textPrimary
	b.Text = text
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = b
	local st = Instance.new("UIStroke")
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Color = UIColors.rim
	st.Transparency = UIColors.rimTransparency
	st.Parent = b
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
	pad.Parent = b
	return b
end

function BagToolsV3.create(S, R, refs)
	local player = Players.LocalPlayer
	local sellRequest = ReplicatedStorage:WaitForChild("SellRequest")
	local confirm = ItemConfirm.create(R.content, player)
	local dirButton = pill("", 2)
	dirButton.Name = "SortDir"
	local filterButton = pill("", 3)
	filterButton.Name = "FilterButton"
	local selectButton = pill(Text.get("ui1.bag.selectMode"), 4)
	selectButton.Name = "SelectModeButton"
	local tools = { dirButton, filterButton, selectButton }

	local function paintDir()
		dirButton.Text = Text.get(S.sortAsc and "ui1.bag.sortAsc" or "ui1.bag.sortDesc")
	end
	paintDir()
	dirButton.Activated:Connect(function()
		S.sortAsc = not S.sortAsc
		SettingSave("bagSortAsc", S.sortAsc)
		paintDir()
		S.rebuildGrid()
	end)

	-- ── 필터 판 ──
	local panel = Instance.new("Frame")
	panel.Name = "FilterPanel"
	panel.BackgroundColor3 = Color3.fromHex("161A2B")
	panel.BackgroundTransparency = 0.02
	panel.Visible = false
	panel.ZIndex = 30
	panel.Parent = refs.column
	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0, 12)
	pc.Parent = panel
	local ps = Instance.new("UIStroke")
	ps.Color = UIColors.rim
	ps.Parent = panel
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 5
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Size = UDim2.new(1, 0, 1, -56)
	scroll.ZIndex = 31
	scroll.Parent = panel
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll
	local spad = Instance.new("UIPadding")
	spad.PaddingLeft, spad.PaddingRight, spad.PaddingTop = UDim.new(0, 12), UDim.new(0, 12), UDim.new(0, 10)
	spad.Parent = scroll
	local chips = {}
	local function countOn()
		local n = 0
		for _, group in pairs(S.filters) do
			for _ in pairs(group) do
				n += 1
			end
		end
		return n
	end
	local function matchCount()
		local n = 0
		for _, item in ipairs(S.inventory) do
			if S.bagPassesFilter(item) then
				n += 1
			end
		end
		return n
	end
	local applyButton
	local function paintFilter()
		local n = countOn()
		filterButton.Text = n > 0 and Text.get("ui1.bag.filterOn", { n = tostring(n) }) or Text.get("ui1.bag.filter")
		for _, c in ipairs(chips) do
			local on = S.filters[c.group][c.key] == true
			c.button.BackgroundTransparency = on and 0.05 or 0.6
			c.button.TextColor3 = on and Color3.fromHex("3A2A12") or UIColors.textPrimary
			c.button.BackgroundColor3 = on and Color3.fromHex("FFC83D") or UIColors.slot
		end
		if applyButton then
			applyButton.Text = Text.get("ui1.bag.filterApply", { n = tostring(matchCount()) })
		end
	end
	local function group(titleKey, order, entries, groupKey)
		local head = Theme.label(scroll, Text.get(titleKey), "caption", "textSecondary")
		head.LayoutOrder = order
		head.Size = UDim2.new(1, 0, 0, 20)
		head.ZIndex = 32
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.Size = UDim2.new(1, 0, 0, 0)
		row.LayoutOrder = order + 1
		row.ZIndex = 32
		row.Parent = scroll
		local flow = Instance.new("UIGridLayout")
		flow.CellSize = UDim2.fromOffset(Theme.isMobile and 110 or 120, 44)
		flow.CellPadding = UDim2.fromOffset(8, 8)
		flow.Parent = row
		for _, e in ipairs(entries) do
			local b = Instance.new("TextButton")
			b.AutoButtonColor = false
			b.Text = e.text
			b.Font = Enum.Font.GothamBold
			b.TextSize = Theme.textSize("caption")
			b.TextWrapped = true
			b.ZIndex = 33
			b.Parent = row
			local cc = Instance.new("UICorner")
			cc.CornerRadius = UDim.new(0, 10)
			cc.Parent = b
			if e.border then
				local st = Instance.new("UIStroke")
				st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				st.Color = e.border
				st.Thickness = 2
				st.Parent = b
			end
			table.insert(chips, { button = b, group = groupKey, key = e.key })
			b.Activated:Connect(function()
				S.filters[groupKey][e.key] = (not S.filters[groupKey][e.key]) or nil
				paintFilter()
			end)
		end
	end
	local grades = {}
	for _, id in ipairs(ArmorData.gradeOrder) do
		table.insert(grades, { key = id, text = Text.name(ArmorData.grades[id].displayName), border = GradeColor.border(id) })
	end
	group("ui1.bag.filter.grade", 10, grades, "grade")
	local zones = {}
	for _, z in ipairs(WorldMapData.zones or {}) do
		if z.key and z.theme then
			table.insert(zones, { key = z.key, text = Text.name(z.theme) })
		end
	end
	group("ui1.bag.filter.zone", 20, zones, "zone")
	local options = {}
	for _, id in ipairs(OptionData.commonOrder or {}) do
		local def = OptionData.options[id]
		if def then
			table.insert(options, { key = id, text = Text.name(def.displayName) })
		end
	end
	group("ui1.bag.filter.option", 30, options, "option")
	local function bottomButton(textKey, x, primary, fn)
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.AnchorPoint = Vector2.new(1, 1)
		b.Position = UDim2.new(1, x, 1, -8)
		b.Size = UDim2.fromOffset(primary and 220 or 120, 44)
		b.BackgroundColor3 = primary and Color3.fromHex("FFC83D") or UIColors.slot
		b.TextColor3 = primary and Color3.fromHex("3A2A12") or UIColors.textPrimary
		b.Font = Enum.Font.GothamBold
		b.TextSize = Theme.textSize("body")
		b.Text = Text.get(textKey, { n = "0" })
		b.ZIndex = 32
		b.Parent = panel
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 10)
		c.Parent = b
		b.Activated:Connect(fn)
		return b
	end
	bottomButton("ui1.bag.filterClear", -244, false, function()
		S.filters = { grade = {}, zone = {}, option = {} }
		paintFilter()
	end)
	applyButton = bottomButton("ui1.bag.filterApply", -12, true, function()
		panel.Visible = false
		S.rebuildGrid()
		paintFilter()
	end)
	filterButton.Activated:Connect(function()
		panel.Visible = not panel.Visible
		paintFilter()
	end)
	paintFilter()

	-- ── 선택해서 정리 ──
	local bar = Instance.new("Frame")
	bar.Name = "SelectBar"
	bar.BackgroundColor3 = Color3.fromHex("161A2B")
	bar.BackgroundTransparency = 0.02
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.new(0, 8, 1, -8)
	bar.Size = UDim2.new(1, -16, 0, 56)
	bar.Visible = false
	bar.ZIndex = 28
	bar.Parent = refs.column
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 12)
	bc.Parent = bar
	local barText = Theme.label(bar, "", "body", "textPrimary")
	barText.Position, barText.Size = UDim2.fromOffset(12, 0), UDim2.new(1, -380, 1, 0)
	barText.TextWrapped = true
	barText.ZIndex = 29
	local function barButton(textKey, x, w)
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.AnchorPoint = Vector2.new(1, 0.5)
		b.Position = UDim2.new(1, x, 0.5, 0)
		b.Size = UDim2.fromOffset(w, 44)
		b.BackgroundColor3 = UIColors.slot
		b.TextColor3 = UIColors.textPrimary
		b.Font = Enum.Font.GothamBold
		b.TextSize = Theme.textSize("body")
		b.Text = Text.get(textKey)
		b.ZIndex = 29
		b.Parent = bar
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 10)
		c.Parent = b
		return b
	end
	local dismantleB = barButton("inv.act.dismantle", -8, 110)
	local sellB = barButton("inv.act.sell", -126, 110)
	local cancelB = barButton("ui1.bag.cancel", -244, 110)
	local function chosen()
		local out = {}
		for i in pairs(S.selected) do
			local item = S.inventory[i]
			if item and not item.locked then
				table.insert(out, i)
			end
		end
		table.sort(out)
		return out
	end
	function S.refreshSelectBar()
		bar.Visible = S.selectMode
		selectButton.Text = Text.get(S.selectMode and "ui1.bag.selectDone" or "ui1.bag.selectMode")
		if not S.selectMode then
			return
		end
		local gold = 0
		local list = chosen()
		for _, i in ipairs(list) do
			gold += Loot.getSellPrice(S.inventory[i]) or 0
		end
		barText.Text = Text.get("ui1.bag.selectCount", { n = tostring(#list), gold = NumberFormat.currency(gold, Text.languageFor()) })
	end
	function S.selectShake(cell)
		local p = cell.Position
		task.spawn(function()
			for k = 1, 4 do
				cell.Position = p + UDim2.fromOffset((k % 2 == 1) and 4 or -4, 0)
				task.wait(0.045)
			end
			cell.Position = p
		end)
		Toast.push("TC", { text = Text.get("ui1.bag.lockedNoSelect"), colorName = "textPrimary" })
	end
	local function setMode(on)
		S.selectMode = on
		S.selected = {}
		S.rebuildGrid()
	end
	selectButton.Activated:Connect(function()
		setMode(not S.selectMode)
	end)
	cancelB.Activated:Connect(function()
		setMode(false)
	end)
	local function run(action, verbKey)
		local list = chosen()
		if #list == 0 then
			return
		end
		local payload = {}
		for _, i in ipairs(list) do
			table.insert(payload, { i, Loot.itemSignature(S.inventory[i]) })
		end
		confirm.ask(Text.get("ui1.bag.selectConfirm", { n = tostring(#list), verb = Text.get(verbKey) }), UIColors.textPrimary, function()
			sellRequest:FireServer(action, payload)
			setMode(false)
		end)
	end
	sellB.Activated:Connect(function()
		run("sellList", "inv.act.sell")
	end)
	dismantleB.Activated:Connect(function()
		run("dismantleList", "inv.act.dismantle")
	end)

	-- 도구 버튼 = 정렬 버튼과 같은 줄을 따라감 · 필터 판 = 격자 자리 덮음
	table.insert(R.layouts, function(L)
		local parent = R.sortButton and R.sortButton.Parent
		for _, t in ipairs(tools) do
			if parent and t.Parent ~= parent then
				t.Parent = parent
			end
			t.Size = UDim2.new(0, 0, 0, L.mode == "phone" and 44 or 30)
		end
		panel.Position = UDim2.fromOffset(8, 8)
		panel.Size = UDim2.new(1, -16, 1, -16)
	end)
	-- InventoryGui = ZIndex 전체 모드(Global): 필터 판 · 선택 막대를 격자 · 칸 위로(깊이만큼 +1)
	local function lift(node, z)
		if node:IsA("GuiObject") then
			node.ZIndex = z
		end
		for _, c in ipairs(node:GetChildren()) do
			lift(c, z + 1)
		end
	end
	lift(panel, 60)
	lift(bar, 60)
	S.refreshSelectBar()
end

return BagToolsV3
