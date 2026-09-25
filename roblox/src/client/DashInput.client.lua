-- 대시 입력(21-2 [2]) - PC LeftShift + 모바일 HUD 대시 버튼(SkillSlots.client.lua가 쏘는
-- SkillSlotTapped "dash"). 판정·도착점은 서버(DashServer.server.lua)가 정하고, 여기는
-- 요청을 보내고 결과(도착점)를 SkillInput.client.lua의 kind="dash"와 똑같이 재생한다.
-- 쿨다운 링은 SkillSlots가 두 채널(로컬 낙관 신호 SkillCastLocal + 서버 DashResult)로
-- 맞춘다 - Q/E와 같은 구조라 새 채널을 만들지 않는다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local DashConfig = require(ReplicatedStorage.Shared.data.DashConfig)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local UIManager = require(script.Parent.UIManager)
local SkillEffects = require(script.Parent.SkillEffects)

local dashRequest = ReplicatedStorage:WaitForChild("DashRequest")
local dashResult = ReplicatedStorage:WaitForChild("DashResult")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local skillSlotsGui = playerGui:WaitForChild("SkillSlotsGui")
local localCastSignal = skillSlotsGui:WaitForChild("SkillCastLocal")
local slotTapped = skillSlotsGui:WaitForChild("SkillSlotTapped")

local localCooldownUntil = 0

local function requestDash()
	-- 18-1 [3] 모달 차단 - 창이 열려 있으면 대시가 안 나간다(지시).
	if UIManager.isInputBlocked() then
		return
	end
	if os.clock() < localCooldownUntil then
		return
	end
	local classId = player:GetAttribute("ClassId")
	if not classId or classId == "" then
		return
	end
	-- G2a: 한 체공에 공중대시와 이단점프 중 하나만(DoubleJumpInput이 착지하면 "AirMoveUsed"를 지운다). 막히면 쿨다운도 안 쓴다.
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local state = humanoid and humanoid:GetState()
	if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then -- 리뷰: 상태로 본다(요철에서 잠깐 Air인 걸 공중으로 세면 다음 점프의 2단이 막힌다)
		if character:GetAttribute("AirMoveUsed") then
			return
		end
		character:SetAttribute("AirMoveUsed", "dash")
	end
	localCooldownUntil = os.clock() + DashConfig.cooldownSeconds
	localCastSignal:Fire("dash", DashConfig.cooldownSeconds)
	dashRequest:FireServer()
end

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then
		return
	end
	if input.KeyCode == Enum.KeyCode.LeftShift then
		requestDash()
	end
end)

slotTapped.Event:Connect(function(slotId)
	if slotId == "dash" then
		requestDash()
	end
end)

dashResult.OnClientEvent:Connect(function(data)
	if not data.ok then
		localCooldownUntil = 0
		return
	end
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if rootPart then
		-- 회전은 건드리지 않고 위치만 옮긴다(SkillInput의 백스텝샷과 같은 이유 - 옆·뒤로
		-- 대시할 때 캐릭터가 홱 돌면 어색하다). Y는 서버가 준 도착점 그대로(시작점과 같은
		-- 높이) - 공중에서 눌러도 수평으로 미끄러진다.
		--
		-- 21-3 공중 대시(지시 - "점프+대시로 체공을 늘려 줄넘기 패턴을 돕는다"): 트윈이 CFrame을
		-- 매 프레임 덮어쓰는 0.3초 동안 높이는 유지되지만 물리 속도엔 중력이 계속 쌓인다 -
		-- 그대로 두면 트윈이 끝나는 순간 쌓인 낙하 속도로 곤두박질쳐 "체공 연장"이 아니라
		-- "순간 낙하"가 된다. 그래서 대시가 끝나는 순간 속도를 0으로 되돌려 그 높이에서 다시
		-- 자연 낙하하게 한다(정점에서 대시하면 체공 0.54 → 0.27+0.3+0.27 ≈ 0.84초). 캐릭터
		-- 물리는 이 클라가 소유하므로 여기서 바꿔도 서버와 어긋나지 않는다. 지면 대시엔 영향이
		-- 없다(이미 속도 0 근처).
		local currentRotation = rootPart.CFrame - rootPart.CFrame.Position
		local tween = TweenService:Create(rootPart, TweenInfo.new(data.durationSeconds, Enum.EasingStyle.Linear), {
			CFrame = currentRotation + data.endPosition,
		})
		tween.Completed:Connect(function()
			if rootPart.Parent then
				rootPart.AssemblyLinearVelocity = Vector3.zero
			end
		end)
		tween:Play()
	end
	local classId = player:GetAttribute("ClassId")
	local color = (classId and classId ~= "" and UIColors.classAccent[classId]) or UIColors.ember
	SkillEffects.dashAfterimage(data.startPosition, data.endPosition, color, data.durationSeconds)
end)
