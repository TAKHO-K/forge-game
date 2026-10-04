-- QUEUE-ALL10 ALL10-P2 초월 계승 계산 한 곳(순수 - 서버 · 클라 화면 · EconSim · 하네스 공용). 숫자 = shared/data/All10Data.lua.
--   스위치(All10.enabled) = 꺼지면 모든 함수가 "지금 게임" 값(계수 1 · 보너스 0 · 해금 없음)을 돌려준다 → 호출부는 분기 없이 곱하고 더하기만 한다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local All10Data = require(ReplicatedStorage.Shared.data.All10Data)
local GoldCost = require(ReplicatedStorage.Shared.GoldCost)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)

local All10 = {}
All10.data = All10Data

local LN = math.log(1.02)

-- 기능 스위치(All10Economy): 데이터 값 · Studio에서만 ReplicatedStorage Attribute "All10Economy"(true/false)가 덮는다(라이브는 데이터 값만)
function All10.enabled()
	if RunService:IsStudio() then
		local override = ReplicatedStorage:GetAttribute("All10Economy")
		if type(override) == "boolean" then
			return override
		end
	end
	return All10Data.enabled == true
end

local function scaledGold(kills, bestStage, kind)
	return GoldCost.cost(MonsterData.tier1.goldDrop * kills * All10Data.killUnitScale, bestStage, kind)
end

-- ── 2-1 계승 ──
-- 계승 가능한 무기인가(QUEUE-ALL9E1 0-2: 등급 무관 +29 이상 · 이미 초월이면 아님). 같은 직업 조건은 무기가 직업별이라 자동(classes[직업].weapon).
function All10.canInherit(weapon)
	local d = All10Data.inherit
	return All10.enabled() and type(weapon) == "table" and weapon.grade ~= d.toGrade and (tonumber(weapon.level) or 0) >= d.requiredLevel
end

-- 계승하면 "+30 증표"를 받는가(계승 순간 단계 ≥ markLevel)
function All10.inheritGivesMark(weapon)
	return type(weapon) == "table" and (tonumber(weapon.level) or 0) >= All10Data.inherit.markLevel
end

function All10.isTranscendWeapon(weapon)
	return type(weapon) == "table" and weapon.grade == All10Data.inherit.toGrade and type(weapon.transcend) == "table"
end

-- ── 2-2 초월 강화(확정 · 10칸 분할) ──
-- 칸 하나 가격(골드) - 그 단계 비용 ÷ slots
function All10.transcendSlotCost(bestStage)
	local d = All10Data.transcendEnhance
	return scaledGold(d.levelKills / d.slots, bestStage, "transcend")
end

-- 초월 강화 공격 몫(무기 강화 줄에 더하는 값): 단계 + 칸/칸 수
function All10.transcendEnhanceBonus(transcend)
	if not All10.enabled() or type(transcend) ~= "table" then
		return 0
	end
	local d = All10Data.transcendEnhance
	local level = math.clamp(math.floor(tonumber(transcend.level) or 0), 0, d.maxLevel)
	local slot = level >= d.maxLevel and 0 or math.clamp(math.floor(tonumber(transcend.slot) or 0), 0, d.slots - 1)
	return d.perLevel * (level + slot / d.slots)
end

-- ── 2-3 고급 수련 · 방어 수련 ──
-- 고급 수련 단계 상한: 초월 무기 없음 = 50(해금 안 됨 - ★스테이지만으로 열지 않는다) · 있으면 50 + (최고 − capStart) ÷ capStep(maxLevel까지)
function All10.advancedCap(bestStage, hasTranscend)
	local d = All10Data.advancedTraining
	if not All10.enabled() or not hasTranscend then
		return d.fromLevel - 1
	end
	return math.clamp(d.fromLevel - 1 + math.floor(math.max(0, (bestStage or 0) - d.capStart) / d.capStep), d.fromLevel - 1, d.maxLevel)
end

-- level → level + 1 비용(level ≥ 50)
function All10.advancedCost(level, bestStage)
	local d = All10Data.advancedTraining
	local nextLevel = level + 1
	local kills = d.baseKills * d.growth ^ (nextLevel - d.fromLevel)
	if d.early and nextLevel <= d.early.untilLevel then
		kills *= d.early.factor
	end
	return scaledGold(kills, bestStage, "advTraining")
end

-- 고급 수련 공격 몫(영구 공격 버킷에 더함): (단계 − 50) × perLevel
function All10.advancedBonus(advLevel)
	if not All10.enabled() then
		return 0
	end
	local d = All10Data.advancedTraining
	return math.max(0, math.min(tonumber(advLevel) or 0, d.maxLevel) - (d.fromLevel - 1)) * d.perLevel
end

function All10.defenseUnlocked(bestStage, hasTranscend)
	return All10.enabled() and hasTranscend == true and (bestStage or 0) >= All10Data.defenseTraining.unlockStage
end

function All10.defenseCost(level, bestStage)
	local d = All10Data.defenseTraining
	return scaledGold(d.baseKills * d.growth ^ level, bestStage, "advTraining")
end

-- 받는 피해 배수(곱) - 서버 피해 식 · UI가 같은 함수
function All10.defenseTakeMultiplier(defLevel)
	if not All10.enabled() then
		return 1
	end
	local d = All10Data.defenseTraining
	return (1 - d.perLevel) ^ math.clamp(math.floor(tonumber(defLevel) or 0), 0, d.maxLevel)
end

-- ── 2-4 초월 보석 ──
function All10.transcendGemUnlocked(inheritRecord)
	return All10.enabled() and type(inheritRecord) == "table" and (tonumber(inheritRecord.at) or 0) > 0
end

-- ── 2-5 직업 특성 진화(직업 고유 능력 상한 +) ──
function All10.evolutionCapBonus(bestStage)
	if not All10.enabled() then
		return 0
	end
	local d = All10Data.evolution
	local n = 0
	for _, s in ipairs(d.stages) do
		if (bestStage or 0) >= s then
			n += 1
		end
	end
	return n * d.capBonusPerStep
end

-- ── 2-6 몹 곡선(D3 · D11) ──
-- 전역 재조정(HP): 16,000부터 1.02^(kappa · (s − 16,000))
function All10.hpCurveFactor(stage)
	if not All10.enabled() then
		return 1
	end
	local d = All10Data.monsterCurve
	return math.exp(d.curveKappa * LN * math.max(0, (stage or 0) - d.curveStart))
end

function All10.attackCurveFactor(stage)
	if not All10.enabled() then
		return 1
	end
	local d = All10Data.monsterCurve
	return math.exp(d.attackKappa * LN * math.max(0, (stage or 0) - d.curveStart))
end

-- 기준 빌드 배수(D11 "몹 스탯 = 기준 빌드 표 + 돌파 계수"): 그 스테이지의 중앙값 계승자가 가진 초월 성장 배수 - 무기(× weaponMultiplier) ×
--   고급 수련(상한까지 산다고 봄 - advancedCap) × 초월 강화(계승 스테이지 → refEndStage 사이 일정하게 +0 → +maxLevel). 공격 줄 구조는 PlayerCombat · 영구 버킷과 같은 꼴.
function All10.referenceBuild(stage, inheritStage)
	local d = All10Data
	local adv = All10.advancedCap(stage, true)
	local span = math.max(1, d.monsterCurve.refEndStage - inheritStage)
	local tLevel = d.transcendEnhance.maxLevel * math.clamp(((stage or 0) - inheritStage) / span, 0, 1)
	return d.inherit.weaponMultiplier * (1 + d.advancedTraining.perLevel * (adv - (d.advancedTraining.fromLevel - 1))) * (1 + d.transcendEnhance.perLevel * tLevel)
end

-- 돌파 계수(그 사람에게만 · 몹 HP에 곱함) - 계승 안 했으면 1:
--   기준 빌드 배수 × (계승 스테이지 S0부터 L 동안 1 / breakRatio) × 1.02^(followKappa · x) · x = max(0, s − S0)
--   QUEUE-ALL10 3-1(실제 EconSim): 이 게임은 처치 시간 목표가 일정해 진행 속도가 "몹 HP 대비 힘" 배수에 그대로 비례한다 →
--     몹 HP를 기준 빌드만큼 올리면 기준 빌드인 사람은 정상 속도 · 돌파 구간만 HP ÷ 2.4 = 속도 2.4배(D3) · 빨리 산 사람은 그만큼 빠르다.
--     (P1 근사 모형의 1.02^(−0.583x) 꼴은 실제 시뮬에서 앞선 몫이 1.02^875배로 쌓여 폭주 - 보고서 3절)
function All10.breakFactor(stage, inheritStage)
	if not All10.enabled() or type(inheritStage) ~= "number" or inheritStage <= 0 then
		return 1
	end
	local d = All10Data.monsterCurve
	local x = math.max(0, (stage or 0) - inheritStage)
	local window = x < d.breakLength and (1 / d.breakRatio) or 1
	return All10.referenceBuild(stage, inheritStage) * window * math.exp((d.followKappa or 0) * x * LN)
end

return All10
