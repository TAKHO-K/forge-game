-- 보석 탭 보유 보석 칸(S20c: GemTab.lua(800줄 한도)에서 분리 + 표시 3종 추가). 서버 index(= gemInventory 순서)는 셀마다 들고 다니고, 표시 순서(등급 높은 순)만 LayoutOrder로 정한다.
-- GemBag.create(parent, deps) -> { scroll, refs, rebuild(gemInventory, order, hooks), paint(viewOf), center(index) }
--   deps.applyGradeVisual(cell, stroke, glow, gradeId)
--   rebuild: 셀을 전부 다시 만든다. hooks.onInput(input, index, gem, cell) = 셀의 InputBegan · hooks.onActivated(index) = 셀의 Activated(탭). 입력 해석(더블클릭 · 드래그 · 탭)은 GemTab이 한다.
--   paint(viewOf): viewOf(index) -> mark("ok" 끼울 수 있다 / "blocked" 못 끼운다 / nil), selected(선택), isNew(분해로 새로 들어온 보석)
--   표시 3종: 링(선택 = 강조색 · 끼울 수 있음 = 성공색) · 어둡게(끼울 수 없음) · NEW 표시. refs[index] = { cell, ring, ringStroke, dimmer, newBadge }

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)

local GemBag = {}

function GemBag.create(parent, deps)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Position = UDim2.new(0, 14, 0, 270)
	scroll.Size = UDim2.new(1, -28, 1, -280)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = parent

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0, 64, 0, 64)
	grid.CellPadding = UDim2.new(0, 6, 0, 6)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll

	local self = { scroll = scroll, refs = {} }
	local cells = {}

	local function corner(inst, radius)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, radius)
		c.Parent = inst
	end

	function self.rebuild(gemInventory, order, hooks)
		for _, cell in ipairs(cells) do
			cell:Destroy()
		end
		cells = {}
		self.refs = {}

		for position, index in ipairs(order) do
			local gem = gemInventory[index]
			local cell = Instance.new("TextButton")
			cell.Name = "GemCell" .. index
			cell.LayoutOrder = position
			cell.Text = ""
			cell.AutoButtonColor = false
			cell.BackgroundColor3 = UIColors.slot
			cell.BackgroundTransparency = UIColors.slotTransparency
			cell.Parent = scroll
			corner(cell, 8)

			local glow = Instance.new("Frame")
			glow.AnchorPoint = Vector2.new(0.5, 0.5)
			glow.Position = UDim2.new(0.5, 0, 0.5, 0)
			glow.Size = UDim2.new(1, 8, 1, 8)
			glow.BackgroundTransparency = 1
			glow.ZIndex = cell.ZIndex - 1
			glow.Parent = cell
			corner(glow, 10)

			local gradeStroke = Instance.new("UIStroke")
			gradeStroke.Thickness = 1.5
			gradeStroke.Parent = cell

			deps.applyGradeVisual(cell, gradeStroke, glow, gem.grade)

			local gradeLabel = Instance.new("TextLabel")
			gradeLabel.BackgroundTransparency = 1
			gradeLabel.Size = UDim2.new(1, -6, 0, 15)
			gradeLabel.Position = UDim2.new(0, 3, 1, -17)
			gradeLabel.Font = Enum.Font.GothamBold
			gradeLabel.TextSize = Theme.textSize("caption")
			gradeLabel.TextColor3 = UIColors.textPrimary
			gradeLabel.Text = ArmorData.grades[gem.grade].displayName
			gradeLabel.Parent = cell

			-- 선택 · 홈 먼저 모드에서 끼울 수 있는 보석(링)
			local ring = Instance.new("Frame")
			ring.Name = "Ring"
			ring.AnchorPoint = Vector2.new(0.5, 0.5)
			ring.Position = UDim2.new(0.5, 0, 0.5, 0)
			ring.Size = UDim2.new(1, -6, 1, -6)
			ring.BackgroundTransparency = 1
			ring.Visible = false
			ring.ZIndex = cell.ZIndex + 3
			ring.Parent = cell
			corner(ring, 5)
			local ringStroke = Instance.new("UIStroke")
			ringStroke.Thickness = 3
			ringStroke.Parent = ring

			-- 못 끼우는 보석(어둡게)
			local dimmer = Instance.new("Frame")
			dimmer.Name = "Dimmer"
			dimmer.Size = UDim2.new(1, 0, 1, 0)
			dimmer.BackgroundColor3 = Color3.new(0, 0, 0)
			dimmer.BackgroundTransparency = 0.45
			dimmer.BorderSizePixel = 0
			dimmer.Visible = false
			dimmer.ZIndex = cell.ZIndex + 2
			dimmer.Parent = cell
			corner(dimmer, 8)

			-- NEW(분해로 새로 들어온 보석 - 이 탭을 한 번 보고 떠나면 사라진다)
			local newBadge = Instance.new("TextLabel")
			newBadge.Name = "NewBadge"
			newBadge.AnchorPoint = Vector2.new(1, 0)
			newBadge.Position = UDim2.new(1, -3, 0, 3)
			newBadge.Size = UDim2.new(0, 34, 0, 16)
			newBadge.BackgroundColor3 = UIColors.ember
			newBadge.BorderSizePixel = 0
			newBadge.Font = Enum.Font.GothamBold
			newBadge.TextSize = Theme.textSize("caption")
			newBadge.TextColor3 = Color3.new(0, 0, 0)
			newBadge.Text = "NEW"
			newBadge.Visible = false
			newBadge.ZIndex = cell.ZIndex + 4
			newBadge.Parent = cell
			corner(newBadge, 4)

			cell.InputBegan:Connect(function(input)
				hooks.onInput(input, index, gem, cell)
			end)
			cell.Activated:Connect(function()
				hooks.onActivated(index)
			end)

			table.insert(cells, cell)
			self.refs[index] = { cell = cell, ring = ring, ringStroke = ringStroke, dimmer = dimmer, newBadge = newBadge }
		end
	end

	function self.paint(viewOf)
		for index, ref in pairs(self.refs) do
			local mark, selected, isNew = viewOf(index)
			ref.dimmer.Visible = mark == "blocked"
			local ringColor = selected and UIColors.ember or (mark == "ok" and UIColors.success or nil)
			ref.ring.Visible = ringColor ~= nil
			if ringColor then
				ref.ringStroke.Color = ringColor
			end
			ref.newBadge.Visible = isNew == true
		end
	end

	-- 이 보석(서버 index)의 지금 칸 중심(ScreenGui 좌표 - 유령이 돌아갈 자리). 칸이 없으면 nil.
	function self.center(index)
		local ref = self.refs[index]
		if ref and ref.cell.Parent then
			return ref.cell.AbsolutePosition + ref.cell.AbsoluteSize / 2
		end
		return nil
	end

	return self
end

return GemBag
