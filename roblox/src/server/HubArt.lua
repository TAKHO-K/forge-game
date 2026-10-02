-- QUEUE-ALL7B 3 허브 건물 · NPC · 게시판 메시(ArtStyleV1 뒤 · 겉모습만 - ArtAssetLoader가 맵 완성 뒤 부른다).
--   건물 = Ground.Hub의 Facility_<시설> 상자(HubBuilding = HubArtMeta 키) 자리에 메시를 얹고 상자는 투명(충돌 = 이 상자 하나 그대로).
--   NPC · 게시판 = 자리 기둥(Spot) 바닥에 세우고 기둥 = 투명 · 충돌 끔(프롬프트 · 이름표 자리 그대로 - 이름표만 메시 꼭대기 위로) · 굴뚝 연기.
--   메시 색 · 네온 = HubArtMeta parts(생성 표). NPC 모델 = Workspace.HubArt.HubNpc_<id>(WorldPivot = 바닥 프레임 · 클라 HubNpcView가 대기 동작).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ArtMeshKit = require(ReplicatedStorage.Shared.ArtMeshKit)
local HubArtMeta = require(ReplicatedStorage.Shared.data.HubArtMeta)
local HubArtData = require(ReplicatedStorage.Shared.data.HubArtData)
local TreeArtMeta = require(ReplicatedStorage.Shared.data.TreeArtMeta)
local HubPropsData = require(ReplicatedStorage.Shared.data.HubPropsData)
local HubPropLayout = require(ReplicatedStorage.Shared.HubPropLayout)
local ArtAssetIds = require(ReplicatedStorage.Shared.data.ArtAssetIds)
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)

local HubArt = {}
local FLOOR = WorldMapData.floorTopY

local function rgb(c)
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- 가져올 때 줄어든 배율 되돌리기: MeshPart 한 변 상한 2048(cm 단위 FBX = 20.48 stud)을 넘는 모델은 가져오기가 모델 전체를 같은 비율로 줄인다
--   (관문 틀 width ÷ gateMeshWidth와 같은 문제) → 메시 표 bounds(가로) ÷ 캐시 모델 실제 가로. 키마다 한 번.
local scaleOf = {}
local function restoreScale(key, src, meta)
	if scaleOf[key] then
		return scaleOf[key]
	end
	local _, size = src:GetBoundingBox()
	local k = (size.X > 0 and meta.bounds[1] / size.X) or 1
	scaleOf[key] = math.abs(k - 1) < 0.01 and 1 or k
	return scaleOf[key]
end

-- 메시 조각을 frame(바닥 가운데) 위에 복제 · 색칠. 반환 = 만든 수
local function place(key, frame, parent, rgbOverride)
	local src = ArtMeshKit.get("props/" .. key)
	local meta = HubArtMeta[key]
	if not src or not meta then
		return 0
	end
	local k = restoreScale(key, src, meta)
	local n = 0
	for _, p in ipairs(src:GetChildren()) do
		if p:IsA("BasePart") then
			local m = p:Clone()
			m.Size = p.Size * k
			m.CFrame = frame * (CFrame.new(p.Position * k) * p.CFrame.Rotation)
			m.Anchored, m.CanCollide, m.CanTouch, m.CanQuery = true, false, false, false
			local pm = meta.parts[p.Name]
			if pm then
				m.Color = rgb((rgbOverride and rgbOverride[p.Name]) or pm.rgb)
				m.Material = pm.neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
			end
			m.Parent = parent
			n += 1
		end
	end
	return n
end

local function floorFrame(part)
	local pos = part.Position
	return CFrame.new(pos.X, FLOOR, pos.Z) * part.CFrame.Rotation
end

local function spotParts()
	local out = {}
	local hub = Workspace:FindFirstChild("Ground") and Workspace.Ground:FindFirstChild("Hub")
	for _, d in ipairs(hub and hub:GetDescendants() or {}) do
		if d:IsA("BasePart") and d:GetAttribute("Spot") then
			out[d:GetAttribute("Spot")] = d
		end
	end
	return out, hub
end

-- 기둥 이름표를 메시 꼭대기 위로(기능 아이콘 = 클라가 TagTop을 읽는다)
local function raiseTag(spot, top)
	spot:SetAttribute("TagTop", top)
	local gui = spot:FindFirstChild("LabelGui")
	if gui then
		gui.StudsOffsetWorldSpace = Vector3.new(0, FLOOR + top + HubArtData.tagGap - spot.Position.Y, 0)
	end
end

local function smoke(model, frame, at)
	local S = HubArtData.smoke
	local holder = Instance.new("Part")
	holder.Name = "ChimneySmoke"
	holder.Size = Vector3.new(1, 1, 1)
	holder.Transparency = 1
	holder.Anchored, holder.CanCollide, holder.CanTouch, holder.CanQuery = true, false, false, false
	holder.CFrame = frame * CFrame.new(at[1], at[2], at[3])
	local e = Instance.new("ParticleEmitter")
	e.Rate = S.rate
	e.Lifetime = NumberRange.new(S.lifetime[1], S.lifetime[2])
	e.Speed = NumberRange.new(S.speed[1], S.speed[2])
	e.SpreadAngle = Vector2.new(12, 12)
	e.Size = NumberSequence.new(S.size[1], S.size[2])
	e.Transparency = NumberSequence.new(S.transparency[1], S.transparency[2])
	e.Color = ColorSequence.new(rgb(S.rgb))
	e.LightEmission = 0
	e.Parent = holder
	holder.Parent = model
end

-- QUEUE-ALL8 B2 바닥: 거리 · 광장 = 카툰 자갈(재질 · 색) + 테두리 연석(겉모습만 - 충돌 · 조준 없음)
local function curb(parent, cf, size)
	local c = Instance.new("Part")
	c.Name = "HubCurb"
	c.Anchored, c.CanCollide, c.CanTouch, c.CanQuery = true, false, false, false
	c.Size = size
	c.CFrame = cf
	c.Color = rgb(HubPropsData.floor.curbRgb)
	c.Material = Enum.Material.SmoothPlastic
	c.TopSurface, c.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	c.Parent = parent
end
local function dressFloors(hub, folder)
	local F = HubPropsData.floor
	local model = Instance.new("Model")
	model.Name = "HubFloors"
	local n = 0
	for _, d in ipairs(hub:GetDescendants()) do
		if d:IsA("BasePart") and (d.Name == "DistrictFloor" or d.Name == "PortalPlaza") then
			d.Material = Enum.Material[F.material]
			d.Color = rgb(F.rgb)
			n += 1
			local img = ArtAssetIds[F.texture] -- 카툰 자갈 무늬(평면 재질 위에 Texture - 윗면만)
			if img and img.image then
				local tex = Instance.new("Texture")
				tex.Name = "HubCobble"
				tex.Texture = "rbxassetid://" .. tostring(img.image)
				tex.StudsPerTileU, tex.StudsPerTileV = F.studsPerTile, F.studsPerTile
				tex.Face = d.Shape == Enum.PartType.Cylinder and Enum.NormalId.Right or Enum.NormalId.Top -- 눕힌 원판 = 로컬 +X 면이 위
				tex.Parent = d
			end
			local top = d.Position.Y + 0.1
			if d.Shape == Enum.PartType.Cylinder then
				local r = d.Size.Y / 2 -- 원판(옆으로 눕힌 원기둥 - 지름 = Y · Z)
				local seg = F.ringSegments
				local len = 2 * math.pi * r / seg + 0.3
				for i = 1, seg do
					local a = (i - 0.5) / seg * 2 * math.pi
					local p = Vector3.new(d.Position.X + math.cos(a) * r, top + F.curbH / 2, d.Position.Z + math.sin(a) * r)
					curb(model, CFrame.lookAt(p, p + Vector3.new(-math.sin(a), 0, math.cos(a))), Vector3.new(F.curbW, F.curbH, len))
				end
			else
				local hx, hz = d.Size.X / 2, d.Size.Z / 2
				for _, e in ipairs({ { 0, -hz, d.Size.X, F.curbW }, { 0, hz, d.Size.X, F.curbW }, { -hx, 0, F.curbW, d.Size.Z }, { hx, 0, F.curbW, d.Size.Z } }) do
					curb(model, d.CFrame * CFrame.new(e[1], d.Size.Y / 2 + F.curbH / 2, e[2]), Vector3.new(e[3], F.curbH, e[4]))
				end
			end
		end
	end
	model.Parent = folder
	return n
end

-- QUEUE-ALL8 B3 소품(HubPropsData → HubPropLayout.list) · 울타리 · 우물 = 단순 충돌 상자(투명) · 경계 랜턴 기둥 = 카툰 랜턴으로
local function sizeOf(kind)
	local m = HubArtMeta[kind]
	return m and math.max(m.bounds[1], m.bounds[3]) / 2 or 2
end
HubArt.propSizeOf = sizeOf
local function placeProps(hub, folder)
	local props = Instance.new("Folder")
	props.Name = HubPropsData.folder
	props.Parent = folder
	local count, byKind = 0, {}
	local function put(kind, cf, rgbOverride, source)
		local model = Instance.new("Model")
		model.Name = kind
		if place(kind, cf, model, rgbOverride) == 0 then
			model:Destroy()
			return
		end
		model.WorldPivot = cf
		model:SetAttribute("HubProp", kind)
		model:SetAttribute("Source", source)
		local col = HubPropsData.colliders[kind]
		if col then
			local c = Instance.new("Part")
			c.Name = "HubPropCollider"
			c.Size = Vector3.new(col[1], col[2], col[3])
			c.CFrame = cf * CFrame.new(0, col[2] / 2, 0)
			c.Transparency = 1
			c.Anchored, c.CanCollide, c.CanTouch, c.CanQuery = true, true, false, true
			c.Parent = model
		end
		model.Parent = props
		count += 1
		byKind[kind] = (byKind[kind] or 0) + 1
	end
	local list, dropped = HubPropLayout.list(sizeOf)
	for _, e in ipairs(list) do
		put(e.kind, e.cf, e.rgb, e.source)
	end
	if #dropped > 0 then -- 길 위라 안 놓은 것(손 배치는 자리를 고친다 - 보고용 한 줄)
		local ex = {}
		for i, e in ipairs(dropped) do
			if i <= 12 then
				table.insert(ex, ("%s:%s@(%d, %d)"):format(e.source, e.kind:gsub("^prop_", ""), e.cf.X, e.cf.Z))
			end
		end
		print(("[HubArt] 길 위라 안 놓음 %d: %s"):format(#dropped, table.concat(ex, " ")))
	end
	if HubPropsData.boundaryLanterns then
		for _, d in ipairs(hub:GetChildren()) do
			if d:IsA("BasePart") and (d.Name == "LanternPost" or d.Name == "Lantern") then
				d.Transparency = 1
				if d.Name == "LanternPost" then
					local base = Vector3.new(d.Position.X, FLOOR, d.Position.Z)
					put("prop_lantern", CFrame.lookAt(base, Vector3.new(0, FLOOR, 0)), nil, "boundary")
				end
			end
		end
	end
	return count, byKind
end

-- QUEUE-ALL8 H 큰 나무 겉모습(TreeArtMeta 메시 · 충돌 · 기능 = 코드 도형 그대로 - 투명으로 남긴다)
--   s = 축마다 배율(단위 메시를 코드 도형 크기로) · 조각 색 = 표
local function placeScaled(key, frame, s, parent)
	local src = ArtMeshKit.get("props/" .. key)
	local meta = TreeArtMeta[key]
	if not src or not meta then
		return 0
	end
	local k = restoreScale(key, src, meta)
	local n = 0
	for _, p in ipairs(src:GetChildren()) do
		if p:IsA("BasePart") then
			local m = p:Clone()
			m.Size = p.Size * k * s
			m.CFrame = frame * (CFrame.new(p.Position * k * s) * p.CFrame.Rotation)
			m.Anchored, m.CanCollide, m.CanTouch, m.CanQuery = true, false, false, false
			local pm = meta.parts[p.Name]
			if pm then
				m.Color = rgb(pm.rgb)
				m.Material = Enum.Material.SmoothPlastic
			end
			m.CastShadow = true
			m.Parent = parent
			n += 1
		end
	end
	return n
end

local function dressTree(folder)
	local ground = Workspace:FindFirstChild("Ground")
	local tree = ground and ground:FindFirstChild("BigTree")
	local course = ground and ground:FindFirstChild("TreeCourse")
	if not tree or not course then
		return 0
	end
	local model = Instance.new("Model")
	model.Name = "TreeArt"
	local count = 0
	local T = WorldMapData.hub.tree
	-- 밑동(실제 크기) · 줄기 칸(단위 원통 → 코드 Trunk 칸 크기 · 칸마다 조금 더 비틀어 이어 붙인다)
	count += placeScaled("tree_trunk_base", CFrame.new(0, FLOOR, 0), Vector3.one, model)
	local twist = 0
	for _, p in ipairs(tree:GetChildren()) do
		if p:IsA("BasePart") then
			if p.Name == "Trunk" then
				local L, Dm = p.Size.X, p.Size.Y -- 눕힌 원통(X = 길이)
				count += placeScaled("tree_trunk_section", CFrame.new(p.Position) * CFrame.Angles(0, math.rad(twist), 0), Vector3.new(Dm / 2, L, Dm / 2), model)
				twist += 20
				p.Transparency = 1
			elseif p.Name == "Ridge" or p.Name == "TrunkFlare" or p.Name == "BarkBump" then
				p.Transparency = 1 -- 옛 세로 판자 결 · 겹친 원통 · 혹(장식 - 충돌 없음)
			elseif p.Name == "Root" then
				p.Transparency = 1 -- 충돌 그대로(두꺼운 쪽만 - WorldMapLayout) · 겉모습 = tree_root
			end
		end
	end
	for _, a in ipairs(T.roots.angles) do
		count += placeScaled("tree_root", CFrame.new(0, FLOOR, 0) * CFrame.Angles(0, -math.rad(a), 0), Vector3.one, model)
	end
	-- 점프맵 가지 발판 · 줄기에서 나온 가지 · 링 발판(난간)
	local bB, bS, bD = TreeArtMeta.tree_branch.bounds, TreeArtMeta.tree_stem.bounds, TreeArtMeta.tree_deck.bounds
	for _, p in ipairs(course:GetDescendants()) do
		if p:IsA("BasePart") then
			if p.Name == "Branch" then
				count += placeScaled("tree_branch", p.CFrame, Vector3.new(p.Size.X / bB[1], p.Size.Y / bB[2], p.Size.Z / bB[3]), model)
				p.Transparency = 1
			elseif p.Name == "BranchStem" then
				count += placeScaled("tree_stem", p.CFrame, Vector3.new(p.Size.X / bS[1], p.Size.Y / bS[2], p.Size.Z / bS[3]), model)
				p.Transparency = 1
			elseif p.Name == "Station" or p.Name == "Deck" then
				count += placeScaled("tree_deck", p.CFrame, Vector3.new(p.Size.X / bD[1], 1, p.Size.Z / bD[3]), model)
				p.Transparency = 1
			end
		end
	end
	model.Parent = folder
	return count
end

function HubArt.scaleOf(key) -- 검증 · 보고용(가져올 때 줄어든 비율의 역수)
	return scaleOf[key]
end

function HubArt.apply()
	if not ArtMeshKit.enabled() then
		return 0, 0
	end
	local spots, hub = spotParts()
	if not hub or Workspace:FindFirstChild(HubArtData.folder) then
		return 0, 0
	end
	local folder = Instance.new("Folder")
	folder.Name = HubArtData.folder
	folder.Parent = Workspace
	local buildings, npcs = 0, 0
	for _, part in ipairs(hub:GetDescendants()) do
		local kind = part:IsA("BasePart") and part:GetAttribute("HubBuilding")
		if kind and HubArtMeta[kind] then
			local model = Instance.new("Model")
			model.Name = "HubBuilding_" .. kind
			local frame = floorFrame(part)
			if place(kind, frame, model) > 0 then
				part.Transparency = 1 -- 충돌 상자는 그대로
				local label = part:FindFirstChild("LabelGui")
				if label then
					label.StudsOffsetWorldSpace = Vector3.new(0, FLOOR + HubArtMeta[kind].height + HubArtData.tagGap - part.Position.Y, 0)
				end
				if HubArtMeta[kind].chimney then
					smoke(model, frame, HubArtMeta[kind].chimney)
				end
				model.WorldPivot = frame
				model.Parent = folder
				buildings += 1
			else
				model:Destroy()
			end
		end
	end
	local function onSpot(entry, prefix)
		local spot = spots[entry.spot]
		local key = entry.model:gsub("^props/", "")
		if not spot or not HubArtMeta[key] then
			return false
		end
		local off = entry.offset or { 0, 0 }
		local frame = floorFrame(spot) * CFrame.new(off[1], 0, off[2])
		local model = Instance.new("Model")
		model.Name = prefix .. entry.id
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- 조각이 한꺼번에 들어와야 클라 대기 동작이 관절 자리를 한 번에 잰다(부모 연결 전에 정한다)
		if place(key, frame, model) == 0 then
			model:Destroy()
			return false
		end
		model.WorldPivot = frame
		model:SetAttribute("HubNpc", prefix == "HubNpc_" and entry.id or nil)
		model.Parent = folder
		spot.Transparency = 1
		spot.CanCollide = false
		raiseTag(spot, math.max(spot:GetAttribute("TagTop") or 0, HubArtMeta[key].height))
		return true
	end
	for _, p in ipairs(HubArtData.props) do
		onSpot(p, "HubProp_")
	end
	for _, n in ipairs(HubArtData.npcs) do
		if onSpot(n, "HubNpc_") then
			npcs += 1
		end
	end
	-- QUEUE-ALL8 B2 · B3 · B4 · H
	local treePieces = dressTree(folder)
	print(("[HubArt] 큰 나무 메시 조각 %d"):format(treePieces))
	local floors = dressFloors(hub, folder)
	local propCount, byKind = placeProps(hub, folder)
	local kinds = {}
	for k, v in pairs(byKind) do
		table.insert(kinds, ("%s %d"):format(k:gsub("^prop_", ""), v))
	end
	table.sort(kinds)
	print(("[HubArt] 바닥 %d · 소품 %d(%s)"):format(floors, propCount, table.concat(kinds, " · ")))
	return buildings, npcs
end

return HubArt
