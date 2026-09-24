-- 원형 보스 아레나 맵(P3a C) - 슬롯마다 기반(바닥 · 벽 고리 · 테라스)을 한 번 짓고, 보스전마다 그 보스의 테마(BossArenaMapData.maps[보스 id])로 색 · 재질을 바꾸고
-- 장식 · 구조물을 짓는다(보스전이 끝나면 치운다). 모양 · 색 · 자리는 전부 데이터 - 여기는 kind별 빌더만 안다(최종 에셋으로 바꿀 때 이 빌더만 고친다).
--
-- 구조물(사용자 지시): 충돌하는 자연 지형지물. ① 걸어서 못 지나간다 - 투명 충돌 기둥이 지면 폴더(GroundProbe)에 있어 보스 걸음도 계단보다 높은 턱으로 보고 비켜 간다
-- ② 보스 돌진이 부딪히면 돌진이 거기서 끝나고(예고 선도 거기까지 - 보이는 것 = 판정) 구조물이 부서지며 헤롱이 길어진다(BossPatterns가 firstOnPath · breakObstacle을 부른다)
-- ③ 플레이어가 hitsToBreak번 때리면 부서진다(조준 대상 - Monster 태그 + 구출 대상과 같은 "맞으면 알림만" 엔티티) ④ 보스가 한 구조물 곁을 smashAfterLaps바퀴만큼
-- 맴돌면 보스가 부순다(뺑뺑이 방지) ⑤ 부서질 때 멤버의 클라가 파편을 그린다(BossArenaObstacleBreak). 전멸 리셋이면 처음대로 다시 선다.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local BossArenaMapData = require(ReplicatedStorage.Shared.data.BossArenaMapData)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local ArenaShape = require(ReplicatedStorage.Shared.ArenaShape)
local GroundProbe = require(script.Parent.GroundProbe)
local MonsterState = require(script.Parent.MonsterState)
local PlayerDamage = require(script.Parent.PlayerDamage)

local BossArenaMap = {}

local GEOMETRY = BossArenaMapData.geometry
local OBSTACLE = BossArenaMapData.obstacle
local FLOOR_TOP_Y = GEOMETRY.floorThicknessStuds / 2 -- 1(옛 아레나와 같은 관례)

-- 파편 연출 채널(클라 BossArenaMapView).
local breakEvent = Instance.new("RemoteEvent")
breakEvent.Name = "BossArenaObstacleBreak"
breakEvent.Parent = ReplicatedStorage

function BossArenaMap.floorTopY()
	return FLOOR_TOP_Y
end

function BossArenaMap.themeFor(bossId)
	return BossArenaMapData.maps[bossId or ""] or BossArenaMapData.default
end

-- ═══ 파트 도우미 ═══

local function newPart(parent, props)
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

-- 누운 원판(Cylinder는 로컬 X가 높이) - 윗면 Y = topY.
local function discCFrame(x, topY, z, thickness)
	return CFrame.new(x, topY - thickness / 2, z) * CFrame.Angles(0, 0, math.rad(90))
end

local function polar(zone, angleDeg, distance)
	local angle = math.rad(angleDeg)
	return zone.center.X + math.cos(angle) * distance, zone.center.Z + math.sin(angle) * distance
end

local function outline(model)
	local highlight = Instance.new("Highlight")
	highlight.Name = "CartoonOutline"
	highlight.FillTransparency = 1
	highlight.OutlineColor = BossArenaMapData.outlineColor
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = model
	highlight.Parent = model
	return highlight
end

-- ═══ 기반(슬롯마다 한 번) ═══

local bases = {} -- [zoneKey] = { floor, rim, walls = { Part }, model }

function BossArenaMap.buildBase(zoneKey)
	if bases[zoneKey] then
		return bases[zoneKey]
	end
	local zone = WorldConfig.zones[zoneKey]
	local radius = GEOMETRY.radiusStuds
	local thickness = GEOMETRY.wallThicknessStuds
	local model = Instance.new("Model")
	model.Name = "BossArenaBase_" .. zoneKey
	model.Parent = Workspace

	-- 바닥 = 원판 하나(지면 폴더 - 보스 지면 추적 · 돌진 Y · 드랍 스냅의 대상). 벽 밑까지 덮는다.
	local floorDiameter = (radius + thickness) * 2
	local floor = newPart(GroundProbe.folder(), {
		name = "BossArenaFloor", shape = "cylinder", collide = true,
		size = Vector3.new(GEOMETRY.floorThicknessStuds, floorDiameter, floorDiameter),
		cframe = discCFrame(zone.center.X, FLOOR_TOP_Y, zone.center.Z, GEOMETRY.floorThicknessStuds),
	})
	-- 테라스(벽 바깥의 낮은 단 - 장식이 선다. 걸어서는 못 간다).
	local rimDiameter = (radius + thickness + GEOMETRY.rimWidthStuds) * 2
	local rim = newPart(model, {
		name = "BossArenaRim", shape = "cylinder", collide = true,
		size = Vector3.new(GEOMETRY.floorThicknessStuds, rimDiameter, rimDiameter),
		cframe = discCFrame(zone.center.X, FLOOR_TOP_Y - GEOMETRY.rimDropStuds, zone.center.Z, GEOMETRY.floorThicknessStuds),
	})
	-- 벽 = 24각형 고리. 변마다 바깥 둘레 기준 길이 + 여유로 이음새 틈이 없다(안쪽 면이 반경 radius에 닿는다).
	local walls = {}
	local segments = GEOMETRY.wallSegments
	local length = 2 * (radius + thickness) * math.tan(math.pi / segments) + 0.5
	for index = 1, segments do
		local angleDeg = (index - 0.5) * 360 / segments
		local x, z = polar(zone, angleDeg, radius / math.cos(math.pi / segments) + thickness / 2)
		local position = Vector3.new(x, FLOOR_TOP_Y + GEOMETRY.wallHeightStuds / 2, z)
		walls[index] = newPart(model, {
			name = "BossArenaWall", collide = true,
			size = Vector3.new(length, GEOMETRY.wallHeightStuds, thickness),
			cframe = CFrame.lookAt(position, Vector3.new(zone.center.X, position.Y, zone.center.Z)),
		})
	end
	outline(model)
	local base = { floor = floor, rim = rim, walls = walls, model = model }
	bases[zoneKey] = base
	return base
end

-- 자동 검증 전용(P3a D1 "첫 진입" 재현): 보스전이 없는 슬롯의 기반을 부순다 - 다음 보스전이 처음 짓는 것처럼 새 파트를 만들고 클라는 그것을 새로 받는다.
function BossArenaMap.debugDestroyBases(activeZones)
	local destroyed = 0
	for zoneKey, base in pairs(bases) do
		if not (activeZones and activeZones[zoneKey]) then
			base.floor:Destroy()
			base.model:Destroy()
			bases[zoneKey] = nil
			destroyed += 1
		end
	end
	return destroyed
end


local function applyTheme(base, theme)
	base.floor.Color, base.floor.Material = theme.floor.color, theme.floor.material
	base.rim.Color, base.rim.Material = theme.rim.color, theme.rim.material
	for _, wall in ipairs(base.walls) do
		wall.Color, wall.Material = theme.wall.color, theme.wall.material
	end
end

-- ═══ 장식 빌더(kind) ═══

local function glowColor(spec, bossData)
	if spec.color then
		return spec.color
	end
	if spec.glow == "body" then
		return bossData.bodyColor
	end
	return bossData.headColor or bossData.bodyColor
end

local DECOR = {}

-- 뾰족한 기둥(얼음 가시 · 수정 · 첨탑): 기운 큰 기둥 + 옆의 작은 기둥(+ tipColor면 끝의 빛 조각).
function DECOR.spike(parent, zone, spec, angleDeg, index)
	local x, z = polar(zone, angleDeg, GEOMETRY.radiusStuds * spec.ring)
	local baseY = FLOOR_TOP_Y - GEOMETRY.rimDropStuds
	local lean = ((index % 3) - 1) * 6
	local yaw = angleDeg * 1.7
	local main = CFrame.new(x, baseY + spec.size.Y / 2 - 1, z) * CFrame.Angles(0, math.rad(yaw), math.rad(lean))
	local material = spec.neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
	newPart(parent, { name = "ArenaSpike", size = spec.size, cframe = main, color = spec.color, transparency = spec.transparency, material = material })
	local small = spec.size * Vector3.new(0.7, 0.55, 0.7)
	newPart(parent, {
		name = "ArenaSpike", size = small, color = spec.color, transparency = spec.transparency, material = material,
		cframe = CFrame.new(x + 3.5, baseY + small.Y / 2 - 1, z - 2.5) * CFrame.Angles(0, math.rad(yaw + 40), math.rad(-lean - 10)),
	})
	if spec.tipColor then
		newPart(parent, {
			name = "ArenaSpikeTip", size = Vector3.new(spec.size.X * 0.8, 3, spec.size.Z * 0.8), color = spec.tipColor, material = Enum.Material.Neon, shadow = false,
			cframe = main * CFrame.new(0, spec.size.Y / 2 + 1.5, 0),
		})
	end
end

-- 원기둥(신전 · 폐허): 받침 + 기둥 + 머리돌. broken이면 기둥이 짧고 머리돌이 옆에 떨어져 있다.
function DECOR.column(parent, zone, spec, angleDeg, index)
	local x, z = polar(zone, angleDeg, GEOMETRY.radiusStuds * spec.ring)
	local baseY = FLOOR_TOP_Y - GEOMETRY.rimDropStuds
	local width = spec.size.X
	local height = spec.size.Y
	if spec.broken then
		height = height * (0.45 + 0.2 * (index % 3))
	end
	newPart(parent, { name = "ArenaColumnBase", size = Vector3.new(width + 3, 1.5, width + 3), color = spec.color, cframe = CFrame.new(x, baseY + 0.75, z) * CFrame.Angles(0, math.rad(angleDeg), 0) })
	newPart(parent, {
		name = "ArenaColumn", shape = "cylinder", size = Vector3.new(height, width, width), color = spec.color,
		cframe = CFrame.new(x, baseY + 1.5 + height / 2, z) * CFrame.Angles(0, 0, math.rad(90)),
	})
	local capSize = Vector3.new(width + 2, 2, width + 2)
	if spec.broken then
		local dx, dz = polar({ center = Vector3.zero }, angleDeg + 90, width + 2)
		newPart(parent, { name = "ArenaColumnCap", size = capSize, color = spec.color, cframe = CFrame.new(x + dx, baseY + 1, z + dz) * CFrame.Angles(0, math.rad(angleDeg + 20), math.rad(12)) })
	else
		newPart(parent, { name = "ArenaColumnCap", size = capSize, color = spec.color, cframe = CFrame.new(x, baseY + 1.5 + height + 1, z) * CFrame.Angles(0, math.rad(angleDeg), 0) })
	end
end

-- 오벨리스크(공허): 기운 사각 기둥 + 그 위에 떠 있는 빛 조각(보스 머리색).
function DECOR.obelisk(parent, zone, spec, angleDeg, index, bossData)
	local x, z = polar(zone, angleDeg, GEOMETRY.radiusStuds * spec.ring)
	local baseY = FLOOR_TOP_Y - GEOMETRY.rimDropStuds
	local tilt = (index % 2 == 0) and spec.tiltDeg or -spec.tiltDeg
	local main = CFrame.new(x, baseY + spec.size.Y / 2 - 1, z) * CFrame.Angles(math.rad(tilt), math.rad(angleDeg), 0)
	newPart(parent, { name = "ArenaObelisk", size = spec.size, color = spec.color, cframe = main })
	newPart(parent, {
		name = "ArenaObeliskShard", size = Vector3.new(spec.size.X * 0.6, 4, spec.size.Z * 0.6), color = glowColor(spec, bossData), material = Enum.Material.Neon, shadow = false,
		cframe = main * CFrame.new(0, spec.size.Y / 2 + 4, 0) * CFrame.Angles(0, math.rad(45), math.rad(45)),
	})
end

-- 바닥 빛 고리: 빛 원판 + 그 위의 바닥색 원판(가운데를 비워 고리로 보인다). 예고 원(바닥 + 0.15)보다 낮다.
function DECOR.floorRing(parent, zone, spec, _, _, bossData, theme)
	local outer = spec.radius * 2
	local inner = (spec.radius - spec.width) * 2
	newPart(parent, {
		name = "ArenaFloorRing", shape = "cylinder", size = Vector3.new(0.04, outer, outer), color = glowColor(spec, bossData), material = Enum.Material.Neon,
		transparency = spec.transparency, shadow = false, cframe = discCFrame(zone.center.X, FLOOR_TOP_Y + 0.04, zone.center.Z, 0.04),
	})
	newPart(parent, {
		name = "ArenaFloorRingInner", shape = "cylinder", size = Vector3.new(0.04, inner, inner), color = theme.floor.color, material = theme.floor.material,
		shadow = false, cframe = discCFrame(zone.center.X, FLOOR_TOP_Y + 0.07, zone.center.Z, 0.04),
	})
end

-- 바닥 원판(물웅덩이 · 모래 무늬) - spots = { { 방위, 반경 배율 } }.
function DECOR.floorDisc(parent, zone, spec)
	for _, spot in ipairs(spec.spots) do
		local x, z = polar(zone, spot[1], GEOMETRY.radiusStuds * spot[2])
		newPart(parent, {
			name = "ArenaFloorDisc", shape = "cylinder", size = Vector3.new(0.04, spec.radius * 2, spec.radius * 2), color = spec.color,
			material = spec.transparency > 0 and Enum.Material.Neon or Enum.Material.SmoothPlastic, transparency = spec.transparency, shadow = false,
			cframe = discCFrame(x, FLOOR_TOP_Y + 0.05, z, 0.04),
		})
	end
end

-- ═══ 구조물 ═══

-- kind별 겉모습(충돌 없음 - 충돌은 아래 투명 기둥이 한다). 반환: 그린 파트 목록.
local OBSTACLE_LOOK = {}

local function heightOf(spec)
	return spec.heightStuds or OBSTACLE.heightStuds
end

function OBSTACLE_LOOK.boulder(model, center, spec, index)
	local r = spec.radius
	return {
		newPart(model, { name = "ObstacleRock", shape = "ball", size = Vector3.new(r * 2, r * 2, r * 2) * 1.05, color = spec.color, transparency = spec.transparency, cframe = CFrame.new(center + Vector3.new(0, r * 0.75, 0)) }),
		newPart(model, { name = "ObstacleRock", shape = "ball", size = Vector3.new(r, r, r) * 1.1, color = spec.color, transparency = spec.transparency,
			cframe = CFrame.new(center + Vector3.new(r * 0.8 * ((index % 2 == 0) and 1 or -1), r * 0.35, r * 0.5)) }),
	}
end

function OBSTACLE_LOOK.block(model, center, spec, index)
	local r = spec.radius
	return {
		newPart(model, { name = "ObstacleBlock", size = Vector3.new(r * 1.7, heightOf(spec) + 0.5, r * 1.5), color = spec.color, transparency = spec.transparency,
			cframe = CFrame.new(center + Vector3.new(0, heightOf(spec) / 2, 0)) * CFrame.Angles(0, math.rad(index * 37), math.rad(6)) }),
		newPart(model, { name = "ObstacleBlock", size = Vector3.new(r, r * 0.8, r * 1.1), color = spec.color, transparency = spec.transparency,
			cframe = CFrame.new(center + Vector3.new(r * 0.7, r * 0.4, -r * 0.6)) * CFrame.Angles(math.rad(10), math.rad(index * 53), 0) }),
	}
end

function OBSTACLE_LOOK.stump(model, center, spec, index)
	local r = spec.radius
	return {
		newPart(model, { name = "ObstacleStump", shape = "cylinder", size = Vector3.new(heightOf(spec) + 0.5, r * 1.9, r * 1.9), color = spec.color, transparency = spec.transparency,
			cframe = CFrame.new(center + Vector3.new(0, (heightOf(spec) + 0.5) / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)) }),
		newPart(model, { name = "ObstacleStump", size = Vector3.new(r * 1.6, 1.2, r * 1.6), color = spec.color, transparency = spec.transparency,
			cframe = CFrame.new(center + Vector3.new(0, heightOf(spec) + 0.8, 0)) * CFrame.Angles(math.rad(8), math.rad(index * 29), math.rad(-6)) }),
	}
end

function OBSTACLE_LOOK.cluster(model, center, spec, index)
	local r = spec.radius
	local parts = {}
	for k = 0, 2 do
		local angle = math.rad(k * 120 + index * 17)
		local height = heightOf(spec) + 1 - k * 1.2
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (k == 0 and 0 or r * 0.55)
		table.insert(parts, newPart(model, {
			name = "ObstacleCrystal", size = Vector3.new(r * 0.8, height, r * 0.8), color = spec.color, transparency = spec.transparency, material = Enum.Material.SmoothPlastic,
			cframe = CFrame.new(center + offset + Vector3.new(0, height / 2, 0)) * CFrame.Angles(math.rad(k * 9), math.rad(k * 40 + 20), math.rad(-k * 12)),
		}))
	end
	return parts
end

-- 큰 바위판(사용자 지시 - 올라서서 건너가는 지형): 충돌 기둥과 같은 크기의 넓은 원판(보이는 윗면 = 실제로 서는 면) + 가장자리의 작은 바위 둘.
function OBSTACLE_LOOK.mesa(model, center, spec, index)
	local r, h = spec.radius, heightOf(spec)
	local parts = {
		newPart(model, { name = "ObstacleMesa", shape = "cylinder", size = Vector3.new(h, r * 2, r * 2), color = spec.color, transparency = spec.transparency,
			cframe = CFrame.new(center + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)) }),
	}
	for k = 0, 1 do
		local angle = math.rad(index * 50 + k * 150)
		local size = Vector3.new(3, h * 0.7, 3.5)
		table.insert(parts, newPart(model, {
			name = "ObstacleMesaRock", size = size, color = spec.color:Lerp(Color3.new(0, 0, 0), 0.15), transparency = spec.transparency,
			cframe = CFrame.new(center + Vector3.new(math.cos(angle) * (r - 1), size.Y / 2, math.sin(angle) * (r - 1))) * CFrame.Angles(0, angle, math.rad(8)),
		}))
	end
	return parts
end

-- [zoneKey] = { zoneKey, theme, bossData, dressing(Model), obstacles = { [id] = obstacle }, nextId, near = { [id] = 초 }, lastBreak }
local active = {}

local function zoneOfKey(zoneKey)
	return WorldConfig.zones[zoneKey]
end

-- 구조물 윗면에 서 있는가(수평으로 윗면 안 + 발이 윗면 근처 이상).
local function standsOnTop(obstacle, root)
	local dx, dz = root.Position.X - obstacle.center.X, root.Position.Z - obstacle.center.Z
	return dx * dx + dz * dz <= (obstacle.radius + 0.5) ^ 2 and root.Position.Y >= obstacle.center.Y + obstacle.height - 0.5
end

-- 부서진 순간: 아레나 안 사람에게 파편 연출을 보내고, 윗면에 서 있던 사람은 파편과 함께 튕겨 나며 피해를 받는다(사용자 지시).
-- 튕김은 보스 패턴의 넉백 연출(launch - BossStormView)을 그대로 쓴다. 반환: 튕겨 난 사람 목록(검증이 읽는다).
local function fireBreak(state, obstacle, cause)
	local zone = zoneOfKey(state.zoneKey)
	local topBreak = OBSTACLE.topBreak
	local patternEvent = ReplicatedStorage:FindFirstChild("BossPatternEvent")
	local launched = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and ArenaShape.contains(zone, root.Position, -GEOMETRY.wallThicknessStuds) then
			breakEvent:FireClient(player, {
				position = obstacle.center + Vector3.new(0, obstacle.height / 2, 0),
				radius = obstacle.radius, height = obstacle.height, color = obstacle.color, cause = cause,
			})
			if standsOnTop(obstacle, root) then
				table.insert(launched, player)
				if patternEvent then
					patternEvent:FireClient(player, "launch", { from = obstacle.center, heightStuds = topBreak.heightStuds, distanceStuds = topBreak.distanceStuds })
				end
				PlayerDamage.applyMaxHpFraction(player, topBreak.maxHpFraction, topBreak.label)
			end
		end
	end
	return launched
end

-- 구조물 하나를 부순다(이미 부서졌으면 false). cause = "hits"(플레이어) · "charge"(보스 돌진) · "boss"(뺑뺑이 방지).
function BossArenaMap.breakObstacle(zoneKey, id, cause)
	local state = active[zoneKey]
	local obstacle = state and state.obstacles[id]
	if not obstacle or obstacle.broken then
		return false
	end
	obstacle.broken = true
	state.obstacles[id] = nil
	MonsterState.clear(obstacle.model)
	obstacle.model:Destroy()
	obstacle.collider:Destroy()
	local launched = fireBreak(state, obstacle, cause)
	state.lastBreak = { id = id, cause = cause, launched = launched, at = os.clock() }
	print(("[forge-game] 구조물 부서짐: %s #%d(%s) - 위에 있던 %d명 튕김"):format(zoneKey, id, cause, #launched))
	return true
end

-- 마지막으로 부서진 구조물(검증이 읽는다).
function BossArenaMap.lastBreak(zoneKey)
	local state = active[zoneKey]
	return state and state.lastBreak or nil
end

local function spawnObstacle(state, zone, spec, angleDeg, index)
	local x, z = polar(zone, angleDeg, GEOMETRY.radiusStuds * spec.ring)
	local center = Vector3.new(x, FLOOR_TOP_Y, z)
	state.nextId += 1
	local id = state.nextId
	-- 충돌 = 지면 폴더의 투명 원기둥(플레이어 물리 · 보스 지면 추적이 같은 것을 본다).
	local height = heightOf(spec)
	local collider = newPart(GroundProbe.folder(), {
		name = "ArenaObstacleCollider", shape = "cylinder", collide = true, transparency = 1, shadow = false,
		size = Vector3.new(height, spec.radius * 2, spec.radius * 2),
		cframe = CFrame.new(center + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	})
	-- 조준 대상 = 모델(Monster 태그 + 구출 대상과 같은 "맞으면 알림만"). 루트는 투명 · 충돌 없음.
	local model = Instance.new("Model")
	model.Name = "구조물"
	local root = newPart(model, {
		name = "HumanoidRootPart", size = Vector3.new(2, 2, 2), transparency = 1, shadow = false,
		cframe = CFrame.new(center + Vector3.new(0, math.min(height, 2.5), 0)),
	})
	model.PrimaryPart = root
	local look = OBSTACLE_LOOK[spec.kind] or OBSTACLE_LOOK.block
	local visuals = look(model, center, spec, index)
	-- 조준 대상 외곽선(몬스터와 같은 AimHighlight - AimTarget이 조준할 때만 켠다. 꺼진 Highlight는 동시 한도에 안 든다).
	local aim = Instance.new("Highlight")
	aim.Name = "AimHighlight"
	aim.Enabled = false
	aim.FillTransparency = 1
	aim.OutlineColor = Color3.fromRGB(255, 230, 90) -- MonsterSpawner의 조준 외곽선과 같은 값
	aim.OutlineTransparency = 0
	aim.Parent = model
	model.Parent = state.dressing
	CollectionService:AddTag(model, "Monster")
	CollectionService:AddTag(model, "RescueTarget") -- 클라가 "보스"를 찾을 때 건너뛴다(BossPatternVisuals.findBossModel)
	CollectionService:AddTag(model, "ArenaObstacle")

	local obstacle = {
		id = id, center = center, radius = spec.radius, height = height, color = spec.color, model = model, collider = collider, visuals = visuals,
		hits = 0, lastHitAt = {}, broken = false,
	}
	local data = {
		id = "arena_obstacle", displayName = "구조물", isRescueTarget = true, bodyColor = spec.color, headColor = spec.color,
		hp = 0, attack = 0, goldDrop = 0, expReward = 0, moveSpeedStuds = 0, attackRangeStuds = 0, attackCooldownSeconds = 1,
	}
	MonsterState.init(model, data, root.Position, state.zoneKey, {
		isRescueTarget = true,
		rescueRemaining = function()
			return 1 - obstacle.hits / OBSTACLE.hitsToBreak
		end,
		onRescueHit = function(player)
			if obstacle.broken then
				return
			end
			local now = os.clock()
			local last = obstacle.lastHitAt[player]
			if last and now - last < OBSTACLE.hitIntervalSeconds then
				return
			end
			obstacle.lastHitAt[player] = now
			obstacle.hits += 1
			-- 금이 가는 겉모습: 맞을 때마다 조금 어두워진다(서버 파트라 모두에게 보인다). 크기는 그대로 - 충돌 기둥과 보이는 모양이 어긋나지 않게.
			for _, part in ipairs(visuals) do
				if part.Parent then
					part.Color = part.Color:Lerp(Color3.new(0, 0, 0), 0.18)
				end
			end
			if obstacle.hits >= OBSTACLE.hitsToBreak then
				BossArenaMap.breakObstacle(state.zoneKey, id, "hits")
			end
		end,
	})
	state.obstacles[id] = obstacle
	return obstacle
end

local function spawnObstacles(state)
	local zone = zoneOfKey(state.zoneKey)
	for _, spec in ipairs(state.theme.obstacles or {}) do -- 그룹마다(작은 구조물 · 큰 바위판)
		for index, angleDeg in ipairs(spec.angles) do
			spawnObstacle(state, zone, spec, angleDeg, index)
		end
	end
end

local function clearObstacles(state)
	for id in pairs(state.obstacles) do
		local obstacle = state.obstacles[id]
		state.obstacles[id] = nil
		MonsterState.clear(obstacle.model)
		obstacle.model:Destroy()
		obstacle.collider:Destroy()
	end
	state.near = {}
end

-- 보스전 시작(BossEncounter.spawnEncounter가 텔레포트 전에 부른다). bossData = 인스턴스 데이터(색 · id). 반환 = 상태(치울 때 넘긴다).
function BossArenaMap.dress(zoneKey, bossData)
	BossArenaMap.undress(zoneKey)
	local base = BossArenaMap.buildBase(zoneKey)
	local theme = BossArenaMap.themeFor(bossData and bossData.id)
	applyTheme(base, theme)
	local zone = zoneOfKey(zoneKey)
	local dressing = Instance.new("Model")
	dressing.Name = "BossArenaDressing_" .. zoneKey
	dressing.Parent = Workspace
	local state = { zoneKey = zoneKey, theme = theme, bossData = bossData, dressing = dressing, obstacles = {}, nextId = 0, near = {} }
	for _, spec in ipairs(theme.decor or {}) do
		local builder = DECOR[spec.kind]
		if builder then
			for index, angleDeg in ipairs(spec.angles or { 0 }) do
				builder(dressing, zone, spec, angleDeg, index, bossData, theme)
				if not spec.angles then
					break
				end
			end
		end
	end
	spawnObstacles(state)
	outline(dressing)
	active[zoneKey] = state
	return state
end

function BossArenaMap.undress(zoneKey)
	local state = active[zoneKey]
	if not state then
		return
	end
	clearObstacles(state)
	state.dressing:Destroy()
	active[zoneKey] = nil
end

-- 전멸 리셋 - 구조물을 처음대로(부서진 것도 다시) 세운다.
function BossArenaMap.resetObstacles(zoneKey)
	local state = active[zoneKey]
	if not state then
		return
	end
	clearObstacles(state)
	spawnObstacles(state)
end

function BossArenaMap.getTheme(zoneKey)
	local state = active[zoneKey]
	return state and state.theme or nil
end

-- 서 있는 구조물 목록(검증 · 검사기용 사본): { { id, center, radius } }.
function BossArenaMap.obstacles(zoneKey)
	local list = {}
	local state = active[zoneKey]
	for id, obstacle in pairs(state and state.obstacles or {}) do
		table.insert(list, { id = id, center = obstacle.center, radius = obstacle.radius, height = obstacle.height, hits = obstacle.hits, model = obstacle.model })
	end
	table.sort(list, function(a, b)
		return a.id < b.id
	end)
	return list
end

-- 원(position, radius)이 서 있는 구조물과 clearance 안으로 겹치는가(사용자 지시: 기믹 지형 - 얼음 기둥 · 모래 구덩이 - 이 구조물 위에 서지 않는다).
function BossArenaMap.overlapsObstacle(zoneKey, position, radius, clearance)
	local state = active[zoneKey]
	for _, obstacle in pairs(state and state.obstacles or {}) do
		local limit = obstacle.radius + radius + (clearance or 0)
		local dx, dz = position.X - obstacle.center.X, position.Z - obstacle.center.Z
		if dx * dx + dz * dz < limit * limit then
			return true
		end
	end
	return false
end

-- 돌진 경로(origin에서 단위벡터 dir로 length)에 처음 걸리는 구조물과 "닿는 거리"(보스 몸통이 구조물 가장자리에 닿는 순간의 이동 거리). 없으면 nil.
function BossArenaMap.firstOnPath(zoneKey, origin, dir, length, bodyHalf)
	local state = active[zoneKey]
	if not state then
		return nil
	end
	local best, bestDistance = nil, math.huge
	for _, obstacle in pairs(state.obstacles) do
		local rel = Vector3.new(obstacle.center.X - origin.X, 0, obstacle.center.Z - origin.Z)
		local along = rel:Dot(dir)
		local reach = obstacle.radius + bodyHalf
		local lateral2 = rel:Dot(rel) - along * along
		if along > 0 and lateral2 <= reach * reach then
			local contact = along - math.sqrt(reach * reach - lateral2)
			if contact >= 0 and contact < length and contact < bestDistance then
				best, bestDistance = obstacle, contact
			end
		end
	end
	if best then
		return best.id, bestDistance
	end
	return nil
end

-- 뺑뺑이 방지(사용자 지시): 보스가 추격 중(스킬 없음) 한 구조물 곁에 머문 시간을 쌓아, "그 구조물을 보스 걸음으로 smashAfterLaps바퀴 도는 시간"을 넘으면 부순다.
-- BossPatterns.step이 정상 상태(추격)일 때마다 부른다. 반환: 부쉈으면 그 id.
function BossArenaMap.noteBossChase(zoneKey, position, dt, moveSpeedStuds)
	local state = active[zoneKey]
	if not state or (moveSpeedStuds or 0) <= 0 then
		return nil
	end
	for id, obstacle in pairs(state.obstacles) do
		local nearRadius = obstacle.radius + OBSTACLE.chargeBodyHalfStuds + OBSTACLE.nearSlackStuds
		local dx, dz = position.X - obstacle.center.X, position.Z - obstacle.center.Z
		local near = dx * dx + dz * dz <= nearRadius * nearRadius
		local accumulated = math.max((state.near[id] or 0) + (near and dt or -dt), 0)
		state.near[id] = accumulated
		local limit = BossArenaMap.smashSeconds(obstacle.radius, moveSpeedStuds)
		if accumulated >= limit then
			print(("[forge-game] 보스가 구조물 곁을 %.1f초(%d바퀴분) 맴돌아 부순다"):format(accumulated, OBSTACLE.smashAfterLaps))
			BossArenaMap.breakObstacle(zoneKey, id, "boss")
			return id
		end
	end
	return nil
end

-- 한 구조물을 보스 걸음으로 smashAfterLaps바퀴 도는 시간(초).
function BossArenaMap.smashSeconds(obstacleRadius, moveSpeedStuds)
	local loop = 2 * math.pi * (obstacleRadius + OBSTACLE.chargeBodyHalfStuds + OBSTACLE.nearSlackStuds)
	return loop / math.max(moveSpeedStuds, 1e-3) * OBSTACLE.smashAfterLaps
end

-- 검증 · 성능 기록용: 이 슬롯의 기반 모델 · 장식 모델 · 바닥(없으면 nil).
function BossArenaMap.debugModels(zoneKey)
	local base = bases[zoneKey]
	local state = active[zoneKey]
	return base and base.model, state and state.dressing, base and base.floor
end

-- 입장 자리(중심에서 entryDistance, entryAngle 방위) - index번째 멤버는 원둘레 방향으로 벌린다.
function BossArenaMap.entryPosition(zoneKey, index, count)
	local zone = zoneOfKey(zoneKey)
	local spread = 4 -- 캐릭터 반폭 1의 4배(옛 ENTRY_SPREAD_STUDS)
	local offsetDeg = math.deg(((index or 1) - 1 - ((count or 1) - 1) / 2) * spread / GEOMETRY.entryDistanceStuds)
	local x, z = polar(zone, GEOMETRY.entryAngleDeg + offsetDeg, GEOMETRY.entryDistanceStuds)
	return Vector3.new(x, FLOOR_TOP_Y + 3, z)
end

return BossArenaMap
