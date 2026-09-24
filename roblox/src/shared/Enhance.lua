-- 강화 순수 계산 로직. 데이터(EnhanceConfig)와 분리해서 여기엔 공식만 둔다.
-- tryEnhance()는 math.random()을 직접 굴리지만, 실제로 골드를 쓰고 결과를 반영하는 흐름은
-- 반드시 서버(EnhanceServer.server.lua)에서만 호출해야 한다 - 클라이언트는 조회용 함수
-- (getCost/getProbability/getDamageMultiplier)만 UI 표시에 쓴다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EnhanceConfig = require(ReplicatedStorage.Shared.data.EnhanceConfig)
-- 28-1 S05: 방지권 상점가(getProtectionPrice)가 변환권과 같은 모양(잡몹 1마리당 골드 × 배수)이라 같은 모듈을 읽는다.
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
-- P2 C1: 골드 비용은 전부 GoldCost 한 곳을 거친다(강화 · 방지권 · 변환권).
local GoldCost = require(ReplicatedStorage.Shared.GoldCost)
-- P3c C1: 천장 구간 보정의 레벨 → 스테이지 척도(levelStageOffset).
local CharacterLevelConfig = require(ReplicatedStorage.Shared.data.CharacterLevelConfig)

local Enhance = {}

-- P2.5a R5: 강화의 공격력 곱연산 몫 = (1 + attackGrowthPerLevel)^단계(+30 = ×9.76). 최종 데미지 몫(+3.5%/강, 합연산)은 getFinalDamageBonus -
-- 두 몫의 곱이 강화 누적 배율(+30 = ×20)이다. 단계는 0 ~ maxLevel로 자른다.
function Enhance.getDamageMultiplier(level)
	local clamped = math.clamp(level or 0, 0, EnhanceConfig.maxLevel)
	return (1 + EnhanceConfig.attackGrowthPerLevel) ^ clamped
end

-- P2.5a R5: 강화가 최종 데미지 버킷에 더하는 값 = 단계 × finalDamagePerLevel(+30 = +105%). 버킷 합산은 PlayerCombat.getFinalDamageBonus.
function Enhance.getFinalDamageBonus(level)
	return math.clamp(level or 0, 0, EnhanceConfig.maxLevel) * EnhanceConfig.finalDamagePerLevel
end

-- 강화 누적 배율(공격력 몫 × 최종 데미지 몫) - 표시 · 시뮬 · 스테이지 환산용.
function Enhance.getTotalMultiplier(level)
	return Enhance.getDamageMultiplier(level) * (1 + Enhance.getFinalDamageBonus(level))
end

-- 상한이면 nil(시도 불가 - 웹 getEnhanceCost의 Infinity와 같은 뜻).
-- P2 C1: 1회 골드 = GoldCost.cost(표의 기본 비용, 계정 최고 스테이지, "enhance") - 골드 수입과 같은 비율로 커진다(P2.5a: 기준 스테이지 1 · 골드 성장률 - GoldCostConfig).
-- accountBestStage가 nil이면 표의 기본 비용(몬테카를로 기대 비용표 · 옛 검증처럼 스테이지와 무관한 계산용).
function Enhance.getCost(level, accountBestStage)
	if level >= EnhanceConfig.maxLevel then
		return nil
	end
	local cost = GoldCost.cost(EnhanceConfig.goldCost[level + 1], accountBestStage, "enhance")
	local discount = EnhanceConfig.ceilingDiscount
	if discount and level >= discount.fromEnhanceLevel and accountBestStage then
		cost = math.max(math.floor(cost * Enhance.getCeilingCostFactor(accountBestStage)), 1)
	end
	return cost
end

-- P3c C1 천장 구간 강화 비용 보정의 배수(1 = 보정 없음). EnhanceConfig.ceilingDiscount 주석 - 레벨 축(weaponGrowthSegments와 같은 축)의 두 점을 스테이지로 옮겨
-- (+ CharacterLevelConfig.levelStageOffset) 그 사이에서 1 → factor로 곧게 내린다.
function Enhance.getCeilingCostFactor(accountBestStage)
	local discount = EnhanceConfig.ceilingDiscount
	if not discount or not accountBestStage then
		return 1
	end
	local offset = CharacterLevelConfig.levelStageOffset
	local lo, hi = discount.rampFromLevel + offset, discount.fullAtLevel + offset
	local t = math.clamp((accountBestStage - lo) / (hi - lo), 0, 1)
	return 1 - (1 - discount.factor) * t
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

-- 위험이 시작되는 단계(28-1 S07): 확률표에서 처음으로 하락(down1 + down2)이 있는 단계, 처음으로 초기화(reset)가 있는 단계 - 구간 진입 확인창 · 도움말 문구가 "19강 · 22강"을
-- 표에서 읽는다(숫자를 UI에 박지 않는다). 없으면 nil.
function Enhance.getRiskStartLevels()
	local dropFrom, resetFrom
	for level, row in ipairs(EnhanceConfig.probability) do
		if not dropFrom and row.down1 + row.down2 > 0 then
			dropFrom = level - 1
		end
		if not resetFrom and row.reset > 0 then
			resetFrom = level - 1
		end
	end
	return dropFrom, resetFrom
end

-- 시도하기 전의 "최악의 경우" 단계 - 확률이 0보다 큰 결과 중 되는 단계(getResultLevel)가 가장 낮은 것. 상한이면 nil.
-- outcomes(선택)를 주면 그 표(방지권 · 게이지를 반영한 getOutcomeTable 결과)로 잰다. 없으면 방지권 · 게이지 없는 표다.
function Enhance.getWorstLevel(level, outcomes)
	outcomes = outcomes or Enhance.getOutcomeTable(level, false, false, false)
	if not outcomes then
		return nil
	end
	local worst = math.huge -- 확률이 있는 결과만 센다 - 불씨 가득 표(성공 100%)는 유지가 없어 level이 최악이 아니다
	for _, key in ipairs(RESULT_ORDER) do
		if outcomes[key] > 0 then
			worst = math.min(worst, Enhance.getResultLevel(level, key))
		end
	end
	return worst
end

-- 실패 1회가 채우는 천장 게이지(천분율 정수) = round(시도한 단계의 성공률 × gainPerSuccessRate). 상한이면 0.
function Enhance.getGaugeGain(level)
	local prob = Enhance.getProbability(level)
	if not prob then
		return 0
	end
	return math.floor(prob.success * EnhanceConfig.gauge.gainPerSuccessRate + 0.5)
end

-- 확률표 한 줄(outcomes)과 롤(0 이상 1 미만)로 결과 키를 고른다. 롤이 표 끝까지 안 걸리는 부동소수 극단값은 "확률이 있는 마지막 결과"로 둔다
-- (확률 0인 결과가 나오지 않게). tryEnhance와 검증(방지권이 "막았을 때만" 빠지는지)이 같은 함수를 읽는다.
function Enhance.rollResult(outcomes, roll)
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
	return result or lastPossible
end

-- 방지권 적용(28-1 S05, PRD 20.72 [1-3]) - **원래 확률표로 굴린 결과**를 받아, 하락(down1 · down2)이고 하락 방지 on이면 유지로, 초기화이고 초기화 방지 on이면
-- 유지로 바꾼다. 돌려주는 값: 최종 결과, 막은 방지권 종류("drop" / "reset" / nil). 막은 경우에만 blockedBy가 있다 = 그때만 방지권 1장이 소모된다
-- (성공 · 유지가 나온 시도에서는 절대 소모되지 않는다). getOutcomeTable(…, useDropTicket, useResetTicket)이 보여 주는 표(하락 확률이 유지에 합쳐진 표)와
-- 수학적으로 같다.
function Enhance.applyProtection(result, useDropTicket, useResetTicket)
	if useDropTicket and (result == "down1" or result == "down2") then
		return "maintain", "drop"
	end
	if useResetTicket and result == "reset" then
		return "maintain", "reset"
	end
	return result, nil
end

-- 서버 재검증(28-1 S05): 요청한 방지권 플래그 중 이번 시도에서 **실제로 쓸 수 있는 것**만 true로 남긴다 - 보유 ≥ 1 · 시도하는 단계 ≥ usableFromLevel ·
-- 게이지가 가득이 아님(가득이면 성공 100%라 무의미). 조건이 안 되면 요청을 거절하지 않고 그 플래그만 조용히 false로 바꾼다(토글을 켠 채 18강에서 눌러도
-- 강화는 된다). 요청 값이 boolean true가 아니면 false.
function Enhance.resolveProtectionFlags(level, gaugeFull, wantDrop, wantReset, haveDrop, haveReset)
	if gaugeFull then
		return false, false
	end
	local config = EnhanceConfig.protection
	local useDrop = wantDrop == true and haveDrop >= 1 and level >= config.drop.usableFromLevel
	local useReset = wantReset == true and haveReset >= 1 and level >= config.reset.usableFromLevel
	return useDrop, useReset
end

-- 방지권 상점가(골드) = 계정 최고 스테이지의 잡몹(tier1) 1마리당 골드 × priceKillEquivalent. 지금 서 있는 스테이지가 아니라 **계정 최고 스테이지**가
-- 기준이다(옵션 변환권과 같은 모양 - 스테이지 1로 내려가 싸게 사는 구멍을 막는다). kind = "drop" / "reset".
-- P2 C1: GoldCost(기준 스테이지 1) = InfiniteStage.getGoldReward와 같은 값 - P2 전과 한 자리도 안 바뀐다.
function Enhance.getProtectionPrice(kind, accountBestStage)
	return GoldCost.cost(MonsterData.tier1.goldDrop, accountBestStage, "protection") * EnhanceConfig.protection[kind].priceKillEquivalent
end

-- 보스 계정 첫 클리어 지급(28-1 S05) - 보스 스테이지 stage가 주는 방지권 장수. 반환: 하락 장수, 초기화 장수(0 또는 1). 식은 EnhanceConfig.protection.bossGrant.
function Enhance.getBossGrant(stage)
	local grant = EnhanceConfig.protection.bossGrant
	if stage < grant.firstStage or (stage - grant.firstStage) % grant.stepStages ~= 0 then
		return 0, 0
	end
	return 1, stage >= grant.resetFromStage and 1 or 0
end

-- 강화 판정 1회(순수 함수 - 저장 · 골드 · 재료 · 방지권 차감은 호출부 몫). flags = { useDropTicket, useResetTicket }(호출부가 resolveProtectionFlags로
-- 이미 검증한 값). roll은 검증용 주입(0 이상 1 미만, 없으면 math.random()).
-- 결과는 **방지권 없는 원래 확률표**로 굴린 뒤 applyProtection이 막을 수 있으면 유지로 바꾼다(S05 - 막았을 때만 소모). 게이지가 가득이면(>= gauge.max) 확정
-- 성공, 성공하면 게이지 0. **모든 실패**(막힌 시도 포함 - 막힌 시도도 실패다)가 getGaugeGain(시도한 단계)만큼 채운다(max에서 자른다) - 하락 · 초기화로
-- 단계가 바뀌어도 게이지는 유지된다.
-- 반환: { result, level(다음 단계), gauge(다음 게이지), gaugeWasFull, blockedBy }. 상한이면 result = "max".
function Enhance.tryEnhance(level, gauge, flags, roll)
	if level >= EnhanceConfig.maxLevel then
		return { result = "max", level = level, gauge = gauge, gaugeWasFull = false }
	end

	local gaugeMax = EnhanceConfig.gauge.max
	local gaugeWasFull = gauge >= gaugeMax
	local outcomes = Enhance.getOutcomeTable(level, gaugeWasFull, false, false)
	local rolled = Enhance.rollResult(outcomes, roll or math.random())
	local result, blockedBy = Enhance.applyProtection(rolled, flags and flags[1], flags and flags[2])

	local nextGauge = 0
	if result ~= "success" then
		nextGauge = math.min(gaugeMax, gauge + Enhance.getGaugeGain(level))
	end
	return { result = result, level = Enhance.getResultLevel(level, result), gauge = nextGauge, gaugeWasFull = gaugeWasFull, blockedBy = blockedBy }
end

-- 최종 공격력 = 무기 기본값 × 등급 배율 × 강화 배율 × 클래스 배율(10-2 [1], 등급 배율은
-- 20-1부터 인자로 받는다 - 실제 무기 등급(저장 데이터)을 읽는 건 호출부(PlayerCombat)
-- 몫이다, WeaponData.lua 주석 참고).
function Enhance.getPlayerAttack(weaponData, level, classMultiplier, gradeMultiplier)
	return weaponData.baseAttack * gradeMultiplier * Enhance.getDamageMultiplier(level) * classMultiplier
end

return Enhance
