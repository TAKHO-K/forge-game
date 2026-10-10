-- UI-1 7c 파티 빠른 말 서버: Remote QuickChat(kind, index) → 규칙(shared/QuickChatRules - 정해진 번호만 · 같은 말 3번 연속 = 5초 쉬기) → 같은 파티 사람들에게 QuickChatShow(userId, kind, index).
--   자유 글은 받지 않는다(번호만 - 글은 받는 쪽 클라가 자기 언어 표에서 찾는다) · 파티가 없으면 나에게만.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QuickChatRules = require(ReplicatedStorage.Shared.QuickChatRules)
local PartyState = require(script.Parent.PartyState)

local request = Instance.new("RemoteEvent")
request.Name = "QuickChat"
request.Parent = ReplicatedStorage
local show = Instance.new("RemoteEvent")
show.Name = "QuickChatShow"
show.Parent = ReplicatedStorage

local states = {}

request.OnServerEvent:Connect(function(player, kind, index)
	local st = states[player] or {}
	states[player] = st
	local ok = QuickChatRules.allow(st, kind, index, os.clock())
	if not ok then
		return
	end
	local party = PartyState.getParty(player)
	local sent = {}
	if party then
		for _, record in ipairs(party.members) do
			local p = record.player
			if typeof(p) == "Instance" and p:IsA("Player") and p.Parent and not sent[p] then
				sent[p] = true
				show:FireClient(p, player.UserId, kind, index)
			end
		end
	end
	if not sent[player] then
		show:FireClient(player, player.UserId, kind, index)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	states[player] = nil
end)
