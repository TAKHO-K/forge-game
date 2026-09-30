-- A2-M1 공용 이징(보스 · 캐릭터 · 연출 공통 - 순수 함수). t = 0 ~ 1 → 0 ~ 1(오버슈트 곡선은 잠깐 1을 넘는다).
-- 애니메이션 12원칙 쪽 이름: 예비 동작(anticipation) = "in"류 · 동작 = "strike"(빠르지만 시작 속도가 0에서 이어짐 - 튐 없음) · 여운 = "back" / "overshoot" · 안착 = "settle"(스프링).
--   in · out · inout = 세제곱 · sine = 사인 inout · quadIn · quadOut = 제곱 · expoOut = 지수 감속
--   back = 살짝 지나쳐 돌아옴(옛 BossMotion "back" 그대로 - c 1.6) · overshoot = 더 크게 지나침(c 2.4)
--   strike = 짧은 가속(앞 18%) → 강한 감속: 시작 속도 0 · 끝 속도 0 - 한 프레임에 속도가 튀지 않는 "빠른 한 방"
--   settle = 감쇠 스프링(한 번 지나쳤다가 작게 되돌아 1에 멈춤 · 끝 값 정확히 1)
local Easing = {}

local function clamp01(t)
	return t < 0 and 0 or (t > 1 and 1 or t)
end
Easing.clamp01 = clamp01

local F = {}
F["in"] = function(t)
	return t * t * t
end
F.out = function(t)
	return 1 - (1 - t) ^ 3
end
F.inout = function(t)
	return t < 0.5 and 4 * t * t * t or 1 - (-2 * t + 2) ^ 3 / 2
end
F.sine = function(t)
	return 0.5 - 0.5 * math.cos(math.pi * t)
end
F.quadIn = function(t)
	return t * t
end
F.quadOut = function(t)
	return 1 - (1 - t) * (1 - t)
end
F.expoOut = function(t)
	return t >= 1 and 1 or 1 - 2 ^ (-10 * t)
end
F.back = function(t)
	local c = 1.6
	return 1 + (c + 1) * (t - 1) ^ 3 + c * (t - 1) ^ 2
end
F.overshoot = function(t)
	local c = 2.4
	return 1 + (c + 1) * (t - 1) ^ 3 + c * (t - 1) ^ 2
end
-- strike: out 세제곱에 시간 휨 s(t)를 넣는다 - 앞 r 구간은 s = t²/(2r)(속도 0 → 1로 가속) · 뒤는 직선 · 끝 값 1로 정규화.
--   f(0) = 0 · f'(0) = 0(한 프레임 속도 튐 없음) · f(1) = 1 · f'(1) = 0 · 최대 속도는 t = r 부근(out과 거의 같은 "빠른 한 방").
local STRIKE_R = 0.15
local STRIKE_NORM = 1 - STRIKE_R / 2
F.strike = function(t)
	local s = (t < STRIKE_R and t * t / (2 * STRIKE_R) or t - STRIKE_R / 2) / STRIKE_NORM
	return 1 - (1 - s) ^ 3
end
-- settle: 정지 상태에서 출발하는 2차 감쇠 스프링의 계단 응답 y = 1 − e^(−k t)(cos ω t + (k/ω) sin ω t) - 시작 속도 0 · 한 번 약 5% 지나쳤다가 1에 멈춤(끝 값 정규화).
local SETTLE_K, SETTLE_W = 5, 5.2
local function settleRaw(t)
	return 1 - math.exp(-SETTLE_K * t) * (math.cos(SETTLE_W * t) + SETTLE_K / SETTLE_W * math.sin(SETTLE_W * t))
end
local SETTLE_END = settleRaw(1)
F.settle = function(t)
	return settleRaw(t) + (1 - SETTLE_END) * t
end
Easing.curves = F

-- 이름 → 값. 모르는 이름 = inout(옛 BossMotion 기본값과 같다).
function Easing.get(kind, t)
	t = clamp01(t)
	local f = F[kind] or F.inout
	return f(t)
end

-- 검사용: 곡선의 수치 미분(시작 · 끝 속도 · 최대 속도 · 최대 가속) - 로컬 하네스 · 자동 검증이 쓴다.
function Easing.profile(kind, steps)
	steps = steps or 200
	local prev, prevV = Easing.get(kind, 0), nil
	local out = { v0 = nil, v1 = nil, vMax = 0, aMax = 0, overshoot = 0 }
	for i = 1, steps do
		local t = i / steps
		local y = Easing.get(kind, t)
		local v = (y - prev) * steps
		if i == 1 then
			out.v0 = v
		end
		if prevV then
			out.aMax = math.max(out.aMax, math.abs(v - prevV) * steps)
		end
		out.vMax = math.max(out.vMax, math.abs(v))
		out.overshoot = math.max(out.overshoot, y - 1)
		prev, prevV = y, v
	end
	out.v1 = prevV
	return out
end

return Easing
