-- 원거리 투사체(화살·마법 구슬, 14-2 재작업). "활은 시위가 안 당겨지고 화살이 날아가지도
-- 않는다"는 지적에 대응한다 - 판정은 서버가 이미 끝낸 뒤(AttackServer.server.lua가
-- 즉시 계산) 이 모듈은 그 결과를 "보이게"만 한다. 서버 권위를 깨지 않는다(지시 사항) -
-- 클라이언트는 데미지·치명타·사망 여부를 전혀 새로 판정하지 않고, 이미 정해진 결과를
-- 언제 화면에 표시할지(투사체가 도착하는 순간)만 늦춘다.
--
-- HitEffects.lua와 같은 풀링 원칙 - 종류(화살/구슬)별로 고정 6개씩 재사용한다(둘 다
-- 합쳐 12개, HitEffects와 같은 "9마리 동시" 근거를 그대로 쓴다 - 근거는 그쪽 주석 참고).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ProjectileConfig = require(ReplicatedStorage.Shared.data.ProjectileConfig)

local Projectiles = {}

local POOL_SIZE_PER_KIND = 6

-- 20-2b: 비행 속도가 서버(AttackServer.server.lua)의 도달 시점 계산과 반드시 같아야 해서
-- ProjectileConfig.lua(단일 출처)로 옮겼다 - 여기 하드코딩하지 않는다.

-- 20-5 [1]: 평타 화살도 Neon으로 바꿔 조용히 발광하게 했다(지시 - "평타는 작고
-- 조용하되 보이기는 해야 한다") - 크기·트레일 두께는 그대로 두고 재질만 바꿨다.
local ARROW_COLOR = Color3.fromRGB(200, 180, 140)
local ARROW_CRIT_COLOR = Color3.fromRGB(255, 130, 60)
local ORB_COLOR = Color3.fromRGB(210, 190, 255)
local ORB_CRIT_COLOR = Color3.fromRGB(255, 130, 220)

-- 백스텝샷(활 E) 적용 화살 전용 - "평타보다 확실히 굵고 밝아야 한다. 스킬이다가
-- 한눈에 읽혀야 한다"(지시). 크기·빛 둘 다 눈에 띄게 키운다.
local ARROW_EMPOWERED_COLOR = Color3.fromRGB(140, 230, 255)
local ARROW_EMPOWERED_CRIT_COLOR = Color3.fromRGB(255, 200, 60)
local ARROW_EMPOWERED_SCALE = 2.4

local function buildArrow()
	local part = Instance.new("Part")
	part.Name = "ArrowProjectile"
	part.Size = Vector3.new(0.06, 0.06, 1.5)
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Transparency = 1
	part.Parent = Workspace

	local topAttach = Instance.new("Attachment")
	topAttach.Position = Vector3.new(0, 0, 0.75)
	topAttach.Parent = part
	local bottomAttach = Instance.new("Attachment")
	bottomAttach.Position = Vector3.new(0, 0, -0.75)
	bottomAttach.Parent = part

	local trail = Instance.new("Trail")
	trail.Attachment0 = topAttach
	trail.Attachment1 = bottomAttach
	trail.Lifetime = 0.15
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	trail.Enabled = false
	trail.Parent = part

	-- 백스텝샷 화살에서만 켜는 빛(기본은 꺼둔다 - 평타 화살까지 전부 PointLight를
	-- 켜면 "조용해야 한다"는 지시와 맞지 않는다, 몬스터 다수가 동시에 맞을 때 빛
	-- 12개가 겹치는 것도 피한다).
	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 10
	light.Enabled = false
	light.Parent = part

	return { part = part, trail = trail, light = light, baseSize = part.Size }
end

local function buildOrb()
	local part = Instance.new("Part")
	part.Name = "OrbProjectile"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(0.5, 0.5, 0.5)
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Transparency = 1
	part.Parent = Workspace

	local light = Instance.new("PointLight")
	light.Brightness = 1.5
	light.Range = 6
	light.Parent = part

	local topAttach = Instance.new("Attachment")
	topAttach.Position = Vector3.new(0, 0, 0.3)
	topAttach.Parent = part
	local bottomAttach = Instance.new("Attachment")
	bottomAttach.Position = Vector3.new(0, 0, -0.3)
	bottomAttach.Parent = part

	local trail = Instance.new("Trail")
	trail.Attachment0 = topAttach
	trail.Attachment1 = bottomAttach
	trail.Lifetime = 0.2
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.2) })
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	trail.Enabled = false
	trail.Parent = part

	return { part = part, trail = trail, light = light }
end

local pools = {
	arrow = {},
	orb = {},
}
local poolIndex = { arrow = 0, orb = 0 }

for i = 1, POOL_SIZE_PER_KIND do
	pools.arrow[i] = buildArrow()
	pools.orb[i] = buildOrb()
end

local function nextSlot(kind)
	local list = pools[kind]
	poolIndex[kind] = (poolIndex[kind] % #list) + 1
	return list[poolIndex[kind]]
end

-- 발사 순간 섬광(20-5 [1] - "발사 순간과 적중 순간을 시각적으로 구분해라. 지금은 둘 다
-- 아무것도 없어서 쐈는지도 모르고 맞았는지도 모르는 상태다"). 적중 쪽은 이미
-- HitEffects.playHit의 버스트가 있다(AttackInput.client.lua showResult) - 여기선 그
-- 반대편(발사)에 짧은 섬광 하나를 더해 쌍을 맞춘다. HitEffects.lua와 같은 풀링 원칙,
-- 다만 발사 이펙트는 몬스터당이 아니라 화살 개수만큼이라 풀을 따로 작게 둔다.
local FLASH_POOL_SIZE = 6
local flashPool = {}
for i = 1, FLASH_POOL_SIZE do
	local part = Instance.new("Part")
	part.Name = "ProjectileMuzzleFlash"
	part.Shape = Enum.PartType.Ball
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CastShadow = false
	part.Transparency = 1
	part.Parent = Workspace
	flashPool[i] = part
end
local flashPoolIndex = 0

local FLASH_NORMAL_SIZE = 0.5
local FLASH_EMPOWERED_SIZE = 1.3
local FLASH_DURATION = 0.12

local function muzzleFlash(position, color, isEmpowered)
	flashPoolIndex = (flashPoolIndex % FLASH_POOL_SIZE) + 1
	local part = flashPool[flashPoolIndex]
	local maxSize = isEmpowered and FLASH_EMPOWERED_SIZE or FLASH_NORMAL_SIZE

	part.Color = color
	part.Size = Vector3.new(0.15, 0.15, 0.15)
	part.Position = position
	part.Transparency = 0.1

	TweenService:Create(part, TweenInfo.new(FLASH_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(maxSize, maxSize, maxSize),
		Transparency = 1,
	}):Play()
end

-- kind: "arrow" | "orb". fromPosition/toPosition: Vector3(월드 좌표). isCrit이면 색이
-- 바뀐다(지시 사항 - "치명타일 때 더 강하게" 판단, 투사체는 발사 시점에 이미 서버가
-- 치명타 여부를 알려준 뒤라 크리티얼 색을 곧바로 입힐 수 있다 - 근접 스윙은 발사
-- 시점에 아직 서버 응답 전이라 이렇게 못 한다, HitEffects.lua와 AttackInput.client.lua
-- 주석 참고). variant(20-5 [1], 선택값): "empowered"면 백스텝샷이 적용된 평타 화살 -
-- 굵고 밝게, 빛까지 켜서 "스킬이다"가 한눈에 읽히게 한다(nil/"normal"이면 기존 평타
-- 화살 그대로, orb에는 영향 없다 - 힐러 스킬은 아직 없다). onArrive는 도착한 프레임에
-- 정확히 한 번 불린다 - 데미지 숫자·피격/사망 이펙트를 이 시점에 맞춰 재생하면
-- "판정 시점과 도달 시점이 어긋나는" 문제가 없다.
function Projectiles.fire(kind, fromPosition, toPosition, isCrit, variant, onArrive)
	local slot = nextSlot(kind)
	local part, trail = slot.part, slot.trail
	local isEmpowered = kind == "arrow" and variant == "empowered"

	local distance = (toPosition - fromPosition).Magnitude
	local speed = ProjectileConfig.speedStudsPerSec[kind]
	local travelTime = math.max(distance / speed, 0.03)

	if isEmpowered then
		part.Color = isCrit and ARROW_EMPOWERED_CRIT_COLOR or ARROW_EMPOWERED_COLOR
		part.Size = slot.baseSize * ARROW_EMPOWERED_SCALE
		trail.Lifetime = 0.28
	else
		part.Color = isCrit and (kind == "arrow" and ARROW_CRIT_COLOR or ORB_CRIT_COLOR) or (kind == "arrow" and ARROW_COLOR or ORB_COLOR)
		if slot.baseSize then
			part.Size = slot.baseSize
		end
		trail.Lifetime = kind == "arrow" and 0.15 or 0.2
	end
	if slot.light then
		slot.light.Color = part.Color
		if kind == "arrow" then
			slot.light.Enabled = isEmpowered -- 평타 화살은 빛을 켜지 않는다("작고 조용하되").
		end
	end
	muzzleFlash(fromPosition, part.Color, isEmpowered)

	part.CFrame = CFrame.lookAt(fromPosition, toPosition)
	part.Transparency = 0
	trail.Enabled = true

	local tween = TweenService:Create(part, TweenInfo.new(travelTime, Enum.EasingStyle.Linear), {
		CFrame = CFrame.lookAt(toPosition, toPosition + (toPosition - fromPosition)),
	})
	tween:Play()

	task.delay(travelTime, function()
		part.Transparency = 1
		trail.Enabled = false
		if kind == "arrow" and slot.light then
			slot.light.Enabled = false -- orb(힐러)의 항상 켜진 빛은 건드리지 않는다.
		end
		if onArrive then
			onArrive()
		end
	end)

	return travelTime
end

return Projectiles
