-- 원형 보스 아레나 맵(P3a C) - 슬롯마다 기반(바닥 · 벽 고리 · 테라스)을 한 번 짓고, 보스전마다 그 보스의 테마(BossArenaMapData.maps[보스 id])로 색 · 재질을 바꾸고
-- 장식 · 구조물을 짓는다(보스전이 끝나면 치운다). 모양 · 색 · 자리는 전부 데이터 - 여기는 kind별 빌더만 안다(최종 에셋으로 바꿀 때 이 빌더만 고친다).
--
-- 구조물(사용자 지시): 충돌하는 자연 지형지물. ① 걸어서 못 지나간다 - 투명 충돌 기둥이 지면 폴더(GroundProbe)에 있어 보스 걸음도 계단보다 높은 턱으로 보고 비켜 간다
-- ② 보스 돌진이 부딪히면 돌진이 거기서 끝나고(예고 선도 거기까지 - 보이는 것 = 판정) 구조물이 부서지며 헤롱이 길어진다(BossPatterns가 firstOnPath · breakObstacle을 부른다)
-- ③ 플레이어가 hitsToBreak번 때리면 부서진다(조준 대상 - Monster 태그 + 구출 대상과 같은 "맞으면 알림만" 엔티티) - 직전에는 금 간 표시(P3c B2)
-- ④ 부서질 때 멤버의 클라가 파편을 그린다(BossArenaObstacleBreak). 전멸 리셋이면 처음대로(같은 시드) 다시 선다.
-- P3c B: 자리 · 크기는 보스 등장마다 무작위(shared/ArenaLayout - 시드는 로그 "보스맵 배치 시드"), 겉모습은 server/BossArenaLooks, 바닥 둔덕(B4)도 여기서 짓는다.
-- 옛 ⑤ "뺑뺑이 5바퀴면 보스가 부순다"는 없앴다(C8 - 돌진 대상이 가장 가까운 사람이라 숨으면 돌진이 온다).

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local BossArenaMapData = require(ReplicatedStorage.Shared.data.BossArenaMapData)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local ArenaShape = require(ReplicatedStorage.Shared.ArenaShape)
local ArenaLayout = require(ReplicatedStorage.Shared.ArenaLayout)
local GroundProbe = require(script.Parent.GroundProbe)
local MonsterState = require(script.Parent.MonsterState)
local PlayerDamage = require(script.Parent.PlayerDamage)
local PlayerState = require(script.Parent.PlayerState) -- P3d D3: 끼인 사람의 받는 피해 0배를 풀 때
local Looks = require(script.Parent.BossArenaLooks)

local BossArenaMap = {}

local GEOMETRY = BossArenaMapData.geometry
local OBSTACLE = BossArenaMapData.obstacle
local REGROW = BossArenaMapData.regrow
local FLOOR_TOP_Y = GEOMETRY.floorThicknessStuds / 2 -- 1(옛 아레나와 같은 관례)

-- P3d B2: 맵 이탈 복귀 직후 보호 중인가(BossArenaContainment가 건다 - 이 모듈은 그 모듈을 require하지 않는다). nil이면 보호 없음.
BossArenaMap.isLaunchProtected = nil

-- 배치 시드를 뽑는 난수(보스 등장마다). 검증은 debugNextSeed로 고정 시드를 넣는다.
local layoutRng = Random.new()
BossArenaMap.debugNextSeed = nil

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

-- ═══ 파트 도우미(겉모습 파일과 같은 것) ═══

local newPart = Looks.newPart
local discCFrame = Looks.discCFrame

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

-- ═══ 구조물(P3c B - 보스 등장마다 무작위 배치, shared/ArenaLayout) ═══

-- 키가 큰 충돌 기둥(석상 · 얼음 기둥 - featureShapes의 tall)은 지면 폴더 밖에 둔다: 지면 탐지 · 드랍 스냅 · 낙하점 높이가 기둥 꼭대기를 바닥으로 보지 않게.
local tallFolder = nil
local function tallColliderFolder()
	if not tallFolder or not tallFolder.Parent then
		tallFolder = Instance.new("Folder")
		tallFolder.Name = "BossArenaTallColliders"
		tallFolder.Parent = Workspace
	end
	return tallFolder
end

-- [zoneKey] = { zoneKey, theme, bossData, dressing(Model), layout, obstacles = { [id] = obstacle }, mounds = { Part }, lastBreak }
local active = {}
-- P3d Play 2: 재생성 토큰 · id는 모듈 전역 일련번호다 - 보스전마다 0 · 1000부터 다시 세면 앞 보스전의 전조 대기 작업(task.delay)이 다음 보스전의 같은 토큰으로 솟고,
-- 같은 id가 덮어써져 충돌 기둥이 남았다(Play 2 실측 - 기둥 21 → 24).
local regrowSerial = 0
local function nextRegrowSerial()
	regrowSerial += 1
	return regrowSerial
end
local spawnObstacle -- P3d D: 재생성(아래 BossArenaMap.spawnRegrown)이 먼저 부른다 - 정의는 아래

local function zoneOfKey(zoneKey)
	return WorldConfig.zones[zoneKey]
end

-- 구조물 윗면에 서 있는가: 충돌 원마다 수평으로 윗면 안 + **발**이 윗면 근처 이상(P3a 리뷰 1 - 루트로 재면 곁의 바닥에 선 사람도 걸렸다). 키 큰 기둥 위에는 못 선다.
local function standsOnTop(obstacle, character, root)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local feetY = root.Position.Y - (humanoid and (humanoid.HipHeight + root.Size.Y / 2) or 3)
	for _, c in ipairs(obstacle.colliders) do
		local dx, dz = root.Position.X - c.center.X, root.Position.Z - c.center.Z
		if not c.tall and dx * dx + dz * dz <= (c.r + 0.5) ^ 2 and feetY >= FLOOR_TOP_Y + c.h - 0.5 then
			return true
		end
	end
	return false
end

-- 부서진 순간: 아레나 안 사람에게 파편 연출을 보내고, 윗면에 서 있던 사람은 파편과 함께 튕겨 나며 피해를 받는다(사용자 지시).
-- 튕김은 보스 패턴의 넉백 연출(launch - BossStormView)을 그대로 쓴다 - P3c A5: 구역을 실어 보내 착지점이 벽 안쪽을 넘지 않는다. 반환: 튕겨 난 사람 목록, 떨어진 사람 목록(검증이 읽는다).
-- P3d C2 · E2: 지진파(cause "wave") · 모래 구덩이(cause "pit")로 무너지면 위에 있던 사람은 **바닥으로 떨어지기만** 한다(피해 · 튕김 없음 - 떨어진 사람 목록).
local SOFT_BREAK = { wave = true, pit = true, escape = true, expire = true } -- escape · expire = 끼임 구조물(P3d D3 - 3타 · 6초)
local function fireBreak(state, obstacle, cause)
	local zone = zoneOfKey(state.zoneKey)
	local topBreak = OBSTACLE.topBreak
	local patternEvent = ReplicatedStorage:FindFirstChild("BossPatternEvent")
	local launched, dropped = {}, {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and ArenaShape.contains(zone, root.Position, -GEOMETRY.wallThicknessStuds) then
			breakEvent:FireClient(player, {
				position = obstacle.center + Vector3.new(0, obstacle.height / 2, 0),
				radius = obstacle.radius, height = obstacle.height, color = obstacle.color, cause = cause,
			})
			if SOFT_BREAK[cause] then
				if standsOnTop(obstacle, character, root) then
					table.insert(dropped, player)
				end
			elseif standsOnTop(obstacle, character, root) and not (BossArenaMap.isLaunchProtected and BossArenaMap.isLaunchProtected(player)) then -- P3d B2: 복귀 보호 중이면 안 튕긴다
				table.insert(launched, player)
				if patternEvent then
					patternEvent:FireClient(player, "launch", {
						from = obstacle.center, heightStuds = topBreak.heightStuds, distanceStuds = topBreak.distanceStuds, zoneCenter = zone.center, zoneRadius = zone.radius,
					})
				end
				PlayerDamage.applyMaxHpFraction(player, topBreak.maxHpFraction, topBreak.label)
			end
		end
	end
	return launched, dropped
end

local function destroyObstacle(obstacle)
	MonsterState.clear(obstacle.model)
	obstacle.model:Destroy()
	for _, collider in ipairs(obstacle.colliderParts) do
		collider:Destroy()
	end
end

-- 구조물 하나를 부순다(이미 부서졌으면 false). cause = "hits"(플레이어) · "charge"(보스 돌진) · "wave"(지진파 - 단상 · P3d C2) · "pit"(모래 구덩이 - P3d E2) ·
-- "escape"(끼임 구조물을 3타 - P3d D3) · "expire"(끼임 자동 파괴 6초). 끼여 있던 사람은 여기서 풀린다(releaseEncased).
function BossArenaMap.breakObstacle(zoneKey, id, cause)
	local state = active[zoneKey]
	local obstacle = state and state.obstacles[id]
	if not obstacle or obstacle.broken then
		return false
	end
	obstacle.broken = true
	state.obstacles[id] = nil
	destroyObstacle(obstacle)
	local released = BossArenaMap.releaseEncased(state, obstacle)
	local launched, dropped = fireBreak(state, obstacle, cause)
	state.lastBreak = { id = id, cause = cause, launched = launched, dropped = dropped, released = released, at = os.clock(), kind = obstacle.kind, hits = obstacle.hits, waveHits = obstacle.waveHits, regrown = obstacle.regrown }
	print(("[forge-game] 구조물 부서짐: %s #%d %s(%s) - 위에 있던 %d명 튕김 · %d명 떨어짐(피해 없음)"):format(zoneKey, id, obstacle.kind, cause, #launched, #dropped))
	return true
end

-- 마지막으로 부서진 구조물(검증이 읽는다).
function BossArenaMap.lastBreak(zoneKey)
	local state = active[zoneKey]
	return state and state.lastBreak or nil
end

-- ═══ 재생성 · 끼임 · 모래 구덩이 달그락(P3d D · E - 규칙 = BossArenaMapData.regrow 주석) ═══

-- 끼임 표시 채널(클라 BossPatternVisuals - 머리 위 "탈출! n타"). 아레나 안 사람 전원에게 보낸다(친구도 부수러 올 수 있게).
local encaseEvent = Instance.new("RemoteEvent")
encaseEvent.Name = "BossArenaEncase"
encaseEvent.Parent = ReplicatedStorage

local function arenaPlayers(state)
	local zone = zoneOfKey(state.zoneKey)
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and ArenaShape.contains(zone, root.Position, -GEOMETRY.wallThicknessStuds) then
			table.insert(list, player)
		end
	end
	return list
end

-- 끼임 상태를 알린다(hitsLeft = 남은 타수 · 0이면 풀림). extra = 아레나 밖이어도 받아야 할 사람(풀려난 당사자 - 리뷰 2: 보스전이 끝나 사냥터로 옮겨진 뒤에 풀면
-- 아레나 안에 아무도 없어 머리 위 "탈출!"이 안 지워졌다).
function BossArenaMap.fireEncase(state, obstacle, hitsLeft, extra)
	local userIds = {}
	for member in pairs(obstacle.encased or {}) do
		if typeof(member) == "Instance" then
			table.insert(userIds, member.UserId)
		end
	end
	local targets = arenaPlayers(state)
	for _, member in ipairs(extra or {}) do
		if typeof(member) == "Instance" and member.Parent and not table.find(targets, member) then
			table.insert(targets, member)
		end
	end
	for _, player in ipairs(targets) do
		encaseEvent:FireClient(player, { id = obstacle.id, userIds = userIds, hitsLeft = hitsLeft, seconds = obstacle.encaseUntil and math.max(obstacle.encaseUntil - os.clock(), 0) or 0,
			position = obstacle.center + Vector3.new(0, obstacle.height, 0) })
	end
end

-- 끼인 사람을 푼다(구조물이 부서질 때 · 치울 때). 반환: 풀린 사람 목록.
function BossArenaMap.releaseEncased(state, obstacle)
	local released = {}
	for member in pairs(obstacle.encased or {}) do
		table.insert(released, member)
		local root = typeof(member) == "Instance" and member.Character and member.Character:FindFirstChild("HumanoidRootPart")
		if root then
			root.Anchored = false
			-- 리뷰 5: 끼임이 건 0배일 때만 푼다(그 사이 다른 출처 - 잡힘 해제 유예 · 회오리 면역 - 가 건 것은 그대로 둔다)
			PlayerState.clearIncomingDamageMultiplierIf(member, obstacle.immuneUntil and obstacle.immuneUntil[member])
		end
	end
	if obstacle.encased and next(obstacle.encased) then
		obstacle.encased = {}
		BossArenaMap.fireEncase(state, obstacle, 0, released)
		print(("[forge-game] 끼임 풀림: #%d - %d명"):format(obstacle.id, #released))
	end
	return released
end

-- 지금 서 있는 구조물 → 배치 칸 모양(아레나 중심 기준 - ArenaLayout.regrowSpot · connectivity가 읽는다).
local function itemsOf(state)
	local zone = zoneOfKey(state.zoneKey)
	local items = {}
	for _, obstacle in pairs(state.obstacles) do
		local colliders = {}
		for _, c in ipairs(obstacle.colliders) do
			table.insert(colliders, { x = c.center.X - zone.center.X, z = c.center.Z - zone.center.Z, r = c.r })
		end
		table.insert(items, { x = obstacle.center.X - zone.center.X, z = obstacle.center.Z - zone.center.Z, radius = obstacle.radius, colliders = colliders })
	end
	return items
end

function BossArenaMap.itemsOf(zoneKey)
	local state = active[zoneKey]
	return state and itemsOf(state) or {}
end

-- 재생성 자리를 고른다. context = { members = { Vector3 }, boss = Vector3, pits = { { position, radius } } }.
-- 반환: plan { item, token, worldColliders = { { center, r, h } }, tries } 또는 nil, 이유.
function BossArenaMap.planRegrow(zoneKey, context)
	local state = active[zoneKey]
	if not state then
		return nil, "no_arena"
	end
	-- P3d Play 3: 자리 찾기는 step 밖(task.defer)에서 돈다 - 그 사이 이 슬롯의 보스전이 바뀌었으면(끝 · 전멸 리셋) 계획하지 않는다(context.token = 스킬이 끝난 순간의 토큰).
	if context.token and context.token ~= state.regrowToken then
		return nil, "cancelled"
	end
	local count = 0
	for _ in pairs(state.obstacles) do
		count += 1
	end
	if count >= REGROW.maxObstacles then
		return nil, "cap"
	end
	local zone = zoneOfKey(zoneKey)
	local function rel(p)
		return { x = p.X - zone.center.X, z = p.Z - zone.center.Z }
	end
	local members, pits = {}, {}
	for _, p in ipairs(context.members or {}) do
		table.insert(members, rel(p))
	end
	for _, pit in ipairs(context.pits or {}) do
		local r = rel(pit.position)
		r.r = pit.radius
		table.insert(pits, r)
	end
	local options = { kit = state.layoutOptions.kit, coverageMin = 0, members = members, boss = context.boss and rel(context.boss) or nil, pits = pits, mounds = state.layout.mounds }
	local regrowId = 1000 + nextRegrowSerial()
	local item, tries, why = ArenaLayout.regrowSpot(state.theme, itemsOf(state), function()
		return state.regrowRng:NextNumber()
	end, options, regrowId)
	if not item then
		return nil, why
	end
	local worldColliders = {}
	for _, c in ipairs(item.colliders) do
		table.insert(worldColliders, { center = Vector3.new(zone.center.X + c.x, FLOOR_TOP_Y, zone.center.Z + c.z), r = c.r, h = c.h })
	end
	return { item = item, token = state.regrowToken, worldColliders = worldColliders, tries = tries }, nil
end

-- 전조가 끝나 실제로 솟는다(리셋 · 보스전 끝으로 토큰이 바뀌었으면 nil). context(선택 - planRegrow와 같은 모양, 멤버는 안 본다) = 솟기 직전에 자리를 다시 본다(리뷰 6 -
-- 전조 1.5초 사이 보스가 걸어 들어왔거나 다른 구조물 · 동적 지형이 생겼으면 이번엔 안 솟는다). 반환: 구조물 또는 nil, 이유.
function BossArenaMap.spawnRegrown(zoneKey, plan, context)
	local state = active[zoneKey]
	if not state or state.regrowToken ~= plan.token then
		return nil, "cancelled"
	end
	if context then
		local zone = zoneOfKey(zoneKey)
		local function rel(p)
			return { x = p.X - zone.center.X, z = p.Z - zone.center.Z }
		end
		local pits = {}
		for _, pit in ipairs(context.pits or {}) do
			local r = rel(pit.position)
			r.r = pit.radius
			table.insert(pits, r)
		end
		local ok, why = ArenaLayout.regrowFits(plan.item, itemsOf(state), { kit = state.layoutOptions.kit, boss = context.boss and rel(context.boss) or nil, pits = pits, mounds = state.layout.mounds })
		if not ok then
			print(("[forge-game] 지형 재생성 취소(솟기 직전 자리 다시 봄): %s #%d - %s"):format(zoneKey, plan.item.id, tostring(why)))
			return nil, why
		end
	end
	local item = table.clone(plan.item)
	local obstacle = spawnObstacle(state, zoneOfKey(zoneKey), item)
	obstacle.regrown = true
	print(("[forge-game] 지형 재생성: %s #%d %s(%.0f, %.0f)%s"):format(zoneKey, item.id, item.kind, item.x, item.z, item.underMember and " - 멤버 발밑" or ""))
	return obstacle
end

-- 발(feet)이 이 구조물의 어느 충돌 원에 몸이 닿는가(수평 거리 < 원 반경 + 몸 반폭). 반환: 가장 깊이 들어간 원(center · r) · 그 중심까지 수평 거리, 또는 nil.
function BossArenaMap.colliderContact(obstacle, feet, halfWidth)
	local best, bestDepth, bestDistance = nil, -math.huge, nil
	for _, c in ipairs(obstacle.colliders) do
		local d = Vector3.new(feet.X - c.center.X, 0, feet.Z - c.center.Z).Magnitude
		if d < c.r + halfWidth and c.r - d > bestDepth then
			best, bestDepth, bestDistance = c, c.r - d, d
		end
	end
	return best, bestDistance
end

-- member를 이 구조물에 끼운다(D3) - 고정 · 받는 피해 0배 · 부수는 데 escapeHits · encaseAutoBreakSeconds 뒤 저절로 부서진다.
function BossArenaMap.encase(zoneKey, obstacle, member, root)
	local state = active[zoneKey]
	if not state or obstacle.broken then
		return false
	end
	obstacle.encased = obstacle.encased or {}
	obstacle.encased[member] = true
	obstacle.escape = true
	obstacle.encaseUntil = obstacle.encaseUntil or (os.clock() + REGROW.encaseAutoBreakSeconds)
	if typeof(root) == "Instance" then
		root.Anchored = true
		root.AssemblyLinearVelocity = Vector3.zero
	end
	if typeof(member) == "Instance" then
		PlayerState.setIncomingDamageMultiplierUntil(member, 0, REGROW.encaseAutoBreakSeconds + 0.1)
		obstacle.immuneUntil = obstacle.immuneUntil or {}
		obstacle.immuneUntil[member] = PlayerState.getIncomingDamageMultiplierUntil(member)
	end
	BossArenaMap.fireEncase(state, obstacle, REGROW.escapeHits - obstacle.hits)
	local token, id = state.regrowToken, obstacle.id
	if not obstacle.expireScheduled then
		obstacle.expireScheduled = true
		task.delay(REGROW.encaseAutoBreakSeconds, function()
			local now = active[zoneKey]
			if now and now.regrowToken == token and now.obstacles[id] == obstacle then
				BossArenaMap.breakObstacle(zoneKey, id, "expire")
			end
		end)
	end
	print(("[forge-game] 끼임: %s - #%d %s, %d타 또는 %.0f초"):format(tostring(member.Name), id, obstacle.kind, REGROW.escapeHits, REGROW.encaseAutoBreakSeconds))
	return true
end

-- 리뷰 3: 이 사람이 어느 구조물에 끼여 있으면 그 사람만 풀어 준다(보스전 이탈 · 종료 - 텔레포트 전에 부른다. 구조물은 남는다 - 다른 끼인 사람 · 6초 자동 파괴 그대로).
function BossArenaMap.releaseMember(zoneKey, member)
	local state = active[zoneKey]
	for _, obstacle in pairs(state and state.obstacles or {}) do
		if obstacle.encased and obstacle.encased[member] then
			obstacle.encased[member] = nil
			local root = typeof(member) == "Instance" and member.Character and member.Character:FindFirstChild("HumanoidRootPart")
			if root then
				root.Anchored = false
				PlayerState.clearIncomingDamageMultiplierIf(member, obstacle.immuneUntil and obstacle.immuneUntil[member])
			end
			BossArenaMap.fireEncase(state, obstacle, next(obstacle.encased) and (REGROW.escapeHits - obstacle.hits) or 0, { member })
			print(("[forge-game] 끼임 풀림(보스전 이탈): %s - #%d"):format(tostring(member.Name), obstacle.id))
			return true
		end
	end
	return false
end

-- 원(position, radius)에 충돌 원이 걸친 구조물 id 목록(E2 - 모래 구덩이).
function BossArenaMap.obstaclesInCircle(zoneKey, position, radius)
	local ids = {}
	local state = active[zoneKey]
	for id, obstacle in pairs(state and state.obstacles or {}) do
		for _, c in ipairs(obstacle.colliders) do
			local dx, dz = position.X - c.center.X, position.Z - c.center.Z
			if dx * dx + dz * dz < (radius + c.r) ^ 2 then
				table.insert(ids, id)
				break
			end
		end
	end
	table.sort(ids)
	return ids
end

-- 모래 구덩이의 틱 한 번(E2): 그 구조물이 달그락거린다(클라) - breakTicks번째에 무너진다(cause "pit" - 위 사람은 떨어지기만). 반환: 지금까지 틱 수, 무너졌는가.
function BossArenaMap.pitRattle(zoneKey, id, breakTicks)
	local state = active[zoneKey]
	local obstacle = state and state.obstacles[id]
	if not obstacle or obstacle.broken then
		return 0, false
	end
	obstacle.pitTicks = (obstacle.pitTicks or 0) + 1
	if obstacle.pitTicks >= breakTicks then
		BossArenaMap.breakObstacle(zoneKey, id, "pit")
		return obstacle.pitTicks, true
	end
	for _, player in ipairs(arenaPlayers(state)) do
		breakEvent:FireClient(player, { stage = "rattle", id = id, position = obstacle.center + Vector3.new(0, obstacle.height / 2, 0), radius = obstacle.radius, height = obstacle.height, color = obstacle.color })
	end
	return obstacle.pitTicks, false
end

-- 지금 이 슬롯의 재생성 토큰(스킬이 끝난 순간에 잡아 두고 planRegrow에 넘긴다).
function BossArenaMap.regrowToken(zoneKey)
	local state = active[zoneKey]
	return state and state.regrowToken or nil
end

-- 검증용: id의 구조물(사본 아님 - 읽기만).
function BossArenaMap.debugObstacle(zoneKey, id)
	local state = active[zoneKey]
	return state and state.obstacles[id] or nil
end

-- ═══ 단상(P3d C - 올라갈 수 있는 큰 블록) ═══

-- 발(feet - Vector3)이 서 있는 단상의 id(없으면 nil). 수평으로 충돌 원 + 0.5 안 · 발이 윗면 − 0.5 이상(standsOnTop과 같은 잣대 - 스탠드인도 발 좌표로 잰다).
function BossArenaMap.daisUnderFeet(zoneKey, feet)
	local state = active[zoneKey]
	for id, obstacle in pairs(state and state.obstacles or {}) do
		if obstacle.climbable then
			for _, c in ipairs(obstacle.colliders) do
				local dx, dz = feet.X - c.center.X, feet.Z - c.center.Z
				if dx * dx + dz * dz <= (c.r + 0.5) ^ 2 and feet.Y >= FLOOR_TOP_Y + c.h - 0.5 then
					return id
				end
			end
		end
	end
	return nil
end

-- 서 있는 단상 목록 { { id, center, radius } }(파동이 지나가는지 잰다).
function BossArenaMap.daises(zoneKey)
	local list = {}
	local state = active[zoneKey]
	for id, obstacle in pairs(state and state.obstacles or {}) do
		if obstacle.climbable then
			table.insert(list, { id = id, center = obstacle.center, radius = obstacle.radius })
		end
	end
	table.sort(list, function(a, b)
		return a.id < b.id
	end)
	return list
end

-- 지진파 하나가 단상 한가운데를 지났다(BossPatterns.updateWaves - 한 번 찍은 파동당 한 번). crackAfterWaves번째 = 금 + 먼지, breakAfterWaves번째 = 무너진다(피해 없음).
-- 반환: "crack" · "break" · nil.
function BossArenaMap.waveHitDais(zoneKey, id)
	local state = active[zoneKey]
	local obstacle = state and state.obstacles[id]
	if not obstacle or obstacle.broken or not obstacle.climbable then
		return nil
	end
	local rule = OBSTACLE.daisWave
	obstacle.waveHits += 1
	if obstacle.waveHits >= rule.breakAfterWaves then
		BossArenaMap.breakObstacle(zoneKey, id, "wave")
		return "break"
	end
	if obstacle.waveHits >= rule.crackAfterWaves then
		if not obstacle.cracked then
			obstacle.cracked = true
			for _, part in ipairs(Looks.crack(obstacle.model, obstacle.center, obstacle.item)) do
				table.insert(obstacle.visuals, part)
			end
		end
		local zone = zoneOfKey(zoneKey)
		for _, player in ipairs(Players:GetPlayers()) do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root and ArenaShape.contains(zone, root.Position, -GEOMETRY.wallThicknessStuds) then
				breakEvent:FireClient(player, { stage = "crack", position = obstacle.center + Vector3.new(0, obstacle.height, 0), radius = obstacle.radius, height = obstacle.height, color = obstacle.color, cause = "wave" })
			end
		end
		print(("[forge-game] 단상 금: %s #%d - 지진파 %d번째(%d번째에 무너진다)"):format(zoneKey, id, obstacle.waveHits, rule.breakAfterWaves))
		return "crack"
	end
	return nil
end

function spawnObstacle(state, zone, item)
	local center = Vector3.new(zone.center.X + item.x, FLOOR_TOP_Y, zone.center.Z + item.z)
	local id = item.id
	-- 충돌 = 투명 원기둥(충돌 원마다). 낮은 기둥은 지면 폴더(플레이어 물리 · 보스 지면 추적이 같은 것을 본다), 키 큰 기둥은 지면 폴더 밖.
	local colliders, colliderParts, height = {}, {}, 0
	for _, c in ipairs(item.colliders) do
		local at = Vector3.new(zone.center.X + c.x, FLOOR_TOP_Y, zone.center.Z + c.z)
		table.insert(colliderParts, Looks.newPart(c.tall and tallColliderFolder() or GroundProbe.folder(), {
			name = "ArenaObstacleCollider", shape = "cylinder", collide = true, transparency = 1, shadow = false,
			size = Vector3.new(c.h, c.r * 2, c.r * 2),
			cframe = CFrame.new(at + Vector3.new(0, c.h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		}))
		table.insert(colliders, { center = at, r = c.r, h = c.h, tall = c.tall })
		if item.climbable then
			CollectionService:AddTag(colliderParts[#colliderParts], "BossArenaDais") -- P3d C: 클라가 "단상 위에 섰다"를 안다(점프 틈 표시를 끈다)
		end
		height = math.max(height, c.h)
	end
	-- 조준 대상 = 모델(Monster 태그 + 구출 대상과 같은 "맞으면 알림만"). 루트는 투명 · 충돌 없음.
	local model = Instance.new("Model")
	model.Name = "구조물"
	local root = Looks.newPart(model, {
		name = "HumanoidRootPart", size = Vector3.new(2, 2, 2), transparency = 1, shadow = false,
		cframe = CFrame.new(center + Vector3.new(0, math.min(height, 2.5), 0)),
	})
	model.PrimaryPart = root
	local visuals = Looks.build(model, center, item, state.bossData)
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
		id = id, kind = item.kind, group = item.group, center = center, radius = item.radius, height = height, color = item.spec.color, model = model,
		colliders = colliders, colliderParts = colliderParts, visuals = visuals, climbable = item.climbable, item = item,
		hits = 0, lastHitAt = {}, broken = false, cracked = false, waveHits = 0,
	}
	local data = {
		id = "arena_obstacle", displayName = "구조물", isRescueTarget = true, bodyColor = item.spec.color, headColor = item.spec.color,
		hp = 0, attack = 0, goldDrop = 0, expReward = 0, moveSpeedStuds = 0, attackRangeStuds = 0, attackCooldownSeconds = 1,
	}
	MonsterState.init(model, data, root.Position, state.zoneKey, {
		isRescueTarget = true,
		rescueRemaining = function()
			return 1 - obstacle.hits / (obstacle.escape and REGROW.escapeHits or OBSTACLE.hitsToBreak)
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
					part.Color = part.Color:Lerp(Color3.new(0, 0, 0), 0.1)
				end
			end
			-- P3c B2: 부서지기 직전(남은 타격 crackAtHitsLeft)에는 금 간 표시가 붙는다. P3d D3: 끼임 구조물은 escapeHits(3)타에 부서진다.
			local needed = obstacle.escape and REGROW.escapeHits or OBSTACLE.hitsToBreak
			if obstacle.escape then
				BossArenaMap.fireEncase(state, obstacle, needed - obstacle.hits)
			end
			if not obstacle.cracked and needed - obstacle.hits <= OBSTACLE.crackAtHitsLeft then
				obstacle.cracked = true
				for _, part in ipairs(Looks.crack(model, center, item)) do
					table.insert(visuals, part)
				end
			end
			if obstacle.hits >= needed then
				BossArenaMap.breakObstacle(state.zoneKey, id, obstacle.escape and "escape" or "hits")
			end
		end,
	})
	state.obstacles[id] = obstacle
	return obstacle
end

local function spawnObstacles(state)
	local zone = zoneOfKey(state.zoneKey)
	for _, item in ipairs(state.layout.items) do
		spawnObstacle(state, zone, item)
	end
end

local function clearObstacles(state)
	for id in pairs(state.obstacles) do
		local obstacle = state.obstacles[id]
		state.obstacles[id] = nil
		destroyObstacle(obstacle)
		BossArenaMap.releaseEncased(state, obstacle) -- P3d D3: 끼인 채 리셋 · 보스전 끝이면 풀어 준다
	end
end

-- B4 둔덕: 층 높이 stepStuds의 원판을 겹쳐 쌓는다(아래 층이 가장 넓다 - 층마다 반경이 줄어 완만하다). 지면 폴더(보스 걸음 · 낙하점 · 드랍이 그 높이를 따른다).
local function buildMounds(state, zone)
	local floorColor = state.theme.floor.color
	for _, mound in ipairs(state.layout.mounds or {}) do
		for layer = 1, mound.layers do
			local radius = mound.radius * (1 - (layer - 1) / mound.layers)
			local topY = FLOOR_TOP_Y + mound.stepStuds * layer
			local part = Looks.newPart(GroundProbe.folder(), {
				name = "BossArenaMound", shape = "cylinder", collide = true, shadow = false,
				color = floorColor:Lerp(Color3.new(0, 0, 0), 0.05 * layer), material = state.theme.floor.material,
				size = Vector3.new(mound.stepStuds + 0.02, radius * 2, radius * 2),
				cframe = Looks.discCFrame(zone.center.X + mound.x, topY, zone.center.Z + mound.z, mound.stepStuds + 0.02),
			})
			CollectionService:AddTag(part, "BossArenaMound") -- 클라가 예고 도형을 둔덕 위로 띄운다(BossPatternVisuals.moundLift)
			table.insert(state.mounds, part)
		end
	end
end

-- 보스전 시작(BossEncounter.spawnEncounter가 텔레포트 전에 부른다). bossData = 인스턴스 데이터(색 · id · 킷). seed = 배치 시드(생략 = 새로 뽑는다 - 검증은 고정 시드).
function BossArenaMap.dress(zoneKey, bossData, seed)
	BossArenaMap.undress(zoneKey)
	local base = BossArenaMap.buildBase(zoneKey)
	local theme = BossArenaMap.themeFor(bossData and bossData.id)
	applyTheme(base, theme)
	local zone = zoneOfKey(zoneKey)
	local dressing = Instance.new("Model")
	dressing.Name = "BossArenaDressing_" .. zoneKey
	dressing.Parent = Workspace
	seed = seed or BossArenaMap.debugNextSeed or layoutRng:NextInteger(1, 2147483646)
	BossArenaMap.debugNextSeed = nil
	local startedAt = os.clock()
	local layout = ArenaLayout.generate(theme, seed, ArenaLayout.optionsFor(bossData))
	local state = { zoneKey = zoneKey, theme = theme, bossData = bossData, dressing = dressing, layout = layout, obstacles = {}, mounds = {},
		layoutOptions = ArenaLayout.optionsFor(bossData), regrowToken = nextRegrowSerial(), regrowRng = Random.new(seed + 7) }
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
	buildMounds(state, zone)
	outline(dressing)
	active[zoneKey] = state
	local report = layout.report
	print(("[forge-game] 보스맵 배치 시드: %s %d - 구조물 %d · 둔덕 %d · 시도 %d · 벽 틈 %.1f · 서로 %.1f · 돌진 보장 %.0f%% · 연결 %s · %.1fms"):format(
		zoneKey, seed, #layout.items, #(layout.mounds or {}), layout.attempts, report.minWallGap, report.minPairGap, report.coverage * 100,
		tostring(report.connected), (os.clock() - startedAt) * 1000))
	return state
end

function BossArenaMap.undress(zoneKey)
	local state = active[zoneKey]
	if not state then
		return
	end
	state.regrowToken = nextRegrowSerial() -- P3d D: 전조 중이던 재생성은 취소
	clearObstacles(state)
	for _, part in ipairs(state.mounds) do
		part:Destroy()
	end
	state.dressing:Destroy()
	active[zoneKey] = nil
end

-- 전멸 리셋 - 구조물을 처음대로(같은 시드 - 부서진 것도 다시) 세운다. 둔덕은 부서지지 않아 그대로다.
function BossArenaMap.resetObstacles(zoneKey)
	local state = active[zoneKey]
	if not state then
		return
	end
	state.regrowToken = nextRegrowSerial() -- P3d D: 전조 중이던 재생성은 취소(처음대로 다시 선다 - 재생성된 것도 치운다)
	clearObstacles(state)
	spawnObstacles(state)
end

function BossArenaMap.getTheme(zoneKey)
	local state = active[zoneKey]
	return state and state.theme or nil
end

-- 이번 보스전의 배치(시드 · 구조물 · 둔덕 · 검사 결과) - 검증 · 로그용.
function BossArenaMap.getLayout(zoneKey)
	local state = active[zoneKey]
	return state and state.layout or nil
end

-- 서 있는 구조물 목록(검증 · 검사기용 사본): { { id, kind, group, center, radius, height, hits, model, colliders, climbable } }.
function BossArenaMap.obstacles(zoneKey)
	local list = {}
	local state = active[zoneKey]
	for id, obstacle in pairs(state and state.obstacles or {}) do
		table.insert(list, {
			id = id, kind = obstacle.kind, group = obstacle.group, center = obstacle.center, radius = obstacle.radius, height = obstacle.height, hits = obstacle.hits,
			model = obstacle.model, colliders = obstacle.colliders, climbable = obstacle.climbable, cracked = obstacle.cracked, waveHits = obstacle.waveHits,
		})
	end
	table.sort(list, function(a, b)
		return a.id < b.id
	end)
	return list
end

-- 원(position, radius)이 서 있는 구조물의 충돌 원과 clearance 안으로 겹치는가(사용자 지시: 기믹 지형 - 얼음 기둥 · 모래 구덩이 - 이 구조물 위에 서지 않는다).
function BossArenaMap.overlapsObstacle(zoneKey, position, radius, clearance)
	local state = active[zoneKey]
	for _, obstacle in pairs(state and state.obstacles or {}) do
		for _, c in ipairs(obstacle.colliders) do
			local limit = c.r + radius + (clearance or 0)
			local dx, dz = position.X - c.center.X, position.Z - c.center.Z
			if dx * dx + dz * dz < limit * limit then
				return true
			end
		end
	end
	return false
end

-- 돌진 경로(origin에서 단위벡터 dir로 length)에 처음 걸리는 구조물과 "닿는 거리"(보스 몸통이 충돌 원 가장자리에 닿는 순간의 이동 거리). 없으면 nil.
function BossArenaMap.firstOnPath(zoneKey, origin, dir, length, bodyHalf)
	local state = active[zoneKey]
	if not state then
		return nil
	end
	return ArenaLayout.firstOnPath(state.obstacles, origin, dir, length, bodyHalf)
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
