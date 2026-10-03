-- 클래스 선택 UI(10-3 [2] → QUEUE-ALL9C 2-4 직업 카드 + 변신 무대). classId Attribute가 빈 문자열("")이면 자동으로 뜬다 - Attribute는 nil을 못 담아 "미선택"을
-- 빈 문자열로 표현한다(PlayerProfile.init/setClassId 참고). 자유 변경을 허용하므로 이미 고른 뒤에도 다시 열 수 있다(캐릭터 창 [직업 변경] · 메인 메뉴
-- [직업 선택] = BindableEvent OpenClassSelect) - 다만 19-1부터는 이미 진행 중인 직업이 있을 때 다른 직업을 고르면 확인창(ClassConfirmPanel)을 먼저 띄운다.
-- 최초 선택(아직 아무 직업도 없을 때)은 잃을 게 없으므로 확인 없이 바로 전환한다.
-- QUEUE-ALL9C 2-4: 왼쪽 = 직업 카드 목록(직업 색 띠 · 이름 · 역할 태그 근접 · 원거리 · 지원 · 난이도 별 · 대표 스킬 한 줄 Q · E · 궁극기 · 성향 막대 = ClassData.cardStats
--   직업 중 최댓값 대비 비율) · 오른쪽 = 무대(client/ClassStage - 전용 캐릭터가 그 직업으로 변신 · 누르면 건너뛰기 · [다시 보기]) + [이 직업으로].
--   카드를 누르면 그 직업 변신을 무대에서 재생한다(로블록스 캐릭터 회전 전시 화면은 만들지 않는다 · 내 아바타 변신 연출 없음 - 들어가면 그 직업 장비를 입고 서 있다).
--   준비 중 직업 = 검은 실루엣 + 무기 윤곽 + "곧 공개"(날짜 약속 없음) · 누르면 소개 한 줄만(구매 · 예약 유도 없음).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local SkillData = require(ReplicatedStorage.Shared.data.SkillData)
local UltimateData = require(ReplicatedStorage.Shared.data.UltimateData)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local Text = require(ReplicatedStorage.Shared.Text)
local Theme = require(script.Parent.ui.kit.Theme)
local Button = require(script.Parent.ui.kit.Button)
local ClassStage = require(script.Parent.ClassStage)

local classSelectRequest = ReplicatedStorage:WaitForChild("ClassSelectRequest")
local classSummaryFetch = ReplicatedStorage:WaitForChild("ClassSummaryFetch")

local player = Players.LocalPlayer
Theme.recompute()

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ClassSelectGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 310 -- 사용자가 직접 연 창 · 처음 고르기 = 다른 창(최대 300 - 출석 등) 위(QUEUE-ALL9C 2-3 메모: 출석 창이 덮던 것)
screenGui.Parent = player:WaitForChild("PlayerGui")

local PAD = 16
local TITLE_H = 30
local HINT_H = 34
local ROW_H = 92
local ROW_GAP = 8
local LIST_W = 300
local MAX_W, MAX_H = 900, 560

local panel = Instance.new("Frame")
panel.Name = "ClassSelectPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.5, 0, 0.5, 0)
panel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
panel.BackgroundTransparency = 0.05
panel.Visible = false
panel.Parent = screenGui
Theme.corner(panel, Theme.corner.panel)

local title = Theme.label(panel, Text.get("class.card.title"), "title", "textPrimary")
title.Name = "Title"
title.Position = UDim2.new(0, PAD, 0, 10)
title.Size = UDim2.new(1, -PAD * 2 - 100, 0, TITLE_H)

local hint = Theme.label(panel, Text.get("class.card.hint"), "caption", "textSecondary")
hint.Name = "FriendHint"
hint.Position = UDim2.new(0, PAD, 0, 10 + TITLE_H)
hint.Size = UDim2.new(1, -PAD * 2, 0, HINT_H)
hint.TextWrapped = true
hint.TextTruncate = Enum.TextTruncate.None
hint.TextYAlignment = Enum.TextYAlignment.Top

local closeRefs = Button.build({ parent = panel, name = "ClassCloseButton", kind = "secondary", width = 88, text = Text.get("class.card.close"),
	anchorPoint = Vector2.new(1, 0), position = UDim2.new(1, -PAD, 0, 10), onActivated = function()
		panel.Visible = false
	end })

local BODY_TOP = 10 + TITLE_H + HINT_H + 6
local list = Instance.new("ScrollingFrame") -- 왼쪽 카드 목록(세로 스크롤)
list.Name = "ClassCards"
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.Position = UDim2.new(0, PAD, 0, BODY_TOP)
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.ScrollingDirection = Enum.ScrollingDirection.Y
list.ScrollBarThickness = 4
list.Parent = panel
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, ROW_GAP)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list

-- 오른쪽 무대 + 버튼
local stageHolder = Instance.new("Frame")
stageHolder.Name = "StageHolder"
stageHolder.BackgroundTransparency = 1
stageHolder.ClipsDescendants = true
stageHolder.Parent = panel
local stage = ClassStage.new(stageHolder)
local buttonRow = Instance.new("Frame")
buttonRow.Name = "StageButtons"
buttonRow.BackgroundTransparency = 1
buttonRow.Parent = panel

-- 전환 확인창(19-1) - 이미 진행 중인 직업이 있을 때만 뜬다(카드 위)
local confirmPanel = Instance.new("Frame")
confirmPanel.Name = "ClassConfirmPanel"
confirmPanel.AnchorPoint = Vector2.new(0.5, 0.5)
confirmPanel.Position = UDim2.new(0.5, 0, 0.5, 0)
confirmPanel.Size = UDim2.new(0, 340, 0, 160)
confirmPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
confirmPanel.BackgroundTransparency = 0.05
confirmPanel.Visible = false
confirmPanel.ZIndex = 5
confirmPanel.Parent = screenGui
Theme.corner(confirmPanel, Theme.corner.panel)
Theme.stroke(confirmPanel)

local confirmText = Instance.new("TextLabel")
confirmText.BackgroundTransparency = 1
confirmText.Position = UDim2.new(0, 12, 0, 12)
confirmText.Size = UDim2.new(1, -24, 0, 80)
confirmText.Font = Enum.Font.Gotham
confirmText.TextSize = 15
confirmText.TextWrapped = true
confirmText.TextColor3 = Color3.new(1, 1, 1)
confirmText.ZIndex = 5
confirmText.Parent = confirmPanel

local function confirmButton(name, textKey, anchorX, color)
	local b = Instance.new("TextButton")
	b.Name = name
	b.AnchorPoint = Vector2.new(anchorX, 1)
	b.Position = UDim2.new(anchorX, anchorX == 0 and 12 or -12, 1, -12)
	b.Size = UDim2.new(0, 150, 0, 40)
	b.Text = Text.get(textKey)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 16
	b.BackgroundColor3 = color
	b.TextColor3 = Color3.new(1, 1, 1)
	b.ZIndex = 5
	b.Parent = confirmPanel
	Theme.corner(b, Theme.corner.button)
	return b
end
local confirmYes = confirmButton("ClassConfirmYes", "ui.class.switch", 0, Color3.fromRGB(60, 100, 60))
local confirmNo = confirmButton("ClassConfirmNo", "ui.class.cancel", 1, Color3.fromRGB(60, 60, 70))

local pendingClassId = nil

confirmNo.Activated:Connect(function()
	pendingClassId = nil
	confirmPanel.Visible = false
end)

confirmYes.Activated:Connect(function()
	if pendingClassId then
		classSelectRequest:FireServer(pendingClassId)
	end
	pendingClassId = nil
	confirmPanel.Visible = false
end)

-- 대상 직업으로 바꿀지 묻는다. 한 번도 플레이한 적 없는 직업(레벨1)이면 "레벨 1부터 시작합니다"로, 이미 진행한 적 있는 직업이면 "레벨 X로 이어집니다"로 문구를 가른다.
local function showConfirm(classInfo)
	pendingClassId = classInfo.id
	confirmText.Text = Text.get("ui.class.confirmChecking", { class = Text.get("class.name." .. classInfo.id) })
	confirmPanel.Visible = true

	-- InvokeServer는 yield한다 - 그 사이 다른 직업을 다시 눌러 pendingClassId가 바뀌면 이 응답은 무시한다(경합 방지).
	local requestedId = classInfo.id
	local ok, summaries = pcall(function()
		return classSummaryFetch:InvokeServer()
	end)
	if pendingClassId ~= requestedId then
		return
	end

	local summary = ok and summaries and summaries[requestedId]
	if summary and summary.level > 1 then
		confirmText.Text = Text.get("ui.class.confirmContinue", {
			class = Text.get("class.name." .. classInfo.id), level = ("%d"):format(summary.level), stage = ("%d"):format(summary.stageBest) })
	else
		confirmText.Text = Text.get("ui.class.confirmFresh", {
			class = Text.get("class.name." .. classInfo.id) })
	end
end

-- 최초 선택(아직 아무 직업도 없음)이면 확인 없이 바로 전환하고, 이미 다른 직업을 쓰고 있으면 확인창을 띄운다. 같은 직업을 다시 누르면 아무 일도 하지 않는다.
local function requestClassChange(classInfo)
	local currentClassId = player:GetAttribute("ClassId")
	if currentClassId == classInfo.id then
		return
	end
	if currentClassId == nil or currentClassId == "" then
		classSelectRequest:FireServer(classInfo.id)
		return
	end
	showConfirm(classInfo)
end

-- ── 카드(왼쪽 목록) ────────────────────────────────────────────
local statMax = {}
for _, key in ipairs(ClassData.cardStats) do
	local m = 0
	for _, id in ipairs(ClassData.order) do
		m = math.max(m, ClassData.classes[id][key] or 0)
	end
	statMax[key] = m
end

local selectedId = nil
local rowStrokes = {} -- [classId] = UIStroke
local select -- 아래

local function makeRow(classInfo, order)
	local id = classInfo.id
	local info = ClassData.cards[id] or {}
	local accent = UIColors.classAccent[id] or UIColors.ember
	local row = Instance.new("TextButton")
	row.Name = "ClassCard_" .. id
	row.AutoButtonColor = false
	row.Text = ""
	row.LayoutOrder = order
	row.Size = UDim2.new(1, -8, 0, ROW_H)
	row.BackgroundColor3 = UIColors.slot
	row.Parent = list
	Theme.corner(row, Theme.corner.chip)
	rowStrokes[id] = Theme.stroke(row)
	local band = Instance.new("Frame")
	band.Name = "Accent"
	band.BackgroundColor3 = accent
	band.BorderSizePixel = 0
	band.Size = UDim2.new(0, 6, 1, 0)
	band.Parent = row
	Theme.corner(band, 3)

	local name = Theme.label(row, Text.get("class.name." .. id), "header", "textPrimary")
	name.Position = UDim2.new(0, 16, 0, 6)
	name.Size = UDim2.new(0, 90, 0, 22)
	local roleChip = Instance.new("TextLabel")
	roleChip.Name = "Role"
	roleChip.BackgroundColor3 = accent
	roleChip.BackgroundTransparency = 0.25
	roleChip.Font = Theme.font
	roleChip.TextSize = Theme.textSize("caption")
	roleChip.TextColor3 = Color3.fromRGB(20, 20, 25)
	roleChip.Text = Text.get("class.role." .. tostring(info.role))
	roleChip.Position = UDim2.new(0, 104, 0, 7)
	roleChip.Size = UDim2.new(0, 58, 0, 20)
	roleChip.Parent = row
	Theme.corner(roleChip, 10)
	local stars = Theme.label(row, "", "caption", "xp")
	stars.Name = "Difficulty"
	local d = info.difficulty or 1
	stars.Text = string.rep("★", d) .. string.rep("☆", 3 - d)
	stars.TextXAlignment = Enum.TextXAlignment.Right
	stars.Position = UDim2.new(1, -70, 0, 7)
	stars.Size = UDim2.new(0, 60, 0, 20)

	local skills = Theme.label(row, "", "caption", "textSecondary")
	skills.Name = "Skills"
	local sd = SkillData[id] or {}
	local ult = UltimateData.skills and UltimateData.skills[id]
	skills.Text = Text.get("class.card.skills", { q = Text.name(sd.Q and sd.Q.name or ""), e = Text.name(sd.E and sd.E.name or ""), ult = Text.name(ult and ult.name or "") })
	skills.Position = UDim2.new(0, 16, 0, 30)
	skills.Size = UDim2.new(1, -26, 0, 18)

	for i, key in ipairs(ClassData.cardStats) do -- 성향 막대 2 × 2
		local col, line = (i - 1) % 2, math.floor((i - 1) / 2)
		local x0 = 16
		local label = Theme.label(row, Text.get("class.stat." .. key), "caption", "textSecondary")
		label.Position = UDim2.new(col * 0.5, x0 - col * 6, 0, 52 + line * 18)
		label.Size = UDim2.new(0, 44, 0, 16)
		local back = Instance.new("Frame")
		back.Name = "Bar_" .. key
		back.BackgroundColor3 = UIColors.panel
		back.BorderSizePixel = 0
		back.Position = UDim2.new(col * 0.5, x0 + 44 - col * 6, 0, 56 + line * 18)
		back.Size = UDim2.new(0.5, -(x0 + 50), 0, 8)
		back.Parent = row
		Theme.corner(back, 4)
		local fill = Instance.new("Frame")
		fill.BackgroundColor3 = accent
		fill.BorderSizePixel = 0
		fill.Size = UDim2.new(math.clamp((classInfo[key] or 0) / math.max(statMax[key], 1e-6), 0.05, 1), 0, 1, 0)
		fill.Parent = back
		Theme.corner(fill, 4)
	end
	row.Activated:Connect(function()
		select(id)
	end)
end

for i, classId in ipairs(ClassData.order) do
	makeRow(ClassData.classes[classId], i)
end

-- 준비 중 직업: 검은 실루엣 + 무기(뿅망치) 윤곽 + "곧 공개" · 누르면 소개 한 줄만
for i, info in ipairs(ClassData.comingSoon or {}) do
	local row = Instance.new("TextButton")
	row.Name = "ComingSoon_" .. info.id
	row.AutoButtonColor = false
	row.Text = ""
	row.LayoutOrder = #ClassData.order + i
	row.Size = UDim2.new(1, -8, 0, ROW_H)
	row.BackgroundColor3 = UIColors.lockedBg
	row.Parent = list
	Theme.corner(row, Theme.corner.chip)
	Theme.stroke(row)
	local sil = Instance.new("Frame") -- 사람 실루엣(머리 + 몸) + 망치 윤곽(속 빈 테두리)
	sil.Name = "Silhouette"
	sil.BackgroundTransparency = 1
	sil.Position = UDim2.new(0, 10, 0, 6)
	sil.Size = UDim2.new(0, 80, 0, 80)
	sil.Parent = row
	local function shape(pos, size, round, filled)
		local f = Instance.new("Frame")
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BackgroundTransparency = filled and 0 or 1
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = pos
		f.Size = size
		f.Parent = sil
		Theme.corner(f, round)
		if not filled then
			Theme.stroke(f, "lockedText", 0)
		end
		return f
	end
	shape(UDim2.new(0.4, 0, 0, 16), UDim2.new(0, 24, 0, 24), 12, true)
	shape(UDim2.new(0.4, 0, 0, 52), UDim2.new(0, 38, 0, 46), 10, true)
	shape(UDim2.new(0.78, 0, 0.55, 0), UDim2.new(0, 5, 0, 38), 2, false).Rotation = 25
	shape(UDim2.new(0.86, 0, 0.3, 0), UDim2.new(0, 26, 0, 16), 6, false).Rotation = 25
	local soon = Theme.label(row, Text.get("class.card.soon"), "header", "lockedText")
	soon.Name = "Soon"
	soon.Position = UDim2.new(0, 100, 0, 8)
	soon.Size = UDim2.new(1, -110, 0, 22)
	local cname = Theme.label(row, Text.get("class.name." .. info.id), "body", "lockedText")
	cname.Position = UDim2.new(0, 100, 0, 32)
	cname.Size = UDim2.new(1, -110, 0, 18)
	local intro = Theme.label(row, Text.get("class.soon." .. info.id), "caption", "textSecondary")
	intro.Name = "Intro"
	intro.Position = UDim2.new(0, 100, 0, 52)
	intro.Size = UDim2.new(1, -110, 0, 34)
	intro.TextWrapped = true
	intro.TextTruncate = Enum.TextTruncate.None
	intro.TextYAlignment = Enum.TextYAlignment.Top
	intro.Visible = false
	row.Activated:Connect(function()
		intro.Visible = not intro.Visible
	end)
end

-- 무대 아래 버튼: [다시 보기] · [이 직업으로](지금 직업 = 누를 수 없음)
Button.build({ parent = buttonRow, name = "ReplayButton", kind = "secondary", width = 110, text = Text.get("class.card.replay"),
	position = UDim2.new(0, 0, 0, 0), onActivated = function()
		if selectedId then
			stage:play(selectedId)
		end
	end })
local pickRefs = Button.build({ parent = buttonRow, name = "PickButton", kind = "primary", width = 160, text = Text.get("class.card.pick"),
	anchorPoint = Vector2.new(1, 0), position = UDim2.new(1, 0, 0, 0), onActivated = function()
		if selectedId then
			requestClassChange(ClassData.classes[selectedId])
		end
	end })

local function refreshPick()
	local current = player:GetAttribute("ClassId")
	for id, stroke in pairs(rowStrokes) do
		stroke.Color = id == selectedId and (UIColors.classAccent[id] or UIColors.ember) or UIColors.rim
		stroke.Thickness = id == selectedId and 2 or 1
		stroke.Transparency = id == selectedId and 0 or UIColors.rimTransparency
	end
	if selectedId and selectedId == current then
		pickRefs.setText(Text.get("class.card.current"))
		pickRefs.setEnabled(false)
	else
		pickRefs.setText(Text.get("class.card.pick"))
		pickRefs.setEnabled(selectedId ~= nil)
	end
	closeRefs.root.Visible = type(current) == "string" and current ~= ""
end

select = function(id)
	selectedId = id
	refreshPick()
	stage:play(id)
end

-- 창 크기: 화면 안(여백 16) · 왼쪽 목록 LIST_W(좁으면 화면 40%) · 나머지 = 무대
local function layout()
	local screen = screenGui.AbsoluteSize
	if screen.X <= 0 then
		return
	end
	local w = math.min(MAX_W, screen.X - 32)
	local h = math.min(MAX_H, screen.Y - 32)
	panel.Size = UDim2.new(0, w, 0, h)
	local listW = math.min(LIST_W, math.floor((w - PAD * 3) * 0.45))
	local bodyH = h - BODY_TOP - PAD
	list.Size = UDim2.new(0, listW, 0, bodyH)
	local btnH = Theme.buttonHeight
	stageHolder.Position = UDim2.new(0, PAD * 2 + listW, 0, BODY_TOP)
	stageHolder.Size = UDim2.new(1, -(PAD * 3 + listW), 0, bodyH - btnH - 8)
	buttonRow.Position = UDim2.new(0, PAD * 2 + listW, 0, BODY_TOP + bodyH - btnH)
	buttonRow.Size = UDim2.new(1, -(PAD * 3 + listW), 0, btnH)
end
screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
layout()

local function openClassSelect()
	layout()
	panel.Visible = true
	local current = player:GetAttribute("ClassId")
	select((type(current) == "string" and current ~= "" and current) or ClassData.order[1])
end
local function closeClassSelect()
	panel.Visible = false
	stage:stop()
end
panel:GetPropertyChangedSignal("Visible"):Connect(function()
	if not panel.Visible then
		stage:stop()
	end
end)
-- Q14 P4e · QUEUE-ALL2 P2: 다시 여는 입구 = 캐릭터 창(C) [직업 변경] · 메인 메뉴 [직업 선택](BindableEvent OpenClassSelect)
local openSignal = Instance.new("BindableEvent")
openSignal.Name = "OpenClassSelect"
openSignal.Parent = script
openSignal.Event:Connect(openClassSelect)

local function onClassIdChanged()
	local classId = player:GetAttribute("ClassId")
	if classId == "" then -- 처음 고르기(nil = 아직 저장을 안 읽음 - 이때 열면 메시 캐시 전이라 무대가 빈 채로 돌았다)
		openClassSelect()
	else
		closeClassSelect()
	end
	-- 전환이 실제로 반영된 시점(서버가 ClassId Attribute를 바꾼 순간) - 확인창이 아직 떠 있을 이유가 없다.
	pendingClassId = nil
	confirmPanel.Visible = false
	refreshPick()
end

player:GetAttributeChangedSignal("ClassId"):Connect(onClassIdChanged)
onClassIdChanged()
