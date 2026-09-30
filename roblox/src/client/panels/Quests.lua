-- QUEUE-10h Q7 U1 퀘스트 · 수련 창(Q6 G3 - 서버 QuestService가 판정 · 지급 · 화면 표를 준다). 단축키 J · 메뉴바 칸(PanelRegistry "quests").
--   ① 첫 접속 보상 ② 메인 퀘스트(단계 · 열리는 것) ③ 일간 3 + 완료 상자 ④ 주간 5 ⑤ 공용 수련 3 ⑥ 직업 고유 능력 3 · 재화(반짝 조각 · 시즌 패스 경험치).
--   값은 QuestUpdate(서버 → 클라)로만 받는다 - 클라는 진행을 계산하지 않는다. 요청 = QuestRequest("view" | "claim" kind id | "train" kind id).
--   폰 = 창이 화면의 92% × 88%(Panel.create) · 본문 스크롤 · 버튼 높이 Theme.buttonHeight(모바일 44).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Text = require(ReplicatedStorage.Shared.Text)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Panel = require(script.Parent.Parent.ui.kit.Panel)
local Button = require(script.Parent.Parent.ui.kit.Button)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local UIManager = require(script.Parent.Parent.UIManager)

local QuestsPanel = {}
QuestsPanel.id = "quests"

local PANEL_SIZE = Vector2.new(560, 440)
local PAD = 12
local ROW_H = 48

local requestRemote = ReplicatedStorage:WaitForChild("QuestRequest")
local updateRemote = ReplicatedStorage:WaitForChild("QuestUpdate")

local built
local view
local order = 0

local function build()
	local panel = Panel.create({ id = QuestsPanel.id, kind = "window", title = Text.get("quests.title"), size = PANEL_SIZE,
		onOpen = function() -- Play C: 단축키 J · 메뉴바로 열면(UIManager.open) render가 안 불려 본문이 비었다 → 열릴 때 그리고 새 표 요청
			task.defer(function()
				QuestsPanel.render()
				requestRemote:FireServer("view")
			end)
		end })
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Body"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.new(1, 0, 1, 0)
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = Theme.color("rim")
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.Parent = panel.content
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, PAD)
	pad.PaddingRight = UDim.new(0, PAD + 4)
	pad.PaddingTop = UDim.new(0, PAD)
	pad.PaddingBottom = UDim.new(0, PAD)
	pad.Parent = scroll
	built = { panel = panel, scroll = scroll }
end

local function label(text, size, color, height)
	order += 1
	local l = Instance.new("TextLabel")
	l.Name = "Line" .. order
	l.LayoutOrder = order
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, 0, height or (size + 8))
	l.Font = Enum.Font.GothamBold
	l.TextSize = size
	l.TextColor3 = color or Theme.color("textPrimary")
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.Text = text
	l.Parent = built.scroll
	return l
end

-- 한 줄 = 왼쪽 글 + 오른쪽 버튼(받기 · 올리기). enabled = 누를 수 있는가
local function row(text, buttonText, enabled, onPress, name)
	order += 1
	local frame = Instance.new("Frame")
	frame.Name = name or ("Row" .. order)
	frame.LayoutOrder = order
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, ROW_H)
	frame.Parent = built.scroll
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, -120, 1, 0)
	l.Font = Enum.Font.Gotham
	l.TextSize = 14
	l.TextColor3 = Theme.color("textPrimary")
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.Text = text
	l.Parent = frame
	local b = Button.build({ parent = frame, kind = "primary", text = buttonText, width = 110, position = UDim2.new(1, 0, 0.5, 0), anchorPoint = Vector2.new(1, 0.5), onActivated = onPress })
	b.root.Name = "ActionButton"
	b.setEnabled(enabled)
	return frame
end

local function send(action, a, b)
	requestRemote:FireServer(action, a, b)
end

function QuestsPanel.render()
	if not built or not UIManager.isOpen(QuestsPanel.id) then
		return
	end
	for _, child in ipairs(built.scroll:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
	order = 0
	if not view then
		label("…", 14)
		return
	end
	row(Text.get("prob.row"), Text.get("prob.open"), true, function() -- Q13 확률 공개 창
		require(script.Parent.Probability).open()
	end, "ProbabilityRow")
	if view.guide then -- Q12 첫 5분 이정표(지금 할 일)
		label(Text.get("guide.now", { index = tostring(view.guide.index), total = tostring(view.guide.total), text = Text.get(view.guide.text) }), 16, Theme.color("xp"))
	end
	if view.attendance then -- Q12 7일 출석
		label(Text.get("attendance.title", { count = tostring(view.attendance.count) }), 16)
		for _, entry in ipairs(view.attendance.rewards) do
			local key = tostring(entry.day)
			local claimed = view.attendance.claimed[key] == true
			local ready = entry.day <= view.attendance.count and not claimed
			row(Text.get("attendance.day", { day = key, reward = Text.get("attendance.reward." .. key) }), claimed and Text.get("quests.claimed") or Text.get("quests.claim"), ready, function()
				send("claim", "attendance", key)
			end, "Attendance_" .. key)
		end
	end
	row(Text.get("quests.login"), view.loginReady and Text.get("quests.claim") or Text.get("quests.claimed"), view.loginReady, function()
		send("claim", "login")
	end, "LoginRow")
	if view.main then
		label(Text.get("quests.main", { index = tostring(view.main.index), total = tostring(view.main.total), name = view.main.name }), 16, Theme.color("xp"))
		row(Text.get("quests.mainUnlock", { unlock = view.main.unlock }), Text.get("quests.claim"), view.main.done, function()
			send("claim", "main")
		end, "MainRow")
	else
		label(Text.get("quests.mainDone"), 16, Theme.color("xp"))
	end
	label(Text.get("quests.daily"), 16)
	for _, q in ipairs(view.daily) do
		row(Text.get("quests.progress", { name = q.name, n = tostring(q.n), target = tostring(q.target) }), q.claimed and Text.get("quests.claimed") or Text.get("quests.claim"),
			q.n >= q.target and not q.claimed, function()
				send("claim", "daily", q.id)
			end, "Daily_" .. q.id)
	end
	row(Text.get("quests.chest"), view.chestClaimed and Text.get("quests.claimed") or Text.get("quests.claim"), view.chestReady, function()
		send("claim", "chest")
	end, "ChestRow")
	label(Text.get("quests.weekly"), 16)
	for _, q in ipairs(view.weekly) do
		row(Text.get("quests.progress", { name = q.name, n = tostring(q.n), target = tostring(q.target) }), q.claimed and Text.get("quests.claimed") or Text.get("quests.claim"),
			q.n >= q.target and not q.claimed, function()
				send("claim", "weekly", q.id)
			end, "Weekly_" .. q.id)
	end
	local function trainRows(rows, header)
		label(header, 16)
		for _, t in ipairs(rows) do
			local atCap = t.level >= t.cap
			row(Text.get("quests.trainRow", { name = t.name, level = tostring(t.level), cap = tostring(t.cap), per = ("%.2f"):format(t.perLevel * 100) }),
				atCap and Text.get("quests.trainCap") or Text.get("quests.trainButton", { cost = NumberFormat.format(t.cost) }), not atCap, function()
					send("train", t.kind, t.id)
				end, "Train_" .. t.id)
		end
	end
	-- QUEUE-ALL3 Q2: 수련 · 직업 능력 줄은 수련 창(U - panels/Training)으로 옮겼다(중복 삭제)
	local _ = trainRows
	label(Text.get("quests.currencies", { shard = tostring(view.currencies and view.currencies.sparkleShard or 0), pass = tostring(view.currencies and view.currencies.passExp or 0) }), 14,
		Theme.color("textSecondary"))
end

function QuestsPanel.open()
	if not built then
		build()
	end
	if not UIManager.isOpen(QuestsPanel.id) and not UIManager.open(QuestsPanel.id) then
		return false
	end
	QuestsPanel.render()
	send("view")
	return true
end

function QuestsPanel.init()
	if not built then
		build()
	end
	updateRemote.OnClientEvent:Connect(function(v)
		view = v
		QuestsPanel.render()
	end)
end

-- 점검 · 스크린샷용: 합성 표로 연다
function QuestsPanel.debugOpen(fakeView)
	view = fakeView
	return QuestsPanel.open()
end

return QuestsPanel
