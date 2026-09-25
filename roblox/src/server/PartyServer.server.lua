-- 파티 조작 RemoteEvent 처리(24-1, 24-2 크로스서버 확장). 클라이언트는 action 문자열 하나와 인자 하나만 보낸다 -
-- 누가 리더인지·자리가 남았는지·견습 중인지·보스전 중인지는 전부 여기서 다시 판정한다
-- (클라이언트가 보낸 값을 그대로 믿지 않는다는 원칙). 멤버십 자체는 PartyState가 갖고,
-- 이 스크립트는 "지금 이 조작이 허용되는가"의 교차 검사(견습·보스전)만 얹는다 - PartyState가
-- TutorialState/BossEncounter를 require하면 순환이 생기기 때문(PartyState.lua 상단 주석).
--
-- 24-2(PRD 20.63) 추가 action: create(파티 만들기 - 코드 발급), joincode(코드로 합류 - 다른 서버면
-- 텔레포트), invite_remote(다른 서버의 친구 초대 - MessagingService), cancel_join(합류 대기 취소).
-- accept/decline은 로컬 초대(PartyState)와 원격 초대(PartyCrossServer) 둘 다 처리한다 - 클라이언트는
-- 어느 쪽인지 모른다(토스트 버튼은 하나). RemoteFunction PartyFriendsFetch: 다른 서버에 있는 온라인 친구 목록.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PartyConfig = require(ReplicatedStorage.Shared.data.PartyConfig)
local PartyState = require(script.Parent.PartyState)
local TutorialState = require(script.Parent.TutorialState)
local BossEncounter = require(script.Parent.BossEncounter)
local Text = require(ReplicatedStorage.Shared.Text)
local PlayerProfile = require(script.Parent.PlayerProfile)
local PartyCrossServer = require(script.Parent.PartyCrossServer)
local PartyVote = require(script.Parent.PartyVote)
local PartyJoinRules = require(script.Parent.PartyJoinRules)
local FriendNotice = require(script.Parent.FriendNotice)

local partyRequest = Instance.new("RemoteEvent")
partyRequest.Name = "PartyRequest"
partyRequest.Parent = ReplicatedStorage

local partyFriendsFetch = Instance.new("RemoteFunction")
partyFriendsFetch.Name = "PartyFriendsFetch"
partyFriendsFetch.Parent = ReplicatedStorage

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
	tutorial_self = "견습 모드 중에는 파티에 들어갈 수 없습니다", -- 다른 서버로 가는 길(코드 파티 만들기 · 코드 합류 · 원격 초대)만 남았다 - 같은 서버의 초대 · 수락은 견습 중에도 된다(S12)
	in_boss = "보스전 중에는 파티원을 바꿀 수 없습니다",
	no_profile = "아직 준비되지 않은 플레이어입니다",
	joining = "합류 중에는 할 수 없습니다",
	service_unavailable = "파티 서비스에 연결할 수 없습니다. 잠시 후 다시 시도하세요",
}

local function fail(player, reason)
	PartyState.notify(player, REASON_TEXT[reason] or PartyCrossServer.REASON_TEXT[reason] or ("실패: " .. tostring(reason)))
end

-- 파티 구성 변경(초대·수락)의 공통 금지 조건은 PartyJoinRules에 있다(S12 - 자동 검증이 같은 함수를 부른다).
local checkJoinable = PartyJoinRules.checkJoinable

-- 내가 파티를 만들거나 다른 서버로 초대를 보낼 수 있는 상태인가(프로필·견습·합류 중). 견습 중이면 다른 서버로 나가는 길은 여전히 막는다(S12 범위 밖 - 텔레포트 뒤 견습 재개는 검증한 적이 없다).
local function checkSelf(player)
	if not PlayerProfile.getProfile(player) then
		return "no_profile"
	end
	if TutorialState.isActive(player) then
		return "tutorial_self"
	end
	if PartyCrossServer.isJoining(player) then
		return "joining"
	end
	return nil
end

-- 친구 목록 조회 스로틀 - 플레이어당 joinPollSeconds에 한 번(GetFriendsAsync는 페이지 단위 웹 호출).
local lastFriendsFetch = setmetatable({}, { __mode = "k" })
local cachedFriends = setmetatable({}, { __mode = "k" })

partyFriendsFetch.OnServerInvoke = function(player)
	local now = os.clock()
	if lastFriendsFetch[player] and now - lastFriendsFetch[player] < PartyConfig.joinPollSeconds then
		return cachedFriends[player] or {}
	end
	lastFriendsFetch[player] = now
	local list = PartyCrossServer.getOnlineFriendsElsewhere(player)
	cachedFriends[player] = list
	return list
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
	elseif action == "invite_remote" then
		-- 24-2: 다른 서버의 친구. 같은 서버에 있으면 PartyCrossServer가 로컬 초대로 돌린다.
		if type(arg) ~= "number" or arg == player.UserId then
			return
		end
		local blocked = checkSelf(player)
		if not blocked and BossEncounter.getActive(player) then
			blocked = "in_boss"
		end
		if blocked then
			fail(player, blocked)
			return
		end
		local target = Players:GetPlayerByUserId(arg)
		if target then
			local localBlocked = checkJoinable(player, target)
			if localBlocked then
				fail(player, localBlocked)
				return
			end
		end
		local ok, reason = PartyCrossServer.inviteRemote(player, arg)
		if not ok then
			fail(player, reason)
		else
			PartyState.notify(player, target and ("%s님을 초대했습니다"):format(target.Name) or "다른 서버의 친구에게 초대를 보냈습니다")
		end
	elseif action == "create" then
		-- 24-2: 초대 없이 파티를 만들어 코드를 받는다(다른 서버의 친구에게 코드로 알려 주는 경로).
		local blocked = checkSelf(player)
		if blocked then
			fail(player, blocked)
			return
		end
		local party, reason = PartyState.create(player)
		if reason then
			fail(player, reason)
			return
		end
		task.spawn(function()
			local code = PartyCrossServer.ensureCode(party)
			if code then
				PartyState.notify(player, ("파티를 만들었습니다 - 코드 %s"):format(code))
			else
				fail(player, "service_unavailable")
			end
		end)
	elseif action == "joincode" then
		-- 24-2: 코드로 합류. 같은 서버면 즉시, 다른 서버면 좌석 예약 → (대기) → 저장 → 텔레포트.
		if type(arg) ~= "string" then
			return
		end
		local blocked = checkSelf(player)
		if blocked then
			fail(player, blocked)
			return
		end
		if BossEncounter.getActive(player) then
			BossEncounter.despawnFor(player) -- 합류하는 순간 자기 솔로 보스는 물러난다(수락 경로와 같다)
		end
		task.spawn(PartyCrossServer.requestJoin, player, arg)
	elseif action == "cancel_join" then
		if not PartyCrossServer.cancelJoin(player) then
			PartyState.notify(player, "취소할 합류 대기가 없습니다")
		end
	elseif action == "accept" or action == "decline" then
		local accept = action == "accept"
		if PartyState.hasPendingInvite(player) then
			if accept then
				local party = PartyState.getPendingInviteParty(player)
				local leader = PartyState.getLeader(party)
				if not leader then
					fail(player, "party_gone")
					PartyState.respondInvite(player, false)
					return
				end
				-- G1-5 우회로 막기: 보스가 살아 있는 동안 초대를 받으면 보스전이 −1 없이 끝났다(합류가 솔로 보스를 물린다) - 포기로만 나간다.
				if BossEncounter.getActive(player) ~= nil then
					PartyState.notify(player, Text.get("boss.blockedInvite"))
					PartyState.respondInvite(player, false)
					return
				end
				local blocked = checkJoinable(leader, player)
				if blocked then
					fail(player, blocked)
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
		elseif PartyCrossServer.hasRemoteInvite(player) then
			-- 24-2: 다른 서버에서 온 초대 - 수락은 코드 합류와 같은 파이프라인이다.
			if accept then
				local blocked = checkSelf(player)
				if not blocked and PartyState.getParty(player) then
					blocked = "already_in_party"
				end
				if blocked then
					fail(player, blocked)
					PartyCrossServer.respondRemoteInvite(player, false)
					return
				end
				if BossEncounter.getActive(player) then
					BossEncounter.despawnFor(player)
				end
			end
			local ok, reason = PartyCrossServer.respondRemoteInvite(player, accept)
			if not ok then
				fail(player, reason)
			end
		else
			fail(player, "no_invite")
		end
	elseif action == "leave" then
		if PartyCrossServer.cancelJoin(player) then
			return -- 합류 대기 중이면 "탈퇴" = 대기 취소
		end
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
			-- 24-2: 원격 좌석(아직 도착 전)도 리더가 취소할 수 있다.
			local party = PartyState.getParty(player)
			if party and PartyState.isLeader(player) and PartyState.hasPendingSeat(party, arg) then
				PartyState.removePendingSeat(party, arg)
				return
			end
			fail(player, reason)
		end
	elseif action == "vote_agree" or action == "vote_reject" then
		-- 25-3: 스테이지 이동 투표 응답. 어느 파티의 어느 투표인지는 PartyVote가 자체
		-- 상태로 안다 - 여기선 "이 사람이 지금 속한 파티"만 넘긴다.
		local party = PartyState.getParty(player)
		if party then
			PartyVote.cast(party, player, action == "vote_agree")
		end
	end
end)

-- 친구가 같은 서버에 들어오면 기존 멤버에게 [파티 초대] 토스트(S12).
FriendNotice.start()

print("[forge-game] PartyServer 로드됨 - 파티 초대/수락/탈퇴/추방 + 크로스서버(코드·원격 초대) 활성")
