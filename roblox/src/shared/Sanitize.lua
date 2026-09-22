-- NaN·inf 오염 차단 공용 출구(S21-0 A2, docs/stage-scaling-audit.md §1-2 ④ 참고).
-- math.max(NaN, 0)은 Luau에서 NaN을 그대로 돌려준다 - 한 번 섞이면 그 이후 어떤 연산을
-- 거쳐도 계속 NaN으로 남는다(자동회복 포함). 플레이어 스탯 합산·피해 계산·보상 계산이
-- 값을 확정하는 마지막 자리(출구)에서 이 함수 하나를 거쳐 오염을 그 자리에서 끊는다.
-- 핫패스(피해 계산, 매 히트)에서 써도 되게 정상값 경로는 비교 2회로 가볍게 유지한다 -
-- 경고 문자열 포맷팅 등 비용이 드는 작업은 오염이 실제로 감지됐을 때만 한다.

local Sanitize = {}

local warnedCallSites = {} -- key = "source:line" -> true(그 호출 위치에서 이미 경고했다)

local function warnOnce(value)
	-- level 1=warnOnce 자신, level 2=Sanitize.number, level 3=Sanitize.number를 부른 코드.
	local source, line = debug.info(3, "sl")
	local key = (source or "?") .. ":" .. tostring(line)
	if warnedCallSites[key] then
		return
	end
	warnedCallSites[key] = true
	warn(("[Sanitize] 비정상 값(%s) 감지 - 대체값으로 교체(%s:%s)"):format(tostring(value), tostring(source), tostring(line)))
end

-- value가 NaN 또는 ±inf면 fallback을 돌려주고(경고는 호출 위치당 1회만), 정상 값이면
-- value 그대로 돌려준다. 정상 값 경로는 비교 2회뿐이라 매 히트 호출에도 가볍다.
function Sanitize.number(value, fallback)
	if value ~= value or math.abs(value) == math.huge then
		warnOnce(value)
		return fallback
	end
	return value
end

return Sanitize
