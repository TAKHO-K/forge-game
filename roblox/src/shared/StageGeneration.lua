-- C5-6 세대 조회(순수 - 서버 · 클라 공용). 데이터 = shared/data/StageGenerationData.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StageGenerationData = require(ReplicatedStorage.Shared.data.StageGenerationData)

local StageGeneration = {}

-- 스테이지 → 세대 번호(0 = 세대 전). startStage부터 1 · everyStages마다 +1.
function StageGeneration.indexOf(stage)
	if type(stage) ~= "number" or stage < StageGenerationData.startStage then
		return 0
	end
	return math.floor((stage - StageGenerationData.startStage) / StageGenerationData.everyStages) + 1
end

-- 세대 정보(nil = 세대 전). 표 밖 번호 = 마지막 행(이름에 번호 접미).
function StageGeneration.forStage(stage)
	local index = StageGeneration.indexOf(stage)
	if index == 0 then
		return nil
	end
	local rows = StageGenerationData.generations
	local row = rows[math.min(index, #rows)]
	local numbered = index > #rows and (" " .. tostring(index)) or ""
	return {
		index = index,
		startStage = StageGenerationData.startStage + (index - 1) * StageGenerationData.everyStages,
		suffix = row.suffix .. numbered,
		prefix = row.prefix .. numbered,
		tint = row.tint,
		tintAlpha = StageGenerationData.tintAlpha,
		setOptionId = row.setOptionId,
		budgetScale = 1 + StageGenerationData.budgetStepPerGeneration * index,
		gateBossId = row.gateBossId,
		mutationId = row.mutationId,
		titleId = row.titleId,
	}
end

-- 드랍 장비의 세트 이름 접미사(주운 스테이지 기준 · 세대 전 = nil).
function StageGeneration.itemSuffix(item)
	local generation = type(item) == "table" and StageGeneration.forStage(item.dropStage)
	return generation and generation.suffix or nil
end

return StageGeneration
