-- 보석 탭 "홈 상세" 행 5개. S20c: GemTab.lua(800줄 한도)에서 잘라 옮겼다. S20e: 변환권 구매 버튼은 보석상인의 "보석 공방"으로 옮겼고 [리롤]은 진입점(누르면 "보석상인에게서 가능" 토스트)으로만 남았다.
-- GemSlotRows.create(parent, hooks) -> { scroll, rows = { [slot] = { row, label, rerollButton } } }
--   hooks.onReroll(slot) = [리롤]을 누를 때(GemTab이 안내 토스트를 띄운다). 행 자체의 입력(더블클릭 · 우클릭 · 탭)은 GemTab이 rows[slot].row에 붙인다.
--   자리 · 크기(scroll · 행 높이 · 버튼 높이)는 GemTab의 배치 함수가 정한다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local Gem = require(ReplicatedStorage.Shared.Gem)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)

local GemSlotRows = {}

function GemSlotRows.create(parent, hooks)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Position = UDim2.new(0, 14, 0, 26)
	scroll.Size = UDim2.new(1, -28, 0, 216)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = scroll

	local rows = {}
	for slot = 1, Gem.slotCount do
		-- 26-3(PRD 20.67 [12] "클릭하면 하단 Detail이 그 보석을 게이지와 함께 보여준다") - Frame이 아니라 TextButton으로 만들어 행 전체를 클릭 대상으로 삼는다.
		-- 안쪽 리롤·변환권 버튼은 그대로 자기 Activated를 먼저 받는다(자식이 부모보다 우선 - 로블록스 기본 동작).
		local row = Instance.new("TextButton")
		row.Name = "SlotRow" .. slot
		row.Text = ""
		row.AutoButtonColor = false
		row.LayoutOrder = slot
		row.Size = UDim2.new(1, 0, 0, 42)
		row.BackgroundColor3 = UIColors.slot
		row.BackgroundTransparency = UIColors.slotTransparency
		row.Parent = scroll
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

		rows[slot] = { row = row, label = label, rerollButton = rerollButton }

		rerollButton.Activated:Connect(function()
			hooks.onReroll(slot)
		end)
	end

	return { scroll = scroll, rows = rows }
end

return GemSlotRows
