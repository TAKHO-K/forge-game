-- 친구가 같은 서버에 들어온 순간, 그 자리에 있던 멤버에게 "친구 OOO님이 들어왔습니다 [파티 초대]" 토스트를 1회 보낸다(S12, PRD 20.73 [7-1]).
-- 서버가 Player:IsFriendsWith(웹 호출 - pcall · 접속 시 1회 · 기존 멤버 각각에 대해)로 판정하고, 토스트를 띄울 가치가 있을 때만 보낸다:
-- 받는 사람이 그 친구를 지금 초대할 수 있어야 한다(파티가 없거나 내가 리더이고 자리가 남음 · 친구가 다른 파티에 없음). [파티 초대] 버튼은 기존 초대 요청("invite")을 그대로 쏜다 - 새 규칙이 없다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PartyConfig = require(ReplicatedStorage.Shared.data.PartyConfig)
local PartyState = require(script.Parent.PartyState)

local friendJoinedNotice = Instance.new("RemoteEvent")
friendJoinedNotice.Name = "FriendJoinedNotice"
friendJoinedNotice.Parent = ReplicatedStorage

local FriendNotice = {}

local function defaultIsFriend(member, newcomer)
	local ok, result = pcall(member.IsFriendsWith, member, newcomer.UserId)
	return ok and result == true
end

-- member가 newcomer를 지금 초대할 수 있는 상태인가.
function FriendNotice.canInvite(member, newcomer)
	if PartyState.getParty(newcomer) then
		return false
	end
	local party = PartyState.getParty(member)
	if party and (not PartyState.isLeader(member) or PartyState.getSeatCount(party) >= PartyConfig.maxMembers) then
		return false
	end
	return true
end

-- member에게 보낼 토스트 payload. 친구가 아니거나 초대할 수 없는 상태면 nil. isFriend(member, newcomer)는 검증이 바꿔 끼운다.
function FriendNotice.payloadFor(member, newcomer, isFriend)
	if not isFriend(member, newcomer) or not FriendNotice.canInvite(member, newcomer) then
		return nil
	end
	return { userId = newcomer.UserId, name = newcomer.Name, seconds = PartyConfig.inviteTimeoutSeconds }
end

-- newcomer가 들어온 순간 기존 멤버 각각에 대해 한 번씩(IsFriendsWith가 yield하므로 멤버마다 따로 돈다).
function FriendNotice.notifyExisting(newcomer, isFriend)
	isFriend = isFriend or defaultIsFriend
	for _, member in ipairs(Players:GetPlayers()) do
		if member ~= newcomer then
			task.spawn(function()
				local payload = FriendNotice.payloadFor(member, newcomer, isFriend)
				if payload and member.Parent and newcomer.Parent then
					friendJoinedNotice:FireClient(member, payload)
				end
			end)
		end
	end
end

function FriendNotice.start()
	Players.PlayerAdded:Connect(function(player)
		FriendNotice.notifyExisting(player)
	end)
end

return FriendNotice
