-- 캐릭터 레벨 곡선·배율이 실제로 계산되는 유일한 위치(13-2, PlayerCombat·InfiniteStage와
-- 같은 이유). 레벨을 소비하는 두 곳(무기 공격력 - PlayerCombat.getAttack, 아이템 레벨계수 -
-- Loot.getArmorDefense) 모두 이 모듈을 거친다.
--
-- 25-1: 경험치 요구치는 "목표 마릿수 곡선"에서 역산한다(CharacterLevelConfig.killTargetAnchors
-- 주석 참고). 순서가 중요하다 - 마릿수 K(L)을 먼저 정의하고, 레벨 L→L+1 필요 경험치를
-- round(K(L) × E(L))로 만든다(E(L) = tier1 몬스터가 스테이지 L에서 실제로 주는 경험치,
-- InfiniteStage.getExpReward와 같은 floor까지 그대로). 이렇게 하면 "자기 레벨 스테이지에서
-- 사냥할 때 레벨당 K(L)마리"가 경험치 계수·성장률 k와 무관하게 구조적으로 성립한다.
-- 곡선은 환생 회차와 무관하게 하나다 - 환생 후 스테이지가 1로 돌아가고 레벨도 1이라 같은
-- 레벨에선 같은 몬스터를 잡으므로, 회차 배수(옛 firstRunExpMultiplier·rebirthCount+1)는 없앴다.
-- 필요 경험치를 정수로 만드는 이유: E(L)도 정수라 누적치·증가분이 전부 2^53 아래 정수로
-- 정확히 표현되고, "정확히 K마리째에 레벨업"이 부동소수점 오차로 K+1마리가 되는 일이 없다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharacterLevelConfig = require(ReplicatedStorage.Shared.data.CharacterLevelConfig)
local InfiniteStageConfig = require(ReplicatedStorage.Shared.data.InfiniteStageConfig)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)

local CharacterLevel = {}

local STAT_LINEAR_MAX_LEVEL = CharacterLevelConfig.statLinearMaxLevel -- 25
local PEAK_MULTIPLIER = 1 + CharacterLevelConfig.statBonusPerLevel * (STAT_LINEAR_MAX_LEVEL - 1) -- 2.44
local ANCHORS = CharacterLevelConfig.killTargetAnchors

-- 레벨 L→L+1에 필요한 목표 처치 수 K(L). 앵커 사이 선형 보간, 첫 앵커 앞·마지막 앵커 뒤는
-- 그 앵커 값으로 고정(레벨125 이후는 레벨당 25마리 - 옛 "625마리 항등식"이 여기서만 성립).
function CharacterLevel.getTargetKills(level)
	if level <= ANCHORS[1].level then
		return ANCHORS[1].kills
	end
	for i = 2, #ANCHORS do
		local a, b = ANCHORS[i - 1], ANCHORS[i]
		if level <= b.level then
			return a.kills + (b.kills - a.kills) * (level - a.level) / (b.level - a.level)
		end
	end
	if level > ANCHORS[#ANCHORS].level then
		return CharacterLevelConfig.killTargetAfterAnchors or ANCHORS[#ANCHORS].kills -- P2.5c: 5회 환생 뒤 곡선
	end
	return ANCHORS[#ANCHORS].kills
end

-- 스테이지 L에서 tier1 몬스터 1마리가 주는 경험치 E(L) - 실제 지급 경로(MonsterState.
-- getExpRewardFor → InfiniteStage.getExpReward)와 같은 식·같은 floor. 목표 마릿수의 전제
-- "자기 레벨에 맞는 스테이지에서 사냥"이 곧 stage = level이다.
-- P2.5a C10: 레벨 → 스테이지 척도(앵커 장비의 처치 스테이지 - CharacterLevelConfig.levelStageOffset 주석). 환생 지급 보석 itemLevel이 이 값이다.
function CharacterLevel.getStageForLevel(level)
	return level + CharacterLevelConfig.levelStageOffset
end

-- P2.5a C3: "레벨 L의 척도 스테이지(getStageForLevel)에서 tier1 1마리가 주는 경험치"(옛: 스테이지 L - 옛 k에서는 척도 오프셋이 0이었다). 지급 경로와 같은 식 · 같은 floor.
function CharacterLevel.getMonsterExpAtLevel(level)
	return InfiniteStage.getExpReward(MonsterData.tier1.expReward, CharacterLevel.getStageForLevel(level))
end

-- 레벨 L→L+1 필요 경험치(정수). 위 모듈 주석 참고.
function CharacterLevel.getExpToNextLevel(level)
	return math.floor(CharacterLevel.getTargetKills(level) * CharacterLevel.getMonsterExpAtLevel(level) + 0.5)
end

-- 누적 임계값 메모(thresholds[level] = 그 레벨 도달 누적 경험치). 지수 성장이라 실제 도달
-- 레벨은 수백을 넘지 않는다 - 필요한 만큼만 앞에서부터 채운다.
local thresholds = { 0 }
local function ensureThreshold(level)
	for l = #thresholds + 1, level do
		thresholds[l] = thresholds[l - 1] + CharacterLevel.getExpToNextLevel(l - 1)
	end
end

-- 그 레벨에 도달하기 위한 누적 경험치. 레벨1은 0.
function CharacterLevel.getExpForLevel(level)
	ensureThreshold(level)
	return thresholds[level]
end

-- 누적 경험치로 현재 레벨을 구한다. 다음 임계값을 넘는지 반복 검사한다 - 증가분이 지수식이라
-- 몬스터 한 마리로 레벨이 여러 개 뛰는 일은 실제로 없어 반복 횟수가 크게 자라지 않는다.
-- P2.5a: 레벨이 수만까지 가므로(스테이지당 2%) 1부터 세는 반복 대신 두 배씩 넓힌 뒤 이분 탐색한다(누적 임계값은 단조 증가). 결과는 옛 반복과 같다.
function CharacterLevel.getLevelFromExp(exp)
	if exp ~= exp or exp < CharacterLevel.getExpForLevel(2) then -- NaN이면 1(옛 반복과 같다 - 리뷰 11)
		return 1
	end
	local lo, hi = 2, 4
	-- 상한 2^20(약 105만) - exp가 inf여도(임계값도 결국 inf) 끝난다.
	while exp >= CharacterLevel.getExpForLevel(hi) and hi < 2 ^ 20 do
		lo, hi = hi, hi * 2
	end
	if exp >= CharacterLevel.getExpForLevel(hi) then
		return hi
	end
	-- 불변식: getExpForLevel(lo) <= exp < getExpForLevel(hi)
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if exp >= CharacterLevel.getExpForLevel(mid) then
			lo = mid
		else
			hi = mid
		end
	end
	return lo
end

-- 다음 레벨까지 진행률(UI 표시용).
function CharacterLevel.getProgress(exp, level)
	local currentThreshold = CharacterLevel.getExpForLevel(level)
	local nextThreshold = CharacterLevel.getExpForLevel(level + 1)
	local needed = nextThreshold - currentThreshold
	local current = exp - currentThreshold
	return { current = current, needed = needed, ratio = needed > 0 and current / needed or 1 }
end

-- 레벨 L 임계값에서 출발해 스테이지 L의 tier1만 잡을 때 실제로 레벨업까지 걸리는 마릿수.
-- expGainMultiplier는 획득 경험치 배수(PlayerProfile.getExpGainMultiplier - 지금은 1.0, 다음
-- 세션의 "경험치 획득량 +최대 25%" 옵션이 곱해질 자리). 목표 K(L)이 정수가 아니면 올림이라
-- K(L)보다 1 큰 값이 나올 수 있다(그 남는 경험치는 다음 레벨로 이월되므로 장기 평균은 K(L)).
function CharacterLevel.getExpectedKills(level, expGainMultiplier)
	local perKill = CharacterLevel.getMonsterExpAtLevel(level) * (expGainMultiplier or 1)
	return math.ceil(CharacterLevel.getExpToNextLevel(level) / perKill - 1e-9)
end

-- 무기 공격력 배율(PlayerCombat.getAttack이 곱한다). 1~25는 웹과 완전히 같은 선형식,
-- (P2.5a: g = k = 1.02 · 레벨 20,000부터 1.01 - CharacterLevelConfig.weaponGrowthLate. 아래는 옛 설명)
-- 26+는 20.10이 정한 지수식(g=1.15, 몬스터 k=1.155보다 살짝 낮게 - 스테이지가 오를수록
-- 아주 조금씩 어려워지도록 의도된 격차).
function CharacterLevel.getWeaponExpMultiplier(level)
	if level <= STAT_LINEAR_MAX_LEVEL then
		return 1 + CharacterLevelConfig.statBonusPerLevel * (level - 1)
	end
	-- P2.5a C2 구간별 g: weaponGrowthLate.fromLevel까지 g, 그 뒤로 late.rate(< k - 천장).
	local late = CharacterLevelConfig.weaponGrowthLate
	local mainLevels = math.min(level, late.fromLevel) - STAT_LINEAR_MAX_LEVEL
	local lateLevels = math.max(0, level - late.fromLevel)
	return PEAK_MULTIPLIER * (CharacterLevelConfig.weaponMultGrowthRate ^ mainLevels) * (late.rate ^ lateLevels)
end

-- 아이템 레벨계수(Loot.getArmorDefense가 곱한다). 1~25는 무기 배율과 같은 선형식(레벨25
-- 시점 무기 공격력·아이템 스탯이 나란히 2.44배로 정점을 찍는 대칭, data/items.js 75-78행
-- 설계 의도 재사용). 26+는 몬스터와 같은 k(InfiniteStageConfig.growthRate 재사용 - P2.5a부터 1.02,
-- PRD-forge-game-roblox.md 20.11-4 "defenseFlat도 k로 키워야 방어력/몬스터공격력 비율이
-- 스테이지 무관 상수로 수렴한다") - g(1.15)가 아니라 k(1.155)를 쓰는 게 무기 배율과 다른
-- 유일한 차이다.
function CharacterLevel.getItemLevelMultiplier(level)
	if level <= STAT_LINEAR_MAX_LEVEL then
		return 1 + CharacterLevelConfig.statBonusPerLevel * (level - 1)
	end
	return PEAK_MULTIPLIER * (InfiniteStageConfig.growthRate ^ (level - STAT_LINEAR_MAX_LEVEL))
end

-- 장갑·신발(attackPercent/speedPercent) 전용 - 레벨25에서 동결한다(PRD-forge-game-roblox.md
-- 20.11-4 "attackPercent/speedPercent는 레벨25에서 동결, defenseFlat·maxHpBonus는 레벨25
-- 이후 k=1.155로 재성장을 연다"). 이유: 공격력 계열은 이미 무기 배율
-- (getWeaponExpMultiplier)이 레벨25 이후 지수 성장을 맡고 있다 - 장갑 공격력%까지 같이
-- 무한 성장하면 두 지수가 곱으로 겹쳐(사실상 지수의 지수) 처치 시간이 순식간에 0으로
-- 붕괴한다(17-1 [0]에서 실측 확인 - 레벨100에서 처치 시간이 1억분의 1초로 붕괴했었다).
-- defenseFlat·maxHpBonus는 그런 이중 계산 상대가 없어 동결하지 않는다(위 함수 그대로 재사용).
function CharacterLevel.getItemLevelMultiplierFrozen(level)
	return CharacterLevel.getItemLevelMultiplier(math.min(level, STAT_LINEAR_MAX_LEVEL))
end

-- P2 B: 환생 rebirthCount회 상태에서 다음 환생에 필요한 레벨(PlayerProfile.rebirth · 환생 UI · EconSim이 이 함수 하나를 본다). 표 밖(최대 회차)이면 nil.
function CharacterLevel.getRebirthRequiredLevel(rebirthCount)
	return CharacterLevelConfig.rebirth.requiredLevels[(rebirthCount or 0) + 1]
end

-- P2.5c 결정 3: 환생 rebirthCount회 상태의 캐릭터 경험치 획득 배율(CharacterLevelConfig.rebirth.expMultipliers - 표 밖이면 마지막 값). 캐릭터 경험치에만 곱한다.
function CharacterLevel.getRebirthExpMultiplier(rebirthCount)
	local list = CharacterLevelConfig.rebirth.expMultipliers
	return list[math.clamp((rebirthCount or 0) + 1, 1, #list)]
end

return CharacterLevel
