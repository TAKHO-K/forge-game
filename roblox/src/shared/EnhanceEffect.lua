-- 강화 단계 → 겉모습 · 사거리 보너스를 읽는 순수 함수(30-0 S08, PRD 20.72 [1-9]). 표는 shared/data/EnhanceVisualData.lua가 유일한 출처고 여기엔 숫자가 없다.
-- 클라(client/WeaponEnhanceVisual)와 서버 자동 검증(EnhanceEffectVerify)이 같은 함수를 읽는다 - 인스턴스를 만들지 않는 순수 계산이라 서버에서도 돈다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnhanceVisualData = require(ReplicatedStorage.Shared.data.EnhanceVisualData)

local EnhanceEffect = {}

-- 이 필드들은 표 안의 작은 표라 필드 단위로 덮는다(뒤 step이 준 필드만 바뀌고 나머지는 앞 step의 값이 남는다). 나머지 필드(스칼라 · rainbow)는 통째로 덮는다.
local MERGED_FIELDS = { "light", "particle", "highlight", "tint", "title" }

local function shallowCopy(source)
	local copy = {}
	for key, value in pairs(source) do
		copy[key] = value
	end
	return copy
end

-- level 단계의 모습 = level 이하 임계 step을 앞에서부터 겹친 결과. 아무것도 없으면(0 ~ 4강) 빈 표. 돌려준 표는 마음대로 읽어도 된다(데이터 표와 공유하지 않는다).
function EnhanceEffect.resolveVisual(level)
	local state = {}
	for _, step in ipairs(EnhanceVisualData.steps) do
		if step.level > level then
			break
		end
		for key, value in pairs(step) do
			if key ~= "level" then
				local isMerged = false
				for _, mergedKey in ipairs(MERGED_FIELDS) do
					if key == mergedKey then
						isMerged = true
						break
					end
				end
				if isMerged then
					local merged = state[key] and shallowCopy(state[key]) or {}
					for field, fieldValue in pairs(value) do
						merged[field] = fieldValue
					end
					state[key] = merged
				else
					state[key] = value
				end
			end
		end
	end
	return state
end

-- 그 단계에 **도달하는 순간**의 빛기둥 시간(초). 그 단계가 임계이고 pillarSeconds가 있을 때만(+25), 아니면 nil.
function EnhanceEffect.getArrivalPillarSeconds(level)
	for _, step in ipairs(EnhanceVisualData.steps) do
		if step.level == level then
			return step.pillarSeconds
		end
	end
	return nil
end

-- 강화 단계가 주는 사거리 배율 보너스 합(+0.30 = +30%). 임계 단계(15 · 20)를 넘은 만큼 직업별 비율이 합산된다.
function EnhanceEffect.getRangeBonus(classId, level)
	local bonus = 0
	for threshold, perClass in pairs(EnhanceVisualData.rangeBonusByLevel) do
		if (level or 0) >= threshold then
			bonus += perClass[classId] or 0
		end
	end
	return bonus
end

return EnhanceEffect
