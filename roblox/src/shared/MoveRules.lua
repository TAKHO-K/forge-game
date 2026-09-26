-- MV1 이동 규칙(순수 함수 - 서버 DashServer · AirState · FallServer · 클라 DashInput · GlideController · 검증 MV1(가)가 같은 식을 쓴다). 수치 = DashConfig · MovementConfig · MovementUnlockData.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DashConfig = require(ReplicatedStorage.Shared.data.DashConfig)
local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)
local MovementUnlockData = require(ReplicatedStorage.Shared.data.MovementUnlockData)

local MoveRules = {}

-- 사람의 해금 행: Player Attribute MoveTier(서버 PlayerProfile - 계정 최대 환생) · 개발 명령 덮어쓰기 MoveTierOverride(서버만 쓴다 · 저장 안 됨). 반환 행, 단계.
function MoveRules.tierOf(player)
	local override = player and player:GetAttribute("MoveTierOverride")
	return MovementUnlockData.tierFor(override or (player and player:GetAttribute("MoveTier")) or 0)
end

-- ── 대시 키: 짧게 = 대시 · 길게(공중 · 활강 해금) = 활강 ──
-- 누른 채 heldSeconds가 지났고 아직 안 뗐을 때(released = false) / 뗀 순간(released = true)의 결과: "dash" | "glide" | "wait"(아직 모름).
-- 지상에서 누르면 누르는 즉시 대시다(길게 눌러도 대시 - 부르는 쪽이 지상이면 이 함수를 안 거친다).
function MoveRules.classifyPress(heldSeconds, released, canGlide)
	local hold = DashConfig.input.glideHoldSeconds
	if released then
		if heldSeconds < hold or not canGlide then
			return "dash"
		end
		return "glide" -- 경계를 넘긴 뒤 뗐다(이미 활강이 켜졌어야 한다 - 늦은 프레임 대비)
	end
	if heldSeconds >= hold then
		return canGlide and "glide" or "dash"
	end
	return "wait"
end

-- ── 대시 충전(태초 신발 2단 대시) ──
-- st = { cooldownUntil, secondUntil(두 번째 대시 창 끝), lastAt }. 반환 ok, reason("cooldown" | "busy"), 두 번째였는가.
function MoveRules.newDashState()
	return { cooldownUntil = -math.huge, secondUntil = -math.huge, lastAt = -math.huge }
end

function MoveRules.tryDash(st, now, charges)
	if now - st.lastAt < DashConfig.durationSeconds then
		return false, "busy" -- 앞 대시가 아직 끝나지 않았다(트윈이 겹치지 않게)
	end
	if (charges or 1) >= 2 and now <= st.secondUntil then
		st.secondUntil = -math.huge
		st.cooldownUntil = now + DashConfig.cooldownSeconds -- 쿨다운은 두 번째를 쓴 순간부터
		st.lastAt = now
		return true, nil, true
	end
	if now < st.cooldownUntil then
		return false, "cooldown"
	end
	st.cooldownUntil = now + DashConfig.cooldownSeconds -- 창을 놓치면 이 쿨다운 그대로
	st.secondUntil = (charges or 1) >= 2 and now + DashConfig.primordialShoes.chainWindowSeconds or -math.huge
	st.lastAt = now
	return true, nil, false
end

-- 한 체공 공중 대시 횟수(태초 신발 = 2단 대시 충전만큼).
function MoveRules.airDashesAllowed(primordialShoes)
	return primordialShoes and DashConfig.primordialShoes.charges or 1
end

-- ── 공중 공격 예산(한 체공) ──
function MoveRules.airAttackBudget(tierRow, airDashesUsed)
	if not tierRow or not tierRow.airAttack then
		return 0
	end
	local A = MovementUnlockData.airAttack
	return tierRow.airJumps * A.perUnlockedJump + (airDashesUsed or 0) * A.perAirDash
end

-- ── 활강 ──
function MoveRules.glideGaugeSeconds(tierRow)
	return MovementConfig.glide.gaugeSeconds + ((tierRow and tierRow.glideSecondsBonus) or 0)
end

-- 게이지를 다 쓴 활강의 수평 거리 · 잃는 높이.
function MoveRules.glideReach(tierRow)
	local seconds = MoveRules.glideGaugeSeconds(tierRow)
	return MovementConfig.glide.forwardSpeed * seconds, MovementConfig.glide.descentSpeed * seconds, seconds
end

-- 게이지 한 스텝: 활강 중이면 줄고 · 서 있으면 refillSeconds에 가득 · 그 밖(공중)은 그대로. 반환 = 새 게이지(초).
function MoveRules.stepGauge(gauge, maxSeconds, dt, gliding, grounded)
	if gliding then
		return math.max(gauge - dt, 0)
	elseif grounded then
		return math.min(gauge + dt * maxSeconds / MovementConfig.glide.refillSeconds, maxSeconds)
	end
	return gauge
end

-- ── 낙하 ──
-- 착지 수직 속도(양수 = 아래로) → { kind = "none" | "damage" | "knockdown", fraction(최대 체력 비율) }.
function MoveRules.fallOutcome(speed)
	local F = MovementConfig.fall
	speed = math.clamp(tonumber(speed) or 0, 0, F.reportMaxSpeed)
	if speed ~= speed or speed < F.dangerSpeed then
		return { kind = "none", fraction = 0 }
	elseif speed >= F.lethalSpeed then
		return { kind = "knockdown", fraction = 1 }
	end
	local t = (speed - F.dangerSpeed) / (F.lethalSpeed - F.dangerSpeed)
	return { kind = "damage", fraction = F.damageMinFraction + (F.damageMaxFraction - F.damageMinFraction) * t }
end

-- 제외 사유(없으면 nil). ctx = { inBoss, inTree, permitRecent, exemptRecent, fromLadder, inWater }.
function MoveRules.fallExcluded(ctx)
	if ctx.inBoss then
		return "boss"
	elseif ctx.inTree then
		return "tree"
	elseif ctx.permitRecent then
		return "permit"
	elseif ctx.exemptRecent then
		return "exempt"
	elseif ctx.fromLadder then
		return "ladder"
	elseif ctx.inWater then
		return "water"
	end
	return nil
end

-- ── 붙잡기(태초 장갑) 서버 확인 ──
-- 클라가 보낸 모서리 윗면 높이(ledgeY)와 서버가 그 점 위에서 광선으로 찾은 윗면(serverTopY)이 serverTolerance 안이고,
-- 모서리가 "마지막 지면(baseY - HeightGuard 기준) + 한 체공 최대 도달(높이 허용치) + 손 높이" 안인가 - 서버가 보는 지금 발은 복제 지연(0.25)만큼 늦어 쓰지 않는다(MV1 실측).
function MoveRules.ledgeClimbValid(ledgeY, serverTopY, baseY)
	local L = MovementConfig.ledgeGrab
	if type(ledgeY) ~= "number" or ledgeY ~= ledgeY or not serverTopY then
		return false, "no_ledge"
	end
	if math.abs(ledgeY - serverTopY) > L.serverTolerance then
		return false, "mismatch"
	end
	if serverTopY - baseY > require(ReplicatedStorage.Shared.JumpMath).heightGuardAllowance() + L.maxLedgeAboveFeet + L.serverTolerance then
		return false, "too_high"
	end
	return true
end

return MoveRules
