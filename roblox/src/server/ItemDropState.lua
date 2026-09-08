-- 땅에 떨어진 아이템 인스턴스의 런타임 상태 단일 관리 통로(14-1). MonsterState와 같은
-- 역할 분리 - 판정(이 모듈)과 시각(ItemDropSpawner)을 나눈다.

local ItemDropState = {}

-- [Model] = { item(Loot.rollArmorDrop 결과 그대로), ownerId(주운 플레이어만 줍게 - 다른
--             플레이어는 이 id와 비교조차 안 한다), spawnedAt(os.clock(), 줍기 지연·연출
--             타이밍 기준), fullNotified(가득 참 알림을 한 번만 보내기 위한 플래그) }
local drops = {}

function ItemDropState.init(model, item, ownerId)
	drops[model] = {
		item = item,
		ownerId = ownerId,
		spawnedAt = os.clock(),
		fullNotified = false,
	}
end

function ItemDropState.getItem(model)
	local entry = drops[model]
	return entry and entry.item
end

function ItemDropState.getOwnerId(model)
	local entry = drops[model]
	return entry and entry.ownerId
end

function ItemDropState.getSpawnedAt(model)
	local entry = drops[model]
	return entry and entry.spawnedAt
end

function ItemDropState.isFullNotified(model)
	local entry = drops[model]
	return entry ~= nil and entry.fullNotified
end

function ItemDropState.setFullNotified(model, value)
	local entry = drops[model]
	if entry then
		entry.fullNotified = value
	end
end

function ItemDropState.clear(model)
	drops[model] = nil
end

-- 픽업 판정·수명 만료 순회용. 순서는 보장하지 않는다(MonsterState.getAllModels와 동일).
function ItemDropState.getAllModels()
	local models = {}
	for model in pairs(drops) do
		table.insert(models, model)
	end
	return models
end

return ItemDropState
