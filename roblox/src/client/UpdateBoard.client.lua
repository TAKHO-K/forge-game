-- QUEUE-ALL1 P4 §2 허브 업데이트 게시판(새 소식 + 지금 쓸 수 있는 코드 - 만료 지난 코드는 안 보인다) · §3 주간 도전 버튼 · 순위 창 · P4 알림 토스트.
--   게시판 = 마을 게시판 메시 판면(ALL8 C4 - 아트 끔이면 자리 위 빌보드) · 누르면 전체 창 · 주간 도전 = 합동 목표 알약 오른쪽 버튼 → 창(이번 주 보스 · 변형 · [도전] · 순위 top). 수치 · 문구 = SocialRewardData · WeeklyChallengeData.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SD = require(ReplicatedStorage.Shared.data.SocialRewardData)
local WD = require(ReplicatedStorage.Shared.data.WeeklyChallengeData)
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local Theme = require(script.Parent.ui.kit.Theme)
local Toast = require(script.Parent.ui.kit.Toast)
local Text = require(ReplicatedStorage.Shared.Text)

local player = Players.LocalPlayer
local INK = Color3.fromRGB(30, 27, 46)
local GOLD = Color3.fromRGB(255, 214, 90)

local gui = Instance.new("ScreenGui")
gui.Name = "UpdateBoardGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 19
gui.Parent = player:WaitForChild("PlayerGui")

local function label(parent, text, size, color, font)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = font or Theme.fontBody
	l.TextSize = size
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.Text = text
	l.Parent = parent
	return l
end

-- 게시판
local boardCodes = nil -- SEC-FIX-1 4: 코드 표는 서버 전용(server/SocialCodeData) - 게시판에 보일 공개 코드만 서버에서 받는다(처음 그릴 때 한 번)
local function fetchBoardCodes()
	if boardCodes == nil then
		local remote = ReplicatedStorage:WaitForChild("BoardCodes", 10)
		local ok, list = false, nil
		if remote then
			ok, list = pcall(remote.InvokeServer, remote)
		end
		if not (ok and type(list) == "table") then
			return {} -- 실패 = 이번엔 코드 줄 없이(다음에 다시 받음)
		end
		boardCodes = list
	end
	return boardCodes
end
local function validCodes()
	local out = {}
	for _, c in ipairs(fetchBoardCodes()) do
		local e = c.expires
		-- QUEUE-ALL5 C: 만료 = UTC 그날 끝(서버 SocialRewardService와 같은 뜻) - 클라의 os.time(표)는 기기 시간대로 읽힐 수 있어 UTC로 명시
		if not c.hidden and not c.inactive and os.time() <= DateTime.fromUniversalTime(e[1], e[2], e[3], 23, 59, 59).UnixTimestamp then
			table.insert(out, Text.get("update.board.codeLine", { code = c.code, note = c.noteKey and Text.get(c.noteKey) or (c.note or ""), date = ("%d.%d.%d"):format(e[1], e[2], e[3]) }))
		end
	end
	return out
end
-- QUEUE-ALL7B 2: 소식 · 코드 = 마을 게시판 자리(HubServiceData noticeBoard - 누르면 코드 입력 탭 · 스트리밍으로 다시 들어오면 Adornee만 바꾼다)
local function buildBoard(adornee)
	local old = gui:FindFirstChild("UpdateBoard")
	if old then
		old.Adornee = adornee
		return
	end
	local b = Instance.new("BillboardGui")
	b.Name = "UpdateBoard"
	b.Size = UDim2.fromOffset(300, 170)
	b.StudsOffsetWorldSpace = Vector3.new(0, 20, 0) -- QUEUE-ALL7B 2: 게시판 자리 기둥의 이름표 · 기능 아이콘 위
	b.MaxDistance = 80
	b.Adornee = adornee
	b.Parent = gui
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = INK
	bg.BackgroundTransparency = 0.15
	bg.Parent = b
	Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 10)
	local y = 6
	local t = label(bg, Text.get("update.board.title"), 16, GOLD, Theme.font)
	t.Position, t.Size = UDim2.fromOffset(10, y), UDim2.new(1, -20, 0, 20)
	y += 22
	for _, n in ipairs(SD.news) do
		local l = label(bg, Text.get("update.board.newsLine", { date = n.date, text = Text.get(n.textKey) }), 12)
		l.Position, l.Size = UDim2.fromOffset(10, y), UDim2.new(1, -20, 0, 30)
		y += 30
	end
	local c = label(bg, Text.get("update.board.codes"), 14, GOLD, Theme.font)
	c.Position, c.Size = UDim2.fromOffset(10, y), UDim2.new(1, -20, 0, 18)
	y += 18
	for _, s in ipairs(validCodes()) do
		local l = label(bg, s, 12, Color3.fromRGB(220, 230, 255))
		l.Position, l.Size = UDim2.fromOffset(10, y), UDim2.new(1, -20, 0, 16)
		y += 16
	end
end
-- QUEUE-ALL8 C4: 아트 켬 = 마을 게시판 메시(HubArt HubProp_board.Board) 판면에 SurfaceGui(maxLines줄 · 넘으면 "더 보기") → 위 빌보드는 지운다.
--   판면 방향 = 종이(Papers) 쪽 면(가져온 메시 축을 가정하지 않는다) · 종이 조각은 소식이 대신하므로 이 화면에서만 숨긴다. 누르면 전체 창(아래).
local LB = require(ReplicatedStorage.Shared.data.HubLabelData).board
local function boardRows()
	local rows = {}
	for _, n in ipairs(SD.news) do
		table.insert(rows, { text = Text.get("update.board.newsLine", { date = n.date, text = Text.get(n.textKey) }) })
	end
	for _, s in ipairs(validCodes()) do
		table.insert(rows, { text = s, color = Color3.fromRGB(220, 230, 255) })
	end
	return rows
end
local function buildFace(board)
	local papers = board.Parent:FindFirstChild("Papers")
	local face, best = Enum.NormalId.Front, -2
	if papers then
		local dir = (papers.Position - board.Position).Unit
		for _, id in ipairs(Enum.NormalId:GetEnumItems()) do
			local d = board.CFrame:VectorToWorldSpace(Vector3.FromNormalId(id)):Dot(dir)
			if d > best then
				face, best = id, d
			end
		end
		papers.LocalTransparencyModifier = 1
	end
	local old = gui:FindFirstChild("UpdateBoard")
	if old then
		old:Destroy()
	end
	local sg = gui:FindFirstChild("UpdateBoardFace") or Instance.new("SurfaceGui")
	sg.Name = "UpdateBoardFace"
	sg:ClearAllChildren()
	sg.Adornee = board
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = LB.pixelsPerStud
	sg.LightInfluence = 0
	sg.MaxDistance = 80
	sg.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop = UDim.new(0, 14), UDim.new(0, 14), UDim.new(0, 10)
	pad.Parent = sg
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 4)
	list.Parent = sg
	local function row(text, size, color, font, order)
		local l = label(sg, text, size, color or INK, font)
		l.TextStrokeTransparency = 1
		l.Size = UDim2.new(1, 0, 0, 0)
		l.AutomaticSize = Enum.AutomaticSize.Y
		l.LayoutOrder = order
		return l
	end
	row(Text.get("update.board.title"), LB.titleSize, Color3.fromRGB(120, 60, 20), Theme.font, 0)
	local rows = boardRows()
	local n = #rows > LB.maxLines and LB.maxLines - 1 or #rows
	for i = 1, n do
		row(rows[i].text, LB.lineSize, Color3.fromRGB(40, 30, 24), nil, i)
	end
	if #rows > LB.maxLines then
		row(Text.get("update.board.more"), LB.lineSize, Color3.fromRGB(150, 70, 20), Theme.font, LB.maxLines)
	end
end

-- 누르면(마을 게시판 프롬프트 - HubServiceData panel "board") 전체 소식 · 코드 창 + [코드 입력](설정 창 게임 탭 코드 칸)
--   QUEUE-ALL9A 3-2: 다른 창과 같은 창 관리자(Panel.create → UIManager) - 닫기 키(X · Backspace) · 폰에서 열면 전투 버튼 숨김 · 스택이 같다
local BOARD_ID = "updateBoard"
local built
local function openFull()
	local UIManager = require(script.Parent.UIManager)
	if built then
		UIManager.open(BOARD_ID)
		return
	end
	local Panel = require(script.Parent.ui.kit.Panel)
	local panel = Panel.create({ id = BOARD_ID, kind = "window", title = Text.get("update.board.title"), size = Vector2.new(400, 380) })
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "UpdateBoardFull"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(12, 8)
	scroll.Size = UDim2.new(1, -24, 1, -60)
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 4
	scroll.Parent = panel.content
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 6)
	list.Parent = scroll
	local order = 0
	local function row(text, size, color, font)
		order += 1
		local l = label(scroll, text, size, color, font)
		l.Size = UDim2.new(1, -6, 0, 0)
		l.AutomaticSize = Enum.AutomaticSize.Y
		l.LayoutOrder = order
	end
	for _, n in ipairs(SD.news) do
		row(Text.get("update.board.newsLine", { date = n.date, text = Text.get(n.textKey) }), 14)
	end
	row(Text.get("update.board.codes"), 15, GOLD, Theme.font)
	for _, s in ipairs(validCodes()) do
		row(s, 14, Color3.fromRGB(220, 230, 255))
	end
	local Button = require(script.Parent.ui.kit.Button)
	Button.build({ parent = panel.content, name = "UpdateBoardCode", kind = "primary", width = 120, anchorPoint = Vector2.new(0, 1), position = UDim2.new(0, 12, 1, -10), text = Text.get("update.board.enterCode"),
		onActivated = function()
			UIManager.close(BOARD_ID, true)
			require(script.Parent.panels.Settings).open("game")
		end })
	Button.build({ parent = panel.content, name = "UpdateBoardClose", kind = "secondary", width = 90, anchorPoint = Vector2.new(1, 1), position = UDim2.new(1, -12, 1, -10), text = Text.get("update.board.close"),
		onActivated = function()
			UIManager.close(BOARD_ID)
		end })
	built = panel
	UIManager.open(BOARD_ID)
end
game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt, who)
	if who == player and prompt:GetAttribute("HubService") == "noticeBoard" then
		openFull()
	end
end)

local function considerSpot(d)
	if d:IsA("BasePart") and d:GetAttribute("Spot") == "noticeBoard" then
		if not gui:FindFirstChild("UpdateBoardFace") then -- 아트 끔(메시 없음) = 옛 빌보드
			buildBoard(d)
		end
	elseif d:IsA("BasePart") and d.Name == "Board" and d.Parent and d.Parent.Name == "HubProp_board" then
		task.defer(buildFace, d) -- 종이 조각이 같이 들어온 뒤
	end
end
for _, d in ipairs(Workspace:GetDescendants()) do
	considerSpot(d)
end
Workspace.DescendantAdded:Connect(considerSpot)

-- 주간 도전 버튼 + 창
local btn = Instance.new("TextButton")
btn.Name = "WeeklyChallengeButton"
btn.AnchorPoint = Vector2.new(0, 0)
btn.Position = UDim2.new(0.5, 110, 0, 36)
btn.Size = UDim2.fromOffset(96, 24)
btn.BackgroundColor3 = Color3.fromRGB(90, 40, 60)
btn.TextColor3 = Color3.new(1, 1, 1)
btn.Font = Theme.font
btn.TextSize = 13
btn.Text = Text.name(WD.text.button)
btn.Parent = gui
btn.Visible = false -- QUEUE-ALL3 Q3 중복 삭제: 주간 도전 = 퀘스트 창(J) [주간 도전] 탭
Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
local panel = Instance.new("Frame")
panel.Name = "WeeklyChallengePanel"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 66)
panel.Size = UDim2.fromOffset(320, 110 + WD.topShown * 20)
panel.BackgroundColor3 = INK
panel.BackgroundTransparency = 0.08
panel.Visible = false
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
local head = label(panel, "", 15, GOLD, Theme.font)
head.Position, head.Size = UDim2.fromOffset(12, 8), UDim2.new(1, -110, 0, 40)
local go = Instance.new("TextButton")
go.Name = "WeeklyStart"
go.Position = UDim2.new(1, -92, 0, 12)
go.Size = UDim2.fromOffset(80, 30)
go.BackgroundColor3 = Color3.fromRGB(200, 70, 90)
go.TextColor3 = Color3.new(1, 1, 1)
go.Font = Theme.font
go.TextSize = 14
go.Text = Text.name(WD.text.start)
go.Parent = panel
Instance.new("UICorner", go).CornerRadius = UDim.new(0, 8)
local rankTitle = label(panel, Text.name(WD.text.rank), 13, Color3.fromRGB(200, 200, 214))
rankTitle.Position, rankTitle.Size = UDim2.fromOffset(12, 54), UDim2.new(1, -24, 0, 18)
local rankRows = {}
for i = 1, WD.topShown do
	local l = label(panel, "", 13)
	l.Position, l.Size = UDim2.fromOffset(16, 74 + (i - 1) * 20), UDim2.new(1, -32, 0, 18)
	rankRows[i] = l
end
local mine = label(panel, "", 12, GOLD)
mine.Position, mine.Size = UDim2.new(0, 12, 1, -24), UDim2.new(1, -24, 0, 18)

local function refreshPanel()
	local bossId = Workspace:GetAttribute("WeeklyChallengeBoss")
	local b = bossId and BossData.bosses[bossId]
	head.Text = Text.get("scene.weekly.head", { boss = b and b.displayName or "?", label = tostring(Workspace:GetAttribute("WeeklyChallengeLabel") or ""), stage = ("%d"):format(WD.stage) })
	local ok, r = pcall(function()
		return ReplicatedStorage:WaitForChild("WeeklyChallengeTop"):InvokeServer()
	end)
	for i, l in ipairs(rankRows) do
		local row = ok and type(r) == "table" and r.rows and r.rows[i]
		l.Text = row and Text.get("scene.weekly.row", { rank = ("%d"):format(row.rank), name = tostring(row.name), seconds = ("%.1f"):format(row.seconds) }) or (i == 1 and Text.name(WD.text.none) or "")
	end
	mine.Text = (ok and type(r) == "table" and r.myBest) and Text.get("scene.weekly.mine", { seconds = ("%.1f"):format(r.myBest) }) or ""
end
btn.Activated:Connect(function()
	panel.Visible = not panel.Visible
	if panel.Visible then
		task.spawn(refreshPanel)
	end
end)
go.Activated:Connect(function()
	ReplicatedStorage:WaitForChild("WeeklyChallengeStart"):FireServer()
	panel.Visible = false
end)

-- P4 알림(초대 보상 · 주간 도전)
local function toast(text)
	if type(text) == "string" then
		Toast.push("TC", { richParts = { { text = text, color = GOLD, bold = true } }, seconds = 4, fadeSeconds = 0.3 })
	end
end
ReplicatedStorage:WaitForChild("SocialRewardNotice").OnClientEvent:Connect(toast)
ReplicatedStorage:WaitForChild("WeeklyChallengeNotice").OnClientEvent:Connect(toast)
