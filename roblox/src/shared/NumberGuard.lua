-- PROG-2B-1 2(PROG-2A D15 · 지시 "2^53 내부 안전 상한 + 공용 검증 함수"): 골드 · 피해 · 체력 · 비용 · 저장 직전이 같은 함수로 숫자를 확정한다.
--   ① NaN · ±무한대 · 음수 · 숫자 아님 = 그대로 막음(대체값 - 경고는 Sanitize와 같이 호출 위치당 1번)
--   ② 골드(정수 화폐)만 내부 안전 상한 2^53(9.0e15 - double이 정수를 정확히 세는 끝)에서 자른다. 골드 곡선 C(√)에서 진행 끝 보유 최대 약 1e10이라 실제로는 안 닿는다(안전장치).
--      피해 · 체력은 스테이지 배율로 1e219까지 크는 실수라 상한을 걸지 않는다(①만).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Sanitize = require(ReplicatedStorage.Shared.Sanitize)

local NumberGuard = {}

NumberGuard.SAFE_MAX = 2 ^ 53

-- 0 이상 유한한 수(피해 · 체력 · 비용 · 보상 금액). 아니면 fallback(기본 0).
function NumberGuard.amount(value, fallback)
	fallback = fallback or 0
	if type(value) ~= "number" then
		return fallback
	end
	value = Sanitize.number(value, fallback)
	if value < 0 then
		return fallback
	end
	return value
end

-- 골드 잔액: amount + [0, 2^53]. 반환 = 값, 상한에서 잘렸는가
function NumberGuard.gold(value)
	local v = NumberGuard.amount(value, 0)
	if v > NumberGuard.SAFE_MAX then
		return NumberGuard.SAFE_MAX, true
	end
	return v, false
end

return NumberGuard
