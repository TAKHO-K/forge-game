-- BR1 새 조각의 그림(docs/design/boss-br1.md §0) - 서버(BossHandlersBR1 · BossPatterns)가 BossPatternEvent로 보낸 사실만 그린다. 판정 없음.
--   sector      부채꼴 · 반원(가는 조각을 호를 따라 놓는다 - 도넛 띠와 같은 방식) → 판정 순간 흰 섬광
--   projectile  전조(보스 위에 모이는 구체 · 공중 대상 머리 위 조준 · 지면이면 굴러갈 띠) → 서버 위치(10Hz)를 따라 그리는 투사체 → 끝(흰 파편)
--   vortex      돌아가는 물결 띠 + 가운데 폭발 원(진해진다) · 내 캐릭터가 반경 안이면 중심으로 당긴다(걷기보다 느리게 - 서버 판정과 무관한 힘)
--   chain       줄지어 선 원 → 보스 쪽부터 차례로 솟는 수정 가시
--   ambush      파고드는 먼지 → (추적 원은 기존 meteor 그림) → 솟는 먼지
-- 색 언어는 기존 그대로 - 위험 = UIColors.danger 한 색, 임팩트 = 흰색. 조각은 BossFx 풀(파티클 방출기 0).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local BossFx = require(script.Parent.BossFx)

local BossBR1View = {}

local player = Players.LocalPlayer
local DANGER = UIColors.danger
local WHITE = Color3.new(1, 1, 1)
local DUST = Color3.fromRGB(235, 228, 214) -- 흙먼지(BossMotionView와 같은 값)
local SECTOR_STEP_DEG = 6

local live = {} -- [Part] = true - reset 때 한 번에 지운다
local projectiles = {} -- [id] = { part, position, dir, speed, target, heightMode }
local vortex = nil -- { center, radius, pull, untilAt, parts }

local function newPart(size, color, transparency, shape)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = size
	part.Transparency = transparency or 0.4
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

local function fadeOut(part, seconds)
	TweenService:Create(part, TweenInfo.new(seconds), { Transparency = 1 }):Play()
	task.delay(seconds, function()
		destroy(part)
	end)
end

local function disc(center, radius, color, transparency)
	local part = newPart(Vector3.new(0.2, radius * 2, radius * 2), color, transparency, Enum.PartType.Cylinder)
	part.CFrame = CFrame.new(center + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90))
	return part
end

-- ─────────────────────────── sector ───────────────────────────
-- 부채꼴 = 호를 따라 SECTOR_STEP_DEG마다 사다리꼴 비슷한 조각(안쪽 ~ 바깥 반경 길이의 판)을 놓는다. 가운데 각 = angleDeg, 폭 = widthDeg.
local function sectorParts(data, color, transparency)
	local parts = {}
	local inner = data.innerRadius or 0
	local width = math.min(data.widthDeg, 360)
	local steps = math.max(2, math.ceil(width / SECTOR_STEP_DEG))
	local mid = (inner + data.radius) / 2
	local depth = data.radius - inner
	for i = 0, steps - 1 do
		local a = math.rad(data.angleDeg - width / 2 + width * (i + 0.5) / steps)
		local arc = 2 * math.pi * data.radius * (width / 360) / steps * 1.1
		-- 부채 조각은 바깥이 넓다 - 바깥 호 길이로 잡아 틈이 없게(안쪽은 겹친다)
		local part = newPart(Vector3.new(arc, 0.2, depth), color, transparency)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		part.CFrame = CFrame.lookAt(data.center + dir * mid + Vector3.new(0, 0.15, 0), data.center + dir * (mid + 1) + Vector3.new(0, 0.15, 0))
		table.insert(parts, part)
	end
	return parts
end

-- 대지 가르기(motion "handDrag"): 반원을 가르는 지름을 따라 흰 금이 보스에서 양쪽으로 번진다(전조 동안).
local function splitLine(data)
	local a = math.rad(data.angleDeg + 90)
	local dir = Vector3.new(math.cos(a), 0, math.sin(a))
	local line = newPart(Vector3.new(0.6, 0.3, 1), WHITE, 0.2)
	line.CFrame = CFrame.lookAt(data.center + Vector3.new(0, 0.3, 0), data.center + dir + Vector3.new(0, 0.3, 0))
	TweenService:Create(line, TweenInfo.new(data.seconds * 0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.6, 0.3, data.radius * 2) }):Play()
	task.delay(data.seconds, function()
		fadeOut(line, 0.3)
	end)
end

-- 주먹 내려찍기(motion "fist" - 연타 칸 · 강화 평타): 위에서 떨어지는 주먹 덩어리 + 먼지 고리. 낙석 기둥 대신.
function BossBR1View.fistSlam(position, radius)
	local fist = newPart(Vector3.new(radius * 0.9, radius * 0.7, radius * 0.9), WHITE, 0.15)
	fist.Material = Enum.Material.SmoothPlastic
	fist.CFrame = CFrame.new(position + Vector3.new(0, 14, 0))
	TweenService:Create(fist, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(position + Vector3.new(0, radius * 0.35, 0)) }):Play()
	task.delay(0.12, function()
		fadeOut(fist, 0.3)
		BossFx.ring(position, 1, radius + 2, DUST, 0.35)
		for i = 1, 6 do
			local a = i / 6 * 2 * math.pi
			BossFx.puff(position + Vector3.new(math.cos(a) * radius * 0.7, 0.5, math.sin(a) * radius * 0.7), 2, DUST, 0.5, Vector3.new(math.cos(a) * 4, 2, math.sin(a) * 4))
		end
		BossFx.shake(position, 0.4)
	end)
end

function BossBR1View.sector(data)
	if data.motion == "handDrag" then
		splitLine(data)
	end
	for _, part in ipairs(sectorParts(data, DANGER, 0.85)) do
		TweenService:Create(part, TweenInfo.new(data.seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = data.jumpable and 0.45 or 0.3 }):Play()
		task.delay(data.seconds, function()
			fadeOut(part, 0.15)
		end)
	end
	-- 점프로 넘는 부채꼴(jumpable)은 가장자리에 흰 물결선(진동파의 "뛰어라"와 같은 뜻) - 모양으로 구분한다.
	if data.jumpable then
		local edge = { center = data.center, angleDeg = data.angleDeg, widthDeg = data.widthDeg, radius = data.radius, innerRadius = data.radius - 1.2 }
		for _, part in ipairs(sectorParts(edge, WHITE, 0.4)) do
			task.delay(data.seconds, function()
				fadeOut(part, 0.15)
			end)
		end
	end
end

function BossBR1View.sectorImpact(data)
	for _, part in ipairs(sectorParts(data, WHITE, 0.15)) do
		fadeOut(part, 0.3)
	end
	BossFx.shake(data.center, 0.5)
end

-- ─────────────────────────── projectile ───────────────────────────
local STYLE = {
	orb = { shape = "ball", size = function(r) return Vector3.one * r * 1.4 end },
	bubble = { shape = "ball", size = function(r) return Vector3.one * r * 1.6 end, transparency = 0.45 },
	shard = { shape = "block", size = function(r) return Vector3.new(r * 0.6, r * 0.6, r * 1.8) end },
	spear = { shape = "block", size = function(r) return Vector3.new(r * 0.35, r * 0.35, r * 3.2) end },
	bolt = { shape = "block", size = function(r) return Vector3.new(r * 0.3, r * 0.3, r * 3.6) end, color = WHITE },
	snowball = { shape = "ball", size = function(r) return Vector3.one * r * 2 end, color = WHITE, material = Enum.Material.Snow, transparency = 0 },
	tornado = { shape = "cylinder", size = function(r) return Vector3.new(r * 3, r * 1.8, r * 1.8) end, transparency = 0.5, spin = true },
}

local function playerByUserId(userId)
	for _, p in ipairs(Players:GetPlayers()) do
		if p.UserId == userId then
			return p
		end
	end
	return nil
end

function BossBR1View.projTelegraph(data)
	local style = STYLE[data.style] or STYLE.orb
	local up = data.center + Vector3.new(0, data.launchHeight or 9, 0)
	-- 보스 위에 모이는 구체(개수만큼) - 전조 시간 동안 커진다.
	for i = 1, data.count do
		local a = (i - 1) / math.max(data.count, 1) * 2 * math.pi
		local at = up + Vector3.new(math.cos(a) * 2.5, 0, math.sin(a) * 2.5)
		local part = newPart(Vector3.one * 0.5, style.color or DANGER, 0.3, Enum.PartType.Ball)
		part.CFrame = CFrame.new(at)
		TweenService:Create(part, TweenInfo.new(data.seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = Vector3.one * 2.2 }):Play()
		task.delay(data.seconds, function()
			destroy(part)
		end)
	end
	-- 공중 대상 = 머리 위 조준 고리(하늘 쪽 표시 - 내려오면 피한다) · 지면 = 굴러갈 띠(대상 쪽).
	for _, userId in pairs(data.targetUserIds or {}) do
		local target = playerByUserId(userId)
		local root = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
		if root then
			if data.heightMode == "ground" then
				local toward = Vector3.new(root.Position.X - data.center.X, 0, root.Position.Z - data.center.Z)
				if toward.Magnitude > 1 then
					local length = math.min(toward.Magnitude + 30, 200)
					local band = newPart(Vector3.new(4, 0.2, length), DANGER, 0.8)
					band.CFrame = CFrame.lookAt(data.center + toward.Unit * (length / 2) + Vector3.new(0, 0.15, 0), data.center + toward.Unit * length + Vector3.new(0, 0.15, 0))
					TweenService:Create(band, TweenInfo.new(data.seconds), { Transparency = 0.45 }):Play()
					task.delay(data.seconds + 0.3, function()
						fadeOut(band, 0.3)
					end)
				end
			else
				local ring = newPart(Vector3.new(0.3, 5, 5), DANGER, 0.2, Enum.PartType.Cylinder)
				local connection
				connection = RunService.RenderStepped:Connect(function()
					if not live[ring] or not root.Parent then
						connection:Disconnect()
						return
					end
					ring.CFrame = CFrame.new(root.Position + Vector3.new(0, 4.5, 0)) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(os.clock() * 4, 0, 0)
				end)
				task.delay(data.seconds + 0.5, function()
					destroy(ring)
				end)
			end
		end
	end
end

function BossBR1View.projSpawn(data)
	local style = STYLE[data.style] or STYLE.orb
	local shape = style.shape == "ball" and Enum.PartType.Ball or (style.shape == "cylinder" and Enum.PartType.Cylinder or Enum.PartType.Block)
	local part = newPart(style.size(data.radius), style.color or DANGER, style.transparency or 0.15, shape)
	if style.material then
		part.Material = style.material
	end
	part.CFrame = CFrame.lookAt(data.position, data.position + data.dir)
	projectiles[data.id] = { part = part, position = data.position, dir = data.dir, speed = data.speed, style = style, heightMode = data.heightMode, radius = data.radius }
end

function BossBR1View.projSync(data)
	for _, entry in ipairs(data.list) do
		local p = projectiles[entry.id]
		if p then
			-- 서버 위치로 맞춘다(작은 차는 부드럽게, 크면 바로)
			local err = (entry.position - p.position).Magnitude
			p.position = err > 3 and entry.position or p.position:Lerp(entry.position, 0.5)
			p.dir = entry.dir
		end
	end
end

function BossBR1View.projEnd(data)
	local p = projectiles[data.id]
	projectiles[data.id] = nil
	if p then
		destroy(p.part)
	end
	for i = 1, 6 do
		local a = i / 6 * 2 * math.pi
		BossFx.chunk(data.position, Vector3.new(math.cos(a) * 14, 10, math.sin(a) * 14), 0.6, WHITE, 0.4)
	end
	BossFx.ring(data.position, 1, 5, WHITE, 0.3)
end

-- ─────────────────────────── vortex ───────────────────────────
function BossBR1View.vortex(data)
	local parts = {}
	for ring = 1, 3 do
		local r = data.radius * ring / 3
		local count = 10 + ring * 4
		for i = 1, count do
			local part = newPart(Vector3.new(r * 2 * math.pi / count * 0.55, 0.2, 1.2), DANGER, 0.55)
			table.insert(parts, { part = part, r = r, a = i / count * 2 * math.pi, speed = 2.2 / ring })
		end
	end
	local burst = disc(data.center, data.burstRadius, DANGER, 0.85)
	TweenService:Create(burst, TweenInfo.new(data.seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 0.25 }):Play()
	vortex = { center = data.center, radius = data.radius, pull = data.pullStudsPerSecond, untilAt = os.clock() + data.seconds, parts = parts, burst = burst }
end

function BossBR1View.vortexBurst(data)
	if vortex then
		for _, entry in ipairs(vortex.parts) do
			destroy(entry.part)
		end
		destroy(vortex.burst)
		vortex = nil
	end
	fadeOut(disc(data.center, data.radius, WHITE, 0.1), 0.35)
	for i = 1, 10 do
		local a = i / 10 * 2 * math.pi
		BossFx.puff(data.center + Vector3.new(math.cos(a) * data.radius * 0.6, 1, math.sin(a) * data.radius * 0.6), 3, WHITE, 0.6, Vector3.new(0, 8, 0))
	end
	BossFx.shake(data.center, 0.8)
end

-- ─────────────────────────── chain ───────────────────────────
local chainDiscs = {}

function BossBR1View.chain(data)
	chainDiscs = {}
	for index, position in ipairs(data.positions) do
		local part = disc(position, data.radius, DANGER, 0.85)
		local lead = data.seconds + data.interval * (index - 1)
		TweenService:Create(part, TweenInfo.new(lead, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 0.3 }):Play()
		chainDiscs[index] = part
	end
end

function BossBR1View.chainImpact(data)
	destroy(chainDiscs[data.index])
	chainDiscs[data.index] = nil
	-- 솟는 수정 가시(흰 기둥이 땅에서 튀어나와 사라진다)
	local spike = newPart(Vector3.new(data.radius * 0.9, 0.5, data.radius * 0.9), WHITE, 0.1)
	spike.CFrame = CFrame.new(data.position) * CFrame.Angles(0, math.rad(45), 0)
	TweenService:Create(spike, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = Vector3.new(data.radius * 0.9, 9, data.radius * 0.9), CFrame = CFrame.new(data.position + Vector3.new(0, 4.5, 0)) * CFrame.Angles(0, math.rad(45), 0),
	}):Play()
	task.delay(0.35, function()
		fadeOut(spike, 0.3)
	end)
end

-- ─────────────────────────── ambush ───────────────────────────
function BossBR1View.ambushDig(data)
	for i = 1, 10 do
		local a = i / 10 * 2 * math.pi
		task.delay(data.seconds * (i / 10), function()
			BossFx.puff(data.center + Vector3.new(math.cos(a) * 4, 1, math.sin(a) * 4), 3, DUST, 0.7, Vector3.new(0, 4, 0))
		end)
	end
end

function BossBR1View.ambushEmerge(data)
	for i = 1, 12 do
		local a = i / 12 * 2 * math.pi
		BossFx.chunk(data.position, Vector3.new(math.cos(a) * 18, 22, math.sin(a) * 18), 1, DUST, 0.7)
	end
	BossFx.shake(data.position, 1)
end

-- ─────────────────────────── 매 프레임 · 리셋 ───────────────────────────
function BossBR1View.reset()
	for part in pairs(live) do
		part:Destroy()
	end
	live = {}
	projectiles = {}
	vortex = nil
	chainDiscs = {}
end

function BossBR1View.debugState()
	local count = 0
	for _ in pairs(live) do
		count += 1
	end
	local projCount = 0
	for _ in pairs(projectiles) do
		projCount += 1
	end
	return { parts = count, projectiles = projCount, vortex = vortex ~= nil }
end

RunService.RenderStepped:Connect(function(dt)
	for _, p in pairs(projectiles) do
		p.position += p.dir * p.speed * dt
		if p.part.Parent then
			local cf = CFrame.lookAt(p.position, p.position + p.dir)
			if p.style.spin then
				cf = CFrame.new(p.position) * CFrame.Angles(0, os.clock() * 8, math.rad(90))
			end
			p.part.CFrame = cf
		end
	end
	if vortex then
		local now = os.clock()
		for _, entry in ipairs(vortex.parts) do
			entry.a += entry.speed * dt
			local dir = Vector3.new(math.cos(entry.a), 0, math.sin(entry.a))
			entry.part.CFrame = CFrame.lookAt(vortex.center + dir * entry.r + Vector3.new(0, 0.2, 0), vortex.center + dir * entry.r + Vector3.new(-dir.Z, 0.2, dir.X))
		end
		-- 끌림: 내 캐릭터가 반경 안이면 중심 쪽으로(루트 CFrame을 조금씩 - 모래 구덩이와 같은 방식). 잡힌 동안 · 죽은 동안은 끌지 않는다.
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 and now < vortex.untilAt and player:GetAttribute("BossTrapKind") == nil and not root.Anchored then
			local toCenter = Vector3.new(vortex.center.X - root.Position.X, 0, vortex.center.Z - root.Position.Z)
			if toCenter.Magnitude <= vortex.radius and toCenter.Magnitude > 0.5 then
				root.CFrame += toCenter.Unit * math.min(vortex.pull * dt, toCenter.Magnitude)
			end
		end
	end
end)

return BossBR1View
