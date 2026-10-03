-- G1-2: 줍는 순간 자동 처리 알림(서버 InventorySync.notifyAutoProcessed → AutoProcessed). 오른쪽 위 피드 한 줄(드랍 피드와 같은 칸 - QUEUE-N1004 A-1부터 몇 초씩 묶는다).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Text = require(ReplicatedStorage.Shared.Text)
local Toast = require(script.Parent.Parent.ui.kit.Toast)

local _ = Players.LocalPlayer
local autoProcessed = ReplicatedStorage:WaitForChild("AutoProcessed")

-- QUEUE-N1004 A-1: 한 개씩 띄우지 않고 ArmorData.autoProcessToastBatchSeconds 동안 모아 한 줄(개수 · 골드 합계 · 보석 수)
local batch -- { count, gold, gems } - 첫 처리 때 만들고 시간이 지나면 띄우고 비운다
autoProcessed.OnClientEvent:Connect(function(info)
	if type(info) ~= "table" then
		return
	end
	if not batch then
		batch = { count = 0, gold = 0, gems = 0 }
		task.delay(ArmorData.autoProcessToastBatchSeconds, function()
			local b = batch
			batch = nil
			local key = b.gems > 0 and (b.gold > 0 and "autoTidy.toast.both" or "autoTidy.toast.gems") or "autoTidy.toast.gold"
			local text = Text.get(key, { count = b.count, gold = NumberFormat.format(b.gold), gems = b.gems })
			Toast.push("TR", { text = text, colorName = "textSecondary", seconds = 2, fadeSeconds = 0.3, groupKey = "autoProcess" })
		end)
	end
	batch.count += 1
	if info.kind == "dismantle" then
		batch.gems += 1
	else
		batch.gold += tonumber(info.gold) or 0
	end
end)
