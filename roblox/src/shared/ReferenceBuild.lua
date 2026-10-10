-- PROG-2B-1 몹 기준 함수 한 곳(순수 - 서버 몹 HP(MonsterStats) · 권장 전투력(CombatFormula) · 몹 정보 UI · EconSim이 같은 함수). 데이터 = shared/data/ReferenceBuildData.lua.
--   계수 = 새 규칙 기준 빌드의 한 대 기대 피해 ÷ 옛 규칙 기준 빌드의 한 대 기대 피해(스테이지 함수 · 플레이어와 무관) = 영구 버킷(수련) 비 × 치명 비.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReferenceBuildData = require(ReplicatedStorage.Shared.data.ReferenceBuildData)
local TrainingData = require(ReplicatedStorage.Shared.data.TrainingData)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local OptionData = require(ReplicatedStorage.Shared.data.OptionData)
local Training = require(ReplicatedStorage.Shared.Training)

local ReferenceBuild = {}

-- 영구 공격 버킷 몫(공용 수련 + 기준 직업 능력) - 상한까지 산 기준 빌드. 반환 = 새, 옛
local function bucketAt(stage)
	local d = ReferenceBuildData
	local ability = 0
	for _, def in ipairs(TrainingData.classAbilities[d.refClass] or {}) do
		if def.bucket == "attack" then
			ability += def.perLevel * Training.capFor(def, stage)
		end
	end
	local new = 0
	for _, def in ipairs(TrainingData.stats) do
		if def.bucket == "attack" then
			new += def.perLevel * Training.capFor(def, stage)
		end
	end
	local L = d.legacyTraining
	local old = L.attackPerLevel * math.min(L.maxLevel, math.floor(math.max(0, stage) / L.stagesPerLevel))
	return d.bucketBase + ability + new, d.bucketBase + ability + old
end

-- 레벨 치명 곡선(PlayerCombat.getLevelCritBonus와 같은 꼴 - 사이 선형 · 끝 밖 끝값)
local function curveAt(curve, level)
	if level <= curve[1].level then
		return curve[1].bonus
	end
	for i = 2, #curve do
		local a, b = curve[i - 1], curve[i]
		if level <= b.level then
			return a.bonus + (b.bonus - a.bonus) * (level - a.level) / (b.level - a.level)
		end
	end
	return curve[#curve].bonus
end

local function refAt(stage)
	local t = ReferenceBuildData.crit.ref
	if stage <= t[1][1] then
		return t[1]
	end
	for i = 2, #t do
		if stage <= t[i][1] then
			local a, b = t[i - 1], t[i]
			local u = (stage - a[1]) / (b[1] - a[1])
			return { stage, a[2] + (b[2] - a[2]) * u, a[3] + (b[3] - a[3]) * u, a[4] + (b[4] - a[4]) * u, a[5] + (b[5] - a[5]) * u }
		end
	end
	return t[#t]
end

-- 치명 수련 상한까지 산 몫(critAxis = "rate" | "dmg")
local function critTrainingAt(stage, axis)
	local v = 0
	for _, def in ipairs(TrainingData.stats) do
		if def.critAxis == axis then
			v += def.perLevel * Training.capFor(def, stage)
		end
	end
	return v
end

-- 한 대 기대 피해(치명 · 위력 버킷 몫만): r = 확률 합(상한 전) · dGear = 장비 · 보석 치명 피해(상한 critDmgBonusCap 안) · dTrain = 수련 몫(상한 밖) · a = 위력 버킷
--   mode = "equal"(넘친 확률 = 같은 기대 피해 → 위력) | 그 밖(넘친 확률 1 = 위력 perCrit)
function ReferenceBuild.critHit(r, dGear, dTrain, a, m0, mode, perCrit)
	local m = m0 + math.min(dGear, CombatConfig.critDmgBonusCap) + dTrain
	local o = math.max(r - 1, 0)
	local conv
	if mode == "equal" then
		conv = o * (m - 1) / m * (1 + a)
	else
		conv = o * (perCrit or 0)
	end
	return (1 + math.min(a + conv, OptionData.options.attackPercent.cap)) * (1 + math.min(r, 1) * (m - 1))
end

-- 치명 비(새 규칙 ÷ 옛 규칙) - 지금 치명 규칙이 옛 것과 같으면 정확히 1
function ReferenceBuild.critFactor(stage)
	local c = ReferenceBuildData.crit
	local x = refAt(stage or 0)
	local r, d, a, level = x[2], x[3], x[4], x[5]
	local m0 = ClassData.classes[ReferenceBuildData.refClass].critDmg
	local den = ReferenceBuild.critHit(r, d, 0, a, m0, "legacy", c.legacyOverCritPerCrit)
	local rN = r - (curveAt(c.legacyCritCurve, level) - curveAt(CombatConfig.critCurve, level)) + critTrainingAt(stage or 0, "rate")
	local over = CombatConfig.overCrit or {}
	local num = ReferenceBuild.critHit(rN, d, critTrainingAt(stage or 0, "dmg"), a, m0, over.mode, over.attackPercentPerCrit)
	return num / den
end

-- 영구 버킷(수련) 비
function ReferenceBuild.bucketFactor(stage)
	local new, old = bucketAt(stage or 0)
	return new / old
end

-- 몹 HP · 권장 전투력 계수(스테이지) - 1 = 옛 규칙과 같음
function ReferenceBuild.hpFactor(stage)
	return ReferenceBuild.bucketFactor(stage) * ReferenceBuild.critFactor(stage)
end

return ReferenceBuild
