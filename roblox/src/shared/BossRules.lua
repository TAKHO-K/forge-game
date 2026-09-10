-- 무한 모드 보스 등장 규칙 + 스테이지별 실제 수치 계산이 곱해지는 유일한 위치(15-1,
-- InfiniteStage.lua와 같은 이유 - 계산 지점이 흩어지면 나중에 보스 풀이 여러 종으로
-- 늘어날 때마다 어디에 곱해야 할지 매번 찾아야 한다).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)

local bossPickRng = Random.new()

local BossRules = {}

function BossRules.isBossStage(stage)
	return stage >= BossData.stageInterval and stage % BossData.stageInterval == 0
end

-- targetStage보다 낮은 쪽에서 가장 가까운 보스 스테이지("아직 못 깼으면 여기서 막힌다"의
-- 기준점). 없으면 0 - StageServer가 "0이면 통과"로 그대로 쓸 수 있다.
function BossRules.getBossStageBelow(targetStage)
	local n = BossData.stageInterval
	return n * math.floor((targetStage - 1) / n)
end

-- 그 스테이지의 보스 풀 - minStage가 stage 이하인 것 중 가장 큰(가장 최근) 항목.
local function findPool(stage)
	local best = nil
	for _, pool in ipairs(BossData.pools) do
		if pool.minStage <= stage and (not best or pool.minStage > best.minStage) then
			best = pool
		end
	end
	return best
end

-- 풀 안에서 랜덤 하나(PRD 20.8-6 "구간별 보스 풀 + 풀 안에서 랜덤"). 지금은 풀마다
-- 종이 하나뿐이라 사실상 결정적이지만, 풀에 종이 늘어나도 호출부(BossEncounter)는
-- 안 바뀐다.
function BossRules.pickBossId(stage)
	local pool = findPool(stage)
	if not pool or #pool.bossIds == 0 then
		return nil
	end
	local index = bossPickRng:NextInteger(1, #pool.bossIds)
	return pool.bossIds[index]
end

-- 이 스테이지의 보스 인스턴스 데이터를 한 번만 계산해서 돌려준다(MonsterSpawner.spawn이
-- 그대로 받는 data 테이블 - MonsterData.tier1과 같은 모양이다). 매 스폰마다 새 테이블을
-- 만든다 - 여러 몬스터가 공유하는 MonsterData 원본과 달리 이건 플레이어 1인 전용이라
-- 공유 걱정이 없다.
--
-- stage=1로 고정해 둔 게 아니라 MonsterState.setStage가 isBoss 데이터는 아예 건드리지
-- 않도록 만들어서(그쪽 주석 참고), 여기서 계산한 값이 최종값 그대로 유지된다 -
-- InfiniteStage 배율을 이중으로 다시 곱하는 사고를 구조적으로 막는다.
function BossRules.buildInstanceData(stage)
	local bossId = BossRules.pickBossId(stage)
	if not bossId then
		return nil
	end
	local boss = BossData.bosses[bossId]
	local tier1 = MonsterData.tier1

	local trashHp = InfiniteStage.getMonsterHp(tier1.hp, stage)
	local trashAttack = InfiniteStage.getMonsterAttack(tier1.attack, stage)
	local trashGold = InfiniteStage.getGoldReward(tier1.goldDrop, stage)
	local trashExp = InfiniteStage.getExpReward(tier1.expReward, stage)

	local attack = trashAttack * boss.attackMultiplier

	return {
		id = boss.id,
		displayName = boss.displayName,
		isBoss = true,
		stageNumber = stage,

		hp = trashHp * boss.hpMultiplier,
		attack = attack,
		heavyAttack = attack * boss.heavyAttackMultiplier,
		heavyAttackIntervalSeconds = boss.heavyAttackIntervalSeconds,
		telegraphWarmupSeconds = boss.telegraphWarmupSeconds,
		telegraphColor = boss.telegraphColor,

		goldDrop = math.floor(trashGold * boss.goldMultiplier),
		expReward = math.floor(trashExp * boss.expMultiplier),

		radiusPx = tier1.radiusPx * boss.sizeScale,
		sizeScale = boss.sizeScale,
		bodyColor = boss.bodyColor,
		headColor = boss.headColor,
		moveSpeedStuds = boss.moveSpeedStuds,
		attackRangeStuds = boss.attackRangeStuds,
		attackCooldownSeconds = boss.attackCooldownSeconds,
	}
end

return BossRules
