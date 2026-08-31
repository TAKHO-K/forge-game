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

-- 강화 판정. 결과는 5종: success/maintain/down1/down2/reset - 파괴는 없다(10-2 지시,
-- 웹 v1에도 원래 없었다). 강등은 +1 밑으로 내려가지 않는다(웹 core/enhance.js와 동일 -
-- math.max(1, ...)). +0 상태에서는 확률표(EnhanceConfig.probability[1])의 down1/down2/reset이
-- 전부 0이라 이 하한이 실제로 걸릴 일은 없다.
function Enhance.tryEnhance(level)
	if level >= EnhanceConfig.maxLevel then
		return { result = "max", level = level }
	end

	local prob = Enhance.getProbability(level)
	local roll = math.random()
	local acc = 0

	acc += prob.success
	if roll < acc then
		return { result = "success", level = level + 1 }
	end

	acc += prob.maintain
	if roll < acc then
		return { result = "maintain", level = level }
	end

	acc += prob.down1
	if roll < acc then
		return { result = "down1", level = math.max(1, level - 1) }
	end

	acc += prob.down2
	if roll < acc then
		return { result = "down2", level = math.max(1, level - 2) }
	end

	return { result = "reset", level = 1 }
end

-- 최종 공격력 = 무기 기본값 × 강화 배율 × 등급 배율 × 클래스 배율(10-2 [1]).
function Enhance.getPlayerAttack(weaponData, level, classMultiplier)
	return weaponData.baseAttack * weaponData.gradeMultiplier * Enhance.getDamageMultiplier(level) * classMultiplier
end

return Enhance
