local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local SaveConfig = require(ReplicatedStorage.Shared.data.SaveConfig)
local ItemDescribe = require(ReplicatedStorage.Shared.ItemDescribe)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local ItemIcons = require(script.Parent.Parent.Parent.ItemIcons)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)
local Layout = require(script.Parent.Layout)
local ItemActions = require(script.Parent.ItemActions)

-- 가방 칸(S20b: InventoryUI 분할) - 보관함 격자 · 골드 / 일괄판매 예상 알약 · 정렬. 세로 스크롤 ScrollingFrame이다(PC = 오른쪽 칸 · 폰 = "가방" 탭 본문). 열 수는 폭에서 정한다(PC 5 · 폰 800에서 9).
local BagTab = {}

function BagTab.create(S, R)
local player = S.player
local content = R.content
local countLabel, cutoffButton, sortButton = R.countLabel, R.cutoffButton, R.sortButton
local CELL_SIZE, CELL_GAP = Layout.cellSize, Layout.cellGap
local GRID_COLS = 5 -- 초기값(배치가 폭에서 다시 정한다)

local bag = Instance.new("ScrollingFrame")
bag.Name = "Bag"
bag.BackgroundTransparency = 1
bag.BorderSizePixel = 0
bag.ScrollBarThickness = 4
bag.CanvasSize = UDim2.new(0, 0, 0, 0)
bag.Parent = content
R.bagFrame = bag

S.makeSectionLabel(bag, "보관함", 14)

local grid = Instance.new("Frame")
grid.Position = UDim2.new(0, 14, 0, 34)
grid.Size = UDim2.new(1, -28, 0, CELL_SIZE * 4 + CELL_GAP * 3)
grid.BackgroundTransparency = 1
grid.Parent = bag

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, CELL_SIZE, 0, CELL_SIZE)
gridLayout.CellPadding = UDim2.new(0, CELL_GAP, 0, CELL_GAP)
gridLayout.FillDirectionMaxCells = GRID_COLS
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = grid

local bagfoot = Instance.new("Frame")
bagfoot.Position = UDim2.new(0, 14, 0, 34 + CELL_SIZE * 4 + CELL_GAP * 3 + 12)
bagfoot.Size = UDim2.new(1, -28, 0, 27)
bagfoot.BackgroundTransparency = 1
bagfoot.Parent = bag

local bagfootLayout = Instance.new("UIListLayout")
bagfootLayout.FillDirection = Enum.FillDirection.Horizontal
bagfootLayout.Padding = UDim.new(0, 8)
bagfootLayout.SortOrder = Enum.SortOrder.LayoutOrder
bagfootLayout.Parent = bagfoot

local function makeFootPill(dangerStyle)
	local pill = Instance.new("Frame")
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.Size = UDim2.new(0, 0, 1, 0)
	pill.BackgroundColor3 = UIColors.panel
	pill.BackgroundTransparency = UIColors.panelTransparency
	pill.Parent = bagfoot

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = pill
	local stroke = Instance.new("UIStroke")
	stroke.Color = dangerStyle and UIColors.danger or UIColors.rim
	stroke.Transparency = dangerStyle and 0.5 or UIColors.rimTransparency
	stroke.Parent = pill
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = pill

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.new(0, 0, 1, 0)
	label.Font = Enum.Font.GothamBold
	label.TextSize = Theme.textSize("caption") -- 16-6 [4]: 12px 미만 금지.
	label.TextColor3 = dangerStyle and Color3.fromRGB(255, 141, 141) or UIColors.textSecondary
	label.Text = ""
	label.Parent = pill

	return label
end

local goldPillLabel = makeFootPill(false)
local bulkEstimatePillLabel = makeFootPill(true)
R.goldPillLabel = goldPillLabel

local cellFrames = {}
local isDoubleClick = ItemActions.doubleClickTracker() -- S20d: 가방 칸 더블클릭(0.35초) = 착용(찬 부위면 교체)

-- 착용 거절 연출의 좌표(S20d): 그 가방 칸 · 가방 영역의 중심(폰에서 이 탭이 안 보이면 nil).
function S.bagCellCenter(index)
	return S.visibleCenter(cellFrames[index])
end
function S.bagAreaCenter()
	return S.visibleCenter(bag)
end

local function selectBagIndex(index)
	S.selectedKind, S.selectedValue = "bag", index
	S.refreshDetail()
	for i, cell in ipairs(cellFrames) do
		local selStroke = cell:FindFirstChild("SelectionStroke")
		if selStroke then
			selStroke.Transparency = (i == index) and 0 or 1
		end
	end
end

local function rebuildGrid()
	for _, child in ipairs(grid:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextButton") then
			child:Destroy()
		end
	end
	cellFrames = {}
	S.rainbowGradients = {}

	local entries = S.sortedEntries()
	local totalSlots = SaveConfig.defaultInventorySlots

	for order, entry in ipairs(entries) do
		local item = entry.item
		local cell = Instance.new("TextButton")
		cell.Name = "Cell_" .. entry.index
		cell.LayoutOrder = order
		cell.Text = ""
		cell.AutoButtonColor = false
		cell.BackgroundColor3 = UIColors.slot
		cell.BackgroundTransparency = UIColors.slotTransparency
		cell.Parent = grid

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 7)
		corner.Parent = cell

		-- 은은한 발광(희귀 이상) - 셀보다 살짝 큰 별도 프레임을 뒤에 깐다(box-shadow 대체).
		local glow = Instance.new("Frame")
		glow.Name = "Glow"
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.Position = UDim2.new(0.5, 0, 0.5, 0)
		glow.Size = UDim2.new(1, 10, 1, 10)
		glow.BackgroundTransparency = 1
		glow.ZIndex = cell.ZIndex - 1
		glow.Parent = cell
		local glowCorner = Instance.new("UICorner")
		glowCorner.CornerRadius = UDim.new(0, 10)
		glowCorner.Parent = glow

		local gradeStroke = Instance.new("UIStroke")
		gradeStroke.Name = "GradeStroke"
		gradeStroke.Thickness = 1.5
		gradeStroke.Parent = cell

		local selectionStroke = Instance.new("UIStroke")
		selectionStroke.Name = "SelectionStroke"
		selectionStroke.Thickness = 2
		selectionStroke.Color = UIColors.ember
		-- 착용 요청 중에는 index가 밀려 있어(교체된 장비가 끝으로 간다) 선택 표시를 켜지 않는다 - 결과가 오면 새 선택이 그려진다(S20d).
		selectionStroke.Transparency = (S.selectedKind == "bag" and S.selectedValue == entry.index and not S.itemActions.isPending()) and 0 or 1
		selectionStroke.Parent = cell

		S.applyGradeVisual(cell, gradeStroke, glow, item.grade)

		local visual = ItemVisualData.gradeVisuals[item.grade]
		local iconColor = (visual and visual.rainbow) and Color3.new(1, 1, 1) or (visual and visual.color or UIColors.textPrimary)
		local iconHolder = Instance.new("Frame")
		iconHolder.AnchorPoint = Vector2.new(0.5, 0.5)
		iconHolder.Position = UDim2.new(0.5, 0, 0.5, 0)
		iconHolder.Size = UDim2.new(0, 30, 0, 30)
		iconHolder.BackgroundTransparency = 1
		iconHolder.Parent = cell
		local builder = ItemIcons.byPart[item.part or "armor"] or ItemIcons.byPart.armor
		builder(iconHolder, 30, iconColor)

		if item.locked then
			local lockHolder = Instance.new("Frame")
			lockHolder.AnchorPoint = Vector2.new(1, 0)
			lockHolder.Position = UDim2.new(1, -3, 0, 3)
			lockHolder.Size = UDim2.new(0, 13, 0, 13)
			lockHolder.BackgroundTransparency = 1
			lockHolder.Parent = cell
			ItemIcons.lock(lockHolder, 13, UIColors.xp)
		end

		-- 26-3(PRD 20.67 [12] "셀 하단 두 태그: [Lv.87] [위력]") - Lv 태그는 가방 셀에
		-- 처음 생긴다(기존엔 착용 슬롯에만 있었다). 옵션 태그는 있을 때만(옵션 없으면 태그
		-- 없음), 직업 불일치는 회색.
		local lvTag = Instance.new("TextLabel")
		lvTag.AnchorPoint = Vector2.new(1, 1)
		lvTag.Position = UDim2.new(1, -5, 1, -4)
		lvTag.Size = UDim2.new(0, 38, 0, 14)
		lvTag.BackgroundTransparency = 1
		lvTag.Font = Enum.Font.GothamBold
		lvTag.TextSize = Theme.textSize("caption")
		lvTag.TextXAlignment = Enum.TextXAlignment.Right
		lvTag.TextColor3 = UIColors.textTertiary
		lvTag.Text = ("Lv.%d"):format(item.itemLevel)
		lvTag.Parent = cell

		if item.option then
			local tag = ItemDescribe.optionTag(item, player:GetAttribute("ClassId")) -- S20: 옵션 이름 · 불일치 · 직업색은 ItemDescribe가 준다
			if tag then
				local optionTag = Instance.new("TextLabel")
				optionTag.AnchorPoint = Vector2.new(0, 1)
				optionTag.Position = UDim2.new(0, 3, 1, -4)
				optionTag.Size = UDim2.new(0, 38, 0, 14)
				optionTag.BackgroundTransparency = 1
				optionTag.Font = Enum.Font.GothamBold
				optionTag.TextSize = Theme.textSize("caption")
				optionTag.TextXAlignment = Enum.TextXAlignment.Left
				optionTag.TextTruncate = Enum.TextTruncate.AtEnd
				optionTag.TextColor3 = tag.mismatched and UIColors.textTertiary or (tag.accentClassId and UIColors.classAccent[tag.accentClassId]) or iconColor
				optionTag.Text = tag.text
				optionTag.Parent = cell
			end
		end

		-- S20d: PC 한 번 클릭 = 상세(기존) · 더블클릭 = 착용 · 우클릭 = 착용 / 탭 방식(폰)은 선택만 하고 상세의 [장착] 버튼이 착용한다. 착용 · 해제는 S.equipFromBag(ItemActions) 한 곳으로 간다.
		cell.Activated:Connect(function()
			if not S.tapMode() and isDoubleClick(entry.index) then
				S.equipFromBag(entry.index)
				return
			end
			selectBagIndex(entry.index)
		end)
		cell.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton2 then
				S.equipFromBag(entry.index)
			end
		end)

		cellFrames[entry.index] = cell
	end

	for i = #entries + 1, totalSlots do
		local cell = Instance.new("Frame")
		cell.Name = "EmptyCell_" .. i
		cell.LayoutOrder = i
		cell.BackgroundColor3 = UIColors.slot
		cell.BackgroundTransparency = 0.5
		cell.Parent = grid
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 7)
		corner.Parent = cell
		local stroke = Instance.new("UIStroke")
		stroke.Color = UIColors.rim
		stroke.Transparency = 0.4
		stroke.Parent = cell
	end

	countLabel.Text = ("%d / %d"):format(#S.inventory, totalSlots)
	local sellCount, sellTotal = S.bulkSellEstimate()
	bulkEstimatePillLabel.Text = ("일괄판매 예상 +%s"):format(NumberFormat.format(sellTotal))
	cutoffButton.Text = ArmorData.grades[S.bulkSellCutoffGrade].displayName .. " 이하 ▾"
	goldPillLabel.Text = "보유 골드 " .. NumberFormat.format(player:GetAttribute("Gold") or 0)

	if S.selectedKind == "bag" and not S.inventory[S.selectedValue] then
		S.selectedKind, S.selectedValue = nil, nil
	end
	S.refreshDetail()
end
S.rebuildGrid = rebuildGrid

RunService.RenderStepped:Connect(function(dt)
	if #S.rainbowGradients == 0 then
		return
	end
	local delta = dt * 40
	for _, gradient in ipairs(S.rainbowGradients) do
		gradient.Rotation = (gradient.Rotation + delta) % 360
	end
end)

sortButton.Activated:Connect(function()
	local currentIndex = table.find(S.SORT_MODES, S.sortMode) or 1
	S.sortMode = S.SORT_MODES[currentIndex % #S.SORT_MODES + 1]
	sortButton.Text = S.SORT_LABELS[S.sortMode] .. " ▾"
	S.rebuildGrid()
end)

-- 배치(S20b): 열 수 · 격자 높이 · 알약 줄 위치를 폭에서 다시 정한다.
table.insert(R.layouts, function(L)
	bag.Position = UDim2.new(0, L.mode == "phone" and 0 or (L.gearW + 1), 0, L.bodyTop)
	local viewHeight = L.bodyH - S.sheetInset
	bag.Size = L.mode == "phone" and UDim2.new(1, 0, 0, viewHeight) or UDim2.new(0, L.bagW, 0, viewHeight)
	local cols = L.bagCols
	local rows = math.ceil(SaveConfig.defaultInventorySlots / cols)
	local gridHeight = rows * CELL_SIZE + (rows - 1) * CELL_GAP
	gridLayout.FillDirectionMaxCells = cols
	grid.Size = UDim2.new(1, -28, 0, gridHeight)
	bagfoot.Position = UDim2.new(0, 14, 0, 34 + gridHeight + 12)
	bag.CanvasSize = UDim2.new(0, 0, 0, math.max(34 + gridHeight + 12 + 27 + 14, L.bodyH))
end)
end

return BagTab
