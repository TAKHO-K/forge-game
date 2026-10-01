local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local GradeColor = require(ReplicatedStorage.Shared.GradeColor)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local ItemDescribe = require(ReplicatedStorage.Shared.ItemDescribe)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Text = require(ReplicatedStorage.Shared.Text)
local ItemIcons = require(script.Parent.Parent.Parent.ItemIcons)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)
local Layout = require(script.Parent.Layout)
local ItemActions = require(script.Parent.ItemActions)
local ItemCell = require(script.Parent.ItemCell)
local CompareTip = require(script.Parent.CompareTip)

-- 가방 칸(S20b · QUEUE-ALL2 P2 ref 17) - 가운데 단: [정렬 · 자동 처리 · 일괄 판매 · 잠긴 것만] 줄 + 격자(스크롤) + 아래 줄(칸 수 · 골드 · 일괄판매 예상).
--   R.bagFrame = 가운데 단 Frame(PC) / "전체 · 갑옷 · 장갑 · 신발" 탭 본문(폰). 격자만 ScrollingFrame이다 - 정렬 · 자동 처리 버튼(자동 처리 드롭다운이 버튼 자식이라 스크롤 밖에 있어야 안 잘린다)은 PC에서 헤더에서 이 줄로 옮겨 온다(폰 = 헤더 그대로).
--   필터(S.bagFilter · S.lockedOnly)는 표시만 거른다 - 서버 index는 그대로(칸 이름 Cell_<서버 index>). 빈 칸(점선 대신 옅은 테두리)은 거르지 않은 "전체"에서만 그린다.
--   칸 읽는 법 = ItemCell(테두리 등급색 · 왼쪽 위 옵션 · 오른쪽 아래 Lv · 자물쇠 · 새 아이템 빨간 점 · 세트 문양). 비교 툴팁 = CompareTip(PC 마우스 올림 · 폰 길게 누름).
local BagTab = {}

function BagTab.create(S, R)
local player = S.player
local content = R.content
local countLabel, cutoffButton, sortButton, bulkSellButton = R.countLabel, R.cutoffButton, R.sortButton, R.bulkSellButton
local CELL_SIZE, CELL_GAP, GRID_PAD = Layout.cellSize, Layout.cellGap, Layout.gridPad
local FOOT_GAP = 10

local refs = {}
local function build()
	local column = Instance.new("Frame")
	column.Name = "Bag"
	column.BackgroundColor3 = UIColors.slot
	column.BackgroundTransparency = 0.55
	column.BorderSizePixel = 0
	column.Parent = content
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = column

	-- 정렬 / 필터 줄(PC). 드롭다운(자동 처리)이 아래 격자 위로 펼쳐지므로 ZIndex를 격자보다 높게 두지 않는다 - 드롭다운 자체가 ZIndex 25다(BulkSell).
	local filterRow = Instance.new("Frame")
	filterRow.Name = "FilterRow"
	filterRow.BackgroundTransparency = 1
	filterRow.Position = UDim2.new(0, GRID_PAD, 0, 8)
	filterRow.Parent = column
	local filterLayout = Instance.new("UIListLayout")
	filterLayout.FillDirection = Enum.FillDirection.Horizontal
	filterLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	filterLayout.Padding = UDim.new(0, 8)
	filterLayout.SortOrder = Enum.SortOrder.LayoutOrder
	filterLayout.Parent = filterRow

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Grid"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 5
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.Parent = column

	local grid = Instance.new("Frame")
	grid.Name = "Cells"
	grid.Position = UDim2.new(0, GRID_PAD, 0, 8)
	grid.BackgroundTransparency = 1
	grid.Parent = scroll
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, CELL_SIZE, 0, CELL_SIZE)
	gridLayout.CellPadding = UDim2.new(0, CELL_GAP, 0, CELL_GAP)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid

	local foot = Instance.new("Frame")
	foot.Name = "Foot"
	foot.BackgroundTransparency = 1
	foot.Parent = scroll
	local footLayout = Instance.new("UIListLayout")
	footLayout.FillDirection = Enum.FillDirection.Horizontal
	footLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	footLayout.Padding = UDim.new(0, 8)
	footLayout.SortOrder = Enum.SortOrder.LayoutOrder
	footLayout.Parent = foot

	local slotCount = Theme.label(foot, "", "caption", "textSecondary")
	slotCount.Name = "SlotCount"
	slotCount.LayoutOrder = 1
	slotCount.Font = Enum.Font.GothamBold
	slotCount.AutomaticSize = Enum.AutomaticSize.X
	slotCount.TextTruncate = Enum.TextTruncate.None
	slotCount.Size = UDim2.new(0, 0, 1, 0)

	local function makeFootPill(order, dangerStyle)
		local pill = Instance.new("Frame")
		pill.LayoutOrder = order
		pill.AutomaticSize = Enum.AutomaticSize.X
		pill.Size = UDim2.new(0, 0, 0, 26)
		pill.BackgroundColor3 = UIColors.panel
		pill.BackgroundTransparency = UIColors.panelTransparency
		pill.Parent = foot
		local pillCorner = Instance.new("UICorner")
		pillCorner.CornerRadius = UDim.new(1, 0)
		pillCorner.Parent = pill
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
	local goldPillLabel = makeFootPill(2, false)
	local bulkEstimatePillLabel = makeFootPill(3, true)

	-- "잠긴 것만" 칩(표시 필터 - 네모 칸 + ✓ 대신 채움 · 글씨 색도 바뀐다 = 색 + 모양)
	local lockChip = Instance.new("TextButton")
	lockChip.Name = "LockedOnlyChip"
	lockChip.AutoButtonColor = false
	lockChip.Text = ""
	lockChip.LayoutOrder = 5
	lockChip.Size = UDim2.new(0, 116, 0, 30)
	lockChip.BackgroundColor3 = UIColors.panel
	lockChip.BackgroundTransparency = UIColors.panelTransparency
	local chipCorner = Instance.new("UICorner")
	chipCorner.CornerRadius = UDim.new(1, 0)
	chipCorner.Parent = lockChip
	local chipStroke = Instance.new("UIStroke")
	chipStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	chipStroke.Color = UIColors.rim
	chipStroke.Transparency = UIColors.rimTransparency
	chipStroke.Parent = lockChip
	local box = Instance.new("Frame")
	box.Name = "Box"
	box.AnchorPoint = Vector2.new(0, 0.5)
	box.Position = UDim2.new(0, 10, 0.5, 0)
	box.Size = UDim2.new(0, 14, 0, 14)
	box.BackgroundColor3 = UIColors.slot
	box.Parent = lockChip
	local boxCorner = Instance.new("UICorner")
	boxCorner.CornerRadius = UDim.new(0, 3)
	boxCorner.Parent = box
	local boxStroke = Instance.new("UIStroke")
	boxStroke.Color = UIColors.textSecondary
	boxStroke.Parent = box
	local chipLabel = Theme.label(lockChip, Text.get("inv.filter.lockedOnly"), "caption", "textSecondary")
	chipLabel.Font = Enum.Font.GothamBold
	chipLabel.AnchorPoint = Vector2.new(0, 0.5)
	chipLabel.Position = UDim2.new(0, 30, 0.5, 0)
	chipLabel.Size = UDim2.new(1, -38, 1, 0)

	refs.column, refs.filterRow, refs.scroll, refs.grid, refs.gridLayout, refs.foot = column, filterRow, scroll, grid, gridLayout, foot
	refs.slotCount, refs.goldPillLabel, refs.bulkEstimatePillLabel = slotCount, goldPillLabel, bulkEstimatePillLabel
	refs.lockChip, refs.lockBox, refs.lockLabel = lockChip, box, chipLabel
end
build()

local column, scroll, grid = refs.column, refs.scroll, refs.grid
R.bagFrame = column
R.goldPillLabel = refs.goldPillLabel

local tip = CompareTip.create(R.screenGui)
S.compareTip = tip

local function paintLockChip()
	local on = S.lockedOnly
	refs.lockBox.BackgroundColor3 = on and UIColors.success or UIColors.slot
	refs.lockLabel.TextColor3 = on and UIColors.textPrimary or UIColors.textSecondary
end
paintLockChip()
refs.lockChip.Activated:Connect(function()
	S.lockedOnly = not S.lockedOnly
	paintLockChip()
	S.rebuildGrid()
end)

local cellFrames = {}
local isDoubleClick = ItemActions.doubleClickTracker() -- S20d: 가방 칸 더블클릭(0.35초) = 착용(찬 부위면 교체)

-- 착용 거절 연출의 좌표(S20d): 그 가방 칸 · 가방 영역의 중심(폰에서 이 탭이 안 보이면 nil).
function S.bagCellCenter(index)
	return S.visibleCenter(cellFrames[index])
end
function S.bagAreaCenter()
	return S.visibleCenter(scroll)
end

local function seen(index)
	if S.newItems and S.newItems.markSeen(index) then
		local cell = cellFrames[index]
		local dot = cell and cell:FindFirstChild("NewDot")
		if dot then
			dot.Visible = false
		end
	end
end

local function selectBagIndex(index)
	if S.selectedKind == "bag" and S.selectedValue == index then
		index = nil -- P3b C1: 같은 칸을 다시 누르면 상세가 닫힌다(선택 해제 - 토글). PC 더블클릭(0.35초 안)은 이 앞에서 착용으로 빠진다.
		S.selectedKind, S.selectedValue = nil, nil
	else
		S.selectedKind, S.selectedValue = "bag", index
		seen(index)
	end
	S.refreshDetail()
	for i, cell in pairs(cellFrames) do
		local selStroke = cell:FindFirstChild("SelectionStroke")
		if selStroke then
			selStroke.Transparency = (i == index) and 0 or 1
		end
	end
end

local function passesFilter(item)
	if S.bagFilter and (item.part or "armor") ~= S.bagFilter then
		return false
	end
	if S.lockedOnly and not item.locked then
		return false
	end
	return true
end

local function makeCell(entry, order)
	local item = entry.item
	local cell = Instance.new("TextButton")
	cell.Name = "Cell_" .. entry.index
	cell.LayoutOrder = order
	cell.Text = ""
	cell.AutoButtonColor = false
	cell.BackgroundColor3 = UIColors.slot
	cell.BackgroundTransparency = UIColors.slotTransparency
	cell.Parent = grid

	local selectionStroke = Instance.new("UIStroke")
	selectionStroke.Name = "SelectionStroke"
	selectionStroke.Thickness = 3
	selectionStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	selectionStroke.Color = Color3.new(1, 1, 1) -- ref 17: 고른 칸 = 흰 테두리
	-- 착용 요청 중에는 index가 밀려 있어(교체된 장비가 끝으로 간다) 선택 표시를 켜지 않는다 - 결과가 오면 새 선택이 그려진다(S20d).
	selectionStroke.Transparency = (S.selectedKind == "bag" and S.selectedValue == entry.index and not S.itemActions.isPending()) and 0 or 1
	selectionStroke.Parent = cell

	local iconColor = GradeColor.of(item.grade, UIColors.textPrimary) -- G1-1: 태초도 제 색
	local topLeft
	if item.option then
		local optionTag = ItemDescribe.optionTag(item, player:GetAttribute("ClassId")) -- S20: 옵션 이름 · 불일치 · 직업색은 ItemDescribe가 준다
		if optionTag then
			topLeft = { text = optionTag.text, color = optionTag.mismatched and UIColors.textTertiary or (optionTag.accentClassId and UIColors.classAccent[optionTag.accentClassId]) or iconColor }
		end
	end
	ItemCell.paint(cell, {
		gradeId = item.grade,
		part = item.part or "armor",
		iconKey = ItemIcons.keyFor(item.part or "armor", item.grade, item.itemLevel, nil, item.setZone), -- A2-N3 Open Cloud 아이콘(ArtStyleV1 뒤)
		iconColor = iconColor,
		iconSize = 30,
		topLeft = topLeft,
		level = item.itemLevel,
		locked = item.locked,
		isNew = S.newItems ~= nil and S.newItems.isNew(entry.index),
		setZone = item.setZone,
	}, S.applyGradeVisual)

	local consumeTap = tip.attach(cell, function()
		return S.inventory[entry.index]
	end, function(target)
		return S.equippedByPart()[target.part or "armor"]
	end, function()
		return player:GetAttribute("ClassId")
	end, function()
		seen(entry.index)
	end)

	-- S20d: PC 한 번 클릭 = 상세 · 더블클릭 = 착용 · 우클릭 = 착용 / 탭 방식(폰)은 선택만 하고 상세의 [장착] 버튼이 착용한다. 착용 · 해제는 S.equipFromBag(ItemActions) 한 곳으로 간다.
	cell.Activated:Connect(function()
		if consumeTap() then
			return -- 길게 눌러 비교를 본 손 뗌 - 선택으로 치지 않는다
		end
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
	return cell
end

local function rebuildGrid()
	for _, child in ipairs(grid:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	cellFrames = {}
	tip.hide()

	local entries = S.sortedEntries()
	local totalSlots = S.bagSlots
	local order = 0
	for _, entry in ipairs(entries) do
		if passesFilter(entry.item) then
			order += 1
			cellFrames[entry.index] = makeCell(entry, order)
		end
	end

	if not S.bagFilter and not S.lockedOnly then
		for i = #entries + 1, totalSlots do
			local cell = Instance.new("Frame")
			cell.Name = "EmptyCell_" .. i
			cell.LayoutOrder = i
			cell.BackgroundColor3 = UIColors.slot
			cell.BackgroundTransparency = 0.6
			cell.Parent = grid
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 8)
			corner.Parent = cell
			local stroke = Instance.new("UIStroke")
			stroke.Color = UIColors.rim
			stroke.Transparency = 0.55
			stroke.Parent = cell
		end
	end

	countLabel.Text = ("%d / %d"):format(#S.inventory, totalSlots)
	refs.slotCount.Text = Text.get("inv.bag.count", { used = tostring(#S.inventory), total = tostring(totalSlots) })
	local _, sellTotal = S.bulkSellEstimate()
	refs.bulkEstimatePillLabel.Text = Text.get("gear.bag.bulkEstimate", { gold = NumberFormat.format(sellTotal) })
	cutoffButton.Text = Text.get("gear.bag.cutoff", { grade = ArmorData.grades[S.bulkSellCutoffGrade].displayName }) -- QUEUE-ALL1 A-2(꺾쇠 = 도형)
	refs.goldPillLabel.Text = Text.get("gear.bag.gold", { gold = NumberFormat.format(player:GetAttribute("Gold") or 0) })

	if S.selectedKind == "bag" and not S.inventory[S.selectedValue] then
		S.selectedKind, S.selectedValue = nil, nil
	end
	if R.layout then
		R.layoutBag(R.layout) -- 보이는 칸 수가 바뀌면 격자 높이 · 아래 줄 자리도 바뀐다
	end
	if S.isOpen and column.Visible then
		S.bagViewed = true
	end
	S.refreshDetail()
end
S.rebuildGrid = rebuildGrid

-- 태초 무지개 테두리 회전(칸이 지워지면 그 그라디언트도 목록에서 빠진다 - 착용 칸 것과 같은 목록을 쓴다).
RunService.RenderStepped:Connect(function(dt)
	local list = S.rainbowGradients
	if #list == 0 then
		return
	end
	local delta = dt * 40
	for i = #list, 1, -1 do
		local gradient = list[i]
		if gradient.Parent == nil then
			table.remove(list, i)
		else
			gradient.Rotation = (gradient.Rotation + delta) % 360
		end
	end
end)

sortButton.Activated:Connect(function()
	local currentIndex = table.find(S.SORT_MODES, S.sortMode) or 1
	S.sortMode = S.SORT_MODES[currentIndex % #S.SORT_MODES + 1]
	sortButton.Text = S.SORT_LABELS[S.sortMode]
	S.rebuildGrid()
end)

-- 배치: 정렬 · 자동 처리 · 일괄 판매 버튼 자리(PC 가운데 단 폭 400 이상 = 이 줄 · 아니면 헤더) · 잠긴 것만 칩(넓은 PC = 이 줄 · 아니면 아래 줄) · 열 수 · 격자 높이.
function R.layoutBag(L)
	local phone = L.mode == "phone"
	local viewHeight = L.bagH - S.sheetInset
	column.Position = UDim2.new(0, L.bagX, 0, L.bagY)
	column.Size = UDim2.new(0, L.bagW, 0, math.max(0, viewHeight))
	column.BackgroundTransparency = phone and 1 or 0.55

	local pillsHere = not phone and L.bagW >= 400
	local chipHere = not phone and L.bagW >= 540
	local pillParent = pillsHere and refs.filterRow or R.headerRight
	for _, pill in ipairs({ sortButton, cutoffButton, bulkSellButton }) do
		if pill.Parent ~= pillParent then
			pill.Parent = pillParent
		end
	end
	local chipParent = chipHere and refs.filterRow or refs.foot
	if refs.lockChip.Parent ~= chipParent then
		refs.lockChip.Parent = chipParent
	end
	refs.lockChip.Size = UDim2.new(0, 116, 0, phone and 44 or 30)
	local filterH = pillsHere and (L.pillH + 8) or 0
	refs.filterRow.Size = UDim2.new(1, -2 * GRID_PAD, 0, math.max(0, filterH - 8))
	refs.filterRow.Visible = pillsHere

	local scrollTop = pillsHere and filterH + 4 or 0
	scroll.Position = UDim2.new(0, 0, 0, scrollTop)
	scroll.Size = UDim2.new(1, 0, 1, -scrollTop)

	local cols = L.bagCols
	local shown = 0
	for _, child in ipairs(grid:GetChildren()) do
		if child:IsA("GuiObject") then
			shown += 1
		end
	end
	local rows = math.max(math.ceil(math.max(shown, 1) / cols), 1)
	local gridWidth = cols * CELL_SIZE + (cols - 1) * CELL_GAP
	local gridHeight = rows * CELL_SIZE + (rows - 1) * CELL_GAP
	refs.gridLayout.FillDirectionMaxCells = cols
	grid.Position = UDim2.new(0, math.max(GRID_PAD, math.floor((L.bagW - gridWidth) / 2)), 0, 8)
	grid.Size = UDim2.new(0, gridWidth, 0, gridHeight)
	local footH = phone and 44 or 30
	refs.foot.Position = UDim2.new(0, grid.Position.X.Offset, 0, 8 + gridHeight + FOOT_GAP)
	refs.foot.Size = UDim2.new(1, -(grid.Position.X.Offset + GRID_PAD), 0, footH)
	scroll.CanvasSize = UDim2.new(0, 0, 0, 8 + gridHeight + FOOT_GAP + footH + 12)
end
table.insert(R.layouts, R.layoutBag)
end

return BagTab
