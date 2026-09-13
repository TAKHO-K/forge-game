-- 스킬 전용 이펙트(20-2a [4]) - "새 애니메이션을 만들지 마라, 차별화는 이펙트로 한다"는
-- 지시 그대로 이미지 에셋 없이 Part+TweenService 조합만 쓴다. 대검 Q/E가 첫 사용자지만
-- 판정 유형처럼 나머지 스킬 대부분이 "대시형"이나 "광역형"의 변형일 거라 여기 두 함수를
-- 그대로 재사용할 수 있게 일부러 클래스·스킬 이름을 모른다(범용 기하 인자만 받는다).

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SkillEffects = {}

local function newGhostPart(size, color)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false -- Raycast(SkillServer의 Q 담장 판정 등)에 걸리지 않게 한다.
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = size
	part.Parent = Workspace
	return part
end

-- 관통돌진 잔상(20-2a [4]) - "지나간 경로에 반투명 Part 3~4개가 순차로 사라짐". startPos~
-- endPos 사이를 균등 분할한 지점마다 캐릭터 실루엣 크기의 파트를 놓고, 각각 조금씩 늦게
-- 시작해 사라지게 한다(먼저 지나간 자리일수록 먼저 사라진다).
local AFTERIMAGE_COUNT = 4
local AFTERIMAGE_SIZE = Vector3.new(2.2, 5, 1)
local AFTERIMAGE_FADE_SECONDS = 0.25

function SkillEffects.dashAfterimage(startPos, endPos, color, totalDurationSeconds)
	local delta = endPos - startPos
	for i = 1, AFTERIMAGE_COUNT do
		local t = (i - 1) / math.max(AFTERIMAGE_COUNT - 1, 1)
		local position = startPos + delta * t
		local part = newGhostPart(AFTERIMAGE_SIZE, color)
		part.CFrame = CFrame.new(position, position + delta)
		part.Transparency = 0.35

		local startDelay = totalDurationSeconds * t
		task.delay(startDelay, function()
			TweenService:Create(part, TweenInfo.new(AFTERIMAGE_FADE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = 1,
			}):Play()
			task.delay(AFTERIMAGE_FADE_SECONDS, function()
				part:Destroy()
			end)
		end)
	end
end

-- 대회전 등 원형 스킬의 확산 링(20-2a [4]) - "시전자 중심에서 퍼져나가는 원형 링". 얇은
-- Cylinder를 반경 0에서 목표 반경까지 키우며 옅어지게 한다.
local RING_THICKNESS_STUDS = 0.3

function SkillEffects.expandingRing(center, radiusStuds, color, durationSeconds)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Size = Vector3.new(RING_THICKNESS_STUDS, 0.2, 0.2)
	-- Cylinder는 로컬 X축이 원통의 높이(두께) 방향이다 - 눕혀서 원판이 바닥과 수평이 되게
	-- Z축으로 90도 돌린다.
	ring.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
	ring.Transparency = 0.2
	ring.Parent = Workspace

	TweenService:Create(ring, TweenInfo.new(durationSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(RING_THICKNESS_STUDS, radiusStuds * 2, radiusStuds * 2),
		Transparency = 1,
	}):Play()

	task.delay(durationSeconds, function()
		ring:Destroy()
	end)
end

-- 자기 버프 지속 오라(20-2b [3], 활 속사) - "버프 중 캐릭터 주변에 빠른 느낌의 잔상 또는
-- 링. 과하게 하지 마라 - 6초 동안 계속 보이는 것이라 화려하면 피로하다"는 지시대로
-- 발등 높이 얇은 링 하나만 캐릭터를 따라다니며 은은하게 유지한다(회전만 살짝 돈다 -
-- 그게 "빠른 느낌"의 전부다). durationSeconds가 지나면 스스로 사라진다.
local AURA_RING_THICKNESS_STUDS = 0.15
local AURA_ROTATION_DEG_PER_SEC = 240

function SkillEffects.selfBuffAura(character, radiusStuds, color, durationSeconds)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.6
	ring.Size = Vector3.new(AURA_RING_THICKNESS_STUDS, radiusStuds * 2, radiusStuds * 2)
	ring.Parent = Workspace

	local startTick = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local currentCharacter = rootPart.Parent
		if not currentCharacter or os.clock() - startTick >= durationSeconds then
			connection:Disconnect()
			ring:Destroy()
			return
		end
		local spinAngle = math.rad(AURA_ROTATION_DEG_PER_SEC * (os.clock() - startTick))
		ring.CFrame = CFrame.new(rootPart.Position - Vector3.new(0, 2.8, 0))
			* CFrame.Angles(0, spinAngle, math.rad(90))
	end)
end

return SkillEffects
