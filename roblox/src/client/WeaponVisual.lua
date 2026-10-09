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
local SkillData = require(ReplicatedStorage.Shared.data.SkillData) -- W3b 채널 스킬 길이 · 틱 간격(서버 틱과 같은 값)
local PoseRig = require(script.Parent.PoseRig)
local AttackTrail = require(script.Parent.AttackTrail) -- W2 칼날 리본 스타일(스킨)
local TrailData = require(ReplicatedStorage.Shared.data.TrailData)
local WeaponEnhanceVisual = require(script.Parent.WeaponEnhanceVisual) -- 강화 단계 이펙트(30-0 S08 - 내 무기만) - 이 파일은 부르기만 한다
local SkillVfx = require(script.Parent.SkillVfx) -- W3c 공중 내려찍기 먼지 · 비장의 한 발 빛 모임 · 어둠 시전(미리보기)
local VfxData = require(ReplicatedStorage.Shared.data.VfxData)
local ArtStyleV1Data = require(ReplicatedStorage.Shared.data.ArtStyleV1Data) -- A2-S 아트 샘플(스위치 뒤 - 대검 등급 3단계 겉모습)
local ArtV1Models = require(ReplicatedStorage.Shared.ArtV1Models)
local ArtMeshKit = require(ReplicatedStorage.Shared.ArtMeshKit) -- A2-N3 Open Cloud 무기 메시
local ArtImportData = require(ReplicatedStorage.Shared.data.ArtImportData)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local GradeColor = require(ReplicatedStorage.Shared.GradeColor)
local SKIN_LOOKS = require(ReplicatedStorage.Shared.data.ArtV1CosmeticData).items -- QUEUE-ALL6 H 무기 꾸미기 · QUEUE-ALL9C 1-6: 소품 look 표로(수정 결정 · 스타터 은빛 날)
local CosmeticItems = require(ReplicatedStorage.Shared.data.CosmeticSlotData).items
local MoveRules = require(ReplicatedStorage.Shared.MoveRules) -- W3c 공중 공격 해금(칼 들어 올림)

local WeaponVisual = {}

local player = Players.LocalPlayer
local M = PlayerMotionData

-- 3타 강공격(16-7): 무기 ×1.3 · 히트스톱(AttackInput이 applyHitstop으로 더 길게)
local HEAVY_WEAPON_SCALE = 1.3
local DRAW_RANGE_STUDS = 220 -- 남의 캐릭터를 이 거리 안에서만 그린다(멀면 무기 숨김 · 관절 안 건드림)

local rigs = {} -- [key(Player 또는 더미 Model)] = 상태
local lastSwingFinisher = false -- W3c-2(WeaponVisual.lastSwingFinisher)
local previewShot -- W3c /gg anim 미리보기(아래 정의)
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
local function overrideModel(classId, pieceName, artModel)
	local folder = ReplicatedStorage.Shared:FindFirstChild(WeaponRigSpec.overrideFolder)
	local entry = artModel or (folder and folder:FindFirstChild(classId)) -- A2-S: 아트 샘플 모델도 같은 규격 검사를 거친다
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

-- 활 시위 두 줄 + 화살(지금 활 · 교체 활 공용 - A2-N4: 교체 활은 시위를 메시에서 빼고 코드가 그린다)
local noteImpact -- A2-N4: 아래(측정 도우미)에서 정의 · 공격 포즈 함수가 먼저 참조

local function buildBowExtras(folder, model, p)
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

local function buildWeapon(classId, colorOverride, parentFolder, artModel, bodyScale)
	bodyScale = bodyScale or 1
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
		local scale = WeaponRigSpec.scaleOf(spec) * (model.kind == "bow" and 1 or bodyScale) -- 활 몸(가지 · 시위 자리 표)은 배율 밖 - 손 자리만 따라간다
		local p = { spec = spec, scale = scale, key = key, bodyScale = bodyScale }
		local custom = overrideModel(classId, spec.name, artModel)
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
			if bodyScale ~= 1 and clone:IsA("Model") then -- QUEUE-ALL4 A3: 손 크기 배율(겉모습만)
				clone:ScaleTo(clone:GetScale() * bodyScale)
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
			if TrailData.ribbon.classes[classId] and clone:GetAttribute("TrailTop") and clone.PrimaryPart then -- A2-S: 교체 모델도 칼날 리본(부착점 = 모델 Attribute · PrimaryPart 로컬)
				p.trail, p.gloss = attachTrail(clone.PrimaryPart, clone:GetAttribute("TrailTop") * bodyScale, clone:GetAttribute("TrailBottom") * bodyScale)
			end
			p.gripLocal = localOf(WeaponRigSpec.attachments.grip)
			p.supportLocal = localOf(WeaponRigSpec.attachments.support)
			p.nockLocal = localOf(WeaponRigSpec.attachments.stringNock)
			p.scale = 1
			if model.kind == "bow" then -- A2-N4 P0-2: 교체 활도 시위 · 화살(옛 = 교체 경로가 p.root 없이 끝나 시위 · 화살이 없었다) · 시위 끝 = Tip과 좌우 대칭
				local tip = localOf(WeaponRigSpec.attachments.tip)
				p.limbs = {}
				if tip then
					p.stringTips = { top = tip, bottom = Vector3.new(-tip.X, tip.Y, tip.Z) }
				end
				buildBowExtras(folder, model, p)
			end
		elseif model.kind == "mesh" or model.kind == "mesh_pair" then
			local part = buildMeshPart(folder, spec.name or "Blade", model.meshId, model.size, model.color)
			part:FindFirstChildOfClass("SpecialMesh").Scale = Vector3.one * scale
			p.part, p.mesh = part, part:FindFirstChildOfClass("SpecialMesh")
			if TrailData.ribbon.classes[classId] and model.trailTop then
				p.trail, p.gloss = attachTrail(part, model.trailTop * bodyScale, model.trailBottom * bodyScale)
			end
		elseif model.kind == "specialmesh" then
			local part = buildMeshPart(folder, "Staff", model.meshId, model.size, model.color, model.textureId)
			part:FindFirstChildOfClass("SpecialMesh").Scale = Vector3.one * scale
			p.part, p.mesh = part, part:FindFirstChildOfClass("SpecialMesh")
			if TrailData.ribbon.closeClasses[classId] and model.trailTop then -- W2-4 가까운 대상 휘두르기 리본
				p.trail, p.gloss = attachTrail(part, model.trailTop * bodyScale, model.trailBottom * bodyScale)
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
			buildBowExtras(folder, model, p)
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
		overlays = {}, deathStart = nil, respawnStart = nil, air = false, lastVy = 0, -- W3b 덧씌움 반응 · 사망 · 부활 · 착지 감지
	}
end

local function attrOf(st, name)
	return st.getAttr(name)
end

local function speedOf(st)
	if not st.classId or st.classId == "" then
		return 1
	end
	return PlayerCombat.getMotionSpeed(st.classId, (attrOf(st, "SpeedPercentBonus") or 0) + (attrOf(st, "FrenzyAttackBonus") or 0), attrOf(st, "AttackSpeedBuffMultiplier")) -- C3-2: 기본 간격 ÷ 실제 간격(1 ~ 1.36 - 서버 AttackServer와 같은 함수)
end

local function inCombat(st, now)
	if st.forcedDrawn ~= nil then
		return st.forcedDrawn
	end
	if attrOf(st, "BossEncounterId") or st.attack or st.getupStart or st.respawnStart or st.deathStart then
		return true
	end
	if os.clock() - st.lastAttackAt < M.combatHoldSeconds then
		return true
	end
	local untilAt = attrOf(st, "CombatUntil")
	return untilAt ~= nil and Workspace:GetServerTimeNow() < untilAt
end

-- QUEUE-ALL4 A3: 아바타 배율(0.8 · 1.35)에서 무기 크기 · 쥔 자리를 손 크기에 맞춘다(겉모습만 - 판정 불변). 옛 = 고정 크기라 0.8배 몸에서 칼이 얼굴 앞을 지났다.
local function handScaleOf(character)
	local hand = character and character:FindFirstChild("RightHand")
	local cfg = WeaponRigSpec.bodyScale
	if not hand or not hand:IsA("BasePart") then
		return 1
	end
	local original = hand:FindFirstChild("OriginalSize") -- R15 배율의 기준 크기(패키지마다 손 크기가 달라 고정 기준값을 못 쓴다 - Play 실측 손 Y 0.89)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local height = humanoid and humanoid:FindFirstChild("BodyHeightScale")
	local raw = (original and original:IsA("Vector3Value") and original.Value.Y > 0) and hand.Size.Y / original.Value.Y or (height and height.Value) or 1
	local s = math.clamp(raw, cfg.min, cfg.max)
	return math.floor(s / cfg.step + 0.5) * cfg.step
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
	local grade = attrOf(st, "WeaponGrade") or 0
	local artModel = ArtMeshKit.weaponModel(classId, ArmorData.gradeOrder[grade + 1] or "normal") -- A2-N3 Open Cloud 메시(ArtStyleV1 뒤 · 캐시에 있을 때만 - 없으면 아래 샘플 · 지금 메시)
	if not artModel and classId == "greatsword" and Workspace:GetAttribute(ArtStyleV1Data.attribute) then -- A2-S 대검 겉모습(같은 형태 · 등급 3단계) - 미리보기 = Attribute ArtV1WeaponLook
		local preview = attrOf(st, "ArtV1WeaponLook")
		local look = ArtStyleV1Data.greatsword.looks[preview] and preview or ArtStyleV1Data.greatsword.gradeLook[grade + 1] or "normal"
		local gradeId = (ArtStyleV1Data.greatsword.looks[preview] and preview ~= "normal") and preview or ArmorData.gradeOrder[grade + 1]
		artModel = ArtV1Models.greatsword(look, GradeColor.of(gradeId))
	end
	local primordialWeapon = artModel == nil and grade >= 6
	st.bodyScale = handScaleOf(st.character)
	st.weapon = buildWeapon(classId, primordialWeapon and Color3.fromRGB(245, 245, 250) or nil, Workspace, artModel, st.bodyScale)
	if artModel then
		artModel:Destroy() -- 무기 폴더에는 복제본이 들어간다
	end
	local skinId = st.weapon and attrOf(st, "Cosmetic_weaponSkin")
	local skin
	for _, item in ipairs(skinId and CosmeticItems or {}) do
		if item.id == skinId and item.slot == "weaponSkin" then
			skin = SKIN_LOOKS[item.look]
		end
	end
	if skin then -- QUEUE-ALL6 H: 몸 파트만 바꾼다(Neon · 빛 = 등급 · 강화 연출은 손대지 않는다) - 색 · 재질 · 반사 · 투명 = look 표
		for _, d in ipairs(st.weapon.folder:GetDescendants()) do
			if d:IsA("BasePart") and d.Material ~= Enum.Material.Neon and d.Transparency < 1 then
				d.Color, d.Material, d.Reflectance = skin.color, Enum.Material[skin.material or "SmoothPlastic"], skin.reflectance or 0
				d.Transparency = math.max(d.Transparency, skin.transparency or 0)
				if d:IsA("MeshPart") and skin.clearTexture then
					d.TextureID = ""
				end
			end
		end
	end
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

-- W3b 채널 스킬(대검 E · 쌍검 E): tm.chan = 채널 길이(시전 순간부터 · 서버 틱과 같은 시계) · tm.period = 틱 간격.
--   [0, ant) 전조 → [ant, chan) 채널(회전 = 틱 한 번에 spinDeg · 틱 순간 가장 빠름 / 번갈아 = 틱마다 한 칼) → act(through) → rec(settle).
local function sampleChannel(clip, tm, tau)
	local ch = clip.channel
	local pose, trail
	if tau < tm.ant then
		pose, trail = mix(poseOf(clip.cocked), poseOf(clip.contact), EASE.inQuad(tau / math.max(tm.ant, 1e-4))), false
	elseif tau < tm.chan then
		trail = true
		if ch.alternate then
			local k = math.floor(tau / tm.period)
			local u = (tau - k * tm.period) / tm.period
			local n = #ch.alternate
			pose = mix(poseOf(ch.alternate[k % n + 1]), poseOf(ch.alternate[(k + 1) % n + 1]), EASE.outCubic(u))
		else
			pose = poseOf(clip.contact)
		end
	elseif tau < tm.chan + tm.act then
		pose, trail = mix(poseOf(clip.contact), poseOf(clip.through), EASE.outCubic((tau - tm.chan) / math.max(tm.act, 1e-4))), true
	else
		pose, trail = mix(poseOf(clip.through), poseOf(clip.settle), EASE.inOutSine(math.min((tau - tm.chan - tm.act) / math.max(tm.rec, 1e-4), 1))), false
	end
	if ch.spinDeg and tau < tm.chan then -- 온몸 회전(Root): 틱 순간(τ = k × 주기)에 가장 빠르고 채널 끝 = 정면(한 바퀴 단위)
		local x = tau / tm.period
		local yaw = ch.spinDeg * x + math.sign(ch.spinDeg) * (ch.wobbleDeg or 0) * math.sin(2 * math.pi * x) / math.pi
		pose = table.clone(pose)
		pose.Root = CFrame.Angles(0, math.rad(yaw), 0) * (pose.Root or CFrame.identity)
	end
	return pose, trail
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
		if a.finisher then -- W3c 비장의 한 발: 당김이 일찍 끝나 짧게 정적(발사 시각 불변)
			u = math.min(u / (1 - M.finisherShot.stillFraction), 1)
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
	elseif tau < t3 then -- W3b: 누움 → 무기 짚고 한쪽 무릎(kneelFraction) → 무기 들며 선다
		local kneel = poseOf(w.getupKneel)
		local tk = G.riseSeconds * (kneel and G.kneelFraction or 0)
		if kneel and tau < t2 + tk then
			return mix(lie, kneel, EASE.outCubic((tau - t2) / tk))
		end
		return mix(kneel or lie, rise, EASE.outCubic((tau - t2 - tk) / (G.riseSeconds - tk)))
	end
	return mix(rise, stance, EASE.inOutSine(math.min((tau - t3) / G.settleSeconds, 1)))
end

-- W3b 사망(비틀 → 무릎 → 엎어짐 · 그대로 누움) · 부활(한쪽 무릎 → 일어남 → 전투 자세).
local function deathPose(tau)
	local D = M.death
	local a, b, c = poseOf(D.stagger), poseOf(D.kneel), poseOf(D.lie)
	if tau < D.staggerSeconds then
		return mix({}, a, EASE.outCubic(tau / D.staggerSeconds))
	elseif tau < D.staggerSeconds + D.kneelSeconds then
		return mix(a, b, EASE.inQuad((tau - D.staggerSeconds) / D.kneelSeconds)) -- 무릎이 풀려 떨어진다(가속)
	end
	return mix(b, c, EASE.outBack(math.min((tau - D.staggerSeconds - D.kneelSeconds) / D.fallSeconds, 1))) -- 엎어지며 살짝 튕김
end
local function respawnTotal()
	local R = M.respawn
	return R.kneelSeconds + R.riseSeconds + R.settleSeconds
end
local function respawnPose(w, tau)
	local R = M.respawn
	local kneel, rise, stance = poseOf(w.getupKneel or w.getupRise), poseOf(w.getupRise), poseOf(w.stance)
	if tau < R.kneelSeconds then
		return kneel
	elseif tau < R.kneelSeconds + R.riseSeconds then
		return mix(kneel, rise, EASE.outCubic((tau - R.kneelSeconds) / R.riseSeconds))
	end
	return mix(rise, stance, EASE.inOutSine(math.min((tau - R.kneelSeconds - R.riseSeconds) / R.settleSeconds, 1)))
end
local function getupTotal()
	local G = M.getup
	return G.bounceSeconds + G.lieSeconds + G.riseSeconds + G.settleSeconds
end
WeaponVisual.getupTotal = getupTotal

-- W2 결정 1: 대상 쪽으로 몸 돌리기(Root 관절 - 루트 파트 · 판정 불변). 공격이 끝나면 포즈에서 빠져 blend로 풀린다.
local function withTurn(a, pose, now)
	if a.turnYaw then
		local turn = CFrame.Angles(0, a.turnYaw * math.min((now - a.start) / M.turnToTarget.seconds, 1), 0)
		pose = table.clone(pose)
		pose.Root = pose.Root and turn * pose.Root or turn -- W3a: 클립의 Root(체중 · 몸 돌림)에 대상 쪽 돌기를 곱한다
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

-- W3c-1: 이 캐릭터가 공중 공격을 할 수 있는 해금 단계인가(플레이어만 - 더미 = 아님)
local function canAirAttack(st)
	local key = st.key
	return typeof(key) == "Instance" and key:IsA("Player") and MoveRules.tierOf(key).airAttack == true
end

-- 한 캐릭터의 목표 포즈. 반환: pose(CFrame 표) · blendKey · blendDur · inHand(무기가 손에) · draw(활) · trailOn · ik(허용)
local function targetPose(st, now, root)
	local w = M.weapons[st.classId]
	if not w then
		return {}, "none", M.blend.default, false, 0, false, false
	end
	-- W3a 키프레임판 재생 중(KeyframeCompare - Animator가 몸을 움직인다): 포즈를 안 쓰고 무기 · 보조 손 IK만(리본 켬)
	if st.external and now < st.external then
		return {}, "external", M.blend.min, true, 0, true, true
	end
	-- W3b 사망(최우선 - 부활 전까지 누움) · 부활
	if st.deathStart then
		return deathPose(now - st.deathStart), "death", M.blend.min, true, 0, false, false
	end
	if st.respawnStart then
		local tau = now - st.respawnStart
		if tau < respawnTotal() then
			return respawnPose(w, tau), "respawn", 0.01, true, 0, false, tau > M.respawn.kneelSeconds
		end
		st.respawnStart = nil
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
			local R = a.finisher and M.finisherShot or M.heavyShot -- W3c 비장의 한 발 = 더 큰 반동
			local since = (a.heavyShot or a.finisher) and a.lastRelease and now - a.lastRelease
			if since and since < R.recoilSeconds then -- W3a 강궁 반동: 쏜 뒤 몸이 살짝 밀린다(sin 모양)
				local k = math.sin(math.pi * since / R.recoilSeconds)
				pose = table.clone(pose)
				for name, cf in pairs(poseOf(R.recoil)) do
					pose[name] = (pose[name] or CFrame.identity) * CFrame.identity:Lerp(cf, k)
				end
			end
			return pose, a.blendKey, a.blendDur, true, draw, false, true -- 쏘기 = 리본 없음(W2-4 휘두르기만)
		end
		st.attack = nil
		a = nil
	end
	if a and a.skill then -- W3b 스킬: 한 번 동작 = 공격 클립과 같은 샘플 · 채널 = 서버 틱 시계(히트스톱은 포즈만 멈추고 시계는 그대로)
		local clip = a.clip
		if a.freezeUntil and now < a.freezeUntil then
			return a.frozenPose or {}, a.blendKey, a.blendDur, true, a.frozenDraw or 0, clip.trail == true, clip.ik ~= false
		end
		if a.freezeUntil then
			if not clip.channel then
				a.start += a.freezeUntil - a.frozeAt
			end
			a.freezeUntil, a.frozeAt = nil, nil
		end
		local tau = now - a.start
		if tau < a.tm.total then
			local pose, draw, trail
			if clip.channel then
				pose, trail = sampleChannel(clip, a.tm, tau)
				draw = 0
			else
				local act
				pose, draw, act = sampleAttack(clip, a.tm, tau)
				trail = act
			end
			a.frozenPose, a.frozenDraw = pose, draw
			return pose, a.blendKey, a.blendDur, true, draw, clip.trail == true and trail, clip.ik ~= false
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
			noteImpact(st, 0.03, (a.hitstop or M.hitstopSeconds) + 0.25) -- A2-M1 측정: 접촉 + 히트스톱 + 동작 시작(의도된 타격)
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
	if character:GetAttribute("Gliding") or now < (st.glideUntil or 0) then
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
	-- W3c-1 대검: 체공 중(공중 공격이 남았을 때) 정점으로 갈수록 칼을 머리 뒤로 끌어올린다 → 공중 내려찍기의 준비 자세(판정 · 규칙 불변 - 자세만)
	if w.airReady and st.air and not st.slamAt and (st.debugAirReady or canAirAttack(st)) and not character:GetAttribute("AirLocked") and not character:GetAttribute("FallKnockdown") then
		local k = math.clamp(1 - v.Y / VfxData.greatswordAir.readyRiseSpeed, 0, 1)
		pose = mix(pose, poseOf(w.airReady), EASE.inOutSine(k))
	end
	return pose, "stance", M.blend.default, true, 0, false, true
end

-- W3b 덧씌움 세기 곡선: 빠르게 들어가(peak - outCubic) → hold → 천천히 풀림(inOutSine).
local function overlayK(def, t)
	local seconds = def.seconds
	local up = seconds * (def.peak or 0.3)
	local hold = def.hold or 0
	if t < up then
		return EASE.outCubic(t / up)
	elseif t < up + hold then
		return 1
	end
	return 1 - EASE.inOutSine(math.min((t - up - hold) / math.max(seconds - up - hold, 1e-3), 1))
end

-- 이번 프레임 덧씌움 { [관절] = { cf, k } } 또는 nil. 시간 반응(st.overlays) + 기절(st.stun) + 넉백 체공(내 캐릭터 AirLocked · 붙잡힘 아님).
local function overlayPose(st, now, character)
	local out = nil
	local function add(tbl, k, sway)
		if k <= 0.001 then
			return
		end
		out = out or {}
		for name, cf in pairs(poseOf(tbl)) do
			if sway and sway[name] then
				cf = cf * CFrame.Angles(0, 0, math.rad(sway[name]))
			end
			local prev = out[name]
			if prev then
				out[name] = { cf = prev.cf * CFrame.identity:Lerp(cf, k), k = math.max(prev.k, k) }
			else
				out[name] = { cf = cf, k = k }
			end
		end
	end
	for i = #st.overlays, 1, -1 do
		local o = st.overlays[i]
		local t = now - o.start
		if t >= o.def.seconds then
			table.remove(st.overlays, i)
		else
			add(o.def.pose, overlayK(o.def, t))
		end
	end
	local s = st.stun
	if s then
		local C = M.overlay.stun
		local t = now - s.start
		if t >= s.seconds then
			st.stun = nil
		else
			local k = t < C.staggerSeconds and EASE.outCubic(t / C.staggerSeconds) or 1
			if t > s.seconds - C.recoverSeconds then
				k = 1 - EASE.inOutSine((t - (s.seconds - C.recoverSeconds)) / C.recoverSeconds)
			end
			local wave = math.sin(2 * math.pi * t / C.swayPeriod)
			local sway = {}
			for name, deg in pairs(C.sway) do
				sway[name] = deg * wave
			end
			if t < C.staggerSeconds then
				add(M.overlay.big.pose, 1 - t / C.staggerSeconds)
			end
			add(C.dazed, k, sway)
		end
	end
	if st.key == player and (character:GetAttribute("AirLocked") or now < (st.debugKnockUntil or 0)) and not st.getupStart then
		st.knockK = math.min((st.knockK or 0) + 0.12, 1)
	else
		st.knockK = math.max((st.knockK or 0) - 0.2, 0)
	end
	if st.knockK > 0 then
		add(M.overlay.knockAir, EASE.inOutSine(st.knockK))
	end
	return out
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

local function updateBow(weapon, p, bowCF, draw, showArrow, palmW, drawScale)
	local model = weapon.model
	for _, limb in ipairs(p.limbs) do
		limb.part.CFrame = bowCF * CFrame.new(limb.spec.relPos) * CFrame.Angles(0, math.rad(limb.spec.relRotYDeg), 0)
	end
	local maxDraw = (p.spec.drawStuds or 1.2) * (drawScale or 1) -- W3a 강궁 = 시위를 더 깊게
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
	seg(p.stringTop, p.stringTips and p.stringTips.top or model.stringTopTip, nock)
	seg(p.stringBottom, p.stringTips and p.stringTips.bottom or model.stringBottomTip, nock)
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
	return handCF * CFrame.new(PALM[p.spec.hand] * p.bodyScale) * p.spec.hold * CFrame.new(-p.gripLocal * heavyMul)
end

local LEG_JOINTS = { RightHip = true, LeftHip = true, RightKnee = true, LeftKnee = true, RightAnkle = true, LeftAnkle = true }
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
	-- W3b 사망 감지(모든 캐릭터) · 착지 · 도약 감지(세로 속도 - 남의 캐릭터도 같은 식)
	if humanoid.Health <= 0 and not st.deathStart then
		st.deathStart, st.attack, st.getupStart, st.respawnStart = now, nil, nil, nil
		if st.key == player then
			root.Anchored = true -- 쓰러진 자리에 둔다(관절이 안 끊기는 몸이 통째로 구르지 않게 - 부활하면 새 캐릭터)
		end
	end
	local vy = root.AssemblyLinearVelocity.Y
	local grounded = st.key == player and humanoid.FloorMaterial ~= Enum.Material.Air or (st.key ~= player and math.abs(vy) < 1.5)
	if humanoid.Health > 0 then
		local O = M.overlay
		if st.air and grounded and st.slamAt then -- W3c-1 공중 내려찍기 뒤 착지 = 먼지 고리 + "쿵"(연출만)
			if now - st.slamAt <= VfxData.greatswordAir.landWindowSeconds then
				SkillVfx.slamLanding(character, st.key == player)
				WeaponVisual.playOverlay(st.key, "landHeavy")
			end
			st.slamAt = nil
		elseif st.air and grounded then
			local fall = -st.lastVy
			if not character:GetAttribute("FallKnockdown") and not character:GetAttribute("AirLocked") and not character:GetAttribute("Gliding") then
				if fall >= O.heavySpeed then
					WeaponVisual.playOverlay(st.key, "landHeavy")
				elseif fall >= O.softSpeed then
					WeaponVisual.playOverlay(st.key, "landSoft")
				end
			end
		elseif not st.air and not grounded and vy > 12 then
			WeaponVisual.playOverlay(st.key, "takeoff")
		end
	end
	st.air = not grounded
	if grounded and st.slamAt and now - st.slamAt > VfxData.greatswordAir.landWindowSeconds then
		st.slamAt = nil
	end
	if not grounded then
		st.lastVy = vy
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
		-- A2-M1 관성 섞기: 전환 순간 관절이 돌던 속도(직전 두 프레임)를 이어받아 지수로 줄이며 새 자세로 - 옛 = 정지 사진에서 출발해 속도가 한 프레임에 0으로 끊겼다
		st.fromVel = nil
		local I = M.inertia
		if I and st.prevApplied and st.prevDt and st.prevDt > 1e-3 and not player:GetAttribute("A2M1InertiaOff") then
			st.fromVel = {}
			for name, cf in pairs(st.applied) do
				local prev = st.prevApplied[name]
				if prev then
					local axis, angle = (prev:Inverse() * cf):ToAxisAngle()
					local rate = angle / st.prevDt
					if rate > I.minRate and rate < I.maxRate then
						st.fromVel[name] = { axis = axis, rate = rate }
					end
				end
			end
		end
	end
	local e = smoother((now - st.blendStart) / st.blendDur)
	local carryT = nil
	if st.fromVel then
		local k = M.inertia.decay
		carryT = (1 - math.exp(-k * (now - st.blendStart))) / k -- ∫ e^(−k t) = 지금까지 이어 돈 양(초 × 속도)
	end
	local applied, appliedW = {}, {}
	for name, cf in pairs(pose) do
		local f = st.from[name] or cf
		local fv = carryT and st.fromVel[name]
		if fv then
			f = f * CFrame.fromAxisAngle(fv.axis, fv.rate * carryT)
		end
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
	st.prevApplied, st.prevDt = st.applied, now - (st.appliedAt or now) -- A2-M1 관성 섞기용(직전 프레임)
	st.applied, st.appliedW, st.appliedAt = applied, appliedW, now
	-- W3a: 다리 · 발 키는 서 있을 때만 - 걷는 동안은 이동 속도만큼 가중치를 줄여 애니메이터 걸음을 살린다(공중 = 그대로)
	local applyW = appliedW
	local v = root.AssemblyLinearVelocity
	local moving = humanoid.FloorMaterial ~= Enum.Material.Air and math.clamp(Vector3.new(v.X, 0, v.Z).Magnitude / M.moveBlendSpeed, 0, 1) or 0
	if moving > 0 then
		applyW = table.clone(appliedW)
		for name in pairs(LEG_JOINTS) do
			if applyW[name] then
				applyW[name] *= 1 - moving
			end
		end
	end
	-- W3b 덧씌움 반응(피격 · 착지 · 도약 · 기절 · 넉백 체공): 지금 포즈 위에 곱한다 · 포즈에 없는 관절 = 세기만큼 애니메이터 위로(저장된 blend 상태는 안 바꾼다)
	local over = overlayPose(st, now, character)
	if over then
		if applied == st.applied then
			applied = table.clone(applied)
		end
		if applyW == appliedW then
			applyW = table.clone(appliedW)
		end
		for name, o in pairs(over) do
			if applied[name] and (applyW[name] or 0) > 0 then
				applied[name] = applied[name] * CFrame.identity:Lerp(o.cf, o.k)
			else
				applied[name], applyW[name] = o.cf, math.max(o.k, applyW[name] or 0)
			end
		end
	end
	local T = PoseRig.apply(rig, applied, applyW)
	local heavyMul = (st.attack and st.attack.heavy) and HEAVY_WEAPON_SCALE or 1
	st.frame = { inHand = inHand, draw = draw, trailOn = trailOn, heavyMul = heavyMul, drawScale = (st.attack and st.attack.finisher) and M.finisherShot.drawStudsScale or ((st.attack and st.attack.heavyShot) and M.heavyShot.drawStudsScale or 1) }
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
			local anchor = spec.drawAnchor + (spec.releaseKick or Vector3.zero) * kick + ((a and a.finisher) and M.finisherShot.drawAnchorExtra * handDraw or ((a and a.heavyShot) and M.heavyShot.drawAnchorExtra * handDraw or Vector3.zero)) -- W3a 강궁 = 더 깊게 · W3c 비장의 한 발 = 더 깊게
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
				local sheath = WeaponRigSpec.sheathCFrame(p.spec.sheath)
				wcf = mount.CFrame * (sheath - sheath.Position + sheath.Position * p.bodyScale) * CFrame.new(-p.gripLocal)
			end
		end
		if wcf then
			placePiece(p, wcf)
			if p.root or p.stringTips then
				local a = st.attack
				local showArrow = f.inHand and not (a and a.ranged and ((a.lastRelease and now - a.lastRelease < a.tm.act) or a.recovering or a.returning))
				local rh = f.inHand and character:FindFirstChild(p.spec.stringHand or "RightHand")
				updateBow(weapon, p, wcf, f.inHand and f.draw or 0, showArrow, rh and rh.CFrame:PointToWorldSpace(PALM[rh.Name] or PALM.RightHand), f.drawScale)
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
-- A2-M1 측정 보조(판정 무관): 의도된 타격 · 반응 순간(공격 접촉 + 히트스톱 · 피격 · 착지 · 도약 · 대시 · 기절 · 넘어짐)을 캐릭터 모델 Attribute ClientImpacts("시작,끝;…" 서버 시각)에
--   적는다(이 클라에만) - client/A2M1Probe가 부드러움 측정에서 뺀다(보스 BossAnimator와 같은 약속).
function noteImpact(st, before, after) -- A2-N4: 앞 선언(위 공격 포즈 함수가 먼저 부른다 - 옛 = 첫 접촉 프레임마다 nil 호출 에러)
	local character = st and st.character
	if not character or not character.Parent then
		return
	end
	local sn = workspace:GetServerTimeNow()
	st.impacts = st.impacts or {}
	table.insert(st.impacts, ("%.3f,%.3f"):format(sn - before, sn + after))
	if #st.impacts > 12 then
		table.remove(st.impacts, 1)
	end
	character:SetAttribute("ClientImpacts", table.concat(st.impacts, ";"))
end

local function stateFor(key)
	return rigs[key]
end

local function bindPlayer(p)
	local st = newState(p, p.Character, function(name)
		return p:GetAttribute(name)
	end)
	rigs[p] = st
	local function refresh()
		local died = st.deathStart ~= nil and st.character ~= p.Character -- W3b: 쓰러진 뒤 새 캐릭터 = 부활 동작
		st.character = p.Character
		st.attack, st.getupStart, st.applied, st.appliedW, st.from, st.fromW, st.blendKey = nil, nil, {}, {}, {}, {}, nil
		st.drawn, st.drawStart = false, -math.huge
		st.deathStart, st.stun, st.overlays, st.air = nil, nil, {}, false
		st.respawnStart = died and os.clock() or nil
		rebuild(st)
	end
	local function watchHand(character) -- A3: 입힌 뒤 배율이 적용되면 손 Size가 바뀐다 → 배율 단계가 달라질 때만 다시 짓는다
		local hand = character and character:WaitForChild("RightHand", 10)
		if not hand then
			return
		end
		hand:GetPropertyChangedSignal("Size"):Connect(function()
			if st.character == character and handScaleOf(character) ~= st.bodyScale then
				rebuild(st)
			end
		end)
	end
	p.CharacterAdded:Connect(function(character)
		task.defer(refresh)
		task.spawn(watchHand, character)
	end)
	if p.Character then
		task.spawn(watchHand, p.Character)
	end
	for _, attr in ipairs({ "ClassId", "WeaponGrade", "ArtV1WeaponLook", "Cosmetic_weaponSkin" }) do
		p:GetAttributeChangedSignal(attr):Connect(refresh)
	end
	-- QUEUE-ALL5 D①: Workspace 신호는 나간 사람 것도 안 끊겨 st(옛 캐릭터 · 무기)를 붙잡았다 → st에 두고 PlayerRemoving에서 끊는다
	st.artStyleConnection = Workspace:GetAttributeChangedSignal(ArtStyleV1Data.attribute):Connect(function() -- A2-S 스위치
		if rigs[p] == st then
			refresh()
		end
	end)
	task.spawn(function() -- A2-N3: 메시 캐시가 늦게 차면(서버 로드 완료) 한 번 다시 짓는다
		local cache = ReplicatedStorage:WaitForChild(ArtImportData.cacheFolder, 120)
		-- FINAL-1 0: 무기 메시는 우선 묶음(약 20초)에 온다 → 그때 한 번 먼저 다시 짓는다(전체 완료 약 50초를 기다리지 않음)
		while cache and not cache:GetAttribute("Ready_weapons") and not cache:GetAttribute(ArtImportData.priorityReadyAttribute) and not cache:GetAttribute(ArtImportData.readyAttribute) do
			cache.AttributeChanged:Wait()
		end
		if cache and rigs[p] == st and not cache:GetAttribute(ArtImportData.readyAttribute) then
			refresh()
		end
		while cache and not cache:GetAttribute(ArtImportData.readyAttribute) do
			cache:GetAttributeChangedSignal(ArtImportData.readyAttribute):Wait()
		end
		if cache and rigs[p] == st then
			refresh()
		end
	end)
	refresh()
end

-- opts(W3a · /gg anim): { close = 가까운 대상 휘두르기 강제 · heavyShot = 강궁 강제 }
local function startAttack(st, index, heavy, air, target, opts)
	if not st or not st.classId then
		return false
	end
	local clip = MotionTiming.clip(st.classId, index, air)
	if not clip then
		return false
	end
	local close = MotionTiming.isRanged(st.classId) and ((opts and opts.close) or isCloseSwing(st, target, air))
	-- W3a 강궁(활 Q 버프 중 - 서버 중계 Attribute AttackSpeedBuffMultiplier) = 깊은 당김 + 반동
	local heavyShot = st.classId == "bow" and ((opts and opts.heavyShot) or (attrOf(st, "AttackSpeedBuffMultiplier") or 1) > 1)
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
		-- W3c-2 비장의 한 발: 활 E 뒤 첫 평타(armSeconds 안) = 새로 깊게 당김 + 빛 모임(발사 시각 = 그대로)
		local finisher = st.classId == "bow" and ((opts and opts.finisher) or (st.finisherArmedAt ~= nil and now - st.finisherArmedAt <= VfxData.bowFinisher.armSeconds))
		st.finisherArmedAt = nil
		if st.key == player then
			lastSwingFinisher = finisher == true
		end
		if finisher then
			SkillVfx.bowGather(st.character, release - now)
		end
		local cur = st.attack
		if cur and cur.ranged and not cur.recovering and not finisher then
			table.insert(cur.queue, release) -- 당긴 채 이어 쏜다
			cur.heavyShot = heavyShot
			return false
		end
		st.attack = { ranged = true, clip = clip, tm = MotionTiming.scale(clip, speedOf(st), heavy, true), start = now, queue = { release }, heavy = heavy, air = air, index = index,
			blendKey = "atk" .. tostring(now), blendDur = M.blend.attackIn, heavyShot = heavyShot, finisher = finisher }
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
	if air and M.weapons[st.classId] and M.weapons[st.classId].airReady then -- W3c-1 대검 공중 내려찍기: 타격 프레임 히트스톱 + 착지 먼지(체공당 1회)
		st.attack.hitstop = VfxData.greatswordAir.hitstopSeconds
		st.slamAt = now
	end
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

-- W3c-2: 방금 시작한 내 원거리 공격이 비장의 한 발인가(AttackInput이 요청 기록에 붙인다 - 서버 버프가 실제로 붙었는지는 발사 이벤트 isBuffedShot)
function WeaponVisual.lastSwingFinisher()
	return lastSwingFinisher
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
-- C3 0-3: target = 서버가 고른 대상(중계 - 돌아서 휘두르기 · 가까운 대상 휘두르기가 남의 화면에도 보인다).
function WeaponVisual.playRemote(key, comboCount, isHeavy, isAir, target)
	startAttack(stateFor(key), isHeavy and 3 or MotionTiming.comboIndex(comboCount), isHeavy, isAir, typeof(target) == "Instance" and target or nil)
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

-- 대시 자세(나 = DashInput · 남 = 중계 "dash" · "dash2"). second = MV1 2단 대시(몸을 비틀어 한 번 더 박참 - 덧씌움).
function WeaponVisual.playDash(key, seconds, second)
	local st = stateFor(key or player)
	if st then
		st.dashUntil = os.clock() + (seconds or 0.3)
		noteImpact(st, 0.03, 0.12) -- A2-M1 측정: 대시 박참(의도된 순간 가속)
		if second then
			WeaponVisual.playOverlay(key or player, "dash2")
		end
	end
end

-- W3b 덧씌움 반응(이름 = PlayerMotionData.overlay의 표 - flinch · big · landSoft · landHeavy · takeoff · coyote · airJump · dash2 · glideIn · glideOut).
function WeaponVisual.playOverlay(key, name)
	local st = stateFor(key or player)
	local def = M.overlay[name]
	if not st or type(def) ~= "table" or not def.pose or st.deathStart then
		return
	end
	if name ~= "glideIn" and name ~= "glideOut" then
		noteImpact(st, 0.03, 0.15) -- A2-M1 측정: 반응 시작(피격 · 착지 · 도약 · 공중 점프 · 2단 대시)
	end
	for i = #st.overlays, 1, -1 do -- 같은 반응은 새로 시작(쌓지 않는다)
		if st.overlays[i].def == def then
			table.remove(st.overlays, i)
		end
	end
	table.insert(st.overlays, { def = def, start = os.clock() })
end

-- 피격(나 = PlayerHitFeedback): 한 대가 최대 체력의 bigHitFraction 이상 = 큰 피격 · 아니면 움찔.
function WeaponVisual.playHit(key, damage, maxHp)
	local big = (maxHp or 0) > 0 and (damage or 0) / maxHp >= M.overlay.bigHitFraction
	WeaponVisual.playOverlay(key, big and "big" or "flinch")
end

-- 기절(보스 playerStun - 모든 화면): 비틀 → 휘청 → 회복(seconds 전체).
function WeaponVisual.playStun(key, seconds)
	local st = stateFor(key or player)
	if st and not st.deathStart then
		st.stun = { start = os.clock(), seconds = math.max(seconds or 1, M.overlay.stun.staggerSeconds + M.overlay.stun.recoverSeconds) }
		noteImpact(st, 0.03, 0.14) -- A2-M1 측정: 기절 시작
	end
end

-- W3b 스킬 모션(나 = SkillInput · 남 = 중계 "skillQ" · "skillE" · A2-M1 "skillR" · "skillT"). 채널 길이 · 틱 간격 = SkillData(서버 틱과 같은 값).
function WeaponVisual.playSkill(key, slot)
	local st = stateFor(key or player)
	local set = st and st.classId and M.skills[st.classId]
	local clip = set and set[slot]
	if not clip or st.deathStart then
		return false
	end
	local now = os.clock()
	st.lastAttackAt = now
	if not st.drawn then
		st.drawn, st.drawStart = true, -math.huge
	end
	local prev = st.attack
	if prev and prev.heavyScaled then
		prev.heavyScaled(false)
	end
	local tm = { ant = clip.ant, act = clip.act, rec = clip.rec, hit = clip.ant }
	if clip.channel then
		local def = SkillData[st.classId] and SkillData[st.classId][slot]
		local chan = def and def.channelSeconds or 1
		tm.chan, tm.period = chan, chan / math.max(def and def.tickCount or 1, 1)
		tm.total = chan + clip.act + clip.rec
	else
		tm.total = clip.ant + clip.act + clip.rec
	end
	st.attack = { skill = slot, clip = clip, tm = tm, start = now, heavyShot = clip.heavyShot, blendKey = "skill" .. tostring(now), blendDur = math.min(M.blend.attackIn, clip.ant) }
	st.getupStart = nil
	if st.classId == "bow" and slot == "E" then -- W3c-2: 다음 평타 1발 = 비장의 한 발
		st.finisherArmedAt = now
	end
	return true
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
	noteImpact(st, 0.03, 0.2) -- A2-M1 측정: 넘어짐 튕김(의도된 충격)
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


-- QUEUE-ALL9C 2-4: 직업 변신 연출(client/ClassTransform)이 내 무기를 잠깐 숨기고 사본을 떨어뜨린다 - 지금 내 무기 폴더(없으면 nil)
function WeaponVisual.getLocalWeaponFolder()
	return current and current.folder
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
	-- W3b 고정(스크린샷): skillQ · skillE · death · respawn · stun · knock · 덧씌움 이름(PlayerMotionData.overlay)
	st.deathStart, st.respawnStart, st.stun, st.overlays, st.debugKnockUntil = nil, nil, nil, {}, nil
	if d.clip == "skillQ" or d.clip == "skillE" then
		if not (st.attack and st.attack.skill == d.clip:sub(6)) then
			WeaponVisual.playSkill(st.key, d.clip:sub(6))
		end
		if st.attack then
			st.attack.start, st.attack.freezeUntil, st.attack.blendDur = now - d.tau, nil, 0.01
		end
		return true
	elseif d.clip == "death" then
		st.attack, st.deathStart = nil, now - d.tau
		return true
	elseif d.clip == "respawn" then
		st.attack, st.respawnStart = nil, now - math.min(d.tau, respawnTotal() - 0.01)
		return true
	elseif d.clip == "stun" then
		st.attack, st.stun = nil, { start = now - d.tau, seconds = 2.5 }
		return true
	elseif d.clip == "knock" then
		st.attack, st.debugKnockUntil, st.knockK = nil, now + 1, 1
		return true
	elseif type(M.overlay[d.clip]) == "table" and M.overlay[d.clip].pose then
		st.attack = nil
		st.dashUntil = d.clip == "dash2" and now + 1 or 0
		st.glideUntil = (d.clip == "glideIn" or d.clip == "glideOut") and now + 1 or 0
		st.overlays = { { def = M.overlay[d.clip], start = now - d.tau } }
		return true
	end
	if d.clip == "finisher" and st.classId == "bow" then -- W3c-2 비장의 한 발 자세(tau = 당김 시작부터 - 발사 = 서버 발사 시각 · 뒤 = 반동)
		local rel = MotionTiming.releaseSeconds(st.classId, false)
		local start = now - d.tau
		local clip = w.attacks[1]
		st.attack = { ranged = true, clip = clip, tm = MotionTiming.scale(clip, 1, false, true), start = start, queue = { start + rel }, index = 1, finisher = true,
			blendKey = "dbgfin" .. d.tau, blendDur = 0.01 }
		if d.tau >= rel then
			st.attack.queue, st.attack.lastRelease = {}, start + rel
		end
		st.getupStart = nil
		return true
	end
	if d.clip == "getup" then
		st.getupStart = now - d.tau
		st.attack = nil
	elseif d.clip:sub(1, 6) == "attack" or d.clip == "heavy" or d.clip == "air" or d.clip == "close" then
		local index = d.clip == "heavy" and 3 or tonumber(d.clip:sub(7)) or 1
		local clip = d.clip == "close" and w.closeSwing or MotionTiming.clip(st.classId, index, d.clip == "air") -- W2-4 "close" = 가까운 대상 휘두르기
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
	if st and st.artStyleConnection then
		st.artStyleConnection:Disconnect()
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

-- W3c 미리보기 발사(/gg anim bow|healer skille - 판정 없음): 활 = 비장의 한 발(깊게 당김 · 빛 모임 → 큰 화살 · 공기 고리 · 흔들림 → 충격 · 히트스톱 · 관통 빛줄기) ·
--   지팡이 = 딜링모드 어둠 구슬(시전 → 비행 → 터졌다 빨려 듦). 앞 20스터드 허공 지점으로.
previewShot = function(st)
	local root = st.character and st.character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local isBow = st.classId == "bow"
	startAttack(st, 1, false, false, nil, { finisher = isBow })
	task.delay(MotionTiming.releaseSeconds(st.classId, false), function()
		local Projectiles = require(script.Parent.Projectiles)
		local muzzle = WeaponVisual.getMuzzleWorldPosition() or (root.Position + Vector3.new(0, 1.5, 0))
		local dir = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
		local to = muzzle + dir * 20
		local kind = isBow and "arrow" or "orb"
		if isBow then
			SkillVfx.bowRelease(muzzle, dir, true)
		end
		Projectiles.fire(kind, muzzle, to, false, isBow and "finisher" or "dark", function(aim)
			if isBow then
				SkillVfx.bowImpact(aim, dir, true)
				SkillVfx.bowStreak(muzzle, aim)
				WeaponVisual.applyHitstop(VfxData.bowFinisher.hitstopSeconds)
			else
				SkillVfx.darkImpact(aim)
			end
		end, { style = AttackTrail.tailStyle(player, kind, false) })
	end)
end

-- W3a 확인 도구 /gg anim <직업> <동작> [반복](서버 DevTools가 Player Attribute DevAnim = "동작|반복|난수"를 올린다 - 내 캐릭터가 반복 재생 · 판정 없음)
do
	local ORDER = { attack1 = { 1 }, attack2 = { 2 }, attack3 = { 3 }, heavy = { 3 }, combo = { 1, 2, 3 } }
	-- W3b: 동작 이름 → 덧씌움 표 이름(dash · dash2 = 대시 자세 + 2단 비틀기)
	local W3B_OVERLAY = { flinch = "flinch", bighit = "big", land = "landSoft", landheavy = "landHeavy", takeoff = "takeoff", coyote = "coyote", airjump = "airJump",
		glidein = "glideIn", glideout = "glideOut", dash = "dash", dash2 = "dash2" }
	player:GetAttributeChangedSignal("DevAnim"):Connect(function()
		local raw = player:GetAttribute("DevAnim")
		if type(raw) ~= "string" then
			return
		end
		local clip, count = string.match(raw, "^(%w+)|(%d+)|")
		count = tonumber(count) or 1
		task.spawn(function()
			task.wait(0.4) -- 직업 전환 · 무기 교체를 기다린다
			for _ = 1, count do
				local st = stateFor(player)
				if not st or not st.classId then
					return
				end
				st.lastAttackAt = os.clock() -- 무기를 든 채 보이게
				if clip == "getup" then
					WeaponVisual.playGetup(player)
					task.wait(getupTotal() + 0.4)
				elseif clip == "skillr" or clip == "skillt" then -- A2-M1 R · T 모션(판정 없음)
					WeaponVisual.playSkill(player, clip == "skillr" and "R" or "T")
					task.wait((st.attack and st.attack.tm.total or 0.8) + 0.5)
				elseif clip == "skillq" or clip == "skille" then -- W3b 스킬(채널 = SkillData 길이)
					if clip == "skille" and st.classId == "healer" then
						SkillVfx.darkCast(st.character) -- W3c-3 딜링모드 켜는 순간(실제 = DealingModeActive 변화 - SkillVfx.watchDealingMode)
					end
					WeaponVisual.playSkill(player, clip == "skillq" and "Q" or "E")
					task.wait((st.attack and st.attack.tm.total or 0.6) + 0.5)
					if clip == "skille" and (st.classId == "bow" or st.classId == "healer") then
						previewShot(st) -- W3c: 비장의 한 발 · 어둠 구슬(발사 · 비행 · 적중 - 판정 없음)
						task.wait(1.2)
					end
				elseif clip == "airattack" then -- W3c-1: 점프 → 정점 가까이 칼을 머리 뒤로 → 공중 내려찍기 → 착지 먼지(판정 없음 · 해금 단계 무관)
					local root = st.character:FindFirstChild("HumanoidRootPart")
					local hum = st.character:FindFirstChildOfClass("Humanoid")
					st.debugAirReady = true
					if hum then
						hum:ChangeState(Enum.HumanoidStateType.Jumping)
					end
					local t0 = os.clock()
					task.wait(0.1)
					while root and root.AssemblyLinearVelocity.Y > 3 and os.clock() - t0 < 1.2 do
						task.wait()
					end
					startAttack(st, 1, false, true, nil)
					task.wait(1.6)
					st.debugAirReady = nil
				elseif W3B_OVERLAY[clip] then -- 덧씌움 반응 · 대시
					if clip == "glidein" then
						st.glideUntil = os.clock() + 1.4
					elseif clip == "glideout" then
						st.glideUntil = os.clock() + 0.6
						task.delay(0.6, WeaponVisual.playOverlay, player, "glideOut")
					end
					if clip == "dash" or clip == "dash2" then
						WeaponVisual.playDash(player, 0.3, clip == "dash2")
					elseif clip ~= "glideout" then
						WeaponVisual.playOverlay(player, W3B_OVERLAY[clip])
					end
					task.wait(1.6)
				elseif clip == "knock" then -- 넉백 체공(1초 유지) → 넘어짐 → 일어나기
					st.debugKnockUntil = os.clock() + 1
					task.wait(1)
					WeaponVisual.playGetup(player)
					task.wait(getupTotal() + 0.4)
				elseif clip == "stun" then
					WeaponVisual.playStun(player, 2.5)
					task.wait(2.9)
				elseif clip == "death" or clip == "respawn" then
					if clip == "death" then
						st.deathStart = os.clock()
						task.wait(2)
					end
					st.deathStart, st.respawnStart = nil, os.clock()
					task.wait(respawnTotal() + 0.5)
				elseif clip == "draw" or clip == "sheathe" then -- 수납 → 꺼내기(sheathe = 반대)
					st.forcedDrawn = clip == "sheathe"
					task.wait(0.8)
					st.forcedDrawn = clip ~= "sheathe"
					task.wait(1)
					st.forcedDrawn = nil
				elseif clip == "kf" then
					local track, length = require(script.Parent.KeyframeCompare).play(player.Character)
					if track then
						st.external = os.clock() + length + 0.1
						task.wait(length + 0.5)
					end
				else
					local interval = CombatConfig.attackTempo.baseIntervalSeconds
					local steps = ORDER[clip] or { 1 }
					for i, index in ipairs(steps) do
						local heavy = clip == "heavy" or (clip == "combo" and i == 3)
						local air = clip == "air"
						local opts = { close = clip == "close", heavyShot = clip == "heavyshot" }
						startAttack(st, index, heavy, air, nil, opts)
						local wait = interval
						if clip == "heavyshot" then
							wait = interval * 1.6 -- 강궁 간격(SkillData.bow.Q.heavyShot.intervalMultiplier)
						end
						task.wait(wait)
					end
					task.wait(0.5)
				end
			end
		end)
	end)
end

-- 남의 공격 중계(서버 AttackServer → AttackMotion)
task.spawn(function()
	local relay = ReplicatedStorage:WaitForChild("AttackMotion", 30)
	if relay then
		relay.OnClientEvent:Connect(function(who, comboCount, isHeavy, isAir, target)
			if typeof(who) == "Instance" and who ~= player then
				WeaponVisual.playRemote(who, comboCount, isHeavy, isAir, target)
			end
		end)
	end
end)

return WeaponVisual
