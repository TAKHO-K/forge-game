-- 패널(30-0 S06, PRD 20.81 [D-3]). 제목줄(제목 · ? · X) + 내용 프레임 + UIManager.register까지 한 번에 한다. **새 창은 반드시 이것으로 만든다.**
-- Panel.create(props) -> refs. props = { id, kind("window"|"station"|"overlay"), title, size(Vector2), hotkey, help(도움말 글), parentId, position(UDim2), anchorPoint, onOpen, onClose }.
--   window: 딤 포함(모달). PC는 size 그대로(최대 720 × 480), 모바일은 min(92% W, 720) × min(88% H, 480).
--   station: 딤 없음(걸을 수 있다). position을 안 주면 화면 중앙.
--   overlay: 딤 포함 - 뒤의 패널 입력까지 막는다(딤이 TextButton이라 클릭을 먹는다). parentId의 패널이 닫히면 같이 닫힌다.
-- X 버튼은 제목줄 오른쪽 끝의 44 × 44 터치 영역(모바일 · PC 공통). ? 는 X 왼쪽(help를 줬을 때만).
-- refs = { screenGui, frame, content, closeButton, titleLabel, dim }. content 안은 호출부가 채운다(고정 크기 · AutomaticSize 중첩 금지).
-- 모바일 판정을 만들 때 Theme.recompute()를 부른 뒤에 create해야 그 값을 따른다(전시장이 열릴 때마다 rebuild).

local Players = game:GetService("Players")

local UIManager = require(script.Parent.Parent.Parent.UIManager)
local HelpToggle = require(script.Parent.HelpToggle)
local Theme = require(script.Parent.Theme)

local Panel = {}

Panel.maxSize = Vector2.new(720, 480)
Panel.closeSize = 44
local CLOSED_SCALE = 0.94
local PANEL_TRANSPARENCY = 0.1

function Panel.create(props)
	local kind = props.kind or "window"
	assert(kind == "window" or kind == "station" or kind == "overlay", "Panel.create: kind는 window · station · overlay - " .. tostring(kind))
	local colors = Theme.colors

	local gui = Instance.new("ScreenGui")
	gui.Name = props.id .. "Gui"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local dim
	if kind ~= "station" then
		dim = Instance.new("TextButton") -- 클릭을 먹는다(뒤로 새지 않는다). 딤을 눌러 닫지 않는다 - 클릭이 곧 공격인 게임이라(18-2 [7]).
		dim.Name = "Dim"
		dim.Text = ""
		dim.AutoButtonColor = false
		dim.Size = UDim2.new(1, 0, 1, 0)
		dim.BackgroundColor3 = colors.overlayDim
		dim.BackgroundTransparency = 1
		dim.BorderSizePixel = 0
		dim.Visible = false
		dim.Parent = gui
	end

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.AnchorPoint = props.anchorPoint or Vector2.new(0.5, 0.5)
	frame.Position = props.position or UDim2.new(0.5, 0, 0.5, 0)
	local size = props.size or Vector2.new(480, 320)
	if kind == "window" and Theme.isMobile then
		frame.Size = UDim2.new(0.92, 0, 0.88, 0)
		local constraint = Instance.new("UISizeConstraint")
		constraint.MaxSize = Panel.maxSize
		constraint.Parent = frame
	else
		frame.Size = UDim2.new(0, math.min(size.X, Panel.maxSize.X), 0, math.min(size.Y, Panel.maxSize.Y))
	end
	frame.BackgroundColor3 = colors.panel
	frame.BackgroundTransparency = 1
	frame.Active = true -- 패널 안 빈 곳을 눌러도 뒤로 새지 않는다(25-4 실측)
	frame.Visible = false
	frame.Parent = gui
	Theme.corner(frame, Theme.corner.panel)
	local frameStroke = Theme.stroke(frame)
	frameStroke.Transparency = 1
	local scale = Instance.new("UIScale")
	scale.Scale = CLOSED_SCALE
	scale.Parent = frame

	-- 제목줄
	local titleHeight = Theme.isMobile and Panel.closeSize or 40
	local titleLabel = Theme.label(frame, props.title or "", "header", "textPrimary")
	titleLabel.Name = "Title"
	titleLabel.Font = Theme.font
	titleLabel.Position = UDim2.new(0, 16, 0, 0)
	titleLabel.Size = UDim2.new(1, -(16 + Panel.closeSize + (props.help and 40 or 8)), 0, titleHeight)

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "Close"
	closeButton.AutoButtonColor = false
	closeButton.BackgroundTransparency = 1
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -4, 0, math.floor((titleHeight - Panel.closeSize) / 2))
	closeButton.Size = UDim2.new(0, Panel.closeSize, 0, Panel.closeSize)
	closeButton.Font = Theme.font
	closeButton.TextSize = Theme.textSize("header")
	closeButton.Text = "✕"
	closeButton.TextColor3 = colors.textSecondary
	closeButton.Parent = frame

	if props.help then
		HelpToggle.build({
			parent = frame,
			text = props.help,
			position = UDim2.new(1, -(4 + Panel.closeSize + 14), 0, titleHeight / 2),
			panelSide = "left",
		})
	end

	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.Position = UDim2.new(0, 0, 0, titleHeight)
	divider.Size = UDim2.new(1, 0, 0, 1)
	divider.BackgroundColor3 = colors.rim
	divider.BackgroundTransparency = colors.rimTransparency
	divider.BorderSizePixel = 0
	divider.Parent = frame

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Position = UDim2.new(0, 0, 0, titleHeight + 1)
	content.Size = UDim2.new(1, 0, 1, -(titleHeight + 1))
	content.ClipsDescendants = true
	content.Parent = frame

	local tweens = {}
	if dim then
		table.insert(tweens, { instance = dim, property = "BackgroundTransparency", open = colors.overlayDimTransparency, closed = 1, isDim = true })
	end
	table.insert(tweens, { instance = frame, property = "BackgroundTransparency", open = PANEL_TRANSPARENCY, closed = 1 })
	table.insert(tweens, { instance = frameStroke, property = "Transparency", open = colors.rimTransparency, closed = 1 })
	table.insert(tweens, { instance = scale, property = "Scale", open = 1, closed = CLOSED_SCALE })

	UIManager.register(props.id, {
		kind = kind,
		parentId = props.parentId,
		screenGui = gui,
		frame = frame,
		extraVisible = dim and { dim } or nil,
		hotkey = props.hotkey,
		hasCloseButton = true,
		tweens = tweens,
		onOpen = props.onOpen,
		onClose = props.onClose,
	})
	closeButton.Activated:Connect(function()
		UIManager.close(props.id)
	end)

	return { screenGui = gui, frame = frame, content = content, closeButton = closeButton, titleLabel = titleLabel, dim = dim }
end

return Panel
