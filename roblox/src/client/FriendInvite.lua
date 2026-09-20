-- 친구 부르기(S12, PRD 20.73 [7-1]) - 로블록스 기본 초대 창(SocialService:PromptGameInvite)을 여는 얇은 래퍼. 새 창을 만들지 않는다.
-- 초대를 보낼 수 없는 계정 · 환경이면(CanSendGameInviteAsync가 false이거나 실패) 버튼을 숨긴다 - 버튼은 onAvailability로 자기 Visible을 정한다.
-- Studio에서는 CanSendGameInviteAsync가 항상 false일 수 있어 버튼을 보이게 둔다(호출이 에러 없이 돌아오는지만 볼 수 있다 - 창은 안 뜰 수 있다).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")

local player = Players.LocalPlayer

local FriendInvite = {}

local canSend = nil -- nil = 아직 모름
local listeners = {}

local function available()
	return canSend == true or RunService:IsStudio()
end

task.spawn(function()
	local ok, result = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
	canSend = ok and result == true
	for _, listener in ipairs(listeners) do
		listener(available())
	end
end)

-- 알 수 있게 되면(이미 알면 바로) listener(보일 수 있는가)를 부른다. 그 전에는 버튼을 숨겨 둔다.
function FriendInvite.onAvailability(listener)
	table.insert(listeners, listener)
	if canSend ~= nil then
		listener(available())
	end
end

function FriendInvite.isAvailable()
	return canSend ~= nil and available()
end

-- 기본 초대 창을 연다. 실패해도 에러를 밖으로 내지 않는다. 돌려주는 값 = pcall 성공 여부.
function FriendInvite.prompt()
	local ok, err = pcall(SocialService.PromptGameInvite, SocialService, player)
	if not ok then
		warn("[FriendInvite] PromptGameInvite 실패: " .. tostring(err))
	end
	return ok
end

return FriendInvite
