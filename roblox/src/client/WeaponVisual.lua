-- 클래스별 무기 파트 생성·스윙 재생(14-2). AttackMotionData.lua의 곡선을 매 프레임
-- 손(RightHand) 기준으로 재계산한다 - TweenService로 절대 CFrame을 한 번 목표 잡는
-- 방식은 스윙 도중 캐릭터가 이동하면 무기가 손에서 떨어져 보인다(그 이유는
-- AttackMotionData.lua 상단 주석 참고). 이 모듈 혼자 캐릭터 스폰·클래스 변경을 구독해
-- 무기를 다시 만든다 - 호출부(AttackInput.client.lua)는 WeaponVisual.playSwing()만
-- 부르면 된다.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AttackMotionData = require(ReplicatedStorage.Shared.data.AttackMotionData)

local WeaponVisual = {}

local player = Players.LocalPlayer

-- 지금 들고 있는 무기 상태 하나. 클래스가 바뀌거나 캐릭터가 다시 스폰되면 통째로 갈아
-- 끼운다(부분 갱신 안 함 - 상태가 섞이면 이전 클래스의 파트가 남는 버그가 생기기 쉽다).
local current = nil -- { classId, config, parts = {name=Part}, swingStartTime, swingDuration }

local function clearCurrent()
	if current then
		for _, part in pairs(current.parts) do
			part:Destroy()
		end
		current = nil
	end
end

local function buildWeapon(classId)
	local config = AttackMotionData[classId]
	if not config then
		return nil
	end

	local parts = {}
	for _, partConfig in ipairs(config.parts) do
		local part = Instance.new("Part")
		part.Name = "Weapon_" .. partConfig.name
		part.Size = partConfig.size
		part.Color = partConfig.color
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.CastShadow = false
		part.Parent = workspace
		parts[partConfig.name] = part
	end

	return { classId = classId, config = config, parts = parts, swingStartTime = nil, swingDuration = nil }
end

local function refresh()
	clearCurrent()
	local classId = player:GetAttribute("ClassId")
	if classId and classId ~= "" then
		current = buildWeapon(classId)
	end
end

-- 구간 t 사이를 선형 보간한다(EasingStyle을 안 쓰는 이유는 AttackMotionData.lua 참고 -
-- 매 프레임 손 위치를 다시 따라가야 해서 TweenService를 못 쓰고, 짧은 스윙에서는 선형도
-- 충분히 스냅있게 느껴진다).
local function lerpKeyframes(keyframes, alpha, field)
	alpha = math.clamp(alpha, 0, 1)
	for i = 1, #keyframes - 1 do
		local a, b = keyframes[i], keyframes[i + 1]
		if alpha >= a.t and alpha <= b.t then
			local span = b.t - a.t
			local localAlpha = span > 0 and (alpha - a.t) / span or 0
			return a[field] + (b[field] - a[field]) * localAlpha
		end
	end
	return keyframes[#keyframes][field]
end

local function updateFrame()
	if not current then
		return
	end

	local character = player.Character
	local hand = character and character:FindFirstChild("RightHand")
	if not hand then
		return
	end

	local alpha = 0
	if current.swingStartTime then
		alpha = math.clamp((os.clock() - current.swingStartTime) / current.swingDuration, 0, 1)
	end

	for _, partConfig in ipairs(current.config.parts) do
		local part = current.parts[partConfig.name]
		local rest = partConfig.restRotationDeg

		if partConfig.swingAxis == "ArrowShoot" then
			-- 화살은 회전이 아니라 전후 이동 - gripOffset 뒤에 국소 Z축 이동을 더 얹는다.
			local offset = lerpKeyframes(partConfig.keyframes, alpha, "offset")
			part.CFrame = hand.CFrame * partConfig.gripOffset * CFrame.new(0, 0, offset)
				* CFrame.Angles(math.rad(rest.X), math.rad(rest.Y), math.rad(rest.Z))
			-- 발사된 뒤(비행 구간)엔 숨긴다 - 다음 스윙이 시작되면(alpha가 0으로 돌아가면)
			-- 다시 보인다. 원위치로 순간이동하는 게 보이지 않게 하는 목적뿐이다.
			part.Transparency = (current.swingStartTime and alpha > 0.72) and 1 or 0
		else
			local angle = lerpKeyframes(partConfig.keyframes, alpha, "angle")
			local rx, ry, rz = rest.X, rest.Y, rest.Z
			if partConfig.swingAxis == "X" then
				rx += angle
			elseif partConfig.swingAxis == "Y" then
				ry += angle
			else
				rz += angle
			end
			part.CFrame = hand.CFrame * partConfig.gripOffset * CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(rz))
		end
	end
end

-- 서버 확인 없이 즉시 재생한다(지시 사항 - "모션은 클라이언트에서 재생한다. 판정은
-- 여전히 서버다"). 호출부(AttackInput.client.lua)는 그 클래스의 공격 쿨다운(초)만
-- 넘긴다 - 실제 스윙 길이(쿨다운의 몇 %를 쓸지)는 AttackMotionData의
-- swingDurationRatio가 클래스마다 정하므로 호출부는 몰라도 된다.
function WeaponVisual.playSwing(attackCooldownSeconds)
	if not current then
		return
	end
	current.swingStartTime = os.clock()
	current.swingDuration = math.max(attackCooldownSeconds * current.config.swingDurationRatio, 0.05)
end

player.CharacterAdded:Connect(refresh)
player:GetAttributeChangedSignal("ClassId"):Connect(refresh)
refresh()

RunService.RenderStepped:Connect(updateFrame)

return WeaponVisual
