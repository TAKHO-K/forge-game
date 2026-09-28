-- QUEUE-10h Q5 BR2 방어구 세트 계산(순수 - 서버 · 클라 툴팁 · 하네스 공용). 데이터 = shared/data/SetData.lua.
--   세트 = 착용 3부위의 item.setZone이 같은 것. 세대 세트 = 같은 구역 + 같은 세대(dropStage) 3부위면 효과 × 세대 예산(StageGeneration.forStage.budgetScale).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SetData = require(ReplicatedStorage.Shared.data.SetData)
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local StageGeneration = require(ReplicatedStorage.Shared.StageGeneration)

local SetBonus = {}

-- 드랍 출처(item.source - CombatResolution이 붙인다) → 세트 계열(구역 키). 보스 = 그 보스 관문 구역 · 잡몹 · 반짝이 = 사냥 구역 · 그 밖(개발 · 견습 · 합성) = nil.
function SetBonus.zoneFromSource(source)
	if type(source) ~= "table" then
		return nil
	end
	if (source.kind == "boss" or source.kind == "raid") and source.bossId then
		local boss = BossData.bosses[source.bossId]
		return boss and boss.gate and boss.gate.zone or nil
	end
	if (source.kind == "field" or source.kind == "sparkle") and type(source.zone) == "string" then
		return source.zone
	end
	return nil
end

-- 세트 표시 이름(구역 테마 + " 세트" · 세대 접두사) - nil = 세트 아님
function SetBonus.setName(zoneKey, dropStage)
	for _, zone in ipairs(WorldMapData.zones) do
		if zone.key == zoneKey then
			local generation = StageGeneration.forStage(dropStage)
			return (generation and (generation.prefix .. " ") or "") .. zone.theme .. SetData.nameSuffix
		end
	end
	return nil
end

-- 착용(equipment = { armor, gloves, shoes })의 세트 상태: 가장 많이 모인 구역 · 부위 수 · 세대 배율(3부위 같은 세대일 때만)
function SetBonus.state(equipment)
	local counts, best, bestCount = {}, nil, 0
	for _, part in ipairs(SetData.parts) do
		local item = equipment and equipment[part]
		local zone = type(item) == "table" and item.setZone or nil
		if zone then
			counts[zone] = (counts[zone] or 0) + 1
			if counts[zone] > bestCount then
				best, bestCount = zone, counts[zone]
			end
		end
	end
	local scale = 1
	if best and bestCount >= #SetData.parts then
		local index
		for _, part in ipairs(SetData.parts) do
			local g = StageGeneration.indexOf(equipment[part].dropStage)
			if index == nil then
				index = g
			elseif index ~= g then
				index = 0
			end
		end
		local generation = index and index > 0 and StageGeneration.forStage(equipment[SetData.parts[1]].dropStage) -- 3부위가 같은 세대일 때만
		scale = generation and generation.budgetScale or 1
	end
	return best, bestCount, scale
end

-- 옵션 축 하나에 더할 세트 값 목록(Option.sumAxisBonus의 extra - 상한은 옵션과 같이). 스위치 꺼짐 = 빈 목록.
function SetBonus.extraValues(equipment, axisId)
	if not SetData.enabled then
		return nil
	end
	local zone, count, scale = SetBonus.state(equipment)
	if not zone then
		return nil
	end
	local values
	for _, tier in ipairs(SetData.tiers) do
		if count >= tier.pieces and tier.axis == axisId then
			values = values or {}
			table.insert(values, tier.value * scale)
		end
	end
	return values
end

return SetBonus
