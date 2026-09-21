-- 장비창 보석 탭(23-4 · 26-3 · S20b: InventoryUI.client.lua의 setupGemTab을 그대로 잘라 옮겼다 - 동작 변경 0).
-- GemTab.create(deps) -> { update, cancelDrag, state, frame }
--   deps(InventoryUI가 주는 공용 접점 - 전부 명시적이다):
--     content · screenGui             Instance: 장비창 캔버스(보석 본문의 부모) · 드래그 유령 아이콘이 붙는 ScreenGui
--     registerLayout(fn)              배치 함수 fn(L)을 등록한다(Shell.applyLayout이 화면 크기가 바뀔 때마다 부른다 - L은 Layout.compute의 결과)
--     isOpen() -> boolean             창이 열려 있는가 · sheetInset() -> number  폰 상세 시트가 올라와 있으면 그 높이(본문이 그만큼 짧아진다)
--     getSelection() -> kind, value   공용 선택 상태 읽기 · select(kind, value) 쓰기(kind = "gemSlot" | "gemBag")
--     refreshDetail() · refreshStats()  상세바 · 총 스탯 갱신(보석은 옵션 보너스에 합산된다)
--     weaponGradeId() · applyGradeVisual(cell, stroke, glow, gradeId) · makeSectionLabel(parent, text, y)  InventoryUI가 함께 쓰는 헬퍼
--   반환: update() = 보석 탭 다시 그리기(창 열 때 · 서버 동기화 때) · cancelDrag() = 드래그 취소(창 닫을 때) · state() = 현재 보석 상태 스냅샷(GemSync) · frame = 보석 본문.
-- S20b 재구성: 본문(GemBody)은 세로 스크롤 ScrollingFrame이다. PC = 무기 칸(왼쪽 220) + 정보 칸 2단 · 폰 = 무기 칸 위 · 정보 칸 아래 1단(홈 행 높이 76 · 리롤 / 변환권 버튼 높이 44).
-- 드래그 중의 전역 입력(UserInputService InputChanged · InputEnded)은 이 모듈 안에서 연결한다. 취소 경로: 창 닫기(InventoryUI onClose → cancelDrag) · 마우스 놓기(endGemDrag). (탭 전환 · 리스폰에는 취소가 없다 - 옛 코드와 같다, 아래 PRD 기록 참고)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local GemData = require(ReplicatedStorage.Shared.data.GemData)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local Gem = require(ReplicatedStorage.Shared.Gem)
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)
local ItemDescribe = require(ReplicatedStorage.Shared.ItemDescribe)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local ItemIcons = require(script.Parent.Parent.Parent.ItemIcons)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)

local gemEquipRequest = ReplicatedStorage:WaitForChild("GemEquipRequest")
local gemRerollRequest = ReplicatedStorage:WaitForChild("GemRerollRequest")
local buyRerollTicketRequest = ReplicatedStorage:WaitForChild("BuyRerollTicketRequest")
local gemSync = ReplicatedStorage:WaitForChild("GemSync")
local gemFetch = ReplicatedStorage:WaitForChild("GemFetch")

local player = Players.LocalPlayer

local GemTab = {}

function GemTab.create(deps)
local content, screenGui = deps.content, deps.screenGui
local makeSectionLabel, applyGradeVisual = deps.makeSectionLabel, deps.applyGradeVisual
local weaponGradeId, refreshDetail, refreshStats = deps.weaponGradeId, deps.refreshDetail, deps.refreshStats

-- 26-3: Detail의 리롤 버튼(장비 3부위 확장)이 보석 탭 상태(변환권 보유량)를 봐야 한다 - 서버 GemSync 스냅샷이 오면 통째로 교체한다.
local currentGemState = {
	gems = { false, false, false, false, false },
	slotUnlocked = { false, false, false, false, false },
	gemInventory = {},
	rerollTickets = { ancient = 0, primordial = 0 },
}
local updateGemTab, cancelGemDrag
local Option = require(ReplicatedStorage.Shared.Option)

local gemBody = Instance.new("ScrollingFrame")
gemBody.Name = "GemBody"
gemBody.BackgroundTransparency = 1
gemBody.BorderSizePixel = 0
gemBody.ScrollBarThickness = 4
gemBody.CanvasSize = UDim2.new(0, 0, 0, 0)
gemBody.Visible = false
gemBody.Parent = content

-- (currentGemState는 이 모듈이 갖는다 - Detail의 리롤 버튼도 같은 변환권 보유량을 봐야 해서 GemTab.state()로 InventoryUI가 읽는다.)

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

local slotLabel = makeSectionLabel(infoPane, "홈 상세 (등급 상한 이하는 전부 장착 가능)", 8)

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
	-- 26-3(PRD 20.67 [12] "클릭하면 하단 Detail이 그 보석을 게이지와 함께 보여준다") - Frame이
	-- 아니라 TextButton으로 만들어 행 전체를 클릭 대상으로 삼는다. 안쪽 리롤·변환권 버튼은
	-- 그대로 자기 Activated를 먼저 받는다(자식이 부모보다 우선 - 로블록스 기본 동작).
	local row = Instance.new("TextButton")
	row.Name = "SlotRow" .. slot
	row.Text = ""
	row.AutoButtonColor = false
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
	label.TextSize = Theme.textSize("body") -- 강화대 옛 보석 탭(13px)보다 키웠다(지시 "글씨도 작고").
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = UIColors.textPrimary
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Text = ""
	label.Parent = row

	local rerollButton = Instance.new("TextButton")
	rerollButton.Size = UDim2.new(0, 64, 0, 17)
	rerollButton.Position = UDim2.new(0, 8, 1, -20)
	rerollButton.Font = Enum.Font.GothamBold
	rerollButton.TextSize = Theme.textSize("caption")
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
	buyButton.TextSize = Theme.textSize("caption")
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

	row.Activated:Connect(function()
		if Gem.isSlotUnlocked(currentGemState.slotUnlocked, slot) and Gem.isFilled(currentGemState.gems, slot) then
			deps.select("gemSlot", slot)
			refreshDetail()
		end
	end)
	rerollButton.Activated:Connect(function()
		gemRerollRequest:FireServer("gem", slot) -- 26-3: (kind, key) 프로토콜(GemServer.server.lua 참고)
	end)
	buyButton.Activated:Connect(function()
		local gem = currentGemState.gems[slot]
		if type(gem) == "table" and gem.grade then
			buyRerollTicketRequest:FireServer(gem.grade)
		end
	end)
end

local invLabel = makeSectionLabel(infoPane, "보유 보석 (끌어서 왼쪽 홈에 놓기)", 250)

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

-- S20b: 본문이 스크롤 창이 되어 스크롤로 잘려 안 보이는 홈 · 행이 생겼다(옛 배치에선 전부 보였다) - 좌표가 프레임 안이어도 그 프레임을 가리는 ScrollingFrame 조상의 보이는 영역 밖이면 대상이 아니다.
local function screenPointInVisible(frame, x, y)
	if not screenPointInFrame(frame, x, y) then
		return false
	end
	local node = frame.Parent
	while node and node ~= content do
		if node:IsA("ScrollingFrame") and not screenPointInFrame(node, x, y) then
			return false
		end
		node = node.Parent
	end
	return true
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
		if screenPointInVisible(socketButtons[slot].button, x, y) or screenPointInVisible(slotRows[slot].row, x, y) then
			targetSlot = slot
			break
		end
	end
	cancelGemDrag()
	if targetSlot and index then
		gemEquipRequest:FireServer(targetSlot, index)
	elseif index then
		-- 26-3(PRD 20.67 [12] "보유 보석 셀도 클릭 = 선택(드래그는 그대로 장착)") - 홈에
		-- 안 놓인 채 끝난 누름(=짧은 클릭)을 선택으로 처리한다.
		deps.select("gemBag", index)
		refreshDetail()
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
		gradeLabel.TextSize = Theme.textSize("caption")
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
	-- 28-2 [8] 3번: 변환권 가격의 기준은 계정 최고 스테이지다(서버 GemServer.rerollTicketPrice와 같은 값 - Attribute는 PlayerProfile이 내린다).
	local stage = player:GetAttribute("AccountBestStage") or 1
	return InfiniteStage.getGoldReward(MonsterData.tier1.goldDrop, stage)
end

updateGemTab = function()
	if not deps.isOpen() then
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
		-- 26-3(PRD 20.67 [9][12]) - "N번 홈 · 상한 <등급> · <등급> <옵션명> 보석 · Lv.N · +X%"
		-- 형식으로 통일한다(옛 "홈N(상한 X) - 등급: 옵션(값)" 형식을 대신한다).
		if not filled then
			ui.label.Text = ("%d번 홈 · 상한 %s · 빈 홈"):format(slot, capInfo.displayName)
		else
			local valueText = ""
			if gem.option then
				local value = Option.valueOf(gem.option, gem.grade, gem.itemLevel, classId)
				if type(value) == "table" then
					valueText = (" · 치확+%.1f%%p 치피+%.2f"):format(value.critRate * 100, value.critDmg * 100)
				else
					valueText = (" · %+.1f%%"):format(value * 100)
				end
			end
			ui.label.Text = ("%d번 홈 · 상한 %s · %s%s"):format(slot, capInfo.displayName, ItemDescribe.gem(gem).title, valueText)
		end

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
	-- 26-3: 지금 Detail에 보석이 선택돼 있으면(리롤 등으로 옵션이 막 바뀌었을 수 있다) 같이 갱신한다.
	local selectedKind = deps.getSelection()
	if selectedKind == "gemSlot" or selectedKind == "gemBag" then
		refreshDetail()
	end
end

-- 26-3: 옵션 보너스 박스(gear 탭)가 보석 옵션도 합산한다 - GemSync가 올 때도 refreshStats를
-- 불러야 리롤·장착 직후 그 자리가 바로 갱신된다(안 그러면 보석 탭을 오가야만 갱신됐다).
gemSync.OnClientEvent:Connect(function(data)
	currentGemState = data
	updateGemTab()
	if deps.isOpen() then
		refreshStats()
	end
end)

task.spawn(function()
	local ok, data = pcall(function()
		return gemFetch:InvokeServer()
	end)
	if ok and data then
		currentGemState = data
		updateGemTab()
		if deps.isOpen() then
			refreshStats()
		end
	end
end)

for _, attr in ipairs({ "RebirthCount", "InfiniteStage", "AccountBestStage" }) do
	player:GetAttributeChangedSignal(attr):Connect(updateGemTab)
end

-- 배치(S20b) - 화면 크기가 정하는 L(Layout.compute)로 두 칸의 크기 · 위치와 터치 크기를 다시 정한다.
local function layout(L)
	local phone = L.mode == "phone"
	gemBody.Position = UDim2.new(0, 0, 0, L.bodyTop)
	gemBody.Size = UDim2.new(1, 0, 0, L.bodyH - deps.sheetInset()) -- 폰: 상세 시트가 올라와 있으면 그만큼 짧다
	local rowHeight = phone and 76 or 42
	local buttonHeight = phone and 44 or 17
	for _, entry in ipairs(slotRows) do
		entry.row.Size = UDim2.new(1, 0, 0, rowHeight)
		entry.rerollButton.Size = UDim2.new(0, 64, 0, buttonHeight)
		entry.rerollButton.Position = UDim2.new(0, 8, 1, -(buttonHeight + 3))
		entry.buyButton.Size = UDim2.new(0, 160, 0, buttonHeight)
		entry.buyButton.Position = UDim2.new(0, 78, 1, -(buttonHeight + 3))
	end
	-- 정보 칸 순서: 보유 보석(끌어 오는 곳)이 위 · 홈 상세(행 · 리롤)가 아래. 무기 칸의 홈(드롭 대상)과 보유 보석이 스크롤 0에서 함께 보여야 낮은 PC 창(본문 232)에서도 끌어 놓을 수 있다.
	local invHeight = phone and 152 or 134
	local slotTop = 26 + invHeight + 12 -- 홈 상세 제목 y
	local listHeight = phone and Gem.slotCount * (rowHeight + 4) or 216
	invLabel.Position = UDim2.new(0, 14, 0, 8)
	gemInvScroll.Position = UDim2.new(0, 14, 0, 26)
	gemInvScroll.Size = UDim2.new(1, -28, 0, invHeight)
	slotLabel.Position = UDim2.new(0, 14, 0, slotTop)
	slotListScroll.Position = UDim2.new(0, 14, 0, slotTop + 18)
	slotListScroll.Size = UDim2.new(1, -28, 0, listHeight)
	local infoHeight = slotTop + 18 + listHeight + 14
	local canvasHeight
	if phone then
		weaponPane.Size = UDim2.new(1, 0, 0, 240)
		weaponPaneLine.Visible = false
		infoPane.Position = UDim2.new(0, 0, 0, 240)
		infoPane.Size = UDim2.new(1, 0, 0, infoHeight)
		canvasHeight = 240 + infoHeight
	else
		canvasHeight = math.max(infoHeight, L.bodyH)
		weaponPane.Size = UDim2.new(0, 220, 0, canvasHeight)
		weaponPaneLine.Visible = true
		infoPane.Position = UDim2.new(0, 220, 0, 0)
		infoPane.Size = UDim2.new(1, -220, 0, canvasHeight)
	end
	gemBody.CanvasSize = UDim2.new(0, 0, 0, canvasHeight)
end
deps.registerLayout(layout)

return {
	update = function()
		updateGemTab()
	end,
	cancelDrag = function()
		cancelGemDrag()
	end,
	state = function()
		return currentGemState
	end,
	frame = gemBody,
}
end

return GemTab
