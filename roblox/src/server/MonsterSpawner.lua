-- 몬스터 인스턴스 생성·사망·리스폰. 이름표 HP 표시 갱신도 여기서 한다.
-- HP<=0인지 판단은 AttackServer가 하고(데미지를 적용한 직후라 그 값을 이미 들고 있다),
-- 그 다음 처리(로그·MonsterState 정리·인스턴스 제거·리스폰 예약)는 여기 despawn()이 맡는다.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local WorldLabelStyle = require(ReplicatedStorage.Shared.WorldLabelStyle)
local RareMonsterConfig = require(ReplicatedStorage.Shared.data.RareMonsterConfig)
local MonsterPrefixData = require(ReplicatedStorage.Shared.data.MonsterPrefixData)
local TreasureChestConfig = require(ReplicatedStorage.Shared.data.TreasureChestConfig)
local MonsterState = require(script.Parent.MonsterState)
local GroundProbe = require(script.Parent.GroundProbe)
local TerrainConfig = require(ReplicatedStorage.Shared.data.TerrainConfig)

-- 22-4: 스폰·리스폰 위치를 그 자리 지면 위(발 오프셋 1.5)로 스냅한다. 첫 스폰(HuntingGround)·
-- 리스폰(despawn의 spawnPosition 재사용)·보스(BossEncounter)·상자 전부 이 함수를 지나므로
-- 여기 한 곳이 "리스폰 위치도 지면 위에 놓인다"를 보장한다. 지면을 못 찾으면 받은 Y 그대로.
local function snapToGround(position)
	local groundY = GroundProbe.surfaceY(position.X, position.Z, position.Y)
	if groundY then
		return Vector3.new(position.X, groundY + TerrainConfig.monsterFootOffsetStuds, position.Z)
	end
	return position
end

local MonsterSpawner = {}

-- 보물상자 등장 알림(22-2 [3]) - 서버 전체에 한 번 쏜다(클라 TreasureChestHud.client.lua가
-- 토스트로 띄운다). 구역 한정이 아니라 서버 전체인 이유: "모여들게" 만드는 장치라 다른
-- 구역에 있는 사람이 알아야 하고, 빈도가 반짝이의 1/5(약 17분에 1번)라 PRD 20.4의 스팸
-- 기준(희귀 이상 드랍을 채팅에 띄우는 것보다 훨씬 드물다)을 한참 밑돈다.
local treasureChestNotice = Instance.new("RemoteEvent")
treasureChestNotice.Name = "TreasureChestNotice"
treasureChestNotice.Parent = ReplicatedStorage

local DEFAULT_BODY_COLOR = Color3.fromRGB(150, 90, 200)
local DEFAULT_HEAD_COLOR = Color3.fromRGB(180, 120, 220)

-- 변종 판정 전용 독립 스트림(10-4의 critRng·17-1의 lootRng와 같은 이유 - math.random의
-- 전역 시드를 다른 판정과 공유하지 않는다). 반짝이·접두사·보물상자 셋이 같은 스트림을
-- 순서대로 쓴다(rollVariant).
local variantRng = Random.new()

-- 스폰 시점 변종 판정(22-2). 순서: 보물상자(0.1%) → 반짝이(0.5%) → 접두사(합 10%).
-- 상자는 몬스터 자체를 대체하므로 가장 먼저, 반짝이는 접두사와 겹치지 않게(반짝이 자체가
-- 이미 변종이라 "거대한 반짝이"까지 만들면 이름·크기·이펙트가 한 개체에 몰린다) 접두사보다
-- 먼저 굴린다. 보스는 호출부(spawn)가 이 함수를 아예 안 부른다.
local function rollVariant()
	if variantRng:NextNumber() < TreasureChestConfig.spawnChance then
		return { isChest = true }
	end
	if variantRng:NextNumber() < RareMonsterConfig.sparkleChance then
		return { isSparkle = true }
	end
	local prefixRoll = variantRng:NextNumber()
	local acc = 0
	for _, prefix in ipairs(MonsterPrefixData.prefixes) do
		acc += prefix.chance
		if prefixRoll < acc then
			return { prefix = prefix }
		end
	end
	return {}
end

-- 표시 이름 - 접두사가 있으면 "단단한 슬라임"(22-2 [1]). 이름표는 조준 시에만 뜨는 16-7
-- 규칙 그대로 - 평소 구별은 크기(prefix.sizeMultiplier)가 맡는다.
local function displayNameFor(data, variant)
	if variant.prefix then
		return variant.prefix.displayName .. " " .. data.displayName
	end
	return data.displayName
end

-- 기본 파트 조합으로 "구분되는 덩어리" 하나를 만든다. Humanoid는 애니메이션·이름표 전용이고
-- 실제 HP는 MonsterState가 관리한다(Humanoid.MaxHealth=100은 쓰이지 않는 더미값).
--
-- 23-6 [3] 보스 실루엣 부착물(에셋 동결 - 기존 파트 조합만 쓴다). data.attachments는
-- BossData의 6종 SPECIES 표에만 있다(잡몹·상자는 nil이라 이 함수가 통째로 no-op).
-- anchor는 "body"|"head" - 그 파트의 실제 위치(bodyAspect 반영 후)를 기준으로 offset(사이즈
-- 배율 전 스터드 단위)만큼 떨어뜨린다. 새 판정 함수는 없다 - CanCollide=false라 히트박스·
-- 어그로·리쉬(전부 루트 위치 기준, 파트 크기 무관 - MonsterAI/Reach 확인됨)에 영향이 없다.
local function buildAttachments(model, data, sizeScale, bodyColor, headColor, bodyPosition, headPosition)
	for _, spec in ipairs(data.attachments or {}) do
		local part
		if spec.kind == "wedge" then
			part = Instance.new("WedgePart")
		else
			part = Instance.new("Part")
			if spec.kind == "ball" then
				part.Shape = Enum.PartType.Ball
			end
		end
		part.Name = spec.name or "BossAttachment"
		part.Size = spec.size * sizeScale
		part.Anchored = true
		part.CanCollide = false
		part.CastShadow = false
		part.Color = (spec.color == "head") and headColor or bodyColor
		local anchorPosition = (spec.anchor == "head") and headPosition or bodyPosition
		local rot = spec.rotationDeg or Vector3.new(0, 0, 0)
		part.CFrame = CFrame.new(anchorPosition + spec.offset * sizeScale) * CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
		part.Parent = model
	end
end

-- sizeScale/bodyColor/headColor(15-1, 기본값은 잡몹 그대로) - 보스를 "확실히 크게"
-- 만들라는 지시를 아트 리소스 없이 기본 파트 크기·색만으로 만족시킨다(하지 말 것:
-- 아트·모션 다듬기, 동결 상태). bodyAspect(23-6, 기본 (1,1,1)) - 몸통 X/Y/Z축을 따로
-- 늘여 6종 보스의 실루엣을 구분한다(거인은 높고 좁게, 전갈은 낮고 넓게 - BossData 참고).
-- 높이(Y)만 바뀌어도 발이 땅에 그대로 붙어 있도록 몸통 중심을 발밑 기준으로 다시 잡는다 -
-- 안 그러면 커진 절반만큼 발이 땅속에 파묻히거나 뜬다.
local function buildModel(data, position, variant)
	-- 크기 축(22-2 [1]) - 접두사 변종만 쓴다. 반짝이는 더 이상 크기를 안 건드린다(모델 속성을
	-- 바꾸면 최종 모델로 교체할 때 사라진다 - RareMonsterConfig.lua 주석).
	local sizeScale = (data.sizeScale or 1) * (variant.prefix and variant.prefix.sizeMultiplier or 1)
	local bodyColor = data.bodyColor or DEFAULT_BODY_COLOR
	local headColor = data.headColor or DEFAULT_HEAD_COLOR
	local bodyAspect = data.bodyAspect or Vector3.new(1, 1, 1)
	local displayName = displayNameFor(data, variant)

	local model = Instance.new("Model")
	model.Name = displayName
	-- 22-5(PRD 20.49 [1]): StreamingEnabled에서 3파트(루트·몸통·머리)가 따로따로 스트리밍되지 않게
	-- 모델 단위로 묶는다 - 멀리서 Head만 먼저 오는 프레임을 없앤다(클라 수신부의 nil 가드는 그대로).
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	CollectionService:AddTag(model, "Monster") -- 클라이언트 AimTarget.lua가 이 태그로만 조준 후보를 찾는다

	-- 반짝이 몬스터(19-4 [6] → 22-2 [2]) - 서버는 태그만 붙인다. 발광·파티클·빛기둥은 전부
	-- 클라이언트 SparkleMonsterVisual.client.lua가 모델 **밖에** 자기 이펙트 파트를 만들어
	-- 피벗을 따라가게 한다 - 모델의 어떤 속성(크기·색·재질·자식)도 건드리지 않으므로 나중에
	-- 최종 모델로 갈아끼워도(태그 + PrimaryPart만 유지되면) 반짝임이 그대로 산다.
	if variant.isSparkle then
		CollectionService:AddTag(model, "SparkleMonster")
	end

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1) * sizeScale
	root.Transparency = 1
	root.CanCollide = false
	root.Anchored = true
	root.Position = position
	root.Parent = model

	-- 23-6: 높이(Y)가 바뀌어도 발이 원래 자리(position.Y - 1.5*sizeScale)에 그대로 붙도록
	-- 몸통 중심을 다시 계산한다. bodyAspect=(1,1,1)이면 아래 식 전부 기존 값과 정확히 같다.
	local bodyHalfHeight = 1.5 * sizeScale * bodyAspect.Y
	local bodyBottomY = position.Y - 1.5 * sizeScale
	local bodyCenterY = bodyBottomY + bodyHalfHeight

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(2.4 * bodyAspect.X, 3 * bodyAspect.Y, 1.2 * bodyAspect.Z) * sizeScale
	body.Anchored = true
	-- 21-3: 보스 몸통은 캐릭터와 충돌하지 않는다. 진동파(뛰었다 찍기)·돌진(60stud/s)으로
	-- 움직이는 anchored 파트가 캐릭터를 밀어내면 물리가 캐릭터를 바닥 아래로 튕겨
	-- FallenPartsDestroyHeight까지 떨어뜨려 "HP는 남았는데 죽는" 엔진 사망이 났다(21-3 검증
	-- 중 재현). 피격 판정은 전부 거리 기반이라 충돌이 필요 없다.
	-- 22-5: 잡몹도 끈다. 22-4 검증 중 추격하는 잡몹 몸통(PivotTo로 순간 이동하는 anchored 파트)이
	-- 플레이어를 밀어 고원 가장자리에서 떨어뜨리는 일이 두 번 있었다 - 평지에선 무해했던 밀림이
	-- 높낮이가 생기자 위험 요소가 됐다. "밀려서 떨어짐"은 의도된 위험이 아니라 사고다(낙하 피해
	-- 없음·절벽은 도달원 밖이라는 20.50 규칙 어디에도 "밀려 떨어짐"이 설계에 없다). 밀림 힘은
	-- anchored 파트라 줄일 수 없고(물리가 겹침을 무조건 해소한다), 난간은 절벽마다 파트를 더한다.
	-- 충돌을 끄면 겹침 자체가 없다 - 잡몹은 사거리(10) 밖에서 멈추지 않고 플레이어 자리까지
	-- 오므로 겹치는 순간이 생기지만(PRD 20.51 [5] 실기 관찰) 탑다운 3인칭에서 어색하지 않았다.
	body.CanCollide = false
	body.Color = bodyColor
	body.Position = Vector3.new(position.X, bodyCenterY, position.Z)
	body.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.6, 1.6, 1.6) * sizeScale
	head.Anchored = true
	head.CanCollide = false -- 위 Body와 같은 이유(21-3 보스 → 22-5 전체)
	head.Color = headColor
	-- 몸통 꼭대기(bodyBottomY + 2*bodyHalfHeight)에 머리 반지름(0.8*sizeScale)만큼 얹는다 -
	-- bodyAspect=(1,1,1)이면 bodyBottomY + 3*sizeScale + 0.8*sizeScale = position.Y + 2.3*sizeScale로
	-- 기존 값과 정확히 같다.
	head.Position = Vector3.new(position.X, bodyBottomY + 2 * bodyHalfHeight + 0.8 * sizeScale, position.Z)
	head.Parent = model

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.NameDisplayDistance = 0
	humanoid.Parent = model

	-- 머리 위 표시(16-7 재설계) - 평소엔 HP바만(여러 마리가 모이면 이름 글씨가 겹친다,
	-- 구역이 이미 tier를 말해줘서 이름은 중복 정보), 조준 대상일 때만 이름을 띄운다.
	-- Visible/Highlight.Enabled 토글은 클라이언트(AimTarget.lua)가 한다 - LocalScript가
	-- 바꾼 프로퍼티는 그 클라이언트에만 보이므로 플레이어마다 다른 대상을 조준해도 안전하다.
	local nameplateGui = Instance.new("BillboardGui")
	nameplateGui.Name = "NameplateGui"
	nameplateGui.Size = UDim2.new(0, 130 * sizeScale, 0, 40 * sizeScale)
	nameplateGui.StudsOffset = Vector3.new(0, 1.6 * sizeScale, 0)
	nameplateGui.AlwaysOnTop = true
	nameplateGui.Adornee = head
	nameplateGui.Parent = head
	WorldLabelStyle.setupNameplateBillboard(nameplateGui, 100)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0, 20)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = displayName
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.Visible = false -- 조준 대상일 때만 AimTarget.lua가 true로 바꾼다
	nameLabel.Parent = nameplateGui
	WorldLabelStyle.styleNameplateText(nameLabel, 16)

	local barBackground = Instance.new("Frame")
	barBackground.Name = "HpBarBackground"
	barBackground.Size = UDim2.new(1, 0, 0, 8)
	barBackground.Position = UDim2.new(0, 0, 1, -8)
	barBackground.BackgroundColor3 = Color3.new(0, 0, 0)
	barBackground.BackgroundTransparency = 0.35
	barBackground.BorderSizePixel = 0
	barBackground.Parent = nameplateGui

	local barBackgroundCorner = Instance.new("UICorner")
	barBackgroundCorner.CornerRadius = UDim.new(1, 0)
	barBackgroundCorner.Parent = barBackground

	local barFill = Instance.new("Frame")
	barFill.Name = "HpBarFill"
	barFill.Size = UDim2.new(1, 0, 1, 0)
	barFill.BackgroundColor3 = Color3.fromRGB(210, 60, 60)
	barFill.BorderSizePixel = 0
	barFill.Parent = barBackground

	local barFillCorner = Instance.new("UICorner")
	barFillCorner.CornerRadius = UDim.new(1, 0)
	barFillCorner.Parent = barFill

	-- 조준 대상 강조 외곽선(16-7) - 기본은 꺼져 있다. AimTarget.lua가 조준 대상 모델에서만
	-- Enabled를 켠다.
	local highlight = Instance.new("Highlight")
	highlight.Name = "AimHighlight"
	highlight.Enabled = false
	highlight.FillTransparency = 1
	highlight.OutlineColor = Color3.fromRGB(255, 230, 90)
	highlight.OutlineTransparency = 0
	highlight.Parent = model

	buildAttachments(model, data, sizeScale, bodyColor, headColor, body.Position, head.Position)

	model.PrimaryPart = root
	return model
end

-- 보물상자 모델(22-2 [3]) - 기본 파트만(아트 동결). 조준·피격 경로가 잡몹과 같아야 하므로
-- 구조(HumanoidRootPart PrimaryPart + Head + NameplateGui/HpBar + AimHighlight + "Monster"
-- 태그)는 buildModel과 맞춘다 - AimTarget.lua·AimPicker·updateHpLabel이 그대로 동작한다.
-- 멀리서 눈에 띄게: 잡몹보다 훨씬 큰 몸통 + 금테 + PointLight + 하늘로 뻗는 빛기둥(반짝이
-- 이펙트 레이어와 같은 수단 - 상자는 우리가 만든 파트라 서버가 직접 붙여도 된다).
local function buildChestModel(position)
	local cfg = TreasureChestConfig
	local model = Instance.new("Model")
	model.Name = "보물상자"
	CollectionService:AddTag(model, "Monster")
	CollectionService:AddTag(model, "TreasureChest")

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.CanCollide = false
	root.Anchored = true
	root.Position = position
	root.Parent = model

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = cfg.sizeStuds
	body.Anchored = true
	body.CanCollide = true
	body.Material = Enum.Material.WoodPlanks
	body.Color = cfg.bodyColor
	body.Position = position + Vector3.new(0, cfg.sizeStuds.Y / 2 - 1, 0)
	body.Parent = model

	local trim = Instance.new("Part")
	trim.Name = "Trim"
	trim.Size = Vector3.new(cfg.sizeStuds.X + 0.2, 0.6, cfg.sizeStuds.Z + 0.2)
	trim.Anchored = true
	trim.CanCollide = false
	trim.Material = Enum.Material.Neon
	trim.Color = cfg.trimColor
	trim.Position = body.Position
	trim.Parent = model

	-- 머리 파트 - 이름표 앵커(buildModel의 Head 역할). 상자 뚜껑 위에 얹는 작은 금덩이.
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.2, 1.2, 1.2)
	head.Anchored = true
	head.CanCollide = false
	head.Material = Enum.Material.Neon
	head.Color = cfg.trimColor
	head.Position = position + Vector3.new(0, cfg.sizeStuds.Y + 0.2, 0)
	head.Parent = model

	local glow = Instance.new("PointLight")
	glow.Color = cfg.trimColor
	glow.Range = cfg.glowRangeStuds
	glow.Brightness = cfg.glowBrightness
	glow.Parent = head

	-- 빛기둥 - 두 Attachment 사이 Beam. 상자 위에서 하늘로.
	local bottom = Instance.new("Attachment")
	bottom.Name = "PillarBottom"
	bottom.Parent = head
	local top = Instance.new("Attachment")
	top.Name = "PillarTop"
	top.Position = Vector3.new(0, cfg.pillarHeightStuds, 0)
	top.Parent = head
	local beam = Instance.new("Beam")
	beam.Attachment0 = bottom
	beam.Attachment1 = top
	beam.Width0 = cfg.pillarWidthStuds
	beam.Width1 = cfg.pillarWidthStuds * 0.4
	beam.Color = ColorSequence.new(cfg.trimColor)
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Parent = head

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.NameDisplayDistance = 0
	humanoid.Parent = model

	local nameplateGui = Instance.new("BillboardGui")
	nameplateGui.Name = "NameplateGui"
	nameplateGui.Size = UDim2.new(0, 160, 0, 40)
	nameplateGui.StudsOffset = Vector3.new(0, 1.6, 0)
	nameplateGui.AlwaysOnTop = true
	nameplateGui.Adornee = head
	nameplateGui.Parent = head
	WorldLabelStyle.setupNameplateBillboard(nameplateGui, 100)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0, 20)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = model.Name
	nameLabel.TextColor3 = cfg.trimColor
	nameLabel.Visible = false
	nameLabel.Parent = nameplateGui
	WorldLabelStyle.styleNameplateText(nameLabel, 16)

	local barBackground = Instance.new("Frame")
	barBackground.Name = "HpBarBackground"
	barBackground.Size = UDim2.new(1, 0, 0, 8)
	barBackground.Position = UDim2.new(0, 0, 1, -8)
	barBackground.BackgroundColor3 = Color3.new(0, 0, 0)
	barBackground.BackgroundTransparency = 0.35
	barBackground.BorderSizePixel = 0
	barBackground.Parent = nameplateGui
	local barBackgroundCorner = Instance.new("UICorner")
	barBackgroundCorner.CornerRadius = UDim.new(1, 0)
	barBackgroundCorner.Parent = barBackground

	local barFill = Instance.new("Frame")
	barFill.Name = "HpBarFill"
	barFill.Size = UDim2.new(1, 0, 1, 0)
	barFill.BackgroundColor3 = cfg.trimColor
	barFill.BorderSizePixel = 0
	barFill.Parent = barBackground
	local barFillCorner = Instance.new("UICorner")
	barFillCorner.CornerRadius = UDim.new(1, 0)
	barFillCorner.Parent = barFill

	local highlight = Instance.new("Highlight")
	highlight.Name = "AimHighlight"
	highlight.Enabled = false
	highlight.FillTransparency = 1
	highlight.OutlineColor = Color3.fromRGB(255, 230, 90)
	highlight.OutlineTransparency = 0
	highlight.Parent = model

	model.PrimaryPart = root
	return model
end

-- 등장 연출(15-1, 지시 [2] "그냥 나타나면 보스로 안 읽힌다"). 기본 파트만으로 만든다 -
-- 바닥에서 퍼지는 경고 링 + 보스 본체 페이드인. 잡몹 스폰에는 안 쓴다(부르는 쪽에서
-- data.isBoss일 때만 호출).
local function playBossAppearEffect(model, position)
	local ring = Instance.new("Part")
	ring.Name = "BossAppearRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(200, 30, 30)
	ring.Anchored = true
	ring.CanCollide = false
	ring.Transparency = 0.2
	ring.Size = Vector3.new(0.2, 1, 1)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = Workspace

	TweenService:Create(ring, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {
		Size = Vector3.new(0.2, 40, 40),
		Transparency = 1,
	}):Play()
	task.delay(0.6, function()
		ring:Destroy()
	end)

	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			local targetTransparency = part.Transparency
			part.Transparency = 1
			TweenService:Create(part, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
				Transparency = targetTransparency,
			}):Play()
		end
	end
end

-- HP 비율로 머리 위 HP바 너비를 갱신한다(16-7 - 숫자 대신 바 하나로 충분하다는 지시,
-- 19-4 - 잡몹은 공유 HP라 절대 숫자 자체가 "누구 기준인가"를 못 정하므로 비율만 쓴다,
-- MonsterState.getHpRatio 참고).
function MonsterSpawner.updateHpLabel(model)
	local head = model:FindFirstChild("Head")
	local nameplateGui = head and head:FindFirstChild("NameplateGui")
	local barFill = nameplateGui and nameplateGui:FindFirstChild("HpBarBackground") and nameplateGui.HpBarBackground:FindFirstChild("HpBarFill")
	if not barFill then
		return
	end

	barFill.Size = UDim2.new(MonsterState.getHpRatio(model), 0, 1, 0)
end

-- zoneKey(16-6, 선택값) - 그 몬스터가 속한 tier 구역 이름. jab몹(격자 스폰)만 갖고,
-- 보스(isBoss, 플레이어별 개인 인스턴스)는 nil로 둔다 - 어차피 despawn에서 리스폰
-- 자체를 안 하므로 zoneKey를 몰라도 상관없다. MonsterAI.server.lua가 이 값으로
-- "이 몬스터의 구역에 지금 플레이어가 있는가"(성능 절전)와 "구역 경계를 벗어났는가"
-- (리쉬 상한)를 둘 다 판정한다.
-- forcedVariant(22-2, 선택값) - DevTools "/gg variant"가 검증용으로 변종을 강제할 때만 넘긴다.
function MonsterSpawner.spawn(data, position, zoneKey, forcedVariant)
	-- 변종 판정(19-4 [6] 반짝이, 22-2 접두사·보물상자 - PRD 8.0-5 "스폰 시점에 판정. 일반
	-- 몬스터를 대체한다") - 보스는 대상이 아니다(플레이어 1인 전용 인스턴스라 "발견의 재미"
	-- 자체가 성립하지 않는다).
	local variant = data.isBoss and {} or (forcedVariant or rollVariant())
	position = snapToGround(position)

	if variant.isChest then
		return MonsterSpawner.spawnChest(data, position, zoneKey)
	end

	local model = buildModel(data, position, variant)
	model.Parent = Workspace
	MonsterState.init(model, data, position, zoneKey, variant)
	MonsterSpawner.updateHpLabel(model)
	if data.isBoss then
		playBossAppearEffect(model, position)
	end
	return model
end

-- 보물상자 스폰(22-2 [3]) - 잡몹 슬롯 하나를 상자가 대체한다. data는 "이 슬롯의 원래 잡몹"
-- 으로, 상자용 data 테이블(isChest + baseData)로 감싼다 - 파괴·소멸 뒤 despawn이 baseData로
-- 원래 잡몹을 리스폰시킨다. 보상(CombatResolution)도 baseData의 tier 골드를 기준으로 준다.
function MonsterSpawner.spawnChest(baseData, position, zoneKey)
	local chestData = {
		id = "treasure_chest",
		displayName = "보물상자",
		isChest = true,
		baseData = baseData,
		tierIndex = baseData.tierIndex,
		-- MonsterAI가 이 몬스터를 건너뛰므로 이동·공격 값은 안 읽히지만, getAttackFor 같은
		-- 공용 조회가 nil 산술을 만나지 않도록 0으로 채운다.
		hp = 0,
		attack = 0,
		goldDrop = 0,
		expReward = 0,
		moveSpeedStuds = 0,
		attackRangeStuds = 0,
		attackCooldownSeconds = 1,
	}

	local model = buildChestModel(position)
	model.Parent = Workspace
	MonsterState.init(model, chestData, position, zoneKey, { isChest = true })
	MonsterSpawner.updateHpLabel(model)

	local zoneLabel = ("tier %d %s 구역"):format(baseData.tierIndex or 0, baseData.displayName or "")
	print(("[forge-game] 보물상자 등장: %s (%.0f, %.0f)"):format(zoneLabel, position.X, position.Z))
	treasureChestNotice:FireAllClients(("보물상자가 %s에 나타났습니다! 함께 부수면 모두가 보상을 받습니다"):format(zoneLabel))

	-- 소멸 타이머 - 파괴(CombatResolution)와 같은 경합 가드(tryClaimDeath)를 쓴다. 둘 중
	-- 먼저 claim한 쪽만 진행하므로 "파괴 직후 소멸 처리"나 그 반대가 겹치지 않는다.
	task.delay(TreasureChestConfig.lifetimeSeconds, function()
		if MonsterState.getData(model) ~= chestData then
			return -- 이미 파괴돼 정리됐다
		end
		if not MonsterState.tryClaimDeath(model) then
			return
		end
		print("[forge-game] 보물상자 소멸(시간 초과): " .. zoneLabel)
		treasureChestNotice:FireAllClients(("%s의 보물상자가 사라졌습니다"):format(zoneLabel))
		MonsterSpawner.despawn(model)
	end)
	return model
end

-- 구출 대상(29-3, PRD 20.73 [2-8] A-4 "빙결 - 때려서 깬다"). 잡힌 친구를 감싼 얼음 덩어리 하나를 타격 대상으로
-- 세운다 - 평타·스킬·투사체의 조준·피격 경로를 그대로 쓰기 위해서다(상자와 같은 이유). 모델은 buildModel 그대로
-- (몸통 + 머리 + HP바 + "Monster" 태그)라 새 에셋이 없다. 잡힌 동안(≤ 9초)만 있고 풀리면 바로 치운다.
-- def = { displayName, color, bodyAspect, footPosition(바닥 좌표), onHit(player, hitInfo), remaining() → 1~0 }
-- 29-5 분신(수정 여왕의 프리즘 분열): def.lookLike = 보스의 인스턴스 데이터 + def.position(보스 루트와 같은 높이)를 주면 그
-- 보스와 **겉모습이 완전히 같은** 타격 대상이 된다(체격·색·실루엣·부착물·이름·HP바 - buildModel이 같은 필드를 읽는다).
-- 몬스터가 아닌 것은 얼음과 같다: HP·AI·보상·기여도·어그로가 없고 맞을 때마다 onHit만 부른다.
function MonsterSpawner.spawnRescueTarget(def, zoneKey)
	local look = def.lookLike
	local data = {
		id = "rescue_target", displayName = look and look.displayName or def.displayName, isRescueTarget = true, isDecoy = look ~= nil,
		bodyColor = look and look.bodyColor or def.color, headColor = look and look.headColor or def.color,
		bodyAspect = look and look.bodyAspect or def.bodyAspect,
		sizeScale = look and look.sizeScale or nil, attachments = look and look.attachments or nil,
		-- MonsterAI가 건너뛰므로 안 읽히지만 공용 조회가 nil 산술을 만나지 않게 0으로 채운다(상자와 같다).
		hp = 0, attack = 0, goldDrop = 0, expReward = 0, moveSpeedStuds = 0, attackRangeStuds = 0, attackCooldownSeconds = 1,
	}
	local position = def.position or (def.footPosition + Vector3.new(0, 1.5, 0)) -- buildModel은 몸통 밑면을 position.Y − 1.5에 둔다
	local model = buildModel(data, position, {})
	CollectionService:AddTag(model, "RescueTarget") -- 클라가 "보스"를 찾을 때 이 모델을 건너뛴다(BossPatternVisuals)
	if not look then
		model.Body.Material = Enum.Material.Ice
		model.Body.Transparency = 0.45
		model.Head.Transparency = 1
	end
	model.Parent = Workspace
	MonsterState.init(model, data, position, zoneKey, { isRescueTarget = true, onRescueHit = def.onHit, rescueRemaining = def.remaining })
	MonsterSpawner.updateHpLabel(model)
	return model
end

function MonsterSpawner.removeRescueTarget(model)
	MonsterState.clear(model)
	model:Destroy()
end

-- 사망 처리. 정해진 스폰 자리에 그대로 리스폰한다 - 무작위 위치로 보내면 균등 배치가
-- 흐트러지고 자리끼리 겹칠 수 있어서, 자리를 고정하는 편이 더 낫다고 판단했다.
--
-- 보스(isBoss)는 고정 스폰 격자(WorldConfig.zoneMonsterGrid)에 속하지 않는 플레이어 전용
-- 인스턴스라 리스폰시키지 않는다 - 다시 나타나는 시점은 BossEncounter.spawnFor가 "그
-- 스테이지에 다시 들어왔을 때"로 직접 관리한다.
function MonsterSpawner.despawn(model)
	local data = MonsterState.getData(model)
	local spawnPosition = MonsterState.getSpawnPosition(model)
	local zoneKey = MonsterState.getZoneKey(model)

	print(("[forge-game] 몬스터 사망: %s"):format(model.Name))
	MonsterState.clear(model) -- 죽는 즉시 타겟 후보에서 제외(findNearestMonsterInRange가 더 이상 고르지 않는다) - 상자면 피격 기록도 여기서 같이 사라진다(22-2 [3])

	-- 마지막 데미지 숫자가 화면에서 사라질 시간만큼은 시체를 남겨둔다.
	task.delay(CombatConfig.damageNumberLifetimeSeconds, function()
		model:Destroy()
	end)

	if not data.isBoss then
		-- 보물상자였던 슬롯은 원래 잡몹(baseData)으로 돌아간다(22-2 [3]) - 리스폰 때 변종을
		-- 다시 굴리므로 드물게 상자가 연달아 나올 수도 있다(확률대로).
		local respawnData = data.isChest and data.baseData or data
		task.delay(WorldConfig.zoneMonsterGrid.respawnDelaySeconds, function()
			MonsterSpawner.spawn(respawnData, spawnPosition, zoneKey)
		end)
	end
end

return MonsterSpawner
