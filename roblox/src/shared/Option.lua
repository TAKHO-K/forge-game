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

-- f(L) = (1 + s·(min(L,125) − 1)) / (1 + s·(100 − 1)) - 20.67 [3] 그대로. 기준 레벨(100)에서 1.0.
-- P2 D1(결정 5A): 125(옛 동결 레벨) 뒤로는 f(125) × (1 + p·log2(L/125)) - p = OptionData.levelLogSlope. 125에서 이어진다.
-- itemLevel은 스테이지(최대 SafeStageCap 4738)라 log2 항이 5.3을 넘지 않는다 - 유한(inf · NaN 없음).
function Option.levelFactor(level)
	local numerator = 1 + STAT_BONUS_PER_LEVEL * (math.min(level, FREEZE_LEVEL) - 1)
	local denominator = 1 + STAT_BONUS_PER_LEVEL * (REFERENCE_LEVEL - 1)
	local factor = numerator / denominator
	if level > FREEZE_LEVEL then
		factor *= 1 + OptionData.levelLogSlope * math.log(level / FREEZE_LEVEL, 2)
	end
	return factor
end

local function gradeIndex(gradeId)
	for i, id in ipairs(ArmorData.gradeOrder) do
		if id == gradeId then
			return i
		end
	end
	return nil
end

-- 옵션(보석) 등급 몫 = OptionData.gradeStep^(등급 순서 − 1) ÷ 장비 태초 배율(ItemVisualData.gradeVisuals.primordial.statMultiplier).
-- 옛(20.67 [3] ~ P2.5b): 장비 등급 배율 statMultiplier(1.45^(순서 − 1)) ÷ 태초 배율 - 태초 = 1.
-- P2.5c 결정 5(사용자 확정 "보석에는 장비 등급 배율 ×1.45를 일부만 적용"): 일반 등급의 기준점(1 ÷ 태초 배율)은 그대로 두고 등급당 배율만 gradeStep(< 1.45)로 -
-- 모든 등급이 옛 값 이하이고 높은 등급일수록 더 줄어든다(태초 = (gradeStep ÷ 1.45)^6). 서버 판정 · 클라 표시 · 시뮬 · 가루 표가 모두 이 함수 하나를 본다.
function Option.gradeFactor(gradeId)
	local index = gradeIndex(gradeId)
	if not index then
		return 0
	end
	return OptionData.gradeStep ^ (index - 1) / ItemVisualData.gradeVisuals.primordial.statMultiplier
end
local gradeFactor = Option.gradeFactor

-- 그 등급이 옵션 풀을 갖는가(영웅 이상 - OptionData.minGradeIndex 주석 참고). 일반·희귀는
-- 항상 false.
function Option.hasOptionPool(gradeId)
	local index = gradeIndex(gradeId)
	return index ~= nil and index >= OptionData.minGradeIndex
end

-- P2.5b A: 그 등급이 가질 수 있는 옵션 개수(지금 규칙 = 옵션 풀이 있으면 1개 · 없으면 0개). 계승이 "B 등급 한도까지"를 이 값으로 자른다.
function Option.optionSlotsFor(gradeId)
	return Option.hasOptionPool(gradeId) and 1 or 0
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
--
-- 26-2 수정: 대칭 clamp(-cap~cap)로 바꾼다. baseValue가 음수인 축(skill_bow_E·skill_healer_Q·
-- skill_healer_E, "쿨다운/소모 ×(1-x)"류 - OptionData 주석 참고)은 합산값 자체가 항상 음수라
-- 옛 `math.min(total, cap)`(cap이 양수라 음수 total엔 전혀 안 걸린다 - 8개를 몰빵해도 상한이
-- 있는 것처럼 보이지만 실제로는 절대 안 잘렸다)로는 [7]의 상한(예: 딜링모드 Σ≤90%)이 코드에서
-- 전혀 작동하지 않는다. 대칭 clamp는 baseValue가 양수인 기존 축(건강·방어·성장·재생·
-- skill_dualblade_Q)에는 total이 항상 0 이상이라 결과가 그대로다(회귀 없음).
function Option.sumWithCap(values, optionId)
	local total = 0
	for _, value in ipairs(values) do
		total += value
	end
	local def = OptionData.options[optionId]
	local cap = def and def.cap
	if cap then
		return math.clamp(total, -cap, cap)
	end
	return total
end

-- sources: 배열의 각 원소가 { option, grade, itemLevel } 형태(장비 아이템 또는 보석 둘 다
-- 이 모양을 공유한다, 20.67 [1] "장비 옵션 1개 ≙ 보석 1개"). axisId와 option.id가 같은
-- 원소만 값을 낸다(다른 옵션이 붙은 자리는 기여가 없다). Option.valueOf·Option.sumWithCap
-- 두 순수 함수를 그대로 합성한 것뿐 - 새 계산식을 만들지 않는다(20.67 [14] 3단계 지시).
function Option.sumAxisBonus(sources, axisId, classId)
	local values = {}
	for _, source in ipairs(sources) do
		if source and source.option and source.option.id == axisId then
			table.insert(values, Option.valueOf(source.option, source.grade, source.itemLevel, classId))
		end
	end
	return Option.sumWithCap(values, axisId)
end

-- 치명 전용 집계 - id="crit"인 원소만 모아 {critRate, critDmg} 두 값을 각각 sumWithCap한다
-- (둘 다 상한 없음, OptionData.crit.cap=nil - 20.67 [6-3]). Option.valueOf가 crit id에는
-- 이미 {critRate, critDmg} 테이블을 돌려주므로 그 값을 축별로 나눠 모으기만 한다.
function Option.critBonus(sources, classId)
	local critRates, critDmgs = {}, {}
	for _, source in ipairs(sources) do
		if source and source.option and source.option.id == "crit" then
			local value = Option.valueOf(source.option, source.grade, source.itemLevel, classId)
			table.insert(critRates, value.critRate)
			table.insert(critDmgs, value.critDmg)
		end
	end
	return Option.sumWithCap(critRates, "crit"), Option.sumWithCap(critDmgs, "crit")
end

return Option
