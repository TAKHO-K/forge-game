-- QUEUE-ALL3 Q7 모서리 다듬기(내 화면 · 겉모습만 · ArtStyleV1 뒤). 규칙 · 대상 = shared/data/BevelData.
--   원래 Block 파트 = 그대로(충돌 · 크기 · 자리 · 조회 · 서버 판정 불변 - 내 화면에서 LocalTransparencyModifier = 1로만 숨김) · 그 위에 같은 CFrame(축 돌림) · Size의 베벨 MeshPart(충돌 · 조회 · 터치 없음)를 겹친다.
--   스트리밍으로 들어오는 파트도 따라간다(Workspace.DescendantAdded) · 원래 파트가 사라지면 겹친 것도 지운다 · 상한 maxParts.
--   Studio 점검: LocalPlayer Attribute "BevelDebug" = true면 [Q7] 줄에 입힌 수 · 재질 분포를 찍는다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local D = require(ReplicatedStorage.Shared.data.BevelData)
local ArtImportData = require(ReplicatedStorage.Shared.data.ArtImportData)

local player = Players.LocalPlayer
local folder = Instance.new("Folder")
folder.Name = "BevelSkinLocal"
folder.Parent = Workspace

local stone = {}
for _, name in ipairs(D.stoneMaterials) do
	local ok, m = pcall(function()
		return Enum.Material[name]
	end)
	if ok and m then
		stone[m] = true
	end
end

local templates = {} -- key -> MeshPart
local skinned = {} -- [원래 파트] = 겹친 MeshPart
local candidates = {} -- [원래 파트] = true(대상 전부 - 상한 안에서 카메라에 가까운 것부터 입힌다)
local count = 0

-- 축 순서 6가지(원래 x · y · z가 메시의 어느 축으로 가나) + 그 회전
local PERMS = {
	{ { 1, 2, 3 }, CFrame.new() },
	{ { 3, 2, 1 }, CFrame.Angles(0, math.rad(90), 0) },
	{ { 1, 3, 2 }, CFrame.Angles(math.rad(90), 0, 0) },
	{ { 2, 1, 3 }, CFrame.Angles(0, 0, math.rad(90)) },
	{ { 2, 3, 1 }, CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(math.rad(90), 0, 0) }, -- 메시 X → 원래 Y · Y → Z · Z → X
	{ { 3, 1, 2 }, CFrame.Angles(0, math.rad(-90), 0) * CFrame.Angles(math.rad(-90), 0, 0) }, -- 메시 X → 원래 Z · Y → X · Z → Y
}

-- 가장 가까운 등급 + 축 순서: 반환 class, perm(메시 축 i ← 원래 축 perm[1][i]), rot
local function pick(size)
	local dims = { size.X, size.Y, size.Z }
	local minSide = math.min(size.X, size.Y, size.Z)
	local best, bestPerm, bestD = nil, nil, math.huge
	for _, class in ipairs(D.classes) do
		for _, perm in ipairs(PERMS) do
			local d = 0
			for i = 1, 3 do
				d += math.abs(math.log(dims[perm[1][i]] / minSide) - math.log(class.ratio[i]))
			end
			if d < bestD then
				best, bestPerm, bestD = class, perm, d
			end
		end
	end
	return best, bestPerm
end

local function excluded(part)
	for _, word in ipairs(D.excludeNames) do
		if part.Name:find(word, 1, true) then
			return true
		end
	end
	local node = part.Parent
	while node and node ~= Workspace do
		if table.find(D.excludeAncestors, node.Name) or node:FindFirstChildOfClass("Humanoid") then
			return true
		end
		node = node.Parent
	end
	return false
end

local function candidate(part)
	if not part:IsA("Part") or part.Shape ~= Enum.PartType.Block or not stone[part.Material] then
		return false
	end
	if part.Transparency >= 0.9 or part:IsDescendantOf(folder) then
		return false
	end
	local s = part.Size
	local minSide, maxSide = math.min(s.X, s.Y, s.Z), math.max(s.X, s.Y, s.Z)
	if minSide < D.minSide or maxSide > D.maxSide then
		return false
	end
	return not excluded(part)
end

local function unskin(part)
	local m = skinned[part]
	if m then
		m:Destroy()
		skinned[part] = nil
		count -= 1
		part.LocalTransparencyModifier = 0
	end
end

local function skin(part)
	if skinned[part] or count >= D.maxParts then
		return
	end
	local class, perm = pick(part.Size)
	local template = class and templates[class.key]
	if not template then
		return
	end
	local dims = { part.Size.X, part.Size.Y, part.Size.Z }
	local m = template:Clone()
	m.Anchored, m.CanCollide, m.CanQuery, m.CanTouch = true, false, false, false
	m.CastShadow = part.CastShadow
	m.Color, m.Material, m.Reflectance = part.Color, part.Material, part.Reflectance
	m.Size = Vector3.new(dims[perm[1][1]], dims[perm[1][2]], dims[perm[1][3]])
	m.CFrame = part.CFrame * perm[2]
	m.Parent = folder
	local off = RunService:IsStudio() and player:GetAttribute("BevelSkinOff") == true
	part.LocalTransparencyModifier = off and 0 or 1
	m.Transparency = off and 1 or 0
	skinned[part] = m
	count += 1
	local conn
	conn = part:GetPropertyChangedSignal("CFrame"):Connect(function()
		if skinned[part] == m then
			m.CFrame = part.CFrame * perm[2]
		else
			conn:Disconnect()
		end
	end)
end

local function register(part)
	if candidates[part] or not candidate(part) then
		return
	end
	candidates[part] = true
	part.AncestryChanged:Connect(function(_, parent)
		if not parent then
			candidates[part] = nil
			unskin(part)
		end
	end)
end

-- 상한 안에서 카메라에 가까운 것부터: 먼 것은 벗기고(원래 파트 다시 보임) 가까운 것을 입힌다(허브 파트가 상한을 다 써서 구역에는 하나도 안 입혀지던 것 - Studio Play 확인)
local function refresh()
	local at = Workspace.CurrentCamera.CFrame.Position
	local list = {}
	for part in pairs(candidates) do
		table.insert(list, { part, (part.Position - at).Magnitude })
	end
	table.sort(list, function(a, b)
		return a[2] < b[2]
	end)
	local want = {}
	for i = 1, math.min(D.maxParts, #list) do
		want[list[i][1]] = true
	end
	for part in pairs(skinned) do
		if not want[part] then
			unskin(part)
		end
	end
	for part in pairs(want) do
		skin(part)
	end
end

local function loadTemplates(cache)
	for _, class in ipairs(D.classes) do
		local model = cache:FindFirstChild(class.key)
		local mesh = model and model:FindFirstChildWhichIsA("MeshPart", true)
		if mesh then
			templates[class.key] = mesh
		end
	end
	return next(templates) ~= nil
end

task.spawn(function()
	local cache = ReplicatedStorage:WaitForChild(ArtImportData.cacheFolder, 600)
	if not cache then
		return
	end
	local t0 = os.clock()
	while not cache:GetAttribute(ArtImportData.readyAttribute) and os.clock() - t0 < 600 do
		task.wait(1)
	end
	if Workspace:GetAttribute("ArtStyleV1") ~= true or not loadTemplates(cache) then
		return
	end
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d:IsA("Part") then
			register(d)
		end
	end
	Workspace.DescendantAdded:Connect(function(d)
		if d:IsA("Part") then
			task.defer(register, d)
		end
	end)
	refresh()
	task.spawn(function()
		while true do
			task.wait(D.refreshSeconds)
			refresh()
			player:SetAttribute("BevelSkinned", count)
		end
	end)
	if RunService:IsStudio() and player:GetAttribute("BevelDebug") then
		local mats = {}
		for part in pairs(skinned) do
			mats[part.Material.Name] = (mats[part.Material.Name] or 0) + 1
		end
		local parts = {}
		for k, v in pairs(mats) do
			table.insert(parts, k .. "=" .. v)
		end
		print(("[Q7] 베벨 입힘 %d(상한 %d) · 재질 %s"):format(count, D.maxParts, table.concat(parts, " ")))
	end
	player:SetAttribute("BevelSkinned", count)
end)

-- Studio 전후 캡처: LocalPlayer Attribute BevelSkinOff = true면 옛 모습(원래 파트 보임 · 베벨 숨김) · false면 다시
if RunService:IsStudio() then
	player:GetAttributeChangedSignal("BevelSkinOff"):Connect(function()
		local off = player:GetAttribute("BevelSkinOff") == true
		for part, m in pairs(skinned) do
			part.LocalTransparencyModifier = off and 0 or 1
			m.Transparency = off and 1 or 0
		end
	end)
end
