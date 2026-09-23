-- 골드 비용이 계산되는 유일한 위치(P2 C1). 강화 · 옵션 변환권 · 방지권 가격이 전부 이 함수를 거친다 - 서버(차감)와 클라(표시)가 같은 함수를 부른다.
-- 곡선 · 기준 스테이지는 shared/data/GoldCostConfig.lua 주석 참고. 순수 함수다(플레이어를 모른다 - 스테이지는 호출부가 계정 최고 스테이지를 넘긴다).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GoldCostConfig = require(ReplicatedStorage.Shared.data.GoldCostConfig)
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)
local Sanitize = require(ReplicatedStorage.Shared.Sanitize)

local GoldCost = {}

-- 기준 스테이지 뒤로 골드 수입과 같은 비율로 커지는 배수(기준 스테이지 이하는 1). stage가 nil이면 1(기본 비용 그대로).
function GoldCost.scale(stage, kind)
	local anchor = GoldCostConfig.anchorStage[kind]
	assert(anchor, "GoldCost: 알 수 없는 비용 종류 " .. tostring(kind))
	if not stage or stage <= anchor then
		return 1
	end
	-- InfiniteStage.getMultiplier(n) = k^(n − 1) - 몬스터 골드와 같은 함수(수입과 비용이 한 식을 공유한다).
	return InfiniteStage.getMultiplier(stage - anchor + 1)
end

-- 비용 = floor(기본 비용 × 배수). 기준 스테이지 1인 종류는 floor(기본 × k^(s−1)) = InfiniteStage.getGoldReward(기본, s)와 같은 값이다.
-- 비정상 값(inf · NaN)은 math.huge로 끊는다 - trySpendGold가 항상 거절한다(공짜가 되는 쪽으로 새지 않는다).
function GoldCost.cost(baseCost, stage, kind)
	return Sanitize.number(math.floor(baseCost * GoldCost.scale(stage, kind)), math.huge)
end

return GoldCost
