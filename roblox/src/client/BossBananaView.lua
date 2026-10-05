-- GUARDIAN-V3 바나나 투사체 그림(판정 무관 - 자리 · 방향은 서버 projSpawn/projSync가 정하고 BossBR1View가 움직인다).
--   acquire() → 풀에서 바나나 한 개(메시 = 교체 슬롯 GuardianBanana → BossFrameworkData.meshSlots → 메시 캐시 · 캐시가 없으면 파트 바나나) · release(part) = 풀로(파괴 없음).
--   hold(data) = 던지기 예비(0.45초) 동안 보스 오른손에 바나나가 나타나 보라로 점점 빛난다(같은 풀 · 놓는 순간 돌려놓고 projSpawn이 비행 바나나를 꺼낸다).
--   V3.1: Meshy 오염 바나나(아틀라스 TextureID) · 길이 = 손 × 1.3 · 비행 = 텀블 회전 + 보라 Trail + 작은 보라 PointLight · 끝 = 보라 조각 파티클(burst - 풀 파트 1개).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BossFxData = require(ReplicatedStorage.Shared.data.BossFxData)
local BossFrameworkData = require(ReplicatedStorage.Shared.data.BossFrameworkData)
local ArtMeshKit = require(ReplicatedStorage.Shared.ArtMeshKit)

local B = BossFxData.guardianBanana
local BossBananaView = {}

local FAR = CFrame.new(0, -5000, 0)
local folder = nil
local pool = {}
local made = 0
local length = B.lengthStuds -- 마지막으로 잰 손 × handScale
local holdLight = nil -- 손에 든 바나나 발광(Highlight 1개를 돌려 씀)
local shardPart = nil

-- 메시 캐시의 첫 MeshPart(없으면 nil - 아트 스위치 끔 · 아직 못 불러옴)
local function meshTemplate()
	local key = BossFrameworkData.meshSlots.GuardianBanana
	local model = key and ArtMeshKit.get(key)
	if not model then
		return nil
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("MeshPart") then
			return d
		end
	end
	return nil
end

local function textureId()
	local key = BossFrameworkData.meshSlotTextures and BossFrameworkData.meshSlotTextures.GuardianBanana
	local e = key and require(ReplicatedStorage.Shared.data.ArtAssetIds)[key]
	return e and e.image and ("rbxassetid://" .. tostring(e.image)) or nil
end

-- 가장 긴 변 = length(메시 비율 유지)
local function fitLength(part)
	local s = part.Size
	local m = math.max(s.X, s.Y, s.Z)
	if math.abs(m - length) > 0.05 then
		part.Size = s * (length / m)
	end
end

local function build()
	local template = meshTemplate()
	local part
	if template then
		part = template:Clone()
		part:ClearAllChildren()
		local tex = textureId()
		if tex then
			part.TextureID = tex -- 구운 색(노랑 + 오염된 보라 꼭지)
			part.Color = Color3.new(1, 1, 1)
			part.Material = Enum.Material.SmoothPlastic
		else
			part.Color = B.color
			part.Material = Enum.Material.Neon
		end
	else
		-- 파트 바나나(캐시 없음): 노랑 원통 + 보라 빛
		part = Instance.new("Part")
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(B.lengthStuds, 1.1, 1.1)
		part.Color = B.color
		part.Material = Enum.Material.Neon
	end
	part.Name = "GuardianBanana"
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = B.glow, B.light.range, B.light.brightness
	light.Parent = part
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.4, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.4, 0)
	a1.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Lifetime = B.trail.lifetime
	trail.WidthScale = NumberSequence.new(B.trail.width0, B.trail.width1)
	trail.Color = ColorSequence.new(B.glow) -- V3.1: 보라 꼬리
	trail.Transparency = NumberSequence.new(B.trail.transparency0, 1)
	trail.LightEmission = 0.8
	trail.FaceCamera = true
	trail.Enabled = false
	trail.Parent = part
	part.CFrame = FAR
	part.Parent = folder
	made += 1
	return part
end

local function ensureFolder()
	if not (folder and folder.Parent) then
		folder = Instance.new("Folder")
		folder.Name = "BossBananaPool"
		folder.Parent = Workspace
		pool, made, holdLight, shardPart = {}, 0, nil, nil
	end
end

function BossBananaView.acquire()
	ensureFolder()
	local part = table.remove(pool)
	if not part then
		if made >= B.poolMax then
			return nil -- 풀 상한(파티 4 × 3갈래) - 넘으면 그 한 발은 안 그린다(판정은 서버)
		end
		part = build()
	end
	fitLength(part)
	part.Transparency = 0
	local light = part:FindFirstChildOfClass("PointLight")
	if light then
		light.Brightness, light.Range = B.light.brightness, B.light.range
	end
	local trail = part:FindFirstChildOfClass("Trail")
	if trail then
		trail:Clear()
		trail.Enabled = true
	end
	return part
end

function BossBananaView.release(part)
	if not part then
		return
	end
	local trail = part:FindFirstChildOfClass("Trail")
	if trail then
		trail.Enabled = false
	end
	part.CFrame = FAR
	table.insert(pool, part)
end

-- 날아가는 바나나 자세: 긴 축(메시 X)을 나는 방향으로 · 진행 방향 오른쪽 축으로 끝이 넘어가는 텀블(spinHz 바퀴/초)
function BossBananaView.pose(part, position, now, dir)
	local d = dir and Vector3.new(dir.X, 0, dir.Z) or Vector3.zero
	local base = d.Magnitude > 1e-3 and CFrame.lookAt(position, position + d) or CFrame.new(position)
	part.CFrame = base * CFrame.Angles(-now * B.spinHz * 2 * math.pi, 0, 0) * CFrame.Angles(0, math.rad(90), 0)
end

-- 맞거나 땅에 닿은 자리: 보라 조각 파티클(풀 파트 1개의 ParticleEmitter:Emit)
function BossBananaView.burst(position)
	ensureFolder()
	if not shardPart then
		shardPart = Instance.new("Part")
		shardPart.Name = "BananaShards"
		shardPart.Anchored, shardPart.CanCollide, shardPart.CanQuery, shardPart.CanTouch = true, false, false, false
		shardPart.Transparency, shardPart.Size = 1, Vector3.one
		local e = Instance.new("ParticleEmitter")
		local S = B.shards
		e.Enabled = false
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(B.glow)
		e.LightEmission = 0.6
		e.Speed = NumberRange.new(S.speed[1], S.speed[2])
		e.Lifetime = NumberRange.new(S.lifetime[1], S.lifetime[2])
		e.SpreadAngle = Vector2.new(180, 180)
		e.Acceleration = Vector3.new(0, -60, 0)
		e.Rotation, e.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-360, 360)
		e.Size = NumberSequence.new(S.size, 0)
		e.Parent = shardPart
		shardPart.Parent = folder
	end
	shardPart.CFrame = CFrame.new(position)
	shardPart:FindFirstChildOfClass("ParticleEmitter"):Emit(B.shards.count)
end

-- 던지기 예비(near = 보스 자리 - 가장 가까운 손 있는 보스): 보스 오른손(Hand_R)에 바나나가 나타나 보라로 0 → 1 빛난다(seconds 뒤 풀로 - 실제 투사체는 projSpawn이 새로 꺼낸다)
function BossBananaView.hold(near, seconds)
	local model, best = nil, math.huge
	for _, m in ipairs(game:GetService("CollectionService"):GetTagged("Monster")) do
		local root = m.PrimaryPart
		if root and m:FindFirstChild("Hand_R") and (root.Position - near).Magnitude < best then
			model, best = m, (root.Position - near).Magnitude
		end
	end
	local hand = model and model:FindFirstChild("Hand_R")
	if not (hand and hand:IsA("BasePart")) then
		return
	end
	local hs = hand.Size
	length = math.max(hs.X, hs.Y, hs.Z) * B.handScale -- V3.1: 손 길이 × 1.3(이후 비행 바나나도 이 길이)
	local part = BossBananaView.acquire()
	if not part then
		return
	end
	local trail = part:FindFirstChildOfClass("Trail")
	if trail then
		trail.Enabled = false
	end
	if not holdLight then
		holdLight = Instance.new("Highlight")
		holdLight.DepthMode = Enum.HighlightDepthMode.Occluded
		holdLight.Parent = folder
	end
	holdLight.FillColor, holdLight.OutlineColor = B.glow, B.glow
	holdLight.Adornee, holdLight.Enabled = part, true
	local light = part:FindFirstChildOfClass("PointLight")
	local H = B.hold
	local start = os.clock()
	local conn
	conn = game:GetService("RunService").RenderStepped:Connect(function()
		local u = (os.clock() - start) / math.max(seconds, 0.05)
		if u >= 1 or not hand.Parent then
			conn:Disconnect()
			if holdLight and holdLight.Adornee == part then
				holdLight.Enabled, holdLight.Adornee = false, nil
			end
			BossBananaView.release(part) -- 놓는 순간 분리(비행 바나나 = projSpawn)
			return
		end
		-- 쥔 끝(꼭지 쪽 = 메시 −X)이 손바닥에: 손 아래 · 바나나 가운데는 길이 0.35만큼 앞
		part.CFrame = hand.CFrame * CFrame.new(0, -hs.Y * 0.45, 0) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.new(length * 0.35, 0, 0)
		holdLight.FillTransparency = 1 - (1 - H.fillTransparency) * u
		holdLight.OutlineTransparency = 1 - (1 - H.outlineTransparency) * u
		if light then
			light.Brightness = B.light.brightness + (H.lightBrightness - B.light.brightness) * u
			light.Range = B.light.range + (H.lightRange - B.light.range) * u
		end
	end)
end

function BossBananaView.stats()
	return { made = made, idle = #pool, length = length }
end

return BossBananaView
