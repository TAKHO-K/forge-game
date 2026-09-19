-- 강화 순수 계산 로직. 데이터(EnhanceConfig)와 분리해서 여기엔 공식만 둔다.
-- tryEnhance()는 math.random()을 직접 굴리지만, 실제로 골드를 쓰고 결과를 반영하는 흐름은
-- 반드시 서버(EnhanceServer.server.lua)에서만 호출해야 한다 - 클라이언트는 조회용 함수
-- (getCost/getProbability/getDamageMultiplier)만 UI 표시에 쓴다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EnhanceConfig = require(ReplicatedStorage.Shared.data.EnhanceConfig)

local Enhance = {}

function Enhance.getDamageMultiplier(level)
	local coefficient = EnhanceConfig.damageCoefficient[level + 1] or 0
	return 1 + coefficient
end

-- 상한이면 nil(시도 불가 - 웹 getEnhanceCost의 Infinity와 같은 뜻).
function Enhance.getCost(level)
	if level >= EnhanceConfig.maxLevel then
		return nil
	end
	return EnhanceConfig.goldCost[level + 1]
end

function Enhance.getProbability(level)
	if level >= EnhanceConfig.maxLevel then
		return nil
	end
	return EnhanceConfig.probability[level + 1]
end

-- 28-1(S03) 결과 5종. 표의 순서 = 판정 순서(success → maintain → down1 → down2 → reset). 파괴(소멸)는 없다(10-2 지시, 웹 v1에도 없었다).
local RESULT_ORDER = { "success", "maintain", "down1", "down2", "reset" }

-- 데이터 로드 시 행 합 검사(PRD 20.72 [1-6] 1번) - EnhanceConfig에 0.045 같은 값이 있어 한 행의 합이 1에서 어긋나기 쉽다. 이 모듈이
-- 서버 시작 때 require되므로 어긋나면 그때 에러가 난다(서버 판정과 UI가 같은 표를 읽는다).
for level, row in ipairs(EnhanceConfig.probability) do
	local sum = 0
	for _, key in ipairs(RESULT_ORDER) do
		sum += row[key]
	end
	if math.abs(sum - 1) > 1e-9 then
		error(("EnhanceConfig.probability[+%d]의 합이 1이 아니다: %.12f"):format(level - 1, sum))
	end
end

-- 시도 전에 화면과 서버가 함께 읽는 "결과별 확률" 한 줄(합 100%) - PRD 20.72 [1-6] 1 · 2번. gaugeFull이면 성공 100%(천장). 방지권(S05)
-- 인자: useDropTicket이면 하락(down1 + down2)을, useResetTicket이면 초기화를 "막았다" - 막힌 확률은 maintain에 합쳐진다.
-- 서버 판정과 (나중의) UI가 이 함수 하나를 읽는다. 상한이면 nil.
function Enhance.getOutcomeTable(level, gaugeFull, useDropTicket, useResetTicket)
	local prob = Enhance.getProbability(level)
	if not prob then
		return nil
	end
	if gaugeFull then
		return { success = 1, maintain = 0, down1 = 0, down2 = 0, reset = 0 }
	end
	local maintain, down1, down2, reset = prob.maintain, prob.down1, prob.down2, prob.reset
	if useDropTicket then
		maintain += down1 + down2
		down1, down2 = 0, 0
	end
	if useResetTicket then
		maintain += reset
		reset = 0
	end
	return { success = prob.success, maintain = maintain, down1 = down1, down2 = down2, reset = reset }
end

-- 결과가 만드는 다음 단계. 하락은 어디서 시작해도 downFloorLevel(18)에서 멈추고, 초기화는 resetToLevel(12)로 간다(옛 "math.max(1, …)" ·
-- "리셋 = 1강"은 없앴다). 검산: 19 → 18 · 20 → 18 · 21 → 19 · 22 → 21 또는 20.
function Enhance.getResultLevel(level, result)
	if result == "success" then
		return level + 1
	elseif result == "down1" then
		return math.max(EnhanceConfig.downFloorLevel, level - 1)
	elseif result == "down2" then
		return math.max(EnhanceConfig.downFloorLevel, level - 2)
	elseif result == "reset" then
		return EnhanceConfig.resetToLevel
	end
	return level -- maintain
end

-- 실패 1회가 채우는 천장 게이지(천분율 정수) = round(시도한 단계의 성공률 × gainPerSuccessRate). 상한이면 0.
function Enhance.getGaugeGain(level)
	local prob = Enhance.getProbability(level)
	if not prob then
		return 0
	end
	return math.floor(prob.success * EnhanceConfig.gauge.gainPerSuccessRate + 0.5)
end

-- 강화 판정 1회(순수 함수 - 저장 · 골드는 호출부 몫). flags = { useDropTicket, useResetTicket }(순서 그대로 - 방지권은 S05, 서버는 지금
-- { false, false }만 넘긴다). roll은 검증용 주입(0 이상 1 미만, 없으면 math.random()).
-- 게이지가 가득이면(>= gauge.max) 확정 성공, 성공하면 게이지 0. **모든 실패**(maintain · down1 · down2 · reset)가 getGaugeGain(시도한 단계)만큼
-- 채운다(max에서 자른다) - 하락 · 초기화로 단계가 바뀌어도 게이지는 유지된다.
-- 반환: { result, level(다음 단계), gauge(다음 게이지), gaugeWasFull }. 상한이면 result = "max".
function Enhance.tryEnhance(level, gauge, flags, roll)
	if level >= EnhanceConfig.maxLevel then
		return { result = "max", level = level, gauge = gauge, gaugeWasFull = false }
	end

	local gaugeMax = EnhanceConfig.gauge.max
	local gaugeWasFull = gauge >= gaugeMax
	local outcomes = Enhance.getOutcomeTable(level, gaugeWasFull, flags and flags[1], flags and flags[2])
	roll = roll or math.random()

	local result, lastPossible, acc = nil, "success", 0
	for _, key in ipairs(RESULT_ORDER) do
		if outcomes[key] > 0 then
			lastPossible = key
		end
		acc += outcomes[key]
		if not result and roll < acc then
			result = key
		end
	end
	result = result or lastPossible -- 부동소수 합이 1에 모자란 극단값 - 확률이 있는 마지막 결과로 둔다(확률 0인 결과가 나오지 않게)

	local nextGauge = 0
	if result ~= "success" then
		nextGauge = math.min(gaugeMax, gauge + Enhance.getGaugeGain(level))
	end
	return { result = result, level = Enhance.getResultLevel(level, result), gauge = nextGauge, gaugeWasFull = gaugeWasFull }
end

-- 최종 공격력 = 무기 기본값 × 등급 배율 × 강화 배율 × 클래스 배율(10-2 [1], 등급 배율은
-- 20-1부터 인자로 받는다 - 실제 무기 등급(저장 데이터)을 읽는 건 호출부(PlayerCombat)
-- 몫이다, WeaponData.lua 주석 참고).
function Enhance.getPlayerAttack(weaponData, level, classMultiplier, gradeMultiplier)
	return weaponData.baseAttack * gradeMultiplier * Enhance.getDamageMultiplier(level) * classMultiplier
end

return Enhance
