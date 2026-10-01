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
local ARENA_GEOMETRY = require(ReplicatedStorage.Shared.data.BossArenaMapData).geometry
local BossRigSpec = require(ReplicatedStorage.Shared.data.BossRigSpec)
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossFx = require(script.Parent.BossFx)
local ArtMeshKit = require(ReplicatedStorage.Shared.ArtMeshKit)

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
	for _, cn in ipairs(c.connections or {}) do
		cn:Disconnect()
	end
	for _, p in ipairs(c.localHidden or {}) do
		p.LocalTransparencyModifier = 0
	end
	c.folder:Destroy()
	-- A2-N4: 서버가 그새 바닥을 다시 칠했으면(같은 슬롯에 다음 보스 테마) 되돌리지 않는다 - 옛 = 이전 보스 색으로 덮어 전갈 모래 바닥이 남색이 됐다
	if c.floor and c.floorWas and c.floor.Color == c.floorSet.color and c.floor.Material == c.floorSet.material then
		c.floor.Material, c.floor.Color = c.floorWas.material, c.floorWas.color
	end
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmo and c.atmoWas then
		atmo.Density, atmo.Color, atmo.Decay, atmo.Haze = c.atmoWas.density, c.atmoWas.color, c.atmoWas.decay, c.atmoWas.haze
	end
	if c.clockWas then
		Lighting.ClockTime = c.clockWas
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
	-- 바닥 윗면 = 발밑 광선(아레나 바닥은 눕힌 원기둥이라 Size.Y가 두께가 아니다 - Play 3에서 140 stud 위로 계산됐다)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { floor }
	local hit = Workspace:Raycast(Vector3.new(floor.Position.X, root.Position.Y + 20, floor.Position.Z), Vector3.new(0, -80, 0), params)
	local topY = hit and hit.Position.Y or (root.Position.Y - 1.5)
	local center = Vector3.new(floor.Position.X, topY, floor.Position.Z)
	local rig = BossRigSpec.rigs[rigId]
	local theme = rig and rig.themeColors or {}
	local data = BossData.bosses[rigId]
	local accent = theme.accent or (rig and rig.accent) or WHITE
	local C = {
		accent = accent, light = accent:Lerp(WHITE, 0.45), head = theme.head or data.headColor, body = theme.body or data.bodyColor,
		floor = floor.Color, stone = floor.Color:Lerp(BLACK, 0.25):Lerp(theme.body or data.bodyColor, 0.25),
		pillar = floor.Color:Lerp(WHITE, 0.3):Lerp(theme.head or data.headColor, 0.2),
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
			local stone = newPart(model, "Stone", s, CFrame.new(base), colorOf(F.color, C), F.material or Enum.Material.Slate)
			if F.material == Enum.Material.Glass then
				stone.Transparency = 0.15
			end
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
				if K.tip then -- 끝 빛(피뢰 가시)
					newPart(folder, ("Dress_ClusterTip_%d_%d"):format(i, j), Vector3.new(s.X * 1.4, s.X * 1.4, s.X * 1.4), cf * CFrame.new(0, s.Y / 2, 0), colorOf(K.tip, C), Enum.Material.Neon)
				end
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
			local pm = P.material or Enum.Material.Slate
			local pillar = newPart(folder, "Dress_Pillar_" .. i, Vector3.new(P.width, h, P.width), CFrame.new(base + Vector3.new(0, h / 2 - 4, 0)) * CFrame.Angles(0, a, 0), colorOf(P.color, C), pm)
			pillar.Transparency = pm == Enum.Material.Glass and 0.2 or 0
			newPart(folder, "Dress_PillarCap_" .. i, Vector3.new(P.width * 1.35, P.width * 0.35, P.width * 1.35), CFrame.new(base + Vector3.new(0, h - 4 + P.width * 0.17, 0)) * CFrame.Angles(0, a, 0), colorOf(P.color, C):Lerp(WHITE, 0.08), pm)
			if P.broken then
				local topH = h * rng:NextNumber(0.2, 0.35)
				newPart(folder, "Dress_PillarBroken_" .. i, Vector3.new(P.width * 0.9, topH, P.width * 0.9),
					CFrame.new(base + Vector3.new(P.width * 0.6, h - 4 + P.width * 0.35 + topH / 2 - 1, 0)) * CFrame.Angles(0, a, math.rad(rng:NextNumber(18, 32))), colorOf(P.color, C), Enum.Material.Slate)
			end
		end
	end
	-- A2-N4 P0-5 배경 링(아레나 밖 사냥터 · 이웃 아레나 가림 - 층마다 한 바퀴 · 폰도 개수 그대로(틈이 생기면 안 된다) · 그림자 끔)
	local fogColor = spec.atmosphere and colorOf(spec.atmosphere.color, C):Lerp(WHITE, 0.55) or C.light
	for li, L in ipairs(spec.backdrop or {}) do
		for i = 1, L.count do
			local a = (i / L.count) * math.pi * 2 + rng:NextNumber(-0.12, 0.12)
			local r = rng:NextNumber(L.radius[1], L.radius[2])
			local h = rng:NextNumber(L.height[1], L.height[2])
			local d = Vector3.new(math.cos(a), 0, math.sin(a))
			local base = center + d * r + Vector3.new(0, L.lift or 0, 0)
			local face = CFrame.lookAt(base, base - d) -- 앞면이 아레나 쪽
			local color = colorOf(L.color, C):Lerp(fogColor, L.fog or 0)
			local name = ("Dress_Backdrop_%d_%d"):format(li, i)
			local part
			if L.shape == "peak" then -- 45° 돌린 상자의 윗반 = 산 삼각(높이 h · 밑변 2h)
				local side = h * math.sqrt(2)
				part = newPart(folder, name, Vector3.new(side, side, h * 0.5), face * CFrame.Angles(0, 0, math.rad(45)), color, L.material)
			elseif L.shape == "dome" then
				part = newPart(folder, name, Vector3.one * h * 2, CFrame.new(base), color, L.material)
				part.Shape = Enum.PartType.Ball
			elseif L.shape == "spire" then
				local w = (L.width or 16) * rng:NextNumber(0.75, 1.25)
				part = newPart(folder, name, Vector3.new(w, h, w), face * CFrame.new(0, h / 2 - 6, 0), color, L.material)
				local cap = newPart(folder, name .. "_Top", Vector3.new(w * 0.72, w * 0.72, w * 0.72), face * CFrame.new(0, h - 6, 0) * CFrame.Angles(0, 0, math.rad(45)) * CFrame.Angles(math.rad(45), 0, 0), color, L.material)
				cap.CastShadow = false
			else -- cliff
				local w = (L.width or 50) * rng:NextNumber(0.8, 1.2)
				part = newPart(folder, name, Vector3.new(w, h, w * 0.5), face * CFrame.new(0, h / 2 - 6, 0), color, L.material)
				local top = Instance.new("WedgePart")
				top.Name = name .. "_Top"
				top.Anchored, top.CanCollide, top.CanQuery, top.CanTouch, top.CastShadow = true, false, false, false, false
				top.Size = Vector3.new(w, h * 0.22, w * 0.5)
				top.CFrame = face * CFrame.new(0, h - 6 + h * 0.11, 0)
				top.Color, top.Material = color, L.material or Enum.Material.Slate
				top.Parent = folder
			end
			part.CastShadow = false
			if L.material == Enum.Material.Glass then
				part.Transparency = 0.1
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
	-- QUEUE-ALL1 바닥 v2 가장자리(docs/design/v2/03 4 · 5절): 벽 밑 낮은 턱 · 벽 모서리 부서진 기둥 · 벽 위 화로(테마 불빛) · 가운데 조명. 플레이 영역 안에는 낮은 턱만(판정 · 전조 안 가림).
	local RS = spec.rim
	if RS then
		local R = BossArenaDressData.rim
		local G = ARENA_GEOMETRY
		local seg = G.wallSegments
		local half = math.pi / seg
		local apothem = G.radiusStuds / math.cos(half) -- 벽 안쪽 면까지(서버 BossArenaMap.buildBase와 같은 식)
		local wallMid = apothem + G.wallThicknessStuds / 2
		local wallTop = center.Y + G.wallHeightStuds
		local mat = RS.material or Enum.Material.Slate
		local function dir(a)
			return Vector3.new(math.cos(a), 0, math.sin(a))
		end
		-- 턱: 벽 면마다 1조각(벽과 같은 각) · 붕괴 조각이 무너지면 그 조각 위 턱도 숨긴다(current.curbs - 아래 bindSliceFloor)
		current.curbs = {}
		for i = 1, seg do
			local a = (i - 0.5) * 2 * half
			local at = center + dir(a) * (apothem - R.curbWidth / 2 + 0.1) + Vector3.new(0, (R.curbHeight - 0.2) / 2, 0)
			local p = newPart(folder, "Dress_RimCurb_" .. i, Vector3.new(2 * apothem * math.tan(half) + 0.3, R.curbHeight + 0.2, R.curbWidth + 0.2),
				CFrame.lookAt(at, Vector3.new(center.X, at.Y, center.Z)), colorOf(RS.curbColor, C), mat)
			p.CastShadow = false
			table.insert(current.curbs, { part = p, deg = math.deg(a) })
		end
		-- 부서진 기둥(벽 모서리에 박힘) + 테라스에 쓰러진 윗동
		local nPillar = RS.pillars or R.pillars
		for i = 1, nPillar do
			local a = math.floor((i - 0.5) * seg / nPillar + 0.5) * 2 * half -- 벽 모서리 각
			local h = rng:NextNumber(R.pillarHeight[1], R.pillarHeight[2])
			local w = R.pillarWidth
			local base = center + dir(a) * wallMid
			local color = colorOf(RS.pillarColor, C)
			newPart(folder, "Dress_RimPillar_" .. i, Vector3.new(w, h, w), CFrame.new(base + Vector3.new(0, h / 2 - 0.5, 0)) * CFrame.Angles(0, -a + math.rad(rng:NextNumber(-8, 8)), 0), color, mat).CastShadow = false
			local fallen = center + dir(a + math.rad(rng:NextNumber(-3, 3))) * (wallMid + R.fallenOut) + Vector3.new(0, -G.rimDropStuds + w * 0.4, 0)
			newPart(folder, "Dress_RimPillarFallen_" .. i, Vector3.new(w * 0.9, w * 1.8, w * 0.9),
				CFrame.new(fallen) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0) * CFrame.Angles(math.rad(rng:NextNumber(70, 85)), 0, 0), color:Lerp(BLACK, 0.1), mat).CastShadow = false
		end
		-- 화로(벽 면 가운데 위) · 불빛 = 보스 테마 색
		local nFire = RS.braziers or R.braziers
		local lights = not phone or R.phoneLights
		current.fires = {}
		for i = 1, nFire do
			local a = (math.floor((i - 1) * seg / nFire) + 0.5) * 2 * half
			local at = center + dir(a) * wallMid
			local bowl = newPart(folder, "Dress_RimBrazier_" .. i, R.bowlSize, CFrame.new(at.X, wallTop + R.bowlSize.X / 2, at.Z) * CFrame.Angles(0, 0, math.pi / 2), C.stone:Lerp(BLACK, 0.3), Enum.Material.Slate, "cyl")
			bowl.CastShadow = false
			local flame = newPart(folder, "Dress_RimFire_" .. i, Vector3.one * R.flameSize, CFrame.new(at.X, wallTop + R.bowlSize.X + R.flameSize * 0.3, at.Z), RS.fire, Enum.Material.Neon)
			flame.Shape = Enum.PartType.Ball
			flame.Transparency = R.flameTransparency
			flame.CastShadow = false
			if lights then
				local L = Instance.new("PointLight")
				L.Color, L.Brightness, L.Range, L.Shadows = RS.fire, R.fireLight.brightness, R.fireLight.range, false
				L.Parent = flame
				table.insert(current.fires, { light = L, phase = rng:NextNumber(0, 100) })
			end
		end
		-- 가운데 조명(가운데 약간 밝고 가장자리 어둡게)
		if lights then
			local CL = R.centerLight
			local anchor = newPart(folder, "Dress_CenterLight", Vector3.one, CFrame.new(center + Vector3.new(0, CL.height, 0)), WHITE)
			anchor.Transparency, anchor.CastShadow = 1, false
			local L = Instance.new("PointLight")
			L.Color, L.Brightness, L.Range, L.Shadows = CL.color, CL.brightness, CL.range, false
			L.Parent = anchor
		end
	end
	-- 바닥 재질(이 클라만)
	local FL = spec.floor
	if FL then
		current.floor = floor
		current.floorWas = { material = floor.Material, color = floor.Color }
		floor.Material = FL.material
		floor.Color = floor.Color:Lerp(colorOf(FL.tint, C), FL.amount)
		current.floorSet = { material = floor.Material, color = floor.Color }
	end
	-- QUEUE-ALL1 P2 바닥 v2(docs/design/v2/03): 동심원 석판 메시(ArtMeshCache) = 석판 색 · 서버 바닥 = 어둡게(이음매 틈으로 보이는 줄눈) · 판정 · 충돌 = 서버 바닥 그대로.
	--   붕괴 조각 바닥(Ground.BossArenaSliceFloor_<구역>)이 생기면 그 쐐기도 줄눈 색으로 · 조각 k 메시(Slice<k>)의 보임 = 그 조각 쐐기의 보임(무너지면 같이 사라진다).
	local FM = spec.floorMesh
	local src = FM and ArtMeshKit.get(FM.mesh)
	if src and current.floorSet then
		local slab = floor.Color:Lerp(WHITE, FM.slabLighten)
		local grout = floor.Color:Lerp(BLACK, FM.groutDarken or 0.45)
		floor.Color = grout
		current.floorSet.color = grout
		-- Play 실측: 석판(+0.06)과 서버 바닥 윗면이 멀리서 깊이 정밀도 싸움(가운데 반경 25 밖은 바닥만 보였다) → 서버 바닥은 이 클라에서 숨기고 줄눈 = 틈 아래 테라스(−0.5) 그늘
		current.localHidden = current.localHidden or {}
		floor.LocalTransparencyModifier = 1
		table.insert(current.localHidden, floor)
		local m = src:Clone()
		m.Name = "Dress_FloorMesh"
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then
				p.CastShadow = false
				p.Material = FM.material
				p.Color = slab
				if p.Name == "Runes" or p.Name == "Detail" then -- 무늬(룬 · 금 · 물웅덩이 · 결정 맥 · 번개) - 빨강 · 주황 금지(전조 색)
					p.Color = colorOf(FM.runes or FM.detail, C)
					p.Material = FM.detailMaterial or Enum.Material.Neon
					p.Transparency = FM.runeTransparency or FM.detailTransparency or 0
				elseif p.Name == "SlabB" then
					p.Color = slab:Lerp(BLACK, FM.slabBDarken or 0.08) -- 두 번째 톤(판마다 명도 차)
				elseif p.Name == "Grout" then
					p.Color = FM.grout and colorOf(FM.grout, C) or grout
				end
				local k = tonumber(p.Name:match("^Slice(%d+)$"))
				if k then
					p:SetAttribute("SliceIndex", k)
					CollectionService:AddTag(p, "ArtFloorSlice") -- 붕괴 연출(BossEnvironmentView.slabFall)이 이 조각의 사본을 떨어뜨린다
				end
			end
		end
		for _, p in ipairs(m:GetDescendants()) do -- 가로 되돌리기(가져오기 2,048 한도 때문에 1/10로 내보냈다 - make_arena_floor.py XZ_EXPORT)
			if p:IsA("BasePart") then
				local k = FM.scaleXZ
				p.Size = Vector3.new(p.Size.X * k, p.Size.Y, p.Size.Z * k)
				p.CFrame = CFrame.new(p.Position.X * k, p.Position.Y, p.Position.Z * k) * p.CFrame.Rotation
			end
		end
		m:PivotTo(CFrame.new(center))
		m.Parent = folder
		-- 서버 바닥 장식(빛 고리 · 안쪽 원판 · 원판 무늬 - 바닥 +0.04 ~ +0.07 원기둥)이 석판을 덮고 큰 원기둥은 다각형 모서리로 보인다 → 이 클라에서만 숨김(끝나면 되돌림)
		for _, d in ipairs(Workspace:GetChildren()) do
			if d:IsA("Model") and d.Name:find("^BossArenaDressing_") then
				for _, p in ipairs(d:GetDescendants()) do
					if p:IsA("BasePart") and FM.hideDecor[p.Name] and (Vector3.new(p.Position.X, 0, p.Position.Z) - Vector3.new(center.X, 0, center.Z)).Magnitude < 150 then
						p.LocalTransparencyModifier = 1
						table.insert(current.localHidden, p)
					end
				end
			end
		end
		local slices = {}
		for _, p in ipairs(m:GetDescendants()) do
			local k = p:GetAttribute("SliceIndex")
			if k then
				slices[k] = p
			end
		end
		local ground = Workspace:FindFirstChild("Ground")
		-- 조각 바닥 = Ground.BossArenaSliceFloor_<구역>(구역 = 바닥 파트의 부모 BossArenaBase_<구역>) · 쐐기는 늦게 복제될 수 있어 하나씩 묶는다(Play: 첫 전조 순간엔 허브 · 쐐기가 아직 없어 묶기가 빠졌다)
		local function bindSliceFloor(model)
			local at = model:IsA("Model") and model.Name:sub(1, 20) == "BossArenaSliceFloor_" and model:GetAttribute("ArenaCenter")
			if not (typeof(at) == "Vector3" and (Vector3.new(at.X, 0, at.Z) - Vector3.new(center.X, 0, center.Z)).Magnitude < 20) then
				return -- 다른 아레나(서버가 부모 연결 전에 단 ArenaCenter로 고른다 - 바닥 파트 부모는 Ground라 구역 이름이 없다)
			end
			local bound, curbBound = {}, {}
			local function bindPart(w)
				if not w:IsA("BasePart") then
					return
				end
				w.LocalTransparencyModifier = 1 -- 겉모습 = 석판 메시(판정 · 보임 동기 = 서버 Transparency 그대로)
				w.Color = grout
				table.insert(current.localHidden, w)
				local k = w:IsA("WedgePart") and w:GetAttribute("SliceIndex") -- 판정 쐐기만(같은 조각의 고리 호 등 보조 파트는 원래 투명할 수 있다)
				local art = k and slices[k]
				if art and not bound[k] then
					bound[k] = true
					local function sync()
						if art.Parent then
							art.Transparency = w.Transparency > 0.5 and 1 or 0
						end
					end
					table.insert(current.connections, w:GetPropertyChangedSignal("Transparency"):Connect(sync))
					sync()
				end
				if k and current.curbs and not curbBound[k] then -- 가장자리 턱: 무너진 조각 위 턱은 숨긴다(구멍 가독성 - 조각 k = 각 (k − 1) × 폭 ~ k × 폭, 서버 enableSliceFloor와 같은 식)
					curbBound[k] = true
					local width = 360 / (model:GetAttribute("SliceCount") or 8)
					local mine = {}
					for _, cb in ipairs(current.curbs) do
						if math.floor(cb.deg / width) + 1 == k then
							table.insert(mine, cb.part)
						end
					end
					local function syncCurb()
						for _, p in ipairs(mine) do
							p.Transparency = w.Transparency > 0.5 and 1 or 0
						end
					end
					table.insert(current.connections, w:GetPropertyChangedSignal("Transparency"):Connect(syncCurb))
					syncCurb()
				end
			end
			for _, w in ipairs(model:GetChildren()) do
				bindPart(w)
			end
			table.insert(current.connections, model.ChildAdded:Connect(bindPart))
			table.insert(current.connections, model.AncestryChanged:Connect(function()
				if not model.Parent then
					for _, art in pairs(slices) do
						art.Transparency = 0 -- 조각 바닥 → 원판(보스전 끝 · 리셋)
					end
					for _, cb in ipairs(current and current.curbs or {}) do
						cb.part.Transparency = 0
					end
				end
			end))
		end
		current.connections = current.connections or {}
		if ground then
			for _, child in ipairs(ground:GetChildren()) do
				bindSliceFloor(child)
			end
			table.insert(current.connections, ground.ChildAdded:Connect(bindSliceFloor))
		end
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
	-- A2-N4 P0-5 아레나 하늘(이 클라만 - 끝나면 되돌림)
	if spec.sky and spec.sky.clockTime then
		current.clockWas = Lighting.ClockTime
		Lighting.ClockTime = spec.sky.clockTime
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
	local FL = BossArenaDressData.rim.fireLight -- 화로 불빛 흔들림
	for _, fire in ipairs(c.fires or {}) do
		fire.light.Brightness = FL.brightness * (1 + FL.flicker * math.noise(now * 3, fire.phase))
	end
	local M = c.spec.motes
	if M and now - c.moteAt > M.every / (c.phone and (M.phoneScale or 0.5) or 1) then
		c.moteAt = now
		-- 내 둘레(카메라가 보는 곳)에 몰아 뿌린다 - 반경 140 전체에 뿌리면 대부분 화면 밖이다
		local me = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local around = me and Vector3.new(me.Position.X, c.center.Y, me.Position.Z) or c.center
		local a, r = math.random() * math.pi * 2, math.sqrt(math.random()) * 60
		local at = around + Vector3.new(math.cos(a) * r, M.fall and (M.fromHeight or 30) or 0.5, math.sin(a) * r)
		local v = Vector3.new(0, (M.fall and -math.abs(M.rise) or M.rise) / M.life, 0) + (M.wind or Vector3.zero)
		if M.shape == "streak" then
			BossFx.streak(at, v, math.max(v.Magnitude * 0.09, 1.2), M.size, colorOf(M.color, c.colors), M.life, v.Magnitude)
		else
			BossFx.spawn({ shape = M.shape or "ball", position = at, velocity = v, size0 = Vector3.one * M.size, size1 = Vector3.one * M.size * 0.3, spin = M.shape == "block" and 3 or nil,
				color = colorOf(M.color, c.colors), transparency0 = 0.35, transparency1 = 1, life = M.life, material = M.material or Enum.Material.Neon })
		end
	end
	-- 먼 번개(플레이 영역 밖 - 화면 번쩍임 없음 · 섬광 줄이기면 옅게)
	local B = c.spec.bolts
	if B and now > (c.boltAt or 0) then
		c.boltAt = now + B.every * (0.5 + math.random())
		local a = math.random() * math.pi * 2
		local r = B.radius[1] + (B.radius[2] - B.radius[1]) * math.random()
		local base = c.center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local reduce = player:GetAttribute("ReduceFlashes") == true
		for k = 0, 3 do -- 지그재그 4마디
			local p0 = base + Vector3.new(math.random(-8, 8), 120 - k * 30, math.random(-8, 8))
			local p1 = base + Vector3.new(math.random(-8, 8), 120 - (k + 1) * 30, math.random(-8, 8))
			BossFx.spawn({ shape = "block", position = (p0 + p1) / 2, size0 = Vector3.new(1.2, 1.2, (p1 - p0).Magnitude), size1 = Vector3.new(0.3, 0.3, (p1 - p0).Magnitude),
				rotation = CFrame.lookAt(p0, p1).Rotation, color = colorOf(B.color, c.colors):Lerp(WHITE, 0.4), transparency0 = reduce and 0.6 or 0, transparency1 = 1, life = 0.35, material = Enum.Material.Neon })
		end
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
