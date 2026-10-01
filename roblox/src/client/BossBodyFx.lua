-- A2-M1 보스 몸 효과(클라 전용 · 판정 무관 · client/BossAnimator가 부른다): 타격 충격(접촉 순간 = 판정 순간) · 등장(보스별 방식) · 무거운 발걸음 · 분노(체력 절반) · 사망(빛으로 흩어짐).
-- 조각은 전부 client/BossFx 풀(새 에셋 · ParticleEmitter 없음 · 동시 상한) · 색 = 보스 색(리그 테마) · 아레나 바닥색에서 파생(새 색 없음) · 흔들림 = BossFx.shake(설정 "화면 흔들림" 존중) ·
-- 섬광 = 설정 "번개 · 섬광 줄이기"(ReduceFlashes)면 밝기만. 데이터 = shared/data/BossMotionData(impacts · footsteps · bosses[].intro).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BossMotionData = require(ReplicatedStorage.Shared.data.BossMotionData)
local BossFx = require(script.Parent.BossFx)
local SoundSheet = require(script.Parent.SoundSheet)

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
	-- 옅게(투명 0.5 ~ 0.6) - 바닥 전조 · 다음 공격 표시를 가리지 않게(Play 4: 짙은 원판이 바닥을 덮었다)
	BossFx.ring(p, 0.6 * S, 3.2 * S, c.dust, 0.42, 0.5)
	BossFx.ring(p + Vector3.new(0, 0.05, 0), 0.3 * S, 1.8 * S, c.accent, 0.28, 0.6)
	-- A2-M1 2차: 보스 강조색 충격파 테두리 = 바깥으로 퍼지는 조각 12개(리뷰: 흰 충격판이 밝은 바닥에 묻히고 보스마다 같아 보임 · 원판이 아니라 테두리만 - 바닥 전조를 안 가린다)
	for i = 1, 12 do
		local a = i / 12 * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		BossFx.spawn({ shape = "block", position = p + dir * 1.2 * S + Vector3.new(0, 0.1, 0), velocity = dir * 7 * S, size0 = Vector3.new(0.5 * S, 0.15, 0.25 * S), size1 = Vector3.new(1.2 * S, 0.1, 0.1 * S),
			rotation = CFrame.lookAt(Vector3.zero, dir).Rotation, color = c.accent, transparency0 = 0.15, transparency1 = 1, life = 0.45, material = Enum.Material.Neon })
	end
	-- A2-M1 2차 리뷰 2: 접촉 순간 번쩍임(0.12초 · 반구 - 타격 프레임이 한눈에 읽히게)
	BossFx.spawn({ shape = "ball", position = p, size0 = Vector3.one * 1.2 * S, size1 = Vector3.one * 2.6 * S, color = c.accent:Lerp(WHITE, 0.6), transparency0 = 0.2, transparency1 = 1, life = 0.12, material = Enum.Material.Neon })
	for i = 1, 7 do
		local a = i / 7 * math.pi * 2 + rnd(-0.3, 0.3)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		BossFx.puff(p + dir * S * 0.6, rnd(0.55, 0.85) * S, c.dust, rnd(0.45, 0.65), dir * rnd(5, 9) * size + Vector3.new(0, rnd(1, 3), 0))
	end
	for _ = 1, 8 do
		local a = math.random() * math.pi * 2
		BossFx.chunk(p + Vector3.new(0, 0.3, 0), Vector3.new(math.cos(a) * rnd(6, 12), rnd(12, 20), math.sin(a) * rnd(6, 12)) * math.sqrt(size), rnd(0.35, 0.7) * S * 0.35, c.debris, rnd(0.8, 1.2)) -- 리뷰 2: 파편 크게 · 오래
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

-- 포효: 발밑 옅은 먼지 고리 두 겹 · 입 앞 음파 줄기 · 발밑 먼지(Play 4: 가슴 높이의 꽉 찬 원판은 화면 · 바닥 전조를 덮어 뺐다)
local function roar(e, at, size, shakeW)
	local c = colorsOf(e)
	local base = Vector3.new(e.visPos.X, floorY(e) + 0.15, e.visPos.Z)
	BossFx.ring(base, 1.5 * e.S, 5 * e.S * size, c.dust, 0.6, 0.55)
	task.delay(0.12, function()
		BossFx.ring(base, 1.2 * e.S, 3.6 * e.S * size, c.accent, 0.45, 0.65)
	end)
	local look = e.root and e.root.CFrame.LookVector or Vector3.new(0, 0, -1)
	local fwd = Vector3.new(math.sin(-e.visYaw), 0, -math.cos(e.visYaw))
	for i = 1, 6 do
		local spread = Vector3.new(0, 1, 0):Cross(fwd) * rnd(-0.6, 0.6) + Vector3.new(0, rnd(-0.2, 0.3), 0)
		BossFx.streak(at + fwd * 0.6 * e.S, fwd + spread, rnd(2, 3.2) * e.S * size * 0.5, 0.12 * e.S, c.accent:Lerp(WHITE, 0.5), 0.3, 12)
	end
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		BossFx.puff(base + Vector3.new(math.cos(a), 0, math.sin(a)) * e.S, rnd(0.6, 0.9) * e.S, c.dust, 0.55, Vector3.new(math.cos(a), 0.3, math.sin(a)) * 6)
	end
	if shakeW and shakeW > 0 then
		BossFx.shake(at, shakeW)
	end
	return look
end

local KINDS = { ground = ground, whoosh = whoosh, spark = spark, roar = roar }

-- QUEUE-ALL4 A4: 판정 원 안으로 줄인 땅 치기(slam · smash_in · punch_in)의 무게감 = 위로 튀는 파편 · 짧은 먼지 기둥 · 묵직한 소리 · 아주 짧은 흔들림.
--   가로로 거의 안 퍼진다(바깥으로 퍼지는 고리 없음 - 범위 착시 금지) · 개수 × 연출 세기(FxScale - 끔 0이면 없음) · 흔들림 = BossFx.shake(설정 · 3초 규칙 · 세기 따름).
local function heavyGround(e, at)
	local H = BossMotionData.heavyGround
	local fx = player:GetAttribute("FxScale")
	fx = type(fx) == "number" and fx or 1
	if fx <= 0 then
		return
	end
	local c = colorsOf(e)
	local p = Vector3.new(at.X, floorY(e) + 0.3, at.Z)
	for _ = 1, math.max(1, math.floor(H.debris * fx + 0.5)) do
		local a = math.random() * math.pi * 2
		local side = rnd(0, H.debrisSide)
		BossFx.chunk(p, Vector3.new(math.cos(a) * side, rnd(H.debrisUp[1], H.debrisUp[2]), math.sin(a) * side), rnd(H.debrisSize[1], H.debrisSize[2]) * e.S, c.debris, rnd(H.debrisLife[1], H.debrisLife[2]))
	end
	for i = 1, math.max(1, math.floor(H.column * fx + 0.5)) do
		local off = Vector3.new(rnd(-1, 1), 0, rnd(-1, 1)) * H.columnJitter * e.S
		BossFx.puff(p + off + Vector3.new(0, (i - 1) * H.columnStep * e.S, 0), rnd(H.columnSize[1], H.columnSize[2]) * e.S, c.dust, H.columnLife, Vector3.new(0, rnd(H.columnRise[1], H.columnRise[2]), 0))
	end
	SoundSheet.play(H.sound, { part = e.root, pitch = H.soundPitch, volume = H.soundVolume, minInterval = H.soundMinInterval })
	BossFx.shake(p, H.shakeWeight, H.shakeSeconds)
end

-- 동작 접촉 순간(BossAnimator가 시각에 맞춰 부른다)
function BossBodyFx.impact(e, clipName)
	local spec = BossMotionData.impacts[clipName or ""]
	if not spec then
		return
	end
	local f = KINDS[spec.kind]
	local sum, n = Vector3.zero, 0
	for _, name in ipairs(spec.parts) do
		local at = partPos(e, name)
		if at and f then
			sum, n = sum + at, n + 1
			f(e, at, spec.size or 1, not spec.heavy and spec.shake or nil) -- 무거운 땅 치기 = 흔들림은 아래 한 번(짧게)
			if spec.floorDust then -- A2-M1 2차: 휩쓴 자리 바닥에 먼지 호(리뷰: 꼬리 궤적이 몸에 가려 안 읽힘)
				local c = colorsOf(e)
				local center = e.visPos or e.root.Position
				local out = Vector3.new(at.X - center.X, 0, at.Z - center.Z)
				local r = math.max(out.Magnitude, e.S)
				local a0 = math.atan2(out.Z, out.X)
				for i = -3, 3 do -- 리뷰 2: 먼지 호가 잘 안 보임 → 7개 · 크게 · 보스 색 섞은 물보라
					local a = a0 + i * 0.2
					local p = Vector3.new(center.X + math.cos(a) * r, floorY(e) + 0.3, center.Z + math.sin(a) * r)
					BossFx.puff(p, rnd(0.8, 1.2) * e.S * (spec.size or 1), c.accent:Lerp(c.dust, 0.45), rnd(0.45, 0.65), Vector3.new(-math.sin(a), 0.4, math.cos(a)) * 6)
				end
			end
		end
	end
	if spec.heavy and n > 0 then
		heavyGround(e, sum / n)
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
	if first and not e.introShell and info.t < (info.riseT or 1) * 0.3 then
		-- 얼음 껍데기(이 클라 파트 - 몸을 감싼다 · 깨질 때 치운다 · 보스 모델 안 = 모델이 사라지면 같이 사라진다)
		local shell = Instance.new("Part")
		shell.Name = "IntroIceShell"
		shell.Anchored, shell.CanCollide, shell.CanQuery, shell.CanTouch, shell.CastShadow = true, false, false, false, false
		shell.Material = Enum.Material.Ice
		shell.Color = ice
		shell.Transparency = 0.25
		shell.Size = Vector3.new(3.2, 5.2, 2.6) * e.S
		shell.CFrame = CFrame.new(e.visPos + Vector3.new(0, 1.5 * e.S - 1.5 - 0.2 * e.S, 0)) * CFrame.Angles(0, math.rad(12), math.rad(4))
		shell.Parent = e.model
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
	-- 첫 효과는 등장 한 번에 한 번(전시 리그 멈춤 촬영은 등장 시각이 매 프레임 바뀐다 - 1.5초에 한 번으로 막는다)
	local first = e.introStyleSeen ~= e.introStamp and (not e.introFirstAt or os.clock() - e.introFirstAt > 1.5)
	e.introStyleSeen = e.introStamp
	if first then
		e.introFirstAt = os.clock()
	end
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

-- ─────────────────────────── 분노(체력 절반) ───────────────────────────
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
function BossBodyFx.enrage(e)
	local E = BossMotionData.enrage
	local c = colorsOf(e)
	local hot = c.accent:Lerp(UIColors.danger, E.tint)
	e.enragedColor = hot
	for _, d in ipairs(e.model:GetDescendants()) do
		if d:IsA("BasePart") and (d.Material == Enum.Material.Neon or d.Material == Enum.Material.Glass) and d.Name ~= "Eyes" then
			game:GetService("TweenService"):Create(d, TweenInfo.new(E.seconds), { Color = d.Color:Lerp(UIColors.danger, E.tint) }):Play()
		end
	end
	local eyes = e.model:FindFirstChild("Eyes")
	if eyes then
		game:GetService("TweenService"):Create(eyes, TweenInfo.new(E.seconds), { Color = eyes.Color:Lerp(UIColors.danger, E.eyeTint) }):Play()
		e.eyeColor = eyes.Color:Lerp(UIColors.danger, E.eyeTint) -- 노려봄(돌진 전조)이 되돌릴 기준 색
	end
	roar(e, partPos(e, "Head") or e.visPos, 1.2, 0.9)
	for _ = 1, 10 do
		local a = math.random() * math.pi * 2
		BossFx.spawn({ shape = "ball", position = e.visPos + Vector3.new(math.cos(a), rnd(0.5, 2.5), math.sin(a)) * e.S, velocity = Vector3.new(math.cos(a) * 6, rnd(6, 12), math.sin(a) * 6),
			size0 = Vector3.one * 0.3 * e.S * 0.5, size1 = Vector3.one * 0.05, color = hot, transparency0 = 0.1, transparency1 = 1, life = 0.7, material = Enum.Material.Neon })
	end
end

-- ─────────────────────────── 사망(비폭력: 어지러움 · X X 눈 · 주저앉음 · 빛으로 흩어짐 · 보상 빛 폭발) ───────────────────────────
-- e = 사망 복제 항목(client/BossAnimator startDeathClone) · info = BossMotion info(stars · scatter · fade)
function BossBodyFx.death(e, info)
	local c = colorsOf(e)
	-- X X 눈: 별이 돌기 시작할 때 눈 막대를 숨기고 머리 앞에 X 두 개(이 클라 파트 - 복제와 함께 사라진다)
	if info.stars and not e.xEyes then
		e.xEyes = true
		local head = e.model:FindFirstChild("Head")
		local eyes = e.model:FindFirstChild("Eyes")
		if head and eyes then
			eyes.LocalTransparencyModifier = 1
			local w = eyes.Size.X
			for _, side in ipairs({ -1, 1 }) do
				for _, rz in ipairs({ 45, -45 }) do
					local bar = Instance.new("Part")
					bar.Name = "DeathXEye"
					bar.Anchored, bar.CanCollide, bar.CanQuery, bar.CanTouch, bar.CastShadow = false, false, false, false, false
					bar.Massless = true
					bar.Material = Enum.Material.SmoothPlastic
					bar.Color = Color3.fromRGB(25, 18, 22)
					bar.Size = Vector3.new(w * 0.34, w * 0.07, 0.06)
					bar.CFrame = eyes.CFrame * CFrame.new(side * w * 0.26, 0, -0.03) * CFrame.Angles(0, 0, math.rad(rz))
					local weld = Instance.new("WeldConstraint")
					weld.Part0, weld.Part1 = head, bar
					weld.Parent = bar
					bar.Parent = e.model
					local bt = e.baseTransparency or (e.preview and e.preview.baseTransparency)
					if bt then
						bt[bar] = 0
					end
				end
			end
		end
	end
	-- 빛으로 흩어짐: 몸 여기저기서 빛 방울이 떠오른다(흩어지는 동안)
	local sc = info.scatter or 0
	if sc > 0 and sc < 1 and (not e.scatterTick or os.clock() - e.scatterTick > 0.05) then
		e.scatterTick = os.clock()
		local parts = e.scatterParts
		if not parts then
			parts = {}
			for _, d in ipairs(e.model:GetDescendants()) do
				if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Name ~= "Hitbox" and d.Size.Magnitude > 0.8 then
					table.insert(parts, d)
				end
			end
			e.scatterParts = parts
		end
		for _ = 1, 4 do
			local p = parts[math.random(1, math.max(#parts, 1))]
			if p then
				BossFx.spawn({ shape = "ball", position = p.Position + Vector3.new(rnd(-0.5, 0.5), rnd(-0.5, 0.5), rnd(-0.5, 0.5)) * p.Size.Magnitude * 0.4,
					velocity = Vector3.new(rnd(-2, 2), rnd(6, 12), rnd(-2, 2)), size0 = Vector3.one * rnd(0.25, 0.5) * e.S * 0.4, size1 = Vector3.one * 0.05,
					color = (math.random() < 0.3 and UIColors.gold or c.accent):Lerp(WHITE, 0.35), transparency0 = 0.05, transparency1 = 1, life = rnd(0.7, 1.1), material = Enum.Material.Neon })
			end
		end
	end
	-- 보상 빛 폭발: 흩어짐이 시작하는 순간 한 번(금 · 강조색 고리 + 사방으로 튀는 빛 - 드랍 연출 D1과 이어진다 · 줍기는 막지 않는다: 전부 충돌 · 조준 없음)
	if sc > 0 and not e.rewardBurst then
		e.rewardBurst = true
		local center = Vector3.new(e.visPos.X, floorY(e) + 0.3, e.visPos.Z)
		BossFx.ring(center, 1 * e.S, 6 * e.S, c.accent:Lerp(WHITE, 0.25), 0.7, 0.6) -- A2-M1 2차: 보스 강조색 · 옅게(리뷰: 모든 보스에 같은 짙은 황토 원판)
		BossFx.ring(center + Vector3.new(0, 0.05, 0), 0.5 * e.S, 2.5 * e.S, UIColors.gold, 0.5, 0.55)
		BossFx.ring(center + Vector3.new(0, 1.5 * e.S, 0), 0.5 * e.S, 4 * e.S, c.accent:Lerp(WHITE, 0.4), 0.55, 0.3)
		for i = 1, 12 do
			local a = i / 12 * math.pi * 2
			BossFx.spawn({ shape = "ball", position = center + Vector3.new(0, 1.2 * e.S, 0), velocity = Vector3.new(math.cos(a) * rnd(14, 22), rnd(10, 18), math.sin(a) * rnd(14, 22)),
				gravity = Workspace.Gravity * 0.35, size0 = Vector3.one * 0.6, size1 = Vector3.one * 0.15, color = i % 3 == 0 and c.accent or UIColors.gold,
				transparency0 = 0, transparency1 = 1, life = 1.0, material = Enum.Material.Neon })
		end
	end
end

-- 전시 리그(/gg boss anim)가 사망 동작을 되풀이할 때 다음 회차 전에 되돌린다
function BossBodyFx.resetDeath(e)
	e.xEyes, e.rewardBurst, e.scatterParts = nil, nil, nil
	for _, d in ipairs(e.model:GetChildren()) do
		if d.Name == "DeathXEye" then
			d:Destroy()
		end
	end
	local eyes = e.model:FindFirstChild("Eyes")
	if eyes then
		eyes.LocalTransparencyModifier = 0
	end
end

return BossBodyFx
