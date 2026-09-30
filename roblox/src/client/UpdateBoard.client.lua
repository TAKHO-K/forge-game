-- QUEUE-ALL1 P4 §2 허브 업데이트 게시판(새 소식 + 지금 쓸 수 있는 코드 - 만료 지난 코드는 안 보인다) · §3 주간 도전 버튼 · 순위 창 · P4 알림 토스트.
--   게시판 = 명예의 전당 옆 빌보드(허브에 가면 보인다) · 주간 도전 = 합동 목표 알약 오른쪽 버튼 → 창(이번 주 보스 · 변형 · [도전] · 순위 top). 수치 · 문구 = SocialRewardData · WeeklyChallengeData.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SD = require(ReplicatedStorage.Shared.data.SocialRewardData)
local WD = require(ReplicatedStorage.Shared.data.WeeklyChallengeData)
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local Theme = require(script.Parent.ui.kit.Theme)
local Toast = require(script.Parent.ui.kit.Toast)

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
local function validCodes()
	local out = {}
	for _, c in ipairs(SD.codes) do
		local e = c.expires
		if os.time() <= os.time({ year = e[1], month = e[2], day = e[3], hour = 23, min = 59, sec = 59 }) then
			table.insert(out, ("%s · %s(~%d.%d.%d)"):format(c.code, c.note or "", e[1], e[2], e[3]))
		end
	end
	return out
end
local function buildBoard()
	local hof = Workspace:FindFirstChild("HallOfFame")
	local adornee = hof and (hof.PrimaryPart or hof:FindFirstChildWhichIsA("BasePart", true))
	if not adornee or gui:FindFirstChild("UpdateBoard") then
		return
	end
	local b = Instance.new("BillboardGui")
	b.Name = "UpdateBoard"
	b.Size = UDim2.fromOffset(300, 170)
	b.StudsOffsetWorldSpace = Vector3.new(14, 10, 0)
	b.MaxDistance = 120
	b.Adornee = adornee
	b.Parent = gui
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = INK
	bg.BackgroundTransparency = 0.15
	bg.Parent = b
	Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 10)
	local y = 6
	local t = label(bg, SD.text.board, 16, GOLD, Theme.font)
	t.Position, t.Size = UDim2.fromOffset(10, y), UDim2.new(1, -20, 0, 20)
	y += 22
	for _, n in ipairs(SD.news) do
		local l = label(bg, ("%s  %s"):format(n.date, n.text), 12)
		l.Position, l.Size = UDim2.fromOffset(10, y), UDim2.new(1, -20, 0, 30)
		y += 30
	end
	local c = label(bg, SD.text.codes, 14, GOLD, Theme.font)
	c.Position, c.Size = UDim2.fromOffset(10, y), UDim2.new(1, -20, 0, 18)
	y += 18
	for _, s in ipairs(validCodes()) do
		local l = label(bg, s, 12, Color3.fromRGB(220, 230, 255))
		l.Position, l.Size = UDim2.fromOffset(10, y), UDim2.new(1, -20, 0, 16)
		y += 16
	end
end
buildBoard()
Workspace.ChildAdded:Connect(function(c)
	if c.Name == "HallOfFame" then
		task.defer(buildBoard)
	end
end)

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
btn.Text = WD.text.button
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
go.Text = WD.text.start
go.Parent = panel
Instance.new("UICorner", go).CornerRadius = UDim.new(0, 8)
local rankTitle = label(panel, WD.text.rank, 13, Color3.fromRGB(200, 200, 214))
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
	head.Text = ("%s · %s(스테이지 %d)"):format(b and b.displayName or "?", tostring(Workspace:GetAttribute("WeeklyChallengeLabel") or ""), WD.stage)
	local ok, r = pcall(function()
		return ReplicatedStorage:WaitForChild("WeeklyChallengeTop"):InvokeServer()
	end)
	for i, l in ipairs(rankRows) do
		local row = ok and type(r) == "table" and r.rows and r.rows[i]
		l.Text = row and ("%d. %s  %.1f초"):format(row.rank, row.name, row.seconds) or (i == 1 and WD.text.none or "")
	end
	mine.Text = (ok and type(r) == "table" and r.myBest) and ("내 기록 %.1f초"):format(r.myBest) or ""
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
