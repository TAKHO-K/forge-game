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
	-- 먼 풍경 대체(Persistent)는 부모에 붙이기 **전에** 정한다(붙인 뒤 바꾸면 이미 스트리밍 대상으로 나가 멀리서 안 보였다 - Studio 실측)
	if path == "BigTree" or path == "GatePillars" or path:match("^Landmark_") then
		m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end
	m.Parent = parent
	models[path] = m
	return m
end

local function makePart(p)
	local part
	if p.shape == "Wedge" then
		part = Instance.new("WedgePart")
	elseif p.shape == "Truss" then
		part = Instance.new("TrussPart") -- 덩굴 사다리(로블록스 기본 오르기)
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
		if p.query == false then
			part.CanQuery = false -- 봉인 상자 투명 벽: 막기만 한다(조준 · 지면 광선에 안 걸림)
			part.CastShadow = false
		end
	end
	if p.transparency then
		part.Transparency = p.transparency
	end
	if p.mesh then
		-- 카툰 잎 뭉치: 파트 크기 그대로 타원(구 메시 - SpecialMesh는 스크립트로 만든다 · 충돌은 파트 상자지만 장식이라 충돌 없음)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType[p.mesh]
		mesh.Parent = part
	end
	for k, v in pairs(p.attrs or {}) do
		part:SetAttribute(k, v)
	end
	if p.attrs and p.attrs.Label then
		local gui = Instance.new("BillboardGui")
		gui.Name = "LabelGui"
		gui.Size = p.attrs.LabelSmall and UDim2.new(0, 110, 0, 20) or UDim2.new(0, 160, 0, 32) -- 봉인 입구 명판은 작게
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
	-- 먼 풍경 대체: 공식 LevelOfDetail(StreamingMesh)은 런타임 스크립트가 못 쓴다(Studio 실측 - "lacking capability Plugin") → 나무 · 빛기둥 · 랜드마크(파트가 적다)를
	-- Persistent(modelAt에서 부모에 붙이기 전에)로 두어 멀리서도 늘 보이게 한다. 파트 수 = 부팅 로그.
	-- 빛기둥 · 관문 = BossData gate.color(도형 색에 이미 들어 있다 - M1-3) · 등록 전/뒤 밝기는 클라(사람마다)
	print(("[forge-game] M1 맵: 도형 %d · Persistent = 나무 · 빛기둥 · 랜드마크"):format(#prims))
	built = { models = models, meta = meta, counts = counts }
	workspace:GetAttributeChangedSignal("Season"):Connect(function()
		WorldMap.setSeason(workspace:GetAttribute("Season"))
	end)
	return meta, counts
end

-- 계절 바꾸기(사용자 - 계절마다 색 교체 용이하게): SeasonRole 붙은 도형(잎 덩어리 · 꽃 · 잎 발판)을 WorldMapData.hub.tree.leaves.seasons[season]의 역할 색 · 재질로 다시 칠한다.
-- 부르는 곳: 부팅(데이터 기본 season) · Workspace Attribute "Season"이 바뀔 때(시즌 이벤트 · 개발 확인). 반환: 칠한 파트 수(없는 계절이면 nil).
function WorldMap.setSeason(season)
	local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
	local palette = WorldMapData.hub.tree.leaves.seasons[season]
	if not palette or not built then
		return nil
	end
	local count = 0
	for _, root in ipairs({ built.models.BigTree, built.models.TreeCourse }) do
		for _, part in ipairs(root and root:GetDescendants() or {}) do
			local role = part:IsA("BasePart") and part:GetAttribute("SeasonRole")
			if role and palette[role] then
				local c, k = palette[role], part:GetAttribute("SeasonTint") or 1 -- 뭉치마다 흔든 밝기는 계절이 바뀌어도 유지
				part.Color = color3({ math.clamp(c[1] * k, 0, 255), math.clamp(c[2] * k, 0, 255), math.clamp(c[3] * k, 0, 255) })
				part.Material = Enum.Material[palette.material] or part.Material
				count += 1
			end
		end
	end
	print(("[forge-game] 계절: %s - 잎 · 꽃 %d개 다시 칠함"):format(season, count))
	return count
end

function WorldMap.meta()
	return built and built.meta
end

function WorldMap.model(path)
	return built and built.models[path]
end

return WorldMap
