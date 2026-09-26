-- 서버 높이 검증(G2a - D0 부록 I §5). 캐릭터 물리는 클라가 가지므로 날기 · 높이 부정은 서버가 따로 잰다. TerrainServer의 0.25초 폴링이 poll을 부른다.
--   기준 = 마지막으로 서 있던 발 높이(supportY - FloorMaterial이 Air가 아니거나 루트 아래 probeStuds 안에 무언가 있을 때). 발 − 기준 > 허용치(JumpMath.heightGuardAllowance -
--   M1-0: 점프력 상한 1단 + 공중 점프 전부의 최대 도달 + 여유 = 7.92 × 2.7 + 1 = 22.38)가 strikes번 이어지면 서 있던 자리로 되돌리고 속도 0 · 로그 · 기록 시각(flaggedAt - 그 뒤에 끝난 보스전의 리더보드 기록을 거절한다).
--   공중 점프(스택형)는 한 체공에 이 높이를 넘지 못한다(충전은 착지해야 찬다). 추방은 하지 않는다. 폴링이 정점을 놓치는 것은 괜찮다(정상 점프를 오탐하지 않는 쪽).
--   발사 허가(M1-2c - MovementConfig.permit): 점프대 · 통통 열매(LaunchPermit - 서버가 발판 위였음을 확인) · 보스 발사 패턴(grantLaunch)은 "발 최고 높이"를 받는다 - 허용 = max(평소, 허가).
--     가장 최근 허가 하나만 · 착지하면 끝 · 시간 상한 뒤엔 내려가기만. 허가 없이 같은 높이로 오르면 여전히 되돌린다.
--   예외: 붙잡힘 · 가둠 · 석상(보낸 쪽이 exempt - 높이를 서버가 고정) · 순간이동(reset - 한 폴링에 teleportResetStuds 넘게 움직여도 자동) · 루트 고정(잡힘 · 끼임) · 사망.
--   검증 체인은 캐릭터를 공중에 두는 옛 항목이 많아 debugOff로 끈다(G2a(나)만 자기 항목에서 켠다 - CharacterLevel.debugLevelGapOff와 같은 방식).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)
local JumpMath = require(ReplicatedStorage.Shared.JumpMath)

local HeightGuard = {}
HeightGuard.debugOff = false

local cfg = MovementConfig.heightGuard
local PERMIT = MovementConfig.permit
local states = {} -- [Player] = { supportY, supportPos, strikes, graceUntil, exemptUntil, lastPos, flaggedAt, reverts, permit, permits, landings }

local function stateOf(player)
	local st = states[player]
	if not st then
		st = HeightGuard.newState()
		states[player] = st
	end
	return st
end
-- 검증용 빈 상태(합성 표본)
function HeightGuard.newState()
	return { strikes = 0, graceUntil = 0, exemptUntil = 0, reverts = 0, permits = 0, landings = 0 }
end

-- 허가 한 장(순수 - 검증이 합성 상태에 준다). 가장 최근 것만 = 덮어쓴다.
function HeightGuard.grantAt(st, maxFeetY, seconds, source, now)
	st.permit = { maxFeetY = maxFeetY, issuedAt = now, expiresAt = now + seconds, source = source, airSeen = false }
	st.permits += 1
	return st.permit
end

-- 허가 진행(판정 한 번마다 - evaluate 안). 착지 · 안 쓴 허가 · 시간 상한 뒤 내려가기만.
local function stepPermit(st, sample, now)
	local permit = st.permit
	if not permit then
		return nil
	end
	if sample.grounded then
		local age = now - permit.issuedAt
		if (permit.airSeen and age >= PERMIT.landGraceSeconds) or (not permit.airSeen and age >= PERMIT.unusedSeconds) then
			st.permit = nil
			st.landings += 1
			return nil
		end
		return permit
	end
	permit.airSeen = true
	if now >= permit.expiresAt then
		if now >= permit.expiresAt + PERMIT.descendMaxSeconds then
			st.permit = nil
			return nil
		end
		-- 내려가기만: 상한 뒤 가장 낮았던 발(이번 표본 전까지) + 평소 허용 - 이번 표본으로 먼저 올리면 다시 오르기를 못 잡는다(M1-2c 첫 Play X)
		local low = permit.lowFeetY or sample.feetY
		permit.descending = true
		permit.maxFeetY = math.min(permit.maxFeetY, low + JumpMath.heightGuardAllowance())
		permit.lowFeetY = math.min(low, sample.feetY)
	end
	return permit
end

-- 판정 한 번(순수 - 검증이 합성 표본으로 부른다). sample = { feetY, pos(루트 Vector3), grounded(bool), skip(bool - 사망 · 루트 고정), probe(fn → 발 바로 아래 지면 Y 또는 nil, 없어도 됨) }.
-- 리뷰 1: 폴링(0.25초)이 짧은 착지(높은 단에 올라서자마자 다시 뜀)를 놓치면 기준이 아래층에 남는다 - 넘었을 때 지금 발 아래 지면을 찾아 그 지면 기준으로 다시 잰다.
-- 반환: "ok" | "strike" | "revert"(되돌릴 자리 = st.supportPos) | "reset"(순간이동으로 봄).
function HeightGuard.evaluate(st, sample, now)
	local moved = st.lastPos and (sample.pos - st.lastPos).Magnitude or 0
	st.lastPos = sample.pos
	if sample.skip then
		st.strikes = 0
		return "ok"
	end
	local permit = stepPermit(st, sample, now)
	-- 한 폴링에 멀리 움직임 = 순간이동으로 보고 기준을 새로(유일한 수평 이동 검사). 허가 비행 중(던지기 · 판 털기 - 초속 100 ~ 350)은 순간이동이 아니라 비행이다 - 기준을 공중으로 옮기지 않는다
	-- (서버 순간이동은 reset이 허가를 지운다).
	local flying = permit ~= nil and not permit.descending
	if (moved > cfg.teleportResetStuds and not flying) or st.supportY == nil then
		st.supportY, st.supportPos, st.strikes = sample.feetY, sample.pos, 0
		st.graceUntil = math.max(st.graceUntil, now + cfg.graceSeconds)
		return "reset"
	end
	if sample.grounded then
		st.supportY, st.supportPos, st.strikes = sample.feetY, sample.pos, 0
		return "ok"
	end
	if now < st.graceUntil or now < st.exemptUntil then
		st.strikes = 0
		return "ok"
	end
	local limit = st.supportY + JumpMath.heightGuardAllowance()
	if permit then
		limit = math.max(limit, permit.maxFeetY)
	end
	if sample.feetY <= limit then
		st.strikes = 0
		return "ok"
	end
	local groundY = sample.probe and sample.probe()
	if groundY and sample.feetY - groundY <= JumpMath.heightGuardAllowance() then
		st.supportY, st.strikes = groundY, 0 -- 되돌릴 자리(supportPos)는 실제로 서 있던 곳 그대로
		return "ok"
	end
	st.strikes += 1
	if st.strikes >= cfg.strikes then
		st.strikes = 0
		return "revert"
	end
	return "strike"
end

-- 붙잡힘 · 가둠 · 석상(서버가 높이를 고정): 서버가 보낸 순간 부른다. seconds = 붙잡는 시간.
function HeightGuard.exempt(player, seconds)
	if typeof(player) ~= "Instance" then -- 리뷰 4: 검증 스탠드인(표)은 상태를 만들지 않는다
		return
	end
	local st = stateOf(player)
	st.exemptUntil = math.max(st.exemptUntil, os.clock() + seconds + cfg.exemptExtraSeconds)
end

-- 발사 허가(점프대 · 통통 열매 - LaunchPermit가 발판 위였음을 확인한 뒤). maxFeetY = 설계 발 정점(공중 점프 몫 포함) - 여유는 여기서 더한다.
function HeightGuard.grant(player, maxFeetY, seconds, source)
	if typeof(player) ~= "Instance" then
		return nil
	end
	return HeightGuard.grantAt(stateOf(player), maxFeetY + PERMIT.marginStuds, seconds, source, os.clock())
end

-- 순수: 서버가 보낸 발사(보스 패턴)의 출발 발 높이 상한. 서 있으면 지금 발 · 공중이면 서버가 늦게 볼 수 있으니 "마지막 지면 + 평소 허용"(그보다 높을 수 없다) ·
-- 이미 허가를 받아 떠 있으면 그 허가 높이(연속으로 맞아도 앞 허가 위에서 다시 뜬다).
function HeightGuard.launchBaseFeet(st, feetY, grounded)
	local base = feetY
	if not grounded then
		base = math.max(feetY, (st.supportY or feetY) + JumpMath.heightGuardAllowance())
		if st.permit then -- 리뷰 1: 앞 허가 높이는 떠 있을 때만 잇는다(서 있으면 안 쓴 허가 1초 동안 맞을 때마다 천장이 쌓였다)
			base = math.max(base, st.permit.maxFeetY)
		end
	end
	return base
end

-- 보스 발사(넉백 · 회오리 · 널뛰기 · 프라이팬 · 던지기 · 파편 튕김): 출발 발 + 발사 높이 + 공중 점프 전부 + 여유 · 시간 상한 = 설계 체공 + bossExtraSeconds(착지하면 먼저 끝).
function HeightGuard.grantLaunch(player, riseStuds, airSeconds, source)
	if typeof(player) ~= "Instance" then
		return nil
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return nil
	end
	local st = stateOf(player)
	local base = HeightGuard.launchBaseFeet(st, root.Position.Y - MovementConfig.rootAboveFeetStuds, humanoid.FloorMaterial ~= Enum.Material.Air)
	return HeightGuard.grantAt(st, base + riseStuds + JumpMath.airJumpsOnlyStuds() + PERMIT.marginStuds, airSeconds + PERMIT.bossExtraSeconds, source, os.clock())
end

-- 서버 순간이동 뒤(복귀 · 심연 · 리스폰): 기준을 다음 폴링의 자리로 새로 잡는다(허가도 끝 - 다른 자리).
function HeightGuard.reset(player)
	if typeof(player) ~= "Instance" then
		return
	end
	local st = stateOf(player)
	st.supportY, st.lastPos, st.strikes, st.permit = nil, nil, 0, nil
	st.graceUntil = os.clock() + cfg.graceSeconds
end

-- 위반으로 되돌린 시각이 since(os.clock) 뒤에 있는가 - 리더보드가 그 보스전 시작 시각으로 묻는다.
function HeightGuard.flaggedSince(player, since)
	local st = states[player]
	return st ~= nil and st.flaggedAt ~= nil and st.flaggedAt >= since
end

function HeightGuard.getState(player)
	return states[player]
end

function HeightGuard.forget(player)
	states[player] = nil
end

local probeParams = RaycastParams.new()
probeParams.FilterType = Enum.RaycastFilterType.Exclude

-- TerrainServer 폴링(0.25초)에서 플레이어마다.
function HeightGuard.poll(player, now)
	if HeightGuard.debugOff then
		return "off"
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return "none"
	end
	local st = stateOf(player)
	local state = humanoid:GetState()
	-- M1-3: 헤엄(Swimming)은 클라가 정하는 상태라, 루트가 실제로 Terrain 물속일 때만 "서 있음"으로 친다(물이 생긴 뒤 상태 위조로 높이 검사를 우회하던 구멍: 리뷰)
	local swimming = state == Enum.HumanoidStateType.Swimming and require(script.Parent.WorldHazards).inWater(root.Position)
	local sample = {
		feetY = root.Position.Y - MovementConfig.rootAboveFeetStuds,
		pos = root.Position,
		grounded = humanoid.FloorMaterial ~= Enum.Material.Air or state == Enum.HumanoidStateType.Climbing
			or swimming or state == Enum.HumanoidStateType.Seated,
		skip = root.Anchored or humanoid.Health <= 0,
		probe = function()
			probeParams.FilterDescendantsInstances = { character }
			local hit = Workspace:Raycast(root.Position, Vector3.new(0, -(MovementConfig.rootAboveFeetStuds + JumpMath.heightGuardAllowance() + cfg.probeStuds), 0), probeParams)
			return hit and hit.Position.Y
		end,
	}
	local permitBefore = st.permit
	local verdict = HeightGuard.evaluate(st, sample, now)
	if verdict == "revert" then
		local from = root.Position
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = CFrame.new(st.supportPos) * (root.CFrame - root.CFrame.Position)
		st.lastPos = st.supportPos
		st.flaggedAt = now
		st.reverts += 1
		st.permit = nil -- 리뷰: 위반으로 되돌렸으면 남은 허가도 끝
		warn(("[forge-game] 높이 보정: %s 발 %.1f(기준 %.1f + 허용 %.2f 초과 %d회 · 허가 %s) → (%.0f, %.1f, %.0f)로 되돌림"):format(
			player.Name, from.Y - MovementConfig.rootAboveFeetStuds, st.supportY, JumpMath.heightGuardAllowance(), cfg.strikes,
			permitBefore and ("%s ≤ %.1f"):format(tostring(permitBefore.source), permitBefore.maxFeetY) or "없음", st.supportPos.X, st.supportPos.Y, st.supportPos.Z))
	end
	return verdict
end

return HeightGuard
