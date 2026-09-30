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
				m.Color = isOutline and ArtStyleV1Data.ink or host.Color
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

local function hex(s)
	return Color3.fromHex(s)
end

-- 무기 교체 모델(복제본 - 호출 쪽이 Destroy). 파트 색 · 네온 = 메타 look · 부착점 = PrimaryPart(Blade 또는 첫 파트) 아래 Attachment.
function ArtMeshKit.weaponModel(classId, gradeId)
	if not Data.weaponClasses[classId] then
		return nil
	end
	local look = Data.weaponGradeFile[gradeId] or "normal"
	local src = ArtMeshKit.get("weapons/" .. classId .. "_" .. look)
	local meta = metaFor(classId)
	if not src or not meta then
		return nil
	end
	local model = src:Clone()
	local lookMeta = meta.looks and meta.looks[look]
	local primary = model:FindFirstChild("Blade") or model:FindFirstChild("Head") or model:FindFirstChildWhichIsA("BasePart")
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			local pm = lookMeta and lookMeta.parts[p.Name]
			if pm then
				p.Color = hex(pm.color)
				p.Material = pm.neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
			end
			p.CastShadow = false
		end
	end
	for name, at in pairs(meta.attachments or {}) do
		local a = Instance.new("Attachment")
		a.Name = name
		a.Position = primary.CFrame:PointToObjectSpace(Vector3.new(at[1], at[2], at[3]))
		a.Parent = primary
	end
	local tip = meta.attachments and meta.attachments.Tip
	if tip then -- 칼날 리본(WeaponVisual attachTrail - PrimaryPart 로컬): 손잡이 → Tip 선의 92% · 25% 자리
		local t = Vector3.new(tip[1], tip[2], tip[3])
		model:SetAttribute("TrailTop", primary.CFrame:PointToObjectSpace(t * 0.92))
		model:SetAttribute("TrailBottom", primary.CFrame:PointToObjectSpace(t * 0.25))
	end
	model.PrimaryPart = primary
	model.WorldPivot = CFrame.identity
	for _, name in ipairs(Data.weaponDropParts[classId] or {}) do -- 코드가 그리는 부분(활 시위)은 메시에서 뺀다
		local d = model:FindFirstChild(name)
		if d then
			d:Destroy()
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
