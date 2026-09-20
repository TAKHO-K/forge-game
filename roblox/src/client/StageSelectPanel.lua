-- 스테이지 선택 패널(25-4) - ▲▼ 한 칸씩 이동 대신 O(클리어)/△(도전 중)/X(진입 못 함)
-- 상태를 보여주는 그리드에서 고른다. 이동 요청은 전부 기존 StageMoveRequest/
-- StageMoveResult를 그대로 쓴다(새 RemoteEvent 없음) - 그래서 파티 비리더·X칸 클릭 같은
-- 예외 처리가 서버 판정과 항상 일치한다(클라가 새로 판정을 만들지 않는다, 그냥 실제
-- 요청을 쏘고 서버가 돌려주는 사유를 보여준다).
--
-- 25-3에서 겪은 함정 회피: AutomaticSize.Y를 부모·자식에 중첩하지 않는다(그리드 셀·
-- 패널 전부 고정 크기). 레지스터 대응으로 이 로직 전부를 독립 모듈로 뽑았다 - StageUI.
-- client.lua에는 StageSelectPanel.open() 호출 한 줄만 늘어난다.
--
-- 30-0 S11(PRD 20.73 [4-2]): 그리드와 페이지 버튼 사이에 보상 띠(StageRewardBand)가 끼었다 - 패널 높이 320 → 396. **보스 칸(5의 배수)만 2단계**다: 칸을 누르면 선택 +
-- 띠가 채워지고 [도전]을 눌러야 이동 요청이 나간다(파티에서는 이 클릭이 투표와 전원 텔레포트를 일으킨다). 일반 칸은 지금처럼 한 번에 이동한다. 보스 칸의 받을 것 ★ / 다 받음 ✓
-- 표시와 띠의 내용은 서버 조회(BossRewardPreviewRequest / Result)가 준다 - 클라는 판정하지 않는다(25-4 그대로: X 칸도 [도전]은 눌리고 서버 거절 사유가 상태줄에 뜬다).
--
-- 30-0 S15(PRD 20.81 [C-4] · [D-1]): 그리드가 **10칸(5 × 2) = 한 구간**(1 ~ 10 · 11 ~ 20 …)으로 바뀌었고 - 창의 시작이 항상 10의 배수 + 1이라 보스 칸이 늘 5번째 · 10번째 자리다 - 그리드 위에
-- 구간 칩 5개(`41-50` …, 50스테이지 묶음) + 양끝 ◀ ▶가 생겼다. 패널은 `UIManager`의 station("stageSelect", 단축키 M은 ui/PanelRegistry)으로 등록돼 열기 · 닫기 · DisplayOrder · 딤 없음(걸을 수 있다)을
-- 매니저가 맡는다(가방 window가 열리면 닫히고 · 강화 패널 station과 서로 닫는다 · 견습 중에는 canOpen이 막는다). 이동 요청 · 거절 · 투표 · 보상 띠의 코드 경로는 그대로다(클라 표시만 바뀌었다).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local BossRewardPreviewData = require(ReplicatedStorage.Shared.data.BossRewardPreviewData)
local DevToolsConfig = require(ReplicatedStorage.Shared.data.DevToolsConfig)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local HudIcons = require(script.Parent.HudIcons)
local StageRewardBand = require(script.Parent.StageRewardBand)
local UIManager = require(script.Parent.UIManager)

local stageMoveRequest = ReplicatedStorage:WaitForChild("StageMoveRequest")
local stageMoveResult = ReplicatedStorage:WaitForChild("StageMoveResult")
local previewRequest = ReplicatedStorage:WaitForChild("BossRewardPreviewRequest")
local previewResult = ReplicatedStorage:WaitForChild("BossRewardPreviewResult")

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

local COLUMNS = 5
local ROWS = 2
local WINDOW_SIZE = COLUMNS * ROWS -- 10칸 고정 = 한 구간 - 스테이지 번호가 아무리 커져도 렌더링 개수는 안 변한다.
local STEP = WINDOW_SIZE -- "이전/다음" 버튼 한 번에 넘기는 칸 수(구간 하나).
local CHIPS = 5 -- 구간 칩 개수(칩 묶음 = 5 × 10 = 50스테이지)
local CHIP_SPAN = CHIPS * WINDOW_SIZE
local CELL_GAP = 6
local PANEL_WIDTH = 366
local GRID_WIDTH = PANEL_WIDTH - 24
-- 칸 크기는 남는 폭에 맞춰 키운다(5열이라 예전 42보다 넓다 - 모바일 터치 44 이상). 높이는 구간 띠(32)가 들어가도 패널 높이 396이 그대로이게 정한다.
local CELL_W = math.floor((GRID_WIDTH - CELL_GAP) / COLUMNS) - CELL_GAP
local CELL_H = 48
local PANEL_HEIGHT = 396 -- 보상 띠가 끼어 320 → 396(고정 - PRD 20.73 [4-2]) - S15에서도 그대로
local STRIP_TOP = 56 -- 범례(36 ~ 52) 아래
local STRIP_HEIGHT = 32
local STRIP_ARROW = 32
local STRIP_GAP = 4
local GRID_TOP = STRIP_TOP + STRIP_HEIGHT + CELL_GAP
local BAND_TOP = GRID_TOP + ROWS * (CELL_H + CELL_GAP) + CELL_GAP + 2 -- 그리드 아래 끝 바로 아래
local CHIP_WIDTH = math.floor((GRID_WIDTH - 2 * STRIP_ARROW - (CHIPS + 1) * STRIP_GAP) / CHIPS)
local CHIP_TEXT_SIZE = 12
local CHIP_TEXT_ROOM = CHIP_WIDTH - 6
-- S16 사전 작업: 잠긴 칩은 왼쪽에 자물쇠(HudIcons.lock - 기존 도형 아이콘)를 그리고 글은 그 오른쪽으로 민다(UIPadding 왼쪽 LOCK_PAD). 자물쇠 그림은 실효 12px 이상이 되게 캔버스 22(그려진 높이 = 캔버스 × 0.62 - 20은 픽셀 반올림으로 12.0이라 여유가 없었다).
local LOCK_ICON_SIZE = 22
local LOCK_PAD = 16
local LOCK_TEXT_ROOM = CHIP_WIDTH - LOCK_PAD - 4 -- 글 자리(칩 폭 − 자물쇠 자리 − 양쪽 여유 2)
-- S12 사전 작업 2: 화면이 패널보다 낮으면(폰 가로 388) UIManager.fitToScreen이 패널 높이를 줄이고, 제목 · 상태줄은 고정한 채 이 사이(범례 ~ 페이지 줄)가 스크롤된다.
-- 캔버스 높이는 패널이 안 줄었을 때 이 영역의 높이와 같다(그때는 스크롤이 없다). 안의 자리는 전부 offset이다(ScrollingFrame 자식의 Scale은 캔버스 기준이라 안 쓴다).
local BODY_TOP = 32 -- 제목줄 아래
local STATUS_RESERVE = 36 -- 아래 상태줄 자리
local BODY_HEIGHT = PANEL_HEIGHT - BODY_TOP - STATUS_RESERVE

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

-- S15 순수 함수(서버 · Player 없이 - 아래 자체 점검이 합성 값으로 읽는다).
-- 창의 시작 = 그 스테이지가 든 구간의 첫 스테이지(1 · 11 · 21 …) - 항상 구간에 정렬되므로 보스 칸(5의 배수)이 늘 5번째 · 10번째 자리다.
local function alignedStart(stage)
	return math.max(1, math.floor((stage - 1) / WINDOW_SIZE) * WINDOW_SIZE + 1)
end

-- 칩 묶음의 시작(1 · 51 · 101 …) - 50에 정렬한다.
local function chipGroupOf(stage)
	return math.max(1, math.floor((stage - 1) / CHIP_SPAN) * CHIP_SPAN + 1)
end

-- 구간 [first, last]의 칩 상태(PRD 20.81 [C-4]): cleared(끝 ≤ 최고 클리어 보스) → front(최전선 best + 1을 포함) → locked(첫 스테이지 > best + 1) → 그 밖(open: 일부만 깼고 최전선은 다른 구간).
local function chipState(first, last, best, bestBossCleared)
	if last <= bestBossCleared then
		return "cleared"
	elseif first <= best + 1 and best + 1 <= last then
		return "front"
	elseif first > best + 1 then
		return "locked"
	end
	return "open"
end

local CHIP_SPEC = {
	cleared = { symbol = "✓", color = UIColors.textTertiary },
	front = { symbol = "●", color = UIColors.ember },
	locked = { symbol = "", color = UIColors.lockedText, lockIcon = true }, -- 색만으로 구분하지 않는다: 자물쇠 그림이 붙는다(글자 · 그림 모두 lockedText - 명암비 4.5 이상)
	open = { symbol = "", color = UIColors.textSecondary },
}

-- 칩 글. 한 줄("● 41-50")이 room 안에 들어가면 그대로, 안 들어가면 두 줄("● 1001" / "1010"), 그래도 기호까지 안 들어가면 기호를 뗀다(그때는 색으로만 구분 - 5자리 스테이지 번호).
-- 글씨 크기는 늘 caption(12) 그대로다 - 번호를 "1234x"로 줄이지 않고 줄을 나눈다. measure(text) → 폭(px)은 부르는 쪽이 준다(TextService · 자체 점검의 가짜 자).
local function chipText(symbol, first, last, room, measure)
	local prefix = symbol ~= "" and (symbol .. " ") or ""
	local oneLine = ("%s%d-%d"):format(prefix, first, last)
	if measure(oneLine) <= room then
		return oneLine
	end
	local twoLines = ("%s%d\n%d"):format(prefix, first, last)
	if measure(twoLines) <= room then
		return twoLines
	end
	return ("%d\n%d"):format(first, last)
end

local function measureChipText(text)
	return TextService:GetTextSize(text, CHIP_TEXT_SIZE, Enum.Font.GothamBold, Vector2.new(1000, 100)).X
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StageSelectGui"
screenGui.ResetOnSpawn = false
-- S15: 열림 · 닫힘은 UIManager가 panel.Visible로 다루고(station), DisplayOrder도 열릴 때 매니저가 station 대역(10 ~ 19)에서 정한다. 닫혀 있을 때의 10은 일반 HUD(SkillSlots 등 5)보다 위라는
-- 뜻 그대로 두고, UiSelfCheck의 HUD 전수 조사(DisplayOrder 10 미만)에서 빠지게 한다.
screenGui.DisplayOrder = 10
screenGui.Parent = playerGui

-- 딤 없음(S15 - station은 걸을 수 있다. 예전의 "바깥을 눌러 닫기"는 없어졌다: 닫기 = X 버튼 · M · X/Backspace 키).
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.5, 0, 0.5, 0)
panel.Size = UDim2.new(0, PANEL_WIDTH, 0, PANEL_HEIGHT)
panel.BackgroundColor3 = UIColors.panel
panel.BackgroundTransparency = 0.08
-- Active=true - 안 그러면 셀 사이 여백(패딩)을 눌렀을 때 클릭이 패널을 그대로 통과해 뒤의 월드(공격 입력)까지 닿는다(Studio 실측으로 발견).
panel.Active = true
panel.Visible = false
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
title.Size = UDim2.new(1, -70, 0, 20)
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = UIColors.textPrimary
title.Text = "스테이지 선택"
title.Parent = panel

-- S16 사전 작업 2: 터치 영역 44 × 44(모바일 하한). 보이는 원은 예전 그대로 26 × 26이고 같은 중심에 뒤 형제로 그린다(눌리는 것은 투명한 44 × 44 버튼).
local CLOSE_TOUCH = 44
local CLOSE_DOT = 26
local CLOSE_CENTER_X = 25 -- 패널 오른쪽 끝에서 원 중심까지(12 + 26 / 2)
local CLOSE_CENTER_Y = 23 -- 패널 위에서 원 중심까지(10 + 26 / 2)
local closeDot = Instance.new("Frame")
closeDot.Name = "CloseDot"
closeDot.AnchorPoint = Vector2.new(0.5, 0.5)
closeDot.Position = UDim2.new(1, -CLOSE_CENTER_X, 0, CLOSE_CENTER_Y)
closeDot.Size = UDim2.new(0, CLOSE_DOT, 0, CLOSE_DOT)
closeDot.BackgroundColor3 = UIColors.panel
closeDot.BackgroundTransparency = UIColors.panelTransparency
closeDot.Parent = panel
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(1, 0)
closeCorner.Parent = closeDot

local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.AnchorPoint = Vector2.new(0.5, 0.5)
closeButton.Position = UDim2.new(1, -CLOSE_CENTER_X, 0, CLOSE_CENTER_Y)
closeButton.Size = UDim2.new(0, CLOSE_TOUCH, 0, CLOSE_TOUCH)
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 14
closeButton.Text = "X"
closeButton.TextColor3 = UIColors.textSecondary
closeButton.BackgroundTransparency = 1
closeButton.Parent = panel

-- 본문 스크롤 영역(제목줄과 상태줄 사이).
local body = Instance.new("ScrollingFrame")
body.Name = "Body"
body.Position = UDim2.new(0, 0, 0, BODY_TOP)
body.Size = UDim2.new(1, 0, 1, -(BODY_TOP + STATUS_RESERVE))
body.CanvasSize = UDim2.new(0, 0, 0, BODY_HEIGHT)
body.ScrollingDirection = Enum.ScrollingDirection.Y
body.ScrollBarThickness = 4
body.BackgroundTransparency = 1
body.BorderSizePixel = 0
body.Parent = panel

-- 범례 - 기호와 색을 같이 쓴다(색만으로 구분하지 않는다, 지시).
local legend = Instance.new("Frame")
legend.Position = UDim2.new(0, 16, 0, 36 - BODY_TOP)
legend.Size = UDim2.new(1, -32, 0, 16)
legend.BackgroundTransparency = 1
legend.Parent = body
local legendLayout = Instance.new("UIListLayout")
legendLayout.FillDirection = Enum.FillDirection.Horizontal
legendLayout.Padding = UDim.new(0, 14)
legendLayout.SortOrder = Enum.SortOrder.LayoutOrder
legendLayout.Parent = legend

-- ★ = 그 보스 칸에 첫 클리어 보상이 남음(gold), ✓ = 전부 받음(textTertiary - 범례에는 안 적는다).
local REWARD_SPEC = { symbol = "★", color = UIColors.gold }
local LEGEND_ORDER = { "cleared", "inProgress", "locked", "reward" }
local LEGEND_TEXT = { cleared = "클리어함", inProgress = "도전 중", locked = "진입 못 함", reward = "첫 클리어 보상 남음" }
for i, key in ipairs(LEGEND_ORDER) do
	local spec = key == "reward" and REWARD_SPEC or STATUS_SPEC[key]
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

-- 구간 띠(S15): [◀] 칩 5개 [▶]. 칩은 한 구간(10스테이지)이고 눌러서 그 구간으로 간다 - 잠긴 구간도 눌린다(다음 목표를 보는 것 - 이동 가능 여부는 서버가 판정한다).
-- ◀ ▶는 칩 묶음을 50스테이지씩 옮긴다(보고 있는 구간은 안 바뀐다). 고정 크기(AutomaticSize 없음) - 폭은 모두 offset이다.
local strip = Instance.new("Frame")
strip.Name = "SectionStrip"
strip.Position = UDim2.new(0, 12, 0, STRIP_TOP - BODY_TOP)
strip.Size = UDim2.new(0, GRID_WIDTH, 0, STRIP_HEIGHT)
strip.BackgroundTransparency = 1
strip.Parent = body

local function makeStripButton(name, x, width)
	local button = Instance.new("TextButton")
	button.Name = name
	button.AutoButtonColor = false
	button.Position = UDim2.new(0, x, 0, 0)
	button.Size = UDim2.new(0, width, 1, 0)
	button.Font = Enum.Font.GothamBold
	button.TextSize = CHIP_TEXT_SIZE
	button.TextColor3 = UIColors.textSecondary
	button.BackgroundColor3 = UIColors.slot
	button.BackgroundTransparency = UIColors.slotTransparency
	button.Text = ""
	button.Parent = strip
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Edge"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border -- TextButton의 기본(Contextual)은 글씨 외곽선이라 테두리로 안 그려진다
	stroke.Color = UIColors.rim
	stroke.Transparency = UIColors.rimTransparency
	stroke.Thickness = 1
	stroke.Parent = button
	return button, stroke
end

local chipPrevButton = makeStripButton("ChipPrev", 0, STRIP_ARROW)
chipPrevButton.Text = "◀"
local chips = {}
for i = 1, CHIPS do
	local button, stroke = makeStripButton("SectionChip" .. i, STRIP_ARROW + STRIP_GAP + (i - 1) * (CHIP_WIDTH + STRIP_GAP), CHIP_WIDTH)
	button.TextWrapped = false
	button.LineHeight = 1
	-- 잠긴 칩의 자물쇠. UIPadding은 글뿐 아니라 자식 자리의 원점도 밀므로 캔버스 x에 -LOCK_PAD를 더해 칩 왼쪽 끝에서 -1이 되게 한다(잠겼을 때만 패딩이 LOCK_PAD다). 세로는 그려진 부분(캔버스의 0.14 ~ 0.76)이 칩 세로 중앙에 온다.
	local padding = Instance.new("UIPadding")
	padding.Parent = button
	local lock = HudIcons.lock(button, LOCK_ICON_SIZE, UIColors.lockedText)
	lock.Name = "LockIcon"
	lock.Position = UDim2.new(0, -1 - LOCK_PAD, 0, math.floor(STRIP_HEIGHT / 2 - LOCK_ICON_SIZE * 0.45 + 0.5))
	lock.Visible = false
	chips[i] = { button = button, stroke = stroke, first = nil, padding = padding, lock = lock }
end
local chipNextButton = makeStripButton("ChipNext", STRIP_ARROW + STRIP_GAP + CHIPS * (CHIP_WIDTH + STRIP_GAP), STRIP_ARROW)
chipNextButton.Text = "▶"

-- 그리드 - 고정 크기 셀(UIGridLayout CellSize) 10개. AutomaticSize를 아예 안 쓴다(25-3
-- 함정 회피). 셀은 한 번만 만들고(재사용) 매번 텍스트·색만 새로 칠한다.
local gridArea = Instance.new("Frame")
gridArea.Name = "Grid"
gridArea.Position = UDim2.new(0, 12, 0, GRID_TOP - BODY_TOP)
gridArea.Size = UDim2.new(0, COLUMNS * (CELL_W + CELL_GAP) + CELL_GAP, 0, ROWS * (CELL_H + CELL_GAP) + CELL_GAP)
gridArea.BackgroundTransparency = 1
gridArea.Parent = body

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, CELL_W, 0, CELL_H)
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
	stageNumberLabel.Position = UDim2.new(0, 0, 0, 2)
	stageNumberLabel.Size = UDim2.new(1, 0, 0, 16)
	stageNumberLabel.Font = Enum.Font.Gotham
	stageNumberLabel.TextSize = 12 -- S16 사전 작업 2: 실효 12 미만 금지(예전 9.5는 정수 속성이라 9로 저장돼 있었다). UIScale 조상이 없다 → 실효 = 12
	stageNumberLabel.TextColor3 = UIColors.textSecondary -- S16 사전 작업: 칸 바탕 대비 4.5 이상(textTertiary는 2.3 - 자체 점검 [S15][UI]가 10칸을 잰다)
	stageNumberLabel.Text = ""
	stageNumberLabel.Parent = cell
	local symbolLabel = Instance.new("TextLabel")
	symbolLabel.Name = "Symbol"
	symbolLabel.BackgroundTransparency = 1
	symbolLabel.Position = UDim2.new(0, 0, 0, 18)
	symbolLabel.Size = UDim2.new(1, 0, 0, 22)
	symbolLabel.Font = Enum.Font.GothamBlack
	symbolLabel.TextSize = 18
	symbolLabel.Text = ""
	symbolLabel.Parent = cell
	-- 보스 칸 오른쪽 아래의 ★ / ✓(서버 응답이 온 뒤에만 - 12 미만 금지).
	local markLabel = Instance.new("TextLabel")
	markLabel.Name = "RewardMark"
	markLabel.BackgroundTransparency = 1
	markLabel.AnchorPoint = Vector2.new(1, 1)
	markLabel.Position = UDim2.new(1, -1, 1, -1)
	markLabel.Size = UDim2.new(0, 14, 0, 14)
	markLabel.Font = Enum.Font.GothamBold
	markLabel.TextSize = 12
	markLabel.Text = ""
	markLabel.Parent = cell
	cells[i] = { button = cell, number = stageNumberLabel, symbol = symbolLabel, stroke = stroke, mark = markLabel, stage = nil }
end

-- 페이지 이동 + 상태줄.
local pageRow = Instance.new("Frame")
pageRow.Position = UDim2.new(0, 12, 0, PANEL_HEIGHT - 68 - BODY_TOP)
pageRow.Size = UDim2.new(1, -24, 0, 26)
pageRow.BackgroundTransparency = 1
pageRow.Parent = body
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
local chipStart = 1 -- 지금 보이는 칩 묶음의 첫 스테이지(1 · 51 · 101 …) - 창이 옮겨 가면 그 창이 든 묶음으로 따라간다(◀ ▶로 묶음만 따로 넘길 수도 있다)
local selectedStage = nil -- 눌러 둔 보스 칸(띠가 이 스테이지를 보여 준다)
local preview = {} -- [스테이지] = 서버 응답의 칸(BossRewardPreview) - 열 때 · 창을 넘길 때 · 보스 처치 뒤 다시 묻는다
local codex = {} -- { [bossId] = true }
local lastPreviewAt = 0
local previewQueued = false

local band = StageRewardBand.build({
	parent = body,
	position = UDim2.new(0, 16, 0, BAND_TOP - BODY_TOP),
	width = PANEL_WIDTH - 32,
	onChallenge = function(stage)
		stageMoveRequest:FireServer(stage)
	end,
})

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
			-- 보스 칸: ★(받을 것이 남음) / ✓(전부 받음) - 서버 응답이 온 칸만. 선택된 칸은 테두리가 굵다.
			local entry = StageRewardBand.isBossStage(stage) and preview[stage] or nil
			if entry == nil then
				cell.mark.Text = ""
			elseif StageRewardBand.hasRemaining(entry) then
				cell.mark.Text = REWARD_SPEC.symbol
				cell.mark.TextColor3 = REWARD_SPEC.color
			else
				cell.mark.Text = "✓"
				cell.mark.TextColor3 = UIColors.textTertiary
			end
			-- 선택된 칸만 눈에 보이는 테두리를 준다(기존 셀의 UIStroke는 TextButton에서 글씨 외곽선 모드라 테두리로 안 그려진다 - 다른 칸의 모양은 그대로 둔다).
			local selected = stage == selectedStage
			cell.stroke.ApplyStrokeMode = selected and Enum.ApplyStrokeMode.Border or Enum.ApplyStrokeMode.Contextual
			cell.stroke.Thickness = selected and 2 or 1.5
			if selected then
				cell.stroke.Color = UIColors.textPrimary
				cell.stroke.Transparency = 0
			end
		end
	end
	prevButton.Visible = windowStart > 1
	-- 구간 칩: 상태 색 · 기호(✓ ●) + 지금 보고 있는 구간은 rimHi 테두리.
	for i, chip in ipairs(chips) do
		local first = chipStart + (i - 1) * WINDOW_SIZE
		local last = first + WINDOW_SIZE - 1
		local spec = CHIP_SPEC[chipState(first, last, best, bestBossCleared)]
		chip.first = first
		local locked = spec.lockIcon == true
		chip.padding.PaddingLeft = UDim.new(0, locked and LOCK_PAD or 0)
		chip.lock.Visible = locked
		chip.button.Text = chipText(spec.symbol, first, last, locked and LOCK_TEXT_ROOM or CHIP_TEXT_ROOM, measureChipText)
		chip.button.TextColor3 = spec.color
		local viewing = first == windowStart
		chip.stroke.Color = viewing and UIColors.rimHi or UIColors.rim
		chip.stroke.Transparency = viewing and 0 or UIColors.rimTransparency
		chip.stroke.Thickness = viewing and 2 or 1
	end
	chipPrevButton.TextTransparency = chipStart > 1 and 0 or 0.6
	band.update(selectedStage, selectedStage and preview[selectedStage] or nil, player:GetAttribute("RebirthCount") or 0, codex)
end

local function setStatus(text)
	statusLine.Text = text or ""
end

-- 지금 창 안의 보스 스테이지(최대 maxStages개 - 21칸 안에는 4 ~ 5개)를 서버에 묻는다. 요청 간격 하한(서버가 "rate"로 거절한다)보다 촘촘하지 않게 한 번으로 모아 보낸다.
local function requestPreview()
	if not isOpen or previewQueued then
		return
	end
	previewQueued = true
	local wait = math.max(0, lastPreviewAt + BossRewardPreviewData.minIntervalSeconds + 0.05 - os.clock())
	task.delay(wait, function()
		previewQueued = false
		if not isOpen then
			return
		end
		local stages = {}
		for _, cell in ipairs(cells) do
			if cell.stage and cell.stage >= 1 and StageRewardBand.isBossStage(cell.stage) and #stages < BossRewardPreviewData.maxStages then
				table.insert(stages, cell.stage)
			end
		end
		if selectedStage and not table.find(stages, selectedStage) and #stages < BossRewardPreviewData.maxStages then
			table.insert(stages, selectedStage)
		end
		if #stages == 0 then
			return
		end
		lastPreviewAt = os.clock()
		previewRequest:FireServer(stages)
	end)
end

previewResult.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	if not payload.ok then
		if payload.reason == "rate" then
			task.delay(BossRewardPreviewData.minIntervalSeconds + 0.1, requestPreview)
		end
		return
	end
	for _, entry in ipairs(payload.entries) do
		preview[entry.stage] = entry
	end
	codex = payload.codex or {}
	render()
end)

-- 보스 칸은 선택만(띠가 채워진다) - [도전]을 눌러야 이동한다. 일반 칸은 그대로 한 번에 이동.
local function selectBossStage(stage)
	selectedStage = stage
	setStatus("")
	render()
	if preview[stage] == nil then
		requestPreview()
	end
end

for _, cell in ipairs(cells) do
	cell.button.Activated:Connect(function()
		if not cell.stage then
			return
		end
		if StageRewardBand.isBossStage(cell.stage) then
			selectBossStage(cell.stage)
			return
		end
		setStatus("")
		-- 예외 4·5(비리더·X칸 클릭): 클라에서 막지 않는다 - 항상 실제 요청을 쏘고 서버
		-- 판정(reject 사유)을 그대로 보여준다.
		stageMoveRequest:FireServer(cell.stage)
	end)
end

-- 창을 옮긴 뒤(이전 · 다음 · 최전선)에는 칩 묶음도 그 창이 든 묶음으로 따라간다.
local function moveWindow(newStart)
	windowStart = math.max(1, newStart)
	chipStart = chipGroupOf(windowStart)
	render()
	requestPreview()
end

prevButton.Activated:Connect(function()
	moveWindow(windowStart - STEP)
end)

nextButton.Activated:Connect(function()
	moveWindow(windowStart + STEP)
end)

frontierButton.Activated:Connect(function()
	local _, best = attrs()
	moveWindow(alignedStart(best + 1))
end)

-- 칩: 그 구간으로(잠긴 구간도 - 이동은 서버가 판정한다). 칩 묶음은 그대로다.
for _, chip in ipairs(chips) do
	chip.button.Activated:Connect(function()
		if not chip.first then
			return
		end
		windowStart = chip.first
		render()
		requestPreview()
	end)
end

-- ◀ ▶: 칩 묶음만 50스테이지씩(보고 있는 구간은 안 바뀐다).
chipPrevButton.Activated:Connect(function()
	chipStart = math.max(1, chipStart - CHIP_SPAN)
	render()
end)

chipNextButton.Activated:Connect(function()
	chipStart += CHIP_SPAN
	render()
end)

-- 열기 · 닫기는 UIManager가 부른다(station "stageSelect" - 단축키 M은 ui/PanelRegistry, 닫기 = X 버튼 · M · X/Backspace). 견습 중에는 canOpen이 막는다(칩 · M 키 둘 다) -
-- 견습은 선형 진행이라 "목록에서 고른다"가 안 맞는다(TutorialHud와 같은 판정).
local function isTutorialActive()
	return player:GetAttribute("TutorialCompleted") ~= true and (player:GetAttribute("TutorialStep") or 0) > 0
end

local function onOpen()
	local _, best = attrs()
	windowStart = alignedStart(best + 1)
	chipStart = chipGroupOf(windowStart)
	isOpen = true
	selectedStage = nil
	UIManager.fitToScreen(panel, screenGui)
	body.CanvasPosition = Vector2.new(0, 0)
	setStatus("")
	render()
	requestPreview()
end

local function onClose()
	isOpen = false
end

UIManager.register("stageSelect", {
	kind = "station",
	screenGui = screenGui,
	frame = panel,
	hasCloseButton = true,
	canOpen = function()
		return not isTutorialActive()
	end,
	onOpen = onOpen,
	onClose = onClose,
})
closeButton.Activated:Connect(function()
	UIManager.close("stageSelect")
end)

-- 칩 · 자체 점검(ui/PanelFitCheck)이 부르는 옛 이름 그대로 - 안에서는 UIManager로 간다.
function StageSelectPanel.open()
	return UIManager.open("stageSelect")
end

function StageSelectPanel.close()
	UIManager.close("stageSelect", true)
end

-- 예외 3(목록을 연 채로 스테이지가 바뀔 때, 파티 투표 이동 포함): 세 Attribute를 구독해
-- 열려 있는 동안은 그 자리에서 다시 그린다(windowStart는 유지 - 보던 자리를 안 바꾼다).
for _, attr in ipairs({ "InfiniteStage", "InfiniteStageBest", "BestBossCleared", "RebirthCount" }) do
	player:GetAttributeChangedSignal(attr):Connect(render)
end
-- 보스를 잡았거나(BestBossCleared) 직업이 바뀌면(ClassId - 장비 수령 기록이 직업별) 열려 있는 동안 다시 묻는다.
for _, attr in ipairs({ "BestBossCleared", "ClassId" }) do
	player:GetAttributeChangedSignal(attr):Connect(requestPreview)
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

-- Studio 자체 점검: 띠의 문자열 생성(순수 함수)을 합성 응답으로 읽는다(DevToolsConfig.verify에 S11(가)가 있을 때만). 서버 없이 클라만으로 도는 (가)다.
if RunService:IsStudio() and (DevToolsConfig.verify.regression or table.find(DevToolsConfig.verify.current, "S11(가)")) then
	task.delay(10, function()
		print("===S11 검증 시작(UI: 보상 띠 문자열 자체 점검)===")
		local pass, total = 0, 0
		local ok, err = pcall(StageRewardBand.selfTest, function(label, passed)
			total += 1
			if passed then
				pass += 1
			end
			print(("[S11][UI] %s %s"):format(label, passed and "O" or "X"))
		end)
		if not ok then
			total += 1
			print(("[S11][UI] 자체 점검 실행 중 에러: %s X"):format(tostring(err)))
		end
		print(("===S11 검증 끝(UI)=== %d/%d 통과"):format(pass, total))
	end)
end

-- 자체 점검(ui/StageSelectCheck.client.lua)이 읽는 내부(Studio 점검 전용 - 판정 · 그리기에는 안 쓴다).
StageSelectPanel.debug = {
	alignedStart = alignedStart,
	chipGroupOf = chipGroupOf,
	chipState = chipState,
	chipText = chipText,
	measureChipText = measureChipText,
	chipTextRoom = CHIP_TEXT_ROOM,
	lockTextRoom = LOCK_TEXT_ROOM,
	chipTextSize = CHIP_TEXT_SIZE,
	cells = cells,
	chips = chips,
	panel = panel,
	closeButton = closeButton,
	closeDot = closeDot,
	chipPrevButton = chipPrevButton,
	chipNextButton = chipNextButton,
	getWindow = function()
		return windowStart, chipStart
	end,
	-- 열려 있는 패널을 그 창으로 다시 그린다(창 · 칩 묶음 시작을 직접 정한다).
	showWindow = function(start)
		windowStart = start
		chipStart = chipGroupOf(start)
		render()
	end,
}

return StageSelectPanel
