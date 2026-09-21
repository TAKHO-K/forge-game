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
--
-- S20b: 이 파일은 배선만 한다 - 창 껍데기(panels/Inventory/Shell) · 장비 칸(GearTab) · 가방 칸(BagTab) · 상세(DetailSheet) · 일괄판매(BulkSell) · 보석 탭(GemTab)이 각자 파일이고,
-- 공용 상태는 Store(S) · 프레임 참조는 R 표 하나로 나눈다. 배율(UIScale)은 없다 - 화면이 좁으면 Layout이 배치를 바꾼다(폰 = 1단 + 탭 3개 + 하단 시트).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local FullTextTip = require(script.Parent.ui.kit.FullTextTip)
local Theme = require(script.Parent.ui.kit.Theme)
local UIManager = require(script.Parent.UIManager)
local BagTab = require(script.Parent.panels.Inventory.BagTab)
local BulkSell = require(script.Parent.panels.Inventory.BulkSell)
local DetailSheet = require(script.Parent.panels.Inventory.DetailSheet)
local GearTab = require(script.Parent.panels.Inventory.GearTab)
local GemTab = require(script.Parent.panels.Inventory.GemTab)
local Shell = require(script.Parent.panels.Inventory.Shell)
local Store = require(script.Parent.panels.Inventory.Store)
local ItemActions = require(script.Parent.panels.Inventory.ItemActions)

local inventorySync = ReplicatedStorage:WaitForChild("InventorySync")
local inventoryFetch = ReplicatedStorage:WaitForChild("InventoryFetch")
local inventoryFull = ReplicatedStorage:WaitForChild("InventoryFull")

local S = Store
local player = S.player
local R = {}
S.R = R -- 점검(InventoryLayoutCheck)이 R.debugForceScreen · R.selectTab을 부른다

Shell.create(S, R)
ItemActions.attach(S, R) -- S20d: 착용 · 해제 입력의 유일한 통로(S.equipFromBag · S.unequipToBag) - 세 탭이 만들어지기 전에 붙는다
GearTab.create(S, R)
BagTab.create(S, R)
DetailSheet.create(S, R)
BulkSell.create(S, R)

-- ═══ 보석 탭(S20b: panels/Inventory/GemTab.lua로 옮김 - 23-4 · 26-3 주석은 그쪽에 있다) ═══
local gemTab = GemTab.create({
	content = R.content,
	screenGui = R.screenGui,
	registerLayout = function(fn)
		table.insert(R.layouts, fn)
	end,
	isOpen = function()
		return S.isOpen
	end,
	sheetInset = function()
		return S.sheetInset
	end,
	isPhone = function()
		return S.mode == "phone"
	end,
	selectTab = function(name)
		R.selectTab(name)
	end,
	getSelection = function()
		return S.selectedKind, S.selectedValue
	end,
	select = function(kind, value)
		S.selectedKind, S.selectedValue = kind, value
	end,
	refreshDetail = S.refreshDetail,
	refreshStats = S.refreshStats,
	weaponGradeId = S.weaponGradeId,
	applyGradeVisual = S.applyGradeVisual,
	makeSectionLabel = S.makeSectionLabel,
})
R.gemFrame = gemTab.frame
S.gemState = function()
	return gemTab.state()
end
S.gemCanAutoEquip = gemTab.canAutoEquip -- 상세 시트의 [장착] 버튼(S20c) - 보석 탭의 GemActions 통로를 그대로 쓴다
S.gemAutoEquip = gemTab.autoEquip
S.gemReplaceText = gemTab.replaceText -- 상세 시트의 [장착] 버튼 위 미리보기 한 줄(S20d)
R.gemTab = gemTab -- 점검(GemFlowCheck)이 debugApply · debugPaint를 부른다
R.applyLayout() -- 모든 탭이 만들어진 뒤 첫 배치

-- S12b G: 글씨를 4단(20 · 16 · 14 · 12)으로 키우면서 넘칠 수 있는 고정 폭 글은 줄임표 + 가리키거나 누르면 전체 글(FullTextTip). 나중에 지어지는 행에도 자동으로 붙는다.
FullTextTip.attach(R.content, R.screenGui)

-- ═══ 열기/닫기(18-1부터 UIManager에 위임 - 트윈·ESC 대체키·모바일 처리는 전부 거기서 공통으로 한다. 이 파일은 "열렸을 때 뭘 다시 그릴지"만 onOpen에 남긴다) ═══
UIManager.register("inventory", {
	screenGui = R.screenGui,
	frame = R.win,
	extraVisible = { R.dim },
	-- 단축키(B - S20 사전 작업에서 I에서 바꿈)는 ui/PanelRegistry.lua 표에 있다(30-0 S06) - UIManager의 hotkey 루프가 그 표를 읽는다.
	modal = true,
	exclusive = true,
	hasCloseButton = true,
	tweens = {
		{ instance = R.dim, property = "BackgroundTransparency", open = UIColors.overlayDimTransparency, closed = 1 },
		{ instance = R.winBackground, property = "BackgroundTransparency", open = 0.14, closed = 1 },
		{ instance = R.winStroke, property = "Transparency", open = UIColors.rimTransparency, closed = 1 },
	},
	onOpen = function()
		S.isOpen = true
		R.applyLayout() -- 닫혀 있는 동안 화면 크기가 바뀌었을 수 있다(창 회전 등).
		S.rebuildGearSlots()
		S.rebuildGrid()
		S.refreshStats()
		gemTab.update()
	end,
	onClose = function()
		S.isOpen = false
		S.bulkSellDropdownOpen = false
		if R.cutoffDropdown then
			R.cutoffDropdown.Visible = false
			R.cutoffDropdownDim.Visible = false
		end
		gemTab.cancelDrag()
	end,
})

R.toggleButton.Activated:Connect(function()
	UIManager.toggle("inventory")
end)

-- 18-2 [7]: 딤 배경 클릭으로 닫지 않는다 - 클릭이 곧 공격인 게임이라 가방 정리 중 손이 미끄러지면 창이 사라진다(검증 중 발견). dim은 TextButton이라 Activated 연결이 없어도
-- 클릭 자체는 계속 먹는다(뒤로 공격이 새 나가지 않는다) - 닫기는 X·B·Backspace만 한다.
R.closeButton.Activated:Connect(function()
	UIManager.close("inventory")
end)

-- ═══ 서버 동기화 ═══

local function onStateChanged(state)
	S.inventory = state.inventory
	S.equippedArmor = state.armor
	S.equippedGloves = state.gloves
	S.equippedShoes = state.shoes
	if S.isOpen then
		S.rebuildGearSlots()
		S.rebuildGrid()
		S.refreshStats()
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
	if S.isOpen then
		R.goldPillLabel.Text = "보유 골드 " .. NumberFormat.format(player:GetAttribute("Gold") or 0)
	end
end)

for _, attr in ipairs({ "ClassId", "WeaponLevel", "WeaponGrade", "CharacterLevel", "MaxHp" }) do
	player:GetAttributeChangedSignal(attr):Connect(function()
		if S.isOpen then
			S.refreshStats()
			S.rebuildGearSlots()
		end
	end)
end


-- 인벤토리가 가득 찼을 때(14-1부터 "땅의 아이템을 못 주웠다"는 뜻) - 간단한 중앙 토스트로만
-- 알린다(옛 ItemPickupHud - S17부터 hud/SystemToasts.client.lua - 와 같은 가벼운 패턴). 새 창을 새로 열 만한 무게의
-- 이벤트가 아니다.
local fullToast = Instance.new("TextLabel")
fullToast.Name = "InventoryFullToast" -- ScreenMap 슬롯 표(TC.inventoryFull)가 이 이름으로 찾는다
fullToast.AnchorPoint = Vector2.new(0.5, 0.5)
fullToast.Position = UDim2.new(0.5, 0, 0.4, 0)
fullToast.Size = UDim2.new(0, 360, 0, 40)
fullToast.BackgroundTransparency = 1
fullToast.TextTransparency = 1
fullToast.TextStrokeTransparency = 0.6
fullToast.Font = Enum.Font.GothamBold
fullToast.TextSize = Theme.textSize("header")
fullToast.TextColor3 = UIColors.danger
fullToast.Text = "인벤토리가 가득 찼습니다 - 땅에 있는 아이템을 주울 수 없습니다"
fullToast.Parent = R.screenGui

inventoryFull.OnClientEvent:Connect(function()
	TweenService:Create(fullToast, TweenInfo.new(0.15), { TextTransparency = 0 }):Play()
	task.delay(2, function()
		TweenService:Create(fullToast, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
	end)
end)
