-- BOSS-NIGHT-2 3 발생 지점 디버그 표시(개발용 · 기본 꺼짐 - BossFxData.originDebug.enabled 또는 workspace Attribute BossOriginDebug = true):
--   서버 사건의 자리(예고 · 판정 · 이펙트가 같이 쓰는 값)에 작은 점 + 판정 범위 선(원 = 반경 · 부채 = 두 변 · 직선 = 빔 · 투사체 = 발사점). 파트는 몇 초 뒤 치운다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local D = require(ReplicatedStorage.Shared.data.BossFxData).originDebug
local BossOriginDebug = {}

local function on()
	return D.enabled or Workspace:GetAttribute(D.attribute) == true
end

local function part(size, cf, shape)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = D.color
	p.Size = size
	p.CFrame = cf
	if shape then
		p.Shape = shape
	end
	p.Parent = Workspace
	task.delay(D.seconds, function()
		p:Destroy()
	end)
	return p
end

local function dot(at)
	part(Vector3.one * D.dot, CFrame.new(at + Vector3.new(0, D.dot / 2, 0)), Enum.PartType.Ball)
end

local function line(a, b)
	local d = b - a
	if d.Magnitude > 1e-3 then
		part(Vector3.new(D.line, D.line, d.Magnitude), CFrame.lookAt((a + b) / 2, b))
	end
end

local function circle(center, radius)
	local n = 24
	for i = 1, n do
		local a0, a1 = (i - 1) / n * 2 * math.pi, i / n * 2 * math.pi
		line(center + Vector3.new(math.cos(a0), 0, math.sin(a0)) * radius, center + Vector3.new(math.cos(a1), 0, math.sin(a1)) * radius)
	end
end

function BossOriginDebug.note(kind, data)
	if not on() or type(data) ~= "table" then
		return
	end
	local lift = Vector3.new(0, 0.15, 0)
	if (kind == "heavyTelegraph" or kind == "heavyImpact") and data.center then
		dot(data.center)
		circle(data.center + lift, data.radius or 1)
	elseif kind == "sector" and data.center then
		dot(data.center)
		local r = data.radius or 10
		for _, s in ipairs({ -1, 1 }) do
			local a = math.rad((data.angleDeg or 0) + s * (data.widthDeg or 60) / 2)
			line(data.center + lift, data.center + lift + Vector3.new(math.cos(a), 0, math.sin(a)) * r)
		end
	elseif (kind == "shockwave" or kind == "shockTelegraph") and data.center then
		dot(data.center)
	elseif kind == "cross" and data.center then
		dot(data.center)
		for k, length in ipairs(data.lengths or {}) do
			local a = math.rad((data.angleDeg or 0) + (data.stepDeg or 0) * (k - 1))
			line(data.center + lift, data.center + lift + Vector3.new(math.cos(a), 0, math.sin(a)) * length)
		end
	elseif kind == "projSpawn" and data.position then
		dot(data.position)
	elseif kind == "projTelegraph" and data.center then
		dot(data.center + Vector3.new(0, data.launchHeight or 0, 0))
	end
end

return BossOriginDebug
