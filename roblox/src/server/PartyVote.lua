-- 25-3(PRD 20.47 [6](라) "입장 수락 팝업 10초"를 20.62에서 조작 수 최소화 이유로 안 만들었던
-- 부분을 투표로 대체) 파티 보스 진입 투표. 리더가 보스 스테이지로 이동을 시도하면 다른 멤버
-- 전원에게 동의/거절을 묻는다 - 과반이 아니라 리더 표 포함 2명(=다른 멤버 중 1명)만 동의하면
-- 성립한다. StageServer.server.lua가 checkPartyEntry 통과 뒤 이 모듈을 불러, 통과하면 콜백
-- (spawnForParty)을 실행한다. 파티당 진행 중인 투표는 하나뿐이다 - 잡몹 스테이지 이동은 각자
-- 자유라 이 모듈과 무관(호출부가 보스 스테이지 이동일 때만 부른다).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PartyConfig = require(ReplicatedStorage.Shared.data.PartyConfig)
local PartyState = require(script.Parent.PartyState)

local partyVoteNotice = Instance.new("RemoteEvent")
partyVoteNotice.Name = "PartyVoteNotice"
partyVoteNotice.Parent = ReplicatedStorage

local PartyVote = {}

-- party -> { targetStage, leader, others = {player,...}, agreed = {[player]=true}, onResolve, token }
local votes = {}
local tokenCounter = 0

local function fireTo(players, data)
	for _, p in ipairs(players) do
		if typeof(p) == "Instance" and p.Parent then
			partyVoteNotice:FireClient(p, data)
		end
	end
end

local function countAgreed(vote)
	local n = 0
	for _ in pairs(vote.agreed) do
		n += 1
	end
	return n
end

local function finish(party, passed)
	local vote = votes[party]
	if not vote then
		return
	end
	votes[party] = nil
	local result = passed and "passed" or "failed"
	fireTo(vote.others, { result = result, stage = vote.targetStage })
	fireTo({ vote.leader }, { result = result, stage = vote.targetStage, isLeader = true })
	if not passed then
		PartyState.notify(vote.leader, "투표가 성립하지 않았습니다(제한시간 초과 - 아무도 동의하지 않음)")
	end
	vote.onResolve(passed)
end

-- 이미 진행 중인 투표가 있으면 false(호출부가 그 자리에서 이동 자체를 거절한다 - 보스전
-- 중에는 투표가 안 뜨는 것과 같은 계통: "지금은 안 된다"). 다른 멤버가 없으면(사실상 혼자)
-- 투표 없이 즉시 onResolve(true)를 부르고 true를 돌려준다.
function PartyVote.start(party, leader, targetStage, onResolve)
	if votes[party] then
		return false
	end

	local others = {}
	for _, member in ipairs(PartyState.getMemberPlayers(party)) do
		if member ~= leader then
			table.insert(others, member)
		end
	end
	if #others == 0 then
		onResolve(true)
		return true
	end

	tokenCounter += 1
	local token = tokenCounter
	votes[party] = {
		targetStage = targetStage,
		leader = leader,
		others = others,
		agreed = { [leader] = true }, -- 리더 표는 자동 포함(지시: "파티장 포함 2명이면 성립").
		onResolve = onResolve,
		token = token,
	}

	fireTo(others, {
		result = "start",
		leaderName = leader.Name,
		stage = targetStage,
		seconds = PartyConfig.stageVoteTimeoutSeconds,
	})
	fireTo({ leader }, {
		result = "start",
		leaderName = leader.Name,
		stage = targetStage,
		seconds = PartyConfig.stageVoteTimeoutSeconds,
		isLeader = true,
	})

	task.delay(PartyConfig.stageVoteTimeoutSeconds, function()
		local vote = votes[party]
		if not vote or vote.token ~= token then
			return -- 이미 해석됐거나(누군가 동의해 조기 성립) 다른 투표로 교체됨
		end
		finish(party, countAgreed(vote) >= 2)
	end)

	return true
end

-- 투표 대상 멤버의 응답. 거절·무응답은 똑같이 "동의 아님"으로만 집계한다(지시 - 둘을
-- 구분하는 별도 상태를 만들지 않는다). 동의가 2명(리더 포함)에 닿으면 그 자리에서 바로 성립.
function PartyVote.cast(party, member, agree)
	local vote = votes[party]
	if not vote then
		return
	end
	local isTarget = false
	for _, other in ipairs(vote.others) do
		if other == member then
			isTarget = true
			break
		end
	end
	if not isTarget then
		return
	end
	vote.agreed[member] = agree or nil
	if countAgreed(vote) >= 2 then
		finish(party, true)
	end
end

-- 투표 도중 파티 구성이 바뀌면(리더 이탈·해산 등) 콜백 없이 정리만 한다 - 이동 자체가
-- 더 이상 의미가 없어진 상태라 "무산" 알림도 보내지 않는다.
function PartyVote.cancel(party)
	votes[party] = nil
end

PartyState.onMemberRemoved(function(_, party)
	if votes[party] then
		PartyVote.cancel(party)
	end
end)

return PartyVote
