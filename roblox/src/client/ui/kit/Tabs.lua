-- 탭(30-0 S06, PRD 20.81 [D-3]). 선택 = textPrimary + ember 밑줄 3px / 비선택 = textSecondary. 높이 Theme.tabHeight(28 / 모바일 40).
-- 5개를 넘으면 가로 스크롤이 아니라 **창을 나눈다** - 6개 이상을 넘기면 error.
-- Tabs.build(props) -> refs. props = { parent, tabs = { { id, text }, ... }, selected(id), width, position, layoutOrder, onSelect(id) }.
-- refs = { root, select(id, silent), getSelected() }.

local Theme = require(script.Parent.Theme)

local Tabs = {}

Tabs.maxTabs = 5
local UNDERLINE_HEIGHT = 3

function Tabs.build(props)
	local tabs = props.tabs
	assert(#tabs >= 1 and #tabs <= Tabs.maxTabs, ("Tabs.build: 탭은 1 ~ %d개(받은 것 %d개) - 넘으면 창을 나눈다"):format(Tabs.maxTabs, #tabs))

	local root = Instance.new("Frame")
	root.Name = props.name or "Tabs"
	root.BackgroundTransparency = 1
	root.Size = UDim2.new(0, props.width or 240, 0, Theme.tabHeight)
	root.Position = props.position or UDim2.new(0, 0, 0, 0)
	root.LayoutOrder = props.layoutOrder or 0
	root.Parent = props.parent

	local state = { selected = props.selected or tabs[1].id }
	local handles = {}

	local function render()
		for id, handle in pairs(handles) do
			local isSelected = id == state.selected
			handle.button.TextColor3 = isSelected and Theme.colors.textPrimary or Theme.colors.textSecondary
			handle.underline.Visible = isSelected
		end
	end

	local function select(id, silent)
		if not handles[id] then
			return
		end
		state.selected = id
		render()
		if not silent and props.onSelect then
			props.onSelect(id)
		end
	end

	for index, tab in ipairs(tabs) do
		local button = Instance.new("TextButton")
		button.Name = "Tab_" .. tab.id
		button.AutoButtonColor = false
		button.BackgroundTransparency = 1
		button.Size = UDim2.new(1 / #tabs, 0, 1, 0)
		button.Position = UDim2.new((index - 1) / #tabs, 0, 0, 0)
		button.Font = Theme.font
		button.TextSize = Theme.textSize("body")
		button.Text = tab.text
		button.Parent = root

		local underline = Instance.new("Frame")
		underline.Name = "Underline"
		underline.AnchorPoint = Vector2.new(0.5, 1)
		underline.Position = UDim2.new(0.5, 0, 1, 0)
		underline.Size = UDim2.new(1, -8, 0, UNDERLINE_HEIGHT)
		underline.BackgroundColor3 = Theme.colors.ember
		underline.BorderSizePixel = 0
		underline.Visible = false
		underline.Parent = button

		handles[tab.id] = { button = button, underline = underline }
		button.Activated:Connect(function()
			select(tab.id, false)
		end)
	end

	render()

	return {
		root = root,
		select = select,
		getSelected = function()
			return state.selected
		end,
	}
end

return Tabs
