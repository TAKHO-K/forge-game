-- 이단점프(G2a - D0 결정 3 B 상한형 · 사용자 확정): 공중에서 점프 버튼을 한 번 더 누르면 세로 속도만 바꿔 다시 뜬다. 입력은 UserInputService.JumpRequest 하나 -
-- PC Space · 게임패드 · 폰 기본 점프 버튼이 모두 이 신호를 낸다(폰에 버튼을 더하지 않는다). 수치 = MovementConfig · 식 = JumpMath.
--   - 2단 오름 = 1단 × 비율, 단 발이 이륙 지면 + 1단 높이를 넘지 않게 줄인다(높이 불변식 그대로 · 체공만 는다). 못 오를 만큼(정점 근처)이면 누름을 쓰지 않는다.
--   - 한 체공에 이단점프와 공중대시 중 하나만: 캐릭터 Attribute "AirMoveUsed"("jump" · "dash" - 이 클라에서만 쓰는 값, 복제 안 됨)를 DashInput과 같이 본다. 착지하면 지운다.
--   - 금지: 넉백(PlatformStand) 받은 뒤 착지까지 · 구조물이 무너져 떨어지는 동안 · 잡힘 · 끼임(루트 Anchored) · 죽음. 플레이어 기절 상태는 코드에 없다(생기면 여기 추가).
--   - ChangeState(Jumping)은 쓰지 않는다(엔진이 1단 속도를 다시 넣어 상한이 깨진다). 상태는 Freefall 그대로라 서버 isAirborne도 공중으로 읽는다.
-- 구조물 붕괴 낙하(G2a B5)도 여기서 한다 - 캐릭터 물리는 이 클라가 소유한다(서버는 떨어질 사람에게만 dropSpeedStuds를 실어 보낸다).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)
local JumpMath = require(ReplicatedStorage.Shared.JumpMath)

local player = Players.LocalPlayer
local cfg = MovementConfig.doubleJump

local character, humanoid, root
local airborne = false
local takeoffFeetY = 0
local airStartedAt = 0
local locked = false -- 넉백 · 무너짐 낙하 뒤 착지까지
local lastRequestAt = -math.huge

local GROUNDED = {
	[Enum.HumanoidStateType.Landed] = true, [Enum.HumanoidStateType.Running] = true, [Enum.HumanoidStateType.RunningNoPhysics] = true,
	[Enum.HumanoidStateType.Climbing] = true, [Enum.HumanoidStateType.Swimming] = true, [Enum.HumanoidStateType.Seated] = true,
}
local AIR = { [Enum.HumanoidStateType.Jumping] = true, [Enum.HumanoidStateType.Freefall] = true }

local function feetY()
	return root.Position.Y - MovementConfig.rootAboveFeetStuds
end

local function onLanded()
	airborne = false
	if not humanoid.PlatformStand then
		locked = false
	end
	character:SetAttribute("AirMoveUsed", nil)
end

local function bind(newCharacter)
	character = newCharacter
	humanoid = newCharacter:WaitForChild("Humanoid")
	root = newCharacter:WaitForChild("HumanoidRootPart")
	airborne, locked = false, false
	humanoid.StateChanged:Connect(function(_, new)
		if GROUNDED[new] then
			onLanded()
		elseif AIR[new] and not airborne then
			if new == Enum.HumanoidStateType.Jumping and not humanoid.PlatformStand then
				locked = false -- 지면에서 새로 뛰었다(무너짐 신호가 이미 서 있던 사람에게 온 경우의 잠금이 다음 점프까지 남지 않게)
			end
			airborne = true
			airStartedAt = os.clock()
			takeoffFeetY = feetY() -- 점프면 지면, 턱에서 걸어 떨어졌으면 턱 윗면
		end
	end)
	humanoid:GetPropertyChangedSignal("PlatformStand"):Connect(function()
		if humanoid.PlatformStand then
			locked = true -- 넉백 · 회오리: 풀린 뒤에도 착지할 때까지
		end
	end)
end

UserInputService.JumpRequest:Connect(function()
	local now = os.clock()
	local gap = now - lastRequestAt
	lastRequestAt = now
	if gap < cfg.newPressGapSeconds or not character or not root or not humanoid then
		return
	end
	if not airborne or now - airStartedAt < cfg.minAirSeconds then
		return
	end
	if locked or humanoid.PlatformStand or root.Anchored or humanoid.Health <= 0 or character:GetAttribute("AirMoveUsed") then
		return
	end
	local rise = JumpMath.secondJumpRise(feetY() - takeoffFeetY, JumpMath.jumpHeight(0, player:GetAttribute("BossStage") ~= nil)) -- 점프력 옵션 출처는 아직 없다(0) · 보스전(BossStage)이면 옵션 무시
	if rise < cfg.minRiseStuds then
		return
	end
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(v.X, JumpMath.upSpeed(rise), v.Z)
	character:SetAttribute("AirMoveUsed", "jump")
end)

-- 구조물 붕괴(서버 BossArenaMap.fireBreak): 윗면에 서 있던 사람만 dropSpeedStuds가 온다 → 아래로 속도 + 이번 낙하 2단 금지.
ReplicatedStorage:WaitForChild("BossArenaObstacleBreak").OnClientEvent:Connect(function(data)
	if type(data) ~= "table" or not data.dropSpeedStuds or not root or not humanoid or humanoid.Health <= 0 or root.Anchored then
		return
	end
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(v.X, math.min(v.Y, -data.dropSpeedStuds), v.Z)
	locked = true
end)

if player.Character then
	task.spawn(bind, player.Character)
end
player.CharacterAdded:Connect(bind)
