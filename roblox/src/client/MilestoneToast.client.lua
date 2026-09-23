-- 환생 후 레벨 마일스톤 달성 토스트(P2.5b D2). 서버 MilestoneReached(PlayerProfile.claimMilestones가 레벨이 바뀔 때 보낸다)를 받아 상단 가운데 줄에 한 번 알린다.
-- 한 번에 여러 마일스톤을 넘으면(레벨이 크게 뛰었다) 한 줄로 합친다. [보상 목록]을 누르면 성장 보상 창(panels/Milestones)이 열린다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Milestone = require(ReplicatedStorage.Shared.Milestone)
local Toast = require(script.Parent.ui.kit.Toast)
local MilestonesPanel = require(script.Parent.panels.Milestones)

local reached = ReplicatedStorage:WaitForChild("MilestoneReached")

reached.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	local parts = { { text = ("성장 보상 Lv.%d · "):format(payload.level or 0), colorName = "xp", bold = true } }
	if (payload.statGained or 0) > 0 then
		table.insert(parts, { text = ("%s ×%.3f "):format(Milestone.statText(), payload.multiplier or 1), colorName = "success" })
	end
	for _, unlock in ipairs(payload.unlocks or {}) do
		table.insert(parts, { text = ("%s "):format(unlock.name), colorName = "gold", bold = true })
	end
	table.insert(parts, { text = "[보상 목록]", colorName = "success", bold = true, onActivate = function()
		MilestonesPanel.open()
	end })
	Toast.push("TC", { richParts = parts, grade = "important", seconds = 6, groupKey = "milestone" })
end)
