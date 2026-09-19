-- 게이지(30-0 S06, PRD 20.81 [D-3]). 높이 3종(10 · 16 · 22) · 트랙 색 · 채움 색 · 숫자 오버레이(16 이상에서만) · 값 변화 0.15초 트윈.
-- 체력바 · 경험치바 · 불씨 · 구출 막대가 같은 부품이 된다(지금 HUD는 아직 이걸 안 쓴다 - PRD [D-6] 순서).
-- Gauge.build(props) -> refs. props = { parent, height(10|16|22), width, position, layoutOrder, trackColorName, fillColorName, value(0~1), text }.
-- refs = { root, setValue(ratio, text), getValue() }. getValue는 트윈이 끝난 뒤의 목표값을 돌려준다.

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Gauge = {}

Gauge.heights = { [10] = true, [16] = true, [22] = true }
Gauge.numberMinHeight = 16
local TWEEN_INFO = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function Gauge.build(props)
	local height = props.height or 16
	assert(Gauge.heights[height], "Gauge.build: 높이는 10 · 16 · 22 중 하나 - " .. tostring(height))

	local root = Instance.new("Frame")
	root.Name = props.name or "Gauge"
	root.BackgroundColor3 = Theme.color(props.trackColorName or "hpDark")
	root.BorderSizePixel = 0
	root.Size = UDim2.new(0, props.width or 200, 0, height)
	root.Position = props.position or UDim2.new(0, 0, 0, 0)
	root.LayoutOrder = props.layoutOrder or 0
	root.ClipsDescendants = true
	root.Parent = props.parent
	Theme.corner(root, height / 2)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Theme.color(props.fillColorName or "hp")
	fill.BorderSizePixel = 0
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.Parent = root

	local numberLabel
	if height >= Gauge.numberMinHeight then
		numberLabel = Theme.label(root, "", "caption", "textPrimary")
		numberLabel.Name = "Number"
		numberLabel.Size = UDim2.new(1, 0, 1, 0)
		numberLabel.TextXAlignment = Enum.TextXAlignment.Center
		numberLabel.ZIndex = 2
	end

	local target = 0
	local refs = { root = root }
	function refs.setValue(ratio, text)
		target = math.clamp(ratio or 0, 0, 1)
		TweenService:Create(fill, TWEEN_INFO, { Size = UDim2.new(target, 0, 1, 0) }):Play()
		if numberLabel then
			numberLabel.Text = text or ""
		end
	end
	function refs.getValue()
		return target
	end
	refs.setValue(props.value or 0, props.text)
	return refs
end

return Gauge
