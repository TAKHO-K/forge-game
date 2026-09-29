-- A2-S 아트 샘플 조립(겉모습만 - 판정 없음). 치수 · 색 = shared/data/ArtStyleV1Data. 파트 이름 = 리그 이름(Blender 메시로 1:1 교체할 자리 - docs/art/art-direction-v1.md §7).
--   greatsword(lookName, gradeColor) → Model(무기 로컬 축: +Z 칼끝 · +X 날 폭 · WorldPivot = 원점 · 부착점 Grip · Tip · Support = WeaponRigSpec · PrimaryPart = Blade)
--   forge() → Model(로컬: 바닥 y 0 · −Z = 앞) - 호출하는 쪽이 PivotTo로 놓는다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArtStyleV1Data = require(ReplicatedStorage.Shared.data.ArtStyleV1Data)
local WeaponRigSpec = require(ReplicatedStorage.Shared.data.WeaponRigSpec)

local ArtV1Models = {}

local X, Y, Z = Vector3.xAxis, Vector3.yAxis, Vector3.zAxis

local function newPart(model, name, size, color, cf, shape, neon)
	local part
	if shape == "wedge" then
		part = Instance.new("WedgePart")
	else
		part = Instance.new("Part")
		if shape == "ball" then
			part.Shape = Enum.PartType.Ball
		elseif shape == "cylinder" then
			part.Shape = Enum.PartType.Cylinder
		end
	end
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
	part.CFrame = cf
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = model
	return part
end

local function attach(host, name, worldPos)
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = host.CFrame:PointToObjectSpace(worldPos)
	a.Parent = host
	return a
end

function ArtV1Models.greatsword(lookName, gradeColor)
	local D = ArtStyleV1Data.greatsword
	local look = D.looks[lookName] or D.looks.normal
	local function col(c)
		return c == "grade" and gradeColor or c
	end
	local model = Instance.new("Model")
	model.Name = "ArtV1Greatsword_" .. lookName
	local b = D.blade
	local bladeLen = b.toZ - b.fromZ
	local blade = newPart(model, "Blade", Vector3.new(b.width, b.thick, bladeLen), look.steel, CFrame.new(0, 0, (b.fromZ + b.toZ) / 2))
	-- 칼끝 = 쐐기 두 장(오른 · 왼 반쪽): 쐐기 로컬 Y(높이) → ±X, 로컬 +Z(높은 쪽) → 칼 밑 쪽(−Z)
	local tipZ = b.toZ + b.tipLength / 2
	newPart(model, "Tip_R", Vector3.new(b.thick, b.width / 2, b.tipLength), look.steel, CFrame.fromMatrix(Vector3.new(b.width / 4, 0, tipZ), Y, X), "wedge")
	newPart(model, "Tip_L", Vector3.new(b.thick, b.width / 2, b.tipLength), look.steelShade, CFrame.fromMatrix(Vector3.new(-b.width / 4, 0, tipZ), -Y, -X), "wedge")
	local f = D.fuller
	newPart(model, "Fuller", Vector3.new(f.width, f.thick, f.toZ - f.fromZ), col(look.fuller), CFrame.new(0, 0, (f.fromZ + f.toZ) / 2), nil, look.fullerNeon)
	newPart(model, "Guard", D.guard.size, col(look.guard), CFrame.new(0, 0, D.guard.z))
	newPart(model, "Grip", Vector3.new(D.grip.length, D.grip.width, D.grip.width), look.grip, CFrame.new(0, 0, D.grip.centerZ) * CFrame.Angles(0, math.pi / 2, 0), "cylinder")
	newPart(model, "Pommel", Vector3.one * D.pommel, col(look.pommel), CFrame.new(0, 0, D.pommelZ), "ball")
	if look.wings then
		local w = D.wing
		local wz = D.guard.z + D.guard.size.Z / 2 + w.size.Y / 2 - 0.1
		-- 쐐기 로컬 Y → +Z(칼끝 쪽으로 솟음) · 로컬 +Z(높은 쪽) → 바깥(±X)
		newPart(model, "Wing_R", w.size, col(look.guard), CFrame.fromMatrix(Vector3.new(w.x, 0, wz), Y, Z), "wedge")
		newPart(model, "Wing_L", w.size, col(look.guard), CFrame.fromMatrix(Vector3.new(-w.x, 0, wz), -Y, Z), "wedge")
	end
	if look.gem then
		newPart(model, "Gem", Vector3.new(D.gem, D.gem * 1.2, D.gem), look.gem, CFrame.new(0, 0, D.guard.z), "ball", look.gemNeon)
	end
	if look.cracks then
		for i, c in ipairs(D.crack.at) do
			newPart(model, "Crack" .. i, D.crack.size, look.cracks, CFrame.new(c.x, 0, c.z) * CFrame.Angles(0, math.rad(c.ry), 0), nil, true)
		end
	end
	if look.light then
		local light = Instance.new("PointLight")
		light.Name = "ArtV1Glow"
		light.Range, light.Brightness = look.light.range, look.light.brightness
		light.Color = look.light.color or gradeColor
		light.Parent = blade
	end
	if look.sparks then
		local s = look.sparks
		local e = Instance.new("ParticleEmitter")
		e.Name = "ArtV1Sparks"
		e.Rate = s.rate
		e.Lifetime = NumberRange.new(s.lifetime * 0.6, s.lifetime)
		e.Speed = NumberRange.new(s.speed * 0.5, s.speed)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, s.size), NumberSequenceKeypoint.new(1, 0) })
		e.Color = ColorSequence.new(s.color)
		e.LightEmission = 1
		e.Transparency = NumberSequence.new(0.1)
		e.Parent = blade
	end
	local A = WeaponRigSpec.attachments
	attach(blade, A.grip, Vector3.new(0, 0, D.gripZ))
	attach(blade, A.tip, Vector3.new(0, 0, b.toZ + b.tipLength))
	attach(blade, A.support, Vector3.new(0, 0, D.supportZ))
	model:SetAttribute("TrailTop", D.trail.top)
	model:SetAttribute("TrailBottom", D.trail.bottom)
	model.PrimaryPart = blade
	model.WorldPivot = CFrame.identity
	return model
end

function ArtV1Models.forge()
	local D = ArtStyleV1Data.forge
	local model = Instance.new("Model")
	model.Name = "ArtV1Forge"
	local function P(name, size, color, pos, shape, neon, rot)
		return newPart(model, name, size, color, CFrame.new(pos) * (rot or CFrame.identity), shape, neon)
	end
	local upright = CFrame.Angles(0, 0, math.pi / 2) -- 원기둥(축 X)을 세운다
	-- 그루터기 받침 + 모루(발 · 허리 · 얼굴 · 윗면 밝은 판 · 뿔)
	P("Stump", Vector3.new(1.7, 3.3, 3.3), D.wood, Vector3.new(0, 0.85, 0), "cylinder", false, upright)
	P("StumpTop", Vector3.new(0.18, 3.5, 3.5), D.woodTop, Vector3.new(0, 1.78, 0), "cylinder", false, upright)
	P("AnvilFoot", Vector3.new(1.9, 0.6, 1.4), D.ironShade, Vector3.new(0, 2.15, 0))
	P("AnvilWaist", Vector3.new(1.0, 0.7, 0.85), D.iron, Vector3.new(0, 2.8, 0))
	P("AnvilFace", Vector3.new(3.0, 0.72, 1.5), D.iron, Vector3.new(0.2, 3.5, 0))
	P("AnvilTopShine", Vector3.new(3.0, 0.08, 1.5), D.ironTop, Vector3.new(0.2, 3.9, 0))
	-- 뿔: 쐐기를 뒤집어(평평한 윗면 · 아래로 깎임) −X로 뾰족하게
	newPart(model, "AnvilHorn", Vector3.new(1.5, 0.72, 1.2), D.iron, CFrame.fromMatrix(Vector3.new(-1.9, 3.5, 0), Z, -Y), "wedge")
	P("HotIngot", Vector3.new(0.9, 0.22, 0.5), D.ingot, Vector3.new(0.5, 4.05, 0), nil, true)
	-- 기대 놓은 망치
	P("HammerHandle", Vector3.new(0.2, 1.8, 0.2), D.wood, Vector3.new(2.05, 2.6, -0.4), nil, false, CFrame.Angles(0, 0, math.rad(-18)))
	P("HammerHead", Vector3.new(0.9, 0.5, 0.5), D.ironShade, Vector3.new(2.35, 3.45, -0.4), nil, false, CFrame.Angles(0, 0, math.rad(-18)))
	-- 뒤쪽 화덕 + 굴뚝(멀리서 보이는 세로 실루엣) · 화덕 입 = 불빛
	P("Hearth", Vector3.new(3.2, 2.4, 2.4), D.stone, Vector3.new(0, 1.2, 3.4))
	P("HearthTop", Vector3.new(3.4, 0.35, 2.6), D.stoneShade, Vector3.new(0, 2.55, 3.4))
	local mouth = P("HearthMouth", Vector3.new(1.7, 0.9, 0.12), D.ember, Vector3.new(0, 1.05, 2.18), nil, true)
	local chimney = P("Chimney", Vector3.new(1.3, 6.2, 1.3), D.stoneShade, Vector3.new(0.6, 5.8, 3.7))
	P("ChimneyCap", Vector3.new(1.8, 0.4, 1.8), D.ironShade, Vector3.new(0.6, 9.1, 3.7))
	P("ChimneyGlow", Vector3.new(1.0, 0.2, 1.0), D.ember, Vector3.new(0.6, 9.35, 3.7), nil, true) -- 멀리서 보이는 불빛(굴뚝 꼭대기)
	-- 표지판: 세로 기둥 + 판 + 노랑 망치 문양(상호작용 = 노랑 · 글자 없음)
	P("SignPole", Vector3.new(0.35, 7.2, 0.35), D.wood, Vector3.new(-2.9, 3.6, 1.2))
	P("SignBoard", Vector3.new(2.4, 1.7, 0.25), D.signBoard, Vector3.new(-2.9, 6.2, 1.0))
	P("EmblemHandle", Vector3.new(0.22, 1.1, 0.1), D.sign, Vector3.new(-2.9, 6.05, 0.83), nil, true, CFrame.Angles(0, 0, math.rad(-35)))
	P("EmblemHead", Vector3.new(0.95, 0.42, 0.1), D.sign, Vector3.new(-2.62, 6.5, 0.83), nil, true, CFrame.Angles(0, 0, math.rad(-35)))
	local light = Instance.new("PointLight")
	light.Name = "ForgeGlow"
	light.Range, light.Brightness, light.Color = D.light.range, D.light.brightness, D.light.color
	light.Parent = mouth
	local capAttach = Instance.new("Attachment")
	capAttach.Name = "ChimneyTop"
	capAttach.Position = Vector3.new(0, 3.4, 0)
	capAttach.Parent = chimney
	local e = Instance.new("ParticleEmitter")
	e.Name = "Embers"
	e.Rate = D.embers.rate
	e.Lifetime = NumberRange.new(D.embers.lifetime * 0.6, D.embers.lifetime)
	e.Speed = NumberRange.new(D.embers.speed * 0.6, D.embers.speed)
	e.SpreadAngle = Vector2.new(15, 15)
	e.EmissionDirection = Enum.NormalId.Top
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, D.embers.size), NumberSequenceKeypoint.new(1, 0) })
	e.Color = ColorSequence.new(D.embers.color)
	e.LightEmission = 1
	e.Parent = capAttach
	model.WorldPivot = CFrame.identity -- PrimaryPart를 두지 않는다(세운 원기둥 Stump를 PrimaryPart로 두면 PivotTo가 그 회전을 따라 모델 전체가 90° 눕는다 - Play 실측)
	return model
end

return ArtV1Models
