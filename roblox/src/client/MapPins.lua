-- 지도 핀 · 지도 이동 공용(QUEUE-ALL3 Q4 · 10 문서 4절). 전체 지도(panels/WorldMapPanel) · 미니맵(hud/Minimap) · 월드 표시가 같은 표를 본다.
--   핀 = 플레이어가 찍은 자리(최대 WorldMapData.map.maxPins · 이번 접속 동안 - 로컬). 월드 = 로컬 빛기둥(충돌 · 조회 없음).
--   MapPins.go(position, label, auto) = 길 안내(Wayfinder owner "mapPin") · auto면 자동 이동(AutoWalk - owners.mapPin 허용). 둥지 · 탐험 지점은 이 목록에 올리지 않는다(지도에 안 그린다).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)
local RoadNet = require(ReplicatedStorage.Shared.RoadNet)

local MapPins = {}

local changed = Instance.new("BindableEvent")
MapPins.changed = changed.Event
local pins = {} -- { { id, position(Vector3 지면), label } }
local nextId = 0
local folder

local function beacon(pin)
	folder = folder or Instance.new("Folder")
	folder.Name = "MapPinsLocal"
	folder.Parent = Workspace
	local p = Instance.new("Part")
	p.Name = "MapPin_" .. pin.id
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Shape = Enum.PartType.Cylinder
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(176, 120, 255) -- 보라(빨강 · 주황 = 전조색 금지)
	p.Transparency = 0.45
	local h = WorldMapData.map.pinBeaconHeight
	p.Size = Vector3.new(h, 2.5, 2.5)
	p.CFrame = CFrame.new(pin.position + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	p.Parent = folder
	pin.part = p
end

function MapPins.list()
	return pins
end

-- 이 자리 가까이(radius stud)에 핀이 있으면 지우고 true · 없으면 새로 찍는다(최대 개수면 가장 오래된 것을 지운다)
function MapPins.toggleAt(position, radius)
	for i, pin in ipairs(pins) do
		if (Vector3.new(pin.position.X - position.X, 0, pin.position.Z - position.Z)).Magnitude <= radius then
			if pin.part then
				pin.part:Destroy()
			end
			table.remove(pins, i)
			changed:Fire()
			return false
		end
	end
	if #pins >= WorldMapData.map.maxPins then
		local old = table.remove(pins, 1)
		if old.part then
			old.part:Destroy()
		end
	end
	nextId += 1
	local ground = position.Y ~= 0 and position.Y or WorldMapData.floorTopY
	local pin = { id = nextId, position = Vector3.new(position.X, ground, position.Z), label = ("핀 %d"):format(nextId) }
	beacon(pin)
	table.insert(pins, pin)
	changed:Fire()
	return true
end

function MapPins.clear()
	for _, pin in ipairs(pins) do
		if pin.part then
			pin.part:Destroy()
		end
	end
	table.clear(pins)
	changed:Fire()
end

-- 길 안내 점 목록: 목적지가 구역 안이면 그 구역 본길(허브 끝 → …)에서 목적지와 가장 가까운 점까지 + 목적지 · 허브면 목적지 하나
function MapPins.pointsTo(position)
	local zone = WorldMapLayout.zoneAt(position)
	if not zone or WorldMapLayout.inHub(position) then
		return { position }
	end
	local road = RoadNet.guidePoints(zone)
	local best, bestD = 1, math.huge
	for i, p in ipairs(road) do
		local d = (Vector3.new(p.X - position.X, 0, p.Z - position.Z)).Magnitude
		if d < bestD then
			best, bestD = i, d
		end
	end
	local list = {}
	for i = 1, best do
		table.insert(list, road[i])
	end
	table.insert(list, position)
	return list
end

-- 길 안내(auto = 자동 이동도). 반환 = 안내를 켰나
function MapPins.go(position, label, auto)
	local Wayfinder = require(script.Parent.Wayfinder)
	Wayfinder.setPoints("mapPin", MapPins.pointsTo(position), { label = label, clearOnArrive = true })
	if auto then
		task.spawn(function()
			local AutoWalk = require(script.Parent.AutoWalk)
			for _ = 1, 40 do -- 경로 계산(비동기)을 기다린다(최대 4초)
				if Wayfinder.route() then
					break
				end
				task.wait(0.1)
			end
			AutoWalk.start()
		end)
	end
	return true
end

return MapPins
