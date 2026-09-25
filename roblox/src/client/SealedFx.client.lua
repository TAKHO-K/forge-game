-- M1 봉인 입구 연출(클라 로컬 - 판정 없음 · 파티클 없음). 수치 = WorldMapData.sealed.
--   잠든 문장(SealEmblem): 빛이 숨쉬듯 희미하게(투명도 사인) · 구름 고래 그림자(SealedFx = whaleShadow): 나무 정상 근처에 있을 때 가끔 구름 위로 큰 그림자가 지나간다 ·
--   두더지 흙더미(SealedFx = moleMound): 가끔 뿅 솟았다 꺼진다. 봉인 입구는 조건 문구 · 날짜 · "곧 열림"을 쓰지 않는다(데이터 주석).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)

local player = Players.LocalPlayer
local DOOR = WorldMapData.sealed.door

local emblems, whaleSpots, moundSpots = {}, {}, {}
local function register(part)
	if not part:IsA("BasePart") then
		return
	end
	if part:GetAttribute("SealEmblem") then
		emblems[part] = true
	elseif part:GetAttribute("SealedFx") == "whaleShadow" then
		whaleSpots[part] = true
	elseif part:GetAttribute("SealedFx") == "moleMound" then
		moundSpots[part] = true
	end
end

task.spawn(function()
	local ground = Workspace:WaitForChild("Ground", 60)
	if not ground then
		return
	end
	for _, d in ipairs(ground:GetDescendants()) do
		register(d)
	end
	ground.DescendantAdded:Connect(register)
end)

local function localPart(size, color, transparency, shape)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Transparency = transparency
	if shape then
		p.Shape = shape
	end
	p.Parent = Workspace
	return p
end

local whale = nil -- { part, from, to, startedAt, seconds }
local nextWhaleAt = os.clock() + 8
local mound = nil -- { part, base, startedAt }
local nextMoundAt = os.clock() + 4

RunService.Heartbeat:Connect(function()
	local t = os.clock()
	for part in pairs(emblems) do
		if part.Parent then
			part.Transparency = 0.35 + 0.4 * (0.5 + 0.5 * math.sin(t * 2 * math.pi / DOOR.breatheSeconds))
		else
			emblems[part] = nil
		end
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	-- 고래 그림자: 정상(전망대 − 80) 위에 있을 때만 · 30 ~ 50초마다 한 번 지나간다
	if whale then
		local k = (t - whale.startedAt) / whale.seconds
		if k >= 1 then
			whale.part:Destroy()
			whale = nil
		else
			whale.part.CFrame = CFrame.lookAt(whale.from:Lerp(whale.to, k), whale.to)
		end
	elseif t >= nextWhaleAt and root.Position.Y > WorldMapData.hub.tree.course.deck.y - 80 then
		for spot in pairs(whaleSpots) do
			if spot.Parent then
				local p = spot.Position
				local from, to = p + Vector3.new(-260, 0, -120), p + Vector3.new(260, 20, 120)
				local part = localPart(Vector3.new(40, 16, 110), Color3.fromRGB(40, 50, 70), 0.55)
				local mesh = Instance.new("SpecialMesh")
				mesh.MeshType = Enum.MeshType.Sphere
				mesh.Parent = part
				whale = { part = part, from = from, to = to, startedAt = t, seconds = 9 }
				break
			end
		end
		nextWhaleAt = t + 30 + math.random() * 20
	end
	-- 두더지 흙더미: 광산 곁(반경 120 안)에 있을 때 4 ~ 9초마다 뿅
	if mound then
		local k = (t - mound.startedAt) / 1.6
		if k >= 1 then
			mound.part:Destroy()
			mound = nil
		else
			local h = math.sin(k * math.pi) * 2.2
			mound.part.CFrame = CFrame.new(mound.base + Vector3.new(0, h - 1, 0))
		end
	elseif t >= nextMoundAt then
		for spot in pairs(moundSpots) do
			if spot.Parent and (spot.Position - root.Position).Magnitude < 120 then
				local offset = Vector3.new(math.random(-8, 8), 0, math.random(-8, 8))
				local part = localPart(Vector3.new(4, 4, 4), Color3.fromRGB(120, 90, 60), 0, Enum.PartType.Ball)
				mound = { part = part, base = spot.Position + offset, startedAt = t }
				break
			end
		end
		nextMoundAt = t + 4 + math.random() * 5
	end
end)
