-- A1 기술 검증 시제품(Studio 개발 전용 - DevTools `/gg a1 …`). 게임 로직과 무관 · 완성 에셋 아님. 판정 목적:
--   ① 이끼 슬라임(파트 + Motor6D Root · Top) ② 구간 수호자 리그(파트 + Motor6D · "달려와 낚아채기" 키프레임을 Motor6D.Transform으로)
--   ③ 전갈 꼬리 Bone 8마디 + 부착점 A · B · C에 3명 매달기(RigidConstraint - Bone = Attachment) ④ 대검 7등급 누적 표현 ⑤ 카툰 풀 소품(잔디 B안)
-- 치수 · 색 = shared/data/A1PrototypeData · 등급 색 = ItemVisualData(기존 값 우선).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local P = require(ReplicatedStorage.Shared.data.A1PrototypeData)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local CartoonStyleData = require(ReplicatedStorage.Shared.data.CartoonStyleData)

local A1Prototypes = {}

local function folder()
	local f = workspace:FindFirstChild("A1Proto")
	if not f then
		f = Instance.new("Folder")
		f.Name = "A1Proto"
		f.Parent = workspace
	end
	return f
end

local function part(parent, name, size, cf, color, opts)
	opts = opts or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = opts.shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = opts.material or Enum.Material.SmoothPlastic
	p.Anchored = opts.anchored ~= false
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = opts.shadow ~= false
	p.Transparency = opts.transparency or 0
	if opts.mesh then
		local m = Instance.new("SpecialMesh")
		m.MeshType = opts.mesh
		m.Scale = opts.meshScale or Vector3.one
		m.Parent = p
	end
	p.Parent = parent
	return p
end

local function motor(name, part0, part1)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = part0.CFrame:ToObjectSpace(part1.CFrame)
	m.C1 = CFrame.identity
	m.Parent = part0
	return m
end

-- ① 이끼 슬라임
function A1Prototypes.mossSlime(origin)
	local S = P.mossSlime
	local model = Instance.new("Model")
	model.Name = "A1_MossSlime"
	local root = part(model, "HumanoidRootPart", Vector3.new(1, 1, 1), origin * CFrame.new(0, 0.5, 0), S.body, { transparency = 1, shadow = false })
	local bottom = part(model, "Bottom", Vector3.one, origin * CFrame.new(0, S.height * 0.3, 0), S.bodyShade,
		{ anchored = false, mesh = Enum.MeshType.Sphere, meshScale = Vector3.new(S.width, S.height * 0.6, S.width) })
	local top = part(model, "Top", Vector3.one, origin * CFrame.new(0, S.height * 0.55, 0), S.body,
		{ anchored = false, mesh = Enum.MeshType.Sphere, meshScale = Vector3.new(S.width * 0.92, S.height * 0.85, S.width * 0.92) })
	motor("Root", root, bottom)
	motor("Top", bottom, top)
	for i, off in ipairs({ Vector3.new(-0.5, 0.95, 0.2), Vector3.new(0.45, 1.05, -0.1), Vector3.new(0, 1.2, -0.45) }) do
		local cap = part(model, "Moss" .. i, Vector3.one, top.CFrame * CFrame.new(off), S.moss, { anchored = false, mesh = Enum.MeshType.Sphere, meshScale = Vector3.new(1.2, 0.45, 1.0) })
		motor("Moss" .. i, top, cap)
	end
	for _, x in ipairs({ -0.55, 0.55 }) do
		local eye = part(model, "Eye", Vector3.one, top.CFrame * CFrame.new(x, 0.15, -1.3), S.eye, { anchored = false, mesh = Enum.MeshType.Sphere, meshScale = Vector3.new(0.45, 0.6, 0.3) })
		motor("Eye", top, eye)
		local shine = part(model, "EyeShine", Vector3.one, top.CFrame * CFrame.new(x + 0.08, 0.3, -1.42), S.eyeShine, { anchored = false, shadow = false, mesh = Enum.MeshType.Sphere, meshScale = Vector3.new(0.15, 0.18, 0.1) })
		motor("EyeShine", top, shine)
	end
	model.PrimaryPart = root
	model.Parent = folder()
	return model
end

-- 전조 "납작 찌부": Motor6D는 크기를 못 바꾼다 → 메시 Scale을 직접(= 리그 밖 표현 · 판정 보고)
function A1Prototypes.slimeSquash(model, amount)
	local S = P.mossSlime
	for _, name in ipairs({ "Bottom", "Top" }) do
		local p = model:FindFirstChild(name)
		local mesh = p and p:FindFirstChildOfClass("SpecialMesh")
		if mesh then
			local base = name == "Bottom" and Vector3.new(S.width, S.height * 0.6, S.width) or Vector3.new(S.width * 0.92, S.height * 0.85, S.width * 0.92)
			local k = 1 + (S.squash.downScaleXZ - 1) * amount
			mesh.Scale = Vector3.new(base.X * k, base.Y * (1 + (S.squash.downScaleY - 1) * amount), base.Z * k)
		end
	end
	local top = model:FindFirstChild("Bottom") and model.Bottom:FindFirstChild("Top")
	if top then
		top.Transform = CFrame.new(0, -S.height * 0.25 * amount, 0)
	end
end

-- ② 구간 수호자 리그
function A1Prototypes.guardian(origin)
	local G = P.guardian
	local model = Instance.new("Model")
	model.Name = "A1_GuardianRig"
	local root = part(model, "HumanoidRootPart", Vector3.new(2, 2, 1), origin * CFrame.new(0, 7, 0), G.body, { transparency = 1, shadow = false })
	local torso = part(model, "Torso", Vector3.new(7, 7, 4.5), origin * CFrame.new(0, 9.5, 0), G.body, { anchored = false })
	local head = part(model, "Head", Vector3.new(4.5, 3.8, 4), origin * CFrame.new(0, 14.9, -0.3), G.stone, { anchored = false })
	local eyeBar = part(model, "Eyes", Vector3.new(3, 0.6, 0.3), head.CFrame * CFrame.new(0, 0.2, -2.05), G.eye, { anchored = false, material = Enum.Material.Neon })
	local rune = part(model, "Rune", Vector3.new(2, 2, 0.3), torso.CFrame * CFrame.new(0, 0.5, -2.3), G.rune, { anchored = false, material = Enum.Material.Neon })
	local function arm(side, x)
		local shoulder = part(model, "Shoulder_" .. side, Vector3.new(3, 5.5, 3), origin * CFrame.new(x, 10.2, 0), G.stone, { anchored = false })
		local hand = part(model, "Hand_" .. side, Vector3.new(3.6, 3.6, 3.6), origin * CFrame.new(x, 6.4, 0), G.stone, { anchored = false })
		local s = motor("Shoulder_" .. side, torso, shoulder)
		s.C1 = CFrame.new(0, 2.2, 0) -- 어깨 축 = 팔 위쪽
		s.C0 = torso.CFrame:ToObjectSpace(origin * CFrame.new(x, 12.4, 0))
		local w = motor("Hand_" .. side, shoulder, hand)
		w.C0 = CFrame.new(0, -2.6, 0)
		w.C1 = CFrame.new(0, 1.2, 0)
		return shoulder, hand
	end
	arm("R", 5.3)
	arm("L", -5.3)
	for _, x in ipairs({ -1.9, 1.9 }) do
		local leg = part(model, x < 0 and "Leg_L" or "Leg_R", Vector3.new(2.8, 6, 3), origin * CFrame.new(x, 3, 0), G.body, { anchored = false })
		motor(x < 0 and "Hip_L" or "Hip_R", torso, leg)
	end
	motor("RootJoint", root, torso)
	motor("Neck", torso, head)
	motor("Eyes", head, eyeBar)
	motor("Rune", torso, rune)
	model.PrimaryPart = root
	model.Parent = folder()
	return model
end

-- 키프레임 k(1 ~ n 사이 실수)의 자세를 Motor6D.Transform으로(애니메이션 채널과 같은 자리 - 업로드 애니메이션도 이 관절 이름을 쓴다).
-- ★ Transform은 복제되지 않는다(애니메이션처럼 각 클라가 그린다) - 서버에서 부르면 서버 물리만 바뀐다. 화면 확인은 클라에서 같은 식으로(A1 보고서).
function A1Prototypes.guardianPose(model, k)
	local keys = P.guardian.grabKeys
	local i = math.clamp(math.floor(k), 1, #keys)
	local j = math.min(i + 1, #keys)
	local f = k - i
	local function lerp(field)
		return keys[i][field] + (keys[j][field] - keys[i][field]) * f
	end
	local torso = model.Torso
	local root = model.HumanoidRootPart
	root.RootJoint.Transform = CFrame.new(0, -lerp("crouch"), -lerp("reach")) * CFrame.Angles(math.rad(-lerp("rootLean")), 0, 0)
	-- 부호: 리그 앞 = 로컬 −Z. 아래로 늘어진 팔을 X축으로 +θ 돌리면 앞으로 든다(A1 실측) → 데이터의 "앞으로 든 각"(음수)을 뒤집어 넣는다
	torso.Shoulder_R.Transform = CFrame.Angles(math.rad(-lerp("shoulderR")), 0, 0)
	model.Shoulder_R.Hand_R.Transform = CFrame.Angles(math.rad(lerp("elbowR")), 0, 0)
	torso.Shoulder_L.Transform = CFrame.Angles(math.rad(-lerp("shoulderL")), 0, 0)
	return keys[i].name
end

-- ③ 전갈 꼬리(Bone 체인) + 부착점 A · B · C
function A1Prototypes.scorpionTail(origin)
	local T = P.scorpionTail
	local model = Instance.new("Model")
	model.Name = "A1_ScorpionTail"
	local body = part(model, "Body", Vector3.new(5, 2.4, 7), origin * CFrame.new(0, 1.4, 0), T.body)
	local parent = body
	local bones = {}
	for i = 1, T.segments do
		local bone = Instance.new("Bone")
		bone.Name = "Tail" .. i
		bone.CFrame = i == 1 and CFrame.new(0, 0.8, 3.5) or CFrame.new(0, 0, T.segmentLength)
		bone.Parent = parent
		bones[i] = bone
		parent = bone
		-- 보이는 마디 = 뼈에 RigidConstraint로 붙은 파트(스킨드 메시 없이 원리 검증)
		local seg = part(model, "Segment" .. i, Vector3.new(T.segmentWidth * (1 - i * 0.05), T.segmentWidth * 0.8, T.segmentLength * 0.9), body.CFrame, i == T.segments and T.sting or T.body, { anchored = false })
		local a = Instance.new("Attachment")
		a.Name = "SegAttach"
		a.CFrame = CFrame.new(0, 0, -T.segmentLength * 0.45)
		a.Parent = seg
		local rc = Instance.new("RigidConstraint")
		rc.Attachment0 = bone
		rc.Attachment1 = a
		rc.Parent = seg
	end
	local holders = {}
	local order = { "A", "B", "C" }
	for n, key in ipairs(order) do
		local bone = bones[T.attach[key]]
		local dummy = part(model, "Held_" .. key, Vector3.new(2, 4, 1), body.CFrame, T.holdColors[n], { anchored = false })
		local a = Instance.new("Attachment")
		a.CFrame = CFrame.new(0, 2.4, 0)
		a.Parent = dummy
		local grip = Instance.new("Attachment")
		grip.Name = "Grip_" .. key
		grip.CFrame = CFrame.new(n == 2 and 1.6 or -1.6, 0, 0)
		grip.Parent = bone
		local rc = Instance.new("RigidConstraint")
		rc.Attachment0 = grip
		rc.Attachment1 = a
		rc.Parent = dummy
		holders[key] = dummy
	end
	model.PrimaryPart = body
	model.Parent = folder()
	return model, bones, holders
end

function A1Prototypes.tailCurl(model, amount)
	local T = P.scorpionTail
	local body = model.Body
	local bone = body:FindFirstChild("Tail1")
	local i = 1
	while bone do
		local base = i == 1 and CFrame.new(0, 0.8, 3.5) or CFrame.new(0, 0, T.segmentLength)
		bone.CFrame = base * CFrame.Angles(math.rad(T.curlDegPerBone * amount), 0, 0)
		i += 1
		bone = bone:FindFirstChild("Tail" .. i)
	end
end

-- ④ 대검 7등급(누적 층 = CartoonStyleData.rarity.layers)
local function sword(parent, origin, gradeId)
	local W = P.greatsword
	local grade = ItemVisualData.gradeVisuals[gradeId]
	local gc = grade.color
	local layers = {}
	for _, l in ipairs(CartoonStyleData.rarity.layers[gradeId]) do
		layers[l] = true
	end
	local model = Instance.new("Model")
	model.Name = "A1_Sword_" .. gradeId
	local steel = layers.whiteBody and W.whiteAura or W.steel
	local bladeLen = W.length - W.gripLength
	part(model, "Blade", Vector3.new(W.bladeWidth, bladeLen - 0.8, W.bladeThick), origin * CFrame.new(0, W.gripLength + (bladeLen - 0.8) / 2, 0), steel)
	local tip = part(model, "Tip", Vector3.new(W.bladeThick, 0.8, W.bladeWidth), origin * CFrame.new(0, W.gripLength + bladeLen - 0.4, 0) * CFrame.Angles(0, math.rad(90), 0), steel)
	tip.Shape = Enum.PartType.Wedge
	part(model, "Guard", Vector3.new(W.guardWidth, 0.35, 0.5), origin * CFrame.new(0, W.gripLength, 0), W.steelShade)
	part(model, "Grip", Vector3.new(0.3, W.gripLength, 0.3), origin * CFrame.new(0, W.gripLength / 2, 0), W.grip)
	part(model, "Pommel", Vector3.one * 0.5, origin * CFrame.new(0, -0.1, 0), W.steelShade, { shape = Enum.PartType.Ball })
	if layers.rim then -- 날 · 손잡이 색 테두리
		for _, x in ipairs({ -1, 1 }) do
			part(model, "Rim", Vector3.new(0.12, bladeLen - 0.9, W.bladeThick + 0.04), origin * CFrame.new(x * (W.bladeWidth / 2 + 0.03), W.gripLength + (bladeLen - 0.8) / 2, 0), gc)
		end
		part(model, "GripWrap", Vector3.new(0.34, 0.25, 0.34), origin * CFrame.new(0, W.gripLength * 0.5, 0), gc)
	end
	if layers.gem then
		part(model, "Gem", Vector3.one * 0.45, origin * CFrame.new(0, W.gripLength, -0.3), layers.whiteBody and gc or gc, { shape = Enum.PartType.Ball, material = Enum.Material.Neon })
	end
	if layers.wings then
		for _, x in ipairs({ -1, 1 }) do
			local w = part(model, "Wing", Vector3.new(0.2, 0.7, 0.9), origin * CFrame.new(x * (W.guardWidth / 2 + 0.3), W.gripLength + 0.25, 0) * CFrame.Angles(0, 0, math.rad(x * -35)), gc)
			w.Shape = Enum.PartType.Wedge
		end
	end
	if layers.glow then
		local light = Instance.new("PointLight")
		light.Color = gc
		light.Range = 6
		light.Brightness = 1.5
		light.Parent = model:FindFirstChild("Blade")
	end
	if layers.shards then -- 주변을 도는 조각 6(정지 사진 = 고리 위치)
		for i = 1, CartoonStyleData.rarity.shardCount do
			local a = (i / CartoonStyleData.rarity.shardCount) * math.pi * 2
			part(model, "Shard", Vector3.new(0.25, 0.45, 0.25), origin * CFrame.new(math.cos(a) * 1.3, W.gripLength + bladeLen * 0.55 + math.sin(a * 2) * 0.2, math.sin(a) * 1.3) * CFrame.Angles(0, a, math.rad(20)), gc, { material = Enum.Material.Neon, shadow = false })
		end
	end
	if layers.ring then -- 점선 빛 고리
		for i = 1, 14 do
			local a = (i / 14) * math.pi * 2
			part(model, "RingDot", Vector3.one * 0.18, origin * CFrame.new(math.cos(a) * 1.7, W.gripLength + 0.4, math.sin(a) * 1.7), gc, { shape = Enum.PartType.Ball, material = Enum.Material.Neon, shadow = false })
		end
	end
	if layers.whiteAura then
		part(model, "WhiteAura", Vector3.new(W.length + 1.2, 2.6, 2.6), origin * CFrame.new(0, W.length / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), W.whiteAura,
			{ shape = Enum.PartType.Cylinder, material = Enum.Material.ForceField, transparency = 0.2, shadow = false })
		part(model, "LightRay", Vector3.new(0.2, 9, 0.2), origin * CFrame.new(0, W.length + 3, 0), W.whiteAura, { material = Enum.Material.Neon, transparency = 0.35, shadow = false })
	end
	model.Parent = parent
	return model
end

function A1Prototypes.swordRow(origin)
	local row = Instance.new("Model")
	row.Name = "A1_SwordRow"
	for i, gradeId in ipairs(CartoonStyleData.rarity.order) do
		sword(row, origin * CFrame.new((i - 4) * P.greatsword.spacing, 0, 0), gradeId)
	end
	row.Parent = folder()
	return row
end

-- ⑤ 카툰 풀 소품(잔디 B안): 쐐기 3잎 덩어리를 원 안에 격자로(지면 레이캐스트)
function A1Prototypes.grassField(center)
	local Gc = P.grassClump
	local model = Instance.new("Model")
	model.Name = "A1_CartoonGrass"
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local rng = Random.new(3)
	local n = 0
	for x = -Gc.radius, Gc.radius, Gc.spacing do
		for z = -Gc.radius, Gc.radius, Gc.spacing do
			if x * x + z * z <= Gc.radius * Gc.radius then
				local px, pz = center.X + x + rng:NextNumber(-1, 1), center.Z + z + rng:NextNumber(-1, 1)
				local hit = workspace:Raycast(Vector3.new(px, center.Y + 200, pz), Vector3.new(0, -400, 0), params)
				if hit then
					for b = 1, Gc.blades do
						local yaw = rng:NextNumber(0, 360)
						local h = Gc.height * rng:NextNumber(0.75, 1.2)
						local w = part(model, "Blade", Vector3.new(0.12, h, Gc.width), CFrame.new(hit.Position + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, math.rad(yaw + b * 120), math.rad(rng:NextNumber(-12, 12))), b == 1 and Gc.tip or Gc.color, { shadow = false })
						w.Shape = Enum.PartType.Wedge
					end
					n += 1
				end
			end
		end
	end
	model.Parent = folder()
	return model, n
end

function A1Prototypes.clear()
	local f = workspace:FindFirstChild("A1Proto")
	if f then
		f:Destroy()
	end
end

return A1Prototypes
