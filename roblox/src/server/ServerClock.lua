-- QUEUE-ALL9B 5 · A8 서버 날짜 시계(퀘스트 · 접속 보상 · 7일 출석 · 시즌 출석판이 쓰는 "지금"). 출시 서버 = os.time() 그대로.
--   Studio에서만 /gg day <+n|reset>(DevTools)로 앞당긴 초를 더한다(날짜 넘기기 검증) - 출시 설정에서는 offset을 읽지도 쓰지도 않는다.
local RunService = game:GetService("RunService")

local ServerClock = {}

local offset = 0

function ServerClock.now()
	if offset ~= 0 and RunService:IsStudio() then
		return os.time() + offset
	end
	return os.time()
end

-- 반환: 적용했나(Studio만)
function ServerClock.shiftDays(days)
	if not RunService:IsStudio() then
		return false
	end
	offset += math.floor(days) * 86400
	return true
end

function ServerClock.reset()
	offset = 0
end

function ServerClock.offsetDays()
	return offset / 86400
end

return ServerClock
