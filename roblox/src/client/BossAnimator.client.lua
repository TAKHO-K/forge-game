-- BR1-4b 보스 모션(4b-1 · 4b-2): 관절 리그 보스(모델 Attribute BossRig)의 Motor6D.Transform을 매 프레임 쓴다(PreSimulation - W1: 여기서 써야 물리에 들어간다 · 복제 안 됨 = 각 클라가 그림).
-- 판정과 무관: 서버 루트(HumanoidRootPart - Anchored)는 서버 계산값 그대로 움직이고, 이 스크립트는 보이는 부위만 움직인다.
--   · 클라 보간: 루트가 복제 틱마다 뚝뚝 옮겨져도 보이는 몸은 부드럽게 따라간다(RootJoint Transform에 보간 오프셋) · 서버 헤롱 기울임(25°)은 몸 모션(주저앉기)으로 바꿔 그린다.
--   · 자세 = shared/BossMotion(서버 부착점 FK와 같은 식) + 2차 움직임 스프링(꼬리 · 망토 · 수염 · 치마가 몸보다 늦게) + 바라보기(가까운 사람) + 피격 움찔(BossHpRatio 감소) + 사망(복제해 쓰러뜨림).
--   · LOD: 카메라에서 BossRigSpec.lod.fullStuds 밖 = 초당 reducedHz · farStuds 밖 = 멈춤(스프링 없음).
--   · 잡힌 사람(Player Attribute BossHoldSlot): 보이는 손 · 집게 · 꼬리 부착점에 붙여 그린다(서버도 같은 FK로 그 자리에 둔다 - server/BossAirGrab).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BossRigSpec = require(ReplicatedStorage.Shared.data.BossRigSpec)
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossMotion = require(ReplicatedStorage.Shared.BossMotion)
local BossRig = require(ReplicatedStorage.Shared.BossRig)
local BossMotionData = require(ReplicatedStorage.Shared.data.BossMotionData)
local BossFx = require(script.Parent.BossFx)
local BossBodyFx = require(script.Parent.BossBodyFx) -- A2-M1 타격 충격 · 등장 · 발걸음 효과
local BossSpring = require(script.Parent.BossSpring) -- BOSS-FRAMEWORK 3 새 몸 2차 움직임
local SoundSheet = require(script.Parent.SoundSheet)
local BossFramework = require(ReplicatedStorage.Shared.BossFramework)
local FrameData = require(ReplicatedStorage.Shared.data.BossFrameworkData)
local BossSoundData = require(ReplicatedStorage.Shared.data.BossSoundData)

local localPlayer = Players.LocalPlayer
local LOD = BossRigSpec.lod
local rigs = {} -- [model] = entry
local stats = { frames = 0, seconds = 0, updates = 0 }
local contexts = {}

local function serverNow()
	return Workspace:GetServerTimeNow()
end

local function yawOf(cf)
	local look = cf.LookVector
	return math.atan2(-look.X, -look.Z)
end

-- rigId = 리그 키(옛 몸 = 보스 id · 새 몸 = "<보스>_v2" - BOSS-FRAMEWORK) · bossId = BossData 키
local function contextFor(rigId, bossId)
	local ctx = contexts[rigId]
	if not ctx then
		local data = BossData.bosses[bossId or rigId]
		ctx = BossMotion.context(rigId, BossRigSpec.rigs[rigId], data and data.skills, data and data.moveSpeedStuds)
		ctx.prepSeconds = BossData.basicPrepSeconds -- A2-N3 결정 ② 평타 예비 동작 길이(서버 신호와 같은 값)
		contexts[rigId] = ctx
	end
	return ctx
end

-- BOSS-FRAMEWORK 6 보스별 소리 자리(빈 문자열 = 재생 안 함) - 새 몸 보스만(옛 몸은 공통 큐 그대로)
local function playSlot(e, soundId, part)
	if not e.ctx.set or e.isClone or type(soundId) ~= "string" or soundId == "" then
		return
	end
	SoundSheet.playRaw(soundId, { tier = BossSoundData.tier, part = part or e.root, minInterval = BossSoundData.minInterval })
end
local function soundsOf(e)
	return BossSoundData.bosses[e.bossId or ""] or {}
end

local WEAPONS = { "IceClub", "Trident", "Staff", "Scepter" }

local function register(model)
	if rigs[model] or not model:GetAttribute("BossRig") then
		return
	end
	local bossId = model:GetAttribute("BossRig")
	local rig, rigId = BossRigSpec.rigOf(model) -- BOSS-FRAMEWORK 1: BossRigKey(새 몸)가 있으면 그 리그
	local root = model:FindFirstChild("HumanoidRootPart")
	if not rig or not root then
		return
	end
	local motors = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") then
			motors[d.Name] = d
		end
	end
	local weapon = nil
	for _, name in ipairs(WEAPONS) do
		weapon = weapon or model:FindFirstChild(name)
	end
	local entry = {
		model = model, rigId = rigId, bossId = bossId, rig = rig, root = root, motors = motors, S = root.Size.X / 2,
		ctx = contextFor(rigId, bossId), rest = BossMotion.prepare(rig),
		st = {}, visPos = root.Position, visYaw = yawOf(root.CFrame), groundY = root.Position.Y, gait = 0, speed = 0, turn = 0,
		springs = {}, lastUpdate = 0, hpRatio = model:GetAttribute("BossHpRatio") or 1,
		weapon = weapon or model:FindFirstChild("Hand_R"),
	}
	for i in ipairs(rig.chains or {}) do
		entry.springs[i] = { x = 0, z = 0, vx = 0, vz = 0 }
	end
	if entry.ctx.set then
		entry.spring = BossSpring.new(rig) -- BOSS-FRAMEWORK 3 마디별 스프링
		-- 늦게 들어온 사람(이미 체력 절반 아래) = 변신 뒤 세트로 바로(변신 동작 없음)
		if entry.hpRatio > 0 and entry.hpRatio < BossMotionData.enrage.phaseAt then
			entry.st.form = "after"
			entry.formDone = true
		end
	end
	-- A2-M1 세밀 장식(lod 2): 폰(작은 화면 · 터치) 또는 먼 거리에서 숨긴다(LocalTransparencyModifier - 이 클라만)
	entry.lod2 = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("DetailLod") == 2 then
			table.insert(entry.lod2, d)
		end
	end
	rigs[model] = entry
end

-- 서버 Attribute → 모션 상태(서버 시각)
local function readState(e, now)
	local m, st = e.model, e.st
	local act = m:GetAttribute("BossAct")
	if act then
		if act ~= st.act or m:GetAttribute("BossActAt") ~= st.actAt then
			st.act, st.actAt, st.actHit, st.actEndAt = act, m:GetAttribute("BossActAt"), m:GetAttribute("BossActHit") or 0, nil
			st.throwPlan, st.throwAt = nil, nil
		end
	elseif st.act and not st.actEndAt then
		st.actEndAt = now
	elseif st.actEndAt and now - st.actEndAt > 0.35 then
		st.act, st.actEndAt = nil, nil
	end
	local env = m:GetAttribute("BossEnv")
	if env then
		if env ~= st.env or m:GetAttribute("BossEnvAt") ~= st.envAt then
			st.env, st.envAt, st.envHit, st.envEndAt = env, m:GetAttribute("BossEnvAt"), m:GetAttribute("BossEnvHit") or 0, nil
		end
	elseif st.env and not st.envEndAt then
		st.envEndAt = now
	elseif st.envEndAt and now - st.envEndAt > 0.35 then
		st.env, st.envEndAt = nil, nil
	end
	st.swingAt, st.swingN = m:GetAttribute("BossSwingAt"), m:GetAttribute("BossSwingN")
	st.prepSeconds = m:GetAttribute("BossPrepSeconds") -- GUARDIAN-V3: 평타 예비 길이(새 몸 수호자 연장 - 없으면 BossData.basicPrepSeconds)
	st.prepAt = m:GetAttribute("BossSwingPrepAt") -- A2-N3 결정 ②: 평타 예비 동작(예정 타격 서버 시각) · QUEUE-ALL1 C-1: 전투 가독성 = 아트 끔에서도(스위치 예외)
	st.nextN = m:GetAttribute("BossSwingNextN") -- QUEUE-ALL1 C-1: 다음 휘두를 쪽(서버가 불규칙으로 정함)
	st.hopAt, st.hopSeconds = m:GetAttribute("BossHopAt"), m:GetAttribute("BossHopSeconds")
	st.inCombat = m:GetAttribute("BossEncounterId") ~= nil -- BR1-4c c-10: 보스전 중 기본 자세 = 전투 준비
	-- A2-M1 리뷰 2: 보스전 중 머리 위 이름표를 숨긴다(이름 · 체력이 상단 보스 체력바와 겹쳐 두 번 나옴 · 스트리밍으로 늦게 오면 그때 찾는다)
	local plate = st.nameplate
	if not (plate and plate.Parent) and now - (st.plateSearchAt or -1) > 0.5 then
		st.plateSearchAt = now
		plate = m:FindFirstChild("NameplateGui", true)
		st.nameplate = plate
	end
	if plate and plate.Enabled == st.inCombat then
		plate.Enabled = not st.inCombat
	end
	-- A2-M1 등장(서버 BossEncounter.startIntro가 적는다 - 판정 무관)
	local introAt, introUntil = m:GetAttribute("BossIntroAt"), m:GetAttribute("BossIntroUntil")
	st.introAt = introAt
	st.introSeconds = (introAt and introUntil) and (introUntil - introAt) or nil
	st.introFull = m:GetAttribute("BossIntroFull") == true
	st.actPhase, st.actPhaseAt = m:GetAttribute("BossActPhase"), m:GetAttribute("BossActPhaseAt")
	st.pickAt = m:GetAttribute("BossPickAt")
	local plan, thrown = m:GetAttribute("BossThrowPlan"), m:GetAttribute("BossThrowAt")
	if st.act and plan and st.actAt and plan > st.actAt then
		st.throwPlan = plan
	end
	st.throwAt = thrown and now - thrown < 2 and thrown or nil
	local stunUntil = m:GetAttribute("BossStunUntil")
	if stunUntil then
		st.stunAt, st.stunUntil = m:GetAttribute("BossStunAt"), stunUntil
	elseif st.stunUntil and now < st.stunUntil then
		st.stunUntil = math.min(st.stunUntil, now + 0.6) -- 일찍 풀리면 바로 일어난다
	end
	local hp = m:GetAttribute("BossHpRatio") or e.hpRatio
	if hp < e.hpRatio - 1e-4 and (not st.flinchAt or now - st.flinchAt > 0.35) then
		st.flinchAt = now
		-- A2-M1 피격 반응 세기(판정 무관): 이번에 줄어든 체력 비율로 - 평타 한 대 ≈ 0.7 · 강공격 · 치명 · 스킬 몰아치기 = 최대 2(BossMotionData.flinchAmp)
		local A = BossMotionData.flinchAmp
		st.flinchAmp = math.clamp(A.base + (e.hpRatio - hp) * A.perHpRatio, A.base, A.max)
	end
	e.hpRatio = hp
	if hp <= 0 and not st.deadAt then
		st.deadAt = now
	end
	-- A2-M1 분노(체력 절반 - 겉모습 · 판정 무관): 한 번만
	if hp > 0 and hp < BossMotionData.enrage.phaseAt and not e.enraged and not e.isClone then
		e.enraged = true
		BossBodyFx.enrage(e)
	end
	-- BOSS-FRAMEWORK 4 변신(새 몸 · 겉모습만 - 서버 무변경): 겉모습 격노 순간 뒤 진행 중인 스킬 · 환경이 없을 때(최대 maxWait초 대기) 변신 동작 1회
	if e.ctx.set and not e.isClone and not e.preview then
		if hp > 0 and hp < BossMotionData.enrage.phaseAt and not e.formDone then
			e.formQueuedAt = e.formQueuedAt or now
			if not st.transformAt and ((not st.act and not st.env) or now - e.formQueuedAt > FrameData.transform.maxWait) then
				st.transformAt = now
				e.formDone = true
				playSlot(e, soundsOf(e).transform)
				playSlot(e, soundsOf(e).roar)
			end
		elseif hp >= 0.999 and e.formDone then
			-- 전멸 리셋(서버가 체력을 다시 채우고 스폰 자리로 옮김) = 변신 전 세트로 되돌림
			st.transformAt, st.form, e.formDone, e.formQueuedAt = nil, nil, nil, nil
		end
	end
end

-- 가까운 사람 쪽으로 머리가 먼저(몸 기준 각 · 도) - 잡기 중에는 없음(서버 FK와 같은 자세)
local function lookYawFor(e)
	if e.st.act and e.ctx.skills and e.ctx.skills[e.st.act] and e.ctx.skills[e.st.act].primitive == "grab" then
		return nil
	end
	local best, bestD = nil, 90
	for _, p in ipairs(Players:GetPlayers()) do
		local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if r then
			local d = (Vector3.new(r.Position.X, 0, r.Position.Z) - Vector3.new(e.visPos.X, 0, e.visPos.Z)).Magnitude
			if d < bestD then
				best, bestD = r.Position, d
			end
		end
	end
	if not best then
		return nil
	end
	local rel = math.atan2(-(best.X - e.visPos.X), -(best.Z - e.visPos.Z)) - e.visYaw
	rel = (rel + math.pi) % (2 * math.pi) - math.pi
	if math.abs(rel) > math.rad(110) then
		return nil -- A2-M1: 등 뒤는 안 본다(±180°에서 각이 뒤집혀 목 · 허리가 한 번에 반대로 돌았다) - 가중치가 줄며 두리번으로
	end
	return math.deg(rel)
end

-- 2차 움직임: 사슬 밑동이 몸 이동(가속)을 늦게 따라온다 - 감쇠 스프링
local function stepSprings(e, dt, accelLocal)
	for i, chain in ipairs(e.rig.chains or {}) do
		local s = e.springs[i]
		local lag = chain.lag or 0.5
		local k, c = 60 * (1 - lag * 0.6), 7
		local tx, tz = math.clamp(accelLocal.Z * 0.9, -35, 35), math.clamp(-accelLocal.X * 0.9, -35, 35)
		s.vx += (k * (tx - s.x) - c * s.vx) * dt
		s.vz += (k * (tz - s.z) - c * s.vz) * dt
		s.x += s.vx * dt
		s.z += s.vz * dt
	end
end

-- BR1-4c c-7 돌진 전조 "노려봄": 눈이 붉게 빛나고(세기 = 전조 진행) 코에서 콧김 먼지
local GLARE = Color3.fromRGB(255, 40, 30)
local SNORT = Color3.fromRGB(235, 228, 214)
local function applyGlare(e, info, now)
	local eyes = e.model:FindFirstChild("Eyes")
	if not eyes or (e.ctx.set and e.ctx.set.face) then -- GUARDIAN-V2: 표정 있는 새 몸 = 화남 눈 모양이 노려봄을 대신(눈 색 그대로 · 빨강 금지)
		return
	end
	e.eyeColor = e.eyeColor or eyes.Color
	local g = info.glare or 0
	eyes.Color = e.eyeColor:Lerp(GLARE, math.clamp(g * 1.4, 0, 1))
	if g > 0.2 and now - (e.lastSnort or 0) > 0.45 then
		e.lastSnort = now
		local mouth = e.model:FindFirstChild("Rig_Mouth", true)
		if mouth and mouth:IsA("Attachment") then
			local out = mouth.WorldCFrame.LookVector
			BossFx.puff(mouth.WorldPosition + out * 1.5, 1.5 + g * 2, SNORT, 0.5, (out * 6 + Vector3.new(0, 2, 0)))
		end
	end
end

local function applyFlash(e, info)
	local part = info.flash == "weapon" and e.weapon or (info.flash and e.model:FindFirstChild(info.flash))
	if e.flashPart and e.flashPart ~= part then
		e.flashPart.Color, e.flashPart.Material = e.flashColor, e.flashMaterial
		e.flashPart = nil
	end
	if part and (info.flashAmount or 0) > 0 then
		if not e.flashPart then
			e.flashPart, e.flashColor, e.flashMaterial = part, part.Color, part.Material
		end
		part.Material = Enum.Material.Neon
		part.Color = e.flashColor:Lerp(Color3.new(1, 1, 1), math.clamp(info.flashAmount, 0, 1))
	elseif e.flashPart then
		e.flashPart.Color, e.flashPart.Material = e.flashColor, e.flashMaterial
		e.flashPart = nil
	end
end

-- GUARDIAN-V3 손 수정 발광: info.glow = 부위 이름들 · glowAmount 0 ~ 1 → 부위마다 Highlight(보라 채움 · 테 - 위험색 아님) · 흰 테(rim)가 켜진 부위는 끈다
local function applyGlow(e, info)
	e.glows = e.glows or {}
	local on = {}
	local G = e.ctx.glow
	local rimOn = {}
	if info.rim and (info.rimAmount or 0) > 0 then
		for _, name in ipairs(info.rim) do
			rimOn[name] = true
		end
	end
	if G and info.glow and (info.glowAmount or 0) > 0 then
		for _, name in ipairs(info.glow) do
			local part = e.model:FindFirstChild(name)
			if part and part:IsA("BasePart") and not rimOn[name] then
				on[name] = true
				local h = e.glows[name]
				if not h or not h.Parent then
					h = Instance.new("Highlight")
					h.Name = "CrystalGlow_" .. name
					h.FillColor, h.OutlineColor = G.color, G.color
					h.DepthMode = Enum.HighlightDepthMode.Occluded
					h.Adornee = part
					h.Parent = e.model
					e.glows[name] = h
				end
				h.Enabled = true
				h.FillTransparency = 1 - G.fillPeak * info.glowAmount
				h.OutlineTransparency = 1 - (1 - G.outline) * info.glowAmount
			end
		end
	end
	for name, h in pairs(e.glows) do
		if not on[name] and h.Enabled then
			h.Enabled = false
		end
	end
end

-- BOSS-FRAMEWORK 5 번쩍(새 몸): info.rim = 때리는 부위 이름들 · rimAmount 0 ~ 1 → 부위마다 Highlight(흰 테 + 옅은 흰 채움 · 위험색 아님) · 판정 시각에 꺼짐
local function applyRim(e, info)
	e.rims = e.rims or {}
	local on = {}
	if info.rim and (info.rimAmount or 0) > 0 then
		local F = FrameData.flash
		for _, name in ipairs(info.rim) do
			local part = e.model:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				on[name] = true
				local h = e.rims[name]
				if not h or not h.Parent then
					h = Instance.new("Highlight")
					h.Name = "RimFlash_" .. name
					h.FillColor, h.OutlineColor = F.color, F.color
					h.DepthMode = Enum.HighlightDepthMode.Occluded
					h.Adornee = part
					h.Parent = e.model
					e.rims[name] = h
				end
				h.Enabled = true
				h.OutlineTransparency = F.outline
				h.FillTransparency = 1 - F.fillPeak * info.rimAmount
			end
		end
	end
	for name, h in pairs(e.rims) do
		if not on[name] and h.Enabled then
			h.Enabled = false
		end
	end
end

-- BR1-4c c-5 헤롱 별: 머리 위를 빙빙 도는 별 3개(쓰러진 보스 · 전시 리그 사망)
local STAR = Color3.fromRGB(255, 230, 90)
local function updateStars(e, show, now)
	if not show then
		if e.stars then
			for _, p in ipairs(e.stars) do
				p:Destroy()
			end
			e.stars = nil
		end
		return
	end
	local head = e.model:FindFirstChild("Head")
	if not head then
		return
	end
	if not e.stars then
		e.stars = {}
		for i = 1, 3 do
			local p = Instance.new("Part")
			p.Name = "DizzyStar"
			p.Shape = Enum.PartType.Ball
			p.Size = Vector3.one * 0.35 * e.S
			p.Material = Enum.Material.Neon
			p.Color = STAR
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
			p.Parent = e.model
			e.stars[i] = p
		end
	end
	local r = head.Size.X * 0.75
	for i, p in ipairs(e.stars) do
		local a = now * 5 + i * (2 * math.pi / 3)
		p.Position = head.Position + Vector3.new(math.cos(a) * r, head.Size.Y * 0.8 + math.sin(now * 7 + i) * 0.1 * e.S, math.sin(a) * r)
	end
end

-- 막타 순간 카메라가 살짝 당겨졌다 돌아옴(화면만 - 슬로모션 동안)
local function deathZoom(position)
	local camera = Workspace.CurrentCamera
	if not camera or camera.CameraType ~= Enum.CameraType.Custom or (camera.CFrame.Position - position).Magnitude > 180 then
		return
	end
	local fov = camera.FieldOfView
	local TweenService = game:GetService("TweenService")
	TweenService:Create(camera, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = fov * 0.82 }):Play()
	task.delay(1.2, function()
		TweenService:Create(camera, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { FieldOfView = fov }):Play()
	end)
end

-- 사망: 서버 모델은 곧 지워진다 → 보이는 몸을 복제해 이 클라에서 쓰러뜨리고 사라지게
local function startDeathClone(e)
	if e.deathClone or not e.model.Parent then
		return
	end
	local ok, clone = pcall(function()
		return e.model:Clone()
	end)
	if not ok or not clone then
		return
	end
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BillboardGui") or d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Humanoid") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanQuery, d.CanTouch = false, false
		end
	end
	clone:SetAttribute("BossRig", nil)
	CollectionService:RemoveTag(clone, "Monster")
	clone.Name = "BossDeathClone"
	clone.Parent = Workspace
	for _, d in ipairs(e.model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = 1
		end
	end
	local motors = {}
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("Motor6D") then
			motors[d.Name] = d
		end
	end
	local ce = {
		model = clone, rigId = e.rigId, bossId = e.bossId, rig = e.rig, root = clone:FindFirstChild("HumanoidRootPart"), motors = motors, S = e.S, ctx = e.ctx, rest = e.rest,
		st = { deadAt = e.st.deadAt, form = e.form }, spring = e.spring, visPos = e.visPos, visYaw = e.visYaw, groundY = e.groundY, gait = 0, speed = 0, turn = 0, springs = e.springs, lastUpdate = 0, hpRatio = 0,
		isClone = true, baseTransparency = {},
	}
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BasePart") then
			ce.baseTransparency[d] = d.Transparency
		end
	end
	e.deathClone = ce
	rigs[clone] = ce
	deathZoom(e.visPos)
end

-- A2-M1 측정 보조(판정 무관): 의도된 타격 창(접촉 − 0.03 ~ 접촉 + 히트스톱 + 0.25)을 모델 Attribute ClientImpacts에 적는다(이 클라에만 - client/A2M1Probe가 튐 검출에서 뺀다).
local impactKeys = { "actAt", "swingAt", "flinchAt", "stunAt", "pickAt", "throwAt", "hopAt", "deadAt" }
local function noteImpacts(e, st)
	e.seen = e.seen or {}
	e.fxQueue = e.fxQueue or {}
	local changed = false
	local w = e.rig.weight or 1
	local function push(a, b)
		e.impacts = e.impacts or {}
		table.insert(e.impacts, ("%.3f,%.3f"):format(a, b))
		if #e.impacts > 12 then
			table.remove(e.impacts, 1)
		end
		changed = true
	end
	-- 등장: 솟기 시작 · 착지 · 포효 접촉 = 의도된 타격 순간(오프라인 하네스와 같은 창)
	if st.introAt and st.introAt ~= e.seen.introAt then
		e.seen.introAt = st.introAt
		if st.introFull and st.introSeconds then
			local I = (e.ctx.boss and e.ctx.boss.intro) or {}
			local riseT = st.introSeconds * (I.riseFrac or 0.42)
			local roarContact = st.introAt + riseT + 0.05 + 0.35
			push(st.introAt - 0.03, st.introAt + 0.06)
			push(st.introAt + riseT - 0.06, st.introAt + riseT + 0.12)
			push(roarContact - 0.47, roarContact + 0.35)
		elseif st.introSeconds then
			push(st.introAt + 0.5 - 0.15, st.introAt + 0.5 + 0.35)
		end
	end
	for _, k in ipairs(impactKeys) do
		local v = st[k]
		if v and v ~= e.seen[k] then
			e.seen[k] = v
			if k == "actAt" and st.act then
				local skill = e.ctx.skills and e.ctx.skills[st.act]
				local clipName = BossMotion.clipNameForSkill(e.rigId, e.rig, st.act, skill, e.form)
				local clip = BossMotion.clip(e.rigId, e.rig, clipName or "")
				local hit = st.actHit or 0
				local slot = soundsOf(e).skills and soundsOf(e).skills[st.act] -- BOSS-FRAMEWORK 6 소리 자리(전조 시작 · 접촉)
				if slot then
					playSlot(e, slot.windup)
				end
				if clip then
					local contact = v + BossMotion.contactTime(clip, hit)
					push(v + BossMotion.clipKeys(clip, hit).preEnd - 0.03, contact + (clip.hitstop or 0) * w + 0.25)
					table.insert(e.fxQueue, { at = contact, clip = clipName, sound = slot and slot.hit })
				end
			elseif k == "swingAt" then
				push(v - 0.03, v + 0.07 + 0.04 * w + 0.25)
				table.insert(e.fxQueue, { at = v + 0.07, clip = (st.swingN or 0) % 2 == 0 and "basic_R" or "basic_L" })
			elseif k == "hopAt" then
				push(v + (st.hopSeconds or 0) - 0.35, v + (st.hopSeconds or 0) + 0.35)
				table.insert(e.fxQueue, { at = v + (st.hopSeconds or 0), clip = "hopSlam" })
			elseif k == "deadAt" then
				local Dd = e.ctx.plan.death
				local slowEnd = Dd.slowSeconds and (Dd.slowSeconds + (Dd.hitstopAt - Dd.slowSeconds * Dd.slowRate)) or Dd.hitstopAt
				push(v - 0.03, v + 0.15)
				push(v + slowEnd - 0.05, v + slowEnd + 0.3)
			else
				push(v - 0.03, v + (k == "pickAt" and 0.35 or 0.14))
			end
		end
	end
	-- BOSS-FRAMEWORK 4 변신 접촉(가슴 치기 · 수정 폭발) = 의도된 빠른 구간 · 몸 효과
	local TF = e.ctx.set and e.ctx.set.transform
	if TF and st.transformAt and st.transformAt ~= e.seen.transformAt then
		e.seen.transformAt = st.transformAt
		push(st.transformAt + TF.hit - 0.03, st.transformAt + TF.hit + 1.15)
		table.insert(e.fxQueue, { at = st.transformAt + TF.hit, clip = TF.clip })
		table.insert(e.fxQueue, { at = st.transformAt + TF.hit + 0.72, transformBurst = true })
	end
	if st.throwPlan and st.throwPlan ~= e.seen.throwPlan then
		e.seen.throwPlan = st.throwPlan
		push(st.throwPlan - 0.12, st.throwPlan + 0.35)
		table.insert(e.fxQueue, { at = st.throwPlan, clip = e.ctx.boss and e.ctx.boss.throw or "throw_overhead" })
	end
	if changed then
		e.model:SetAttribute("ClientImpacts", table.concat(e.impacts, ";"))
	end
end

-- A2-M1 세밀 장식 LOD: 폰 = DETAIL_LOD.phoneStuds 밖 · PC = pcStuds 밖이면 숨김(0.5초마다 판정)
local DETAIL_LOD = { phoneStuds = 55, pcStuds = 150 }
local UserInputService = game:GetService("UserInputService")
local function isPhone()
	local cam = Workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
	return (UserInputService.TouchEnabled and math.min(vp.X, vp.Y) < 500) or Players.LocalPlayer:GetAttribute("A2M1ForcePhone") == true -- 측정용 강제(Studio)
end
local function updateDetailLod(e, distance, now)
	if not e.lod2 or #e.lod2 == 0 or (e.lodAt and now - e.lodAt < 0.5) then
		return
	end
	e.lodAt = now
	local hide = distance > (isPhone() and DETAIL_LOD.phoneStuds or DETAIL_LOD.pcStuds)
	if hide ~= e.lodHidden then
		e.lodHidden = hide
		for _, p in ipairs(e.lod2) do
			if p.Parent then
				p.LocalTransparencyModifier = hide and 1 or 0
			end
		end
	end
end

local function updateEntry(e, now, dt, camPos)
	local m, root = e.model, e.root
	if not root or not root.Parent then
		return
	end
	if e.preview then
		e.previewStep(e, now, dt)
		if not e.model.Parent then
			return
		end
	elseif not e.isClone then
		readState(e, now)
		-- A2-N4 §3-3(A2-N3 결정 ④): 평타 예비 동안 약한 흰 번쩍임(팔이 화면 밖이어도 전조가 읽히게 - 겉모습만)
		local prepAt, flash = e.st.prepAt, BossMotionData.prepFlash
		local prepLead = e.st.prepSeconds or BossData.basicPrepSeconds
		local u = prepAt and flash and (now - (prepAt - prepLead)) / prepLead
		if u and u >= 0 and u <= 1 then
			if not e.prepHighlight then
				local h = Instance.new("Highlight")
				h.Name = "PrepFlash"
				h.FillColor, h.OutlineTransparency = flash.color, 1
				h.DepthMode = Enum.HighlightDepthMode.Occluded
				h.Adornee = e.model
				h.Parent = e.model
				e.prepHighlight = h
			end
			e.prepHighlight.Enabled = true
			e.prepHighlight.FillTransparency = 1 - flash.peak * math.sin(math.pi * u)
		elseif e.prepHighlight and e.prepHighlight.Enabled then
			e.prepHighlight.Enabled = false
		end
		if e.st.deadAt then
			startDeathClone(e)
			return
		end
	end
	-- 보간(서버 루트 → 보이는 루트): 위치 · 방향(yaw만 - 헤롱 기울임은 몸 모션으로)
	local target = root.Position
	local stunned = e.st.stunUntil and now < e.st.stunUntil
	if not stunned and not e.isClone then
		e.groundY = target.Y
	end
	if stunned then
		target = Vector3.new(target.X, e.groundY, target.Z) -- 서버 헤롱은 1.2 내려 앉힌다 - 주저앉기 모션이 대신
	end
	local prev = e.visPos
	-- A2-M1 보간: 1차 지수(옛 - 복제 틱마다 속도가 톱니처럼 튐) → 2차 임계 감쇠 스프링(속도 연속) + 복제 틱 사이 속도 보정(스프링 지연만큼 앞쪽 = 서버 자리와 어긋나지 않게)
	local I = BossMotionData.interp
	local clock = os.clock()
	if not e.lastTarget or (target - e.lastTarget).Magnitude > 1e-3 then
		local gap = e.lastTargetAt and clock - e.lastTargetAt or 0
		if e.lastTarget and gap > 0.004 and gap < 0.5 and (target - e.lastTarget).Magnitude < 30 then
			e.estVel = (e.estVel or Vector3.zero):Lerp((target - e.lastTarget) / gap, I.velBlend)
		end
		e.lastTarget, e.lastTargetAt = target, clock
	elseif clock - e.lastTargetAt > I.staleSeconds then
		e.estVel = (e.estVel or Vector3.zero) * math.exp(-dt * I.stopDecay) -- 서버가 멈췄다 - 예측을 빨리 거둔다(지나쳤다 돌아오는 폭 최소)
	end
	local lead = math.min(clock - e.lastTargetAt, I.maxLeadSeconds) + I.springLeadFraction * 2 / I.omega
	local goal = target + (e.estVel or Vector3.zero) * lead
	if (target - prev).Magnitude > 30 then
		e.visPos = target -- 순간 이동(복귀 · 잡기 곁 순간 이동)은 보간하지 않는다
		e.visVel = Vector3.zero
	else
		local h = math.min(dt, 1 / 20)
		local w = I.omega
		e.visVel = (e.visVel or Vector3.zero) + (w * w * (goal - prev) - 2 * w * (e.visVel or Vector3.zero)) * h
		e.visPos = prev + e.visVel * h
	end
	local yawT = yawOf(root.CFrame)
	-- A2-N4 P0-1: 서버 루트 yaw 0 = 추격 · 패턴이 방향을 안 정했다(PivotTo(CFrame.new)) → 옛 = 늘 월드 −Z를 봤다.
	--   보이는 방향 = 움직이면 가는 쪽 · 서 있으면 대상(BossFaceUserId) 쪽 · 없으면 그대로. 루트를 돌린 패턴(잡기 · 오르골 · 모래 탐색)은 루트 방향 그대로.
	if not e.isClone and math.abs(yawT) < 1e-3 then
		local v = e.estVel or Vector3.zero
		local flat = Vector3.new(v.X, 0, v.Z)
		if flat.Magnitude > BossMotionData.faceMoveMinSpeed then
			yawT = math.atan2(-flat.X, -flat.Z)
		else
			local uid = e.model:GetAttribute("BossFaceUserId")
			local p = uid and Players:GetPlayerByUserId(uid)
			local r = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			local d = r and Vector3.new(r.Position.X - e.visPos.X, 0, r.Position.Z - e.visPos.Z)
			yawT = (d and d.Magnitude > 0.5) and math.atan2(-d.X, -d.Z) or e.visYaw
		end
	end
	-- BOSS-NIGHT-1(매머드 v3.lockFacing): 서버가 스킬 시작 순간 고정한 방향(BossFaceLockYaw) - 스킬 동안 몸이 대상을 따라 돌지 않는다(등 뒤가 생긴다 · 뒷발차기)
	local lockYaw = not e.isClone and e.model:GetAttribute("BossFaceLockYaw")
	if lockYaw then
		yawT = lockYaw
	end
	-- A2-M1 등장 동안 보이는 몸은 나(파티) 쪽을 본다(서버 루트 방향 = 판정은 그대로 - 스폰 방향이 입장 반대쪽이라 옛 연출은 등을 보였다). 등장 첫 프레임은 바로 그 방향으로.
	local st0 = e.st
	if st0.introAt and st0.introSeconds and now < st0.introAt + st0.introSeconds + 0.15 then
		local me = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
		if me then
			yawT = math.atan2(-(me.Position.X - e.visPos.X), -(me.Position.Z - e.visPos.Z))
			if e.introYawStamp ~= st0.introAt then
				e.introYawStamp = st0.introAt
				e.visYaw = yawT
			end
		end
	end
	-- QUEUE-ALL1 01 C-2: 꼬리로 대상 쪽을 치는 스킬(BossMotionData.tailToTarget - 심해 군주 꼬리 반원) = 보이는 몸을 대상 반대로 돌려 꼬리가 대상 쪽으로 휘두른다(판정 · 서버 루트 그대로)
	if st0.act and BossMotionData.tailToTarget and BossMotionData.tailToTarget[st0.act] then
		yawT += math.pi
	end
	local dy = (yawT - e.visYaw + math.pi) % (2 * math.pi) - math.pi
	local prevYaw = e.visYaw
	e.visYaw += dy * (1 - math.exp(-dt * 10))
	local moved = Vector3.new(e.visPos.X - prev.X, 0, e.visPos.Z - prev.Z)
	local speedNow = moved.Magnitude / math.max(dt, 1e-3)
	e.speed += (speedNow - e.speed) * (1 - math.exp(-dt * 8))
	e.turn += (((e.visYaw - prevYaw + math.pi) % (2 * math.pi) - math.pi) / math.max(dt, 1e-3) - e.turn) * (1 - math.exp(-dt * 6))
	local stride = (BossMotion.walkFor(e.ctx, e.form).stride or 0.7) * e.S * BossMotion.strideScale(e.ctx, e.speed) -- A2-M1: 달릴수록 보폭이 는다(BossMotion과 같은 배율 - 발 미끄러짐 없음) · BOSS-FRAMEWORK: 세트 보폭
	local prevGait = e.gait
	e.gait = (e.gait + moved.Magnitude / (2 * stride)) % 1
	-- A2-M1 발 디딤(걸음 위상 0.25 = 왼발 · 0.75 = 오른발이 땅에 닿는 순간) → 먼지 · 무거운 보스는 작은 흔들림
	local fourLeg = e.ctx.set and e.form ~= nil and (e.ctx.set.forms[e.form].gait == "knuckle" or e.ctx.set.forms[e.form].gait == "quad")
	if e.speed > 1.5 and e.rig.plan == "biped" and not e.isClone then
		local function crossed(p)
			if prevGait <= e.gait then
				return prevGait < p and e.gait >= p
			end
			return p > prevGait or p <= e.gait
		end
		if crossed(0.25) then
			e.stepFeet = e.stepFeet or {}
			table.insert(e.stepFeet, "Foot_L")
		end
		if crossed(0.75) then
			e.stepFeet = e.stepFeet or {}
			table.insert(e.stepFeet, "Foot_R")
		end
		if fourLeg then -- BOSS-FRAMEWORK 2: 너클 · 네 발 = 앞발(주먹)도 디딘다(위상 0.5 · 0 - 0은 한 바퀴 넘어갈 때)
			if crossed(0.5) then
				e.stepFeet = e.stepFeet or {}
				table.insert(e.stepFeet, "Hand_L")
			end
			if crossed(0) then
				e.stepFeet = e.stepFeet or {}
				table.insert(e.stepFeet, "Hand_R")
			end
		end
	end

	-- LOD
	local distance = (camPos - e.visPos).Magnitude
	if not e.isClone then
		updateDetailLod(e, distance, now)
	end
	if distance > LOD.farStuds and not e.isClone then
		return
	end
	if distance > LOD.fullStuds and now - e.lastUpdate < 1 / LOD.reducedHz and not e.isClone then
		return
	end
	local t0 = os.clock()
	local st = e.st
	st.speed, st.gait, st.turn = e.speed, e.gait, e.turn
	-- A2-M1 겹침 지연 표본은 가까울 때만(먼 보스는 비용 절약) · 잡기 중에는 끔(서버 잡기 FK와 같은 부착점 - server/BossAirGrab도 끈다)
	st.noOverlap = distance > LOD.fullStuds or (st.act ~= nil and e.ctx.skills ~= nil and e.ctx.skills[st.act] ~= nil and e.ctx.skills[st.act].primitive == "grab")
	local lookT = distance <= LOD.fullStuds and lookYawFor(e) or nil
	if lookT then
		e.lookSmooth = (e.lookSmooth or lookT) + (lookT - (e.lookSmooth or lookT)) * (1 - math.exp(-dt * 6))
	end
	-- A2-M1: 대상이 생기고 사라질 때 가중치를 천천히(0.3초 남짓) - 마지막 바라본 각에서 두리번으로 넘어간다
	e.lookW = (e.lookW or 0) + ((lookT and 1 or 0) - (e.lookW or 0)) * (1 - math.exp(-dt * 7))
	st.lookYaw = (e.lookW > 1e-3 and e.lookSmooth) or nil
	st.lookW = e.lookW
	local pose, info = BossMotion.evaluate(e.ctx, st, now)
	e.form = info.form -- BOSS-FRAMEWORK: 지금 세트(보폭 · 발 디딤 · 사망 복제가 쓴다)
	noteImpacts(e, st)
	-- A2-M1 몸 효과: 접촉 순간 충격(가까울 때만) · 등장 · 등장 포효
	if not e.isClone then
		for i = #e.fxQueue, 1, -1 do
			local q = e.fxQueue[i]
			if now >= q.at then
				table.remove(e.fxQueue, i)
				if now - q.at < 0.3 and distance <= LOD.fullStuds then
					if q.transformBurst then
						BossBodyFx.transformBurst(e) -- BOSS-FRAMEWORK 4 등 수정 폭발 조각
					else
						BossBodyFx.impact(e, q.clip)
					end
				end
				if now - q.at < 0.3 then
					playSlot(e, q.sound)
				end
			end
		end
		if info.intro then
			e.introStamp = st.introAt
			e.introActive = true
			BossBodyFx.intro(e, info.intro)
			if info.intro.roarAt and now >= info.intro.roarAt and e.introRoared ~= st.introAt then
				e.introRoared = st.introAt
				BossBodyFx.impact(e, e.ctx.plan.introRoar or "roar")
				playSlot(e, soundsOf(e).roar)
			end
		elseif e.introActive then
			e.introActive = false
			BossBodyFx.introEnd(e)
		end
		if e.stepFeet then
			for _, foot in ipairs(e.stepFeet) do
				BossBodyFx.footstep(e, foot)
				playSlot(e, soundsOf(e).step, e.model:FindFirstChild(foot))
			end
			e.stepFeet = nil
		end
	end

	-- 2차 움직임 스프링(가까울 때만 · 잡기 중에는 끔 - 서버 FK와 같은 꼬리 자리)
	local grabbing = st.act and e.ctx.skills and e.ctx.skills[st.act] and e.ctx.skills[st.act].primitive == "grab"
	if distance <= LOD.fullStuds and not grabbing then
		local accelWorld = (moved / math.max(dt, 1e-3) - (e.lastVel or Vector3.zero)) / math.max(dt, 1e-3)
		e.lastVel = moved / math.max(dt, 1e-3)
		local yawCf = CFrame.Angles(0, e.visYaw, 0)
		local accelLocal = yawCf:VectorToObjectSpace(accelWorld) * 0.05
		if e.spring then
			BossSpring.apply(e.spring, pose, dt, accelLocal, e.turn) -- BOSS-FRAMEWORK 3 새 몸 = 마디별 스프링(폰 · lite 절반 갱신)
		else
			stepSprings(e, dt, accelLocal)
			for i, chain in ipairs(e.rig.chains or {}) do
				local s = e.springs[i]
				for j, joint in ipairs(chain) do
					local v = pose[joint] or { 0, 0, 0, 0, 0, 0 }
					pose[joint] = { (v[1] or 0) + s.x * (j == 1 and 1 or 0.35), v[2] or 0, (v[3] or 0) + s.z * (j == 1 and 1 or 0.35), v[4] or 0, v[5] or 0, v[6] or 0 }
				end
			end
		end
	end
	-- 눈 모양(기절 · 사망 = 빙글) - A2-M1: 한 프레임에 돌지 않고 0.1초 남짓 굴러간다(튐 없음)
	local eyeT = info.eyes or { 0, 0, 0 }
	e.eyeCur = e.eyeCur or { 0, 0, 0 }
	if not e.eyeTo or e.eyeTo[1] ~= eyeT[1] or e.eyeTo[2] ~= eyeT[2] or e.eyeTo[3] ~= eyeT[3] then
		e.eyeFrom, e.eyeTo, e.eyeAt = { e.eyeCur[1], e.eyeCur[2], e.eyeCur[3] }, { eyeT[1], eyeT[2], eyeT[3] }, now
	end
	local ek = BossMotion.ease("sine", (now - e.eyeAt) / 0.2) -- 시작 · 끝 속도 0(옛 지수 따라가기는 첫 프레임이 가장 빨랐다)
	for i = 1, 3 do
		e.eyeCur[i] = e.eyeFrom[i] + (e.eyeTo[i] - e.eyeFrom[i]) * ek
	end
	if math.abs(e.eyeCur[1]) + math.abs(e.eyeCur[2]) + math.abs(e.eyeCur[3]) > 0.05 then
		pose.Eyes = { e.eyeCur[1], e.eyeCur[2], e.eyeCur[3], 0, 0, 0 }
	end

	-- GUARDIAN-V2 표정: 눈 Neon 모양 3개 중 하나만 보인다(바뀔 때만 · LocalTransparencyModifier - 사망 사라짐 연출의 Transparency와 따로). 그 모양 메시가 없으면(상자 몸) 평소 눈 그대로.
	local FaceSpec = e.ctx.set and e.ctx.set.face
	if FaceSpec and info.face ~= e.face then
		local want = FaceSpec.eyes[info.face or "normal"]
		if not (want and e.model:FindFirstChild(want)) then
			want = FaceSpec.eyes.normal
		end
		for _, partName in pairs(FaceSpec.eyes) do
			local p = e.model:FindFirstChild(partName)
			if p and p:IsA("BasePart") then
				p.LocalTransparencyModifier = partName == want and 0 or 1
			end
		end
		e.face = info.face
	end

	-- 쓰기: RootJoint = 보간 오프셋 · 자세
	local transforms = BossMotion.toTransforms(e.rest, e.S, pose)
	-- BR1-4c c-10 발 접지: 가장 낮은 발바닥을 기준 높이(발 −1.5)에 맞춘다(뜬 발 · 바닥 관통 없음) - 뛰어오른 동작 · 사망은 뺀다 · 부드럽게 · 한도 ±0.6 단위
	local fix = 0
	local feet = e.rig.feet
	if info.contacts and e.rig.contactAt then -- BOSS-FRAMEWORK 2: 세트 접지 부위(너클 = 발 + 주먹)
		if e.contactsFor ~= info.contacts then
			e.contactsFor, e.contactList = info.contacts, {}
			for _, name in ipairs(info.contacts) do
				local at = e.rig.contactAt[name]
				if at then
					table.insert(e.contactList, { part = name, at = at })
				end
			end
		end
		feet = e.contactList
	end
	if feet and #feet > 0 and not info.airborne and not st.deadAt and distance <= LOD.fullStuds then
		local frames = BossRig.solve(e.rig, CFrame.identity, e.S, transforms)
		local minY = math.huge
		for _, f in ipairs(feet) do
			local cf = frames[f.part]
			if cf then
				minY = math.min(minY, (cf * CFrame.new(f.at * e.S)).Position.Y)
			end
		end
		if minY < math.huge then
			fix = math.clamp(-1.5 * e.S + BossRig.rootLift(e.rig, e.S) - minY, -0.6 * e.S, 0.6 * e.S) -- A2-M1: 접지 리그는 발 기준 = 루트 − 1.5(stud)
		end
	end
	e.footFix = (e.footFix or 0) + (fix - (e.footFix or 0)) * (1 - math.exp(-dt * 20))
	if math.abs(e.footFix) > 1e-3 then
		transforms.RootJoint = CFrame.new(0, e.footFix, 0) * (transforms.RootJoint or CFrame.identity)
	end
	local rootMotor = e.motors.RootJoint
	if rootMotor then
		local visual = CFrame.new(e.visPos) * CFrame.Angles(0, e.visYaw, 0)
		local offset = rootMotor.C0:Inverse() * root.CFrame:Inverse() * visual * rootMotor.C0
		rootMotor.Transform = offset * (transforms.RootJoint or CFrame.identity)
		transforms.RootJoint = nil
	end
	for name, motor in pairs(e.motors) do
		if name ~= "RootJoint" then
			motor.Transform = transforms[name] or CFrame.identity
		end
	end
	if not e.isClone then
		if e.ctx.set then
			applyGlow(e, info) -- GUARDIAN-V3 손 수정 발광(예비 동작 내내 - 흰 테가 켜진 부위는 흰 테가 덮는다)
			applyRim(e, info) -- BOSS-FRAMEWORK 5 때리는 부위 흰 테(옛 무기 번쩍 대신)
		else
			applyFlash(e, info)
		end
		applyGlare(e, info, now)
	end
	if e.isClone or e.preview then
		updateStars(e, info.stars and (info.fade or 0) < 1, now)
		if info.dead then
			BossBodyFx.death(e, info) -- A2-M1 X X 눈 · 빛으로 흩어짐 · 보상 빛 폭발
		end
	end
	if (e.isClone or e.preview) and info.fade then
		for part, base in pairs(e.isClone and e.baseTransparency or e.preview.baseTransparency) do
			if part.Parent then
				part.Transparency = base + (1 - base) * info.fade
			end
		end
		if e.isClone and info.fade >= 1 then
			rigs[m] = nil
			m:Destroy()
			return
		end
	end
	e.lastUpdate = now
	stats.seconds += os.clock() - t0
	stats.updates += 1
end

-- 잡힌 사람을 보이는 부착점에 붙인다(서버도 같은 FK 자리에 둔다 - 복제 지연 동안 손에서 떨어져 보이지 않게)
local HANG = BossRigSpec.holdHangStuds
local held = {} -- [Player] = { marker, collide = { [part] = CanCollide } } - 4b-5: 잡힌 캐릭터 충돌 끔 · 머리 위 색 표식(자리마다 색)
local function markerColor(slot)
	for _, slots in pairs(BossRigSpec.holdSlots) do
		local i = table.find(slots, slot)
		if i then
			return BossRigSpec.holdMarkColors[(i - 1) % #BossRigSpec.holdMarkColors + 1]
		end
	end
	return BossRigSpec.holdMarkColors[1]
end
local function releaseHeld(p)
	local h = held[p]
	if not h then
		return
	end
	held[p] = nil
	for part, was in pairs(h.collide) do
		if part.Parent then
			part.CanCollide = was
		end
	end
	if h.marker then
		h.marker:Destroy()
	end
end
local function pinHeld()
	for _, p in ipairs(Players:GetPlayers()) do
		local slot = p:GetAttribute("BossHoldSlot")
		local character = p.Character
		local root = slot and character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local best = nil
			for model, e in pairs(rigs) do
				if not e.isClone and not e.preview and model:GetAttribute("BossRig") and (not best or (model:GetPivot().Position - root.Position).Magnitude < (best.model:GetPivot().Position - root.Position).Magnitude) then
					best = e
				end
			end
			local att = best and best.model:FindFirstChild("Rig_" .. slot, true)
			if att and att:IsA("Attachment") then
				root.CFrame = CFrame.new(att.WorldPosition - Vector3.new(0, HANG, 0)) * root.CFrame.Rotation
			end
			local h = held[p]
			if not h or h.character ~= character then
				releaseHeld(p)
				h = { character = character, collide = {} }
				for _, d in ipairs(character:GetDescendants()) do
					if d:IsA("BasePart") then
						h.collide[d] = d.CanCollide
						d.CanCollide = false
					end
				end
				local marker = Instance.new("Part")
				marker.Name = "BossHoldMarker"
				marker.Shape = Enum.PartType.Ball
				marker.Size = Vector3.new(1.2, 1.2, 1.2)
				marker.Material = Enum.Material.Neon
				marker.Color = markerColor(slot)
				marker.Anchored, marker.CanCollide, marker.CanQuery, marker.CanTouch = true, false, false, false
				marker.Parent = Workspace
				h.marker = marker
				held[p] = h
			end
			h.marker.CFrame = CFrame.new(root.Position + Vector3.new(0, 4.2, 0))
		elseif held[p] then
			releaseHeld(p)
		end
	end
end
Players.PlayerRemoving:Connect(releaseHeld)

-- ─────────────────────────── 4b-8 모션 확인(/gg boss anim) - 이 클라에만 있는 전시용 리그 ───────────────────────────
local preview = nil
local function stopPreview()
	if preview then
		rigs[preview.model] = nil
		preview.model:Destroy()
		preview = nil
	end
end

-- BOSS-FRAMEWORK: 동작 이름 앞 "after:" = 변신 뒤 세트로(새 몸 전시) · "transform" = 변신 동작
local function splitForm(action)
	local base = action:match("^after:(.+)$")
	return base or action, base and "after" or nil
end

local function cycleOf(e, action)
	local form
	action, form = splitForm(action)
	local data = BossData.bosses[e.bossId or e.rigId]
	local skill = data and data.skills[action]
	local TF = e.ctx.set and e.ctx.set.transform
	local fixed = { idle = 4, walk = 6, run = 4, basic = 3, flinch = 2.4, stun = 4.8, death = 4.4, grab = 10.1, throw = 3.2, intro = 4.2, introShort = 2.2, transform = TF and TF.seconds + 1.2 or 3 }
	if fixed[action] then
		return fixed[action]
	elseif skill then
		local clip = BossMotion.clip(e.rigId, e.rig, BossMotion.clipNameForSkill(e.rigId, e.rig, action, skill, form) or "")
		return (skill.telegraphSeconds or 1.5) + ((clip and clip.loop) and 3 or 1.8)
	end
	return 3
end

local function allActions(rigId, e)
	if e and e.ctx.set then -- BOSS-FRAMEWORK 새 몸: 변신 전 · 변신 · 변신 뒤
		local list = { "intro", "idle", "walk", "run" }
		for _, id in ipairs(e.ctx.set.signature or {}) do
			table.insert(list, id)
		end
		for _, a in ipairs({ "transform", "after:idle", "after:walk", "after:run" }) do
			table.insert(list, a)
		end
		for _, id in ipairs(e.ctx.set.signature or {}) do
			table.insert(list, "after:" .. id)
		end
		for _, a in ipairs({ "swipe", "grab", "stun", "flinch", "death" }) do
			table.insert(list, a)
		end
		return list
	end
	local boss = BossMotionData.bosses[rigId]
	local list = { "intro", "idle", "walk", "run", "basic", "swipe" }
	for _, id in ipairs(boss and boss.signature or {}) do
		table.insert(list, id)
	end
	for _, a in ipairs({ "grab", "stun", "flinch", "death" }) do
		table.insert(list, a)
	end
	return list
end

local function previewStep(e, now, dt)
	local P = e.preview
	local action = P.list[P.index]
	local freeze = localPlayer:GetAttribute("BossAnimFreeze") -- 스크린샷용: 동작 시작 뒤 이 초에 멈춘다(LocalPlayer Attribute)
	if type(freeze) == "number" then
		P.cycleAt = now - freeze
		dt = 0
	end
	local t = now - P.cycleAt
	if t >= cycleOf(e, action) then
		P.count += 1
		if P.rep and P.count >= P.rep * #P.list then
			stopPreview()
			return
		end
		P.index = P.index % #P.list + 1
		P.cycleAt = now
		t = 0
		action = P.list[P.index]
		for part, base in pairs(P.baseTransparency) do
			if part.Parent then
				part.Transparency = base
			end
		end
		BossBodyFx.resetDeath(e)
		print(("[BossAnim] %s · %s"):format(e.rigId, action))
	end
	localPlayer:SetAttribute("BossAnimAction", action) -- A2-M1 측정기가 동작별로 나눠 센다
	local st = {}
	local form
	action, form = splitForm(action)
	if e.ctx.set then
		st.form = form or (action ~= "transform" and "before" or nil)
		st.inCombat = true
	end
	local data = BossData.bosses[e.bossId or e.rigId]
	local move = data.moveSpeedStuds or 8
	local speed = 0
	if action == "walk" then
		speed = move
	elseif action == "run" then
		speed = move * 2.5
	elseif action == "basic" then
		st.swingN = math.floor(t - 0.3)
		st.swingAt = P.cycleAt + 0.3 + math.max(st.swingN, 0)
	elseif action == "flinch" then
		st.flinchAt = P.cycleAt + math.floor(t / 0.8) * 0.8
	elseif action == "stun" then
		st.stunAt, st.stunUntil = P.cycleAt + 0.2, P.cycleAt + 4.2
	elseif action == "death" then
		st.deadAt = P.cycleAt + 0.3
	elseif action == "transform" then
		st.transformAt = P.cycleAt + 0.3
	elseif action == "intro" or action == "introShort" then -- A2-M1 등장(첫 조우 3초 · 짧은 판 1.2초 - 서버 BossData.mechanics.intro와 같은 길이)
		local I = BossData.mechanics.intro
		st.introAt, st.introSeconds, st.introFull = P.cycleAt + 0.3, action == "intro" and I.firstSeconds or I.shortSeconds, action == "intro"
		st.inCombat = true
	elseif action == "grab" or action == "throw" then
		local tele = action == "grab" and 5 or 0
		st.act, st.actAt, st.actHit = "grab", P.cycleAt - (5 - tele), 5
		if action == "grab" and t > tele and t < tele + 1 then
			speed = move * 2.5
		end
		local pickT = P.cycleAt + tele + (action == "grab" and 1 or 0)
		if now >= pickT then
			st.pickAt = pickT
		end
		st.throwPlan = pickT + (action == "grab" and 2.5 or 1.2)
		if now >= st.throwPlan then
			st.throwAt, st.act = st.throwPlan, nil
		end
	else
		local hit = (data.skills[action] and data.skills[action].telegraphSeconds) or 1.5
		st.act, st.actAt, st.actHit = action, P.cycleAt + 0.3, hit
		local endAt = st.actAt + cycleOf(e, action) - 0.6
		if now > endAt then
			st.actEndAt = endAt
		end
	end
	-- 걷기 · 달리기 = 원을 돈다(발 딛기 · 방향 전환 기울임 확인)
	if speed > 0 then
		P.angle += speed * dt / P.radius
		local pos = P.center + Vector3.new(math.cos(P.angle) * P.radius, 0, math.sin(P.angle) * P.radius)
		local facing = Vector3.new(-math.sin(P.angle), 0, math.cos(P.angle))
		e.root.CFrame = CFrame.lookAt(pos, pos + facing)
	end
	e.st = st
	-- 잡기 · 던지기: 잡힌 사람 대신 막대 인형을 부착점에 매단다(4b-5 꼬리 · 손 자리 확인)
	local slots = BossRigSpec.holdSlots[e.rig.plan] or BossRigSpec.holdSlots.biped
	for i, d in ipairs(P.dummies) do
		local att = st.pickAt and not st.throwAt and e.model:FindFirstChild("Rig_" .. slots[i], true)
		d.Transparency = att and 0 or 1
		if att then
			d.CFrame = CFrame.new(att.WorldPosition - Vector3.new(0, BossRigSpec.holdHangStuds, 0))
		end
	end
end

local function startPreview(payload)
	stopPreview()
	if type(payload) ~= "table" then
		return
	end
	local rigKey = BossFramework.rigKeyFor(payload.bossId) or payload.bossId -- BOSS-FRAMEWORK: Studio 시험 스위치면 새 몸
	local rig = BossRigSpec.rigs[rigKey]
	local data = BossData.bosses[payload.bossId]
	local char = localPlayer.Character
	local myRoot = char and char:FindFirstChild("HumanoidRootPart")
	if not rig or not data or not myRoot then
		return
	end
	local S = data.visualScale or data.sizeScale or 3 -- A2-M1 덩치(켜진 보스 = sizeScale × bodyScale)
	if payload.scale then
		S = (data.sizeScale or 3) * payload.scale -- A2-M1 시범: 전시 리그만 배율 강제(/gg boss anim <보스> <동작> [반복] [배율])
	end
	if rigKey ~= payload.bossId and rig.scale then -- GUARDIAN-V2: 새 몸 크기 배율(실전 MonsterSpawner와 같은 S × scale)
		S *= rig.scale
	end
	local look = Vector3.new(myRoot.CFrame.LookVector.X, 0, myRoot.CFrame.LookVector.Z)
	local ahead = look.Magnitude > 1e-3 and look.Unit or Vector3.new(0, 0, -1)
	local ground = myRoot.Position.Y - 3
	local center = myRoot.Position + ahead * (16 + 4 * S)
	center = Vector3.new(center.X, ground + 1.5 * S - BossRig.rootLift(rig, S), center.Z) -- A2-M1: 접지 리그 = 루트 바닥 + 1.5(실전과 같은 높이)
	local model = Instance.new("Model")
	model.Name = "BossAnimPreview"
	local root = BossRig.build(model, rig, { sizeScale = S, bodyColor = data.bodyColor, headColor = data.headColor, detail = Workspace:GetAttribute("ArtStyleV1") == true }, center)
	root.CFrame = CFrame.lookAt(center, Vector3.new(myRoot.Position.X, center.Y, myRoot.Position.Z))
	model.PrimaryPart = root
	model:SetAttribute("BossRig", payload.bossId)
	if rigKey ~= payload.bossId then
		model:SetAttribute("BossRigKey", rigKey)
		-- 새 몸 전시 = KIT 메시가 캐시에 있으면 실전처럼 끼운다(옛 몸 전시는 그대로 상자)
		local ArtMeshKit = require(ReplicatedStorage.Shared.ArtMeshKit)
		if rig.meshKey and ArtMeshKit.get(rig.meshKey) then
			ArtMeshKit.applyRig(model, rig.meshKey, rigKey, S, BossRig.rootLift(rig, S))
		end
	end
	model.Parent = Workspace
	register(model)
	local e = rigs[model]
	if not e then
		model:Destroy()
		return
	end
	local list = payload.action == "all" and allActions(payload.bossId, e) or { payload.action }
	e.preview = { list = list, index = 1, rep = payload.rep, count = 0, cycleAt = serverNow(), center = center, radius = 10 + 2 * S, angle = 0, dummies = {}, baseTransparency = {} }
	e.previewStep = previewStep
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			e.preview.baseTransparency[d] = d.Transparency
		end
	end
	for i = 1, (rig.plan == "scorpion" and 3 or 2) do
		local dummy = Instance.new("Part")
		dummy.Name = "HeldDummy" .. i
		dummy.Size = Vector3.new(2, 4.5, 1)
		dummy.Anchored, dummy.CanCollide, dummy.CanQuery, dummy.CanTouch = true, false, false, false
		dummy.Color = ({ Color3.fromRGB(255, 90, 90), Color3.fromRGB(90, 200, 255), Color3.fromRGB(120, 230, 120) })[i]
		dummy.Transparency = 1
		dummy.Parent = model
		table.insert(e.preview.dummies, dummy)
	end
	preview = e
	print(("[BossAnim] 시작 %s · %s(%d동작)"):format(payload.bossId, payload.action, #list))
end

local function hookPreviewEvent(ev)
	if ev.Name == "BossAnimPreview" and ev:IsA("RemoteEvent") then
		ev.OnClientEvent:Connect(startPreview)
	end
end
if ReplicatedStorage:FindFirstChild("BossAnimPreview") then
	hookPreviewEvent(ReplicatedStorage.BossAnimPreview)
end
ReplicatedStorage.ChildAdded:Connect(hookPreviewEvent)

local function watch(model)
	if model:GetAttribute("BossRig") then
		register(model)
	end
end
for _, m in ipairs(CollectionService:GetTagged("Monster")) do
	watch(m)
end
CollectionService:GetInstanceAddedSignal("Monster"):Connect(function(m)
	task.defer(watch, m)
end)
CollectionService:GetInstanceRemovedSignal("Monster"):Connect(function(m)
	local e = rigs[m]
	if e and not e.isClone then
		if e.flashPart then
			e.flashPart.Color, e.flashPart.Material = e.flashColor, e.flashMaterial
		end
		rigs[m] = nil
	end
end)

RunService.PreSimulation:Connect(function(dt)
	local camera = Workspace.CurrentCamera
	local camPos = camera and camera.CFrame.Position or Vector3.zero
	local now = serverNow()
	for model, e in pairs(rigs) do
		if not model.Parent then
			if not e.isClone then
				rigs[model] = nil
			end
		else
			updateEntry(e, now, dt, camPos)
		end
	end
	stats.frames += 1
	if stats.frames % 120 == 0 then
		localPlayer:SetAttribute("BossAnimCostUs", stats.updates > 0 and stats.seconds / stats.frames * 1e6 or 0) -- 계측: 프레임당 모션 계산 μs(모든 보스 합)
		localPlayer:SetAttribute("BossAnimCount", stats.updates / stats.frames)
		stats.frames, stats.seconds, stats.updates = 0, 0, 0
	end
end)
RunService.PreRender:Connect(pinHeld)
