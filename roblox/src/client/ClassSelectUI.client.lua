-- 클래스 선택 UI(10-3 [2]). 기능 확인 수준 - 폴리시(꾸미기)는 UI 세션에서 한꺼번에 한다.
-- classId Attribute가 빈 문자열("")이면 자동으로 뜬다 - Attribute는 nil을 못 담아 "미선택"을
-- 빈 문자열로 표현한다(PlayerProfile.init/setClassId 참고). 자유 변경을 허용하므로 이미
-- 고른 뒤에도 좌하단 버튼으로 다시 열 수 있다 - 다만 19-1부터는 이미 진행 중인 직업이
-- 있을 때 다른 직업을 고르면 확인창(ClassConfirmPanel)을 먼저 띄운다. 최초 선택(아직
-- 아무 직업도 없을 때)은 잃을 게 없으므로 확인 없이 바로 전환한다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassData = require(ReplicatedStorage.Shared.data.ClassData)

local classSelectRequest = ReplicatedStorage:WaitForChild("ClassSelectRequest")
local classSummaryFetch = ReplicatedStorage:WaitForChild("ClassSummaryFetch")

local player = Players.LocalPlayer

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ClassSelectGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "ClassSelectPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.5, 0, 0.5, 0)
panel.Size = UDim2.new(0, 380, 0, 260)
panel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
panel.BackgroundTransparency = 0.05
panel.Visible = false
panel.Parent = screenGui

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, 0, 0, 30)
title.LayoutOrder = 0
title.Text = "직업을 선택하세요"
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.TextColor3 = Color3.new(1, 1, 1)
title.Parent = panel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Parent = panel

-- 전환 확인창(19-1) - 이미 진행 중인 직업이 있을 때만 뜬다. 별도 Frame으로 두고
-- panel 위에 겹쳐 보인다(같은 screenGui 안, 나중에 그려져 위에 온다).
local confirmPanel = Instance.new("Frame")
confirmPanel.Name = "ClassConfirmPanel"
confirmPanel.AnchorPoint = Vector2.new(0.5, 0.5)
confirmPanel.Position = UDim2.new(0.5, 0, 0.5, 0)
confirmPanel.Size = UDim2.new(0, 340, 0, 160)
confirmPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
confirmPanel.BackgroundTransparency = 0.05
confirmPanel.Visible = false
confirmPanel.ZIndex = 2
confirmPanel.Parent = screenGui

local confirmText = Instance.new("TextLabel")
confirmText.BackgroundTransparency = 1
confirmText.Position = UDim2.new(0, 12, 0, 12)
confirmText.Size = UDim2.new(1, -24, 0, 80)
confirmText.Font = Enum.Font.Gotham
confirmText.TextSize = 15
confirmText.TextWrapped = true
confirmText.TextColor3 = Color3.new(1, 1, 1)
confirmText.ZIndex = 2
confirmText.Parent = confirmPanel

local confirmYes = Instance.new("TextButton")
confirmYes.AnchorPoint = Vector2.new(0, 1)
confirmYes.Position = UDim2.new(0, 12, 1, -12)
confirmYes.Size = UDim2.new(0, 150, 0, 40)
confirmYes.Text = "전환"
confirmYes.Font = Enum.Font.GothamBold
confirmYes.TextSize = 16
confirmYes.BackgroundColor3 = Color3.fromRGB(60, 100, 60)
confirmYes.TextColor3 = Color3.new(1, 1, 1)
confirmYes.ZIndex = 2
confirmYes.Parent = confirmPanel

local confirmNo = Instance.new("TextButton")
confirmNo.AnchorPoint = Vector2.new(1, 1)
confirmNo.Position = UDim2.new(1, -12, 1, -12)
confirmNo.Size = UDim2.new(0, 150, 0, 40)
confirmNo.Text = "취소"
confirmNo.Font = Enum.Font.Gotham
confirmNo.TextSize = 16
confirmNo.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
confirmNo.TextColor3 = Color3.new(1, 1, 1)
confirmNo.ZIndex = 2
confirmNo.Parent = confirmPanel

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
	panel.Visible = false
end)

-- 대상 직업으로 바꿀지 묻는다. 한 번도 플레이한 적 없는 직업(레벨1)이면 "레벨 1부터
-- 시작합니다"로, 이미 진행한 적 있는 직업이면 "레벨 X로 이어집니다"로 문구를 가른다 -
-- 전자는 되돌릴 수 없는 손실을 만들지 않는다는 걸, 후자는 그 직업 진행도가 그대로
-- 남아있다는 걸 알려주는 게 목적이다.
local function showConfirm(classInfo)
	pendingClassId = classInfo.id
	confirmText.Text = ("%s(으)로 전환합니다...\n확인 중"):format(classInfo.displayName)
	confirmPanel.Visible = true

	-- InvokeServer는 yield한다 - 그 사이 다른 직업을 다시 눌러 pendingClassId가 바뀌면
	-- 이 응답은 무시한다(경합 방지).
	local requestedId = classInfo.id
	local ok, summaries = pcall(function()
		return classSummaryFetch:InvokeServer()
	end)
	if pendingClassId ~= requestedId then
		return
	end

	local summary = ok and summaries and summaries[requestedId]
	if summary and summary.level > 1 then
		confirmText.Text = ("%s(으)로 전환합니다.\n레벨 %d · 최고 스테이지 %d로 이어집니다."):format(
			classInfo.displayName, summary.level, summary.stageBest)
	else
		confirmText.Text = ("%s(으)로 전환합니다.\n레벨 1부터 시작합니다. 골드와 가방은 유지됩니다."):format(
			classInfo.displayName)
	end
end

-- 최초 선택(아직 아무 직업도 없음)이면 확인 없이 바로 전환하고, 이미 다른 직업을 쓰고
-- 있으면 확인창을 띄운다. 같은 직업을 다시 누르면 아무 일도 하지 않는다.
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

local function makeButton(classInfo, order)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, 356, 0, 46)
	button.Font = Enum.Font.Gotham
	button.TextSize = 15
	button.TextColor3 = Color3.new(1, 1, 1)
	button.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	button.LayoutOrder = order
	button.Text = ("%s   공격 %.2fx / 방어 %.2fx / 속도 %.2fx"):format(
		classInfo.displayName, classInfo.atk, classInfo.def, classInfo.atkSpeed)
	button.Parent = panel

	button.Activated:Connect(function()
		requestClassChange(classInfo)
	end)
end

for i, classId in ipairs(ClassData.order) do
	makeButton(ClassData.classes[classId], i)
end

-- 재변경용 상시 버튼(좌하단 - 강화 UI는 화면 중앙 하단, 공격 버튼은 우하단이라 겹치지 않는다).
-- y오프셋 34: 16-1에서 생긴 맨 아래 경험치바(ExpBar.client.lua, 높이 26)와 겹치지 않게
-- 8px 띄운다(Studio 실측으로 -24 그대로 두면 2px 겹치는 걸 확인했다).
local reopenButton = Instance.new("TextButton")
reopenButton.Name = "ClassReopenButton"
reopenButton.AnchorPoint = Vector2.new(0, 1)
reopenButton.Position = UDim2.new(0, 24, 1, -34)
reopenButton.Size = UDim2.new(0, 90, 0, 36)
reopenButton.Text = "직업 변경"
reopenButton.Font = Enum.Font.Gotham
reopenButton.TextSize = 14
reopenButton.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
reopenButton.TextColor3 = Color3.new(1, 1, 1)
reopenButton.Parent = screenGui
reopenButton.Activated:Connect(function()
	panel.Visible = true
end)

local function onClassIdChanged()
	local classId = player:GetAttribute("ClassId")
	if classId == nil or classId == "" then
		panel.Visible = true
	else
		panel.Visible = false
	end
	-- 전환이 실제로 반영된 시점(서버가 ClassId Attribute를 바꾼 순간) - 확인창이 아직
	-- 떠 있을 이유가 없다.
	pendingClassId = nil
	confirmPanel.Visible = false
end

player:GetAttributeChangedSignal("ClassId"):Connect(onClassIdChanged)
onClassIdChanged()
