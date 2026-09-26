-- 이동 보조(M1-0).
--   ① 공중 점프 · 대시 모션 중계(AirMoveFx): 모션은 클라가 루트 관절 C0로 그려서 복제되지 않는다 - 입력한 클라가 kind를 보내면 다른 사람들에게 (그 사람, kind)로 다시 보낸다.
--      그리기 신호일 뿐 판정 · 상태는 없다. kind는 두 가지만 받고, relayMinGapSeconds보다 잦으면 버린다.
--   ③ MV1: 서버 체공 상태(AirState) · 낙하(FallServer - FallLanded) · 활강 상태(GlideState → Character Attribute Gliding - 모든 클라가 글라이더를 그린다) ·
--      태초 장갑 붙잡기(LedgeClimb - 서버가 모서리를 광선으로 다시 확인하고 HeightGuard 허가를 준다 = 올라서기를 합법 동작으로 등록).
--   ② 로블록스 기본 Shift Lock을 끈다(DevEnableMouseLock) - 기본 키가 LeftShift라 대시와 겹친다. 시점 고정은 자체 구현(client/ShiftLock.client.lua · LeftControl).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)
local MoveRules = require(ReplicatedStorage.Shared.MoveRules)
local AirState = require(script.Parent.AirState)
local FallServer = require(script.Parent.FallServer)
local HeightGuard = require(script.Parent.HeightGuard)
local PlayerProfile = require(script.Parent.PlayerProfile)
local PlayerState = require(script.Parent.PlayerState)
local PlayerMotionData = require(ReplicatedStorage.Shared.data.PlayerMotionData)

AirState.start()
FallServer.start()

local KINDS = { flip = true, lean = true, dash = true } -- W1: dash = 대시 무기 자세(표시만)

local airMoveFx = Instance.new("RemoteEvent")
airMoveFx.Name = "AirMoveFx"
airMoveFx.Parent = ReplicatedStorage

local lastRelayAt = {} -- [Player] = { [kind] = os.clock() } - 종류별(점프 직후 대시 기울임이 먹히지 않게)

airMoveFx.OnServerEvent:Connect(function(player, kind)
	if not KINDS[kind] then
		return
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local now = os.clock()
	local last = lastRelayAt[player] or {}
	lastRelayAt[player] = last
	if now - (last[kind] or -math.huge) < MovementConfig.airMotion.relayMinGapSeconds then
		return
	end
	last[kind] = now
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			airMoveFx:FireClient(other, player, kind)
		end
	end
end)

-- ── W1 넘어짐 → 일어나기 ──
-- 클라(넉백 · 회오리 · 붕괴 잠금 뒤 착지)가 알리면: 서버가 건 보스 발사(HeightGuard.grantLaunch)가 최근에 있었을 때만(발사 1건당 1회 소비 - W1 리뷰 1)
-- 일어나는 동안 무적(PlayerMotionData.getup.invulnSeconds · 출처 "getup")을 주고 남에게 모션을 중계한다. 강제 이동 기록이 없으면 무적 · 중계 없음(클라 모션만).
local playerGetup = Instance.new("RemoteEvent")
playerGetup.Name = "PlayerGetup"
playerGetup.Parent = ReplicatedStorage
local lastGetupAt = {}
local lastGetupStatus = {} -- 검증 훅
local function handleGetup(player)
	local G = PlayerMotionData.getup
	local now = os.clock()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		lastGetupStatus[player] = "dead"
		return "dead"
	end
	if now - (lastGetupAt[player] or -math.huge) < G.minGapSeconds then
		lastGetupStatus[player] = "gap"
		return "gap"
	end
	if not HeightGuard.consumeForcedLaunch(player, G.serverWindowSeconds, now) then
		lastGetupStatus[player] = "not_forced"
		return "not_forced"
	end
	lastGetupAt[player] = now
	PlayerState.setInvulnerableUntil(player, G.invulnSeconds, "getup")
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			airMoveFx:FireClient(other, player, "getup")
		end
	end
	lastGetupStatus[player] = "ok"
	return "ok"
end
playerGetup.OnServerEvent:Connect(handleGetup)
if RunService:IsStudio() then -- 검증 훅(W1(나)): 서버 execute_luau → ServerStorage.W1GetupHook:Invoke(player) = 상태 문자열
	local hook = Instance.new("BindableFunction")
	hook.Name = "W1GetupHook"
	hook.OnInvoke = function(player, reset)
		if reset then
			lastGetupAt[player] = nil
		end
		return handleGetup(player)
	end
	hook.Parent = game:GetService("ServerStorage")
end

-- ── MV1 활강 상태 ──
local glideState = Instance.new("RemoteEvent")
glideState.Name = "GlideState"
glideState.Parent = ReplicatedStorage
local glideOnAt = {} -- [Player] = os.clock()
local glideLastAt = {} -- 리뷰 4: 요청 간격(표시 스팸 방지)

glideState.OnServerEvent:Connect(function(player, on)
	local now = os.clock()
	if now - (glideLastAt[player] or -math.huge) < 0.15 then
		return
	end
	glideLastAt[player] = now
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	if on == true and MoveRules.tierOf(player).glide then
		glideOnAt[player] = os.clock()
		character:SetAttribute("Gliding", true)
	else
		glideOnAt[player] = nil
		character:SetAttribute("Gliding", nil)
	end
end)

-- 서버가 땅을 본 뒤에도 켜져 있으면 끈다(클라가 끄는 신호를 놓친 경우 - 켠 직후 0.5초는 서버 착지 판정 지연이라 기다린다)
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for player, at in pairs(glideOnAt) do
		if now - at > 0.5 and not AirState.session(player) then
			glideOnAt[player] = nil
			if player.Character then
				player.Character:SetAttribute("Gliding", nil)
			end
		end
	end
end)

-- ── MV1 태초 장갑 붙잡기(올라서기 = 합법 동작) ──
local ledgeClimb = Instance.new("RemoteEvent")
ledgeClimb.Name = "LedgeClimb"
ledgeClimb.Parent = ReplicatedStorage
local LEDGE = MovementConfig.ledgeGrab
local lastLedgeAt = {}
local ledgeParams = RaycastParams.new()
ledgeParams.FilterType = Enum.RaycastFilterType.Exclude
ledgeParams.RespectCanCollide = true -- 리뷰 2: 비충돌 파트(투명 구역 볼륨 등)를 모서리로 인정하지 않는다

-- 서버가 모서리 윗면을 찾는다: 클라가 보낸 점(XZ)이 서버가 본 루트에서 수평 pointSlackStuds 안이면, 그 점의 윗면 높이 + 여유에서 아래로.
-- 높이 기준 = 마지막 지면(HeightGuard supportY - 없으면 지금 발). 서버가 보는 루트는 복제 지연만큼 늦어(0.25초에 수 ~ 20 stud) 지금 발로 재면 모서리 아래(벽 안)에서 광선이 시작했다(MV1 실측 - 거절 mismatch).
local function ledgeTopFor(character, root, point)
	ledgeParams.FilterDescendantsInstances = { character }
	local feetY = root.Position.Y - MovementConfig.rootAboveFeetStuds
	if Vector3.new(point.X - root.Position.X, 0, point.Z - root.Position.Z).Magnitude > LEDGE.pointSlackStuds then
		return nil, feetY
	end
	local from = Vector3.new(point.X, point.Y + LEDGE.serverTolerance + 1, point.Z)
	local hit = Workspace:Raycast(from, Vector3.new(0, -(LEDGE.serverTolerance * 2 + 2), 0), ledgeParams)
	return hit and hit.Position.Y, feetY
end

-- 반환 = "ok" | 거절 사유(검증 MV1(나)가 직접 부른다).
local function handleLedge(player, ledgePoint, wallDir)
	local now = os.clock()
	if now - (lastLedgeAt[player] or -math.huge) < LEDGE.requestGapSeconds then
		return "throttled"
	end
	lastLedgeAt[player] = now
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or typeof(wallDir) ~= "Vector3" or typeof(ledgePoint) ~= "Vector3" or not PlayerProfile.hasLedgeGrab(player) then
		return "no_gloves"
	end
	local flat = Vector3.new(wallDir.X, 0, wallDir.Z)
	if flat.Magnitude < 0.5 then
		return "bad_dir"
	end
	local session = AirState.session(player) -- 리뷰 2: 지금 공중일 때만(땅에서 직전 체공의 몫을 쓰지 못하게)
	if not session then
		return "not_air"
	elseif session.ledgeUsed then
		return "used"
	end
	local topY, feetY = ledgeTopFor(character, root, ledgePoint)
	local guard = HeightGuard.getState(player)
	local ok, why = MoveRules.ledgeClimbValid(ledgePoint.Y, topY, (guard and guard.supportY) or feetY)
	if not ok then
		return why
	end
	session.ledgeUsed = true
	HeightGuard.grant(player, topY + LEDGE.permitMarginStuds, LEDGE.permitSeconds, "ledge")
	return "ok"
end
ledgeClimb.OnServerEvent:Connect(function(player, ledgePoint, wallDir)
	local result = handleLedge(player, ledgePoint, wallDir)
	if result ~= "ok" and result ~= "throttled" then
		print(("[forge-game] 붙잡기 거절: %s - %s"):format(player.Name, result))
	end
end)
if RunService:IsStudio() then -- 검증 훅(MV1(나) - 서버 검증이 같은 판정을 부른다)
	local hook = Instance.new("BindableFunction")
	hook.Name = "LedgeClimbHook"
	hook.OnInvoke = handleLedge
	hook.Parent = game:GetService("ServerStorage")
end

local function onPlayer(player)
	player.DevEnableMouseLock = false
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayer(player)
end
Players.PlayerRemoving:Connect(function(player)
	lastRelayAt[player] = nil
	glideOnAt[player] = nil
	glideLastAt[player] = nil
	lastLedgeAt[player] = nil
	lastGetupAt[player] = nil
	lastGetupStatus[player] = nil
end)
