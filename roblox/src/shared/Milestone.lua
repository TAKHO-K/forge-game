-- 환생 후 레벨 마일스톤 규칙(P2.5b D) - 순수 함수. 데이터 = MilestoneData. 서버(PlayerProfile.claimMilestones)가 기록하고 클라(성장 보상 창 · 토스트)가 같은 함수로 보인다.
-- 기록 모양: classState.milestones = { [tostring(환생 회차)] = 그 회차에서 받은 마지막 능력치 마일스톤 레벨(50의 배수) } · profile.milestoneUnlocks = 받은 해금 개수(0 ~ #unlocks).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InfiniteStageConfig = require(ReplicatedStorage.Shared.data.InfiniteStageConfig)
local MilestoneData = require(ReplicatedStorage.Shared.data.MilestoneData)
local Sanitize = require(ReplicatedStorage.Shared.Sanitize)

local Milestone = {}

-- 이 레벨까지 받을 수 있는 마지막 능력치 마일스톤 레벨(50의 배수, 50 미만이면 0).
function Milestone.claimedLevelFor(level)
	return math.floor((level or 0) / MilestoneData.statInterval) * MilestoneData.statInterval
end

-- 다음 능력치 마일스톤 레벨.
function Milestone.nextStatLevel(level)
	return Milestone.claimedLevelFor(level) + MilestoneData.statInterval
end

-- 이 레벨까지 받을 수 있는 해금 개수(목록 길이가 상한).
function Milestone.unlockCountFor(level)
	return math.min(#MilestoneData.unlocks, math.floor((level or 0) / MilestoneData.unlockInterval))
end

-- k번째 해금이 열리는 레벨.
function Milestone.unlockLevel(index)
	return index * MilestoneData.unlockInterval
end

-- 능력치 마일스톤 총 횟수 = 회차마다 받은 마지막 레벨 ÷ 50의 합.
function Milestone.statCount(milestones)
	local count = 0
	for _, claimed in pairs(milestones or {}) do
		if type(claimed) == "number" then
			count += math.floor(claimed / MilestoneData.statInterval)
		end
	end
	return count
end

-- 영구 능력치 배율(공격력) = k^(1.5 × 횟수). NaN · inf는 1로 끊는다.
function Milestone.multiplier(count)
	return Sanitize.number(InfiniteStageConfig.growthRate ^ (MilestoneData.statStagesPerMilestone * (count or 0)), 1)
end

-- 최대 체력 배율 - MilestoneData.survival이 켜져 있을 때만 공격력과 같은 배율(기본 1).
function Milestone.maxHpMultiplier(count)
	return MilestoneData.survival and Milestone.multiplier(count) or 1
end

-- 영구 능력치가 붙는 곳의 표시 글("공격력" 또는 "공격력 · 최대 체력").
function Milestone.statText()
	return MilestoneData.survival and "공격력 · 최대 체력" or "공격력"
end

-- 스테이지 환산(보고용) = 1.5 × 횟수.
function Milestone.stageEquivalent(count)
	return MilestoneData.statStagesPerMilestone * (count or 0)
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

-- 기록 갱신 계산(서버가 적용한다): 환생 회차 · 지금 레벨 · 지금 기록 → { cycleKey, claimedLevel(새 값), statGained, unlockFrom, unlockTo }. 환생 0회면 아무것도 없다.
function Milestone.plan(rebirthCount, level, milestones, unlockCount)
	if (rebirthCount or 0) < 1 then
		return nil
	end
	local key = tostring(rebirthCount)
	local before = (milestones and milestones[key]) or 0
	local after = math.max(before, Milestone.claimedLevelFor(level))
	local unlockAfter = math.max(unlockCount or 0, Milestone.unlockCountFor(level))
	return {
		cycleKey = key,
		claimedLevel = after,
		statGained = math.floor(after / MilestoneData.statInterval) - math.floor(before / MilestoneData.statInterval),
		unlockFrom = (unlockCount or 0) + 1,
		unlockTo = unlockAfter,
	}
end

return Milestone
