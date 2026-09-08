-- 드랍 아이템 인스턴스 생성·연출·제거(14-1). MonsterSpawner와 같은 역할 분리 - 시각(이
-- 모듈)과 판정(ItemDropState)을 나눈다. 실제 픽업 판정(거리 확인·인벤토리 반영)은
-- ItemDropServer.server.lua가 한다 - 이 모듈은 "어떻게 생겼고 어떻게 나타났다 사라지는가"만
-- 안다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local ItemDropState = require(script.Parent.ItemDropState)

local ItemDropSpawner = {}

-- 여러 개가 한 자리에 겹치지 않게 살짝 흩뿌린다(웹 PRD 7.1 "2개가 나오면 바닥에 약간
-- 떨어뜨려 배치 - 겹쳐서 하나로 보이지 않게"와 같은 이유, 다중 드랍이 아직 없어도 몬스터가
-- 여럿 거의 동시에 죽는 상황엔 그대로 적용된다).
local SCATTER_RADIUS_STUDS = 1.5
local FLOAT_HEIGHT_STUDS = 1.2 -- 바닥에서 살짝 띄워 착지 사이즈감을 준다
local BOUNCE_HEIGHT_STUDS = 3
local BOUNCE_UP_SECONDS = 0.18
local BOUNCE_DOWN_SECONDS = 0.27
ItemDropSpawner.bounceSeconds = BOUNCE_UP_SECONDS + BOUNCE_DOWN_SECONDS -- WorldConfig.items.pickupDelaySeconds가 이 값 이상이어야 연출을 다 본다

local function buildModel(item)
	local part = item.part or "armor" -- 지금은 항상 armor - 필드 자체가 아직 없어도 안전하게 기본값
	local visual = ItemVisualData.gradeVisuals[item.grade]
	local size = ItemVisualData.partShapes[part] or ItemVisualData.partShapes.armor

	local model = Instance.new("Model")
	model.Name = "ItemDrop"

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Shape = Enum.PartType.Block
	root.Size = size
	root.Anchored = true
	root.CanCollide = false
	root.Material = Enum.Material.Neon
	root.Color = visual.color
	root.Parent = model

	local light = Instance.new("PointLight")
	light.Brightness = visual.glowBrightness
	light.Range = visual.glowRange
	light.Color = visual.color
	light.Parent = root

	-- 이름표(등급 + 레벨) - 가까이 가야만 보인다(지시 사항: "가까이 갔을 때 이름표에 함께
	-- 뜨는 정도로 충분할 수도 있다" - 등급은 이미 색으로 표현되므로 여기선 등급명+레벨을
	-- 같이 적어 레벨 축을 이름표 하나로 해결한다).
	local nameplateGui = Instance.new("BillboardGui")
	nameplateGui.Name = "NameplateGui"
	nameplateGui.Size = UDim2.new(4, 0, 1, 0)
	nameplateGui.StudsOffset = Vector3.new(0, 1.3, 0)
	nameplateGui.MaxDistance = 15
	nameplateGui.AlwaysOnTop = true
	nameplateGui.Adornee = root
	nameplateGui.Parent = root

	local grade = ArmorData.grades[item.grade]
	local partName = ItemVisualData.partDisplayNames[part] or part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = visual.color
	label.TextStrokeTransparency = 0.4
	label.Text = ("%s %s (Lv.%d)"):format(grade and grade.displayName or item.grade, partName, item.itemLevel)
	label.Parent = nameplateGui

	model.PrimaryPart = root
	return model
end

-- 등급이 높을수록 눈에 띄는 드랍 순간 연출(지시 사항 - "낮은 등급은 조용해야 한다").
-- 확장하는 링 하나가 빠르게 커지며 사라진다 - 몬스터와 같은 "도형으로 표현" 방식.
local function spawnBurst(position, color)
	local ring = Instance.new("Part")
	ring.Name = "ItemDropBurst"
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Anchored = true
	ring.CanCollide = false
	ring.Size = Vector3.new(0.2, 0.6, 0.6)
	ring.Orientation = Vector3.new(0, 0, 90) -- 실린더를 눕혀 링처럼 보이게
	ring.CFrame = CFrame.new(position)
	ring.Transparency = 0.15
	ring.Parent = Workspace

	local tween = TweenService:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.2, 5, 5),
		Transparency = 1,
	})
	tween:Play()
	tween.Completed:Connect(function()
		ring:Destroy()
	end)
end

-- 몬스터 사망 위치 근처에 드랍을 스폰한다. 위로 솟았다 떨어지는 연출 뒤 정지한다(지시
-- 사항 - "즉시 나타나면 눈에 안 띈다"). owner는 이 아이템을 주울 수 있는 유일한
-- 플레이어(Player 인스턴스) - 다른 플레이어는 줍기 판정 대상에서 아예 제외된다(14-1
-- "다른 플레이어가 내 드랍을 주울 수 있는가" - 기본 비허용, ItemDropServer 참고).
function ItemDropSpawner.spawn(item, deathPosition, owner)
	local model = buildModel(item)

	local offsetX = (math.random() * 2 - 1) * SCATTER_RADIUS_STUDS
	local offsetZ = (math.random() * 2 - 1) * SCATTER_RADIUS_STUDS
	local groundPosition = deathPosition + Vector3.new(offsetX, 0, offsetZ)
	local restPosition = groundPosition + Vector3.new(0, FLOAT_HEIGHT_STUDS, 0)
	local peakPosition = groundPosition + Vector3.new(0, FLOAT_HEIGHT_STUDS + BOUNCE_HEIGHT_STUDS, 0)

	model.PrimaryPart.CFrame = CFrame.new(groundPosition)
	model.Parent = Workspace

	ItemDropState.init(model, item, owner.UserId)

	local up = TweenService:Create(model.PrimaryPart, TweenInfo.new(BOUNCE_UP_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = CFrame.new(peakPosition),
	})
	up:Play()
	up.Completed:Connect(function()
		if model.Parent then
			TweenService:Create(model.PrimaryPart, TweenInfo.new(BOUNCE_DOWN_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				CFrame = CFrame.new(restPosition),
			}):Play()
		end
	end)

	local visual = ItemVisualData.gradeVisuals[item.grade]
	if visual and visual.burstOnDrop then
		spawnBurst(restPosition, visual.color)
	end

	-- 수명 만료(웹 BALANCE.itemGroundLifetime과 같은 60초, WorldConfig.items 참고) -
	-- 못 주운 채 시간이 지나면 조용히 사라진다.
	task.delay(WorldConfig.items.groundLifetimeSeconds, function()
		if model.Parent then
			ItemDropSpawner.despawn(model)
		end
	end)

	return model
end

function ItemDropSpawner.despawn(model)
	ItemDropState.clear(model)
	model:Destroy()
end

return ItemDropSpawner
