local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GradeColor = require(game:GetService("ReplicatedStorage").Shared.GradeColor) -- QUEUE-ALL9C 2-2 등급 색 쓰임별(text · border)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local SettingsData = require(ReplicatedStorage.Shared.data.SettingsData) -- QUEUE-N1004 A-1 자동 정리 방식 기본값
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Text = require(ReplicatedStorage.Shared.Text)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)
local Toast = require(script.Parent.Parent.Parent.ui.kit.Toast)
local ItemIcons = require(script.Parent.Parent.Parent.ItemIcons) -- 2-2 막힌 등급 칩 자물쇠

-- 일괄판매(S20b: InventoryUI 분할) - 확인 팝업 · 기준 등급 드롭다운. 헤더 버튼(R.bulkSellButton · R.cutoffButton)이 여는 창 안 overlay다.
local BulkSell = {}

function BulkSell.create(S, R)
local player = S.player
local content = R.content
local bulkSellButton, cutoffButton = R.bulkSellButton, R.cutoffButton
local sellRequest = ReplicatedStorage:WaitForChild("SellRequest")
local SettingSave = require(script.Parent.Parent.Parent.ui.SettingSave)
local autoProcessRequest = ReplicatedStorage:WaitForChild("AutoProcessRequest")
local cutoffDropdown, cutoffDropdownDim

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
confirmBox.Size = UDim2.new(0, 340, 0, 200) -- Q13: [분해한다] 버튼 자리만큼 넓힘 · QUEUE-ALL9C 1-10 분해 합계 줄만큼 높임
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
confirmText.TextSize = Theme.textSize("body")
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
confirmHighestLabel.TextSize = Theme.textSize("body")
confirmHighestLabel.TextXAlignment = Enum.TextXAlignment.Left
confirmHighestLabel.Text = ""
confirmHighestLabel.Parent = confirmBox

-- QUEUE-ALL9C 1-10 일괄 분해 합계(값 = 서버와 같은 Loot.isBulkDismantleTarget · dismantleReward · getSellPrice)
local confirmDismantleSum = Instance.new("TextLabel")
confirmDismantleSum.Name = "DismantleSum"
confirmDismantleSum.Position = UDim2.new(0, 16, 0, 106)
confirmDismantleSum.Size = UDim2.new(1, -32, 0, 34)
confirmDismantleSum.BackgroundTransparency = 1
confirmDismantleSum.ZIndex = 21
confirmDismantleSum.Font = Enum.Font.Gotham
confirmDismantleSum.TextSize = Theme.textSize("caption")
confirmDismantleSum.TextWrapped = true
confirmDismantleSum.TextXAlignment = Enum.TextXAlignment.Left
confirmDismantleSum.TextColor3 = UIColors.textSecondary
confirmDismantleSum.Text = ""
confirmDismantleSum.Parent = confirmBox

local confirmYes = Instance.new("TextButton")
confirmYes.AnchorPoint = Vector2.new(1, 1)
confirmYes.Position = UDim2.new(1, -12, 1, -12)
confirmYes.Size = UDim2.new(0, 96, 0, 32)
confirmYes.BackgroundColor3 = UIColors.danger
confirmYes.BackgroundTransparency = 0.55
confirmYes.Text = Text.get("gear.bulk.yes")
confirmYes.Font = Enum.Font.GothamBold
confirmYes.TextSize = Theme.textSize("body")
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
confirmNo.Text = Text.get("gear.bulk.cancel")
confirmNo.Font = Enum.Font.GothamBold
confirmNo.TextSize = Theme.textSize("body")
confirmNo.TextColor3 = UIColors.textPrimary
confirmNo.ZIndex = 21
confirmNo.Parent = confirmBox
local confirmNoCorner = Instance.new("UICorner")
confirmNoCorner.CornerRadius = UDim.new(0, 8)
confirmNoCorner.Parent = confirmNo

-- Q13 등급 선택 일괄 분해(무료) - 같은 기준 등급 · 대상 = Loot.isBulkDismantleTarget(서버와 같은 함수 - 잠금 · 초월 · 태초 · 영웅 미만 제외)
local Loot = require(ReplicatedStorage.Shared.Loot)
local confirmDismantle = Instance.new("TextButton")
confirmDismantle.Name = "DismantleBulkButton"
confirmDismantle.AnchorPoint = Vector2.new(1, 1)
confirmDismantle.Position = UDim2.new(1, -212, 1, -12)
confirmDismantle.Size = UDim2.new(0, 108, 0, 32)
confirmDismantle.BackgroundColor3 = UIColors.panel
confirmDismantle.BackgroundTransparency = UIColors.panelTransparency
confirmDismantle.Font = Enum.Font.GothamBold
confirmDismantle.TextSize = Theme.textSize("body")
confirmDismantle.TextColor3 = UIColors.textPrimary
confirmDismantle.ZIndex = 21
confirmDismantle.Parent = confirmBox
local confirmDismantleCorner = Instance.new("UICorner")
confirmDismantleCorner.CornerRadius = UDim.new(0, 8)
confirmDismantleCorner.Parent = confirmDismantle
local function dismantleCount()
	local n = 0
	local top = S.sellCheckedTop()
	local byGrade, gold = {}, 0
	for _, item in ipairs(S.inventory) do
		if top and Loot.isBulkDismantleTarget(item, top) then
			n += 1
			local gem = Loot.dismantleReward(item) -- QUEUE-ALL9C 1-10 서버가 넣는 보석과 같은 표
			byGrade[gem.grade] = (byGrade[gem.grade] or 0) + 1
			gold += Loot.getSellPrice(item)
		end
	end
	return n, byGrade, gold
end
local pendingDismantleCount = 0 -- SEC-FIX-1 7: 확인 창이 보여 준 분해 개수(누른 순간 다시 세지 않는다 - 판매 pendingCount와 같은 이유)
confirmDismantle.Activated:Connect(function()
	confirmOverlay.Visible = false
	if pendingDismantleCount > 0 then
		sellRequest:FireServer("dismantleBulk", S.sellCheckedTop(), pendingDismantleCount) -- QUEUE-ALL8 G1: 기준 = 체크한 가장 높은 등급 · SEC-FIX-1 7: + 보여 준 개수(서버가 다시 세서 다르면 안 함)
	end
	pendingDismantleCount = 0
end)

confirmNo.Activated:Connect(function()
	confirmOverlay.Visible = false
end)
confirmOverlay.Activated:Connect(function()
	confirmOverlay.Visible = false
end)

-- QUEUE-ALL8 F 리뷰: 확인 창에 "보여 준" 개수 · 등급을 잡아 둔다(누른 순간 다시 세면 창이 떠 있는 동안 주운 장비까지 팔렸다)
local pendingKey, pendingCount = nil, 0
confirmYes.Activated:Connect(function()
	confirmOverlay.Visible = false
	if pendingKey and pendingCount > 0 then -- QUEUE-ALL8 G1: 체크한 등급 + 확인 창 개수(서버가 다시 세서 다르면 안 판다)
		sellRequest:FireServer("sellGrades", pendingKey, pendingCount)
	end
	pendingKey, pendingCount = nil, 0
end)

local function openConfirm()
	local count, total, highestSoldGradeId = S.bulkSellEstimate()
	if count == 0 then
		return
	end
	pendingKey, pendingCount = S.sellCheckedKey(), count
	confirmText.Text = Text.get("gear.bulk.confirm", { count = ("%d"):format(count), gold = NumberFormat.currency(total, Text.languageFor()) })
	local nd, byGrade, dismantleGold = dismantleCount()
	pendingDismantleCount = nd
	confirmDismantle.Text = Text.get("gear.bulk.dismantle", { count = ("%d"):format(nd) }) -- Q13: 영웅 이상만 보석으로(태초 · 초월 제외)
	local parts = {}
	for _, id in ipairs(ArmorData.gradeOrder) do
		if byGrade[id] then
			table.insert(parts, ("%s %d"):format(ArmorData.grades[id].displayName, byGrade[id]))
		end
	end
	confirmDismantleSum.Text = nd > 0 and Text.get("gear.reward.bulk", { count = ("%d"):format(nd), grades = table.concat(parts, " · "), gold = NumberFormat.currency(dismantleGold, Text.languageFor()) }) or ""
	confirmDismantle.AutoButtonColor = nd > 0
	confirmDismantle.TextTransparency = nd > 0 and 0 or 0.5
	local visual = highestSoldGradeId and ItemVisualData.gradeVisuals[highestSoldGradeId]
	confirmHighestDot.BackgroundColor3 = visual and GradeColor.border(highestSoldGradeId) or UIColors.textTertiary -- QUEUE-ALL9C 2-2
	confirmHighestLabel.TextColor3 = visual and GradeColor.text(highestSoldGradeId) or UIColors.textTertiary
	confirmHighestLabel.Text = highestSoldGradeId
		and Text.get("gear.bulk.highest", { grade = ArmorData.grades[highestSoldGradeId].displayName })
		or ""
	confirmOverlay.Visible = true
end
bulkSellButton.Activated:Connect(function()
	if not R.openSalvageV2 then -- 03 v2 = 등급 골라 분해 창(아래)
		openConfirm()
	end
end)

-- QUEUE-ALL9A 2-2: 서버가 개수가 달라 거부하면(확인 창이 떠 있는 동안 가방이 바뀜) 안내 + 새 개수로 확인 창 다시
sellRequest.OnClientEvent:Connect(function(action, ok, why)
	if (action == "sellGrades" or action == "dismantleBulk") and not ok and why == "count_mismatch" then -- SEC-FIX-1 7: 분해도 같은 안내
		Toast.push("TC", { text = Text.get("gear.bulk.changed"), grade = "notice", seconds = 4 })
		;(R.openSalvageV2 or openConfirm)()
	end
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
cutoffDropdown.Size = UDim2.new(0, 230, 0, 0) -- G1-2: 자동 처리 줄("자동 처리: 영웅 이하")이 들어가게 130 → 170 · ALL8 G1: 제외 안내 한 줄이 두 줄로 접혀 들어가게 230
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
	S.bulkSellDropdownOpen = false
	cutoffDropdown.Visible = false
	cutoffDropdownDim.Visible = false
end

-- 등급 목록에 색 점을 찍는다(지시 - "텍스트만으로는 서열이 안 읽힌다"). QUEUE-ALL8 G1: 목록 = ArmorData.bulkSellGrades(전설 이상은 줄 자체가 없다).
local dropdownRows = {}
local checkBoxes = {} -- [gradeId] = { box, mark } - 그린 체크 상자(글자 기호는 폰트에서 너무 작게 나왔다)
local function refreshChecks()
	for id, c in pairs(checkBoxes) do
		local on = S.bulkSellChecked[id] == true
		c.box.BackgroundTransparency = on and 0 or 1
		c.mark.Visible = on
	end
end
for order, gradeId in ipairs(ArmorData.bulkSellGrades) do -- QUEUE-ALL8 G1: 체크 목록(전설 이상은 줄 자체가 없다)
	local row = Instance.new("TextButton")
	row.LayoutOrder = order
	row.Text = ""
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 28)
	row.ZIndex = 25
	row.Parent = cutoffDropdown
	table.insert(dropdownRows, row)

	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0, 0.5)
	dot.Position = UDim2.new(0, 10, 0.5, 0)
	dot.Size = UDim2.new(0, 8, 0, 8)
	dot.BackgroundColor3 = GradeColor.border(gradeId) -- QUEUE-ALL9C 2-2
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
	label.TextSize = Theme.textSize("body")
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = UIColors.textPrimary
	label.Text = ArmorData.grades[gradeId].displayName
	label.Parent = row
	label.Position = UDim2.new(0, 50, 0.5, 0)
	label.Size = UDim2.new(1, -58, 1, 0)
	local box = Instance.new("Frame") -- 체크 상자(점 오른쪽)
	box.Name = "CheckBox"
	box.AnchorPoint = Vector2.new(0, 0.5)
	box.Position = UDim2.new(0, 24, 0.5, 0)
	box.Size = UDim2.fromOffset(18, 18)
	box.BackgroundColor3 = UIColors.gold
	box.ZIndex = 25
	box.Parent = row
	Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)
	local boxStroke = Instance.new("UIStroke")
	boxStroke.Color = UIColors.textPrimary
	boxStroke.Thickness = 2
	boxStroke.Parent = box
	local mark = Instance.new("TextLabel")
	mark.BackgroundTransparency = 1
	mark.Size = UDim2.fromScale(1, 1)
	mark.Font = Enum.Font.GothamBlack
	mark.TextSize = 14
	mark.TextColor3 = UIColors.panel
	mark.Text = "V"
	mark.ZIndex = 26
	mark.Parent = box
	checkBoxes[gradeId] = { box = box, mark = mark }

	row.Activated:Connect(function() -- 누를 때마다 체크 켬/끔(하나는 늘 남긴다) · 드롭다운은 열린 채
		local was = S.bulkSellChecked[gradeId]
		S.bulkSellChecked[gradeId] = not was or nil
		if S.sellCheckedKey() == "" then
			S.bulkSellChecked[gradeId] = true
		end
		SettingSave("bulkSellGrades", S.sellCheckedKey())
		refreshChecks()
		S.rebuildGrid()
	end)
end
refreshChecks()
-- 안내 한 줄(누를 수 없음): 전설 이상 · 잠긴 · 착용 중 장비는 팔리지 않는다
local noteRow = Instance.new("TextLabel")
noteRow.Name = "BulkSellNote"
noteRow.LayoutOrder = #ArmorData.bulkSellGrades + 5
noteRow.BackgroundTransparency = 1
noteRow.Size = UDim2.new(1, -20, 0, 34)
noteRow.Position = UDim2.fromOffset(10, 0)
noteRow.TextXAlignment = Enum.TextXAlignment.Left
noteRow.TextWrapped = true
noteRow.ZIndex = 25
noteRow.Font = Enum.Font.Gotham
noteRow.TextSize = Theme.textSize("caption")
noteRow.TextColor3 = UIColors.textSecondary
noteRow.Text = Text.get("gear.bulk.excludeNote")
noteRow.Parent = cutoffDropdown

-- G1-2: 줍는 순간 자동 처리 토글 - 드롭다운 맨 아래 한 줄. 누를 때마다 끔 → 영웅 이하 → 희귀 이하 → 일반 이하 → 끔(서버가 값 검사 · Attribute AutoProcess로 되돌려 준다).
-- 기준 이하 · 잠기지 않은 장비: 영웅은 분해(보석), 일반 · 희귀는 판매(골드). 문구는 TextData.
local autoRow = Instance.new("TextButton")
autoRow.Name = "AutoProcessRow"
autoRow.LayoutOrder = #ArmorData.bulkSellGrades + 10
autoRow.BackgroundTransparency = 1
autoRow.Size = UDim2.new(1, 0, 0, 28)
autoRow.ZIndex = 25
autoRow.Font = Enum.Font.GothamBold
autoRow.TextSize = Theme.textSize("body")
autoRow.TextColor3 = UIColors.textSecondary
autoRow.Parent = cutoffDropdown
table.insert(dropdownRows, autoRow)
local function refreshAutoRow()
	local value = player:GetAttribute("AutoProcess") or "off"
	local grade = ArmorData.grades[value]
	autoRow.Text = grade and Text.get("bag.autoProcess.on", { grade = grade.displayName }) or Text.get("bag.autoProcess.off")
	autoRow.TextColor3 = grade and UIColors.textPrimary or UIColors.textSecondary
end
refreshAutoRow()
player:GetAttributeChangedSignal("AutoProcess"):Connect(refreshAutoRow)
autoRow.Activated:Connect(function()
	-- QUEUE-N1004 A-1: 끔 → 일반 이하(기본) → 희귀 이하 → 영웅 이하 → 끔(목록은 높은 등급부터라 거꾸로 돈다)
	local choices = ArmorData.autoProcessGradeChoices
	local current = player:GetAttribute("AutoProcess") or "off"
	local index = table.find(choices, current)
	if index == nil then
		autoProcessRequest:FireServer(true, choices[#choices])
	elseif index > 1 then
		autoProcessRequest:FireServer(true, choices[index - 1])
	else
		autoProcessRequest:FireServer(false, choices[#choices])
	end
end)
-- QUEUE-N1004 A-1 자동 정리 방식 한 줄(판매 ↔ 분해 · 설정 autoProcessMode - 설정 창 [게임]과 같은 값)
local modeRow = Instance.new("TextButton")
modeRow.Name = "AutoProcessModeRow"
modeRow.LayoutOrder = #ArmorData.bulkSellGrades + 11
modeRow.BackgroundTransparency = 1
modeRow.Size = UDim2.new(1, 0, 0, 28)
modeRow.ZIndex = 25
modeRow.Font = Enum.Font.Gotham
modeRow.TextSize = Theme.textSize("caption")
modeRow.TextColor3 = UIColors.textSecondary
modeRow.TextWrapped = true
modeRow.Parent = cutoffDropdown
table.insert(dropdownRows, modeRow)
local function autoMode()
	return player:GetAttribute("AutoProcessMode") or SettingsData.keys.autoProcessMode.default
end
local function refreshModeRow()
	modeRow.Text = Text.get("autoTidy.modeRow." .. autoMode())
end
refreshModeRow()
player:GetAttributeChangedSignal("AutoProcessMode"):Connect(refreshModeRow)
modeRow.Activated:Connect(function()
	local nextMode = autoMode() == "sell" and "dismantle" or "sell"
	SettingSave("autoProcessMode", nextMode)
end)

cutoffButton.Activated:Connect(function()
	S.bulkSellDropdownOpen = not S.bulkSellDropdownOpen
	cutoffDropdown.Visible = S.bulkSellDropdownOpen
	cutoffDropdownDim.Visible = S.bulkSellDropdownOpen
end)

cutoffDropdownDim.Activated:Connect(closeCutoffDropdown)

-- 재접속 등으로 서버 값이 늦게 도착해도(로드 중엔 목록의 가장 낮은 등급으로 임시 시작했다)
-- 실제 저장된 기준으로 맞춰준다 - ClassId 등 다른 Attribute와 같은 패턴.
player:GetAttributeChangedSignal("BulkSellGrades"):Connect(function() -- QUEUE-ALL8 G1: 저장된 체크(접속 뒤 늦게 도착)
	S.bulkSellChecked = S.parseSellChecked(player:GetAttribute("BulkSellGrades"))
	refreshChecks()
	if S.isOpen then
		S.rebuildGrid()
	end
end)

-- ═══ QUEUE-UI2 UI2-5 2차 2-2: 등급 골라 분해(03 v2) - PC = 가운데 창 640 × 480 · 폰 = 아래에서 올라오는 시트(가로 꽉 · 232) ═══
--   헤더의 [판매 등급 ▾] · [일괄 판매] 두 버튼 → [등급 골라 분해] 하나(같은 창에서 등급 고르기 · 판매 · 분해 · 자동 정리).
--   게임 규칙 그대로: 고를 수 있는 등급 = ArmorData.bulkSellGrades(일반 · 희귀 · 영웅) · 전설 이상 = 막힘(하나씩) · 판매 = 고른 등급 전부(골드) · 분해 = 그중 영웅 이상(Loot.isBulkDismantleTarget - 보석).
--   [취소] = 기본(왼쪽) · [N개 분해] = 빨강(오른쪽 - 확인 창 안 위험 버튼 규칙) · [N개 판매] = 보조. 창 자체가 확인 단계(누르는 순간 보인 개수로 요청 - 서버가 다시 세서 다르면 거절 → 창 다시).
if require(script.Parent.Layout).lookV2 then
	local UiKit = require(script.Parent.Parent.Parent.ui.v2.UiKit)
	local UiTokens = require(ReplicatedStorage.Shared.data.UiTokens)
	local SHEET = require(ReplicatedStorage.Shared.data.UiLayoutData).bag.salvage
	local function tok(name)
		return Color3.fromHex(UiTokens.colors[name])
	end
	local Z = 30
	cutoffButton.Visible = false -- 등급 고르기 = 창 안
	bulkSellButton.Text = Text.get("gear.bulk.v2.button")

	local dimV2 = Instance.new("TextButton")
	dimV2.Name = "SalvageDim"
	dimV2.Text = ""
	dimV2.AutoButtonColor = false
	dimV2.Size = UDim2.fromScale(1, 1)
	dimV2.BackgroundColor3 = Color3.new(0, 0, 0)
	dimV2.BackgroundTransparency = UiTokens.dimTransparency
	dimV2.Visible = false
	dimV2.ZIndex = Z
	dimV2.Parent = content

	local box = Instance.new("Frame")
	box.Name = "SalvageByGrade"
	box.BackgroundColor3 = tok("panel.window")
	box.ZIndex = Z + 1
	box.Parent = dimV2
	Instance.new("UICorner", box).CornerRadius = UDim.new(0, UiTokens.corner.window)
	local boxStroke = Instance.new("UIStroke")
	boxStroke.Color = tok("line")
	boxStroke.Thickness = UiTokens.stroke.window
	boxStroke.Parent = box
	local sinkBox = Instance.new("TextButton") -- 창 안 클릭이 딤(닫기)으로 새지 않게
	sinkBox.Text = ""
	sinkBox.AutoButtonColor = false
	sinkBox.BackgroundTransparency = 1
	sinkBox.Size = UDim2.fromScale(1, 1)
	sinkBox.ZIndex = Z + 1
	sinkBox.Parent = box

	local function label(parent, text, size, color, z)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.GothamBold
		l.TextSize = Theme.textSize(size)
		l.TextColor3 = color
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextWrapped = true
		l.Text = text
		l.ZIndex = z or Z + 2
		l.Parent = parent
		return l
	end
	local title = label(box, Text.get("gear.bulk.v2.title"), "title", tok("text.primary"))
	title.Name = "Title"
	local sub = label(box, Text.get("gear.bulk.v2.sub"), "caption", tok("text.secondary"))
	sub.Name = "Sub"
	sub.Font = Enum.Font.Gotham

	-- 등급 칩(고를 수 있음 = 체크 · 막힘 = 회색 + 자물쇠 + "하나씩")
	local chips = {}
	local chipOrder = {}
	for i = 1, SHEET.chipGrades do
		table.insert(chipOrder, ArmorData.gradeOrder[i])
	end
	for _, gradeId in ipairs(chipOrder) do
		local selectable = table.find(ArmorData.bulkSellGrades, gradeId) ~= nil
		local chip = Instance.new("TextButton")
		chip.Name = "Chip_" .. gradeId
		chip.Text = ""
		chip.AutoButtonColor = false
		chip.ZIndex = Z + 2
		chip.Parent = box
		local skin = UiKit.skin(chip, "sec", { state = selectable and "normal" or "disabled" })
		local dot = Instance.new("Frame")
		dot.Name = "GradeDot"
		dot.AnchorPoint = Vector2.new(0, 0.5)
		dot.Position = UDim2.new(0, 14, 0.5, -2)
		dot.Size = UDim2.fromOffset(12, 12)
		dot.BackgroundColor3 = GradeColor.border(gradeId)
		dot.BackgroundTransparency = selectable and 0 or 0.5
		dot.ZIndex = chip.ZIndex + 1
		dot.Parent = chip
		Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
		local name = label(chip, ArmorData.grades[gradeId].displayName, "body", selectable and tok("text.primary") or tok("text.muted"), chip.ZIndex + 1)
		name.Position = UDim2.new(0, 34, 0, 0)
		name.Size = UDim2.new(1, -70, 1, -4)
		name.TextYAlignment = Enum.TextYAlignment.Center
		name.TextWrapped = false
		local mark = Instance.new("Frame") -- 오른쪽: 체크(고를 수 있음) · 자물쇠(막힘)
		mark.Name = "Mark"
		mark.AnchorPoint = Vector2.new(1, 0.5)
		mark.Position = UDim2.new(1, -12, 0.5, -2)
		mark.Size = UDim2.fromOffset(22, 22)
		mark.BackgroundColor3 = tok("accent")
		mark.ZIndex = chip.ZIndex + 1
		mark.Parent = chip
		Instance.new("UICorner", mark).CornerRadius = UDim.new(0, 6)
		local markStroke = Instance.new("UIStroke")
		markStroke.Color = tok("text.secondary")
		markStroke.Thickness = 2
		markStroke.Parent = mark
		local tick = label(mark, "V", "caption", tok("accent.text"), chip.ZIndex + 2)
		tick.Font = Enum.Font.GothamBlack
		tick.Size = UDim2.fromScale(1, 1)
		tick.TextXAlignment = Enum.TextXAlignment.Center
		if not selectable then
			mark.BackgroundTransparency = 1
			markStroke.Enabled = false
			tick.Visible = false
			ItemIcons.lock(mark, 18, tok("text.muted"))
			for _, d in ipairs(mark:GetDescendants()) do
				if d:IsA("GuiObject") then
					d.ZIndex = chip.ZIndex + 2
				end
			end
			chip:SetAttribute("Blocked", Text.get("gear.bulk.v2.oneByOne"))
		end
		chips[gradeId] = { button = chip, selectable = selectable, mark = mark, tick = tick, skin = skin, name = name }
	end

	local summary = label(box, "", "body", tok("text.secondary"))
	summary.Name = "Summary"
	summary.Font = Enum.Font.Gotham
	summary.TextYAlignment = Enum.TextYAlignment.Top

	local function action(name, kind, textToken)
		local b = Instance.new("TextButton")
		b.Name = name
		b.AutoButtonColor = false
		b.Font = Enum.Font.GothamBold
		b.TextSize = Theme.textSize("header")
		b.TextColor3 = tok(textToken or "text.primary")
		b.ZIndex = Z + 2
		b.Parent = box
		if not UiKit.skin(b, kind) then
			b.BackgroundColor3 = kind == "danger" and tok("warning") or tok("panel.slot")
			Instance.new("UICorner", b).CornerRadius = UDim.new(0, UiTokens.corner.button)
		end
		return b
	end
	local cancelV2 = action("Cancel", "sec")
	cancelV2.Text = Text.get("gear.bulk.cancel")
	local sellV2 = action("Sell", "sec")
	local dismantleV2 = action("Dismantle", "danger")

	-- 자동 정리 두 줄(줍는 순간 · 판매/분해 방식)은 옛 드롭다운에서 이 창 아래로 옮긴다(같은 버튼 · 같은 연결)
	local autoBox = Instance.new("Frame")
	autoBox.Name = "AutoRows"
	autoBox.BackgroundTransparency = 1
	autoBox.ZIndex = Z + 2
	autoBox.Parent = box
	local autoList = Instance.new("UIListLayout")
	autoList.FillDirection = Enum.FillDirection.Horizontal
	autoList.Padding = UDim.new(0, 12)
	autoList.SortOrder = Enum.SortOrder.LayoutOrder
	autoList.Parent = autoBox
	for _, row in ipairs({ autoRow, modeRow }) do
		row.Parent = autoBox
		row.ZIndex = Z + 2
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = tok("info")
	end
	noteRow.Visible = false -- 안내 = 창 부제(sub)

	local shown = { sell = 0, key = "", dismantle = 0 }
	local function refreshV2()
		for gradeId, c in pairs(chips) do
			if c.selectable then
				local on = S.bulkSellChecked[gradeId] == true
				c.mark.BackgroundTransparency = on and 0 or 1
				c.tick.Visible = on
				if c.skin then -- 고름 = 노랑(tab-on) + 진한 글자
					c.skin.Image = UiKit.stateImage(on and "tab-on" or "sec", "normal") or c.skin.Image
					c.name.TextColor3 = on and tok("accent.text") or tok("text.primary")
				end
			end
		end
		local count, total = S.bulkSellEstimate()
		local nd, byGrade = dismantleCount()
		local parts = {}
		for _, id in ipairs(ArmorData.gradeOrder) do
			if byGrade[id] then
				table.insert(parts, ("%s %d"):format(ArmorData.grades[id].displayName, byGrade[id]))
			end
		end
		local lines = {}
		if count > 0 then
			table.insert(lines, Text.get("gear.bulk.v2.sellLine", { count = ("%d"):format(count), gold = NumberFormat.currency(total, Text.languageFor()) }))
		end
		if nd > 0 then
			table.insert(lines, Text.get("gear.bulk.v2.dismantleLine", { count = ("%d"):format(nd), grades = table.concat(parts, " · ") }))
		end
		summary.Text = #lines > 0 and table.concat(lines, "\n") or Text.get("gear.bulk.v2.none")
		shown.sell, shown.key, shown.dismantle = count, S.sellCheckedKey(), nd
		sellV2.Text = Text.get("gear.bulk.v2.sell", { count = ("%d"):format(count) })
		dismantleV2.Text = Text.get("gear.bulk.v2.dismantle", { count = ("%d"):format(nd) })
		for _, pair in ipairs({ { sellV2, "sec", count > 0 }, { dismantleV2, "danger", nd > 0 } }) do -- 0개 = 비활성 그림 + 흐린 글자
			local b, kind, on = pair[1], pair[2], pair[3]
			local skin = b:FindFirstChild("Skin")
			if skin then
				skin.Image = UiKit.stateImage(kind, on and "normal" or "disabled") or skin.Image
			end
			b.TextColor3 = tok(on and "text.primary" or "text.muted")
		end
	end

	-- 배치: PC = 가운데 창 · 폰 = 아래 시트(칩 한 줄 6 · 버튼 두 칸)
	local function placeV2()
		local L = R.layout
		local phone = L and L.mode == "phone"
		local P = phone and SHEET.phone or SHEET.pc
		local winW, winH = R.win.AbsoluteSize.X, R.win.AbsoluteSize.Y
		local w, h = math.min(P.w, winW - 16), math.min(P.h, winH - 16)
		box.AnchorPoint = phone and Vector2.new(0.5, 1) or Vector2.new(0.5, 0.5)
		box.Position = phone and UDim2.new(0.5, 0, 1, 0) or UDim2.fromScale(0.5, 0.5)
		box.Size = UDim2.fromOffset(phone and winW or w, h)
		local pad = P.pad
		local innerW = (phone and winW or w) - 2 * pad
		title.Position = UDim2.fromOffset(pad, P.titleY)
		title.Size = UDim2.new(1, -2 * pad, 0, P.titleH)
		sub.Position = UDim2.fromOffset(pad, P.titleY + P.titleH)
		sub.Size = UDim2.new(1, -2 * pad, 0, P.subH)
		sub.Visible = P.subH > 0
		local cols = P.chipCols
		local cw = math.floor((innerW - (cols - 1) * P.chipGap) / cols)
		for i, gradeId in ipairs(chipOrder) do
			local c = chips[gradeId].button
			local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
			c.Position = UDim2.fromOffset(pad + col * (cw + P.chipGap), P.chipY + row * (P.chipH + P.chipGap))
			c.Size = UDim2.fromOffset(cw, P.chipH)
		end
		local rows = math.ceil(#chipOrder / cols)
		local afterChips = P.chipY + rows * (P.chipH + P.chipGap)
		summary.Position = UDim2.fromOffset(pad, afterChips + 4)
		summary.Size = UDim2.new(1, -2 * pad, 0, P.summaryH)
		autoBox.Position = UDim2.fromOffset(pad, afterChips + 4 + P.summaryH)
		autoBox.Size = UDim2.new(1, -2 * pad, 0, P.autoH)
		autoBox.Visible = P.autoH > 0
		for _, row in ipairs({ autoRow, modeRow }) do
			row.Size = UDim2.new(0.5, -6, 0, P.autoH)
		end
		local by = h - pad - P.buttonH
		local bw = math.floor((innerW - 2 * P.buttonGap) / 3)
		cancelV2.Position = UDim2.fromOffset(pad, by)
		sellV2.Position = UDim2.fromOffset(pad + bw + P.buttonGap, by)
		dismantleV2.Position = UDim2.fromOffset(pad + 2 * (bw + P.buttonGap), by)
		for _, b in ipairs({ cancelV2, sellV2, dismantleV2 }) do
			b.Size = UDim2.fromOffset(bw, P.buttonH)
		end
	end

	local function openV2()
		closeCutoffDropdown()
		confirmOverlay.Visible = false
		placeV2()
		refreshV2()
		dimV2.Visible = true
	end
	local function closeV2()
		dimV2.Visible = false
	end
	R.openSalvageV2 = openV2
	R.salvageV2 = box
	bulkSellButton.Activated:Connect(function()
		openV2()
	end)
	dimV2.Activated:Connect(closeV2)
	cancelV2.Activated:Connect(closeV2)
	for gradeId, c in pairs(chips) do
		c.button.Activated:Connect(function()
			if not c.selectable then
				return -- 전설 이상 = 하나씩(막힘)
			end
			local was = S.bulkSellChecked[gradeId]
			S.bulkSellChecked[gradeId] = not was or nil
			if S.sellCheckedKey() == "" then
				S.bulkSellChecked[gradeId] = true
			end
			SettingSave("bulkSellGrades", S.sellCheckedKey())
			refreshChecks()
			S.rebuildGrid()
			refreshV2()
		end)
	end
	sellV2.Activated:Connect(function()
		if shown.sell > 0 then
			closeV2()
			sellRequest:FireServer("sellGrades", shown.key, shown.sell)
		end
	end)
	dismantleV2.Activated:Connect(function()
		if shown.dismantle > 0 then
			closeV2()
			sellRequest:FireServer("dismantleBulk", S.sellCheckedTop(), shown.dismantle) -- SEC-FIX-1 7: 보여 준 개수
		end
	end)
	player:GetAttributeChangedSignal("BulkSellGrades"):Connect(function()
		if dimV2.Visible then
			refreshV2()
		end
	end)
end

R.cutoffDropdown, R.cutoffDropdownDim = cutoffDropdown, cutoffDropdownDim

-- 배치(S20b): 폰은 버튼 · 드롭다운 행이 터치 44 이상이다(PC는 원래 값).
table.insert(R.layouts, function(L)
	local phone = L.mode == "phone"
	confirmYes.Size = UDim2.new(0, 96, 0, phone and 44 or 32)
	confirmNo.Size = UDim2.new(0, 88, 0, phone and 44 or 32)
	for _, row in ipairs(dropdownRows) do
		row.Size = UDim2.new(1, 0, 0, phone and 44 or 28)
	end
end)
end

return BulkSell
