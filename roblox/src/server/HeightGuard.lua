-- 서버 높이 검증(G2a - D0 부록 I §5). 캐릭터 물리는 클라가 가지므로 날기 · 높이 부정은 서버가 따로 잰다. TerrainServer의 0.25초 폴링이 poll을 부른다.
--   기준 = 마지막으로 서 있던 발 높이(supportY - FloorMaterial이 Air가 아니거나 루트 아래 probeStuds 안에 무언가 있을 때). 발 − 기준 > 허용치(JumpMath.heightGuardAllowance -
--   M1-0: 점프력 상한 1단 + 공중 점프 전부의 최대 도달 + 여유 = 7.92 × 2.7 + 1 = 22.38)가 strikes번 이어지면 서 있던 자리로 되돌리고 속도 0 · 로그 · 기록 시각(flaggedAt - 그 뒤에 끝난 보스전의 리더보드 기록을 거절한다).
--   공중 점프(스택형)는 한 체공에 이 높이를 넘지 못한다(충전은 착지해야 찬다). 추방은 하지 않는다. 폴링이 정점을 놓치는 것은 괜찮다(정상 점프를 오탐하지 않는 쪽).
--   예외: 넉백 · 회오리 · 파편 튕김(보낸 쪽이 exempt) · 순간이동(reset - 한 폴링에 teleportResetStuds 넘게 움직여도 자동) · 루트 고정(잡힘 · 끼임) · 사망.
--   검증 체인은 캐릭터를 공중에 두는 옛 항목이 많아 debugOff로 끈다(G2a(나)만 자기 항목에서 켠다 - CharacterLevel.debugLevelGapOff와 같은 방식).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)
local JumpMath = require(ReplicatedStorage.Shared.JumpMath)

local HeightGuard = {}
HeightGuard.debugOff = false

local cfg = MovementConfig.heightGuard
local states = {} -- [Player] = { supportY, supportPos, strikes, graceUntil, exemptUntil, lastPos, flaggedAt, reverts }

local function stateOf(player)
	local st = states[player]
	if not st then
		st = { strikes = 0, graceUntil = 0, exemptUntil = 0, reverts = 0 }
		states[player] = st
	end
	return st
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
	if moved > cfg.teleportResetStuds or st.supportY == nil then
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
	if sample.feetY - st.supportY <= JumpMath.heightGuardAllowance() then
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

-- 넉백 · 회오리 · 파편: 서버가 보낸 순간 부른다. seconds = 체공(+ 붙잡는 시간).
function HeightGuard.exempt(player, seconds)
	if typeof(player) ~= "Instance" then -- 리뷰 4: 검증 스탠드인(표)은 상태를 만들지 않는다
		return
	end
	local st = stateOf(player)
	st.exemptUntil = math.max(st.exemptUntil, os.clock() + seconds + cfg.exemptExtraSeconds)
end

-- 서버 순간이동 뒤(복귀 · 심연 · 리스폰): 기준을 다음 폴링의 자리로 새로 잡는다.
function HeightGuard.reset(player)
	if typeof(player) ~= "Instance" then
		return
	end
	local st = stateOf(player)
	st.supportY, st.lastPos, st.strikes = nil, nil, 0
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
	local sample = {
		feetY = root.Position.Y - MovementConfig.rootAboveFeetStuds,
		pos = root.Position,
		grounded = humanoid.FloorMaterial ~= Enum.Material.Air or state == Enum.HumanoidStateType.Climbing
			or state == Enum.HumanoidStateType.Swimming or state == Enum.HumanoidStateType.Seated,
		skip = root.Anchored or humanoid.Health <= 0,
		probe = function()
			probeParams.FilterDescendantsInstances = { character }
			local hit = Workspace:Raycast(root.Position, Vector3.new(0, -(MovementConfig.rootAboveFeetStuds + JumpMath.heightGuardAllowance() + cfg.probeStuds), 0), probeParams)
			return hit and hit.Position.Y
		end,
	}
	local verdict = HeightGuard.evaluate(st, sample, now)
	if verdict == "revert" then
		local from = root.Position
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = CFrame.new(st.supportPos) * (root.CFrame - root.CFrame.Position)
		st.lastPos = st.supportPos
		st.flaggedAt = now
		st.reverts += 1
		warn(("[forge-game] 높이 보정: %s 발 %.1f(기준 %.1f + 허용 %.2f 초과 %d회) → (%.0f, %.1f, %.0f)로 되돌림"):format(
			player.Name, from.Y - MovementConfig.rootAboveFeetStuds, st.supportY, JumpMath.heightGuardAllowance(), cfg.strikes, st.supportPos.X, st.supportPos.Y, st.supportPos.Z))
	end
	return verdict
end

return HeightGuard
