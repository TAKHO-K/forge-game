-- C2 전투 공식(순수 - 서버 피해 경로 · EconSim · 클라 표시가 같은 함수를 쓴다). 규칙 = shared/data/CombatFormulaData 머리 주석.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatFormulaData = require(ReplicatedStorage.Shared.data.CombatFormulaData)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)
local Sanitize = require(ReplicatedStorage.Shared.Sanitize)
local ReferenceBuild = require(ReplicatedStorage.Shared.ReferenceBuild) -- PROG-2B-1 3 몹 기준 함수(권장 전투력 = 몹 HP와 같은 계수)

local CombatFormula = {}

-- 검증 전용(DevTools 자동 검증 체인만 켠다 - 옛 피해 기대값 보존, CharacterLevel.debugLevelGapOff와 같은 방식 · 서버 사본만). C2(나)는 자기 항목에서 되켠다.
CombatFormula.debugOff = false

function CombatFormula.enabled()
	return CombatFormulaData.enabled == true and not CombatFormula.debugOff
end

-- 전투력(한 대 기대 피해) = 공격력 × 치명 기대.
function CombatFormula.offensePowerOf(attack, critRate, critDmg)
	local rate = math.clamp(critRate or 0, 0, 1)
	return Sanitize.number(attack * (1 + rate * math.max((critDmg or 1) - 1, 0)), 0)
end

-- loadout(BalanceSim.buildLoadout 모양 - atk · critMultAvg)의 전투력.
function CombatFormula.offensePower(loadout)
	return Sanitize.number(loadout.atk * (loadout.critMultAvg or 1), 0)
end

-- 표(스테이지 → 값) 로그 보간 · 양 끝 밖 = 끝값.
local function interpLog(points, stage)
	local n = #points
	if n == 0 then
		return 1
	end
	if stage <= points[1][1] then
		return points[1][2]
	end
	if stage >= points[n][1] then
		return points[n][2]
	end
	for i = 2, n do
		local b = points[i]
		if stage <= b[1] then
			local a = points[i - 1]
			local u = (stage - a[1]) / (b[1] - a[1])
			return math.exp(math.log(a[2]) + (math.log(b[2]) - math.log(a[2])) * u)
		end
	end
	return points[n][2]
end

-- 대표가 기준 구역 몹 1마리에 드는 한 대 수(스테이지).
function CombatFormula.representativeHits(stage)
	return interpLog(CombatFormulaData.representative.hits, stage)
end

local function referenceBaseHp()
	return MonsterData[MonsterData.tierOrder[CombatFormulaData.representative.referenceTier]].hp
end

-- W3b 파트 0 후반 벽(CombatFormulaData.lateWall): 권장 배수(lift - 평균 굴림 대표 비율 = 1 ÷ lift) · 주는 피해 평탄 하한(flatLow - 벽이 실제로 물리는 선). 표 밖 = 끝값.
function CombatFormula.lateLift(stage)
	local wall = CombatFormulaData.lateWall
	return wall and interpLog(wall.lift, stage) or 1
end

function CombatFormula.dealFlatLow(stage)
	local wall = CombatFormulaData.lateWall
	if not wall or type(stage) ~= "number" then
		return CombatFormulaData.deal.flatLow
	end
	return interpLog(wall.flatLow, stage)
end

-- 권장 전투력(스테이지 · 몹 기본 HP - 없으면 기준 구역 몹 = 스테이지 권장): 그 몹 HP(스테이지 적용) ÷ 대표 한 대 수 × 후반 벽 배수.
-- PROG-2B-1 3(CRIT-TRAIN-1 C7): × 몹 기준 함수 계수(ReferenceBuild.hpFactor - 몹 HP와 같은 계수 · 안 곱하면 새 힘을 가진 기준 빌드가 벽 벌칙을 벗어나 빨라짐).
function CombatFormula.recommendedPower(stage, baseHp)
	return math.max(InfiniteStage.getTrashHp(baseHp or referenceBaseHp(), stage) / CombatFormula.representativeHits(stage) * CombatFormula.lateLift(stage) * ReferenceBuild.hpFactor(stage), 1e-9) -- C4-1 잡몹 구간 배율(대표 = 잡몹 기준)
end

-- C3 0-3 화면 표시용 권장 전투력(판정은 recommendedPower): 표시 곡선(representative.displayHits - 실제 힘 점프를 완만히) 기준.
function CombatFormula.displayRecommendedPower(stage, baseHp)
	local points = CombatFormulaData.representative.displayHits or CombatFormulaData.representative.hits
	return math.max(InfiniteStage.getTrashHp(baseHp or referenceBaseHp(), stage) / interpLog(points, stage) * CombatFormula.lateLift(stage) * ReferenceBuild.hpFactor(stage), 1e-9) -- PROG-2B-1 3: 판정과 같은 계수
end

-- 권장 방어(스테이지 · 때린 몹의 공격 - 없으면 기준 구역 몹): α × 몹 공격 × 대표 방어 비율.
function CombatFormula.recommendedDefense(stage, attack)
	local a = attack or InfiniteStage.getTrashAttack(MonsterData[MonsterData.tierOrder[CombatFormulaData.representative.referenceTier]].attack, stage) -- C5-3 잡몹 공격 구간 배율
	return math.max(CombatConfig.damageReductionAlpha * a * interpLog(CombatFormulaData.representative.defenseRatio, stage) * CombatFormulaData.representative.defenseScale, 1e-9)
end

-- 곡선(연속 · 단조 증가): r → 배율. flatLow = 평탄 하한 덮어쓰기(후반 벽 - nil = c.flatLow · kneeLow 이상이어야 연속).
local function curve(c, r, flatLow)
	flatLow = flatLow or c.flatLow
	if r ~= r or r <= 0 then
		return c.floor
	end
	if r >= c.flatHigh then
		return math.min((r / c.flatHigh) ^ c.highExponent, c.highCap)
	elseif r >= flatLow then
		return 1
	end
	local knee = (c.kneeLow / flatLow) ^ c.midExponent
	if r >= c.kneeLow then
		return (r / flatLow) ^ c.midExponent
	end
	return math.max(knee * (r / c.kneeLow) ^ c.lowExponent, c.floor)
end
CombatFormula.curve = curve

-- 주는 피해 배율(스위치가 꺼져 있으면 1). stage = 후반 벽 평탄 하한을 읽을 스테이지(nil = 기본 flatLow).
function CombatFormula.dealMultiplierForRatio(r, stage)
	if not CombatFormula.enabled() then
		return 1
	end
	return curve(CombatFormulaData.deal, r, CombatFormula.dealFlatLow(stage))
end

-- stage = 몹 기준 스테이지(보스 = 보스 스테이지) · baseHp = 몹 기본 HP(nil = 기준 구역 = 보스).
function CombatFormula.dealMultiplier(power, stage, baseHp)
	if not CombatFormula.enabled() or type(power) ~= "number" or power <= 0 or type(stage) ~= "number" then
		return 1
	end
	return Sanitize.number(curve(CombatFormulaData.deal, power / CombatFormula.recommendedPower(stage, baseHp), CombatFormula.dealFlatLow(stage)), 1)
end

-- 받는 피해 배율(스위치가 꺼져 있으면 1): q = 방어 ÷ 권장 방어 → 1 ÷ 곡선.
function CombatFormula.takeMultiplierForRatio(q)
	if not CombatFormula.enabled() then
		return 1
	end
	return 1 / curve(CombatFormulaData.take, q)
end

-- attack = 때린 몹의 공격(감소식에 넣는 값 - 스테이지 적용 · 패턴 배율 전).
function CombatFormula.takeMultiplier(defense, stage, attack)
	if not CombatFormula.enabled() or type(defense) ~= "number" or type(stage) ~= "number" then
		return 1
	end
	return Sanitize.number(CombatFormula.takeMultiplierForRatio(defense / CombatFormula.recommendedDefense(stage, attack)), 1)
end

-- C5-1 장비 뒤처짐 신호(CombatFormulaData.gearLag): bestDealItemLevel = 가장 좋은 딜 부위 itemLevel(nil = 모름 → 1 · 0 = 미착용 → 벌점) · stage = 몹 기준 스테이지. 잡몹 전용(호출부가 보스를 거른다).
function CombatFormula.gearLagMultiplier(bestDealItemLevel, stage)
	local rule = CombatFormulaData.gearLag
	if not rule or not rule.enabled or not CombatFormula.enabled() or type(bestDealItemLevel) ~= "number" or type(stage) ~= "number" or stage <= rule.fromStage then
		return 1
	end
	local n = interpLog(rule.lagStages, stage)
	local lag = stage - bestDealItemLevel
	if lag + 1e-9 < n then -- 로그 보간 부동소수(10.000000000000002)로 N 정확히 부족한 경우가 빠지지 않게
		return 1
	end
	return Sanitize.number(math.max(1 / (1 + lag / n), rule.floor or 0), 1)
end

-- 보스전 제외인가(CombatFormulaData.bossExempt).
function CombatFormula.bossExempt()
	return CombatFormulaData.bossExempt == true
end

-- 처치 시간 배수(대표 = 1 · 보고서 · 표시): 1 ÷ (r × m(r)). stage = 후반 벽 평탄 하한(nil = 기본).
function CombatFormula.killTimeFactor(r, stage)
	return 1 / math.max(r * CombatFormula.dealMultiplierForRatio(r, stage), 1e-9)
end

-- 화면 표시 숫자.
function CombatFormula.display(power)
	return math.floor(power * CombatFormulaData.displayScale + 0.5)
end

return CombatFormula
