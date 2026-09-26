-- M1-4 해안 거품 · 물보라(클라 전용 · 로컬 · 수량 제한 - 사용자: Terrain 물결은 전역이라 해안 · 신전 주변만 따로). 수치 = WorldMapData.coastFx.
--   거품 자리 = T3 해안선(TerrainShape.coastR - 방위마다) + 바다 만 둘레 · spacing 간격. 카메라 radius 안의 가까운 near개만 입자를 켠다(나머지는 끔 · 풀 재사용).
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)
local TerrainShape = require(ReplicatedStorage.Shared.TerrainShape)
local TerrainGenData = require(ReplicatedStorage.Shared.data.TerrainGenData)

local C = WorldMapData.coastFx
local sea = TerrainGenData.edgeStyles.tier3
local waterY = WorldMapData.floorTopY + sea.seaLevel + 0.4

-- 거품 자리 목록(한 번)
local spots = {}
do
	local zone = WorldMapLayout.zoneByKey("tier3")
	local R0 = sea.coastR
	local step = C.spacing / R0 * 180 / math.pi
	for d = zone.angleDeg - 26, zone.angleDeg + 26, step do
		local R = TerrainShape.coastR(d) + sea.beach * 0.35
		local a = math.rad(d)
		table.insert(spots, Vector3.new(math.cos(a) * R, waterY, math.sin(a) * R))
	end
	local bay = TerrainGenData.zones.tier3.bay
	local c = WorldMapLayout.toWorld(zone, bay.r, bay.lat)
	local n = math.floor(2 * math.pi * bay.radius / C.spacing)
	for i = 1, n do
		local a = i / n * 2 * math.pi
		table.insert(spots, Vector3.new(c.X + math.cos(a) * (bay.radius + 6), waterY, c.Z + math.sin(a) * (bay.radius + 6)))
	end
end

local folder = Instance.new("Folder")
folder.Name = "CoastFx"
folder.Parent = workspace
local pool = {}
for i = 1, C.near do
	local p = Instance.new("Part")
	p.Name = "Foam"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(14, 1, 14)
	p.Parent = folder
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0
	e.Lifetime = NumberRange.new(C.lifetime * 0.7, C.lifetime)
	e.Speed = NumberRange.new(2, 5)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, C.size * 0.5), NumberSequenceKeypoint.new(1, C.size) })
	e.Color = ColorSequence.new(Color3.fromRGB(240, 250, 252))
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	e.SpreadAngle = Vector2.new(60, 60)
	e.Acceleration = Vector3.new(0, -6, 0)
	e.LightEmission = 0.1
	e.Parent = p
	pool[i] = { part = p, emitter = e }
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.5 then
		return
	end
	acc = 0
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local here = cam.CFrame.Position
	local near = {}
	for _, s in ipairs(spots) do
		local d = Vector3.new(s.X - here.X, 0, s.Z - here.Z).Magnitude
		if d <= C.radius then
			table.insert(near, { s = s, d = d })
		end
	end
	table.sort(near, function(a, b)
		return a.d < b.d
	end)
	for i, slot in ipairs(pool) do
		local n = near[i]
		if n then
			slot.part.CFrame = CFrame.new(n.s)
			slot.emitter.Rate = C.rate
		else
			slot.emitter.Rate = 0
		end
	end
end)
