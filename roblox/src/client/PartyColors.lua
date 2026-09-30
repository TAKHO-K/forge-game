-- QUEUE-ALL2 P4 ④ 파티원 색(09 B-2 "보스 = 파티원마다 색(최대 4색 - 이름표 · 파티 창과 같은 색)"). 한 규칙 = 같은 PartyId를 UserId 오름차순으로 세운 자리 → UIColors.partyColors[자리].
--   모든 화면에서 같은 사람 = 같은 색(서버 표 없음 - Player Attribute PartyId만). 파티가 아니면 nil. TargetFocus(이름표 점) · DamageFeedView(보스 피해 숫자 · 불꽃) · PartyListView(파티 줄)가 같이 쓴다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)

local PartyColors = {}

function PartyColors.of(who)
	local me = Players.LocalPlayer
	local partyId = who and who:GetAttribute("PartyId")
	if partyId == nil or partyId == "" or partyId ~= me:GetAttribute("PartyId") then
		return nil
	end
	local members = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("PartyId") == partyId then
			table.insert(members, p.UserId)
		end
	end
	table.sort(members)
	local index = table.find(members, who.UserId) or 1
	return UIColors.partyColors[(index - 1) % #UIColors.partyColors + 1]
end

function PartyColors.ofUserId(userId)
	local who = Players:GetPlayerByUserId(userId)
	return who and PartyColors.of(who) or nil
end

return PartyColors
