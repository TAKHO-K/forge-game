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
		-- 높이) - 공중에서 눌러도 수평으로 미끄러지고 그 뒤 중력이 마저 떨어뜨린다.
		local currentRotation = rootPart.CFrame - rootPart.CFrame.Position
		TweenService:Create(rootPart, TweenInfo.new(data.durationSeconds, Enum.EasingStyle.Linear), {
			CFrame = currentRotation + data.endPosition,
		}):Play()
	end
	local classId = player:GetAttribute("ClassId")
	local color = (classId and classId ~= "" and UIColors.classAccent[classId]) or UIColors.ember
	SkillEffects.dashAfterimage(data.startPosition, data.endPosition, color, data.durationSeconds)
end)
