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
-- MV1: dashCount = 한 체공 공중 대시 횟수(없으면 dashSeconds가 있을 때 1 - 태초 신발 2단 대시 = 2). 대시를 여러 번 넣으면 순서 경우가 늘어 steps를 줄여 부른다.
function JumpMath.maxAirSeconds(h1, airJumps, dashSeconds, landY, aboveY, steps, dashCount)
	steps = steps or 24
	local base = {}
	for _ = 1, airJumps or 0 do
		table.insert(base, "jump")
	end
	local orders = { base }
	if dashSeconds then
		for _ = 1, dashCount or 1 do
			local nextOrders, seen = {}, {}
			for _, order in ipairs(orders) do
				for at = 1, #order + 1 do
					local o = table.clone(order)
					table.insert(o, at, "dash")
					local key = table.concat(o, ",")
					if not seen[key] then
						seen[key] = true
						table.insert(nextOrders, o)
					end
				end
			end
			orders = nextOrders
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

-- 발사 뒤 공중 점프 전부를 정점마다 눌렀을 때 더 오르는 높이(M1-2c 발사 허가 - 점프력 상한 포함). 1단은 빠진다(발사가 1단을 대신한다).
function JumpMath.airJumpsOnlyStuds()
	local h1 = JumpMath.jumpHeight(MovementConfig.jumpHeightBonusCap)
	return MovementConfig.airJump.charges * JumpMath.airJumpRise(h1)
end

-- 정해진 비행 시간 포물선(M1 점프대 · M1-2c): from → to를 seconds에 가는 초속도와 발 정점 상승(from 기준 - 위로 오르는 부분만).
function JumpMath.arcLaunch(from, to, seconds)
	local v = (to - from) / seconds + Vector3.new(0, g() * seconds / 2, 0)
	return v, v.Y > 0 and v.Y * v.Y / (2 * g()) or 0
end

-- 넉백(launch) 포물선 체공: 최고 높이 h로 떴다가 같은 높이로(BossStormView.launch - 2v ÷ g).
function JumpMath.launchAirSeconds(heightStuds)
	return 2 * JumpMath.upSpeed(math.max(heightStuds or 0, 0.5)) / g()
end

-- 걷기 배율(신발 + 신속 합 → 1 + 합, 상한 MovementConfig.moveSpeedMaxMultiplier). 공격 속도 배율(PlayerCombat.getSpeedMultiplier - D1-2부터 상한 ×2.5)과 따로.
function JumpMath.moveSpeedMultiplier(speedPercentBonus)
	return math.min(1 + math.max(speedPercentBonus or 0, 0), MovementConfig.moveSpeedMaxMultiplier)
end

-- 서버 높이 검증 허용치: 마지막 지면 대비 발이 이보다 높으면 위반(M1-0 - 점프력 상한 + 공중 점프 전부의 최대 도달 + 여유).
-- airJumps(선택 - S1): 해금된 공중 점프 수(MovementUnlockData 단계 - 없으면 최대 charges).
function JumpMath.heightGuardAllowance(airJumps)
	return JumpMath.maxReachStuds(JumpMath.jumpHeight(MovementConfig.jumpHeightBonusCap), airJumps) + MovementConfig.heightGuard.toleranceStuds
end

-- MV1 대시 거리: 기본 × clamp(장비 걷기 배율, 1, DashConfig.speedScaleMax) × 공중 대시 배율(환생 4 - MovementUnlockData.airDashRangeMultiplier · 지상은 1).
function JumpMath.dashRangeStuds(moveMultiplier, airMultiplier, baseStuds) -- FINAL-1 3: baseStuds = 대시 모드 기본 거리(DashModes.base - 없으면 긴 대시)
	local DashConfig = require(ReplicatedStorage.Shared.data.DashConfig)
	return (baseStuds or DashConfig.rangeStuds) * math.clamp(moveMultiplier or 1, 1, DashConfig.speedScaleMax) * (airMultiplier or 1)
end

-- MV1 한 체공 최대 수평 간격(끝에서 끝 · movement-metrics §2 식): 걷기 × (체공 − 대시 시간 합) + 대시 거리 합. opts = { walk, airJumps, dashes, dashStuds, rise, steps }.
-- C3 0-2 opts.coyote = true: 코요테 타임을 끝까지 쓴 점프(발판 끝을 지나 coyoteSeconds 동안 걸으며 떨어진 뒤 1단) - 걸은 거리 + 낮아진 이륙점만큼 더 멀리.
function JumpMath.coyoteDropStuds()
	local t = MovementConfig.airJump.coyoteSeconds
	return 0.5 * g() * t * t
end
function JumpMath.maxGapStuds(opts)
	local DashConfig = require(ReplicatedStorage.Shared.data.DashConfig)
	local dashes = opts.dashes or 0
	local dashSeconds = dashes > 0 and DashConfig.durationSeconds or nil
	local drop = opts.coyote and JumpMath.coyoteDropStuds() or 0
	local walk = opts.walk or MovementConfig.walkSpeedStuds
	local air = JumpMath.maxAirSeconds(MovementConfig.jumpHeightStuds, opts.airJumps or 0, dashSeconds, math.max(opts.rise or 0, 0) + drop, nil, opts.steps or (dashes > 1 and 12 or 24), dashes > 0 and dashes or nil)
	if not air or air <= 0 then
		return -1
	end
	return walk * (air - dashes * DashConfig.durationSeconds) + dashes * (opts.dashStuds or DashConfig.rangeStuds) + (opts.coyote and walk * MovementConfig.airJump.coyoteSeconds or 0)
end

-- MV1 "못 넘는 틈"(평지 · 끝에서 끝): 한 체공 최대 간격 + 여유 gapMarginStuds를 올림(v2 = 42.6 → 46과 같은 식).
JumpMath.gapMarginStuds = 3
function JumpMath.unjumpableGapStuds(opts)
	local o = table.clone(opts)
	o.coyote = true -- C3 0-2: 못 넘는 틈 = 코요테 타임을 끝까지 쓴 점프까지(52 → 53 · 74 → 76 · 123 → 125)
	return math.ceil(JumpMath.maxGapStuds(o) + JumpMath.gapMarginStuds)
end

-- MV1 오를 수 있는 가장 높은 단(발 기준): 1단 + 공중 점프 전부(점프력 옵션 상한 포함) + 태초 장갑 붙잡기(모서리가 손 높이 MovementConfig.ledgeGrab.maxLedgeAboveFeet 안이면 올라선다).
function JumpMath.maxClimbStuds(airJumps, withLedgeGrab, jumpBonus)
	local h1 = JumpMath.jumpHeight(jumpBonus or 0)
	return h1 + (airJumps or 0) * JumpMath.airJumpRise(h1) + (withLedgeGrab and MovementConfig.ledgeGrab.maxLedgeAboveFeet or 0)
end

-- MV1 낙하: 높이 h를 자유 낙하한 착지 속도.
function JumpMath.fallSpeedFromHeight(h)
	return math.sqrt(2 * g() * math.max(h or 0, 0))
end

return JumpMath
