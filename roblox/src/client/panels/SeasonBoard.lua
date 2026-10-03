-- QUEUE-ALL9B 5 시즌 출석판 창(기본 창 - 디자인 다듬기 = ALL9C). 데이터 = 서버 QuestUpdate의 board(QuestService.view) · 받기 = QuestRequest("claim", "board", 칸) / ("claim", "boardBonus").
--   5-4 접속 창 순서: 하루 첫 접속 = 일일 접속 보상 창(panels/Attendance) → 닫으면 이 창(받을 것이 있을 때만 · 이미 받았으면 안 뜸). 접속 창이 안 뜨는 날은 이 창만 자동으로.
--   다른 입구 = 상점 [시즌] 탭 "시즌 출석판" 줄. 칸: 일차 번호 · 받은 칸 = 체크 + 흐리게 · 오늘 칸 = 금 테 · 앞으로 받을 칸 = 보상 미리보기 · 위 = "32칸 중 N칸 받음" 막대.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SeasonBoardData = require(ReplicatedStorage.Shared.data.SeasonBoardData)
local Text = require(ReplicatedStorage.Shared.Text)
local Panel = require(script.Parent.Parent.ui.kit.Panel)
local Button = require(script.Parent.Parent.ui.kit.Button)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local RewardIcons = require(script.Parent.Parent.ui.RewardIcons)
local UIManager = require(script.Parent.Parent.UIManager)

local SeasonBoard = {}
SeasonBoard.id = "seasonBoard"

local player = Players.LocalPlayer
local PANEL_SIZE = Vector2.new(760, 430)
local COLS = 8
local requestRemote = ReplicatedStorage:WaitForChild("QuestRequest")
local updateRemote = ReplicatedStorage:WaitForChild("QuestUpdate")

local built, view
local autoShown = false

local function build()
	local panel = Panel.create({ id = SeasonBoard.id, kind = "window", title = Text.get("board.seasonTitle"), size = PANEL_SIZE, onOpen = function()
		task.defer(SeasonBoard.render)
	end })
	local progress = Theme.label(panel.content, "", "body", "textPrimary")
	progress.Name = "Progress"
	progress.Position = UDim2.fromOffset(12, 6)
	progress.Size = UDim2.new(1, -24, 0, 22)
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Position = UDim2.fromOffset(12, 30)
	bar.Size = UDim2.new(1, -24, 0, 8)
	bar.BackgroundColor3 = Theme.color("slot")
	bar.Parent = panel.content
	Theme.corner(bar, 4)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Theme.color("gold")
	fill.Parent = bar
	Theme.corner(fill, 4)
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Cells"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.Position = UDim2.fromOffset(12, 46)
	grid.Size = UDim2.new(1, -24, 1, -46 - 70)
	grid.ScrollBarThickness = 6
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.Parent = panel.content
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(1 / COLS, -6, 0, 70)
	layout.CellPadding = UDim2.fromOffset(6, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	local claim = Button.build({ parent = panel.content, kind = "claim", width = 240, height = Theme.isMobile and 60 or 48, text = Text.get("board.claim"),
		position = UDim2.new(0.5, 0, 1, -24), anchorPoint = Vector2.new(0.5, 1), onActivated = function()
			local b = view and view.board
			if not b or not b.todayKind then
				return
			end
			if b.todayKind == "cell" then
				requestRemote:FireServer("claim", "board", tostring(b.todayCell))
			else
				requestRemote:FireServer("claim", "boardBonus")
			end
		end })
	claim.root.Name = "BoardClaim"
	local nextLine = Theme.label(panel.content, "", "caption", "textSecondary")
	nextLine.Name = "NextReset"
	nextLine.TextXAlignment = Enum.TextXAlignment.Center
	nextLine.Position = UDim2.new(0, 12, 1, -20)
	nextLine.Size = UDim2.new(1, -24, 0, 18)
	built = { panel = panel, progress = progress, fill = fill, grid = grid, claim = claim, nextLine = nextLine, cells = {} }
end

-- 칸 하나(일차 · 보상 그림 · 받음 체크). 반환 = 칸 Frame(받기 연출이 찾는다 - 이름 Cell<n>)
function SeasonBoard.cellFrame(n)
	return built and built.cells[n]
end

function SeasonBoard.render()
	local b = view and view.board
	if not built or not b then
		return
	end
	for _, c in ipairs(built.grid:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	built.cells = {}
	local claimedCount = 0
	for n, reward in ipairs(SeasonBoardData.cells) do
		local key = tostring(n)
		local claimed = b.claimed[key] == true
		claimedCount += claimed and 1 or 0
		local today = b.todayKind == "cell" and b.todayCell == n
		local cell = Instance.new("Frame")
		cell.Name = "Cell" .. key
		cell.LayoutOrder = n
		cell.BackgroundColor3 = Theme.color("slot")
		cell.BackgroundTransparency = claimed and 0.6 or 0.15
		cell.Parent = built.grid
		Theme.corner(cell, 8)
		local stroke = Theme.stroke(cell)
		stroke.Color = today and Theme.color("gold") or Theme.color("rim")
		stroke.Thickness = today and 3 or 1
		local day = Theme.label(cell, Text.get("board.dayShort", { day = key }), "caption", claimed and "textSecondary" or "textPrimary")
		day.Name = "Day"
		day.Size = UDim2.new(1, 0, 0, 18)
		day.TextXAlignment = Enum.TextXAlignment.Center
		local icons = RewardIcons.row(cell, reward, 26, { frameSize = UDim2.new(1, -6, 0, 44), position = UDim2.fromOffset(3, 20) })
		icons.Name = "Rewards"
		if claimed then
			local check = Theme.label(cell, "✓", "title", "success")
			check.Name = "ClaimedCheck"
			check.TextXAlignment = Enum.TextXAlignment.Right
			check.Position = UDim2.new(1, -22, 0, -2)
			check.Size = UDim2.fromOffset(20, 22)
		end
		built.cells[n] = cell
	end
	built.progress.Text = Text.get("board.progress", { total = tostring(#SeasonBoardData.cells), n = tostring(claimedCount) })
	built.fill.Size = UDim2.fromScale(claimedCount / #SeasonBoardData.cells, 1)
	local text
	if b.todayKind == "cell" then
		text = Text.get("board.claim")
	elseif b.todayKind == "bonus" then
		text = Text.get("board.bonus", { n = tostring(SeasonBoardData.after.sparkleShard or 0) })
	else
		text = Text.get("board.done")
	end
	built.claim.setText(text)
	built.claim.setEnabled(b.todayKind ~= nil)
	local left = math.max(0, b.resetIn or 0)
	built.nextLine.Text = Text.get("board.next", { h = tostring(math.floor(left / 3600)), m = tostring(math.floor(left % 3600 / 60)) })
end

function SeasonBoard.open()
	UIManager.open(SeasonBoard.id)
end

-- 5-4 접속 창 순서: 일일 접속 보상 창이 닫힐 때(panels/Attendance) · 그 창이 안 뜨는 날의 자동 1회
function SeasonBoard.openIfReady()
	local b = view and view.board
	if b and b.todayKind and player:GetAttribute("TutorialCompleted") == true and not UIManager.isOpen(SeasonBoard.id) then
		autoShown = true
		UIManager.open(SeasonBoard.id)
		return true
	end
	return false
end

function SeasonBoard.init(attendanceWillShow)
	build()
	updateRemote.OnClientEvent:Connect(function(v)
		view = v
		if UIManager.isOpen(SeasonBoard.id) then
			SeasonBoard.render()
		end
		if not autoShown and v and v.board and v.board.todayKind and player:GetAttribute("TutorialCompleted") == true and not attendanceWillShow(v) then
			autoShown = true
			task.delay(2.5, function()
				if #UIManager.getStack() == 0 then
					UIManager.open(SeasonBoard.id)
				end
			end)
		end
	end)
end

return SeasonBoard
