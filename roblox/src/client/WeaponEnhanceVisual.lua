-- 강화 단계 → 무기 겉모습(30-0 S08, PRD 20.72 [1-9]). 이펙트는 **단계의 함수**다 - 표는 shared/data/EnhanceVisualData.lua, 누적 계산은 shared/EnhanceEffect.resolveVisual이고
-- 여기는 그 결과를 인스턴스로 옮기기만 한다(저장 없음 - 단계가 내려가면 apply가 다시 불려 그 단계의 모습으로 돌아간다).
-- 판정과 무관한 겉모습이다(29-3 원칙) - 서버 값은 하나도 바꾸지 않는다. 새 파티클 · 새 에셋 · 새 색 없음(UIColors 키 + 로블록스 기본 인스턴스).
--
-- 무기 하나가 갖는 이펙트 인스턴스의 상한: PointLight 1 · ParticleEmitter 1 · Highlight 1(12인 예산, PRD 20.72 [1-9]) + 그것을 붙이는 Attachment 1 · Highlight가 감쌀 Model 1(+22부터).
-- 보석 홈을 가리지 않는다(PRD 20.81 [E] 4번): 빛 · 파티클은 날의 몸통 쪽 Attachment(WeaponModelData.effectAnchor)에 붙이고 파티클 ZOffset은 음수(무기 뒤), Highlight는 외곽선만(채움 투명 1)이다.
--
-- WeaponVisual이 apply(weapon, level)를 부른다(무기를 새로 지을 때) - weapon = WeaponVisual의 current({ classId, model, motion, kind, instances }). 이 모듈은 weapon.instances.fx에 자기 인스턴스를
-- 담는다(WeaponVisual.destroyDeep이 무기와 함께 지운다). init(getWeapon)은 WeaponLevel Attribute가 바뀔 때 지금 무기에 다시 apply하고, +25 도달 순간 빛기둥을 세운다.
-- 지금은 **내 무기만** 그린다 - 다른 플레이어의 무기를 그리는 경로가 클라에 아직 없다(README S08 미결).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local EnhanceEffect = require(ReplicatedStorage.Shared.EnhanceEffect)
local EnhanceVisualData = require(ReplicatedStorage.Shared.data.EnhanceVisualData)
local RareMonsterConfig = require(ReplicatedStorage.Shared.data.RareMonsterConfig)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local WorldLabelStyle = require(ReplicatedStorage.Shared.WorldLabelStyle)

local player = Players.LocalPlayer

local WeaponEnhanceVisual = {}

local active -- { weapon, state } - 지금 이펙트가 붙어 있는 무기(매 프레임 맥동 · 무지개를 돌린다)
local pillars = {} -- { { rig, beam, expiresAt } } - +25 도달 순간의 빛기둥
local titleGui, titleLabel -- 머리 위 칭호(+25)

local function colorOf(key)
	return UIColors[key]
end

local function destroyField(fx, name)
	if fx[name] then
		fx[name]:Destroy()
		fx[name] = nil
	end
end

-- 몸체 파트(색 보간 대상) · 이펙트를 다는 파트 · Trail 목록. 종류(kind)마다 instances 구조가 다르다(WeaponVisual.buildWeapon 참고).
local function bodyParts(weapon)
	local instances = weapon.instances
	if weapon.kind == "mesh" or weapon.kind == "specialmesh" then
		return { instances.part }
	elseif weapon.kind == "mesh_pair" then
		local parts = {}
		for _, part in pairs(instances.parts) do
			table.insert(parts, part)
		end
		return parts
	end
	local parts = {} -- bow: 활 몸체 마디(시위 · 화살은 제외)
	for _, limb in ipairs(instances.limbs) do
		table.insert(parts, limb.part)
	end
	return parts
end

local function effectParent(weapon)
	local instances = weapon.instances
	if weapon.kind == "mesh_pair" then
		return instances.parts[weapon.model.effectPart]
	elseif weapon.kind == "bow" then
		return instances.root
	end
	return instances.part
end

local function trailsOf(weapon)
	local instances = weapon.instances
	if weapon.kind == "mesh" then
		return { instances.trail }
	elseif weapon.kind == "mesh_pair" then
		local trails = {}
		for _, trail in pairs(instances.trails) do
			table.insert(trails, trail)
		end
		return trails
	end
	return {}
end

-- 무기의 모든 BasePart를 Model 하나에 담는다(Highlight는 Adornee 하나만 감쌀 수 있다 - 두 칼 · 활 마디 전부를 한 외곽선으로). 파트는 계속 Anchored로 WeaponVisual이 매 프레임 옮긴다.
local function collectBaseParts(value, out)
	if typeof(value) == "Instance" then
		if value:IsA("BasePart") then
			table.insert(out, value)
		end
	elseif type(value) == "table" then
		for key, child in pairs(value) do
			if key ~= "fx" then
				collectBaseParts(child, out)
			end
		end
	end
end

local function ensureModel(weapon, fx)
	if fx.model then
		return fx.model
	end
	local model = Instance.new("Model")
	model.Name = "Weapon_EnhanceRoot"
	local parts = {}
	collectBaseParts(weapon.instances, parts)
	for _, part in ipairs(parts) do
		part.Parent = model
	end
	model.Parent = Workspace
	fx.model = model
	return model
end

local function applyLight(weapon, fx, light)
	if not light then
		destroyField(fx, "light")
		return
	end
	if not fx.light then
		fx.light = Instance.new("PointLight")
		fx.light.Name = "EnhanceGlow"
		fx.light.Parent = fx.anchor
	end
	fx.light.Color = colorOf(light.color)
	fx.light.Brightness = light.brightness
	fx.light.Range = light.range
end

local function applyParticle(fx, particle)
	if not particle then
		destroyField(fx, "emitter")
		return
	end
	local style = EnhanceVisualData.particleStyle
	if not fx.emitter then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "EnhanceSparks"
		emitter.Lifetime = NumberRange.new(style.lifetime.min, style.lifetime.max)
		emitter.Speed = NumberRange.new(style.speed.min, style.speed.max)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, style.size), NumberSequenceKeypoint.new(1, 0) })
		emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, style.transparencyStart), NumberSequenceKeypoint.new(1, 1) })
		emitter.LightEmission = style.lightEmission
		emitter.ZOffset = style.zOffset
		emitter.Parent = fx.anchor
		fx.emitter = emitter
	end
	fx.emitter.Rate = particle.rate
	fx.emitter.Color = particle.colorTo and ColorSequence.new(colorOf(particle.color), colorOf(particle.colorTo)) or ColorSequence.new(colorOf(particle.color))
end

local function applyHighlight(weapon, fx, highlight)
	if not highlight then
		destroyField(fx, "highlight")
		return
	end
	if not fx.highlight then
		local model = ensureModel(weapon, fx)
		local created = Instance.new("Highlight")
		created.Name = "EnhanceOutline"
		created.Adornee = model
		created.DepthMode = Enum.HighlightDepthMode.Occluded
		created.FillTransparency = 1
		created.Parent = model
		fx.highlight = created
	end
	fx.highlight.OutlineColor = colorOf(highlight.color)
	fx.highlight.FillTransparency = highlight.fillTransparency
end

local function applyBody(weapon, state)
	local baseColor = weapon.model.color
	for _, part in ipairs(bodyParts(weapon)) do
		part.Color = state.tint and baseColor:Lerp(colorOf(state.tint.color), state.tint.alpha) or baseColor
	end
	local trailWidth = weapon.motion.trailWidth * (state.trailWidthScale or 1)
	for _, trail in ipairs(trailsOf(weapon)) do
		trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, trailWidth), NumberSequenceKeypoint.new(1, 0) })
		trail.Color = ColorSequence.new(state.trailColor and colorOf(state.trailColor) or weapon.motion.trailColor)
	end
end

-- 머리 위 칭호(+25, WorldLabelStyle). 캐릭터가 새로 스폰되면 Head가 늦게 올 수 있어 기다린다.
local function applyTitle(title)
	if not title then
		if titleGui then
			titleGui:Destroy()
			titleGui, titleLabel = nil, nil
		end
		return
	end
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		if character then
			task.spawn(function()
				local later = character:WaitForChild("Head", 5)
				if later and player.Character == character then
					applyTitle(active and active.state.title)
				end
			end)
		end
		return
	end
	if titleGui and titleGui.Parent == head then
		titleLabel.Text = title.text
		return
	end
	if titleGui then
		titleGui:Destroy()
	end
	titleGui = Instance.new("BillboardGui")
	titleGui.Name = "EnhanceTitle"
	titleGui.Size = UDim2.fromOffset(120, 32)
	titleGui.StudsOffset = Vector3.new(0, title.studsOffsetY, 0)
	titleGui.Adornee = head
	WorldLabelStyle.setupNameplateBillboard(titleGui, 200)
	titleGui.Parent = head
	titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.fromScale(1, 1)
	titleLabel.Text = title.text
	titleLabel.TextColor3 = UIColors.textPrimary
	WorldLabelStyle.styleNameplateText(titleLabel, title.textSize)
	titleLabel.Parent = titleGui
end

-- 무기에 level 단계의 모습을 입힌다(멱등 - 같은 단계로 다시 불러도 · 단계가 내려가도 그 단계의 모습이 된다).
function WeaponEnhanceVisual.apply(weapon, level)
	local state = EnhanceEffect.resolveVisual(level)
	local fx = weapon.instances.fx
	if not fx then
		fx = {}
		weapon.instances.fx = fx
	end
	if (state.light or state.particle) and not fx.anchor then
		local anchor = Instance.new("Attachment")
		anchor.Name = "EnhanceAnchor"
		anchor.Position = weapon.model.effectAnchor
		anchor.Parent = effectParent(weapon)
		fx.anchor = anchor
	end
	applyLight(weapon, fx, state.light)
	applyParticle(fx, state.particle)
	applyHighlight(weapon, fx, state.highlight)
	applyBody(weapon, state)
	applyTitle(state.title)
	active = { weapon = weapon, state = state }
end

-- 무기가 사라졌다(클래스 교체 · 재스폰) - 인스턴스는 WeaponVisual이 지운다. 칭호는 캐릭터에 붙어 있어 그대로 둔다.
function WeaponEnhanceVisual.clear()
	active = nil
end

local function spawnPillar(seconds)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local rig = Instance.new("Part")
	rig.Name = "EnhancePillarRig"
	rig.Size = Vector3.new(1, 1, 1)
	rig.Transparency = 1
	rig.Anchored = true
	rig.CanCollide = false
	rig.CanQuery = false
	rig.CanTouch = false
	rig.Position = root.Position - Vector3.new(0, 3, 0)
	local center = Instance.new("Attachment")
	center.Parent = rig
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, RareMonsterConfig.pillarHeightStuds, 0)
	top.Parent = rig
	local beam = Instance.new("Beam")
	beam.Attachment0 = center
	beam.Attachment1 = top
	beam.Width0 = RareMonsterConfig.pillarWidthStuds
	beam.Width1 = RareMonsterConfig.pillarWidthStuds * 0.3
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Parent = rig
	rig.Parent = Workspace
	table.insert(pillars, { rig = rig, beam = beam, expiresAt = os.clock() + seconds })
end

local function update()
	local now = os.clock()
	local rainbowColor = Color3.fromHSV((now % EnhanceVisualData.rainbow.cycleSeconds) / EnhanceVisualData.rainbow.cycleSeconds, 1, 1)

	for index = #pillars, 1, -1 do
		local pillar = pillars[index]
		if now >= pillar.expiresAt then
			pillar.rig:Destroy()
			table.remove(pillars, index)
		else
			pillar.beam.Color = ColorSequence.new(rainbowColor)
		end
	end

	if not active then
		return
	end
	local fx, state = active.weapon.instances.fx, active.state
	if not fx then
		return
	end
	local pulse = state.light and state.light.pulse
	if pulse and fx.light then
		fx.light.Brightness = pulse.min + (pulse.max - pulse.min) * (0.5 + 0.5 * math.sin(now * 2 * math.pi / pulse.periodSeconds))
	end
	if state.rainbow then
		local sequence = ColorSequence.new(rainbowColor)
		if fx.light then
			fx.light.Color = rainbowColor
		end
		if fx.emitter then
			fx.emitter.Color = sequence
		end
		if fx.highlight then
			fx.highlight.OutlineColor = rainbowColor
		end
		for _, trail in ipairs(trailsOf(active.weapon)) do
			trail.Color = sequence
		end
		if titleLabel then
			titleLabel.TextColor3 = rainbowColor
		end
	end
end

-- getWeapon() = WeaponVisual의 지금 무기(없으면 nil). WeaponLevel이 바뀔 때마다 그 무기에 다시 apply하고, 단계에 도달하는 순간의 빛기둥(+25)을 세운다.
function WeaponEnhanceVisual.init(getWeapon)
	local lastLevel = player:GetAttribute("WeaponLevel") or 0
	player:GetAttributeChangedSignal("WeaponLevel"):Connect(function()
		local level = player:GetAttribute("WeaponLevel") or 0
		local weapon = getWeapon()
		if weapon then
			WeaponEnhanceVisual.apply(weapon, level)
		end
		local pillarSeconds = EnhanceEffect.getArrivalPillarSeconds(level)
		if pillarSeconds and level > lastLevel then
			spawnPillar(pillarSeconds)
		end
		lastLevel = level
	end)
	RunService.RenderStepped:Connect(update)
end

return WeaponEnhanceVisual
