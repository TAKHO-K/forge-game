-- QUEUE-ALL7B 3 허브 건물 · NPC · 게시판 메시(ArtStyleV1 뒤 · 겉모습만 - ArtAssetLoader가 맵 완성 뒤 부른다).
--   건물 = Ground.Hub의 Facility_<시설> 상자(HubBuilding = HubArtMeta 키) 자리에 메시를 얹고 상자는 투명(충돌 = 이 상자 하나 그대로).
--   NPC · 게시판 = 자리 기둥(Spot) 바닥에 세우고 기둥 = 투명 · 충돌 끔(프롬프트 · 이름표 자리 그대로 - 이름표만 메시 꼭대기 위로) · 굴뚝 연기.
--   메시 색 · 네온 = HubArtMeta parts(생성 표). NPC 모델 = Workspace.HubArt.HubNpc_<id>(WorldPivot = 바닥 프레임 · 클라 HubNpcView가 대기 동작).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ArtMeshKit = require(ReplicatedStorage.Shared.ArtMeshKit)
local HubArtMeta = require(ReplicatedStorage.Shared.data.HubArtMeta)
local HubArtData = require(ReplicatedStorage.Shared.data.HubArtData)
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
local function place(key, frame, parent)
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
				m.Color = rgb(pm.rgb)
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
	return buildings, npcs
end

return HubArt
