-- A2-M1 보스 아레나 꾸미기(클라 전용 · ArtStyleV1 스위치 뒤 · 판정 · 충돌 · 조준 무관 - 데이터 shared/data/BossArenaDressData).
-- 내가 보스전에 들어가면(LocalPlayer BossEncounterId) 그 보스의 아레나(가장 가까운 BossArenaFloor)에 플레이 영역 밖 장식 · 떠다니는 룬석 · 떠오르는 빛 · 바닥 재질 · 가장자리 선 · 대기를 얹고,
-- 나오면 전부 치우고 되돌린다. 파트는 전부 Anchored · CanCollide · CanQuery · CanTouch 끔(서버 판정 · 레이캐스트에 안 걸린다) · 폰은 개수를 줄인다(BossArenaDressData.phone).
-- 반복 장식(수정 무리 · 기둥 · 룬석)은 나중에 Blender 메시로 바꿀 자리(이름 = Dress_<종류>_<번호>).
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local BossArenaDressData = require(ReplicatedStorage.Shared.data.BossArenaDressData)
local BossRigSpec = require(ReplicatedStorage.Shared.data.BossRigSpec)
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossFx = require(script.Parent.BossFx)

local player = Players.LocalPlayer
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local current = nil -- { folder, floats = {}, floor, floorWas = { material, color }, atmoWas, center, top, spec, colors, moteAt, phone }

local function isPhone()
	local cam = Workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
	return (UserInputService.TouchEnabled and math.min(vp.X, vp.Y) < 500) or Players.LocalPlayer:GetAttribute("A2M1ForcePhone") == true -- 측정용 강제(Studio)
end

local function bossOf(encounterId)
	for _, m in ipairs(CollectionService:GetTagged("Monster")) do
		if m:GetAttribute("BossEncounterId") == encounterId and m:GetAttribute("BossRig") then
			return m
		end
	end
	return nil
end

local function floorNear(pos)
	local best, bestD = nil, math.huge
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "BossArenaFloor" then
			local dist = (Vector3.new(d.Position.X, 0, d.Position.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
			if dist < bestD then
				best, bestD = d, dist
			end
		end
	end
	return best
end

local function colorOf(role, C)
	if typeof(role) == "Color3" then
		return role
	end
	return C[role] or C.accent
end

local function newPart(parent, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.CastShadow = size.Magnitude > 6
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape == "cyl" then
		p.Shape = Enum.PartType.Cylinder
	end
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function clear()
	if not current then
		return
	end
	local c = current
	current = nil
	c.folder:Destroy()
	if c.floor and c.floorWas then
		c.floor.Material, c.floor.Color = c.floorWas.material, c.floorWas.color
	end
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmo and c.atmoWas then
		atmo.Density, atmo.Color, atmo.Decay, atmo.Haze = c.atmoWas.density, c.atmoWas.color, c.atmoWas.decay, c.atmoWas.haze
	end
end

local function dress(boss)
	clear()
	local rigId = boss:GetAttribute("BossRig")
	local spec = BossArenaDressData.bosses[rigId or ""]
	local root = boss:FindFirstChild("HumanoidRootPart")
	if not spec or not root or Workspace:GetAttribute("ArtStyleV1") ~= true then
		return
	end
	local floor = floorNear(root.Position)
	if not floor then
		return
	end
	local phone = isPhone()
	local countK = phone and BossArenaDressData.phone.countScale or 1
	local center = Vector3.new(floor.Position.X, floor.Position.Y + floor.Size.Y / 2, floor.Position.Z)
	local rig = BossRigSpec.rigs[rigId]
	local theme = rig and rig.themeColors or {}
	local data = BossData.bosses[rigId]
	local accent = theme.accent or (rig and rig.accent) or WHITE
	local C = {
		accent = accent, light = accent:Lerp(WHITE, 0.45), head = theme.head or data.headColor, body = theme.body or data.bodyColor,
		floor = floor.Color, stone = floor.Color:Lerp(BLACK, 0.25):Lerp(theme.body or data.bodyColor, 0.25),
	}
	local folder = Instance.new("Folder")
	folder.Name = "BossArenaDress"
	folder.Parent = Workspace
	current = { folder = folder, floats = {}, center = center, spec = spec, colors = C, phone = phone, moteAt = 0 }
	local rng = Random.new(tonumber(rigId:len()) * 7919 + 13) -- 보스마다 같은 배치(결정적)

	-- 떠다니는 룬석
	local F = spec.floatStones
	if F then
		for i = 1, math.floor(F.count * countK + 0.5) do
			local a = (i / F.count) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
			local r = rng:NextNumber(F.radius[1], F.radius[2])
			local h = rng:NextNumber(F.height[1], F.height[2])
			local s = F.size * rng:NextNumber(0.7, 1.25)
			local base = center + Vector3.new(math.cos(a) * r, h, math.sin(a) * r)
			local model = Instance.new("Model")
			model.Name = "Dress_FloatStone_" .. i
			local stone = newPart(model, "Stone", s, CFrame.new(base), colorOf(F.color, C), Enum.Material.Slate)
			local inlay = newPart(model, "Inlay", Vector3.new(s.X * 0.7, s.Y * 0.08, s.Z * 1.02), CFrame.new(base + Vector3.new(0, s.Y * 0.12, 0)), colorOf(F.inlay, C), Enum.Material.Neon)
			model.PrimaryPart = stone
			model.Parent = folder
			table.insert(current.floats, { model = model, base = base, phase = rng:NextNumber(0, 6.28), yaw = rng:NextNumber(0, 6.28), tilt = rng:NextNumber(-0.25, 0.25), inlayOffset = s.Y * 0.12, inlay = inlay, stone = stone })
		end
	end
	-- 테라스 결정 무리
	local K = spec.clusters
	if K then
		for i = 1, math.floor(K.count * countK + 0.5) do
			local a = (i / K.count) * math.pi * 2 + rng:NextNumber(-0.25, 0.25)
			local r = rng:NextNumber(K.radius[1], K.radius[2])
			local base = center + Vector3.new(math.cos(a) * r, -1.5, math.sin(a) * r)
			for j = 1, rng:NextInteger(K.shards[1], K.shards[2]) do
				local s = K.size * (j == 1 and 1 or rng:NextNumber(0.45, 0.75))
				local off = j == 1 and Vector3.zero or Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
				local cf = CFrame.new(base + off + Vector3.new(0, s.Y * 0.4, 0)) * CFrame.Angles(rng:NextNumber(-0.35, 0.35), rng:NextNumber(0, 6.28), rng:NextNumber(-0.35, 0.35)) * CFrame.Angles(0, math.rad(45), 0)
				local p = newPart(folder, ("Dress_Cluster_%d_%d"):format(i, j), s, cf, colorOf(K.color, C), K.material)
				p.Transparency = K.material == Enum.Material.Glass and 0.15 or 0
			end
		end
	end
	-- 먼 기둥(폐허)
	local P = spec.pillars
	if P then
		for i = 1, math.floor(P.count * countK + 0.5) do
			local a = (i / P.count) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
			local r = rng:NextNumber(P.radius[1], P.radius[2])
			local h = rng:NextNumber(P.height[1], P.height[2])
			local base = center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			newPart(folder, "Dress_Pillar_" .. i, Vector3.new(P.width, h, P.width), CFrame.new(base + Vector3.new(0, h / 2 - 4, 0)) * CFrame.Angles(0, a, 0), colorOf(P.color, C), Enum.Material.Slate)
			newPart(folder, "Dress_PillarCap_" .. i, Vector3.new(P.width * 1.35, P.width * 0.35, P.width * 1.35), CFrame.new(base + Vector3.new(0, h - 4 + P.width * 0.17, 0)) * CFrame.Angles(0, a, 0), colorOf(P.color, C):Lerp(WHITE, 0.08), Enum.Material.Slate)
			if P.broken then
				local topH = h * rng:NextNumber(0.2, 0.35)
				newPart(folder, "Dress_PillarBroken_" .. i, Vector3.new(P.width * 0.9, topH, P.width * 0.9),
					CFrame.new(base + Vector3.new(P.width * 0.6, h - 4 + P.width * 0.35 + topH / 2 - 1, 0)) * CFrame.Angles(0, a, math.rad(rng:NextNumber(18, 32))), colorOf(P.color, C), Enum.Material.Slate)
			end
		end
	end
	-- 바닥 가장자리 선(벽 안쪽 · 바닥 위 얇은 고리 = 24조각)
	local E = spec.edge
	if E then
		local R = BossArenaDressData.playRadius - 1.5
		local n = 48
		for i = 1, n do
			local a0, a1 = (i - 1) / n * math.pi * 2, i / n * math.pi * 2
			local p0 = center + Vector3.new(math.cos(a0) * R, 0.06, math.sin(a0) * R)
			local p1 = center + Vector3.new(math.cos(a1) * R, 0.06, math.sin(a1) * R)
			local p = newPart(folder, "Dress_Edge_" .. i, Vector3.new(E.width, 0.1, (p1 - p0).Magnitude + 0.2), CFrame.lookAt((p0 + p1) / 2, p1), colorOf(E.color, C), Enum.Material.Neon)
			p.Transparency = E.transparency
		end
	end
	-- 바닥 재질(이 클라만)
	local FL = spec.floor
	if FL then
		current.floor = floor
		current.floorWas = { material = floor.Material, color = floor.Color }
		floor.Material = FL.material
		floor.Color = floor.Color:Lerp(colorOf(FL.tint, C), FL.amount)
	end
	-- 대기(이 클라만 - 끝나면 되돌림)
	local A = spec.atmosphere
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if A and atmo then
		current.atmoWas = { density = atmo.Density, color = atmo.Color, decay = atmo.Decay, haze = atmo.Haze }
		atmo.Density = A.density
		atmo.Color = colorOf(A.color, C):Lerp(WHITE, 0.55)
		atmo.Decay = colorOf(A.decay, C):Lerp(BLACK, 0.2)
		atmo.Haze = A.haze
	end
	print(("[A2M1Dress] %s · 파트 %d · 폰 %s"):format(rigId, #folder:GetDescendants(), tostring(phone)))
end

-- 매 프레임: 떠다니는 룬석 · 떠오르는 빛
RunService.RenderStepped:Connect(function()
	local c = current
	if not c then
		return
	end
	local now = os.clock()
	local F = c.spec.floatStones
	for _, f in ipairs(c.floats) do
		local y = math.sin(now * 0.8 + f.phase) * (F and F.bob or 1)
		local yaw = f.yaw + math.rad((F and F.spin or 5) * now)
		local cf = CFrame.new(f.base + Vector3.new(0, y, 0)) * CFrame.Angles(f.tilt, yaw, f.tilt * 0.5)
		f.stone.CFrame = cf
		f.inlay.CFrame = cf * CFrame.new(0, f.inlayOffset, 0)
	end
	local M = c.spec.motes
	if M and now - c.moteAt > M.every / (c.phone and (M.phoneScale or 0.5) or 1) then
		c.moteAt = now
		local a, r = math.random() * math.pi * 2, math.sqrt(math.random()) * (BossArenaDressData.playRadius - 4)
		local at = c.center + Vector3.new(math.cos(a) * r, 0.5, math.sin(a) * r)
		BossFx.spawn({ shape = "ball", position = at, velocity = Vector3.new(0, M.rise / M.life, 0), size0 = Vector3.one * M.size, size1 = Vector3.one * M.size * 0.3,
			color = colorOf(M.color, c.colors), transparency0 = 0.35, transparency1 = 1, life = M.life, material = Enum.Material.Neon })
	end
end)

local token = 0
local function onEncounter()
	token += 1
	local my = token
	local id = player:GetAttribute("BossEncounterId")
	if not id then
		clear()
		return
	end
	task.spawn(function()
		for _ = 1, 20 do -- 보스 모델 복제를 기다린다
			if my ~= token then
				return
			end
			local boss = bossOf(id)
			if boss then
				dress(boss)
				return
			end
			task.wait(0.25)
		end
	end)
end
player:GetAttributeChangedSignal("BossEncounterId"):Connect(onEncounter)
onEncounter()
