-- W2-2 판정 표시(/gg hitbox on|off - 서버 AttackServer가 켠 사람에게만 HitboxDebug를 보낸다). 사용자가 궤적과 실제 판정을 직접 비교하는 용도.
--   range = 평타 판정 원(AimPicker = 사거리 원 안에서 1명 - 부채꼴 아님) 반투명 원판 + 고른 대상 점.
--   projectile = 서버가 계산한 경로(발사 자리 → 발사 순간 대상 자리) 선 + 허용 폭 원(이 안에 있으면 맞음) + 도달 순간 대상 자리(초록 = 맞음 · 빨강 = 빗나감).
--   blocked = 벽에 막힌 발사(선 + 막힌 점).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local event = ReplicatedStorage:WaitForChild("HitboxDebug")

local folder = Instance.new("Folder")
folder.Name = "HitboxDebug"
folder.Parent = Workspace

local CYAN, GREEN, RED, WHITE = Color3.fromRGB(80, 220, 255), Color3.fromRGB(90, 230, 120), Color3.fromRGB(255, 80, 80), Color3.new(1, 1, 1)

local function part(props, seconds)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = folder
	Debris:AddItem(p, seconds)
	return p
end

local function disc(center, radius, color, transparency, seconds)
	return part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, radius * 2, radius * 2), CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Transparency = transparency }, seconds)
end

local function dot(center, color, seconds, size)
	return part({ Shape = Enum.PartType.Ball, Size = Vector3.one * (size or 0.8), CFrame = CFrame.new(center), Color = color, Transparency = 0.15, Material = Enum.Material.Neon }, seconds)
end

local function line(a, b, color, seconds)
	local len = (b - a).Magnitude
	if len < 0.05 then
		return
	end
	return part({ Size = Vector3.new(0.12, 0.12, len), CFrame = CFrame.lookAt((a + b) / 2, b), Color = color, Transparency = 0.2, Material = Enum.Material.Neon }, seconds)
end

event.OnClientEvent:Connect(function(info)
	if type(info) ~= "table" then
		return
	end
	if info.kind == "range" then
		local feet = info.origin - Vector3.new(0, 2.9, 0)
		disc(feet, info.range, CYAN, 0.72, 0.5)
		disc(feet + Vector3.new(0, 0.02, 0), 0.6, WHITE, 0.2, 0.5)
		if info.target then
			dot(info.target, CYAN, 0.5, 1)
			line(info.origin, info.target, CYAN, 0.5)
		end
	elseif info.kind == "projectile" then
		line(info.origin, info.launch or info.arrive, WHITE, 1.2)
		if info.launch then
			disc(info.launch - Vector3.new(0, 2.9, 0), info.tolerance, info.hit and GREEN or RED, 0.75, 1.2)
			dot(info.launch, WHITE, 1.2, 0.6)
		end
		dot(info.arrive, info.hit and GREEN or RED, 1.2, 1.1)
	elseif info.kind == "blocked" then
		line(info.origin, info.wall, RED, 1)
		dot(info.wall, RED, 1, 0.9)
	end
end)
