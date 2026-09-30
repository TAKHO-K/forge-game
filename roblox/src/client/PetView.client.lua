-- QUEUE-10h Q11 펫 모습(모든 클라가 각자 그린다 - 서버는 Attribute PetBody · PetZone · PetGrade만 준다 · 위치 전송 없음).
--   몸 = PetData.rigs(파트 ≤ 8 · 앵커 · 충돌 · 조준 없음) · 색 = 구역 알 색(NestState.zoneColor) · 따라가기 = 주인 뒤 옆으로 보간 · 새끼 용 = 떠서 날갯짓.
--   동작: idle(숨쉬기) · 따라가기(걸을 때 통통) · 날기(용) · 기쁨(내가 아이템을 주우면 한 바퀴 뛰기 - ItemPickedUp).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PetData = require(ReplicatedStorage.Shared.data.PetData)
local EggData = require(ReplicatedStorage.Shared.data.EggData)
local NestState = require(script.Parent.NestState)
local ArtMeshKit = require(ReplicatedStorage.Shared.ArtMeshKit) -- A2-N3 Open Cloud 펫 메시
local ArtImportData = require(ReplicatedStorage.Shared.data.ArtImportData)

local localPlayer = Players.LocalPlayer
for _ = 1, 50 do -- 구역 색은 NestView가 NestState에 붙인다(먼저 돌면 잠깐 기다림)
	if NestState.zoneColor then
		break
	end
	task.wait(0.1)
end
local folder = Instance.new("Folder")
folder.Name = "Pets"
folder.Parent = workspace

local pets = {} -- [Player] = { model, body, key, pos, yaw, joyUntil, parts }
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function build(player)
	local bodyId = player:GetAttribute("PetBody")
	local zone = player:GetAttribute("PetZone")
	local rig = bodyId and PetData.rigs[bodyId]
	if not rig then
		return nil
	end
	local base = NestState.zoneColor and NestState.zoneColor(zone) or Color3.new(1, 1, 1)
	local k = EggData.look.patternDarken
	local colors = { base = base, accent = Color3.new(base.R * k, base.G * k, base.B * k), eye = Color3.new(0.08, 0.08, 0.1) }
	local model = Instance.new("Model")
	model.Name = "Pet_" .. player.Name
	local parts = {}
	-- A2-N3 Open Cloud 펫 메시(ArtStyleV1 뒤): 펫 등급 → 외형 등급(ArtImportData.petLookOfGrade) · 파트 색 = 같은 이름 리그 역할(구역 색) · Deco = 메타 대비색
	local look = ArtImportData.petLookOfGrade[player:GetAttribute("PetGrade") or ""] or "normal"
	local mesh = ArtMeshKit.get("pets/" .. bodyId .. "_" .. look)
	if mesh then
		local role = {}
		for _, spec in ipairs(rig) do
			role[spec.name] = spec.color
		end
		for _, src in ipairs(mesh:GetChildren()) do
			if src:IsA("BasePart") then
				local part = src:Clone()
				part.Color = colors[role[src.Name]] or (src.Name == "Deco" and Color3.fromHex(ArtImportData.petDecoColor[bodyId][look] or "#FFFFFF")) or base
				part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
				part.CastShadow = true
				part.Parent = model
				parts[src.Name] = { part = part, offset = CFrame.new(src.Position) }
			end
		end
		local gp = look == "rare" and ArtImportData.petGlowPoint[bodyId]
		if gp and parts.Body then
			local at = Instance.new("Attachment")
			at.Position = parts.Body.part.CFrame:PointToObjectSpace(Vector3.new(gp[1], gp[2], gp[3]))
			at.Parent = parts.Body.part
			local light = Instance.new("PointLight")
			light.Color, light.Brightness, light.Range = base, ArtImportData.petGlow.brightness, ArtImportData.petGlow.range
			light.Parent = at
		end
		rig = {}
	end
	for _, spec in ipairs(rig) do
		local part = Instance.new(spec.wedge and "WedgePart" or "Part")
		part.Name = spec.name
		part.Size = spec.size
		part.Color = colors[spec.color] or base
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
		part.CastShadow = true
		part.Parent = model
		parts[spec.name] = { part = part, offset = CFrame.new(spec.pos) }
	end
	if player:GetAttribute("PetGrade") == "epic" and not mesh then -- 영웅 = 몸에 약한 빛(구분용) · 메시 외형은 희귀 외형 빛(위)
		local light = Instance.new("PointLight")
		light.Color, light.Brightness, light.Range = base, 1, 6
		light.Parent = parts.Body.part
	end
	model.Parent = folder
	return { model = model, parts = parts, key = tostring(bodyId) .. "|" .. tostring(zone) .. "|" .. tostring(player:GetAttribute("PetGrade")) .. "|" .. tostring(mesh ~= nil), body = bodyId, pos = nil, yaw = 0, joyUntil = 0 }
end

local function refresh(player)
	local key = tostring(player:GetAttribute("PetBody")) .. "|" .. tostring(player:GetAttribute("PetZone")) .. "|" .. tostring(player:GetAttribute("PetGrade")) .. "|" .. tostring(ArtMeshKit.get("pets/" .. tostring(player:GetAttribute("PetBody")) .. "_normal") ~= nil)
	local cur = pets[player]
	if cur and cur.key == key then
		return
	end
	if cur then
		cur.model:Destroy()
	end
	pets[player] = build(player)
end

local function watch(player)
	for _, attr in ipairs({ "PetBody", "PetZone", "PetGrade" }) do
		player:GetAttributeChangedSignal(attr):Connect(function()
			refresh(player)
		end)
	end
	refresh(player)
end

for _, p in ipairs(Players:GetPlayers()) do
	watch(p)
end
Players.PlayerAdded:Connect(watch)
local function refreshAll()
	for player in pairs(pets) do
		refresh(player)
	end
end
task.spawn(function() -- A2-N3: 메시 캐시가 차거나 스위치가 바뀌면 다시 짓는다
	local cache = ReplicatedStorage:WaitForChild(ArtImportData.cacheFolder, 120)
	if cache then
		cache:GetAttributeChangedSignal(ArtImportData.readyAttribute):Connect(refreshAll)
		refreshAll()
	end
end)
workspace:GetAttributeChangedSignal("ArtStyleV1"):Connect(refreshAll)
Players.PlayerRemoving:Connect(function(player)
	if pets[player] then
		pets[player].model:Destroy()
		pets[player] = nil
	end
end)

-- 기쁨: 내가 아이템을 주웠다(서버 ItemPickedUp - 줍기 연출과 같은 신호)
local picked = ReplicatedStorage:WaitForChild("ItemPickedUp", 10)
if picked then
	picked.OnClientEvent:Connect(function()
		if pets[localPlayer] then
			pets[localPlayer].joyUntil = os.clock() + 0.6
		end
	end)
end

local F = PetData.follow
RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	for player, pet in pairs(pets) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root then
			pet.model.Parent = nil
			continue
		end
		pet.model.Parent = folder
		local flying = PetData.flyingBodies[pet.body] == true
		local target = (root.CFrame * CFrame.new(F.offset)).Position
		rayParams.FilterDescendantsInstances = { folder, player.Character }
		local hit = workspace:Raycast(target + Vector3.new(0, 4, 0), Vector3.new(0, -14, 0), rayParams)
		local groundY = hit and hit.Position.Y or (root.Position.Y - 3)
		local y = groundY + 0.45 + (flying and (F.flyHeight + math.sin(now * 2 * math.pi / F.bobSeconds) * F.bobStuds) or 0)
		target = Vector3.new(target.X, y, target.Z)
		if not pet.pos or (pet.pos - target).Magnitude > F.teleportStuds then
			pet.pos = target
		end
		local prev = pet.pos
		pet.pos = pet.pos:Lerp(target, 1 - math.exp(-F.lerpPerSecond * dt))
		local move = Vector3.new(pet.pos.X - prev.X, 0, pet.pos.Z - prev.Z)
		if move.Magnitude > 0.01 then
			pet.yaw = math.atan2(-move.X, -move.Z)
		end
		local hop = 0
		local spin = 0
		if not flying and move.Magnitude / math.max(dt, 1e-3) > 1 then
			hop = math.abs(math.sin(now * 12)) * 0.18 -- 걸을 때 통통
		end
		if now < pet.joyUntil then
			local t = 1 - (pet.joyUntil - now) / 0.6
			hop += math.sin(t * math.pi) * 0.8
			spin = t * 2 * math.pi
		end
		local breathe = 1 + math.sin(now * 2) * 0.02
		local cf = CFrame.new(pet.pos + Vector3.new(0, hop, 0)) * CFrame.Angles(0, pet.yaw + spin, 0)
		for name, p in pairs(pet.parts) do
			local offset = p.offset
			if name == "Wing_L" or name == "Wing_R" then
				local flap = math.sin(now * 10) * 0.5 * (name == "Wing_L" and 1 or -1)
				offset = offset * CFrame.Angles(0, 0, flap)
			elseif name == "Head" then -- 숨쉬기 = 머리만 살짝(크기 변경 없이)
				offset = offset * CFrame.new(0, (breathe - 1) * 2, 0)
			end
			p.part.CFrame = cf * offset
		end
	end
end)
