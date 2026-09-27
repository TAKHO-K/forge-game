-- BR1-4b 보스 리그(4b-1): shared/data/BossRigSpec 표로 부위 파트 + Motor6D를 짓고(서버 MonsterSpawner), 관절 자세로 부위 자리를 계산한다(FK - 서버가 잡힌 사람을
-- 손 · 꼬리 부착점에 둘 때 · 클라 검사). 모션(자세 계산)은 client/BossAnimator + shared/BossMotion - 이 모듈은 모양과 FK만.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossRigSpec = require(ReplicatedStorage.Shared.data.BossRigSpec)

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

-- 관절 하나의 C0 · C1(sizeScale 적용).
function BossRig.jointFrames(j, S)
	return CFrame.new(j.at * S) * angles(j.rot), CFrame.new(j.pivot * S)
end

local function newPart(j, S, look, rig)
	local part
	if j.shape == "wedge" then
		part = Instance.new("WedgePart")
	else
		part = Instance.new("Part")
		if j.shape == "ball" then
			part.Shape = Enum.PartType.Ball
		end
	end
	part.Name = j.part
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

-- 모델에 리그를 짓는다. look = { sizeScale, bodyColor, headColor } · position = 루트 자리. 반환: root, body, head(옛 BossLook.buildCore와 같은 약속).
function BossRig.build(model, rig, look, position)
	local S = look.sizeScale or 1
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1) * S
	root.Transparency = 1
	root.CanCollide = false
	root.Anchored = true
	root.Position = position
	root.Parent = model
	local parts = { HumanoidRootPart = root }
	for _, j in ipairs(rig.joints) do
		local p0 = parts[j.parent]
		local c0, c1 = BossRig.jointFrames(j, S)
		local part = newPart(j, S, look, rig)
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
	for _, j in ipairs(rig.joints) do
		local c0, c1 = BossRig.jointFrames(j, S)
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
