-- QUEUE-10h Q12 첫 5분 이정표 토스트(서버 QuestService.view().guide가 바뀌면 TC 줄에 한 줄 · 스킬 단계는 안내 카드 한 줄 더). 상시 띠는 두지 않는다(ScreenMap 자리 규칙) - 늘 보는 곳 = 퀘스트 창 맨 위 "지금 할 일".
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Text = require(ReplicatedStorage.Shared.Text)
local Toast = require(script.Parent.Parent.ui.kit.Toast)

local updateRemote = ReplicatedStorage:WaitForChild("QuestUpdate")
local lastGuide = false -- false = 아직 한 번도 못 받음(접속 첫 표에도 한 번 보여 준다)

updateRemote.OnClientEvent:Connect(function(view)
	if type(view) ~= "table" then
		return
	end
	local id = view.guide and view.guide.id or nil
	if id == lastGuide then
		return
	end
	local wasActive = lastGuide ~= false and lastGuide ~= nil
	lastGuide = id
	if view.guide then
		Toast.push("TC", { text = Text.get("guide.now", { index = tostring(view.guide.index), total = tostring(view.guide.total), text = Text.get(view.guide.text) }), colorName = "xp", seconds = 5, priority = 2, groupKey = "guide" })
		if view.guide.card then
			Toast.push("TC", { text = Text.get(view.guide.card), colorName = "textPrimary", seconds = 6, priority = 2, groupKey = "guideCard" })
		end
	elseif wasActive then
		Toast.push("TC", { text = Text.get("guide.done"), colorName = "xp", seconds = 5, priority = 2, groupKey = "guide" })
	end
end)
