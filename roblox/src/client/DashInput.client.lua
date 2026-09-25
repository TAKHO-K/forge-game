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
local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local UIManager = require(script.Parent.UIManager)
local SkillEffects = require(script.Parent.SkillEffects)
local AirMotion = require(script.Parent.AirMotion)

local dashRequest = ReplicatedStorage:WaitForChild("DashRequest")
local dashResult = ReplicatedStorage:WaitForChild("DashResult")
local airMoveFx = ReplicatedStorage:WaitForChild("AirMoveFx")

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
	-- M1-0: 공중대시는 한 체공에 1회 - 공중 점프와는 어느 순서로든 섞는다(DoubleJumpInput이 착지하면 "AirDashUsed"를 지운다). 막히면 쿨다운도 안 쓴다.
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local state = humanoid and humanoid:GetState()
	if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then -- 리뷰(G2a): 상태로 본다(요철에서 잠깐 Air인 걸 공중으로 세지 않게)
		if character:GetAttribute("AirDashUsed") then
			return
		end
		character:SetAttribute("AirDashUsed", true)
		character:SetAttribute("AirDashUntil", os.clock() + DashConfig.durationSeconds + MovementConfig.airJump.dashPendingSeconds) -- 리뷰 5: 결과가 오기 전(왕복)부터 공중 점프를 막는다 - 결과가 오면 정확한 끝 시각으로 덮는다
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
		local character = player.Character
		if character then -- 리뷰 4: 서버가 거절하면 이 체공의 공중대시도 돌려준다
			character:SetAttribute("AirDashUsed", nil)
			character:SetAttribute("AirDashUntil", nil)
		end
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
		-- M1-0: 트윈 동안은 공중 점프를 받지 않는다(끝나며 속도 0으로 되돌려 충전만 날아간다) · 앞으로 기울이는 모션(남에게는 서버 중계)
		character:SetAttribute("AirDashUntil", os.clock() + data.durationSeconds)
		AirMotion.play(character, "lean", data.durationSeconds)
		airMoveFx:FireServer("lean")
	end
	local classId = player:GetAttribute("ClassId")
	local color = (classId and classId ~= "" and UIColors.classAccent[classId]) or UIColors.ember
	SkillEffects.dashAfterimage(data.startPosition, data.endPosition, color, data.durationSeconds)
end)
