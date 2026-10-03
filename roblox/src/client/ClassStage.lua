-- QUEUE-ALL9C 2-4 직업 선택 무대: ViewportFrame + WorldModel 안 전용 캐릭터(client/StageMascot)의 변신 애니메이션 한 편(공통 흐름 + 직업별 한 박자 = ClassStageData).
--   ClassStage.new(holder) → stage: holder(Frame) 안에 배경 · 뷰포트 · 직업 이름 · 건너뛰기 버튼을 짓는다.
--   stage:play(classId) = 처음부터 · stage:skip() = 바로 완성 포즈 · stage:stop() = 갱신 끔(창 닫힘). 시간 t의 모습은 t만으로 정해진다(키프레임 · 소품 · 흔들림 전부 결정적)
--   → 건너뛰기 · 다시 보기 · 촬영(Studio Attribute DevStageTime = 그 초로 고정 · DevContactSheet = 그 직업 30컷 격자)이 같은 그림.
--   소리 = 재생 중 사건 시각을 지날 때 한 번(건너뛰기 · 고정 = 없음). 소품(연기 · 반짝 · 꽃 · 먼지) 동시 개수 상한 = stage.particleMax(가벼움 = 절반).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Data = require(ReplicatedStorage.Shared.data.ClassStageData)
local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local ArtImportData = require(ReplicatedStorage.Shared.data.ArtImportData)
local Text = require(ReplicatedStorage.Shared.Text)
local Theme = require(script.Parent.ui.kit.Theme)
local StageMascot = require(script.Parent.StageMascot)
local SoundSheet = require(script.Parent.SoundSheet)
local GraphicsMode = require(script.Parent.GraphicsMode)

local ClassStage = {}
ClassStage.__index = ClassStage

local T = Data.times
local rad = math.rad

-- ── 이징 ──────────────────────────────────────────────────────
local EASE = {
	linear = function(x)
		return x
	end,
	["in"] = function(x)
		return x * x
	end,
	out = function(x)
		return 1 - (1 - x) * (1 - x)
	end,
	inOut = function(x)
		return -(math.cos(math.pi * x) - 1) / 2
	end,
	backOut = function(x) -- 살짝 넘쳤다 돌아옴
		local c1 = 1.70158
		local c3 = c1 + 1
		return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
	end,
}

-- ── 포즈 합치기 · 보간 ─────────────────────────────────────────
local function merge(base, over)
	local out = { root = {}, j = {}, squash = (over and over.squash) or (base and base.squash) or 0 }
	for _, src in ipairs({ base or {}, over or {} }) do
		for k, v in pairs(src.root or {}) do
			out.root[k] = v
		end
		for name, v in pairs(src.j or {}) do
			out.j[name] = v
		end
	end
	return out
end

local function resolve(pose, classId)
	if type(pose) == "string" then
		if pose == "hold" then
			return merge(Data.poses.idle, Data.hold[classId])
		elseif pose == "finale" then
			return merge(Data.poses.idle, Data.finale[classId])
		end
		return Data.poses[pose] or {}
	end
	return pose
end


local compileTrack -- 아래 정의(매끄러운 잇기)

-- 직업 하나의 전체 키 목록(공통 흐름 + 한 박자 + 포즈)
local function buildTrack(classId)
	local hold = "hold"
	local keys = {
		{ t = 0.0, pose = "idle" },
		{ t = 0.25, pose = "crouch", ease = "in" }, -- 예비 동작
		{ t = T.smoke, pose = "poof", ease = "out" }, -- 펑(늘어남)
		{ t = 0.55, pose = "land", ease = "in" }, -- 착지 찌그러짐
		{ t = 0.75, pose = "armsOut", ease = "backOut" },
		{ t = 1.3, pose = "armsOut", ease = "linear" },
		{ t = T.weaponDrop, pose = "lookUp", ease = "inOut" }, -- 예비 동작(고개 들고 무릎 살짝)
		{ t = 1.56, pose = "reach", ease = "out" },
		{ t = T.weaponCatch, pose = merge(resolve(hold, classId), Data.poses.catch), ease = "in" }, -- 받는 순간 찌그러짐
		{ t = T.beat, pose = hold, ease = "backOut" },
	}
	local card = ClassData.cards and ClassData.cards[classId]
	for i, k in ipairs(Data.beats[card and card.transform or ""] or {}) do
		if i > 1 then
			table.insert(keys, { t = T.beat + k.t, pose = k.pose, ease = k.ease })
		end
	end
	local finale = resolve("finale", classId)
	local holdArms = {} -- 포즈 앞 웅크림(예비 동작) 동안 팔은 무기를 쥔 그대로
	for name, v in pairs(resolve(hold, classId).j) do
		if name:find("Shoulder") or name:find("Elbow") then
			holdArms[name] = v
		end
	end
	table.insert(keys, { t = T.pose + 0.08, pose = merge(Data.poses.crouch, { j = holdArms }), ease = "in" })
	table.insert(keys, { t = T.pose + 0.22, pose = merge(finale, { root = { y = 0.7 }, squash = -0.1 }), ease = "out" })
	table.insert(keys, { t = T.pose + 0.32, pose = merge(finale, { root = { y = -0.08 }, squash = 0.13 }), ease = "in" })
	table.insert(keys, { t = T.done, pose = "finale", ease = "backOut" })
	for _, k in ipairs(keys) do
		k.resolved = resolve(k.pose, classId)
	end
	return compileTrack(keys)
end

-- ── 매끄러운 잇기(사용자 10-04: "하나의 동작처럼") ─────────────────────
-- 키 사이 = 3차 에르미트(캣멀-롬 기울기 - 속도가 키에서 끊기지 않는다). ease = backOut 키 = 그 앞에 "살짝 넘친" 키를 자동으로 넣어 넘쳤다 돌아오게.
-- ease = in(가속) · out(감속) = 그 키 기울기를 0 쪽으로(멈추듯 들어가거나 떠난다). 채널마다 시간차(ClassStageData.lag - 몸통 → 어깨 → 팔꿈치 → 머리 순 = 겹치는 동작).
local function flatten(pose)
	local f = { ["root.y"] = pose.root and pose.root.y or 0, ["root.rz"] = pose.root and pose.root.rz or 0, ["root.rx"] = pose.root and pose.root.rx or 0, squash = pose.squash or 0 }
	for name, v in pairs(pose.j or {}) do
		f[name .. ".1"], f[name .. ".2"], f[name .. ".3"] = v[1], v[2], v[3]
	end
	return f
end

function compileTrack(keys)
	local expanded = {}
	for _, k in ipairs(keys) do
		local prev = expanded[#expanded]
		local target = flatten(k.resolved)
		if k.ease == "backOut" and prev and k.t - prev.t > 0.08 then -- 넘침 키: 목표를 지나친 자리(앞 키에서 온 방향으로)
			local over = {}
			for ch in pairs(target) do
				over[ch] = true
			end
			for ch in pairs(prev.flat) do
				over[ch] = true
			end
			for ch in pairs(over) do
				local tv, fv = target[ch] or 0, prev.flat[ch] or 0
				over[ch] = tv + (tv - fv) * Data.overshoot
			end
			table.insert(expanded, { t = k.t - (k.t - prev.t) * Data.overshootAt, flat = over, ease = "inOut" })
		end
		table.insert(expanded, { t = k.t, flat = target, ease = k.ease })
	end
	local channels = {}
	for _, k in ipairs(expanded) do
		for ch in pairs(k.flat) do
			channels[ch] = true
		end
	end
	return { keys = expanded, channels = channels }
end

-- 채널 값(3차 에르미트 · 기울기 = 이웃 키 차이 - 속도 연속). 키 ease = out(감속해 닿음) → 그 키에서 기울기 0 · in(가속해 닿음 = 충격) → 기울기 유지.
local function channelAt(track, ch, t)
	local K = track.keys
	local n = #K
	if t <= K[1].t then
		return K[1].flat[ch] or 0
	end
	if t >= K[n].t then
		return K[n].flat[ch] or 0
	end
	local i = 1
	while K[i + 1].t < t do
		i += 1
	end
	local a, b = K[i], K[i + 1]
	local h = b.t - a.t
	local x = (t - a.t) / h
	local pa, pb = a.flat[ch] or 0, b.flat[ch] or 0
	local function slope(j)
		if K[j].ease == "out" then
			return 0
		end
		local k0, k1 = K[math.max(1, j - 1)], K[math.min(n, j + 1)]
		local dt = k1.t - k0.t
		return dt > 0 and ((k1.flat[ch] or 0) - (k0.flat[ch] or 0)) / dt or 0
	end
	local ma, mb = slope(i) * h, slope(i + 1) * h
	local x2, x3 = x * x, x * x * x
	return (2 * x3 - 3 * x2 + 1) * pa + (x3 - 2 * x2 + x) * ma + (-2 * x3 + 3 * x2) * pb + (x3 - x2) * mb
end

local function lagOf(ch)
	local joint = ch:match("^(%a+)%.")
	return joint and Data.lag[joint] or 0
end

local function evaluate(track, t)
	local pose = { root = {}, j = {}, squash = 0 }
	for ch in pairs(track.channels) do
		local v = channelAt(track, ch, math.max(0, t - lagOf(ch)))
		if ch == "squash" then
			pose.squash = v
		elseif ch:sub(1, 5) == "root." then
			pose.root[ch:sub(6)] = v
		else
			local joint, idx = ch:match("^(%a+)%.(%d)$")
			pose.j[joint] = pose.j[joint] or { 0, 0, 0 }
			pose.j[joint][tonumber(idx)] = v
		end
	end
	-- 늘 깔리는 숨쉬기 · 무게중심(작게 - 멈춰 있지 않게)
	local B = Data.breath
	local w = math.sin(t * B.speed)
	local w2 = math.sin(t * B.speed * 0.5 + 1.3)
	pose.root.y = (pose.root.y or 0) + B.rise * w
	pose.root.rz = (pose.root.rz or 0) + B.sway * w2
	for name, add in pairs(B.joints) do
		pose.j[name] = pose.j[name] or { 0, 0, 0 }
		pose.j[name][1] += add[1] * w
		pose.j[name][3] += add[3] * w
	end
	return pose
end

-- 어깨 · 엉덩이 = 방향으로 계산(오일러 순서 때문에 위로 든 팔의 "벌림"이 안쪽으로 뒤집히던 것): { 드는 각(0 아래 · 90 앞 · 180 위), 비틀기, 벌림(오른쪽 +z · 왼쪽 −z = 바깥) }
local LIMB_SIDE = { RightShoulder = 1, LeftShoulder = -1, RightHip = 1, LeftHip = -1 }
local DOWN = Vector3.new(0, -1, 0)
local function limbRotation(v, side)
	local p, s = rad(v[1]), rad(v[3] * side)
	local dir = Vector3.new(side * math.sin(s), -math.cos(p) * math.cos(s), -math.sin(p) * math.cos(s))
	local axis = DOWN:Cross(dir)
	local rot
	if axis.Magnitude < 1e-5 then
		rot = DOWN:Dot(dir) > 0 and CFrame.new() or CFrame.Angles(math.pi, 0, 0)
	else
		rot = CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(DOWN:Dot(dir), -1, 1)))
	end
	return rot * CFrame.Angles(0, rad(v[2]), 0)
end

local function toMascotPose(p, extraRz)
	local joints = {}
	for name, v in pairs(p.j or {}) do
		local side = LIMB_SIDE[name]
		joints[name] = side and limbRotation(v, side) or CFrame.Angles(rad(v[1]), rad(v[2]), rad(v[3]))
	end
	local r = p.root or {}
	local root = CFrame.new(0, r.y or 0, 0) * CFrame.Angles(rad(r.rx or 0), 0, rad((r.rz or 0) + (extraRz or 0)))
	return { root = root, joints = joints, squash = p.squash or 0 }
end

-- ── 무대 ──────────────────────────────────────────────────────
function ClassStage.new(holder)
	local self = setmetatable({}, ClassStage)
	local S = Data.stage
	self.holder = holder
	local back = Instance.new("Frame")
	back.Name = "StageBack"
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.new(1, 1, 1)
	back.BorderSizePixel = 0
	back.Parent = holder
	Theme.corner(back, Theme.corner.chip)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(S.background.top, S.background.bottom)
	g.Parent = back
	local vpf = Instance.new("ViewportFrame")
	vpf.Name = "Stage"
	vpf.Size = UDim2.fromScale(1, 1)
	vpf.BackgroundTransparency = 1
	vpf.Ambient = S.light.ambient
	vpf.LightColor = S.light.color
	vpf.LightDirection = S.light.direction
	vpf.Parent = holder
	self.vpf = vpf
	local world = Instance.new("WorldModel")
	world.Parent = vpf
	self.world = world
	local camera = Instance.new("Camera")
	camera.FieldOfView = S.camera.fov
	camera.CFrame = CFrame.lookAt(S.camera.position, S.camera.lookAt)
	camera.Parent = vpf
	vpf.CurrentCamera = camera
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Shape = Enum.PartType.Cylinder
	floor.Size = Vector3.new(S.floor.size.Y, S.floor.size.X, S.floor.size.Z)
	floor.CFrame = CFrame.new(0, StageMascot.FOOT_Y - S.floor.size.Y / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
	floor.Anchored = true
	floor.Color = S.floor.color
	floor.Material = Enum.Material.SmoothPlastic
	floor.Parent = world
	local shadow = Instance.new("Part") -- 발밑 그림자(뛰면 작고 옅게)
	shadow.Name = "Shadow"
	shadow.Shape = Enum.PartType.Cylinder
	shadow.Anchored, shadow.CanCollide, shadow.CastShadow = true, false, false
	shadow.Material = Enum.Material.SmoothPlastic
	shadow.Color = Data.shadow.color
	shadow.Parent = world
	self.shadow = shadow
	self.camera = camera
	self.cameraBase = camera.CFrame
	self.mascot = StageMascot.new(world)
	-- 소품 칸(미리 지어 재사용)
	self.maxParticles = GraphicsMode.isLite() and S.particleMaxLite or S.particleMax
	self.pool = {}
	for i = 1, self.maxParticles do
		local p = Instance.new("Part")
		p.Name = "Fx" .. i
		p.Shape = Enum.PartType.Ball
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Material = Enum.Material.SmoothPlastic
		p.Transparency = 1
		p.Parent = world
		self.pool[i] = p
	end
	self.props = {}
	-- 직업 이름(포즈 때 톡)
	local name = Instance.new("TextLabel")
	name.Name = "ClassName"
	name.BackgroundTransparency = 1
	name.AnchorPoint = Vector2.new(0.5, 1)
	name.Position = UDim2.new(0.5, 0, 1, -10) -- 무대 아래(든 팔 · 무기를 안 가린다)
	name.Size = UDim2.new(1, -20, 0, 40)
	name.Font = Enum.Font.GothamBlack
	name.TextSize = 32
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.2
	name.TextTransparency = 1
	name.TextStrokeColor3 = Color3.fromRGB(30, 34, 50)
	name.ZIndex = 3
	name.Parent = holder
	local nameScale = Instance.new("UIScale")
	nameScale.Parent = name
	self.nameLabel, self.nameScale = name, nameScale
	-- 무대를 누르면 건너뛰기
	local tap = Instance.new("TextButton")
	tap.Name = "StageSkip"
	tap.BackgroundTransparency = 1
	tap.Text = ""
	tap.Size = UDim2.fromScale(1, 1)
	tap.ZIndex = 2
	tap.Parent = holder
	tap.Activated:Connect(function()
		self:skip()
	end)
	self.t = 0
	if RunService:IsStudio() then
		holder:GetAttributeChangedSignal("DevContactSheet"):Connect(function()
			self:contactSheet(holder:GetAttribute("DevContactSheet"))
		end)
	end
	return self
end

-- 소품 하나(결정적: spawn 시각 · 수명 · 출발 · 속도 · 크기)
function ClassStage:addProp(spec)
	table.insert(self.props, spec)
end

local function sound(cue)
	pcall(SoundSheet.play, cue)
end

function ClassStage:play(classId)
	self.classId = classId
	self.keys = buildTrack(classId)
	local m = self.mascot
	m:clearGear()
	self.armor = m:attachArmor(classId)
	self.weapon = m:attachWeapon(classId)
	-- 메시 캐시가 아직 다 안 왔으면(접속 직후) 다 받은 신호에 한 번 다시 재생(방어구 · 무기가 빠진 채로 끝나지 않게)
	local cache = ReplicatedStorage:FindFirstChild(ArtImportData.cacheFolder)
	if not (cache and cache:GetAttribute(ArtImportData.readyAttribute)) and not self.waitingCache then
		self.waitingCache = true
		task.spawn(function()
			local folder = ReplicatedStorage:WaitForChild(ArtImportData.cacheFolder, 120)
			while folder and not folder:GetAttribute(ArtImportData.readyAttribute) do
				folder:GetAttributeChangedSignal(ArtImportData.readyAttribute):Wait()
			end
			self.waitingCache = false
			if self.classId and self.conn then
				self:play(self.classId)
			end
		end)
	end
	-- 조각 묶음(붙는 몸 파트) 순서 · 출발 시각
	local groups, order = {}, {}
	for _, a in ipairs(self.armor) do
		if not groups[a.body] then
			groups[a.body] = {}
		end
		table.insert(groups[a.body], a)
	end
	local slotOf = {}
	for i, slotBodies in ipairs(Data.armorSlots) do
		for _, body in ipairs(slotBodies) do
			slotOf[body] = i
		end
	end
	local slots = {}
	for body, list in pairs(groups) do
		local i = slotOf[body] or #Data.armorSlots
		slots[i] = slots[i] or {}
		for _, a in ipairs(list) do
			table.insert(slots[i], a)
		end
	end
	for i = 1, #Data.armorSlots do
		if slots[i] then
			local start = T.armorStart + (i - 1) * T.armorGap
			for n, a in ipairs(slots[i]) do
				local ang = (i * 3 + n) * 2.4
				a.flyStart = start
				a.flyDir = Vector3.new(math.cos(ang) * Data.armorFlyFrom.distance, Data.armorFlyFrom.up, math.sin(ang) * Data.armorFlyFrom.distance * 0.5 - 2)
			end
			table.insert(order, { body = slots[i][1].body, at = start + T.armorFly })
		end
	end
	self.landings = order
	-- 소품
	self.props = {}
	local P = Data.props
	for i = 1, P.smoke.puffs do
		local a = (i / P.smoke.puffs) * math.pi * 2
		local dir = Vector3.new(math.cos(a) * 1.6, 0.4 + (i % 3) * 0.5, math.sin(a) * 0.8)
		self:addProp({ at = T.smoke - 0.02, life = P.smoke.seconds, from = Vector3.new(0, -1.6 + (i % 3) * 0.5, 0.4), vel = dir * 1.6, size = { P.smoke.size[1], P.smoke.size[2] + (i % 3) * 0.3 }, color = P.smoke.color, fade = P.smoke.transparency })
	end
	for _, l in ipairs(order) do
		for i = 1, P.sparkle.count do
			local a = (i / P.sparkle.count) * math.pi * 2
			self:addProp({ at = l.at, life = P.sparkle.seconds, body = l.body, vel = Vector3.new(math.cos(a), 0.8, math.sin(a)) * 0.9, size = { P.sparkle.size, 0.1 }, color = P.sparkle.color, neon = true })
		end
	end
	for _, at in ipairs(Data.landings) do -- 착지 · 받기 · 포즈 착지 먼지
		for i = 1, P.dust.count do
			local side = (i - (P.dust.count + 1) / 2)
			self:addProp({ at = at, life = 0.4, from = Vector3.new(side * 0.7, StageMascot.FOOT_Y + 0.15, -0.3), vel = Vector3.new(side * 0.9, 0.45, -0.4), size = { 0.35, 1.0 }, color = P.dust.color, fade = P.dust.fade })
		end
	end
	local card = ClassData.cards[classId] or {}
	local beat = card.transform
	if beat == "heavy" then
		for i = 1, P.dust.count do
			self:addProp({ at = T.beat + 0.14, life = 0.45, from = Vector3.new((i - 2.5) * 0.6, StageMascot.FOOT_Y + 0.2, -1.6), vel = Vector3.new((i - 2.5) * 0.5, 0.7, -0.3), size = { 0.5, 1.4 }, color = P.dust.color, fade = P.dust.fade })
		end
	elseif beat == "flowers" then
		for i = 1, P.flowers.count do
			local a = (i / P.flowers.count) * math.pi * 2
			self:addProp({ at = T.beat + P.flowers.at, life = P.flowers.seconds, tip = true, vel = Vector3.new(math.cos(a) * 1.8, 1.2 + (i % 2) * 0.6, math.sin(a) * 0.8), gravity = 3, size = { 0.2, 0.75 }, color = P.flowers.colors[(i - 1) % #P.flowers.colors + 1], keep = true })
		end
	end
	for i = 1, P.finaleSparkle.count do
		local a = (i / P.finaleSparkle.count) * math.pi * 2
		self:addProp({ at = T.done - 0.08, life = P.finaleSparkle.seconds, from = Vector3.new(0, 0.6, 0), vel = Vector3.new(math.cos(a) * 2.4, 1.2 + math.sin(a), -0.6), size = { P.finaleSparkle.size, 0.1 }, color = P.sparkle.color, neon = true })
	end
	-- 사과 · 화살(궁수)
	if self.apple then
		self.apple:Destroy()
		self.apple = nil
	end
	if beat == "apple" then
		local apple = Instance.new("Model")
		apple.Name = "ApplePropModel"
		local ball = Instance.new("Part")
		ball.Name = "Apple"
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.one * P.apple.size
		ball.Color = P.apple.color
		ball.Anchored = true
		ball.Parent = apple
		local leaf = Instance.new("Part")
		leaf.Name = "Leaf"
		leaf.Size = Vector3.new(0.35, 0.08, 0.2)
		leaf.Color = P.apple.leaf
		leaf.Anchored = true
		leaf.Parent = apple
		local arrow = Instance.new("Part")
		arrow.Name = "Arrow"
		arrow.Size = Vector3.new(0.1, 0.1, 2.0)
		arrow.Color = P.arrow.color
		arrow.Anchored = true
		arrow.Parent = apple
		apple.Parent = self.world
		self.apple = apple
	end
	self.events = {
		{ at = T.smoke, cue = Data.sounds.smoke },
		{ at = T.weaponCatch, cue = Data.sounds.catch },
		{ at = T.done - 0.05, cue = Data.sounds.pose },
	}
	for _, l in ipairs(order) do
		table.insert(self.events, { at = l.at, cue = Data.sounds.clank, quiet = true })
	end
	local beatCue = beat and Data.sounds[beat]
	if beatCue then
		table.insert(self.events, { at = T.beat + (beat == "apple" and P.arrow.at + P.arrow.flySeconds or beat == "flowers" and P.flowers.at or 0.14), cue = beatCue })
	end
	self.lastClank = -1
	self.startClock = os.clock()
	self.t = 0
	self.lastT = 0
	self.skipped = false
	self:start()
end

function ClassStage:skip()
	if not self.keys then
		return
	end
	self.startClock = os.clock() - T.done
	self.skipped = true
end

function ClassStage:start()
	if self.conn then
		return
	end
	self.conn = RunService.RenderStepped:Connect(function(dt)
		if not self.holder:IsDescendantOf(game) or not self.holder.Visible then
			return
		end
		local devT = RunService:IsStudio() and self.holder:GetAttribute("DevStageTime")
		local t = type(devT) == "number" and devT or (os.clock() - self.startClock)
		self:render(t, dt, devT == nil)
	end)
end

function ClassStage:stop()
	if self.conn then
		self.conn:Disconnect()
		self.conn = nil
	end
end

-- 몸 흔들림(조각이 붙을 때마다 작은 충격 → 감쇠 진동 - 결정적)
function ClassStage:jiggle(t)
	local sum = 0
	for i, l in ipairs(self.landings or {}) do
		local dt = t - l.at
		if dt > 0 and dt < 0.6 then
			sum += Data.attachJiggle * (i % 2 == 0 and 1 or -1) * math.exp(-dt * 9) * math.sin(dt * 26)
		end
	end
	return sum
end

function ClassStage:render(t, dt, live)
	if not self.keys then
		return
	end
	local m = self.mascot
	local pose = evaluate(self.keys, t) -- 끝난 뒤 = 마지막 포즈 + 숨쉬기(evaluate 안)
	-- 시선: 날아오는 조각(가운데) · 떨어지는 무기를 고개로 따라봄(목에 더함 - 몸통 기준 방위)
	local G = Data.gaze
	local look
	local flying, n = Vector3.zero, 0
	for _, a in ipairs(self.armor or {}) do
		local x = (t - a.flyStart) / T.armorFly
		if x > -0.6 and x < 0.7 then -- 출발 조금 전부터(예비 시선) 붙기 직전까지
			flying += a.part.Position
			n += 1
		end
	end
	if n > 0 then
		look = flying / n
	elseif t > T.weaponDrop - 0.1 and t < T.weaponCatch then
		local hand = m.parts.RightHand
		look = hand.Position + Vector3.new(0, Data.weaponDropHeight * (1 - math.clamp((t - T.weaponDrop) / (T.weaponCatch - T.weaponDrop), 0, 1) ^ 2), 0)
	end
	local head = m.parts.Head.Position
	self.gazeYaw, self.gazePitch = self.gazeYaw or 0, self.gazePitch or 0
	local wantYaw, wantPitch = 0, 0
	if look then
		local d = look - head
		wantYaw = math.clamp(math.deg(math.atan2(-d.X, -d.Z)), -G.maxYaw, G.maxYaw) * G.weight
		wantPitch = math.clamp(math.deg(math.atan2(d.Y, math.sqrt(d.X * d.X + d.Z * d.Z))), -G.maxPitch, G.maxPitch) * G.weight
	end
	local follow = 1 - math.exp(-(dt or 1 / 60) * 10) -- 시선은 부드럽게 따라감
	self.gazeYaw += (wantYaw - self.gazeYaw) * follow
	self.gazePitch += (wantPitch - self.gazePitch) * follow
	pose.j.Neck = pose.j.Neck or { 0, 0, 0 }
	pose.j.Neck = { pose.j.Neck[1] + self.gazePitch * 0.6, pose.j.Neck[2] + self.gazeYaw, pose.j.Neck[3] }
	m:setPose(toMascotPose(pose, self:jiggle(t)))
	-- 눈 깜빡임
	local B = Data.blink
	local blink = false
	for _, bt in ipairs(B.times) do
		if t >= bt and t < bt + B.seconds then
			blink = true
		end
	end
	if t > T.done and ((t - T.done) % B.every) < B.seconds then
		blink = true
	end
	m.blink = blink
	-- 카메라: 3초 동안 아주 천천히 다가감(이징)
	local cx = EASE.inOut(math.clamp(t / T.done, 0, 1))
	local base = self.cameraBase
	local target = Data.stage.camera.lookAt
	self.camera.CFrame = base + (target - base.Position) * (Data.dolly * cx)
	-- 방어구 조각: 출발 전 숨김 · 날아오는 중(backOut = 살짝 지나쳤다 철컥) · 붙은 뒤 그대로
	for _, a in ipairs(self.armor or {}) do
		local x = (t - a.flyStart) / T.armorFly
		if x <= 0 then
			a.hidden = true
		elseif x < 1 then
			local e = EASE.backOut(x)
			a.hidden = false
			a.offset = a.flyDir * (1 - e)
			a.spin = (1 - e) * 3
		else
			a.hidden, a.offset, a.spin = false, nil, nil
		end
	end
	-- 무기: 떨어지기 전 숨김 · 떨어지는 중(중력 = in) · 받음 · 저글링(도적 한 박자)
	local card = ClassData.cards[self.classId] or {}
	for _, a in ipairs(self.weapon or {}) do
		if t < T.weaponDrop then
			a.hidden = true
		elseif t < T.weaponCatch then
			local x = (t - T.weaponDrop) / (T.weaponCatch - T.weaponDrop)
			a.hidden = false
			a.offset = Vector3.new(0, Data.weaponDropHeight * (1 - x * x), 0)
			a.spin = (1 - x) * math.pi * 4
		elseif card.transform == "juggle" and t > T.beat + 0.12 and t < T.beat + 0.56 then
			local x = (t - (T.beat + 0.12)) / 0.44
			local phase = x * math.pi * 3 + (a.hand == "LeftHand" and math.pi or 0)
			a.hidden = false
			a.offset = Vector3.new(0, 2.6 * math.abs(math.sin(phase)), 0)
			a.spin = x * math.pi * 6
		else
			a.hidden, a.offset, a.spin = false, nil, nil
		end
	end
	local world = m:render(live and dt or 1 / 60)
	local rootY = (pose.root and pose.root.y or 0)
	local up = math.clamp(rootY, 0, 1.5)
	local sz = Data.shadow.size * (1 - up * 0.3)
	self.shadow.Size = Vector3.new(0.05, sz, sz * 0.75)
	self.shadow.CFrame = CFrame.new(world.HumanoidRootPart.Position.X, StageMascot.FOOT_Y + 0.02, world.HumanoidRootPart.Position.Z) * CFrame.Angles(0, 0, math.pi / 2)
	self.shadow.Transparency = Data.shadow.transparency + up * 0.25
	-- 사과 · 화살
	if self.apple then
		local P = Data.props
		local headPart = world.Head
		local top = headPart.Position + Vector3.new(0, Data.props.apple.onHead, 0)
		local appear = math.clamp((t - (T.beat + 0.02)) / 0.12, 0, 1)
		local hit = T.beat + P.arrow.at + P.arrow.flySeconds
		local wob = t > hit and math.exp(-(t - hit) * 8) * math.sin((t - hit) * 40) * 0.15 or 0
		local ball = self.apple.Apple
		ball.Size = Vector3.one * P.apple.size * EASE.backOut(appear)
		ball.Transparency = appear > 0 and 0 or 1
		ball.CFrame = CFrame.new(top) * CFrame.Angles(0, 0, wob)
		self.apple.Leaf.CFrame = ball.CFrame * CFrame.new(0.12, 0.48, 0) * CFrame.Angles(0, 0, 0.5)
		self.apple.Leaf.Transparency = ball.Transparency
		local arrow = self.apple.Arrow
		local stuck = top + Vector3.new(0.9, 0.05, 0)
		local from = top + Vector3.new(P.arrow.from, 1.2, 0)
		local fx = math.clamp((t - (T.beat + P.arrow.at)) / P.arrow.flySeconds, 0, 1)
		arrow.Transparency = (t < T.beat + P.arrow.at) and 1 or 0
		local pos = from:Lerp(stuck, fx)
		arrow.CFrame = CFrame.lookAt(pos, pos + (stuck - from).Unit) * CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, wob * 2)
	end
	-- 소품 칸 채우기(상한 안에서 지금 살아 있는 것만)
	local tipPos
	for _, a in ipairs(self.weapon or {}) do
		if not tipPos or a.part.Position.Y > tipPos.Y then
			tipPos = a.part.Position
		end
	end
	local used = 0
	for _, pr in ipairs(self.props) do
		local x = (t - pr.at) / pr.life
		if x >= 0 and x < 1 and used < #self.pool then
			used += 1
			local part = self.pool[used]
			local origin = pr.from
			if pr.body then
				origin = world[pr.body] and world[pr.body].Position or Vector3.zero
			elseif pr.tip then
				origin = tipPos or Vector3.new(0, 2.5, 0)
			end
			local e = EASE.out(x)
			local pos = origin + pr.vel * e - Vector3.new(0, (pr.gravity or 0) * x * x, 0)
			part.Position = pos
			part.Size = Vector3.one * (pr.size[1] + (pr.size[2] - pr.size[1]) * e)
			part.Color = pr.color
			part.Material = pr.neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
			part.Transparency = pr.keep and math.max(0, (x - 0.6) / 0.4) or (pr.fade and pr.fade + (1 - pr.fade) * x) or x
		end
	end
	for i = used + 1, #self.pool do
		self.pool[i].Transparency = 1
	end
	-- 직업 이름(포즈 때 톡 - 넘쳤다 돌아옴)
	local nx = math.clamp((t - T.nameAt) / 0.25, 0, 1)
	self.nameLabel.Text = Text.get("class.name." .. self.classId)
	self.nameLabel.TextTransparency = nx > 0 and 0 or 1
	self.nameLabel.TextStrokeTransparency = nx > 0 and 0.2 or 1
	self.nameScale.Scale = math.max(0.01, EASE.backOut(nx))
	-- 소리(재생 중 · 건너뛰기 아님 · 시간 고정 아님)
	if live and not self.skipped then
		for _, ev in ipairs(self.events) do
			if self.lastT < ev.at and t >= ev.at then
				if not ev.quiet or ev.at - self.lastClank > 0.25 then
					sound(ev.cue)
					if ev.quiet then
						self.lastClank = ev.at
					end
				end
			end
		end
	end
	self.lastT = t
	self.t = t
end

-- Studio 검증: 그 직업 3초를 초당 10장(30컷)으로 한 화면 격자에 늘어놓는다(1/60초씩 실제처럼 돌려 스프링 · 시선까지 같은 결과 → 0.1초마다 무대 사본).
--   무대 holder Attribute DevContactSheet = 직업 id(끝나면 nil = 지움). 컷 아래 = 초 · 그 칸의 효과음 지점(● = 소리 연결 지점).
function ClassStage:contactSheet(classId)
	local gui = self.holder:FindFirstAncestorWhichIsA("ScreenGui")
	local old = gui and gui.Parent and gui.Parent:FindFirstChild("ClassStageContactSheet")
	if old then
		old:Destroy()
	end
	if not classId or not gui then
		return
	end
	self:stop()
	self:play(classId)
	self:stop()
	local sheet = Instance.new("ScreenGui")
	sheet.Name = "ClassStageContactSheet"
	sheet.DisplayOrder = 999
	sheet.IgnoreGuiInset = true
	sheet.Parent = gui.Parent
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
	bg.Parent = sheet
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(1 / 6, -4, 1 / 5, -4)
	grid.CellPadding = UDim2.new(0, 4, 0, 4)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = bg
	self.gazeYaw, self.gazePitch = 0, 0
	local step = 1 / 60
	local t = 0
	self:render(0, step, false)
	for frame = 0, 29 do
		local at = frame * 0.1
		while t < at - 1e-6 do
			t = math.min(at, t + step)
			self:render(t, step, false)
		end
		local cell = Instance.new("ViewportFrame")
		cell.LayoutOrder = frame
		cell.BackgroundColor3 = Data.stage.background.bottom
		cell.Ambient, cell.LightColor, cell.LightDirection = self.vpf.Ambient, self.vpf.LightColor, self.vpf.LightDirection
		cell.Parent = bg
		local wm = self.world:Clone()
		wm.Parent = cell
		local cam = self.camera:Clone()
		cam.Parent = cell
		cell.CurrentCamera = cam
		local mark = ""
		for _, ev in ipairs(self.events) do
			if ev.at >= at and ev.at < at + 0.1 then
				mark = " ●"
			end
		end
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, 0, 18)
		label.Position = UDim2.new(0, 4, 1, -20)
		label.Font = Enum.Font.GothamBold
		label.TextSize = 14
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = Color3.fromRGB(20, 20, 30)
		label.Text = ("%.1fs%s"):format(at, mark)
		label.Parent = cell
	end
	self:start()
end

function ClassStage:isDone()
	return self.t >= T.done
end

return ClassStage
