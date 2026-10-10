-- 토글(30-0 S06, PRD 20.81 [D-3]). 켜짐 = success 채움 + "✓" / 꺼짐 = slot + 빈 칸 - 색만으로 구분하지 않는다(✓ 모양). 라벨은 오른쪽 · 터치 영역은 라벨까지 전체.
-- Toggle.build(props) -> refs. props = { parent, text, value, width, position, layoutOrder, onChanged(value) }.
-- refs = { root, setValue(bool, silent), getValue(), setText(text), setEnabled(bool, reasonText) }. 비활성이면 눌러도 안 바뀌고 이유 한 줄이 아래(영역 밖 4px)에 나온다.

local Theme = require(script.Parent.Theme)

local Toggle = {}

local BOX_SIZE = 24

-- UI-1 1단계(00 v8 §1): 그림 스위치 - 이름표 왼쪽 · 트랙 56 × 32 오른쪽 · 손잡이 X 2 ↔ 26 · 줄 전체가 누르는 영역(PC 56 · 폰 44 이상) · 켬 = 초록 + 체크 · 끔 = 남색 + 빈 동그라미(그림 안).
--   누름 0.05초 손잡이 가로 ×1.18 + pressed 그림 · 버튼 위에서 뗄 때만 바뀜(Activated) · 손잡이 0.12초 Back · 비활성 누름 = 좌우 4px 2번 + 이유 줄. 스위치 UiV2Flags.parts = false → 옛 네모 칸.
local function buildV8(props)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local TweenService = game:GetService("TweenService")
	local D = require(ReplicatedStorage.Shared.data.UiPartsData).toggle
	local ArtImage = require(script.Parent.Parent.ArtImage)
	local rowH = math.max(Theme.isMobile and D.rowMinH.phone or D.rowMinH.pc, props.height or 0)
	local root = Instance.new("TextButton")
	root.Name = props.name or "Toggle"
	root.AutoButtonColor = false
	root.Text = ""
	root.BackgroundTransparency = 1
	root.Size = UDim2.new(0, props.width or 200, 0, rowH)
	root.Position = props.position or UDim2.new(0, 0, 0, 0)
	root.LayoutOrder = props.layoutOrder or 0
	root.Parent = props.parent
	local track = Instance.new("ImageLabel")
	track.Name = "Track"
	track.BackgroundTransparency = 1
	track.AnchorPoint = Vector2.new(1, 0.5)
	track.Position = UDim2.new(1, -4, 0.5, 0)
	track.Size = UDim2.fromOffset(D.track[1], D.track[2])
	track.Parent = root
	local knob = Instance.new("ImageLabel")
	knob.Name = "Knob"
	knob.BackgroundTransparency = 1
	knob.Size = UDim2.fromOffset(D.knob, D.knob)
	knob.Parent = track
	local label = Theme.label(root, props.text or "", "body", "textPrimary")
	label.Name = "Label"
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.new(0, 0, 0.5, 0)
	label.Size = UDim2.new(1, -(D.track[1] + 16), 1, 0)
	label.TextWrapped = true
	label.TextTruncate = Enum.TextTruncate.None
	local reasonLabel = Theme.label(root, "", "caption", "textSecondary")
	reasonLabel.Name = "Reason"
	reasonLabel.Position = UDim2.new(0, 0, 1, 2)
	reasonLabel.Size = UDim2.new(1, -(D.track[1] + 16), 0, Theme.textSize("caption") + 2)
	reasonLabel.Visible = false
	local state = { value = props.value == true, enabled = true, reason = "", pressed = false }
	local function img(key)
		return ArtImage.get(D.img[key]) or ""
	end
	local function render(animate)
		local v, en, pr = state.value, state.enabled, state.pressed
		track.Image = img(not en and (v and "onDisabled" or "offDisabled") or (pr and (v and "onPressed" or "offPressed") or (v and "on" or "off")))
		if track.Image == "" then -- 그림 기록 없음 = 색 트랙(임시)
			track.BackgroundTransparency = 0
			track.BackgroundColor3 = v and Theme.colors.success or Theme.colors.slot
		end
		knob.Image = img(not en and "knobDisabled" or (pr and "knobPressed" or "knob"))
		local x = v and D.knobOnX or D.knobOffX
		local w = pr and math.floor(D.knob * D.pressStretch) or D.knob
		if pr and v then
			x = x - (w - D.knob) -- 움직일 쪽으로 늘어남
		end
		local goal = { Position = UDim2.fromOffset(x, D.inset), Size = UDim2.fromOffset(w, D.knob) }
		if animate then
			TweenService:Create(knob, TweenInfo.new(pr and D.pressSeconds or D.moveSeconds, pr and Enum.EasingStyle.Quad or Enum.EasingStyle.Back, Enum.EasingDirection.Out), goal):Play()
		else
			knob.Position, knob.Size = goal.Position, goal.Size
		end
		label.TextColor3 = en and Theme.colors.textPrimary or Theme.colors.lockedIcon
		reasonLabel.Text = state.reason
		reasonLabel.Visible = (not en) and state.reason ~= ""
	end
	root.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if not state.enabled then
				task.spawn(function() -- 비활성 누름 = 흔들림 + 이유 줄
					for k = 1, 4 do
						track.Position = UDim2.new(1, -4 + ((k % 2 == 1) and D.shakePx or -D.shakePx), 0.5, 0)
						task.wait(D.shakeSeconds / 4)
					end
					track.Position = UDim2.new(1, -4, 0.5, 0)
				end)
				return
			end
			state.pressed = true
			render(true)
		end
	end)
	root.InputEnded:Connect(function(input)
		if state.pressed and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			state.pressed = false
			render(true)
		end
	end)
	root.MouseLeave:Connect(function()
		if state.pressed then
			state.pressed = false -- 누른 채 밖으로 = 취소
			render(true)
		end
	end)
	root.Activated:Connect(function()
		if not state.enabled then
			return
		end
		state.value = not state.value
		state.pressed = false
		render(true)
		if Theme.isMobile then
			require(script.Parent.Parent.Haptics).pulse(0.2, 0.03)
		end
		if props.onChanged then
			props.onChanged(state.value)
		end
	end)
	render(false)
	local refs = { root = root }
	function refs.setValue(value, silent)
		state.value = value == true
		render(true)
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
		render(false)
	end
	return refs
end

function Toggle.build(props)
	if require(game:GetService("ReplicatedStorage").Shared.data.UiV2Flags).parts then
		return buildV8(props)
	end
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
			check.TextColor3 = Theme.colors.textOnAccent -- QUEUE-ALL10 0-6 초록 칸 위 ✓
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
