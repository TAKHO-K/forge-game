-- M1 맵 그레이박스 빌더(서버). 도형 = shared/WorldMapLayout.buildAll()(수치 = data/WorldMapData) - 여기서는 파트로 바꾸기만 한다.
-- 모든 모델은 Workspace.Ground 아래(GroundProbe의 지면 = 이 폴더). 충돌 없는 도형(잎 · 등불 · 자리 표시)은 CanCollide · CanQuery · CanTouch를 끈다 -
-- 지면 광선 · 조준 광선 · 터치 이벤트 어디에도 안 걸린다(장식 비용 = 그리기만).
-- 스트리밍: 나무(BigTree - 줄기 + 잎) · 관문 빛기둥 · 구역 랜드마크는 Persistent(어디서나 보인다 - 스트리밍으로 사라지지 않는다). 나머지는 기본(Nonatomic - 파트 단위로 들어온다 나간다).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)
local GroundProbe = require(script.Parent.GroundProbe)

local WorldMap = {}

local built = nil -- { models = { [path] = Model }, meta, counts }

local function color3(c)
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function modelAt(root, models, path)
	if models[path] then
		return models[path]
	end
	local parentPath, name = path:match("^(.*)%.([^%.]+)$")
	local parent = root
	if parentPath then
		parent = modelAt(root, models, parentPath)
	else
		name = path
	end
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	models[path] = m
	return m
end

local function makePart(p)
	local part
	if p.shape == "Wedge" then
		part = Instance.new("WedgePart")
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
	part.Material = p.neon and Enum.Material.Neon or (Enum.Material[p.material] or Enum.Material.Concrete)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = p.collide
	if not p.collide then
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
	else
		part.CanTouch = false -- 트리거는 서버 거리 폴링(TravelServer) - 터치 이벤트를 안 쓴다
	end
	if p.transparency then
		part.Transparency = p.transparency
	end
	for k, v in pairs(p.attrs or {}) do
		part:SetAttribute(k, v)
	end
	if p.attrs and p.attrs.Label then
		local gui = Instance.new("BillboardGui")
		gui.Name = "LabelGui"
		gui.Size = UDim2.new(0, 160, 0, 32)
		gui.StudsOffsetWorldSpace = Vector3.new(0, p.size.Y / 2 + 3, 0)
		gui.MaxDistance = 220
		gui.Parent = part
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Text = p.attrs.Label
		text.TextColor3 = Color3.new(1, 1, 1)
		text.TextStrokeTransparency = 0.4
		text.TextScaled = true
		text.Parent = gui
	end
	return part
end

-- 한 번만 짓는다(HuntingGround 부팅). 반환: 메타(구역별 탐험 · 이스터에그 · 둥지) · 모델별 파트 수.
function WorldMap.build()
	if built then
		return built.meta, built.counts
	end
	local root = GroundProbe.folder()
	local prims, meta = WorldMapLayout.buildAll()
	local models, counts = {}, {}
	for _, p in ipairs(prims) do
		local m = modelAt(root, models, p.model)
		makePart(p).Parent = m
		local top = p.model:match("^[^%.]+")
		counts[top] = counts[top] or { parts = 0, decor = 0 }
		counts[top].parts += 1
		if not p.collide then
			counts[top].decor += 1
		end
	end
	-- 스트리밍 모드(Workspace.StreamingEnabled일 때만 뜻이 있다 - 꺼져 있어도 설정은 무해)
	-- 먼 풍경 대체: 공식 LevelOfDetail(StreamingMesh)은 런타임 스크립트가 못 쓴다(Studio 실측 - "lacking capability Plugin") → 파트가 적은 랜드마크(구역마다 3 ~ 8)를
	-- Persistent로 두어 멀리서도 늘 보이게 한다(나무 43 · 빛기둥 6 · 랜드마크 29 = 78파트).
	for name, m in pairs(models) do
		if name == "BigTree" or name == "GatePillars" or name:match("^Landmark_") then
			m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		end
	end
	-- 빛기둥 = 그 관문 보스의 고유 색(머리색)
	local BossData = require(ReplicatedStorage.Shared.data.BossData)
	for _, part in ipairs(models.GatePillars and models.GatePillars:GetChildren() or {}) do
		local boss = BossData.bosses[part:GetAttribute("BossId")]
		if boss then
			part.Color = boss.headColor
		end
	end
	print(("[forge-game] M1 맵: 도형 %d · Persistent = 나무 · 빛기둥 · 랜드마크"):format(#prims))
	built = { models = models, meta = meta, counts = counts }
	return meta, counts
end

function WorldMap.meta()
	return built and built.meta
end

function WorldMap.model(path)
	return built and built.models[path]
end

return WorldMap
