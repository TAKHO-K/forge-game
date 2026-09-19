-- 보스 아레나 동적 지형의 그리기·충돌(29-3, PRD 20.73 [2-7] · 20.76). 서버(BossArenaProps)는 논리 목록만 갖고
-- BossPatternEvent로 "생겼다(propSpawn)·사라졌다(propRemove)·전부 치워라(propsClear)"만 알린다 - 파트는 전부 여기서,
-- 각자의 클라에서 만든다(서버 인스턴스 0개). 캐릭터 물리는 클라 소유라 여기서 만든 Anchored 파트에 정상적으로 막힌다.
--
-- 전역 기믹의 전조도 여기서 그린다(서리 거인의 포효): 25-4 색 언어 그대로 - 바닥 전체를 위험색(빨강) 한 장으로 깔고
-- **안전지대만 비운다**(20.73 [2-0] 1번 "빨강이 없는 곳 = 안전"). 비우는 방법은 그 위에 바닥색 띠를 얹는 것이다 -
-- 기둥마다 보스 반대쪽으로 뻗는 폭 = 기둥 지름의 띠("기둥의 그림자"). 탑다운 15° 카메라에서는 기둥이 어느 쪽을
-- 가리는지가 한눈에 안 들어오므로 그림자를 직접 그려 준다. 띠는 실제 판정(벌어지는 쐐기 + 몸통 반폭)보다 좁다 -
-- 그린 곳 안에 서 있으면 반드시 안전하다(보이는 것보다 덜 맞는 쪽으로만 어긋난다, shared/BossPropMath).
-- 새 색·새 파티클·새 에셋 없음: 빨강 = UIColors.danger, 흰색 = 임팩트, 기둥 = 서버가 준 기존 색(보스 머리색).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)

local BossArenaPropsView = {}

local DANGER_COLOR = UIColors.danger
local IMPACT_COLOR = Color3.new(1, 1, 1)
local ARENA_FLOOR_COLOR = Color3.fromRGB(30, 15, 15) -- BossEncounter.buildArena의 바닥색과 같은 값 - "빨강을 비운 자리"
local SHADOW_LENGTH_STUDS = 48 -- 그림자 띠의 길이(기둥 뒤 3초 걸음 = 48stud까지 그린다 - 판정은 벽까지다)
local COLLIDE_CLEARANCE_STUDS = 1.5

local player = Players.LocalPlayer

-- [id] = { part, position, radius }
local props = {}
local telegraphParts = {}

local function newPart(size, color, transparency, material)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = material
	part.Color = color
	part.Size = size
	part.Transparency = transparency
	part.Parent = Workspace
	return part
end

local function fadeAndDestroy(part, seconds)
	TweenService:Create(part, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 1 }):Play()
	task.delay(seconds, function()
		part:Destroy()
	end)
end

-- ─────────────────────────── 지형 ───────────────────────────

-- 모래 구덩이(29-3 개미지옥): 비탈 = 모래색 원판(기존 색), 바닥(중심부) = 위험색 원판("지금 여기 있으면 맞는다").
-- armSeconds 동안 서서히 드러나고, 그 뒤부터 내 캐릭터가 비탈 위에 있으면 중심으로 끌려간다(아래 start의 루프).
local function newFlatDisc(position, radius, color, material, lift)
	local disc = newPart(Vector3.new(0.2, radius * 2, radius * 2), color, 1, material)
	disc.Shape = Enum.PartType.Cylinder
	disc.CFrame = CFrame.new(position + Vector3.new(0, lift, 0)) * CFrame.Angles(0, 0, math.rad(90))
	return disc
end

local function spawnPit(data)
	local slope = newFlatDisc(data.position, data.radius, data.color, Enum.Material.Sand, 0.08)
	local core = newFlatDisc(data.position, data.coreRadius, DANGER_COLOR, Enum.Material.Neon, 0.14)
	slope.Name = "BossArenaPit"
	local info = TweenInfo.new(data.armSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(slope, info, { Transparency = 0.15 }):Play()
	TweenService:Create(core, info, { Transparency = 0.3 }):Play()
	props[data.id] = {
		part = slope, extra = core, position = data.position, radius = data.radius, isPit = true,
		coreRadius = data.coreRadius, pull = data.pullStudsPerSecond, armedAt = os.clock() + data.armSeconds,
	}
end

-- data = { id, kind, position(지면), radius, height, color }
function BossArenaPropsView.spawn(data)
	if props[data.id] then
		return
	end
	if data.coreRadius then
		spawnPit(data)
		return
	end
	-- 세로 원기둥(Cylinder는 로컬 X축이 높이 - Z축으로 90도 돌려 세운다). 바닥에서 솟아오른다.
	local part = newPart(Vector3.new(0.5, data.radius * 2, data.radius * 2), data.color, 0.15, Enum.Material.Ice)
	part.Name = "BossArenaProp"
	part.Shape = Enum.PartType.Cylinder
	part.CFrame = CFrame.new(data.position + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90))
	TweenService:Create(part, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(data.height, data.radius * 2, data.radius * 2),
		CFrame = CFrame.new(data.position + Vector3.new(0, data.height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	}):Play()
	props[data.id] = { part = part, position = data.position, radius = data.radius }
end

function BossArenaPropsView.remove(ids)
	for _, id in ipairs(ids) do
		local entry = props[id]
		if entry then
			props[id] = nil
			if entry.extra then
				fadeAndDestroy(entry.extra, 0.3)
			end
			entry.part.CanCollide = false
			if not entry.isPit then
				entry.part.Color = IMPACT_COLOR -- 부서지는 순간 = 임팩트(흰색)
			end
			fadeAndDestroy(entry.part, 0.3)
		end
	end
end

function BossArenaPropsView.clear()
	for id, entry in pairs(props) do
		entry.part:Destroy()
		if entry.extra then
			entry.extra:Destroy()
		end
		props[id] = nil
	end
	BossArenaPropsView.clearTelegraph()
end

-- ─────────────────────────── 전역 기믹 전조 ───────────────────────────

function BossArenaPropsView.clearTelegraph()
	for _, part in ipairs(telegraphParts) do
		part:Destroy()
	end
	telegraphParts = {}
end

-- data = gimmickTelegraph 이벤트(center = 보스 발밑, zoneCenter·zoneHalfSize = 아레나, seconds)
function BossArenaPropsView.showGlobalTelegraph(data)
	BossArenaPropsView.clearTelegraph()
	local sheet = newPart(Vector3.new(data.zoneHalfSize * 2, 0.2, data.zoneHalfSize * 2), DANGER_COLOR, 0.85, Enum.Material.Neon)
	sheet.CFrame = CFrame.new(data.zoneCenter + Vector3.new(0, 0.12, 0))
	TweenService:Create(sheet, TweenInfo.new(data.seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 0.4 }):Play()
	-- 29-4 범람: 위험색 판이 곧 수면이다 - 예고 동안 riseStuds까지 차오른다(수면이 시계). 판보다 높은 단 윗면만 빨강 밖에 남는다.
	if data.safeZone and data.safeZone.riseStuds then
		TweenService:Create(sheet, TweenInfo.new(data.seconds, Enum.EasingStyle.Linear), {
			CFrame = sheet.CFrame + Vector3.new(0, data.safeZone.riseStuds, 0),
		}):Play()
	end
	table.insert(telegraphParts, sheet)

	-- 29-4 과충전: 원형 안전지대(피뢰침 곁) - 같은 문법이다. 빨강 위에 바닥색 원판을 얹어 "여기만 비어 있다"를 그린다.
	for _, circle in ipairs(data.safeCircles or {}) do
		local hole = newFlatDisc(Vector3.new(circle.center.X, data.zoneCenter.Y, circle.center.Z), circle.radius, ARENA_FLOOR_COLOR, Enum.Material.Slate, 0.28)
		hole.Transparency = 0
		table.insert(telegraphParts, hole)
	end

	for _, entry in pairs(props) do
		local away = Vector3.new(entry.position.X - data.center.X, 0, entry.position.Z - data.center.Z)
		if not entry.isPit and away.Magnitude > 1e-3 then
			local dir = away.Unit
			local from = Vector3.new(entry.position.X, data.zoneCenter.Y + 0.28, entry.position.Z)
			local shadow = newPart(Vector3.new(entry.radius * 2, 0.16, SHADOW_LENGTH_STUDS), ARENA_FLOOR_COLOR, 0, Enum.Material.Slate)
			shadow.CFrame = CFrame.lookAt(from + dir * (SHADOW_LENGTH_STUDS / 2), from + dir * SHADOW_LENGTH_STUDS)
			table.insert(telegraphParts, shadow)
		end
	end
end

-- 판정 순간 - 바닥이 흰색으로 번쩍이고 사라진다(임팩트 = 흰색). 그림자 띠는 바로 지운다.
function BossArenaPropsView.resolveTelegraph()
	local parts = telegraphParts
	telegraphParts = {}
	for index, part in ipairs(parts) do
		if index == 1 then
			part.Color = IMPACT_COLOR
			part.Transparency = 0.3
			fadeAndDestroy(part, 0.35)
		else
			part:Destroy()
		end
	end
end

-- 기둥의 충돌은 내 캐릭터가 그 기둥 밖으로 나온 뒤에 켠다 - 낙빙을 맞은 자리에 기둥이 솟으면 캐릭터가 기둥 속에
-- 끼거나 위로 튕겨 오른다. (기둥 "안"은 포효의 안전지대가 아니다 - shared/BossPropMath.isShielded.)
function BossArenaPropsView.start()
	RunService.Heartbeat:Connect(function(dt)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		for _, entry in pairs(props) do
			if entry.isPit then
				-- 비탈 위에 있으면 중심으로 끌려간다. 내 캐릭터의 물리는 이 클라 소유라 여기서 옮긴다(컨베이어와 같은 방식).
				-- 잡힌 동안(루트가 서버에 고정돼 있다)·죽은 동안에는 끌지 않는다. 중심 0.5stud 안에서는 멈춘다(떨림 방지).
				local toCenter = Vector3.new(entry.position.X - root.Position.X, 0, entry.position.Z - root.Position.Z)
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if os.clock() >= entry.armedAt and toCenter.Magnitude <= entry.radius and toCenter.Magnitude > 0.5
					and player:GetAttribute("BossTrapKind") == nil and humanoid and humanoid.Health > 0 then
					root.CFrame += toCenter.Unit * math.min(entry.pull * dt, toCenter.Magnitude)
				end
			elseif not entry.part.CanCollide then
				local dx, dz = root.Position.X - entry.position.X, root.Position.Z - entry.position.Z
				if math.sqrt(dx * dx + dz * dz) > entry.radius + COLLIDE_CLEARANCE_STUDS then
					entry.part.CanCollide = true
				end
			end
		end
	end)
end

return BossArenaPropsView
