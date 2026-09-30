-- BR1-2 근접 원형 구역(서리 거인 · 폭풍 군주 · 구간 수호자 - 보스 모델 Attribute BossInnerCircle = 반경): 보스 발밑 바닥에 원(파랑 테 - 안 = 평타가 안 닿는 곳)이 늘 따라간다.
-- 평타(basicSweep) = 원 밖 판정 띠와 같은 크기의 궤적이 한 바퀴 쓸고 사라진다(A2-N4 - BossBR1View.swingTrail) - 판정은 서버(원 밖 · 사거리 안 전원 · 평타 줄이면 원 안은 약하게).
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BossInnerCircleView = {}

local SAFE = Color3.fromRGB(120, 200, 255)
local DANGER = Color3.fromRGB(230, 40, 40)
local SEGMENTS = 32

local rings = {} -- [보스 Model] = { parts }

local function newPart(size, color, transparency)
	local part = Instance.new("Part")
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = size
	part.Transparency = transparency
	part.Parent = Workspace
	return part
end

local function floorOf(model)
	local pivot = model:GetPivot().Position
	local hit = Workspace:Raycast(pivot + Vector3.new(0, 2, 0), Vector3.new(0, -20, 0), (function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { model }
		return params
	end)())
	return hit and hit.Position.Y or pivot.Y - 3
end

RunService.RenderStepped:Connect(function()
	for model, entry in pairs(rings) do
		if not model.Parent or not model:GetAttribute("BossInnerCircle") then
			for _, part in ipairs(entry.parts) do
				part:Destroy()
			end
			rings[model] = nil
		end
	end
	for _, model in ipairs(Workspace:GetChildren()) do
		local radius = model:IsA("Model") and model:GetAttribute("BossInnerCircle")
		if radius then
			local entry = rings[model]
			if not entry then
				entry = { parts = {}, floorAt = 0 }
				for i = 1, SEGMENTS do
					table.insert(entry.parts, newPart(Vector3.new(radius * 2 * math.pi / SEGMENTS + 0.3, 0.2, 0.7), SAFE, 0.25))
				end
				rings[model] = entry
			end
			if os.clock() - entry.floorAt > 0.5 then
				entry.floorAt = os.clock()
				entry.floorY = floorOf(model)
			end
			local c = model:GetPivot().Position
			for i, part in ipairs(entry.parts) do
				local a = (i - 0.5) / SEGMENTS * 2 * math.pi
				part.CFrame = CFrame.new(c.X + math.cos(a) * radius, entry.floorY + 0.15, c.Z + math.sin(a) * radius) * CFrame.Angles(0, -a + math.pi / 2, 0)
			end
		end
	end
end)

function BossInnerCircleView.sweep(data)
	-- A2-N4 §2-4: 판정 띠(원 inner ~ 사거리 outer 한 바퀴)와 같은 크기의 궤적이 0.12초에 한 바퀴 쓸고 사라진다 · 원 안 약한 휘두름(평타 줄)은 옅게
	local BossBR1View = require(script.Parent.BossBR1View)
	-- 바닥 높이 = 원형 구역 표시가 재 둔 floorY(가장 가까운 보스) - 루트 높이는 보스 덩치마다 달라 루트 − 상수로는 바닥 아래로 들어갔다(Play 캡처)
	local floorY, best = nil, math.huge
	for model, entry in pairs(rings) do
		local d = model.Parent and (model:GetPivot().Position - data.center).Magnitude or math.huge
		if d < best and entry.floorY then
			floorY, best = entry.floorY, d
		end
	end
	local base = Vector3.new(data.center.X, floorY or (data.center.Y - 1.5), data.center.Z)
	BossBR1View.swingTrail(base, math.random() * 360, 360, data.inner, data.outer, DANGER, 0.3)
	if data.innerSwing then
		BossBR1View.swingTrail(base, math.random() * 360, 360, 0, data.inner, DANGER, 0.6)
	end
end

return BossInnerCircleView
