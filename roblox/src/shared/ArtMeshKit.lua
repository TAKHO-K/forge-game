-- A2-N3 Open Cloud 메시 연결 키트(서버 · 클라 공용). 캐시 = ReplicatedStorage.ArtMeshCache(서버 ArtAssetLoader가 InsertService로 채운다 - Rojo 관리 밖).
--   normalize(model)            - 가져온 모델을 리그 공간(stud · 앞 −Z)으로: × unitScale · Y yawDegrees 회전 · 원점 피벗 · 물리 끔 · SmoothPlastic.
--   get(key)                    - 캐시 모델(키 = "monsters/rock_boar" - ArtAssetIds 키) 또는 nil. 스위치(ArtStyleV1)가 꺼져 있으면 항상 nil.
--   applyRig(model, key, rigId, S, lift) - BossRig.build로 지은 리그에 메시를 끼운다(shared/MeshSwap - 관절 · 부착점 · 색 그대로) + 껍데기(_Outline) · 남는 장식 메시 용접.
--   weaponModel(classId, gradeId) - 무기 교체 모델(부착점 = MeshMeta.<직업>.attachments · 색 = 등급 look) 또는 nil → WeaponVisual 규격 검사로 간다.
--   모두 겉모습만: 판정 파트(루트 · Hitbox · query 파트의 CanQuery)는 MeshSwap이 옛 파트 값을 옮긴다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage.Shared.data.ArtImportData)
local ArtStyleV1Data = require(ReplicatedStorage.Shared.data.ArtStyleV1Data)
local MeshImportCheckData = require(ReplicatedStorage.Shared.data.MeshImportCheckData)
local MeshSwap = require(ReplicatedStorage.Shared.MeshSwap)
local MeshImportCheck = require(ReplicatedStorage.Shared.MeshImportCheck)
local WeaponRigSpec = require(ReplicatedStorage.Shared.data.WeaponRigSpec)
local WeaponRigCheck = require(ReplicatedStorage.Shared.WeaponRigCheck)
local GearV3 = require(ReplicatedStorage.Shared.GearV3) -- QUEUE-ALL9E1 1-1 장비 v3 무기

local ArtMeshKit = {}

function ArtMeshKit.enabled()
	return workspace:GetAttribute(ArtStyleV1Data.attribute) == true
end

function ArtMeshKit.normalize(model)
	local S = Data.unitScale
	local turn = CFrame.Angles(0, math.rad(Data.yawDegrees), 0)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local cf = d.CFrame
			local pivot = d.PivotOffset -- Blender 원점(= 관절 자리)이 cm로 남아 있다 → 같이 줄인다(MeshImportCheck ② 관절 = 파트 피벗)
			d.Size = d.Size * S
			d.PivotOffset = CFrame.new(pivot.Position * S) * pivot.Rotation
			d.CFrame = turn * (CFrame.new(cf.Position * S) * cf.Rotation)
			d.Anchored = true
			d.CanCollide, d.CanTouch, d.CanQuery = false, false, false
			d.Material = Enum.Material.SmoothPlastic
		end
	end
	model.WorldPivot = CFrame.identity
	return model
end

function ArtMeshKit.get(key)
	if not ArtMeshKit.enabled() then
		return nil
	end
	local folder = ReplicatedStorage:FindFirstChild(Data.cacheFolder)
	local m = folder and folder:FindFirstChild(key)
	return (m and m:IsA("Model")) and m or nil
end

local function metaFor(rigId)
	local folder = ReplicatedStorage.Shared:FindFirstChild(MeshImportCheckData.metaFolder)
	local mod = folder and folder:FindFirstChild(rigId)
	if mod and mod:IsA("ModuleScript") then
		local ok, meta = pcall(require, mod)
		return ok and meta or nil
	end
	return nil
end
ArtMeshKit.metaFor = metaFor

-- 리그에 메시 끼우기. 반환 count, lines(X일 때만 경고 1줄 - 호출 쪽이 찍는다).
function ArtMeshKit.applyRig(model, key, rigId, S, lift)
	local src = ArtMeshKit.get(key)
	if not src then
		return 0
	end
	local exp = MeshImportCheck.expected(rigId, 1)
	local rigNames = exp and exp.parts or {}
	-- 코드 장식(A2-M1 BossDetailSpec deco - 부모 부위에 용접)은 부모가 새 메시로 바뀌면 용접이 끊긴다 → 먼저 지운다(메시 쪽 장식 = 몸 파트에 합침 또는 아래 따로 용접)
	for _, d in ipairs(model:GetChildren()) do
		if d:IsA("BasePart") and not rigNames[d.Name] and d.Name ~= "HumanoidRootPart" and d.Name ~= "Hitbox" and d:FindFirstChildOfClass("WeldConstraint") then
			d:Destroy()
		end
	end
	-- 판정 불변: 조준 · 판정 파트(규격 query = true - 보스 Body · Head)는 옛 상자를 투명 사본(<이름>_Query)으로 남겨 새 메시에 용접하고, 새 메시는 조준에 안 걸린다
	local queryKeep = {}
	for name, e in pairs(rigNames) do
		local old = e.query and model:FindFirstChild(name)
		if old and old:IsA("BasePart") then
			local q = old:Clone()
			q:ClearAllChildren()
			q.Name = name .. "_Query"
			q.Transparency = 1
			q.CastShadow = false
			queryKeep[name] = q
		end
	end
	local count, lines, refCF = MeshSwap.swap(model, src, rigId, { scale = S, meta = metaFor(rigId), lift = lift })
	for name, q in pairs(queryKeep) do
		local mesh = model:FindFirstChild(name)
		if mesh and mesh ~= q then
			mesh.CanQuery = false
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = mesh, q
			w.Parent = q
			q.Parent = model
		else
			q:Destroy()
		end
	end
	-- BOSS-FRAMEWORK 7 KIT 메시: 메타 texture(아틀라스 - ArtAssetIds image id)를 입는 부위에 TextureID · 색 흰색(텍스처 색 그대로 - 겉모습만)
	local texMeta = metaFor(rigId)
	texMeta = texMeta and texMeta.texture
	if texMeta then
		local ArtAssetIds = require(ReplicatedStorage.Shared.data.ArtAssetIds)
		local e = ArtAssetIds[texMeta.atlas]
		if e and e.image then
			for name in pairs(texMeta.parts or {}) do
				local mesh = model:FindFirstChild(name)
				if mesh and mesh:IsA("MeshPart") then
					mesh.TextureID = "rbxassetid://" .. tostring(e.image)
					mesh.Color = Color3.new(1, 1, 1)
				end
			end
		end
	end
	if not refCF then
		return count, lines
	end
	-- 남는 메시(껍데기 · 합치지 않은 장식): 가져온 자리 그대로 붙은 부위에 용접
	local root = model:FindFirstChild("HumanoidRootPart")
	local base = root.CFrame * CFrame.new(0, lift or 0, 0)
	local meta = metaFor(rigId)
	local outlines = 0
	for _, p in ipairs(src:GetChildren()) do
		if p:IsA("BasePart") and not rigNames[p.Name] then
			local isOutline = p.Name:sub(-#Data.outlineSuffix) == Data.outlineSuffix
			local hostName = isOutline and p.Name:sub(1, -#Data.outlineSuffix - 1) or (meta and meta.deco and meta.deco[p.Name])
			local host = hostName and model:FindFirstChild(hostName)
			if host and host:IsA("BasePart") then
				local rel = refCF:ToObjectSpace(p.CFrame)
				local m = p:Clone()
				m.Size = p.Size * S
				m.CFrame = base * (CFrame.new(rel.Position * S) * rel.Rotation)
				m.Anchored, m.Massless = false, true
				m.CanCollide, m.CanTouch, m.CanQuery = false, false, false
				m.CastShadow = false
				local pm = meta and meta.parts and meta.parts[p.Name]
				local mat = meta and meta.decoMaterial and meta.decoMaterial[p.Name]
				m.Color = isOutline and (Data.outlineColorOf and Data.outlineColorOf[rigId] or ArtStyleV1Data.ink) or (pm and pm.color and Color3.fromHex(pm.color)) or host.Color -- 장식 묶음 색 = 메타(테마 색 기준 Blender 색)
				m.Material = isOutline and Enum.Material.SmoothPlastic or (mat and Enum.Material[mat]) or host.Material
				if meta and meta.lod2 and meta.lod2[p.Name] then
					m:SetAttribute("DetailLod", 2) -- 폰 · 먼 거리에서 숨김(BossAnimator updateDetailLod)
				end
				local w = Instance.new("WeldConstraint")
				w.Part0, w.Part1 = host, m
				w.Parent = m
				m.Parent = model
				if isOutline then
					outlines += 1
				end
			end
		end
	end
	if outlines > 0 then
		model:SetAttribute("MeshOutline", true) -- 외곽선 풀(OutlinePool)이 어두운 Highlight를 달지 않는다(조준 외곽선은 그대로)
	end
	model:SetAttribute("ArtMesh", key)
	return count, lines
end

-- 소품 겉모습 입히기(킷 · 제단): 같은 이름 코드 파트 자리에 메시를 겹치고 코드 파트는 투명(충돌 · 조준 · 프롬프트 자리 그대로 = 판정 불변).
--   frame = 메시 공간 원점이 오는 자리(라이브러리 틀 = 원점 · 제단 = 바닥 가운데). 색 · 재질 = 코드 파트 그대로. 반환 입힌 수.
function ArtMeshKit.skin(model, key, frame, scale)
	local src = ArtMeshKit.get(key)
	if not src then
		return 0
	end
	local n = 0
	for _, p in ipairs(src:GetChildren()) do
		local target = p:IsA("BasePart") and model:FindFirstChild(p.Name, true)
		if target and target:IsA("BasePart") then
			local m = p:Clone()
			m.Name = p.Name .. "_Mesh"
			if scale and scale ~= Vector3.one then -- 배치 배율(축마다 - PropLibrary applyScale과 같은 식 · 메시는 회전 0으로 구워져 축 = 배율 성분)
				m.Size = p.Size * scale
				m.CFrame = frame * (CFrame.new(p.Position * scale) * p.CFrame.Rotation)
			else
				m.CFrame = frame * p.CFrame
			end
			m.Color, m.Material = target.Color, target.Material
			m.Anchored = target.Anchored
			m.CanCollide, m.CanTouch, m.CanQuery = false, false, false
			m.CastShadow = target.CastShadow
			if not target.Anchored then
				local w = Instance.new("WeldConstraint")
				w.Part0, w.Part1 = target, m
				w.Parent = m
			end
			target.Transparency = 1
			m.Parent = target.Parent
			n += 1
		end
	end
	model:SetAttribute("ArtMesh", key)
	return n
end

-- 방어구 구역(아이콘 · 착용 표시 공용): item.setZone(세트 계열 - SAVE v49) · 없으면 그 itemLevel이 닿는 보스 스테이지(보스 간격 올림)의 보스 구역. 겉모습만.
function ArtMeshKit.armorZone(item)
	local setZone = type(item) == "table" and item.setZone or nil
	if type(setZone) == "string" and setZone:match("^tier%d$") then
		return setZone
	end
	local BossRules = require(ReplicatedStorage.Shared.BossRules)
	local BossData = require(ReplicatedStorage.Shared.data.BossData)
	local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
	local interval = BossData.stageInterval or 5
	local level = type(item) == "table" and item.itemLevel or 1
	local bossId = BossRules.bossIdForStage(math.max(1, math.ceil(level / interval)) * interval)
	for _, z in ipairs(WorldMapData.zones or {}) do
		if z.bossId == bossId then
			return z.key
		end
	end
	return "tier1"
end

local function hex(s)
	return Color3.fromHex(s)
end

-- 무기 교체 모델(복제본 - 호출 쪽이 Destroy). 파트 색 · 네온 = 메타 look · 부착점 = PrimaryPart(Blade 또는 첫 파트) 아래 Attachment.
function ArtMeshKit.weaponModel(classId, gradeId, options) -- options.keepDropParts = 코드가 그리는 부분(활 시위)을 메시로 남김(무대 - 그리는 코드 없음)
	if not Data.weaponClasses[classId] then
		return nil
	end
	local look = Data.weaponGradeFile[gradeId] or "normal"
	-- QUEUE-ALL9E1 1-1 장비 v3: 스위치 GearV3Meshes · weapons/<직업>_<단계>(s1 ~ s5 - 같은 손잡이 원점 · 부착점 = 옛 메타) · 색 = GearV3.weaponColor(구역) · 문 부품(초월 균열 Tr) = 그 등급만
	local stage = GearV3.enabled() and GearV3.data.stageOfGrade[gradeId]
	local v3src = stage and ArtMeshKit.get("weapons/" .. classId .. "_" .. stage)
	local src = v3src or ArtMeshKit.get("weapons/" .. classId .. "_" .. look)
	local meta = metaFor(classId)
	if not src or not meta then
		return nil
	end
	local model = src:Clone()
	local lookMeta = meta.looks and meta.looks[look]
	if v3src then
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") and not GearV3.visible(p.Name, gradeId) then
				p:Destroy()
			end
		end
	end
	local primary = model:FindFirstChild(v3src and "Blade_Body" or "Blade") or model:FindFirstChild(v3src and "Head_Body" or "Head") or model:FindFirstChildWhichIsA("BasePart")
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			if v3src then
				local color, neon = GearV3.weaponColor(p.Name, gradeId)
				p.Color = color
				p.Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
			else
				local pm = lookMeta and lookMeta.parts[p.Name]
				if pm then
					p.Color = hex(pm.color)
					p.Material = pm.neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
				end
			end
			p.CastShadow = false
		end
	end
	-- 규격 길이 맞춤: A2-N1 메시는 WeaponRigSpec refLength와 길이가 다를 수 있다(쌍검 3.30 vs 2.60) → 손잡이(원점) 기준으로 같은 비율로 줄여 규격 길이에 맞춘다(모양 비율 · 손잡이 자리 그대로)
	local f = 1
	local piece = WeaponRigSpec.weapons[classId] and WeaponRigSpec.weapons[classId].pieces[1]
	local axis = piece and WeaponRigCheck.AXES[piece.tipAxis]
	if axis then
		local lo, hi = math.huge, -math.huge
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then
				local h = p.Size / 2
				local ext = math.abs(p.CFrame.RightVector:Dot(axis)) * h.X + math.abs(p.CFrame.UpVector:Dot(axis)) * h.Y + math.abs(p.CFrame.LookVector:Dot(axis)) * h.Z
				local c = p.Position:Dot(axis)
				lo, hi = math.min(lo, c - ext), math.max(hi, c + ext)
			end
		end
		local length = hi - lo
		if length > 0 and math.abs(length - piece.refLength) > piece.refLength * WeaponRigSpec.check.lengthTolerance * 0.5 then
			f = piece.refLength / length
			for _, p in ipairs(model:GetDescendants()) do
				if p:IsA("BasePart") then
					p.Size *= f
					p.CFrame = CFrame.new(p.Position * f) * p.CFrame.Rotation
				end
			end
		end
	end
	for name, at in pairs(meta.attachments or {}) do
		local a = Instance.new("Attachment")
		a.Name = name
		a.Position = primary.CFrame:PointToObjectSpace(Vector3.new(at[1], at[2], at[3]) * f)
		a.Parent = primary
	end
	local tip = meta.attachments and meta.attachments.Tip
	if tip then -- 칼날 리본(WeaponVisual attachTrail - PrimaryPart 로컬): 손잡이 → Tip 선의 92% · 25% 자리
		local t = Vector3.new(tip[1], tip[2], tip[3]) * f
		model:SetAttribute("TrailTop", primary.CFrame:PointToObjectSpace(t * 0.92))
		model:SetAttribute("TrailBottom", primary.CFrame:PointToObjectSpace(t * 0.25))
	end
	model.PrimaryPart = primary
	-- A2-N4 P0-2: PrimaryPart가 있으면 피벗 = PrimaryPart.CFrame × PivotOffset이다 - 정규화(Y180)로 돈 파트 회전이 피벗에 남아 칼끝 · 날 · 시위 쪽이 180° 뒤집혔다(옛 WorldPivot 대입은 무시됨) → 피벗을 리그 원점으로 못 박는다
	primary.PivotOffset = primary.CFrame:Inverse()
	model.WorldPivot = CFrame.identity
	for _, name in ipairs(not (options and options.keepDropParts) and Data.weaponDropParts[classId] or {}) do -- 코드가 그리는 부분(활 시위)은 메시에서 뺀다
		for _, d in ipairs(model:GetChildren()) do
			if d.Name == name or d.Name:sub(1, #name + 1) == name .. "_" then -- v3 = <이름>_<구역>
				d:Destroy()
			end
		end
	end
	local pieces = Data.weaponPieces[classId]
	if pieces then -- 조각이 여럿인 무기(쌍검 BladeRight · BladeLeft): 같은 모델을 조각 이름으로 복제(WeaponVisual overrideModel이 조각 이름으로 찾는다)
		local box = Instance.new("Model")
		box.Name = model.Name
		for _, pieceName in ipairs(pieces) do
			local c = model:Clone()
			c.Name = pieceName
			c.Parent = box
		end
		model:Destroy()
		return box
	end
	return model
end

return ArtMeshKit
