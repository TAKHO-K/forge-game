-- BOSS-NIGHT-2 2b 바닥 자국(겉모습만 - 피해 · 판정 · 충돌 · 조준 · 이동 방해 없음): 폭풍 1폼 검기가 지나간 그을린 길 · 지진파가 지나간 균열.
--   scorch(at, dir, width, length)   검기 길 한 칸(그을린 띠 + 가끔 잔불 선)
--   trackWave(data)                   shockwave 사건(서버 시계 × 속도 = 반경) 따라 stepStuds마다 균열 + 파편
-- 파트 = 풀(종류별 상한 max - 넘으면 가장 오래된 자국부터 다시 씀 · 생성/파괴 반복 없음). 수치 = BossFxData.groundMarks.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local G = require(ReplicatedStorage.Shared.data.BossFxData).groundMarks
local ArtAssetIds = require(ReplicatedStorage.Shared.data.ArtAssetIds)
-- BOSS-NIGHT-2 3: 균열 = 그림 판(Decal) - 파트 수 260 → 상한 80. 그림 id가 없으면 옛 선 파트로.
local DEC = G.crack.decal
local decalEntry = DEC and ArtAssetIds[DEC.asset]
local decalImage = decalEntry and decalEntry.image and ("rbxassetid://" .. tostring(decalEntry.image)) or nil
local BossGroundMarks = {}

local FAR = CFrame.new(0, -5000, 0)
local folder = nil
local idle = {} -- 쉬는 파트
local live = { scorch = {}, crack = {} } -- [종류] = { { parts = { {part, base, glow} }, born } } 오래된 순
local waves = {}
local rng = Random.new()
local scorchN = 0

local function acquire()
	if not (folder and folder.Parent) then
		folder = Instance.new("Folder")
		folder.Name = "BossGroundMarks"
		folder.Parent = Workspace
		idle = {}
	end
	local part = table.remove(idle)
	if part and part:FindFirstChild("CrackDecal") then
		part:FindFirstChild("CrackDecal").Transparency = 1 -- 선 파트로 다시 쓸 때 그림은 숨김
	end
	if not part then
		part = Instance.new("Part")
		part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
		part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		part.Name = "GroundMark"
		part.Parent = folder
	end
	return part
end

local decalIdle = {}
local function acquireDecal()
	local part = acquire()
	local decal = part:FindFirstChild("CrackDecal")
	if not decal then
		decal = Instance.new("Decal")
		decal.Name = "CrackDecal"
		decal.Face = Enum.NormalId.Top
		decal.Parent = part
	end
	part.Transparency = 1
	return part, decal
end

local function releaseMark(mark)
	for _, e in ipairs(mark.parts) do
		e.part.CFrame = FAR
		e.part.Transparency = 1
		if e.decal then
			e.decal.Transparency = 1
			table.insert(decalIdle, e.part)
		else
			table.insert(idle, e.part)
		end
	end
	mark.parts = {}
end

local function count(kind)
	local n = 0
	for _, m in ipairs(live[kind]) do
		n += #m.parts
	end
	return n
end

-- 상한: 이 자국을 더하면 넘을 때 가장 오래된 자국부터 거둔다
local function makeRoom(kind, need)
	local cap = (kind == "crack" and decalImage) and DEC.max or G[kind].max
	while #live[kind] > 0 and count(kind) + need > cap do
		releaseMark(table.remove(live[kind], 1))
	end
end

local function put(mark, color, material, transparency, size, cf, glow)
	local part = acquire()
	part.Color, part.Material, part.Size, part.CFrame = color, material, size, cf
	part.Transparency = transparency
	table.insert(mark.parts, { part = part, base = transparency, glow = glow })
end

local function segmentCf(a, b)
	return CFrame.lookAt((a + b) / 2, b), (b - a).Magnitude
end

function BossGroundMarks.scorch(at, dir, width, length)
	local S = G.scorch
	makeRoom("scorch", 2)
	local mark = { parts = {}, born = os.clock(), kind = "scorch" }
	local p = at + Vector3.new(0, S.lift, 0)
	local cf = CFrame.lookAt(p, p + dir)
	put(mark, S.color, Enum.Material.SmoothPlastic, S.transparency, Vector3.new(width * rng:NextNumber(0.85, 1.0), 0.05, length * 1.05), cf, false)
	scorchN += 1
	if scorchN % S.emberEvery == 0 then
		local side = dir:Cross(Vector3.yAxis) * rng:NextNumber(-width * 0.3, width * 0.3)
		put(mark, S.ember, Enum.Material.Neon, S.emberTransparency, Vector3.new(S.emberWidth, 0.06, length * 0.9), cf + side + Vector3.new(0, 0.02, 0), true)
	end
	table.insert(live.scorch, mark)
end

local function crackStep(center, radius)
	local C = G.crack
	local need = C.perStep * C.segments + C.debris
	makeRoom("crack", need)
	local mark = { parts = {}, born = os.clock(), kind = "crack" }
	local y = Vector3.new(0, C.lift, 0)
	for i = 1, C.perStep do
		local a = rng:NextNumber(0, 2 * math.pi)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local len = rng:NextNumber(C.length[1], C.length[2])
		-- 바깥쪽으로 들쭉날쭉 · 반경 따라 조금 휘어짐
		local p0 = center + dir * (radius - len * 0.5) + y
		local side = dir:Cross(Vector3.yAxis)
		local glowLine = (i % C.glowEvery) == 0
		for s = 1, C.segments do
			local p1 = center + dir * (radius - len * 0.5 + len * s / C.segments) + side * rng:NextNumber(-C.jitter, C.jitter) + y
			local cf, l = segmentCf(p0, p1)
			put(mark, C.color, Enum.Material.Slate, C.transparency, Vector3.new(C.width * rng:NextNumber(0.7, 1.2), 0.05, l + 0.15), cf, false)
			p0 = p1
		end
		if glowLine then
			local cf = CFrame.lookAt(center + dir * radius + y + Vector3.new(0, 0.02, 0), center + dir * (radius + 1) + y)
			put(mark, C.glow, Enum.Material.Neon, C.glowTransparency, Vector3.new(0.12, 0.06, len * 0.7), cf, true)
		end
	end
	for _ = 1, C.debris do
		local a = rng:NextNumber(0, 2 * math.pi)
		local s = rng:NextNumber(C.debrisSize[1], C.debrisSize[2])
		local at = center + Vector3.new(math.cos(a), 0, math.sin(a)) * (radius + rng:NextNumber(-1, 1)) + Vector3.new(0, s * 0.3, 0)
		put(mark, C.debrisColor, Enum.Material.Slate, 0, Vector3.new(s, s * 0.6, s * 0.8), CFrame.new(at) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0), false)
	end
	table.insert(live.crack, mark)
end

-- 그림 판 한 장(크기 · 방향 무작위 · 보스 색조)
local function putDecal(mark, at, tint)
	local part = table.remove(decalIdle)
	local decal
	if part then
		decal = part:FindFirstChild("CrackDecal")
	else
		part, decal = acquireDecal()
	end
	decal.Texture = decalImage
	decal.Color3 = tint or Color3.new(1, 1, 1)
	decal.Transparency = DEC.transparency
	local size = rng:NextNumber(DEC.size[1], DEC.size[2])
	part.Size = Vector3.new(size, 0.05, size)
	part.CFrame = CFrame.new(at + Vector3.new(0, DEC.lift, 0)) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0)
	part.Transparency = 1
	table.insert(mark.parts, { part = part, decal = decal, base = DEC.transparency })
end

local function crackDecalStep(center, radius, tint)
	makeRoom("crack", DEC.perStep)
	local mark = { parts = {}, born = os.clock(), kind = "crack" }
	for _ = 1, DEC.perStep do
		local a = rng:NextNumber(0, 2 * math.pi)
		putDecal(mark, center + Vector3.new(math.cos(a), 0, math.sin(a)) * radius, tint)
	end
	table.insert(live.crack, mark)
end

local function enabledFor(bossId)
	if decalImage then
		return bossId and DEC.bosses[bossId]
	end
	return bossId and G.crack.bosses[bossId]
end

function BossGroundMarks.trackWave(data)
	if data.air or not enabledFor(data.bossId) then
		return
	end
	local step = decalImage and DEC.stepStuds or G.crack.stepStuds
	table.insert(waves, { center = Vector3.new(data.center.X, data.center.Y, data.center.Z), serverStart = data.serverStart, speed = data.speed, maxRadius = data.maxRadius, next = step, step = step,
		tint = decalImage and DEC.tints[data.bossId] or nil })
end

-- 단발 땅 치기(동작 세트 impacts[동작].crack = 반경 stud): 충격 자리 둘레에 그림 판 burst장(BossBodyFx.impact)
function BossGroundMarks.crackBurst(center, radius, bossId)
	if not (decalImage and enabledFor(bossId)) then
		return
	end
	makeRoom("crack", DEC.burst)
	local mark = { parts = {}, born = os.clock(), kind = "crack" }
	for i = 1, DEC.burst do
		local a = (i / DEC.burst) * 2 * math.pi + rng:NextNumber(-0.4, 0.4)
		local r = i == 1 and 0 or rng:NextNumber(radius * 0.35, radius * 0.75)
		putDecal(mark, center + Vector3.new(math.cos(a), 0, math.sin(a)) * r, DEC.tints[bossId])
	end
	table.insert(live.crack, mark)
end

function BossGroundMarks.reset()
	for _, kind in ipairs({ "scorch", "crack" }) do
		for _, m in ipairs(live[kind]) do
			releaseMark(m)
		end
		live[kind] = {}
	end
	waves = {}
end

function BossGroundMarks.stats()
	return { scorch = count("scorch"), crack = count("crack"), idle = #idle + #decalIdle, waves = #waves, decal = decalImage ~= nil }
end

local glowAcc = 0
RunService.Heartbeat:Connect(function(dt)
	if #waves > 0 then
		local t = Workspace:GetServerTimeNow()
		for i = #waves, 1, -1 do
			local w = waves[i]
			local r = (t - w.serverStart) * w.speed
			while r >= w.next and w.next <= w.maxRadius do
				if decalImage then
					crackDecalStep(w.center, w.next, w.tint)
				else
					crackStep(w.center, w.next)
				end
				w.next += w.step
			end
			if r > w.maxRadius then
				table.remove(waves, i)
			end
		end
	end
	if #live.scorch == 0 and #live.crack == 0 then
		return
	end
	glowAcc += dt
	local glowTick = glowAcc >= 1 / G.glowHz
	if glowTick then
		glowAcc = 0
	end
	local now = os.clock()
	for _, kind in ipairs({ "scorch", "crack" }) do
		local cfg, list = G[kind], live[kind]
		for i = #list, 1, -1 do
			local m = list[i]
			local age = now - m.born
			if age >= cfg.holdSeconds + cfg.fadeSeconds then
				releaseMark(m)
				table.remove(list, i)
			elseif age > cfg.holdSeconds or glowTick then
				local fade = math.clamp((age - cfg.holdSeconds) / cfg.fadeSeconds, 0, 1)
				for _, e in ipairs(m.parts) do
					local base = e.base
					if e.glow then
						base = math.min(1, base + (math.random() < 0.3 and 0.1 or 0))
					end
					if e.decal then
						e.decal.Transparency = base + (1 - base) * fade
					else
						e.part.Transparency = base + (1 - base) * fade
					end
				end
			end
		end
	end
end)

return BossGroundMarks
