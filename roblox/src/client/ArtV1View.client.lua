-- A2-S 아트 샘플 클라 연출(스위치 Workspace.ArtStyleV1 뒤 · 판정 없음 · 값 = shared/data/ArtStyleV1Data).
--   ① 아트 몸체 몬스터(모델 Attribute ArtV1): 대기 숨쉬기 · 걷기 통통 · 쓰러짐(데굴 + 흐려짐) - 관절 Transform(PreSimulation · 전조 포즈 중에는 손대지 않음)
--   ② 강화대: 서버 도형(Base · AnvilTop)을 이 화면에서만 숨기고(LocalTransparencyModifier - 충돌 · 거리 판정 자리 그대로) 모루 · 화덕 · 굴뚝 · 표지판을 놓는다
--   ③ 강화 성공 / 대성공 / 실패 연출(EnhanceResult를 같이 듣는다 - 결과 판정 · 문구는 강화 패널 그대로)
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")

local ArtStyleV1Data = require(ReplicatedStorage.Shared.data.ArtStyleV1Data)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local ArtV1Models = require(ReplicatedStorage.Shared.ArtV1Models)
local ArtV1FxData = require(ReplicatedStorage.Shared.data.ArtV1FxData)
local ArtV1Fx = require(script.Parent.ArtV1Fx)
local CameraShake = require(script.Parent.CameraShake)

local M = ArtStyleV1Data.monsterMotion
local TAU = math.pi * 2

local function isOn()
	return Workspace:GetAttribute(ArtStyleV1Data.attribute) == true
end

-- ─────────────── ① 몬스터 움직임 ───────────────
local mobs = {} -- [Model] = { root, rootJoint, neck, lastPos, walk, phase, t0, windupEnd, dyingAt, parts }

local function track(model)
	if mobs[model] or not model:IsA("Model") or not model:GetAttribute("ArtV1") then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	local rootJoint = root and root:FindFirstChild("RootJoint")
	local body = model:FindFirstChild("Body")
	if not (rootJoint and body) then
		return
	end
	local st = { root = root, rootJoint = rootJoint, neck = body:FindFirstChild("Neck"), lastPos = root.Position, walk = 0, phase = 0, t0 = os.clock() + math.random() * 3, windupEnd = -math.huge }
	mobs[model] = st
	model:GetAttributeChangedSignal("MobWindup"):Connect(function()
		if model:GetAttribute("MobWindup") == nil then
			st.windupEnd = os.clock()
		end
	end)
	model:GetAttributeChangedSignal("DiedAt"):Connect(function()
		if model:GetAttribute("DiedAt") and not st.dyingAt then
			st.dyingAt = os.clock()
			st.parts = {}
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") and d ~= root and d.Name ~= "Hitbox" then
					table.insert(st.parts, d)
				end
			end
		end
	end)
end

for _, model in ipairs(CollectionService:GetTagged("Monster")) do
	track(model)
end
CollectionService:GetInstanceAddedSignal("Monster"):Connect(function(model)
	task.defer(track, model) -- Attribute ArtV1이 복제된 뒤
end)

RunService.PreSimulation:Connect(function(dt)
	local now = os.clock()
	local camera = Workspace.CurrentCamera
	for model, st in pairs(mobs) do
		if not model.Parent then
			mobs[model] = nil
			continue
		end
		local pos = st.root.Position
		if camera and (pos - camera.CFrame.Position).Magnitude > M.lodStuds then
			st.lastPos = pos
			continue
		end
		if st.dyingAt then
			local d = M.death
			local e = now - st.dyingAt
			local a = math.clamp(e / d.rollSeconds, 0, 1)
			a = 1 - (1 - a) * (1 - a)
			st.rootJoint.Transform = CFrame.new(0, -d.sinkStuds * a, 0) * CFrame.Angles(0, 0, math.rad(d.rollDeg * a))
			local fade = math.clamp((e - d.fadeFrom) / d.fadeSeconds, 0, 1)
			for _, p in ipairs(st.parts) do
				p.LocalTransparencyModifier = fade
			end
			continue
		end
		local flat = Vector3.new(pos.X - st.lastPos.X, 0, pos.Z - st.lastPos.Z)
		st.lastPos = pos
		local speed = dt > 0 and flat.Magnitude / dt or 0
		st.walk += ((speed >= M.walk.minSpeed and 1 or 0) - st.walk) * math.clamp(dt * 8, 0, 1)
		if model:GetAttribute("MobWindup") ~= nil or now - st.windupEnd < M.windupReleaseSeconds then
			continue -- 전조 포즈(MonsterRigAnimator)가 같은 관절을 쓰는 동안
		end
		st.phase += dt * M.walk.hopHz * math.pi
		local hop = math.abs(math.sin(st.phase)) * st.walk
		local breathe = math.sin((now - st.t0) * TAU * M.idle.hz) * (1 - st.walk)
		st.rootJoint.Transform = CFrame.new(0, hop * M.walk.hopStuds + breathe * M.idle.bobStuds, 0) * CFrame.Angles(math.rad(-M.walk.leanDeg * hop), 0, 0)
		if st.neck then
			st.neck.Transform = CFrame.new(0, -math.sin((now - st.t0) * TAU * M.idle.hz - 0.8) * M.idle.capLagStuds - hop * 0.12, 0)
		end
	end
end)

-- ─────────────── ② 강화대 ───────────────
local F = ArtStyleV1Data.forge
local forgeModel = nil
-- A2-N3 Open Cloud 강화대 메시(순서표 7): 같은 이름 코드 파트 자리에 겹치고 코드 파트는 투명(불빛 · 연기 · 불씨 = 코드 그대로). 캐시가 늦으면 준비 신호 때.
local ArtMeshKit = require(ReplicatedStorage.Shared.ArtMeshKit)
local ArtImportData = require(ReplicatedStorage.Shared.data.ArtImportData)
local function skinForge()
	if forgeModel and not forgeModel:GetAttribute("ArtMesh") then
		ArtMeshKit.skin(forgeModel, "props/forge", forgeModel:GetPivot(), Vector3.one * (ArtStyleV1Data.forge.scale or 1))
	end
end
task.spawn(function()
	local cache = ReplicatedStorage:WaitForChild(ArtImportData.cacheFolder, 120)
	if cache then
		cache:GetAttributeChangedSignal(ArtImportData.readyAttribute):Connect(skinForge)
	end
end)

local function setForge(on)
	local station = Workspace:FindFirstChild("EnhanceStation")
	if not station then
		return
	end
	for _, name in ipairs(F.hideParts) do
		local p = station:FindFirstChild(name)
		if p then
			p.LocalTransparencyModifier = on and 1 or 0
		end
	end
	if forgeModel then
		forgeModel:Destroy()
		forgeModel = nil
	end
	if not on then
		return
	end
	local base = station:FindFirstChild("Base")
	if not base then
		return
	end
	local ground = base.Position - Vector3.new(0, base.Size.Y / 2, 0)
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { station }
	params.FilterType = Enum.RaycastFilterType.Exclude
	local hit = Workspace:Raycast(base.Position + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0), params)
	if hit then
		ground = hit.Position -- 실제 바닥(허브 거리 바닥 y 1.35 - 서버 Base 밑면 y 0보다 높다)
	end
	local hub = WorldConfig.huntingGround.center
	local face = Vector3.new(hub.X, ground.Y, hub.Z)
	forgeModel = ArtV1Models.forge()
	forgeModel:PivotTo((face - ground).Magnitude > 1 and CFrame.lookAt(ground, face) or CFrame.new(ground))
	skinForge()
	if F.outlineTag then
		CollectionService:AddTag(forgeModel, "OutlineTarget")
	end
	forgeModel.Parent = Workspace
end

local function anvilTop()
	local top = forgeModel and forgeModel:FindFirstChild("AnvilTopShine")
	if top then
		return top.Position + Vector3.new(0, 0.3, 0)
	end
	local station = Workspace:FindFirstChild("EnhanceStation")
	local anvil = station and station:FindFirstChild("AnvilTop")
	return anvil and anvil.Position + Vector3.new(0, 0.6, 0) or nil
end

-- ─────────────── ③ 강화 성공 연출 ───────────────
local X = ArtStyleV1Data.enhanceFx

local slowK = 1 -- Studio 캡처용 슬로모션 배율(ReplicatedStorage Attribute ArtV1FxSlow - 실제 게임은 항상 1)

local function fxPart(name, size, color, cf, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape or Enum.PartType.Ball
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.Neon
	p.CFrame = cf
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Parent = Workspace
	return p
end

local function emit(pos, count, color, size, speed, spread, gravity, lifetime)
	local holder = fxPart("ArtV1FxEmitter", Vector3.one * 0.1, color, CFrame.new(pos))
	holder.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0
	lifetime = lifetime or X.particleLifetime
	e.Lifetime = NumberRange.new(lifetime[1], lifetime[2])
	e.Speed = NumberRange.new(speed * 0.6, speed)
	e.SpreadAngle = Vector2.new(spread, spread)
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = Vector3.new(0, -gravity, 0)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.TimeScale = 1 / slowK
	e.Parent = holder
	e:Emit(count)
	Debris:AddItem(holder, X.emitterSeconds * slowK)
end

local function playEnhance(great)
	local pos = anvilTop()
	if not pos then
		return
	end
	local S = great and X.great or X.success
	slowK = RunService:IsStudio() and tonumber(ReplicatedStorage:GetAttribute("ArtV1FxSlow")) or 1
	-- 흰 번쩍 → 퍼지는 고리 → 불꽃(대성공: + 금 별 + 빛기둥 + 약한 흔들림)
	local flash = fxPart("ArtV1Flash", Vector3.one * 0.5, X.flashColor, CFrame.new(pos))
	flash.Transparency = 0.1
	TweenService:Create(flash, TweenInfo.new(S.flashSeconds * slowK, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * S.flashSize, Transparency = 1 }):Play()
	Debris:AddItem(flash, S.flashSeconds * slowK + 0.05)
	local disc = CFrame.new(pos - Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	local ring = fxPart("ArtV1Ring", Vector3.new(0.08, 1, 1), X.ringColor, disc, Enum.PartType.Cylinder)
	ring.Transparency = 0.2
	TweenService:Create(ring, TweenInfo.new(S.ringSeconds * slowK, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.08, S.ringSize, S.ringSize), Transparency = 1 }):Play()
	Debris:AddItem(ring, S.ringSeconds * slowK + 0.05)
	emit(pos, S.sparks, S.sparkColor, S.sparkSize, S.sparkSpeed, S.sparkSpread, X.sparkGravity)
	if great then
		emit(pos + Vector3.new(0, 0.5, 0), S.stars, S.starColor, S.starSize, S.starSpeed, S.starSpread, S.starGravity)
		local b = S.burst
		emit(pos, b.count, b.color, b.size, b.speed, 180, 0, b.lifetime)
		-- 빛기둥 = Beam(아래 → 위로 갈수록 투명): 솟음(riseFraction) 뒤 전체가 흐려지며 가늘어진다
		local pl = S.pillar
		local host = fxPart("ArtV1Pillar", Vector3.one * 0.1, pl.color, CFrame.new(pos))
		host.Transparency = 1
		local a0 = Instance.new("Attachment")
		a0.Parent = host
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, 0.2, 0)
		a1.Parent = host
		local beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1 = a0, a1
		beam.FaceCamera = true
		beam.Segments = 1
		beam.LightEmission = 1
		beam.Color = ColorSequence.new(pl.color)
		beam.Width0, beam.Width1 = pl.width, pl.topWidth
		beam.Parent = host
		local tr = pl.transparency
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local e = (os.clock() - t0) / (pl.seconds * slowK)
			if e >= 1 or not host.Parent then
				conn:Disconnect()
				host:Destroy()
				return
			end
			local rise = math.clamp(e / pl.riseFraction, 0, 1)
			a1.Position = Vector3.new(0, 0.2 + (pl.height - 0.2) * (1 - (1 - rise) ^ 2), 0)
			local fade = math.clamp((e - pl.riseFraction) / (1 - pl.riseFraction), 0, 1) ^ 2
			beam.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, tr[1] + (1 - tr[1]) * fade),
				NumberSequenceKeypoint.new(0.5, tr[2] + (1 - tr[2]) * fade),
				NumberSequenceKeypoint.new(1, tr[3]),
			})
			beam.Width0, beam.Width1 = pl.width * (1 - 0.7 * fade), pl.topWidth * (1 - 0.7 * fade)
		end)
		-- 바닥 링: 강화대 발밑에서 넓게 퍼짐
		local fr = S.floorRing
		local floorY = forgeModel and forgeModel:GetPivot().Position.Y or pos.Y - 3
		local floorDisc = CFrame.new(pos.X, floorY + 0.08, pos.Z) * CFrame.Angles(0, 0, math.pi / 2)
		local floorRing = fxPart("ArtV1FloorRing", Vector3.new(fr.thick, 1, 1), fr.color, floorDisc, Enum.PartType.Cylinder)
		floorRing.Transparency = fr.startTransparency
		TweenService:Create(floorRing, TweenInfo.new(fr.seconds * slowK, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(fr.thick, fr.size, fr.size), Transparency = 1 }):Play()
		Debris:AddItem(floorRing, fr.seconds * slowK + 0.05)
		-- 짧은 화면 반짝임(설정 섬광 줄이기 = 건너뜀)
		if S.screenFlash and not Players.LocalPlayer:GetAttribute("ReduceFlashes") then
			local grade = Instance.new("ColorCorrectionEffect")
			grade.Name = "ArtV1ScreenFlash"
			grade.Brightness = S.screenFlash.brightness
			grade.Parent = Lighting
			local back = TweenService:Create(grade, TweenInfo.new(S.screenFlash.seconds * slowK, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 })
			back.Completed:Connect(function()
				grade:Destroy()
			end)
			back:Play()
		end
		if S.shake then
			CameraShake.trigger(S.shake.seconds, S.shake.studs, "climax") -- 강화 대성공 = 클라이맥스(3초 규칙 예외 · 연출 세기는 곱함)
		end
	end
end

-- A2-N2 2-2 강화 실패(아래로 = 실패): 유지 = 회색 연기 조금 · 하락 · 초기화 = 어두운 링 + 연기 + 떨어지는 쇳조각. 흰 번쩍 · 섬광 없음(성공과 헷갈리지 않게)
-- QUEUE-ALL2 P4 1순위 ⑥: 22강 이상 → 12강 초기화 = 하락과 다른 전용 순간(FxMomentData.enhanceReset): 무기 빛 공이 떨어지며 꺼짐 · 금빛 파편 · 쇳조각 2배 · 어두운 링 1.5배 ·
--   채도 빠짐 0.4초(밝기 변화 없음 = 번쩍임 아님) · 짧은 클라이맥스 흔들림(설정 "화면 흔들림" 끔 = 없음). 세기 × FxScale · 끔(0)이면 옛 하락 모습 그대로.
local FAIL_KIND = { maintain = "maintain", down1 = "down", down2 = "down", reset = "reset" }
local FxMomentData = require(ReplicatedStorage.Shared.data.FxMomentData)
local FxMoment = require(script.Parent.FxMoment)

local function playResetExtras(pos, R, k)
	local g = R.glow
	local ball = ArtV1Fx.part("ArtV1ResetGlow", Vector3.one * g.size, g.color, CFrame.new(pos + Vector3.new(0, 0.6, 0)))
	ball.Transparency = 0.15
	local sec = g.seconds * ArtV1Fx.slow()
	TweenService:Create(ball, TweenInfo.new(sec, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		CFrame = CFrame.new(pos - Vector3.new(0, g.dropStuds, 0)), Color = Color3.fromRGB(40, 36, 44), Transparency = 1, Size = Vector3.one * g.size * 0.5,
	}):Play()
	Debris:AddItem(ball, sec + 0.05)
	ArtV1Fx.burst(pos + Vector3.new(0, 0.4, 0), math.max(1, math.floor(R.shards * k)), { color = R.shardColor, size = R.shardSize, speed = R.shardSpeed, spread = 90, gravity = 40, lifetime = { 0.4, 0.8 }, lightEmission = 0.6 })
	-- 채도 빠짐(ColorCorrection Saturation만 - Brightness 0). ReduceFlashes = 절반
	local d = R.desaturate
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "FxMomentResetGrade"
	cc.Saturation = 0
	cc.Parent = Lighting
	local amount = d.saturation * k * (FxMoment.reduceFlashes() and 0.5 or 1)
	TweenService:Create(cc, TweenInfo.new(d.seconds * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Saturation = amount }):Play()
	task.delay(d.seconds * 0.4 + d.holdSeconds, function()
		local back = TweenService:Create(cc, TweenInfo.new(d.seconds * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Saturation = 0 })
		back.Completed:Connect(function()
			cc:Destroy()
		end)
		back:Play()
	end)
	if Players.LocalPlayer:GetAttribute("SettingScreenShake") ~= false then
		CameraShake.trigger(R.shake.seconds, R.shake.studs, "climax") -- × FxScale는 CameraShake.allow가 곱한다
	end
end

local function playFail(kind)
	local pos = anvilTop()
	if not pos then
		return
	end
	local F2 = ArtV1FxData.enhanceFail
	local k = kind == "reset" and FxMoment.scale() or 0
	local R = k > 0 and FxMomentData.enhanceReset or nil
	local s = F2[kind == "reset" and "down" or kind]
	ArtV1Fx.burst(pos, s.smoke, { color = F2.smokeColor, size = F2.smokeSize, sizeEnd = F2.smokeSize * 1.8, speed = F2.smokeSpeed, spread = 35, gravity = -1, lifetime = { F2.seconds * 0.7, F2.seconds * 1.4 },
		texture = F2.smokeTexture, lightEmission = 0, transparency = NumberSequence.new(0.35, 1), drag = 2 })
	if R then
		ArtV1Fx.burst(pos, math.max(s.pieces, math.floor(R.pieces * k)), { color = R.pieceColor, size = R.pieceSize, speed = R.pieceSpeed, spread = 80, gravity = 34, lifetime = { 0.5, F2.seconds * 1.2 }, lightEmission = 0 })
		ArtV1Fx.ring(pos - Vector3.new(0, 0.25, 0), s.ring * (1 + (R.ringScale - 1) * k), R.ringSeconds, F2.ringColor, 0.14, 0.2)
		playResetExtras(pos, R, k)
		return
	end
	if s.pieces > 0 then
		ArtV1Fx.burst(pos, s.pieces, { color = F2.pieceColor, size = F2.pieceSize, speed = F2.pieceSpeed, spread = 70, gravity = 30, lifetime = { 0.5, F2.seconds }, lightEmission = 0 })
	end
	if s.ring then
		ArtV1Fx.ring(pos - Vector3.new(0, 0.25, 0), s.ring, F2.seconds * 0.6, F2.ringColor, 0.1, 0.3)
	end
end

task.spawn(function()
	local result = ReplicatedStorage:WaitForChild("EnhanceResult")
	result.OnClientEvent:Connect(function(payload)
		if isOn() and type(payload) == "table" and payload.result == "success" then
			playEnhance(type(payload.level) == "number" and payload.level % X.greatEvery == 0)
		elseif isOn() and type(payload) == "table" and FAIL_KIND[payload.result] then
			playFail(FAIL_KIND[payload.result])
		end
		-- QUEUE-ALL2 P4 2순위: 방지권이 막음 = 모루 위 푸른 방패 링(유지 연기 위에 겹침) · 세기 × FxScale
		local k = FxMoment.scale()
		local pos = type(payload) == "table" and payload.blockedBy and k > 0 and anvilTop()
		if pos then
			local SH = FxMomentData.enhancePanel.shield
			ArtV1Fx.ring(pos, SH.size * (0.6 + 0.4 * k), SH.seconds, SH.color, SH.thick, 0.1)
			if not FxMoment.reduceFlashes() then
				ArtV1Fx.flash(pos + Vector3.new(0, 0.3, 0), SH.size * 0.35, SH.seconds * 0.6, SH.color)
			end
		end
	end)
end)

-- 스위치
local function applySwitch()
	setForge(isOn())
end
Workspace:GetAttributeChangedSignal(ArtStyleV1Data.attribute):Connect(applySwitch)
task.spawn(function()
	local station = Workspace:WaitForChild("EnhanceStation", 30)
	if not station then
		return
	end
	station:WaitForChild("Base", 30) -- 강화대 모델은 비원자 스트리밍 - 모델이 먼저 오고 파트가 늦게 올 수 있다
	applySwitch()
	station.ChildAdded:Connect(function(child) -- 스트리밍으로 나갔다 다시 들어온 파트는 새 인스턴스라 숨김이 풀린다
		if child.Name == "Base" and isOn() and not forgeModel then
			setForge(true)
		elseif isOn() and table.find(F.hideParts, child.Name) and child:IsA("BasePart") then
			child.LocalTransparencyModifier = 1
		end
	end)
end)

-- 개발 확인용(Studio 전용 · 판정 없음): ReplicatedStorage Attribute ArtV1FxTest = "success" | "great" | "maintain" | "down" | "reset"으로 연출만 재생
if RunService:IsStudio() then
	ReplicatedStorage:GetAttributeChangedSignal("ArtV1FxTest"):Connect(function()
		local v = ReplicatedStorage:GetAttribute("ArtV1FxTest")
		if v == "success" or v == "great" then
			playEnhance(v == "great")
		elseif v == "maintain" or v == "down" or v == "reset" then
			playFail(v)
		end
	end)
end
