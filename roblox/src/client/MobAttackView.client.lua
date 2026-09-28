-- Q1 잡몹 모양 공격 예고 · 동작 연출(그리기만 - 판정은 서버 MonsterAI · 모양 = shared/MobAttackShape와 같은 값).
--   서버 Attribute: MobAttack = "id|전조 초|시각"(전조 시작 - 바닥 예고가 전조 동안 차오른다 · 서리 숨결은 몹 발밑에서 앞으로 번지는 서리 궤적)
--   · MobStrike = "id|시각"(동작 - 예고 자리가 번쩍 · 돌풍은 퍼지는 고리) · MobAttack이 nil이 되고 MobStrike가 없으면(추격 끝) 예고만 지운다.
--   새 에셋 · 파티클 · 색 없음: 판 파트(Neon) + UIColors.stealShield(서리) · 종 accent.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local MonsterSpeciesData = require(ReplicatedStorage.Shared.data.MonsterSpeciesData)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)

local FROST = UIColors.stealShield
local LOD_STUDS = 220 -- 이보다 멀면 그리지 않는다(먼 몹)
local FAN_SLICES = 7
local STRIKE_SECONDS = 0.45

local shown = {} -- [model] = { folder, parts, started, seconds, attack }

local function attackOf(model, id)
	local def = MonsterSpeciesData.species[model:GetAttribute("MonsterRig") or ""]
	for _, attack in ipairs(def and def.attacks or {}) do
		if attack.id == id then
			return attack, def
		end
	end
	return nil
end

local function groundY(model, root)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model, Players.LocalPlayer.Character }
	local hit = Workspace:Raycast(root.Position, Vector3.new(0, -40, 0), params)
	return hit and hit.Position.Y or (root.Position.Y - 2.5)
end

local function slab(folder, size, cframe, color)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.CFrame = cframe
	p.Transparency = 1
	p.Parent = folder
	return p
end

-- 예고 모양(바닥 판): 부채꼴 · 뒤 반원 = 판 조각 여러 장 · 원 = 납작한 원기둥
local function buildShape(folder, attack, origin, facing, color)
	local parts = {}
	local y = origin.Y + 0.08
	local base = Vector3.new(origin.X, y, origin.Z)
	if attack.shape == "circle" then
		local disc = slab(folder, Vector3.new(0.12, attack.range * 2, attack.range * 2), CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90)), color)
		disc.Shape = Enum.PartType.Cylinder
		table.insert(parts, disc)
		return parts
	end
	local yaw = math.atan2(-facing.X, -facing.Z) -- CFrame 앞(−Z)이 facing이 되는 각
	local from, to
	if attack.shape == "cone" then
		from, to = -(attack.halfAngle or 35), attack.halfAngle or 35
	else -- rearArc: 등 뒤 반원(옆 90°까지)
		from, to = 90, 270
	end
	local slices = attack.shape == "cone" and FAN_SLICES or FAN_SLICES + 2
	local step = (to - from) / slices
	local width = 2 * attack.range * math.tan(math.rad(step / 2)) + 0.3
	for i = 0, slices - 1 do
		local a = math.rad(from + step * (i + 0.5))
		local cf = CFrame.new(base) * CFrame.Angles(0, yaw + a, 0) * CFrame.new(0, 0, -attack.range / 2)
		table.insert(parts, slab(folder, Vector3.new(width, 0.12, attack.range), cf, color))
	end
	return parts
end

local function clear(model)
	local st = shown[model]
	if st then
		st.folder:Destroy()
		shown[model] = nil
	end
end

local function onAttack(model)
	local tag = model:GetAttribute("MobAttack")
	if not tag then
		local st = shown[model]
		task.delay(0.15, function() -- 전조 중 추격 끝 = 예고만 지운다(동작이면 MobStrike가 먼저 와서 striking)
			if shown[model] == st and st and not st.striking then
				clear(model)
			end
		end)
		return
	end
	local id, seconds = string.match(tag, "^([^|]+)|([%d%.]+)")
	local attack = id and attackOf(model, id)
	local root = model.PrimaryPart
	local camera = Workspace.CurrentCamera
	if not (attack and root and camera) or (root.Position - camera.CFrame.Position).Magnitude > LOD_STUDS then
		return
	end
	clear(model)
	local folder = Instance.new("Folder")
	folder.Name = "MobAttackTelegraph"
	folder.Parent = Workspace
	local facing = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	local origin = Vector3.new(root.Position.X, groundY(model, root), root.Position.Z)
	shown[model] = { folder = folder, parts = buildShape(folder, attack, origin, facing, FROST), started = os.clock(), seconds = tonumber(seconds) or 0.8, attack = attack }
end

local function onStrike(model)
	local tag = model:GetAttribute("MobStrike")
	local st = shown[model]
	if not (tag and st) then
		return
	end
	local def = MonsterSpeciesData.species[model:GetAttribute("MonsterRig") or ""]
	st.striking = os.clock()
	for _, p in ipairs(st.parts) do
		p.Color = def and def.accent or FROST
		p.Transparency = 0.25
	end
end

local function watch(model)
	if not model:IsA("Model") then
		return
	end
	local def = MonsterSpeciesData.species[model:GetAttribute("MonsterRig") or ""]
	if not (def and def.attacks) then
		return
	end
	model:GetAttributeChangedSignal("MobAttack"):Connect(function()
		onAttack(model)
	end)
	model:GetAttributeChangedSignal("MobStrike"):Connect(function()
		onStrike(model)
	end)
	model.AncestryChanged:Connect(function()
		if not model.Parent then
			clear(model)
		end
	end)
end

for _, model in ipairs(CollectionService:GetTagged("Monster")) do
	watch(model)
end
CollectionService:GetInstanceAddedSignal("Monster"):Connect(watch)

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for model, st in pairs(shown) do
		if st.striking then
			local t = (now - st.striking) / STRIKE_SECONDS
			if t >= 1 then
				clear(model)
			else
				for _, p in ipairs(st.parts) do
					p.Transparency = 0.25 + 0.75 * t
				end
				if st.attack.shape == "circle" and st.parts[1] then -- 돌풍 = 퍼지는 고리
					local r = st.attack.range * (1 + 0.6 * t)
					st.parts[1].Size = Vector3.new(0.12, r * 2, r * 2)
				end
			end
		else
			-- 전조 동안 차오른다(서리 숨결 = 앞으로 번지는 서리 궤적: 가까운 조각부터가 아니라 부채 전체가 발밑에서 앞으로 길어진다)
			local t = math.clamp((now - st.started) / math.max(st.seconds, 0.05), 0, 1)
			for _, p in ipairs(st.parts) do
				p.Transparency = 0.85 - 0.4 * t
			end
			if st.attack.shape == "cone" then
				for _, p in ipairs(st.parts) do
					local full = st.attack.range
					local len = math.max(full * t, 0.5)
					local back = p:GetAttribute("FullCFrame") or p.CFrame
					if not p:GetAttribute("FullCFrame") then
						p:SetAttribute("FullCFrame", back)
					end
					p.Size = Vector3.new(p.Size.X, p.Size.Y, len)
					p.CFrame = back * CFrame.new(0, 0, (full - len) / 2)
				end
			end
		end
	end
end)
