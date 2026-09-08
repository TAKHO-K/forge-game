-- 아이템을 주웠을 때의 반응(14-1 "줍는 순간의 반응"). SaveNoticeHud와 같은 화면 중앙
-- 토스트 패턴을 재사용하되, 등급 색을 그대로 쓰고 등급이 높을수록 글자를 크게 띄운다
-- (ItemVisualData.gradeVisuals.toastTextSize).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)

local itemPickedUp = ReplicatedStorage:WaitForChild("ItemPickedUp")

local DISPLAY_SECONDS = 1.6

local player = Players.LocalPlayer

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ItemPickupHudGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.Name = "ItemPickupLabel"
label.AnchorPoint = Vector2.new(0.5, 1)
label.Position = UDim2.new(0.5, 0, 1, -140)
label.Size = UDim2.new(0, 360, 0, 40)
label.BackgroundTransparency = 1
label.TextTransparency = 1
label.TextStrokeTransparency = 0.6
label.Font = Enum.Font.GothamBold
label.Text = ""
label.Parent = screenGui

itemPickedUp.OnClientEvent:Connect(function(item)
	local grade = ArmorData.grades[item.grade]
	local visual = ItemVisualData.gradeVisuals[item.grade]
	local partName = ItemVisualData.partDisplayNames[item.part or "armor"] or "장비"

	label.Text = ("%s %s 획득 (Lv.%d)"):format(grade and grade.displayName or item.grade, partName, item.itemLevel)
	label.TextColor3 = visual and visual.color or Color3.new(1, 1, 1)
	label.TextSize = visual and visual.toastTextSize or 18
	label.TextTransparency = 0

	TweenService:Create(label, TweenInfo.new(DISPLAY_SECONDS), { TextTransparency = 1 }):Play()
end)
