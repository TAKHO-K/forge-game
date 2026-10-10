-- QUEUE-10h Q6 G3 수련 · 직업 고유 능력 계산(순수 - 서버 · 클라 · EconSim 공용). 데이터 = shared/data/TrainingData.lua.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TrainingData = require(ReplicatedStorage.Shared.data.TrainingData)
local GoldCost = require(ReplicatedStorage.Shared.GoldCost)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local All10 = require(ReplicatedStorage.Shared.All10) -- QUEUE-ALL10 2-5 직업 특성 진화(능력 상한 +)

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
	local cap = math.floor(math.max(0, bestStage or 0) / (def and def.stagesPerLevel or TrainingData.stagesPerLevel)) -- QUEUE-ALL9B 2: 항목별 스테이지 간격(수련 = 20)
	if def and def.maxLevel then
		local evolution = Training.statDef(def.id) ~= def and All10.evolutionCapBonus(bestStage) or 0 -- QUEUE-ALL10 2-5(D4): 직업 고유 능력만 5,000 · 7,500 · 10,000에서 상한 +10씩(공용 수련 1 ~ 50은 그대로 · 스위치 끔 = 0)
		cap = math.min(cap, def.maxLevel + evolution)
	end
	return cap
end

-- 다음 단계(level → level + 1) 가격(골드) - 몇 마리분 × GoldCost(계정 최고 스테이지)
function Training.killsFor(def, level)
	return def.baseKills * (def.levelGrowth or TrainingData.levelGrowth) ^ (level or 0) -- QUEUE-ALL9B 2: 항목별 증가율(수련 = 1.08)
end

function Training.costFor(def, level, bestStage)
	return GoldCost.cost(MonsterData.tier1.goldDrop * Training.killsFor(def, level), bestStage, Training.statDef(def.id) == def and "training" or "classAbility")
end

-- UI-1b 1-b 17: 한 번 누름 묶음 = target(%) 이상이 되는 최소 단계 수 · 상한(cap)까지 남은 만큼만(0 = 상한)
function Training.bundleLevels(def, level, cap, target)
	local left = math.max(0, (cap or 0) - (level or 0))
	if left == 0 then
		return 0
	end
	local k = math.max(1, math.ceil(target / def.perLevel - 1e-9))
	return math.min(k, left)
end

-- 묶음 가격 = 묶인 단계 가격 합(단계 가격은 그대로 - 경제 영향 0)
function Training.bundleCost(def, level, k, bestStage)
	local sum = 0
	for i = 0, k - 1 do
		sum += Training.costFor(def, level + i, bestStage)
	end
	return sum
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
