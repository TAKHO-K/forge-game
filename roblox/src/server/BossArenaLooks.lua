-- 보스맵 구조물의 겉모습(P3c B - kind별 빌더). 충돌은 BossArenaMap의 투명 기둥이 한다 - 여기 파트는 전부 충돌 · 조준 없음이고, 보이는 모양이 충돌 원 안에 들어간다
-- (맞았을 때 크기가 줄지 않는다 - P3a). 최종 에셋으로 바꿀 때 이 파일만 갈아 끼운다(모델 복제).
-- item = ArenaLayout 배치 한 칸 { kind, group, x, z, radius, rotationDeg, colliders(아레나 기준 x · z · r · h · tall) }. center = 바닥 위 한가운데(Vector3).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossArenaMapData = require(ReplicatedStorage.Shared.data.BossArenaMapData)

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

-- 선 원기둥(세로) - 밑면 Y = baseY.
local function uprightCylinder(model, name, x, baseY, z, radius, height, color, transparency)
	return newPart(model, {
		name = name, shape = "cylinder", size = Vector3.new(height, radius * 2, radius * 2), color = color, transparency = transparency,
		cframe = CFrame.new(x, baseY + height / 2, z) * CFrame.Angles(0, 0, math.rad(90)),
	})
end

local function heightOf(item)
	if item.group == "big" then
		return OBSTACLE.climbHeightStuds
	end
	return OBSTACLE.heightStuds
end

local LOOKS = {}

-- ═══ 작은 구조물(P3a 모양 그대로) ═══
function LOOKS.boulder(model, center, item, spec)
	local r = item.radius
	local side = (item.id % 2 == 0) and 1 or -1
	return {
		newPart(model, { name = "ObstacleRock", shape = "ball", size = Vector3.new(r * 2, r * 2, r * 2), color = spec.color, transparency = spec.transparency, cframe = CFrame.new(center + Vector3.new(0, r * 0.75, 0)) }),
		newPart(model, { name = "ObstacleRock", shape = "ball", size = Vector3.new(r, r, r) * 1.05, color = spec.color, transparency = spec.transparency,
			cframe = CFrame.new(center + Vector3.new(r * 0.3 * side, r * 0.3, r * 0.2)) }),
	}
end

function LOOKS.block(model, center, item, spec)
	local r, h = item.radius, heightOf(item)
	return {
		newPart(model, { name = "ObstacleBlock", size = Vector3.new(r * 1.35, h + 0.5, r * 1.2), color = spec.color, transparency = spec.transparency,
			cframe = CFrame.new(center + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, math.rad(item.rotationDeg), math.rad(6)) }),
		newPart(model, { name = "ObstacleBlock", size = Vector3.new(r * 0.6, r * 0.7, r * 0.6), color = spec.color, transparency = spec.transparency,
			cframe = CFrame.new(center + Vector3.new(r * 0.3, r * 0.35, -r * 0.25)) * CFrame.Angles(math.rad(10), math.rad(item.rotationDeg + 53), 0) }),
	}
end

function LOOKS.stump(model, center, item, spec)
	local r, h = item.radius, heightOf(item)
	return {
		uprightCylinder(model, "ObstacleStump", center.X, center.Y, center.Z, r * 0.95, h + 0.5, spec.color, spec.transparency),
		newPart(model, { name = "ObstacleStump", size = Vector3.new(r * 1.3, 1.2, r * 1.3), color = spec.color, transparency = spec.transparency,
			cframe = CFrame.new(center + Vector3.new(0, h + 0.8, 0)) * CFrame.Angles(math.rad(8), math.rad(item.rotationDeg), math.rad(-6)) }),
	}
end

function LOOKS.cluster(model, center, item, spec)
	local r, h = item.radius, heightOf(item)
	local parts = {}
	for k = 0, 2 do
		local angle = math.rad(k * 120 + item.rotationDeg)
		local height = h + 1 - k * 1.2
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (k == 0 and 0 or r * 0.5)
		table.insert(parts, newPart(model, {
			name = "ObstacleCrystal", size = Vector3.new(r * 0.7, height, r * 0.7), color = spec.color, transparency = spec.transparency,
			cframe = CFrame.new(center + offset + Vector3.new(0, height / 2, 0)) * CFrame.Angles(math.rad(k * 9), math.rad(k * 40 + 20), math.rad(-k * 12)),
		}))
	end
	return parts
end

-- ═══ 큰 블록(B2 - 윗면 climbHeightStuds에 올라선다) ═══
-- 돌무더기: 가운데 낮은 원통(보이는 윗면 = 실제로 서는 면) + 둘레에 둥근 돌 일곱이 뭉친 모양.
function LOOKS.rockpile(model, center, item, spec)
	local r, h = item.radius, OBSTACLE.climbHeightStuds
	local parts = { uprightCylinder(model, "ObstacleRockpileCore", center.X, center.Y, center.Z, r - 0.6, h, spec.color, spec.transparency) }
	for k = 0, 6 do
		local angle = math.rad(item.rotationDeg + k * 360 / 7 + (k % 2) * 11)
		local size = 1.6 + (k % 3) * 0.15 -- 공 반경 - 꼭대기(1.8 × 반경)가 윗면(3.5)을 넘지 않는다
		local at = center + Vector3.new(math.cos(angle) * (r - size), size * 0.8, math.sin(angle) * (r - size))
		table.insert(parts, newPart(model, {
			name = "ObstacleRockpileStone", shape = "ball", size = Vector3.new(size, size, size) * 2, color = spec.color:Lerp(Color3.new(0, 0, 0), 0.08 * (k % 3)),
			transparency = spec.transparency, cframe = CFrame.new(at),
		}))
	end
	return parts
end

-- 고인돌: 받침돌 셋 위에 둥근 판돌(판 윗면 = 서는 면). 판의 반경 = 충돌 원 반경.
function LOOKS.dolmen(model, center, item, spec)
	local r, h = item.radius, OBSTACLE.climbHeightStuds
	local slab = 0.9
	local parts = {}
	for k = 0, 2 do
		local angle = math.rad(item.rotationDeg + k * 120)
		local legHeight = h - slab
		table.insert(parts, newPart(model, {
			name = "ObstacleDolmenLeg", size = Vector3.new(2, legHeight, 2.6), color = spec.color:Lerp(Color3.new(0, 0, 0), 0.12), transparency = spec.transparency,
			cframe = CFrame.new(center + Vector3.new(math.cos(angle) * r * 0.55, legHeight / 2, math.sin(angle) * r * 0.55)) * CFrame.Angles(0, -angle, math.rad(4)),
		}))
	end
	table.insert(parts, newPart(model, {
		name = "ObstacleDolmenSlab", shape = "cylinder", size = Vector3.new(slab, r * 2, r * 2), color = spec.color, transparency = spec.transparency,
		cframe = BossArenaLooks.discCFrame(center.X, center.Y + h, center.Z, slab),
	}))
	return parts
end

-- ═══ 작은 지형지물(B3) - 충돌 원마다 한 덩어리 ═══
local function eachCollider(item, center, fn)
	local parts = {}
	for index, c in ipairs(item.colliders) do
		local at = Vector3.new(center.X + (c.x - item.x), center.Y, center.Z + (c.z - item.z))
		for _, part in ipairs(fn(at, c, index)) do
			table.insert(parts, part)
		end
	end
	return parts
end

function LOOKS.icePillars(model, center, item, spec)
	return eachCollider(item, center, function(at, c)
		return {
			uprightCylinder(model, "FeatureIcePillar", at.X, at.Y, at.Z, c.r * 0.9, c.h - 0.6, spec.color, spec.transparency),
			newPart(model, { name = "FeatureIceTip", shape = "ball", size = Vector3.new(c.r * 1.6, c.r * 1.6, c.r * 1.6), color = spec.color, transparency = spec.transparency,
				cframe = CFrame.new(at + Vector3.new(0, c.h - 0.8, 0)) }),
		}
	end)
end

function LOOKS.snowMound(model, center, item, spec)
	return eachCollider(item, center, function(at, c)
		-- 공의 윗부분만 바닥 위로 - 바닥에서의 반경이 충돌 원 안이다.
		local ballRadius = (c.h * c.h + (c.r * 0.85) ^ 2) / (2 * c.h)
		return { newPart(model, { name = "FeatureSnowMound", shape = "ball", size = Vector3.new(ballRadius, ballRadius, ballRadius) * 2, color = spec.color, transparency = spec.transparency,
			cframe = CFrame.new(at + Vector3.new(0, c.h - ballRadius, 0)) }) }
	end)
end

function LOOKS.statue(model, center, item, spec)
	return eachCollider(item, center, function(at, c)
		local yaw = CFrame.Angles(0, math.rad(item.rotationDeg), 0)
		return {
			newPart(model, { name = "FeatureStatuePlinth", size = Vector3.new(2.6, 1.5, 2.6), color = spec.color:Lerp(Color3.new(0, 0, 0), 0.15), cframe = CFrame.new(at + Vector3.new(0, 0.75, 0)) * yaw }),
			newPart(model, { name = "FeatureStatueBody", size = Vector3.new(1.6, 4, 1.1), color = spec.color, cframe = CFrame.new(at + Vector3.new(0, 3.5, 0)) * yaw }),
			newPart(model, { name = "FeatureStatueHead", shape = "ball", size = Vector3.new(1.4, 1.4, 1.4), color = spec.color, cframe = CFrame.new(at + Vector3.new(0, 6.2, 0)) }),
		}
	end)
end

-- 두 기둥 + 위를 가로지르는 들보(들보는 캐릭터 머리보다 높다 - 사이로 지나간다). broken이면 들보가 반쯤 무너져 기울었다.
local function gate(model, center, item, spec, legShape, broken)
	local shape = SHAPES[item.kind]
	local parts = eachCollider(item, center, function(at, c)
		if legShape == "cylinder" then
			return { uprightCylinder(model, "FeatureGateLeg", at.X, at.Y, at.Z, c.r, c.h, spec.color, spec.transparency) }
		end
		local side = c.r * 1.35
		return { newPart(model, { name = "FeatureGateLeg", size = Vector3.new(side, c.h, side), color = spec.color, transparency = spec.transparency,
			cframe = CFrame.new(at + Vector3.new(0, c.h / 2, 0)) * CFrame.Angles(0, math.rad(item.rotationDeg), 0) }) }
	end)
	local a, b = item.colliders[1], item.colliders[2]
	local mid = Vector3.new(center.X + ((a.x + b.x) / 2 - item.x), center.Y + shape.lintelStuds + 0.6, center.Z + ((a.z + b.z) / 2 - item.z))
	local span = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2) + a.r * 2
	local look = CFrame.new(mid) * CFrame.Angles(0, math.rad(-item.rotationDeg), broken and math.rad(9) or 0)
	table.insert(parts, newPart(model, { name = "FeatureGateLintel", size = Vector3.new(broken and span * 0.7 or span, 1.2, 2), color = spec.color, transparency = spec.transparency,
		cframe = broken and (look * CFrame.new(-span * 0.15, 0, 0)) or look }))
	return parts
end

function LOOKS.brokenArch(model, center, item, spec)
	return gate(model, center, item, spec, "cylinder", true)
end

function LOOKS.ruinGate(model, center, item, spec)
	return gate(model, center, item, spec, "block", false)
end

function LOOKS.crystalCluster(model, center, item, spec)
	return eachCollider(item, center, function(at, c, index)
		return { newPart(model, { name = "FeatureCrystal", size = Vector3.new(c.r * 1.3, c.h, c.r * 1.3), color = spec.color, transparency = spec.transparency, material = Enum.Material.Neon,
			cframe = CFrame.new(at + Vector3.new(0, c.h / 2, 0)) * CFrame.Angles(math.rad(index * 5), math.rad(item.rotationDeg + index * 40), math.rad(-index * 4)) }) }
	end)
end

function LOOKS.ruinFragment(model, center, item, spec)
	return eachCollider(item, center, function(at, c)
		return {
			newPart(model, { name = "FeatureRuinFragment", size = Vector3.new(c.r * 1.35, c.h, c.r * 1.05), color = spec.color, transparency = spec.transparency,
				cframe = CFrame.new(at + Vector3.new(0, c.h / 2, 0)) * CFrame.Angles(0, math.rad(item.rotationDeg), math.rad(5)) }),
		}
	end)
end

function LOOKS.cactus(model, center, item, spec)
	return eachCollider(item, center, function(at, c)
		local yaw = math.rad(item.rotationDeg)
		local dir = Vector3.new(math.cos(yaw), 0, math.sin(yaw))
		return {
			uprightCylinder(model, "FeatureCactus", at.X, at.Y, at.Z, 0.7, c.h, spec.color),
			uprightCylinder(model, "FeatureCactusArm", at.X + dir.X * 0.85, at.Y + 2.4, at.Z + dir.Z * 0.85, 0.3, 2, spec.color),
			uprightCylinder(model, "FeatureCactusArm", at.X - dir.X * 0.85, at.Y + 3.2, at.Z - dir.Z * 0.85, 0.3, 1.6, spec.color),
		}
	end)
end

function LOOKS.rodWreck(model, center, item, spec)
	return eachCollider(item, center, function(at, c, index)
		if index == 1 then
			return {
				newPart(model, { name = "FeatureRodBase", size = Vector3.new(1.1, 0.5, 1.1), color = spec.color, cframe = CFrame.new(at + Vector3.new(0, 0.25, 0)) }),
				newPart(model, { name = "FeatureRod", size = Vector3.new(0.5, c.h, 0.5), color = spec.color, material = Enum.Material.Metal,
					cframe = CFrame.new(at + Vector3.new(0, c.h / 2, 0)) * CFrame.Angles(math.rad(6), 0, math.rad(-5)) }),
			}
		end
		return { newPart(model, { name = "FeatureRodDebris", size = Vector3.new(c.r * 1.3, c.h, c.r * 1.2), color = spec.color:Lerp(Color3.new(0, 0, 0), 0.2),
			cframe = CFrame.new(at + Vector3.new(0, c.h / 2, 0)) * CFrame.Angles(0, math.rad(item.rotationDeg + 30), math.rad(12)) }) }
	end)
end

function LOOKS.rubble(model, center, item, spec)
	return eachCollider(item, center, function(at, c, index)
		return { newPart(model, { name = "FeatureRubble", size = Vector3.new(c.r * 1.35, c.h, c.r * 1.2), color = spec.color, transparency = spec.transparency,
			cframe = CFrame.new(at + Vector3.new(0, c.h / 2, 0)) * CFrame.Angles(math.rad(index * 6), math.rad(item.rotationDeg + index * 47), 0) }) }
	end)
end

function LOOKS.runeStones(model, center, item, spec, bossData)
	return eachCollider(item, center, function(at, c)
		local yaw = CFrame.Angles(0, math.rad(item.rotationDeg), 0)
		return {
			newPart(model, { name = "FeatureRuneStone", size = Vector3.new(1.3, c.h, 0.9), color = spec.color, cframe = CFrame.new(at + Vector3.new(0, c.h / 2, 0)) * yaw }),
			newPart(model, { name = "FeatureRuneGlow", size = Vector3.new(0.6, 0.6, 0.95), color = bossData and bossData.headColor or spec.color, material = Enum.Material.Neon, shadow = false,
				cframe = CFrame.new(at + Vector3.new(0, c.h * 0.6, 0)) * yaw }),
		}
	end)
end

-- 겉모습을 짓는다. 반환: 그린 파트 목록(맞을 때 어두워지는 대상).
function BossArenaLooks.build(model, center, item, bossData)
	local look = LOOKS[item.kind] or LOOKS.block
	return look(model, center, item, item.spec, bossData)
end

-- B2 금 간 표시(부서지기 직전): 충돌 원마다 윗면에 어두운 금 세 줄(기존 외곽선 색). 반환: 그린 파트 목록.
function BossArenaLooks.crack(model, center, item)
	local parts = {}
	for _, c in ipairs(item.colliders) do
		local at = Vector3.new(center.X + (c.x - item.x), center.Y + c.h + 0.06, center.Z + (c.z - item.z))
		for k = 0, 2 do
			local angle = math.rad(item.rotationDeg + k * 62 + 15)
			local length = math.max(c.r * 1.4, 1)
			table.insert(parts, newPart(model, {
				name = "ObstacleCrack", size = Vector3.new(length, 0.1, 0.25), color = BossArenaMapData.outlineColor, shadow = false,
				cframe = CFrame.new(at + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (c.r * 0.2)) * CFrame.Angles(0, -angle, 0),
			}))
		end
	end
	return parts
end

return BossArenaLooks
