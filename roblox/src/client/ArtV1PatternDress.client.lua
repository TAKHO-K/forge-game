-- A2-N4 §2-6 맵 변화 패턴 에셋화(ArtStyleV1 뒤 · 클라 겉모습만). 데이터 = ArtV1PatternData.
--   판정 파트(조각 바닥 · 점프 발판 · 수정 몸통)의 크기 · 충돌 · 재질은 안 건드린다 - 옆에 충돌 · 조준 · 터치 끈 장식만 붙이고, 수정 몸통은 로컬 투명도만 바꾼다.
--   ① 붕괴 조각: 조각 경계 잉크 줄 + 허브 테 · 조각이 꺼지면(Transparency 1) 그 조각 줄을 숨기고 돌 부스러기가 떨어진다
--   ② 점프 발판: 밑에 떠 있는 바위 섬(키트 메시) + 어두운 테두리 · 체크포인트엔 초록 수정 가시
--   ③ 깨는 수정: 수정 무리 메시(몸통 높이 × sizeScale)
--   끄면(ArtStyleV1 끔) 덧붙인 것을 전부 치우고 몸통 투명도를 되돌린다.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ArtMeshKit = require(ReplicatedStorage.Shared.ArtMeshKit)
local ArtStyleV1Data = require(ReplicatedStorage.Shared.data.ArtStyleV1Data)
local P = require(ReplicatedStorage.Shared.data.ArtV1PatternData)

local rng = Random.new()
local dressed = {} -- [판정 인스턴스] = { parts = { 장식 }, ... }

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function on()
	return Workspace:GetAttribute(ArtStyleV1Data.attribute) == true
end

local function deco(parent, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = "PatternDress"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size, p.CFrame, p.Color, p.Material = size, cf, color, material or Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- 키트 모델 전체(여러 파트 - Play: 첫 파트만 복제하니 수정 무리가 가시 1개였다)를 균일 배율로 복제 → 밑면 가운데가 base에 오게.
--   fit = "height" | "width" · size = 그 축의 목표 길이. 반환 = 파트 목록(첫 파트에 이름 PatternDress) · 없으면 nil.
local function meshModel(key, fit, size, base, parent, yaw)
	local src = ArtMeshKit.get(key)
	if not src then
		return nil
	end
	local bbCf, bbSize = src:GetBoundingBox()
	local k = size / (fit == "height" and bbSize.Y or math.max(bbSize.X, bbSize.Z))
	local bottom = bbCf.Position - Vector3.new(0, bbSize.Y / 2, 0)
	local place = CFrame.new(base) * CFrame.Angles(0, yaw or 0, 0)
	local parts = {}
	for _, p in ipairs(src:GetDescendants()) do
		if p:IsA("BasePart") then
			local c = p:Clone()
			c:ClearAllChildren()
			c.Name = "PatternDress"
			c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch, c.CastShadow = true, false, false, false, false
			c.Size = p.Size * k
			c.CFrame = place * (CFrame.new((p.Position - bottom) * k) * p.CFrame.Rotation)
			c.Parent = parent
			table.insert(parts, c)
		end
	end
	return parts, bbSize * k
end

local function paint(parts, color, material, transparency)
	for _, p in ipairs(parts) do
		p.Color = color
		p.Material = material or p.Material
		p.Transparency = transparency or p.Transparency
	end
end

local function undress(target)
	local d = dressed[target]
	if not d then
		return
	end
	dressed[target] = nil
	for _, c in ipairs(d.conns or {}) do
		c:Disconnect()
	end
	for _, p in ipairs(d.parts) do
		p:Destroy()
	end
	if d.restore then
		d.restore()
	end
end

-- ─────────────────────────── ① 붕괴 조각 ───────────────────────────
local function dropRubble(wedge)
	local S = P.slice
	for _ = 1, S.rubblePerWedge do
		local start = wedge.Position + Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2))
		local parts = meshModel(S.rubbleMesh, "width", rng:NextNumber(S.rubbleSize[1], S.rubbleSize[2]), start, Workspace, rng:NextNumber(0, 6.28))
		if not parts then
			return
		end
		paint(parts, wedge.Color)
		local info = TweenInfo.new(S.rubbleSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		for _, r in ipairs(parts) do
			TweenService:Create(r, info, { CFrame = r.CFrame + Vector3.new(0, -S.rubbleFallStuds, 0), Transparency = 1 }):Play()
			task.delay(S.rubbleSeconds, function()
				r:Destroy()
			end)
		end
	end
end

local function dressSlices(model)
	if dressed[model] then
		return
	end
	local count = model:GetAttribute("SliceCount")
	local hub = model:FindFirstChild("BossArenaSliceHub")
	local wedges = {}
	for _, w in ipairs(model:GetChildren()) do
		if w:IsA("WedgePart") and w:GetAttribute("SliceIndex") then
			table.insert(wedges, w)
		end
	end
	if not count or not hub or #wedges < count * 2 then
		return false
	end
	local S = P.slice
	local d = { parts = {}, conns = {} }
	dressed[model] = d
	local center = hub.Position
	local top = wedges[1].Position.Y + wedges[1].Size.X / 2
	local hubR = hub.Size.Y / 2
	local radius = 0
	for _, w in ipairs(wedges) do
		for _, sx in ipairs({ -0.5, 0.5 }) do
			for _, sy in ipairs({ -0.5, 0.5 }) do
				for _, sz in ipairs({ -0.5, 0.5 }) do
					local c = w.CFrame * (w.Size * Vector3.new(sx, sy, sz))
					radius = math.max(radius, (Vector3.new(c.X - center.X, 0, c.Z - center.Z)).Magnitude)
				end
			end
		end
	end
	local ink = rgb(S.seamColor)
	-- 허브 테(허브보다 조금 넓은 어두운 원판 - 허브 윗면 바로 아래)
	local ring = deco(model, Vector3.new(0.05, (hubR + S.hubRingExtra) * 2, (hubR + S.hubRingExtra) * 2), CFrame.new(center.X, top + S.seamLift * 0.5, center.Z) * CFrame.Angles(0, 0, math.rad(90)), ink)
	ring.Shape = Enum.PartType.Cylinder
	table.insert(d.parts, ring)
	-- 조각 경계 줄: k번 줄 = (k − 1)조각과 k조각 사이(각 (k − 1) × 360 / count)
	local seams = {}
	local len = radius - hubR
	for k = 1, count do
		local a = math.rad((k - 1) * 360 / count)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local mid = Vector3.new(center.X, top + S.seamLift, center.Z) + dir * (hubR + len / 2)
		seams[k] = deco(model, Vector3.new(S.seamWidth, 0.06, len), CFrame.lookAt(mid, mid + dir), ink)
		table.insert(d.parts, seams[k])
	end
	local function refresh()
		local down = {}
		for _, w in ipairs(wedges) do
			if w.Transparency >= 1 then
				down[w:GetAttribute("SliceIndex")] = true
			end
		end
		for k = 1, count do
			local prev = k == 1 and count or k - 1
			seams[k].Transparency = (down[k] and down[prev]) and 1 or 0
		end
	end
	for _, w in ipairs(wedges) do
		table.insert(d.conns, w:GetPropertyChangedSignal("Transparency"):Connect(function()
			if w.Transparency >= 1 then
				dropRubble(w)
			end
			refresh()
		end))
	end
	table.insert(d.conns, model.AncestryChanged:Connect(function()
		if not model.Parent then
			undress(model)
		end
	end))
	refresh()
	return true
end

-- ─────────────────────────── ② 점프 발판 ───────────────────────────
local function dressStep(part)
	if dressed[part] then
		return
	end
	local J = P.jumpStep
	local d = { parts = {} }
	dressed[part] = d
	local w = part.Size.X
	local topY = part.Position.Y + part.Size.Y / 2
	local rim = deco(part, Vector3.new(w + J.rimExtra, part.Size.Y, part.Size.Z + J.rimExtra), part.CFrame - Vector3.new(0, J.rimDrop, 0), rgb(J.rimColor))
	table.insert(d.parts, rim)
	-- 바위 섬: 폭 맞춤 균일 배율 → 윗면이 발판 밑면에 닿게(한 번 놓아 높이를 재고 내린다)
	local island, isize = meshModel(J.islandMesh, "width", w * J.islandWidthScale, part.Position, part, rng:NextNumber(0, 6.28))
	if island then
		local drop = part.Size.Y / 2 + isize.Y - 0.2
		for _, p in ipairs(island) do
			p.CFrame = p.CFrame - Vector3.new(0, drop, 0)
			table.insert(d.parts, p)
		end
		paint(island, rgb(J.islandColor))
	end
	if part:GetAttribute("Checkpoint") then
		local spike = meshModel(J.checkpointMesh, "height", J.checkpointHeight, Vector3.new(part.Position.X + w / 2 - 0.6, topY - 0.2, part.Position.Z + w / 2 - 0.6), part)
		if spike then
			paint(spike, rgb(J.checkpointColor), Enum.Material.Neon)
			for _, p in ipairs(spike) do
				table.insert(d.parts, p)
			end
		end
	end
	d.conns = { part.AncestryChanged:Connect(function()
		if not part:IsDescendantOf(Workspace) then
			undress(part)
		end
	end) }
end

-- ─────────────────────────── ③ 깨는 수정 ───────────────────────────
local function dressCrystal(model)
	if dressed[model] or model:GetAttribute("RescueKind") ~= "crystal" then
		return
	end
	local body = model:FindFirstChild("Body")
	local C = P.crystal
	local mesh = body and meshModel(C.mesh, "height", body.Size.Y * C.sizeScale, body.Position - Vector3.new(0, body.Size.Y / 2, 0), model)
	if not mesh then
		return
	end
	paint(mesh, body.Color, Enum.Material.Glass, C.transparency)
	local was = body.Transparency
	body.Transparency = 1
	dressed[model] = { parts = mesh, restore = function()
		if body.Parent then
			body.Transparency = was
		end
	end, conns = { model.AncestryChanged:Connect(function()
		if not model.Parent then
			undress(model)
		end
	end) } }
end

-- ─────────────────────────── 연결 ───────────────────────────
local function consider(inst)
	if not on() then
		return
	end
	if inst:IsA("Model") and inst.Name:sub(1, 20) == "BossArenaSliceFloor_" then
		task.spawn(function()
			for _ = 1, 20 do -- 조각 파트가 모델 뒤에 차례로 복제된다
				if dressSlices(inst) ~= false or not inst.Parent then
					return
				end
				task.wait(0.25)
			end
		end)
	elseif inst:IsA("BasePart") and inst:GetAttribute("CourseSite") then
		dressStep(inst)
	elseif inst:IsA("Model") and CollectionService:HasTag(inst, "RescueTarget") then
		task.defer(dressCrystal, inst)
	end
end

local function scanAll()
	for _, d in ipairs(Workspace:GetDescendants()) do
		consider(d)
	end
end

Workspace.DescendantAdded:Connect(consider)
Workspace:GetAttributeChangedSignal(ArtStyleV1Data.attribute):Connect(function()
	if on() then
		scanAll()
	else
		local list = {}
		for target in pairs(dressed) do
			table.insert(list, target)
		end
		for _, target in ipairs(list) do
			undress(target)
		end
	end
end)
task.delay(2, scanAll)
