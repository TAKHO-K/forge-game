-- 가방·장비창(12-1 [3] 신설 → 16-3에서 `Claude outputs/inventory-mockup.html` 전면 반영).
-- 서버 권위 원칙은 그대로다 - 판매·착용·잠금은 전부 RemoteEvent로 서버(InventoryServer.
-- server.lua/PlayerProfile.lua)가 최종 판정한다. 이 파일은 그 결과(InventorySync)를
-- 받아 그리기만 한다 - 클라이언트가 낙관적으로 먼저 반영하는 부분(선택 상태·정렬)도
-- 서버 상태와 무관한 순수 표시 결정이라 서버 응답이 달라져도 되돌릴 게 없다.
--
-- 등급 색은 전부 ItemVisualData.gradeVisuals에서만 가져온다(지시 - "목업 hex를 여기저기
-- 흩뿌리지 마라, 단일 출처를 유지한다"). 부위 아이콘은 ItemIcons.lua(도형 조합, 이미지
-- 에셋 0개) - 무기 아이콘은 대각선으로 그렸다가 체크 표시처럼 보였다는 지시를 따라
-- 처음부터 수직으로 그렸다(ItemIcons.weapon 참고).
--
-- 16-6부터 갑옷·장갑·신발 3부위 전부 드랍·장착된다(EquipSlots.lua 단일 출처 - 웹의
-- ITEM_PARTS를 그대로 이식). 무기만 예외다 - 드랍/착용 대상이 아니라 강화대
-- (EnhanceUI.client.lua)에서 레벨만 올리는 캐릭터 고유 장비라, 장비 패널에서는 항상
-- "차 있는" 정보 표시 전용 슬롯으로 다룬다(판매·잠금·해제 대상이 아니다 - 클릭해도
-- 상세바에 정보만 보여주고 해제 버튼은 비활성).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local EquipSlots = require(ReplicatedStorage.Shared.data.EquipSlots)
local WeaponData = require(ReplicatedStorage.Shared.data.WeaponData)
local SaveConfig = require(ReplicatedStorage.Shared.data.SaveConfig)
local Loot = require(ReplicatedStorage.Shared.Loot)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local ItemIcons = require(script.Parent.ItemIcons)

local inventorySync = ReplicatedStorage:WaitForChild("InventorySync")
local inventoryFetch = ReplicatedStorage:WaitForChild("InventoryFetch")
local inventoryFull = ReplicatedStorage:WaitForChild("InventoryFull")
local equipRequest = ReplicatedStorage:WaitForChild("EquipRequest")
local sellRequest = ReplicatedStorage:WaitForChild("SellRequest")
local lockRequest = ReplicatedStorage:WaitForChild("LockRequest")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ═══ 치수(inventory-mockup.html 1080p 기준값 그대로) ═══
local WINDOW_WIDTH, WINDOW_HEIGHT = 720, 560
local HEADER_HEIGHT = 44
local DETAIL_HEIGHT = 86
local GEAR_WIDTH = 228
local CELL_SIZE, CELL_GAP = 78, 8
local GRID_COLS = 5
local GEAR_SLOT_SIZE = 95

-- 부위 목록은 EquipSlots.lua 하나에서만 나온다(지시 - "UI가 부위 목록을 하드코딩하면
-- 안 된다"). 장비 패널은 무기도 같이 보여주므로 그 앞에 하나만 덧붙인다 - 무기는
-- 드랍·장착 부위가 아니라서(EquipSlots.lua 주석) 거기 목록엔 없다.
local GEAR_ORDER = { "weapon" }
for _, part in ipairs(EquipSlots.order) do
	table.insert(GEAR_ORDER, part)
end

local PART_ORDER_INDEX = {}
for index, part in ipairs(GEAR_ORDER) do
	PART_ORDER_INDEX[part] = index
end

-- 서버 상태(InventorySync가 미는 스냅샷 그대로 - 이 배열의 인덱스가 서버 인덱스다).
local inventory = {}
local equippedArmor = nil
local equippedGloves = nil
local equippedShoes = nil

-- 부위 이름 -> 지금 착용 중인 아이템(nil이면 미착용). rebuildGearSlots/refreshDetail이
-- armor/gloves/shoes를 하나씩 따로 취급하지 않고 이 표 하나로 조회한다(16-6 - 부위가
-- 갑옷 하나였을 땐 없어도 됐지만 셋이 되니 하드코딩한 분기 3벌이 생길 뻔했다).
local function equippedByPart()
	return { armor = equippedArmor, gloves = equippedGloves, shoes = equippedShoes }
end

local sortMode = "grade" -- "grade" | "level" | "part" - 클라 전용 표시 순서, 서버 왕복 없음.
local SORT_MODES = { "grade", "level", "part" }
local SORT_LABELS = { grade = "등급순", level = "레벨순", part = "부위순" }

-- 선택 상태: kind="bag"이면 value=서버 인덱스, kind="equip"이면 value="weapon"/"armor".
local selectedKind, selectedValue = nil, nil

local isOpen = false
local rainbowGradients = {} -- 매 프레임 회전시켜야 하는 태초 등급 테두리 그라디언트 목록.

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "InventoryGui"
screenGui.ResetOnSpawn = false
-- 창을 열면 뒤 HUD(공격 버튼 등)를 완전히 덮어야 한다 - 다른 HUD ScreenGui들은 전부
-- 기본 DisplayOrder(0)라 이 값을 더 높여야 딤 배경이 실제로 위에서 클릭을 먹는다.
screenGui.DisplayOrder = 10
screenGui.Parent = playerGui

-- ═══ 열기 버튼(HUD, 항상 보임) ═══
local toggleButton = Instance.new("TextButton")
toggleButton.Name = "InventoryToggleButton"
toggleButton.AnchorPoint = Vector2.new(1, 0.5)
toggleButton.Position = UDim2.new(1, -16, 0.5, 0)
toggleButton.Size = UDim2.new(0, 90, 0, 36)
toggleButton.Text = "가방"
toggleButton.Font = Enum.Font.GothamBold
toggleButton.TextSize = 14
toggleButton.TextColor3 = UIColors.textPrimary
toggleButton.BackgroundColor3 = UIColors.panel
toggleButton.BackgroundTransparency = UIColors.panelTransparency
toggleButton.Parent = screenGui

do
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = toggleButton
	local stroke = Instance.new("UIStroke")
	stroke.Color = UIColors.rim
	stroke.Transparency = UIColors.rimTransparency
	stroke.Parent = toggleButton
end

-- ═══ 배경 딤(클릭을 먹는다) ═══
local dim = Instance.new("TextButton")
dim.Name = "Dim"
dim.Text = ""
dim.AutoButtonColor = false
dim.Size = UDim2.new(1, 0, 1, 0)
dim.BackgroundColor3 = UIColors.overlayDim
dim.BackgroundTransparency = 1 -- 닫힌 상태 시작값. 열 때 overlayDimTransparency로 트윈.
dim.Visible = false
dim.Parent = screenGui

-- ═══ 창 본체 ═══
-- 720x560은 목업의 1080p 기준값이다 - Studio 실측(16-3)에서 실제로 이 창이 뷰포트보다
-- 커서 위아래가 화면 밖으로 38px씩 잘리는 걸 확인했다(사용 가능 세로 484px인 창에 560
-- 높이를 그대로 꽂았을 때). 그래서 win은 뷰포트에 맞춰 매번 다시 계산한 크기만 갖고,
-- 실제 720x560 기준 레이아웃은 전부 안쪽 `content` 프레임(고정 크기)에 넣은 뒤
-- UIScale로 축소해서 보여준다 - 내부 자식들의 절대좌표 수식은 하나도 안 바꿔도 된다.
local win = Instance.new("Frame")
win.Name = "Window"
win.AnchorPoint = Vector2.new(0.5, 0.5)
win.Position = UDim2.new(0.5, 0, 0.5, 0)
win.Size = UDim2.new(0, WINDOW_WIDTH, 0, WINDOW_HEIGHT)
win.BackgroundTransparency = 1
win.ClipsDescendants = true
win.Visible = false
win.Parent = screenGui

local winCorner = Instance.new("UICorner")
winCorner.CornerRadius = UDim.new(0, 10)
winCorner.Parent = win

local winBackground = Instance.new("Frame")
winBackground.Name = "Background"
winBackground.Size = UDim2.new(1, 0, 1, 0)
winBackground.BackgroundColor3 = UIColors.panel
winBackground.BackgroundTransparency = 1 -- 닫힌 상태. panel-2(불투명0.86 -> Transparency0.14)로 트윈.
winBackground.BorderSizePixel = 0
winBackground.Parent = win
local winBackgroundCorner = Instance.new("UICorner")
winBackgroundCorner.CornerRadius = UDim.new(0, 10)
winBackgroundCorner.Parent = winBackground

local winStroke = Instance.new("UIStroke")
winStroke.Color = UIColors.rim
winStroke.Transparency = 1
winStroke.Parent = winBackground

local winScale = Instance.new("UIScale")
winScale.Scale = 0.94
winScale.Parent = win

-- 720x560 고정 캔버스 - 실제 자식(헤더·본문·상세바)은 전부 여기 붙는다.
local content = Instance.new("Frame")
content.Name = "Content"
content.AnchorPoint = Vector2.new(0.5, 0.5)
content.Position = UDim2.new(0.5, 0, 0.5, 0)
content.Size = UDim2.new(0, WINDOW_WIDTH, 0, WINDOW_HEIGHT)
content.BackgroundTransparency = 1
content.Parent = win

local contentScale = Instance.new("UIScale")
contentScale.Parent = content

-- 뷰포트(데스크톱 가로 짧은 창이든 모바일 세로든)에 맞춰 창 크기를 다시 계산한다 -
-- 가로/세로 중 더 빡빡한 쪽 기준으로 축소하고(=CSS object-fit:contain과 같은 계산),
-- 720x560보다 커지지는 않는다(min(1, ...)).
local function fitWindow()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	local inset = game:GetService("GuiService"):GetGuiInset()
	local availableWidth = viewport.X - inset.X * 2
	local availableHeight = viewport.Y - inset.Y - 16
	local scale = math.min(1, (availableWidth * 0.92) / WINDOW_WIDTH, (availableHeight * 0.92) / WINDOW_HEIGHT)
	win.Size = UDim2.new(0, WINDOW_WIDTH * scale, 0, WINDOW_HEIGHT * scale)
	contentScale.Scale = scale
end

fitWindow()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitWindow)

-- ═══ 헤더 ═══
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
header.BackgroundColor3 = Color3.new(0, 0, 0)
header.BackgroundTransparency = 0.78
header.Parent = content

local headerBottomLine = Instance.new("Frame")
headerBottomLine.AnchorPoint = Vector2.new(0, 1)
headerBottomLine.Position = UDim2.new(0, 0, 1, 0)
headerBottomLine.Size = UDim2.new(1, 0, 0, 1)
headerBottomLine.BackgroundColor3 = UIColors.rim
headerBottomLine.BackgroundTransparency = UIColors.rimTransparency
headerBottomLine.BorderSizePixel = 0
headerBottomLine.Parent = header

-- UIListLayout엔 CSS flex:1(남는 폭을 전부 먹는 스페이서) 같은 게 없다 - 억지로 계산해
-- 채우는 대신 왼쪽 묶음(제목·개수)과 오른쪽 묶음(정렬·일괄판매·닫기)을 서로 다른
-- AnchorPoint로 각각 왼쪽/오른쪽에 붙인다. 가운데는 그냥 빈다.
local headerLeft = Instance.new("Frame")
headerLeft.AnchorPoint = Vector2.new(0, 0.5)
headerLeft.Position = UDim2.new(0, 14, 0.5, 0)
headerLeft.AutomaticSize = Enum.AutomaticSize.X
headerLeft.Size = UDim2.new(0, 0, 0, 20)
headerLeft.BackgroundTransparency = 1
headerLeft.Parent = header

local headerLeftLayout = Instance.new("UIListLayout")
headerLeftLayout.FillDirection = Enum.FillDirection.Horizontal
headerLeftLayout.VerticalAlignment = Enum.VerticalAlignment.Center
headerLeftLayout.Padding = UDim.new(0, 8)
headerLeftLayout.SortOrder = Enum.SortOrder.LayoutOrder
headerLeftLayout.Parent = headerLeft

local headerRight = Instance.new("Frame")
headerRight.AnchorPoint = Vector2.new(1, 0.5)
headerRight.Position = UDim2.new(1, -14, 0.5, 0)
headerRight.AutomaticSize = Enum.AutomaticSize.X
headerRight.Size = UDim2.new(0, 0, 0, 26)
headerRight.BackgroundTransparency = 1
headerRight.Parent = header

local headerRightLayout = Instance.new("UIListLayout")
headerRightLayout.FillDirection = Enum.FillDirection.Horizontal
headerRightLayout.VerticalAlignment = Enum.VerticalAlignment.Center
headerRightLayout.Padding = UDim.new(0, 12)
headerRightLayout.SortOrder = Enum.SortOrder.LayoutOrder
headerRightLayout.Parent = headerRight

local title = Instance.new("TextLabel")
title.LayoutOrder = 1
title.BackgroundTransparency = 1
title.AutomaticSize = Enum.AutomaticSize.X
title.Size = UDim2.new(0, 0, 1, 0)
title.Font = Enum.Font.GothamBold
title.TextSize = 14.5
title.TextColor3 = UIColors.textPrimary
title.Text = "가방"
title.Parent = headerLeft

local countLabel = Instance.new("TextLabel")
countLabel.LayoutOrder = 2
countLabel.BackgroundTransparency = 1
countLabel.AutomaticSize = Enum.AutomaticSize.X
countLabel.Size = UDim2.new(0, 0, 1, 0)
countLabel.Font = Enum.Font.Gotham
countLabel.TextSize = 12 -- 16-6 [4]: 12px 미만 금지.
countLabel.TextColor3 = UIColors.textTertiary
countLabel.Text = "0 / 0"
countLabel.Parent = headerLeft

local function makeHeaderPill(text, order, widthPadding)
	local pill = Instance.new("TextButton")
	pill.LayoutOrder = order
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.Size = UDim2.new(0, 0, 0, 26)
	pill.BackgroundColor3 = UIColors.panel
	pill.BackgroundTransparency = UIColors.panelTransparency
	pill.Font = Enum.Font.GothamBold
	pill.TextSize = 12 -- 16-6 [4]: 12px 미만 금지.
	pill.TextColor3 = UIColors.textSecondary
	pill.Text = text
	pill.Parent = headerRight

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = pill
	local stroke = Instance.new("UIStroke")
	stroke.Color = UIColors.rim
	stroke.Transparency = UIColors.rimTransparency
	stroke.Parent = pill
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, widthPadding or 11)
	padding.PaddingRight = UDim.new(0, widthPadding or 11)
	padding.Parent = pill

	return pill
end

local sortButton = makeHeaderPill(SORT_LABELS[sortMode] .. " ▾", 1)

-- 등급 이름은 ArmorData.gradeOrder 마지막 항목에서 매번 다시 읽는다 - 등급이 늘어도
-- (영웅·전설 등) 이 라벨이 자동으로 "그 시점 최고 등급 이하 일괄판매"를 가리키게 하려는
-- 것이다(Loot.rollBossArmorDrop이 이미 쓰는 것과 같은 "마지막 항목 참조" 패턴).
local function highestGradeId()
	return ArmorData.gradeOrder[#ArmorData.gradeOrder]
end

local bulkSellButton = makeHeaderPill("", 2)

local closeButton = Instance.new("TextButton")
closeButton.LayoutOrder = 3
closeButton.Text = ""
closeButton.AutoButtonColor = false
closeButton.Size = UDim2.new(0, 26, 0, 26)
closeButton.BackgroundColor3 = UIColors.panel
closeButton.BackgroundTransparency = UIColors.panelTransparency
closeButton.Parent = headerRight
do
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = closeButton
	local stroke = Instance.new("UIStroke")
	stroke.Color = UIColors.rim
	stroke.Transparency = UIColors.rimTransparency
	stroke.Parent = closeButton
	-- X 표시 - 이모지·유니코드 글리프 대신 회전한 막대 2개(GoldHud 이후 이 프로젝트의
	-- 일관된 선택, 폰트 두부 문제를 원천 차단한다).
	for _, rotation in ipairs({ 45, -45 }) do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.new(0.5, 0, 0.5, 0)
		bar.Size = UDim2.new(0, 13, 0, 2)
		bar.Rotation = rotation
		bar.BackgroundColor3 = UIColors.textSecondary
		bar.BorderSizePixel = 0
		bar.Parent = closeButton
	end
end

-- ═══ 본문 ═══
local body = Instance.new("Frame")
body.Name = "Body"
body.Position = UDim2.new(0, 0, 0, HEADER_HEIGHT)
body.Size = UDim2.new(1, 0, 1, -(HEADER_HEIGHT + DETAIL_HEIGHT))
body.BackgroundTransparency = 1
body.Parent = content

-- ── 좌: 장비 패널 ──
local gear = Instance.new("Frame")
gear.Name = "Gear"
gear.Size = UDim2.new(0, GEAR_WIDTH, 1, 0)
gear.BackgroundTransparency = 1
gear.Parent = body

local gearRightLine = Instance.new("Frame")
gearRightLine.AnchorPoint = Vector2.new(1, 0)
gearRightLine.Position = UDim2.new(1, 0, 0, 0)
gearRightLine.Size = UDim2.new(0, 1, 1, 0)
gearRightLine.BackgroundColor3 = UIColors.rim
gearRightLine.BackgroundTransparency = UIColors.rimTransparency
gearRightLine.BorderSizePixel = 0
gearRightLine.Parent = gear

local function makeSectionLabel(parent, text, y)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(0, 14, 0, y)
	label.Size = UDim2.new(1, -28, 0, 14)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 12 -- 16-6 [4]: 12px 미만 금지.
	label.TextColor3 = UIColors.textTertiary
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.Parent = parent
	return label
end

makeSectionLabel(gear, "착용 중", 14)

local gearGrid = Instance.new("Frame")
gearGrid.Position = UDim2.new(0, 14, 0, 34)
gearGrid.Size = UDim2.new(1, -28, 0, GEAR_SLOT_SIZE * 2 + 9)
gearGrid.BackgroundTransparency = 1
gearGrid.Parent = gear

local gearGridLayout = Instance.new("UIGridLayout")
gearGridLayout.CellSize = UDim2.new(0, GEAR_SLOT_SIZE, 0, GEAR_SLOT_SIZE)
gearGridLayout.CellPadding = UDim2.new(0, 9, 0, 9)
gearGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gearGridLayout.Parent = gearGrid

local reserved = Instance.new("TextLabel")
reserved.Position = UDim2.new(0, 14, 0, 34 + GEAR_SLOT_SIZE * 2 + 9 + 12)
reserved.Size = UDim2.new(1, -28, 0, 89)
reserved.BackgroundTransparency = 1
reserved.Text = "특수 옵션 · 전설 이상에서 표시"
reserved.TextWrapped = true
reserved.Font = Enum.Font.GothamBold
reserved.TextSize = 12 -- 16-6 [4]: 12px 미만 금지.
reserved.TextColor3 = UIColors.textTertiary
reserved.Parent = gear
do
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = reserved
	local stroke = Instance.new("UIStroke")
	stroke.Color = UIColors.rim
	stroke.Transparency = 0.84
	stroke.Parent = reserved
end

-- 총 스탯 3줄. reserved 바로 아래, 위쪽 테두리로 구분한다(목업 .stats border-top).
local statsTop = 34 + GEAR_SLOT_SIZE * 2 + 9 + 12 + 89 + 12
local statsBorder = Instance.new("Frame")
statsBorder.Position = UDim2.new(0, 14, 0, statsTop)
statsBorder.Size = UDim2.new(1, -28, 0, 1)
statsBorder.BackgroundColor3 = UIColors.rim
statsBorder.BackgroundTransparency = UIColors.rimTransparency
statsBorder.BorderSizePixel = 0
statsBorder.Parent = gear

local function makeStatRow(labelText, valueColor, y)
	local row = Instance.new("Frame")
	row.Position = UDim2.new(0, 14, 0, y)
	row.Size = UDim2.new(1, -28, 0, 20)
	row.BackgroundTransparency = 1
	row.Parent = gear

	local key = Instance.new("TextLabel")
	key.BackgroundTransparency = 1
	key.Size = UDim2.new(0.5, 0, 1, 0)
	key.Font = Enum.Font.GothamBold
	key.TextSize = 12 -- 16-6 [4]: 12px 미만 금지.
	key.TextColor3 = UIColors.textTertiary
	key.TextXAlignment = Enum.TextXAlignment.Left
	key.Text = labelText
	key.Parent = row

	local value = Instance.new("TextLabel")
	value.AnchorPoint = Vector2.new(1, 0)
	value.Position = UDim2.new(1, 0, 0, 0)
	value.Size = UDim2.new(0.5, 0, 1, 0)
	value.BackgroundTransparency = 1
	value.Font = Enum.Font.GothamBold
	value.TextSize = 13
	value.TextColor3 = valueColor
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.Text = "-"
	value.Parent = row

	return value
end

local statsY = statsTop + 12
local atkValueLabel = makeStatRow("공격력", UIColors.ember, statsY)
local defValueLabel = makeStatRow("방어력", Color3.fromRGB(127, 179, 232), statsY + 26)
local hpValueLabel = makeStatRow("최대 체력", UIColors.hp, statsY + 52)

-- ── 우: 보관함 ──
local bag = Instance.new("Frame")
bag.Name = "Bag"
bag.Position = UDim2.new(0, GEAR_WIDTH + 1, 0, 0)
bag.Size = UDim2.new(1, -(GEAR_WIDTH + 1), 1, 0)
bag.BackgroundTransparency = 1
bag.Parent = body

makeSectionLabel(bag, "보관함", 14)

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
	label.TextSize = 12 -- 16-6 [4]: 12px 미만 금지.
	label.TextColor3 = dangerStyle and Color3.fromRGB(255, 141, 141) or UIColors.textSecondary
	label.Text = ""
	label.Parent = pill

	return label
end

local goldPillLabel = makeFootPill(false)
local bulkEstimatePillLabel = makeFootPill(true)

-- ═══ 하단 상세바 ═══
local detail = Instance.new("Frame")
detail.Name = "Detail"
detail.AnchorPoint = Vector2.new(0, 1)
detail.Position = UDim2.new(0, 0, 1, 0)
detail.Size = UDim2.new(1, 0, 0, DETAIL_HEIGHT)
detail.BackgroundColor3 = Color3.new(0, 0, 0)
detail.BackgroundTransparency = 0.74
detail.Parent = content

local detailTopLine = Instance.new("Frame")
detailTopLine.Size = UDim2.new(1, 0, 0, 1)
detailTopLine.BackgroundColor3 = UIColors.rim
detailTopLine.BackgroundTransparency = UIColors.rimTransparency
detailTopLine.BorderSizePixel = 0
detailTopLine.Parent = detail

local detailPadding = Instance.new("UIPadding")
detailPadding.PaddingLeft = UDim.new(0, 16)
detailPadding.PaddingRight = UDim.new(0, 16)
detailPadding.Parent = detail

-- 헤더와 같은 이유로 UIListLayout 하나에 flex 스페이서를 넣지 않는다 - dpic·dinfo는
-- 왼쪽에 절대 위치로, 버튼 3개(dact)는 오른쪽에 붙는 별도 그룹으로 나눈다.
local dpic = Instance.new("Frame")
dpic.AnchorPoint = Vector2.new(0, 0.5)
dpic.Position = UDim2.new(0, 0, 0.5, 0)
dpic.Size = UDim2.new(0, 56, 0, 56)
dpic.BackgroundColor3 = UIColors.slot
dpic.BackgroundTransparency = UIColors.slotTransparency
dpic.Parent = detail
local dpicCorner = Instance.new("UICorner")
dpicCorner.CornerRadius = UDim.new(0, 8)
dpicCorner.Parent = dpic
local dpicStroke = Instance.new("UIStroke")
dpicStroke.Thickness = 1.5
dpicStroke.Color = UIColors.rim
dpicStroke.Transparency = UIColors.rimTransparency
dpicStroke.Parent = dpic

local dinfo = Instance.new("Frame")
dinfo.Position = UDim2.new(0, 70, 0, 0)
dinfo.Size = UDim2.new(1, -260, 1, 0)
dinfo.BackgroundTransparency = 1
dinfo.Parent = detail

local dname = Instance.new("TextLabel")
dname.Position = UDim2.new(0, 0, 0, 14)
dname.Size = UDim2.new(1, 0, 0, 18)
dname.BackgroundTransparency = 1
dname.Font = Enum.Font.GothamBold
dname.TextSize = 14
dname.TextXAlignment = Enum.TextXAlignment.Left
dname.TextColor3 = UIColors.textPrimary
dname.Text = "선택된 아이템 없음"
dname.Parent = dinfo

local dmeta = Instance.new("TextLabel")
dmeta.Position = UDim2.new(0, 0, 0, 36)
dmeta.Size = UDim2.new(1, 0, 0, 16)
dmeta.BackgroundTransparency = 1
dmeta.Font = Enum.Font.Gotham
dmeta.TextSize = 12 -- 16-6 [4]: 12px 미만 금지.
dmeta.TextXAlignment = Enum.TextXAlignment.Left
dmeta.TextColor3 = UIColors.textTertiary
dmeta.Text = ""
dmeta.Parent = dinfo

-- 버튼 3개 묶음 - 화면 오른쪽에 붙는다.
local dact = Instance.new("Frame")
dact.AnchorPoint = Vector2.new(1, 0.5)
dact.Position = UDim2.new(1, 0, 0.5, 0)
dact.AutomaticSize = Enum.AutomaticSize.X
dact.Size = UDim2.new(0, 0, 0, 34)
dact.BackgroundTransparency = 1
dact.Parent = detail

local dactLayout = Instance.new("UIListLayout")
dactLayout.FillDirection = Enum.FillDirection.Horizontal
dactLayout.VerticalAlignment = Enum.VerticalAlignment.Center
dactLayout.Padding = UDim.new(0, 7)
dactLayout.SortOrder = Enum.SortOrder.LayoutOrder
dactLayout.Parent = dact

local function makeActionButton(order, width, style)
	local btn = Instance.new("TextButton")
	btn.LayoutOrder = order
	btn.Text = ""
	btn.Size = UDim2.new(0, width, 0, 34)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 12.5
	btn.Parent = dact

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = btn
	local stroke = Instance.new("UIStroke")
	stroke.Parent = btn

	if style == "primary" then
		btn.BackgroundColor3 = UIColors.ember
		btn.BackgroundTransparency = 0.72
		btn.TextColor3 = Color3.fromRGB(255, 217, 191)
		stroke.Color = UIColors.ember
		stroke.Transparency = 0.38
	elseif style == "sell" then
		btn.BackgroundColor3 = UIColors.panel
		btn.BackgroundTransparency = UIColors.panelTransparency
		btn.TextColor3 = UIColors.gold
		stroke.Color = UIColors.gold
		stroke.Transparency = 0.58
	else
		btn.BackgroundColor3 = UIColors.panel
		btn.BackgroundTransparency = UIColors.panelTransparency
		btn.TextColor3 = UIColors.textPrimary
		stroke.Color = UIColors.rim
		stroke.Transparency = UIColors.rimTransparency
	end

	return btn, stroke
end

local lockButton = makeActionButton(1, 36, "lock")
local lockIconHolder = Instance.new("Frame")
lockIconHolder.AnchorPoint = Vector2.new(0.5, 0.5)
lockIconHolder.Position = UDim2.new(0.5, 0, 0.5, 0)
lockIconHolder.Size = UDim2.new(0, 14, 0, 14)
lockIconHolder.BackgroundTransparency = 1
lockIconHolder.Parent = lockButton
ItemIcons.lock(lockIconHolder, 14, UIColors.xp)

local sellButton = makeActionButton(2, 76, "sell")
sellButton.Text = "판매"

local equipButton = makeActionButton(3, 84, "primary")
equipButton.Text = "착용"

-- ═══ 등급 시각 효과 ═══

-- 등급색 + 발광. 칸 배경은 등급과 무관하게 동일해야 하지만(지시 - "칸 내부 배경은 모든
-- 등급이 동일"), 5% 정도 등급색 쪽으로 당기면 색이 한눈에 더 잘 읽힌다(지시가 준 두
-- 대안 중 "더 간단한 쪽"을 골랐다 - 이중 UIStroke보다 셀 하나에 손대는 쪽이 20칸을
-- 한 번에 그릴 때 더 가볍다). 발광은 ItemVisualData.gradeVisuals.glowBrightness를 그대로
-- 재사용한다(14-1이 이미 정의해 둔 등급별 세기 - 여기서 새 숫자를 만들지 않는다).
local function blendToward(base, target, ratio)
	return Color3.new(
		base.R + (target.R - base.R) * ratio,
		base.G + (target.G - base.G) * ratio,
		base.B + (target.B - base.B) * ratio
	)
end

-- 태초(rainbow=true) 등급 테두리 - 여기서는 로블록스가 CSS보다 유리하다(지시). UIStroke에
-- UIGradient(무지개 ColorSequence)를 붙이고 매 프레임 Rotation을 돌리면 CSS conic-gradient
-- 정지 이미지보다 나은, 실제로 흐르는 테두리가 된다.
local RAINBOW_SEQUENCE = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
	ColorSequenceKeypoint.new(1 / 6, Color3.fromRGB(242, 196, 61)),
	ColorSequenceKeypoint.new(2 / 6, Color3.fromRGB(95, 211, 107)),
	ColorSequenceKeypoint.new(3 / 6, Color3.fromRGB(59, 209, 192)),
	ColorSequenceKeypoint.new(4 / 6, Color3.fromRGB(74, 158, 232)),
	ColorSequenceKeypoint.new(5 / 6, Color3.fromRGB(169, 123, 232)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 90, 90)),
})

-- cellFrame에 등급 시각 효과를 입힌다. grade가 nil이면(빈 칸) 아무것도 하지 않는다 -
-- 호출부가 이미 점선 빈 칸 스타일을 따로 그렸다.
local function applyGradeVisual(cellFrame, gradeStroke, glowFrame, gradeId)
	local visual = ItemVisualData.gradeVisuals[gradeId]
	if not visual then
		return
	end

	if visual.rainbow then
		gradeStroke.Color = Color3.new(1, 1, 1)
		gradeStroke.Transparency = 0
		local gradient = Instance.new("UIGradient")
		gradient.Color = RAINBOW_SEQUENCE
		gradient.Parent = gradeStroke
		table.insert(rainbowGradients, gradient)
		glowFrame.BackgroundTransparency = 0.8
		glowFrame.BackgroundColor3 = Color3.new(1, 1, 1)
		return
	end

	gradeStroke.Color = visual.color
	gradeStroke.Transparency = 0
	cellFrame.BackgroundColor3 = blendToward(UIColors.slot, visual.color, 0.05)

	if gradeId ~= "normal" then
		glowFrame.BackgroundColor3 = visual.color
		glowFrame.BackgroundTransparency = math.clamp(1 - (visual.glowBrightness / 5) * 0.6, 0.4, 0.95)
	end
end

-- ═══ 선택·정렬·판매 대상 계산 ═══

-- 정렬은 표시 순서만 바꾼다 - {item, serverIndex} 짝을 유지해서 서버 인덱스는 항상
-- 원본 그대로 남긴다(사용자 지시: "실제 인스턴스를 훑어라" 원칙과 같은 이유로, 표시
-- 순서와 서버 진실을 섞으면 나중에 반드시 잠금/판매가 엉뚱한 칸에 걸리는 버그가 난다).
local function sortedEntries()
	local entries = {}
	for i, item in ipairs(inventory) do
		table.insert(entries, { item = item, index = i })
	end

	if sortMode == "grade" then
		table.sort(entries, function(a, b)
			local ai, bi = 0, 0
			for i, id in ipairs(ArmorData.gradeOrder) do
				if id == a.item.grade then ai = i end
				if id == b.item.grade then bi = i end
			end
			return ai > bi
		end)
	elseif sortMode == "level" then
		table.sort(entries, function(a, b)
			return a.item.itemLevel > b.item.itemLevel
		end)
	elseif sortMode == "part" then
		table.sort(entries, function(a, b)
			local ap = PART_ORDER_INDEX[a.item.part or "armor"] or 99
			local bp = PART_ORDER_INDEX[b.item.part or "armor"] or 99
			return ap < bp
		end)
	end

	return entries
end

local function isSellableGrade(gradeId, cutoffId)
	local cutoffIndex
	for i, id in ipairs(ArmorData.gradeOrder) do
		if id == cutoffId then
			cutoffIndex = i
		end
	end
	for i, id in ipairs(ArmorData.gradeOrder) do
		if id == gradeId then
			return cutoffIndex ~= nil and i <= cutoffIndex
		end
	end
	return false
end

local function bulkSellEstimate()
	local cutoff = highestGradeId()
	local count, total = 0, 0
	for _, item in ipairs(inventory) do
		if not item.locked and isSellableGrade(item.grade, cutoff) then
			count += 1
			total += Loot.getSellPrice(item)
		end
	end
	return count, total
end

-- ═══ 상세바 갱신 ═══

local function describeItemName(item)
	local grade = ArmorData.grades[item.grade]
	local partName = ItemVisualData.partDisplayNames[item.part or "armor"] or "장비"
	return (grade and grade.displayName or item.grade) .. " " .. partName
end

-- 착용 중 슬롯 상세 문구(16-6) - 부위마다 보여줄 스탯이 다르다(갑옷=방어력 flat, 장갑·
-- 신발=비율%). EquipSlots.statType으로 어느 쪽인지 구분하지 않고 부위별로 직접 나열한
-- 이유는 세 부위의 "어떻게 보여줄지"(단위·서식)까지 같지 않아서다 - statType은 서버
-- 계산(PlayerCombat)이 쓰는 축이고, 이건 순수 표시 문제라 축을 하나 더 만들지 않았다.
local PART_META_TEXT = {
	armor = function(item)
		return ("%s · Lv.%d · 방어력 %s"):format(
			ItemVisualData.partDisplayNames.armor, item.itemLevel, NumberFormat.format(Loot.getArmorDefense(item)))
	end,
	gloves = function(item)
		return ("%s · Lv.%d · 공격력 +%.0f%%"):format(
			ItemVisualData.partDisplayNames.gloves, item.itemLevel, Loot.getGlovesAttackPercent(item) * 100)
	end,
	shoes = function(item)
		return ("%s · Lv.%d · 이동+공속 +%.0f%%"):format(
			ItemVisualData.partDisplayNames.shoes, item.itemLevel, Loot.getShoesSpeedPercent(item) * 100)
	end,
}

local function clearDetail()
	dname.Text = "선택된 아이템 없음"
	dname.TextColor3 = UIColors.textTertiary
	dmeta.Text = ""
	for _, child in ipairs(dpic:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	dpicStroke.Color = UIColors.rim
	dpicStroke.Transparency = UIColors.rimTransparency

	lockButton.AutoButtonColor = false
	lockButton.Active = false
	lockIconHolder.Visible = false
	sellButton.AutoButtonColor = false
	sellButton.Active = false
	sellButton.TextTransparency = 0.6
	equipButton.AutoButtonColor = false
	equipButton.Active = false
	equipButton.TextTransparency = 0.6
	equipButton.Text = "착용"
end

local function setDpicIcon(partId, color)
	for _, child in ipairs(dpic:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local builder = ItemIcons.byPart[partId] or ItemIcons.byPart.armor
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.new(0.5, 0, 0.5, 0)
	holder.Size = UDim2.new(0, 28, 0, 28)
	holder.BackgroundTransparency = 1
	holder.Parent = dpic
	builder(holder, 28, color)
end

local function refreshDetail()
	if selectedKind == "bag" then
		local item = inventory[selectedValue]
		if not item then
			selectedKind, selectedValue = nil, nil
			clearDetail()
			return
		end
		local visual = ItemVisualData.gradeVisuals[item.grade]
		local color = visual and visual.color or UIColors.textPrimary
		dname.Text = describeItemName(item)
		dname.TextColor3 = color
		dmeta.Text = ("%s · Lv.%d · 방어력 %s · 판매가 %s"):format(
			ItemVisualData.partDisplayNames[item.part or "armor"] or "장비",
			item.itemLevel,
			NumberFormat.format(Loot.getArmorDefense(item)),
			NumberFormat.format(Loot.getSellPrice(item))
		)
		setDpicIcon(item.part or "armor", color)
		dpicStroke.Color = color
		dpicStroke.Transparency = 0

		lockButton.AutoButtonColor = true
		lockButton.Active = true
		lockIconHolder.Visible = true
		sellButton.AutoButtonColor = true
		sellButton.Active = true
		sellButton.TextTransparency = item.locked and 0.6 or 0
		equipButton.AutoButtonColor = true
		equipButton.Active = true
		equipButton.TextTransparency = 0
		equipButton.Text = "착용"
	elseif selectedKind == "equip" and selectedValue ~= "weapon" and equippedByPart()[selectedValue] then
		local part = selectedValue
		local item = equippedByPart()[part]
		local visual = ItemVisualData.gradeVisuals[item.grade]
		local color = visual and visual.color or UIColors.textPrimary
		dname.Text = describeItemName(item) .. " (착용 중)"
		dname.TextColor3 = color
		dmeta.Text = PART_META_TEXT[part](item)
		setDpicIcon(item.part or part, color)
		dpicStroke.Color = color
		dpicStroke.Transparency = 0

		lockButton.AutoButtonColor = false
		lockButton.Active = false
		lockIconHolder.Visible = false
		sellButton.AutoButtonColor = false
		sellButton.Active = false
		sellButton.TextTransparency = 0.6
		equipButton.AutoButtonColor = true
		equipButton.Active = true
		equipButton.TextTransparency = 0
		equipButton.Text = "해제"
	elseif selectedKind == "equip" and selectedValue == "weapon" then
		local weaponLevel = player:GetAttribute("WeaponLevel") or 0
		local weaponData = WeaponData.weapons[WeaponData.starterId]
		dname.Text = weaponData.displayName
		dname.TextColor3 = UIColors.textPrimary
		dmeta.Text = ("무기 · Lv.%d · 강화대에서 강화"):format(weaponLevel)
		setDpicIcon("weapon", UIColors.textPrimary)
		dpicStroke.Color = UIColors.rim
		dpicStroke.Transparency = UIColors.rimTransparency

		lockButton.AutoButtonColor = false
		lockButton.Active = false
		lockIconHolder.Visible = false
		sellButton.AutoButtonColor = false
		sellButton.Active = false
		sellButton.TextTransparency = 0.6
		equipButton.AutoButtonColor = false
		equipButton.Active = false
		equipButton.TextTransparency = 0.6
		equipButton.Text = "착용"
	else
		clearDetail()
	end
end

-- ═══ 총 스탯 갱신 ═══

local function refreshStats()
	local classId = player:GetAttribute("ClassId")
	local maxHp = player:GetAttribute("MaxHp")
	hpValueLabel.Text = maxHp and NumberFormat.format(maxHp) or "-"

	if not classId or classId == "" then
		atkValueLabel.Text = "-"
		defValueLabel.Text = "-"
		return
	end

	local weaponLevel = player:GetAttribute("WeaponLevel") or 0
	local characterLevel = player:GetAttribute("CharacterLevel") or 1
	local weapon = { id = WeaponData.starterId, level = weaponLevel }
	-- 16-6: 장갑 공격력% 보너스가 공격력 계산에 들어간다 - 서버(AttackServer)와 같은
	-- PlayerCombat.getAttack 4번째 인자를 그대로 쓴다.
	local attack = PlayerCombat.getAttack(weapon, classId, characterLevel, Loot.getGlovesAttackPercent(equippedGloves))
	local defense = PlayerCombat.getDefense(classId, Loot.getArmorDefense(equippedArmor))

	atkValueLabel.Text = NumberFormat.format(attack)
	defValueLabel.Text = NumberFormat.format(defense)
end

-- ═══ 격자 다시 그리기 ═══

local function rebuildGearSlots()
	for _, child in ipairs(gearGrid:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextButton") then
			child:Destroy()
		end
	end

	local equipped = equippedByPart()

	for order, part in ipairs(GEAR_ORDER) do
		local filled = part == "weapon" or equipped[part] ~= nil
		-- 16-6부터 갑옷·장갑·신발 전부 실제로 착용·해제할 수 있다 - 셋 다 클릭 가능.
		local interactive = true

		local slot = Instance.new(interactive and "TextButton" or "Frame")
		slot.Name = "Gear_" .. part
		slot.LayoutOrder = order
		slot.BackgroundColor3 = UIColors.slot
		slot.BackgroundTransparency = UIColors.slotTransparency
		if slot:IsA("TextButton") then
			slot.Text = ""
			slot.AutoButtonColor = false
		end
		slot.Parent = gearGrid

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 7)
		corner.Parent = slot

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1.5
		stroke.Parent = slot

		local color = UIColors.textTertiary
		if filled then
			if part == "weapon" then
				color = UIColors.textPrimary
				stroke.Color = UIColors.rim
				stroke.Transparency = UIColors.rimTransparency
			else
				local visual = ItemVisualData.gradeVisuals[equipped[part].grade]
				color = visual and visual.color or UIColors.textPrimary
				stroke.Color = color
				stroke.Transparency = 0
			end
		else
			-- 빈 슬롯은 점선(지시 - "아직 못 채운 칸이 눈에 보여야 파밍 동기가 생긴다").
			stroke.Color = UIColors.rim
			stroke.Transparency = 0.4
			-- Roblox UIStroke는 점선을 못 그린다(LineJoinMode/ApplyStrokeMode 어느 쪽도
			-- 점선 옵션이 없다) - 대신 살짝 더 옅고 배경을 더 어둡게 해 "비어 있다"는
			-- 인상을 준다(색만으로 구분, 목업의 점선 대체).
			slot.BackgroundTransparency = 0.5
		end

		local iconHolder = Instance.new("Frame")
		iconHolder.AnchorPoint = Vector2.new(0.5, 0.42)
		iconHolder.Position = UDim2.new(0.5, 0, 0.42, 0)
		iconHolder.Size = UDim2.new(0, 26, 0, 26)
		iconHolder.BackgroundTransparency = 1
		iconHolder.Parent = slot
		ItemIcons.byPart[part](iconHolder, 26, color)

		local nameLabel = Instance.new("TextLabel")
		nameLabel.AnchorPoint = Vector2.new(0.5, 1)
		nameLabel.Position = UDim2.new(0.5, 0, 1, -8)
		nameLabel.Size = UDim2.new(1, -8, 0, 14) -- 16-6 [4]: 9.5->12px로 키운 만큼 높이도 12->14.
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 12
		nameLabel.TextColor3 = filled and UIColors.textSecondary or UIColors.textTertiary
		nameLabel.Text = ItemVisualData.partDisplayNames[part]
		nameLabel.Parent = slot

		if filled then
			local level = part == "weapon" and (player:GetAttribute("WeaponLevel") or 0) or equipped[part].itemLevel
			local lvTag = Instance.new("TextLabel")
			lvTag.AnchorPoint = Vector2.new(1, 1)
			lvTag.Position = UDim2.new(1, -5, 1, -4)
			lvTag.Size = UDim2.new(0, 38, 0, 14) -- 16-6 [4]: 9->12px로 키운 만큼 높이도 12->14, 폭도 34->38.
			lvTag.BackgroundTransparency = 1
			lvTag.Font = Enum.Font.GothamBold
			lvTag.TextSize = 12
			lvTag.TextXAlignment = Enum.TextXAlignment.Right
			lvTag.TextColor3 = UIColors.textTertiary
			lvTag.Text = ("Lv.%d"):format(level)
			lvTag.Parent = slot
		end

		if interactive then
			slot.Activated:Connect(function()
				if part == "weapon" then
					selectedKind, selectedValue = "equip", "weapon"
				elseif filled then
					selectedKind, selectedValue = "equip", part
				else
					return -- 빈 슬롯은 선택할 게 없다(착용된 것도, 보관함에서 고른 것도 아니다).
				end
				refreshDetail()
			end)
		end
	end
end

local cellFrames = {}

local function selectBagIndex(index)
	selectedKind, selectedValue = "bag", index
	refreshDetail()
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
	rainbowGradients = {}

	local entries = sortedEntries()
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
		selectionStroke.Transparency = (selectedKind == "bag" and selectedValue == entry.index) and 0 or 1
		selectionStroke.Parent = cell

		applyGradeVisual(cell, gradeStroke, glow, item.grade)

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

		cell.Activated:Connect(function()
			selectBagIndex(entry.index)
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

	countLabel.Text = ("%d / %d"):format(#inventory, totalSlots)
	local sellCount, sellTotal = bulkSellEstimate()
	bulkEstimatePillLabel.Text = ("일괄판매 예상 +%s"):format(NumberFormat.format(sellTotal))
	bulkSellButton.Text = (highestGradeId() and ArmorData.grades[highestGradeId()].displayName or "") .. " 이하 일괄판매"
	goldPillLabel.Text = "보유 골드 " .. NumberFormat.format(player:GetAttribute("Gold") or 0)

	if selectedKind == "bag" and not inventory[selectedValue] then
		selectedKind, selectedValue = nil, nil
	end
	refreshDetail()
end

RunService.RenderStepped:Connect(function(dt)
	if #rainbowGradients == 0 then
		return
	end
	local delta = dt * 40
	for _, gradient in ipairs(rainbowGradients) do
		gradient.Rotation = (gradient.Rotation + delta) % 360
	end
end)

-- ═══ 열기/닫기 ═══

local function setOpen(open)
	isOpen = open
	if open then
		dim.Visible = true
		win.Visible = true
		fitWindow() -- 닫혀 있는 동안 화면 크기가 바뀌었을 수 있다(창 회전 등).
		rebuildGearSlots()
		rebuildGrid()
		refreshStats()
	end

	local tweenInfo = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(dim, tweenInfo, {
		BackgroundTransparency = open and UIColors.overlayDimTransparency or 1,
	}):Play()
	TweenService:Create(winBackground, tweenInfo, { BackgroundTransparency = open and 0.14 or 1 }):Play()
	TweenService:Create(winStroke, tweenInfo, { Transparency = open and UIColors.rimTransparency or 1 }):Play()
	local scaleTween = TweenService:Create(winScale, tweenInfo, { Scale = open and 1 or 0.94 })
	scaleTween:Play()

	if not open then
		scaleTween.Completed:Wait()
		dim.Visible = false
		win.Visible = false
	end
end

toggleButton.Activated:Connect(function()
	setOpen(not isOpen)
end)

dim.Activated:Connect(function()
	setOpen(false)
end)

closeButton.Activated:Connect(function()
	setOpen(false)
end)

sortButton.Activated:Connect(function()
	local currentIndex = table.find(SORT_MODES, sortMode) or 1
	sortMode = SORT_MODES[currentIndex % #SORT_MODES + 1]
	sortButton.Text = SORT_LABELS[sortMode] .. " ▾"
	rebuildGrid()
end)

-- ═══ 일괄판매 확인 창 ═══
-- 되돌릴 수 없는 동작이라(지시) 실행 전 작은 확인 팝업을 하나 더 띄운다. 창 안에 또
-- 하나의 작은 딤+패널을 겹치는 구조 - 별도 ScreenGui를 만들지 않고 이 창의 자식으로
-- 두면 열려 있을 때만(win이 보일 때만) 같이 보이고 닫힐 때 같이 정리된다.
local confirmOverlay = Instance.new("TextButton")
confirmOverlay.Text = ""
confirmOverlay.AutoButtonColor = false
confirmOverlay.Size = UDim2.new(1, 0, 1, 0)
confirmOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
confirmOverlay.BackgroundTransparency = 0.5
confirmOverlay.Visible = false
confirmOverlay.ZIndex = 20
confirmOverlay.Parent = content

local confirmBox = Instance.new("Frame")
confirmBox.AnchorPoint = Vector2.new(0.5, 0.5)
confirmBox.Position = UDim2.new(0.5, 0, 0.5, 0)
confirmBox.Size = UDim2.new(0, 300, 0, 140)
confirmBox.BackgroundColor3 = UIColors.panel
confirmBox.BackgroundTransparency = 0.05
confirmBox.ZIndex = 21
confirmBox.Parent = confirmOverlay
local confirmCorner = Instance.new("UICorner")
confirmCorner.CornerRadius = UDim.new(0, 10)
confirmCorner.Parent = confirmBox
local confirmStroke = Instance.new("UIStroke")
confirmStroke.Color = UIColors.rim
confirmStroke.Transparency = UIColors.rimTransparency
confirmStroke.Parent = confirmBox

local confirmText = Instance.new("TextLabel")
confirmText.Position = UDim2.new(0, 16, 0, 16)
confirmText.Size = UDim2.new(1, -32, 0, 64)
confirmText.BackgroundTransparency = 1
confirmText.ZIndex = 21
confirmText.Font = Enum.Font.GothamBold
confirmText.TextSize = 13
confirmText.TextWrapped = true
confirmText.TextColor3 = UIColors.textPrimary
confirmText.Text = ""
confirmText.Parent = confirmBox

local confirmYes = Instance.new("TextButton")
confirmYes.AnchorPoint = Vector2.new(1, 1)
confirmYes.Position = UDim2.new(1, -12, 1, -12)
confirmYes.Size = UDim2.new(0, 96, 0, 32)
confirmYes.BackgroundColor3 = UIColors.danger
confirmYes.BackgroundTransparency = 0.55
confirmYes.Text = "판매한다"
confirmYes.Font = Enum.Font.GothamBold
confirmYes.TextSize = 12.5
confirmYes.TextColor3 = Color3.fromRGB(255, 200, 200)
confirmYes.ZIndex = 21
confirmYes.Parent = confirmBox
local confirmYesCorner = Instance.new("UICorner")
confirmYesCorner.CornerRadius = UDim.new(0, 8)
confirmYesCorner.Parent = confirmYes

local confirmNo = Instance.new("TextButton")
confirmNo.AnchorPoint = Vector2.new(1, 1)
confirmNo.Position = UDim2.new(1, -116, 1, -12)
confirmNo.Size = UDim2.new(0, 88, 0, 32)
confirmNo.BackgroundColor3 = UIColors.panel
confirmNo.BackgroundTransparency = UIColors.panelTransparency
confirmNo.Text = "취소"
confirmNo.Font = Enum.Font.GothamBold
confirmNo.TextSize = 12.5
confirmNo.TextColor3 = UIColors.textPrimary
confirmNo.ZIndex = 21
confirmNo.Parent = confirmBox
local confirmNoCorner = Instance.new("UICorner")
confirmNoCorner.CornerRadius = UDim.new(0, 8)
confirmNoCorner.Parent = confirmNo

confirmNo.Activated:Connect(function()
	confirmOverlay.Visible = false
end)
confirmOverlay.Activated:Connect(function()
	confirmOverlay.Visible = false
end)

confirmYes.Activated:Connect(function()
	confirmOverlay.Visible = false
	sellRequest:FireServer("sellBulk", highestGradeId())
end)

bulkSellButton.Activated:Connect(function()
	local count, total = bulkSellEstimate()
	if count == 0 then
		return
	end
	confirmText.Text = ("잠기지 않고 착용 중이 아닌 %d개를 팔아 %s골드를 받는다. 되돌릴 수 없다."):format(
		count, NumberFormat.format(total))
	confirmOverlay.Visible = true
end)

lockButton.Activated:Connect(function()
	if selectedKind ~= "bag" then
		return
	end
	local item = inventory[selectedValue]
	if not item then
		return
	end
	lockRequest:FireServer(selectedValue, not item.locked)
end)

sellButton.Activated:Connect(function()
	if selectedKind ~= "bag" then
		return
	end
	local item = inventory[selectedValue]
	if not item or item.locked then
		return
	end
	sellRequest:FireServer("sell", selectedValue)
end)

equipButton.Activated:Connect(function()
	if selectedKind == "bag" then
		equipRequest:FireServer("equip", selectedValue)
	elseif selectedKind == "equip" and selectedValue ~= "weapon" then
		-- 16-6: 어느 부위를 벗을지 서버에 같이 알려야 한다(갑옷 하나였을 땐 필요 없었다).
		equipRequest:FireServer("unequip", selectedValue)
	end
end)

-- ═══ 서버 동기화 ═══

local function onStateChanged(state)
	inventory = state.inventory
	equippedArmor = state.armor
	equippedGloves = state.gloves
	equippedShoes = state.shoes
	if isOpen then
		rebuildGearSlots()
		rebuildGrid()
		refreshStats()
	end
end

inventorySync.OnClientEvent:Connect(onStateChanged)

local ok, initialState = pcall(function()
	return inventoryFetch:InvokeServer()
end)
if ok and initialState then
	onStateChanged(initialState)
end

player:GetAttributeChangedSignal("Gold"):Connect(function()
	if isOpen then
		goldPillLabel.Text = "보유 골드 " .. NumberFormat.format(player:GetAttribute("Gold") or 0)
	end
end)

for _, attr in ipairs({ "ClassId", "WeaponLevel", "CharacterLevel", "MaxHp" }) do
	player:GetAttributeChangedSignal(attr):Connect(function()
		if isOpen then
			refreshStats()
			rebuildGearSlots()
		end
	end)
end

-- 인벤토리가 가득 찼을 때(14-1부터 "땅의 아이템을 못 주웠다"는 뜻) - 간단한 중앙 토스트로만
-- 알린다(ItemPickupHud.client.lua와 같은 가벼운 패턴). 새 창을 새로 열 만한 무게의
-- 이벤트가 아니다.
local fullToast = Instance.new("TextLabel")
fullToast.AnchorPoint = Vector2.new(0.5, 0.5)
fullToast.Position = UDim2.new(0.5, 0, 0.4, 0)
fullToast.Size = UDim2.new(0, 360, 0, 40)
fullToast.BackgroundTransparency = 1
fullToast.TextTransparency = 1
fullToast.TextStrokeTransparency = 0.6
fullToast.Font = Enum.Font.GothamBold
fullToast.TextSize = 15
fullToast.TextColor3 = UIColors.danger
fullToast.Text = "인벤토리가 가득 찼습니다 - 땅에 있는 아이템을 주울 수 없습니다"
fullToast.Parent = screenGui

inventoryFull.OnClientEvent:Connect(function()
	TweenService:Create(fullToast, TweenInfo.new(0.15), { TextTransparency = 0 }):Play()
	task.delay(2, function()
		TweenService:Create(fullToast, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
	end)
end)
