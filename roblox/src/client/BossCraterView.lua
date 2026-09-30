-- A2-N4 §2-5 지진파 구덩이 흔적(클라 겉모습만 - 충돌 · 조준 · 터치 끔 = 충돌 변화 0 · 판정 무관). 데이터 = BossFxData.quakeLook.crater.
--   add(center, floorColor): 찍은 자리 바닥에 어두운 얕은 원 + 테두리 돌 조각. 아레나당(= 이 클라가 보는 보스전) maxCraters개 - 넘으면 옛 것부터 치운다.
--   보스전이 끝나면(LocalPlayer BossEncounterId 없음) 전부 치운다 = 전투 끝 복구.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local BossFxData = require(ReplicatedStorage.Shared.data.BossFxData)

local BossCraterView = {}

local craters = {} -- 목록(옛 것부터) - 각 항목 = { parts }
local folder = nil

local function newPart(name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size, p.CFrame, p.Color, p.Material = size, cf, color, material
	p.Transparency = 1
	p.Parent = folder
	return p
end

local function clearAll()
	for _, c in ipairs(craters) do
		for _, p in ipairs(c) do
			p:Destroy()
		end
	end
	table.clear(craters)
end

function BossCraterView.add(center, floorColor)
	local C = BossFxData.quakeLook.crater
	if not C then
		return
	end
	if not folder or not folder.Parent then
		folder = Instance.new("Folder")
		folder.Name = "BossCraters"
		folder.Parent = Workspace
	end
	while #craters >= C.maxCraters do
		for _, p in ipairs(table.remove(craters, 1)) do
			p:Destroy()
		end
	end
	local base = floorColor or Color3.fromRGB(120, 110, 100)
	local dark = base:Lerp(Color3.new(0, 0, 0), 0.45)
	local rim = base:Lerp(Color3.new(1, 1, 1), 0.12)
	local parts = {}
	-- 바닥 위 0.06(바닥과 겹쳐 깜빡이지 않게) 얇은 원 두 겹: 바깥 = 흙 테 · 안 = 어두운 속(깊이는 색으로만 - depthLook는 속 원의 두께 느낌)
	local ground = center + Vector3.new(0, 0.06, 0)
	table.insert(parts, newPart("CraterRim", Vector3.new(0.1, C.radius * 2, C.radius * 2), CFrame.new(ground) * CFrame.Angles(0, 0, math.rad(90)), rim, Enum.Material.Ground))
	table.insert(parts, newPart("CraterPit", Vector3.new(0.12, C.radius * 1.5, C.radius * 1.5), CFrame.new(ground + Vector3.new(0, 0.02, 0)) * CFrame.Angles(0, 0, math.rad(90)), dark, Enum.Material.Ground))
	parts[1].Shape, parts[2].Shape = Enum.PartType.Cylinder, Enum.PartType.Cylinder
	local rng = Random.new()
	for i = 1, C.rimRocks do
		local a = (i / C.rimRocks) * 2 * math.pi + rng:NextNumber(-0.3, 0.3)
		local s = rng:NextNumber(C.rockSize[1], C.rockSize[2])
		local at = center + Vector3.new(math.cos(a) * C.radius * 0.9, s * 0.25, math.sin(a) * C.radius * 0.9)
		table.insert(parts, newPart("CraterRock", Vector3.new(s, s * 0.6, s * 0.8), CFrame.new(at) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6.28), rng:NextNumber(-0.4, 0.4)), rim:Lerp(dark, 0.3), Enum.Material.Slate))
	end
	for _, p in ipairs(parts) do
		TweenService:Create(p, TweenInfo.new(C.fadeInSeconds), { Transparency = 0 }):Play()
	end
	table.insert(craters, parts)
end

function BossCraterView.count()
	return #craters
end

local player = Players.LocalPlayer
local lastEncounter = player:GetAttribute("BossEncounterId")
player:GetAttributeChangedSignal("BossEncounterId"):Connect(function()
	local id = player:GetAttribute("BossEncounterId")
	if id ~= lastEncounter then
		clearAll() -- 전투 끝 · 다른 보스전 = 복구
	end
	lastEncounter = id
end)

return BossCraterView
