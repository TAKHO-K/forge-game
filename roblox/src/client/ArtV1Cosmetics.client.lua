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
	t.FaceCamera = false -- 2차 패스: 카메라를 보면 옆에서 바닥에 누운 판자처럼 보였다 → 세로 리본(부착점 = 루트 위아래)
	t.LightEmission = 1
	t.MinLength = 0.05
	t.Parent = root
	return t
end

local function styleTrail(trail, theme, spec)
	trail.Color = ColorSequence.new(theme.core, theme.edge)
	trail.LightEmission = CosData.trailEmission
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
	local st = { player = player, root = root, hum = hum, isLocal = player == localPlayer, lastVy = 0, lastStep = root.Position, lastPos = root.Position, dashUntil = 0 }
	st.dash = makeTrail(root, "ArtV1DashTrail", 0.8)
	st.glide = makeTrail(root, "ArtV1GlideTrail", 0.4)
	chars[character] = st
	character.Destroying:Connect(function()
		if st.glideRelease then -- QUEUE-ALL6 B6(D-2): Destroy로 지워지면 이 신호가 아래 Heartbeat 정리보다 먼저 와 빌린 입자 몫이 샜다
			st.glideRelease()
			st.glideRelease = nil
		end
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
	local ring = Fx.ring(feet, j.ring, 0.35, theme.edge, CosData.jumpRingThick, 1 - (1 - 0.1) * opacityScale())
	ring.Material = Enum.Material.Neon
	if j.squash and ring:IsA("BasePart") then -- QUEUE-ALL1 P6 젤리 "뽀잉": 고리가 납작하게 퍼졌다 사라진다
		-- Fx.ring의 퍼짐 트윈(Size · Transparency)을 같은 속성 트윈으로 대신한다(겹치면 앞 트윈이 취소된다) - 고리 두께(X)는 납작하게 · 지름은 widen배로 튕기듯
		local seconds = j.squash.seconds * Fx.slow()
		TweenService:Create(ring, TweenInfo.new(seconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = Vector3.new(ring.Size.X * 0.4, j.ring * j.squash.widen, j.ring * j.squash.widen), Transparency = 1 }):Play()
	end
	Fx.burst(feet + Vector3.new(0, 0.3, 0), particleCount(j.particles, st.isLocal), { color = theme.particle, size = j.size, speed = j.speed, spread = j.spread, gravity = j.gravity, lifetime = { 0.4, 0.8 } })
	if j.labelKey then -- QUEUE-ALL6 H 망치와 모루 "깡!" - 발밑에서 위로 떠오르며 사라짐(0.5초 · 남의 것은 작게)
		local gui = Instance.new("BillboardGui")
		gui.Name = "ArtV1JumpLabel"
		gui.Size = UDim2.fromOffset(st.isLocal and 80 or 52, st.isLocal and 36 or 24)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 0.6, 0)
		gui.LightInfluence = 0
		local holder = Instance.new("Part")
		holder.Name = "ArtV1JumpLabelAnchor"
		holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch = true, false, false, false
		holder.Transparency = 1
		holder.Size = Vector3.one * 0.1
		holder.CFrame = CFrame.new(feet)
		holder.Parent = Workspace
		gui.Adornee = holder
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = theme.core
		label.TextStrokeTransparency = 0.2
		label.Text = require(ReplicatedStorage.Shared.Text).get(j.labelKey)
		label.Parent = gui
		gui.Parent = holder
		TweenService:Create(holder, TweenInfo.new(0.5), { CFrame = CFrame.new(feet + Vector3.new(0, 2.4, 0)) }):Play()
		TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		Debris:AddItem(holder, 0.55)
	end
end

-- QUEUE-ALL6 H 할로윈 박쥐 한 마리(겉모습만): 날개 두 장(V) · 퍼덕이며 위로 날아 사라짐
--   QUEUE-ALL6R 결정 5: 주황 눈 둘(spec.eye) · spec.pumpkinEvery번째마다 박쥐 대신 작은 주황 호박 장식(theme.ornament)이 같은 길로 떠오른다(공중 요소만 주황).
local function bat(position, color, size, seconds, spec, theme, count)
	local ornament = spec and spec.pumpkinEvery and theme and theme.ornament and count % spec.pumpkinEvery == 0 and theme.ornament
	local parts, wings = {}, {}
	if ornament then
		local s = ornament.size
		table.insert(parts, Fx.part("ArtV1BatPumpkin", Vector3.new(s * 1.1, s * 0.85, s * 1.1), ornament.pumpkin, CFrame.new(position), Enum.PartType.Ball, Enum.Material.SmoothPlastic))
		table.insert(parts, Fx.part("ArtV1BatPumpkin", Vector3.new(s * 0.14, s * 0.35, s * 0.14), ornament.stem, CFrame.new(position + Vector3.new(0, s * 0.5, 0)), Enum.PartType.Block, Enum.Material.SmoothPlastic))
	else
		local body = Fx.part("ArtV1Bat", Vector3.new(size * 0.25, size * 0.25, size * 0.35), color, CFrame.new(position), Enum.PartType.Ball, Enum.Material.SmoothPlastic)
		table.insert(parts, body)
		for i, side in ipairs({ -1, 1 }) do
			local w = Fx.part("ArtV1BatWing", Vector3.new(size * 0.5, 0.05, size * 0.3), color, CFrame.new(position) * CFrame.new(side * size * 0.3, 0, 0) * CFrame.Angles(0, 0, side * 0.5), Enum.PartType.Block, Enum.Material.SmoothPlastic)
			wings[i] = w
			table.insert(parts, w)
			if spec and spec.eye then -- 눈 = 몸 앞쪽 위 작은 점 둘(Neon - 어두운 하늘에서도 보인다)
				table.insert(parts, Fx.part("ArtV1BatEye", Vector3.new(size * 0.07, size * 0.07, size * 0.07), spec.eye, CFrame.new(position + Vector3.new(side * size * 0.05, size * 0.06, -size * 0.16)), Enum.PartType.Ball, Enum.Material.Neon))
			end
		end
	end
	local drift = Vector3.new((math.random() - 0.5) * 4, 2.5 + math.random() * 2, (math.random() - 0.5) * 4)
	for _, p in ipairs(parts) do
		p.Transparency = 1 - 0.9 * opacityScale()
		TweenService:Create(p, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = p.Position + drift, Transparency = 1 }):Play()
		Debris:AddItem(p, seconds + 0.05)
	end
	for i, w in ipairs(wings) do -- 퍼덕임(각 3번)
		local side = i == 1 and -1 or 1
		TweenService:Create(w, TweenInfo.new(seconds / 6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 5, true), { Orientation = w.Orientation + Vector3.new(0, 0, side * -40) }):Play()
	end
end

local function footprint(st, theme)
	local f = theme.footstep
	local feet = Fx.feetOf(st.root.Parent)
	if not feet then
		return
	end
	local cf = CFrame.new(feet - Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, math.atan2(-st.root.CFrame.LookVector.X, -st.root.CFrame.LookVector.Z), 0)
	local p
	if f.shape == "puddle" then -- QUEUE-ALL1 P6 젤리 웅덩이 = 삐뚤한 납작 타원 + 가운데 밝은 방울
		local stretch = 0.75 + math.random() * 0.5
		p = Fx.part("ArtV1Step", Vector3.new(0.06, f.size * stretch, f.size), theme.edge, cf * CFrame.Angles(0, math.random() * math.pi, 0) * CFrame.Angles(0, 0, math.pi / 2), Enum.PartType.Cylinder, Enum.Material.Glass)
		local q = Fx.part("ArtV1Step", Vector3.new(0.08, f.size * 0.4, f.size * 0.4), theme.core, cf * CFrame.new(0.15, 0, 0.1) * CFrame.Angles(0, 0, math.pi / 2), Enum.PartType.Cylinder, Enum.Material.SmoothPlastic)
		q.Transparency = 1 - 0.7 * opacityScale()
		TweenService:Create(q, TweenInfo.new(f.seconds), { Transparency = 1 }):Play()
		Debris:AddItem(q, f.seconds + 0.05)
	elseif f.shape == "hammer" then -- QUEUE-ALL6 H 망치 자국 = 머리(가로 네모) + 자루(가는 네모) 납작 자국
		p = Fx.part("ArtV1Step", Vector3.new(f.size * 0.8, 0.06, f.size * 0.38), theme.edge, cf, Enum.PartType.Block, Enum.Material.SmoothPlastic)
		local q = Fx.part("ArtV1Step", Vector3.new(f.size * 0.14, 0.06, f.size * 0.7), theme.core, cf * CFrame.new(0, 0, f.size * 0.5), Enum.PartType.Block, Enum.Material.SmoothPlastic)
		q.Transparency = 1 - 0.7 * opacityScale()
		TweenService:Create(q, TweenInfo.new(f.seconds), { Transparency = 1 }):Play()
		Debris:AddItem(q, f.seconds + 0.05)
	elseif f.shape == "pumpkin" then -- QUEUE-ALL6 H 호박 = 납작 원 셋(가운데 큰 것 + 양옆) + 꼭지
		p = Fx.part("ArtV1Step", Vector3.new(0.06, f.size * 0.75, f.size * 0.9), f.pumpkin, cf * CFrame.Angles(0, 0, math.pi / 2), Enum.PartType.Cylinder, Enum.Material.SmoothPlastic)
		for _, side in ipairs({ -1, 1 }) do
			local q = Fx.part("ArtV1Step", Vector3.new(0.05, f.size * 0.55, f.size * 0.6), f.pumpkin:Lerp(theme.edge, 0.2), cf * CFrame.new(side * f.size * 0.3, 0, 0) * CFrame.Angles(0, 0, math.pi / 2), Enum.PartType.Cylinder, Enum.Material.SmoothPlastic)
			q.Transparency = 1 - 0.8 * opacityScale()
			TweenService:Create(q, TweenInfo.new(f.seconds), { Transparency = 1 }):Play()
			Debris:AddItem(q, f.seconds + 0.05)
		end
		local stem = Fx.part("ArtV1Step", Vector3.new(f.size * 0.12, 0.08, f.size * 0.25), f.stem, cf * CFrame.new(0, 0, -f.size * 0.5), Enum.PartType.Block, Enum.Material.SmoothPlastic)
		stem.Transparency = 1 - 0.8 * opacityScale()
		TweenService:Create(stem, TweenInfo.new(f.seconds), { Transparency = 1 }):Play()
		Debris:AddItem(stem, f.seconds + 0.05)
	elseif f.shape == "star" then -- 별 = 45° 겹친 납작한 네모 두 장
		p = Fx.part("ArtV1Step", Vector3.new(f.size * 0.7, 0.06, f.size * 0.7), theme.edge, cf * CFrame.Angles(0, math.rad(45), 0), Enum.PartType.Block, Enum.Material.Neon)
		local q = Fx.part("ArtV1Step", Vector3.new(f.size * 0.7, 0.07, f.size * 0.7), theme.core, cf, Enum.PartType.Block, Enum.Material.Neon)
		q.Transparency = 1 - 0.7 * opacityScale()
		TweenService:Create(q, TweenInfo.new(f.seconds), { Transparency = 1 }):Play()
		Debris:AddItem(q, f.seconds + 0.05)
	else
		p = Fx.part("ArtV1Step", Vector3.new(0.06, f.size, f.size), theme.edge, cf * CFrame.Angles(0, 0, math.pi / 2), Enum.PartType.Cylinder, f.neon and Enum.Material.Neon or Enum.Material.SmoothPlastic)
	end
	p.Transparency = 1 - 0.8 * opacityScale()
	TweenService:Create(p, TweenInfo.new(f.seconds), { Transparency = 1 }):Play()
	Debris:AddItem(p, f.seconds + 0.05)
end

RunService.Heartbeat:Connect(function(dt)
	local on = Fx.isOn()
	local camera = Workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position
	local now = os.clock()
	for character, st in pairs(chars) do
		if not character.Parent or not st.root.Parent then
			if st.glideRelease then -- QUEUE-ALL5 D①: 활강 중 캐릭터가 사라지면(죽음 · 리스폰 · 퇴장) 빌린 입자 몫을 못 돌려줘 예산이 영구히 줄었다
				st.glideRelease()
				st.glideRelease = nil
			end
			chars[character] = nil
			continue
		end
		local near = st.isLocal or (eye and (st.root.Position - eye).Magnitude <= FxData.budget.otherPlayerDistance)
		local vel = st.root.AssemblyLinearVelocity
		-- 수평 속도 = 위치 변화량(Play 4: 대시는 루트를 CFrame 트윈으로 옮겨 AssemblyLinearVelocity가 0이었다 · 남의 캐릭터도 복제 위치로 같게 잰다)
		local pos = st.root.Position
		local moved = Vector3.new(pos.X - st.lastPos.X, 0, pos.Z - st.lastPos.Z).Magnitude
		st.lastPos = pos
		local flat = (dt > 0 and moved < 60) and moved / dt or 0 -- 60 stud 넘게 한 번에 = 순간이동(대시 아님)
		local gliding = character:GetAttribute("Gliding") == true
		-- ① 대시 트레일
		local dashTheme = on and near and themeOf(st.player, "dashTrail")
		if dashTheme and flat >= D.dashSpeed and not gliding then
			if now >= st.dashUntil then
				styleTrail(st.dash, dashTheme, dashTheme.dash)
			end
			st.dashUntil = now + D.dashHoldSeconds * Fx.slow()
			local drops = dashTheme.dash.drops -- QUEUE-ALL1 P6 젤리: 대시 중 방울이 튀어 잠깐 남는다
			if drops and now >= (st.nextDrop or 0) then
				st.nextDrop = now + drops.every
				local b = Fx.part("ArtV1Drop", Vector3.one * drops.size * (0.6 + math.random() * 0.6), math.random() < 0.5 and dashTheme.core or dashTheme.edge,
					CFrame.new(st.root.Position + Vector3.new((math.random() - 0.5) * 1.6, -1.8 + math.random() * 1.2, (math.random() - 0.5) * 1.6)), Enum.PartType.Ball, drops.neon and Enum.Material.Neon or Enum.Material.Glass) -- QUEUE-ALL6 H 망치와 모루 = 빛나는 불꽃
				b.Transparency = 1 - 0.85 * opacityScale()
				TweenService:Create(b, TweenInfo.new(drops.seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1, Size = b.Size * 0.3, Position = b.Position - Vector3.new(0, 0.8, 0) }):Play()
				Debris:AddItem(b, drops.seconds + 0.05)
			end
		end
		local bats = dashTheme and dashTheme.dash.bats -- QUEUE-ALL6 H 할로윈: 대시 중 박쥐 떼
		if bats and flat >= D.dashSpeed and not gliding and now >= (st.nextBat or 0) then
			st.nextBat = now + bats.every * (st.isLocal and 1 or 2)
			st.batCount = (st.batCount or 0) + 1
			bat(st.root.Position + Vector3.new((math.random() - 0.5) * 2, -0.5 + math.random(), (math.random() - 0.5) * 2), dashTheme.edge, bats.size, bats.seconds, bats, dashTheme, st.batCount)
		end
		local gbats = gliding and on and near and themeOf(st.player, "glideTrail")
		gbats = gbats and gbats.glide.bats
		if gbats and now >= (st.nextGlideBat or 0) then -- 활강 중 박쥐 몇 마리가 따라 날다 흩어짐
			st.nextGlideBat = now + gbats.every * (st.isLocal and 1 or 2)
			st.batCount = (st.batCount or 0) + 1
			local gtheme = themeOf(st.player, "glideTrail")
			bat(st.root.Position + Vector3.new((math.random() - 0.5) * 3, 1 + math.random(), (math.random() - 0.5) * 3), gtheme.edge, gbats.size, gbats.seconds, gbats, gtheme, st.batCount)
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
