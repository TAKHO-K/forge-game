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
	-- InfiniteStage.getGoldMultiplier(n) = goldGrowthRate^(n − 1) - 몬스터 골드와 같은 함수(수입과 비용이 한 식을 공유한다). P2.5a: k 대신 골드 성장률.
	return InfiniteStage.getGoldMultiplier(stage - anchor + 1)
end

-- 비용 = floor(기본 비용 × 배수). 기준 스테이지 1인 종류는 floor(기본 × k^(s−1)) = InfiniteStage.getGoldReward(기본, s)와 같은 값이다.
-- 비정상 값(inf · NaN)은 math.huge로 끊는다 - trySpendGold가 항상 거절한다(공짜가 되는 쪽으로 새지 않는다).
function GoldCost.cost(baseCost, stage, kind)
	return Sanitize.number(math.floor(baseCost * GoldCost.scale(stage, kind)), math.huge)
end

-- QUEUE-ALL6 D 보상 골드 = "보기 좋은 숫자"(지급값 자체 - 표시만 반올림하지 않는다 · 서버 지급 · 클라 미리보기가 같은 함수):
--   1,000 미만 = 100 단위(최소 100) · 1,000 ~ 99,999 = 천 단위 · 100,000 이상 = 앞 두 자리만(12,345 → 12,000 · 1,234,567 → 1,200,000). 반올림 = 가까운 쪽(반은 올림).
function GoldCost.niceReward(n)
	n = Sanitize.number(n, 0)
	if n <= 0 or n == math.huge then
		return n
	end
	local step
	if n < 1000 then
		step = 100
	elseif n < 100000 then
		step = 1000
	else
		step = 10 ^ (math.floor(math.log10(n)) - 1)
	end
	return math.max(100, math.floor(n / step + 0.5) * step)
end

-- 퀘스트 · 출석 · 초반 여정 · 시즌 패스 보상 골드(QuestService.grant · RewardIcons 미리보기 - 같은 값). kills = 데이터의 "잡몹 몇 마리 몫"
function GoldCost.rewardGold(goldPerKill, kills, stage)
	return GoldCost.niceReward(GoldCost.cost(goldPerKill * kills, stage, "quest"))
end

return GoldCost
