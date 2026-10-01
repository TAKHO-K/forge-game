-- MV1 활강 모습(그리기만 - 판정 없음): 머리 위 카툰 나뭇잎 글라이더(잎 1장 + 줄기 - 파트 2개 · 새 에셋 없음) + 앞으로 눕는 자세(AirMotion.hold).
--   자기 캐릭터 = GlideController가 켜는 순간 바로 부른다 · 남의 캐릭터 = 서버가 켜 둔 Character Attribute "Gliding"을 보고 부른다(GlideController가 감시).
--   치장 슬롯 gliderSkin(CosmeticSlotData) 자리 = 이 모듈 하나(스킨을 바꾸면 여기서 모양만 고른다).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunService = game:GetService("RunService")

local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)
local CosmeticSlotData = require(ReplicatedStorage.Shared.data.CosmeticSlotData)
local CosData = require(ReplicatedStorage.Shared.data.ArtV1CosmeticData)
local ArtMeshKit = require(ReplicatedStorage.Shared.ArtMeshKit)
local AirMotion = require(script.Parent.AirMotion)

local GlideView = {}
local LOOK = MovementConfig.glide.look

local function part(name, size, color, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = false, false, false, false, true
	p.Parent = parent
	return p
end

local function weld(a, b, c0)
	local w = Instance.new("Weld")
	w.Part0, w.Part1, w.C0 = a, b, c0
	w.Parent = b
end

-- QUEUE-ALL1 P6: 장착한 글라이더 스킨의 look(CosmeticSlotData.gliderSkins) → 모양 메시(없거나 아트 꺼짐 = nil = 기본 잎)
local function skinLook(character)
	local player = Players:GetPlayerFromCharacter(character)
	local skinId = player and player:GetAttribute("Cosmetic_gliderSkin")
	for _, s in ipairs(CosmeticSlotData.gliderSkins) do
		if s.id == skinId and s.look ~= "" and CosData.gliders[s.look] then
			local spec = CosData.gliders[s.look]
			if spec.procedural then -- QUEUE-ALL6 H 파트로 짓는 모양(메시 없음)
				return s.look, spec, nil
			end
			local src = ArtMeshKit.get(spec.mesh)
			return src and s.look or nil, spec, src
		end
	end
	return nil
end

local function loosePart(p, parent)
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = false, false, false, false, false, true
	p.Parent = parent
end

-- 드래곤 날개: 몸 뒤 양쪽에 날개 메시(관절 = 메시 원점) · C0 롤을 사인으로 흔든다
local function buildWings(model, root, spec, src)
	local welds = {}
	for i, name in ipairs(spec.parts) do
		local w = src:FindFirstChild(name, true)
		if w and w:IsA("BasePart") then
			local c = w:Clone()
			local k = spec.wingLength / math.max(c.Size.X, c.Size.Z, 0.01)
			local pivot = c.PivotOffset
			c.Size *= k
			c.Color = spec.color or c.Color -- 캐시 메시는 회색(몬스터 색은 리그가 입힌다) → T6 드래곤 파랑
			loosePart(c, model)
			local sx = i == 1 and -1 or 1
			local weldObj = Instance.new("Weld")
			weldObj.Part0, weldObj.Part1 = root, c
			weldObj.C0 = CFrame.new(sx * spec.side, spec.up, spec.back) * w.CFrame.Rotation
			weldObj.C1 = CFrame.new(pivot.Position * k) * pivot.Rotation
			weldObj.Parent = c
			table.insert(welds, { weld = weldObj, base = weldObj.C0, sx = sx })
		end
	end
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not model.Parent then
			conn:Disconnect()
			return
		end
		local a = math.rad(spec.flapDeg) * math.sin((os.clock() - t0) * spec.flapHz * math.pi * 2)
		for _, e in ipairs(welds) do
			e.weld.C0 = e.base * CFrame.Angles(0, 0, e.sx * a)
		end
	end)
end

-- 구름 고래: 캐릭터 밑에 타는 고래(모델째 · 루트에 용접) + 위아래 살랑 + 꼬리 물보라 입자
local function buildWhale(model, root, spec, src)
	local whale = src:Clone()
	whale.Name = "CloudWhale"
	whale:ScaleTo(spec.scale)
	whale:PivotTo(root.CFrame * CFrame.new(spec.offset[1], spec.offset[2], spec.offset[3]))
	local anchor = Instance.new("Part")
	anchor.Name = "WhaleAnchor"
	anchor.Size = Vector3.one * 0.2
	anchor.Transparency = 1
	anchor.CFrame = whale:GetPivot()
	loosePart(anchor, model)
	for _, d in ipairs(whale:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Color = spec.colors and spec.colors[d.Name] or d.Color
			loosePart(d, d.Parent)
			local wc = Instance.new("WeldConstraint")
			wc.Part0, wc.Part1 = anchor, d
			wc.Parent = d
		end
	end
	whale.Parent = model
	local base = root.CFrame:ToObjectSpace(anchor.CFrame)
	local weldObj = Instance.new("Weld")
	weldObj.Part0, weldObj.Part1, weldObj.C0 = root, anchor, base
	weldObj.Parent = anchor
	local tail = whale:FindFirstChild("Tail", true)
	if tail and tail:IsA("BasePart") then
		local att = Instance.new("Attachment")
		att.Position = Vector3.new(0, 0, tail.Size.Z * 0.45)
		att.Parent = tail
		local e = Instance.new("ParticleEmitter")
		e.Name = "WhaleSplash"
		e.Color = ColorSequence.new(spec.splash.color)
		e.Size = NumberSequence.new(spec.splash.size, 0)
		e.Transparency = NumberSequence.new(0.2, 1)
		e.Lifetime = NumberRange.new(spec.splash.life * 0.6, spec.splash.life)
		e.Rate = spec.splash.rate
		e.Speed = NumberRange.new(spec.splash.speed * 0.5, spec.splash.speed)
		e.SpreadAngle = Vector2.new(40, 40)
		e.Acceleration = Vector3.new(0, -12, 0)
		e.Parent = att
	end
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not model.Parent then
			conn:Disconnect()
			return
		end
		weldObj.C0 = base * CFrame.new(0, spec.bobStuds * math.sin((os.clock() - t0) * spec.bobHz * math.pi * 2), 0)
	end)
end

-- QUEUE-ALL6 H #55 슬라임 낙하산: 덮개(납작한 공 · 유리 젤리) + 눈 + 줄 넷 · 덮개가 천천히 출렁(가로 · 세로 크기 사인)
local function buildParachute(model, root, spec)
	local canopy = Instance.new("Part")
	canopy.Name = "SlimeCanopy"
	canopy.Shape = Enum.PartType.Ball
	canopy.Material = Enum.Material.Glass
	canopy.Color = spec.color
	canopy.Transparency = 0.25
	canopy.Size = Vector3.new(spec.width, spec.height, spec.width)
	loosePart(canopy, model)
	weld(root, canopy, CFrame.new(0, spec.above, 0))
	for _, side in ipairs({ -1, 1 }) do
		local eye = Instance.new("Part")
		eye.Name = "SlimeEye"
		eye.Shape = Enum.PartType.Ball
		eye.Color = spec.eye
		eye.Size = Vector3.one * 0.5
		loosePart(eye, model)
		weld(canopy, eye, CFrame.new(side * spec.width * 0.18, spec.height * 0.12, -spec.width * 0.44))
	end
	for _, x in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -1, 1 }) do
			local top = Vector3.new(x * spec.width * 0.36, spec.above - spec.height * 0.25, z * spec.width * 0.36)
			local bottom = Vector3.new(x * 0.8, 1.2, z * 0.3)
			local len = (top - bottom).Magnitude
			local rope = Instance.new("Part")
			rope.Name = "SlimeRope"
			rope.Color = spec.color:Lerp(Color3.new(1, 1, 1), 0.4)
			rope.Size = Vector3.new(0.08, len, 0.08)
			loosePart(rope, model)
			weld(root, rope, CFrame.lookAt((top + bottom) / 2, top) * CFrame.Angles(math.rad(90), 0, 0))
		end
	end
	local t0 = os.clock()
	local base = canopy.Size
	local conn
	conn = game:GetService("RunService").RenderStepped:Connect(function()
		if not canopy.Parent then
			conn:Disconnect()
			return
		end
		local k = math.sin((os.clock() - t0) * spec.wobbleHz * 2 * math.pi) * spec.wobble
		canopy.Size = Vector3.new(base.X * (1 + k), base.Y * (1 - k), base.Z * (1 + k)) -- 말랑하게 출렁
	end)
end

function GlideView.show(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or character:FindFirstChild("MV1Glider") then
		return
	end
	local look, spec, src = skinLook(character)
	if look then
		local model = Instance.new("Model")
		model.Name = "MV1Glider"
		model:SetAttribute("GliderLook", look)
		model.Parent = character
		if look == "dragonWing" then
			buildWings(model, root, spec, src)
		elseif look == "cloudWhale" then
			buildWhale(model, root, spec, src)
		elseif look == "slimeParachute" then
			buildParachute(model, root, spec)
		end
		AirMotion.hold(character, "glide", LOOK.poseLeanDeg)
		require(script.Parent.WeaponVisual).playOverlay(Players:GetPlayerFromCharacter(character), "glideIn")
		return
	end
	local model = Instance.new("Model")
	model.Name = "MV1Glider"
	local leaf = part("Leaf", LOOK.leafSize, LOOK.leafColor, model)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere -- 납작한 타원 = 잎
	mesh.Parent = leaf
	local stem = part("Stem", Vector3.new(0.3, LOOK.aboveHeadStuds + 1.2, 0.3), LOOK.stemColor, model)
	model.Parent = character
	-- 잎은 머리 위 · 앞쪽으로 살짝(눕는 자세에서 등 위에 오도록) · 줄기는 손 높이에서 잎까지
	weld(root, leaf, CFrame.new(0, 2 + LOOK.aboveHeadStuds, -0.6) * CFrame.Angles(math.rad(8), 0, 0))
	weld(root, stem, CFrame.new(0, 1.4 + LOOK.aboveHeadStuds / 2, -0.4))
	AirMotion.hold(character, "glide", LOOK.poseLeanDeg)
	require(script.Parent.WeaponVisual).playOverlay(Players:GetPlayerFromCharacter(character), "glideIn") -- W3b 활강 시작
end

function GlideView.hide(character)
	if not character then
		return
	end
	local model = character:FindFirstChild("MV1Glider")
	if model then
		require(script.Parent.WeaponVisual).playOverlay(Players:GetPlayerFromCharacter(character), "glideOut") -- W3b 활강 끝(착지 준비)
		model:Destroy()
	end
	AirMotion.release(character, "glide")
end

return GlideView
