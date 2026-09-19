-- 보스 아레나의 동적 지형 - 논리 상태(29-3, PRD 20.73 [2-7] 성능 원칙 · 20.76). 서버는 "어디에 무엇이 있다"는
-- 목록만 갖는다 - 인스턴스를 하나도 만들지 않는다. 그리기와 캐릭터 충돌은 클라(BossArenaPropsView)가 하고,
-- 판정(포효의 "기둥 뒤", 가시가 끊기는 자리)은 이 목록과 shared/BossPropMath의 기하로 서버가 한다.
--
-- 지형의 종류·크기·개수 상한은 BossData.bosses[id].props[kind] = { radiusStuds, heightStuds, maxCount }.
-- 이 모듈은 알리지 않는다(RemoteEvent를 모른다) - 바뀐 내용을 돌려주고, 부른 쪽(BossPatterns)이 멤버에게 보낸다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossPropMath = require(ReplicatedStorage.Shared.BossPropMath)

local BossArenaProps = {}

-- [Model] = { nextId, list = { { id, kind, position(지면 좌표), radius, height }, ... }(오래된 것이 앞) }
-- 약한 키 - 보스 모델이 사라지면 같이 사라진다.
local states = setmetatable({}, { __mode = "k" })

local function stateOf(model)
	local st = states[model]
	if not st then
		st = { nextId = 0, list = {} }
		states[model] = st
	end
	return st
end

function BossArenaProps.list(model)
	return stateOf(model).list
end

function BossArenaProps.count(model, kind)
	local n = 0
	for _, prop in ipairs(stateOf(model).list) do
		if kind == nil or prop.kind == kind then
			n += 1
		end
	end
	return n
end

-- 반환: 새 지형, 상한 때문에 밀려난 지형의 id 목록(가장 오래된 것부터 사라진다).
function BossArenaProps.spawn(model, kind, def, position)
	local st = stateOf(model)
	local evicted = {}
	while BossArenaProps.count(model, kind) >= def.maxCount do
		for index, prop in ipairs(st.list) do
			if prop.kind == kind then
				table.insert(evicted, prop.id)
				table.remove(st.list, index)
				break
			end
		end
	end
	st.nextId += 1
	local prop = { id = st.nextId, kind = kind, position = position, radius = def.radiusStuds, height = def.heightStuds }
	table.insert(st.list, prop)
	return prop, evicted
end

-- predicate(prop)가 참인 지형을 지운다. 반환: 지운 id 목록.
function BossArenaProps.removeWhere(model, predicate)
	local st = stateOf(model)
	local removed = {}
	for index = #st.list, 1, -1 do
		if predicate(st.list[index]) then
			table.insert(removed, st.list[index].id)
			table.remove(st.list, index)
		end
	end
	return removed
end

function BossArenaProps.clear(model)
	return BossArenaProps.removeWhere(model, function()
		return true
	end)
end

-- from(보스 중심)에서 본 position을 가려 주는 kind 지형(없으면 nil). 여럿이면 보스에 가까운 것.
function BossArenaProps.shieldingProp(model, kind, from, position, bodyHalfWidthStuds)
	local best, bestDistance = nil, math.huge
	for _, prop in ipairs(stateOf(model).list) do
		if prop.kind == kind and BossPropMath.isShielded(from, position, prop.position, prop.radius, bodyHalfWidthStuds) then
			local d = BossPropMath.distanceToSegment(prop.position, from, from)
			if d < bestDistance then
				best, bestDistance = prop, d
			end
		end
	end
	return best
end

-- position에서 가장 가까운 "kind 지형의 뒤 자리"까지의 직선 거리(지형이 없으면 math.huge) + 그 자리.
function BossArenaProps.nearestSafeSpot(model, kind, from, position, marginStuds)
	local bestSpot, bestDistance = nil, math.huge
	for _, prop in ipairs(stateOf(model).list) do
		if prop.kind == kind then
			local spot = BossPropMath.safeSpot(from, prop.position, prop.radius, marginStuds)
			local d = BossPropMath.distanceToSegment(position, spot, spot)
			if d < bestDistance then
				bestSpot, bestDistance = spot, d
			end
		end
	end
	return bestDistance, bestSpot
end

-- kind 지형 전부의 "뒤 자리" 목록(힌트 화살표).
function BossArenaProps.safeSpots(model, kind, from, marginStuds)
	local spots = {}
	for _, prop in ipairs(stateOf(model).list) do
		if prop.kind == kind then
			table.insert(spots, BossPropMath.safeSpot(from, prop.position, prop.radius, marginStuds))
		end
	end
	return spots
end

-- origin에서 dir로 뻗는 띠가 처음 닿는 kind 지형과 그 거리(없으면 nil).
function BossArenaProps.firstHitOnRay(model, kind, origin, dir, maxLengthStuds, halfWidthStuds)
	local best, bestDistance = nil, math.huge
	for _, prop in ipairs(stateOf(model).list) do
		local d = prop.kind == kind and BossPropMath.rayHitDistance(origin, dir, maxLengthStuds, halfWidthStuds, prop.position, prop.radius)
		if d and d < bestDistance then
			best, bestDistance = prop, d
		end
	end
	return best, best and bestDistance or nil
end

return BossArenaProps
