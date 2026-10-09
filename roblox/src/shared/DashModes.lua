-- FINAL-1 3 MOVE-2 대시 입력 규칙(순수 계산 - 클라 입력 · 서버 판정 · 하네스가 같은 식을 쓴다). 수치 = DashConfig.modes · doubleTap · analog · backflip.
--   long  = 방향키(없으면 바라보는 쪽) + 대시 키 · short = W/A/D 두 번 연속 · analog = 폰 스틱 · 게임패드(기울기 0 ~ 1 → short ~ long 사이 연속) · S 두 번 연속 = 백플립(대시 아님 - 점프 1회)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DashConfig = require(ReplicatedStorage.Shared.data.DashConfig)

local DashModes = {}

-- 모드 이름 · 기울기 → 기본 거리(stud · 이동 속도 배율 전) · 지속(초). 모르는 모드 = long(서버가 클라 값을 그대로 믿지 않는다)
function DashModes.base(mode, tilt)
	local short, longR, longD = DashConfig.modes.short, DashConfig.rangeStuds, DashConfig.durationSeconds
	if mode == "short" then
		return short.rangeStuds, short.durationSeconds
	elseif mode == "analog" then
		local a = DashConfig.analog
		local t = math.clamp(((tonumber(tilt) or 1) - a.deadzone) / (1 - a.deadzone), 0, 1)
		return short.rangeStuds + (longR - short.rangeStuds) * t, short.durationSeconds + (longD - short.durationSeconds) * t
	end
	return longR, longD
end

-- 두 번 연속 누름 판정기: 같은 키를 window초 안에 다시 누르면 true(판정 뒤 기록을 비운다 - 세 번째가 또 연속이 되지 않게)
function DashModes.newTapState()
	return { key = nil, at = -math.huge }
end

function DashModes.tap(st, key, now, window)
	local double = st.key == key and now - st.at <= (window or DashConfig.doubleTap.windowSeconds)
	if double then
		st.key, st.at = nil, -math.huge
	else
		st.key, st.at = key, now
	end
	return double
end

return DashModes
