-- GUARDIAN-V3 새 몸 수호자 바닥 그림(판정 무관 - 서버 사건의 자리 · 반경 · 시각 그대로): 연보라 균열 표시(빨강 금지) + 지진파 돌판 · 수정 조각 링.
--   chargeCrack(focus) / chargeEnd(charge)  돌진 경로 = 가장자리 균열선 두 줄(폭 = 몸 폭 = 서버 halfWidth) + 옅은 채움
--   leapTelegraph · leapAim · leapImpact     도약 착지 = 균열 원(반경 = 판정) · 대상 따라 움직이다 lockSeconds 전에 고정(밝아짐)
--   quakeTelegraph(shockTelegraph)          찍기 전 발밑 균열 링(옛 빨강 원판 대신)
--   quakeWave(shockwave)                    땅 파동 = 파도 앞면 돌판(솟았다 가라앉음) + 바닥 균열 전파 · 공중 파동 = 떠다니는 수정 조각 링(반경 = 서버 시계 × 속도 - 판정과 같은 시각)
-- 파트 = 풀(종류별 · 만든 파트는 다시 쓴다 - 생성/파괴 반복 없음). 수치 = BossFxData.guardianQuake · 색 = BossFrameworkData.v3[보스].marks(채움 = 연보라 비발광 · 균열선 = 보라 Neon).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BossFxData = require(ReplicatedStorage.Shared.data.BossFxData)
local BossFrameworkData = require(ReplicatedStorage.Shared.data.BossFrameworkData)
local BossFx = require(script.Parent.BossFx)

local Q = BossFxData.guardianQuake
local BossQuakeView = {}

local FAR = CFrame.new(0, -5000, 0)
local folder = nil
local pools = {} -- [kind] = { 쉬는 파트 }
local groups = {} -- 살아 있는 묶음 { parts, update(g, now) → 끝났으면 true }
local rng = Random.new()

local function marksOf(bossId)
	local cfg = bossId and BossFrameworkData.v3[bossId]
	return cfg and cfg.marks or BossFrameworkData.v3.section_guardian.marks
end

local function acquire(kind)
	if not (folder and folder.Parent) then
		folder = Instance.new("Folder")
		folder.Name = "BossQuakeView"
		folder.Parent = Workspace
		pools = {}
	end
	local pool = pools[kind] or {}
	pools[kind] = pool
	local part = table.remove(pool)
	if not part then
		part = Instance.new("Part")
		part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
		part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		part.Name = "Quake_" .. kind
		if kind == "disc" then
			part.Shape = Enum.PartType.Cylinder
		end
		part.Parent = folder
	end
	part.Transparency = 1
	return part
end

local function release(kind, part)
	part.CFrame = FAR
	part.Transparency = 1
	table.insert(pools[kind], part)
end

local function releaseGroup(g)
	for _, entry in ipairs(g.parts) do
		release(entry.kind, entry.part)
	end
	g.parts = {}
	g.dead = true
end

local function add(g, kind)
	local part = acquire(kind)
	table.insert(g.parts, { kind = kind, part = part })
	return part
end

local function style(part, color, material)
	part.Color = color
	part.Material = material or Enum.Material.Neon
end

-- 가는 판(a → b · 폭 w · 높이 h) 놓기
local function placeSegment(part, a, b, w, h)
	local d = b - a
	local len = d.Magnitude
	if len < 1e-3 then
		part.CFrame = FAR
		return
	end
	part.Size = Vector3.new(w, h, len)
	part.CFrame = CFrame.lookAt((a + b) / 2, b)
end

-- 들쭉날쭉한 점들(a → b · n칸 · 옆으로 ±jitter · 끝점 고정)
local function jaggedPoints(a, b, n, jitter)
	local d = b - a
	local side = Vector3.new(-d.Z, 0, d.X)
	side = side.Magnitude > 1e-3 and side.Unit or Vector3.xAxis
	local list = { a }
	for i = 1, n - 1 do
		table.insert(list, a + d * (i / n) + side * rng:NextNumber(-jitter, jitter))
	end
	table.insert(list, b)
	return list
end

local function newGroup(update)
	local g = { parts = {}, update = update }
	table.insert(groups, g)
	return g
end

-- ─────────────────────────── 돌진 경로 균열선 ───────────────────────────
local chargeGroup = nil

function BossQuakeView.chargeCrack(data)
	if chargeGroup then
		releaseGroup(chargeGroup)
	end
	local m = marksOf(data.bossId)
	local C = Q.charge
	local a = Vector3.new(data.bossPosition.X, data.floorY + Q.crack.lift, data.bossPosition.Z)
	local b = Vector3.new(data.endPosition.X, data.floorY + Q.crack.lift, data.endPosition.Z)
	local d = b - a
	if d.Magnitude < 1 then
		return
	end
	local side = Vector3.new(-d.Z, 0, d.X).Unit
	local start, seconds = os.clock(), data.seconds
	local g = newGroup(nil)
	local fill = add(g, "block")
	style(fill, m.color, Enum.Material.SmoothPlastic)
	fill.Size = Vector3.new(data.halfWidth * 2, 0.08, d.Magnitude)
	fill.CFrame = CFrame.lookAt((a + b) / 2 - Vector3.new(0, 0.03, 0), b - Vector3.new(0, 0.03, 0))
	local lines = {}
	local n = math.max(2, math.ceil(d.Magnitude / C.step))
	for _, s in ipairs({ -1, 1 }) do
		local pts = jaggedPoints(a + side * s * data.halfWidth, b + side * s * data.halfWidth, n, C.jitter)
		for i = 1, #pts - 1 do
			local seg = add(g, "block")
			style(seg, m.crackColor or m.color)
			placeSegment(seg, pts[i], pts[i + 1], m.crackWidth, 0.1)
			table.insert(lines, seg)
		end
	end
	g.update = function(_, now)
		-- 전조 동안 진해진다(균열선 0.85 → crackTransparency · 채움 C.fill → marks.transparency 근처)
		local u = math.clamp((now - start) / math.max(seconds, 0.05), 0, 1)
		for _, seg in ipairs(lines) do
			seg.Transparency = 0.85 + (m.crackTransparency - 0.85) * u
		end
		fill.Transparency = C.fill + (math.min(m.transparency + Q.lightenFill, 0.95) - C.fill) * u
		if g.fadeAt then
			local f = math.clamp((now - g.fadeAt) / 0.3, 0, 1)
			for _, seg in ipairs(lines) do
				seg.Transparency = seg.Transparency + (1 - seg.Transparency) * f
			end
			fill.Transparency = fill.Transparency + (1 - fill.Transparency) * f
			return f >= 1
		end
		return false
	end
	chargeGroup = g
end

-- 돌진 출발(charge 사건): 달리는 동안 유지 → 도착하면 0.3초에 흐려진다
function BossQuakeView.chargeEnd(data)
	local g = chargeGroup
	chargeGroup = nil
	if g then
		task.delay(data.durationSeconds or 0, function()
			g.fadeAt = os.clock()
		end)
	end
end

-- ─────────────────────────── 도약 착지 균열 원 ───────────────────────────
local leapGroup = nil

local function ringPoints(center, radius, n, jitter)
	local pts = {}
	for i = 0, n - 1 do
		local a = i / n * 2 * math.pi
		local r = radius + rng:NextNumber(-jitter, jitter)
		pts[i + 1] = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
	end
	return pts
end

function BossQuakeView.leapTelegraph(data)
	if leapGroup then
		releaseGroup(leapGroup)
	end
	local m = marksOf(data.bossId)
	local L = Q.leap
	local g = newGroup(nil)
	local offsets = ringPoints(Vector3.zero, data.radius, L.segments, L.jitter)
	local segs = {}
	for i = 1, #offsets do
		local seg = add(g, "block")
		style(seg, m.crackColor or m.color)
		segs[i] = seg
	end
	local fill = add(g, "disc")
	style(fill, m.color, Enum.Material.SmoothPlastic)
	local start = os.clock()
	local lockAt = start + data.seconds - (data.lockSeconds or 0)
	g.center, g.target, g.radius = data.center, data.center, data.radius
	g.update = function(_, now)
		g.center = g.center:Lerp(g.target, math.clamp((now - (g.lastAt or now)) / 0.1, 0, 1))
		g.lastAt = now
		local base = Vector3.new(g.center.X, g.center.Y + Q.crack.lift, g.center.Z)
		local u = math.clamp((now - start) / math.max(data.seconds, 0.05), 0, 1)
		local locked = now >= lockAt
		local lineT = locked and (m.crackTransparency - L.lockFlash) or (0.8 + (m.crackTransparency - 0.8) * u)
		for i, seg in ipairs(segs) do
			placeSegment(seg, base + offsets[i], base + offsets[i % #offsets + 1], m.crackWidth * (locked and 1.6 or 1), 0.1)
			seg.Transparency = math.clamp(lineT, 0, 1)
		end
		fill.Size = Vector3.new(0.08, g.radius * 2, g.radius * 2)
		fill.CFrame = CFrame.new(base - Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, 0, math.rad(90))
		fill.Transparency = L.fill + (math.min(m.transparency + Q.lightenFill, 0.95) - L.fill) * u
		return g.ended == true
	end
	leapGroup = g
end

function BossQuakeView.leapAim(data)
	if leapGroup then
		leapGroup.target = data.center
	end
end

function BossQuakeView.leapImpact(data)
	if leapGroup then
		leapGroup.ended = true
		leapGroup = nil
	end
	local m = marksOf(data.bossId)
	local at = data.center + Vector3.new(0, 0.2, 0)
	BossFx.ring(at, data.radius * 0.3, data.radius, m.color, 0.35, 0.45)
	for i = 1, 10 do
		local a = i / 10 * 2 * math.pi + rng:NextNumber(-0.2, 0.2)
		BossFx.chunk(at, Vector3.new(math.cos(a) * 16, rng:NextNumber(14, 22), math.sin(a) * 16), rng:NextNumber(0.8, 1.6), Q.slab.color, 1.0)
	end
	BossFx.shake(at, 1.0)
end

-- ─────────────────────────── 지진파 ───────────────────────────
local quakeTelegraphGroup = nil

function BossQuakeView.quakeTelegraph(data)
	if quakeTelegraphGroup then
		releaseGroup(quakeTelegraphGroup)
	end
	local m = marksOf(data.bossId)
	local T = Q.telegraph
	local g = newGroup(nil)
	local unit = ringPoints(Vector3.zero, 1, T.segments, T.jitter / T.radius1)
	local segs = {}
	for i = 1, #unit do
		local seg = add(g, "block")
		style(seg, m.crackColor or m.color)
		segs[i] = seg
	end
	local start = os.clock()
	local base = Vector3.new(data.center.X, data.center.Y + Q.crack.lift, data.center.Z)
	g.update = function(_, now)
		local u = math.clamp((now - start) / math.max(data.seconds, 0.05), 0, 1)
		local r = T.radius0 + (T.radius1 - T.radius0) * u
		for i, seg in ipairs(segs) do
			placeSegment(seg, base + unit[i] * r, base + unit[i % #unit + 1] * r, m.crackWidth, 0.1)
			seg.Transparency = 0.85 + (m.crackTransparency - 0.85) * u
		end
		return now - start > data.seconds + 0.15
	end
	quakeTelegraphGroup = g
end

local rings = {} -- 살아 있는 파동 묶음(오래된 것부터)

function BossQuakeView.quakeWave(data)
	if quakeTelegraphGroup and (data.layer or 1) == 1 then
		releaseGroup(quakeTelegraphGroup)
		quakeTelegraphGroup = nil
	end
	-- 동시 링 상한(파트 ≤ 24 × maxRings): 넘으면 가장 오래된 링부터 거둔다
	while #rings >= Q.maxRings do
		releaseGroup(table.remove(rings, 1))
	end
	local m = marksOf(data.bossId)
	local g = newGroup(nil)
	table.insert(rings, g)
	local base = Vector3.new(data.center.X, data.center.Y, data.center.Z)
	local offset = rng:NextNumber(0, 2 * math.pi)
	local pieces = {}
	if data.air then
		for i = 1, Q.shards do
			local p = add(g, "block")
			style(p, Q.shard.color, Q.shard.material)
			p.Size = Q.shard.size
			pieces[i] = { part = p, a = offset + i / Q.shards * 2 * math.pi, phase = rng:NextNumber(0, 6.28), tilt = rng:NextNumber(-25, 25) }
		end
	else
		for i = 1, Q.slabs do
			local p = add(g, "block")
			style(p, Q.slab.color, Q.slab.material)
			pieces[i] = { part = p, a = offset + i / Q.slabs * 2 * math.pi, phase = rng:NextNumber(0, 6.28), h = rng:NextNumber(Q.slab.height[1], Q.slab.height[2]) }
		end
		for i = 1, Q.cracks do
			local p = add(g, "block")
			style(p, m.crackColor or m.color)
			table.insert(pieces, { part = p, a = offset + (i + 0.5) / Q.cracks * 2 * math.pi + rng:NextNumber(-0.15, 0.15), crack = true })
		end
	end
	g.update = function(_, now)
		local r = (Workspace:GetServerTimeNow() - data.serverStart) * data.speed
		if r <= 0 then
			return false
		end
		if r > data.maxRadius then
			for i, ring in ipairs(rings) do
				if ring == g then
					table.remove(rings, i)
					break
				end
			end
			return true
		end
		local front = math.max(r - data.thickness / 2, 0.5)
		local circumference = 2 * math.pi * front
		for _, piece in ipairs(pieces) do
			local dir = Vector3.new(math.cos(piece.a), 0, math.sin(piece.a))
			local p = piece.part
			if piece.crack then
				-- 바닥 균열: 가운데 → 파도 앞면까지 자란다
				placeSegment(p, base + dir * 2 + Vector3.new(0, Q.crack.lift, 0), base + dir * front + Vector3.new(0, Q.crack.lift, 0), Q.crack.width, 0.08)
				p.Transparency = m.crackTransparency
			elseif data.air then
				-- 공중 파동: 떠다니는 수정 조각(판정 높이 띠 가운데 · 흔들림 · 돌기)
				local y = Q.shard.height + math.sin(now * 3 + piece.phase) * Q.shard.bob
				p.CFrame = CFrame.new(base + dir * front + Vector3.new(0, y, 0)) * CFrame.Angles(0, now * Q.shard.spinHz * 2 * math.pi + piece.phase, math.rad(piece.tilt))
				p.Transparency = Q.shard.transparency
			else
				-- 땅 파동 앞면: 돌판이 솟았다 가라앉는다(앞으로 기울어 바깥을 본다)
				local width = math.max(circumference / Q.slabs * 0.82, 1.5)
				p.Size = Vector3.new(width, piece.h, Q.slab.depth)
				local bob = (0.5 + 0.5 * math.sin(now * Q.slab.bobHz * 2 * math.pi + piece.phase))
				local y = -piece.h / 2 + Q.slab.rise * (0.4 + 0.6 * bob) + piece.h * 0.35
				local at = base + dir * front + Vector3.new(0, y, 0)
				p.CFrame = CFrame.lookAt(at, at + dir) * CFrame.Angles(math.rad(-Q.slab.tiltDeg), 0, 0)
				p.Transparency = 0
			end
		end
		return false
	end
end

function BossQuakeView.reset()
	for _, g in ipairs(groups) do
		if not g.dead then
			releaseGroup(g)
		end
	end
	groups, rings = {}, {}
	chargeGroup, leapGroup, quakeTelegraphGroup = nil, nil, nil
end

-- 자동 검사 · 보고용: 살아 있는 묶음 · 사용 중 파트 · 쉬는 파트
function BossQuakeView.stats()
	local used, idle = 0, 0
	for _, g in ipairs(groups) do
		used += #g.parts
	end
	for _, pool in pairs(pools) do
		idle += #pool
	end
	return { groups = #groups, rings = #rings, used = used, idle = idle }
end

RunService.RenderStepped:Connect(function()
	if #groups == 0 then
		return
	end
	local now = os.clock()
	for i = #groups, 1, -1 do
		local g = groups[i]
		if g.dead then
			table.remove(groups, i)
		elseif g.update and g.update(g, now) then
			releaseGroup(g)
			table.remove(groups, i)
		end
	end
end)

return BossQuakeView
