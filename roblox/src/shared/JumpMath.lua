-- 이동 계산(G2a · M1-0) - 순수 함수. 클라 공중 점프 · 서버 높이 검증 · 검증 · 이동 수치 표(movement-metrics.md)가 같은 식을 읽는다. 수치 = MovementConfig.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)

local JumpMath = {}

local function g()
	return MovementConfig.gravity
end

-- 1단 발 최고 높이. bonus = 점프 높이 +% 합(0.1 = +10%) - 상한에서 자른다. M1-0: 보스 아레나도 같은 값(MovementConfig 주석).
function JumpMath.jumpHeight(bonus)
	return MovementConfig.jumpHeightStuds * (1 + math.clamp(bonus or 0, 0, MovementConfig.jumpHeightBonusCap))
end

-- 공중 점프 한 번이 지금 높이에서 올려 주는 높이(M1-0 스택형 - 상한 없음).
function JumpMath.airJumpRise(h1)
	return (h1 or MovementConfig.jumpHeightStuds) * MovementConfig.airJump.heightFraction
end

-- 한 체공의 최대 발 높이(이륙 지면 기준) = 1단 + 공중 점프 전부를 정점마다 눌렀을 때. 공중대시는 높이를 붙잡기만 한다(더하지 않는다).
function JumpMath.maxReachStuds(h1, charges)
	h1 = h1 or MovementConfig.jumpHeightStuds
	return h1 + (charges or MovementConfig.airJump.charges) * JumpMath.airJumpRise(h1)
end

-- 높이 h만큼 오르는 위쪽 속도.
function JumpMath.upSpeed(h)
	return math.sqrt(2 * g() * math.max(h, 0))
end

-- 한 체공 궤적(식으로 - 적분 없음). events = { "jump" | "dash", ... }(순서대로). fractions[i] = 그 이벤트를 누르는 높이 = 착지 높이 + (지금 궤적 정점 − 착지 높이) × f
-- (하강 중 - 1이면 정점. 정점이 착지 높이보다 낮으면 정점에서). 공중 점프 = 위 속도를 max(지금, 공중 점프 속도)로 · 대시 = dashSeconds 동안 높이 고정 뒤 속도 0(DashInput 21-3).
-- 반환: 체공(초 - landY에 내려앉을 때까지), 발이 aboveY보다 높았던 시간(초 - aboveY를 줬을 때).
function JumpMath.airTrajectory(h1, events, fractions, dashSeconds, landY, aboveY)
	h1 = h1 or MovementConfig.jumpHeightStuds
	landY = landY or 0
	local gv = g()
	local u2 = JumpMath.upSpeed(JumpMath.airJumpRise(h1))
	local t, y, v, above = 0, 0, JumpMath.upSpeed(h1), 0
	-- y0에서 속도 v0로 dt 동안 포물선일 때 aboveY 위에 있던 시간
	local function aboveTime(y0, v0, dt)
		if not aboveY then
			return 0
		end
		local disc = v0 * v0 + 2 * gv * (y0 - aboveY)
		if disc <= 0 then
			return 0
		end
		local r = math.sqrt(disc)
		return math.max(0, math.min(dt, (v0 + r) / gv) - math.max(0, (v0 - r) / gv))
	end
	for i, kind in ipairs(events) do
		local apex = v > 0 and y + v * v / (2 * gv) or y
		local target = apex <= landY and apex or landY + (apex - landY) * fractions[i]
		local rise = v > 0 and v / gv or 0
		local fall = math.sqrt(2 * math.max(apex - target, 0) / gv)
		above += aboveTime(y, v, rise + fall)
		t += rise + fall
		y, v = target, -gv * fall
		if kind == "jump" then
			v = math.max(v, u2)
		else
			if aboveY and y > aboveY then
				above += dashSeconds
			end
			t += dashSeconds
			v = 0
		end
	end
	local disc = v * v + 2 * gv * (y - landY)
	if disc < 0 then
		return nil, nil
	end
	local s = (v + math.sqrt(disc)) / gv
	above += aboveTime(y, v, s)
	return t + s, above
end

-- 한 체공 최대: 공중 점프 airJumps번 + 공중대시(dashSeconds - nil이면 안 씀)를 어떤 순서 · 어떤 높이에서 누르든 가장 긴 체공(초). 격자 탐색이라 검증 · 표 계산용(매 프레임 쓰지 않는다).
-- landY = 착지 높이(높은 단에 내려앉는 간격 표). aboveY를 주면 체공 대신 "발이 aboveY 위에 있던 시간"의 최대(보스 판정 층 위에 머무는 시간).
function JumpMath.maxAirSeconds(h1, airJumps, dashSeconds, landY, aboveY, steps)
	steps = steps or 24
	local base = {}
	for _ = 1, airJumps or 0 do
		table.insert(base, "jump")
	end
	local orders = { base }
	if dashSeconds then
		orders = {}
		for at = 1, #base + 1 do
			local order = table.clone(base)
			table.insert(order, at, "dash")
			table.insert(orders, order)
		end
	end
	local best = -1
	for _, order in ipairs(orders) do
		local fractions = table.create(#order, 0)
		local function visit(k)
			if k > #order then
				local total, above = JumpMath.airTrajectory(h1, order, fractions, dashSeconds or 0, landY, aboveY)
				local value = aboveY and above or total
				if value and value > best then
					best = value
				end
				return
			end
			for i = 0, steps do
				fractions[k] = i / steps
				visit(k + 1)
			end
		end
		visit(1)
	end
	return best
end

-- 넉백(launch) 포물선 체공: 최고 높이 h로 떴다가 같은 높이로(BossStormView.launch - 2v ÷ g).
function JumpMath.launchAirSeconds(heightStuds)
	return 2 * JumpMath.upSpeed(math.max(heightStuds or 0, 0.5)) / g()
end

-- 걷기 배율(신발 + 신속 합 → 1 + 합, 상한 MovementConfig.moveSpeedMaxMultiplier). 공격 속도 배율(PlayerCombat.getSpeedMultiplier)과 따로 - 공속은 상한 없음.
function JumpMath.moveSpeedMultiplier(speedPercentBonus)
	return math.min(1 + math.max(speedPercentBonus or 0, 0), MovementConfig.moveSpeedMaxMultiplier)
end

-- 서버 높이 검증 허용치: 마지막 지면 대비 발이 이보다 높으면 위반(M1-0 - 점프력 상한 + 공중 점프 전부의 최대 도달 + 여유).
function JumpMath.heightGuardAllowance()
	return JumpMath.maxReachStuds(JumpMath.jumpHeight(MovementConfig.jumpHeightBonusCap)) + MovementConfig.heightGuard.toleranceStuds
end

return JumpMath
