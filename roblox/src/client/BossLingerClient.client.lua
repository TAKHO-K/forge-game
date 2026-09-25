-- G1-4: 서버 BossLinger 신호 → 잔류 선택 창을 열고 닫는다(client/panels/BossLinger).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossLingerPanel = require(script.Parent.panels.BossLinger)

ReplicatedStorage:WaitForChild("BossLinger").OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	if payload.kind == "start" then
		BossLingerPanel.show(payload)
	elseif payload.kind == "end" then
		BossLingerPanel.hide()
	end
end)
