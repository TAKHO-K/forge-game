-- 공중 점프(M1-0 - 사용자 결정: 겐지 · 한조식 스택형, 필드 · 보스 아레나 같은 규칙). 공중에서 점프 버튼을 누를 때마다 충전 1을 쓰고 지금 높이에서 더 오른다.
-- 입력은 UserInputService.JumpRequest 하나 - PC Space · 게임패드 · 폰 기본 점프 버튼이 모두 이 신호를 낸다(폰에 버튼을 더하지 않는다). 수치 = MovementConfig.airJump · 식 = JumpMath.
--   - 충전 = airJump.charges(바닥을 밟으면 다시 찬다). 공중대시는 한 체공에 1회(DashInput)이고 공중 점프와 어느 순서로든 섞는다(G2a 상한형 · 대시 택일은 폐기).
--   - 캐릭터 Attribute(이 클라에서만 쓰는 값 - 복제 안 됨): "AirJumpsLeft"(남은 충전 - AirChargeDots가 그린다) · "AirDashesUsed"(DashInput - MV1 횟수) · "AirDashUntil"(대시 트윈이 도는 동안은 점프를 받지 않는다 - 트윈이 끝나며 속도를 0으로 되돌려 충전만 날아간다).
--   - 금지: 넉백(PlatformStand) 받은 뒤 착지까지 · 구조물이 무너져 떨어지는 동안 · 잡힘 · 끼임(루트 Anchored) · 죽음. 플레이어 기절 상태는 코드에 없다(생기면 여기 추가).
--   - ChangeState(Jumping)은 쓰지 않는다(엔진이 1단 속도를 다시 넣는다). 상태는 Freefall 그대로라 서버 isAirborne도 공중으로 읽는다.
--   - MV1: 충전 = 환생 해금(MoveRules.tierOf - 환생 0 = 0 · 1 ~ 2 = 1 · 3+ = 2). 활강 중 점프 = 활강만 끈다(GlideController) · 태초 장갑 붙잡기로 매달린 중 점프 = 올라서기(LedgeGrab).
--     넉백 · 무너짐 잠금은 캐릭터 Attribute "AirLocked"로도 알린다(활강 · 낙하 판정이 읽는다 - 이 클라에서만).
--   - 모션: 앞으로 한 바퀴(AirMotion) - 남에게는 서버 중계(AirMoveFx). 남의 공중 점프 · 대시 모션도 여기서 받아 그린다.
-- 구조물 붕괴 낙하(G2a B5)도 여기서 한다 - 캐릭터 물리는 이 클라가 소유한다(서버는 떨어질 사람에게만 dropSpeedStuds를 실어 보낸다).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)
local DashConfig = require(ReplicatedStorage.Shared.data.DashConfig)
local JumpMath = require(ReplicatedStorage.Shared.JumpMath)
local AirMotion = require(script.Parent.AirMotion)
local GlideController = require(script.Parent.GlideController)
local LedgeGrab = require(script.Parent.LedgeGrab)
local MoveRules = require(ReplicatedStorage.Shared.MoveRules)
local WeaponVisual = require(script.Parent.WeaponVisual) -- W1 넘어짐 → 일어나기 · 남의 대시 자세

local player = Players.LocalPlayer
local cfg = MovementConfig.airJump
local airMoveFx = ReplicatedStorage:WaitForChild("AirMoveFx")

local character, humanoid, root
local airborne = false
local airStartedAt = 0
local locked = false -- 넉백 · 무너짐 낙하 뒤 착지까지
local lastRequestAt = -math.huge

-- MV1: 해금된 공중 점프 충전
local function unlockedCharges()
	return (MoveRules.tierOf(player)).airJumps
end

-- M1-3: 헤엄(Swimming)은 체공을 끝내지만 충전은 안 돌려준다(MovementConfig.water.rechargeInWater - 물 밖 착지에서만 찬다)
local GROUNDED = {
	[Enum.HumanoidStateType.Landed] = true, [Enum.HumanoidStateType.Running] = true, [Enum.HumanoidStateType.RunningNoPhysics] = true,
	[Enum.HumanoidStateType.Climbing] = true, [Enum.HumanoidStateType.Seated] = true,
}
local AIR = { [Enum.HumanoidStateType.Jumping] = true, [Enum.HumanoidStateType.Freefall] = true }

local playerGetup = ReplicatedStorage:WaitForChild("PlayerGetup")
local GETUP_MIN_LOCK_SECONDS = 0.3 -- W1 리뷰 2: 잠긴(넉백 · 회오리 · 붕괴) 뒤 이만큼 날아갔다 떨어진 착지만 일어나기(잠기자마자 땅에 닿은 것은 아님)
local lockedAt = -math.huge
local function onLanded()
	airborne = false
	if not humanoid.PlatformStand then
		if locked and os.clock() - lockedAt >= GETUP_MIN_LOCK_SECONDS and humanoid.Health > 0 then
			-- W1: 넉백 · 회오리 · 붕괴로 날아갔다 착지 = 넘어짐 → 일어나기(0.8초 이내 · 서버가 강제 이동 기록을 보고 무적 · 남에게 중계)
			WeaponVisual.playGetup(nil)
			playerGetup:FireServer()
		end
		locked = false
	end
	character:SetAttribute("AirJumpsLeft", unlockedCharges())
	character:SetAttribute("AirDashesUsed", nil)
	character:SetAttribute("AirLocked", nil)
end

local function bind(newCharacter)
	character = newCharacter
	humanoid = newCharacter:WaitForChild("Humanoid")
	root = newCharacter:WaitForChild("HumanoidRootPart")
	airborne, locked = false, false
	character:SetAttribute("AirJumpsLeft", unlockedCharges())
	humanoid.StateChanged:Connect(function(_, new)
		if GROUNDED[new] or (new == Enum.HumanoidStateType.Swimming and MovementConfig.water.rechargeInWater) then
			onLanded()
		elseif new == Enum.HumanoidStateType.Swimming then
			airborne = false -- 물에 들어오면 체공은 끝(물 밖으로 뛰어오르면 새 체공 - 남은 충전 그대로)
			character:SetAttribute("AirDashesUsed", nil)
		elseif AIR[new] and not airborne then
			if new == Enum.HumanoidStateType.Jumping and not humanoid.PlatformStand then
				locked = false -- 지면에서 새로 뛰었다(무너짐 신호가 이미 서 있던 사람에게 온 경우의 잠금이 다음 점프까지 남지 않게)
				character:SetAttribute("AirLocked", nil)
			end
			airborne = true
			airStartedAt = os.clock()
		end
	end)
	humanoid:GetPropertyChangedSignal("PlatformStand"):Connect(function()
		if humanoid.PlatformStand then
			if not locked then
				lockedAt = os.clock()
			end
			locked = true -- 넉백 · 회오리: 풀린 뒤에도 착지할 때까지
			character:SetAttribute("AirLocked", true)
		end
	end)
end

local function onJumpRequest()
	local now = os.clock()
	local gap = now - lastRequestAt
	lastRequestAt = now
	if gap < cfg.newPressGapSeconds or not character or not root or not humanoid then
		return
	end
	-- MV1: 매달림 중 = 올라서기 · 활강 중 = 활강만 끈다(이번 누름은 공중 점프로 쓰지 않는다)
	if LedgeGrab.isHanging() then
		LedgeGrab.climb()
		return
	end
	if GlideController.isGliding() then
		GlideController.stop("jump")
		return
	end
	if not airborne or now - airStartedAt < cfg.minAirSeconds then
		return
	end
	local left = character:GetAttribute("AirJumpsLeft") or 0
	if left <= 0 or locked or humanoid.PlatformStand or root.Anchored or humanoid.Health <= 0 or now < (character:GetAttribute("AirDashUntil") or 0) then
		return
	end
	local v = root.AssemblyLinearVelocity
	local rise = JumpMath.airJumpRise(JumpMath.jumpHeight(0)) -- 점프력 옵션 출처는 아직 없다(0)
	root.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, JumpMath.upSpeed(rise)), v.Z) -- 오르는 중 속도가 더 크면 그대로(정점을 낮추지 않는다)
	character:SetAttribute("AirJumpsLeft", left - 1)
	AirMotion.play(character, "flip", MovementConfig.airMotion.flipSeconds)
	airMoveFx:FireServer("flip")
end
UserInputService.JumpRequest:Connect(onJumpRequest)
-- 검증 훅(Studio - 이 창은 MCP 스페이스 입력이 안 먹는다): 클라 execute_luau → PlayerGui.MV1JumpHook:Invoke() = 점프 요청 한 번(공중 점프 · 활강 끄기 · 올라서기)
if game:GetService("RunService"):IsStudio() then
	local hook = Instance.new("BindableFunction")
	hook.Name = "MV1JumpHook"
	hook.OnInvoke = function()
		lastRequestAt = -math.huge
		onJumpRequest()
		return character and character:GetAttribute("AirJumpsLeft")
	end
	hook.Parent = player:WaitForChild("PlayerGui")
end

-- 남의 공중 점프 · 대시 모션(서버 중계).
airMoveFx.OnClientEvent:Connect(function(who, kind)
	local other = typeof(who) == "Instance" and who:IsA("Player") and who.Character
	if kind == "dash" then
		WeaponVisual.playDash(who, DashConfig.durationSeconds) -- W1 대시 무기 자세
	elseif kind == "getup" then
		WeaponVisual.playGetup(who) -- W1 넘어짐 → 일어나기
	elseif other then
		AirMotion.play(other, kind, kind == "flip" and MovementConfig.airMotion.flipSeconds or DashConfig.durationSeconds)
	end
end)

-- 구조물 붕괴(서버 BossArenaMap.fireBreak): 윗면에 서 있던 사람만 dropSpeedStuds가 온다 → 아래로 속도 + 이번 낙하 공중 점프 금지.
ReplicatedStorage:WaitForChild("BossArenaObstacleBreak").OnClientEvent:Connect(function(data)
	if type(data) ~= "table" or not data.dropSpeedStuds or not root or not humanoid or humanoid.Health <= 0 or root.Anchored then
		return
	end
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(v.X, math.min(v.Y, -data.dropSpeedStuds), v.Z)
	if not locked then
		lockedAt = os.clock()
	end
	locked = true
	if character then
		character:SetAttribute("AirLocked", true)
	end
end)

if player.Character then
	task.spawn(bind, player.Character)
end
player.CharacterAdded:Connect(bind)
-- MV1: 환생 해금이 바뀌면(환생 · 개발 명령) 땅에 있을 때의 충전 표시를 새 값으로
local function refreshCharges()
	if character and not airborne then
		character:SetAttribute("AirJumpsLeft", unlockedCharges())
	end
end
player:GetAttributeChangedSignal("MoveTier"):Connect(refreshCharges)
player:GetAttributeChangedSignal("MoveTierOverride"):Connect(refreshCharges)
