-- 가방 칸 비교 툴팁(QUEUE-ALL2 P2 ref 17 ②) - PC = 마우스를 올리면 · 폰 = 길게 누르면(0.45초) 착용 중인 같은 부위와 비교한다. 누르는 조작(선택 · 장착)은 그대로 칸 클릭이 한다(hover에 기대는 조작 없음).
-- create(screenGui) -> { show(anchorGui, item, equipped, classId), hide(), attach(cell, getItem, getEquipped, onShown) }
--   툴팁은 ScreenGui 직계(창 ClipsDescendants에 안 잘린다) · ZIndex 40(글은 41 - ZIndexBehavior Global에서 root 뒤로 숨지 않게) · 자리는 ItemTooltip.placeNear.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local GradeColor = require(game:GetService("ReplicatedStorage").Shared.GradeColor) -- QUEUE-ALL9C 2-2 등급 색 쓰임별(text · border)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local ItemDescribe = require(ReplicatedStorage.Shared.ItemDescribe)
local Text = require(ReplicatedStorage.Shared.Text)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)
local ItemTooltip = require(script.Parent.Parent.Parent.ui.kit.ItemTooltip)
local Compare = require(script.Parent.Compare)

local CompareTip = {}

local WIDTH, PAD, MAX_LINES = 260, 10, 8
local LONG_PRESS = 0.45
local MOVE_CANCEL = 12

function CompareTip.create(screenGui)
	local root = Instance.new("Frame")
	root.Name = "InventoryCompareTip"
	root.ZIndex = 40
	root.Size = UDim2.new(0, WIDTH, 0, 60)
	root.BackgroundColor3 = UIColors.panel
	root.BackgroundTransparency = 0.04
	root.Visible = false
	root.Parent = screenGui
	Theme.corner(root, 10)
	local stroke = Theme.stroke(root, "gold", 0.1)
	stroke.Thickness = 2

	local labels = {}
	for i = 1, MAX_LINES do
		local label = Theme.label(root, "", i == 1 and "body" or "caption", "textPrimary")
		label.Name = "Line" .. i
		label.ZIndex = 41
		label.Font = Enum.Font.GothamBold
		label.TextWrapped = true
		label.TextTruncate = Enum.TextTruncate.None
		label.Visible = false
		labels[i] = label
	end

	local self = {}
	local shownFor

	function self.hide()
		root.Visible = false
		shownFor = nil
	end

	function self.show(anchor, item, equipped, classId)
		if self.blocked and self.blocked() then
			return -- UI-1c 5단계: 고정 창이 열린 동안 마우스 올림 설명 없음
		end
		if not (anchor and item) then
			return
		end
		local described = ItemDescribe.item(item, classId)
		local visual = ItemVisualData.gradeVisuals[item.grade]
		local lines = {
			{ text = Text.get("inv.detail.inBag", { name = described.title }), color = visual and GradeColor.text(item.grade) or UIColors.textPrimary }, -- QUEUE-ALL9C 2-2
			{ text = described.meta, color = UIColors.textSecondary },
			Compare.baseLine(item, equipped),
		}
		for _, line in ipairs(Compare.optionLines(item, equipped, classId, true)) do
			table.insert(lines, line)
		end
		local y = PAD
		for i, label in ipairs(labels) do
			local line = lines[i]
			label.Visible = line ~= nil
			if line then
				label.Text = line.text
				label.TextColor3 = line.color
				local bounds = TextService:GetTextSize(line.text, label.TextSize, label.Font, Vector2.new(WIDTH - PAD * 2, 1000))
				local height = math.max(label.TextSize + 4, bounds.Y + 2)
				label.Position = UDim2.new(0, PAD, 0, y)
				label.Size = UDim2.new(1, -PAD * 2, 0, height)
				y += height + 2
			end
		end
		root.Size = UDim2.new(0, WIDTH, 0, y + PAD - 2)
		ItemTooltip.placeNear(root, { min = anchor.AbsolutePosition, max = anchor.AbsolutePosition + anchor.AbsoluteSize }, screenGui.AbsoluteSize, 8)
		root.Visible = true
		shownFor = anchor
	end

	-- 칸에 붙인다: PC 마우스 올림 / 폰 길게 누름. 길게 누른 뒤의 손 뗌은 탭(선택)으로 치지 않는다 - 반환 함수 consumeTap()이 true면 그 Activated를 무시한다.
	-- getItem() -> item · getEquipped(item) -> 같은 부위 착용품 · classId() · onShown() = 본 것 처리(새 아이템 점)
	function self.attach(cell, getItem, getEquipped, classId, onShown)
		local pressToken = 0
		local pressStart
		local suppressTap = false
		local function open()
			local item = getItem()
			if item then
				self.show(cell, item, getEquipped(item), classId())
				if onShown then
					onShown()
				end
			end
		end
		cell.MouseEnter:Connect(function()
			if Theme.isMobile then
				return
			end
			open()
		end)
		cell.MouseLeave:Connect(function()
			if shownFor == cell then
				self.hide()
			end
		end)
		cell.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			pressToken += 1
			local token = pressToken
			pressStart = input.Position
			task.delay(LONG_PRESS, function()
				if token == pressToken and pressStart then
					suppressTap = true
					open()
				end
			end)
		end)
		cell.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch and pressStart and (input.Position - pressStart).Magnitude > MOVE_CANCEL then
				pressStart = nil -- 끌어서 스크롤하는 중 - 길게 누름이 아니다
				pressToken += 1
			end
		end)
		cell.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				pressStart = nil
				pressToken += 1
				if shownFor == cell then
					self.hide()
				end
			end
		end)
		return function()
			if suppressTap then
				suppressTap = false
				return true
			end
			return false
		end
	end

	return self
end

return CompareTip
