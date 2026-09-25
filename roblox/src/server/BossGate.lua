-- M1 보스 관문 입장. 보스 스테이지를 고르면(StageServer) 스테이지만 옮기고 그 보스 구역의 관문까지 길 안내(Player Attribute BossGateZone)를 켠다 -
-- 관문 판을 밟으면(TravelServer 거리 폴링) 여기서 입장한다: 솔로 = 바로 · 파티 = 리더만 · 멤버 전원 검사(checkPartyEntry) · 입장 투표(PartyVote) → 파티 보스.
-- 입장한 사람은 관문 앞을 복귀 자리로 기록한다(BossEncounter.setReturnPoint - 잔류 [다음] · 포기 · 처치 뒤 복귀. [마을]은 허브).
-- WorldMapData.boss.entry = "direct"면 옛 즉시 입장(StageServer가 바로 스폰).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossRules = require(ReplicatedStorage.Shared.BossRules)
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)
local PlayerProfile = require(script.Parent.PlayerProfile)
local BossEncounter = require(script.Parent.BossEncounter)
local PartyState = require(script.Parent.PartyState)
local PartyVote = require(script.Parent.PartyVote)

local BossGate = {}

function BossGate.enabled()
	return WorldMapData.boss.entry == "gate"
end

-- 이 스테이지 보스의 구역(관문) 키 - 보스 id가 WorldMapData.zones[k].bossId인 구역. 새 보스가 구역 없이 들어오면 nil(그때는 즉시 입장).
function BossGate.zoneKeyForStage(stage)
	local bossId = BossRules.bossIdForStage(stage)
	for _, z in ipairs(WorldMapData.zones) do
		if z.bossId == bossId then
			return z.key
		end
	end
	return nil
end

-- 관문 앞 복귀 자리(관문 판에서 안쪽으로 한 걸음 - 다시 밟지 않게)
function BossGate.returnPoint(zoneKey)
	local zone = WorldMapLayout.zoneByKey(zoneKey)
	return WorldMapLayout.toWorld(zone, WorldMapData.layout.gate.r - WorldMapData.layout.gate.radius - 12, 0, 3)
end

-- 스테이지를 옮긴 뒤(StageServer) 길 안내 대상을 맞춘다: 보스 스테이지 = 그 관문 · 아니면 끔.
function BossGate.refreshGuide(player)
	local stage = PlayerProfile.getInfiniteStage(player)
	local zoneKey = stage and BossRules.isBossStage(stage) and BossGate.zoneKeyForStage(stage) or nil
	player:SetAttribute("BossGateZone", zoneKey)
	player:SetAttribute("BossGateStage", zoneKey and stage or nil)
end

-- 관문 판을 밟았다. 반환: 처리 결과 코드(로그 · 검증).
function BossGate.enter(player, zoneKey)
	local stage = PlayerProfile.getInfiniteStage(player)
	if not stage or not BossRules.isBossStage(stage) then
		return "not_boss_stage"
	end
	if BossEncounter.getEncounter(player) then
		return "in_encounter"
	end
	if BossGate.zoneKeyForStage(stage) ~= zoneKey then
		return "wrong_gate"
	end
	local party = PartyState.getParty(player)
	local back = BossGate.returnPoint(zoneKey)
	if party then
		if not PartyState.isLeader(player) then
			PartyState.notify(player, "보스 관문은 파티 리더가 연다")
			return "party_not_leader"
		end
		local blocked = BossEncounter.checkPartyEntry(party, stage)
		if #blocked > 0 then
			local names = {}
			for _, entry in ipairs(blocked) do
				table.insert(names, ("%s:%s"):format(entry.player.Name, entry.reason))
			end
			PartyState.notify(player, "파티 보스 입장 불가 - " .. table.concat(names, ", "))
			return "party_blocked"
		end
		local started = PartyVote.start(party, player, stage, function(passed)
			if passed and not BossEncounter.getEncounter(player) then
				for _, member in ipairs(BossEncounter.getEntryMembers(party)) do
					BossEncounter.setReturnPoint(member, back)
				end
				BossEncounter.spawnForParty(party, player, stage)
			end
		end)
		if not started then
			PartyState.notify(player, "이미 진행 중인 투표가 있습니다")
			return "vote_pending"
		end
		return "vote"
	end
	BossEncounter.setReturnPoint(player, back)
	BossEncounter.spawnFor(player, stage)
	return "entered"
end

return BossGate
