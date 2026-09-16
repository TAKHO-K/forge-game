-- 파티 조작 RemoteEvent 처리(24-1). 클라이언트는 action 문자열 하나와 인자 하나만 보낸다 -
-- 누가 리더인지·자리가 남았는지·견습 중인지·보스전 중인지는 전부 여기서 다시 판정한다
-- (클라이언트가 보낸 값을 그대로 믿지 않는다는 원칙). 멤버십 자체는 PartyState가 갖고,
-- 이 스크립트는 "지금 이 조작이 허용되는가"의 교차 검사(견습·보스전)만 얹는다 - PartyState가
-- TutorialState/BossEncounter를 require하면 순환이 생기기 때문(PartyState.lua 상단 주석).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PartyState = require(script.Parent.PartyState)
local TutorialState = require(script.Parent.TutorialState)
local BossEncounter = require(script.Parent.BossEncounter)
local PlayerProfile = require(script.Parent.PlayerProfile)

local partyRequest = Instance.new("RemoteEvent")
partyRequest.Name = "PartyRequest"
partyRequest.Parent = ReplicatedStorage

local REASON_TEXT = {
	self = "자기 자신은 초대할 수 없습니다",
	target_in_party = "이미 다른 파티에 속한 플레이어입니다",
	target_has_invite = "이미 초대를 받고 응답을 기다리는 중입니다",
	not_leader = "리더만 할 수 있습니다",
	party_full = "파티가 가득 찼습니다(최대 4인)",
	no_invite = "유효한 초대가 없습니다",
	already_in_party = "이미 파티에 속해 있습니다",
	party_gone = "그 파티는 더 이상 없습니다",
	not_member = "파티원이 아닙니다",
	tutorial_self = "견습 모드 중에는 파티에 들어갈 수 없습니다",
	tutorial_target = "견습 모드 중인 플레이어는 초대할 수 없습니다",
	in_boss = "보스전 중에는 파티원을 바꿀 수 없습니다",
	no_profile = "아직 준비되지 않은 플레이어입니다",
}

local function fail(player, reason)
	PartyState.notify(player, REASON_TEXT[reason] or ("실패: " .. tostring(reason)))
end

-- 파티 구성 변경(초대·수락)의 공통 금지 조건 - 견습 중(어느 쪽이든)·보스전 중(파티 쪽).
-- 견습은 싱글이다(지시 1) - 견습 중인 플레이어가 파티에 들어가는 길도, 파티원이 견습에
-- 들어가는 길(TutorialState.start의 자동 탈퇴)도 둘 다 막는다.
local function checkJoinable(inviter, invitee)
	if not PlayerProfile.getProfile(inviter) or not PlayerProfile.getProfile(invitee) then
		return "no_profile"
	end
	if TutorialState.isActive(inviter) then
		return "tutorial_self"
	end
	if TutorialState.isActive(invitee) then
		return "tutorial_target"
	end
	if BossEncounter.getActive(inviter) then
		return "in_boss" -- 보스 HP가 입장 인원에 고정돼 있어 중간 합류는 없다(PRD 20.47 [6](다)).
	end
	return nil
end

partyRequest.OnServerEvent:Connect(function(player, action, arg)
	if action == "invite" then
		local target = type(arg) == "number" and Players:GetPlayerByUserId(arg)
		if not target then
			return
		end
		local blocked = checkJoinable(player, target)
		if blocked then
			fail(player, blocked)
			return
		end
		local ok, reason = PartyState.invite(player, target)
		if not ok then
			fail(player, reason)
		else
			PartyState.notify(player, ("%s님을 초대했습니다"):format(target.Name))
		end
	elseif action == "accept" or action == "decline" then
		local accept = action == "accept"
		if accept then
			local party = PartyState.getPendingInviteParty(player)
			local leader = PartyState.getLeader(party)
			if not leader then
				fail(player, "party_gone")
				PartyState.respondInvite(player, false)
				return
			end
			local blocked = checkJoinable(leader, player)
			if blocked then
				fail(player, blocked == "tutorial_target" and "tutorial_self" or blocked)
				PartyState.respondInvite(player, false)
				return
			end
			-- 합류하는 순간 진행 중이던 자기 솔로 보스는 물러난다 - 파티원의 보스전은 리더가
			-- 시작하는 파티 보스뿐이다(StageServer.server.lua).
			if BossEncounter.getActive(player) then
				BossEncounter.despawnFor(player)
			end
		end
		local ok, reason = PartyState.respondInvite(player, accept)
		if not ok then
			fail(player, reason)
		end
	elseif action == "leave" then
		if not PartyState.leave(player, "leave") then
			fail(player, "not_member")
		end
	elseif action == "kick" then
		if type(arg) ~= "number" then
			return
		end
		if BossEncounter.getActive(player) then
			fail(player, "in_boss")
			return
		end
		local ok, reason = PartyState.kick(player, arg)
		if not ok then
			fail(player, reason)
		end
	end
end)

print("[forge-game] PartyServer 로드됨 - 파티 초대/수락/탈퇴/추방 활성")
