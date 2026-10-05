-- BOSS-NIGHT-1 메시 투사체 그림(판정 무관 - 자리 · 방향은 서버 projSpawn/projSync · BossBR1View가 움직인다): 스타일별 설정 = BossFxData.meshShots[style].
--   메시 = 교체 슬롯(BossFrameworkData.meshSlots · meshSlotTextures) · 풀(생성/파괴 반복 없음) · 비행 자세 = 긴 축(메시 X)을 나는 방향으로 + spin(roll = 자기 축 회전 · tumble = 끝이 넘어감).
--   hold(near, seconds, style) = 전조 동안 보스의 holdParts(예: 상아) 끝에 메시가 0 → 1로 자란다(holdAt = 부위 국소 자리) · burst = 끝 조각 파티클.
--   지금 쓰는 곳: 매머드 얼음 상아 발사(icetusk). 바나나(수호자)는 BossBananaView 그대로.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local BossFxData = require(ReplicatedStorage.Shared.data.BossFxData)
local BossFrameworkData = require(ReplicatedStorage.Shared.data.BossFrameworkData)
local ArtMeshKit = require(ReplicatedStorage.Shared.ArtMeshKit)

local BossMeshShotView = {}
local FAR = CFrame.new(0, -5000, 0)
local folder = nil
local pools, made, shardParts = {}, {}, {}

function BossMeshShotView.has(style)
	return style ~= nil and BossFxData.meshShots ~= nil and BossFxData.meshShots[style] ~= nil
end

local function ensureFolder()
	if not (folder and folder.Parent) then
		folder = Instance.new("Folder")
		folder.Name = "BossMeshShotPool"
		folder.Parent = Workspace
		pools, made, shardParts = {}, {}, {}
	end
end

local function build(style)
	local cfg = BossFxData.meshShots[style]
	local key = BossFrameworkData.meshSlots[cfg.slot]
	local model = key and ArtMeshKit.get(key)
	local template
	for _, d in ipairs(model and model:GetDescendants() or {}) do
		if d:IsA("MeshPart") then
			template = d
			break
		end
	end
	local part
	if template then
		part = template:Clone()
		part:ClearAllChildren()
		local tk = BossFrameworkData.meshSlotTextures and BossFrameworkData.meshSlotTextures[cfg.slot]
		local e = tk and require(ReplicatedStorage.Shared.data.ArtAssetIds)[tk]
		if e and e.image then
			part.TextureID = "rbxassetid://" .. tostring(e.image)
			part.Color = Color3.new(1, 1, 1)
			part.Material = Enum.Material.SmoothPlastic
		else
			part.Color, part.Material = cfg.color, Enum.Material.Glass
		end
	else
		part = Instance.new("Part") -- 캐시 없음(아트 스위치 끔): 얼음 쐐기
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(cfg.lengthStuds, 1.2, 1.2)
		part.Color, part.Material = cfg.color, Enum.Material.Glass
	end
	local s = part.Size
	part.Size = s * (cfg.lengthStuds / math.max(s.X, s.Y, s.Z))
	part.Name = "MeshShot_" .. style
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = cfg.glow, cfg.light.range, cfg.light.brightness
	light.Parent = part
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, 0.4, 0), Vector3.new(0, -0.4, 0)
	a0.Parent, a1.Parent = part, part
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Lifetime = cfg.trail.lifetime
	trail.WidthScale = NumberSequence.new(cfg.trail.width0, 0)
	trail.Color = ColorSequence.new(cfg.glow)
	trail.Transparency = NumberSequence.new(cfg.trail.transparency0, 1)
	trail.LightEmission, trail.FaceCamera, trail.Enabled = 0.7, true, false
	trail.Parent = part
	part:SetAttribute("BaseSize", part.Size)
	part.CFrame = FAR
	part.Parent = folder
	made[style] = (made[style] or 0) + 1
	return part
end

function BossMeshShotView.acquire(style)
	ensureFolder()
	pools[style] = pools[style] or {}
	local part = table.remove(pools[style])
	if not part then
		if (made[style] or 0) >= BossFxData.meshShots[style].poolMax then
			return nil -- 풀 상한 - 그 한 발은 안 그린다(판정은 서버)
		end
		part = build(style)
	end
	part.Size = part:GetAttribute("BaseSize") or part.Size
	part.Transparency = 0
	local trail = part:FindFirstChildOfClass("Trail")
	if trail then
		trail:Clear()
		trail.Enabled = true
	end
	return part
end

function BossMeshShotView.release(style, part)
	if not part then
		return
	end
	local trail = part:FindFirstChildOfClass("Trail")
	if trail then
		trail.Enabled = false
	end
	part.CFrame = FAR
	pools[style] = pools[style] or {}
	table.insert(pools[style], part)
end

-- 비행 자세: 긴 축(X)을 나는 방향으로 · roll = 그 축으로 돈다(고드름) · tumble = 진행 방향 오른쪽 축으로 넘어간다
function BossMeshShotView.pose(style, part, position, now, dir)
	local cfg = BossFxData.meshShots[style]
	local d = dir or Vector3.new(0, 0, -1)
	local base = d.Magnitude > 1e-3 and CFrame.lookAt(position, position + d) or CFrame.new(position)
	local a = now * cfg.spinHz * 2 * math.pi
	if cfg.spin == "tumble" then
		part.CFrame = base * CFrame.Angles(-a, 0, 0) * CFrame.Angles(0, math.rad(90), 0)
	else
		part.CFrame = base * CFrame.Angles(0, 0, a) * CFrame.Angles(0, math.rad(90), 0)
	end
end

function BossMeshShotView.burst(style, position)
	ensureFolder()
	local cfg = BossFxData.meshShots[style]
	local p = shardParts[style]
	if not p then
		p = Instance.new("Part")
		p.Name = "MeshShotShards_" .. style
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Transparency, p.Size = true, false, false, false, 1, Vector3.one
		local e = Instance.new("ParticleEmitter")
		e.Enabled = false
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(cfg.glow)
		e.LightEmission = 0.5
		e.Speed = NumberRange.new(cfg.shards.speed[1], cfg.shards.speed[2])
		e.Lifetime = NumberRange.new(cfg.shards.lifetime[1], cfg.shards.lifetime[2])
		e.SpreadAngle = Vector2.new(180, 180)
		e.Acceleration = Vector3.new(0, -60, 0)
		e.Rotation, e.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-360, 360)
		e.Size = NumberSequence.new(cfg.shards.size, 0)
		e.Parent = p
		p.Parent = folder
		shardParts[style] = p
	end
	p.CFrame = CFrame.new(position)
	p:FindFirstChildOfClass("ParticleEmitter"):Emit(cfg.shards.count)
end

-- 전조: 가장 가까운 보스(holdParts가 있는)의 그 부위 끝에 메시가 자라남(0.15 → 1 배 · 빛 증가) → seconds 뒤 풀로(실제 투사체는 projSpawn이 꺼낸다)
function BossMeshShotView.hold(near, seconds, style)
	local cfg = BossFxData.meshShots[style]
	local model, best = nil, math.huge
	for _, m in ipairs(game:GetService("CollectionService"):GetTagged("Monster")) do
		local root = m.PrimaryPart
		if root and m:FindFirstChild(cfg.holdParts[1]) and (root.Position - near).Magnitude < best then
			model, best = m, (root.Position - near).Magnitude
		end
	end
	if not model then
		return
	end
	for _, name in ipairs(cfg.holdParts) do
		local host = model:FindFirstChild(name)
		local part = host and host:IsA("BasePart") and BossMeshShotView.acquire(style)
		if part then
			local trail = part:FindFirstChildOfClass("Trail")
			if trail then
				trail.Enabled = false
			end
			local base = part.Size
			local light = part:FindFirstChildOfClass("PointLight")
			local start = os.clock()
			local conn
			conn = RunService.RenderStepped:Connect(function()
				local u = (os.clock() - start) / math.max(seconds, 0.05)
				if u >= 1 or not host.Parent then
					conn:Disconnect()
					part.Size = base
					BossMeshShotView.release(style, part)
					return
				end
				local k = 0.15 + 0.85 * u
				part.Size = base * k
				-- 부위 끝(국소 −Y 끝 = 상아 끝)에서 같은 방향으로 자람
				local tip = host.CFrame * CFrame.new(0, -host.Size.Y * cfg.holdAt, 0)
				part.CFrame = tip * CFrame.Angles(0, 0, math.rad(-90)) * CFrame.new(base.X * k * 0.45, 0, 0)
				if light then
					light.Brightness = cfg.light.brightness * (0.5 + 2.5 * u)
				end
			end)
		end
	end
end

function BossMeshShotView.stats()
	local idle = 0
	for _, list in pairs(pools) do
		idle += #list
	end
	return { made = made, idle = idle }
end

return BossMeshShotView
