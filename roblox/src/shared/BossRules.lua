-- 무한 모드 보스 등장 규칙 + 스테이지별 실제 수치 계산이 곱해지는 유일한 위치(15-1,
-- InfiniteStage.lua와 같은 이유 - 계산 지점이 흩어지면 나중에 보스 풀이 여러 종으로
-- 늘어날 때마다 어디에 곱해야 할지 매번 찾아야 한다).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)
local InfiniteStageConfig = require(ReplicatedStorage.Shared.data.InfiniteStageConfig)
local PartyConfig = require(ReplicatedStorage.Shared.data.PartyConfig)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local BalanceSim = require(ReplicatedStorage.Shared.BalanceSim)

local bossPickRng = Random.new()
local rotationRng = Random.new()

local BossRules = {}

-- ═══ 파티 인원수 보스 HP 배수(23-5에서 자리만 분리 → 24-1에서 채움, PRD 20.62) ═══
-- HP_party(N) = HP_solo × N^p. 파티 N명의 총 DPS는 대략 N배이고 패턴 피해는 각자 따로 받으므로
-- 처치 시간은 T_N = T_1 × N^(p−1)이다 - p=1이면 이득 0, p=0이면 N배 빠르다.
--
-- p는 새 상수가 아니라 기존 값 셋에서 유도한다(지시 "BalanceAnchorConfig와 기존 지수식에서
-- 파생"): "정원(maxMembers)이 꽉 찬 파티의 시간 이득은 정확히 보스 한 구간(stageInterval)만큼"
-- - 4인 파티가 스테이지 S 보스를 잡는 시간 = 솔로가 직전 보스(S − stageInterval)를 잡는 시간.
-- 보스 HP가 스테이지당 k배로 자라므로(InfiniteStage.getMonsterHp) 직전 보스의 HP 비율은
-- k^(−stageInterval)이고, 이를 N_max^(p−1)과 같게 놓으면
--     N_max^(p−1) = k^(−stageInterval)  →  p = 1 − stageInterval · ln(k) / ln(N_max)
-- k=1.155, stageInterval=5, N_max=4 → p ≈ 0.480. 2/3/4인 처치 시간 = 솔로의 0.70/0.56/0.49배
-- ("유리하되 4배 빠르지는 않다"). 파티 하나가 진행을 앞당길 수 있는 폭이 보스 한 칸을
-- 넘지 않는다는 뜻이라 리더보드 축(최고 도달 스테이지)의 의미도 지킨다.
function BossRules.partyHpExponent()
	return 1 - BossData.stageInterval * math.log(InfiniteStageConfig.growthRate) / math.log(PartyConfig.maxMembers)
end

function BossRules.partySizeHpMultiplier(memberCount)
	local n = math.max(memberCount or 1, 1)
	return n ^ BossRules.partyHpExponent()
end

-- 파훼 게이트의 받는 피해 배율 g(29-1, PRD 20.73 [2-8] A-3) = N_max^(p−1) = 1/k^stageInterval ≈ 0.487.
-- 새 상수가 아니라 p와 같은 세 값에서 나온다 - 뜻: "기믹을 무시하는 정원 파티의 딜 = 기믹을 푸는
-- 솔로의 딜". 4명이 모여 기믹을 건너뛰어도 혼자 제대로 하는 것보다 나을 게 없다.
function BossRules.gateDamageTakenMultiplier()
	return PartyConfig.maxMembers ^ (BossRules.partyHpExponent() - 1)
end

-- 파티 보스 입장 밴드(PRD 20.47 [6](라) "불가" 밴드 재사용). 멤버 전원이
--     bossStage ≤ recommendedStage(L_i) + band
-- 를 만족해야 한다. band는 PRD 20.8-3 ①의 4직업 공통 콤보 배수((1+1+1.8)/3 ≈ 1.267)를
-- 스테이지로 환산한 값 ⌊ln(1.267)/ln(k)⌋ = 1 - "실력으로 메울 수 있는 격차"의 코드 기준 하한
-- (직업별 E 스킬 상한 +2·+3은 PRD가 잠정으로 표시한 값이라 새 상수로 넣지 않는다). 권장
-- 스테이지는 무기 등급을 안 본다(20.44 [2](나) 결정 그대로 - rec(L)).
function BossRules.partyEntryBand()
	local comboAvg = 1 + (CombatConfig.comboHitMultiplier - 1) / CombatConfig.comboHitEvery
	return math.floor(math.log(comboAvg) / math.log(InfiniteStageConfig.growthRate))
end

function BossRules.partyEntryStageCap(level)
	return BalanceSim.recommendedStage(level, 0, false) + BossRules.partyEntryBand()
end

-- 순환 상태(rotation = { order, index, pending, history })를 받아 다음 보스 id를
-- 뽑고 rotation을 제자리에서 갱신한다(23-5, PRD 20.50 [5] 설계).
--   - order가 비었거나 index가 이미 끝(6개 다 씀)에 도달했으면 다시 섞는다.
--   - 새로 섞은 order[1]이 직전 바퀴의 마지막(order[#order])과 같으면 2~6 중
--     무작위 위치와 맞바꾼다 - "같은 보스가 바퀴 경계에서 연속으로 나오지 않는다"를
--     이 한 번의 교환으로 보장한다(다시 섞기를 반복하지 않는다 - 분포 차이가 없다).
-- history는 관측·디버그용(DevTools "/gg boss history") - 순환 알고리즘 자체엔 안 쓰인다.
local ROTATION_HISTORY_LIMIT = 50

local function shuffleInPlace(rng, list)
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
end

-- history 기록 전용(23-5) - "/gg boss force"로 강제 지정된 보스도 실제로 등장은 했으므로
-- 정상 순환 뽑기와 똑같이 이력에 남긴다(PlayerProfile.getBossForStage가 두 경로 모두에서
-- 부른다) - 순환 알고리즘(order/index) 자체는 건드리지 않는다.
function BossRules.recordRotationHistory(rotation, bossId)
	rotation.history = rotation.history or {}
	table.insert(rotation.history, bossId)
	if #rotation.history > ROTATION_HISTORY_LIMIT then
		table.remove(rotation.history, 1)
	end
end

function BossRules.nextRotationBossId(rotation)
	local allIds = BossData.pools[1].bossIds
	if not rotation.order or #rotation.order == 0 or rotation.index > #rotation.order then
		local previousLast = rotation.order and rotation.order[#rotation.order]
		local newOrder = {}
		for _, id in ipairs(allIds) do
			table.insert(newOrder, id)
		end
		shuffleInPlace(rotationRng, newOrder)
		if previousLast and newOrder[1] == previousLast and #newOrder > 1 then
			local swapWith = rotationRng:NextInteger(2, #newOrder)
			newOrder[1], newOrder[swapWith] = newOrder[swapWith], newOrder[1]
		end
		rotation.order = newOrder
		rotation.index = 1
	end

	local bossId = rotation.order[rotation.index]
	rotation.index += 1
	BossRules.recordRotationHistory(rotation, bossId)

	return bossId
end

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
--
-- 23-5: bossId는 더 이상 여기서 무작위로 뽑지 않는다 - 호출부(BossEncounter.spawnFor)가
-- PlayerProfile의 순환 상태(BossRules.nextRotationBossId)로 미리 정한 값을 넘긴다.
-- BossRules는 여전히 "그 id로 인스턴스 데이터를 계산하는" 순수 함수만 갖는다 - PlayerProfile
-- (상태)을 이 shared 모듈이 직접 require하지 않기 위함(순수 규칙 모듈 유지).
-- partySize(24-1): 입장 인원(더미 포함 머릿수). 솔로는 1 - N^p = 1이라 기존 계산과 완전히 같다.
function BossRules.buildInstanceData(stage, bossId, partySize)
	local boss = BossData.bosses[bossId]
	if not boss then
		return nil
	end
	return BossRules.buildInstanceDataFrom(MonsterData.tier1, stage, boss, 1, 1, partySize or 1)
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

	local data = BossRules.buildInstanceDataFrom(tierBase, stage, boss, tierIndex, hpScale * weaponMultiplier, nil)
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
-- hpMultiplierExtra(견습 전용 배율, 일반 무한 모드는 1)만 다르다. partySize(24-1)는
-- partySizeHpMultiplier 전용 - 견습 호출부는 nil(=1)을 넘긴다(견습은 항상 싱글).
function BossRules.buildInstanceDataFrom(trashBase, stage, boss, tierIndex, hpMultiplierExtra, partySize)
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
		-- partySizeHpMultiplier(24-1) - 입장 인원 N의 N^p(위 partyHpExponent 주석). 솔로는 1.
		hp = trashHp * boss.hpMultiplier * hpMultiplierExtra * BossRules.partySizeHpMultiplier(partySize),
		partySize = partySize or 1,
		partyHpMultiplier = BossRules.partySizeHpMultiplier(partySize),
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
		-- 23-6 [3]: MonsterSpawner.buildModel이 실루엣(bodyAspect)·부착물(attachments)을
		-- 읽는 곳이 바로 이 인스턴스 데이터라서 여기 안 넣으면 6종이 스폰 시 전부 다시
		-- 똑같은 모양으로 보인다(BossData.bosses[id]에는 있어도 인스턴스 테이블로 안 넘어옴).
		bodyAspect = boss.bodyAspect,
		attachments = boss.attachments,
		primaryPattern = boss.primaryPattern,
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
		-- 29-1: 보스별 잡힘·구출 종류(BossData SPECIES_MECHANICS, 구간 수호자는 nil).
		mechanics = boss.mechanics,
	}
end

return BossRules
