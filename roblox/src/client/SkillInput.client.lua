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

-- 21-2 [3]: 슬롯 탭/클릭(모바일의 유일한 스킬 입력) - 키 입력과 같은 함수로 들어간다.
local slotTapped = skillSlotsGui:WaitForChild("SkillSlotTapped")
slotTapped.Event:Connect(function(slotId)
	if slotId == "q" or slotId == "e" then
		requestSkill(slotId:upper())
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
			-- 회전은 건드리지 않는다 - 위치만 옮긴다. 관통돌진(전방)은 원래 보던 방향과
			-- 이동 방향이 같아 문제가 안 됐지만, 백스텝샷(후방, 20-2b)은 이동 방향대로
			-- 돌려버리면 뒤로 빠지면서 캐릭터가 홱 돌아 뒤를 보는 꼴이 된다 - 회피기는
			-- 물러나는 동안에도 정면을 유지해야 자연스럽다.
			local currentRotation = rootPart.CFrame - rootPart.CFrame.Position
			TweenService:Create(rootPart, TweenInfo.new(data.durationSeconds, Enum.EasingStyle.Linear), {
				CFrame = currentRotation + data.endPosition,
			}):Play()
		end
		SkillEffects.dashAfterimage(data.startPosition, data.endPosition, color, data.durationSeconds)
		playHits(data.hits)
	elseif data.kind == "tick" then
		SkillEffects.expandingRing(data.casterPosition, data.radiusStuds, color, 0.4)
		playHits(data.hits)
		-- 광역(대회전)에만 카메라 흔들림(지시 [4] - "돌진마다 흔들리면 멀미가 난다").
		CameraShake.trigger(E_CAMERA_SHAKE_SECONDS, E_CAMERA_SHAKE_STUDS)
	elseif data.kind == "summon" then
		-- 그림자분신(20-6 [2]) - Model 자체는 서버가 만들어 Workspace에 Parent하는 순간
		-- 모든 클라에 자동 복제된다(SkillServer.server.lua) - 여기선 소환 순간을 강조하는
		-- 짧은 퍼짐 링 하나만 더한다(대검 회전베기의 expandingRing을 그대로 재사용).
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			SkillEffects.expandingRing(rootPart.Position, 4, color, 0.3)
		end
	elseif data.kind == "flurryTick" then
		-- 난무(20-6 [3]) - 매 타격마다 대상 위치에 교차 베기 이펙트(지시 [3] "이펙트: 한 점에
		-- 모이는 교차 베기").
		local hit = data.hits[1]
		if hit then
			local targetRoot = hit.target.PrimaryPart
			if targetRoot then
				SkillEffects.crossSlash(targetRoot.Position, color, 0.2)
			end
			playHits(data.hits)
		end
	elseif data.kind == "heal" then
		-- 치유(힐러 Q, 20-6 [5]) - hits가 아니라 self 필드를 읽는다([4] 결과 포맷 확장의
		-- 첫 사용자). 자기 자신에게만 뜬다 - playHits를 안 쓴다(대상이 몬스터가 아니다).
		local character = player.Character
		if character and data.self then
			DamageNumbers.show(character, data.self.healAmount, data.self.isCrit, true)
			SkillEffects.healRise(character, color, 1.0)
		end
	elseif data.kind == "toggle" then
		-- 딜링모드(힐러 E, 20-6 [6]) - 상태 표시는 BuffHud(아이콘)와 PlayerHealthBar(체력바
		-- 테두리/색)가 서버 Attribute를 직접 구독해서 맡는다(둘 다 "서버가 유일한 진실"
		-- 원칙) - 여기서는 켜지는 순간의 작은 강조 이펙트만 더한다.
		if data.active then
			local character = player.Character
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")
			if rootPart then
				SkillEffects.expandingRing(rootPart.Position, 3, color, 0.25)
			end
		end
	elseif data.kind == "selfBuff" then
		-- 활 속사(20-2b [1][3]) - "버프 중 캐릭터 주변에 빠른 느낌의 잔상 또는 링. 과하게
		-- 하지 마라"는 지시대로 은은한 발등 링 하나만 지속시간 내내 따라다닌다. 실제 배율
		-- 표시는 BuffHud.client.lua(체력바 근처)가 맡는다 - 이 이펙트는 순수 시각 강조.
		local character = player.Character
		if character then
			local def = SkillData[player:GetAttribute("ClassId")][slot]
			SkillEffects.selfBuffAura(character, 2.2, color, def.durationSeconds)
		end
	end
	-- kind == "channelStart"는 별도 재생 없음 - WalkSpeed는 서버가 이미 바꿨고 Attribute
	-- 복제로 클라가 자동으로 따라간다(PlayerProfile.refreshMovementSpeed와 같은 경로).
end)
