-- C1 토벌 스테이지 규칙(순수) - 토벌 입장 경로는 BR2에서 만든다. 그 경로가 이 함수들과 서버 BossGate.raidCheck만 부른다.
--   토벌 스테이지 = min(지금 선택 스테이지, 가장 최근(= 가장 높은) 클리어 보스 스테이지). 보스 레벨 · 드랍 itemLevel(보스 규칙 ArmorData.bossItemLevelDelta +0 · +7 · +15) 모두 이 값 기준.
--   미클리어 보스 스테이지에 서 있는 동안은 토벌 불가(일반 스테이지 · 깬 보스 스테이지에서만 입장).
--   파티 = 멤버마다 자기 토벌 스테이지(드랍), 보스 레벨 = 멤버 중 최고(잡몹 기준 스테이지와 같은 1번 규칙 - 낮은 멤버가 입장해 보스를 낮추는 길 없음).
--   원격 입장 = 그 보스 관문이 등록돼 있을 때만(SAVE v40 world.bossGates - BossGate.usableFor).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossRules = require(ReplicatedStorage.Shared.BossRules)

local RaidRules = {}

-- 클리어한 보스가 없으면 nil.
function RaidRules.raidStage(currentStage, bestBossCleared)
	if type(currentStage) ~= "number" or type(bestBossCleared) ~= "number" or bestBossCleared < BossData.stageInterval then
		return nil
	end
	return math.max(1, math.min(currentStage, bestBossCleared))
end

-- 이 보스가 처음 나오는 스테이지(배치표 한 바퀴 안에서 찾는다).
function RaidRules.firstStageOf(bossId)
	local laps = BossData.placement.laps
	local span = BossData.stageInterval * #laps[1] * #laps
	for stage = BossData.stageInterval, span, BossData.stageInterval do
		if BossRules.bossIdForStage(stage) == bossId then
			return stage
		end
	end
	return nil
end

-- 반환: ok, 이유("no_clear" · "boss_stage_uncleared" · "boss_not_met" · "gate_unregistered"), 토벌 스테이지.
-- input = { currentStage, bestBossCleared, bossId, remote(원격 입장인가), gateUsable(관문 등록 - 본인 또는 파티) }
function RaidRules.check(input)
	local stage = RaidRules.raidStage(input.currentStage, input.bestBossCleared)
	if stage == nil then
		return false, "no_clear", nil
	end
	if BossRules.isBossStage(input.currentStage) and input.currentStage > input.bestBossCleared then
		return false, "boss_stage_uncleared", nil
	end
	local first = RaidRules.firstStageOf(input.bossId)
	if first == nil or first > input.bestBossCleared then
		return false, "boss_not_met", nil
	end
	if input.remote and not input.gateUsable then
		return false, "gate_unregistered", nil
	end
	return true, nil, stage
end

-- 파티 보스 레벨 = 멤버 토벌 스테이지 중 최고.
function RaidRules.partyBossStage(memberRaidStages)
	local top = nil
	for _, stage in ipairs(memberRaidStages) do
		if top == nil or stage > top then
			top = stage
		end
	end
	return top
end

return RaidRules
