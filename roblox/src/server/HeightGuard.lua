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
local isStudio = game:GetService("RunService"):IsStudio()

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
-- hRate(S1 후속 0-4) = 설계 체공 동안 수평 상한(stud/s) - 보스 발사 = moveGuard.permitSpeed(400) · 점프대 = 설계 수평 속도 × padSpeedMargin · nil = 걷기 그대로(통통 열매 · 붙잡기).
function HeightGuard.grantAt(st, maxFeetY, seconds, source, now, hRate)
	local prev = st.permit
	if prev and prev.hRate and now <= prev.expiresAt then -- 리뷰 2: 날아가는 중 받은 새 허가(붙잡기 등)가 앞 허가(보스 발사 400)의 수평 상한을 끊지 않게 - 설계 체공 안이면 이어받는다
		hRate = math.max(hRate or 0, prev.hRate)
	end
	st.permit = { maxFeetY = maxFeetY, issuedAt = now, expiresAt = now + seconds, source = source, airSeen = false, hRate = hRate }
	st.permits += 1
	return st.permit
end

-- 허가 진행(판정 한 번마다 - evaluate 안). 착지 · 안 쓴 허가 · 시간 상한 뒤 내려가기만.
local function stepPermit(st, sample, now)
	local permit = st.permit
	if not permit then
		return nil
	end
	st.permitSeenAt = now -- MV1 낙하 제외(강제 체공): 허가가 살아 있던 마지막 판정 시각
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
		permit.maxFeetY = math.min(permit.maxFeetY, low + (st.allowance or JumpMath.heightGuardAllowance()))
		permit.lowFeetY = math.min(low, sample.feetY)
	end
	return permit
end

-- 판정 한 번(순수 - 검증이 합성 표본으로 부른다). sample = { feetY, pos(루트 Vector3), grounded(bool), skip(bool - 사망 · 루트 고정), probe(fn → 발 바로 아래 지면 Y 또는 nil, 없어도 됨) }.
-- 리뷰 1: 폴링(0.25초)이 짧은 착지(높은 단에 올라서자마자 다시 뜀)를 놓치면 기준이 아래층에 남는다 - 넘었을 때 지금 발 아래 지면을 찾아 그 지면 기준으로 다시 잰다.
-- 반환: "ok" | "strike" | "revert"(되돌릴 자리 = st.supportPos) | "reset"(순간이동으로 봄).
function HeightGuard.evaluate(st, sample, now)
	st.lastPos = sample.pos
	if sample.skip then
		st.strikes = 0
		return "ok"
	end
	local permit = stepPermit(st, sample, now)
	-- S1: 옛 "한 폴링에 teleportResetStuds 넘게 움직임 = 순간이동으로 인정"은 삭제 - 서버 순간이동은 reset(supportY = nil)으로만 기준을 새로 잡는다.
	--   표시 없는 큰 수평 이동 = evaluateHorizontal이 되돌린다 · 표시 없는 큰 위 이동 = 아래 높이 검사가 되돌린다(아래로 빠른 낙하는 그대로 허용).
	if st.supportY == nil then
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
	local allowance = st.allowance or JumpMath.heightGuardAllowance() -- S1: 해금 단계별(환생 0 = 공중 점프 0 → 8.92) · 합성 상태는 최대
	local limit = st.supportY + allowance
	if permit then
		limit = math.max(limit, permit.maxFeetY)
	end
	if sample.feetY <= limit then
		st.strikes = 0
		return "ok"
	end
	local groundY = sample.probe and sample.probe()
	if groundY and sample.feetY - groundY <= allowance then
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

-- ─────────────────────────── S1 수평 이동 검사 ───────────────────────────
-- 순수 한 번(검증이 합성 표본으로 부른다). ctx = { rate(지금 합법 최대 수평 속도 stud/s), exempt(bool - 검사 안 함) }.
-- 반환 "ok" | "hrevert"(되돌릴 자리 = st.hGood). 대시 · 밀림 허가는 st.hBank(grantDash · grantBurst)에서 쓴다.
local MG = MovementConfig.moveGuard
function HeightGuard.evaluateHorizontal(st, sample, now, ctx)
	st.hBank = st.hBank or {}
	st.hViolations = st.hViolations or 0
	local pos = sample.pos
	if sample.skip or ctx.exempt then
		st.hGood, st.hAt, st.bucket = pos, now, nil
		return "ok"
	end
	-- 리뷰 3: 서버 순간이동(reset) 뒤 유예는 "자유 이동 창"이 아니다 - 도착 자리(hAnchor = reset 순간 서버 루트) 근처만 새 기준으로 받는다.
	--   지연으로 옛 자리 표본이 끼면 도착 자리로 되돌린다(위반으로 세지 않는다 - 정상 순간이동의 지연).
	if ctx.grace and st.hAnchor then
		local near = Vector3.new(pos.X - st.hAnchor.X, 0, pos.Z - st.hAnchor.Z).Magnitude <= ctx.rate * MG.bucketSeconds + MG.slackStuds
		if near then
			st.hGood, st.hAt, st.bucket = pos, now, nil
			return "ok"
		end
		st.hGood = st.hAnchor
		st.hAt = now
		st.hGraceReverts = (st.hGraceReverts or 0) + 1
		return "hrevert"
	end
	if not st.hGood then
		st.hGood, st.hAt, st.bucket = pos, now, nil
		return "ok"
	end
	local dt = math.clamp(now - (st.hAt or now), 0, 1)
	st.hAt = now
	local cap = ctx.rate * MG.bucketSeconds + MG.slackStuds
	st.bucket = math.min(cap, (st.bucket or cap) + ctx.rate * dt)
	local bank = 0
	for i = #st.hBank, 1, -1 do
		if now > st.hBank[i].untilAt then
			table.remove(st.hBank, i)
		else
			bank += st.hBank[i].studs
		end
	end
	local d = Vector3.new(pos.X - st.hGood.X, 0, pos.Z - st.hGood.Z).Magnitude
	if d <= st.bucket then
		st.bucket -= d
		st.hGood = pos
		return "ok"
	end
	local need = d - st.bucket
	if need <= bank + 1e-6 then
		for _, b in ipairs(st.hBank) do -- 먼저 받은 허가부터
			local use = math.min(b.studs, need)
			b.studs -= use
			need -= use
		end
		st.bucket = 0
		st.hGood = pos
		return "ok"
	end
	st.hViolations += 1
	st.hLastViolation = { at = now, studs = d, allowed = st.bucket + bank, rate = ctx.rate }
	return "hrevert"
end

-- 순수: 허가 한 장 쌓기(대시 · 밀림) - 검증이 합성 상태에 준다.
function HeightGuard.bankAt(st, studs, seconds, now)
	st.hBank = st.hBank or {}
	table.insert(st.hBank, { studs = studs, untilAt = now + seconds })
end

-- 서버가 준 대시(DashServer - 거리 = 서버 계산) · 2단 대시는 두 번 부른다.
function HeightGuard.grantDash(player, rangeStuds)
	if typeof(player) ~= "Instance" then
		return
	end
	HeightGuard.bankAt(stateOf(player), rangeStuds * MG.dashMargin, MG.dashWindowSeconds, os.clock())
end

-- 서버가 보낸 밀림(선인장 - WorldHazards): 속도 × 시간 만큼.
function HeightGuard.grantBurst(player, studs)
	if typeof(player) ~= "Instance" then
		return
	end
	HeightGuard.bankAt(stateOf(player), studs, MG.burstWindowSeconds, os.clock())
end

-- 지금 합법 최대 수평 속도(합법 이동 목록 중 켜진 것) · 검사 제외 여부.
function HeightGuard.horizontalContext(st, character, root, humanoid, now)
	local walk = MovementConfig.walkSpeedStuds * MovementConfig.moveSpeedMaxMultiplier * MG.walkMargin
	local rate = walk
	if character:GetAttribute("Gliding") then
		rate = math.max(rate, MovementConfig.glide.forwardSpeed * MG.glideMargin)
	end
	if humanoid:GetState() == Enum.HumanoidStateType.Swimming or require(script.Parent.WorldHazards).inWater(root.Position) then
		rate = math.max(rate, walk + MG.flowMaxStuds)
	end
	if st.permit and st.permit.hRate and now <= st.permit.expiresAt then -- 리뷰 4: 설계 체공 안만(내려가기 단계 = 걷기 · 활강 속도) · S1 후속 0-4: 허가마다 수평 상한
		rate = math.max(rate, st.permit.hRate)
	end
	return { rate = rate, exempt = now < st.exemptUntil, grace = now < st.graceUntil }
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
-- hSpeed = 설계 수평 속도(점프대 포물선 - 없으면 걷기 그대로) · 여유 = moveGuard.padSpeedMargin.
function HeightGuard.grant(player, maxFeetY, seconds, source, hSpeed)
	if typeof(player) ~= "Instance" then
		return nil
	end
	return HeightGuard.grantAt(stateOf(player), maxFeetY + PERMIT.marginStuds, seconds, source, os.clock(), hSpeed and hSpeed * MG.padSpeedMargin or nil)
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
	st.forcedLaunch = { at = os.clock(), used = false, source = source } -- W1 리뷰 1: 서버가 건 발사만 따로(일어나기 무적 = 1건당 1회 소비)
	local base = HeightGuard.launchBaseFeet(st, root.Position.Y - MovementConfig.rootAboveFeetStuds, humanoid.FloorMaterial ~= Enum.Material.Air)
	return HeightGuard.grantAt(st, base + riseStuds + JumpMath.airJumpsOnlyStuds() + PERMIT.marginStuds, airSeconds + PERMIT.bossExtraSeconds, source, os.clock(), MG.permitSpeed)
end

-- 서버 순간이동 뒤(복귀 · 심연 · 리스폰): 기준을 다음 폴링의 자리로 새로 잡는다(허가도 끝 - 다른 자리).
function HeightGuard.reset(player)
	if typeof(player) ~= "Instance" then
		return
	end
	local st = stateOf(player)
	st.supportY, st.lastPos, st.strikes, st.permit = nil, nil, 0, nil
	st.hGood, st.bucket = nil, nil -- S1: 수평 기준도 새 자리에서
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	st.hAnchor = root and root.Position or nil -- 리뷰 3: 유예 동안 받을 도착 자리(서버가 방금 옮긴 루트)
	st.graceUntil = os.clock() + cfg.graceSeconds
end

-- MV1 낙하 제외: 지금 발사 허가 · 예외(붙잡힘 · 넉백 등)가 있거나 graceSeconds 안에 끝났는가(착지 보고는 서버 착지 판정보다 늦게 온다).
function HeightGuard.recentlyForced(player, graceSeconds, now)
	local st = states[player]
	if not st then
		return false
	end
	now = now or os.clock()
	return st.permit ~= nil or now - (st.permitSeenAt or -math.huge) <= graceSeconds or now <= st.exemptUntil + graceSeconds
end

-- W1 일어나기 무적: 서버가 건 보스 발사(grantLaunch - 넉백 · 회오리 · 던지기 · 판 털기)가 window초 안에 있었고 아직 안 썼으면 소비하고 true.
-- 플레이어가 요청한 허가(점프대 · 통통 열매 · 붙잡기)와 붙잡힘 예외(exempt)는 넘어짐이 아니라 세지 않는다(리뷰 1 - 반복 무적 방지).
function HeightGuard.consumeForcedLaunch(player, window, now)
	local st = states[player]
	local f = st and st.forcedLaunch
	now = now or os.clock()
	if not f or f.used or now - f.at > window then
		return false
	end
	f.used = true
	return true
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
local climbParams = OverlapParams.new()
climbParams.FilterType = Enum.RaycastFilterType.Exclude

-- M1-4 사다리: "오르는 중(Climbing)"은 클라가 정하는 상태라, 루트 곁(cfg.climbBox)에 실제 오를 것(TrussPart · Climbable 표시)이 있을 때만 "서 있음"으로 친다
-- (사다리 · 나무 덩굴 사다리 - 상태 위조로 높이 검사를 우회하지 못하게 · 헤엄과 같은 원칙).
function HeightGuard.nearClimbable(character, root)
	climbParams.FilterDescendantsInstances = { character }
	for _, part in ipairs(Workspace:GetPartBoundsInBox(root.CFrame, cfg.climbBox, climbParams)) do
		if part:IsA("TrussPart") or part:GetAttribute("Climbable") then
			return true
		end
	end
	return false
end

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
		grounded = humanoid.FloorMaterial ~= Enum.Material.Air or (state == Enum.HumanoidStateType.Climbing and HeightGuard.nearClimbable(character, root))
			or swimming or state == Enum.HumanoidStateType.Seated,
		skip = root.Anchored or humanoid.Health <= 0,
		probe = function()
			probeParams.FilterDescendantsInstances = { character }
			local hit = Workspace:Raycast(root.Position, Vector3.new(0, -(MovementConfig.rootAboveFeetStuds + JumpMath.heightGuardAllowance() + cfg.probeStuds), 0), probeParams)
			return hit and hit.Position.Y
		end,
	}
	local permitBefore = st.permit
	-- S1: 높이 허용치 = 해금된 공중 점프 수 기준(미해금 공중 점프 = 클라 물리라 요청이 없다 - 서버는 높이로 잡는다)
	st.allowance = JumpMath.heightGuardAllowance(require(ReplicatedStorage.Shared.MoveRules).tierOf(player).airJumps)
	-- S1 수평 이동(먼저 - 되돌리면 이번 높이 판정은 건너뛴다)
	local hv = HeightGuard.evaluateHorizontal(st, sample, now, HeightGuard.horizontalContext(st, character, root, humanoid, now))
	if hv == "hrevert" and now < st.graceUntil then -- 유예 중 = 도착 자리로 되돌림만(위반 아님 · 로그 없음)
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = CFrame.new(st.hGood) * (root.CFrame - root.CFrame.Position)
		return "hsnap"
	end
	if hv == "hrevert" then
		local from = root.Position
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = CFrame.new(st.hGood) * (root.CFrame - root.CFrame.Position)
		st.lastPos = st.hGood
		st.hReverts = (st.hReverts or 0) + 1
		if isStudio then
			player:SetAttribute("S1HReverts", st.hReverts) -- 검증 계측(Studio)
		end
		local v = st.hLastViolation
		if (st.hWarnedAt or -math.huge) < now - 5 then -- 로그만(5초에 한 번 - 킥 · 자동 제재 없음)
			st.hWarnedAt = now
			warn(("[forge-game] 이동 보정: %s 수평 %.1f stud(허용 %.1f · 합법 속도 %.0f/s) → (%.0f, %.1f, %.0f)로 되돌림 · 누적 %d"):format(
				player.Name, v and v.studs or (from - st.hGood).Magnitude, v and v.allowed or 0, v and v.rate or 0, st.hGood.X, st.hGood.Y, st.hGood.Z, st.hViolations or 0))
		end
		return "hrevert"
	end
	local verdict = HeightGuard.evaluate(st, sample, now)
	if st.trace then -- 검증 계측(G2aVerify가 켤 때만): 판정 · 발 − 기준 · 유예/예외 남은 시간
		table.insert(st.trace, ("%s(%.1f/%s/g%.1f/e%.1f)"):format(verdict, sample.feetY - (st.supportY or sample.feetY), sample.grounded and "G" or "A",
			math.max(0, st.graceUntil - now), math.max(0, st.exemptUntil - now)))
	end
	if verdict == "revert" then
		local from = root.Position
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = CFrame.new(st.supportPos) * (root.CFrame - root.CFrame.Position)
		st.lastPos = st.supportPos
		st.flaggedAt = now
		st.reverts += 1
		st.permit = nil -- 리뷰: 위반으로 되돌렸으면 남은 허가도 끝
		warn(("[forge-game] 높이 보정: %s 발 %.1f(기준 %.1f + 허용 %.2f 초과 %d회 · 허가 %s) → (%.0f, %.1f, %.0f)로 되돌림"):format(
			player.Name, from.Y - MovementConfig.rootAboveFeetStuds, st.supportY, st.allowance or JumpMath.heightGuardAllowance(), cfg.strikes,
			permitBefore and ("%s ≤ %.1f"):format(tostring(permitBefore.source), permitBefore.maxFeetY) or "없음", st.supportPos.X, st.supportPos.Y, st.supportPos.Z))
	end
	return verdict
end

return HeightGuard
