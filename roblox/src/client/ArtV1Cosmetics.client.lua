-- A2-N2 2-3 이동 치장 4칸(대시 트레일 · 점프 이펙트 · 활강 궤적 · 발자국) 그리기(클라 · ArtStyleV1 스위치 뒤 · 외형만). 값 = shared/data/ArtV1CosmeticData.
--   장착 = Player Attribute Cosmetic_<칸> = 세트 id(서버 CosmeticService) → CosmeticSlotData.sets[세트].looks[칸] = 테마 키. 칸마다 다른 세트를 섞어 낄 수 있다.
--   남의 캐릭터도 그린다(입자 × otherPlayerScale · 카메라 거리 otherPlayerDistance 밖은 생략). 감지는 속도로(입력 신호가 남에게 없다): 대시 · 점프 · 활강(Character Attribute Gliding) · 걷기.
--   보스전(내 Player Attribute BossEncounterId) 중에는 치장 불투명도 ≤ 50%. 색 규칙 검사 = TrailSkin.check(부팅 때 Studio에서 경고).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local CosData = require(ReplicatedStorage.Shared.data.ArtV1CosmeticData)
local CosmeticSlotData = require(ReplicatedStorage.Shared.data.CosmeticSlotData)
local FxData = require(ReplicatedStorage.Shared.data.ArtV1FxData)
local TrailSkin = require(ReplicatedStorage.Shared.TrailSkin)
local Fx = require(script.Parent.ArtV1Fx)

local D = CosData.detect
local localPlayer = Players.LocalPlayer

if RunService:IsStudio() then
	for id, t in pairs(CosData.themes) do
		local ok, reasons = TrailSkin.check({ core = t.core, edge = t.edge, particle = t.particle })
		if not ok then
			warn(("[ArtV1Cosmetics] 테마 %s 색 규칙 X: %s"):format(id, table.concat(reasons, " · ")))
		end
	end
end

local setById = {}
for _, set in ipairs(CosmeticSlotData.sets) do
	setById[set.id] = set
end

local function themeOf(player, slot)
	local setId = player:GetAttribute("Cosmetic_" .. slot)
	local set = setId and setById[setId]
	local key = set and set.looks[slot]
	return key and CosData.themes[key] or nil
end

local function opacityScale()
	return localPlayer:GetAttribute("BossEncounterId") ~= nil and CosData.bossOpacity or 1
end

local function seq(a, b)
	local k = 1 - (1 - b) * opacityScale()
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, 1 - (1 - a) * opacityScale()), NumberSequenceKeypoint.new(1, math.max(k, b)) })
end

local function particleCount(n, isLocal)
	return isLocal and n or math.floor(n * FxData.budget.otherPlayerScale + 0.5)
end

-- 캐릭터마다: 대시 · 활강 Trail 2개(루트 위아래 부착점) · 상태
local chars = {} -- [character] = { player, root, hum, dash, glide, glideEmitter, lastVy, lastStep, dashUntil, isLocal }

local function makeTrail(root, name, spread)
	local a0 = Instance.new("Attachment")
	a0.Name = name .. "A0"
	a0.Position = Vector3.new(0, spread, 0)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Name = name .. "A1"
	a1.Position = Vector3.new(0, -spread, 0)
	a1.Parent = root
	local t = Instance.new("Trail")
	t.Name = name
	t.Attachment0, t.Attachment1 = a0, a1
	t.Enabled = false
	t.FaceCamera = true
	t.LightEmission = 1
	t.MinLength = 0.05
	t.Parent = root
	return t
end

local function styleTrail(trail, theme, spec)
	trail.Color = ColorSequence.new(theme.core, theme.edge)
	trail.Lifetime = spec.lifetime * Fx.slow()
	trail.WidthScale = NumberSequence.new(1, 0.15)
	trail.Transparency = seq(spec.transparency and spec.transparency[1] or 0.2, 1)
	local a0, a1 = trail.Attachment0, trail.Attachment1
	a0.Position, a1.Position = Vector3.new(0, spec.width / 2, 0), Vector3.new(0, -spec.width / 2, 0)
end

local function track(player, character)
	if chars[character] then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 10)
	local hum = character:WaitForChild("Humanoid", 10)
	if not (root and hum) then
		return
	end
	local st = { player = player, root = root, hum = hum, isLocal = player == localPlayer, lastVy = 0, lastStep = root.Position, dashUntil = 0 }
	st.dash = makeTrail(root, "ArtV1DashTrail", 0.8)
	st.glide = makeTrail(root, "ArtV1GlideTrail", 0.4)
	chars[character] = st
	character.Destroying:Connect(function()
		chars[character] = nil
	end)
end

local function hookPlayer(player)
	if player.Character then
		task.spawn(track, player, player.Character)
	end
	player.CharacterAdded:Connect(function(c)
		task.spawn(track, player, c)
	end)
end
for _, p in ipairs(Players:GetPlayers()) do
	hookPlayer(p)
end
Players.PlayerAdded:Connect(hookPlayer)

local function jumpFx(st, theme)
	local j = theme.jump
	local feet = Fx.feetOf(st.root.Parent)
	if not feet then
		return
	end
	local ring = Fx.ring(feet, j.ring, 0.35, theme.edge, 0.1, 1 - (1 - 0.2) * opacityScale())
	ring.Material = Enum.Material.Neon
	Fx.burst(feet + Vector3.new(0, 0.3, 0), particleCount(j.particles, st.isLocal), { color = theme.particle, size = j.size, speed = j.speed, spread = j.spread, gravity = j.gravity, lifetime = { 0.4, 0.8 } })
end

local function footprint(st, theme)
	local f = theme.footstep
	local feet = Fx.feetOf(st.root.Parent)
	if not feet then
		return
	end
	local cf = CFrame.new(feet - Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, math.atan2(-st.root.CFrame.LookVector.X, -st.root.CFrame.LookVector.Z), 0)
	local p
	if f.shape == "star" then -- 별 = 45° 겹친 납작한 네모 두 장
		p = Fx.part("ArtV1Step", Vector3.new(f.size * 0.7, 0.06, f.size * 0.7), theme.edge, cf * CFrame.Angles(0, math.rad(45), 0), Enum.PartType.Block, Enum.Material.Neon)
		local q = Fx.part("ArtV1Step", Vector3.new(f.size * 0.7, 0.07, f.size * 0.7), theme.core, cf, Enum.PartType.Block, Enum.Material.Neon)
		q.Transparency = 1 - 0.7 * opacityScale()
		TweenService:Create(q, TweenInfo.new(f.seconds), { Transparency = 1 }):Play()
		Debris:AddItem(q, f.seconds + 0.05)
	else
		p = Fx.part("ArtV1Step", Vector3.new(0.06, f.size, f.size), theme.edge, cf * CFrame.Angles(0, 0, math.pi / 2), Enum.PartType.Cylinder, f.neon and Enum.Material.Neon or Enum.Material.SmoothPlastic)
	end
	p.Transparency = 1 - 0.7 * opacityScale()
	TweenService:Create(p, TweenInfo.new(f.seconds), { Transparency = 1 }):Play()
	Debris:AddItem(p, f.seconds + 0.05)
end

RunService.Heartbeat:Connect(function()
	local on = Fx.isOn()
	local camera = Workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position
	local now = os.clock()
	for character, st in pairs(chars) do
		if not character.Parent or not st.root.Parent then
			chars[character] = nil
			continue
		end
		local near = st.isLocal or (eye and (st.root.Position - eye).Magnitude <= FxData.budget.otherPlayerDistance)
		local vel = st.root.AssemblyLinearVelocity
		local flat = Vector3.new(vel.X, 0, vel.Z).Magnitude
		local gliding = character:GetAttribute("Gliding") == true
		-- ① 대시 트레일
		local dashTheme = on and near and themeOf(st.player, "dashTrail")
		if dashTheme and flat >= D.dashSpeed and not gliding then
			if now >= st.dashUntil then
				styleTrail(st.dash, dashTheme, dashTheme.dash)
			end
			st.dashUntil = now + D.dashHoldSeconds * Fx.slow()
		end
		st.dash.Enabled = dashTheme ~= nil and dashTheme ~= false and now < st.dashUntil
		-- ② 점프 이펙트(위 속도가 갑자기 늘어남 = 지상 점프 · 공중 점프)
		local jumpTheme = on and near and themeOf(st.player, "jumpFx")
		if jumpTheme and vel.Y - st.lastVy >= D.jumpImpulse and vel.Y > 10 then
			jumpFx(st, jumpTheme)
		end
		st.lastVy = vel.Y
		-- ③ 활강 궤적
		local glideTheme = on and near and gliding and themeOf(st.player, "glideTrail")
		if glideTheme then
			if not st.glide.Enabled then
				styleTrail(st.glide, glideTheme, glideTheme.glide)
				local g = glideTheme.glide
				local n, release = Fx.hold(particleCount(g.particles, st.isLocal))
				st.glideRelease = release
				if n > 0 then
					local e = Instance.new("ParticleEmitter")
					e.Name = "ArtV1GlideSparkle"
					e.Rate = n / g.particleLife
					e.Lifetime = NumberRange.new(g.particleLife * 0.7, g.particleLife)
					e.Speed = NumberRange.new(0.5, 1.5)
					e.SpreadAngle = Vector2.new(180, 180)
					e.Acceleration = Vector3.new(0, -g.gravity, 0)
					e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, g.size), NumberSequenceKeypoint.new(1, 0) })
					e.Color = ColorSequence.new(glideTheme.particle)
					e.Transparency = seq(0, 1)
					e.LightEmission = 1
					e.Parent = st.glide.Attachment1
					st.glideEmitter = e
				end
			end
			st.glide.Enabled = true
		elseif st.glide.Enabled then
			st.glide.Enabled = false
			if st.glideEmitter then
				st.glideEmitter:Destroy()
				st.glideEmitter = nil
			end
			if st.glideRelease then
				st.glideRelease()
				st.glideRelease = nil
			end
		end
		-- ④ 발자국(땅에서 걸을 때 일정 거리마다 · 캐릭터당 동시 footstepMax 이하 = 수명 × 걸음 빈도로 자연히 제한)
		local stepTheme = on and near and not gliding and themeOf(st.player, "footstep")
		if stepTheme and st.hum.FloorMaterial ~= Enum.Material.Air and flat >= D.footstepMinSpeed and flat < D.dashSpeed then
			if (st.root.Position - st.lastStep).Magnitude >= D.footstepStuds then
				st.lastStep = st.root.Position
				footprint(st, stepTheme)
			end
		else
			st.lastStep = st.root.Position
		end
	end
end)

-- 개발 확인용(Studio 전용 · 판정 · 저장 무관): 내 Player Attribute를 로컬에서 바꿔 섞어 장착을 본다 - ReplicatedStorage Attribute ArtV1CosmeticTest = "dashTrail=ember,jumpFx=starlight,…"
if RunService:IsStudio() then
	ReplicatedStorage:GetAttributeChangedSignal("ArtV1CosmeticTest"):Connect(function()
		local v = tostring(ReplicatedStorage:GetAttribute("ArtV1CosmeticTest") or "")
		for pair in v:gmatch("[^,]+") do
			local slot, id = pair:match("^(%w+)=(%w*)$")
			if slot then
				localPlayer:SetAttribute("Cosmetic_" .. slot, id ~= "" and id or nil)
			end
		end
	end)
end
