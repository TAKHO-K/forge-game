-- 20강+ 강화 성공 공지(30-0 S08, PRD 20.72 [1-9]). 서버(EnhanceService)가 새 단계가 EnhanceConfig.announceFromLevel 이상인 성공마다 같은 서버 전원에게 (표시 이름, 새 단계)를 보낸다.
-- 여기서는 그것을 채팅 시스템 메시지 1줄로 바꿔 보여 준다. 판정 · 조건은 전부 서버다 - 클라는 받은 대로 그린다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local Text = require(ReplicatedStorage.Shared.Text)

local announce = ReplicatedStorage:WaitForChild("EnhanceAnnounce")

announce.OnClientEvent:Connect(function(displayName, level)
	local channels = TextChatService:FindFirstChild("TextChannels")
	local general = channels and channels:FindFirstChild("RBXGeneral")
	if general then
		general:DisplaySystemMessage(Text.get("scene.enhance.announce", { name = tostring(displayName), level = ("%d"):format(tonumber(level) or 0) }))
	end
end)
