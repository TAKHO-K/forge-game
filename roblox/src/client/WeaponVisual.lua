-- 클래스별 무기 생성·스윙 재생(14-2 재작업). AttackMotionData의 이징 곡선을 매 프레임
-- 손(RightHand) 기준으로 재계산한다 - TweenService로 절대 CFrame을 한 번 목표 잡는
-- 방식은 스윙 도중 캐릭터가 이동하면 무기가 손에서 떨어져 보인다(캐릭터가 최대
-- 0.55초짜리 스윙 동안 16stud/s면 8stud 넘게 움직일 수 있다). 대신 TweenService:GetValue
-- (Instance 없이 alpha 하나로 이징된 alpha를 돌려주는 API)로 로블록스 내장 이징 곡선을
-- 이 절차적 계산 안에 그대로 넣는다 - "손 추적"과 "이징된 스윙"을 동시에 만족시키는
-- 유일한 조합이었다.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AttackMotionData = require(ReplicatedStorage.Shared.data.AttackMotionData)
local WeaponModelData = require(ReplicatedStorage.Shared.data.WeaponModelData)

local WeaponVisual = {}

local player = Players.LocalPlayer

-- 지금 들고 있는 무기 상태 하나. 클래스가 바뀌거나 캐릭터가 다시 스폰되면 통째로 갈아
-- 끼운다(부분 갱신 안 함 - 상태가 섞이면 이전 클래스의 파트가 남는 버그가 생기기 쉽다).
local current = nil
-- current = { classId, model(WeaponModelData 항목), motion(AttackMotionData 항목),
--   kind, instances(part/attachment/trail 등을 담는 테이블, kind별로 구조가 다르다),
--   swingStartTime, releaseFired }

-- instances 테이블은 kind마다 구조가 다르다 - mesh/specialmesh는 최상위에 Instance가
-- 바로 있지만, mesh_pair(parts/trails 딕셔너리)·bow(limbs가 {part=,spec=} 테이블의
-- 리스트)는 Instance가 중첩된 테이블 안에 있다. 최상위만 훑던 이전 버전이 중첩된 것들을
-- 놓쳐서 클래스를 바꿀 때마다 파트가 계속 쌓였다(실제 플레이로 확인된 버그) - 재귀로
-- 전부 찾아 지운다.
local function destroyDeep(value)
	if typeof(value) == "Instance" then
		value:Destroy()
	elseif type(value) == "table" then
		for _, v in pairs(value) do
			destroyDeep(v)
		end
	end
end

local function clearCurrent()
	if current then
		destroyDeep(current.instances)
		current = nil
	end
end

-- 칼날 하나에 Trail을 붙인다 - 시작·끝 두 Attachment 사이를 이어 그린다(지시 사항).
-- 클래스별 색·굵기는 AttackMotionData(모션 쪽 데이터)가 가진다 - "이 클래스가 얼마나
-- 굵고 진한 검기를 남기는가"는 형태보다 모션의 성격이라고 판단했다.
local function attachTrail(part, topLocal, bottomLocal, width, color)
	local topAttach = Instance.new("Attachment")
	topAttach.Position = topLocal
	topAttach.Parent = part

	local bottomAttach = Instance.new("Attachment")
	bottomAttach.Position = bottomLocal
	bottomAttach.Parent = part

	local trail = Instance.new("Trail")
	trail.Attachment0 = topAttach
	trail.Attachment1 = bottomAttach
	trail.Lifetime = 0.22
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, width),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Color = ColorSequence.new(color)
	trail.Enabled = false
	trail.Parent = part

	return trail
end

-- MeshPart.MeshId는 런타임 스크립트에서 못 쓴다("lacking capability NotAccessible" -
-- 실측으로 확인, 로블록스가 보안상 잠가 뒀다) - 그래서 MeshPart 대신 Part +
-- SpecialMesh(레거시 메시, MeshId가 여전히 스크립트로 설정 가능하다)로 우회한다.
-- SpecialMesh는 부모 Part의 Transparency·Color를 그대로 따른다 - Part 자체를 투명하게
-- 두면 메시도 안 보인다(테스트로 확인).
local function buildMeshPart(name, meshId, size, color)
	local part = Instance.new("Part")
	part.Name = "Weapon_" .. name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Parent = workspace

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = meshId
	mesh.Parent = part

	return part
end

local function buildWeapon(classId)
	local model = WeaponModelData[classId]
	local motion = AttackMotionData[classId]
	if not model or not motion then
		return nil
	end

	local instances = {}

	if model.kind == "mesh" then
		local part = buildMeshPart("Blade", model.meshId, model.size, model.color)
		instances.part = part
		instances.trail = attachTrail(part, model.trailTop, model.trailBottom, motion.trailWidth, motion.trailColor)
	elseif model.kind == "mesh_pair" then
		instances.parts = {}
		instances.trails = {}
		for _, partSpec in ipairs(model.parts) do
			local part = buildMeshPart(partSpec.name, model.meshId, model.size, model.color)
			instances.parts[partSpec.name] = part
			instances.trails[partSpec.name] = attachTrail(part, model.trailTop, model.trailBottom, motion.trailWidth, motion.trailColor)
		end
	elseif model.kind == "specialmesh" then
		local part = Instance.new("Part")
		part.Name = "Weapon_Staff"
		part.Size = model.size
		part.Color = model.color
		-- SpecialMesh는 부모 Part의 Transparency를 그대로 따른다 - 여기서 투명하게 두면
		-- 메시도 안 보인다(buildMeshPart 주석과 같은 이유로 실측 확인).
		part.Anchored = true
		part.CanCollide = false
		part.CastShadow = false
		part.Parent = workspace

		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.FileMesh
		mesh.MeshId = model.meshId
		mesh.TextureId = model.textureId
		mesh.Scale = Vector3.new(1, 1, 1)
		mesh.Parent = part

		instances.part = part
	elseif model.kind == "bow" then
		local root = Instance.new("Part")
		root.Name = "Weapon_BowRoot"
		root.Size = Vector3.new(0.1, 0.1, 0.1)
		root.Transparency = 1
		root.Anchored = true
		root.CanCollide = false
		root.CastShadow = false
		root.Parent = workspace
		instances.root = root

		instances.limbs = {}
		for i, limb in ipairs(model.limbs) do
			local part = Instance.new("Part")
			part.Name = "Weapon_Limb" .. i
			part.Shape = Enum.PartType.Cylinder
			part.Size = limb.size
			part.Color = model.color
			part.Material = Enum.Material.SmoothPlastic
			part.Anchored = true
			part.CanCollide = false
			part.CastShadow = false
			part.Parent = workspace
			table.insert(instances.limbs, { part = part, spec = limb })
		end

		local stringTop = Instance.new("Part")
		stringTop.Name = "Weapon_StringTop"
		stringTop.Shape = Enum.PartType.Cylinder
		stringTop.Size = Vector3.new(1, model.stringThickness, model.stringThickness)
		stringTop.Color = model.stringColor
		stringTop.Material = Enum.Material.SmoothPlastic
		stringTop.Anchored = true
		stringTop.CanCollide = false
		stringTop.CastShadow = false
		stringTop.Parent = workspace
		instances.stringTop = stringTop

		local stringBottom = stringTop:Clone()
		stringBottom.Name = "Weapon_StringBottom"
		stringBottom.Parent = workspace
		instances.stringBottom = stringBottom

		local arrow = Instance.new("Part")
		arrow.Name = "Weapon_Arrow"
		arrow.Size = model.arrowSize
		arrow.Color = model.arrowColor
		arrow.Material = Enum.Material.SmoothPlastic
		arrow.Anchored = true
		arrow.CanCollide = false
		arrow.CastShadow = false
		arrow.Parent = workspace
		instances.arrow = arrow
	end

	return { classId = classId, model = model, motion = motion, kind = model.kind, instances = instances, swingStartTime = nil }
end

local function refresh()
	clearCurrent()
	local classId = player:GetAttribute("ClassId")
	if classId and classId ~= "" then
		current = buildWeapon(classId)
	end
end

-- 이징 적용 보간(각도 필드용). AttackMotionData.evalEase가 실제 easing 계산을 한다 -
-- 여기는 어느 구간(a,b)에 있는지만 찾는다.
local function evalKeyframes(keyframes, alpha, field)
	alpha = math.clamp(alpha, 0, 1)
	for i = 1, #keyframes - 1 do
		local a, b = keyframes[i], keyframes[i + 1]
		if alpha >= a.t and alpha <= b.t then
			local span = b.t - a.t
			local localAlpha = span > 0 and (alpha - a.t) / span or 0
			local easedAlpha = AttackMotionData.evalEase(localAlpha, b.easing)
			return a[field] + (b[field] - a[field]) * easedAlpha
		end
	end
	return keyframes[#keyframes][field]
end

local function rotationCFrame(swingAxis, angleDeg)
	if swingAxis == "X" then
		return CFrame.Angles(math.rad(angleDeg), 0, 0)
	elseif swingAxis == "Y" then
		return CFrame.Angles(0, math.rad(angleDeg), 0)
	else
		return CFrame.Angles(0, 0, math.rad(angleDeg))
	end
end

local function inTrailWindow(window, alpha)
	return window and alpha >= window[1] and alpha <= window[2]
end

local function updateMeleeAlike(hands, model, motion, instances, alpha, singlePart, pairParts)
	for _, partMotion in ipairs(motion.parts) do
		local part = singlePart or pairParts[partMotion.name]
		local gripOffset
		local handName = "RightHand"
		if model.kind == "mesh_pair" then
			for _, spec in ipairs(model.parts) do
				if spec.name == partMotion.name then
					gripOffset = spec.gripOffset
					handName = spec.hand or "RightHand"
					break
				end
			end
		else
			gripOffset = model.gripOffset
		end
		local hand = hands[handName]
		if not hand then
			continue
		end

		local angle = evalKeyframes(partMotion.keyframes, alpha, "angle")
		part.CFrame = hand.CFrame * gripOffset * rotationCFrame(partMotion.swingAxis, angle)

		local trail = model.kind == "mesh_pair" and instances.trails[partMotion.name] or instances.trail
		if trail then
			trail.Enabled = current.swingStartTime ~= nil and inTrailWindow(partMotion.trailWindow, alpha)
		end
	end
end

local function updateBow(hand, model, motion, instances, alpha)
	local rootCFrame = hand.CFrame * model.gripOffset
	instances.root.CFrame = rootCFrame

	for _, limb in ipairs(instances.limbs) do
		local spec = limb.spec
		limb.part.CFrame = rootCFrame * CFrame.new(spec.relPos) * CFrame.Angles(0, math.rad(spec.relRotYDeg), 0)
	end

	local drawOffset = evalKeyframes(motion.parts[1].keyframes, alpha, "offset")
	local topTip = model.stringTopTip
	local bottomTip = model.stringBottomTip
	local nock = model.stringRestNock + Vector3.new(0, 0, drawOffset)

	local function placeStringSegment(part, fromLocal, toLocal)
		local fromWorld = rootCFrame:PointToWorldSpace(fromLocal)
		local toWorld = rootCFrame:PointToWorldSpace(toLocal)
		local mid = (fromWorld + toWorld) / 2
		local length = (toWorld - fromWorld).Magnitude
		part.Size = Vector3.new(length, part.Size.Y, part.Size.Z)
		part.CFrame = CFrame.lookAt(mid, toWorld) * CFrame.Angles(0, math.rad(90), 0)
	end

	placeStringSegment(instances.stringTop, topTip, nock)
	placeStringSegment(instances.stringBottom, bottomTip, nock)

	-- 화살은 시위가 풀리는 시점(motion.releaseT) 전까지만 보인다 - 그 뒤는 실제로 날아가는
	-- 화살(Projectiles.lua)이 대신한다(AttackInput.client.lua가 그 시점에 발사한다).
	local showArrow = not current.swingStartTime or alpha < motion.releaseT
	instances.arrow.Transparency = showArrow and 0 or 1
	if showArrow then
		-- 화살은 항상 시위와 수직으로, 활 곡선 평면과 수직인 방향(로컬 +X - 원본 데이터의
		-- Y축이 활의 "두께"였는데 그립 회전(Z축 90도)이 Y를 X로 옮겼다, WeaponModelData.lua
		-- 주석 참고)을 향한다.
		local nockWorld = rootCFrame:PointToWorldSpace(nock)
		local outwardWorld = rootCFrame:VectorToWorldSpace(Vector3.new(1, 0, 0))
		instances.arrow.CFrame = CFrame.lookAt(nockWorld, nockWorld + outwardWorld)
	end
end

local function updateStaff(hand, model, motion, instances, alpha)
	local partMotion = motion.parts[1]
	local angle = evalKeyframes(partMotion.keyframes, alpha, "angle")
	instances.part.CFrame = hand.CFrame * model.gripOffset * rotationCFrame(partMotion.swingAxis, angle)
end

local function updateFrame()
	if not current then
		return
	end

	local character = player.Character
	local rightHand = character and character:FindFirstChild("RightHand")
	if not rightHand then
		return
	end
	-- 쌍검은 왼손에도 칼이 붙는다(WeaponModelData.lua의 dualblade.parts[].hand) - 오른손
	-- 하나만 쓰던 이전 버전은 두 자루가 다 오른손에 붙는 버그("젓가락질")였다.
	local leftHand = character:FindFirstChild("LeftHand")
	local hands = { RightHand = rightHand, LeftHand = leftHand }

	local alpha = 0
	if current.swingStartTime then
		alpha = math.clamp((os.clock() - current.swingStartTime) / current.motion.totalDurationSeconds, 0, 1)
	end

	if current.kind == "mesh" then
		updateMeleeAlike(hands, current.model, current.motion, current.instances, alpha, current.instances.part, nil)
	elseif current.kind == "mesh_pair" then
		updateMeleeAlike(hands, current.model, current.motion, current.instances, alpha, nil, current.instances.parts)
	elseif current.kind == "bow" then
		updateBow(rightHand, current.model, current.motion, current.instances, alpha)
	elseif current.kind == "specialmesh" then
		updateStaff(rightHand, current.model, current.motion, current.instances, alpha)
	end
end

-- 서버 확인 없이 즉시 재생한다(지시 사항 - "모션은 클라이언트에서 재생한다. 판정은
-- 여전히 서버다"). 스윙 길이는 클래스 데이터(AttackMotionData)가 고정으로 갖고 있다 -
-- 호출부는 "지금 재생해라"만 알려주면 된다.
function WeaponVisual.playSwing()
	if not current then
		return
	end
	current.swingStartTime = os.clock()
end

-- 활/힐러 전용 - 지금 스윙이 "발사 시점"(releaseT)을 지났는지. AttackInput.client.lua가
-- 서버의 attackResult를 받았을 때 이미 발사 시점이 지났다면 곧바로 투사체를 쏘고,
-- 아직이면(스윙이 방금 시작해 발사 애니메이션이 안 끝났으면) releaseT까지 기다렸다가
-- 쏜다 - 시위가 안 당겨진 채로 화살이 날아가는 어색함을 막는다.
function WeaponVisual.getReleaseDelay()
	if not current or not current.motion.releaseT or not current.swingStartTime then
		return 0
	end
	local elapsed = os.clock() - current.swingStartTime
	local releaseAt = current.motion.releaseT * current.motion.totalDurationSeconds
	return math.max(releaseAt - elapsed, 0)
end

-- 투사체(화살·구슬)가 시작할 위치 - 활은 시위 nock 근처, 힐러는 지팡이 끝.
function WeaponVisual.getMuzzleWorldPosition()
	if not current then
		return nil
	end
	if current.kind == "bow" then
		return current.instances.arrow.Position
	elseif current.kind == "specialmesh" then
		local part = current.instances.part
		return (part.CFrame * CFrame.new(0, 0, -current.model.size.Z / 2)).Position
	end
	return nil
end

player.CharacterAdded:Connect(refresh)
player:GetAttributeChangedSignal("ClassId"):Connect(refresh)
refresh()

RunService.RenderStepped:Connect(updateFrame)

return WeaponVisual
