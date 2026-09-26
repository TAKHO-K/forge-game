-- M1-4 소품 라이브러리(서버). 틀 = data/PropData · 배치 = shared/PropKit.place(맵 도형 목록의 prop 항목).
--   라이브러리 = ReplicatedStorage.Assets.Props.<이름>(Model · 피벗 = 바닥 가운데 · −Z = 앞). 같은 이름 교체 모델(PropData.overrideFolders - Rojo `src/shared/PropModels/<이름>.rbxm` 또는 place)이
--   있으면 그걸 복사해 쓰고, 없으면 틀로 짓는다(Attribute PropSource = "custom" | "template"). 배치 = 라이브러리 모델 복제 → 배율 → 피벗 이동.
--   카툰 교체 절차 = docs/art/asset-pipeline.md(교체 모델도 틀의 크기 · 충돌 발자국을 지킨다 - 판정 · 검사가 틀 도형을 읽는다).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PropData = require(ReplicatedStorage.Shared.data.PropData)
local PropKit = require(ReplicatedStorage.Shared.PropKit)

local PropLibrary = {}

local folder = nil
local cache = {} -- [name] = Model(라이브러리)
local placed = {} -- [name] = 개수(부팅 로그 · 검증)

local function color3(c)
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function findOverride(name)
	for _, path in ipairs(PropData.overrideFolders or {}) do
		local node = ReplicatedStorage
		for seg in path:gmatch("[^%.]+") do
			node = node and node:FindFirstChild(seg)
		end
		local m = node and node:FindFirstChild(name)
		if m and m:IsA("Model") then
			return m
		end
	end
	return nil
end

-- 도형 명세 하나 → 파트(WorldMap.makePart와 같은 규칙: 충돌 없는 장식 = 쿼리 · 터치 · 그림자 끔)
local function makePart(p)
	local part
	if p.shape == "Wedge" then
		part = Instance.new("WedgePart")
	elseif p.shape == "Truss" then
		part = Instance.new("TrussPart")
	else
		part = Instance.new("Part")
		if p.shape == "Ball" then
			part.Shape = Enum.PartType.Ball
		elseif p.shape == "Cylinder" then
			part.Shape = Enum.PartType.Cylinder
		end
	end
	part.Name = p.name
	part.Anchored = true
	part.Size = p.size
	part.CFrame = p.cf
	part.Color = color3(p.color)
	part.Material = Enum.Material[p.material] or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = p.collide
	part.CanTouch = false
	if not p.collide then
		part.CanQuery = false
		part.CastShadow = false
	end
	if p.transparency then
		part.Transparency = p.transparency
	end
	if p.mesh then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType[p.mesh]
		mesh.Parent = part
	end
	for k, v in pairs(p.attrs or {}) do
		part:SetAttribute(k, v)
	end
	return part
end

local function ensureFolder()
	if folder then
		return folder
	end
	local root = ReplicatedStorage:FindFirstChild(PropData.folder)
	if not root then
		root = Instance.new("Folder")
		root.Name = PropData.folder
		root.Parent = ReplicatedStorage
	end
	folder = root:FindFirstChild("Props")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Props"
		folder.Parent = root
	end
	return folder
end

-- 라이브러리 모델(없으면 만든다)
function PropLibrary.model(name)
	if cache[name] then
		return cache[name]
	end
	local f = ensureFolder()
	local m = f:FindFirstChild(name)
	if not m then
		local custom = findOverride(name)
		if custom then
			m = custom:Clone()
			m:PivotTo(CFrame.new()) -- 교체 모델의 피벗(바닥 가운데 규칙)을 원점으로
			m:SetAttribute("PropSource", "custom")
		else
			m = Instance.new("Model")
			for _, p in ipairs(PropKit.expand(name, CFrame.new(), Vector3.one)) do
				makePart(p).Parent = m
			end
			m:SetAttribute("PropSource", "template")
		end
		m.Name = name
		m.WorldPivot = CFrame.new() -- 피벗 = 바닥 가운데(틀 원점)
		m.Parent = f
	end
	cache[name] = m
	return m
end

-- 배율 적용(틀 축마다): 피벗 기준 위치 · 크기를 늘인다(교체 메시도 MeshPart 크기로 같이 늘어난다)
local function applyScale(m, s)
	if s.X == 1 and s.Y == 1 and s.Z == 1 then
		return
	end
	for _, part in ipairs(m:GetDescendants()) do
		if part:IsA("BasePart") then
			local lcf = part.CFrame -- 라이브러리 복제본은 원점 피벗이라 월드 = 로컬
			local rot = lcf - lcf.Position
			local function k(axis)
				local u = rot * axis
				return math.sqrt((u.X * s.X) ^ 2 + (u.Y * s.Y) ^ 2 + (u.Z * s.Z) ^ 2)
			end
			local sz = part.Size
			part.Size = Vector3.new(sz.X * k(Vector3.xAxis), sz.Y * k(Vector3.yAxis), sz.Z * k(Vector3.zAxis))
			part.CFrame = CFrame.new(lcf.Position * s) * rot
		end
	end
end

-- 지형에 붙이기(snap 항목): 피벗 위 60에서 아래로 Terrain만 광선 → 식 높이와 0.75 넘게 다르면 지형 높이 − 0.3으로 옮긴다.
-- 식(TerrainShape)과 굽힌 지형은 같아야 하지만, 모양을 바꾸고 아직 안 구운 구역 · 굽기 오차에서 떠 있거나 묻히지 않게(사용자: 재굽기 시 자동 재배치).
local snapParams = RaycastParams.new()
snapParams.FilterType = Enum.RaycastFilterType.Include
local snapStats = { checked = 0, moved = 0, maxDelta = 0 }
local function snapCf(cf, reach)
	snapParams.FilterDescendantsInstances = { workspace.Terrain }
	snapStats.checked += 1
	-- 발자국 7점(가운데 · 네 방향 · 대각 둘)의 가장 낮은 지형(배치 식 PropScatter.groundUnder와 같은 규칙 - 비탈에서 뜨지 않게)
	local low = nil
	for _, o in ipairs({ Vector3.zero, Vector3.new(reach, 0, 0), Vector3.new(-reach, 0, 0), Vector3.new(0, 0, reach), Vector3.new(0, 0, -reach), Vector3.new(reach * 0.7, 0, reach * 0.7), Vector3.new(-reach * 0.7, 0, -reach * 0.7) }) do
		local hit = workspace:Raycast(cf.Position + o + Vector3.new(0, 60, 0), Vector3.new(0, -140, 0), snapParams)
		if hit and hit.Material ~= Enum.Material.Water then
			low = math.min(low or math.huge, hit.Position.Y)
		end
	end
	if not low then
		return cf
	end
	local want = low - 0.3
	local d = want - cf.Position.Y
	snapStats.maxDelta = math.max(snapStats.maxDelta, math.abs(d))
	if math.abs(d) > 0.75 then
		snapStats.moved += 1
		return cf + Vector3.new(0, d, 0)
	end
	return cf
end
function PropLibrary.snapStats()
	return snapStats
end

-- 배치 항목(PropKit.place) → 복제 Model(부모는 부르는 쪽이 붙인다)
function PropLibrary.instantiate(entry)
	local m = PropLibrary.model(entry.prop):Clone()
	m:SetAttribute("PropSource", nil)
	m:SetAttribute("Prop", entry.prop)
	applyScale(m, entry.scale or Vector3.one)
	m:PivotTo(entry.snap and snapCf(entry.cf, math.sqrt((entry.size.X / 2) ^ 2 + (entry.size.Z / 2) ^ 2)) or entry.cf)
	for k, v in pairs(entry.attrs or {}) do
		m:SetAttribute(k, v)
	end
	placed[entry.prop] = (placed[entry.prop] or 0) + 1
	return m
end

function PropLibrary.counts()
	return placed
end

-- 부팅 때 틀 전부를 라이브러리에 만든다(배치가 없는 틀도 - 교체 작업자가 목록을 본다)
function PropLibrary.ensureAll()
	local n, custom = 0, 0
	for name in pairs(PropData.templates) do
		local m = PropLibrary.model(name)
		n += 1
		if findOverride(name) then
			custom += 1
		end
		local _ = m
	end
	return n, custom
end

return PropLibrary
