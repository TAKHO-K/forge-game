-- QUEUE-ALL1 P2 바닥 드랍 연출 v2(docs/design/v2/08-drop-visuals.md · 디아블로4식 "검은 실루엣 + 빛" · ArtStyleV1 뒤 - 부르는 곳 = ArtV1Dopamine.build).
--   ① 장비 = 실제 방어구 v3 메시(ArtMeshCache armor/<부위>_<내 직업>_<외형> 중 대표 조각)를 거의 검정으로 칠해 살짝 띄우고 천천히 돌린다 · 서버 상자 · 테두리 원판은 이 화면에서만 숨김.
--   ② 빛기둥 = 등급색 가는 Beam 가닥(개수 · 높이 · 흔들림 = 등급) · ③ 바닥 빛 = 경계 없는 번짐(부드러운 원 Decal - 테두리 · 채운 원 금지: 보스 전조와 헷갈리지 않게)
--   ④ 이름표 = "<세트> <부위> (<등급>)" · 영웅 이상 = 멀리서도 · 겹치면 위로 쌓는다 ⑤ 테두리 빛(Highlight) = 가깝고 높은 등급 상위 n개만(엔진 동시 한도).
--   수치 = shared/data/ArtV1FxData.dropV2. 태초 · 초월은 기존 규칙(04 문서 클립)이라 여기서 빛기둥을 만들지 않는다(실루엣 · 이름표만).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local FxData = require(ReplicatedStorage.Shared.data.ArtV1FxData)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local ArtImportData = require(ReplicatedStorage.Shared.data.ArtImportData)
local ArtAssetIds = require(ReplicatedStorage.Shared.data.ArtAssetIds)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local ArtMeshKit = require(ReplicatedStorage.Shared.ArtMeshKit)
local Fx = require(script.Parent.ArtV1Fx)

local V = FxData.dropV2
local UserInputService = game:GetService("UserInputService")
local function isPhone()
	local cam = Workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
	return UserInputService.TouchEnabled and math.min(vp.X, vp.Y) < 500
end
local player = Players.LocalPlayer
local DropLookV2 = {}

local live = {} -- [model] = { mesh = Model?, base = CFrame, spin, strands = { Beam }, highlight?, gradeRank, ground, label, labelOffset }

local function zoneName(zone)
	for _, z in ipairs(WorldMapData.zones or {}) do
		if z.key == zone and z.hunt and z.hunt.name then
			return (z.hunt.name:gsub("%s*사냥터$", ""))
		end
	end
	return nil
end

local function rankOf(grade)
	return table.find(ArmorData.gradeOrder, grade) or 1
end

-- ① 대표 조각 실루엣
local function silhouette(model, part, grade, root)
	local classId = player:GetAttribute(ArtImportData.armorClassAttribute)
	local look = ArtImportData.armorLookOfGrade[grade] or "normal"
	local src = type(classId) == "string" and ArtMeshKit.get(("armor/%s_%s_%s"):format(part, classId, look))
	if not src then
		return nil
	end
	local keep = V.meshPieces[part] or {}
	local m = Instance.new("Model")
	m.Name = "DropSilhouette"
	for _, p in ipairs(src:GetChildren()) do
		for _, want in ipairs(keep) do
			if p.Name == want or p.Name:sub(1, #want + 1) == want .. "_" then
				local c = p:Clone()
				c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch = true, false, false, false
				c.CastShadow = false
				c.Material = p.Name:match("_Glow$") and Enum.Material.Neon or Enum.Material.SmoothPlastic
				c.Color = p.Name:match("_Glow$") and ItemVisualData.gradeVisuals[grade] and ItemVisualData.gradeVisuals[grade].color or V.silhouette
				c.Parent = m
				break
			end
		end
	end
	if #m:GetChildren() == 0 then
		m:Destroy()
		return nil
	end
	-- 가운데 = 조각 묶음 경계 상자 가운데 → 서버 Root 자리로 · 크기 = 드랍 상자 크기에 맞춤(너무 크면 줄임)
	local cf, size = m:GetBoundingBox()
	local k = math.min(1, V.meshMaxStuds / math.max(size.X, size.Y, size.Z))
	for _, c in ipairs(m:GetChildren()) do
		local rel = cf:ToObjectSpace(c.CFrame)
		c.Size = c.Size * k
		c.CFrame = CFrame.new(rel.Position * k) * rel.Rotation
	end
	m.WorldPivot = CFrame.identity
	m.Parent = model
	return m
end

-- ② 빛기둥 가닥
local function strand(folder, ground, s, color, i, n)
	local ok, release = Fx.holdBeam()
	if not ok then
		return nil, nil
	end
	local host = Instance.new("Part")
	host.Name = "StrandHost"
	host.Anchored, host.CanCollide, host.CanQuery, host.CanTouch, host.CastShadow = true, false, false, false, false
	host.Transparency = 1
	host.Size = Vector3.one * 0.1
	local a = (i - 1) / math.max(n, 1) * math.pi * 2
	local off = n > 1 and Vector3.new(math.cos(a), 0, math.sin(a)) * s.spread or Vector3.zero
	host.CFrame = CFrame.new(ground + off)
	host.Parent = folder
	local a0 = Instance.new("Attachment")
	a0.Parent = host
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, s.height * (1 - 0.12 * (i - 1)), 0)
	a1.Parent = host
	local b = Instance.new("Beam")
	b.Attachment0, b.Attachment1 = a0, a1
	b.FaceCamera = true
	b.Segments = s.sway and 8 or 1
	b.LightEmission = V.strandEmission
	b.Color = ColorSequence.new(color)
	b.Width0, b.Width1 = s.width, s.width * 0.35
	b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, s.transparency), NumberSequenceKeypoint.new(0.7, math.min(1, s.transparency + 0.2)), NumberSequenceKeypoint.new(1, 1) })
	b.Parent = host
	return b, release
end

-- ③ 바닥 번짐
local function groundGlow(folder, ground, g, color)
	local e = ArtAssetIds["fx/soft_glow"]
	if not (e and e.image) then
		return
	end
	local p = Instance.new("Part")
	p.Name = "GroundGlow"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(g.size, 0.05, g.size)
	p.CFrame = CFrame.new(ground + Vector3.new(0, V.glowLift, 0))
	p.Parent = folder
	local d = Instance.new("Decal")
	d.Face = Enum.NormalId.Top
	d.Texture = "rbxassetid://" .. tostring(e.image)
	d.Color3 = color
	d.Transparency = g.transparency
	d.Parent = p
end

-- 반환: releases(Beam 예산 반납 목록)
function DropLookV2.build(model, folder, grade, ground, color)
	local spec = V.grades[grade]
	local root = model.PrimaryPart or model:FindFirstChild("Root")
	if not (spec and root) then
		return {}
	end
	local releases = {}
	local st = { ground = ground, rank = rankOf(grade), grade = grade, strands = {}, spin = math.random() * 360, hidden = {} }
	-- 서버 상자 · 테두리 원판 = 이 화면에서만 숨김(아트 끄면 unbuild가 되돌린다)
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") and (p == root or p.Name == "DropRing") then
			p.LocalTransparencyModifier = 1
			table.insert(st.hidden, p)
		end
	end
	st.mesh = silhouette(model, model:GetAttribute("DropPart") or "armor", grade, root)
	if not st.mesh then -- 메시가 없으면(캐시 전 · 직업 모름) 상자 실루엣을 그대로 보인다
		for _, p in ipairs(st.hidden) do
			if p == root then
				p.LocalTransparencyModifier = 0
			end
		end
	end
	if spec.strands and not V.skipStrands[grade] then
		local n = spec.strands.count * (isPhone() and V.phoneStrandScale or 1)
		n = math.max(1, math.floor(n + 0.5))
		for i = 1, n do
			local b, release = strand(folder, ground, spec.strands, color, i, n)
			if b then
				table.insert(st.strands, b)
				table.insert(releases, release)
			end
		end
		if spec.outer then
			local b, release = strand(folder, ground, spec.outer, color, 1, 1)
			if b then
				table.insert(releases, release)
			end
		end
	end
	if spec.glow then
		groundGlow(folder, ground, spec.glow, color)
	end
	-- ④ 이름표: "<세트> <부위> (<등급>)" · 영웅 이상 = 멀리서도
	local gui = model:FindFirstChild("NameplateGui", true)
	local label = gui and gui:FindFirstChildOfClass("TextLabel")
	if gui and label then
		st.gui, st.label = gui, label
		st.textWas, st.maxWas, st.sizeWas, st.offsetWas = label.Text, gui.MaxDistance, gui.Size, gui.StudsOffset
		local zone = zoneName(model:GetAttribute("DropZone"))
		local g = ArmorData.grades[grade]
		local partName = ItemVisualData.partDisplayNames[model:GetAttribute("DropPart") or "armor"] or ""
		label.Text = ("%s%s (%s)"):format(zone and (zone .. " ") or "", partName, g and g.displayName or grade)
		if st.rank >= rankOf(V.nameplateAlwaysFrom) then
			gui.MaxDistance = V.nameplateFarStuds
			gui.Size = UDim2.new(gui.Size.X.Scale * spec.nameScale, 0, gui.Size.Y.Scale * spec.nameScale, 0)
		end
		st.baseOffset = gui.StudsOffset
	end
	live[model] = st
	-- 착지: 한 번 더 통통(겉모습) + 유물부터 번쩍
	st.bornAt = os.clock()
	if spec.landFlash then
		task.delay(V.landDelaySeconds, function()
			if live[model] then
				Fx.flash(ground + Vector3.new(0, 1.2, 0), spec.landFlash, 0.2, color)
				Fx.ring(ground + Vector3.new(0, 0.12, 0), spec.landFlash * 2.5, 0.5, color, 0.1, 0.2)
			end
		end)
	end
	return releases
end

function DropLookV2.unbuild(model)
	local st = live[model]
	if not st then
		return
	end
	live[model] = nil
	for _, p in ipairs(st.hidden) do
		if p.Parent then
			p.LocalTransparencyModifier = 0
		end
	end
	if st.mesh then
		st.mesh:Destroy()
	end
	if st.highlight then
		st.highlight:Destroy()
	end
	if st.gui and st.gui.Parent then
		st.label.Text, st.gui.MaxDistance, st.gui.Size, st.gui.StudsOffset = st.textWas, st.maxWas, st.sizeWas, st.offsetWas
	end
end

-- 매 프레임: 회전 · 흔들림 · (0.3초마다) Highlight 상위 n · 이름표 쌓기
local lastPick = 0
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for model, st in pairs(live) do
		if not model.Parent then
			DropLookV2.unbuild(model)
		else
			local root = model.PrimaryPart
			if st.mesh and root then
				st.spin += V.spinDegPerSec / 60
				local t = now - st.bornAt
				local hop = t < V.landDelaySeconds + V.hopSeconds and t > V.landDelaySeconds and math.sin((t - V.landDelaySeconds) / V.hopSeconds * math.pi) * V.hopStuds or 0
				local bob = math.sin(now * 1.6 + st.spin * 0.01) * V.bobStuds
				st.mesh:PivotTo(CFrame.new(root.Position + Vector3.new(0, hop + bob, 0)) * CFrame.Angles(math.rad(V.tiltDeg), math.rad(st.spin), 0))
			end
			if #st.strands > 0 and V.grades[st.grade].strands.sway then
				local s = V.grades[st.grade].strands.sway
				for i, b in ipairs(st.strands) do
					local w = math.sin(now * 1.3 + i * 1.7) * s
					b.CurveSize0, b.CurveSize1 = w, -w * 0.6
				end
			end
		end
	end
	if now - lastPick < 0.3 then
		return
	end
	lastPick = now
	local cam = Workspace.CurrentCamera
	local eye = cam and cam.CFrame.Position or Vector3.zero
	local list = {}
	for model, st in pairs(live) do
		table.insert(list, { model = model, st = st, d = (st.ground - eye).Magnitude })
	end
	table.sort(list, function(a, b)
		if a.st.rank ~= b.st.rank then
			return a.st.rank > b.st.rank
		end
		return a.d < b.d
	end)
	-- ⑤ 테두리 빛: 상위 n개만(가까운 · 높은 등급 순 - 영웅 이상)
	for i, e in ipairs(list) do
		local want = i <= V.highlightMax and e.st.rank >= rankOf(V.highlightFrom) and e.d <= V.highlightStuds and e.st.mesh ~= nil
		if want and not e.st.highlight then
			local h = Instance.new("Highlight")
			h.Name = "DropRim"
			h.FillTransparency = 1
			h.OutlineTransparency = 0.1
			h.OutlineColor = ItemVisualData.gradeVisuals[e.st.grade] and ItemVisualData.gradeVisuals[e.st.grade].color or Color3.new(1, 1, 1)
			h.DepthMode = Enum.HighlightDepthMode.Occluded
			h.Adornee = e.st.mesh
			h.Parent = e.st.mesh
			e.st.highlight = h
		elseif not want and e.st.highlight then
			e.st.highlight:Destroy()
			e.st.highlight = nil
		end
	end
	-- 이름표 쌓기: 서로 stackStuds 안의 드랍은 등급 순으로 위로
	for i, a in ipairs(list) do
		local k = 0
		for j = 1, i - 1 do
			local b = list[j]
			if (Vector3.new(a.st.ground.X, 0, a.st.ground.Z) - Vector3.new(b.st.ground.X, 0, b.st.ground.Z)).Magnitude < V.stackStuds then
				k += 1
			end
		end
		if a.st.gui and a.st.baseOffset then
			a.st.gui.StudsOffset = a.st.baseOffset + Vector3.new(0, k * V.stackLineStuds, 0)
		end
	end
end)

return DropLookV2
