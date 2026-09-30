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

local function contextFor(rigId)
	local ctx = contexts[rigId]
	if not ctx then
		local data = BossData.bosses[rigId]
		ctx = BossMotion.context(rigId, BossRigSpec.rigs[rigId], data and data.skills, data and data.moveSpeedStuds)
		contexts[rigId] = ctx
	end
	return ctx
end

local WEAPONS = { "IceClub", "Trident", "Staff", "Scepter" }

local function register(model)
	if rigs[model] or not model:GetAttribute("BossRig") then
		return
	end
	local rigId = model:GetAttribute("BossRig")
	local rig = BossRigSpec.rigs[rigId]
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
		model = model, rigId = rigId, rig = rig, root = root, motors = motors, S = root.Size.X / 2,
		ctx = contextFor(rigId), rest = BossMotion.prepare(rig),
		st = {}, visPos = root.Position, visYaw = yawOf(root.CFrame), groundY = root.Position.Y, gait = 0, speed = 0, turn = 0,
		springs = {}, lastUpdate = 0, hpRatio = model:GetAttribute("BossHpRatio") or 1,
		weapon = weapon or model:FindFirstChild("Hand_R"),
	}
	for i in ipairs(rig.chains or {}) do
		entry.springs[i] = { x = 0, z = 0, vx = 0, vz = 0 }
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
	st.hopAt, st.hopSeconds = m:GetAttribute("BossHopAt"), m:GetAttribute("BossHopSeconds")
	st.inCombat = m:GetAttribute("BossEncounterId") ~= nil -- BR1-4c c-10: 보스전 중 기본 자세 = 전투 준비
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
	if not eyes then
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
		model = clone, rigId = e.rigId, rig = e.rig, root = clone:FindFirstChild("HumanoidRootPart"), motors = motors, S = e.S, ctx = e.ctx, rest = e.rest,
		st = { deadAt = e.st.deadAt }, visPos = e.visPos, visYaw = e.visYaw, groundY = e.groundY, gait = 0, speed = 0, turn = 0, springs = e.springs, lastUpdate = 0, hpRatio = 0,
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
	for _, k in ipairs(impactKeys) do
		local v = st[k]
		if v and v ~= e.seen[k] then
			e.seen[k] = v
			if k == "actAt" and st.act then
				local skill = e.ctx.skills and e.ctx.skills[st.act]
				local clip = BossMotion.clip(e.rigId, e.rig, BossMotion.clipNameForSkill(e.rigId, e.rig, st.act, skill) or "")
				local hit = st.actHit or 0
				if clip then
					local contact = v + BossMotion.contactTime(clip, hit)
					push(v + BossMotion.clipKeys(clip, hit).preEnd - 0.03, contact + (clip.hitstop or 0) * w + 0.25)
				end
			elseif k == "swingAt" then
				push(v - 0.03, v + 0.07 + 0.04 * w + 0.25)
			elseif k == "hopAt" then
				push(v + (st.hopSeconds or 0) - 0.35, v + (st.hopSeconds or 0) + 0.35)
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
	if st.throwPlan and st.throwPlan ~= e.seen.throwPlan then
		e.seen.throwPlan = st.throwPlan
		push(st.throwPlan - 0.12, st.throwPlan + 0.35)
	end
	if changed then
		e.model:SetAttribute("ClientImpacts", table.concat(e.impacts, ";"))
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
	local dy = (yawT - e.visYaw + math.pi) % (2 * math.pi) - math.pi
	local prevYaw = e.visYaw
	e.visYaw += dy * (1 - math.exp(-dt * 10))
	local moved = Vector3.new(e.visPos.X - prev.X, 0, e.visPos.Z - prev.Z)
	local speedNow = moved.Magnitude / math.max(dt, 1e-3)
	e.speed += (speedNow - e.speed) * (1 - math.exp(-dt * 8))
	e.turn += (((e.visYaw - prevYaw + math.pi) % (2 * math.pi) - math.pi) / math.max(dt, 1e-3) - e.turn) * (1 - math.exp(-dt * 6))
	local stride = (e.ctx.walk.stride or 0.7) * e.S
	e.gait = (e.gait + moved.Magnitude / (2 * stride)) % 1

	-- LOD
	local distance = (camPos - e.visPos).Magnitude
	if distance > LOD.farStuds and not e.isClone then
		return
	end
	if distance > LOD.fullStuds and now - e.lastUpdate < 1 / LOD.reducedHz and not e.isClone then
		return
	end
	local t0 = os.clock()
	local st = e.st
	st.speed, st.gait, st.turn = e.speed, e.gait, e.turn
	st.noOverlap = distance > LOD.fullStuds -- A2-M1 겹침 지연 표본은 가까울 때만(먼 보스는 비용 절약)
	st.lookYaw = distance <= LOD.fullStuds and lookYawFor(e) or nil
	if st.lookYaw then
		e.lookSmooth = (e.lookSmooth or 0) + (st.lookYaw - (e.lookSmooth or 0)) * (1 - math.exp(-dt * 6))
		st.lookYaw = e.lookSmooth
	end
	local pose, info = BossMotion.evaluate(e.ctx, st, now)
	noteImpacts(e, st)

	-- 2차 움직임 스프링(가까울 때만 · 잡기 중에는 끔 - 서버 FK와 같은 꼬리 자리)
	local grabbing = st.act and e.ctx.skills and e.ctx.skills[st.act] and e.ctx.skills[st.act].primitive == "grab"
	if distance <= LOD.fullStuds and not grabbing then
		local accelWorld = (moved / math.max(dt, 1e-3) - (e.lastVel or Vector3.zero)) / math.max(dt, 1e-3)
		e.lastVel = moved / math.max(dt, 1e-3)
		local yawCf = CFrame.Angles(0, e.visYaw, 0)
		local accelLocal = yawCf:VectorToObjectSpace(accelWorld) * 0.05
		stepSprings(e, dt, accelLocal)
		for i, chain in ipairs(e.rig.chains or {}) do
			local s = e.springs[i]
			for j, joint in ipairs(chain) do
				local v = pose[joint] or { 0, 0, 0, 0, 0, 0 }
				pose[joint] = { (v[1] or 0) + s.x * (j == 1 and 1 or 0.35), v[2] or 0, (v[3] or 0) + s.z * (j == 1 and 1 or 0.35), v[4] or 0, v[5] or 0, v[6] or 0 }
			end
		end
	end
	if info.eyes then
		pose.Eyes = { info.eyes[1], info.eyes[2], info.eyes[3], 0, 0, 0 }
	end

	-- 쓰기: RootJoint = 보간 오프셋 · 자세
	local transforms = BossMotion.toTransforms(e.rest, e.S, pose)
	-- BR1-4c c-10 발 접지: 가장 낮은 발바닥을 기준 높이(발 −1.5)에 맞춘다(뜬 발 · 바닥 관통 없음) - 뛰어오른 동작 · 사망은 뺀다 · 부드럽게 · 한도 ±0.6 단위
	local fix = 0
	if e.rig.feet and #e.rig.feet > 0 and not info.airborne and not st.deadAt and distance <= LOD.fullStuds then
		local frames = BossRig.solve(e.rig, CFrame.identity, e.S, transforms)
		local minY = math.huge
		for _, f in ipairs(e.rig.feet) do
			local cf = frames[f.part]
			if cf then
				minY = math.min(minY, (cf * CFrame.new(f.at * e.S)).Position.Y)
			end
		end
		if minY < math.huge then
			fix = math.clamp(-1.5 * e.S - minY, -0.6 * e.S, 0.6 * e.S)
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
		applyFlash(e, info)
		applyGlare(e, info, now)
	end
	if e.isClone or e.preview then
		updateStars(e, info.stars and (info.fade or 0) < 1, now)
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

local function cycleOf(e, action)
	local data = BossData.bosses[e.rigId]
	local skill = data and data.skills[action]
	local fixed = { idle = 4, walk = 6, run = 4, basic = 3, flinch = 2.4, stun = 4.8, death = 3.4, grab = 10.1, throw = 3.2 }
	if fixed[action] then
		return fixed[action]
	elseif skill then
		local clip = BossMotion.clip(e.rigId, e.rig, BossMotion.clipNameForSkill(e.rigId, e.rig, action, skill) or "")
		return (skill.telegraphSeconds or 1.5) + ((clip and clip.loop) and 3 or 1.8)
	end
	return 3
end

local function allActions(rigId)
	local boss = BossMotionData.bosses[rigId]
	local list = { "idle", "walk", "run", "basic", "swipe" }
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
		print(("[BossAnim] %s · %s"):format(e.rigId, action))
	end
	localPlayer:SetAttribute("BossAnimAction", action) -- A2-M1 측정기가 동작별로 나눠 센다
	local st = {}
	local data = BossData.bosses[e.rigId]
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
	local rig = BossRigSpec.rigs[payload.bossId]
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
	local look = Vector3.new(myRoot.CFrame.LookVector.X, 0, myRoot.CFrame.LookVector.Z)
	local ahead = look.Magnitude > 1e-3 and look.Unit or Vector3.new(0, 0, -1)
	local ground = myRoot.Position.Y - 3
	local center = myRoot.Position + ahead * (16 + 4 * S)
	center = Vector3.new(center.X, ground + 1.5 * S, center.Z)
	local model = Instance.new("Model")
	model.Name = "BossAnimPreview"
	local root = BossRig.build(model, rig, { sizeScale = S, bodyColor = data.bodyColor, headColor = data.headColor }, center)
	root.CFrame = CFrame.lookAt(center, Vector3.new(myRoot.Position.X, center.Y, myRoot.Position.Z))
	model.PrimaryPart = root
	model:SetAttribute("BossRig", payload.bossId)
	model.Parent = Workspace
	register(model)
	local e = rigs[model]
	if not e then
		model:Destroy()
		return
	end
	local list = payload.action == "all" and allActions(payload.bossId) or { payload.action }
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
