-- G1-2: 줍는 순간 자동 처리 알림(서버 InventorySync.notifyAutoProcessed → AutoProcessed). 오른쪽 위 피드 한 줄(드랍 피드와 같은 칸 - 같은 groupKey로 묶여 쌓이지 않는다).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Text = require(ReplicatedStorage.Shared.Text)
local Toast = require(script.Parent.Parent.ui.kit.Toast)

local _ = Players.LocalPlayer
local autoProcessed = ReplicatedStorage:WaitForChild("AutoProcessed")

autoProcessed.OnClientEvent:Connect(function(info)
	if type(info) ~= "table" then
		return
	end
	local grade = ArmorData.grades[info.grade]
	local item = ("%s %s"):format(grade and grade.displayName or tostring(info.grade), ItemVisualData.partDisplayNames[info.part or "armor"] or "")
	local text = info.kind == "dismantle" and Text.get("toast.autoDismantle", { item = item })
		or Text.get("toast.autoSell", { item = item, gold = NumberFormat.format(info.gold or 0) })
	Toast.push("TR", { text = text, colorName = "textSecondary", seconds = 1.5, fadeSeconds = 0.3, groupKey = "autoProcess" })
end)
