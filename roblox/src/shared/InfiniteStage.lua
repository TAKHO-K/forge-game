-- 무한 모드 스테이지 배율이 실제로 곱해지는 유일한 위치(11-1, PlayerCombat·calcDamage와
-- 같은 이유 - 배율 적용 지점이 흩어지면 나중에 보스·몬스터 다양화가 들어올 때마다 어디에
-- 곱해야 할지 매번 찾아야 한다). 몬스터 HP·공격력·골드 보상 전부 이 모듈 하나를 거친다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InfiniteStageConfig = require(ReplicatedStorage.Shared.data.InfiniteStageConfig)

local InfiniteStage = {}

function InfiniteStage.getMultiplier(stage)
	return InfiniteStageConfig.growthRate ^ (stage - 1)
end

function InfiniteStage.getMonsterHp(baseHp, stage)
	return baseHp * InfiniteStage.getMultiplier(stage)
end

function InfiniteStage.getMonsterAttack(baseAttack, stage)
	return baseAttack * InfiniteStage.getMultiplier(stage)
end

-- 골드는 정수 화폐다(PlayerProfile.addGold가 그대로 더하는 값) - HP·공격력과 달리
-- 소수점을 남기지 않는다.
function InfiniteStage.getGoldReward(baseGold, stage)
	return math.floor(baseGold * InfiniteStage.getMultiplier(stage))
end

return InfiniteStage
