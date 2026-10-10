-- PROG-2B-1 몹 기준 함수 한 곳(순수 - 서버 몹 HP(MonsterStats) · 몹 정보 UI · EconSim이 같은 함수). 데이터 = shared/data/ReferenceBuildData.lua.
--   계수 = 새 규칙 기준 빌드의 한 대 기대 피해 ÷ 옛 규칙 기준 빌드의 한 대 기대 피해(스테이지 함수 · 플레이어와 무관).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReferenceBuildData = require(ReplicatedStorage.Shared.data.ReferenceBuildData)
local TrainingData = require(ReplicatedStorage.Shared.data.TrainingData)
local Training = require(ReplicatedStorage.Shared.Training)

local ReferenceBuild = {}

-- 영구 공격 버킷 몫(공용 수련 + 기준 직업 능력) - 상한까지 산 기준 빌드
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

-- 몹 HP 계수(스테이지) - 1 = 옛 규칙과 같음
function ReferenceBuild.hpFactor(stage)
	local new, old = bucketAt(stage or 0)
	return new / old
end

return ReferenceBuild
