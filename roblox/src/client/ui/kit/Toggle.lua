-- 토글(30-0 S06, PRD 20.81 [D-3]). 켜짐 = success 채움 + "✓" / 꺼짐 = slot + 빈 칸 - 색만으로 구분하지 않는다(✓ 모양). 라벨은 오른쪽 · 터치 영역은 라벨까지 전체.
-- Toggle.build(props) -> refs. props = { parent, text, value, width, position, layoutOrder, onChanged(value) }.
-- refs = { root, setValue(bool, silent), getValue(), setText(text), setEnabled(bool, reasonText) }. 비활성이면 눌러도 안 바뀌고 이유 한 줄이 아래(영역 밖 4px)에 나온다.

local Theme = require(script.Parent.Theme)

local Toggle = {}

local BOX_SIZE = 24

function Toggle.build(props)
	local root = Instance.new("TextButton")
	root.Name = props.name or "Toggle"
	root.AutoButtonColor = false
	root.Text = ""
	root.BackgroundTransparency = 1
	root.Size = UDim2.new(0, props.width or 200, 0, Theme.isMobile and Theme.touchMin or 32)
	root.Position = props.position or UDim2.new(0, 0, 0, 0)
	root.LayoutOrder = props.layoutOrder or 0
	root.Parent = props.parent

	local box = Instance.new("Frame")
	box.Name = "Box"
	box.AnchorPoint = Vector2.new(0, 0.5)
	box.Position = UDim2.new(0, 0, 0.5, 0)
	box.Size = UDim2.new(0, BOX_SIZE, 0, BOX_SIZE)
	box.Parent = root
	Theme.corner(box, 6)
	local boxStroke = Theme.stroke(box)

	local check = Theme.label(box, "✓", "body", "textPrimary")
	check.Name = "Check"
	check.Size = UDim2.new(1, 0, 1, 0)
	check.TextXAlignment = Enum.TextXAlignment.Center
	check.Font = Theme.font

	local label = Theme.label(root, props.text or "", "body", "textPrimary")
	label.Name = "Label"
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.new(0, BOX_SIZE + 10, 0.5, 0)
	label.Size = UDim2.new(1, -(BOX_SIZE + 10), 0, Theme.textSize("body") + 4)

	local reasonLabel = Theme.label(root, "", "caption", "textSecondary")
	reasonLabel.Name = "Reason"
	reasonLabel.Position = UDim2.new(0, BOX_SIZE + 10, 1, 2)
	reasonLabel.Size = UDim2.new(1, -(BOX_SIZE + 10), 0, Theme.textSize("caption") + 2)
	reasonLabel.Visible = false

	local state = { value = props.value == true, enabled = true, reason = "" }

	local function render()
		if not state.enabled then
			box.BackgroundColor3 = Theme.colors.lockedBg
			box.BackgroundTransparency = 0
			boxStroke.Color = Theme.colors.lockedRim
			boxStroke.Transparency = 0.3
			check.TextColor3 = Theme.colors.lockedIcon
			label.TextColor3 = Theme.colors.lockedIcon
		elseif state.value then
			box.BackgroundColor3 = Theme.colors.success
			box.BackgroundTransparency = 0
			boxStroke.Color = Theme.colors.success
			boxStroke.Transparency = 1
			check.TextColor3 = Theme.colors.textPrimary
			label.TextColor3 = Theme.colors.textPrimary
		else
			box.BackgroundColor3 = Theme.colors.slot
			box.BackgroundTransparency = Theme.colors.slotTransparency
			boxStroke.Color = Theme.colors.rim
			boxStroke.Transparency = Theme.colors.rimTransparency
			check.TextColor3 = Theme.colors.textPrimary
			label.TextColor3 = Theme.colors.textPrimary
		end
		check.Visible = state.value
		reasonLabel.Text = state.reason
		reasonLabel.Visible = (not state.enabled) and state.reason ~= ""
	end

	root.Activated:Connect(function()
		if not state.enabled then
			return
		end
		state.value = not state.value
		render()
		if props.onChanged then
			props.onChanged(state.value)
		end
	end)

	render()

	local refs = { root = root }
	function refs.setValue(value, silent)
		state.value = value == true
		render()
		if not silent and props.onChanged then
			props.onChanged(state.value)
		end
	end
	function refs.getValue()
		return state.value
	end
	function refs.setText(text)
		label.Text = text
	end
	function refs.setEnabled(enabled, reasonText)
		state.enabled = enabled
		state.reason = enabled and "" or (reasonText or "")
		render()
	end
	return refs
end

return Toggle
