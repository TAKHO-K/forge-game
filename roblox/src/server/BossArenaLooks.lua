-- 보스맵 구조물의 겉모습(P3c B · BR1-4c c-12 레시피 - shared/data/ArenaPropData). 충돌은 BossArenaMap의 투명 기둥이 한다 - 여기 파트는 전부 충돌 · 조준 없음이고, 보이는 모양이 충돌 원 안에 들어간다
-- (맞았을 때 크기가 줄지 않는다 - P3a). 최종 에셋으로 바꿀 때 이 파일만 갈아 끼운다(모델 복제).
-- item = ArenaLayout 배치 한 칸 { kind, group, x, z, radius, rotationDeg, colliders(아레나 기준 x · z · r · h · tall) }. center = 바닥 위 한가운데(Vector3).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossArenaMapData = require(ReplicatedStorage.Shared.data.BossArenaMapData)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors) -- P3d-F B3: 금 간 단상 위험색

local BossArenaLooks = {}

local OBSTACLE = BossArenaMapData.obstacle
local SHAPES = BossArenaMapData.featureShapes

function BossArenaLooks.newPart(parent, props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.collide == true
	part.CanQuery = props.collide == true -- 충돌 없는 장식은 서버 레이캐스트(지면 · 공중 판정)에도 안 걸린다
	part.CanTouch = false
	part.CastShadow = props.shadow ~= false
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Color = props.color or Color3.new(1, 1, 1)
	part.Transparency = props.transparency or 0
	part.Size = props.size
	if props.shape == "cylinder" then
		part.Shape = Enum.PartType.Cylinder
	elseif props.shape == "ball" then
		part.Shape = Enum.PartType.Ball
	end
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CFrame = props.cframe
	part.Name = props.name or "ArenaPart"
	part.Parent = parent
	return part
end

local newPart = BossArenaLooks.newPart

-- 누운 원판(Cylinder는 로컬 X가 높이) - 윗면 Y = topY.
function BossArenaLooks.discCFrame(x, topY, z, thickness)
	return CFrame.new(x, topY - thickness / 2, z) * CFrame.Angles(0, 0, math.rad(90))
end

local function heightOf(item)
	if item.group == "big" then
		return OBSTACLE.climbHeightStuds
	end
	return OBSTACLE.heightStuds
end

-- ═══ BR1-4c c-12 레시피 빌더(shared/data/ArenaPropData - 조각 목록 × 맵 팔레트) ═══
local PROP = require(ReplicatedStorage.Shared.data.ArenaPropData)
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)

-- 톤 → 색 · 재질 · 투명도(가독성 규칙: top 밝게 · base 어둡게 · detail/crystal = 맵 장식색 · glow = 보스 머리색 빛)
local function luminance(c)
	return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
end

local function toneOf(tone, spec, bossData)
	local color, transparency = spec.color or Color3.fromRGB(128, 128, 128), spec.transparency or 0
	local map = bossData and BossArenaMapData.maps[bossData.id]
	if map and math.abs(luminance(color) - luminance(map.floor.color)) < PROP.tones.minFloorContrast then
		color = color:Lerp(BLACK, PROP.tones.contrastDarken) -- 바닥과 대비(가독성)
	end
	if tone == "top" then
		return color:Lerp(WHITE, PROP.tones.topLighten), Enum.Material.SmoothPlastic, transparency
	elseif tone == "base" then
		return color:Lerp(BLACK, PROP.tones.baseDarken), Enum.Material.SmoothPlastic, transparency
	elseif tone == "crack" then
		return color:Lerp(BLACK, PROP.tones.crackDarken), Enum.Material.SmoothPlastic, 0
	elseif tone == "detail" or tone == "crystal" then
		local d = PROP.detail[bossData and bossData.id or ""] or PROP.detail.default
		if tone == "crystal" then
			return d.color, Enum.Material.Neon, math.max(d.transparency, 0.1)
		end
		return d.color, d.material, d.transparency
	elseif tone == "glow" then
		return (bossData and bossData.headColor) or color, Enum.Material.Neon, 0
	end
	return color, Enum.Material.SmoothPlastic, transparency
end

local function piecePart(model, piece, cf, size, spec, bossData)
	local color, material, transparency = toneOf(piece.t, spec, bossData)
	if piece.s == "wedge" then
		local w = Instance.new("WedgePart")
		w.Anchored, w.CanCollide, w.CanQuery, w.CanTouch = true, false, false, false
		w.Size, w.CFrame, w.Color, w.Material, w.Transparency = size, cf, color, material, transparency
		w.TopSurface, w.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		w.Name = "Prop" .. piece.n
		w.Parent = model
		return w
	elseif piece.s == "cyl" then
		return newPart(model, { name = "Prop" .. piece.n, shape = "cylinder", size = Vector3.new(size.Y, size.X, size.Z), color = color, material = material,
			transparency = transparency, shadow = piece.t ~= "detail", cframe = cf * CFrame.Angles(0, 0, math.rad(90)) })
	end
	return newPart(model, { name = "Prop" .. piece.n, shape = piece.s == "ball" and "ball" or nil, size = piece.s == "ball" and Vector3.one * size.X or size,
		color = color, material = material, transparency = transparency, cframe = cf })
end

-- 조각 하나: origin(바닥 가운데) · yaw · r · h 기준
local function placePiece(model, piece, origin, yaw, r, h, spec, bossData)
	if piece.mound then -- 눈더미: 공 윗부분만 바닥 위(바닥 반경 = 충돌 원 × 0.85)
		local ball = (h * h + (r * 0.85) ^ 2) / (2 * h)
		return newPart(model, { name = "Prop" .. piece.n, shape = "ball", size = Vector3.one * ball * 2, color = (toneOf(piece.t, spec, bossData)),
			transparency = spec.transparency, cframe = CFrame.new(origin + Vector3.new(0, h - ball, 0)) })
	end
	local sz, at, rot = piece.size, piece.at, piece.rot or { 0, 0, 0 }
	local size = piece.u and Vector3.new(sz[1] * r, sz[2] * r, sz[3] * r) or Vector3.new(sz[1] * r, sz[2] * h, sz[3] * r)
	local cf = CFrame.new(origin) * yaw * CFrame.new(at[1] * r, at[2] * h, at[3] * r) * CFrame.Angles(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))
	return piecePart(model, piece, cf, size, spec, bossData)
end

-- 두 기둥 사이 들보(span 조각) - 들보는 캐릭터 머리보다 높다(사이로 지나간다). broken이면 반쯤 무너져 기울었다.
local function placeSpan(model, piece, item, center, spec, bossData, broken)
	local shape = SHAPES[item.kind]
	local a, b = item.colliders[1], item.colliders[2]
	local mid = Vector3.new(center.X + ((a.x + b.x) / 2 - item.x), center.Y + shape.lintelStuds + piece.at[2], center.Z + ((a.z + b.z) / 2 - item.z))
	local span = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2) + a.r * 2
	local look = CFrame.new(mid) * CFrame.Angles(0, math.rad(-item.rotationDeg), broken and math.rad(9) or 0)
	local size = Vector3.new(span * piece.size[1] * (broken and 0.7 or 1), piece.size[2], piece.size[3])
	return piecePart(model, piece, broken and (look * CFrame.new(-span * 0.15, 0, 0)) or look, size, spec, bossData)
end

local function findOverride(name)
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local folder = shared and shared:FindFirstChild("PropModels")
	local m = folder and folder:FindFirstChild(name)
	return m and m:IsA("Model") and m or nil
end

-- 레시피(또는 교체 모델)로 짓는다. 반환: 그린 파트 목록.
local function buildRecipe(model, center, item, spec, bossData)
	local override = findOverride("Arena_" .. item.kind)
	local yaw = CFrame.Angles(0, math.rad(item.rotationDeg or 0), 0)
	local parts = {}
	if override then -- A2 교체 모델: 피벗 = 바닥 가운데 · 기준 반경 refRadius에서 만든 모델을 반경 비로 키운다(발자국 = 충돌 원 계약)
		local clone = override:Clone()
		clone:ScaleTo(item.radius / PROP.library.refRadius)
		clone:PivotTo(CFrame.new(center) * yaw)
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
				d.Parent = model
				table.insert(parts, d)
			end
		end
		clone:Destroy()
		return parts
	end
	local recipe = PROP.recipes[item.kind] or PROP.recipes.block
	if recipe.perCollider then
		for index, c in ipairs(item.colliders) do
			local origin = Vector3.new(center.X + (c.x - item.x), center.Y, center.Z + (c.z - item.z))
			local pieces = recipe.variants and (recipe.variants[index] or recipe.variants[#recipe.variants]) or recipe
			for _, piece in ipairs(pieces) do
				if not piece.span then
					table.insert(parts, placePiece(model, piece, origin, yaw, c.r, c.h, spec, bossData))
				end
			end
		end
		for _, piece in ipairs(recipe) do
			if piece.span then
				table.insert(parts, placeSpan(model, piece, item, center, spec, bossData, recipe.lintel and recipe.lintel.broken))
			end
		end
	else
		for _, piece in ipairs(recipe) do
			table.insert(parts, placePiece(model, piece, center, yaw, item.radius, heightOf(item), spec, bossData))
		end
	end
	return parts
end

-- 겉모습을 짓는다. 반환: 그린 파트 목록(맞을 때 어두워지는 대상).
function BossArenaLooks.build(model, center, item, bossData)
	return buildRecipe(model, center, item, item.spec, bossData)
end

-- 금 간 표시(BR1-4c c-12 단계 - ArenaPropData.crackStages): 1단계 = 가는 금 · 2단계 = 굵은 금 + 빨간 빛 금 + 위험색 틴트(옛 P3d-F B3 모양 = 2단계).
-- 충돌 원마다 윗면에 한가운데서 뻗는 금 lines줄(가지 하나씩). 판정 자리는 그대로(겉모습만). 반환: 그린 파트 목록.
function BossArenaLooks.crack(model, center, item, stage)
	stage = stage or #PROP.crackStages
	local look = PROP.crackStages[stage]
	if look.tintFraction > 0 then
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") and part.Transparency < 1 and part.Name ~= "ObstacleCrack" then
				part.Color = part.Color:Lerp(UIColors.danger, look.tintFraction)
			end
		end
	end
	local parts = {}
	for _, c in ipairs(item.colliders) do
		local at = Vector3.new(center.X + (c.x - item.x), center.Y + c.h + 0.06, center.Z + (c.z - item.z))
		for k = 0, look.lines - 1 do
			local angle = math.rad(item.rotationDeg + k * (360 / look.lines) + 15 + (stage == 1 and 40 or 0))
			local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local length = math.max(c.r * 0.85, 1)
			table.insert(parts, newPart(model, {
				name = "ObstacleCrack", size = Vector3.new(length, 0.1, look.widthStuds), color = BossArenaMapData.outlineColor, shadow = false,
				cframe = CFrame.new(at + dir * (length / 2)) * CFrame.Angles(0, -angle, 0),
			}))
			if look.glow then -- 붕괴 예고: 금 속 빨간 빛(탑다운 · 폰에서 보이게)
				table.insert(parts, newPart(model, {
					name = "ObstacleCrack", size = Vector3.new(length * 0.8, 0.12, look.widthStuds * 0.4), color = UIColors.danger, material = Enum.Material.Neon, shadow = false,
					cframe = CFrame.new(at + dir * (length * 0.45) + Vector3.new(0, 0.02, 0)) * CFrame.Angles(0, -angle, 0),
				}))
			end
			-- 가지: 금 끝에서 30° 꺾여 반 길이
			local branch = angle + math.rad(k % 2 == 0 and 30 or -30)
			local tip = at + dir * length
			table.insert(parts, newPart(model, {
				name = "ObstacleCrack", size = Vector3.new(length * 0.45, 0.1, look.widthStuds * 0.7), color = BossArenaMapData.outlineColor, shadow = false,
				cframe = CFrame.new(tip - dir * (length * 0.3) + Vector3.new(math.cos(branch), 0, math.sin(branch)) * (length * 0.2)) * CFrame.Angles(0, -branch, 0),
			}))
		end
	end
	return parts
end

-- 남은 타격 → 균열 단계(0 = 금 없음)
function BossArenaLooks.crackStageFor(hitsLeft)
	local stage = 0
	for index, look in ipairs(PROP.crackStages) do
		if hitsLeft <= look.hitsLeft then
			stage = index
		end
	end
	return stage
end

-- 라이브러리(ReplicatedStorage.Assets.Props.Arena_<kind>): 기준 크기(refRadius) 모델 한 벌 - A2 카툰 모델 교체의 본(같은 이름을 Shared.PropModels에 두면 그걸 쓴다).
function BossArenaLooks.ensureLibrary()
	local assets = ReplicatedStorage:FindFirstChild("Assets") or Instance.new("Folder")
	assets.Name = "Assets"
	assets.Parent = ReplicatedStorage
	local props = assets:FindFirstChild(PROP.library.folder) or Instance.new("Folder")
	props.Name = PROP.library.folder
	props.Parent = assets
	local made = 0
	for kind in pairs(PROP.recipes) do
		local name = "Arena_" .. kind
		if not props:FindFirstChild(name) then
			local m = Instance.new("Model")
			m.Name = name
			local shape = SHAPES[kind]
			local colliders = {}
			for _, c in ipairs(shape and shape.colliders or { { 0, 0, PROP.library.refRadius, OBSTACLE.heightStuds } }) do
				table.insert(colliders, { x = c[1], z = c[2], r = c[3], h = c[4] })
			end
			local big = kind == "rockpile" or kind == "dolmen"
			local item = { kind = kind, group = big and "big" or (shape and "feature" or "small"), x = 0, z = 0, radius = PROP.library.refRadius, rotationDeg = 0, colliders = colliders }
			buildRecipe(m, Vector3.zero, item, { color = Color3.fromRGB(150, 150, 160) }, nil)
			m.WorldPivot = CFrame.new()
			m:SetAttribute("PropSource", findOverride(name) and "custom" or "recipe")
			m.Parent = props
			made += 1
		end
	end
	return made
end

-- 레시피 조각 수(구조물 하나 - 성능 상한 검사): kind · 충돌 원 수
function BossArenaLooks.pieceCount(kind, colliderCount)
	local recipe = PROP.recipes[kind]
	if not recipe then
		return 0
	end
	if not recipe.perCollider then
		return #recipe
	end
	local n = 0
	for index = 1, colliderCount do
		local pieces = recipe.variants and (recipe.variants[index] or recipe.variants[#recipe.variants]) or recipe
		for _, piece in ipairs(pieces) do
			n += piece.span and 0 or 1
		end
	end
	for _, piece in ipairs(recipe) do
		n += piece.span and 1 or 0
	end
	return n
end

return BossArenaLooks
