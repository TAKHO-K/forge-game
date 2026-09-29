-- A2-S 아트 샘플 클라 연출(스위치 Workspace.ArtStyleV1 뒤 · 판정 없음 · 값 = shared/data/ArtStyleV1Data).
--   ① 아트 몸체 몬스터(모델 Attribute ArtV1): 대기 숨쉬기 · 걷기 통통 · 쓰러짐(데굴 + 흐려짐) - 관절 Transform(PreSimulation · 전조 포즈 중에는 손대지 않음)
--   ② 강화대: 서버 도형(Base · AnvilTop)을 이 화면에서만 숨기고(LocalTransparencyModifier - 충돌 · 거리 판정 자리 그대로) 모루 · 화덕 · 굴뚝 · 표지판을 놓는다
--   ③ 강화 성공 / 대성공 연출(EnhanceResult를 같이 듣는다 - 결과 판정 · 문구는 강화 패널 그대로)
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local ArtStyleV1Data = require(ReplicatedStorage.Shared.data.ArtStyleV1Data)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local ArtV1Models = require(ReplicatedStorage.Shared.ArtV1Models)
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
	local hub = WorldConfig.huntingGround.center
	local face = Vector3.new(hub.X, ground.Y, hub.Z)
	forgeModel = ArtV1Models.forge()
	forgeModel:PivotTo((face - ground).Magnitude > 1 and CFrame.lookAt(ground, face) or CFrame.new(ground))
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

local function emit(pos, count, color, size, speed, spread, gravity)
	local holder = fxPart("ArtV1FxEmitter", Vector3.one * 0.1, color, CFrame.new(pos))
	holder.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0
	e.Lifetime = NumberRange.new(0.45, 0.8)
	e.Speed = NumberRange.new(speed * 0.6, speed)
	e.SpreadAngle = Vector2.new(spread, spread)
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = Vector3.new(0, -gravity, 0)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Parent = holder
	e:Emit(count)
	Debris:AddItem(holder, 1.2)
end

local function playEnhance(great)
	local pos = anvilTop()
	if not pos then
		return
	end
	local S = great and X.great or X.success
	-- 흰 번쩍 → 퍼지는 고리 → 불꽃(대성공: + 금 별 + 빛기둥 + 약한 흔들림)
	local flash = fxPart("ArtV1Flash", Vector3.one * 0.5, X.flashColor, CFrame.new(pos))
	flash.Transparency = 0.1
	TweenService:Create(flash, TweenInfo.new(S.flashSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * S.flashSize, Transparency = 1 }):Play()
	Debris:AddItem(flash, S.flashSeconds + 0.05)
	local disc = CFrame.new(pos - Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	local ring = fxPart("ArtV1Ring", Vector3.new(0.08, 1, 1), X.ringColor, disc, Enum.PartType.Cylinder)
	ring.Transparency = 0.2
	TweenService:Create(ring, TweenInfo.new(S.ringSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.08, S.ringSize, S.ringSize), Transparency = 1 }):Play()
	Debris:AddItem(ring, S.ringSeconds + 0.05)
	emit(pos, S.sparks, S.sparkColor, 0.35, great and 20 or 14, great and 70 or 55, 30)
	if great then
		emit(pos + Vector3.new(0, 0.5, 0), S.stars, S.starColor, 0.9, 6, 90, 4)
		local pl = S.pillar
		local pillar = fxPart("ArtV1Pillar", Vector3.new(0.5, pl.width, pl.width), pl.color, CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2), Enum.PartType.Cylinder)
		pillar.Transparency = 0.25
		TweenService:Create(pillar, TweenInfo.new(pl.seconds * 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(pl.height, pl.width, pl.width), CFrame = CFrame.new(pos + Vector3.new(0, pl.height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2) }):Play()
		TweenService:Create(pillar, TweenInfo.new(pl.seconds * 0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, pl.seconds * 0.35), { Transparency = 1, Size = Vector3.new(pl.height, pl.width * 0.2, pl.width * 0.2) }):Play()
		Debris:AddItem(pillar, pl.seconds + 0.05)
		if S.shake then
			CameraShake.trigger(S.shake.seconds, S.shake.studs)
		end
	end
end

task.spawn(function()
	local result = ReplicatedStorage:WaitForChild("EnhanceResult")
	result.OnClientEvent:Connect(function(payload)
		if isOn() and type(payload) == "table" and payload.result == "success" then
			playEnhance(type(payload.level) == "number" and payload.level % X.greatEvery == 0)
		end
	end)
end)

-- 스위치
local function applySwitch()
	setForge(isOn())
end
Workspace:GetAttributeChangedSignal(ArtStyleV1Data.attribute):Connect(applySwitch)
task.spawn(function()
	Workspace:WaitForChild("EnhanceStation", 30)
	applySwitch()
end)

-- 개발 확인용(Studio 전용 · 판정 없음): ReplicatedStorage Attribute ArtV1FxTest = "success" | "great"로 연출만 재생
if RunService:IsStudio() then
	ReplicatedStorage:GetAttributeChangedSignal("ArtV1FxTest"):Connect(function()
		local v = ReplicatedStorage:GetAttribute("ArtV1FxTest")
		if v == "success" or v == "great" then
			playEnhance(v == "great")
		end
	end)
end
