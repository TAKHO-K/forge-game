-- BR1-4b 보스 리그(4b-1): shared/data/BossRigSpec 표로 부위 파트 + Motor6D를 짓고(서버 MonsterSpawner), 관절 자세로 부위 자리를 계산한다(FK - 서버가 잡힌 사람을
-- 손 · 꼬리 부착점에 둘 때 · 클라 검사). 모션(자세 계산)은 client/BossAnimator + shared/BossMotion - 이 모듈은 모양과 FK만.

local BossRigSpec = require(script.Parent.data.BossRigSpec) -- A2-M1: 상대 경로(편집 모드 미리보기가 Shared 복제본에서 새로 불러 쓴다 - 동작 같음)

local BossRig = {}

local function angles(rot)
	if not rot then
		return CFrame.identity
	end
	return CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
end

function BossRig.specFor(bossId)
	return bossId and BossRigSpec.rigs[bossId] or nil
end

-- A2-M1 접지: 보스 리그(rig.groundLift)는 발바닥 = 루트 − 1.5(stud)가 되게 루트에 붙는 관절만 1.5 × (S − 1) 올린다.
--   옛 = 발바닥 루트 − 1.5 × S · 루트 = 바닥 + 1.5(판정 자리 - 그대로) → 크기 3에서 발이 바닥 아래 3 stud(정강이까지 묻힘 · Play 1 실측 4.35 stud @ 3.9).
--   모든 FK(서버 잡기 부착점 · 클라 모션 · 검사)가 이 함수를 거쳐 같이 올라간다. 잡몹 리그(MonsterRigSpec)는 표시가 없어 그대로.
function BossRig.rootLift(rig, S)
	return (rig and rig.groundLift) and 1.5 * (S - 1) or 0
end

-- 관절 하나의 C0 · C1(sizeScale 적용). lift = 루트 관절만 올리는 높이(BossRig.rootLift).
function BossRig.jointFrames(j, S, lift)
	local at = j.at * S
	if lift and lift ~= 0 and j.parent == "HumanoidRootPart" then
		at += Vector3.new(0, lift, 0)
	end
	return CFrame.new(at) * angles(j.rot), CFrame.new(j.pivot * S)
end

local function newPart(j, S, look, rig)
	local part
	if j.shape == "wedge" then
		part = Instance.new("WedgePart")
	elseif j.shape == "corner" then
		part = Instance.new("CornerWedgePart")
	else
		part = Instance.new("Part")
		if j.shape == "ball" then
			part.Shape = Enum.PartType.Ball
		elseif j.shape == "cyl" then
			part.Shape = Enum.PartType.Cylinder
		end
	end
	part.Name = j.part or j.name -- 장식(A2-M1)은 name
	part.Size = j.size * S
	part.Color = BossRigSpec.colorOf(j.color, look, rig)
	part.Material = j.material and Enum.Material[j.material] or Enum.Material.SmoothPlastic
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = j.query == true
	part.CastShadow = j.size.Magnitude * S > 1.2
	return part
end

-- 모델에 리그를 짓는다. look = { sizeScale, bodyColor, headColor, detail(A2-M1 - true면 디테일: 새 관절 · 장식 · 테마 색 = ArtStyleV1 스위치) } · position = 루트 자리.
-- 반환: root, body, head(옛 BossLook.buildCore와 같은 약속).
function BossRig.build(model, rig, look, position)
	local S = look.sizeScale or 1
	if look.detail and rig.themeColors then
		look = table.clone(look)
		look.bodyColor, look.headColor = rig.themeColors.body, rig.themeColors.head
	end
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1) * S
	root.Transparency = 1
	root.CanCollide = false
	root.Anchored = true
	root.Position = position
	root.Parent = model
	local parts = { HumanoidRootPart = root }
	local lift = BossRig.rootLift(rig, S)
	for _, j in ipairs(rig.joints) do
		local p0 = parts[j.parent]
		if j.detail and not look.detail then
			continue -- A2-M1 디테일 관절은 스위치 켬일 때만
		end
		local c0, c1 = BossRig.jointFrames(j, S, lift)
		local part = newPart(j, S, look, rig)
		if look.detail and rig.recolor and rig.recolor[j.part] then
			part.Color = BossRigSpec.colorOf(rig.recolor[j.part], look, rig) -- A2-M1 디테일 모드 부위 색
		end
		part.CFrame = p0.CFrame * c0 * c1:Inverse()
		part.Parent = model
		local motor = Instance.new("Motor6D")
		motor.Name = j.name
		motor.Part0 = p0
		motor.Part1 = part
		motor.C0 = c0
		motor.C1 = c1
		motor.Parent = p0
		parts[j.part] = part
	end
	-- A2-M1 장식(관절 없음 - 부모 부위에 용접 · 충돌 · 조준 · 터치 없음 · 모션 비용 0). lod 2 = 세밀(클라가 폰 · 먼 거리에서 숨긴다 - Attribute DetailLod)
	if look.detail and rig.deco then
		for _, d in ipairs(rig.deco) do
			local p0 = parts[d.parent]
			if p0 then
				local part = newPart(d, S, look, rig)
				part.Name = d.name
				part.CFrame = p0.CFrame * CFrame.new(d.at * S) * angles(d.rot)
				if d.lod == 2 then
					part:SetAttribute("DetailLod", 2)
				end
				local weld = Instance.new("WeldConstraint")
				weld.Part0, weld.Part1 = p0, part
				weld.Parent = part
				part.Parent = model
			end
		end
	end
	for name, a in pairs(rig.attach) do
		local host = parts[a.part]
		if host then
			local att = Instance.new("Attachment")
			att.Name = "Rig_" .. name
			att.Position = a.at * S
			att.Parent = host
		end
	end
	return root, parts.Body, parts.Head
end

-- FK: 루트 CFrame · 자세(pose[관절 이름] = CFrame - Motor6D.Transform과 같은 뜻 · 없으면 기준 자세)로 부위 CFrame 표. 부착점 이름을 주면 그 점의 CFrame만.
function BossRig.solve(rig, rootCFrame, S, pose)
	local out = { HumanoidRootPart = rootCFrame }
	local lift = BossRig.rootLift(rig, S)
	for _, j in ipairs(rig.joints) do
		local c0, c1 = BossRig.jointFrames(j, S, lift)
		out[j.part] = out[j.parent] * c0 * ((pose and pose[j.name]) or CFrame.identity) * c1:Inverse()
	end
	return out
end

function BossRig.attachPoint(rig, rootCFrame, S, pose, attachName)
	local a = rig.attach[attachName]
	if not a then
		return nil
	end
	local frames = BossRig.solve(rig, rootCFrame, S, pose)
	local host = frames[a.part]
	return host and host * CFrame.new(a.at * S) or nil
end

return BossRig
