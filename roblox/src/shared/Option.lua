-- 보석·장비 통합 옵션 순수 계산 로직(26-1, PRD-forge-game-roblox.md 20.67 [3][4][5][8]). 데이터
-- (OptionData)와 분리해서 여기엔 공식만 둔다 - Gem.lua/Loot.lua/Enhance.lua와 같은 분리 원칙.
-- math.random 계열을 직접 굴리는 함수(rollValue·rollFor)는 반드시 서버에서만 호출해야 한다 -
-- 클라이언트는 조회 함수(valueOf·rangeOf·sumWithCap·levelFactor)만 쓴다.
--
-- 26-1 지시: 이 모듈은 아직 게임에 연결되지 않는다(순수 함수만, 20.67 [14] 1단계) - 어떤 서버
-- 모듈도 아직 이 파일을 require하지 않는다. "/gg option table"로 [3] 구간표와 대조한다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OptionData = require(ReplicatedStorage.Shared.data.OptionData)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local CharacterLevelConfig = require(ReplicatedStorage.Shared.data.CharacterLevelConfig)
local BalanceAnchorConfig = require(ReplicatedStorage.Shared.data.BalanceAnchorConfig)

-- 옵션 롤도 치명타 판정(PlayerCombat.critRng)·보석 이름 롤(Gem.gemRng)과 같은 이유로 전역
-- 시드와 분리한다.
local optionRng = Random.new()

local Option = {}

local STAT_BONUS_PER_LEVEL = CharacterLevelConfig.statBonusPerLevel -- 0.06
local REFERENCE_LEVEL = BalanceAnchorConfig.referenceLevel -- 100
-- 동결 레벨 = killTargetAnchors 마지막 앵커(125, 5회차 끝) - 새 상수를 만들지 않고 이미 있는
-- 앵커를 재사용한다(20.67 [3] "레벨125(killTargetAnchors 마지막 앵커)에서 동결").
local FREEZE_LEVEL = CharacterLevelConfig.killTargetAnchors[#CharacterLevelConfig.killTargetAnchors].level

-- f(L) = (1 + s·(min(L,125) − 1)) / (1 + s·(100 − 1)) - 20.67 [3] 그대로. 기준 레벨(100)에서
-- 1.0, 동결 레벨(125) 이후로는 값이 더 늘지 않는다.
function Option.levelFactor(level)
	local numerator = 1 + STAT_BONUS_PER_LEVEL * (math.min(level, FREEZE_LEVEL) - 1)
	local denominator = 1 + STAT_BONUS_PER_LEVEL * (REFERENCE_LEVEL - 1)
	return numerator / denominator
end

-- m_grade/m_primordial - ItemVisualData.gradeVisuals.statMultiplier를 태초 기준으로
-- 정규화한다(20.67 [3] "기존 등급 배율표를 그대로 정규화").
local function gradeFactor(gradeId)
	local visual = ItemVisualData.gradeVisuals[gradeId]
	if not visual then
		return 0
	end
	return visual.statMultiplier / ItemVisualData.gradeVisuals.primordial.statMultiplier
end

local function gradeIndex(gradeId)
	for i, id in ipairs(ArmorData.gradeOrder) do
		if id == gradeId then
			return i
		end
	end
	return nil
end

-- 그 등급이 옵션 풀을 갖는가(영웅 이상 - OptionData.minGradeIndex 주석 참고). 일반·희귀는
-- 항상 false.
function Option.hasOptionPool(gradeId)
	local index = gradeIndex(gradeId)
	return index ~= nil and index >= OptionData.minGradeIndex
end

-- 드랍·환생·리롤 풀 10종(공통 8 + 그 직업 특화 2, 20.67 [1] "직업 특화 후보는 그 순간
-- 플레이어의 직업 2종만"). classId가 nil이거나 알 수 없으면 공통 8종만.
local function poolFor(classId)
	local pool = {}
	for _, id in ipairs(OptionData.commonOrder) do
		table.insert(pool, id)
	end
	local classIds = classId and OptionData.classSkillOptions[classId]
	if classIds then
		for _, id in ipairs(classIds) do
			table.insert(pool, id)
		end
	end
	return pool
end
Option.poolFor = poolFor

-- 롤 하나 U[0.875, 1.125] - 서버 전용.
function Option.rollValue()
	return OptionData.rollMin + optionRng:NextNumber() * (OptionData.rollMax - OptionData.rollMin)
end

-- 그 등급·직업에서 옵션 하나를 굴린다(서버 전용) - 옵션 풀이 없는 등급(일반·희귀)이면 nil.
-- 치명(crit)은 치확·치피 롤이 독립이라(20.67 [2] "둘 다 독립 롤") roll2도 같이 굴린다.
function Option.rollFor(gradeId, classId)
	if not Option.hasOptionPool(gradeId) then
		return nil
	end
	local pool = poolFor(classId)
	local id = pool[optionRng:NextInteger(1, #pool)]
	local option = { id = id, roll = Option.rollValue() }
	if OptionData.options[id].critRateBase then
		option.roll2 = Option.rollValue()
	end
	return option
end

-- value(option, grade, itemLevel, roll) = base_p × (m_grade/m_primordial) × f(itemLevel) × roll
-- (20.67 [3]). classId 불일치(직업 특화 옵션을 다른 직업이 들고 있음)면 0 - 20.67 [8] "코드는
-- Option.valueFor(option, classId)가 classId 불일치면 0을 돌려주는 한 줄이다". 치명은 두 값
-- {critRate, critDmg}을 돌려준다(둘 다 PlayerCombat.calcDamage의 별개 인자).
function Option.valueOf(option, gradeId, itemLevel, classId)
	if not option or not option.id then
		return 0
	end
	local def = OptionData.options[option.id]
	if not def then
		return 0
	end
	if def.classId and def.classId ~= classId then
		return 0
	end

	local gf = gradeFactor(gradeId)
	local lf = Option.levelFactor(itemLevel)

	if def.critRateBase then
		return {
			critRate = def.critRateBase * gf * lf * option.roll,
			critDmg = def.critDmgBase * gf * lf * (option.roll2 or option.roll),
		}
	end

	return def.baseValue * gf * lf * (option.roll or 1)
end

-- {min, mid, max} - 그 등급·레벨·직업에서 이 옵션이 가질 수 있는 값의 범위(20.67 [12] UI
-- 게이지가 쓸 값, "/gg option table"이 [3] 구간표와 대조할 때도 쓴다). mid는 기댓값(roll=1.0).
function Option.rangeOf(optionId, gradeId, itemLevel, classId)
	local function at(roll)
		return Option.valueOf({ id = optionId, roll = roll, roll2 = roll }, gradeId, itemLevel, classId)
	end
	return { min = at(OptionData.rollMin), mid = at(1.0), max = at(OptionData.rollMax) }
end

-- 값 목록(같은 optionId)을 더하고 그 옵션의 합산 상한(OptionData.options[id].cap)을 적용한다
-- (20.67 [7] "합산은 min(cap, Σ)로 순서 무관"). 상한이 없으면(cap=nil) 그대로 합.
function Option.sumWithCap(values, optionId)
	local total = 0
	for _, value in ipairs(values) do
		total += value
	end
	local def = OptionData.options[optionId]
	local cap = def and def.cap
	if cap then
		return math.min(total, cap)
	end
	return total
end

return Option
