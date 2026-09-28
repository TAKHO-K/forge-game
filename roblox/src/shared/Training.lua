-- QUEUE-10h Q6 G3 수련 · 직업 고유 능력 계산(순수 - 서버 · 클라 · EconSim 공용). 데이터 = shared/data/TrainingData.lua.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TrainingData = require(ReplicatedStorage.Shared.data.TrainingData)
local GoldCost = require(ReplicatedStorage.Shared.GoldCost)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)

local Training = {}

local function defOf(list, id)
	for _, def in ipairs(list or {}) do
		if def.id == id then
			return def
		end
	end
	return nil
end

function Training.statDef(id)
	return defOf(TrainingData.stats, id)
end

function Training.abilityDef(classId, id)
	return defOf(TrainingData.classAbilities[classId], id)
end

-- 계정 최고 스테이지가 허락하는 단계 상한(스테이지 연동). ability면 def.maxLevel과 둘 중 작은 쪽.
function Training.capFor(def, bestStage)
	local cap = math.floor(math.max(0, bestStage or 0) / TrainingData.stagesPerLevel)
	if def and def.maxLevel then
		cap = math.min(cap, def.maxLevel)
	end
	return cap
end

-- 다음 단계(level → level + 1) 가격(골드) - 몇 마리분 × GoldCost(계정 최고 스테이지)
function Training.killsFor(def, level)
	return def.baseKills * TrainingData.levelGrowth ^ (level or 0)
end

function Training.costFor(def, level, bestStage)
	return GoldCost.cost(MonsterData.tier1.goldDrop * Training.killsFor(def, level), bestStage, def.maxLevel and "classAbility" or "training")
end

-- 합연산 몫: levels = { [id] = 단계 } · defs = 목록. bucket("attack" | "hp") 또는 axis(옵션 축 id) 하나로 모은다.
local function sumFor(defs, levels, bucket, axis)
	local sum = 0
	for _, def in ipairs(defs or {}) do
		local level = type(levels) == "table" and tonumber(levels[def.id]) or 0
		if level and level > 0 and ((bucket and def.bucket == bucket) or (axis and def.axis == axis)) then
			sum += def.perLevel * level
		end
	end
	return sum
end

-- 영구 버킷 몫(공격 · 체력): 공용 수련 + 그 직업 능력
function Training.bucketBonus(training, abilities, classId, bucket)
	return sumFor(TrainingData.stats, training, bucket, nil) + sumFor(TrainingData.classAbilities[classId], abilities, bucket, nil)
end

-- 옵션 축 몫(방어 · 속도 · 치유) - Option.sumAxisBonus의 extra 값 목록(없으면 nil)
function Training.axisValues(training, abilities, classId, axisId)
	local v = sumFor(TrainingData.stats, training, nil, axisId) + sumFor(TrainingData.classAbilities[classId], abilities, nil, axisId)
	return v > 0 and { v } or nil
end

return Training
