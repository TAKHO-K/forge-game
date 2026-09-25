-- BR1-2 근접 원형 구역(서리 거인 · 폭풍 군주 · 구간 수호자 - 보스 모델 Attribute BossInnerCircle = 반경): 보스 발밑 바닥에 원(파랑 테 - 안 = 평타가 안 닿는 곳)이 늘 따라간다.
-- 평타(basicSweep) = 원 밖을 낫처럼 쓰는 반투명 붉은 호(0.25초에 한 바퀴 반) - 판정은 서버(원 밖 · 사거리 안 전원).
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

-- 낫 휘두르기: 원(inner) ~ 사거리(outer) 띠를 붉은 호가 한 바퀴 반 돈다.
function BossInnerCircleView.sweep(data)
	local mid = (data.inner + data.outer) / 2
	local blade = newPart(Vector3.new(data.outer - data.inner, 0.3, 3), DANGER, 0.35)
	local start = math.random() * 2 * math.pi
	local steps = 10
	for i = 0, steps do
		task.delay(0.025 * i, function()
			if blade.Parent then
				local a = start + i / steps * math.pi * 1.5
				local at = Vector3.new(data.center.X + math.cos(a) * mid, data.center.Y - 2.6, data.center.Z + math.sin(a) * mid)
				blade.CFrame = CFrame.lookAt(at, Vector3.new(data.center.X, at.Y, data.center.Z)) * CFrame.Angles(0, math.rad(90), 0)
			end
		end)
	end
	task.delay(0.3, function()
		blade:Destroy()
	end)
end

return BossInnerCircleView
