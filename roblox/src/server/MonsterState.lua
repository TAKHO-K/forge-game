-- 몬스터 런타임 상태 단일 관리 통로. Humanoid.Health에 HP를 두지 않는다.
-- 확인 결과: Humanoid.Health/MaxHealth는 문서상 number(Lua 64비트 double)이지만,
-- 로블록스 내부적으로는 32비트 float로 저장되는 것으로 보고돼 있다(devforum: 값이 10^9
-- 근처만 가도 정밀도가 깨져 미세 조정이 불가능해짐). 우리 무한 모드는 1e308까지 가고
-- 그 위는 bignum{m,e}로 넘어가므로 애초에 Humanoid.Health로는 표현이 불가능하다.
-- 지금은 plain number로 두되, 나중에 bignum{m,e}로 바꿀 때 이 모듈만 고치면 되도록
-- 읽기/쓰기를 한 곳으로 모은다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)

local MonsterState = {}

-- [Model] = { hp, maxHp, stage(11-1, 이 인스턴스가 지금 스케일된 무한 모드 스테이지),
--             data(스폰에 쓴 MonsterData 항목 - 여러 몬스터 인스턴스가 같은 테이블을
--             공유하므로 절대 직접 고치지 않는다), spawnPosition(리스폰 자리),
--             aiState("idle"/"chasing"/"returning"), aiTarget(추격 중인 Player, 없으면 nil),
--             lastAttackTick(반격 쿨다운 기준 시각, os.clock()),
--             bossPhase/bossPhaseEndsAt/bossNextHeavyAt(15-1, isBoss 인스턴스만 - 예고 후
--             강한 일격 상태 머신. MonsterAI.server.lua의 tryBossAttack 참고) }
local monsters = {}

function MonsterState.init(model, data, spawnPosition, zoneKey)
	monsters[model] = {
		hp = data.hp,
		maxHp = data.hp,
		stage = 1,
		data = data,
		spawnPosition = spawnPosition,
		zoneKey = zoneKey, -- 16-6, tier 구역 몬스터만 있음(보스는 nil).
		aiState = "idle",
		aiTarget = nil,
		lastAttackTick = nil,
		bossPhase = data.isBoss and "normal" or nil,
		bossPhaseEndsAt = nil,
		bossNextHeavyAt = data.isBoss and (os.clock() + data.heavyAttackIntervalSeconds) or nil,
	}
end

function MonsterState.getZoneKey(model)
	local entry = monsters[model]
	return entry and entry.zoneKey
end

function MonsterState.getHp(model)
	local entry = monsters[model]
	return entry and entry.hp
end

function MonsterState.getMaxHp(model)
	local entry = monsters[model]
	return entry and entry.maxHp
end

function MonsterState.setHp(model, value)
	local entry = monsters[model]
	if entry then
		entry.hp = value
	end
end

function MonsterState.getData(model)
	local entry = monsters[model]
	return entry and entry.data
end

function MonsterState.getStage(model)
	local entry = monsters[model]
	return entry and entry.stage
end

-- 무한 모드 스테이지 배율 재적용(11-1). 몬스터가 새 대상에게 어그로를 붙이는 순간
-- (MonsterAI.server.lua)마다 그 대상의 스테이지로 다시 스케일한다 - data(여러 몬스터
-- 인스턴스가 공유하는 MonsterData 원본 테이블)는 절대 고치지 않고, 이 인스턴스의
-- hp/maxHp/stage에만 배율을 적용한다.
--
-- 이미 피해를 입은(hp < maxHp) 몬스터는 다시 스케일하지 않는다 - 그러지 않으면 다른
-- 스테이지 플레이어가 다가오는 순간 풀피로 되돌아가는 "공짜 회복" 버그가 생긴다. 여러
-- 플레이어가 서로 다른 스테이지로 같은 몬스터를 동시에 다투는 경우(그 몬스터는 먼저
-- 어그로를 잡은 쪽의 스테이지 기준에 그대로 머문다)는 이번 단계의 범위 밖이다 - 이
-- 게임의 어그로 자체가 이미 "몬스터 한 마리당 대상 하나"로 설계돼 있다.
function MonsterState.setStage(model, stage)
	local entry = monsters[model]
	if not entry or entry.data.isBoss or entry.stage == stage or entry.hp < entry.maxHp then
		return
	end
	entry.stage = stage
	entry.maxHp = InfiniteStage.getMonsterHp(entry.data.hp, stage)
	entry.hp = entry.maxHp
end

-- 무한 모드 스테이지 배율이 적용된 공격력(11-1). data.attack(원본, 스테이지1 기준)에
-- 이 인스턴스의 stage 배율을 곱한다 - MonsterAI.server.lua가 반격 데미지 계산에 쓴다.
function MonsterState.getAttack(model)
	local entry = monsters[model]
	return entry and InfiniteStage.getMonsterAttack(entry.data.attack, entry.stage)
end

-- 무한 모드 스테이지 배율이 적용된 처치 골드(11-1). AttackServer가 처치 판정 직후 쓴다.
function MonsterState.getGoldDrop(model)
	local entry = monsters[model]
	return entry and InfiniteStage.getGoldReward(entry.data.goldDrop, entry.stage)
end

-- 무한 모드 스테이지 배율이 적용된 처치 경험치(13-2). AttackServer가 처치 판정 직후 쓴다 -
-- getGoldDrop과 같은 패턴.
function MonsterState.getExpReward(model)
	local entry = monsters[model]
	return entry and InfiniteStage.getExpReward(entry.data.expReward, entry.stage)
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

-- 15-1 - 예고 후 강한 일격 상태 머신(isBoss 인스턴스만 쓴다, MonsterAI.server.lua 참고).
function MonsterState.getBossPhase(model)
	local entry = monsters[model]
	return entry and entry.bossPhase
end

function MonsterState.setBossPhase(model, value)
	local entry = monsters[model]
	if entry then
		entry.bossPhase = value
	end
end

function MonsterState.getBossPhaseEndsAt(model)
	local entry = monsters[model]
	return entry and entry.bossPhaseEndsAt
end

function MonsterState.setBossPhaseEndsAt(model, value)
	local entry = monsters[model]
	if entry then
		entry.bossPhaseEndsAt = value
	end
end

function MonsterState.getBossNextHeavyAt(model)
	local entry = monsters[model]
	return entry and entry.bossNextHeavyAt
end

function MonsterState.setBossNextHeavyAt(model, value)
	local entry = monsters[model]
	if entry then
		entry.bossNextHeavyAt = value
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
