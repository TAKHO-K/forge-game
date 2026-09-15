-- 몬스터 런타임 상태 단일 관리 통로. Humanoid.Health에 HP를 두지 않는다.
-- 확인 결과: Humanoid.Health/MaxHealth는 문서상 number(Lua 64비트 double)이지만,
-- 로블록스 내부적으로는 32비트 float로 저장되는 것으로 보고돼 있다(devforum: 값이 10^9
-- 근처만 가도 정밀도가 깨져 미세 조정이 불가능해짐). 우리 무한 모드는 1e308까지 가고
-- 그 위는 bignum{m,e}로 넘어가므로 애초에 Humanoid.Health로는 표현이 불가능하다.
-- 지금은 plain number로 두되, 나중에 bignum{m,e}로 바꿀 때 이 모듈만 고치면 되도록
-- 읽기/쓰기를 한 곳으로 모은다.
--
-- 19-4: 사냥터 잡몹(공유)과 보스(개인 인스턴스)가 서로 다른 HP 모델을 쓴다 - 반드시
-- isBoss로 분기해서 읽어야 한다.
--   보스(isBoss=true): 기존 그대로 절대값 hp/maxHp. BossRules.buildInstanceData가
--     스폰 시점에 이미 스테이지 배율을 곱해 최종값을 만들어 두므로(플레이어 1인 전용
--     인스턴스라 "누구 기준인가" 문제 자체가 없다), 여기서 추가로 배율을 곱하지 않는다.
--   잡몹(isBoss=false/nil): 절대값이 없다. hpRatio(0~1)만 저장한다 - 여러 플레이어가
--     서로 다른 stage를 갖고 같은 몬스터를 때리므로 "이 몬스터의 최대체력"이라는 절대
--     숫자 자체가 성립하지 않는다(19-4 [0] 조사, C안 채택). 대신 플레이어 P가 데미지 D를
--     넣으면 "P의 stage 기준 이 몬스터의 유효 최대체력"(InfiniteStage.getMonsterHp(data.hp,
--     P.stage))으로 나눈 비율만큼 공용 hpRatio 풀에서 뺀다 - 이 비율 자체는 "누구
--     기준인가"를 묻지 않는 값이라(0~1 사이, 보는 사람과 무관) HP바에 그대로 쓸 수 있다.
--     공격력·골드·경험치도 같은 이유로 "그 순간 계산 대상 플레이어의 stage"를 인자로
--     받는다(getAttackFor/getGoldDropFor/getExpRewardFor) - 몬스터 인스턴스 자체엔
--     stage를 저장하지 않는다(예전 setStage/getStage는 19-4에서 완전히 제거했다).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)
local MonsterPrefixData = require(ReplicatedStorage.Shared.data.MonsterPrefixData)
local TreasureChestConfig = require(ReplicatedStorage.Shared.data.TreasureChestConfig)

local MonsterState = {}

-- [Model] = { hp, maxHp(보스 전용, 잡몹은 nil), hpRatio(잡몹 전용, 보스는 nil),
--             contributions(잡몹 전용 - [Player]=누적 기여 비율, 보스는 nil),
--             data(스폰에 쓴 MonsterData/BossRules 항목 - 여러 몬스터 인스턴스가 같은
--             테이블을 공유하므로 절대 직접 고치지 않는다), spawnPosition(리스폰 자리),
--             aiState("idle"/"chasing"/"returning"), aiTarget(추격 중인 Player, 없으면 nil),
--             lastAttackTick(반격 쿨다운 기준 시각, os.clock()),
--             bossPattern(21-3, isBoss 인스턴스만 - 패턴 상태 머신의 가변 테이블. 내용은
--             BossPatterns.lua만 읽고 쓴다 - 15-1의 bossPhase/bossPhaseEndsAt/bossNextHeavyAt
--             세 필드를 이 테이블 하나로 대체했다. 여기 두는 이유는 "몬스터 런타임 상태는
--             이 모듈이 단일 통로"라는 원칙 - clear(model) 한 번에 같이 사라진다) }
local monsters = {}

-- variant(22-2) - 스폰 시점에 굴린 인스턴스별 변종 { isSparkle, prefix(MonsterPrefixData 항목
-- 또는 nil), isChest }. data는 여러 인스턴스가 공유하는 원본 테이블이라 변종 배율을 data에
-- 쓰지 않고 entry에만 둔다. 보스는 셋 다 없다(MonsterSpawner.spawn이 보스엔 안 굴린다).
--
-- 보물상자(isChest, 22-2 [3])는 HP 대신 피격 횟수를 센다 - chestHits(총 유효 피격 수),
-- chestLastHitAt([Player]=마지막 유효 피격 시각), chestHitters([Player]=true, 한 번이라도
-- 유효 피격을 낸 전원 - 보상 대상). 상자가 파괴·소멸되면 clear(model) 한 번에 이 셋이
-- 같이 사라진다(지시 "정리 항목" - 기록을 entry 밖에 두지 않는 이유).
function MonsterState.init(model, data, spawnPosition, zoneKey, variant)
	variant = variant or {}
	monsters[model] = {
		hp = data.isBoss and data.hp or nil,
		maxHp = data.isBoss and data.hp or nil,
		hpRatio = data.isBoss and nil or 1.0,
		contributions = data.isBoss and nil or {},
		data = data,
		spawnPosition = spawnPosition,
		zoneKey = zoneKey, -- 16-6, tier 구역 몬스터만 있음(보스는 nil).
		isSparkle = variant.isSparkle or false, -- 19-4 [6], 잡몹 전용(보스는 항상 false로 들어온다).
		prefix = variant.prefix, -- 22-2 [1], 잡몹 전용.
		isChest = variant.isChest or false, -- 22-2 [3].
		chestHits = 0,
		chestLastHitAt = {},
		chestHitters = {},
		aiState = "idle",
		aiTarget = nil,
		lastAttackTick = nil,
		bossPattern = data.isBoss and {} or nil,
	}
end

function MonsterState.isChest(model)
	local entry = monsters[model]
	return entry ~= nil and entry.isChest
end

function MonsterState.getPrefix(model)
	local entry = monsters[model]
	return entry and entry.prefix
end

-- 접두사 보상 배율(22-2 [1]) - 골드·경험치·드랍 확률이 전부 이 값을 곱는다(= HP 배율,
-- MonsterPrefixData 공평성 정의). 접두사가 없으면 1.
function MonsterState.getRewardMultiplier(model)
	local entry = monsters[model]
	return MonsterPrefixData.getRewardMultiplier(entry and entry.prefix)
end

-- 이동속도(22-2 [1]) - data.moveSpeedStuds × 접두사 배율. MonsterAI가 data를 직접 읽지 않고
-- 이 함수를 쓴다(인스턴스별 값이라 공유 data에 둘 수 없다).
function MonsterState.getMoveSpeed(model)
	local entry = monsters[model]
	if not entry then
		return 0
	end
	local multiplier = entry.prefix and entry.prefix.moveSpeedMultiplier or 1
	return entry.data.moveSpeedStuds * multiplier
end

-- 보물상자를 한 번이라도 유효 피격한 [Player]=true 집합(22-2 [3] - 파괴 시 전원이 각자
-- 보상을 받는다). 상자가 아니면 빈 테이블.
function MonsterState.getChestHitters(model)
	local entry = monsters[model]
	return (entry and entry.isChest and entry.chestHitters) or {}
end

-- 21-3 - 보스 패턴 상태 테이블(BossPatterns.lua 전용). 보스가 아니면 nil.
function MonsterState.getBossPatternState(model)
	local entry = monsters[model]
	return entry and entry.bossPattern
end

-- 21-3 - 플레이어 사망 시 보스 HP를 최대치로 되돌린다(BossEncounter.resetFor). 잡몹은
-- 대상이 아니다(공유 비율 HP라 "되돌릴 최대치" 자체가 없다).
function MonsterState.resetBossHp(model)
	local entry = monsters[model]
	if entry and entry.data.isBoss then
		entry.hp = entry.maxHp
	end
end

function MonsterState.isSparkle(model)
	local entry = monsters[model]
	return entry ~= nil and entry.isSparkle
end

function MonsterState.getZoneKey(model)
	local entry = monsters[model]
	return entry and entry.zoneKey
end

function MonsterState.getData(model)
	local entry = monsters[model]
	return entry and entry.data
end

-- HP 비율(0~1). 보스는 hp/maxHp를 그대로 나눈 값(기존과 동일한 절대값 기반), 잡몹은
-- hpRatio를 그대로 돌려준다. MonsterSpawner.updateHpLabel(HP바)이 이 함수 하나만 본다 -
-- "누구 기준인가"를 몰라도 되는 값이라 HP바가 유일하게 항상 정확한 표시다(19-4 [1] 지시 -
-- 절대 숫자를 보여주지 않는다).
function MonsterState.getHpRatio(model)
	local entry = monsters[model]
	if not entry then
		return 0
	end
	if entry.data.isBoss then
		return entry.maxHp > 0 and math.clamp(entry.hp / entry.maxHp, 0, 1) or 0
	end
	if entry.isChest then
		-- 상자는 "남은 피격 횟수" 비율 - HP바 하나로 진행도를 보여준다.
		return math.clamp(1 - entry.chestHits / TreasureChestConfig.requiredHits, 0, 1)
	end
	return math.clamp(entry.hpRatio, 0, 1)
end

-- 데미지 적용(19-4 [1][2]). attackerStage는 잡몹 계산에만 쓰인다(보스는 무시) -
-- attackerPlayer는 기여 비율 기록용(보스는 기록 자체를 안 한다, [3] 지시 "보스는
-- 건드리지 마라" - 보스 보상은 지금처럼 처치한 플레이어 1인이 그대로 가져간다).
-- 반환값: 이번 타격으로 죽었는가(bool).
function MonsterState.applyDamage(model, damage, attackerStage, attackerPlayer)
	local entry = monsters[model]
	if not entry then
		return false
	end

	if entry.data.isBoss then
		entry.hp -= damage
		return entry.hp <= 0
	end

	-- 보물상자(22-2 [3]) - 피해량은 무관, 피격 "횟수"만 센다. 플레이어당 유효 피격 간격
	-- (TreasureChestConfig.hitIntervalSeconds) 안의 연타는 세지 않는다 - 이게 없으면 한 명이
	-- 0.28초 평타로 혼자 순식간에 깨서 "모두가 받는다"가 무의미해진다(설계의 핵심). 첫 유효
	-- 피격을 낸 순간 보상 대상(chestHitters)에 들어간다 - 강한 사람도 15번, 약한 사람도 15번.
	if entry.isChest then
		if not attackerPlayer then
			return false
		end
		local now = os.clock()
		local last = entry.chestLastHitAt[attackerPlayer]
		if last and now - last < TreasureChestConfig.hitIntervalSeconds then
			return false
		end
		entry.chestLastHitAt[attackerPlayer] = now
		entry.chestHitters[attackerPlayer] = true
		entry.chestHits += 1
		return entry.chestHits >= TreasureChestConfig.requiredHits
	end

	-- 접두사 변종(22-2 [1]) - HP 배율은 "이 인스턴스"의 값이라 공유 data가 아니라 entry에서
	-- 곱한다. 비율 모델(19-4)은 그대로 - 유효 최대체력만 배율만큼 커진다.
	local prefixHpMultiplier = entry.prefix and entry.prefix.hpMultiplier or 1
	local effectiveMaxHp = InfiniteStage.getMonsterHp(entry.data.hp, attackerStage) * prefixHpMultiplier
	local ratioDealt = effectiveMaxHp > 0 and (damage / effectiveMaxHp) or 0
	entry.hpRatio -= ratioDealt
	if attackerPlayer then
		entry.contributions[attackerPlayer] = (entry.contributions[attackerPlayer] or 0) + ratioDealt
	end
	return entry.hpRatio <= 0
end

-- 이 몬스터에 기여한 [Player]=누적비율 테이블(잡몹 전용, 보스는 항상 빈 테이블 - 보스는
-- 애초에 기록하지 않는다). AttackServer의 사망 처리가 이 테이블을 훑어 임계값
-- (CombatConfig.contributionRewardThreshold) 이상인 플레이어 전원에게 각자 보상을 준다.
function MonsterState.getContributors(model)
	local entry = monsters[model]
	return (entry and entry.contributions) or {}
end

-- 플레이어 퇴장 시 호출한다(AttackServer의 PlayerRemoving). 그 플레이어가 아직 살아있는
-- 모든 몬스터의 기여 기록에 남아 있을 수 있으므로 전부 지운다 - 안 지우면 이미 나간
-- Player 인스턴스를 몬스터가 죽을 때까지 계속 들고 있게 된다(MonsterAI.server.lua의
-- releaseChasersOf와 같은 "떠나는 쪽이 자기 흔적을 지운다" 원칙).
function MonsterState.clearPlayerContributions(player)
	for _, entry in pairs(monsters) do
		if entry.contributions then
			entry.contributions[player] = nil
		end
		-- 보물상자 피격 기록도 같이 지운다(22-2 [3] 지시 "플레이어 퇴장 시 그 기록도 정리") -
		-- 남겨 두면 파괴 시점에 이미 나간 Player를 보상 대상으로 순회하게 된다.
		if entry.isChest then
			entry.chestLastHitAt[player] = nil
			entry.chestHitters[player] = nil
		end
	end
end

-- 스테이지 배율이 적용된 공격력(19-4, InfiniteStage 직접 호출로 교체 - 예전
-- setStage/entry.stage는 완전히 제거했다). 보스는 data.attack이 이미 최종값이라 그대로
-- 돌려준다(BossRules.buildInstanceData 참고) - 잡몹은 targetStage로 매 호출마다 새로
-- 계산한다(같은 몬스터를 서로 다른 stage의 플레이어가 때려도 각자 맞는 값이 나온다).
function MonsterState.getAttackFor(model, targetStage)
	local entry = monsters[model]
	if not entry then
		return 0
	end
	if entry.data.isBoss then
		return entry.data.attack
	end
	return InfiniteStage.getMonsterAttack(entry.data.attack, targetStage)
end

function MonsterState.getGoldDropFor(model, stage)
	local entry = monsters[model]
	if not entry then
		return 0
	end
	if entry.data.isBoss then
		return entry.data.goldDrop
	end
	return InfiniteStage.getGoldReward(entry.data.goldDrop, stage) * MonsterPrefixData.getRewardMultiplier(entry.prefix)
end

function MonsterState.getExpRewardFor(model, stage)
	local entry = monsters[model]
	if not entry then
		return 0
	end
	if entry.data.isBoss then
		return entry.data.expReward
	end
	return InfiniteStage.getExpReward(entry.data.expReward, stage) * MonsterPrefixData.getRewardMultiplier(entry.prefix)
end

function MonsterState.getSpawnPosition(model)
	local entry = monsters[model]
	return entry and entry.spawnPosition
end

function MonsterState.getAiState(model)
	local entry = monsters[model]
	return entry and entry.aiState
end

function MonsterState.setAiState(model, value)
	local entry = monsters[model]
	if entry then
		entry.aiState = value
	end
end

function MonsterState.getAiTarget(model)
	local entry = monsters[model]
	return entry and entry.aiTarget
end

function MonsterState.setAiTarget(model, player)
	local entry = monsters[model]
	if entry then
		entry.aiTarget = player
	end
end

function MonsterState.getLastAttackTick(model)
	local entry = monsters[model]
	return entry and entry.lastAttackTick
end

function MonsterState.setLastAttackTick(model, value)
	local entry = monsters[model]
	if entry then
		entry.lastAttackTick = value
	end
end

-- 처치 경합 가드(15-1 검증 중 재현 - 연타로 두 AttackRequest가 거의 동시에 같은 처치
-- 직전 몬스터를 때리면, 첫 요청이 ImmediateSave.request(DataStore 호출로 실제 yield한다)에서
-- 멈춘 사이 두 번째 요청이 똑같이 "내가 죽였다"고 판단해 골드·경험치·드랍을 이중 지급하고,
-- 뒤이어 이미 지워진 MonsterState를 다시 despawn하려다 크래시했다(몬스터 사망은 로그에
-- 두 번 찍히고 despawn만 두 번째에서 nil 참조로 죽는 형태로 재현됨). 이 함수는 "처치를
-- 확정하는" 시점(AttackServer의 newHp<=0 분기 맨 앞)에서 단 한 번만 호출해야 한다 - 이후
-- 어떤 yield(ImmediateSave 등)가 끼어들어도, 두 번째 호출은 이미 clear된 entry가 아니라
-- 여기서 곧바로 false를 받아 조용히 물러난다(entry 자체를 즉시 지우지는 않는다 - despawn이
-- 뒤이어 data·spawnPosition을 여전히 읽어야 하므로, "죽었다는 사실"만 이 한 줄로 원자적으로
-- 표시한다). check와 set 사이에 yield가 없어야 이 보장이 성립하므로 이 함수 자체는 절대
-- yield하지 않는다.
function MonsterState.tryClaimDeath(model)
	local entry = monsters[model]
	if not entry or entry.claimed then
		return false
	end
	entry.claimed = true
	return true
end

function MonsterState.clear(model)
	monsters[model] = nil
end

-- 사거리 판정 등 전체 몬스터를 훑어야 하는 로직용. 순서는 보장하지 않는다.
function MonsterState.getAllModels()
	local models = {}
	for model in pairs(monsters) do
		table.insert(models, model)
	end
	return models
end

return MonsterState
