-- G1-4 보스맵 잔류 선택(D0 결정 5 · 사용자 확정). BossEncounter.enterLinger가 잔류를 시작하면 멤버마다 선택 창을 열고(Remote BossLinger), 고른 것을 처리한다.
--   next  = 그 사람의 스테이지를 보스 스테이지 + 1로(이동 규칙 = 최고 + 1 · 보스 게이트 - 못 가면 마을) 옮기고 보스맵에서 빠진다
--   retry = 솔로면 바로, 파티면 리더만 신청 → 재투표(PartyVote) 통과 시 같은 슬롯에 보스를 다시 세운다(남아 있는 멤버만)
--   town  = 스테이지는 그대로 두고 사냥터(마을)로
--   lingerSeconds(90) 동안 아무것도 안 고른 사람은 next(잠수 대비). 마지막 멤버가 빠지면 슬롯이 반납된다(BossEncounter.leaveFor).
-- 가방이 가득이라 못 넣은 보스 장비는 그 사람이 사냥터로 돌아가는 순간 발밑에 떨어뜨린다(holdDrops → BossEncounter.onMemberReturned).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossRules = require(ReplicatedStorage.Shared.BossRules)
local InfiniteStageConfig = require(ReplicatedStorage.Shared.data.InfiniteStageConfig)
local Text = require(ReplicatedStorage.Shared.Text)
local BossEncounter = require(script.Parent.BossEncounter)
local PlayerProfile = require(script.Parent.PlayerProfile)
local PartyState = require(script.Parent.PartyState)

local BossLinger = {}

local lingerEvent = Instance.new("RemoteEvent")
lingerEvent.Name = "BossLinger"
lingerEvent.Parent = ReplicatedStorage

local choiceEvent = Instance.new("RemoteEvent")
choiceEvent.Name = "BossLingerChoice"
choiceEvent.Parent = ReplicatedStorage

local heldDrops = setmetatable({}, { __mode = "k" }) -- [Player] = { entries, flush }

local function fire(player, payload)
	if typeof(player) == "Instance" and player:IsA("Player") then
		lingerEvent:FireClient(player, payload)
	end
end

-- 잔류 시작 → 멤버마다 창(남은 초 · 파티 여부 · 리더 여부 · 다음 스테이지로 갈 수 있는가).
local function canGoNext(player, stage)
	local target = stage + 1
	local best = PlayerProfile.getInfiniteStageBest(player)
	if type(best) ~= "number" then
		return false -- 프로필 없는 멤버(검증 스탠드인 등) - Play 1 오류
	end
	if target > best + 1 or target > InfiniteStageConfig.safeStageCap then
		return false
	end
	local required = BossRules.getBossStageBelow(target)
	return not (required > 0 and required > PlayerProfile.getBestBossCleared(player))
end

BossEncounter.onLingerStarted(function(encounter)
	for _, member in ipairs(encounter.members) do
		if typeof(member) ~= "Instance" then
			continue -- 스탠드인에게는 창이 없다
		end
		fire(member, {
			kind = "start", stage = encounter.stage, seconds = BossData.lingerSeconds,
			isParty = encounter.party ~= nil, isLeader = encounter.party == nil or PartyState.isLeader(member), canNext = canGoNext(member, encounter.stage),
		})
	end
end)

BossEncounter.onMemberReturned(function(player)
	local held = heldDrops[player]
	if held then
		heldDrops[player] = nil
		held.flush(held.entries, BossEncounter.huntingGroundReturnPosition())
	end
	fire(player, { kind = "end" })
end)

-- CombatResolution이 잔류일 때 부른다: deferred = { { player, item } } · flush = 떨어뜨리는 함수(사냥터로 돌아가는 순간 그 사람 몫만).
function BossLinger.holdDrops(deferred, flush)
	for _, entry in ipairs(deferred) do
		local held = heldDrops[entry.player]
		if not held then
			held = { entries = {}, flush = flush }
			heldDrops[entry.player] = held
		end
		table.insert(held.entries, entry)
	end
end

-- 보스전 멤버 중 실제 Player(투표 대상 - 리뷰 3).
function BossLinger.realMembers(encounter)
	local list = {}
	for _, member in ipairs(encounter.members) do
		if typeof(member) == "Instance" and member.Parent then
			table.insert(list, member)
		end
	end
	return list
end

-- 한 사람의 선택. 반환: 처리했는가, 결과 코드(검증 · 로그).
function BossLinger.choose(player, choice)
	local encounter = BossEncounter.getEncounter(player)
	if not encounter or not encounter.lingering then
		return false, "not_lingering"
	end
	if choice == "town" then
		BossEncounter.leaveFor(player)
		return true, "town"
	elseif choice == "next" then
		if canGoNext(player, encounter.stage) then
			PlayerProfile.setInfiniteStage(player, encounter.stage + 1)
			BossEncounter.leaveFor(player)
			return true, "next"
		end
		BossEncounter.leaveFor(player) -- 다음 스테이지로 못 가면(기여 부족으로 기록이 안 오른 파티원 등) 마을로
		PartyState.notify(player, Text.get("linger.cannotNext"))
		return true, "town_fallback"
	elseif choice == "retry" then
		if encounter.party == nil then
			return BossEncounter.retryLinger(encounter), "retry"
		end
		if not PartyState.isLeader(player) then
			PartyState.notify(player, Text.get("linger.leaderOnly"))
			return false, "not_leader"
		end
		local PartyVote = require(script.Parent.PartyVote)
		local started = PartyVote.start(encounter.party, player, encounter.stage, function(passed)
			if passed and encounter.lingering then
				BossEncounter.retryLinger(encounter)
				for _, member in ipairs(encounter.members) do
					fire(member, { kind = "end" })
				end
			end
		end, "retry", BossLinger.realMembers(encounter))
		return started, started and "vote" or "vote_busy"
	end
	return false, "bad_choice"
end

-- ═══ G1-5 보스 생존 중 포기(D0 결정 5 · 사용자 확정) ═══
-- 보스가 살아 있는 동안 스테이지 이동은 막힌다(StageServer). 대신 포기: 솔로 = 바로, 파티 = 포기 투표(PartyVote kind "giveup" - 요청한 사람 + 1명 동의).
-- 통과하면 그 보스전의 멤버 전원이 "도전 스테이지 − 1"로 내려가 마을로 돌아간다(보스는 물러난다). 같은 규칙: 파티 탈퇴 · 재접속(BossEncounter · StageServer).
function BossLinger.stepDown(player, bossStage)
	PlayerProfile.setInfiniteStage(player, math.max(1, bossStage - 1))
end

function BossLinger.giveUp(player)
	local encounter = BossEncounter.getEncounter(player)
	if not encounter or encounter.lingering or not encounter.model then
		return false, "no_boss"
	end
	if encounter.isTutorial then
		return false, "tutorial" -- 리뷰 4: 견습 보스는 포기 대상이 아니다(견습 흐름이 멈췄다)
	end
	local function apply()
		local members = table.clone(encounter.members)
		local stage = encounter.stage
		BossEncounter.despawnFor(members[1] or player)
		for _, member in ipairs(members) do
			if typeof(member) == "Instance" and member.Parent then
				BossLinger.stepDown(member, stage)
			end
		end
		print(("[forge-game] 보스 포기: 스테이지 %d → %d · %d명"):format(stage, math.max(1, stage - 1), #members))
	end
	if encounter.party == nil then
		apply()
		return true, "gave_up"
	end
	local PartyVote = require(script.Parent.PartyVote)
	local started = PartyVote.start(encounter.party, player, encounter.stage, function(passed)
		if passed and BossEncounter.getEncounter(player) == encounter and not encounter.lingering then
			apply()
		end
	end, "giveup", BossLinger.realMembers(encounter))
	return started, started and "vote" or "vote_busy"
end

local giveUpEvent = Instance.new("RemoteEvent")
giveUpEvent.Name = "BossGiveUp"
giveUpEvent.Parent = ReplicatedStorage
giveUpEvent.OnServerEvent:Connect(function(player)
	BossLinger.giveUp(player)
end)

choiceEvent.OnServerEvent:Connect(function(player, choice)
	if type(choice) ~= "string" then
		return
	end
	local ok, result = BossLinger.choose(player, choice)
	if ok and result == "retry" then
		local encounter = BossEncounter.getEncounter(player)
		for _, member in ipairs(encounter and encounter.members or { player }) do
			fire(member, { kind = "end" })
		end
	end
end)

-- 90초 무입력 → 남은 사람은 다음 스테이지(1초마다 검사).
local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < 1 then
		return
	end
	elapsed = 0
	local now = os.clock()
	for _, encounter in ipairs(BossEncounter.lingeringEncounters()) do
		if encounter.lingerUntil and now >= encounter.lingerUntil then
			for _, member in ipairs(table.clone(encounter.members)) do
				BossLinger.choose(member, "next")
			end
		end
	end
end)

return BossLinger
