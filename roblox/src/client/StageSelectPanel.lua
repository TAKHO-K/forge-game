-- 스테이지 선택 패널(25-4) - ▲▼ 한 칸씩 이동 대신 O(클리어)/△(도전 중)/X(진입 못 함)
-- 상태를 보여주는 그리드에서 고른다. 이동 요청은 전부 기존 StageMoveRequest/
-- StageMoveResult를 그대로 쓴다(새 RemoteEvent 없음) - 그래서 파티 비리더·X칸 클릭 같은
-- 예외 처리가 서버 판정과 항상 일치한다(클라가 새로 판정을 만들지 않는다, 그냥 실제
-- 요청을 쏘고 서버가 돌려주는 사유를 보여준다).
--
-- 25-3에서 겪은 함정 회피: AutomaticSize.Y를 부모·자식에 중첩하지 않는다(그리드 셀·
-- 패널 전부 고정 크기). 레지스터 대응으로 이 로직 전부를 독립 모듈로 뽑았다 - StageUI.
-- client.lua에는 StageSelectPanel.open() 호출 한 줄만 늘어난다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)

local stageMoveRequest = ReplicatedStorage:WaitForChild("StageMoveRequest")
local stageMoveResult = ReplicatedStorage:WaitForChild("StageMoveResult")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local StageSelectPanel = {}

-- 서버 거절 사유(StageServer.server.lua reject())를 그대로 옮긴다 - StageUI.client.lua의
-- 콘솔 warn 매핑과 같은 목록, 이 패널은 화면에도 띄운다("조용히 실패하지 마라").
local REASON_TEXT = {
	range = "그 스테이지로는 아직 갈 수 없습니다(최고 도달 스테이지 + 1까지만)",
	boss_locked = "바로 아래 보스를 먼저 깨야 갈 수 있습니다",
	party_not_leader = "보스 스테이지는 파티 리더만 열 수 있습니다",
	party_blocked = "파티원 중 입장 불가한 사람이 있습니다",
	vote_pending = "이미 진행 중인 투표가 있습니다",
}

local COLUMNS = 7
local ROWS = 3
local WINDOW_SIZE = COLUMNS * ROWS -- 21칸 고정 - 스테이지 번호가 아무리 커져도 렌더링 개수는 안 변한다.
local CELL_SIZE = 42
local CELL_GAP = 6
local STEP = 10 -- "이전/다음" 버튼 한 번에 넘기는 칸 수.

-- 나중 확장 대비(파티원 진행 상황을 파티장이 보는 기능) - LocalPlayer에 묶지 않고
-- (stage, best, bestBossCleared) 세 값만 받는 순수 함수로 둔다. 호출부가 나중에 다른
-- 파티원의 Attribute를 넘겨도 그대로 재사용된다.
-- "도전 중"의 정의(PRD 20.71) - 지금 서 있는 스테이지 한 칸이 아니라, 마지막으로 깬
-- 보스(bestBossCleared)보다 크고 최고 도달+1(입장 가능 상한) 이하인 전부.
local function computeStageStatus(stage, best, bestBossCleared)
	if stage > best + 1 then
		return "locked"
	elseif stage <= bestBossCleared then
		return "cleared"
	end
	return "inProgress"
end

local STATUS_SPEC = {
	cleared = { symbol = "O", color = UIColors.success },
	inProgress = { symbol = "△", color = UIColors.gold },
	locked = { symbol = "X", color = UIColors.danger },
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StageSelectGui"
screenGui.ResetOnSpawn = false
-- 10 - SkillSlots.client.lua(대시 버튼 등 일반 HUD)가 이미 DisplayOrder=5를 쓴다. 같은
-- 값이면 우선순위가 안 정해져 바깥 탭 감지(dim)가 그 버튼들에 클릭을 뺏길 수 있다(Studio
-- 실측으로 발견) - 일반 HUD보다는 위, UIManager 모달 창(100+)보다는 아래로 둔다.
screenGui.DisplayOrder = 10
screenGui.Enabled = false
screenGui.Parent = playerGui

local dim = Instance.new("TextButton")
dim.Name = "Dim"
dim.Size = UDim2.new(1, 0, 1, 0)
dim.BackgroundColor3 = UIColors.overlayDim
dim.BackgroundTransparency = UIColors.overlayDimTransparency
dim.AutoButtonColor = false
dim.Text = ""
dim.Parent = screenGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.5, 0, 0.5, 0)
panel.Size = UDim2.new(0, COLUMNS * (CELL_SIZE + CELL_GAP) + CELL_GAP + 24, 0, 320)
panel.BackgroundColor3 = UIColors.panel
panel.BackgroundTransparency = 0.08
-- Active=true - 안 그러면 셀 사이 여백(패딩)을 눌렀을 때 클릭이 패널을 그대로 통과해
-- 뒤에 깔린 dim(바깥 탭 감지용)까지 닿아 패널이 의도치 않게 닫힌다(Studio 실측으로 발견).
panel.Active = true
panel.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 14)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = UIColors.rim
panelStroke.Transparency = UIColors.rimTransparency
panelStroke.Parent = panel

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.new(0, 16, 0, 12)
title.Size = UDim2.new(1, -60, 0, 20)
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = UIColors.textPrimary
title.Text = "스테이지 선택"
title.Parent = panel

local closeButton = Instance.new("TextButton")
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -12, 0, 10)
closeButton.Size = UDim2.new(0, 26, 0, 26)
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 14
closeButton.Text = "X"
closeButton.TextColor3 = UIColors.textSecondary
closeButton.BackgroundColor3 = UIColors.panel
closeButton.BackgroundTransparency = UIColors.panelTransparency
closeButton.Parent = panel
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(1, 0)
closeCorner.Parent = closeButton

-- 범례 - 기호와 색을 같이 쓴다(색만으로 구분하지 않는다, 지시).
local legend = Instance.new("Frame")
legend.Position = UDim2.new(0, 16, 0, 36)
legend.Size = UDim2.new(1, -32, 0, 16)
legend.BackgroundTransparency = 1
legend.Parent = panel
local legendLayout = Instance.new("UIListLayout")
legendLayout.FillDirection = Enum.FillDirection.Horizontal
legendLayout.Padding = UDim.new(0, 14)
legendLayout.SortOrder = Enum.SortOrder.LayoutOrder
legendLayout.Parent = legend

local LEGEND_ORDER = { "cleared", "inProgress", "locked" }
local LEGEND_TEXT = { cleared = "클리어함", inProgress = "도전 중", locked = "진입 못 함" }
for i, key in ipairs(LEGEND_ORDER) do
	local spec = STATUS_SPEC[key]
	local label = Instance.new("TextLabel")
	label.LayoutOrder = i
	label.BackgroundTransparency = 1
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.new(0, 0, 1, 0)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 12
	label.TextColor3 = spec.color
	label.Text = spec.symbol .. " " .. LEGEND_TEXT[key]
	label.Parent = legend
end

-- 그리드 - 고정 크기 셀(UIGridLayout CellSize) 21개. AutomaticSize를 아예 안 쓴다(25-3
-- 함정 회피). 셀은 한 번만 만들고(재사용) 매번 텍스트·색만 새로 칠한다.
local gridArea = Instance.new("Frame")
gridArea.Position = UDim2.new(0, 12, 0, 60)
gridArea.Size = UDim2.new(0, COLUMNS * (CELL_SIZE + CELL_GAP) + CELL_GAP, 0, ROWS * (CELL_SIZE + CELL_GAP) + CELL_GAP)
gridArea.BackgroundTransparency = 1
gridArea.Parent = panel

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, CELL_SIZE, 0, CELL_SIZE)
gridLayout.CellPadding = UDim2.new(0, CELL_GAP, 0, CELL_GAP)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.StartCorner = Enum.StartCorner.TopLeft
gridLayout.Parent = gridArea

local cells = {}
for i = 1, WINDOW_SIZE do
	local cell = Instance.new("TextButton")
	cell.LayoutOrder = i
	cell.AutoButtonColor = false
	cell.Font = Enum.Font.GothamBold
	cell.TextSize = 11
	cell.BackgroundColor3 = UIColors.slot
	cell.BackgroundTransparency = UIColors.slotTransparency
	cell.Text = ""
	cell.Parent = gridArea
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = cell
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5
	stroke.Parent = cell
	local stageNumberLabel = Instance.new("TextLabel")
	stageNumberLabel.Name = "Number"
	stageNumberLabel.BackgroundTransparency = 1
	stageNumberLabel.Position = UDim2.new(0, 0, 0, 4)
	stageNumberLabel.Size = UDim2.new(1, 0, 0, 14)
	stageNumberLabel.Font = Enum.Font.Gotham
	stageNumberLabel.TextSize = 9.5
	stageNumberLabel.TextColor3 = UIColors.textTertiary
	stageNumberLabel.Text = ""
	stageNumberLabel.Parent = cell
	local symbolLabel = Instance.new("TextLabel")
	symbolLabel.Name = "Symbol"
	symbolLabel.BackgroundTransparency = 1
	symbolLabel.Position = UDim2.new(0, 0, 0, 16)
	symbolLabel.Size = UDim2.new(1, 0, 0, 22)
	symbolLabel.Font = Enum.Font.GothamBlack
	symbolLabel.TextSize = 18
	symbolLabel.Text = ""
	symbolLabel.Parent = cell
	cells[i] = { button = cell, number = stageNumberLabel, symbol = symbolLabel, stroke = stroke, stage = nil }
end

-- 페이지 이동 + 상태줄.
local pageRow = Instance.new("Frame")
pageRow.Position = UDim2.new(0, 12, 1, -68)
pageRow.Size = UDim2.new(1, -24, 0, 26)
pageRow.BackgroundTransparency = 1
pageRow.Parent = panel
local pageLayout = Instance.new("UIListLayout")
pageLayout.FillDirection = Enum.FillDirection.Horizontal
pageLayout.Padding = UDim.new(0, 8)
pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
pageLayout.Parent = pageRow

local function makePageButton(text, order)
	local button = Instance.new("TextButton")
	button.LayoutOrder = order
	button.AutomaticSize = Enum.AutomaticSize.X
	button.Size = UDim2.new(0, 0, 1, 0)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 12
	button.TextColor3 = UIColors.textSecondary
	button.BackgroundColor3 = UIColors.panel
	button.BackgroundTransparency = UIColors.panelTransparency
	button.Text = text
	button.Parent = pageRow
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = UIColors.rim
	stroke.Transparency = UIColors.rimTransparency
	stroke.Parent = button
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = button
	return button
end

local prevButton = makePageButton("◀ 이전 " .. STEP, 1)
local frontierButton = makePageButton("최전선", 2)
local nextButton = makePageButton("다음 " .. STEP .. " ▶", 3)

local statusLine = Instance.new("TextLabel")
statusLine.Position = UDim2.new(0, 16, 1, -34)
statusLine.Size = UDim2.new(1, -32, 0, 26)
statusLine.BackgroundTransparency = 1
statusLine.Font = Enum.Font.Gotham
statusLine.TextSize = 11.5
statusLine.TextWrapped = true
statusLine.TextXAlignment = Enum.TextXAlignment.Left
statusLine.TextColor3 = UIColors.danger
statusLine.Text = ""
statusLine.Parent = panel

local isOpen = false
local windowStart = 1

local function attrs()
	-- 예외 1(세이브 없는 신규 플레이어): 프로필 로드 전엔 Attribute가 nil일 수 있다 -
	-- 기본값으로 방어한다(open() 자체를 프로필 로드 전엔 안 부르는 게 1차 방어).
	local stage = player:GetAttribute("InfiniteStage") or 1
	local best = player:GetAttribute("InfiniteStageBest") or 1
	local bestBossCleared = player:GetAttribute("BestBossCleared") or 0
	return stage, best, bestBossCleared
end

local function render()
	if not isOpen then
		return
	end
	local _, best, bestBossCleared = attrs()
	for i, cell in ipairs(cells) do
		local stage = windowStart + i - 1
		cell.stage = stage
		-- 예외 2(스테이지 번호가 매우 클 때): 창 방식이라 항상 WINDOW_SIZE개만 그린다 -
		-- 여기 산술은 정수 덧셈·비교뿐이라 큰 수에서도 안 터진다.
		if stage < 1 then
			cell.button.Visible = false
		else
			cell.button.Visible = true
			local status = computeStageStatus(stage, best, bestBossCleared)
			local spec = STATUS_SPEC[status]
			cell.number.Text = tostring(stage)
			cell.symbol.Text = spec.symbol
			cell.symbol.TextColor3 = spec.color
			cell.stroke.Color = spec.color
			cell.stroke.Transparency = 0.3
		end
	end
	prevButton.Visible = windowStart > 1
end

local function setStatus(text)
	statusLine.Text = text or ""
end

for _, cell in ipairs(cells) do
	cell.button.Activated:Connect(function()
		if not cell.stage then
			return
		end
		setStatus("")
		-- 예외 4·5(비리더·X칸 클릭): 클라에서 막지 않는다 - 항상 실제 요청을 쏘고 서버
		-- 판정(reject 사유)을 그대로 보여준다.
		stageMoveRequest:FireServer(cell.stage)
	end)
end

prevButton.Activated:Connect(function()
	windowStart = math.max(1, windowStart - STEP)
	render()
end)

nextButton.Activated:Connect(function()
	windowStart = windowStart + STEP
	render()
end)

frontierButton.Activated:Connect(function()
	local _, best = attrs()
	windowStart = math.max(1, best + 1 - math.floor(WINDOW_SIZE / 2))
	render()
end)

local function close()
	isOpen = false
	screenGui.Enabled = false
end

dim.Activated:Connect(close)
closeButton.Activated:Connect(close)

function StageSelectPanel.open()
	local _, best = attrs()
	windowStart = math.max(1, best + 1 - math.floor(WINDOW_SIZE / 2))
	isOpen = true
	screenGui.Enabled = true
	setStatus("")
	render()
end

-- 예외 3(목록을 연 채로 스테이지가 바뀔 때, 파티 투표 이동 포함): 세 Attribute를 구독해
-- 열려 있는 동안은 그 자리에서 다시 그린다(windowStart는 유지 - 보던 자리를 안 바꾼다).
for _, attr in ipairs({ "InfiniteStage", "InfiniteStageBest", "BestBossCleared" }) do
	player:GetAttributeChangedSignal(attr):Connect(render)
end

stageMoveResult.OnClientEvent:Connect(function(payload)
	if not isOpen then
		return
	end
	if payload.result == "ok" then
		setStatus("")
	elseif payload.result == "rejected" then
		setStatus(REASON_TEXT[payload.reason] or ("이동할 수 없습니다(" .. tostring(payload.reason) .. ")"))
	end
end)

return StageSelectPanel
