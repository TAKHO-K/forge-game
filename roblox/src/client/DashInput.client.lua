-- 대시 입력(21-2 [2]) - PC LeftShift + 모바일 HUD 대시 버튼(SkillSlots.client.lua가 쏘는
-- SkillSlotTapped "dash"). 판정·도착점은 서버(DashServer.server.lua)가 정하고, 여기는
-- 요청을 보내고 결과(도착점)를 SkillInput.client.lua의 kind="dash"와 똑같이 재생한다.
-- 쿨다운 링은 SkillSlots가 두 채널(로컬 낙관 신호 SkillCastLocal + 서버 DashResult)로
-- 맞춘다 - Q/E와 같은 구조라 새 채널을 만들지 않는다.
-- MV1: 키(폰 버튼)를 누른 시간으로 가른다(MoveRules.classifyPress) - 지상 = 누르는 즉시 대시 · 공중 = 떼면 대시 / DashConfig.input.glideHoldSeconds 넘게 누르고 있으면 활강(해금 전 · 게이지 없음이면 그때 대시).
--   활강 중 누르면 활강만 끈다. 폰 대시 버튼은 SkillSlots의 SkillSlotPress(누름 · 뗌)로 같은 판정을 탄다.
--   공중 대시 = 한 체공 MoveRules.airDashesAllowed회(태초 신발 2) · 2단 대시 = MoveRules.tryDash(로컬 예측 - 판정은 서버).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local DashConfig = require(ReplicatedStorage.Shared.data.DashConfig)
local TranscendentData = require(ReplicatedStorage.Shared.data.TranscendentData) -- C5-7b 광폭 대시 쿨
local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local UIManager = require(script.Parent.UIManager)
local SkillEffects = require(script.Parent.SkillEffects)
local AirMotion = require(script.Parent.AirMotion)
local GlideController = require(script.Parent.GlideController)
local MoveRules = require(ReplicatedStorage.Shared.MoveRules)
local WeaponVisual = require(script.Parent.WeaponVisual) -- W1 대시 무기 자세 · 일어나기 입력 버퍼

local dashRequest = ReplicatedStorage:WaitForChild("DashRequest")
local dashResult = ReplicatedStorage:WaitForChild("DashResult")
local airMoveFx = ReplicatedStorage:WaitForChild("AirMoveFx")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local skillSlotsGui = playerGui:WaitForChild("SkillSlotsGui")
local localCastSignal = skillSlotsGui:WaitForChild("SkillCastLocal")
local slotPress = skillSlotsGui:WaitForChild("SkillSlotPress")

local localDash = MoveRules.newDashState()
local pendingSecond = false

local function primordialShoes()
	local parts = player:GetAttribute("PrimordialParts")
	return type(parts) == "string" and parts:find("shoes", 1, true) ~= nil
end

local function requestDash()
	-- 18-1 [3] 모달 차단 - 창이 열려 있으면 대시가 안 나간다(지시).
	if UIManager.isInputBlocked() then
		return
	end
	if WeaponVisual.bufferInput(requestDash) then
		return -- W1: 일어나는 중 = 끝나는 순간 낸다
	end
	local classId = player:GetAttribute("ClassId")
	if not classId or classId == "" then
		return
	end
	-- M1-0: 공중대시는 한 체공에 1회(MV1: 태초 신발 2회 - "AirDashesUsed") - 공중 점프와는 어느 순서로든 섞는다(DoubleJumpInput이 착지하면 지운다). 막히면 쿨다운도 안 쓴다.
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local state = humanoid and humanoid:GetState()
	if state == Enum.HumanoidStateType.Swimming and not MovementConfig.water.dashInWater then
		return -- M1-3: 물속 대시 불가(서버도 거절) - 쿨다운을 쓰지 않는다
	end
	local charges = primordialShoes() and DashConfig.primordialShoes.charges or 1
	local airborne = state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall -- 리뷰(G2a): 상태로 본다(요철에서 잠깐 Air인 걸 공중으로 세지 않게)
	if airborne and (character:GetAttribute("AirDashesUsed") or 0) >= MoveRules.airDashesAllowed(charges >= 2) then
		return
	end
	local cooldownScale = player:GetAttribute("FrenzyActive") == true and TranscendentData.frenzy.dashCooldownScale or 1 -- C5-7b 광폭(서버와 같은 배율)
	local ok, _, second = MoveRules.tryDash(localDash, os.clock(), charges, cooldownScale)
	pendingSecond = second == true -- W3b 2단 대시 모션(결과가 오면 쓴다)
	if not ok then
		return
	end
	if airborne then
		character:SetAttribute("AirDashesUsed", (character:GetAttribute("AirDashesUsed") or 0) + 1)
		character:SetAttribute("AirDashUntil", os.clock() + DashConfig.durationSeconds + MovementConfig.airJump.dashPendingSeconds) -- 리뷰 5: 결과가 오기 전(왕복)부터 공중 점프를 막는다 - 결과가 오면 정확한 끝 시각으로 덮는다
	end
	character:SetAttribute("DashReadyAt", localDash.cooldownUntil) -- 충전 표시(AirChargeDots)가 쿨다운 중이면 공중대시 칸을 회색으로(M1-0 후속)
	character:SetAttribute("DashSecondUntil", localDash.secondUntil > os.clock() and localDash.secondUntil or nil) -- MV1 2단 대시 창
	if second or charges < 2 or localDash.secondUntil < os.clock() then
		localCastSignal:Fire("dash", DashConfig.cooldownSeconds * cooldownScale)
	end
	dashRequest:FireServer()
end

-- ── MV1 누름 · 뗌 판정 ──
local press = nil -- { at, consumed }

local function isAirborne()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local st = humanoid and humanoid:GetState()
	return st == Enum.HumanoidStateType.Jumping or st == Enum.HumanoidStateType.Freefall
end

local function onPress()
	if UIManager.isInputBlocked() then
		return
	end
	if GlideController.isGliding() then
		GlideController.stop("dash") -- 활강 중 누름 = 끄기만
		press = { consumed = true }
		return
	end
	if not isAirborne() then
		requestDash() -- 지상 = 누르는 즉시(길게 눌러도 대시)
		press = { consumed = true }
		return
	end
	press = { at = os.clock(), consumed = false }
end

local function onRelease()
	local p = press
	press = nil
	if not p or p.consumed then
		return
	end
	if MoveRules.classifyPress(os.clock() - p.at, true, false) == "dash" then
		requestDash()
	end
end

RunService.Heartbeat:Connect(function()
	local p = press
	if not p or p.consumed then
		return
	end
	local result = MoveRules.classifyPress(os.clock() - p.at, false, GlideController.canStart())
	if result == "glide" then
		p.consumed = true
		GlideController.start()
	elseif result == "dash" then
		p.consumed = true -- 활강을 못 켜는 긴 누름(해금 전 · 게이지 없음) = 그 순간 대시
		requestDash()
	end
end)

-- 검증 훅(Studio): 클라 execute_luau가 키 입력 없이 같은 누름 경로를 탄다 - Invoke("press") · Invoke("release")
if RunService:IsStudio() then
	local hook = Instance.new("BindableFunction")
	hook.Name = "MV1DashHook"
	hook.OnInvoke = function(kind)
		if kind == "press" then
			onPress()
		elseif kind == "release" then
			onRelease()
		end
		return press and (press.consumed and "consumed" or "pending") or "none"
	end
	hook.Parent = player:WaitForChild("PlayerGui")
end

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then
		return
	end
	if input.KeyCode == Enum.KeyCode.LeftShift then
		onPress()
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		onRelease()
	end
end)

slotPress.Event:Connect(function(slotId, down)
	if slotId == "dash" then
		if down then
			onPress()
		else
			onRelease()
		end
	end
end)

dashResult.OnClientEvent:Connect(function(data)
	if not data.ok then
		if data.reason ~= "busy" then
			localDash = MoveRules.newDashState()
		end
		local character = player.Character
		if character then -- 리뷰 4: 서버가 거절하면 이 체공의 공중대시도 돌려준다
			local used = (character:GetAttribute("AirDashesUsed") or 0) - 1
			character:SetAttribute("AirDashesUsed", used > 0 and used or nil)
			character:SetAttribute("AirDashUntil", nil)
			character:SetAttribute("DashReadyAt", nil)
			character:SetAttribute("DashSecondUntil", nil)
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
	WeaponVisual.playDash(nil, data.durationSeconds, pendingSecond) -- W1 대시 무기 자세 · W3b 2단 대시 비틀기(남에게는 중계 "dash" · "dash2")
	airMoveFx:FireServer(pendingSecond and "dash2" or "dash")
	pendingSecond = false
end)
