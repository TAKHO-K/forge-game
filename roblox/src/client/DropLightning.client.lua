-- D1(사용자 결정 · 디아블로4식) 땅 드랍 번개: 불규칙한 번개가 장비에 계속 내리꽂힌다(영웅부터 · 높이 = 등급 단계 · 색 = 땅 드랍 색 - 낮은 등급일수록 회색 쪽).
-- 서버 ItemDropSpawner가 드랍 모델에 DropGrade · BoltHeight · BoltGround Attribute를 둔다 - 여기서는 그리기만(클라 전용 파트 · 파티클 없음 · 파트 + 투명도).
-- 모양: 옅은 곧은 심지(멀리서 등급 읽기) + 지그재그 본선 + 짧은 가지 1 → restrike 간격(무작위)마다 꺾임을 새로 뽑고 번쩍였다 흐려진다. 멀면(bolt.maxDistance) 안 그린다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PrimordialData = require(ReplicatedStorage.Shared.data.PrimordialData)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)

local BOLT = PrimordialData.bolt
local rng = Random.new()
local bolts = {} -- [model] = { folder, core, segments = {}, branch = {}, nextAt, flashAt, ground, height, color }

local function dropColor(gradeId)
	if gradeId == "primordial" then
		return PrimordialData.auraColor
	end
	local visual = ItemVisualData.gradeVisuals[gradeId]
	local look = PrimordialData.dropLook[gradeId]
	return (visual and visual.color or PrimordialData.dropGray):Lerp(PrimordialData.dropGray, look and look.desaturate or 0)
end

local function newPart(parent, name, color)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = Vector3.new(BOLT.width, BOLT.width, 1)
	part.Parent = parent
	return part
end

-- a → b 사이를 잇는 막대(길이 방향 = Z)
local function place(part, a, b, width)
	local length = (b - a).Magnitude
	part.Size = Vector3.new(width, width, math.max(length, 0.05))
	part.CFrame = CFrame.lookAt((a + b) / 2, b)
end

local function strike(bolt)
	local top = bolt.ground + Vector3.new(0, bolt.height, 0)
	local count = #bolt.segments
	local points = { top }
	for i = 1, count - 1 do
		local t = i / count
		local jitter = BOLT.jitter * (1 - t * 0.6) -- 아래(장비 쪽)로 갈수록 가운데로 모인다
		table.insert(points, bolt.ground + Vector3.new(rng:NextNumber(-jitter, jitter), bolt.height * (1 - t), rng:NextNumber(-jitter, jitter)))
	end
	table.insert(points, bolt.ground + Vector3.new(0, 1.2, 0))
	for i, part in ipairs(bolt.segments) do
		place(part, points[i], points[i + 1], BOLT.width * (i == count and 1.6 or 1))
	end
	-- 가지: 본선 위쪽 1/3 어딘가에서 옆으로 짧게
	local from = points[math.max(2, math.floor(count / 3))]
	local dir = Vector3.new(rng:NextNumber(-1, 1), -0.8, rng:NextNumber(-1, 1)).Unit
	local mid = from + dir * bolt.height * 0.12 + Vector3.new(rng:NextNumber(-0.4, 0.4), 0, rng:NextNumber(-0.4, 0.4))
	place(bolt.branch[1], from, mid, BOLT.width * 0.7)
	place(bolt.branch[2], mid, mid + dir * bolt.height * 0.1, BOLT.width * 0.5)
	bolt.flashAt = os.clock()
	bolt.nextAt = os.clock() + rng:NextNumber(BOLT.restrikeMin, BOLT.restrikeMax)
end

local function build(model)
	local height = model:GetAttribute("BoltHeight") or 0
	local ground = model:GetAttribute("BoltGround")
	if height <= 0 or typeof(ground) ~= "Vector3" or bolts[model] then
		return
	end
	local color = dropColor(model:GetAttribute("DropGrade"))
	local folder = Instance.new("Folder")
	folder.Name = "DropLightning"
	folder.Parent = model
	local core = newPart(folder, "Core", color)
	core.Transparency = 0.82
	place(core, ground, ground + Vector3.new(0, height, 0), 0.9)
	local bolt = { folder = folder, core = core, segments = {}, branch = {}, ground = ground, height = height, color = color }
	for i = 1, math.max(4, math.floor(height / BOLT.segmentStuds)) do
		bolt.segments[i] = newPart(folder, "Bolt", color)
	end
	bolt.branch[1] = newPart(folder, "Branch", color)
	bolt.branch[2] = newPart(folder, "Branch", color)
	bolts[model] = bolt
	strike(bolt)
	model.Destroying:Connect(function()
		bolts[model] = nil
	end)
end

local function watch(inst)
	if inst:IsA("Model") and inst.Name == "ItemDrop" then
		if inst:GetAttribute("BoltGround") then
			build(inst)
		end
		inst:GetAttributeChangedSignal("BoltGround"):Connect(function()
			build(inst)
		end)
	end
end

Workspace.ChildAdded:Connect(watch)
for _, child in ipairs(Workspace:GetChildren()) do
	watch(child)
end

local player = Players.LocalPlayer
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local camera = Workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position
	for model, bolt in pairs(bolts) do
		if not model.Parent then
			bolts[model] = nil
		else
			local near = eye == nil or (bolt.ground - eye).Magnitude <= BOLT.maxDistance
			bolt.folder.Parent = near and model or nil
			if near then
				if now >= bolt.nextAt then
					strike(bolt)
				end
				-- 번쩍(0) → 흐려짐(0.75) - 다음 번개까지
				local fade = math.clamp((now - bolt.flashAt) / 0.18, 0, 1)
				local transparency = 0.05 + 0.7 * fade
				for _, part in ipairs(bolt.segments) do
					part.Transparency = transparency
				end
				bolt.branch[1].Transparency = math.min(1, transparency + 0.15)
				bolt.branch[2].Transparency = math.min(1, transparency + 0.25)
			end
		end
	end
	local _ = player
end)
