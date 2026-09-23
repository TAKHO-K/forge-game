-- 환생 후 레벨 마일스톤(P2.5b D)의 클라 통로 하나 - GemSync · InventorySync와 같은 이유(PlayerProfile이 달성 순간 직접 부른다 - 호출부마다 알림을 챙기면 잊는다).
--   MilestoneReached(RemoteEvent, 서버 → 클라): { level, statGained, claimedLevel, bonus, multiplier, unlocks = { { index, id, name, level, reserved } } } - 달성 토스트가 읽는다.
--   MilestoneFetch(RemoteFunction): 성장 보상 창이 열 때 묻는다 - { rebirthCount, level, claimedLevel, bonus, unlockCount }(P2.5c B2).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local reached = Instance.new("RemoteEvent")
reached.Name = "MilestoneReached"
reached.Parent = ReplicatedStorage

local fetch = Instance.new("RemoteFunction")
fetch.Name = "MilestoneFetch"
fetch.Parent = ReplicatedStorage

local PlayerProfile

local MilestoneNotice = {}

function MilestoneNotice.push(player, payload)
	if typeof(player) == "Instance" and player:IsA("Player") then -- 검증 스탠드인(표)에는 보내지 않는다
		reached:FireClient(player, payload)
	end
end

fetch.OnServerInvoke = function(player)
	PlayerProfile = PlayerProfile or require(script.Parent.PlayerProfile) -- 순환 require 방지(PlayerProfile이 이 모듈을 require한다)
	return PlayerProfile.getMilestoneSummary(player)
end

return MilestoneNotice
