-- MV1 서버 체공 상태(사람마다 - 매 Heartbeat). 서버가 보는 지면 판정(HeightGuard.poll과 같은 기준: FloorMaterial · 사다리 곁 오르기 · 물 · 앉음)으로
-- 땅 → 공중이 바뀌는 순간 새 "체공 세션"을 연다. 세션 = { id, since, takeoffPos(마지막으로 선 자리 = 낙하 쓰러짐 부활 자리), fromLadder, airDashes, airAttacks, ledgeUsed }.
--   공중 공격 예산(MoveRules.airAttackBudget) · 공중 대시 횟수 · 붙잡기 1회 · 강공격 스택 초기화(AttackServer)가 이 세션을 읽는다.
--   지연: 서버가 보는 착지는 클라보다 늦다 - 착지 직후 공격은 클라가 "지상"으로 보내고(AttackServer가 받는다), 서버가 오래(airSanitySeconds) 공중으로 본 요청만 공중으로 센다.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local AirState = {}

AirState.debugPaused = false
local states = {} -- [Player] = { grounded, groundPos, session, sessionCount }

-- 서버가 이 사람을 공중으로 보는 동안 "공중 공격" 판정을 강제하는 체공 길이(클라 신호 없이도 - 긴 활강 · 낙하 중 지상 신호 위조 방지).
AirState.airSanitySeconds = 0.6 -- 리뷰 3: 1단 점프 체공(0.54) 정도 - 그보다 오래 공중이면 지상 신고라도 공중으로 센다(단, 발밑 가까이 = 막 착지는 지상 - AttackServer)
-- 이만큼 이어진 체공만 "떴다"로 센다(강공격 스택 초기화 - 요철 · 계단에서 잠깐 Air인 것은 세지 않는다).
AirState.takeoffMinSeconds = 0.15

local function newSession(st, now, fromLadder)
	st.sessionCount += 1
	st.session = { id = st.sessionCount, since = now, takeoffPos = st.groundPos, fromLadder = fromLadder, airDashes = 0, airAttacks = 0, ledgeUsed = false }
end

function AirState.stateOf(player)
	local st = states[player]
	if not st then
		st = { grounded = true, groundPos = nil, session = nil, sessionCount = 0, takeoffCount = 0 }
		states[player] = st
	end
	return st
end

-- 순수 한 스텝(검증이 합성 표본으로 부른다): grounded(bool) · pos(Vector3) · climbing(bool - 떨어지기 직전 상태가 오르기였나) · gliding(bool - 활강 중).
-- S1 낙하 궤적: 세션마다 서버가 본 루트 최고점 peakY(새로 오르기 시작하면(공중 점프 · 발사) · 활강 중이면 다시 잰다) · 착지 높이 landY.
function AirState.step(st, grounded, pos, climbing, now, gliding)
	if grounded then
		if st.session then
			st.session.endedAt = now
			st.session.landY = pos.Y
			st.lastSession = st.session -- 착지 보고(낙하 판정)가 서버 착지보다 늦게 와도 그 체공을 읽는다
			if AirState.onLanded then
				AirState.onLanded(st, st.session)
			end
		end
		st.grounded = true
		st.groundPos = pos
		st.session = nil
	elseif st.grounded or not st.session then
		st.grounded = false
		newSession(st, now, st.lastClimbing == true)
	end
	st.lastClimbing = climbing
	local s = st.session
	if s then
		local y = pos.Y
		local dt = s.prevAt and math.max(now - s.prevAt, 1e-3) or nil
		local falling = dt and s.prevY and (s.prevY - y) / dt or 0
		-- 리뷰 5: 활강 = 서버 Gliding + 실제 하강이 활강 속도(5) 근처일 때만 · 다시 오름 = 떨어지던 가장 낮은 곳에서 2 넘게 올랐을 때만(0.06 올리기 · 착지 직전 Gliding 켜기로 최고점을 못 지운다)
		if not s.peakY or y > s.peakY or (gliding and falling <= 8) then
			s.peakY = y
			s.lowY = y
		else
			s.lowY = math.min(s.lowY or y, y)
			if y - s.lowY >= 2 and y < s.peakY then
				s.peakY = y -- 떨어지다 다시 오름(공중 점프 · 발사) = 새 최고점부터
				s.lowY = y
			end
		end
		s.prevY, s.prevAt = y, now
	end
	if s and not s.counted and now - s.since >= AirState.takeoffMinSeconds then
		s.counted = true
		st.takeoffCount += 1
	end
	return s
end

-- 지금 체공 세션(땅이면 nil).
function AirState.session(player)
	local st = states[player]
	return st and st.session
end

-- S1: 서버가 본 낙하 높이(최고점 − 착지 · 착지 전이면 지금 높이) → 같은 높이의 자유 낙하 착지 속도. 궤적이 없는 세션(검증 합성)은 nil.
function AirState.fallSpeedOf(session, currentY)
	if not session or not session.peakY then
		return nil
	end
	local h = session.peakY - (session.landY or currentY or session.peakY)
	return math.sqrt(2 * workspace.Gravity * math.max(h, 0)), h
end

-- 서버가 지금 공중으로 본 지 몇 초(땅이면 0).
function AirState.airborneSeconds(player, now)
	local s = AirState.session(player)
	return s and ((now or os.clock()) - s.since) or 0
end

-- 원거리 공중 정지 중인가(AttackServer가 정지 끝 시각을 적는다 - 대공 잡기 체공 · BossHandlersBR1.trackAir).
function AirState.isHovering(player, now)
	local s = AirState.session(player)
	return s ~= nil and (s.hoverUntil or 0) > (now or os.clock())
end

-- 지금 체공이 있으면 그것, 없으면 방금 끝난 체공(낙하 보고용).
function AirState.currentOrLastSession(player)
	local st = states[player]
	return st and (st.session or st.lastSession)
end

-- 공중 공격이 들어온 체공은 짧아도 "떴다"로 센다(첫 공중 공격부터 스택이 0에서 시작하게).
function AirState.markTakeoff(player)
	local st = AirState.stateOf(player)
	if st.session and not st.session.counted then
		st.session.counted = true
		st.takeoffCount += 1
	end
end

-- 뜬 횟수(강공격 스택 초기화 - takeoffMinSeconds 넘게 이어진 체공만 · 땅이면 마지막 값 그대로: 착지 뒤 첫 지상 공격도 "뜬 뒤"로 친다).
function AirState.sessionCount(player)
	return AirState.stateOf(player).takeoffCount
end

-- 이번 체공의 마지막 안전 자리(서 있던 곳) - 땅이면 지금 선 자리.
function AirState.safePosition(player)
	local st = states[player]
	if not st then
		return nil
	end
	local s = st.session or st.lastSession
	return (s and s.takeoffPos) or st.groundPos
end

-- 활강 · 붙잡기 올라서기처럼 서버가 "새 지면"을 인정할 때(올라서기 = 모서리 위를 선 자리로).
function AirState.setGround(player, pos)
	local st = AirState.stateOf(player)
	st.groundPos = pos
end

-- 서버 순간이동 뒤(복귀 · 쓰러짐 부활): 세션을 닫고 그 자리를 선 자리로.
function AirState.reset(player, pos)
	local st = AirState.stateOf(player)
	st.session, st.lastSession, st.grounded, st.groundPos = nil, nil, true, pos
end

local function groundedNow(character, humanoid, root)
	local state = humanoid:GetState()
	if humanoid.FloorMaterial ~= Enum.Material.Air or state == Enum.HumanoidStateType.Seated then
		return true, false
	end
	if state == Enum.HumanoidStateType.Climbing then
		return require(script.Parent.HeightGuard).nearClimbable(character, root), true
	end
	if state == Enum.HumanoidStateType.Swimming then
		return require(script.Parent.WorldHazards).inWater(root.Position), false
	end
	return false, false
end

-- 발밑 가까이(landingSlackStuds 안)에 땅이 있는가 - 서버가 아직 공중으로 보는 막 착지한 요청을 지상으로 받는다(리뷰 8: 긴 체공 뒤 착지 순간 공격이 거부됐다).
AirState.landingSlackStuds = 4.5
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.RespectCanCollide = true
function AirState.nearGround(player, root)
	groundParams.FilterDescendantsInstances = { player.Character }
	return workspace:Raycast(root.Position, Vector3.new(0, -(3 + AirState.landingSlackStuds), 0), groundParams) ~= nil
end

function AirState.forget(player)
	states[player] = nil
end

function AirState.start()
	RunService.Heartbeat:Connect(function()
		if AirState.debugPaused then
			return -- 검증(MV1(나))이 세션을 직접 세우는 동안
		end
		local now = os.clock()
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if humanoid and root and humanoid.Health > 0 then
				local grounded, climbing = groundedNow(character, humanoid, root)
				AirState.step(AirState.stateOf(player), grounded or root.Anchored, root.Position, climbing, now, character:GetAttribute("Gliding") == true)
				AirState.stateOf(player).player = player
			end
		end
	end)
	Players.PlayerRemoving:Connect(AirState.forget)
end


return AirState
