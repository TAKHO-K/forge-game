-- PROG-2B-1 2: 처치 골드 보너스 합 규칙 한 곳(순수 - 서버 CombatResolution · EconSim). 데이터 = shared/data/GoldBonusData.lua(목록 · 상한).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GoldBonusData = require(ReplicatedStorage.Shared.data.GoldBonusData)

local GoldBonus = {}

-- % 보너스 목록(소수 - 0.25 = +25%) → 합(상한 cap). 음수 · 비정상 값은 0으로 친다.
function GoldBonus.total(bonuses)
	local sum = 0
	for _, b in ipairs(bonuses or {}) do
		if type(b) == "number" and b == b and b > 0 and b ~= math.huge then
			sum += b
		end
	end
	return math.min(sum, GoldBonusData.cap)
end

-- 처치 골드 = floor(기본 골드 × (1 + % 보너스 합) + 고정 덤). 기본 골드 = 접두사 · 반짝이 자기 몫(× 0.5)까지 곱한 값 · 덤 = 반짝이 N마리분.
function GoldBonus.killGold(baseGold, bonuses, flat)
	return math.floor(baseGold * (1 + GoldBonus.total(bonuses)) + (flat or 0))
end

return GoldBonus
