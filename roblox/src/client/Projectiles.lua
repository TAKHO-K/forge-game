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
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ProjectileConfig = require(ReplicatedStorage.Shared.data.ProjectileConfig)
local TrailData = require(ReplicatedStorage.Shared.data.TrailData)
local SkillData = require(ReplicatedStorage.Shared.data.SkillData) -- C3-2 강궁 화살 크기
local VfxData = require(ReplicatedStorage.Shared.data.VfxData) -- W3c 비장의 한 발 · 어둠 구슬
local SkillVfx = require(script.Parent.SkillVfx)

local Projectiles = {}

-- W2 ⑨: 속사 버프 최대(공속 ×6.25 · 활 쿨다운 0.053초 · 체공 ≈ 0.43 + 0.27초)면 동시에 약 13발이 난다 - 6개 풀은 날던 화살을 도중에 빼 써서 순간이동 · 끊김이 났다 → 16.
local POOL_SIZE_PER_KIND = 24 -- 내 화살 + 남의 화살(중계) 같이

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
	light.Enabled = false -- QUEUE-STUDIO P-3: 날 때만 켠다(옛 = 풀 24개가 투명한 채 마지막 도착 자리에서 늘 빛났다 - 모든 사람 화면에 광원 24)
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

	-- W2-2: 구슬 옅은 파티클(날아가는 동안만)
	local P = TrailData.projectile.orb.particles
	local particles = Instance.new("ParticleEmitter")
	particles.Rate = P.rate
	particles.Lifetime = NumberRange.new(P.lifetime)
	particles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, P.size), NumberSequenceKeypoint.new(1, 0) })
	particles.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	particles.Speed = NumberRange.new(0.5, 1.5)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.LightEmission = 0.8
	particles.Enabled = false
	particles.Parent = part

	local slot = { part = part, trail = trail, light = light, particles = particles, baseSize = part.Size }
	SkillVfx.decorateOrb(slot) -- W3c 딜링모드 어둠 구슬(보라 테두리 껍질 · 어둠 입자 - 평소 숨김)
	return slot
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

local flying -- [slot] = 날고 있는 것(아래 fire) - 빈 슬롯을 먼저 고른다
local function nextSlot(kind)
	local list = pools[kind]
	for _ = 1, #list do -- W2 리뷰: 날고 있는 슬롯은 건너뛴다(남의 화살과 풀을 같이 써도 내 화살이 도중에 뺏기지 않게)
		poolIndex[kind] = (poolIndex[kind] % #list) + 1
		local slot = list[poolIndex[kind]]
		if not flying[slot] then
			return slot
		end
	end
	poolIndex[kind] = (poolIndex[kind] % #list) + 1
	local slot = list[poolIndex[kind]]
	local old = flying[slot]
	flying[slot] = nil
	if old and old.onArrive then
		old.onArrive(old.fallback, false) -- 다 차서 덮어쓸 때: 이전 것의 도착 콜백을 지금 부른다(안 불리고 사라지지 않게)
	end
	return slot
end

-- 발사 순간 섬광(20-5 [1] - "발사 순간과 적중 순간을 시각적으로 구분해라. 지금은 둘 다
-- 아무것도 없어서 쐈는지도 모르고 맞았는지도 모르는 상태다"). 적중 쪽은 이미
-- HitEffects.playHit의 버스트가 있다(AttackInput.client.lua showResult) - 여기선 그
-- 반대편(발사)에 짧은 섬광 하나를 더해 쌍을 맞춘다. HitEffects.lua와 같은 풀링 원칙,
-- 다만 발사 이펙트는 몬스터당이 아니라 화살 개수만큼이라 풀을 따로 작게 둔다.
local FLASH_POOL_SIZE = 12 -- W2 ⑨: 투사체 풀과 같이 키움
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

-- W3c variant 추가: "finisher" = 궁수 E 비장의 한 발(강궁보다 한 단계 큰 화살 · 굵은 빛 꼬리) · "dark" = 치유사 딜링모드 어둠 구슬(검은 핵 · 보라 테두리 · 어둠 연기 꼬리).
-- kind: "arrow" | "orb". fromPosition/toPosition: Vector3(월드 좌표). isCrit이면 색이
-- 바뀐다(치명타 여부는 발사 시점에 서버가 이미 알려준다). variant(20-5 [1], 선택값): "empowered"면
-- 백스텝샷이 적용된 평타 화살 - 굵고 밝게, 빛까지 켠다. onArrive는 도착한 프레임에 정확히 한 번 불린다.
-- opts(W2, 선택): { travelSeconds = 서버 비행 시간(없으면 거리 ÷ 속도) · style = AttackTrail.tailStyle(궤적 꼬리 색 · 폭 · 길이) ·
--   target = 대상 모델 · anchor = 발사 순간 대상 루트 자리(클라 화면) · tolerance = 서버 허용 폭 }
--   target이 있으면 매 프레임 끝점을 다시 잡는다(서버 규칙의 거울): 대상 루트가 anchor에서 tolerance 안이면 지금 머리 쪽으로(맞는 화살),
--   넘으면 anchor 쪽으로(빗나가는 화살). 도착 순간 = 서버 도달 시각(요청 시각 + 발사 지연 + 비행 시간 - AttackInput이 맞춘다).
flying = {} -- [slot] = { from, startAt, travel, target, anchor, headOffset, tolerance, fallback, onArrive, kind }

local function aimOf(f)
	local target = f.target
	local root = target and target.Parent and target.PrimaryPart
	if root and f.anchor and (root.Position - f.anchor).Magnitude <= f.tolerance then
		return root.Position + f.headOffset, true
	end
	return f.fallback, false
end

function Projectiles.fire(kind, fromPosition, toPosition, isCrit, variant, onArrive, opts)
	local slot = nextSlot(kind)
	local part, trail = slot.part, slot.trail
	local isEmpowered = kind == "arrow" and variant == "empowered"
	local isHeavy = kind == "arrow" and variant == "heavy" -- C3-2 강궁: 큰 화살(SkillData.bow.Q.heavyShot.arrowScale) · 굵은 꼬리
	local isFinisher = kind == "arrow" and variant == "finisher"
	local isDark = kind == "orb" and variant == "dark"
	local F = VfxData.bowFinisher
	opts = opts or {}

	local distance = (toPosition - fromPosition).Magnitude
	local speed = ProjectileConfig.speedStudsPerSec[kind]
	local travelTime = math.max(opts.travelSeconds or distance / speed, 0.03)

	if isFinisher then
		part.Color = isCrit and F.critColor or F.color
		part.Size = slot.baseSize * F.arrowScale
		trail.Lifetime = F.trailLifetime
	elseif isEmpowered then
		part.Color = isCrit and ARROW_EMPOWERED_CRIT_COLOR or ARROW_EMPOWERED_COLOR
		part.Size = slot.baseSize * ARROW_EMPOWERED_SCALE
		trail.Lifetime = 0.28
	elseif isHeavy then
		part.Color = isCrit and ARROW_CRIT_COLOR or ARROW_COLOR
		part.Size = slot.baseSize * SkillData.bow.Q.heavyShot.arrowScale
		trail.Lifetime = 0.3
	else
		part.Color = isCrit and (kind == "arrow" and ARROW_CRIT_COLOR or ORB_CRIT_COLOR) or (kind == "arrow" and ARROW_COLOR or ORB_COLOR)
		if slot.baseSize then
			part.Size = slot.baseSize
		end
		trail.Lifetime = kind == "arrow" and 0.15 or 0.2
	end
	-- W2 궤적 꼬리(스킨 색 · 콤보 단계 폭): 꼬리 띠 = 진행 방향에 수직(위아래 두 점)
	local style = opts.style
	if style then
		trail.Color = style.color
		trail.Transparency = style.transparency
		trail.Lifetime = isFinisher and F.trailLifetime or (isEmpowered and math.max(style.lifetime, 0.28) or style.lifetime)
		trail.LightEmission = style.lightEmission or 0
		trail.FaceCamera = true
		trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.15) })
		local half = style.width / 2 * (isFinisher and F.trailWidthScale or ((isEmpowered or isHeavy) and 1.6 or 1))
		trail.Attachment0.Position = Vector3.new(0, half, 0)
		trail.Attachment1.Position = Vector3.new(0, -half, 0)
	end
	if slot.light then
		slot.light.Color = part.Color
		slot.light.Enabled = true -- QUEUE-STUDIO P-3: 구슬도 날 때만(밝기 · 범위는 만들 때 값 그대로 - 겉모습 불변)
		if kind == "arrow" then
			-- W2-2: 화살촉 작은 빛(평타 = 은은하게 · 백스텝샷 = 옛 밝기)
			local tip = TrailData.projectile.arrow.tipLight
			slot.light.Enabled = true
			slot.light.Brightness = isFinisher and F.light.brightness or (isEmpowered and 2 or tip.brightness)
			slot.light.Range = isFinisher and F.light.range or (isEmpowered and 10 or tip.range)
		end
	end
	if slot.particles then -- W2-2 지팡이 구슬: 옅은 파티클 몇 개(스킨 파티클 색)
		slot.particles.Color = ColorSequence.new(style and style.particle or part.Color)
		slot.particles.Enabled = true
	end
	if kind == "orb" then
		SkillVfx.styleOrb(slot, isDark, isCrit) -- 꺼짐이면 밝은 구슬로 되돌린다(빛 세기 · 크기는 위에서)
	end
	muzzleFlash(fromPosition, isDark and VfxData.healerDark.rim or part.Color, isEmpowered or isHeavy or isFinisher)

	part.CFrame = CFrame.lookAt(fromPosition, toPosition)
	part.Transparency = 0
	trail.Enabled = true

	local targetRoot = opts.target and opts.target.PrimaryPart
	flying[slot] = {
		kind = kind, from = fromPosition, startAt = os.clock(), travel = travelTime, onArrive = onArrive,
		target = opts.target, anchor = opts.anchor, tolerance = opts.tolerance or 0, fallback = toPosition,
		headOffset = targetRoot and (toPosition - targetRoot.Position) or Vector3.zero,
	}
	return travelTime
end

-- 날아가는 투사체: 매 프레임 끝점을 다시 잡아 선형으로(서버와 같은 직선 · 중력 없음)
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for slot, f in pairs(flying) do
		local t = (now - f.startAt) / f.travel
		local aim, tracking = aimOf(f)
		if t >= 1 then
			flying[slot] = nil
			if (aim - f.from).Magnitude > 1e-3 then
				slot.part.CFrame = CFrame.lookAt(aim, aim + (aim - f.from))
			end
			slot.part.Transparency = 1
			slot.trail.Enabled = false
			if slot.light then
				slot.light.Enabled = false -- QUEUE-STUDIO P-3: 구슬도 도착하면 끈다(투명한 구슬이 남긴 빛 제거)
			end
			if slot.particles then
				slot.particles.Enabled = false
			end
			SkillVfx.orbArrived(slot)
			if f.onArrive then
				f.onArrive(aim, tracking)
			end
		else
			local pos = f.from:Lerp(aim, t)
			if (aim - pos).Magnitude > 1e-3 then
				slot.part.CFrame = CFrame.lookAt(pos, aim)
			end
		end
	end
end)

return Projectiles
