local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)

-- 일괄판매(S20b: InventoryUI 분할) - 확인 팝업 · 기준 등급 드롭다운. 헤더 버튼(R.bulkSellButton · R.cutoffButton)이 여는 창 안 overlay다.
local BulkSell = {}

function BulkSell.create(S, R)
local player = S.player
local content = R.content
local bulkSellButton, cutoffButton = R.bulkSellButton, R.cutoffButton
local sellRequest = ReplicatedStorage:WaitForChild("SellRequest")
local bulkSellCutoffRequest = ReplicatedStorage:WaitForChild("BulkSellCutoffRequest")
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

local confirmYes = Instance.new("TextButton")
confirmYes.AnchorPoint = Vector2.new(1, 1)
confirmYes.Position = UDim2.new(1, -12, 1, -12)
confirmYes.Size = UDim2.new(0, 96, 0, 32)
confirmYes.BackgroundColor3 = UIColors.danger
confirmYes.BackgroundTransparency = 0.55
confirmYes.Text = "판매한다"
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
confirmNo.Text = "취소"
confirmNo.Font = Enum.Font.GothamBold
confirmNo.TextSize = Theme.textSize("body")
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
	sellRequest:FireServer("sellBulk", S.bulkSellCutoffGrade)
end)

bulkSellButton.Activated:Connect(function()
	local count, total, highestSoldGradeId = S.bulkSellEstimate()
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
	S.bulkSellDropdownOpen = false
	cutoffDropdown.Visible = false
	cutoffDropdownDim.Visible = false
end

-- 등급 목록에 색 점을 찍는다(지시 - "텍스트만으로는 서열이 안 읽힌다"). BULK_SELL_GRADE_CHOICES가
-- 이미 bulkSellMaxGrade까지만 잘라낸 목록이라 유물 이상은 여기 나타날 수가 없다.
local dropdownRows = {}
for order, gradeId in ipairs(S.BULK_SELL_GRADE_CHOICES) do
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
	label.TextSize = Theme.textSize("body")
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = UIColors.textPrimary
	label.Text = ArmorData.grades[gradeId].displayName .. " 이하"
	label.Parent = row

	row.Activated:Connect(function()
		S.bulkSellCutoffGrade = gradeId
		bulkSellCutoffRequest:FireServer(gradeId)
		closeCutoffDropdown()
		S.rebuildGrid()
	end)
end

cutoffButton.Activated:Connect(function()
	S.bulkSellDropdownOpen = not S.bulkSellDropdownOpen
	cutoffDropdown.Visible = S.bulkSellDropdownOpen
	cutoffDropdownDim.Visible = S.bulkSellDropdownOpen
end)

cutoffDropdownDim.Activated:Connect(closeCutoffDropdown)

-- 재접속 등으로 서버 값이 늦게 도착해도(로드 중엔 목록의 가장 낮은 등급으로 임시 시작했다)
-- 실제 저장된 기준으로 맞춰준다 - ClassId 등 다른 Attribute와 같은 패턴.
player:GetAttributeChangedSignal("BulkSellCutoffGrade"):Connect(function()
	local grade = player:GetAttribute("BulkSellCutoffGrade")
	if grade and grade ~= S.bulkSellCutoffGrade then
		S.bulkSellCutoffGrade = grade
		if S.isOpen then
			S.rebuildGrid()
		end
	end
end)

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
