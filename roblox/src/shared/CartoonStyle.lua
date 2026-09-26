-- A1 카툰 스타일 적용기(서버). CartoonStyle.apply(프로필 이름) = CartoonStyleData.managed에 적힌 속성만 바꾼다(관리 밖 = 손대지 않음) · 두 번 불러도 결과 같음(멱등).
-- 관리 대상(= docs/art/cartoon-pipeline.md 표):
--   Lighting 속성(managed.lighting) · Lighting 자식 효과 4(managed.effects - 이름 고정 · 없으면 만든다) · Terrain 물 속성(managed.terrain) · MaterialColors(managed.terrainMaterials) ·
--   MaterialService: 폴더 CartoonStyle 안 "CartoonFlat_<재질>" 변형(텍스처 없음 = 평면 면 음영) + 그 재질의 BaseMaterialOverride ·
--   소품(Attribute Prop 모델) BasePart.CastShadow(원래 값 = Attribute CSBaseCastShadow) · Workspace Attribute CartoonStyle.
-- 서버에서 바꾼 Lighting · Terrain · MaterialService 값은 클라에 복제된다. 외곽선 · 구역 색조는 클라(OutlinePool · CartoonZoneTint)가 Workspace Attribute를 보고 그린다.

local Lighting = game:GetService("Lighting")
local MaterialService = game:GetService("MaterialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local D = require(ReplicatedStorage.Shared.data.CartoonStyleData)
local TerrainGenData = require(ReplicatedStorage.Shared.data.TerrainGenData)

local CartoonStyle = {}

local function color(v)
	if typeof(v) == "table" then
		return Color3.fromRGB(v[1], v[2], v[3])
	end
	return v
end

-- 비교용 문자열(속성은 float32 - 숫자 4자리 · 색 HEX로 맞춘다)
local function fmt(v)
	if typeof(v) == "number" then
		return ("%.4f"):format(v)
	elseif typeof(v) == "Color3" then
		return v:ToHex()
	end
	return tostring(v)
end

local function effectOf(name, spec)
	local inst = Lighting:FindFirstChild(name)
	if inst and not inst:IsA(spec.class) then
		inst = nil
	end
	if not inst then
		-- 기존 place의 효과(이름 = 클래스 기본 이름)를 먼저 찾는다: Atmosphere · Bloom · SunRays
		for _, child in ipairs(Lighting:GetChildren()) do
			if child:IsA(spec.class) and (child.Name == name or name ~= "CartoonColorCorrection") then
				inst = child
				break
			end
		end
	end
	return inst
end

-- base 프로필의 덮어쓰기 = Terrain_<재질> 변형이 있으면 그것(TerrainBake.applyVariants 자리) · 없으면 ""
local function baseOverride(material)
	local v = MaterialService:FindFirstChild(TerrainGenData.materialVariants.prefix .. material, true)
	if v and v:IsA("MaterialVariant") and v.BaseMaterial == Enum.Material[material] then
		return v.Name
	end
	return ""
end

-- 텍스처 없는 변형 = 평면 면 음영(MaterialColors 색이 그대로 먹는다 - A1 실측). ★ 게임 스크립트는 MaterialVariant.BaseMaterial을 쓸 수 없다(Plugin 권한) →
-- 변형은 Rojo 모델 파일(shared/CartoonFlatVariants.model.json - 플러그인이 씀)에 두고, 여기서는 복제해 MaterialService로 옮기기만 한다. 없는 재질 = "" (덮어쓰기 없음).
local function flatVariant(material)
	local folder = MaterialService:FindFirstChild("CartoonStyle")
	if not folder then
		local source = ReplicatedStorage.Shared:FindFirstChild("CartoonFlatVariants")
		if not source then
			return ""
		end
		folder = source:Clone()
		folder.Name = "CartoonStyle"
		folder.Parent = MaterialService
	end
	local v = folder:FindFirstChild(D.variantPrefix .. material)
	return v and v.Name or ""
end

local function eachMapPart(fn)
	local spec = D.managed.mapParts
	local ground = workspace:FindFirstChild("Ground")
	local model = ground and ground:FindFirstChild(spec.model)
	if not model then
		return
	end
	local wanted = {}
	for _, name in ipairs(spec.names) do
		wanted[name] = true
	end
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and wanted[part.Name] then
			fn(part)
		end
	end
end

local function eachPropPart(fn)
	for _, model in ipairs(workspace:GetDescendants()) do
		if model:GetAttribute("Prop") ~= nil then
			for _, part in ipairs(model:GetDescendants()) do
				if part:IsA("BasePart") then
					fn(part)
				end
			end
		end
	end
end

function CartoonStyle.apply(profileName)
	local P = D.profiles[profileName]
	assert(P, "알 수 없는 프로필: " .. tostring(profileName))
	local M = D.managed
	local counts = { lighting = 0, effects = 0, materials = 0, overrides = 0, propParts = 0 }

	for _, key in ipairs(M.lighting) do
		Lighting[key] = color(P.lighting[key])
		counts.lighting += 1
	end
	for name, spec in pairs(M.effects) do
		local values = P.effects[name]
		local inst = effectOf(name, spec)
		if not inst and values.Enabled ~= false then
			inst = Instance.new(spec.class)
			inst.Name = name
			inst.Parent = Lighting
		end
		if inst then
			for _, key in ipairs(spec.props) do
				if values[key] ~= nil then
					inst[key] = color(values[key])
				end
			end
			counts.effects += 1
		end
	end
	local terrain = workspace.Terrain
	for _, key in ipairs(M.terrain) do
		terrain[key] = color(P.terrain[key])
	end
	for _, material in ipairs(M.terrainMaterials) do
		local c = P.materialColors[material]
		if c then
			terrain:SetMaterialColor(Enum.Material[material], color(c))
			counts.materials += 1
		end
		local override = P.materialOverrides and flatVariant(material) or baseOverride(material)
		MaterialService:SetBaseMaterialOverride(Enum.Material[material], override)
		counts.overrides += override ~= "" and 1 or 0
	end
	local props = P.props
	eachPropPart(function(part)
		if part:GetAttribute("CSBaseCastShadow") == nil then
			part:SetAttribute("CSBaseCastShadow", part.CastShadow)
		end
		local small = math.max(part.Size.X, part.Size.Y, part.Size.Z) <= (props.smallMaxSize or 0)
		part.CastShadow = not (props.smallShadowOff and small) and part:GetAttribute("CSBaseCastShadow")
		counts.propParts += 1
	end)
	eachMapPart(function(part)
		part.Color = color(P.mapParts[part.Name])
	end)
	workspace:SetAttribute("CartoonStyle", profileName)
	return counts
end

-- 검증: 관리 속성의 지금 값(문자열 표 - 키 = "분류.이름")
function CartoonStyle.snapshotManaged()
	local M = D.managed
	local snap = {}
	for _, key in ipairs(M.lighting) do
		snap["lighting." .. key] = fmt(Lighting[key])
	end
	for name, spec in pairs(M.effects) do
		local inst = effectOf(name, spec)
		for _, key in ipairs(spec.props) do
			snap["effect." .. name .. "." .. key] = inst and fmt(inst[key]) or "(없음)"
		end
	end
	for _, key in ipairs(M.terrain) do
		snap["terrain." .. key] = fmt(workspace.Terrain[key])
	end
	for _, material in ipairs(M.terrainMaterials) do
		snap["materialColor." .. material] = fmt(workspace.Terrain:GetMaterialColor(Enum.Material[material]))
		snap["override." .. material] = MaterialService:GetBaseMaterialOverride(Enum.Material[material])
	end
	local shadows = {}
	eachPropPart(function(part)
		table.insert(shadows, part.CastShadow and "1" or "0")
	end)
	snap["props.castShadow"] = table.concat(shadows)
	local mapColors = {}
	eachMapPart(function(part)
		table.insert(mapColors, part.Name .. ":" .. part.Color:ToHex())
	end)
	snap["mapParts.color"] = table.concat(mapColors, ",")
	snap["workspace.CartoonStyle"] = fmt(workspace:GetAttribute("CartoonStyle"))
	return snap
end

-- 검증: 이 프로필을 적용했을 때 기대되는 관리 속성 값(snapshotManaged와 같은 키 - 소품 그림자는 원래 값 · 크기에서 계산)
function CartoonStyle.expected(profileName)
	local P = D.profiles[profileName]
	local M = D.managed
	local snap = {}
	for _, key in ipairs(M.lighting) do
		snap["lighting." .. key] = fmt(color(P.lighting[key]))
	end
	for name, spec in pairs(M.effects) do
		local inst = effectOf(name, spec)
		for _, key in ipairs(spec.props) do
			local v = P.effects[name][key]
			local want = inst and inst[key]
			if v ~= nil then
				want = color(v)
			end
			snap["effect." .. name .. "." .. key] = inst and fmt(want) or "(없음)"
		end
	end
	for _, key in ipairs(M.terrain) do
		snap["terrain." .. key] = fmt(color(P.terrain[key]))
	end
	for _, material in ipairs(M.terrainMaterials) do
		local c = P.materialColors[material]
		snap["materialColor." .. material] = c and fmt(color(c)) or fmt(workspace.Terrain:GetMaterialColor(Enum.Material[material]))
		snap["override." .. material] = P.materialOverrides and (D.variantPrefix .. material) or baseOverride(material)
	end
	local shadows = {}
	eachPropPart(function(part)
		local baseValue = part:GetAttribute("CSBaseCastShadow")
		if baseValue == nil then
			baseValue = part.CastShadow
		end
		local small = math.max(part.Size.X, part.Size.Y, part.Size.Z) <= (P.props.smallMaxSize or 0)
		table.insert(shadows, (not (P.props.smallShadowOff and small) and baseValue) and "1" or "0")
	end)
	snap["props.castShadow"] = table.concat(shadows)
	local mapColors = {}
	eachMapPart(function(part)
		table.insert(mapColors, part.Name .. ":" .. color(P.mapParts[part.Name]):ToHex())
	end)
	snap["mapParts.color"] = table.concat(mapColors, ",")
	snap["workspace.CartoonStyle"] = profileName
	return snap
end

-- 검증: 관리 밖 속성 표본(바뀌면 안 되는 것) - Lighting 시간 · 안개 · 그림자 켬 · 하늘 · 피사계 심도 · 관리 밖 재질 덮어쓰기 · 소품 색 · 재질 · 지형 복셀 표본
function CartoonStyle.snapshotUnmanaged()
	local snap = {}
	for _, key in ipairs({ "ClockTime", "GeographicLatitude", "FogEnd", "FogStart", "FogColor", "GlobalShadows" }) do
		snap["lighting." .. key] = tostring(Lighting[key])
	end
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Sky") then
			snap["sky.SkyboxUp"] = child.SkyboxUp
			snap["sky.SunAngularSize"] = tostring(child.SunAngularSize)
		elseif child:IsA("DepthOfFieldEffect") then
			snap["dof.Enabled"] = tostring(child.Enabled)
		end
	end
	local managedMaterials = {}
	for _, m in ipairs(D.managed.terrainMaterials) do
		managedMaterials[m] = true
	end
	for _, item in ipairs(Enum.Material:GetEnumItems()) do
		if not managedMaterials[item.Name] then
			local ok, v = pcall(function()
				return MaterialService:GetBaseMaterialOverride(item)
			end)
			if ok then
				snap["override." .. item.Name] = v
			end
		end
	end
	local colors, n = {}, 0
	eachPropPart(function(part)
		n += 1
		if n % 7 == 0 then
			table.insert(colors, part.Material.Name .. ":" .. part.Color:ToHex())
		end
	end)
	snap["props.colorMaterialSample"] = table.concat(colors, ",")
	local mats, occ = workspace.Terrain:ReadVoxels(Region3.new(Vector3.new(-64, -24, -64), Vector3.new(64, 40, 64)):ExpandToGrid(4), 4)
	local sum = 0
	for x = 1, mats.Size.X, 3 do
		for y = 1, mats.Size.Y, 3 do
			for z = 1, mats.Size.Z, 3 do
				sum += occ[x][y][z] + mats[x][y][z].Value * 0.001
			end
		end
	end
	snap["terrain.voxelSample"] = ("%.6f"):format(sum)
	return snap
end

-- 두 표의 차이(키 목록)
function CartoonStyle.diff(a, b)
	local out = {}
	for key, value in pairs(a) do
		if b[key] ~= value then
			table.insert(out, key)
		end
	end
	for key in pairs(b) do
		if a[key] == nil then
			table.insert(out, key)
		end
	end
	table.sort(out)
	return out
end

return CartoonStyle
