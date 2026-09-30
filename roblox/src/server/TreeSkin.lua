-- QUEUE-ALL1 ★0-2 카툰 나무 입히기(ArtStyleV1 뒤 - 메시 캐시가 있을 때만 · 없으면 지금 나무 그대로). 수치 = shared/data/TreeArtData.
--   field(entry)  - PropLibrary 배치 Common_Tree 하나: 구역 변형 메시(줄기 · 잎 3색)를 틀 자리에 겹치고 틀 겉모습은 숨긴다(틀 줄기 원기둥 = 충돌 그대로).
--   hubTrees()    - 허브 임시 자리 나무(큰 나무 = Common_Tree 틀 + 메시 · 관목 = 메시만 · 장식수 = 가는 충돌 원기둥 + 메시). 자리 둘레에 다른 충돌이 있으면 건너뜀.
--   bigTree()     - 허브 큰 나무 잎 뭉치(Block + SpecialMesh 공)마다 덩어리 덮개 · 뭉치 색(계절)을 따라 칠한다. 뭉치 판정 · 충돌은 그대로(겉모습만 투명).
--   잎 메시 = CollectionService "TreeSway"(클라 TreeWind가 가까운 것만 흔든다 - 필드 · 허브 나무만).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ArtMeshKit = require(ReplicatedStorage.Shared.ArtMeshKit)
local TreeArtData = require(ReplicatedStorage.Shared.data.TreeArtData)
local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)

local TreeSkin = {}

local function rgb(c)
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function hash(pos, n)
	return math.floor(math.abs(pos.X * 7.13 + pos.Z * 3.31 + pos.Y * 1.7)) % n + 1
end

-- 캐시 모델(props/trees/<key>)의 파트를 frame · scale로 겹친다. colors = { Trunk = Color3, Leaves = …, Deco_Dark = …, Deco_Light = … }
local function place(parent, key, frame, scale, colors, sway)
	local src = ArtMeshKit.get(TreeArtData.keyPrefix .. key)
	if not src then
		return nil
	end
	local made = {}
	for _, p in ipairs(src:GetChildren()) do
		if p:IsA("BasePart") then
			local m = p:Clone()
			m.Name = "TreeMesh_" .. p.Name
			m.Size = p.Size * scale
			m.CFrame = frame * (CFrame.new(p.Position * scale) * p.CFrame.Rotation)
			m.Anchored = true
			m.CanCollide, m.CanQuery, m.CanTouch = false, false, false
			m.CastShadow = true
			m.Material = Enum.Material.SmoothPlastic
			m.Color = colors[p.Name] or m.Color
			if sway and p.Name ~= "Trunk" then
				CollectionService:AddTag(m, "TreeSway")
			end
			m.Parent = parent
			made[p.Name] = made[p.Name] or {}
			table.insert(made[p.Name], m)
		end
	end
	return made
end

local function paletteColors(pal)
	return { Trunk = rgb(pal.bark), Leaves = rgb(pal.leaf), Deco_Dark = rgb(pal.dark), Deco_Light = rgb(pal.light) }
end

function TreeSkin.field(entry, forceKey, paletteName)
	local model = entry.model
	local frame = model:GetPivot()
	local zone = WorldMapLayout.zoneAt(frame.Position)
	local zkey = paletteName or (zone and zone.key) or "default"
	local list = TreeArtData.variants[zkey] or TreeArtData.variants.default
	local key = forceKey or list[hash(frame.Position, #list)]
	local pal = TreeArtData.palettes[zkey] or TreeArtData.palettes.default
	local made = place(model, key, frame, entry.scale or Vector3.one, paletteColors(pal), true)
	if not made then
		return false
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and (d.Name == "Trunk" or d.Name == "Leaves") then
			d.Transparency = 1 -- 틀 겉모습 숨김(줄기 원기둥 충돌은 그대로)
		end
	end
	model:SetAttribute("ArtMesh", TreeArtData.keyPrefix .. key)
	return true
end

-- 허브 임시 자리 나무
function TreeSkin.hubTrees()
	if Workspace:FindFirstChild("HubTrees") or not ArtMeshKit.get(TreeArtData.keyPrefix .. "tree_oak") then
		return 0, 0
	end
	local PropLibrary = require(script.Parent.PropLibrary)
	local H = TreeArtData.hub
	local folder = Instance.new("Folder")
	folder.Name = "HubTrees"
	folder.Parent = Workspace
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	ray.FilterDescendantsInstances = { folder }
	ray.RespectCanCollide = true
	local over = OverlapParams.new()
	over.FilterType = Enum.RaycastFilterType.Exclude
	over.FilterDescendantsInstances = { folder, Workspace.Terrain }
	over.RespectCanCollide = true
	local placed, skipped = 0, 0
	local colors = paletteColors(TreeArtData.palettes.hub)
	for i, s in ipairs(H.spots) do
		local at = WorldMapLayout.hubPoint(s.angleDeg, s.r)
		local hit = Workspace:Raycast(at + Vector3.new(0, 60, 0), Vector3.new(0, -140, 0), ray)
		local ground = hit and hit.Position or at
		local blocked = #Workspace:GetPartBoundsInRadius(ground + Vector3.new(0, H.clearStuds + 1.5, 0), H.clearStuds, over) > 0 -- 구 밑이 바닥 위 1.5(바닥 자체는 안 잡는다)
		if blocked then
			skipped += 1
		else
			local frame = CFrame.new(ground) * CFrame.Angles(0, math.rad(i * 47 % 360), 0)
			local scale = Vector3.one * (s.scale or 1)
			if s.kind:sub(1, 5) == "tree_" then
				local m = PropLibrary.instantiate({ prop = "Common_Tree", cf = frame, scale = scale, size = Vector3.new(4, 20, 4) })
				m.Name = "HubTree_" .. i
				m.Parent = folder
				TreeSkin.field({ model = m, scale = scale }, s.kind, "hub")
			else
				local m = Instance.new("Model")
				m.Name = "HubTree_" .. i
				m.Parent = folder
				if s.kind == "hub_topiary" then
					local c = Instance.new("Part")
					c.Name = "Trunk"
					c.Shape = Enum.PartType.Cylinder
					c.Size = Vector3.new(H.topiaryCollider.height * scale.Y, H.topiaryCollider.diameter, H.topiaryCollider.diameter)
					c.CFrame = frame * CFrame.new(0, H.topiaryCollider.height * scale.Y / 2 - 1, 0) * CFrame.Angles(0, 0, math.rad(90))
					c.Anchored, c.Transparency, c.CanTouch = true, 1, false
					c.Parent = m
				end
				place(m, s.kind, frame, scale, colors, true)
			end
			placed += 1
		end
	end
	return placed, skipped
end

-- 허브 큰 나무 잎 뭉치 덮개
function TreeSkin.bigTree()
	local tree = Workspace:FindFirstChild("BigTree", true)
	if not tree or tree:GetAttribute("TreeSkin") or not ArtMeshKit.get(TreeArtData.keyPrefix .. TreeArtData.clumps[1]) then
		return 0
	end
	local B = TreeArtData.bigTree
	local n = 0
	for _, part in ipairs(tree:GetDescendants()) do
		local role = part:IsA("BasePart") and part:GetAttribute("SeasonRole")
		local mesh = role and part:FindFirstChildOfClass("SpecialMesh") -- 뭉치 = Block + SpecialMesh(Sphere · 배율 Scale) (Play 실측 176개)
		local sphere = mesh and mesh.MeshType == Enum.MeshType.Sphere
		if role and B.roles[role] and (sphere or (part:IsA("Part") and part.Shape == Enum.PartType.Ball)) then
			local size = sphere and part.Size * mesh.Scale or part.Size
			local key = TreeArtData.clumps[hash(part.Position, #TreeArtData.clumps)]
			local function colors()
				local c = part.Color
				return { Leaves = c, Deco_Dark = Color3.new(c.R * B.darkK, c.G * B.darkK, c.B * B.darkK), Deco_Light = c:Lerp(Color3.new(1, 1, 1), B.lightK) }
			end
			local made = place(part.Parent, key, part.CFrame, size * B.scale, colors(), false)
			if made then
				part.Transparency = 1
				part:GetPropertyChangedSignal("Color"):Connect(function() -- 계절이 바뀌면 덮개도
					local c = colors()
					for name, list in pairs(made) do
						for _, m in ipairs(list) do
							m.Color = c[name] or m.Color
						end
					end
				end)
				n += 1
			end
		end
	end
	tree:SetAttribute("TreeSkin", n)
	return n
end

return TreeSkin
