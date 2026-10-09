-- BOSS-NIGHT-1 새 몸 폼별 겉모습(클라 · 판정 무관): 동작 세트(BossClipSetData)의
--   formParts = { before = { 부위 … }, after = { 부위 … } } = 그 폼에서 숨길 부위(그 부위의 외곽선 · Neon 조각 "<부위>_…"까지 LocalTransparencyModifier 1)
--   formFx = { halo = { part, at, radius, count, thickness, colors, speeds }(그 폼에서 머리 뒤 이중 후광 - 고리 2개 반대 회전 · Neon 조각) ·
--              shards = { part, radius, count, size, color, speed }(허리 둘레 떠도는 파편) · orbs = { slot, count, radius, height, size, speed, bob }(구름 보주 공전 - 두 폼) }
--   폭풍 군주: 1폼 = 망토 · 지팡이 · 1폼 어깨 · 아래팔 · 손 · 구름 깃 / 2폼 = 날개 · 왕관 · 가슴 코어 · 2폼 어깨 · 건틀릿 · 후광 · 파편.
--   만든 파트는 모델 안 폴더 하나(BossFormFx) - 모델이 사라지면 같이 사라진다 · 폰 · lite = 고리 조각 절반.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossFrameworkData = require(ReplicatedStorage.Shared.data.BossFrameworkData)
local ArtMeshKit = require(ReplicatedStorage.Shared.ArtMeshKit)

local BossFormFxView = {}
local states = setmetatable({}, { __mode = "k" })

local function lite()
	local p = game:GetService("Players").LocalPlayer
	return p and (p:GetAttribute("A2M1ForcePhone") == true or p:GetAttribute("GraphicsMode") == "lite")
end

-- 부위 이름 → 그 부위 + 외곽선 · 장식 파트들
local function partsNamed(model, name)
	local out = {}
	for _, c in ipairs(model:GetChildren()) do
		if c:IsA("BasePart") and (c.Name == name or c.Name:sub(1, #name + 1) == name .. "_") then
			table.insert(out, c)
		end
	end
	return out
end

local function neon(parent, size, color, shape)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local function orbMesh()
	local key = BossFrameworkData.meshSlots.StormOrb
	local model = key and ArtMeshKit.get(key)
	for _, d in ipairs(model and model:GetDescendants() or {}) do
		if d:IsA("MeshPart") then
			return d
		end
	end
	return nil
end

local function build(e, set)
	local s = { hidden = {}, form = nil }
	local folder = Instance.new("Folder")
	folder.Name = "BossFormFx"
	folder.Parent = e.model
	s.folder = folder
	local FX = set.formFx or {}
	local S = e.model:GetAttribute("BossVisualScale") or 1
	if FX.halo then
		local H = FX.halo
		s.rings = {}
		local n = lite() and math.max(4, math.floor(H.count / 2)) or H.count
		for r = 1, 2 do
			local ring = { segs = {}, radius = H.radius[r], speed = H.speeds[r] }
			for i = 1, n do
				table.insert(ring.segs, neon(folder, Vector3.new(H.thickness, H.thickness, 2 * math.pi * H.radius[r] / n * 0.8), H.colors[r]))
			end
			table.insert(s.rings, ring)
		end
	end
	if FX.shards then
		s.shards = {}
		for i = 1, FX.shards.count do
			table.insert(s.shards, neon(folder, FX.shards.size * (0.7 + 0.6 * ((i * 37) % 10) / 10), FX.shards.color))
		end
	end
	if FX.orbs then
		s.orbs = {}
		local template = orbMesh()
		for i = 1, FX.orbs.count do
			local p
			if template then
				p = template:Clone()
				p:ClearAllChildren()
				local tk = BossFrameworkData.meshSlotTextures and BossFrameworkData.meshSlotTextures[FX.orbs.slot]
				local entry = tk and require(ReplicatedStorage.Shared.data.ArtAssetIds)[tk]
				if entry and entry.image then
					p.TextureID = "rbxassetid://" .. tostring(entry.image)
					p.Color = Color3.new(1, 1, 1)
				end
				local sz = p.Size
				p.Size = sz * (FX.orbs.size / math.max(sz.X, sz.Y, sz.Z))
				p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
				p.Parent = folder
			else
				p = neon(folder, Vector3.one * FX.orbs.size, Color3.fromRGB(200, 210, 230), Enum.PartType.Ball)
				p.Material = Enum.Material.SmoothPlastic
			end
			local light = Instance.new("PointLight")
			light.Color, light.Range, light.Brightness = Color3.fromRGB(255, 230, 120), FX.orbs.size * 1.6, 0.8
			light.Parent = p
			table.insert(s.orbs, p)
		end
	end
	s.scale = S
	return s
end

local function setVisible(list, visible)
	for _, p in ipairs(list) do
		p.LocalTransparencyModifier = visible and 0 or 1
	end
end

-- ─────────────────────────── BOSS-NIGHT-2 2-2 아이언맨식 조립(set.transform.assemble · 변신 시작부터 초) ───────────────────────────
--   부품마다 대역(메시 복제)이 보는 사람 반대편(보스 뒤 · 화면 밖) fromStuds · 위 upStuds에서 번개 꼬리를 달고 출발 → 빠르게 오다 끝에서 감속(easeOut) → at에 진짜 부품이 나타남
--   (흰 번쩍 flashSeconds · 철컥 sound · 작은 흔들림 shake) · hide = 그 순간 사라지는 1폼 부품(그때까지 보임) · wings = 날개는 몸에서 펼침(클립) · burst = 번개 폭발.
local SoundSheet = require(script.Parent.SoundSheet)
local BossFx = require(script.Parent.BossFx)
local Players = game:GetService("Players")

local function easeOut(u)
	return 1 - (1 - u) ^ 3
end

local function capeNames()
	local out = {}
	for _, t in ipairs({ "A", "B", "C", "D" }) do
		for i = 1, 4 do
			table.insert(out, "Cape" .. t .. i)
		end
	end
	return out
end

local function makeProxy(s, real, A)
	local p = real:Clone()
	p:ClearAllChildren()
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.LocalTransparencyModifier = 0
	p.Transparency = 0
	local half = p.Size.Y * 0.45
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, half, 0), Vector3.new(0, -half, 0)
	a0.Parent, a1.Parent = p, p
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Lifetime = 0.35
	trail.Color = ColorSequence.new(A.trailColor)
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.WidthScale = NumberSequence.new(1, 0.2)
	trail.LightEmission, trail.FaceCamera = 1, true
	trail.Parent = p
	p.Parent = s.folder
	return p
end

local function flash(real, seconds)
	local h = Instance.new("Highlight")
	h.FillColor, h.OutlineColor = Color3.new(1, 1, 1), Color3.new(1, 1, 1)
	h.FillTransparency, h.OutlineTransparency = 0.2, 0.4
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Adornee = real
	h.Parent = real
	task.delay(seconds, function()
		h:Destroy()
	end)
end

-- 반환: 이번 프레임 조립 중이면 true(평소 숨김 유지 루프를 건너뛴다)
local function assembleStep(e, s, set, now)
	local T = set.transform
	local A = T and T.assemble
	local st = e.st
	if not (A and st and st.transformAt) then
		return false
	end
	local t = now - st.transformAt
	local asm = s.asm
	if not asm or asm.at ~= st.transformAt then
		if asm then
			for _, px in pairs(asm.proxies) do
				px:Destroy()
			end
		end
		asm = { at = st.transformAt, proxies = {}, done = {}, burst = false, dropped = false }
		s.asm = asm
	end
	if t > T.seconds + 0.2 then
		if not asm.finished then
			asm.finished = true
			for _, px in pairs(asm.proxies) do
				px:Destroy()
			end
			asm.proxies = {}
			s.form = nil -- 평소 폼 보이기로 다시 맞춤
		end
		return false
	end
	if t < (T.switchAt or 0) then
		return false -- 웅크림(1폼 그대로)
	end
	local root = e.model.PrimaryPart
	if not root then
		return true
	end
	local center = root.Position
	local cam = workspace.CurrentCamera
	local me = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local viewer = (me and me.Position) or (cam and cam.CFrame.Position) or (center + Vector3.new(0, 0, 30))
	local back = Vector3.new(center.X - viewer.X, 0, center.Z - viewer.Z)
	back = back.Magnitude > 1e-3 and back.Unit or Vector3.new(0, 0, 1)
	local side = back:Cross(Vector3.yAxis)
	if not asm.dropped and t >= (A.dropAt or 0) then -- 지팡이가 번개로 흩어짐
		asm.dropped = true
		for _, name in ipairs(A.drop or {}) do
			local p = e.model:FindFirstChild(name)
			if p then
				for k = 1, 6 do
					local a = k / 6 * 2 * math.pi
					BossFx.streak(p.Position, Vector3.new(math.cos(a), 0.6, math.sin(a)), 3, 0.25, A.trailColor, 0.3, 14)
				end
			end
		end
	end
	for i, step in ipairs(A.steps) do
		local hideNames = step.hide == "cape" and capeNames() or step.hide or {}
		local attached = t >= step.at
		-- 1폼 짝 부품: 붙는 순간까지 보임
		for _, name in ipairs(hideNames) do
			s.hidden[name] = s.hidden[name] or partsNamed(e.model, name)
			setVisible(s.hidden[name], not attached)
		end
		local names = step.wings and { "Wing_L1", "Wing_L2", "Wing_R1", "Wing_R2" } or step.parts or {}
		for j, name in ipairs(names) do
			s.hidden[name] = s.hidden[name] or partsNamed(e.model, name)
			setVisible(s.hidden[name], attached)
			local real = e.model:FindFirstChild(name)
			local key = i * 10 + j
			if real and real:IsA("BasePart") and not step.wings then
				local launch = step.at - A.flySeconds
				if t >= launch and not attached then
					local px = asm.proxies[key]
					if not px then
						px = makeProxy(s, real, A)
						asm.proxies[key] = px
						local sgn = (name:sub(-2) == "_L") and -1 or ((name:sub(-2) == "_R") and 1 or 0)
						asm[key] = center + back * A.fromStuds + side * (sgn * A.fromStuds * 0.35) + Vector3.new(0, A.upStuds, 0)
					end
					local u = math.clamp((t - launch) / A.flySeconds, 0, 1)
					local k = easeOut(u) -- 빠르게 출발 → 끝에서 감속
					local pos = asm[key]:Lerp(real.Position, k) + Vector3.new(0, math.sin(math.pi * u) * 6, 0)
					local spin = CFrame.Angles((1 - k) * 6, (1 - k) * 4, 0)
					px.CFrame = CFrame.new(pos) * real.CFrame.Rotation * spin
					if math.random() < 0.5 then -- 번개 꼬리 잔불꽃
						BossFx.streak(pos, (asm[key] - pos).Magnitude > 1 and (asm[key] - pos).Unit or back, 2 + 3 * (1 - k), 0.18, A.trailColor, 0.15, 0)
					end
				end
			end
			if attached and not asm.done[key] then
				asm.done[key] = true
				local px = asm.proxies[key]
				if px then
					px:Destroy()
					asm.proxies[key] = nil
				end
				if real and real:IsA("BasePart") then
					flash(real, A.flashSeconds)
					if j == 1 then -- 같은 순간 둘(어깨 L/R)이면 소리 · 흔들림 한 번
						pcall(SoundSheet.play, A.sound, { part = real, minInterval = 0.05 })
						BossFx.shake(real.Position, A.shake)
					end
					BossFx.ring(real.Position, 0.4, 3.2, Color3.new(1, 1, 1), 0.18, 0.35)
				end
			end
		end
	end
	if not asm.burst and t >= A.burst then -- 번개 폭발 + 떠오름(클립)
		asm.burst = true
		for k = 1, 14 do
			local a = k / 14 * 2 * math.pi
			BossFx.streak(center + Vector3.new(0, 6, 0), Vector3.new(math.cos(a), math.random() * 0.8 - 0.2, math.sin(a)), 10 + math.random() * 6, 0.35, A.trailColor, 0.35, 30)
		end
		BossFx.ring(center - Vector3.new(0, 3, 0), 2, 26, A.trailColor, 0.45, 0.35)
		BossFx.shake(center, 0.6)
	end
	return true
end

-- 매 프레임(BossAnimator): e = 보스 항목(model · ctx.set) · formName = "before" | "after"
function BossFormFxView.step(e, formName, now)
	local set = e.ctx and e.ctx.set
	if not (set and (set.formParts or set.formFx)) or not e.model.Parent then
		return
	end
	local s = states[e.model]
	if not s then
		s = build(e, set)
		states[e.model] = s
	end
	formName = formName or "before"
	local assembling = assembleStep(e, s, set, now) -- BOSS-NIGHT-2 아이언맨식 조립(그동안 평소 숨김 유지를 건너뜀)
	if assembling then
		if s.form ~= formName then
			s.form = formName
			for _, name in ipairs((set.formParts or {}).before or {}) do -- 2폼 부품은 조립이 보이기를 정한다 · 1폼 부품만 여기서
				s.hidden[name] = s.hidden[name] or partsNamed(e.model, name)
			end
			for _, name in ipairs((set.formParts or {})[formName] or {}) do
				s.hidden[name] = s.hidden[name] or partsNamed(e.model, name)
				setVisible(s.hidden[name], false)
			end
		end
		return BossFormFxView.move(e, s, set, formName, now)
	end
	if s.form ~= formName then
		s.form = formName
		for fname, list in pairs(set.formParts or {}) do
			for _, name in ipairs(list) do
				s.hidden[name] = s.hidden[name] or partsNamed(e.model, name)
				setVisible(s.hidden[name], fname ~= formName)
			end
		end
	end
	-- 지금 폼에서 숨길 부위는 1 유지(등장 연출 끝 · 사망 연출이 모든 파트를 0으로 되돌린다 - BossBodyFx.introEnd) · 초당 4번(비용)
	if s.hideAt and now - s.hideAt < 0.25 then
		return BossFormFxView.move(e, s, set, formName, now)
	end
	s.hideAt = now
	for _, name in ipairs((set.formParts or {})[formName] or {}) do
		for _, p in ipairs(s.hidden[name] or {}) do
			if p.LocalTransparencyModifier < 1 then
				p.LocalTransparencyModifier = 1
			end
		end
	end
	return BossFormFxView.move(e, s, set, formName, now)
end

-- 후광 · 파편 = 30Hz(BulkMoveTo 한 번 - 비용) · 구름 보주는 같은 때
function BossFormFxView.move(e, s, set, formName, now)
	if s.moveAt and now - s.moveAt < 1 / 30 then
		return
	end
	s.moveAt = now
	local FX = set.formFx or {}
	local root = e.model.PrimaryPart
	if not root then
		return
	end
	-- 이중 후광 · 허리 파편(그 폼에서만) · 구름 보주(두 폼): 위치를 모아 BulkMoveTo 한 번(파트 37개를 하나씩 옮기면 보스 모션 비용이 × 2였다 - Studio 측정)
	local moveParts, moveCFs = s.moveParts or {}, s.moveCFs or {}
	s.moveParts, s.moveCFs = moveParts, moveCFs
	local n = 0
	local function put(p, cf)
		n += 1
		moveParts[n], moveCFs[n] = p, cf
	end
	local function show(list, key, on)
		if s[key] ~= on then
			s[key] = on
			for _, p in ipairs(list) do
				p.Transparency = on and 0.1 or 1
			end
		end
	end
	if s.rings then
		local H = FX.halo
		local on = formName == H.form
		if not s.ringAll then
			s.ringAll = {}
			for _, ring in ipairs(s.rings) do
				for _, seg in ipairs(ring.segs) do
					table.insert(s.ringAll, seg)
				end
			end
		end
		show(s.ringAll, "ringOn", on)
		if on then
			local host = e.model:FindFirstChild(H.part) or root
			local base = host.CFrame * CFrame.new(H.at[1], H.at[2], H.at[3])
			local turn = CFrame.Angles(0, math.rad(90), 0)
			for _, ring in ipairs(s.rings) do
				local segs = ring.segs
				local k = #segs
				for i = 1, k do
					put(segs[i], base * CFrame.Angles(0, 0, (i / k) * 2 * math.pi + now * ring.speed) * CFrame.new(0, ring.radius, 0) * turn)
				end
			end
		end
	end
	if s.shards then
		local Sh = FX.shards
		local on = formName == Sh.form
		show(s.shards, "shardOn", on)
		if on then
			local host = e.model:FindFirstChild(Sh.part) or root
			local c = host.Position
			local k = #s.shards
			for i = 1, k do
				local a = (i / k) * 2 * math.pi + now * Sh.speed
				put(s.shards[i], CFrame.new(c.X + math.cos(a) * Sh.radius, c.Y + math.sin(now * 2 + i) * Sh.radius * 0.12, c.Z + math.sin(a) * Sh.radius) * CFrame.Angles(now * 1.3 + i, now + i * 0.7, 0))
			end
		end
	end
	if s.orbs then
		local O = FX.orbs
		local c = root.Position
		local h = O.height[formName] or O.height.before
		local k = #s.orbs
		for i = 1, k do
			local a = (i / k) * 2 * math.pi + now * O.speed
			put(s.orbs[i], CFrame.new(c.X + math.cos(a) * O.radius, c.Y + h + math.sin(now * 1.7 + i * 2) * O.bob, c.Z + math.sin(a) * O.radius) * CFrame.Angles(0, now * 0.8 + i, 0))
		end
	end
	for i = #moveParts, n + 1, -1 do
		moveParts[i], moveCFs[i] = nil, nil
	end
	if n > 0 then
		workspace:BulkMoveTo(moveParts, moveCFs, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

return BossFormFxView
