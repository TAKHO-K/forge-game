-- W3c 스킬 · 공격 VFX(클라 전용 - 서버는 판정만). 수치 = shared/data/VfxData · A2 카툰 교체 = 이 모듈만.
--   대검 공중 내려찍기 착지 먼지 고리 · 궁수 비장의 한 발(빛 모임 · 공기 고리 · 관통 빛줄기 · 충격) · 치유사 딜링모드(검보라 소용돌이 · 어둠 구슬 꾸밈 · 터졌다 빨려 드는 적중).
--   조각은 전부 풀(재사용) · 파티클 = Emit 한 번(상시 방출은 구슬 하나당 1개).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local V = require(ReplicatedStorage.Shared.data.VfxData)
local CameraShake = require(script.Parent.CameraShake)

local SkillVfx = {}

local folder = Instance.new("Folder")
folder.Name = "SkillVfx"
folder.Parent = Workspace

local function basePart(name, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape or Enum.PartType.Block
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Transparency = 1
	p.Parent = folder
	return p
end

-- 조각 풀(순환)
local function pool(size, make)
	local list, i = {}, 0
	for k = 1, size do
		list[k] = make()
	end
	return function()
		i = i % size + 1
		return list[i]
	end
end

-- 한 번 터지는 파티클(부착점 하나 + 방출기 하나)
local function burstEmitter(parent)
	local att = Instance.new("Attachment")
	att.Parent = parent
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Rate = 0
	e.LightEmission = 0.6
	e.Parent = att
	return att, e
end

local emitterHost = basePart("SkillVfxEmitters")
emitterHost.Size = Vector3.new(0.2, 0.2, 0.2)
local nextBurst = pool(6, function()
	local att, e = burstEmitter(emitterHost)
	return { att = att, e = e }
end)

local function burst(position, color, count, speed, size, lifetime, direction, spread, lightEmission, accel)
	local b = nextBurst()
	b.att.WorldCFrame = direction and CFrame.lookAt(position, position + direction) or CFrame.new(position)
	local e = b.e
	e.Color = ColorSequence.new(color)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(lifetime * 0.7, lifetime)
	e.Speed = NumberRange.new(speed * 0.6, speed)
	e.SpreadAngle = spread or Vector2.new(180, 180)
	e.EmissionDirection = Enum.NormalId.Front
	e.LightEmission = lightEmission or 0.6
	e.Acceleration = accel or Vector3.zero
	e.Drag = 4
	e:Emit(count)
end

local function shake(def)
	CameraShake.trigger(def.seconds, def.studs)
end

-- ── 고리(납작한 원통 - 축 = 방향) ──
local nextRing = pool(8, function()
	return basePart("SkillVfxRing", Enum.PartType.Cylinder)
end)
local function ring(center, axis, def, delaySeconds)
	local p = nextRing()
	local cf = CFrame.lookAt(center, center + axis) * CFrame.Angles(0, math.rad(90), 0) -- 원통 축(X) = 방향
	task.delay(delaySeconds or 0, function()
		p.Color = def.color
		p.Size = Vector3.new(def.thickness, def.fromStuds, def.fromStuds)
		p.CFrame = cf
		p.Transparency = def.startTransparency
		TweenService:Create(p, TweenInfo.new(def.seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(def.thickness, def.toStuds, def.toStuds), Transparency = 1,
		}):Play()
	end)
end

-- ─────────── W3c-1 대검 공중 내려찍기: 착지 먼지 고리 ───────────
function SkillVfx.slamLanding(character, isMine)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	local D = V.greatswordAir.dustRing
	local foot = root.Position - Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2 - 0.1, 0)
	ring(foot, Vector3.yAxis, D)
	burst(foot, D.color, D.puffs, D.puffSpeed, D.puffSize, 0.5, Vector3.yAxis, Vector2.new(75, 75), 0, Vector3.new(0, -8, 0))
	if isMine then
		shake(V.greatswordAir.shake)
	end
end

-- ─────────── 모이는 빛 · 소용돌이(구 표면 → 중심으로 감기는 입자) ───────────
-- 방출기 모양(Sphere · Inward)은 파트에서만 먹는다 → 보이지 않는 공 파트를 대상(손 · 자리)에 매 프레임 붙인다.
local nextGather = pool(4, function()
	local host = basePart("SkillVfxGather", Enum.PartType.Ball)
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Rate = 0
	e.Shape = Enum.ParticleEmitterShape.Sphere
	e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	e.LightEmission = 1
	e.Parent = host
	local light = Instance.new("PointLight")
	light.Enabled = false
	light.Parent = host
	return { host = host, e = e, light = light }
end)
-- follow = 매 프레임 자리(파트 · 없으면 고정 자리) · radius = 모이는 구 반지름 · seconds 동안
local function gatherAt(follow, offset, radius, seconds)
	local g = nextGather()
	g.token = (g.token or 0) + 1
	local token = g.token
	g.host.Size = Vector3.one * radius * 2
	local function place()
		if typeof(follow) == "Instance" then
			g.host.CFrame = follow.CFrame * CFrame.new(offset or Vector3.zero)
		else
			g.host.CFrame = CFrame.new(follow)
		end
	end
	place()
	if typeof(follow) == "Instance" then
		local conn
		conn = RunService.RenderStepped:Connect(function()
			if g.token ~= token or not follow.Parent then
				conn:Disconnect()
				return
			end
			place()
		end)
		task.delay(seconds + 0.4, function()
			conn:Disconnect()
		end)
	end
	return g, token
end

-- ─────────── W3c-2 궁수 비장의 한 발 ───────────
-- 준비: 활 쥔 손(왼손)에 빛이 모인다(seconds = 발사까지 - 기존 발사 시각 안)
function SkillVfx.bowGather(character, seconds)
	local hand = character and (character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm"))
	if not hand then
		return
	end
	local G = V.bowFinisher.gather
	local g, token = gatherAt(hand, nil, 1.6, seconds)
	g.e.Color = ColorSequence.new(G.color)
	g.e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0.05) })
	g.e.Speed = NumberRange.new(5, 6)
	g.e.Lifetime = NumberRange.new(0.25, 0.3)
	g.e.RotSpeed = NumberRange.new(0, 0)
	g.e.LightEmission = 1
	g.e.Rate = G.count / math.max(seconds, 0.1)
	g.e.Enabled = true
	g.light.Color = G.color
	g.light.Range = G.lightRange
	g.light.Brightness = 0
	g.light.Enabled = true
	TweenService:Create(g.light, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Brightness = G.lightBrightness }):Play()
	task.delay(seconds, function()
		if g.token == token then
			g.e.Enabled = false
			g.light.Enabled = false
		end
	end)
end

-- 발사: 총구 앞으로 공기를 가르는 고리 + 작은 흔들림(내 화면)
function SkillVfx.bowRelease(muzzle, direction, isMine)
	local R = V.bowFinisher.airRing
	local dir = direction.Magnitude > 1e-3 and direction.Unit or Vector3.zAxis
	for i = 1, R.rings do
		ring(muzzle + dir * (R.gapStuds * i), dir, R, (i - 1) * 0.04)
	end
	if isMine then
		shake(V.bowFinisher.shake)
	end
end

-- 관통 빛줄기(경로에 남아 사라짐)
local nextStreak = pool(4, function()
	return basePart("SkillVfxStreak")
end)
function SkillVfx.bowStreak(from, to)
	local S = V.bowFinisher.streak
	local dir = to - from
	if dir.Magnitude < 1 then
		return
	end
	local finish = to + dir.Unit * S.beyondStuds
	local length = (finish - from).Magnitude
	local p = nextStreak()
	p.Color = S.color
	p.Size = Vector3.new(S.widthStuds, S.widthStuds, length)
	p.CFrame = CFrame.lookAt(from:Lerp(finish, 0.5), finish)
	p.Transparency = 0.2
	TweenService:Create(p, TweenInfo.new(S.seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Transparency = 1, Size = Vector3.new(S.widthStuds * 0.2, S.widthStuds * 0.2, length),
	}):Play()
end

-- 적중: 큰 충격(섬광 구 + 조각 - 쏜 방향으로 밀림 = 넉백 강조)
local nextFlash = pool(6, function()
	return basePart("SkillVfxFlash", Enum.PartType.Ball)
end)
local function flash(position, color, fromStuds, toStuds, seconds, startTransparency)
	local p = nextFlash()
	p.Color = color
	p.Size = Vector3.one * fromStuds
	p.CFrame = CFrame.new(position)
	p.Transparency = startTransparency or 0.1
	TweenService:Create(p, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * toStuds, Transparency = 1 }):Play()
	return p
end
function SkillVfx.bowImpact(position, direction, isMine)
	local I = V.bowFinisher.impact
	local dir = direction and direction.Magnitude > 1e-3 and direction.Unit or Vector3.zAxis
	flash(position, I.color, 0.5, I.flashStuds, I.flashSeconds)
	burst(position, I.color, I.count, I.speed, I.size, 0.35, dir, Vector2.new(40, 40), 1)
	ring(position + dir * I.pushStuds * 0.3, dir, { color = I.color, thickness = 0.15, fromStuds = 1, toStuds = I.flashStuds * 1.4, seconds = 0.2, startTransparency = 0.3 })
	if isMine then
		shake(V.bowFinisher.hitShake)
	end
end

-- ─────────── W3c-3 치유사 딜링모드 ───────────
local D = V.healerDark

-- E 켜는 순간: 두 손 끝에 검보라 소용돌이(안쪽으로 감김) + 빛
function SkillVfx.darkCast(character)
	local C = D.cast
	for _, handName in ipairs({ "RightHand", "LeftHand" }) do
		local hand = character and (character:FindFirstChild(handName) or character:FindFirstChild(handName == "RightHand" and "Right Arm" or "Left Arm"))
		if hand then
			local g, token = gatherAt(hand, Vector3.new(0, -0.6, 0), 1.8, C.seconds)
			g.e.Color = ColorSequence.new(C.color, C.dark)
			g.e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0.05) })
			g.e.Speed = NumberRange.new(4, 5)
			g.e.Lifetime = NumberRange.new(0.3, 0.4)
			g.e.RotSpeed = NumberRange.new(-360, 360)
			g.e.LightEmission = 0.3
			g.e.Rate = C.count / C.seconds / 2
			g.e.Enabled = true
			g.light.Color = C.color
			g.light.Range = C.lightRange
			g.light.Brightness = C.lightBrightness
			g.light.Enabled = true
			TweenService:Create(g.light, TweenInfo.new(C.seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Brightness = 0 }):Play()
			task.delay(C.seconds, function()
				if g.token == token then
					g.e.Enabled = false
					g.light.Enabled = false
				end
			end)
		end
	end
end

-- 딜링모드 켜짐 감시(모든 플레이어 - 남의 캐릭터도 보인다): 꺼짐 → 켜짐 순간만
function SkillVfx.watchDealingMode()
	local function bind(p)
		local was = p:GetAttribute("DealingModeActive") == true
		p:GetAttributeChangedSignal("DealingModeActive"):Connect(function()
			local on = p:GetAttribute("DealingModeActive") == true
			if on and not was then
				SkillVfx.darkCast(p.Character)
			end
			was = on
		end)
	end
	for _, p in ipairs(Players:GetPlayers()) do
		bind(p)
	end
	Players.PlayerAdded:Connect(bind)
end

-- 구슬 꾸밈(Projectiles 풀 구슬마다 한 번): 보라 테두리 껍질(용접 - 구슬과 같이 움직임) + 어둠 입자(안쪽으로 감김)
function SkillVfx.decorateOrb(slot)
	local shell = Instance.new("Part")
	shell.Name = "DarkRim"
	shell.Shape = Enum.PartType.Ball
	shell.Material = Enum.Material.Neon
	shell.Anchored = false
	shell.Massless = true
	shell.CanCollide = false
	shell.CanQuery = false
	shell.CanTouch = false
	shell.CastShadow = false
	shell.Transparency = 1
	shell.Size = Vector3.one * D.coreStuds * D.shellScale
	shell.CFrame = slot.part.CFrame
	shell.Parent = slot.part
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = slot.part, shell
	weld.Parent = shell
	local M = D.motes
	local motes = Instance.new("ParticleEmitter")
	motes.Enabled = false
	motes.Rate = M.rate
	motes.Color = ColorSequence.new(M.color)
	motes.Lifetime = NumberRange.new(M.lifetime)
	motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, M.size), NumberSequenceKeypoint.new(1, 0) })
	motes.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	motes.Shape = Enum.ParticleEmitterShape.Sphere
	motes.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	motes.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	motes.Speed = NumberRange.new(1.5, 2.5)
	motes.RotSpeed = NumberRange.new(-200, 200)
	motes.LightEmission = 0
	motes.Parent = shell
	slot.darkShell, slot.darkMotes = shell, motes
	slot.lightBase = slot.light and { brightness = slot.light.Brightness, range = slot.light.Range } or nil
end

-- 어둠 구슬 켜기/끄기(fire 때) - 끄면 옛 밝은 구슬(치유모드)로 돌아간다. 크기 · 꼬리 색은 on일 때만 덮는다.
function SkillVfx.styleOrb(slot, on, isCrit)
	local shell = slot.darkShell
	if not shell then
		return
	end
	if not on then
		shell.Transparency = 1
		slot.darkMotes.Enabled = false
		if slot.light and slot.lightBase then
			slot.light.Brightness, slot.light.Range = slot.lightBase.brightness, slot.lightBase.range
		end
		return
	end
	local part = slot.part
	part.Color = D.core
	part.Size = Vector3.one * D.coreStuds
	shell.Size = Vector3.one * D.coreStuds * D.shellScale
	shell.Color = isCrit and D.rimCrit or D.rim
	shell.Transparency = D.shellTransparency
	slot.darkMotes.Enabled = true
	if slot.particles then
		slot.particles.Enabled = false -- 밝은 구슬 파티클 대신 어둠 입자
	end
	if slot.light then
		slot.light.Color = D.rim
		slot.light.Brightness = D.light.brightness
		slot.light.Range = D.light.range
	end
	local T = D.trail
	local trail = slot.trail
	trail.Color = ColorSequence.new(T.color, T.edge)
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, T.startTransparency), NumberSequenceKeypoint.new(1, 1) })
	trail.LightEmission = 0
	trail.Lifetime = T.lifetime
	trail.Attachment0.Position = Vector3.new(0, T.width / 2, 0)
	trail.Attachment1.Position = Vector3.new(0, -T.width / 2, 0)
end

-- 도착: 껍질 숨김
function SkillVfx.orbArrived(slot)
	if slot.darkShell then
		slot.darkShell.Transparency = 1
		slot.darkMotes.Enabled = false
	end
end

-- 적중: 작게 터졌다(보라) → 검게 안으로 빨려 사라짐
function SkillVfx.darkImpact(position)
	local I = D.impact
	local p = flash(position, D.rim, D.coreStuds, I.burstStuds, I.burstSeconds, 0.2)
	TweenService:Create(p, TweenInfo.new(I.burstSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * I.burstStuds, Transparency = 0.35 }):Play()
	task.delay(I.burstSeconds, function()
		p.Color = D.core
		TweenService:Create(p, TweenInfo.new(I.implodeSeconds, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Size = Vector3.one * 0.05, Transparency = 0.6 }):Play()
		task.delay(I.implodeSeconds, function()
			p.Transparency = 1
		end)
	end)
	-- 안쪽으로 감기는 어둠 조각(구 표면 → 중심)
	local g = gatherAt(position, nil, I.burstStuds / 2, 0)
	g.e.Color = ColorSequence.new(D.rim, D.core)
	g.e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.02) })
	g.e.Speed = NumberRange.new(5, 7)
	g.e.Lifetime = NumberRange.new(0.18, 0.22)
	g.e.RotSpeed = NumberRange.new(-300, 300)
	g.e.LightEmission = 0.5
	g.e:Emit(I.count)
end

return SkillVfx
