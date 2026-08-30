-- 몬스터 런타임 상태 단일 관리 통로. Humanoid.Health에 HP를 두지 않는다.
-- 확인 결과: Humanoid.Health/MaxHealth는 문서상 number(Lua 64비트 double)이지만,
-- 로블록스 내부적으로는 32비트 float로 저장되는 것으로 보고돼 있다(devforum: 값이 10^9
-- 근처만 가도 정밀도가 깨져 미세 조정이 불가능해짐). 우리 무한 모드는 1e308까지 가고
-- 그 위는 bignum{m,e}로 넘어가므로 애초에 Humanoid.Health로는 표현이 불가능하다.
-- 지금은 plain number로 두되, 나중에 bignum{m,e}로 바꿀 때 이 모듈만 고치면 되도록
-- 읽기/쓰기를 한 곳으로 모은다.

local MonsterState = {}

-- [Model] = { hp, maxHp, data(스폰에 쓴 MonsterData 항목), spawnPosition(리스폰 자리) }
local monsters = {}

function MonsterState.init(model, data, spawnPosition)
	monsters[model] = {
		hp = data.hp,
		maxHp = data.hp,
		data = data,
		spawnPosition = spawnPosition,
	}
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

function MonsterState.getSpawnPosition(model)
	local entry = monsters[model]
	return entry and entry.spawnPosition
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
