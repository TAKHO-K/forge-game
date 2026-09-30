-- A2-M1 보스 몸 효과(클라 전용 · 판정 무관 · client/BossAnimator가 부른다): 타격 충격(접촉 순간 = 판정 순간) · 등장(보스별 방식) · 무거운 발걸음 · 분노(체력 절반) · 사망(빛으로 흩어짐).
-- 조각은 전부 client/BossFx 풀(새 에셋 · ParticleEmitter 없음 · 동시 상한) · 색 = 보스 색(리그 테마) · 아레나 바닥색에서 파생(새 색 없음) · 흔들림 = BossFx.shake(설정 "화면 흔들림" 존중) ·
-- 섬광 = 설정 "번개 · 섬광 줄이기"(ReduceFlashes)면 밝기만. 데이터 = shared/data/BossMotionData(impacts · footsteps · bosses[].intro).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BossMotionData = require(ReplicatedStorage.Shared.data.BossMotionData)
local BossFx = require(script.Parent.BossFx)

local BossBodyFx = {}

local player = Players.LocalPlayer
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local function rnd(a, b)
	return a + (b - a) * math.random()
end

local function colorsOf(e)
	if e.fxColors then
		return e.fxColors
	end
	local body = e.model:FindFirstChild("Body")
	local head = e.model:FindFirstChild("Head")
	local accent = e.rig.themeColors and e.rig.themeColors.accent or e.rig.accent or (head and head.Color) or WHITE
	-- 바닥색: 발밑 아레나 바닥(없으면 몸색) - 흙먼지 = 바닥을 밝게
	local floorColor = body and body.Color or Color3.fromRGB(128, 128, 128)
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { e.model }
	local hit = Workspace:Raycast(e.root.Position + Vector3.new(0, 2, 0), Vector3.new(0, -30, 0), params)
	if hit and hit.Instance then
		floorColor = hit.Instance.Color
	end
	e.fxColors = { accent = accent, dust = floorColor:Lerp(WHITE, 0.35), debris = floorColor:Lerp(BLACK, 0.2), body = body and body.Color or floorColor }
	return e.fxColors
end

local function floorY(e)
	return (e.groundY or e.root.Position.Y) - 1.5
end

local function partPos(e, name)
	local p = e.model:FindFirstChild(name)
	return p and p:IsA("BasePart") and p.Position or nil
end

-- 땅 치기: 고리 · 방사 먼지 · 튀는 파편(크기 = S × size)
local function ground(e, at, size, shakeW)
	local c = colorsOf(e)
	local y = floorY(e)
	local p = Vector3.new(at.X, y + 0.15, at.Z)
	local S = e.S * size
	BossFx.ring(p, 0.6 * S, 3.2 * S, c.dust, 0.42, 0.25)
	BossFx.ring(p + Vector3.new(0, 0.05, 0), 0.3 * S, 1.8 * S, c.accent, 0.28, 0.35)
	for i = 1, 7 do
		local a = i / 7 * math.pi * 2 + rnd(-0.3, 0.3)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		BossFx.puff(p + dir * S * 0.6, rnd(0.55, 0.85) * S, c.dust, rnd(0.45, 0.65), dir * rnd(5, 9) * size + Vector3.new(0, rnd(1, 3), 0))
	end
	for _ = 1, 5 do
		local a = math.random() * math.pi * 2
		BossFx.chunk(p + Vector3.new(0, 0.3, 0), Vector3.new(math.cos(a) * rnd(6, 12), rnd(12, 20), math.sin(a) * rnd(6, 12)) * math.sqrt(size), rnd(0.25, 0.5) * S * 0.35, c.debris, rnd(0.6, 0.9))
	end
	if shakeW and shakeW > 0 then
		BossFx.shake(p, shakeW)
	end
end

-- 휘두름: 부위 둘레 접선 방향 바람 줄기
local function whoosh(e, at, size)
	local c = colorsOf(e)
	local center = e.visPos or e.root.Position
	local out = Vector3.new(at.X - center.X, 0, at.Z - center.Z)
	local tangent = out.Magnitude > 1e-3 and Vector3.new(0, 1, 0):Cross(out.Unit) or Vector3.new(1, 0, 0)
	for i = 1, 5 do
		local off = Vector3.new(rnd(-1, 1), rnd(-1, 1), rnd(-1, 1)) * e.S * 0.35
		BossFx.streak(at + off, tangent * (i % 2 == 0 and 1 or -1) + Vector3.new(0, rnd(-0.2, 0.2), 0), rnd(2.2, 3.4) * e.S * size * 0.5, 0.16 * e.S * size, c.accent:Lerp(WHITE, 0.5), 0.22, 10)
	end
end

-- 시전: 손의 빛 방울 · 작은 고리
local function spark(e, at, size)
	local c = colorsOf(e)
	for _ = 1, 5 do
		BossFx.spawn({ shape = "ball", position = at, velocity = Vector3.new(rnd(-6, 6), rnd(4, 10), rnd(-6, 6)) * size, size0 = Vector3.one * 0.5 * e.S * size * 0.4, size1 = Vector3.one * 0.05,
			color = c.accent, transparency0 = 0.1, transparency1 = 1, life = rnd(0.35, 0.55), material = Enum.Material.Neon })
	end
	BossFx.puff(at, 1.4 * e.S * size * 0.5, c.accent:Lerp(WHITE, 0.4), 0.3, Vector3.zero)
end

-- 포효: 가슴 높이 음파 고리 둘 · 발밑 먼지 고리
local function roar(e, at, size, shakeW)
	local c = colorsOf(e)
	local center = Vector3.new(e.visPos.X, at.Y - 0.8 * e.S, e.visPos.Z)
	BossFx.ring(center, 1.5 * e.S, 7 * e.S * size, c.accent:Lerp(WHITE, 0.3), 0.5, 0.45)
	task.delay(0.12, function()
		BossFx.ring(center, 1.2 * e.S, 5.5 * e.S * size, c.accent, 0.45, 0.55)
	end)
	BossFx.ring(Vector3.new(e.visPos.X, floorY(e) + 0.15, e.visPos.Z), 1.5 * e.S, 5 * e.S * size, c.dust, 0.6, 0.35)
	if shakeW and shakeW > 0 then
		BossFx.shake(center, shakeW)
	end
end

local KINDS = { ground = ground, whoosh = whoosh, spark = spark, roar = roar }

-- 동작 접촉 순간(BossAnimator가 시각에 맞춰 부른다)
function BossBodyFx.impact(e, clipName)
	local spec = BossMotionData.impacts[clipName or ""]
	if not spec then
		return
	end
	local f = KINDS[spec.kind]
	for _, name in ipairs(spec.parts) do
		local at = partPos(e, name)
		if at and f then
			f(e, at, spec.size or 1, spec.shake)
		end
	end
end

-- 무거운 발걸음(발이 땅을 디딘 순간)
function BossBodyFx.footstep(e, footName)
	local F = BossMotionData.footsteps
	local w = e.rig.weight or 1
	if w < F.dustWeight then
		return
	end
	local at = partPos(e, footName)
	if not at then
		return
	end
	local c = colorsOf(e)
	local p = Vector3.new(at.X, floorY(e) + 0.2, at.Z)
	for i = 1, 3 do
		local a = math.random() * math.pi * 2
		BossFx.puff(p, rnd(0.35, 0.55) * e.S, c.dust, 0.45, Vector3.new(math.cos(a), 0.4, math.sin(a)) * 3)
	end
	if w >= F.shakeWeight then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - p).Magnitude < F.nearStuds then
			BossFx.shake(p, F.shakeScale * w)
		end
	end
end

-- ─────────────────────────── 등장(보스별 방식) ───────────────────────────
local function flashOk()
	return player:GetAttribute("ReduceFlashes") ~= true
end

local INTRO = {}
function INTRO.rise(e, info, first)
	local c = colorsOf(e)
	local base = Vector3.new(e.visPos.X, floorY(e) + 0.15, e.visPos.Z)
	if first then
		BossFx.ring(base, 1 * e.S, 4.5 * e.S, c.debris, 0.9, 0.2) -- 갈라진 땅
	end
	if info.rise < 0.98 and (not e.introTick or os.clock() - e.introTick > 0.1) then
		e.introTick = os.clock()
		for _ = 1, 3 do
			local a = math.random() * math.pi * 2
			local r = rnd(0.6, 1.4) * e.S
			BossFx.chunk(base + Vector3.new(math.cos(a) * r, 0.3, math.sin(a) * r), Vector3.new(math.cos(a) * rnd(3, 7), rnd(10, 18), math.sin(a) * rnd(3, 7)), rnd(0.3, 0.6) * e.S * 0.4, c.debris, 0.8)
		end
		BossFx.puff(base + Vector3.new(rnd(-1, 1) * e.S, 0, rnd(-1, 1) * e.S), rnd(0.7, 1.1) * e.S, c.dust, 0.6, Vector3.new(0, 3, 0))
	end
end
function INTRO.emerge(e, info, first)
	local c = colorsOf(e)
	local water = c.accent:Lerp(Color3.fromRGB(60, 140, 200), 0.5)
	local base = Vector3.new(e.visPos.X, floorY(e) + 0.15, e.visPos.Z)
	if first then
		BossFx.ring(base, 1 * e.S, 5 * e.S, water, 1.2, 0.3)
	end
	if info.rise < 0.98 and (not e.introTick or os.clock() - e.introTick > 0.08) then
		e.introTick = os.clock()
		for _ = 1, 4 do
			local a = math.random() * math.pi * 2
			BossFx.spawn({ shape = "ball", position = base + Vector3.new(math.cos(a), 0.4, math.sin(a)) * e.S * rnd(0.5, 1.3), velocity = Vector3.new(math.cos(a) * 3, rnd(12, 20), math.sin(a) * 3),
				gravity = Workspace.Gravity * 0.4, size0 = Vector3.one * rnd(0.3, 0.5) * e.S * 0.4, size1 = Vector3.one * 0.1, color = water, transparency0 = 0.2, transparency1 = 0.9, life = 0.8, material = Enum.Material.Glass })
		end
	end
end
function INTRO.burrow(e, info, first)
	local c = colorsOf(e)
	local base = Vector3.new(e.visPos.X, floorY(e) + 0.15, e.visPos.Z)
	if first then
		for _ = 1, 14 do
			local a = math.random() * math.pi * 2
			BossFx.chunk(base, Vector3.new(math.cos(a) * rnd(8, 16), rnd(16, 28), math.sin(a) * rnd(8, 16)), rnd(0.3, 0.6) * e.S * 0.4, c.dust:Lerp(c.debris, 0.3), 1.0)
		end
		BossFx.ring(base, 1 * e.S, 6 * e.S, c.dust, 0.8, 0.2)
		BossFx.shake(base, 1.0)
	end
end
function INTRO.iceBreak(e, info, first)
	local c = colorsOf(e)
	local ice = c.accent:Lerp(WHITE, 0.4)
	if first then
		-- 얼음 껍데기(이 클라 파트 - 몸을 감싼다 · 깨질 때 치운다)
		local shell = Instance.new("Part")
		shell.Name = "IntroIceShell"
		shell.Anchored, shell.CanCollide, shell.CanQuery, shell.CanTouch, shell.CastShadow = true, false, false, false, false
		shell.Material = Enum.Material.Ice
		shell.Color = ice
		shell.Transparency = 0.25
		shell.Size = Vector3.new(3.2, 5.2, 2.6) * e.S
		shell.CFrame = CFrame.new(e.visPos + Vector3.new(0, 1.5 * e.S - 1.5 - 0.2 * e.S, 0)) * CFrame.Angles(0, math.rad(12), math.rad(4))
		shell.Parent = Workspace
		e.introShell = shell
	end
	if e.introShell and info.t >= (info.riseT or 1) * 0.35 then
		local center = e.introShell.Position
		e.introShell:Destroy()
		e.introShell = nil
		for _ = 1, 16 do
			local a = math.random() * math.pi * 2
			BossFx.spawn({ shape = "block", position = center + Vector3.new(rnd(-1, 1), rnd(-1.5, 1.5), rnd(-1, 1)) * e.S, velocity = Vector3.new(math.cos(a) * rnd(10, 18), rnd(8, 18), math.sin(a) * rnd(10, 18)),
				gravity = Workspace.Gravity * 0.5, size0 = Vector3.one * rnd(0.4, 0.8) * e.S * 0.4, size1 = Vector3.one * 0.2, rotation = CFrame.Angles(math.random() * 6, math.random() * 6, 0), spin = 8,
				color = ice, transparency0 = 0.2, transparency1 = 0.8, life = 1.0, material = Enum.Material.Ice })
		end
		BossFx.ring(Vector3.new(center.X, floorY(e) + 0.15, center.Z), 1 * e.S, 5 * e.S, ice, 0.6, 0.3)
		BossFx.shake(center, 1.1)
	end
end
function INTRO.assemble(e, info, first)
	local c = colorsOf(e)
	-- 몸이 결정 조각에서 나타난다(이 클라만 - 몸 투명 → 불투명) + 조각이 모여든다
	local k = math.clamp(info.rise, 0, 1)
	for _, d in ipairs(e.model:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Name ~= "Hitbox" then
			d.LocalTransparencyModifier = math.max(1 - k * 1.3, 0)
		end
	end
	if first then
		local center = e.visPos + Vector3.new(0, 2 * e.S, 0)
		for i = 1, 14 do
			local a = i / 14 * math.pi * 2
			local from = center + Vector3.new(math.cos(a) * 9 * e.S * 0.5, rnd(-1, 2) * e.S, math.sin(a) * 9 * e.S * 0.5)
			local life = (info.riseT or 1) * rnd(0.7, 1)
			BossFx.spawn({ shape = "block", position = from, velocity = (center - from) / life, size0 = Vector3.new(0.3, 0.9, 0.3) * e.S * 0.5, size1 = Vector3.new(0.1, 0.3, 0.1) * e.S * 0.5,
				rotation = CFrame.Angles(math.random() * 6, math.random() * 6, 0), spin = 4, color = c.accent, transparency0 = 0.1, transparency1 = 0.6, life = life, material = Enum.Material.Neon })
		end
	end
end
function INTRO.descend(e, info, first)
	local c = colorsOf(e)
	if info.rise >= 0.97 and not e.introLanded then
		e.introLanded = true
		local base = Vector3.new(e.visPos.X, floorY(e) + 0.15, e.visPos.Z)
		-- 번개 기둥(보스 자리에 하늘에서) · 섬광은 설정 존중(줄이기면 빛기둥만 옅게)
		BossFx.spawn({ shape = "block", position = base + Vector3.new(0, 60, 0), size0 = Vector3.new(0.9, 120, 0.9) * (e.S / 3), size1 = Vector3.new(0.2, 120, 0.2),
			color = c.accent:Lerp(WHITE, 0.5), transparency0 = flashOk() and 0 or 0.5, transparency1 = 1, life = 0.3, material = Enum.Material.Neon, essential = true })
		ground(e, base, 1.4, 1.3)
	end
end

-- 매 프레임(등장 중). info = BossMotion info.intro
function BossBodyFx.intro(e, info)
	if not info or info.style == "short" then
		return
	end
	local f = INTRO[info.style]
	local first = e.introStyleSeen ~= e.introStamp
	e.introStyleSeen = e.introStamp
	if f then
		f(e, info, first)
	end
	if info.rise >= 0.99 and e.introLandStamp ~= e.introStamp and info.style ~= "descend" then
		e.introLandStamp = e.introStamp
		ground(e, e.visPos, 1.0, 0.8)
	end
end

-- 등장 끝(보이는 몸 원래대로 · 남은 껍데기 치우기)
function BossBodyFx.introEnd(e)
	if e.introShell then
		e.introShell:Destroy()
		e.introShell = nil
	end
	for _, d in ipairs(e.model:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("DetailLod") ~= 2 then
			d.LocalTransparencyModifier = 0
		end
	end
	e.introLanded = nil
end

return BossBodyFx
