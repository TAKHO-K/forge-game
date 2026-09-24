-- 장비창 보석 탭(23-4 · 26-3 · S20b: InventoryUI.client.lua의 setupGemTab을 그대로 잘라 옮겼다 · S20c: 홈 한 줄 · 장착 입력 재구성).
-- GemTab.create(deps) -> { update, cancelDrag, state, frame, canAutoEquip, autoEquip }
--   deps(InventoryUI가 주는 공용 접점 - 전부 명시적이다):
--     content · screenGui             Instance: 장비창 캔버스(보석 본문의 부모) · 드래그 유령 아이콘이 붙는 ScreenGui
--     registerLayout(fn)              배치 함수 fn(L)을 등록한다(Shell.applyLayout이 화면 크기가 바뀔 때마다 부른다 - L은 Layout.compute의 결과)
--     isOpen() -> boolean             창이 열려 있는가 · sheetInset() -> number  폰 상세 시트가 올라와 있으면 그 높이(본문이 그만큼 짧아진다) · isPhone() -> boolean  폰 배치인가
--     getSelection() -> kind, value   공용 선택 상태 읽기 · select(kind, value) 쓰기(kind = "gemSlot" | "gemBag" | nil)
--     refreshDetail() · refreshStats()  상세바 · 총 스탯 갱신(보석은 옵션 보너스에 합산된다) · selectTab(name)  탭 전환(보석 획득 토스트의 [보석 탭 열기])
--     weaponGradeId() · applyGradeVisual(cell, stroke, glow, gradeId) · makeSectionLabel(parent, text, y)  InventoryUI가 함께 쓰는 헬퍼
--   반환: update() = 보석 탭 다시 그리기(창 열 때 · 서버 동기화 때) · cancelDrag() = 창 닫을 때(드래그 취소 · 홈 먼저 취소 · NEW 확인) · state() = 현재 보석 상태 스냅샷(GemSync) · frame = 보석 본문
--          canAutoEquip(index) · autoEquip(index) = 상세 시트의 [장착] 버튼이 부른다(입력 통로는 하나 - GemActions) · replaceText(index) = 자동 장착이 밀어낼 보석 미리보기 글(S20d).
-- S20b 재구성: 본문(GemBody)은 세로 스크롤 ScrollingFrame이다. PC = 무기 칸(왼쪽 220) + 정보 칸 2단 · 폰 = 홈 한 줄 위 · 정보 칸 아래 1단(홈 행 높이 76 · 리롤 / 변환권 버튼 높이 44).
-- S20c 입력(서버 규칙은 그대로 - 장착은 항상 "교체"이고 기존 보석은 보석칸으로 돌아온다 · 해제는 서버에 없다). 모든 입력은 GemActions.equip 한 곳으로 간다:
--   PC   보석 더블클릭(0.35초) · 우클릭 = 자동 장착(끼울 수 있는 열린 홈 중 상한이 가장 낮은 홈) / 홈 더블클릭 · 우클릭 = 그 홈을 "홈 먼저" 대상으로 고르기 → 밝게 보이는 보석을 클릭하면 교체(Esc · 빈 곳 클릭 = 취소) / 드래그(끼울 수 있는 홈은 빛나고 · 못 끼우는 홈은 어둡게 + ×).
--   폰   더블탭 없음. 탭 = 선택 토글. 보석을 탭하면 [장착](상세 시트) + 가능한 홈 강조 → 강조된 홈을 탭 · 홈을 탭하면 그 홈이 대상 → 강조된 보석을 탭. 다시 탭하거나 빈 곳을 탭하면 선택 해제.
--   거절(클라 미리 판정 · 서버 결과 모두) = 유령이 원래 칸으로 0.2초 복귀 + 이유 토스트. 강화대 12stud 안에서만 서버가 받으므로(GemServer) 탭 위에 상태를 보인다.
-- 드래그 중의 전역 입력(UserInputService InputChanged · InputEnded)은 이 모듈 안에서 연결한다. 취소 경로: 창 닫기(InventoryUI onClose → cancelDrag) · 마우스 놓기(endGemDrag). (탭 전환 · 리스폰에는 취소가 없다 - 옛 코드와 같다, PRD 20.108 참고)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local GemData = require(ReplicatedStorage.Shared.data.GemData)
local Gem = require(ReplicatedStorage.Shared.Gem)
local ItemDescribe = require(ReplicatedStorage.Shared.ItemDescribe)
local Toast = require(script.Parent.Parent.Parent.ui.kit.Toast)
local Hint = require(script.Parent.Parent.GemWorkshop.Hint)
local GemActions = require(script.Parent.GemActions)
local GemSlots = require(script.Parent.GemSlots)
local GemSlotRows = require(script.Parent.GemSlotRows)
local GemHeader = require(script.Parent.GemHeader)
local GemBag = require(script.Parent.GemBag)

local gemSync = ReplicatedStorage:WaitForChild("GemSync")
local gemFetch = ReplicatedStorage:WaitForChild("GemFetch")

local player = Players.LocalPlayer

local GemTab = {}

-- 본문 맨 위 안내 블록(변환 · 리롤 안내 줄 + 상황 안내 한 줄)의 높이는 GemHeader.height()가 정한다(안 써 본 상태는 눈에 띄는 줄이라 더 높다). 그 아래에 무기 칸 · 정보 칸이 놓인다.
local PHONE_LEFT_WIDTH = 300 -- 폰: 홈 한 줄(5 × 48 + 4 × 8 = 272 + 여백)이 차지하는 왼쪽 폭 - 그 오른쪽이 보유 보석
local CHIP_SIZE = { pc = 34, phone = 48 } -- 홈 칩 크기(폰은 터치 44 이상)
local CHIP_GAP = { pc = 5, phone = 8 }
local WEAPON_ICON_SIZE = 176 -- 무기 그림(PC 전용 장식 - 폰에서는 접는다)

function GemTab.create(deps)
local content, screenGui = deps.content, deps.screenGui
local makeSectionLabel, applyGradeVisual = deps.makeSectionLabel, deps.applyGradeVisual
local weaponGradeId, refreshDetail, refreshStats = deps.weaponGradeId, deps.refreshDetail, deps.refreshStats
local uiConfig = GemData.ui

-- 26-3: Detail의 리롤 버튼(장비 3부위 확장)이 보석 탭 상태(변환권 보유량)를 봐야 한다 - 서버 GemSync 스냅샷이 오면 통째로 교체한다.
local currentGemState = {
	gems = { false, false, false, false, false },
	slotUnlocked = { false, false, false, false, false },
	gemInventory = {},
	rerollTickets = { ancient = 0, primordial = 0 },
}
local initialized = false -- 첫 스냅샷을 받았는가(그 전의 보석은 "새 보석"이 아니다)
local seenCount = 0 -- 이 수 이하의 보석칸 index는 이미 본 보석이다(그 위가 NEW - 분해로 새로 들어온 보석은 맨 끝에 붙는다)
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

-- ── 맨 위: 변환 · 리롤 안내 줄(S20e - 보석상인에게서만 된다) + 상황별 안내 한 줄 ──
local header = GemHeader.createStatus(gemBody, { onLocate = Hint.locate })

-- ── 왼쪽(폰은 위): 홈 한 줄 + 확대한 무기 그림(PC 장식) ──
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

local weaponLabel = makeSectionLabel(weaponPane, "내 무기 - 홈 5칸", 8)

local slots = GemSlots.create(weaponPane) -- 홈 5칸(Socket1~5) - 드롭 · 탭 대상
slots.row.Position = UDim2.new(0, 14, 0, 26)

local weaponArt = GemHeader.createWeaponArt(weaponPane, WEAPON_ICON_SIZE)
local weaponIconHolder = weaponArt.holder

-- ── 오른쪽: 보유 보석 목록 + 홈 상세(리롤/변환권) ──
local infoPane = Instance.new("Frame")
infoPane.Name = "InfoPane"
infoPane.Position = UDim2.new(0, 220, 0, 0)
infoPane.Size = UDim2.new(1, -220, 1, 0)
infoPane.BackgroundTransparency = 1
infoPane.Parent = gemBody

local slotLabel = makeSectionLabel(infoPane, "홈 상세 (등급 상한 이하는 전부 장착 가능)", 8)

-- S20e: 변환 · 리롤은 보석상인의 "보석 공방"에서만 된다 - 이 행의 [리롤]은 진입점으로만 남아 누르면 토스트 "보석상인에게서 가능" + [위치 안내]가 나온다(변환권 구매 버튼은 공방으로 옮겼다).
local slotList = GemSlotRows.create(infoPane, {
	onReroll = Hint.toast,
})
local slotListScroll, slotRows = slotList.scroll, slotList.rows

local invLabel = makeSectionLabel(infoPane, "보유 보석", 250)

local bag = GemBag.create(infoPane, { applyGradeVisual = applyGradeVisual, screenGui = screenGui })
local gemInvScroll = bag.scroll

-- ═══ 상태 읽기 · 좌표 도우미 ═══

-- 폰 배치이거나 마지막 입력이 터치면 "탭 방식"(더블탭 · 드래그 없음, 탭 = 선택 토글). 판정은 화면 크기(폰 배치)가 기본이다 - 터치 없는 Studio 창에서도 같은 결과.
local function tapMode()
	return deps.isPhone() or UserInputService:GetLastInputType() == Enum.UserInputType.Touch
end

local function centerOf(frame)
	return frame.AbsolutePosition + frame.AbsoluteSize / 2
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

-- 홈 먼저(armed) 상태: 선택이 그 홈(gemSlot)일 때만 유효하다(다른 것을 선택하면 저절로 풀린다).
local armedFlag = nil
local function armedSlot()
	local kind, value = deps.getSelection()
	if armedFlag and kind == "gemSlot" and value == armedFlag then
		return armedFlag
	end
	return nil
end

local function selectedBagIndex()
	local kind, value = deps.getSelection()
	if kind == "gemBag" and currentGemState.gemInventory[value] then
		return value
	end
	return nil
end

-- ═══ 그리기: 홈 칩 · 보석칸 표시 · 상태 · 안내 ═══

local dragIndex, dragGrade, dragProxy, dragOrigin = nil, nil, nil, nil

local function slotMark(slot)
	if armedSlot() then
		return nil -- 홈 먼저 모드에서는 보석 쪽이 강조된다
	end
	local gradeId = dragGrade
	if not gradeId then
		local index = selectedBagIndex()
		gradeId = index and currentGemState.gemInventory[index].grade
	end
	if not gradeId then
		return nil
	end
	return Gem.socketBlockReason(currentGemState.slotUnlocked, slot, gradeId) and "blocked" or "ok"
end

local function paintSlots()
	local kind, value = deps.getSelection()
	for slot = 1, Gem.slotCount do
		local gem = currentGemState.gems[slot]
		local filled = type(gem) == "table"
		slots.paint(slot, {
			unlocked = Gem.isSlotUnlocked(currentGemState.slotUnlocked, slot),
			filled = filled,
			gemGrade = filled and gem.grade or nil,
			mark = slotMark(slot),
			selected = kind == "gemSlot" and value == slot,
		})
	end
end

local function paintCells()
	local armed = armedSlot()
	local selected = selectedBagIndex()
	bag.paint(function(index)
		local gem = currentGemState.gemInventory[index]
		local mark
		if armed and gem then
			mark = Gem.socketBlockReason(currentGemState.slotUnlocked, armed, gem.grade) and "blocked" or "ok"
		end
		return mark, selected == index, index > seenCount
	end)
end

-- 안내 줄: 보석상인을 써 본 적이 없으면 눈에 띄게, 써 본 뒤에는 작게(서버가 GemMerchantUsed Attribute로 알린다). 높이가 바뀌므로 배치를 다시 한다(아래 relayout).
local relayout
local function paintStatus()
	local usedBefore = header.isUsed()
	header.paint(player:GetAttribute("GemMerchantUsed") == true)
	if header.isUsed() ~= usedBefore and relayout then
		relayout()
	end
end

-- 안내 한 줄(상황별). "끼운 보석을 선택하면 리롤 · 변환권과 함께 교체 방법을 알려 준다"(사용자 결정).
local function hintText()
	local kind = deps.getSelection()
	local phone = tapMode()
	if armedSlot() then
		return phone and "교체할 보석을 탭 - 밝은 보석만 가능 · 빈 곳 탭 = 취소" or "교체할 보석을 클릭하세요 - 밝은 보석만 가능 · Esc · 빈 곳 클릭 = 취소"
	elseif kind == "gemBag" then
		return phone and "[장착] = 자동 장착 · 강조된 홈을 탭 = 그 홈에 장착" or "더블클릭 · 우클릭 · [장착] = 자동 장착 · 끌어서 원하는 홈에 놓기"
	elseif kind == "gemSlot" then
		return "다른 보석으로 교체하려면 보석칸에서 선택"
	end
	return phone and "보석 탭 → [장착] 또는 홈 탭 · 홈 탭 → 보석 탭" or "보석 더블클릭 · 우클릭 = 자동 장착 · 홈 더블클릭 · 우클릭 = 홈 골라 교체"
end

local function paintHint()
	header.setHint(hintText())
end

local function paintAll()
	paintSlots()
	paintCells()
	paintStatus()
	paintHint()
end

-- ═══ 장착 통로(GemActions) ═══

local actions = GemActions.create({
	screenGui = screenGui,
	getState = function()
		return currentGemState
	end,
	slotCenter = function(slot)
		return centerOf(slots.chips[slot].button)
	end,
	onEquipped = function(slot)
		-- 성공: 방금 끼운 보석을 홈 상세로 이어서 보여 준다(선택이 보석칸 → 홈으로 옮겨 가며 깜빡이지 않는다).
		armedFlag = nil
		seenCount = #currentGemState.gemInventory
		deps.select("gemSlot", slot)
		refreshDetail()
		paintAll()
	end,
	onPending = function()
		refreshDetail() -- [장착] 버튼이 요청 중에는 잠긴다
		paintHint()
	end,
})

local function equipInto(slot, index)
	return actions.equip(slot, index, { originPos = bag.center(index), fromPos = centerOf(slots.chips[slot].button) })
end

local function clearArm()
	if armedFlag then
		armedFlag = nil
		paintAll()
	end
end

local function armSlot(slot)
	if not Gem.isSlotUnlocked(currentGemState.slotUnlocked, slot) then
		Toast.push("TC", { text = GemActions.reasonText("slot_locked", nil, slot), colorName = "danger", grade = "notice", seconds = 2.5, groupKey = "gemEquipReject" })
		return
	end
	if armedFlag == slot and armedSlot() then
		armedFlag = nil -- 같은 홈을 다시 고르면 취소
		deps.select(nil, nil)
	else
		armedFlag = slot
		deps.select("gemSlot", slot)
	end
	refreshDetail()
	paintAll()
end

-- ═══ 드래그 앤 드롭(지시 "드래그로 보석 장착") ═══
-- Roblox UI는 표준 드래그 API가 없다 - 마우스 다운(cell.InputBegan)에서 화면 최상위(screenGui, win의 ClipsDescendants 밖) 프록시를 만들고, 전역 UserInputService로 위치를
-- 따라가다가(win 밖으로 나가도 계속 보여야 한다) 마우스 업에서 좌표가 홈 위에 있으면 GemActions.equip을 부른다 - 판정은 서버(GemEquipRequest)가 다시 한다(클라이언트 판정은 표시·프리뷰 전용).

local function slotAt(x, y)
	for slot = 1, Gem.slotCount do
		if screenPointInVisible(slots.chips[slot].button, x, y) or screenPointInVisible(slotRows[slot].row, x, y) then
			return slot
		end
	end
	return nil
end

cancelGemDrag = function()
	if dragProxy then
		dragProxy:Destroy()
	end
	dragProxy, dragIndex, dragGrade, dragOrigin = nil, nil, nil, nil
	bag.hideTip()
	paintSlots()
end

local function endGemDrag(x, y)
	if not dragProxy then
		return
	end
	local index, proxy, origin = dragIndex, dragProxy, dragOrigin
	local targetSlot = slotAt(x, y)
	dragProxy, dragIndex, dragGrade, dragOrigin = nil, nil, nil, nil -- 유령은 지우지 않고 GemActions에 넘긴다(거절이면 그 유령이 0.2초 동안 원래 칸으로 돌아간다)
	if targetSlot and index then
		actions.equip(targetSlot, index, { proxy = proxy, originPos = origin, fromPos = Vector2.new(x, y) })
	else
		proxy:Destroy()
		if index then
			-- 26-3(PRD 20.67 [12] "보유 보석 셀도 클릭 = 선택(드래그는 그대로 장착)") - 홈에 안 놓인 채 끝난 누름(=짧은 클릭)을 선택으로 처리한다.
			-- P3b C1: 같은 보석을 다시 누르면 상세가 닫힌다(선택 해제 - 토글).
			local selectedKind, selectedValue = deps.getSelection()
			if selectedKind == "gemBag" and selectedValue == index then
				deps.select(nil, nil)
			else
				deps.select("gemBag", index)
			end
			refreshDetail()
		end
	end
	paintAll()
end

local function startGemDrag(index, gradeId, cell)
	cancelGemDrag()
	dragIndex, dragGrade, dragOrigin = index, gradeId, centerOf(cell)
	local mouse = UserInputService:GetMouseLocation() - GuiService:GetGuiInset() -- ScreenGui 좌표(입력 이벤트의 Position과 같은 기준)
	dragProxy = GemActions.makeGhost(screenGui, mouse, gradeId)
	paintSlots()
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

-- ═══ 보석칸 · 홈의 입력 ═══

local lastCellClick = { key = nil, at = 0 } -- 마지막 눌림(어느 보석 · 언제) - 같은 것을 doubleClickSeconds 안에 다시 누르면 더블클릭
local lastSlotClick = { key = nil, at = 0 }

local function isDoubleClick(last, key)
	local now = os.clock()
	local double = last.key == key and now - last.at <= uiConfig.doubleClickSeconds
	last.key, last.at = (not double) and key or nil, now
	return double
end

-- 보석 셀 탭(탭 방식): 홈 먼저 모드면 그 홈에 교체 · 아니면 선택 토글.
local function onCellTap(index)
	local armed = armedSlot()
	if armed then
		equipInto(armed, index)
		return
	end
	if selectedBagIndex() == index then
		deps.select(nil, nil)
	else
		deps.select("gemBag", index)
	end
	refreshDetail()
	paintAll()
end

-- 홈 탭(탭 방식): 보석을 골라 둔 상태면 그 홈에 장착 · 아니면 그 홈을 "홈 먼저" 대상으로 고르기(다시 탭하면 취소).
local function onSlotTap(slot)
	local bagIndex = selectedBagIndex()
	if bagIndex then
		equipInto(slot, bagIndex)
		return
	end
	armSlot(slot)
end

-- 홈에 입력을 붙인다(칩 · 행 공통): PC 더블클릭 · 우클릭 = 홈 먼저 고르기 · 한 번 클릭 = 홈 상세(기존) / 탭 방식은 onSlotTap.
local function bindSlotInput(obj, slot)
	obj.InputBegan:Connect(function(input)
		local inputType = input.UserInputType
		if inputType == Enum.UserInputType.MouseButton2 then
			armSlot(slot)
		elseif inputType == Enum.UserInputType.MouseButton1 and not tapMode() then
			if isDoubleClick(lastSlotClick, slot) then
				armSlot(slot)
			end
		end
	end)
	obj.Activated:Connect(function()
		if tapMode() then
			onSlotTap(slot)
		elseif Gem.isSlotUnlocked(currentGemState.slotUnlocked, slot) and Gem.isFilled(currentGemState.gems, slot) then
			local selectedKind, selectedValue = deps.getSelection()
			if selectedKind == "gemSlot" and selectedValue == slot then
				deps.select(nil, nil) -- P3b C1: 같은 홈을 다시 누르면 상세가 닫힌다(토글)
			else
				deps.select("gemSlot", slot)
			end
			refreshDetail()
			paintAll()
		end
	end)
end

for slot = 1, Gem.slotCount do
	bindSlotInput(slots.chips[slot].button, slot)
	bindSlotInput(slotRows[slot].row, slot)
end

-- 보석 셀의 눌림(PC): 우클릭 = 자동 장착 · 왼쪽 = 홈 먼저 모드면 그 홈에 교체 / 더블클릭이면 자동 장착 / 아니면 드래그 시작(놓으면 홈 위면 장착, 아니면 선택 - 상세를 한 번만 그린다).
local function onCellInput(input, index, gem, cell)
	local inputType = input.UserInputType
	if inputType == Enum.UserInputType.MouseButton2 then
		actions.autoEquip(index, { originPos = centerOf(cell) })
	elseif inputType == Enum.UserInputType.MouseButton1 and not tapMode() then
		local armed = armedSlot()
		if armed then
			equipInto(armed, index)
		elseif isDoubleClick(lastCellClick, index) then
			actions.autoEquip(index, { originPos = centerOf(cell) })
		else
			startGemDrag(index, gem.grade, cell)
		end
	end
end

local function rebuildGemInventory()
	bag.rebuild(currentGemState.gemInventory, Gem.displayOrder(currentGemState.gemInventory), { -- 표시 순서 = 등급 높은 순(같은 등급은 획득 순) - 서버 index는 셀이 그대로 들고 간다
		onInput = onCellInput,
		hoverText = actions.replaceText, -- S20d: PC 호버 = "교체될 보석: ..."(교체가 없으면 안 나온다)
		tapMode = tapMode,
		onActivated = function(index)
			if tapMode() then
				onCellTap(index)
			end
		end,
	})
end

updateGemTab = function()
	if not deps.isOpen() then
		return
	end

	local classId = player:GetAttribute("ClassId")
	local weaponGrade = weaponGradeId()
	weaponArt.update(weaponGrade, classId)

	for slot = 1, Gem.slotCount do
		local ui = slotRows[slot]
		local unlocked = Gem.isSlotUnlocked(currentGemState.slotUnlocked, slot)
		local capGradeId = Gem.gradeCapForSlot(slot)
		local capInfo = ArmorData.grades[capGradeId]

		if not unlocked then
			ui.label.Text = ("홈%d(상한 %s) - 잠김, 환생 %d회 필요"):format(slot, capInfo.displayName, GemData.slotUnlockRequiredRebirth[slot])
			ui.rerollButton.Visible = false
			continue
		end

		local gem = currentGemState.gems[slot]
		local filled = type(gem) == "table"
		-- 26-3(PRD 20.67 [9][12]) - "N번 홈 · 상한 <등급> · <등급> <옵션명> 보석 · Lv.N · +X%" 형식으로 통일한다(옛 "홈N(상한 X) - 등급: 옵션(값)" 형식을 대신한다).
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
		if rerollable then
			-- S20e: 진입점으로만 남는다 - 항상 눌린다(변환권이 없어도 "보석상인에게서 가능"을 알려야 하므로 회색으로 막지 않는다).
			local tickets = currentGemState.rerollTickets[gem.grade] or 0
			ui.rerollButton.Text = ("리롤(%d장)"):format(tickets)
		end
	end

	rebuildGemInventory()
	paintAll()
	-- 26-3: 지금 Detail에 보석이 선택돼 있으면(리롤 등으로 옵션이 막 바뀌었을 수 있다) 같이 갱신한다. 장착 요청이 도는 중에는 건너뛴다 - 보석칸 index가 밀려 잠깐 다른 보석이 보이는 깜빡임을
	-- 막는다(결과가 오면 onEquipped가 한 번에 갱신한다).
	local selectedKind = deps.getSelection()
	if (selectedKind == "gemSlot" or selectedKind == "gemBag") and not actions.isPending() then
		refreshDetail()
	end
end

-- 분해로 보석이 늘면 토스트로 알린다(누르면 보석 탭). 보석칸 수가 늘어나는 경로는 분해뿐이다(교체는 1대1 · 환생 · 리롤은 수가 그대로다).
local function pushGainToast()
	Toast.push("TC", {
		text = "보석 획득 [보석 탭 열기]",
		richParts = {
			{ text = "보석 획득 ", colorName = "textPrimary" },
			{ text = "[보석 탭 열기]", colorName = "success", bold = true, onActivate = function()
				deps.selectTab("보석")
			end },
		},
		grade = "notice",
		seconds = 4,
		groupKey = "gemGain",
	})
end

local lastClassId = nil
local function applyState(data)
	local previousCount = #currentGemState.gemInventory
	currentGemState = data
	local classId = player:GetAttribute("ClassId")
	if not initialized or classId ~= lastClassId then
		-- 첫 스냅샷 · 직업을 바꾼 뒤(다른 직업의 보석칸이 온다)의 보석은 새로 얻은 것이 아니다
		initialized = true
		lastClassId = classId
		seenCount = #data.gemInventory
	elseif #data.gemInventory > previousCount and not (gemBody.Visible and deps.isOpen()) then
		pushGainToast()
	end
	if armedFlag and not Gem.isSlotUnlocked(data.slotUnlocked, armedFlag) then
		armedFlag = nil
	end
	updateGemTab()
end

-- 26-3: 옵션 보너스 박스(gear 탭)가 보석 옵션도 합산한다 - GemSync가 올 때도 refreshStats를 불러야 리롤·장착 직후 그 자리가 바로 갱신된다(안 그러면 보석 탭을 오가야만 갱신됐다).
gemSync.OnClientEvent:Connect(function(data)
	applyState(data)
	if deps.isOpen() then
		refreshStats()
	end
end)

task.spawn(function()
	local ok, data = pcall(function()
		return gemFetch:InvokeServer()
	end)
	if ok and data then
		applyState(data)
		if deps.isOpen() then
			refreshStats()
		end
	end
end)

for _, attr in ipairs({ "RebirthCount", "InfiniteStage", "AccountBestStage" }) do
	player:GetAttributeChangedSignal(attr):Connect(updateGemTab)
end

-- ═══ 전역 입력: Esc · 빈 곳 클릭 = 취소 / 폰에서 빈 곳 탭 = 선택 해제 ═══

-- 이 화면 좌표가 보석 탭의 조작 대상(홈 칩 · 홈 행 · 보석 셀) 위인가(빈 곳 판정용).
local function overTarget(x, y)
	for slot = 1, Gem.slotCount do
		if screenPointInVisible(slots.chips[slot].button, x, y) or screenPointInVisible(slotRows[slot].row, x, y) then
			return true
		end
	end
	for _, ref in pairs(bag.refs) do
		if ref.cell.Parent and screenPointInVisible(ref.cell, x, y) then
			return true
		end
	end
	return false
end

UserInputService.InputBegan:Connect(function(input)
	if not (gemBody.Visible and deps.isOpen()) then
		return
	end
	local inputType = input.UserInputType
	if input.KeyCode == Enum.KeyCode.Escape then
		if armedSlot() then
			clearArm()
		end
	elseif inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.Touch then
		local x, y = input.Position.X, input.Position.Y
		if not screenPointInFrame(gemBody, x, y) or overTarget(x, y) then
			return
		end
		if armedSlot() then
			clearArm() -- 홈 먼저 모드: 빈 곳 클릭 = 취소(선택은 그대로)
		elseif tapMode() and (selectedBagIndex() or deps.getSelection() == "gemSlot") then
			deps.select(nil, nil) -- 탭 방식: 빈 곳 탭 = 선택 해제
			refreshDetail()
			paintAll()
		end
	end
end)

-- 보석상인을 처음 써서 hints.gemMerchantUsed가 true가 되면(서버가 GemMerchantUsed Attribute로 알린다) 안내 줄이 눈에 띄는 모양에서 작은 회색 줄로 줄어든다. 탭이 보였다가 사라지면 그 사이 본 보석은 NEW가 아니다.
player:GetAttributeChangedSignal("GemMerchantUsed"):Connect(paintStatus)

gemBody:GetPropertyChangedSignal("Visible"):Connect(function()
	if gemBody.Visible then
		updateGemTab()
	else
		seenCount = #currentGemState.gemInventory -- 이 탭을 본 뒤 떠났다 - 그 보석들은 더 이상 NEW가 아니다
		armedFlag = nil
	end
end)

-- 배치(S20b · S20c) - 화면 크기가 정하는 L(Layout.compute)로 두 칸의 크기 · 위치와 터치 크기를 다시 정한다.
local lastLayout = nil
local function layout(L)
	lastLayout = L
	local phone = L.mode == "phone"
	gemBody.Position = UDim2.new(0, 0, 0, L.bodyTop)
	gemBody.Size = UDim2.new(1, 0, 0, L.bodyH - deps.sheetInset()) -- 폰: 상세 시트가 올라와 있으면 그만큼 짧다
	local rowHeight = phone and 76 or 42
	local buttonHeight = phone and 44 or 17
	for _, entry in ipairs(slotRows) do
		entry.row.Size = UDim2.new(1, 0, 0, rowHeight)
		entry.rerollButton.Size = UDim2.new(0, 64, 0, buttonHeight)
		entry.rerollButton.Position = UDim2.new(0, 8, 1, -(buttonHeight + 3))
	end
	local chipSize = phone and CHIP_SIZE.phone or CHIP_SIZE.pc
	slots.setLayout(chipSize, phone and CHIP_GAP.phone or CHIP_GAP.pc)
	weaponLabel.Visible = not phone
	weaponIconHolder.Visible = not phone
	slots.row.Position = UDim2.new(0, 14, 0, phone and 4 or 26)
	weaponIconHolder.Position = UDim2.new(0.5, 0, 0, 26 + chipSize + 12)
	-- 정보 칸: 보유 보석(끌어 오는 곳)이 위 · 홈 상세(행 · 리롤)가 아래. PC = 무기 칸의 홈(드롭 대상)과 보유 보석이 스크롤 0에서 함께 보여야 낮은 PC 창(본문 232)에서도 끌어 놓을 수 있다.
	-- 폰 = 홈 한 줄(왼쪽 300)과 보유 보석(오른쪽)을 같은 높이에 나란히 놓는다 - 상세 시트(84)가 올라와 본문이 106만 남아도 홈과 보석이 스크롤 없이 함께 보여야 탭 → 탭 장착이 된다.
	header.setLayout(phone)
	invLabel.Visible = not phone
	invLabel.Text = "보유 보석 - 더블클릭 · 우클릭 · 드래그"
	local top = header.height()
	local bagTop = phone and 4 or 26
	local invHeight = phone and 66 or 134
	local slotTop = bagTop + invHeight + 12 -- 홈 상세 제목 y
	local listHeight = phone and Gem.slotCount * (rowHeight + 4) or 216
	local bagX = phone and 0 or 14
	invLabel.Position = UDim2.new(0, 14, 0, 8)
	gemInvScroll.Position = UDim2.new(0, bagX, 0, bagTop)
	gemInvScroll.Size = UDim2.new(1, -(bagX + 14), 0, invHeight)
	slotLabel.Position = UDim2.new(0, 14, 0, slotTop)
	slotListScroll.Position = UDim2.new(0, 14, 0, slotTop + 18)
	slotListScroll.Size = UDim2.new(1, -28, 0, listHeight)
	local infoHeight = slotTop + 18 + listHeight + 14
	local canvasHeight
	if phone then
		local weaponPaneHeight = 4 + chipSize + 8
		weaponPane.Position = UDim2.new(0, 0, 0, top)
		weaponPane.Size = UDim2.new(0, PHONE_LEFT_WIDTH, 0, weaponPaneHeight)
		weaponPaneLine.Visible = false
		infoPane.Position = UDim2.new(0, PHONE_LEFT_WIDTH, 0, top)
		infoPane.Size = UDim2.new(1, -PHONE_LEFT_WIDTH, 0, infoHeight)
		canvasHeight = top + math.max(weaponPaneHeight, infoHeight)
	else
		canvasHeight = math.max(top + infoHeight, L.bodyH)
		weaponPane.Position = UDim2.new(0, 0, 0, top)
		weaponPane.Size = UDim2.new(0, 220, 0, canvasHeight - top)
		weaponPaneLine.Visible = true
		infoPane.Position = UDim2.new(0, 220, 0, top)
		infoPane.Size = UDim2.new(1, -220, 0, canvasHeight - top)
	end
	gemBody.CanvasSize = UDim2.new(0, 0, 0, canvasHeight)
	paintAll() -- 폰 시트가 올라오거나 내려갈 때(선택이 바뀔 때)도 여기서 표시를 다시 맞춘다
end
deps.registerLayout(layout)
relayout = function() -- 안내 줄 높이가 바뀌었을 때(paintStatus) 같은 화면 크기로 다시 배치한다
	if lastLayout then
		layout(lastLayout)
	end
end

return {
	update = function()
		updateGemTab()
	end,
	cancelDrag = function()
		-- 창을 닫을 때: 드래그 취소 + 홈 먼저 취소 + 이 탭을 보고 있었으면 NEW 확인
		cancelGemDrag()
		armedFlag = nil
		if gemBody.Visible then
			seenCount = #currentGemState.gemInventory
		end
	end,
	state = function()
		return currentGemState
	end,
	canAutoEquip = function(index)
		return actions.canAutoEquip(index)
	end,
	autoEquip = function(index)
		return actions.autoEquip(index, { originPos = bag.center(index) })
	end,
	replaceText = actions.replaceText, -- 상세 시트의 [장착] 버튼 위 한 줄(S20d)
	frame = gemBody,
	-- Studio 자체 점검 전용(GemFlowCheck): 서버 없이 상태를 넣어 그리고 · 다시 그리고 · 홈 먼저 상태를 강제한다.
	debugApply = function(state)
		applyState(state)
	end,
	debugPaint = function()
		paintAll()
	end,
	debugArm = function(slot)
		armedFlag = slot
		deps.select("gemSlot", slot)
		refreshDetail()
		paintAll()
	end,
}
end

return GemTab
