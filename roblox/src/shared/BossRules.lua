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
-- 19-4: MonsterState.getAttackFor/getGoldDropFor/getExpRewardFor가 isBoss면 InfiniteStage를
-- 다시 곱하지 않고 data 필드를 그대로 돌려주도록 짜여 있다 - 여기서 계산한 값이 최종값
-- 그대로 유지된다. InfiniteStage 배율을 이중으로 다시 곱하는 사고를 구조적으로 막는다.
function BossRules.buildInstanceData(stage)
	local bossId = BossRules.pickBossId(stage)
	if not bossId then
		return nil
	end
	local boss = BossData.bosses[bossId]
	return BossRules.buildInstanceDataFrom(MonsterData.tier1, stage, boss, 1, 1)
end

-- 23-1 견습 모드 전용(BossData에 새 항목을 만들지 않는다 - 같은 보스 id에 patterns
-- 부분집합·tier 기반 trash 베이스만 다르게 넘긴다). tierIndex는 TutorialData.steps[n].tierIndex,
-- hpScale은 TutorialData.steps[n].bossHpScale(대여 무기 배율은 이 함수 밖에서 곱한다 -
-- patternKeys 필터와 함께 결과 테이블만 조정하면 되므로 buildInstanceDataFrom을 그대로 쓴다).
function BossRules.buildTutorialInstanceData(tierIndex, stage, patternKeys, hpScale, weaponMultiplier)
	local bossId = BossRules.pickBossId(BossData.stageInterval) -- 견습은 스테이지 구간과 무관 - 유일한 풀(pools[1])을 그대로 쓴다.
	if not bossId then
		return nil
	end
	local boss = BossData.bosses[bossId]
	local tierBase = MonsterData[MonsterData.tierOrder[tierIndex]] or MonsterData.tier1

	local data = BossRules.buildInstanceDataFrom(tierBase, stage, boss, tierIndex, hpScale * weaponMultiplier)
	data.isTutorial = true

	-- 패턴 부분집합(21-3 상태 머신이 없는 키를 만나면 안 되므로 BossPatterns.lua도 방어
	-- 처리를 같이 갖췄다 - 그쪽 주석 참고). heavy는 항상 포함(보스 데이터 자체의 상시 동작).
	local filteredPatterns = {}
	for _, key in ipairs(patternKeys) do
		filteredPatterns[key] = boss.patterns[key]
	end
	data.patterns = filteredPatterns

	return data
end

-- buildInstanceData/buildTutorialInstanceData 공용 - trashBase(MonsterData의 tier 항목)와
-- hpMultiplierExtra(견습 전용 배율, 일반 무한 모드는 1)만 다르다.
function BossRules.buildInstanceDataFrom(trashBase, stage, boss, tierIndex, hpMultiplierExtra)
	local trashHp = InfiniteStage.getMonsterHp(trashBase.hp, stage)
	local trashAttack = InfiniteStage.getMonsterAttack(trashBase.attack, stage)
	local trashGold = InfiniteStage.getGoldReward(trashBase.goldDrop, stage)
	local trashExp = InfiniteStage.getExpReward(trashBase.expReward, stage)

	local attack = trashAttack * boss.attackMultiplier

	return {
		id = boss.id,
		displayName = boss.displayName,
		isBoss = true,
		stageNumber = stage,
		-- 20-4: 재도전(첫 처치 아님) 드랍이 Loot.rollArmorDrop(dropGradeTableByTier)을 타면서
		-- tierIndex가 필요해졌다. 무한 모드 보스는 항상 tier1 기준으로 계산되므로(buildInstanceData가
		-- 1을 넘긴다) 1 고정 - Loot.rollBossFirstClearDrop의 tierIndex=1 고정과 같은 이유. 견습
		-- 모드 보스는 호출부(buildTutorialInstanceData)가 실제 tierIndex를 넘긴다.
		tierIndex = tierIndex,

		-- hpMultiplierExtra(23-1) - 견습 전용 보정(TutorialData.bossHpScale × 대여 무기 배율).
		-- 무한 모드는 항상 1이라(buildInstanceData 호출) 기존 계산과 완전히 같다.
		hp = trashHp * boss.hpMultiplier * hpMultiplierExtra,
		attack = attack,
		-- 21-3: heavyAttack(=attack×3) 필드는 없앴다 - 배율은 공격력이 아니라 감소식을 거친
		-- 피해에 곱한다(PlayerDamage.applyHit의 damageMultiplier, 이유는 그쪽 주석).
		heavyAttackMultiplier = boss.heavyAttackMultiplier,
		heavyAttackIntervalSeconds = boss.heavyAttackIntervalSeconds,
		telegraphWarmupSeconds = boss.telegraphWarmupSeconds,
		telegraphColor = boss.telegraphColor,

		goldDrop = math.floor(trashGold * boss.goldMultiplier),
		expReward = math.floor(trashExp * boss.expMultiplier),

		radiusPx = trashBase.radiusPx * boss.sizeScale,
		sizeScale = boss.sizeScale,
		bodyColor = boss.bodyColor,
		headColor = boss.headColor,
		moveSpeedStuds = boss.moveSpeedStuds,
		attackRangeStuds = boss.attackRangeStuds,
		attackCooldownSeconds = boss.attackCooldownSeconds,
		chaseStopDistanceStuds = boss.chaseStopDistanceStuds,

		-- 21-3 패턴 상수(BossPatterns.lua가 읽는다). 원본 테이블을 그대로 가리킨다 - 읽기
		-- 전용이라 공유해도 안전하다(BossData는 절대 런타임에 고치지 않는다).
		patterns = boss.patterns,
		patternMinGapSeconds = boss.patternMinGapSeconds,
		enragedHpFraction = boss.enragedHpFraction,
		enragedPatternMinGapSeconds = boss.enragedPatternMinGapSeconds,
		entryGraceSeconds = boss.entryGraceSeconds,
	}
end

return BossRules
