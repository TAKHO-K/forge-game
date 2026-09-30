-- A2-N4 §3-2 슬라임 구역 가장자리 풀 덤불(ArtStyleV1 뒤 · 클라 겉모습만 - 충돌 · 조준 · 터치 · 그림자 끔 · 판정 무관). 데이터 = ArtV1ZoneData.edgeTufts · 메시 = ArtMeshCache props/grass_tuft.
--   자리 = 그 구역 본길 · 갈림길(shared/RoadNet)의 가장자리(RoadData.half + shoulder) 밖 양옆 · 지형이 풀(onMaterials)인 곳만(아래로 광선).
--   지형도 스트리밍되므로 내 주변 nearStuds 안의 자리만 checkSeconds마다 차례로 놓는다(상한 maxCount). 끄면(ArtStyleV1 끔) 전부 치운다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ArtV1ZoneData = require(ReplicatedStorage.Shared.data.ArtV1ZoneData)
local ArtStyleV1Data = require(ReplicatedStorage.Shared.data.ArtStyleV1Data)
local RoadData = require(ReplicatedStorage.Shared.data.RoadData)
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local ArtMeshKit = require(ReplicatedStorage.Shared.ArtMeshKit)
local RoadNet = require(ReplicatedStorage.Shared.RoadNet)

local T = ArtV1ZoneData.edgeTufts
local player = Players.LocalPlayer
local folder = nil
local spots = nil -- { { p = Vector3(길 옆 수평 자리), placed = bool } }
local placedCount = 0

local function buildSpots()
	local list = {}
	local rng = Random.new(20260930)
	local edge = RoadData.half + RoadData.shoulder
	for _, key in ipairs(T.zones) do
		for _, zone in ipairs(WorldMapData.zones) do
			if zone.key == key then
				local paths = { RoadNet.zonePath(zone), RoadNet.branchPath(zone) }
				for _, path in pairs(paths) do
					local last = -math.huge
					for i = 2, #path.pts do
						local q, prev = path.pts[i], path.pts[i - 1]
						if q.s - last >= T.spacing then
							last = q.s
							local dir = Vector3.new(q.x - prev.x, 0, q.z - prev.z)
							if dir.Magnitude > 1e-3 then
								local side = Vector3.new(-dir.Unit.Z, 0, dir.Unit.X)
								for _, sgn in ipairs({ -1, 1 }) do
									for _ = 1, T.perSide do
										local off = edge + rng:NextNumber(T.offset[1], T.offset[2])
										local along = dir.Unit * rng:NextNumber(-T.spacing / 2, T.spacing / 2)
										table.insert(list, { p = Vector3.new(q.x, q.y, q.z) + side * sgn * off + along, yaw = rng:NextNumber(0, 2 * math.pi), scale = rng:NextNumber(T.scale[1], T.scale[2]), color = T.colors[rng:NextInteger(1, #T.colors)] })
									end
								end
							end
						end
					end
				end
			end
		end
	end
	return list
end

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { Workspace.Terrain }

local function clearAll()
	if folder then
		folder:Destroy()
		folder = nil
	end
	placedCount = 0
	if spots then
		for _, s in ipairs(spots) do
			s.placed = false
		end
	end
end

local function step()
	if Workspace:GetAttribute(ArtStyleV1Data.attribute) ~= true then
		if folder then
			clearAll()
		end
		return
	end
	local src = ArtMeshKit.get("props/grass_tuft")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not src or not root then
		return
	end
	spots = spots or buildSpots()
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "GrassTufts"
		folder.Parent = Workspace
	end
	local mesh = src:FindFirstChildWhichIsA("BasePart", true)
	for _, s in ipairs(spots) do
		if placedCount >= T.maxCount then
			break
		end
		if not s.placed and (Vector3.new(s.p.X - root.Position.X, 0, s.p.Z - root.Position.Z)).Magnitude <= T.nearStuds then
			local hit = Workspace:Raycast(s.p + Vector3.new(0, 40, 0), Vector3.new(0, -90, 0), params)
			if hit then
				s.placed = true
				if T.onMaterials[hit.Material.Name] then
					local m = mesh:Clone()
					m.Name = "Tuft"
					m.Size = mesh.Size * s.scale
					m.CFrame = CFrame.new(hit.Position + Vector3.new(0, m.Size.Y / 2 - 0.15, 0)) * CFrame.Angles(0, s.yaw, 0)
					m.Anchored, m.CanCollide, m.CanQuery, m.CanTouch, m.CastShadow = true, false, false, false, false
					m.Color = Color3.fromRGB(s.color[1], s.color[2], s.color[3])
					m.Material = Enum.Material.SmoothPlastic
					m.Parent = folder
					placedCount += 1
				end
			end
		end
	end
end

task.spawn(function()
	while true do
		local ok, err = pcall(step)
		if not ok then
			warn("[GrassTuftView] " .. tostring(err))
			task.wait(10)
		end
		task.wait(T.checkSeconds)
	end
end)
