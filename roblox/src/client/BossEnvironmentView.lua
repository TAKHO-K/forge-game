-- BR1 환경 변화의 그림 · 힘(docs/design/boss-br1.md §4) - 서버(BossEnvironment)가 보낸 구역만 그린다. 보이는 구역 = 서버 판정 구역(같은 표).
--   envTelegraph  구역을 위험색으로 옅게 깔고 가장자리에 금(흰 선)이 번진다 · 스타일별 한 가지 강조(용암 = 먼지 · 물 = 넘치는 물결 · 모래 = 소용돌이 · 바람 = 줄기)
--   envStart      구역이 진해진다(재질로 구분 - 용암 CrackedLava · 얼음물 Glass · 급류 Glass · 모래 Sand · 전기 Neon) · 밥상뒤집기 = 판이 들렸다 뒤집히는 그림
--   envWind       바람 방향이 돈다(바람이 불어 가는 반원의 가장자리 = 전기 벽)
--   힘(내 캐릭터만 - 서버 판정과 무관): pit = 반경 안이면 중심으로 끌린다 · wind = 바람 방향으로 밀린다(공중이면 airMultiplier배). 걷기(16)보다 약하다 - 버티면 나간다.
-- 큰 파트를 물리로 뒤집지 않는다 - 전부 Anchored 그림(사용자 지시).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local BossFx = require(script.Parent.BossFx)

local BossEnvironmentView = {}

local player = Players.LocalPlayer
local DANGER = UIColors.danger
local WHITE = Color3.new(1, 1, 1)
local DUST = Color3.fromRGB(235, 228, 214)
local STEP_DEG = 6

local STYLE_MATERIAL = {
	lava = Enum.Material.CrackedLava,
	ice = Enum.Material.Glass,
	water = Enum.Material.Glass,
	sand = Enum.Material.Sand,
	storm = Enum.Material.Neon,
	crystal = Enum.Material.Glass,
}

local live = {}
local voids = {} -- BR1-3 무너진 조각(검은 구멍) - 다음 붕괴 · 보스전 끝까지 남는다(전조가 current를 새로 만들어도 지우지 않는다)
local VOID = Color3.fromRGB(12, 10, 14)
local current = nil -- { zones, parts = { [zone index] = { parts } }, style, active, forces }

local function newPart(size, color, transparency, material, shape)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = material or Enum.Material.Neon
	part.Color = color
	part.Size = size
	part.Transparency = transparency
	if shape then
		part.Shape = shape
	end
	part.Parent = Workspace
	live[part] = true
	return part
end

local function destroy(part)
	if part and live[part] then
		live[part] = nil
		part:Destroy()
	end
end

-- 부채꼴 · 고리(가운데 center · 가운데 각 angleDeg · 폭 widthDeg · inner ~ outer)를 호 조각으로.
local function arcParts(center, angleDeg, widthDeg, inner, outer, color, transparency, material)
	local parts = {}
	local steps = math.max(2, math.ceil(widthDeg / STEP_DEG))
	local mid = (inner + outer) / 2
	for i = 0, steps - 1 do
		local a = math.rad(angleDeg - widthDeg / 2 + widthDeg * (i + 0.5) / steps)
		local arc = 2 * math.pi * outer * (widthDeg / 360) / steps * 1.08
		local part = newPart(Vector3.new(arc, 0.25, outer - inner), color, transparency, material)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		part.CFrame = CFrame.lookAt(center + dir * mid + Vector3.new(0, 0.2, 0), center + dir * (mid + 1) + Vector3.new(0, 0.2, 0))
		table.insert(parts, part)
	end
	return parts
end

-- 구역 하나의 그림(전조 · 활성 공용 - 색 · 투명도 · 재질만 다르다).
local function zoneParts(z, transparency, material)
	if z.shape == "circle" then
		local part = newPart(Vector3.new(0.25, z.radius * 2, z.radius * 2), DANGER, transparency, material, Enum.PartType.Cylinder)
		part.CFrame = CFrame.new(z.center + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
		return { part }
	elseif z.shape == "ring" then
		return arcParts(z.center, 0, 360, z.beyond, z.radius, DANGER, transparency, material)
	elseif z.shape == "pit" then
		local core = newPart(Vector3.new(0.25, z.core * 2, z.core * 2), DANGER, transparency, material, Enum.PartType.Cylinder)
		core.CFrame = CFrame.new(z.center + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90))
		local slope = arcParts(z.center, 0, 360, z.radius - 1.2, z.radius, WHITE, 0.5, Enum.Material.SmoothPlastic) -- 끌림 반경 테두리(흰 선 - 위험이 아니라 경계)
		table.insert(slope, core)
		-- BR1-2 개미지옥: 모래 깔때기(안쪽으로 갈수록 낮아 보이는 고리 3겹 - 도는 것은 매 프레임) · 테두리 밖을 가리키는 흰 화살표 8개(빠져나오는 법)
		for k = 1, 3 do
			local r = z.core + (z.radius - z.core) * k / 4
			for _, part in ipairs(arcParts(z.center - Vector3.new(0, 0.05 * k, 0), 0, 360, r - 0.6, r, Color3.fromRGB(190, 160, 110), 0.3, Enum.Material.Sand)) do
				part:SetAttribute("PitSwirl", k)
				table.insert(slope, part)
			end
		end
		for i = 1, 8 do
			local a = i / 8 * 2 * math.pi
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local arrow = newPart(Vector3.new(1.2, 0.3, 4), WHITE, 0.2, Enum.Material.Neon)
			arrow.CFrame = CFrame.lookAt(z.center + dir * (z.radius + 2.5) + Vector3.new(0, 0.3, 0), z.center + dir * (z.radius + 6) + Vector3.new(0, 0.3, 0))
			local tip = newPart(Vector3.new(2.6, 0.3, 1.2), WHITE, 0.2, Enum.Material.Neon)
			tip.CFrame = arrow.CFrame * CFrame.new(0, 0, -2.2) * CFrame.Angles(0, math.rad(45), 0)
			table.insert(slope, arrow)
			table.insert(slope, tip)
		end
		return slope
	elseif z.shape == "slice" then
		-- BR1-3 피자 조각(허브 밖 · 두 경계선 사이)
		return arcParts(z.center, z.startDeg + z.widthDeg / 2, z.widthDeg, z.hub, z.radius, DANGER, transparency, material)
	elseif z.shape == "rect" and z.halfMap then
		-- BR1-3 판 털기: 맵 절반 = 반원(아레나 중심 · 판 쪽 방위 angleDeg + 90) - 판정 사각형과 원 안에서 같다
		local a = math.rad(z.angleDeg)
		local side = Vector3.new(-math.sin(a), 0, math.cos(a))
		return arcParts(z.center - side * z.halfWidth, z.angleDeg + 90, 180, 0, z.halfLength, DANGER, transparency, material)
	elseif z.shape == "rect" then
		local part = newPart(Vector3.new(z.halfWidth * 2, 0.25, z.halfLength * 2), DANGER, transparency, material)
		part.CFrame = CFrame.new(z.center + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, -math.rad(z.angleDeg) + math.rad(90), 0)
		return { part }
	elseif z.shape == "wind" then
		return arcParts(z.center, z.angleDeg, 180, z.beyond, z.radius, DANGER, transparency, material)
	end
	return {}
end

local function clearParts()
	if current then
		for _, list in pairs(current.parts) do
			for _, part in ipairs(list) do
				destroy(part)
			end
		end
		current.parts = {}
	end
end

-- 금(가장자리에서 번지는 흰 선) - 전조 동안 몇 번 튄다.
local function crackAlong(z, seconds)
	local points = {}
	if z.shape == "circle" or z.shape == "pit" then
		local r = z.shape == "pit" and z.radius or z.radius
		for i = 1, 10 do
			local a = i / 10 * 2 * math.pi
			table.insert(points, { z.center + Vector3.new(math.cos(a) * r, 0.4, math.sin(a) * r), Vector3.new(-math.sin(a), 0, math.cos(a)) })
		end
	elseif z.shape == "ring" or z.shape == "wind" then
		local r = z.beyond
		for i = 1, 24 do
			local a = i / 24 * 2 * math.pi
			table.insert(points, { z.center + Vector3.new(math.cos(a) * r, 0.4, math.sin(a) * r), Vector3.new(-math.sin(a), 0, math.cos(a)) })
		end
	elseif z.shape == "slice" then
		-- 두 경계선(가운데 → 벽) + 바깥 호를 따라 금
		for _, deg in ipairs({ z.startDeg, z.startDeg + z.widthDeg }) do
			local dir = Vector3.new(math.cos(math.rad(deg)), 0, math.sin(math.rad(deg)))
			for i = 0, 8 do
				table.insert(points, { z.center + dir * (z.hub + (z.radius - z.hub) * i / 8) + Vector3.new(0, 0.4, 0), dir })
			end
		end
	elseif z.shape == "rect" and z.halfMap then
		-- 판 털기: 판의 가장자리(지름 = 보스가 잡는 쪽)를 따라 금
		local a = math.rad(z.angleDeg)
		local along, side = Vector3.new(math.cos(a), 0, math.sin(a)), Vector3.new(-math.sin(a), 0, math.cos(a))
		local edge = z.center - side * z.halfWidth
		for i = -6, 6 do
			table.insert(points, { edge + along * (z.halfLength * i / 6) + Vector3.new(0, 0.4, 0), along })
		end
	elseif z.shape == "rect" then
		local a = math.rad(z.angleDeg)
		local along, side = Vector3.new(math.cos(a), 0, math.sin(a)), Vector3.new(-math.sin(a), 0, math.cos(a))
		for i = -3, 3 do
			table.insert(points, { z.center + along * (z.halfLength * i / 3) + side * z.halfWidth + Vector3.new(0, 0.4, 0), along })
			table.insert(points, { z.center + along * (z.halfLength * i / 3) - side * z.halfWidth + Vector3.new(0, 0.4, 0), along })
		end
	end
	for index, entry in ipairs(points) do
		task.delay(seconds * (index / #points) * 0.8, function()
			if current then
				BossFx.streak(entry[1], entry[2], 5, 0.25, WHITE, 0.9, 0)
				BossFx.puff(entry[1], 2, DUST, 0.6, Vector3.new(0, 3, 0))
			end
		end)
	end
end

-- BR1-2 수정 부수기(garden = { courses }): 전조 동안 두 코스의 발판 자리에 흰 테 · 수정 자리에 빛기둥이 솟는다(서버가 활성 순간 진짜 발판 · 수정을 세운다).
local function gardenTelegraph(garden, seconds)
	local parts = {}
	for _, course in ipairs(garden.courses or {}) do
		for _, p in ipairs(course.platforms or {}) do
			BossFx.ring(p.position + Vector3.new(0, 0.3, 0), 1, p.width, WHITE, seconds)
			if p.crystal then
				local pillar = newPart(Vector3.new(2, 0.5, 2), WHITE, 0.3, Enum.Material.Neon)
				pillar.CFrame = CFrame.new(p.position)
				TweenService:Create(pillar, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(2, 60, 2) }):Play()
				table.insert(parts, pillar)
			end
		end
	end
	return parts
end

-- 빛줄기(보스 색): 수정 → 보스(길 안내 - 매 프레임 보스를 따라간다). 수정이 깨지면 그 줄이 사라진다.
local beams = {} -- [site] = { part, from }
local function clearBeams()
	for site, entry in pairs(beams) do
		beams[site] = nil
		destroy(entry.part)
	end
end

local function startBeams(garden, color)
	clearBeams()
	for site, course in ipairs(garden.courses or {}) do
		for _, p in ipairs(course.platforms or {}) do
			if p.crystal then
				local part = newPart(Vector3.new(0.8, 0.8, 1), color or DANGER, 0.25, Enum.Material.Neon)
				beams[site] = { part = part, from = p.position + Vector3.new(0, 3, 0) }
			end
		end
	end
end

local function bossModelNear(position)
	local best, bestDistance = nil, math.huge
	for _, model in ipairs(Workspace:GetChildren()) do
		if model:IsA("Model") and model:GetAttribute("BossShielded") then
			local d = (model:GetPivot().Position - position).Magnitude
			if d < bestDistance then
				best, bestDistance = model, d
			end
		end
	end
	return best
end

-- 보호막(보스 둘레 유리 공 - BossShielded Attribute가 켜진 보스) · 빛줄기 매 프레임
local shieldBall = nil
RunService.RenderStepped:Connect(function()
	local anyBeam = next(beams) ~= nil
	local model = nil
	if anyBeam then
		for _, entry in pairs(beams) do
			model = bossModelNear(entry.from)
			break
		end
	end
	if model then
		local center = model:GetPivot().Position + Vector3.new(0, 2, 0)
		for _, entry in pairs(beams) do
			local length = (center - entry.from).Magnitude
			entry.part.Size = Vector3.new(0.8, 0.8, length)
			entry.part.CFrame = CFrame.lookAt(entry.from:Lerp(center, 0.5), center)
		end
		if not shieldBall or not shieldBall.Parent then
			shieldBall = newPart(Vector3.one * 16, Color3.fromRGB(170, 220, 255), 0.7, Enum.Material.ForceField)
			shieldBall.Shape = Enum.PartType.Ball
		end
		shieldBall.CFrame = CFrame.new(center)
	elseif shieldBall then
		destroy(shieldBall)
		shieldBall = nil
	end
end)

-- BR1-2 프라이팬: 아주 멀리 날아간 사람이 궤적 끝 하늘에서 "반짝" 별이 된다(자체 카툰 연출 - 노랑 네온 네 갈래 + 흰 가운데 · 커졌다 돌며 사라짐).
-- 풀링: 부품 한 벌을 한 번 만들어 계속 다시 쓴다(겹치면 마지막 것만) · 파티클 방출기 0. 아레나 멤버 전원이 받는다(날아간 본인 · 다른 사람 모두).
local starParts = nil
local starToken = 0
local function starSet()
	if starParts and starParts[1].Parent then
		return starParts
	end
	starParts = {}
	for i = 1, 2 do
		local ray = Instance.new("Part")
		ray.Name = "BossStarRay"
		ray.Anchored, ray.CanCollide, ray.CanQuery, ray.CanTouch, ray.CastShadow = true, false, false, false, false
		ray.Material = Enum.Material.Neon
		ray.Color = Color3.fromRGB(255, 225, 90)
		ray.Size = Vector3.new(0.6, 0.6, 6)
		ray.Transparency = 1
		ray.Parent = Workspace
		starParts[i] = ray
	end
	local core = Instance.new("Part")
	core.Name = "BossStarCore"
	core.Anchored, core.CanCollide, core.CanQuery, core.CanTouch, core.CastShadow = true, false, false, false, false
	core.Material = Enum.Material.Neon
	core.Shape = Enum.PartType.Ball
	core.Color = WHITE
	core.Size = Vector3.one * 1.6
	core.Transparency = 1
	core.Parent = Workspace
	starParts[3] = core
	return starParts
end

function BossEnvironmentView.starTwinkle(data)
	starToken += 1
	local token = starToken
	task.delay(data.delay or 0, function()
		if token ~= starToken then
			return
		end
		local parts = starSet()
		local started = os.clock()
		local connection
		connection = RunService.RenderStepped:Connect(function()
			local t = (os.clock() - started) / 0.7
			if t >= 1 or token ~= starToken then
				for _, part in ipairs(parts) do
					part.Transparency = 1
				end
				connection:Disconnect()
				return
			end
			local scale = math.sin(t * math.pi) * 2.2 + 0.2 -- 커졌다 작아진다
			local spin = t * math.pi * 1.5
			local facing = CFrame.new(data.position) * Workspace.CurrentCamera.CFrame.Rotation -- 보는 사람 쪽을 향한 네 갈래 별
			for i = 1, 2 do
				parts[i].Size = Vector3.new(0.6 * scale, 6 * scale, 0.6 * scale)
				parts[i].CFrame = facing * CFrame.Angles(0, 0, spin + (i - 1) * math.pi / 2)
				parts[i].Transparency = t * 0.6
			end
			parts[3].Size = Vector3.one * 1.6 * scale
			parts[3].CFrame = CFrame.new(data.position)
			parts[3].Transparency = t * 0.5
		end)
	end)
end

-- BR1-2 수정 부수기 도움 단계: 화면 알림(3초) + 새 발판 자리 강조(흰 고리 · 빛기둥)
function BossEnvironmentView.courseHelp(data)
	local gui = Instance.new("ScreenGui")
	gui.Name = "CourseHelpNotice"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 35
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 140)
	label.Size = UDim2.new(0, 360, 0, 44)
	label.BackgroundColor3 = Color3.fromRGB(30, 34, 44)
	label.BackgroundTransparency = 0.1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 22
	label.TextColor3 = data.stage >= 2 and Color3.fromRGB(255, 200, 80) or Color3.fromRGB(120, 230, 255)
	label.Text = data.stage >= 2 and "수정까지 날아가는 발판이 생겼어요!" or "도움 발판이 생겼어요!"
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label
	gui.Parent = player:WaitForChild("PlayerGui")
	task.delay(3, function()
		gui:Destroy()
	end)
	for _, position in ipairs(data.positions or {}) do
		BossFx.ring(position, 1, 6, WHITE, 2.5)
		local beam = newPart(Vector3.new(0.6, 30, 0.6), label.TextColor3, 0.4)
		beam.CFrame = CFrame.new(position + Vector3.new(0, 15, 0))
		task.delay(3, function()
			destroy(beam)
		end)
	end
end

function BossEnvironmentView.coreHit(data)
	local entry = beams[data.index]
	if entry then
		BossFx.ring(entry.from, 1, 5, WHITE, 0.3)
		if data.broken then
			for _ = 1, 8 do
				BossFx.chunk(entry.from, Vector3.new(math.random(-12, 12), 16, math.random(-12, 12)), 0.8, entry.part.Color, 0.7)
			end
			beams[data.index] = nil
			destroy(entry.part)
		end
	end
end

local function clearVoids(withDust)
	for _, entry in ipairs(voids) do
		for _, part in ipairs(entry.parts) do
			if withDust and math.random() < 0.3 then
				BossFx.puff(part.Position + Vector3.new(0, 1, 0), 3, DUST, 0.6, Vector3.new(0, 5, 0))
			end
			destroy(part)
		end
	end
	voids = {}
end

-- BR1-3 무너진 조각: 바닥이 사라진 검은 구멍(조각 모양) + 무너지는 파편. 이전 조각은 먼지와 함께 돌아온다(구멍을 치운다).
local function collapse(data)
	clearVoids(true)
	for _, z in ipairs(data.zones) do
		local parts = arcParts(z.center, z.startDeg + z.widthDeg / 2, z.widthDeg, z.hub, z.radius, VOID, 0, Enum.Material.SmoothPlastic)
		table.insert(voids, { zone = z, parts = parts })
		local mid = math.rad(z.startDeg + z.widthDeg / 2)
		local dir = Vector3.new(math.cos(mid), 0, math.sin(mid))
		for i = 1, 14 do
			local at = z.center + dir * (z.hub + (z.radius - z.hub) * math.random()) + Vector3.new(0, 0.5, 0)
			BossFx.chunk(at, Vector3.new(math.random(-6, 6), 8, math.random(-6, 6)), 1.6, DUST, 1.0)
		end
		BossFx.shake(z.center + dir * 30, 1)
	end
end

-- BR1-3 판 털기: 보스가 잡은 가장자리(지름)를 경첩으로 반원 판이 통째로 들린다 → shakes번 턴다 → "쿵" 내려놓는다(Anchored 판 - 매 프레임 CFrame, 물리 없음).
-- 판이 들린 동안 그 자리 바닥 = 검은 빈 공간(zoneParts가 VOID 색으로 깐다 - 서버 낙사 구역과 같다).
local function plateShake(z, shakes, seconds)
	local a = math.rad(z.angleDeg)
	local along, side = Vector3.new(math.cos(a), 0, math.sin(a)), Vector3.new(-math.sin(a), 0, math.cos(a))
	local hinge = z.center - side * z.halfWidth
	local pivot = CFrame.fromMatrix(hinge + Vector3.new(0, 0.6, 0), along, Vector3.yAxis)
	local parts = arcParts(hinge, z.angleDeg + 90, 180, 0, z.halfLength, DUST, 0, Enum.Material.Slate)
	local offsets = {}
	for i, part in ipairs(parts) do
		part.Size = Vector3.new(part.Size.X, 1.2, part.Size.Z)
		offsets[i] = pivot:ToObjectSpace(part.CFrame)
	end
	local started = os.clock()
	local liftDeg = 22
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if t >= seconds or not current then
			connection:Disconnect()
			for _, part in ipairs(parts) do
				destroy(part)
			end
			for i = 1, 16 do
				local at = hinge + side * math.random(5, math.floor(z.halfLength)) + along * math.random(-60, 60)
				BossFx.puff(at + Vector3.new(0, 1, 0), 4, DUST, 0.7, Vector3.new(0, 6, 0))
			end
			BossFx.shake(hinge, 1.2) -- 쿵
			return
		end
		local f = t / seconds
		local lift = liftDeg * math.min(t / 0.35, 1) * (f > 0.85 and (1 - f) / 0.15 or 1)
		local wobble = math.sin(t / seconds * shakes * 2 * math.pi) * 9 -- 털기(shakes번 오르내림)
		local rotation = pivot * CFrame.fromAxisAngle(Vector3.new(1, 0, 0), -math.rad(lift + wobble)) -- 판(로컬 +Z)이 위로 들리는 쪽이 음의 각
		for i, part in ipairs(parts) do
			part.CFrame = rotation * offsets[i]
		end
	end)
	for k = 1, shakes do
		task.delay(seconds * (k - 0.5) / shakes, function()
			if current then
				BossFx.shake(hinge, 0.8)
			end
		end)
	end
end

function BossEnvironmentView.voidFall(data)
	BossFx.ring(data.position + Vector3.new(0, 0.5, 0), 1, 6, DUST, 0.4)
	for i = 1, 6 do
		BossFx.chunk(data.position + Vector3.new(0, 0.5, 0), Vector3.new(math.random(-5, 5), -10, math.random(-5, 5)), 1, DUST, 0.6)
	end
end

function BossEnvironmentView.telegraph(data)
	clearParts()
	clearBeams()
	current = nil
	current = { zones = data.zones, parts = {}, style = data.style, active = false, coreFlash = {} }
	if data.garden then
		current.parts.garden = gardenTelegraph(data.garden, data.seconds)
	end
	for index, z in ipairs(data.zones) do
		local parts = zoneParts(z, 0.88, Enum.Material.Neon)
		current.parts[index] = parts
		for _, part in ipairs(parts) do
			if part.Color == DANGER then
				TweenService:Create(part, TweenInfo.new(data.seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 0.55 }):Play()
			end
		end
		crackAlong(z, data.seconds)
		if z.shape == "slice" then
			-- BR1-3 지반 붕괴 전조: 조각이 점점 크게 흔들린다(0.5초마다)
			local mid = math.rad(z.startDeg + z.widthDeg / 2)
			local at = z.center + Vector3.new(math.cos(mid), 0, math.sin(mid)) * (z.hub + z.radius) / 2
			for k = 0, math.floor(data.seconds / 0.5) - 1 do
				task.delay(k * 0.5, function()
					if current then
						BossFx.shake(at, 0.3 + 0.6 * k / math.max(data.seconds / 0.5, 1))
					end
				end)
			end
		elseif z.shape == "rect" then
			-- 널뛰기 전조: 지형이 크게 흔들린다(0.25초마다 흔들림 + 판 가장자리 먼지 기둥) - 판 전체 위험색은 위 zoneParts
			for k = 0, math.floor(data.seconds / 0.25) - 1 do
				task.delay(k * 0.25, function()
					if current then
						BossFx.shake(z.center, 0.35 + 0.5 * k / math.max(data.seconds / 0.25, 1))
						local a = math.rad(z.angleDeg)
						local along = Vector3.new(math.cos(a), 0, math.sin(a))
						for _, sign in ipairs({ 1, -1 }) do
							BossFx.puff(z.center + along * z.halfLength * sign + Vector3.new(0, 1, 0), 3, DUST, 0.5, Vector3.new(0, 6, 0))
						end
					end
				end)
			end
		end
	end
	BossFx.shake(data.zones[1] and data.zones[1].center or Vector3.zero, 0.4)
end

-- 밥상뒤집기 = 널뛰기(사용자 보완 B): 판이 **가운데 받침점**(판 길이의 가운데를 지나는 가로축)을 축으로 한쪽이 솟았다 넘어가며 뒤집힌다(Anchored 판을 트윈 - 물리 없음).
-- 판의 로컬 Z = 판 길이 방향(서버 along) - 받침점에서 먼 끝일수록 크게 움직인다(= 서버가 멀리 날리는 자리).
local function flipSlab(z)
	local a = -math.rad(z.angleDeg) + math.rad(90)
	local slab = newPart(Vector3.new(z.halfWidth * 2, 1.5, z.halfLength * 2), DUST, 0, Enum.Material.Slate)
	local base = CFrame.new(z.center + Vector3.new(0, 0.75, 0)) * CFrame.Angles(0, a, 0)
	slab.CFrame = base
	-- 받침점(가운데 쐐기)
	local fulcrum = newPart(Vector3.new(z.halfWidth * 2, 2, 2), WHITE, 0.2, Enum.Material.Slate)
	fulcrum.CFrame = base * CFrame.new(0, -0.5, 0)
	TweenService:Create(slab, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = base * CFrame.Angles(math.rad(35), 0, 0) }):Play() -- 지렛대가 튕긴다
	task.delay(0.2, function()
		TweenService:Create(slab, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = base * CFrame.Angles(math.rad(180), 0, 0) }):Play() -- 넘어가며 뒤집힌다
		task.delay(0.45, function()
			TweenService:Create(slab, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			TweenService:Create(fulcrum, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			task.delay(0.35, function()
				destroy(slab)
				destroy(fulcrum)
			end)
		end)
	end)
	for i = 1, 10 do
		BossFx.chunk(z.center + Vector3.new(0, 1, 0), Vector3.new(math.random(-15, 15), 25, math.random(-15, 15)), 1.2, DUST, 0.8)
	end
	BossFx.shake(z.center, 1)
end

function BossEnvironmentView.start(data)
	if not current then
		current = { zones = data.zones, parts = {}, style = data.style, coreFlash = {} }
	end
	clearParts()
	current.zones = data.zones
	current.active = true
	current.untilAt = os.clock() + data.seconds
	local material = STYLE_MATERIAL[data.style] or Enum.Material.Neon
	for index, z in ipairs(data.zones) do
		if data.style == "collapse" then
			current.parts[index] = {}
		elseif z.halfMap then
			current.parts[index] = zoneParts(z, 0, Enum.Material.SmoothPlastic) -- 들린 판 자리 = 빈 공간(검정)
			for _, part in ipairs(current.parts[index]) do
				part.Color = VOID
			end
			plateShake(z, data.shakes or 3, data.seconds)
		else
			current.parts[index] = zoneParts(z, 0.35, material)
			if z.shape == "rect" then
				flipSlab(z)
			end
		end
	end
	if data.style == "collapse" then
		collapse(data)
	end
	if data.garden then -- BR1-2 수정 부수기: 수정 → 보스 빛줄기(보스 색)
		startBeams(data.garden, data.color)
	end
end

function BossEnvironmentView.wind(data)
	if not current then
		return
	end
	clearParts()
	current.zones = data.zones
	local material = STYLE_MATERIAL[current.style] or Enum.Material.Neon
	for index, z in ipairs(data.zones) do
		current.parts[index] = zoneParts(z, 0.35, material)
	end
end

function BossEnvironmentView.clear()
	clearParts()
	clearBeams()
	clearVoids(false)
	current = nil
end

function BossEnvironmentView.reset()
	clearBeams()
	current = nil
	voids = {}
	fields = {}
	for part in pairs(live) do
		part:Destroy()
	end
	live = {}
end

function BossEnvironmentView.debugState()
	local count = 0
	for _ in pairs(live) do
		count += 1
	end
	return { parts = count, active = current ~= nil and current.active == true }
end

-- 빙판(field kind "slippery" - 서리 거인 발 구르기): 원 안 지면에 서 있으면 미끄러진다(수평 속도가 한 프레임에 목표 쪽으로 SLIP_BLEND만큼만 - 관성).
-- 판정 없음(서버는 알리기만 한다). 원 = 옅은 흰 판(Glass).
local SLIP_BLEND = 0.06
local fields = {} -- { center, radius, untilAt, part }
local lastVelocity = Vector3.zero

function BossEnvironmentView.field(data)
	if data.kind ~= "slippery" then
		return
	end
	local part = newPart(Vector3.new(0.2, data.radius * 2, data.radius * 2), WHITE, 0.55, Enum.Material.Glass, Enum.PartType.Cylinder)
	part.CFrame = CFrame.new(data.center + Vector3.new(0, 0.18, 0)) * CFrame.Angles(0, 0, math.rad(90))
	table.insert(fields, { center = data.center, radius = data.radius, untilAt = os.clock() + data.seconds, part = part })
	task.delay(data.seconds, function()
		TweenService:Create(part, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		task.delay(0.4, function()
			destroy(part)
		end)
	end)
end

RunService.Heartbeat:Connect(function()
	if #fields == 0 then
		return
	end
	local now = os.clock()
	for i = #fields, 1, -1 do
		if now > fields[i].untilAt then
			table.remove(fields, i)
		end
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or root.Anchored or humanoid.FloorMaterial == Enum.Material.Air then
		lastVelocity = root and root.AssemblyLinearVelocity or Vector3.zero
		return
	end
	local inside = false
	for _, f in ipairs(fields) do
		local d = Vector3.new(root.Position.X - f.center.X, 0, root.Position.Z - f.center.Z).Magnitude
		inside = inside or d <= f.radius
	end
	local v = root.AssemblyLinearVelocity
	if inside then
		local flat = Vector3.new(lastVelocity.X, 0, lastVelocity.Z):Lerp(Vector3.new(v.X, 0, v.Z), SLIP_BLEND)
		root.AssemblyLinearVelocity = Vector3.new(flat.X, v.Y, flat.Z)
		v = root.AssemblyLinearVelocity
	end
	lastVelocity = v
end)

-- 점프대(서버 파트 - 태그 BossJumpPad · Attribute LaunchHeight): 내 캐릭터가 서 있으면 그 높이까지 띄운다(v = √(2gh)). 서버 높이 검증의 기준 = 점프대 윗면이라
-- 허용(+22.38) 안이다. 한 번 띄우면 0.6초 동안은 다시 안 띄운다(떠오르는 첫 프레임에 또 밟힌 것으로 읽히지 않게).
-- M1-2c: 띄울 때 LaunchPermitRequest(발판)를 보낸다 - 서버가 위치 기록으로 확인하고 설계 정점까지 높이 허가(공중 점프를 섞어도 되돌리지 않게).
local CollectionService = game:GetService("CollectionService")
local padCooldownUntil = 0
local permitRemote = nil
task.spawn(function()
	permitRemote = ReplicatedStorage:WaitForChild("LaunchPermitRequest", 30)
end)
local function askPermit(pad)
	if permitRemote then
		permitRemote:FireServer(pad)
	end
end
RunService.Heartbeat:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or root.Anchored or os.clock() < padCooldownUntil or humanoid.FloorMaterial == Enum.Material.Air then
		return
	end
	for _, pad in ipairs(CollectionService:GetTagged("BossJumpPad")) do
		local rel = root.Position - pad.Position
		if math.abs(rel.X) <= pad.Size.X / 2 and math.abs(rel.Z) <= pad.Size.Z / 2 and rel.Y >= 0 and rel.Y <= 5 then
			local target = pad:GetAttribute("LaunchTarget")
			if typeof(target) == "Vector3" then
				-- BR1-2 발사 발판(수정 부수기 도움 2단계): 정점 LaunchApexY를 지나 target에 내려앉는 포물선. 날아가는 동안은 조작을 끈다(걷기 제어가 수평 속도를 지우지 않게).
				local g = Workspace.Gravity
				local apexY = math.max(pad:GetAttribute("LaunchApexY") or target.Y + 8, root.Position.Y + 2, target.Y + 1)
				local up = math.sqrt(2 * g * (apexY - root.Position.Y))
				local total = up / g + math.sqrt(2 * (apexY - target.Y) / g)
				local flat = Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z)
				root.AssemblyLinearVelocity = flat / total + Vector3.new(0, up, 0)
				humanoid.PlatformStand = true
				task.delay(total + 0.05, function()
					if humanoid.Parent then
						humanoid.PlatformStand = false
					end
				end)
				padCooldownUntil = os.clock() + total + 0.3
				askPermit(pad)
				BossFx.ring(pad.Position + Vector3.new(0, 0.3, 0), 1, 6, WHITE, 0.3)
				break
			end
			local height = pad:GetAttribute("LaunchHeight") or 18
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(v.X, math.sqrt(2 * Workspace.Gravity * height), v.Z)
			padCooldownUntil = os.clock() + 0.6
			askPermit(pad)
			BossFx.ring(pad.Position + Vector3.new(0, 0.3, 0), 1, 5, WHITE, 0.3)
			break
		end
	end
end)

-- 힘(내 캐릭터) · 바람 줄기(그림).
local windStreakAt = 0
local sinkSand, sinkSeenAt = nil, 0 -- BR1-2 개미지옥: 내 다리를 덮는 모래(구덩이 밖이면 곧 치운다)
RunService.Heartbeat:Connect(function()
	if sinkSand and os.clock() - sinkSeenAt > 0.15 then
		destroy(sinkSand)
		sinkSand = nil
	end
	-- 깔때기 고리가 돈다(안쪽이 빠르다)
	if current and current.active then
		for _, list in pairs(current.parts) do
			for _, part in ipairs(list) do
				local k = part:GetAttribute("PitSwirl")
				if k then
					part.CFrame *= CFrame.Angles(0, 0.02 * (4 - k), 0)
				end
			end
		end
	end
end)
RunService.Heartbeat:Connect(function(dt)
	if not current or not current.active or os.clock() > (current.untilAt or 0) then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 or root.Anchored or player:GetAttribute("BossTrapKind") ~= nil then
		return
	end
	local airborne = humanoid:GetState() == Enum.HumanoidStateType.Freefall or humanoid:GetState() == Enum.HumanoidStateType.Jumping
	-- M1 BR1-3 후속(사용자): 어디서든(중심 · 구덩이 겹침) "바깥으로 걷는 속도 > 끌려가는 속도" - 겹친 구덩이의 끌림을 더하되 한 구덩이 끌림(가장 센 것)을 넘지 않게 자른다.
	--   옛 동작은 겹치면 더해져(7 + 7 = 14) 걷기 16과 거의 같아 못 빠져나왔다.
	local pullSum, pullMax = Vector3.zero, 0
	for _, z in ipairs(current.zones) do
		if z.shape == "pit" and z.pull then
			local toCenter = Vector3.new(z.center.X - root.Position.X, 0, z.center.Z - root.Position.Z)
			if toCenter.Magnitude <= z.radius and toCenter.Magnitude > 0.5 then
				pullSum += toCenter.Unit * z.pull
				pullMax = math.max(pullMax, z.pull)
			end
		end
	end
	if pullSum.Magnitude > pullMax then
		pullSum = pullSum.Unit * pullMax
	end
	if pullSum.Magnitude > 0 then
		root.CFrame += pullSum * dt
	end
	for _, z in ipairs(current.zones) do
		if z.shape == "pit" and z.pull then
			local toCenter = Vector3.new(z.center.X - root.Position.X, 0, z.center.Z - root.Position.Z)
			-- BR1-2: 안쪽일수록 다리가 모래에 묻힌다(그림만 - 판정은 서버 중심 원)
			if toCenter.Magnitude <= z.radius and not airborne then
				local depth = math.clamp(1 - toCenter.Magnitude / z.radius, 0, 1)
				sinkSand = sinkSand or newPart(Vector3.new(3.2, 1, 3.2), Color3.fromRGB(190, 160, 110), 0.05, Enum.Material.Sand, Enum.PartType.Cylinder)
				local h = 0.6 + depth * 2.6
				sinkSand.Size = Vector3.new(h, 3.2, 3.2)
				sinkSand.CFrame = CFrame.new(root.Position.X, z.center.Y + h / 2, root.Position.Z) * CFrame.Angles(0, os.clock() * 4, math.rad(90))
				sinkSeenAt = os.clock()
			end
		elseif z.shape == "wind" and z.push then
			local a = math.rad(z.angleDeg)
			local push = Vector3.new(math.cos(a), 0, math.sin(a)) * z.push * (airborne and (z.airMultiplier or 1) or 1)
			root.CFrame += push * dt
			if os.clock() >= windStreakAt then
				windStreakAt = os.clock() + 0.08
				local offset = Vector3.new(math.random(-40, 40), math.random(2, 8), math.random(-40, 40))
				BossFx.streak(root.Position + offset - push.Unit * 20, push.Unit, 8, 0.2, WHITE, 0.5, 40)
			end
		end
	end
end)

return BossEnvironmentView
