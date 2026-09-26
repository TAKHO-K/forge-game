-- M1-4 관문 주변 날씨(클라 전용 · 로컬 - 서버 · 다른 사람과 무관). 수치 = WorldMapData.gateWeather.
--   sea(심해 군주 신전): 물보라(광장 가장자리) + 옅은 안개 / storm(폭풍 군주 첨탑): 비(카메라 둘레) + 먹구름 판 + 드문 흐린 섬광.
--   섬광 = 구름 속 넓고 은은한 빛(PointLight · 구름 색이 잠깐 밝아짐) - 보스 낙뢰(노란 줄기 · 바닥 표시) · 피뢰침 경고와 모양 · 색이 다르다(연보라 흰빛 · 줄기 없음).
--   광과민 배려: 밝기 낮게 · 간격 16 ~ 32초 · Player Attribute ReduceFlashes = true면 섬광 끔. 입자 수 상한 = maxParticles(rate × lifetime 합).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)

local W = WorldMapData.gateWeather
local player = Players.LocalPlayer

local function color3(c)
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- 입자 몫 줄이기(상한): 켜는 효과들의 rate × lifetime 합이 넘으면 같은 비율로 rate를 낮춘다
local function budgetScale(parts)
	local total = 0
	for _, p in ipairs(parts) do
		total += p.rate * p.lifetime
	end
	return total > W.maxParticles and W.maxParticles / total or 1
end

local function anchoredPart(name, size, cf, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
	return p
end

local function emitter(parent, spec)
	local e = Instance.new("ParticleEmitter")
	e.Rate = spec.rate
	e.Lifetime = NumberRange.new(spec.lifetime * 0.8, spec.lifetime)
	e.Speed = NumberRange.new(spec.speed or 2)
	e.Size = NumberSequence.new(spec.size or 1)
	e.Color = ColorSequence.new(spec.color or Color3.new(1, 1, 1))
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, spec.transparency or 0.4), NumberSequenceKeypoint.new(1, 1) })
	e.LightEmission = spec.light or 0.2
	e.SpreadAngle = spec.spread or Vector2.new(30, 30)
	e.EmissionDirection = spec.dir or Enum.NormalId.Top
	e.Acceleration = spec.accel or Vector3.zero
	if spec.parallel then
		e.Orientation = Enum.ParticleOrientation.VelocityParallel
	end
	e.Parent = parent
	return e
end

local folder = Instance.new("Folder")
folder.Name = "GateWeather"
folder.Parent = workspace

local sites = {} -- [zoneKey] = { spec, position, built = { … } | nil }
for _, g in ipairs(WorldMapLayout.bossGates()) do
	if g.zoneKey and W[g.zoneKey] then
		sites[g.zoneKey] = { key = g.zoneKey, spec = W[g.zoneKey], position = g.position, dir = g.dir }
	end
end

local function build(site)
	local S = site.spec
	local out = { emitters = {}, parts = {} }
	local pos = site.position
	if S.kind == "sea" then
		local plaza = ((WorldMapData.layout.gateSites or {})[site.key] or {}).plaza or 60
		local list = {}
		for i = 1, S.spray.count do
			local a = (i - 0.5) / S.spray.count * 2 * math.pi
			local p = anchoredPart("Spray", Vector3.new(4, 1, 4), CFrame.new(pos + Vector3.new(math.cos(a) * plaza * 0.55, -3, math.sin(a) * plaza * 0.55)), folder)
			table.insert(out.parts, p)
			table.insert(list, { part = p, rate = S.spray.rate, lifetime = S.spray.lifetime,
				spec = { rate = S.spray.rate, lifetime = S.spray.lifetime, speed = 12, size = S.spray.size, color = Color3.fromRGB(230, 245, 250), transparency = 0.35, spread = Vector2.new(25, 25), accel = Vector3.new(0, -20, 0) } })
		end
		local m = anchoredPart("Mist", Vector3.new(plaza, 1, plaza), CFrame.new(pos + Vector3.new(0, 2, 0)), folder)
		table.insert(out.parts, m)
		table.insert(list, { part = m, rate = S.mist.rate, lifetime = S.mist.lifetime,
			spec = { rate = S.mist.rate, lifetime = S.mist.lifetime, speed = 1, size = S.mist.size, color = Color3.fromRGB(200, 225, 230), transparency = S.mist.transparency, light = 0 } })
		local k = budgetScale(list)
		for _, e in ipairs(list) do
			e.spec.rate *= k
			table.insert(out.emitters, emitter(e.part, e.spec))
		end
	elseif S.kind == "storm" then
		local C = S.cloud
		local cloud = Instance.new("Part")
		cloud.Name = "StormCloud"
		cloud.Shape = Enum.PartType.Cylinder
		cloud.Anchored, cloud.CanCollide, cloud.CanQuery, cloud.CanTouch, cloud.CastShadow = true, false, false, false, false
		cloud.Size = Vector3.new(24, C.radius * 2, C.radius * 2)
		cloud.CFrame = CFrame.new(pos + Vector3.new(0, C.height, 0) + site.dir * 80) * CFrame.Angles(0, 0, math.rad(90))
		cloud.Color = color3(C.color)
		cloud.Material = Enum.Material.SmoothPlastic
		cloud.Transparency = C.transparency
		cloud.Parent = folder
		local light = Instance.new("PointLight")
		light.Brightness = 0
		light.Range = S.flash.range
		light.Color = color3(S.flash.color)
		light.Shadows = false
		light.Parent = cloud
		out.cloud, out.light = cloud, light
		table.insert(out.parts, cloud)
		-- 비: 카메라 머리 위를 따라다니는 판 하나(아래로 긴 줄)
		local rain = anchoredPart("StormRain", Vector3.new(90, 1, 90), CFrame.new(pos + Vector3.new(0, 60, 0)), folder)
		out.rain = rain
		table.insert(out.parts, rain)
		local list = { { part = rain, rate = S.rain.rate, lifetime = S.rain.lifetime,
			spec = { rate = S.rain.rate, lifetime = S.rain.lifetime, speed = S.rain.speed, size = 0.18, color = Color3.fromRGB(190, 205, 230), transparency = 0.45, dir = Enum.NormalId.Bottom, spread = Vector2.new(4, 4), parallel = true, light = 0 } } }
		local k = budgetScale(list)
		for _, e in ipairs(list) do
			e.spec.rate *= k
			table.insert(out.emitters, emitter(e.part, e.spec))
		end
		out.nextFlash = os.clock() + S.flash.everySeconds[1]
	end
	return out
end

local function teardown(site)
	for _, p in ipairs(site.built.parts) do
		p:Destroy()
	end
	site.built = nil
end

local function flash(site)
	local S = site.spec
	if player:GetAttribute("ReduceFlashes") then
		return
	end
	local b = site.built
	local base = color3(S.cloud.color)
	b.light.Brightness = S.flash.brightness
	b.cloud.Color = base:Lerp(color3(S.flash.color), 0.35)
	local info = TweenInfo.new(S.flash.seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(b.light, info, { Brightness = 0 }):Play()
	TweenService:Create(b.cloud, info, { Color = base }):Play()
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local here = cam.CFrame.Position
	for _, site in pairs(sites) do
		local b = site.built
		if b and b.rain then -- 비 판은 카메라 머리 위를 매 프레임 따라간다
			b.rain.CFrame = CFrame.new(here + Vector3.new(0, 40, 0))
		end
	end
	acc += dt
	if acc < 0.5 then
		return
	end
	acc = 0
	local now = os.clock()
	for _, site in pairs(sites) do
		local d = Vector3.new(here.X - site.position.X, 0, here.Z - site.position.Z).Magnitude
		local inside = d <= site.spec.radius
		if inside and not site.built then
			site.built = build(site)
		elseif not inside and site.built then
			teardown(site)
		end
		local b = site.built
		if b and b.light and now >= b.nextFlash then
			local E = site.spec.flash.everySeconds
			b.nextFlash = now + E[1] + math.random() * (E[2] - E[1])
			flash(site)
		end
	end
end)
