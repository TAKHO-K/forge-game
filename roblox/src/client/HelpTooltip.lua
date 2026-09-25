-- 도움말 토글(25-3) - 작은 "?" 버튼 + 짧은 설명 패널. 새 창이 아니라 기존 UIColors 패널
-- 룩을 재사용한 말풍선 하나다.
--
-- PC: 버튼 MouseEnter로 열림, MouseLeave로 닫힘.
-- 모바일: hover가 없으므로 버튼 Activated(클릭/탭 공통)로 "연다" - 이미 열려 있어도 다시
--   열기만 하므로 터치가 MouseEnter/Activated를 둘 다 쏴도 서로 꼬이지 않는다. 닫는 쪽은
--   화면 전체를 덮는 투명 캐치 버튼(패널·버튼보다 낮은 ZIndex)이 맡는다 - 그 바깥(=지금
--   열린 패널 밖 아무 곳)을 탭/클릭하면 닫힌다. PC에서도 "밖으로 나가면 닫힌다"의 보조
--   경로로 자연스럽게 같이 동작해서, UserInputService.TouchEnabled 같은 플랫폼 분기를
--   따로 두지 않는다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local Text = require(ReplicatedStorage.Shared.Text)
local Theme = require(script.Parent.ui.kit.Theme)

local HelpTooltip = {}

-- G1-1 2단 도움말: text에 표 { short = "한 줄", detail = "상세" }를 주면 처음엔 짧은 한 줄 + "눌러서 자세히"만 보이고, 패널을 누르면 상세가 펼쳐진다
-- (닫았다 다시 열면 짧은 쪽부터). 문자열이면 옛 동작 그대로(한 단).
-- parent: 버튼을 붙일 인스턴스. anchorPosition: UDim2(버튼 중심 위치, parent 기준).
-- text: 설명(2~3줄 권장) - panelSide("right"|"left")로 패널이 버튼 어느 쪽에 펼쳐질지.
-- options(30-0 S06, ui/kit/HelpToggle가 쓴다 - 안 주면 위 기존 동작 그대로): { toggleOnly = true(hover 경로를 쓰지 않고 누를 때마다 열고 닫는다),
--   buttonSize(기본 16), buttonTextSize(기본 캡션 단 - PC 12 · 모바일 14), panelSize(Vector2, 기본 200×70), panelTextSize(기본 12) }.
function HelpTooltip.attach(parent, anchorPosition, text, panelSide, options)
	local toggleOnly = options ~= nil and options.toggleOnly == true
	local buttonSize = options and options.buttonSize or 16
	local panelSize = options and options.panelSize or Vector2.new(200, 70)
	local screenGui = parent
	while screenGui and not screenGui:IsA("ScreenGui") do
		screenGui = screenGui.Parent
	end
	screenGui = screenGui or parent

	local button = Instance.new("TextButton")
	button.Name = "HelpButton"
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = anchorPosition
	button.Size = UDim2.new(0, buttonSize, 0, buttonSize)
	button.Font = Enum.Font.GothamBold
	button.TextSize = options and options.buttonTextSize or Theme.textSize("caption") -- S12b G: 11 → 캡션 단(PC 12 · 모바일 14 - 12 미만 금지)
	button.Text = "?"
	button.TextColor3 = UIColors.textSecondary
	button.BackgroundColor3 = UIColors.panel
	button.BackgroundTransparency = UIColors.panelTransparency
	button.AutoButtonColor = false
	button.ZIndex = 51
	button.Parent = parent

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(1, 0)
	buttonCorner.Parent = button

	local buttonStroke = Instance.new("UIStroke")
	buttonStroke.Color = UIColors.rim
	buttonStroke.Transparency = UIColors.rimTransparency
	buttonStroke.Parent = button

	-- 바깥을 탭/클릭하면 닫히는 전체 화면 캐치 - 버튼·패널보다 낮은 ZIndex라 버튼 자체는
	-- 항상 눌리고, 그 외 화면 전부가 "바깥"이 된다.
	local catcher = Instance.new("TextButton")
	catcher.Name = "HelpCatcher"
	catcher.Size = UDim2.new(1, 0, 1, 0)
	catcher.BackgroundTransparency = 1
	catcher.Text = ""
	catcher.AutoButtonColor = false
	catcher.ZIndex = 49
	catcher.Visible = false
	catcher.Parent = screenGui

	local left = panelSide == "left"
	-- 고정 크기로 둔다(200×70, 2~3줄 설명 기준) - 부모(button)도 AutomaticSize를 쓰는 채로
	-- 패널·텍스트를 둘 다 AutomaticSize.Y로 중첩하면 초기 레이아웃 패스에서 TextBounds가
	-- 안 먹혀(실측 - 한 줄 폭 그대로 굳어버림) 줄바꿈이 깨지는 문제가 있었다. 고정 크기가
	-- 더 단순하고 안전하다.
	local panel = Instance.new("Frame")
	panel.Name = "HelpPanel"
	panel.AnchorPoint = Vector2.new(left and 1 or 0, 0)
	panel.Position = UDim2.new(left and 0 or 1, left and -10 or 10, 0.5, -8)
	panel.Size = UDim2.new(0, panelSize.X, 0, panelSize.Y)
	panel.BackgroundColor3 = UIColors.panel
	panel.BackgroundTransparency = UIColors.panelTransparency
	panel.ZIndex = 52
	panel.Visible = false
	panel.Parent = button

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 8)
	panelCorner.Parent = panel

	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = UIColors.rim
	panelStroke.Transparency = UIColors.rimTransparency
	panelStroke.Parent = panel

	local panelText = Instance.new("TextLabel")
	panelText.BackgroundTransparency = 1
	panelText.Position = UDim2.new(0, 10, 0, 8)
	panelText.Size = UDim2.new(1, -20, 1, -16)
	panelText.Font = Enum.Font.Gotham
	panelText.TextSize = options and options.panelTextSize or 12
	panelText.TextWrapped = true
	panelText.TextXAlignment = Enum.TextXAlignment.Left
	panelText.TextYAlignment = Enum.TextYAlignment.Top
	panelText.TextColor3 = UIColors.textPrimary
	local short, detail = text, nil
	if type(text) == "table" then
		short, detail = text.short, text.detail
	end
	panelText.Text = short
	panelText.ZIndex = 52
	panelText.Parent = panel

	local setExpanded = nil
	if detail then
		local textSize = panelText.TextSize
		local hintHeight = textSize + 4
		local collapsedHeight = math.max(44, 8 + textSize * 2.6 + hintHeight + 6) -- 짧은 줄 두 줄 + 안내 한 줄 · 터치 44 이상
		local hint = Instance.new("TextLabel")
		hint.Name = "DetailHint"
		hint.BackgroundTransparency = 1
		hint.AnchorPoint = Vector2.new(0, 1)
		hint.Position = UDim2.new(0, 10, 1, -4)
		hint.Size = UDim2.new(1, -20, 0, hintHeight)
		hint.Font = Enum.Font.GothamBold
		hint.TextSize = textSize
		hint.TextXAlignment = Enum.TextXAlignment.Right
		hint.TextColor3 = UIColors.textSecondary
		hint.ZIndex = 52
		hint.Parent = panel
		local toggle = Instance.new("TextButton")
		toggle.Name = "DetailButton"
		toggle.BackgroundTransparency = 1
		toggle.Text = ""
		toggle.Size = UDim2.new(1, 0, 1, 0)
		toggle.ZIndex = 53
		toggle.Parent = panel
		local expanded = false
		setExpanded = function(on)
			expanded = on
			panelText.Text = on and (short .. "\n\n" .. detail) or short
			panelText.Size = UDim2.new(1, -20, 1, -(16 + hintHeight))
			hint.Text = Text.get(on and "help.less" or "help.more")
			panel.Size = UDim2.new(0, panelSize.X, 0, on and math.max(panelSize.Y, collapsedHeight) or collapsedHeight)
		end
		toggle.Activated:Connect(function()
			setExpanded(not expanded)
		end)
		setExpanded(false)
	end

	local function setOpen(open)
		if open and setExpanded then
			setExpanded(false) -- 다시 열면 짧은 쪽부터
		end
		panel.Visible = open
		catcher.Visible = open
	end

	if toggleOnly then
		-- 누르면 열리고 다시 누르면 닫힌다(hover 없음 - PC · 모바일 같은 동작).
		button.Activated:Connect(function()
			setOpen(not panel.Visible)
		end)
	else
		button.MouseEnter:Connect(function()
			setOpen(true)
		end)
		button.MouseLeave:Connect(function()
			setOpen(false)
		end)
		-- 클릭/탭 공통 - 이미 열려 있어도(PC hover) 다시 "연다"만 호출하므로 토글 경합이 없다.
		button.Activated:Connect(function()
			setOpen(true)
		end)
	end
	catcher.Activated:Connect(function()
		setOpen(false)
	end)

	return button
end

return HelpTooltip
