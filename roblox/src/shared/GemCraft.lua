-- 보석 분해(가루) · 재련 규칙(P2.5b C · B) - 순수 함수. 서버(PlayerProfile.dismantleGem · dismantleGemsUpTo · refineGem)가 판정하고 클라(보석 가공 창 · 상세 바)가 같은 함수로 미리 보인다.
--   분해: 보석 가방의 보석 1개 → 보석 가루(계정 공유). 양 = max(1, 반올림(GemData.dust.dustYield[등급] × Option.levelFactor(itemLevel))). 홈에 낀 보석은 분해 대상이 아니다(가방에서만).
--   재련: 대상 보석(홈 또는 가방)에 **더 높은 레벨의 다른 보석**(가방)을 먹이면 대상의 itemLevel이 먹인 보석의 itemLevel이 된다. 등급 · 옵션(종류 · 굴림)은 그대로 -
--         수치는 Option.valueOf가 새 레벨로 다시 계산한다. 먹인 보석은 사라진다. 비용 = 골드(GoldCost "refine") + 가루. 합성이 아니다(등급이 안 바뀐다 - 태초를 만드는 길이 없다).
--   이유 코드(재련): not_found(대상 · 먹이 없음) · same_gem(같은 보석) · no_gain(먹이 레벨 ≤ 대상 레벨 - 오를 것이 없다) + 서버의 no_gold · no_dust.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local GemData = require(ReplicatedStorage.Shared.data.GemData)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local GoldCost = require(ReplicatedStorage.Shared.GoldCost)
local Option = require(ReplicatedStorage.Shared.Option)

local GemCraft = {}

local function gradeRank(gradeId)
	for i, id in ipairs(ArmorData.gradeOrder) do
		if id == gradeId then
			return i
		end
	end
	return 0
end

-- 보석 1개의 분해 가루.
function GemCraft.dustYield(gem)
	local base = GemData.dust.dustYield[gem.grade] or 0
	if base <= 0 then
		return 0
	end
	return math.max(1, math.floor(base * Option.levelFactor(gem.itemLevel or 1) + 0.5))
end

-- 일괄 분해 대상인가: cutoffGradeId 이하 등급(가방의 보석만 - 호출부가 가방 목록을 넘긴다).
function GemCraft.isBulkTarget(gem, cutoffGradeId)
	local cutoff = gradeRank(cutoffGradeId)
	return cutoff > 0 and gradeRank(gem.grade) > 0 and gradeRank(gem.grade) <= cutoff
end

-- 일괄 분해 미리보기: 개수 · 가루 합 · 대상 중 최고 등급(확인창이 등급을 강조한다).
function GemCraft.bulkEstimate(gemInventory, cutoffGradeId)
	local count, dust, highest, highestRank = 0, 0, nil, 0
	for _, gem in ipairs(gemInventory) do
		if GemCraft.isBulkTarget(gem, cutoffGradeId) then
			count += 1
			dust += GemCraft.dustYield(gem)
			if gradeRank(gem.grade) > highestRank then
				highest, highestRank = gem.grade, gradeRank(gem.grade)
			end
		end
	end
	return count, dust, highest
end

-- 일괄 분해 등급 선택지 = 보석이 가질 수 있는 등급(가루 기준량이 있는 등급) - 낮은 것부터.
function GemCraft.bulkGradeChoices()
	local choices = {}
	for _, id in ipairs(ArmorData.gradeOrder) do
		if GemData.dust.dustYield[id] then
			table.insert(choices, id)
		end
	end
	return choices
end

-- 재련 판정. target · fodder = 보석 표(없으면 nil). 같은 표면 same_gem.
function GemCraft.refineBlockReason(target, fodder)
	if not target or not fodder then
		return "not_found"
	end
	if target == fodder then
		return "same_gem"
	end
	if (fodder.itemLevel or 0) <= (target.itemLevel or 0) then
		return "no_gain"
	end
	return nil
end

-- 재련 비용: 골드 · 가루(대상 등급 기준). stage = 계정 최고 스테이지.
function GemCraft.refineCost(targetGradeId, stage)
	local kills = GemData.dust.refineGoldKills[targetGradeId] or GemData.dust.refineGoldKills.epic
	local gold = GoldCost.cost(MonsterData.tier1.goldDrop * kills, stage, "refine")
	local dust = GemData.dust.refineDust[targetGradeId] or GemData.dust.refineDust.epic
	return gold, dust
end

-- 재련 뒤 대상(새 표 - 미리보기용): 레벨만 먹이의 레벨.
function GemCraft.refinedGem(target, fodder)
	local gem = {}
	for key, value in pairs(target) do
		gem[key] = value
	end
	gem.itemLevel = fodder.itemLevel
	return gem
end

-- P3c E4 보석 판매가(골드). stage = 계정 최고 스테이지. = GoldCost("refine", tier1 골드 × 가루 × 재련의 골드/가루 비 × sellFractionOfDust) - 분해 가루 가치보다 낮다.
function GemCraft.sellPrice(gem, stage)
	local dust = GemData.dust
	local grade = dust.refineGoldKills[gem.grade] and gem.grade or "epic"
	local killsPerDust = dust.refineGoldKills[grade] / dust.refineDust[grade]
	local kills = GemCraft.dustYield(gem) * killsPerDust * dust.sellFractionOfDust
	return math.max(GoldCost.cost(MonsterData.tier1.goldDrop * kills, stage, "refine"), 1)
end

-- 같은 보석의 분해 가루를 골드로 친 값(판매가와 비교 - 검증 · 보고용).
function GemCraft.dustGoldValue(gem, stage)
	local dust = GemData.dust
	local grade = dust.refineGoldKills[gem.grade] and gem.grade or "epic"
	return GoldCost.cost(MonsterData.tier1.goldDrop * GemCraft.dustYield(gem) * dust.refineGoldKills[grade] / dust.refineDust[grade], stage, "refine")
end

-- 변환권 1장 구매에 드는 가루(골드와 별도).
function GemCraft.ticketDust(gradeId)
	return GemData.dust.ticketDust[gradeId] or 0
end

return GemCraft
