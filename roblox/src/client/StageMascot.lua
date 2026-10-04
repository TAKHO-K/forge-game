-- QUEUE-ALL9C 2-4 전용 무대 캐릭터(게임 스타일 R15 블록 1명 - 아바타와 무관하게 늘 같은 모습). 지금 쓰는 곳 = 직업 선택 무대(client/ClassStage) · 나중에 상점 미리보기 · 튜토리얼 안내.
--   StageMascot.new(parent) → mascot: 파트 = 표준 R15 블록 치수(MeshMeta.armor_wear refSize와 같은 크기라 방어구 v3 조각이 자리표 그대로 맞는다) · 전부 Anchored(물리 없음 - ViewportFrame WorldModel 안).
--   움직임 = 관절 FK: mascot:setPose(pose) - pose = { root = CFrame(무대 기준), joints = { [관절 이름] = CFrame 회전 }, squash = 숫자(+ 찌그러짐 · − 늘어남) } → mascot:render().
--   붙이기: mascot:attachArmor(classId) · mascot:attachWeapon(classId) → 조각 목록(조각마다 offset · spin · pop · hidden을 부르는 쪽이 프레임마다 정한다) · mascot:clearGear().
--   색 · 표정 = shared/data/ClassStageData.mascot. 방어구 색 = client/ArmorColors(게임 안 착용과 같은 함수) · 무기 = ArtMeshKit.weaponModel + WeaponRigSpec(손 · 손바닥 · 쥐는 방향).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage.Shared.data.ClassStageData)
local ArtMeshKit = require(ReplicatedStorage.Shared.ArtMeshKit)
local WeaponRigSpec = require(ReplicatedStorage.Shared.data.WeaponRigSpec)
local Wear = require(ReplicatedStorage.Shared.MeshMeta.armor_wear)
local ArmorColors = require(script.Parent.ArmorColors)
local ArtImportData = require(ReplicatedStorage.Shared.data.ArtImportData)
local GearV3 = require(ReplicatedStorage.Shared.GearV3)

local StageMascot = {}
StageMascot.__index = StageMascot

-- 표준 R15 블록(가운데 자리 = 서 있을 때 · 루트 = 원점 · 앞 = −Z · 발바닥 y = FOOT_Y)
local PARTS = {
	{ name = "HumanoidRootPart", size = Vector3.new(2, 2, 1), at = Vector3.new(0, 0.6, 0) },
	{ name = "LowerTorso", size = Vector3.new(2, 0.4, 1), at = Vector3.new(0, -0.2, 0), parent = "HumanoidRootPart", joint = "Root", pivot = Vector3.new(0, -0.4, 0), color = "pants" },
	{ name = "UpperTorso", size = Vector3.new(2, 1.6, 1), at = Vector3.new(0, 0.8, 0), parent = "LowerTorso", joint = "Waist", pivot = Vector3.new(0, 0, 0), color = "shirt" },
	{ name = "Head", size = Vector3.new(2, 1, 1), at = Vector3.new(0, 2.1, 0), parent = "UpperTorso", joint = "Neck", pivot = Vector3.new(0, 1.6, 0), color = "skin" },
	{ name = "RightUpperArm", size = Vector3.new(1, 1.17, 1), at = Vector3.new(1.5, 1.015, 0), parent = "UpperTorso", joint = "RightShoulder", pivot = Vector3.new(1.5, 1.3, 0), color = "shirt" },
	{ name = "RightLowerArm", size = Vector3.new(1, 1.05, 1), at = Vector3.new(1.5, -0.095, 0), parent = "RightUpperArm", joint = "RightElbow", pivot = Vector3.new(1.5, 0.43, 0), color = "skin" },
	{ name = "RightHand", size = Vector3.new(1, 0.3, 1), at = Vector3.new(1.5, -0.77, 0), parent = "RightLowerArm", joint = "RightWrist", pivot = Vector3.new(1.5, -0.62, 0), color = "skin" },
	{ name = "LeftUpperArm", size = Vector3.new(1, 1.17, 1), at = Vector3.new(-1.5, 1.015, 0), parent = "UpperTorso", joint = "LeftShoulder", pivot = Vector3.new(-1.5, 1.3, 0), color = "shirt" },
	{ name = "LeftLowerArm", size = Vector3.new(1, 1.05, 1), at = Vector3.new(-1.5, -0.095, 0), parent = "LeftUpperArm", joint = "LeftElbow", pivot = Vector3.new(-1.5, 0.43, 0), color = "skin" },
	{ name = "LeftHand", size = Vector3.new(1, 0.3, 1), at = Vector3.new(-1.5, -0.77, 0), parent = "LeftLowerArm", joint = "LeftWrist", pivot = Vector3.new(-1.5, -0.62, 0), color = "skin" },
	{ name = "RightUpperLeg", size = Vector3.new(1, 1.22, 1), at = Vector3.new(0.5, -1.01, 0), parent = "LowerTorso", joint = "RightHip", pivot = Vector3.new(0.5, -0.4, 0), color = "pants" },
	{ name = "RightLowerLeg", size = Vector3.new(1, 1.19, 1), at = Vector3.new(0.5, -2.215, 0), parent = "RightUpperLeg", joint = "RightKnee", pivot = Vector3.new(0.5, -1.62, 0), color = "pants" },
	{ name = "RightFoot", size = Vector3.new(1, 0.3, 1), at = Vector3.new(0.5, -2.96, 0), parent = "RightLowerLeg", joint = "RightAnkle", pivot = Vector3.new(0.5, -2.81, 0), color = "shoes" },
	{ name = "LeftUpperLeg", size = Vector3.new(1, 1.22, 1), at = Vector3.new(-0.5, -1.01, 0), parent = "LowerTorso", joint = "LeftHip", pivot = Vector3.new(-0.5, -0.4, 0), color = "pants" },
	{ name = "LeftLowerLeg", size = Vector3.new(1, 1.19, 1), at = Vector3.new(-0.5, -2.215, 0), parent = "LeftUpperLeg", joint = "LeftKnee", pivot = Vector3.new(-0.5, -1.62, 0), color = "pants" },
	{ name = "LeftFoot", size = Vector3.new(1, 0.3, 1), at = Vector3.new(-0.5, -2.96, 0), parent = "LeftLowerLeg", joint = "LeftAnkle", pivot = Vector3.new(-0.5, -2.81, 0), color = "shoes" },
}
StageMascot.FOOT_Y = -3.11
local ARMOR_PARTS = { "armor", "gloves", "shoes" }

function StageMascot.new(parent)
	local self = setmetatable({}, StageMascot)
	local M = Data.mascot
	local model = Instance.new("Model")
	model.Name = "StageMascot"
	self.model = model
	self.parts, self.rest, self.joints = {}, {}, {}
	self.attached = {} -- { part, body, localCF, baseSize, offset(Vector3 | nil), spin(라디안 | nil), pop(크기 배율), hidden }
	for _, spec in ipairs(PARTS) do
		local p = Instance.new("Part")
		p.Name = spec.name
		p.Size = spec.size
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Color = spec.color and M.colors[spec.color] or Color3.new(1, 1, 1)
		p.Transparency = spec.name == "HumanoidRootPart" and 1 or 0
		p.Parent = model
		self.parts[spec.name] = p
		self.rest[spec.name] = spec
		if spec.joint then
			local parentAt = self.rest[spec.parent] and self.rest[spec.parent].at or Vector3.zero
			self.joints[spec.joint] = { part = spec.name, parent = spec.parent, c0 = CFrame.new(spec.pivot - parentAt), c1 = CFrame.new(spec.pivot - spec.at) }
		end
	end
	-- 머리 = 둥근 블록 머리(SpecialMesh Head) + 밝은 표정
	local head = self.parts.Head
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = head
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Texture = M.face
	face.Face = Enum.NormalId.Front
	face.Parent = head
	-- 눈꺼풀(깜빡임 - 기본 얼굴 눈 자리 위 피부색 판 · mascot.blink = true 동안 보임)
	self.lids = {}
	for i, x in ipairs(M.eyes.x) do
		local lid = Instance.new("Part")
		lid.Name = "Eyelid" .. i
		lid.Size = M.eyes.size
		lid.Anchored, lid.CanCollide, lid.CanQuery, lid.CanTouch, lid.CastShadow = true, false, false, false, false
		lid.Material = Enum.Material.SmoothPlastic
		lid.Color = M.colors.skin
		lid.Transparency = 1
		lid.Parent = model
		self.lids[i] = { part = lid, x = x }
	end
	-- 망토(따라오는 움직임 - 스프링) · 직업 색은 attachArmor 때
	local cape = Instance.new("Part")
	cape.Name = "Cape"
	cape.Size = M.cape.size
	cape.Anchored, cape.CanCollide, cape.CanQuery, cape.CanTouch, cape.CastShadow = true, false, false, false, false
	cape.Material = Enum.Material.Fabric
	cape.Color = M.colors.shirt
	cape.Transparency = 1
	cape.Parent = model
	self.cape = cape
	self.capeAngle, self.capeVel = 0, 0
	self.headLag, self.headVel = 0, 0
	self.lastRoot = nil
	model.Parent = parent
	self.pose = { root = CFrame.new(), joints = {}, squash = 0 }
	self:render(0)
	return self
end

function StageMascot:setPose(pose)
	self.pose = pose
end

-- 찌그러짐: 발바닥(루트 아래 FOOT_Y) 기준으로 위아래 1 − s · 옆 1 + s/2
local function squashOf(rootCF, s)
	if math.abs(s) < 1e-4 then
		return nil
	end
	local ground = rootCF * CFrame.new(0, StageMascot.FOOT_Y, 0)
	return ground, Vector3.new(1 + s * 0.5, 1 - s, 1 + s * 0.5)
end

local function squashCF(cf, ground, k)
	if not ground then
		return cf
	end
	local rel = ground:ToObjectSpace(cf)
	local p = rel.Position
	return ground * CFrame.new(p.X * k.X, p.Y * k.Y, p.Z * k.Z) * rel.Rotation
end

-- dt = 지난 프레임부터 초(따라오는 움직임 스프링)
function StageMascot:render(dt)
	local pose = self.pose
	local rootCF = pose.root or CFrame.new()
	local world = { HumanoidRootPart = rootCF * CFrame.new(self.rest.HumanoidRootPart.at) }
	-- 따라오는 움직임: 루트가 옆으로 기울거나 움직인 만큼 머리 · 망토가 반대로 늦게 따라온다(스프링)
	local S = Data.mascot.spring
	local tilt = 0
	if self.lastRoot and dt and dt > 0 then
		local rel = self.lastRoot:ToObjectSpace(rootCF)
		local _, _, rz = rel:ToOrientation()
		tilt = rz / dt + rel.Position.Y / dt * 0.15
	end
	self.lastRoot = rootCF
	if dt and dt > 0 then
		local acc = -S.stiffness * self.headLag - S.damping * self.headVel - tilt * S.drive
		self.headVel += acc * dt
		self.headLag = math.clamp(self.headLag + self.headVel * dt, -0.5, 0.5)
		local cacc = -S.capeStiffness * self.capeAngle - S.capeDamping * self.capeVel - tilt * S.capeDrive
		self.capeVel += cacc * dt
		self.capeAngle = math.clamp(self.capeAngle + self.capeVel * dt, -0.8, 0.8)
	end
	for _, spec in ipairs(PARTS) do
		local j = spec.joint and self.joints[spec.joint]
		if j then
			local rot = pose.joints and pose.joints[spec.joint] or CFrame.new()
			if spec.joint == "Neck" then
				rot = rot * CFrame.Angles(0, 0, self.headLag)
			end
			world[spec.name] = world[j.parent] * j.c0 * rot * j.c1:Inverse()
		end
	end
	local ground, k = squashOf(rootCF, pose.squash or 0)
	for name, cf in pairs(world) do
		local p = self.parts[name]
		p.CFrame = squashCF(cf, ground, k)
		p.Size = k and self.rest[name].size * k or self.rest[name].size
	end
	for _, lid in ipairs(self.lids) do
		lid.part.CFrame = squashCF(world.Head * CFrame.new(lid.x, Data.mascot.eyes.y, Data.mascot.eyes.z), ground, k)
		lid.part.Transparency = self.blink and 0 or 1
	end
	-- 망토: 윗몸통 등 위쪽 모서리에 걸려 늦게 따라 흔들린다
	local torso = world.UpperTorso
	local C = Data.mascot.cape
	local hang = torso * CFrame.new(0, 0.75, 0.55) * CFrame.Angles(C.restAngle + self.capeAngle * 0.6, 0, self.capeAngle) * CFrame.new(0, -C.size.Y / 2, 0)
	self.cape.CFrame = squashCF(hang, ground, k)
	-- 붙인 조각(방어구 · 무기): 몸 파트 자리 × localCF. 날아오는 중 = a.offset(세계 축 이동) · a.spin(몸 파트 기준 회전 - 무기는 손 기준이라 한 자루로 돈다)
	for _, a in ipairs(self.attached) do
		local body = world[a.body]
		if body and a.part.Parent then
			local spin = a.spin and a.spin ~= 0 and CFrame.Angles(a.spin * 0.35, a.spin, 0) or CFrame.new()
			local cf = CFrame.new(a.offset or Vector3.zero) * body * spin * a.localCF
			a.part.CFrame = squashCF(cf, ground, k)
			local scale = (a.pop or 1)
			a.part.Size = (k and a.baseSize * k or a.baseSize) * scale
			a.part.Transparency = a.hidden and 1 or a.baseTransparency -- (뷰포트에서는 LocalTransparencyModifier가 안 먹는다)
		end
	end
	return world
end

local function attach(self, part, body, localCF, tag)
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
	part.Parent = self.model
	local a = { part = part, body = body, localCF = localCF, baseSize = part.Size, baseTransparency = part.Transparency, tag = tag }
	table.insert(self.attached, a)
	return a
end

-- 방어구 v3(그 직업 · 기본 외형) - 조각 자리 = MeshMeta.armor_wear(offset · 회전 = 원본 메시 그대로 - 몸 파트가 refSize와 같은 크기)
function StageMascot:attachArmor(classId)
	local out = {}
	local F = ArtImportData.armorFit
	for _, part in ipairs(ARMOR_PARTS) do
		local key = ("%s_%s_%s"):format(part, classId, Data.armorLook)
		-- QUEUE-ALL9E1 1-1 장비 v3: 스위치 켬 + <부위>_<직업>_<단계>가 있으면 그것(게임 착용과 같은 색 · 문 부품 함수)
		local stageKey = ("%s_%s_%s"):format(part, classId, GearV3.data.stageOfGrade[Data.armorGrade] or "s1")
		local g3 = GearV3.enabled() and ArtMeshKit.get("armor/" .. stageKey) and Wear.pieces[stageKey] and true or false
		if g3 then
			key = stageKey
		end
		local src = ArtMeshKit.get("armor/" .. key)
		local meta = Wear.pieces[key]
		if src and meta then
			-- 1-1 "장갑이 손보다 큼": 손 · 발 묶음은 게임 착용과 같은 규칙(파트 × (1 + handFootPad))으로 줄인다 - 나머지는 무대 파트 = refSize라 자리표 그대로
			local groups = {}
			for _, piece in ipairs(src:GetChildren()) do
				local m = piece:IsA("BasePart") and meta[piece.Name]
				if m and self.parts[m.attach] and (not g3 or GearV3.visible(piece.Name, Data.armorGrade)) then
					groups[m.attach] = groups[m.attach] or {}
					table.insert(groups[m.attach], { piece = piece, m = m })
				end
			end
			for body, list in pairs(groups) do
				local s, mid = Vector3.one, Vector3.zero
				if F.handFootParts[body] then
					local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
					for _, g in ipairs(list) do
						local R, h = g.piece.CFrame.Rotation, g.piece.Size / 2
						local ext = Vector3.new(
							math.abs(R.RightVector.X) * h.X + math.abs(R.UpVector.X) * h.Y + math.abs(R.LookVector.X) * h.Z,
							math.abs(R.RightVector.Y) * h.X + math.abs(R.UpVector.Y) * h.Y + math.abs(R.LookVector.Y) * h.Z,
							math.abs(R.RightVector.Z) * h.X + math.abs(R.UpVector.Z) * h.Y + math.abs(R.LookVector.Z) * h.Z)
						local c = Vector3.new(g.m.offset[1], g.m.offset[2], g.m.offset[3])
						lo, hi = lo:Min(c - ext), hi:Max(c + ext)
					end
					local size, target = hi - lo, self.parts[body].Size * (1 + F.handFootPad)
					s = Vector3.new(math.min(1, target.X / math.max(size.X, 1e-3)), math.min(1, target.Y / math.max(size.Y, 1e-3)), math.min(1, target.Z / math.max(size.Z, 1e-3)))
					mid = (lo + hi) / 2
				end
				for _, g in ipairs(list) do
					local piece, m = g.piece, g.m
					local R = piece.CFrame.Rotation
					local p = piece:Clone()
					p.Size = piece.Size * Vector3.new(
						math.abs(R.RightVector.X) * s.X + math.abs(R.RightVector.Y) * s.Y + math.abs(R.RightVector.Z) * s.Z,
						math.abs(R.UpVector.X) * s.X + math.abs(R.UpVector.Y) * s.Y + math.abs(R.UpVector.Z) * s.Z,
						math.abs(R.LookVector.X) * s.X + math.abs(R.LookVector.Y) * s.Y + math.abs(R.LookVector.Z) * s.Z)
					local color, neon = (g3 and GearV3.armorColor or ArmorColors.colorOfV3)(piece.Name, Data.armorZone, Data.armorGrade, classId)
					p.Color = color
					p.Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
					local off = Vector3.new(m.offset[1], m.offset[2], m.offset[3])
					local at = mid + (off - mid) * s
					local a = attach(self, p, m.attach, CFrame.new(at) * R, "armor")
					a.group = m.attach
					table.insert(out, a)
				end
			end
		end
	end
	local capeColor = Data.capeColors[classId]
	self.cape.Color = capeColor or Data.mascot.colors.shirt
	self.cape.Transparency = capeColor and 0 or 1
	return out
end

-- 무기(그 직업 · 기본 외형) - 손잡이(원점 · Grip 부착점) → 손바닥(WeaponRigSpec.palm) · 쥐는 방향 hold. 쌍검 = 같은 칼을 양손에.
function StageMascot:attachWeapon(classId)
	local out = {}
	local rig = WeaponRigSpec.weapons[classId]
	if not rig then
		return out
	end
	for _, spec in ipairs(rig.pieces) do
		local model = ArtMeshKit.weaponModel(classId, "normal", { keepDropParts = true }) -- 1-1 "활 시위 없음": 무대엔 시위를 그리는 코드(WeaponVisual)가 없어 메시 시위를 남긴다
		if model then
			local grip = Vector3.zero
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("Attachment") and d.Name == "Grip" then
					grip = d.WorldPosition
				end
			end
			local palm = WeaponRigSpec.palm[spec.hand] or Vector3.zero
			local handCF = CFrame.new(palm) * (spec.hold or CFrame.new()) * CFrame.new(-grip)
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then
					local rel = d.CFrame
					d.Parent = nil
					local a = attach(self, d, spec.hand, handCF * rel, "weapon")
					a.hand = spec.hand
					table.insert(out, a)
				end
			end
			model:Destroy()
		end
	end
	return out
end

function StageMascot:clearGear()
	for _, a in ipairs(self.attached) do
		a.part:Destroy()
	end
	self.attached = {}
	self.cape.Transparency = 1
end

function StageMascot:destroy()
	self.model:Destroy()
end

return StageMascot
