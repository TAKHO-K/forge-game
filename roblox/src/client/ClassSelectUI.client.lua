-- 클래스 선택 UI(10-3 [2]). 기능 확인 수준 - 폴리시(꾸미기)는 UI 세션에서 한꺼번에 한다.
-- classId Attribute가 빈 문자열("")이면 자동으로 뜬다 - Attribute는 nil을 못 담아 "미선택"을
-- 빈 문자열로 표현한다(PlayerProfile.init/setClassId 참고). 지금은 자유 변경을 허용하므로
-- 이미 고른 뒤에도 좌하단 버튼으로 다시 열 수 있다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassData = require(ReplicatedStorage.Shared.data.ClassData)

local classSelectRequest = ReplicatedStorage:WaitForChild("ClassSelectRequest")

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
		classSelectRequest:FireServer(classInfo.id)
	end)
end

for i, classId in ipairs(ClassData.order) do
	makeButton(ClassData.classes[classId], i)
end

-- 재변경용 상시 버튼(좌하단 - 강화 UI는 화면 중앙 하단, 공격 버튼은 우하단이라 겹치지 않는다).
local reopenButton = Instance.new("TextButton")
reopenButton.Name = "ClassReopenButton"
reopenButton.AnchorPoint = Vector2.new(0, 1)
reopenButton.Position = UDim2.new(0, 24, 1, -24)
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
end

player:GetAttributeChangedSignal("ClassId"):Connect(onClassIdChanged)
onClassIdChanged()
