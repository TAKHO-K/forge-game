-- 환생 후 레벨 마일스톤 규칙(P2.5b D · P2.5c B2 재설계) - 순수 함수. 데이터 = MilestoneData(사다리 설명은 그 파일 머리). 서버(PlayerProfile.claimMilestones)가 기록하고
-- 클라(성장 보상 창 · 토스트) · 시뮬(EconSim)이 같은 함수로 계산한다.
-- 기록 모양(v33): classState.milestoneLevel = 그 직업이 받은 마지막 능력치 마일스톤 레벨(0 = 없음 · 200 · 250 · 300 …) · profile.milestoneUnlocks = 받은 해금 개수.
-- 버킷(합연산) = 받은 마지막 레벨에서 바로 나온다(레벨 200 = 큰 보상 · 그 뒤 50마다 작은 보상, 상한 capRatio − 1) - 회차 기록 표가 필요 없다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InfiniteStageConfig = require(ReplicatedStorage.Shared.data.InfiniteStageConfig)
local MilestoneData = require(ReplicatedStorage.Shared.data.MilestoneData)
local Sanitize = require(ReplicatedStorage.Shared.Sanitize)

local Milestone = {}

-- 이 직업이 사다리에 들어섰는가(환생 requiredRebirths회 완료).
function Milestone.isEligible(rebirthCount)
	return (rebirthCount or 0) >= MilestoneData.requiredRebirths
end

-- 이 레벨까지 받을 수 있는 마지막 능력치 마일스톤 레벨(firstLevel 미만이면 0 · 그 뒤 statInterval 배수).
function Milestone.claimedLevelFor(level)
	level = level or 0
	if level < MilestoneData.firstLevel then
		return 0
	end
	return MilestoneData.firstLevel + math.floor((level - MilestoneData.firstLevel) / MilestoneData.statInterval) * MilestoneData.statInterval
end

-- 다음 능력치 마일스톤 레벨.
function Milestone.nextStatLevel(level)
	local claimed = Milestone.claimedLevelFor(level)
	return claimed == 0 and MilestoneData.firstLevel or claimed + MilestoneData.statInterval
end

-- 받은 능력치 마일스톤 개수(큰 보상 1 + 작은 보상 n) - 표시 · 토스트용.
function Milestone.statCountFor(claimedLevel)
	if (claimedLevel or 0) < MilestoneData.firstLevel then
		return 0
	end
	return 1 + math.floor((claimedLevel - MilestoneData.firstLevel) / MilestoneData.statInterval)
end

-- 버킷 상한(합) = capRatio − 1.
function Milestone.bonusCap()
	return MilestoneData.capRatio - 1
end

-- 버킷 값(합연산) = min(상한, 큰 보상 + 작은 보상 × 개수). 받은 마지막 레벨이 firstLevel 미만이면 0.
function Milestone.bonusFor(claimedLevel)
	local count = Milestone.statCountFor(claimedLevel)
	if count == 0 then
		return 0
	end
	return math.min(Milestone.bonusCap(), MilestoneData.bigBonus + MilestoneData.smallBonus * (count - 1))
end

-- 버킷이 상한에 닿는 마일스톤 레벨(표시 · 보고용).
function Milestone.capLevel()
	local smallCount = math.ceil((Milestone.bonusCap() - MilestoneData.bigBonus) / MilestoneData.smallBonus - 1e-9)
	return MilestoneData.firstLevel + math.max(0, smallCount) * MilestoneData.statInterval
end

-- 버킷 배율 = 1 + 버킷(NaN · inf는 1로 끊는다).
function Milestone.multiplier(claimedLevel)
	return Sanitize.number(1 + Milestone.bonusFor(claimedLevel), 1)
end

-- 공격력 · 최대 체력 배율 - MilestoneData.stat이 가리키는 쪽만 버킷 배율, 다른 쪽은 1.
function Milestone.attackMultiplier(claimedLevel)
	return MilestoneData.stat == "attack" and Milestone.multiplier(claimedLevel) or 1
end

function Milestone.maxHpMultiplier(claimedLevel)
	return MilestoneData.stat == "survival" and Milestone.multiplier(claimedLevel) or 1
end

-- 버킷이 붙는 곳의 표시 글.
function Milestone.statText()
	return MilestoneData.stat == "survival" and "최대 체력" or "공격력"
end

-- 스테이지 환산(보고 · 표시) = ln(1 + 버킷) ÷ ln k.
function Milestone.stageEquivalent(claimedLevel)
	return math.log(Milestone.multiplier(claimedLevel)) / math.log(InfiniteStageConfig.growthRate)
end

-- 이 레벨까지 받을 수 있는 해금 개수(firstLevel = 1번째, 그 뒤 unlockInterval마다 다음 - 목록 길이가 상한).
function Milestone.unlockCountFor(level)
	level = level or 0
	if level < MilestoneData.firstLevel then
		return 0
	end
	return math.min(#MilestoneData.unlocks, 1 + math.floor((level - MilestoneData.firstLevel) / MilestoneData.unlockInterval))
end

-- k번째 해금이 열리는 레벨.
function Milestone.unlockLevel(index)
	return MilestoneData.firstLevel + (index - 1) * MilestoneData.unlockInterval
end

-- 받은 해금들의 효과 합.
function Milestone.inheritDiscount(unlockCount)
	local total = 0
	for index = 1, math.min(unlockCount or 0, #MilestoneData.unlocks) do
		total += MilestoneData.unlocks[index].inheritDiscount or 0
	end
	return total
end

function Milestone.bagSlotsBonus(unlockCount)
	local total = 0
	for index = 1, math.min(unlockCount or 0, #MilestoneData.unlocks) do
		total += MilestoneData.unlocks[index].bagSlots or 0
	end
	return total
end

-- 기록 갱신 계산(서버가 적용한다): 환생 횟수 · 지금 레벨 · 받은 마지막 레벨 · 받은 해금 개수 → { claimedLevel(새 값), statGained, bonusBefore, bonusAfter, unlockFrom, unlockTo }.
-- 사다리 밖(환생 5회 전)이면 nil.
function Milestone.plan(rebirthCount, level, claimedLevel, unlockCount)
	if not Milestone.isEligible(rebirthCount) then
		return nil
	end
	local before = claimedLevel or 0
	local after = math.max(before, Milestone.claimedLevelFor(level))
	return {
		claimedLevel = after,
		statGained = Milestone.statCountFor(after) - Milestone.statCountFor(before),
		bonusBefore = Milestone.bonusFor(before),
		bonusAfter = Milestone.bonusFor(after),
		unlockFrom = (unlockCount or 0) + 1,
		unlockTo = math.max(unlockCount or 0, Milestone.unlockCountFor(level)),
	}
end

return Milestone
