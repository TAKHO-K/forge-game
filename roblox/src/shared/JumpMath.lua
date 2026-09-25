-- 이동 계산(G2a) - 순수 함수. 클라 이단점프 · 서버 높이 검증 · 회피 검사기(BossSkillMath) · 검증이 같은 식을 읽는다. 수치 = MovementConfig.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)

local JumpMath = {}

local function g()
	return MovementConfig.gravity
end

-- 1단 발 최고 높이. bonus = 점프 높이 +% 합(0.1 = +10%) - 상한에서 자른다. inBossArena면 옵션을 무시한다(MovementConfig 주석).
function JumpMath.jumpHeight(bonus, inBossArena)
	if inBossArena then
		return MovementConfig.jumpHeightStuds
	end
	return MovementConfig.jumpHeightStuds * (1 + math.clamp(bonus or 0, 0, MovementConfig.jumpHeightBonusCap))
end

-- 2단이 올려 주는 높이(상한형). feetRise = 지금 발 − 이륙 지면. 1단 × 비율과 "1단 최고 높이까지 남은 높이" 중 작은 쪽(음수면 0).
function JumpMath.secondJumpRise(feetRise, h1)
	h1 = h1 or MovementConfig.jumpHeightStuds
	return math.max(0, math.min(h1 * MovementConfig.doubleJump.heightFraction, h1 - feetRise))
end

-- 높이 h만큼 오르는 위쪽 속도.
function JumpMath.upSpeed(h)
	return math.sqrt(2 * g() * math.max(h, 0))
end

-- 높이 y에서 속도 0으로 떨어져 바닥까지(초).
local function fallSeconds(y)
	return math.sqrt(2 * math.max(y, 0) / g())
end

-- 1단 + 2단 최대 체공(초). 내려오는 중 발 높이 y에서 2단을 누르는 모든 경우 중 가장 긴 것(D0 부록 I §1 - 정점이 최적이 아니다).
function JumpMath.maxDoubleJumpAirSeconds(h1)
	h1 = h1 or MovementConfig.jumpHeightStuds
	local up1 = JumpMath.upSpeed(h1) / g()
	local best = 2 * up1
	for i = 0, 400 do
		local y = h1 * i / 400
		local t = up1 + fallSeconds(h1 - y) -- 정점 → y까지 내려온 시각
		local rise = JumpMath.secondJumpRise(y, h1)
		if rise >= MovementConfig.doubleJump.minRiseStuds then
			local v2 = JumpMath.upSpeed(rise)
			t += (v2 + math.sqrt(v2 * v2 + 2 * g() * y)) / g()
			best = math.max(best, t)
		end
	end
	return best
end

-- 1단 + 공중대시 최대 체공(초). 대시는 높이를 dashSeconds 동안 붙잡고 끝나면 속도 0에서 다시 떨어진다(DashInput 21-3).
function JumpMath.maxAirDashAirSeconds(h1, dashSeconds)
	h1 = h1 or MovementConfig.jumpHeightStuds
	local up1 = JumpMath.upSpeed(h1) / g()
	local best = 2 * up1
	for i = 0, 400 do
		local y = h1 * i / 400
		best = math.max(best, up1 + fallSeconds(h1 - y) + dashSeconds + fallSeconds(y))
	end
	return best
end

-- 한 번의 체공에서 가능한 최대(이단점프와 공중대시는 둘 중 하나만 - 두 경우의 큰 쪽).
function JumpMath.maxAirSeconds(h1, dashSeconds)
	return math.max(JumpMath.maxDoubleJumpAirSeconds(h1), JumpMath.maxAirDashAirSeconds(h1, dashSeconds))
end

-- 넉백(launch) 포물선 체공: 최고 높이 h로 떴다가 같은 높이로(BossStormView.launch - 2v ÷ g).
function JumpMath.launchAirSeconds(heightStuds)
	return 2 * JumpMath.upSpeed(math.max(heightStuds or 0, 0.5)) / g()
end

-- 걷기 배율(신발 + 신속 합 → 1 + 합, 상한 MovementConfig.moveSpeedMaxMultiplier). 공격 속도 배율(PlayerCombat.getSpeedMultiplier)과 따로 - 공속은 상한 없음.
function JumpMath.moveSpeedMultiplier(speedPercentBonus)
	return math.min(1 + math.max(speedPercentBonus or 0, 0), MovementConfig.moveSpeedMaxMultiplier)
end

-- 서버 높이 검증 허용치: 마지막 지면 대비 발이 이보다 높으면 위반(점프력 상한까지 넉넉히 + 여유).
function JumpMath.heightGuardAllowance()
	return MovementConfig.jumpHeightStuds * (1 + MovementConfig.jumpHeightBonusCap) + MovementConfig.heightGuard.toleranceStuds
end

return JumpMath
