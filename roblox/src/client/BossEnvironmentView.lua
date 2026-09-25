-- BR1 환경 변화의 그림 · 힘(docs/design/boss-br1.md §4) - 서버(BossEnvironment)가 보낸 구역만 그린다. 보이는 구역 = 서버 판정 구역(같은 표).
--   envTelegraph  구역을 위험색으로 옅게 깔고 가장자리에 금(흰 선)이 번진다 · 스타일별 한 가지 강조(용암 = 먼지 · 물 = 넘치는 물결 · 모래 = 소용돌이 · 바람 = 줄기)
--   envStart      구역이 진해진다(재질로 구분 - 용암 CrackedLava · 얼음물 Glass · 급류 Glass · 모래 Sand · 전기 Neon) · 밥상뒤집기 = 판이 들렸다 뒤집히는 그림
--   envWind       바람 방향이 돈다(바람이 불어 가는 반원의 가장자리 = 전기 벽)
--   힘(내 캐릭터만 - 서버 판정과 무관): pit = 반경 안이면 중심으로 끌린다 · wind = 바람 방향으로 밀린다(공중이면 airMultiplier배). 걷기(16)보다 약하다 - 버티면 나간다.
-- 큰 파트를 물리로 뒤집지 않는다 - 전부 Anchored 그림(사용자 지시).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local BossFx = require(script.Parent.BossFx)

local BossEnvironmentView = {}

local player = Players.LocalPlayer
local DANGER = UIColors.danger
local WHITE = Color3.new(1, 1, 1)
local DUST = Color3.fromRGB(235, 228, 214)
local STEP_DEG = 6

local STYLE_MATERIAL = {
	lava = Enum.Material.CrackedLava,
	ice = Enum.Material.Glass,
	water = Enum.Material.Glass,
	sand = Enum.Material.Sand,
	storm = Enum.Material.Neon,
	crystal = Enum.Material.Glass,
}

local live = {}
local current = nil -- { zones, parts = { [zone index] = { parts } }, style, active, forces }

local function newPart(size, color, transparency, material, shape)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = material or Enum.Material.Neon
	part.Color = color
	part.Size = size
	part.Transparency = transparency
	if shape then
		part.Shape = shape
	end
	part.Parent = Workspace
	live[part] = true
	return part
end

local function destroy(part)
	if part and live[part] then
		live[part] = nil
		part:Destroy()
	end
end

-- 부채꼴 · 고리(가운데 center · 가운데 각 angleDeg · 폭 widthDeg · inner ~ outer)를 호 조각으로.
local function arcParts(center, angleDeg, widthDeg, inner, outer, color, transparency, material)
	local parts = {}
	local steps = math.max(2, math.ceil(widthDeg / STEP_DEG))
	local mid = (inner + outer) / 2
	for i = 0, steps - 1 do
		local a = math.rad(angleDeg - widthDeg / 2 + widthDeg * (i + 0.5) / steps)
		local arc = 2 * math.pi * outer * (widthDeg / 360) / steps * 1.08
		local part = newPart(Vector3.new(arc, 0.25, outer - inner), color, transparency, material)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		part.CFrame = CFrame.lookAt(center + dir * mid + Vector3.new(0, 0.2, 0), center + dir * (mid + 1) + Vector3.new(0, 0.2, 0))
		table.insert(parts, part)
	end
	return parts
end

-- 구역 하나의 그림(전조 · 활성 공용 - 색 · 투명도 · 재질만 다르다).
local function zoneParts(z, transparency, material)
	if z.shape == "circle" then
		local part = newPart(Vector3.new(0.25, z.radius * 2, z.radius * 2), DANGER, transparency, material, Enum.PartType.Cylinder)
		part.CFrame = CFrame.new(z.center + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
		return { part }
	elseif z.shape == "ring" then
		return arcParts(z.center, 0, 360, z.beyond, z.radius, DANGER, transparency, material)
	elseif z.shape == "pit" then
		local core = newPart(Vector3.new(0.25, z.core * 2, z.core * 2), DANGER, transparency, material, Enum.PartType.Cylinder)
		core.CFrame = CFrame.new(z.center + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90))
		local slope = arcParts(z.center, 0, 360, z.radius - 1.2, z.radius, WHITE, 0.5, Enum.Material.SmoothPlastic) -- 끌림 반경 테두리(흰 선 - 위험이 아니라 경계)
		table.insert(slope, core)
		return slope
	elseif z.shape == "rect" then
		local part = newPart(Vector3.new(z.halfWidth * 2, 0.25, z.halfLength * 2), DANGER, transparency, material)
		part.CFrame = CFrame.new(z.center + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, -math.rad(z.angleDeg) + math.rad(90), 0)
		return { part }
	elseif z.shape == "wind" then
		return arcParts(z.center, z.angleDeg, 180, z.beyond, z.radius, DANGER, transparency, material)
	end
	return {}
end

local function clearParts()
	if current then
		for _, list in pairs(current.parts) do
			for _, part in ipairs(list) do
				destroy(part)
			end
		end
		current.parts = {}
	end
end

-- 금(가장자리에서 번지는 흰 선) - 전조 동안 몇 번 튄다.
local function crackAlong(z, seconds)
	local points = {}
	if z.shape == "circle" or z.shape == "pit" then
		local r = z.shape == "pit" and z.radius or z.radius
		for i = 1, 10 do
			local a = i / 10 * 2 * math.pi
			table.insert(points, { z.center + Vector3.new(math.cos(a) * r, 0.4, math.sin(a) * r), Vector3.new(-math.sin(a), 0, math.cos(a)) })
		end
	elseif z.shape == "ring" or z.shape == "wind" then
		local r = z.beyond
		for i = 1, 24 do
			local a = i / 24 * 2 * math.pi
			table.insert(points, { z.center + Vector3.new(math.cos(a) * r, 0.4, math.sin(a) * r), Vector3.new(-math.sin(a), 0, math.cos(a)) })
		end
	elseif z.shape == "rect" then
		local a = math.rad(z.angleDeg)
		local along, side = Vector3.new(math.cos(a), 0, math.sin(a)), Vector3.new(-math.sin(a), 0, math.cos(a))
		for i = -3, 3 do
			table.insert(points, { z.center + along * (z.halfLength * i / 3) + side * z.halfWidth + Vector3.new(0, 0.4, 0), along })
			table.insert(points, { z.center + along * (z.halfLength * i / 3) - side * z.halfWidth + Vector3.new(0, 0.4, 0), along })
		end
	end
	for index, entry in ipairs(points) do
		task.delay(seconds * (index / #points) * 0.8, function()
			if current then
				BossFx.streak(entry[1], entry[2], 5, 0.25, WHITE, 0.9, 0)
				BossFx.puff(entry[1], 2, DUST, 0.6, Vector3.new(0, 3, 0))
			end
		end)
	end
end

function BossEnvironmentView.telegraph(data)
	BossEnvironmentView.clear()
	current = { zones = data.zones, parts = {}, style = data.style, active = false }
	for index, z in ipairs(data.zones) do
		local parts = zoneParts(z, 0.88, Enum.Material.Neon)
		current.parts[index] = parts
		for _, part in ipairs(parts) do
			if part.Color == DANGER then
				TweenService:Create(part, TweenInfo.new(data.seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 0.55 }):Play()
			end
		end
		crackAlong(z, data.seconds)
	end
	BossFx.shake(data.zones[1] and data.zones[1].center or Vector3.zero, 0.4)
end

-- 밥상뒤집기(rect): 판이 가장자리를 축으로 들렸다가 뒤집혀 떨어지는 그림(Anchored 판을 트윈 - 물리 없음).
local function flipSlab(z)
	local a = -math.rad(z.angleDeg) + math.rad(90)
	local slab = newPart(Vector3.new(z.halfWidth * 2, 1.5, z.halfLength * 2), DUST, 0, Enum.Material.Slate)
	local base = CFrame.new(z.center + Vector3.new(0, 0.75, 0)) * CFrame.Angles(0, a, 0)
	slab.CFrame = base
	local hinge = base * CFrame.new(z.halfWidth, 0, 0)
	TweenService:Create(slab, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = hinge * CFrame.Angles(0, 0, math.rad(110)) * CFrame.new(-z.halfWidth, 0, 0),
	}):Play()
	task.delay(0.45, function()
		TweenService:Create(slab, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = hinge * CFrame.Angles(0, 0, math.rad(180)) * CFrame.new(-z.halfWidth, 0, 0), Transparency = 1,
		}):Play()
		task.delay(0.35, function()
			destroy(slab)
		end)
	end)
	for i = 1, 10 do
		BossFx.chunk(z.center + Vector3.new(0, 1, 0), Vector3.new(math.random(-15, 15), 25, math.random(-15, 15)), 1.2, DUST, 0.8)
	end
	BossFx.shake(z.center, 1)
end

function BossEnvironmentView.start(data)
	if not current then
		current = { zones = data.zones, parts = {}, style = data.style }
	end
	clearParts()
	current.zones = data.zones
	current.active = true
	current.untilAt = os.clock() + data.seconds
	local material = STYLE_MATERIAL[data.style] or Enum.Material.Neon
	for index, z in ipairs(data.zones) do
		current.parts[index] = zoneParts(z, 0.35, material)
		if z.shape == "rect" then
			flipSlab(z)
		end
	end
end

function BossEnvironmentView.wind(data)
	if not current then
		return
	end
	clearParts()
	current.zones = data.zones
	local material = STYLE_MATERIAL[current.style] or Enum.Material.Neon
	for index, z in ipairs(data.zones) do
		current.parts[index] = zoneParts(z, 0.35, material)
	end
end

function BossEnvironmentView.clear()
	clearParts()
	current = nil
end

function BossEnvironmentView.reset()
	current = nil
	fields = {}
	for part in pairs(live) do
		part:Destroy()
	end
	live = {}
end

function BossEnvironmentView.debugState()
	local count = 0
	for _ in pairs(live) do
		count += 1
	end
	return { parts = count, active = current ~= nil and current.active == true }
end

-- 빙판(field kind "slippery" - 서리 거인 발 구르기): 원 안 지면에 서 있으면 미끄러진다(수평 속도가 한 프레임에 목표 쪽으로 SLIP_BLEND만큼만 - 관성).
-- 판정 없음(서버는 알리기만 한다). 원 = 옅은 흰 판(Glass).
local SLIP_BLEND = 0.06
local fields = {} -- { center, radius, untilAt, part }
local lastVelocity = Vector3.zero

function BossEnvironmentView.field(data)
	if data.kind ~= "slippery" then
		return
	end
	local part = newPart(Vector3.new(0.2, data.radius * 2, data.radius * 2), WHITE, 0.55, Enum.Material.Glass, Enum.PartType.Cylinder)
	part.CFrame = CFrame.new(data.center + Vector3.new(0, 0.18, 0)) * CFrame.Angles(0, 0, math.rad(90))
	table.insert(fields, { center = data.center, radius = data.radius, untilAt = os.clock() + data.seconds, part = part })
	task.delay(data.seconds, function()
		TweenService:Create(part, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		task.delay(0.4, function()
			destroy(part)
		end)
	end)
end

RunService.Heartbeat:Connect(function()
	if #fields == 0 then
		return
	end
	local now = os.clock()
	for i = #fields, 1, -1 do
		if now > fields[i].untilAt then
			table.remove(fields, i)
		end
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or root.Anchored or humanoid.FloorMaterial == Enum.Material.Air then
		lastVelocity = root and root.AssemblyLinearVelocity or Vector3.zero
		return
	end
	local inside = false
	for _, f in ipairs(fields) do
		local d = Vector3.new(root.Position.X - f.center.X, 0, root.Position.Z - f.center.Z).Magnitude
		inside = inside or d <= f.radius
	end
	local v = root.AssemblyLinearVelocity
	if inside then
		local flat = Vector3.new(lastVelocity.X, 0, lastVelocity.Z):Lerp(Vector3.new(v.X, 0, v.Z), SLIP_BLEND)
		root.AssemblyLinearVelocity = Vector3.new(flat.X, v.Y, flat.Z)
		v = root.AssemblyLinearVelocity
	end
	lastVelocity = v
end)

-- 힘(내 캐릭터) · 바람 줄기(그림).
local windStreakAt = 0
RunService.Heartbeat:Connect(function(dt)
	if not current or not current.active or os.clock() > (current.untilAt or 0) then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 or root.Anchored or player:GetAttribute("BossTrapKind") ~= nil then
		return
	end
	local airborne = humanoid:GetState() == Enum.HumanoidStateType.Freefall or humanoid:GetState() == Enum.HumanoidStateType.Jumping
	for _, z in ipairs(current.zones) do
		if z.shape == "pit" and z.pull then
			local toCenter = Vector3.new(z.center.X - root.Position.X, 0, z.center.Z - root.Position.Z)
			if toCenter.Magnitude <= z.radius and toCenter.Magnitude > 0.5 then
				root.CFrame += toCenter.Unit * math.min(z.pull * dt, toCenter.Magnitude)
			end
		elseif z.shape == "wind" and z.push then
			local a = math.rad(z.angleDeg)
			local push = Vector3.new(math.cos(a), 0, math.sin(a)) * z.push * (airborne and (z.airMultiplier or 1) or 1)
			root.CFrame += push * dt
			if os.clock() >= windStreakAt then
				windStreakAt = os.clock() + 0.08
				local offset = Vector3.new(math.random(-40, 40), math.random(2, 8), math.random(-40, 40))
				BossFx.streak(root.Position + offset - push.Unit * 20, push.Unit, 8, 0.2, WHITE, 0.5, 40)
			end
		end
	end
end)

return BossEnvironmentView
