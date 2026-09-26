-- 대시 서버 판정(21-2 [2]). SkillServer.server.lua의 돌진형(관통돌진·백스텝샷)과 같은 신뢰
-- 모델이다 - 클라는 "대시하겠다"만 보내고, 쿨다운·방향·도착점(담장 차단)·피해 감소는 전부
-- 여기서 정한다. 실제 이동은 결과를 받은 클라(DashInput.client.lua)가 자기 캐릭터를
-- 트윈한다(그 클라가 캐릭터의 네트워크 소유자라 서버가 CFrame을 밀어넣으면 위치가 튄다 -
-- SkillServer 상단 주석과 같은 이유).
--
-- 방향: 조이스틱/WASD 이동 방향(Humanoid.MoveDirection, 소유 클라에서 복제된다)이 있으면
-- 그쪽, 서 있으면 바라보는 방향. 클라가 방향 벡터를 따로 보내지 않는다 - 서버가 이미
-- 갖고 있는 값을 쓴다(AimPoint처럼 "클라가 보낸 방향을 그대로 믿지 않는다").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DashConfig = require(ReplicatedStorage.Shared.data.DashConfig)
local PlayerProfile = require(script.Parent.PlayerProfile)
local PlayerState = require(script.Parent.PlayerState)
local DashEndpoint = require(script.Parent.DashEndpoint)

local dashRequest = Instance.new("RemoteEvent")
dashRequest.Name = "DashRequest"
dashRequest.Parent = ReplicatedStorage

-- { ok=true, cooldownSeconds, startPosition, endPosition, durationSeconds } 또는
-- { ok=false, reason } - SkillCastResult의 kind="dash"와 같은 모양이라 클라 재생 코드가
-- 같은 형태를 쓴다. SkillSlots.client.lua도 이 이벤트로 대시 슬롯 링을 서버 상태에 맞춘다.
local dashResult = Instance.new("RemoteEvent")
dashResult.Name = "DashResult"
dashResult.Parent = ReplicatedStorage

local lastDashTick = {} -- [Player] = os.clock()

dashRequest.OnServerEvent:Connect(function(player)
	if not PlayerProfile.getClassId(player) then
		return -- 직업 미선택·로드 전 - 헛동작(AttackServer와 같은 원칙)
	end
	-- 29-1(PRD 20.73 [2-8] A-2): 잡힌 동안엔 대시도 못 쓴다.
	if PlayerState.isTrapped(player) then
		dashResult:FireClient(player, { ok = false, reason = "trapped" })
		return
	end

	local now = os.clock()
	local last = lastDashTick[player]
	if last and now - last < DashConfig.cooldownSeconds then
		dashResult:FireClient(player, { ok = false, reason = "cooldown" })
		return
	end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not rootPart or not humanoid or (PlayerState.getHp(player) or 0) <= 0 then
		return
	end

	-- M1-3: 물속 대시 불가(MovementConfig.water.dashInWater) - 쿨다운을 쓰지 않는다
	if not require(ReplicatedStorage.Shared.data.MovementConfig).water.dashInWater and require(script.Parent.WorldHazards).inWater(rootPart.Position) then
		dashResult:FireClient(player, { ok = false, reason = "water" })
		return
	end

	local move = humanoid.MoveDirection
	local flat = Vector3.new(move.X, 0, move.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z)
	end
	if flat.Magnitude < 1e-3 then
		return
	end
	local direction = flat.Unit

	lastDashTick[player] = now
	local startPos = rootPart.Position
	local endPos = DashEndpoint.compute(player, startPos, direction, DashConfig.rangeStuds)

	-- PRD 5.4 "대시 중 피격 데미지 50% 감소" - 대검 회전베기와 같은 통로(PlayerState).
	PlayerState.setIncomingDamageMultiplierUntil(player, DashConfig.incomingDamageMultiplier, DashConfig.durationSeconds, "dash")

	dashResult:FireClient(player, {
		ok = true,
		cooldownSeconds = DashConfig.cooldownSeconds,
		startPosition = startPos,
		endPosition = endPos,
		durationSeconds = DashConfig.durationSeconds,
	})
end)

Players.PlayerRemoving:Connect(function(player)
	lastDashTick[player] = nil
end)

print("[forge-game] DashServer 로드됨 - 대시(LeftShift/모바일 버튼) 판정 활성")
