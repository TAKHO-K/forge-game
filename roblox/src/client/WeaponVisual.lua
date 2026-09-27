-- 무기 모델 · 플레이어 모션(W1 재작성 - 14-2 · MV1 이어서). 모든 캐릭터(나 + 남 + 검증 더미)에게 같은 코드로:
--   ① 무기 만들기: WeaponModelData(지금 메시) 또는 교체 모델(ReplicatedStorage.Shared.WeaponModels - WeaponRigCheck 통과할 때만) · WeaponRigSpec(쥐는 손 · 손잡이 점 · 쥔 방향 · 배율 · 수납 자리).
--   ② 포즈: PlayerMotionData 클립(전조 → 동작 → 회복 · 비선형 이징) · 상태(수납 · 꺼내기 · 전투 대기 · 이동 · 대시 · 활강 · 공격 · 공중 · 넘어짐 → 일어나기) 사이 blend 0.15 ~ 0.3초.
--      관절 = client/PoseRig(애니메이터 위에 가중치로 · 직접 FK · 보조 손 · 시위 IK). 루트는 안 움직인다(이동 판정 무관).
--   ③ 시각: shared/MotionTiming(서버 원거리 발사 시각과 같은 함수) · 공격 속도 배율(Player Attribute - 남의 캐릭터도 같은 값) · 타격 프레임 히트스톱.
--   남의 캐릭터: 서버 중계 AttackMotion(공격) · AirMoveFx(대시 · 일어나기) + 복제되는 Attribute(ClassId · WeaponGrade · CombatUntil · Gliding · BossEncounterId).
--   애니메이션 에셋 업로드 없음(라이브에서 그대로 돈다 - W1 보고서 ⑤).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AttackMotionData = require(ReplicatedStorage.Shared.data.AttackMotionData)
local WeaponRigSpec = require(ReplicatedStorage.Shared.data.WeaponRigSpec)
local WeaponModelData = require(ReplicatedStorage.Shared.data.WeaponModelData)
local PlayerMotionData = require(ReplicatedStorage.Shared.data.PlayerMotionData)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local MotionTiming = require(ReplicatedStorage.Shared.MotionTiming)
local WeaponRigCheck = require(ReplicatedStorage.Shared.WeaponRigCheck)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local PoseRig = require(script.Parent.PoseRig)
local AttackTrail = require(script.Parent.AttackTrail) -- W2 칼날 리본 스타일(스킨)
local TrailData = require(ReplicatedStorage.Shared.data.TrailData)
local WeaponEnhanceVisual = require(script.Parent.WeaponEnhanceVisual) -- 강화 단계 이펙트(30-0 S08 - 내 무기만) - 이 파일은 부르기만 한다

local WeaponVisual = {}

local player = Players.LocalPlayer
local M = PlayerMotionData

-- 3타 강공격(16-7): 무기 ×1.3 · 히트스톱(AttackInput이 applyHitstop으로 더 길게)
local HEAVY_WEAPON_SCALE = 1.3
local DRAW_RANGE_STUDS = 220 -- 남의 캐릭터를 이 거리 안에서만 그린다(멀면 무기 숨김 · 관절 안 건드림)

local rigs = {} -- [key(Player 또는 더미 Model)] = 상태
local current = nil -- 내 무기(WeaponEnhanceVisual · ComboGlow 호환 - { classId, model, motion, kind, instances })

-- ─────────────────────────── 무기 만들기 ───────────────────────────
local function destroyDeep(value)
	if typeof(value) == "Instance" then
		value:Destroy()
	elseif type(value) == "table" then
		for _, v in pairs(value) do
			destroyDeep(v)
		end
	end
end

-- W2 칼날 리본(TrailData.ribbon): 칼밑 ↔ 칼끝 두 부착점 사이 리본(폭 = 칼날 길이 - 대검 넓고 묵직 · 쌍검 칼마다 얇게) + 강공격 광택 리본(칼끝 ↔ 칼끝 바깥).
--   동작 구간(act)에만 켠다 · 색 · 빛남 = 스킨(AttackTrail.ribbonStyle - 공격 시작 때 칠한다) · 수명 · 테이퍼 · 강공격 규칙은 스킨 무관.
local function attachTrail(part, topLocal, bottomLocal)
	local topAttach = Instance.new("Attachment")
	topAttach.Position = topLocal
	topAttach.Parent = part
	local bottomAttach = Instance.new("Attachment")
	bottomAttach.Position = bottomLocal
	bottomAttach.Parent = part
	local function newTrail(a0, a1)
		local trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1 = a0, a1
		trail.FaceCamera = true
		trail.MinLength = 0.05
		trail.Enabled = false
		trail.Parent = part
		return trail
	end
	local trail = newTrail(topAttach, bottomAttach)
	local outer = Instance.new("Attachment")
	outer.Position = topLocal + (topLocal - bottomLocal).Unit * TrailData.ribbon.heavy.gloss.outerStuds
	outer.Parent = part
	local gloss = newTrail(outer, topAttach)
	return trail, gloss
end

local function paintRibbon(p, who, heavy)
	local key = tostring(typeof(who) == "Instance" and who:IsA("Player") and who:GetAttribute("TrailSkin") or "default") .. (heavy and "H" or "") .. (AttackTrail.dimOthers() and "D" or "")
	if p.ribbonKey == key then
		return
	end
	p.ribbonKey = key
	local style = AttackTrail.ribbonStyle(who, heavy)
	local t = p.trail
	t.Color, t.Transparency, t.LightEmission, t.WidthScale, t.Lifetime = style.color, style.transparency, style.lightEmission, style.widthScale, style.lifetime
	if style.gloss then
		p.gloss.Color, p.gloss.Transparency, p.gloss.LightEmission, p.gloss.WidthScale, p.gloss.Lifetime = style.color, style.gloss.transparency, style.lightEmission, style.widthScale, style.gloss.lifetime
	end
end

-- MeshPart.MeshId는 런타임 스크립트에서 못 쓴다 → Part + SpecialMesh(레거시 메시).
local function buildMeshPart(folder, name, meshId, size, color, textureId)
	local part = Instance.new("Part")
	part.Name = "Weapon_" .. name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = folder
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = meshId
	if textureId then
		mesh.TextureId = textureId
	end
	mesh.Parent = part
	return part
end

-- 교체 모델(규격 통과만): ReplicatedStorage.Shared.WeaponModels.<직업>(.<조각 이름>)
local function overrideModel(classId, pieceName)
	local folder = ReplicatedStorage.Shared:FindFirstChild(WeaponRigSpec.overrideFolder)
	local entry = folder and folder:FindFirstChild(classId)
	if entry and pieceName then
		entry = entry:FindFirstChild(pieceName) or nil
	end
	if not entry then
		return nil
	end
	local ok, rows = WeaponRigCheck.check(classId, pieceName, entry)
	if not ok then
		local bad = {}
		for _, r in ipairs(rows) do
			if not r.ok then
				table.insert(bad, r.label)
			end
		end
		warn(("[forge-game] 무기 교체 모델 %s.%s 규격 X(%s) - 지금 메시를 쓴다"):format(classId, tostring(pieceName or "main"), table.concat(bad, " · ")))
		return nil
	end
	return entry
end

local function buildWeapon(classId, colorOverride, parentFolder)
	local model = WeaponModelData[classId]
	local rig = WeaponRigSpec.weapons[classId]
	if not model or not rig then
		return nil
	end
	if colorOverride then -- D1: 무기 태초 = 흰 본체
		model = table.clone(model)
		model.color = colorOverride
	end
	local motion = AttackMotionData[classId]
	local folder = Instance.new("Folder")
	folder.Name = "Weapon_" .. classId
	folder.Parent = parentFolder
	local instances = { folder = folder }
	local pieces = {} -- [key] = { spec, scale, part | model(교체) | root(활), mesh, gripLocal(배율 적용 로컬 손잡이 점) }

	for _, spec in ipairs(rig.pieces) do
		local key = spec.name or "main"
		local scale = WeaponRigSpec.scaleOf(spec)
		local p = { spec = spec, scale = scale, key = key }
		local custom = overrideModel(classId, spec.name)
		if custom then
			local clone = custom:Clone()
			for _, d in ipairs(clone:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
				end
			end
			if clone:IsA("BasePart") then
				clone.Anchored, clone.CanCollide, clone.CanQuery, clone.CanTouch = true, false, false, false
			end
			clone.Parent = folder
			local frame = clone:IsA("Model") and clone.WorldPivot or clone.CFrame
			local function localOf(name)
				for _, d in ipairs(clone:GetDescendants()) do
					if d:IsA("Attachment") and d.Name == name then
						return frame:PointToObjectSpace(d.WorldPosition)
					end
				end
				return nil
			end
			p.custom = clone
			p.gripLocal = localOf(WeaponRigSpec.attachments.grip)
			p.supportLocal = localOf(WeaponRigSpec.attachments.support)
			p.nockLocal = localOf(WeaponRigSpec.attachments.stringNock)
			p.scale = 1
		elseif model.kind == "mesh" or model.kind == "mesh_pair" then
			local part = buildMeshPart(folder, spec.name or "Blade", model.meshId, model.size, model.color)
			part:FindFirstChildOfClass("SpecialMesh").Scale = Vector3.one * scale
			p.part, p.mesh = part, part:FindFirstChildOfClass("SpecialMesh")
			if TrailData.ribbon.classes[classId] and model.trailTop then
				p.trail, p.gloss = attachTrail(part, model.trailTop, model.trailBottom)
			end
		elseif model.kind == "specialmesh" then
			local part = buildMeshPart(folder, "Staff", model.meshId, model.size, model.color, model.textureId)
			part:FindFirstChildOfClass("SpecialMesh").Scale = Vector3.one * scale
			p.part, p.mesh = part, part:FindFirstChildOfClass("SpecialMesh")
			if TrailData.ribbon.closeClasses[classId] and model.trailTop then -- W2-4 가까운 대상 휘두르기 리본
				p.trail, p.gloss = attachTrail(part, model.trailTop, model.trailBottom)
			end
		elseif model.kind == "bow" then
			local root = Instance.new("Part")
			root.Name = "Weapon_BowRoot"
			root.Size = Vector3.new(0.1, 0.1, 0.1)
			root.Transparency = 1
			root.Anchored, root.CanCollide, root.CanQuery, root.CanTouch, root.CastShadow = true, false, false, false, false
			root.Parent = folder
			p.root = root
			if TrailData.ribbon.closeClasses[classId] and model.trailTop then -- W2-4 가까운 대상 휘두르기 리본(활 root에 부착)
				p.trail, p.gloss = attachTrail(root, model.trailTop, model.trailBottom)
			end
			p.limbs = {}
			for i, limb in ipairs(model.limbs) do
				local part = Instance.new("Part")
				part.Name = "Weapon_Limb" .. i
				part.Shape = Enum.PartType.Cylinder
				part.Size = limb.size
				part.Color = model.color
				part.Material = Enum.Material.SmoothPlastic
				part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
				part.Parent = folder
				table.insert(p.limbs, { part = part, spec = limb })
			end
			local function stringPart(name)
				local s = Instance.new("Part")
				s.Name = name
				s.Shape = Enum.PartType.Cylinder
				s.Size = Vector3.new(1, model.stringThickness, model.stringThickness)
				s.Color = model.stringColor
				s.Material = Enum.Material.SmoothPlastic
				s.Anchored, s.CanCollide, s.CanQuery, s.CanTouch, s.CastShadow = true, false, false, false, false
				s.Parent = folder
				return s
			end
			p.stringTop, p.stringBottom = stringPart("Weapon_StringTop"), stringPart("Weapon_StringBottom")
			local arrow = Instance.new("Part")
			arrow.Name = "Weapon_Arrow"
			arrow.Size = model.arrowSize
			arrow.Color = model.arrowColor
			arrow.Material = Enum.Material.SmoothPlastic
			arrow.Anchored, arrow.CanCollide, arrow.CanQuery, arrow.CanTouch, arrow.CastShadow = true, false, false, false, false
			arrow.Parent = folder
			p.arrow = arrow
		end
		p.gripLocal = p.gripLocal or spec.grip * scale
		p.supportLocal = p.supportLocal or (spec.support and spec.support * scale)
		p.nockLocal = p.nockLocal or (spec.stringNock and spec.stringNock * scale)
		pieces[key] = p
	end

	-- WeaponEnhanceVisual · ComboGlow 호환 instances(옛 구조)
	if model.kind == "mesh" or model.kind == "specialmesh" then
		instances.part = pieces.main.part or (pieces.main.custom and (pieces.main.custom:IsA("BasePart") and pieces.main.custom or pieces.main.custom.PrimaryPart))
		instances.trail = pieces.main.trail
	elseif model.kind == "mesh_pair" then
		instances.parts, instances.trails = {}, {}
		for key, p in pairs(pieces) do
			instances.parts[key] = p.part
			instances.trails[key] = p.trail
		end
	elseif model.kind == "bow" then
		local p = pieces.main
		instances.root, instances.limbs, instances.stringTop, instances.stringBottom, instances.arrow = p.root, p.limbs, p.stringTop, p.stringBottom, p.arrow
	end
	return { classId = classId, model = model, motion = motion, kind = model.kind, instances = instances, pieces = pieces, rig = rig, folder = folder }
end

-- ─────────────────────────── 상태 ───────────────────────────
local function newState(key, character, getAttr)
	return {
		key = key, character = character, getAttr = getAttr, weapon = nil, classId = nil,
		drawn = false, drawStart = -math.huge, attack = nil, getupStart = nil, dashUntil = 0,
		applied = {}, appliedW = {}, from = {}, fromW = {}, blendKey = nil, blendStart = 0, blendDur = M.blend.default,
		combo = 0, lastAttackAt = -math.huge, forcedDrawn = nil,
	}
end

local function attrOf(st, name)
	return st.getAttr(name)
end

local function speedOf(st)
	return PlayerCombat.getTotalSpeedMultiplier(attrOf(st, "SpeedPercentBonus"), attrOf(st, "AttackSpeedBuffMultiplier"))
end

local function inCombat(st, now)
	if st.forcedDrawn ~= nil then
		return st.forcedDrawn
	end
	if attrOf(st, "BossEncounterId") or st.attack or st.getupStart then
		return true
	end
	if os.clock() - st.lastAttackAt < M.combatHoldSeconds then
		return true
	end
	local untilAt = attrOf(st, "CombatUntil")
	return untilAt ~= nil and Workspace:GetServerTimeNow() < untilAt
end

local function rebuild(st)
	if st.weapon then
		if st.key == player then
			WeaponEnhanceVisual.clear()
			current = nil
		end
		destroyDeep(st.weapon.instances)
		st.weapon.folder:Destroy()
		st.weapon = nil
	end
	local classId = attrOf(st, "ClassId")
	st.classId = classId
	if not classId or classId == "" or not st.character then
		return
	end
	local primordialWeapon = (attrOf(st, "WeaponGrade") or 0) >= 6
	st.weapon = buildWeapon(classId, primordialWeapon and Color3.fromRGB(245, 245, 250) or nil, Workspace)
	if st.weapon and st.key == player then
		current = st.weapon
		WeaponEnhanceVisual.apply(current, attrOf(st, "WeaponLevel") or 0)
		local glowPart = primordialWeapon and (current.instances.part or current.instances.root or (current.instances.parts and select(2, next(current.instances.parts))))
		if glowPart then -- D1: 무기 태초 = 은은한 흰 숨쉬기 빛
			local light = Instance.new("PointLight")
			light.Name = "PrimordialWeaponGlow"
			light.Color = Color3.fromRGB(255, 255, 255)
			light.Range = 6
			light.Brightness = 0.6
			light.Parent = glowPart
			task.spawn(function()
				local t = 0
				while light.Parent do
					t += task.wait(0.1)
					light.Brightness = 0.45 + 0.35 * (0.5 + 0.5 * math.sin(t * 1.6))
				end
			end)
		end
	end
end

-- ─────────────────────────── 포즈 계산 ───────────────────────────
local function smoother(x)
	x = math.clamp(x, 0, 1)
	return x * x * x * (x * (x * 6 - 15) + 10)
end
local EASE = {
	inQuad = function(u) return u * u end,
	outCubic = function(u) return 1 - (1 - u) ^ 3 end,
	inOutSine = function(u) return -(math.cos(math.pi * u) - 1) / 2 end,
	outBack = function(u)
		local c1, c3 = 1.70158, 2.70158
		return 1 + c3 * (u - 1) ^ 3 + c1 * (u - 1) ^ 2
	end,
}
WeaponVisual.EASE = EASE

local rotCache = setmetatable({}, { __mode = "k" })
local function poseOf(tbl)
	if not tbl then
		return nil
	end
	local cached = rotCache[tbl]
	if cached then
		return cached
	end
	cached = {}
	for name, v in pairs(tbl) do
		cached[name] = PoseRig.rot(v)
	end
	rotCache[tbl] = cached
	return cached
end

-- a → b (둘 다 CFrame 표) - 한쪽에만 있는 관절은 없는 쪽 = 0(항등)으로 본다.
local function mix(a, b, u)
	local out = {}
	for name, cf in pairs(a) do
		out[name] = cf:Lerp(b[name] or CFrame.identity, u)
	end
	for name, cf in pairs(b) do
		if not out[name] then
			out[name] = CFrame.identity:Lerp(cf, u)
		end
	end
	return out
end

-- 공격 클립 τ초의 포즈 · 활 당김(0 ~ 1) · 동작 구간인가.
local function sampleAttack(clip, tm, tau)
	local c, h, th, s = poseOf(clip.cocked), poseOf(clip.contact), poseOf(clip.through), poseOf(clip.settle)
	local draw = clip.draw
	if tau < tm.ant then
		local u = EASE.inQuad(tau / math.max(tm.ant, 1e-4))
		return mix(c, h, u), draw and (draw[1] + (draw[2] - draw[1]) * EASE.outCubic(tau / math.max(tm.ant, 1e-4))) or 0, false
	elseif tau < tm.ant + tm.act then
		local u = EASE.outCubic((tau - tm.ant) / math.max(tm.act, 1e-4))
		return mix(h, th, u), draw and draw[3] or 0, true
	else
		local u = EASE.inOutSine(math.min((tau - tm.ant - tm.act) / math.max(tm.rec, 1e-4), 1))
		return mix(th, s, u), draw and draw[4] or 0, false
	end
end

-- 원거리(활 · 지팡이) 공격 = 발사 예약 큐: 요청마다 "요청 + 서버 발사 시각(상수)"에 놓는다. 첫 발 = 들어 올리며 당김 · 이어지는 발 = 조준을 유지한 채
-- 놓자마자(시위 튕김 act) 다음 예약 시각까지 다시 당김(연사) · 큐가 비면 회복 → 끝. 반환: pose(nil = 끝) · 당김 · 동작 구간인가.
local function rangedPose(a, now)
	local c, h, s = poseOf(a.clip.cocked), poseOf(a.clip.contact), poseOf(a.clip.settle)
	local nextRel = a.queue[1]
	if nextRel and now >= nextRel then
		table.remove(a.queue, 1) -- 놓음 = 타격 프레임(서버 발사 시각과 같다)
		a.lastRelease = now
		nextRel = a.queue[1]
	end
	local act = a.tm.act
	-- W2-6 당기는 손(활 IK): handDraw = 쉬는 시위(0) → 당김 고정점(1) · kick = 놓은 뒤 튕김(0 ~ 1 ~ 0). 반환 draw = 시위 당김(놓은 뒤 = 0 - 손이 얼굴 옆에 남아도 시위는 쉰다).
	local B = M.bowHand
	local since = a.lastRelease and now - a.lastRelease
	a.kick = (since and since < B.kickSeconds) and math.sin(math.pi * since / B.kickSeconds) or 0
	a.returning = false
	if since and since < act then
		a.handDraw = 1
		return h, 0, true
	end
	if nextRel then
		local from = a.lastRelease and (a.lastRelease + act) or a.start
		local u = math.clamp((now - from) / math.max(nextRel - from, 1e-3), 0, 1)
		if a.lastRelease then -- 연사: 앞 returnFraction 동안 손이 시위로 돌아가(다음 화살 잡기) → 다시 당김
			local g = B.returnFraction
			if u < g then
				a.handDraw = 1 - EASE.inOutSine(u / g)
				a.returning = true -- 새 화살은 손이 시위에 닿을 때 보인다
				return h, 0, false
			end
			local d = EASE.outCubic((u - g) / (1 - g))
			a.handDraw = d
			return h, d, false
		end
		local d = EASE.outCubic(u)
		a.handDraw = d
		return mix(c, h, EASE.inQuad(u)), d, false
	end
	a.recovering = true
	local r = (now - ((a.lastRelease or now) + act)) / math.max(a.tm.rec, 1e-3)
	if r >= 1 then
		return nil
	end
	a.handDraw = 1 - EASE.inOutSine(math.max(r, 0)) -- 회복: 손이 얼굴 옆에서 시위로 돌아간다
	return mix(h, s, EASE.inOutSine(math.max(r, 0))), 0, false
end

local function getupPose(st, w, tau)
	local G = M.getup
	local bounce, lie, rise, stance = poseOf(G.bounce), poseOf(G.lie), poseOf(w.getupRise), poseOf(w.stance)
	local t1, t2, t3 = G.bounceSeconds, G.bounceSeconds + G.lieSeconds, G.bounceSeconds + G.lieSeconds + G.riseSeconds
	if tau < t1 then
		return mix(bounce, lie, EASE.outBack(tau / t1) * 0.35) -- 튕김(장난감처럼 - 뒤로 젖히며 살짝 넘침)
	elseif tau < t2 then
		return mix(bounce, lie, 0.35 + 0.65 * EASE.outCubic((tau - t1) / G.lieSeconds))
	elseif tau < t3 then
		return mix(lie, rise, EASE.outCubic((tau - t2) / G.riseSeconds))
	end
	return mix(rise, stance, EASE.inOutSine(math.min((tau - t3) / G.settleSeconds, 1)))
end
local function getupTotal()
	local G = M.getup
	return G.bounceSeconds + G.lieSeconds + G.riseSeconds + G.settleSeconds
end
WeaponVisual.getupTotal = getupTotal

-- W2 결정 1: 대상 쪽으로 몸 돌리기(Root 관절 - 루트 파트 · 판정 불변). 공격이 끝나면 포즈에서 빠져 blend로 풀린다.
local function withTurn(a, pose, now)
	if a.turnYaw then
		pose.Root = CFrame.Angles(0, a.turnYaw * math.min((now - a.start) / M.turnToTarget.seconds, 1), 0)
	end
	return pose
end

-- 대상 방향(루트 기준 수평 각 - 왼쪽 +). 앞 minDeg 안이면 nil(돌지 않는다).
local function turnYawTo(st, target)
	local root = st.character and st.character:FindFirstChild("HumanoidRootPart")
	local tp = target and target.PrimaryPart
	if not root or not tp then
		return nil
	end
	local l = root.CFrame:VectorToObjectSpace(tp.Position - root.Position)
	if l.X * l.X + l.Z * l.Z < 0.25 then
		return nil
	end
	local yaw = math.atan2(-l.X, -l.Z)
	if math.abs(math.deg(yaw)) < M.turnToTarget.minDeg then
		return nil
	end
	return yaw
end

-- W2-4 활 · 지팡이: 대상이 가까우면(루트 ↔ 루트 closeSwing.rangeStuds 안 · 지상) 휘두르기.
local function isCloseSwing(st, target, air)
	local w = M.weapons[st.classId]
	local root = st.character and st.character:FindFirstChild("HumanoidRootPart")
	local tp = target and target.PrimaryPart
	return not air and w ~= nil and w.closeSwing ~= nil and root ~= nil and tp ~= nil and (tp.Position - root.Position).Magnitude <= M.closeSwing.rangeStuds
end

-- 한 캐릭터의 목표 포즈. 반환: pose(CFrame 표) · blendKey · blendDur · inHand(무기가 손에) · draw(활) · trailOn · ik(허용)
local function targetPose(st, now, root)
	local w = M.weapons[st.classId]
	if not w then
		return {}, "none", M.blend.default, false, 0, false, false
	end
	-- 넘어짐 → 일어나기(최우선 - 전신)
	if st.getupStart then
		local tau = now - st.getupStart
		if tau < getupTotal() then
			return getupPose(st, w, tau), "getup", M.blend.min, true, 0, false, tau > M.getup.bounceSeconds + M.getup.lieSeconds
		end
		st.getupStart = nil
		if st.onGetupDone then
			local cb = st.onGetupDone
			st.onGetupDone = nil
			task.spawn(cb)
		end
	end
	-- 공격
	local a = st.attack
	if a and a.ranged then
		local pose, draw = rangedPose(a, now)
		if pose then
			return pose, a.blendKey, a.blendDur, true, draw, false, true -- 쏘기 = 리본 없음(W2-4 휘두르기만)
		end
		st.attack = nil
		a = nil
	end
	if a then
		if a.freezeUntil and now < a.freezeUntil then
			local pose, draw = sampleAttack(a.clip, a.tm, a.tm.ant)
			return withTurn(a, pose, now), a.blendKey, a.blendDur, true, draw, true, true
		end
		if a.freezeUntil then
			a.start += a.freezeUntil - a.frozeAt
			a.freezeUntil, a.frozeAt = nil, nil
		end
		local tau = now - a.start
		if not a.hitDone and tau >= a.tm.ant then
			a.hitDone = true
			a.freezeUntil, a.frozeAt = now + (a.hitstop or M.hitstopSeconds), now
			local pose, draw = sampleAttack(a.clip, a.tm, a.tm.ant)
			return withTurn(a, pose, now), a.blendKey, a.blendDur, true, draw, true, true
		end
		if tau < a.tm.total then
			local pose, draw, act = sampleAttack(a.clip, a.tm, tau)
			return withTurn(a, pose, now), a.blendKey, a.blendDur, true, draw, act, true
		end
		st.attack = nil
		if a.heavyScaled then
			a.heavyScaled(false)
		end
	end
	local character = st.character
	if character:GetAttribute("Gliding") then
		return poseOf(M.glide), "glide", M.blend.default, false, 0, false, false
	end
	if now < st.dashUntil and st.drawn then
		return poseOf(w.dash), "dash", M.blend.min, true, 0, false, true
	end
	-- 꺼내기 · 수납
	local mount = st.weapon and st.weapon.rig.pieces[1].sheath.mount or "back"
	local u = (now - st.drawStart) / M.drawSeconds
	if u < 1 then
		local reach = poseOf(M.reach[mount])
		if st.drawn then
			if u < M.drawGrabT then
				return reach, "reach", M.drawSeconds * M.drawGrabT, false, 0, false, false
			end
			return poseOf(w.stance), "draw", M.drawSeconds * (1 - M.drawGrabT), true, 0, false, true
		end
		if u < 1 - M.drawGrabT then
			return reach, "reach", M.drawSeconds * (1 - M.drawGrabT), true, 0, false, false
		end
		return {}, "sheathe", M.drawSeconds * M.drawGrabT, false, 0, false, false
	end
	if not st.drawn then
		return {}, "none", M.blend.default, false, 0, false, false
	end
	-- 전투 대기 · 이동(속도로 섞음) + 숨쉬기
	local v = root.AssemblyLinearVelocity
	local m = math.clamp(Vector3.new(v.X, 0, v.Z).Magnitude / M.moveBlendSpeed, 0, 1)
	local pose = mix(poseOf(w.stance), poseOf(w.move), m)
	local breathe = math.sin(now * 2 * math.pi / M.idlePeriodSeconds) * (1 - m)
	pose.Waist = (pose.Waist or CFrame.identity) * CFrame.Angles(math.rad(1.5 * breathe), 0, 0)
	return pose, "stance", M.blend.default, true, 0, false, true
end

-- ─────────────────────────── 매 프레임 ───────────────────────────
local PALM = WeaponRigSpec.palm
local POLE_SUPPORT = Vector3.new(-1, -1.2, 0.2) -- 왼팔 보조 손 팔꿈치 = 왼쪽 아래
local POLE_STRING = Vector3.new(1, 0.1, 1) -- 시위 당기는 오른팔 팔꿈치 = 오른쪽 뒤

local function placePiece(p, cf)
	if p.custom then
		if p.custom:IsA("Model") then
			p.custom:PivotTo(cf)
		else
			p.custom.CFrame = cf
		end
	elseif p.part then
		p.part.CFrame = cf
	elseif p.root then
		p.root.CFrame = cf
	end
end

local function updateBow(weapon, p, bowCF, draw, showArrow, palmW)
	local model = weapon.model
	for _, limb in ipairs(p.limbs) do
		limb.part.CFrame = bowCF * CFrame.new(limb.spec.relPos) * CFrame.Angles(0, math.rad(limb.spec.relRotYDeg), 0)
	end
	local maxDraw = p.spec.drawStuds or 1.2
	local nock = p.nockLocal + Vector3.new(0, 0, draw * maxDraw)
	if palmW and draw > 0 then -- W2-6: 시위 가운데 = 당기는 손바닥(고정점 IK) - 활 몸 쪽 · 최대 당김 · 옆 0.6까지만
		local l = bowCF:PointToObjectSpace(palmW)
		nock = Vector3.new(math.clamp(l.X, -0.6, 0.6), math.clamp(l.Y, -0.6, 0.6), math.clamp(l.Z, p.nockLocal.Z, p.nockLocal.Z + maxDraw))
	end
	local function seg(part, fromLocal, toLocal)
		local a, b = bowCF:PointToWorldSpace(fromLocal), bowCF:PointToWorldSpace(toLocal)
		part.Size = Vector3.new((b - a).Magnitude, part.Size.Y, part.Size.Z)
		part.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
	end
	seg(p.stringTop, model.stringTopTip, nock)
	seg(p.stringBottom, model.stringBottomTip, nock)
	p.arrow.Transparency = showArrow and 0 or 1
	if showArrow then
		local nockW = bowCF:PointToWorldSpace(nock)
		local fwd = bowCF:VectorToWorldSpace(Vector3.new(0, 0, -1))
		if palmW and draw > 0 then -- 화살 = 시위 가운데 → 활 손잡이(화살 받침) 쪽
			local rest = bowCF:PointToWorldSpace(p.gripLocal)
			if (rest - nockW).Magnitude > 0.05 then
				fwd = (rest - nockW).Unit
			end
		end
		p.arrow.CFrame = CFrame.lookAt(nockW + fwd * (model.arrowSize.Z / 2), nockW + fwd * 2)
	end
	return bowCF:PointToWorldSpace(nock)
end

local function setFolderShown(st, shown)
	if st.weapon and st.weapon.folder then
		st.weapon.folder.Parent = shown and Workspace or nil
	end
end

-- ① 포즈(PreSimulation = 애니메이터 다음 · 물리 전 - RenderStepped에 쓰면 애니메이터가 덮어써 물리 풀이에 안 들어간다: W1 실측)
local function pieceCFrame(p, handCF, heavyMul)
	return handCF * CFrame.new(PALM[p.spec.hand]) * p.spec.hold * CFrame.new(-p.gripLocal * heavyMul)
end

local function updatePose(st, now, camPos)
	local character = st.character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	st.frame = nil
	if not root or not humanoid or not st.weapon then
		return
	end
	if st.key ~= player and camPos and (root.Position - camPos).Magnitude > DRAW_RANGE_STUDS then
		local far = PoseRig.get(character)
		if far and next(far.written) then
			PoseRig.release(far) -- 리뷰 3: 범위 밖 = 관절을 돌려준다
		end
		st.applied, st.appliedW, st.from, st.fromW, st.blendKey = {}, {}, {}, {}, nil
		return
	end
	local rig = PoseRig.get(character)
	if not rig then
		return
	end
	-- 전투 상태 → 꺼내기 · 수납
	local combat = humanoid.Health > 0 and inCombat(st, now)
	if combat ~= st.drawn then
		st.drawn = combat
		local u = (now - st.drawStart) / M.drawSeconds
		st.drawStart = u < 1 and now - (1 - u) * M.drawSeconds or now -- 동작 중 반대로 바뀌면 이어서
	end
	local pose, key, dur, inHand, draw, trailOn, ikOk = targetPose(st, now, root)
	if key ~= st.blendKey then
		st.from, st.fromW = st.applied, st.appliedW
		st.blendKey, st.blendStart, st.blendDur = key, now, math.clamp(dur, 0.01, M.blend.max)
	end
	local e = smoother((now - st.blendStart) / st.blendDur)
	local applied, appliedW = {}, {}
	for name, cf in pairs(pose) do
		local f = st.from[name] or cf
		applied[name] = f:Lerp(cf, e)
		appliedW[name] = (st.fromW[name] or 0) + (1 - (st.fromW[name] or 0)) * e
	end
	for name, cf in pairs(st.from) do
		if not pose[name] then
			local fw = (st.fromW[name] or 0) * (1 - e)
			if fw > 0.001 then
				applied[name], appliedW[name] = cf, fw
			end
		end
	end
	st.applied, st.appliedW = applied, appliedW
	local T = PoseRig.apply(rig, applied, appliedW)
	local heavyMul = (st.attack and st.attack.heavy) and HEAVY_WEAPON_SCALE or 1
	st.frame = { inHand = inHand, draw = draw, trailOn = trailOn, heavyMul = heavyMul }
	-- 보조 손 · 시위 IK(무기가 손에 있고 포즈가 허용할 때 - 꺼내는 중 · 활강 · 넘어져 누운 동안은 끔). 무기 자리 = 이번 포즈의 FK 손.
	local main = st.weapon.pieces.main
	local ik = M.weapons[st.classId] and M.weapons[st.classId].ik
	if not (main and inHand and ikOk and ik) then
		return
	end
	local cf = PoseRig.fk(rig, T)
	local hand = cf and cf[main.spec.hand]
	if not hand then
		return
	end
	local mainCF = pieceCFrame(main, hand, heavyMul)
	if ik == "string" and main.nockLocal then
		local spec = main.spec
		local a = st.attack
		local handDraw, kick = draw, 0
		if a and a.ranged and a.handDraw then
			handDraw, kick = a.handDraw, a.kick or 0
		end
		local target
		local headCF = cf.Head
		if spec.drawAnchor and headCF then -- W2-6: 쉬는 시위 → 머리 기준 고정점(턱 · 뺨 옆) · 놓을 때 튕김 · 머리 뒷면 쪽으로는 handBackLimit까지만
			local anchor = spec.drawAnchor + (spec.releaseKick or Vector3.zero) * kick
			local restLocal = headCF:PointToObjectSpace(mainCF:PointToWorldSpace(main.nockLocal))
			local l = restLocal:Lerp(anchor, handDraw)
			target = headCF:PointToWorldSpace(Vector3.new(l.X, l.Y, math.min(l.Z, spec.handBackLimit or 0.3)))
		else
			target = mainCF:PointToWorldSpace(main.nockLocal + Vector3.new(0, 0, draw * (spec.drawStuds or 1.2)))
		end
		local wristT = kick > 0 and spec.releaseOpenDeg and CFrame.Angles(math.rad(-spec.releaseOpenDeg * kick), 0, 0) or nil
		st.frame.ikMiss = PoseRig.solveArm(rig, T, cf, "Right", target, spec.drawPole or POLE_STRING, PALM.RightHand, wristT, appliedW.RightShoulder or 1)
	elseif ik == "support" and main.supportLocal then
		local target = mainCF:PointToWorldSpace(main.supportLocal * heavyMul)
		st.frame.ikMiss = PoseRig.solveArm(rig, T, cf, "Left", target, POLE_SUPPORT, PALM.LeftHand, CFrame.Angles(0, 0, math.rad(90)), appliedW.RightShoulder or 1)
	end
end

-- ② 무기 자리(RenderStepped - 물리가 이번 포즈로 놓은 실제 손 · 몸 파트 기준)
local function placeWeapon(st, now, camPos)
	local character = st.character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not st.weapon then
		return
	end
	local shown = st.frame ~= nil or st.key == player or not camPos or (root.Position - camPos).Magnitude <= DRAW_RANGE_STUDS
	setFolderShown(st, shown)
	if not shown then
		return
	end
	local f = st.frame or { inHand = false, draw = 0, trailOn = false, heavyMul = 1 }
	local weapon = st.weapon
	for _, p in pairs(weapon.pieces) do
		local wcf
		local hand = character:FindFirstChild(p.spec.hand)
		if f.inHand and hand then
			wcf = pieceCFrame(p, hand.CFrame, f.heavyMul)
		else
			local mount = character:FindFirstChild(p.spec.sheath.mount == "hip" and "LowerTorso" or "UpperTorso")
			if mount then
				wcf = mount.CFrame * WeaponRigSpec.sheathCFrame(p.spec.sheath) * CFrame.new(-p.gripLocal)
			end
		end
		if wcf then
			placePiece(p, wcf)
			if p.root then
				local a = st.attack
				local showArrow = f.inHand and not (a and a.ranged and ((a.lastRelease and now - a.lastRelease < a.tm.act) or a.recovering or a.returning))
				local rh = f.inHand and character:FindFirstChild(p.spec.stringHand or "RightHand")
				updateBow(weapon, p, wcf, f.inHand and f.draw or 0, showArrow, rh and rh.CFrame:PointToWorldSpace(PALM[rh.Name] or PALM.RightHand))
			end
		end
		if p.trail then
			local heavy = f.heavyMul > 1 -- 3타 · 공중 3타 강공격(무기 ×1.3 구간과 같다)
			local on = f.trailOn and f.inHand
			if on then
				paintRibbon(p, st.key, heavy)
			end
			p.trail.Enabled = on
			p.gloss.Enabled = on and heavy
		end
	end
end

-- ─────────────────────────── 등록 · 공격 시작 ───────────────────────────
local function stateFor(key)
	return rigs[key]
end

local function bindPlayer(p)
	local st = newState(p, p.Character, function(name)
		return p:GetAttribute(name)
	end)
	rigs[p] = st
	local function refresh()
		st.character = p.Character
		st.attack, st.getupStart, st.applied, st.appliedW, st.from, st.fromW, st.blendKey = nil, nil, {}, {}, {}, {}, nil
		st.drawn, st.drawStart = false, -math.huge
		rebuild(st)
	end
	p.CharacterAdded:Connect(function()
		task.defer(refresh)
	end)
	for _, attr in ipairs({ "ClassId", "WeaponGrade" }) do
		p:GetAttributeChangedSignal(attr):Connect(refresh)
	end
	refresh()
end

local function startAttack(st, index, heavy, air, target)
	if not st or not st.classId then
		return false
	end
	local clip = MotionTiming.clip(st.classId, index, air)
	if not clip then
		return false
	end
	local close = MotionTiming.isRanged(st.classId) and isCloseSwing(st, target, air)
	if close then
		clip = M.weapons[st.classId].closeSwing
	end
	local now = os.clock()
	st.lastAttackAt = now
	if not st.drawn then -- 공격 = 즉시 전투 자세(꺼내기 생략 - 무기가 곧장 손으로)
		st.drawn, st.drawStart = true, -math.huge
	end
	if MotionTiming.isRanged(st.classId) and not close then -- 원거리 = 발사 예약 큐(서버 발사 시각 상수 - rangedPose)
		local release = now + MotionTiming.releaseSeconds(st.classId, air)
		local cur = st.attack
		if cur and cur.ranged and not cur.recovering then
			table.insert(cur.queue, release) -- 당긴 채 이어 쏜다
			return false
		end
		st.attack = { ranged = true, clip = clip, tm = MotionTiming.scale(clip, speedOf(st), heavy, true), start = now, queue = { release }, heavy = heavy, air = air, index = index,
			blendKey = "atk" .. tostring(now), blendDur = M.blend.attackIn }
		st.getupStart = nil
		local airData = air and AttackMotionData[st.classId] and AttackMotionData[st.classId].air
		if airData and airData.bodyPitchDeg and st.character then
			require(script.Parent.AirMotion).play(st.character, "lean", MotionTiming.releaseSeconds(st.classId, air) + (airData.hoverSeconds or 0), airData.bodyPitchDeg)
		end
		return false
	end
	local tm = MotionTiming.scale(clip, speedOf(st), heavy, close) -- 휘두르기(W2-4) = 전조 고정(타격 = 서버 발사 시각)
	local prev = st.attack
	if prev and prev.heavyScaled then
		prev.heavyScaled(false)
	end
	st.attack = { clip = clip, tm = tm, start = now, heavy = heavy, air = air, index = index, blendKey = "atk" .. tostring(now), blendDur = math.min(M.blend.attackIn, tm.ant),
		turnYaw = turnYawTo(st, target), close = close }
	st.getupStart = nil
	-- 3타 강공격: 메시 ×1.3(SpecialMesh 배율 - 파트 크기는 메시에 안 먹는다)
	if heavy and st.weapon then
		local meshes = {}
		for _, p in pairs(st.weapon.pieces) do
			if p.mesh then
				table.insert(meshes, p)
			end
		end
		local function set(on)
			for _, p in ipairs(meshes) do
				p.mesh.Scale = Vector3.one * p.scale * (on and HEAVY_WEAPON_SCALE or 1)
			end
		end
		set(true)
		st.attack.heavyScaled = set
	end
	-- 공중: 몸 자세(MV1 틀) - 회전 베기 = 제자리 한 바퀴 · 그 밖 = 앞으로 실었다 돌아온다
	local airData = air and AttackMotionData[st.classId] and AttackMotionData[st.classId].air
	if airData and st.character then
		local seconds = tm.total
		if airData.bodySpinDeg then
			require(script.Parent.AirMotion).play(st.character, "spin", seconds, airData.bodySpinDeg)
		elseif airData.bodyPitchDeg then
			require(script.Parent.AirMotion).play(st.character, "lean", seconds + (airData.hoverSeconds or 0), airData.bodyPitchDeg)
		end
	end
	return close
end

-- 내 스윙(서버 확인 없이 즉시 - 판정은 서버). isHeavy = 3타 강공격 예측 · isAir = 공중 공격 · target = 클라 조준 대상(AimTarget - 서버와 같은 AimPicker · 연출용).
-- 반환: 활 · 지팡이 가까운 대상 휘두르기인가(W2-4 - 화살 · 구슬을 안 그린다).
function WeaponVisual.playSwing(isHeavy, isAir, target)
	local st = stateFor(player)
	if not st then
		return false
	end
	local now = os.clock()
	if now - st.lastAttackAt > CombatConfig.comboResetWindowSeconds then
		st.combo = 0
	end
	st.combo += 1
	local index = isHeavy and 3 or MotionTiming.comboIndex(st.combo)
	return startAttack(st, index, isHeavy, isAir, target)
end

-- 남의 공격(서버 중계 AttackMotion) · 검증 더미.
function WeaponVisual.playRemote(key, comboCount, isHeavy, isAir)
	startAttack(stateFor(key), isHeavy and 3 or MotionTiming.comboIndex(comboCount), isHeavy, isAir)
end

-- 3타 강타 히트스톱(16-7) - 지금 포즈를 durationSeconds 동안 얼린다(타격 프레임 히트스톱과 겹치면 긴 쪽).
function WeaponVisual.applyHitstop(durationSeconds)
	local st = stateFor(player)
	local a = st and st.attack
	if not a then
		return
	end
	local now = os.clock()
	if a.freezeUntil then
		a.freezeUntil = math.max(a.freezeUntil, now + durationSeconds)
	else
		a.freezeUntil, a.frozeAt = now + durationSeconds, now
	end
end

-- 활 · 지팡이: 지금 스윙의 발사 시점(= 타격 프레임)까지 남은 시간(서버 AttackServer도 MotionTiming.releaseSeconds로 같은 시각).
function WeaponVisual.getReleaseDelay()
	local st = stateFor(player)
	local a = st and st.attack
	if not a or not a.ranged or not a.queue[1] then
		return 0
	end
	return math.max(a.queue[1] - os.clock(), 0) -- 가장 먼저 예약된 발사(결과는 요청 순서대로 온다)
end

-- 대시 자세(나 = DashInput · 남 = 중계 "dash").
function WeaponVisual.playDash(key, seconds)
	local st = stateFor(key or player)
	if st then
		st.dashUntil = os.clock() + (seconds or 0.3)
	end
end

-- 입력 버퍼(내 캐릭터 - 공격 · 대시): 일어나는 중이면 fn을 맡아 두었다 끝나는 순간 낸다(마지막 것 하나 · bufferSeconds 안에 누른 것만). 맡았으면 true.
local buffered = nil -- { fn, at }
function WeaponVisual.bufferInput(fn)
	if not WeaponVisual.isGettingUp() then
		return false
	end
	buffered = { fn = fn, at = os.clock() }
	return true
end
local function flushBuffered()
	local b = buffered
	buffered = nil
	if b and os.clock() - b.at <= M.getup.bufferSeconds then
		b.fn()
	end
end

-- 넘어짐 → 일어나기(나 = 넉백 · 회오리 착지 · 남 = 중계 "getup" · BR1-4 보스가 부른다). onDone = 끝나는 순간(입력 버퍼).
function WeaponVisual.playGetup(key, onDone)
	local st = stateFor(key or player)
	if not st or not st.classId then
		if onDone then
			task.spawn(onDone)
		end
		return
	end
	st.attack = nil
	st.getupStart = os.clock()
	st.onGetupDone = function()
		if onDone then
			onDone()
		end
		if st.key == player then
			flushBuffered()
		end
	end
end

function WeaponVisual.isGettingUp(key)
	local st = stateFor(key or player)
	return st ~= nil and st.getupStart ~= nil and os.clock() - st.getupStart < getupTotal()
end


-- 무기 이펙트 자리(강화 빛과 같은 자리) - ComboGlow가 쓴다.
function WeaponVisual.getEffectAttach()
	if not current then
		return nil
	end
	local instances = current.instances
	local part
	if current.kind == "mesh_pair" then
		part = instances.parts[current.model.effectPart]
	elseif current.kind == "bow" then
		part = instances.root
	else
		part = instances.part
	end
	return part, current.model.effectAnchor
end

-- 투사체 시작 자리 - 활 = 화살(시위), 지팡이 = 머리(모델 −Z 끝).
function WeaponVisual.getMuzzleWorldPosition()
	if not current then
		return nil
	end
	if current.kind == "bow" then
		return current.instances.arrow.Position
	elseif current.kind == "specialmesh" then
		local part = current.instances.part
		local spec = current.pieces.main.spec
		return part.CFrame:PointToWorldSpace(WeaponRigCheck.AXES[spec.tipAxis] * spec.refLength / 2) -- 규격 끝 축(지팡이 = +Y 머리)
	end
	return nil
end

-- ─────────────────────────── 검증 · 스크린샷 훅(Studio) ───────────────────────────
-- 더미(검증 - 다른 플레이어 경로와 같은 코드): 모델 + 속성 표 → 중계 공격 · 일어나기를 그대로 받는다.
function WeaponVisual.bindDummy(model, attrs)
	local st = newState(model, model, function(name)
		return attrs[name]
	end)
	rigs[model] = st
	rebuild(st)
	model.Destroying:Connect(function()
		if st.weapon then
			st.weapon.folder:Destroy()
		end
		rigs[model] = nil
	end)
	return st
end

-- 포즈 고정(스크린샷): clip = "stance" | "move" | "dash" | "glide" | "sheathed" | "attack1..3" | "heavy" | "air" | "getup" · tau = 그 클립의 초(배율 speed).
function WeaponVisual.debugFreeze(key, clipName, tau, speed)
	local st = stateFor(key or player)
	if not st then
		return false
	end
	st.debug = clipName and { clip = clipName, tau = tau or 0, speed = speed or 1 } or nil
	return true
end

local function debugPose(st, now)
	local d = st.debug
	local w = M.weapons[st.classId]
	if not d or not w then
		return false
	end
	st.forcedDrawn = d.clip ~= "sheathed"
	st.drawn = st.forcedDrawn
	st.drawStart = -math.huge
	if d.clip == "getup" then
		st.getupStart = now - d.tau
		st.attack = nil
	elseif d.clip:sub(1, 6) == "attack" or d.clip == "heavy" or d.clip == "air" then
		local index = d.clip == "heavy" and 3 or tonumber(d.clip:sub(7)) or 1
		local clip = MotionTiming.clip(st.classId, index, d.clip == "air")
		local tm = MotionTiming.scale(clip, d.speed, d.clip == "heavy")
		st.attack = { clip = clip, tm = tm, start = now - d.tau, heavy = d.clip == "heavy", air = d.clip == "air", index = index, blendKey = "dbg" .. d.clip .. d.tau, blendDur = 0.01, hitDone = true }
		st.getupStart = nil
	else
		st.attack, st.getupStart = nil, nil
		st.dashUntil = d.clip == "dash" and now + 1 or 0
	end
	return true
end

-- ─────────────────────────── 실행 ───────────────────────────
local function camPosition()
	local cam = Workspace.CurrentCamera
	return cam and cam.CFrame.Position
end
RunService.PreSimulation:Connect(function()
	local now, camPos = os.clock(), camPosition()
	for _, st in pairs(rigs) do
		if st.debug then
			debugPose(st, now)
		end
		local ok, err = pcall(updatePose, st, now, camPos)
		if not ok and not st.warned then
			st.warned = true
			warn("[forge-game] WeaponVisual 포즈 에러: " .. tostring(err))
		end
	end
end)
RunService.RenderStepped:Connect(function()
	local now, camPos = os.clock(), camPosition()
	for _, st in pairs(rigs) do
		local ok, err = pcall(placeWeapon, st, now, camPos)
		if not ok and not st.warnedPlace then
			st.warnedPlace = true
			warn("[forge-game] WeaponVisual 무기 자리 에러: " .. tostring(err))
		end
	end
end)

for _, p in ipairs(Players:GetPlayers()) do
	bindPlayer(p)
end
Players.PlayerAdded:Connect(bindPlayer)
Players.PlayerRemoving:Connect(function(p)
	local st = rigs[p]
	if st and st.weapon then
		st.weapon.folder:Destroy()
	end
	rigs[p] = nil
end)
player:GetAttributeChangedSignal("WeaponLevel"):Connect(function()
	if current then
		WeaponEnhanceVisual.apply(current, player:GetAttribute("WeaponLevel") or 0)
	end
end)
WeaponEnhanceVisual.init(function()
	return current
end)

-- 검증 · 스크린샷 훅(Studio 전용): 클라 execute_luau → PlayerGui.W1PoseHook:Invoke(명령, …)
--   "freeze", clip, tau, speed(내 캐릭터 포즈 고정 - clip nil = 풀기) · "dummy", classId(내 옆에 내 아바타 복제 = "남의 캐릭터" 경로) → 더미 모델 ·
--   "dummyAttack", comboCount, heavy, air · "dummyGetup" · "dummyFreeze", clip, tau · "swing", heavy, air(내 스윙) · "state"(요약 문자열) · "getup"(내 일어나기)
if RunService:IsStudio() then
	local dummies = {} -- [번호] = 모델
	local hook = Instance.new("BindableFunction")
	hook.Name = "W1PoseHook"
	hook.OnInvoke = function(cmd, a1, a2, a3)
		if cmd == "freeze" then
			return WeaponVisual.debugFreeze(player, a1, a2, a3)
		elseif cmd == "swing" then
			WeaponVisual.playSwing(a1 == true, a2 == true)
			return true
		elseif cmd == "getup" then
			WeaponVisual.playGetup(player)
			return true
		elseif cmd == "dummy" then -- a1 = 직업 · a2 = 옆 거리 · a3 = 번호(여러 개)
			local idx = a3 or 1
			if dummies[idx] then
				dummies[idx]:Destroy()
			end
			local character = player.Character
			character.Archivable = true
			local clone = character:Clone()
			for _, d in ipairs(clone:GetDescendants()) do
				if d:IsA("LocalScript") or d:IsA("Script") then
					d:Destroy()
				end
			end
			clone.Name = "W1Dummy" .. idx
			clone:PivotTo(character:GetPivot() * CFrame.new(a2 or 7, 0, 0))
			clone.HumanoidRootPart.Anchored = true
			clone.Parent = Workspace
			dummies[idx] = clone
			WeaponVisual.bindDummy(clone, { ClassId = a1 or player:GetAttribute("ClassId") })
			return clone
		elseif cmd == "dummyAttack" then -- a1 = 콤보 수 · a2 = 강공격 · a3 = 공중 (번호 1)
			WeaponVisual.playRemote(dummies[1], a1 or 1, a2 == true, a3 == true)
			return true
		elseif cmd == "dummyGetup" then
			WeaponVisual.playGetup(dummies[a1 or 1])
			return true
		elseif cmd == "dummyFreeze" then -- a1 = 번호 · a2 = 클립 · a3 = 초
			return WeaponVisual.debugFreeze(dummies[a1], a2, a3, 1)
		elseif cmd == "bindModel" then -- 서버가 만든 모델(복제됨) 등록: a1 = 이름 · a2 = 직업 → 서버 AttackMotion · AirMoveFx 중계를 그 모델로 받는다(W1-6 네트워크 경로)
			local m = Workspace:FindFirstChild(a1)
			if not m then
				return false
			end
			WeaponVisual.bindDummy(m, { ClassId = a2 })
			return true
		elseif cmd == "stateModel" then
			local st = rigs[Workspace:FindFirstChild(a1)]
			return st and ("attack=%s index=%s heavy=%s air=%s getup=%s blend=%s"):format(tostring(st.attack ~= nil), tostring(st.attack and st.attack.index), tostring(st.attack and st.attack.heavy), tostring(st.attack and st.attack.air), tostring(st.getupStart ~= nil), tostring(st.blendKey)) or "없음"
		elseif cmd == "clearDummies" then
			for _, d in pairs(dummies) do
				d:Destroy()
			end
			dummies = {}
			return true
		elseif cmd == "patch" then -- 실행 중 포즈 데이터 바꾸기(다듬기 - 확정 값은 PlayerMotionData 파일로 옮긴다): a1 = "weapons.greatsword.stance" · a2 = 값
			local t, last = M, nil
			local keys = string.split(a1, ".")
			for i = 1, #keys - 1 do
				local k = tonumber(keys[i]) or keys[i]
				t = t[k]
			end
			last = tonumber(keys[#keys]) or keys[#keys]
			t[last] = a2
			return true
		elseif cmd == "get" then
			local t = M
			for _, k in ipairs(string.split(a1, ".")) do
				t = t[tonumber(k) or k]
			end
			return t
		elseif cmd == "state" then
			local st = rigs[type(a1) == "number" and dummies[a1] or player]
			if not st then
				return "없음"
			end
			local main = st.weapon and st.weapon.pieces.main or (st.weapon and select(2, next(st.weapon.pieces)))
			local part = main and (main.part or main.root)
			return ("class=%s drawn=%s attack=%s getup=%s blend=%s weaponAt=%s"):format(tostring(st.classId), tostring(st.drawn), tostring(st.attack ~= nil), tostring(st.getupStart ~= nil), tostring(st.blendKey), part and tostring(part.Position) or "-")
		end
		return nil
	end
	hook.Parent = player:WaitForChild("PlayerGui")
end

-- 남의 공격 중계(서버 AttackServer → AttackMotion)
task.spawn(function()
	local relay = ReplicatedStorage:WaitForChild("AttackMotion", 30)
	if relay then
		relay.OnClientEvent:Connect(function(who, comboCount, isHeavy, isAir)
			if typeof(who) == "Instance" and who ~= player then
				WeaponVisual.playRemote(who, comboCount, isHeavy, isAir)
			end
		end)
	end
end)

return WeaponVisual
