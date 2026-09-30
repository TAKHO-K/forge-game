-- QUEUE-ALL3 Q10 먼 산 배치(서버 - 모두에게 같은 풍경 · 정적). 수치 = shared/data/DistantMountainData · 메시 = ReplicatedStorage.ArtMeshCache(ArtAssetLoader - ArtStyleV1 켬일 때만).
--   캐시가 준비되면(ArtMeshReady) 한 번 짓는다. 충돌 · 조회 · 터치 · 그림자 없음 · 세계 경계 밖만(플레이 지형 · 충돌 불변).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local D = require(ReplicatedStorage.Shared.data.DistantMountainData)
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local ArtImportData = require(ReplicatedStorage.Shared.data.ArtImportData)

local function waitCache()
	local cache = ReplicatedStorage:WaitForChild(ArtImportData.cacheFolder, 600)
	if not cache then
		return nil
	end
	local t0 = os.clock()
	while not cache:GetAttribute(ArtImportData.readyAttribute) and os.clock() - t0 < 600 do
		task.wait(1)
	end
	return cache
end

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function place(cache, key, colors, position, yaw, scale, haze, folder, name)
	local src = cache:FindFirstChild("props/mountains/" .. key)
	if not src then
		return 0
	end
	local m = src:Clone()
	m.Name = name
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow = true, false, false, false, false
			local c = colors[d.Name] or colors.Body
			if c then
				d.Color = haze and rgb(c):Lerp(rgb(D.far.hazeColor), D.far.hazeLerp) or rgb(c)
			end
			d.Material = Enum.Material.SmoothPlastic
		end
	end
	local _, size = m:GetBoundingBox()
	local want = D.heights[key:gsub("_lod$", "")] -- 가져온 크기 ≠ 원래 크기(단위) → 원래 높이 × scale로
	if want and size.Y > 0.01 then
		scale *= want / size.Y
	end
	m:ScaleTo(scale)
	m:PivotTo(CFrame.new(position) * CFrame.Angles(0, yaw, 0))
	m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- 스트리밍 반경(1,024) 밖이라 항상 보내야 보인다(부모 연결 전에 - M1 기록)
	m.Parent = folder
	return 1
end

task.spawn(function()
	local cache = waitCache()
	if not cache or not Workspace:GetAttribute("ArtStyleV1") then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = D.folderName
	local near = Instance.new("Folder")
	near.Name = "Near"
	near.Parent = folder
	local far = Instance.new("Folder")
	far.Name = "Far"
	far.Parent = folder
	local rng = Random.new(D.seed)
	local y = WorldMapData.floorTopY - D.baseDepth
	local placed = 0
	local zoneByIndex = {}
	for i, zone in ipairs(WorldMapData.zones) do
		zoneByIndex[i] = zone
		local z = D.zones[zone.key]
		if z then
			for j, off in ipairs(D.near.angleOffsets) do
				local a = math.rad(zone.angleDeg + off)
				local r = D.near.r + rng:NextNumber(-D.near.jitterR, D.near.jitterR)
				local key = z.meshes[(j - 1) % #z.meshes + 1]
				local pos = Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
				place(cache, key, z.colors, pos, rng:NextNumber(0, math.pi * 2), rng:NextNumber(D.near.scale[1], D.near.scale[2]), false, near, key .. "_" .. j)
				placed += 1
			end
		end
	end
	for k = 1, D.far.count do
		local deg = (k - 1) * 360 / D.far.count
		local best, bestD = nil, math.huge
		for _, zone in ipairs(WorldMapData.zones) do
			local d = math.abs(((deg - zone.angleDeg + 180) % 360) - 180)
			if d < bestD then
				best, bestD = zone, d
			end
		end
		local z = best and D.zones[best.key]
		if z then
			local a = math.rad(deg)
			local r = D.far.r + rng:NextNumber(-D.far.jitterR, D.far.jitterR)
			local key = z.meshes[(k - 1) % #z.meshes + 1] .. "_lod"
			local pos = Vector3.new(math.cos(a) * r, y - 20, math.sin(a) * r)
			place(cache, key, z.colors, pos, rng:NextNumber(0, math.pi * 2), rng:NextNumber(D.far.scale[1], D.far.scale[2]), true, far, key .. "_" .. k)
			placed += 1
		end
	end
	folder.Parent = Workspace
	print(("[Q10] 먼 산 %d개(가까운 %d · 먼 LOD %d)"):format(placed, #near:GetChildren(), #far:GetChildren()))
end)
