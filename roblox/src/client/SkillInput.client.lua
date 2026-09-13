-- 스킬 입력(Q/E, 20-2a) + 서버 결과 수신. 판정·쿨다운·이동 도착점은 전부 서버
-- (SkillServer.server.lua)가 계산한다 - 여기는 키 입력을 보내고, 서버가 알려준 결과
-- (이동 도착점·타격 목록)를 재생만 한다.
--
-- 쿨다운 링(SkillSlots.client.lua)은 이 스크립트가 직접 못 건드린다 - 서로 다른
-- LocalScript라 require로 연결할 수 없다(Rojo가 .client.lua를 LocalScript로 만든다).
-- 대신 두 가지 채널을 쓴다: (1) BindableEvent(SkillCastLocal, 같은 클라 안에서만 오가는
-- 로컬 신호) - 키를 누른 즉시 링을 낙관적으로 돌리기 시작한다(지시 [1] "낙관적으로 먼저
-- 돌아도 된다"). (2) SkillCastResult RemoteEvent - 서버 진실이 필요하면(거부됐을 때)
-- SkillSlots가 이 리모트를 직접 구독해 스스로 바로잡는다(지시 [1] "서버 응답이 다르면
-- 서버 상태로 되돌려라") - 이 스크립트가 대신 전달해 줄 필요가 없다, RemoteEvent는
-- 누구든 들을 수 있는 방송이다(comboUpdate 등 기존 리모트도 이미 이 방식).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local SkillData = require(ReplicatedStorage.Shared.data.SkillData)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local UIManager = require(script.Parent.UIManager)
local WeaponVisual = require(script.Parent.WeaponVisual)
local HitEffects = require(script.Parent.HitEffects)
local DamageNumbers = require(script.Parent.DamageNumbers)
local CameraShake = require(script.Parent.CameraShake)
local SkillEffects = require(script.Parent.SkillEffects)

local skillRequest = ReplicatedStorage:WaitForChild("SkillRequest")
local skillCastResult = ReplicatedStorage:WaitForChild("SkillCastResult")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- SkillSlots.client.lua가 자기 ScreenGui 밑에 만들어 두는 로컬 전용 신호(ComboPipsAnchor와
-- 같은 WaitForChild 계약 패턴, AttackInput.client.lua 참고).
local skillSlotsGui = playerGui:WaitForChild("SkillSlotsGui")
local localCastSignal = skillSlotsGui:WaitForChild("SkillCastLocal")

local KEY_TO_SLOT = { [Enum.KeyCode.Q] = "Q", [Enum.KeyCode.E] = "E" }

-- 서버 왕복 전에 한 번 더 막는 로컬 게이트(지시 [5] 검증 2 - "쿨다운 중 다시 누르면
-- 아무 일도 일어나지 않는다"). 서버도 독립적으로 다시 검사한다(클라를 믿지 않는다,
-- SkillServer.server.lua) - 이건 그냥 연타로 서버에 불필요한 요청을 안 보내기 위한
-- UX 1차 방어일 뿐이다.
local localCooldownUntil = { Q = 0, E = 0 }

-- 스킬 적중 피드백(20-2a [4]) - 3타 강타(0.08초)보다 조금 무겁게. "스킬은 더 무겁게
-- 느껴져야 한다"는 지시대로 실기로 맞춘 값.
local HEAVY_HITSTOP_SECONDS = 0.12
local E_CAMERA_SHAKE_SECONDS = 0.2
local E_CAMERA_SHAKE_STUDS = 0.5

local function classAccentColor()
	local classId = player:GetAttribute("ClassId")
	return (classId and classId ~= "" and UIColors.classAccent[classId]) or UIColors.ember
end

local function playHits(hits)
	if #hits == 0 then
		return
	end
	for _, hit in ipairs(hits) do
		DamageNumbers.show(hit.target, hit.damage, hit.isCrit)
		if hit.isDead then
			HitEffects.playDeath(hit.target)
		else
			HitEffects.playHit(hit.target, hit.isCrit, HEAVY_HITSTOP_SECONDS)
		end
	end
	WeaponVisual.applyHitstop(HEAVY_HITSTOP_SECONDS)
end

local function requestSkill(slot)
	-- 18-1 [3]과 같은 이중 방어(모달 열려 있으면 게임 입력을 막는다) - 지시 [5] 검증 5.
	if UIManager.isInputBlocked() then
		return
	end
	if os.clock() < localCooldownUntil[slot] then
		return
	end

	local classId = player:GetAttribute("ClassId")
	local def = classId and classId ~= "" and SkillData[classId] and SkillData[classId][slot]
	if not def then
		return -- 이 직업엔 이 스킬이 없다(대검 외 - 지시 [5] 검증 7, 조용히 무시하고 끝)
	end

	localCooldownUntil[slot] = os.clock() + def.cooldownSeconds
	localCastSignal:Fire(slot, def.cooldownSeconds)

	-- 기존 평타 모션을 그대로 재사용한다(지시 [4] - 새 애니메이션 금지, 재생속도·스케일
	-- 조정까지만 허용). 3타 강타 변형(playSwing(true))이 이미 그 조정을 갖고 있어 그대로
	-- 쓴다 - 차별화는 아래 SkillCastResult 핸들러의 이펙트가 맡는다.
	WeaponVisual.playSwing(true)

	skillRequest:FireServer(slot)
end

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then
		return
	end
	local slot = KEY_TO_SLOT[input.KeyCode]
	if slot then
		requestSkill(slot)
	end
end)

skillCastResult.OnClientEvent:Connect(function(slot, data)
	if not data.ok then
		-- 서버가 거부했다(쿨다운 등) - 로컬 낙관적 잠금을 되돌려 바로 다시 시도할 수
		-- 있게 한다. 링 자체의 교정은 SkillSlots.client.lua가 같은 이벤트를 직접 듣고 한다.
		localCooldownUntil[slot] = 0
		return
	end

	local color = classAccentColor()

	if data.kind == "dash" then
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			local delta = data.endPosition - data.startPosition
			local facingPoint = delta.Magnitude > 1e-3 and (data.endPosition + delta.Unit) or (data.endPosition + Vector3.new(0, 0, 1))
			TweenService:Create(rootPart, TweenInfo.new(data.durationSeconds, Enum.EasingStyle.Linear), {
				CFrame = CFrame.new(data.endPosition, facingPoint),
			}):Play()
		end
		SkillEffects.dashAfterimage(data.startPosition, data.endPosition, color, data.durationSeconds)
		playHits(data.hits)
	elseif data.kind == "tick" then
		SkillEffects.expandingRing(data.casterPosition, data.radiusStuds, color, 0.4)
		playHits(data.hits)
		-- 광역(대회전)에만 카메라 흔들림(지시 [4] - "돌진마다 흔들리면 멀미가 난다").
		CameraShake.trigger(E_CAMERA_SHAKE_SECONDS, E_CAMERA_SHAKE_STUDS)
	end
	-- kind == "channelStart"는 별도 재생 없음 - WalkSpeed는 서버가 이미 바꿨고 Attribute
	-- 복제로 클라가 자동으로 따라간다(PlayerProfile.refreshMovementSpeed와 같은 경로).
end)
