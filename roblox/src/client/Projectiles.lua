-- 원거리 투사체(화살·마법 구슬, 14-2 재작업). "활은 시위가 안 당겨지고 화살이 날아가지도
-- 않는다"는 지적에 대응한다 - 판정은 서버가 이미 끝낸 뒤(AttackServer.server.lua가
-- 즉시 계산) 이 모듈은 그 결과를 "보이게"만 한다. 서버 권위를 깨지 않는다(지시 사항) -
-- 클라이언트는 데미지·치명타·사망 여부를 전혀 새로 판정하지 않고, 이미 정해진 결과를
-- 언제 화면에 표시할지(투사체가 도착하는 순간)만 늦춘다.
--
-- HitEffects.lua와 같은 풀링 원칙 - 종류(화살/구슬)별로 고정 6개씩 재사용한다(둘 다
-- 합쳐 12개, HitEffects와 같은 "9마리 동시" 근거를 그대로 쓴다 - 근거는 그쪽 주석 참고).

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Projectiles = {}

local POOL_SIZE_PER_KIND = 6

local ARROW_SPEED_STUDS_PER_SEC = 90
local ORB_SPEED_STUDS_PER_SEC = 55

local ARROW_COLOR = Color3.fromRGB(200, 180, 140)
local ARROW_CRIT_COLOR = Color3.fromRGB(255, 130, 60)
local ORB_COLOR = Color3.fromRGB(210, 190, 255)
local ORB_CRIT_COLOR = Color3.fromRGB(255, 130, 220)

local function buildArrow()
	local part = Instance.new("Part")
	part.Name = "ArrowProjectile"
	part.Size = Vector3.new(0.06, 0.06, 1.5)
	part.Material = Enum.Material.SmoothPlastic
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

	return { part = part, trail = trail }
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

-- kind: "arrow" | "orb". fromPosition/toPosition: Vector3(월드 좌표). isCrit이면 색이
-- 바뀐다(지시 사항 - "치명타일 때 더 강하게" 판단, 투사체는 발사 시점에 이미 서버가
-- 치명타 여부를 알려준 뒤라 크리티얼 색을 곧바로 입힐 수 있다 - 근접 스윙은 발사
-- 시점에 아직 서버 응답 전이라 이렇게 못 한다, HitEffects.lua와 AttackInput.client.lua
-- 주석 참고). onArrive는 도착한 프레임에 정확히 한 번 불린다 - 데미지 숫자·피격/사망
-- 이펙트를 이 시점에 맞춰 재생하면 "판정 시점과 도달 시점이 어긋나는" 문제가 없다.
function Projectiles.fire(kind, fromPosition, toPosition, isCrit, onArrive)
	local slot = nextSlot(kind)
	local part, trail = slot.part, slot.trail

	local distance = (toPosition - fromPosition).Magnitude
	local speed = kind == "arrow" and ARROW_SPEED_STUDS_PER_SEC or ORB_SPEED_STUDS_PER_SEC
	local travelTime = math.max(distance / speed, 0.03)

	part.Color = isCrit and (kind == "arrow" and ARROW_CRIT_COLOR or ORB_CRIT_COLOR) or (kind == "arrow" and ARROW_COLOR or ORB_COLOR)
	if slot.light then
		slot.light.Color = part.Color
	end
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
		if onArrive then
			onArrive()
		end
	end)

	return travelTime
end

return Projectiles
