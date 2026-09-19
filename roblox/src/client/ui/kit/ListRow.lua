-- 목록 행(30-0 S06, PRD 20.81 [D-3]). 고정 높이 3종(28 · 40 · 56) · 왼쪽 아이콘 칸 · 가운데 글(높이 28은 1줄, 40 · 56은 2줄) · 오른쪽 값 또는 버튼.
-- 글이 넘치면 말줄임(TextTruncate.AtEnd) - 행 높이는 늘지 않는다. 선택 = rimHi 테두리.
-- ListRow.build(props) -> refs. props = { parent, height(28|40|56), iconText, title, subtitle, valueText, button = { text, kind, onActivated }, selected, width, position, layoutOrder, onActivated }.
-- 버튼은 버튼 높이 + 위아래 여백 4씩 이상인 행에서만 쓴다(PC 40 · 56 / 모바일 56 - 버튼 44 터치 타깃을 줄이지 않는다).
-- refs = { root, setSelected(bool), setTitle(text), setSubtitle(text), setValue(text) }.

local Button = require(script.Parent.Button)
local Theme = require(script.Parent.Theme)

local ListRow = {}

ListRow.heights = { [28] = true, [40] = true, [56] = true }
local PAD = 4

function ListRow.build(props)
	local height = props.height or 40
	assert(ListRow.heights[height], "ListRow.build: 높이는 28 · 40 · 56 중 하나 - " .. tostring(height))
	assert(not (props.button and height < Theme.buttonHeight + PAD * 2), ("ListRow.build: 버튼은 높이 %d 이상의 행에서만 쓴다(버튼 높이 %d + 여백)"):format(Theme.buttonHeight + PAD * 2, Theme.buttonHeight))

	local root = Instance.new("TextButton")
	root.Name = props.name or "ListRow"
	root.AutoButtonColor = false
	root.Text = ""
	root.BackgroundColor3 = Theme.colors.slot
	root.BackgroundTransparency = Theme.colors.slotTransparency
	root.Size = UDim2.new(0, props.width or 240, 0, height)
	root.Position = props.position or UDim2.new(0, 0, 0, 0)
	root.LayoutOrder = props.layoutOrder or 0
	root.Parent = props.parent
	Theme.corner(root, Theme.corner.chip)
	local stroke = Theme.stroke(root)

	local iconSize = height - PAD * 2
	local iconCell = Theme.label(root, props.iconText or "", "number", "textSecondary")
	iconCell.Name = "Icon"
	iconCell.Position = UDim2.new(0, PAD, 0, PAD)
	iconCell.Size = UDim2.new(0, iconSize, 0, iconSize)
	iconCell.TextXAlignment = Enum.TextXAlignment.Center

	-- 오른쪽 자리: 버튼(폭 88) 또는 값 글(폭 72).
	local rightWidth = props.button and Button.minWidth or ((props.valueText ~= nil) and 72 or 0)
	local textX = PAD + iconSize + 8
	local textWidth = -(textX + rightWidth + (rightWidth > 0 and 8 or PAD))

	local titleHeight = Theme.textSize("body") + 4
	local subtitleHeight = Theme.textSize("caption") + 2
	local title = Theme.label(root, props.title or "", "body", "textPrimary")
	title.Name = "Title"
	title.Size = UDim2.new(1, textWidth, 0, titleHeight)
	local subtitle = Theme.label(root, props.subtitle or "", "caption", "textSecondary")
	subtitle.Name = "Subtitle"
	subtitle.Size = UDim2.new(1, textWidth, 0, subtitleHeight)
	if height == 28 then
		title.Position = UDim2.new(0, textX, 0.5, -titleHeight / 2)
		subtitle.Visible = false
	else
		local gap = height == 40 and 0 or 2
		local block = titleHeight + gap + subtitleHeight
		title.Position = UDim2.new(0, textX, 0.5, -block / 2)
		subtitle.Position = UDim2.new(0, textX, 0.5, -block / 2 + titleHeight + gap)
	end

	local valueLabel
	if props.valueText ~= nil and not props.button then
		valueLabel = Theme.label(root, props.valueText, "body", "textPrimary")
		valueLabel.Name = "Value"
		valueLabel.AnchorPoint = Vector2.new(1, 0.5)
		valueLabel.Position = UDim2.new(1, -PAD - 4, 0.5, 0)
		valueLabel.Size = UDim2.new(0, rightWidth, 0, titleHeight)
		valueLabel.TextXAlignment = Enum.TextXAlignment.Right
		valueLabel.Font = Theme.font
	end
	if props.button then
		Button.build({
			parent = root,
			kind = props.button.kind or "secondary",
			text = props.button.text,
			width = rightWidth,
			anchorPoint = Vector2.new(1, 0.5),
			position = UDim2.new(1, -PAD - 4, 0.5, 0),
			onActivated = props.button.onActivated,
		})
	end

	if props.onActivated then
		root.Activated:Connect(props.onActivated)
	end

	local refs = { root = root }
	function refs.setSelected(selected)
		stroke.Color = selected and Theme.colors.rimHi or Theme.colors.rim
		stroke.Transparency = selected and Theme.colors.rimHiTransparency or Theme.colors.rimTransparency
	end
	function refs.setTitle(text)
		title.Text = text
	end
	function refs.setSubtitle(text)
		subtitle.Text = text
	end
	function refs.setValue(text)
		if valueLabel then
			valueLabel.Text = text
		end
	end
	refs.setSelected(props.selected == true)
	return refs
end

return ListRow
