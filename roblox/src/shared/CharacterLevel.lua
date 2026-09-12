-- 캐릭터 레벨 곡선·배율이 실제로 계산되는 유일한 위치(13-2, PlayerCombat·InfiniteStage와
-- 같은 이유). 레벨을 소비하는 두 곳(무기 공격력 - PlayerCombat.getAttack, 아이템 레벨계수 -
-- Loot.getArmorDefense) 모두 이 모듈을 거친다.
--
-- 레벨25까지는 웹 WEAPON_LEVEL_EXP 배열을 그대로 쓴다. 26+ 경험치 곡선은 20.10의 공식을
-- 쓰되, "레벨25 실측 누적치(25,000)에서 정확히 이어 붙인다"는 원칙으로 앵커를 잡는다 -
-- 공식 자체의 절대값(Lv25=25,057)과 실측표(25,000) 사이의 0.2% 오차가 25->26 경계에서
-- 미세한 불연속(레벨업 없이 경험치만 손해 보는 구간)을 만들지 않도록, 공식은 "증가분"만
-- 가져오고 시작점은 실측표를 따른다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharacterLevelConfig = require(ReplicatedStorage.Shared.data.CharacterLevelConfig)
local InfiniteStageConfig = require(ReplicatedStorage.Shared.data.InfiniteStageConfig)

local CharacterLevel = {}

local MAX_FINITE_LEVEL = #CharacterLevelConfig.weaponLevelExp -- 25
local FINITE_PEAK_EXP = CharacterLevelConfig.weaponLevelExp[MAX_FINITE_LEVEL] -- 25000
local PEAK_MULTIPLIER = 1 + CharacterLevelConfig.statBonusPerLevel * (MAX_FINITE_LEVEL - 1) -- 2.44

local function expFormula(level)
	return CharacterLevelConfig.expFormulaBase
		* (CharacterLevelConfig.expFormulaRatio ^ (level - 1) - 1)
		/ CharacterLevelConfig.expFormulaDivisor
end

local FINITE_PEAK_FORMULA = expFormula(MAX_FINITE_LEVEL) -- 앵커 보정에만 쓰는 중간값(~25,057)

-- 그 레벨에 도달하기 위한 누적 경험치. 1~25는 실측표, 26+는 25번째 실측값에서 공식의
-- 증가분만 이어 붙인다(위 주석 참고).
function CharacterLevel.getExpForLevel(level)
	if level <= MAX_FINITE_LEVEL then
		return CharacterLevelConfig.weaponLevelExp[level]
	end
	return FINITE_PEAK_EXP + (expFormula(level) - FINITE_PEAK_FORMULA)
end

-- 누적 경험치로 현재 레벨을 구한다. 1~25는 배열을 훑고(웹 core/weaponExp.js와 동일 방식),
-- 그 이상은 다음 임계값을 넘는지 반복 검사한다 - 경험치 증가율이 지수식이라 몬스터 한 마리
-- 처치로 레벨이 여러 개씩 뛰는 일은 실제로 없어 반복 횟수가 크게 자라지 않는다.
function CharacterLevel.getLevelFromExp(exp)
	local level = 1
	for i = 1, MAX_FINITE_LEVEL do
		if exp >= CharacterLevelConfig.weaponLevelExp[i] then
			level = i
		else
			return level
		end
	end
	while exp >= CharacterLevel.getExpForLevel(level + 1) do
		level += 1
	end
	return level
end

-- 다음 레벨까지 진행률(UI 표시용).
function CharacterLevel.getProgress(exp, level)
	local currentThreshold = CharacterLevel.getExpForLevel(level)
	local nextThreshold = CharacterLevel.getExpForLevel(level + 1)
	local needed = nextThreshold - currentThreshold
	local current = exp - currentThreshold
	return { current = current, needed = needed, ratio = needed > 0 and current / needed or 1 }
end

-- 무기 공격력 배율(PlayerCombat.getAttack이 곱한다). 1~25는 웹과 완전히 같은 선형식,
-- 26+는 20.10이 정한 지수식(g=1.15, 몬스터 k=1.155보다 살짝 낮게 - 스테이지가 오를수록
-- 아주 조금씩 어려워지도록 의도된 격차).
function CharacterLevel.getWeaponExpMultiplier(level)
	if level <= MAX_FINITE_LEVEL then
		return 1 + CharacterLevelConfig.statBonusPerLevel * (level - 1)
	end
	return PEAK_MULTIPLIER * (CharacterLevelConfig.weaponMultGrowthRate ^ (level - MAX_FINITE_LEVEL))
end

-- 아이템 레벨계수(Loot.getArmorDefense가 곱한다). 1~25는 무기 배율과 같은 선형식(레벨25
-- 시점 무기 공격력·아이템 스탯이 나란히 2.44배로 정점을 찍는 대칭, data/items.js 75-78행
-- 설계 의도 재사용). 26+는 몬스터와 같은 k=1.155(InfiniteStageConfig.growthRate 재사용,
-- PRD-forge-game-roblox.md 20.11-4 "defenseFlat도 k로 키워야 방어력/몬스터공격력 비율이
-- 스테이지 무관 상수로 수렴한다") - g(1.15)가 아니라 k(1.155)를 쓰는 게 무기 배율과 다른
-- 유일한 차이다.
function CharacterLevel.getItemLevelMultiplier(level)
	if level <= MAX_FINITE_LEVEL then
		return 1 + CharacterLevelConfig.statBonusPerLevel * (level - 1)
	end
	return PEAK_MULTIPLIER * (InfiniteStageConfig.growthRate ^ (level - MAX_FINITE_LEVEL))
end

-- 장갑·신발(attackPercent/speedPercent) 전용 - 레벨25에서 동결한다(PRD-forge-game-roblox.md
-- 20.11-4 "attackPercent/speedPercent는 레벨25에서 동결, defenseFlat·maxHpBonus는 레벨25
-- 이후 k=1.155로 재성장을 연다"). 이유: 공격력 계열은 이미 무기 배율
-- (getWeaponExpMultiplier)이 레벨25 이후 지수 성장을 맡고 있다 - 장갑 공격력%까지 같이
-- 무한 성장하면 두 지수가 곱으로 겹쳐(사실상 지수의 지수) 처치 시간이 순식간에 0으로
-- 붕괴한다(17-1 [0]에서 실측 확인 - 레벨100에서 처치 시간이 1억분의 1초로 붕괴했었다).
-- defenseFlat·maxHpBonus는 그런 이중 계산 상대가 없어 동결하지 않는다(위 함수 그대로 재사용).
function CharacterLevel.getItemLevelMultiplierFrozen(level)
	return CharacterLevel.getItemLevelMultiplier(math.min(level, MAX_FINITE_LEVEL))
end

return CharacterLevel
