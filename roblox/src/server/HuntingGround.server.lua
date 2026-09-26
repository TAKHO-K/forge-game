-- 사냥터 = M1 큰 세계(허브 "큰 나무 마을" + 꽃잎 구역 6개 · 반지름 약 3,000 - 옛 3×3 구역 맵(16-6)을 대체). 도형 = WorldMapLayout(수치 WorldMapData) →
-- server/WorldMap이 짓는다. 여기서는 부팅 순서만: 맵 → 리스폰 → 허브 NPC(환생 제단 · 보석상인 - 강화대는 EnhanceStation) → 몬스터 지대(SpawnSites) → 세계 이동(Travel).
-- 옛 구역 지형(ZoneTerrain) · 맵 밑판 · 능선 · 포탈 패드(TeleportPad)는 더 이상 짓지 않는다(모듈은 남아 있다 - 검증 · 개발 명령 일부가 읽는다).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local MonsterPrefixData = require(ReplicatedStorage.Shared.data.MonsterPrefixData)
local WorldMap = require(script.Parent.WorldMap)
local SpawnSites = require(script.Parent.SpawnSites)
local Travel = require(script.Parent.Travel)

local FLOOR_THICKNESS = WorldMapData.floorThickness
local FLOOR_Y = WorldMapData.floorTopY - FLOOR_THICKNESS / 2 -- 바닥 중심 Y(윗면 = floorTopY = 1 - 옛 관례 그대로)

local function removeDefaultSpawns(ourSpawnName)
	for _, obj in ipairs(Workspace:GetChildren()) do
		if obj:IsA("SpawnLocation") and obj.Name ~= ourSpawnName then
			obj:Destroy()
		end
	end
end

-- 22-4: 플레이스 기본 Baseplate(2048×16, 윗면 y=0)를 지운다. 20.49 실측에서 잔존이 확인됐고,
-- 남겨 두면 구역 바닥 사이 틈·심연이 전부 "1stud 아래 바닥"이 되어 심연 복귀(TerrainServer)와
-- 몬스터의 "지면 없음" 판정이 절대 발동하지 않는다. removeDefaultSpawns와 같은 성격의 정리.
local function removeDefaultBaseplate()
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate:Destroy()
	end
end

-- 리스폰 = 허브(나무 아래 안전 지대 - 몬스터 없음)의 리스폰 자리(WorldConfig.zones.spawn.arrival - 중심은 나무 줄기).
local function createPlayerSpawn(position)
	local spawnPart = Instance.new("SpawnLocation")
	spawnPart.Name = "HuntingGroundSpawn"
	spawnPart.Size = Vector3.new(6, 1, 6)
	spawnPart.Anchored = true
	spawnPart.Neutral = true
	spawnPart.Transparency = 0.5
	spawnPart.Position = Vector3.new(position.X, FLOOR_Y + FLOOR_THICKNESS / 2 + 0.5, position.Z)
	spawnPart.Parent = Workspace
	return spawnPart
end

-- 환생 제단(S12b F) - 커뮤니티 센터 블록의 리스폰 쪽 면 앞에 놓는 환생 전용 상호작용 물체. 모델은 임시(F5에서 교체) - 강화대와 같은 도형 두 개 + ProximityPrompt.
-- 위치 = WorldConfig.rebirthAltar(RebirthAccess.altarPosition이 서버 판정에 같은 식으로 쓴다). 프롬프트는 클라(RebirthAltar.client.lua)가 받아 확인창을 연다 -
-- 실제 환생 여부는 서버(RebirthAccess)가 요청 시점의 위치로 다시 잰다.
local function createRebirthAltar(communityZone)
	local altar = WorldConfig.rebirthAltar
	local position = WorldConfig.huntingGround.center + communityZone.center + altar.offsetFromCommunity
	local floorTop = FLOOR_Y + FLOOR_THICKNESS / 2

	local model = Instance.new("Model")
	model.Name = "RebirthAltar"

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(5, 2, 5)
	base.Anchored = true
	base.CanCollide = true
	base.Color = Color3.fromRGB(90, 90, 100)
	base.Position = Vector3.new(position.X, floorTop + 1, position.Z)
	base.Parent = model

	local orb = Instance.new("Part")
	orb.Name = "Orb"
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.new(2.6, 2.6, 2.6)
	orb.Anchored = true
	orb.CanCollide = false
	orb.Color = Color3.fromRGB(160, 130, 60)
	orb.Material = Enum.Material.Neon
	orb.Position = Vector3.new(position.X, floorTop + 3.6, position.Z)
	orb.Parent = model

	local label = Instance.new("BillboardGui")
	label.Name = "NameplateGui"
	label.Size = UDim2.new(4, 0, 1, 0)
	label.StudsOffset = Vector3.new(0, 2.2, 0)
	label.AlwaysOnTop = true
	label.Adornee = orb
	label.Parent = orb

	local labelText = Instance.new("TextLabel")
	labelText.BackgroundTransparency = 1
	labelText.Size = UDim2.new(1, 0, 1, 0)
	labelText.Text = altar.objectText
	labelText.TextColor3 = Color3.new(1, 1, 1)
	labelText.TextScaled = true
	labelText.Parent = label

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RebirthAltarPrompt"
	prompt.ObjectText = altar.objectText
	prompt.ActionText = altar.actionText
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = altar.promptDistanceStuds
	prompt.Parent = orb

	model.PrimaryPart = base
	model.Parent = Workspace
	return model
end

-- 보석상인(S20e) - 환생 제단 옆(WorldConfig.gemMerchant.offsetFromCommunity)의 임시 NPC. 모델은 임시(F5에서 교체) - 좌판 · 몸통 · 머리 · 보석 모양 파트 + ProximityPrompt.
-- 위치 = GemMerchantAccess.position이 서버 판정(변환 · 리롤 요청)에 같은 식으로 쓴다. 프롬프트는 클라(GemMerchant.client.lua)가 받아 "보석 공방" 창을 연다 -
-- 변환 · 리롤을 해도 되는지는 서버(GemWorkshop → GemMerchantAccess)가 요청 시점의 위치로 다시 잰다. 클라의 [위치 안내] 마커도 이 모델(이름 GemMerchant) 위에 붙는다.
local function createGemMerchant(communityZone)
	local merchant = WorldConfig.gemMerchant
	local position = WorldConfig.huntingGround.center + communityZone.center + merchant.offsetFromCommunity
	local floorTop = FLOOR_Y + FLOOR_THICKNESS / 2

	local model = Instance.new("Model")
	model.Name = "GemMerchant"

	local stall = Instance.new("Part")
	stall.Name = "Stall"
	stall.Size = Vector3.new(6, 2, 3)
	stall.Anchored = true
	stall.CanCollide = true
	stall.Color = Color3.fromRGB(90, 70, 60)
	stall.Position = Vector3.new(position.X, floorTop + 1, position.Z)
	stall.Parent = model

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(2, 2.6, 1.2)
	body.Anchored = true
	body.CanCollide = false
	body.Color = Color3.fromRGB(70, 60, 110)
	body.Position = Vector3.new(position.X, floorTop + 3.3, position.Z + 2)
	body.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.6, 1.6, 1.6)
	head.Anchored = true
	head.CanCollide = false
	head.Color = Color3.fromRGB(230, 200, 170)
	head.Position = Vector3.new(position.X, floorTop + 5.4, position.Z + 2)
	head.Parent = model

	local gem = Instance.new("Part")
	gem.Name = "Gem"
	gem.Size = Vector3.new(1.2, 1.2, 1.2)
	gem.Anchored = true
	gem.CanCollide = false
	gem.Color = Color3.fromRGB(80, 200, 190)
	gem.Material = Enum.Material.Neon
	gem.CFrame = CFrame.new(position.X, floorTop + 2.9, position.Z - 0.4) * CFrame.Angles(math.rad(45), math.rad(45), 0)
	gem.Parent = model

	local label = Instance.new("BillboardGui")
	label.Name = "NameplateGui"
	label.Size = UDim2.new(4, 0, 1, 0)
	label.StudsOffset = Vector3.new(0, 2.2, 0)
	label.AlwaysOnTop = true
	label.Adornee = head
	label.Parent = head

	local labelText = Instance.new("TextLabel")
	labelText.BackgroundTransparency = 1
	labelText.Size = UDim2.new(1, 0, 1, 0)
	labelText.Text = merchant.objectText
	labelText.TextColor3 = Color3.new(1, 1, 1)
	labelText.TextScaled = true
	labelText.Parent = label

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GemMerchantPrompt"
	prompt.ObjectText = merchant.objectText
	prompt.ActionText = merchant.actionText
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = merchant.promptDistanceStuds
	prompt.Parent = stall -- 서버 반경의 기준점(= position)과 같은 자리 - 프롬프트가 뜬 곳에서 누른 요청은 항상 반경 안이다

	model.PrimaryPart = stall
	model.Parent = Workspace
	return model
end

-- ═══ 실행 ═══

local meta, counts = WorldMap.build()
-- M1-3: 굽힌 지형 표식(버전 · 표본 서명)이 데이터와 같은가 - 다르면 경고만(런타임 생성 금지 · 다시 굽기 = Studio edit)
task.spawn(function()
	require(script.Parent.TerrainBake).checkVersion()
	local on, slots = require(script.Parent.TerrainBake).applyVariants() -- M1-4 MaterialVariant 자리(있으면 끼움)
	print(("[forge-game] 지형 재질 변형 자리 %d · 켠 것 %d%s"):format(slots, #on, #on > 0 and (" (" .. table.concat(on, ", ") .. ")") or ""))
end)
require(script.Parent.NestServer).start() -- M1-3 둥지 3트랙(프롬프트 · 순환 · 번개 문 · 동기화)
do
	local names = {}
	for name, c in pairs(counts) do
		table.insert(names, ("%s %d(장식 %d)"):format(name, c.parts, c.decor))
	end
	table.sort(names)
	print("[forge-game] M1 맵 모델별 파트: " .. table.concat(names, " · "))
	for _, z in ipairs(WorldMapData.zones) do
		local m = meta.zones[z.key]
		print(("[forge-game] 구역 %s(%s · 보스 %s): 탐험 %d · 이스터에그 자리 %d · 둥지 %d · 허브 끝→캠프 %.0f · 캠프→관문 %.0f"):format(z.key, z.theme, z.bossId,
			#m.explore, #m.eggs, #m.nests, WorldMapLayout.routeLength(z, "hubEdge", "camp"), WorldMapLayout.routeLength(z, "camp", "gate")))
	end
end

-- M1: 대기 밀도(WorldMapData.atmosphere - place 기본 0.3은 멀리 있는 나무 · 빛기둥을 지운다)
do
	local atmosphere = game:GetService("Lighting"):FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Density = WorldMapData.atmosphere.density
		atmosphere.Offset = WorldMapData.atmosphere.offset
	end
end

removeDefaultSpawns("HuntingGroundSpawn")
removeDefaultBaseplate()
createPlayerSpawn(WorldConfig.zones.spawn.arrival)
createRebirthAltar(WorldConfig.zones.community)
createGemMerchant(WorldConfig.zones.community)

SpawnSites.start()
local downPads = {}
local course = WorldMap.model("TreeCourse")
for _, part in ipairs(course and course:GetChildren() or {}) do
	if part:GetAttribute("StationDown") then
		table.insert(downPads, part)
	end
end
Travel.start(downPads)

print(("[forge-game] 사냥터 생성 완료 - 허브 + 구역 %d · 몬스터는 지대 활성화로(사람이 가까이 오면)"):format(#WorldMapData.zones))

-- 공정성 항등식 실측 로그(16-6 지시 - "6개 tier 전부 수치로 확인하고 결과를 보여줘라").
for _, check in ipairs(MonsterData.fairnessCheck) do
	print(("[forge-game] tier%d 공정성 검증 - r=%.4f, 시간당보상=%.4f"):format(
		check.tier, check.r, check.rewardPerTime))
end
-- 접두사 변종 공평성(22-2 [1]) - 보상배율/HP배율이 접두사 무관하게 1인지 실행 시점에 확인.
for _, check in ipairs(MonsterPrefixData.fairnessCheck) do
	print(("[forge-game] 접두사 %s(%s) 공평성 검증 - HP×%.2f, 보상×%.2f, 시간당보상=%.4f"):format(
		check.displayName, check.id, check.hpMultiplier, check.rewardMultiplier, check.rewardPerTime))
end
