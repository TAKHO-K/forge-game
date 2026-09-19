-- 버튼(30-0 S06, PRD 20.81 [D-3]). 3종(primary / secondary / danger) × 상태 4개(기본 · 눌림 · 비활성 · 진행 중).
-- Button.build(props) -> refs. props = { parent, kind, text, width, position, anchorPoint, layoutOrder, height, onActivated }.
-- 높이는 Theme.buttonHeight(PC 32 / 모바일 44) · 최소 폭 88 · 고정 크기(AutomaticSize 없음).
-- 비활성 이유 한 줄은 버튼 **아래**(버튼 자신의 영역 밖, 아래 4px)에 나온다 - 호출부가 그만큼(caption 글씨 높이 + 4) 비워 둔다.
-- 눌림 색은 InputBegan에서 즉시 바꾼다(Activated는 손을 뗀 뒤라 늦다).
-- refs = { root, setEnabled(bool, reasonText), setBusy(bool), setText(text), forceVisual(state|nil), getVisual() }.

local Theme = require(script.Parent.Theme)

local Button = {}

Button.minWidth = 88
Button.kinds = { primary = true, secondary = true, danger = true }

-- 종류 · 시각 상태 → 색. 눌림은 종류와 무관하게 emberDim(지시서). 비활성은 lockedBg + lockedIcon.
local function look(kind, visual)
	local colors = Theme.colors
	if visual == "pressed" then
		return { fill = colors.emberDim, fillTransparency = 0, text = colors.textPrimary, stroke = colors.rim, strokeTransparency = colors.rimTransparency }
	elseif visual == "disabled" then
		return { fill = colors.lockedBg, fillTransparency = 0, text = colors.lockedIcon, stroke = colors.lockedRim, strokeTransparency = 0.3 }
	end
	-- 기본 · 진행 중(같은 바탕, 글씨만 "…")
	if kind == "primary" then
		return { fill = colors.ember, fillTransparency = 0, text = colors.textPrimary, stroke = colors.ember, strokeTransparency = 1 }
	elseif kind == "danger" then
		return { fill = colors.slot, fillTransparency = colors.slotTransparency, text = colors.textPrimary, stroke = colors.danger, strokeTransparency = 0 }
	end
	return { fill = colors.slot, fillTransparency = colors.slotTransparency, text = colors.textPrimary, stroke = colors.rim, strokeTransparency = colors.rimTransparency }
end

function Button.build(props)
	local kind = props.kind or "secondary"
	assert(Button.kinds[kind], "Button.build: 알 수 없는 kind - " .. tostring(kind))
	local height = props.height or Theme.buttonHeight

	local button = Instance.new("TextButton")
	button.Name = props.name or "Button"
	button.AutoButtonColor = false
	button.Size = UDim2.new(0, math.max(Button.minWidth, props.width or Button.minWidth), 0, height)
	button.AnchorPoint = props.anchorPoint or Vector2.new(0, 0)
	button.Position = props.position or UDim2.new(0, 0, 0, 0)
	button.LayoutOrder = props.layoutOrder or 0
	button.Font = Theme.font
	button.TextSize = Theme.textSize("body")
	button.Text = props.text or ""
	button.Parent = props.parent
	Theme.corner(button, Theme.corner.button)
	local stroke = Theme.stroke(button)

	local reason = Theme.label(button, "", "caption", "textSecondary")
	reason.Name = "Reason"
	reason.Position = UDim2.new(0, 0, 1, 4)
	reason.Size = UDim2.new(1, 0, 0, Theme.textSize("caption") + 2)
	reason.Visible = false

	local state = { enabled = true, busy = false, pressed = false, forced = nil, text = props.text or "", reason = "" }

	local function visualState()
		if state.forced then
			return state.forced
		end
		if state.busy then
			return "busy"
		end
		if not state.enabled then
			return "disabled"
		end
		return state.pressed and "pressed" or "default"
	end

	local function render()
		local visual = visualState()
		local applied = look(kind, visual)
		button.BackgroundColor3 = applied.fill
		button.BackgroundTransparency = applied.fillTransparency
		button.TextColor3 = applied.text
		stroke.Color = applied.stroke
		stroke.Transparency = applied.strokeTransparency
		button.Text = (visual == "busy") and "…" or state.text
		reason.Text = state.reason
		reason.Visible = (visual == "disabled") and state.reason ~= ""
	end

	local function isPointer(input)
		return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	end
	button.InputBegan:Connect(function(input)
		if isPointer(input) and state.enabled and not state.busy then
			state.pressed = true
			render()
		end
	end)
	button.InputEnded:Connect(function(input)
		if isPointer(input) and state.pressed then
			state.pressed = false
			render()
		end
	end)
	button.Activated:Connect(function()
		if state.enabled and not state.busy and props.onActivated then
			props.onActivated()
		end
	end)

	render()

	local refs = { root = button }
	function refs.setEnabled(enabled, reasonText)
		state.enabled = enabled
		state.reason = enabled and "" or (reasonText or "")
		state.pressed = false
		render()
	end
	function refs.setBusy(busy)
		state.busy = busy
		state.pressed = false
		render()
	end
	function refs.setText(text)
		state.text = text
		render()
	end
	-- 전시장 전용: 눌림 같은 순간 상태를 고정해 보여 준다("default" · "pressed" · "disabled" · "busy" 또는 nil로 해제).
	function refs.forceVisual(visual)
		state.forced = visual
		render()
	end
	function refs.getVisual()
		return visualState()
	end
	return refs
end

return Button
