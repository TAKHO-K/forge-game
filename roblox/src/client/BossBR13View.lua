-- BR1-3 새 패턴의 그림 - 서버(BossHandlersBR1)가 보낸 사실만 그린다. 판정 없음. 파티클 방출기 0(부품 · 트윈 · BossFx 풀).
--   swipeOutline  강화 평타 부채꼴 테두리 흰 선 두 줄(보스 몸 밖부터 - 가려지지 않게) + 무기 번쩍
--   sweep         에네르기파: 휩쓸 반원(위험색) + 보스 앞 기 모으기(커지는 빛) + 바닥 회전 화살표 · 머리 위 ↻/↺ → 굵은 빔이 돈다
--   boomerang     분신 돌격: 선(위험색) + 선 끝 분신 실루엣 · 화살표 → 분신이 벽까지 갔다가 돌아와 흡수(선은 끝까지 남는다)
--   armadillo     아르마딜로 태세: 가시가 돋고(전조) → 가시 껍질 + 머리 위 "✋ 공격 멈춤" → 반격 가시(날아와 바닥 원에 꽂힌다)
--   playerStun    기절한 사람 머리 위 별
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local BossSkillMath = require(ReplicatedStorage.Shared.BossSkillMath)
local BossFx = require(script.Parent.BossFx)

local BossBR13View = {}

local DANGER = UIColors.danger
local WHITE = Color3.new(1, 1, 1)
local DUST = Color3.fromRGB(235, 228, 214)
local STEP_DEG = 6

local live = {}
local sweep = nil -- { data, beam, startedAt }
local boom = nil -- { data, lines, clones, startedAt }
local shell = nil -- { parts, gui }

local function newPart(size, color, transparency, shape, material)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = material or Enum.Material.Neon
	part.Color = color
	part.Size = size
	part.Transparency = transparency or 0.4
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

local function fadeOut(part, seconds)
	if not live[part] then
		return
	end
	TweenService:Create(part, TweenInfo.new(seconds), { Transparency = 1 }):Play()
	task.delay(seconds, function()
		destroy(part)
	end)
end

local function disc(center, radius, color, transparency)
	local part = newPart(Vector3.new(0.2, radius * 2, radius * 2), color, transparency, Enum.PartType.Cylinder)
	part.CFrame = CFrame.new(center + Vector3.new(0, 0.14, 0)) * CFrame.Angles(0, 0, math.rad(90))
	return part
end

-- 선분(a → b, 바닥 위 lift) 하나 - 굵기 w.
local function segment(a, b, w, color, transparency, lift)
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local part = newPart(Vector3.new(w, 0.2, math.max(flat.Magnitude, 0.1)), color, transparency)
	local y = Vector3.new(0, lift or 0.2, 0)
	part.CFrame = CFrame.lookAt(a + flat / 2 + y, b + y)
	return part
end

-- 호(가운데 center · 반경 r · 각 fromDeg → toDeg) 위의 가는 선 조각들.
local function arcLine(center, r, fromDeg, toDeg, w, color, transparency, lift)
	local parts = {}
	local steps = math.max(2, math.ceil(math.abs(toDeg - fromDeg) / STEP_DEG))
	for i = 0, steps - 1 do
		local a0 = math.rad(fromDeg + (toDeg - fromDeg) * i / steps)
		local a1 = math.rad(fromDeg + (toDeg - fromDeg) * (i + 1) / steps)
		table.insert(parts, segment(center + Vector3.new(math.cos(a0), 0, math.sin(a0)) * r, center + Vector3.new(math.cos(a1), 0, math.sin(a1)) * r, w, color, transparency, lift))
	end
	return parts
end

-- 반원 · 부채꼴 위험 판(가운데 각 · 폭 · 반경)
local function wedge(center, angleDeg, widthDeg, inner, outer, color, transparency)
	local parts = {}
	local steps = math.max(2, math.ceil(widthDeg / STEP_DEG))
	local mid = (inner + outer) / 2
	for i = 0, steps - 1 do
		local a = math.rad(angleDeg - widthDeg / 2 + widthDeg * (i + 0.5) / steps)
		local arc = 2 * math.pi * outer * (widthDeg / 360) / steps * 1.06
		local part = newPart(Vector3.new(arc, 0.2, outer - inner), color, transparency)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		part.CFrame = CFrame.lookAt(center + dir * mid + Vector3.new(0, 0.13, 0), center + dir * (mid + 1) + Vector3.new(0, 0.13, 0))
		table.insert(parts, part)
	end
	return parts
end

local function bossNear(position)
	local best, bestDistance = nil, math.huge
	for _, model in ipairs(CollectionService:GetTagged("Monster")) do
		if model:GetAttribute("BossHpRatio") ~= nil and not CollectionService:HasTag(model, "RescueTarget") and model.PrimaryPart then
			local d = (model.PrimaryPart.Position - position).Magnitude
			if d < bestDistance then
				best, bestDistance = model, d
			end
		end
	end
	return best
end

local function playerByUserId(userId)
	for _, p in ipairs(Players:GetPlayers()) do
		if p.UserId == userId then
			return p
		end
	end
	return nil
end

local function billboard(adornee, text, color, seconds, size)
	local gui = Instance.new("BillboardGui")
	gui.Size = size or UDim2.new(0, 150, 0, 56)
	gui.StudsOffset = Vector3.new(0, 4.5, 0)
	gui.LightInfluence = 0
	gui.Adornee = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Parent = gui
	gui.Parent = adornee
	if seconds then
		task.delay(seconds, function()
			gui:Destroy()
		end)
	end
	return gui
end

-- ─────────────────────────── 강화 평타 테두리 ───────────────────────────
-- 부채꼴 테두리를 흰 선 **두 줄**(바깥 호 · 두 경계선 - 보스 몸 반폭 밖부터)로 바닥보다 조금 높게 · 보스 무기 자리(앞쪽 머리 높이)가 0.3초 번쩍.
function BossBR13View.swipeOutline(data)
	local parts = {}
	local inner = 3.5 -- 보스 몸통 반폭 밖부터(몸에 가려지지 않게)
	local from, to = data.angleDeg - data.widthDeg / 2, data.angleDeg + data.widthDeg / 2
	for _, r in ipairs({ data.radius, data.radius - 1.1 }) do
		for _, part in ipairs(arcLine(data.center, r, from, to, 0.35, WHITE, 0.1, 0.45)) do
			table.insert(parts, part)
		end
	end
	for _, deg in ipairs({ from, to }) do
		local dir = Vector3.new(math.cos(math.rad(deg)), 0, math.sin(math.rad(deg)))
		local normal = Vector3.new(-dir.Z, 0, dir.X) * (deg == from and 1 or -1)
		for _, shift in ipairs({ 0, 1.1 }) do
			table.insert(parts, segment(data.center + dir * inner + normal * shift, data.center + dir * data.radius + normal * shift, 0.35, WHITE, 0.1, 0.45))
		end
	end
	task.delay(data.seconds, function()
		for _, part in ipairs(parts) do
			fadeOut(part, 0.15)
		end
	end)
	if data.weaponFlash then
		local dir = Vector3.new(math.cos(math.rad(data.angleDeg)), 0, math.sin(math.rad(data.angleDeg)))
		local flash = newPart(Vector3.one * 2.5, WHITE, 0, Enum.PartType.Ball)
		flash.CFrame = CFrame.new(data.center + dir * 3.5 + Vector3.new(0, 6, 0) - dir * 2)
		TweenService:Create(flash, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * 6, Transparency = 1 }):Play()
		task.delay(0.3, function()
			destroy(flash)
		end)
	end
end

-- ─────────────────────────── 에네르기파 휩쓸기 ───────────────────────────
local function clearSweep()
	if sweep then
		for _, part in ipairs(sweep.parts) do
			destroy(part)
		end
		if sweep.gui then
			sweep.gui:Destroy()
		end
		sweep = nil
	end
end

function BossBR13View.sweepTelegraph(data)
	clearSweep()
	sweep = { data = data, parts = {} }
	local color = data.color or DANGER
	for _, part in ipairs(wedge(data.center, data.angleDeg, data.widthDeg, 0, data.radius, DANGER, 0.9)) do
		TweenService:Create(part, TweenInfo.new(data.seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 0.5 }):Play()
		table.insert(sweep.parts, part)
	end
	-- 바닥 회전 화살표: 시작 쪽에서 끝 쪽으로 반경 10의 호 + 끝의 화살촉
	local fromDeg = data.startDeg
	local toDeg = data.startDeg + data.dirSign * data.widthDeg * 0.9
	for _, part in ipairs(arcLine(data.center, 11, fromDeg, toDeg, 1.2, WHITE, 0.05, 0.5)) do
		table.insert(sweep.parts, part)
	end
	local tipAt = data.center + Vector3.new(math.cos(math.rad(toDeg)), 0, math.sin(math.rad(toDeg))) * 11
	local tangent = Vector3.new(-math.sin(math.rad(toDeg)), 0, math.cos(math.rad(toDeg))) * data.dirSign
	for _, side in ipairs({ 1, -1 }) do
		local back = tipAt - tangent * 3 + Vector3.new(math.cos(math.rad(toDeg)), 0, math.sin(math.rad(toDeg))) * 1.8 * side
		table.insert(sweep.parts, segment(back, tipAt, 1.2, WHITE, 0.05, 0.5))
	end
	-- 기 모으기: 보스 앞(대상 쪽) 머리 높이에 빛이 커진다
	local front = Vector3.new(math.cos(math.rad(data.angleDeg)), 0, math.sin(math.rad(data.angleDeg)))
	local orb = newPart(Vector3.one * 0.6, color, 0.1, Enum.PartType.Ball)
	orb.CFrame = CFrame.new(data.center + front * 5 + Vector3.new(0, 5, 0))
	TweenService:Create(orb, TweenInfo.new(data.seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = Vector3.one * 7 }):Play()
	table.insert(sweep.parts, orb)
	sweep.orb = orb
	local boss = bossNear(data.center)
	local head = boss and boss:FindFirstChild("Head")
	if head then
		-- 위에서 보면 +각 = 시계 방향(X → Z) - 화면 기준 화살표
		sweep.gui = billboard(head, data.dirSign > 0 and "↻" or "↺", WHITE, nil, UDim2.new(0, 90, 0, 90))
	end
end

function BossBR13View.sweepFire(data)
	if not sweep then
		return
	end
	local d = sweep.data
	if sweep.orb then
		destroy(sweep.orb)
	end
	local beam = newPart(Vector3.new(d.halfWidth * 2, 3, d.radius), d.color or DANGER, 0.05)
	local core = newPart(Vector3.new(d.halfWidth * 0.8, 3.4, d.radius), WHITE, 0.2)
	table.insert(sweep.parts, beam)
	table.insert(sweep.parts, core)
	sweep.beam, sweep.core, sweep.startedAt = beam, core, os.clock()
	BossFx.shake(d.center, 0.8)
end

function BossBR13View.sweepEnd()
	clearSweep()
end

-- ─────────────────────────── 분신 부메랑 ───────────────────────────
local function clearBoom()
	if boom then
		for _, part in ipairs(boom.parts) do
			destroy(part)
		end
		boom = nil
	end
end

local function cloneBody(color)
	local body = newPart(Vector3.new(3.6, 5.2, 3.6), color, 0.45, nil, Enum.Material.Glass)
	return body
end

function BossBR13View.boomTelegraph(data)
	clearBoom()
	boom = { data = data, parts = {}, clones = {}, lines = {} }
	local color = data.color or DANGER
	for _, line in ipairs(data.lines) do
		local a = math.rad(line.angleDeg)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local band = segment(data.center, data.center + dir * line.length, data.halfWidth * 2, DANGER, 0.85, 0.16)
		TweenService:Create(band, TweenInfo.new(data.seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 0.45 }):Play()
		table.insert(boom.parts, band)
		-- 선 끝: 분신 실루엣(준비 자세) + 화살표(선 끝 삼각 - 오는 길도 같은 선)
		local tip = data.center + dir * line.length
		local silhouette = cloneBody(color)
		silhouette.CFrame = CFrame.lookAt(tip + Vector3.new(0, 2.6, 0), data.center + Vector3.new(0, 2.6, 0))
		table.insert(boom.parts, silhouette)
		local side = Vector3.new(-dir.Z, 0, dir.X)
		for _, s in ipairs({ 1, -1 }) do
			table.insert(boom.parts, segment(tip - dir * 5 + side * 3 * s, tip - dir * 1, 1, WHITE, 0.05, 0.4))
		end
		table.insert(boom.lines, { dir = dir, length = line.length, silhouette = silhouette })
	end
end

function BossBR13View.boomRun()
	if not boom then
		return
	end
	boom.startedAt = os.clock()
	for _, line in ipairs(boom.lines) do
		destroy(line.silhouette) -- 실루엣은 사라지고 보스 곁에서 분신이 달려 나간다
		local clone = cloneBody(boom.data.color or DANGER)
		clone.Transparency = 0.3
		table.insert(boom.parts, clone)
		line.clone = clone
	end
end

function BossBR13View.boomEnd()
	if boom then
		BossFx.ring(boom.data.center + Vector3.new(0, 1, 0), 2, 8, WHITE, 0.35) -- 흡수
	end
	clearBoom()
end

-- ─────────────────────────── 아르마딜로 태세 · 반격 가시 ───────────────────────────
local function clearShell()
	if shell then
		for _, part in ipairs(shell.parts) do
			destroy(part)
		end
		if shell.gui then
			shell.gui:Destroy()
		end
		shell = nil
	end
end

function BossBR13View.armadilloTelegraph(data)
	clearShell()
	shell = { parts = {} }
	local color = data.color or DANGER
	-- 가시가 돋는다: 몸 둘레 12개의 쐐기가 땅에서 솟아 기울어진다
	for i = 1, 12 do
		local a = i / 12 * 2 * math.pi
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local spike = Instance.new("WedgePart")
		spike.Anchored, spike.CanCollide, spike.CanQuery, spike.CanTouch, spike.CastShadow = true, false, false, false, false
		spike.Material = Enum.Material.Neon
		spike.Color = color
		spike.Size = Vector3.new(0.8, 0.2, 1.6)
		local base = CFrame.lookAt(data.center + dir * (data.radius - 2) + Vector3.new(0, 2.5, 0), data.center + dir * (data.radius + 4) + Vector3.new(0, 6, 0))
		spike.CFrame = base
		spike.Parent = Workspace
		live[spike] = true
		TweenService:Create(spike, TweenInfo.new(data.seconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = Vector3.new(0.9, 3.2, 2.2) }):Play()
		table.insert(shell.parts, spike)
	end
end

function BossBR13View.armadilloStance(data)
	if not shell then
		BossBR13View.armadilloTelegraph({ center = data.center, radius = data.radius, seconds = 0.01, color = data.color })
	end
	-- 가시 껍질(반투명 둥근 껍데기) + 머리 위 "✋ 공격 멈춤"(한눈에 "때리지 마")
	local dome = newPart(Vector3.one * data.radius * 2, data.color or DANGER, 0.55, Enum.PartType.Ball, Enum.Material.Glass)
	dome.CFrame = CFrame.new(data.center + Vector3.new(0, 1.5, 0))
	table.insert(shell.parts, dome)
	local boss = bossNear(data.center)
	local head = boss and boss:FindFirstChild("Head")
	if head then
		shell.gui = billboard(head, "✋ 공격 멈춤", Color3.fromRGB(255, 230, 90), nil, UDim2.new(0, 220, 0, 64))
		shell.gui.StudsOffset = Vector3.new(0, 7, 0)
	end
end

function BossBR13View.armadilloEnd()
	clearShell()
end

-- 반격 가시: 보스에서 떨어질 자리로 포물선(delay 동안) + 떨어질 자리 바닥 원(진해진다).
function BossBR13View.spikeMark(data)
	local mark = disc(data.position, data.radius, DANGER, 0.8)
	TweenService:Create(mark, TweenInfo.new(data.seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 0.3 }):Play()
	local ring = arcLine(data.position, data.radius, 0, 360, 0.3, WHITE, 0.1, 0.3)
	local spike = Instance.new("WedgePart")
	spike.Anchored, spike.CanCollide, spike.CanQuery, spike.CanTouch, spike.CastShadow = true, false, false, false, false
	spike.Material = Enum.Material.Neon
	spike.Color = data.color or DANGER
	spike.Size = Vector3.new(1.2, 4, 2.4)
	spike.Parent = Workspace
	live[spike] = true
	local from = data.from + Vector3.new(0, 4, 0)
	local started = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local f = math.clamp((os.clock() - started) / data.seconds, 0, 1)
		if not live[spike] or f >= 1 then
			connection:Disconnect()
			return
		end
		local at = from:Lerp(data.position + Vector3.new(0, 2, 0), f) + Vector3.new(0, math.sin(f * math.pi) * 12, 0)
		spike.CFrame = CFrame.new(at) * CFrame.Angles(f * math.pi * 3, 0, 0)
	end)
	task.delay(data.seconds + 0.05, function()
		destroy(mark)
		destroy(spike)
		for _, part in ipairs(ring) do
			destroy(part)
		end
	end)
end

function BossBR13View.spikeImpact(data)
	fadeOut(disc(data.position, data.radius, WHITE, 0.1), 0.3)
	for i = 1, 8 do
		local a = i / 8 * 2 * math.pi
		BossFx.chunk(data.position + Vector3.new(0, 0.5, 0), Vector3.new(math.cos(a) * 10, 12, math.sin(a) * 10), 0.7, DUST, 0.5)
	end
	BossFx.shake(data.position, 0.4)
end

-- ─────────────────────────── 기절 별 ───────────────────────────
function BossBR13View.playerStun(data)
	local target = data.userId and playerByUserId(data.userId)
	local head = target and target.Character and target.Character:FindFirstChild("Head")
	if head then
		local gui = billboard(head, "✦ ✦ ✦", Color3.fromRGB(255, 225, 80), data.seconds, UDim2.new(0, 110, 0, 36))
		gui.StudsOffset = Vector3.new(0, 2.2, 0)
	end
end

function BossBR13View.reset()
	clearSweep()
	clearBoom()
	clearShell()
	for part in pairs(live) do
		part:Destroy()
	end
	live = {}
end

-- 매 프레임: 빔 회전 · 분신 이동(서버와 같은 함수로 시계를 따라간다 - 판정은 서버)
RunService.RenderStepped:Connect(function()
	if sweep and sweep.beam and sweep.startedAt then
		local d = sweep.data
		local skill = { sweepDeg = d.widthDeg, sweepSeconds = d.sweepSeconds }
		local deg = BossSkillMath.sweepAngleAt(skill, d.angleDeg, d.dirSign, os.clock() - sweep.startedAt)
		local dir = Vector3.new(math.cos(math.rad(deg)), 0, math.sin(math.rad(deg)))
		local mid = d.center + dir * (d.radius / 2) + Vector3.new(0, 1.8, 0)
		sweep.beam.CFrame = CFrame.lookAt(mid, mid + dir)
		sweep.core.CFrame = sweep.beam.CFrame
	end
	if boom and boom.startedAt then
		local d = boom.data
		local skill = { outSpeedStuds = d.outSpeed, backSpeedStuds = d.backSpeed, turnSeconds = d.turnSeconds }
		for _, line in ipairs(boom.lines) do
			if line.clone and live[line.clone] then
				local distance, leg = BossSkillMath.boomerangAt(skill, line.length, os.clock() - boom.startedAt)
				if distance then
					local at = d.center + line.dir * distance + Vector3.new(0, 2.6, 0)
					local face = leg == "back" and -line.dir or line.dir
					line.clone.CFrame = CFrame.lookAt(at, at + face)
					if math.random() < 0.3 then
						BossFx.streak(at, -face, 4, 1, WHITE, 0.25, 0)
					end
				else
					destroy(line.clone)
				end
			end
		end
	end
end)

return BossBR13View
