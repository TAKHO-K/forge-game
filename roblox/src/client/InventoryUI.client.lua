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
local UserInputService = game:GetService("UserInputService")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local EquipSlots = require(ReplicatedStorage.Shared.data.EquipSlots)
local WeaponData = require(ReplicatedStorage.Shared.data.WeaponData)
local SaveConfig = require(ReplicatedStorage.Shared.data.SaveConfig)
local Loot = require(ReplicatedStorage.Shared.Loot)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local GemData = require(ReplicatedStorage.Shared.data.GemData)
local Gem = require(ReplicatedStorage.Shared.Gem)
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local ItemIcons = require(script.Parent.ItemIcons)
local UIManager = require(script.Parent.UIManager)

-- 분해 가능 등급(23-2) - 서버(PlayerProfile.lua DISMANTLE_MIN_GRADE_INDEX)와 같은 문턱(영웅
-- 이상, ArmorData.gradeOrder index 3). 버튼을 활성화할지 미리 판단하는 표시용일 뿐 실제
-- 검증은 서버가 다시 한다(다른 등급 판정과 같은 원칙 - 클라이언트 값을 믿지 않는다).
local function isDismantleEligibleGrade(gradeId)
	for i, id in ipairs(ArmorData.gradeOrder) do
		if id == gradeId then
			return i >= 3
		end
	end
	return false
end

local inventorySync = ReplicatedStorage:WaitForChild("InventorySync")
local inventoryFetch = ReplicatedStorage:WaitForChild("InventoryFetch")
local inventoryFull = ReplicatedStorage:WaitForChild("InventoryFull")
local equipRequest = ReplicatedStorage:WaitForChild("EquipRequest")
local sellRequest = ReplicatedStorage:WaitForChild("SellRequest")
local lockRequest = ReplicatedStorage:WaitForChild("LockRequest")
local dismantleRequest = ReplicatedStorage:WaitForChild("DismantleRequest")
local bulkSellCutoffRequest = ReplicatedStorage:WaitForChild("BulkSellCutoffRequest")
local setInventoryWindowPositionRequest = ReplicatedStorage:WaitForChild("SetInventoryWindowPosition")

-- 23-4: 보석 탭(강화대에서 옮겨옴, EnhanceUI.client.lua 주석 참고) - 원격 통로 이름은
-- 그대로 재사용한다(새 RemoteEvent를 만들지 않는다, 서버 GemServer.server.lua는 그대로).
local gemEquipRequest = ReplicatedStorage:WaitForChild("GemEquipRequest")
local gemRerollRequest = ReplicatedStorage:WaitForChild("GemRerollRequest")
local buyRerollTicketRequest = ReplicatedStorage:WaitForChild("BuyRerollTicketRequest")
local gemSync = ReplicatedStorage:WaitForChild("GemSync")
local gemFetch = ReplicatedStorage:WaitForChild("GemFetch")

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

-- 일괄판매 기준 등급 선택지(20-3) - ArmorData.gradeOrder에서 bulkSellMaxGrade까지만 잘라낸다
-- (단일 출처 - 상한 등급을 여기 다시 하드코딩하지 않는다. 서버도 같은 두 값으로 같은 상한을
-- 강제한다, PlayerProfile.sellItemsBulkUpTo/setBulkSellCutoffGrade 참고).
local BULK_SELL_GRADE_CHOICES = {}
for _, id in ipairs(ArmorData.gradeOrder) do
	table.insert(BULK_SELL_GRADE_CHOICES, id)
	if id == ArmorData.bulkSellMaxGrade then
		break
	end
end

-- 서버가 이미 골라 둔 값을 Attribute로 갖고 있으면(재접속) 그걸 초기값으로 쓴다 - 아직
-- 안 왔으면(로드 중) 목록의 가장 낮은 등급으로 시작하고, Attribute가 오는 대로 아래
-- GetAttributeChangedSignal 연결이 곧바로 맞춰준다.
local bulkSellCutoffGrade = player:GetAttribute("BulkSellCutoffGrade") or BULK_SELL_GRADE_CHOICES[1]
local bulkSellDropdownOpen = false
-- 아래(드롭다운 UI 생성부)에서 실제로 채워진다 - UIManager onClose가 이 파일 위쪽에서
-- 미리 참조해야 해서 선언만 여기로 끌어올렸다(Lua 클로저는 값이 아니라 upvalue를
-- 잡으므로, 나중에 대입해도 onClose가 그 최신 값을 본다).
local cutoffDropdown, cutoffDropdownDim

-- 23-4: 보석 탭(아래쪽에서 정의)을 이 시점(UIManager.register의 onOpen/onClose)이 먼저
-- 참조한다 - cutoffDropdown과 같은 이유로 이름만 먼저 선언해 둔다.
local updateGemTab, cancelGemDrag

-- 선택 상태: kind="bag"이면 value=서버 인덱스, kind="equip"이면 value="weapon"/"armor".
local selectedKind, selectedValue = nil, nil

local isOpen = false
local rainbowGradients = {} -- 매 프레임 회전시켜야 하는 태초 등급 테두리 그라디언트 목록.

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "InventoryGui"
screenGui.ResetOnSpawn = false
-- DisplayOrder는 UIManager가 열림 스택 순서에 맞춰 매긴다(18-1) - 다른 HUD ScreenGui들은
-- 전부 기본값(0)이라 창이 열려 있는 동안엔 항상 그 위에 뜬다.
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
-- 23-4: 중앙 고정이 기본 채팅창(왼쪽 위)과 겹치는 걸 실측으로 발견했다 - fitWindow가
-- 채팅·우상단 HUD 칩 열을 피해 매번 실제 좌상단 좌표를 계산해서 넣는다(아래 fitWindow
-- 주석 참고). AnchorPoint를 (0,0)으로 바꿔 그 좌표를 그대로 Position에 쓴다.
win.AnchorPoint = Vector2.new(0, 0)
win.Position = UDim2.new(0, 0, 0, 0) -- fitWindow가 첫 호출에서 바로 덮어쓴다.
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
--
-- 23-4: 창을 세로 중앙에 고정하면 기본 채팅창(왼쪽 위)과 겹친다는 걸 실측으로 발견했다
-- (뷰포트 1321x542에서 창 좌상단(384,27)이 채팅 영역(8,12)~(483,172)와 겹침). 처음엔
-- 세로로만 밀어봤는데, 그러면 창 바닥의 착용/판매/분해 버튼이 화면 하단 HUD(경험치
-- 바·스킬 슬롯)와 겹쳐 오히려 안 보이는 문제가 새로 생겼다(플레이 확인) - "세로로 밀지
-- 말고 우상단으로 옮기라"는 방향으로 다시 잡았다. 오른쪽 위 골드/레벨/스테이지 칩 열
-- (TopChipsGui, 폭 약 70px, 화면 오른쪽에서 -14px)도 가리면 안 되므로 그만큼 오른쪽
-- 여백을 더 둔다 - 기본 로블록스 유저목록(플레이어 리스트)은 필요하면 설정에서 끌 수
-- 있는 별개 UI라 이 계산에서 고려하지 않는다(지시 원문).
local CHAT_RIGHT_CLEARANCE = 500 -- 기본 채팅창 폭(~475px) + 여유
local HUD_RIGHT_CLEARANCE = 90 -- TopChipsGui 칩 열(~70px) + 여유
local TOP_MARGIN = 30 -- 지시 "조금만 더 위로" - 60에서 줄였다.

-- 23-4/23-5: 사용자가 헤더를 드래그해 옮긴 위치(지시 - "장비창 상단을 드래그하면 위치를
-- 옮길 수 있게, 껐다 켜도/직업변경·환생 등 무엇을 해도 유지, 재접속해도 유지"). nil이면
-- 아직 한 번도 안 옮겼다는 뜻이라 위 기본 계산(채팅·HUD 회피)을 그대로 쓴다. 한 번
-- 옮기면 이 세션이 끝날 때까지 계속 이 값을 쓴다(별도 로직 없이 자동 유지) - 23-5부터는
-- 접속 시점에 서버가 이미 저장된 값을 Attribute(InventoryWindowX/Y)로 보내주므로, 그
-- 값이 있으면 이 변수를 그걸로 먼저 채운다(아래 applySavedWindowPosition).
local userWindowPosition = nil

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
	local width, height = WINDOW_WIDTH * scale, WINDOW_HEIGHT * scale
	win.Size = UDim2.new(0, width, 0, height)
	contentScale.Scale = scale

	if userWindowPosition then
		-- 뷰포트가 바뀌었을 수도 있으니(창 크기 조절·모바일 회전) 매번 다시 화면 안으로
		-- 잘라 넣는다 - 지시 "드래그 가능 부분이 화면 밖으로는 나가지 않게".
		local left = math.clamp(userWindowPosition.X, 0, math.max(0, viewport.X - width))
		local top = math.clamp(userWindowPosition.Y, 0, math.max(0, viewport.Y - height))
		win.Position = UDim2.new(0, left, 0, top)
		return
	end

	-- 오른쪽 칩 열을 피할 수 있는 만큼 오른쪽에 붙이되(HUD_RIGHT_CLEARANCE), 그 위치가
	-- 채팅창과 겹치면(화면이 좁아 둘 다 피할 자리가 없으면) 채팅 쪽을 우선한다 - 채팅이
	-- 소통 기능이라 장식용 칩 열보다 안 가리는 쪽이 더 중요하다는 판단.
	local left = viewport.X - width - HUD_RIGHT_CLEARANCE
	left = math.max(left, CHAT_RIGHT_CLEARANCE)
	left = math.min(left, viewport.X - width - 8)
	left = math.max(left, 8)
	win.Position = UDim2.new(0, left, 0, TOP_MARGIN)
end

-- 23-5: 저장된 위치가 있으면(재접속 포함) 그걸로 시작한다 - 아직 한 번도 드래그하지
-- 않은(userWindowPosition == nil) 이 세션에서만 덮어쓴다. 접속 직후 Attribute가 아직
-- 안 왔을 수도 있어(프로필 로드가 이 스크립트 시작보다 늦을 수 있다) 초기 조회 +
-- 변경 신호 둘 다 듣는다(BulkSellCutoffGrade와 같은 패턴).
local function applySavedWindowPosition()
	if userWindowPosition then
		return
	end
	local x = player:GetAttribute("InventoryWindowX")
	local y = player:GetAttribute("InventoryWindowY")
	if x and y then
		userWindowPosition = Vector2.new(x, y)
		fitWindow()
	end
end

fitWindow()
applySavedWindowPosition()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitWindow)
player:GetAttributeChangedSignal("InventoryWindowX"):Connect(applySavedWindowPosition)
player:GetAttributeChangedSignal("InventoryWindowY"):Connect(applySavedWindowPosition)

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

-- ═══ 탭(23-4 신설 - "장비창을 열고 탭만 바꾸면 보석이 보이도록") ═══
-- 헤더와 본문 사이에 얇은 탭 줄 하나를 끼워 넣는다 - 그래서 본문(body)의 y 시작점·높이가
-- TAB_ROW_HEIGHT만큼 밀린다. 색 규칙은 EnhanceUI.client.lua 탭과 같은 것(선택=강조색,
-- 나머지=패널색)을 이 창의 팔레트(UIColors)로 옮긴 것뿐 - 새 색을 안 만든다.
local TAB_ROW_HEIGHT = 30
local EQUIP_TAB_NAMES = { "장비", "보석" }
local equipTabButtons = {}
local equipTabContents = {}
local activeEquipTab = "장비"

local equipTabRow = Instance.new("Frame")
equipTabRow.Name = "TabRow"
equipTabRow.Position = UDim2.new(0, 0, 0, HEADER_HEIGHT)
equipTabRow.Size = UDim2.new(1, 0, 0, TAB_ROW_HEIGHT)
equipTabRow.BackgroundTransparency = 1
equipTabRow.Parent = content

local equipTabRowLine = Instance.new("Frame")
equipTabRowLine.AnchorPoint = Vector2.new(0, 1)
equipTabRowLine.Position = UDim2.new(0, 0, 1, 0)
equipTabRowLine.Size = UDim2.new(1, 0, 0, 1)
equipTabRowLine.BackgroundColor3 = UIColors.rim
equipTabRowLine.BackgroundTransparency = UIColors.rimTransparency
equipTabRowLine.BorderSizePixel = 0
equipTabRowLine.Parent = equipTabRow

local function selectEquipTab(name)
	activeEquipTab = name
	for tabName, btn in pairs(equipTabButtons) do
		local selected = tabName == name
		btn.BackgroundColor3 = selected and UIColors.gold or UIColors.panel
		btn.BackgroundTransparency = selected and 0.1 or UIColors.panelTransparency
		btn.TextColor3 = selected and Color3.new(0, 0, 0) or UIColors.textSecondary
	end
	for tabName, frame in pairs(equipTabContents) do
		frame.Visible = tabName == name
	end
end

for i, name in ipairs(EQUIP_TAB_NAMES) do
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 96, 0, 22)
	btn.Position = UDim2.new(0, 14 + (i - 1) * 104, 0, 4)
	btn.Text = name
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 13
	btn.BackgroundColor3 = UIColors.panel
	btn.BackgroundTransparency = UIColors.panelTransparency
	btn.TextColor3 = UIColors.textSecondary
	btn.Parent = equipTabRow
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = btn
	equipTabButtons[name] = btn
	btn.Activated:Connect(function()
		selectEquipTab(name)
	end)
end

-- ═══ 본문 ═══
local body = Instance.new("Frame")
body.Name = "Body"
body.Position = UDim2.new(0, 0, 0, HEADER_HEIGHT + TAB_ROW_HEIGHT)
body.Size = UDim2.new(1, 0, 1, -(HEADER_HEIGHT + TAB_ROW_HEIGHT + DETAIL_HEIGHT))
body.BackgroundTransparency = 1
body.Parent = content
equipTabContents["장비"] = body

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

-- 분해(23-2, PRD 20.38 [3] 확장) - 상위 5등급(영웅~태초)만 대상. 판매와 자리를 나란히
-- 두되 서로 다른 결과를 준다(분해=보석만, 판매=골드만, PlayerProfile.dismantleItem 주석
-- 참고) - 같은 "sell" 스타일(금색 테두리)을 재사용한다(새 색을 안 만든다는 지시).
local dismantleButton = makeActionButton(3, 60, "sell")
dismantleButton.Text = "분해"

local equipButton = makeActionButton(4, 84, "primary")
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

-- 반환값에 highestSoldGradeId를 더했다(20-3) - 확인창이 "대상에 포함된 최고 등급"을
-- 이름·색으로 보여주려면 기준 등급(bulkSellCutoffGrade)이 아니라 실제로 팔릴 아이템 중
-- 가장 높은 등급을 알아야 한다(인벤토리에 그 기준보다 낮은 등급만 있을 수도 있다).
local function bulkSellEstimate()
	local count, total = 0, 0
	local highestSoldGradeId, highestSoldGradeIndex = nil, 0
	for _, item in ipairs(inventory) do
		if not item.locked and isSellableGrade(item.grade, bulkSellCutoffGrade) then
			count += 1
			total += Loot.getSellPrice(item)
			for i, id in ipairs(ArmorData.gradeOrder) do
				if id == item.grade and i > highestSoldGradeIndex then
					highestSoldGradeId, highestSoldGradeIndex = id, i
				end
			end
		end
	end
	return count, total, highestSoldGradeId
end

-- ═══ 상세바 갱신 ═══

local function describeItemName(item)
	local grade = ArmorData.grades[item.grade]
	local partName = ItemVisualData.partDisplayNames[item.part or "armor"] or "장비"
	return (grade and grade.displayName or item.grade) .. " " .. partName
end

-- 무기 등급(20-1) - 저장이 아니라 Attribute(WeaponGrade, 0~6)로만 온다. ArmorData.gradeOrder로
-- index->id를 찾는다(등급 데이터의 단일 출처, describeItemName의 갑옷 쪽과 같은 원리).
local function weaponGradeId()
	local grade = player:GetAttribute("WeaponGrade") or 0
	return ArmorData.gradeOrder[grade + 1]
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
	dismantleButton.AutoButtonColor = false
	dismantleButton.Active = false
	dismantleButton.TextTransparency = 0.6
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
		local dismantleEligible = not item.locked and isDismantleEligibleGrade(item.grade)
		dismantleButton.AutoButtonColor = dismantleEligible
		dismantleButton.Active = dismantleEligible
		dismantleButton.TextTransparency = dismantleEligible and 0 or 0.6
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
		dismantleButton.AutoButtonColor = false
		dismantleButton.Active = false
		dismantleButton.TextTransparency = 0.6
		equipButton.AutoButtonColor = true
		equipButton.Active = true
		equipButton.TextTransparency = 0
		equipButton.Text = "해제"
	elseif selectedKind == "equip" and selectedValue == "weapon" then
		local weaponLevel = player:GetAttribute("WeaponLevel") or 0
		local weaponData = WeaponData.weapons[WeaponData.starterId]
		local gradeId = weaponGradeId()
		local gradeInfo = gradeId and ArmorData.grades[gradeId]
		local visual = gradeId and ItemVisualData.gradeVisuals[gradeId]
		local color = visual and visual.color or UIColors.textPrimary
		-- 이름에 등급을 붙인다(20-1 [2] 판단) - 갑옷·장갑·신발(describeItemName)이 이미
		-- "등급 부위" 형식을 쓰고 있어, 무기만 색으로만 표시하면 이 창 안에서 두 가지 규칙이
		-- 섞인다. 강화 단계(+N)는 기존처럼 dmeta 줄에 그대로 둔다(부위별 레벨 표시와 동일).
		dname.Text = (gradeInfo and gradeInfo.displayName or "") .. " " .. weaponData.displayName
		dname.TextColor3 = color
		dmeta.Text = ("무기 · +%d · 강화대에서 강화"):format(weaponLevel)
		setDpicIcon("weapon", color)
		dpicStroke.Color = color
		dpicStroke.Transparency = 0

		lockButton.AutoButtonColor = false
		lockButton.Active = false
		lockIconHolder.Visible = false
		sellButton.AutoButtonColor = false
		sellButton.Active = false
		sellButton.TextTransparency = 0.6
		dismantleButton.AutoButtonColor = false
		dismantleButton.Active = false
		dismantleButton.TextTransparency = 0.6
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
	local weaponGrade = player:GetAttribute("WeaponGrade") or 0
	local characterLevel = player:GetAttribute("CharacterLevel") or 1
	local weapon = { id = WeaponData.starterId, level = weaponLevel, grade = weaponGrade }
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
				local visual = ItemVisualData.gradeVisuals[weaponGradeId()]
				color = visual and visual.color or UIColors.textPrimary
				stroke.Color = color
				stroke.Transparency = 0
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
	cutoffButton.Text = ArmorData.grades[bulkSellCutoffGrade].displayName .. " 이하 ▾"
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

-- ═══ 열기/닫기(18-1부터 UIManager에 위임 - 트윈·ESC 대체키·모바일 처리는 전부 거기서
-- 공통으로 한다. 이 파일은 "열렸을 때 뭘 다시 그릴지"만 onOpen에 남긴다) ═══

UIManager.register("inventory", {
	screenGui = screenGui,
	frame = win,
	extraVisible = { dim },
	hotkey = Enum.KeyCode.I,
	modal = true,
	exclusive = true,
	hasCloseButton = true,
	tweens = {
		{ instance = dim, property = "BackgroundTransparency", open = UIColors.overlayDimTransparency, closed = 1 },
		{ instance = winBackground, property = "BackgroundTransparency", open = 0.14, closed = 1 },
		{ instance = winStroke, property = "Transparency", open = UIColors.rimTransparency, closed = 1 },
		{ instance = winScale, property = "Scale", open = 1, closed = 0.94 },
	},
	onOpen = function()
		isOpen = true
		fitWindow() -- 닫혀 있는 동안 화면 크기가 바뀌었을 수 있다(창 회전 등).
		rebuildGearSlots()
		rebuildGrid()
		refreshStats()
		updateGemTab()
	end,
	onClose = function()
		isOpen = false
		bulkSellDropdownOpen = false
		if cutoffDropdown then
			cutoffDropdown.Visible = false
			cutoffDropdownDim.Visible = false
		end
		cancelGemDrag()
	end,
})

toggleButton.Activated:Connect(function()
	UIManager.toggle("inventory")
end)

-- 18-2 [7]: 딤 배경 클릭으로 닫지 않는다 - 클릭이 곧 공격인 게임이라 가방 정리 중 손이
-- 미끄러지면 창이 사라진다(검증 중 발견). dim은 TextButton이라 Activated 연결이 없어도
-- 클릭 자체는 계속 먹는다(뒤로 공격이 새 나가지 않는다) - 닫기는 X·I·Backspace만 한다.

closeButton.Activated:Connect(function()
	UIManager.close("inventory")
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
confirmBox.Size = UDim2.new(0, 300, 0, 168)
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

-- 대상에 포함된 최고 등급을 이름+색으로 보여준다(20-3, 지시 - "판매 개수·총액만으로는
-- 어느 등급까지 쓸려가는지 한눈에 안 읽힌다"). 점 하나 + 색 입힌 이름 텍스트로 충분해서
-- RichText 없이도 표현된다.
local confirmHighestDot = Instance.new("Frame")
confirmHighestDot.AnchorPoint = Vector2.new(0, 0.5)
confirmHighestDot.Position = UDim2.new(0, 16, 0, 92)
confirmHighestDot.Size = UDim2.new(0, 9, 0, 9)
confirmHighestDot.BorderSizePixel = 0
confirmHighestDot.ZIndex = 21
confirmHighestDot.Parent = confirmBox
local confirmHighestDotCorner = Instance.new("UICorner")
confirmHighestDotCorner.CornerRadius = UDim.new(1, 0)
confirmHighestDotCorner.Parent = confirmHighestDot

local confirmHighestLabel = Instance.new("TextLabel")
confirmHighestLabel.AnchorPoint = Vector2.new(0, 0.5)
confirmHighestLabel.Position = UDim2.new(0, 31, 0, 92)
confirmHighestLabel.Size = UDim2.new(1, -47, 0, 16)
confirmHighestLabel.BackgroundTransparency = 1
confirmHighestLabel.ZIndex = 21
confirmHighestLabel.Font = Enum.Font.GothamBold
confirmHighestLabel.TextSize = 12.5
confirmHighestLabel.TextXAlignment = Enum.TextXAlignment.Left
confirmHighestLabel.Text = ""
confirmHighestLabel.Parent = confirmBox

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
	sellRequest:FireServer("sellBulk", bulkSellCutoffGrade)
end)

bulkSellButton.Activated:Connect(function()
	local count, total, highestSoldGradeId = bulkSellEstimate()
	if count == 0 then
		return
	end
	confirmText.Text = ("잠기지 않고 착용 중이 아닌 %d개를 팔아 %s골드를 받는다. 되돌릴 수 없다."):format(
		count, NumberFormat.format(total))
	local visual = highestSoldGradeId and ItemVisualData.gradeVisuals[highestSoldGradeId]
	confirmHighestDot.BackgroundColor3 = visual and visual.color or UIColors.textTertiary
	confirmHighestLabel.TextColor3 = visual and visual.color or UIColors.textTertiary
	confirmHighestLabel.Text = highestSoldGradeId
		and ("대상에 포함된 최고 등급: %s"):format(ArmorData.grades[highestSoldGradeId].displayName)
		or ""
	confirmOverlay.Visible = true
end)

-- ═══ 일괄판매 기준 등급 드롭다운(20-3) ═══
-- confirmOverlay와 같은 패턴(딤 + 그 위 패널)이다 - 바깥을 클릭하면 닫힌다. cutoffButton의
-- 자식으로 둬서(내용 프레임이 아니라) 스케일·레이아웃 계산 없이 항상 버튼 바로 아래에
-- 붙는다.
cutoffDropdownDim = Instance.new("TextButton")
cutoffDropdownDim.Text = ""
cutoffDropdownDim.AutoButtonColor = false
cutoffDropdownDim.Size = UDim2.new(1, 0, 1, 0)
cutoffDropdownDim.BackgroundTransparency = 1
cutoffDropdownDim.ZIndex = 24
cutoffDropdownDim.Visible = false
cutoffDropdownDim.Parent = content

cutoffDropdown = Instance.new("Frame")
cutoffDropdown.Name = "CutoffDropdown"
cutoffDropdown.Position = UDim2.new(0, 0, 1, 4)
cutoffDropdown.Size = UDim2.new(0, 130, 0, 0)
cutoffDropdown.AutomaticSize = Enum.AutomaticSize.Y
cutoffDropdown.BackgroundColor3 = UIColors.panel
cutoffDropdown.BackgroundTransparency = 0.05
cutoffDropdown.ZIndex = 25
cutoffDropdown.Visible = false
cutoffDropdown.Parent = cutoffButton

local cutoffDropdownCorner = Instance.new("UICorner")
cutoffDropdownCorner.CornerRadius = UDim.new(0, 8)
cutoffDropdownCorner.Parent = cutoffDropdown
local cutoffDropdownStroke = Instance.new("UIStroke")
cutoffDropdownStroke.Color = UIColors.rim
cutoffDropdownStroke.Transparency = UIColors.rimTransparency
cutoffDropdownStroke.Parent = cutoffDropdown

local cutoffDropdownPadding = Instance.new("UIPadding")
cutoffDropdownPadding.PaddingTop = UDim.new(0, 4)
cutoffDropdownPadding.PaddingBottom = UDim.new(0, 4)
cutoffDropdownPadding.Parent = cutoffDropdown

local cutoffDropdownLayout = Instance.new("UIListLayout")
cutoffDropdownLayout.SortOrder = Enum.SortOrder.LayoutOrder
cutoffDropdownLayout.Parent = cutoffDropdown

local function closeCutoffDropdown()
	bulkSellDropdownOpen = false
	cutoffDropdown.Visible = false
	cutoffDropdownDim.Visible = false
end

-- 등급 목록에 색 점을 찍는다(지시 - "텍스트만으로는 서열이 안 읽힌다"). BULK_SELL_GRADE_CHOICES가
-- 이미 bulkSellMaxGrade까지만 잘라낸 목록이라 유물 이상은 여기 나타날 수가 없다.
for order, gradeId in ipairs(BULK_SELL_GRADE_CHOICES) do
	local row = Instance.new("TextButton")
	row.LayoutOrder = order
	row.Text = ""
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 28)
	row.ZIndex = 25
	row.Parent = cutoffDropdown

	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0, 0.5)
	dot.Position = UDim2.new(0, 10, 0.5, 0)
	dot.Size = UDim2.new(0, 8, 0, 8)
	dot.BackgroundColor3 = ItemVisualData.gradeVisuals[gradeId].color
	dot.BorderSizePixel = 0
	dot.ZIndex = 25
	dot.Parent = row
	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(1, 0)
	dotCorner.Parent = dot

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.new(0, 26, 0.5, 0)
	label.Size = UDim2.new(1, -34, 1, 0)
	label.BackgroundTransparency = 1
	label.ZIndex = 25
	label.Font = Enum.Font.GothamBold
	label.TextSize = 12.5
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = UIColors.textPrimary
	label.Text = ArmorData.grades[gradeId].displayName .. " 이하"
	label.Parent = row

	row.Activated:Connect(function()
		bulkSellCutoffGrade = gradeId
		bulkSellCutoffRequest:FireServer(gradeId)
		closeCutoffDropdown()
		rebuildGrid()
	end)
end

cutoffButton.Activated:Connect(function()
	bulkSellDropdownOpen = not bulkSellDropdownOpen
	cutoffDropdown.Visible = bulkSellDropdownOpen
	cutoffDropdownDim.Visible = bulkSellDropdownOpen
end)

cutoffDropdownDim.Activated:Connect(closeCutoffDropdown)

-- 재접속 등으로 서버 값이 늦게 도착해도(로드 중엔 목록의 가장 낮은 등급으로 임시 시작했다)
-- 실제 저장된 기준으로 맞춰준다 - ClassId 등 다른 Attribute와 같은 패턴.
player:GetAttributeChangedSignal("BulkSellCutoffGrade"):Connect(function()
	local grade = player:GetAttribute("BulkSellCutoffGrade")
	if grade and grade ~= bulkSellCutoffGrade then
		bulkSellCutoffGrade = grade
		if isOpen then
			rebuildGrid()
		end
	end
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

dismantleButton.Activated:Connect(function()
	if selectedKind ~= "bag" then
		return
	end
	local item = inventory[selectedValue]
	if not item or item.locked or not isDismantleEligibleGrade(item.grade) then
		return
	end
	dismantleRequest:FireServer(selectedValue)
end)

equipButton.Activated:Connect(function()
	if selectedKind == "bag" then
		equipRequest:FireServer("equip", selectedValue)
	elseif selectedKind == "equip" and selectedValue ~= "weapon" then
		-- 16-6: 어느 부위를 벗을지 서버에 같이 알려야 한다(갑옷 하나였을 땐 필요 없었다).
		equipRequest:FireServer("unequip", selectedValue)
	end
end)

-- ═══ 보석 탭(23-4, EnhanceUI.client.lua에서 이관 + 재설계) ═══
-- 지시 3가지를 여기 한 화면에 담는다: "장비창 탭만 바꾸면 보석이 보인다"(탭 자체는 위쪽
-- TAB_ROW_HEIGHT 블록), "자신 직업 무기가 더 크게"(왼쪽 무기 실루엣을 gear 슬롯 아이콘
-- (26px)의 6배 이상으로 키운다), "드래그로 보석 장착"(오른쪽 보유 보석 칸을 왼쪽 홈
-- 또는 슬롯 행 위로 끌어다 놓으면 장착). 등급 상한 규칙(Gem.canSocket)·리롤/변환권
-- 구매는 옛 EnhanceUI 보석 탭 로직을 그대로 옮기되 "슬롯 고정 등급"이 아니라 "그 슬롯에
-- 실제로 꽂힌 보석의 등급"(gem.grade)을 읽도록 고쳤다.

-- Luau는 함수 하나당 로컬 레지스터가 200개로 제한된다 - 이 파일(InventoryUI.client.lua)은
-- 최상위(청크) 레벨에 로컬을 계속 쌓아 온 1700줄짜리 단일 스크립트라, 보석 탭에 필요한
-- 로컬(무기 실루엣·홈 5개·슬롯 행·드래그 상태 등 20여 개)을 그냥 최상위에 더 얹으면
-- 전체 합이 200을 넘는다(실측: "Out of local registers ... exceeded limit 200" 컴파일
-- 에러). 함수 하나로 감싸면 그 안의 로컬은 이 함수 전용 레지스터 파일(별도 200개)을 쓰므로
-- 최상위 레지스터를 전혀 잡아먹지 않는다 - updateGemTab/cancelGemDrag만 최상위에 미리
-- 선언해 둔 자리(위쪽 forward-declare)에 대입해 밖으로 내보낸다.
local function setupGemTab()

local gemBody = Instance.new("Frame")
gemBody.Name = "GemBody"
gemBody.Position = body.Position
gemBody.Size = body.Size
gemBody.BackgroundTransparency = 1
gemBody.Visible = false
gemBody.Parent = content
equipTabContents["보석"] = gemBody

local currentGemState = {
	gems = { false, false, false, false, false },
	slotUnlocked = { false, false, false, false, false },
	gemInventory = {},
	rerollTickets = { ancient = 0, primordial = 0 },
}

-- ── 왼쪽: 확대한 무기 실루엣 + 홈 5개(드롭 타깃) ──
local WEAPON_ICON_SIZE = 176 -- gear 슬롯 무기 아이콘(26px)의 약 6.8배 - 지시 "자신 직업
-- 무기가 좀 더 크게"를 이 탭에서 가장 큰 그림으로 구현한다.

local weaponPane = Instance.new("Frame")
weaponPane.Name = "WeaponPane"
weaponPane.Size = UDim2.new(0, 220, 1, 0)
weaponPane.BackgroundTransparency = 1
weaponPane.Parent = gemBody

local weaponPaneLine = Instance.new("Frame")
weaponPaneLine.AnchorPoint = Vector2.new(1, 0)
weaponPaneLine.Position = UDim2.new(1, 0, 0, 0)
weaponPaneLine.Size = UDim2.new(0, 1, 1, 0)
weaponPaneLine.BackgroundColor3 = UIColors.rim
weaponPaneLine.BackgroundTransparency = UIColors.rimTransparency
weaponPaneLine.BorderSizePixel = 0
weaponPaneLine.Parent = weaponPane

makeSectionLabel(weaponPane, "내 무기 - 홈 5칸", 8)

local weaponIconHolder = Instance.new("Frame")
weaponIconHolder.AnchorPoint = Vector2.new(0.5, 0)
weaponIconHolder.Position = UDim2.new(0.5, 0, 0, 40)
weaponIconHolder.Size = UDim2.new(0, WEAPON_ICON_SIZE, 0, WEAPON_ICON_SIZE)
weaponIconHolder.BackgroundTransparency = 1
weaponIconHolder.Parent = weaponPane

-- 직업색 발광(지시 "자신 직업 무기") - 스킬 슬롯이 이미 쓰는 classAccent를 그대로
-- 재사용한다(새 색을 만들지 않는다).
local weaponGlow = Instance.new("Frame")
weaponGlow.AnchorPoint = Vector2.new(0.5, 0.5)
weaponGlow.Position = UDim2.new(0.5, 0, 0.5, 0)
weaponGlow.Size = UDim2.new(0, WEAPON_ICON_SIZE * 1.2, 0, WEAPON_ICON_SIZE * 1.2)
weaponGlow.BackgroundTransparency = 0.86
weaponGlow.BackgroundColor3 = UIColors.textTertiary
weaponGlow.ZIndex = 0
weaponGlow.Parent = weaponIconHolder
local weaponGlowCorner = Instance.new("UICorner")
weaponGlowCorner.CornerRadius = UDim.new(1, 0)
weaponGlowCorner.Parent = weaponGlow

local weaponIconArt = Instance.new("Frame")
weaponIconArt.BackgroundTransparency = 1
weaponIconArt.Size = UDim2.new(1, 0, 1, 0)
weaponIconArt.ZIndex = 2
weaponIconArt.Parent = weaponIconHolder

-- 홈 5개 - "덜 띄는 자리(1)"는 자루 쪽, "가장 두드러지는 자리(5)"는 칼끝(무기의 핵심
-- 이펙트 자리, 지시 그대로). ItemIcons.weapon이 칼날을 y=0(끝)~0.72*size(자루 시작)로
-- 그린다(ItemIcons.lua 주석) - 그 축을 그대로 따라간다. 등급 상한(Gem.gradeCapForSlot)과는
-- 이제 별개 축이다 - 1번 홈만 태초 상한인 것과 무관하게 5번이 여전히 가장 크고 눈에 띈다.
local SOCKET_Y_RATIO = { 0.92, 0.72, 0.50, 0.28, 0.06 }
local SOCKET_SIZE = { 12, 15, 19, 23, 28 }

local socketButtons = {}
for slot = 1, Gem.slotCount do
	local dot = Instance.new("TextButton")
	dot.Name = "Socket" .. slot
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.new(0.5, 0, SOCKET_Y_RATIO[slot], 0)
	dot.Size = UDim2.new(0, SOCKET_SIZE[slot], 0, SOCKET_SIZE[slot])
	dot.Text = ""
	dot.AutoButtonColor = false
	dot.ZIndex = 5
	dot.BackgroundColor3 = UIColors.slot
	dot.BackgroundTransparency = UIColors.slotTransparency
	dot.Parent = weaponIconHolder
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = dot
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5 + slot * 0.4 -- 5번이 가장 두꺼운 테두리 - "가장 두드러지는 자리".
	stroke.Parent = dot
	socketButtons[slot] = { button = dot, stroke = stroke }
end

-- ── 오른쪽: 슬롯 상세(리롤/변환권) + 보유 보석 목록(드래그 시작점) ──
local infoPane = Instance.new("Frame")
infoPane.Name = "InfoPane"
infoPane.Position = UDim2.new(0, 220, 0, 0)
infoPane.Size = UDim2.new(1, -220, 1, 0)
infoPane.BackgroundTransparency = 1
infoPane.Parent = gemBody

makeSectionLabel(infoPane, "홈 상세 (등급 상한 이하는 전부 장착 가능)", 8)

local slotListScroll = Instance.new("ScrollingFrame")
slotListScroll.Position = UDim2.new(0, 14, 0, 26)
slotListScroll.Size = UDim2.new(1, -28, 0, 216)
slotListScroll.BackgroundTransparency = 1
slotListScroll.BorderSizePixel = 0
slotListScroll.ScrollBarThickness = 4
slotListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
slotListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
slotListScroll.Parent = infoPane

local slotListLayout = Instance.new("UIListLayout")
slotListLayout.SortOrder = Enum.SortOrder.LayoutOrder
slotListLayout.Padding = UDim.new(0, 4)
slotListLayout.Parent = slotListScroll

local slotRows = {}
for slot = 1, Gem.slotCount do
	local row = Instance.new("Frame")
	row.Name = "SlotRow" .. slot
	row.LayoutOrder = slot
	row.Size = UDim2.new(1, 0, 0, 42)
	row.BackgroundColor3 = UIColors.slot
	row.BackgroundTransparency = UIColors.slotTransparency
	row.Parent = slotListScroll
	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 6)
	rowCorner.Parent = row
	local rowStroke = Instance.new("UIStroke")
	rowStroke.Color = UIColors.rim
	rowStroke.Transparency = UIColors.rimTransparency
	rowStroke.Parent = row

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(0, 8, 0, 3)
	label.Size = UDim2.new(1, -16, 0, 18)
	label.Font = Enum.Font.Gotham
	label.TextSize = 13.5 -- 강화대 옛 보석 탭(13px)보다 키웠다(지시 "글씨도 작고").
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = UIColors.textPrimary
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Text = ""
	label.Parent = row

	local rerollButton = Instance.new("TextButton")
	rerollButton.Size = UDim2.new(0, 64, 0, 17)
	rerollButton.Position = UDim2.new(0, 8, 1, -20)
	rerollButton.Font = Enum.Font.GothamBold
	rerollButton.TextSize = 11.5
	rerollButton.Text = "리롤"
	rerollButton.BackgroundColor3 = UIColors.panel
	rerollButton.BackgroundTransparency = UIColors.panelTransparency
	rerollButton.TextColor3 = UIColors.textPrimary
	rerollButton.Visible = false
	rerollButton.Parent = row
	local rerollCorner = Instance.new("UICorner")
	rerollCorner.CornerRadius = UDim.new(0, 5)
	rerollCorner.Parent = rerollButton

	local buyButton = Instance.new("TextButton")
	buyButton.Size = UDim2.new(0, 160, 0, 17)
	buyButton.Position = UDim2.new(0, 78, 1, -20)
	buyButton.Font = Enum.Font.GothamBold
	buyButton.TextSize = 11.5
	buyButton.Text = "변환권 구매"
	buyButton.BackgroundColor3 = UIColors.panel
	buyButton.BackgroundTransparency = UIColors.panelTransparency
	buyButton.TextColor3 = UIColors.textPrimary
	buyButton.Visible = false
	buyButton.Parent = row
	local buyCorner = Instance.new("UICorner")
	buyCorner.CornerRadius = UDim.new(0, 5)
	buyCorner.Parent = buyButton

	slotRows[slot] = { row = row, label = label, rerollButton = rerollButton, buyButton = buyButton }

	rerollButton.Activated:Connect(function()
		gemRerollRequest:FireServer(slot)
	end)
	buyButton.Activated:Connect(function()
		local gem = currentGemState.gems[slot]
		if type(gem) == "table" and gem.grade then
			buyRerollTicketRequest:FireServer(gem.grade)
		end
	end)
end

makeSectionLabel(infoPane, "보유 보석 (끌어서 왼쪽 홈에 놓기)", 250)

local gemInvScroll = Instance.new("ScrollingFrame")
gemInvScroll.Position = UDim2.new(0, 14, 0, 270)
gemInvScroll.Size = UDim2.new(1, -28, 1, -280)
gemInvScroll.BackgroundTransparency = 1
gemInvScroll.BorderSizePixel = 0
gemInvScroll.ScrollBarThickness = 4
gemInvScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
gemInvScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
gemInvScroll.Parent = infoPane

local gemInvLayout = Instance.new("UIGridLayout")
gemInvLayout.CellSize = UDim2.new(0, 64, 0, 64)
gemInvLayout.CellPadding = UDim2.new(0, 6, 0, 6)
gemInvLayout.SortOrder = Enum.SortOrder.LayoutOrder
gemInvLayout.Parent = gemInvScroll

-- ── 드래그 앤 드롭(지시 "드래그로 보석 장착") ──
-- Roblox UI는 표준 드래그 API가 없다 - 마우스 다운(cell.InputBegan)에서 화면 최상위
-- (screenGui, win의 ClipsDescendants 밖) 프록시를 만들고, 전역 UserInputService로 위치를
-- 따라가다가(win 밖으로 나가도 계속 보여야 한다) 마우스 업에서 좌표가 홈 위에 있으면
-- 장착 요청을 보낸다 - 실제 서버 검증(Gem.canSocket)은 GemServer가 다시 한다(클라이언트
-- 판정은 표시·프리뷰 전용, 아래 하이라이트도 마찬가지).
local dragProxy, dragInvIndex, dragGemGrade = nil, nil, nil

local function clearSocketHighlight()
	for _, entry in ipairs(socketButtons) do
		entry.stroke.Color = UIColors.rim
		entry.stroke.Transparency = UIColors.rimTransparency
	end
end

local function updateSocketHighlight()
	if not dragGemGrade then
		return
	end
	for slot, entry in ipairs(socketButtons) do
		local unlocked = Gem.isSlotUnlocked(currentGemState.slotUnlocked, slot)
		local ok = unlocked and Gem.canSocket(dragGemGrade, slot)
		entry.stroke.Color = ok and UIColors.success or UIColors.danger
		entry.stroke.Transparency = unlocked and 0 or 0.6
	end
end

local function screenPointInFrame(frame, x, y)
	local pos, size = frame.AbsolutePosition, frame.AbsoluteSize
	return x >= pos.X and x <= pos.X + size.X and y >= pos.Y and y <= pos.Y + size.Y
end

cancelGemDrag = function()
	if dragProxy then
		dragProxy:Destroy()
	end
	dragProxy, dragInvIndex, dragGemGrade = nil, nil, nil
	clearSocketHighlight()
end

local function endGemDrag(x, y)
	if not dragProxy then
		return
	end
	local index = dragInvIndex
	local targetSlot = nil
	for slot = 1, Gem.slotCount do
		if screenPointInFrame(socketButtons[slot].button, x, y) or screenPointInFrame(slotRows[slot].row, x, y) then
			targetSlot = slot
			break
		end
	end
	cancelGemDrag()
	if targetSlot and index then
		gemEquipRequest:FireServer(targetSlot, index)
	end
	-- 드래그가 홈에 안 맞았거나(targetSlot=nil) 서버가 거부해도(등급 상한 초과 등) 이
	-- 클라이언트가 먼저 지운 하이라이트(cancelGemDrag)를 실제 상태(잠김/장착색)로 즉시
	-- 되돌린다 - 서버 응답(GemSync push)이 안 오는 실패 케이스에서도 소켓이 무채색으로
	-- 눌러붙어 있지 않게 한다.
	updateGemTab()
end

local function startGemDrag(index, gradeId)
	cancelGemDrag()
	dragInvIndex = index
	dragGemGrade = gradeId
	local mouse = UserInputService:GetMouseLocation()
	local proxy = Instance.new("Frame")
	proxy.Name = "GemDragProxy"
	proxy.AnchorPoint = Vector2.new(0.5, 0.5)
	proxy.Size = UDim2.new(0, 30, 0, 30)
	proxy.Position = UDim2.new(0, mouse.X, 0, mouse.Y)
	proxy.BackgroundColor3 = (ItemVisualData.gradeVisuals[gradeId] or {}).color or UIColors.textTertiary
	proxy.ZIndex = 1000
	proxy.Parent = screenGui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = proxy
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Parent = proxy
	dragProxy = proxy
	updateSocketHighlight()
end

UserInputService.InputChanged:Connect(function(input)
	if not dragProxy then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		dragProxy.Position = UDim2.new(0, input.Position.X, 0, input.Position.Y)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if not dragProxy then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		endGemDrag(input.Position.X, input.Position.Y)
	end
end)

local gemInvCells = {}

local function rebuildGemInventory()
	for _, cell in ipairs(gemInvCells) do
		cell:Destroy()
	end
	gemInvCells = {}

	for i, gem in ipairs(currentGemState.gemInventory) do
		local cell = Instance.new("TextButton")
		cell.Name = "GemCell" .. i
		cell.LayoutOrder = i
		cell.Text = ""
		cell.AutoButtonColor = false
		cell.BackgroundColor3 = UIColors.slot
		cell.BackgroundTransparency = UIColors.slotTransparency
		cell.Parent = gemInvScroll

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = cell

		local glow = Instance.new("Frame")
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.Position = UDim2.new(0.5, 0, 0.5, 0)
		glow.Size = UDim2.new(1, 8, 1, 8)
		glow.BackgroundTransparency = 1
		glow.ZIndex = cell.ZIndex - 1
		glow.Parent = cell
		local glowCorner = Instance.new("UICorner")
		glowCorner.CornerRadius = UDim.new(0, 10)
		glowCorner.Parent = glow

		local gradeStroke = Instance.new("UIStroke")
		gradeStroke.Thickness = 1.5
		gradeStroke.Parent = cell

		applyGradeVisual(cell, gradeStroke, glow, gem.grade)

		local gradeLabel = Instance.new("TextLabel")
		gradeLabel.BackgroundTransparency = 1
		gradeLabel.Size = UDim2.new(1, -6, 0, 15)
		gradeLabel.Position = UDim2.new(0, 3, 1, -17)
		gradeLabel.Font = Enum.Font.GothamBold
		gradeLabel.TextSize = 11
		gradeLabel.TextColor3 = UIColors.textPrimary
		gradeLabel.Text = ArmorData.grades[gem.grade].displayName
		gradeLabel.Parent = cell

		cell.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				startGemDrag(i, gem.grade)
			end
		end)

		table.insert(gemInvCells, cell)
	end
end

local function currentStageGoldReward()
	local stage = player:GetAttribute("InfiniteStage") or 1
	return InfiniteStage.getGoldReward(MonsterData.tier1.goldDrop, stage)
end

updateGemTab = function()
	if not isOpen then
		return
	end

	local classId = player:GetAttribute("ClassId")
	local weaponGrade = weaponGradeId()
	local visual = weaponGrade and ItemVisualData.gradeVisuals[weaponGrade]
	weaponGlow.BackgroundColor3 = (classId and UIColors.classAccent[classId]) or UIColors.textTertiary
	for _, child in ipairs(weaponIconArt:GetChildren()) do
		child:Destroy()
	end
	local iconColor = (visual and visual.rainbow) and Color3.new(1, 1, 1) or (visual and visual.color or UIColors.textPrimary)
	ItemIcons.weapon(weaponIconArt, WEAPON_ICON_SIZE, iconColor)

	for slot = 1, Gem.slotCount do
		local ui = slotRows[slot]
		local socket = socketButtons[slot]
		local unlocked = Gem.isSlotUnlocked(currentGemState.slotUnlocked, slot)
		local capGradeId = Gem.gradeCapForSlot(slot)
		local capInfo = ArmorData.grades[capGradeId]

		if not unlocked then
			ui.label.Text = ("홈%d(상한 %s) - 잠김, 환생 %d회 필요"):format(slot, capInfo.displayName, GemData.slotUnlockRequiredRebirth[slot])
			ui.rerollButton.Visible = false
			ui.buyButton.Visible = false
			socket.button.BackgroundColor3 = UIColors.slot
			socket.stroke.Color = UIColors.rim
			socket.stroke.Transparency = 0.7
			continue
		end

		local gem = currentGemState.gems[slot]
		local filled = type(gem) == "table"
		local optionText
		if not filled then
			optionText = "빈 홈"
		elseif not Gem.isRerollableGrade(gem.grade) then
			optionText = ("위력 +%.1f%%"):format(Gem.attackPercentBonusForGrade(gem.grade) * 100)
		elseif gem.optionId then
			local axis = Gem.optionAxis(gem.optionId)
			local axisName = GemData.axisDisplayNames[axis] or axis
			optionText = ("%s(%s +%.1f%%)"):format(gem.optionId, axisName, Gem.magnitudeForGrade(gem.grade, axis) * 100)
		else
			optionText = "옵션 미배정(변환권 필요)"
		end
		local gemGradeInfo = filled and ArmorData.grades[gem.grade]
		ui.label.Text = filled
			and ("홈%d(상한 %s) - %s: %s"):format(slot, capInfo.displayName, gemGradeInfo.displayName, optionText)
			or ("홈%d(상한 %s) - 빈 홈"):format(slot, capInfo.displayName)

		local rerollable = filled and Gem.isRerollableGrade(gem.grade)
		ui.rerollButton.Visible = rerollable
		ui.buyButton.Visible = rerollable
		if rerollable then
			local tickets = currentGemState.rerollTickets[gem.grade] or 0
			ui.rerollButton.Text = ("리롤(%d장)"):format(tickets)
			ui.rerollButton.AutoButtonColor = tickets > 0
			ui.rerollButton.Active = tickets > 0
			ui.buyButton.Text = ("변환권(%s골드)"):format(NumberFormat.format(currentStageGoldReward() * GemData.rerollTicketGoldMultiplier))
		end

		if filled then
			local gradeVisual = ItemVisualData.gradeVisuals[gem.grade]
			socket.button.BackgroundColor3 = (gradeVisual and gradeVisual.color) or UIColors.textPrimary
			socket.stroke.Transparency = 0
		else
			socket.button.BackgroundColor3 = UIColors.slot
			socket.stroke.Color = UIColors.rim
			socket.stroke.Transparency = 0.4
		end
	end

	rebuildGemInventory()
end

gemSync.OnClientEvent:Connect(function(data)
	currentGemState = data
	updateGemTab()
end)

task.spawn(function()
	local ok, data = pcall(function()
		return gemFetch:InvokeServer()
	end)
	if ok and data then
		currentGemState = data
		updateGemTab()
	end
end)

for _, attr in ipairs({ "RebirthCount", "InfiniteStage" }) do
	player:GetAttributeChangedSignal(attr):Connect(updateGemTab)
end

end -- setupGemTab

setupGemTab()

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

for _, attr in ipairs({ "ClassId", "WeaponLevel", "WeaponGrade", "CharacterLevel", "MaxHp" }) do
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
