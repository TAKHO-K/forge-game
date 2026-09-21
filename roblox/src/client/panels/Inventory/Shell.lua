local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)
local Layout = require(script.Parent.Layout)
local GuiService = game:GetService("GuiService")

-- 장비창 껍데기(S20b: InventoryUI 분할 - 화면 · 딤 · 창 · 헤더 · 탭 줄 + 배치 적용). 탭 본문(장비 · 가방 · 보석)과 상세는 다른 모듈이 R에 자기 프레임을 붙이고, 배치는 R.layouts에 함수를 등록해 Shell.applyLayout이 부른다.
-- 배율은 항상 1(UIScale 없음). 창 크기 · 폰 / PC 판정은 Layout.compute(ScreenGui 크기)가 정한다.
local Shell = {}

local CHAT_RIGHT_CLEARANCE = 500 -- 기본 채팅창 폭(~475px) + 여유
local HUD_RIGHT_CLEARANCE = 90 -- TopChipsGui 칩 열(~70px) + 여유
local TOP_MARGIN = 30 -- 지시 "조금만 더 위로" - 60에서 줄였다.
local HEADER_HEIGHT = 44 -- 초기값(applyLayout이 Layout의 값으로 다시 정한다)

function Shell.create(S, R)
local player = S.player
local playerGui = player:WaitForChild("PlayerGui")
local setInventoryWindowPositionRequest = ReplicatedStorage:WaitForChild("SetInventoryWindowPosition")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "InventoryGui"
screenGui.ResetOnSpawn = false
-- DisplayOrder는 UIManager가 열림 스택 순서에 맞춰 매긴다(18-1) - 다른 HUD ScreenGui들은 전부 기본값(0)이라 창이 열려 있는 동안엔 항상 그 위에 뜬다.
screenGui.Parent = playerGui
R.screenGui = screenGui
R.layouts = {} -- 탭 모듈이 등록하는 배치 함수 fn(L)

-- ═══ 열기 버튼(HUD, 항상 보임) ═══
local toggleButton = Instance.new("TextButton")
toggleButton.Name = "InventoryToggleButton"
toggleButton.AnchorPoint = Vector2.new(1, 0.5)
toggleButton.Position = UDim2.new(1, -16, 0.5, 0)
toggleButton.Size = UDim2.new(0, 90, 0, 36)
toggleButton.Text = "가방"
toggleButton.Font = Enum.Font.GothamBold
toggleButton.TextSize = Theme.textSize("body")
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
-- S20b: 720 × 560 고정 캔버스를 UIScale로 줄이던 구조를 없앴다. win은 Layout이 정한 크기(PC 720 × 560 이하 · 폰은 화면 - 여백)이고 content는 win을 꽉 채운다 - 넘치는 내용은 탭 본문의 ScrollingFrame이 받는다.
local win = Instance.new("Frame")
win.Name = "Window"
-- 23-4: 중앙 고정이 기본 채팅창(왼쪽 위)과 겹치는 걸 실측으로 발견했다 - positionWindow가 채팅 · 우상단 HUD 칩 열을 피해 매번 실제 좌상단 좌표를 계산해서 넣는다.
win.AnchorPoint = Vector2.new(0, 0)
win.Position = UDim2.new(0, 0, 0, 0) -- applyLayout이 첫 호출에서 바로 덮어쓴다.
win.Size = UDim2.new(0, Layout.pcWidth, 0, Layout.pcHeight)
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

-- win을 꽉 채우는 캔버스 - 실제 자식(헤더 · 탭 · 본문 · 상세)은 전부 여기 붙는다.
local content = Instance.new("Frame")
content.Name = "Content"
content.Size = UDim2.new(1, 0, 1, 0)
content.BackgroundTransparency = 1
content.Parent = win

R.win, R.winBackground, R.winStroke, R.content = win, winBackground, winStroke, content

-- 23-4/23-5: 사용자가 헤더를 드래그해 옮긴 위치(지시 - "장비창 상단을 드래그하면 위치를 옮길 수 있게, 껐다 켜도/직업변경·환생 등 무엇을 해도 유지, 재접속해도 유지"). nil이면 아직 한 번도 안 옮겼다는 뜻이라
-- 기본 계산(채팅 · HUD 회피)을 쓴다. 23-5부터는 접속 시점에 서버가 저장된 값을 Attribute(InventoryWindowX/Y)로 보내주므로 그 값이 있으면 이 변수를 먼저 채운다(applySavedWindowPosition). PC에서만 쓴다(폰은 창이 화면을 채운다).
local userWindowPosition = nil

-- 현재 화면 크기(ScreenGui 폭 · 높이 = 뷰포트 - 상단 인셋). 점검이 가상 화면을 강제할 수 있다(R.debugForceScreen).
local function screenSize()
	if R.forcedScreen then
		return R.forcedScreen
	end
	local size = screenGui.AbsoluteSize
	if size.X > 0 and size.Y > 0 then
		return size
	end
	local camera = workspace.CurrentCamera
	local inset = GuiService:GetGuiInset()
	return Vector2.new(camera.ViewportSize.X, camera.ViewportSize.Y - inset.Y)
end

local function positionWindow(L)
	win.Size = UDim2.new(0, L.winW, 0, L.winH)
	if L.mode == "phone" then
		win.Position = UDim2.new(0, Layout.margin, 0, Layout.margin)
		return
	end
	if userWindowPosition then
		-- 뷰포트가 바뀌었을 수도 있으니(창 크기 조절) 매번 다시 화면 안으로 잘라 넣는다 - 지시 "드래그 가능 부분이 화면 밖으로는 나가지 않게".
		local left = math.clamp(userWindowPosition.X, 0, math.max(0, L.screenW - L.winW))
		local top = math.clamp(userWindowPosition.Y, 0, math.max(0, L.screenH - L.winH))
		win.Position = UDim2.new(0, left, 0, top)
		return
	end
	-- 오른쪽 칩 열을 피할 수 있는 만큼 오른쪽에 붙이되(HUD_RIGHT_CLEARANCE), 그 위치가 채팅창과 겹치면(화면이 좁아 둘 다 피할 자리가 없으면) 채팅 쪽을 우선한다 - 채팅이 소통 기능이라 장식용 칩 열보다 안 가리는 쪽이 더 중요하다는 판단.
	local left = L.screenW - L.winW - HUD_RIGHT_CLEARANCE
	left = math.max(left, CHAT_RIGHT_CLEARANCE)
	left = math.min(left, L.screenW - L.winW - Layout.margin)
	left = math.max(left, Layout.margin)
	local top = math.max(Layout.margin, math.min(TOP_MARGIN, L.screenH - L.winH - Layout.margin))
	win.Position = UDim2.new(0, left, 0, top)
end

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

-- 23-4: 헤더(제목 줄) 드래그로 창을 옮긴다(지시 - "장비창 상단을 드래그하면 위치를 옮길
-- 수 있게"). header 위의 자식 버튼(정렬·일괄판매·닫기 등)은 자기가 먼저 입력을 받아가서
-- (로블록스는 그 지점의 가장 앞 GuiObject에만 InputBegan을 준다) 이 핸들러와 안 겹친다 -
-- 그 버튼들이 없는 빈 자리(제목 옆)를 잡았을 때만 드래그가 시작된다.
local headerDragging = false
local headerDragStart, headerDragStartPos

header.InputBegan:Connect(function(input)
	if S.mode == "phone" then
		return -- 폰: 창이 화면을 채우므로 옮기지 않는다(S20b)
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		headerDragging = true
		headerDragStart = input.Position
		headerDragStartPos = win.AbsolutePosition
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not headerDragging then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		local delta = input.Position - headerDragStart
		local viewport = workspace.CurrentCamera.ViewportSize
		local size = win.AbsoluteSize
		-- 지시 "드래그 가능 부분이 화면 밖으로는 나가지 않게" - 창 전체가 뷰포트 안에
		-- 머물도록 매 프레임 잘라 넣는다(모서리 너머로 끌어도 그 자리에서 멈춘다).
		local left = math.clamp(headerDragStartPos.X + delta.X, 0, math.max(0, viewport.X - size.X))
		local top = math.clamp(headerDragStartPos.Y + delta.Y, 0, math.max(0, viewport.Y - size.Y))
		win.Position = UDim2.new(0, left, 0, top)
		userWindowPosition = Vector2.new(left, top)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if headerDragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		headerDragging = false
		-- 23-5: 드래그가 끝날 때 한 번만 서버에 저장한다(매 프레임 InputChanged마다 쏘지
		-- 않는다 - 되돌릴 수 있는 UI 배치라 즉시저장까지는 필요 없고, 요청 자체를 줄인다).
		if userWindowPosition then
			setInventoryWindowPositionRequest:FireServer(userWindowPosition.X, userWindowPosition.Y)
		end
	end
end)

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
title.TextSize = Theme.textSize("header")
title.TextColor3 = UIColors.textPrimary
title.Text = "가방"
title.Parent = headerLeft

local countLabel = Instance.new("TextLabel")
countLabel.LayoutOrder = 2
countLabel.BackgroundTransparency = 1
countLabel.AutomaticSize = Enum.AutomaticSize.X
countLabel.Size = UDim2.new(0, 0, 1, 0)
countLabel.Font = Enum.Font.Gotham
countLabel.TextSize = Theme.textSize("caption") -- 16-6 [4]: 12px 미만 금지.
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
	pill.TextSize = Theme.textSize("caption") -- 16-6 [4]: 12px 미만 금지.
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

local sortButton = makeHeaderPill(S.SORT_LABELS[S.sortMode] .. " ▾", 1)

-- 일괄판매 기준 등급 선택 버튼(20-3) - 클릭하면 등급 목록(색 점 포함)이 드롭다운으로 열린다.
-- 라벨은 rebuildGrid에서 bulkSellCutoffGrade가 바뀔 때마다 다시 맞춘다.
local cutoffButton = makeHeaderPill("", 2)

local bulkSellButton = makeHeaderPill("일괄판매", 3)

local closeButton = Instance.new("TextButton")
closeButton.LayoutOrder = 4
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

-- 헤더 · 탭 줄 배치가 배치(L)마다 바뀌는 크기(폰 = 터치 44)
local function layoutHeader(L)
	header.Size = UDim2.new(1, 0, 0, L.headerH)
	headerRight.Size = UDim2.new(0, 0, 0, L.pillH)
	for _, pill in ipairs({ sortButton, cutoffButton, bulkSellButton }) do
		pill.Size = UDim2.new(0, 0, 0, L.pillH)
	end
	closeButton.Size = UDim2.new(0, L.closeSize, 0, L.closeSize)
end

-- ═══ 탭 ═══
-- 23-4 신설: 헤더와 본문 사이에 탭 줄 하나. 색 규칙은 EnhanceUI.client.lua 탭과 같다(선택=강조색, 나머지=패널색). S20b: PC = [장비 · 보석](장비 탭이 장비 칸 + 가방 2단),
-- 폰 = [장비 · 가방 · 보석](각각 1단). 어느 프레임이 어느 탭에 속하는지는 배치가 바뀔 때마다 applyLayout이 정한다.
local tabButtons = {}
local tabPanels = {} -- 탭 이름 -> { 프레임 … }
local activeTab = "장비"

local tabRow = Instance.new("Frame")
tabRow.Name = "TabRow"
tabRow.BackgroundTransparency = 1
tabRow.Parent = content

local tabRowLine = Instance.new("Frame")
tabRowLine.AnchorPoint = Vector2.new(0, 1)
tabRowLine.Position = UDim2.new(0, 0, 1, 0)
tabRowLine.Size = UDim2.new(1, 0, 0, 1)
tabRowLine.BackgroundColor3 = UIColors.rim
tabRowLine.BackgroundTransparency = UIColors.rimTransparency
tabRowLine.BorderSizePixel = 0
tabRowLine.Parent = tabRow

local function selectTab(name)
	if not tabPanels[name] then
		name = "장비"
	end
	activeTab = name
	for tabName, btn in pairs(tabButtons) do
		local selected = tabName == name
		btn.BackgroundColor3 = selected and UIColors.gold or UIColors.panel
		btn.BackgroundTransparency = selected and 0.1 or UIColors.panelTransparency
		btn.TextColor3 = selected and Color3.new(0, 0, 0) or UIColors.textSecondary
	end
	for tabName, frames in pairs(tabPanels) do
		for _, frame in ipairs(frames) do
			frame.Visible = tabName == name
		end
	end
end
R.selectTab = selectTab

local function rebuildTabs(L)
	for _, btn in pairs(tabButtons) do
		btn:Destroy()
	end
	tabButtons = {}
	local buttonWidth = L.mode == "phone" and 110 or 96
	for i, name in ipairs(L.tabNames) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, buttonWidth, 0, L.tabButtonH)
		btn.Position = UDim2.new(0, 14 + (i - 1) * (buttonWidth + 8), 0, (L.tabH - L.tabButtonH) / 2)
		btn.Text = name
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = Theme.textSize("body")
		btn.BackgroundColor3 = UIColors.panel
		btn.BackgroundTransparency = UIColors.panelTransparency
		btn.TextColor3 = UIColors.textSecondary
		btn.Parent = tabRow
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = btn
		tabButtons[name] = btn
		btn.Activated:Connect(function()
			selectTab(name)
		end)
	end
end

-- 화면 크기에서 배치를 정해 전부에 적용한다. 화면 크기가 바뀔 때 · 창을 열 때 부른다. 반환: 배치 L.
function R.applyLayout()
	local size = screenSize()
	local L = Layout.compute(size.X, size.Y)
	S.mode, R.layout = L.mode, L
	positionWindow(L)
	layoutHeader(L)
	tabRow.Position = UDim2.new(0, 0, 0, L.headerH)
	tabRow.Size = UDim2.new(1, 0, 0, L.tabH)
	if L.mode == "phone" then
		tabPanels = { ["장비"] = { R.gearFrame }, ["가방"] = { R.bagFrame }, ["보석"] = { R.gemFrame } }
	else
		tabPanels = { ["장비"] = { R.gearFrame, R.bagFrame }, ["보석"] = { R.gemFrame } }
	end
	rebuildTabs(L)
	for _, fn in ipairs(R.layouts) do
		fn(L)
	end
	selectTab(activeTab)
	return L
end

-- 검사용: 가상 화면 크기(Vector2)를 강제해 배치를 다시 적용한다(nil이면 실제 화면으로 돌아간다). 폰 배치를 PC 창에서 실제 인스턴스로 잴 수 있다.
function R.debugForceScreen(size)
	R.forcedScreen = size
	return R.applyLayout()
end

-- 23-5: 저장된 위치가 있으면(재접속 포함) 그걸로 시작한다 - 아직 한 번도 드래그하지 않은(userWindowPosition == nil) 이 세션에서만 덮어쓴다. 접속 직후 Attribute가 아직 안 왔을 수도 있어
-- (프로필 로드가 이 스크립트 시작보다 늦을 수 있다) 초기 조회 + 변경 신호 둘 다 듣는다(BulkSellCutoffGrade와 같은 패턴).
local function applySavedWindowPosition()
	if userWindowPosition then
		return
	end
	local x = player:GetAttribute("InventoryWindowX")
	local y = player:GetAttribute("InventoryWindowY")
	if x and y then
		userWindowPosition = Vector2.new(x, y)
		if R.layout then
			positionWindow(R.layout)
		end
	end
end
applySavedWindowPosition()
screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	if R.gemFrame then -- 모든 탭이 만들어진 뒤에만
		R.applyLayout()
	end
end)
player:GetAttributeChangedSignal("InventoryWindowX"):Connect(applySavedWindowPosition)
player:GetAttributeChangedSignal("InventoryWindowY"):Connect(applySavedWindowPosition)

R.header, R.countLabel = header, countLabel
R.sortButton, R.cutoffButton, R.bulkSellButton, R.closeButton = sortButton, cutoffButton, bulkSellButton, closeButton
R.toggleButton, R.dim = toggleButton, dim
end

return Shell
