-- W2 공격 잔상 도우미(그리기 규칙 한 곳): 스킨 · "다른 유저 흐리게" · 칼날 리본 스타일(WeaponVisual) · 투사체 꼬리 스타일(Projectiles) · 적중 불꽃.
--   수치 = shared/data/TrailData(너비 · 수명 · 강공격 규칙은 스킨 무관) · 스킨 = Player Attribute TrailSkin(서버가 소유 확인 뒤 건다).
--   판정 없음(그리기만). 판정 도형 표시는 /gg hitbox(client/HitboxDebugView) 전용.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local TrailData = require(ReplicatedStorage.Shared.data.TrailData)
local TrailSkin = require(ReplicatedStorage.Shared.TrailSkin)

local AttackTrail = {}

local player = Players.LocalPlayer

local dimOthers = TrailData.dimOthers.default
function AttackTrail.setDimOthers(on)
	dimOthers = on == true
end
function AttackTrail.dimOthers()
	return dimOthers
end

-- 스킨(Player Attribute - 없거나 금지 검사 X면 기본)
function AttackTrail.skinOf(who)
	local id = typeof(who) == "Instance" and who:IsA("Player") and who:GetAttribute("TrailSkin") or nil
	return (TrailSkin.resolve(id))
end

local function extraFor(who)
	if who ~= player and dimOthers then
		return TrailData.dimOthers.extraTransparency
	end
	return 0
end

local function fade(from)
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, math.min(from, 1)), NumberSequenceKeypoint.new(1, 1) })
end

-- 칼날 리본 스타일(WeaponVisual이 Trail에 칠한다): heavy = 3타 · 공중 3타 강공격
function AttackTrail.ribbonStyle(who, heavy)
	local R = TrailData.ribbon
	local skin = AttackTrail.skinOf(who)
	local extra = extraFor(who)
	local start = heavy and R.heavy.startTransparency or R.startTransparency
	return {
		color = ColorSequence.new(skin.core, skin.edge),
		transparency = fade(start + extra),
		lightEmission = heavy and R.heavy.lightEmission or R.lightEmission,
		widthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, R.widthTaper) }),
		lifetime = R.lifetime,
		gloss = heavy and { transparency = fade(R.heavy.gloss.transparency + extra), lifetime = R.heavy.gloss.lifetime } or nil,
	}
end

-- 투사체 꼬리 스타일(Projectiles.fire가 Trail에 칠한다): kind = "arrow" | "orb"
function AttackTrail.tailStyle(who, kind, heavy)
	local P = TrailData.projectile[kind] or TrailData.projectile.arrow
	local skin = AttackTrail.skinOf(who)
	return {
		color = ColorSequence.new(skin.core, skin.edge),
		transparency = fade(P.startTransparency + extraFor(who)),
		lightEmission = P.lightEmission,
		width = heavy and P.heavyWidth or P.width,
		lifetime = heavy and P.heavyLifetime or P.lifetime,
		particle = skin.particle or skin.core,
	}
end

-- ─── 적중 불꽃(작은 조각 풀 · 서버 적중 지점) ───
local folder = Instance.new("Folder")
folder.Name = "AttackSparks"
folder.Parent = Workspace
local POOL = 48
local pool, poolIndex, active = {}, 0, {}
for i = 1, POOL do
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material, p.Size, p.Transparency = Enum.Material.Neon, Vector3.one * 0.25, 1
	p.Parent = folder
	pool[i] = p
end

function AttackTrail.spark(who, position, count)
	if typeof(position) ~= "Vector3" then
		return
	end
	local S = TrailData.spark
	local skin = AttackTrail.skinOf(who)
	local extra = extraFor(who)
	for i = 1, count do
		poolIndex = poolIndex % POOL + 1
		local p = pool[poolIndex]
		local a = (i / count) * math.pi * 2 + math.random() * 0.8
		p.Color = skin.particle or skin.core
		p.CFrame = CFrame.new(position) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
		p.Transparency = 0.1 + extra
		active[p] = { startAt = os.clock(), from = p.Transparency, velocity = Vector3.new(math.cos(a), 0.5 + math.random() * 0.7, math.sin(a)) * S.speed }
	end
end

-- 검증 · 스크린샷(Studio): 발사 · 도착 · 결과 순간을 LocalPlayer의 BindableEvent "W2TrailDebug"로 알린다(execute_luau 기록기가 연결).
local debugEvent
if RunService:IsStudio() then
	debugEvent = Instance.new("BindableEvent")
	debugEvent.Name = "W2TrailDebug"
	debugEvent.Parent = player
end
function AttackTrail.debugFire(kind, info)
	if debugEvent then
		debugEvent:Fire(kind, os.clock(), info)
	end
end

RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	local life = TrailData.spark.seconds
	for p, a in pairs(active) do
		local t = (now - a.startAt) / life
		if t >= 1 then
			p.Transparency = 1
			active[p] = nil
		else
			p.Transparency = a.from + (1 - a.from) * t
			p.CFrame += a.velocity * dt
			a.velocity += Vector3.new(0, -Workspace.Gravity * 0.3 * dt, 0)
		end
	end
end)

return AttackTrail
