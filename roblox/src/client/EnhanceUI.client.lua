-- 강화 UI(10-2). 기능 확인 수준 - 폴리시(꾸미기)는 UI 세션에서 한꺼번에 한다. 강화대
-- 근처에서만 보인다(거리 기준, WorldConfig.enhance.interactionRangeStuds와 서버가 같은
-- 값을 쓴다). 서버 Attribute(WeaponLevel/Gold)만 읽는다 - 확률·비용 표시는 Enhance
-- 조회 함수로 계산하되, 실제 판정은 절대 여기서 하지 않는다(서버 전용, EnhanceServer.server.lua).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Enhance = require(ReplicatedStorage.Shared.Enhance)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local GemData = require(ReplicatedStorage.Shared.data.GemData)
local Gem = require(ReplicatedStorage.Shared.Gem)
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)

local enhanceRequest = ReplicatedStorage:WaitForChild("EnhanceRequest")
local enhanceResult = ReplicatedStorage:WaitForChild("EnhanceResult")
-- 23-2: 환생·분해·보석 슬롯·옵션 변환권(PRD 20.37/20.38) - 강화대가 무기 관련 상호작용의
-- 기존 허브라 같은 패널에 탭으로 붙인다(20.37 [3] "분해 UI는 강화대에 둔다"와 같은 판단을
-- 환생·보석에도 그대로 적용 - 새 UI 스타일을 만들지 않는다는 지시).
local rebirthRequest = ReplicatedStorage:WaitForChild("RebirthRequest")
local rebirthResult = ReplicatedStorage:WaitForChild("RebirthResult")
local gemEquipRequest = ReplicatedStorage:WaitForChild("GemEquipRequest")
local gemRerollRequest = ReplicatedStorage:WaitForChild("GemRerollRequest")
local buyRerollTicketRequest = ReplicatedStorage:WaitForChild("BuyRerollTicketRequest")
local gemSync = ReplicatedStorage:WaitForChild("GemSync")
local gemFetch = ReplicatedStorage:WaitForChild("GemFetch")

local RESULT_LABEL = {
	success = "성공! +%d",
	maintain = "실패 - 형상유지 (+%d)",
	down1 = "실패 - 1강 하락 (+%d)",
	down2 = "실패 - 2강 하락 (+%d)",
	reset = "실패 - 초기화 (+%d)",
	max = "이미 최대 강화 단계입니다",
	insufficient_gold = "골드가 부족합니다",
}

local player = Players.LocalPlayer
local stationPosition = WorldConfig.huntingGround.center + WorldConfig.enhance.stationOffset

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "EnhanceGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "EnhancePanel"
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.new(0.5, 0, 1, -120)
panel.Size = UDim2.new(0, 320, 0, 208)
panel.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
panel.BackgroundTransparency = 0.1
panel.Visible = false
panel.Parent = screenGui

-- 탭 3개(강화/환생/보석, 23-2 신설) - 기존 320px 패널 폭을 그대로 3등분한다. 같은 색
-- 규칙(선택 탭=골드, 나머지=어두운 회색)만 쓴다 - 새 색을 만들지 않는다.
local TAB_NAMES = { "강화", "환생", "보석" }
local tabButtons = {}
local tabContents = {}
local activeTab = "강화"

local tabRow = Instance.new("Frame")
tabRow.Size = UDim2.new(1, 0, 0, 28)
tabRow.Position = UDim2.new(0, 0, 0, 0)
tabRow.BackgroundTransparency = 1
tabRow.Parent = panel

local function selectTab(name)
	activeTab = name
	for tabName, btn in pairs(tabButtons) do
		btn.BackgroundColor3 = tabName == name and Color3.fromRGB(200, 160, 40) or Color3.fromRGB(40, 40, 46)
	end
	for tabName, frame in pairs(tabContents) do
		frame.Visible = tabName == name
	end
end

for i, name in ipairs(TAB_NAMES) do
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1 / #TAB_NAMES, 0, 1, 0)
	btn.Position = UDim2.new((i - 1) / #TAB_NAMES, 0, 0, 0)
	btn.Text = name
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 15
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
	btn.Parent = tabRow
	tabButtons[name] = btn
	btn.Activated:Connect(function()
		selectTab(name)
	end)
end

-- ═══ 강화 탭(기존 내용 그대로, 탭 프레임 안으로 이동만 했다) ═══

local enhanceTab = Instance.new("Frame")
enhanceTab.Size = UDim2.new(1, 0, 1, -28)
enhanceTab.Position = UDim2.new(0, 0, 0, 28)
enhanceTab.BackgroundTransparency = 1
enhanceTab.Parent = panel
tabContents["강화"] = enhanceTab

local infoLabel = Instance.new("TextLabel")
infoLabel.BackgroundTransparency = 1
infoLabel.Size = UDim2.new(1, -16, 0, 90)
infoLabel.Position = UDim2.new(0, 8, 0, 8)
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.TextYAlignment = Enum.TextYAlignment.Top
infoLabel.TextWrapped = true
infoLabel.Font = Enum.Font.Gotham
infoLabel.TextSize = 16
infoLabel.TextColor3 = Color3.new(1, 1, 1)
infoLabel.Text = ""
infoLabel.Parent = enhanceTab

local enhanceButton = Instance.new("TextButton")
enhanceButton.Size = UDim2.new(0, 140, 0, 40)
enhanceButton.Position = UDim2.new(0.5, -70, 1, -48)
enhanceButton.Text = "강화"
enhanceButton.Font = Enum.Font.GothamBold
enhanceButton.TextSize = 18
enhanceButton.BackgroundColor3 = Color3.fromRGB(200, 160, 40)
enhanceButton.Parent = enhanceTab

local resultLabel = Instance.new("TextLabel")
resultLabel.BackgroundTransparency = 1
resultLabel.Size = UDim2.new(1, -16, 0, 20)
resultLabel.Position = UDim2.new(0, 8, 1, -74)
resultLabel.Font = Enum.Font.GothamBold
resultLabel.TextSize = 14
resultLabel.TextColor3 = Color3.fromRGB(255, 220, 90)
resultLabel.Text = ""
resultLabel.Parent = enhanceTab

-- ═══ 환생 탭(23-2, PRD 20.38 [1][2]) ═══

local rebirthTab = Instance.new("Frame")
rebirthTab.Size = UDim2.new(1, 0, 1, -28)
rebirthTab.Position = UDim2.new(0, 0, 0, 28)
rebirthTab.BackgroundTransparency = 1
rebirthTab.Visible = false
rebirthTab.Parent = panel
tabContents["환생"] = rebirthTab

local rebirthInfoLabel = Instance.new("TextLabel")
rebirthInfoLabel.BackgroundTransparency = 1
rebirthInfoLabel.Size = UDim2.new(1, -16, 0, 90)
rebirthInfoLabel.Position = UDim2.new(0, 8, 0, 8)
rebirthInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
rebirthInfoLabel.TextYAlignment = Enum.TextYAlignment.Top
rebirthInfoLabel.TextWrapped = true
rebirthInfoLabel.Font = Enum.Font.Gotham
rebirthInfoLabel.TextSize = 16
rebirthInfoLabel.TextColor3 = Color3.new(1, 1, 1)
rebirthInfoLabel.Text = ""
rebirthInfoLabel.Parent = rebirthTab

local rebirthButton = Instance.new("TextButton")
rebirthButton.Size = UDim2.new(0, 140, 0, 40)
rebirthButton.Position = UDim2.new(0.5, -70, 1, -48)
rebirthButton.Text = "환생"
rebirthButton.Font = Enum.Font.GothamBold
rebirthButton.TextSize = 18
rebirthButton.BackgroundColor3 = Color3.fromRGB(200, 160, 40)
rebirthButton.Parent = rebirthTab

local rebirthResultLabel = Instance.new("TextLabel")
rebirthResultLabel.BackgroundTransparency = 1
rebirthResultLabel.Size = UDim2.new(1, -16, 0, 20)
rebirthResultLabel.Position = UDim2.new(0, 8, 1, -74)
rebirthResultLabel.Font = Enum.Font.GothamBold
rebirthResultLabel.TextSize = 14
rebirthResultLabel.TextColor3 = Color3.fromRGB(255, 220, 90)
rebirthResultLabel.Text = ""
rebirthResultLabel.Parent = rebirthTab

-- 확인창(지시 - "환생은 되돌릴 수 없는 조작이다... 확인 단계 없이 즉시 실행되지 않게 하라").
-- 화면 전체를 덮어 패널 뒤 다른 조작이 새어 들어가지 않게 한다.
local rebirthConfirmOverlay = Instance.new("Frame")
rebirthConfirmOverlay.Size = UDim2.new(1, 0, 1, 0)
rebirthConfirmOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
rebirthConfirmOverlay.BackgroundTransparency = 0.4
rebirthConfirmOverlay.Visible = false
rebirthConfirmOverlay.ZIndex = 10
rebirthConfirmOverlay.Parent = screenGui

local rebirthConfirmBox = Instance.new("Frame")
rebirthConfirmBox.AnchorPoint = Vector2.new(0.5, 0.5)
rebirthConfirmBox.Position = UDim2.new(0.5, 0, 0.5, 0)
rebirthConfirmBox.Size = UDim2.new(0, 280, 0, 140)
rebirthConfirmBox.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
rebirthConfirmBox.ZIndex = 11
rebirthConfirmBox.Parent = rebirthConfirmOverlay

local rebirthConfirmLabel = Instance.new("TextLabel")
rebirthConfirmLabel.BackgroundTransparency = 1
rebirthConfirmLabel.Size = UDim2.new(1, -16, 0, 70)
rebirthConfirmLabel.Position = UDim2.new(0, 8, 0, 8)
rebirthConfirmLabel.TextWrapped = true
rebirthConfirmLabel.Font = Enum.Font.Gotham
rebirthConfirmLabel.TextSize = 15
rebirthConfirmLabel.TextColor3 = Color3.new(1, 1, 1)
rebirthConfirmLabel.ZIndex = 11
rebirthConfirmLabel.Text = "정말 환생하시겠습니까?\n레벨과 무한 스테이지가 1로 초기화됩니다 - 되돌릴 수 없습니다."
rebirthConfirmLabel.Parent = rebirthConfirmBox

local rebirthConfirmYes = Instance.new("TextButton")
rebirthConfirmYes.Size = UDim2.new(0, 120, 0, 36)
rebirthConfirmYes.Position = UDim2.new(0, 12, 1, -48)
rebirthConfirmYes.Text = "환생한다"
rebirthConfirmYes.Font = Enum.Font.GothamBold
rebirthConfirmYes.TextSize = 15
rebirthConfirmYes.BackgroundColor3 = Color3.fromRGB(200, 160, 40)
rebirthConfirmYes.ZIndex = 11
rebirthConfirmYes.Parent = rebirthConfirmBox

local rebirthConfirmNo = Instance.new("TextButton")
rebirthConfirmNo.Size = UDim2.new(0, 120, 0, 36)
rebirthConfirmNo.Position = UDim2.new(1, -132, 1, -48)
rebirthConfirmNo.Text = "취소"
rebirthConfirmNo.Font = Enum.Font.GothamBold
rebirthConfirmNo.TextSize = 15
rebirthConfirmNo.BackgroundColor3 = Color3.fromRGB(60, 60, 66)
rebirthConfirmNo.ZIndex = 11
rebirthConfirmNo.Parent = rebirthConfirmBox

local function updateRebirthInfo()
	local rebirthCount = player:GetAttribute("RebirthCount") or 0
	local level = player:GetAttribute("CharacterLevel") or 1
	if rebirthCount >= GemData.maxRebirthCount then
		rebirthInfoLabel.Text = ("환생 %d/%d회 완료 - 더 이상 환생할 수 없습니다."):format(rebirthCount, GemData.maxRebirthCount)
		rebirthButton.Text = "완료"
		rebirthButton.AutoButtonColor = false
		return
	end

	local requiredLevel = 25 * (rebirthCount + 1)
	rebirthButton.Text = "환생"
	rebirthButton.AutoButtonColor = true
	rebirthInfoLabel.Text = ("환생 %d/%d회 · 현재 레벨 %d\n필요 레벨 %d - 레벨을 1로 초기화하고 무기 등급·보석 슬롯을 1단계 올립니다.\n경험치 배수 ×%d → ×%d"):format(
		rebirthCount, GemData.maxRebirthCount, level, requiredLevel, rebirthCount + 1, rebirthCount + 2)
end

rebirthButton.Activated:Connect(function()
	if (player:GetAttribute("RebirthCount") or 0) >= GemData.maxRebirthCount then
		return
	end
	rebirthConfirmOverlay.Visible = true
end)

rebirthConfirmNo.Activated:Connect(function()
	rebirthConfirmOverlay.Visible = false
end)

rebirthConfirmYes.Activated:Connect(function()
	rebirthConfirmOverlay.Visible = false
	rebirthRequest:FireServer()
end)

rebirthResult.OnClientEvent:Connect(function(data)
	if data.success then
		rebirthResultLabel.Text = ("환생 성공! %d회차"):format(data.rebirthCount)
	elseif data.reason == "level_too_low" then
		rebirthResultLabel.Text = ("레벨이 부족합니다(필요 레벨 %d)"):format(data.requiredLevel or 0)
	elseif data.reason == "max_rebirth" then
		rebirthResultLabel.Text = "이미 최대 환생 회차입니다"
	else
		rebirthResultLabel.Text = "환생 실패: " .. tostring(data.reason)
	end
	updateRebirthInfo()
end)

player:GetAttributeChangedSignal("RebirthCount"):Connect(updateRebirthInfo)
player:GetAttributeChangedSignal("CharacterLevel"):Connect(updateRebirthInfo)

-- ═══ 보석 탭(23-2, PRD 20.37 [2][3][5]/20.38 [2]) ═══

local gemTab = Instance.new("Frame")
gemTab.Size = UDim2.new(1, 0, 1, -28)
gemTab.Position = UDim2.new(0, 0, 0, 28)
gemTab.BackgroundTransparency = 1
gemTab.Visible = false
gemTab.Parent = panel
tabContents["보석"] = gemTab

local gemScroll = Instance.new("ScrollingFrame")
gemScroll.Size = UDim2.new(1, -8, 1, -8)
gemScroll.Position = UDim2.new(0, 4, 0, 4)
gemScroll.BackgroundTransparency = 1
gemScroll.BorderSizePixel = 0
gemScroll.ScrollBarThickness = 4
gemScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
gemScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
gemScroll.Parent = gemTab

local gemListLayout = Instance.new("UIListLayout")
gemListLayout.SortOrder = Enum.SortOrder.LayoutOrder
gemListLayout.Padding = UDim.new(0, 4)
gemListLayout.Parent = gemScroll

local currentGemState = { gems = { false, false, false, false, false }, gemInventory = {}, rerollTickets = { ancient = 0, primordial = 0 } }
local gemRows = {}

for slot = 1, Gem.slotCount do
	local row = Instance.new("Frame")
	row.LayoutOrder = slot
	row.Size = UDim2.new(1, 0, 0, 44)
	row.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
	row.Parent = gemScroll

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -8, 0, 20)
	label.Position = UDim2.new(0, 6, 0, 2)
	label.Font = Enum.Font.Gotham
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = ""
	label.Parent = row

	local equipButton = Instance.new("TextButton")
	equipButton.Size = UDim2.new(0, 80, 0, 18)
	equipButton.Position = UDim2.new(0, 6, 1, -20)
	equipButton.Font = Enum.Font.GothamBold
	equipButton.TextSize = 12
	equipButton.Text = "교체"
	equipButton.BackgroundColor3 = Color3.fromRGB(200, 160, 40)
	equipButton.Parent = row

	local rerollButton = Instance.new("TextButton")
	rerollButton.Size = UDim2.new(0, 80, 0, 18)
	rerollButton.Position = UDim2.new(0, 92, 1, -20)
	rerollButton.Font = Enum.Font.GothamBold
	rerollButton.TextSize = 12
	rerollButton.Text = "리롤"
	rerollButton.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
	rerollButton.Visible = false
	rerollButton.Parent = row

	local buyButton = Instance.new("TextButton")
	buyButton.Size = UDim2.new(0, 110, 0, 18)
	buyButton.Position = UDim2.new(0, 178, 1, -20)
	buyButton.Font = Enum.Font.GothamBold
	buyButton.TextSize = 12
	buyButton.Text = "변환권 구매"
	buyButton.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
	buyButton.Visible = false
	buyButton.Parent = row

	gemRows[slot] = { row = row, label = label, equipButton = equipButton, rerollButton = rerollButton, buyButton = buyButton }

	-- 픽커 UI 없이 인벤토리에서 같은 등급의 첫 번째 보석을 자동으로 고른다(23-2 "임의
	-- 결정" - 같은 등급 보석이 여러 개면 옵션 이름이 달라도 선택창 없이 첫 항목을 쓴다,
	-- 보수적 기본값 원칙).
	equipButton.Activated:Connect(function()
		local gradeId = Gem.gradeForSlot(slot)
		for i, g in ipairs(currentGemState.gemInventory) do
			if g.grade == gradeId then
				gemEquipRequest:FireServer(slot, i)
				break
			end
		end
	end)

	rerollButton.Activated:Connect(function()
		gemRerollRequest:FireServer(slot)
	end)

	buyButton.Activated:Connect(function()
		buyRerollTicketRequest:FireServer(Gem.gradeForSlot(slot))
	end)
end

local function currentStageGoldReward()
	local stage = player:GetAttribute("InfiniteStage") or 1
	return InfiniteStage.getGoldReward(MonsterData.tier1.goldDrop, stage)
end

local function updateGemTab()
	local rebirthCount = player:GetAttribute("RebirthCount") or 0
	for slot = 1, Gem.slotCount do
		local ui = gemRows[slot]
		local gradeId = Gem.gradeForSlot(slot)
		local gradeInfo = ArmorData.grades[gradeId]

		if not Gem.isSlotUnlocked(slot, rebirthCount) then
			ui.label.Text = ("슬롯%d(%s) - 잠김, 환생 %d회 필요"):format(slot, gradeInfo.displayName, slot)
			ui.equipButton.Visible = false
			ui.rerollButton.Visible = false
			ui.buyButton.Visible = false
			continue
		end

		local gem = currentGemState.gems[slot]
		local filled = type(gem) == "table"
		-- 23-3: 옵션이 이제 스탯 축을 갖는다(GemData.optionAxis) - 실제 수치까지 보여준다.
		-- 옵션 풀이 없는 등급(영웅~유물)은 항상 공격력% 하나뿐이고, 고대·태초는 옵션
		-- 미배정(변환권 전) 상태를 "빈 슬롯"과 구분해 보여준다.
		local optionText
		if not filled then
			optionText = "빈 슬롯"
		elseif not Gem.isRerollableGrade(gradeId) then
			optionText = ("공격력 +%.1f%%"):format(Gem.attackPercentBonusForGrade(gradeId) * 100)
		elseif gem.optionId then
			local axis = Gem.optionAxis(gem.optionId)
			local axisName = GemData.axisDisplayNames[axis] or axis
			optionText = ("%s(%s +%.1f%%)"):format(gem.optionId, axisName, Gem.magnitudeForGrade(gradeId, axis) * 100)
		else
			optionText = "옵션 미배정(변환권 필요)"
		end
		ui.label.Text = ("슬롯%d(%s) - %s"):format(slot, gradeInfo.displayName, optionText)

		local matchCount = 0
		for _, g in ipairs(currentGemState.gemInventory) do
			if g.grade == gradeId then
				matchCount += 1
			end
		end
		ui.equipButton.Visible = true
		ui.equipButton.Text = ("교체(%d개 보유)"):format(matchCount)
		ui.equipButton.AutoButtonColor = matchCount > 0
		ui.equipButton.Active = matchCount > 0

		local rerollable = Gem.isRerollableGrade(gradeId)
		ui.rerollButton.Visible = rerollable
		ui.buyButton.Visible = rerollable
		if rerollable then
			local tickets = currentGemState.rerollTickets[gradeId] or 0
			ui.rerollButton.Text = ("리롤(%d장)"):format(tickets)
			ui.rerollButton.AutoButtonColor = filled and tickets > 0
			ui.rerollButton.Active = filled and tickets > 0
			ui.buyButton.Text = ("변환권 구매(%s골드)"):format(NumberFormat.format(currentStageGoldReward() * GemData.rerollTicketGoldMultiplier))
		end
	end
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

player:GetAttributeChangedSignal("RebirthCount"):Connect(updateGemTab)
player:GetAttributeChangedSignal("InfiniteStage"):Connect(updateGemTab)

selectTab("강화")

-- 강화대가 등급을 몰랐던 것(20-1 [2] - "강화대에 현재 무기 등급 표시")을 여기서 연결한다.
-- 등급 자체는 이 화면에서 바꾸지 않는다(환생 전용 축, EnhanceUI는 표시만).
local function gradeDisplayName()
	local grade = player:GetAttribute("WeaponGrade") or 0
	local gradeId = ArmorData.gradeOrder[grade + 1]
	local gradeInfo = gradeId and ArmorData.grades[gradeId]
	return gradeInfo and gradeInfo.displayName or "일반"
end

local function updateInfo()
	local level = player:GetAttribute("WeaponLevel") or 0
	local gold = player:GetAttribute("Gold") or 0
	local cost = Enhance.getCost(level)
	local gradeName = gradeDisplayName()

	if not cost then
		infoLabel.Text = ("%s 등급 · 현재 +%d (최대 강화 단계)"):format(gradeName, level)
		enhanceButton.Text = "최대"
		enhanceButton.AutoButtonColor = false
		return
	end

	local prob = Enhance.getProbability(level)
	enhanceButton.Text = "강화"
	enhanceButton.AutoButtonColor = true
	infoLabel.Text = ("%s 등급 · 현재 +%d\n다음 +%d 성공 확률 %.0f%%\n소모 골드 %s (보유 %s)"):format(
		gradeName, level, level + 1, prob.success * 100, NumberFormat.format(cost), NumberFormat.format(gold))
end

enhanceButton.Activated:Connect(function()
	enhanceRequest:FireServer()
end)

enhanceResult.OnClientEvent:Connect(function(data)
	local level = data.level or (player:GetAttribute("WeaponLevel") or 0)
	local template = RESULT_LABEL[data.result] or data.result
	if template:find("%%d") then
		resultLabel.Text = template:format(level)
	else
		resultLabel.Text = template
	end
	updateInfo()
end)

player:GetAttributeChangedSignal("WeaponLevel"):Connect(updateInfo)
player:GetAttributeChangedSignal("WeaponGrade"):Connect(updateInfo)
player:GetAttributeChangedSignal("Gold"):Connect(updateInfo)

RunService.Heartbeat:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		panel.Visible = false
		return
	end

	local distance = (root.Position - stationPosition).Magnitude
	local wasVisible = panel.Visible
	panel.Visible = distance <= WorldConfig.enhance.interactionRangeStuds
	if panel.Visible and not wasVisible then
		updateInfo()
		updateRebirthInfo()
		updateGemTab()
	end
end)
