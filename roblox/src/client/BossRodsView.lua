-- BR1-2 폭풍 군주 "번개 조준경"의 그림(서버 BossLightningRods가 보낸 사실만 - 판정 없음). 파티클 방출기 0.
--   rodsStart   피뢰침마다 바닥에 흰 테(인정 반경 = rodReach) · 화면 위 가운데 "피뢰침 0/N · 남은 방전 7"
--   rodsTarget  표적 머리 위 "⚡ 표적"(내 것이면 크게) → markSeconds 뒤 조준경(빨간 십자 + 원)이 표적 발밑을 따라간다
--   rodsLock    조준경이 멈춘다(서버가 잡은 자리 = 낙뢰 자리) · 원이 좁혀 들어온다(lockSeconds)
--   rodsStrike  하늘에서 꽂히는 번개 · 피뢰침에 꽂혔으면 그 피뢰침이 빛난다(노랑 네온) · 이미 빛나는 피뢰침이면 회색 불꽃(인정 없음)
--   rodsAmbient 일반 번개(빨간 원 → 번개) · rodsStatus = 위 글 · rodsEnd = 치운다
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Theme = require(script.Parent.ui.kit.Theme)
local BossFx = require(script.Parent.BossFx)

local BossRodsView = {}

local player = Players.LocalPlayer
local YELLOW = Color3.fromRGB(255, 220, 60)
local RED = Color3.fromRGB(230, 40, 40)
local WHITE = Color3.new(1, 1, 1)

local live = {}
local rods = {} -- [index] = { center, glow }
local scope = nil -- { parts, userId, followFrom, locked }
local hud = nil

local function newPart(size, color, transparency, shape)
	local part = Instance.new("Part")
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = size
	part.Transparency = transparency or 0
	if shape then
		part.Shape = shape
	end
	part.Parent = Workspace
	live[part] = true
	return part
end

local function destroy(inst)
	if inst and live[inst] then
		live[inst] = nil
		inst:Destroy()
	end
end

local function disc(center, radius, color, transparency)
	local part = newPart(Vector3.new(0.2, radius * 2, radius * 2), color, transparency, Enum.PartType.Cylinder)
	part.CFrame = CFrame.new(center + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90))
	return part
end

local function playerByUserId(userId)
	for _, p in ipairs(Players:GetPlayers()) do
		if p.UserId == userId then
			return p
		end
	end
	return nil
end

local function ensureHud()
	if hud and hud.Parent then
		return hud
	end
	Theme.recompute()
	local gui = Instance.new("ScreenGui")
	gui.Name = "BossRodsHud"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 30
	local label = Instance.new("TextLabel")
	label.Name = "Status"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, Theme.isMobile and 66 or 96)
	label.Size = UDim2.new(0, Theme.isMobile and 300 or 340, 0, Theme.isMobile and 36 or 38)
	label.BackgroundColor3 = Theme.color("panel")
	label.BackgroundTransparency = 0.15
	label.Font = Theme.font
	label.TextSize = Theme.textSize("title")
	label.TextColor3 = YELLOW
	label.Parent = gui
	Theme.corner(label, Theme.corner.chip)
	gui.Parent = player:WaitForChild("PlayerGui")
	hud = gui
	live[gui] = true
	return gui
end

function BossRodsView.start(data)
	BossRodsView.clear()
	for _, rod in ipairs(data.rods or {}) do
		local ring = disc(rod.center, 5, WHITE, 0.6)
		rods[rod.index] = { center = rod.center, ring = ring }
	end
	ensureHud()
end

function BossRodsView.status(data)
	local gui = ensureHud()
	gui.Status.Text = ("⚡ 피뢰침 %d/%d · 남은 방전 %d"):format(data.charged, data.required, data.left)
	for index, entry in pairs(rods) do
		if data.chargedIndex and data.chargedIndex[index] and not entry.glow then
			entry.glow = newPart(Vector3.new(1.6, 13, 1.6), YELLOW, 0.1)
			entry.glow.CFrame = CFrame.new(entry.center + Vector3.new(0, 6, 0))
			entry.ring.Color = YELLOW
			entry.ring.Transparency = 0.3
			BossFx.ring(entry.center, 2, 9, YELLOW, 0.5)
		end
	end
end

local function clearScope()
	if scope then
		for _, part in ipairs(scope.parts) do
			destroy(part)
		end
		destroy(scope.mark)
		scope = nil
	end
end

function BossRodsView.target(data)
	clearScope()
	local target = playerByUserId(data.userId)
	local head = target and target.Character and target.Character:FindFirstChild("Head")
	local mark = nil
	if head then
		local mine = target == player
		mark = Instance.new("BillboardGui")
		mark.Size = UDim2.new(0, mine and 130 or 90, 0, mine and 44 or 32)
		mark.StudsOffset = Vector3.new(0, 5, 0)
		mark.AlwaysOnTop = true
		mark.Adornee = head
		mark.Parent = head
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = RED
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = WHITE
		label.Text = mine and "⚡ 내가 표적!" or "⚡ 표적"
		label.Parent = mark
		live[mark] = true
	end
	local ring = disc(Vector3.zero, 6, RED, 0.45)
	local barA = newPart(Vector3.new(0.4, 0.3, 14), RED, 0.1)
	local barB = newPart(Vector3.new(14, 0.3, 0.4), RED, 0.1)
	for _, part in ipairs({ ring, barA, barB }) do
		part.Transparency = 1
	end
	scope = { parts = { ring, barA, barB }, mark = mark, userId = data.userId, followFrom = os.clock() + data.markSeconds, locked = nil }
end

function BossRodsView.lock(data)
	if not scope then
		return
	end
	scope.locked = data.position
	for _, part in ipairs(scope.parts) do
		part.Transparency = 0.1
	end
	local ring = scope.parts[1]
	ring.Size = Vector3.new(0.2, data.radius * 4, data.radius * 4)
	TweenService:Create(ring, TweenInfo.new(data.seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = Vector3.new(0.2, data.radius * 2, data.radius * 2) }):Play()
end

function BossRodsView.strike(data)
	clearScope()
	local bolt = newPart(Vector3.new(1.2, 60, 1.2), data.already and Color3.fromRGB(150, 150, 150) or YELLOW, 0)
	bolt.CFrame = CFrame.new(data.position + Vector3.new(0, 30, 0))
	task.delay(0.25, function()
		destroy(bolt)
	end)
	BossFx.ring(data.position, 1, data.radius + 2, WHITE, 0.3)
	BossFx.shake(data.position, 0.5)
end

function BossRodsView.ambient(data)
	local circle = disc(data.position, data.radius, RED, 0.55)
	TweenService:Create(circle, TweenInfo.new(data.seconds), { Transparency = 0.25 }):Play()
	task.delay(data.seconds + 0.1, function()
		destroy(circle)
	end)
end

function BossRodsView.ambientHit(data)
	local bolt = newPart(Vector3.new(0.8, 50, 0.8), WHITE, 0)
	bolt.CFrame = CFrame.new(data.position + Vector3.new(0, 25, 0))
	task.delay(0.2, function()
		destroy(bolt)
	end)
	BossFx.ring(data.position, 1, data.radius + 1, WHITE, 0.25)
end

function BossRodsView.clear()
	clearScope()
	for inst in pairs(live) do
		inst:Destroy()
	end
	live, rods, hud = {}, {}, nil
end

-- 조준경이 표적의 발밑을 따라간다(표시 뒤 ~ 멈출 때까지)
RunService.RenderStepped:Connect(function()
	if not scope or scope.locked then
		if scope and scope.locked then
			local at = scope.locked
			scope.parts[1].CFrame = CFrame.new(at + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
			scope.parts[2].CFrame = CFrame.new(at + Vector3.new(0, 0.2, 0))
			scope.parts[3].CFrame = CFrame.new(at + Vector3.new(0, 0.2, 0))
		end
		return
	end
	if os.clock() < scope.followFrom then
		return
	end
	local target = playerByUserId(scope.userId)
	local root = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
	if root then
		local at = Vector3.new(root.Position.X, root.Position.Y - 3, root.Position.Z)
		for i, part in ipairs(scope.parts) do
			part.Transparency = i == 1 and 0.45 or 0.2
		end
		scope.parts[1].CFrame = CFrame.new(at + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, os.clock() * 3, math.rad(90))
		scope.parts[2].CFrame = CFrame.new(at + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, os.clock() * 2, 0)
		scope.parts[3].CFrame = CFrame.new(at + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, os.clock() * 2, 0)
	end
end)

return BossRodsView
