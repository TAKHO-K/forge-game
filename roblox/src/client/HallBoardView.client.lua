-- UI-1c 3단계 마을 게시판 겉면(I v1 §1-1 · sheet_02): 서버가 세운 workspace.HallBoard.Board 앞면에 SurfaceGui 1200 × 800(PixelsPerStud 50 · LightInfluence 0 · AlwaysOnTop 끔).
--   같은 데이터 = 창과 같은 LeaderboardRequest "board"(전체 = 역대 최고 스테이지) · 같은 단상 함수(HallOfFameV1.podium) · 겉면엔 탭 · 내 줄 없음.
--   갱신 = refreshSeconds마다 · 새 내용을 다 지은 뒤 옛 것을 지움(깜빡임 없이 바꿔 끼움) · [E] = 마을 기능 프롬프트(HubServicePrompt · hallOfFame)라 창 열기가 같은 함수.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

if not require(ReplicatedStorage.Shared.data.UiV2Flags).hall then
	return
end

local Text = require(ReplicatedStorage.Shared.Text)
local L = require(ReplicatedStorage.Shared.data.UiLayoutData).hall
local HubServiceData = require(ReplicatedStorage.Shared.data.HubServiceData)
local Hall = require(script.Parent.panels.HallOfFameV1)
local ArtImage = require(script.Parent.ui.ArtImage)

local B = L.board
local C = L.colors
local player = Players.LocalPlayer
local request = ReplicatedStorage:WaitForChild("LeaderboardRequest")

local model = Workspace:WaitForChild("HallBoard", 120)
local part = model and model:WaitForChild("Board", 30)
if not part then
	return
end

local gui = Instance.new("SurfaceGui")
gui.Name = "HallBoardGui"
gui.Face = Enum.NormalId.Front
gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
gui.CanvasSize = Vector2.new(B.canvas[1], B.canvas[2])
gui.LightInfluence = 0
gui.AlwaysOnTop = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.ResetOnSpawn = false
gui.Adornee = part
gui.Parent = player:WaitForChild("PlayerGui")

-- [E] 프롬프트 = 마을 기능 프롬프트와 같은 이름 · 속성(HubServices가 받아 Leaderboard.open)
local service
for _, s in ipairs(HubServiceData.services) do
	if s.id == "hallOfFame" then
		service = s
	end
end
local prompt = Instance.new("ProximityPrompt")
prompt.Name = "HubServicePrompt"
prompt:SetAttribute("HubService", "hallOfFame")
prompt.KeyboardKeyCode = Enum.KeyCode.E
prompt.HoldDuration = 0
prompt.RequiresLineOfSight = false
prompt.MaxActivationDistance = B.promptDistance
local function relabel()
	prompt.ObjectText = service and Text.get(service.nameKey) or ""
	prompt.ActionText = service and Text.get(service.actionKey) or ""
end
relabel()
player:GetAttributeChangedSignal(Text.languageAttribute):Connect(relabel)
prompt.Parent = part

local content = nil
local function px(n)
	return n -- 겉면 = 캔버스 px 그대로(글자 설정 배율 안 탐 - 모두에게 같은 게시판)
end

local function draw(r)
	local root = Instance.new("Frame")
	root.Name = "Content"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Color3.fromHex(B.wood)
	root.BorderSizePixel = 0
	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.BackgroundColor3 = Color3.fromHex(C.window)
	inner.BorderSizePixel = 0
	inner.Position = UDim2.fromOffset(B.frameWood, B.frameWood)
	inner.Size = UDim2.new(1, -2 * B.frameWood, 1, -2 * B.frameWood)
	inner.Parent = root
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromHex(B.goldLine)
	st.Thickness = B.frameGold
	st.Parent = inner
	local W = B.canvas[1] - 2 * B.frameWood
	-- 머리: 왕관 + "명예의 전당" 40 + 시즌 알약
	local head = Instance.new("Frame")
	head.Name = "Head"
	head.BackgroundColor3 = Color3.fromHex("4A3412")
	head.BorderSizePixel = 0
	head.Size = UDim2.new(1, 0, 0, B.head)
	head.Parent = inner
	local hl = Instance.new("UIListLayout")
	hl.FillDirection = Enum.FillDirection.Horizontal
	hl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	hl.VerticalAlignment = Enum.VerticalAlignment.Center
	hl.Padding = UDim.new(0, 16)
	hl.SortOrder = Enum.SortOrder.LayoutOrder
	hl.Parent = head
	local crown = ArtImage.label(head, "ui/v9/rank-crown", UDim2.fromOffset(52, 40), "♛")
	crown.LayoutOrder = 1
	local t = Hall.label(head, Text.get("ui1c.hall.title"), 40, "FFD45A", { name = "Title", font = "korean" })
	t.AutomaticSize = Enum.AutomaticSize.X
	t.Size = UDim2.fromOffset(0, B.head)
	t.TextTruncate = Enum.TextTruncate.None
	t.LayoutOrder = 2
	local season = Hall.seasonText(r and r.season)
	if season then
		local pill = Instance.new("TextLabel")
		pill.Name = "Season"
		pill.LayoutOrder = 3
		pill.BackgroundColor3 = Color3.fromHex(C.pill)
		pill.AutomaticSize = Enum.AutomaticSize.X
		pill.Size = UDim2.fromOffset(0, 44)
		pill.Font = Enum.Font.GothamBold
		pill.TextSize = 22
		pill.TextColor3 = Color3.new(1, 1, 1)
		pill.Text = "   " .. season .. "   "
		pill.Parent = head
		local pc = Instance.new("UICorner")
		pc.CornerRadius = UDim.new(1, 0)
		pc.Parent = pill
	end
	local gl = Instance.new("Frame")
	gl.BackgroundColor3 = Color3.fromHex(B.goldLine)
	gl.BorderSizePixel = 0
	gl.Position = UDim2.fromOffset(0, B.head)
	gl.Size = UDim2.new(1, 0, 0, 4)
	gl.Parent = inner
	local entries = r and r.entries or {}
	local names = r and r.names or {}
	-- 왼쪽 단상(창과 같은 부품 · 같은 비율)
	local pr = B.podium
	Hall.podium(inner, { pr[1] - B.frameWood, pr[2] - B.frameWood, pr[3], pr[4] }, entries, names,
		{ width = pr[3] - 20, block = 0.86, heights = { 0.5, 0.4, 0.35 }, avatar = { 170, 150, 150 }, crown = 52, name = 26, small = 18, value = 28, rank = 64, rankT = 0.65, avatarStroke = 6 }, px)
	-- 오른쪽 4 ~ 10등
	local lr = B.list
	local list = Instance.new("Frame")
	list.Name = "List"
	list.BackgroundColor3 = Color3.fromHex(C.row)
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(lr[1] - B.frameWood, lr[2] - B.frameWood)
	list.Size = UDim2.fromOffset(lr[3], lr[4])
	list.Parent = inner
	local lc = Instance.new("UICorner")
	lc.CornerRadius = UDim.new(0, 12)
	lc.Parent = list
	Hall.label(list, Text.get("ui1c.hall.board.range"), 22, "FFD45A", { rect = { 16, 8, 200, 36 } })
	Hall.label(list, Text.get("ui1c.hall.basis.stage"), 18, C.muted, { align = Enum.TextXAlignment.Right, rect = { lr[3] - 216, 8, 200, 36 } })
	for i = 4, math.min(#entries, 3 + B.rows) do
		local e = entries[i]
		local y = 48 + (i - 4) * B.rowH
		local id = e.userId or (e.members and e.members[1])
		local nm = names[tostring(id)] or ("#" .. tostring(id))
		Hall.label(list, tostring(e.rank), B.rowNum, "FFFFFF", { font = "number", align = Enum.TextXAlignment.Center, rect = { 8, y, 44, B.rowH } })
		local av = Hall.avatar(list, id, nm, 38)
		av.Position = UDim2.fromOffset(60, y + (B.rowH - 38) / 2)
		Hall.label(list, nm, B.rowText, "FFFFFF", { rect = { 110, y, 280, B.rowH } })
		Hall.label(list, Hall.valueOf(e), B.rowNum, "FFFFFF", { font = "number", align = Enum.TextXAlignment.Right, rect = { lr[3] - 136, y, 120, B.rowH } })
		local line = Instance.new("Frame")
		line.BackgroundColor3 = Color3.fromHex(C.rowLine)
		line.BorderSizePixel = 0
		line.Position = UDim2.fromOffset(8, y + B.rowH - 1)
		line.Size = UDim2.fromOffset(lr[3] - 16, 1)
		line.Parent = list
	end
	if #entries == 0 then
		Hall.label(list, Text.get("ui1c.hall.board.empty"), 24, C.muted, { align = Enum.TextXAlignment.Center, rect = { 0, 200, lr[3], 60 } })
	end
	local hint = Instance.new("Frame")
	hint.Name = "Hint"
	hint.BackgroundTransparency = 1
	hint.Position = UDim2.fromOffset(16, lr[4] - 76)
	hint.Size = UDim2.fromOffset(lr[3] - 32, 60)
	hint.Parent = list
	local hs = Instance.new("UIStroke")
	hs.Color = Color3.fromHex(B.goldLine)
	hs.Thickness = 2
	hs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	hs.Parent = hint
	local hc = Instance.new("UICorner")
	hc.CornerRadius = UDim.new(0, 10)
	hc.Parent = hint
	Hall.label(hint, "[E]  " .. Text.get("ui1c.hall.board.prompt"), 22, "FFD45A", { align = Enum.TextXAlignment.Center, rect = { 0, 0, lr[3] - 32, 60 } })
	root.Parent = gui -- 다 지은 뒤 붙이고 옛 것을 지움(깜빡임 없음)
	if content then
		content:Destroy()
	end
	content = root
end

local last = nil
local function refresh()
	local ok, r = pcall(function()
		return request:InvokeServer("board", "all")
	end)
	if ok and type(r) == "table" and r.ok then
		last = r
	end
	draw(last)
end

player:GetAttributeChangedSignal(Text.languageAttribute):Connect(function()
	draw(last)
end)
while true do
	refresh()
	task.wait(L.refreshSeconds)
end
