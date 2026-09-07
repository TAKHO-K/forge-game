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

-- 경험치도 골드와 같은 이유로 정수·같은 k를 쓴다(13-2 - "몬스터가 세지는 속도"라는 하나의
-- 축으로 남긴다는 20.11-4/20.10의 원칙을 경험치에도 그대로 적용). 온커브 밖 감쇠는 넣지
-- 않는다 - 처치 시간이 몬스터 HP(같은 k)에 비례해 짧아지는 만큼 시간당 총 보상이 이미
-- 스테이지 무관에 가깝게 수렴해, 별도 페널티는 그 상쇄를 중복 적용하는 셈이다(PRD
-- 13-2 참고). 실측에서 낮은 스테이지 무한 파밍이 실제로 우위로 확인되면 재검토한다.
function InfiniteStage.getExpReward(baseExp, stage)
	return math.floor(baseExp * InfiniteStage.getMultiplier(stage))
end

return InfiniteStage
