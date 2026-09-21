-- 보석 홈 5칸 한 줄(S20c) - 무기 그림 위에 붙이지 않고 무기와 무관한 한 줄로 늘어놓는다(무기 에셋은 임시 - F5에서 Socket Attachment로 교체). 보석 탭의 드롭 · 탭 대상이다.
-- 홈 그리기 상태: 잠김(HudIcons.lock) / 채움(등급 색 테두리 + 안쪽 음영으로 보석이 박힌 느낌 + 보석 원) / 열린 빈 홈(홈 등급 색 테두리 + 음영 - 지금 규칙에서는 홈이 열리면 바로 채워져 옛 개발 계정에만 나온다)
-- + 표시: mark = "ok"(끼울 수 있다 - 성공색 테두리 · 살짝 밝게) · "blocked"(끼울 수 없다 - 어둡게 + 작은 ×) · selected(선택 · 홈 먼저 고른 홈 - 강조색 테두리). 색은 전부 기존 표(UIColors · 아이템 등급 색 ItemVisualData)뿐이다.
-- GemSlots.create(parent) -> { row, chips = { [slot] = { button, ... } }, setLayout(size, gap), paint(slot, view) }
--   view = { unlocked, filled, gemGrade, mark, selected }

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local Gem = require(ReplicatedStorage.Shared.Gem)
local HudIcons = require(script.Parent.Parent.Parent.HudIcons)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)
local GemActions = require(script.Parent.GemActions)

local GemSlots = {}

local LOCK_ICON_SIZE = 20
local DOT_RATIO = 0.42 -- 보석 원 지름 = 칩 크기 × 이 값
local LABEL_HEIGHT = 14

local function blendToward(base, target, ratio)
	return Color3.new(base.R + (target.R - base.R) * ratio, base.G + (target.G - base.G) * ratio, base.B + (target.B - base.B) * ratio)
end

local function round(inst, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = inst
	return corner
end

function GemSlots.create(parent)
	local row = Instance.new("Frame")
	row.Name = "SocketRow"
	row.BackgroundTransparency = 1
	row.Parent = parent

	local chips = {}
	for slot = 1, Gem.slotCount do
		local button = Instance.new("TextButton")
		button.Name = "Socket" .. slot
		button.Text = ""
		button.AutoButtonColor = false
		button.BackgroundColor3 = UIColors.slot
		button.BackgroundTransparency = UIColors.slotTransparency
		button.Parent = row
		round(button, 8)
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Parent = button

		-- 안쪽 음영: 어두운 우물 - 보석이 박혀 있는 홈처럼 보인다
		local well = Instance.new("Frame")
		well.Name = "Well"
		well.Position = UDim2.new(0, 3, 0, 3)
		well.Size = UDim2.new(1, -6, 1, -6)
		well.BackgroundColor3 = Color3.new(0, 0, 0)
		well.BackgroundTransparency = 0.45
		well.BorderSizePixel = 0
		well.ZIndex = 2
		well.Parent = button
		round(well, 6)
		local wellStroke = Instance.new("UIStroke")
		wellStroke.Color = Color3.new(0, 0, 0)
		wellStroke.Transparency = 0.3
		wellStroke.Parent = well

		local dot = Instance.new("Frame")
		dot.Name = "Gem"
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.BorderSizePixel = 0
		dot.ZIndex = 3
		dot.Parent = button
		round(dot, 100)
		local dotStroke = Instance.new("UIStroke")
		dotStroke.Color = Color3.new(1, 1, 1)
		dotStroke.Transparency = 0.5
		dotStroke.Parent = dot

		local number = Instance.new("TextLabel")
		number.Name = "Number"
		number.BackgroundTransparency = 1
		number.AnchorPoint = Vector2.new(0, 1)
		number.Position = UDim2.new(0, 0, 1, -2)
		number.Size = UDim2.new(1, 0, 0, LABEL_HEIGHT)
		number.Font = Enum.Font.GothamBold
		number.TextSize = Theme.textSize("caption") -- 12 미만 금지
		number.Text = tostring(slot)
		number.ZIndex = 3
		number.Parent = button

		local lock = HudIcons.lock(button, LOCK_ICON_SIZE)
		lock.Name = "Lock"
		lock.AnchorPoint = Vector2.new(0.5, 0.5)
		lock.Position = UDim2.new(0.5, 0, 0.5, 0)

		-- 끼울 수 없는 홈: 어둡게 + 작은 ×
		local dimmer = Instance.new("Frame")
		dimmer.Name = "Dimmer"
		dimmer.Size = UDim2.new(1, 0, 1, 0)
		dimmer.BackgroundColor3 = Color3.new(0, 0, 0)
		dimmer.BackgroundTransparency = 0.35
		dimmer.BorderSizePixel = 0
		dimmer.ZIndex = 6
		dimmer.Visible = false
		dimmer.Parent = button
		round(dimmer, 8)
		local cross = Instance.new("TextLabel")
		cross.BackgroundTransparency = 1
		cross.Size = UDim2.new(1, 0, 1, 0)
		cross.Font = Enum.Font.GothamBold
		cross.TextSize = Theme.textSize("header")
		cross.TextColor3 = UIColors.danger
		cross.Text = "×"
		cross.ZIndex = 7
		cross.Parent = dimmer

		chips[slot] = { button = button, stroke = stroke, well = well, dot = dot, number = number, lock = lock, dimmer = dimmer }
	end

	local self = { row = row, chips = chips }

	-- 칩 크기 · 간격(PC 34 / 폰 48 - Layout이 정한다). 한 줄로 늘어놓는다.
	function self.setLayout(size, gap)
		row.Size = UDim2.new(0, Gem.slotCount * size + (Gem.slotCount - 1) * gap, 0, size)
		local dotSize = math.max(12, math.floor(size * DOT_RATIO))
		for slot, chip in ipairs(chips) do
			chip.button.Size = UDim2.new(0, size, 0, size)
			chip.button.Position = UDim2.new(0, (slot - 1) * (size + gap), 0, 0)
			chip.dot.Size = UDim2.new(0, dotSize, 0, dotSize)
			chip.dot.Position = UDim2.new(0.5, 0, 0, math.floor((size - LABEL_HEIGHT) / 2) + 1)
		end
	end

	function self.paint(slot, view)
		local chip = chips[slot]
		local capColor = GemActions.gradeColor(Gem.gradeCapForSlot(slot))
		chip.button.BackgroundColor3 = UIColors.slot
		if not view.unlocked then
			chip.well.Visible = false
			chip.dot.Visible = false
			chip.number.Visible = false
			chip.lock.Visible = true
			chip.stroke.Color = UIColors.rim
			chip.stroke.Transparency = 0.6
			chip.stroke.Thickness = 1.5
		else
			chip.lock.Visible = false
			chip.well.Visible = true
			chip.number.Visible = true
			chip.number.TextColor3 = capColor -- 번호 색 = 이 홈의 등급 상한
			chip.dot.Visible = view.filled
			chip.stroke.Transparency = 0
			chip.stroke.Thickness = 2
			if view.filled then
				local color = GemActions.gradeColor(view.gemGrade)
				chip.dot.BackgroundColor3 = color
				chip.stroke.Color = color
			else
				chip.stroke.Color = capColor
				chip.stroke.Transparency = 0.25
			end
		end
		chip.dimmer.Visible = view.mark == "blocked"
		if view.mark == "ok" then
			chip.stroke.Color = UIColors.success
			chip.stroke.Transparency = 0
			chip.stroke.Thickness = 3
			chip.button.BackgroundColor3 = blendToward(UIColors.slot, UIColors.success, 0.25)
		end
		if view.selected then
			chip.stroke.Color = UIColors.ember
			chip.stroke.Transparency = 0
			chip.stroke.Thickness = 3
		end
	end

	return self
end

return GemSlots
