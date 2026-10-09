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
local TelegraphStyle = require(script.Parent.TelegraphStyle) -- A2-N2 2-4 전조 공통 테두리(ArtStyleV1 스위치 뒤)
local BossBananaView = require(script.Parent.BossBananaView) -- GUARDIAN-V3 바나나(풀 · 교체 슬롯)
local BossGroundMarks = require(script.Parent.BossGroundMarks) -- BOSS-NIGHT-2 2b 검기가 지나간 그을린 길(겉모습만)
local BossMeshShotView = require(script.Parent.BossMeshShotView) -- BOSS-NIGHT-1 메시 투사체(매머드 얼음 상아 - 풀 · 교체 슬롯)

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
	if color == DANGER then
		task.defer(TelegraphStyle.register, part)
	end
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

-- A2-N4 §2-4 휘두름 궤적: 판정 부채꼴(center · 가운데 각 angleDeg · 폭 widthDeg · 반경 inner ~ outer)과 같은 크기를 fromSide 쪽에서 반대쪽으로 쓸고 사라진다.
--   조각 = 반지름 방향 얇은 판(길이 outer − inner) - 각 조각의 바깥 끝이 정확히 outer(판정보다 크게 그리지 않는다).
local BossFxData = require(ReplicatedStorage.Shared.data.BossFxData)
function BossBR1View.swingTrail(center, angleDeg, widthDeg, inner, outer, color, transparency)
	local T = BossFxData.swingTrail
	inner = math.max(inner or 0, 0)
	if outer - inner < 0.2 then
		return
	end
	local n = math.clamp(math.ceil(math.abs(widthDeg) / T.stepDeg), 2, T.maxSlices) -- 음수 폭 = 반대 방향으로 쓸기(QUEUE-ALL1 평타 좌우)
	local from = angleDeg - widthDeg / 2
	local mid = (inner + outer) / 2
	for i = 0, n do
		task.delay(T.seconds * i / n, function()
			local a = math.rad(from + widthDeg * i / n)
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local at = center + dir * mid + Vector3.new(0, 0.35, 0)
			local blade = newPart(Vector3.new(T.width, 0.18, outer - inner), color or WHITE, transparency or T.transparency)
			blade.CFrame = CFrame.lookAt(at, at + dir)
			fadeOut(blade, T.fadeSeconds)
		end)
	end
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
	-- 리뷰 9: 반경을 BANDS개 띠로 나눠 띠마다 **그 띠의 바깥 호 길이**로 잡는다 - 한 조각으로 그리면 보스 곁에서 조각이 경계선 너머(안전한 쪽)로 넘쳤다.
	local BANDS = 3
	local band = (data.radius - inner) / BANDS
	for b = 1, BANDS do
		local r0, r1 = inner + band * (b - 1), inner + band * b
		local mid = (r0 + r1) / 2
		for i = 0, steps - 1 do
			local a = math.rad(data.angleDeg - width / 2 + width * (i + 0.5) / steps)
			local arc = 2 * math.pi * r1 * (width / 360) / steps * 1.05
			local part = newPart(Vector3.new(arc, 0.2, band), color, transparency)
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			part.CFrame = CFrame.lookAt(data.center + dir * mid + Vector3.new(0, 0.15, 0), data.center + dir * (mid + 1) + Vector3.new(0, 0.15, 0))
			table.insert(parts, part)
		end
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
	for _, part in ipairs(sectorParts(data, WHITE, 0.55)) do -- A2-N4: 부채꼴 번쩍임은 옅게 · 휘두름 궤적이 주인공
		fadeOut(part, 0.2)
	end
	BossBR1View.swingTrail(data.center, data.angleDeg, data.widthDeg, data.innerRadius, data.radius)
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
	-- BR1-2 반사된 투사체(보스 판정 - 흰 테두리의 붉은 빛 창): 멀리서도 보이게 길고 밝다
	reflected = { shape = "block", size = function(r) return Vector3.new(r * 0.8, r * 0.8, r * 3) end, material = Enum.Material.Neon, transparency = 0 },
	-- BOSS-NIGHT-2 폭풍 1폼 검기: 판정 상자는 안 보임 - 지면에 선 초승달 Neon 호(p.crescent)
	crescent = { shape = "block", size = function(r) return Vector3.new(r * 2, 0.6, 1) end, transparency = 1 },
}
local CRESCENT = { color = Color3.fromRGB(255, 225, 80), edge = Color3.fromRGB(90, 200, 255), segs = 9, spanDeg = 75, height = 1.8, thickness = 0.35 } -- Neon 색 = 가장 낮은 채널 ≤ 90

local function playerByUserId(userId)
	for _, p in ipairs(Players:GetPlayers()) do
		if p.UserId == userId then
			return p
		end
	end
	return nil
end

function BossBR1View.projTelegraph(data)
	if data.style == "banana" then -- GUARDIAN-V3: 바닥 · 머리 위 표시 없음 - 보스 손에 든 바나나가 빛난다(예비 동작)
		BossBananaView.hold(data.center, data.seconds)
		return
	end
	if BossMeshShotView.has(data.style) then -- BOSS-NIGHT-1: 머리 위 조준 고리 없음 - 보스 상아 끝에서 얼음이 자란다(예비 동작 · 상아 발광)
		BossMeshShotView.hold(data.center, data.seconds, data.style)
		return
	end
	if data.style == "crescent" then -- BOSS-NIGHT-2 검기: 바닥 띠 · 머리 위 구체 없음 - 신호 = 예비 0.5초 무기 번개 발광(v3 glow)
		return
	end
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
	if data.style == "banana" then
		local part = BossBananaView.acquire()
		if part then
			BossBananaView.pose(part, data.position, os.clock(), data.dir)
			projectiles[data.id] = { part = part, position = data.position, dir = data.dir, speed = data.speed, style = { banana = true }, heightMode = data.heightMode, radius = data.radius, scale = 1, traveled = 0, pooled = true }
		end
		return
	end
	if BossMeshShotView.has(data.style) then
		local part = BossMeshShotView.acquire(data.style)
		if part then
			BossMeshShotView.pose(data.style, part, data.position, os.clock(), data.dir)
			projectiles[data.id] = { part = part, position = data.position, dir = data.dir, speed = data.speed, style = { meshShot = data.style }, heightMode = data.heightMode, radius = data.radius, scale = 1, traveled = 0, pooled = true }
		end
		return
	end
	local style = STYLE[data.style] or STYLE.orb
	local shape = style.shape == "ball" and Enum.PartType.Ball or (style.shape == "cylinder" and Enum.PartType.Cylinder or Enum.PartType.Block)
	local part = newPart(style.size(data.radius), style.color or DANGER, style.transparency or 0.15, shape)
	if style.material then
		part.Material = style.material
	end
	part.CFrame = CFrame.lookAt(data.position, data.position + data.dir)
	projectiles[data.id] = { part = part, position = data.position, dir = data.dir, speed = data.speed, style = style, heightMode = data.heightMode, radius = data.radius, scale = 1, traveled = 0 }
	if data.style == "tornado" then
		-- BR1-4c c-2: 다가오는 게 보이게 - 판정 반경(radius) · 높이(groundHitHeightStuds 14) 안의 깔때기 5층 + 바닥 먼지 고리 + 진행 방향 바닥 띠 + 가까울수록 바람 줄기
		part.Transparency = 1
		local r = data.radius
		local t = { rings = {}, floorY = data.position.Y - r * 0.6 }
		for k = 1, 5 do
			local rk = r * (0.62 + 0.095 * k)
			local ring = newPart(Vector3.new(2.6, rk * 2, rk * 2), k % 2 == 0 and Color3.fromRGB(215, 225, 235) or Color3.fromRGB(170, 185, 200), 0.35 + 0.05 * k, Enum.PartType.Cylinder)
			ring.Material = Enum.Material.SmoothPlastic
			table.insert(t.rings, { part = ring, h = 1.3 + (k - 1) * 2.75, speed = 6 + k * 1.5, phase = k * 1.1 })
		end
		t.dust = newPart(Vector3.new(0.3, r * 2.6, r * 2.6), Color3.fromRGB(205, 190, 160), 0.55, Enum.PartType.Cylinder)
		t.band = newPart(Vector3.new(r * 2, 0.15, 26), DANGER, 0.72)
		t.nextStreak = 0
		projectiles[data.id].tornado = t
	end
	if data.style == "crescent" then
		local cr = { segs = {}, R = data.radius * 1.5, floorY = data.position.Y - data.radius * 0.6, nextSpark = 0 }
		for k = 1, CRESCENT.segs do
			local edge = k == 1 or k == CRESCENT.segs
			local seg = newPart(Vector3.new(cr.R * 2 * math.sin(math.rad(CRESCENT.spanDeg) / CRESCENT.segs) * 1.15, CRESCENT.height * (edge and 0.6 or 1), CRESCENT.thickness), edge and CRESCENT.edge or CRESCENT.color, 0.05)
			seg.Material = Enum.Material.Neon
			cr.segs[k] = seg
		end
		projectiles[data.id].crescent = cr
	end
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

-- 벽 튕김: 자리 · 방향을 서버 값으로 바로 맞추고 벽에 흰 충격 · 기억한 자리(가장 먼 사람)에 옅은 표적 원.
function BossBR1View.projBounce(data)
	local p = projectiles[data.id]
	if p then
		p.position, p.dir = data.position, data.dir
	end
	BossFx.ring(data.position, 1, 6, WHITE, 0.3)
	BossFx.shake(data.position, 0.3)
	if data.aim then
		local mark = disc(Vector3.new(data.aim.X, data.position.Y - (p and p.radius * 0.6 or 3), data.aim.Z), p and p.radius or 5, DANGER, 0.6)
		fadeOut(mark, 1.2)
	end
end

function BossBR1View.projEnd(data)
	local p = projectiles[data.id]
	projectiles[data.id] = nil
	if p and p.pooled and p.style.meshShot then -- BOSS-NIGHT-1: 풀로 + 조각
		BossMeshShotView.release(p.style.meshShot, p.part)
		BossMeshShotView.burst(p.style.meshShot, data.position)
		return
	end
	if p and p.pooled then
		BossBananaView.release(p.part) -- GUARDIAN-V3: 풀로(파괴 없음)
		BossFx.ring(data.position, 0.5, 4, Color3.fromRGB(200, 90, 255), 0.3)
		BossBananaView.burst(data.position) -- V3.1: 보라 조각 파티클
		return
	end
	if p then
		destroy(p.part)
		if p.tornado then
			for _, ring in ipairs(p.tornado.rings) do
				destroy(ring.part)
			end
			destroy(p.tornado.dust)
			destroy(p.tornado.band)
		end
		if p.crescent then
			for _, seg in ipairs(p.crescent.segs) do
				destroy(seg)
			end
		end
	end
	for i = 1, 6 do
		local a = i / 6 * 2 * math.pi
		BossFx.chunk(data.position, Vector3.new(math.cos(a) * 14, 10, math.sin(a) * 14), 0.6, WHITE, 0.4)
	end
	BossFx.ring(data.position, 1, 5, WHITE, 0.3)
end

-- ─────────────────────────── BR1-4c c-11 눈덩이 파묻힘 ───────────────────────────
-- 서버: 맞은 사람 = 잡힘("snowball") + BossSnowballId/Phase Attribute · 이 파일: 그 사람을 눈덩이 겉에 반쯤 파묻어(다리만 밖) 공과 같이 굴린다(그림만 - 판정 자리는 서버).
-- 내 캐릭터가 파묻히면 카메라는 회전 없이 공 중심만 부드럽게 따라간다(대상 = 숨은 기준점) + 화면 가장자리 옅은 서리 테두리.
local riding = {} -- [Player] = true
local camAnchor, frost = nil, nil

function BossBR1View.projRiders(data)
	local p = projectiles[data.id]
	if p then
		p.scale = data.scale or 1
		p.part.Size = p.style.size(p.radius) * p.scale -- 그림만 커진다(판정 반경은 서버 radiusStuds 그대로)
	end
end

local function frostEdges(on)
	if on and not frost then
		frost = Instance.new("ScreenGui")
		frost.Name = "SnowballFrost"
		frost.IgnoreGuiInset = true
		frost.DisplayOrder = 5
		for _, e in ipairs({ { UDim2.new(1, 0, 0.16, 0), UDim2.fromScale(0, 0), 90 }, { UDim2.new(1, 0, 0.16, 0), UDim2.fromScale(0, 0.84), -90 },
			{ UDim2.new(0.1, 0, 1, 0), UDim2.fromScale(0, 0), 0 }, { UDim2.new(0.1, 0, 1, 0), UDim2.fromScale(0.9, 0), 180 } }) do
			local f = Instance.new("Frame")
			f.Size, f.Position = e[1], e[2]
			f.BackgroundColor3 = Color3.fromRGB(215, 238, 255)
			f.BorderSizePixel = 0
			local g = Instance.new("UIGradient")
			g.Rotation = e[3]
			g.Transparency = NumberSequence.new(0.35, 1) -- 가장자리 옅게 → 안쪽 투명
			g.Parent = f
			f.Parent = frost
		end
		frost.Parent = player:WaitForChild("PlayerGui")
	elseif not on and frost then
		frost:Destroy()
		frost = nil
	end
end

local function setCameraFollow(on, center)
	local camera = Workspace.CurrentCamera
	if on then
		if not camAnchor then
			camAnchor = Instance.new("Part")
			camAnchor.Name = "SnowballCamAnchor"
			camAnchor.Anchored, camAnchor.CanCollide, camAnchor.CanQuery, camAnchor.CanTouch = true, false, false, false
			camAnchor.Transparency = 1
			camAnchor.Size = Vector3.one * 0.2
			camAnchor.CFrame = CFrame.new(center)
			camAnchor.Parent = Workspace
			camera.CameraSubject = camAnchor
		end
	elseif camAnchor then
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		camera.CameraSubject = humanoid
		camAnchor:Destroy()
		camAnchor = nil
	end
end

local function updateRiders(dt)
	for _, other in ipairs(Players:GetPlayers()) do
		local id = other:GetAttribute("BossSnowballId")
		local p = id and projectiles[id]
		local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if p and root then
			riding[other] = true
			local r = p.radius * (p.scale or 1)
			local flat = Vector3.new(p.dir.X, 0, p.dir.Z)
			flat = flat.Magnitude > 1e-3 and flat.Unit or Vector3.new(0, 0, -1)
			local axis = Vector3.yAxis:Cross(flat) -- 윗점이 진행 방향으로 가는 구르기 축
			local roll = (p.traveled or 0) / math.max(r, 1) + (other:GetAttribute("BossSnowballPhase") or 0)
			local u = CFrame.fromAxisAngle(axis, roll):VectorToWorldSpace(Vector3.yAxis) -- 공 중심 → 그 사람 쪽
			local center = p.position
			local at = center + u * (r * 0.85) -- 몸통은 눈 속 · 다리(루트 아래 = 바깥)가 삐져나온다
			root.CFrame = CFrame.fromMatrix(at, axis, -u) -- 몸의 위 = 공 중심 쪽(머리가 눈 속)
			if other == player then
				setCameraFollow(true, center)
				camAnchor.CFrame = CFrame.new(camAnchor.Position:Lerp(center + Vector3.new(0, 2, 0), 1 - math.exp(-10 * dt))) -- 위치만 · 회전 없음
				frostEdges(true)
			end
		elseif riding[other] then
			riding[other] = nil
			if other == player then
				setCameraFollow(false)
				frostEdges(false)
			end
		end
	end
end

-- 튀어나온 뒤 기절(style "snow"): 머리 위 작은 눈송이 · 눈 털며 비틀(루트가 고정된 동안 좌우로 흔들림 + 눈가루) → 끝나면 W1 일어나기.
function BossBR1View.snowStun(data)
	local target = data.userId and Players:GetPlayerByUserId(data.userId)
	local character = target and target.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local head = character and character:FindFirstChild("Head")
	if not root then
		return
	end
	if head then
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.new(0, 70, 0, 26)
		gui.StudsOffset = Vector3.new(0, 2, 0)
		gui.AlwaysOnTop = true
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = "❄ ❄"
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(225, 245, 255)
		label.TextStrokeTransparency = 0.4
		label.Parent = gui
		gui.Adornee = head
		gui.Parent = head
		task.delay(data.seconds, function()
			gui:Destroy()
		end)
	end
	local base = root.CFrame
	local started = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if t >= data.seconds or not root.Parent or not root.Anchored then
			connection:Disconnect()
			if root.Parent then
				require(script.Parent.WeaponVisual).playGetup(target) -- W1 일어나기
			end
			return
		end
		local sway = math.sin(t * 9) * math.rad(9) * (1 - t / data.seconds * 0.5)
		root.CFrame = base * CFrame.Angles(0, 0, sway) -- 비틀(몸 털기)
		if math.random() < 0.18 then
			BossFx.chunk(root.Position + Vector3.new(0, 1.5, 0), Vector3.new((math.random() - 0.5) * 10, 6, (math.random() - 0.5) * 10), 0.35, WHITE, 0.4)
		end
	end)
	for i = 1, 8 do -- 튀어나오는 순간 눈 파편
		local a = i / 8 * 2 * math.pi
		BossFx.chunk(root.Position, Vector3.new(math.cos(a) * 12, 12, math.sin(a) * 12), 0.6, WHITE, 0.5)
	end
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

-- ─────────────────────────── BR1-2 투사체 반사 ───────────────────────────
-- 전조: 보스 둘레에 거울 판 6장이 땅에서 솟는다(보스 색 · 유리) → 반사: 판이 빛나며 돈다 + 원거리 멤버마다 "되돌아올 경로" 바닥 선(보스 → 그 사람, 매 프레임 따라간다 -
-- 되돌리는 순간 그 사람 자리로 곧게 가므로 이 선 = 실제 판정의 길) → 되돌림: 보스 곁에 빛이 모이고(windup) 그 선이 짙어진다.
local mirror = nil -- { panels, lines = { [userId] = Part }, center, spin }

local function clearMirror()
	if not mirror then
		return
	end
	for _, part in ipairs(mirror.panels) do
		destroy(part)
	end
	for _, line in pairs(mirror.lines) do
		destroy(line)
	end
	mirror = nil
end

function BossBR1View.reflectTelegraph(data)
	clearMirror()
	mirror = { panels = {}, lines = {}, center = data.center, radius = data.radius, spin = 0 }
	local color = data.color or DANGER
	for i = 1, 6 do
		local a = i / 6 * 2 * math.pi
		local at = data.center + Vector3.new(math.cos(a) * data.radius, -4, math.sin(a) * data.radius)
		local panel = newPart(Vector3.new(5, 7, 0.4), color, 0.35)
		panel.Material = Enum.Material.Glass
		panel.CFrame = CFrame.lookAt(at, Vector3.new(data.center.X, at.Y, data.center.Z))
		TweenService:Create(panel, TweenInfo.new(data.seconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = panel.CFrame + Vector3.new(0, 7.5, 0) }):Play()
		table.insert(mirror.panels, panel)
	end
	BossFx.ring(data.center, 1, data.radius + 2, WHITE, data.seconds)
end

function BossBR1View.reflectStance(data)
	if not mirror then
		BossBR1View.reflectTelegraph({ center = data.center, radius = data.radius, seconds = 0.01, color = data.color })
	end
	for _, panel in ipairs(mirror.panels) do
		panel.Material = Enum.Material.Neon
		panel.Transparency = 0.45
	end
	for _, userId in ipairs(data.rangedUserIds or {}) do
		local line = newPart(Vector3.new(3, 0.15, 1), DANGER, 0.55)
		mirror.lines[userId] = line
	end
end

function BossBR1View.reflectShot(data)
	local orb = newPart(Vector3.one * 1, data.color or DANGER, 0, Enum.PartType.Ball)
	orb.Material = Enum.Material.Neon
	orb.CFrame = CFrame.new(data.from)
	TweenService:Create(orb, TweenInfo.new(data.windup, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * 4 }):Play()
	task.delay(data.windup, function()
		destroy(orb)
	end)
	-- 되돌아가는 길(고정 - 이미 정해졌다): 짙은 빨강 띠
	local flat = Vector3.new(data.to.X - data.from.X, 0, data.to.Z - data.from.Z)
	local band = newPart(Vector3.new(5, 0.2, flat.Magnitude), DANGER, 0.25)
	band.CFrame = CFrame.lookAt(Vector3.new(data.from.X, (mirror and mirror.center.Y or data.from.Y - 3) + 0.2, data.from.Z) + flat / 2, Vector3.new(data.to.X, (mirror and mirror.center.Y or data.from.Y - 3) + 0.2, data.to.Z))
	task.delay(data.windup + flat.Magnitude / 30, function()
		fadeOut(band, 0.3)
	end)
	BossFx.ring(data.from, 1, 6, WHITE, 0.25)
end

function BossBR1View.reflectEnd()
	clearMirror()
end

RunService.RenderStepped:Connect(function(dt)
	if not mirror then
		return
	end
	mirror.spin += dt * 0.6
	local c = mirror.center
	for i, panel in ipairs(mirror.panels) do
		local a = i / 6 * 2 * math.pi + mirror.spin
		local at = c + Vector3.new(math.cos(a) * mirror.radius, 3.5, math.sin(a) * mirror.radius)
		panel.CFrame = CFrame.lookAt(at, Vector3.new(c.X, at.Y, c.Z))
	end
	for userId, line in pairs(mirror.lines) do
		local target = nil
		for _, p in ipairs(Players:GetPlayers()) do
			if p.UserId == userId then
				target = p
			end
		end
		local root = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local flat = Vector3.new(root.Position.X - c.X, 0, root.Position.Z - c.Z)
			local length = math.max(flat.Magnitude + 40, 1)
			local dir = flat.Magnitude > 1e-3 and flat.Unit or Vector3.new(1, 0, 0)
			line.Size = Vector3.new(5, 0.15, length)
			line.CFrame = CFrame.lookAt(c + Vector3.new(0, 0.15, 0) + dir * (length / 2), c + Vector3.new(0, 0.15, 0) + dir * length)
		end
	end
end)

-- ─────────────────────────── 매 프레임 · 리셋 ───────────────────────────
function BossBR1View.reset()
	clearMirror()
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
	updateRiders(dt)
	for _, p in pairs(projectiles) do
		p.position += p.dir * p.speed * dt
		p.traveled = (p.traveled or 0) + p.speed * dt
		if p.style.meshShot then
			BossMeshShotView.pose(p.style.meshShot, p.part, p.position, os.clock(), p.dir)
		elseif p.style.banana then
			BossBananaView.pose(p.part, p.position, os.clock(), p.dir)
		elseif p.part.Parent then
			local cf = CFrame.lookAt(p.position, p.position + p.dir)
			if p.style.spin then
				cf = CFrame.new(p.position) * CFrame.Angles(0, os.clock() * 8, math.rad(90))
			end
			p.part.CFrame = cf
		end
		local cr = p.crescent
		if cr then -- BOSS-NIGHT-2 검기: 진행 방향으로 볼록한 호(가운데가 앞) · 지면에 서서 날아감 · 가끔 번개 조각
			-- BOSS-NIGHT-2 2b Studio 실측: 전멸 리셋 때 끝 신호(projEnd)를 못 받은 초승달이 계속 날며 자국을 남겼다 → 최대 비행 거리 넘으면 숨기고 자국 끔
			if p.traveled > BossFxData.groundMarks.scorch.maxTravel then
				if not cr.expired then
					cr.expired = true
					for _, seg in ipairs(cr.segs) do
						seg.Transparency = 1
					end
				end
				continue
			end
			local flat = Vector3.new(p.dir.X, 0, p.dir.Z)
			flat = flat.Magnitude > 1e-3 and flat.Unit or Vector3.new(0, 0, -1)
			local right = flat:Cross(Vector3.yAxis)
			local base = Vector3.new(p.position.X, cr.floorY + CRESCENT.height * 0.5, p.position.Z)
			local n = #cr.segs
			for k = 1, n do
				local a = math.rad(CRESCENT.spanDeg) * ((k - 0.5) / n * 2 - 1)
				local at = base + flat * (cr.R * math.cos(a) - cr.R * 0.7) + right * (cr.R * math.sin(a))
				local tangent = right * math.cos(a) - flat * math.sin(a)
				cr.segs[k].CFrame = CFrame.fromMatrix(at, tangent, Vector3.yAxis)
			end
			cr.nextSpark -= dt
			if cr.nextSpark <= 0 then
				cr.nextSpark = 0.06
				local a = math.rad(CRESCENT.spanDeg) * (math.random() * 2 - 1)
				local at = base + flat * (cr.R * math.cos(a) - cr.R * 0.7) + right * (cr.R * math.sin(a))
				BossFx.streak(at, -flat + Vector3.new(0, 0.4, 0), 2.5, 0.2, CRESCENT.color, 0.2, 8)
			end
			-- BOSS-NIGHT-2 2b: 지나간 길에 그을린 띠(step stud마다 · 약 3초 뒤 사라짐 - BossGroundMarks 풀 · 상한)
			local step = BossFxData.groundMarks.scorch.step
			local floorAt = Vector3.new(p.position.X, cr.floorY, p.position.Z)
			cr.lastMark = cr.lastMark or floorAt
			local gap = floorAt - cr.lastMark
			if gap.Magnitude >= step then
				BossGroundMarks.scorch((floorAt + cr.lastMark) / 2, flat, cr.R * 2 * BossFxData.groundMarks.scorch.widthScale * 0.5, gap.Magnitude)
				cr.lastMark = floorAt
			end
		end
		local t = p.tornado
		if t then
			local now = os.clock()
			local base = Vector3.new(p.position.X, t.floorY, p.position.Z)
			for _, ring in ipairs(t.rings) do
				local wob = Vector3.new(math.sin(now * 2 + ring.phase) * 0.6, 0, math.cos(now * 1.7 + ring.phase) * 0.6)
				ring.part.CFrame = CFrame.new(base + wob + Vector3.new(0, ring.h, 0)) * CFrame.Angles(0, now * ring.speed, 0) * CFrame.Angles(0, 0, math.rad(90))
			end
			t.dust.CFrame = CFrame.new(base + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, now * 3, 0) * CFrame.Angles(0, 0, math.rad(90))
			local flat = Vector3.new(p.dir.X, 0, p.dir.Z)
			if flat.Magnitude > 1e-3 then
				local ahead = base + flat.Unit * (p.radius + 13) + Vector3.new(0, 0.12, 0)
				t.band.CFrame = CFrame.lookAt(ahead, ahead + flat.Unit)
			end
			-- 가까울수록 바람 줄기가 많아진다(60 stud 밖 0 → 곁 초당 14)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local d = root and (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(base.X, 0, base.Z)).Magnitude or math.huge
			local rate = math.clamp(1 - d / 60, 0, 1) * 14
			t.nextStreak -= dt * rate
			while t.nextStreak <= 0 and rate > 0 do
				t.nextStreak += 1
				local a = math.random() * 2 * math.pi
				local at = base + Vector3.new(math.cos(a) * p.radius * 1.4, 1 + math.random() * 10, math.sin(a) * p.radius * 1.4)
				BossFx.streak(at, Vector3.new(-math.sin(a), 0.25, math.cos(a)), 5, 0.25, WHITE, 0.35, 22)
			end
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
