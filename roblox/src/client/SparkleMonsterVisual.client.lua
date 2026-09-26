-- 반짝이 몬스터 이펙트 레이어(19-4 [6] → 22-2 [2]에서 재구성, PRD 8.0-5 "무지개빛 반짝임").
--
-- 핵심 요구(22-2 [2]): 나중에 최종 모델로 교체해도 반짝임이 살아 있어야 한다. 옛 방식
-- (서버가 Body 크기 ×1.3 + Body 안에 PointLight)은 모델에 얹힌 것이라 모델을 갈아끼우면
-- 같이 사라졌다. 이제 서버는 "SparkleMonster" 태그만 붙이고, 이 스크립트가 모델 **밖에**
-- (Workspace 직속, 클라이언트 전용) 자기 이펙트 파트를 하나 만들어 매 프레임 모델 피벗
-- (model:GetPivot())을 따라가게 한다. 모델의 어떤 속성·자식도 건드리지 않는다 - 모델이
-- 뭐든(기본 파트든 메시든) 태그와 피벗만 있으면 그대로 동작한다.
--
-- 클라이언트가 만드는 이유(19-4와 같다): 순수 시각 효과라 서버 권위가 필요 없고, 서버가
-- 색을 매 프레임 바꾸면 그 값이 모든 클라이언트로 매번 네트워크를 탄다. 반짝이는 드물어
-- (0.5%) 동시에 여러 마리를 돌려도 부담이 없다.
--
-- 구성(RareMonsterConfig 값): PointLight(주변 발광) + ParticleEmitter(반짝이 입자) + 하늘로
-- 뻗는 Beam 빛기둥(멀리서 "저기 있다" - 옆 구역에서도 지평선 위로 보인다). 색은 셋 다
-- 무지개 순환.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RareMonsterConfig = require(ReplicatedStorage.Shared.data.RareMonsterConfig)

local HUE_CYCLE_SECONDS = 2 -- 웹 drawMonster의 (gameTime*180)%360과 비슷한 체감 속도(2초에 한 바퀴)
local TAG = "SparkleMonster"

-- [Model] = { rig = Part, light = PointLight, beam = Beam, emitter = ParticleEmitter }
local effects = {}

local function buildEffect(model)
	local rig = Instance.new("Part")
	rig.Name = "SparkleEffectRig"
	rig.Size = Vector3.new(1, 1, 1)
	rig.Transparency = 1
	rig.Anchored = true
	rig.CanCollide = false
	rig.CanQuery = false
	rig.CanTouch = false
	rig.CFrame = model:GetPivot()

	local light = Instance.new("PointLight")
	light.Name = "SparkleGlow"
	light.Range = RareMonsterConfig.glowRangeStuds
	light.Brightness = RareMonsterConfig.glowBrightness
	light.Parent = rig

	local center = Instance.new("Attachment")
	center.Name = "Center"
	center.Parent = rig

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Sparkles"
	emitter.Rate = RareMonsterConfig.particleRate
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Speed = NumberRange.new(2, 4)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	emitter.LightEmission = 1
	emitter.Parent = center

	local top = Instance.new("Attachment")
	top.Name = "PillarTop"
	top.Position = Vector3.new(0, RareMonsterConfig.pillarHeightStuds, 0)
	top.Parent = rig

	local beam = Instance.new("Beam")
	beam.Name = "SparklePillar"
	beam.Attachment0 = center
	beam.Attachment1 = top
	beam.Width0 = RareMonsterConfig.pillarWidthStuds
	beam.Width1 = RareMonsterConfig.pillarWidthStuds * 0.3
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Parent = rig

	rig.Parent = Workspace
	return { rig = rig, light = light, beam = beam, emitter = emitter }
end

local function removeEffect(model)
	local effect = effects[model]
	if effect then
		effects[model] = nil
		effect.rig:Destroy()
	end
end

local function trackModel(model)
	if effects[model] then
		return
	end
	effects[model] = buildEffect(model)
	-- 모델이 사라지면(죽어서 Destroy) 이펙트도 같이 지운다. 서버가 태그를 떼는 경우도 대비.
	model.AncestryChanged:Connect(function(_, parent)
		if not parent then
			removeEffect(model)
		end
	end)
end

for _, model in ipairs(CollectionService:GetTagged(TAG)) do
	trackModel(model)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(trackModel)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(removeEffect)

RunService.RenderStepped:Connect(function()
	local hue = (os.clock() % HUE_CYCLE_SECONDS) / HUE_CYCLE_SECONDS
	local color = Color3.fromHSV(hue, 1, 1)
	for model, effect in pairs(effects) do
		if model.Parent then
			effect.rig.CFrame = model:GetPivot()
			effect.light.Color = color
			effect.beam.Color = ColorSequence.new(color)
			effect.emitter.Color = ColorSequence.new(color)
		else
			removeEffect(model)
		end
	end
end)

-- D1-2: 금화 분수(서버 SparkleCoinFountain - 반짝이 처치 지점). 파티클 없이 금색 원판 파트 count개를 위로 흩뿌리고 중력으로 떨어뜨린다(RareMonsterConfig.coinFountain - 한 번 최대 count개 · lifeSeconds 뒤 전부 삭제).
local Players = game:GetService("Players")
local COIN = RareMonsterConfig.coinFountain
local COIN_COLOR = Color3.fromRGB(255, 200, 40)

local function coinFountain(position)
	local camera = Workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local from = root and root.Position or eye
	if not from or (from - position).Magnitude > COIN.maxDistance then
		return
	end
	local coins = {}
	for i = 1, COIN.count do
		local coin = Instance.new("Part")
		coin.Name = "SparkleCoin"
		coin.Shape = Enum.PartType.Cylinder
		coin.Size = Vector3.new(COIN.size * 0.25, COIN.size, COIN.size)
		coin.Material = Enum.Material.Neon
		coin.Color = COIN_COLOR
		coin.Anchored, coin.CanCollide, coin.CanQuery, coin.CanTouch, coin.CastShadow = true, false, false, false, false
		local angle = (i / COIN.count) * math.pi * 2 + math.random() * 0.4
		local out = COIN.spread * (0.4 + math.random() * 0.6)
		coins[i] = { part = coin, velocity = Vector3.new(math.cos(angle) * out, COIN.upSpeed * (0.7 + math.random() * 0.3), math.sin(angle) * out), spin = math.random() * 10 }
		coin.CFrame = CFrame.new(position + Vector3.new(0, 1.5, 0))
		coin.Parent = Workspace
	end
	local startedAt = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		local age = os.clock() - startedAt
		if age >= COIN.lifeSeconds then
			connection:Disconnect()
			for _, c in ipairs(coins) do
				c.part:Destroy()
			end
			return
		end
		for _, c in ipairs(coins) do
			c.velocity -= Vector3.new(0, COIN.gravity * dt, 0)
			local pos = c.part.Position + c.velocity * dt
			c.part.CFrame = CFrame.new(pos) * CFrame.Angles(0, age * c.spin, math.pi / 2)
			c.part.Transparency = math.clamp((age / COIN.lifeSeconds - 0.6) / 0.4, 0, 1)
		end
	end)
end

ReplicatedStorage:WaitForChild("SparkleCoinFountain").OnClientEvent:Connect(coinFountain)

